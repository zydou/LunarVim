# alpha-nvim — CLAUDE.md

## Project Overview

alpha-nvim is a fast, fully programmable Neovim startup greeter (start screen). It is
fundamentally a general-purpose Neovim UI library with a declarative, data-driven API for
building welcome screens. Themes are expressed entirely as data structures, which makes the
plugin "fully programmable". Built-in themes include `dashboard`, `startify`, and `theta`.

## Directory Structure

```
alpha-nvim/
├── lua/
│   ├── alpha.lua                        # Main module: rendering engine, API, setup
│   ├── alpha/
│   │   ├── fortune.lua                  # Random fortune-quote footer component
│   │   ├── term.lua                     # Terminal preview layout element (alpha.layout_element.terminal)
│   │   └── themes/
│   │       ├── dashboard.lua            # Classic dashboard theme
│   │       ├── startify.lua             # vim-startify style theme
│   │       └── theta.lua                # Theta theme (depends on plenary.nvim)
├── doc/alpha.txt                        # Vim help docs (definitive config spec)
├── debug/
│   ├── DEBUG.md
│   ├── min-alpha-dashboard.lua          # Minimal dashboard debug config
│   └── min-alpha-startify.lua           # Minimal startify debug config
├── CONTRIBUTING.md
├── LICENSE
├── README.md
└── stylua.toml                          # Lua formatting config (4-space indent, 120 col width)
```

## Core Modules

### `alpha` (`lua/alpha.lua`)

Main module exposing the rendering engine and the public API.

#### Rendering Engine

Table-driven renderer dispatching on `el.type`:

- **`layout_element.text`** — static text element. `val` accepts `string`, `string[]`, or `function`.
- **`layout_element.padding`** — inserts `val` blank lines (number or function returning number).
- **`layout_element.button`** — interactive button with `shortcut`, `on_press`, cursor jump,
  and highlight options (`hl`, `hl_shortcut`).
- **`layout_element.group`** — composes child elements, supports `spacing` between items and
  `inherit` opts (extended into child opts unless child has higher `priority`).
- **`alpha.resolve(to, el, opts, state)`** — resolves lazy (`val` is function) elements by
  calling `el.val()` and re-dispatching.

Keymaps are applied via a parallel `keymaps_element` table. `text` and `padding` are no-ops;
`button` sets buffer-local keymaps; `group` recurses into children.

Internal functions:

- **`layout(conf, state)`** — writes layout text and highlights into the buffer.
- **`keymaps(conf, state)`** — attaches keymaps for the layout.
- **`enable_alpha(conf, state)`** — sets buffer-local options, creates the `alpha_temp`
  augroup, and registers `BufUnload`, `WinClosed`, `CursorMoved`, and resize autocmds.
- **`should_skip_alpha()`** — returns true when a file argument is passed, the buffer already
  has content, other listed buffers are visible, `-M` mode is set, or blacklisted argv
  flags (`-b`, `-c`, `+…`, `-S`) are present. `--startuptime` is whitelisted.

#### Public API

- **`alpha.setup(config)`** — entry point. Validates `config.layout`, merges defaults
  (`autostart`, `keymap.press`, `keymap.queue_press`), stores `alpha.default_config`,
  registers the `Alpha`, `AlphaRedraw`, and `AlphaRemap` user commands, and hooks `VimEnter`
  to auto-start.
- **`alpha.start(on_vimenter, conf?)`** — opens the greeter. When `on_vimenter` is true it
  reuses the current buffer (after `should_skip_alpha()` checks); otherwise it creates a new
  buffer. Sets up keymaps, calls `enable_alpha`, draws, fires `User AlphaReady`, and applies
  element keymaps.
- **`alpha.draw(conf, state)`** — clears and redraws the entire layout into the buffer.
- **`alpha.redraw(conf?, state?)`** — re-render; when called with no args it looks up the
  current buffer's state from `alpha_state`.
- **`alpha.close(ev)`** — tears down an instance: removes state, resets cursor tracking,
  deletes the augroup, and fires `User AlphaClosed`.
- **`alpha.press()`** — executes the `on_press` of the button under the cursor, plus any
  queued presses.
- **`alpha.queue_press(state)`** — toggles the current button into/out of the press queue
  (multi-select via `<M-CR>`) and draws a `*` marker.
- **`alpha.move_cursor(window)`** — snaps the cursor to the nearest button jump point when
  navigating with arrow keys.
- **`alpha.align_center(tbl, state)`** — centers lines using `bit.arshift(win_width - longest, 1)`.
- **`alpha.pad_margin(tbl, state, margin, shrink)`** — left-pads lines by `margin`; when
  `shrink` is true the margin shrinks to avoid overflow.
- **`alpha.highlight(state, end_ln, hl, left, el)`** — converts hl specs into
  `nvim_buf_add_highlight` tuples. Accepts a highlight group string or an array of
  `{group, start_col, end_col}` (2-D array for multi-line).
- **`alpha.handle_window(x)`** — `WinClosed` autocmd handler that updates the instance's
  window list.

#### Internal State

- `alpha_state` — map of `buffer -> state` (per-instance state table).
- `cursor_ix` / `cursor_jumps` / `cursor_jumps_press` / `cursor_jumps_press_queue` —
  module-level cursor tracking globals.

#### Exposed Tables

- `alpha.layout_element` — the layout dispatch table (extended by `term.lua`).
- `alpha.keymaps_element` — the keymap dispatch table (extended by `term.lua`).

### Themes

Themes are pure data — they return a config table of the form:

```lua
{
    layout = {
        { type = "padding", val = 2 },
        { type = "text", val = "Header", opts = { hl = "Title", position = "center" } },
        { type = "group", val = { ... }, opts = { spacing = 1 } },
        { type = "button", val = "New file", shortcut = "n",
          on_press = function() ... end,
          opts = { hl_shortcut = "Keyword", position = "center", keymap = {...} } },
    },
    opts = { margin = 5, noautocmd = false, redraw_on_resize = true,
             setup = function() ... end },
}
```

#### `alpha.themes.dashboard`

Classic dashboard layout: header ASCII art, button group, footer. Exports `button`,
`section`, `config`, `leader` (default `"SPC"`), and deprecated alias `opts = config`.

#### `alpha.themes.startify`

vim-startify style: header, top buttons, MRU (global), MRU (cwd-filtered), bottom buttons,
footer. Exports `icon`, `button`, `file_button`, `mru`, `mru_opts`, `section`, `config`,
`nvim_web_devicons`, `leader`, and deprecated alias `opts = config`. Redraw on resize is
disabled by default; a `DirChanged` autocmd triggers redraw + remap.

#### `alpha.themes.theta`

Theta theme: header, recent-files section, quick-links button group. **Soft-depends on
`plenary.nvim`** (`plenary.path`) for path shortening — the module returns early (no config)
if plenary is not installed. Exports `header`, `buttons`, `mru`, `config`, `mru_opts`,
`leader`, `nvim_web_devicons`. Also registers a `DirChanged` redraw autocmd.

### `alpha.fortune` (`lua/alpha/fortune.lua`)

Returns a function that selects a random quote from a built-in `fortune_list` and word-wraps
it to `max_width` (default 54). Usage:

```lua
dashboard.section.footer.val = require("alpha.fortune")()
```

Options: `max_width` (number) or a table `{ max_width = N, fortune_list = {...} }`.

### `alpha.term` (`lua/alpha/term.lua`)

Registers the `terminal` layout element. `alpha.layout_element.terminal` opens a floating
terminal window running `el.command` (string or function) and occupies `el.height` lines in
the layout. `alpha.keymaps_element.terminal` is a no-op. The terminal is torn down on
`User AlphaClosed`. Must be required **after** `alpha` so it can mutate
`alpha.layout_element`.

## Configuration

```lua
require("alpha").setup(require("alpha.themes.dashboard").config)
-- or
require("alpha").setup(require("alpha.themes.startify").config)
-- or
require("alpha").setup(require("alpha.themes.theta").config)
```

### Top-Level Config

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `layout` | `table` | **yes** | Ordered list of layout elements (top to bottom). |
| `opts` | `table` | no | Theme/global options (see below). |

### `opts`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `autostart` | `boolean` | `true` | Auto-open on `VimEnter`. |
| `keymap.press` | `string \| string[]` | `"<CR>"` | Key(s) to press the focused button. |
| `keymap.queue_press` | `string \| string[]` | `"<M-CR>"` | Key(s) to queue a button press (multi-select). |
| `margin` | `number` | `0` | Horizontal padding on non-centered elements. |
| `noautocmd` | `boolean` | `false` | Use `noautocmd` when setting buffer options (skips `FileType`). |
| `redraw_on_resize` | `boolean` | `true` | Redraw on window resize. Uses `WinResized` on NVIM >= 0.11, otherwise `VimResized` + `BufLeave`/`WinEnter`/`WinNew`/`WinClosed` + width-checking `CursorMoved`. |
| `setup` | `function` | `nil` | Callback run once before the first draw. |

### Layout Element Types

| Type | Required fields | Key `opts` |
|------|-----------------|------------|
| `text` | `val` (string / string[] / function) | `position` ("left" / "center"), `hl` |
| `padding` | `val` (number / function) | — |
| `button` | `val`, `on_press` | `position`, `shortcut`, `align_shortcut` ("left"/"right"), `hl`, `hl_shortcut`, `cursor`, `width`, `shrink_margin`, `keymap` |
| `group` | `val` (table / function) | `spacing`, `inherit`, `priority` |
| `terminal` | `command` (string / function), `width`, `height` | `redraw`, `window_config` |

`hl` accepts a group name string or an array of `{group, start_col, end_col}` sections
(2-D array for multi-line elements).

### Theme-Specific Options

- `leader` (dashboard/theta): string substituted for `"SPC"` in button keymaps (default `"SPC"`).
- `mru_opts` (startify/theta): `{ ignore = function(path, ext): boolean, autocd: boolean }`.
- `nvim_web_devicons` (startify/theta): `{ enabled: boolean, highlight: boolean | string }`.

### User Commands

- `:Alpha` — open the greeter manually (`alpha.start(false)`).
- `:AlphaRedraw` — redraw the current instance.
- `:AlphaRemap` — re-apply element keymaps for the current buffer.

### Autocmds

- `User AlphaReady` — fired after the first draw completes.
- `User AlphaClosed` — fired when the alpha buffer is unloaded.

## Dependencies

- **Hard dependencies:** none.
- **Soft dependencies:**
  - `nvim-tree/nvim-web-devicons` — icons in MRU entries and buttons (startify, theta, dashboard).
  - `nvim-lua/plenary.nvim` — required by the `theta` theme for path shortening. The theme
    returns early (no config) if plenary is unavailable.
- **Upstream inspiration:** `glepnir/dashboard-nvim`, `mhinz/vim-startify`.
- **Consumed by:** user configurations as a startup greeter.

## Build / Test

- No build step (pure Lua plugin).
- No automated test suite.
- Manual testing via the minimal configs in `debug/`.
- Formatting: `stylua lua/` (4-space indent, 120-column width, double quotes, no call parens).

## Code Conventions

- 4-space indentation (see `stylua.toml` and `.editorconfig`).
- Main module uses `local alpha = {}`; sub-modules use `local M = {}`.
- Table-driven design: dispatch tables (`layout_element`, `keymaps_element`) indexed by
  `el.type` strings — a form of pattern matching.
- Module-level globals for cross-call state (`alpha_state`, `cursor_ix`, `cursor_jumps`, etc.).
- `vim.F.if_nil` for optional-value defaults.
- `vim.tbl_extend("keep", ...)` to merge configs while preserving user-supplied values.
- `vim.deepcopy` to clone elements before resolving lazy values (avoids mutation side effects).
- `bit.arshift` for center-alignment arithmetic.
- `---@param` / `---@return` annotations on public helper functions.
- `---@diagnostic disable-next-line: unused-local` where API shape requires unused params.
- `-- stylua: ignore start` / `-- stylua: ignore end` around large option-setting blocks.
