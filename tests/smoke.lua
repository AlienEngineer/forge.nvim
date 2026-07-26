-- Headless smoke test for forge.nvim. Run with: make test  (or `nvim -l tests/smoke.lua`)
local script = debug.getinfo(1, "S").source:sub(2)
local plugin_dir = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.runtimepath:prepend(plugin_dir)

local failures = 0
local function check(name, cond)
  if cond then
    print("ok   - " .. name)
  else
    failures = failures + 1
    print("FAIL - " .. name)
  end
end

-- Capture notifications so warn-paths don't spam / can be asserted.
local last_notify
vim.notify = function(msg, level)
  last_notify = { msg = msg, level = level }
end

-- 1. All modules load (catches syntax errors).
for _, mod in ipairs({
  "forge",
  "forge.config",
  "forge.ts",
  "forge.lsp",
  "forge.snippet",
  "forge.picker",
  "forge.health",
  "forge.actions.create_class",
  "forge.actions.implement",
  "forge.actions.code_action",
}) do
  local ok = pcall(require, mod)
  check("require " .. mod, ok)
end

-- 2. setup() wires keymaps + command.
require("forge").setup()
local maps = {}
for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
  maps[m.lhs] = m.desc
end
-- <leader> defaults to "\"
local function has_map(suffix)
  for lhs, desc in pairs(maps) do
    if lhs:sub(-#suffix) == suffix and (desc or ""):find("Forge") then
      return true
    end
  end
  return false
end
check("keymap create_class (cc)", has_map("cc"))
check("keymap implement (ci)", has_map("ci"))
check("keymap code_action (ca)", has_map("ca"))
check(":Forge command exists", vim.fn.exists(":Forge") == 2)

-- 3. config.lang resolves filetypes + aliases.
local config = require("forge.config")
check("lang(dart) resolves", config.lang("dart") ~= nil)
check("alias typescriptreact -> typescript", config.lang("typescriptreact") == config.lang("typescript"))
check("unknown filetype -> nil", config.lang("nonsense") == nil)

-- 4. create_class expands a snippet into the buffer.
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.bo[buf].filetype = "dart"
vim.ui.input = function(_, cb)
  cb("Widget")
end
require("forge.actions.create_class").run()
local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
check("create_class inserted 'class Widget'", text:find("class Widget", 1, true) ~= nil)

-- 5. create_class warns on unsupported filetype.
vim.bo[buf].filetype = "nonsense"
last_notify = nil
require("forge.actions.create_class").run()
check("create_class warns on unknown ft", last_notify ~= nil and last_notify.msg:find("no class template", 1, true) ~= nil)

-- 6. implement gracefully bails when not inside a class (no parser attached).
vim.bo[buf].filetype = "dart"
last_notify = nil
require("forge.actions.implement").run()
check("implement warns when not in a class", last_notify ~= nil)

-- 7. clause inserters (pure string logic, no LSP/treesitter needed).
local inserters = require("forge.inserters")
local fake_node = { range = function() return 0, 0 end }
local function run_inserter(style, lines, iface, kw)
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  inserters[style](b, fake_node, iface, kw or "implements")
  return table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
end

check("braces: bare class", run_inserter("braces", { "class Foo {", "}" }, "I") == "class Foo implements I {\n}")
check(
  "braces: with extends",
  run_inserter("braces", { "class Foo extends Bar {", "}" }, "I") == "class Foo extends Bar implements I {\n}"
)
check(
  "braces: appends to existing implements",
  run_inserter("braces", { "class Foo implements A {", "}" }, "B") == "class Foo implements A, B {\n}"
)
check(
  "braces: multi-line header",
  run_inserter("braces", { "class Foo", "    extends Bar {", "}" }, "I")
    == "class Foo\n    extends Bar implements I {\n}"
)
check("braces: one-liner", run_inserter("braces", { "class Foo {}" }, "I") == "class Foo implements I {}")
check("python: bare class", run_inserter("python", { "class A:", "    pass" }, "I") == "class A(I):\n    pass")
check(
  "python: existing base",
  run_inserter("python", { "class A(Base):", "    pass" }, "I") == "class A(Base, I):\n    pass"
)
check("python: empty parens", run_inserter("python", { "class A():", "    pass" }, "I") == "class A(I):\n    pass")

-- 8. end-to-end with real treesitter parsers: locate the class, insert clause.
local ts = require("forge.ts")
local function e2e(ft, lang_key, lines, cursor_row, expect)
  local b = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(b)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  vim.bo[b].filetype = ft
  pcall(vim.treesitter.start, b, ft)
  vim.api.nvim_win_set_cursor(0, { cursor_row, 2 })
  local lang = config.lang(lang_key)
  local node = ts.enclosing_class(lang.class_node_types)
  if not node then
    check("e2e " .. ft .. ": found class node", false)
    return
  end
  inserters[lang.style](b, node, "I", lang.implements_keyword or "implements")
  local text = table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
  check("e2e " .. ft .. ": inserted clause", text:find(expect, 1, true) ~= nil)
end

e2e("dart", "dart", { "class Foo {", "  void bar() {}", "}" }, 2, "class Foo implements I {")
e2e("java", "java", { "class Foo {", "  void bar() {}", "}" }, 2, "class Foo implements I {")
e2e("typescript", "typescript", { "class Foo {", "  bar() {}", "}" }, 2, "class Foo implements I {")
e2e("python", "python", { "class Foo:", "    def bar(self):", "        pass" }, 2, "class Foo(I):")

-- 9. picker: workspace/symbol query filtering (kinds + self-exclusion).
local picker = require("forge.picker")
local real_request_sync = vim.lsp.buf_request_sync
vim.lsp.buf_request_sync = function(_, _, _, _)
  return {
    [1] = {
      result = {
        { name = "Comparable", kind = 11, location = { uri = "file:///a.dart" } }, -- Interface
        { name = "Widget", kind = 5, location = { uri = "file:///b.dart" } }, -- Class
        { name = "myVar", kind = 13, location = { uri = "file:///c.dart" } }, -- Variable (filtered out)
        { name = "Self", kind = 5, location = { uri = "file:///d.dart" } }, -- excluded by name
      },
    },
  }
end
local qbuf = vim.api.nvim_create_buf(true, false)
local got = picker._query_symbols("x", { bufnr = qbuf, kinds = { [5] = true, [11] = true }, exclude = "Self" })
local names = {}
for _, s in ipairs(got) do
  names[s.name] = true
end
check("query keeps Interface (kind 11)", names["Comparable"] == true)
check("query keeps Class (kind 5)", names["Widget"] == true)
check("query drops Variable (kind 13)", names["myVar"] == nil)
check("query drops excluded self name", names["Self"] == nil)
check("query returns {} for empty prompt", #picker._query_symbols("", { bufnr = qbuf }) == 0)
vim.lsp.buf_request_sync = real_request_sync

-- 10. picker falls back to vim.ui.input when Telescope is unavailable.
local input_called = false
vim.ui.input = function(_, _)
  input_called = true
end
picker.pick_symbol({ bufnr = qbuf, kinds = {}, on_choice = function() end })
check("pick_symbol uses fallback without telescope", input_called == true)

-- 11. health check runs without error.
check("health.check runs", pcall(require("forge.health").check))

print(("\n%d failure(s)"):format(failures))
if failures > 0 then
  os.exit(1)
end
