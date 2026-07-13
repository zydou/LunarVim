local linters = require("lvim.lsp.null-ls.linters")
linters.setup({
  { name = "gitlint", env = { GITLINT_CONFIG = vim.fn.expand("~/.config/gitlint/config.ini") } },
})
