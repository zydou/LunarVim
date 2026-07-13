# hop.nvim

## Project Overview

hop.nvim is an EasyMotion-style Neovim plugin that lets users jump to any position in a buffer with as few keystrokes as possible. It overlays 1–3 character labels (hints) on buffer text; the user types a label to jump to its annotated position. This is the actively maintained fork of [phaazon/hop.nvim](https://github.com/phaazon/hop.nvim), maintained by [smoka7](https://github.com/smoka7/hop.nvim).

## Directory Structure

```
hop.nvim/
├── lua/hop/
│   ├── init.lua              # Entry module: exports hint_* functions and setup
│   ├── defaults.lua          # Default configuration (keys, direction, extensions, etc.)
│   ├── hint.lua              # Hint module: distance calc, hint creation/reduction/highlight
│   ├── highlight.lua         # Hop highlight groups + ColorScheme autocommand
│   ├── jump_regex.lua        # Regex generators (word_start/camel_case/line/anywhere/etc.)
│   ├── jump_target.lua       # JumpTarget generator: converts regex matches into jump positions
│   ├── window.lua            # Window context computation (WindowContext, line/column ranges)
│   ├── perm.lua              # Permutation algorithm (TrieBacktrackFilling) for hint labels
│   ├── mappings.lua          # Character match-mapping lookup (e.g. for CJK / Persian input)
│   ├── health.lua            # :checkhealth implementation
│   └── mappings/             # Keyboard layout / input-method variants
│       ├── zh.lua            # Chinese pinyin mapping
│       ├── zh_sc.lua         # Simplified Chinese
│       ├── zh_tc.lua         # Traditional Chinese
│       └── fa.lua            # Persian (Farsi)
├── plugin/hop.lua            # Registers :Hop* commands on load
├── doc/hop.txt               # Vim help documentation
├── tests/                    # Tests (plenary.nvim + busted)
│   ├── minimal_init.lua
│   ├── tst_mappings_zh.txt
│   ├── hop/
│   │   ├── hop_spec.lua
│   │   ├── window_spec.lua
│   │   └── mappings_zh_spec.lua
│   └── lua/
│       └── hop_helpers.lua
├── examples/
│   └── hop-extension-hello-world/  # Sample extension skeleton
├── rfcs/
│   └── 0001-hop-general-hint-modes.md
├── .github/workflows/test.yml
├── Makefile
└── stylua.toml
```

## Core Modules

### `hop.init` — Entry Point
- `M.setup(opts)` — Set global options, load highlights, register autocommand, load extensions
- `M.hint_words(opts)` / `M.hint_char1(opts)` / `M.hint_char2(opts)` — Various jump modes
- `M.hint_camel_case(opts)` / `M.hint_patterns(opts, pattern)` / `M.hint_lines(opts)`
- `M.hint_vertical(opts)` / `M.hint_lines_skip_whitespace(opts)` / `M.hint_anywhere(opts)`
- `M.hint_with(jump_target_gtr, opts)` — Jump using a custom target generator
- `M.hint_with_callback(jump_target_gtr, opts, callback)` — Jump with a callback (used by extensions)
- `M.refine_hints(key, hint_state, ...)` — Step the hint state machine (narrow hints)
- `M.quit(hint_state)` — End a Hop session, clear highlights and restore diagnostics
- `M.get_input_pattern(prompt, maxchar, opts)` — Interactive input with optional preview
- `M.move_cursor_to(jt, opts)` — Move cursor to a target and update the jump list

Internal (not part of the public API surface):
- `M.hint_with_regex(regex, opts, callback)` — Wraps a `Regex` object into a generator and dispatches to `hint_with_callback`

### `hop.defaults` — Default Configuration
```lua
M.keys = 'asdghklqwertyuiopzxcvbnmfj'  -- Label character set
M.quit_key = '<Esc>'                     -- Key to abort a Hop session
M.perm_method = TrieBacktrackFilling     -- Label permutation algorithm
M.reverse_distribution = false           -- If true, assign best labels to farthest targets
M.x_bias = 10                            -- Horizontal distance weight
M.distance_method = hint.manh_distance   -- Distance function
M.teasing = true                         -- Show error messages for invalid inputs
M.virtual_cursor = false                 -- Show a fake cursor overlay while hopping
M.jump_on_sole_occurrence = true         -- Auto-jump when only one target exists
M.case_insensitive = true                -- Case-insensitive pattern matching
M.create_hl_autocmd = true               -- Re-apply highlights on ColorScheme change
M.current_line_only = false              -- Restrict hints to the current line
M.dim_unmatched = true                   -- Dim buffer text that is not a jump target
M.hl_mode = "combine"                    -- Extmark highlight blend mode
M.uppercase_labels = false               -- Render labels in upper case
M.multi_windows = false                  -- Show hints across all windows in the tab
M.windows_list = function()              -- Returns the list of windows to scan
  return vim.api.nvim_tabpage_list_wins(0)
end
M.ignore_injections = false              -- Ignore treesitter language injections
M.hint_position = hint.HintPosition.BEGIN  -- Where the hint sits on the target
M.hint_offset = 0                        -- Column offset applied after jump
M.hint_type = hint.HintType.OVERLAY      -- 'overlay' or 'inline' extmark rendering
M.excluded_filetypes = {}                -- Filetypes to skip in multi-window mode
M.match_mappings = {}                    -- Active input-method mappings (e.g. 'zh_sc')
M.extensions = { 'hop-yank', 'hop-treesitter' }  # Extensions to load (installed separately)
```

### `hop.hint` — Hint Module
- `HintDirection` enum: `BEFORE_CURSOR = 1`, `AFTER_CURSOR = 2`
- `HintPosition` enum: `BEGIN = 1`, `MIDDLE = 2`, `END = 3`
- `HintType` enum: `OVERLAY = 'overlay'`, `INLINE = 'inline'`
- `HintPriority` constants: `DIM = 65533`, `HINT = 65534`, `CURSOR = 65535`
- `manh_distance(a, b, x_bias)` — Weighted Manhattan distance (favors vertical packing)
- `readwise_distance(a, b, x_bias)` — Left-to-right reading-order distance
- `reduce_hints(hints, key)` — Filter/narrow hints by one key press
- `create_hints(jump_targets, indirect_jump_targets, opts)` — Assign labels via permutations
- `create_hint_state(opts)` — Build the per-session state (contexts, namespaces, diagnostics)
- `set_hint_extmarks(hl_ns, hints, opts)` — Render hint labels as extmarks
- `set_hint_preview(hl_ns, jump_targets)` — Highlight pattern matches during input preview

### `hop.jump_regex` — Regex Generators
Each returns a `Regex` object: `{ oneshot: boolean, match: function }`.
- `regex_by_word_start()` — Start of `\k\+` words
- `regex_by_camel_case()` — camelCase / acronym / hex / number boundaries
- `regex_by_case_searching(pat, plain_search, opts)` — User-supplied pattern with smart-case and match-mapping support
- `by_line_start()` — First column of every line (excluding the active line)
- `regex_by_vertical()` — The cursor's column on other lines
- `regex_by_line_start_skip_whitespace()` — First non-whitespace column of each line
- `regex_by_anywhere()` — Word/case/underscore/hash boundaries everywhere

### `hop.jump_target` — Jump Target Generator
- `jump_target_generator(regex, win_ctxs?)` — Returns a `Generator` function that scans windows/lines and produces `Locations`
- `sort_indirect_jump_targets(indirect_jump_targets, opts)` — Sort by score (ascending, or descending if `reverse_distribution`)
- `move_jump_target(jt, offset_row, offset_cell)` — Apply a row/cell offset to a target

Key types:
- `JumpTarget` — `{ window, buffer, cursor: CursorPos, length }`
- `IndirectJumpTarget` — `{ index, score }` (flat, score-sorted)
- `Locations` — `{ jump_targets: JumpTarget[], indirect_jump_targets: IndirectJumpTarget[] }`

### `hop.window` — Window Context
- `get_windows_context(opts)` — Returns `WindowContext[]` (current window first; others if `multi_windows`)
- `get_lines_context(win_ctx)` — Returns `LineContext[]` for visible, unfolded lines
- `clip_window_context(win_ctx, opts)` — Restrict context to `current_line_only` / direction
- `clip_line_context(win_ctx, line_ctx, opts)` — Slice the line to the visible region and apply direction
- `cell2char(line, cell)` — Convert a displayed cell column to a character index (multi-byte aware)
- `pos2extmark(pos)` / `row2extmark` / `col2extmark` / `line_range2extmark` / `column_range2extmark` — Coordinate conversions
- `is_active_window` / `is_cursor_line` / `is_active_line` — Context predicates

Important coordinate aliases (see `window.lua` header):
- `WindowRow` — 1-based line number
- `WindowCol` — 0-based byte index
- `WindowCell` — 0-based displayed cell (via `strdisplaywidth`)
- `WindowChar` — 0-based character index

### `hop.perm` — Label Permutation
- `TrieBacktrackFilling` — Trie + backtracking algorithm that assigns short, unique label sequences to jump targets
- `permutations(keys, n, opts)` — Dispatches to `opts.perm_method`

### `hop.highlight` — Highlight Management
- `insert_highlights()` — Define `HopNextKey`, `HopNextKey1`, `HopNextKey2`, `HopUnmatched`, `HopCursor`, `HopPreview`
- `create_autocmd()` — Re-apply highlights on `ColorScheme` (gated by `create_hl_autocmd`)

### `hop.mappings` — Input Match-Mappings
- `checkout(pat, opts)` — Expand each pattern character via the active `match_mappings` (e.g. pinyin → Latin)

### `hop.health` — `:checkhealth`
- `check()` — Validates that `opts.keys` contains no duplicate characters

## Commands (registered in `plugin/hop.lua`)

For each base command, variants are auto-generated with suffixes:
- `BC` — `direction = BEFORE_CURSOR`
- `AC` — `direction = AFTER_CURSOR`
- `CurrentLine` — `current_line_only = true`
- `CurrentLineBC` / `CurrentLineAC` — combined
- `MW` — `multi_windows = true`

Base commands:
- `HopChar1`, `HopChar2`, `HopWord`, `HopPattern`, `HopAnywhere`, `HopCamelCase`
- `HopLine`, `HopVertical`, `HopLineStart`

Extensions (when installed) add e.g. `HopYankChar1`, `HopNodes`, `HopPaste`.

## Extension System

Extensions are **not bundled** in this repository. They are separate plugins named in `opts.extensions` (defaults: `hop-yank`, `hop-treesitter`) and must be installed independently. Each extension must export a `register(opts)` function.

Reference skeleton: `examples/hop-extension-hello-world/`.

## Configuration

```lua
require('hop').setup({
  keys = 'etovxqpdygfblzhckisuran',
  reverse_distribution = false,
  jump_on_sole_occurrence = true,
  hint_position = hop.hint.HintPosition.BEGIN,
  hint_type = hop.hint.HintType.OVERLAY,
  multi_windows = false,
  dim_unmatched = true,
  virtual_cursor = false,
  match_mappings = { 'zh_sc' },
})
```

Hop does **not** set keybindings — users must define them:

```lua
local hop = require('hop')
local directions = require('hop.hint').HintDirection
vim.keymap.set('', 'f', function()
  hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true })
end, { remap = true })
```

## Dependencies

- **Required**: Neovim >= 0.9.0 (the plugin refuses to load on older versions)
- **Behavioral note**: On Neovim < 0.10.0, `hint_type` is forced to `OVERLAY` (inline extmark features require 0.10+)
- **Optional**: `hop-yank` and `hop-treesitter` extensions (installed separately)
- **Test**: `plenary.nvim`

## Build / Test

- **Test framework**: plenary.nvim + busted
- **Run**: `make test` or `nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"`
- **CI**: `.github/workflows/test.yml`

## Coding Conventions

- **Language**: Pure Lua (no dependencies beyond Neovim built-ins)
- **Naming**: Module functions use `M.snake_case` (`M.hint_words`); config keys are `snake_case`
- **Type annotations**: `---@class` / `---@enum` / `---@alias` / `---@type` / `---@param` / `---@return`
- **Options fallback**: `setmetatable(opts, { __index = defaults })` so every call site can omit any key
- **Highlight namespaces**: Dedicated namespace IDs (`hop_hl`, `hop_dim`) for extmarks; cleaned up on quit
- **Hint state machine**: `hint_with_callback` → `refine_hints` loop until a unique match or cancellation
- **Formatting**: `stylua.toml` (column width 120)
