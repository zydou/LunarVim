# Comment.nvim - CLAUDE.md

## Project Overview

Comment.nvim is a smart and powerful comment plugin for Neovim. It supports line comments (`//`) and block comments (`/* */`), dot-repeat (`.`), counts, and integration with motions/text-objects. It has native treesitter integration to support embedded filetypes (e.g., JavaScript inside HTML, Vue components, code blocks inside Markdown, etc.).

## Directory Structure

```
Comment.nvim/
├── plugin/Comment.lua          # Vim plugin entrypoint; defines <Plug> mappings
├── lua/Comment/
│   ├── init.lua                # Main module; provides setup() and default keymaps
│   ├── api.lua                 # Core Lua API (toggle/comment/uncomment/insert)
│   ├── config.lua              # Configuration management (Config class, defaults, get/set)
│   ├── opfunc.lua              # Operator-mode core logic (linewise/blockwise comment engine)
│   ├── utils.lua               # Utilities (cmode/ctype/cmotion enums, commenter/uncommenter closures)
│   ├── extra.lua               # Extended API (insert comment above/below/eol)
│   └── ft.lua                  # Filetype -> commentstring mapping table (with treesitter detection)
├── doc/
│   ├── Comment.txt             # Vim help doc (auto-generated from EmmyLua annotations)
│   ├── API.md                  # API documentation
│   └── plugs.md                # Keymap documentation
├── .github/workflows/ci.yaml   # CI: auto-generates help docs on push to master
└── stylua.toml                 # Lua formatter config (stylua, 4-space indent)
```

## Core Modules

### `Comment.init` (`lua/Comment/init.lua`)
- **setup(config?)** - Loads config, creates default keymaps. Merges user config with defaults via `vim.tbl_deep_extend('force', ...)`.
- Default keymaps are controlled by `mappings.basic` and `mappings.extra`.
- Exported as `require('Comment')`.

### `Comment.config` (`lua/Comment/config.lua`)
- **Config:set(cfg)** - Merges user config into defaults (`vim.tbl_deep_extend('force', ...)`)
- **Config:get()** - Returns the current config
- Uses a metatable with `__index`/`__newindex` that reads/writes to a `state` table, allowing dynamic properties like `Config.position` (used for sticky cursor restoration)
- Config class fields: `padding`, `sticky`, `ignore`, `mappings`, `toggler`, `opleader`, `extra`, `pre_hook`, `post_hook`

### `Comment.api` (`lua/Comment/api.lua`)
Provides a chainable API via metatables:
- **api.toggle.linewise / blockwise** - Toggle comment (current/count/motion)
- **api.comment.linewise / blockwise** - Force comment
- **api.uncomment.linewise / blockwise** - Force uncomment
- **api.insert.linewise {above, below, eol}** - Insert comment at specified position and enter INSERT mode
- **api.insert.blockwise {above, below, eol}** - Same for blockwise comments
- **api.locked(fn)** - Wraps an API function call with `lockmarks` to preserve marks/jumps
- **api.call(fn, op)** - Sets `operatorfunc` for dot-repeat support; stores cursor position for sticky behavior

### `Comment.opfunc` (`lua/Comment/opfunc.lua`)
Underlying comment engine:
- **Op.opfunc(motion, cfg, cmode, ctype)** - Core `operatorfunc` callback; computes range, parses commentstring, dispatches to linewise/blockwise, restores cursor if sticky
- **Op.count(count, cfg, cmode, ctype)** - Comment with a count (used by `[count]gcc`)
- **Op.linewise(param)** - Linewise comment logic (computes min indentation, applies padding and ignore pattern)
- **Op.blockwise(param, partial)** - Block comment logic (supports full, partial, and current-line blockwise)

### `Comment.utils` (`lua/Comment/utils.lua`)
- **cmode** - Comment mode enum: `{toggle=0, comment=1, uncomment=2}`
- **ctype** - Comment type enum: `{linewise=1, blockwise=2}`
- **cmotion** - Motion type enum: `{line=1, char=2, block=3, v=4, V=5}`
- **U.is_fn(fn, ...)** - Calls `fn` if it is a function, otherwise returns `fn` itself (used for config options that can be static values or functions)
- **U.parse_cstr(cfg, ctx)** - Resolves commentstring by priority: `pre_hook` > `ft.lua` (with treesitter) > `vim.bo.commentstring`
- **U.unwrap_cstr(cstr)** - Splits a `commentstring` (e.g., `'%s'`) into left/right parts around `%s`
- **U.commenter(left, right, padding, scol, ecol, tabbed)** - Returns a closure for commenting (linewise, blockwise, or current-line blockwise)
- **U.uncommenter(left, right, padding, scol, ecol)** - Returns a closure for uncommenting
- **U.is_commented(left, right, padding, scol, ecol)** - Returns a closure that checks whether a line/region is commented
- **U.catch(fn, ...)** - Error handler wrapping `xpcall`; emits warnings via `vim.notify`
- Key types: `CommentCtx` (ctype/cmode/cmotion/range), `CommentRange` (srow/scol/erow/ecol), `OpFnParams`

### `Comment.extra` (`lua/Comment/extra.lua`)
- **insert_below(ctype, cfg)** - Insert comment below current line and enter INSERT mode
- **insert_above(ctype, cfg)** - Insert comment above current line and enter INSERT mode
- **insert_eol(ctype, cfg)** - Insert comment at end of line and enter INSERT mode
- Known issue: `move_n_insert` prints `a` when used with `i_CTRL-o` (see FIXME in source)

### `Comment.ft` (`lua/Comment/ft.lua`)
- Built-in commentstring mappings for many languages (linewise and blockwise)
- **ft.set(lang, val)** - Set commentstring for a filetype; supports chaining (`ft.set('a', ...).set('b', ...)`) and metatable magic (`ft.javascript = {...}`)
- **ft.get(lang, ctype?)** - Get commentstring for a filetype; returns deep copy of `{line, block}` if `ctype` is nil
- **ft.contains(tree, range)** - Walks a treesitter parse tree to find the language for a range (ignores `tree-sitter-comment` parser)
- **ft.calculate(ctx)** - Computes commentstring via treesitter for embedded languages; falls back to buffer filetype
- Supports compound (dot-separated) filetypes via metatable `__index` (e.g., `ansible.yaml` tries `ansible` first, then falls back to `yaml`)

## Configuration

```lua
require('Comment').setup({
    padding = true,          -- Space between comment and code (boolean or fun():boolean)
    sticky = true,           -- Keep cursor in place after commenting (NORMAL mode only)
    ignore = nil,            -- Lua pattern; lines matching are ignored during (un)comment
    toggler = { line = 'gcc', block = 'gbc' },    -- NORMAL mode toggle mappings
    opleader = { line = 'gc', block = 'gb' },     -- Operator-pending mappings
    extra = { above = 'gcO', below = 'gco', eol = 'gcA' }, -- Extra insert mappings
    mappings = { basic = true, extra = true },     -- Enable/disable default mappings (set false to disable all)
    pre_hook = nil,          -- Callback before (un)comment; receives CommentCtx, can return custom commentstring
    post_hook = nil,         -- Callback after (un)comment; receives CommentCtx
})
```

## Dependencies

- **Hard dependencies**: None. Pure Lua plugin.
- **Optional dependencies**:
  - `nvim-treesitter` - Enables embedded language detection and treesitter-powered commentstring resolution
  - `nvim-ts-context-commentstring` - Integrates via `pre_hook` for tsx/jsx context-aware commenting
- **Plugin managers**: Works with `lazy.nvim`, `packer`, `vim-plug`, etc.

## Build / Test

- No build step (pure Lua plugin).
- CI (`ci.yaml`) runs on push to `master` (when `*.lua` files change) and auto-generates `doc/Comment.txt` help file from EmmyLua annotations using [`lemmy-help`](https://github.com/numToStr/lemmy-help).
- Code formatting: [stylua](https://github.com/JohnnyMorganz/StyLua) with 4-space indent, Unix line endings, single quotes preferred.

## Coding Conventions

- EmmyLua-style annotations (`---@class`, `---@field`, `---@param`, `---@return`, `---@see`, `---@usage`, etc.)
- 4-space indentation, Unix line endings
- Single quotes preferred (stylua `AutoPreferSingle`)
- Modules use `local M = {}` or table literals, returned at the end
- Function naming: module-level public functions use PascalCase (`Op.linewise`, `ft.calculate`); internal helpers use camelCase or `U.` prefix (`U.is_empty`, `U.catch`)
- Error handling: wrap with `U.catch` (xpcall) and notify via `vim.notify(..., vim.log.levels.WARN)`
- Config options that accept either a static value or a function are resolved via `U.is_fn`
