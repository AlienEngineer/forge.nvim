local M = {}

local ts_utils_ok, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
local ts = require('forge.ts')

local function duplicate_lines(bufnr, start_row, end_row)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  vim.api.nvim_buf_set_lines(bufnr, end_row + 1, end_row + 1, false, lines)
  return lines
end

local function strip_quotes(text)
  -- drop surrounding ' " ` so search/cursor target the raw test name, not the quotes.
  if not text then return text end
  return text:gsub("^['\"`]", ""):gsub("['\"`]$", "")
end

local function place_cursor_on_text(text, start_row)
  -- search inserted lines starting at start_row (0-indexed). Place cursor at start of first match.
  local bufnr = vim.api.nvim_get_current_buf()
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  text = strip_quotes(text)
  for i = start_row, math.min(total_lines - 1, start_row + 200) do
    local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
    if line and text and line:find(text, 1, true) then
      local s, e = line:find(text, 1, true)
      -- win_set_cursor uses 1-indexed row and 0-indexed col
      vim.api.nvim_win_set_cursor(0, { i + 1, s - 1 })
      return true
    end
  end
  return false
end

local function duplicate_js_ts()
  local bufnr = vim.api.nvim_get_current_buf()
  local cur = vim.api.nvim_win_get_cursor(0)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { cur[1] - 1, cur[2] } })
  if not ok or not node then
    return false
  end

  while node do
    local t = node:type()
    if t == "call_expression" or t == "call_expression" or t == "call_expression" then
      -- callee is usually the first child
      local callee = node:child(0)
      if callee then
        local callee_txt = vim.treesitter.get_node_text(callee, bufnr)
        if callee_txt and (callee_txt:find("test") or callee_txt:find("it") or callee_txt:find("describe")) then
          -- find string arg node (first string/template)
          local string_node = nil
          for i = 0, node:child_count() - 1 do
            local c = node:child(i)
            if c and c:type():match("string") or (c and c:type():match("template")) then
              string_node = c
              break
            end
          end

          local srow, scol, erow, ecol = node:range()
          local lines = duplicate_lines(bufnr, srow, erow)

          local target_text = nil
          if string_node then
            target_text = vim.treesitter.get_node_text(string_node, bufnr)
          end

          -- Search for the target_text in inserted block
          local inserted_start = erow + 1 -- 0-indexed
          if target_text and place_cursor_on_text(target_text, inserted_start) then
            return true
          end

          -- fallback: put cursor at start of inserted block
          vim.api.nvim_win_set_cursor(0, { inserted_start + 1, 0 })
          return true
        end
      end
    end
    node = node:parent()
  end
  return false
end

local function duplicate_dart()
  -- Treesitter-based duplication for Dart/Flutter test calls (test, testWidgets, group)
  local bufnr = vim.api.nvim_get_current_buf()
  local cur = vim.api.nvim_win_get_cursor(0)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { cur[1] - 1, cur[2] } })
  if not ok or not node then
    return false
  end

  while node do
    local t = node:type()
    if t == "call_expression" then
      local callee = node:child(0)
      if callee then
        local callee_txt = vim.treesitter.get_node_text(callee, bufnr)
        if callee_txt and (callee_txt:find("test") or callee_txt:find("testWidgets") or callee_txt:find("group")) then
          -- find string arg node (first string_literal)
          local string_node = nil
          for i = 0, node:child_count() - 1 do
            local c = node:child(i)
            if c and c:type():match("string") then
              string_node = c
              break
            end
          end

          local srow, scol, erow, ecol = node:range()
          local lines = duplicate_lines(bufnr, srow, erow)

          local target_text = nil
          if string_node then
            target_text = vim.treesitter.get_node_text(string_node, bufnr)
          end

          local inserted_start = erow + 1
          if target_text and place_cursor_on_text(target_text, inserted_start) then
            return true
          end

          vim.api.nvim_win_set_cursor(0, { inserted_start + 1, 0 })
          return true
        end
      end
    end
    node = node:parent()
  end
  return false
end

local function duplicate_dart_text()
  -- Text-based fallback for Dart test calls when Treesitter node shapes differ.
  local bufnr = vim.api.nvim_get_current_buf()
  local cur = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  -- search upward for a line that contains a test invocation
  for i = cur[1], 1, -1 do
    local line = lines[i]
    if not line then goto continue end
    if line:find("test%s*%(") or line:find("testWidgets%s*%(") or line:find("group%s*%(") then
      local start_row = i - 1
      -- find the position of '(' on the start line
      local s_pos = line:find("%(") or 1
      -- scan forward to find matching parenthesis
      local depth = 0
      local started = false
      local end_row = start_row
      for r = start_row, #lines - 1 do
        local ln = lines[r + 1]
        local cstart = 1
        if r == start_row then cstart = s_pos end
        for c = cstart, #ln do
          local ch = ln:sub(c, c)
          if ch == '(' then depth = depth + 1; started = true end
          if ch == ')' then depth = depth - 1 end
          if started and depth == 0 then
            end_row = r
            goto found_end
          end
        end
      end
      ::found_end::
      if not started then return false end

      -- duplicate the block
      duplicate_lines(bufnr, start_row, end_row)

      -- attempt to extract the test name (first quoted string between start and end)
      local name = nil
      for r = start_row, end_row do
        local ln = lines[r + 1]
        if ln then
          local sq = ln:match("'(.-)'")
          if sq then name = sq; break end
          local dq = ln:match('"(.-)"')
          if dq then name = dq; break end
        end
      end

      local inserted_start = end_row + 1
      if name and place_cursor_on_text(name, inserted_start) then
        return true
      end
      vim.api.nvim_win_set_cursor(0, { inserted_start + 1, 0 })
      return true
    end
    ::continue::
  end
  return false
end

local function duplicate_rust()
  local bufnr = vim.api.nvim_get_current_buf()
  local cur = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  -- search upward for #[test]
  for i = cur[1] - 1, 1, -1 do
    local l = lines[i]
    if l and l:match("#%s*%[test%]") then
      -- find function start below
      for j = i, #lines do
        local fnline = lines[j]
        local fnname = fnline and fnline:match("fn%s+([%w_]+)")
        if fnname then
          -- find function end by brace counting
          local brace = 0
          local start_row = j - 1
          local end_row = j - 1
          for k = j, #lines do
            local ln = lines[k]
            for c in ln:gmatch('.') do
              if c == '{' then brace = brace + 1 end
              if c == '}' then brace = brace - 1 end
            end
            if k == j then
              -- account for '{' on signature line
              if lines[k]:find('{') then brace = brace end
            end
            if brace == 0 and lines[k]:find('}') then
              end_row = k - 1
              break
            end
            end_row = k - 1
          end

          local block = duplicate_lines(bufnr, start_row, end_row)
          -- search inserted block for function name
          local inserted_start = end_row + 1
          if place_cursor_on_text(fnname, inserted_start) then
            return true
          end
          vim.api.nvim_win_set_cursor(0, { inserted_start + 1, 0 })
          return true
        end
      end
      break
    end
  end
  return false
end

function M.run()
  local ft = vim.bo.filetype
  -- Try TS/JS treesitter first
  if ft:match('typescript') or ft:match('javascript') or ft:match('tsx') or ft:match('jsx') then
    local ok = duplicate_js_ts()
    if ok then return end
  end
  -- Dart: try Treesitter then text fallback
  if ft:match('dart') then
    local ok = duplicate_dart()
    if ok then return end
    local ok2 = duplicate_dart_text()
    if ok2 then return end
  end
  -- Try rust regex fallback
  if ft == 'rust' then
    local ok = duplicate_rust()
    if ok then return end
  end

  vim.notify('forge: could not find a test to duplicate', vim.log.levels.INFO)
end

return M
