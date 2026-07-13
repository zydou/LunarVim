local util = require 'lspconfig.util'

local bin_name = 'ty'
local cmd = { bin_name, 'server' }

return {
  default_config = {
    cmd = cmd,
    filetypes = { 'python' },
    root_dir = function(fname)
      local root_files = { 'pyproject.toml', 'requirements.txt', 'uv.lock' }
      return util.root_pattern(unpack(root_files))(fname) or util.find_git_ancestor(fname)
    end,
    single_file_support = true,
  },
  docs = {
    description = [[
https://github.com/astral-sh/ty

An extremely fast Python type checker and language server, written in Rust.
]],
    default_config = {
      root_dir = [[root_pattern(".git", "pyproject.toml", "uv.lock")]],
    },
  },
}
