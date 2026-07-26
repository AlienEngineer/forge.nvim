.PHONY: test lint

# Headless test suite (requires Neovim >= 0.10 with bundled treesitter parsers).
test:
	nvim -l tests/smoke.lua

# Optional: format check if stylua is installed.
lint:
	stylua --check .
