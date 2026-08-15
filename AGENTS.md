# forge.nvim — Agents Handbook

## Project

Neovim plugin for keybind-driven code generation. Thin dispatch layer wiring ergonomic keymaps (`<leader>c*`) to LSP, Treesitter, and snippet templates. Does not generate code itself — orchestrates existing tools.

**Key Actions:**
- `<leader>cc` — Create class (snippet template)
- `<leader>cf` — Create field (type picker: primitives + workspace symbols)
- `<leader>ctf` — Toggle field immutability (`final`, `readonly`)
- `<leader>ci` — Implement interface (search base-class/interface via workspace/symbol + stub members)
- `<leader>ca` — Code actions (passthrough to LSP)
- `<leader>cnr` — Refactoring comment (language-aware)

## Architecture

**Modular handler per action:**
- `lua/forge/actions/*.lua` — one file per action. Each exports `.run()` entrypoint.
- `lua/forge/config.lua` — defaults, language configs, keymap setup.
- `lua/forge/lsp.lua` — LSP queries (workspace/symbol, code actions).
- `lua/forge/ts.lua` — Treesitter queries and node navigation.
- `lua/forge/picker.lua` — Telescope-backed symbol picker (fallback: vim.ui.select).
- `lua/forge/field_inserters.lua` — language-specific field/member insertion logic.
- `lua/forge/snippet.lua` — snippet expansion via vim.snippet.
- `lua/forge/health.lua` — `:checkhealth forge` diagnostics.

## Key Directories

- `lua/forge/` — Core plugin logic (init, config, utilities).
- `lua/forge/actions/` — Individual action handlers.
- `plugin/forge.lua` — Entry point (defines `:Forge` command, loads plugin).
- `tests/smoke.lua` — Headless smoke test suite.

## Build & Test

```bash
# Run headless smoke tests (requires Neovim >= 0.10 with bundled Treesitter)
make test
# or
nvim -l tests/smoke.lua

# Format check (if stylua installed)
make lint

# Format (apply)
stylua .
```

**Requirements:**
- Neovim 0.10+ (vim.snippet, vim.lsp.buf_request_sync, bundled Treesitter)
- LSP server for target language
- Treesitter parser for target language (for implement flow)
- Optional: telescope.nvim (fallback: vim.ui.select)

## Conventions

**Language Config:**
Each language entry in `config.languages` needs:
- `class_template` — LSP snippet string; `__NAME__` → typed name, `$0`/`${1:..}` → tabstops.
- `class_node_types` — table mapping Treesitter node types to `true` (e.g. `{ class_declaration = true }`).
- `style` — `"braces"` or `"python"` (omit to disable implement flow).
- `implements_keyword` — string used in implements clause (e.g. `":"` for Kotlin).

**Builtin languages:** dart, java, typescript, javascript, python.

**Action Handler Pattern:**
```lua
local M = {}

function M.run()
  -- Entry point. Called by keybind or :Forge command.
  -- Use config.current_lang to get language config.
  -- Raise errors with require("forge.error").bail(msg).
end

return M
```

**Formatting:**
- stylua.toml: 120-char columns, 2-space indent, Unix line endings.
- All Lua files in `lua/forge/` and `plugin/` must pass `stylua --check .`.

**Testing:**
- Tests in `tests/smoke.lua` run headless. No UI. Assert behavior via mock LSP responses and Treesitter queries.
- Use `check(name, cond)` helper to track pass/fail.

## Notes for Agents

- Language-specific logic lives in config, not hardcoded. Extend via `languages` dict.
- Implement flow (lookup, stub members) relies on LSP code-action support; coverage varies by server.
- Picker uses workspace/symbol synchronously with short timeout for snappiness.
- Line-based clause inserter (braces style) handles single and simple multi-line class headers; exotic cases may need manual fix.
