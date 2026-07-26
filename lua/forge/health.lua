local M = {}

function M.check()
  local h = vim.health
  local start = h.start or h.report_start
  local ok = h.ok or h.report_ok
  local warn = h.warn or h.report_warn
  local err = h.error or h.report_error

  start("forge")

  if vim.fn.has("nvim-0.10") == 1 then
    ok("Neovim >= 0.10 (vim.snippet / buf_request_all available)")
  else
    err("Neovim 0.10+ is required")
  end

  if vim.treesitter and vim.treesitter.get_node then
    ok("treesitter API available (used to locate the enclosing class)")
  else
    warn("treesitter not available — the implement flow needs it")
  end

  if #vim.lsp.get_clients() > 0 then
    ok("LSP clients present")
  else
    warn("no LSP clients seen yet — implement / code-action need a running server")
  end

  if pcall(require, "telescope") then
    ok("telescope.nvim found")
  else
    warn("telescope.nvim not found (optional). Install telescope-ui-select for fuzzy pickers")
  end
end

return M
