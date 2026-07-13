# Neovim Plugins — 版本锁定仓库

这是一个 Neovim 插件集合仓库，用于将常用插件锁定到特定 commit hash 以实现可复现的安装。使用 [lazy.nvim](lazy.nvim/) 作为插件管理器。

## 仓库结构

```
.
├── lock.json            # 版本锁定文件 (55 个插件)
├── LICENSE
├── README.md
├── <plugin_name>/       # 每个插件的独立目录
│   ├── lua/             # Lua 源码
│   ├── plugin/          # Vim plugin 入口
│   ├── doc/             # 文档
│   ├── CLAUDE.md        # 插件代码库说明
│   └── ...
└── CLAUDE.md            # 本文件 — 根目录说明
```

## 插件列表 (按功能分类)

### 核心框架
| 插件 | 描述 | 作者 | 锁定 commit |
|------|------|------|-------------|
| [lazy.nvim](lazy.nvim/) | 插件管理器，支持延迟加载 | folke | bef521a |
| [plenary.nvim](plenary.nvim/) | Lua 工具库（Job/Path/Async 等） | nvim-lua | 08e3019 |
| [nui.nvim](nui.nvim/) | UI 组件库（Popup/Input/Layout 等） | MunifTanjim | 53e907f |

### LSP 与补全
| 插件 | 描述 | 作者 | 锁定 commit |
|------|------|------|-------------|
| [nvim-lspconfig](nvim-lspconfig/) | 300+ LSP 服务器配置集合 | neovim | aa5f4f4 |
| [nvim-cmp](nvim-cmp/) | 补全引擎核心 | hrsh7th | cd2cf0c |
| [cmp-buffer](cmp-buffer/) | 缓冲区补全源 | hrsh7th | 3022dbc |
| [cmp-path](cmp-path/) | 路径补全源 | hrsh7th | 91ff86c |
| [cmp-cmdline](cmp-cmdline/) | 命令行补全源 | hrsh7th | d126061 |
| [cmp-nvim-lsp](cmp-nvim-lsp/) | LSP 补全源 | hrsh7th | cbc7b02 |
| [cmp_luasnip](cmp_luasnip/) | LuaSnip 补全源 | saadparwaiz1 | 05a9ab2 |
| [mason.nvim](mason.nvim/) | LSP/DAP/linters 包管理器 | williamboman | 751b1fc |
| [mason-lspconfig.nvim](mason-lspconfig.nvim/) | Mason↔lspconfig 桥梁 | williamboman | 273fdde |
| [nlsp-settings.nvim](nlsp-settings.nvim/) | JSON/YAML LSP 设置加载器 | tamago324 | 707b431 |
| [neodev.nvim](neodev.nvim/) | Neovim Lua 开发配置 | folke | ce9a2e8 |
| [nvim-navic](nvim-navic/) | LSP 面包屑导航 | SmiteshP | 8649f69 |
| [schemastore.nvim](schemastore.nvim/) | JSON Schema 数据 | b0o | 8c46453 |

### Treesitter
| 插件 | 描述 | 作者 | 锁定 commit |
|------|------|------|-------------|
| [nvim-treesitter](nvim-treesitter/) | Tree-sitter 抽象层 | nvim-treesitter | d5a1c2b |
| [nvim-ts-context-commentstring](nvim-ts-context-commentstring/) | 上下文注释字符串 | JoosepAlviste | 0bdccb9 |
| [rainbow-delimiters.nvim](rainbow-delimiters.nvim/) | 彩虹括号 | hiphish | cf0da25 |
| [vim-matchup](vim-matchup/) | 增强 `%` 匹配导航 | andymass | aca23e |

### Git 集成
| 插件 | 描述 | 作者 | 锁定 commit |
|------|------|------|-------------|
| [gitsigns.nvim](gitsigns.nvim/) | Git 状态列/ blame | lewis6991 | 805610a |

### 编辑增强
| 插件 | 描述 | 作者 | 锁定 commit |
|------|------|------|-------------|
| [Comment.nvim](Comment.nvim/) | 注释切换 | numToStr | 0236521 |
| [nvim-surround](nvim-surround/) | 符号包围编辑 | kylechui | ae29810 |
| [nvim-autopairs](nvim-autopairs/) | 自动配对 | windwp | 14e9737 |
| [nvim-lastplace](nvim-lastplace/) | 光标位置恢复 | ethanholz | 0bb6103 |
| [multicursors.nvim](multicursors.nvim/) | 多光标编辑 (Hydra 构建) | smoka7 | 562809a |
| [LuaSnip](LuaSnip/) | 代码片段引擎 | L3MON4D3 | 1def353 |
| [friendly-snippets](friendly-snippets/) | 预置代码片段集合 | rafamadriz | 6cd7280 |
| [copilot.lua](copilot.lua/) | GitHub Copilot 集成 | zbirenbaum | 30321e3 |
| [copilot-cmp](copilot-cmp/) | Copilot 补全源 | zbirenbaum | 15fc12a |

### 导航与搜索
| 插件 | 描述 | 作者 | 锁定 commit |
|------|------|------|-------------|
| [hop.nvim](hop.nvim/) | EasyMotion 跳转 | smoka7 | efe5818 |
| [telescope.nvim](telescope.nvim/) | 模糊查找器 | nvim-telescope | 6312868 |
| [telescope-fzf-native.nvim](telescope-fzf-native.nvim/) | fzf 原生排序 | nvim-telescope | 9ef21b2 |
| [which-key.nvim](which-key.nvim/) | 键绑定提示 | folke | 4433e5e |

### UI/视觉
| 插件 | 描述 | 作者 | 锁定 commit |
|------|------|------|-------------|
| [lualine.nvim](lualine.nvim/) | 状态栏/标签栏 | nvim-lualine | 0a5a668 |
| [bufferline.nvim](bufferline.nvim/) | 缓冲区标签栏 | akinsho | 73540cb |
| [alpha-nvim](alpha-nvim/) | 启动 Dashboard | goolord | 29074ee |
| [neo-tree.nvim](neo-tree.nvim/) | 文件浏览器 | nvim-neo-tree | 5d172e8 |
| [indent-blankline.nvim](indent-blankline.nvim/) | 缩进参考线 | lukas-reineke | 9637670 |
| [hlchunk.nvim](hlchunk.nvim/) | Chunk/缩进高亮 | shellRaining | 5465dd3 |
| [nvim-colorizer.lua](nvim-colorizer.lua/) | 颜色高亮 | norcalli | a065833 |
| [nvim-web-devicons](nvim-web-devicons/) | 文件图标 | nvim-tree | 5b90678 |
| [vim-illuminate](vim-illuminate/) | 单词高亮 | RRethy | e522e0d |
| [lunar.nvim](lunar.nvim/) | LunarVim 主题 | lunarvim | 08bbc93 |

### 通知与消息
| 插件 | 描述 | 作者 | 锁定 commit |
|------|------|------|-------------|
| [nvim-notify](nvim-notify/) | 通知管理器 | rcarriga | 22f2909 |
| [noice.nvim](noice.nvim/) | UI 替换 (消息/命令行/提示) | folke | dbfc5fb |
| [numb.nvim](numb.nvim/) | 行号预览 | nacro90 | 7f564e6 |

### 诊断与任务
| 插件 | 描述 | 作者 | 锁定 commit |
|------|------|------|-------------|
| [trouble.nvim](trouble.nvim/) | 统一诊断列表 | folke | 6f380b8 |
| [none-ls.nvim](none-ls.nvim/) | null-ls fork (格式化/诊断) | nvimtools | 3a48266 |
| [todo-comments.nvim](todo-comments.nvim/) | TODO 注释高亮 | folke | 304a8d2 |

### 终端与工具
| 插件 | 描述 | 作者 | 锁定 commit |
|------|------|------|-------------|
| [toggleterm.nvim](toggleterm.nvim/) | 终端管理 | akinsho | 066cccf |
| [glow.nvim](glow.nvim/) | Markdown 预览 | ellisonleao | 238070a |
| [bigfile.nvim](bigfile.nvim/) | 大文件优化 | lunarvim | 33eb067 |
| [hydra.nvim](hydra.nvim/) | 子模式键映射 | nvimtools | 9838529 |
| [structlog.nvim](structlog.nvim/) | 结构化日志 | Tastyep | 45b26a2 |

## 依赖关系概览

```
核心依赖链：
  plenary.nvim ─┬─ telescope.nvim ── telescope-fzf-native.nvim
                ├─ gitsigns.nvim
                ├─ neo-tree.nvim
                ├─ none-ls.nvim
                └─ 其他多个插件

  nvim-lspconfig ─┬─ mason-lspconfig.nvim ── mason.nvim
                  ├─ cmp-nvim-lsp ── nvim-cmp
                  ├─ nvim-navic
                  ├─ nlsp-settings.nvim
                  └─ neodev.nvim

  nvim-cmp ─┬─ cmp-buffer / cmp-path / cmp-cmdline
            ├─ cmp-nvim-lsp
            ├─ cmp_luasnip ── LuaSnip
            └─ copilot-cmp ── copilot.lua

  nvim-treesitter ─┬─ nvim-ts-context-commentstring
                   └─ rainbow-delimiters.nvim

  nui.nvim ─┬─ noice.nvim
            └─ neo-tree.nvim

  hydra.nvim ── multicursors.nvim
```

## 使用方法

每个插件目录下都有独立的 `CLAUDE.md`，包含该插件的详细信息：
- 项目概述与核心功能
- 目录结构说明
- 核心模块与导出 API
- 配置方式与选项
- 依赖关系
- 构建/测试方法
- 编码规范

编辑插件时，请先阅读对应目录下的 `CLAUDE.md` 了解代码库约定。

## lock.json 格式

```jsonc
{
  "description": "Pinned Neovim plugin sources...",
  "plugins": {
    "<plugin-name>": {
      "owner": "<github-owner>",
      "repo": "<repo-name>",
      "commit": "<40-char-sha>",
      "source": "https://github.com/<owner>/<repo>/archive/<commit>.tar.gz"
    }
  }
}
```

## 编码规范（仓库整体）

- **语言**: Lua 5.1 (LuaJIT) + 少量 Vim script
- **格式化**: 各插件通常使用 stylua (column_width=120, indent_type=Spaces)
- **类型注解**: EmmyLua 风格注解 (`@param`, `@type`, `@return`)
- **模块模式**: 不使用全局变量，每个文件返回局部模块表
- **命名约定**: `snake_case` 用于函数/变量，`PascalCase` 用于类/OOP 模块
- **异步**: 统一使用 `vim.loop` (libuv) 或 plenary.async
