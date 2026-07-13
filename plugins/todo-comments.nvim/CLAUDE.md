# todo-comments.nvim

## Project Overview

todo-comments.nvim is a Neovim (>= 0.8.0) plugin for highlighting and searching TODO/HACK/PERM-style keywords in code comments. It supports configurable highlight styles, sign column icons, multi-line TODO comments, Treesitter integration (highlight only within comments), and multiple search outputs (quickfix, Telescope, FzfLua, Trouble, Snacks).

## Directory Structure

```
todo-comments.nvim/
├── plugin/
│   └── todo.vim              # Vim command entry points (TodoQuickFix/TodoLocList/TodoTelescope/...)
├── lua/todo-comments/
│   ├── init.lua              # Main entry: setup() and reset/disable/enable/jump methods
│   ├── config.lua            # Configuration module (defaults, setup, color/sign generation)
│   ├── highlight.lua         # Highlight engine (matching, rendering, autocmd management)
│   ├── search.lua            # Search module (ripgrep invocation, quickfix/loclist output)
│   ├── jump.lua              # Jump to next/previous TODO
│   ├── util.lua              # Utility functions (color contrast calculation, notifications)
│   ├── fzf.lua               # FzfLua integration
│   ├── snacks.lua            # Snacks.picker integration
├── lua/telescope/
│   └── _extensions/
│       └── todo-comments.lua # Telescope extension (grep_string wrapper)
├── lua/trouble/
│   ├── providers/todo.lua    # Trouble provider (legacy API)
│   └── sources/todo.lua      # Trouble source (new API)
├── doc/
│   └── todo-comments.nvim.txt # Vim help doc (.txt)
├── .neoconf.json             # neodev config (declares plenary.nvim, trouble.nvim, nvim-web-devicons)
├── .editorconfig             # Editor config (2-space indent, utf-8)
├── .lua-format               # LuaFormatter config (column_limit: 80)
├── stylua.toml               # Stylua config (2-space indent, sort_requires)
├── selene.toml               # Selene linter config (vim globals allowed, mixed_table allowed)
└── vim.toml                  # Vim type-checking config (std = "vim")
```

## Core Modules

### `todo-comments.init` — Main Entry

- `M.setup(options)` — Configure plugin (delegates to `config.setup`)
- `M.reset()` — Reload configuration (uses plenary reload)
- `M.enable()` / `M.disable()` — Enable/disable highlighting
- `M.jump_next(opts?)` / `M.jump_prev(opts?)` — Jump to next/previous TODO

### `todo-comments.config` — Configuration Management

- `M.setup(options)` — Merge defaults with user options and initialize (defers if vim hasn't entered)
- `M.options` — Current configuration table
- `M.keywords` — Keyword mapping (alt names -> canonical name)
- `M.search_regex(keywords?)` — Generate search regex from search pattern with KEYWORDS placeholder replaced
- `M.hl_regex` — Compiled highlight regex list
- `M.colors()` — Generate highlight groups (`TodoBg<kw>`, `TodoFg<kw>`, `TodoSign<kw>`) using linear sRGB contrast calculation
- `M.signs()` — Define sign column icons per keyword
- `M._options` — Stored user options for reload
- `M._setup()` — Internal setup (merges config, builds keyword map, compiles regex, registers Snacks source)

**`TodoOptions` configuration fields:**

| Option | Description |
|--------|-------------|
| `signs` | Show icons in sign column |
| `sign_priority` | Sign priority (default: 8) |
| `keywords` | Keyword definitions (each with `icon`, `color`, `alt`, optional `signs`) |
| `merge_keywords` | When true, merge custom keywords with defaults |
| `gui_style` | GUI style for fg/bg highlight groups |
| `colors` | Named color definitions (list of highlight group names + fallback hex) |
| `highlight.multiline` | Enable multi-line TODO comments |
| `highlight.multiline_pattern` | Lua pattern to match continuation lines |
| `highlight.multiline_context` | Extra lines re-evaluated on change |
| `highlight.before` | Highlight before keyword: "fg", "bg", or "" |
| `highlight.keyword` | Keyword highlight style: "fg", "bg", "wide", "wide_bg", "wide_fg", or "" |
| `highlight.after` | Highlight after keyword: "fg", "bg", or "" |
| `highlight.pattern` | Pattern or table of patterns (vim regex, KEYWORDS placeholder) |
| `highlight.comments_only` | Only highlight in comments (via Treesitter) |
| `highlight.max_line_len` | Ignore lines longer than this (default: 400) |
| `highlight.exclude` | Filetypes to exclude from highlighting |
| `highlight.throttle` | Debounce interval in ms (default: 200) |
| `search.command` | Search command (default: "rg") |
| `search.args` | Arguments passed to search command |
| `search.pattern` | Regex with KEYWORDS placeholder for ripgrep |

**Default keywords:** `FIX`, `TODO`, `HACK`, `WARN`, `PERF`, `NOTE`, `TEST` — each supports `alt` aliases.

### `todo-comments.highlight` — Highlight Engine

- `M.enabled` — Whether highlighting is active
- `M.bufs` / `M.wins` — Tracked buffers and windows
- `M.state` — Per-buffer state (`dirty` lines hash, `comments` cache)
- `M.timer` — Debounce timer for batched updates
- `M.start()` / `M.stop()` — Start/stop highlighting (set up/tear down autocmds)
- `M.attach(win)` — Register buffer listener for a window; attaches Treesitter callbacks if available
- `M.highlight(buf, first, last)` — Highlight a line range (clear namespace, place signs, apply hl groups)
- `M.redraw(buf, first, last)` — Mark lines dirty with multiline_context expansion, schedule debounced update
- `M.update()` — Flush dirty lines (grouped into contiguous ranges)
- `M.match(str, patterns?)` — Match single line against highlight patterns; returns `(start, finish, kw)`
- `M.is_comment(buf, row, col)` — Check if position is a comment (Treesitter first, fallback to synstack)
- `M.highlight_win(win, force?)` — Highlight visible range of a window
- `M.is_valid_buf(buf)` / `M.is_valid_win(win)` / `M.is_float(win)` / `M.is_quickfix(buf)` — Validity helpers

**Autocmds (group `Todo`):**
- `BufWinEnter,WinNew *` — attach to buffer
- `WinScrolled *` — highlight visible range
- `ColorScheme *` — re-generate colors (deferred 10ms)

Uses namespace `vim.api.nvim_create_namespace("todo-comments")`.

### `todo-comments.search` — Search Module

- `M.search(cb, opts)` — Async search via plenary.job calling ripgrep
- `M.process(lines)` — Parse raw ripgrep output lines into structured items
- `M.setqflist(opts)` / `M.setloclist(opts)` — Fill quickfix/location list and open
- `M.setlist(opts, use_loclist)` — Underlying list setter (supports `keywords` and `cwd` opts)

### `todo-comments.jump` — Jump

- `M.next(opts?)` / `M.prev(opts?)` — Jump forward/backward by line, filters by `opts.keywords` (list)

### `todo-comments.util` — Utilities

- `M.get_hl(name)` — Get highlight group attributes (foreground/background/special as hex strings)
- `M.hex2linear_srgb(hex)` — Convert hex to linear sRGB
- `M.contrast_ratio(c1, c2)` — WCAG contrast ratio between two linear sRGB colors
- `M.maximize_contrast(base, fg1, fg2)` — Pick the color with higher contrast against base
- `M.warn(msg)` / `M.error(msg)` — Notifications via `vim.notify`

### Integration Modules

- `todo-comments.fzf` — FzfLua integration: `M.todo(opts)` wraps `fzf-lua.providers.grep.Grep.grep`
- `todo-comments.snacks` — Snacks.picker integration: defines `M.source` (with `finder`, `search`, `format`, `previewer`) and `M.pick(opts)`. Source is auto-registered in `config._setup` if Snacks is available.
- `telescope/_extensions/todo-comments.lua` — Telescope extension: exports `todo-comments` and `todo` via `grep_string` with vimgrep entry maker
- `trouble/providers/todo.lua` — Trouble legacy provider (callback style, returns trouble items)
- `trouble/sources/todo.lua` — Trouble new source (defines `M.config` with formatters/modes and `M.get(cb)`)

## Configuration

```lua
require('todo-comments').setup {
  signs = true,
  keywords = {
    FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
    TODO = { icon = " ", color = "info" },
    -- ...
  },
  highlight = {
    pattern = [[.*<(KEYWORDS)\s*:]],
    keyword = "wide",
    comments_only = true,
  },
  search = {
    command = "rg",
    pattern = [[\b(KEYWORDS):]],
  },
}
```

**Vim commands** (defined in `plugin/todo.vim`):

- `:TodoQuickFix` — Fill quickfix list
- `:TodoLocList` — Fill location list
- `:TodoTelescope` — Telescope search
- `:TodoFzfLua` — FzfLua search
- `:TodoTrouble` — Trouble integration

**Lua API:**

```lua
require('todo-comments').jump_next { keywords = { "FIX", "TODO" } }
require('todo-comments').setqflist { open = true }
```

## Dependencies

- **Required:** `nvim-lua/plenary.nvim`
- **Optional:** `BurntSushi/ripgrep` (for search), `telescope.nvim`, `fzf-lua`, `trouble.nvim`, `snacks.nvim`

## Build / Test

No build steps. Lua files and Vim script load directly. Managed via lazy.nvim or any plugin manager.

## Code Style & Tooling

- **Stylua** (`stylua.toml`): 2-space indent, column width 120, `sort_requires` enabled
- **Selene** (`selene.toml`): based on lua51 + `vim` std, allows mixed tables
- **LuaFormatter** (`.lua-format`): column limit 80, 2-space indent
- **vim.toml**: `std = "vim"` for type checking
- EmmyLua-style annotations (`---@class`, `---@type`, `---@param`, `---@field`)
- Module-level locals for global state (`M.ns`, `M.bufs`, `M.wins`, `M.state`, `M.timer`)
- Debounced highlight updates via `vim.defer_fn` + `highlight.throttle`
- Treesitter preferred for comment detection, fallback to `vim.fn.synstack`
- Color contrast computed in linear sRGB space for perceptual accuracy
