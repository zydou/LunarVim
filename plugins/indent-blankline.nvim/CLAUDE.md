# indent-blankline.nvim

## Project Overview

indent-blankline.nvim is a Neovim plugin that adds indentation guide lines to all lines (including empty lines). It uses Neovim's virtual text feature and does **not** use conceal. It supports treesitter integration to highlight the current code context. Requires Neovim >= 0.5. This is the v3 version (v1 lives on the `version-1` branch).

## Repository Structure

```
indent-blankline.nvim/
├── lua/indent_blankline/
│   ├── init.lua              # Entry module: setup() and refresh() core rendering logic
│   ├── commands.lua          # User commands: Enable / Disable / Toggle / Refresh
│   └── utils.lua             # Utility functions (indent calculation, context detection, highlight management)
├── plugin/
│   └── indent_blankline.vim  # Vim plugin entry (defines commands and autocommands)
├── doc/
│   └── indent_blankline.txt  # Vim help documentation
├── README.md
├── LICENSE.md
├── stylua.toml               # Code formatter config
└── .luacheckrc               # Linter config
```

## Core Modules

### `indent_blankline.init` — Entry and Rendering Engine
- `M.setup(options)` — Configures the plugin; stores all options in `vim.g.indent_blankline_*` global variables.
- `M.init()` — Initialization: creates the highlight namespace, resets highlights, performs the first refresh.
- `M.refresh(scroll)` — Core rendering function, guarded by `xpcall`.

#### Rendering Pipeline
1. Check whether the plugin is enabled via `utils.is_indent_blankline_enabled` (respects `enabled`, `disable_with_nolist`, filetype/buftype/bufname include/exclude lists).
2. Compute the window range: `vim.fn.line('w0')` and `vim.fn.line('w$')`, plus/minus `viewport_buffer`.
3. Manage the render-range cache (`vim.b.__indent_blankline_ranges`), keyed by stringified `leftcol`, supporting scroll merging.
4. Read buffer lines in the current range (`nvim_buf_get_lines`).
5. For every line, compute the indent level via `utils.find_indent` (or `ts_indent.get_indent` for blank lines when treesitter is enabled).
6. Build the virtual text lines via the `get_virtual_text` closure; handles first-indent toggle, toggling of trailing indent, end-of-line char, context highlight, blank-line inheritance, `max_indent_increase`, and `leftcol` skip for horizontally-scrolled rendering.
7. Use `vim.loop.new_async` per line, with the real work wrapped in `vim.schedule_wrap` and guarded by `xpcall(utils.error_handler, ...)`.
8. Render through `nvim_buf_set_extmark` with `virt_text_pos = "overlay"` and `hl_mode = "combine"`.

### `indent_blankline.commands` — User Commands
- `M.refresh(bang, scroll)` — Refresh. With `bang`, refresh across all windows using `windo` and restore the current window.
- `M.enable(bang)` — Enable. Global (buffer 0) if `bang`, otherwise the current buffer.
- `M.disable(bang)` — Disable. Clears the namespace for all buffers if `bang`, or just the current buffer (sets `vim.b.__indent_blankline_active = false`).
- `M.toggle(bang)` — Toggle. Reads `vim.g.indent_blankline_enabled` (bang) or `vim.b.__indent_blankline_active` (non-bang).

Vim user commands exposed by `plugin/indent_blankline.vim`:

| Command | Description |
| --- | --- |
| `:[bang]IndentBlanklineRefresh` | Refresh indent guides. `!` applies to all windows. |
| `:[bang]IndentBlanklineRefreshScroll` | Refresh triggered on scroll (same with context merging). |
| `:[bang]IndentBlanklineEnable` | Enable guides. |
| `:[bang]IndentBlanklineDisable` | Disable guides. |
| `:[bang]IndentBlanklineToggle` | Toggle guides. |

### `indent_blankline.utils` — Utility Functions

#### Caching & Error Handling
- `M.memo` — Memoization wrapper; caches recent function results by inspected parameters (used to memoize `is_indent_blankline_enabled`).
- `M.error_handler(err, level)` — Error handler: silently ignores "Invalid buffer id" errors; otherwise forwards to `vim.notify_once` with a `DEBUG` level.

#### Indent Calculation
- `M.find_indent(whitespace, only_whitespace, shiftwidth, strict_tabs, list_chars)` — Calculates indent level and builds a `virtual_string` from `listchars`. When tabs appear before non-tabs and `strict_tabs` is true, returns `indent = 0`. Handles `tab_char_start` / `tab_char_fill` / `tab_char_end` from `:listchars`.

#### Context Detection
- `M.get_current_context(type_patterns, use_treesitter_scope)` — Gets the current code context. Requires `nvim-treesitter`. When `use_treesitter_scope` is true, uses `locals.containing_scope`; otherwise walks up the node tree looking for the first type matching a regex in `pattern_list` and returns `start + 1`, `end + 1` (1-indexed).

#### Highlight Management
- `M.reset_highlights()` — Resets default highlights. Derived from `Whitespace` / `Label` links. `IndentBlanklineContextStart` uses `gui=underline guisp=...`, the others use `guifg=... gui=nocombine`. Only overrides highlights that the user hasn't already customized (fg, bg, sp, cterm attributes are all empty).

#### Buffer Operations
- `M.clear_buf_indent(buf)` — Clears the indent extmarks in the entire buffer.
- `M.clear_line_indent(buf, lnum)` — Clears extmarks only on the given line.

#### Other Helpers
- `M.get_from_list(list, i, default)` — Returns the i-th element of the highlight list by cycling with modulo, or a default value.
- `M.first_not_nil(...)` — Returns the first non-nil argument (used by `setup`).
- `M.get_variable(key)` — Resolves `vim.b[key]` → `vim.t[key]` → `vim.g[key]` priority chain.
- `M.merge_ranges(ranges)` — Merges consecutive/overlapping `[start, end]` ranges.
- `M.binary_search_ranges(ranges, target)` — Binary search in range list.
- `M._if(cond, a, b)` — Ternary operator helper.

## Configuration

```lua
require("indent_blankline").setup {
    enabled = true,                              -- Plugin switch
    char = "│",                                  -- Indent guide char
    char_blankline = "",                         -- Indent guide char on blank lines (falls back to char)
    char_list = {},                              -- Per-level indent chars
    char_list_blankline = {},                    -- Per-level chars on blank lines
    context_char = "│",                          -- Context indent guide char
    context_char_blankline = "",                 -- Context char on blank lines
    context_char_list = {},                      -- Per-level context chars
    context_char_list_blankline = {},            -- Per-level context chars on blank lines
    indent_level = 20,                           -- Max indent level to render
    max_indent_increase = nil,                   -- Max indent increase relative to previous line (falls back to indent_level)
    use_treesitter = false,                      -- Use treesitter for indent calculation
    use_treesitter_scope = false,                -- Use treesitter containing_scope instead of pattern matching
    show_first_indent_level = true,              -- Display the first level of indent
    show_trailing_blankline_indent = true,       -- Show indent guides on trailing blank lines
    show_end_of_line = false,                    -- Display end-of-line char
    show_foldtext = true,                        -- Skip lines inside closed folds
    show_current_context = false,                -- Highlight the indent of the current context
    show_current_context_start = false,          -- Highlight the start line of the current context
    show_current_context_start_on_current_line = true, -- Show the context marker when the cursor is on the first line
    space_char_blankline = " ",                  -- Space char on blank lines (only when `list` is off)
    strict_tabs = false,                         -- Turn off indent guides when tabs precede spaces
    disable_with_nolist = false,                 -- Disable plugin when `nolist`
    disable_warning_message = false,             -- Suppress the IndentLine migration warning
    viewport_buffer = 10,                        -- Additional line buffer at top/bottom of viewport
    context_patterns = { "class", "^func", ... }, -- Treesitter node patterns for context detection
    context_pattern_highlight = {},              -- Per-pattern highlight overrides (e.g. { ["if"] = "Conditional" })
    filetype = {},                               -- Only render in these filetypes
    filetype_exclude = { "lspinfo", "packer", "checkhealth", "help", "man", "" },
    filetype_include = {},                       -- Alias for filetype
    buftype_exclude = { "terminal", "nofile", "quickfix", "prompt" },
    bufname_exclude = {},                        -- Buffer-name (pattern) exclude list
    char_priority = 1,                           -- Extmark priority for indent chars
    context_start_priority = 10000,              -- Extmark priority for the context-start underline
    char_highlight_list = {},                    -- Per-level indent char highlights
    space_char_highlight_list = {},              -- Per-level space highlights
    space_char_blankline_highlight_list = {},    -- Per-level space highlights on blank lines
    context_highlight_list = {},                 -- Per-level context char highlights
}
```

All configuration entries are stored in `vim.g.indent_blankline_*` global variables and can also be set directly.

### Configuration Precedence (for each option)

```
options.<key>               -- First priority (passed to setup())
vim.g.indent_blankline_*    -- Second priority (user-set global)
vim.g.indentLine_*          -- Third priority (backward-compatible with Yggdroot/indentLine)
fallback literal            -- Final default
```

### Variable Resolution Priority (per-buffer / per-tab / per-global)

For per-buffer reads such as `indent_blankline_enabled`, `utils.get_variable` resolves in order: `vim.b[key] → vim.t[key] → vim.g[key]`.

## Highlight Groups

| Highlight Group | Default Link | Description |
| --- | --- | --- |
| `IndentBlanklineChar` | `Whitespace` | Normal indent guide |
| `IndentBlanklineSpaceChar` | `Whitespace` | Space chars that make up indent levels |
| `IndentBlanklineSpaceCharBlankline` | `Whitespace` | Space chars on blank lines |
| `IndentBlanklineContextChar` | `Label` | The indent guide matching the current context |
| `IndentBlanklineContextSpaceChar` | `Whitespace` | Space chars within the current context |
| `IndentBlanklineContextStart` | `Label` (underline) | Marker for the first line of the current context (underline style) |

Highlights are applied by `utils.reset_highlights` and only take effect if the user hasn't already defined them (checks fg/bg/sp/cterm attributes to detect customization).

## Commands and Autocommands

Registered by `plugin/indent_blankline.vim`:

```vim
autocmd OptionSet list,listchars,shiftwidth,tabstop,expandtab  IndentBlanklineRefresh
autocmd FileChangedShellPost,TextChanged,TextChangedI,CompleteChanged,
            \ BufWinEnter,Filetype *                            IndentBlanklineRefresh
autocmd WinScrolled *                                         IndentBlanklineRefreshScroll
autocmd ColorScheme *             lua require("indent_blankline.utils").reset_highlights()
autocmd VimEnter *                lua require("indent_blankline").init()
```

When `show_current_context = true`, an additional autocommand group is registered inside `setup()`:

```vim
autocmd CursorMoved,CursorMovedI * IndentBlanklineRefresh
```

## Dependencies

- **Required**: Neovim >= 0.5 (the plugin uses virtual text extmarks; Vim is not supported).
- **Optional**: `nvim-treesitter` — enables treesitter-based indent calculation, context detection, and scope-based context.
- **Backward-compatible**: Reads `vim.g.indentLine_*` variables from the older Yggdroot/indentLine plugin.

## Build / Test

- **No automated test suite**.
- **Lint**: `luacheck` (config in `.luacheckrc`).
- **Format**: `stylua` (config in `stylua.toml`).
- **CI**: `.github/workflows/pr_check.yml`.

## Coding Conventions

- **Language**: Pure Lua (compatible with LuaJIT).
- **Configuration storage**: Uses `vim.g.*` global variables (not `vim.opt` or a `setup` return value).
- **Naming**: Module functions use uppercase (`M.setup`, `M.refresh`); config keys use `snake_case`.
- **Error handling**: All extmark operations are wrapped with `xpcall` + `utils.error_handler`.
- **Async processing**: Uses `vim.loop.new_async` per line, with the actual work wrapped in `vim.schedule_wrap`.
- **Range caching**: `vim.b.__indent_blankline_ranges` caches rendered ranges keyed by `leftcol`; supports scroll merging via `merge_ranges` and `binary_search_ranges`.
- **Compatibility**: Maintains backward compatibility with Yggdroot/indentLine options (e.g. `vim.g.indentLine_char`).
- **Highlight safety**: `reset_highlights` only applies defaults when the user hasn't customized the highlight group.
- **Memoization**: `is_indent_blankline_enabled` is memoized via `utils.memo` to avoid redundant computation on every refresh.
