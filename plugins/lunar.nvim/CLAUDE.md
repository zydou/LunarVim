# lunar.nvim — Claude Code Reference

Neovim colorscheme plugin based on LunarVim's "lunar" theme (derived from a TokyoNight-style palette). Provides a single `lunar` colorscheme plus a matching Lualine theme.

## Project Overview

- **Name**: `lunar.nvim`
- **Author**: Christian Chiarulli (`chrisatmachine@gmail.com`)
- **Background**: `dark` (hardcoded in `setup`)
- **Function**: Dark colorscheme for Neovim with highlight groups for editor components, Treesitter, LSP diagnostics, and many popular plugins; includes a bundled Lualine theme.

## Directory Structure

```
lunar.nvim/
├── README.md                          # Brief project description
├── LICENSE                            # License
├── lunarvim.toml                      # Color config source (TOML; palette + highlight groups)
├── .gitignore
├── colors/
│   └── lunar.vim                      # Vim entry script; calls lua/lunar.lua
└── lua/
    ├── lualine/
    │   └── themes/
    │       └── lunar.lua              # Bundled Lualine theme
    └── lunar/
        ├── init.lua                   # Main module; exposes setup() API
        ├── palette.lua                # Palette definition (color constants)
        └── theme.lua                  # Highlight group definitions (core file)
```

**Note**: `lunarvim.toml` is a TOML equivalent of `palette.lua` / `theme.lua`. When adding or modifying colors/highlights, the TOML and Lua must be updated together to stay in sync.

## Core Modules

### `lua/lunar/init.lua`
- **Role**: Entry module; exposes the public API.
- **Public API**:
  ```lua
  require("lunar").setup()
  ```
- **Behavior**:
  - Runs `hi clear` to clear existing highlights
  - Sets dark background (`vim.o.background = 'dark'`)
  - Resets syntax if `syntax_on` exists (`syntax reset`)
  - Enables true color (`termguicolors = true`)
  - Sets `vim.g.colors_name = 'lunar'`
  - Calls `theme.set_highlights()` to register all highlight groups

### `lua/lunar/palette.lua`
- **Role**: Defines the palette (a table of color constants).
- **Returns**: A `name -> "#rrggbb"` map.
- **Categories**: Base colors, Git-related colors, diff colors, statusline/popup colors, borders, error/warning/info/hint severity colors.

### `lua/lunar/theme.lua`
- **Role**: Registers all highlight groups via `vim.api.nvim_set_hl`.
- **Exports**: `set_highlights()` function.
- **Coverage**:
  - Editor (cursor line, search, popup menu, sign column, folds, etc.)
  - Code (base syntax: Comment/String/Function/Keyword/Type/etc.)
  - Treesitter (`@` semantic markers + LSP Semantic Tokens + Markdown inline)
  - Markdown
  - LSP (Diagnostic + legacy NvimTree/LspDiagnostics aliases)
  - Plugin-specific groups: WhichKey, GitSigns, Quickscope, Eyeliner, Telescope, NvimTree, Lir, Buffer, StatusLine, IndentBlankline, Bookmarks, Bqf, Cmp, Navic, Packer, SymbolOutline, Notify, TreesitterContext, Hop, Crates

### `lua/lualine/themes/lunar.lua`
- **Role**: Supplies colors for Lualine.
- **Approach**: Hardcodes a set of colors (blue/green/magenta/red/yellow/fg/bg/gray); defines `a`/`b`/`c` segments for `normal` and `inactive` modes, and `a`/`b` segments only for `insert`/`visual`/`command`/`replace` modes.

## Usage

**As a colorscheme**:

Vimscript:
```vim
colorscheme lunar
```

Or via Lua:
```lua
require("lunar").setup()
```

**With Lualine**:
```lua
require("lualine").setup {
  options = { theme = "lunar" }
}
```

**Note**: `setup()` takes no parameters. There is no runtime configuration for palette or highlight groups.

## Dependencies

### Required
None. The colorscheme only depends on Neovim built-in APIs (`vim.api.nvim_set_hl`).

### Soft dependencies (highlight groups / integrations)
The following plugins have corresponding highlight groups defined by this colorscheme. Defining the groups is safe (no side effects) even when the plugin is not installed:

- `nvim-treesitter` / Neovim built-in treesitter
- `nvim-lspconfig` (LSP diagnostics + Semantic Tokens)
- `nvim-tree` (NvimTree)
- `telescope.nvim`
- `lualine.nvim`
- `gitsigns.nvim`
- `which-key.nvim`
- `cmp` (nvim-cmp)
- `nvim-navic`
- `packer.nvim`
- `aerial.nvim` / `symbols-outline.nvim` (SymbolOutline)
- `nvim-notify`
- `treesitter-context.nvim`
- `hop.nvim`
- `crates.nvim`
- `quickscope.nvim`
- `eyeliner.nvim`
- `lir.nvim`
- `bufferline.nvim` (Buffer* groups + BufferLineIndicatorSelected)
- `indent-blankline.nvim`
- `bookmarks.nvim`
- `bqf.nvim`

### Dependents
- Other Neovim configs can depend on this plugin and enable it directly.
- `lualine/themes/lunar.lua` can be referenced directly by Lualine.

## Coding Conventions

### General
- **Language**: Lua (Neovim config style; no external libraries).
- **Indentation**: 2 spaces.
- **Naming**:
  - Module files are lowercase with `.lua` extension (`palette.lua`, `theme.lua`).
  - Lua variables/functions use `snake_case`.
  - Neovim highlight groups follow Vim built-in naming (`Normal`, `CursorLine`) or Treesitter/LSP conventions (`@function.builtin`, `@lsp.type.variable`).
  - Color keys are kept consistent across palette / theme.lua / lualine (`fg`, `bg`, `blue`, `green`, ...).
- **Module pattern**: `local M = {}; M.foo = ...; return M`.

### Palette changes
- When changing a color, **update both** `lua/lunar/palette.lua` and the `[palette]` section of `lunarvim.toml`.
- Color values use `#rrggbb` hex strings.

### Highlight group changes
- When changing a highlight, **update both** `lua/lunar/theme.lua` and the corresponding section of `lunarvim.toml` (`[Editor]`, `[Code]`, `[Treesitter]`, `[LSP]`, `[Telescope]`, etc.).
- Register with `vim.api.nvim_set_hl(0, name, opts)`.
- Link to an existing highlight with `{ link = 'Target' }`.
- Unset attributes use `'NONE'` (Lua) or `'-'` (TOML) as a placeholder.
- Style flags: `bold=true`, `italic=true`, `underline=true`, `undercurl=true`, `strikethrough=true`.

### Lualine theme
- When changing the Lualine theme, only edit `lua/lualine/themes/lunar.lua`; no TOML sync is needed.
- Color values are hardcoded (does not require the palette module).

### Adding a new plugin
1. Add the new groups in `lua/lunar/theme.lua` inside `set_highlights()`.
2. Add a corresponding section in `lunarvim.toml` (e.g. `[NewPlugin]`).
3. Register it in the "Soft dependencies" section of this document.

## Known Quirks
- `CmpItemKindDefaultc` (note the trailing `c`) is a historical typo present in both `theme.lua` and `lunarvim.toml`. Keep it consistent across both files if changing it.
- `@punctuation.delimeter` (misspelled "delimiter") is a historical typo present in both `theme.lua` and `lunarvim.toml`. Keep it consistent across both files if changing it.
