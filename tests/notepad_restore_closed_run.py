# Function audit D48 (Bonus 0.6.23): the Notepad's Restore list, opened from the settings page before the box was ever shown, restores an
# earlier version without a Lua error. On Bonus 0.6.22: 'Notepad.lua: attempt to index upvalue frame (a nil value)'.
# Run from the repo root: python3 tests/notepad_restore_closed_run.py
# Needs: pip install lupa. A stub cannot show real rendering, sharpness, or fonts: this checks logic and layout numbers only.
import os, sys
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)
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
r = lua.execute(r'''
local made = {}; date = os.date
local CF = CreateFrame
CreateFrame = function(kind, name, parent) local f = CF(kind, name, parent); f.parent = parent; made[#made+1] = f; return f end
ns.Notepad_OnDBReady()
local db = ns.notepadDB
local n = db.notes[1]; n.text = "current text"; n.hist = { { t = 1, text = "old version" } }
ns.Notepad_ToggleRestore()
local p = XayaUINotepadRestore
p.IsShown = function() return true end
p.scripts.OnShow(p)
local btns = {}
for _, f in ipairs(made) do if f.parent == p.child and f.__kind == "Button" then btns[#btns+1] = f end end
local ok, err = pcall(btns[2].scripts.OnClick, btns[2])
local kept = false
for _, h in ipairs(n.hist) do if h.text == "current text" then kept = true end end
return (XayaUINotepad == nil) and "noframe" or "frame", ok, tostring(err), n.text, kept
''')
fr, ok, err, text, h1 = r
fails = 0
def check(name, c, extra=""):
    global fails
    print(("PASS " if c else "FAIL ") + name + ("" if c else "  [" + str(extra) + "]"))
    fails += 0 if c else 1
check("the box was never built", fr == "noframe", fr)
check("clicking an earlier version: no Lua error", ok is True, err)
check("the note now holds the earlier version", text == "old version", text)
check("the text before it is kept in the versions", h1 is True, h1)
print("%d failed" % fails)
sys.exit(1 if fails else 0)
