local util = require 'lspconfig.util'

local bin_name = 'ryl'
local cmd = { bin_name, 'server' }

return {
  default_config = {
    cmd = cmd,
    filetypes = { 'yaml' },
    root_dir = function(fname)
      local root_files = { 'pyproject.toml', '.ryl.toml', 'ryl.toml' }
      return util.root_pattern(unpack(root_files))(fname) or util.find_git_ancestor(fname)
    end,
    single_file_support = true,
  },
  docs = {
    description = [[
https://github.com/owenlamont/ryl

Fast YAML linter written in Rust
]],
    default_config = {
      root_dir = [[root_pattern(".git", "pyproject.toml", "ryl.toml", ".ryl.toml")]],
    },
  },
}
