local config = require("forge.config")

local M = {}

-- <prefix>nr : insert a refactoring note above current line.
function M.run()
  local ft = vim.bo.filetype
  local lang = config.lang(ft)
  if not lang or not lang.comment_prefix then
    vim.notify(("forge: refactoring comments are not supported for filetype '%s'"):format(ft), vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local indent = current_line:match("^%s*") or ""
  local comment = indent .. lang.comment_prefix .. " Refactoring: "

  vim.api.nvim_buf_set_lines(bufnr, row, row, false, { comment })
  vim.api.nvim_win_set_cursor(0, { row + 1, #comment })
end

return M
