local M = {}

local Log = require("lvim.core.log")
local if_nil = vim.F.if_nil

local function git_cmd(opts)
  local plenary_loaded, Job = pcall(require, "plenary.job")
  if not plenary_loaded then return 1, { "" } end

  opts = opts or {}
  opts.cwd = opts.cwd or get_lvim_base_dir()

  local stderr = {}
  local stdout, ret = Job:new({
    command = "git",
    args = opts.args,
    cwd = opts.cwd,
    on_stderr = function(_, data) table.insert(stderr, data) end,
  }):sync(10000)

  if not vim.tbl_isempty(stderr) then Log:debug(stderr) end

  if not vim.tbl_isempty(stdout) then Log:debug(stdout) end

  return ret, stdout, stderr
end

---Get the current Lunarvim development branch
---@return string|nil
function M.get_lvim_branch()
  local _, results = git_cmd({ args = { "rev-parse", "--abbrev-ref", "HEAD" } })
  local branch = if_nil(results[1], "")
  return branch
end

---Get currently checked-out tag of Lunarvim
---@return string
function M.get_lvim_tag()
  local args = { "describe", "--tags", "--abbrev=0" }

  local _, results = git_cmd({ args = args })
  local tag = if_nil(results[1], "")
  return tag
end

---Get the description of currently checked-out commit of Lunarvim
---@return string|nil
function M.get_lvim_description()
  local _, results = git_cmd({ args = { "describe", "--dirty", "--always" } })

  local description = if_nil(results[1], M.get_lvim_branch())
  return description
end

---Get currently running version of Lunarvim
---@return string
function M.get_lvim_version()
  local current_branch = M.get_lvim_branch()

  local lvim_version
  if current_branch ~= "HEAD" or "" then
    lvim_version = current_branch .. "-" .. M.get_lvim_description()
  else
    lvim_version = "v" .. M.get_lvim_tag()
  end
  return lvim_version
end

return M
