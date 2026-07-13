require("lvim.lsp.manager").setup("bashls", {
  cmd = { "bash-language-server", "start" },
})

local code_actions = require("lvim.lsp.null-ls.code_actions")
code_actions.setup({
  { name = "shellcheck" },
})

local linters = require("lvim.lsp.null-ls.linters")
linters.setup({
  { name = "shellcheck" },
})

local formatters = require("lvim.lsp.null-ls.formatters")
formatters.setup({
  { name = "shfmt", extra_args = { "--indent", "4", "--case-indent", "--space-redirects", "--binary-next-line" } },
})
