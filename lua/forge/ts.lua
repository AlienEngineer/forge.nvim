local M = {}

-- Walk up the treesitter tree from the cursor until a node whose type is in
-- `node_types` is found. Returns the class node or nil.
function M.enclosing_class(node_types)
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node then
    -- The tree may not be parsed yet (e.g. called before any redraw). Force a
    -- parse and retry with an explicit cursor position.
    local pok, parser = pcall(vim.treesitter.get_parser, 0)
    if pok and parser then
      pcall(function()
        parser:parse(true)
      end)
      local cur = vim.api.nvim_win_get_cursor(0)
      ok, node = pcall(vim.treesitter.get_node, { bufnr = 0, pos = { cur[1] - 1, cur[2] } })
    end
  end
  if not ok or not node then
    return nil
  end
  while node do
    if node_types[node:type()] then
      return node
    end
    node = node:parent()
  end
  return nil
end

return M
