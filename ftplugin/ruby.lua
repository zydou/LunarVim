-- AUTO-GENERATED from mason-lspconfig's filetype mapping
-- (plugins/mason-lspconfig.nvim/lua/mason-lspconfig/mappings/filetype.lua).
-- COMPLETE SET — no server/filetype filtering applied.
-- Supersedes the runtime ftplugin files that
-- lua/lvim/lsp/templates.lua generated into
-- $LUNARVIM_RUNTIME_DIR/site/after/ftplugin/ at boot.
-- MANUAL EDITS WILL BE LOST on re-generation.

-- filetype: ruby
-- server(s): rubocop, ruby_lsp, solargraph, sorbet, standardrb, stimulus_ls

-- NOTE: multiple servers manage this filetype; all are attempted
local mgr_ok, mgr = pcall(require, "lvim.lsp.manager")
if mgr_ok then
  pcall(function() mgr.setup('rubocop') end)
  pcall(function() mgr.setup('ruby_lsp') end)
  pcall(function() mgr.setup('solargraph') end)
  pcall(function() mgr.setup('sorbet') end)
  pcall(function() mgr.setup('standardrb') end)
  pcall(function() mgr.setup('stimulus_ls') end)
end
