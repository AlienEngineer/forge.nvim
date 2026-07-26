local config = require("forge.config")
local snippet = require("forge.snippet")

local M = {}

-- <prefix>c : prompt for a name and drop a language-appropriate class snippet
-- at the cursor. The scaffold itself comes from `vim.snippet`, so tabstops work
-- like any other snippet.
function M.run()
  local ft = vim.bo.filetype
  local lang = config.lang(ft)
  if not lang or not lang.class_template then
    vim.notify(("forge: no class template for filetype '%s'"):format(ft), vim.log.levels.WARN)
    return
  end
  vim.ui.input({ prompt = "Class name: " }, function(name)
    if not name or name == "" then
      return
    end
    snippet.expand_class(lang.class_template, name)
  end)
end

return M
