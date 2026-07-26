local M = {}

-- LSP SymbolKind values we care about.
M.SymbolKind = { Class = 5, Interface = 11, Struct = 23, Enum = 10 }

-- Query workspace symbols across all attached clients and hand the aggregated,
-- kind-filtered results to `cb`.
function M.workspace_symbols(query, kinds, cb)
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    vim.notify("forge: no LSP client attached to this buffer", vim.log.levels.WARN)
    cb({})
    return
  end
  vim.lsp.buf_request_all(0, "workspace/symbol", { query = query or "" }, function(results)
    local out = {}
    for _, r in pairs(results or {}) do
      if r and r.result then
        for _, sym in ipairs(r.result) do
          if not kinds or kinds[sym.kind] then
            out[#out + 1] = sym
          end
        end
      end
    end
    cb(out)
  end)
end

-- Ask the server for an "implement/override/add missing" code action at the
-- cursor and auto-apply it when there is a single match.
function M.implement_action(filter)
  vim.lsp.buf.code_action({ apply = true, filter = filter })
end

return M
