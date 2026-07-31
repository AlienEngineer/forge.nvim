local config = require("forge.config")
local snippet = require("forge.snippet")
local ts = require("forge.ts")
local lsp = require("forge.lsp")

local M = {}

local function create_class_filter(action)
  return (action.title or ""):lower():find("create class", 1, true) ~= nil
end

local function expand_snippet(lang)
  local class_node = lang.class_node_types and ts.enclosing_class(lang.class_node_types)
  if class_node then
    local bufnr = vim.api.nvim_get_current_buf()
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
