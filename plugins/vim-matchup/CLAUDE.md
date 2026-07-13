# vim-matchup

## Project Overview

A Vim/Neovim plugin that provides enhanced `%` key matching navigation. Compared to the built-in `matchit`, it supports more matching pairs (including HTML tags, function/class blocks, Markdown headers, etc.), Tree-sitter integration, off-screen match display, and rich text objects and motion commands.

- **Author**: Andy Massimino
- **License**: MIT
- **Requirements**: Vim 7.4+ or Neovim 0.1.7+; Neovim 0.5+ recommended with Tree-sitter

## Directory Structure

```
vim-matchup/
├── autoload/
│   ├── matchup.vim                 # Initialization entry point (matchup#init)
│   └── matchup/
│       ├── delim.vim               # Core delimiter matching algorithm (get_next/prev/current/surrounding)
│       ├── motion.vim              # Motion commands (%, g%, ]%, [%, z%, Z%)
│       ├── text_obj.vim            # Text objects (a%, i%)
│       ├── matchparen.vim          # Matching paren highlighting (replaces built-in matchparen)
│       ├── where.vim               # Off-screen match info display (:MatchupWhereAmI)
│       ├── transmute.vim           # Transpose matching pairs (experimental)
│       ├── surround.vim            # Surround operations (ds%, cs%)
│       ├── loader.vim              # Lazy loading mechanism
│       ├── perf.vim                # Performance measurement (tic/toc)
│       ├── quirks.vim              # Special language handling
│       ├── custom.vim              # Custom match pairs and user-defined motions
│       ├── re.vim                  # Regex engine helpers
│       ├── pos.vim                 # Position/coordinate utilities
│       ├── misc.vim                # Miscellaneous utilities (MatchupReload)
│       ├── util.vim                # General utilities
│       ├── test.vim                # Test helpers
│       ├── unmatchit.vim           # Disable built-in matchit
│       ├── ts_engine.vim           # Tree-sitter engine bridge
│       └── ts_syntax.vim           # Tree-sitter syntax highlighting integration
├── lua/
│   ├── match-up.lua                # Lua entry point (M.setup)
│   ├── treesitter-matchup.lua      # Tree-sitter module registration
│   └── treesitter-matchup/
│       ├── internal.lua            # Tree-sitter matching implementation
│       ├── compat.lua              # nvim-treesitter compatibility layer
│       ├── syntax.lua              # Syntax highlighting
│       ├── util.lua                # Utility functions
│       └── third-party/            # Third-party code (query, lru, utils, hl-info, reload)
├── plugin/
│   └── matchup.vim                 # Vim plugin entry point
├── after/
│   ├── plugin/matchit.vim          # Loads matchit functionality
│   ├── ftplugin/                   # File type-specific configuration (15 file types)
│   │   ├── html_matchup.vim
│   │   ├── lua_matchup.vim
│   │   ├── ruby_matchup.vim
│   │   └── ...
│   └── queries/                    # Tree-sitter query files (31 languages)
│       ├── html/matchup.scm
│       ├── lua/matchup.scm
│       ├── python/matchup.scm
│       └── ...
├── doc/
│   └── matchup.txt                 # Vim help documentation
├── test/                           # Test directory
│   ├── vader                       # Vader test framework
│   ├── issues                      # Regression tests
│   ├── lang                        # Language-specific tests
│   ├── legacy                      # Legacy compatibility tests
│   ├── new                         # New test suite (Makefile-based)
│   ├── scripts                     # Test scripts
│   └── minvimrc                    # Minimal vimrc for testing
├── .gitlab-ci.yml                  # CI configuration
├── .luacheckrc                     # Lua static analysis config
├── .vintrc.yml                     # Vim script static analysis config
├── .projections.json               # Projection config
├── CONTRIBUTING.md
├── README.md
└── LICENSE.md
```

## Core Modules

### `match-up` (Lua entry point)

Minimal Lua entry point. `M.setup(opts)` flattens the config table into `vim.g.matchup_*` global variables.

```lua
require('match-up').setup {
  matchparen = { enabled = true, ... },
  motion = { enabled = true, ... },
  text_obj = { enabled = true, ... },
  delim = { ... },
  ...
}
```

When `sync = true` is passed, it loads the plugin immediately (via `runtime! plugin/matchup.vim`) and validates option names, erroring on unknown options.

### `autoload/matchup.vim` (Vim initialization)

`matchup#init()` is the initialization entry point:
1. `s:init_options()` — Initialize all `g:matchup_*` global variables
2. `s:init_modules()` — Load each feature module
3. `s:init_default_mappings()` — Set up default key mappings

### `autoload/matchup/delim.vim` (Core matching algorithm)

Core delimiter matching engine. Provides:
- `matchup#delim#get_next(type, side)` — Get next match
- `matchup#delim#get_prev(type, side)` — Get previous match
- `matchup#delim#get_current(type, side)` — Get current match
- `matchup#delim#get_surrounding(type, count, opts)` — Get surrounding matches
- `matchup#delim#get_matching(delim, ...)` — Get all matches for a delimiter

Supports multiple engines (configured via `b:matchup_active_engines`):
- `matchit` — Traditional regex-based engine
- `treesitter` — Tree-sitter engine

### `autoload/matchup/motion.vim` (Motion commands)

Implements enhanced `%` motions:
- `%` — Jump to next match
- `g%` — Reverse jump
- `]%` — Jump to next open match
- `[%` — Jump to previous open match
- `z%` — Jump inside current block
- `Z%` — Jump to previous inside block (opposite of z%)

### `autoload/matchup/text_obj.vim` (Text objects)

Provides text objects:
- `a%` — An any-block (or open-to-close block with count)
- `i%` — Inside an any-block (or open-to-close block with count)

Supports line-wise operator combinations for `d` and `y` operators (configurable via `g:matchup_text_obj_linewise_operators`).

### `autoload/matchup/matchparen.vim` (Paren highlighting)

Replaces the built-in `matchparen` plugin, providing:
- Current matching bracket highlighting
- Off-screen match info display
- Deferred show/hide (configurable)
- Background highlight mode
- Surrounding highlight (`<plug>(matchup-hi-surround)`)

### `autoload/matchup/transmute.vim` (Transmute module)

Experimental module for transposing matching pairs. Disabled by default (`g:matchup_transmute_enabled = 0`). Currently supports LaTeX delimiter changes.

### `autoload/matchup/surround.vim` (Surround operations)

Provides vim-surround-style operations:
- `ds%` — Delete surrounding matching words
- `cs%` — Change surrounding matching words

Requires `g:matchup_surround_enabled = 1`.

### `autoload/matchup/where.vim` (Where am I)

Provides `:MatchupWhereAmI` command to show breadcrumb-style position context by finding successive matching words.

### `autoload/matchup/custom.vim` (Custom motions)

API for defining custom motions:
- `matchup#custom#define_motion(modes, keys, fcn, opts)` — Define a custom motion
- `matchup#custom#suggest_pos(delim, opts)` — Get preferred cursor location

### `treesitter-matchup` (Tree-sitter engine)

Registers a `matchup` module via nvim-treesitter's `define_modules`.

`internal.lua` implements:
- `is_enabled(bufnr)` — Check if Tree-sitter matching is enabled
- `is_hl_enabled(bufnr)` — Check if highlighting is enabled
- `get_matches(bufnr)` — Get matching pairs (with LRU cache, 150 entries)
- `get_delim(bufnr, opts)` — Get delimiter at position
- `get_matching(delim, down, bufnr)` — Get matching delimiters

Uses `third-party/query.lua` to execute Tree-sitter queries. Query definitions are in `after/queries/*/matchup.scm`.

### `treesitter-matchup/compat.lua`

Compatibility layer that wraps different versions of the nvim-treesitter API.

### `autoload/matchup/ts_engine.vim` (Tree-sitter engine bridge)

Vim script bridge to the Lua Tree-sitter engine. Provides:
- `matchup#ts_engine#is_enabled(bufnr)` — Check if Tree-sitter is enabled
- `matchup#ts_engine#is_hl_enabled(bufnr)` — Check if highlighting is enabled
- `matchup#ts_engine#get_delim(opts)` — Get delimiter from Tree-sitter

## Configuration

Configuration is done through `vim.g.matchup_*` global variables (traditional Vim way) or via the Lua `setup()` function:

```lua
-- Lua way
require('match-up').setup {
  matchparen = {
    enabled = true,
    offscreen = { method = 'status' },
    deferred = true,
    deferred_show_delay = 50,
    deferred_hide_delay = 700,
  },
  motion = { enabled = true },
  text_obj = { enabled = true },
  delim = {
    count_fail = 0,
    count_max = 8,
  },
}

-- Vim way
let g:matchup_matchparen_enabled = 1
let g:matchup_matchparen_offscreen = {'method': 'status'}
let g:matchup_motion_enabled = 1
```

### Main Global Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `g:matchup_enabled` | 1 | Master switch |
| `g:matchup_matchparen_enabled` | 1 | Matching paren highlighting |
| `g:matchup_matchparen_offscreen` | `{method: 'status'}` | Off-screen display method |
| `g:matchup_matchparen_deferred` | 0 | Deferred highlighting |
| `g:matchup_matchparen_stopline` | 400 | Stop search line count |
| `g:matchup_matchparen_singleton` | 0 | Highlight words without matches |
| `g:matchup_matchparen_timeout` | 300 | Highlighting timeout (ms) |
| `g:matchup_matchparen_insert_timeout` | 60 | Insert mode timeout (ms) |
| `g:matchup_matchparen_hi_surround_always` | 0 | Always highlight surrounding |
| `g:matchup_matchparen_hi_background` | 0 | Background highlight mode |
| `g:matchup_motion_enabled` | 1 | Motion commands |
| `g:matchup_motion_override_Npercent` | 6 | Override N% threshold |
| `g:matchup_motion_cursor_end` | 1 | Cursor lands on end of words |
| `g:matchup_motion_keepjumps` | 0 | Keep jumplist |
| `g:matchup_text_obj_enabled` | 1 | Text objects |
| `g:matchup_text_obj_linewise_operators` | `['d', 'y']` | Line-wise operators |
| `g:matchup_delim_count_fail` | 0 | Match fail count |
| `g:matchup_delim_count_max` | 8 | Max match count |
| `g:matchup_delim_stopline` | 1500 | Search stopline |
| `g:matchup_delim_noskips` | 0 | Skip comments/strings |
| `g:matchup_delim_nomids` | 0 | Disable mid words |
| `g:matchup_delim_start_plaintext` | 1 | Start in plaintext mode |
| `g:matchup_transmute_enabled` | 0 | Transmute module (experimental) |
| `g:matchup_mouse_enabled` | 1 | Mouse support |
| `g:matchup_surround_enabled` | 0 | Surround operations |
| `g:matchup_where_enabled` | 1 | Where am I command |
| `g:matchup_override_vimtex` | 0 | Override vimtex matching |
| `g:matchup_mappings_enabled` | 1 | Enable default mappings |

### User Commands

| Command | Description |
|---------|-------------|
| `:NoMatchParen` | Disable match highlighting |
| `:DoMatchParen` | Enable match highlighting |
| `:MatchupWhereAmI` | Show current match context (breadcrumb) |
| `:MatchupReload` | Reload the plugin (for debugging) |
| `:MatchupShowTimes` | Show performance timing info |
| `:MatchupClearTimes` | Clear performance timing data |

### Default Key Mappings

| Mapping | Mode | Description |
|---------|------|-------------|
| `%` | n, x, o | Jump to next match |
| `g%` | n, x, o | Reverse jump |
| `]%` | n, x, o | Next open match |
| `[%` | n, x, o | Previous open match |
| `z%` | n, x, o | Jump inside block |
| `Z%` | n, x, o | Jump to previous inside block |
| `a%` | x, o | Select an any-block (text object) |
| `i%` | x, o | Select inside any-block (text object) |
| `ds%` | n | Delete surrounding (requires surround_enabled) |
| `cs%` | n | Change surrounding (requires surround_enabled) |
| `<C-g>%` | i | Insert mode motion |
| `<2-LeftMouse>` | n | Double-click to jump |

## Dependencies

### Runtime Dependencies

No hard dependencies. Optional:
- `nvim-treesitter` — Enables Tree-sitter engine (recommended)

### Dependents

- Used by many Neovim configs as `%` navigation enhancement
- Can replace built-in `matchit` and `matchparen`

## Build / Test

```bash
# Run new test suite
cd test/new && make -j1

# Run specific test directories
cd test/new && make test-core test-delim test-loader test-syn test-where

# Vader tests (legacy)
vim -Nu test/minvimrc -c 'Vader! test/issues/*.vader'
```

CI uses GitLab CI (`.gitlab-ci.yml`) with tests against Vim 7.4, 8.0, latest, and Neovim (including Tree-sitter).

## Coding Conventions

- **Languages**: Vim script (primary) + Lua (Tree-sitter integration)
- **Code style**: Vim script uses `cpo` save/restore pattern; function naming: `s:` for script-local, `matchup#` for global
- **Naming**: Global variables `g:matchup_*`; commands `Matchup*` / `NoMatchParen` / `DoMatchParen`; functions `matchup#*`
- **Compatibility**: Supports Vim 7.4+ and Neovim 0.1.7+; feature detection via `has()`
- **Lazy loading**: `loader.vim` implements on-demand module loading
- **Tree-sitter**: Query files use `.scm` format, placed under `after/queries/` by language
- **Third-party code**: `third-party/` directory contains modified nvim-treesitter components (query, lru, utils, hl-info, reload) with separate LICENSE files
- **File type config**: `after/ftplugin/*_matchup.vim` provides additional match pairs for specific languages
- **Folding**: Vim script files use marker-based folding (`{{{1`, `}}}1`)
- **Indentation**: shiftwidth=2, no tabs
- **Line length**: Max 74 columns for Vim script
- **Strings**: Prefer single-quoted strings
