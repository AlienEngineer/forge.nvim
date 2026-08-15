local config = require("forge.config")
local ts = require("forge.ts")
local field_inserters = require("forge.field_inserters")
local lsp = require("forge.lsp")

local M = {}

local function create_method_filter(action)
  local title = action.title or ""
  return title:lower():match("^create method '[^']+'$") ~= nil
end

local function expand_snippet(lang)
  local class_node = ts.enclosing_class(lang.class_node_types or {})
  if not class_node then
    vim.notify("forge: cursor is not inside a class", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local insert_row, indent
  if lang.style == "braces" then
    insert_row, indent = field_inserters.braces_method_insert_pos(bufnr, class_node)
  else
    insert_row, indent = field_inserters.python_method_insert_pos(bufnr, class_node)
  end

  if not insert_row then
    vim.notify("forge: couldn't find method insertion point", vim.log.levels.WARN)
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, insert_row, insert_row, false, { "" })
  vim.api.nvim_win_set_cursor(0, { insert_row + 1, 0 })
  vim.snippet.expand(indent .. lang.method_snippet)
end

-- <prefix>m : smart method creator.
-- When cursor is on a missing symbol, applies the LSP "Create method 'X'" or
-- "Create function 'X'" fix. Otherwise inserts a method snippet inside the
-- enclosing class.
function M.run()
  local ft = vim.bo.filetype
  local lang = config.lang(ft)
  if not lang or not lang.style or not lang.method_snippet then
    vim.notify(("forge: create-method is not supported for filetype '%s'"):format(ft), vim.log.levels.WARN)
    return
  end

  local class_node = ts.enclosing_class(lang.class_node_types or {})
  if not class_node then
    vim.lsp.buf.code_action({ apply = true, filter = create_method_filter })
    return
  end

  lsp.try_code_action(create_method_filter, function()
    expand_snippet(lang)
  end)
end

M._create_method_filter = create_method_filter

return M
