# CLAUDE.md - rainbow-delimiters.nvim

This file provides guidance to Claude Code for working with the rainbow-delimiters.nvim codebase.

## Project Overview

A Neovim plugin that provides alternating syntax highlighting ("rainbow parentheses") powered by Tree-sitter. The goal is to have a hackable plugin which allows for different configuration of queries and strategies, both globally and per file type. Users can override and extend the built-in defaults through their own configuration.

This is a fork of `nvim-ts-rainbow2`, which was implemented as a module for `nvim-treesitter`. Since nvim-treesitter deprecated the module system, this standalone plugin was created.

**Requirements**: Neovim >= 0.10 (recommended; legacy strategies exist for older versions), treesitter parsers for each language.

## Directory Structure

```
rainbow-delimiters.nvim/
├── lua/
│   ├── rainbow-delimiters.lua              -- Public API / entry point
│   ├── rainbow-delimiters.types.lua        -- LuaCATS type definitions (@meta)
│   └── rainbow-delimiters/
│       ├── setup.lua                       -- setup() function (sets vim.g.rainbow_delimiters)
│       ├── default.lua                     -- Default configuration (query, strategy, priority, highlight)
│       ├── config.lua                      -- Configuration lookup with fallback to defaults
│       ├── lib.lua                         -- Internal library (attach, detach, highlight, namespaces)
│       ├── match-tree.lua                  -- Match tree data structure for organizing query matches
│       ├── set.lua                         -- Set-like data structure
│       ├── stack.lua                       -- Stack-like data structure
│       ├── util.lua                        -- Internal helper functions
│       ├── log.lua                         -- Logging module
│       ├── health.lua                      -- Health check module (call manually or register)
│       ├── _test/
│       │   └── highlight.lua               -- Helper for highlight tests (record_extmarks, fetch_delimiters)
│       └── strategy/
│           ├── global.lua                  -- Global strategy dispatcher (current/legacy based on nvim version)
│           ├── global/
│           │   ├── current.lua             -- Global strategy for Neovim 0.10+
│           │   └── legacy.lua              -- Global strategy for Neovim < 0.10
│           ├── local.lua                   -- Local strategy dispatcher
│           ├── local/
│           │   ├── current.lua             -- Local strategy for Neovim 0.10+
│           │   └── legacy.lua              -- Local strategy for Neovim < 0.10
│           ├── no-op.lua                   -- Dummy strategy for testing
│           ├── christmas.lua               -- Strategy decorator (cycles colors like Christmas lights)
│           └── track.lua                   -- Strategy decorator (tracks attached buffers)
├── plugin/rainbow-delimiters.lua           -- Bootstrap (highlight groups, autocommands)
├── autoload/
│   └── rainbow_delimiters.vim              -- VimScript compatibility layer (legacy API)
├── queries/                                -- Treesitter queries by language (71 languages)
│   └── <language>/
│       ├── rainbow-delimiters.scm          -- Standard delimiter query (matches (), [], {})
│       ├── rainbow-delimiters-react.scm    -- React-aware delimiter query (JavaScript)
│       ├── rainbow-blocks.scm              -- Block-level query (e.g., LaTeX, Lua, query, verilog)
│       ├── rainbow-parens.scm              -- Parentheses-only query (JS, TSX, TypeScript)
│       └── rainbow-tags-react.scm          -- JSX tag query (JS, TSX)
├── test/                                   -- Test suite
│   ├── unit/                               -- Unit tests (busted)
│   ├── e2e/                                -- End-to-end tests (embedded Neovim via RPC)
│   │   └── strategy/                       -- Strategy-specific e2e tests
│   ├── highlight/                          -- Highlight tests
│   │   ├── busted.lua                      -- Dynamic test runner for highlight specs
│   │   ├── samples/                        -- Sample files per language
│   │   └── spec/                           -- Recorded extmark specs per language/query/sample
│   ├── stress/                             -- Stress tests
│   ├── bin/                                -- Test shims (busted, lua, nvim binaries)
│   └── xdg/                                -- XDG test config (isolated environment)
├── doc/                                    -- Vim help docs
│   ├── rainbow-delimiters.txt              -- Main documentation
│   └── news.txt                            -- Changelog
├── README.rst                              -- Main documentation
├── HACKING.rst                             -- Developer guide
├── CONTRIBUTING.rst                        -- Contributor guide
├── CHANGELOG.rst
├── TODO.rst
├── LICENSE                                 -- Apache-2.0 license
├── makefile                                -- Build/test targets
├── .busted                                 -- Busted test configuration
├── .editorconfig                           -- Editor configuration (indent style)
├── .gitignore
├── .gitmodules                             -- Git submodules (nvim-treesitter)
├── .luarc.json                             -- LuaLS configuration
├── .nvimrc                                 -- Neovim config for testing (sets busted shim)
├── .github/                                -- GitHub issue templates
└── .gitlab/                                -- GitLab issue templates
```

## Core Modules

### `lua/rainbow-delimiters.lua` - Public API

| Function | Signature | Purpose |
|---|---|---|
| `enable(bufnr)` | `integer -> void` | Enable rainbow delimiters for a buffer. |
| `disable(bufnr)` | `integer -> void` | Disable rainbow delimiters for a buffer. |
| `toggle(bufnr)` | `integer -> void` | Toggle rainbow delimiters for a buffer. |
| `is_enabled(bufnr)` | `integer -> boolean` | Check if rainbow delimiters are enabled. |

**Public fields**:
- `hlgroup_at(i)` — reference to `lib.hlgroup_at` for getting highlight group at index.
- `strategy` — table of available strategies: `['global']`, `['local']`, `['noop']`.

### `lua/rainbow-delimiters/setup.lua` - Setup Function

```lua
require('rainbow-delimiters.setup').setup {
    strategy = { ... },
    query = { ... },
    priority = { ... },
    highlight = { ... },
    whitelist = { ... },
    blacklist = { ... },
    condition = function(bufnr) ... end,
    log = { level = ..., file = ... },
}
```

Sets `vim.g.rainbow_delimiters` to the provided config. Also callable directly via metatable `__call`.

### `lua/rainbow-delimiters/default.lua` - Default Configuration

Default configuration (`rainbow_delimiters.config`):

| Field | Default | Purpose |
|---|---|---|
| `query` | `{[''] = 'rainbow-delimiters', javascript = 'rainbow-delimiters-react'}` | Query names by filetype. |
| `strategy` | `{[''] = require 'rainbow-delimiters.strategy.global'}` | Highlight strategies by filetype. |
| `priority` | `{[''] = floor((semantic_tokens + treesitter) / 2)}` | Highlight priority. |
| `log` | `{level = WARN, file = stdpath('log') .. '/rainbow-delimiters.log'}` | Logging settings. |
| `highlight` | `{'RainbowDelimiterRed', 'RainbowDelimiterYellow', 'RainbowDelimiterBlue', 'RainbowDelimiterOrange', 'RainbowDelimiterGreen', 'RainbowDelimiterViolet', 'RainbowDelimiterCyan'}` | Highlight groups in order. |

Uses `get_with_fallback(table, key)` to fall back to `''` (empty string) key when a specific filetype is not configured.

### `lua/rainbow-delimiters/config.lua` - Configuration Lookup

Provides metatable-based lookup tables (`query`, `strategy`, `priority`, `log`) that fall back through:
1. User setting for filetype
2. User setting for fallback (`''`)
3. Default setting for filetype
4. Default setting for fallback (`''`)

The `highlight` field is handled separately via the top-level metatable `__index` (user setting, then default).

Also provides:
- `enabled_for(lang)` — checks whitelist/blacklist.
- `enabled_when(bufnr)` — evaluates the user-supplied `condition` function (returns true if no condition is set).

### `lua/rainbow-delimiters/lib.lua` - Internal Library

**Shared internal functions** (not for use by strategies):

| Function | Signature | Purpose |
|---|---|---|
| `get_query(lang, bufnr)` | `(string, integer?) -> Query?` | Gets the treesitter query for a language. Query name can be a function. |
| `highlight(bufnr, lang, node, hlgroup)` | `(integer, string, TSNode, string) -> void` | Highlights a node with a highlight group. Priority can be a function. |
| `hlgroup_at(i)` | `(integer) -> string` | Returns the highlight group name at index i (wraps around). |
| `clear_namespace(bufnr, lang, line_start, line_end)` | `(integer, string, integer?, integer?) -> void` | Clears highlights in a range. |
| `attach(bufnr)` | `(integer) -> void` | Attaches to a buffer (sets up parser callbacks, initial highlight). |
| `detach(bufnr)` | `(integer) -> void` | Detaches from a buffer (clears highlights, destroys parser). |

**State**:
- `nsids` — per-language namespaces (lazy instantiation via metatable; immutable after creation).
- `buffers` — table of attached buffer settings (key: bufnr, value: settings table or `false` if disabled).
- `enabled_for` — reference to `config.enabled_for`.

### `lua/rainbow-delimiters/match-tree.lua` - Match Tree

Data structure for organizing query matches hierarchically.

**`Match`** class:
- `container` — the container TSNode.
- `sentinel` — marks the last delimiter.
- `delimiters` — Set of delimiter nodes.

**`MatchTree`** class:
- `match` — the Match object.
- `children` — Set of child MatchTrees.

Supports `__lt` (partial ordering by containment) and `__call` (append child).

**Functions**:
- `assemble(query, match)` — creates a MatchTree from query iter_matches result.
- `highlight(tree, bufnr, lang, level, pred)` — applies highlighting recursively with optional predicate.

### `lua/rainbow-delimiters/strategy/` - Strategies

**Strategy protocol** (from `types.lua`):
```lua
---@class rainbow_delimiters.strategy
---@field on_attach fun(bufnr: integer, settings: rainbow_delimiters.buffer_settings)
---@field on_detach fun(bufnr: integer)
---@field on_reset fun(bufnr: integer, settings: rainbow_delimiters.buffer_settings)
```

**Available strategies**:
- `strategy.global` — highlights all visible buffers (default). Dispatches to `current` or `legacy` based on Neovim version.
- `strategy.local` — highlights only the current buffer (cursor scope).
- `strategy.no-op` — does nothing (for testing).

**Strategy decorators** (functions that wrap a strategy and return a new strategy):
- `strategy.christmas` — `lights(strategy?, delay?)` cycles colors like Christmas lights using a timer.
- `strategy.track` — `track(strategy)` tracks all attached buffers (exposes `.buffers` and `.attachments`).

**Neovim version dispatch**: `global.lua` and `local.lua` check `vim.fn.has 'nvim-0.10'` to load `current.lua` (for 0.10+) or `legacy.lua` (for older). This is due to changes in `Query:iter_captures()` behavior (see neovim/neovim#27296).

### `lua/rainbow-delimiters/set.lua` - Set Data Structure

Set-like table with `add`, `contains`, `size`, `items` methods. Constructor: `Set.new(...)`.

### `lua/rainbow-delimiters/stack.lua` - Stack Data Structure

Stack-like table with `size`, `peek`, `push`, `pop`, `iter` methods. Constructor: `Stack.new(items)`.

### `lua/rainbow-delimiters/util.lua` - Internal Helpers

| Function | Purpose |
|---|---|
| `for_each_child(parent_lang, lang, language_tree, thunk)` | Recursively applies thunk to language tree and children (replacement for deprecated `LanguageTree:for_each_child`). |

### `lua/rainbow-delimiters/log.lua` - Logging

Logger module. Logs messages with level >= configured level. Dynamically determines calling module from debug info. Provides `error`, `warn`, `debug`, `trace`, `info` methods.

### `lua/rainbow-delimiters/health.lua` - Health Check

Health check module. Not automatically registered as a `:checkhealth` provider; call `require 'rainbow-delimiters.health'.check()` manually or register it. Validates:
- Parser installation for configured languages.
- Strategy validity (checks `on_attach`, `on_detach`, `on_reset` fields).
- Query validity.
- Priority validity.
- Highlight group configuration.
- Logging configuration.
- Configuration schema.

### `plugin/rainbow-delimiters.lua` - Bootstrap

1. Defines highlight groups (`RainbowDelimiterRed`, etc.) with `default = true` (gruvbox-inspired colors).
2. Sets up `ColorScheme` autocmd to re-apply highlight groups.
3. Sets up `FileType` autocmd to attach to new buffers (checks `config.enabled_for` and `config.enabled_when`).
4. Sets up `BufUnload` autocmd to detach from unloaded buffers.
5. Sets `vim.g.loaded_rainbow = true`.

### `autoload/rainbow_delimiters.vim` - VimScript Compatibility

Legacy VimScript API that delegates to the Lua module. Provides:
- `rainbow_delimiters#strategy` table (global, local, noop)
- `rainbow_delimiters#hlgroup_at(i)`
- `rainbow_delimiters#enable(bufnr)`
- `rainbow_delimiters#disable(bufnr)`
- `rainbow_delimiters#toggle(bufnr)`
- `rainbow_delimiters#is_enabled(bufnr)`

## Configuration

Configuration is done by setting entries in the Vim script dictionary `g:rainbow_delimiters`:

```lua
local rainbow_delimiters = require 'rainbow-delimiters'

---@type rainbow_delimiters.config
vim.g.rainbow_delimiters = {
    strategy = {
        [''] = rainbow_delimiters.strategy['global'],
        vim = rainbow_delimiters.strategy['local'],
    },
    query = {
        [''] = 'rainbow-delimiters',
        lua = 'rainbow-blocks',
    },
    priority = {
        [''] = 110,
        lua = 210,
    },
    highlight = {
        'RainbowDelimiterRed',
        'RainbowDelimiterYellow',
        'RainbowDelimiterBlue',
        'RainbowDelimiterOrange',
        'RainbowDelimiterGreen',
        'RainbowDelimiterViolet',
        'RainbowDelimiterCyan',
    },
}
```

Or using the `setup` function:
```lua
require('rainbow-delimiters.setup').setup { ... }
```

**Config schema** (from `types.lua`):
- `strategy` — per-filetype strategy (strategy object or function returning strategy).
- `query` — per-filetype query name (string or function returning string).
- `priority` — per-filetype highlight priority (integer or function returning integer).
- `highlight` — list of highlight group names.
- `whitelist` — list of languages to highlight (exclusive with blacklist).
- `blacklist` — list of languages to not highlight.
- `condition` — dynamic condition `fun(bufnr): boolean`.
- `log` — `{level, file}` logging config.

## Queries

The plugin uses treesitter queries to identify delimiters. Query files are in `queries/<language>/`:

- `rainbow-delimiters.scm` — standard delimiter query (matches `()`, `[]`, `{}`).
- `rainbow-delimiters-react.scm` — React-aware delimiter query (JavaScript default).
- `rainbow-blocks.scm` — block-level query (e.g., LaTeX `\begin`/`\end`, Lua `do`/`end`, query, verilog).
- `rainbow-parens.scm` — parentheses-only query (JS, TSX, TypeScript).
- `rainbow-tags-react.scm` — JSX tag query (JS, TSX).

71 languages are supported with queries.

## Dependencies

- **Required**: Neovim with treesitter support (`vim.treesitter`).
- **Required**: Treesitter parsers for each language (installed separately).
- **Optional**: nvim-treesitter (for parser management, but not required).

## Building / Testing

**Makefile targets** (see `makefile`):
- `check`: Runs all tests (unit-test, e2e-test, highlight-test).
- `unit-test`: Runs busted unit tests.
- `e2e-test`: Runs end-to-end tests.
- `highlight-test`: Runs highlight tests.
- `record-highlight`: Records extmarks for highlight specs (requires `LANGUAGE` variable).
- `clean`: Cleans test artifacts.

**Busted configuration** (`.busted`):
- `unit` — unit tests in `test/unit/`.
- `e2e` — end-to-end tests in `test/e2e/`.
- `highlight` — highlight tests in `test/highlight/busted.lua`.

**Running tests**:
```bash
make check          # all tests
make unit-test      # unit tests only
make e2e-test       # e2e tests only
make highlight-test # highlight tests only
```

**Highlight testing workflow**:
1. Sample files live in `test/highlight/samples/<lang>/`.
2. Recorded specs live in `test/highlight/spec/<lang>/<query>/<sample>.lua`.
3. Record new specs with: `make record-highlight LANGUAGE=lua`
4. The `_test/highlight.lua` module provides `record_extmarks(language, sample, query)` and `fetch_delimiters(nvim, lang, sample, query)`.

**Code style**: configured via `.editorconfig` (tab indent for Lua, 2-space indent for `.scm`, UTF-8, LF line endings). Luacheck for linting (no config file present).

## Code Style / Conventions

- **EditorConfig** (`.editorconfig`): tab indent for `.lua` files, 2-space indent for `.scm` files, UTF-8, LF.
- **Luacheck** for linting.
- **Vim modeline** at end of files: `-- vim:tw=79:ts=4:sw=4:noet:` (most files); `-- vim:ft=lua` (`.busted`).
- **License headers**: Apache-2.0 for Lua source files; Unlicense SPDX headers for `makefile` and `.busted`.
- LuaCATS type annotations in `types.lua` (`@meta` file).
- Module pattern: each file returns `local M = {}` table.
- Object-oriented patterns using metatables (`Set`, `Stack`, `MatchTree`).

## Key Patterns

- **Strategy pattern**: Strategies implement `on_attach`, `on_detach`, `on_reset` functions. The plugin dispatches to the appropriate strategy based on filetype.
- **Strategy decorators**: `christmas` and `track` are not strategies themselves but functions that wrap a strategy and return a new strategy.
- **Match tree**: Query matches are organized into a tree structure based on containment. The tree is used to assign highlight groups by depth.
- **Namespace per language**: Each language gets its own namespace for highlights, allowing independent clearing.
- **Fallback configuration**: All config lookups fall back to the `''` (empty string) key for defaults.
- **Neovim version dispatch**: Global and local strategies dispatch to `current` or `legacy` implementations based on Neovim version.
- **Parser callbacks**: `lib.attach` registers `on_detach` and `on_child_removed` callbacks on the parser, not autocommands.
- **Lazy namespaces**: `lib.nsids` uses a metatable to create namespaces on demand.
