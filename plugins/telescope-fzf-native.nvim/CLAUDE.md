# telescope-fzf-native.nvim

## Project Overview

telescope-fzf-native.nvim is a C port of the [fzf](https://github.com/junegunn/fzf) fuzzy-finding algorithm, providing native high-performance fuzzy sorting for telescope.nvim. It implements fzf's scoring algorithm and position calculation but does not include fzf's interactive UI. The compiled C shared library is loaded via LuaJIT FFI.

Supports full fzf search syntax: fuzzy match (`sbtrkt`), exact match (`'wild`), prefix match (`^music`), suffix match (`.mp3$`), inverse match (`!fire`), and OR operator (`|`).

**Known limitations (not yet implemented):** Unicode support and `normalize` (always set to `false`, reserved for future use). See README "TODO" section.

## Directory Structure

```
telescope-fzf-native.nvim/
├── src/
│   ├── fzf.c            # C implementation of fzf algorithm (scoring, position calculation, pattern parsing)
│   └── fzf.h            # C header (type definitions, score constants, function declarations)
├── lua/
│   ├── fzf_lib.lua      # Lua FFI bindings: wraps the C library with a Lua-friendly interface
│   └── telescope/_extensions/
│       └── fzf.lua      # Telescope extension: registers the fzf sorter
├── CMakeLists.txt        # CMake build configuration
├── CMakePresets.json     # CMake presets (Ninja / Unix Makefiles)
├── Makefile              # Traditional make build
├── .github/workflows/
│   ├── ci.yml            # CI: build and test
│   └── lint.yml          # Lint: luacheck + clang-format
├── test/
│   ├── fzf_lib_spec.lua  # Lua-level tests (plenary.nvim busted)
│   ├── test.c            # C-level tests (requires examiner library)
│   └── minrc.vim         # Minimal nvim config for headless testing
├── build/                # Build output directory (*.so / *.dll), gitignored
├── .clang-format         # C formatting config (IndentWidth: 2, ColumnLimit: 80)
├── .stylua.toml          # Lua formatting config
└── .luacheckrc           # Lua static analysis config
```

## Core Modules

### `src/fzf.c` + `src/fzf.h` — fzf C Algorithm

#### Data structures

- `fzf_i16_t` / `fzf_i32_t` — slices of `int16_t` / `int32_t` with `data`, `size`, `cap`, `allocated`
- `fzf_position_t` — array of `uint32_t` match positions
- `fzf_result_t` — `{start, end, score}` result of a match
- `fzf_slab_t` — scratch memory with two arenas: `I16` (int16) and `I32` (int32)
- `fzf_string_t` — `{const char *data, size_t size}`
- `fzf_term_t` — single term: `{fn, inv, ptr, text, case_sensitive}`
- `fzf_term_set_t` — OR-combined set of terms
- `fzf_pattern_t` — AND-combined list of term sets; has `only_inv` flag (true when every term set has exactly one inverse term)

#### Score constants

```c
ScoreMatch = 16
ScoreGapStart = -3
ScoreGapExtention = -1
BonusBoundary = ScoreMatch / 2
BonusNonWord = ScoreMatch / 2
BonusCamel123 = BonusBoundary + ScoreGapExtention
BonusConsecutive = -(ScoreGapStart + ScoreGapExtention)
BonusFirstCharMultiplier = 2
```

#### Match algorithms

- `fzf_fuzzy_match_v1` — simpler O(N*M) fuzzy match
- `fzf_fuzzy_match_v2` — slab-based O(N*M) fuzzy match, used by default; falls back to v1 when slab is too small
- `fzf_exact_match_naive` — non-fuzzy exact match (used for `'quoted` and `!inverse` terms)
- `fzf_prefix_match` — `^prefix` match
- `fzf_suffix_match` — `suffix$` match
- `fzf_equal_match` — `^exact$` match (whole string must equal pattern)

#### Public API (for FFI)

- `fzf_make_default_slab()` / `fzf_make_slab(config)` / `fzf_free_slab()` — allocate/score slab memory
  - Default slab: `I16` size = `100 * 1024`, `I32` size = `2048`
- `fzf_parse_pattern(case_mode, normalize, pattern, fuzzy)` / `fzf_free_pattern()` — parse search pattern
  - `case_mode`: `CaseSmart (0)`, `CaseIgnore (1)`, `CaseRespect (2)`
  - Splits on spaces; supports `|` OR, `!` inverse, `'` exact, `^` prefix, `$` suffix, `\ ` escaped space
- `fzf_get_score(text, pattern, slab)` — compute match score (returns 0 for no match, 1 for empty pattern)
- `fzf_get_positions(text, pattern, slab)` / `fzf_free_positions()` — get match positions (returns NULL for no match)
- `fzf_pos_array(len)` — allocate a position array

### `lua/fzf_lib.lua` — FFI Bindings

Loads `build/libfzf.so` (or `build/libfzf.dll` on Windows), provides:

- `fzf.allocate_slab()` / `fzf.free_slab(s)`
- `fzf.parse_pattern(pattern, case_mode, fuzzy)` → pattern object
  - Defaults: `case_mode = 0` (smart_case), `fuzzy = true`
  - Always passes `normalize = false` to the C library
- `fzf.free_pattern(p)`
- `fzf.get_score(input, pattern, slab)` → number
- `fzf.get_pos(input, pattern, slab)` → number[] (Lua array, 1-indexed) or nil

Case modes: `0 = smart_case`, `1 = ignore_case`, `2 = respect_case`.

### `lua/telescope/_extensions/fzf.lua` — Telescope Extension

Registered as the `fzf` telescope extension:

- `setup(ext_config, config)` — configures whether to override default file/generic sorters
- `exports.native_fzf_sorter(opts)` — returns a native fzf sorter instance
- `exports.health()` — health check verifying the library works correctly

Sorter features:
- `prompt_cache` — caches parsed pattern objects per prompt
- `discard = true` — non-matching items are discarded entirely (score = -1)
- Handles `|` OR operator, `!` inverse match, `\` escape character
- `clear_filter_fun` — strips pre-filter prefix for highlight when `filter_function` is set

## User Configuration

Users configure via telescope, not directly:

```lua
require('telescope').setup {
  extensions = {
    fzf = {
      fuzzy = true,                    -- false enables exact matching only
      override_generic_sorter = true,  -- override the generic sorter
      override_file_sorter = true,     -- override the file sorter
      case_mode = "smart_case",        -- "smart_case" | "ignore_case" | "respect_case"
    },
  },
}
require('telescope').load_extension('fzf')
```

Developers can use the library directly:

```lua
local fzf = require('fzf_lib')
local slab = fzf.allocate_slab()
local pattern = fzf.parse_pattern("query", 0)
local score = fzf.get_score("some text", pattern, slab)
local pos = fzf.get_pos("some text", pattern, slab)
fzf.free_pattern(pattern)
fzf.free_slab(slab)
```

## Dependencies

- **Runtime:** LuaJIT FFI (bundled with Neovim), C compiler (gcc/clang) + CMake or make (for building)
- **Consumed by:** `telescope.nvim` (registered as an extension)
- **Dev tests:** `plenary.nvim` (Lua), `examiner` (C test library)

## Build / Test

### Build

- **CMake:** `cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build`
  - Produces `build/libfzf.so` (Unix) or `build/libfzf.dll` (Windows)
  - Uses C99 standard, `-Wall` (no `-Werror`)
- **Make:** `make`
  - Produces `build/libfzf.so` / `build/libfzf.dll`
  - Uses `-std=gnu99`, `-Wall -Werror -fpic -O3`

### Test / Lint

- `make ntest` — Lua tests (plenary.nvim busted, headless nvim)
- `make test` — C tests (compiles and runs `build/test`, requires LD_LIBRARY_PATH)
- `make lint` — `luacheck lua`
- `make format` — `clang-format --dry-run` check for C code
- `make clangdhappy` — generate `compile_commands.json`
- `make clean` — remove build artifacts

## Coding Standards

- **C code:** `.clang-format` config (GNU-like style, IndentWidth 2, ColumnLimit 80); warnings treated as errors only in Makefile build
- **Lua code:** `.stylua.toml` config; `luacheck` static analysis (`.luacheckrc`, ignores unused argument warning 212 and readonly global write 122)
- **Shared library** output to `build/` directory (gitignored)
