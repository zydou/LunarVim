require("lvim.lsp.manager").setup("ryl", {
  cmd = { "ryl", "server" },
})

local linters = require("lvim.lsp.null-ls.linters")
linters.setup({
  { command = "actionlint" },
})

require("lvim.lsp.null-ls.formatters").setup({
  { name = "ryl_format", extra_args = { "--config-file", vim.fn.expand("~/.config/ryl/ryl.toml") } },
})
