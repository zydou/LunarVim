# neo-tree.nvim

A Neovim tree viewer / file explorer that replaces `netrw`. Renders hierarchical sources (file system, open buffers, git status, document symbols, and third-party plugins) as sidebars, floating windows, or netrw-style (`position = "current"`) splits. Design pillars: zero hard breaking changes (opt-in branches), smooth UX (no glitchy sidebars), and deep respect for project tooling (git status, `.gitignore`, libuv watcher).

Public top-level module: `require("neo-tree")`. Programmable entry point: `require("neo-tree.command").execute({...})`.

## Directory Structure

```
neo-tree.nvim/
├── plugin/neo-tree.vim           # :Neotree user command (global, with -complete=custom)
├── lua/neo-tree/
│   ├── lua                       # Top-level public API: setup, show_logs, get_prior_window,
│   │                              #   paste_default_config, set_log_level, close_all (deprecated)
│   ├── defaults.lua              # ~717-line canonical options table; excluded from stylua format
│   ├── collections.lua           # Tree/LinkedList/Queue data structures (used internally by renderer)
│   ├── log.lua                   # Logger (levels: trace/debug/info/warn/error/fatal; optional file out)
│   ├── utils/
│   │   ├── init.lua              # Path normalization, debounce, open-buffer tracking
│   │   └── filesize/filesize.lua # Human-readable file size strings
│   ├── git/
│   │   ├── init.lua              # Re-exports status/status_async/is_ignored/mark_ignored/get_repository_root
│   │   ├── status.lua            # Async git status batching, diff
│   │   ├── ignored.lua           # .gitignore-aware filtering
│   │   └── utils.lua             # get_repository_root, fugitive integration
│   ├── events/
│   │   ├── init.lua              # Custom debounced event subsystem wrapping Vim autocmds
│   │   └── queue.lua             # Event queue implementation (FIFO with handler chaining)
│   ├── setup/
│   │   ├── init.lua              # Bootstrap: merge_config + event wiring + source loading (~746 lines)
│   │   ├── mapping-helper.lua    # Keymap short-form -> long-form normalization
│   │   ├── netrw.lua             # Hijack/disable FileExplorer + edit-<dir>
│   │   └── deprecations.lua      # Migration paths for renamed/removed options
│   ├── sources/
│   │   ├── manager.lua           # State registry (source_data, all_states, default_configs)
│   │   ├── common/
│   │   │   ├── container.lua     # Tree container renderer
│   │   │   ├── file-items.lua    # Folder/file/link node creation + sorting
│   │   │   ├── file-nesting.lua  # Nested-file patterns (JetBrains style)
│   │   │   ├── filters/
│   │   │   │   ├── init.lua      # Live tree filtering (filter/filter_on_submit/clear_filter)
│   │   │   │   └── filter_fzy.lua # fzy-based fuzzy matching for filtering
│   │   │   ├── help.lua          # "?" help popup
│   │   │   ├── hijack_cursor.lua # Opt-in cursor sticks on first letter of filename
│   │   │   ├── node_expander.lua # Recursive node expansion with prefetching
│   │   │   ├── preview.lua       # Floating preview window
│   │   │   ├── commands.lua      # Shared mapped commands (add, delete, rename, copy, move, ...)
│   │   │   └── components.lua    # Built-in render components (indent, icon, name, git_status, ...)
│   │   ├── filesystem/
│   │   │   ├── init.lua          # Filesystem source
│   │   │   ├── commands.lua      # Filesystem-specific commands
│   │   │   ├── components.lua    # Filesystem-specific components
│   │   │   └── lib/
│   │   │       ├── fs_scan.lua   # Async directory scanning
│   │   │       ├── fs_watch.lua  # libuv file watcher
│   │   │       ├── fs_actions.lua # Filesystem operations (create/delete/rename/move)
│   │   │       ├── filter.lua    # Filtered-items logic
│   │   │       ├── filter_external.lua # External filter commands
│   │   │       └── globtopattern.lua   # Glob to Lua pattern conversion
│   │   ├── buffers/
│   │   │   ├── init.lua          # Buffer list source
│   │   │   ├── commands.lua      # Buffers-specific commands
│   │   │   ├── components.lua    # Buffers-specific components
│   │   │   └── lib/items.lua     # Buffer item enumeration
│   │   ├── git_status/
│   │   │   ├── init.lua          # Git status source
│   │   │   ├── commands.lua      # Git-specific commands
│   │   │   ├── components.lua    # Git-specific components
│   │   │   └── lib/items.lua     # Git status item enumeration
│   │   └── document_symbols/
│   │       ├── init.lua          # LSP document_symbols source (disabled by default)
│   │       ├── commands.lua      # Symbols-specific commands
│   │       ├── components.lua    # Symbols-specific components
│   │       └── lib/
│   │           ..client_filters.lua # LSP client filtering
│   │           ├── kinds.lua         # LSP symbol kind definitions
│   │           └── symbols_utils.lua # Symbol tree utilities
│   ├── ui/
│   │   ├── renderer.lua          # ~44 KB rendering engine (windows/buffers/components/trees)
│   │   ├── highlights.lua        # Highlight group definitions (NeoTree* groups)
│   │   ├── selector.lua          # Source selector (winbar/statusline tabs)
│   │   ├── inputs.lua            # Input line UI (nui-based)
│   │   ├── popups.lua            # Float popup for confirm/input
│   │   └── windows.lua           # Window layout helpers (per-tab location tracking)
│   └── command/
│       ├── init.lua              # require("neo-tree.command").execute(...)
│       ├── parser.lua            # :Neotree -> table
│       └── completion.lua        # -complete=custom callback
├── scripts/
│   └── test.sh                   # Local test setup script (installs deps, runs make test)
├── tests/
│   ├── mininit.lua               # Headless config for Plenary.busted
│   ├── neo-tree/{command,events,sources,ui,utils}/   # Tests
│   └── utils/                    # Test helpers
├── Makefile / Dockerfile         # make test; make format
├── doc/                          # :help doc
├── release.sh                    # Release script
└── .stylua.toml                  # 100-col, 2-space indent, AutoPreferDouble
```

## Core Modules

| Module | Responsibility |
|---|---|
| `neo-tree.lua` | Top-level public API. `setup(config, is_auto_config?)`, `show_logs`, `get_prior_window`, `paste_default_config`, `set_log_level`, `close_all` (deprecated). |
| `neo-tree/setup/init.lua` | **Bootstrap**. Migrates deprecated keys, deep-merges `defaults.lua` <- user <- per-source configs, normalizes keymaps, loads sources, wires events/subscriptions. |
| `neo-tree/defaults.lua` | Canonical options. Single source of default config + commented examples. Also readable via `M.paste_default_config()`. |
| `neo-tree/sources/manager.lua` | In-memory state registry. Tracks per-source `source_data` (with `state_by_tab`, `state_by_win`, `subscriptions`), `all_states`, `default_configs`. Used to create/get/dispose/redraw any source. |
| `neo-tree/sources/<name>/init.lua` | Each source exposes `name`, `display_name`, `setup`, `navigate`, `commands`, and `components`. Filesystem additionally exports `follow(callback, force_show)`, `_navigate_internal(...)`, `reset_search()`, `toggle_directory()`, and `prefetcher`. |
| `neo-tree/sources/common/` | Reusable primitives -- `container.lua` (tree container), `file-items` (folder/file/link nodes), `file-nesting` (nested-file patterns), `filters/` (live filtering), `node_expander`, preview logic, `hijack_cursor`, shared commands and components. |
| `neo-tree/command/init.lua` | Executed by `:Neotree`. Handles `opts.source`, `opts.action` (close/focus/show; default "focus"), `opts.position`, `opts.reveal_file`, `opts.id`, `opts.dir`, `opts.git_base`, `opts.toggle`, `opts.reveal`, `opts.selector`, etc. Used by keybindings via `require('neo-tree.command').execute(...)`. |
| `neo-tree/events/*` | Custom debounced event wrapper. `define_event`, `define_autocmd_event`, `subscribe`, `unsubscribe`, `fire_event`, `clear_all_events`, `destroy_event`. Wraps Vim autocmds with transformations (`args.diagnostics_lookup`, `args.opened_buffers`, etc.) and debounce strategies (`CALL_LAST_ONLY`). |
| `neo-tree/ui/renderer.lua` | Largest module. Creates windows/buffers with nui, draws tree rows via `renderers` config, manages floating layout, handles node expansion/focus, provides `get_expanded_nodes`, `clean_invalid_neotree_buffers`, `resize_timer_interval`. |

## Setup Function Signature

```lua
-- Require path: require("neo-tree") -> lua/neo-tree.lua
function M.setup(config_table?, is_auto_config: boolean?)
  -- config_table: user options merged INTO defaults.lua
  -- is_auto_config: true for lazy auto-setup; skips netrw hijack
  -- Returns internal merged config (also stored as M.config)
end
```

Merge order (deep, `vim.tbl_deep_extend("force", ...)`):
1. `vim.deepcopy(defaults)` from `defaults.lua`
2. `vim.deepcopy(user_config)` (also migration-applied by `setup/deprecations.lua`)
3. Per-source merge: `default_config <- source_default_config <- user_config[source]`
4. Final assignment `M.config = vim.tbl_deep_extend("force", default_config, user_config)`

### Top-level options (high-signal)

- **`sources`** -- `{"filesystem", "buffers", "git_status"}` by default; third-party sources addable by module name.
- **`default_source`** -- `"filesystem"` or `"last"`.
- **`close_if_last_window`** -- auto-quit tree when it becomes last tab window.
- **`enable_git_status` / `enable_diagnostics` / `enable_modified_markers` / `enable_opened_markers`** -- section toggles.
- **`git_status_async`**, **`git_status_async_options`** `{ batch_size, batch_delay, max_lines }` -- large-repo option.
- **`hide_root_node`**, **`retain_hidden_root_indent`** -- top-level node visibility.
- **`open_files_do_not_replace_types`**, **`open_files_in_last_window`** -- control window hijack when opening from tree.
- **`sort_case_insensitive`**, **`sort_function`** -- ordering control.
- **`resize_timer_interval`** (ms, -1 to disable) -- right-aligned/faded content redraw throttle.
- **`use_popups_for_input`** -- `false` falls back to `vim.ui.input()`.
- **`use_default_mappings`** -- `false` wipes all keymap defaults for user ownership.
- **`nesting_rules`** -- passed to `sources.common.file-nesting`.
- **`auto_clean_after_session_restore`** -- buffer cleanup on `SessionLoadPost`.
- **`enable_cursor_hijack`** -- cursor sticks on first letter of filename.
- **`enable_refresh_on_write`** -- refresh tree when a file is written (only when `use_libuv_file_watcher` is false).
- **`window.position`** -- per-source: `"left"|"right"|"top"|"bottom"|"float"|"current"` (validated, fallbacks to `"left"`).
- **`window.mappings`** -- keymap table; short and long forms normalized by `mapping-helper`.
- **`source_selector`** -- winbar/statusline tab configuration; includes `sources` (list of `{ source }`), `winbar`, `statusline`, `content_layout`, `tabs_layout`, separator, highlight config.
- **`log_level`**, **`log_to_file`** -- logging.
- **`default_component_configs`** -- shared component templates (`container`, `indent`, `icon`, `modified`, `name`, `git_status`, `diagnostics`, ...). Used as the base when merging renderers.
- **`renderers`** (top-level or per-source) -- supply which components appear in `container`, `leaf_with_url`, `expanded_roots`, rows. Per-source renderers fully **replace** default renderers for that renderer name.
- **`commands`** -- top-level command list; per-source commands `tbl_extend("keep", ...)`.
- **`event_handlers`** -- list of `{ event, handler }` forwarded into `events.subscribe`.

### Per-source filesystem (`filesystem.*`, most-used)

- `follow_current_file` `{ enabled, leave_dirs_open, update_root }` -- reveal active file.
- `hijack_netrw_behavior` -- `"open_default"|"disabled"|"open_current"`.
- `filtered_items` -- `hide_dotfiles`, `hide_gitignored`, `hide_hidden`, `hide_by_name`, `never_show`, etc.
- `find_by_full_path_words` -- `"exact"|"fuzzy"`.
- `group_empty_dirs`, `search_limit`, `use_libuv_file_watcher`, `scan_mode`.
- `window.position`, `window.width`, `window.mappings` -- per-source overrides.

## Dependencies

### Required
- **`plenary.nvim`** -- core runtime (Job for async git, Path, Scandir). Also used for Plenary.busted tests.
- **`MunifTanjim/nui.nvim`** -- UI primitives for inputs/popups/renderer; required for UI surfaces.

### Optional (loaded via `pcall`)
- **`nvim-tree/nvim-web-devicons`** -- file icons & highlights, fallback to `icon.default = "*"` if missing.
- **`3rd/image.nvim`** -- image preview (referenced in README only).
- **LSP / diagnostic providers** -- passive via `DiagnosticChanged` autocmd.

Note: there is no Vimscript loader that soft-gates on dependencies; missing `plenary`/`nui` will cause runtime errors.

## Command & Autocmd Registration

1. **User command** -- `plugin/neo-tree.vim`: defines a single *global* `command! -nargs=* -complete=custom,... Neotree`. Delegation: `lua require("neo-tree.command")._command(<f-args>)`. Completion callback: `require("neo-tree.command").complete_args`.

2. **The executable entrypoint** -- `require("neo-tree.command").execute(opts)` where `opts` supports `{ action, source, position, reveal_file, id, dir, git_base, toggle, reveal, reveal_force_cwd, selector, ... }`. Valid actions: `"close"`, `"focus"` (default), `"show"`. The special source `"migrations"` opens the deprecation log.

3. **Vim autocmds created in `setup/init.lua`**:
   - `vim.api.nvim_create_augroup("NeoTree_BufLeave", {clear=true})` -> `BufWinLeave` for `neo-tree *` (filtered to `neo-tree [^ ]+ %[1%d%d%d%]`) -> restores cursorline/cursorlineopt/foldcolumn/wrap/list/spell/number/relativenumber/winhighlight settings (saved in `prior_window_options[tostring(winid)]`).

4. **Neo-tree custom events** wired in `setup/init.lua` (`define_events` block, guarded by `events_setup` boolean):
   - Custom events: `FS_EVENT`, `GIT_STATUS_CHANGED`, `STATE_CREATED`, `BEFORE_RENDER`, `AFTER_RENDER`, `FILE_ADDED`, `FILE_DELETED`, `BEFORE_FILE_MOVE`, `FILE_MOVED`, `FILE_OPEN_REQUESTED`, `FILE_OPENED`, `BEFORE_FILE_RENAME`, `FILE_RENAMED`, `NEO_TREE_BUFFER_ENTER/LEAVE`, `NEO_TREE_POPUP_BUFFER_ENTER/LEAVE`, `NEO_TREE_POPUP_INPUT_READY`, `NEO_TREE_LSP_UPDATE`, `NEO_TREE_WINDOW_BEFORE_OPEN`, `NEO_TREE_WINDOW_AFTER_OPEN`, `NEO_TREE_WINDOW_BEFORE_CLOSE`, `NEO_TREE_WINDOW_AFTER_CLOSE`.
   - `VIM_*` wrapper events: `VIM_BUFFER_ENTER`, `VIM_WIN_ENTER`, `VIM_WIN_CLOSED`, `VIM_TAB_CLOSED`, `VIM_RESIZED`, `VIM_COLORSCHEME`, `VIM_AFTER_SESSION_LOAD`, `VIM_DIR_CHANGED`, `VIM_CURSOR_MOVED`, `VIM_INSERT_LEAVE`, `VIM_BUFFER_CHANGED`, `VIM_BUFFER_ADDED/DELETED/MODIFIED_SET`, `VIM_LEAVE`, `VIM_TERMINAL_ENTER`, `VIM_TEXT_CHANGED_NORMAL`, `VIM_DIAGNOSTIC_CHANGED`, `VIM_LSP_REQUEST`, `GIT_EVENT`, `GIT_STATUS_CHANGED`.
   - Key subscriptions in setup:
     - `VIM_BUFFER_ENTER` -> `M.buffer_enter_event` (win option store, netrw hijack, focus redirect for "current" position).
     - `VIM_COLORSCHEME` -> `highlights.setup` (id `"neo-tree-highlight"`).
     - `VIM_WIN_ENTER` -> `M.win_enter_event` (id `"neo-tree-win-enter"`; close all floats, prior_window tracking, `close_if_last_window`, rebuild tree on window splits).
     - `VIM_AFTER_SESSION_LOAD` -> `clean_invalid_neotree_buffers(true)` (only when `auto_clean_after_session_restore` is true).
     - `VIM_TAB_CLOSED` -> `manager.dispose_invalid_tabs`.
     - `VIM_WIN_CLOSED` -> `manager.dispose_window(winid)`.
     - `VIM_LEAVE` -> `events.clear_all_events`.
     - `VIM_RESIZED` -> `renderer.update_floating_window_layouts`.

5. **Netrw hijack** (`setup/netrw.lua`): only when not auto-config and `hijack_netrw_behavior` != `"disabled"`. Installs custom `BufEnter`/autocmd to redirect `edit <dir>` paths into Neo-tree (calls `netrw.hijack()` inside `buffer_enter_event`).

6. **Cursor hijack** (`sources/common/hijack_cursor.lua`): opt-in via `enable_cursor_hijack`, subscribes to `VIM_CURSOR_MOVED` to reposition on first letter of filename.

7. **Source selector** (`ui/selector.lua`): opt-in via `source_selector.winbar` or `source_selector.statusline`. Per-source default_source is auto-aligned to first selector entry.

## Build / Test Commands

```makefile
# Run Plenary busted tests
make test
# -> nvim --headless --noplugin -u tests/mininit.lua \
#     -c "lua require('plenary.test_harness').test_directory('tests/neo-tree/', {minimal_init='tests/mininit.lua',sequential=true})"

# Docker variant
make test-docker
# -> docker build -t neo-tree . && docker run --rm neo-tree make test

# Format all Lua except defaults.lua (pure-data config)
make format
# -> stylua --glob '*.lua' --glob '!defaults.lua' .
```

Test code uses `tests/mininit.lua` as the minimal `rtp` init; `manager._clear_state` is available as a teardown hook.

## Coding Conventions

1. **Module root**: start every file with `local M = {}`. Public surface is methods on `M`. Constants are module-local.
2. **`local vim = vim`** -- declare at module top for direct upvalue access and perf (`vim.api.*`, `vim.fn.*`, `vim.tbl_deep_extend`).
3. **LuaCATS annotations** on any public-facing function: `--- @param name type`, `--- @return type`, `--- @cast value Type`, `--- @class`.
4. **Deep-copy policy**: always `vim.deepcopy(...)` before mutating (`merge_config`, `create_state`). Never mutate defaults.
5. **`vim.tbl_deep_extend("force", ...)`** for merging; **`vim.tbl_extend("keep", ...)`** when preserving existing keys (e.g., per-source commands inheritance).
6. **Defensive `pcall` for optional plugins** (`nvim-web-devicons`, `image.nvim`); hard-fail `error("...:")` for required module-load failures (`get_source_data`, `set_default_config`, `manager.get_state`).
7. **Vim schedule/wrap** for re-entrant work (`vim.schedule`, `vim.schedule_wrap`). Vim API calls wrapped in `pcall` when used in callbacks (`buffer_enter_event`, tab-close handler).
8. **Logging**: `require("neo-tree/log")` with `log.trace|debug|info|warn|error|fatal`. Controlled by `log_level`. Never `print` for diagnostics.
9. **Events**: single `events.subscribe{event, handler, id}` API. Idempotent `events_setup` guard. Fire via `events.fire_event`. Vim-autocmd-backed events use `define_autocmd_event(names, debounce_ms, transform_fn?, nested?)`.
10. **Mappings**: short form `{ "cmd", "desc" }` and long form `{ handler = ..., desc = ..., ... }`. `mapping-helper.normalize_map` canonicalizes. User config normalized before merge.
11. **Keymap builder**: `M.define_navigation_commands` and per-source `commands.lua` define every keybind as a function with help text.
12. **Paths**: normalize via `utils.normalize_path`, cross-platform `utils.path_separator`.
13. **Version-conditional code**: `vim.version().minor >= 7` for WinSeparator highlight; `< 0.6` falls back to `User LspDiagnosticsChanged`.
14. **One file per source**: `init.lua` + optional `commands.lua`, `components.lua`, `lib/`. Common code lives in `sources/common/` -- **must not depend on UI**.
15. **Separation of data vs logic**: `defaults.lua` is a *pure config table* (no functions) -- excluded from stylua; `setup/init.lua` is the logic that reads and merges it.
16. **Exported vs internal**: anything not required/completed by an entry point is effectively private (`local fn`, `local M._name`).
17. **Comment style**: inline `-- ` for notes; `--- @` LuaCATS where useful. Module-level use-case comments with `--- @module` style.
18. **Naming**: highlight groups `NeoTree*`; autocmd events in `events.lua` are UPPER_SNAKE (`VIM_BUFFER_ENTER`); config keys are snake_case; Vim command `Neotree`.
19. **Formatting**: `stylua` 100-column, 2-space indent, double-quotes auto. **`defaults.lua` excluded from format** (data file).
20. **No lazy-plugin spaghetti** -- modules are required once at setup; long-lived state lives in `M.config`, `manager.source_data`, `M.events_setup`.
21. **Top-level contract**: `require("neo-tree").setup(opts)` is the only needed call after plugin loads. `:Neotree <source> [position] [flags]` is the user-facing Vim command.

## Public API Entrypoints

```lua
-- Bootstrap
require("neo-tree").setup(opts?, is_auto_config?)

-- Programmatic command (used by keybindings)
require("neo-tree.command").execute({
  source = "filesystem",        -- source name
  action = "show",              -- "close"|"focus"|"show" (default: "focus")
  position = "left",            -- "left"|"right"|"top"|"bottom"|"float"|"current"
  reveal_file = "/abs/path",    -- reveal this file
  dir = "/abs/path",            -- root path
  id = 123,                     -- state id
  git_base = "HEAD",            -- git ref for diff
  toggle = false,               -- toggle visibility
  reveal = false,               -- reveal current file
  reveal_force_cwd = false,     -- force reveal in cwd
  selector = false,             -- show source selector
})

-- Per-source (loaded by setup from `sources=` table)
require("neo-tree.sources.filesystem")
  :navigate(state, path, id?)
  M.follow(callback?, force_show?): boolean
  M.reset_search(state, refresh?, open_current_node?)
  M.toggle_directory(state, node, path_to_reveal?, skip_redraw?, recursive?, callback?)
require("neo-tree.sources.manager").get_state(source_name, tabid?, winid?)

-- Events
require("neo-tree.events").subscribe{ event = ..., handler = ..., id = ... }
require("neo-tree.events").fire_event(name, args)
```

## Key Files to Read When Modifying

- `lua/neo-tree.lua` -- top-level API surface
- `lua/neo-tree/setup/init.lua` -- config merge + event wiring (the "main" of the plugin)
- `lua/neo-tree/defaults.lua` -- canonical options (edit here to add new config)
- `lua/neo-tree/sources/manager.lua` -- state registry
- `lua/neo-tree/sources/<name>/init.lua` -- per-source behavior
- `lua/neo-tree/sources/common/` -- reusable tree primitives
- `lua/neo-tree/command/init.lua` -- command executor
- `lua/neo-tree/events/init.lua` -- event subsystem
- `lua/neo-tree/ui/renderer.lua` -- rendering engine
- `tests/neo-tree/` -- Plenary.busted tests
