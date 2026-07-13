# cmp_luasnip

## Project Overview

cmp_luasnip is an [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) completion source for [LuaSnip](https://github.com/L3MON4D3/LuaSnip) snippets. It lists all snippets (regular snippets and, optionally, auto-snippets) available for the current filetype(s) as completion items and, when a snippet is selected, expands it in-place via `luasnip.snip_expand`, replacing the trigger word that was inserted by nvim-cmp.

## Directory Structure

```
cmp_luasnip/
├── LICENSE
├── README.md
├── stylua.toml               # Stylua formatter config (tabs, 120 col width, double quotes)
├── after/
│   └── plugin/
│       └── cmp_luasnip.lua   # Registers source + autocommands for cache invalidation
└── lua/
    └── cmp_luasnip/
        └── init.lua           # All source logic in a single file
```

## Core Module: `lua/cmp_luasnip/init.lua`

The entire source implementation lives in this single file and is returned as the module table. The nvim-cmp source object is created via `source.new()`.

### Module-level state

- `snip_cache` — table keyed by filetype; each value is a list of completion items for that filetype's snippets.
- `defaults` — table of default options (`use_show_condition = true`, `show_autosnippets = false`).
- `doc_cache` — table keyed by filetype then `snip_id`, caching rendered Markdown documentation strings.

### Source API

#### Cache management

- `source.clear_cache()` — wipes `snip_cache` and `doc_cache` entirely. Called on the `User LuasnipCleanup` autocommand.
- `source.refresh()` — clears the cache for the most recently loaded filetype (`luasnip.session.latest_load_ft`) from **both** `snip_cache` and `doc_cache`. Called on the `User LuasnipSnippetsAdded` autocommand.

#### nvim-cmp source methods

- `source:new()` — creates the source object via `setmetatable({}, { __index = source })`.
- `source:is_available()` — returns `true` if `pcall(require, "luasnip")` succeeds. The `pcall` ensures the source is silently unavailable when LuaSnip is not installed.
- `source:get_debug_name()` — returns `"luasnip"`.
- `source:get_keyword_pattern()` — returns the Lua string `"\\%([^[:alnum:][:blank:]]\\|\\w\\+\\)"`.
- `source:complete(params, callback)` — entry point for completion. Calls `init_options(params)` to merge defaults into `params.option` and validate it. Iterates all snippet filetypes via `luasnip.util.util.get_snippet_filetypes()`, builds items for each non-hidden snippet. Each item carries `word = trigger`, `label = trigger`, `kind = cmp.lsp.CompletionItemKind.Snippet`, and `data = { filetype, snip_id, show_condition, auto }`. Honors `show_autosnippets` and `use_show_condition` options.
- `source:resolve(completion_item, callback)` — fetches the snippet by id via `luasnip.get_id_snippet()`. On cache miss, builds Markdown documentation (header = `name _ [filetype]`, horizontal rule, description, and a code block of `snip:get_docstring()` rendered with the current buffer's filetype) using `vim.lsp.util.convert_input_to_markdown_lines`, caches it, and assigns it to `completion_item.documentation` with `kind = MarkupKind.Markdown`.
- `source:execute(completion_item, callback)` — expands the snippet. For regex-triggered snippets (`snip.regTrig`), uses `snip:get_pattern_expand_helper()` instead. Computes `clear_region` from the cursor position and `completion_item.word` length, then lets `snip:matches(line)` potentially override it (via `expand_params.clear_region` or `expand_params.trigger`). Calls `luasnip.snip_expand` with the resolved `clear_region` and `expand_params`.

### Option initialization (`init_options`)

Called at the start of every `complete` invocation:

```lua
params.option = vim.tbl_deep_extend('keep', params.option, defaults)
vim.validate({
    use_show_condition = { params.option.use_show_condition, 'boolean' },
    show_autosnippets  = { params.option.show_autosnippets,  'boolean' },
})
```

Note: the function reads/writes `params.option`, **not** `params.opts` (the comment in the source code is stale — `opts` was renamed to `option`). Users configure this via `option = { ... }` in the cmp source entry.

### Options

| Option               | Type      | Default | Description |
|----------------------|-----------|---------|-------------|
| `use_show_condition` | `boolean` | `true`  | Filter completion items by the snippet's `show_condition` predicate (passed the text before the cursor). |
| `show_autosnippets`  | `boolean` | `false` | Include LuaSnip auto-snippets in the completion list. Including them can be problematic because selecting the entry inserts the trigger text and the snippet fires automatically. |

## `after/plugin/cmp_luasnip.lua`

- Registers the `luasnip` source with nvim-cmp via `cmp.register_source("luasnip", require("cmp_luasnip").new())`.
- Creates the `cmp_luasnip` augroup with two autocommands:
  - `User LuasnipCleanup` → `clear_cache()`
  - `User LuasnipSnippetsAdded` → `refresh()`

## Configuration

```lua
local cmp = require('cmp')

cmp.setup {
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  sources = {
    { name = 'luasnip', option = {
      use_show_condition = true,
      show_autosnippets  = false,
    }},
    -- more sources
  },
}
```

Both options can be toggled. See the README for per-buffer disabling guidance.

## Dependencies

- **Runtime:** [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) — the consumer of this source.
- **Runtime:** [LuaSnip](https://github.com/L3MON4D3/LuaSnip) — the source is unavailable if LuaSnip is not installed.

## Build / Test

No build step or test suite. Pure Lua plugin loaded by Neovim at runtime.

## Coding Conventions

- Single-file plugin: all source logic lives in `lua/cmp_luasnip/init.lua`.
- Uses LuaCATS annotations (`---@param`, `---@return`).
- Module pattern: `local source = {}`, `source.new()` returns `setmetatable({}, { __index = source })`.
- Options merged with `vim.tbl_deep_extend('keep', ...)` and validated with `vim.validate`.
- Formatting enforced by [Stylua](https://github.com/JohnnyMorganz/StyLua) with the project's `stylua.toml`:
  - `column_width = 120`
  - `indent_type = "Tabs"`, `indent_width = 4`
  - `quote_style = "AutoPreferDouble"`
  - `line_endings = "Unix"`
  - `no_call_parentheses = false`
- Cache invalidation driven by LuaSnip user events (`LuasnipCleanup`, `LuasnipSnippetsAdded`) rather than polling.
- Completion items carry `data = { filetype, snip_id, show_condition, auto }` for use by `resolve` and `execute`.
