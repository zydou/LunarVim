# nvim-lastplace

## Overview

nvim-lastplace is a Neovim plugin that automatically restores the cursor to its last position when a file is reopened. It is a Lua rewrite of [vim-lastplace](https://github.com/farmergreg/vim-lastplace).

> **Note:** The plugin is no longer maintained (declared "NO LONGER MAINTAINED" in the README), but is considered feature-complete for its author's use case.

## Directory Structure

```
nvim-lastplace/
├── LICENSE
├── README.md
└── lua/
    └── nvim-lastplace/
        └── init.lua          # The single source file containing all plugin logic
```

The entire plugin consists of a single Lua module.

## Core Module

### `nvim-lastplace.init` (`lua/nvim-lastplace/init.lua`)

Returns a table `lastplace` exposing the following public API:

- **`lastplace.setup(options)`** — Entry point. Merges user options with defaults and registers autocommands based on the detected Neovim version.
- **`lastplace.lastplace_buf()`** — Legacy cursor-restore entry point for old Neovim (<0.7). Registered on `BufWinEnter`. Only checks `buftype` on 0.5.1; checks both `buftype` and `filetype` otherwise.
- **`lastplace.lastplace_ft(buffer)`** — Main cursor-restore entry point. Registered on `FileType` in the old (<0.7, non-0.5.1) path, and called from a per-buffer `BufWinEnter` callback in the 0.7+ path. Always checks both `buftype` and `filetype`.

Internal helpers:

- **`split_on_comma(str)`** — Splits a comma-separated string into a table (used to bridge Vim global-variable options that are set as comma-separated strings).
- **`set_option(option, default)`** — Resolves an option value using priority: user-supplied `options` table > Vim global variable (`vim.g[option]`) > hardcoded `default`. Boolean table values are coalesced into `0`/`1` integers to match the vim-style global-variable conventions.
- **`set_cursor_position()`** — Reads the `'"` mark and decides how to restore the cursor:
  1. If the window already shows the buffer's last line (`w$ == $`): `keepjumps normal! g`"`
  2. If the last-edited line is far from the buffer bottom (more than half the window height away): `keepjumps normal! g`"zz`
  3. Otherwise (last edit is near the bottom): `keepjumps normal! G`
  - Regardless of the branch, if `foldclosed(".") ~= -1` and `lastplace_open_folds` is `1`, it runs `normal! zvzz` to open the fold and center the view.

## Version-Dependent Autocommand Behavior

`setuptools` detects the Neovim version and registers autocommands differently:

### Neovim >= 0.7 (Lua API path)

```text
BufRead
  └─ creates a one-shot "BufWinEnter" autocmd for the current buffer
       └─ calls lastplace.ft(buffer)
```

- Uses `nvim_create_augroup("NvimLastplace", { clear = true })` and `nvim_create_autocmd`.
- `lastplace_ft` handles both `buftype` and `filetype` filtering.

### Neovim < 0.7, but not exactly 0.5.1 (Vimscript autocmd path)

```text
BufWinEnter * → require('nvim-lastplace').lastplace_buf()
FileType    * → require('nvim-lastplace').lastplace_ft()
```

- The `FileType` autocmd calls `lastplace_ft`, which resets the cursor for ignored filetypes.
- The `BufWinEnter` autocmd calls `lastplace_buf`.

### Neovim == 0.5.1 (special-case path)

```text
BufWinEnter * → require('nvim-lastplace').lastplace_buf()
-- no FileType autocmd is registered
```

- Only `BufWinEnter` → `lastplace_buf` is set up; the `FileType` handler is intentionally skipped.
- `lastplace_buf` itself also skips the `filetype` check on 0.5.1 (mirrored by the missing autocmd).

### Shared pre-restore short-circuit (all versions)

Both `lastplace_buf` and `lastplace_ft` bail out early if the cursor is already past line 1 (e.g. when launched with `nvim file +num`), so an explicitly requested line number is preserved.

For ignored `filetype` values, the cursor is reset to the first line via `normal! gg`.

## Configuration

Configured through `setup`:

```lua
require('nvim-lastplace').setup {
    lastplace_ignore_buftype = {"quickfix", "nofile", "help"},
    lastplace_ignore_filetype = {"gitcommit", "gitrebase", "svn", "hgcommit"},
    lastplace_open_folds = true,
}
```

### Options

| Option                       | Type    | Default                                          | Description                                                       |
| ---------------------------- | ------- | ------------------------------------------------ | ----------------------------------------------------------------- |
| `lastplace_ignore_buftype`   | table   | `{"quickfix", "nofile", "help"}`                 | Buffer types for which cursor restoration is skipped              |
| `lastplace_ignore_filetype`  | table   | `{"gitcommit", "gitrebase", "svn", "hgcommit"}`  | File types for which cursor restoration is skipped                |
| `lastplace_open_folds`       | boolean | `true`                                           | Whether to open closed folds around the restored cursor position  |

### Vim Global Variable Compatibility

For users configuring via `init.vim`, options can also be set as Vim global variables (comma-separated strings for lists; `0`/`1` for booleans):

```vim
let g:lastplace_ignore_buftype = "quickfix,nofile,help"
let g:lastplace_ignore_filetype = "commit,gitrebase,svn,hgcommit"
let g:lastplace_open_folds = 1
```

## Dependencies

- **No external dependencies** — only relies on the Neovim standard API (`vim.fn`, `vim.api`, `vim.cmd`, `vim.g`).
- Compatible with Neovim 0.5.1+ and 0.7+, using distinct autocmd registration strategies per version (see above).

## Coding Conventions

- Uses `vim.fn` and `vim.api` for Neovim standard operations; `vim.cmd` is only used to register legacy Vimscript autocommands on old Neovim versions.
- Boolean options are internally normalized to `0`/`1` integers to match the numeric convention of the corresponding Vim global variables.
- Uses `keepjumps` on `normal!` commands so that cursor restoration does not pollute the jump list.
- The `'"` (last-position) mark is the sole source of truth for where to restore; the window-relative branches (`g`"`, `g`"zz`, `G`, `zvzz`) only adjust how the viewport is repositioned after the jump.
