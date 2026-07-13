-- AUTO-GENERATED from mason-lspconfig's filetype mapping
-- (plugins/mason-lspconfig.nvim/lua/mason-lspconfig/mappings/filetype.lua).
-- COMPLETE SET — no server/filetype filtering applied.
-- Supersedes the runtime ftplugin files that
-- lua/lvim/lsp/templates.lua generated into
-- $LUNARVIM_RUNTIME_DIR/site/after/ftplugin/ at boot.
-- MANUAL EDITS WILL BE LOST on re-generation.

-- filetype: typescript.tsx
-- server(s): angularls, biome, denols, eslint, rome, tsserver, vtsls

-- NOTE: multiple servers manage this filetype; all are attempted
local mgr_ok, mgr = pcall(require, "lvim.lsp.manager")
if mgr_ok then
  pcall(function() mgr.setup('angularls') end)
  pcall(function() mgr.setup('biome') end)
  pcall(function() mgr.setup('denols') end)
  pcall(function() mgr.setup('eslint') end)
  pcall(function() mgr.setup('rome') end)
  pcall(function() mgr.setup('tsserver') end)
  pcall(function() mgr.setup('vtsls') end)
end
