local config = require("forge.config")
local ts = require("forge.ts")

local M = {}

local MODIFIERS = {
  public = true,
  private = true,
  protected = true,
  static = true,
  abstract = true,
  override = true,
  late = true,
  transient = true,
  volatile = true,
}

local function is_field_line(before_semicolon)
  local trimmed = before_semicolon:gsub("^%s+", ""):gsub("%s+$", "")
  if trimmed == "" then
    return false
  end
  if trimmed:find("^//") or trimmed:find("^/%*") then
    return false
  end
  if trimmed:find("%(") then
    return false
  end
  local first = trimmed:match("^(%S+)")
  if first == "return" or first == "if" or first == "for" or first == "while" or first == "switch" then
    return false
  end
  return true
end

local function toggle_keyword_in_line(line, keyword)
  local indent = line:match("^%s*") or ""
  local content = line:sub(#indent + 1)
  local semi = content:find(";", 1, true)
  if not semi then
    return nil, "forge: current line doesn't look like a field"
  end
  local before = content:sub(1, semi - 1)
  local after = content:sub(semi)
  if not is_field_line(before) then
    return nil, "forge: current line doesn't look like a field"
  end

  local tokens = {}
  local has_keyword = false
  for tok in before:gmatch("%S+") do
    if tok == keyword then
      has_keyword = true
    else
      tokens[#tokens + 1] = tok
    end
  end

  if not has_keyword then
    local insert_at = 1
    while insert_at <= #tokens and MODIFIERS[tokens[insert_at]] do
      insert_at = insert_at + 1
    end
    table.insert(tokens, insert_at, keyword)
  end

  local new_before = table.concat(tokens, " ")
  if new_before == "" then
    return nil, "forge: couldn't toggle field modifier on this line"
  end
  return indent .. new_before .. after
end

-- <prefix>tf : toggle `final`/`readonly` keyword on current field line.
function M.run()
  local ft = vim.bo.filetype
  local lang = config.lang(ft)
  if not lang or not lang.style or not lang.field_final_keyword then
    vim.notify(("forge: toggle-field-final is not supported for filetype '%s'"):format(ft), vim.log.levels.WARN)
    return
  end

  local class_node = ts.enclosing_class(lang.class_node_types or {})
  if not class_node then
    vim.notify("forge: cursor is not inside a class", vim.log.levels.WARN)
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
  local updated, err = toggle_keyword_in_line(line, lang.field_final_keyword)
  if not updated then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  vim.api.nvim_buf_set_lines(0, row, row + 1, false, { updated })
end

M._toggle_keyword_in_line = toggle_keyword_in_line

return M
