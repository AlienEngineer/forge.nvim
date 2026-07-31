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
  "forge.field_inserters",
  "forge.health",
  "forge.actions.create_class",
  "forge.actions.create_field",
  "forge.actions.create_method",
  "forge.actions.create_typedef",
  "forge.actions.wrap_if",
  "forge.actions.wrap_for",
  "forge.actions.add_param",
  "forge.actions.toggle_field_final",
  "forge.actions.toggle_body",
  "forge.actions.inline_variable",
  "forge.actions.extract_variable",
  "forge.actions.extract_method",
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
for _, m in ipairs(vim.api.nvim_get_keymap("v")) do
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
check("keymap create_field (cf)", has_map("cf"))
check("keymap create_method (cm)", has_map("cm"))
check("keymap create_typedef (ctd)", has_map("td"))
check("keymap wrap_if (cwi)", has_map("wi"))
check("keymap wrap_for (cwf)", has_map("wf"))
check("keymap add_param (cp)", has_map("cp"))
check("keymap toggle_field_final (ctf)", has_map("ctf"))
check("keymap toggle_body (cb)", has_map("cb"))
check("keymap implement (ci)", has_map("ci"))
check("keymap inline_variable (cvi)", has_map("cvi"))
check("keymap extract_variable (cev)", has_map("cev"))
check("keymap extract_method (cem)", has_map("cem"))
check("keymap code_action (ca)", has_map("ca"))
check(":Forge command exists", vim.fn.exists(":Forge") == 2)

-- 3. config.lang resolves filetypes + aliases.
local config = require("forge.config")
check("lang(dart) resolves", config.lang("dart") ~= nil)
check("alias typescriptreact -> typescript", config.lang("typescriptreact") == config.lang("typescript"))
check("unknown filetype -> nil", config.lang("nonsense") == nil)

-- 3a. lsp.try_code_action: calls fallback when no LSP action matches.
local lsp_mod = require("forge.lsp")
local real_buf_request_sync = vim.lsp.buf_request_sync
local real_apply_workspace_edit = vim.lsp.util.apply_workspace_edit
local real_execute_command = vim.lsp.buf.execute_command

local fallback_called = false
local apply_called = false
local command_called = false
vim.lsp.buf_request_sync = function(_, _, _, _)
  return { [1] = { result = { { title = "Fix All" }, { title = "Organize Imports" } } } }
end
vim.lsp.util.apply_workspace_edit = function(_, _)
  apply_called = true
  return true
end
vim.lsp.buf.execute_command = function(_)
  command_called = true
end

lsp_mod.try_code_action(function(a) return (a.title or ""):lower():find("create class") ~= nil end, function()
  fallback_called = true
end)
check("try_code_action: fallback when no match", fallback_called == true and apply_called == false and command_called == false)

-- try_code_action: fires code_action when match found.
fallback_called = false
apply_called = false
command_called = false
vim.lsp.buf_request_sync = function(_, _, _, _)
  return { [1] = { result = { { title = "Create class 'Foo'", edit = {} }, { title = "Fix All" } } } }
end
lsp_mod.try_code_action(function(a) return (a.title or ""):lower():find("create class") ~= nil end, function()
  fallback_called = true
end)
check("try_code_action: fires code_action when match found", apply_called == true and fallback_called == false)

vim.lsp.buf_request_sync = real_buf_request_sync
vim.lsp.util.apply_workspace_edit = real_apply_workspace_edit
vim.lsp.buf.execute_command = real_execute_command

-- 4. create_class at top-level expands scaffold.
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.bo[buf].filetype = "dart"
require("forge.actions.create_class").run()
local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
check("create_class inserted class scaffold", text:find("class ", 1, true) ~= nil and text:find("{", 1, true) ~= nil)

-- 4a. create_class inside a class inserts AFTER the enclosing class.
vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "class Outer {", "  void m() {}", "}" })
pcall(vim.treesitter.start, buf, "dart")
vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside Outer
require("forge.actions.create_class").run()
local after_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
-- The original class must still be intact and the new scaffold must appear after it.
local outer_pos = after_text:find("class Outer", 1, true)
local new_pos = after_text:find("class ", outer_pos + 1, true)
check("create_class outside: new class after enclosing", outer_pos ~= nil and new_pos ~= nil and new_pos > outer_pos)

-- 5. create_class warns on unsupported filetype.
vim.bo[buf].filetype = "nonsense"
last_notify = nil
require("forge.actions.create_class").run()
check("create_class warns on unknown ft", last_notify ~= nil and last_notify.msg:find("no class template", 1, true) ~= nil)

-- 6. create_field inserts a field snippet inside the enclosing class.
vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "class Book {", "}", "" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
local real_input = vim.ui.input
require("forge.actions.create_field").run()
local field_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
check("create_field inserts field scaffold", field_text:find("Type", 1, true) ~= nil and field_text:find("name", 1, true) ~= nil)

-- 6a. create_method inserts a method scaffold inside the class.
vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "class Book {", "}" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
require("forge.actions.create_method").run()
local method_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
check("create_method inserts method scaffold", method_text:find("void", 1, true) ~= nil and method_text:find("name", 1, true) ~= nil)

-- create_method uses LSP code action on missing method call.
local create_method_mod = require("forge.actions.create_method")
local real_buf_request_sync2 = vim.lsp.buf_request_sync
local real_code_action2 = vim.lsp.buf.code_action
local create_method_called = false
vim.lsp.buf_request_sync = function(_, _, _, _)
  return { [1] = { result = { { title = "Create method 'newMethod' from type 'Xpto'", edit = {} }, { title = "Fix All" } } } }
end
vim.lsp.buf.code_action = function(opts)
  create_method_called = true
end
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "xpto.newMethod()" })
vim.api.nvim_win_set_cursor(0, { 1, 7 })
create_method_mod.run()
check("create_method uses lsp action", create_method_called == true)
vim.lsp.buf_request_sync = real_buf_request_sync2
vim.lsp.buf.code_action = real_code_action2

-- create_method outside class uses direct LSP path, not snippet fallback.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "template.sadfdsa();" })
vim.bo[buf].filetype = "dart"
local outside_direct = false
vim.lsp.buf.code_action = function(opts)
  outside_direct = true
  check(
    "create_method direct lsp filter",
    opts and opts.filter and opts.filter({ title = "Create method 'sadfdsa'" }) == true
  )
end
last_notify = nil
create_method_mod.run()
check("create_method outside class uses direct lsp", outside_direct == true and last_notify == nil)
vim.lsp.buf.code_action = real_code_action2

-- 6c. create_typedef: parser unit tests (pure Lua, no treesitter needed).
local ctd = require("forge.actions.create_typedef")

local n, p, rt = ctd._parse_braces_sig("void onCallback(String value) {")
check("parse_braces_sig: name", n == "onCallback")
check("parse_braces_sig: params", p == "String value")
check("parse_braces_sig: return_type", rt == "void")

local n2, p2, rt2 = ctd._parse_braces_sig("public static List<String> fetchAll(int page, bool flag) {")
check("parse_braces_sig: strips modifiers", n2 == "fetchAll")
check("parse_braces_sig: return type with generics", rt2 == "List<String>")

local n3, p3, rt3 = ctd._parse_ts_sig("onCallback(value: string): void {")
check("parse_ts_sig: name", n3 == "onCallback")
check("parse_ts_sig: params", p3 == "value: string")
check("parse_ts_sig: return_type", rt3 == "void")

local n4, p4, rt4 = ctd._parse_ts_sig("async fetchData(id: number): Promise<string> {")
check("parse_ts_sig: strips async", n4 == "fetchData")
check("parse_ts_sig: return type with generics", rt4 == "Promise<string>")

local n5, p5, rt5 = ctd._parse_py_sig("def on_callback(self, value: str, count: int) -> None:")
check("parse_py_sig: name", n5 == "on_callback")
check("parse_py_sig: strips self", p5:find("str") ~= nil and p5:find("int") ~= nil)
check("parse_py_sig: return_type", rt5 == "None")

local td_dart = ctd._build_typedef("dart", "onCallback", "String value", "void")
check("build_typedef dart: typedef keyword", td_dart:find("typedef", 1, true) ~= nil)
check("build_typedef dart: capitalized name", td_dart:find("OnCallback", 1, true) ~= nil)
check("build_typedef dart: Function keyword", td_dart:find("Function", 1, true) ~= nil)

local td_ts = ctd._build_typedef("typescript", "onCallback", "value: string", "void")
check("build_typedef ts: type keyword", td_ts:match("^type ") ~= nil)
check("build_typedef ts: arrow", td_ts:find("=>", 1, true) ~= nil)

local td_py = ctd._build_typedef("python", "on_callback", "str, int", "None")
check("build_typedef py: Callable", td_py:find("Callable", 1, true) ~= nil)
check("build_typedef py: capitalized name", td_py:find("On_callback", 1, true) ~= nil)

-- create_typedef warns when not in a method (no treesitter context).
vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "// top level" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
last_notify = nil
require("forge.actions.create_typedef").run()
check("create_typedef warns when not in method", last_notify ~= nil)

-- create_typedef warns on unsupported filetype.
vim.bo[buf].filetype = "nonsense"
last_notify = nil
require("forge.actions.create_typedef").run()
check("create_typedef warns on unsupported ft", last_notify ~= nil)

local field_ins = require("forge.field_inserters")
local fake_method = { range = function() return 0, 0 end }
local pb = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(pb, 0, -1, false, { "void foo() {", "}" })
local pr, pc, php = field_ins.find_param_insert_pos(pb, fake_method)
check("find_param_insert_pos row=0", pr == 0)
check("find_param_insert_pos col at )", pc == 9)
check("find_param_insert_pos no params", php == false)
local pb2 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(pb2, 0, -1, false, { "void foo(int a) {", "}" })
local _, _, php2 = field_ins.find_param_insert_pos(pb2, fake_method)
check("find_param_insert_pos detects existing params", php2 == true)

-- add_param warns when not inside a method.
vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "var x = 1;", "" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
last_notify = nil
require("forge.actions.add_param").run()
check("add_param warns when not in a method", last_notify ~= nil)

-- 6c. toggle_body warns when not inside a method.
vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "var x = 1;", "" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
last_notify = nil
require("forge.actions.toggle_body").run()
check("toggle_body warns when not in a method", last_notify ~= nil)

-- toggle_body works from inside one-line method.
local real_code_action2 = vim.lsp.buf.code_action
local action_called = false
vim.lsp.buf.code_action = function(opts)
  action_called = true
  local ok = opts and opts.filter and opts.filter({ title = "Convert to expression body" })
  check("toggle_body filter picks expression action", ok == true)
end
vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "int f() { return 1; }" })
pcall(vim.treesitter.start, buf, "dart")
vim.api.nvim_win_set_cursor(0, { 1, 10 })
last_notify = nil
require("forge.actions.toggle_body").run()
check("toggle_body runs from inside one-line method", action_called == true and last_notify == nil)
vim.lsp.buf.code_action = real_code_action2

-- toggle_body works from inside multi-line block body.
vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "int f() {",
  "  return 1;",
  "}",
})
vim.api.nvim_win_set_cursor(0, { 2, 3 })
action_called = false
vim.lsp.buf.code_action = function(opts)
  action_called = true
  check("toggle_body filter picks block action", opts and opts.filter and opts.filter({ title = "Convert to expression body" }) == true)
end
require("forge.actions.toggle_body").run()
check("toggle_body runs from inside multi-line body", action_called == true)
vim.lsp.buf.code_action = real_code_action2

-- 7. toggle_field_final toggles field keyword on/off.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "class Book {", "  String title;", "}" })
vim.api.nvim_win_set_cursor(0, { 2, 3 })
require("forge.actions.toggle_field_final").run()
local line_after_add = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1]
check("toggle_field_final adds final", line_after_add == "  final String title;")
require("forge.actions.toggle_field_final").run()
local line_after_remove = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1]
check("toggle_field_final removes final", line_after_remove == "  String title;")
local toggle = require("forge.actions.toggle_field_final")
local ts_on = toggle._toggle_keyword_in_line("private value: string;", "readonly")
check("toggle helper adds readonly after modifier", ts_on == "private readonly value: string;")
local ts_off = toggle._toggle_keyword_in_line("private readonly value: string;", "readonly")
check("toggle helper removes readonly", ts_off == "private value: string;")

-- 8. implement gracefully bails when not inside a class (no parser attached).
vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "void topLevel() {}", "" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
last_notify = nil
require("forge.actions.implement").run()
check("implement warns when not in a class", last_notify ~= nil)

-- 9. clause inserters (pure string logic, no LSP/treesitter needed).
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

-- 10. field inserters (template + indentation behaviour).
local field_inserters = require("forge.field_inserters")
local function run_field(style, lines, template, field_type, field_name)
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  field_inserters[style](b, fake_node, template, field_type, field_name)
  return table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
end
check(
  "field braces inserts after open brace",
  run_field("braces", { "class Foo {", "}" }, "__TYPE__ __NAME__;", "String", "title"):find(
    "class Foo {%s*\n%s*String title;%s*\n}",
    1
  ) ~= nil
)
check(
  "field python inserts under header",
  run_field("python", { "class Foo:", "    pass" }, "__NAME__: __TYPE__", "str", "title")
    == "class Foo:\n    title: str\n    pass"
)

-- 11. end-to-end with real treesitter parsers: locate the class, insert clause.
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

-- 11a. enclosing_method generic fallback finds method node via param-list child.
local function e2e_method(ft, lines, cursor_row)
  local b = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(b)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  vim.bo[b].filetype = ft
  pcall(vim.treesitter.start, b, ft)
  local pok, parser = pcall(vim.treesitter.get_parser, b, ft)
  if pok and parser then
    pcall(function()
      parser:parse(true)
    end)
  end
  vim.api.nvim_win_set_cursor(0, { cursor_row, 4 })
  local lang_cfg = config.lang(ft)
  return ts.enclosing_method(lang_cfg and lang_cfg.method_node_types or {}) ~= nil
end
check("e2e dart: enclosing_method found", e2e_method("dart", { "class Foo {", "  void bar() {", "  }", "}" }, 3))
check("e2e typescript: enclosing_method found", e2e_method("typescript", { "class Foo {", "  bar() {", "  }", "}" }, 3))
check("e2e python: enclosing_method found", e2e_method("python", { "class Foo:", "    def bar(self):", "        pass" }, 3))

-- 11b. wrap_if/wrap_for: block wrapping + snippet fallback.
vim.api.nvim_set_current_buf(buf)
vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "void f() {",
  "  for (var i = 0; i < 3; i++) {",
  "    print(i);",
  "  }",
  "}",
})
pcall(vim.treesitter.start, buf, "dart")
vim.api.nvim_win_set_cursor(0, { 2, 4 })
require("forge.actions.wrap_if").run()
local if_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
check("wrap_if wraps loop", if_text:find("if (condition)", 1, true) ~= nil and if_text:find("for (var i = 0", 1, true) ~= nil)
local if_cursor = vim.api.nvim_win_get_cursor(0)
local if_line = vim.api.nvim_buf_get_lines(buf, if_cursor[1] - 1, if_cursor[1], false)[1]
check("wrap_if cursor on condition", if_cursor[1] == 2 and if_line:sub(if_cursor[2] + 1, if_cursor[2] + 9) == "condition")

vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "print('x');" })
vim.api.nvim_win_set_cursor(0, { 1, 1 })
require("forge.actions.wrap_if").run()
local if_snippet_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
check("wrap_if snippet fallback", if_snippet_text:find("if", 1, true) ~= nil)

vim.api.nvim_set_current_buf(buf)
vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "void f() {",
  "  if (ready) {",
  "    print('ok');",
  "  }",
  "}",
})
pcall(vim.treesitter.start, buf, "dart")
vim.api.nvim_win_set_cursor(0, { 2, 4 })
require("forge.actions.wrap_for").run()
local for_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
check("wrap_for wraps block", for_text:find("for (var item in iterable)", 1, true) ~= nil and for_text:find("if (ready)", 1, true) ~= nil)

vim.bo[buf].filetype = "dart"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "recipes" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
require("forge.actions.wrap_for").run()
local for_snippet_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
check("wrap_for snippet uses iterable word", for_snippet_text:find("recipes", 1, true) ~= nil)

-- 12. picker: workspace/symbol query filtering (kinds + self-exclusion).
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
local type_candidates = picker._candidates("str", { bufnr = qbuf, literals = { "String", "int" }, kinds = { [5] = true, [11] = true } })
check("candidates include primitive types", type_candidates[1] and type_candidates[1].name == "String")
vim.lsp.buf_request_sync = real_request_sync

-- 13. picker falls back to vim.ui.input when Telescope is unavailable.
local input_called = false
vim.ui.input = function(_, _)
  input_called = true
end
picker.pick_symbol({ bufnr = qbuf, kinds = {}, on_choice = function() end })
check("pick_symbol uses fallback without telescope", input_called == true)
input_called = false
picker.pick_type({ bufnr = qbuf, kinds = {}, literals = { "String" }, on_choice = function() end })
check("pick_type uses fallback without telescope", input_called == true)
vim.ui.input = real_input

-- 14. health check runs without error.
check("health.check runs", pcall(require("forge.health").check))

print(("\n%d failure(s)"):format(failures))
if failures > 0 then
  os.exit(1)
end
