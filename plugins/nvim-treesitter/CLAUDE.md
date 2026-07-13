# CLAUDE.md - nvim-treesitter

This file provides guidance to Claude Code for working with the nvim-treesitter codebase.

## Project Overview

nvim-treesitter is the central Neovim abstraction over the tree-sitter C library. It provides:
- Parser installation, management, and language registration
- A module system for features (highlight, indent, incremental_selection, folding, locals, etc.)
- Treesitter query infrastructure for all installed languages

**Important**: This is a Neovim-specific Lua plugin backed by the tree-sitter C library. It targets Neovim 0.9.2+ and uses the modern `vim.treesitter` API (e.g., `vim.treesitter.start/stop`, `vim.treesitter.language.register`).

## Directory Structure

```
nvim-treesitter/
├── lua/nvim-treesitter.lua             -- Main entry: setup(), define_modules(), statusline()
├── lua/nvim-treesitter/
│   ├── caching.lua                     -- Buffer cache utility for module state
│   ├── compat.lua                      -- Compatibility shims for vim.treesitter API changes
│   ├── configs.lua                     -- Configuration and module registry (core)
│   ├── fold.lua                        -- Folding based on treesitter queries
│   ├── health.lua                      -- :checkhealth provider
│   ├── highlight.lua                   -- Syntax highlighting module (vim.treesitter.start/stop)
│   ├── incremental_selection.lua       -- Incremental selection navigation
│   ├── indent.lua                      -- Treesitter-based indentation (vim.bo.indentexpr)
│   ├── info.lua                        -- Parser info, :TSInstallInfo, etc.
│   ├── install.lua                     -- Parser installation (git clone, compiler, etc.)
│   ├── locals.lua                      -- Local definitions/references/scope queries
│   ├── parsers.lua                     -- Parser configurations for all languages (~270+)
│   ├── query.lua                       -- Query loading, matching, cache invalidation
│   ├── query_predicates.lua            -- Built-in query predicates (@*, #*)
│   ├── shell_command_selectors.lua     -- OS-specific shell command selectors
│   ├── statusline.lua                  -- Statusline integration
│   ├── ts_utils.lua                    -- Utility functions for TS node manipulation
│   ├── tsrange.lua                     -- TSRange for range-based highlighting
│   └── utils.lua                       -- General utilities (command registration, etc.)
├── plugin/nvim-treesitter.lua          -- Autocmd setup, lazy-loads modules
├── parser-info/                        -- Parser metadata (per-language .info files)
├── parser/                             -- Compiled parser storage location (.so files)
├── queries/                            -- Treesitter queries by language (scm files)
│   └── <language>/
│       ├── highlights.scm
│       ├── locals.scm
│       ├── folds.scm
│       ├── indents.scm
│       ├── injections.scm
│       └── textobjects.scm
├── scripts/                            -- Utility scripts (pre-push, format-queries, etc.)
├── tests/                              -- Test directory (indent/, query/, unit/)
└── CONTRIBUTING.md                     -- Contributor guide with query conventions
```

## Core Modules

### Entry Points
- **`lua/nvim-treesitter.lua`**: Top-level module. `setup()` initializes all sub-modules and registers commands (`:TSInstall`, `:TSInfo`, `:TSConfig`). `define_modules()` registers external modules. `statusline()` provides statusline string.
- **`plugin/nvim-treesitter.lua`**: Bootstraps the plugin on load. Calls `setup()` and sets up autocommands (Filetype for query file reloading via `invalidate_query_file`).

### configs.lua - Configuration & Module System
- **`TSModule`** class: defines a feature module with `module_path`, `enable`, `disable`, `keymaps`, `is_supported`, `attach()`, `detach()`, `enabled_buffers`, `additional_vim_regex_highlighting`.
- **`TSConfig`** class: top-level config with `modules`, `sync_install`, `ensure_installed`, `auto_install`, `ignore_install`, `parser_install_dir`.
- Built-in modules: `highlight`, `incremental_selection`, `indent`.
- Key functions: `define_modules()`, `get_module()`, `enable_module()`, `disable_module()`, `attach_module()`, `detach_module()`, `reattach_module()`, `is_module()`, `available_modules()`.
- `recurse_modules()`: walks module definitions tree.
- `init()`: processes queued module definitions and registers commands.

### install.lua - Parser Management
- Manages parser installation via git clone + compilation (gcc/clang/zig or tree-sitter CLI).
- Uses `vim.loop.spawn` (libuv) directly for async process execution (no plenary.nvim dependency).
- Lockfile tracking in `lockfile.json` (per-language revision pinning).
- Commands: `:TSInstall`, `:TSInstallFromGrammar`, `:TSUpdate`, `:TSUninstall`.
- `auto_install`: automatically installs parsers when opening supported filetypes.
- Compiler preference order: `$CC`, `cc`, `gcc`, `clang`, `cl`, `zig`.
- On Windows, prefers git-based installation (no tar).

### parsers.lua - Parser Registry
- Defines all ~270+ parser configs as `InstallInfo` entries in a `list` table.
- Maps filetypes to parser names via `register_lang()` (e.g., `jsx` -> `javascript`, `html_tags` -> `html`, `typescript.tsx` -> `tsx`).
- Uses `vim.treesitter.language.register()` on modern Neovim; falls back to `filetype_to_parsername` table (deprecated) on older versions.
- Each parser entry has `install_info` (url, files, branch, revision, etc.) and `maintainers`.
- Key functions: `ft_to_lang()`, `available_parsers()`, `get_parser_configs()`, `get_buf_lang()`.

### query.lua - Query Infrastructure
- `built_in_query_groups`: `highlights`, `locals`, `folds`, `indents`, `injections`.
- Loads/reloads queries for installed parsers; caches them by buffer and changedtick.
- `invalidate_query_file()`: clears query cache on write (called from plugin autocmd).
- `has_highlights()`, `has_locals()`, `has_folds()`, `has_indents()`, `has_injections()`: feature support checks (auto-generated from `built_in_query_groups`).
- `get_capture_matches_recursively()`: used by locals and fold modules.
- `collect_group_results()` / `iter_group_results()`: iterate query matches for a buffer.
- `available_query_groups()`: discovers all query groups from runtime files.

### highlight.lua
- Provides treesitter-based syntax highlighting.
- Uses `vim.treesitter.start(bufnr, lang)` / `vim.treesitter.stop(bufnr)` (modern Neovim API).
- `attach()`: starts the highlighter and optionally enables vim regex syntax.
- `detach()`: stops the highlighter.
- Deprecated `start()` / `stop()` wrappers redirect to `attach()` / `detach()`.

### indent.lua
- Treesitter-based indentation via `vim.bo.indentexpr`.
- Uses `vim.treesitter.query` indent computation.
- Avoids force reparsing for YAML.
- Recognizes comment parsers (`comment`, `jsdoc`, `phpdoc`).

### fold.lua
- Treesitter-based folding via `vim.wo.foldexpr`.
- Uses `@fold` captures from `folds.scm` queries, falls back to `@scope` from `locals.scm`.
- Respects `foldnestmax` option.

### incremental_selection.lua
- Incremental (de)selection of syntax nodes.
- Default keymaps: `gnn` (init), `grn` (node incremental), `grc` (scope incremental), `grm` (node decremental).
- Uses `ts_utils.get_node_at_cursor()` and node tree traversal.

### locals.lua
- Local definitions, references, and scopes from `locals.scm` queries.
- `collect_locals()`, `iter_locals()`, `get_locals()`, `get_definitions()`, `get_references()`, `get_scopes()`.
- `get_definition_id()`: creates unique ID from scope and text.

### ts_utils.lua
- Core utility functions for tree-sitter node manipulation.
- `get_node_text()`, `get_node_at_cursor()`, `get_nodes_at_cursor()`.
- `get_prev_node()`, `get_next_node()`, `parent()`.
- `memoize_by_buf_tick()`: caching decorator used by fold module.
- `_get_line_for_node()`: used by statusline module.

### info.lua
- `:TSInstallInfo` command: lists all parsers and installation status.
- `:TSModuleInfo` command: lists module state per filetype.
- `install_info()`: prints sorted parser list with installed/not-installed status.

### statusline.lua
- `statusline()`: generates a statusline string showing the current node's context (class/function/method hierarchy).
- Configurable via `indicator_size`, `type_patterns`, `transform_fn`, `separator`, `allow_duplicates`.

### caching.lua
- `create_buffer_cache()`: creates a per-buffer cache that auto-cleans on buffer detach.
- Uses `nvim_buf_attach()` with `on_detach` callback for cleanup.

### compat.lua
- Shims for `vim.treesitter.query` API changes across Neovim versions.
- Wraps `get_query_files`/`get_query`, `get_query`/`get_query`, `parse_query`/`parse_query`, `get_range`, `get_node_text`.

### health.lua
- `:checkhealth` provider.
- Checks: Neovim version (>= 0.9.2), tree-sitter CLI, parser ABI version (minimum 13), runtimepath config.

### query_predicates.lua
- Registers custom tree-sitter query predicates and directives.
- Handles injection language resolution (e.g., markdown info strings, HTML script type).
- Injection aliases: `ex`->`elixir`, `pl`->`perl`, `sh`->`bash`, `uxn`->`uxntal`, `ts`->`typescript`.

### shell_command_selectors.lua
- OS-specific shell command construction (Windows vs Unix).
- Handles `cmd.exe` path conversion when `shellslash` is set.

### tsrange.lua
- `TSRange` class for range-based highlighting.
- Supports creating ranges from buffer positions or TS nodes.
- Used for range-based highlight operations.

### utils.lua
- `notify()`: wrapper around `vim.notify` with default title.
- `get_path_sep()`, `join_path`, `join_space`: path manipulation utilities.
- `setup_commands()`: registers user-defined commands from module `commands` tables.
- `ts_cli_version()`: gets tree-sitter CLI version.

## Code Style / Conventions

- **Stylua** config (`.stylua.toml`): column_width=120, 2-space indent, Unix LF, AutoPreferDouble, no call parens.
- **Luacheck** for linting (`.luacheckrc`): ignores unused args (212), redefining locals (411/412), shadowing (422), readonly globals (122).
- **EditorConfig**: 2-space indent for Lua, 4-space for Python, tabs for Makefiles.
- Vim modeline-style file headers (`-- Last Change:`) in some files.
- Heavy use of `vim.treesitter` and `vim.api.nvim_*`.
- Query files (`queries/*/*.scm`) follow tree-sitter query syntax with 2-space indentation.
- Type annotations using `---@class`, `---@field`, `---@param` (EmmyLua-style).

## Dependencies

- **Required**: Neovim >= 0.9.2 with treesitter support (`vim.treesitter`), tree-sitter C library.
- **Required**: `tar` and `curl` (or `git`) in PATH for parser download.
- **Required**: C compiler (gcc/clang/zig) in PATH for parser compilation.
- **Optional**: `tree-sitter` CLI (only needed for `:TSInstallFromGrammar`, not for `:TSInstall`).

## Building / Testing

- Tests exist in `tests/` (indent/, query/, unit/) but coverage is limited.
- Style checks: `luacheck` + `stylua`.
- Pre-push hook: `ln -s ../../scripts/pre-push .git/hooks/pre-push`.
- Query formatting: `./scripts/format-queries.lua <file_or_dir>`.
- Lockfile update: `./scripts/update-lockfile.sh`.
- README parser list auto-generated by `./scripts/update-readme.lua`.

## Key Patterns

- **Module registration**: External plugins call `require('nvim-treesitter').define_modules { name = { module_path = "..." } }`.
- **Lazy loading**: Modules attach/detach on Filetype autocmd.
- **Buffer caching**: `caching.create_buffer_cache()` for per-buffer module state with auto-cleanup on detach.
- **Query inheritance**: `; inherits: lang1,lang2` at top of .scm files. Optional inheritance uses parentheses: `; inherits: lang1,(optionallang)`.
- **Query format-ignore**: `; format-ignore` directive to preserve specific formatting.
- **Filetype to parser mapping**: `vim.treesitter.language.register(lang, ft)` on modern Neovim; deprecated `filetype_to_parsername` table as fallback.
- **Parser installation**: git clone -> compile (via libuv spawn) -> place .so in runtimepath.
- **ABI compatibility**: minimum tree-sitter ABI version is 13.
