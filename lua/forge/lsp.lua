local M = {}

local function apply_code_action(action, client)
  if action.edit then
    local ok = pcall(vim.lsp.util.apply_workspace_edit, action.edit, client and client.offset_encoding or "utf-16")
    if not ok then
      return false
    end
  end

  if action.command then
    local ok = pcall(vim.lsp.buf.execute_command, action.command)
    if not ok then
      return false
    end
  end

  return action.edit ~= nil or action.command ~= nil
end

-- Ask the server for an "implement/override/add missing" code action at the
-- cursor and auto-apply it when there is a single match.
function M.implement_action(filter)
  vim.lsp.buf.code_action({ apply = true, filter = filter })
end

-- Synchronously checks whether the language server offers any code action
-- matching `filter` at the current cursor position.
-- If a match exists, delegates to `vim.lsp.buf.code_action` for proper
-- application (handles edits, commands, and resolve). Returns true.
-- If no match, calls `fallback()` (if provided) and returns false.
--
-- This is used to make snippet-insertion actions context-aware: when a
-- missing-symbol diagnostic is present the LSP fix is used; otherwise the
-- snippet fallback runs.
function M.try_code_action(filter, fallback)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1
  local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
  local col = cursor[2]
  local ok_word, word = pcall(vim.fn.expand, "<cword>")
  if not ok_word then
    word = ""
  end
  local word_start = col
  local word_end = col
  if word ~= "" then
    local s = line_text:find(vim.pesc(word), math.max(1, col - #word + 1), true)
    if s then
      word_start = s - 1
      word_end = word_start + #word
    end
  end

  local params_list = {}

  -- If user invoked from visual selection, use that exact range first.
  local ok_s, s_pos = pcall(vim.fn.getpos, "'<")
  local ok_e, e_pos = pcall(vim.fn.getpos, "'>")
  if ok_s and ok_e and s_pos and e_pos and (s_pos[2] ~= 0 or s_pos[3] ~= 0) then
    -- getpos returns {bufnum, lnum, col, off}
    local s_line, s_col = s_pos[2] - 1, math.max(0, s_pos[3] - 1)
    local e_line, e_col = e_pos[2] - 1, math.max(0, e_pos[3] - 1)
    if s_line ~= e_line or s_col ~= e_col then
      local sel_params = vim.lsp.util.make_range_params(0, "utf-8")
      sel_params.range = {
        start = { line = s_line, character = s_col },
        ["end"] = { line = e_line, character = e_col },
      }
      table.insert(params_list, sel_params)
    end
  end

  -- default probe ranges (point, line, word)
  params_list[#params_list + 1] = vim.lsp.util.make_range_params(0, "utf-8")
  local point_params = vim.lsp.util.make_position_params()
  params_list[#params_list + 1] = point_params
  local line_params = vim.lsp.util.make_range_params(0, "utf-8")
  line_params.range = {
    start = { line = line, character = 0 },
    ["end"] = { line = line, character = #line_text },
  }
  params_list[#params_list + 1] = line_params
  if word ~= "" then
    local word_params = vim.lsp.util.make_range_params(0, "utf-8")
    word_params.range = {
      start = { line = line, character = word_start },
      ["end"] = { line = line, character = word_end },
    }
    params_list[#params_list + 1] = word_params
  end

  local chosen_action
  local chosen_client

  for idx, params in ipairs(params_list) do
    params.context = {
      diagnostics = vim.diagnostic.get(bufnr),
      triggerKind = 1, -- Invoked
    }

    local results = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 2000)
    if results then
      for client_id, result in pairs(results) do
        local client = vim.lsp.get_client_by_id(client_id)

        -- Debug: collect titles when user enabled debug flag
        if vim.g.forge_debug_actions then
          local titles = {}
          for _, a in ipairs(result.result or {}) do
            table.insert(titles, a.title or vim.inspect(a))
          end
          vim.schedule(function()
            vim.notify(string.format("forge.lsp: client=%s params_idx=%d titles=%s", client.name or tostring(client_id), idx, table.concat(titles, " | ")), vim.log.levels.INFO)
          end)
        end

        for _, action in ipairs(result.result or {}) do
          if filter(action) then
            chosen_action = action
            chosen_client = client
            break
          end
        end
        if chosen_action then
          break
        end
      end
    end
    if chosen_action then
      break
    end
  end

  if not chosen_action then
    if fallback then
      fallback()
    end
    return false
  end

  if vim.g.forge_debug_actions and chosen_action then
    vim.schedule(function()
      vim.notify(string.format("forge.lsp: applying action '%s' (client=%s)", chosen_action.title or "<no title>", chosen_client and chosen_client.name or "?"), vim.log.levels.INFO)
    end)
  end

  return apply_code_action(chosen_action, chosen_client)
end

-- Return module

function M.has_code_action(filter)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1
  local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""

  local params_list = {
    vim.lsp.util.make_range_params(0, "utf-8"),
  }
  params_list[#params_list + 1] = vim.lsp.util.make_position_params()
  local line_params = vim.lsp.util.make_range_params(0, "utf-8")
  line_params.range = {
    start = { line = line, character = 0 },
    ["end"] = { line = line, character = #line_text },
  }
  params_list[#params_list + 1] = line_params

  for _, params in ipairs(params_list) do
    params.context = { diagnostics = vim.diagnostic.get(bufnr), triggerKind = 1 }
    local results = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 500)
    if results then
      for _, result in pairs(results) do
        for _, action in ipairs(result.result or {}) do
          if filter(action) then
            return true
          end
        end
      end
    end
  end
  return false
end

function M.has_rename()
  local bufnr = vim.api.nvim_get_current_buf()
  for _, client in ipairs(vim.lsp.get_active_clients({ bufnr = bufnr })) do
    local caps = client.server_capabilities or client.resolved_capabilities
    if caps and caps.renameProvider then
      return true
    end
  end
  return false
end

return M
