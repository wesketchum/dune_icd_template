--[[
icd_changes_to_docx.lua -- pandoc Lua filter used by icd_to_docx.py.

Turns dune-icd-changes markup, which the LaTeX reader keeps as raw LaTeX
(read with -f latex+raw_tex), into the spans pandoc's docx writer emits as
Word tracked changes and comments:

  \added[id=X]{new}          -> insertion by X
  \deleted[id=X]{old}        -> deletion by X
  \replaced[id=X]{new}{old}  -> deletion of old + insertion of new, by X
  \comment[id=X]{text}       -> Word comment by X
  \ToDo[id=X]{text}          -> Word comment by X, prefixed "ToDo:"
  addedblock / deletedblock  -> every paragraph, heading, list item and
                                table cell inside becomes an insertion /
                                deletion by X; a reason={...} becomes a
                                comment on the first paragraph

Author names come from metadata `changes_authors` (id -> full name) and the
change date from `changes_date`; icd_to_docx.py sets both. `latex_macros`
holds macro definitions prepended to every fragment re-read here, so class
macros (\icdrow, \tbd, ...) still expand inside markup arguments.
]]

local authors = {}
local change_date = os.date("!%Y-%m-%dT%H:%M:%SZ")
local macros = ""
local comment_id = 0
local reread_depth = 0
local drop_comments = false

local function meta_string(v)
  if v == nil then return nil end
  return pandoc.utils.stringify(v)
end

local function read_meta(meta)
  if meta.changes_authors then
    for k, v in pairs(meta.changes_authors) do
      authors[k] = meta_string(v)
    end
  end
  change_date = meta_string(meta.changes_date) or change_date
  macros = meta_string(meta.latex_macros) or ""
  drop_comments = meta.drop_comments == true
end

local function author_of(opts)
  local id = opts and opts:match("id%s*=%s*([^,%]]+)")
  if id then id = id:gsub("%s+$", "") end
  return (id and authors[id]) or id or "Unknown"
end

-- Return the content of a balanced {...} group starting at s[i] == "{",
-- and the index just past its closing brace.
local function brace_group(s, i)
  if s:sub(i, i) ~= "{" then return nil, i end
  local depth, j = 0, i
  while j <= #s do
    local c = s:sub(j, j)
    if c == "\\" then
      j = j + 1
    elseif c == "{" then
      depth = depth + 1
    elseif c == "}" then
      depth = depth - 1
      if depth == 0 then return s:sub(i + 1, j - 1), j + 1 end
    end
    j = j + 1
  end
  return nil, i
end

-- Parse "\name[opts]{a1}{a2}..." into name, opts, {args}.
local function parse_command(raw)
  local name, rest = raw:match("^\\(%a+)%s*(.*)$")
  if not name then return nil end
  local opts = ""
  local i = 1
  if rest:sub(1, 1) == "[" then
    local close = rest:find("]", 1, true)
    opts = rest:sub(2, close - 1)
    i = close + 1
  end
  local args = {}
  while true do
    while rest:sub(i, i):match("%s") do i = i + 1 end
    local arg, nexti = brace_group(rest, i)
    if not arg then break end
    table.insert(args, arg)
    i = nexti
  end
  return name, opts, args
end

local markup_filter -- forward declaration

local function read_latex(text)
  local doc = pandoc.read(macros .. "\n" .. text, "latex+raw_tex")
  return doc:walk(markup_filter)
end

-- LaTeX fragment -> inline list (paragraphs joined with a space).
local function to_inlines(text)
  local doc = read_latex(text)
  local out = pandoc.Inlines({})
  if text:match("^%s") then out:insert(pandoc.Space()) end
  for _, blk in ipairs(doc.blocks) do
    if blk.content and (blk.t == "Para" or blk.t == "Plain") then
      if #out > 0 then out:insert(pandoc.Space()) end
      out:extend(blk.content)
    end
  end
  if text:match("%s$") then out:insert(pandoc.Space()) end
  return out
end

local function change_span(kind, inlines, author)
  if #inlines == 0 then return pandoc.Inlines({}) end
  return pandoc.Inlines({ pandoc.Span(inlines, pandoc.Attr("", { kind },
    { author = author, date = change_date })) })
end

local function comment(inlines, author)
  if drop_comments then return pandoc.Inlines({}) end
  comment_id = comment_id + 1
  local id = tostring(comment_id)
  return {
    pandoc.Span(inlines, pandoc.Attr("", { "comment-start" },
      { id = id, author = author, date = change_date })),
    pandoc.Span({}, pandoc.Attr("", { "comment-end" }, { id = id })),
  }
end

local function raw_inline(el)
  if el.format ~= "latex" and el.format ~= "tex" then return nil end
  local name, opts, args = parse_command(el.text)
  if not name then return nil end
  local who = author_of(opts)
  if name == "added" and args[1] then
    return change_span("insertion", to_inlines(args[1]), who)
  elseif name == "deleted" and args[1] then
    return change_span("deletion", to_inlines(args[1]), who)
  elseif name == "replaced" and args[2] then
    local out = change_span("deletion", to_inlines(args[2]), who)
    out:extend(change_span("insertion", to_inlines(args[1]), who))
    return out
  elseif name == "comment" and args[1] then
    return comment(to_inlines(args[1]), who)
  elseif name == "ToDo" and args[1] then
    local body = pandoc.Inlines({ pandoc.Strong({ pandoc.Str("ToDo:") }), pandoc.Space() })
    body:extend(to_inlines(args[1]))
    return comment(body, who)
  end
  return nil
end

-- Wrap the inline content of every text-bearing block in a change span.
local function mark_blocks(blocks, kind, who)
  local wrap = function(el)
    if #el.content > 0 then
      el.content = change_span(kind, el.content, who)
    end
    return el
  end
  return pandoc.Blocks(blocks):walk({ Para = wrap, Plain = wrap, Header = wrap })
end

local function raw_block(el)
  if el.format ~= "latex" and el.format ~= "tex" then return nil end
  local env, opts, body = el.text:match(
    "^%s*\\begin{(%a+block)}%s*(%b[])(.-)\\end{%a+block}%s*$")
  if not env then
    env, body = el.text:match("^%s*\\begin{(%a+block)}(.-)\\end{%a+block}%s*$")
    opts = ""
  end
  if env ~= "addedblock" and env ~= "deletedblock" then
    -- A paragraph or list item made only of markup arrives as a RawBlock.
    -- Re-read it behind an \mbox{} so pandoc sees inline text, then drop
    -- the \mbox{}.
    if el.text:match("^%s*\\begin") then return nil end
    local has_markup = false
    for _, cmd in ipairs({ "added", "deleted", "replaced", "comment", "ToDo" }) do
      if el.text:match("\\" .. cmd .. "%f[^%a]") then has_markup = true end
    end
    if not has_markup or reread_depth > 3 then return nil end
    reread_depth = reread_depth + 1
    local blocks = read_latex("\\mbox{}" .. el.text).blocks
    reread_depth = reread_depth - 1
    return blocks:walk({ RawInline = function(r)
      if r.text == "\\mbox{}" then return {} end
    end })
  end
  opts = opts:gsub("^%[", ""):gsub("%]$", "")
  local who = author_of(opts)
  local blocks = read_latex(body).blocks
  blocks = mark_blocks(blocks, env == "addedblock" and "insertion" or "deletion", who)
  local _, reason = opts:find("reason%s*=%s*{")
  if reason then
    local text = brace_group(opts, reason)
    local label = env == "addedblock" and "Proposed addition: " or "Proposed deletion: "
    local note = comment(pandoc.Inlines({ pandoc.Str(label .. text) }), who)
    table.insert(blocks, 1, pandoc.Para(note))
  end
  return blocks
end

markup_filter = { RawInline = raw_inline, RawBlock = raw_block }

-- \ref{label} -> the number pandoc gives that heading with --number-sections.
local function resolve_refs(doc)
  local numbers, counters = {}, {}
  doc:walk({ Header = function(h)
    if h.classes:includes("unnumbered") then return nil end
    counters[h.level] = (counters[h.level] or 0) + 1
    for l = h.level + 1, 9 do counters[l] = nil end
    local parts = {}
    for l = 1, h.level do table.insert(parts, tostring(counters[l] or 0)) end
    if h.identifier ~= "" then numbers[h.identifier] = table.concat(parts, ".") end
  end })
  return doc:walk({ RawInline = function(el)
    local cmd, label = el.text:match("^\\(%a*ref)%s*{(.-)}$")
    if not cmd then return nil end
    if cmd == "pageref" then return {} end
    return pandoc.Str(numbers[label] or ("[" .. label .. "]"))
  end })
end

return {
  { Meta = read_meta },
  markup_filter,
  { Pandoc = resolve_refs },
}
