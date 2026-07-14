-- local require = require("lvim.utils.require").require
local base_dir = get_lvim_base_dir()
local function plugin_dir(name)
  return join_paths(base_dir, "plugins", name)
end

local core_plugins = {
  { dir = plugin_dir("lazy.nvim") },
  {
    dir = plugin_dir("nvim-lspconfig"),
    lazy = true,
    dependencies = {
      dir = plugin_dir("mason-lspconfig.nvim"),
      dir = plugin_dir("nlsp-settings.nvim"),
    },
  },
  {
    dir = plugin_dir("mason-lspconfig.nvim"),
    cmd = { "LspInstall", "LspUninstall" },
    config = function()
      require("mason-lspconfig").setup(lvim.lsp.installer.setup)

      -- automatic_installation is handled by lsp-manager
      local settings = require("mason-lspconfig.settings")
      settings.current.automatic_installation = false
    end,
    lazy = true,
    event = "User FileOpened",
    dependencies = { dir = plugin_dir("mason.nvim") },
  },
  { dir = plugin_dir("nlsp-settings.nvim"), cmd = "LspSettings", lazy = true },
  { dir = plugin_dir("none-ls.nvim"), lazy = true },
  {
    dir = plugin_dir("mason.nvim"),
    config = function() require("lvim.core.mason").setup() end,
    cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUninstallAll", "MasonLog" },
    build = function()
      pcall(function() require("mason-registry").refresh() end)
    end,
    event = "User FileOpened",
    lazy = true,
  },

  {
    dir = plugin_dir("lunar.nvim"),
    lazy = lvim.colorscheme ~= "lunar",
  },
  { dir = plugin_dir("structlog.nvim"), lazy = true },
  {
    dir = plugin_dir("plenary.nvim"),
    cmd = { "PlenaryBustedFile", "PlenaryBustedDirectory" },
    lazy = true,
  },
  -- Telescope
  {
    dir = plugin_dir("telescope.nvim"),
    branch = "0.1.x",
    config = function() require("lvim.core.telescope").setup() end,
    dependencies = { dir = plugin_dir("telescope-fzf-native.nvim") },
    lazy = true,
    cmd = "Telescope",
    enabled = lvim.builtin.telescope.active,
  },
  {
    dir = plugin_dir("telescope-fzf-native.nvim"),
    build = "make",
    lazy = true,
    enabled = lvim.builtin.telescope.active,
  },
  -- Install nvim-cmp, and buffer source as a dependency
  {
    dir = plugin_dir("nvim-cmp"),
    config = function()
      if lvim.builtin.cmp then require("lvim.core.cmp").setup() end
    end,
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      dir = plugin_dir("cmp-nvim-lsp"),
      dir = plugin_dir("cmp_luasnip"),
      dir = plugin_dir("cmp-buffer"),
      dir = plugin_dir("cmp-path"),
      dir = plugin_dir("cmp-cmdline"),
    },
  },
  { dir = plugin_dir("cmp-nvim-lsp"), lazy = true },
  { dir = plugin_dir("cmp_luasnip"), lazy = true },
  { dir = plugin_dir("cmp-buffer"), lazy = true },
  { dir = plugin_dir("cmp-path"), lazy = true },
  {
    dir = plugin_dir("cmp-cmdline"),
    lazy = true,
    enabled = lvim.builtin.cmp and lvim.builtin.cmp.cmdline.enable or false,
  },
  {
    dir = plugin_dir("LuaSnip"), -- has submodule, do not use mirror url
    config = function()
      local utils = require("lvim.utils")
      local paths = {}
      if lvim.builtin.luasnip.sources.friendly_snippets then paths[#paths + 1] = plugin_dir("friendly-snippets") end
      local user_snippets = utils.join_paths(get_config_dir(), "snippets")
      if utils.is_directory(user_snippets) then paths[#paths + 1] = user_snippets end
      require("luasnip.loaders.from_lua").lazy_load()
      require("luasnip.loaders.from_vscode").lazy_load({
        paths = paths,
      })
      require("luasnip.loaders.from_snipmate").lazy_load()
    end,
    event = "InsertEnter",
    dependencies = {
      dir = plugin_dir("friendly-snippets"),
    },
  },
  {
    dir = plugin_dir("friendly-snippets"),
    lazy = true,
    cond = lvim.builtin.luasnip.sources.friendly_snippets,
  },
  {
    dir = plugin_dir("neodev.nvim"),
    lazy = true,
  },

  -- Autopairs
  {
    dir = plugin_dir("nvim-autopairs"),
    event = "InsertEnter",
    config = function() require("lvim.core.autopairs").setup() end,
    enabled = lvim.builtin.autopairs.active,
    dependencies = {
      dir = plugin_dir("nvim-treesitter"),
      dir = plugin_dir("nvim-cmp"),
    },
  },

  -- Treesitter
  {
    dir = plugin_dir("nvim-treesitter"),
    -- run = ":TSUpdate",
    config = function()
      local utils = require("lvim.utils")
      local path = plugin_dir("nvim-treesitter")
      vim.opt.rtp:prepend(path) -- treesitter needs to be before nvim's runtime in rtp
      require("lvim.core.treesitter").setup()
    end,
    cmd = {
      "TSInstall",
      "TSUninstall",
      "TSUpdate",
      "TSUpdateSync",
      "TSInstallInfo",
      "TSInstallSync",
      "TSInstallFromGrammar",
    },
    event = "User FileOpened",
  },
  {
    -- Lazy loaded by Comment.nvim pre_hook
    dir = plugin_dir("nvim-ts-context-commentstring"),
    lazy = true,
  },

  {
    dir = plugin_dir("gitsigns.nvim"),
    config = function() require("lvim.core.gitsigns").setup() end,
    event = "User FileOpened",
    cmd = "Gitsigns",
    enabled = lvim.builtin.gitsigns.active,
  },

  -- Whichkey
  {
    dir = plugin_dir("which-key.nvim"),
    config = function() require("lvim.core.which-key").setup() end,
    cmd = "WhichKey",
    event = "VeryLazy",
    enabled = lvim.builtin.which_key.active,
  },

  -- Comments
  {
    dir = plugin_dir("Comment.nvim"),
    config = function() require("lvim.core.comment").setup() end,
    keys = { { "gc", mode = { "n", "v" } }, { "gb", mode = { "n", "v" } } },
    event = "User FileOpened",
    enabled = lvim.builtin.comment.active,
  },

  -- Icons
  {
    dir = plugin_dir("nvim-web-devicons"),
    enabled = lvim.use_icons,
    lazy = true,
  },

  -- Status Line and Bufferline
  {
    -- "hoob3rt/lualine.nvim",
    dir = plugin_dir("lualine.nvim"),
    -- "Lunarvim/lualine.nvim",
    config = function() require("lvim.core.lualine").setup() end,
    event = "VimEnter",
    enabled = lvim.builtin.lualine.active,
  },

  -- breadcrumbs
  {
    dir = plugin_dir("nvim-navic"),
    config = function() require("lvim.core.breadcrumbs").setup() end,
    event = "User FileOpened",
    enabled = lvim.builtin.breadcrumbs.active,
  },

  {
    dir = plugin_dir("bufferline.nvim"),
    config = function() require("lvim.core.bufferline").setup() end,
    branch = "main",
    event = "User FileOpened",
    enabled = lvim.builtin.bufferline.active,
  },

  -- alpha
  {
    dir = plugin_dir("alpha-nvim"),
    config = function() require("lvim.core.alpha").setup() end,
    enabled = lvim.builtin.alpha.active,
    event = "VimEnter",
  },

  -- Terminal
  {
    dir = plugin_dir("toggleterm.nvim"),
    branch = "main",
    init = function() require("lvim.core.terminal").init() end,
    config = function() require("lvim.core.terminal").setup() end,
    cmd = {
      "ToggleTerm",
      "TermExec",
      "ToggleTermToggleAll",
      "ToggleTermSendCurrentLine",
      "ToggleTermSendVisualLines",
      "ToggleTermSendVisualSelection",
    },
    keys = lvim.builtin.terminal.open_mapping,
    enabled = lvim.builtin.terminal.active,
  },

  -- SchemaStore
  {
    dir = plugin_dir("schemastore.nvim"),
    lazy = true,
  },

  {
    dir = plugin_dir("vim-illuminate"),
    config = function() require("lvim.core.illuminate").setup() end,
    event = "User FileOpened",
    enabled = lvim.builtin.illuminate.active,
  },

  {
    dir = plugin_dir("indent-blankline.nvim"),
    config = function() require("lvim.core.indentlines").setup() end,
    event = "User FileOpened",
    enabled = lvim.builtin.indentlines.active,
  },

  {
    dir = plugin_dir("bigfile.nvim"),
    config = function()
      pcall(function() require("bigfile").setup(lvim.builtin.bigfile.config) end)
    end,
    enabled = lvim.builtin.bigfile.active,
    dependencies = { dir = plugin_dir("nvim-treesitter") },
    event = { "FileReadPre", "BufReadPre", "User FileOpened" },
  },
  { -- pick up where you left off
    dir = plugin_dir("nvim-lastplace"),
    event = "BufRead",
    config = function()
      require("nvim-lastplace").setup({
        lastplace_ignore_buftype = { "quickfix", "nofile", "help" },
        lastplace_ignore_filetype = { "commit", "gitrebase", "svn", "hgcommit" },
        lastplace_open_folds = true,
      })
    end,
  },
  { -- pretty list for diagnostics, references, telescope results, quickfix and location lists
    dir = plugin_dir("trouble.nvim"),
    cmd = "Trouble",
    opts = {},
  },
  { -- highlight TODO, FIXME, etc.
    dir = plugin_dir("todo-comments.nvim"),
    dependencies = { dir = plugin_dir("plenary.nvim") },
    opts = {},
  },
  {
    dir = plugin_dir("noice.nvim"),
    event = "VeryLazy",
    opts = {},
    dependencies = {
      dir = plugin_dir("nui.nvim"),
      dir = plugin_dir("nvim-notify"),
    },
    config = function()
      require("noice").setup({
        lsp = {
          -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
          },
        },
        routes = {
          {
            filter = {
              event = "msg_show",
              kind = "",
              find = "written", -- hide written messages
            },
            opts = { skip = true },
          },
        },
        -- you can enable a preset for easier configuration
        presets = {
          bottom_search = true, -- use a classic bottom cmdline for search
          command_palette = true, -- position the cmdline and popupmenu together
          long_message_to_split = true, -- long messages will be sent to a split
          inc_rename = false, -- enables an input dialog for inc-rename.nvim
          lsp_doc_border = true, -- add a border to hover docs and signature help
        },
      })
    end,
  },
  { -- motion on speed
    dir = plugin_dir("hop.nvim"),
    event = "BufRead",
    opts = { keys = "etovxqpdygfblzhckisuran" },
    config = function()
      require("hop").setup()
      vim.api.nvim_set_keymap("n", "t", ":HopChar1CurrentLine<cr>", { silent = true })
      vim.api.nvim_set_keymap("n", "f", ":HopWord<cr>", { silent = true })
      vim.api.nvim_set_keymap("n", "F", ":HopWordAC<cr>", { silent = true })
      vim.api.nvim_set_keymap("n", "S", ":HopLine<cr>", { silent = true })
    end,
  },
  { -- file explorer
    dir = plugin_dir("neo-tree.nvim"),
    dependencies = {
      dir = plugin_dir("plenary.nvim"),
      dir = plugin_dir("nvim-web-devicons"),
      dir = plugin_dir("nui.nvim"),
    },
    config = function()
      require("neo-tree").setup({
        sources = { "filesystem", "document_symbols", "git_status" },
        close_if_last_window = true,
        filesystem = {
          hijack_netrw_behavior = "open_current",
          filtered_items = {
            force_visible_in_empty_folder = true,
            hide_dotfiles = false,
            hide_gitignored = false,
            hide_by_name = { "node_modules", ".venv" },
            always_show = { ".github", ".devcontainer", ".in", ".out" },
            never_show = { ".DS_Store", "thumbs.db" },
          },
        },
        document_symbols = { follow_cursor = true },
        window = { width = 42 },
        source_selector = {
          winbar = true,
          statusline = true,
          sources = {
            { source = "filesystem" },
            { source = "git_status" },
            { source = "document_symbols" },
          },
        },
        default_component_configs = {
          icon = {
            folder_closed = lvim.icons.ui.Folder,
            folder_open = lvim.icons.ui.FolderOpen,
            folder_empty = lvim.icons.ui.EmptyFolder,
            default = lvim.icons.ui.File,
            highlight = "NeoTreeFileIcon",
          },
          modified = { symbol = lvim.icons.git.LineModified, highlight = "NeoTreeModified" },
          symlink_target = { enabled = true },
          git_status = {
            symbols = {
              added = lvim.icons.git.LineAdded,
              modified = lvim.icons.git.LineModified,
              deleted = lvim.icons.git.FileDeleted,
              renamed = lvim.icons.git.FileRenamed,
              ignored = lvim.icons.git.FileIgnored,
              conflict = lvim.icons.git.FileUnmerged,
              untracked = "",
              unstaged = "󰄱",
              staged = "",
            },
          },
          file_size = { enabled = true, required_width = 40 },  -- min width of window required
        },
      })
    end,
  },
  { -- markdown preview
    dir = plugin_dir("glow.nvim"),
    config = function()
      require("glow").setup({
        border = "shadow",
        pager = false,
        width = 180,
        height = 120,
        width_ratio = 0.8,
        height_ratio = 0.9,
      })
    end,
  },
  { -- jump to line number
    dir = plugin_dir("numb.nvim"),
    event = "BufRead",
    config = function()
      require("numb").setup({ show_numbers = true, show_cursorline = true })
    end,
  },
  { -- highlight matching words
    dir = plugin_dir("vim-matchup"),
    config = function() vim.g.matchup_matchparen_offscreen = { method = "popup" } end,
  },
  { -- multi-cursor
    dir = plugin_dir("multicursors.nvim"),
    event = "VeryLazy",
    dependencies = { dir = plugin_dir("hydra.nvim") },
    opts = {
      hint_config = { float_opts = { border = "none" }, position = "bottom-right" },
      generate_hints = {
        normal = true, insert = true, extend = true,
        config = { column_count = 1 },
      },
    },
    cmd = { "MCstart", "MCvisual", "MCclear", "MCpattern", "MCvisualPattern", "MCunderCursor" },
    keys = {
      { mode = { "v", "n" }, "<Leader>m", "<cmd>MCstart<cr>", desc = "Create a selection for selected text or word under the cursor" },
    },
  },
  { -- colorizer
    dir = plugin_dir("nvim-colorizer.lua"),
    config = function()
      require("colorizer").setup({ "*" }, {
        RGB = true, RRGGBB = true, RRGGBBAA = true, names = true,
        rgb_fn = true, hsl_fn = true, css = true, css_fn = true,
      })
    end,
  },
  { -- rainbow parentheses
    dir = plugin_dir("rainbow-delimiters.nvim"),
  },
  { -- surround delimiter pairs
    dir = plugin_dir("nvim-surround"),
    event = "VeryLazy",
    config = function() require("nvim-surround").setup({}) end,
  },
  { -- highlight code chunks and indent lines
    dir = plugin_dir("hlchunk.nvim"),
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("hlchunk").setup({
        chunk = {
          enable = true,
          use_treesitter = true,
          chars = { horizontal_line = "─", vertical_line = "│", left_top = "╭", left_bottom = "╰", right_arrow = ">" },
          style = { "#0ba1e0", "#c21f30" },
        },
      })
    end,
  },
}

return core_plugins
