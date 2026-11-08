#!/usr/bin/env python3
"""In-game QA walkthrough for the Stat Calculator's change numbers, stat-name colours and hover notes (XayaUI_DevAssist 0.7.72,
XayaUI_DevAssist/QAWalks-stat-colors.lua; XayaUI QoL 0.7.54, XayaUI Bonus Features 0.6.38; QA B306-B311; REQUEST-LOG session
014bN6tUDLJ6T742DewZDg1s #5, #6, #8, #15). Xaya's rule V22 (2026-11-07): "make sure every feature or significant change to the codebase
/ bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game, with stand-in stat readings (500 crit rating, 600 haste rating,
the converter rating / 40: TEST STAND-INS), and runs each step as a player would (Do it for me, then the check):
  - registered with pre-fill for B306-B311; the last step is a Done step;
  - before Do it for me: step 1 says "not tested" (nil), never Pass;
  - step 1 (more crit): Pass, the drawn colour is the game's green (the stand-in game's GREEN_FONT_COLOR); negative: the new value
    repainted in the theme's accent gives Fail;
  - step 2 (less crit): Pass, the game's red; step 3 (more haste): Pass, the GCD's shorter new value is green;
  - step 4 with the class theme: no verdict, says to pick a color-blind theme; with the colorblind / protan base: Pass (blue / orange);
  - step 5 (the Critical Strike hover): Pass, the title in Critical Strike's colour; negative: the title repainted gives Fail;
  - step 6 (notes, Dev Assist on): Pass, every note line is in the hover;
  - Done: the typed numbers are cleared and the panel is put back (closed).
Negative control: on 930a0c7 the walkthrough does not exist (the registration check fails).
Run: python3 tests/qa_walks_stat_colors_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function has(s, p) return type(s) == "string" and s:find(p, 1, true) ~= nil end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
local ns = rawget(_G, "XayaUI_NS")
local QA = rawget(_G, "XayaUI_DevQA")
local def = QA and QA.walks["stat-colors"]
check("the stat colours walkthrough is registered with pre-fill, for B306-B311", def ~= nil and def.prefill == true and def.qa == "B306, B307, B308, B309, B310, B311")
if not def then return R end
check("its last step is a Done step", def.steps[#def.steps].done == true)
ns.Print = function() end
-- stand-in stat readings (the stand-in game answers 0 for every rating)
RAT = { [9] = 500, [10] = 500, [11] = 500, [18] = 600, [19] = 600, [20] = 600 }
GetCombatRating = function(i) return RAT[i] or 0 end
GetCombatRatingBonus = function(i) return (RAT[i] or 0) / 40 end
GetCombatRatingBonusForCombatRatingValue = function(i, v) return v / 40 end
GetCritChance = function() return 17.5 end
GetRangedCritChance = function() return 17.5 end
GetSpellCritChance = function() return 17.5 end
GetHaste = function() return 15 end
GetMeleeHaste = function() return 15 end
UnitSpellHaste = function() return 15 end
UnitAttackSpeed = function() return 2.6, nil end
UnitDamage = function() return 100, 200, nil, nil, 0, 0, 1 end
-- the game's tooltip keeps its lines in font strings GameTooltipTextLeftN / RightN; the stand-in tooltip keeps text only, so these
-- stand-ins record each line's text and colour as the game's tooltip shows them
local TL = {}
local function line(i, side)
  local key = side .. i
  if not TL[key] then
    local fs = { t = nil, c = { 1, 1, 1 }, shown = false }
    function fs:GetText() return self.t end
    function fs:GetTextColor() return self.c[1], self.c[2], self.c[3], 1 end
    function fs:SetTextColor(r, g, b) self.c = { r, g, b } end
    function fs:IsShown() return self.shown end
    TL[key] = fs; rawset(_G, "GameTooltipText" .. key, fs)
  end
  return TL[key]
end
local n = 0
local baseOwner, baseShow = GameTooltip.SetOwner, GameTooltip.Show
GameTooltip.SetOwner = function(self, ...) n = 0; for _, fs in pairs(TL) do fs.shown, fs.t = false, nil end; return baseOwner(self, ...) end
GameTooltip.AddLine = function(self, a, r, g, b) n = n + 1; local l = line(n, "Left"); l.t, l.c, l.shown = a, { r or 1, g or 1, b or 1 }, true end
GameTooltip.AddDoubleLine = function(self, a, bb, lr, lg, lb, rr, rg, rbb)
  n = n + 1
  local l, rt = line(n, "Left"), line(n, "Right")
  l.t, l.c, l.shown = a, { lr or 1, lg or 1, lb or 1 }, true
  rt.t, rt.c, rt.shown = bb, { rr or 1, rg or 1, rbb or 1 }, true
end
GameTooltip.NumLines = function() return n end
local sc = ns.Service("statCalc")
sc.Cfg().enabled = true; if ns.CharToolkit_Apply then ns.CharToolkit_Apply() end
local ok0 = def.steps[1].check()
check("step 1 before Do it for me: not tested (no verdict)", ok0 == nil, tostring(ok0))
local function run(i) local st = def.steps[i]; if st.setup then st.setup() end; W.tick(0.1, 3); return st.check() end
local ok1, n1 = run(1)
local G = { GREEN_FONT_COLOR:GetRGB() }
check("step 1 (100 more crit): Pass, drawn in the game's green, the note says so", ok1 == true and has(n1, "meaning better") and has(n1, ("%.2f,%.2f,%.2f"):format(G[1], G[2], G[3])), n1)
-- negative: the new value repainted in the theme's accent (the old colour)
local d = sc.Drawn()
local it = d.model.byKey.map_crit
local fsC
for _, f in ipairs(d.fonts) do if f:IsShown() and f:GetText() == it.newValue then fsC = f end end
local acc = ns.Theme and ns.Theme.cur and ns.Theme.cur.accent or { 0.75, 0.25, 1 }
if fsC then fsC:SetTextColor(acc[1], acc[2], acc[3], 1) end
local okN = def.steps[1].check()
check("step 1 negative: the new value in the theme's accent gives Fail", fsC ~= nil and okN == false, tostring(okN))
local ok2, n2 = run(2)
check("step 2 (100 less crit): Pass, the game's red", ok2 == true and has(n2, "meaning worse"), n2)
local ok3, n3 = run(3)
check("step 3 (300 more haste): Pass, the GCD's new value is shorter and green", ok3 == true and has(n3, "GCD: new value -"), n3)
local ok4, n4 = run(4)
check("step 4 with the class theme: no verdict, says to pick a color-blind theme", ok4 == nil and has(n4, "pick a color-blind theme"), n4)
local T = ns.Theme
local real = T.EffBase
for _, base in ipairs({ "colorblind", "protan" }) do
  T.EffBase = function() return base end
  if ns.CharToolkit_Render then ns.CharToolkit_Render() end
  local ok4b, n4b = def.steps[4].check()
  local cb = T.BUILTIN.colorblind.pal
  check(("step 4 with the %s base theme: Pass, crit blue (%.2f,%.2f,%.2f), haste orange"):format(base, cb.accent[1], cb.accent[2], cb.accent[3]),
    ok4b == true and has(n4b, ("%.2f,%.2f,%.2f"):format(cb.accent[1], cb.accent[2], cb.accent[3])) and has(n4b, ("%.2f,%.2f,%.2f"):format(cb.danger[1], cb.danger[2], cb.danger[3])), n4b)
end
T.EffBase = real
local ok5, n5 = run(5)
check("step 5 (the Critical Strike hover): Pass, the title in Critical Strike's colour", ok5 == true and has(n5, "title 'Critical Strike'"), n5)
local l1 = rawget(_G, "GameTooltipTextLeft1")
if l1 then l1:SetTextColor(1, 0.82, 0) end
local ok5n = def.steps[5].check()
check("step 5 negative: the title in the theme's label colour gives Fail", ok5n == false, tostring(ok5n))
def.steps[5].setup()
local ok6, n6 = def.steps[6].check()
check("step 6 (notes, Dev Assist on): Pass, every note line in the hover", ok6 == true and has(n6, "XayaUI Dev Assist loaded: true"), n6)
def.steps[#def.steps].setup(); W.tick(0.1, 3)
local c = sc.Cfg()
check("Done: the typed numbers are cleared and the panel is put back (closed)", c.whatIfStats.crit == nil and c.whatIfStats.haste == nil and not sc.Shown(),
  tostring(c.whatIfStats.crit) .. " " .. tostring(sc.Shown()))
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + str(name)[:900])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    return 1 if bad or errs else 0


if __name__ == "__main__":
    sys.exit(main())
