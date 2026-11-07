# Formula lines on spell tooltips (Bonus 0.6.2): cooldown / recharge from live duration + rate, damage ratio from the spell text.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
secret = {}
function issecretvalue(v) return secret[v] == true end
lines = {}
GameTooltip = { AddDoubleLine=function(self,a,b) lines[#lines+1]=a.." "..b end }
posts = {}
Enum = { TooltipDataType = { Item=0, Spell=1, Unit=2, UnitAura=7 } }
TooltipDataProcessor = { AddTooltipPostCall=function(t,f) posts[t]=f end }
function CreateFrame() return { RegisterEvent=function() end, SetScript=function() end } end
SlashCmdList = {}
inCombat = false
function InCombatLockdown() return inCombat end
function GetLocale() return "enUS" end
stats = { 1000, 5000, 900, 800 }          -- str, agi, sta, int
function UnitStat(u, i) return stats[i], stats[i] end
ap = { 5000, 550, 0 }
function UnitAttackPower() return ap[1], ap[2], ap[3] end
function GetSpellBonusDamage(school) return 4000 end
haste = 29.2
function UnitSpellHaste() return haste end
desc = {}
charges = {}
cds = {}
base = {}
C_Spell = {
  GetSpellDescription=function(id) return desc[id] end,
  GetSpellCharges=function(id) return charges[id] end,
  GetSpellCooldown=function(id) return cds[id] or { duration=0, modRate=1 } end,
  GetSpellBaseCooldown=function(id) return base[id] or 0, 1500 end,
  GetSpellTexture=function() return 1 end,
}
function reset() lines = {} end
''')
L.execute("XayaUI_NS = {}; CueRulesDB = {}")
for f in ("XayaUI/Modules.lua", "XayaUI_Bonus/Tooltips.lua", "XayaUI_Rules/AuraSources.lua", "XayaUI_Bonus/TooltipsUI.lua"):
    L.eval('function(src,n) return (load(src,n)) end')(open(os.path.join(ROOT, f), encoding='utf-8').read(), f)("XayaUI", L.eval("XayaUI_NS"))
L.execute("XayaUI_NS.TT.DB(); XayaUI_NS.TT.Init(); XayaUI_NS.TT.DB().ids.enabled = false")   # IDs off: only formula lines
fails = 0
def check(n, c):
    global fails
    if not c: print("  got:", list(L.eval("lines").values()))
    print(("PASS " if c else "FAIL ") + n); fails += 0 if c else 1
def run(code): L.execute("reset()"); L.execute(code); return list(L.eval("lines").values())
rech = "{lines={{leftText='Instant', rightText='3.5 sec recharge'}}}"
# Fracture-like: 2 charges, recharge 4.5 s, rate = 1 + haste
r = run("desc[1]='Rapidly slash your target for 15,386 Physical damage, and shatter 2 Lesser Soul Fragments.'; charges[1]={maxCharges=2, currentCharges=2, cooldownDuration=4.5, chargeModRate=1.292}; posts[1](GameTooltip, {id=1, lines=%s})" % rech[1:-1].join(["{", "}"]) if False else "desc[1]='Rapidly slash your target for 15,386 Physical damage, and shatter 2 Lesser Soul Fragments.'; charges[1]={maxCharges=2, currentCharges=2, cooldownDuration=4.5, chargeModRate=1.292}; posts[1](GameTooltip, {id=1, lines={{leftText='Instant', rightText='3.5 sec recharge'}}})")
check("recharge: duration / haste rate, matches tooltip", "Recharge: 4.5 s ÷ 1.29 (haste 29.2%) = 3.5 s = tooltip  (2 charges)" in r)
check("damage ratio over attack power (agility character)", "Damage ratio: 15,386 Physical ÷ 5,550 attack power = 2.77" in r)
# tooltip disagrees with duration / rate
r = run("charges[2]={maxCharges=2, cooldownDuration=4.5, chargeModRate=1.292}; posts[1](GameTooltip, {id=2, lines={{rightText='4.5 sec recharge'}}})")
check("mismatch is reported, not hidden", any("tooltip says 4.5 s" in l for l in r))
# rate that is not haste
r = run("charges[3]={maxCharges=2, cooldownDuration=10, chargeModRate=1.1}; posts[1](GameTooltip, {id=3})")
check("non-haste rate labelled as rate", "Recharge: 10 s ÷ 1.10 (rate) = 9.1 s  (2 charges)" in r)
# normal cooldown, running, with talent-reduced duration vs base
r = run("cds[4]={duration=10, modRate=1}; base[4]=12000; posts[1](GameTooltip, {id=4, lines={{rightText='12 sec cooldown'}}})")
check("cooldown not hasted, base differs, tooltip compared", "Cooldown: 10 s  (no haste or rate change); base 12 s; tooltip says 12 s" in r)
# not on cooldown: base only
r = run("base[5]=120000; posts[1](GameTooltip, {id=5})")
check("idle cooldown shows base only", "Cooldown: 120 s base; haste shows while it is on cooldown" in r)
# GCD only is not the spell's cooldown
r = run("cds[6]={duration=1.5, modRate=1, isOnGCD=true}; posts[1](GameTooltip, {id=6})")
check("GCD ignored", not any(l.startswith("Cooldown") for l in r))
# Immolation Aura-like text: two damage numbers, second one over time
r = run("desc[7]='Engulf yourself in flames, instantly causing 2,884 Fire damage to enemies within 8 yards and radiating 9,687 Fire damage over 9 sec.'; posts[1](GameTooltip, {id=7})")
check("two damage numbers, second over time", r == ["Damage ratio: 2,884 Fire ÷ 5,550 attack power = 0.52", "Damage ratio: 9,687 Fire over 9 sec ÷ 5,550 attack power = 1.75"])
# intellect character uses spell power
r = run("stats={500,500,900,6000}; posts[1](GameTooltip, {id=7})")
check("intellect character divides by spell power", r[0] == "Damage ratio: 2,884 Fire ÷ 4,000 spell power = 0.72")
L.execute("stats={1000,5000,900,800}")
# secret attack power: no ratio, no error
r = run("secret[5000]=true; posts[1](GameTooltip, {id=1})")
check("secret stat skipped", not any("Damage" in l for l in r))
L.execute("secret[5000]=nil")
# in combat: nothing
r = run("inCombat=true; posts[1](GameTooltip, {id=1, lines={{rightText='3.5 sec recharge'}}})")
check("nothing in combat", r == [])
L.execute("inCombat=false")
# non-English client: no damage parsing
r = run("GetLocale=function() return 'deDE' end; posts[1](GameTooltip, {id=7})")
check("non-English text not parsed", r == [])
L.execute("GetLocale=function() return 'enUS' end")
# options
r = run("XayaUI_NS.TT.DB().formulas.damage=false; posts[1](GameTooltip, {id=1})")
check("damage option off", not any("Damage" in l for l in r) and any("Recharge" in l for l in r))
r = run("XayaUI_NS.TT.DB().formulas.damage=true; XayaUI_NS.TT.DB().formulas.enabled=false; posts[1](GameTooltip, {id=1})")
check("master switch off", r == [])
L.execute("XayaUI_NS.TT.DB().formulas.enabled=true")
# items get no formula lines
check("items untouched", run("posts[0](GameTooltip, {id=1})") == [])
# throwing API contained
r = run("C_Spell.GetSpellCharges=function() error('x') end; posts[1](GameTooltip, {id=7})")
check("throwing API contained (damage lines still drawn)", len(r) == 2)
# learned-data hook
r = run("XayaUI_NS.TT.FormulaSource=function(id) return { {'Observed:', '2.77 x attack power'} } end; posts[1](GameTooltip, {id=99})")
check("FormulaSource lines added", "Observed: 2.77 x attack power" in r)
g = L.eval("XayaUI_NS.BuildTooltipsTab(function() end)")
check("Formulas tab built", g.args.formulas is not None)
print("FAILS:", fails); sys.exit(1 if fails else 0)
