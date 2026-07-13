# nvim-navic

## Project Overview

nvim-navic is a Neovim statusline/winbar component that leverages the LSP (Language Server Protocol) `documentSymbol` capability to display the current code context (e.g. class, method, function), similar to IDE breadcrumb navigation.

**Name origin:** Indian Regional Navigation Navigation System (NavIC).

## Directory Structure

```
nvim-navic/
├── LICENSE.md
├── README.md
├── doc/
│   └── navic.txt            # Vim help documentation
└── lua/
    ├── nvim-navic/
    │   ├── init.lua         # Main module, public API
    │   └── lib.lua          # Internal library, LSP symbol parsing and context tracking
    └── lualine/
        └── components/
            └── navic.lua    # lualine integration component
```

## Core Modules

### `nvim-navic` (lua/nvim-navic/init.lua)

Main module providing the public API:

- **`navic.setup(opts)`** — Configure plugin options. Merges user-supplied `icons` into the existing defaults (does not replace the entire icon set).
- **`navic.get_data(bufnr?)`** — Get the context data table for a buffer (list of `{kind, type, name, icon, scope}` entries). Skips the root node (index 1). Returns `nil` if no context is available.
- **`navic.format_data(data, opts?)`** — Format context data into a display-ready string for statusline/winbar. When `opts` is supplied the global config is deep-copied and overridden; otherwise the global config is used directly.
- **`navic.get_location(opts?, bufnr?)`** — Get the formatted location string (primary public interface). Combines `get_data` + `format_data`.
- **`navic.is_available(bufnr?)`** — Check whether navic is attached to the given buffer (defaults to current buffer).
- **`navic.attach(client, bufnr)`** — Attach navic to an LSP client for the specified buffer. Sets up autocommands for context updates and the initial symbol request.

The `Options` class fields:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `icons` | table | Nerd Font icon set (indexed by LSP kind number, 1-26 + 255) | Icons per symbol type |
| `highlight` | boolean | `false` | Enable highlight groups |
| `separator` | string | `" > "` | Separator between symbols |
| `depth_limit` | number | `0` | Max depth shown (0 = unlimited) |
| `depth_limit_indicator` | string | `".."` | Indicator when depth limit is exceeded |
| `safe_output` | boolean | `true` | Escape `%` and newline characters for statusline safety |
| `lazy_update_context` | boolean | `false` | Disable `CursorMoved` context updates (only update on `CursorHold`) |
| `click` | boolean | `false` | Enable click-to-jump; double-click opens nvim-navbuddy |
| `format_text` | function | `function(a) return a end` | Custom text transformation for each segment |
| `lsp.auto_attach` | boolean | `false` | Auto-attach to any LSP via the `LspAttach` autocommand |
| `lsp.preference` | table | `nil` | LSP server priority list (lower index = higher priority) |

#### Autocommand setup inside `attach`

All autocmds are placed in the `"navic"` augroup:

- `InsertLeave`, `BufEnter`, `CursorHold` — request document symbols from the LSP (debounced via `changedtick` and an `awaiting_lsp_response` flag).
- `CursorHold` — update the context (which symbols contain the cursor).
- `CursorMoved` — update context immediately (skipped when `lazy_update_context` is true or `vim.b.navic_lazy_update_context` is set).
- `BufDelete` — clear stored buffer data.

#### Auto-attach mechanism

When `lsp.auto_attach = true`, a single `LspAttach` autocommand is created that:
1. Checks the client exposes `documentSymbolProvider`.
2. Attaches if no client is yet attached to the buffer.
3. If a different client is already attached, consults `lsp.preference` to decide whether to re-attach.

#### Click handling

When `click = true`, segments are wrapped with `%N@v:lua.navic_click_handler@...%X` clickable regions. The global `_G.navic_click_handler` is set at format time:
- Single click: jump to the symbol's start position.
- Double click: open `nvim-navbuddy` on that element (warns if navbuddy is not installed).

### `nvim-navic.lib` (lua/nvim-navic/lib.lua)

Internal library for LSP symbol parsing and context tracking:

- **`lib.parse(symbols)`** — Parse raw LSP document symbols into a tree structure. Auto-detects the two LSP response formats:
  - `SymbolInformation[]` (has `location.range`, flat list) → uses `symbolInfo_treemaker`.
  - `DocumentSymbol[]` (has `range`, hierarchical) → uses `dfs`.
- **`lib.request_symbol(for_buf, handler, client, file_uri?, retry_count?)`** — Make a `textDocument/documentSymbol` request with retry logic (default 10 retries, 750ms delay on error).
- **`lib.update_data(for_buf, symbols)`** — Parse and store the symbol tree for a buffer.
- **`lib.update_context(for_buf, cursor_pos?)`** — Determine which symbols in the tree contain the current cursor position using a binary search over sorted child scopes. Accepts an optional cursor position (defaults to current window cursor).
- **`lib.get_tree(bufnr)`** — Retrieve the stored symbol tree for a buffer.
- **`lib.get_context_data(bufnr)`** — Retrieve the current context chain for a buffer.
- **`lib.clear_buffer_data(bufnr)`** — Clear stored tree and context data.
- **`lib.adapt_lsp_str_to_num(str)`** — Convert LSP symbol kind name (e.g. `"Function"`) to its numeric kind (12). Returns 0 for unknown names.
- **`lib.adapt_lsp_num_to_str(num)`** — Convert LSP numeric kind to its string name. Returns `"Text"` for unknown numbers.

#### Tree node structure

```
{
  is_root = boolean,
  name = string,
  scope = { start = {line, character}, ["end"] = {line, character} },
  name_range = { ... },   -- same shape as scope
  kind = integer,         -- 1-26 per LSP spec
  index = integer,        -- 1-based index among siblings
  parent = node,
  children = { node, ... },
  prev = node,
  next = node,
}
```

#### Private helpers

- `symbol_relation(symbol, other)` — Determine spatial relation: `"before"`, `"after"`, `"around"`, or `"within"`.
- `symbolInfo_treemaker(symbols, root_node)` — Build tree from flat `SymbolInformation[]` (sorts by scope nesting, then walks with a stack).
- `dfs(curr_symbol_layer, parent_node)` — Build tree from hierarchical `DocumentSymbol[]`.
- `in_range(cursor_pos, range)` — Binary search helper: returns `-1` (behind), `0` (within), or `1` (ahead).
- `lsp_str_to_num` / `lsp_num_to_str` — Lookup tables for LSP `SymbolKind` enum (File=1 … TypeParameter=26). The config icon table also includes index `255` for Macro.

### `lualine/components/navic.lua`

lualine integration component. Extends `lualine.component`:

- `cond` — returns `navic.is_available()`.
- `color_correction` — `nil`, `"static"` (adjust highlight bg once at init), or `"dynamic"` (adjust on every update). Adjusts `NavicText`, `NavicSeparator`, and `NavicIcons*` backgrounds to match the current lualine section background.
- `navic_opts` — table in the same format as `setup`'s options (except `lsp` options). Passed through to `navic.get_location`.

## Configuration

```lua
local navic = require("nvim-navic")

navic.setup {
    icons = {
        File = "󰈙 ",
        Module = " ",
        -- ...
    },
    lsp = {
        auto_attach = false,
        preference = nil,
    },
    highlight = false,
    separator = " > ",
    depth_limit = 0,
    depth_limit_indicator = "..",
    safe_output = true,
    lazy_update_context = false,
    click = false,
    format_text = function(text)
        return text
    end,
}
```

### LSP integration

Manual attach:
```lua
require("lspconfig").clangd.setup {
    on_attach = function(client, bufnr)
        navic.attach(client, bufnr)
    end
}
```

Auto attach:
```lua
navic.setup {
    lsp = {
        auto_attach = true,
        preference = { "clangd", "pyright" }
    }
}
```

### Winbar / statusline usage

```lua
vim.o.winbar = "%{%v:lua.require'nvim-navic'.get_location()%}"
```

## Dependencies

- **Requires:**
  - Neovim >= 0.7.0
  - nvim-lspconfig (or equivalent LSP client configuration)
- **Used by:**
  - nvim-navbuddy (companion plugin for an interactive breadcrumbs UI)
  - lualine.nvim (via `lualine/components/navic.lua`)
  - feline.nvim, galaxyline (manual API integration)

## Global Variables

- `vim.g.navic_silence` — when `true`, suppresses warning/error notifications from navic.
- `vim.b.navic_lazy_update_context` — when `true` for a specific buffer, disables `CursorMoved` context updates for that buffer only.

## Highlight Groups

When `highlight = true`, the following groups must be defined (either by your colorscheme or manually via `vim.api.nvim_set_hl`):

- `NavicIconsFile`, `NavicIconsModule`, `NavicIconsNamespace`, `NavicIconsPackage`, `NavicIconsClass`, `NavicIconsMethod`, `NavicIconsProperty`, `NavicIconsField`, `NavicIconsConstructor`, `NavicIconsEnum`, `NavicIconsInterface`, `NavicIconsFunction`, `NavicIconsVariable`, `NavicIconsConstant`, `NavicIconsString`, `NavicIconsNumber`, `NavicIconsBoolean`, `NavicIconsArray`, `NavicIconsObject`, `NavicIconsKey`, `NavicIconsNull`, `NavicIconsEnumMember`, `NavicIconsStruct`, `NavicIconsEvent`, `NavicIconsOperator`, `NavicIconsTypeParameter`
- `NavicText` — text color
- `NavicSeparator` — separator color

## Coding Conventions

- Lua module pattern (`local M = {}`).
- LSP symbol kinds are referenced by numeric index (matching the LSP `SymbolKind` enum).
- Buffer-local data stored via `vim.b[bufnr]` (e.g. `navic_client_id`, `navic_client_name`).
- Autocommands managed via the `"navic"` augroup.
- Context tracking uses autocommands (`CursorMoved`, `CursorHold`), not extmarks.
- `safe_output` replaces `%` with `%%` and newlines with spaces to prevent statusline breakage.
- `format_data` deep-copies global config when per-call `opts` are supplied, so callers can override without side effects.
