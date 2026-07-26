local config = require("forge.config")
local ts = require("forge.ts")
local lsp = require("forge.lsp")
local inserters = require("forge.inserters")

local M = {}

-- Only auto-apply code actions that look like member stubbing.
local function implement_filter(action)
  local t = (action.title or ""):lower()
  return t:find("implement", 1, true)
    or t:find("missing", 1, true)
    or t:find("override", 1, true)
    or t:find("stub", 1, true)
end

-- <prefix>i : add an interface to the current class and let the LSP stub the
-- members. We only wire the pieces together — the picker is workspace/symbol,
-- the class lookup is treesitter, the stubbing is an LSP code action.
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

  local kinds = config.get().implement_symbol_kinds
  vim.ui.input({ prompt = "Interface to implement: " }, function(query)
    if query == nil then
      return
    end
    lsp.workspace_symbols(query, kinds, function(symbols)
      if #symbols == 0 then
        vim.notify("forge: no matching symbols", vim.log.levels.WARN)
        return
      end
      vim.ui.select(symbols, {
        prompt = "Implement interface",
        format_item = function(s)
          local where = s.containerName
          if (not where or where == "") and s.location and s.location.uri then
            where = vim.fn.fnamemodify(vim.uri_to_fname(s.location.uri), ":t")
          end
          return ("%s  %s"):format(s.name, where or "")
        end,
      }, function(choice)
        if not choice then
          return
        end
        local inserter = inserters[lang.style]
        local ok = inserter and inserter(0, class_node, choice.name, lang.implements_keyword or "implements")
        if not ok then
          vim.notify("forge: couldn't insert the implements clause", vim.log.levels.WARN)
        end
        local srow, scol = class_node:range()
        vim.defer_fn(function()
          pcall(vim.api.nvim_win_set_cursor, 0, { srow + 1, scol })
          lsp.implement_action(implement_filter)
        end, 200)
      end)
    end)
  end)
end

return M
