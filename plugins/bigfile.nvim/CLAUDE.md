# bigfile.nvim - CLAUDE.md

## Project Overview

bigfile.nvim is a Neovim performance optimization plugin that automatically disables
certain features (such as LSP, treesitter, syntax highlighting, etc.) when opening
large files to improve the editing experience. The file size threshold and the list
of features to disable are both configurable, and users can also define custom features.

## Directory Structure

```
bigfile.nvim/
├── lua/bigfile/
│   ├── init.lua              # Main module: setup(), BufReadPre callback, big-file detection
│   └── features.lua          # Feature registry: built-in feature definitions and custom-feature API
├── after/plugin/bigfile.lua  # Deferred entry point (runs setup on first load)
├── test/
│   ├── minimal_init.lua      # Minimal init used by tests (PLENARY_DIR, NVIM_TS_DIR)
│   ├── specs/
│   │   ├── default_spec.lua  # Tests for default configuration
│   │   └── features_spec.lua # Tests for individual features
│   └── data/                 # Test data fixtures (large files)
├── Makefile                  # Build / test / lint commands
├── README.md
└── .stylua.toml              # Lua formatting configuration
```

## Core Modules

### `bigfile` (`lua/bigfile/init.lua`)
Configuration entry point and big-file detection logic.

- **M.setup(overrides?)** — Merges user overrides with `default_config`, creates the
  `"bigfile"` augroup, and registers a `BufReadPre` autocmd that calls
  `pre_bufread_callback`. Sets `vim.g.loaded_bigfile_plugin = true` so the deferred
  plugin file is a no-op after explicit setup.
- **M.config** — Alias for `M.setup` (provided for plugin-manager conventions).
- **get_buf_size(bufnr?)** — Returns the file size in MiB, rounded to the nearest
  integer (`math.floor(0.5 + bytes / (1024 * 1024))`). Returns `nil` if the buffer
  has no valid associated filename.
- **pre_bufread_callback(bufnr, config)** — Core detection:
  1. Short-circuits if the `bigfile_detected` buffer variable is already set.
  2. Computes file size in MiB.
  3. If `config.pattern` is a function, runs it `(bufnr, filesize_mib)` and uses its
     return value as a fallback when the function returns `nil`/`false` (i.e. size
     threshold is still honored).
  4. Sets `bigfile_detected` to `0` or `1` on the buffer.
  5. Resolves features via `features.get_feature`, splits into deferred vs. immediate,
     calls `feature.disable(bufnr)` immediately for non-deferred features, and
     schedules deferred feature disabling on `BufReadPost`.

The default `config` class:

```lua
---@class config
---@field filesize integer size in MiB
---@field pattern string|string[]|fun(bufnr: number, filesize_mib: number): boolean
---@field features string[] array of features
```

Default `filesize` is `2` (MiB); default `pattern` is `{ "*" }`.

### `bigfile.features` (`lua/bigfile/features.lua`)
Feature registry. Each feature is registered via `feature(name, content)` and validated
with `vim.validate`. The public API is:

- **M.get_feature(raw_feature)** — Resolves a feature. If `raw_feature` is a string it is
  looked up in the registry; if it is a table it is registered as a custom feature.
  Emits a `vim.notify` warning at `WARN` level for unknown features.

Custom feature shape:

```lua
{
    name = "myfeature",          -- unique name
    opts = { defer = false },    -- true => run disable() on BufReadPost instead of BufReadPre
    disable = function(bufnr)    -- called to disable the feature
        -- ...
    end,
}
```

#### Built-in Features
| Name               | Defer | Description                                                                  |
| ------------------ | ----- | ---------------------------------------------------------------------------- |
| `matchparen`       | no    | Runs `:NoMatchParen` (global); stays disabled after the big file is closed. Has `opts = { global = true }`. |
| `lsp`              | no    | Creates an `LspAttach` autocmd that detaches the LSP client from the buffer. |
| `treesitter`       | no    | Configures nvim-treesitter's module `disable` callbacks and sets `bigfile_disable_treesitter` buffer var. |
| `illuminate`       | no    | Calls `require("illuminate.engine").stop_buf(buf)` via pcall.                |
| `indent_blankline` | no    | Calls `require("indent_blankline.commands").disable()` via pcall.           |
| `vimopts`          | no    | Disables `swapfile`, sets `foldmethod = "manual"`, `undolevels = -1`, `undoreload = 0`, `list = false`. |
| `syntax`           | yes   | Runs `syntax clear` then sets `vim.opt_local.syntax = "OFF"`.                |
| `filetype`         | yes   | Clears file type with `vim.opt_local.filetype = ""`.                         |

## Configuration

```lua
require("bigfile").setup({
    filesize = 2,        -- file size threshold in MiB (rounded to nearest MiB)
    pattern = { "*" },   -- autocmd pattern or custom detection function
    features = {         -- list of features to disable
        "indent_blankline",
        "illuminate",
        "lsp",
        "treesitter",
        "syntax",
        "matchparen",
        "vimopts",
        "filetype",
    },
})
```

You may also use the `M.config` alias, which is common across LunarVim plugins:

```lua
require("bigfile").config { ... }
```

### Custom pattern function

```lua
pattern = function(bufnr, filesize_mib)
    -- Return true to mark big, false/nil to fall back to `filesize` threshold
    local filetype = vim.filetype.match({ buf = bufnr })
    return filetype == "python" and filesize_mib > 1
end
```

## Dependencies

- **Hard dependencies:** none.
- **Optional integrations:** `nvim-lua/plenary.nvim` (tests), `nvim-treesitter/nvim-treesitter`
  (tests and the `treesitter` feature), `RRethy/vim-illuminate` (the `illuminate` feature),
  `lukas-reineke/indent-blankline.nvim` (the `indent_blankline` feature), Neovim's built-in
  LSP client (the `lsp` feature).
- **Downstream:** users load the plugin directly via their plugin manager; it does not
  expose itself as a library for other plugins.

## Build / Test

The `Makefile` provides the following targets:

- **`make test`** — Fetches test dependencies, generates test fixtures, and runs
  `PlenaryBustedDirectory` against `test/specs/`.
- **`make test-file FILE=path`** — Runs a single test file through plenary.busted.
- **`make test-data`** — Downloads/generates fixture files under `test/data/`.
- **`make deps`** — Clones `plenary.nvim` and `nvim-treesitter` into the pack path.
- **`make lint`** — Runs `luacheck lua` and `stylua --check lua`.

Test runner invocation:

```bash
nvim --headless -u test/minimal_init.lua \
  -c "PlenaryBustedDirectory test/specs { minimal_init = 'test/minimal_init.lua' }"
```

## Coding Conventions

- **Indentation:** 2 spaces (see `.stylua.toml`).
- **Line width:** 100 columns.
- **Line endings:** Unix (`lf`).
- **Quotes:** auto-prefer double; call parentheses omitted (`call_parentheses = "None"`).
- **Module pattern:** each module returns a single `local M = {}` table.
- **Validation:** user-supplied inputs are validated with `vim.validate`.
- **Defensive calls:** optional dependencies are loaded through `pcall` / `pcall(require, ...)`.
- **Warnings:** unknown features are reported via `vim.notify(..., vim.log.levels.WARN)`.
- **Feature lists:** transformed with `vim.tbl_map` and iterated with `ipairs`.
- **Naming:** public functions use `M.PascalCase` (e.g. `M.setup`, `M.get_feature`);
  module-local functions and helpers use `snake_case`.
- **Type annotations:** EmmyLua `---@class` / `---@field` / `---@param` annotations are used
  throughout `init.lua` and `features.lua`.
