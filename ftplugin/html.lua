require("lvim.lsp.manager").setup("tailwindcss", {
  cmd = { "tailwindcss-language-server", "--stdio" },
})

require("lvim.lsp.manager").setup("html", {
  cmd = { "vscode-html-language-server", "--stdio" },
})
