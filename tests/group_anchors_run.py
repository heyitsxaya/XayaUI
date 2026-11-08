"""Group anchors, fix A (Rules 0.6.82; REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s rows 14, 16, 28, 29). Her report (#14): "anchoring to
an EUI unit frame isn't calculating correctly": the group "Externals" (This group's anchor point Bottom left, Point on the frame Top
left, X 0 / Y 0, Group scale 0.25) sat left of and below EllesmereUIUnitFrames_Player's top-left corner. Cause: in Auto size a group's
container is a 1 x 1 frame and what is inside hangs from its CENTRE, so "Bottom left" named a corner of an invisible dot. Her decisions,
each asserted here on what is drawn (screen positions from the real Visual.lua with real anchors, parents and scale):
  - rows / columns growing one way: the WHOLE GRID's point sits on the frame's point ("Whole grid's corner"; also tests/layout_parity_run.py);
  - hand-placed groups ("Both now"): the outline of EVERY switched-on display (also ones not showing now), from saved data: hiding a
    display never moves the group; a switched-off display (or rule) does not count;
  - Center keeps today's behaviour; a set size keeps its box's point;
  - changing the point from now on: "Icons move": the new point sits on the frame, X / Y unchanged;
  - existing groups: "Nothing moves": ns.MigrateGroupAnchors adjusts X / Y once (idempotent, saved flag) so every icon stays where the
    code before 0.6.82 drew it. The "before" positions below were RECORDED by running this file with --record against Rules 0.6.81
    (commit 897ae70, the code before this change), not computed by the code under test.
  - B (group to group), geometry part: a group that follows another follows its anchor point (Auto) or its box (set size), also when
    that group moves or is scaled, with no watcher.
Negative control: on 897ae70 every "sits on" check fails (the icons are about half an icon off) and the migration does not exist.
Run: python3 tests/group_anchors_run.py   (needs: pip install lupa). --record prints the icon positions of the migration scenarios."""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RECORD = "--record" in sys.argv
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
STUBS = bench[a:b]
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(STUBS)
L.execute(r'''
COMBAT = false
local M = FRAME_METHODS
-- real geometry: size, scale, parent, one anchor (as tests/layout_parity_run.py), plus the readings Visual.lua takes back
function M:SetSize(w, h) self._w, self._h = w, h end
function M:SetWidth(w) self._w = w end
function M:SetHeight(h) self._h = h end
function M:GetWidth() return self._w or 30 end
function M:GetHeight() return self._h or 30 end
function M:GetSize() return self:GetWidth(), self:GetHeight() end
function M:SetScale(s) self._scale = s end
function M:GetScale() return self._scale or 1 end
function M:SetParent(p) self._parent = p end
function M:GetParent() return self._parent end
function M:ClearAllPoints() self._pt = nil end
function M:SetAllPoints() end
function M:SetPoint(p, rel, rp, x, y)
  if type(rel) == "number" or rel == nil then rel, rp, x, y = self._parent or UIParent, p, rel or 0, rp or 0 end
  if type(rel) == "string" then rel = _G[rel] end
  assert(rel ~= self, "anchored to itself")
  self._pt = { p, rel, rp or p, x or 0, y or 0 }
end
local V = { CENTER = {0,0}, TOP = {0,.5}, BOTTOM = {0,-.5}, LEFT = {-.5,0}, RIGHT = {.5,0},
  TOPLEFT = {-.5,.5}, TOPRIGHT = {.5,.5}, BOTTOMLEFT = {-.5,-.5}, BOTTOMRIGHT = {.5,-.5} }
function EffScale(f) local s = 1; while f and f ~= UIParent do s = s * (f._scale or 1); f = f._parent end return s end
local depth = 0
function PointAbs(f, pt)
  local cx, cy = CenterAbs(f); local s = EffScale(f); local v = V[pt]
  return cx + v[1] * f:GetWidth() * s, cy + v[2] * f:GetHeight() * s
end
function CenterAbs(f)
  if f == UIParent then return 960, 540 end
  local a = f._pt; assert(a, "frame has no anchor")
  depth = depth + 1; assert(depth < 60, "anchor loop")
  local rx, ry = PointAbs(a[2], a[3]); local s = EffScale(f); local v = V[a[1]]
  depth = depth - 1
  local px, py = rx + a[4] * s, ry + a[5] * s
  return px - v[1] * f:GetWidth() * s, py - v[2] * f:GetHeight() * s
end
function M:GetEffectiveScale() return EffScale(self) end
function M:GetCenter() if not self._pt and self ~= UIParent then return nil end local x, y = CenterAbs(self); local s = EffScale(self); return x / s, y / s end
function M:GetRect()
  if not self._pt and self ~= UIParent then return nil end
  local x, y = CenterAbs(self); local s = EffScale(self)
  return x / s - self:GetWidth() / 2, y / s - self:GetHeight() / 2, self:GetWidth(), self:GetHeight()
end
UIParent._w, UIParent._h = 1920, 1080
function UIParent:GetEffectiveScale() return 1 end
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{ settingsTestHooks = { keepOld = true } }"); L.globals().NS = ns
for f in ("XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI_Rules/RuleDefaults.lua", "XayaUI_Rules/Conditions.lua", "XayaUI_Rules/Outcomes.lua", "XayaUI_Rules/Cues.lua", "XayaUI_Rules/Visual.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute(r'''
ns = NS   -- (a global here: every chunk below reads it)
local ns = NS
ns.Print = function() end
ns.runtime = ns.runtime or {}
XayaUI_NS = ns
-- the stand-in "EllesmereUIUnitFrames_Player": a named frame of its own scale (her screenshot's frame name)
EUI = CreateFrame("Frame", "EllesmereUIUnitFrames_Player", UIParent)
EUI:SetParent(UIParent); EUI:SetScale(1); EUI:SetSize(220, 44); EUI:ClearAllPoints(); EUI:SetPoint("CENTER", UIParent, "CENTER", -320, -230)
_G.EllesmereUIUnitFrames_Player = EUI
function Reset() ns.folders, ns.rules = {}, {}; CueRulesDB.folders, CueRulesDB.rules = ns.folders, ns.rules; CueRulesDB.groupAnchorVer = nil; CueRulesDB.groupAnchorMoved = nil end
local n = 0
function Rule(folder, w, h, x, y, extra)
  n = n + 1
  local r = { uid = "u" .. n, name = "r" .. n, folder = folder, useBuff = true, buffID = 9000 + n, enabled = true,
    visual = { enabled = true, trigger = "buffActive", w = w, h = h, x = x or 0, y = y or 0 } }
  ns.rules[#ns.rules + 1] = r
  pcall(ns.NormalizeRule, r)
  r.visual.enabled, r.visual.w, r.visual.h, r.visual.x, r.visual.y, r.visual.trigger = true, w, h, x or 0, y or 0, "buffActive"
  for k, v in pairs(extra or {}) do r.visual[k] = v end
  return r
end
function Show(rules, on) for _, r in ipairs(rules) do ns.SetVisualShown(r, on ~= false) end end
function Box(rules)   -- the bounding box of the given displays as drawn (screen units)
  local l, b, r_, t
  for _, r in ipairs(rules) do
    local fr = ns.VisualFramesOf(r)[1]
    local x, y = CenterAbs(fr); local s = EffScale(fr)
    local hw, hh = fr:GetWidth() * s / 2, fr:GetHeight() * s / 2
    l = l and math.min(l, x - hw) or (x - hw); r_ = r_ and math.max(r_, x + hw) or (x + hw)
    b = b and math.min(b, y - hh) or (y - hh); t = t and math.max(t, y + hh) or (y + hh)
  end
  return l, b, r_, t
end
local P01 = { TOPLEFT = { 0, 1 }, TOP = { .5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, .5 }, CENTER = { .5, .5 }, RIGHT = { 1, .5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { .5, 0 }, BOTTOMRIGHT = { 1, 0 } }
function BoxPoint(rules, pt) local l, b, r, t = Box(rules); local p = P01[pt]; return l + p[1] * (r - l), b + p[2] * (t - b) end
function Centers(rules) local out = {}; for i, r in ipairs(rules) do out[i] = { CenterAbs(ns.VisualFramesOf(r)[1]) } end; return out end
''')
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)
def near(a, b, tol=0.01): return abs(a - b) <= tol
def pt2(name): return tuple(L.eval(name)[i] for i in (1, 2))

if not RECORD:
    # 1. her case, a grid growing Right: Bottom left on the EUI frame's Top left, X 0 / Y 0, Group scale 0.25
    L.execute(r'''
    Reset()
    ns.folders[1] = { id = "fE", name = "Externals", cType = "dynamic", cGrowth = "RIGHT", cSpacing = 4, cScale = 0.25,
      cRel = "custom", cFrame = "EllesmereUIUnitFrames_Player", cPoint = "BOTTOMLEFT", cRelPoint = "TOPLEFT" }
    E = { Rule("fE", 30, 30), Rule("fE", 30, 30), Rule("fE", 30, 30) }
    Show(E)
    GOT = { BoxPoint(E, "BOTTOMLEFT") }; WANT = { PointAbs(EUI, "TOPLEFT") }
    Show({ E[1] }, false)
    GOT2 = { BoxPoint({ E[2], E[3] }, "BOTTOMLEFT") }
    ''')
    g, w = pt2("GOT"), pt2("WANT")
    check("her case (Right, Bottom left on the frame's Top left, scale 0.25): the grid's bottom-left is on the frame's top-left", near(g[0], w[0]) and near(g[1], w[1]), "grid %.2f,%.2f vs frame %.2f,%.2f" % (g + w))
    g2 = pt2("GOT2")
    check("  ...one aura down: the two left still start at the frame's top-left (the grid grows away from the corner)", near(g2[0], w[0]) and near(g2[1], w[1]), "%.2f,%.2f" % g2)

    # 2. a group of hand-placed displays: the outline of every switched-on display
    L.execute(r'''
    Reset()
    ns.folders[1] = { id = "fS", name = "Hand placed", cRel = "custom", cFrame = "EllesmereUIUnitFrames_Player", cPoint = "BOTTOMLEFT", cRelPoint = "TOPLEFT", cScale = 0.5 }
    S1 = Rule("fS", 40, 40, -60, 10)
    S2 = Rule("fS", 30, 20, 50, 30, { anchor = "TOPLEFT", point = "TOPLEFT" })   -- a corner anchor of its own
    S3 = Rule("fS", 36, 36, 0, -70)   -- switched on but not showing (other spec, conditions not met)
    OFF = Rule("fS", 50, 50, -400, -400); OFF.visual.enabled = false            -- display switched off: not part of the outline
    ROFF = Rule("fS", 50, 50, 400, 400); ROFF.enabled = false                    -- rule switched off: not part of the outline
    Show({ S1, S2, S3 })
    ALL = { BoxPoint({ S1, S2, S3 }, "BOTTOMLEFT") }; WANT = { PointAbs(EUI, "TOPLEFT") }
    C0 = Centers({ S1, S2 })
    Show({ S3 }, false)
    C1 = Centers({ S1, S2 })
    local l = ns.GroupOutline and ns.GroupOutline(ns.folders[1]); OUTL = l or 0
    ''')
    g, w = pt2("ALL"), pt2("WANT")
    check("hand-placed, Bottom left: the outline of every switched-on display has its bottom-left on the frame's top-left", near(g[0], w[0]) and near(g[1], w[1]), "outline %.2f,%.2f vs frame %.2f,%.2f" % (g + w))
    c0, c1 = L.eval("C0"), L.eval("C1")
    same = all(near(c0[i][1], c1[i][1]) and near(c0[i][2], c1[i][2]) for i in (1, 2))
    check("  ...a display that stops showing (conditions not met) does not move the others", same)
    check("  ...the switched-off display and the switched-off rule are left out (outline from saved data: left edge -80)", near(L.eval("OUTL"), -80), L.eval("OUTL"))

    # 3. Center keeps today's behaviour; a set size keeps its box's point
    L.execute(r'''
    Reset()
    ns.folders[1] = { id = "fC", name = "Center", cX = 25, cY = -40 }
    C = Rule("fC", 40, 40, 60, 0)
    ns.folders[2] = { id = "fB", name = "Boxed", cSize = "set", cW = 200, cH = 100, cPoint = "BOTTOMLEFT", cRel = "custom", cFrame = "EllesmereUIUnitFrames_Player", cRelPoint = "TOPLEFT" }
    B = Rule("fB", 40, 40, 0, 0)
    Show({ C, B })
    CC = { CenterAbs(ns.VisualFramesOf(C)[1]) }
    BB = { PointAbs(ns.GroupFrame(ns.folders[2]), "BOTTOMLEFT") }; WANT = { PointAbs(EUI, "TOPLEFT") }
    BC = { CenterAbs(ns.VisualFramesOf(B)[1]) }; BXC = { CenterAbs(ns.GroupFrame(ns.folders[2])) }
    ''')
    cc = pt2("CC")
    check("Center: unchanged, the display is drawn at the screen centre + X / Y + its own X (1045, 500)", near(cc[0], 960 + 25 + 60) and near(cc[1], 540 - 40), "%.2f,%.2f" % cc)
    bb, w = pt2("BB"), pt2("WANT")
    check("Set size: the box's bottom-left is on the frame's top-left, its display at the box's centre (unchanged)", near(bb[0], w[0]) and near(bb[1], w[1]) and near(pt2("BC")[0], pt2("BXC")[0]), "%.2f,%.2f" % bb)

    # 4. "Icons move": a new point on an Auto group puts that point of what it holds on the frame, X / Y unchanged
    L.execute(r'''
    Reset()
    ns.folders[1] = { id = "fM", name = "Moves", cRel = "custom", cFrame = "EllesmereUIUnitFrames_Player", cPoint = "BOTTOMLEFT", cRelPoint = "TOPLEFT", cX = 12, cY = 7 }
    M1, M2 = Rule("fM", 30, 30, -20, 0), Rule("fM", 30, 30, 20, 25)
    Show({ M1, M2 })
    ns.folders[1].cPoint = "TOPRIGHT"
    ns.RefreshAllVisuals()
    GOT = { BoxPoint({ M1, M2 }, "TOPRIGHT") }; WANT = { PointAbs(EUI, "TOPLEFT") }
    XY = { ns.folders[1].cX, ns.folders[1].cY }
    ''')
    g, w = pt2("GOT"), pt2("WANT")
    check("changing This group's anchor point to Top right: the outline's top-right is on the frame's top-left + X / Y", near(g[0], w[0] + 12) and near(g[1], w[1] + 7), "%.2f,%.2f vs %.2f,%.2f" % (g + w))
    check("  ...and X / Y are unchanged (12, 7)", tuple(L.eval("XY")[i] for i in (1, 2)) == (12, 7))

# 5. "Nothing moves": the migration. Each scenario: a group (and its displays) as saved before 0.6.82; icon centres were recorded with
# Rules 0.6.81 (897ae70) by --record.
SCEN = r'''
function Scenarios()
  Reset()
  local F, R = ns.folders, {}
  F[#F + 1] = { id = "m1", name = "Externals", cType = "dynamic", cGrowth = "RIGHT", cSpacing = 4, cScale = 0.25, cRel = "custom", cFrame = "EllesmereUIUnitFrames_Player", cPoint = "BOTTOMLEFT", cRelPoint = "TOPLEFT" }
  R.m1 = { Rule("m1", 30, 30), Rule("m1", 30, 30), Rule("m1", 30, 30) }
  F[#F + 1] = { id = "m2", name = "Column", cType = "dynamic", cGrowth = "DOWN", cSpacing = 3, cWrapN = 2, cPoint = "TOPRIGHT", cX = -200, cY = 150, cScale = 1.25 }
  R.m2 = { Rule("m2", 32, 32), Rule("m2", 24, 24), Rule("m2", 32, 40), Rule("m2", 28, 28) }
  F[#F + 1] = { id = "m3", name = "Left up", cType = "dynamic", cGrowth = "LEFT", cSpacing = 5, cWrapN = 3, cWrapRev = true, cPoint = "BOTTOM", cX = 300, cY = -100 }
  R.m3 = { Rule("m3", 30, 30), Rule("m3", 30, 30), Rule("m3", 30, 30), Rule("m3", 30, 30) }
  F[#F + 1] = { id = "m4", name = "Hand placed", cPoint = "BOTTOMLEFT", cRel = "custom", cFrame = "EllesmereUIUnitFrames_Player", cRelPoint = "TOPLEFT", cScale = 0.5 }
  R.m4 = { Rule("m4", 40, 40, -60, 10), Rule("m4", 30, 20, 50, 30, { anchor = "TOPLEFT", point = "TOPLEFT" }), Rule("m4", 36, 36, 0, -70) }
  F[#F + 1] = { id = "mp", name = "Parent", cScale = 0.5, cX = 100, cY = 50 }
  F[#F + 1] = { id = "m5", name = "Nested to screen", parent = "mp", cAnchorTo = "screen", cPoint = "TOPLEFT", cRelPoint = "TOPLEFT", cX = 40, cY = -60, cScale = 1.5 }
  R.m5 = { Rule("m5", 30, 30, 0, 0), Rule("m5", 30, 30, 45, -10) }
  F[#F + 1] = { id = "m6", name = "Nested in parent", parent = "mp", cPoint = "RIGHT", cX = -30 }
  R.m6 = { Rule("m6", 30, 30, -15, 0), Rule("m6", 20, 20, 20, 20) }
  -- left as they are: Center, a set size, Centered row, From anchor point, a static group nested in a dynamic one
  F[#F + 1] = { id = "k1", name = "Center", cType = "dynamic", cGrowth = "RIGHT", cX = 10, cY = 10 }
  R.k1 = { Rule("k1", 30, 30), Rule("k1", 30, 30) }
  F[#F + 1] = { id = "k2", name = "Set size", cSize = "set", cW = 120, cH = 60, cPoint = "BOTTOMLEFT", cX = -500, cY = -300 }
  R.k2 = { Rule("k2", 30, 30, 0, 0) }
  F[#F + 1] = { id = "k3", name = "Centered row", cType = "dynamic", cGrowth = "HCENTER", cPoint = "TOPLEFT", cX = 0, cY = 300 }
  R.k3 = { Rule("k3", 30, 30), Rule("k3", 30, 30) }
  F[#F + 1] = { id = "k4", name = "From anchor", cType = "dynamic", cGrowth = "ANCHOR_ROW", cPoint = "BOTTOMRIGHT", cX = 600, cY = 0 }
  R.k4 = { Rule("k4", 30, 30), Rule("k4", 30, 30) }
  F[#F + 1] = { id = "kd", name = "Dyn parent", cType = "dynamic", cGrowth = "UP", cX = -700, cY = 100 }
  F[#F + 1] = { id = "k5", name = "Static in dynamic", parent = "kd", cPoint = "TOPLEFT" }
  R.k5 = { Rule("k5", 30, 30), Rule("k5", 30, 30) }
  ORDER = { "m1", "m2", "m3", "m4", "m5", "m6", "k1", "k2", "k3", "k4", "k5" }
  RULES = R
  for _, id in ipairs(ORDER) do Show(R[id]) end
end
function Snapshot()
  local out = {}
  for _, id in ipairs(ORDER) do
    for i, c in ipairs(Centers(RULES[id])) do out[#out + 1] = { id .. "#" .. i, c[1], c[2] } end
  end
  return out
end
'''
L.execute(SCEN)
# recorded with --record on 897ae70 (Rules 0.6.81): every icon's centre on screen before 0.6.82
BEFORE = {
    "m1#1": (530.125, 328.375), "m1#2": (538.625, 328.375), "m1#3": (547.125, 328.375),
    "m2#1": (1739.375, 1229.375), "m2#2": (1739.375, 1190.625), "m2#3": (1783.125, 1229.375), "m2#4": (1783.125, 1183.125),
    "m3#1": (1260, -84.5), "m3#2": (1225, -84.5), "m3#3": (1190, -84.5), "m3#4": (1260, -49.5),
    "m4#1": (500.25, 337.25), "m4#2": (562.5, 342.5), "m4#3": (530.25, 297.25),
    "m5#1": (40.375, 1019.625), "m5#2": (74.125, 1012.125),
    "m6#1": (1037.5, 590), "m6#2": (1055, 600),
    "k1#1": (970, 535), "k1#2": (1004, 535),
    "k2#1": (-440, -270),
    "k3#1": (-16.5, 1364.5), "k3#2": (17.5, 1364.5),
    "k4#1": (2505, 15), "k4#2": (2471, 15),
    "k5#1": (275, 640), "k5#2": (275, 674),
}
if RECORD:
    L.execute("Scenarios(); SNAP = Snapshot()")
    snap = L.eval("SNAP")
    for i in range(1, len(snap) + 1):
        e = snap[i]
        print('"%s": (%r, %r),' % (e[1], round(e[2], 4), round(e[3], 4)))
    sys.exit(0)

L.execute(r'''
Scenarios()
local keep = {}
for _, f in ipairs(ns.folders) do keep[f.id] = { f.cX, f.cY } end
N1 = ns.MigrateGroupAnchors and ns.MigrateGroupAnchors() or 0
ns.RefreshAllVisuals()
for _, id in ipairs(ORDER) do Show(RULES[id]) end
AFTER = Snapshot()
XY1 = {}
for _, f in ipairs(ns.folders) do XY1[f.id] = { f.cX or 0, f.cY or 0 } end
N2 = ns.MigrateGroupAnchors and ns.MigrateGroupAnchors() or 0
XY2SAME = true
for _, f in ipairs(ns.folders) do if (f.cX or 0) ~= XY1[f.id][1] or (f.cY or 0) ~= XY1[f.id][2] then XY2SAME = false end end
UNTOUCHED = true
for _, id in ipairs({ "k1", "k2", "k3", "k4", "k5", "mp" }) do local f = ns.FolderById(id); if f.cX ~= keep[id][1] or f.cY ~= keep[id][2] then UNTOUCHED = false end end
MOVED = {}
for _, e in ipairs(CueRulesDB.groupAnchorMoved or {}) do MOVED[#MOVED + 1] = e.id end
VER = CueRulesDB.groupAnchorVer
M1XY = { ns.FolderById("m1").cX or 0, ns.FolderById("m1").cY or 0 }
''')
after = L.eval("AFTER")
AFT = {after[i][1]: (after[i][2], after[i][3]) for i in range(1, len(after) + 1)}
bad = []
for k, (x, y) in AFT.items():
    if k.startswith("m2#"): continue   # mixed sizes: see below
    bx, by = BEFORE[k]
    if max(abs(x - bx), abs(y - by)) > 0.01: bad.append("%s %.2f,%.2f (was %.2f,%.2f)" % (k, x, y, bx, by))
check("Nothing moves: after the one-time update every icon is where 0.6.81 drew it (%d icons in 10 groups of same-size icons)" % (len(AFT) - 4), not bad, "; ".join(bad[:4]))
# m2: a Down grid of mixed sizes (32, 24, 32 x 40, 28; 2 per column, Top right). Its whole grid's Top right corner stays exactly where it
# was; inside the grid an icon smaller than its line now lines up by the grid's corner, as the combat engine has always drawn it
# (Blizzard's flow layout), instead of centred on its line: such an icon moves by up to half the size difference (an open question).
M2 = [(32, 32), (24, 24), (32, 40), (28, 28)]
def tr(prefix, src): return [src[prefix + "#%d" % i] for i in range(1, 5)]
def tr_corner(pos):   # (sizes on screen: the group's scale is 1.25)
    return max(pos[i][0] + M2[i][0] * 1.25 / 2 for i in range(4)), max(pos[i][1] + M2[i][1] * 1.25 / 2 for i in range(4))
b2, a2 = tr_corner(tr("m2", BEFORE)), tr_corner(tr("m2", AFT))
check("  ...a grid of mixed sizes: its whole grid's Top right corner is where 0.6.81 drew it", near(a2[0], b2[0]) and near(a2[1], b2[1]), "%.2f,%.2f (was %.2f,%.2f)" % (a2 + b2))
check("  ...it adjusted exactly the six Auto groups with a non-Center point (grid or outline)", L.eval("N1") == 6 and sorted(L.eval("MOVED")[i] for i in range(1, 7)) == ["m1", "m2", "m3", "m4", "m5", "m6"], "%s" % L.eval("N1"))
check("  ...Center, set size, Centered row, From anchor point and a static group inside a dynamic one keep their X / Y", L.eval("UNTOUCHED"))
m1 = L.eval("M1XY")
check("  ...her group's X / Y now hold the old offset: (-3.625, -7.375) = ((-15 + 0.5) x 0.25, (-30 + 0.5) x 0.25)", near(m1[1], -3.625) and near(m1[2], -7.375), "%s, %s" % (m1[1], m1[2]))
check("  ...once only: the saved flag is set and a second run changes nothing", L.eval("VER") == 1 and L.eval("N2") == 0 and L.eval("XY2SAME"))

if not RECORD:
    # 6. B (geometry): a group that follows another group
    L.execute(r'''
    Reset()
    ns.folders[1] = { id = "gT", name = "Target", cType = "dynamic", cGrowth = "RIGHT", cSpacing = 4, cPoint = "BOTTOMLEFT", cX = -200, cY = -100, cScale = 0.5 }
    T = { Rule("gT", 30, 30), Rule("gT", 30, 30) }
    ns.folders[2] = { id = "gA", name = "Follower", cRel = "group", cGroup = "gT", cPoint = "TOPLEFT", cX = 0, cY = 0 }
    A = { Rule("gA", 30, 30, 0, 0), Rule("gA", 30, 30, 40, 0) }
    Show(T); Show(A)
    GOT = { BoxPoint(A, "TOPLEFT") }; WANT = { BoxPoint(T, "BOTTOMLEFT") }
    ns.folders[1].cX, ns.folders[1].cY, ns.folders[1].cScale = 50, 80, 1.5
    ns.RefreshAllVisuals(); Show(T); Show(A)
    GOT2 = { BoxPoint(A, "TOPLEFT") }; WANT2 = { BoxPoint(T, "BOTTOMLEFT") }
    SIZE_A = ns.VisualFramesOf(A[1])[1]:GetWidth() * EffScale(ns.VisualFramesOf(A[1])[1])
    -- the followed group with a set size: its box, at the point chosen on it
    ns.folders[1].cSize, ns.folders[1].cW, ns.folders[1].cH = "set", 200, 80
    ns.folders[2].cRelPoint = "BOTTOMRIGHT"
    ns.RefreshAllVisuals(); Show(T); Show(A)
    GOT3 = { BoxPoint(A, "TOPLEFT") }; WANT3 = { PointAbs(ns.GroupFrame(ns.folders[1]), "BOTTOMRIGHT") }
    -- a loop is never followed: the target following back is refused by the guard, and the group falls back to the screen
    LOOP_NO = ns.GroupAnchorAllowed ~= nil and ns.GroupAnchorAllowed(ns.folders[1], ns.folders[2]) == false and ns.GroupAnchorAllowed(ns.folders[2], ns.folders[2]) == false
    ''')
    g, w = pt2("GOT"), pt2("WANT")
    check("B: a group that follows another (Auto) has its point (Top left) on that group's anchor point (its grid's bottom-left)", near(g[0], w[0]) and near(g[1], w[1]), "%.2f,%.2f vs %.2f,%.2f" % (g + w))
    g, w = pt2("GOT2"), pt2("WANT2")
    check("  ...the followed group moves and is scaled to 1.5: the follower stays on its point (no watcher)", near(g[0], w[0]) and near(g[1], w[1]), "%.2f,%.2f vs %.2f,%.2f" % (g + w))
    check("  ...and the follower's own icons keep their size (it is not scaled with the other group)", near(L.eval("SIZE_A"), 30))
    g, w = pt2("GOT3"), pt2("WANT3")
    check("  ...the followed group with a set size: the follower sits on its box's chosen point (Bottom right)", near(g[0], w[0]) and near(g[1], w[1]), "%.2f,%.2f vs %.2f,%.2f" % (g + w))
    check("  ...the loop guard: the followed group cannot follow back, and a group never follows itself", L.eval("LOOP_NO"))

if not RECORD:
    # 7. Review fixes (Rules 0.6.82, on top of 751da05). Each check here fails on 751da05.
    # 7a. "It stays where it is" (picker / Anchor to the screen) for a grid whose anchor point decides where it sits: the review measured
    #     a Right group with Bottom left: first icon 315,215 -> 218,186 after Anchor to a frame. Reanchor now keeps the grid in place.
    L.execute(r"""
    ns.MarkDirty = ns.MarkDirty or function() ns.configVersion = (ns.configVersion or 0) + 1 end   -- (Engine.lua is not loaded here)
    ns.Fire = ns.Fire or function() end
    Reset()
    ns.folders[1] = { id = "gR", name = "Right grid", cType = "dynamic", cGrowth = "RIGHT", cSpacing = 4, cPoint = "BOTTOMLEFT", cX = -600, cY = -400 }
    ns.folders[2] = { id = "gO", name = "Other", cX = -1700, cY = -1000 }   -- (left of and below the grid: the group's point becomes Bottom left)
    G = { Rule("gR", 30, 30), Rule("gR", 30, 30), Rule("gR", 30, 30) }
    O = { Rule("gO", 30, 30, 0, 0) }
    Show(G); Show(O)
    C0 = Centers(G)
    local ok, own, rel = ns.AnchorGroupToFrame(ns.folders[1], EUI, "EllesmereUIUnitFrames_Player")
    OWN = tostring(own)
    ns.RefreshAllVisuals(); Show(G); Show(O)
    C1 = Centers(G)
    local ok2, own2 = ns.AnchorGroupToGroup(ns.folders[1], ns.folders[2])
    OWN2 = tostring(own2)
    ns.RefreshAllVisuals(); Show(G); Show(O)
    C2 = Centers(G)
    ns.UnanchorGroup(ns.folders[1])
    ns.RefreshAllVisuals(); Show(G); Show(O)
    C3 = Centers(G)
    PT3 = tostring(ns.folders[1].cPoint)
    """)
    def same_centers(a, b, tol=1.0):
        return all(abs(a[i][1] - b[i][1]) <= tol and abs(a[i][2] - b[i][2]) <= tol for i in range(1, len(a) + 1))
    def fmt(c): return "%.1f,%.1f" % (c[1][1], c[1][2])
    c0, c1, c2, c3 = L.eval("C0"), L.eval("C1"), L.eval("C2"), L.eval("C3")
    check("review 1: Right grid with Bottom left, Anchor to a frame (its point becomes %s): every icon stays where it was" % L.eval("OWN"),
          L.eval("OWN") != "BOTTOMLEFT" and same_centers(c0, c1), "first icon %s -> %s" % (fmt(c0), fmt(c1)))
    check("  ...anchored to another group (its point becomes %s): the icons stay" % L.eval("OWN2"), L.eval("OWN2") == "BOTTOMLEFT" and same_centers(c1, c2), "%s -> %s" % (fmt(c1), fmt(c2)))
    check("  ...Anchor to the screen (point back to Center): the icons stay", L.eval("PT3") == "nil" and same_centers(c2, c3), "%s -> %s" % (fmt(c2), fmt(c3)))
    # 7b. the same with nothing showing (out of the mover view): the grid of every switched-on item is kept, so it shows where it was
    L.execute(r"""
    Reset()
    ns.folders[1] = { id = "gH", name = "Hidden grid", cType = "dynamic", cGrowth = "DOWN", cSpacing = 2, cPoint = "TOPRIGHT", cX = -600, cY = -350, cScale = 0.75 }
    H = { Rule("gH", 30, 30), Rule("gH", 30, 30) }
    Show(H); D0 = Centers(H); Show(H, false)
    ns.AnchorGroupToFrame(ns.folders[1], EUI, "EllesmereUIUnitFrames_Player")
    HPT = tostring(ns.folders[1].cPoint)
    ns.RefreshAllVisuals(); Show(H)
    D1 = Centers(H)
    """)
    d0, d1 = L.eval("D0"), L.eval("D1")
    check("  ...nothing showing when it is anchored (point %s): once shown, the Down grid is where it was" % L.eval("HPT"), L.eval("HPT") != "TOPRIGHT" and same_centers(d0, d1), "%s -> %s" % (fmt(d0), fmt(d1)))
    # 7c. a hand-placed Auto group with a corner point (outline): the same paths keep it in place (parity with 7a)
    L.execute(r"""
    Reset()
    ns.folders[1] = { id = "gS", name = "Hand placed", cPoint = "TOPLEFT", cX = -650, cY = -380, cScale = 0.5 }
    S = { Rule("gS", 40, 40, -30, 0), Rule("gS", 30, 20, 40, 25) }
    Show(S); E0 = Centers(S)
    ns.AnchorGroupToFrame(ns.folders[1], EUI, "EllesmereUIUnitFrames_Player"); ns.RefreshAllVisuals(); Show(S); E1 = Centers(S)
    ns.UnanchorGroup(ns.folders[1]); ns.RefreshAllVisuals(); Show(S); E2 = Centers(S)
    """)
    e0, e1, e2 = L.eval("E0"), L.eval("E1"), L.eval("E2")
    check("  ...a hand-placed group (outline, Top left): Anchor to a frame and to the screen keep its displays in place", same_centers(e0, e1) and same_centers(e1, e2), "%s -> %s -> %s" % (fmt(e0), fmt(e1), fmt(e2)))
    # 7d. the settings page's point list still moves the icons (her answer), also for a grid: only cPoint changes
    L.execute(r"""
    Reset()
    ns.folders[1] = { id = "gP", name = "Point list", cType = "dynamic", cGrowth = "RIGHT", cSpacing = 4, cPoint = "BOTTOMLEFT", cX = 100, cY = 100 }
    P = { Rule("gP", 30, 30), Rule("gP", 30, 30) }
    Show(P); F0 = Centers(P)
    ns.folders[1].cPoint = "TOPRIGHT"; ns.RefreshAllVisuals(); Show(P)
    F1 = { BoxPoint(P, "TOPRIGHT") }
    """)
    f1 = pt2("F1")
    check("  ...the settings page's point (Top right) still moves the icons: the grid's top-right is on the screen's top-right + X / Y", near(f1[0], 2020) and near(f1[1], 1180), "%.2f,%.2f" % f1)

    # 7e. review 2: a nested group anchored to the screen inside a parent of scale 0.5 that follows a group that is deleted: it stays put
    L.execute(r"""
    Reset()
    ns.folders[1] = { id = "pP", name = "Parent", cScale = 0.5, cX = 100, cY = 50 }
    ns.folders[2] = { id = "pT", name = "Followed", cX = 300, cY = 200 }
    ns.folders[3] = { id = "pN", name = "Nested", parent = "pP", cAnchorTo = "screen", cRel = "group", cGroup = "pT", cX = 20, cY = 10 }
    PT = { Rule("pT", 30, 30, 0, 0) }
    PN = { Rule("pN", 30, 30, 0, 0) }
    Show(PT); Show(PN)
    N0 = Centers(PN)
    REL = ns.ReleaseGroupAnchors({ pT = true })
    ns.RefreshAllVisuals(); Show(PN)
    N1 = Centers(PN)
    NXY = { ns.folders[3].cX, ns.folders[3].cY }
    NLINK = tostring(ns.folders[3].cRel) .. " " .. tostring(ns.folders[3].cGroup)
    """)
    n0, n1, nxy = L.eval("N0"), L.eval("N1"), L.eval("NXY")
    check("review 2: nested in a parent of scale 0.5, anchored to the screen, its followed group deleted: it stays where it was (link cleared)",
          L.eval("NLINK") == "nil nil" and same_centers(n0, n1), "%s -> %s, X / Y %s, %s" % (fmt(n0), fmt(n1), nxy[1], nxy[2]))

    # 7f. review 5: measuring a group (its anchor point, for the picker's box or the unlocked handle) never makes the dot; a followed group has one
    L.execute(r"""
    Reset()
    ns.folders[1] = { id = "dM", name = "Measured", cSize = "set", cW = 120, cH = 60, cPoint = "BOTTOMLEFT", cX = 40, cY = 30 }
    ns.folders[2] = { id = "dQ", name = "Quiet", cPoint = "TOPRIGHT", cX = -40, cY = 0 }
    Rule("dQ", 30, 30, 0, 0)
    AXY = { ns.GroupAnchorXY(ns.folders[1]) }
    BXY = { PointAbs(ns.GroupFrame(ns.folders[1]), "BOTTOMLEFT") }
    QXY = { ns.GroupAnchorXY(ns.folders[2]) }
    NODOT = ns.GroupFrame(ns.folders[1]).xuiDot == nil and ns.GroupFrame(ns.folders[2]).xuiDot == nil
    ns.folders[3] = { id = "dF", name = "Follower", cRel = "group", cGroup = "dQ" }
    Rule("dF", 30, 30, 0, 0)
    ns.RefreshAllVisuals()
    DOTQ = ns.GroupFrame(ns.folders[2]).xuiDot ~= nil
    QXY2 = { ns.GroupAnchorXY(ns.folders[2]) }
    """)
    a_, b_ = pt2("AXY"), pt2("BXY")
    q1, q2 = pt2("QXY"), pt2("QXY2")
    check("review 5: measuring a group's anchor point makes no dot frame (a set box and an outline group)", L.eval("NODOT"))
    check("  ...the measured point is right without it: the set box's bottom-left", near(a_[0], b_[0]) and near(a_[1], b_[1]), "%.2f,%.2f vs %.2f,%.2f" % (a_ + b_))
    check("  ...a group that is followed gets its dot, at the same point as measured without it", L.eval("DOTQ") and near(q1[0], q2[0]) and near(q1[1], q2[1]), "%.2f,%.2f vs %.2f,%.2f" % (q1 + q2))

    # 7g. review 4: one refresh pass measures each hand-placed group's outline once (it walked every rule for every display before)
    L.execute(r"""
    Reset()
    ns.folders[1] = { id = "oB", name = "Big hand placed", cPoint = "BOTTOMLEFT", cX = -300, cY = -200 }
    OB = {}
    for i = 1, 20 do OB[i] = Rule("oB", 20, 20, (i - 10) * 25, 0) end
    Show(OB)
    X0 = Centers({ OB[2] })[1][1]
    local vp, calls = ns.VisualPoints, 0
    ns.VisualPoints = function(...) calls = calls + 1; return vp(...) end   -- (the outline reads each display's points through it)
    local w0 = ns.GroupOutlineWalks and ns.GroupOutlineWalks() or 0
    ns.RefreshAllVisuals()
    WALKS = ns.GroupOutlineWalks and (ns.GroupOutlineWalks() - w0) or -1
    VPCALLS = calls
    ns.VisualPoints = vp
    -- the cache follows edits: a display moved (a settings edit bumps ns.configVersion) is in the next pass
    OB[1].visual.x = -400; ns.configVersion = (ns.configVersion or 0) + 1
    ns.RefreshAllVisuals(); Show(OB)
    X1 = Centers({ OB[2] })[1][1]
    -- and outside a pass the outline is read at once (a drag / a nudge between two passes)
    OB[1].visual.x = -500
    ns.GroupFrame(ns.folders[1]); ns.RefreshVisual(OB[1]); for i = 2, 20 do ns.RefreshVisual(OB[i]) end
    X2 = Centers({ OB[2] })[1][1]
    """)
    walks, vpc = L.eval("WALKS"), L.eval("VPCALLS")
    check("review 4: one refresh pass of a 20-display hand-placed group reads the displays' points about once each (not 20 x 20)", vpc <= 60, vpc)
    check("  ...its outline is measured once in that pass", walks == 1, walks)
    x0, x1, x2 = L.eval("X0"), L.eval("X1"), L.eval("X2")
    check("  ...the next pass after a settings edit uses the new outline: the left display moved 175 px left, the outline's corner stays, the others move 175 right",
          near(x1 - x0, 175), "%.2f" % (x1 - x0))
    check("  ...outside a pass the outline is read at once (100 px more: the others 275 right of where they started)", near(x2 - x0, 275), "%.2f" % (x2 - x0))

print(); print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED"); sys.exit(1 if fails else 0)
