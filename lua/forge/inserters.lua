-- Clause inserters, keyed by the `style` field in a language config. Each takes
-- (bufnr, class_node, iface, kw) and returns true on success. Kept in their own
-- module so the string logic is unit-testable without an LSP/treesitter round trip.
local M = {}

-- Brace-body languages (dart, java, typescript): the implements clause sits
-- between the class header and the opening `{`.
function M.braces(bufnr, class_node, iface, kw)
  local srow = class_node:range()
  local last = vim.api.nvim_buf_line_count(bufnr)
  for row = srow, last - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local bpos = line and line:find("{", 1, true)
    if bpos then
      local before = line:sub(1, bpos - 1):gsub("%s+$", "")
      local rest = line:sub(bpos)
      local clause
      if before:find("%f[%w]" .. kw .. "%f[%W]") then
        clause = before .. ", " .. iface .. " " .. rest
      else
        clause = before .. " " .. kw .. " " .. iface .. " " .. rest
      end
      vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { clause })
      return true
    end
  end
  return false
end

-- Python: "implements" == a base class inside the `(...)` after the name.
function M.python(bufnr, class_node, iface)
  local srow = class_node:range()
  local last = vim.api.nvim_buf_line_count(bufnr)
  for row = srow, last - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if line then
      local op, cp = line:find("(", 1, true), line:find(")", 1, true)
      if op and cp and cp > op then
        local sep = line:sub(op + 1, cp - 1):match("%S") and ", " or ""
        local new = line:sub(1, cp - 1) .. sep .. iface .. line:sub(cp)
        vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new })
        return true
      end
      local colon = line:find(":", 1, true)
      if colon then
        local head = line:sub(1, colon - 1):gsub("%s+$", "")
        local new = head .. "(" .. iface .. "):" .. line:sub(colon + 1)
        vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new })
        return true
      end
    end
  end
  return false
end

return M
