# trouble.nvim

## Overview

A Neovim plugin that provides a unified, interactive list for diagnostics, LSP results, quickfix, location lists, Telescope results, fzf-lua results, and Snacks picker results. Supports jumping, previewing, filtering, sorting, and grouping.

- **Author**: folke
- **License**: Apache-2.0
- **Requirement**: Neovim >= 0.9.2

## Directory Structure

```
trouble.nvim/
├── lua/trouble/
│   ├── init.lua                    # Entry module (M.setup + __index proxy to api)
│   ├── api.lua                     # Public API: open/close/toggle/is_open/refresh/get_items/statusline
│   ├── async.lua                   # Coroutine-based async scheduler with budgeted execution
│   ├── cache.lua                   # Cached storage with hit/miss statistics (CacheM/Cache)
│   ├── command.lua                 # :Trouble command implementation and completion
│   ├── docs.lua                    # Extracts docs from source and generates README snippets
│   ├── filter.lua                  # Built-in filters (buf/ft/range/not/any)
│   ├── format.lua                  # Formatting engine (template string parsing, icon resolution)
│   ├── item.lua                    # trouble.Item data class (normalizes position/filename/source)
│   ├── promise.lua                 # Lightweight Promise implementation
│   ├── sort.lua                    # Built-in sorters (pos)
│   ├── spec.lua                    # Config/section/action spec parsing and merging
│   ├── tree.lua                    # trouble.Node tree structure (used for UI rendering)
│   ├── util.lua                    # Utilities (throttle/debounce/notify/weak_ref/get_lines/camel)
│   ├── config/
│   │   ├── init.lua                # trouble.Config definition, setup, get (mode inheritance)
│   │   ├── actions.lua             # Built-in actions (refresh/close/jump/preview/fold/...)
│   │   ├── highlights.lua          # Highlight group definitions and links
│   │   └── parser.lua              # Treesitter-based :Trouble command argument parser
│   ├── view/
│   │   ├── init.lua                # trouble.View class (lifecycle/render/jump/preview)
│   │   ├── indent.lua              # Indent guide symbol rendering
│   │   ├── main.lua                # Main window tracking (trouble.Main)
│   │   ├── preview.lua             # Preview window management (singleton)
│   │   ├── render.lua              # trouble.Render (extends Text), item-to-render-line mapping
│   │   ├── section.lua             # trouble.Section (single data-source result set)
│   │   ├── text.lua                # trouble.Text base class (extmark text segments)
│   │   ├── treesitter.lua          # Treesitter integration (preview/syntax highlighting)
│   │   └── window.lua              # trouble.Window (split/float/main window abstraction)
│   ├── providers/
│   │   └── telescope.lua           # Deprecated shim; redirects to sources/telescope
│   └── sources/
│       ├── init.lua                # trouble.Source registry (register/get/load)
│       ├── diagnostics.lua         # Diagnostics source (uses vim.diagnostic)
│       ├── lsp.lua                 # LSP source (references/definitions/symbols/calls/...)
│       ├── qf.lua                  # Quickfix/Location list source
│       ├── telescope.lua           # Telescope results source (bidirectional integration)
│       ├── fzf.lua                 # fzf-lua integration
│       └── snacks.lua              # Snacks picker integration
├── doc/
│   └── trouble.txt                 # Vim help documentation
├── docs/                           # Supplementary documentation / static assets
├── scripts/                        # Helper scripts
├── tests/                          # plenary.nvim-based Busted tests
│   ├── minit.lua                   # Test entry point (lazy.nvim bootstrap)
│   ├── parser_spec.lua
│   └── spec_spec.lua
├── stylua.toml, selene.toml, vim.toml  # Formatting / static analysis config
├── README.md
└── CHANGELOG.md
```

## Core Modules

### `trouble` (Entry) + `trouble.api`

The entry module uses a `__index` metamethod to proxy all undefined keys to the `api` module, so `require("trouble").open(...)` is equivalent to `require("trouble.api").open(...)`. Action names (e.g. `require("trouble").jump(...)`) are proxied through `M._action(k)`.

| API Function | Description |
|--------------|-------------|
| `M.setup(opts)` | Initialize: set up config, highlights, create `:Trouble` command, initialize main window tracking |
| `M.open(opts)` | Open a Trouble view for the specified mode |
| `M.close(opts)` | Close the most recently opened view |
| `M.toggle(opts)` | Toggle the view open/closed |
| `M.is_open(opts)` | Check whether a matching view is open |
| `M.refresh(opts)` | Refresh all matching views |
| `M.get_items(opts)` | Get the item list of the current view |
| `M.statusline(opts)` | Return a statusline component (`has`/`get` methods) |

### `trouble.config` (Config System)

The config system supports **mode inheritance**: each mode can specify `mode = "parent_mode"` to inherit parent configuration. `M.get(...)` merges in order: `{} → defaults → global options → mode chain (parent first) → user opts`.

`trouble.Config` class defines all config fields:

| Field | Default | Description |
|-------|---------|-------------|
| `debug` | `false` | Enable debug notifications |
| `auto_close` | `false` | Auto close when there are no items |
| `auto_open` | `false` | Auto open when there are items |
| `auto_preview` | `true` | Automatically open preview when on an item |
| `auto_refresh` | `true` | Auto refresh when open |
| `auto_jump` | `false` | Auto jump when there is only one item |
| `focus` | `false` | Focus the window when opened |
| `restore` | `true` | Restore last location in the list when opening |
| `follow` | `true` | Follow the current item |
| `indent_guides` | `true` | Show indent guides |
| `max_items` | `200` | Limit items displayed per section |
| `multiline` | `true` | Render multi-line messages |
| `pinned` | `false` | Bind opened Trouble window to current buffer |
| `warn_no_results` | `true` | Warn when there are no results |
| `open_no_results` | `false` | Open the Trouble window even when there are no results |
| `win` | `{}` | Result window options (split or float) |
| `preview` | `{type="main", scratch=true}` | Preview window options |
| `throttle` | `{refresh=20, update=10, render=10, follow=100, preview={ms=100, debounce=true}}` | Throttle/debounce settings |
| `keys` | (large map) | Key mappings (string action name, custom function, or `false` to disable) |
| `modes` | `{lsp_references, lsp_base, symbols}` | Mode definitions |
| `icons` | `{indent, folder_closed, folder_open, kinds}` | Icon configuration |

Additional `trouble.Mode` fields (extends `trouble.Config` + `trouble.Section.spec`):

| Field | Description |
|-------|-------------|
| `desc?` | Mode description (shown in mode picker) |
| `sections?` | List of section mode names to compose a multi-section view |
| `source` | Source name |
| `title?` | Section title (string or `false` to hide) |
| `events?` | List of autocommands that trigger refresh |
| `groups?` | Grouping specification |
| `sort?` | Sort specification |
| `filter?` | Filter specification |
| `flatten?` | Flatten hierarchical items |
| `format?` | Format template string |
| `params?` | Extra parameters (e.g. LSP request params) |

Custom extension fields: `config? fun(opts)`, `formatters?`, `filters?`, `sorters?`.

### `trouble.view` (View Class)

Core UI class. Each View instance contains:
- `self.sections` — one or more Section (data sources)
- `self.win` — result window (trouble.Window)
- `self.preview_win` — preview window
- `self.renderer` — trouble.Render instance

Key methods:
- `M.new(opts)` — Create view, initialize sections/windows/renderer
- `M:open()` — Refresh data then open window
- `M:close()` — Close and return to main window
- `M:refresh()` — Refresh all sections
- `M:render()` — Render sections to buffer
- `M:jump(item, opts)` — Jump to item location (supports `split`/`vsplit`)
- `M:preview(item)` — Open preview
- `M:filter(filter, opts)` — Apply filter
- `M:fold(node, opts)` / `M:fold_level(opts)` — Fold control
- `M:move(opts)` — Move cursor to next/prev/first/last item
- `M:delete(node)` — Delete item from tree
- `M:help()` — Show help window

### `trouble.sources` (Source Registry)

Sources are registered via `M.register(name, source)`. Each source is a table:
- `source.get(cb, ctx)` — async item-fetching function (or table of sub-source functions)
- `source.config?` — optional default mode configuration
- `source.setup?()` — optional initialization function
- `source.highlights?` — optional highlight definitions
- `source.preview?` — optional custom preview function

`M.load()` auto-loads `lua/trouble/sources/*.lua` from the runtime path.

### `trouble.format` (Formatting Engine)

Template string system supporting `{field}` placeholders, `{hl:Group}text{hl}` highlight markers, `{icon}` icons, and `{a|b}` first-match syntax.

Built-in formatters: `pos`, `code`, `severity`, `severity_icon`, `file_icon`, `count`, `filename`, `dirname`, `filter`, `kind_icon`, `directory`, `directory_icon`.

### `trouble.tree` (Node Tree)

Tree structure for hierarchical UI display. Each Node has `id`, `parent`, `children`, `item`, `group`, `folded`. Supports `flatten`, `count`, `delete`, `is_leaf`, `is`, `depth`, `degree`. Builders: `fields` (group by field values) and `directory` (hierarchical path).

### `trouble.promise`

Lightweight Promise implementation supporting chained `.then` (aliased `next`) and error handling. Unhandled rejections trigger a traceback notification. Provides `resolve`, `reject`, `all`, `all_settled`, `timeout(ms)`.

### `trouble.view.window`

Window abstraction layer supporting three types:
- `split` — split window relative to editor or another window
- `float` — floating window
- `main` — use the current main editor window

Provides an event system (`on` method), keymaps (`map` method), and lifecycle callbacks (`on_mount`, `on_close`).

### `trouble.async`

Coroutine-based async scheduler with a budget (`M.budget = 1` ms). `Async.new(fn)`, `await(cb)`, `sync()`, `cancel()`. Used for structured concurrency.

### `trouble.cache`

Cache class with automatic hit/miss statistics (`Cache.report()`). Auto-vivifies named caches via `__index`.

## Configuration

```lua
require("trouble").setup {
  mode = nil,
  debug = false,
  win = {},
  preview = { type = "main", scratch = true },
  throttle = { refresh = 20, update = 10, render = 10, follow = 100, preview = { ms = 100, debounce = true } },
  keys = { ... },
  modes = { ... },
  icons = { indent = {...}, folder = {...}, kinds = {...} },
  -- Custom extensions:
  -- config = function(opts) end,  -- callback run after mode merge
  -- formatters = { my_formatter = function(ctx) end },
  -- filters = { my_filter = function(item, value, ctx) end },
  -- sorters = { my_sorter = function(item) end },
}
```

### User Command

| Command | Description |
|---------|-------------|
| `:Trouble [mode] [action] [opts]` | Open/operate Trouble (with completion) |

The `:Trouble` command supports Lua assignment syntax for options (parsed via treesitter): e.g. `:Trouble diagnostics win.position=bottom filter.buf=0`.

### Built-in Modes

| Mode | Description |
|------|-------------|
| `diagnostics` | LSP diagnostics |
| `lsp` | Combined LSP view (definitions/references/implementations/type_definitions/declarations/incoming_calls/outgoing_calls) |
| `lsp_references` | LSP references |
| `lsp_definitions` | LSP definitions |
| `lsp_type_definitions` | LSP type definitions |
| `lsp_implementations` | LSP implementations |
| `lsp_declarations` | LSP declarations |
| `lsp_command` | LSP execute command (requires `params.command`) |
| `lsp_document_symbols` | Document symbols |
| `lsp_incoming_calls` | LSP incoming call hierarchy |
| `lsp_outgoing_calls` | LSP outgoing call hierarchy |
| `qflist` / `quickfix` | Quickfix list |
| `loclist` | Location list |
| `symbols` | Document symbols with filtering (custom mode extending lsp_document_symbols) |
| `telescope` | Telescope results previously opened with `require('trouble.sources.telescope').open()` |
| `telescope_files` | Telescope file results |
| `fzf` | fzf-lua results |
| `fzf_files` | fzf-lua file results |
| `snacks` | Snacks picker results |
| `snacks_files` | Snacks picker file results |

### Built-in Actions

`refresh`, `close`, `cancel`, `focus`, `preview`, `delete`, `toggle_preview`, `toggle_refresh`, `filter`, `help`, `next`, `prev`, `first`, `last`, `jump_only`, `jump`, `jump_close`, `jump_split`, `jump_split_close`, `jump_vsplit`, `jump_vsplit_close`, `inspect`, `fold_toggle`, `fold_toggle_recursive`, `fold_open`, `fold_open_recursive`, `fold_close`, `fold_close_recursive`, `fold_reduce`, `fold_more`, `fold_open_all`, `fold_close_all`, `fold_update`, `fold_update_all`, `fold_disable`, `fold_enable`, `fold_toggle_enable`.

## Highlight Groups

All groups are prefixed with `Trouble` and link to standard groups by default:

- **General**: `TroubleNormal`, `TroubleNormalNC`, `TroubleText`, `TroublePreview`
- **Items**: `TroubleFilename`, `TroubleBasename`, `TroubleDirectory`, `TroubleIconDirectory`, `TroubleSource`, `TroubleCode`, `TroublePos`, `TroubleCount`
- **Indent guides**: `TroubleIndent`, `TroubleIndentFoldClosed`, `TroubleIndentFoldOpen`, `TroubleIndentTop/Middle/Last/Ws`
- **LSP kinds**: `TroubleIconArray`, `TroubleIconBoolean`, `TroubleIconClass`, ... (one per SymbolKind)
- **Per-source**: `<Trouble><Source><Field>` (e.g. `TroubleDiagnosticsFilename`)

## Dependencies

### Runtime

No hard runtime dependencies. Optional integrations:
- `plenary.nvim` — test framework
- `nvim-web-devicons` or `mini.icons` — file type icons
- `telescope.nvim` — Telescope result integration
- `fzf-lua` — fzf-lua integration
- `snacks.nvim` — Snacks picker integration
- `nvim-treesitter` — preview syntax highlighting, command argument parsing
- `lualine.nvim` — statusline component refresh

Consumers:
- Telescope/fzf-lua/Snacks can send results to Trouble via `require("trouble.sources.telescope").open()` and similar entry points.

## Build / Test

```bash
# Run tests (uses the minit.lua bootstrap which requires lazy.nvim)
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minit.lua'}"

# Generate docs (requires lazy.nvim)
lua require("trouble.docs").update()
```

Formatting: **stylua** (120 columns, sorted requires). Static analysis: **selene**.

## Coding Conventions

- **Language**: Lua, requires Neovim >= 0.9.2
- **Formatting**: stylua, 120 columns, double quotes, sorted requires
- **Naming**: exported module table is `M`; public functions use `snake_case`; class methods use `:` syntax; private methods use `_` prefix
- **Type annotations**: extensive EmmyLua `---@class`, `---@field`, `---@param`, `---@alias` for sumneko-lua and selene
- **Metatable pattern**: heavy use of Lua metatables for OOP (View/Node/Cache/Text/Window/Indent/Promise/Async)
- **Async**: libuv timers (`vim.loop`/`vim.uv`) for throttle/debounce; coroutines for structured async
- **Weak references**: `Util.weak(self)` used to avoid circular references in callbacks
- **Config inheritance**: mode chain inheritance implemented via `while opts.mode` loop in `Config.get()`
