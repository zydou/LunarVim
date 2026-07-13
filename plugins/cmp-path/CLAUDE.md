# cmp-path

## Project Overview

cmp-path is an [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) completion source that provides filesystem path completions. It uses `vim.loop.fs_scandir` / `fs_scandir_next` to asynchronously enumerate directories and produces completion items for files and folders. It is typically used with `cmp.setup.cmdline(':', ...)` to complete paths in Ex commands but also works in Insert mode.

The `path` source is auto-registered by `after/plugin/cmp_path.lua`, so no manual `require('cmp').register_source(...)` is needed.

## Directory Structure

```
cmp-path/
├── LICENSE
├── README.md                 # User-facing docs (setup, config options)
├── after/
│   └── plugin/
│       └── cmp_path.lua      # Auto-registers the 'path' source with nvim-cmp
└── lua/
    └── cmp_path/
        └── init.lua          # All source logic in a single file
```

## Core Modules

### `lua/cmp_path/init.lua`

Contains the entire source implementation. The module returns a table `source`; instances are created via `source.new()`.

### Constants

- `NAME_REGEX` — character class matching a single valid filename character (anything except `/ \ : * ? < > ' " ` |`).
- `PATH_REGEX` — a `vim.regex` object matching a partial absolute or relative path at the end of the line. Used by `_dirname` to locate the directory separator that precedes the partial filename.
- `constants.max_lines = 20` — number of preview lines shown for file documentation.

### Source Instance

State held on `self`. Currently stateless — `source.new()` returns a fresh table with no instance fields.

### Source API

- `source.new()` — creates the source object via `setmetatable({}, { __index = source })`.
- `source.get_trigger_characters()` — returns `{ '/', '.' }`.
- `source.get_keyword_pattern(params)` — returns `NAME_REGEX .. '*'`.
- `source.complete(params, callback)` — resolves the directory to scan via `_dirname`, then calls `_candidates`. Hidden files are included only when the character at `params.offset` in `cursor_before_line` is `.`.
- `source.resolve(completion_item, callback)` — if the item is a file, reads the first 1 KB of the file to produce a Markdown code-block preview (detects filetype via `vim.filetype.match`; reports "binary file" for content containing `\0`).
- `source._dirname(params, option)` — parses `cursor_before_line` with `PATH_REGEX` and computes the absolute directory. Handles:
  - `../` — parent of buffer cwd
  - `./` or a trailing `"` / `'` — buffer cwd
  - `~/` — user home directory
  - `$VAR/` — environment variable expansion
  - `/` — absolute path (with guards against URL components, URL schemes, HTML closing tags, math expressions, and slash comments)
  - In command mode (`mode == 'c'`), uses `vim.fn.getcwd()` instead of `option.get_cwd`.
- `source._candidates(dirname, include_hidden, option, callback)` — async directory scan via `vim.loop.fs_scandir`. Builds `lsp.CompletionItem`s with `kind = File` or `Folder`. For directories, sets `insertText = name .. '/'`, adjusts `label` based on `label_trailing_slash`, and sets `word = name` when `trailing_slash` is disabled.
- `source._is_slash_comment()` — heuristic that returns true when the current buffer's `commentstring` contains `/*` or `//` and the buffer has a non-empty `filetype`. Used to prevent `/` from triggering path completion inside comments.
- `source._validate_option(params)` — merges user options with defaults via `vim.tbl_deep_extend('keep', ...)` and validates with `vim.validate`.
- `source._get_documentation(filename, count)` — reads the first KB of a file, detects binary content, and formats a Markdown or PlainText documentation block.

### Defaults (`cmp_path.Option`)

```lua
---@class cmp_path.Option
---@field public trailing_slash boolean
---@field public label_trailing_slash boolean
---@field public get_cwd fun(params): string

local defaults = {
  trailing_slash        = false,
  label_trailing_slash  = true,
  get_cwd = function(params)
    return vim.fn.expand(('#%d:p:h'):format(params.context.bufnr))
  end,
}
```

## Configuration

```lua
cmp.setup {
  sources = { { name = 'path', option = {
    trailing_slash        = false,
    label_trailing_slash  = true,
    get_cwd = function(params)
      return vim.fn.expand(('#%d:p:h'):format(params.context.bufnr))
    end,
  }}},
}
```

Source-level options (`option` table):

| Option                 | Type       | Default                                    | Description |
|------------------------|------------|--------------------------------------------|-------------|
| `trailing_slash`       | `boolean`  | `false`                                    | Completed directory insert includes a trailing `/`. |
| `label_trailing_slash` | `boolean`  | `true`                                     | Completion menu shows `/` after directory names. |
| `get_cwd`              | `function` | Returns the directory of the current buffer | Base directory for relative-path completion. |

## Dependencies

- **Runtime:** [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)

## Build / Test

No build step or test suite. Pure Lua plugin loaded by Neovim at runtime.

## Coding Conventions

- Single-file plugin in `lua/cmp_path/init.lua`.
- Uses LuaCATS annotations (`---@class`, `---@param`, `---@return`, `---@field`).
- Module pattern: `local source = {}`, `source.new()` returns `setmetatable({}, { __index = source })`.
- Options merged with `vim.tbl_deep_extend('keep', ...)` and validated with `vim.validate`.
- Completion items carry `data = { path, type, stat, lstat }` for later access during `resolve`.
- File-kind detection uses `stat.type`, falls back to `fs_scandir` types, and handles broken symlinks via `fs_lstat`.
