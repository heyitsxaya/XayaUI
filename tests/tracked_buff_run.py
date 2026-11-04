"""Insivius's Death and Decay rule (2026-11-04), in combat: "death and decay buff is tracked in his cdm ... it is failing in xui and
not triggering at all with or without conditions". The rule: Death and Decay (spell 43265) ready AND its buff (188290, extra ID
434034) missing; a condition: buff trigger AND charges == 2.

In combat the game hides both auras. Before 0.6.8 the buff answer stayed unknown when no Cooldown Manager frame carried 188290 or
434034 (the tracker is filed under the spell, 43265), and also when one listed ID could never be read (missing needs every ID
absent); the charge count was hidden too. This runs XayaUI's real Core.lua + Conditions.lua + Triggers.lua + Outcomes.lua against stand-in game
calls. The spell IDs are the rule's; the names and the frame are stand-ins.
Run: python3 tests/tracked_buff_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
COMBAT = false
SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
issecretvalue = function(v) return v == SECRET end
InCombatLockdown = function() return COMBAT end
C_Secrets = { ShouldAurasBeSecret = function() return COMBAT end, GetSpellAuraSecrecy = function() return 2 end }
Enum = Enum or {}; Enum.SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
NAMES = { [43265] = "Death and Decay", [188290] = "Death and Decay", [434034] = "Death and Decay", [55090] = "Scourge Strike", [999] = "Other Buff" }
C_Spell.GetSpellName = function(id) return NAMES[id] end
BUFF_UP = false
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
  if COMBAT then return SECRET end
  if BUFF_UP and id == 188290 then return { spellId = 188290, applications = 0, expirationTime = 0, duration = 0, auraInstanceID = 7 } end
  return nil
end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
-- Death and Decay: 2 charges; the count is hidden in combat, "recharging" and the maximum are not (NeverSecret)
CHG = 2
C_Spell.GetSpellCharges = function(id) if id ~= 43265 then return nil end
  return { currentCharges = COMBAT and SECRET or CHG, maxCharges = 2, isActive = CHG < 2, cooldownStartTime = 0, cooldownDuration = 0 } end
C_Spell.GetSpellCooldown = function(id)
  local act = (id == 43265 and CHG == 0)
  return { startTime = COMBAT and SECRET or 0, duration = COMBAT and SECRET or 0, isActive = act, isOnGCD = false, isEnabled = true }
end
-- the Cooldown Manager: Death and Decay in Tracked Buffs, filed under the SPELL (43265); a Scourge Strike cooldown icon
local function item(spellID)
  local f = CreateFrame("Frame")
  f.cooldownInfo = { spellID = spellID }
  function f:GetSpellID() return spellID end
  return f
end
DND = item(43265)
SS = item(55090)
BUFF_KIDS = { DND }
BuffIconCooldownViewer = CreateFrame("Frame"); function BuffIconCooldownViewer:GetChildren() return unpack(BUFF_KIDS) end
EssentialCooldownViewer = CreateFrame("Frame"); function EssentialCooldownViewer:GetChildren() return SS end
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
for f in ("XayaUI/Core.lua", "XayaUI/Conditions.lua", "XayaUI/Triggers.lua", "XayaUI/Outcomes.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute(r'''
local ns = NS
ns.Print = function() end
RULE = { uid = "u1", name = "Death and Decay", enabled = true, useCooldown = true, spellID = 43265, cdState = "ready",
  useBuff = true, buffID = 188290, buffAlt = { 434034 }, buffState = "missing", load = { mode = "all", combat = "yes", specs = { ["252"] = true } } }
COND = { uid = "c1", name = "Condition 1", parentUid = "u1", enabled = true,
  when = { list = { { ref = "buff", cmp = "==", num = 0, op = "and" }, { ref = "n:cdCharges", cmp = "==", num = 2, op = "and" } } } }
ns.rules = { RULE, COND }
if ns.NormalizeWhen then ns.NormalizeWhen(COND) end
function BUFF() local p, s = ns.BuffPresentAny(RULE); return p, s end
function TRIG() local _, info = ns.Evaluate(RULE, { combat = COMBAT, specID = 252 }); return info.cdOK, info.buffOK, info.trigOK end
function WHEN() local _, info = ns.EvaluateOutcome(COND, { combat = COMBAT, specID = 252 }); return info.whenOK end
''')
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)

# out of combat: the aura API answers; the fallback is not used
L.execute("COMBAT = false; BUFF_UP = false; DND.wasSetFromAura = false")
p, s = L.eval("BUFF()")
check("out of combat, buff not up: missing, from the aura API", p is False and "aura API" in str(s), (p, s))
L.execute("BUFF_UP = true")
p, s = L.eval("BUFF()")
check("out of combat, buff up: present, from the aura API", p is True and "aura API" in str(s), (p, s))

# in combat
L.execute("COMBAT = true; BUFF_UP = false; DND.wasSetFromAura = false; DND.auraInstanceID = nil; CHG = 2")
p, s = L.eval("BUFF()")
check("in combat, not standing in it: MISSING, from the Tracked Buffs icon of the rule's spell (was unknown)", p is False and "tracked buff of the rule's spell 43265" in str(s), (p, s))
cd, bf, trig = L.eval("TRIG()")
check("the rule's triggers: ready AND missing -> the rule is TRUE in combat", cd is True and bf is True and trig is True, (cd, bf, trig))
check("Condition 1 (buff AND charges == 2) is TRUE in combat", L.eval("WHEN()") is True, L.eval("WHEN()"))
L.execute("DND.wasSetFromAura = true; DND.auraInstanceID = SECRET")
p, s = L.eval("BUFF()")
check("in combat, standing in it: PRESENT (the icon is lit)", p is True, (p, s))
cd, bf, trig = L.eval("TRIG()")
check("  ...and the rule is FALSE", bf is False and trig is False, (cd, bf, trig))
L.execute("DND.wasSetFromAura = false; DND.auraInstanceID = nil; CHG = 1")
check("one charge left: the rule (ready = full charges) is FALSE and the condition's charges == 2 is FALSE, not unknown",
      L.eval("select(3, TRIG())") is False and L.eval("WHEN()") is False, (L.eval("TRIG()"), L.eval("WHEN()")))

# the game hides an icon's spell IDs while its aura is active: the IDs it showed before are kept
L.execute("COMBAT = true; DND.wasSetFromAura = false; DND.auraInstanceID = nil; GetTime = function() return 30000 end")
p, s = L.eval("BUFF()")
L.execute("DND.GetSpellID = function() return SECRET end; DND.cooldownInfo = { spellID = SECRET }; DND.wasSetFromAura = true; DND.auraInstanceID = SECRET; GetTime = function() return 30001 end")
p2, s2 = L.eval("BUFF()")
check("icon IDs hidden while its aura is active: still found from the IDs it showed before -> PRESENT", p is False and p2 is True, (p, s, p2, s2))
L.execute("DND.GetSpellID = function() return 43265 end; DND.cooldownInfo = { spellID = 43265 }; DND.wasSetFromAura = false; DND.auraInstanceID = nil; GetTime = function() return 30002 end")

# guards
L.execute("CHG = 2; RULE.buffID = 999; RULE.buffAlt = nil")
p, s = L.eval("BUFF()")
check("an aura with another name than the rule's spell is never answered from the spell's icon (stays unknown)", p is None, (p, s))
L.execute("RULE.buffID = 188290; RULE.buffAlt = { 434034 }; BUFF_KIDS = {}")
L.execute("GetTime = function() return 10000 end")   # (the frame index is rebuilt at most every 0.25 s of game time)
p, s = L.eval("BUFF()")
check("the spell not in Tracked Buffs: unknown, as before (no guess)", p is None, (p, s))
L.execute("BUFF_KIDS = { DND }; GetTime = function() return 20000 end; RULE.spellID = 55090; NAMES[55090] = 'Death and Decay'")
p, s = L.eval("BUFF()")
check("a COOLDOWN icon of the spell is never used as the buff (Essential viewer)", p is None, (p, s))

# "missing debuff" rules (Target Debuff (yours), state: NOT on the target), in combat: Blizzard files the tracker under the
# ability (Sigil of Flame 204596), the rule watches the debuff (204598): the icon is found by the debuff's NAME
L.execute(r'''
NAMES[204596], NAMES[204598] = "Sigil of Flame", "Sigil of Flame"
SIGIL = (function() local f = CreateFrame("Frame"); f.cooldownInfo = { spellID = 204596 }; function f:GetSpellID() return 204596 end; return f end)()
BUFF_KIDS = { DND, SIGIL }
UnitExists = function(u) return u == "player" or u == "target" end
UnitAffectingCombat = function() return COMBAT end
C_UnitAuras.GetUnitAuras = function() if COMBAT then return SECRET end return {} end
COMBAT = true; GetTime = function() return 40000 end
TD = { type = "targetDebuff", spellID = 204598, unit = "target", state = "no" }
function TDCHECK() return NS.TRIGGER_TYPES.targetDebuff.check(TD) end
''')
v, why = L.eval("TDCHECK()")
check("missing debuff in combat, tracker filed under the ability: found by name, icon not lit -> 'not on the target' TRUE", v is True, (v, why))
L.execute("SIGIL.wasSetFromAura = true; SIGIL.auraInstanceID = SECRET; GetTime = function() return 40001 end")
v, why = L.eval("TDCHECK()")
check("  ...icon lit -> FALSE", v is False, (v, why))
L.execute("NAMES[204599] = 'Some Other Debuff'; TD.spellID = 204599; SIGIL.wasSetFromAura = false; SIGIL.auraInstanceID = nil; GetTime = function() return 40002 end")
v, why = L.eval("TDCHECK()")
check("  ...a debuff with another name than any tracked icon stays unknown in combat (no guess)", v is None, (v, why))

print(); print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED"); sys.exit(1 if fails else 0)
