# numb.nvim

## Project Overview

numb.nvim is a lightweight Neovim plugin that **previews the target line non-intrusively** when the user types a `:{number}` command. When you type `:3`, the window temporarily scrolls to the target line so you can see its content before pressing Enter; the original window state is restored if you cancel.

- **Author:** nacro90 (MIT License)
- **Core features:**
  - Live line preview while typing a command
  - Supports relative line-number expressions (`+3`, `-2`, `++--+5`)
  - Non-intrusive: restores original window position and options when the command is cancelled

## Directory Structure

```
numb.nvim/
├── README.md              # Installation and usage documentation
├── LICENSE                # MIT license
├── lua-format             # Config for the `lua-format` CLI tool
├── stylua.toml            # Stylua formatting config (120 columns, 2-space indent, no call parentheses)
└── lua/
    └── numb/
        ├── init.lua       # Public API and core logic
        └── log.lua        # Logging module (based on rxi/log.lua)
```

The entire plugin consists of two Lua files. There is no `plugin/`, `tests/`, or CI directory.

## Core Modules

### `lua/numb/init.lua` — Main entry point

Returns the `numb` table, the public interface of the plugin.

| Function | Description |
|---|---|
| `numb.setup(user_opts)` | Initializes the plugin: merges user options, registers the `CmdlineChanged` / `CmdlineLeave` autocommands |
| `numb.on_cmdline_changed()` | `CmdlineChanged` handler: parses the number/symbols on the command line and calls peek/unpeek |
| `numb.on_cmdline_exit()` | `CmdlineLeave` handler: restores window state; stays on the preview line if the command was not aborted |
| `numb.disable()` | Clears window state and destroys the `numb` augroup |

**Internal functions (local, not exported):**

- `save_win_state(states, winnr)` — Saves cursor position, tracked window options, and `topline`
- `set_win_options(winnr, options)` — Batch-sets window options
- `peek(winnr, linenr)` — Saves state and scrolls to the preview line (clamps line to `[1, n_buf_lines]`)
- `unpeek(winnr, stay)` — Restores original window state; `stay=true` keeps the preview line, unfolds it (`zv`), and re-centers
- `is_peeking(winnr)` — Returns whether the window is currently in preview state
- `parse_num_str(str)` — Parses a signed number string into an absolute line number (via `load("return " .. str)()`)

**Module-level state:**

- `win_states` — Table mapping window numbers to their saved states
- `peek_cursor` — Stores the peek position so `unpeek(stay=true)` can restore it

### `lua/numb/log.lua` — Logging module

Standalone logging utility returning a `log` table. Supports `trace` / `debug` / `info` / `warn` / `error` / `fatal` levels and corresponding `fmt_*` formatted variants. Provides a `log.new(config, standalone)` factory function.

- Default log level is `"warn"` (debug/trace are silent)
- Log prefix is `'numb'`
- Logs to the Neovim console (`use_console = true`) via `echom`
- Log file path is `vim.fn.stdpath('data') .. '/numb.log'` (e.g. `~/.local/share/nvim/data/numb.log`)
- **Note:** `log.new` always resets `config = default_config`, ignoring the passed config — the logging module is not user-configurable

## Configuration Options

Configured via `require('numb').setup { ... }`:

| Option | Default | Type | Description |
|---|---|---|---|
| `show_numbers` | `true` | bool | Enable `'number'` while peeking |
| `show_cursorline` | `true` | bool | Enable `'cursorline'` while peeking |
| `hide_relativenumbers` | `true` | bool | Disable `'relativenumber'` while peeking |
| `number_only` | `false` | bool | Only preview when the entire command is a number/signs (anchors the match with `$`) |
| `centered_peeking` | `true` | bool | Center the previewed line (`normal! zz`) |

**Tracked window options** (saved and restored): `number`, `cursorline`, `foldenable`, `relativenumber`.

Options are merged with `vim.tbl_extend("force", opts, user_opts or {})`. `disable()` clears `win_states` and the augroup but does **not** reset `opts`, so a later `setup()` reuses the previously set options.

## Dependencies

- **No external dependencies** — relies only on the Neovim Lua standard library (`vim.api`, `vim.fn`, `vim.cmd`, `vim.tbl_extend`, etc.)
- `log.lua` is an embedded standalone logging module (derived from rxi/log.lua, modified by tjdevries), not a separate plugin dependency

## Build / Test

- No test directory, no CI configuration
- Code is formatted with **Stylua** (config in `stylua.toml`): 120-column width, 2-space indent, no call parentheses
- `lua-format` is a separate config file for the `lua-format` CLI tool

## Coding Conventions

- `snake_case` naming throughout (functions, variables, options)
- Public functions are attached to the `numb` table; private functions are `local`
- API aliases: `local api = vim.api`, `local cmd = api.nvim_command`
- Internal function comments use `---` LuaDoc style
- The autocommand group is named `numb`, matching the plugin name
- Initialization flow: `setup()` → create augroup → register `CmdlineChanged` / `CmdlineLeave` → event-driven peek/unpeek

## Notes

- `parse_num_str` uses `load("return " .. str)()` to dynamically evaluate command-line input. Input is constrained by the pattern `^([%+%-%d]+)`, so the risk is minimal but worth noting.
- `on_cmdline_changed` calls `unpeek(winnr, false)` before peeking to reset any prior preview state, then redraws.
- `on_cmdline_exit` checks `vim.api.nvim_get_vvar("event").abort` to decide whether to stay on the preview line.
- `log.new` always resets to `default_config`, ignoring the passed config — the logging module is not user-configurable.
