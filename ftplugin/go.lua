-- AUTO-GENERATED from mason-lspconfig's filetype mapping
-- (plugins/mason-lspconfig.nvim/lua/mason-lspconfig/mappings/filetype.lua).
-- COMPLETE SET — no server/filetype filtering applied.
-- Supersedes the runtime ftplugin files that
-- lua/lvim/lsp/templates.lua generated into
-- $LUNARVIM_RUNTIME_DIR/site/after/ftplugin/ at boot.
-- MANUAL EDITS WILL BE LOST on re-generation.

-- filetype: go
-- server(s): ast_grep, golangci_lint_ls, gopls, snyk_ls

-- NOTE: multiple servers manage this filetype; all are attempted
local mgr_ok, mgr = pcall(require, "lvim.lsp.manager")
if mgr_ok then
  pcall(function() mgr.setup('ast_grep') end)
  pcall(function() mgr.setup('golangci_lint_ls') end)
  pcall(function() mgr.setup('gopls') end)
  pcall(function() mgr.setup('snyk_ls') end)
end
