local M = {}

-- Ask the server for an "implement/override/add missing" code action at the
-- cursor and auto-apply it when there is a single match.
function M.implement_action(filter)
  vim.lsp.buf.code_action({ apply = true, filter = filter })
end

return M
