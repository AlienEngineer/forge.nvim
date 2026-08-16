# forge.nvim

Keybind-driven code generation for Neovim. **forge does not generate code
itself** — it is a thin dispatch layer that wires a few ergonomic keymaps to
tools that already do the hard work:

| Keymap        | Action            | Powered by                                            |
| ------------- | ----------------- | ----------------------------------------------------- |
| `<leader>cc`  | Create a class    | `vim.snippet` (native snippet templates)              |
| `<leader>cf`  | Create a field    | name prompt + live type picker (primitives + `workspace/symbol`) |
| `<leader>ctf` | Toggle field final| line-level toggle (`final`/`readonly`) inside class   |
| `<leader>ci`  | Implement an interface | live `workspace/symbol` picker + treesitter + LSP code action |
| `<leader>ca`  | Code actions      | `vim.lsp.buf.code_action` (passthrough)               |
| `<leader>cnr` | Add refactoring comment | inserts language-aware `Refactoring:` comment above current line |

The philosophy: language-aware generation (stubbing interface members,
scaffolding) is already solved by LSP servers, treesitter and snippets. forge
just gives you one consistent set of keybinds on top of them, so nothing has to
be re-implemented per language.

## Requirements

- Neovim **0.10+** (`vim.snippet`, `vim.lsp.buf_request_sync`)
- A configured LSP server for your language (for `<leader>ci` / `<leader>ca`)
- Treesitter parser for your language (for `<leader>ci`)
- Optional but recommended:
  [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) — turns
  `<leader>ci` into a **single live picker**: one popup that searches base-class
  / interface candidates via `workspace/symbol` as you type. Without it,
  `<leader>ci` falls back to a query prompt + `vim.ui.select`.

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
    create_field = "f", -- <leader>cf
    toggle_field_final = "tf", -- <leader>ctf
    implement    = "i", -- <leader>ci
    code_action  = "a", -- <leader>ca
    comment_refactoring = "nr", -- <leader>cnr
    help         = "?", -- <leader>c?
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

You can also drive everything through `:Forge <create_class|create_field|toggle_field_final|implement|code_action|comment_refactoring>`.

## Usage

- **Create class** — `<leader>cc`, type a name, a class snippet is expanded at
  the cursor with working tabstops.
- **Create field** — `<leader>cf`, type field name, then pick field type from
  one live popup. The picker includes language primitives (e.g. `String`) plus
  matching workspace symbols.
- **Toggle field final** — `<leader>ctf` on a field line inside a class toggles
  field immutability keyword on/off (`final` for dart/java, `readonly` for
  typescript).
- **Implement interface** — put the cursor inside a class, `<leader>ci`. A single
  picker opens; as you type it live-searches base-class / interface candidates
  via `workspace/symbol`. Pick one and forge inserts the `implements` clause and
  asks the LSP to stub the members. (The current class is excluded from results.)
- **Code actions** — `<leader>ca` opens the LSP code-action menu.
- **Refactoring comment** — `<leader>cnr` inserts `Refactoring: ` as a language-aware
  comment above current line and places cursor after colon.
- **Help** — `<leader>c?` opens a searchable popup listing every configured
  action, its keymap, and description (Telescope fuzzy-find if installed,
  `vim.ui.select` fallback otherwise).

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

## Development and CI

CI runs `make lint` and `make test` for every pull request and push to `main`.
The root [`VERSION`](VERSION) file is the repository's semantic version marker
and must contain one `MAJOR.MINOR.PATCH` value. After successful checks on
`main`, CI creates one patch-version commit with `[skip ci]`; that generated
commit does not start another CI run.

## Limitations

- The `braces` clause inserter is line-based; it handles single-line and simple
  multi-line class headers. Exotic headers may need a manual tweak.
- The implement step relies on the LSP exposing an "implement / add missing
  members" code action. Coverage varies by server.
- The live picker queries `workspace/symbol` synchronously per keystroke (short
  timeout). Snappy in practice; very large workspaces may feel it.
