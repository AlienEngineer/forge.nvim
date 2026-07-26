-- Guard against double-loading. Actual wiring happens in
-- require("forge").setup(), so installing without calling setup() is inert.
if vim.g.loaded_forge then
  return
end
vim.g.loaded_forge = true
