local M = {}

local Log = require("lvim.core.log")

function M.run_pre_reload() Log:debug("Starting pre-reload hook") end

function M.run_post_reload() Log:debug("Starting post-reload hook") end

---Reset any startup cache files used by lazy.nvim
---NOTE: ftplugin files are now pre-generated in ./ftplugin and checked into
---the repo, so this no longer regenerates live templates.
---Tip: Useful for clearing any outdated settings
function M.reset_cache()
  local lvim_modules = {}
  for module, _ in pairs(package.loaded) do
    if module:match("lvim.core") or module:match("lvim.lsp") then
      package.loaded[module] = nil
      table.insert(lvim_modules, module)
    end
  end
  Log:trace(string.format("Cache invalidated for core modules: { %s }", table.concat(lvim_modules, ", ")))
end

return M
