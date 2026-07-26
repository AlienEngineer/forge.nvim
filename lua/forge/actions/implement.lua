local config = require("forge.config")
local ts = require("forge.ts")
local lsp = require("forge.lsp")
local inserters = require("forge.inserters")
local picker = require("forge.picker")

local M = {}

-- Only auto-apply code actions that look like member stubbing.
local function implement_filter(action)
  local t = (action.title or ""):lower()
  return t:find("implement", 1, true)
    or t:find("missing", 1, true)
    or t:find("override", 1, true)
    or t:find("stub", 1, true)
end

-- Best-effort name of a class node, used to exclude the class from its own
-- interface search. Relies on the `name` field, present in the dart/java/ts/
-- python grammars; returns nil if unavailable.
local function class_name(node, bufnr)
  local ok, field = pcall(function()
    local f = node:field("name")
    return f and f[1]
  end)
  if ok and field then
    local ok2, text = pcall(vim.treesitter.get_node_text, field, bufnr)
    if ok2 then
      return text
    end
  end
  return nil
end

-- <prefix>i : add an interface to the current class and let the LSP stub the
-- members. forge only wires the pieces together — the live search is
-- workspace/symbol via the picker, the class lookup is treesitter, and the
-- stubbing is an LSP code action.
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
  local winnr = vim.api.nvim_get_current_win()

  -- Insert the implements clause, then ask the LSP to stub the members.
  local function apply(choice)
    if not choice or not choice.name then
      return
    end
    pcall(vim.api.nvim_set_current_win, winnr)
    local inserter = inserters[lang.style]
    local ok = inserter and inserter(bufnr, class_node, choice.name, lang.implements_keyword or "implements")
    if not ok then
      vim.notify("forge: couldn't insert the implements clause", vim.log.levels.WARN)
    end
    local srow, scol = class_node:range()
    vim.defer_fn(function()
      pcall(vim.api.nvim_win_set_cursor, winnr, { srow + 1, scol })
      lsp.implement_action(implement_filter)
    end, 200)
  end

  picker.pick_symbol({
    bufnr = bufnr,
    kinds = config.get().implement_symbol_kinds,
    exclude = class_name(class_node, bufnr),
    on_choice = apply,
  })
end

return M
