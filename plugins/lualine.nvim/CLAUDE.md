# CLAUDE.md — lualine.nvim

## Project Overview

**lualine.nvim** is a blazing-fast, easy-to-configure Neovim statusline written in Lua. It supports three display areas — statusline, tabline, and winbar — with per-filetype extensions and a large collection of built-in themes.

- Requires Neovim >= 0.7 (winbar requires >= 0.8, on_click requires >= 0.8)
- Only loads the components the user specifies — no unnecessary initialization
- Configured via `require('lualine').setup { ... }`

## Directory Structure

```
lualine.nvim/
├── lua/
│   ├── lualine.lua            # Entry module: setup / refresh / hide / statusline / winbar / tabline
│   ├── lualine_require.lua    # Custom require: lazy loading, path resolution, plugin directory detection
│   └── lualine/
│       ├── config.lua          # Default config + apply_configuration / get_config
│       ├── component.lua       # Component base class (parent of all components)
│       ├── highlight.lua       # Highlight group management, transitional separator highlights, color utils
│       ├── components/         # Built-in components (mode, branch, diagnostics, diff, ...)
│       │   ├── special/        # Internal components: function_component / eval_func_component / vim_var_component
│       │   ├── branch/         # Multi-file component example (init.lua + git_branch.lua)
│       │   ├── buffers/        # Multi-file component (init.lua + config.lua)
│       │   ├── diagnostics/    # Multi-file component (init.lua + config.lua + sources.lua)
│       │   ├── diff/           # Multi-file component (init.lua + git_diff.lua)
│       │   ├── tabs/           # Multi-file component (init.lua + config.lua)
│       │   ├── windows/        # Multi-file component (init.lua + config.lua)
│       │   └── *.lua           # Single-file components
│       ├── extensions/         # Filetype extensions (trouble, nvim-tree, fugitive, ...)
│       ├── themes/             # Built-in themes (gruvbox, nord, dracula, auto, ...)
│       └── utils/              # Utility modules
│           ├── class.lua       # Minimal OOP base class (classic style)
│           ├── loader.lua      # Component / extension / theme loader
│           ├── section.lua     # Section drawing logic (draw_section)
│           ├── utils.lua       # deepcopy / is_focused / stl_escape / define_autocmd / ...
│           ├── color_utils.lua # Color conversion (rgb/cterm/color_name)
│           ├── fn_store.lua    # Mouse click callback registry
│           ├── job.lua         # Async job wrapper
│           ├── mode.lua        # Vim mode code → mode name mapping
│           ├── nvim_opts.lua   # vim.opt cache and restore
│           └── notices.lua     # Startup notice collection
├── tests/
│   ├── minimal_init.lua        # Minimal vim config for tests (loads plenary + devicons)
│   ├── helpers.lua             # Test helpers
│   ├── statusline.lua          # Statusline test utility class (expect matching)
│   └── spec/
│       ├── config_spec.lua     # Config parsing tests
│       ├── component_spec.lua  # Component behavior tests
│       ├── lualine_spec.lua    # Main flow tests (largest)
│       └── utils_spec.lua      # Utility function tests
├── scripts/
│   ├── test_runner.sh          # Test launcher (headless nvim + plenary)
│   ├── docgen.sh               # Generate doc/lualine.txt from README (panvimdoc)
│   └── nvim_isolated_conf.sh   # Isolated config script
├── doc/lualine.txt             # Auto-generated vim docs
├── examples/                   # Custom theme examples (evil_lualine, slanted-gaps, bubbles)
├── CONTRIBUTING.md             # Contribution guide
├── Makefile                    # lint / format / test / testcov / docgen / check
├── .stylua.toml                # Stylua formatting config
└── .luacheckrc                 # Luacheck config
```

## Core Modules

### `lua/lualine.lua` — Entry & Runtime

Exported table:

```lua
M = {
  setup = setup,           -- Apply config, load components/extensions/themes, register autocommands
  statusline = ...,        -- Function produced by status_dispatch('sections')
  tabline = tabline,       -- Returns tabline string
  winbar = ...,            -- Function produced by status_dispatch('winbar')
  get_config = ...,        -- Returns a deep copy of the current config
  refresh = refresh,       -- Force refresh (scope: all/tabpage/window)
  hide = hide,             -- Hide/restore lualine
}
```

Key internal functions:

- `apply_transitional_separators(status, is_focused)` — Replaces `%z{sep}` / `%Z{sep}` placeholders with transitional separator highlights
- `statusline(sections, is_focused, is_winbar)` — Concatenates sections a→z, handles middle separator `%=` and truncation `%<`
- `status_dispatch(sec_name)` — Closure that selects extension sections or default sections based on filetype
- `setup_theme()` — Loads theme, creates highlight groups, registers `ColorScheme` and `OptionSet background` autocommands
- `refresh(opts)` — Core refresh logic; handles focus tracking, window iteration, and timers. Defers autocmd-triggered refreshes to timer context to avoid Neovim redraw bugs
- `set_statusline / set_tabline / set_winbar` — Sets `&statusline` / `&tabline` / `&winbar`, starts timers and autocommands
- `hide(opts)` — Hides or restores lualine segments. Options: `place` (statusline/tabline/winbar), `unhide` (boolean)
- `verify_nvim_version()` — Returns true if Neovim >= 0.7

### `lua/lualine/component.lua` — Component Base Class

All components inherit from `Component` (OOP based on `utils/class.lua`).

Key methods:

- `M:init(options)` — Initializes component_no, sets up separator, highlights, on_click
- `M:update_status(is_focused)` — **Must be overridden by subclasses**, returns a string
- `M:draw(default_highlight, is_focused)` — Driver method: checks `cond` → `update_status` → `fmt` → icon → padding → on_click → highlights → section separators → separator
- `M:create_hl(color, hint)` — Creates a private highlight group for the component
- `M:strip_separator()` — Removes trailing empty separator
- `M:set_separator()` — Sets default separator based on section position (left vs right of middle)
- `M:set_on_click()` — Registers on_click callback (requires nvim >= 0.8)
- `M:apply_padding()` — Applies left/right padding (respects leading highlight)
- `M:apply_highlights(default_highlight)` — Applies custom color highlight and default highlight bookends
- `M:apply_icon()` — Prepends/appends icon with optional color highlight and alignment
- `M:apply_section_separators()` — Wraps component with `%z{sep}` / `%Z{sep}` transitional separator markers
- `M:format_fn(id, str)` — Wraps string with mouse click format for on_click callback

Component options: `icon`, `separator`, `cond`, `color`, `padding`, `fmt`, `on_click`, `draw_empty`, `type`.

### `lua/lualine/config.lua` — Configuration Management

- Built-in default config (`config` table) containing `options`, `sections`, `inactive_sections`, `tabline`, `winbar`, `inactive_winbar`, `extensions`
- `apply_configuration(user_config)` — Merges user config, normalizes separator format, expands `disabled_filetypes`
- `get_current_config()` — Returns a deep copy of the current config

Note: `globalstatus` defaults to `vim.go.laststatus == 3` (i.e., enabled if the user already set `laststatus=3`), not `false`.

### `lua/lualine/highlight.lua` — Highlight System

- Maintains `loaded_highlights` table tracking all highlight groups created by lualine
- `create_highlight_groups(theme)` — Creates `lualine_{section}_{mode}` highlight groups from theme definition
- `create_component_highlight_group(color, hint, options)` — Creates highlight for component `color` option
- `get_transitional_highlights(left_hl, right_hl)` — Creates transitional separator highlight group
- `format_highlight(section_name, is_focused)` — Returns `%#lualine_X_mode#` format string
- `get_mode_suffix()` — Returns `_normal` / `_insert` / `_visual` / `_replace` / `_command` / `_terminal` based on current vim mode
- `get_stl_default_hl(is_focused)` — Returns the default statusline highlight for focused/unfocused state
- `component_format_highlight(highlight, is_focused)` — Formats a component highlight token for stl use
- Color handling: `sanitize_color`, `color_name2rgb`, `cterm2rgb`, `get_lualine_hl`, `highlight_exists`

### `lua/lualine/utils/loader.lua` — Loader

- `component_loader(component)` — Dispatches to different loading strategies based on component type:
  - `custom` — Table with function as first element; calls it directly
  - `lua_fun` — Lua function component
  - `mod` — Built-in module component (`lualine.components.xxx`)
  - `stl` — Vim statusline expression (`%f`, `%m`, etc.)
  - `var` — Vim variable/option (`g:`, `b:`, `bo:`, `go:`, etc.)
  - `_` — Vim function / Lua expression
- `load_all(config)` — Resets component counter, clears fn store and nvim_opts cache, loads all sections and extensions
- `load_theme(theme_name)` — Loads theme from runtime path; prioritizes user config path over bundled themes

### `lua/lualine/utils/section.lua` — Section Drawing

`draw_section(section, section_name, is_focused)`:

- Iterates components calling `draw`
- Strips trailing empty separators
- Removes adjacent separators when custom color changes background
- Inserts transitional separators (`%z` / `%Z`) at section boundaries
- Returns the final section string

### `lua/lualine/utils/class.lua` — OOP Base Class

Minimal classic-style class system: `Object:extend()`, `Object:new(...)`, `Object:init(...)`.

### `lua/lualine/utils/fn_store.lua` — Callback Registry

Provides id → function mapping for `on_click` callbacks. Callbacks are injected into statusline via `%*%d@v:lua.require'lualine.utils.fn_store'.call_fn@`.

### `lua/lualine/utils/nvim_opts.lua` — Option Cache

Caches and restores `statusline`, `tabline`, `winbar`, `laststatus`, `showtabline`, and other options. Supports global / buffer / window scope. Used by `hide()` to restore original options.

### `lua/lualine/utils/mode.lua` — Mode Mapping

`Mode.map` maps vim mode codes (`n`, `i`, `v`, `R`, `c`, `t`, etc.) to readable names (NORMAL, INSERT, VISUAL, etc.). `Mode.get_mode()` returns the current mode name.

### `lua/lualine/utils/job.lua` — Async Job Wrapper

Wraps `vim.fn.jobstart` with `start`, `stop`, and `wrap_cb_alive` methods. Used by components like `branch` and `diff` for async git operations.

### `lua/lualine/utils/notices.lua` — Startup Notices

Collects notices during setup and displays them at startup via `:LualineNotices` command and `vim.notify`. Supports both regular notices (cleared on each `setup()` call) and persistent notices.

### `lua/lualine_require.lua` — Custom Require

- `M.require(module)` — Loads module from lualine's own directory first, then falls back to runtime path
- `M.lazy_require(modules)` — Returns a metatable that lazily requires modules on first access
- `M.is_valid_filename(name)` — Validates that a filename contains only safe characters
- `M.sep` — Platform path separator

## Configuration

```lua
require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'auto',                    -- Theme name / theme table / function
    component_separators = { left = '', right = '' },
    section_separators = { left = '', right = '' },
    disabled_filetypes = { statusline = {}, winbar = {} },
    ignore_focus = {},
    always_divide_middle = true,
    globalstatus = vim.go.laststatus == 3,  -- Global statusline (nvim 0.7+)
    refresh = { statusline = 1000, tabline = 1000, winbar = 1000 },
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff', 'diagnostics' },
    lualine_c = { 'filename' },
    lualine_x = { 'encoding', 'fileformat', 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
  inactive_sections = { ... },
  tabline = { ... },
  winbar = { ... },
  inactive_winbar = { ... },
  extensions = { 'trouble', 'nvim-tree', ... },
}
```

Component formats:

- String: `'mode'` — built-in component
- Function: `function() return 'text' end` — custom Lua function
- Table with options: `{ 'diagnostics', sources = { 'nvim_diagnostic' } }`
- Vim function: `{ 'FugitiveHead', type = 'vim_fun' }`
- Vim variable: `'g:coc_status'`, `'bo:filetype'`
- Vim statusline: `'%f'`, `'%m'`
- Lua expression: `{ "os.date('%a')", type = 'lua_expr' }`

Extension format:

```lua
local my_ext = {
  sections = { lualine_a = { 'mode' } },
  inactive_sections = { ... },  -- optional
  winbar = { ... },             -- optional
  inactive_winbar = { ... },    -- optional
  filetypes = { 'lua' },
  init = function() ... end,    -- optional initialization
}
require('lualine').setup { extensions = { my_ext } }
```

## Dependencies

### Runtime Dependencies

- **Neovim >= 0.7** (required)
- **nvim-web-devicons** (optional, for icon display)

### Dev / Test Dependencies

- **plenary.nvim** — Test framework (plenary.busted / plenary.test_harness)
- **nvim-web-devicons** — Loaded during tests
- **luacheck** — Linting
- **stylua** — Formatting
- **luacov + luacov-console** — Coverage
- **panvimdoc + pandoc** — Doc generation

## Build / Test

### Tests

Tests require `plenary.nvim` and `nvim-web-devicons` to be in the same parent directory as this repo.

```bash
make test            # Run all tests
make testcov         # Run with coverage (requires luacov + luacov-console)
bash scripts/test_runner.sh tests/spec/config_spec.lua  # Run a single test file
```

Test launch command: `nvim --headless -u tests/minimal_init.lua -c "set rtp+=$(pwd)" ...`

### Lint & Format

```bash
make lint            # luacheck lua/ tests/ examples/
make format          # stylua lua/ examples/
make check           # lint + test
make precommit_check # docgen + format + test + lint
```

### Doc Generation

```bash
make docgen          # Generate doc/lualine.txt from README.md (requires pandoc)
```

Do not manually edit `doc/lualine.txt` — it is auto-generated by CI.

## Coding Conventions

### Style

- **Indentation**: 2 spaces (Stylua config)
- **Quotes**: Single quotes preferred (`AutoPreferSingle`)
- **Parentheses**: No omitting parens for single-table arg calls (`call_parentheses = "NoSingleTable"`)
- **Line width**: Not enforced (luacheck ignores 631)
- **Formatter**: Stylua (`.stylua.toml`)

### Naming Conventions

- Module export table: uppercase `M` (`local M = {}`)
- Component files: lowercase single-file `mode.lua` or multi-file directory `branch/init.lua`
- Highlight group naming: `lualine_{section}_{mode}` (e.g., `lualine_a_normal`)
- Transitional highlight: `lualine_{left_hl}_to_{right_hl}`
- Component private highlight: `{component_name}_{hint}`
- Private functions: `local function` or underscore prefix within module

### Component Development Guide

1. Inherit from `lualine.component`: `local M = require('lualine.component'):extend()`
2. Override `M.init(self, options)` and call `M.super.init(self, options)`
3. Override `M.update_status(self, is_focused)` to return a string
4. Use `lualine_require.lazy_require { ... }` for lazy dependency loading
5. Use `modules.utils.stl_escape()` to escape `%` in output

### Comments & Types

- EmmyLua-style annotations: `---@param name string`, `---@return boolean`
- Copyright header at top of each module: `-- Copyright (c) 2020-2021 hoob3rt / shadmansaleh`

### Luacheck Rules

- Global whitelist: `vim`, `assert`
- Unused `self` ignored (`self = false`)
- Unused `_`-prefixed args ignored (`212/_.*`)
- Line width not checked (`631`)

### Pre-commit Check

Run `make precommit_check` to ensure docs, formatting, tests, and lint all pass.

## Public API Summary

| Function | Description |
|---|---|
| `require('lualine').setup(config)` | Apply configuration, load components/extensions/themes |
| `require('lualine').statusline()` | Returns the statusline string (used internally by `&statusline`) |
| `require('lualine').tabline()` | Returns the tabline string |
| `require('lualine').winbar()` | Returns the winbar string |
| `require('lualine').get_config()` | Returns a deep copy of the current config |
| `require('lualine').refresh(opts)` | Force refresh. Options: `scope` (all/tabpage/window), `place` (statusline/tabline/winbar) |
| `require('lualine').hide(opts)` | Hide/restore lualine. Options: `place` (statusline/tabline/winbar), `unhide` (boolean) |

## User-Facing Commands

- `:LualineBuffersJump N` — Jump to buffer at index N in the buffers component (defined in `components/buffers/init.lua`)
- `:LualineRenameTab [name]` — Set or clear the name of the current tabpage (defined in `components/tabs/init.lua`)
- `:LualineNotices` — Open a buffer showing config warnings/notices (defined in `utils/notices.lua`)
