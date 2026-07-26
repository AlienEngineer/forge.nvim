# forge.nvim

Keybind-driven code generation for Neovim. **forge does not generate code
itself** — it is a thin dispatch layer that wires a few ergonomic keymaps to
tools that already do the hard work:

| Keymap        | Action            | Powered by                                            |
| ------------- | ----------------- | ----------------------------------------------------- |
| `<leader>cc`  | Create a class    | `vim.snippet` (native snippet templates)              |
| `<leader>ci`  | Implement an interface | `workspace/symbol` + treesitter + LSP code action |
| `<leader>ca`  | Code actions      | `vim.lsp.buf.code_action` (passthrough)               |

The philosophy: language-aware generation (stubbing interface members,
scaffolding) is already solved by LSP servers, treesitter and snippets. forge
just gives you one consistent set of keybinds on top of them, so nothing has to
be re-implemented per language.

## Requirements

- Neovim **0.10+** (`vim.snippet`, `vim.lsp.buf_request_all`)
- A configured LSP server for your language (for `<leader>ci` / `<leader>ca`)
- Treesitter parser for your language (for `<leader>ci`)
- Optional: [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
  with [telescope-ui-select](https://github.com/nvim-telescope/telescope-ui-select.nvim)
  — turns the interface / code-action pickers into fuzzy finders.

## Install (lazy.nvim)

```lua
{
  "your-username/forge.nvim",
  event = "VeryLazy",
  opts = {},
}
```

`opts = {}` calls `require("forge").setup()`. Nothing is wired until setup runs.

## Configuration

Defaults (override any subset via `opts`):

```lua
require("forge").setup({
  prefix = "<leader>c",
  keymaps = {
    create_class = "c", -- <leader>cc
    implement    = "i", -- <leader>ci
    code_action  = "a", -- <leader>ca
  },
  implement_symbol_kinds = { [5] = true, [11] = true }, -- Class, Interface
  filetype_aliases = {
    typescriptreact = "typescript",
    javascriptreact = "javascript",
  },
  languages = {
    -- see lua/forge/config.lua for the full default table
  },
})
```

You can also drive everything through `:Forge <create_class|implement|code_action>`.

## Usage

- **Create class** — `<leader>cc`, type a name, a class snippet is expanded at
  the cursor with working tabstops.
- **Implement interface** — put the cursor inside a class, `<leader>ci`, type a
  query, pick the interface. forge inserts the `implements` clause and asks the
  LSP to stub the members.
- **Code actions** — `<leader>ca` opens the LSP code-action menu.

## Extending

Add a language by dropping an entry into `languages`:

```lua
require("forge").setup({
  languages = {
    kotlin = {
      class_template = "class __NAME__ {\n\t$0\n}",
      class_node_types = { class_declaration = true },
      style = "braces",
      implements_keyword = ":", -- Kotlin uses ` : Iface`
    },
  },
})
```

- `class_template` — an LSP snippet string. `__NAME__` becomes the typed name;
  `$0` / `${1:..}` are real tabstops.
- `class_node_types` — treesitter node types that count as "a class".
- `style` — `"braces"` or `"python"`. Omit to disable the implement flow.
- `implements_keyword` — used by the `braces` inserter.

Ships with defaults for **dart, java, typescript, javascript, python**.

## Health

```
:checkhealth forge
```

## Limitations (first iteration)

- The `braces` clause inserter is line-based; it handles single-line and simple
  multi-line class headers. Exotic headers may need a manual tweak.
- The implement step relies on the LSP exposing an "implement / add missing
  members" code action. Coverage varies by server.
- The picker is a query box + `vim.ui.select` (fuzzy via telescope-ui-select),
  not yet a live-updating telescope picker. On the roadmap.
