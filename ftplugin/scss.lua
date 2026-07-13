require("lvim.lsp.manager").setup("tailwindcss", {
  cmd = { "tailwindcss-language-server", "--stdio" },
})

require("lvim.lsp.manager").setup("cssls", {
  cmd = { "vscode-css-language-server", "--stdio" },
})
