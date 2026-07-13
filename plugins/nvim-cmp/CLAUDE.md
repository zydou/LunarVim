# nvim-cmp

## Project Overview

nvim-cmp is a **completion engine plugin** for Neovim, authored by hrsh7th and written entirely in Lua. Its core design principle: the engine ships no built-in completion sources — sources are installed from external repositories and "sourced in".

- **Core features:**
  - Full support for LSP completion-related capabilities
  - Powerful customizability via Lua functions
  - Smart key-mapping handling
  - No flicker
  - Snippet engine is a **required** dependency (a `snippet.expand` function must be provided)

## Directory Structure

```
nvim-cmp/
├── LICENSE, Makefile, README.md, init.sh, nvim-cmp-scm-1.rockspec, stylua.toml
├── utils/
├── lua/cmp/                      # all Lua modules
│   ├── init.lua                  # main entry / public API
│   ├── core.lua                  # engine orchestration
│   ├── context.lua               # completion context
│   ├── config.lua                # config storage + merging (require('cmp.config'))
│   ├── entry.lua                 # completion entry model
│   ├── matcher.lua               # match/fuzzy engine
│   ├── source.lua                # source abstraction
│   ├── view.lua                  # UI view controller
│   ├── vim_source.lua            # Vim-Lua bridge
│   ├── types/                    # type enums + specs
│   │   ├── cmp.lua, init.lua, lsp.lua, vim.lua
│   ├── config/                   # config submodules
│   │   ├── compare.lua, context.lua, default.lua
│   │   ├── mapping.lua, sources.lua, window.lua
│   ├── view/                     # view implementations
│   │   ├── custom_entries_view.lua, native_entries_view.lua
│   │   ├── wildmenu_entries_view.lua, docs_view.lua
│   │   └── ghost_text_view.lua
│   └── utils/                    # internal helpers
│       ├── api.lua, async.lua, autocmd.lua, binary.lua
│       ├── buffer.lua, cache.lua, char.lua, debug.lua
│       ├── event.lua, feedkeys.lua, highlight.lua
│       ├── keymap.lua, misc.lua, options.lua, pattern.lua
│       ├── snippet.lua, spec.lua, str.lua, window.lua
├── plugin/
│   └── cmp.lua                   # entry point loaded at Neovim startup
├── autoload/
│   └── cmp.vim                   # Vimscript bridge for Lua callbacks
└── doc/
    └── cmp.txt                   # full Vim help file (~35KB)
```

Each test file (`*_spec.lua`) sits alongside its implementation file.

## Core Modules

### Main Modules

| Module | Responsibility |
|---|---|
| `lua/cmp/init.lua` | **Public API surface**. Creates `cmp.core`, exposes types, wraps core actions (`complete`, `confirm`, `select_*`, `close`, `abort`, `scroll_docs`, `open/close_docs`, `visible`, `get_*_entry`, `status`, `get_config`), defines `cmp.setup`, subscribes to autocmds |
| `lua/cmp/core.lua` | **Engine** (`cmp.Core`). Owns `sources`, `view`, `context`, `event`. Drives the completion lifecycle: filtering, fetching sources, debounce/throttle, confirmation |
| `lua/cmp/context.lua` | **Completion context** (`cmp.Context`). Per-keystroke snapshot: cursor position, cursor_before_line/after_line, bufnr, filetime, time, cache, reason |
| `lua/cmp/entry.lua` | **Completion entry** (`cmp.Model`, `cmp.Entry`). Wraps LSP `CompletionItem`, score, offset, sort text |
| `lua/cmp/source.lua` | **Source abstraction** (`cmp.Source`). Tracks status (`WAITING/FETCHING/COMPLETED`), cache, dedup |
| `lua/cmp/matcher.lua` | Fuzzy/pattern matching logic |
| `lua/cmp/vim_source.lua` | Bridge layer for Vimscript sources (registered via the `autoload/cmp.vim` callback mechanism) |
| `lua/cmp/view.lua` | **UI coordinator** (`cmp.View`). Selects the entries view, wires up `docs_view`, `ghost_text_view`, and the `cmp.view.event` keymap events |

### View Implementations (`lua/cmp/view/`)

| View | Description |
|---|---|
| `custom_entries_view.lua` | Custom floating-window completion view (default; `selection_order='top_down'`) |
| `native_entries_view.lua` | Native popupmenu (`completeopt`) completion view |
| `wildmenu_entries_view.lua` | wildmenu-based view (cmdline) |
| `docs_view.lua` | Documentation window (with border) |
| `ghost_text_view.lua` | Experimental inline ghost-text preview |

### Config Submodules (`lua/cmp/config/`)

| Module | Responsibility |
|---|---|
| `config.lua` | Config storage + merging. Holds `global`, `buffers`, `filetypes`, `cmdline`, `onetime`. `config.get()` caches the merged layers via a `revision` counter |
| `default.lua` | `cmp.ConfigSchema` factory containing all defaults |
| `mapping.lua` | `cmp.mapping` helper + `mapping.preset.insert/cmdline` |
| `window.lua` | `cmp.config.window.bordered()` helper |
| `sources.lua` | `cmp.config.sources(...)` — assigns `group_index` to each source group |
| `compare.lua` | `cmp.config.compare.*` comparator functors (`offset`, `exact`, `score`, `recently_used`, `locality`, `scopes`, `kind`, `length`, `order`, `sort_text`) |
| `context.lua` | Context-related config helpers |

### Utility Modules (`lua/cmp/utils/`)

`api` (cursor/line/mode helpers), `async` (debounce/throttle/dedup), `autocmd` (custom event subscribe/emit), `cache`, `char` (utf-aware offsets), `event` (pub/sub), `feedkeys`, `keymap` (termcode normalization), `misc` (merge, id), `snippet`, `str`, `window`, `binary`, `highlight`, `options`, `pattern`, `debug`, `buffer`, `spec`

### Types (`lua/cmp/types/`)

`init.lua` re-exports `cmp`, `lsp`, `vim`. `cmp.lua` defines enums/aliases/classes: `cmp.ConfirmBehavior`, `cmp.SelectBehavior`, `cmp.ContextReason`, `cmp.TriggerEvent`, `cmp.PreselectMode`, `cmp.ItemField`, and classes `cmp.ContextOption`, `cmp.SetupProperty`, `cmp.ConfigSchema`, `cmp.SourceConfig`, etc.

## Public API (`cmp.*`)

```lua
cmp.setup({...})                            # -> global (same as cmp.setup.global)
cmp.setup.global({...})
cmp.setup.filetype('lua', {...})
cmp.setup.buffer({...})
cmp.setup.cmdline({'/', '?'}, {...})

cmp.complete(option)                        # manual trigger
cmp.complete_common_string()
cmp.close() / abort()
cmp.select_next_item({ behavior, count })
cmp.select_prev_item({ behavior, count })
cmp.confirm({ select, behavior }, callback)
cmp.scroll_docs(delta)

cmp.visible_docs() / cmp.open_docs() / cmp.close_docs()

cmp.visible()
cmp.get_selected_entry() / cmp.get_active_entry() / cmp.get_entries()
cmp.get_config()
cmp.status()

cmp.register_source(name, source)           # returns integer id
cmp.unregister_source(id)

cmp.sync(callback)                          # wraps a callback to run after the filter settles
cmp.suspend()
cmp.core:suspend()

cmp.event:on('complete_done', ...) / 'menu_opened' / 'menu_closed'

cmp.config.disable          -- sentinel to disable a default option (vim.NIL)
cmp.config.compare          -- sorting comparator functions
cmp.config.sources(...)     -- source-group helper
cmp.config.mapping          -- mapping wrapper
cmp.config.window.bordered()

cmp.lsp.CompletionItemKind  -- LSP types

cmp.mapping.preset.insert / .cmdline
cmp.core                    -- the engine instance
```

Note: `cmp.select_next_item` falls back to `<C-n>`/`<Down>` when no cmp menu is visible but the native `pumvisible()` is shown.

## Configuration Options (`config/default.lua`)

```lua
{
  enabled = function() ... end,
  performance = {
    debounce = 60, throttle = 30,
    fetching_timeout = 500, confirm_resolve_timeout = 80,
    async_budget = 1, max_view_entries = 200,
  },
  preselect = cmp.PreselectMode.Item,
  mapping = {},
  snippet = { expand = function(args) ... end },   -- REQUIRED
  completion = {
    autocomplete = { cmp.TriggerEvent.TextChanged },
    completeopt = 'menu,menuone,noselect',
    keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%(-\w*\)*\)]],
    keyword_length = 1,
  },
  formatting = {
    expandable_indicator = true,
    fields = { 'abbr', 'kind', 'menu' },
    format = function(_, vim_item) return vim_item end,
  },
  matching = {
    disallow_fuzzy_matching = false,
    disallow_fullfuzzy_matching = false,
    disallow_partial_fuzzy_matching = true,
    disallow_partial_matching = false,
    disallow_prefix_unmatching = false,
    disallow_symbol_nonprefix_matching = true,
  },
  sorting = {
    priority_weight = 2,
    comparators = { offset, exact, score, recently_used, locality, kind, length, order },
  },
  sources = {},
  confirmation = {
    default_behavior = cmp.ConfirmBehavior.Insert,
    get_commit_characters = function(cc) return cc end,
  },
  event = {},
  experimental = { ghost_text = false },
  view = {
    entries = { name = 'custom', selection_order = 'top_down', follow_cursor = false },
    docs = { auto_open = true },
  },
  window = {
    completion = { border, winhighlight, winblend, scrolloff, col_offset, side_padding, scrollbar },
    documentation = { max_height, max_width, border, winhighlight, winblend },
  },
}
```

**Config merge priority** (low → high): `global_config` → `filetype_config` → `buffer_config`. The more specific scope wins — buffer config overrides filetype config, which overrides global config. The `onetime` config (from `cmp.complete({ config = ... })`) is resolved in its own branch and takes priority over `global` (but does not merge with buffer/filetype layers). Cmdline mode uses `cmdline_config` merged over `global_config`. All layers are merged and cached by `config.cache:ensure(...)` keyed on `revision` counters.

**Deprecation shims** (`config.normalize()`): `experimental.native_menu` → `view.entries='native'`; `documentation` → `window.documentation`; `sources[n].opts` → `sources[n].option`.

## Source Contract

Sources are external — nvim-cmp ships none. The source contract (from `source.lua` + `autoload/cmp.vim`):

- `is_available()`, `get_debug_name()`, `get_position_encoding_kind()`, `get_trigger_characters()`, `get_keyword_pattern()`, `complete(ctx, callback)`, `execute(entry, callback)`, `resolve(entry, callback)`

Registration paths:
- **Lua sources:** `cmp.register_source(name, source)` → `source.new(name, s)` → `core:register_source(src)`; returns integer `id`
- **Vimscript sources:** `cmp#register_source(name, source)` in `autoload/cmp.vim` → bridges via `luaeval` to `cmp.vim_source.new(bridge_id, methods)`. Callbacks flow back through `cmp#_method` → `cmp.vim_source.on_callback`

`cmp.config.sources({...}, {...})` builds a flat list, assigning each group a `group_index` (used by `compare.locality`/`scopes`).

## Dependencies

**Hard runtime dependencies:**
- Neovim with `nvim_create_autocmd` (checked in `plugin/cmp.lua`)
- Snippet engine — **required** (must provide `snippet.expand`). Options: `vim-vsnip` + `cmp-vsnip`, `LuaSnip` + `cmp_luasnip`, `ultisnips` + `cmp-nvim-ultisnips`, `nvim-snippy` + `cmp-snippy`, or native `vim.snippet.expand` (Neovim v0.10+)

**Optional/integration dependencies:**
- `nvim-lspconfig` + `cmp-nvim-lsp` (LSP source + `default_capabilities()`)
- `cmp-buffer`, `cmp-path`, `cmp-cmdline` (official companion sources)
- `petertriho/cmp-git` (git source)
- `vim.on_key` (used to detect `<C-c>` triggering `InsertLeave` — optional, guarded)

**Dev/test:** vusted (busted-style) specs (`*_spec.lua`), Makefile, stylua.toml, init.sh

## Loading

`plugin/cmp.lua` is auto-loaded at Neovim startup (standard `plugin/` convention):

1. **Guard:** `if vim.g.loaded_cmp then return end; vim.g.loaded_cmp = true` — load once
2. **API check:** requires `nvim_create_autocmd`; otherwise prints a warning and returns
3. **Highlights:** sets `CmpItemAbbr`, `CmpItemAbbrDeprecated`, `CmpItemAbbrMatch`, `CmpItemAbbrMatchFuzzy`, `CmpItemKind`, `CmpItemMenu`, and per-kind `CmpItemKind<Kind>` highlights (all `default = true`)
4. **ColorScheme/UIEnter autocmd:** inherits default highlight groups from `Pmenu`/`Comment`/`Special`, `bg='NONE'`
5. **`<C-c>` handling:** if `vim.on_key` exists, registers a key listener in the `cmp.plugin` namespace that fires `InsertLeave` when `<C-c>` is pressed in a non-suitable mode
6. **User command:** `CmpStatus` → `require('cmp').status()`
7. **Ready event:** `doautocmd User CmpReady` — signals that cmp is loaded

The `cmp` module is lazily loaded via `require('cmp')` (runs `lua/cmp/init.lua`) on first use. `init.lua` then wires up autocmds (`InsertEnter`, `TextChangedI/P`, `CmdlineChanged`, `CursorMovedI`, `InsertLeave`, `CmdlineLeave`) and subscribes to `complete_done`/`confirm_done` for `recently_used` + `scopes`/`locality` updates.

## Vim Documentation

`doc/cmp.txt` (~35KB) is the full help file. Sections (help tags):
- `cmp-abstract`, `cmp-concept`, `cmp-usage`, `cmp-function`, `cmp-mapping`, `cmp-command`, `cmp-highlight`, `cmp-filetype`, `cmp-autocmd`, `cmp-config`, `cmp-config-helper`, `cmp-develop`, `cmp-faq`
- Highlight groups: `CmpItemAbbr`, `CmpItemAbbrDeprecated`, `CmpItemAbbrMatch`, `CmpItemAbbrMatchFuzzy`, `CmpItemKind`, `CmpItemKind%KIND_NAME%`, `CmpItemMenu`
- Commands: `CmpStatus`
- Autocmds: `CmpReady`

## Build / Test

- **Test framework:** vusted (busted-style) specs (`*_spec.lua`), alongside implementation files
- **Makefile:** `make test` (vusted), `make lint` (luacheck), `make integration`
- **Formatting:** stylua (config in `stylua.toml`)

## Coding Conventions

- **Module pattern:** each module is a local table returned via `return name`, using `local name = {}` + `setmetatable({}, { __index = name })` for OO-style instantiation
- **Factory functions:** `name.new(...)` for instances; `name.empty(...)` for sentinels
- **Public API prefix:** all user-facing symbols live in the `cmp` table in `init.lua`
- **Type annotations:** heavy use of `---@class`, `---@field`, `---@param`, `---@return`, `---@alias`, `---@type`, `---@overload` (EmmyLua / sumneko-lua style)
- **Enum style:** uppercase table keys mapped to lowercase string values, e.g. `cmp.ConfirmBehavior = { Insert = 'insert', Replace = 'replace' }`
- **Private convention:** fields prefixed with `_` (e.g. `_get_entries_view`) or marked `private` in EmmyLua annotations
- **Test files:** `name_spec.lua` alongside `name.lua` (busted/vusted spec)
- **Config submodules** live in `lua/cmp/config/`; **view implementations** in `lua/cmp/view/`; **utilities** in `lua/cmp/utils/`; **types** in `lua/cmp/types/`
- **Keymap normalization:** keys are normalized via `keymap.normalize`; termcodes via `keymap.t`
- **ID generation:** `misc.id('cmp.xxx.new')` for unique instance ids
- **Autocmd abstraction:** a custom `autocmd.subscribe`/`autocmd.emit` layer is used instead of raw `nvim_create_autocmd` everywhere
