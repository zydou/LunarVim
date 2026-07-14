local plugin_loader = {}

local utils = require("lvim.utils")
local Log = require("lvim.core.log")
local join_paths = utils.join_paths

local plugins_dir = join_paths(get_lvim_base_dir(), "plugins")

function plugin_loader.init(opts)
  opts = opts or {}

  local lazy_install_dir = opts.install_path or join_paths(get_lvim_base_dir(), "plugins", "lazy.nvim")

  local rtp = vim.opt.rtp:get()
  local base_dir = (vim.env.LUNARVIM_BASE_DIR or get_runtime_dir() .. "/lvim"):gsub("\\", "/")
  local idx_base = #rtp + 1
  for i, path in ipairs(rtp) do
    path = path:gsub("\\", "/")
    if path == base_dir then
      idx_base = i + 1
      break
    end
  end
  table.insert(rtp, idx_base, lazy_install_dir)
  table.insert(rtp, idx_base + 1, join_paths(plugins_dir, "*"))
  vim.opt.rtp = rtp

  pcall(function()
    -- set a custom path for lazy's cache
    local lazy_cache = require("lazy.core.cache")
    lazy_cache.path = join_paths(get_cache_dir(), "lazy", "luac")
  end)
end

function plugin_loader.reload(spec)
  local Config = require("lazy.core.config")

  Config.spec = spec

  require("lazy.core.plugin").load(true)
  require("lazy.core.plugin").update_state()

  require("lazy.manage").clear()
end

function plugin_loader.load(configurations)
  Log:debug("loading plugins configuration")
  local lazy_available, lazy = pcall(require, "lazy")
  if not lazy_available then
    Log:warn("skipping loading plugins until lazy.nvim is installed")
    return
  end

  -- remove plugins from rtp before loading lazy, so that all plugins won't be loaded on startup
  vim.opt.runtimepath:remove(join_paths(plugins_dir, "*"))

  local status_ok = xpcall(function()
    table.insert(lvim.lazy.opts.install.colorscheme, 1, lvim.colorscheme)
    lazy.setup(configurations, lvim.lazy.opts)
  end, debug.traceback)

  if not status_ok then
    Log:warn("problems detected while loading plugins' configurations")
    Log:trace(debug.traceback())
  end
end

return plugin_loader
