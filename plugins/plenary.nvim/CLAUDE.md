# CLAUDE.md - plenary.nvim

This file provides guidance to Claude Code for working with the plenary.nvim codebase.

## Project Overview

plenary.nvim is a Lua utility library for Neovim — "all the lua functions I don't want to write twice." It provides a comprehensive set of modules for async programming, job control, path manipulation, file scanning, testing, and more. It is a foundational dependency for many Neovim plugins (telescope.nvim, neogit, octo.nvim,neo-tree.nvim, vgit.nvim, etc.).

**Note**: This library is useless outside of Neovim since it requires Neovim functions. It should be usable with any recent version of Neovim.

## Directory Structure

```
plenary.nvim/
+-- lua/
|   +-- plenary/
|   |   +-- init.lua                    -- Lazy-loading entry point (metatable __index)
|   |   +-- async/                       -- Async programming (coroutines + libuv)
|   |   |   +-- init.lua                -- Lazy-loaded async module
|   |   |   +-- async.lua               -- Core async: wrap(), run(), void(), etc.
|   |   |   +-- api.lua                 -- Neovim API wrappers (async nvim_*)
|   |   |   +-- control.lua             -- Condvar, Semaphore, channels
|   |   |   +-- structs.lua             -- Deque (double-ended queue)
|   |   |   +-- util.lua                -- scheduler(), sleep(), block_on(), race(), etc.
|   |   |   +-- uv_async.lua            -- libuv async wrappers (vim.loop)
|   |   |   +-- lsp.lua                 -- LSP async helpers (buf_request, buf_request_all)
|   |   |   +-- tests.lua               -- async test utilities (a.describe, a.it, etc.)
|   |   +-- async_lib/                  -- Legacy async library (deprecated, kept for compat)
|   |   +-- busted.lua                  -- Bundled busted test framework implementation
|   |   +-- job.lua                     -- Job/process management
|   |   +-- path.lua                    -- Path manipulation (object-oriented, immutable)
|   |   +-- scandir.lua                 -- Synchronous/async directory scanning
|   |   +-- context_manager.lua         -- Python-style context managers
|   |   +-- test_harness.lua            -- Test runner (PlenaryBustedDirectory / PlenaryBustedFile)
|   |   +-- filetype.lua                -- Filetype detection
|   |   +-- strings.lua                 -- String utilities
|   |   +-- tbl.lua                     -- Table utilities
|   |   +-- fun.lua                     -- Functional programming utilities (map, filter, etc.)
|   |   +-- functional.lua              -- Functional helpers (first, second, etc.)
|   |   +-- iterators.lua               -- Iterator utilities
|   |   +-- bit.lua                     -- Bitwise operations
|   |   +-- operators.lua               -- Comparison operators
|   |   +-- enum.lua                    -- Enum implementation (make_enum)
|   |   +-- class.lua                   -- OOP class system
|   |   +-- log.lua                     -- Logging (DEBUG_PLENARY env var)
|   |   +-- json.lua                    -- JSON encoding/decoding (json_strip_comments)
|   |   +-- curl.lua                    -- HTTP requests via curl
|   |   +-- reload.lua                  -- Module hot-reload (reload_module)
|   |   +-- run.lua                     -- Script runner (with_displayed_output)
|   |   +-- errors.lua                  -- Error handling utilities (traceback_error, info_error)
|   |   +-- debug_utils.lua             -- Debug utilities
|   |   +-- nvim_meta.lua               -- Neovim metadata (is_headless, LuaJIT version)
|   |   +-- vararg/                     -- Vararg utilities
|   |   |   +-- init.lua                -- Lazy-loaded vararg module
|   |   |   +-- rotate.lua              -- rotate(), arg_rotate()
|   |   +-- collections/                -- Pure Lua collection implementations
|   |   |   +-- py_list.lua             -- Python-style List class
|   |   +-- window/                     -- Window management
|   |   |   +-- init.lua                -- Window class (try_close, close_related_win)
|   |   |   +-- border.lua              -- Border drawing for floating windows
|   |   |   +-- float.lua               -- Floating window helpers
|   |   +-- popup/                      -- Vim popup API compatibility
|   |   |   +-- init.lua                -- popup_create, popup_hide, etc.
|   |   |   +-- utils.lua               -- Popup utilities
|   |   +-- profile.lua                 -- Top-level profile module (wraps profile/ directory)
|   |   +-- profile/                    -- Profiling
|   |   |   +-- init.lua
|   |   |   +-- lua_profiler.lua
|   |   |   +-- memory_profiler.lua
|   |   |   +-- p.lua
|   |   +-- lsp/                        -- LSP utilities
|   |   |   +-- override.lua            -- LSP handler overrides
|   |   +-- benchmark/                  -- Benchmarking
|   |   |   +-- init.lua
|   |   |   +-- stat.lua                -- Statistical functions (mean, median, std_dev, etc.)
|   |   +-- _meta/                      -- Metatype definitions
|   |       +-- _luassert.lua
|   +-- luassert/                       -- Assertion library (standalone)
|   |   +-- init.lua
|   |   +-- assert.lua
|   |   +-- assertions.lua
|   |   +-- compatibility.lua
|   |   +-- match.lua
|   |   +-- modifiers.lua
|   |   +-- namespaces.lua
|   |   +-- state.lua
|   |   +-- util.lua
|   |   +-- spy.lua
|   |   +-- stub.lua
|   |   +-- mock.lua
|   |   +-- array.lua
|   |   +-- matchers/                   -- Composite and core matchers
|   |   |   +-- init.lua
|   |   |   +-- core.lua
|   |   |   +-- composite.lua
|   |   +-- formatters/                 -- Binary string formatter, etc.
|   |   |   +-- init.lua
|   |   |   +-- binarystring.lua
|   |   +-- languages/
|   |       +-- en.lua                  -- English language for BDD assertions
|   +-- say.lua                         -- BDD-style test DSL (standalone)
+-- plugin/plenary.vim                   -- Plugin entry (minimal)
+-- tests/
|   +-- minimal_init.vim                -- Minimal vimrc for headless testing
|   +-- manual/                         -- Manual test scripts
|   +-- plenary/                        -- Test files mirror lua structure
+-- scripts/                            -- Build/test scripts
|   +-- minimal.vim                     -- Minimal vimrc for testing
|   +-- update_filetypes_from_github.lua
|   +-- generate_luassert_types.lua
|   +-- update_vararg.py
|   +-- vararg/
+-- data/                               -- Data files (filetype mappings)
+-- doc/                                -- Vim help docs
+-- TESTS_README.md                     -- Testing documentation
+-- POPUP.md                            -- Popup API documentation
+-- README.md
+-- Makefile
+-- plenary.nvim-scm-1.rockspec
+-- rockspec.template
+-- .stylua.toml
+-- .luacheckrc
```

## Core Modules

### `lua/plenary/init.lua` - Lazy-Loading Entry Point

Uses metatable `__index` to lazily require submodules. `require("plenary").job` will lazily load `plenary.job`. This means `require("plenary.path")` does NOT trigger loading of all submodules.

### `lua/plenary/async/` - Async Programming

Built on native Lua coroutines and `libuv`. Provides cooperative concurrency and cancellation. Access via `require("plenary.async")` which lazily loads submodules by indexing (`async.uv`, `async.util`, `async.api`, `async.control`, `async.lsp`, `async.tests`).

**Key functions** (from `async.lua`):
- `async.wrap(func, argc)` — converts a callback-style function into an async (coroutine-based) function. The callback must be the last argument of `func`.
- `async.run(async_fn, callback)` — runs an async function, optionally calling `callback` when done.
- `async.void(func)` — wraps a function so it runs in an async context but cannot return values (non-blocking).

**`api.lua`**: Wraps all `vim.api.nvim_*` functions to be async-aware. Automatically calls `scheduler()` when invoked inside a fast event (`vim.in_fast_event()`).

**`control.lua`**: Concurrency primitives:
- `Condvar` — `wait()` (blocks until notified), `notify_all()`, `notify_one()`.
- `Semaphore.new(initial_permits)` — `acquire()` (async), `release()`.
- `channel.oneshot()` — single-value channel; returns `(tx, rx)`.
- `channel.counter()` — notification-only channel (no value payload).
- `channel.mpsc()` — multiple-producer, single-consumer channel; returns `(sender, receiver)` with `:send()` and `:recv()`.

**`structs.lua`**: `Deque` (double-ended queue) with `pushleft`, `pushright`, `popleft`, `popright`, `is_empty`.

**`util.lua`**: Utility functions for async workflows:
- `async.util.sleep(ms)` — async sleep.
- `async.util.block_on(async_fn, timeout)` — blocks Neovim until the async function completes (use sparingly).
- `async.util.will_block(async_fn, timeout)` — wraps an async function so it blocks when called.
- `async.util.join(async_fns)` — runs multiple async functions concurrently.
- `async.util.run_first(async_fns)` — returns when the first async function completes.
- `async.util.race(async_fns)` — alias for `run_first`.
- `async.util.run_all(async_fns, callback)` — runs all and invokes callback.
- `async.util.apcall(async_fn, ...)` — async pcall (protected call).
- `async.util.protected(async_fn)` — wraps an async function so errors are caught.
- `async.util.scheduler()` — yields to the libuv scheduler (required inside fast events).

**`uv_async.lua`**: Wraps `vim.loop` (libuv) functions to be async. Includes filesystem (`fs_open`, `fs_read`, `fs_write`, `fs_stat`, etc.), network (`tcp_connect`, `udp_send`, etc.), timer, signal, and process functions.

**`lsp.lua`**: Async LSP request helpers. Wraps `vim.lsp.buf_request` (deprecated, use `buf_request_all`) and `vim.lsp.buf_request_all`.

**`tests.lua`**: Async-aware BDD test primitives. Use via `async.tests.add_globals()` to inject `a.describe`, `a.it`, `a.pending`, `a.before_each`, `a.after_each` into the global environment. These wrap the busted primitives in `will_block()` so async test bodies work correctly.

### `lua/plenary/busted.lua` - Bundled Busted Test Framework

A dependency-free bundled implementation of the busted test framework. Defines global `describe`, `it`, `pending`, `before_each`, `after_each`, `clear`. Replaces `assert` with `luassert`. Runs test files in separate Neovim instances via `test_harness.lua`.

### `lua/plenary/job.lua` - Job/Process Management

**`Job` class** (object-oriented):

| Method | Purpose |
|---|---|
| `Job:new(o)` | Creates a new job with command, args, cwd, env, callbacks. |
| `Job:start()` | Starts the job. |
| `Job:sync(timeout, wait_interval)` | Runs job synchronously, returns result. |
| `Job:result()` | Returns stdout lines. |
| `Job:stderr_result()` | Returns stderr lines. |
| `Job:pid()` | Returns process ID. |
| `Job:wait(timeout, wait_interval, should_redraw)` | Waits for job to finish. |
| `Job:co_wait(wait_time)` | Coroutine-based wait. |
| `Job:send(data)` | Writes data to the job's stdin. |
| `Job:and_then(next_job)` | Chains jobs (runs next after this completes). |
| `Job:and_then_on_success(next_job)` | Chains on success (exit code 0). |
| `Job:and_then_on_failure(next_job)` | Chains on failure (non-zero exit). |
| `Job:after(fn)` | Runs callback after job finishes (any exit code). |
| `Job:after_success(fn)` | Runs callback after successful exit. |
| `Job:after_failure(fn)` | Runs callback after failed exit. |
| `Job.chain(...)` | Chains multiple jobs sequentially. |
| `Job.join(...)` | Runs multiple jobs in parallel, waits for all. |
| `Job.is_job(item)` | Checks if `item` is a `Job` instance. |
| `Job:add_on_exit_callback(cb)` | Adds an on_exit callback after job creation. |

**Job options**: `command`, `args`, `cwd`, `env`, `interactive`, `detached`, `skip_validation`, `enable_handlers`, `enabled_recording`, `on_start`, `on_stdout`, `on_stderr`, `on_exit`, `writer`, `maximum_results`.

### `lua/plenary/path.lua` - Path Manipulation

**`Path` class** (object-oriented, immutable). All methods return new `Path` objects rather than mutating.

| Method | Purpose |
|---|---|
| `Path:new(...)` | Creates a new path. Accepts strings or other Path objects. |
| `Path:joinpath(...)` | Joins path components. |
| `Path:absolute()` | Returns absolute path. |
| `Path:exists()` | Checks if path exists. |
| `Path:expand()` | Expands `~` and environment variables. |
| `Path:make_relative(cwd)` | Makes path relative to `cwd`. |
| `Path:normalize(cwd)` | Normalizes path (resolves `.` and `..`). |
| `Path:shorten(len, exclude)` | Shortens path components. |
| `Path:mkdir(opts)` | Creates directory (`parents`, `mode`, `exists_ok`). |
| `Path:rmdir()` | Removes directory. |
| `Path:rename(opts)` | Renames path (`opts.new_name`). |
| `Path:copy(opts)` | Copies path (`opts.destination`). |
| `Path:touch(opts)` | Creates file / updates timestamp. |
| `Path:rm(opts)` | Removes file. |
| `Path:is_dir()` | Checks if path is a directory. |
| `Path:is_file()` | Checks if path is a file. |
| `Path:is_absolute()` | Checks if path is absolute. |
| `Path:parent()` | Returns parent path. |
| `Path:parents()` | Returns all ancestor paths (iterator). |
| `Path:open()` | Opens file handle (internal). |
| `Path:read(callback)` | Reads file contents (sync or async via callback). |
| `Path:head(lines)` | Reads first N lines. |
| `Path:tail(lines)` | Reads last N lines. |
| `Path:readlines()` | Reads all lines into a table. |
| `Path:iter()` | Iterates over lines in the file. |
| `Path:write(txt, flag, mode)` | Writes to file (`flag` is `"w"` or `"a"`). |
| `Path:readbyterange(offset, length)` | Reads a byte range from the file. |
| `Path:find_upwards(filename)` | Walks up the directory tree looking for `filename`. |

### `lua/plenary/scandir.lua` - Directory Scanning

| Function | Purpose |
|---|---|
| `scan_dir(path, opts)` | Synchronous recursive directory scan. |
| `scan_dir_async(path, opts)` | Async recursive directory scan. |
| `ls(path, opts)` | Returns a formatted `ls -la`-style string (sync). |
| `ls_async(path, opts)` | Async version of `ls`. |

**Options**: `hidden`, `add_dirs`, `respect_gitignore`, `depth`, `search_pattern`, `on_insert(file, typ)`, `on_exit(results)` (async only).

### `lua/plenary/context_manager.lua` - Context Managers

Python-style context managers using coroutines or enter/exit objects.

| Function | Purpose |
|---|---|
| `context_manager.with(obj, callable)` | Executes `callable` within the context. If `obj` is a function/coroutine, it is treated as a coroutine context manager. If it is a table, it must implement `enter()` and `exit()`. |
| `context_manager.open(filename, mode)` | Opens a file, yields the handle to `with`, and closes it afterward. |

### `lua/plenary/test_harness.lua` - Test Runner

| Function | Purpose |
|---|---|
| `harness.test_directory_command(command)` | Parses a vim command string like `PlenaryBustedDirectory tests/plenary/ {opts}` and runs the tests. |
| `harness.test_directory(paths_or_dir, opts)` | Runs bundled tests across one or more paths or directories. |

**Vim commands**:
- `:PlenaryBustedFile <file>` — runs a single test file in a floating window (or headless).
- `:PlenaryBustedDirectory <dir> {opts}` — runs all `*_spec.lua` files in a directory.

**Options**: `nvim_cmd` (default `vim.v.progpath`), `init`, `minimal_init`, `sequential` (default false), `keep_going` (default true), `timeout` (default 50000 ms), `winopts`.

### `lua/plenary/filetype.lua` - Filetype Detection

| Function | Purpose |
|---|---|
| `filetype.add_table(new_filetypes)` | Adds filetype mappings (table with `extension`, `file_name`, `shebang` keys). |
| `filetype.add_file(filename)` | Adds file->filetype mapping from a Lua file in `data/plenary/filetypes/`. |
| `filetype.detect(filepath, opts)` | Detects filetype from extension, name, modeline, or shebang (exits on first match). |
| `filetype.detect_from_extension(filepath)` | Detects from extension. |
| `filetype.detect_from_name(filepath)` | Detects from exact filename. |
| `filetype.detect_from_modeline(filepath)` | Detects from the modeline in the first/last lines. |
| `filetype.detect_from_shebang(filepath)` | Detects from the shebang (`#!`) line. |

### `lua/plenary/enum.lua` - Enum Implementation

Provides `make_enum(tbl)` which converts a list of strings into an enum type. Each member is a variant with comparison (`__lt`, `__gt`, `__eq`) and `__tostring`. Supports `Enum:has_key(key)`, `Enum:from_str(key)`, `Enum:from_num(num)`.

### `lua/plenary/curl.lua` - HTTP Requests via curl

Thin wrapper around the `curl` CLI. Provides functions for common HTTP operations (GET, POST, etc.) with header/data parsing utilities.

### `lua/plenary/json.lua` - JSON Utilities

Provides `json.json_strip_comments(json_string, options)` to strip C-style `//` and `/* */` comments from JSON strings before parsing. Useful for JSONC (JSON with comments).

### `lua/plenary/reload.lua` - Module Hot-Reload

| Function | Purpose |
|---|---|
| `reload.reload_module(module_name, starts_with_only)` | Unloads and re-loads a module (or modules matching a prefix). |

### `lua/plenary/run.lua` - Script Runner

| Function | Purpose |
|---|---|
| `run.with_displayed_output(title_text, cmd, opts)` | Runs a command and displays its output in a floating window. |

### `lua/plenary/errors.lua` - Error Utilities

| Function | Purpose |
|---|---|
| `errors.traceback_error(msg, level)` | Raises an error with a debug traceback appended. |
| `errors.info_error(msg, func_info, level)` | Raises an error with function info (from `debug.getinfo`) appended. |

### `lua/plenary/nvim_meta.lua` - Neovim Metadata

| Field | Purpose |
|---|---|
| `nvim_meta.is_headless` | `true` when Neovim is running with `--headless` (no UI attached). |
| `nvim_meta.lua_jit` | Table with `lua` (version string), `jit` (boolean), and `version` (LuaJIT version). |

### `lua/plenary/log.lua` - Logging

Inspired by `rxi/log.lua`. Controlled by the `DEBUG_PLENARY` environment variable. Supports logging to console (`use_console`: `"sync"`, `"async"`, or `false`), to a file (`use_file`), and to the quickfix list (`use_quickfix`). Default output file is `stdpath("cache")/plenary.log`.

### `lua/plenary/profile/` - Profiling (wrapped by `profile.lua`)

`plenary.profile` is a thin wrapper around LuaJIT's `jit.p` profiler.

| Function | Purpose |
|---|---|
| `profile.start(out, opts)` | Starts profiling. `opts.flame = true` produces flamegraph-compatible output. |
| `profile.stop()` | Stops profiling. |
| `profile.benchmark(iterations, f, ...)` | Runs `f` for `iterations` iterations and returns elapsed time in seconds. |

### `lua/plenary/popup/` - Popup API

Vim-compatible popup API for Neovim. Provides `popup_create`, `popup_hide`, `popup_show`, `popup_move`, `popup_settext`, etc. Implemented on top of `vim.api.nvim_open_win`. See `POPUP.md` for full documentation.

### `lua/plenary/window/` - Window Management

- `plenary.window` — `try_close(win_id, force)`, `close_related_win(parent_win_id, child_win_id)`.
- `plenary.window.border` — `Border` class for drawing borders around floating windows (supports titles and custom thickness).
- `plenary.window.float` — `default_opts(options)` for creating centered floating windows, `percentage_range_window`, `centered_percentage_window`, `centered_with_top_win`, etc. Provides `default_options` with `winblend = 15`, `percentage = 0.9`.

### `lua/plenary/lsp/override.lua` - LSP Handler Overrides

| Function | Purpose |
|---|---|
| `override.override(method, new_function)` | Replaces an LSP handler callback (e.g., `"textDocument/publishDiagnostics"`). |
| `override.get_original_function(method)` | Returns the original (pre-override) handler, useful for wrapping. |

### `lua/plenary/benchmark/` - Benchmarking

Benchmarking framework for measuring function execution time. Produces formatted output with mean, standard deviation, median, min/max, and auto-scaled time units (ns/μs/ms).

### `lua/plenary/collections/py_list.lua` - Python-List Collection

A pure-Lua implementation of a Python-style list with methods like `iter()`, `append`, `insert`, `remove`, `pop`, `__len`, `__eq`, etc. Can be constructed with `List { 1, 2, 3 }`.

### `lua/plenary/async_lib/` - Legacy Async Library (Deprecated)

Version 1 of the async library. Kept for backward compatibility. Users should migrate to `plenary.async`.

### `lua/luassert/` - Assertion Library

Standalone assertion library (can be used independently of plenary.nvim). Provides:
- `assert`, `spy`, `stub`, `mock`
- `match` for matching patterns
- Modifiers: `modifiers` (e.g., `not_`, `is_not`)
- Namespaces: `namespaces` for managing assertion state
- Matchers: `matchers.core` (e.g., `keys`, `callable`), `matchers.composite` (e.g., `all_of`, `any_of`, `matches_any_of`)
- Formatters: `formatters.binarystring` for formatting binary strings in error messages
- Languages: `languages.en` for English text in BDD assertions
- State: `state` for tracking current test assertions

### `lua/say.lua` - BDD Test DSL

BDD-style test language for use with busted. Provides translated assertion phrases used by `luassert.languages.en`.

## Configuration

plenary.nvim is a library, not a plugin with user-facing configuration. Most modules are used directly:

```lua
local Job = require("plenary.job")
local Path = require("plenary.path")
local async = require("plenary.async")
```

## Dependencies

- **Required**: Neovim (uses `vim.*` API extensively)
- **Optional**: `curl` CLI (for `plenary.curl`), LuaJIT (for `plenary.profile`)

## Building / Testing

**Makefile targets**:
| Target | Description |
|---|---|
| `test` | Runs `PlenaryBustedDirectory tests/plenary/` with minimal vimrc (sequential). |
| `generate_filetypes` | Updates filetype data from GitHub. |
| `generate_luassert_types` | Generates luassert type annotations. |
| `lint` | Runs `luacheck lua/plenary`. |

**Running tests**:
```bash
make test
```

Or manually:
```bash
nvim --headless --noplugin -u scripts/minimal.vim -c "PlenaryBustedDirectory tests/plenary/ {minimal_init = 'tests/minimal_init.vim', sequential = true}"
```

You can also run a single test file with:
```vim
:PlenaryBustedFile %
```

## Code Style / Conventions

- **Stylua** config (`.stylua.toml`): `column_width=120`, 2-space indent, Unix LF, `AutoPreferDouble` quotes, no call parens.
- **Luacheck** for linting (`.luacheckrc`).
- Module pattern: most files return a local `M = {}` table. Class-style modules (e.g., `Path`, `Job`, `Border`) define a metatable and `__index`.
- Heavy use of LuaCATS type annotations (`@class`, `@field`, `@param`, `@return`).
- Object-oriented patterns using metatables (`Path`, `Job`, `Window`, `Border`, `Deque`, `Semaphore`, etc.).
- Functional programming patterns in `fun.lua`, `functional.lua`, `iterators.lua`.
- Async functions are created via `async.wrap(func, argc)` and must be run via `async.run()`.

## Key Patterns

- **Lazy loading**: `plenary/init.lua` uses metatable `__index` to lazily require submodules.
- **Async wrapping**: `async.wrap(func, argc)` converts callback-style functions to coroutine-based async functions. The callback must be the last argument.
- **Job chaining**: `Job:and_then()`, `Job.chain()`, `Job.join()` for composing jobs sequentially or in parallel.
- **Path immutability**: `Path` methods return new `Path` objects rather than mutating the original.
- **Context managers**: Python-style `with` blocks using coroutines or enter/exit objects.
- **Test harness**: `PlenaryBustedFile` and `PlenaryBustedDirectory` commands for running busted-style tests. Test files use the `*_spec.lua` naming pattern.
- **Async tests**: Use `async.tests.add_globals()` to inject `a.describe`, `a.it`, etc. for writing tests with async bodies.
- **Concurrency**: `async.control.channel` (oneshot, counter, mpsc), `Condvar`, `Semaphore` for coroutine coordination.
