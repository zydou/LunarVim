# glow.nvim

## Project Overview

glow.nvim is a Neovim plugin that preview Markdown files directly inside the Neovim terminal. It is based on [charmbracelet/glow](https://github.com/charmbracelet/glow) — a command-line Markdown renderer — and displays styled Markdown output in a floating window without leaving the editor.

Main features:
- Preview the current Markdown buffer in a floating window via `:Glow`
- Preview a specific file via `:Glow <path>`
- Close the floating window via `:Glow!`
- Close the window with the `q` or `<Esc>` keys
- Automatically download and install the glow binary if not found on `PATH`
- Configurable window size, border, style (dark/light), and pager mode

---

## Directory Structure

```
glow.nvim/
├── LICENSE                        # MIT license
├── README.md                      # Project documentation
├── Makefile                       # Test build
├── .gitignore
├── .stylua.toml                   # Formatting configuration
├── doc/
│   └── glow.nvim.txt              # Vim help document
├── lua/
│   └── glow.lua                   # Main entry module (contains all plugin logic)
├── tests/
│   ├── minimal_init.lua           # Minimal test init file
│   └── glow/
│       ├── glow_spec.lua          # Test specs
│       └── TEST.md                # Markdown file used by tests
└── .github/
    ├── workflows/
    │   ├── default.yml            # CI tests
    │   ├── release.yml            # Release workflow
    │   └── docs.yml               # Docs generation
    └── ISSUE_TEMPLATE/
        └── bug_report.md          # Issue template
```

---

## Core Module

### `glow` (single main module)

All glow.nvim logic lives in the single file `lua/glow.lua`.

Exposed API:
- `glow.setup(params)` — configure the plugin (merge user config with defaults), create the `:Glow` user command
- `glow.execute(opts)` — main execution function (triggered by `:Glow`), handles the bang argument, checks the Neovim version, kicks off the glow flow
- `glow.config` — reference to the current configuration

### Internal functions (locals)

| Function | Responsibility |
|------|------|
| `cleanup()` | Delete the temporary file |
| `err(msg)` | Display an error via `vim.notify` |
| `safe_close(h)` | Safely close a libuv handle |
| `stop_job()` | Stop the running glow process |
| `close_window()` | Close the floating window (stop process, cleanup temp file, close window) |
| `tmp_file()` | Create a temporary Markdown file from the current buffer |
| `open_window(cmd_args)` | Create the floating window and launch the glow process to display output |
| `release_file_url()` | Build the glow binary download URL based on OS and architecture |
| `is_md_ft()` | Check whether the current buffer has a supported Markdown filetype |
| `is_md_ext(ext)` | Check whether a file extension is a supported Markdown extension |
| `run(opts)` | Main run logic: validate the glow binary, check the file type, launch the process |
| `install_glow(opts)` | Download and install the glow binary to `install_path` |
| `get_executable()` | Resolve the glow executable path |
| `create_autocmds()` | Create the `:Glow` user command |

---

## Configuration

### Installation

```lua
-- lazy.nvim
{"ellisonleao/glow.nvim", config = true, cmd = "Glow"}

-- packer.nvim
use {"ellisonleao/glow.nvim", config = function() require("glow").setup() end}

-- vim-plug
Plug 'ellisonleao/glow.nvim'
lua << EOF
require('glow').setup()
EOF
```

### Default configuration

```lua
require('glow').setup({
  glow_path = "",                -- auto-detected from PATH via vim.fn.exepath("glow")
  install_path = "~/.local/bin", -- glow binary installation path
  border = "shadow",             -- floating window border style
  style = "dark|light",          -- auto-filled from vim.o.background
  pager = false,                 -- whether to use pager mode
  width = 100,                   -- floating window width
  height = 100,                  -- floating window height
})
```

Note: `width_ratio` and `height_ratio` are not part of the default config table. They are referenced with a fallback of `0.7` inside `open_window` (via `glow.config.width_ratio or 0.7`) and can be overridden by the user, but they are not declared fields on the `Config` class.

### Custom configuration

```lua
require('glow').setup({
  style = "dark",
  width = 120,
  border = "rounded",
})
```

### Commands

- `:Glow` — preview the current Markdown buffer (no-op if the window is already open)
- `:Glow <path>` — preview the specified file
- `:Glow!` — close the current preview window

The `:Glow` user command is created with `{ complete = "file", nargs = "?", bang = true }`.

### Key mappings

Inside the preview window:
- `q` — close the window
- `<Esc>` — close the window

---

## Dependencies

### Required

- **Neovim >= 0.8.0** — version is checked at startup
- **[glow](https://github.com/charmbracelet/glow)** — Charmbracelet's command-line Markdown renderer
  - If glow is not on `PATH`, the plugin auto-downloads and installs it to `install_path`
  - `curl` and `tar` are required for download and installation

### Optional

None.

### Reverse dependencies

glow.nvim is a standalone terminal plugin and is not typically depended on by other plugins.

---

## Build / Test

### Tests

```bash
make test
```

Tests use the busted framework from [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).

Test files:
- `tests/glow/glow_spec.lua` — tests `setup()` with default and custom configs
- `tests/glow/TEST.md` — Markdown file used by tests
- `tests/minimal_init.lua` — minimal test init configuration

### Code style

Configured via `.stylua.toml`:

```toml
column_width = 120
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
no_call_parentheses = false
```

### CI

GitHub Actions workflows:
- `default.yml` — run tests
- `release.yml` — publish to LuaRocks
- `docs.yml` — generate documentation

---

## Coding Conventions

### Style

- Follow `.stylua.toml` (2-space indentation, `AutoPreferDouble` quotes, call parentheses always present)
- Use **2-space indentation**
- Use **double quotes** preferred (`AutoPreferDouble`)
- Always use parentheses in function calls (`no_call_parentheses = false`)

### Naming

- Module is a local table: `local glow = {}`
- Config fields use snake_case: `glow_path`, `install_path`, `width_ratio`
- Local functions use snake_case: `close_window`, `tmp_file`, `open_window`
- Type aliases use PascalCase: `Config`, `Glow`

### Type annotations

LuaCATS annotations are used throughout:
- `---@class` — class definition
- `---@field` — field definition
- `---@alias` — type alias
- `---@param` / `---@return` — parameter / return types
- `---@type` — variable type declaration

### Error handling

- Errors are reported via `vim.notify(msg, vim.log.levels.ERROR, { title = "glow" })`
- Executable existence is checked before use: `vim.fn.executable(path) == 0`
- File readability is checked before operations: `vim.fn.filereadable(file)`

### Process management

- `vim.loop.spawn` launches the glow process
- `vim.loop.new_pipe` creates stdout/stderr pipes
- `vim.api.nvim_open_term` renders terminal output in the buffer
- On process exit, the `on_exit` callback calls `stop_job()` and `cleanup()`
- The download step in `install_glow` uses `vim.fn.jobstart` (not `vim.loop.spawn`)

### Temporary files

- Created with `vim.fn.tempname() .. ".md"`
- Written via `vim.fn.writefile` from the current buffer's lines
- Removed by `cleanup()` on window close or process exit

### Window management

- Floating window created via `vim.api.nvim_open_win`
- Window options: `style = "minimal"`, `relative = "editor"`, `border = glow.config.border`
- Buffer options: `bufhidden = "wipe"`, `filetype = "glowpreview"`
- Window option: `winblend = 0`
- Size calculation: based on `width_ratio` / `height_ratio` (default `0.7`), capped by `width` / `height` when set

### Auto-install

- When glow is not on `PATH`, it is downloaded from GitHub releases
- The download URL is built from `vim.loop.os_uname().sysname` and `jit.arch`
- Hardcoded version: `1.5.1`
- Supported OSes: Windows, Linux, Darwin, Freebsd
- Supported architectures: i386, x86_64, arm7, arm64

### Filetype detection

Supported Markdown filetypes:
- `markdown`
- `markdown.pandoc`
- `markdown.gfm`
- `wiki`
- `vimwiki`
- `telekasten`

Supported Markdown file extensions:
- `md`, `markdown`, `mkd`, `mkdn`, `mdwn`, `mdown`, `mdtxt`, `mdtext`, `rmd`, `wiki`
