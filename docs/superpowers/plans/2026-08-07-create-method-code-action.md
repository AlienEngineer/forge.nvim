# Create Method Code Action Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `<leader>cm` auto-apply Dart Analysis Server's `Create method 'fromMap'` code action and reject unrelated create actions.

**Architecture:** Replace the permissive title keyword filter in
`forge.actions.create_method` with a case-insensitive full-title pattern for
quoted create-method actions. Preserve current LSP probing, application, and
snippet fallback paths. Add smoke tests through the exported filter and the
existing mocked LSP action flow.

**Tech Stack:** Lua, Neovim LSP API, headless Neovim smoke tests.

## Global Constraints

- Support Neovim 0.10+.
- Do not change keymaps, LSP request handling, code-action application, or
  snippet insertion behavior.
- Match only `Create method '…'` action titles, case-insensitively.
- Keep existing snippet fallback inside classes and filtered LSP picker outside
  classes.

---

### Task 1: Narrow Create-Method Action Selection

**Files:**
- Modify: `lua/forge/actions/create_method.lua:8-21`
- Modify: `tests/smoke.lua:179-211`

**Interfaces:**
- Consumes: an LSP CodeAction-like table with optional `title: string`.
- Produces: `M._create_method_filter(action) -> boolean`, true only for a
  case-insensitive complete match of `Create method 'name'`.

- [ ] **Step 1: Write failing filter tests**

Add these assertions immediately before the existing mocked create-method LSP
test:

```lua
local create_method_mod = require("forge.actions.create_method")
local create_method_filter = create_method_mod._create_method_filter

check("create_method filter matches Dart action", create_method_filter({ title = "Create method 'fromMap'" }))
check("create_method filter ignores case", create_method_filter({ title = "CREATE METHOD 'fromMap'" }))
check("create_method filter rejects function", not create_method_filter({ title = "Create function 'fromMap'" }))
check("create_method filter rejects class", not create_method_filter({ title = "Create class 'SwaggerParameter'" }))
check("create_method filter rejects implement", not create_method_filter({ title = "Implement members" }))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`

Expected: `create_method filter matches Dart action` passes, while at least one
of the rejection checks fails because the current broad filter accepts it.

- [ ] **Step 3: Replace broad filter**

Replace the keyword conditions in `create_method_filter` with:

```lua
local function create_method_filter(action)
  local title = action.title or ""
  return title:lower():match("^create method '[^']+'$") ~= nil
end
```

This accepts only complete quoted create-method titles and leaves `M.run()`'s
existing `lsp.try_code_action` and fallback calls unchanged.

- [ ] **Step 4: Update mocked LSP action title**

In existing create-method smoke test, change:

```lua
{ title = "Create method 'newMethod' from type 'Xpto'", edit = {} }
```

to:

```lua
{ title = "Create method 'newMethod'", edit = {} }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `make test`

Expected: all smoke checks report `ok`; process exits zero.

- [ ] **Step 6: Check formatting**

Run: `make lint`

Expected: Stylua reports no formatting violations.

- [ ] **Step 7: Commit**

```bash
git add lua/forge/actions/create_method.lua tests/smoke.lua
git commit -m "fix: select exact create method action" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```
