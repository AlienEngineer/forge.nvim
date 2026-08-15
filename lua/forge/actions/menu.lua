local M = {}
local lsp = require("forge.lsp")
local ts = require("forge.ts")
local config = require("forge.config")

local function extract_variable_filter(action)
  local t = (action.title or ""):lower()
  return t:find("extract") ~= nil
    and (
      t:find("variable") ~= nil
      or t:find("local") ~= nil
      or t:find("const") ~= nil
      or t:find("let") ~= nil
      or t:find("field") ~= nil
    )
end

local function extract_method_filter(action)
  local t = (action.title or ""):lower()
  return t:find("extract") ~= nil and (t:find("method") ~= nil or t:find("function") ~= nil or t:find("closure") ~= nil)
end

function M.run()
  local ft = vim.bo.filetype
  local lang = config.lang(ft) or {}
  local bufnr = vim.api.nvim_get_current_buf()

  local candidates = {}

  -- Rename
  if lsp.has_rename() then
    table.insert(candidates, {
      key = "cr",
      label = "Rename",
      run = function()
        pcall(vim.lsp.buf.rename)
      end,
    })
  end

  -- Extract variable
  if lsp.has_code_action(extract_variable_filter) then
    table.insert(candidates, {
      key = "cev",
      label = "Extract Variable",
      run = function()
        require("forge.actions.extract_variable").run()
      end,
    })
  end

  -- Extract method
  if lsp.has_code_action(extract_method_filter) then
    table.insert(candidates, {
      key = "cem",
      label = "Extract Method",
      run = function()
        require("forge.actions.extract_method").run()
      end,
    })
  end

  -- Create method (use create_method's filter if available)
  local ok, create_mod = pcall(require, "forge.actions.create_method")
  if
    ok
    and create_mod
    and create_mod._create_method_filter
    and lsp.has_code_action(create_mod._create_method_filter)
  then
    table.insert(candidates, {
      key = "cm",
      label = "Create Method",
      run = function()
        require("forge.actions.create_method").run()
      end,
    })
  end

  -- Toggle body: show when inside method (treesitter found)
  if lang.method_node_types and ts.enclosing_method(lang.method_node_types) then
    table.insert(candidates, {
      key = "cb",
      label = "Toggle Body (expr<->block)",
      run = function()
        require("forge.actions.toggle_body").run()
      end,
    })
  end

  -- Implement: show when inside class
  if lang.class_node_types and ts.enclosing_class(lang.class_node_types) then
    table.insert(candidates, {
      key = "ci",
      label = "Implement / Add stubs",
      run = function()
        require("forge.actions.implement").run()
      end,
    })
  end

  if #candidates == 0 then
    vim.notify("forge: no applicable shortcuts found", vim.log.levels.INFO)
    return
  end

  local items = {}
  for i, c in ipairs(candidates) do
    items[i] = string.format("%d. %-20s (%s)", i, c.label, c.key)
  end

  vim.ui.select(items, { prompt = "Forge: code shortcuts" }, function(choice, idx)
    if choice and idx and candidates[idx] then
      candidates[idx].run()
    end
  end)
end

return M
