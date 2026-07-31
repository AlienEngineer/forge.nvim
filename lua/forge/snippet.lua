local M = {}

-- Expand a snippet template. Templates use `$0`/`${n:placeholder}` tabstop
-- syntax handled by `vim.snippet`. No substitution is done here.
function M.expand_class(template)
  vim.snippet.expand(template)
end

return M
