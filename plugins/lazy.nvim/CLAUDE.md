# lazy.nvim

## Overview

lazy.nvim is a modern Neovim plugin manager. Key features: lazy loading, automatic installation, lockfile support, config file change detection, and a built-in UI. It is the most widely used Neovim plugin manager and is compatible with the spec format used by most modern Neovim plugins. Requires Neovim >= 0.8.0 built with LuaJIT.

## Project Structure

```
lazy.nvim/
├── lua/lazy/
│   ├── init.lua              # Entry module: setup(), bootstrap(), plugins(), stats()
│   ├── health.lua            # :checkhealth lazy
│   ├── state.lua             # Persistent state (state.json)
│   ├── stats.lua             # Performance statistics (load times, etc.)
│   ├── status.lua            # Statusline component (pending update count)
│   ├── help.lua              # Helptag generation
│   ├── docs.lua              # Documentation processing
│   ├── types.lua             # Type definitions (LazyPlugin, LazySpec, etc.)
│   ├── util.lua              # General utilities
│   ├── example.lua           # Example configuration
│   ├── core/                 # Core engine
│   │   ├── config.lua        # Configuration options and setup
│   │   ├── cache.lua         # Module cache (bytecode / vim.loader)
│   │   ├── util.lua          # Core utilities (path normalization, etc.)
│   │   ├── loader.lua        # Plugin loader (package.loader + startup logic)
│   │   ├── plugin.lua        # Plugin spec parsing (Spec)
│   │   └── handler/          # Lazy-loading handlers
│   │       ├── init.lua      # Handler base class and registry
│   │       ├── event.lua     # Event handler (autocmd-triggered loading)
│   │       ├── keys.lua      # Keys handler (keymap-triggered loading)
│   │       ├── ft.lua        # FileType handler
│   │       └── cmd.lua       # Command handler (command-triggered loading)
│   ├── manage/               # Plugin management (install/update/clean)
│   │   ├── init.lua          # Manager (install/update/check/clean/sync/log/build)
│   │   ├── git.lua           # Git operations (info/get_target/get_branch/etc.)
│   │   ├── semver.lua        # Semantic versioning
│   │   ├── lock.lua          # Lockfile management (lazy-lock.json)
│   │   ├── checker.lua       # Update checker
│   │   ├── reloader.lua      # Config reload detection
│   │   ├── process.lua       # Async process management
│   │   ├── runner.lua        # Task runner (coroutine concurrency)
│   │   └── task/             # Task definitions
│   │       ├── init.lua      # Task base class
│   │       ├── git.lua       # Git tasks (clone/checkout/fetch/status/log/branch/origin)
│   │       ├── plugin.lua    # Plugin tasks (docs/build)
│   │       └── fs.lua        # Filesystem tasks (clean)
│   └── view/                 # UI rendering
│       ├── init.lua          # LazyView (main UI window)
│       ├── config.lua        # UI command mappings and keymap configuration
│       ├── commands.lua      # UI command implementations (home/install/update/etc.)
│       ├── render.lua        # Rendering engine
│       ├── float.lua         # Floating window base class
│       ├── sections.lua      # UI sections (filtered by status)
│       ├── diff.lua          # Diff display
│       ├── colors.lua        # UI highlights
│       └── text.lua          # Text components
├── tests/                    # Test suite
│   ├── init.lua              # Test configuration (plenary + XDG env isolation)
│   ├── helpers.lua           # Test helpers
│   ├── core/init_spec.lua    # Core module tests
│   ├── core/plugin_spec.lua  # Plugin parsing tests
│   ├── core/e2e_spec.lua     # End-to-end tests
│   ├── core/util_spec.lua    # Utility tests
│   ├── manage/semver_spec.lua
│   ├── manage/task_spec.lua
│   ├── manage/runner_spec.lua
│   └── handlers/keys_spec.lua
├── doc/lazy.nvim.txt         # Vim help documentation
├── .github/workflows/ci.yml  # CI configuration
├── CHANGELOG.md
├── TODO.md
├── LICENSE
├── stylua.toml               # stylua formatting config
├── selene.toml               # selene lint config
├── .markdownlint.yaml        # markdown lint config
├── .neoconf.json             # neovim config
└── vim.toml                  # vim-treesitter / vim-parser config
```

## Core Modules

### `lazy.init` — Entry Point
- `M.setup(spec, opts)` — Main initialization: validate environment → load config → set up loader → start plugins → trigger `LazyDone`. Two overloads: `(LazyConfig)` or `(LazySpec, LazyConfig)`.
- `M.bootstrap()` — Auto-install lazy.nvim (clone to `vim.fn.stdpath("data") .. "/lazy/lazy.nvim"`, branch `stable`).
- `M.plugins()` / `M.stats()` — Query plugins and statistics.
- `M._start` — Timestamp set on first setup.
- Metatable `__index` proxies undefined keys to `lazy.view.commands.commands[key]`, so `require("lazy").update(...)` etc. work.

### `lazy.core.config` — Configuration
- `M.defaults` — Complete default configuration table (see "Configuration" section).
- `M.setup(opts)` — Merge user config, normalize paths, reset packpath/rtp, set `vim.go.loadplugins = false`, create `UIEnter` and `VeryLazy` autocommands.
- `M.ns` — Neovim namespace ID (integer, created via `vim.api.nvim_create_namespace("lazy")`).
- `M.version` — Current version string (e.g. `"10.20.3"`).
- `M.plugins` / `M.to_clean` / `M.options` / `M.spec` — Plugin registry, cleanup list, merged options, spec loader.
- `M.headless()` — Returns true when no UI is attached.

### `lazy.core.plugin` — Plugin Spec
- `Spec.new(spec?, opts?)` — Constructor; calls `Spec:parse(spec)` if spec provided.
- `Spec:parse(spec)` / `Spec:normalize(spec)` / `Spec:fix_disabled()` — Parse and normalize user-provided plugin specs.
- `Spec:add(plugin, results?)` — Add a single plugin to the registry; handles URL inference, dev mode, dir resolution, fragment tracking, dependency normalization, and merging duplicates.
- `Spec.get_name(pkg)` — Extract plugin name from a URL/path (strips `.git`, trailing `/`, takes last segment).
- `Spec:import(spec)` / `Spec:rebuild(name?)` / `Spec:fix_cond()` / `Spec:fix_optional()` — Additional spec processing.
- `Plugin.load()` — Load specs from disk; creates `Spec.new()`, parses `{spec, {"folke/lazy.nvim"}}`, fires `User LazyPlugins`.
- `Plugin.update_state()` — Scan install dir, set `_.installed`/`_.is_local`, compute `lazy` property, populate `Config.to_clean`.
- `Plugin.values(plugin, prop, is_list?)` — Cached resolution of a property (opts/keys/event/cmd/ft) merging super values. `is_list` controls extend vs merge.
- `Plugin.has_errors(plugin)` — Returns true if any task has an error.
- `Plugin.find(path)` — Find the plugin owning a given Lua file path.

### `lazy.core.loader` — Loader
- `M.loader(modname)` — Custom `package.loader` (inserted at `package.loaders[3]`), loads lazy plugins on demand.
- `M.setup()` — Disable RTP plugins from config, set up `ColorSchemePre` autocmd, call `Plugin.load()`, `Handler.init()`, install missing plugins (up to 5 rounds), call `Handler.setup()`.
- `M.startup()` — Source `filetype.lua`, run all `plugin.init` functions, load `lazy=false` start plugins (sorted by priority desc), load original RTP plugins, load `after/` paths. Sets `M.init_done = true`.
- `M.load(plugins, reason, opts)` — Load specified plugins. `reason` is a `{[string]:string}` table describing why the plugin is being loaded (e.g. `{ cmd = "Lazy load" }`, `{ keys = name }`). `opts` is optional `{force:boolean}`.
- `M.install_missing()` — Incrementally install missing plugins; returns true if more rounds needed.
- `M.deactivate(plugin)` / `M.reload(plugin)` — Unload or reload a plugin.
- `M._load(plugin, reason, opts)` — Internal: check installed + cond, set up handlers, mark loaded, add to RTP, load deps, packadd, run config, fire `User LazyLoad`.
- `M.config(plugin)` — Run plugin config: call `plugin.config(plugin, opts)` or `require(main).setup(opts)`.
- `M.get_main(plugin)` — Resolve the main module for a plugin.
- `M.packadd(path)` / `M.ftdetect(path)` / `M.source_runtime(...)` / `M.add_to_rtp(plugin)` / `M.source(path)` — Vim script sourcing and RTP management.
- `M.colorscheme(name)` — Load the plugin providing a colorscheme if not already available.
- `M.auto_load(modname, modpath)` — Called by `M.loader` to auto-load a plugin when one of its modules is required.

### `lazy.core.handler` — Lazy-Loading Handlers
Four types (`keys`, `event`, `cmd`, `ft`). Each handler instance manages its own `active` and `managed` tables.

- `M.init()` — Create all handler instances (one per type).
- `M.setup()` — Enable handlers for all plugins.
- `M.enable(plugin)` — Register a plugin's lazy-loading triggers (resolves handlers, then calls `M.handlers[type]:add(plugin)`).
- `M.disable(plugin)` — Remove triggers.
- `M.new(type)` — Build a handler instance with double-metatable `__index` chain (handler → super → M).
- `M.resolve(plugin)` — Populate `plugin._.handlers` with parsed values per type.

#### Sub-modules
- `event.lua` — Creates autocommand (`once = true`), supports `VeryLazy` and other custom events via `M.mappings`, and event chains (`M.triggers`: `FileType → BufReadPost → BufReadPre`).
- `keys.lua` — Creates a `vim.keymap.set` wrapper; manages by `id` (termcode-escaped lhs, with ft/mode suffixes). On trigger, loads the plugin then replays the keypress via `nvim_feedkeys`.
- `ft.lua` — Inherits from Event (`M.extends = Event`); triggers `FileType` + runs `Loader.ftdetect(plugin.dir)`.
- `cmd.lua` — Creates a user command; on first call loads the plugin, then replays the command via `vim.cmd`. Tab-completion also triggers loading.

### `lazy.manage` — Plugin Management
- `M.install(opts)` — Install missing plugins. Pipeline: `git.clone` → `{ git.checkout, lockfile = opts.lockfile }` → `plugin.docs` → `wait` → `plugin.build`. Filter: `plugin.url and not plugin._.installed`.
- `M.update(opts)` — Update installed plugins. Pipeline: `git.origin` → `git.branch` → `git.fetch` → `git.status` → `{ git.checkout, lockfile = opts.lockfile }` → `plugin.docs` → `wait` → `plugin.build` → `{ git.log, updated = true }`. Filter: `plugin.url and plugin._.installed`.
- `M.restore(opts)` — Restore to lockfile state (delegates to `M.update` with `lockfile = true`).
- `M.check(opts)` — Check for updates (no-op execution). Pipeline: `{ git.origin, check = true }` → `git.fetch` → `git.status` → `wait` → `{ git.log, check = true }`.
- `M.log(opts)` — Show git log. Pipeline: `{ git.origin, check = true }` → `{ git.log, check = opts.check }`.
- `M.build(opts)` — Build plugins. Pipeline: `{ plugin.build, force = true }`.
- `M.sync(opts)` — Synchronize (clean → install → update, chained sequentially via `:wait()`).
- `M.clean(opts)` — Clean plugins not in spec. Pipeline: `fs.clean`. Filter: `Config.to_clean`.
- `M.clear(plugins)` — Clear task state on plugins.
- `M.run(ropts, opts)` — Core wrapper: fires `User {mode}Pre`/`User {mode}` autocommands, shows UI, creates a `Runner`, starts it, fires `LazyRender`, and on completion runs `Plugin.update_state()`, `checker.fast_check()`, and the mode event.

### `lazy.manage.runner` — Task Runner
- Concurrent pipeline execution using Lua coroutines.
- `Runner.new(opts)` — Create a runner; specify `pipeline` (array of task names or `{[1]=name, [name]=value}` tables), `plugins` (array or filter fn), and `concurrency`.
- `runner:start()` — Create a coroutine per plugin, round-robin resume bounded by `concurrency`, fire `_on_done` callbacks when all complete.
- `runner:wait(cb?)` — If `cb` given, append to `_on_done`; otherwise synchronous busy-wait until done.
- `runner:queue(plugin, task_name, opts?)` — Split `"git.clone"` → `require("lazy.manage.task.git").clone`, skip if `task_def.skip(plugin, opts)`, else `Task.new(...)` + `task:start()`.
- `"wait"` in the pipeline yields control so other coroutines can proceed (barrier).

### `lazy.manage.task` — Task System
- `Task.new(plugin, name, task, opts)` — Create a task. `task` is `fun(task:LazyTask)`, `opts` is `TaskOptions` (`{[string]:any}`, `on_done?`).
- `Task:start()` / `Task:has_started()` / `Task:is_done()` / `Task:is_running()` / `Task:time()` — Lifecycle.
- `Task:spawn(cmd, opts?)` — Wrap `Process.spawn`; updates `self.status` per line, sets `self.error` on failure.
- `Task:wait()` — Synchronous busy-wait while running.
- Sub-modules (task definitions, each with `skip` and `run`):
  - `git.clone` / `git.checkout` / `git.fetch` / `git.status` / `git.log` / `git.branch` / `git.origin`
  - `plugin.docs` / `plugin.build`
  - `fs.clean`

### `lazy.view` — UI
- `LazyView:create()` — Create the floating window (singleton via `M.view`).
- `LazyView:show(mode?)` — Show the view; reuses existing window if visible; no-op when headless.
- `LazyView:update()` — Render current state.
- Modes: `home`, `help`, `debug`, `profile`.
- Commands (`:Lazy <cmd>`): `home`, `show`, `help`, `debug`, `profile`, `install`, `update`, `sync`, `check`, `restore`, `clean`, `log`, `build`, `load`, `reload`, `health`, `clear`.
- Global keymaps: `K` (hover), `d` (diff), `q` (close), `<cr>` (details), `<C-s>` (profile sort), `<C-f>` (profile filter), `<C-c>` (abort).
- Diff backends: `browser`, `git`, `terminal_git`, `diffview.nvim`.
- UI sections (in order): Failed, Working, Breaking Changes, Updated, Installed, Updates, Log, Clean, Not Installed, Outdated, Loaded, Not Loaded, Disabled.

## Configuration

```lua
require("lazy").setup({
  -- Plugin list (each element is a LazyPluginSpec)
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  { "neovim/nvim-lspconfig", event = "VeryLazy" },
}, {
  -- Global configuration
  root = vim.fn.stdpath("data") .. "/lazy",
  lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
  concurrency = nil,
  defaults = { lazy = false, version = nil, cond = nil },
  spec = nil,
  dev = { path = "~/projects", patterns = {}, fallback = false },
  git = { log = { "-8" }, timeout = 120, url_format = "https://github.com/%s.git", filter = true },
  install = { missing = true, colorscheme = { "habamax" } },
  ui = {
    size = { width = 0.8, height = 0.8 },
    wrap = true,
    border = "none",
    backdrop = 60,
    title = nil,
    title_pos = "center",
    pills = true,
    icons = { ... },
    browser = nil,
    throttle = 20,
    custom_keys = { ... },
  },
  diff = { cmd = "git" },
  checker = { enabled = false, concurrency = nil, notify = true, frequency = 3600, check_pinned = false },
  change_detection = { enabled = true, notify = true },
  performance = {
    cache = { enabled = true },
    reset_packpath = true,
    rtp = { reset = true, paths = {}, disabled_plugins = { "gzip", "matchit", "matchparen", "netrwPlugin", "tarPlugin", "tohtml", "tutor", "zipPlugin" } },
  },
  readme = { enabled = true, root = vim.fn.stdpath("state") .. "/lazy/readme", files = { "README.md", "lua/**/README.md" }, skip_if_doc_exists = true },
  state = vim.fn.stdpath("state") .. "/lazy/state.json",
  build = { warn_on_override = true },
  profiling = { loader = false, require = false },
  debug = false,
})
```

### Plugin Spec (`LazyPluginSpec`) Fields

| Field | Type | Description |
|-------|------|-------------|
| `[1]` | `string?` | Short plugin URL (expanded via `config.git.url_format`) |
| `name` | `string` | Display name and config file name |
| `url` | `string?` | Custom git URL |
| `dir` | `string?` | Local plugin directory |
| `dev` | `boolean?` | Use local plugin directory instead of fetching |
| `lazy` | `boolean?` | Lazy-load the plugin |
| `enabled` | `boolean\|fun():boolean` | Include/exclude the plugin |
| `cond` | `boolean\|fun(LazyPlugin):boolean` | Conditionally load the plugin |
| `optional` | `boolean?` | Only included if specified elsewhere without `optional` |
| `priority` | `number?` | Load priority for `lazy=false` plugins (default 50) |
| `main` | `string?` | Main module for `config()` and `opts()` |
| `dependencies` | `LazySpec[]` | Plugins to load before this one |
| `init` | `fun(LazyPlugin)` | Always run during startup |
| `opts` | `table\|fun(LazyPlugin, opts:table)` | Options passed to `config()` |
| `config` | `fun(LazyPlugin, opts:table)\|true` | Run when the plugin loads |
| `build` | `fun(LazyPlugin)\|string\|list` | Build command(s) run on install/update |
| `branch` / `tag` / `commit` | `string?` | Git reference |
| `version` | `string\|false` | Semver version to install |
| `pin` | `boolean?` | Exclude from updates |
| `submodules` | `boolean?` | Fetch git submodules (default true) |
| `event` | `string\|string[]\|fun\|LazyEventSpec[]` | Lazy-load on event |
| `cmd` | `string\|string[]\|fun` | Lazy-load on command |
| `ft` | `string\|string[]\|fun` | Lazy-load on filetype |
| `keys` | `string\|string[]\|LazyKeysSpec[]\|fun` | Lazy-load on key mapping |
| `module` | `false?` | Don't auto-load this Lua module on require |

## Dependencies

- **Required**: Neovim >= 0.8.0 built with LuaJIT (`ffi` available)
- **Optional**: git >= 2.19.0 (for partial clones)
- **Optional**: a Nerd Font

## Build / Test

- **Test framework**: plenary.nvim + busted
- **Run tests**: `tests/run` script (auto-installs plenary to `.tests/site`)
- **Test environment**: Uses isolated XDG directories (`.tests/config`, `.tests/data`, etc.)
- **CI**: `.github/workflows/ci.yml`
- **Lint**: selene (`selene.toml`) + stylua (`stylua.toml`) + markdownlint (`.markdownlint.yaml`)

## Coding Conventions

- **Language**: Pure Lua (LuaJIT), using Neovim 0.8+ API
- **Naming**: Modules capitalized (`Config`, `Loader`, `Plugin`); functions camelCase
- **Type annotations**: Full `---@class` / `---@field` / `---@param` / `---@alias` / `---@type` annotations
- **Config merging**: `vim.tbl_deep_extend("force", defaults, opts)`
- **Error handling**: `Util.try(fn, msg)` wrapper + `Util.error/info/warn` notifications
- **Performance tracking**: `Util.track(id)` / `Util.track()` paired to record elapsed time
- **Caching**: `lazy.core.cache` leverages Neovim's built-in cache (`vim.loader` on nvim 0.9.1+)
- **Package loader**: Custom `package.loader` inserted at `package.loaders[3]` for on-demand loading
- **Coroutine concurrency**: `Runner` uses Lua coroutines for concurrent task execution
- **Version management**: `lazy-lock.json` records each plugin's commit hash and branch
