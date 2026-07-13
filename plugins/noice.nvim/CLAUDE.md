# noice.nvim

**Noice** (Nice / Noise / Notice) is a Neovim plugin that **completely replaces Neovim's default UI** for three things:
1. **Messages** (`:messages` / `msg_show`) -- routed to configurable views instead of the echo area
2. **Cmdline** -- a popup/fancy command line with icons and syntax highlighting
3. **Popupmenu** -- cmdline completion menu via nui or cmp backends

It also **overrides** `vim.notify`, the LSP handlers (`hover`, `signature_help`), the LSP markdown formatters, and `cmp.entry.get_documentation`, routing everything through a single filter/route/view pipeline. Built on Neovim's experimental `vim.ui_attach` API. Requires Neovim >= 0.9 (nightly recommended).

## Directory Structure

```
noice.nvim/
├── lazy.lua               # lazy.nvim entry spec: { nui.nvim (lazy=true), folke/noice.nvim }
├── selene.toml            # Linter config: std="vim", mixed_table="allow"
├── stylua.toml            # Formatter: 2-space indent, 120 col, sort_requires enabled
├── vim.toml               # vimls config (project-defined globals)
├── doc/                   # Help docs (noice.nvim.txt)
├── scripts/               # test helper script
├── lua/
│   ├── noice/             # Main plugin
│   │   ├── init.lua       # Public API + setup/enable/disable
│   │   ├── api/           # api/init.lua (exposed), api/status.lua (statusline data)
│   │   ├── commands.lua   # :Noice commands (history, last, errors, all, + built-ins)
│   │   ├── health.lua     # :checkhealth noice
│   │   ├── config/        # Configuration layer
│   │   │   ├── init.lua       # Defaults + setup() + deep-merge logic
│   │   │   ├── views.lua      # View definitions (popup, mini, split, hover, cmdline ...)
│   │   │   ├── routes.lua      # Default filters -> view assignments
│   │   │   ├── preset.lua      # Named presets (bottom_search, command_palette, ...)
│   │   │   ├── cmdline.lua     # Cmdline UI behavior
│   │   │   ├── format.lua      # Built-in format tables (lsp_progress, details, telescope, ...)
│   │   │   ├── highlights.lua  # NoiceCmdline, NoicePopup, NoiceMini, ... hl groups
│   │   │   ├── icons.lua       # Nerd Font icons + completion kind icons
│   │   │   └── status.lua      # Built-in statusline component defaults (ruler, message, ...)
│   │   ├── lsp/           # LSP overrides & formatting
│   │   │   ├── init.lua       # Entry: wires up hover/signature/message/progress/override
│   │   │   ├── hover.lua       # Replaces vim.lsp.buf.hover
│   │   │   ├── signature.lua   # Replaces vim.lsp.buf.signature_help
│   │   │   ├── message.lua     # Handles LSP window/showMessage
│   │   │   ├── progress.lua    # LSP progress (format: lsp_progress) -> mini view
│   │   │   ├── docs.lua        # Scrollable docs
│   │   │   ├── format.lua      # Noice markdown formatting for LSP
│   │   │   └── override.lua    # Hooks vim.lsp.util.* + cmp.entry.get_documentation
│   │   ├── message/       # Message model & routing
│   │   │   ├── init.lua       # NoiceMessage class (extends NoiceBlock)
│   │   │   ├── filter.lua     # Filter matching engine
│   │   │   ├── manager.lua    # Global message store (history + active)
│   │   │   └── router.lua     # Routes incoming messages to views (redirect/update)
│   │   ├── source/
│   │   │   └── notify.lua     # Replaces vim.notify
│   │   ├── text/          # Rendering primitives
│   │   │   ├── init.lua, block.lua, highlight.lua, syntax.lua, treesitter.lua
│   │   │   ├── markdown.lua   # Markdown -> NoiceMessage
│   │   │   └── format/        # Format helpers (formatters.lua)
│   │   ├── ui/            # UI surface (vim.ui_attach)
│   │   │   ├── init.lua, cmdline.lua, grid.lua, msg.lua, state.lua
│   │   │   └── popupmenu/     # init.lua (backend dispatch) + cmp.lua + nui.lua backends
│   │   ├── util/          # Misc
│   │   │   ├── init.lua       # Core helpers (protect/try/wo/interval/open/notify/...)
│   │   │   ├── lazy.lua       # Lazy-require wrapper (`local require = require("noice.util.lazy")`)
│   │   │   ├── hacks.lua      # Neovim compatibility shims
│   │   │   ├── call.lua, ffi.lua, nui.lua, spinners.lua, stats.lua
│   │   ├── view/          # View abstraction
│   │   │   ├── init.lua       # NoiceView base class (push/set/display/show/hide/render)
│   │   │   ├── nui.lua, scrollbar.lua
│   │   │   └── backend/       # Concrete backends (see below)
│   │   ├── types/         # LuaLS type annotations
│   │   │   ├── init.lua       # (empty)
│   │   │   └── nui.lua        # NuiPopupOptions / NuiSplitOptions / NoiceNuiOptions types
│   │   └── integrations/  # fzf.lua, snacks.lua (picker sources)
│   └── telescope/_extensions/noice.lua  # :Telescope noice
└── tests/                 # minit.lua (lazy.nvim test harness) + text/, util/, view/
```

## Core Modules

| Module | Responsibility |
|---|---|
| `noice/init.lua` | Public API. `setup()`, `enable()`, `disable()`, `redirect()`, `notify()`, `cmd()` |
| `noice/config/init.lua` | Merges defaults + user opts, applies presets, sets up highlights, LSP, routes |
| `noice/config/views.lua` | Registry of all view definitions (popup, mini, split, hover, cmdline_popup, ...) |
| `noice/config/routes.lua` | Default filter->view routing table |
| `noice/config/preset.lua` | Named presets that mutate config |
| `noice/config/format.lua` | Built-in format tables (`lsp_progress`, `details`, `telescope`, `fzf`, `snacks`, ...) |
| `noice/view/init.lua` | `NoiceView` base class; `View.get_view()` resolves backend with fallback chain |
| `noice/view/backend/*` | Concrete view implementations |
| `noice/message/*` | Message model, filter engine, manager (store), router (dispatch) |
| `noice/lsp/init.lua` | Wires LSP overrides into Neovim |
| `noice/lsp/override.lua` | Hooks `vim.lsp.util.*` and `cmp.entry.get_documentation` |
| `noice/source/notify.lua` | Replaces `vim.notify` |
| `noice/ui/*` | `vim.ui_attach` integration (cmdline, msg, popupmenu) |
| `noice/text/*` | Rendering primitives, markdown parser, treesitter/syntax highlighting |
| `noice/util/lazy.lua` | Lazy-require wrapper used at the top of nearly every module |

## Setup Signature & Configuration

```lua
---@param opts? NoiceConfig
function M.setup(opts)
```

Top-level `NoiceConfig` keys (from `config/init.lua` defaults):

- **`cmdline`** -- `{ enabled, view="cmdline_popup", opts, format }`. `format` is `table<string, CmdlineFormat>` keyed by name (`cmdline`, `search_down`, `search_up`, `filter`, `lua`, `help`, `calculator`, `input`, plus custom e.g. `IncRename`). Each: `{ pattern, icon, lang, kind, view, opts, conceal, icon_hl_group, title }`.
- **`messages`** -- `{ enabled, view="notify", view_error, view_warn, view_history="messages", view_search="virtualtext" }`.
- **`popupmenu`** -- `{ enabled, backend="nui"|"cmp", kind_icons }`.
- **`redirect`** -- `{ view="popup", filter={event="msg_show"} }` (default for `require("noice").redirect`).
- **`commands`** -- `table<string, NoiceCommand>`: built-in `history`, `last`, `errors`, `all`. Each: `{ view, opts, filter, filter_opts }`.
- **`notify`** -- `{ enabled=true, view="notify" }`.
- **`lsp`** -- `{ progress, override, hover, signature, message, documentation, markdown, health }`.
  - `progress`: `{ enabled, format="lsp_progress", format_done="lsp_progress_done", throttle=1000/10, view="mini" }`.
  - `override`: `{ ["vim.lsp.util.convert_input_to_markdown_lines"], ["vim.lsp.util.stylize_markdown"], ["cmp.entry.get_documentation"] }` (booleans, default `false`).
  - `hover`/`signature`: `{ enabled, silent, view, opts }`; signature has `auto_open={enabled, trigger, luasnip, snipppets, throttle}`.
  - `message`: `{ enabled, view="notify", opts }`.
  - `documentation`: `{ view="hover", opts }` (shared base for hover/signature).
- **`markdown`** -- `{ hover, highlights }` link-handling tables (e.g. `["|(%S-)|"] = vim.cmd.help`).
- **`health`** -- `{ checker=true }` (controls whether health checks run on startup).
- **`presets`** -- `table<string, bool|table>`: `bottom_search`, `command_palette`, `long_message_to_split`, `inc_rename`, `lsp_doc_border`, `cmdline_output_to_split`.
- **`throttle`** -- `1000/30` (UI refresh rate).
- **`views`** -- `table<string, NoiceViewOptions>` (user view overrides).
- **`routes`** -- `NoiceRouteConfig[]` (user route overrides).
- **`status`** -- `table<string, NoiceFilter>` (statusline components; built-in defaults: `ruler`, `message`, `command`, `mode`, `search`).
- **`format`** -- `NoiceFormatOptions` (user format overrides; built-in defaults include `debug`, `level`, `progress`, `spinner`, `title`, `event`, `kind`, `date`, `message`, `confirm`, `cmdline`).
- **`debug`**, **`log`**, **`log_max_size`** (default `1024*1024*2` = 2MB).

### Presets (`config/preset.lua`)
Each preset is a partial `NoiceConfig` merged over defaults. `bottom_search` switches search to classic cmdline; `command_palette` positions cmdline+popupmenu together; `long_message_to_split` routes tall messages to a split; `inc_rename` adds an `IncRename` cmdline format; `lsp_doc_border` adds a rounded border to hover; `cmdline_output_to_split` sends cmdline output to a split.

### Routes (`config/routes.lua`)
Default routes map events to views: `cmdline`->cmdline view; `confirm`/`confirm_sub`/`number_prompt`->`confirm`; `msg_history_show`->`view_history`; `search_count`->`view_search`; `msg_showmode`/`msg_showcmd`/`msg_ruler`->skip; `msg_show` (kinds `""`, `echo`, `echomsg`, `lua_print`, `list_cmd`)->`view` (replace+merge); errors/warnings->`view_error`/`view_warn`; `notify`->`notify` view; `lsp` progress->`lsp.progress.view`; `lsp` message->`lsp.message.view`. User routes are prepended (checked first).

## Dependencies

**Required:**
- Neovim >= 0.9 (nightly recommended)
- `MunifTanjim/nui.nvim` -- rendering & multiple views (lazy-loadable)

**Optional:**
- `rcarriga/nvim-notify` -- notification view (falls back to `mini`)
- Nerd Font (for icons)
- `nvim-treesitter` -- cmdline & LSP doc highlighting (parsers: `vim`, `regex`, `lua`, `bash`, `markdown`, `markdown_inline`)
- `hrsh7th/nvim-cmp` -- for `cmp.entry.get_documentation` override and `popupmenu.backend="cmp"`
- `nvim-telescope/telescope.nvim` or `ibhagwan/fzf-lua` -- open message history
- `folke/snacks.nvim` -- `snacks` backend + picker source (auto-registered if available)

## How It Overrides vim.notify / LSP / Diagnostic

- **`vim.notify`** -- `source/notify.lua`: `enable()` saves `vim.notify` to `M._orig` and replaces it with `M.notify`, which builds a `NoiceMessage("notify", level, msg)` and adds it to the `Manager`. `disable()` restores the original.
- **LSP handlers** -- `lsp/init.lua`: replaces `vim.lsp.buf.hover` and `vim.lsp.buf.signature_help` with Noice versions that use `vim.lsp.buf_request` and render via docs views. `lsp.message` hooks `window/showMessage`. `lsp.progress` hooks `$/progress`.
- **LSP markdown** -- `lsp/override.lua`: when enabled, replaces `vim.lsp.util.convert_input_to_markdown_lines` and `vim.lsp.util.stylize_markdown` with Noice's own markdown formatter, and hooks `cmp.entry.get_documentation` via `Hacks.on_module`.
- **Diagnostic**: Noice does **not** override `vim.diagnostic` directly; it intercepts the `msg_show` events that diagnostics produce, routing them through the normal message pipeline.

## Backends (`lua/noice/view/backend/`)

| File | Backend id | Notes |
|---|---|---|
| `popup.lua` | `popup` | nui popup (default for cmdline, confirm, hover) |
| `mini.lua` | `mini` | minimal floating notifications (default for LSP progress) |
| `split.lua` | `split` | nui split (messages history, cmdline output) |
| `virtualtext.lua` | `virtualtext` | extmark virtual text (search count) |
| `notify.lua` | `notify` | delegates to `rcarriga/nvim-notify` |
| `notify_send.lua` | `notify_send` | system `notify-send` |
| `snacks.lua` | `snacks` | delegates to `folke/snacks.nvim` |

Backend resolution (`View.get_view`): iterates the `backend` list (a string or array), requires `noice.view.backend.<name>`, checks `is_available()`, and falls back through `opts.fallback`. The `notify` view uses `backend = {"snacks","notify"}` with `fallback = "mini"`. Views can inherit from other views via a `view` key (e.g. `cmdline_popupmenu` -> `popupmenu`, `messages` -> `split`), resolved by `config/views.lua:get_options()`.

## Build / Test Commands

- **Tests**: `tests/minit.lua` -- a `nvim -l` script using the lazy.nvim test harness (`lazy.minit`). Run via `nvim -l tests/minit.lua` (sets `LAZY_STDPATH`, bootstraps lazy from GitHub).
- **Linting**: `selene` (config `selene.toml`, `std="vim"`, `mixed_table="allow"`).
- **Formatting**: `stylua` (config `stylua.toml`, 2-space indent, 120 col, `sort_requires` on).
- **CI**: `.github/workflows/` has `ci.yml`, `pr.yml`, `labeler.yml`, `stale.yml`, `update.yml`.
- No `Makefile` or `package.json`; no npm-based build.

## Coding Conventions

- **Lazy requires everywhere**: every module starts with `local require = require("noice.util.lazy")` to defer loading.
- **Module pattern**: each file returns a single `local M = {}` table of functions.
- **Heavy use of `---@class` / `---@type` / `---@param` / `---@field` annotations** for LuaLS type checking (e.g. `NoiceConfig`, `NoiceView`, `NoiceViewOptions`, `NoiceRouteConfig`, `NoiceCommand`, `NoiceFormat`, `NoiceFilter`, `NoicePresets`).
- **Object model**: `NoiceView` extends `nui.object` via `Object("NoiceView")`; `NoiceMessage` extends `NoiceBlock` (which itself extends `nui.object` via `Object("Block")`).
- **Config merge strategy**: `vim.tbl_deep_extend("force", ...)` for most merges; `"keep"` when resolving view inheritance chains.
- **Error handling**: `Util.protect(fn)` / `Util.try(fn)` wraps risky calls; `Util.error`/`Util.panic`/`Util.debug` gated on `Config.options.debug`.
- **Formatting**: 2-space indentation, 120-column width, sorted `require`s (enforced by stylua `sort_requires`).
- **Linting**: selene with `mixed_table="allow"` (mixing array + hash parts of tables is permitted).
- **Neovim compat**: `util/hacks.lua` + version checks like `vim.fn.has("nvim-0.11")` and `vim.v.vim_denter`; `vim.uv or vim.loop` fallback.
- **Namespace**: single namespace `vim.api.nvim_create_namespace("noice")` stored at `Config.ns`.
- **Autocmds**: `VimEnter` deferred load; `VimLeavePre` cleanup; `ColorScheme` re-applies highlights.
- **vim.toml**: project-defined globals for vimls (the language server), complementing selene's `std="vim"`.

## Key Public API

- `require("noice").setup(opts)`
- `require("noice").enable()` / `.disable()` / `.deactivate()`
- `require("noice").redirect(cmd, routes)` -- capture messages from a command/function
- `require("noice").notify(msg, level, opts)` -- programmatic notifications
- `require("noice").cmd(name)` -- run a `:Noice` command
- `require("noice").api` -- exposed API table (`api/init.lua`, `api/status.lua`)

### `:Noice` commands (defined in `commands.lua`)

Built-in commands registered under `:Noice <name>` (and `:Noice<Name>` shortcuts): `history`, `last`, `errors`, `all` (from config), plus `debug`, `dismiss`, `log`, `enable`, `disable`, `telescope`, `fzf`, `snacks`, `pick`, `stats`, `routes`, `config`, `viewstats`. User commands defined in `config.commands` are merged into this set.
