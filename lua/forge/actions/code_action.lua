local M = {}

-- <prefix>a : thin passthrough to LSP code actions. With telescope-ui-select
-- installed this menu becomes a fuzzy picker for free.
function M.run()
  vim.lsp.buf.code_action()
end

return M
