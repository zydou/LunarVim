# nui.nvim

## Project Overview

nui.nvim is a **UI Component Library for Neovim** by MunifTanjim, written in pure Lua. It provides reusable, extensible building blocks for floating windows, splits, prompts, menus, trees, tables, and composite layouts. It is a foundational dependency for many popular plugins (e.g., noice.nvim, dressing.nvim, neo-tree, nvim-notify).

**Two categories of primitives:**
- **Blocks** (buffer rendering primitives): `NuiText`, `NuiLine`, `NuiTable`, `NuiTree`
- **Components** (interactive window managers): `NuiPopup`, `NuiInput`, `NuiMenu`, `NuiSplit`, `NuiLayout`

**Core design goal:** Extensibility — every component supports `Class:extend("Name")` to create custom subclasses.

## Directory Structure

```
nui.nvim/
├── lua/nui/                      # All source code
│   ├── object/init.lua           # Base class system (middleclass port)
│   ├── text/init.lua             # NuiText
│   ├── line/init.lua             # NuiLine
│   ├── tree/                     # NuiTree (+ util.lua)
│   ├── table/                    # NuiTable
│   ├── popup/                    # NuiPopup (+ border.lua)
│   ├── input/                    # NuiInput (extends Popup)
│   ├── menu/                     # NuiMenu (extends Popup)
│   ├── split/                    # NuiSplit (+ utils.lua)
│   ├── layout/                   # NuiLayout (+ float.lua, split.lua, utils.lua)
│   └── utils/                    # Shared utilities (init, autocmd, keymap, buf_storage)
├── tests/                        # Plenary/busted test suite
│   ├── init.lua                  # Test bootstrap (--clean simulation)
│   ├── helpers/init.lua          # Custom assertions and popup border helpers
│   └── nui/                      # Specs mirroring lua/nui/ structure
├── scripts/                      # CI scripts (test, lint, format, plenary patch)
├── .github/workflows/            # ci.yml, publish.yml
├── nui.nvim-dev-1.rockspec       # Package spec
├── .stylua.toml / .luacheckrc / .luacov / .codecov.yml
├── CHANGELOG.md, LICENSE, README.md
```

**Note:** There is no top-level `lua/nui/init.lua` aggregator. Consumers require individual modules directly, e.g., `require("nui.popup")`, `require("nui.text")`.

## Core Modules

| Module | Export | Type |
|---|---|---|
| `nui.object` | `Object(name)` | Factory → class (`new`, `extend`, `is_instance`, `is_subclass`) |
| `nui.text` | `NuiText` | Highlightable text segment |
| `nui.line` | `NuiLine` | Row of NuiText chunks |
| `nui.tree` | `NuiTree`, `Tree.Node(data, children?)` | Tree renderer + node factory |
| `nui.table` | `NuiTable` | Grid renderer with border/header/footer |
| `nui.popup` | `NuiPopup` | Floating window component |
| `nui.popup.border` | `NuiPopupBorder` | Border subcomponent |
| `nui.input` | `NuiInput` | Prompt input (extends Popup) |
| `nui.menu` | `NuiMenu`, `Menu.item()`, `Menu.separator()` | Selectable menu (extends Popup) |
| `nui.split` | `NuiSplit` | Editor/window split component |
| `nui.layout` | `NuiLayout`, `Layout.Box()` | Composes Popup/Split into floating or split layouts |
| `nui.utils` | utils table | `defaults`, `is_type`, `parse_number_input`, `get_editor/window_size`, internal `_` helpers |
| `nui.utils.autocmd` | autocmd table | `event` enum, `create/delete/exec`, `buf.define/remove` |
| `nui.utils.keymap` | keymap table | `set`, `_del`, `execute` |
| `nui.utils.buf_storage` | buf_storage table | Per-buffer namespaced storage with cleanup |

### NuiText API

- `Text(content, extmark?)` — `extmark` is a highlight group name or `{hl_group=...}` table
- `:set(content, extmark?)`, `:content()`, `:length()`, `:width()`
- `:highlight(bufnr, ns_id, linenr, byte_start)`
- `:render(bufnr, ns_id, linenr_start, byte_start, ...)` / `:render_char(...)`

### NuiLine API

- `Line(texts?)`, `:append(content, highlight?)`, `:content()`, `:width()`
- `:highlight(...)`, `:render(bufnr, ns_id, linenr_start, linenr_end?)`

### NuiTree API

- `Tree.Node(data, children?)` — factory; node receives `_id`, `_depth`, `_parent_id`, `_child_ids`
- `Tree({bufnr, ns_id, nodes, get_node_id?, prepare_node?})`
- `:get_node(id_or_linenr)` → returns `(node, linenr_start, linenr_end)`
- `:get_nodes(parent_id?)`, `:set_nodes(nodes, parent_id?)`, `:add_node(node, parent_id?)`, `:remove_node(node_id)`
- Node methods: `:get_id/depth/parent_id`, `:has_children`, `:get_child_ids`, `:is_expanded/expand/collapse`
- `:render(linenr_start?)`

### NuiTable API

- `Table({bufnr, ns_id, columns, data})` — columns contain `accessor_key`/`accessor_fn`, `header`/`footer` (string|NuiText|NuiLine|function), `cell` (function), `align`, `min/max_width`, nested `columns`
- `:render(linenr_start?)`, `:get_cell(position?)`, `:refresh_cell(cell)`

### NuiPopup API

- `Popup({relative, position, size, enter, focusable, zindex, anchor, buf_options, win_options, border, ns_id, bufnr?})`
- Lifecycle: `:mount()`, `:unmount()`, `:hide()`, `:show()`
- `:update_layout(config)` (replaces deprecated `:set_layout/set_size/set_position`)
- `:map/:unmap/:on/:off` (keymaps + autocommands on the popup buffer)
- Public fields: `bufnr`, `winid`, `ns_id`, `border`, `win_config`

### NuiPopupBorder API

Handles simple (string style → `win_config.border`) vs. complex (separate border window + buffer). Built-in styles: `double`, `none`, `rounded`, `shadow`, `single`, `solid`. Custom: 8-element list, named map, or per-character `{char, hl_group}` tuples.

- `:set_style(style)`, `:set_text(edge, text, align)`, `:set_highlight(highlight_group)`, `:get()`
- Public fields: `popup` (back-reference), `bufnr`, `winid`, `win_config` (only for complex borders)
- `:get()` returns `nil` for complex borders, the style string or tuple list for simple borders

### NuiInput API (extends Popup)

- `Input(popup_options, {prompt, default_value, on_change, on_close, on_submit, disable_cursor_position_patch})`
- Uses vim prompt buffer (`buftype=prompt`, `prompt_setcallback`)
- Overrides `:mount/:unmount` to handle insert-mode cursor patching and submit/close callbacks
- Note: `on_change` is deprecated

### NuiMenu API (extends Popup)

- `Menu(popup_options, {lines, max/min_width/height, keymap, prepare_item, should_skip_item, on_change, on_close, on_submit})`
- `Menu.item(content, data?)`, `Menu.separator(content, options?)` — returns `Tree.Node`
- Default keymaps: `j/k/Tab/S-Tab` navigate, `Esc/C-c` close, `<CR>` submit (no `<Space>`)
- `on_change` callback signature: `fun(item: NuiTree.Node, menu: NuiMenu): nil`
- Internally creates a `NuiTree` to render items

### NuiSplit API

- `Split({relative, position, size, enter, buf_options, win_options, ns_id})`
- `:mount/:unmount/:hide/:show/:update_layout`, `:map/:unmap/:on/:off`
- Uses `nvim_command` splits + `win_splitmove` for repositioning

### NuiLayout API

- `Layout(options, box)` — `options` is layout config or a container Popup/Split
- `Layout.Box(box, {dir, grow, size})` — wraps components into a box tree; `dir` = `"row"` (default) | `"col"`
- Auto-detects layout `type` = `"float"` (contains a Popup) or `"split"` (only Splits)
- `:mount/:unmount/:hide/:show/:update(config, box?)`

### Utils

- `utils._` (internal): `get_next_id`, `clear_namespace`, `normalize_namespace_id`, `ensure_namespace_id`, `set_buf/win_option(s)`, `normalize_dimension`, `truncate_text/nui_text/nui_line`, `calculate_gap_width`, `render_lines`, `clear_lines`, `normalize_layout_options`, `parse/serialize_winhighlight`, `char_to_byte_range`
- Feature flags: `_.feature.lua_keymap`, `lua_autocmd`, `v0_10`
- `autocmd.event` — full Vim autocommand event name enum (with aliases like `BufCreate`, `BufRead`, `BufWrite`, `FileEncoding`)

## Configuration

nui.nvim is a component library with no global setup. Each component is configured via its constructor:

```lua
local Popup = require("nui.popup")
local popup = Popup({
  relative = "editor",
  position = "50%",
  size = { width = 80, height = 40 },
  border = { style = "rounded", text = { top = "Title" } },
})
popup:mount()
```

## Dependencies

- **Runtime:** None (requires Neovim >= 0.5.0; rockspec has no `depends` entries)
- **Dev/test:**
  - `plenary.nvim` — test harness (`plenary.test_harness`, `plenary.busted`)
  - `luacov` + `luafilesystem` — code coverage
  - `luacheck` — static analysis
  - `stylua` (v0.17.1) — formatting

## Build / Test

| Tool | Config/Script | Purpose |
|---|---|---|
| **luacheck** | `.luacheckrc` (std=luajit, ignores 211/212/213 for unused `_`; `vim` global) | Static analysis, run via `scripts/lint.sh` |
| **stylua** | `.stylua.toml` (120 columns, 2-space indent, AutoPreferDouble, Unix line endings) | Formatting; CI checks `lua/nui/` and `tests/` |
| **luacov** | `.luacov` | Coverage stats |
| **scripts/test.sh** | — | Clones + patches plenary, runs plenary harness in headless nvim, prints luacov summary, fails on stack traces |
| **scripts/format.sh** | — | Formatting script |
| **CI** | `.github/workflows/ci.yml` | Jobs: `lint` (luacheck), `format` (stylua check), `test` (luacov + codecov), `release` (release-please → publish.yml) |

**Test structure:**
- Framework: Plenary's busted-style specs, run headless via `scripts/test.sh`
- Bootstrap: `tests/init.lua` strips user runtime paths (`--clean` simulation), sets `package.path` to repo root, adds plenary from `.tests/site`
- Layout: `tests/nui/<module>/init_spec.lua` mirrors `lua/nui/<module>/`
- Helpers: `tests/helpers/init.lua` provides custom assertions (`mod.eq/neq/approx/errors/feedkeys/tbl_pick/tbl_omit`), buffer/extmark assertions (`assert_buf_lines/options`, `assert_extmark`, `assert_highlight`), and popup border helpers
- Feature-flipping tests: `mod.describe_flipping_feature(name, desc, func)` runs the block under both states of a feature flag (for lua keymap/autocmd/v0_10 compatibility paths)
- plenary is patched via `scripts/plenary-353.patch` to fix a luacov incompatibility

## Coding Conventions

- **Class names:** PascalCase — `NuiPopup`, `NuiInput`, `NuiMenu`, `NuiSplit`, `NuiLayout`, `NuiTree`, `NuiTable`, `NuiText`, `NuiLine`, `NuiPopupBorder`, `NuiTree.Node`
- **File naming:** Each class lives in `lua/nui/<name>/init.lua`; helper files use lowercase (`border.lua`, `utils.lua`, `util.lua`, `float.lua`, `split.lua`)
- **Private/internal state:** Stored in `self._` (single-underscore table) — e.g., `self._.mounted`, `self._.size`
- **Internal utilities:** `utils._` (single-underscore field) holds private helpers
- **Public fields:** `bufnr`, `winid`, `ns_id`, `win_config`, `border` are exposed directly on instances
- **Class identity pattern:** Each module ends with a local alias and returns it:
  ```lua
  local NuiPopup = Popup
  return NuiPopup
  ```
- **Type annotations:** Extensive EmmyLua-style `---@class`, `---@alias`, `---@field`, `---@param` annotations
- **Deprecated APIs:** Clearly marked with `-- luacov: disable` blocks and `---@deprecated` annotations; old names preserved as wrappers (e.g., `Popup:set_layout` → `:update_layout`)
- **Keymap handler signature convention:** `___force___` and `___byte_start___` triple-underscore params indicate internal/forced parameters
- **Border style naming:** 8 positional map keys: `top_left`, `top`, `top_right`, `right`, `bottom_right`, `bottom`, `bottom_left`, `left`
- **ID generation:** `nui.utils._.get_next_id()` yields `"nui_1"`, `"nui_2"`, ... for autocommand groups and instance IDs
