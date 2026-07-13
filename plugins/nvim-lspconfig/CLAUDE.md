# nvim-lspconfig

## Project Overview

nvim-lspconfig is a collection of declarative configurations for the Neovim built-in LSP client. It provides configurations, launch, and initialization methods for 300+ language servers. This is a community-maintained project.

**Core philosophy:** Does NOT install language servers themselves, only provides configurations. Users need to install the corresponding language server executables themselves.

## Directory Structure

```
nvim-lspconfig/
├── LICENSE.md
├── README.md
├── CONTRIBUTING.md
├── Makefile                    # `make test` and `make lint` targets
├── flake.nix / flake.lock      # Nix build configuration
├── nvim-lspconfig-scm-1.rockspec  # LuaRocks package definition
├── .luacheckrc                 # Lua static analysis configuration
├── .stylua.toml                # Code formatting configuration (stylua)
├── selene.toml                 # Selene linter configuration (std = "neovim")
├── neovim.yml                  # Neovim type definitions for sumneko-lua-language-server
├── doc/
│   ├── lspconfig.txt           # Vim help docs (:h lspconfig)
│   ├── server_configurations.md   # All supported servers list (auto-generated via docgen)
│   └── server_configurations.txt
├── plugin/
│   └── lspconfig.lua           # Plugin entry point, defines user commands and highlight groups
├── lua/
│   ├── lspconfig.lua           # Main module, provides the `lspconfig` table with lazy-loading metatable
│   └── lspconfig/
│       ├── configs.lua         # Configuration registration and management core logic
│       ├── manager.lua         # LSP client manager (per-root-dir client tracking)
│       ├── async.lua           # Async utilities (coroutine-based async.run, async.run_command, async.reenter)
│       ├── util.lua            # General utilities (path handling, root directory detection, etc.)
│       ├── ui/
│       │   ├── lspinfo.lua     # :LspInfo window implementation
│       │   └── windows.lua     # Floating window UI utilities (extracted from plenary.nvim)
│       └── server_configurations/  # 308 server configuration files
│           ├── pyright.lua
│           ├── lua_ls.lua
│           ├── rust_analyzer.lua
│           └── ...
├── scripts/
│   ├── docgen.lua              # Documentation generation script
│   ├── docgen.sh               # Shell wrapper for docgen.lua
│   └── README_template.md      # Template for generating server_configurations.md
├── test/
│   ├── minimal_init.lua        # Minimal test configuration
│   ├── lspconfig_spec.lua      # Test cases (uses vusted)
│   └── test_dir/               # Test fixtures
└── .github/                    # CI/CD configuration (codespell, lint, test, docgen, release, etc.)
```

## Core Modules

### `lspconfig` (lua/lspconfig.lua)

Main entry module. Uses a metatable for lazy loading — accessing `lspconfig.<server_name>` automatically loads the corresponding configuration from `lspconfig.server_configurations.<server_name>`.

- **`lspconfig.<server_name>.setup(user_config)`** — Configure and set up autostart for the specified language server
- **`lspconfig.<server_name>.launch(bufnr?)`** — Manually launch the server for a buffer
- **`lspconfig.<server_name>.manager`** — The `lspconfig.Manager` instance for this server
- **`lspconfig.util`** — General utility module

Supports server aliases (e.g., `sumneko_lua` → `lua_ls`, `ruby_ls` → `ruby_lsp`, `fennel-ls` → `fennel_ls`, `starlark-rust` → `starlark_rust`), emitting deprecation warnings via `vim.deprecate`.

### `lspconfig.configs` (lua/lspconfig/configs.lua)

Configuration registry. Uses a metatable intercepting `__newindex` to register new server configurations.

Key functions:
- **`configs.__newindex(t, config_name, config_def)`** — Register a new configuration, validate fields, create `M.setup()` and `M.launch()` methods
- **`M.setup(user_config)`** — Merge user config with default config, set up autocommands for autostart
- **`M.launch(bufnr)`** — Manually start the server (determines root_dir, attaches existing or starts new)
- **`M._setup_buffer(client_id, bufnr)`** — Set up buffer-local configuration (on_attach, commands)

Configuration definition format (`config_def`):
```lua
{
    default_config = {
        cmd = { "server", "args" },
        filetypes = { "python" },
        root_dir = function(...) end,
        single_file_support = true,
        settings = { ... },
        init_options = { ... },
        capabilities = { ... },
        handlers = { ... },
        autostart = true,        -- default: true
        -- deprecate = { to = "new_name", version = "0.2.0" },  -- optional deprecation
    },
    on_new_config = function(config, root_dir) end,  -- called before server start
    on_attach = function(client, bufnr) end,
    commands = {
        CommandName = { function(...) end, description = "...", nargs = 1, complete = 'file' },
    },
    docs = {
        description = [[ ... ]],
        default_config = { root_dir = [[...]] },
    },
}
```

Important behaviors in `setup()`:
- User config is merged with default config via `vim.tbl_deep_extend('keep', user_config, default_config)`
- `on_new_config` is called twice: first from `config_def.on_new_config`, then from `user_config.on_new_config`
- `autostart` (default `true`) creates an autocmd on `FileType` (or `BufReadPost` if no filetypes) that calls `manager:try_add`
- The `on_attach` is wrapped so that `_setup_buffer` is deferred via `BufEnter` if the buffer isn't current
- `workspace_did_change_configuration` is patched onto the client to send settings
- `offset_encoding` is auto-detected from `result.offsetEncoding` in `on_init`

### `lspconfig.manager` (lua/lspconfig/manager.lua)

LSP client manager, responsible for:
- Tracking client instances per `root_dir`
- Handling `workspace/didChangeWorkspaceFolders` for multi-root workspaces
- Supporting single-file mode (`single_file_support`)
- Reusing existing clients when opening buffers in the same workspace

Key methods:
- **`M.new(config, make_config)`** — Create a manager instance
- **`M:try_add(bufnr, project_root?)`** — Try to attach a buffer to a client (determines root_dir, handles single_file)
- **`M:try_add_wrapper(bufnr, project_root?)`** — Validates filetype matches before calling `try_add`
- **`M:add(root_dir, single_file, bufnr)`** — Add buffer to the client for the given root_dir (starts new client if needed)
- **`M:clients()`** — Get all clients managed by this manager

Internal methods:
- **`M:_start_new_client`** — Calls `vim.lsp.start_client(new_config)`, sets `cmd_cwd` to root_dir if available
- **`M:_attach_or_spawn`** — Attaches to existing client, registers workspace folders, or starts new client
- **`M:_attach_after_client_initialized`** — Polls `client.initialized` via timer before attaching
- **`M:_register_workspace_folders`** — Sends `workspace/didChangeWorkspaceFolders` to existing client

### `lspconfig.async` (lua/lspconfig/async.lua)

Async utilities based on Lua coroutines:
- **`async.run(func)`** — Runs `func` in a new coroutine, catches errors and reports via `vim.notify`
- **`async.run_command(cmd)`** — Runs a shell command asynchronously via `vim.fn.jobstart`, returns stdout lines or nil on failure
- **`async.reenter()`** — If inside a fast event, schedules a `vim.schedule` resume and yields (prevents "fast event" errors)

### `lspconfig.util` (lua/lspconfig/util.lua)

General utility module, providing:
- **`M.default_config`** — Default LSP configuration (`autostart = true`, `capabilities`, `settings`, `init_options`, `handlers`, `log_level`, `message_level`)
- **`M.on_setup`** — Global hook called after each server's `setup()` (set by external plugins like mason-lspconfig)
- **`M.path`** — Path utilities: `sanitize`, `dirname`, `is_dir`, `is_file`, `is_absolute`, `is_fs_root`, `exists`, `join`, `traverse_parents`, `iterate_parents`, `is_descendant`, `escape_wildcards`, `path_separator`
- **`M.search_ancestors(startpath, func)`** — Walk up directory tree calling `func` on each ancestor
- **`M.root_pattern(...)`** — Create a root directory detection function based on file patterns (uses `vim.fn.glob`)
- **`M.find_git_ancestor(startpath)`** — Find `.git` root directory (supports worktrees via `.git` file)
- **`M.find_mercurial_ancestor(startpath)`** — Find `.hg` root directory
- **`M.find_node_modules_ancestor(startpath)`** — Find `node_modules` root directory
- **`M.find_package_json_ancestor(startpath)`** — Find `package.json` root directory
- **`M.insert_package_json(config_files, field, fname)`** — Add `package.json` to config_files if it contains the specified field
- **`M.bufname_valid(bufname)`** — Validate buffer name (absolute path, zipfile, tarfile)
- **`M.validate_bufnr(bufnr)`** — Validate buffer number (0 means current buffer)
- **`M.add_hook_before/after(func, new_fn)`** — Compose hook functions
- **`M.available_servers()`** — List all servers that have been set up (have a manager)
- **`M.get_config_by_ft(filetype)`** — Get all configs matching a filetype
- **`M.get_managed_clients()`** — Get all clients managed by lspconfig
- **`M.get_active_clients_list_by_ft(filetype)`** — Get names of active clients for a filetype
- **`M.get_other_matching_providers(filetype)`** — Get configs matching filetype that are NOT currently active
- **`M.get_active_client_by_name(bufnr, servername)`** — Get active client by name for a buffer
- **`M.strip_archive_subpath(path)`** — Strip virtual path suffix from `zipfile://` or `tarfile:` paths
- **`M.create_module_commands(module_name, commands)`** — Create user commands from a commands table
- **`M._parse_user_command_options(command_definition)`** — Parse lspconfig-style command options to nvim command attributes

### `plugin/lspconfig.lua`

Plugin entry point, executed on Neovim startup:
- Checks Neovim version (requires 0.8+)
- Defines highlight groups: `LspInfoBorder`, `LspInfoList`, `LspInfoTip`, `LspInfoTitle`, `LspInfoFiletype`
- Creates user commands:
  - `:LspInfo` — Display LSP status (attached, active, configured servers)
  - `:LspStart [server_name]` — Manually launch a server (by name or by current filetype)
  - `:LspStop [client_id] [++force]` — Stop client(s) (by ID or for current buffer)
  - `:LspRestart [client_id]` — Restart client(s) (stops then re-launches after detach)
  - `:LspLog` — Open the LSP log file

### `lspconfig.ui.windows` (lua/lspconfig/ui/windows.lua)

Floating window utilities (extracted and modified from plenary.nvim). Provides `win_float.percentage_range_window()` for creating centered floating windows with configurable size.

### `lspconfig.ui.lspinfo` (lua/lspconfig/ui/lspinfo.lua)

Implementation of the `:LspInfo` command. Displays information about attached, active, and configured language servers in a floating window.

## Configuration

```lua
-- Basic usage
require'lspconfig'.pyright.setup{}

-- With custom configuration
local lspconfig = require('lspconfig')
lspconfig.rust_analyzer.setup {
    settings = {
        ['rust-analyzer'] = {},
    },
    on_attach = function(client, bufnr)
        -- Set keybindings, etc.
    end,
}
```

### Adding a Custom Server

Create a new file in `lua/lspconfig/server_configurations/SERVER_NAME.lua`:

```lua
local util = require 'lspconfig.util'

return {
    default_config = {
        cmd = { 'my-lsp-server' },
        filetypes = { 'mylang' },
        root_dir = util.root_pattern('.git', 'myconfig.toml'),
    },
    docs = {
        description = [[
Description of the server.
]],
    },
}
```

**Server naming convention:** Convert all dashes (`-`) to underscores (`_`). Prefer the commonly used name or abbreviation (e.g., `pyright`, `clangd`, `zls`). For servers following the `x-language-server` pattern, use `x_ls` (e.g., `jsonnet_ls`).

## Dependencies

- **Requires:** Lua 5.1+, Neovim 0.8+
- **Consumed by:** Many plugins depend on nvim-lspconfig, such as:
  - mason.nvim (auto-installs LSP servers)
  - mason-lspconfig.nvim (bridges mason and lspconfig)
  - Various LSP-related plugins

## Build / Test

```bash
# Run tests (uses vusted)
make test

# Lint
make lint       # runs luacheck, selene, and stylua --check

# Generate documentation (auto-runs on push to master via CI)
nvim -R -Es +'set rtp+=$PWD' +'luafile scripts/docgen.lua'
# or:
sh scripts/docgen.sh
```

## Code Style & Conventions

- Code formatting: `.stylua.toml` (stylua, 120 column width, 2-space indent, single quotes)
- Lua static analysis: `.luacheckrc` (ignores 122, 212, 631)
- Selene linter: `selene.toml` (std = "neovim", relaxed rules)
- Server configurations use `snake_case` naming
- Configuration definitions must include `default_config` and `docs` fields
- Use `vim.validate` for input validation
- Use `vim.tbl_deep_extend('keep', ...)` for config merging
- Commit messages follow [conventional commit style](https://www.conventionalcommits.org/) (e.g., `feat: add lua-language-server support`)
- Do NOT edit `doc/server_configurations.md` or `doc/server_configurations.txt` directly — they are auto-generated by docgen from the `docs` table in each server's Lua file and `scripts/README_template.md`
