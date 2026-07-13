local util = require 'lspconfig.util'

local bin_name = 'rumdl'
local cmd = { bin_name, 'server' }

return {
  default_config = {
    cmd = cmd,
    filetypes = { 'markdown' },
    root_dir = function(fname)
      local root_files = { '.rumdl.toml' }
      return util.root_pattern(unpack(root_files))(fname) or util.find_git_ancestor(fname)
    end,
    single_file_support = true,
  },
  docs = {
    description = [[
https://github.com/rvben/rumdl

rumdl is a modern Markdown linter and formatter, built for speed with Rust.
]],
    default_config = {
      root_dir = [[root_pattern(".git", ".rumdl.toml")]],
    },
  },
}
