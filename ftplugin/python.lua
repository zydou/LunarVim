require("lvim.lsp.manager").setup("ty", {
  cmd = { "ty", "server" },
})

require("lvim.lsp.manager").setup("ruff", {
  cmd = { "ruff", "server" },
})


require("lvim.lsp.null-ls.formatters").setup({
  { name = "ruff" },
  { name = "ruff_format" },
})
