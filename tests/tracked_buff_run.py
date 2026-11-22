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
# (round 11b, build spec step 5) hidden data comes from the shared stand-in: the secret object and world.lua's restriction state (combat hides
# the auras and the charge count through C_Secrets, as the game does); no local fake.
BENCH_RESTRICTIONS = r'''
-- [bench restrictions] (round 11b, build spec step 5: one stand-in for hidden data, kept in the private XUI-Docs repo)
-- A test on the engine_bench.py stubs gets the shared secret object (tests/harness/secret.lua) and the restriction state machine of
-- tests/harness/world.lua, the same code the harness and the gates play. world.lua runs in its own environment, so its frames,
-- C_Spell and C_UnitAuras stay there and the bench's stubs and the test's own game model are untouched. This state gets:
--   W   the world: drive it with W.enterCombat / W.leaveCombat, W.startKey / W.completeKey, W.startEncounter / W.endEncounter,
--       W.enterInstance / W.leaveInstance; set W.auraSecrecy[id] / W.cdSecrecy[id] (0 NeverSecret, 1 AlwaysSecret, absent 2)
--   W.S the secret object: W.S.new(v) a hidden value, W.S.reveal(v) for asserts only (no global S: tests name rules S)
--   the installed type, issecretvalue, canaccessvalue, issecrettable, canaccesstable, tonumber, string.format (S.install), and
--   world's state-driven readers: C_Secrets, C_RestrictedActions, InCombatLockdown, UnitAffectingCombat, IsInInstance,
--   GetInstanceInfo, C_ChallengeMode and C_InstanceEncounter (a test may still replace any of them after this block).
-- The world's events (PLAYER_REGEN_DISABLED, ADDON_RESTRICTION_STATE_CHANGED, ...) go to BENCH_FIRE(event, ...) when the test defines
-- it (its own event delivery), and nowhere otherwise. Run once, after the bench and before any addon file (addons keep 'local type =
-- type'). Every copy of this block is the same: tests/fix_r11_fakes_run.py checks it (its owner should be engine_bench.py).
do
  local dir, G = ..., _G
  local env = {}
  for _, k in ipairs({ "assert", "collectgarbage", "coroutine", "debug", "dofile", "error", "gcinfo", "getfenv", "getmetatable", "ipairs",
      "load", "loadfile", "loadstring", "math", "newproxy", "next", "os", "pairs", "pcall", "print", "rawequal", "rawget", "rawset",
      "select", "setfenv", "setmetatable", "string", "table", "tonumber", "tostring", "type", "unpack", "xpcall", "_VERSION" }) do
    env[k] = rawget(G, k)
  end
  env._G = env
  local chunk = assert(loadfile(dir .. "world.lua"))
  setfenv(chunk, env)
  W = chunk()({})
  W.S.install(G, { legacy = W })
  for _, k in ipairs({ "C_Secrets", "C_RestrictedActions", "InCombatLockdown", "UnitAffectingCombat", "IsInInstance", "GetInstanceInfo",
      "C_ChallengeMode", "C_InstanceEncounter" }) do
    G[k] = env[k]
  end
  W.fire = function(e, ...) local f = rawget(G, "BENCH_FIRE"); if f then return f(e, ...) end end
end
-- [/bench restrictions]
'''
L.execute(BENCH_RESTRICTIONS, os.path.join(ROOT, "tests", "harness") + os.sep)
L.execute(r'''
function COMBAT(on) if on and not W.combat then W.enterCombat() elseif not on and W.combat then W.leaveCombat() end end
Enum = Enum or {}; Enum.SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
NAMES = { [43265] = "Death and Decay", [188290] = "Death and Decay", [434034] = "Death and Decay", [55090] = "Scourge Strike", [999] = "Other Buff" }
C_Spell.GetSpellName = function(id) return NAMES[id] end
BUFF_UP = false
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
  if C_Secrets.ShouldSpellAuraBeSecret(id) then return nil end   -- RequiresNonSecretAura: nil while the aura is hidden (spec 2.2)
  if BUFF_UP and id == 188290 then return { spellId = 188290, applications = 0, expirationTime = 0, duration = 0, auraInstanceID = 7 } end
  return nil
end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
-- Death and Decay: 2 charges; the count is hidden in combat, "recharging" and the maximum are not (NeverSecret)
CHG = 2
C_Spell.GetSpellCharges = function(id) if id ~= 43265 then return nil end
  local cur = CHG; if C_Secrets.ShouldSpellCooldownBeSecret(id) then cur = W.S.new(CHG) end
  return { currentCharges = cur, maxCharges = 2, isActive = CHG < 2, cooldownStartTime = 0, cooldownDuration = 0 } end
C_Spell.GetSpellCooldown = function(id)
  local act = (id == 43265 and CHG == 0)
  local h = C_Secrets.ShouldSpellCooldownBeSecret(id)
  return { startTime = h and W.S.new(0) or 0, duration = h and W.S.new(0) or 0, isActive = act, isOnGCD = false, isEnabled = true }
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
for f in ("XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI_Rules/RuleDefaults.lua", "XayaUI_Rules/Conditions.lua", "XayaUI_Rules/Triggers.lua", "XayaUI_Rules/Outcomes.lua"):
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
function TRIG() local _, info = ns.Evaluate(RULE, { combat = InCombatLockdown(), specID = 252 }); return info.cdOK, info.buffOK, info.trigOK end
function WHEN() local _, info = ns.EvaluateOutcome(COND, { combat = InCombatLockdown(), specID = 252 }); return info.whenOK end
''')
fails = []
checked = []   # (round 11 repair, SD-138 / V35: a test fails if it prints no result count) every check() made, for the last line "N checks, M failed" tests/run_all.py reads
def check(name, ok, extra=""):
    checked.append(name)
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)

# out of combat: the aura API answers; the fallback is not used
L.execute("COMBAT(false); BUFF_UP = false; DND.wasSetFromAura = false")
p, s = L.eval("BUFF()")
check("out of combat, buff not up: missing, from the aura API", p is False and "aura API" in str(s), (p, s))
L.execute("BUFF_UP = true")
p, s = L.eval("BUFF()")
check("out of combat, buff up: present, from the aura API", p is True and "aura API" in str(s), (p, s))

# in combat
L.execute("COMBAT(true); BUFF_UP = false; DND.wasSetFromAura = false; DND.auraInstanceID = nil; CHG = 2")
p, s = L.eval("BUFF()")
check("in combat, not standing in it: MISSING, from the Tracked Buffs icon of the rule's spell (was unknown)", p is False and "tracked buff of the rule's spell 43265" in str(s), (p, s))
cd, bf, trig = L.eval("TRIG()")
check("the rule's triggers: ready AND missing -> the rule is TRUE in combat", cd is True and bf is True and trig is True, (cd, bf, trig))
check("Condition 1 (buff AND charges == 2) is TRUE in combat", L.eval("WHEN()") is True, L.eval("WHEN()"))
L.execute("DND.wasSetFromAura = true; DND.auraInstanceID = W.S.new(7)")
p, s = L.eval("BUFF()")
check("in combat, standing in it: PRESENT (the icon is lit)", p is True, (p, s))
cd, bf, trig = L.eval("TRIG()")
check("  ...and the rule is FALSE", bf is False and trig is False, (cd, bf, trig))
L.execute("DND.wasSetFromAura = false; DND.auraInstanceID = nil; CHG = 1")
check("one charge left: the rule (ready = full charges) is FALSE and the condition's charges == 2 is FALSE, not unknown",
      L.eval("select(3, TRIG())") is False and L.eval("WHEN()") is False, (L.eval("TRIG()"), L.eval("WHEN()")))

# the game hides an icon's spell IDs while its aura is active: the IDs it showed before are kept
L.execute("COMBAT(true); DND.wasSetFromAura = false; DND.auraInstanceID = nil; GetTime = function() return 30000 end")
p, s = L.eval("BUFF()")
L.execute("DND.GetSpellID = function() return W.S.new(43265) end; DND.cooldownInfo = { spellID = W.S.new(43265) }; DND.wasSetFromAura = true; DND.auraInstanceID = W.S.new(7); GetTime = function() return 30001 end")
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
check("a COOLDOWN icon of the spell is never used as the buff (Essential viewer)", p is None or ("Essential" not in str(s)), (p, s))
# 0.6.13 (gap 8): with no icon under the aura's IDs and none of the rule's spell in Tracked Buffs, a Tracked Buffs icon filed
# under the aura's NAME answers (here DND, "Death and Decay", the same name as aura 188290), never the Essential cooldown icon
check("the aura's name finds the Tracked Buffs icon (not lit -> absent), and says so", p is False and "name" in str(s), (p, s))

# "missing debuff" rules (Target Debuff (yours), state: NOT on the target), in combat: Blizzard files the tracker under the
# ability (Sigil of Flame 204596), the rule watches the debuff (204598): the icon is found by the debuff's NAME
L.execute(r'''
NAMES[204596], NAMES[204598] = "Sigil of Flame", "Sigil of Flame"
SIGIL = (function() local f = CreateFrame("Frame"); f.cooldownInfo = { spellID = 204596 }; function f:GetSpellID() return 204596 end; return f end)()
BUFF_KIDS = { DND, SIGIL }
UnitExists = function(u) return u == "player" or u == "target" end
-- RequiresUnitAuraAccess: the read errors while auras are hidden (spec 2.2; before round 11b this stand-in handed a hidden token)
C_UnitAuras.GetUnitAuras = function() if C_Secrets.ShouldAurasBeSecret() then error(string.format(W.TEXT_AURA_ACCESS, "C_UnitAuras.GetUnitAuras")) end return {} end
COMBAT(true); GetTime = function() return 40000 end
TD = { type = "targetDebuff", spellID = 204598, unit = "target", state = "no" }
function TDCHECK() return NS.TRIGGER_TYPES.targetDebuff.check(TD) end
''')
v, why = L.eval("TDCHECK()")
check("missing debuff in combat, tracker filed under the ability: found by name, icon not lit -> 'not on the target' TRUE", v is True, (v, why))
L.execute("SIGIL.wasSetFromAura = true; SIGIL.auraInstanceID = W.S.new(9); GetTime = function() return 40001 end")
v, why = L.eval("TDCHECK()")
check("  ...icon lit -> FALSE", v is False, (v, why))
L.execute("NAMES[204599] = 'Some Other Debuff'; TD.spellID = 204599; SIGIL.wasSetFromAura = false; SIGIL.auraInstanceID = nil; GetTime = function() return 40002 end")
v, why = L.eval("TDCHECK()")
check("  ...a debuff with another name than any tracked icon stays unknown in combat (no guess)", v is None, (v, why))

print()
if fails:
    print("FAILED: " + ", ".join(fails))
print("%d checks, %d failed" % (len(checked), len(fails)))
sys.exit(1 if fails else 0)
