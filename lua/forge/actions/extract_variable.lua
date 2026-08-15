local M = {}

-- <prefix>ev : extract selected expression (or expression under cursor) to a
-- local variable. Works in normal and visual modes.
-- Delegates to the LSP "extract variable / local" refactoring.
local lsp = require("forge.lsp")

function M.run()
  local filter = function(action)
    local t = (action.title or ""):lower()
    return t:find("extract") ~= nil
      and (
        t:find("variable") ~= nil
        or t:find("local") ~= nil
        or t:find("const") ~= nil
        or t:find("let") ~= nil
        or t:find("field") ~= nil
      )
  end

  local applied = lsp.try_code_action(filter, function()
    vim.lsp.buf.code_action({ filter = filter })
  end)

  if applied then
    -- After extract applied, place cursor on the new variable usage and
    -- invoke rename so user can rename the extracted variable immediately.
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]

    local function find_var_in_line(r)
      local ok, line = pcall(vim.api.nvim_buf_get_lines, bufnr, r - 1, r, false)
      if not ok or not line or not line[1] then
        return nil
      end
      local ln = line[1]
      -- match word followed by non-word or end (variable usage). Prefer pattern with
      -- word followed by non-alnum (to avoid matching substrings).
      local s, e, name = ln:find('([%a_][%w_]*)')
      if s then
        return s - 1, name
      end
      return nil
    end

    local target_row, target_col
    -- Search current line and two lines down
    for i = 0, 2 do
      local res = find_var_in_line(row + i)
      if res then
        target_row = row + i
        target_col = res
        break
      end
    end
    -- If not found, search up two lines
    if not target_row then
      for i = 1, 2 do
        local res = find_var_in_line(row - i)
        if res then
          target_row = row - i
          target_col = res
          break
        end
      end
    end

    if target_row and target_col then
      vim.api.nvim_win_set_cursor(0, { target_row, target_col })
      pcall(vim.lsp.buf.rename)
    else
      pcall(vim.lsp.buf.rename)
    end
  end
end

return M
