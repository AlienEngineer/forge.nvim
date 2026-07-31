local M = {}

-- <prefix>ev : extract selected expression (or expression under cursor) to a
-- local variable. Works in normal and visual modes.
-- Delegates to the LSP "extract variable / local" refactoring.
function M.run()
  vim.lsp.buf.code_action({
    filter = function(action)
      local t = (action.title or ""):lower()
      return t:find("extract") ~= nil
        and (
          t:find("variable") ~= nil
          or t:find("local") ~= nil
          or t:find("const") ~= nil
          or t:find("let") ~= nil
          or t:find("field") ~= nil
        )
    end,
  })
end

return M
