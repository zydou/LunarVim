# cmp-buffer

## Project Overview

cmp-buffer is an [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) completion source that provides auto-completion of words found in the current buffer (and optionally other visible or all buffers). It indexes buffer contents asynchronously in the background and maintains a live word list kept in sync with buffer edits.

It also exports a `compare_locality` comparator function that ranks completion items by their distance from the cursor line, improving completion relevance sorting. This comparator works on items from any source (e.g. LSP), not just this buffer source.

## Directory Structure

```
cmp-buffer/
├── LICENSE
├── README.md                 # User-facing docs (setup, config, indexing explanation)
├── after/
│   └── plugin/
│       └── cmp_buffer.lua    # Auto-registers the 'buffer' source with nvim-cmp
└── lua/
    └── cmp_buffer/
        ├── init.lua           # Entry point; returns a new source instance
        ├── source.lua         # nvim-cmp source implementation (complete, compare_locality)
        ├── buffer.lua         # Per-buffer word indexing, watching, and distance tracking
        └── timer.lua          # setInterval/clearInterval-style libuv timer wrapper
```

## Core Modules

### `cmp_buffer.init.lua`

- Entry point. Returns `require('cmp_buffer.source').new()` so it can be called as a callable table by `nvim-cmp` (or used as an argument to `cmp.register_source`).

### `cmp_buffer.source.lua`

- Implements the nvim-cmp source protocol. Created via `source.new()`.
- **Public API:**
  - `source.new()` — create a new source instance. Stores a `buffers` table keyed by buffer number.
  - `source:complete(params, callback)` — gathers words from all configured buffers and returns completion items with `dup = 0`. Uses `vim.defer_fn` with 100ms delay when any buffer's indexer is still active, setting `isIncomplete = true`.
  - `source:compare_locality(entry1, entry2)` — comparator for `sorting.comparators`. Compares entries by distance from the cursor line using the word distance index. Returns `nil` if entries come from different contexts (`entry.context`).
  - `source:get_keyword_pattern(params)` — returns the configured `keyword_pattern`.
  - `source:_validate_options(params)` — validates merged user options against defaults via `vim.validate`. Note: does **not** validate `max_indexed_line_length`.
  - `source:_get_buffers(opts)` — (private) lazily creates and caches `buffer` instances for each bufnr. Hooks `on_close_cb` to release the cache entry when a buffer detaches.
  - `source:_get_distance_from_entry(entry)` — (private) looks up the word distance for a completion entry, trying `filterText` first then `label`. Adds `+1` to `cursor.line` to convert 0-based to 1-based.
- **Defaults:**
  ```lua
  keyword_length = 3
  keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\%(\w\|á\|Á\|é\|É\|í\|Í\|ó\|Ó\|ú\|Ú\)*\%(-\%(\w\|á\|Á\|é\|É\|í\|Í\|ó\|Ó\|ú\|Ú\)*\)*\)]]
  get_bufnrs = function() return { vim.api.nvim_get_current_buf() } end
  indexing_batch_size = 1000
  indexing_interval = 100
  max_indexed_line_length = 1024 * 40
  ```
  The default `keyword_pattern` matches signed/decimal numbers and identifiers (including accented Latin characters like á, é, í, ó, ú, upper- and lowercase), with optional hyphen or dot separators between identifier segments.

### `cmp_buffer.buffer.lua`

- Represents a single buffer for word indexing. Created via `buffer.new(bufnr, opts)`.
- **Class constant:**
  - `buffer.GET_LINES_CHUNK_SIZE = 1000` — chunk size used when fetching lines from Neovim. Fetching in chunks is intentionally more memory-efficient than a single bulk request (see source comment around `nvim_buf_get_lines`).
- **Public API:**
  - `buffer.new(bufnr, opts)` — constructor. Compiles `keyword_pattern` into a `vim.regex` object.
  - `buffer:watch()` — attaches via `nvim_buf_attach` to monitor `on_lines`, `on_reload`, `on_detach` events.
  - `buffer:start_indexing_timer()` — kicks off the asynchronous background indexer using the libuv timer.
  - `buffer:stop_indexing_timer()` — stops the async indexer and resets `timer_current_line = -1`.
  - `buffer:mark_all_lines_dirty()` — marks both word tables and the distance map as dirty (called after each async batch).
  - `buffer:close()` — releases all resources, stops the timer, and invokes the `on_close_cb` hook.
  - `buffer:get_words()` — returns two tables of unique words: `other_lines` and `curr_line`. Rebuilds lazily based on dirty flags.
  - `buffer:get_words_distances(cursor_row)` — returns a map of `word => minimum line distance` from `cursor_row` (1-based). Rebuilt lazily.
  - `buffer:index_line(linenr, line)` — indexes words from a single line using the configured regex. Truncates lines longer than `max_indexed_line_length` before matching.
  - `buffer:index_range(range_start, range_end, skip_already_indexed)` — indexes a range of lines in `GET_LINES_CHUNK_SIZE` chunks. Uses `safe_buf_call` to avoid Neovim issue #16729.
  - `buffer:rebuild_unique_words(words_table, range_start, range_end)` — (helper) rebuilds a unique-words set from `lines_words` over a range.
  - `buffer:safe_buf_call(callback)` — (helper) workaround for Neovim issue #16729; calls the callback in the buffer's context only if not already there.
- **Internal state:**
  - `lines_words` — array indexed by 1-based line number, each entry a list of words on that line.
  - `unique_words_curr_line` / `unique_words_other_lines` — lazy-rebuilt sets of unique words, split by the last edit range.
  - `words_distances` — lazy-rebuilt map of word to minimum line distance from the cursor.
  - Dirty flags (`unique_words_curr_line_dirty`, `unique_words_other_lines_dirty`, `words_distances_dirty`) avoid redundant full rebuilds.
- **Indexing model:**
  - **Async indexer** (`start_indexing_timer`): processes `indexing_batch_size` lines per `indexing_interval` ms tick. Negative `batch_size` is treated as synchronous (process all lines in one tick). Skips already-indexed lines on each tick.
  - **Watcher** (`on_lines`): synchronously re-indexes only the changed lines. Adjusts the async indexer's `timer_current_line` when edits overlap or precede it, so no lines are skipped or double-indexed.
  - **Reload** (`on_reload`): clears `lines_words` and restarts the async indexer.
  - **Detach** (`on_detach`): calls `buffer:close()`.

### `cmp_buffer.timer.lua`

- JavaScript `setInterval`/`clearInterval` semantics built on top of `vim.loop` timers.
- **Public API:**
  - `timer.new()` — creates a new timer backed by `vim.loop.new_timer()`.
  - `timer:start(timeout_ms, repeat_ms, callback)` — starts the timer. Wraps the callback to fix two libuv problems:
    1. Prevents multiple invocations on a single event loop tick (small intervals can queue up).
    2. Detects when a different callback was set (via `start` again) and skips the stale one.
  - `timer:stop()` — stops the timer and clears the callback wrapper so a previously-scheduled invocation is a no-op.
  - `timer:is_active()` — delegates to `handle:is_active()`.
  - `timer:close()` — closes the underlying `vim.loop` handle.

## Configuration

Configure via `cmp.setup`. Options go under the `option` key of the source entry (not at the top level):

```lua
local cmp = require('cmp')
local cmp_buffer = require('cmp_buffer')

cmp.setup {
  sources = {
    { name = 'buffer', option = {
      keyword_length = 3,
      keyword_pattern = [[\%(-\?\d\+\%(\.\d\+\)\?\|\h\w*\%([\-.]\w*\)*\)]],
      get_bufnrs = function() return { vim.api.nvim_get_current_buf() } end,
      indexing_interval = 100,
      indexing_batch_size = 1000,
      max_indexed_line_length = 1024 * 40,
    }},
  },
  sorting = {
    comparators = {
      function(...) return cmp_buffer:compare_locality(...) end,
    },
  },
}
```

### Options

| Option | Type | Default | Description |
|---|---|---|---|
| `keyword_length` | `number` | `3` | Minimum characters typed before triggering completion. |
| `keyword_pattern` | `string` | (see above) | Vim regex used to extract words from buffer lines. Set to `[[\k\+]]` to use `'iskeyword'`. |
| `get_bufnrs` | `fun(): number[]` | `{ current_buf }` | Returns the list of buffer numbers to index. Use `vim.api.nvim_list_bufs()` for all buffers, or filter by visible windows. |
| `indexing_interval` | `number` | `100` | Milliseconds between async indexing ticks. |
| `indexing_batch_size` | `number` | `1000` | Lines indexed per tick. Negative = synchronous (all at once, blocks UI). |
| `max_indexed_line_length` | `number` | `1024 * 40` | Max bytes indexed per line; longer lines are truncated. |

### `get_bufnrs` recipes

**All buffers:**
```lua
get_bufnrs = function() return vim.api.nvim_list_bufs() end
```

**Visible buffers only:**
```lua
get_bufnrs = function()
  local bufs = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    bufs[vim.api.nvim_win_get_buf(win)] = true
  end
  return vim.tbl_keys(bufs)
end
```

**Skip large files (>1 MB):**
```lua
get_bufnrs = function()
  local buf = vim.api.nvim_get_current_buf()
  local byte_size = vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf))
  if byte_size > 1024 * 1024 then return {} end
  return { buf }
end
```

## Dependencies

- **Runtime:** [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) — the only hard dependency. The plugin registers itself as a source via `cmp.register_source` (in `after/plugin/cmp_buffer.lua`).
- **Optional:** None. No other plugins are required.

## Build / Test

No build step and no test suite. Pure Lua plugin loaded by Neovim at runtime.

## Coding Conventions

- Lua code uses `local` everywhere; module "classes" are implemented via `setmetatable({}, { __index = ... })`.
- Each class exposes a `class.new(...)` constructor and uses `self` methods (colon syntax).
- Heavy use of LuaCATS-style type annotations (`---@class`, `---@field`, `---@param`, `---@return`).
- Configuration defaults live inside `source.lua`; user options are merged with `vim.tbl_deep_extend('keep', params.option, defaults)`.
- Line indexing uses **1-based** line numbers in `lines_words` (Lua array), but the Neovim API (`nvim_buf_get_lines`, `on_lines`) uses **0-based** indexes — conversions are explicit at the API boundary (e.g. `index_range` adds `+1` when calling `index_line`).
- `compare_locality` converts `entry.context.cursor.line` (0-based) to 1-based by adding `+1` before calling `get_words_distances`.
- Private methods are prefixed with `_` (e.g. `_validate_options`, `_get_buffers`, `_get_distance_from_entry`).
