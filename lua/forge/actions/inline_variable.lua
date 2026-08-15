local M = {}

-- <prefix>vi : inline the local variable on the current line.
-- Delegates entirely to the language server's "inline variable" refactoring.
-- Position the cursor on the variable declaration line before invoking.
function M.run()
  vim.lsp.buf.code_action({
    apply = true,
    filter = function(action)
      local t = (action.title or ""):lower()
      return t:find("inline") ~= nil and (t:find("variable") ~= nil or t:find("local") ~= nil or t:find("field") ~= nil)
    end,
  })
end

return M
