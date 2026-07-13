# neodev.nvim

Neovim development plugin that automatically configures **lua-language-server (lua_ls)** for Neovim config, runtime, and plugin directories. Provides full signature help, documentation, and completion for the Neovim Lua API (`vim.api`, `vim.opt`, `vim.loop`, `vim.treesitter`, `vim.lsp`, etc.) and properly sets up the `require` path so the LSP can resolve modules in `opt`/`start` and plugin directories.

- Requires Neovim >= 0.7.0
- Designed to be set up **BEFORE** `lspconfig` in user config
- Written and maintained by Folke (same author as lazy.nvim, neoconf.nvim, etc.)

## Directory Structure

```
neodev.nvim/
├── README.md                  # User-facing documentation
├── BUILD.md                   # Instructions for regenerating type docs
├── CHANGELOG.md               # Release history
├── LICENSE
├── doc/
│   ├── lua-dev.txt            # Legacy vimdoc
│   └── neodev.nvim.txt        # Generated vimdoc
├── lua/
│   ├── lua-dev.lua            # Legacy shim: warns + returns require("neodev")
│   └── neodev/
│       ├── init.lua           # Main entry: M.setup(opts)
│       ├── config.lua         # LuaDevOptions config class + defaults
│       ├── luals.lua          # Lua LS library/path/settings construction
│       ├── lsp.lua            # lspconfig hook into lua_ls + jsonls
│       ├── util.lua           # Helpers: find_root, fetch, read/write file, is_nvim_config
│       └── build/             # Code-generation pipeline (see Build section)
│           ├── init.lua       # Orchestrates generation (M.build()), runs on require
│           ├── api.lua        # Parses Neovim api_info() -> EmmyLua annotations
│           ├── annotations.lua # EmmyLua class/alias formatting helpers
│           ├── docs.lua       # vim.fn/command/lua/luv documentation sources
│           ├── mpack.lua      # Reader for .mpack API extracts
│           ├── options.lua    # Generates vim.opt annotations
│           └── writer.lua     # File writer for generated type stubs (splits at 200KB)
├── types/
│   ├── stable/                # Pre-generated EmmyLua annotations (Neovim < 0.10)
│   │   ├── api.lua, alias.lua, cmd.lua, lpeg.lua, lua.lua,
│   │   ├── options.lua, options.{1,2,3}.lua,
│   │   ├── uv.lua, vim.fn.lua, vim.fn.1.lua, vim.lua
│   ├── nightly/               # Pre-generated annotations (Neovim >= 0.10)
│   │   ├── alias.lua, cmd.lua, uv.lua, vim.lua
│   └── override/              # Manual overrides applied on top of generated files
│       ├── api.lua, lua.lua, options.lua, vim.fn.lua
├── stylua.toml                # Formatter config (2-space indent, 120 col width)
├── selene.toml                # Linter config (std="lua51+vim")
├── vim.toml                   # Type-check config: {vim.any = true}
├── .neoconf.json              # Project-local LSP config
└── .github/workflows/
    ├── ci.yml                 # Tests, docs generation, release
    └── types.yml              # Hourly cron to regenerate type stubs
```

> **Note on split files:** `build/writer.lua` splits output when a file exceeds `MAX_SIZE` (200KB), appending `.1`, `.2`, etc. before the `.lua` extension. This is why `options.lua`/`vim.fn.lua` have `.1/.2/.3` siblings.

## Core Modules

| Module | Responsibility |
|---|---|
| **`neodev/init.lua`** | Public API. `M.setup(opts)` applies config, sets up the lspconfig hook, and registers as a neoconf plugin. Also registers `LuaDevOptions` as a Neoconf schema (supporting `boolean` or `string[]` for `plugins`). Returns a legacy shim `{settings = {legacy = true}}`. |
| **`neodev/config.lua`** | Holds `M.defaults` (LuaDevOptions), `M.options` (merged user opts), `M.setup()`, `M.types()`, `M.root()`, `M.version()` (returns `"nightly"` or `"stable"`), and `M.merge()`. Also stores the `debug` flag. |
| **`neodev/luals.lua`** | Builds the Lua LS configuration: `M.library(opts)` returns a list of workspace library paths (runtime `$VIMRUNTIME`, plugins from packpath or lazy.nvim, type stubs); `M.path(settings)` returns the `pathStrict` pattern (`?.lua`, `?/init.lua`) or custom meta paths; `M.setup(opts, settings)` returns the full `settings.Lua` table for lua_ls. |
| **`neodev/lsp.lua`** | Hooks into `lspconfig.util.on_setup` to intercept `lua_ls` and `jsonls` setup. For jsonls: adds the LuaLS schema for `.luarc.json`. For lua_ls: registers `on_new_config` that determines options based on the buffer location — enabled when the buffer is under `vim.fn.stdpath("config")` or under any directory containing a `/lua` subdirectory (plugin root, with `plugins` disabled); disabled elsewhere. It then applies the user `override`, handles the `workspace/configuration` handler to avoid setting fallback-scope workspace libraries, and deep-merges the neodev settings. |
| **`neodev/util.lua`** | Pure helpers: `find_root()` finds the nearest ancestor directory containing `lua`; `fetch()` downloads via `curl`; `is_nvim_config()` checks whether the current buffer is under `vim.fn.stdpath("config")`; `keys()`/`for_each()` sort keys for deterministic iteration; `read_file`/`write_file`/`debug`/`error`/`warn` utilities. |
| **`neodev/build/*`** | **Not part of runtime** — a self-bootstrapping Lua script run only during type regeneration (see Build section). |

## Setup Function Signature

```lua
---@param opts? LuaDevOptions
function M.setup(opts)
```

The `LuaDevOptions` class (defined in `config.lua`):

```lua
--- @class LuaDevOptions
{
  library = {
    enabled = true,          -- master on/off toggle for changing LSP settings
    ---@type boolean|string
    runtime = true,          -- true = use $VIMRUNTIME; or a custom path string
    types = true,            -- full signature/docs/completion for vim.api, treesitter, lsp, etc.
    ---@type boolean|string[]
    plugins = true,          -- true = all opt/start plugins; or an explicit list of plugin names
  },
  setup_jsonls = true,       -- configures jsonls to validate .luarc.json files
  override = function(root_dir, options) end,  -- user hook to customize per-root library options
  lspconfig = true,          -- auto-setup lua_ls via lspconfig hooks
  pathStrict = true,         -- requires lua-language-server >= 3.6.0, faster path resolution
  debug = false,             -- enable debug notifications
}
```

The `override` function signature: `function(root_dir: string, options: library_options) end` — called per `root_dir`, allowing users to customize library settings for specific directories (e.g., `/etc/nixos`).

## Dependencies

**Runtime dependencies:**
- **Neovim >= 0.7.0** (core requirement)
- **nvim-lspconfig** — required for the `lspconfig = true` auto-setup path
- **neoconf.nvim** — optional, for project-local settings (loaded via `pcall`)
- **lazy.nvim** — optional, for plugin discovery (loaded via `package.loaded["lazy"]`)
- **nvim-cmp** (or a similar completion plugin) — mentioned in the README but not a hard dependency

**Build/dev dependencies:**
- **lua-language-server** >= 3.6.0 (for `pathStrict`)
- **curl** (for fetching `uv.lua` and `lpeg.lua` from GitHub)
- **stylua** (formatter)
- **selene** (linter)
- **plenary.nvim** (test framework, used in CI)
- **panvimdoc** (vimdoc generation, CI only)
- **doxygen, luajit, python3-msgpack** (for type generation, CI only)

## Build / Type Regeneration

The plugin has a **self-contained code-generation pipeline** in `lua/neodev/build/`:

1. **Trigger**: `lua/neodev/build/init.lua` calls `M.build()` at module load time. In CI, this is run via:
   ```
   nvim -u NONE -E -R --headless --cmd "set rtp^=." --cmd "packloadall" --cmd "luafile lua/neodev/build/init.lua" --cmd q
   ```
   The build module is **not** loaded during normal plugin operation.

2. **Process** (`M.build()`):
   - `M.clean()` — removes all generated `.lua` files in the types directory except `vim.lua`
   - `M.uv()` — fetches `uv.lua` from the luvit-meta GitHub repo
   - `M.alias()` — writes type aliases from `Annotations.nvim_types`
   - `M.commands()` — writes `vim.cmd.*` stubs from Neovim command docs
   - For Neovim < 0.10 only: also fetches `lpeg.lua`, builds `options.lua`, `api.lua`, `lua.lua`, and `vim.fn.lua`
   - `M.api()` — parses `vim.fn.api_info()` into EmmyLua annotations. On nightly it additionally reads `api.mpack` to add any missing/hidden functions. (Note: this block only runs on Neovim < 0.10, so the mpack supplement is effectively dormant.)

3. **Override system**: `M.override(fname)` loads manual overrides from `types/override/<fname>.lua` and deep-merges them on top of the generated content. This allows manual corrections to auto-generated annotations.

4. **Output**: Generated EmmyLua annotation files in `types/stable/` and `types/nightly/`. These are **committed to the repo** and shipped with the plugin — users do not need to run the build.

5. **File splitting**: `build/writer.lua` automatically splits output into `.1.lua`, `.2.lua`, etc. when a file exceeds 200KB (`M.MAX_SIZE`).

6. **CI automation**: The `types.yml` workflow runs hourly via cron to regenerate type stubs for both nightly and stable Neovim, auto-committing changes.

## Tests

```bash
nvim --headless -u tests/init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.lua', sequential = true}"
```

> **Note:** The `tests/` directory is currently not present in the repo. The CI workflow guards with `[ ! -d tests ] && exit 0`, so the test step is a no-op when no tests exist.

## Coding Conventions

- **Module pattern**: Each module returns a local `M = {}` table with functions; modules that need config load `local config = require("neodev.config")` at the top.
- **Type annotations**: EmmyLua-style `---@class`, `---@param`, `---@type`, `---@return`, `---@generic` annotations throughout (e.g., the `LuaDevOptions` class, `boolean|string[]` union types).
- **Config merging**: Uses `vim.tbl_deep_extend("force", ...)` for deep merges (config defaults, settings, overrides).
- **Safe requires**: Uses `pcall(function() ... end)` for optional dependencies (neoconf, lazy).
- **Legacy support**: `lua/lua-dev.lua` shim warns users about the rename from `lua-dev` to `neodev`; `lsp.lua` checks `config.settings.legacy` to detect old-style setup.
- **Formatting**: 2-space indentation, 120 column width (`stylua.toml`).
- **Linting**: selene with `std="lua51+vim"` (`selene.toml`).
- **Type checking**: `vim.toml` with `{vim.any = true}` for vim global typing.
- **Deterministic iteration**: `util.for_each()` sorts keys before iterating to ensure stable output (important for generated files).
- **Error handling**: `util.error()` uses `vim.notify_once` with log level ERROR and title `"neodev.nvim"`; `util.debug()` conditionally logs when `debug = true`.
- **Path handling**: Uses `vim.loop.fs_realpath` and `vim.fs.normalize` for cross-platform path resolution.
- **No external Lua dependencies** at runtime — pure Lua/Neovim API only.
- **File organization**: The build pipeline is isolated in `neodev/build/` and is not loaded during normal plugin operation (only during type regeneration).
