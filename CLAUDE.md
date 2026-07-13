# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is a **personal, offline LunarVim configuration** forked from [LunarVim@64764a2](https://github.com/LunarVim/LunarVim) and stripped of all network dependence. It targets **Neovim v0.10.x** only.

There are **no** LunarVim tests, Makefiles, CI workflows, or `.github` config in this repo. The config is pure Lua and is loaded at startup by Neovim directly — there is nothing to build, lint, or "run" except by launching Neovim.

The three-piece deployment this config relies on:

1. **This repo (`lvim/`)** — the Neovim config (init.lua + lua/ tree).
2. **[`zydou/nvim-plugins`](https://github.com/zydou/nvim-plugins)** — every plugin source pinned to a commit hash, shipped as pre-extracted directories under `~/.local/share/lunarvim/site/pack/lazy/opt/`. Each plugin dir is a clone at the commit listed in `lock.json`.
3. **[`zydou/tree-sitter-parsers`](https://github.com/zydou/tree-sitter-parsers)** — 326 tree-sitter grammars compiled to .so (ABI 14, matching nvim v0.10.x) and released as `parsers.tar.gz`, extracted into `~/.local/share/lunarvim/site/pack/lazy/opt/nvim-treesitter/parser/`.

If plugin + parsers are already installed on the machine, Neovim runs fully offline. The only network code path is the lazy.nvim bootstrap fallback in `plugin-loader.lua`, which `git clone`s from `https://cnb.cool/bennydou/vim/lazy.nvim.git` only if the opt dir is empty — in normal operation this never fires.

## Architecture / startup sequence

`init.lua` → `lvim.bootstrap:init()` → `lvim.config:load()` → `lvim.plugin-loader.load()` → `lvim.core.theme` → `lvim.core.commands`.

1. **`bootstrap.lua`** — sets `rtp`, computes `runtime_dir` / `config_dir` / `cache_dir` / `pack_dir` (defaults sourced from `$LUNARVIM_*` env vars, falling back to `stdpath()`), installs the `lazy.nvim` bootstrap, overrides `vim.fn.stdpath("cache")`, and calls `plugin-loader.init()`. It also kicks off `mason.bootstrap()`.
2. **`plugin-loader.lua`** — inserts `lazy.nvim` + `site/pack/lazy/opt/*` into `rtp`, sets lazy's cache path to `$LUNARVIM_CACHE_DIR`, then `lazy.setup()`s the plugin specs. The `load()` function removes and re-adds the opt glob before calling lazy, so plugins aren't loaded twice on startup.
3. **`plugins.lua`** — the **single source of truth for the plugin list**. Every plugin is declared with `dir = "~/.local/share/lunarvim/site/pack/lazy/opt/<name>"` — no `url`, no git. The commit-locking block (commit-hash pinning via `snapshots/default.json`) is intentionally dead code, commented out because plugins are distributed locally.
4. **`config/init.lua`** — `init()` seeds `lvim` global from `config.defaults`, loads keymappings/builtins/settings/autocmands/lsp config. `load()` `dofile`s the user's `~/.config/lvim/config.lua` (the only runtime file outside this repo).
5. **`lvim.*` global** — a big state table (`lvim.builtin.*`, `lvim.lsp`, `lvim.keymappings`, etc.) read by the `core/` modules that actually wire each plugin up.

### Key directories

- `lua/lvim/config/` — `lvim` global init, defaults, user-config loader. Users customize via `~/.config/lvim/config.lua`, not here.
- `lua/lvim/core/` — one module per feature (`treesitter`, `cmp`, `lualine`, `telescope`, `gitsigns`, `terminal`, `bufferline`, `mason`, `autocmds`, `theme`, `commands`, `log`, …). Each `requires` its plugin and applies config via `lvim.builtin.<name>` options.
- `lua/lvim/lsp/` — LSP manager, per-server providers in `lsp/providers/*.lua` (e.g. `lua_ls`, `jsonls`, `yamlls`, `tailwindcss`, `vuels`), and `null-ls/{formatters,linters,code_actions,services}` for format-on-save/diagnostics.
- `lua/lvim/utils/` — filesystem helpers, module (re)loading, git, hooks.
- `snapshots/default.json` — the LunarVim canonical commit pin table for core plugins (kept for reference; no longer read at runtime).

### Plugin list and how to change it

To **add/remove/edit a plugin**: edit `lua/lvim/plugins.lua` (the `core_plugins` table) AND mirror the change in the `nvim-plugins` bundle repo (add/remove the dir + entry in its `lock.json`) so the source is actually present in `site/pack/lazy/opt/`. Updates to `lock.json` alone do nothing — the dir on disk must also exist.

The bundle currently ships these **extra plugins beyond LunarVim's defaults**: `copilot.lua`, `copilot-cmp`, `glow.nvim`, `hlchunk.nvim`, `hop.nvim`, `hydra.nvim`, `multicursors.nvim`, `neo-tree.nvim`, `noice.nvim`, `nui.nvim`, `numb.nvim`, `nvim-colorizer.lua`, `nvim-lastplace`, `nvim-notify`, `nvim-surround`, `rainbow-delimiters.nvim`, `todo-comments.nvim`, `trouble.nvim`, `vim-matchup`. These aren't declared in `plugins.lua` yet (disabled) — wire them up here when enabling.

### Tree-sitter parsers

Parsers live at `site/pack/lazy/opt/nvim-treesitter/parser/*.so`, all targeting **ABI 14 (nvim v0.10.x)**. `core/treesitter.lua` prepends the treesitter package dir to `rtp` before setup. Because parsers are prebuilt .so files, `:TSUpdate`/grammar install is bypassed entirely. To add a new language: build it in the `tree-sitter-parsers` repo (`build.py <lang>`, requires `tree-sitter` CLI v0.24.7, ABI 14), drop the resulting `.so` into the parser dir. `ensure_installed` in `core/treesitter.lua` is only consulted for listings — with precompiled parsers it's effectively inert. Re-parsing ABI matters: a `.so` built for a different ABI will fail to load on v0.10.x.

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

- Plugin specs use `dir = "..."`, never `url`/`commit`. Do not reintroduce the git-commit-locking block — it's dead code for a reason (it crashes under headless invocation when `LVIM_DEV_MODE` is unset).
- User overrides belong in `~/.config/lvim/config.lua`, tracked separately — do not edit that file from this repo.
- The global namespace is `lvim` (standard LunarVim pattern); core modules read `lvim.builtin.<feature>` for their options.
