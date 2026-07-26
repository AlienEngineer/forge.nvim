local M = {}

-- Expand a class template. `__NAME__` is substituted with the user-supplied
-- name; the remaining `$0`/`${n:..}` tabstops are handled by `vim.snippet`.
function M.expand_class(template, name)
  local escaped = name:gsub("%%", "%%%%")
  local snippet = template:gsub("__NAME__", escaped)
  vim.snippet.expand(snippet)
end

return M
