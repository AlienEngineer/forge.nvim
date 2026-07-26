-- Single-popup, live symbol picker for the implement flow. As you type, it
-- re-queries the LSP `workspace/symbol` endpoint and shows matching base-class /
-- interface candidates. Uses Telescope's dynamic finder when available and
-- degrades to a prompt + `vim.ui.select` otherwise.
--
-- Nothing here generates code: the search is the LSP's, the fuzzy UI is
-- Telescope's. forge only filters to the interesting symbol kinds and forwards
-- the pick.
local M = {}

-- Human-readable "where does this symbol live" hint.
local function symbol_location(sym)
  local where = sym.containerName
  if (not where or where == "") and sym.location and sym.location.uri then
    where = vim.fn.fnamemodify(vim.uri_to_fname(sym.location.uri), ":t")
  end
  return where or ""
end
M._symbol_location = symbol_location

-- Synchronously query workspace/symbol on the *source* buffer (opts.bufnr), so
-- the request reaches that buffer's LSP client rather than the picker's prompt
-- buffer (which has none). Filters to opts.kinds and drops opts.exclude.
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

-- Live Telescope picker: one popup, results refresh on every keystroke.
local function telescope_pick(opts)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = "Implement (type to search base classes)",
      finder = finders.new_dynamic({
        entry_maker = function(sym)
          return {
            value = sym,
            display = ("%s  %s"):format(sym.name, symbol_location(sym)),
            ordinal = sym.name,
          }
        end,
        fn = function(prompt)
          return query_symbols(prompt, opts)
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

-- Fallback for when Telescope is absent: prompt for a query, then select.
local function fallback_pick(opts)
  vim.ui.input({ prompt = "Interface to implement: " }, function(query)
    if query == nil then
      return
    end
    local symbols = query_symbols(query, opts)
    if #symbols == 0 then
      vim.notify("forge: no matching symbols", vim.log.levels.WARN)
      return
    end
    vim.ui.select(symbols, {
      prompt = "Implement interface",
      format_item = function(s)
        return ("%s  %s"):format(s.name, symbol_location(s))
      end,
    }, function(choice)
      if choice then
        opts.on_choice(choice)
      end
    end)
  end)
end

-- Pick a base class / interface and hand it to opts.on_choice(symbol).
--   opts.bufnr     : source buffer whose LSP client answers workspace/symbol
--   opts.kinds     : set of LSP SymbolKind numbers to keep (or nil for all)
--   opts.exclude   : symbol name to omit (e.g. the current class)
--   opts.on_choice : fn(symbol) invoked with the chosen symbol
function M.pick_symbol(opts)
  if pcall(require, "telescope") then
    local ok = pcall(telescope_pick, opts)
    if ok then
      return
    end
  end
  fallback_pick(opts)
end

return M
