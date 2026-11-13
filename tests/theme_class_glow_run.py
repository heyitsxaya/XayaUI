#!/usr/bin/env python3
"""Class themes: the per-class override table for the "class" base (XayaUI 0.6.86, Options 0.6.109; XayaUI/Theme.lua T.CLASS_THEMES).
Xaya 2026-11-13: the resmoothed Druid glow. It keeps every original colour, but the orange -> lilac change now spreads over 40-66 %
of the bar. Hex values are the source of truth (hex / 255 for Lua floats); "all newly passed themes get total override priority".
The glow is the class base's parent-group glow (the bar behind a selected rule's top parent group in the rule list, TreePaint.lua);
its rule-name colour is that row's text. The game draws a gradient of n stops as n - 1 evenly spaced pieces (Theme.lua Strip), so
the table holds the even resample of the designed stops (checked here against the designed stops and positions).
Loads the real addons in the stand-in game (Lua 5.1 via lupa) with the player a Druid, sets up rules in nested groups, opens the
window, selects a nested rule, runs the decorate pass and reads what is DRAWN on the top parent group's row.
  A The table: DRUID's glow, rule-name and Ready colours are exactly her hex / 255; the even resample matches her designed stops
    at 0, 1/7 ... 7/7 of the bar (linear in sRGB, rounded to a byte).
  B Druid, Class colors: the row draws the 8 colours left to right in 7 pieces covering the row end to end, its plain banner
    texture is cleared under them, and the row's name is #590E00.
  C Total override priority: a Custom theme started from Class colors, with its own Parent group glow colour and gradient, and a
    class colour of its own for "Parent group glow", still draws the Druid glow; the Reverse switch does not turn it round.
  D Nothing else changes: with the Druid glow on, the resolved palette, gradients, Reverse switch offer, the cursor trail's
    "Match the UI theme" colours and the theme's share string equal those of the same setup with the class table emptied.
  E Not Druid, or not the class base: a Demon Hunter, Class colors picked as Mage, the XUI default and a cursor trail theme draw the
    banner as before (one texture, gradStart to black, no pieces) with the usual row text colour; so does a Druid whose settings
    window has a theme of its own. Switching from the Druid glow back hides every piece.
Run: python3 tests/theme_class_glow_run.py   (Lua 5.1 via lupa)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402

DESIGN = [("FF7C0A", 0), ("FF7C0A", 6), ("E87E42", 24), ("E47F51", 40), ("CB8689", 53), ("B289B6", 66), ("6884D1", 83), ("537BE8", 100)]
EVEN = ["FF7C0A", "F47D24", "E77E46", "DF815D", "C38797", "9A87BF", "6583D5", "537BE8"]
RULE, READY = "590E00", "040A4E"


def rgb(h):
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def at(p):
    for (h0, p0), (h1, p1) in zip(DESIGN, DESIGN[1:]):
        if p0 <= p <= p1:
            t = 0 if p1 == p0 else (p - p0) / (p1 - p0)
            a, b = rgb(h0), rgb(h1)
            return "%02X%02X%02X" % tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


LUA = r'''
return function(W, L, want)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local CLASS = "DRUID"
UnitClass = function(u) if u == "player" then return "Class", CLASS, 11 end return nil end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local T = ns.Theme
local function f3(c) return c and ("%.3f,%.3f,%.3f"):format(c[1] or -1, c[2] or -1, c[3] or -1) or "nil" end
local function same(a, b) return a and b and math.abs(a[1] - b[1]) < 0.0005 and math.abs(a[2] - b[2]) < 0.0005 and math.abs(a[3] - b[3]) < 0.0005 end
local function hex(h) return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 } end

-- A the table
local D = T.CLASS_THEMES and T.CLASS_THEMES.DRUID
check("A T.CLASS_THEMES.DRUID exists", D ~= nil)
if not D then return R end
check("A the glow has 8 colours", type(D.glow) == "table" and #D.glow == 8, D.glow and #D.glow)
for i, h in ipairs(want.even) do
  local c = D.glow and D.glow[i]
  check(("A glow colour %d is #%s exactly (hex / 255)"):format(i, h), c and c[1] == hex(h)[1] and c[2] == hex(h)[2] and c[3] == hex(h)[3] and (c[4] or 1) == 1, f3(c))
end
local function exact(c, h) return c and c[1] == hex(h)[1] and c[2] == hex(h)[2] and c[3] == hex(h)[3] end
check("A the rule name on the glow is #" .. want.rule .. " exactly", exact(D.glowRule, want.rule), f3(D.glowRule))
check("A Ready on the glow is #" .. want.ready .. " exactly", exact(D.glowReady, want.ready), f3(D.glowReady))

-- the window, a nested rule selected (as tests/tree_paint_parity_run.py)
local function rule(name, enabled, folder) local r = ns.NewRule(); r.name = name; r.enabled = enabled; r.folder = folder; ns.NormalizeRule(r); r.uid = r.uid or (ns.NewUID and ns.NewUID()); return r end
ns.folders = { { id = "f1", name = "Defensives" }, { id = "f2", name = "Inner", parent = "f1" } }
local A = rule("Shell", true, "f1"); A.useBuff, A.buffID, A.buffState = true, 48707, "present"
local B = rule("Cooldown watch", true, "f2"); B.spellID = 47528; B.cdState = "ready"
ns.rules = { A, B }
CueRulesDB.rules = ns.rules
if ns.ToggleUI then pcall(ns.ToggleUI) end
W.tick(0.1, 6)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub("AceConfigDialog-3.0")
pcall(ACD.SelectGroup, ACD, "CueRules", "cooldowns", "enabledTab"); W.tick(0.2, 4)
if ns.EditRule then pcall(ns.EditRule, B); W.tick(0.2, 4) end
local function repaint() T.Changed(); W.tick(0.2, 6); if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 3) end
local function topRow()
  local found
  local function walk(f, d)
    if found or not f or d > 60 then return end
    if f.uniquevalue and f.IsShown and f:IsShown() and f.xuiBanner and f.xuiBanner:IsShown() then
      local uv = tostring(f.uniquevalue)
      if uv:match("f1$") then found = f; return end
    end
    for _, c in ipairs(f.GetChildren and { f:GetChildren() } or {}) do walk(c, d + 1) end
  end
  walk(UIParent, 0)
  return found
end
local function pieces(b)
  local st = b and b.xuiBanner and b.xuiBanner.xuiGradL
  local o = {}
  for _, s in ipairs(st and st.segs or {}) do if s:IsShown() then o[#o + 1] = s end end
  table.sort(o, function(x, y) return x:GetLeft() < y:GetLeft() end)
  return o
end
local function readGlow(b)
  local segs = pieces(b)
  if #segs == 0 then return nil, "no glow piece shown" end
  local cols = {}
  for i, s in ipairs(segs) do
    local g = s._grad
    if not (g and g[1] == "HORIZONTAL") then return nil, "piece " .. i .. " has no horizontal gradient" end
    if i == 1 then cols[1] = g[2] elseif not same(cols[#cols], g[2]) then return nil, "pieces " .. (i - 1) .. "/" .. i .. " do not meet" end
    cols[#cols + 1] = g[3]
    if i > 1 and math.abs(segs[i - 1]:GetRight() - s:GetLeft()) > 0.01 then return nil, "gap before piece " .. i end
  end
  if math.abs(segs[1]:GetLeft() - b:GetLeft()) > 0.01 or math.abs(segs[#segs]:GetRight() - b:GetRight()) > 0.01 then return nil, "pieces do not cover the row" end
  return cols
end
local function textCol(b) local r, g, bl = b.text:GetTextColor(); return { r, g, bl } end
local function expectGlow(label)
  local b = topRow()
  check(label .. ": the top parent group's row has its banner", b ~= nil)
  if not b then return end
  local cols, why = readGlow(b)
  local ok = cols and #cols == 8
  if ok then for i, h in ipairs(want.even) do if not same(cols[i], hex(h)) then ok = false; why = "colour " .. i .. " " .. f3(cols[i]) end end end
  check(label .. ": the row draws the Druid glow, 8 colours left to right in 7 pieces end to end", ok, why or (cols and #cols))
  local c = b.xuiBanner._color
  check(label .. ": the banner's own texture is cleared under the pieces", c and (c[4] or 1) == 0, f3(c))
  check(label .. ": the row's name is #" .. want.rule, same(textCol(b), hex(want.rule)), f3(textCol(b)))
end
local function expectPlain(label)
  local b = topRow()
  check(label .. ": the top parent group's row has its banner", b ~= nil)
  if not b then return end
  check(label .. ": no glow piece is shown", #pieces(b) == 0, #pieces(b))
  local g = b.xuiBanner._grad
  local gs = ns.TREE_GRAD
  check(label .. ": the banner is gradStart to black, as before", g and g[1] == "HORIZONTAL" and same(g[2], gs) and same(g[3], { 0, 0, 0 }), g and (f3(g[2]) .. " > " .. f3(g[3])))
  local tc = T.TokCol("text", "settings")
  check(label .. ": the row's name has the usual text colour", same(textCol(b), tc), f3(textCol(b)) .. " vs " .. f3(tc))
end

-- B Druid, Class colors
T.ResetAll(); repaint()
expectGlow("B Druid, Class colors")

-- C total override priority
T.SetToken("gradStart", { 0.1, 0.5, 0.1, 1 }); T.SetTokenGradient("gradStart", true)
T.SetClassColor("xui-list-parent", "bg", { 0.2, 0.2, 0.9, 1 }); T.SetGradReverse(true); repaint()
check("C (the theme is now Custom, started from Class colors)", CueRulesDB.theme.base == "custom" and T.Under() == "class")
expectGlow("C Custom from Class with its own glow colour, gradient, class colour and Reverse on")

-- D nothing else changes
local function snap()
  local s = {}
  for _, t in ipairs(T.TOKENS) do s[#s + 1] = t[1] .. "=" .. f3(T.cur[t[1]]) end
  for _, t in ipairs(T.TOKENS) do local g = T.curGrad[t[1]]; if g then local o = {}; for i, c in ipairs(g.stops) do o[i] = f3(c) end; s[#s + 1] = t[1] .. "~" .. table.concat(o, ">") end end
  s[#s + 1] = "hasGrad=" .. tostring(T.HasGradient())
  for i, c in ipairs(T.TrailStops()) do s[#s + 1] = "trail" .. i .. "=" .. f3(c) end
  s[#s + 1] = "export=" .. tostring(T.Export and T.Export())
  return table.concat(s, "\n")
end
local saved = T.CLASS_THEMES.DRUID
for _, setup in ipairs({ { "the Custom theme of C", function() end }, { "Class colors", function() T.ResetAll() end } }) do
  setup[2](); repaint()
  local with = snap()
  T.CLASS_THEMES.DRUID = nil; repaint()
  local without = snap()
  T.CLASS_THEMES.DRUID = saved; repaint()
  check("D " .. setup[1] .. ": palette, gradients, Reverse offer, trail colours and share string equal those without the class table", with == without)
end

-- E not Druid, or not the class base
T.ResetAll(); T.SetBase("class", "MAGE"); repaint()
expectPlain("E Druid with Class colors picked as Mage (after the Druid glow)")
T.ResetAll(); T.SetBase("default"); repaint()
expectPlain("E Druid, the XUI default")
T.ResetAll(); T.SetBase("cursor_fel"); repaint()
expectPlain("E Druid, a cursor trail theme")
T.ResetAll(); repaint()
if T.SetScopeTheme then
  T.SetScopeTheme("settings", "default"); repaint()
  expectPlain("E Druid, Class colors, the settings window with a theme of its own")
  T.ResetScope("settings"); repaint()
end
expectGlow("E Druid, Class colors again")
CLASS = "DEMONHUNTER"; T.ResetAll(); repaint()
expectPlain("E a Demon Hunter, Class colors")
return R
end
'''


def main():
    results = []

    def check(name, ok, detail=""):
        results.append((name + (("  [" + str(detail) + "]") if detail and not ok else ""), bool(ok)))

    resample = [at(i * 100 / 7) for i in range(8)]
    check("A the even resample of her designed stops is %s" % " ".join(EVEN), resample == EVEN, " ".join(resample))

    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    want = H.to_lua(L, {"even": EVEN, "rule": RULE, "ready": READY})
    res = L.eval("function(src, W, Ld, want) return loadstring(src)()(W, Ld, want) end")(LUA, world, loader, want)
    for i in range(1, len(res) + 1):
        results.append((res[i][1], bool(res[i][2])))
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    check("no Lua error", not errs, "; ".join(str(e) for e in errs[:3]))

    fails = 0
    for name, ok in results:
        print(("ok   " if ok else "FAIL ") + name)
        fails += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), fails))
    print("FAILS: %d" % fails)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
