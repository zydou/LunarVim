# cmp-nvim-lsp

## Project Overview

cmp-nvim-lsp is an [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) completion source that bridges Neovim's built-in LSP client (`vim.lsp`) to nvim-cmp. It provides completion results from any active language server and also exports the `default_capabilities()` helper to advertise nvim-cmp-specific LSP capabilities (snippets, insert replace, label details, etc.) back to servers.

## Directory Structure

```
cmp-nvim-lsp/
├── LICENSE
├── README.md
├── .gitignore
├── doc/
│   └── cmp-nvim-lsp.txt     # Vim help file (currently only documents the FAQ)
├── after/
│   └── plugin/
│       └── cmp_nvim_lsp.lua # Calls require('cmp_nvim_lsp').setup() on load
└── lua/
    └── cmp_nvim_lsp/
        ├── init.lua           # Top-level module: capabilities helper, InsertEnter hook, client/source registration
        └── source.lua         # Per-client LSP source (complete, resolve, execute, request helpers)
```

## Core Modules

### `cmp_nvim_lsp.init.lua`

The top-level module `M`.

**Public API:**
- `M.setup()` — creates an `InsertEnter` autocommand under the `cmp_nvim_lsp` augroup. On each insert-enter, `_on_insert_enter` runs:
  1. Iterates **all active** LSP clients via `get_clients()` and registers any that lack a source yet.
  2. Iterates **buffer-scoped** clients via `get_clients({ bufnr = 0 })` to register clients for the current buffer early (before full activation).
  3. For each client, creates `source.new(client)`, checks `s:is_available()`, and registers it with `cmp.register_source('nvim_lsp', s)`.
  4. Unregisters and cleans up `client_source_map` entries for clients that are stopped or no longer attached.
- `M.default_capabilities(override?)` — returns a capability table declaring support for snippets, deprecated items, preselect, tag support, insert/replace, resolve, insert-text modes, label details, and completion-list item defaults. Individual fields are overridden via the `override` parameter using an `if_nil` helper.
- `M.update_capabilities(override)` — deprecated shim that forwards to `default_capabilities` and prints a deprecation warning (Neovim >= 0.9 native `vim.deprecate`, or a small ported fallback).
- `M.client_source_map` — table mapping `client.id → source_id` for cleanup.

Internals select between `vim.lsp.get_clients` (Neovim 0.10+) and `vim.lsp.get_active_clients` (older).

### `cmp_nvim_lsp.source.lua`

Per-client source. Created via `source.new(client)`.

**Public API:**
- `source:get_debug_name()` — `"nvim_lsp:<client.name>"`.
- `source:is_available()` — returns `false` if the client is stopped (via `is_stopped()`), not attached to the current buffer (filters with `get_clients({ bufnr, id })`), or lacks `completionProvider`.
- `source:get_position_encoding_kind()` — returns server's `positionEncoding`, falling back to `client.offset_encoding`, then `'utf-16'`.
- `source:get_trigger_characters()` — from `server_capabilities.completionProvider.triggerCharacters`.
- `source:get_keyword_pattern(params)` — supports per-server overrides via `params.option[<client.name>].keyword_pattern`, falling back to cmp's global `completion.keyword_pattern`.
- `source:complete(params, callback)` — sends `textDocument/completion` with `make_position_params` and a trigger context (kind + character).
- `source:resolve(completion_item, callback)` — sends `completionItem/resolve` when the server supports `resolveProvider`; bails early if the client is stopped.
- `source:execute(completion_item, callback)` — sends `workspace/executeCommand` when the item has a `.command`; bails early if the client is stopped or the item has no command.
- `source._request(method, params, callback)` — thin wrapper around `client.request` that cancels any in-flight request for the same method, retries once on `ContentModified` (`code == -32801`), and handles the old vs. new callback-arg signature across Neovim versions.
- `source._call_client_method(method_name, ...)` — compatibility shim for the dot-vs-colon method call change between Neovim 0.10 and 0.11+ (prevents deprecation warnings).
- `source._get(root, paths)` — generic object-path traversal; returns `nil` if any key along the path is missing.

## Configuration

```lua
-- 1. Register the source
require'cmp'.setup {
  sources = { { name = 'nvim_lsp' } },
}

-- 2. Advertise capabilities to LSP servers
local capabilities = require('cmp_nvim_lsp').default_capabilities()
require('lspconfig').clangd.setup { capabilities = capabilities }
```

Per-server keyword-pattern override:

```lua
cmp.setup {
  sources = {
    { name = 'nvim_lsp', option = {
      php = { keyword_pattern = [=[[\%(\$k*)|\k+]]=] },
    }},
  },
}
```

### `default_capabilities(override)` override fields

The `override` table accepts the following fields (each defaults to the value listed when omitted):

| Field | Default |
| --- | --- |
| `dynamicRegistration` | `false` |
| `snippetSupport` | `true` |
| `commitCharactersSupport` | `true` |
| `deprecatedSupport` | `true` |
| `preselectSupport` | `true` |
| `tagSupport` | `{ valueSet = { 1 } }` |
| `insertReplaceSupport` | `true` |
| `resolveSupport` | `{ properties = { "documentation", "additionalTextEdits", "insertTextFormat", "insertTextMode", "command" } }` |
| `insertTextModeSupport` | `{ valueSet = { 1, 2 } }` |
| `labelDetailsSupport` | `true` |
| `insertTextMode` | `1` |
| `completionList` | `{ itemDefaults = { 'commitCharacters', 'editRange', 'insertTextFormat', 'insertTextMode', 'data' } }` |

Note: `contextSupport` in the returned table reuses `override.snippetSupport` rather than a dedicated override key. This is an existing behavior of the code — add `snippetSupport = false` in the override to turn off both snippet and context support simultaneously.

## Dependencies

- **Runtime dependency:** [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) — must already be installed and loaded.
- **Provided capability:** This plugin is the canonical bridge between nvim-cmp and Neovim's built-in LSP; many Neovim distributions call it from their LSP configuration to produce `capabilities` for `lspconfig`.

## Build / Test

No build step or test suite. Pure Lua plugin loaded by Neovim at runtime.

## Coding Conventions

- Every class exposes `class.new(...)`; methods are defined as `function name(self, ...)` using a metatable `__index`.
- Heavy LuaCATS type annotations throughout.
- Constant defaults live at the top of `init.lua`; `if_nil(val, default)` is used instead of `val or default` to preserve explicit `false` values (important for capability flags).
- Careful Neovim version compatibility:
  - `vim.lsp.get_clients` vs `vim.lsp.get_active_clients` (0.10 boundary).
  - Dot vs. colon method dispatch via `_call_client_method` (0.11 boundary).
  - `ContentModified` retry logic in `_request`.
  - Old vs. new callback signature detection in `_request` callback (`method == arg2` check).
- Deprecation compatibility: local fallback of `vim.deprecate` keeps the plugin loadable on Neovim < 0.9.
- Help docs live in `doc/cmp-nvim-lsp.txt`.
