# nlsp-settings.nvim

Configure Neovim LSP servers using JSON or YAML settings files (similar to VS Code's `coc-settings.json`), with live reloading via `workspace/didChangeConfiguration`. Integrates tightly with `nvim-lspconfig`. Supports JSON Schema-powered autocompletion when used with `jsonls`.

## Directory Structure

```
nlsp-settings.nvim/
├── LICENSE                          # MIT
├── Makefile                         # formatting target (stylua)
├── README.md
├── .luacheckrc                      # luajit std, codes=true, globals={vim}
├── stylua.toml                      # formatter config
├── plugin/
│   └── nlspsetting.vim              # Vim command definitions + bootstrap guard
├── lua/
│   ├── nlspsettings.lua             # Core module: setup(), get_settings(), update_settings()
│   └── nlspsettings/
│       ├── config.lua               # Configuration state & defaults
│       ├── deprecated.lua           # Backwards-compat shims (NlspConfig etc.)
│       ├── log.lua                  # Logging with optional nvim-notify
│       ├── schemas.lua              # Schema discovery (generated + local)
│       ├── utils.lua                # Table/list merge helpers
│       ├── command/
│       │   ├── completion.lua       # Completion for :LspSettings
│       │   ├── init.lua             # Command implementation (:LspSettings actions)
│       │   └── parser.lua           # CLI arg parser for :LspSettings
│       └── loaders/
│           ├── json.lua             # JSON loader (jsonls)
│           └── yaml/
│               ├── init.lua         # YAML loader (yamlls)
│               └── tinyyaml.lua     # Vendored YAML parser dependency
├── schemas/
│   ├── _generated/                  # Auto-generated JSON schemas per server
│   └── README.md
├── scripts/
│   ├── gen_schemas.lua              # Schema generation script (Lua)
│   ├── gen_schemas.sh               # Runner script (nvim --headless)
│   └── gen_schemas_readme.lua       # Regenerates schemas/README.md
├── examples/
│   ├── rust_analyzer.json
│   └── sumneko_lua.json
├── doc/
│   └── nlspsettings.txt
└── .github/workflows/
    ├── gen_schemas.yml              # CI: regenerate schemas hourly + on dispatch
    └── stylua_check.yml             # CI: style check on push/PR
```

## Core Modules

| Module | Role |
|---|---|
| `nlspsettings.lua` | **Core**. Loads settings files, merges priorities, manages `servers` state table, provides `setup()` and `update_settings()`, hooks `lspconfig.util.default_config`. |
| `config.lua` | Owns `config.values` (singleton). Stores defaults and exposes `set_default_values()` / `get()`. |
| `schemas.lua` | Discovers JSON schema files from `schemas/` and `schemas/_generated/`. Exposes `get_base_schemas_data()` (server->path map) and `get_langserver_names()`. Handles Windows path setup and `debug.getinfo`-based module path resolution. |
| `command/init.lua` | Implements `:LspSettings` subcommands: open global/local config, open buffer-matching config, trigger live update. Handles directory creation, server resolution via active clients, and `_BufWritePost` watcher callback. |
| `command/parser.lua` | Pure parser for `:LspSettings` arguments. Validates flags (`buffer`, `local`, `update`) and server names, resolves action. Raises Lua errors on malformed input. |
| `command/completion.lua` | Provides tab-completion for server names and flags via schemas. |
| `loaders/json.lua` | Loader implementing `load(path)` -> table, `get_default_schemas()` -> list of `{fileMatch, url}`. Uses `vim.fn.json_decode`. Sets `file_ext = 'json'`, `server_name = 'jsonls'`, `settings_key = 'json'`. |
| `loaders/yaml/init.lua` | Loader implementing `load(path)` -> table via `tinyyaml`. `get_default_schemas()` -> table of `{url: globPattern}`. Sets `file_ext = 'yml'`, `server_name = 'yamlls'`, `settings_key = 'yaml'`. |
| `loaders/yaml/tinyyaml.lua` | Vendored Lua YAML parser from `api7/lua-tinyyaml`. |
| `log.lua` | Wraps `vim.notify` / `nvim-notify` (configurable). Exposes `.info`, `.warn`, `.error`. Supports once-via `log_once`. |
| `utils.lua` | `extend()` -- deep-merges tables; warns if mixing list+table schemas. |
| `deprecated.lua` | Shims for old `NlspConfig`, `NlspLocalConfig`, `NlspBufConfig`, `NlspLocalBufConfig`, `NlspUpdateSettings` commands. |
| `plugin/nlspsetting.vim` | Bootstraps `g:loaded_nlspsettings`, defines `:LspSettings` and deprecated commands. |

## Core Module Internals (`nlspsettings.lua`)

### State

```lua
---@class nlspsettings.server_settings
---@field global_settings table
---@field conf_settings table

---@type table<string, nlspsettings.server_settings>
local servers = {}
```

The `servers` table is keyed by server name. Each entry holds `global_settings` (from `config_home`) and `conf_settings` (captured from `new_config.settings` before override).

### Key Functions

- `lsp_table_to_lua_table(t)` -- Converts dot-separated keys (e.g. `"Lua.workspace.library"`) into nested Lua tables.
- `load(path)` -- Reads a settings file via the active loader, returns `(data, err)`.
- `get_server_name_from_path(path)` -- Extracts server name from a filename (e.g. `rust_analyzer.json` -> `rust_analyzer`).
- `load_global_setting(path)` -- Loads a single global settings file into `servers[name].global_settings`.
- `get_settings(root_dir, server_name)` -- Merges local, global, and conf settings with `'keep'` priority (see below). For the loader's own server (e.g. `jsonls`), injects default schemas when `append_default_schemas` is true.
- `update_settings(server_name)` -- Reloads global settings, then notifies all active clients via `workspace/didChangeConfiguration` and updates `client.config.settings`.
- `make_on_new_config(on_new_config)` -- Wraps an existing `on_new_config` hook to capture `conf_settings` and replace `new_config.settings` with merged settings.
- `setup_autocmds()` -- Creates the `LspSettings` augroup with a `BufWritePost` autocmd watching `*/<config_home_name>/*.ext` and `*/<local_settings_dir>/*.ext`.
- `setup_default_config()` -- Patches `lspconfig.util.default_config` with the `on_new_config` hook.
- `get_settings_files(path)` -- Returns a list of settings files under a directory (uses `vim.loop.fs_scandir`).
- `load_settings()` -- Loads all settings files from `config_home`.

## Setup Function Signature

```lua
require('nlspsettings').setup(opts?)
```

### Configuration Options (`nlspsettings.config.values`)

| Option | Type | Default | Purpose |
|---|---|---|---|
| `config_home` | `string` | `stdpath('config') .. '/nlsp-settings'` | Directory holding global settings files (`<server>.<ext>`) |
| `local_settings_dir` | `string` | `".nlsp-settings"` | Local (project-root) settings directory name |
| `local_settings_root_markers_fallback` | `string[]` | `{'.git', '.nlsp-settings'}` | Fallback root markers if lspconfig has no root dir |
| `ignored_servers` | `string[]` | `{}` | Servers to skip in buffer-server selection |
| `append_default_schemas` | `boolean` | `false` | Whether to inject stored JSON schemas into loader server settings |
| `open_strictly` | `boolean` | `false` | Restrict `:LspSettings` server arg to known schemas |
| `nvim_notify.enable` | `boolean` | `false` | Use `rcarriga/nvim-notify` for notifications |
| `nvim_notify.timeout` | `number` | `5000` | Notification timeout ms |
| `loader` | `'json' \| 'yaml'` | `'json'` | Which loader to use (`nlspsettings.loaders.<name>`) |

## Dependencies

**Required**:
- Neovim (uses `vim.lsp.get_active_clients`, `vim.tbl_extend`, `vim.tbl_deep_extend`, `vim.notify_once`, `vim.loop`, `vim.validate`, `vim.log.levels`)
- `nvim-lspconfig` (mandatory -- the plugin hooks its `default_config`)

**Optional**:
- `rcarriga/nvim-notify` -- richer notifications (opt-in via config)
- `mason.nvim` / `mason-lspconfig.nvim` -- recommended for installing LSP servers including `jsonls`
- `jsonls` LSP -- for JSON Schema completion of settings files
- `tinyyaml` (vendored under `loaders/yaml/tinyyaml.lua`) -- only needed when `loader = 'yaml'`

## Integration with nvim-lspconfig

1. `setup()` patches `lspconfig.util.default_config` with an `on_new_config` hook (`make_on_new_config`).
2. The hook runs before any user config (via `add_hook_before`) and:
   - Saves the server's `default_config.settings` + `setup({settings=...})` as `conf_settings`.
   - Replaces `new_config.settings` with the merged result of `get_settings(root_dir, server_name)`.
3. Settings priority (deep-extend with `'keep'`, so earlier tables win):
   1. Local settings (`<root>/.nlsp-settings/<server>.<ext>`)
   2. Global settings (`config_home/<server>.<ext>`)
   3. `setup({settings=...})` and `default_config.settings` (merged into `conf_settings`)
4. On `BufWritePost` to any settings file -> `_BufWritePost` -> reloads + notifies the server via `workspace/didChangeConfiguration`, updates `client.config.settings`.
5. For the loader's own server (e.g. `jsonls`), `append_default_schemas=true` injects fileMatch-schema entries so the server validates/completes the settings files.

## Build / Test / Format Commands

From the Makefile:

```makefile
fmt:
	stylua --config-path stylua.toml --glob 'lua/**/*.lua' --glob '!lua/**/tinyyaml.lua' -- lua
```

- No test suite / CI test runner (only `fmt` and CI workflows for stylua check and schema generation).
- `scripts/gen_schemas.lua` regenerates `schemas/_generated/*` from upstream nvim-lspconfig (fetches package.json URLs from a gist), run via `scripts/gen_schemas.sh` in CI (`gen_schemas.yml`) on an hourly schedule.

## Coding Conventions

- **Language**: Lua 5.1 / LuaJIT (Neovim runtime). Uses `vim.loop` for fs ops.
- **Module pattern**: Each file returns a module table `M = {}` / `local M`. State is module-level (`servers`, `loader`).
- **Annotations**: EmmyLua doc-comments (`---@class`, `---@field`, `---@param`, `---@return`) throughout.
- **Validation**: `vim.validate {}` on public inputs (`path`, `server_name`, `opts`).
- **Path handling**: Uses `lspconfig.util.path` (`is_dir`, `is_file`, `join`, `sanitize`, `root_pattern`); Windows-aware (`os_uname().version`).
- **Style** (stylua.toml): 2-space indent, `AutoPreferSingle` quotes, `no_call_parentheses`.
- **Linting** (.luacheckrc): `std = luajit`, `codes = true`, global `vim`.
- **Comments**: Mix of English and Japanese (developer notes in Japanese).
- **Error handling**: Uses `pcall` around parsers; errors returned as boolean or logged via `nlspsettings.log.error`.
- **Settings merging**: Deep-copies where needed (`vim.deepcopy`) to avoid mutating user input on merge.
- **Autocmd group**: `LspSettings` augroup, watches `*/<config_home_name>/*.ext` and `*/<local_settings_dir>/*.ext`.
- **Vendored dep**: `tinyyaml.lua` is explicitly excluded from stylua formatting (not from luacheck).
