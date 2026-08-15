local M = {}

-- Build { name, keymap, desc } rows from the active config + init.lua tables.
local function collect_rows()
  local forge = require("forge")
  local cfg = forge.config or require("forge.config").defaults
  local prefix = cfg.prefix or ""
  local rows = {}
  for name, binding in pairs(cfg.keymaps or {}) do
    local suffix
    if type(binding) == "string" then
      suffix = binding
    elseif type(binding) == "table" then
      suffix = binding.key
    end
    if suffix and forge.actions[name] then
      rows[#rows + 1] = {
        name = name,
        keymap = prefix .. suffix,
        desc = (forge.descriptions or {})[name] or ("Forge: " .. name),
      }
    end
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  return rows
end
M._collect_rows = collect_rows

local function display(row)
  return string.format("%-16s %-22s %s", row.keymap, row.name, row.desc)
end

local function run_row(row)
  local forge = require("forge")
  local handler = forge.actions[row.name]
  if handler then
    handler()
  end
end

local function telescope_pick(rows)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = "Forge: actions",
      finder = finders.new_table({
        results = rows,
        entry_maker = function(row)
          return { value = row, display = display(row), ordinal = row.name .. " " .. row.keymap .. " " .. row.desc }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry and entry.value then
            run_row(entry.value)
          end
        end)
        return true
      end,
    })
    :find()
end

local function fallback_pick(rows)
  vim.ui.select(rows, {
    prompt = "Forge: actions",
    format_item = display,
  }, function(choice)
    if choice then
      run_row(choice)
    end
  end)
end

function M.run()
  local rows = collect_rows()
  if #rows == 0 then
    vim.notify("forge: no actions configured", vim.log.levels.INFO)
    return
  end
  if pcall(require, "telescope") then
    local ok = pcall(telescope_pick, rows)
    if ok then
      return
    end
  end
  fallback_pick(rows)
end

return M
