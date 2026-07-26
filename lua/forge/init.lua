local config = require("forge.config")

local M = {}

-- Action name -> handler. Add an entry here (plus a default keymap in
-- config.lua) to grow the plugin.
local actions = {
  create_class = function()
    require("forge.actions.create_class").run()
  end,
  implement = function()
    require("forge.actions.implement").run()
  end,
  code_action = function()
    require("forge.actions.code_action").run()
  end,
}

local descriptions = {
  create_class = "Forge: create class",
  implement = "Forge: implement interface",
  code_action = "Forge: code actions",
}

M.config = nil

function M._apply_keymaps()
  local prefix = M.config.prefix
  for name, suffix in pairs(M.config.keymaps) do
    local handler = actions[name]
    if handler and suffix then
      vim.keymap.set("n", prefix .. suffix, handler, {
        silent = true,
        desc = descriptions[name] or ("Forge: " .. name),
      })
    end
  end
end

function M._create_command()
  vim.api.nvim_create_user_command("Forge", function(opts)
    local handler = actions[opts.args]
    if handler then
      handler()
    else
      vim.notify("forge: unknown subcommand '" .. opts.args .. "'", vim.log.levels.ERROR)
    end
  end, {
    nargs = 1,
    complete = function(lead)
      local out = {}
      for name in pairs(actions) do
        if name:find(lead, 1, true) == 1 then
          out[#out + 1] = name
        end
      end
      table.sort(out)
      return out
    end,
  })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", config.defaults, opts or {})
  config.set(M.config)
  M._apply_keymaps()
  M._create_command()
end

return M
