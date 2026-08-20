local M = {}

-- Per-language behaviour.
--   class_template     : LSP snippet string. `__NAME__` is replaced with the
--                        name typed in the input box; `$0`/`${1:..}` are real
--                        snippet tabstops expanded by `vim.snippet`.
--   class_node_types   : treesitter node types that count as "a class" when
--                        locating the enclosing class for the implement flow.
--   field_template     : template used by <prefix>f (create field).
--                        `__TYPE__` and `__NAME__` are replaced.
--   primitive_types    : built-in types offered in the field-type picker.
--   field_final_keyword: keyword toggled by <prefix>tf on current field line.
--   style              : which clause inserter to use ("braces" | "python").
--                        Omit to disable the implement flow for that language.
--   implements_keyword : keyword used by the "braces" inserter.
M.defaults = {
  prefix = "<leader>c",
  keymaps = {
    create_class = "nc", -- <prefix>nc
    create_field = "nf", -- <prefix>nf
    create_method = "nm", -- <prefix>nm
    create_typedef = "nt", -- <prefix>nt
    wrap_if = { key = "wi", modes = { "n", "v" } }, -- <prefix>wi
    wrap_for = { key = "wf", modes = { "n", "v" } }, -- <prefix>wf
    add_param = "p", -- <prefix>p
    toggle_field_final = "tf", -- <prefix>tf
    toggle_body = "b", -- <prefix>b
    implement = "i", -- <prefix>i
    inline_variable = "vi", -- <prefix>vi
    -- table form: { key, modes } for keymaps that apply to multiple modes
    extract_variable = { key = "ev", modes = { "n", "v" } }, -- <prefix>ev
    extract_method = { key = "em", modes = { "n", "v" } }, -- <prefix>em
    move_to_file = "mf", -- <prefix>mf
    move_all_to_files = "maf", -- <prefix>maf
    code_action = "a", -- <prefix>a
    comment_refactoring = "nr", -- <prefix>nr
    code_menu = { key = " ", modes = { "n", "v" } }, -- <prefix><space>
    duplicate_test = "d", -- <prefix>d
    help = "?", -- <prefix>?
  },
  -- Symbol kinds offered when picking an interface (LSP SymbolKind numbers).
  implement_symbol_kinds = { [5] = true, [11] = true }, -- Class, Interface
  -- Symbol kinds offered in the field type picker.
  field_type_symbol_kinds = { [5] = true, [11] = true, [23] = true, [10] = true }, -- Class, Interface, Struct, Enum
  -- Extra filetypes that should reuse another language's config.
  filetype_aliases = {
    typescriptreact = "typescript",
    javascriptreact = "javascript",
  },
  languages = {
    dart = {
      class_template = "class ${1:Name} {\n\t$0\n}",
      field_snippet = "${1:Type} ${2:name};",
      field_template = "__TYPE__ __NAME__;",
      -- Return type is tabstop 1 so LSP completion fires immediately.
      method_snippet = "${1:void} ${2:name}($3) {\n\t$0\n}",
      param_snippet = "${1:Type} ${2:name}",
      method_node_types = { method_declaration = true, function_declaration = true },
      primitive_types = {
        "String",
        "int",
        "double",
        "bool",
        "num",
        "dynamic",
        "Object",
        "List",
        "Map",
        "Set",
      },
      class_node_types = { class_definition = true },
      style = "braces",
      implements_keyword = "implements",
      field_final_keyword = "final",
      comment_prefix = "//",
    },
    java = {
      class_template = "public class ${1:Name} {\n\t$0\n}",
      field_snippet = "${1:Type} ${2:name};",
      field_template = "__TYPE__ __NAME__;",
      method_snippet = "${1:void} ${2:name}($3) {\n\t$0\n}",
      param_snippet = "${1:Type} ${2:name}",
      method_node_types = { method_declaration = true, constructor_declaration = true },
      primitive_types = {
        "String",
        "int",
        "long",
        "double",
        "float",
        "boolean",
        "char",
        "byte",
        "short",
        "Object",
        "List",
        "Map",
        "Set",
      },
      class_node_types = { class_declaration = true },
      style = "braces",
      implements_keyword = "implements",
      field_final_keyword = "final",
      comment_prefix = "//",
    },
    typescript = {
      class_template = "class ${1:Name} {\n\t$0\n}",
      field_snippet = "${1:name}: ${2:Type};",
      field_template = "__NAME__: __TYPE__;",
      -- Tabstop 1 is the return type (after `:`) so LSP completion fires first.
      method_snippet = "${2:name}($3): ${1:void} {\n\t$0\n}",
      param_snippet = "${2:name}: ${1:Type}",
      method_node_types = { method_definition = true, function_declaration = true },
      primitive_types = {
        "string",
        "number",
        "boolean",
        "bigint",
        "symbol",
        "unknown",
        "any",
        "void",
        "never",
        "object",
        "Array",
        "Record",
        "Map",
        "Set",
      },
      class_node_types = { class_declaration = true, abstract_class_declaration = true },
      style = "braces",
      implements_keyword = "implements",
      field_final_keyword = "readonly",
      comment_prefix = "//",
    },
    javascript = {
      -- JS has no `implements`, so only class scaffolding is enabled.
      class_template = "class ${1:Name} {\n\t$0\n}",
      method_snippet = "${1:name}($2) {\n\t$0\n}",
      param_snippet = "${1:name}",
      method_node_types = { method_definition = true, function_declaration = true },
      class_node_types = { class_declaration = true },
      comment_prefix = "//",
    },
    python = {
      class_template = "class ${1:Name}:\n\t$0",
      field_snippet = "${1:name}: ${2:Type}",
      field_template = "__NAME__: __TYPE__",
      -- Tabstop 1 is the return type (after `->`) so LSP completion fires first.
      method_snippet = "def ${2:name}(self$3) -> ${1:None}:\n\t$0",
      param_snippet = "${2:name}: ${1:Type}",
      method_node_types = { function_definition = true },
      primitive_types = {
        "str",
        "int",
        "float",
        "bool",
        "bytes",
        "list",
        "dict",
        "set",
        "tuple",
        "Any",
        "object",
      },
      class_node_types = { class_definition = true },
      style = "python",
      comment_prefix = "#",
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
