# nvim-surround

## Project Overview

nvim-surround is a Neovim plugin for adding, deleting, and changing delimiter pairs surrounding text (e.g. brackets, quotes, HTML tags, function calls). It is a Lua rewrite of tpope's vim-surround, augmented with Tree-sitter support, first-class handling of function calls and HTML tags, dot-repeat, buffer-local configuration, and more.

## Directory Structure

```
nvim-surround/
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
├── doc/                        # Vim help docs (e.g. nvim-surround.txt)
├── queries/
│   └── lua/
│       └── nvim-surround.scm   # Tree-sitter query (function_call captures)
├── tests/
│   ├── minimal_init.lua        # Test bootstrap (plenary.nvim)
│   ├── basics_spec.lua         # Core add/delete/change tests
│   ├── configuration_spec.lua  # Configuration merging tests
│   ├── aliases_spec.lua        # Alias resolution tests
│   ├── dot_repeat_spec.lua     # Dot-repeat behavior tests
│   ├── html_tags_spec.lua      # HTML tag surround tests
│   ├── function_calls_spec.lua # Function call surround tests
│   └── jumps_spec.lua          # Nearest-pair jumping tests
├── lua/
│   └── nvim-surround/
│       ├── init.lua            # Main module; public API + callbacks
│       ├── config.lua          # Default options, translation, keymap setup
│       ├── buffer.lua          # Buffer/cursor/mark/extmark helpers
│       ├── input.lua           # User input (char + string prompts)
│       ├── cache.lua           # Dot-repeat cache for normal/delete/change
│       ├── utils.lua           # Nearest-selection heuristic + NOOP
│       ├── motions.lua         # Vim motion-based selection (text-objects)
│       ├── patterns.lua        # Lua pattern-based selection
│       ├── queries.lua         # Tree-sitter query capture selection
│       ├── treesitter.lua      # Tree-sitter node-type selection
│       ├── annotations.lua     # LuaLS type annotations (shared types)
│       └── functional.lua      # Functional helpers (to_list)
├── .luacheckrc                 # Lua static analysis config
├── stylua.toml                 # Code formatting config
├── selene.toml                 # Selene linter config
├── vim.yml                     # Vim version matrix (CI)
└── .github/                    # CI workflows and issue/PR templates
```

## Core Modules

### `nvim-surround` (`lua/nvim-surround/init.lua`)

Main entry point. Exposes the public API and operator callbacks.

Public functions:
- **`setup(user_opts)`** — Global configuration; merges with defaults, sets keymaps, wires dot-repeat listener.
- **`buffer_setup(buffer_opts)`** — Buffer-local configuration; merges on top of global options.
- **`insert_surround(args)`** — Insert delimiter pair around the cursor in insert mode.
- **`normal_surround(args)`** — Add delimiters around a Vim motion (normal mode). Returns `"g@"` to trigger `operatorfunc` on first call.
- **`visual_surround(args)`** — Add delimiters around a visual selection (supports visual-line and visual-block).
- **`delete_surround(args)`** — Delete nearest surrounding pair. Returns `"g@l"` to trigger `operatorfunc`.
- **`change_surround(args)`** — Change nearest surrounding pair. Returns `"g@l"` to trigger `operatorfunc`.

Operator callbacks (set as `vim.go.operatorfunc`):
- **`normal_callback(mode)`** — Reads the `[`/`]` marks after a motion, highlights the range, queries the user for a delimiter char, then calls `normal_surround`.
- **`delete_callback()`** — Queries the user for a char, then calls `delete_surround`.
- **`change_callback()`** — Queries the user for a target char and a replacement, then calls `change_surround`.

Module-level state:
- `M.normal_curpos` — Cached cursor position used by `operatorfunc` (which clobbers the real cursor).
- `M.pending_surround` — Set while a surround is in progress; used to gate the dot-repeat listener.

### `nvim-surround.config` (`lua/nvim-surround/config.lua`)

Defines `M.default_opts`, translates user options into internal form, and sets up keymaps.

Default options (`M.default_opts`):
| Key              | Type                        | Default                                                  | Notes                                       |
| ---------------- | --------------------------- | -------------------------------------------------------- | ------------------------------------------- |
| `keymaps`        | `table<string, string>`     | see below                                                | Disable a mapping by setting it to `false`. |
| `surrounds`      | `table<string, surround>`   | see below                                                | Per-character definitions.                  |
| `aliases`        | `table<string, string\|string[]>` | see below                                          | Single char maps to one or many surround keys. |
| `highlight`      | `{ duration: integer }`     | `{ duration = 0 }`                                       | `0` means highlight until next action.      |
| `move_cursor`    | `false\|"begin"\|"sticky"`  | `"begin"`                                                | Cursor placement after an operation.        |
| `indent_lines`   | `function`                  | Built-in (re-indents only if a formatter is configured)  | Signature: `(start: integer, stop: integer) -> nil` |

Default keymaps:
```lua
{
    insert      = "<C-g>s",
    insert_line = "<C-g>S",
    normal      = "ys",
    normal_cur  = "yss",
    normal_line = "yS",
    normal_cur_line = "ySS",
    visual      = "S",
    visual_line = "gS",
    delete      = "ds",
    change      = "cs",
    change_line = "cS",
}
```

Default surrounds:
- `(`, `)`, `{`, `}`, `<`, `>`, `[`, `]` — bracket pairs (opening adds inner spaces).
- `'`, `"`, `` ` `` — quote pairs.
- `i` — Prompts the user for left/right delimiter strings.
- `t`, `T` — HTML tags (prompts for tag/attributes; `T` uses a more permissive change target).
- `f` — Function call (prompts for function name; uses Tree-sitter `@call.outer` when available, otherwise a Lua pattern).
- `invalid_key_behavior` — Fallback used when the user presses an unrecognized key; by default, any printable character is treated as a same-on-both-sides delimiter.

Each surround is a table with the shape `{ add, find, delete, change? }`:
- `add` — `add_func`: returns a `delimiter_pair` (list of left lines and right lines).
- `find` — `find_func`: returns a `selection` (the text *inside* the delimiters).
- `delete` — `delete_func`: returns a `selections` (left + right delimiter ranges).
- `change` — Optional `{ target, replacement }`: `target` is a `delete_func` for the part to replace (e.g. function name), `replacement` is an `add_func` for the new value.

Default aliases:
```lua
{
    ["a"] = ">",
    ["b"] = ")",
    ["B"] = "}",
    ["r"] = "]",
    ["q"] = { '"', "'", "`" },
    ["s"] = { "}", "]", ")", ">", '"', "'", "`" },
}
```

Helper functions:
- `get_selection(args)` — Dispatch to motions/patterns/queries/treesitter based on the provided key.
- `get_selections(args)` — Get a `selections` pair from a `char` + `pattern` (or `exclude` function).
- `get_delimiters(char, line_mode)` — Resolve alias, call `add`, wrap in lines if `line_mode`.
- `get_add` / `get_find` / `get_delete` / `get_change` — Look up the corresponding function for a char, falling back to `invalid_key_behavior`.
- `translate_opts(user_opts)` — Convert user-provided config into internal form (wraps string patterns/functions, translates aliases, handles `invalid_key_behavior`).
- `merge_opts(base_opts, new_opts)` — Deep-extends translated user opts over base opts.
- `set_keymaps(args)` — Creates `<Plug>(nvim-surround-*)` maps and user-facing keymaps.

### `nvim-surround.buffer` (`lua/nvim-surround/buffer.lua`)

Low-level buffer and cursor operations. All positions are 1-indexed.

Cursor:
- `get_curpos()` / `set_curpos(pos)` — Read/write cursor position.
- `restore_curpos(pos)` — Move cursor based on `move_cursor` setting (`"begin"` → first_pos, `"sticky"` → extmark-tracked pos, `false` → old_pos).

Marks:
- `get_mark(mark)` / `set_mark(mark, pos)` / `del_mark(mark)` — Buffer mark helpers.
- `adjust_mark(mark)` — Nudge `[`/`]` off whitespace characters.
- `set_operator_marks(motion)` — Run `g@motion` to populate `[`/`]` marks for a text-object.

Extmarks:
- `set_extmark(pos)` / `get_extmark(id)` / `del_extmark(id)` — Extmark lifecycle.
- `with_extmark(pos, fn)` — Run `fn` while tracking `pos` through an extmark; returns the updated position.

Byte indexing (UTF-8 aware):
- `get_first_byte(pos)` / `get_last_byte(pos)` — Snap a position to the first/last byte of a multi-byte character.

Buffer contents:
- `get_lines(start, stop)` / `get_line(lnum)` — Read buffer text.
- `get_text(selection)` — Read text covered by a selection.
- `insert_text(pos, text)` / `delete_selection(sel)` / `change_selection(sel, text)` — Mutate buffer text.
- `comes_before(pos1, pos2)` / `is_inside(pos, selections)` — Position comparison helpers.

Highlight:
- `highlight_selection(selection)` / `clear_highlights()` — Visual feedback using the `NvimSurroundHighlight` namespace.

### `nvim-surround.input` (`lua/nvim-surround/input.lua`)

User input helpers:
- `get_char()` — Read a single key from the user (returns `nil` on `<Esc>`/`<C-c>`).
- `get_input(prompt)` — Read a string via `vim.fn.input` (returns `nil` on cancel).
- `replace_termcodes(char)` — Convert terminal keycodes (e.g. `<C-g>`) to internal representation; pass through ASCII/UTF-8 bytes unchanged.

### `nvim-surround.cache` (`lua/nvim-surround/cache.lua`)

Dot-repeat state. Three caches:
- `cache.normal` — `{ delimiters, line_mode }`.
- `cache.delete` — `{ char }`.
- `cache.change` — `{ del_char, add_delimiters, line_mode }`.

`set_callback(func_name)` — Triggers a no-op `g@l` to register the next `operatorfunc` for dot-repeat.

### `nvim-surround.utils` (`lua/nvim-surround/utils.lua`)

- `NOOP` — Empty function used as a placeholder `operatorfunc`.
- `get_nearest_selections(char, action)` — For each aliased char, compute candidate `selections` and pick the best via `filter_selections_list`.
- `filter_selections_list(selections_list)` — Jumping heuristic: prefers the selection containing the cursor; otherwise the nearest one before/after the cursor.

### `nvim-surround.motions` (`lua/nvim-surround/motions.lua`)

- `is_quote(char)` — Returns true for `'`, `"`, `` ` ``.
- `get_selection(motion)` — Uses `set_operator_marks` to resolve a Vim text-object (e.g. `a(`, `at`, `a"`) into a `selection`. Falls back to a lookbehind search when the cursor is not already inside the text-object.

### `nvim-surround.patterns` (`lua/nvim-surround/patterns.lua`)

Lua pattern-based selection:
- `index_to_pos(index)` / `pos_to_index(pos)` — Convert between 1D buffer index and 2D position.
- `adjust_selection(selection)` — Expand selection to fully contain multi-byte characters.
- `get_selection(find)` — Find the nearest match for a Lua pattern around the cursor.
- `get_selections(selection, pattern)` — Given a parent selection and a pattern with four capture groups `(left_delimiter)(start)(right_delimiter)(end)`, return the left/right delimiter selections.

### `nvim-surround.queries` (`lua/nvim-surround/queries.lua`)

Tree-sitter query capture selection (requires `nvim-treesitter`):
- `get_node(selection)` — Find the exact node matching a selection via DFS.
- `filter_selection(sexpr, capture, parent_selection)` — Narrow a parent selection to a named capture.
- `get_selection(capture, type)` — Get the nearest capture match of a given type (e.g. `"textobjects"`).

### `nvim-surround.treesitter` (`lua/nvim-surround/treesitter.lua`)

Tree-sitter node-type selection (requires `nvim-treesitter`):
- `get_selection(node_types)` — DFS from the root to find the nearest node whose type is in `node_types`, returning it as a `selection`.

### `nvim-surround.annotations` (`lua/nvim-surround/annotations.lua`)

Shared LuaLS type definitions used across modules:
- Aliases: `text`, `position`, `delimiter`, `delimiter_pair`, `add_func`, `find_func`, `delete_func`, `change_table`.
- Classes: `selection`, `selections`, `surround`, `options`, `user_surround`, `user_options`.

### `nvim-surround.functional` (`lua/nvim-surround/functional.lua`)

- `to_list(t)` — Wrap a scalar in a single-element list; pass lists through unchanged.

## Configuration

```lua
require("nvim-surround").setup({
    keymaps = {
        normal = "ys",
        delete = "ds",
        change = "cs",
        -- Set any mapping to `false` to disable it.
    },
    surrounds = {
        ["$"] = {
            add = { "${", "}" },
            find = function()
                -- Return a selection for the text inside ${ ... }
            end,
            delete = "^(%${)().-(})()$",
        },
    },
    aliases = {
        ["b"] = ")",
    },
    highlight = {
        duration = 500,  -- milliseconds; 0 means "until next action"
    },
    move_cursor = "begin",  -- "begin" | "sticky" | false
})
```

Buffer-local overrides:
```lua
require("nvim-surround").buffer_setup({
    keymaps = { normal = "ys" },
})
```

### Adding a Custom Surround

A surround is defined by four keys:
```lua
surrounds = {
    ["$"] = {
        -- Required: returns a pair of delimiter lines.
        add = { "${", "}" },
        -- Required: returns the selection *inside* the delimiters.
        find = function()
            return require("nvim-surround.config").get_selection({
                pattern = "%${.-}",
            })
        end,
        -- Required: returns the left/right delimiter selections to delete.
        delete = "^(%${)().-(})()$",
        -- Optional: target/replacement for `change`.
        change = {
            target = "^(%${)().-(})()$",
            replacement = function() return { "${", "}" } end,
        },
    },
}
```

User-provided strings for `find`/`delete`/`change.target` are treated as Lua patterns; tables for `add` are wrapped into a function automatically.

## Dependencies

- **Required:** Neovim 0.8+.
- **Optional:**
  - [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) — Enables surrounding/changing Tree-sitter nodes (e.g. `@call.outer` for `f`).
  - [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects) — Allows using Tree-sitter text-objects in surround definitions.
- **Test:** [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (test framework).

## Build / Test

```bash
# Run the full test suite
nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = './tests/minimal_init.lua' }"

# Static analysis
luacheck lua/
selene check

# Formatting
stylua --check lua/
```

## Coding Standards

- Formatting is enforced by `stylua.toml`.
- Static analysis via `.luacheckrc` (luacheck) and `selene.toml` (selene).
- Type annotations use LuaLS syntax (`---@class`, `---@field`, `---@param`, `---@alias`, `---@type`); shared types live in `annotations.lua`.
- All user-facing keymaps are implemented as `<Plug>(nvim-surround-*)` maps; user keymaps are bound to these `<Plug>` targets.
- Dot-repeat is implemented by caching the action in `cache.*` and re-registering the appropriate `operatorfunc` via `cache.set_callback`. A `vim.on_key` listener captures the cursor position when the user presses `.`.
- Cursor position through buffer mutations is preserved using extmarks (`buffer.with_extmark`).
- Motion-based operations use the `operatorfunc` + `g@` pattern; `[` and `]` marks are adjusted to avoid landing on whitespace.
- All buffer positions are 1-indexed; conversions to 0-indexed Neovim API calls happen at the `buffer.lua` boundary.
