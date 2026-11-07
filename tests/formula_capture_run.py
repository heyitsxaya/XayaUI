# End to end, offline: /xuiformula snapshots (XayaUI_DevAssist/FormulaCapture.lua) -> tools/formula_fit.py -> XayaUI_SpellData_<CLASS>
# -> the "Observed:" line on the spell tooltip (XayaUI_Bonus/Tooltips.lua). Stand-in game API; numbers follow a known formula.
import os, sys, shutil, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import formula_fit
fails = 0
def check(n, c):
    global fails
    print(("PASS " if c else "FAIL ") + n); fails += 0 if c else 1

L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
function issecretvalue() return false end
printed = {}
function print(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end printed[#printed+1] = table.concat(t, " ") end
function date() return "2026-11-04 01:00:00" end
function GetBuildInfo() return "12.1.5", "70688", "Nov 1 2026", 120105 end
C_Timer = { After = function(_, f) f() end }
function CreateFrame() return { RegisterEvent=function() end, UnregisterEvent=function() end, SetScript=function(s, n, f) s.h = f end } end
SlashCmdList = {}
inCombat = false
function InCombatLockdown() return inCombat end
function UnitClass() return "Demon Hunter", "DEMONHUNTER", 12 end
function GetSpecialization() return 2 end
function GetSpecializationInfo() return 581, "Vengeance" end
C_ClassTalents = { GetActiveConfigID = function() return 1 end }
C_Traits = { GetConfigInfo = function() return { treeIDs = { 10 } } end, GetTreeNodes = function() return { 100, 101 } end,
  GetNodeInfo = function(_, node) return { activeRank = 1, activeEntry = { entryID = node } } end,
  GetEntryInfo = function(_, e) return { definitionID = e } end, GetDefinitionInfo = function(d) return { spellID = d * 10 } end }
Enum = { SpellBookSpellBank = { Player = 0 } }
C_SpellBook = { GetNumSpellBookSkillLines = function() return 1 end,
  GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 2 } end,
  GetSpellBookItemInfo = function(i) return { spellID = ({ 263642, 258920 })[i] } end }
-- stats the test changes between snapshots
st = { agi = 5000, vers = 1.9, haste = 29.2 }
function UnitStat(_, i) local v = ({ 1000, st.agi, 900, 800 })[i] return v, v end
function UnitAttackPower() return st.agi, 0, 0 end
function GetSpellBonusDamage() return 100 end
function GetSpellBonusHealing() return 100 end
function GetCombatRatingBonus() return st.vers end
function GetVersatilityBonus() return 0 end
function UnitSpellHaste() return st.haste end
function GetCritChance() return 20 end
function GetMasteryEffect() return 80 end
function UnitHealthMax() return 1000000 end
function UnitDamage() return 1000, 1200 end
function UnitAttackSpeed() return 2.6 end
function GetAverageItemLevel() return 700, 700 end
function GetInventoryItemID(_, slot) if slot == 16 and not st.noWeapon then return 12345 end end
local function fmt(n) local s = tostring(math.floor(n + 0.5)) return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") end
C_Spell = {
  GetSpellDescription = function(id)
    local m = (1 + st.vers / 100)
    if id == 263642 then return "Rapidly slash your target for " .. fmt(2.77 * st.agi * m) .. " Physical damage, and shatter 2 Lesser Soul Fragments." end
    if id == 258920 then return "Engulf yourself in flames, instantly causing " .. fmt(0.52 * st.agi * m) .. " Fire damage to enemies within 8 yards." end
    return ""
  end,
  GetSpellCharges = function(id) if id == 263642 then return { maxCharges = 2, cooldownDuration = 4.5, chargeModRate = 1 + st.haste / 100 } end end,
  GetSpellBaseCooldown = function(id) if id == 258920 then return 12000 end return 0 end,
  GetSpellName = function(id) return ({ [263642] = "Fracture", [258920] = "Immolation Aura" })[id] end,
}
''')
L.eval('function(src,n) return (load(src,n)) end')(open(os.path.join(ROOT, 'XayaUI_DevAssist/FormulaCapture.lua'), encoding='utf-8').read(), 'FormulaCapture.lua')("XayaUI_DevAssist")
FC = 'XayaUIFormulaCapture'
check("hash is stable 8 hex chars", len(L.eval(FC + '.Hash("1000,1010")')) == 8 and L.eval(FC + '.Hash("a")') == L.eval(FC + '.Hash("a")'))
tpl = L.eval(FC + '.Split("Slash for 15,386 Physical damage within 8 yards.")')
check("split: template and numbers", tpl[0] == "Slash for # Physical damage within # yards." and list(tpl[1].values()) == [15386, 8])
# walkthrough: full gear, weapon off, trinket off, two more levels, then a versatility-only change
L.execute(FC + '.Capture("start")')
check("first snapshot taken", L.eval('#XayaUIDevAssistDB.formula.loadouts["DEMONHUNTER:581:" .. ' + FC + '.Loadout().hash].snaps') == 1)
L.execute(FC + '.Capture("again")')
check("no-change snapshot skipped", any("no change in stats" in str(p) for p in L.eval("printed").values()))
for agi, vers in ((4200, 1.9), (3900, 1.9), (3500, 1.9), (3500, 0.4)):
    L.execute(f"st.agi = {agi}; st.vers = {vers}; st.haste = st.haste - 1.5; {FC}.Capture('gear change')")
key = 'DEMONHUNTER:581:" .. ' + FC + '.Loadout().hash .. "'
n = L.eval('#XayaUIDevAssistDB.formula.loadouts["' + key + '"].snaps')
check("five snapshots across gear changes", n == 5)
check("status reports the loadout complete", any("This loadout is complete" in str(p) for p in L.eval("printed").values()))
L.execute("inCombat = true; printed = {}"); L.execute(FC + '.Capture("x")')
check("combat defers", any("when combat ends" in str(p) for p in L.eval("printed").values()))
L.execute("inCombat = false")
# serialize the saved variable the way the game writes it (enough of it for the loader)
L.execute(r'''
function ser(v, ind)
  ind = ind or ""
  if type(v) == "table" then
    local keys = {} for k in pairs(v) do keys[#keys+1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = { "{\n" }
    for _, k in ipairs(keys) do
      local ks = type(k) == "number" and ("[" .. k .. "]") or ("[" .. string.format("%q", k) .. "]")
      out[#out+1] = ind .. "  " .. ks .. " = " .. ser(v[k], ind .. "  ") .. ",\n"
    end
    out[#out+1] = ind .. "}"
    return table.concat(out)
  elseif type(v) == "string" then return string.format("%q", v)
  else return tostring(v) end
end''')
tmp = tempfile.mkdtemp()
saved = os.path.join(tmp, "XayaUI_DevAssist.lua")
open(saved, "w", encoding="utf-8").write("XayaUIDevAssistDB = " + L.eval("ser(XayaUIDevAssistDB)") + "\n")
formula_fit.main([saved, "--emit", "--out", tmp])
report = open(os.path.join(tmp, "formula-report.md"), encoding="utf-8").read()
check("Fracture fitted: 2.77 x attack power, x (1 + versatility)", "| Fracture (263642) | #1 Physical damage | 2.77 × attack power, × (1 + versatility) | 5 |" in report)
check("Immolation Aura fitted: 0.52 x attack power", "| Immolation Aura (258920) | #1 Fire damage | 0.52 × attack power, × (1 + versatility) | 5 |" in report)
check("constant numbers (2 fragments, 8 yards) are not formulas", "#2" not in report)
check("recharge scales with haste", "| Fracture (263642) | cooldown | 4.5 s, scales with haste | 5 |" in report)
data = os.path.join(tmp, "XayaUI_SpellData_DEMONHUNTER", "Data.lua")
toc = open(os.path.join(tmp, "XayaUI_SpellData_DEMONHUNTER", "XayaUI_SpellData_DEMONHUNTER.toc")).read()
check("data folder is load on demand", "## LoadOnDemand: 1" in toc and "Data.lua" in toc)
# the Bonus tooltip reads it
B = LuaRuntime(unpack_returned_tuples=True)
B.execute(r'''
function issecretvalue() return false end
lines = {}
GameTooltip = { AddDoubleLine = function(_, a, b) lines[#lines+1] = a .. " " .. b end }
posts = {}
Enum = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(t, f) posts[t] = f end }
function CreateFrame() return { RegisterEvent=function() end, SetScript=function() end } end
SlashCmdList = {}
function InCombatLockdown() return false end
function GetLocale() return "deDE" end   -- keep the live damage lines out of this check
function UnitClass() return "Demon Hunter", "DEMONHUNTER", 12 end
function GetSpecialization() return 2 end
function GetSpecializationInfo() return 581, "Vengeance" end
C_Spell = { GetSpellCharges = function() end, GetSpellCooldown = function() return { duration = 0, modRate = 1 } end, GetSpellBaseCooldown = function() return 0 end }
loaded = {}
C_AddOns = { DoesAddOnExist = function(n) return n == "XayaUI_SpellData_DEMONHUNTER" end, LoadAddOn = function(n) loaded[#loaded+1] = n; dofile(DATA) end }
''')
B.globals().DATA = data
B.execute("XayaUI_NS = {}; CueRulesDB = {}")
for f in ("XayaUI/Modules.lua", "XayaUI_Bonus/Tooltips.lua", "XayaUI/AuraSources.lua", "XayaUI_Bonus/TooltipsUI.lua"):
    B.eval('function(src,n) return (load(src,n)) end')(open(os.path.join(ROOT, f), encoding='utf-8').read(), f)("XayaUI", B.eval("XayaUI_NS"))
# (Bonus 0.6.30 reads AuraSources / AuraModel through ns.Service; this test sets ns.AuraSources / ns.AuraModel directly, so the lookup answers with them)
B.execute('local real = XayaUI_NS.Service; XayaUI_NS.Service = function(n) if n == "AuraSources" then return XayaUI_NS.AuraSources elseif n == "AuraModel" then return XayaUI_NS.AuraModel end return real(n) end')
# the stand-in talent list matches the capture (spell IDs 1000 and 1010)
B.execute("XayaUI_NS.AuraModel = { ActiveTalentSpells = function() return { 1010, 1000 } end }")
B.execute("XayaUI_NS.TT.DB(); XayaUI_NS.TT.Init(); XayaUI_NS.TT.DB().ids.enabled = false; XayaUI_NS.TT.LoadClassData()")
check("only the player's class folder is loaded", list(B.eval("loaded").values()) == ["XayaUI_SpellData_DEMONHUNTER"])
B.execute("posts[1](GameTooltip, { id = 263642 })")
got = list(B.eval("lines").values())
check("tooltip shows the observed formula with own talents", "Observed: 2.770 × attack power × (1 + versatility)  (Physical damage; 5 gear sets)" in got)
B.execute("lines = {}; XayaUI_NS.AuraModel = { ActiveTalentSpells = function() return { 1000 } end }; XayaUI_NS.TT.talentHash = nil; posts[1](GameTooltip, { id = 263642 })")
check("different talents are flagged", any("other talents" in l for l in B.eval("lines").values()))
B.execute("lines = {}; posts[1](GameTooltip, { id = 999 })")
check("spell without data: no observed line", not any("Observed" in l for l in B.eval("lines").values()))
# the fit refuses what it cannot reproduce, and does not claim a versatility result it never tested
pts = [({"ap": x, "vers": 1.9}, round(0.0001 * x * x)) for x in (3000, 3500, 4000, 4500)]
check("non-linear numbers: no fit", formula_fit.try_fit(pts, "ap", None) is None)
pts = [({"ap": x, "vers": 1.9}, round(2.77 * x * 1.019)) for x in (3000, 3500, 4000)]
f = formula_fit.try_fit(pts, "ap", None)
check("versatility never varied: reported as untested", f is not None and f["vers"] is None)
check("two power levels are not enough", formula_fit.try_fit(pts[:2], "ap", None) is None)
shutil.rmtree(tmp)
print("FAILS:", fails); sys.exit(1 if fails else 0)
