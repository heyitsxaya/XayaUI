# Stub test for the Stat Calculator (QoL until Bonus 0.6.37; XayaUI_QoL 0.7.0): StatMath.lua (thresholds, lost rating, rating per 1%, next 1%, what-if,
# item stat deltas, coins) and the phase-1 checks of the model (StatModel.lua) and panel (XayaUI_Bonus/StatCalculator.lua), kept through the
# 0.7.0 rebuild (V9). The phase-2 checks (sections, value toggle, hover, sheet, What If, overlays, secrets, settings) are in
# tests/char_statcalc2_run.py. Stand-in game world: tests/char_world.lua.
# (Bonus 0.6.45, main: ported from qa-installer-branch; the old tab-nil model's checks, the character window's stat tooltip lines
# (Enhanced Tooltips) and SM.Coins are left out: none of them is on main.)
# Run from the repo root: python3 tests/char_statcalc_run.py   Needs: pip install lupa.
# The converter below is a TEST STAND-IN with a made-up bracket shape (rate 1/46 per point, penalties from 30%); it is not game data
# and nothing from it ships. What it checks is that the scan FINDS whatever brackets the converter has, and finds none when there are none.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
fails, n = 0, 0
function check(name, cond, extra) n = n + 1; if not cond then fails = fails + 1; print("FAIL: " .. name .. (extra ~= nil and ("  -> " .. tostring(extra)) or "")) else print("ok:   " .. name) end end
ns = {}
assert(loadfile(__SM__))("XayaUI_Bonus", ns)
local SM = ns.StatMath

-- stand-in converters ---------------------------------------------------------------------------------------------------
local RATE = 1 / 46
local BR = { { 30, 0.1 }, { 39, 0.2 }, { 47, 0.3 }, { 54, 0.4 }, { 66, 0.5 }, { 126, 1.0 } }  -- (linear % where a bracket starts, penalty)
local function dr(x)
  local lin = x * RATE
  local out, prevEdge, prevPen = 0, 0, 0
  for _, b in ipairs(BR) do
    if lin <= b[1] then return out + (lin - prevEdge) * (1 - prevPen) end
    out = out + (b[1] - prevEdge) * (1 - prevPen); prevEdge, prevPen = b[1], b[2]
  end
  return out + (lin - prevEdge) * (1 - prevPen)
end
local function rounded(x) return math.floor(dr(x) * 100 + 0.5) / 100 end
local function linear(x) return x * RATE end

-- 1. no brackets
local r0 = SM.BaseRate(linear)
check("base rate read from a small rating", math.abs(r0 - RATE) < 1e-12, r0)
local th = SM.Thresholds(linear, r0, 200)
check("a straight converter has no thresholds", #th == 0, #th)
local a = SM.Analyze(linear, 528, r0, th, 1, linear(528))
check("lost rating 0 below any threshold", a.lost == 0, a.lost)
check("rating per 1% = 46", math.abs(a.perPctBase - 46) < 1e-9 and math.abs(a.perPctNow - 46) < 1e-9, a.perPctNow)
check("next 1% = 46 rating", a.nextOne == 46, a.nextOne)
check("penalty 0", a.penalty == 0, a.penalty)

-- 2. brackets, exact converter
r0 = SM.BaseRate(dr)
th = SM.Thresholds(dr, r0, 200)
check("six thresholds found", #th == 6, #th)
check("first threshold at 1380 rating (30%)", th[1] and th[1].rating == 1380 and math.abs(th[1].pct - 30) < 1e-9, th[1] and th[1].rating)
check("first penalty 10%", th[1] and math.abs(th[1].penalty - 0.1) < 1e-9, th[1] and th[1].penalty)
check("second threshold at 1794 (39% linear)", th[2] and th[2].rating == 1794, th[2] and th[2].rating)
check("last bracket penalty 100% (no further gain)", th[6] and th[6].penalty == 1, th[6] and th[6].penalty)
a = SM.Analyze(dr, 528, r0, th, 1, dr(528))
check("528 crit: next threshold 1380, 852 away", a.nextThreshold == th[1] and a.toNext == 852, a.toNext)
a = SM.Analyze(dr, 1600, r0, th, 1, dr(1600))
check("1600 rating: penalty 10%", math.abs(a.penalty - 0.1) < 1e-9, a.penalty)
check("1600 rating: lost = 22 (220 points past the threshold x 10%)", math.abs(a.lost - 22) < 1e-6, a.lost)
check("1600 rating: per 1% now = 46 / 0.9", math.abs(a.perPctNow - 46 / 0.9) < 1e-6, a.perPctNow)
a = SM.Analyze(dr, 1370, r0, th, 1, dr(1370))
check("next 1% across the threshold: 10 points at full rate + 0.7826% at 90% (40 points) = 50", a.nextOne == 50, a.nextOne)
a = SM.Analyze(dr, 997, r0, th, 2.8, dr(997))
check("mastery factor 2.8: 16.43 rating per 1% mastery", math.abs(a.perPctBase - 46 / 2.8) < 1e-9, a.perPctBase)
check("mastery factor: next 1% mastery = 17 rating", a.nextOne == 17, a.nextOne)
a = SM.Analyze(dr, 10000, r0, th, 1, dr(10000))
check("past the last bracket: next 1% is capped (nil)", a.nextOne == nil, a.nextOne)
a = SM.Analyze(dr, 528, r0, th, 1, dr(528) + 3)
check("converter disagreeing with the game's value is flagged", a.mismatch == true)

-- 3. brackets, converter that rounds to 0.01%
local thr = SM.Thresholds(rounded, SM.BaseRate(rounded), 200)
check("rounded converter: still six thresholds", #thr == 6, #thr)
check("rounded converter: first threshold within 6 rating of 1380", thr[1] and math.abs(thr[1].rating - 1380) <= 6, thr[1] and thr[1].rating)
for i, t in ipairs(thr) do print("      rounded threshold " .. i .. ": " .. t.rating .. " rating, penalty " .. t.penalty) end
check("rounded converter: penalties are whole percents", thr[3] and math.abs(thr[3].penalty - 0.3) < 1e-9, thr[3] and thr[3].penalty)

-- 4. Solve
local x = SM.Solve(function(v) return v / (v + 10000) * 100 end, 40, 0, 1e6, true)
check("Solve inverts armor-like curves", x and math.abs(x - 6666.67) < 0.1, x)
check("Solve: unreachable target is nil", SM.Solve(function(v) return v / (v + 10000) * 100 end, 120, 0, 1e6, true) == nil)

-- 5. What if, item stat deltas, coins (0.7.0)
local w = SM.WhatIf(dr, 528, 852, 1, th)
check("WhatIf +852 from 528: exactly to the 30% threshold (+18.52%)", w and math.abs(w.gain - (30 - 528 / 46)) < 1e-9 and w.newRating == 1380, w and w.gain)
check("WhatIf +852 lands on the threshold, so it counts as crossed", w and #w.crossed == 1 and w.crossed[1].rating == 1380, w and #w.crossed)
w = SM.WhatIf(dr, 528, 1000, 1, th)
check("WhatIf +1000: the 148 points past 1380 count 90% (thresholds apply)", w and math.abs(w.gain - ((30 - 528 / 46) + 148 / 46 * 0.9)) < 1e-9, w and w.gain)
w = SM.WhatIf(dr, 528, -1000, 1, th)
check("WhatIf -1000 stops at 0 rating (-11.48%)", w and w.newRating == 0 and math.abs(w.gain + 528 / 46) < 1e-9, w and w.newRating)
w = SM.WhatIf(dr, 997, 100, 2.8, th)
check("WhatIf with the mastery factor: +100 = +6.09% mastery", w and math.abs(w.gain - 100 / 46 * 2.8) < 1e-9, w and w.gain)
check("WhatIf: a converter that gives nothing -> nil", SM.WhatIf(function() return nil end, 10, 10) == nil)
local d = SM.StatDelta({ A = 400, B = 100, C = "x" }, { A = 300, D = 200, B = 100 })
check("StatDelta: new - old per key, keys only in old go negative, equal and non-numbers left out", d.A == 100 and d.D == -200 and d.B == nil and d.C == nil)
-- (Bonus 0.6.45, main: SM.Coins, the repair cost's split, is left out of StatMath.lua: nothing reads it since QoL 0.7.23)
''' .replace("__SM__", P("XayaUI_Bonus/StatMath.lua")))


# --- The phase-1 checks of the model and panel, on the 0.7.0 model (StatModel.lua) --------------------------------------------
# Each check keeps the number or outcome the 0.6.2 test asserted; the wording moved from one-line strings to label / value pairs.
lua.execute(r'''
SM_n, SM_fails = n, fails
assert(loadfile(__WORLD__))()
n, fails = SM_n, SM_fails
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_Bonus", ns)
assert(loadfile(__CM__))("XayaUI_Bonus", ns)
assert(loadfile(__CT__))("XayaUI_Bonus", ns)
-- (V25 R4) the extra lines on the character window's stat tooltips are XayaUI Bonus Features' Enhanced Tooltips' (Tooltips.lua section 5)
XayaUI_NS = ns
ns.FireReady(); ns.SettingsOpenAllForTests()   -- (P5) the module addons load after XayaUI: their settings stores open (Modules.lua section 0c)

local c = CWC()
check("off by default", c.enabled == false)
check("defaults filled", c.panel == true and c.side == "right" and type(c.spells) == "table")

-- (Bonus 0.6.45, main) the checks of the old tab-nil model (its crit, mastery, stamina, parry, armor, attack power, dodge, GCD, attack
-- speed, leech, haste rows and the Character section) are left out of the main port: that model was built only for Improved Character
-- Display's tooltips, which are not on main, and StatModel.lua on main does not build it (boundary map section 2b). The same numbers on
-- the Stat Calculator's own Stats tab are checked in tests/char_stat_map_run.py, char_stat_round_run.py and char_stat_window_run.py.
check("main: the old tab-nil model builds nothing", #(ns.StatCalc_Model()) == 0)
local gm = ns.StatCalc_Model("gear")
local gs = row(ns.StatCalc_Model("stats"), "gearSum")   -- (QoL 0.7.23: the Summary is on the Stats tab)
-- QoL 0.7.14: no per-slot list; a clicked slot shows its item level, ratings, sockets and durability in the comparison
check("gear: no per-slot list any more (the comparison shows a clicked slot)", row(gm, "slot1") == nil)
ns.StatModel.gearSlot = 1
gm = ns.StatCalc_Model("gear")
local function cell(key, i) local r = row(gm, key); return r and r.cells and r.cells[i] end
check("gear: a clicked slot's item level and ratings (Head: 336, crit 300, haste 200)", cell("gc_ilvl", 1) == "336" and cell("gc_crit", 1) == "300" and cell("gc_haste", 1) == "200",
  tostring(cell("gc_ilvl", 1)) .. " " .. tostring(cell("gc_crit", 1)))
check("[0.7.23] gear: no durability or repair row in the comparison (Xaya: \"durability and repair can be removed from all stat calculator panes\")",
  row(gm, "gc_dur") == nil and row(gm, "gc_repair") == nil, cell("gc_dur", 1))
ns.StatModel.gearSlot = 11
gm = ns.StatCalc_Model("gear")
check("gear: its empty socket (Ring: 1)", cell("gc_sockets", 1) == "1", cell("gc_sockets", 1))
ns.StatModel.gearSlot = nil
gm = ns.StatCalc_Model("stats")
-- (QoL 0.7.15: the Summary is a table, Gear | Character | Elsewhere, one row per stat; QoL 0.7.23: on the Stats tab)
check("gear totals: a column head Gear | Character | Elsewhere", gs and gs.kind == "colhead" and table.concat(gs.cols or {}, "|") == "Gear|Character|Elsewhere")
local function sumCells(k) local r = row(gm, "gearSum_" .. k); return r and table.concat(r.cells, "|") end
check("gear totals vs character: Critical Strike gear 400 | character 528 | +128 elsewhere", sumCells("crit") == "400|528|+128" and row(gm, "gearSum_crit").label == "Critical Strike", sumCells("crit"))
check("gear totals: sockets", sumCells("sockets") == "1||" and row(gm, "gearSum_sockets").cellTones[1] == "warn", sumCells("sockets"))

-- spell math
local nums = ns.StatCalc_Numbers("Rapidly slash your target for 6,944 Physical damage, and shatter 2 Lesser Soul Fragments. 15% more.")
check("numbers: thousands separator read, percentages skipped", nums[1] == 6944 and nums[2] == 2 and #nums == 2, table.concat(nums, ","))
check("resolve: spell link", ns.StatCalc_ResolveSpell("|cff71d5ff|Hspell:263642:0|h[Fracture]|h|r") == 263642)
check("resolve: name", ns.StatCalc_ResolveSpell("Fracture") == 263642)
check("resolve: id", ns.StatCalc_ResolveSpell(" 263642 ") == 263642)
c.advanced = true
c.spells = { { id = 263642, base = "ap", coeff = 200 } }
local fr = row(ns.StatCalc_Model("spells"), "spell263642")
check("spell math: Fracture row, its spell ID with the name (#380; QoL 0.7.24: on the line under it)", fr ~= nil and fr.label == "Fracture" and fr.row.idText == "Spell ID: 263642" and fr.value == "", fr and fr.label)
check("spell math: 6,944 = 200.0% of attack power, 1 Agility = 2.00 (QoL 0.7.24: her words \"1 agility = {value}\")", pair(fr, "6,944") == "200.0% of attack power; 1 Agility = 2.00", pair(fr, "6,944"))
check("spell math: entered coefficient matches, no warning", pair(fr, "Entered") == "200.0% of attack power; measured 200.0%")
c.spells[1].coeff = 150
fr = row(ns.StatCalc_Model("spells"), "spell263642")
check("spell math: a different entered coefficient is flagged", (pair(fr, "Entered") or ""):find("differs", 1, true) ~= nil)

-- turning on: events registered, panel docks when the character window opens (the character window's stat tooltip lines are Enhanced
-- Tooltips', not on main: their checks are left out of the main port)
CharacterFrame = mk("Frame"); PaperDollFrame = mk("Frame")
local statRow = mk("Frame"); statRow.Label = mk("FS"); statRow.Label.text = "Critical Strike:"
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = { statRow }
c.enabled = true
CWA()
CharacterFrame.shown = true; PaperDollFrame:Show()
check("panel shown docked with the character window", XayaUIStatCalculator and XayaUIStatCalculator:IsShown())
check("main: the character window's stat rows are not hooked (no Enhanced Tooltips)", statRow.hooks == nil or statRow.hooks.OnEnter == nil)
PaperDollFrame:Hide()
check("panel hides with the character window", not XayaUIStatCalculator:IsShown())
for _, t in ipairs({ "sheet", "stats", "defense", "offense", "gear", "whatif", "spells" }) do
  c.tab = t
  local ok, err = pcall(ns.StatCalc_Render)
  check("panel renders the " .. t .. " tab", ok, err)
end
c.tab = "sheet"
c.enabled = false; CWA()
check("off: panel hidden", not XayaUIStatCalculator:IsShown())

-- settings page and command
local page = CWPage(function() end)
check("settings page builds: feature node Stat Calculator with Panel and Spell Math under it (main: nothing of Improved Character Display)",
  page.childGroups == "tree" and page.name == "Stat Calculator" and page.args.panelPart and page.args.spells and page.args.enchantSlotsPage == nil
  and page.args.overlayPart == nil and page.args.ilvl == nil and page.args.enchants == nil)
page.args.spells.args.add.set(nil, "Fracture")
check("add spell via settings (duplicate ignored)", #c.spells == 1)
check("/xui stats status runs", ns.RunCommand("stats", "status") and printed[#printed]:find("Stat Calculator:", 1, true) ~= nil)
check("/xui stats while off says so", ns.RunCommand("stats", "") and printed[#printed]:find("is off", 1, true) ~= nil)
CharacterFrame.shown = false
ns.RunCommand("stats", "on")
check("/xui stats on turns it on", c.enabled == true)
ns.RunCommand("stats", "")
check("/xui stats shows the panel on its own", XayaUIStatCalculator:IsShown())
check("an old saved tab name (0.6.2 'ratings') maps to Stats", (function() c.tab = "ratings"; return CWC().tab == "stats" end)())
print(("%d checks, %d failed"):format(n, fails))
'''.replace("__WORLD__", P("tests/char_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__SM__", P("XayaUI_Bonus/StatMath.lua"))
   .replace("__CM__", P("XayaUI_Bonus/StatModel.lua")).replace("__CT__", P("XayaUI_Bonus/StatCalculator.lua")))
sys.exit(1 if lua.eval("fails") else 0)
