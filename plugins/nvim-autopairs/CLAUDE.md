# nvim-autopairs

## Overview

nvim-autopairs is a powerful, extensible autopair plugin for Neovim (requires 0.7+) by windwp. It automatically inserts and manages paired characters (brackets, quotes, backticks, HTML tags, etc.) in insert mode.

- **Core features:**
  - Pair insert / move / delete: typing an opening char auto-inserts the closing char, repeating a closing char skips over it, `<BS>` deletes a pair
  - **Endwise rules:** auto-append a closing keyword (`end`, `}`) after block-opening patterns in Ruby / Lua / Elixir
  - **Treesitter integration:** when `check_ts = true`, node-aware conditions prevent pairing inside strings / comments
  - **FastWrap:** `<M-e>` moves a closing bracket to the end of an expression, with highlighted jump positions
  - **Completion integration:** integrates with nvim-cmp and legacy compe to auto-insert `(` after completing a function / method
  - **Pair-after-quote:** insert a bracket before a quote and it auto-closes after the closing quote
  - Regex rules, multibyte characters, undo sequence breaks, per-filetype enable / disable

## Directory Structure

```
nvim-autopairs/
├── README.md, LICENSE, Makefile, style.toml, .editorconfig, .luarc.json
├── doc/                          # Vim help docs
├── .github/                      # CI workflows
├── lua/
│   ├── nvim-autopairs.lua        # main module (NOTE: no init.lua)
│   └── nvim-autopairs/
│       ├── _log.lua              # plenary.log wrapper
│       ├── rule.lua              # Rule class
│       ├── conds.lua             # condition function factory
│       ├── utils.lua             # helpers, keycode constants
│       ├── fastwrap.lua          # FastWrap feature
│       ├── ts-rule.lua           # endwise helper
│       ├── ts-conds.lua          # Treesitter conditions
│       ├── ts-utils.lua          # Treesitter helpers
│       ├── rules/
│       │   ├── basic.lua         # default rules + creators
│       │   ├── ts_basic.lua      # TS-enhanced rules
│       │   └── endwise-{ruby,lua,elixir}.lua  # endwise rule sets
│       └── completion/
│           ├── cmp.lua           # nvim-cmp integration
│           ├── compe.lua         # legacy compe integration
│           └── handlers.lua      # completion handlers
└── tests/
    ├── minimal.vim, test_utils.lua
    ├── nvim-autopairs_spec.lua   # main test suite
    ├── afterquote_spec.lua, endwise_spec.lua
    ├── treesitter_spec.lua, utils_spec.lua, fastwrap_spec.lua
    └── endwise/ (init.lua, ruby.rb, sample.lua, sample.md, main.rs)
```

**Note:** The main module is `lua/nvim-autopairs.lua` (there is no `init.lua`); `require('nvim-autopairs')` resolves to it. Sub-modules live under `lua/nvim-autopairs/` (e.g. `require('nvim-autopairs.rule')`).

## Core Modules

### `nvim-autopairs` (nvim-autopairs.lua) — main singleton `M` table

| Member | Description |
|---|---|
| `state` | `{disabled, rules, buf_ts}`; `ts_node` and `expr_quote` are added dynamically at runtime |
| `config` | merged options |
| `setup(opt)` | entry point: merges defaults, sets up rules, TS, `<CR>` mapping, autocommands |
| `add_rule` / `add_rules` / `get_rule(s)` / `remove_rule` / `clear_rules` | rule management |
| `disable` / `enable` / `force_attach` | enable / disable control |
| `get_buf_rules` / `set_buf_rule` / `on_attach` | buffer-scoped operations |
| `autopairs_map` / `autopairs_insert` / `autopairs_bs` / `autopairs_c_h` / `autopairs_c_w` | core mapping logic |
| `autopairs_cr` / `autopairs_afterquote` / `autopairs_closequote_expr` | enter / post-quote handling |
| `check_break_line_char` / `completion_confirm` / `map_cr` / `esc` | helpers |

Key behaviors inside `on_attach`:
- Rules are sorted by pair length (longer first), then by keymap length.
- Non-regex rules with a `key_map` get buffer-local expr keymaps; the end char is also mapped when `move_cond` is set.
- Regex rules with an empty `key_map` fall back to an `InsertCharPre` autocommand (`autopairs_insert`) to trigger pairing on any typed char.
- `<BS>`, `<C-h>`, `<C-w>` are mapped conditionally based on `map_bs` / `map_c_h` / `map_c_w`.

`is_disable()` (local) returns true when: disabled flag is set, buffer is a floating window with no filetype, buffer is non-modifiable, macro recording/executing (`disable_in_macro`), replace mode (`disable_in_replace_mode`), visual-block mode (`disable_in_visualblock`), or filetype is in `disable_filetype`.

### `rule.lua` — Rule class

Callable constructor via metatable, with a fluent builder API:

- `Rule.new(...)` / `Rule(...)` — accepts `(start, end, filetypes)` or a table
- Builder methods: `use_regex`, `use_key`, `use_undo`, `use_multibyte`, `replace_endpair`, `replace_map_cr`, `set_end_pair_length`, `with_move/del/cr/pair`, `only_cr`, `end_wise`
- Query methods: `get_end_pair`, `get_map_cr`, `get_end_pair_length`, `can_pair/move/del/cr`

`end_wise(cond)` sets `is_endwise = true` and delegates to `only_cr(cond)` (clears `key_map`, disables pair/move/del). `use_multibyte()` auto-detects multibyte pairs and sets `key_map` / `key_end` from the trailing UTF-8 char.

### `conds.lua` — condition factory

Each returns a closure over `CondOpts` (`ts_node, text, rule, bufnr, col, char, line, prev_char, next_char`). Conditions return `true` (pass), `false` (block), or `nil` (undecided). Available conditions: `none`, `done`, `invert`, `before_regex/text`, `after_regex/text`, `not_before/after_regex/text`, `is_bracket_line`, `is_bracket_line_move`, `not_inside_quote`, `is_inside_quote`, `not_add_quote_inside_quote`, `move_right`, `is_end_line`, `is_bracket_in_quote`, `not_filetypes`, `not_before_char`. Deprecated aliases (`*_check`) are kept for backward compatibility.

### `utils.lua` — helpers

`M.key` keycode constants (`del`, `bs`, `c_h`, `left`, `right`, `join_left`, `join_right`, `undo_sequence`, `noundo_sequence`, `abbr`) plus helpers: `is_quote/bracket/close_bracket`, `compare`, `is_in_quotes`, `is_attached/set_attach`, `is_in_table`, `check_filetype/check_not_filetype`, `is_in_range`, `get_cursor`, `text_get_line/text_get_current_line`, `repeat_key`, `text_cusor_line`, `text_sub_char`, `insert_char`, `set_vchar`, `feed`, `esc`, `is_block_wise_mode`, `get_prev_char`.

### `fastwrap.lua` — FastWrap feature

`M.setup(cfg)` merges the default config and stores it on `npairs.config.fast_wrap`. `M.show()` renders an extmark-based jump UI (`ns_fast_wrap` namespace), then reads a target key and moves the bracket. Also exports `getchar_handler`, `choose_pos`, `move_bracket`, `highlight_wrap`. Default config: `map = '<M-e>'`, `chars = { '{', '[', '(', '"', "'" }`, `pattern = [=[[%'%"%>%]%)%}%,%`]]=]`, `end_key = '$'`, `before_key = 'h'`, `after_key = 'l'`, `cursor_pos_before = true`, `keys = 'qwertyuiopzxcvbnmasdfghjkl'`, `highlight = 'Search'`, `highlight_grey = 'Comment'`, `manual_position = true`, `use_virt_lines = true`.

### `ts-rule.lua` — endwise helper

`endwise(...)` helper: builds a regex `Rule` chained with `:end_wise(cond.is_end_line())`, optionally adding a TS node check (`is_ts_node`) as a fourth argument.

### `ts-conds.lua` — TS-aware conditions

`is_endwise_node`, `is_in_range`, `is_ts_node`, `is_not_ts_node`, `is_not_ts_node_comment`, `is_not_in_context`. These use `nvim-treesitter.parsers` and `ts_utils`.

### `ts-utils.lua` — Treesitter helpers

`get_language_tree_at_position`, `get_tag_name`.

### `rules/basic.lua` — default rules

`setup(opt)` returns the default rule table; also exports `quote_creator` and `bracket_creator`. Includes rules for `<!-- -->`, triple-backtick fences, `"""` / `'''`, quotes (with filetype exclusions for rust / nix / vim), brackets `(`, `[`, `{`, and an HTML autotag regex rule.

### `rules/ts_basic.lua` — TS-enhanced rules

`setup(config)` extends the basic rules, adding `is_not_ts_node_comment()` to quote and bracket rules (`'`, `"`, `(`, `[`, `{`, `` ` ``).

### `completion/cmp.lua` — nvim-cmp integration

`M.on_confirm_done(opts)` returns a cmp `confirm_done` callback; contains a default `filetypes` map (`*`, python, clojure, clojavascript, fennel, janet, and disabled tex / shell / nix entries).

### `completion/handlers.lua` — completion handlers

Handlers `["*"]`, `lisp`, `python` for inserting a pair after a completion item.

### `completion/compe.lua` — legacy compe integration

`completion_done`, `setup`.

### `_log.lua` — logging

Returns a `plenary.log` logger when `_G.__is_log` is set (level `debug` if `true`, otherwise `warn`); otherwise returns a no-op stub.

## Configuration

Configured via `require('nvim-autopairs').setup(config)`.

| Option | Default | Description |
|---|---|---|
| `disable_filetype` | `{"TelescopePrompt","spectre_panel"}` | disabled filetypes |
| `disable_in_macro` | `true` | disable when recording / executing a macro |
| `disable_in_visualblock` | `false` | disable after visual-block mode |
| `disable_in_replace_mode` | `true` | disable in replace mode |
| `ignored_next_char` | `[=[[%w%%%'%[%"%.%`%$]]=]` | skip pairing when next char matches |
| `enable_moveright` | `true` | move right on repeated closing char |
| `enable_afterquote` | `true` | pair after quote |
| `enable_check_bracket_line` | `true` | same-line balance check |
| `enable_bracket_in_quote` | `true` | allow brackets inside quotes |
| `enable_abbr` | `false` | trigger abbreviation |
| `break_undo` | `true` | break the undo sequence |
| `check_ts` | `false` | enable Treesitter checking |
| `map_cr` / `map_bs` / `map_c_h` / `map_c_w` | `true/true/false/false` | keymap toggles |
| `ts_config` | `{lua={"string","source","string_content"}, javascript={"string","template_string"}}` | suppressed TS node types |
| `fast_wrap` | `nil` | FastWrap config |

**Rule system:** `Rule(start_pair, end_pair, filetypes?)` with fluent conditions. Filetypes support a `-vim` negation syntax (moved to `not_filetypes`). Rules are sorted by pair length and attached per buffer via expr keymaps; regex rules fall back to an `InsertCharPre` autocommand.

## Dependencies

- **No dependencies for core functionality** — pure Neovim API
- **Optional:** `nvim-treesitter` (parsers, `ts_utils`, `vim.treesitter`), required when `check_ts = true` or using `ts-conds` / `ts-rule`
- **Optional:** `nvim-cmp` (completion/cmp.lua) or legacy `compe` (completion/compe.lua)
- **Dev / test:** `plenary.nvim` (busted test runner + logging), `nvim-treesitter`, `playground`

## Build / Test

- **Runner:** Plenary busted (`plenary.busted` / `PlenaryBustedDirectory`)
- **`tests/minimal.vim`:** headless init; adds plenary, nvim-treesitter, playground to rtp; sets `_G.__is_log = true`, calls `nvim-autopairs.setup()`
- **`tests/test_utils.lua`:** defines globals `eq`, `Test_filter` (supports `only = true` to run a single case), `Test_withfile` (primary test utility — sets buffer lines, cursor, feeds keys, asserts resulting lines + cursor position via `|` markers)
- **Test files:** use `describe` + `_G.Test_withfile`. Cases are tables with `name, key, before, after, filetype, linenr, setup_func, end_cursor`
- **Makefile:**
  - `make test` → run the full suite
  - `make test-file FILE=...` → run a single spec

## Coding Conventions

- Module-level singleton `M = {}` returned by each module
- **PascalCase classes:** `Rule`, `Cond` (documented with `---@class` annotations)
- **snake_case** for functions, options, and fields
- **Rule fields:** `start_pair`, `end_pair`, `key_map`, `key_end`, `filetypes`, `not_filetypes`, `is_regex`, `is_endwise`, `is_undo`, `is_multibyte`, `move_cond/del_cond/cr_cond/pair_cond`
- **Builder methods** are verb phrases: `with_*`, `use_*`, `replace_*`, `only_cr`, `end_wise`
- **Conditions** named by intent: `none/done/move_right/not_inside_quote/is_bracket_line/...`
- **File naming:** rule files use hyphens (`endwise-ruby.lua`, `ts_basic.lua`); `completion/` subdirectory for integrations
- **Test case naming:** numbered strings (`"1 add normal bracket"`); use `only = true` to isolate a single case
- Heavy use of `---@param` / `---@class` / `---@return` type annotations (for LuaLS)
