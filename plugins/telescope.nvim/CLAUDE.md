# telescope.nvim

## Project Overview

`telescope.nvim` is a highly extendable fuzzy finder over lists for Neovim. Built on the latest Neovim core features, with a modular design centered around pluggable pickers, sorters, and previewers. Community-driven extension system.

Slogan: "Find, Filter, Preview, Pick. All lua, all the time."

Requires Neovim >= 0.7.0.

Primary data flow:

```
Finder generates raw results
  -> Entry Maker builds entries (value, ordinal, display)
    -> Sorter scores & filters entries
      -> Picker displays results, handles UI & prompt
        -> Previewer shows context for the selected entry
          -> Actions respond to user selections
```

## Required & Optional Dependencies

- **Required (hard):** [`plenary.nvim`](https://github.com/nvim-lua/plenary.nvim) (provides `Job`, `popup`, `async`, `plenary.path`, `plenary.log`, `plenary.class`)
- **Recommended (external tools):** [`ripgrep`](https://github.com/BurntSushi/ripgrep) for `live_grep` / `grep_string`; [`fd`](https://github.com/sharkdp/fd) for faster `find_files`
- **Recommended (native sort):** [`telescope-fzf-native.nvim`](https://github.com/nvim-telescope/telescope-fzf-native.nvim) or [`telescope-fzy-native.nvim`](https://github.com/nvim-telescope/telescope-fzy-native.nvim)
- **Optional:** [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) for previewer highlighting; [`nvim-web-devicons`](https://github.com/nvim-tree/nvim-web-devicons) for file icons
- **Legacy deprecation shim:** [`scm-nvim/scm.nvim`? — not actually a dependency]

## Directory Structure

```
telescope.nvim/
├── lua/telescope/
│   ├── init.lua                 # Entry: setup() / load_extension() / register_extension()
│   ├── config.lua               # Defaults, picker per-config, and option docs (telescope_defaults)
│   ├── config/
│   │   └── resolve.lua          # Resolves height/width/position values for layouts
│   ├── pickers.lua              # Picker class: UI, event loop, layout orchestration
│   ├── pickers/
│   │   ├── entry_display.lua    # Column-based entry display builder
│   │   ├── highlights.lua       # Highlights for selection / match / multiline
│   │   ├── layout_strategies.lua # horizontal/vertical/center/cursor/flex/bottom_pane adapters
│   │   ├── multi.lua            # MultiSelect helper
│   │   ├── scroller.lua         # Scroll logic (cycle / limit)
│   │   └── window.lua           # Window setup helpers (prompt/results/preview)
│   ├── finders.lua              # JobFinder base class + async variants
│   ├── finders/
│   │   ├── async_job_finder.lua      # Async job-based finder (lines over libuv pipe)
│   │   ├── async_oneshot_finder.lua   # Runs a command once, parses output after EOF
│   │   └── async_static_finder.lua    # Drives an async fn, no external job
│   ├── sorters.lua              # Sorter class + built-in sorters (fzy, prefilter, empty, substring, ...)
│   ├── entry_manager.lua        # Scored entry ring buffer backed by LinkedList
│   ├── make_entry.lua           # `gen_from_*` entry-maker factories (files, git, lsp, vimgrep, …)
│   ├── from_entry.lua           # Extractors: from_entry.path / .file / .filename / .bufnr / .uri / ...
│   ├── previewers/
│   │   ├── init.lua             # Previewer registry + wrappers (cat/vimgrep/qflist/vim_buffer_*)
│   │   ├── previewer.lua        # Previewer base interface (`:new`/`:preview`/`:teardown`/…)
│   │   ├── buffer_previewer.lua # Buffer-backed preview (file/BAT/treesitter highlighting)
│   │   ├── term_previewer.lua   # Terminal-based preview (termopen wrappers)
│   │   └── utils.lua            # Preview helpers (set_preview_message, flush / mime, …)
│   ├── actions/
│   │   ├── init.lua             # Core actions: select, send_to_qflist, cycle_history, close, center, which_key, delete_buffer, …
│   │   ├── set.lua              # `set.select` / `set.edit` / `shift_selection` / scroll helpers
│   │   ├── state.lua            # Read-only state accessors (get_selected_entry, get_current_picker, get_current_line, …)
│   │   ├── utils.lua            # map_entries, get_registered_mappings, edit helpers
│   │   ├── generate.lua         # `action_generate.which_key` / `action_generate.refine`
│   │   ├── history.lua          # `History` class + `get_simple_history` (pluggable handler via `defaults.history.handler`)
│   │   ├── layout.lua           # toggle_preview / toggle_prompt_position / toggle_mirror / cycle_layout_*
│   │   └── mt.lua               # Action metatable: enables `+` composition, `:replace`, `:replace_if`, `:enhance`
│   ├── mapping.lua              # Key map parsing / attach_mappings glue
│   ├── themes.lua               # get_dropdown / get_cursor / get_ivy
│   ├── builtin/
│   │   ├── init.lua             # `require_on_exported_call` wrapper, list of every builtin picker
│   │   ├── __internal.lua       # buffers, oldfiles, colorscheme, help_tags, man_pages, commands, …
│   │   ├── __files.lua          # find_files, live_grep, grep_string, treesitter, tags, current_buffer_fuzzy_find, …
│   │   ├── __git.lua            # git_files, git_commits, git_bcommits, git_branches, git_status, git_stash
│   │   ├── __lsp.lua            # lsp_references, lsp_incoming_calls, lsp_outgoing_calls, lsp_definitions, …
│   │   └── __diagnostics.lua    # diagnostics
│   ├── _extensions/
│   │   └── init.lua             # extension manager (_loaded / _config / _health tables, lazy load)
│   ├── algos/
│   │   ├── linked_list.lua      # Doubly-linked list (used by EntryManager)
│   │   ├── fzy.lua              # Same algorithm as `fzy` (Lua port, used as default sorter)
│   │   └── string_distance.lua  # Levenshtein-style helpers
│   ├── command.lua              # `:Telescope` command parser (VimL -> Lua)
│   ├── utils.lua                # Shared helpers (notifications, path joins, OS command output, …)
│   ├── debounce.lua             # Debounce helper
│   ├── state.lua                # Global TelescopeGlobalState store: set/get status + global keys (cached_pickers, …)
│   ├── health.lua                # `:checkhealth telescope` implementation
│   ├── deprecated.lua           # Option deprecation warnings (currently a near-empty shim)
│   ├── log.lua                  # Thin wrapper around `plenary.log`
│   ├── _.lua                    # libuv-based Job + pipe abstractions (LinesPipe / NullPipe / ChunkPipe / ErrorPipe)
│   └── tests/                   # plenary.busted specs (automated/, pickers/, helpers.lua)
├── plugin/telescope.lua          # Bootstrap: highlights + `:Telescope` user command + `<Plug>(TelescopeFuzzyCommandSearch)`
├── ftplugin/                     # `TelescopePrompt` / `TelescopeResults` / `TelescopePreview` buflocal settings
├── scripts/
│   ├── gendocs.lua               # Re-generates `doc/` from EmmyLua annotations
│   └── minimal_init.vim          # Headless Neovim init for tests / doc gen
├── doc/                          # Vim help docs (auto-generated, do not edit by hand)
├── autoload/                     # VimScript helpers
├── data/telescope-sources/       # Built-in symbol data (telescope-symbols.nvim)
├── Makefile                      # `test` / `lint` / `docgen` targets
├── CONTRIBUTING.md
├── developers.md                 # Developer guide (theme, action, picker recipes)
└── LICENSE                       # MIT
```

## Core Modules

### `telescope` (`init.lua`)

- `telescope.setup(opts)` — Merges `defaults`, `pickers`, `extensions` into globals. Invalid keys (e.g. `default` instead of `defaults`) raise an error.
- `telescope.load_extension(name)` — Calls the extension's `setup` and returns its `exports`.
- `telescope.register_extension(mod)` — Identity function kept for API symmetry; extensions are loaded lazily via `_extensions.manager`'s `__index`.
- `telescope.extensions` — Proxy table that lazy-requires `telescope._extensions.<name>`.

### `telescope.config`

- `config.values` — Current merged defaults (`_TelescopeConfigurationValues`, survives `:luafile reload`).
- `config.set_defaults(user_defaults)` — Re-merges user top-level options; uses `first_non_null` and `smarter_depth_2_extend`.
- `config.set_pickers(pickers)` — Per-picker overrides stored on `_TelescopeConfigurationPickers`.
- `telescope.config.resolve` — Resolves "0-1 percentage", "int pixels", or "function" specifiers to concrete dimensions.

Valid top-level setup keys: `defaults`, `pickers`, `extensions`.

### `telescope.pickers`

`Picker:new(opts)` constructs a picker. Required fields:

- `finder` — data source (required; assert fires if missing)
- `sorter` — defaults to `sorters.empty()` if omitted
- `previewer` — buffer / termopen / custom previewer instance
- Prompt, results, preview: managed by `p_window`

Other notable fields: `prompt_title`, `results_title`, `prompt_prefix`, `selection_caret`, `entry_prefix`, `multi_icon`, `initial_mode`, `debounce`, `default_text`, `get_status_text`, `on_input_filter_cb`, `get_selection_window`, `attach_mappings`, `default_selection_index`, `current_previewer_index`.

### `telescope.finders`

- `JobFinder` — synchronous-style external command driven by `plenary.job`. Supports `writer` (piped input) and `maximum_results`.
- `AsyncJobFinder` — async variant using libuv pipes (`_.lua` LinesPipe/ChunkPipe).
- `AsyncOneshotFinder` — runs a command once, parses output after EOF.
- `AsyncStaticFinder` — drives an async Lua function (no external process).

### `telescope.sorters`

`Sorter:new(opts)` — base class. Key fields: `scoring_function`, `filter_function`, `highlighter`, `discard`, `tags`, `init/start/finish/destroy` hooks. Built-in factories: `get_fzy_sorter`, `get_generic_fzy_sorter`, `get_substr_matcher`, `prefilter`, `empty`, `get_levenshtein_sorter`, `get_fzy_sorter` (native override when fzf-native is installed).

### `telescope.actions`

Actions are either plain functions `(prompt_bufnr) -> …` or "action" objects produced by `actions.mt.transform_mod`. Action objects support:

- `a + b` — chain (runs `a` then `b`)
- `:replace(fn)` — swap the function for the current picker session
- `:replace_if(cond, fn)` — conditional swap
- `:replace_map({[cond] = fn, …})` — multi-branch swap
- `:enhance({pre, post})` — run hooks before/after

Built-in actions (selected highlights):

- Selection: `move_selection_next/previous/better/worse`, `move_to_top/middle/bottom`, `add/remove/toggle_selection`, `select_all/drop_all/toggle_all`
- Opening: `select_default`, `select_horizontal/vertical/tab`, `file_edit/split/vsplit/tab`
- Preview: `preview_scrolling_up/down`, `results_scrolling_up/down`, `cycle_previewers_next/prev`
- Lists: `send_selected_to_qflist`, `add_selected_to_qflist`, `send_to_qflist`, `add_to_qflist`, `smart_send_to_qflist`, `smart_add_to_qflist`, plus `*_loclist` variants
- History: `cycle_history_next/prev`
- Git: `git_create_branch`, `git_apply_stash`, `git_checkout`, `git_switch_branch`, `git_track_branch`, `git_delete_branch`, `git_merge_branch`, `git_rebase_branch`, `git_reset_mixed/soft/hard`, `git_checkout_current_buffer`, `git_staging_toggle`
- Misc: `close`, `center`, `edit_command_line`, `set_command_line`, `edit_search_line`, `set_search_line`, `edit_register`, `paste_register`, `insert_symbol`, `insert_symbol_i`, `insert_value`, `delete_buffer`, `complete_tag`, `open_qflist`, `open_loclist`, `which_key`, `remove_selected_picker`

### `telescope.builtin`

Every picker is exposed via `require_on_exported_call`, which returns a proxy that lazy-requires the underlying module on first call. Pickers are grouped by file:

- **Files** (`__files.lua`): `find_files` (alias `fd`), `live_grep`, `grep_string`, `treesitter`, `current_buffer_fuzzy_find`, `tags`, `current_buffer_tags`
- **Git** (`__git.lua`): `git_files`, `git_commits`, `git_bcommits`, `git_branches`, `git_status`, `git_stash`
- **LSP** (`__lsp.lua`): `lsp_references`, `lsp_incoming_calls`, `lsp_outgoing_calls`, `lsp_definitions`, `lsp_type_definitions`, `lsp_implementations`, `lsp_document_symbols`, `lsp_workspace_symbols`, `lsp_dynamic_workspace_symbols`
- **Diagnostics** (`__diagnostics.lua`): `diagnostics`
- **Internal / Vim** (`__internal.lua`): `builtin`, `resume`, `pickers`, `planets`, `symbols`, `commands`, `quickfix`, `quickfixhistory`, `loclist`, `oldfiles`, `command_history`, `search_history`, `vim_options`, `help_tags`, `man_pages`, `reloader`, `buffers`, `colorscheme`, `marks`, `registers`, `keymaps`, `filetypes`, `highlights`, `autocommands`, `spell_suggest`, `tagstack`, `jumplist`

### `telescope.themes`

Pre-baked UI presets that merge with user opts via `vim.tbl_deep_extend("force", …)`:

- `get_dropdown(opts)` — centered, short, `sorting_strategy = "ascending"`
- `get_cursor(opts)` — floating window at cursor
- `get_ivy(opts)` — bottom-pane Ivy-style layout

## Configuration

```lua
require('telescope').setup {
  defaults = {
    layout_strategy = 'horizontal',
    sorting_strategy = 'descending',
    layout_config = { width = 0.8, height = 0.9 },
    mappings = {
      i = {
        ['<esc>'] = require('telescope.actions').close,
      },
    },
  },
  pickers = {
    find_files = { hidden = true },
  },
  extensions = {
    fzf = { fuzzy = true },
  },
}
```

Extension module interface:

```lua
return require('telescope').register_extension {
  setup = function(ext_config, config) end,
  exports = { my_picker = function(opts) end },
  health = function() end,
}
```

## Build / Test / Lint

- `make test` — runs `PlenaryBustedDirectory lua/tests/automated/` with `scripts/minimal_init.vim`
- `make lint` — `luacheck lua/telescope` (config in `.luacheckrc`)
- `make docgen` — regenerates `doc/` from EmmyLua annotations via `scripts/gendocs.lua`

## Coding Conventions

- Lua formatted with **Stylua** (config: `.stylua.toml`)
- Static analysis with **luacheck** (config: `.luacheckrc`)
- EmmyLua-style annotations: `---@class`, `---@field`, `---@param`, `---@return`, `---@tag`, `---@config`, `---@brief`, `---@eval`, `---@deprecated`
- Built-in pickers use lazy loading via `require_on_exported_call` (metatable `__index` proxy)
- Global state persisted in `_TelescopeConfigurationValues` / `_TelescopeConfigurationPickers` (config) and `TelescopeGlobalState` (runtime state)
- Actions are transformed with `actions.mt.transform_mod` to enable `+` composition and `:replace`/`:enhance`
- Highlight groups are defined in `plugin/telescope.lua` and linked to standard groups by default
- `:Telescope` command is parsed in `command.lua`; tab completion covers builtins, extensions, and option keys
- Deprecations are surfaced via `deprecated.options` (currently a near-empty shim; most migrations are documented in `doc/telescope_changelog.txt`)
