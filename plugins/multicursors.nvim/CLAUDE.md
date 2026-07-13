# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

**multicursors.nvim** is a Neovim multicursor plugin inspired by [vim-visual-multi](https://github.com/mg979/vim-visual-multi) and built on top of [hydra.nvim](https://github.com/nvimtools/hydra.nvim). It provides intuitive repetitive text editing by letting users create and manage multiple selections, then perform synchronized edits across all of them.

Main features:

- Synchronized editing on selections (insert, append, replace, delete, etc.)
- Create selections via search pattern / word under cursor
- Extend mode for expanding selections via Vim motions or Treesitter nodes
- Three modes: Normal, Insert, and Extend
- Real-time key synchronization to all selections in Insert mode
- Treesitter-powered selection extension (parent, first-child, last-child nodes)

## Directory Structure

```
multicursors.nvim/
├── README.md             # User documentation and default configuration
├── CHANGELOG.md          # Version changelog
├── LICENSE               # License
├── Makefile              # Build/test targets
├── stylua.toml           # Code formatting configuration
├── doc/
│   └── multicursors.txt  # Vim built-in help docs
├── lua/
│   └── multicursors/
│       ├── init.lua         # Entry point: setup(), command creation, public API
│       ├── config.lua       # Default configuration and default keymap tables
│       ├── types.lua        # vim doc-annotated types (@class definitions)
│       ├── utils.lua        # Selection extmark creation/reading/deletion, cursor movement, and other core utilities
│       ├── search.lua       # Pattern finding, <cword>, visual selection, find next/previous
│       ├── selections.lua   # Selection math: motion, reduction, forward movement
│       ├── layers.lua       # Hydra layer creation and hint generation
│       ├── normal_mode.lua  # Normal mode action API (find, jump, paste, macro, etc.)
│       ├── insert_mode.lua  # Insert mode actions: key sync, BS/Del/arrow keys
│       ├── extend_mode.lua  # Extend mode: motion expansion, TS nodes, anchor toggle
│       ├── highlight.lua    # Highlight group definitions (MultiCursor, MultiCursorMain)
│       └── ts.lua           # Treesitter helper: parent/first_child/last_child
└── tests/
    ├── minimal_init.lua     # Test bootstrap: clone deps, load plugin
    ├── run_tests.sh         # Script to run all spec files
    └── multicursors/
        ├── normal_spec.lua     # Normal mode tests
        ├── insert_spec.lua     # Insert mode tests
        ├── search_spec.lua     # Search tests
        ├── selections_spec.lua # Selection math tests
        └── extend_spec.lua     # Extend mode tests
```

## Core Modules

### `init.lua` — Entry Point and Public API

The sole entry module exposed to users.

- `setup(opts)` — Merge default config, set DEBUG_MODE flag on `vim.g.MultiCursorDebug`, register highlights, register commands, create the Normal hydra layer.
- `start()` — Start multicursor (visual selection if in visual mode, otherwise `<cword>`).
- `new_under_cursor()` — Create a selection for the character under the cursor and activate Normal mode.
- `search_visual()` — Create a selection from the last visual selection.
- `new_pattern()` / `new_pattern_visual()` — Interactively prompt for a pattern; select every match in the buffer or visual range.
- `exit()` — Clear selections and buffer vars (delegates to `utils.exit()`).

User commands created when `create_commands = true`: `MCstart`, `MCvisual`, `MCclear`, `MCpattern`, `MCvisualPattern`, `MCunderCursor`.

### `config.lua` — Default Configuration and Keymap Tables

Exports a table `M` used as default config. Contains three keymap dictionaries:

- `normal_keys` — Normal mode keymap table `{ [string]: Action }` (lines 10–58)
- `extend_keys` — Extend mode keymap table (lines 60–84)
- `insert_keys` — Insert mode keymap table (lines 86–127)

Each `Action` field:

- `method` — Function to invoke when the key is pressed; `nil` creates an exit head (leaves multicursor mode); `false` removes the binding.
- `opts` — Table passed through to Hydra. May contain `{ desc, nowait, exit, ... }`. Overrides to `nowait` on individual actions take precedence over the global `nowait`.

Other notable config fields:

```lua
{
    DEBUG_MODE = false,
    create_commands = true,
    updatetime = 50,
    nowait = true,
    mode_keys = { append = 'a', change = 'c', extend = 'e', insert = 'i' },
    normal_keys = normal_keys,
    insert_keys = insert_keys,
    extend_keys = extend_keys,
    hint_config = { float_opts = { border = 'none' }, position = 'bottom' },
    generate_hints = {
        normal = true,
        insert = true,
        extend = true,
        config = { column_count = nil, max_hint_length = 25 },
    },
}
```

### `types.lua` — Type Annotations

`@class` types defined for vim doc generation:

- `Action` — `{ method: function?|false, opts: HeadOpts }`
- `Point` — `{ row: integer, col: integer }`
- `Selection` — `{ id: integer, row: integer, col: integer, end_row: integer, end_col: integer }` (all 0-indexed)
- `SearchContext` — `{ pattern, text, row, offset, till, skip }`
- `Head` — `{ [1] = string, [2] = string|function|nil, [3] = HeadOpts }`
- `HeadOpts` — `{ private?, exit?, exit_before?, on_key?, mode?, silent?, expr?, nowait?, remap?, desc? }`
- `GenerateHints`, `GenerateHintsConfig`, `Config` — Configuration types

### `utils.lua` — Core Utilities

Maintains two extmark namespaces:

- `ns_id = nvim_create_namespace 'multicursors'` — secondary (multi) selections
- `main_ns_id = nvim_create_namespace 'multicursorsmaincursor'` — the main selection

Key API:

- `create_extmark(sel, ns)` — Create an extmark, deleting any pre-existing marks whose id differs from `sel.id` in the new extmark's range. Passes `overlap = true` on Neovim > 0.9.9. Returns the extmark id.
- `delete_extmark(sel, ns)` — Delete the first extmark found in the selection's range.
- `clear_namespace(ns)` / `clear_selections()` — Clear all extmarks of a namespace or both namespaces.
- `get_main_selection()` — Return the main `Selection`, or `{}` if none.
- `get_all_selections()` — Return a `Selection[]` of every multi selection (excludes main).
- `swap_main_to(new, skip)` — Swap the main selection with `new`. Resolves ids so `new` becomes the main extmark and the old main becomes a multi selection (unless `skip` is true).
- `call_on_selections(cb)` — Call `cb` on every multi selection (re-reading each mark by id first), then on the main selection.
- `update_selections_with(cb)` — Like `call_on_selections`, but deletes the extmark before calling `cb` and recreates it after (so extmarks track buffer edits).
- `move_cursor(pos, current?)` — Move cursor and (optionally) record position in the jumplist via the `'` marker. Clamps negative columns to 0 (works around Neovim #20793).
- `get_char()` — Read a single character from the user; returns `nil` on interrupt.
- `get_last_visual_range()` — Return text of the last visual selection as a `string[]`.
- `debug(any)` — Notify via `vim.notify` at DEBUG level when `vim.g.MultiCursorDebug` is set.
- `exit()` — Clear selections and reset `vim.b.MultiCursorMultiline`, `vim.b.MultiCursorPattern`, `vim.b.MultiCursorSubLayer`.

Enums:

- `M.position = { before = 'before', after = 'after', on = 'on' }`
- `M.namespace = { Main = 'MultiCursorMain', Multi = 'MultiCursor' }`

### `search.lua` — Pattern Finding

Key API:

- `find_cursor_word()` — Find the `<cword>` under the cursor, store it as `\<word\>` in `vim.b.MultiCursorPattern`, and mark the main selection. Returns `true` on success.
- `find_all_matches(content, pattern, start_row, start_col)` — Find every match of `pattern` in a `string[]` content list (offset by `start_row`/`start_col` for visual ranges) and make the last match the main selection. Notifies "no match found" on zero hits.
- `find_next(skip)` / `find_prev(skip)` — Find next/previous match after/before the cursor (wraps around the buffer). Delegates to `multiline_string` when `vim.b.MultiCursorMultiline` is true.
- `new_under_cursor()` — Mark the character under the cursor as the main selection and clear `vim.b.MultiCursorPattern`.
- `create_down(skip)` / `create_up(skip)` — Create a selection on the line below/above the cursor; delegates to `swap_main_to`.
- `create_under()` — Create a selection under the cursor; delegates to `swap_main_to`.
- `find_pattern(whole_buffer)` — Interactively read keys from the user, updating the selection each keystroke; returns `true` when at least one match was made.
- `find_selected()` — Find the last visual selection's text and mark it as the main selection; sets multiline state when the selection has more than one line.
- `multiline_string(pattern, pos)` — Match a multiline pattern via `vim.fn.searchpos`.

Buffer vars used:

- `vim.b.MultiCursorPattern` — Current search pattern.
- `vim.b.MultiCursorMultiline` — Whether the current pattern is multiline.
- `vim.b.MultiCursorAnchorStart` — In Extend mode, which end of the selection stays put.
- `vim.b.MultiCursorSubLayer` — Whether a sub-hydra layer (Insert or Extend) is active.

### `selections.lua` — Selection Math

- `_get_new_position(sel, motion)` — Execute a Vim `motion` from the selection and return a zero-length `Selection` at the new position.
- `_get_reduced_selection(sel, pos, count?)` — Collapse a selection to zero length at `before` / `on` / `after` the current selection.
- `move_by_motion(motion)` — Re-position all secondary selections (then main) by running a Vim motion, then move the cursor.
- `reduce_to_char(pos)` — Shrink every selection (main and secondary) to zero length at `pos`.
- `_move_forward(count)` — Collapse every selection to `after` and then expand it by `count` characters.
- `move_char_horizontal(pos)` — Collapse all selections horizontally to `pos` (`'before'` or `'after'`).

### `layers.lua` — Hydra Layer Creation and Hint Generation

Hydra layers:

- `L.normal_hydra` — Normal mode layer
- `L.insert_hydra` — Insert mode layer
- `L.extend_hydra` — Extend mode layer

Key API:

- `create_normal_hydra(config)` — Build the Normal Hydra with `mode_keys.insert/change/append/extend` sub-layer heads, an `<esc>` exit head, and mode/color settings.
- `generate_normal_heads(config)` / `generate_insert_heads(config)` / `generate_extend_heads(config)` — Build the Head[] arrays. Normal heads also include sub-layer entries bound to `config.mode_keys.*`.
- `create_insert_hydra(config)` / `create_extend_hydra(config)` — Build the Insert/Extend Hydras. On exit, both defer reactivation of `normal_hydra` by 20 ms via `vim.defer_fn` and clear `vim.b.MultiCursorSubLayer`.
- `set_heads_options(keys, nowait)` — (local) Iterate the keymap dictionary, skip entries whose `method == false`, and return a `Head[]` with per-action `nowait` taking precedence over the global default.
- `generate_hints(config, heads, mode)` — (local) Render hints. Returns `'MultiCursor {mode} mode'` when `config.generate_hints[mode] == false`; uses a custom string when it is a string; calls it as `f(heads)` when it is a function; otherwise auto-generates padded, column-aligned hints.

Sub-layer behavior: entering Insert/Extend sets `vim.b.MultiCursorSubLayer = true` and creates the sub-hydra on demand. The Normal hydra's `on_exit` skips `utils.exit()` when a sub-layer is running.

### `normal_mode.lua` — Normal Mode Action API

All methods are invoked by Hydra heads:

Lookup and navigation: `find_next`, `skip_find_next`, `find_prev`, `skip_find_prev`, `find_all_matches`, `goto_next`, `goto_prev`, `skip_goto_next`, `skip_goto_prev`
Selection creation: `create_up`, `skip_create_up`, `create_down`, `skip_create_down`, `create_char`
Editing: `change(config)`, `delete`, `delete_line`, `delete_end`
Paste and replace: `paste_after`, `paste_before`, `replace`
Yank: `yank`, `yank_end`, `yank_line`
Case: `upper_case`, `lower_case`
Misc: `run_macro`, `normal_command`, `dot_repeat`, `clear_others`, `align_selections_before`, `align_selections_start`

`goto_next`/`goto_prev`/`skip_goto_*` wrap around the buffer. `skip_*` variants swap the main match without preserving it as a secondary selection.

### `insert_mode.lua` — Insert Mode Action API

Insert-mode synchronization is implemented via autocommands on the `multicursors` augroup:

- `insert(config)` — Shrink every selection to zero length `before` the cursor, then start insert mode and install the autocommands.
- `append(config)` — Same as `insert`, but shrinks to `on` the selection.
- `insert_text(text)` — Append `text` at the end of every secondary selection, then advance them by the text's char length.
- `exit()` — Clear insert autocommands, send `<Esc>`, and clear `vim.b.MultiCursorSubLayer`.
- `_insert_and_clear()` — Flush any buffered `_inserted_text` via `insert_text`, then reset the buffer.

Key-mapping methods (all methods on `M`): `BS_method`, `CR_method`, `Del_method`, `Left_method`, `Right_method`, `UP_method`, `Down_method`, `Home_method`, `End_method`, `C_Right`, `C_Left`, `C_w_method`, `C_u_method`.

`_on_insert_enter` swaps `vim.opt.updatetime` to `config.updatetime` during Insert mode. `_on_insert_char_pre` accumulates typed chars in `_inserted_text`. `_on_cursor_hold` flushes the buffer every `updatetime` ms. `_on_insert_leave` flushes and restores `updatetime`.

### `extend_mode.lua` — Extend Mode Action API

Motion expansion: `h_method`, `j_method`, `k_method`, `l_method`, `w_method`, `e_method`, `b_method`, `caret_method`, `dollar_method`
Treesitter: `node_parent`, `node_first_child`, `node_last_child`
Misc: `o_method` / `O_method` (toggle anchor), `custom_method` (prompt for a motion), `undo_history` (restore last extend state)

`extend_selections(motion)` reads `vim.b.MultiCursorAnchorStart` to decide which end stays put, applies the motion, and auto-toggles the anchor via `o_method` when every selection passes the anchor (mimicking Visual-mode behavior). `custom_method` uses `vim.ui.input`. Selection history is saved in a module-local `last_selections` table and restored by `undo_history`.

### `highlight.lua` — Highlight Groups

Defines two highlight groups:

- `MultiCursor` — secondary selections (yellow-green `#DBEC6B` on `#161714`)
- `MultiCursorMain` — main selection (bright green `#d6f31f`, bold)

Registered with `default = true` and refreshed on `ColorScheme` via an autocommand set up in `init.setup`.

### `ts.lua` — Treesitter Helpers

- `extend_node(match)` — Return the range of the Treesitter node's parent. Climbs parents until the range differs from the match; falls back to the next named sibling if the parent is nil.
- `get_first_child(match)` — Return the range of the first named child node whose range differs from the match.
- `get_last_child(match)` — Return the range of the last named child node whose range differs from the match.

## Configuration

Configured via `require('multicursors').setup(opts)`. Options are merged with `vim.tbl_deep_extend('keep', opts, default_config)`, so user values take precedence.

Custom keymap example:

```lua
require('multicursors').setup {
    normal_keys = {
        [','] = {
            method = N.clear_others,
            opts = { desc = 'Clear others' },
        },
        ['<C-/>'] = {
            method = function()
                require('multicursors.utils').call_on_selections(function(selection)
                    vim.api.nvim_win_set_cursor(0, { selection.row + 1, selection.col + 1 })
                    local line_count = selection.end_row - selection.row + 1
                    vim.cmd('normal ' .. line_count .. 'gcc')
                end)
            end,
            opts = { desc = 'comment selections' },
        },
    },
}
```

## Dependencies

Runtime:

- **Neovim >= 0.9.0** (uses extmarks, `nvim_buf_set_text`, versions API, and similar)
- **[hydra.nvim](https://github.com/nvimtools/hydra.nvim)** (actively maintained fork) — provides the Hydra layer system (mappings, hints, mode switching, statusline integration)

Test:

- **[plenary.nvim](https://github.com/nvim-lua/plenary.nvim)** — provides the `PlenaryBustedFile`/`PlenaryBustedDirectory` test runners
- **hydra.nvim** — as above

## Build / Test

Run all tests:

```bash
make test
# or directly:
chmod +x tests/run_tests.sh
tests/run_tests.sh
```

The test bootstrap (`tests/minimal_init.lua`) clones `plenary.nvim` and `hydra.nvim` into `/tmp/` ( overridable via `PLENARY_DIR` and `HYDRA_DIR` ) and adds them to `runtimepath`. Tests then run via plenary's busted-compatible layer.

Format:

```bash
stylua .
```

Formatting config (`stylua.toml`): Unix line endings, 4-space indent, 80 column width, single-quote preferred, no call parentheses.

## Coding Conventions

### Style

- **Indent**: 4 spaces (no tab)
- **Width**: 80 columns
- **Quotes**: single quotes preferred (`'multicursors.utils'`)
- **Line endings**: Unix (LF)
- **Call parentheses**: omitted (`M.foo 'bar'` not `M.foo('bar')`)

### Naming

- **Modules**: `lua/multicursors/<name>.lua`, each returns a local `M` table.
- **Class types**: `---@class Foo` declared in `types.lua`.
- **Private fields**: `_underscore` prefix (e.g. `_inserted_text`, `_au_group`).
- **Public methods**: capitalized (`M.start`, `M.setup`).
- **Action methods**: `snake_case_method` (e.g. `find_next`, `create_down`, `BS_method`).
- **Constant enums**: `M.position`, `M.namespace` using PascalCase values.

### Type Annotations

Every public function and class uses `---@type`, `---@param`, `---@return`, `---@class` annotations.

```lua
---@param selection Selection
---@param namespace Namespace
---@return integer
M.create_extmark = function(selection, namespace) ... end
```

### Module Pattern

```lua
local M = {}
-- ...
return M
```

Other modules are required with dot separators (e.g. `require 'multicursors.utils'`).

### Comment Style

- Use `---` triple-dash comments (vim doc style).
- Mark complex logic with `-- INFO`, `-- HACK`, `-- TODO`.
- Inline comments use `--` followed by a space.

### Test Conventions

- Filename pattern: `<module>_spec.lua`.
- Structure with `describe` / `it` / `before_each` / `after_each`.
- Use `luassert` for assertions (`assert.same`, `assert.equal`, `assert.is_not`, ...).
- Start tests with `vim.cmd [[enew]]` for a clean buffer.
- Clean up with `vim.cmd.bdelete { bang = true }` after the test.

### Debugging

Set `DEBUG_MODE = true` in setup or `vim.g.MultiCursorDebug = true` to enable `utils.debug()`, which `vim.notify`s at `vim.log.levels.DEBUG`.

### Important Implementation Details

- Selections are tracked with **extmarks**, not virtual text, so they follow buffer edits automatically.
- The main selection uses a **separate namespace** so its highlight is independent.
- Insert mode is synced live via `InsertCharPre`, `CursorHoldI`, and `InsertLeave` autocommands in a dedicated augroup (`'multicursors'`).
- Multiline patterns use `vim.fn.searchpos` rather than `matchstrpos`.
- Empty-line extmarks are special-cased (forced to `col = 0` / `end_col = 0`) because Neovim can't render zero-width extmarks otherwise.
- All arithmetic on cursor positions follows a strict 0-indexed convention (off by one when crossing the `nvim_win_set_cursor` boundary, which is 1-indexed).
