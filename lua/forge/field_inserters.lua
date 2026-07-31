local M = {}

local function indent_unit()
  if vim.bo.expandtab then
    local sw = vim.bo.shiftwidth
    if sw == 0 then
      sw = vim.bo.tabstop
    end
    return string.rep(" ", math.max(sw, 2))
  end
  return "\t"
end

local function line_indent(line)
  return (line:match("^%s*")) or ""
end

local function format_field(template, field_type, field_name)
  local t = field_type:gsub("%%", "%%%%")
  local n = field_name:gsub("%%", "%%%%")
  return template:gsub("__TYPE__", t):gsub("__NAME__", n)
end

function M.format_field(template, field_type, field_name)
  return format_field(template, field_type, field_name)
end

-- Returns (row, indent_str) for the snippet field insertion point.
-- row is 0-based (insert a new line AT row+1).
-- For braces style: the line containing `{`.
function M.braces_insert_pos(bufnr, class_node)
  local srow = class_node:range()
  local last = vim.api.nvim_buf_line_count(bufnr)
  for row = srow, last - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if line and line:find("{", 1, true) then
      local next_line = vim.api.nvim_buf_get_lines(bufnr, row + 1, row + 2, false)[1] or ""
      local base = line_indent(line)
      local body_indent = line_indent(next_line)
      if body_indent == "" or next_line:match("^%s*}") then
        body_indent = base .. indent_unit()
      end
      return row, body_indent
    end
  end
  return nil, nil
end

-- For python classes: class header line.
function M.python_insert_pos(bufnr, class_node)
  local srow = class_node:range()
  local line = vim.api.nvim_buf_get_lines(bufnr, srow, srow + 1, false)[1] or ""
  local base = line_indent(line)
  local next_line = vim.api.nvim_buf_get_lines(bufnr, srow + 1, srow + 2, false)[1] or ""
  local body_indent = line_indent(next_line)
  if body_indent == "" or #body_indent <= #base then
    body_indent = base .. indent_unit()
  end
  return srow, body_indent
end

-- For braces-style: insert row (0-based) is the closing `}` of the class.
-- Returns (row, indent) where indent is the class body indent string.
function M.braces_method_insert_pos(bufnr, class_node)
  local srow = class_node:range()
  local _, _, erow, _ = class_node:range()
  local indent = ""
  local last = vim.api.nvim_buf_line_count(bufnr)
  for row = srow, math.min(erow, last - 1) do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if line and line:find("{", 1, true) then
      local base = line_indent(line)
      local next_line = vim.api.nvim_buf_get_lines(bufnr, row + 1, row + 2, false)[1] or ""
      indent = line_indent(next_line)
      if indent == "" or next_line:match("^%s*}") then
        indent = base .. indent_unit()
      end
      break
    end
  end
  return erow, indent
end

-- For python classes: insert after the last line of the class body.
function M.python_method_insert_pos(bufnr, class_node)
  local srow = class_node:range()
  local _, _, erow, _ = class_node:range()
  local class_line = vim.api.nvim_buf_get_lines(bufnr, srow, srow + 1, false)[1] or ""
  local base = line_indent(class_line)
  local next_line = vim.api.nvim_buf_get_lines(bufnr, srow + 1, srow + 2, false)[1] or ""
  local indent = line_indent(next_line)
  if indent == "" or #indent <= #base then
    indent = base .. indent_unit()
  end
  return erow + 1, indent
end

-- Scan the method node's lines to find the closing `)` of its parameter list.
-- Returns (row, col, has_params):
--   row, col: 0-based position of `)`.
--   has_params: true if there are already params between ( and ).
function M.find_param_insert_pos(bufnr, method_node)
  local srow = method_node:range()
  local last = vim.api.nvim_buf_line_count(bufnr)
  local depth = 0
  local open_row, open_col
  for row = srow, math.min(srow + 30, last - 1) do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if not line then
      break
    end
    for i = 1, #line do
      local c = line:sub(i, i)
      if c == "(" then
        depth = depth + 1
        if depth == 1 then
          open_row, open_col = row, i
        end
      elseif c == ")" then
        depth = depth - 1
        if depth == 0 then
          local between = ""
          if open_row == row then
            between = line:sub(open_col + 1, i - 1)
          elseif open_row then
            between = "x" -- multi-line params — assume non-empty
          end
          local has_params = between:match("%S") ~= nil
          return row, i - 1, has_params -- 0-based col of )
        end
      end
    end
  end
  return nil, nil, false
end
-- with indentation derived from existing class body or editor shiftwidth.
function M.braces(bufnr, class_node, template, field_type, field_name)
  local srow = class_node:range()
  local last = vim.api.nvim_buf_line_count(bufnr)
  for row = srow, last - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if line and line:find("{", 1, true) then
      local next_line = vim.api.nvim_buf_get_lines(bufnr, row + 1, row + 2, false)[1] or ""
      local base = line_indent(line)
      local body_indent = line_indent(next_line)
      if body_indent == "" or next_line:match("^%s*}") then
        body_indent = base .. indent_unit()
      end
      local field_line = body_indent .. format_field(template, field_type, field_name)
      vim.api.nvim_buf_set_lines(bufnr, row + 1, row + 1, false, { field_line })
      return true
    end
  end
  return false
end

-- For python classes, inserts an annotated class attribute under class header.
function M.python(bufnr, class_node, template, field_type, field_name)
  local srow = class_node:range()
  local line = vim.api.nvim_buf_get_lines(bufnr, srow, srow + 1, false)[1] or ""
  local base = line_indent(line)
  local next_line = vim.api.nvim_buf_get_lines(bufnr, srow + 1, srow + 2, false)[1] or ""
  local body_indent = line_indent(next_line)
  if body_indent == "" or #body_indent <= #base then
    body_indent = base .. indent_unit()
  end
  local field_line = body_indent .. format_field(template, field_type, field_name)
  vim.api.nvim_buf_set_lines(bufnr, srow + 1, srow + 1, false, { field_line })
  return true
end

return M
