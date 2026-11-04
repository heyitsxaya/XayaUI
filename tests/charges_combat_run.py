"""Charges in combat (core 0.6.9). Insivius, 2026-11-04, after 0.6.8: his Death and Decay rule fired "before he has charges
available". 0.6.8 read "no charge recharging" (SpellChargeInfo.isActive == false, NeverSecret) as "full"; Blizzard documents
that flag as false also when the recharge's "start time or duration are zero", and a cooldown can be on hold. The count is now
built from anchors (exact out of combat; 0 while the spell's own cooldown runs; full only when no cast of yours came after it
was last seen full) and your own casts (+ the Cooldown Manager's charge gains for 3+ charges). This runs XayaUI's real Core,
Conditions, Triggers and Outcomes against stand-in game calls in simulated time. Spell 43265 is Death and Decay, 152280 is used
as a stand-in replacement spell; everything else is made up.
Run: python3 tests/charges_combat_run.py   (needs: pip install lupa)"""
import os, sys, re
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
COMBAT = false
T = 1000
GetTime = function() return T end
SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
issecretvalue = function(v) return v == SECRET end
InCombatLockdown = function() return COMBAT end
-- the game, per spell: cur (true count), max, recharging (what the game REPORTS as SpellChargeInfo.isActive), cd (the spell's
-- own cooldown running), hold (its cooldown is on hold)
SP = {}
function SPELL(id, max) SP[id] = { cur = max, max = max, recharging = false, cd = false, hold = false } end
OVR = {}
C_Spell.GetOverrideSpell = function(id) return OVR[id] or id end
C_Spell.GetSpellCharges = function(id)
  local s = SP[id]; if not s then return nil end
  return { currentCharges = COMBAT and SECRET or s.cur, maxCharges = s.max, isActive = s.recharging,
           cooldownStartTime = COMBAT and SECRET or 0, cooldownDuration = COMBAT and SECRET or 0, chargeModRate = 1 }
end
C_Spell.GetSpellCooldown = function(id)
  local s = SP[id] or { cd = false, hold = false }
  return { startTime = COMBAT and SECRET or 0, duration = COMBAT and SECRET or 0, isActive = s.cd, isOnGCD = false, isEnabled = not s.hold, modRate = 1 }
end
-- the Cooldown Manager: an Essential icon for a 3-charge spell (its ChargeGained alerts are counted)
local function item(spellID)
  local f = CreateFrame("Frame"); f.cooldownInfo = { spellID = spellID }; function f:GetSpellID() return spellID end; return f
end
ESS = {}
EssentialCooldownViewer = CreateFrame("Frame"); function EssentialCooldownViewer:GetChildren() return unpack(ESS) end
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
for f in ("XayaUI/Core.lua", "XayaUI/Conditions.lua", "XayaUI/Timing.lua", "XayaUI/Triggers.lua", "XayaUI/Outcomes.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute(r'''
local ns = NS
ns.Print = function() end
-- (so the same checks can run against an older build, which had neither)
ns._WatchCharges = ns._WatchCharges or function() end
ns.NoteChargeCast = ns.NoteChargeCast or function() end
function RULE(id, state) return { uid = "r" .. id .. state, name = "R" .. id, enabled = true, useCooldown = true, spellID = id, cdState = state, buffState = "none", load = { mode = "always" } } end
function CD(r) return ns.ReadCooldown(r) end
function COUNT(r) local _, info = ns.Evaluate(r, { combat = COMBAT }); return ns.NumRef("n:cdCharges", r, info) end
function READY(r) local _, info = ns.Evaluate(r, { combat = COMBAT }); return info.cdOK end
function CAST(id) ns.NoteChargeCast(id, T) end
function WATCH() ns._WatchCharges() end
''')
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)
def lua(s): return L.execute(s)
def ev(s): return L.eval(s)

# --- 1. Death and Decay (2 charges), Insivius's report: a charge used, its recharge not started yet ---
lua("SPELL(43265, 2); DND = RULE(43265, 'ready'); NS.rules = { DND }; WATCH()")
check("out of combat: exact 2, ready", ev("COUNT(DND)") == 2 and ev("READY(DND)") is True)
lua("COMBAT = true; T = T + 5; WATCH()")
check("combat starts at full: 2, ready", ev("COUNT(DND)") == 2 and ev("READY(DND)") is True)
lua("T = T + 1; CAST(43265); SP[43265].cur = 1; SP[43265].recharging = false")   # the game says 'not recharging' after the cast
check("cast, recharge not started (the game says 'not recharging'): NOT ready, count 1 (was: full, the early fire)",
      ev("READY(DND)") is False and ev("COUNT(DND)") == 1, (ev("READY(DND)"), ev("COUNT(DND)")))
lua("T = T + 3; SP[43265].recharging = true")
check("recharge running: 1, not ready", ev("COUNT(DND)") == 1 and ev("READY(DND)") is False)
lua("T = T + 1; CAST(43265); SP[43265].cur = 0; SP[43265].cd = true")
check("second cast: the spell's own cooldown runs -> 0", ev("COUNT(DND)") == 0 and ev("READY(DND)") is False)
lua("T = T + 20; SP[43265].cur = 1; SP[43265].cd = false; SP[43265].recharging = true")
check("one charge back: 1", ev("COUNT(DND)") == 1)
lua("T = T + 20; SP[43265].cur = 2; SP[43265].recharging = false")
check("recharge seen to finish: full again, ready", ev("COUNT(DND)") == 2 and ev("READY(DND)") is True)

# --- 2. a combat-only rule: never read out of combat; the watcher keeps an exact count anyway ---
lua("SPELL(43266, 2); C2 = RULE(43266, 'ready'); NS.rules = { DND, C2 }; COMBAT = true; T = T + 1; CAST(43266); SP[43266].cur = 1; SP[43266].recharging = true; WATCH()")
lua("COMBAT = false; T = T + 30; SP[43266].cur = 2; SP[43266].recharging = false; WATCH()")   # recharged out of combat (SPELL_UPDATE_CHARGES)
lua("COMBAT = true; T = T + 60")
check("a cast from an earlier pull does not hold a combat-only rule back (exact count recorded out of combat)", ev("READY(C2)") is True and ev("COUNT(C2)") == 2, (ev("READY(C2)"), ev("COUNT(C2)")))

# --- 3. the spell's cooldown on hold ---
lua("SP[43266].hold = true")
check("cooldown on hold: not ready, count unknown", ev("READY(C2)") is False and ev("COUNT(C2)") is None, (ev("READY(C2)"), ev("COUNT(C2)")))
lua("SP[43266].hold = false")

# --- 3b. a lockout: the spell's own cooldown runs while no charge recharges (charges remain) ---
lua("SP[43266].cd = true; SP[43266].recharging = false")
check("lockout (own cooldown, nothing recharging): not ready, count unknown (not 0)", ev("READY(C2)") is False and ev("COUNT(C2)") is None, (ev("READY(C2)"), ev("COUNT(C2)")))
lua("SP[43266].cd = false")

# --- 4. a talent replaces the spell: the one on the bar is read, its casts count ---
lua("COMBAT = false; SPELL(152280, 2); OVR[43265] = 152280; T = T + 1; WATCH()")
lua("COMBAT = true; T = T + 1; CAST(152280); SP[152280].cur = 1; SP[152280].recharging = true")
check("replacement spell read (its charges), its cast counted: 1", ev("COUNT(DND)") == 1 and ev("CD(DND).readID") == 152280, (ev("COUNT(DND)"), ev("CD(DND).readID")))
check("  ...and /xui status says which spell was read", "reading 152280" in str(ev("CD(DND).why")), ev("CD(DND).why"))
lua("OVR[43265] = nil")

# --- 5. 3 charges ---
lua("COMBAT = false; SPELL(500, 3); R3 = RULE(500, 'ready'); NS.rules = { R3 }; T = T + 1; WATCH()")
lua("COMBAT = true; T = T + 1; CAST(500); SP[500].cur = 2; SP[500].recharging = true")
check("3 charges, spell NOT in the Cooldown Manager, recharging: count unknown (no guess); not ready", ev("COUNT(R3)") is None and ev("READY(R3)") is False)
lua("COMBAT = false; T = T + 60; SP[500].cur = 3; SP[500].recharging = false; WATCH(); FR500 = (function() local f = CreateFrame('Frame'); f.cooldownInfo = { spellID = 500 }; function f:GetSpellID() return 500 end; f.xuiChargeGains = {}; return f end)(); ESS = { FR500 }")
lua("T = T + 1; R3.uid = 'x'; COMBAT = true; T = T + 1; CAST(500); T = T + 1; CAST(500); SP[500].cur = 1; SP[500].recharging = true")
check("3 charges in the Cooldown Manager: two casts -> 1", ev("COUNT(R3)") == 1, ev("COUNT(R3)"))
lua("T = T + 9; table.insert(FR500.xuiChargeGains, T); SP[500].cur = 2")
check("  ...a charge gained (Cooldown Manager alert) -> 2", ev("COUNT(R3)") == 2, ev("COUNT(R3)"))
lua("T = T + 1; table.insert(FR500.xuiChargeGains, T); table.insert(FR500.xuiChargeGains, T); SP[500].cur = 2")
check("  ...a count that does not add up (gains reported beyond full) -> unknown, not clamped", ev("COUNT(R3)") is None, ev("COUNT(R3)"))
lua("T = T + 9; SP[500].cur = 3; SP[500].recharging = false")
check("  ...a recharge seen to finish -> full, exact again", ev("COUNT(R3)") == 3 and ev("READY(R3)") is True)

# --- 6. single-charge spells ---
lua("COMBAT = true; SP[600] = nil; S1 = RULE(600, 'ready'); NS.rules = { S1 }")
lua("C_Spell.GetSpellCharges = (function(real) return function(id) if id == 600 then return nil end return real(id) end end)(C_Spell.GetSpellCharges)")
lua("SP[600] = { cd = false, hold = true }")
check("single-charge spell on hold (its cooldown starts later): not ready", ev("READY(S1)") is False, ev("READY(S1)"))
lua("SP[600] = { cd = false, hold = false }")
check("single-charge spell off cooldown: ready, charges condition reads 1", ev("READY(S1)") is True and ev("COUNT(S1)") == 1)

# --- 7. unknown never reads as "has a charge" ---
lua("U = RULE(500, 'hasCharge')")
check("'has a charge' with the count unknown is unknown, not TRUE", ev("NS.CheckCooldownState(U, { known = true, max = 3, atMax = false, empty = nil })") is None)
check("'not ready' with readiness unknown is unknown", ev("NS.CheckCooldownState(RULE(500, 'notReady'), { known = true, max = 3, atMax = nil })") is None)

# --- 8. wiring ---
trig = open(os.path.join(ROOT, "XayaUI", "Triggers.lua"), encoding="utf-8").read()
check("your casts reach the charge counter (Triggers.lua UNIT_SPELLCAST_SUCCEEDED -> ns.NoteChargeCast)", "ns.NoteChargeCast(spellID, now)" in trig)
tim = open(os.path.join(ROOT, "XayaUI", "Timing.lua"), encoding="utf-8").read()
check("the Cooldown Manager's ChargeGained alerts are recorded on its icon (Timing.lua)", re.search(r"CDM_EVENT\.ChargeGained.*?xuiChargeGains", tim, re.S) is not None)

print(); print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED"); sys.exit(1 if fails else 0)
