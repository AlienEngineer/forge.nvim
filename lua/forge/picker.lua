local M = {}

local function symbol_location(sym)
  local where = sym.containerName
  if (not where or where == "") and sym.location and sym.location.uri then
    where = vim.fn.fnamemodify(vim.uri_to_fname(sym.location.uri), ":t")
  end
  return where or ""
end
M._symbol_location = symbol_location

local function contains_icase(haystack, needle)
  if not needle or needle == "" then
    return true
  end
  return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

local function primitive_candidates(prompt, literals)
  local out = {}
  local seen = {}
  for _, name in ipairs(literals or {}) do
    if name ~= "" and not seen[name] and contains_icase(name, prompt or "") then
      seen[name] = true
      out[#out + 1] = { name = name, _forge_kind = "primitive" }
    end
  end
  return out, seen
end
M._primitive_candidates = primitive_candidates

-- Synchronously query workspace/symbol on the source buffer and return filtered symbols.
local function query_symbols(prompt, opts)
  if not prompt or prompt == "" then
    return {}
  end
  local bufnr = opts.bufnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  local responses = vim.lsp.buf_request_sync(bufnr, "workspace/symbol", { query = prompt }, opts.timeout or 1000)
  local out = {}
  for _, resp in pairs(responses or {}) do
    for _, sym in ipairs((resp or {}).result or {}) do
      local kind_ok = not opts.kinds or opts.kinds[sym.kind]
      if kind_ok and sym.name ~= opts.exclude then
        out[#out + 1] = sym
      end
    end
  end
  return out
end
M._query_symbols = query_symbols

local function candidates(prompt, opts)
  local prim, seen = primitive_candidates(prompt, opts.literals)
  local out = {}
  for _, item in ipairs(prim) do
    out[#out + 1] = item
  end
  for _, sym in ipairs(query_symbols(prompt, opts)) do
    if not seen[sym.name] then
      out[#out + 1] = sym
      seen[sym.name] = true
    end
  end
  return out
end
M._candidates = candidates

local function default_display(item)
  local where = symbol_location(item)
  if item._forge_kind == "primitive" then
    where = "primitive"
  end
  return ("%s  %s"):format(item.name, where)
end

local function telescope_pick(opts)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = opts.prompt_title,
      finder = finders.new_dynamic({
        entry_maker = function(item)
          return {
            value = item,
            display = opts.display_item(item),
            ordinal = item.name,
          }
        end,
        fn = function(prompt)
          return candidates(prompt, opts)
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry and entry.value then
            opts.on_choice(entry.value)
          end
        end)
        return true
      end,
    })
    :find()
end

local function fallback_pick(opts)
  vim.ui.input({ prompt = opts.input_prompt }, function(query)
    if query == nil then
      return
    end
    local items = candidates(query, opts)
    if #items == 0 then
      vim.notify("forge: no matching symbols", vim.log.levels.WARN)
      return
    end
    vim.ui.select(items, {
      prompt = opts.select_prompt,
      format_item = opts.display_item,
    }, function(choice)
      if choice then
        opts.on_choice(choice)
      end
    end)
  end)
end

local function pick(opts)
  opts.display_item = opts.display_item or default_display
  if pcall(require, "telescope") then
    local ok = pcall(telescope_pick, opts)
    if ok then
      return
    end
  end
  fallback_pick(opts)
end

function M.pick_symbol(opts)
  pick(vim.tbl_extend("force", {
    prompt_title = "Implement (type to search base classes)",
    input_prompt = "Interface to implement: ",
    select_prompt = "Implement interface",
  }, opts))
end

function M.pick_type(opts)
  pick(vim.tbl_extend("force", {
    prompt_title = "Field type (type to search)",
    input_prompt = "Field type: ",
    select_prompt = "Select field type",
    literals = opts.literals or {},
  }, opts))
end

return M
