# hlchunk.nvim

## Project Overview

hlchunk.nvim is a Neovim plugin that highlights the current code chunk, indent lines, line numbers, and blank areas using extmarks. It serves as an alternative to indent-blankline.nvim. Requires Neovim >= 0.10.0.

## Directory Structure

```
hlchunk.nvim/
├── lua/hlchunk/
│   ├── init.lua              -- entry module, exports setup function
│   ├── mods/                 -- four independent highlight mods
│   │   ├── base_mod/         -- base class, parent of all mods
│   │   │   ├── init.lua      -- BaseMod: enable/disable/render/clear lifecycle
│   │   │   ├── base_conf.lua -- base configuration definition
│   │   │   └── type.lua      -- type annotations (MetaInfo)
│   │   ├── chunk/            -- chunk highlight (AST range under cursor)
│   │   │   ├── init.lua
│   │   │   └── chunk_conf.lua
│   │   ├── indent/           -- indent line highlight
│   │   │   ├── init.lua
│   │   │   └── indent_conf.lua
│   │   ├── line_num/         -- line number highlight
│   │   │   ├── init.lua
│   │   │   └── line_num_conf.lua
│   │   └── blank/            -- blank-line indent marker highlight
│   │       ├── init.lua
│   │       └── blank_conf.lua
│   └── utils/                -- utility modules
│       ├── class.lua         -- lightweight OOP class system (base/derived)
│       ├── position.lua      -- Pos class (bufnr, row, col) with char lookup
│       ├── indentHelper.lua  -- indent level calculation
│       ├── chunkHelper.lua   -- chunk range calculation (treesitter/context)
│       ├── scope.lua         -- Scope factory (bufnr, start, finish)
│       ├── cache.lua         -- multi-key cache
│       ├── cFunc.lua         -- FFI fast path (calls Neovim C functions)
│       ├── loopTask.lua      -- asynchronous looped task (animation)
│       ├── timer.lua         -- setTimeout/setInterval/debounce/debounce_throttle/throttle
│       ├── filetype.lua      -- exclude_filetypes list
│       └── ts_node_type/     -- treesitter node type matchers (cpp/css/fortran/lua/rust/yaml/zig)
├── docs/en/                  -- English docs (chunk/indent/line_num/blank)
├── docs/zh_CN/               -- Chinese docs
├── test/                     -- plenary.nvim tests
├── Makefile                  -- lint/test targets
└── stylua.toml               -- formatting config (spaces, indent_width = 4)
```

## Core Modules

### `hlchunk.init` — Entry Point
- `hlchunk.setup(userConf)` — iterates over the config table; for each entry with `enable = true`, requires `hlchunk.mods.<name>`, constructs it with the conf, and calls `:enable()`.

### `hlchunk.mods.base_mod` — BaseMod
All mods inherit from this base class. Provides a unified lifecycle:
- `:enable()` — set highlights, render initial window content, create autocommands and user commands
- `:disable()` — clear extmarks across all buffers, delete augroup
- `:render(range)` / `:clear(range)` — render/clear within a 0-indexed `Scope`
- `:shouldRender(bufnr)` — guard: checks buffer validity, `enable` flag, `exclude_filetypes`, `shiftwidth ~= 0`, and forbids buftypes `help`/`nofile`/`terminal`/`prompt`
- `:setHl()` — resolves `style` into highlight groups named `<hl_base_name><n>` (e.g. `HLChunk1`, `HLIndent1`). Accepts: `string`, `string[]`, `vim.api.keyset.highlight[]`, `vim.api.keyset.get_hl_info[]`, or `function` returning any of those
- `:createUsercmd()` — registers `EnableHL<Name>` / `DisableHL<Name>` user commands; created only when the mod is enabled
- `:notify(msg, level, opts)` — respects `conf.notify`; supports `opts.once`

### `hlchunk.mods.chunk` — ChunkMod
Highlights the AST node enclosing the cursor by drawing a **rounded box** (corner chars + arrows) with extmarks. Uses `chunkHelper.get_chunk_range` (treesitter when `use_treesitter = true`, otherwise context-based `searchpair`).

Extra features:
- Configurable `chars` (box-drawing glyphs: `left_top`, `left_bottom`, `horizontal_line`, `vertical_line`, `left_arrow`, `right_arrow`)
- `textobject` — keymap (in `x`/`o` modes) to select the current chunk
- `error_sign` — when true and the chunk has a treesitter error, renders in the error color (second style entry)
- `duration` / `delay` — animation control; delay 0 + duration > 0 uses `LoopTask` to animate the box appearing
- `max_file_size` — auto-disables the mod for files larger than this many bytes
- `use_treesitter` — optional treesitter integration

### `hlchunk.mods.indent` — IndentMod
Renders indent guides as overlay extmarks. Uses `indentHelper.get_rows_indent` and three `Cache` instances (`indent_cache`, `pos2info`, `pos2id`) for efficient re-rendering.

Config:
- `chars` — list of characters cycled per indent level (default `{ "│" }`)
- `filter_list` — list of predicate functions applied to each render info entry; return false to skip
- `ahead_lines` — extra lines rendered above/below the window to reduce flicker on scroll
- `delay` — debounce delay in ms for scroll/move callbacks (default 100)
- `use_treesitter` — use nvim-treesitter.indent when available
- Listens to: `WinScrolledX`, `WinScrolledY`, `TextChanged(I)`, `BufWinEnter`, `OptionSet list/shiftwidth/tabstop/expandtab`

### `hlchunk.mods.line_num` — LineNumMod
Highlights every line number in the current chunk via extmark's `number_hl_group` field (not virt_text). Reacts to `CursorMoved(I)`.

### `hlchunk.mods.blank` — BlankMod
**Inherits from `IndentMod`** (not from `BaseMod`). Renders character-based indent markers on blank lines by reusing indent computation logic. Adds `renderLeader` for the partial leading segment.

### Utility Modules
- `class.lua` — lightweight OOP: `class(ctor)` for a base class; `class(base, ctor)` for a derived class
- `cFunc.lua` — FFI fast path calling Neovim C functions directly (`get_indent_buf`, `get_sw_value`, `ml_get_buf`, `ml_get_buf_len`, `skipwhite`). No Lua fallback; LuaJIT FFI is a hard requirement.
- `cache.lua` — multi-key cache constructed as `Cache("key1", "key2", ...)` with `get`/`set`/`has`/`clear`/`remove`
- `timer.lua` — `setTimeout`, `setInterval`, `debounce` (with optional immediate-fire flag), `debounce_throttle` (fires immediately then debounces), `throttle`
- `loopTask.lua` — `LoopTask(fn, "linear", duration, ...)` schedules a function across a list of argument packs with timed intervals, used for chunk box animation
- `position.lua` — `Pos` class; `Pos.get_char_at_pos(pos, expand_tab_width)` reads a character at a position
- `scope.lua` — **factory function** (not a class) returning `{ bufnr, start, finish }`; start/finish are 0-indexed inclusive
- `filetype.lua` — `exclude_filetypes` table of filetypes where all mods are disabled by default (e.g. dashboard, neo-tree, TelescopePrompt, etc.)

## Configuration

```lua
require('hlchunk').setup({
    chunk = {
        enable = true,
        style = { "#806d9c" },           -- string, string[], highlight table, or function
        notify = false,
        priority = 15,
        use_treesitter = true,
        chars = {
            left_arrow = "─", horizontal_line = "─", vertical_line = "│",
            left_top = "╭", left_bottom = "╰", right_arrow = ">",
        },
        textobject = "",                  -- e.g. "ih" to select the chunk
        max_file_size = 1024 * 1024,
        error_sign = true,
        duration = 200,
        delay = 300,
        exclude_filetypes = { dashboard = true },
    },
    indent = {
        enable = true,
        style = { "#33333366" },
        priority = 10,
        chars = { "│" },
        use_treesitter = false,
        ahead_lines = 5,
        delay = 100,
        filter_list = {},
    },
    line_num = { enable = true, style = "#806d9c", priority = 10 },
    blank = { enable = true, style = { "#33333366" }, chars = { "․" }, priority = 9 },
})
```

Each mod can also be required and enabled on its own:
```lua
local indent = require('hlchunk.mods.indent')
indent({ style = { "#555555" }, chars = { "│" } }):enable()
```

Common config fields shared by every mod: `enable`, `style`, `notify`, `priority`, `exclude_filetypes`.

Default priority order: chunk (15) > indent (10) = line_num (10) > blank (9).

## User Commands

When a mod is enabled at setup time, two user commands are created:
- `EnableHL<Name>` — e.g. `EnableHLchunk`, `EnableHLindent`, `EnableHLline_num`, `EnableHLblank`
- `DisableHL<Name>` — same naming pattern

Note: `<Name>` is derived from the mod's `meta.name` converted to CamelCase (e.g. `line_num` -> `LineNum`). Mods disabled at setup time never get commands because they have no instance to operate on.

## Dependencies

- **Hard requirement**: Neovim >= 0.10.0 with LuaJIT FFI (for `cFunc.lua`)
- **Optional**: nvim-treesitter (only if `use_treesitter = true` in chunk/indent mod config)

## Build / Test

- **Test framework**: plenary.nvim (provides `PlenaryBustedDirectory`)
- **Run tests**: `make test`
- **Lint**: `make luacheck` (luacheck, ignores warning 631), `make stylua` (check formatting)
- **Types**: `make lua-language-server` (requires version-specific `.luarc` config)
- **Formatting**: `stylua` with 4-space indentation (see `stylua.toml`)

## Coding Conventions

- Pure Lua (LuaJIT), targeting Neovim 0.10+ API
- Custom OOP via `utils/class.lua` — not metatable prototype chains; the pattern is `class(ctor)` and `class(base, ctor)` with a `__call` metamethod
- Type annotations: extensive `---@class` / `---@field` / `---@param` / `---@alias` / `---@enum` for LuaLS
- Highlight groups are created dynamically with `nvim_set_hl`; names follow `<hl_base_name><index>` (e.g. `HLChunk1`, `HLIndent1`)
- Rendering performance optimizations:
  - Per-line extmark caching via the `Cache` class
  - Asynchronous `LoopTask` for chunk animation so the box renders progressively
  - `debounce_throttle` / `debounce` for scroll and cursor-move callbacks to batch rendering
  - FFI in `cFunc.lua` to avoid Lua-side overhead for indent/line queries
- Tree-sitter node matching uses `ts_node_type/` per-language tables, plus a `default` fallback of common patterns (class/func/if/else/while/for/try/etc.)
