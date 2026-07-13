# nvim-notify

## Project Overview

nvim-notify is a fancy, configurable notification manager for Neovim. It replaces the default `vim.notify` with animated, stylized notification windows supporting multiple render styles, animation stages, history tracking, and picker integrations.

**Design inspiration:** Originally based on [sunjon](https://github.com/sunjon)'s [design proposal](https://neovim.discourse.group/t/wip-animated-notifications-plugin/448).

## Directory Structure

```
nvim-notify/
├── LICENSE
├── README.md
├── Dockerfile                  # Docker config for testing
├── .releaserc.json             # Semantic release configuration
├── stylua.toml                 # Code formatting config (column_width=100, 2-space indent)
├── doc/                        # Vim help documentation
├── scripts/
│   ├── docgen/                 # Documentation generation tools
│   ├── gendocs.lua             # Docs generation entry script
│   └── style/                  # Style/linting scripts
│   └── test/                   # Test scripts
├── tests/
│   ├── init.vim                # Test bootstrap
│   ├── unit/
│   │   └── init_spec.lua       # Unit tests (plenary.busted)
│   └── manual/
│       └── merge_duplicates.lua # Manual test for duplicate merging
├── lua/
│   ├── notify/
│   │   ├── init.lua            # Main module, public API
│   │   ├── instance.lua        # Notification instance creation/management
│   │   ├── config/
│   │   │   ├── init.lua        # Configuration definition and validation
│   │   │   └── highlights.lua  # Highlight group definitions
│   │   ├── animate/
│   │   │   ├── init.lua        # Animation scheduler
│   │   │   └── spring.lua      # Spring physics animation
│   │   ├── stages/
│   │   │   ├── init.lua        # Animation stages entry (lazy-loaded)
│   │   │   ├── fade.lua        # Fade animation
│   │   │   ├── slide.lua       # Slide animation
│   │   │   ├── slide_out.lua   # Slide-out only animation
│   │   │   ├── fade_in_slide_out.lua  # Fade in + slide out (default)
│   │   │   ├── static.lua      # No initial movement, just timer
│   │   │   ├── no_animation.lua # No animation (instant, repositions for stacking)
│   │   │   └── util.lua        # Stage utility functions (slots, directions)
│   │   ├── render/
│   │   │   ├── init.lua        # Renderer entry (lazy-loaded)
│   │   │   ├── base.lua        # Base renderer (namespace setup)
│   │   │   ├── default.lua     # Default renderer
│   │   │   ├── minimal.lua     # Minimal renderer
│   │   │   ├── simple.lua      # Simple renderer
│   │   │   ├── compact.lua     # Compact renderer
│   │   │   ├── wrapped-default.lua  # Wrapped default renderer
│   │   │   └── wrapped-compact.lua  # Wrapped compact renderer
│   │   ├── service/
│   │   │   ├── init.lua        # Notification service (queue management, animation loop)
│   │   │   ├── notification.lua # Notification object
│   │   │   └── buffer/
│   │   │       ├── init.lua    # Notification buffer rendering logic
│   │   │       └── highlights.lua  # Highlight management for notification buffers
│   │   ├── windows/
│   │   │   └── init.lua        # Window animator
│   │   ├── integrations/
│   │   │   ├── init.lua        # Integration entry (dispatches to telescope/fzf-lua)
│   │   │   └── fzf.lua         # fzf-lua integration
│   │   └── util/
│   │       ├── init.lua        # General utilities (blend, FIFOQueue, win helpers)
│   │       └── queue.lua       # FIFO queue implementation
│   └── telescope/
│       └── _extensions/
│           └── notify.lua      # Telescope extension
└── .github/                    # CI/CD workflows
```

## Core Modules

### `notify` (lua/notify/init.lua)

Main module providing the public API:

- **`notify.setup(user_config)`** — Configure nvim-notify, create the global instance. Also registers `:Notifications` and `:NotificationsClear` commands and loads the Telescope extension if available.
- **`notify.notify(message, level, opts)`** — Send a notification (synchronous). Returns `notify.Record`.
- **`notify.async(message, level, opts)`** — Send a notification asynchronously using `plenary.async`. Returns `notify.AsyncRecord` with `events.open()`/`events.close()` awaitables. Must be called inside an async context.
- **`notify.history(opts)`** — Get records of all previous notifications. Returns `notify.Record[]`.
- **`notify.clear_history()`** — Clear all history records.
- **`notify.dismiss(opts)`** — Dismiss all currently-displayed notification windows. Accepts `opts.pending` (clear queued) and `opts.silent` (suppress confirmation).
- **`notify.open(notif_id, opts)`** — Open a notification in a standalone buffer. Returns `notify.OpenedBuffer`.
- **`notify.pending()`** — Get the number of notifications waiting to be displayed.
- **`notify.instance(user_config, inherit)`** — Create an independent instance with its own configuration, windows, and history. Defaults to inheriting the global config. The returned instance exposes the same functions as the notify module.
- **`notify._config()`** — Get the resolved global config object.
- **`notify._print_history()`** — Internal. Used by the `:Notifications` command to print history to the echo area.

The module is directly callable via `__call`:
```lua
require("notify")("Hello", "info", { title = "Greeting" })
```

If called inside a fast event or during startup, the call is deferred via `vim.schedule`.

### Notification Options (`notify.Options`)

Per-notification options passed as the third argument to `notify` / `notify.async`:

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Title text |
| `icon` | string | Icon override |
| `timeout` | number\|boolean | Timeout in ms. `false` disables timeout, `true` uses default |
| `on_open` | function(win) | Callback when the window opens |
| `on_close` | function(win) | Callback when the window closes |
| `keep` | function(): bool | Return true to keep the notification open after timeout |
| `render` | function\|string | Custom renderer or built-in renderer name |
| `replace` | integer\|notify.Record | Replace an existing open notification by id. Unset fields are inherited from the replaced notification |
| `hide_from_history` | boolean | Exclude this notification from history |
| `animate` | boolean | If `false`, skip to the timed stage instantly (useful for blocking flows like `vim.fn.input`) |

### Notification Records

```
notify.Record = {
  id: integer,
  message: string[],
  level: string | integer,
  title: string[],     -- [left, right]
  icon: string,
  time: number,        -- vim.fn.localtime()
  render: function,
}
```

`notify.AsyncRecord` extends `notify.Record` with:
```
events: { open: function, close: function }   -- plenary oneshot channels
```

`notify.OpenedBuffer` (returned by `notify.open`):
```
{ buffer: integer, height: integer, width: integer,
  highlights: { body: string, border: string, title: string, icon: string } }
```

### `notify.instance` (lua/notify/instance.lua)

Creates and manages a notification instance. Each instance holds:
- A resolved config (via `config.setup`)
- A `WindowAnimator`
- A `NotificationService`
- A notification list (used for `history()` and `replace`)

Supports:
- Replacing open notifications (`opts.replace`)
- Merging duplicate notifications (`merge_duplicates` config)
- Independent `notify()`, `notify.async()`, `open()`, `history()`, `dismiss()`, `pending()`, `clear_history()`
- The instance itself is also callable via `__call`

### `notify.config` (lua/notify/config/init.lua)

Configuration definition and validation. Default config:

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `level` | string\|number | `vim.log.levels.INFO` | Minimum display level |
| `timeout` | number | `5000` | Default timeout in ms |
| `max_width` | number\|function\|nil | `nil` | Max columns (supports callable for dynamic values) |
| `max_height` | number\|function\|nil | `nil` | Max lines (supports callable) |
| `stages` | string\|function[] | `"fade_in_slide_out"` | Animation stages |
| `render` | string\|function | `"default"` | Renderer |
| `background_colour` | string | `"NotifyBackground"` | Background color (group name, hex string, or function). Required for opacity stages. Falls back to `#000000` if no bg is found. |
| `on_open` | function\|nil | `nil` | Window-open callback |
| `on_close` | function\|nil | `nil` | Window-close callback |
| `minimum_width` | number | `50` | Minimum window width |
| `fps` | number | `30` | Animation framerate |
| `top_down` | boolean | `true` | Top-down (true) or bottom-up (false) stacking |
| `merge_duplicates` | boolean\|number | `true` | Merge duplicates. If a number, minimum duplicate count before merging |
| `time_formats` | table | `{ notification_history = "%FT%T", notification = "%T" }` | `strftime` formats |
| `icons` | table | `{ ERROR = "", WARN = "", INFO = "", DEBUG = "", TRACE = "✎" }` | Icons for each level |

If `termguicolors` is unset and the stages require opacity (fade / fade_in_slide_out) on Neovim < 0.10, stages fall back to `static` with a warning.

### `notify.windows` (lua/notify/windows/init.lua)

`WindowAnimator` manages:
- Window lifecycle (open, update, close)
- Animation stage progression (`win_stages[win]`)
- Spring-based animation via the `animate.spring` module
- Opacity transitions using highlight blending (`notify.background_colour` becomes the base blend color)
- Timer management via `vim.loop.new_timer()` to drive the "timed" stage that waits for `timeout`

### `notify.service` (lua/notify/service/init.lua)

`NotificationService` manages:
- A FIFO queue of pending notifications (`notify.util.FIFOQueue`)
- The animation loop, driven through `vim.defer_fn` at intervals of `1000 / fps` ms
- `push`, `replace`, `dismiss`, and `pending` operations

### `notify.service.buffer` (lua/notify/service/buffer/)

`NotificationBuf` wraps a Neovim buffer with a notification record and renders it using the configured renderer. Manages per-buffer highlight groups and opacity.

### `notify.stages.*`

Each stage module exports a function that takes a direction and returns an array of stage functions:

1. **First function (init):** Receives `{ message, open_windows }`. Returns a table of `nvim_open_win` options (may include `opacity` 0-100). Return `nil` if the notification cannot be displayed right now.
2. **Subsequent functions (animation):** Also receive the `win` id. They return goal values for `{ col, row, height, width, opacity }`. Numbers jump instantly; tables animate via a dampened spring. The `time = true` field marks the "waiting" stage (drives the timeout).
3. **Final stage:** Once the last stage's goals are reached, the window is closed.

Built-in stages:
- `fade` — fade in/out
- `slide` — slide in/out
- `slide_out` — slide in / slide out
- `fade_in_slide_out` — fade in + slide out (default)
- `static` — no movement, just a timer
- `no_animation` — instant appearance, then repositions to stack properly on the next stage

Each stage function is lazy-loaded through `notify/stages/init.lua` via `__index`.

Spring goal fields: `{ goal_value, damping?, frequency?, complete? }`.

### `notify.render.*`

Renderers draw notification content into a buffer. Each render function has the signature:
```
fun(buf: integer, notification: notify.Record, highlights: notify.Highlights, config)
```

Built-in renderers: `default`, `minimal`, `simple`, `compact`, `wrapped-compact`, `wrapped-default`.

Loaded lazily through `notify/render/init.lua` via `__index`. The `base` module only creates the `nvim-notify` namespace.

### `notify.util` / `notify.util.queue`

General utilities: color blending, window config helpers, `lazy_require`, `FIFOQueue`, `open_win`, etc.

### `notify.integrations` (lua/notify/integrations/init.lua)

`pick()` dispatches to `telescope` or `fzf-lua`. The `fzf.lua` module provides the fzf-lua picker UI.

### Telescope Extension (lua/telescope/_extensions/notify.lua)

Registers the `notify` extension, exposing `Telescope notify`. Uses `time_formats().notification` for list display. The `init.lua` at the top level wires this up when a picker is invoked.

### Commands Added by `setup()`

- `:Notifications` — Print notification history to the echo area (`notify._print_history`)
- `:NotificationsClear` — Clear history (`notify.clear_history`)

## Highlights

Naming scheme: `Notify<LEVEL><SECTION>`. Levels: `ERROR`, `WARN`, `INFO`, `DEBUG`, `TRACE`. Sections: `Border`, `Body`, `Title`, `Icon`.

Default highlights (defined in `lua/notify/config/highlights.lua`):
- `Notify<LEVEL>Border` — colored foregrounds
- `Notify<LEVEL>Icon` — colored foregrounds
- `Notify<LEVEL>Title` — colored foregrounds
- `Notify<LEVEL>Body` — linked to `Normal`
- `NotifyBackground` — linked to `Normal` (used as the base for opacity blending)
- `NotifyLogTime` — linked to `Comment` (used by the `:Notifications` log)
- `NotifyLogTitle` — linked to `Special` (used by the `:Notifications` log)

Highlight definitions are refreshed on `ColorScheme` changes. Custom levels fall back to `INFO` highlights unless defined by the user.

## Dependencies

- **Required:**
  - Neovim >= 0.5 (uses `vim.api`, extmarks, floating windows, `vim.loop`, `vim.log.levels`)
- **Optional:**
  - [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) — required for `notify.async`
  - [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) — history picker
  - [fzf-lua](https://github.com/ibhagwan/fzf-lua) — alternative history picker

## Installation & Setup

```lua
require("notify").setup {
  timeout = 3000,
  stages = "fade_in_slide_out",
  render = "default",
  background_colour = "#000000",
  top_down = true,
}

-- Replace default vim.notify
vim.notify = require("notify")
```

For opacity stages, set `vim.opt.termguicolors = true`.

## Basic Usage

```lua
vim.notify("This is an error", "error")
vim.notify("Update", "info", { title = "Plugin", timeout = 2000 })

-- Async usage with plenary
local async = require("plenary.async")
local notify = require("notify").async
async.run(function()
  notify("Waiting...").events.close()
  notify("Done!")
end)

-- treesitter highlighting in notifications
vim.notify(text, "info", {
  title = "Plugin",
  on_open = function(win)
    local buf = vim.api.nvim_win_get_buf(win)
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  end,
})

-- History
local history = require("notify").history()
require("notify").history({ include_hidden = true })
```

## Testing

Tests use `plenary.busted`. Run with:
```bash
nvim --headless -c "PlenicBustedDirectory tests/ { minimal_init = './tests/init.vim' }"
```

## Code Style

- Formatted with `stylua` (config in `stylua.toml`): column width 100, 2-space indent, Unix line endings, double quotes preferred
- Lua module pattern (`local M = {}`)
- OO-style classes via `__index` metatables
- Async callbacks wrapped with `vim.schedule_wrap`
- Timer-driven animation loop via `vim.defer_fn` and `vim.loop.new_timer()`
- FIFO queue for pending notification scheduling
- `"force"` table merges for user config overrides; `"keep"` for default-preserving extension
