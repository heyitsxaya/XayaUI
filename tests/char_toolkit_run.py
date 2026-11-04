# Stub test for QoL > Character Toolkit (XayaUI_QoL 0.7.0): StatMath.lua (thresholds, lost rating, rating per 1%, next 1%, what-if,
# item stat deltas, coins) and the phase-1 checks of the model (CharacterModel.lua) and panel (CharacterToolkit.lua), kept through the
# 0.7.0 rebuild (V9). The phase-2 checks (sections, value toggle, hover, sheet, What If, overlays, secrets, settings) are in
# tests/char_toolkit2_run.py. Stand-in game world: tests/char_toolkit_world.lua.
# Run from the repo root: python3 tests/char_toolkit_run.py   Needs: pip install lupa.
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
assert(loadfile(__SM__))("XayaUI_QoL", ns)
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
local g, sv, cp = SM.Coins(1234567)
check("Coins: 1,234,567 copper = 123g 45s 67c", g == 123 and sv == 45 and cp == 67, tostring(g) .. " " .. tostring(sv) .. " " .. tostring(cp))
check("Coins: negative or not a number -> nil", SM.Coins(-1) == nil and SM.Coins("5") == nil)
''' .replace("__SM__", P("XayaUI_QoL/StatMath.lua")))


# --- The phase-1 checks of the model and panel, on the 0.7.0 model (CharacterModel.lua) --------------------------------------------
# Each check keeps the number or outcome the 0.6.2 test asserted; the wording moved from one-line strings to label / value pairs.
lua.execute(r'''
SM_n, SM_fails = n, fails
assert(loadfile(__WORLD__))()
n, fails = SM_n, SM_fails
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
ns.FireReady()

local c = ns.CharToolkit_Cfg()
check("off by default", c.enabled == false)
check("defaults filled", c.panel == true and c.side == "right" and c.tooltips == true and type(c.spells) == "table" and c.overlays == false)

local m = ns.CharToolkit_Model()
local crit = row(m, "crit")
check("crit: total 22.48%", crit and crit.value == "22.48%", crit and crit.value)
check("crit: true rating 528, +11.48% from rating, lost 0, penalty 0%", pair(crit, "Rating") == "528" and pair(crit, "From rating") == "+11.48%"
  and pair(crit, "Lost to diminishing returns") == "0" and pair(crit, "Penalty on the next point") == "0%")
check("crit: 46.0 per 1%, next 1% costs 46", pair(crit, "Rating per 1%") == "46.0" and pair(crit, "Next 1% costs") == "46 rating", pair(crit, "Rating per 1%"))
check("crit: next threshold 1,380 (30.00%), 852 away", pair(crit, "Next threshold") == "1,380 (30.00%), 852 away", pair(crit, "Next threshold"))
local mas = row(m, "mastery")
check("mastery: 16.4 rating per 1% mastery", pair(mas, "Rating per 1%") == "16.4 mastery", pair(mas, "Rating per 1%"))
check("mastery: mastery factor on the hover", tipHas(mas, "2.800"))
local sta = row(m, "stamina")
check("stamina: 1 Stamina = 21.20 health", pair(sta, "Health per point") == "21.20", pair(sta, "Health per point"))
check("stamina: Stamina for +1% max health", (pair(sta, "For +1% max health") or ""):find("14,765 health", 1, true) ~= nil, pair(sta, "For +1% max health"))
local parry = row(m, "parry")
check("parry from crit: 528 crit rating = 10.15% parry, before diminishing returns", pair(parry, "From crit rating") == "528 rating = 10.15% (before DR)", pair(parry, "From crit rating"))
check("parry from crit: 52.0 crit rating per 1%", pair(parry, "Crit rating per 1%") == "52.0", pair(parry, "Crit rating per 1%"))
local armor = row(m, "armor")
check("armor: reduction and armor for next 1%", pair(armor, "Damage reduction") ~= nil and pair(armor, "Armor for the next 1%") ~= nil)
check("armor: primary -> armor marked not given", pair(armor, "Agility -> armor") == "not given by the game")
local ap = row(m, "ap")
check("attack power: 1 Agility = 1.00 attack power", pair(ap, "1 Agility =") == "1.00 attack power", pair(ap, "1 Agility ="))
check("dodge: primary -> dodge per point marked not given", pair(row(m, "dodge"), "Agility -> dodge per point") == "not given by the game")
check("gcd: unavailable before one is seen", row(m, "gcd").value == "unavailable", row(m, "gcd").value)
ns.CharToolkit_ReadGCD()
local g = row(ns.CharToolkit_Model(), "gcd")
check("gcd: read from the game's global cooldown", g.value == "1.16 s", g.value)
check("gcd: unhasted estimate 1.50 s", pair(g, "Unhasted (estimate)") == "1.50 s", pair(g, "Unhasted (estimate)"))
check("gcd: haste rating for -0.01 s", (pair(g, "For -0.01 s") or ""):find("haste = ", 1, true) ~= nil, pair(g, "For -0.01 s"))
local spd = row(m, "speed")
check("attack speed: unhasted estimate and haste for -0.01 s", pair(spd, "Unhasted (estimate)") == "2.58 s" and pair(spd, "Haste rating for -0.01 s") ~= nil)

local leech = row(m, "leech")
check("leech: all 13.61% from other sources (rating 0)", pair(leech, "Other sources") == "+13.61%", pair(leech, "Other sources"))
local haste = row(m, "haste")
check("haste: other sources multiplied in, labelled (1.2925 / (1 + 1200/46/100) - 1)",
  pair(haste, "Other sources") == ("+%.2f%% (estimate)"):format((1.2925 / (1 + 1200 / 46 / 100) - 1) * 100), pair(haste, "Other sources"))
check("mastery: other sources = spec base (88.69 - 997/46*2.8)", pair(mas, "Other sources") == ("+%.2f%%"):format(88.69 - 997 / 46 * 2.8), pair(mas, "Other sources"))
check("character section: spec, Agility, item level, movement, mastery text",
  row(m, "spec") and row(m, "stat2") and pair(row(m, "ilvl"), "Equipped") == "334.25" and pair(row(m, "move"), "Swim") == "70%"
  and pair(row(m, "move"), "Flight") == "300%" and row(m, "masteryText") and row(m, "masteryText").value:find("101.8%", 1, true))
check("items carry their tab", row(m, "crit").tab == "stats" and row(m, "armor").tab == "defense" and row(m, "ap").tab == "offense")
check("gear is not built unless its tab is asked for", row(m, "gearSum") == nil)
c.whatIf = 852
local wcrit = row(ns.CharToolkit_Model("stats"), "crit")
check("what if +852 crit: +18.52% (exactly to the 30% threshold)", pair(wcrit, "What if +852 rating") == "+18.52% (total 41.00%)", pair(wcrit, "What if +852 rating"))
c.whatIf = 0
local gm = ns.CharToolkit_Model("gear")
local gs = row(gm, "gearSum")
check("gear: per-slot rows with item level and ratings", pair(row(gm, "slot1"), "Ratings") == "crit 300, haste 200" and row(gm, "slot1").value == "336")
check("gear: durability under 100% shown", pair(row(gm, "slot1"), "Durability") == "78%")
check("gear: empty socket flagged", pair(row(gm, "slot11"), "Empty sockets") == "1")
check("gear totals vs character: crit gear 400, character 528, +128 elsewhere", pair(gs, "crit") == "gear 400, character 528 (+128 from elsewhere)", pair(gs, "crit"))
check("gear totals: sockets", pair(gs, "Empty sockets") == "1")

-- no converter: current figures only, said plainly
local saved = GetCombatRatingBonusForCombatRatingValue
GetCombatRatingBonusForCombatRatingValue = nil
crit = row(ns.CharToolkit_Model(), "crit")
check("no converter: average per 1% and a note", (pair(crit, "Rating per 1%") or ""):find("(average)", 1, true) and tipHas(crit, "not available"))
GetCombatRatingBonusForCombatRatingValue = saved

-- spell math
local nums = ns.CharToolkit_Numbers("Rapidly slash your target for 6,944 Physical damage, and shatter 2 Lesser Soul Fragments. 15% more.")
check("numbers: thousands separator read, percentages skipped", nums[1] == 6944 and nums[2] == 2 and #nums == 2, table.concat(nums, ","))
check("resolve: spell link", ns.CharToolkit_ResolveSpell("|cff71d5ff|Hspell:263642:0|h[Fracture]|h|r") == 263642)
check("resolve: name", ns.CharToolkit_ResolveSpell("Fracture") == 263642)
check("resolve: id", ns.CharToolkit_ResolveSpell(" 263642 ") == 263642)
c.advanced = true
c.spells = { { id = 263642, base = "ap", coeff = 200 } }
local fr = row(ns.CharToolkit_Model("spells"), "spell263642")
check("spell math: Fracture row", fr ~= nil and fr.label == "Fracture")
check("spell math: 6,944 = 200.0% of attack power, 1 Agility = +2.00", pair(fr, "6,944") == "200.0% of attack power; 1 Agility = +2.00", pair(fr, "6,944"))
check("spell math: entered coefficient matches, no warning", pair(fr, "Entered") == "200.0% of attack power; measured 200.0%")
c.spells[1].coeff = 150
fr = row(ns.CharToolkit_Model("spells"), "spell263642")
check("spell math: a different entered coefficient is flagged", (pair(fr, "Entered") or ""):find("differs", 1, true) ~= nil)

-- tooltip label matching
check("label: 'Critical Strike:' -> crit", ns.CharToolkit_KeyForLabel("Critical Strike:") == "crit")
check("label: colored 'Mastery:' -> mastery", ns.CharToolkit_KeyForLabel("|cffffffffMastery:|r") == "mastery")
check("label: 'Global Cooldown:' -> gcd", ns.CharToolkit_KeyForLabel("Global Cooldown:") == "gcd")
check("label: 'Agility:' -> the Agility line", ns.CharToolkit_KeyForLabel("Agility:") == "stat2")
check("label: unknown -> nil", ns.CharToolkit_KeyForLabel("Durability:") == nil)

-- turning on: events registered, panel docks when the character window opens, tooltip lines appended
CharacterFrame = mk("Frame"); PaperDollFrame = mk("Frame")
local statRow = mk("Frame"); statRow.Label = mk("FS"); statRow.Label.text = "Critical Strike:"
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = { statRow }
c.enabled = true
ns.CharToolkit_Apply()
CharacterFrame.shown = true; PaperDollFrame:Show()
check("panel shown docked with the character window", XayaUICharacterToolkit and XayaUICharacterToolkit:IsShown())
check("stat row hooked", statRow.hooks.OnEnter and #statRow.hooks.OnEnter == 1)
GameTooltip:SetOwner(statRow)
statRow.hooks.OnEnter[1](statRow)
local found = false
for _, l in ipairs(GameTooltip.lines or {}) do if tostring(l):find("Lost to diminishing returns: 0", 1, true) then found = true end end
check("tooltip: toolkit lines added to the crit tooltip", found)
PaperDollFrame:Hide()
check("panel hides with the character window", not XayaUICharacterToolkit:IsShown())
for _, t in ipairs({ "sheet", "stats", "defense", "offense", "gear", "whatif", "spells" }) do
  c.tab = t
  local ok, err = pcall(ns.CharToolkit_Render)
  check("panel renders the " .. t .. " tab", ok, err)
end
c.tab = "sheet"
c.enabled = false; ns.CharToolkit_Apply()
check("off: panel hidden", not XayaUICharacterToolkit:IsShown())

-- settings page and command
local page = ns.BuildCharToolkitPage(function() end)
check("settings page builds: feature node with Panel, Slot Overlays and Spell Math under it", page.childGroups == "tree" and page.args.panelPart
  and page.args.overlayPart and page.args.spells)
page.args.spells.args.add.set(nil, "Fracture")
check("add spell via settings (duplicate ignored)", #c.spells == 1)
check("/xui stats status runs", ns.RunCommand("stats", "status") and printed[#printed]:find("Character Toolkit", 1, true) ~= nil)
check("/xui stats while off says so", ns.RunCommand("stats", "") and printed[#printed]:find("is off", 1, true) ~= nil)
CharacterFrame.shown = false
ns.RunCommand("stats", "on")
check("/xui stats on turns it on", c.enabled == true)
ns.RunCommand("stats", "")
check("/xui stats shows the panel on its own", XayaUICharacterToolkit:IsShown())
check("an old saved tab name (0.6.2 'ratings') maps to Stats", (function() c.tab = "ratings"; return ns.CharToolkit_Cfg().tab == "stats" end)())
print(("%d checks, %d failed"):format(n, fails))
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua"))
   .replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")))
sys.exit(1 if lua.eval("fails") else 0)
