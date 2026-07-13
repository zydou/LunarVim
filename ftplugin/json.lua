-- AUTO-GENERATED from mason-lspconfig's filetype mapping
-- (plugins/mason-lspconfig.nvim/lua/mason-lspconfig/mappings/filetype.lua).
-- COMPLETE SET — no server/filetype filtering applied.
-- Supersedes the runtime ftplugin files that
-- lua/lvim/lsp/templates.lua generated into
-- $LUNARVIM_RUNTIME_DIR/site/after/ftplugin/ at boot.
-- MANUAL EDITS WILL BE LOST on re-generation.

-- filetype: json
-- server(s): biome, dprint, jsonls, rome, snyk_ls, spectral

-- NOTE: multiple servers manage this filetype; all are attempted
local mgr_ok, mgr = pcall(require, "lvim.lsp.manager")
if mgr_ok then
  pcall(function() mgr.setup('biome') end)
  pcall(function() mgr.setup('dprint') end)
  pcall(function() mgr.setup('jsonls') end)
  pcall(function() mgr.setup('rome') end)
  pcall(function() mgr.setup('snyk_ls') end)
  pcall(function() mgr.setup('spectral') end)
end
