local config = require("forge.config")
local ts = require("forge.ts")
local field_inserters = require("forge.field_inserters")

local M = {}

-- <prefix>f : insert a field snippet inside the enclosing class.
-- Tabstops land on type and name so the user fills them in-place; normal LSP
-- completion fires at each tabstop.
function M.run()
  local ft = vim.bo.filetype
  local lang = config.lang(ft)
  if not lang or not lang.style or not lang.field_snippet then
    vim.notify(("forge: create-field is not supported for filetype '%s'"):format(ft), vim.log.levels.WARN)
    return
  end

  local class_node = ts.enclosing_class(lang.class_node_types or {})
  if not class_node then
    vim.notify("forge: cursor is not inside a class", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  local insert_row, indent
  if lang.style == "braces" then
    insert_row, indent = field_inserters.braces_insert_pos(bufnr, class_node)
  else
    insert_row, indent = field_inserters.python_insert_pos(bufnr, class_node)
  end

  if not insert_row then
    vim.notify("forge: couldn't find field insertion point", vim.log.levels.WARN)
    return
  end

  -- Insert an empty line at the insertion point.
  vim.api.nvim_buf_set_lines(bufnr, insert_row + 1, insert_row + 1, false, { "" })
  -- Move cursor to start of that line (1-indexed row, col 0).
  vim.api.nvim_win_set_cursor(0, { insert_row + 2, 0 })
  -- Expand the field snippet with indentation as a literal prefix.
  vim.snippet.expand(indent .. lang.field_snippet)
end

return M
