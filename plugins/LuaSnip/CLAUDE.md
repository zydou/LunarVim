# LuaSnip - CLAUDE.md

## Project Overview

LuaSnip is a fast and powerful snippet engine for Neovim. It supports:
- Tabstops (insert nodes) with forward/backward navigation
- Text transformations via Lua functions
- Conditional expansion
- Nested snippets
- Filetype-specific snippets
- Choice nodes (alternatives at a tabstop)
- Dynamic snippet generation (dynamic nodes)
- Regex triggers
- Autotriggered snippets
- Postfix snippets (expand text already typed)
- Parsing snippets in LSP, VS Code, and SnipMate formats
- Snippet history (jump back into older snippets)
- Treesitter-based filetype detection at cursor

## Directory Structure

```
LuaSnip/
├── plugin/
│   ├── luasnip.lua                    # Vim plugin entry: <Plug> mappings, keymap wiring
│   └── luasnip.vim                    # Vim-compatible API (luasnip#...)
├── lua/luasnip/
│   ├── init.lua                       # Main module: expand/jump/choice public API
│   ├── config.lua                     # Configuration (set_config/setup) and defaults
│   ├── snippets.lua                   # Snippet registration (snipmate-compatible API)
│   ├── _types.lua                     # Internal type definitions
│   ├── nodes/                         # All node implementations
│   │   ├── node.lua                   # Base Node class
│   │   ├── snippet.lua                # Snippet / SN / ISN / P (snippet_node, parent_indexer)
│   │   ├── textNode.lua               # T (text node)
│   │   ├── functionNode.lua           # F (function node)
│   │   ├── insertNode.lua             # I (insert node / tabstop)
│   │   ├── choiceNode.lua             # C (choice node)
│   │   ├── dynamicNode.lua            # D (dynamic node)
│   │   ├── restoreNode.lua            # R (restore node)
│   │   ├── multiSnippet.lua           # MultiSnippet (multiple snippets from one trigger)
│   │   ├── snippetProxy.lua           # Proxy snippet (deferred resolution)
│   │   ├── absolute_indexer.lua       # Absolute position indexer
│   │   ├── key_indexer.lua            # Key-based indexer
│   │   ├── duplicate.lua             # Node duplication utility
│   │   ├── util.lua                   # Node utilities (jump_into/init positions)
│   │   └── util/trig_engines.lua      # Trigger engines (plain/pattern)
│   ├── extras/                        # Extended functionality
│   │   ├── init.lua                   # fmt/lambda/rep/match/partial/nonempty/dl
│   │   ├── fmt.lua                    # fmt() and fmta() format helpers
│   │   ├── _lambda.lua                # Lambda expression parser
│   │   ├── postfix.lua                # Postfix snippet builder
│   │   ├── otf.lua                    # On-the-fly snippets
│   │   ├── select_choice.lua          # Choice selection UI
│   │   ├── snippet_list.lua           # Snippet list browser
│   │   ├── snip_location.lua          # Snippet source file locator
│   │   ├── filetype_functions.lua     # Filetype resolution functions
│   │   ├── treesitter_postfix.lua     # Treesitter-powered postfix
│   │   ├── expand_conditions.lua      # Built-in expand/show conditions
│   │   └── conditions/                # Condition helpers (expand.lua, show.lua)
│   ├── loaders/                       # Snippet loaders
│   │   ├── init.lua                   # edit_snippet_files / cleanup / reload
│   │   ├── from_vscode.lua            # VS Code format loader (json/jsonc)
│   │   ├── from_snipmate.lua          # SnipMate format loader
│   │   ├── from_lua.lua               # Lua format loader (supports hot reload)
│   │   ├── util.lua                   # Loader utilities
│   │   └── _caches.lua                # Loader caches
│   ├── session/                       # Session management
│   │   ├── init.lua                   # Session state (ft_redirect, current_nodes, etc.)
│   │   └── snippet_collection/        # Snippet storage, matching, invalidation
│   │       ├── init.lua               # Collection management (by_key, by_prio)
│   │       └── source.lua             # Snippet source tracking
│   └── util/                          # Utility modules
│       ├── util.lua                   # General utilities (cursor ops, JSON, no_region_check)
│       ├── types.lua                  # Node type constants
│       ├── ext_opts.lua               # Extended options (highlight groups)
│       ├── events.lua                 # Event system (pre/post expand, etc.)
│       ├── environ.lua                # Environment variables (TM_*, CAPTURE, etc.)
│       ├── mark.lua                   # Extmark management
│       ├── str.lua / path.lua         # String/path utilities
│       ├── dict.lua / table.lua       # Data structures
│       ├── select.lua                 # Selection keymaps
│       ├── log.lua                    # Logging
│       ├── extend_decorator.lua       # Extend decorator
│       ├── directed_graph.lua         # Directed graph (dependency tracking)
│       ├── jsonc.lua                  # JSONC parsing
│       ├── pattern_tokenizer.lua      # Pattern tokenizer
│       ├── _builtin_vars.lua          # Built-in variables (selector, clipboard, etc.)
│       ├── functions.lua              # Misc helper functions
│       └── parser/                    # LSP snippet syntax parser
│           ├── init.lua               # Parser entry point
│           ├── neovim_parser.lua      # Built-in Neovim parser
│           ├── neovim_ast.lua         # AST via Neovim TS
│           ├── ast_parser.lua         # AST parser
│           └── ast_utils.lua          # AST utilities
├── tests/                             # Tests (Neovim built-in + plenary.busted)
│   ├── unit/                          # Unit tests
│   ├── integration/                   # Integration tests
│   ├── parsers/                       # Parser plugin shared objects
│   ├── data/                          # Test data files
│   └── helpers.lua                    # Test helpers
├── deps/
│   ├── jsregexp/                      # JS regex submodule (optional, for LSP transforms)
│   └── lua51_include/                 # Lua 51 headers for jsregexp compilation
├── ftplugin/                          # Filetype plugins
├── syntax/                            # Syntax definitions
├── Examples/snippets.lua              # Example snippet definitions
├── DOC.md                             # Full documentation
└── README.md
```

## Core Modules

### `luasnip` (`lua/luasnip/init.lua`)
Main entry point, returns the `ls` table via `lazy_table` (lazy loading of constructors):

**Snippet operations:**
- `expand(opts?)` - Expand the snippet matching the current cursor position
- `expand_or_jump()` - Expand if possible, otherwise jump to next tabstop
- `snip_expand(snippet, opts)` - Directly expand a snippet object
- `expand_auto()` - Expand matching autosnippet (triggered by `TextChangedI`)
- `expand_repeat()` - Repeat last expansion (via vim-repeat)
- `lsp_expand(body, opts)` - Expand an LSP snippet string directly

**Navigation:**
- `jump(dir)` - Jump between tabstops (1 = forward, -1 = backward)
- `jumpable(dir)` / `jump_destination(dir)` - Check/return jump destination
- `expandable()` / `expand_or_jumpable()` / `locally_jumpable(dir)` - State checks
- `in_snippet()` - Check if cursor is inside any snippet
- `expand_or_locally_jumpable()` - Expand, or jump only if already in a snippet

**Choice nodes:**
- `choice_active()` - Whether a choice node is currently active
- `change_choice(val)` - Cycle choice (1 = next, -1 = prev)
- `set_choice(indx)` - Set choice by index
- `get_current_choices()` - Get docstrings of current choices

**Snippet management:**
- `add_snippets(ft, snippets, opts)` - Register snippets programmatically
- `get_snippets(ft, opts)` - Retrieve snippets for a filetype
- `available()` - List all available snippets by filetype
- `cleanup()` - Remove all snippets (fires `LuasnipCleanup` autocmd; used for reload)
- `clean_invalidated(opts)` - Remove invalidated snippets
- `refresh_notify(ft)` - Fire `LuasnipSnippetsAdded` autocmd
- `unlink_current()` - Exit the current snippet
- `unlink_current_if_deleted()` - Exit if snippet text was deleted
- `exit_out_of_region(node)` - Leave snippet when cursor exits its region
- `activate_node(opts)` - Re-activate a node at a given position

**Filetype:**
- `filetype_extend(ft, extend_ft)` - Add filetypes whose snippets also apply to `ft`
- `filetype_set(ft, fts)` - Replace the filetype list for `ft`
- `get_snippet_filetypes()` - Get all registered filetypes

**Config and internals:**
- `setup(config)` - Configure LuaSnip (delegates to `config.lua`)
- `session` - Session state table (`current_nodes`, `ft_redirect`, `snippet_roots`, etc.)
- `env_namespace` - Namespace for environment variables
- `extend_decorator` - Decorator factory for extending snippets
- `log` - Logging module

**Lazy-loaded constructors** (loaded on first access):
- `s` / `snippet` - `Snippet.S` (create snippet from nodes)
- `sn` / `snippet_node` - `Snippet.SN` (create snippet node)
- `isn` / `indent_snippet_node` - `Snippet.ISN` (indented snippet node)
- `t` / `text_node` - `TextNode.T`
- `f` / `function_node` - `FunctionNode.F`
- `i` / `insert_node` - `InsertNode.I`
- `c` / `choice_node` - `ChoiceNode.C`
- `d` / `dynamic_node` - `DynamicNode.D`
- `r` / `restore_node` - `RestoreNode.R`
- `parent_indexer` / `P` - `Snippet.P` (reference a parent's insert node)
- `multi_snippet` / `ms` - `MultiSnippet.new_multisnippet`
- `parser` - LSP snippet parser module
- `config` - Config module
- `snippet_source` - Source tracking module
- `select_keys` - Selection key mapping helper

### `luasnip.config` (`lua/luasnip/config.lua`)
- `set_config(user_config)` / `setup(user_config)` - Apply configuration
- `_setup()` - Create `luasnip` augroup and register autocommands

**Configuration keys:**
- `keep_roots` / `link_roots` / `link_children` - Snippet history behavior
- `update_events` - Events triggering dependent updates (default: `"InsertLeave"`)
- `region_check_events` - Events triggering region-exit checks (default: nil)
- `delete_check_events` - Events triggering deletion checks (default: nil)
- `store_selection_keys` - Key to store visual selection (for `$TM_SELECTED_TEXT`)
- `ext_opts` - Highlight group definitions per node type
- `ext_base_prio` / `ext_prio_increase` - Priority base/increase for extmarks
- `enable_autosnippets` - Enable autosnippet expansion on insert
- `ft_func` - `fn()` -> filetype list (default: `from_filetype`)
- `load_ft_func` - `fn(bufnr)` -> filetype list for loaders (default: `from_filetype_load`)
- `snip_env` - Globals injected into Lua snippet files (via lazy_table)
- `parser_nested_assembler` - Assembler for nested LSP snippets
- `loaders_store_source` - Whether loaders store snippet source locations

**Legacy:** `history = true` maps to `keep_roots`/`link_roots`/`link_children`.

### Node system (`lua/luasnip/nodes/`)
All nodes inherit from `Node` (`node.lua`):
- **Snippet (S)** - Top-level snippet container; holds nodes, tabstops, env, marks
- **SnippetNode (SN)** - Node that wraps a sub-snippet (nested expansion target)
- **IndentSnippetNode (ISN)** - Like SN but preserves indentation of inserted code
- **Text (T)** - Static text
- **Insert (I)** - Editable tabstop; `pos` determines jump order (1, 2, ...; 0 = end)
- **Function (F)** - Dynamic content via Lua function
- **Choice (C)** - Multiple alternatives at one position
- **Dynamic (D)** - Generates a sub-tree dynamically
- **Restore (R)** - Restores previously entered content (linked to choice/dynamic nodes)
- **MultiSnippet (MS)** - Multiple snippets from one context/trigger

### Loaders (`lua/luasnip/loaders/`)
- **from_vscode** - Load VS Code snippets (`.json`, `.jsonc`, `code-snippets`)
- **from_snipmate** - Load SnipMate-style collections
- **from_lua** - Load Lua-format collections (supports `add_opts`, `reload_file`)
- Support two modes: `load()` (immediate) and `lazy_load()` (deferred)
- **edit_snippet_files(opts)** - Interactive picker to jump to snippet source files
- **cleanup()** - Clear loader caches
- **reload_file(filename)** - Hot-reload a Lua snippet file

### Extras (`lua/luasnip/extras/`)
- **fmt(fmtstr, nodes)** - Python-style format string for snippets
- **fmta(fmtstr, nodes)** - Auto-indenting variant of fmt
- **lambda** - Lambda expressions: `l("text $ARG1 more")` -> function node
- **rep(indx)** - Repeat content of tabstop `indx`
- **match(indx, pattern, then, else)** - Conditional content based on pattern
- **partial(fn, ...)** - Partial application of a function
- **nonempty(indx, if_str, else_str)** - Render different content based on whether a tabstop is non-empty
- **dl(indx, repr)** - Dynamic lambda (lambda that uses dynamic node's text)
- **postfix(postfix, opts)** - Postfix snippet builder (e.g. `.if` -> `if <expr> then end`)
- **otf(context)** - On-the-fly snippet from a string
- **treesitter_postfix** - Postfix with Treesitter context
- **expand_conditions** - Built-in conditions (e.g. `at_line_beginning`, `has_selected_text`)
- **select_choice** - UI for selecting a choice node
- **snippet_list** - Browse all snippets
- **snip_location** - Locate snippet source file

### Parser (`lua/luasnip/util/parser/`)
LSP snippet syntax parser with multiple backends:
- `neovim_parser.lua` - Built-in Neovim parser (default)
- `neovim_ast.lua` - AST via Neovim Treesitter
- `ast_parser.lua` / `ast_utils.lua` - AST-based parser utilities
- `init.lua` - Entry point that selects the appropriate parser

### Session (`lua/luasnip/session/`)
- `session.init` - Global session state: `current_nodes`, `ft_redirect`, `snippet_roots`, `ns_id`, `active_choice_nodes`, `jump_active`, `config`
- `snippet_collection` - Stores snippets by key and priority; handles matching and invalidation
- `snippet_collection.source` - Tracks source file/line for each snippet

## Configuration

```lua
local ls = require("luasnip")
ls.setup({
    keep_roots = false,
    link_roots = false,
    link_children = false,
    update_events = "InsertLeave",
    region_check_events = nil,
    delete_check_events = nil,
    store_selection_keys = nil,
    ext_opts = { ... },          -- highlight groups per node type
    ext_base_prio = 200,
    ext_prio_increase = 9,
    enable_autosnippets = false,
    ft_func = function() return { vim.bo.filetype } end,
    load_ft_func = function(bufnr) return { vim.bo[bufnr].filetype } end,
    snip_env = { ... },          -- globals injected into Lua snippet files
    parser_nested_assembler = function(pos, snip) ... end,
    loaders_store_source = false,
})
```

## Dependencies

- **Required:** Neovim >= 0.7 (extmarks)
- **Optional:** `jsregexp` (for LSP snippet regex transformations; install via `make install_jsregexp`)
- **Integrations:** `nvim-cmp` + `cmp_luasnip`, `nvim-treesitter` (filetype detection, postfix)
- **Downstream:** Used as snippet engine by various completion plugins

## Build / Test

- **Build (optional):** `make install_jsregexp` - Compile and install the JS regex library
- **Tests:** Neovim's built-in test framework (busted via plenary.nvim)
  - Unit tests: `tests/unit/`
  - Integration tests: `tests/integration/`
  - Run: `make test` (requires Neovim worktrees in `deps/nvim_multiversion/`)
  - Specific Neovim versions: `TEST_07=true TEST_09=true TEST_MASTER=true make test`
- **Formatting:** stylua (config in `.stylua.toml`: tabs, 80 columns, double quotes)

## Coding Conventions

- EmmyLua-style annotations for type documentation
- Modules use `local M = {}` pattern, return `M` at end
- Node classes use OOP style: `Class:new()` + metatable inheritance
- Lazy loading via `util.lazy_table` and `lazy_snip_env` to reduce startup cost
- Logging: `require("luasnip.util.log").new("module_name")`
- Error handling: `safe_*` wrappers automatically unlink the current snippet on error
- Naming: node files lowercase (`insertNode.lua`), exported constructors uppercase (`I`)
- Indentation: tabs, 4-tab indent width, 80 column limit
- Quote style: auto-prefer double quotes
