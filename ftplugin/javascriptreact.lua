require("lvim.lsp.manager").setup("tailwindcss", {
  cmd = { "tailwindcss-language-server", "--stdio" },
})

require("lvim.lsp.manager").setup("tsserver", {
  cmd = { "typescript-language-server", "--stdio" },
})
