# hydra.nvim

## Project Overview

hydra.nvim is a Neovim implementation of the famous [Emacs Hydra](https://github.com/abo-abo/hydra) package. It lets users summon a set of related keybindings (heads) via a prefix key (body), then invoke those heads repeatedly without re-pressing the prefix. A hint (in a floating window, the cmdline, or the statusline) shows the available heads and their behavior. Maintained by the nvimtools organization (originally created by anuvyklack).

## Directory Structure

```
hydra.nvim/
├── lua/hydra/
│   ├── init.lua              # Hydra constructor & setup function
│   ├── statusline.lua        # Statusline integration (is_active/get_name/get_color/get_hint)
│   ├── health.lua            # :checkhealth implementation
│   ├── keymap-util.lua       # Keymap utility functions (cmd/pcmd)
│   ├── hint/                 # Hint system
│   │   ├── init.lua          # Hint factory (selects hint type from config)
│   │   ├── basehint.lua      # Hint base class
│   │   ├── parser.lua        # Parses hint strings (_, ^, %{val} syntax)
│   │   ├── cmdline.lua       # Cmdline hint (auto/manual)
│   │   ├── window.lua        # Floating-window hint (auto/manual)
│   │   ├── statusline.lua    # Statusline hint (auto/manual/mute)
│   │   └── vim-options.lua   # Built-in dynamic-value functions (%{func} syntax)
│   ├── layer/                # Layer system (used by Pink hydra)
│   │   ├── init.lua          # Layer class: keymap-layer management
│   │   ├── README.md
│   │   └── notes.md
│   └── lib/                  # Utility libraries
│       ├── class.lua         # Lightweight OOP class system
│       ├── meta-accessor.lua # vim.o/go/wo/bo meta-accessor (temp modify + restore)
│       ├── api-wrappers.lua  # Neovim API wrappers (Window/Buffer)
│       ├── highlight.lua     # Highlight utilities (HydraStatusLine* groups)
│       ├── deprecations.lua  # Deprecated-config migration
│       ├── types.lua         # Type annotations
│       └── util.lua          # General utilities (merge_config, termcodes, generate_id)
├── plugin/hydra.lua          # Sets up Hydra highlight groups on load
├── syntax/hydra_hint.vim     # Syntax highlighting for the hint window
├── doc/hydra.txt             # Vim help doc
├── CHANGELOG.md
└── CONTRIBUTING.md
```

## Core Modules

### `hydra.init` — Hydra constructor
- `Hydra(input)` — constructor; the input table accepts `name`, `mode`, `body`, `hint`, `config`, `heads`
- `Hydra:activate()` — programmatically activate the hydra
- `Hydra:exit()` — deactivate the hydra, restore options and highlights
- `Hydra.setup(opts)` — set global defaults applied to all subsequently created hydras

### Hydra config (`config`)
```lua
config = {
    debug = false,            -- enable debug output (vim.pretty_print)
    exit = false,             -- default exit value for every head
    foreign_keys = nil,       -- nil | "warn" | "run"
    color = "red",            -- "red" | "amaranth" | "teal" | "pink" | "blue"
    buffer = nil,             -- nil | true | bufnr  (make hydra buffer-local)
    invoke_on_body = false,   -- activate on body key alone (without a head)
    desc = nil,               -- description for the body keymap; defaults to name or "[Hydra]"
    on_enter = nil,           -- hook called on activation (meta-accessors available)
    on_exit = nil,            -- hook called before deactivation
    on_key = nil,             -- hook called after every head execution
    timeout = false,          -- false | true | number(ms); auto-disable after inactivity
    hint = false,             -- false | table  (hint config; false disables the hint)
}
```

`color` has higher precedence than `exit` + `foreign_keys`. If `color` is set, it overrides the other two.

### Heads
Each head has the form `{ lhs, rhs, opts }`:
- `lhs` — trigger key (string)
- `rhs` — command string | function | nil
- `opts` — optional table:
  - `private` (boolean) — head is only reachable while the hydra is active
  - `exit` (boolean) — exit the hydra after this head
  - `exit_before` (boolean) — exit the hydra *before* running this head
  - `on_key` (boolean, default true) — when false, skip `config.on_key` for this head
  - `desc` (string|false) — description shown in auto-generated hints; `false` hides the head
  - `expr` (boolean) — evaluate rhs as a Vim expression
  - `silent` (boolean) — silent mapping
  - `nowait` (boolean) — for Pink hydras, skip timeout and fire immediately
  - `remap` (boolean) — if true, rhs is remapped; otherwise it is non-recursive (default)
  - `mode` (string|string[]) — override the hydra's mode for this head

If no exit head is provided, `<Esc>` is bound automatically to exit.

### Colors system
| Color     | exit | foreign_keys | Non-head key behavior      | Head behavior          |
|-----------|------|--------------|----------------------------|------------------------|
| red       | false| nil          | Exit + execute            | Continue               |
| blue      | true | nil          | Exit + execute            | Exit                   |
| amaranth  | false| "warn"       | Block + continue          | Continue               |
| teal      | true | "warn"       | Block + continue          | Exit                   |
| pink      | false| "run"        | Execute + continue (Layer)| Continue (Layer-based) |

Each head is rendered either "reddish" (continue) or "blueish" (exit) in the hint.

### `hydra.hint` — Hint system
The factory in `hint/init.lua` picks a hint class based on config:

| Config                              | Class used            |
|-------------------------------------|-----------------------|
| `config.hint == false`              | `HintStatusLineMute`  |
| manual hint string + `type="window"`| `HintManualWindow`    |
| manual hint + `type="statusline"`   | `HintManualStatusLine`|
| manual hint + `type="statuslinemanual"`| `HintStatusLineMute` |
| manual hint + other type            | `HintManualCmdline`   |
| auto hint + `type="cmdline"`        | `HintAutoCmdline`     |
| auto hint + `type="statusline"`     | `HintAutoStatusLine`  |
| auto hint + `type="window"`         | `HintAutoWindow`      |

Hint string syntax:
- `_text_` — highlighted as a head key
- `^` — alignment placeholder (consumed before rendering)
- `%{func}` — dynamic value; calls a function from `config.hint.funcs` (or built-ins)

Hint config table:
```lua
hint = {
    type = "window",          -- "window" | "cmdline" | "statusline" | "statuslinemanual"
    position = "bottom",      -- "top" | "middle" | "bottom", optionally + "-left"/"-right"
    offset = 0,               -- offset from the nearest editor border
    float_opts = { },         -- passed to nvim_open_win() (border, style, etc.)
    show_name = true,         -- show hydra name in auto-generated hints
    hide_on_load = false,     -- don't show the hint window immediately on activation
    funcs = {},               -- name -> fun():string  for %{name} dynamic values
}
```

### `hydra.layer` — Layer class (Pink hydra)
- Organizes keymaps into three lists: `enter`, `layer`, `exit`
- Saves and restores any overridden keymaps on enter/exit
- Supports buffer-local and global modes
- Uses `vim.keymap.set` and `BufEnter`/`WinEnter` autocommands
- Public methods: `layer:activate()`, `layer:exit()`
- Only one layer can be active at a time; `_G.active_keymap_layer` holds the current one

### `hydra.lib.meta-accessor` — Meta-accessor
- Wraps `vim.o` / `vim.go` / `vim.bo` / `vim.wo`
- Records original values on first write; call `:restore()` to revert
- In `on_enter`, writes are allowed; in `on_exit`, writes are disabled (read-only)
- Buffer/window options use autocommands to re-apply on BufEnter/WinEnter

### `hydra.lib.class` — OOP class system
- `class(parent)` creates a new class; supports an `initialize` constructor
- Metatable `__call` enables `ClassName(args)` construction syntax

### `hydra.keymap-util` — Keymap utilities
- `cmd(command)` — wraps a string as `<Cmd>command<CR>`
- `pcmd(try_cmd, catch?, catch_cmd?)` — returns a `<Cmd>try | ... | catch ... | endtry<CR>` string

### `hydra.statusline` — Statusline integration
- `is_active()` — boolean: is a hydra currently active?
- `get_name()` — name of the active hydra (or nil)
- `get_color()` — color name of the active hydra (or nil)
- `get_hint()` — returns a statusline hint string when `config.hint == false` or `type == "statuslinemanual"` / `"statusline"`

### `hydra.lib.highlight` — Highlight utilities
- Creates `HydraStatusLine{Red,Blue,Amaranth,Teal,Pink}` groups by blending each `Hydra<Color>` with `StatusLine`

### `hydra.lib.api-wrappers` — Neovim API wrappers
- `Window` — window object with `wo` meta-accessor, `set_buffer`, `close`, `set_config`
- `Buffer` — buffer object with `bo` meta-accessor, `set_lines`, `add_highlight`, `delete`

### `hydra.lib.deprecations` — Deprecation handling
- `util.deprecate(option, date, migrator, hint)` registers a deprecated config path
- `util.process_deprecations(config)` walks a config and runs any applicable migrations
- Currently migrates `hint.border` → `hint.float_opts.border`

## Configuration Example

```lua
local Hydra = require('hydra')

-- Set global defaults
require('hydra').setup({
    debug = false,
    hint = { show_name = true, position = { "bottom" }, offset = 0 },
})

-- Create a Hydra
Hydra({
    name = "Window",
    mode = "n",
    body = "<C-w>",
    hint = [[
  ^ ^     Move      ^ ^     Size
  _h_ _j_ _k_ _l_   _+_ _-_
  ^ ^               _<_ _>_]],
    config = {
        exit = false,
        color = "amaranth",
        invoke_on_body = true,
    },
    heads = {
        { "h", "<C-w>h" },
        { "j", "<C-w>j" },
        { "+", "<C-w>+", { desc = "increase height" } },
        { "q", nil, { exit = true, desc = "quit" } },
    },
})
```

## How it works internally

Non-pink hydras are implemented as an infinite chain of `<Plug>(Hydra<ID>_wait)` mappings:
- Red (continue) heads: `<Plug>(..._wait)` + lhs → run rhs + `<Plug>(..._wait)`
- Blue (exit) heads: `<Plug>(..._wait)` + lhs → run rhs + `<Plug>(..._exit)`
- `<Plug>(..._wait)` alone → `<Plug>(..._leave)`, which checks the color and either exits or re-waits

Pink hydras use the Layer system instead, so unbound keys keep working (including `[count]`).

See `CONTRIBUTING.md` for a more detailed walkthrough.

## Dependencies

- **Requires**: Neovim only. `HydraFooter` highlight requires Neovim 0.10+.
- **No external runtime dependencies.**

## Build / Release

- **Docs**: generated with [panvimdoc](https://github.com/kdheepak/panvimdoc) (`.github/workflows/panvimdoc.yml`)
- **Releases**: managed with release-please (`.github/workflows/release-please.yaml`)
- **Tests**: no automated test suite currently exists

## Coding Conventions

- **Language**: pure Lua
- **OOP**: custom class system (`hydra.lib.class`); constructor method is named `initialize`
- **Naming**: classes are PascalCase (`Hydra`, `Layer`, `MetaAccessor`); functions are camelCase
- **Type annotations**: full `---@class` / `---@field` / `---@param` annotations in `lib/types.lua`
- **Highlight groups**: `HydraRed`, `HydraBlue`, `HydraAmaranth`, `HydraTeal`, `HydraPink`, `HydraHint`, `HydraBorder`, `HydraTitle`, `HydraFooter`, plus `HydraStatusLine{Color}` for statusline hints
- **Global state**: `_G.Hydra` holds the active hydra; `_G.active_keymap_layer` holds the active layer
- **Validation**: `vim.validate` is used in the constructor to check input
- **Deprecations**: handled through `lib/deprecations.lua` with automatic migration
