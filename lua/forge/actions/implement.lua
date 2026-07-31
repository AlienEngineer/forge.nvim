local config = require("forge.config")
local ts = require("forge.ts")
local lsp = require("forge.lsp")

local M = {}

local function implement_filter(action)
  local t = (action.title or ""):lower()
  return t:find("implement", 1, true)
    or t:find("missing", 1, true)
    or t:find("override", 1, true)
    or t:find("stub", 1, true)
end

-- Inserts `kw ` before `{` on the class header line and returns (row, col):
-- 0-based row and 0-based col of the gap where the type name will be typed.
-- A trailing space before `{` is preserved so the type doesn't butt against it.
local function insert_kw_braces(bufnr, class_node, kw)
  local srow = class_node:range()
  local last = vim.api.nvim_buf_line_count(bufnr)
  for row = srow, last - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local bpos = line and line:find("{", 1, true)
    if bpos then
      local before = line:sub(1, bpos - 1):gsub("%s+$", "")
      local rest = line:sub(bpos)
      local prefix
      if before:find("%f[%w]" .. kw .. "%f[%W]") then
        -- keyword already present: cursor will expand `, TypeName`
        prefix = before .. ", "
      else
        prefix = before .. " " .. kw .. " "
      end
      -- Extra trailing space before `{` keeps the gap clean after snippet expand.
      vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { prefix .. " " .. rest })
      return row, #prefix
    end
  end
  return nil, nil
end

-- Inserts the base-class slot into a Python class header and returns (row, col).
local function insert_kw_python(bufnr, class_node)
  local srow = class_node:range()
  local last = vim.api.nvim_buf_line_count(bufnr)
  for row = srow, last - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    if line then
      local op = line:find("%(", 1, true)
      local cp = line:find("%)", 1, true)
      if op and cp and cp > op then
        local inner = line:sub(op + 1, cp - 1)
        local sep = inner:match("%S") and ", " or ""
        local new = line:sub(1, cp - 1) .. sep .. " " .. line:sub(cp)
        vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new })
        return row, cp - 1 + #sep
      end
      local colon = line:find(":", 1, true)
      if colon then
        local head = line:sub(1, colon - 1):gsub("%s+$", "")
        vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { head .. "( " .. line:sub(colon) })
        return row, #head + 1
      end
    end
  end
  return nil, nil
end

-- <prefix>i : add an interface/base-class to the enclosing class inline.
-- The user types the type name at a snippet tabstop; normal LSP completion
-- (blink/nvim-cmp) fires as they type. On leaving insert mode the LSP is asked
-- to auto-stub missing members.
function M.run()
  local ft = vim.bo.filetype
  local lang = config.lang(ft)
  if not lang or not lang.style then
    vim.notify(("forge: implement is not supported for filetype '%s'"):format(ft), vim.log.levels.WARN)
    return
  end

  local class_node = ts.enclosing_class(lang.class_node_types or {})
  if not class_node then
    vim.notify("forge: cursor is not inside a class", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local kw = lang.implements_keyword or "implements"

  local row, col
  if lang.style == "braces" then
    row, col = insert_kw_braces(bufnr, class_node, kw)
  else
    row, col = insert_kw_python(bufnr, class_node)
  end

  if not row then
    vim.notify("forge: couldn't find implements insertion point", vim.log.levels.WARN)
    return
  end

  -- Land cursor at the gap and open a snippet tabstop for the type name.
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
  vim.snippet.expand("${1:Type}")

  -- After the user finishes (leaves insert mode), auto-run the stub code action.
  local group = vim.api.nvim_create_augroup("ForgeImplementStub_" .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      vim.api.nvim_del_augroup_by_id(group)
      vim.defer_fn(function()
        lsp.implement_action(implement_filter)
      end, 300)
    end,
  })
end

return M
