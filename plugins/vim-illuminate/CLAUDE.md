# vim-illuminate

## Project Overview

A Neovim plugin that automatically highlights other uses of the word under the cursor, similar to IDE "highlight occurrences" features. Supports multiple backend providers (LSP, Tree-sitter, regex) and provides reference navigation, text-object selection, and flexible pause/freeze/visibility controls.

- **Author**: Adam P. Regasz-Rethy (RRethy)
- **License**: Not specified
- **Requirement**: Neovim >= 0.7.2 (recommended); legacy Vim/Neovim 0.5.1+ path available via `g:Illuminate_useDeprecated`

## Directory Structure

```
vim-illuminate/
├── lua/
│   ├── illuminate.lua             # Entry module: public API (legacy + new wrappers)
│   └── illuminate/
│       ├── config.lua             # Configuration management (providers, delay, filetypes, etc.)
│       ├── engine.lua             # Core engine: autocmds, timer, refresh logic, pause/resume
│       ├── reference.lua          # Reference data management (buf_references, bisect, cursor_in_references)
│       ├── highlight.lua          # Highlight management via extmarks (illuminate.highlight namespace)
│       ├── goto.lua               # Reference navigation (goto_next_reference, goto_prev_reference)
│       ├── textobj.lua            # Text-object (<a-i> selects current reference range)
│       ├── util.lua               # Utilities (is_allowed, get_cursor_pos, has_keymap)
│       └── providers/
│           ├── lsp.lua            # LSP provider (textDocument/documentHighlight via buf_request_all)
│           ├── treesitter.lua     # Tree-sitter provider (nvim-treesitter locals)
│           └── regex.lua          # Regex provider (vim.regex with \k\+ pattern)
├── plugin/
│   └── illuminate.vim             # Vim entry point: loads engine, creates commands and default keymaps
├── autoload/
│   └── illuminate.vim             # Legacy Vim-compatible functions (on_cursor_moved, matchadd-based)
├── doc/
│   └── illuminate.txt             # Vim help documentation
├── .editorconfig
├── README.md
└── foo.txt                        # Placeholder file
```

## Architecture

The plugin has two parallel implementations:

1. **New engine** (`lua/illuminate/`): Used by default on Neovim >= 0.7.2. Powered by autocmds, libuv timers, and extmarks.
2. **Legacy implementation** (`lua/illuminate.lua` + `autoload/illuminate.vim`): Used on older versions or when `g:Illuminate_useDeprecated = 1`. Uses `vim.lsp.util.buf_highlight_references`, `matchadd`, and Vim timers.

The entry module (`lua/illuminate.lua`) exposes both legacy functions directly and delegates new-API calls to submodules.

## Core Modules

### `illuminate` (Entry)

Entry module providing the public API. Contains legacy implementations (LSP handler, `next_reference`, `toggle_pause`) and thin wrappers that delegate to submodules for the new engine.

| Function | Description |
|----------|-------------|
| `M.on_attach(client)` | LSP on_attach callback; sets `textDocument/documentHighlight` handler (legacy) |
| `M.on_cursor_moved(bufnr)` | Legacy cursor-moved handler; clears highlights and re-requests |
| `M.get_document_highlights(bufnr)` | Returns the reference list for the buffer (legacy) |
| `M.next_reference(opt)` | Legacy reference navigation (supports `reverse`, `wrap`, `range_ordering`, `silent`) |
| `M.toggle_pause()` | Legacy buffer-local pause toggle |
| `M.configure(config)` | Sets configuration (delegates to `config.set`) |
| `M.pause()` / `M.resume()` / `M.toggle()` | Global pause/resume/toggle (delegates to engine) |
| `M.pause_buf()` / `M.resume_buf()` / `M.toggle_buf()` / `M.stop_buf()` | Buffer-level pause control (delegates to engine) |
| `M.freeze_buf()` / `M.unfreeze_buf()` / `M.toggle_freeze_buf()` | Freeze buffer (stop refresh but keep highlights; delegates to engine) |
| `M.invisible_buf()` / `M.visible_buf()` / `M.toggle_visibility_buf()` | Hide/show highlights without stopping engine (delegates to engine) |
| `M.goto_next_reference(wrap)` | Jump to next reference (defaults to `vim.o.wrapscan`) |
| `M.goto_prev_reference(wrap)` | Jump to previous reference (defaults to `vim.o.wrapscan`) |
| `M.textobj_select()` | Select current reference as text-object |
| `M.debug()` | Print debug info (config, provider, paused state) |
| `M.is_paused()` | Returns global paused state |
| `M.set_highlight_defaults()` | Set default highlight groups (IlluminatedWordText/Read/Write) |

### `illuminate.engine` (Core Engine)

The heart of the new implementation. Manages:

- **Autocmds** (in augroup `vim_illuminate_v2_augroup`):
  - `VimEnter`, `CursorMoved`, `CursorMovedI`, `ModeChanged`, `TextChanged` → `refresh_references()`
  - `BufWritePost` → sets `written[bufnr] = true` (prevents stale-reference early return after formatting)
  - `VimLeave` → stops all timers
- **Timer**: Uses `vim.loop.new_timer()` with initial delay from `config.delay()` and 17ms polling interval
- **State**: `paused_bufs`, `stopped_bufs`, `frozen_bufs`, `invisible_bufs`, `is_paused`, `written`, `error_timestamps`
- **Provider selection**: `get_provider(bufnr)` iterates configured providers in order and returns the first ready one

`refresh_references(bufnr, winid)` is the core function:
1. Returns early if buffer is frozen
2. Checks `buf_should_illuminate` (global pause, buffer pause/stop, `should_enable` callback, `max_file_lines`, mode allow/deny, filetype allow/deny)
3. If cursor is still within current references and buffer wasn't just written, clears references and returns
4. If file exceeds `large_file_cutoff`, returns early (skips refresh)
5. Calls `provider.initiate_request(bufnr, winid)`
6. Starts a 17ms-interval timer that polls `provider.get_references(bufnr, pos)`
7. On result: stores references, highlights if cursor is within them, stops timer
8. Error handling: 5 errors within 500ms → notifies and stops the engine

### `illuminate.config`

Configuration table with defaults:

| Key | Default | Description |
|-----|---------|-------------|
| `providers` | `{'lsp', 'treesitter', 'regex'}` | Ordered list of providers |
| `delay` | `100` | Refresh delay in ms (+100ms when in insert mode; minimum 17ms) |
| `filetype_overrides` | `{}` | Per-filetype config overrides |
| `filetypes_denylist` | `{'dirbuf', 'dirvish', 'fugitive'}` | Filetypes to skip |
| `filetypes_allowlist` | `{}` | Filetypes to include (overridden by denylist) |
| `modes_denylist` / `modes_allowlist` | `{}` | Mode filtering |
| `providers_regex_syntax_denylist` / `providers_regex_syntax_allowlist` | `{}` | Syntax filtering for regex provider |
| `under_cursor` | `true` | Highlight the word under cursor |
| `max_file_lines` | `nil` | Disable illumination above this line count |
| `large_file_cutoff` | `nil` | Line count threshold for large-file behavior |
| `large_file_overrides` | `nil` | Config overrides for large files (defaults to disabling illumination) |
| `min_count_to_highlight` | `1` | Minimum matches required to highlight |
| `should_enable` | `function(bufnr) return true end` | Custom enable callback |
| `case_insensitive_regex` | `false` | Case-insensitive regex matching |

Filetype overrides are resolved per-call via `filetype_override(bufnr)`. Large-file overrides default to `{ filetypes_allowlist = { '_none' } }` (effectively disabled) when `large_file_overrides` is nil.

### `illuminate.reference`

Manages per-buffer reference data (`buf_references` table). References are stored as tuples: `{{start_row, start_col}, {end_row, end_col}, kind}` where `kind` is a `DocumentHighlightKind` enum value.

- `buf_set_references(bufnr, refs)` / `buf_get_references(bufnr)`
- `buf_cursor_in_references(bufnr, pos)` — checks if cursor is within any reference (uses binary search)
- `bisect_left(references, pos)` — binary search for navigation
- `buf_sort_references(bufnr)` — lazy sort (only sorts if needed)
- `is_pos_in_ref(pos, ref)` — point-in-range test

### `illuminate.highlight`

Manages extmarks in the `illuminate.highlight` namespace. Does NOT wrap `vim.lsp.util.buf_highlight_references` (only the legacy path in `illuminate.lua` does).

- `buf_highlight_references(bufnr, references)` — applies extmarks using `vim.region()`, respects `under_cursor` and `min_count_to_highlight`
- `buf_clear_references(bufnr)` — clears namespace extmarks
- `range(bufnr, start, finish, kind)` — sets extmark with highlight group based on kind
- `kind_to_hl_group(kind)` — maps `DocumentHighlightKind` to `IlluminatedWordText`/`IlluminatedWordRead`/`IlluminatedWordWrite`

### `illuminate.goto`

Reference navigation using binary search:

- `goto_next_reference(wrap)` — finds next reference after cursor via `bisect_left`
- `goto_prev_reference(wrap)` — finds previous reference before cursor
- Both freeze the buffer during jump to prevent refresh interference, set jump mark via `normal! m``, then unfreeze
- Emits `E384` error when hitting top/bottom without wrap

### `illuminate.textobj`

Text-object implementation for `<a-i>`:

- `select()` — moves cursor to reference start, enters visual mode (or `o` if already visual), moves cursor to reference end
- Handles visual mode variants (`v`, `V`, `CTRL-V`, `s`)

### `illuminate.providers.lsp`

LSP provider using `vim.lsp.buf_request_all` with `textDocument/documentHighlight`.

- `is_ready(bufnr)` — checks if any buffer client supports `textDocument/documentHighlight`
- `initiate_request(bufnr, winid)` — sends LSP request; handles multiple clients; converts offset_encoding (utf-8/utf-16/utf-32) via `get_line_byte_from_position`
- `get_references(bufnr)` — returns cached references from callback
- References are normalized to `{{line, col}, {line, col}, kind}` tuples

### `illuminate.providers.treesitter`

Tree-sitter provider using `nvim-treesitter.ts_utils` and `nvim-treesitter.locals`.

- Registered via `ts.define_modules` with `is_supported = query.has_locals`
- `attach(bufnr)` / `detach(bufnr)` — called by nvim-treesitter when buffer is attached/detached
- `is_ready(bufnr)` — checks `buf_attached[bufnr]` and excludes `yaml` filetype
- `get_references(bufnr)` — uses `locals.find_definition` and `locals.find_usages` to find references

### `illuminate.providers.regex`

Regex provider using `vim.regex` with `\k\+` word pattern.

- `is_ready(bufnr)` — checks syntax against `providers_regex_syntax_allowlist/denylist`
- `get_references(bufnr, cursor)` — builds regex from word under cursor, scans all lines
- Supports `case_insensitive_regex` config
- Returns references with `DocumentHighlightKind.Text`

## Configuration

```lua
-- With nvim-lspconfig
on_attach = function(client)
  require('illuminate').on_attach(client)
end

-- Custom configuration
require('illuminate').configure {
  providers = { 'lsp', 'treesitter', 'regex' },
  delay = 100,
  filetype_overrides = {
    ruby = { providers = { 'regex' } }
  },
  filetypes_denylist = { 'dirbuf', 'dirvish', 'fugitive' },
  under_cursor = true,
  large_file_cutoff = 10000,
  large_file_overrides = { under_cursor = true },
  min_count_to_highlight = 1,
  case_insensitive_regex = false,
}
```

### Highlight Groups

| Group | Description |
|-------|-------------|
| `IlluminatedWordText` | Default highlight for references (no kind info) |
| `IlluminatedWordRead` | Highlight for read-kind references |
| `IlluminatedWordWrite` | Highlight for write-kind references |

Defaults: `gui=underline` (reapplied on `ColorScheme`).

### User Commands (Neovim >= 0.7.2)

| Command | Description |
|---------|-------------|
| `:IlluminatePause` | Globally pause |
| `:IlluminateResume` | Globally resume |
| `:IlluminateToggle` | Globally toggle |
| `:IlluminatePauseBuf` | Buffer-local pause |
| `:IlluminateResumeBuf` | Buffer-local resume |
| `:IlluminateToggleBuf` | Buffer-local toggle |
| `:IlluminateDebug` | Print debug info |

All commands accept a `!` bang (currently unused in command definitions but declared).

### Default Keymaps (Neovim >= 0.7.2)

Only set if no existing user mapping is present (checked via `util.has_keymap`).

| Mapping | Mode | Description |
|---------|------|-------------|
| `<a-n>` | n | Jump to next reference |
| `<a-p>` | n | Jump to previous reference |
| `<a-i>` | o/x | Select current reference text-object |

### Legacy Vim Commands

| Command | Description |
|---------|-------------|
| `:IlluminationDisable[!]` | Disable (buffer-local with `!`) |
| `:IlluminationEnable[!]` | Enable (buffer-local with `!`) |
| `:IlluminationToggle[!]` | Toggle (buffer-local with `!`) |

### Legacy Vim Global Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `g:Illuminate_delay` | `0` | Delay in milliseconds |
| `g:Illuminate_highlightUnderCursor` | `1` | Highlight word under cursor |
| `g:Illuminate_highlightPriority` | `-1` | matchadd priority |
| `g:Illuminate_ftblacklist` | `[]` | Filetype blacklist |
| `g:Illuminate_ftwhitelist` | `[]` | Filetype whitelist |
| `g:Illuminate_ftHighlightGroups` | `{}` | Per-filetype highlight group filtering |
| `g:Illuminate_insert_mode_highlight` | `0` | Enable highlight in insert mode |
| `g:Illuminate_useDeprecated` | `0` | Force legacy implementation on Neovim |

## Dependencies

### Runtime

No hard dependencies. Optional:
- `nvim-treesitter` — enables the treesitter provider
- LSP client — enables the lsp provider

### Consumers

- Commonly used with `nvim-lspconfig` (via `on_attach`)
- Can serve as a highlighting base for other plugins

## Build / Test

No automated test suite. Manual verification:
1. Open a file with LSP support
2. Place cursor on an identifier
3. Observe other occurrences highlighted
4. Use `<a-n>` / `<a-p>` to navigate

## Coding Conventions

- **Language**: Lua, compatible with Neovim 0.5.1+ and 0.7.2+ APIs
- **Code style**: 2-space indentation, no enforced formatter config
- **Naming**: Module export table uses `M`; functions use `snake_case`; Vim script private functions use `s_` prefix
- **Compatibility**: Detected via `vim.fn.has('nvim-0.5.1')` and `vim.fn.has('nvim-0.7.2')`
- **Provider interface**: Each provider implements `is_ready(bufnr)`, `initiate_request(bufnr, winid)`, `get_references(bufnr, pos)`; treesitter additionally implements `attach`/`detach`
- **Error handling**: Engine auto-stops after 5 consecutive errors within 500ms and notifies the user
- **Performance**: Large-file auto-degradation (`large_file_cutoff`); 17ms timer polling to avoid blocking
