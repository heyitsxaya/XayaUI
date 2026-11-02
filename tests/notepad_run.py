# Stub test for Notepad.lua (toolbar icons, wrap, scale, note-name row). Run from the repo root: python3 tests/notepad_run.py
# Needs: pip install lupa. A stub cannot show real rendering, sharpness, or fonts: this checks logic and layout numbers only.
import os, sys
from lupa import LuaRuntime
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
STANDARD_TEXT_FONT = "x"; time = os.time
InCombatLockdown = function() return false end; UnitAffectingCombat = function() return false end
C_Timer = { After = function() end, NewTicker = function() return mk("t") end }
CueRulesDB = {}
ns = { Merge = function(a, b) for k, v in pairs(b or {}) do if a[k] == nil then a[k] = v end end end, Print = print }
''')
src = open(os.path.join(ROOT, "Notepad.lua"), encoding="utf-8").read()
load = lua.eval("function(src) local f, e = load(src, '=Notepad.lua'); if not f then error(e) end; return f end")
lua.eval("function(f) f('XayaUI', ns) end")(load(src))
res = lua.execute(r'''
local out, fails = {}, 0
local function check(name, cond) out[#out+1] = (cond and "PASS " or "FAIL ") .. name; if not cond then fails = fails + 1 end end
ns.Notepad_OnDBReady()
local db = ns.notepadDB
db.toolbar = true
ns.Notepad_SetShown(true)
local f = XayaUINotepad
local W, H = 280, 220
f.GetWidth = function() return W end
f.GetHeight = function() return H end
f.SetHeight = function(self, h) H = h end
local function resize(w, h) W = w; if h then H = h end; f.lastLayoutW = nil; f.scripts.OnSizeChanged(f, W) end
local function rows()
  local r = 1
  for _, b in ipairs(f.tb.btns) do r = math.max(r, math.floor((-b.pt[5] - f.tb.btns[1].pt[5] * -1) / 1)) end
  return r
end

-- title bar and name row
check("title bar text is Notepad, centered", f.title.text == "Notepad" and f.title.pt[1] == "CENTER")
check("name row is a child under the title bar", f.nr ~= nil and f.nr.edit ~= nil and f.nr.ph ~= nil)
check("default name shown as grey placeholder 'Note 1' with count 1/1", f.nr.ph.text == "Note 1" and f.nr.ph.shown == true and f.nr.count.text == "1/1" and f.nr.edit.text == "")

-- toolbar images and tooltips
local want = { "plus", "pages", "trash", "left", "right", "history", "list", "format", "menu" }
for i, b in ipairs(f.tb.btns) do
  check("button " .. i .. " image " .. want[i], b.tex.texture == "Interface\\AddOns\\XayaUI\\Media\\UI\\Notepad\\" .. want[i] .. ".png" and b.tex.shown == true)
  b.scripts.OnEnter(b)
  check("button " .. i .. " tooltip: " .. tostring(tipText), tipText and tipDesc and #tipText > 0 and #tipDesc > 0)
end

-- wrap and scale
local HDRX = 42
local function geom(w)
  resize(w)
  local u = math.max(1, math.min(2, w / 280))
  local maxr, maxx = 0, 0
  for _, b in ipairs(f.tb.btns) do
    maxr = math.max(maxr, math.floor((-b.pt[5] - 2 * u) / (18 * u) + 0.5))
    maxx = math.max(maxx, b.pt[4] + b.w)
  end
  return u, maxr + 1, maxx, f.tb.h
end
local u, r, mx, th = geom(280); check("280 wide: 1x, 1 row, bar 20 high", u == 1 and r == 1 and th == 20)
u, r, mx, th = geom(150);       check("150 wide: wraps to 2 rows, bar 38 high, nothing past the edge", r == 2 and th == 38 and mx <= 150)
check("150 wide: minH covers header + toolbar + typing room (" .. f.minH .. ")", f.minH >= HDRX + th + 3 + 14 + 30 and H >= f.minH)
u, r, mx, th = geom(560);       check("560 wide: 2x, 1 row, bar 40 high, button width 52", u == 2 and r == 1 and th == 40 and f.tb.btns[1].w == 52 and mx <= 560)
check("560 wide: icon image scaled to 26", f.tb.btns[1].tex.w == 26)
u, r, mx, th = geom(400);       check("400 wide: scaled and fits on 1 row", r == 1 and mx <= 400 and f.tb.btns[1].w > 26 and f.tb.btns[1].w < 52)
resize(280)

-- renaming
local ne = f.nr.edit
ne:SetFocus(); ne.scripts.OnEditFocusGained(ne)
ne:SetText("  Boss notes  "); ne.scripts.OnTextChanged(ne, true)
check("typing stores the name and hides the placeholder", ns.notepadDB.notes[1].name == "  Boss notes  " and f.nr.ph.shown == false)
ne:ClearFocus()
check("focus lost trims the name", ns.notepadDB.notes[1].name == "Boss notes")
local e1 = ns.Notepad_ListEntries()[1]
check("list entry carries the custom name", e1.name == "Boss notes")
ne:SetFocus(); ne.scripts.OnEditFocusGained(ne)
ne:SetText("x"); ne.scripts.OnTextChanged(ne, true); ne.scripts.OnEscapePressed(ne)
check("Esc restores the earlier name", ns.notepadDB.notes[1].name == "Boss notes" and ne.text == "Boss notes")
ne:SetFocus(); ne.scripts.OnEditFocusGained(ne)
ne:SetText("   "); ne.scripts.OnTextChanged(ne, true); ne:ClearFocus()
check("empty name goes back to default 'Note 1'", ns.notepadDB.notes[1].name == nil and f.nr.ph.text == "Note 1" and f.nr.ph.shown == true)
ne:SetFocus(); ne.scripts.OnEditFocusGained(ne)
ne:SetText("Boss notes"); ne.scripts.OnTextChanged(ne, true); ne:ClearFocus()
ns.Notepad_Duplicate()
check("duplicate of a named note is '<name> (copy)', 2/2", ns.notepadDB.notes[2].name == "Boss notes (copy)" and f.nr.count.text == "2/2")
ns.Notepad_New(nil, true)
check("a new note defaults to its position: 'Note 3'", ns.notepadDB.notes[3].name == nil and f.nr.ph.text == "Note 3" and ns.Notepad_ListEntries()[3].name == "Note 3")
ne:SetFocus(); ne.scripts.OnEditFocusGained(ne)
check("name box is limited to 40 letters", ne.maxLetters == 40)
ne:ClearFocus()

-- line-icon fallback
db.iconLines = true; ns.Notepad_Refresh()
check("line icons option: images hidden, lines shown", f.tb.btns[1].tex.shown == false and f.tb.btns[1].icon[1].shown == true)
db.iconLines = false; ns.Notepad_Refresh()
check("default: images shown, lines hidden", f.tb.btns[1].tex.shown == true and f.tb.btns[1].icon[1].shown == false)

-- other toolbar positions
db.toolbarPos = "BOTTOM"; resize(150)
check("BOTTOM toolbar wraps too, 4 per row because the resize grip takes 16 px (bar " .. tostring(f.tb.h) .. ")", f.tb.h == 56)
db.toolbarPos = "LEFT"; resize(280, 220)
check("LEFT toolbar: minH covers 9 buttons + header (" .. f.minH .. ")", f.minH == 9 * 20 + 42 + 8 and f.tb.w == 38)
db.toolbarPos = "TOP"; resize(280)
out[#out+1] = fails == 0 and "ALL PASS" or ("FAILS: " .. fails)
return table.concat(out, "\n")
''')
print(res)
sys.exit(0 if res.endswith("ALL PASS") else 1)
