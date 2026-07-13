# which-key.nvim

## Project Overview

A Neovim plugin that displays a popup with possible key bindings when the user starts typing a key sequence. Supports automatic trigger detection, grouping, built-in plugins (marks/registers/spelling/presets), deferred loading, and rich visual customization.

- **Author**: folke
- **License**: Apache-2.0
- **Requirement**: Neovim >= 0.5.0 (with feature detection for 0.6 and 0.7 APIs)

## Directory Structure

```
which-key.nvim/
├── lua/which-key/
│   ├── init.lua                    # Entry module: setup/load/register/show/show_command/execute/reset
│   ├── config.lua                  # Options class definition and defaults
│   ├── keys.lua                    # Core engine: mapping tree, hook system, function mappings
│   ├── view.lua                    # Popup window rendering and interaction loop
│   ├── layout.lua                  # Layout engine (columns/width/alignment/breadcrumbs)
│   ├── tree.lua                    # Prefix tree (Tree/Node) data structure
│   ├── text.lua                    # Text rendering (Text class with highlight segments)
│   ├── mappings.lua                # Mapping parser (user mappings → internal format)
│   ├── types.lua                   # EmmyLua type definitions (annotation-only file)
│   ├── util.lua                    # Utilities (keycode parsing, mode detection, caching)
│   ├── colors.lua                  # Highlight group setup
│   ├── health.lua                  # :checkhealth implementation
│   └── plugins/
│       ├── init.lua                # Plugin registry (setup/_setup/invoke)
│       ├── marks.lua               # Marks plugin (' and ` triggers)
│       ├── registers.lua           # Registers plugin (" and <C-r> triggers)
│       ├── spelling.lua            # Spelling plugin (z= trigger)
│       └── presets/
│           ├── init.lua            # Presets initialization (operators/motions/text_objects)
│           └── misc.lua            # Preset actions (windows/nav/z/g)
├── plugin/
│   └── which-key.vim               # Vim entry point (defines :WhichKey command)
├── doc/
│   └── which-key.nvim.txt          # Vim help documentation
├── .lua-format                     # lua-format config (100 columns)
├── stylua.toml                     # stylua config (120 columns)
├── .neoconf.json                   # neodev config
├── selene.toml                     # selene config
├── vim.toml                        # selene vim globals
├── README.md
├── CHANGELOG.md
└── TODO.md
```

## Core Modules

### `which-key` (Entry)

Entry module that coordinates configuration, loading, and key processing.

| Function | Description |
|----------|-------------|
| `M.setup(options)` | Initialize configuration and schedule loading |
| `M.load()` | Load plugins, register root mappings, process queue |
| `M.register(mappings, opts)` | Register key mappings (deferred until VimEnter) |
| `M.show(keys, opts)` | Manually display the WhichKey panel |
| `M.show_command(keys, mode)` | :WhichKey command implementation |
| `M.execute(id)` | Execute a registered function mapping by index |
| `M.reset()` | Reload the module and reinitialize (uses plenary.reload) |

Loading flow:
1. `setup()` → `config.setup()` + `schedule_load()`
2. `schedule_load()` → on VimEnter, call `load()`
3. `load()` → `plugins.setup()` + `colors.setup()` + register `<leader>` for n/v modes + `Keys.setup()` + process queue

### `which-key.config`

Defines the `Options` class and default configuration. Config fields include:

- `plugins` — Built-in plugin toggles (marks/registers/spelling/presets)
- `operators` — Operators that trigger motion/text-object completion
- `key_labels` — Key display name overrides
- `motions` — Motion options (`count = true` to show count-aware motions)
- `icons` — breadcrumb/separator/group icons
- `popup_mappings` — Scroll bindings inside the popup (scroll_down/scroll_up)
- `window` — Popup window style (border/position/margin/padding/winblend/zindex)
- `layout` — Column layout (height/width/spacing/align)
- `triggers` — Auto trigger mode ("auto" or prefix list)
- `triggers_nowait` — Prefixes that show immediately without waiting for timeoutlen
- `triggers_blacklist` — Modes/prefixes that should never be hooked
- `hidden` — Patterns to hide from labels
- `ignore_missing` — Hide mappings without a label
- `show_help` — Show help message in the command line
- `show_keys` — Show currently pressed key and label in the command line
- `disable` — Disable popup by buftype/filetype

### `which-key.keys` (Core Engine)

The most complex module, managing:
- **Mapping tree**: `M.mappings` table, indexed by `mode .. buf` as `MappingTree`
- **Hook system**: Automatically create hook mappings for prefix keys
- **Function mappings**: `M.functions` table storing Lua callbacks

Key functions:
- `M.register(mappings, opts)` — Parse and register mappings into the tree
- `M.get_mappings(mode, prefix_i, buf)` — Get all mappings under a prefix
- `M.hook_add(prefix_n, mode, buf)` — Create auto-trigger mapping for a prefix
- `M.hook_del(prefix_n, mode, buf)` — Remove a hook mapping
- `M.hook_id(prefix_n, mode, buf)` — Generate unique hook identifier
- `M.is_hooked(prefix_n, mode, buf)` — Check if a prefix is already hooked
- `M.update(buf)` — Update keymaps and hooks for trees
- `M.update_keymaps(mode, buf)` — Fetch keymaps from Neovim API and add to tree
- `M.add_hooks(mode, buf, node)` — Recursively create hooks for all prefix nodes
- `M.get_tree(mode, buf)` — Get or create a MappingTree for mode/buffer
- `M.get_operator(prefix_i)` — Detect if prefix starts with a known operator
- `M.process_motions(ret, mode, prefix_i, buf)` — Handle operator+motion text objects
- `M.is_hook(prefix, cmd)` — Check if a keymap is a WhichKey hook
- `M.map(mode, prefix_n, cmd, buf, opts)` — Set a keymap with duplicate detection
- `M.dump()` — Return undocumented mappings (for debugging)

Hook mechanism:
1. For each prefix key, create two mappings:
   - `<prefix>` → `<cmd>lua require("which-key").show(...)<cr>` (triggers display)
   - `<prefix>Þ` → `<nop>` (ensures timeoutlen works; `Þ` is a secret character)
2. The `M.hooked` table prevents duplicate hooking
3. Blacklisted modes/prefixes (numbers, `q`, `<esc>`, select mode, operator-pending, `j`/`k` in insert/visual) are skipped

### `which-key.tree` (Prefix Tree)

`Tree` and `Node` classes implementing a prefix tree:
- `Tree:new()` — Create an empty tree
- `Tree:add(mapping, opts)` — Add a mapping to the tree (with optional caching)
- `Tree:get(prefix_i, index, plugin_context)` — Get node at prefix (supports plugin lazy-loading)
- `Tree:walk(cb, node)` — Recursively traverse all nodes
- `Tree:path(prefix_i)` — Get all nodes along a prefix path

Each `Node` contains:
- `mapping` — Mapping info (prefix, cmd, desc, group, label, etc.)
- `prefix_i` — Internal keycode representation
- `prefix_n` — Normalized representation
- `children` — Child node table

### `which-key.view` (Popup Window)

Manages the WhichKey popup display and interaction.

| Function | Description |
|----------|-------------|
| `M.show()` | Create and show the floating window |
| `M.hide()` | Close and clean up the window |
| `M.open(keys, opts)` | Open and initialize the key sequence |
| `M.on_keys(opts)` | Main interaction loop (read keys, render, execute) |
| `M.render(text)` | Render Text object to the buffer |
| `M.read_pending()` | Read pending input from the input queue |
| `M.getchar()` | Read a single character (with interrupt handling) |
| `M.execute(prefix_i, mode, buf)` | Execute a key sequence (with hook management) |
| `M.back()` | Backspace (go up one prefix level) |
| `M.scroll(up)` | Scroll the window |
| `M.is_enabled(buf)` | Check if popup is enabled for this buffer |
| `M.show_cursor()` | Highlight the cursor position |
| `M.hide_cursor()` | Clear cursor highlight |
| `M.is_valid()` | Check if the window and buffer are still valid |

Interaction loop:
1. Read pending input
2. Get mappings for the current prefix
3. Exact match (non-group, no children) → execute and close
4. No mappings found → close (execute if auto-triggered)
5. Has child mappings → render layout and wait for next key
6. `<esc>` closes, `<bs>` goes back, `<c-d>/<c-u>` scroll

### `which-key.layout`

`Layout` class converts mapping groups into visual layout:
- `Layout:new(mappings, options)` — Create a layout from mapping results
- `Layout:max_width(key)` — Calculate maximum width for a given field
- `Layout:layout(win)` — Generate a Text object (columns, alignment, spacing)
- `Layout:trail()` — Render the breadcrumb trail and help line in the command line

### `which-key.text`

`Text` class for building the popup content with highlight segments:
- `Text:new()` — Create a new Text object
- `Text:nl()` — Finalize the current line
- `Text:set(row, col, str, group)` — Set text at a position with optional highlight group
- `Text:highlight(row, from, to, group)` — Add a highlight range
- `Text:fix_nl(line)` — Replace newlines with a visible character
- `Text.len(str)` — Get display width of a string

### `which-key.mappings`

Parses user-provided mapping tables into internal format:
- `M.parse(mappings, opts)` — Parse mappings table into Mapping array
- `M.to_mapping(mapping)` — Convert parsed options to a Mapping object
- `M._parse(value, mappings, opts)` — Recursive parsing of mapping values
- `M._process(value, opts)` — Separate mapping keys from options
- `M.child_opts(opts)` — Extract inheritable options for child mappings
- `M._try_parse(value, mappings, opts)` — Protected parsing with error handling

Distinguishes between:
- **Vim map args**: `noremap`, `desc`, `expr`, `silent`, `nowait`, `script`, `unique`, `callback`, `replace_keycodes`
- **Which-key args**: `prefix`, `mode`, `plugin`, `buffer`, `remap`, `cmd`, `name`, `group`, `preset`, `cond`

Special behaviors:
- `cond` option: skip registration if falsy or function returns false
- `remap` option: converted to `noremap = not remap`
- `<Plug>` commands automatically set `noremap = false`
- `buffer = 0` is converted to the current buffer
- For Neovim < 0.7.0: callbacks are proxied via `M.execute()`, `desc` is stripped, `replace_keycodes` is removed

### `which-key.plugins`

Plugin registry managing built-in plugins:
- `M.setup()` — Initialize all enabled plugins
- `M._setup(plugin, opts)` — Register plugin actions and call setup
- `M.invoke(mapping, context)` — Invoke a plugin to generate dynamic mappings

Each plugin implements:
- `plugin.name` — Plugin name string
- `plugin.actions` — Trigger action list (trigger/mode/label)
- `plugin.run(trigger, mode, buf)` — Generate dynamic mapping items
- `plugin.setup(wk, opts, options)` — Optional initialization

### `which-key.types`

Pure type annotation file defining all EmmyLua types:
- `Keymap` — Neovim keymap structure from `nvim_get_keymap`
- `KeyCodes` — Parsed keycode representation (`keys`, `internal`, `notation`)
- `MappingOptions` — Vim mapping options (noremap/silent/nowait/expr)
- `Mapping` — Internal mapping representation
- `MappingTree` — Tree container (mode, buf, tree)
- `VisualMapping` — Mapping with display fields (key, highlights, value)
- `PluginItem` — Dynamic item generated by plugins
- `PluginAction` — Plugin trigger definition (trigger/mode/label/delay)
- `Plugin` — Plugin interface definition

### `which-key.colors`

Sets up highlight groups with default links:

| Highlight Group | Defaults To | Description |
|-----------------|-------------|-------------|
| `WhichKey` | Function | The key |
| `WhichKeyGroup` | Keyword | A group |
| `WhichKeySeparator` | Comment | Separator between key and label |
| `WhichKeyDesc` | Identifier | The label of the key |
| `WhichKeyFloat` | NormalFloat | Normal in the popup window |
| `WhichKeyBorder` | FloatBorder | Border of the popup window |
| `WhichKeyValue` | Comment | Used by plugins that provide values |

### `which-key.health`

Implements `:checkhealth which-key`:
- Walks all mapping trees to detect conflicting keymaps
- Reports duplicate keymaps and buffer-local overrides
- Uses `vim.health` API (with fallback for older Neovim versions)

### `which-key.util`

Utility functions:
- `M.t(str)` — Convert key notation to internal termcodes (cached in `tcache`)
- `M.parse_keys(keystr)` — Parse a key string into `KeyCodes` (cached in `cache`)
- `M.parse_internal(keystr)` — Parse internal keycodes into individual key tokens
- `M.check_cache()` — Invalidate caches when leader/localleader changes
- `M.get_mode()` — Get the current mode (normalized for block/select modes)
- `M.check_mode(mode, buf)` — Validate a mode string
- `M.warn(msg)` / `M.error(msg)` — Notify with WhichKey title

## Configuration

```lua
require("which-key").setup {
  plugins = {
    marks = true,
    registers = true,
    spelling = { enabled = true, suggestions = 20 },
    presets = {
      operators = true, motions = true, text_objects = true,
      windows = true, nav = true, z = true, g = true,
    },
  },
  operators = { gc = "Comments" },
  key_labels = { ["<space>"] = "SPC", ["<cr>"] = "RET" },
  motions = { count = true },
  icons = { breadcrumb = "»", separator = "➜", group = "+" },
  popup_mappings = { scroll_down = "<c-d>", scroll_up = "<c-u>" },
  window = {
    border = "none", position = "bottom",
    margin = { 1, 0, 1, 0 }, padding = { 1, 2, 1, 2 },
    winblend = 0, zindex = 1000,
  },
  layout = {
    height = { min = 4, max = 25 }, width = { min = 20, max = 50 },
    spacing = 3, align = "left",
  },
  ignore_missing = false,
  hidden = { "<silent>", "<cmd>", "<Cmd>", "<CR>", "^:", "^ ", "^call ", "^lua " },
  show_help = true, show_keys = true,
  triggers = "auto",
  triggers_nowait = { "`", "'", "g`", "g'", '"', "<c-r>", "z=" },
  triggers_blacklist = { i = { "j", "k" }, v = { "j", "k" } },
  disable = { buftypes = {}, filetypes = {} },
}
```

### User Commands

| Command | Description |
|---------|-------------|
| `:WhichKey [keys] [mode]` | Manually display the key binding panel |
| `:checkhealth which-key` | Check for conflicting key mappings |

### Registering Mappings

```lua
local wk = require("which-key")

wk.register({
  f = {
    name = "file",  -- group name
    f = { "<cmd>Telescope find_files<cr>", "Find File" },
    r = { "<cmd>Telescope oldfiles<cr>", "Open Recent File", noremap = false, buffer = 123 },
    n = { "New File" },  -- label only, no mapping created
    e = "Edit File",  -- label only (shorthand)
    ["1"] = "which_key_ignore",  -- special label to hide from popup
    b = { function() print("bar") end, "Foobar" },  -- Lua function mapping
  },
}, { prefix = "<leader>" })
```

Register options (`opts`):
- `mode` — Mode for the mappings (default: `"n"`; can be a table for multiple modes)
- `prefix` — Prefix prepended to all mappings (default: `""`)
- `buffer` — Buffer number for buffer-local mappings (default: nil/global; `0` = current buffer)
- `silent` — Use `silent` when creating keymaps (default: `true`)
- `noremap` — Use `noremap` when creating keymaps (default: `true`)
- `nowait` — Use `nowait` when creating keymaps (default: `false`)
- `expr` — Use `expr` when creating keymaps (default: `false`)
- `cond` — Condition (boolean or function) to control registration

## Dependencies

### Runtime Dependencies

No hard dependencies. Optional:
- `plenary.nvim` — Only used by `M.reset()` for module reloading

### Dependents

- Used by almost all modern Neovim configurations as a key binding documentation/discovery tool
- Commonly paired with `lazy.nvim` for lazy-loading key bindings

## Build / Test

No built-in test suite. Formatting uses **stylua** (120 columns) and **lua-format** (100 columns). Static analysis uses **selene**.

## Coding Conventions

- **Language**: Lua, compatible with Neovim >= 0.5.0 (feature detection via `vim.fn.has("nvim-0.6")` and `vim.fn.has("nvim-0.7.0")`)
- **Formatting**: stylua (120 columns, double quotes, 2-space indent) and lua-format (100 columns)
- **Naming**: Module export table is `M`; public functions use `snake_case`; classes use `PascalCase` (Tree/Node/Layout/Text)
- **Type annotations**: `types.lua` centrally defines all types; other modules use EmmyLua inline annotations
- **Deferred loading**: `schedule_load()` defers until VimEnter to avoid startup overhead
- **Secret character**: Uses `Þ` (Thorn character) as the nop mapping suffix to ensure timeoutlen works correctly
- **Keycode handling**: `Util.t()`, `Util.parse_keys()`, and `Util.parse_internal()` unify internal/normalized keycode representations
- **Caching**: Keycode parsing results cached in `cache` and `tcache`; invalidated when leader/localleader changes
- **Namespace**: Uses `vim.api.nvim_create_namespace("WhichKey")` for extmarks and highlights
