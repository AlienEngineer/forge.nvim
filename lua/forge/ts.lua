local M = {}

-- Tree-sitter returns only a broad parent node when cursor is past line end.
local function cursor_node()
  local cur = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(0, cur[1] - 1, cur[1], false)[1] or ""
  local col = math.min(cur[2], math.max(#line - 1, 0))
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = 0, pos = { cur[1] - 1, col } })
  return ok and node or nil
end

-- Walk up the treesitter tree from the cursor until a node whose type is in
-- `node_types` is found. Returns the node or nil.
-- Always forces a re-parse to avoid stale trees between buffer edits.
local function enclosing_node(node_types)
  local pok, parser = pcall(vim.treesitter.get_parser, 0)
  if pok and parser then
    pcall(function()
      parser:parse(true)
    end)
  end
  local node = cursor_node()
  if not node then
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

function M.enclosing_class(node_types)
  return enclosing_node(node_types)
end

-- Return class start positions in reverse source order, so callers can safely
-- apply edits that remove declarations from the current buffer.
function M.class_positions(node_types)
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok or not parser then
    return {}
  end

  local trees = parser:parse(true)
  local positions = {}

  local function visit(node)
    if node_types[node:type()] then
      local row, col = node:start()
      positions[#positions + 1] = { row = row + 1, col = col }
    end
    for child in node:iter_children() do
      visit(child)
    end
  end

  for _, tree in ipairs(trees) do
    visit(tree:root())
  end

  table.sort(positions, function(a, b)
    return a.row == b.row and a.col > b.col or a.row > b.row
  end)
  return positions
end

-- Node types that indicate a parameter list (direct children of a function node).
local PARAM_CHILD_TYPES = {
  formal_parameter_list = true,
  formal_parameters = true,
  parameters = true,
  parameter_list = true,
}

-- Returns true if `node` directly contains a parameter-list child.
local function has_param_child(node)
  for i = 0, node:child_count() - 1 do
    if PARAM_CHILD_TYPES[node:child(i):type()] then
      return true
    end
  end
  return false
end

-- Dart (and similar grammars) separate `method_signature` / `function_signature`
-- from `function_body` as siblings under `class_body`. When the cursor is inside
-- `function_body`, the signature node is never an ancestor. This function scans
-- for a preceding sibling (or its first child) that holds parameter info.
local function find_signature_sibling(start_node)
  local n = start_node
  while n do
    if n:type() == "function_body" then
      local parent = n:parent()
      if not parent then
        return nil
      end
      for i = 0, parent:child_count() - 1 do
        if parent:child(i):id() == n:id() and i > 0 then
          -- Walk preceding siblings looking for one with params.
          for j = i - 1, 0, -1 do
            local sib = parent:child(j)
            if has_param_child(sib) then
              return sib
            end
            -- One level deeper (e.g. method_signature → function_signature).
            for k = 0, sib:child_count() - 1 do
              local gc = sib:child(k)
              if has_param_child(gc) then
                return gc
              end
            end
          end
          break
        end
      end
      return nil
    end
    n = n:parent()
  end
  return nil
end

-- Finds the innermost enclosing function/method node.
-- Strategy (in order):
--   1. Configured node_types (exact grammar name match).
--   2. Any ancestor that has a parameter-list as a direct child.
--   3. Dart/sibling pattern: preceding sibling of function_body with params.
function M.enclosing_method(node_types)
  -- Re-parse once and get the cursor node.
  local pok, parser = pcall(vim.treesitter.get_parser, 0)
  if pok and parser then
    pcall(function()
      parser:parse(true)
    end)
  end
  local start = cursor_node()
  if not start then
    return nil
  end

  -- Strategy 1: named node types.
  if node_types and next(node_types) then
    local n = start
    while n do
      if node_types[n:type()] then
        return n
      end
      n = n:parent()
    end
  end

  -- Strategy 2: any ancestor with a parameter-list child (TS, Python, Java…).
  local n = start
  while n do
    if has_param_child(n) then
      return n
    end
    n = n:parent()
  end

  -- Strategy 3: sibling pattern (Dart).
  return find_signature_sibling(start)
end

return M
