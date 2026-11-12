#!/usr/bin/env python3
"""Round 5 (gate5): a Bar cue's parts are laid out in whole pixels (V27, Xaya 2026-11-10, REQUEST-LOG A23 SD-28 / SD-29, her words:
"zero floating numbers"; her answer on numbers: "Whole-pixel / no float math" -- positions and sizes stored and set in whole pixels).

The release gate (tests/gate_performance_run.py, P5) found XayaUI_Rules/BarCue.lua giving the spark a fractional height after the
settings window closed: SetSize(12, 48.4) (the spark glow is 2.2 times the bar's 22 px thickness). A fractional size is drawn
blurred on the game's pixel grid and is decimal arithmetic the player gains nothing from. A saved size or spark width with decimals
(a size typed or dragged to a fraction) reached the icon square and the bar's insets the same way.

What the player sees, checked here on the real addons in the stand-in game (tests/harness):
  1. the default bar (220 x 22, icon left, spark on): icon 22 x 22, bar starts 22 px in, spark 12 x 48 on the fill's moving edge;
  2. a vertical bar 22 x 150 (fills up from the bottom): spark 48 x 12 on the fill's top edge;
  3. a bar whose saved size and spark width carry decimals (220.6 x 22.4, spark 12.4): every size and offset the bar's parts get
     is a whole number (icon 22 x 22, bar inset 22, spark 12 x 48), and the bar still fills the display beside its icon.
Fails on the pre-change BarCue.lua (spark 12 x 48.4; icon 22.4; spark 12.4 x 49.28), passes after.
Limit (V25): the stand-in records the numbers XayaUI passes; how the game draws them is UNVERIFIED IN GAME.
Run: python3 tests/fix_r5_barcue_pixels_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

RESULTS = []


def check(name, ok, extra=""):
    RESULTS.append((name, bool(ok)))
    print(("PASS " if ok else "FAIL ") + name + (("  [" + str(extra) + "]") if (extra and not ok) else ""))


LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")

local P = ns.NewRule(); P.name = "Demon Spikes"; P.enabled = true; P.useBuff = true; P.buffID = 203819; P.buffState = "present"; ns.NormalizeRule(P)
ns.rules = { P }
local cue = ns.NewCueRule(P, "bar")
check("a Bar cue is made", cue ~= nil and cue.visual and cue.visual.kind == "bar")
if not cue then return R end
local v = cue.visual

-- every number XayaUI hands the bar's parts (icon, spark, the bar itself) while it lays them out
local seen = {}
local function watch(obj, label)
  local setSize, setPoint = obj.SetSize, obj.SetPoint
  rawset(obj, "SetSize", function(self, w, h) seen[#seen + 1] = { label .. ":SetSize", w, h }; return setSize(self, w, h) end)
  rawset(obj, "SetPoint", function(self, p, rel, rp, x, y)
    seen[#seen + 1] = { label .. ":SetPoint", type(x) == "number" and x or 0, type(y) == "number" and y or 0 }
    return setPoint(self, p, rel, rp, x, y)
  end)
end
local function whole(n) return type(n) == "number" and n == math.floor(n) end
local function allWhole()
  for _, s in ipairs(seen) do
    if not (whole(s[2]) and (s[3] == nil or whole(s[3]))) then return false, s[1] .. "(" .. tostring(s[2]) .. ", " .. tostring(s[3]) .. ")" end
  end
  return #seen > 0, #seen == 0 and "nothing laid out" or nil
end
local function layout()
  ns.RefreshVisual(cue)
  local fr = ns.DisplayFrame(cue)
  if fr and fr.barF and not fr._r5watched then
    fr._r5watched = true
    watch(fr.barF, "bar"); watch(fr.barIcon, "icon"); watch(fr.barSpark, "spark")
    ns.RefreshVisual(cue)
  end
  return fr
end

-- 1. the default bar
seen = {}
local fr = layout()
check("the display frame has a status bar", fr and fr.barF ~= nil)
if not (fr and fr.barF) then return R end
seen = {}; ns.RefreshVisual(cue)
local sp = fr.barSpark
check("default bar: the spark is 12 x 48, whole pixels (was 12 x 48.4)", sp._w == 12 and sp._h == 48, tostring(sp._w) .. " x " .. tostring(sp._h))
check("default bar: the spark sits on the fill's moving edge (right edge while draining left)",
  select(2, sp:GetPoint(1)) == fr.barF:GetStatusBarTexture() and select(3, sp:GetPoint(1)) == "RIGHT")
check("default bar: the icon square is 22 x 22 at the left", fr.barIcon:IsShown() and fr.barIcon._w == 22 and fr.barIcon._h == 22)
local p1, _, _, x1 = fr.barF:GetPoint(1)
check("default bar: the bar starts 22 px in, after the icon", p1 == "TOPLEFT" and x1 == 22, tostring(p1) .. " " .. tostring(x1))
local ok, bad = allWhole()
check("default bar: every size and offset given to the icon, spark and bar is a whole number", ok, bad)

-- 2. a vertical bar, 22 wide and 150 tall, filling up from the bottom
v.w, v.h = 22, 150
v.bar.dir = "bottom"
seen = {}; ns.RefreshVisual(cue)
check("vertical bar: the spark is 48 x 12, whole pixels (was 48.4 x 12)", sp._w == 48 and sp._h == 12, tostring(sp._w) .. " x " .. tostring(sp._h))
check("vertical bar: the spark sits on the fill's top edge", select(3, sp:GetPoint(1)) == "TOP")
ok, bad = allWhole()
check("vertical bar: every size and offset given to the icon, spark and bar is a whole number", ok, bad)

-- 3. a saved size and spark width with decimals
v.w, v.h = 220.6, 22.4
v.bar.dir = "left"
v.bar.spark.w = 12.4
seen = {}; ns.RefreshVisual(cue)
check("decimal size 220.6 x 22.4, spark 12.4: the spark is 12 x 48", sp._w == 12 and sp._h == 48, tostring(sp._w) .. " x " .. tostring(sp._h))
check("decimal size: the icon square is 22 x 22", fr.barIcon._w == 22 and fr.barIcon._h == 22, tostring(fr.barIcon._w) .. " x " .. tostring(fr.barIcon._h))
p1, _, _, x1 = fr.barF:GetPoint(1)
local p2, rel2, _, x2, y2 = fr.barF:GetPoint(2)
check("decimal size: the bar starts 22 px in and reaches the display's right edge",
  p1 == "TOPLEFT" and x1 == 22 and p2 == "BOTTOMRIGHT" and rel2 == fr and x2 == 0 and y2 == 0, tostring(x1) .. " / " .. tostring(x2))
ok, bad = allWhole()
check("decimal size: every size and offset given to the icon, spark and bar is a whole number", ok, bad)
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    for i in range(1, len(res) + 1):
        check(res[i][1], res[i][2])
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    check("no Lua errors in the stand-in game", not errs, len(errs))
    bad = sum(1 for _, ok in RESULTS if not ok)
    print("%d checks, %d failed" % (len(RESULTS), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
