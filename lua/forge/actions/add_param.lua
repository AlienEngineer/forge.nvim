local config = require("forge.config")
local ts = require("forge.ts")
local field_inserters = require("forge.field_inserters")

local M = {}

-- <prefix>p : add a parameter to the enclosing method/function.
-- Finds the closing `)` of the method signature, inserts `, ` before it when
-- params already exist, then expands a param snippet. Tabstop 1 is the type
-- so LSP completion fires immediately, just like <prefix>i.
function M.run()
  local ft = vim.bo.filetype
  local lang = config.lang(ft)
  if not lang or not lang.method_node_types or not lang.param_snippet then
    vim.notify(("forge: add-param is not supported for filetype '%s'"):format(ft), vim.log.levels.WARN)
    return
  end

  local method_node = ts.enclosing_method(lang.method_node_types)
  if not method_node then
    vim.notify("forge: cursor is not inside a method or function", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local row, col, has_params = field_inserters.find_param_insert_pos(bufnr, method_node)
  if not row then
    vim.notify("forge: couldn't find method parameter list", vim.log.levels.WARN)
    return
  end

  -- Insert `, ` before `)` when params exist, creating the slot for the snippet.
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  local prefix = has_params and ", " or ""
  local new_line = line:sub(1, col) .. prefix .. line:sub(col + 1)
  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })

  -- Move cursor to the slot and expand the param snippet.
  vim.api.nvim_win_set_cursor(0, { row + 1, col + #prefix })
  vim.snippet.expand(lang.param_snippet)
end

return M
