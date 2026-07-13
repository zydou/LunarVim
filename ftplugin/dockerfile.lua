require("lvim.lsp.manager").setup("dockerls", {
  cmd = { "docker-langserver", "--stdio" },
})

local linters = require("lvim.lsp.null-ls.linters")
linters.setup({
  { name = "hadolint" },
})
