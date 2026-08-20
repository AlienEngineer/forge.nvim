local lsp = require("forge.lsp")

local M = {}

-- <prefix>mf : move current class or type to its own file through the LSP.
function M.run()
  local filter = function(action)
    local title = (action.title or ""):lower()
    return title:find("move", 1, true) ~= nil and title:find("file", 1, true) ~= nil
  end

  lsp.try_code_action(filter, function()
    vim.lsp.buf.code_action({ filter = filter })
  end)
end

return M
