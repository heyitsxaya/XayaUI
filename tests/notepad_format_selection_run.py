# UI-59 / UI-60 (2026-11-07): the Notepad format bar must keep highlighted text.
# Tester report (Insivius, verbatim): "highlighting text on the note pad and selecting a color deletes it".
# The game's EditBox:Insert replaces the highlighted text (the report is the evidence; docs/reference/api lists no
# getter for the highlighted range). This stub EditBox models that: Insert replaces the selection, the cursor counts
# characters, SetText / Insert fire OnTextChanged. Run from the repo root: python3 tests/notepad_format_selection_run.py
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
local function mk(kind)
  local o = { __kind = kind, lines = {}, scripts = {}, shown = true }
  return setmetatable(o, { __index = function(t, k)
    if type(k) ~= "string" or not k:match("^%u") then return nil end   -- plain fields (lowercase) are nil, like real frames
    if k == "CreateLine" then return function(self) local ln = mk("Line"); self.lines[#self.lines+1] = ln; return ln end end
    if k == "SetScript" then return function(self, n, fn) self.scripts[n] = fn end end
    if k == "SetPoint" then return function(self, ...) self.pt = { ... } end end
    if k == "SetSize" then return function(self, w, h) self.w, self.h = w, h end end
    if k == "SetHeight" then return function(self, h) self.h = h end end
    if k == "SetWidth" then return function(self, w) self.w = w end end
    if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
    if k == "SetMaxLetters" then return function(self, n) self.maxLetters = n end end
    if k == "SetTexture" then return function(self, v) self.texture = v end end
    if k == "SetText" then return function(self, v) self.text = v end end
    if k == "GetText" then return function(self) return self.text or "" end end
    if k == "HasFocus" then return function(self) return self.focus == true end end
    if k == "SetFocus" then return function(self) self.focus = true end end
    if k == "ClearFocus" then return function(self) if self.focus then self.focus = false; if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end end end
    if k == "CreateTexture" or k == "CreateFontString" then return function(self) return mk("Tex") end end
    if k == "GetWidth" or k == "GetHeight" or k == "GetLeft" or k == "GetTop" or k == "GetScale" or k == "GetEffectiveScale" then return function() return 100 end end
    if k:match("^Is") then return function() return false end end
    if k:match("^Get") then return function() return 0 end end
    return function(self, ...) return self end
  end })
end
GameTooltip = mk("GameTooltip"); tipText, tipDesc = nil, nil
function GameTooltip:SetText(t) tipText = t end
function GameTooltip:AddLine(t) tipDesc = t end
UIParent = mk("UIParent")
function CreateFrame(kind, name, parent) local f = mk(kind); if name then _G[name] = f end; return f end
STANDARD_TEXT_FONT = "x"; time = os.time; clock = 100; function GetTime() return clock end
ctrl, shift = false, false; function IsControlKeyDown() return ctrl end; function IsShiftKeyDown() return shift end
InCombatLockdown = function() return false end; UnitAffectingCombat = function() return false end
C_Timer = { After = function() end, NewTicker = function() return mk("t") end }
CueRulesDB = {}
ns = { Merge = function(a, b) for k, v in pairs(b or {}) do if a[k] == nil then a[k] = v end end end, Print = print }
''')
src = open(os.path.join(ROOT, "XayaUI_Bonus/Notepad.lua"), encoding="utf-8").read()
load = lua.eval("function(src) local f, e = load(src, '=Notepad.lua'); if not f then error(e) end; return f end")
lua.eval("function(f) f('XayaUI', ns) end")(load(open(os.path.join(ROOT, "XayaUI/Modules.lua"), encoding="utf-8").read()))   # core contract (0.5.108)
lua.eval("function(f) f('XayaUI', ns) end")(load(src))
src = open(os.path.join(ROOT, "XayaUI_Bonus/Notepad.lua"), encoding="utf-8").read()
load = lua.eval("function(src) local f, e = load(src, '=Notepad.lua'); if not f then error(e) end; return f end")
lua.eval("function(f) f('XayaUI', ns) end")(load(open(os.path.join(ROOT, "XayaUI/Modules.lua"), encoding="utf-8").read()))
lua.eval("function(f) f('XayaUI', ns) end")(load(src))
res = lua.execute(r'''
local out, fails = {}, 0
local function check(name, cond, got) out[#out+1] = (cond and "PASS " or "FAIL ") .. name .. ((not cond and got) and ("  [got: " .. tostring(got) .. "]") or ""); if not cond then fails = fails + 1 end end
ns.Notepad_OnDBReady()
local db = ns.notepadDB
db.format = true
ns.Notepad_SetShown(true)
local f = XayaUINotepad
local eb = f.eb
-- character helpers (the game's cursor counts characters)
local function chars(t) local r = {}; for ch in t:gmatch("[%z\1-\127\194-\244][\128-\191]*") do r[#r+1] = ch end; return r end
local function join(c, a, b) return table.concat(c, "", a, b) end
eb.text, eb.cur, eb.sel = "", 0, nil
eb.GetText = function(self) return self.text end
eb.GetCursorPosition = function(self) return self.cur end
eb.SetCursorPosition = function(self, p) local n = #chars(self.text); self.cur = math.max(0, math.min(n, p)); self.sel = nil end
eb.HighlightText = function(self, a, b) local n = #chars(self.text); a = a or 0; b = (b == nil or b < 0) and n or b; if a == b then self.sel = nil else self.sel = { math.min(a, b), math.max(a, b) }; self.cur = math.max(a, b) end end
local function fire() if self_text_changed then end; if eb.scripts.OnTextChanged then eb.scripts.OnTextChanged(eb, true) end end
eb.SetText = function(self, t) self.text = t or ""; self.cur = #chars(self.text); self.sel = nil; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end end
eb.Insert = function(self, t)
  local c = chars(self.text)
  local a, b = self.cur, self.cur
  if self.sel then a, b = self.sel[1], self.sel[2] end
  self.text = join(c, 1, a) .. t .. join(c, b + 1, #c)
  self.cur = a + #chars(t); self.sel = nil
  if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, true) end
end
local function setNote(t) eb:SetText(t); ns.notepadDB.notes[ns.notepadDB.cur or 1].text = t end
local function select(a, b) eb:HighlightText(a, b) end
local function btn(label) for _, b in ipairs(f.fb.btns) do if b.fs.text == label then return b end end end
local function click(i) f.fb.btns[i].scripts.OnClick(f.fb.btns[i]) end
local function noteText() local n = ns.notepadDB.notes[ns.notepadDB.cur or 1]; return n and n.text end
check("format bar built", f.fb ~= nil and #f.fb.btns == 9)
-- buttons: 1 View, 2 H, 3 bullet, 4 checkbox, 5 R, 6 Y, 7 G, 8 B, 9 Spell

-- the reported case: one word highlighted, G clicked
setNote("oop"); select(0, 3); click(7)
check("UI-59: highlighted 'oop' + G keeps the word, wrapped in green", eb.text == "|cff55dd55oop|r", eb.text)
check("UI-59: the saved note has the wrapped word", noteText() == "|cff55dd55oop|r", noteText())
check("UI-59: cursor sits after the closing |r", eb.cur == #chars("|cff55dd55oop|r"), eb.cur)

-- a word in the middle of a line, every colour
local cols = { [5] = "ff5555", [6] = "ffd100", [7] = "55dd55", [8] = "66b3ff" }
for i, hex in pairs(cols) do
  setNote("say oop now"); select(4, 7); click(i)
  check("colour " .. hex .. " wraps a mid-line selection", eb.text == "say |cff" .. hex .. "oop|r now", eb.text)
end
-- selection made right-to-left (cursor at the start) is the same selection
setNote("say oop now"); select(7, 4); eb.cur = 4; click(5)
check("right-to-left selection wraps the same word", eb.text == "say |cffff5555oop|r now", eb.text)
-- non-ASCII text in and before the selection
setNote("caf\195\169 \195\169t\195\169 x"); select(5, 8); click(6)
check("UTF-8 selection kept", eb.text == "caf\195\169 |cffffd100\195\169t\195\169|r x", eb.text)
-- the whole note, several lines
setNote("line one\nline two"); select(0, -1); click(8)
check("whole multi-line note kept", eb.text == "|cff66b3ffline one\nline two|r", eb.text)
-- selection that itself looks like the colour code's start
setNote("a |cff b"); select(2, 6); click(5)
check("selection starting with '|c' kept", eb.text == "a |cffff5555|cff|r b", eb.text)

-- no selection: unchanged behaviour, cursor between the pair
setNote("ab"); eb:SetCursorPosition(1); click(7)
check("no selection: pair inserted at the cursor", eb.text == "a|cff55dd55|rb", eb.text)
check("no selection: cursor between the colour code and |r", eb.cur == 1 + #chars("|cff55dd55"), eb.cur)
setNote("ab"); eb:SetCursorPosition(2); click(9)
check("no selection: Spell inserts {spell:} with the cursor inside", eb.text == "ab{spell:}" and eb.cur == 2 + 7, eb.text .. " @" .. eb.cur)

-- Spell with a selection keeps the text inside the braces
setNote("cast Fireball now"); select(5, 13); click(9)
check("Spell keeps the selected name inside {spell:}", eb.text == "cast {spell:Fireball} now", eb.text)

-- line-start buttons with a selection keep the text
setNote("first\nsecond"); select(6, 12); click(2)
check("H with a selected whole line keeps it", eb.text == "first\n# second", eb.text)
setNote("one two"); select(4, 7); click(3)
check("bullet with a mid-line selection keeps the text (new line, as without a selection)", eb.text == "one \n- two", eb.text)
setNote("task"); select(0, 4); click(4)
check("checkbox with a selection keeps the text", eb.text == "[ ] task", eb.text)
-- line-start buttons without a selection: unchanged
setNote("x"); eb:SetCursorPosition(1); click(2)
check("H mid-line without a selection starts a new line", eb.text == "x\n# ", eb.text)
setNote(""); eb:SetCursorPosition(0); click(3)
check("bullet on an empty note", eb.text == "- ", eb.text)

-- undo brings back the text before the click
setNote("keep me"); select(0, 7); click(5)
eb.scripts.OnKeyDown(eb, "Z")
check("(ctrl held) setup", true)
ctrl = true; eb.scripts.OnKeyDown(eb, "Z"); ctrl = false
check("Ctrl+Z after colouring gives back an unformatted text (never empty)", eb.text ~= "" and not eb.text:find("|cffff5555|r", 1, true), eb.text)

-- a full note: nothing is lost, the click does nothing
local full = string.rep("a", ns.Notepad_MAX_CHARS - 3)
setNote(full); select(0, 5); click(7)
check("full note: text unchanged (nothing cut off)", eb.text == full, #eb.text)

for _, l in ipairs(out) do print(l) end
print(("%d checks, %d failed"):format(#out, fails))
return fails
''')
sys.exit(1 if res else 0)
