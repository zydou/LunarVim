# none-ls.nvim

Community-maintained fork of the original **null-ls.nvim** (repo renamed for compatibility; all APIs unchanged). Its tagline:

> "Use Neovim as a language server to inject LSP diagnostics, code actions, and more via Lua."

It bridges a gap in Neovim's LSP ecosystem: non-LSP sources can hook into the built-in LSP client as if they were real language servers. It also reduces boilerplate for general-purpose servers and can avoid spawning external processes. Sources are Lua-defined and can wrap CLI tools (e.g., formatters/linters) into LSP-native features.

This plugin is loaded via Neovim's standard `lua/` path — there is no `plugin/` directory. The public entry point is `require("null-ls")`.

## Directory Structure

```
none-ls.nvim/
├── lua/null-ls/                  # Plugin source tree
│   ├── init.lua                  # Public API (M.setup, re-exports)
│   ├── config.lua                # Configuration defaults & validation
│   ├── sources.lua               # Source registration & discovery
│   ├── methods.lua               # LSP <-> internal method mappings
│   ├── client.lua                # In-memory LSP client lifecycle (attach/init/caps)
│   ├── formatting.lua            # textDocument/formatting & rangeFormatting handler
│   ├── diagnostics.lua           # Diagnostic parsing & production helpers
│   ├── code-actions.lua          # textDocument/codeAction handler
│   ├── completion.lua            # textDocument/completion handler
│   ├── hover.lua                 # textDocument/hover handler
│   ├── generators.lua            # Async generator runner (plenary.async + loop.spawn)
│   ├── rpc.lua                   # JSON-RPC request/response plumbing
│   ├── loop.lua                  # libuv-backed process spawn / timer / temp-file layer
│   ├── diff.lua                  # Minimal text-edit diff computation for formatting
│   ├── logger.lua                # Leveled logging facility (plenary.log)
│   ├── state.lua                 # Runtime state: conditional sources, action registry, cache
│   ├── health.lua                 # :checkhealth support
│   ├── info.lua                  # :NullLsInfo centered floating window
│   ├── utils/                    # Shared utilities
│   │   ├── init.lua
│   │   ├── make_params.lua       # Builds NullLsParams (lazy-resolving metatable)
│   │   └── test.lua
│   ├── helpers/                  # Source factory & output parsers
│   │   ├── init.lua              # Re-exports factory functions
│   │   ├── make_builtin.lua      # Core builtin factory function
│   │   ├── formatter_factory.lua # Formatter wrapper (single output -> { text })
│   │   ├── generator_factory.lua # Async CLI generator (libuv job spawner)
│   │   ├── cache.lua             # bufnr-keyed result caching
│   │   ├── command_resolver.lua  # prefer_local/only_local local-binary resolution
│   │   ├── diagnostics.lua       # Parses CLI output into diagnostics (pattern/JSON/efm)
│   │   ├── cspell.lua            # Internal helper for cspell config resolution
│   │   └── range_formatting_args_factory.lua
│   └── builtins/                 # Built-in sources (lazy-loaded via metatable)
│       ├── init.lua              # Lazy metatable index per method
│       ├── formatting/           # ~161 formatters (stylua.lua, black.lua, prettier, ...)
│       ├── diagnostics/          # ~115 linters (eslint, pylint, actionlint, ...)
│       ├── code_actions/         # 15 code-action providers
│       ├── completion/           # 4 completion providers
│       ├── hover/                # 2 hover providers
│       ├── _test/                # Internal test-only sources (first_formatter, ...)
│       └── _meta/                # Generated index (filetype_map.lua, per-method maps)
├── test/                         # Busted specs (plenary)
│   ├── spec/                     # units: client_spec, sources_spec, formatting_spec, ...
│   ├── minimal_init.lua          # Headless Neovim config for tests
│   ├── files/                    # Test fixtures
│   └── scripts/
├── doc/                          # Markdown docs (MAIN.md, BUILTINS.md, HELPERS.md, ...)
├── scripts/                      # autogen.sh + autogen.lua (generate _meta files)
├── Makefile                      # test, test-file, check, install-hooks, clean, autogen
├── .pre-commit-config.yaml       # stylua + prettier hooks
├── stylua.toml / selene.toml     # Stylua & Selene config
├── .github/workflows/            # build.yml (stylua + selene + make test), docs.yml
├── vim.toml / selene.toml        # Lint configs
├── LICENSE
└── README.md
```

## Core Modules

| Module | Role |
|---|---|
| `init.lua` | Public entry point. `M.setup(user_config)`, re-exports `register`/`deregister`/`enable`/`disable`/`toggle`/`get_source`/`get_sources`/`is_registered`/`register_name`/`reset_sources`, plus `builtins`/`methods`/`formatter`/`generator`. Creates `NullLsInfo` and `NullLsLog` user commands; sets up `FileType` auto-attach and `InsertLeave` RPC flush. |
| `config.lua` | Defaults table (debounce, debug, default_timeout, fallback_severity, diagnostics_format, log_level, notify_format, root_dir, root_dir_async, update_in_insert, diagnostic_config, temp_dir, border, on_attach, on_init, on_exit, should_attach, sources, cmd). Validates via `vim.validate` with `type_overrides`. `_setup` guard prevents double init. Defines `NullLsInfo*` highlights on setup. |
| `sources.lua` | Source registry: `register`, `deregister`, `enable`/`disable`/`toggle`, `get`/`get_all`/`get_available`/`get_supported`, `is_registered`, `register_name`, `reset`. Filetype + method matching (with override support). Transforms sources into `{ id, name, generator, filetypes (map), methods (map), condition, config, _validated }`. Conditional sources (`condition` fn) are deferred via `state.push_conditional_source` and registered lazily through `try_register`. Calls `client.on_source_change()` and `client.update_filetypes()` after mutation. |
| `methods.lua` | Defines two namespaces: `lsp` (real LSP method strings) and `internal` (`NULL_LS_*` strings), plus a `map` converting LSP->internal and `overrides`. The `overrides` table lets `DIAGNOSTICS_ON_OPEN` queries be satisfied by sources registered for `DIAGNOSTICS` or `DIAGNOSTICS_ON_SAVE`. Also exposes `request_name_to_capability` and `get_readable_name(m)`. |
| `client.lua` | Manages the **in-memory LSP client**. `should_attach(bufnr)` rejects unnamed/special buffers and consults `config.should_attach`. `get_root_dir` resolves via `config.root_dir` or `config.root_dir_async`. `on_init` installs a dynamic `supports_method` that returns true only if a registered generator can handle the method for the current buffer. `start_client` passes `rpc.start` as `cmd`. `try_add` / `retry_add` handle attach flow and (`retry_add`) re-issue synthetic `didOpen` to regenerate diagnostics. |
| `rpc.lua` | JSON-RPC request/response plumbing that drives the in-memory client. Defines static `capabilities` (formatting, range formatting, code action, completion, hover, textDocumentSync). `start(dispatchers)` returns `{ request, notify, is_closing, terminate }`. Routes each LSP method to the matching handler module. Caches `didChange` notifications in insert mode (respecting `update_in_insert`); `flush()` clears the cache on `InsertLeave`. |
| `generators.lua` | Runs registered generators for a given method/filetype. Uses **`plenary.async`** (`a.run`, `a.wrap`, `a.util.apcall`, `a.util.join`) for concurrency control, not `plenary.job`. Supports parallel and sequential (`opts.sequential`) execution. Handles per-generator `filter`, `runtime_condition`, `postprocess`, `after_each`. Stops failed generators (`_failed` flag) and supports self-deregistration via `_should_deregister`. Reports `$/progress` notifications. |
| `formatting.lua` | Handles `textDocument/formatting` and `textDocument/rangeFormatting`. Copies the buffer into a temp buffer, runs generators sequentially against it, computes a minimal diff via `diff.lua`, and applies the resulting text edit. Sets `_null_ls_handled` on params to signal the client. |
| `diagnostics.lua` | Produces and filters diagnostics. Maps `DID_CHANGE`->`DIAGNOSTICS`, `DID_OPEN`->`DIAGNOSTICS_ON_OPEN`, `DID_SAVE`->`DIAGNOSTICS_ON_SAVE`. Per-source namespaces (`NULL_LS_SOURCE_<id>`). Post-processes each diagnostic: range conversion, severity fallback, `source` tagging, `diagnostics_format` substitution (`#{m}` message, `#{s}` source, `#{c}` code), user `diagnostics_postprocess`. Dedupes via changedtick tracking and supports both single-file and multi-file diagnostics. |
| `code-actions.lua` | Handles `textDocument/codeAction` and `workspace/execute_command`. Registers actions into `state.actions` keyed by title, then wraps each as a command invocation. Sorts results by title before returning. Ignores requests marked `_null_ls_ignore`. |
| `completion.lua` | Handles `textDocument/completion`. Aggregates `items` from all matching generators and tracks `isIncomplete`. |
| `hover.lua` | Handles `textDocument/hover`. Returns `{ contents = { results } }` (note the extra wrapping table). |
| `diff.lua` | Computes a minimal LSP text edit (`{ range, newText, rangeLength }`) between old and new buffer contents. Adapted from Neovim's `vim.lsp.util.compute_diff`. Handles UTF-8 byte indexing. |
| `loop.lua` | **libuv-backed low-level process layer** — not "event loop scheduling." `spawn(cmd, args, opts)` runs a child process via `uv.spawn` with stdin/stdout/stderr pipes, timeout, `check_exit_code`, and optional temp-file handling. `timer(timeout, ...)` wraps `uv.new_timer`. `temp_file(content, bufname, dirname)` creates a temp file and registers a `VimLeavePre` cleanup. `read_file` / `write_file` are simple file utilities. |
| `state.lua` | Holds runtime state: `conditional_sources` (pending & registration), `cache` (per-uri, per-command output cache), `actions` (code-action registry keyed by title, with `register_action` / `run_action` / `clear_actions`), and `commands` (currently unused). |
| `logger.lua` | Leveled logging via `plenary.log`. Levels: off/error/warn/info/debug/trace. `debug` config flag forces level to "trace". `:NullLsLog` opens the log at `vim.fn.stdpath("cache") .. "/null-ls"`. `warn`/`error` also call `vim.notify`. |
| `health.lua` | `:checkhealth` integration. For each registered source reports whether `can_run()` passes and whether the resolved command is executable (respects `only_local` / `prefer_local`). Unresolvable dynamic commands are reported as "unable to verify." |
| `info.lua` | `:NullLsInfo` centered floating window (80% x 70% of editor, border defaults to "solid"). Shows active sources per filetype, supported methods from `_meta/filetype_map.lua`, log path/level, and highlights (`NullLsInfoHeader`, `NullLsInfoTitle`, `NullLsInfoSources`, `NullLsInfoBorder`). Closes on `<ESC>`, `q`, or buffer leave. |

## Setup Function Signature

```lua
require("null-ls").setup(user_config)
```

`user_config` is validated against defaults in `config.lua`. Key options:

| Option | Default | Type | Purpose |
|---|---|---|---|
| `cmd` | `{ "nvim" }` | table | Command used to start the in-memory server (null-ls uses nvim itself, passed as a table to `vim.lsp.start_client`). |
| `debounce` | `250` | number | Debounce ms forwarded to the LSP client's `flags.debounce_text_changes`. |
| `debug` | `false` | boolean | Forces log level to "trace" and enables verbose logging. |
| `default_timeout` | `5000` | number | Default generator spawn timeout (ms). |
| `diagnostic_config` | `{}` | table | Extra `vim.diagnostic.config` merged into every source namespace (e.g. `virtual_text`). |
| `diagnostics_format` | `"#{m}"` | string | Format string for diagnostic messages (`#{s}` source, `#{m}` message, `#{c}` code). |
| `fallback_severity` | `ERROR` | number | Severity used when a diagnostic doesn't specify one. |
| `log_level` | `"warn"` | string | Logging level (`off`/`error`/`warn`/`info`/`debug`/`trace`). |
| `notify_format` | `"[null-ls] %s"` | string | `vim.notify` format. |
| `root_dir` | `u.root_pattern(".null-ls-root","Makefile",".git")` | function | Root detection. |
| `root_dir_async` | `nil` | function\|nil | Async root detection (overrides `root_dir` when set). |
| `update_in_insert` | `false` | boolean | If false, `didChange` notifications are cached in insert mode and flushed on `InsertLeave`. |
| `on_attach` | `nil` | function\|nil | Callback when the in-memory client attaches to a buffer. |
| `on_init` / `on_exit` | `nil` | function\|nil | Lifecycle hooks on the LSP client. |
| `should_attach` | `nil` | function\|nil | Extra filter (bufnr) whether the client should attach. |
| `sources` | `nil` | table\|nil | Sources to register on setup. |
| `temp_dir` | `nil` | string\|nil | Directory for generator temp files. |
| `border` | `nil` | table\|string\|nil | Border style for the `:NullLsInfo` floating window. |

## Dependencies

- **plenary.nvim** -- required (provides `plenary.log`, `plenary.async`, `plenary.test_harness`, `plenary.path`, `plenary.busted`, `plenary.path`, async lib, curl, etc.).
- **Neovim >= 0.7** (uses `vim.validate`, `vim.diagnostic`, `vim.lsp`, `vim.api.nvim_set_hl`, libuv).
- No other runtime dependencies; CLI tools invoked by builtins must be installed separately (e.g., `stylua`, `eslint`).

## How It Registers Sources & Features

**Registration** (`sources.lua`):
- `null_ls.register(source | source[] | { sources = [...], filetypes = ..., name = ... })`.
- Each source is validated (`validate_and_transform`): requires `generator` (table with `fn`), `filetypes` (table), `method` (table of internal methods), optional `condition`, `config`, `can_run`, `disabled_filetypes`.
- Filetypes & methods are converted to maps for fast lookup (empty filetypes becomes `{ _all = true }`); a unique integer `id` is assigned.
- Conditional sources (`condition` fn) are deferred via `state.push_conditional_source` and registered lazily through `try_register` the next time a matching buffer is opened.
- After registration, `client.on_source_change()` and `client.update_filetypes()` refresh the in-memory client.

**Feature dispatch** (via the in-memory LSP client in `client.lua` + handlers):
- **Formatting** -- `formatting.lua` handles `textDocument/formatting` and `textDocument/rangeFormatting`; uses a temp buffer + `diff.lua` to apply minimal edits.
- **Diagnostics** -- `diagnostics.lua` produces diagnostics; triggered on `DID_CHANGE`, `DID_OPEN`, `DID_SAVE` (mapped to `DIAGNOSTICS`, `DIAGNOSTICS_ON_OPEN`, `DIAGNOSTICS_ON_SAVE`).
- **Code actions** -- `code-actions.lua` handles `textDocument/codeAction`; `workspace/execute_command` re-runs the registered action.
- **Completion** -- `completion.lua` handles `textDocument/completion`.
- **Hover** -- `hover.lua` handles `textDocument/hover`.

The `methods.lua` `lsp_to_internal_map` converts incoming LSP method strings to internal `NULL_LS_*` constants; `overrides` lets `DIAGNOSTICS_ON_OPEN` queries be satisfied by sources registered for `DIAGNOSTICS` or `DIAGNOSTICS_ON_SAVE`.

## Built-in Source Categories

Five public categories, each a lazy-loaded table under `lua/null-ls/builtins/<category>/`:

| Category | Internal method | Example builtins | Count |
|---|---|---|---|
| `formatting` | `NULL_LS_FORMATTING` / `NULL_LS_RANGE_FORMATTING` | stylua, black, prettier, clang_format, biome, alejandra, autopep8 | ~161 |
| `diagnostics` | `NULL_LS_DIAGNOSTICS` (+ on_open/on_save) | eslint, pylint, actionlint, bandit, buf, checkstyle, clj_kondo, codespell, cppcheck, credo | ~115 |
| `code_actions` | `NULL_LS_CODE_ACTIONS` | eslint_d, gitsigns, shellcheck, gomodifytags, refactoring, statix, xo, ts_node_action | 15 |
| `completion` | `NULL_LS_COMPLETION` | spell, luasnip, tags, vsnip | 4 |
| `hover` | `NULL_LS_HOVER` | printenv, dictionary | 2 |

Plus internal `_test` (sources used only by the test suite, e.g. `first_formatter`, `slow_code_action`) and `_meta` (generated `filetype_map.lua` mapping filetype -> method -> builtin names, and per-method maps backing `sources.get_supported`).

## Builtin Structure -- The Factory Pattern

Every builtin is built by `make_builtin(opts)` in `helpers/make_builtin.lua`:

- **Input opts**: `name`, `meta` (url, description), `method` (internal method or list), `filetypes`, `extra_filetypes`, `disabled_filetypes`, `generator_opts` (command, args, to_stdin, from_stderr, from_temp_file, format, check_exit_code, env, cwd, timeout, dynamic_command, ignore_stderr, ignore_stdout, diagnostics_format, diagnostic_config, filter, diagnostics_postprocess, runtime_condition, to_temp_file, temp_dir, on_output, use_cache, multiple_files), `factory` (defaults to a plain generator return), `condition`, `config`, `can_run`, `prefer_local`/`only_local` (resolves local node_modules/yarn-pnp binaries), `extra_args`, `prepend_extra_args`.
- **Factory**: defaults to returning the generator as-is; `formatter_factory` wraps output into `{ { text = output } }`, forces `ignore_stderr = true`, and forces `from_temp_file` when `to_temp_file` is set; `generator_factory` returns an async generator table (`async = true`) whose `fn` spawns the command via `loop.spawn`, parses output (raw/line/json/json_raw), handles caching, temp files, and dynamic commands.
- **Metatable trick**: the returned builtin table uses `__index` so `generator` is **lazily** produced by calling `factory(generator_opts)` on first access -- this lets `.with(user_opts)` create a fresh copy via `vim.tbl_extend("force", opts, user_opts)` and re-run the factory.
- **`.with(user_opts)`**: returns a new builtin with merged options (the primary customization API, e.g. `null_ls.builtins.formatting.stylua.with({ extra_args = { "--indent-width", "2" } })`).
- **Command resolution**: `prefer_local`/`only_local` set `dynamic_command` via `command_resolver.generic(prefix)` (or `from_node_modules` / `from_yarn_pnp` for specialized variants). When both are set, `only_local` wins. The resolver walks `vim.fs.parents` from the buffer to the root looking for an executable at `<prefix>/<command>`, caching results per bufnr.
- **extra_args handling**: when `extra_args` is set, `generator_opts.args` is replaced with a function that merges original + extra args, respecting `prepend_extra_args` and keeping `"-"` last for stdin.

Example (stylua.lua):
```lua
return h.make_builtin({
    name = "stylua",
    meta = { url = "...", description = "..." },
    method = { FORMATTING, RANGE_FORMATTING },
    filetypes = { "lua", "luau" },
    generator_opts = {
        command = "stylua",
        args = h.range_formatting_args_factory({ ... }, "--range-start", "--range-end", { row_offset = -1, col_offset = -1 }),
        to_stdin = true,
    },
    factory = h.formatter_factory,
})
```

### Helpers Subsystem

- **`helpers/diagnostics.lua`**: output parsers -- `from_pattern`, `from_patterns`, `from_errorformat`, `from_json`. Handles attribute adapters (`from_quote`, `from_length`), severity maps, byte-index column conversion, and offset application. Re-exported as `null_ls.helpers.diagnostics` (note: distinct from the top-level `null-ls.diagnostics` module).
- **`helpers/cache.lua`**: `by_bufnr(cb)` wraps a callback in a per-buFnr cache; used by command resolvers.
- **`helpers/range_formatting_args_factory.lua`**: returns a function injecting range markers into args based on method (full-file vs range).
- **`helpers/cspell.lua`**: internal helper (not exported from `helpers/init.lua`) that locates `cspell.json` configs and falls back to a generated minimal config.
- **`helpers/init.lua`** re-exports: `cache`, `diagnostics`, `formatter_factory`, `generator_factory`, `make_builtin`, `range_formatting_args_factory`.

### NullLsParams

Built by `utils/make_params.lua`. The returned `NullLsParams` object is a lazy-resolving metatable wrapper with these fields:
- `method`, `bufnr`, `ft` / `filetype`, `bufname`, `content` (string[]), `row`, `col`, `range` (1-indexed `NullLsRange`), `word_to_complete`.
- `lsp_method` (original LSP method), `lsp_params` (raw), `options`.
- `source_id` (set by `generators.run`), `command`, `root` (set by `generator_factory`).
- Lazy computed: `content`, `bufname`, `ft`/`filetype`, `_pos` (cursor position), `range`, `word_to_complete`.
- Methods: `get_source()` resolves the source by `source_id`; `get_config()` returns `source.config or {}`.

## Build / Test / Check Commands

From `Makefile`:

| Command | Action |
|---|---|
| `make test` | Run full suite headless: `nvim --headless --noplugin -u test/minimal_init.lua -c "lua require('plenary.test_harness').test_directory_command('test/spec {minimal_init = \"test/minimal_init.lua\"}')"` |
| `make test-file FILE=path` | Run a single spec file via `plenary.busted.run`. |
| `make check` | Run `pre-commit run --all-files` (stylua + prettier). |
| `make install-hooks` | Install pre-commit hooks. |
| `make clean` | Remove `.tests/`. |
| `make autogen` | Run `scripts/autogen.sh` (invokes `scripts/autogen.lua`; CI-only; generates `_meta` files). |

CI (`.github/workflows/build.yml`) runs three jobs on PRs & pushes to `main`: **stylua** (formatting check), **selene** (linting `./lua`), and **test** (`make test`). Tests depend on checking out `plenary.nvim` into `.tests/site/pack/deps/start/plenary.nvim`.

## Coding Conventions

- **Module pattern**: every module is a single `local M = {} ... return M` file; requires are short aliases (`local c = require("null-ls.config")`, `local u = ...utils`, `local s = ...state`, `local h = ...helpers`, `local methods = require("null-ls.methods")`).
- **Naming**: module `M`, methods are `M.snake_case`; internal constants are `SCREAMING_SNAKE` (`NULL_LS_FORMATTING`); config keys are `snake_case`.
- **Validation**: heavy use of `vim.validate` with custom type-override tables and clear error messages.
- **Lazy loading**: builtins use metatable `__index` to `require` on first access and `rawset` to cache; `make_builtin` lazily constructs the generator.
- **Immutability caution**: `vim.deepcopy(opts.generator_opts)` inside `make_builtin`; `vim.tbl_extend("force", ...)` for merges; `vim.tbl_deep_extend` for generator_opts.
- **Formatting**: enforced by **stylua** (`stylua.toml`: `indent_type = "Spaces"`, 2-space indent) and **prettier** for non-Lua files (`.pre-commit-config.yaml`).
- **Linting**: **selene** (`selene.toml`) for Lua static analysis.
- **Docs**: markdown docs in `doc/` (MAIN.md, BUILTINS.md, BUILTIN_CONFIG.md, CONFIG.md, HELPERS.md, SOURCES.md, TESTING.md, CONTRIBUTING.md, null-ls.txt); user commands `NullLsInfo` / `NullLsLog`.
- **Type annotations**: occasional `---@param` / `---@return` and `---@usage` comments (e.g., `config.lua`, `methods.lua`); full `NullLsParams` class in `utils/make_params.lua`.
- **Logging**: `log:debug/info/warn/error` via `logger.lua`; conditional sources log registration decisions.
- **Autogeneration**: `_meta/filetype_map.lua` and per-method maps are generated, not hand-edited (`make autogen`).
- **Spec naming**: `test/spec/<module>_spec.lua` mirrors `lua/null-ls/<module>.lua`; fixtures in `test/files/`, helpers in `test/scripts/`.

## Key API Surface

```lua
local null_ls = require("null-ls")
null_ls.setup({ sources = {...}, ... })          -- configure + register initial sources
null_ls.register(source | sources)               -- add sources (single, list, or { sources, filetypes, name })
null_ls.deregister(query)                        -- remove by name/method/id/filetype (string or table query)
null_ls.enable / disable / toggle(query)         -- toggle sources matching query
null_ls.get_source(query) / get_sources()        -- introspection (get_source returns list; get_sources returns all)
null_ls.is_registered(query)                     -- boolean
null_ls.register_name(name)                      -- mark a name as registered (for :NullLsInfo display)
null_ls.reset_sources()                          -- wipe all registered sources
null_ls.builtins.<category>.<name>               -- built-in sources (lazy-loaded)
null_ls.builtins.<cat>.<name>.with({...})        -- customize a builtin (returns fresh copy)
null_ls.methods.DIAGNOSTICS / FORMATTING / ...   -- internal method constants
null_ls.methods.<lsp_method_name>                -- LSP method strings (e.g. null_ls.methods.CODE_ACTION)
null_ls.formatter({...}) / null_ls.generator({...}) -- factory helpers (formatter_factory / generator_factory)
null_ls.helpers.diagnostics                      -- diagnostic output parsers (from_pattern / from_json / from_errorformat)
null_ls.helpers.make_builtin({...})              -- build a custom builtin
null_ls.helpers.range_formatting_args_factory(...) -- range-formatting arg builder
```
