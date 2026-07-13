# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is a **personal, offline LunarVim configuration** forked from [LunarVim@64764a2](https://github.com/LunarVim/LunarVim) and stripped of all network dependence. It targets **Neovim v0.10.x** only.

There are **no** LunarVim tests, Makefiles, CI workflows, or `.github` config in this repo. The config is pure Lua and is loaded at startup by Neovim directly — there is nothing to build, lint, or "run" except by launching Neovim, which is done through the `lvim` wrapper at `~/.local/bin/lvim` (sets `LUNARVIM_*` env vars, then `exec`s the pinned nvim with `-u <base>/init.lua`).

This is a **single-repo, fully self-contained setup**:

1. **This repo (`lvim/`)** — `init.lua` + `lua/` config, **plus** the `plugins/` directory checked into git. Every plugin ships as a source directory pinned to a commit hash (sourced from the [`zydou/nvim-plugins`](https://github.com/zydou/nvim-plugins) bundle, which records the pin in its `lock.json`). All `dir =` specs point into `./plugins/`, resolved relative to `$LUNARVIM_BASE_DIR`.
2. **[`zydou/tree-sitter-parsers`](https://github.com/zydou/tree-sitter-parsers)** — 326 tree-sitter grammars compiled to `.so` (ABI 14, matching nvim v0.10.x) and released as `parsers.tar.gz`, downloaded at deploy time into `plugins/nvim-treesitter/parser/`. These `.so` files are **gitignored** (see `plugins/.gitignore`) and must not be committed here.

Neovim runs fully offline — there is no network code path. Even lazy.nvim itself is shipped inside `plugins/lazy.nvim/`, so the `git clone` fallback in `plugin-loader.lua` never fires.

User overrides go in `~/.config/lvim/` (config dir), tracked separately — key bindings and options in `config.lua`, **not** in this repo. (The user plugin table that once lived in `~/.config/lvim/lua/user/plugins.lua` has been merged into `lua/lvim/plugins.lua`.)

## Architecture / startup sequence

`init.lua` → `lvim.bootstrap:init()` → `lvim.config:load()` → `lvim.plugin-loader.load()` → `lvim.core.theme` → `lvim.core.commands`.

1. **`bootstrap.lua`** — sets `rtp`, computes `runtime_dir` / `config_dir` / `cache_dir` / `pack_dir` (defaults sourced from `$LUNARVIM_*` env vars, falling back to `stdpath()`), installs the `lazy.nvim` bootstrap, overrides `vim.fn.stdpath("cache")`, and calls `plugin-loader.init()`. It also kicks off `mason.bootstrap()`.
2. **`plugin-loader.lua`** — inserts `lazy.nvim` + `site/pack/lazy/opt/*` into `rtp`, sets lazy's cache path to `$LUNARVIM_CACHE_DIR`, then `lazy.setup()`s the plugin specs. The `load()` function removes and re-adds the opt glob before calling lazy, so plugins aren't loaded twice on startup.
3. **`plugins.lua`** — the **single source of truth for the plugin list** (core plugins + formerly-user plugins merged in). Every plugin is declared with `dir = plugin_dir("<name>")`, where the local helper resolves `get_lvim_base_dir() .. "/plugins/<name>"` — no hardcoded `~`, no `url`, no git. The commit-locking block is intentionally dead code, commented out because plugins are shipped locally.
4. **`config/init.lua`** — `init()` seeds `lvim` global from `config.defaults`, loads keymappings/builtins/settings/autocmands/lsp config. `load()` `dofile`s the user's `~/.config/lvim/config.lua` (the only runtime file outside this repo).
5. **`lvim.*` global** — a big state table (`lvim.builtin.*`, `lvim.lsp`, `lvim.keymappings`, etc.) read by the `core/` modules that actually wire each plugin up.

### Key directories

- `lua/lvim/config/` — `lvim` global init, defaults, user-config loader. Users customize via `~/.config/lvim/config.lua`, not here.
- `lua/lvim/core/` — one module per feature (`treesitter`, `cmp`, `lualine`, `telescope`, `gitsigns`, `terminal`, `bufferline`, `mason`, `autocmds`, `theme`, `commands`, `log`, …). Each `requires` its plugin and applies config via `lvim.builtin.<name>` options.
- `lua/lvim/lsp/` — LSP manager, per-server providers in `lsp/providers/*.lua` (e.g. `lua_ls`, `jsonls`, `yamlls`, `tailwindcss`, `vuels`), and `null-ls/{formatters,linters,code_actions,services}` for format-on-save/diagnostics.
- `lua/lvim/utils/` — filesystem helpers, module (re)loading, git, hooks.
- `plugins/` — **checked-in plugin sources** (gitignored `*.so` in `plugins/nvim-treesitter/parser/`). Resolved by lazy.nvim via the root path in `config/defaults.lua`.

### Plugin list and how to change it

To **add/remove/edit a plugin**: edit the `core_plugins` table in `lua/lvim/plugins.lua` AND make sure the matching source dir exists under `plugins/<name>/`. The source comes from the `nvim-plugins` bundle repo (edit its `lock.json` + add/remove the dir there too) so the `plugins/` tree stays in sync.

Beyond LunarVim's defaults, `plugins.lua` also declares these extra plugins (all already in `plugins/`): `copilot.lua`, `copilot-cmp`, `glow.nvim`, `hlchunk.nvim`, `hop.nvim`, `hydra.nvim`, `multicursors.nvim`, `neo-tree.nvim`, `noice.nvim`, `nui.nvim`, `numb.nvim`, `nvim-colorizer.lua`, `nvim-lastplace`, `nvim-notify`, `nvim-surround`, `rainbow-delimiters.nvim`, `todo-comments.nvim`, `trouble.nvim`, `vim-matchup`. They were migrated from the former user config `~/.config/lvim/lua/user/plugins.lua`.

### Tree-sitter parsers

Parsers live at `plugins/nvim-treesitter/parser/*.so`, all targeting **ABI 14 (nvim v0.10.x)**, gitignored via `plugins/.gitignore`. `core/treesitter.lua` prepends `plugins/nvim-treesitter/` to `rtp` before setup. Because parsers are prebuilt .so files, `:TSUpdate`/grammar install is bypassed. To add a new language: build it in the `tree-sitter-parsers` repo (`build.py <lang>`, requires `tree-sitter` CLI v0.24.7, ABI 14), drop the resulting `.so` into `plugins/nvim-treesitter/parser/`. `ensure_installed` in `core/treesitter.lua` is only consulted for listings — with precompiled parsers it's effectively inert. ABI matters: a `.so` built for a different ABI will fail to load on v0.10.x.

### ftplugin (static LSP auto-ignite)

`ftplugin/` is **static and checked into the repo** — the runtime generator
(`templates.lua`) was removed. Neovim auto-loads `ftplugin/<ft>.lua` when entering
a matching buffer; each file calls `lsp.manager.setup("<server>")`. A server only
actually starts if mason installed its package **and** the binary is on `$PATH`
(`lsp/manager.lua` → `launch_server`), so a file may list many candidates but
only installed ones ignite.

Two populations coexist (user files overwrite auto-generated ones of the same name):
1. **Auto-generated (complete, unfiltered)** — parsed from mason-lspconfig's
   `mappings/filetype.lua`; attempts *every* server mapped to the filetype.
2. **User hand-written** — explicit `cmd` (system binaries like `ruff`, `ty`,
   `lua-language-server`) plus null-ls formatters/linters/code-actions. These
   were migrated from the former `~/.config/lvim/ftplugin/` and take precedence.

To override LSP for a filetype, edit the matching `ftplugin/<ft>.lua`. The
auto base can be regenerated from mason-lspconfig's mapping; preserve the
user-overwritten files across regeneration. `lsp.templates_dir` in
`config/defaults.lua` now points at this repo dir (was the generated
`site/after/ftplugin`).

## Common commands / how to work on this config

There is no build step. Change a file in `lua/`, then in a running Neovim instance do `:LvimReload` to hot-reload (`config/init.lua` `M:reload()`), or restart Neovim.

| Task | How |
|------|-----|
| Validate config loads | `nvim --headless +qall` (exits 0 if init.lua succeeded; errors print to stderr) |
| See startup log | `:LvimLog` or open `~/.cache/lvim/log/lvim.log` |
| Dump effective `lvim` options | In Neovim, call `lvim.utils.generate_settings()` → writes `lv-settings.lua` in cwd |
| Add a plugin | Edit `plugins.lua` + ensure dir exists in `site/pack/lazy/opt/`; the source comes from `nvim-plugins` repo |
| Update a plugin's source | Pin a new commit in `nvim-plugins/lock.json`, re-extract into opt dir |
| Regenerate a tree-sitter parser | `python3 build.py <lang>` in the `tree-sitter-parsers` repo, copy `.so` to opt parser dir |
| LSP for a filetype | `:LspInfo`, `:LspInstall` (mason), per-server config in `lua/lvim/lsp/providers/` |

## Conventions

- Plugin specs use `dir = "..."` into `./plugins/`, never `url`/`commit`. Do not reintroduce the git-commit-locking block — it's dead code.
- Keep `plugins/` in sync with the `nvim-plugins` bundle repo's `lock.json`; never commit `*.so` files (they're gitignored).
- User overrides belong in `~/.config/lvim/config.lua`, tracked separately — do not edit that file from this repo.
- The global namespace is `lvim` (standard LunarVim pattern); core modules read `lvim.builtin.<feature>` for their options.
