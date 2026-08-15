# AGENTS.md

`forge.nvim` is a Neovim plugin that wires ergonomic keymaps and `:Forge` subcommands to LSP, treesitter, and `vim.snippet`-based refactoring/scaffolding actions. Core code lives in `lua/forge/`, entrypoints are `plugin/forge.lua` and `lua/forge/init.lua`, and tests are in `tests/smoke.lua`.

## Key files
- `lua/forge/config.lua` — default keymaps, per-language templates, symbol kinds, and filetype aliases.
- `lua/forge/*.lua` — action implementations, picker helpers, LSP/treesitter integration, and shared inserters.
- `plugin/forge.lua` — guarded plugin loader; real setup happens in `require("forge").setup()`.
- `Makefile` — repo commands.
- `stylua.toml` — formatting rules.

## Commands
- Test: `make test`
- Lint/format check: `make lint`
- Direct test runner: `nvim -l tests/smoke.lua`
- Direct format check: `stylua --check .`

## Conventions
- Lua only; use 2-space indentation and double quotes to match `stylua.toml`.
- Keep additions aligned with existing action/config patterns in `lua/forge/init.lua` and `lua/forge/config.lua`.
- New user-facing actions should be wired in both `lua/forge/init.lua` and the default keymaps in `lua/forge/config.lua`.
- Prefer small, language-aware helpers over generic abstractions; this plugin intentionally delegates work to LSP/treesitter/snippets.
