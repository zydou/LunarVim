require("lvim.lsp.manager").setup("jsonls", {
  cmd = { "vscode-json-language-server", "--stdio" },
})

local linters = require("lvim.lsp.null-ls.linters")
linters.setup({
  {
    name = "jsonlint",
    filetypes = { "json" },
    extra_args = { "--comments", "--no-duplicate-keys" },
  },
})

local formatters = require("lvim.lsp.null-ls.formatters")
formatters.setup({
  {
    name = "prettier",
    filetypes = { "json" },
    extra_args = { "--config", vim.fn.expand("~/.config/prettier/.prettierrc.json") },
  },
})
