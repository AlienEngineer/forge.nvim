local config = require("forge.config")

local M = {}

local BLOCK_NODE_TYPES = {
  block = true,
  statement_block = true,
  compound_statement = true,
  suite = true,
}

local WRAP_NODES = {
  ["if"] = {
    header = {
      dart = "if (condition) {",
      java = "if (condition) {",
      javascript = "if (condition) {",
      python = "if condition:",
      typescript = "if (condition) {",
    },
    snippet = {
      dart = "if (${1:condition}) {\n\t$0\n}",
      java = "if (${1:condition}) {\n\t$0\n}",
      javascript = "if (${1:condition}) {\n\t$0\n}",
      python = "if ${1:condition}:\n\t$0",
      typescript = "if (${1:condition}) {\n\t$0\n}",
    },
  },
  ["for"] = {
    header = {
      dart = "for (var item in iterable) {",
      java = "for (var item : iterable) {",
      javascript = "for (const item of iterable) {",
      python = "for item in iterable:",
      typescript = "for (const item of iterable) {",
    },
    snippet = {
      dart = "for (var ${1:item} in ${2:iterable}) {\n\t$0\n}",
      java = "for (var ${1:item} : ${2:iterable}) {\n\t$0\n}",
      javascript = "for (const ${1:item} of ${2:iterable}) {\n\t$0\n}",
      python = "for ${1:item} in ${2:iterable}:\n\t$0",
      typescript = "for (const ${1:item} of ${2:iterable}) {\n\t$0\n}",
    },
  },
}

local function cursor_node()
  local pok, parser = pcall(vim.treesitter.get_parser, 0)
  if pok and parser then
    pcall(function()
      parser:parse(true)
    end)
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = 0, pos = { cur[1] - 1, cur[2] } })
  if not ok then
    return nil
  end
  return node
end

local function has_block_child(node)
  for i = 0, node:child_count() - 1 do
    if BLOCK_NODE_TYPES[node:child(i):type()] then
      return true
    end
  end
  return false
end

local function is_wrap_candidate(node)
  local t = node:type()
  return has_block_child(node)
    and (t:find("statement", 1, true) or t:find("declaration", 1, true) or t == "function_definition")
end

local function is_empty_block(bufnr, node)
  local srow, _, erow, _ = node:range()
  local lines = vim.api.nvim_buf_get_lines(bufnr, srow, erow + 1, false)
  if #lines == 0 then
    return false
  end
  if #lines == 1 then
    return lines[1]:find("%{%s*%}") ~= nil
  end
  for i = 2, #lines - 1 do
    if lines[i]:find("%S") then
      return false
    end
  end
  return true
end

local function find_wrap_node()
  local node = cursor_node()
  if not node then
    return nil
  end

  local cur = vim.api.nvim_win_get_cursor(0)
  local row = cur[1] - 1
  local line = vim.api.nvim_get_current_line()

  while node do
    if is_wrap_candidate(node) then
      local srow, _, erow, _ = node:range()
      if row == srow or row == erow or line:find("{", 1, true) or line:find("}", 1, true) then
        return node
      end
    end
    node = node:parent()
  end
  return nil
end

local function indent_unit()
  if vim.bo.expandtab then
    local sw = vim.bo.shiftwidth
    if sw == 0 then
      sw = 2
    end
    return string.rep(" ", sw)
  end
  return "\t"
end

local function wrap_node(kind, node, header, ft)
  local bufnr = vim.api.nvim_get_current_buf()
  local srow, _, erow, _ = node:range()
  local lines = vim.api.nvim_buf_get_lines(bufnr, srow, erow + 1, false)
  local base_indent = lines[1]:match("^(%s*)") or ""
  local inner_indent = indent_unit()

  local out = { base_indent .. header }
  for _, line in ipairs(lines) do
    out[#out + 1] = inner_indent .. line
  end
  if header:find("{", 1, true) then
    out[#out + 1] = base_indent .. "}"
  end
  vim.api.nvim_buf_set_lines(bufnr, srow, erow + 1, false, out)

  if kind == "if" then
    local header_line = out[1]
    local cond_start = header_line:find("condition", 1, true)
    if cond_start then
      vim.api.nvim_win_set_cursor(0, { srow + 1, cond_start - 1 })
      return
    end
  end

  vim.api.nvim_win_set_cursor(0, { srow + 1, #base_indent + 1 })
end

local function word_under_cursor()
  return vim.fn.expand("<cword>")
end

local function singularize(word)
  if word:match("ies$") then
    return word:gsub("ies$", "y")
  end
  if word:match("(sses|xes|ches|shes|zes)$") then
    return word:gsub("es$", "")
  end
  if word:match("s$") and not word:match("ss$") then
    return word:gsub("s$", "")
  end
  return word
end

local function snippet(kind, ft, item, iterable)
  local tmpl = WRAP_NODES[kind].snippet[ft]
  if kind == "for" and item and iterable then
    return tmpl:gsub("%${1:item}", item):gsub("%${2:iterable}", iterable)
  end
  return tmpl
end

local function fallback(kind, ft, word)
  if kind == "for" then
    word = word or word_under_cursor()
    if word ~= "" then
      return snippet(kind, ft, singularize(word), word)
    end
  end
  return snippet(kind, ft)
end

local function wrap_selection(kind, srow, erow, header, ft)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, srow, erow + 1, false)
  local base_indent = lines[1]:match("^(%s*)") or ""
  local inner_indent = indent_unit()
  local out = { base_indent .. header }
  for _, line in ipairs(lines) do
    out[#out + 1] = inner_indent .. line
  end
  if header:find("{", 1, true) then
    out[#out + 1] = base_indent .. "}"
  end
  vim.api.nvim_buf_set_lines(bufnr, srow, erow + 1, false, out)
  if kind == "if" then
    local header_line = out[1]
    local cond_start = header_line:find("condition", 1, true)
    if cond_start then
      vim.api.nvim_win_set_cursor(0, { srow + 1, cond_start - 1 })
      return
    end
  end
  vim.api.nvim_win_set_cursor(0, { srow + 1, #base_indent + 1 })
end

function M.run(kind)
  local ft = config.lang(vim.bo.filetype) and (config.get().filetype_aliases[vim.bo.filetype] or vim.bo.filetype) or nil
  if not ft or not WRAP_NODES[kind] or not WRAP_NODES[kind].snippet[ft] then
    vim.notify(("forge: %s not supported for '%s'"):format(kind, vim.bo.filetype), vim.log.levels.WARN)
    return
  end

  -- If visual selection exists, wrap selection lines
  local ok_s, s_pos = pcall(vim.fn.getpos, "'<")
  local ok_e, e_pos = pcall(vim.fn.getpos, "'>")
  if ok_s and ok_e and s_pos and e_pos and (s_pos[2] ~= 0 or s_pos[3] ~= 0) then
    local s_line, _ = s_pos[2] - 1, math.max(0, s_pos[3] - 1)
    local e_line, _ = e_pos[2] - 1, math.max(0, e_pos[3] - 1)
    if s_line <= e_line then
      wrap_selection(kind, s_line, e_line, WRAP_NODES[kind].header[ft], ft)
      return
    end
  end

  local node = find_wrap_node()
  if node then
    if is_empty_block(vim.api.nvim_get_current_buf(), node) then
      local bufnr = vim.api.nvim_get_current_buf()
      if kind == "for" then
        local srow, _, erow, _ = node:range()
        vim.api.nvim_buf_set_lines(bufnr, srow, erow + 1, false, {})
        vim.api.nvim_win_set_cursor(0, { srow + 1, 0 })
        vim.snippet.expand(fallback(kind, ft))
        return
      else
        vim.snippet.expand(fallback(kind, ft))
        return
      end
    end
    wrap_node(kind, node, WRAP_NODES[kind].header[ft], ft)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local word = nil
  if kind == "for" then
    local line = vim.api.nvim_get_current_line()
    word = word_under_cursor()
    if word ~= "" and line:match("^%s*" .. vim.pesc(word) .. "%s*$") then
      local row = vim.api.nvim_win_get_cursor(0)[1] - 1
      vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, {})
      vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
    end
  end
  vim.snippet.expand(fallback(kind, ft, word))
end

return M
