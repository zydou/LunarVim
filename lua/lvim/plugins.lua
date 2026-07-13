-- local require = require("lvim.utils.require").require
local core_plugins = {
  { dir = "~/.local/share/lunarvim/site/pack/lazy/opt/lazy.nvim" },
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nvim-lspconfig",
    lazy = true,
    dependencies = {
      dir = "~/.local/share/lunarvim/site/pack/lazy/opt/mason-lspconfig.nvim",
      dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nlsp-settings.nvim",
    },
  },
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/mason-lspconfig.nvim",
    cmd = { "LspInstall", "LspUninstall" },
    config = function()
      require("mason-lspconfig").setup(lvim.lsp.installer.setup)

      -- automatic_installation is handled by lsp-manager
      local settings = require("mason-lspconfig.settings")
      settings.current.automatic_installation = false
    end,
    lazy = true,
    event = "User FileOpened",
    dependencies = { dir = "~/.local/share/lunarvim/site/pack/lazy/opt/mason.nvim" },
  },
  { dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nlsp-settings.nvim", cmd = "LspSettings", lazy = true },
  { dir = "~/.local/share/lunarvim/site/pack/lazy/opt/none-ls.nvim", lazy = true },
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/mason.nvim",
    config = function() require("lvim.core.mason").setup() end,
    cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUninstallAll", "MasonLog" },
    build = function()
      pcall(function() require("mason-registry").refresh() end)
    end,
    event = "User FileOpened",
    lazy = true,
  },

  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/lunar.nvim",
    lazy = lvim.colorscheme ~= "lunar",
  },
  { dir = "~/.local/share/lunarvim/site/pack/lazy/opt/structlog.nvim", lazy = true },
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/plenary.nvim",
    cmd = { "PlenaryBustedFile", "PlenaryBustedDirectory" },
    lazy = true,
  },
  -- Telescope
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/telescope.nvim",
    branch = "0.1.x",
    config = function() require("lvim.core.telescope").setup() end,
    dependencies = { dir = "~/.local/share/lunarvim/site/pack/lazy/opt/telescope-fzf-native.nvim" },
    lazy = true,
    cmd = "Telescope",
    enabled = lvim.builtin.telescope.active,
  },
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/telescope-fzf-native.nvim",
    build = "make",
    lazy = true,
    enabled = lvim.builtin.telescope.active,
  },
  -- Install nvim-cmp, and buffer source as a dependency
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nvim-cmp",
    config = function()
      if lvim.builtin.cmp then require("lvim.core.cmp").setup() end
    end,
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      dir = "~/.local/share/lunarvim/site/pack/lazy/opt/cmp-nvim-lsp",
      dir = "~/.local/share/lunarvim/site/pack/lazy/opt/cmp_luasnip",
      dir = "~/.local/share/lunarvim/site/pack/lazy/opt/cmp-buffer",
      dir = "~/.local/share/lunarvim/site/pack/lazy/opt/cmp-path",
      dir = "~/.local/share/lunarvim/site/pack/lazy/opt/cmp-cmdline",
    },
  },
  { dir = "~/.local/share/lunarvim/site/pack/lazy/opt/cmp-nvim-lsp", lazy = true },
  { dir = "~/.local/share/lunarvim/site/pack/lazy/opt/cmp_luasnip", lazy = true },
  { dir = "~/.local/share/lunarvim/site/pack/lazy/opt/cmp-buffer", lazy = true },
  { dir = "~/.local/share/lunarvim/site/pack/lazy/opt/cmp-path", lazy = true },
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/cmp-cmdline",
    lazy = true,
    enabled = lvim.builtin.cmp and lvim.builtin.cmp.cmdline.enable or false,
  },
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/LuaSnip", -- has submodule, do not use mirror url
    config = function()
      local utils = require("lvim.utils")
      local paths = {}
      if lvim.builtin.luasnip.sources.friendly_snippets then paths[#paths + 1] = utils.join_paths(get_runtime_dir(), "site", "pack", "lazy", "opt", "friendly-snippets") end
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
      dir = "~/.local/share/lunarvim/site/pack/lazy/opt/friendly-snippets",
    },
  },
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/friendly-snippets",
    lazy = true,
    cond = lvim.builtin.luasnip.sources.friendly_snippets,
  },
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/neodev.nvim",
    lazy = true,
  },

  -- Autopairs
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nvim-autopairs",
    event = "InsertEnter",
    config = function() require("lvim.core.autopairs").setup() end,
    enabled = lvim.builtin.autopairs.active,
    dependencies = {
      dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nvim-treesitter",
      dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nvim-cmp",
    },
  },

  -- Treesitter
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nvim-treesitter",
    -- run = ":TSUpdate",
    config = function()
      local utils = require("lvim.utils")
      local path = utils.join_paths(get_runtime_dir(), "site", "pack", "lazy", "opt", "nvim-treesitter")
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
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nvim-ts-context-commentstring",
    lazy = true,
  },

  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/gitsigns.nvim",
    config = function() require("lvim.core.gitsigns").setup() end,
    event = "User FileOpened",
    cmd = "Gitsigns",
    enabled = lvim.builtin.gitsigns.active,
  },

  -- Whichkey
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/which-key.nvim",
    config = function() require("lvim.core.which-key").setup() end,
    cmd = "WhichKey",
    event = "VeryLazy",
    enabled = lvim.builtin.which_key.active,
  },

  -- Comments
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/Comment.nvim",
    config = function() require("lvim.core.comment").setup() end,
    keys = { { "gc", mode = { "n", "v" } }, { "gb", mode = { "n", "v" } } },
    event = "User FileOpened",
    enabled = lvim.builtin.comment.active,
  },

  -- Icons
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nvim-web-devicons",
    enabled = lvim.use_icons,
    lazy = true,
  },

  -- Status Line and Bufferline
  {
    -- "hoob3rt/lualine.nvim",
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/lualine.nvim",
    -- "Lunarvim/lualine.nvim",
    config = function() require("lvim.core.lualine").setup() end,
    event = "VimEnter",
    enabled = lvim.builtin.lualine.active,
  },

  -- breadcrumbs
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nvim-navic",
    config = function() require("lvim.core.breadcrumbs").setup() end,
    event = "User FileOpened",
    enabled = lvim.builtin.breadcrumbs.active,
  },

  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/bufferline.nvim",
    config = function() require("lvim.core.bufferline").setup() end,
    branch = "main",
    event = "User FileOpened",
    enabled = lvim.builtin.bufferline.active,
  },

  -- alpha
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/alpha-nvim",
    config = function() require("lvim.core.alpha").setup() end,
    enabled = lvim.builtin.alpha.active,
    event = "VimEnter",
  },

  -- Terminal
  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/toggleterm.nvim",
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
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/schemastore.nvim",
    lazy = true,
  },

  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/vim-illuminate",
    config = function() require("lvim.core.illuminate").setup() end,
    event = "User FileOpened",
    enabled = lvim.builtin.illuminate.active,
  },

  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/indent-blankline.nvim",
    config = function() require("lvim.core.indentlines").setup() end,
    event = "User FileOpened",
    enabled = lvim.builtin.indentlines.active,
  },

  {
    dir = "~/.local/share/lunarvim/site/pack/lazy/opt/bigfile.nvim",
    config = function()
      pcall(function() require("bigfile").setup(lvim.builtin.bigfile.config) end)
    end,
    enabled = lvim.builtin.bigfile.active,
    dependencies = { dir = "~/.local/share/lunarvim/site/pack/lazy/opt/nvim-treesitter" },
    event = { "FileReadPre", "BufReadPre", "User FileOpened" },
  },
}
--- NOTE: get_short_name / get_default_sha1 / commit-locking logic removed.
--- All core plugins are installed locally via `dir =` (offline, no git),
--- so the git-commit-locking code path is dead and caused crashes when
--- LVIM_DEV_MODE was unset (e.g. headless invocations from build scripts).

-- local default_snapshot_path = join_paths(get_lvim_base_dir(), "snapshots", "default.json")
-- local content = vim.fn.readfile(default_snapshot_path)
-- local default_sha1 = assert(vim.fn.json_decode(content))

-- -- taken from <https://github.com/folke/lazy.nvim/blob/c7122d64cdf16766433588486adcee67571de6d0/lua/lazy/core/plugin.lua#L27>
-- local get_short_name = function(long_name)
--   local name = long_name:sub(-4) == ".git" and long_name:sub(1, -5) or long_name
--   local slash = name:reverse():find("/", 1, true) --[[@as number?]]
--   return slash and name:sub(#name - slash + 2) or long_name:gsub("%W+", "_")
-- end

-- local get_default_sha1 = function(spec)
--   local short_name = get_short_name(spec.url)
--   return default_sha1[short_name] and default_sha1[short_name].commit
-- end

-- if not vim.env.LVIM_DEV_MODE then
--   --  Manually lock the commit hashes of core plugins
--   for _, spec in ipairs(core_plugins) do
--     spec["commit"] = get_default_sha1(spec)
--   end
-- end

return core_plugins
