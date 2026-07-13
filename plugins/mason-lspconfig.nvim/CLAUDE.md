# CLAUDE.md — mason-lspconfig.nvim

This file provides guidance to Claude Code when working with the code in this repository.

## Project Overview

`mason-lspconfig.nvim` is a bridge plugin between [mason.nvim](https://github.com/williamboman/mason.nvim) and [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig). Its core responsibility is to make servers installed via Mason work seamlessly with lspconfig, simplifying the installation and configuration of LSP servers.

Main features:
- Registers an `on_setup` hook with `lspconfig`, ensuring servers installed via mason are automatically set up with the correct configuration
- Provides convenience APIs (e.g., `:LspInstall` / `:LspUninstall` commands)
- Supports auto-installation of a predefined list of servers (`ensure_installed`)
- Supports auto-installation of all servers set up via lspconfig (`automatic_installation`)
- Performs bidirectional mapping between lspconfig server names and mason package names (e.g., `lua_ls <-> lua-language-server`)
- Provides a `handlers` mechanism for automatic server setup (instead of manually calling `lspconfig.xxx.setup`)

**Important**: The plugin API uses lspconfig server names — not mason.nvim package names.

## Directory Structure

```
mason-lspconfig.nvim/
├── lua/mason-lspconfig/                  -- Main plugin modules
│   ├── init.lua                          -- Entry point; exports setup() / setup_handlers() / get_mappings() and other public APIs
│   ├── settings.lua                      -- Default configuration (ensure_installed, automatic_installation, handlers)
│   ├── lspconfig_hook.lua                -- Registers lspconfig.on_setup hook, injects mason config into the setup flow
│   ├── ensure_installed.lua              -- Auto-installation logic for the ensure_installed option
│   ├── install.lua                       -- Handles single-package install() and notifications
│   ├── notify.lua                        -- Unified notification wrapper (title = "mason-lspconfig.nvim")
│   ├── version.lua                       -- Version info (auto-managed by release-please)
│   ├── server_config_extensions.lua      -- Server config extensions (e.g., registers omnisharp_mono alias)
│   ├── typescript.lua                    -- TypeScript SDK lookup utility (tsdk / tsserver path resolution)
│   ├── mappings/                         -- Name mapping tables
│   │   ├── server.lua                    -- lspconfig <-> mason bidirectional mapping table
│   │   ├── language.lua                  -- Language name -> package name list mapping (dynamically built from mason registry)
│   │   └── filetype.lua                  -- filetype -> server name mapping (auto-generated)
│   ├── server_configurations/            -- Per-server extra configuration factories (install_dir -> config table)
│   │   ├── pylsp/init.lua                -- Provides :PylspInstall command for installing plugins
│   │   ├── julials/init.lua              -- Julia environment path detection
│   │   ├── volar/init.lua                -- TypeScript SDK resolution for Vue
│   │   └── ... (26 server configurations)
│   └── api/
│       └── command.lua                   -- Registers :LspInstall / :LspUninstall user commands
├── tests/                                -- Test suite
│   ├── minimal_init.vim                  -- Test bootstrap script (loads dummy registry)
│   ├── mason-lspconfig/
│   │   ├── setup_spec.lua                -- Tests for setup() / setup_handlers()
│   │   └── api/
│   │       ├── api_spec.lua              -- Public API tests
│   │       └── command_spec.lua          -- :LspInstall / :LspUninstall command tests
│   └── helpers/
│       └── lua/
│           ├── test_helpers.lua           -- Async test utilities / mockx / TableMock
│           ├── luassertx.lua              -- luassert extensions
│           └── dummy-registry/           -- Dummy mason package registry for tests
│               ├── index.lua
│               ├── dummy_package.lua
│               ├── dummy2_package.lua
│               └── fail_dummy.lua
├── scripts/                              -- Maintenance scripts
│   └── lua/mason-scripts/mason-lspconfig/generate.lua  -- Generator scripts (e.g., filetype mapping)
├── doc/                                  -- Documentation directory
├── Makefile                              -- Build / test / dependency management
├── selene.toml                           -- selene linter configuration
├── stylua.toml                           -- stylua formatter configuration
└── .editorconfig                         -- Editor indentation / line endings configuration
```

## Core Modules

| Module | File | Responsibility |
|--------|------|----------------|
| `init` | `init.lua` | Plugin entry point. Exports `setup()`, `setup_handlers()`, `get_installed_servers()`, `get_available_servers(filter)`, `get_mappings()` |
| `settings` | `settings.lua` | Stores and manages `MasonLspconfigSettings` (with `set()` method) |
| `lspconfig_hook` | `lspconfig_hook.lua` | Registers `util.on_setup` hook, intercepts lspconfig setup flow: injects mason config, handles Windows cmd paths, auto-installs |
| `ensure_installed` | `ensure_installed.lua` | Iterates `ensure_installed` list at `setup()` time and installs missing servers |
| `install` | `install.lua` | Wraps `pkg:install()` and sends success/failure notifications |
| `notify` | `notify.lua` | Unified notification wrapper: `vim.notify(msg, level, { title = "mason-lspconfig.nvim" })` |
| `mappings/server` | `mappings/server.lua` | Bidirectional mapping table: `lspconfig_to_package` and `package_to_lspconfig` (reverse auto-generated via `_.invert`) |
| `mappings/language` | `mappings/language.lua` | Dynamically builds language-to-package-name mapping from the registry |
| `mappings/filetype` | `mappings/filetype.lua` | filetype -> server name list (**auto-generated file, do not edit manually**) |
| `api/command` | `api/command.lua` | Registers `:LspInstall` and `:LspUninstall` commands, supports filetype inference and keyboard completion |

## Public API

```lua
---@param config MasonLspconfigSettings | nil
function M.setup(config)

---@param handlers table<string, fun(server_name: string)>
function M.setup_handlers(handlers)  -- default handler is at handlers[1]

---@return string[]  -- list of installed lspconfig server names
function M.get_installed_servers()

---@param filter { filetype: string | string[] }?: optional
---@return string[]  -- list of available lspconfig server names
function M.get_available_servers(filter)

---@return { lspconfig_to_mason: table, mason_to_lspconfig: table }
function M.get_mappings()
```

## Configuration

The plugin must be initialized in the following order:
1. `require("mason").setup()`
2. `require("mason-lspconfig").setup()`
3. Set up servers via `lspconfig` (or use `handlers` for automatic setup)

### Setup Function

```lua
require("mason-lspconfig").setup {
    -- Automatically install specified servers (unaffected by automatic_installation)
    ---@type string[]
    ensure_installed = { "lua_ls", "rust_analyzer" },

    -- Whether to automatically install servers set up via lspconfig
    -- false | true | { exclude: string[] }
    ---@type boolean | { exclude: string[] }
    automatic_installation = false,

    handlers = {
        -- Default handler (at index [1], matches all servers)
        function(server_name)
            require("lspconfig")[server_name].setup {}
        end,
        -- Server-specific handler
        ["rust_analyzer"] = function(server_name)
            require("lspconfig").rust_analyzer.setup {
                settings = { ["rust-analyzer"] = { ... } }
            }
        end,
    },
}
```

`setup_handlers()` iterates installed servers, preferring a matching named handler, otherwise falling back to `handlers[1]` (the default handler). Handlers are also triggered after a successful install.

### Configuration Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `ensure_installed` | `string[]` | `{}` | List of servers to auto-install; supports `"name@version"` format |
| `automatic_installation` | `boolean \| { exclude: string[] }` | `false` | Whether to auto-install missing servers when lspconfig sets them up |
| `handlers` | `table<string, fun(server_name)>?` | `nil` | Handler table for automatic server setup |

### Server Configuration Factories

Modules under `server_configurations/` export a factory function that takes an `install_dir` argument and returns a config table (usually containing an `on_new_config` callback). These configs are injected into lspconfig's `setup()` flow via `lspconfig_hook` when the corresponding server is installed by mason.

Typical pattern:
```lua
return function(install_dir)
    return {
        on_new_config = function(new_config, workspace_dir)
            -- Derive correct cmd/init_options based on install_dir and workspace_dir
        end,
    }
end
```

User-provided config has the highest priority (user_config > mason_config > default_config).

## Dependencies

### Required Dependencies

| Package | Purpose |
|---------|---------|
| [mason.nvim](https://github.com/williamboman/mason.nvim) | LSP/DAP/linters/formatters package manager core (provides `mason-registry`, `mason-core`) |
| [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | Neovim built-in LSP client configuration (provides `lspconfig.util.on_setup` hook) |

### Runtime Dependencies (from mason-core)

- `mason-core.functional` (`_`) — Functional programming utilities (`_.map`, `_.filter`, `_.compose`, `_.cond`, `_.reduce`, etc.)
- `mason-core.optional` (`Optional`) — Optional value handling (`of_nilable`, `or_`, `if_present`, `if_not_present`)
- `mason-core.async` (`a`) — Async operations (`a.scope`, `a.promisify`, `a.scheduler`)
- `mason-core.log` — Logging module
- `mason-core.path` — Path joining
- `mason-core.platform` — Platform detection (`is_headless`, `is.win`)
- `mason-core.package` (`Package`) — Package parsing (`Package.Parse` for `"name@version"` format)
- `mason-core.fs` — Filesystem operations
- `mason-core.managers.pip3` / `mason-core.process` / `mason-core.spawn` — Process management (used by pylsp, etc.)

### Test Dependencies

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) — Test framework (`plenary.test_harness`)
- [luassert](https://github.com/lunarmodules/luassert) — Assertion library (`spy`, `stub`, `match`)
- [neotest](https://github.com/nvim-neotest/neotest) — Test framework (fetched in Makefile)

## Build / Test

### Running Tests

```bash
make test
```

`make test` will:
1. Clean test fixtures (`clean_fixtures`)
2. Clone dependencies into `dependencies/` (mason.nvim, plenary.nvim, nvim-lspconfig, neotest)
3. Launch Neovim in headless mode, load `tests/minimal_init.vim`, run `plenary.test_harness`

Environment variables:
- `INSTALL_ROOT_DIR` — Mason installation directory (default `$(pwd)/tests/fixtures/mason`)
- `NVIM_HEADLESS` — Headless nvim command

### Other Make Targets

| Target | Description |
|--------|-------------|
| `make dependencies` | Fetch test dependencies |
| `make clean` | Clean fixtures and dependencies |
| `make clean_dependencies` | Clean only dependencies |
| `make clean_fixtures` | Clean only installation fixtures |
| `make generate` | Run generator scripts (e.g., filetype mapping) |

### Test Structure

- `tests/minimal_init.vim` — Test bootstrap: sets runtimepath, loads dummy registry, registers dummy lspconfig servers
- `tests/helpers/lua/test_helpers.lua` — Provides `async_test()`, `mockx`, `TableMock`, `InstallHandleGenerator`, `InstallContextGenerator`
- `tests/helpers/lua/dummy-registry/` — Dummy mason packages (`dummy`, `dummy2`, `fail_dummy`)

## Coding Conventions

### Formatting

- **stylua** (`stylua.toml`): uses spaces for indentation, no function call parentheses, `sort_requires` enabled
- **editorconfig** (`.editorconfig`): 4-space indentation, LF line endings, UTF-8, max line width 120, auto-insert final newline, trim trailing whitespace
- **cbfmt** (`.cbfmt.toml`): Markdown formatting

### Lint

- **selene** (`selene.toml`): standard library mode `lua51+vim`, allows `unused_variable` and `shadowing`

### Naming Conventions

- Modules use `snake_case` (e.g., `mason-lspconfig.ensure_installed`)
- Local variables use `snake_case` (e.g., `server_name`, `pkg_name`, `user_config`)
- Exported tables use `PascalCase` `M` or specific names (e.g., `local M = {}`)
- Type annotations use `---@class` / `---@param` / `---@return` (EmmyLua style)
- Functional programming style: heavy use of `mason-core.functional` (`_.map`, `_.filter`, `_.compose`, `_.cond`, `_.reduce`)
- Optional pattern: use `Optional.of_nilable()` / `:or_()` / `:if_present()` / `:if_not_present()` for nullable values
- Async pattern: use `a.scope()` to wrap async functions, `a.promisify()` to convert callback-style APIs

### Code Style Highlights

- Use `_.curryN` for function currying
- Use `_.cond` for pattern-matching-style conditional branching
- Use `_.memoize` to cache pure function results
- Use `vim.schedule_wrap` to ensure callbacks execute in the correct context
- Use `pcall` to guard potentially failing calls (e.g., `require`, `registry.get_package`)
- Use `log.fmt_trace` / `log.fmt_error` for structured logging
- Notifications use `require "mason-lspconfig.notify"` wrapper to keep the title consistent

### Version Management

Version numbers are auto-managed by `release-please`, synced across:
- `lua/mason-lspconfig/version.lua` (`VERSION`, `MAJOR_VERSION`, `MINOR_VERSION`, `PATCH_VERSION`)
- `README.md` (`<!-- x-release-please-version -->` comment marker)
