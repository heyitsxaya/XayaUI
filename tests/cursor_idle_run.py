"""QoL 0.7.41: a still cursor costs (almost) nothing (REQUEST-LOG A15 P-13; her idle tooltip: XayaUI_QoL 1% "now", avg 0.4%).
Runs the real XayaUI_QoL/CursorHighlight.lua and CursorTrail.lua in a stand-in world (core's Theme.lua for the trail's gradients) and
counts what one frame does: the highlight's anchor is placed only when the cursor (or the UI scale) moved; the trail's per-frame loop
over its dot pool runs only while a dot is live (counted as calls of Grad, the per-dot colour function, through the dots' textures).
Negative control: QoL 0.7.40 re-anchors the highlight on every frame (first check FAILS).
Run: python3 tests/cursor_idle_run.py   (needs: pip install lupa)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
ANCHOR_SETS, TEX = 0, 0
local FR = {}
FR.__index = function(t, k)
  if k == "CreateTexture" or k == "CreateMaskTexture" or k == "CreateLine" or k == "CreateFontString" then
    return function() return setmetatable({}, { __index = function(_, m) if type(m) == "string" and m:match("^%u") then return function() TEX = TEX + 1 end end end }) end
  end
  if k == "SetScript" then return function(self, n, f) self.scripts[n] = f end end
  if k == "SetPoint" then return function(self) if self.isAnchor then ANCHOR_SETS = ANCHOR_SETS + 1 end end end
  if type(k) == "string" and k:match("^%u") then return function() end end
  return nil
end
FRAMES = {}
CreateFrame = function(kind, name, parent) local f = setmetatable({ scripts = {}, parent = parent }, FR); FRAMES[#FRAMES + 1] = f; return f end
UIParent = CreateFrame()
SCALE = 1
UIParent.GetEffectiveScale = function() return SCALE end
NOW = 100
GetTime = function() return NOW end
CX, CY = 800, 500
GetCursorPosition = function() return CX, CY end
IsMouselooking = function() return false end
UnitAffectingCombat = function() return false end
CueRulesDB = { cursorHighlight = { enabled = true, shape = "circle" }, cursorTrail = { enabled = true, shape = "line", size = 13, length = 0.2, opacity = 1 } }
XayaUI_NS = { RegisterSettingsPage = function() end, WhenReady = function(fn) fn() end, AtLogin = function(fn) fn() end, RegisterCommand = function() end, Share = { RegisterKind = function() end } }
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI_QoL', ns) end")
ns = L.eval("XayaUI_NS")
load(open(os.path.join(ROOT, "XayaUI", "Modules.lua"), encoding="utf-8").read(), "XayaUI/Modules.lua", ns)   # (core 0.6.75) the settings seam
L.execute("XayaUI_NS.SettingsDeclareStore(\"qol\", \"XayaUI_QoL\", \"XayaUIQoLDB\"); XayaUI_NS.SettingsOpenAllForTests()")   # (P5) XayaUI QoL's store opens (copied from the CueRulesDB above), as its ADDON_LOADED does
load(open(os.path.join(ROOT, "XayaUI", "Theme.lua"), encoding="utf-8").read(), "XayaUI/Theme.lua", ns)
load(open(os.path.join(ROOT, "XayaUI_QoL", "CursorHighlight.lua"), encoding="utf-8").read(), "XayaUI_QoL/CursorHighlight.lua", ns)
load(open(os.path.join(ROOT, "XayaUI_QoL", "CursorTrail.lua"), encoding="utf-8").read(), "XayaUI_QoL/CursorTrail.lua", ns)
L.execute(r'''
NS = XayaUI_NS
NS.CursorHighlight_Apply()
if NS.CursorTrail_Apply then NS.CursorTrail_Apply() end
-- the highlight's own frames: the anchor is the frame whose parent is the highlight's frame (CursorHighlight.lua Build)
HL, ANCHOR, TRAIL = nil, nil, nil
-- the highlight's frame is the one with a per-frame script that has a child (its anchor); the trail's has none
for _, f in ipairs(FRAMES) do
  if f.scripts.OnUpdate then
    local child
    for _, g in ipairs(FRAMES) do if g.parent == f then child = g end end
    if child then HL, ANCHOR = f, child else TRAIL = f end
  end
end
if ANCHOR then ANCHOR.isAnchor = true end
function FRAME(n) for i = 1, n do NOW = NOW + 1 / 60; if HL then HL.scripts.OnUpdate(HL, 1 / 60) end; if TRAIL then TRAIL.scripts.OnUpdate(TRAIL, 1 / 60) end end end
''')
fails = []
def check(name, ok):
    print(("ok    " if ok else "FAIL  ") + name)
    if not ok: fails.append(name)
E = lambda s: L.eval(s)
check("the highlight and the trail are running (both have a per-frame script); the anchor frame was found",
      E("HL ~= nil") and E("TRAIL ~= nil") and E("ANCHOR ~= nil"))
L.execute("FRAME(2); ANCHOR_SETS = 0; FRAME(120)")
check("a still cursor for 2 s (120 frames): the highlight is not re-anchored (%d times)" % E("ANCHOR_SETS"), E("ANCHOR_SETS") == 0)
L.execute("ANCHOR_SETS = 0; for i = 1, 30 do CX = CX + 5; FRAME(1) end")
check("a moving cursor (30 frames): re-anchored every frame it moved (30)", E("ANCHOR_SETS") == 30)
L.execute("ANCHOR_SETS = 0; SCALE = 0.8; FRAME(1); SCALE = 0.8; FRAME(10)")
check("a UI scale change re-anchors once", E("ANCHOR_SETS") == 1)
L.execute("FRAME(60); TEX = 0; FRAME(120)")
check("the trail after the cursor stopped and its dots faded: no texture call for 2 s (%d)" % E("TEX"), E("TEX") == 0)
L.execute("TEX = 0; for i = 1, 10 do CX = CX + 40; FRAME(1) end")
check("the trail while the cursor moves: dots are drawn (texture calls)", E("TEX") > 0)
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
