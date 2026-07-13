# nvim-colorizer.lua

## Overview

nvim-colorizer.lua is a **high-performance, zero-external-dependency** Neovim color highlighter written in LuaJIT. It highlights color codes in the editor viewport in real time and supports multiple color formats.

- **Supported formats:**
  - `#RGB` / `#RRGGBB` / `#RRGGBBAA` hex colors
  - CSS named colors (Blue, Gray, etc.)
  - CSS `rgb()` / `rgba()` / `hsl()` / `hsla()` functions
  - `css` / `css_fn` shorthands to enable groups of CSS features at once
  - Two display modes: `foreground` (text color) and `background` (background color)
- **Performance features:** FFI trie, FFI byte-category lookup table, FFI hex parser, regex caching, bitmask-keyed matcher cache

## Requirements / Dependencies

- **Neovim >= 0.4.0**
- `set termguicolors` — `setup()` prints an error and returns early without it
- `malloc()` / `free()` available on the system (Linux, macOS, Windows)
- **No external runtime dependencies** — only LuaJIT built-ins (`bit`, `ffi`) and `vim.api.*`

## Directory structure

```
nvim-colorizer.lua/
├── .github/                    # GitHub config (CI, sponsorship, etc.)
├── LICENSE
├── README.md
├── doc/
│   ├── colorizer-lua.txt       # Vim help document
│   ├── index.html              # Generated HTML docs
│   ├── ldoc.css                # Doc styles
│   └── modules/                # LDoc module docs (colorizer.html, nvim.html, trie.html)
├── lua/
│   ├── colorizer.lua           # Main module
│   └── colorizer/
│       ├── nvim.lua            # Neovim API wrapper
│       └── trie.lua            # FFI trie data structure
├── plugin/
│   └── colorizer.vim           # Vimscript entry point, defines commands
└── test/
    ├── expectation.txt         # Manual golden test file
    └── print-trie.lua          # Trie visualization tool
```

## Core modules

### `lua/colorizer.lua` — main module

Exported table:

| Export | Description |
|---|---|
| `DEFAULT_NAMESPACE` | Namespace id (`nvim.create_namespace "colorizer"`) |
| `setup` | Initialization entry point |
| `is_buffer_attached` | Check whether a buffer is attached |
| `attach_to_buffer` | Attach to a buffer and continuously highlight changes |
| `detach_from_buffer` | Detach from a buffer |
| `highlight_buffer` | Synchronously highlight a line range |
| `reload_all_buffers` | Re-attach all tracked buffers |
| `get_buffer_options` | Get a copy of the buffer's current options |

**Internal functions (local, not exported):**

- `initialize_trie()` — lazily builds `COLOR_MAP` and `COLOR_TRIE` from `nvim.get_color_map()`
- `byte_is_hex`, `byte_is_alphanumeric`, `parse_hex` — FFI byte-category helpers backed by the `BYTE_CATEGORY[256]` lookup table (low 4 bits = category, high 4 bits = hex value)
- `percent_or_hex`, `color_is_bright`, `hue_to_rgb`, `hsl_to_rgb` — color math
- `color_name_parser`, `rgb_hex_parser` — fast non-regex parsers
- `css_fn.rgb / rgba / hsl / hsla` — regex-based CSS function parsers
- `compile_matcher` — chains a list of parsers into a single fallback parser
- `make_matcher` — builds and caches a compiled parser closure keyed by a bitmask of enabled options
- `merge`, `rehighlight_buffer`, `new_buffer_options`
- `COLORIZER_SETUP_HOOK` — internal closure created inside `setup()` and invoked by the `FileType` autocmd

Highlight naming: highlights are named `colorizer_{mode_suffix}_{rgb}` where the suffix is `mb` (background) or `mf` (foreground), cached in `HIGHLIGHT_CACHE`. In background mode, `color_is_bright` picks Black or White as the foreground text color.

### `lua/colorizer/nvim.lua` — Neovim API wrapper

Metatable-wrapped object providing:

- `print`, `echo` — wrappers around `vim.inspect` / `nvim_out_write`
- `fn` — lazy `vim.api.nvim_call_function` dispatcher (cached on the metatable)
- `buf` — buffer shortcuts (`line`, `nr`)
- `ex` — lazy ex-command dispatcher (strips a trailing `_` → `!`, joins args with spaces)
- `g`, `v`, `b`, `w`, `o`, `bo`, `wo`, `env` — accessors for global / vvar / buffer / window / option / buffer-option / window-option / env vars (`__index` / `__newindex`)
- Fallback `__index` wraps `vim.api['nvim_'..k]`

### `lua/colorizer/trie.lua` — FFI trie

Hand-written LuaJIT FFI C-structure trie (`struct Trie { bool is_leaf; struct Trie* character[62]; }`) using `malloc`/`free`. Characters map to the 62-wide child array via `INDEX_LOOKUP_TABLE[256]` (0–9 → 0–9, A–Z → 10–35, a–z → 36–61, anything else → 255 = invalid). GC `__gc = trie_destroy` recursively frees children.

Metatype exports:

| Method | Description |
|---|---|
| `__new(t)` | Construct a trie, optionally bulk-extended from an init table |
| `insert(trie, value)` | Insert a value |
| `search(trie, value[, start])` | Exact-match search |
| `longest_prefix(trie, value[, start])` | Longest-prefix match |
| `extend(trie, t)` | Bulk insert from a table |
| `__tostring` | Tree visualization (used by `print-trie.lua`) |

## Configuration options

Configured via `require'colorizer'.setup(filetypes?, default_options?)`.

**Defaults (`DEFAULT_OPTIONS`):**

| Option | Default | Description |
|---|---|---|
| `RGB` | `true` | `#RGB` hex |
| `RRGGBB` | `true` | `#RRGGBB` hex |
| `names` | `true` | Named colors |
| `RRGGBBAA` | `false` | `#RRGGBBAA` hex |
| `rgb_fn` | `false` | CSS `rgb()` / `rgba()` |
| `hsl_fn` | `false` | CSS `hsl()` / `hsla()` |
| `css` | `false` | Enable all CSS features (rgb_fn, hsl_fn, names, RGB, RRGGBB) |
| `css_fn` | `false` | Enable CSS functions only (rgb_fn, hsl_fn) |
| `mode` | `'background'` | Display mode: `'foreground'` or `'background'` |

Filetype-specific overrides are passed as the first table argument, e.g. `html = { mode = 'foreground' }`. Prefix a filetype with `!` to exclude it (e.g. `!vim`); exclusions only take effect when `*` (highlight all) is also specified.

To disable named-color highlighting for a filetype, set `names = false` (the `no_names` key shown in old examples is not actually handled by the matcher).

## Commands

Defined in `plugin/colorizer.vim`:

- `:ColorizerAttachToBuffer` — attach to the current buffer (or reload its settings)
- `:ColorizerDetachFromBuffer` — stop highlighting the current buffer
- `:ColorizerReloadAllBuffers` — re-attach every highlighted buffer
- `:ColorizerToggle` — toggle highlighting on the current buffer

## Loading

The Vimscript file `plugin/colorizer.vim` defines the four commands above and is guarded by `g:loaded_colorizer`. Users must call `require'colorizer'.setup()`, which:

1. Requires `termguicolors` to be set
2. Defines the internal `COLORIZER_SETUP_HOOK` closure
3. Creates the `ColorizerSetup` augroup with a `FileType` autocmd for each configured filetype (or `FileType *` by default)

`attach_to_buffer` uses `nvim.buf_attach` with `on_lines` (incrementally re-highlight changed lines) and `on_detach` (clear the buffer's entry from `BUFFER_OPTIONS`).

## Build / Test

- **No automated test framework** (no busted, plenary, etc.)
- `test/expectation.txt` is a manual golden test file: after `attach_to_buffer(0, {css=true})` it contains `--[[ SUCCESS ... ]]` and `--[[ FAIL ... ]]` blocks for visual verification
- `test/print-trie.lua` is a standalone tool that dumps/visualizes trie structures (requires `trie` / `nvim` via a manipulated `package.path`)

## Coding conventions

- **Module names:** `colorizer`, `colorizer/nvim`, `colorizer/trie`
- **Global constants:** `UPPER_SNAKE_CASE` (`COLOR_MAP`, `COLOR_TRIE`, `DEFAULT_OPTIONS`, `SETUP_SETTINGS`, `BUFFER_OPTIONS`, `FILETYPE_OPTIONS`, `MATCHER_CACHE`, `HIGHLIGHT_CACHE`, etc.)
- **Local variables:** `lower_snake_case` (occasional `camelCase`, e.g. `COLOR_NAME_MINLEN`, `already_attached`)
- **Definition order:** helper functions are declared `local function` before use; mutual recursion relies on Lua's forward-reference rules
- **Export table:** `return { ... }` at the end of the file, documented with `--- @export` annotations
- **FFI conventions:** `struct Trie`, `Trie_t`, `Trie_ptr_t`, `Trie_size` type aliases; `INDEX_LOOKUP_TABLE`, `CHAR_LOOKUP_TABLE` character maps
- **Option hashing:** options are encoded into a bitmask integer (`bor` / `lshift`) used as the matcher cache key
- **Vim interop:** plugin file ends with the `let g:loaded_colorizer = 1` guard; uses `nvim.ex.augroup(...)` / `nvim.ex.autocmd(...)` ex-command helpers

## Known quirks

- The `css_fn` option is documented as enabling CSS functions, but `make_matcher` reads `options.css_fns` (plural). Since the defined option key is `css_fn` (singular), setting `css_fn = true` alone does **not** enable `rgb_fn`/`hsl_fn` — use `css = true`, `rgb_fn = true`, or `hsl_fn = true` instead.
- The code comment above `DEFAULT_NAMESPACE` says the name is `"terminal_highlight"`, but the actual namespace name passed to `create_namespace` is `"colorizer"`.
