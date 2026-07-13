# bufferline.nvim - CLAUDE.md

## Project Overview

bufferline.nvim is a Lua-based Neovim plugin that renders a snazzy, GUI-editor-like buffer line (tabline). It provides a visually appealing list of open buffers with tabpage integration, LSP diagnostic indicators, buffer grouping, sidebar offsets, buffer numbers, a picker, pinning, unique name disambiguation, close icons, reordering, custom areas, and more. It is designed to automatically derive its colors from the active colorscheme.

## Directory Structure

```
bufferline.nvim/
├── lua/bufferline.lua                    # Main entry: setup(), public API, tabline rendering
├── lua/bufferline/
│   ├── lazy.lua                          # Lazy-loading utility (deferred require)
│   ├── config.lua                        # Configuration management (Config class, defaults, validation)
│   ├── ui.lua                            # UI rendering engine (tabline string generation)
│   ├── commands.lua                      # User command implementations (move/jump/sort/close/etc.)
│   ├── state.lua                         # Global state management
│   ├── models.lua                        # Component models (Component/Buffer/Tabpage/Section classes)
│   ├── buffers.lua                       # Buffer component management
│   ├── tabpages.lua                      # Tabpage component management
│   ├── groups.lua                        # Grouping system (pinned/groups/ungrouped/separators)
│   ├── sorters.lua                       # Sorting algorithms
│   ├── highlights.lua                    # Highlight group management and caching
│   ├── colors.lua                        # Color utilities (shading, brightness, hl color resolution)
│   ├── constants.lua                     # Constants (separators, visibility, padding, icons)
│   ├── diagnostics.lua                   # LSP diagnostic integration (nvim_lsp, coc)
│   ├── duplicates.lua                    # Duplicate buffer name disambiguation
│   ├── numbers.lua                       # Buffer number display (ordinal/buffer_id/both)
│   ├── pick.lua                          # Buffer picker (character-based selection)
│   ├── offset.lua                        # Sidebar offset (for NvimTree, etc.)
│   ├── hover.lua                         # Mouse hover events
│   ├── custom_area.lua                   # Custom left/right tabline areas
│   ├── types.lua                         # EmmyLua type definitions
│   └── utils/
│       ├── init.lua                      # General utility functions
│       └── log.lua                       # Debug logging
├── tests/                                # Tests (plenary.nvim + busted)
│   ├── bufferline_spec.lua
│   ├── config_spec.lua
│   ├── groups_spec.lua
│   ├── sorters_spec.lua
│   ├── colors_spec.lua
│   ├── highlights_spec.lua
│   ├── numbers_spec.lua
│   ├── offset_spec.lua
│   ├── duplicates_spec.lua
│   ├── ui_spec.lua
│   ├── custom_area_spec.lua
│   ├── utils_spec.lua
│   ├── utils.lua                         # Test utilities
│   └── minimal_init.lua                 # Minimal nvim config for tests
├── doc/bufferline.txt                    # Vim help documentation
├── CHANGELOG.md
├── README.md
├── LICENSE
├── .github/
│   ├── workflows/ci.yaml                # CI: format, tests, release
│   └── workflows/contributing.yaml      # Semantic PR subject check
├── .luarc.json                           # Lua Language Server config
└── stylua.toml                           # Lua formatting config
```

## Core Modules

### `bufferline` (`lua/bufferline.lua`)
Main entry module:
- **M.setup(conf?)** - Configuration entry point; initializes all subsystems, sets up autocommands and user commands, and sets `vim.o.tabline = "%!v:lua.nvim_bufferline()"`
- **M.bufferline()** - Core rendering function that generates the tabline string and segment data
- **_G.nvim_bufferline()** - Tabline expression function (`%!v:lua.nvim_bufferline()`)
- **Public API**:
  - `move(direction)` / `move_to(index)` / `cycle(direction)` / `go_to(num)` - Navigation
  - `sort_by(criteria)` / `pick()` / `close_with_pick()` / `close_in_direction(dir)` - Operations
  - `close_others()` / `rename_tab(args)` / `unpin_and_close(id)` - Management
  - `exec(index, func)` - Execute a function on a visible element by position
  - `get_elements()` / `style_preset` / `groups` - Query/configuration
  - Deprecated aliases: `pick_buffer`, `go_to_buffer`, `sort_buffers_by`, `close_buffer_with_pick`

### `bufferline.config` (`lua/bufferline/config.lua`)
- **Config class** - OOP configuration management
  - `Config:new(o)` - Create config instance (saves a copy of user preferences)
  - `Config:merge(defaults)` - Merge user config with defaults using `vim.tbl_deep_extend("force", ...)`
  - `Config:resolve(defaults)` - Resolve incompatible options (e.g., tabline mode overrides)
  - `Config:validate(defaults, resolved)` - Validate config structure, options, and highlights
  - `Config:is_tabline()` / `Config:is_bufferline()` - Mode checks
- **M.setup(c)** - Parse and store user config
- **M.apply(quiet?)** - Apply config: resolve, validate, merge, set highlight names, return final preferences
- **M.update_highlights()** - Re-derive highlights on colorscheme change
- **M.get()** - Get the current config
- **STYLE_PRESETS** - Style preset enum: `{default = 1, minimal = 2, no_bold = 3, no_italic = 4}`
- **derive_colors(preset)** - Automatically derive all highlight groups from the colorscheme
- Validation: `validate_user_options`, `validate_config_structure`, `validate_user_highlights`
- Deprecation handling: `deprecations` table (e.g., `show_buffer_default_icon`)

### `bufferline.ui` (`lua/bufferline/ui.lua`)
- **M.tabline(items, tab_indicators)** - Generate the full tabline string, segments, and metadata (visible components, offset sizes)
- **M.element(state, element)** - Render a single buffer/tabpage element into segments
- **M.refresh()** - Schedule a tabline redraw via `vim.cmd.redrawtabline()`
- **M.on_hover_over / M.on_hover_out** - Hover event handlers
- **M.make_clickable(func_name, id, component)** - Add mouse click handlers to segments
- Component type IDs: `diagnostics`, `name`, `icon`, `number`, `groups`, `duplicates`, `close`, `modified`, `pick`
- Internal: `Context` class for render context, `truncate()` for fitting buffers to screen width, `to_tabline_str()` for converting segments to tabline format strings

### `bufferline.commands` (`lua/bufferline/commands.lua`)
Implements all user-facing operations:
- `open_element(id)` / `get_current_element()` - Element access
- `handle_user_command(command, id)` - Execute a user command (string or function)
- `handle_click(id, _, button)` / `handle_close(id)` / `handle_group_click(position)` - Mouse click handlers (registered globally as `___bufferline_private.*`)
- `pick()` / `close_with_pick()` / `unpin_and_close(id)` - Picker and close operations
- `go_to(num, absolute?)` / `cycle(direction)` - Navigation
- `move(direction)` / `move_to(to_index, from_index?)` - Reordering (with optional wrapping at ends)
- `sort_by(sort_by)` - Sorting
- `close_in_direction(direction)` / `close_others()` - Bulk close
- `get_elements()` - Get current elements list
- `exec(index, func)` - Execute function on element by visible position
- `rename_tab(args)` - Rename a tabpage

### `bufferline.models` (`lua/bufferline/models.lua`)
Component class hierarchy:
- **Component** - Base class for all visual tabline entities
  - `Component:new(t)` - Create with type, length, focusable, component function
  - `Component:current()` / `Component:is_end()` / `Component:as_element()` - Base interface
  - `Component:__ancestor(depth, formatter)` - Get directory prefix up to a depth
- **Buffer** (type `"buffer"`) - Buffer component with path, icon, diagnostics, visibility, etc.
- **Tabpage** (type `"tab"`) - Tabpage component with buffers list, modified state, etc.
- **GroupView** (type `"group"`) - Non-focusable group separator/label component
- **Section** - A segment of tab views (before/current/after) with `add`, `drop`, and `__add` (length aggregation)

### `bufferline.groups` (`lua/bufferline/groups.lua`)
Grouping system:
- Built-in groups: `pinned` and `ungrouped`
- User-defined groups via `options.groups.items` with `name`, `matcher`, `separator`, `priority`, `highlight`, `icon`, `auto_close`
- Separator styles: `pill` (default), `tab`, `none`
- `M.setup(conf)` - Initialize groups from user config
- `M.render(components, sorter)` - Group, sort, and wrap components with group markers
- `M.set_id(buffer)` - Assign a group ID to a buffer (manual or matcher-based)
- `M.toggle_pin()` / `M.action(name, action)` / `M.toggle_hidden(priority, name)` - Group operations
- `M.complete()` - Command completion for group names
- Pinned buffers persisted via `vim.g.BufferlinePositions`

### `bufferline.sorters` (`lua/bufferline/sorters.lua`)
Sorting algorithms:
- `sort_by_extension` - By file extension
- `sort_by_directory` - By full directory path
- `sort_by_relative_directory` - By relative directory path
- `sort_by_id` - By buffer ID (default)
- `sort_by_tabs` / `sort_by_tabpage_number` - By tabpage number
- `sort_by_new_after_current` - New buffers placed after the currently active one
- `sort_by_new_after_existing` - New buffers placed after all existing ones
- `M.sort(elements, opts)` - Main sort function; respects `custom_sort` (user-driven ordering) and `"none"` to skip sorting

### Other Modules
- **highlights** - Highlight group management: `generate_name`, `set`, `set_all`, `for_element`, `set_icon_highlight`, `hl` (wrap in `%#...#`), icon highlight caching
- **diagnostics** - LSP diagnostic integration: `get(opts)` retrieves diagnostics from `vim.diagnostic` (nvim_lsp) or Coc; `component(ctx)` renders the diagnostic indicator; supports custom `diagnostics_indicator` function
- **duplicates** - Disambiguates buffers with duplicate names by prefixing ancestor directory paths; respects `show_duplicate_prefix`, `duplicates_across_groups`, `max_prefix_length`
- **numbers** - Buffer number display: `none`, `ordinal`, `buffer_id`, `both`, or a custom function; supports superscript/subscript styling
- **pick** - Character-based buffer picker: `choose_then(func)` prompts user for a character then calls func with the selected element ID
- **offset** - Sidebar offset calculation: inspects `vim.fn.winlayout()` to detect sidebar windows by filetype and reserves space for them
- **hover** - Mouse hover event handling: sets up `<MouseMove>` mapping and `BufferLineHoverOver`/`BufferLineHoverOut` autocommands; requires Neovim >= 0.8 and `mousemoveevent`
- **custom_area** - Custom left/right tabline areas: user provides functions returning `{text, fg, bg, link}` tables
- **state** - Global state table: `components`, `visible_components`, `__components`, `current_element_index`, `custom_sort`, `is_picking`, `hovered`, `left_offset_size`, `right_offset_size`
- **constants** - Constants: `padding`, `indicator` ("▎"), `sep_names`, `sep_chars`, `positions_key` ("BufferlinePositions"), `visibility` (SELECTED=3, INACTIVE=2, NONE=1), `FOLDER_ICON`, `ELLIPSIS`
- **lazy** - Lazy-loading utility: `lazy.require(path)` returns a proxy table that defers `require` until first access
- **colors** - Color utilities: `shade_color`, `color_is_bright`, `get_color` (resolve hex/cterm from highlight groups with fallback chaining)
- **utils** - General utilities: `fold`, `measure`, `join`, `map`, `find`, `merge_lists`, `for_each`, `is_valid`, `get_buf_count`, `get_tab_count`, `get_icon`, `truncate_name`, `is_list`, `notify`, `save_positions`, `restore_positions`, `is_current_stable_release`

## Configuration

```lua
require("bufferline").setup({
    options = {
        mode = "buffers",           -- "buffers" or "tabs"
        style_preset = "default",   -- "default" | "minimal" | "no_bold" | "no_italic" (or a list)
        numbers = "none",           -- "none" | "ordinal" | "buffer_id" | "both" | function
        close_command = "bdelete! %d",
        right_mouse_command = "bdelete! %d",
        left_mouse_command = "buffer %d",
        middle_mouse_command = nil,
        indicator = { icon = "▎", style = "icon" },  -- style: "icon" | "underline" | "none"
        buffer_close_icon = "",
        modified_icon = "●",
        close_icon = "",
        left_trunc_marker = "",
        right_trunc_marker = "",
        max_name_length = 18,
        max_prefix_length = 15,
        tab_size = 18,
        truncate_names = true,
        color_icons = true,
        show_buffer_icons = true,
        show_buffer_close_icons = true,
        show_close_icon = true,
        show_tab_indicators = true,
        show_duplicate_prefix = true,
        duplicates_across_groups = true,
        enforce_regular_tabs = false,
        always_show_bufferline = true,
        auto_toggle_bufferline = true,
        persist_buffer_sort = true,
        move_wraps_at_ends = false,
        separator_style = "thin",   -- "slant" | "thick" | "thin" | "slope" | "padded_slant" | "padded_slope" | { '|', '|' }
        diagnostics = false,        -- "nvim_lsp" | "coc" | false
        diagnostics_update_in_insert = true,
        diagnostics_indicator = nil, -- function(count, level, diagnostics_dict, context)
        offsets = { { filetype = "NvimTree", text = "File Explorer", text_align = "left" } },
        hover = { enabled = false, delay = 200, reveal = {} },
        sort_by = "id",             -- "id" | "extension" | "directory" | "relative_directory" | "tabs" | "insert_after_current" | "insert_at_end" | "none" | function
        name_formatter = nil,       -- function(buf) return string
        get_element_icon = nil,     -- function(opts) return icon, highlight
        custom_filter = nil,        -- function(buf, bufnums) return boolean
        themable = true,
        groups = { items = {}, options = { toggle_hidden_on_enter = true } },
        custom_areas = { left = function() return {} end, right = function() return {} end },
        debug = { logging = false },
    },
    highlights = {
        -- Highlight group configuration (supports gradient colors via {highlight, attribute} tables)
        fill = { bg = "#1e1e2e" },
        background = { fg = "#65737e", bg = "#1e1e2e" },
        -- ... see :h bufferline-highlights for all valid highlight groups
    },
})
```

All configuration must be inside the `options` or `highlights` tables. Highlights can be a table or a function that receives the default highlights and returns a modified table.

## Dependencies

- **Required**: Neovim >= 0.7 (the plugin checks `vim.version().minor >= 0.7`)
- **Recommended**: `nvim-tree/nvim-web-devicons` (icon support; falls back to `vim-devicons` or no icons)
- **Optional**: LSP client (`nvim_lsp` or `coc`) for diagnostic indicators
- **Optional**: NvimTree or similar sidebar plugins (for offset integration)
- **Test dependencies**: `nvim-lua/plenary.nvim`, `nvim-tree/nvim-web-devicons` (loaded in `tests/minimal_init.lua`)

## Build / Test

- **Tests**: plenary.nvim + busted
  - Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua', sequential = true}"`
  - Test coverage: bufferline, config, groups, sorters, colors, highlights, numbers, offset, duplicates, ui, custom_area, utils
- **CI**: GitHub Actions (`ci.yaml`) - runs formatting, tests (on Neovim nightly), and release-please
- **Formatting**: stylua (`stylua.toml`) - 2-space indent, 120 column width, double quotes, collapse simple statements
- **Type checking**: `.luarc.json` (Lua Language Server config; disables `assign-type-mismatch`, `cast-local-type`, `missing-parameter` diagnostics)
- **Semantic PRs**: `contributing.yaml` enforces conventional commit PR titles

## Coding Conventions

- 2-space indentation, Unix line endings (configured in `stylua.toml`)
- Modules use the `local M = {}` pattern
- Lazy loading via `lazy.lua`'s `lazy.require()` to reduce startup overhead
- OOP style using metatables for `Config`, `Component`, `Buffer`, `Tabpage`, `Group`, `Section`, and `Context` classes
- EmmyLua annotations: `---@module`, `---@class`, `---@field`, `---@param`, `---@return`, `---@alias`, `---@enum`, `---@generic`, `---@type`, `---@deprecated`, `---@diagnostic disable`
- Use `vim.schedule` for deferred UI operations (e.g., `notify`, `redrawtabline`)
- Use `vim.F.if_nil` for optional value defaults
- Use `vim.tbl_deep_extend("force", ...)` for config merging
- Naming convention: module-level public functions use `M.FunctionName` (PascalCase), private functions use `local function name` (lowercase)
- Module boundary markers: `-----------------------------------------------------------------------------//` section separators
- Global state is stored in `state.lua`; click handlers are registered in `_G.___bufferline_private`
- Test-only exports are guarded by `if _G.__TEST then ... end` or `if utils.is_test() then ... end`
- Deprecations use `vim.deprecate` with a scheduled notification
