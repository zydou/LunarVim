# CLAUDE.md - nvim-web-devicons

This file provides guidance to Claude Code for working with the nvim-web-devicons codebase.

## Project Overview

A Lua fork of [vim-devicons](https://github.com/ryanoasis/vim-devicons) for Neovim (>=0.7.0). Provides file-type icons **and** their colors, with light/dark variants driven by `&background`. Requires a Nerd Font (v2.3+). Published to LuaRocks.

## Directory Structure

```
nvim-web-devicons/
├── lua/nvim-web-devicons/
│   ├── nvim-web-devicons.lua      -- Main entry / public API
│   ├── icons-default.lua          -- Dark variant icon tables (SOURCE OF TRUTH)
│   ├── icons-light.lua            -- Light variant (AUTO-GENERATED, never hand-edit)
│   └── hi-test.lua                -- Highlight test module (:NvimWebDeviconsHiTest)
├── plugin/nvim-web-devicons.vim   -- Legacy guard, sets g:nvim_web_devicons and g:loaded_devicons
├── scripts/
│   ├── generate_colors.lua        -- `make colors` engine: generates icons-light.lua + cterm colors
│   └── filetype-generator.sh      -- Helper: maps icon names -> filetypes
├── .github/workflows/             -- CI (lint / style / colors), release, semantic-pr-subject
├── CONTRIBUTING.md                -- Build/order/icon-contribution conventions
├── Makefile                       -- all | colors | colors-check | style-check | style-fix | lint | clean
├── .editorconfig                  -- lf, final newline, 2-space lua indent
├── .stylua.toml                   -- column_width 120, 2-space, AutoPreferDouble, None call parens
├── .luacheckrc                    -- max_line_length 120, globals vim/jit/bit
├── .luarc.json                    -- sumneko lua 5.1, diagnostics globals vim/jit/bit
└── README.md
```

## Core Modules

### `plugin/nvim-web-devicons.vim` — Legacy Guard

Sets `g:nvim_web_devicons = 1` and `g:loaded_devicons = 1` to prevent double-loading. Guarded by `exists('g:loaded_devicons')`.

### `lua/nvim-web-devicons.lua` — Main Entry & Public API

**State**:
- Five low-level icon tables: `icons_by_filename`, `icons_by_file_extension`, `icons_by_operating_system`, `icons_by_desktop_environment`, `icons_by_window_manager`.
- A merged `icons` table — all five combined via `vim.tbl_extend("keep", ...)` then `vim.tbl_extend("force", icons, global_opts.override)` — with `icons[1] = default_icon`.
- `default_icon = { icon = "", color = "#6d8086", cterm_color = "66", name = "Default" }`.
- `global_opts` table: `override = {}, strict = false, default = false, color_icons = true`.
- `loaded` boolean guard.
- `filetypes` map: Neovim filetype -> icon name (206 entries).

**Icon lookup chain** (`get_icon_data`):
- Non-strict (`strict = false`, default):
  1. `icons[name]` — the merged table, so by_filename and by_extension entries collide by name.
  2. `get_icon_by_extension(name, ext, opts)` — if `ext` is given, looks up in `icons[ext]`; otherwise calls `iterate_multi_dotted_extension(name, icons)` which recursively peels segments after each `.` so `foo.tar.gz` tries `tar.gz`, then `gz`, etc., all against the merged table.
  3. `default_icon` if `has_default`.
- Strict (`strict = true`):
  1. `icons_by_filename[name]` only.
  2. `get_icon_by_extension(name, ext, opts)` — consults `icons_by_file_extension` only.
  3. `default_icon` if `has_default`.

**Highlight system**:
- `get_highlight_name(data)` -> `"DevIcon" .. data.name` (or `default_icon` when `color_icons == false`).
- `set_up_highlight(icon_data)` -> `nvim_set_hl(0, hl_group, { fg = color, ctermfg = tonumber(cterm_color) })`.
- `set_up_highlights(allow_override)`:
  - If `color_icons == false`, highlights only `default_icon` and returns early.
  - Otherwise loops `icons`, skipping entries without both a color and a name, and skips already-defined highlights unless `allow_override` is true.

**Autocmds**:
- `ColorScheme` -> `M.set_up_highlights()` (registered inside `setup()`).
- `OptionSet background` -> `M.refresh()` — registered at **module load**, outside `setup()`, so light/dark switching works even before `setup()` is called.

**User command**: `:NvimWebDeviconsHiTest` -> requires `hi-test` and passes `default_icon`, `global_opts.override`, and the five icon tables. Registered inside `setup()`.

#### Public API

| Function | Returns | Purpose |
|---|---|---|
| `setup(opts)` | nil | One-time init. Merges overrides, sets flags, builds `icons`, sets up highlights, registers ColorScheme autocmd + `:NvimWebDeviconsHiTest` command. Guarded by `loaded`. |
| `has_loaded()` | boolean | Whether setup ran. |
| `get_default_icon()` | table | The default icon. |
| `refresh()` | nil | `refresh_icons()` then `M.set_up_highlights(true)` (force override). Called on OptionSet background. |
| `get_icons()` | table | All merged icons. |
| `get_icons_by_filename()` | table | Icons by filename. |
| `get_icons_by_extension()` | table | Icons by extension. |
| `get_icons_by_operating_system()` | table | Icons by OS. |
| `get_icons_by_desktop_environment()` | table | Icons by DE. |
| `get_icons_by_window_manager()` | table | Icons by WM. |
| `get_icon(name, ext, opts)` | `icon, hl_group_name` | Primary lookup. Calls `setup()` lazily if not loaded. |
| `get_icon_colors(name, ext, opts)` | `icon, color, cterm_color` | Resolves actual highlight fg/ctermfg if a `DevIcon<name>` highlight group is already defined; otherwise falls back to the entry's color. |
| `get_icon_color(name, ext, opts)` | `icon, color` | Convenience wrapper over `get_icon_colors`. |
| `get_icon_cterm_color(name, ext, opts)` | `icon, cterm_color` | Convenience wrapper over `get_icon_colors`. |
| `get_icon_name_by_filetype(ft)` | string\|nil | Filetype -> icon-name via `filetypes` map. |
| `get_icon_by_filetype(ft, opts)` | `icon, hl_group` | Forces `strict = false`. |
| `get_icon_colors_by_filetype(ft, opts)` | `icon, color, cterm_color` | |
| `get_icon_color_by_filetype(ft, opts)` | `icon, color` | |
| `get_icon_cterm_color_by_filetype(ft, opts)` | `icon, cterm_color` | |
| `set_icon(user_icons)` | nil | Merges into `icons`, highlights each new/overridden entry unless `color_icons == false`. |
| `set_ui_by_filetype(user_filetypes)` | nil | Merges into `filetypes` map. |
| `set_default_icon(icon, color, cterm_color)` | nil | Mutates + highlights default icon. |

### `lua/nvim-web-devicons/icons-default.lua` & `icons-light.lua`

Both share identical structure (3760 lines each) and return one table with five sub-tables. Each sub-table (and the surrounding blank lines) falls roughly in these ranges:

- `icons_by_filename`           — lines 1–740
- `icons_by_file_extension`     — lines 742–3287
- `icons_by_operating_system`   — lines 3289–3632
- `icons_by_desktop_environment`— lines 3634–3683
- `icons_by_window_manager`     — lines 3685–3752
- `return { ... }`              — lines 3754–3760

**Icon entry schema** (key order **must** be preserved — enforced by CONTRIBUTING.md):

```lua
[".gitconfig"] = {
    icon = "",
    color = "#41535b",       -- html hex
    cterm_color = "0",       -- number as string, BELOW color; auto-regenerated by script
    name = "GitConfig",      -- alphanumeric only, no /, -, _; "DevIcon"..name = hl group
},
```

- **icons-default.lua**: the source of truth for colors and icons. Edit this one.
- **icons-light.lua**: **auto-generated**, never hand-edited. Colors are darkened versions of the dark variant via luminance tiers.

Theme selection (`refresh_icons`): `vim.o.background == "light"` -> icons-light, else icons-default.

### `lua/nvim-web-devicons/hi-test.lua`

Returns a **function** (not a module). Defines `IconDisplay` class with `:new(o)` and `:render(...)`.

Signature: `(default_icon, global_override, icons_by_filename, icons_by_file_extension, icons_by_operating_system, icons_by_desktop_environment, icons_by_window_manager)`.

Renders an unmodifiable buffer with six sections (Default, Overrides if present, then the five icon tables). Each row is `icon  tag  group  <highlight def>`, sorted by name, with per-line `nvim_buf_add_highlight`. Mimics `:so $VIMRUNTIME/syntax/hitest.vim`.

## Configuration

```lua
require'nvim-web-devicons'.setup {
  -- Merged into icons (always)
  override = { ... },
  -- Used only when strict = true
  override_by_filename = { [".gitignore"] = { ... } },
  override_by_extension = { ["log"] = { ... } },
  override_by_operating_system = { ["apple"] = { ... } },
  override_by_desktop_environment = { ... },
  override_by_window_manager = { ... },
  strict = false,     -- true: lookup by filename then extension only (prevents name/extension collisions)
  default = false,    -- true: return default_icon when no match
  color_icons = true, -- false: all icons use default_icon's color
}
```

There's no separate `default_icon` override field; to override the default icon, pass `override = { default_icon = { ... } }`.

## Scripts

### `scripts/generate_colors.lua` (run via `make colors`)

Requires LuaJIT + `lifepillar/vim-colortemplate` on runtimepath. Run from repo root. Edits `icons-default.lua` in place and generates `icons-light.lua`:

1. Opens `icons-default.lua`, for each of the 5 local tables calls `generate_lines()`, which `darken_color`s every `#xxxxxx`.
2. Writes all 5 darkened tables to `icons-light.lua`.
3. Runs `update_cterm_colors()` on both files: searches `^\s*color =`, approximates nearest cterm index via `colortemplate#colorspace#approx(color).index`, and updates (or inserts) the `cterm_color` line directly below.

### `scripts/filetype-generator.sh`

Fetches icon names from the original `kyazdani42/nvim-web-devicons` repo via curl, creates temp files, opens each in headless nvim to detect the buffer filetype, then prints a `local filetypes = { ['ft'] = { ... } }` table. Helpful when adding many icons. Not part of the build, and the upstream URL points to the old author namespace.

## Build / CI / Tooling

**Makefile targets**:
- `all` = `colors style-check lint`
- `colors` (depends on `vim-colortemplate`) — regenerate light icons and cterm colors
- `colors-check` (depends on `colors`) — `git diff --exit-code lua/nvim-web-devicons/icons-light.lua`
- `vim-colortemplate` — downloads `lifepillar/vim-colortemplate` v2.2.3
- `style-check` / `style-fix` — `stylua . --check` / `stylua .`
- `lint` — `luacheck lua scripts`
- `clean` — remove `vim-colortemplate/`

**CI jobs** (GitHub Actions):
- `lint`: `luarocks install luacheck 1.1.1` then `make lint`
- `style`: `stylua` v0.19 `--check lua scripts`
- `colors`: `make colors-check`

**Code style**: stylua (col width 120, 2-space indent, Unix LF, AutoPreferDouble quote style, None call parens). Lint via luacheck (max line length 120, globals: `vim`/`jit`/`bit`).

## Contributor Conventions (Key Rules)

1. **Alphabetical ordering** of `icons_by_filename`, `icons_by_file_extension`, and `filetypes` to avoid merge conflicts.
2. **Key/value order in icon entries is mandatory**: `icon`, `color`, `cterm_color`, `name` — `cterm_color` directly below `color`.
3. `color` = html hex; `cterm_color` = any number (the script corrects it); `name` = alphanumeric only.
4. Filename keys: always-named files (e.g. `.gitconfig`); extension keys: all files sharing an extension.
5. After changes run `make`; use `make style-fix` to auto-fix. Commit **both** `icons-default.lua` and `icons-light.lua`.
6. Test via `:NvimWebDeviconsHiTest`, with `TERM=xterm-256color nvim`, under both `&background` values.
7. PRs: reference issues; enable "allow edits by maintainers"; Conventional Commit subject required by CI.

## Notable Gotchas

- **Always edit `icons-default.lua`, never `icons-light.lua`.** The latter is regenerated by `make colors`. A hand-edit to `icons-light.lua` will fail the `colors-check` CI job.
- The 5 tables are `local` declarations in a single file; the generator walks them by searching `^local icons_by_...` markers in that exact order.
- Multi-dotted extension handling is recursive (`iterate_multi_dotted_extension`) — intentional for files like `foo.tar.gz`.
- `OptionSet background` autocmd is registered at **module load**; `ColorScheme` autocmd and the `:NvimWebDeviconsHiTest` command are created only inside `setup()`.
- `setup()` is guarded by `loaded` and auto-invoked lazily from `get_icon*` if not yet called.
- `color_icons = false` collapses every highlight (and `get_highlight_name`) to the `default_icon` values.
- Strict mode is what activates the dedicated `override_by_*` tables.
- `filetypes` maps Neovim `&filetype` to an **icon name** (a string key into the icon tables), not to the icon entry itself.
- `vim.tbl_extend("keep", ...)` is used in `refresh_icons` so base icons win over each other, while `vim.tbl_extend("force", ...)` in `setup` lets user overrides clobber.
