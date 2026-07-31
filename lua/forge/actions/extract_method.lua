local M = {}

-- <prefix>em : extract selected block (or statement under cursor) to a new
-- method/function. Works in normal and visual modes.
-- Delegates to the LSP "extract method / function" refactoring.
local lsp = require("forge.lsp")

function M.run()
  local filter = function(action)
    local t = (action.title or ""):lower()
    return t:find("extract") ~= nil
      and (t:find("method") ~= nil or t:find("function") ~= nil or t:find("closure") ~= nil)
  end

  -- Try to find and apply matching LSP action synchronously. If none found,
  -- fall back to showing the code action picker.
  local applied = lsp.try_code_action(filter, function()
    vim.lsp.buf.code_action({ filter = filter })
  end)

  if applied then
    -- After extract applied, try to place cursor on the generated method call
    -- at the original location and invoke rename so user can rename immediately.
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]

    local function find_call_in_line(r)
      local ok, line = pcall(vim.api.nvim_buf_get_lines, bufnr, r - 1, r, false)
      if not ok or not line or not line[1] then
        return nil
      end
      local ln = line[1]
      local s, e, name = ln:find('([%a_][%w_]*)%s*%(')
      if s then
        return s - 1, name
      end
      return nil
    end

    local target_row, target_col, target_name
    -- Search current line and two lines down
    for i = 0, 2 do
      local c = find_call_in_line(row + i)
      if c then
        target_row = row + i
        target_col = c
        break
      end
    end
    -- If not found, search up two lines
    if not target_row then
      for i = 1, 2 do
        local c = find_call_in_line(row - i)
        if c then
          target_row = row - i
          target_col = c
          break
        end
      end
    end

    if target_row and target_col then
      vim.api.nvim_win_set_cursor(0, { target_row, target_col })
      -- Trigger rename at the call site so user can rename new method
      pcall(vim.lsp.buf.rename)
    else
      -- Fallback: try rename at current cursor
      pcall(vim.lsp.buf.rename)
    end
  end
end

return M
