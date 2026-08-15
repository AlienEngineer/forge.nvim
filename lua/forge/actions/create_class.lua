local config = require("forge.config")
local snippet = require("forge.snippet")
local ts = require("forge.ts")
local lsp = require("forge.lsp")

local M = {}

local function create_class_filter(action)
  return (action.title or ""):lower():find("create class", 1, true) ~= nil
end

local function expand_snippet(lang)
  local bufnr = vim.api.nvim_get_current_buf()

  -- If the cursor is on a word-like token, prefer creating the class at EOF
  -- with that word as the class name. Falls back to inserting after enclosing
  -- class (existing behavior) or expanding at cursor.
  local name = vim.fn.expand('<cword>')
  if name and name:match('^[%a_][%w_]*$') then
    -- Prepare template: replace common placeholder patterns with name so the
    -- snippet expands with the detected identifier filled in.
    local templ = lang.class_template
    -- Replace ${1:Name} or ${1:any} with the detected name
    templ = templ:gsub('%${1:.-}', name)
    -- Replace legacy __NAME__ placeholders
    templ = templ:gsub('__NAME__', name)

    -- Insert at end of file with a blank line separator
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    -- ensure there is at least one blank line at EOF
    vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, { '', '' })
    -- Move cursor to the new insertion point (last line)
    vim.api.nvim_win_set_cursor(0, { line_count + 2, 0 })

    snippet.expand_class(templ)
    return
  end

  -- Otherwise preserve previous behaviour: insert after enclosing class if any
  local class_node = lang.class_node_types and ts.enclosing_class(lang.class_node_types)
  if class_node then
    local _, _, erow, _ = class_node:range()
    vim.api.nvim_buf_set_lines(bufnr, erow + 1, erow + 1, false, { "", "" })
    vim.api.nvim_win_set_cursor(0, { erow + 3, 0 })
  end
  snippet.expand_class(lang.class_template)
end

-- <prefix>c : smart class creator.
-- When cursor is on a missing symbol, applies the LSP "Create class 'X'" fix.
-- Otherwise expands a class snippet (jumping outside any enclosing class first).
function M.run()
  local ft = vim.bo.filetype
  local lang = config.lang(ft)
  if not lang or not lang.class_template then
    vim.notify(("forge: no class template for filetype '%s'"):format(ft), vim.log.levels.WARN)
    return
  end

  lsp.try_code_action(create_class_filter, function()
    expand_snippet(lang)
  end)
end

return M
