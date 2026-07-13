require("lvim.lsp.manager").setup("lua_ls", {
  cmd = { "lua-language-server" },
})

require("lvim.lsp.null-ls.formatters").setup({
  { name = "stylua", extra_args = { "--config-path", vim.fn.expand("~/.config/stylua/stylua.toml") } },
})
