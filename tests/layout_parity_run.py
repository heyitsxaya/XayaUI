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
-- Blizzard's enums the engine passes to its container (12.1.5 AnchorUtil.lua)
AnchorUtil = { FlowLayoutAxis = { Horizontal = 0, Vertical = 1 }, FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
-- the container's aura groups and flow settings, recorded so the flow model below can lay them out
local function G(self) self._groups = self._groups or {}; self._ng = self._ng or 0; return self._groups end
function M:AddAuraGroup(key, filter, o) local g = G(self); self._ng = self._ng + 1; g[key] = { layout = o.layout, enabled = true, order = self._ng } end
function M:SetAuraGroupLayout(key, l) G(self)[key].layout = l end
function M:SetAuraGroupEnabled(key, en) G(self)[key].enabled = en end
function M:SetFlowLayoutAxis(a) self._flow = self._flow or {}; self._flow.axis = a end
function M:SetFlowLayoutAnchorPoint(p) self._flow = self._flow or {}; self._flow.anchor = p end
function M:SetFlowLayoutGrowthDirection(h, v) self._flow = self._flow or {}; self._flow.h, self._flow.v = h, v end
function M:SetFlowLayoutMaximumLineSize(m) self._flow = self._flow or {}; self._flow.max = m end
-- A model of Blizzard's flow layout (12.1.5 AnchorUtil.ApplyFlowLayout, CustomAuraContainer OnLayoutComplete), written for this test
-- from reading the game's UI source (no code copied): enabled groups in layoutIndex order (then the order they were added); an empty
-- group adds nothing; groupSpacing goes before a non-empty group that continues the line (and may wrap it); every element is
-- followed by elementSpacing; an element that would make the line longer than the maximum starts a new line, lineSpacing below the
-- thickest element of the line; each element sits by the flow's anchor corner at the cursor; the container then takes the size of
-- what was placed. counts[key] = how many icons that group shows (default 1). Returns each icon's screen centre, in group order.
function FlowModel(c, counts)
  local f = c._flow
  local list = {}
  for key, g in pairs(c._groups or {}) do if g.enabled then list[#list + 1] = { key = key, g = g } end end
  table.sort(list, function(a, b)
    local la, lb = a.g.layout.layoutIndex or math.huge, b.g.layout.layoutIndex or math.huge
    if la ~= lb then return la < lb end
    return a.g.order < b.g.order
  end)
  local vertical = (f.axis == 1)
  local pdir, cdir = vertical and f.v or f.h, vertical and f.h or f.v
  local maxLine = f.max or math.huge
  local cp, cc, lineP, lineC, layP, layC, placed = 0, 0, 0, 0, 0, 0, false
  local out = {}
  local function NewLine(gap) cp = 0; cc = cc + (lineC + gap) * cdir; lineP, lineC = 0, 0 end
  for _, e in ipairs(list) do
    local l = e.g.layout
    local n = (counts and counts[e.key]) or 1
    local es, ls, gs = l.elementSpacing or 0, l.lineSpacing or 0, l.groupSpacing or 0
    local gls = l.groupLineSpacing or ls
    if placed and n > 0 and gs > 0 then
      if lineP > 0 and lineP + gs > maxLine then NewLine(gls) else cp = cp + gs * pdir; lineP = lineP + gs end
    end
    for _ = 1, n do
      local w, h = l.elementWidth, l.elementHeight
      local ep, ec = vertical and h or w, vertical and w or h
      local nextP = (lineP > 0) and (lineP + ep) or ep
      if lineP > 0 and nextP > maxLine then NewLine(ls); nextP = ep end
      out[#out + 1] = { key = e.key, w = w, h = h, ox = vertical and cc or cp, oy = vertical and cp or cc }
      cp = cp + (ep + es) * pdir
      lineP = nextP + es
      lineC = math.max(lineC, ec)
      layP = math.max(layP, lineP - es)
      layC = math.max(layC, math.abs(cc) + ec)
      placed = true
    end
  end
  c:SetSize(math.max(vertical and layC or layP, 1), math.max(vertical and layP or layC, 1))
  local ax, ay = PointAbs(c, f.anchor)
  local s = EffScale(c)
  for _, o in ipairs(out) do   -- the element's anchor point -> its centre
    local v = V[f.anchor]
    o.x = ax + o.ox * s - v[1] * o.w * s
    o.y = ay + o.oy * s - v[2] * o.h * s
  end
  return out
end
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
for f in ("XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI_Rules/RuleDefaults.lua", "XayaUI_Rules/Conditions.lua", "XayaUI_Rules/Outcomes.lua", "XayaUI_Rules/Cues.lua", "XayaUI_Rules/Visual.lua"):
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
        '''.replace("ENGINE_PATH", repr(os.path.join(ROOT, "XayaUI_Rules", "Combat", "AuraDisplay.lua")).replace("'", '"')))
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
# Block growth (Centered row / column, From anchor point) and Manual order: EVERY icon of the engine's container (laid out by the flow
# model above, the container pinned where the engine pins it) must land on XayaUI's own icon for the same rule, also when some auras
# are down (the group closes up and the block grows / shrinks around its pin), with mixed icon sizes, wrapping, nested groups and scale.
BLOCKS = [
    # growth, group anchor point, sizes (w, h) per rule, shown (1-based rule numbers), extra group fields
    ("HCENTER", "CENTER", [(30, 30)] * 4, [1, 2, 3, 4], {}),
    ("HCENTER", "CENTER", [(30, 30)] * 5, [1, 2, 3, 4, 5], {"cWrapN": 2}),
    ("HCENTER", "CENTER", [(30, 30)] * 5, [1, 2, 3, 4, 5], {"cWrapN": 2, "cWrapRev": True}),
    ("VCENTER", "CENTER", [(30, 30)] * 4, [1, 3, 4], {}),
    ("VCENTER", "CENTER", [(30, 30)] * 5, [1, 2, 3, 4, 5], {"cWrapN": 2, "cWrapRev": True}),
    ("HCENTER", "TOPLEFT", [(40, 40), (24, 24), (32, 48)], [1, 2, 3], {"cX": 50, "cY": -20, "cScale": 1.25}),
]
for pt in ("TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"):
    BLOCKS.append(("ANCHOR_ROW", pt, [(36, 36), (24, 24), (30, 40), (36, 36)], [1, 2, 3, 4], {"cW": 120, "cH": 60, "cX": 15, "cY": -10}))
    BLOCKS.append(("ANCHOR_COL", pt, [(36, 36), (24, 24), (40, 30), (36, 36)], [1, 2, 3, 4], {"cW": 60, "cH": 110, "cScale": 0.8}))
    BLOCKS.append(("ANCHOR_ROW", pt, [(30, 30)] * 4, [2, 4], {"cW": 0, "cH": 0}))   # two auras down: the block closes up around the anchor
BLOCKS += [
    ("ANCHOR_ROW", "BOTTOMRIGHT", [(30, 30)] * 6, [1, 2, 3, 4, 5, 6], {"cWrapN": 4, "cParent": (-200, 100)}),
    ("ANCHOR_COL", "TOPRIGHT", [(30, 30)] * 6, [1, 3, 4, 5, 6], {"cWrapN": 3}),
    # edge growths in Manual order (rule order): every icon, equal sizes (the members' spacing, #17)
    ("RIGHT", "CENTER", [(30, 30)] * 4, [1, 2, 3, 4], {}),
    ("DOWN", "CENTER", [(30, 30)] * 4, [1, 2, 3, 4], {"cWrapN": 2}),
    ("LEFT", "CENTER", [(30, 30)] * 4, [1, 3, 4], {}),
]
for k, (dir, pt, sizes, shown, extra) in enumerate(BLOCKS):
    n = len(sizes)
    L.execute(r'''
    local ns, dir, pt, n, k, sp = NS, ...
    ns.folders, ns.rules = {}, {}
    CueRulesDB.folders, CueRulesDB.rules = ns.folders, ns.rules
    BF = { id = "fb" .. k, name = "B" .. k, cType = "dynamic", cGrowth = dir, cPoint = pt, cSpacing = sp, cW = 0, cH = 0 }
    ns.folders[1] = BF
    BRULES = {}
    ''', dir, pt, n, k, 6)
    for key, val in extra.items():
        if key == "cParent":
            L.execute(r'''local ns, px, py, k = NS, ...; ns.folders[2] = { id = "fbp" .. k, name = "BP" .. k, cType = "static", cX = px, cY = py, cW = 0, cH = 0 }; BF.parent = "fbp" .. k''', val[0], val[1], k)
        else:
            L.globals().BF[key] = val
    for i, (w, h) in enumerate(sizes, 1):
        L.execute(r'''
        local ns, i, w, h, k = NS, ...
        local r = { uid = "b" .. k .. "_" .. i, name = "b" .. i, folder = "fb" .. k, useBuff = true, buffID = 6000 + i, enabled = true,
          visual = { enabled = true, trigger = "buffActive", w = w, h = h } }
        ns.rules[#ns.rules + 1] = r
        if ns.NormalizeRule then pcall(ns.NormalizeRule, r) end
        r.visual.enabled, r.visual.w, r.visual.h, r.visual.trigger = true, w, h, "buffActive"
        BRULES[i] = r
        ''', i, w, h, k)
    shown_lua = L.table_from({i: True for i in shown})
    L.execute(r'''
    local ns, shown = NS, ...
    for i, r in ipairs(BRULES) do ns.SetVisualShown(r, shown[i] == true) end
    -- XayaUI's own spots first (once the engine draws a rule, XayaUI hides its own icon for it)
    local xui, xsz = {}, {}
    local l, b, r_, t
    for i, r in ipairs(BRULES) do
      if shown[i] then
        local fr = ns.VisualFramesOf(r)[1]
        xui[i] = { CenterAbs(fr) }
        xsz[i] = fr:GetWidth() * EffScale(fr)
        local hw, hh = xsz[i] / 2, fr:GetHeight() * EffScale(fr) / 2
        local x, y = xui[i][1], xui[i][2]
        l = l and math.min(l, x - hw) or (x - hw); r_ = r_ and math.max(r_, x + hw) or (x + hw)
        b = b and math.min(b, y - hh) or (y - hh); t = t and math.max(t, y + hh) or (y + hh)
      end
    end
    BBOX = { l, b, r_, t }
    GPOINT = function(pt) return PointAbs(ns.GroupFrame(BF), pt) end
    for k in pairs(ns.AuraDisplay._groups) do ns.AuraDisplay._groups[k] = nil end
    ns.AuraDisplay.Build()
    local g = ns.AuraDisplay._groups[BF.id]
    assert(g and g.ok, "engine group not built: " .. tostring(g and g.err))
    local counts = {}
    for i, key in ipairs(g.memberKey) do counts[key] = shown[i] and 1 or 0 end
    local placed = FlowModel(g.frame, counts)
    local byKey = {}
    for _, o in ipairs(placed) do byKey[o.key] = o end
    BRES, BSIZE = {}, true
    for i, r in ipairs(BRULES) do
      if shown[i] then
        local x, y = xui[i][1], xui[i][2]
        local o = byKey[g.memberKey[i]]
        if not o then BRES[#BRES + 1] = { i, x, y, -1, -1 }; BSIZE = false
        else
          BRES[#BRES + 1] = { i, x, y, o.x, o.y }
          if math.abs(xsz[i] - o.w * EffScale(g.frame)) > 0.001 then BSIZE = false end
        end
      end
    end
    BKEYS = #g.memberKey
    ''', shown_lua)
    res = L.eval("BRES")
    worst, detail = 0, []
    for j in range(1, len(res) + 1):
        i, xx, xy, ex, ey = (res[j][q] for q in range(1, 6))
        d = max(abs(xx - ex), abs(xy - ey))
        worst = max(worst, d)
        if d >= 0.01: detail.append("rule %d: XayaUI %.2f,%.2f vs engine %.2f,%.2f" % (i, xx, xy, ex, ey))
    label = "%s, anchor %s, sizes %s, shown %s%s" % (dir, pt, "mixed" if len(set(sizes)) > 1 else sizes[0], shown, (" " + str(extra)) if extra else "")
    # what the growth means, stated here on its own (not read from either implementation): the block of shown icons has its
    # `pin` point on the group frame's `pinTo` point
    rev = bool(extra.get("cWrapRev"))
    want = {"HCENTER": ("BOTTOM" if rev else "TOP", "CENTER"), "VCENTER": ("RIGHT" if rev else "LEFT", "CENTER"),
            "ANCHOR_ROW": (pt, pt), "ANCHOR_COL": (pt, pt)}.get(dir)
    if want:
        bl, bb, br, bt = (L.eval("BBOX")[q] for q in range(1, 5))
        VV = {"CENTER": (0, 0), "TOP": (0, .5), "BOTTOM": (0, -.5), "LEFT": (-.5, 0), "RIGHT": (.5, 0), "TOPLEFT": (-.5, .5), "TOPRIGHT": (.5, .5), "BOTTOMLEFT": (-.5, -.5), "BOTTOMRIGHT": (.5, -.5)}
        v = VV[want[0]]
        px, py = (bl + br) / 2 + v[0] * (br - bl), (bb + bt) / 2 + v[1] * (bt - bb)
        gx, gy = L.eval("GPOINT")(want[1])
        check("  ...the icons' %s sits on the group's %s" % want, max(abs(px - gx), abs(py - gy)) < 0.01, "icons %.2f,%.2f vs group %.2f,%.2f" % (px, py, gx, gy))
    check("every icon on XayaUI's spot: " + label, worst < 0.01 and len(res) == len(shown), "; ".join(detail[:3]))
    check("  ...and the same size on screen", L.eval("BSIZE"))
# the engine's own copy of the block definition agrees with Visual.lua's for every growth, anchor point and wrap side
L.execute(r'''
BLOCK_SAME = true
for _, dir in ipairs({ "RIGHT", "LEFT", "DOWN", "UP", "HCENTER", "VCENTER", "ANCHOR_ROW", "ANCHOR_COL" }) do
  for _, pt in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
    for _, rev in ipairs({ false, true }) do
      local fo = { cGrowth = dir, cPoint = pt, cWrapRev = rev or nil }
      local a, b = NS.DynamicBlock(fo), NS.AuraDisplay._BlockFallback(fo)
      if (a == nil) ~= (b == nil) then BLOCK_SAME = false end
      if a and b then for _, f in ipairs({ "horiz", "right", "down", "corner", "pin", "pinTo" }) do if a[f] ~= b[f] then BLOCK_SAME = false end end end
    end
  end
end
''')
check("engine fallback block definition = Visual.lua's (8 growths x 9 anchor points x 2 wrap sides)", L.eval("BLOCK_SAME"))

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
