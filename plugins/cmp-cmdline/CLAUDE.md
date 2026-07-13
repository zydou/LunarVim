# cmp-cmdline

## Project Overview

cmp-cmdline is an [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) completion source that provides completions for Vim's cmdline — both `:` (command mode) and `/`/`?` (search mode). It wraps `vim.fn.getcompletion` to produce completion candidates for commands, file paths, option names, and other built-in Vim completions, integrating them cleanly into the nvim-cmp popup menu.

## Directory Structure

```
cmp-cmdline/
├── LICENSE
├── README.md                 # User-facing docs (setup, options)
├── after/
│   └── plugin/
│       └── cmp_cmdline.lua   # Auto-registers the 'cmdline' source with nvim-cmp
└── lua/
    └── cmp_cmdline/
        └── init.lua          # All source logic in a single file
```

## Core File: `lua/cmp_cmdline/init.lua`

The entire source implementation is contained in this single module. It is loaded and instantiated by `after/plugin/cmp_cmdline.lua`, which calls `cmp.register_source('cmdline', require('cmp_cmdline').new())`.

### Regex Patterns

Pre-compiled Vim regex objects (built via `vim.regex()`) used to pre-process the cmdline before dispatching to `vim.fn.getcompletion`:

| Regex                        | Purpose |
|------------------------------|---------|
| `MODIFIER_REGEX`             | Matches command modifiers at the head of the cmdline: `:aboveleft`, `:belowright`, `:botright`, `:browse`, `:confirm`, `:hide`, `:keepalt`, `:keeppatterns`, `:leftabove`, `:lockmarks`, `:noswapfile`, `:rightbelow`, `:silent`, `:tab`, `:topleft`, `:verbose`, `:vertical`. |
| `COUNT_RANGE_REGEX`          | Matches `{count}` and `{range}` prefixes, including `'<,'>` mark ranges and `$` end markers. |
| `ONLY_RANGE_REGEX`           | Matches a cmdline consisting solely of a range/count (e.g. `4,` or `'<,'>`); completion is suppressed for these. |
| `OPTION_NAME_COMPLETION_REGEX` | Matches `setlocal ...` to enable completion of option names like `no{word}`. |
| `[[\h\w*$]]` (anonymous)     | Matches the trailing identifier suffix for dotted completion (e.g. extracts `get_query` from `vim.treesitter.get_query`). |

### Default Options

```lua
local DEFAULT_OPTION = {
  treat_trailing_slash = true,
  ignore_cmds = { 'Man', '!' },
}
```

Merged into per-invocation options via `vim.tbl_deep_extend('keep', params.option or {}, DEFAULT_OPTION)`; user options take precedence.

### Source Definitions Table

A list of `cmp.Cmdline.Definition` tables, each with:

- `ctype` — display type string (currently only `'cmdline'` is defined).
- `regex` — Vim regex; matches the tail of `params.context.cursor_before_line` to determine the input offset. Compiled on each `complete` call.
- `kind` — `cmp.lsp.CompletionItemKind` for UI display (currently `Variable`).
- `isIncomplete` — whether the completion list may be a prefix of a larger set (currently `true`).
- `exec(option, arglead, cmdline, force)` — calls `vim.fn.getcompletion(..., 'cmdline')` and returns `lsp.CompletionItem[]`.
- `fallback?` — if truthy and `exec` returns no items, allows falling through to the next definition.

The single built-in definition uses `ctype = 'cmdline'` and dispatches through `vim.fn.getcompletion(cmdline, 'cmdline')`.

### `exec` Implementation Details

The single definition's `exec` function performs these steps:

1. **Range-only suppression** — returns `{}` when `cmdline` consists solely of a range unless `force` is true (manual trigger).
2. **Parse cmdline** — strips the range prefix via `COUNT_RANGE_REGEX`, then calls `vim.api.nvim_parse_cmd` to extract `.cmd`. Errors from `nvim_parse_cmd` are caught via `pcall`.
3. **Ignore command check** — returns `{}` when `parsed.cmd` is in `option.ignore_cmds`.
4. **Strip modifiers** — iteratively removes `MODIFIER_REGEX` matches from `cmdline` when `arglead ~= cmdline` (i.e. when nested subcommands under modifiers).
5. **Extract `fixed_input`** — uses `[[\h\w*$]]` on `arglead` to find the stable prefix for dotted completion (keeps `vim.treesitter.` when completion yields `get_query`).
6. **Option-name completion** — when `cmdline` matches `OPTION_NAME_COMPLETION_REGEX`, boolean options get an extra `no{word}` entry (with `filterText = word`) so `set nocursorline` works.
7. **Escape backslashes** — `cmdline:gsub([[\]], [[\\\\]])` before passing to `vim.fn.getcompletion`.
8. **Build items** — iterates `vim.fn.getcompletion`, handling both `string` and `{ word = ... }` shaped entries; applies `fixed_input` prefix to labels that don't already contain it.
9. **Strip trailing slash** — when `option.treat_trailing_slash` is true, removes a single trailing `/` from labels unless the path ends with `~/`, `./`, or `../`.

### Source Instance State

The `source.new()` constructor returns a table cached across `complete` calls to support fuzzy-merge behavior:

- `before_line` — previous `cursor_before_line`.
- `offset`, `ctype` — previous completion offset/type (must match to merge).
- `items` — previous completion items.

### Source API

- `source.new()` — creates a source instance with default state.
- `source:get_keyword_pattern()` — returns `[[^[:blank:]]*]`.
- `source:get_trigger_characters()` — returns `{ ' ', '.', '#', '-' }`.
- `source:complete(params, callback)` — iterates `definitions`; on regex match calls `exec` and, when the new input is a prefix of the old input (or vice versa) and `offset`/`ctype` match, merges in previously returned items to compensate for `vim.fn.getcompletion` not supporting fuzzy matching.

### Option Validation

User-supplied options are validated with `vim.validate`, expecting the fields defined in the `cmp-cmdline.Option` LuaCATS class (`treat_trailing_slash: boolean`, `ignore_cmds: string[]`).

## Configuration

Configured via `cmp.setup.cmdline` (the recommended entry point):

```lua
-- `/` cmdline: buffer word completion
cmp.setup.cmdline('/', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = { { name = 'buffer' } },
})

-- `:` cmdline: path + cmdline completion
cmp.setup.cmdline(':', {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = 'path' }
  }, {
    {
      name = 'cmdline',
      option = {
        ignore_cmds = { 'Man', '!' }
      }
    }
  }),
})
```

Source-level options (`option` table):

| Option                 | Type       | Default          | Description |
|------------------------|------------|------------------|-------------|
| `treat_trailing_slash`| `boolean`  | `true`           | Strip trailing `/` from path completions so pressing `/` descends into the next directory. Excludes `~/`, `./`, and `../`. |
| `ignore_cmds`          | `string[]` | `{ 'Man', '!' }` | Commands for which completion is disabled. |

## Dependencies

- **Runtime dependency:** [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)
- **Optional runtime:** [cmp-buffer](https://github.com/hrsh7th/cmp-buffer) — required for `/` search completion to surface buffer words.

## Build / Test

No build step or test suite. Pure Lua plugin loaded by Neovim at runtime.

## Coding Conventions

- Single-file plugin; all logic is in `lua/cmp_cmdline/init.lua`.
- LuaCATS annotations (`---@class`, `---@param`) and `vim.validate` for option validation.
- Constants (default options, regex objects) are module-level locals.
- Class-style objects via `setmetatable({}, { __index = source })` with a `source.new()` constructor.
- Options are merged with `vim.tbl_deep_extend('keep', ...)`.
- Prefer `pcall` around functions that can throw (e.g. `vim.api.nvim_parse_cmd`, `vim.opt[word]:get()`).
