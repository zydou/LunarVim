require("lvim.lsp.manager").setup("taplo", {
  cmd = { "taplo", "lsp", "stdio" },
})

local formatters = require("lvim.lsp.null-ls.formatters")
formatters.setup({
  { name = "taplo", extra_args = { "--config", vim.fn.expand("~/.config/taplo/taplo.toml") } },
})
