# friendly-snippets

## Project Overview

friendly-snippets is a community-driven collection of code snippets for a wide variety of programming languages. Its goal is to be a single repository where users can find snippets for every language they use.

All snippets follow the VS Code snippet format (JSON). Any snippet engine that supports loading VS Code snippets can consume this collection — for example [vim-vsnip](https://github.com/hrsh7th/vim-vsnip), [LuaSnip](https://github.com/L3MON4D3/LuaSnip), or [coc-snippets](https://github.com/neoclide/coc-snippets).

The repository is pure data: there is no Lua runtime module or build step. Snippet engines read the JSON files directly.

---

## Directory Structure

```
friendly-snippets/
├── LICENSE                              # MIT License (Copyright 2021 Rafael Madriz)
├── README.md                            # Project documentation (install, usage, credits)
├── .editorconfig                        # Editor formatting rules
├── .github/workflows/
│   └── *.yml                            # CI: format JSON files with Prettier (tab-width 4)
├── package.json                         # VS Code extension manifest (maps language IDs → snippet paths)
├── debug/
│   ├── lazy-nvim.lua                    # Bootstrap config for debugging with lazy.nvim + LuaSnip
│   └── packer-nvim.lua                  # Bootstrap config for debugging with packer.nvim + LuaSnip
└── snippets/
    ├── global.json                      # Global snippets (timestamps, dates, UUID, copyright)
    ├── license.json                     # License header snippets
    ├── html.json                        # HTML (also mapped to jade, pug, eruby, jsreact, htmldjango, astro, blade)
    ├── css.json                         # CSS (also mapped to scss, sass, less, stylus)
    ├── javascript/
    │   ├── javascript.json              # JavaScript (also mapped to jsreact, vue, svelte)
    │   ├── typescript.json              # TypeScript (also mapped to tsreact)
    │   ├── jsdoc.json                   # JSDoc comments
    │   ├── tsdoc.json                   # TSDoc comments
    │   ├── react.json                   # React (javascriptreact)
    │   ├── react-ts.json                # React (typescriptreact)
    │   ├── react-native.json            # React Native (javascriptreact)
    │   ├── react-native-ts.json         # React Native (typescriptreact)
    │   ├── next.json                    # Next.js (javascriptreact)
    │   ├── next-ts.json                 # Next.js (typescriptreact)
    │   ├── react-es7.json               # React ES7+ (javascriptreact, typescriptreact)
    │   └── ...
    ├── python/
    │   ├── python.json                  # Python general
    │   ├── comprehension.json           # List/dict/set comprehensions
    │   ├── unittest.json                # unittest snippets
    │   ├── debug.json                   # Debugging (pdb, ipdb, rpdb, pudb, IPython, Celery rdb, debugpy, pprint)
    │   └── pydoc.json                   # Python docstrings
    ├── lua/
    │   ├── lua.json                     # Lua
    │   └── luadoc.json                  # Lua docstrings
    ├── c/
    │   ├── c.json                       # C
    │   └── cdoc.json                    # C doc comments
    ├── cpp/
    │   ├── cpp.json                     # C++
    │   └── cppdoc.json                  # C++ doc comments
    ├── csharp/
    │   ├── csharp.json                  # C#
    │   └── csharpdoc.json               # C# doc comments
    ├── ruby/
    │   ├── ruby.json                    # Ruby
    │   ├── rdoc.json                    # Ruby doc comments
    │   └── rspec.json                   # RSpec
    ├── rust/
    │   ├── rust.json                    # Rust
    │   └── rustdoc.json                 # Rust doc comments
    ├── java/
    │   ├── java.json                    # Java
    │   ├── java-tests.json              # Java tests (language ID: java-testing)
    │   └── javadoc.json                 # Javadoc comments
    ├── go.json                          # Go
    ├── php/
    │   ├── php.json                     # PHP
    │   └── phpdoc.json                  # PHP doc comments
    ├── shell/
    │   ├── shell.json                   # Shell (shellscript, shell, sh, zsh)
    │   └── shelldoc.json                # Shell doc comments
    ├── kotlin/
    │   ├── kotlin.json                  # Kotlin
    │   └── kdoc.json                    # KDoc comments
    ├── ocaml/
    │   ├── ocaml.json                   # OCaml (also ocamlinterface)
    │   ├── ocamllex.json                # OCamllex
    │   ├── dune.json                    # Dune build system
    │   └── dune-project.json            # Dune project files
    ├── latex/                           # LaTeX sub-collection
    │   ├── latex-snippets.json
    │   ├── vscode-latex-snippets.json
    │   └── bibtex.json                  # BibTeX (bibtex, bib)
    ├── docker/
    │   ├── docker-compose.json          # Docker Compose
    │   └── docker_file.json             # Dockerfile
    ├── cobol/
    │   ├── vscode_cobol.json
    │   ├── vscode_cobol-compound.json
    │   ├── vscode_cobol_dir.json
    │   └── vscode_cobol_jcl.json
    ├── frameworks/                       # Framework-specific snippets (not auto-loaded)
    │   ├── rails.json                   # Ruby on Rails
    │   ├── django/                      # Django (admin, forms, models, tags, urls, views)
    │   │   └── django_rest/             # Django REST framework (serializers, views)
    │   ├── djangohtml.json              # Django HTML templates (djangohtml, htmldjango)
    │   ├── vue/                         # Vue (html, script, style, nuxt-html, nuxt-script, vue)
    │   ├── angular/                     # Angular (html, typescript, jsonc)
    │   ├── blade/                       # Laravel Blade (blade, helpers, livewire, snippets)
    │   ├── relm4/                       # Relm4 (workers, factories, templates, components) — Rust
    │   ├── remix-ts.json                # Remix (TypeScript)
    │   ├── flutter.json                 # Flutter / Dart
    │   ├── jekyll.json                  # Jekyll
    │   ├── twig.json                    # Twig
    │   ├── edge.json                    # Edge templates
    │   ├── ejs.json                     # EJS
    │   ├── unity.json                   # Unity (C#)
    │   ├── unreal.json                  # Unreal Engine
    │   └── ...
    ├── markdown.json                    # Markdown (also mapped to rmd)
    ├── latex.json                       # LaTeX (plaintex, tex)
    ├── gitcommit.json                   # Git commit messages (also NeogitCommitMessage)
    ├── editorconfig.json                # .editorconfig
    ├── kubernetes.json                  # Kubernetes manifests (yaml)
    ├── terraform.json                   # Terraform
    ├── sql.json                         # SQL
    ├── dart.json                        # Dart
    ├── swift.json                       # Swift
    ├── julia.json                       # Julia
    ├── scala.json                       # Scala
    ├── haskell.json                     # Haskell
    ├── elixir.json                      # Elixir
    ├── eelixir.json                     # EEx / HEEx
    ├── erlang.json                      # Erlang
    ├── erb.json                         # ERB
    ├── nix.json                         # Nix
    ├── fennel.json                      # Fennel
    ├── gleam.json                       # Gleam
    ├── rescript.json                    # ReScript
    ├── purescript.json                  # PureScript
    ├── reason.json                      # Reason
    ├── r.json                           # R (also rmd)
    ├── rmarkdown.json                   # R Markdown
    ├── plantuml.json                    # PlantUML
    ├── solidity.json                    # Solidity
    ├── systemverilog.json               # SystemVerilog
    ├── verilog.json                     # Verilog
    ├── vhdl.json                        # VHDL
    ├── tcl.json                         # Tcl
    ├── perl.json                        # Perl
    ├── cmake.json                       # CMake
    ├── make.json                        # Make
    ├── nushell.json                     # Nushell
    ├── PowerShell.json                  # PowerShell (powershell, ps1)
    ├── mint.json                        # Mint
    ├── gdscript.json                    # GDScript
    ├── kivy.json                        # Kivy
    ├── liquid.json                      # Liquid
    ├── org.json                         # Org mode
    ├── norg.json                        # Neorg
    ├── asciidoc.json                    # AsciiDoc
    ├── beancount.json                   # Beancount
    ├── rst.json                         # reStructuredText
    ├── loremipsum.json                  # Lorem Ipsum placeholder text
    ├── glsl.json                        # GLSL shaders
    ├── fsh.json                         # F#
    ├── objc.json                        # Objective-C
    ├── zig.json                         # Zig
    └── svelte.json                      # Svelte
```

---

## Data Format

Every JSON file follows the VS Code snippet format:

```json
{
  "snippetName": {
    "prefix": "trigger",
    "body": ["line1", "line2"],
    "description": "Description of the snippet"
  }
}
```

- `prefix` — the trigger string (string or array of strings).
- `body` — the snippet content (string or array of lines). Supports VS Code tab stops (`$0`, `$1`, `${1:default}`), variables (`${CURRENT_YEAR}`, `${UUID}`, etc.), and placeholders.
- `description` — human-readable explanation of what the snippet does.

---

## Language Registration (package.json)

The `contributes.snippets` array in `package.json` maps each JSON file to one or more VS Code language IDs:

```json
{
  "language": ["javascript", "javascriptreact", "vue", "svelte"],
  "path": "./snippets/javascript/javascript.json"
}
```

When adding or modifying a snippet file, you **must** also update this array so the snippet engine knows which filetypes the snippets apply to.

---

## Framework Snippets

Framework snippets live under `snippets/frameworks/` and are **not loaded by default**. Users must explicitly enable them via their snippet engine. For example, with LuaSnip:

```lua
require("luasnip").filetype_extend("ruby", {"rails"})
```

This design keeps the default experience lean for users who do not use those frameworks.

---

## Code Style & Formatting

Enforced by `.editorconfig` and the CI workflow (Prettier):

| File type | Indentation | Line endings |
|-----------|-------------|--------------|
| `*.json`  | 4 spaces    | LF           |
| `*.lua`   | tab (width 4) | LF         |
| `*.md`    | 2 spaces    | LF           |
| `*.yml`   | 2 spaces    | LF           |

- All files must end with a final newline (`insert_final_newline = true`).
- The CI workflow runs `prettier --tab-width 4 --parser json --write **/*.json` on every push to `main`.

---

## Adding New Snippets

1. Create or edit the appropriate JSON file under `snippets/`. Use the standard VS Code language ID as the filename (e.g., `python.json`, `go.json`).
2. For framework-specific snippets, place the file under `snippets/frameworks/` in a subdirectory named after the framework.
3. Register the file in `package.json` under `contributes.snippets` with the correct `language` ID(s) and `path`.
4. Follow the existing formatting: 4-space indentation, LF line endings, final newline.
5. Use concise, memorable `prefix` values and clear `description` strings.

---

## Loading Snippets

friendly-snippets is engine-agnostic. Users load it through their snippet engine of choice:

**LuaSnip (recommended):**
```lua
{
  "L3MON4D3/LuaSnip",
  dependencies = { "rafamadriz/friendly-snippets" },
  config = function()
    require("luasnip.loaders.from_vscode").lazy_load()
  end,
}
```

**vim-vsnip:**
```vim
let g:vsnip_filetypes = {}
```

**coc-snippets:**
```vim
:CocInstall https://github.com/rafamadriz/friendly-snippets@main
```

---

## Debug Helpers

The `debug/` directory contains self-contained Neovim configurations for testing snippet loading during development:

- `lazy-nvim.lua` — bootstraps lazy.nvim in a temp directory with LuaSnip + nvim-cmp.
- `packer-nvim.lua` — bootstraps packer.nvim in a temp directory with LuaSnip + nvim-cmp.

These are not part of the shipped collection; they are developer tooling only.

---

## License

MIT License. Copyright (c) 2021 Rafael Madriz. See `LICENSE` for the full text.
