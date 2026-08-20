local lsp = require("forge.lsp")
local ts = require("forge.ts")
local config = require("forge.config")

local M = {}

local function move_to_file_filter(action)
  local title = (action.title or ""):lower()
  return title:find("move", 1, true) ~= nil and title:find("file", 1, true) ~= nil
end

-- <prefix>mf : move current class or type to its own file through the LSP.
function M.run()
  lsp.try_code_action(move_to_file_filter, function()
    vim.lsp.buf.code_action({ filter = move_to_file_filter })
  end)
end

-- <prefix>maf : move every configured class in the current buffer through LSP.
function M.run_all()
  local lang = config.lang(vim.bo.filetype)
  if not lang or not lang.class_node_types then
    vim.notify("forge: no class node types configured for this filetype", vim.log.levels.WARN)
    return
  end

  local positions = ts.class_positions(lang.class_node_types)
  if #positions == 0 then
    vim.notify("forge: no classes found in current buffer", vim.log.levels.INFO)
    return
  end

  local original_cursor = vim.api.nvim_win_get_cursor(0)
  local moved = 0
  for _, position in ipairs(positions) do
    vim.api.nvim_win_set_cursor(0, { position.row, position.col })
    if lsp.try_code_action(move_to_file_filter) then
      moved = moved + 1
    end
  end
  vim.api.nvim_win_set_cursor(0, original_cursor)

  local skipped = #positions - moved
  if skipped > 0 then
    vim.notify(string.format("forge: could not automatically move %d class(es) to files", skipped), vim.log.levels.WARN)
  end
end

M._move_to_file_filter = move_to_file_filter

return M
