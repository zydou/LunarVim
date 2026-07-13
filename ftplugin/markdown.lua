require("lvim.lsp.manager").setup("rumdl", {
  cmd = { "rumdl", "server" },
})

require("lvim.lsp.null-ls.formatters").setup({
  { name = "rumdl_format", extra_args = { "--config", vim.fn.expand("~/.config/rumdl/rumdl.toml") } }
})
