# copilot-cmp

## Project Overview

copilot-cmp is a Neovim plugin that transforms [zbirenbaum/copilot.lua](https://github.com/zbirenbaum/copilot.lua) into an [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) source. It makes GitHub Copilot suggestions appear inside the nvim-cmp completion menu and displays their full contents when hovered.

The core goal is seamless integration between Copilot's LSP-based suggestions and the standard Neovim completion framework, so users can see both LSP completions and AI completions in a single menu.

---

## Directory Structure

```
copilot-cmp/
├── LICENSE
├── README.md                        # Installation, configuration, and usage documentation
├── .stylua.toml                     # Formatter config (column_width: 120, indent_width: 2)
└── lua/
    └── copilot_cmp/
        ├── init.lua                 # Entry module: exposes setup() and source registration
        ├── source.lua               # nvim-cmp source implementation (complete/resolve/execute)
        ├── completion_functions.lua # Core method that communicates with Copilot to fetch completions
        ├── format.lua               # Converts Copilot completions into cmp item format
        ├── pattern.lua              # Suffix utility that fixes bracket pairing
        ├── comparators.lua          # Custom comparators (prioritize sorting)
        └── capabilities.lua         # Default LSP capabilities definition
```

---

## Core Modules

### `copilot_cmp.init` (entry point)

Exposed API:
- `setup(opts)` — Sets up the plugin. Registers autocommands for `InsertEnter`/`LspAttach` events and registers the cmp source for each active Copilot LSP client.
- `client_source_map` — Mapping of registered client IDs to their cmp sources.
- `registered` — Whether the source has already been registered.
- `default_capabilities(override)` — Returns default LSP completion capabilities.
- `update_capabilities(_, override)` — Deprecated; delegates to `default_capabilities`.

Default options:
```lua
{
  event = { "InsertEnter", "LspAttach" },
  fix_pairs = true,
}
```

### `copilot_cmp.source`

Implements the cmp source interface:
- `source.new(client, opts)` — Creates a source object bound to a given LSP client. Initializes a uv timer for async completion handling.
- `source:get_trigger_characters()` — Returns trigger characters `{'.'}`.
- `source:get_keyword_pattern()` — Returns `'.'`.
- `source:complete(params, callback)` — Requests completions from Copilot (delegates to `completion_functions.getCompletions`).
- `source:resolve(completion_item, callback)` — Resolves a completion item by running any registered execution functions.
- `source:execute(completion_item, callback)` — Executes a completion (pass-through).
- `source:is_available()` — Checks whether the Copilot client is active for the current buffer.
- `source.executions` — Table of post-processing functions applied during `resolve`. Empty by default; no public API to extend it.

### `copilot_cmp.completion_functions`

Core logic that bridges Copilot and cmp. Depends on `copilot.util.get_doc_params()` and `copilot.api.get_completions()` from copilot.lua.
- `methods.getCompletions(self, params, callback)` — Calls `api.get_completions` with document params, then formats each completion response via `format.format_item`.
- `methods.init(completion_method, opts)` — Sets `opts.fix_pairs` on the module and returns the requested completion method (e.g., `methods.getCompletions`).

### `copilot_cmp.format`

Responsible for transforming raw Copilot completions into cmp item format:
- `format.format_item(item, ctx, opts)` — Main formatter. Applies `fix_pairs`, builds multi-line output, and returns a cmp item with:
  - `copilot = true` (used by the comparator)
  - `score = item.score`
  - `cmp.kind_hl_group = "CmpItemKindCopilot"` and `cmp.kind_text = "Copilot"` (for lspkind)
  - `textEdit` with `newText`, `insert`, and `replace` ranges
  - `documentation` as a markdown code block of the filetype and preview text
  - `dup = 0` (do not deduplicate Copilot items)
- `format.to_multi_line(item, ctx)` — Handles alignment, indentation (respects `expandtab`/`shiftwidth`), label abbreviation (text > 40 chars becomes `first 20 ... last 15`), and computes insert/replace ranges.
- `format.deindent(text, user_indent)` — Strips the common leading indent from `text` and optionally re-applies `user_indent`.
- `format.add_indent(text, user_indent, indent_level)` — Prepends `indent_level` copies of `user_indent` to every line.
- `format.remove_leading_whitespace(text)` — Removes leading whitespace.
- `format.split(inputstr, sep)` — Splits a string by `\n`, `\r`, or a custom separator.
- `format.get_indent_string(text)` / `format.get_newline_char(text)` — Indent and newline detection helpers.
- `format.get_indent_offset(text)` — Returns the number of leading whitespace characters.
- `label_text(text)` (local) — Abbreviates long labels for display in the completion menu.

### `copilot_cmp.pattern`

Implements the `fix_pairs` feature, which addresses the case where Copilot tries to account for existing surrounding brackets. When the text after the cursor contains closing brackets whose matching opening bracket appears in the completion text (but the closing one does not), the missing closing bracket is appended so that completion does not strip characters typed after the cursor.
- `pattern.set_suffix(text, line_suffix)` — Iterates over characters in `line_suffix`; when a character has a defined bracket pair and the completion already contains the opening bracket but not the closing one, the closing bracket is appended to the completion text.

### `copilot_cmp.comparators`

Custom cmp sorting comparators:
- `comparators.prioritize(entry1, entry2)` — Places Copilot completions above other completions when both are compared.
- `comparators.score(entry1, entry2)` — Orders entries by their Copilot `score` field (used for Copilot-to-Copilot comparisons).

### `copilot_cmp.capabilities`

- `M.default_capabilities(override)` — Returns the default client capabilities object (mirrors `cmp-nvim-lsp` defaults), with fields like `snippetSupport`, `deprecatedSupport`, `preselectSupport`, etc. Accepts an `override` table to customize values.
- `M.update_capabilities(_, override)` — Deprecated wrapper that emits a `vim.deprecate` warning and delegates to `default_capabilities`. Will be removed in copilot_cmp 1.0.0.

---

## Configuration

### Installation

Using any package manager:
```lua
-- lazy.nvim
{
  "zbirenbaum/copilot-cmp",
  config = function()
    require("copilot_cmp").setup()
  end,
}

-- packer
use {
  "zbirenbaum/copilot-cmp",
  after = { "copilot.lua" },
  config = function()
    require("copilot_cmp").setup()
  end,
}
```

### Disabling copilot.lua's Built-in Suggestions (Recommended)

To avoid conflicts, disable copilot.lua's `suggestion` and `panel` modules:
```lua
require("copilot").setup({
  suggestion = { enabled = false },
  panel = { enabled = false },
})
```

### Integration with nvim-cmp

#### Source Registration

```lua
cmp.setup {
  sources = {
    { name = "copilot", group_index = 2 },
    { name = "nvim_lsp", group_index = 2 },
    { name = "path", group_index = 2 },
    { name = "luasnip", group_index = 2 },
  },
}
```

#### Highlighting & Icon

Copilot's cmp source defines the highlight group `CmpItemKindCopilot`. With lspkind:
```lua
local lspkind = require("lspkind")
lspkind.init({
  symbol_map = {
    Copilot = "",
  },
})
vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" })
```

Without lspkind, add the custom icon in your cmp `format` function in the usual way for any other `kind`.

#### Tab Completion Configuration (Recommended)

Because Copilot may suggest completions for blank lines (using surrounding context), naive `<TAB>` mapping can be problematic. The following snippet makes `<TAB>` select a completion only when a non-whitespace word precedes the cursor; otherwise it falls back to indenting:

```lua
local has_words_before = function()
  if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then return false end
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_text(0, line - 1, 0, line - 1, col, {})[1]:match("^%s*$") == nil
end

cmp.setup({
  mapping = {
    ["<Tab>"] = vim.schedule_wrap(function(fallback)
      if cmp.visible() and has_words_before() then
        cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
      else
        fallback()
      end
    end),
  },
})
```

#### Comparators

Use the `prioritize` comparator to rank Copilot entries above other sources. Enable `priority_weight = 2` and place cmp's `exact` comparator before `prioritize` so better LSP matches are not stuck below Copilot matches:

```lua
cmp.setup {
  sorting = {
    priority_weight = 2,
    comparators = {
      require("copilot_cmp.comparators").prioritize,
      -- default nvim-cmp comparators follow
      cmp.config.compare.offset,
      cmp.config.compare.exact,
      cmp.config.compare.score,
      cmp.config.compare.recently_used,
      cmp.config.compare.locality,
      cmp.config.compare.kind,
      cmp.config.compare.sort_text,
      cmp.config.compare.length,
      cmp.config.compare.order,
    },
  },
}
```

### copilot-cmp Options

It is **heavily discouraged** to modify default settings without a known issue requiring it.

```lua
{
  event = { "InsertEnter", "LspAttach" },
  fix_pairs = true,
}
```
- `event` — When the source is registered. Tweak only if your setup has unusual autocommand requirements.
- `fix_pairs` — When the completion text contains an open bracket whose matching close bracket appears in the text after the cursor (but not in the completion itself), the missing closing bracket is appended. Fixes the case where Copilot would otherwise suggest `print('hello` and delete the closing `')` on accept.

---

## Dependencies

### Required
- **[copilot.lua](https://github.com/zbirenbaum/copilot.lua)** — Provides the Copilot LSP client, authentication, and editor communication. `completion_functions.lua` relies on `copilot.util.get_doc_params` and `copilot.api.get_completions` from this plugin.
- **[nvim-cmp](https://github.com/hrsh7th/nvim-cmp)** — Neovim completion framework into which copilot-cmp registers as a source.

### Optional
- **[lspkind.nvim](https://github.com/onsails/lspkind.nvim)** — Only used for the Copilot icon; not required.

### Relationship
- copilot-cmp is the official recommended nvim-cmp integration for copilot.lua.
- All completion logic ultimately requests Copilot suggestions through copilot.lua's API.

---

## Code Style

### Formatting
The project uses `.stylua.toml` at the repo root:
- `column_width = 120`
- `indent_type = "Spaces"`
- `indent_width = 2`
- `quote_style = "AutoPreferDouble"`
- `no_call_parentheses = false` (parentheses are kept on calls)

### Naming Conventions
- Modules are required with the local assignment pattern: `local name = require("module.name")`
- Module tables are typically named `M` (e.g., `local M = {}`)
- Methods are defined in two styles:
  - `function modulename:name(self, ...)` (colon method syntax)
  - `modulename.name = function(...)` (dot assignment syntax)
- Module-level state tables are sometimes named `methods` (in `completion_functions.lua`) or `source` (in `source.lua`).

### Comments & Documentation
- All public functions have LuaDoc-style comments (`--- ...`).
- Type aliases are declared with `---@alias`.
- Behavioral notes (deprecations, edge cases) are documented above relevant functions.

### Compatibility & Async Patterns
- API backward compatibility between Neovim 0.8 and 0.9+ is handled via fallback patterns:
  - `vim.lsp.get_clients` (0.9+) with fallback to `vim.lsp.get_active_clients()` (0.8).
  - `vim.loop.new_timer()` is used for enabling async callbacks in cmp completion.

---

## Build / Test

There is no formal CI or test suite. Contributions are maintained through manual review and community feedback. Code style is checked via `stylua`.
