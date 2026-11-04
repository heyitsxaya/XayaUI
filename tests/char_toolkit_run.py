# Stub test for QoL > Character Toolkit (XayaUI_QoL 0.6.2): StatMath.lua (thresholds, lost rating, rating per 1%, next 1%) and
# CharacterToolkit.lua (model rows, secret values, linked stats, spell-number parsing, tooltip label matching, settings page, command).
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
''' .replace("__SM__", P("XayaUI_QoL/StatMath.lua")))

# --- CharacterToolkit.lua with stand-in game calls ----------------------------------------------------------------------------
lua.execute(r'''
local function mk(kind)
  local o = { kind = kind, shown = false, pts = {}, scripts = {}, hooks = {}, events = {} }
  return setmetatable(o, { __index = function(t, k)
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local F = {
      Show = function(self) self.shown = true; if self.hooks.OnShow then for _, f in ipairs(self.hooks.OnShow) do f(self) end end end,
      Hide = function(self) self.shown = false; if self.hooks.OnHide then for _, f in ipairs(self.hooks.OnHide) do f(self) end end end,
      IsShown = function(self) return self.shown end,
      SetScript = function(self, s, f) self.scripts[s] = f end,
      HookScript = function(self, s, f) self.hooks[s] = self.hooks[s] or {}; table.insert(self.hooks[s], f) end,
      RegisterEvent = function(self, e) self.events[e] = true end, RegisterUnitEvent = function(self, e) self.events[e] = true end,
      UnregisterAllEvents = function(self) self.events = {} end,
      CreateTexture = function() return mk("Texture") end, CreateFontString = function() local f = mk("FS"); f.text = ""; return f end,
      SetText = function(self, s) self.text = s end, GetText = function(self) return self.text end,
      GetStringHeight = function() return 12 end, GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end,
      GetHeight = function(self) return self.h or 0 end, SetHeight = function(self, h) self.h = h end,
      SetSize = function(self, w, h) self.w, self.h = w, h end, GetCenter = function() return 0, 0 end,
      GetVerticalScroll = function() return 0 end, GetChildren = function(self) return unpack(self.children or {}) end,
      IsOwned = function(self, f) return self.owner == f end, SetOwner = function(self, f) self.owner = f; self.lines = {} end,
      AddLine = function(self, s) self.lines = self.lines or {}; table.insert(self.lines, s) end,
    }
    return F[k] or function() end
  end })
end
CreateFrame = function(kind, name) local f = mk(kind); if name then _G[name] = f end; return f end
UIParent = mk("Frame")
GameTooltip = mk("GameTooltip")
C_Timer = { After = function(_, fn) fn() end }
InCombatLockdown = function() return false end
hooksecurefunc = function(name, fn) local old = _G[name]; _G[name] = function(...) local r = { old(...) }; fn(...); return unpack(r) end end
STAT_CRITICAL_STRIKE, STAT_MASTERY, STAT_PARRY, SPELL_STAT3_NAME = "Critical Strike", "Mastery", "Parry", "Stamina"

-- game reads (VDH-like numbers from Xaya's screenshot: 528 crit = 11.48%, 997 mastery, 69,647 stamina)
local RATE = 1 / 46
local function dr(x) local lin = x * RATE; if lin <= 30 then return lin end; return 30 + (lin - 30) * 0.9 end
local ratings = { [9] = 528, [18] = 1200, [26] = 997, [29] = 120, [31] = 120, [21] = 0, [17] = 0, [14] = 0, [4] = 0, [3] = 0 }
GetCombatRating = function(i) return ratings[i] or 0 end
GetCombatRatingBonus = function(i) if i == 4 then return 0 end; if i == 31 then return dr(ratings[i]) / 2 end; return dr(ratings[i] or 0) end
GetCombatRatingBonusForCombatRatingValue = function(i, v) if i == 31 then return dr(v) / 2 end; if i == 4 then return v / 52 end; return dr(v) end
GetCritChance = function() return 22.48 end
GetRangedCritChance = function() return 5 end
GetSpellCritChance = function() return 5 end
GetHaste = function() return 29.25 end
GetMeleeHaste = function() return 29.25 end
GetMasteryEffect = function() return 88.69, 2.8 end
GetVersatilityBonus = function() return 0 end
GetAvoidance = function() return 0 end
GetLifesteal = function() return 13.61 end
GetSpeed = function() return 0 end
GetDodgeChance = function() return 16.52 end
GetParryChance = function() return 14.01 end
GetBlockChance = function() return 0 end
GetCritChanceProvidesParryEffect = function() return true end
UnitStat = function(_, i) local v = ({ 1000, 2637, 69647, 900 })[i]; return v, v end
UnitHPPerStamina = function() return 20 end
GetUnitMaxHealthModifier = function() return 1.06 end
UnitHealthMax = function() return 1476516 end
UnitArmor = function() return 5685, 5685 end
UnitEffectiveLevel = function() return 90 end
C_PaperDollInfo = { GetArmorEffectiveness = function(a, lvl) return a / (a + 12000) end }
UnitAttackPower = function() return 3472, 0, 0 end
GetAttackPowerForStat = function(i, v) return v end
UnitAttackSpeed = function() return 2.0, 2.01 end
UnitDamage = function() return 8138.2, 8944.6 end
GetSpecialization = function() return 2 end
GetSpecializationInfo = function() return 581, "Vengeance", "", 0, "TANK", 2 end
GetSpellBonusDamage = function() return 500 end
C_Spell = {
  GetSpellName = function(id) return id == 263642 and "Fracture" or nil end,
  GetSpellInfo = function(x) if x == "Fracture" then return { spellID = 263642, name = "Fracture" } end end,
  GetSpellDescription = function(id) return "Rapidly slash your target for 6,944 Physical damage, and shatter 2 Lesser Soul Fragments. Generates 25 Fury. 15% more." end,
  GetSpellCooldown = function() return { startTime = 1, duration = 1.16 } end,
}
issecretvalue = function(v) return v == "SECRET" end
LARGE_NUMBER_SEPERATOR, DECIMAL_SEPERATOR = ",", "."
printed = {}
ns = { Print = function(...) table.insert(printed, table.concat({ ... }, " ")) end }
CueRulesDB = {}
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
ns.FireReady()

local c = ns.CharToolkit_Cfg()
check("off by default", c.enabled == false)
check("defaults filled", c.panel == true and c.side == "right" and c.tooltips == true and type(c.spells) == "table")

local function row(model, key) for _, r in ipairs(model) do if r.key == key then return r end end end
local function has(r, pat) for _, l in ipairs(r and r.lines or {}) do if l:find(pat, 1, true) then return true end end; return false end
local m = ns.CharToolkit_Model()
local crit = row(m, "crit")
check("crit row: total 22.48%", crit and crit.value == "22.48%", crit and crit.value)
check("crit row: true rating, lost 0, penalty 0%", has(crit, "528 rating = +11.48%  |  lost 0  |  penalty 0%"), crit and crit.lines[1])
check("crit row: 46.0 per 1%, next 1% 46", has(crit, "46.0 rating per 1%  |  next 1%: 46"), crit and crit.lines[2])
check("crit row: next threshold 1,380 (30.00%), 852 away", has(crit, "Next threshold: 1,380 rating (30.00%), 852 away"), crit and crit.lines[3])
local mas = row(m, "mastery")
check("mastery row: 16.4 rating per 1% mastery", has(mas, "16.4 rating per 1% mastery"), mas and mas.lines[2])
check("mastery row: mastery factor on the hover", (function() for _, t in ipairs(mas.tip) do if t:find("2.800", 1, true) then return true end end end)())
local sta = row(m, "stamina")
check("stamina: 1 Stamina = 21.20 health", has(sta, "1 Stamina = 21.20 health"), sta and sta.lines[1])
check("stamina: stamina for +1% max health", has(sta, "Stamina for +1% max health"), sta and sta.lines[2])
local parry = row(m, "parry")
check("parry from crit: 528 crit rating = 10.15% parry", has(parry, "528 crit rating = 10.15% parry"), parry and parry.lines[1])
check("parry from crit: 52.0 crit rating per 1%", has(parry, "52.0 crit rating per 1%"), parry and parry.lines[2])
local armor = row(m, "armor")
check("armor: reduction and armor for next 1%", has(armor, "Damage reduction vs your level") and has(armor, "Armor for the next 1%"))
check("armor: primary -> armor marked not given", has(armor, "not given by the game"))
local ap = row(m, "ap")
check("attack power: 1 Agility = 1.00 attack power", has(ap, "1 Agility = 1.00 attack power"), ap and ap.lines[1])
check("dodge: primary -> dodge marked not given", has(row(m, "dodge"), "Agility -> dodge"))
check("gcd: unavailable before one is seen", row(m, "gcd").value:find("unavailable", 1, true) ~= nil)
ns.CharToolkit_ReadGCD()
local g = row(ns.CharToolkit_Model(), "gcd")
check("gcd: read from the game's global cooldown", g.value == "1.16 s", g.value)
check("gcd: unhasted estimate 1.50 s", has(g, "unhasted (estimate) 1.50 s"), g.lines[1])
check("gcd: haste rating for -0.01 s", has(g, "Haste for -0.01 s"), g.lines[2])
check("attack speed: unhasted estimate and haste for -0.01 s", has(row(m, "speed"), "Unhasted (estimate)") and has(row(m, "speed"), "Haste rating for -0.01 s"))

-- secret values: shown as unavailable, never compared
GetCombatRating = function(i) if i == 9 then return "SECRET" end; return ratings[i] or 0 end
GetCritChance = function() return "SECRET" end
ns.CharToolkit_ClearCache()
crit = row(ns.CharToolkit_Model(), "crit")
check("secret crit: value unavailable, no error", crit and crit.value:find("unavailable", 1, true) ~= nil, crit and crit.value)
GetCombatRating = function(i) return ratings[i] or 0 end
GetCritChance = function() return 22.48 end

-- no converter: current figures only, said plainly
local saved = GetCombatRatingBonusForCombatRatingValue
GetCombatRatingBonusForCombatRatingValue = nil
crit = row(ns.CharToolkit_Model(), "crit")
check("no converter: average per 1% and a note", has(crit, "average, no threshold data") and crit.tip[1]:find("not available", 1, true) ~= nil)
GetCombatRatingBonusForCombatRatingValue = saved

-- spell math
local nums = ns.CharToolkit_Numbers("Rapidly slash your target for 6,944 Physical damage, and shatter 2 Lesser Soul Fragments. 15% more.")
check("numbers: thousands separator read, percentages skipped", nums[1] == 6944 and nums[2] == 2 and #nums == 2, table.concat(nums, ","))
check("resolve: spell link", ns.CharToolkit_ResolveSpell("|cff71d5ff|Hspell:263642:0|h[Fracture]|h|r") == 263642)
check("resolve: name", ns.CharToolkit_ResolveSpell("Fracture") == 263642)
check("resolve: id", ns.CharToolkit_ResolveSpell(" 263642 ") == 263642)
c.advanced = true
c.spells = { { id = 263642, base = "ap", coeff = 200 } }
local sm = ns.CharToolkit_Model()
local fr
for _, r in ipairs(sm) do if r.label == "Fracture" then fr = r end end
check("spell math: Fracture row", fr ~= nil)
check("spell math: 6,944 = 200.0% of attack power, 1 Agility = +2.00", fr and has(fr, "6,944 = 200.0% of attack power  |  1 Agility = +2.00"), fr and fr.lines[1])
check("spell math: entered coefficient matches, no warning", fr and has(fr, "Entered: 200.0% of attack power; measured first number: 200.0%") and not has(fr, "differs"))
c.spells[1].coeff = 150
for _, r in ipairs(ns.CharToolkit_Model()) do if r.label == "Fracture" then fr = r end end
check("spell math: a different entered coefficient is flagged", has(fr, "differs"))

-- tooltip label matching
check("label: 'Critical Strike:' -> crit", ns.CharToolkit_KeyForLabel("Critical Strike:") == "crit")
check("label: colored 'Mastery:' -> mastery", ns.CharToolkit_KeyForLabel("|cffffffffMastery:|r") == "mastery")
check("label: 'Global Cooldown:' -> gcd", ns.CharToolkit_KeyForLabel("Global Cooldown:") == "gcd")
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
for _, l in ipairs(GameTooltip.lines or {}) do if tostring(l):find("lost 0", 1, true) then found = true end end
check("tooltip: toolkit lines added to the crit tooltip", found)
PaperDollFrame:Hide()
check("panel hides with the character window", not XayaUICharacterToolkit:IsShown())
c.enabled = false; ns.CharToolkit_Apply()
check("off: panel hidden", not XayaUICharacterToolkit:IsShown())

-- settings page and command
local page = ns.BuildCharToolkitPage(function() end)
check("settings page builds with Panel and Spell Math tabs", page.args.panelTab and page.args.spells and page.childGroups == "tab")
page.args.spells.args.add.set(nil, "Fracture")
check("add spell via settings (duplicate ignored)", #c.spells == 1)
check("/xui stats status runs", ns.RunCommand("stats", "status") and printed[#printed]:find("Character Toolkit", 1, true) ~= nil)
check("/xui stats while off says so", ns.RunCommand("stats", "") and printed[#printed]:find("is off", 1, true) ~= nil)
CharacterFrame.shown = false
ns.RunCommand("stats", "on")
check("/xui stats on turns it on", c.enabled == true)
ns.RunCommand("stats", "")
check("/xui stats shows the panel on its own", XayaUICharacterToolkit:IsShown())
print(("%d checks, %d failed"):format(n, fails))
'''.replace("__MOD__", P("XayaUI/Modules.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")))
sys.exit(1 if lua.eval("fails") else 0)
