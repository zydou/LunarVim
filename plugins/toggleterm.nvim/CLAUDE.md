# toggleterm.nvim

## Overview

A Neovim plugin for creating and managing multiple toggleable terminal windows. Supports multiple layouts (horizontal/vertical split, float, tab), allows users to define named terminals, and quickly switch between them.

- **Author**: akinsho
- **License**: GPL-3.0
- **Requirement**: Neovim >= 0.7

## Directory Structure

```
toggleterm.nvim/
├── lua/
│   ├── toggleterm.lua              # Entry module, public API (M.setup, M.toggle, M.exec, M.send_lines_to_terminal, etc.)
│   └── toggleterm/
│       ├── terminal.lua            # Terminal class, terminal lifecycle management (Terminal:new, toggle, open, close, send)
│       ├── config.lua              # Configuration management, ToggleTermConfig type definition and defaults
│       ├── ui.lua                  # Window/buffer UI management (open split, float, tab; highlights; winbar)
│       ├── commandline.lua         # Command-line argument parsing (TermExec cmd='...' dir=... syntax)
│       ├── constants.lua           # Constants (FILETYPE, shading_amount, highlight_group_name_prefix)
│       ├── colors.lua              # Color utilities (shade_color, get_hex, color_is_bright, is_bright_background, set_hl)
│       ├── utils.lua               # General utilities (notify, key_map, git_dir, wo_setlocal, etc.)
│       └── lazy.lua                # Lazy require wrapper (load-on-demand)
├── doc/
│   └── toggleterm.txt              # Vim help document
├── tests/                          # plenary.nvim-based tests
│   ├── minimal_init.lua            # Test bootstrap config
│   ├── terminal_spec.lua
│   ├── commandline_spec.lua
│   ├── command-complete_spec.lua
│   └── state_spec.lua
├── .luarc.json                     # sumneko-lua language server config
├── stylua.toml                     # Formatting config (100 columns, double quotes)
├── README.md
└── CHANGELOG.md
```

## Core Modules

### `toggleterm` (Entry)

| Function | Description |
|----------|-------------|
| `M.setup(user_prefs)` | Initialize plugin: set config, global mappings, autocmds, user commands |
| `M.toggle(count, size, dir, direction, name)` | Toggle terminal visibility |
| `M.exec(cmd, num, size, dir, direction, name, go_back, open)` | Execute command in terminal |
| `M.toggle_all(force)` | Toggle all terminals |
| `M.exec_command(args, count)` | `:TermExec` command implementation |
| `M.send_lines_to_terminal(...)` | Send current/visual lines to terminal |
| `M.toggle_command(args, count)` | `:ToggleTerm` command implementation |

**Smart toggle behavior**: When no count is given, `M.toggle` uses `smart_toggle` — if any terminal window is open, all are closed and their state is saved; if none are open, the saved view is restored. When a count is given, only that specific terminal is toggled.

### `toggleterm.terminal` (Terminal class)

Core class. Each terminal instance is a `Terminal` object stored in the module-level `terminals` table.

| Method | Description |
|--------|-------------|
| `Terminal:new(args)` | Create new terminal (reuse if ID already exists) |
| `Terminal:toggle(size, direction)` | Toggle open/close |
| `Terminal:open(size, direction)` | Open terminal window (split/float/tab) |
| `Terminal:close()` | Close window |
| `Terminal:send(cmd, go_back)` | Send command to terminal |
| `Terminal:spawn()` | Create background terminal job |
| `Terminal:shutdown()` | Fully close and delete |
| `Terminal:change_dir(dir, go_back)` | Change terminal directory |
| `Terminal:set_mode(m)` | Set INSERT/NORMAL mode |
| `Terminal:clear()` | Send clear/clr command |
| `Terminal:scroll_bottom()` | Scroll to bottom |
| `Terminal:focus()` | Focus terminal window |
| `Terminal:is_focused()` | Check if terminal is focused |
| `Terminal:is_open()` | Check if terminal window is open |
| `Terminal:is_float()` | Check if terminal is floating |
| `Terminal:is_split()` | Check if terminal is split |
| `Terminal:is_tab()` | Check if terminal is tab |
| `Terminal:resize(size)` | Resize split terminal |
| `Terminal:persist_mode()` | Save current mode to state |

| Module Function | Description |
|-----------------|-------------|
| `M.identify(name)` | Parse terminal ID from buffer name |
| `M.get_or_create_term(num, dir, direction, name)` | Get or create terminal |
| `M.get(id, include_hidden)` | Get terminal by ID |
| `M.get_all(include_hidden)` | Get all terminals (sorted) |
| `M.find(predicate)` | Find terminal by predicate |
| `M.get_toggled_id(position)` | Get ID of Nth open terminal |
| `M.get_focused_id()` | Get currently focused terminal ID |
| `M.get_last_focused()` | Get last focused terminal |
| `M.Terminal` | Exported Terminal class for user extension |

### `toggleterm.config`

Defines `ToggleTermConfig` class (with type annotations). `M.set(user_conf)` deep-merges config and computes highlights. `M.get(key)` reads config value. Uses `__index` metamethod so the module is directly accessible as a config table.

### `toggleterm.ui`

Window layout management core.

- **Split layout**: `open_split`, `resize_split` (exports); `close_split` is a local function using `split_commands` table for direction-related vim commands
- **Float window**: `open_float`, `update_float`, `_get_float_config` (supports row/col/width/height as numbers or functions)
- **Tab page**: `open_tab` (export); `close_tab` is a local function
- **State preservation**: `save_terminal_view` / `open_terminal_view` / `close_and_save_terminal_view` implement smart-toggle
- **Highlights**: `hl_term` creates per-terminal highlight groups (`ToggleTerm<id><group>`)
- **Winbar**: `set_winbar` / `winbar` implement clickable terminal switch bar (requires Neovim 0.8+ nightly)
- **Size persistence**: `save_window_size` / `save_direction_size` / `has_saved_size` / `get_size` handle `persist_size` behavior

### `toggleterm.commandline`

Parses command-line style arguments. `M.parse(args)` handles `cmd='git commit' dir=~/proj size=20 direction=float name=myterm` format. Also provides `term_exec_complete` and `toggle_term_complete` completion functions, and `get_path_parts` for path completion.

### `toggleterm.colors`

Color utilities: `shade_color` (lighten/darken hex color), `get_hex` (get highlight group color), `color_is_bright` (check if color is bright), `is_bright_background` (check if background is bright), `set_hl` (set highlight group).

### `toggleterm.constants`

Constants: `FILETYPE = "toggleterm"`, `shading_amount = -30`, `highlight_group_name_name_prefix = "ToggleTerm"`.

### `toggleterm.utils`

General utilities: `notify`, `key_map`, `git_dir`, `wo_setlocal`, `get_line_selection`, `get_visual_selection`, `is_nightly`, `str_is_empty`, `concat_without_empty`, `tbl_filter_empty`.

### `toggleterm.lazy`

Lazy require wrapper using `setmetatable` to defer module loading until first index access.

## Configuration

```lua
require("toggleterm").setup {
  size = 12,                                  -- Default split terminal size (number or function)
  open_mapping = [[<c-\>]],                    -- Global toggle mapping (string or array of strings)
  hide_numbers = true,                        -- Hide line numbers
  shade_filetypes = {},                       -- Only shade these filetypes (allowlist)
  shade_terminals = true,                     -- Shade terminal background
  shading_factor = -30,                       -- Shading factor (multiplied by -3 if background is light)
  start_in_insert = true,                     -- Start in insert mode
  insert_mappings = true,                     -- Respond to open_mapping in insert mode
  terminal_mappings = true,                   -- Respond to open_mapping in terminal mode
  persist_size = true,                        -- Persist split size
  persist_mode = true,                        -- Persist insert/normal mode
  direction = "horizontal",                   -- Default direction
  close_on_exit = true,                       -- Close window when process exits
  shell = vim.o.shell,                        -- Shell to use (string or function)
  auto_scroll = true,                         -- Auto-scroll to bottom
  autochdir = false,                          -- Follow vim directory changes
  float_opts = {
    winblend = 0,                             -- Window transparency
    title_pos = "left",                       -- Float window title position
    border = "single",                        -- Border style ("curved" is custom)
    width = <number|function>,                -- Float width
    height = <number|function>,               -- Float height
    row = <number|function>,                  -- Float row position
    col = <number|function>,                  -- Float column position
    zindex = <number>,                        -- Float z-index
    relative = "editor",                      -- Relative position
  },
  winbar = {
    enabled = false,                          -- Enable winbar (requires 0.8+)
    name_formatter = fn,                      -- Custom name formatter
  },
  highlights = {},                            -- Custom highlight groups
  on_create = fun(t: Terminal),               -- Called when terminal is first created
  on_open = fun(t: Terminal),                 -- Called when terminal opens
  on_close = fun(t: Terminal),                -- Called when terminal closes
  on_stdout = fun(t, job, data, name),        -- Stdout callback
  on_stderr = fun(t, job, data, name),        -- Stderr callback
  on_exit = fun(t, job, exit_code, name),     -- Process exit callback
  env = {},                                   -- Environment variables for jobstart()
  clear_env = false,                          -- Use clean job environment
}
```

### User Commands

| Command | Description |
|---------|-------------|
| `:ToggleTerm [args]` | Toggle terminal (supports size/dir/direction/name args) |
| `:TermExec cmd='...'` | Execute command in terminal |
| `:ToggleTermToggleAll` | Toggle all terminals |
| `:ToggleTermSendVisualLines` | Send visual lines to terminal |
| `:ToggleTermSendVisualSelection` | Send visual selection to terminal |
| `:ToggleTermSendCurrentLine` | Send current line to terminal |
| `:ToggleTermSetName [name]` | Set terminal name |
| `:TermSelect` | Interactively select terminal |

### Global Variables

- `_G.IS_TEST`: Enables extra debug methods in test mode (e.g., `__reset`)
- `_G.___toggleterm_winbar_click(id)`: Winbar click callback

## Dependencies

### Runtime Dependencies

No hard dependencies. Optional:
- `plenary.nvim` — Testing framework
- `nvim-treesitter` — Referenced in some README examples

### Used By

- Many users use `toggleterm` with `lazy.nvim` for lazy loading
- Commonly used as terminal management core in editor configs

## Build / Test

```bash
# Run tests (requires plenary.nvim)
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

Formatting uses **stylua** (100 column width, double quotes, always collapse simple statements).

## Coding Conventions

- **Language**: Lua, targeting Neovim >= 0.7 API; some features require 0.8+ (e.g., WinBar)
- **Code style**: stylua formatting, 100 columns, double quotes, always collapse simple statements
- **Naming**: Module export table uses `M` (uppercase); public functions use `PascalCase` or `snake_case`; private functions use `__` prefix (e.g., `__spawn`, `__set_options`, `__make_output_handler`); `@package` visibility for semi-private methods
- **Type annotations**: EmmyLua style `---@class`, `---@field`, `---@param`, `---@alias`
- **Lazy loading**: Via `lazy.lua`'s `setmetatable` for on-demand require (config/ui/colors/etc.)
- **Cross-platform**: `is_windows` and `is_nightly` handle OS differences; `get_newline_chr` handles shell differences (cmd/pwsh/nushell/bash)
