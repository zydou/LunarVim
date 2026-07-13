# copilot.lua

## Project Overview

copilot.lua is a pure Lua replacement for [github/copilot.vim](https://github.com/github/copilot.vim). It uses Neovim's built-in LSP client API to communicate with the Copilot language server, significantly reducing CPU and memory usage while providing auto-completion capabilities comparable to the official Copilot plugin.

Main features:
- **Suggestion** — Displays inline ghost text as AI suggestions in insert mode, supporting both auto-trigger and manual trigger
- **Panel** — Previews multiple Copilot solutions in a split window
- **LSP integration** — Runs as an LSP server, allowing Copilot to integrate with any plugin that supports LSP client detection
- **Status notification** — Reports Copilot state changes via `statusNotification`

---

## Directory Structure

```
copilot.lua/
├── LICENSE
├── README.md                       # Installation and configuration docs
├── SettingsOpts.md                # LSP server advanced settings options list
├── .stylua.toml                   # Code formatting configuration
├── .github/workflows/             # CI workflow (updates dist files)
│   └── update-copilot-dist.yaml
├── copilot/
│   ├── index.js                   # Copilot language server entry point (Node.js)
│   ├── package.json               # Node.js dependencies
│   └── dist/                      # Pre-compiled Copilot language server assets
│       ├── language-server.js     # Main LSP server
│       ├── tree-sitter-*.wasm     # Tree-sitter parsers for various languages
│       ├── resources/             # Tokenizer resources (tiktoken)
│       └── compiled/              # Platform-specific native modules
├── plugin/
│   └── copilot.lua                # Defines the :Copilot user command
└── lua/
    └── copilot/
        ├── init.lua               # Main entry point, exposes setup()
        ├── config.lua             # Configuration management (defaults, setup, get)
        ├── client.lua             # LSP client management (start, attach, detach)
        ├── api.lua                # Copilot LSP API wrapper (all LSP requests/notifications)
        ├── suggestion.lua         # Inline suggestion module (ghost text display, accept, cycle)
        ├── panel.lua              # Panel module (multi-solution preview, navigation, accept)
        ├── command.lua            # Command implementations (:Copilot subcommands)
        ├── auth.lua               # GitHub authentication flow (signin/signout)
        ├── highlight.lua          # Highlight group definitions (CopilotSuggestion, CopilotAnnotation)
        ├── handlers.lua           # Deprecated handlers wrapper (backward compatibility)
        └── util.lua               # Utility functions (doc params, editor info, proxy config, etc.)
```

---

## Core Modules

### `copilot.init` (Main Entry Point)

Exposed API:
- `setup(opts)` — Initializes the plugin, sets up highlights, config, commands, and submodules

Behavior:
- Calls `highlight.setup()`, `config.setup(opts)`, and `command.enable()`
- Only creates user commands when `panel.enabled` is true
- Registers deprecated commands for backward compatibility: `:CopilotDetach` → `:Copilot detach`, `:CopilotStop` → `:Copilot disable`, `:CopilotPanel` → `:Copilot panel`, `:CopilotAuth` → `:Copilot auth`
- Guards against double-setup via `M.setup_done`

### `copilot.config`

Configuration management:
- `config.setup(opts)` — Merges user config with defaults, returns final config (idempotent)
- `config.get(key)` — Gets a config entry (errors if not initialized)

Default configuration:
```lua
{
  panel = {
    enabled = true,
    auto_refresh = false,
    keymap = { jump_prev = "[[", jump_next = "]]", accept = "<CR>", refresh = "gr", open = "<M-CR>" },
    layout = { position = "bottom", ratio = 0.4 },
  },
  suggestion = {
    enabled = true,
    auto_trigger = false,
    hide_during_completion = true,
    debounce = 15,
    keymap = { accept = "<M-l>", accept_word = false, accept_line = false, next = "<M-]>", prev = "<M-[>", dismiss = "<C-]>" },
  },
  ft_disable = nil, -- @deprecated, use filetypes instead
  filetypes = {},
  auth_provider_url = nil,
  copilot_node_command = "node",
  server_opts_overrides = {},
}
```

Note: The `filetypes` config defaults to `{}`, but `util.lua` defines an `internal_filetypes` table with these defaults: `yaml`, `markdown`, `help`, `gitcommit`, `gitrebase`, `hgcommit`, `svn`, `cvs`, and `"."` are all set to `false`. These internal defaults are used unless `filetypes["*"]` is set.

### `copilot.client`

LSP client management:
- `client.buf_attach(force)` — Attaches the Copilot LSP client to the current buffer
- `client.buf_detach()` — Detaches from the current buffer
- `client.buf_is_attached(bufnr)` — Checks if client is attached
- `client.get()` — Gets the current LSP client
- `client.is_disabled()` — Returns true if client is disabled (startup error or teardown)
- `client.get_node_version()` — Gets and validates Node.js version (accepts >= 16.14, warns on 16.x, errors below 16.14)
- `client.use_client(callback)` — Ensures client is initialized, then executes callback (starts client if needed, polls with timer until initialized)
- `client.setup()` — Configures LSP client and creates FileType autocommand
- `client.teardown()` — Stops client and cleans up

Internal details:
- Uses `vim.lsp.start` (Neovim >= 0.8.2) or falls back to `vim.lsp.start_client` with a custom `reuse_client` shim
- Sets custom capabilities: `capabilities.copilot = { openURL = true }`
- Registers LSP handlers: `PanelSolution`, `PanelSolutionsDone`, `statusNotification`, `copilot/openURL`
- `on_init` callback sends `setEditorInfo` with editor info, editor configuration, network proxy, and auth provider URL
- `on_exit` callback triggers `command.status()` if exit code > 0

### `copilot.api`

Copilot LSP API wrapper providing the following requests/notifications:
- `api.request(client, method, params, callback)` — Sends an LSP request (uses coroutine.yield for sync-style when no callback)
- `api.notify(client, method, params)` — Sends an LSP notification
- `api.set_editor_info(client, params, callback)` — Sets editor info
- `api.notify_change_configuration(client, params)` — Notifies configuration change
- `api.check_status(client, params, callback)` — Checks Copilot status
- `api.sign_in_initiate(client, callback)` — Initiates authentication
- `api.sign_in_confirm(client, params, callback)` — Confirms authentication
- `api.sign_out(client, callback)` — Signs out
- `api.get_version(client, callback)` — Gets version
- `api.notify_accepted(client, params, callback)` — Notifies acceptance
- `api.notify_rejected(client, params, callback)` — Notifies rejection
- `api.notify_shown(client, params, callback)` — Notifies shown
- `api.get_completions(client, params, callback)` — Gets completions
- `api.get_completions_cycling(client, params, callback)` — Gets cycling completions
- `api.get_panel_completions(client, params, callback)` — Gets panel completions
- `api.register_panel_handlers(panelId, handlers)` / `api.unregister_panel_handlers(panelId)` — Registers/unregisters panel callbacks
- `api.register_status_notification_handler(handler)` / `api.unregister_status_notification_handler(handler)` — Registers/unregisters status notification callbacks

Exposed sub-tables:
- `api.panel` — Panel callback registry (contains `callback.PanelSolution` and `callback.PanelSolutionsDone`)
- `api.status` — Status notification state (contains `client_id`, `data`, `callback`)
- `api.handlers` — LSP handler table passed to the client (includes `PanelSolution`, `PanelSolutionsDone`, `statusNotification`, `copilot/openURL`)

The `copilot/openURL` handler uses `vim.ui.open` (Neovim >= 0.10) to open URLs, with error fallbacks for older versions.

### `copilot.suggestion`

Inline suggestion module:
- `suggestion.is_visible()` — Checks if a suggestion is visible
- `suggestion.accept(modifier)` — Accepts the current suggestion (optional modifier function transforms the suggestion before applying)
- `suggestion.accept_word()` — Accepts one word
- `suggestion.accept_line()` — Accepts one line
- `suggestion.next()` / `suggestion.prev()` — Cycles through suggestions
- `suggestion.dismiss()` — Dismisses the suggestion
- `suggestion.toggle_auto_trigger()` — Toggles auto trigger for the current buffer
- `suggestion.setup()` — Sets up keymaps, autocommands, and config (called by `command.enable()`)
- `suggestion.teardown()` — Removes keymaps and autocommands

Buffer-level overrides:
- `vim.b.copilot_suggestion_auto_trigger` — Overrides `auto_trigger` per buffer
- `vim.b.copilot_suggestion_hidden` — Manually hides suggestion (e.g., when completion menu is open)

Uses namespace `copilot.suggestion` and extmark ID 1 for ghost text rendering via `virt_text` / `virt_lines`.

### `copilot.panel`

Panel module:
- `panel.accept()` — Accepts the current solution in the panel
- `panel.jump_next()` / `panel.jump_prev()` — Jumps between solutions
- `panel.open(layout)` — Opens the panel
- `panel.refresh()` — Refreshes the panel
- `panel.setup()` — Sets up open keymap and config (called by `command.enable()`)
- `panel.teardown()` — Removes keymap and closes panel

Panel uses a virtual buffer with URI scheme `copilot://` (converted from `file://`). Supported positions: `top`, `right`, `bottom`, `left`, `horizontal`, `vertical`.

Internal panel methods: `panel:lock()`, `panel:unlock()`, `panel:clear()`, `panel:refresh_header()`, `panel:add_entry()`, `panel:get_entry()`, `panel:jump()`, `panel:accept()`, `panel:close()`, `panel:ensure_bufnr()`, `panel:ensure_winid()`, `panel:refresh()`, `panel:init()`.

### `copilot.command`

Command implementations:
- `command.version()` — Displays version info (editor, copilot.lua, language-server, Node.js)
- `command.status()` — Displays Copilot status (offline/online/auth state)
- `command.attach(opts)` — Attaches to current buffer (supports `{ force = true }` via `!`)
- `command.detach()` — Detaches from current buffer
- `command.toggle(opts)` — Toggles attach state
- `command.enable()` — Enables Copilot (calls `client.setup()`, `panel.setup()`, `suggestion.setup()`)
- `command.disable()` — Disables Copilot (calls `client.teardown()`, `panel.teardown()`, `suggestion.teardown()`)

### `copilot.auth`

Authentication flow:
- `auth.signin()` — Starts the GitHub authentication flow (copies code to clipboard, opens popup, waits for confirmation)
- `auth.signout()` — Signs out
- `auth.get_cred()` — Gets saved credentials from `~/.config/github-copilot/hosts.json` (or `$XDG_CONFIG_HOME`, or `~/AppData/Local` on Windows)

Internal: `auth.setup(client)` orchestrates the sign-in coroutine using `check_status`, `sign_in_initiate`, `sign_in_confirm`.

### `copilot.util`

Utility functions:
- `util.get_editor_info()` — Gets editor info (name: "Neovim", version from `vim.fn.execute("version")`)
- `util.get_copilot_lua_version()` — Gets copilot.lua version via `git rev-parse HEAD` (returns "dev" on failure)
- `util.get_next_id()` — Returns incrementing integer ID
- `util.should_attach()` — Determines if Copilot should attach to current buffer (checks filetypes, buflisted, buftype)
- `util.language_for_file_type(filetype)` — Maps Neovim filetype to Copilot language ID (strips after dot, applies normalization map)
- `util.get_doc()` / `util.get_doc_params(overrides)` — Gets current document parameters (uses utf-16 encoding)
- `util.get_editor_configuration()` — Gets editor configuration for `setEditorInfo` (enableAutoCompletions, disabledLanguages)
- `util.get_network_proxy()` — Gets network proxy config from `vim.g.copilot_proxy` and `vim.g.copilot_proxy_strict_ssl`
- `util.strutf16len(str)` — Computes UTF-16 string length (uses `vim.fn.strutf16len` if available, fallback implementation otherwise)

Language normalization map: `bash` → `shellscript`, `bst` → `bibtex`, `cs` → `csharp`, `cuda` → `cuda-cpp`, `dosbatch` → `bat`, `dosini` → `ini`, `gitcommit` → `git-commit`, `gitrebase` → `git-rebase`, `make` → `makefile`, `objc` → `objective-c`, `objcpp` → `objective-cpp`, `ps1` → `powershell`, `raku` → `perl6`, `sh` → `shellscript`, `text` → `plaintext`.

Internal filetypes (deny-by-default unless overridden): `yaml`, `markdown`, `help`, `gitcommit`, `gitrebase`, `hgcommit`, `svn`, `cvs`, `"."`.

Deprecated functions: `util.get_copilot_client`, `util.is_attached`, `util.get_completion_params`, `util.get_copilot_path`, `util.auth`.

### `copilot.highlight`

Highlight group definitions:
- `CopilotSuggestion` — Linked to `Comment`
- `CopilotAnnotation` — Linked to `Comment`

Uses `highlight default link` so user colorschemes can override.

### `copilot.handlers`

Deprecated backward-compatibility wrapper. All functions delegate to `api.panel.callback` or `api.unregister_panel_handlers`. Use `api.register_panel_handlers` / `api.unregister_panel_handlers` instead.

---

## Configuration

### Installation

```lua
-- lazy.nvim example
{
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  config = function()
    require("copilot").setup({})
  end,
}
```

### Authentication

Run `:Copilot auth` (or `:Copilot auth signin`) to start the authentication process.

### Configuration Options

See README.md for the full default config. Key options:
- `panel.enabled` / `suggestion.enabled` — Enable/disable panel and suggestions
- `filetypes` — Enable/disable Copilot per filetype (supports function values; `"*"` overrides all defaults)
- `copilot_node_command` — Path to Node.js executable (must be >= 16.14, >= 17.3 recommended, >= 18.x preferred)
- `auth_provider_url` — Custom auth provider URL for GitHub Enterprise
- `server_opts_overrides` — Override LSP client config (see SettingsOpts.md)
- `ft_disable` — Deprecated, use `filetypes` instead

### Commands

The `:Copilot` command supports the following subcommands (with tab completion and `!` bang for force-attach):

- `auth signin` / `auth signout` — Authentication
- `attach` / `detach` / `toggle` — Buffer attach control (`attach!` forces)
- `enable` / `disable` — Global enable/disable
- `panel open` / `panel accept` / `panel jump_next` / `panel jump_prev` / `panel refresh` — Panel operations
- `suggestion accept` / `suggestion accept_word` / `suggestion accept_line` / `suggestion next` / `suggestion prev` / `suggestion dismiss` / `suggestion toggle_auto_trigger` — Suggestion operations
- `status` / `version` — Status/version info

Default action when no subcommand given: `auth` → `signin`, `panel` → `open`, `suggestion` → `toggle_auto_trigger`, bare `:Copilot` → `status`.

Unknown first-level args fall back to `copilot.command` module (e.g., `:Copilot status` loads `copilot.command.status`).

---

## Dependencies

### Required

- **Neovim >= 0.8.0** (recommended >= 0.9.0; some features like `vim.ui.open` require >= 0.10)
- **Node.js >= 16.14** (>= 17.3 preferred, >= 18.x recommended) — Runs the Copilot language server
- **Git** — Used for version detection

### Optional

- **[copilot-cmp](https://github.com/zbirenbaum/copilot-cmp)** — nvim-cmp integration
- **[copilot-lualine](https://github.com/AndreM222/copilot-lualine)** — lualine status bar integration

### Dependents

- copilot.lua is a required dependency for copilot-cmp
- Any plugin needing Copilot completions can integrate via the `copilot.api` module

---

## Build / Test

### Build

- The `copilot/dist/` directory contains the pre-compiled Copilot language server
- dist files are updated automatically via GitHub Actions (`.github/workflows/update-copilot-dist.yaml`)

### Testing

This plugin has no formal test suite.

---

## Coding Conventions

### Code Style

Per `.stylua.toml`: `column_width = 120`, `indent_type = "Spaces"`, `indent_width = 2`, `quote_style = "AutoPreferDouble"`, `no_call_parentheses = false`, `line_endings = "Unix"`.

### Naming Conventions

- Module tables named `M` or `mod`
- Private functions declared with `local function`
- Public functions declared with `function M.name()` or `mod.name = function()`

### Type Annotations

- Uses LuaCATS type annotations (`---@class`, `---@alias`, `---@param`, `---@return`)
- Config classes marked with `---@class (exact)`

### Async Patterns

- Uses `coroutine.wrap` and `coroutine.yield` for synchronous-style async calls
- Uses `vim.schedule` / `vim.schedule_wrap` to ensure execution in the correct context
- Uses `vim.loop.new_timer()` for polling and timeouts

### Compatibility

- Code includes compatibility shims for Neovim 0.8 and 0.9+ API differences
- Falls back from `vim.lsp.get_clients` (0.9+) to `vim.lsp.get_active_clients` (0.8)
- Uses `vim.deprecate` or custom `deprecate` function to mark deprecated APIs
- `lsp_start` shim for Neovim < 0.8.2 with custom `reuse_client` logic
