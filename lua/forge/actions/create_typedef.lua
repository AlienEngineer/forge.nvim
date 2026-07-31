local config = require("forge.config")
local ts = require("forge.ts")

local M = {}

-- Collect signature text from start_row, joining lines until we see balanced
-- parentheses (end of param list). Strips leading indent.
local function sig_text(bufnr, start_row)
  local parts = {}
  local depth = 0
  local found_open = false
  local continued = false
  for i = start_row, start_row + 8 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
    if not line then break end
    local stripped = (continued and line:gsub("^%s+", "") or line:gsub("^%s+", ""))
    continued = true
    table.insert(parts, stripped)
    for c in stripped:gmatch(".") do
      if c == "(" then
        depth = depth + 1
        found_open = true
      elseif c == ")" then
        depth = depth - 1
      end
    end
    -- Stop once the parameter list is closed (balanced parens).
    -- For TS/Java we also need the return type annotation on the same line —
    -- but that comes AFTER `)`, so the loop continues one more line if needed.
    if found_open and depth == 0 then
      -- Check if this line also contains `{` or ends the sig naturally.
      -- Either way, we have enough to parse.
      break
    end
  end
  return table.concat(parts, " ")
end

-- MODIFIERS to strip before the return type / name pair.
local MODIFIERS = {
  public = true,
  private = true,
  protected = true,
  static = true,
  final = true,
  abstract = true,
  synchronized = true,
  override = true,
  default = true,
  async = true,
}

-- Parse "ReturnType name(params) {" (Dart, Java, C#-style)
-- Returns name, params, return_type — or nil if unparseable.
local function parse_braces_sig(raw)
  -- Strip everything from `{` onward (function body start).
  local sig = raw:match("^(.-)%s*{") or raw
  sig = sig:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  -- Extract the param list from the last balanced parens.
  local before_paren, params = sig:match("^(.-)%((.*)%)%s*$")
  if not before_paren then return nil end
  local tokens = {}
  for t in before_paren:gmatch("%S+") do
    tokens[#tokens + 1] = t
  end
  if #tokens < 1 then return nil end
  -- Last token is the method name; everything before is [modifiers +] return type.
  local name = tokens[#tokens]
  -- Strip leading modifiers to get just the return type.
  local type_start = 1
  while type_start < #tokens and MODIFIERS[tokens[type_start]] do
    type_start = type_start + 1
  end
  local return_type = table.concat(tokens, " ", type_start, #tokens - 1)
  if return_type == "" then return_type = "void" end
  return name, params, return_type
end

-- Parse "name(params): returnType {" (TypeScript / JavaScript)
local function parse_ts_sig(raw)
  local sig = raw:match("^(.-)%s*{") or raw
  sig = sig:gsub("^%s*async%s+", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  local name = sig:match("^([%w_$]+)%(")
  if not name then return nil end
  local params = sig:match("%((.-)%)")
  -- Return type follows "):"; strip generic qualifiers like "Promise<..."
  local return_type = sig:match("%)%s*:%s*(.+)$") or "void"
  return_type = return_type:gsub("%s+$", "")
  return name, params or "", return_type
end

-- Parse "def name(self, params) -> return_type:" (Python)
local function parse_py_sig(raw)
  local sig = raw:gsub("^%s*def%s+", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  local name = sig:match("^([%w_]+)%(")
  if not name then return nil end
  -- Find matching close paren (handles nested parens in type annotations).
  local open_pos = sig:find("%(")
  if not open_pos then return nil end
  local depth = 0
  local close_pos
  for i = open_pos, #sig do
    local c = sig:sub(i, i)
    if c == "(" then
      depth = depth + 1
    elseif c == ")" then
      depth = depth - 1
      if depth == 0 then
        close_pos = i
        break
      end
    end
  end
  if not close_pos then return nil end
  local params = sig:sub(open_pos + 1, close_pos - 1)
  -- Remove self / cls (first positional param).
  params = params:gsub("^self%s*,?%s*", ""):gsub("^cls%s*,?%s*", "")
  -- Extract only type annotations for the Callable signature.
  local types = {}
  for pair in (params .. ","):gmatch("([^,]+),") do
    local typ = pair:match(":%s*([^=,]+)") or pair:gsub("^%s+", ""):gsub("%s+$", "")
    typ = typ:gsub("^%s+", ""):gsub("%s+$", "")
    if typ ~= "" then types[#types + 1] = typ end
  end
  params = table.concat(types, ", ")
  -- Return type lives after `) ->` and before the trailing `:`.
  local after = sig:sub(close_pos + 1)
  local return_type = after:match("%->%s*(.-)%s*:?%s*$") or "None"
  return_type = return_type:gsub("%s+$", "")
  return name, params, return_type
end

local function capitalize(s)
  return s:sub(1, 1):upper() .. s:sub(2)
end

-- Build the typedef snippet string for a given language.
-- The method name (capitalized) is tabstop 1 so the user can rename it.
local function build_typedef(real_ft, name, params, return_type)
  local cap = capitalize(name)
  if real_ft == "dart" then
    return ("typedef ${1:%s} = %s Function(%s);"):format(cap, return_type, params)
  elseif real_ft == "typescript" or real_ft == "javascript" then
    return ("type ${1:%s} = (%s) => %s;"):format(cap, params, return_type)
  elseif real_ft == "java" then
    return ("@FunctionalInterface\ninterface ${1:%s} {\n\t%s apply(%s);\n}"):format(
      cap,
      return_type,
      params
    )
  elseif real_ft == "python" then
    local type_list = params ~= "" and params or ""
    return ("${1:%s}: TypeAlias = Callable[[%s], %s]"):format(cap, type_list, return_type)
  end
  return nil
end

-- Export helpers for unit testing.
M._parse_braces_sig = parse_braces_sig
M._parse_ts_sig = parse_ts_sig
M._parse_py_sig = parse_py_sig
M._build_typedef = build_typedef

-- <prefix>td : generate a type definition from the enclosing method signature.
-- The typedef is inserted on a new line above the enclosing class.
function M.run()
  local ft = vim.bo.filetype
  local lang = config.lang(ft)
  if not lang or not lang.class_node_types then
    vim.notify(("forge: ctd not supported for filetype '%s'"):format(ft), vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local cfg = config.get()
  local real_ft = cfg.filetype_aliases[ft] or ft

  -- Find the enclosing method first.
  local method_node = ts.enclosing_method(lang.method_node_types or {})
  if not method_node then
    vim.notify("forge: cursor is not inside a method", vim.log.levels.WARN)
    return
  end

  -- Read and parse the method signature.
  local srow = method_node:range()
  local raw = sig_text(bufnr, srow)

  local name, params, return_type
  if real_ft == "typescript" or real_ft == "javascript" then
    name, params, return_type = parse_ts_sig(raw)
  elseif real_ft == "python" then
    name, params, return_type = parse_py_sig(raw)
  else
    name, params, return_type = parse_braces_sig(raw)
  end

  if not name then
    vim.notify("forge: couldn't parse method signature", vim.log.levels.WARN)
    return
  end

  local typedef_snippet = build_typedef(real_ft, name, params, return_type)
  if not typedef_snippet then
    vim.notify(("forge: ctd not supported for filetype '%s'"):format(ft), vim.log.levels.WARN)
    return
  end

  -- Need the enclosing class to know where to insert.
  local class_node = ts.enclosing_class(lang.class_node_types)
  if not class_node then
    vim.notify("forge: cursor is not inside a class", vim.log.levels.WARN)
    return
  end

  local csrow, _, _, _ = class_node:range()
  vim.api.nvim_buf_set_lines(bufnr, csrow, csrow, false, { "" })
  vim.api.nvim_win_set_cursor(0, { csrow + 1, 0 })
  vim.snippet.expand(typedef_snippet)
end

return M

