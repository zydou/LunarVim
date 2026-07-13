# CLAUDE.md - nvim-ts-context-commentstring

This file provides guidance to Claude Code for working with the nvim-ts-context-commentstring codebase.

## Project Overview

A Neovim plugin that dynamically sets the `commentstring` option based on the cursor's location within a treesitter parse tree. Its primary purpose is to handle embedded languages (e.g., HTML/CSS/JS inside Vue, JSX inside TSX) where different sections of a file require different comment styles.

**Key design principle**: The plugin ONLY modifies `vim.bo.commentstring`. It provides no commenting keybindings of its own and is designed to be paired with a commenting plugin (Comment.nvim, vim-commentary, etc.).

**Requirements**: Neovim >= 0.9.4, treesitter parsers (via nvim-treesitter or manual TS grammar installation).

## Directory Structure

```
nvim-ts-context-commentstring/
├── lua/
│   ├── ts_context_commentstring.lua              -- Public API / entry point
│   └── ts_context_commentstring/
│       ├── config.lua                            -- Configuration schema and defaults
│       ├── internal.lua                          -- Core engine (tree walking, buffer setup)
│       ├── utils.lua                             -- Cursor/visual position utilities
│       └── integrations/
│           ├── comment_nvim.lua                  -- Comment.nvim pre_hook factory
│           └── vim_commentary.lua                -- vim-commentary <Plug> mappings
├── plugin/ts_context_commentstring.lua           -- Vimscript bootstrap (FileType autocmd)
├── utils/
│   ├── minimal_init.lua                          -- Minimal config for testing
│   └── run_minimal.sh                            -- Launches nvim with minimal_init.lua
├── doc/
│   └── nvim-ts-context-commentstring.txt         -- Vim help docs
├── .github/
│   ├── workflows/default.yml                     -- CI: Stylua lint check
│   └── ISSUE_TEMPLATE/bug_report.yml             -- Bug report template
├── README.md
├── LICENSE
└── stylua.toml
```

## Core Modules

### `lua/ts_context_commentstring.lua` - Public API

Thin facade delegating to `internal` and `config`.

| Function | Signature | Purpose |
|---|---|---|
| `setup(config)` | `ts_context_commentstring.Config -> void` | Merges user config into defaults via `config.update()`. |
| `calculate_commentstring(args?)` | `Args? -> string \| nil` | Pure calculation — returns commentstring without mutating state. |
| `update_commentstring(args?)` | `Args? -> void` | Calculates and applies commentstring to buffer. Falls back to original. |

**Args** class:
- `key: string` — which key to prefer from `CommentConfigMultiple` (defaults to `'__default'`)
- `location: Location` — optional override location (0-indexed `{line, col}` 2-tuple)

### `lua/ts_context_commentstring/config.lua` - Configuration

Defines config schema (LuaCATS `@class`/`@alias`), default values, and merge function.

| Function | Signature | Purpose |
|---|---|---|
| `update(config?)` | `Config? -> void` | Deep-extends current config via `vim.tbl_deep_extend('force', ...)`. |
| `is_autocmd_enabled()` | `() -> boolean` | Returns false if vim-commentary loaded, else `config.enable_autocmd`. |
| `get_languages_config()` | `() -> LanguagesConfig` | Merges new `languages` table with deprecated `config` table. |

**Config fields** (`ts_context_commentstring.Config`):

| Field | Type | Default | Purpose |
|---|---|---|---|
| `enable_autocmd` | `boolean` | `true` | Auto-update commentstring on `CursorHold`. |
| `custom_calculation` | `fun(node, language_tree): string` | `nil` | User-supplied custom commentstring logic (takes priority). |
| `languages` | `LanguagesConfig` | (see below) | Per-language commentstrings. Keys are **treesitter language names**, not filetypes. |
| `config` | `LanguagesConfig` | `{}` | **Deprecated** — legacy key, merged with `languages`. |
| `commentary_integration` | `CommentaryConfig` | `{...}` | Keybinding overrides for vim-commentary integration. |

**Type aliases**:
- `CommentConfig` = `string | CommentConfigMultiple`
- `CommentConfigMultiple` = `{__default: string, __multiline: string}`
- `LanguageConfig` = `CommentConfig | table<string, CommentConfig>`
- `LanguagesConfig` = `table<string, LanguageConfig>`

**Default languages configured**: astro, c, css, gleam, glimmer, go, graphql, haskell, handlebars, hcl, html, ini, lua, nix, php, python, rescript, scss, sh, bash, solidity, sql, svelte, terraform, twig, typescript, vim, vue, zsh, kotlin, roc, tsx (with javascript aliased to tsx).

**TSX multi-node config** — `tsx` (and `javascript`) define per-node-type overrides:
```lua
tsx = {
  __default = '// %s',
  __multiline = '/* %s */',
  jsx_element = '{/* %s */}',
  jsx_fragment = '{/* %s */}',
  jsx_attribute = { __default = '// %s', __multiline = '/* %s */' },
  comment = { __default = '// %s', __multiline = '/* %s */' },
  call_expression = { __default = '// %s', __multiline = '/* %s */' },
  statement_block = { __default = '// %s', __multiline = '/* %s */' },
  spread_element = { __default = '// %s', __multiline = '/* %s */' },
}
```

### `lua/ts_context_commentstring/internal.lua` - Core Engine

The heart of the plugin. Contains treesitter traversal logic, buffer setup, and deprecated nvim-treesitter module bridge.

| Function | Signature | Purpose |
|---|---|---|
| `setup_buffer(bufnr)` | `number -> void` | Per-buffer init: saves original commentstring, sets up commentary mappings, creates CursorHold autocmd. |
| `calculate_commentstring(args?)` | `Args? -> string \| nil` | Main calculation logic. Gets node at cursor, applies custom_calculation, calls check_node. |
| `update_commentstring(args?)` | `Args? -> void` | Calls calculate_commentstring and sets vim.bo.commentstring (or restores original). |
| `check_node(node, language_config, commentstring_key)` | `(table, LanguageConfig, string) -> string \| nil` | **Recursive tree walker.** Checks if current node's type matches a key in language config; if not, recurses to parent. |
| `attach()` | `() -> void` | **Deprecated.** Old nvim-treesitter module entry point. |
| `detach()` | `() -> void` | **Deprecated.** No-op. |

**Global function** (in `_G` for `v:lua` access from `<Plug>` mappings):
- `_G.context_commentstring.update_commentstring_and_run(mapping)` — recalculates commentstring then returns termcodes for the given `<Plug>` mapping.

**The `check_node` algorithm (critical)**:
1. If no `language_config` exists for the language → return `nil`.
2. If `node` is `nil` (reached root) → return `language_config[key] or language_config.__default or language_config`.
3. Look up `node:type()` in `language_config`. If found → return `match[key] or match.__default or match`.
4. Otherwise recurse with `node:parent()`.

This walks **up** the treesitter tree from the innermost node at the cursor until it finds a matching node type.

### `lua/ts_context_commentstring/utils.lua` - Utility Functions

| Function | Signature | Purpose |
|---|---|---|
| `get_cursor_location()` | `() -> Location` | Returns `{line-1, col}` of current cursor (0-indexed). |
| `get_cursor_line_non_whitespace_col_location()` | `() -> Location` | Returns `{line-1, first_non_whitespace_col}` — default location for node lookup. |
| `get_visual_start_location()` | `() -> Location` | Returns start of visual selection with first non-whitespace column. |
| `get_visual_end_location()` | `() -> Location` | Returns end of visual selection. |
| `is_treesitter_active(bufnr?)` | `number? -> boolean` | Safely checks if treesitter parser is available. |
| `get_node_at_cursor_start_of_line(only_languages, location?)` | `(string[], Location?) -> node?, language_tree?` | Gets treesitter node at location. Handles **injected languages** by iterating all language trees. |

### `lua/ts_context_commentstring/integrations/comment_nvim.lua` - Comment.nvim Integration

| Function | Signature | Purpose |
|---|---|---|
| `create_pre_hook()` | `() -> fun(ctx): string\|nil` | Returns a Comment.nvim `pre_hook` function. Determines `__default` vs `__multiline` key from `ctx.ctype`, determines location, calls `calculate_commentstring`. |

### `lua/ts_context_commentstring/integrations/vim_commentary.lua` - vim-commentary Integration

| Function | Signature | Purpose |
|---|---|---|
| `set_up_maps(maps)` | `CommentaryConfig -> void` | Creates buffer-local mappings for commentary keys that point to `<Plug>` context mappings. |

**Module-level side effects**: On require, creates global `<Plug>` mappings (`<Plug>ContextCommentary`, `<Plug>ContextCommentaryLine`, `<Plug>ContextChangeCommentary`) in normal/visual/operator-pending modes that call `_G.context_commentstring.update_commentstring_and_run()`.

### `plugin/ts_context_commentstring.lua` - Vimscript Bootstrap

1. Guard: returns early if `vim.g.loaded_ts_context_commentstring` is set.
2. Creates `FileType` autocmd in `'ts_context_commentstring'` augroup that calls `internal.setup_buffer(args.buf)`.
3. **Backwards compatibility**: If `vim.g.skip_ts_context_commentstring_module` is not set, attempts to register as an nvim-treesitter module (for nvim-treesitter < 1.0).

## Data Flow

```
CursorHold autocmd (or pre-hook / <Plug> mapping)
  → internal.update_commentstring()
    → internal.calculate_commentstring()
      → utils.get_node_at_cursor_start_of_line(only_languages, location)
        → walks language trees for injected language support
        → returns node + language_tree
      → config.custom_calculation(node, language_tree) [optional]
      → internal.check_node(node, language_config, key)
        → recursive parent walk up the TS tree
    → sets vim.bo.commentstring (or restores original)
```

## Configuration

```lua
require('ts_context_commentstring').setup {
  enable_autocmd = true,           -- auto-update on CursorHold
  custom_calculation = nil,        -- fun(node, language_tree): string
  languages = {                    -- treesitter language -> comment config
    html = '<!-- %s -->',
    lua = { __default = '-- %s', __multiline = '--[[ %s ]]' },
  },
  commentary_integration = {       -- vim-commentary keybindings
    Commentary = 'gc',
    CommentaryLine = 'gcc',
    ChangeCommentary = 'cgc',
    CommentaryUndo = 'gcu',
  },
}
```

**Recommended**: Set `vim.g.skip_ts_context_commentstring_module = true` to skip legacy nvim-treesitter module registration and speed up loading.

## Dependencies

- **Hard dependency**: `vim.treesitter` (Neovim 0.9+ built-in treesitter)
- **Soft dependency**: `nvim-treesitter` (for legacy module registration, skippable via global flag)
- **Optional integrations**: `Comment.nvim`, `vim-commentary` (kommentary, nvim-comment, mini.comment documented in wiki but not in this repo's code)

## Code Style / Conventions

- **Stylua** config (`stylua.toml`): 2-space indent, single quotes, no call parentheses.
- LuaCATS type annotations (`@class`, `@alias`, `@field`) used throughout for type checking.
- Module pattern: each file returns `local M = {}` table.
- `---@param` and `---@return` annotations on all public functions.
- `vim.treesitter` API used for all treesitter operations.

## Key Patterns

- **Config keys are treesitter languages, not filetypes** — a common source of confusion.
- **The `check_node` recursive walk** is the core algorithm — edits to language configs must account for node type names matching treesitter's parser output.
- **Two integration patterns**: Comment.nvim uses a `pre_hook` factory; vim-commentary uses `<Plug>` mappings with a global recalculate-and-run function.
- **The `custom_calculation` hook** takes priority over the built-in lookup.
- **The `enable_autocmd` flag** is automatically disabled when vim-commentary is detected.
- **Injected language support** via `utils.get_node_at_cursor_start_of_line` which uses `language_tree:for_each_tree()` to find the smallest language tree containing the cursor position.
