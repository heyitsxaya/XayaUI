"""Parity test: the combat engine's icons must land exactly where XayaUI draws a dynamic group's first display, for every growth
direction, nested groups with their own offsets, group scale and group anchor points.
It runs XayaUI's real Core.lua + Visual.lua layout and the engine's real AuraDisplay.lua placement against stand-in frames that
resolve real screen positions (anchors, parents, scale), then compares the two first-icon centres.
Run: python3 tests/layout_parity_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
STUBS = bench[a:b]
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(STUBS)
L.execute(r'''
COMBAT = false
local M = FRAME_METHODS
-- real geometry: size, scale, parent, one anchor
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
  self._pt = { p, rel, rp or p, x or 0, y or 0 }
end
local V = { CENTER = {0,0}, TOP = {0,.5}, BOTTOM = {0,-.5}, LEFT = {-.5,0}, RIGHT = {.5,0},
  TOPLEFT = {-.5,.5}, TOPRIGHT = {.5,.5}, BOTTOMLEFT = {-.5,-.5}, BOTTOMRIGHT = {.5,-.5} }
function EffScale(f) local s = 1; while f and f ~= UIParent do s = s * (f._scale or 1); f = f._parent end return s end
function PointAbs(f, pt)   -- screen position of a named point of f
  local cx, cy = CenterAbs(f); local s = EffScale(f); local v = V[pt]
  return cx + v[1] * f:GetWidth() * s, cy + v[2] * f:GetHeight() * s
end
function CenterAbs(f)
  if f == UIParent then return 960, 540 end
  local a = f._pt; assert(a, "frame has no anchor")
  local rx, ry = PointAbs(a[2], a[3]); local s = EffScale(f); local v = V[a[1]]
  local px, py = rx + a[4] * s, ry + a[5] * s          -- where f's own point sits
  return px - v[1] * f:GetWidth() * s, py - v[2] * f:GetHeight() * s
end
UIParent._w, UIParent._h = 1920, 1080
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
for f in ("Core.lua", "Conditions.lua", "Outcomes.lua", "Cues.lua", "Visual.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute(r'''
local ns = NS
ns.Print = function() end
ns.runtime = ns.runtime or {}
XayaUI_NS = ns
CueRulesDB.engineDisplay = { groups = {}, auto = true }
''')
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)

CASES = [
    # growth, group point, group offsets, scale, parent offsets (None = top level), icon size
    ("RIGHT", "CENTER", (10, 20), 1, None, 30),
    ("LEFT", "CENTER", (-200, 40), 1, None, 32),
    ("DOWN", "CENTER", (-98, -187), 1, (-409, -2), 30),      # Xaya's Active Mitigation inside Personal Buff Tracking
    ("UP", "TOPLEFT", (5, -7), 1.5, (100, 50), 36),
    ("DOWN", "BOTTOMRIGHT", (-30, 30), 0.8, (0, 0), 28),
    ("RIGHT", "TOPLEFT", (0, 0), 2, (-300, 200), 24),
    # extra rows / columns on the other side (Items per row / column + "New rows go above / to the left")
    ("RIGHT", "CENTER", (10, 20), 1, None, 30, True),
    ("LEFT", "CENTER", (-200, 40), 1, None, 32, True),
    ("DOWN", "CENTER", (-98, -187), 1, (-409, -2), 30, True),
    ("UP", "TOPLEFT", (5, -7), 1.5, (100, 50), 36, True),
]
for i, case in enumerate(CASES):
    (dir, pt, off, sc, poff, sz), rev = case[:6], (len(case) > 6 and case[6])
    L.execute(r'''
    local ns, dir, pt, ox, oy, sc, hasParent, px, py, sz, i, rev = NS, ...
    ns.folders, ns.rules = {}, {}
    CueRulesDB.folders, CueRulesDB.rules = ns.folders, ns.rules
    local parentId
    if hasParent then parentId = "fp" .. i; ns.folders[#ns.folders + 1] = { id = parentId, name = "P" .. i, cType = "dynamic", cGrowth = "DOWN", cX = px, cY = py } end
    ns.folders[#ns.folders + 1] = { id = "fg" .. i, name = "G" .. i, parent = parentId, cType = "dynamic", cGrowth = dir, cPoint = pt, cX = ox, cY = oy, cScale = sc, cW = 0, cH = 0, cWrapRev = rev or nil }
    RULE = { uid = "u" .. i, name = "r" .. i, folder = "fg" .. i, useBuff = true, buffID = 5000 + i, enabled = true,
      visual = { enabled = true, trigger = "buffActive", w = sz, h = sz } }
    ns.rules[1] = RULE
    if ns.NormalizeRule then pcall(ns.NormalizeRule, RULE) end
    RULE.visual.enabled, RULE.visual.w, RULE.visual.h = true, sz, sz
    ns.SetVisualShown(RULE, true)          -- XayaUI lays the group out (outside a step: at once)
    local fr = ns.VisualFramesOf(RULE)[1]
    XUI_X, XUI_Y = CenterAbs(fr)
    ''', dir, pt, off[0], off[1], sc, poff is not None, (poff or (0, 0))[0], (poff or (0, 0))[1], sz, i, bool(rev))
    xui = (L.eval("XUI_X"), L.eval("XUI_Y"))
    if i == 0:
        L.execute(r'''
        local f = assert(loadfile(ENGINE_PATH)); f("XayaUI_CombatEngine", NS)
        '''.replace("ENGINE_PATH", repr(os.path.join(ROOT, "XayaUI_CombatEngine", "AuraDisplay.lua")).replace("'", '"')))
    L.execute(r'''
    local ns = NS
    for k in pairs(ns.AuraDisplay._groups) do ns.AuraDisplay._groups[k] = nil end
    ns.AuraDisplay.Build()
    local g = ns.AuraDisplay._groups["fg" .. ...]
    assert(g and g.ok, "engine group not built: " .. tostring(g and g.err))
    local c = g.frame
    local a = c._pt
    -- first icon centre = the container's anchored corner + (corner -> centre) in icon sizes, at the container's scale
    local V = { CENTER = {0,0}, TOP = {0,-.5}, BOTTOM = {0,.5}, LEFT = {.5,0}, RIGHT = {-.5,0}, TOPLEFT = {.5,-.5}, TOPRIGHT = {-.5,-.5}, BOTTOMLEFT = {.5,.5}, BOTTOMRIGHT = {-.5,.5} }
    local rx, ry = PointAbs(a[2], a[3]); local s = EffScale(c)
    local sz = RULE.visual.w
    ENG_X = rx + a[4] * s + V[a[1]][1] * sz * s
    ENG_Y = ry + a[5] * s + V[a[1]][2] * sz * s
    ENG_HOSTED = (c._parent ~= nil and c._parent ~= UIParent)
    ''', i)
    eng = (L.eval("ENG_X"), L.eval("ENG_Y"))
    d = max(abs(xui[0] - eng[0]), abs(xui[1] - eng[1]))
    check("%s%s, group point %s, offset %s, scale %s, parent %s: engine icon on XayaUI's spot" % (dir, " (extra lines on the other side)" if rev else "", pt, off, sc, poff), d < 0.01,
          "XayaUI %.2f,%.2f vs engine %.2f,%.2f" % (xui + eng))
    check("  ...and hosted by XayaUI's group frame", L.eval("ENG_HOSTED"))
# XayaUI's own layout: wrap after N items, extra rows / columns on either side
WRAPS = [
    # growth, items per line, reverse
    ("RIGHT", 2, False), ("RIGHT", 2, True), ("LEFT", 3, False), ("DOWN", 2, False), ("DOWN", 2, True), ("UP", 2, True),
]
for k, (dir, n, rev) in enumerate(WRAPS):
    L.execute(r'''
    local ns, dir, n, rev, k = NS, ...
    ns.folders, ns.rules = {}, {}
    CueRulesDB.folders, CueRulesDB.rules = ns.folders, ns.rules
    ns.folders[1] = { id = "fw", name = "W", cType = "dynamic", cGrowth = dir, cSpacing = 5, cW = 0, cH = 0, cWrapN = n, cWrapRev = rev or nil }
    WRAPPED = {}
    for i = 1, 5 do
      local r = { uid = "w" .. i, name = "w" .. i, folder = "fw", useBuff = true, buffID = 8000 + i, enabled = true,
        visual = { enabled = true, trigger = "buffActive", w = 30, h = 30 } }
      ns.rules[i] = r
      if ns.NormalizeRule then pcall(ns.NormalizeRule, r) end
      r.visual.enabled, r.visual.w, r.visual.h = true, 30, 30
      ns.SetVisualShown(r, true)
    end
    for i = 1, 5 do
      local fr = ns.VisualFramesOf(ns.rules[i])[1]
      local x, y = CenterAbs(fr)
      WRAPPED[i] = { x, y }
    end
    ''', dir, n, bool(rev), k)
    W_ = L.eval("WRAPPED"); pos = [(W_[i][1], W_[i][2]) for i in range(1, 6)]
    rel = [(round(p[0] - pos[0][0], 2), round(p[1] - pos[0][1], 2)) for p in pos]
    horiz = dir in ("RIGHT", "LEFT")
    along = {"RIGHT": (1, 0), "LEFT": (-1, 0), "DOWN": (0, -1), "UP": (0, 1)}[dir]
    across = (0, -1) if horiz else (1, 0)
    if rev: across = (-across[0], -across[1])
    want = []
    for i in range(5):
        col, row = i % n, i // n
        want.append((round(35 * (col * along[0] + row * across[0]), 2), round(35 * (col * along[1] + row * across[1]), 2)))
    check("XayaUI wraps %s after %d%s: positions %s" % (dir, n, " (other side)" if rev else "", want), rel == want, "got %s" % rel)
# Single slots (no group, or a static group): the engine icon must sit exactly on XayaUI's own icon
SINGLES = [
    # group (None = no group), group offsets, group scale, display offsets, size
    (None, (0, 0), 1, (-250, 120), 48),
    ("static", (300, -40), 1.5, (12, -8), 36),
    ("static", (-60, 200), 0.75, (0, 0), 64),
]
for j, (grp, goff, gsc, voff, sz) in enumerate(SINGLES):
    L.execute(r'''
    local ns, hasGroup, gx, gy, gsc, vx, vy, sz, j = NS, ...
    ns.folders, ns.rules = {}, {}
    CueRulesDB.folders, CueRulesDB.rules = ns.folders, ns.rules
    local fid
    if hasGroup then fid = "fs" .. j; ns.folders[1] = { id = fid, name = "S" .. j, cX = gx, cY = gy, cScale = gsc, cW = 0, cH = 0 } end
    RULE = { uid = "s" .. j, name = "single" .. j, folder = fid, useBuff = true, buffID = 7000 + j, buffState = "present", enabled = true,
      visual = { enabled = true, trigger = "buffActive", w = sz, h = sz, x = vx, y = vy } }
    ns.rules[1] = RULE
    if ns.NormalizeRule then pcall(ns.NormalizeRule, RULE) end
    RULE.visual.enabled, RULE.visual.w, RULE.visual.h, RULE.visual.x, RULE.visual.y, RULE.visual.trigger = true, sz, sz, vx, vy, "buffActive"
    ns.SetVisualShown(RULE, true)
    local fr = ns.VisualFramesOf(RULE)[1]
    XUI_X, XUI_Y = CenterAbs(fr)
    ns.AuraDisplay.Build()
    local s = ns.AuraDisplay._singles[RULE]
    assert(s and s.ok, "single slot not built: " .. tostring(s and s.err))
    local c = s.frame
    local a = c._pt
    local rx, ry = PointAbs(a[2], a[3]); local es = EffScale(c)
    -- the slot's TOPLEFT corner + half an icon right and down = the icon centre
    ENG_X = rx + a[4] * es + 0.5 * sz * es
    ENG_Y = ry + a[5] * es - 0.5 * sz * es
    SIZE_OK = math.abs(sz * es - fr:GetWidth() * EffScale(fr)) < 0.001
    ''', grp is not None, goff[0], goff[1], gsc, voff[0], voff[1], sz, j)
    xui = (L.eval("XUI_X"), L.eval("XUI_Y")); eng = (L.eval("ENG_X"), L.eval("ENG_Y"))
    d = max(abs(xui[0] - eng[0]), abs(xui[1] - eng[1]))
    check("single (%s group, offset %s, scale %s, display offset %s, size %s): engine icon on XayaUI's icon" % (grp or "no", goff, gsc, voff, sz), d < 0.01,
          "XayaUI %.2f,%.2f vs engine %.2f,%.2f" % (xui + eng))
    check("  ...and the same size on screen", L.eval("SIZE_OK"))

print(); print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED"); sys.exit(1 if fails else 0)
