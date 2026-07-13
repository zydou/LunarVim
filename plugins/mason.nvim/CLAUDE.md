# CLAUDE.md — mason.nvim

## Project Overview

**mason.nvim** is a portable Neovim package manager that runs on all platforms Neovim supports (Linux, macOS, Windows). It provides a single interface for managing external editor tooling, including:

- LSP servers
- DAP servers (debug adapters)
- Linters
- Formatters

Packages are installed, by default, inside Neovim's data directory (under the `mason/` subdirectory of `vim.fn.stdpath "data"`), and executables are linked into a unified `bin/` directory that mason.nvim prepends to `PATH` during setup.

**Minimum requirements:**
- Neovim >= 0.7.0
- Unix: `git`, `curl` or `wget`, `unzip`, GNU `tar`, `gzip`
- Windows: pwsh/powershell, git, GNU tar, 7zip/peazip, etc.

**Core runtime dependencies:**
- `plenary.nvim` — test framework (`plenary.test_harness`) and coroutine utilities
- `mason-registry` (`mason-org/mason-registry`) — the default core package registry

**Recommended companion extensions:**
- `mason-lspconfig.nvim` — integration with `nvim-lspconfig`
- `mason-null-ls.nvim` — integration with `null-ls` (linters/formatters)
- `mason-nvim-dap.nvim` — integration with `nvim-dap`

## Directory Structure

```
mason.nvim/
├── README.md                  # Documentation
├── CHANGELOG.md               # Changelog
├── CONTRIBUTING.md            # Contribution guide
├── LICENSE                    # MIT License
├── Makefile                   # Build & test targets
├── PACKAGES.md                # Package-related notes
├── SECURITY.md                # Security policy
├── selene.toml                # Selene linter config
├── stylua.toml                # StyLua formatter config
├── vim.yml                    # Possibly used for CI coverage testing
├── doc/                       # Neovim help docs (:help mason.nvim)
├── .github/                   # GitHub Actions / Issue templates
│
├── lua/
│   ├── mason/                 # ──────────────── Top-level plugin module ────────────────
│   │   ├── init.lua           # Entry point: M.setup(config) — initializes config, PATH, commands, registry sources
│   │   ├── settings.lua       # MasonSettings config table & defaults
│   │   ├── health.lua         # :checkhealth mason implementation
│   │   ├── version.lua        # Version info
│   │   ├── api/
│   │   │   └── command.lua    # User commands: :Mason, :MasonInstall, :MasonUninstall,
│   │   │                     #   :MasonUninstallAll, :MasonUpdate, :MasonLog
│   │   ├── providers/         # Top-level provider implementations (consumed by mason-core.providers)
│   │   │   ├── client/        # Pure client-side metadata resolvers (local CLI tools)
│   │   │   │   ├── init.lua   # Aggregates all sub-service providers
│   │   │   │   ├── gh.lua     # `gh` CLI
│   │   │   │   ├── golang.lua # `go` CLI  (NOTE: .lua, not .go)
│   │   │   │   ├── npm.lua    # `npm` CLI
│   │   │   │   ├── openvsx.lua
│   │   │   │   ├── pypi.lua
│   │   │   │   └── rubygems.lua
│   │   │   └── registry-api/  # Remote API provider
│   │   │       └── init.lua   # Calls the https://api.mason-registry.dev API
│   │   └── ui/                # Neovim floating-window UI
│   │       ├── init.lua       # Module entry: open(), close(), set_view(), set_sticky_cursor()
│   │       ├── instance.lua   # Core UI view orchestration (state, events, effect handling)
│   │       ├── colors.lua     # Highlight group definitions
│   │       ├── palette.lua    # Color palette
│   │       └── components/
│   │           ├── header.lua        # Title bar
│   │           ├── tabs.lua          # Category tabs (All / LSP / DAP / Linter / Formatter)
│   │           ├── language-filter.lua
│   │           ├── json-schema.lua   # LSP settings schema rendering
│   │           ├── main/            # Main package list
│   │           │   ├── init.lua
│   │           │   └── package_list.lua
│   │           └── help/             # Help window
│   │               ├── init.lua
│   │               ├── formatter.lua
│   │               ├── lsp.lua
│   │               ├── linter.lua
│   │               └── dap.lua
│   │
│   ├── mason-core/            # ──────────────── Core library ────────────────
│   │   ├── async/             # Async / coroutine control primitives
│   │   │   ├── init.lua       # a.run, a.wait, a.wait_all, a.wait_first, a.sleep,
│   │   │                     #   a.run_blocking, a.scope, a.scheduler, a.promisify, a.blocking
│   │   │   ├── control.lua    # Semaphore & OneShotChannel
│   │   │   └── uv.lua         # libuv-based async helpers
│   │   ├── functional/        # Functional programming utility library (Ramda-style)
│   │   │   ├── init.lua       # Unified `_` module (single entry point for all functions, lazy-loaded)
│   │   │   ├── data.lua       # table_pack, set_of, enum
│   │   │   ├── function.lua   # compose, partial, curryN, memoize, identity, always, lazy, tap, apply_to,
│   │   │                     #   apply, converge, apply_spec, T, F
│   │   │   ├── list.lua       # map, filter, filter_map, each, concat, append, prepend, zip_table, nth,
│   │   │                     #   head, last, length, flatten, sort_by, uniq_by, join, partition, take,
│   │   │                     #   drop, drop_last, reduce, split_every, index_by, find_first, any, all, reverse
│   │   │   ├── logic.lua      # all_pass, any_pass, if_else, cond, complement, is_not, default_to
│   │   │   ├── number.lua     # gt, gte, lt, lte, inc, dec, negate
│   │   │   ├── relation.lua   # equals, not_equals, prop_eq, prop_satisfies, path_satisfies, min, add
│   │   │   ├── string.lua     # split, match, matches, gsub, format, trim, trim_start_matches,
│   │   │                     #   trim_end_matches, strip_prefix, strip_suffix, dedent, starts_with,
│   │   │                     #   to_upper, to_lower
│   │   │   ├── table.lua      # prop, path, pick, keys, size, to_pairs, from_pairs, invert, merge_left,
│   │   │                     #   dissoc, assoc, evolve
│   │   │   └── type.lua       # is, is_nil
│   │   ├── installer/         # Installation pipeline
│   │   │   ├── init.lua       # Global Semaphore + execute() — the main installation flow
│   │   │   ├── context.lua    # InstallContext (fs / spawn / stdio / receipt / chdir / linking)
│   │   │   ├── handle.lua     # InstallHandle state machine (IDLE → QUEUED → ACTIVE → CLOSED)
│   │   │   ├── linker.lua     # bin / share / opt linking & unlinking (uses receipt.links)
│   │   │   ├── managers/      # Legacy installer managers (used by old PackageSpec.install function-based approach)
│   │   │   │   ├── cargo.lua, composer.lua, gem.lua, golang.lua,
│   │   │   │   │   luarocks.lua, npm.lua, nuget.lua, opam.lua,
│   │   │   │   │   pypi.lua, std.lua, common.lua
│   │   │   └── registry/      # Registry-based installer (new schema-driven approach)
│   │   │       ├── init.lua       # InstallerProvider registry: parse(), compile(), get_versions(), register_provider()
│   │   │       ├── link.lua       # bin / share / opt linking for registry packages
│   │   │       ├── expr.lua       # Expression evaluation
│   │   │       ├── schemas.lua    # LSP schema download
│   │   │       ├── util.lua       # Utility functions (e.g., ensure_valid_version)
│   │   │       └── providers/     # InstallerProvider implementations (keyed by PURL type)
│   │   │           ├── cargo.lua, composer.lua, gem.lua,
│   │   │           │   golang.lua, luarocks.lua, npm.lua,
│   │   │           │   nuget.lua, opam.lua, openvsx.lua, pypi.lua
│   │   │           ├── github/    # GitHub releases & builds
│   │   │           │   ├── init.lua, build.lua, release.lua
│   │   │           └── generic/   # Generic download & build
│   │   │               ├── init.lua, download.lua, build.lua
│   │   ├── managers/          # External package manager abstractions (for spawn-based interaction)
│   │   │   ├── cargo/, composer/, dotnet/, gem/, git/, github/,
│   │   │   │   go/, luarocks/, npm/, opam/, pip3/, powershell/, std/
│   │   ├── package/
│   │   │   ├── init.lua       # Package class (new, install, uninstall, is_installed,
│   │   │                     #   get_installed_version, check_new_version, …)
│   │   │   └── version-check.lua  # Version check logic
│   │   ├── providers/         # Provider dispatch layer
│   │   │   └── init.lua       # Provider table, chained fallback per configured providers
│   │   ├── ui/                # Low-level declarative UI library
│   │   │   ├── init.lua
│   │   │   ├── state.lua
│   │   │   └── display.lua    # Floating-window rendering
│   │   ├── EventEmitter.lua   # Event emitter
│   │   ├── fetch.lua          # HTTP download (curl / wget)
│   │   ├── fs.lua             # Filesystem (sync / async)
│   │   ├── log.lua            # Logging backend
│   │   ├── notify.lua         # User notification wrapper
│   │   ├── optional.lua       # Optional monad
│   │   ├── path.lua           # Path construction & concatenation
│   │   ├── platform.lua       # Platform detection (darwin_arm64, linux_x64_gnu, …)
│   │   ├── process.lua        # libuv process helpers
│   │   ├── purl.lua           # PURL (package URL) parsing & compilation
│   │   ├── receipt.lua        # Installation receipt
│   │   ├── result.lua         # Result monad (success / failure + try / and_then / on_success, …)
│   │   ├── semver.lua         # Semantic versioning
│   │   ├── spawn.lua          # Process spawning
│   │   ├── terminator.lua     # Installation terminator
│   │   └── ui/                # (low-level UI, same as above)
│   │
│   ├── mason-registry/        # ──────────────── Package registry ────────────────
│   │   ├── init.lua           # MasonRegistry — package lookup via EventEmitter (get_package,
│   │   │                     #   get_all_packages, refresh, update, is_installed, …)
│   │   ├── api.lua            # Low-level HTTP API client (wraps api.mason-registry.dev)
│   │   ├── installer.lua      # Registry installation logic (called by mason-registry.init.update)
│   │   ├── index/
│   │   │   └── init.lua       # Placeholder / interface (currently returns {})
│   │   └── sources/           # RegistrySource implementations
│   │       ├── init.lua       # Registry source management (set_registries, iter, is_installed, checksum)
│   │       ├── file.lua       # file:// local source
│   │       ├── github.lua     # github: remote source (default: mason-org/mason-registry)
│   │       ├── lua.lua        # lua: Lua module source
│   │       └── util.lua       # Utility functions
│   │
│   └── mason-vendor/          # ────────────── Third-party vendored code ──────────────
│       └── zzlib/             # ZIP decompression (used for downloading registry archives)
│           ├── init.lua
│           ├── inflate-bit32.lua
│           └── inflate-bwo.lua
│
└── tests/                     # ──────────────── Tests ────────────────
    ├── minimal_init.vim       # Neovim init script for tests
    ├── fixtures/              # Test fixtures
    │   └── purl-test-suite-data.json
    ├── helpers/
    │   ├── lua/
    │   │   ├── luassertx.lua          # luassert extensions
    │   │   ├── test_helpers.lua       # Test helper functions
    │   │   └── dummy-registry/        # Dummy registry for tests
    │   │       ├── index.lua
    │   │       ├── dummy_package.lua
    │   │       ├── dummy2_package.lua
    │   │       └── registry_package.lua
    ├── mason/                  # Top-level mason module tests
    │   ├── setup_spec.lua
    │   └── api/command_spec.lua
    ├── mason-core/             # mason-core module tests
    │   ├── EventEmitter_spec.lua, fetch_spec.lua, fs_spec.lua, optional_spec.lua,
    │   │   path_spec.lua, platform_spec.lua, process_spec.lua, purl_spec.lua,
    │   │   result_spec.lua, spawn_spec.lua, terminator_spec.lua, ui_spec.lua
    │   ├── async/async_spec.lua
    │   ├── functional/             # Complete functional library tests
    │   │   ├── data_spec.lua, function_spec.lua, list_spec.lua, logic_spec.lua,
    │   │   │   number_spec.lua, relation_spec.lua, string_spec.lua, table_spec.lua, type_spec.lua
    │   ├── installer/              # Installer tests
    │   │   ├── context_spec.lua, handle_spec.lua, installer_spec.lua, linker_spec.lua
    │   │   ├── managers/           # Legacy installer manager tests
    │   │   │   ├── cargo_spec.lua, common_spec.lua, composer_spec.lua, gem_spec.lua,
    │   │   │   │   golang_spec.lua, luarocks_spec.lua, npm_spec.lua, nuget_spec.lua,
    │   │   │   │   opam_spec.lua, pypi_spec.lua, std_spec.lua
    │   │   └── registry/           # Registry installer tests
    │   │       ├── expr_spec.lua, installer_spec.lua, link_spec.lua, util_spec.lua
    │   │       └── providers/      # Registry provider tests
    │   │           ├── cargo_spec.lua, composer_spec.lua, gem_spec.lua, golang_spec.lua,
    │   │           │   luarocks_spec.lua, npm_spec.lua, nuget_spec.lua, opam_spec.lua,
    │   │           │   openvsx_spec.lua, pypi_spec.lua
    │   │           ├── generic/build_spec.lua, generic/download_spec.lua
    │   │           └── github/build_spec.lua, github/release_spec.lua
    │   ├── managers/               # External package manager tests
    │   │   ├── cargo_spec.lua, composer_spec.lua, dotnet_spec.lua, gem_spec.lua,
    │   │   │   git_spec.lua, github_client_spec.lua, github_spec.lua, go_spec.lua,
    │   │   │   luarocks_spec.lua, npm_spec.lua, opam_spec.lua, pip3_spec.lua, powershell_spec.lua
    │   ├── package/                # Package class tests
    │   │   └── package_spec.lua
    │   └── providers/              # Provider tests
    │       └── provider_spec.lua
    └── mason-registry/             # Registry tests
        ├── api_spec.lua
        ├── registry_spec.lua
        └── sources/lua_spec.lua
```

## Core Modules

### 1. Entry Module (`lua/mason/init.lua`)

- **`M.setup(config)`**: The plugin's top-level entry point.
  1. Merges config via `settings.set(config)`
  2. Sets the `vim.env.MASON` environment variable
  3. Modifies `PATH` (prepend / append / skip)
  4. Loads `mason.api.command` to register all user commands
  5. Registers a `VimLeavePre` autocommand that terminates all running installations on exit
  6. Configures registry sources via `mason-registry.sources.set_registries`

### 2. Settings Module (`lua/mason/settings.lua`)

- **`DEFAULT_SETTINGS` table**: Contains all configuration options.
  - `install_root_dir` — installation root directory
  - `PATH` — PATH modification strategy (`"prepend"` | `"append"` | `"skip"`)
  - `log_level` — logging level
  - `max_concurrent_installers` — max concurrent installations
  - `registries` — list of registry sources (e.g., `"github:mason-org/mason-registry"`)
  - `providers` — list of metadata providers (e.g., `"mason.providers.registry-api"`)
  - `github` — download URL template
  - `pip` — pip-related settings
  - `ui` — UI-related config (border, dimensions, icons, keymaps)

### 3. Commands / API (`lua/mason/api/command.lua`)

Registers the following user commands:

- **`:Mason`** — opens the UI window
- **`:MasonInstall <package> ...`** — install / reinstall packages (supports `--debug`, `--force`, `--strict`, `--target=` options)
- **`:MasonUninstall <package> ...`** — uninstall packages
- **`:MasonUninstallAll`** — uninstall all packages
- **`:MasonUpdate`** — update all registries
- **`:MasonLog`** — open the log file

Exported function table: `{ Mason, MasonInstall, MasonUninstall, MasonUninstallAll, MasonUpdate, MasonLog }`

### 4. Package Registry (`lua/mason-registry/`)

**`mason-registry/init.lua`:**
- Inherits from `EventEmitter`; the registry's main entry point.
- Key exports:
  - `get_package(name)` — look up a package by name (errors if not found)
  - `has_package(name)` — check whether a package exists
  - `get_all_packages()` / `get_all_package_names()`
  - `get_installed_packages()` / `get_installed_package_names()`
  - `get_all_package_specs()` — returns all package specs
  - `register_package_aliases(new_aliases)` — register package aliases
  - `get_package_aliases(name)` — get aliases for a package
  - `is_installed(name)` — fast check whether a package is installed (scans install root dir)
  - `refresh(cb)` — refresh the registry if outdated (TTL 24h)
  - `update(cb)` — force-update the registry

**Registry sources (`sources/`):**
- `init.lua` — parses `registry_id` strings and instantiates the corresponding `RegistrySource`
  - Supports three types: `github:` (GitHub repo), `lua:` (Lua module), `file:` (local file)
- `github.lua` — downloads `registry.json.zip` from GitHub and caches it
- `lua.lua` — dynamically loads package specs from a Lua module
- `file.lua` — loads from a local file

### 5. Package Abstraction (`lua/mason-core/package/init.lua`)

**`Package` class** (inherits from `EventEmitter`):
- `Package.new(spec)` — construct a package instance from a spec
- `Package.Parse(identifier)` — parse `"name@version"` format
- `:install(opts?)` — install the package, returns `InstallHandle`
- `:uninstall()` — uninstall the package
- `:is_installed()` — check whether the package is installed
- `:get_installed_version(cb)` — get the installed version
- `:check_new_version(cb)` — check for a newer version
- `:get_lsp_settings_schema()` — get the LSP settings schema
- `:is_registry_spec()` — whether this is a registry spec (vs. legacy PackageSpec)
- `:get_aliases()` — get package aliases
- `:get_handle()` — get the current install handle (Optional)
- `:get_receipt()` — get the install receipt (Optional)
- `:unlink()` — unlink the package (remove symlinks & install dir)

**Package categories (`Package.Cat`):** Compiler, Runtime, DAP, LSP, Linter, Formatter (plain table with string values).

**Package languages (`Package.Lang`):** Auto-vivifying metatable table for language strings.

**Two spec types:**
- `PackageSpec` — legacy spec with an `install` function field
- `RegistryPackageSpec` — new registry-driven spec with a `source` field (PURL-based)

### 6. Installation Pipeline (`lua/mason-core/installer/`)

**Main entry (`init.lua`):**
- Global `Semaphore` controls the number of concurrent installations.
- `execute(handle, opts)` — the full installation flow:
  1. `create_prefix_dirs()` — create necessary directories
  2. `lock_package()` — write a lockfile
  3. `prepare_installer()` — select the registry installer or the legacy install function
  4. `run_installer()` — execute the installer (inside a coroutine)
  5. `context:promote_cwd()` — move the temporary install directory to its final location
  6. `linker.link()` — create bin / share / opt links
  7. `build_receipt()` — generate the installation receipt
- `exec_in_context(context, fn)` — run an async function within an install context (coroutine-based)
- `run_concurrently(suspend_fns)` — run async functions concurrently within the same context
- `context()` — request the current install context (used inside async functions)

**`InstallContext`** (`context.lua`): installation context
- Holds `CwdManager`, `ContextualFs`, `ContextualSpawn`, `receipt`, `handle`, `package`, `links`, `requested_version`, `stdio_sink`, `opts`
- `:promote_cwd()` — atomically move the temporary directory to the install directory
- `:chdir(path, fn)` — temporarily change the working directory
- `:write_shell_exec_wrapper()` — generate a cross-platform executable wrapper
- `:write_node_exec_wrapper()`, `:write_ruby_exec_wrapper()`, `:write_php_exec_wrapper()`, `:write_pyvenv_exec_wrapper()`, `:write_exec_wrapper()` — language-specific wrapper generators
- `:link_bin(name, path)` — register a bin link

**`InstallHandle`** (`handle.lua`): installation handle, state machine:
- States: `IDLE` → `QUEUED` → `ACTIVE` → `CLOSED`
- Events: `state:change`, `spawn_handles:change`, `stdout`, `stderr`, `terminate`, `closed`, `kill`
- `:terminate()` — send SIGTERM (Unix) or taskkill (Windows)
- Tracks child process PIDs via `InstallHandleSpawnHandle`

**`linker.lua`**: bin / share / opt linking & unlinking (operates on `receipt.links`).

### 7. Provider System (`lua/mason-core/providers/init.lua`)

**`providers` table**: provider service registry
- Lazily creates dispatch methods for each service (`github`, `npm`, `pypi`, `rubygems`, `packagist`, `crates`, `golang`, `openvsx`)
- At call time, tries each provider in `settings.current.providers` order; the first success wins
- Common methods: `get_latest_version`, `get_all_versions`, `get_latest_release`, `get_all_release_versions`, `get_latest_tag`, `get_all_tags`

### 8. Registry Installer (`lua/mason-core/installer/registry/init.lua`)

Pairs PURLs with `InstallerProvider` implementations:
- `parse(spec, opts)` — parse a spec, select a provider; returns `{ provider, source, raw_source, purl }`
- `compile(spec, opts)` — compile to a closure `function(ctx): Result`
- `get_versions(spec)` — get available versions (`Result<string[]>`)
- `register_provider(id, provider)` — register an `InstallerProvider`
- Registered providers: `cargo`, `composer`, `gem`, `generic`, `github`, `golang`, `luarocks`, `npm`, `nuget`, `opam`, `openvsx`, `pypi`

Each `InstallerProvider` must implement:
- `parse(source, purl, opts): Result` — parse the source
- `install(ctx, source, purl): Result` — execute the installation (async)
- `get_versions(purl, source): Result<string[]>` — get the version list (async)

### 9. Async Primitives (`lua/mason-core/async/init.lua`)

Based on Lua JIT coroutines:
- `a.run(fn, cb)` — start async execution; result delivered via callback
- `a.scope(fn)` — wrap as a panic-on-error async function
- `a.run_blocking(fn)` — block the current Neovim until the async fn completes
- `a.wait(resolver)` — await a promise inside a coroutine
- `a.wait_all(fns)` / `a.wait_first(fns)` — concurrent await
- `a.scheduler()` — ensure we're not inside a fast event loop
- `a.sleep(ms)` — delay
- `a.promisify(fn)` — convert callback-style to coroutine-style
- `a.blocking(fn)` — wrap as a blocking function

**Control primitives (`control.lua`):**
- `Semaphore` — counting semaphore
- `OneShotChannel` — single-shot channel

### 10. Functional Utility Library (`lua/mason-core/functional/`)

Provides a unified `_` module (single entry point, lazy-loaded via metatables):
- **data**: `table_pack`, `set_of`, `enum`
- **function**: `compose`, `partial`, `curryN`, `memoize`, `identity`, `always`, `T`, `F`, `lazy`, `tap`, `apply_to`, `apply`, `converge`, `apply_spec`
- **list**: `map`, `filter`, `filter_map`, `each`, `concat`, `append`, `prepend`, `zip_table`, `nth`, `head`, `last`, `length`, `flatten`, `sort_by`, `uniq_by`, `join`, `partition`, `take`, `drop`, `drop_last`, `reduce`, `split_every`, `index_by`, `find_first`, `any`, `all`, `reverse`, `list_not_nil`, `list_copy`
- **logic**: `all_pass`, `any_pass`, `if_else`, `cond`, `complement`, `is_not`, `default_to`
- **number**: `gt`, `gte`, `lt`, `lte`, `inc`, `dec`, `negate`
- **relation**: `equals`, `not_equals`, `prop_eq`, `prop_satisfies`, `path_satisfies`, `min`, `add`
- **string**: `split`, `match`, `matches`, `gsub`, `format`, `trim`, `trim_start_matches`, `trim_end_matches`, `strip_prefix`, `strip_suffix`, `dedent`, `starts_with`, `to_upper`, `to_lower`
- **table**: `prop`, `path`, `pick`, `keys`, `size`, `to_pairs`, `from_pairs`, `invert`, `merge_left`, `dissoc`, `assoc`, `evolve`
- **type**: `is`, `is_nil`
- Additional: `coalesce`, `when`, `lazy_when`, `scheduler`, `scheduler_wrap`, `lazy_require`

### 11. Core Data Types

**`Result` monad (`result.lua`):**
- Constructors: `Result.success(v)`, `Result.failure(e)`
- Transform: `map`, `map_catching`, `map_err`, `recover`, `recover_catching`
- Chain: `and_then`, `or_else`, `ok`, `ok_or`
- Consume: `get_or_throw`, `get_or_nil`, `get_or_else`, `err_or_nil`
- Side effects: `on_success`, `on_failure`
- Scope: `Result.try(fn)`, `Result.pcall(fn, ...)`, `Result.run_catching(fn)`

**`Optional` monad (`optional.lua`):**
- Constructors: `Optional.of(v)`, `Optional.of_nilable(v)`, `Optional.empty()`
- Transform: `map`, `and_then`, `or_`, `ok_or`
- Consume: `get`, `or_else`, `or_else_get`, `or_else_throw`
- Check: `is_present`
- Side effects: `if_present`, `if_not_present`

### 12. Platform Detection (`lua/mason-core/platform.lua`)

- `M.arch` / `M.sysname` — architecture / OS
- `M.is.PATTERN` — pattern matching for targets like `"linux_x64_gnu"`, `"darwin_arm64"`
- `M.is` table: computed on access via metatable
- `M.when { unix = ..., win = ..., linux = ..., darwin = ... }`
- `M.path_sep` — path separator (`:` for Unix, `;` for Windows)
- `M.get_homebrew_prefix()` / `M.get_node_version()`
- `M.is_headless` — whether running in headless (no UI) mode
- `M.os_distribution` — async lazy lookup of the OS distribution (Linux only)

## Configuration

Users configure the plugin via `require("mason").setup(config)`:

```lua
require("mason").setup({
    ui = {
        icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
        }
    }
})
```

### Registry Configuration

Defaults to `"github:mason-org/mason-registry"`, downloaded to `install_root_dir`. Also supports:
- **lua:** — load from a Lua module (e.g., `"lua:my-registry.packages"`)
- **file:** — load from a local file

### Provider Configuration

Tries multiple providers in order:
```lua
providers = {
    "mason.providers.registry-api",   -- remote API
    "mason.providers.client",          -- local CLI tools (`npm`, `gh`, `pip`, etc.)
}
```

## Build / Test

Run tests via the Makefile:

```bash
make test
```

`make test` flow:
1. `clean_fixtures` — clean the test installation directory
2. `dependencies` — clone `plenary.nvim` and `neotest` (test dependencies)
3. Launch headless Neovim: `nvim --headless --noplugin -u tests/minimal_init.vim`
4. Override `INSTALL_ROOT_DIR` to point to `tests/fixtures/mason`
5. Call the `RunTests()` function (`plenary.test_harness.test_directory`)

`make clean` — clean fixtures & dependencies.

Test framework: `busted`-style tests from `plenary.nvim`.
Spec file naming convention: `<module>_spec.lua`.

## Coding Conventions

### Formatting
- **StyLua** (`.stylua.toml`): uses **spaces** for indentation; **no** function call parentheses (`call_parentheses = "None"`); auto-sorts `requires`.

### Linter
- **Selene** (`selene.toml`): uses Lua 5.1 + Vim stdlib; excludes `lua-m-vendor/`; allows unused variables and variable shadowing.

### Naming Conventions
- **Module names**: `mason-core.X.Y` — hyphen-separated; hierarchy expressed via directory structure
- **Class names**: `PascalCase` (`Package`, `InstallContext`, `Result`, `Optional`)
- **Method names**: instance methods use colon syntax `Module:method()`; static functions use dot syntax `Module.static_fn()`
- **Private fields**: marked with `private` comment and underscore prefix (e.g., `private cwd`)
- **Config keys**: `UPPER_SNAKE_CASE` (e.g., `install_root_dir` is an exception using lowercase; `PATH` uppercase is an exception)
- **Functions / variables**: `snake_case`

### Type Annotations
- Heavy use of LuaCATS (`---@class`, `---@field`, `---@param`, `---@alias`, `---@return`, `---@enum`, `---@since`) type annotations
- Class definitions typically placed in `---@class` doc comments
- Function signatures indicate sync/async in comments (`---@async`)

### Async Patterns
- All async operations use the coroutine-style `a.run` / `a.wait` / `a.wait_all` API
- Avoid direct libuv callbacks except in the low-level `async/uv.lua`
- Use the `Result` monad instead of the traditional `pcall` + error-string pattern

### Module Export Conventions
- A module returns a single table, class, or function
- Classes use metatable + `__index` (hand-rolled OOP, no external framework)
- Use a local `M = {}` table to collect exported symbols

### Functional Style
- Code encourages use of `_.map`, `_.filter`, `_.compose`, etc.
- Exception handling uses `Result.try` + `try(Result.pcall(...))` patterns
- Prefer `Optional` / `Result` monads over `nil` error propagation

### Debug Support
- Use `log.fmt_debug(...)`, `log.fmt_info(...)`, `log.fmt_error(...)`, etc. for different log levels
- Setting `MASON_VERBOSE_LOGS=1` enables synchronous console logging
- The `--debug` install option retains the install directory and writes `mason-debug.log`

### File Organization Conventions
- `core/` — generic, reusable logic; no Neovim-specific UI
- `mason/` — top-level plugin implementation (commands, UI, config)
- `mason-registry/` — registry management
- `mason-vendor/` — third-party code that should not be modified directly
- Each class / module maps to its own file; class tables are exported via a `Module.new()` factory function
