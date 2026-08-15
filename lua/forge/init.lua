local config = require("forge.config")

local M = {}

-- Action name -> handler. Add an entry here (plus a default keymap in
-- config.lua) to grow the plugin.
local actions = {
  create_class = function()
    require("forge.actions.create_class").run()
  end,
  create_field = function()
    require("forge.actions.create_field").run()
  end,
  create_method = function()
    require("forge.actions.create_method").run()
  end,
  create_typedef = function()
    require("forge.actions.create_typedef").run()
  end,
  wrap_if = function()
    require("forge.actions.wrap_if").run()
  end,
  wrap_for = function()
    require("forge.actions.wrap_for").run()
  end,
  add_param = function()
    require("forge.actions.add_param").run()
  end,
  toggle_field_final = function()
    require("forge.actions.toggle_field_final").run()
  end,
  toggle_body = function()
    require("forge.actions.toggle_body").run()
  end,
  implement = function()
    require("forge.actions.implement").run()
  end,
  inline_variable = function()
    require("forge.actions.inline_variable").run()
  end,
  extract_variable = function()
    require("forge.actions.extract_variable").run()
  end,
  extract_method = function()
    require("forge.actions.extract_method").run()
  end,
  code_action = function()
    require("forge.actions.code_action").run()
  end,
  comment_refactoring = function()
    require("forge.actions.comment_refactoring").run()
  end,
  code_menu = function()
    require("forge.actions.menu").run()
  end,
  duplicate_test = function()
    require("forge.actions.duplicate_test").run()
  end,
  help = function()
    require("forge.actions.help").run()
  end,
}

local descriptions = {
  create_class = "Forge: create class",
  create_field = "Forge: create field",
  create_method = "Forge: create method",
  create_typedef = "Forge: create type definition",
  wrap_if = "Forge: wrap with if",
  wrap_for = "Forge: wrap with for",
  add_param = "Forge: add parameter",
  toggle_field_final = "Forge: toggle field final",
  toggle_body = "Forge: toggle expression/block body",
  implement = "Forge: implement interface",
  inline_variable = "Forge: inline variable",
  extract_variable = "Forge: extract to variable",
  extract_method = "Forge: extract to method",
  code_action = "Forge: code actions",
  comment_refactoring = "Forge: add refactoring comment",
  code_menu = "Forge: code shortcuts menu",
  duplicate_test = "Forge: duplicate test",
  help = "Forge: show keymap help",
}

M.actions = actions
M.descriptions = descriptions

M.config = nil

function M._apply_keymaps()
  local prefix = M.config.prefix
  for name, binding in pairs(M.config.keymaps) do
    local handler = actions[name]
    if not handler then
      goto continue
    end
    local suffix, modes
    if type(binding) == "string" then
      suffix = binding
      modes = { "n" }
    elseif type(binding) == "table" then
      suffix = binding.key
      modes = binding.modes or { "n" }
    end
    if suffix then
      vim.keymap.set(modes, prefix .. suffix, handler, {
        silent = true,
        desc = descriptions[name] or ("Forge: " .. name),
      })
    end
    ::continue::
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
