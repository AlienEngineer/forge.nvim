local M = {}

-- Per-language behaviour.
--   class_template     : LSP snippet string. `__NAME__` is replaced with the
--                        name typed in the input box; `$0`/`${1:..}` are real
--                        snippet tabstops expanded by `vim.snippet`.
--   class_node_types   : treesitter node types that count as "a class" when
--                        locating the enclosing class for the implement flow.
--   style              : which clause inserter to use ("braces" | "python").
--                        Omit to disable the implement flow for that language.
--   implements_keyword : keyword used by the "braces" inserter.
M.defaults = {
  prefix = "<leader>c",
  keymaps = {
    create_class = "c", -- <prefix>c
    implement = "i", -- <prefix>i
    code_action = "a", -- <prefix>a
  },
  -- Symbol kinds offered when picking an interface (LSP SymbolKind numbers).
  implement_symbol_kinds = { [5] = true, [11] = true }, -- Class, Interface
  -- Extra filetypes that should reuse another language's config.
  filetype_aliases = {
    typescriptreact = "typescript",
    javascriptreact = "javascript",
  },
  languages = {
    dart = {
      class_template = "class __NAME__ {\n\t$0\n}",
      class_node_types = { class_definition = true },
      style = "braces",
      implements_keyword = "implements",
    },
    java = {
      class_template = "public class __NAME__ {\n\t$0\n}",
      class_node_types = { class_declaration = true },
      style = "braces",
      implements_keyword = "implements",
    },
    typescript = {
      class_template = "class __NAME__ {\n\t$0\n}",
      class_node_types = { class_declaration = true, abstract_class_declaration = true },
      style = "braces",
      implements_keyword = "implements",
    },
    javascript = {
      -- JS has no `implements`, so only class scaffolding is enabled.
      class_template = "class __NAME__ {\n\t$0\n}",
      class_node_types = { class_declaration = true },
    },
    python = {
      class_template = "class __NAME__:\n\t$0",
      class_node_types = { class_definition = true },
      style = "python",
    },
  },
}

M.active = nil

function M.set(cfg)
  M.active = cfg
end

function M.get()
  return M.active or M.defaults
end

-- Resolve the language config for a filetype, honouring aliases.
function M.lang(ft)
  local cfg = M.get()
  local key = cfg.filetype_aliases[ft] or ft
  return cfg.languages[key]
end

return M
