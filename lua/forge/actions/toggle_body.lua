local config = require("forge.config")
local ts = require("forge.ts")

local M = {}

local function method_text(bufnr, method_node)
  local srow, _, erow, _ = method_node:range()
  return vim.api.nvim_buf_get_lines(bufnr, srow, erow + 1, false)
end

local function current_method_kind(bufnr, method_node)
  local lines = method_text(bufnr, method_node)
  local text = table.concat(lines, "\n")
  if text:find("=>", 1, true) then
    return "expression"
  end
  if #lines > 0 then
    return "block"
  end
  return nil
end

-- <prefix>b : toggle the current method between expression body (`=> expr`) and
-- block body (`{ ... }`). Delegates to the LSP; filter is chosen based on which
-- form is currently in use so the action always converts to the opposite form.
function M.run()
  local ft = vim.bo.filetype
  local lang = config.lang(ft)
  if not lang or not lang.method_node_types then
    vim.notify(("forge: toggle-body not supported for '%s'"):format(ft), vim.log.levels.WARN)
    return
  end

  local method_node = ts.enclosing_method(lang.method_node_types)
  if not method_node then
    vim.notify("forge: cursor is not inside a method", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local kind = current_method_kind(bufnr, method_node)
  if not kind then
    vim.notify("forge: toggle-body could not read method body", vim.log.levels.WARN)
    return
  end

  local expr = kind == "expression"

  vim.lsp.buf.code_action({
    apply = true,
    filter = function(action)
      local t = (action.title or ""):lower()
      if expr then
        -- Currently expression body → offer conversion to block body.
        return t:find("block") ~= nil
      else
        -- Currently block body → offer conversion to expression body.
        return t:find("expression") ~= nil
      end
    end,
  })
end

return M
