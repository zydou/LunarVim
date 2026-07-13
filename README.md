# LunarVim (personal, offline fork)

My personal LunarVim configuration, forked from
[LunarVim@64764a2](https://github.com/LunarVim/LunarVim) and stripped of all
network dependence. Runs Neovim fully offline by shipping plugins and
tree-sitter parsers as pre-pinned, precompiled bundles. Targets **Neovim
v0.10.x only** (v0.10.4 latest).

## What's different from upstream LunarVim

| Aspect | Upstream | This fork |
|--------|----------|-----------|
| Plugin install | lazy.nvim fetches from GitHub at startup | Sources checked into `./plugins/` — no git at runtime |
| Plugin versions | lazy-lock.json | `lock.json` in the [nvim-plugins](https://github.com/zydou/nvim-plugins) bundle repo (commit-pinned) |
| Tree-sitter parsers | `:TSUpdate` downloads + compiles | 326 parsers prebuilt as `.so` (ABI 14) in the [tree-sitter-parsers](https://github.com/zydou/tree-sitter-parsers) bundle, deployed into `plugins/nvim-treesitter/parser/` |
| Commit-hash pinning code | Active | Removed — dead code |

## Repository layout

```
lvim/
├── init.lua                 # entry point: bootstrap → config → plugins → theme → commands
├── lua/lvim/
│   ├── bootstrap.lua        # rtp, dirs, lazy bootstrap, stdpath override
│   ├── plugin-loader.lua    # lazy.nvim init + plugin spec loading (dir-based, no git)
│   ├── plugins.lua          # ← the plugin list (core + user-merged); every spec uses `dir = plugin_dir("..")` (base-relative)
│   ├── config/
│   │   ├── defaults.lua     # base `lvim` global state (lazy root = ./plugins)
│   │   ├── init.lua         # seeds lvim, loads user config.lua, keymaps/autocmds
│   │   └── settings.lua     # `vim.opt` defaults (2-space indent, number, termguicolors)
│   ├── core/                # one module per feature: treesitter, cmp, lualine, gitsigns, …
│   ├── lsp/                 # LSP manager, per-server providers/, null-ls formatters+linters
│   └── utils/               # fs, modules, git, hooks
└── plugins/                 # ← checked-in plugin sources (gitignored *.so in parser/)
```

User overrides go in **`~/.config/lvim/config.lua`** (created automatically on first
run from the example) — never inside this repo. Config & data dirs are set by the
`lvim` wrapper at `~/.local/bin/lvim` (`LUNARVIM_CONFIG_DIR`, `LUNARVIM_CACHE_DIR`).

## How it works (startup)

1. `init.lua` → `lvim.bootstrap:init(base_dir)`
   - resolves `$LUNARVIM_RUNTIME_DIR`/`CONFIG_DIR`/`CACHE_DIR` (fallback to `stdpath()`),
   - computes `pack_dir = <runtime>/site` and `lazy_install_dir = <pack>/lazy/opt/lazy.nvim`,
   - inserts `lazy.nvim` + `lazy/opt/*` into `rtp`,
   - overrides `vim.fn.stdpath("cache")`, then inits mason.
2. `lvim.config:load()` runs `~/.config/lvim/config.lua`.
3. `lvim.plugin-loader.load({ plugins })` runs `lazy.setup()` over the `core_plugins`
   table in `plugins.lua`. Every entry is a local `dir =` into `./plugins/`, so lazy
   never touches the network. (The only git-clone code path is a one-time bootstrap
   of lazy.nvim if `plugins/lazy.nvim/` is missing — it isn't.)
4. `lvim.core.theme.setup()` + `lvim.core.commands.load()`.

## The two bundle repos

### Plugins — [zydou/nvim-plugins](https://github.com/zydou/nvim-plugins)

Every plugin pinned to a commit in `lock.json`, e.g.:

```json
"alpha-nvim": {
  "owner": "goolord",
  "repo": "alpha-nvim",
  "commit": "29074eeb869a6cbac9ce1fbbd04f5f5940311b32",
  "source": "https://github.com/goolord/alpha-nvim/archive/29074eeb….tar.gz"
}
```

The same sources are **checked into `./plugins/<name>/`** in this repo (a mirror
of the `lock.json` pins). To update a plugin: change `commit`/`source` in
`lock.json` and re-extract that tarball into `plugins/`.

Beyond LunarVim's defaults, also shipped (and now declared in `plugins.lua`):
`copilot.lua`, `copilot-cmp`, `glow.nvim`, `hlchunk.nvim`, `hop.nvim`,
`hydra.nvim`, `multicursors.nvim`, `neo-tree.nvim`, `noice.nvim`, `nui.nvim`,
`numb.nvim`, `nvim-colorizer.lua`, `nvim-lastplace`, `nvim-notify`,
`nvim-surround`, `rainbow-delimiters.nvim`, `todo-comments.nvim`,
`trouble.nvim`, `vim-matchup`. These were migrated from the former user
config `~/.config/lvim/lua/user/plugins.lua`.

### Tree-sitter parsers — [zydou/tree-sitter-parsers](https://github.com/zydou/tree-sitter-parsers)

326 grammar parsers compiled with `tree-sitter` CLI v0.24.7 to `.so` files
targeting **ABI 14**, which must match the running Neovim version
(**v0.10.x**). Built by `build.py` in parallel (`JOBS = min(CPUs, 16)`),
verified by a headless nvim parse test, then uploaded to the persistent
GitHub release
[`parsers`](https://github.com/zydou/tree-sitter-parsers/releases/download/parsers/parsers.tar.gz).

Deployed (gitignored) into **`plugins/nvim-treesitter/parser/`**. Because they're
precompiled, `:TSUpdate` is bypassed. To add a language:

```bash
cd ~/Projects/tree-sitter-parsers
python3 build.py <lang>                       # compile dist/<lang>.so
cp dist/<lang>.so ~/.local/share/lunarvim/lvim/plugins/nvim-treesitter/parser/
```

CI (`.github/workflows/build.yaml`) rebuilds on every push to `main` and
re-uploads the full `dist/*` to the release.

### LSP via static `ftplugin/`

`ftplugin/` is checked into the repo and replaces what `lua/lvim/lsp/templates.lua`
used to generate at boot. Neovim auto-loads `ftplugin/<filetype>.lua` when entering
a matching buffer; each file calls `lsp.manager.setup("<server>")`. Because a server
only ignites when mason has installed it **and** its binary is on `$PATH`
(`lsp/manager.lua` → `launch_server`), a file can list many candidate servers
while only the installed ones actually start.

The directory is a mix of two sources (same-named files are overwritten by the
user version):
- **Auto-generated files** (complete, unfiltered against mason-lspconfig's
  filetype mapping) — one per known filetype, each attempting every mapped server.
- **User hand-written files** — explicit `cmd` pointing at system-installed
  binaries (`ruff`, `ty`, `lua-language-server`, …) plus null-ls
  formatters/linters/code-actions, migrated from the former
  `~/.config/lvim/ftplugin/`.

To customize LSP for a filetype, edit its `ftplugin/<ft>.lua`. Regenerate the auto
base from `plugins/mason-lspconfig.nvim/lua/mason-lspconfig/mappings/filetype.lua`,
preserving any user-overwritten files. `lsp.templates_dir` in
`lua/lvim/lsp/config.lua` now points at this repo `ftplugin/` directory.

## Working on the config

There is no build step, no linter, and no test suite — the config is pure Lua
loaded by Neovim.

```bash
# Sanity-check that init.lua loads without error
nvim --headless +qall                          # exits 0 on success

# Hot-reload config inside a running Neovim
:LvimReload

# Inspect the resolved lvim global
:lua lvim.utils.generate_settings()            # writes ./lv-settings.lua

# Runtime log
:LvimLog   # or ~/.cache/lvim/log/lvim.log
```

**Adding a plugin:** edit the `core_plugins` table in `lua/lvim/plugins.lua`
(use `dir = "…"`, never `url`), and make sure the matching source dir exists in
`plugins/`. **Adding a parser:** build its `.so` and drop it in
`plugins/nvim-treesitter/parser/`.

## Requirements

- Neovim **v0.10.x** (the prebuilt parsers are ABI 14, which is ABI-locked to this version)
- The `lvim` wrapper at `~/.local/bin/lvim` sets `LUNARVIM_BASE_DIR` to this repo,
  `LUNARVIM_CONFIG_DIR` to `~/.config/lvim`, and launches the pinned nvim with
  `-u <base>/init.lua`
- `plugins/` is part of this repo (no separate extraction step)
- Parsers deployed into `plugins/nvim-treesitter/parser/` (gitignored `*.so`)
