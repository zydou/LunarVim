# structlog.nvim

## Project Overview

structlog.nvim is a structured logging library for Neovim, inspired by Python's structlog. It builds log entries as dictionaries, passes them through a processor pipeline, formats them, and writes them to various sinks. The core idea is to treat logs as key/value events with context rather than opaque strings.

## Directory Structure

```
structlog.nvim/
├── lua/structlog/
│   ├── init.lua              # Entry point: configure() / get_logger(), aggregates all submodules
│   ├── logger.lua            # Logger class: creation, cloning, log level methods
│   ├── pipeline.lua          # Pipeline class: processor chain -> formatter -> sink
│   ├── level.lua             # Log level definitions (TRACE=1 .. ERROR=5)
│   ├── processors/
│   │   ├── init.lua          # Processor aggregation: Timestamper, StackWriter
│   │   ├── timestamper.lua   # Adds a timestamp field
│   │   └── stack_writer.lua  # Adds call stack info (file, line)
│   ├── formatters/
│   │   ├── init.lua          # Formatter aggregation: Format, FormatColorizer, KeyValue
│   │   ├── format.lua        # String formatting (string.format style)
│   │   ├── format_colorizer.lua # Highlight-aware formatting (for Console sink)
│   │   └── key_value.lua     # key=value output via vim.inspect
│   └── sinks/
│       ├── init.lua          # Sink aggregation: Console, File, RotatingFile, Adapter, NvimNotify
│       ├── console.lua       # Writes to the Neovim console (nvim_echo)
│       ├── file.lua          # Appends to a file
│       ├── rotating_file.lua # Size/time based log file rotation
│       ├── adapter.lua       # Custom sink adapter
│       └── plugins/
│           └── nvim_notify.lua # Writes to nvim-notify notifications
├── test/
│   ├── minimal-init.lua      # Neovim init used by tests
│   ├── unit/                 # Unit tests (plenary.busted)
│   └── integration/          # Integration tests
├── script/test.sh            # Test runner script
├── .github/workflows/        # CI: test, sanitize, documentation
├── Makefile                  # test / lint / format / doc targets
├── config.ld                 # LDoc documentation config
├── .stylua.toml              # Stylua formatting config
├── .luacheckrc               # Luacheck linting config
├── LICENSE                   # MIT License
└── structlog.nvim-0.1-1.rockspec  # LuaRocks package spec
```

## Core Modules

### `structlog.init` — Main Entry Point

- `M.configure(logger_configs)` — Configure one or more loggers
- `M.get_logger(name)` — Return a clone of the configured logger, or `nil` if not found

Exported table: `M.Logger`, `M.Pipeline`, `M.level`, `M.formatters`, `M.processors`, `M.sinks`

### `structlog.logger` — Logger Class

- `Logger(name, pipelines)` — Constructor
- `logger:clone()` — Deep-copies the logger (including context)
- `logger:add_pipeline(pipeline)` — Append a pipeline to the logger
- `logger:set_name(name)` — Rename the logger and update `context.logger_name`
- `logger:log(level, msg, events)` — Generic log method
- `logger:trace/debug/info/warn/error(msg, events)` — Level-specific shortcuts
- `logger.context` — Dictionary of context fields, automatically merged into every log entry

### `structlog.pipeline` — Pipeline Class

- `Pipeline(level, processors, formatter, sink)` — Constructor
- `pipeline:push(log)` — Run processor chain -> format -> write to sink

### `structlog.level` — Log Levels

`TRACE=1, DEBUG=2, INFO=3, WARN=4, ERROR=5`. `Level.name(level)` returns the string representation.

### Processors

Processors are callables (functions or tables with `__call`) that receive a log dictionary and return a modified dictionary. They are chained in order.

- `Timestamper(format)` — Adds a `timestamp` field (uses `os.date` format)
- `StackWriter(keys, opts)` — Adds `file` / `line` fields (via `debug.getinfo`)
  - `opts.max_parents` — Max parent directories shown in the file path
  - `opts.stack_level` — Stack level to inspect, relative to the logger method caller (default `0`)

### Formatters

Formatters receive a log dictionary and return a modified dictionary where `log.msg` holds the final output (except `KeyValue`, which returns the string directly).

- `Format(format, entries, opts)` — `string.format` style; remaining fields are appended as `key=value`
  - `opts.blacklist` — List of entries to exclude from formatting (default `{}`)
  - `opts.blacklist_all` — When `true`, suppresses the trailing key/value output (default `false`)
- `FormatColorizer(format, entries, colors, opts)` — Like `Format` but returns an array of `{text, color}` tuples for highlighted console output
  - `colors` — Map of entry name to a colorizer function
  - `opts.blacklist`, `opts.blacklist_all` — Same as `Format`
  - `FormatColorizer.color_level()` — Helper that maps log levels to highlight groups (TRACE/DEBUG -> Comment, INFO -> None, WARN -> WarningMsg, ERROR -> ErrorMsg)
  - `FormatColorizer.color(hl_group)` — Helper that returns a constant highlight group regardless of value
- `KeyValue()` — Returns the `vim.inspect` representation of the entire log entry as a string

### Sinks

Sinks are the final destination of log entries. They expose `sink:write(entry)`.

- `Console(async?)` — Writes via `nvim_echo`. When `async` is falsy (the default), output is synchronous unless inside a fast event; when `true`, output is always scheduled via `vim.schedule`.
- `File(path, iolib?)` — Appends to a file. `iolib` defaults to `io` (overridable for testing).
- `RotatingFile(path, opts)` — Rotates logs by size and/or age
  - `opts.max_size` — Max file size in bytes
  - `opts.max_age` — Max file age in seconds
  - `opts.time_format` — Timestamp format for the archive name (default `"%F-%H:%M:%S"`)
  - `opts.uv` — Libuv handle (default `vim.loop`)
  - `opts.iolib` — IO library forwarded to the underlying `File` sink
- `Adapter(fn)` — Wraps a custom function `fn(log)` as a sink
- `NvimNotify(notify?, opts?)` — Writes to nvim-notify. `notify` defaults to `require("notify")`; `opts` are merged into the nvim-notify options.

## Configuration

```lua
local log = require("structlog")

log.configure({
  my_logger = {
    pipelines = {
      {
        level = log.level.INFO,
        processors = {
          log.processors.Timestamper("%H:%M:%S"),
          log.processors.StackWriter({ "line", "file" }, { max_parents = 0 }),
        },
        formatter = log.formatters.Format(
          "%s [%s] %s: %-30s",
          { "timestamp", "level", "logger_name", "msg" }
        ),
        sink = log.sinks.Console(),
      },
    },
  },
})

local logger = log.get_logger("my_logger")
logger:info("message", { key = "value" })
```

Pipeline configs support two forms:
- **Named keys**: `{ level, processors, formatter, sink }`
- **Positional (array)**: `{ level, { processors... }, formatter, sink }` — unpacked in order

## Dependencies

- **Required**: None (only `lua >= 5.1`)
- **Optional**: `nvim-notify` (only needed when using the `NvimNotify` sink)
- **Published as**: A LuaRocks package usable by any Neovim plugin

## Build / Test

- `make test FILE=...` — Run tests via plenary.busted (omit `FILE` to run the full suite)
- `make lint` — `luacheck` static analysis
- `make format` — `stylua` formatting
- `make doc` — `ldoc` documentation generation

## Coding Conventions

- Formatted with `stylua` (`.stylua.toml`)
- Linted with `luacheck` (`.luacheckrc`)
- Classes and factory functions use the `setmetatable` + `__call` metatable pattern
- Module documentation uses LDoc-style `---` comments
- Processors / formatters / sinks are aggregated and re-exported through their respective `init.lua`
