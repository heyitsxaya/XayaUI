"""Count the global cooldown (core 0.6.25; Xaya 2026-11-04 backlog, from the cooldown-trigger options): a rule or a "Cooldown (any
spell)" trigger row with countGCD ticked treats its spell as on cooldown while it is on the global cooldown (it cannot be cast);
unticked (default) the global cooldown is ignored, as before. SpellCooldownInfo.isOnGCD: bool? · NeverSecret, Nilable
(docs/reference/api/structures.md:6549). Runs XayaUI's real Core, Conditions, Timing, Triggers and Outcomes against stand-in game
calls (the stand-in reports isActive = true while on the GCD, as the game does: the GCD starts the spell's cooldown display).
The shared cooldown reading is cached per spell for every rule (ns.ReadCooldown): two rules on one spell must still answer apart.
Run: python3 tests/count_gcd_run.py   (needs: pip install lupa)"""
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
function SPELL(id, max) SP[id] = { cur = max, max = max, recharging = false, cd = false, hold = false, gcd = false } end
OVR = {}
C_Spell.GetOverrideSpell = function(id) return OVR[id] or id end
C_Spell.GetSpellCharges = function(id)
  local s = SP[id]; if not s then return nil end
  return { currentCharges = COMBAT and SECRET or s.cur, maxCharges = s.max, isActive = s.recharging,
           cooldownStartTime = COMBAT and SECRET or 0, cooldownDuration = COMBAT and SECRET or 0, chargeModRate = 1 }
end
C_Spell.GetSpellCooldown = function(id)
  local s = SP[id] or { cd = false, hold = false }
  return { startTime = COMBAT and SECRET or (s.start or 0), duration = COMBAT and SECRET or (s.dur or 0), isActive = s.cd or s.gcd, isOnGCD = s.gcd, isEnabled = not s.hold, modRate = 1 }
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

# 1. single-charge spell (made-up 7001), built-in Cooldown section, State "Cooldown ready"
lua("SPELL(7001, 1); A = RULE(7001, 'ready'); B = RULE(7001, 'ready'); B.countGCD = true; NS.rules = { A, B }")
check("off the GCD: both rules ready", ev("READY(A)") is True and ev("READY(B)") is True)
lua("SP[7001].gcd = true")
check("on the GCD, countGCD off (default): ready (the global cooldown is ignored, as before)", ev("READY(A)") is True, ev("READY(A)"))
check("on the GCD, countGCD on: NOT ready", ev("READY(B)") is False, ev("READY(B)"))
check("two rules on the same spell in the same engine step answer apart (the shared reading is not changed)",
      ev("(function() local a = READY(A); local b = READY(B); return a == true and b == false end)()") is True)
lua("B.cdState = 'empty'")
check("on the GCD, countGCD on, State 'On cooldown': true", ev("READY(B)") is True, ev("READY(B)"))
lua("SP[7001].gcd = false")
check("GCD over: 'On cooldown' false again", ev("READY(B)") is False, ev("READY(B)"))
# 2. in combat: isOnGCD is NeverSecret, so the same answers
lua("B.cdState = 'ready'; COMBAT = true; T = T + 5; SP[7001].gcd = true")
check("in combat, on the GCD, countGCD on: NOT ready", ev("READY(B)") is False, ev("READY(B)"))
check("in combat, on the GCD, countGCD off: ready", ev("READY(A)") is True, ev("READY(A)"))
lua("SP[7001].gcd = false; COMBAT = false; T = T + 5")
# 3. two-charge spell (made-up 7002): 'Has a charge' while on the GCD
lua("SPELL(7002, 2); C = RULE(7002, 'hasCharge'); C.countGCD = true; D = RULE(7002, 'hasCharge'); NS.rules = { C, D }; WATCH()")
check("charges full, off the GCD: has a charge", ev("READY(C)") is True)
lua("SP[7002].gcd = true")
check("charges full, on the GCD, countGCD on: no charge available", ev("READY(C)") is False, ev("READY(C)"))
check("charges full, on the GCD, countGCD off: has a charge", ev("READY(D)") is True, ev("READY(D)"))
lua("SP[7002].gcd = false")
# 4. the 'Cooldown (any spell)' trigger row
lua("""ROW = { type = 'cooldown', spellID = 7001, state = 'ready' }
ROWG = { type = 'cooldown', spellID = 7001, state = 'ready', countGCD = true }""")
lua("SP[7001].gcd = true")
check("trigger row, on the GCD, countGCD off: true (ready)", ev("(select(1, NS.CheckTrigger(ROW)))") is True, ev("(select(1, NS.CheckTrigger(ROW)))"))
check("trigger row, on the GCD, countGCD on: false", ev("(select(1, NS.CheckTrigger(ROWG)))") is False, ev("(select(1, NS.CheckTrigger(ROWG)))"))
lua("SP[7001].gcd = false")
check("trigger row, off the GCD, countGCD on: true", ev("(select(1, NS.CheckTrigger(ROWG)))") is True)
# 5. the options: the built-in section and the trigger row both offer it
trig = open(os.path.join(ROOT, "XayaUI", "Triggers.lua"), encoding="utf-8").read()
opts = open(os.path.join(ROOT, "XayaUI_Options", "Options.lua"), encoding="utf-8").read()
check("the 'Cooldown (any spell)' row has a 'Count the global cooldown' tick box", 'key = "countGCD", kind = "toggle", label = "Count the global cooldown"' in trig)
check("the built-in Cooldown section has a 'Count the global cooldown' tick box", 'countGCD = Tog(rule, "countGCD", "Count the global cooldown"' in opts)
# ===== B2: "Seconds left" and "Charges" comparisons on the cooldown trigger itself =====
lua("SPELL(7003, 1); E = RULE(7003, 'empty'); E.cdTimeOp = '<='; E.cdTimeSec = 3; NS.rules = { E }")
lua("SP[7003].cd = true; SP[7003].start = T; SP[7003].dur = 10")
check("on cooldown, 10 s left, 'Seconds left at most 3': false", ev("READY(E)") is False, ev("READY(E)"))
lua("T = T + 8")
check("2 s left: true", ev("READY(E)") is True, ev("READY(E)"))
lua("E.cdTimeOp = '>'; E.cdTimeSec = 5")
check("2 s left, 'More than 5': false", ev("READY(E)") is False)
lua("E.cdTimeOp = 'any'")
check("'Any': the state alone decides (on cooldown: true)", ev("READY(E)") is True)
lua("SP[7003].cd = false; SP[7003].dur = 0")
# charges
lua("SPELL(7004, 3); G = RULE(7004, 'hasCharge'); G.cdChargeOp = '>='; G.cdChargeVal = 2; NS.rules = { G }; WATCH()")
check("3 of 3 charges, 'Charges at least 2': true", ev("READY(G)") is True, ev("READY(G)"))
lua("SP[7004].cur = 1; SP[7004].recharging = true")
check("1 charge, 'at least 2': false (and the state 'has a charge' alone would be true)", ev("READY(G)") is False, ev("READY(G)"))
lua("G.cdChargeOp = '='; G.cdChargeVal = 1")
check("1 charge, 'Exactly 1': true", ev("READY(G)") is True)
# unknown keeps the trigger unknown, never a guess; a false comparison wins over unknown
lua("H = RULE(7003, 'empty'); H.cdTimeOp = '<='; H.cdTimeSec = 3; NS.rules = { H }; COMBAT = true; T = T + 2; SP[7003].cd = true")   # state true (on cooldown), so the comparison decides
check("in combat, cooldown time hidden and no estimate: 'Seconds left' unknown (nil), not a guess",
      ev("(function() local _, info = NS.Evaluate(H, { combat = COMBAT }); return info.cdOK end)()") is None)
lua("COMBAT = false; SP[7003].cd = false; T = T + 30")
# the trigger row
lua("""ROWT = { type = 'cooldown', spellID = 7004, state = 'hasCharge', cdChargeOp = '>=', cdChargeVal = 2 }""")
lua("SP[7004].cur = 1; SP[7004].recharging = true")
check("trigger row, 1 charge, 'Charges at least 2': false", ev("(select(1, NS.CheckTrigger(ROWT)))") is False, ev("(select(1, NS.CheckTrigger(ROWT)))"))
lua("SP[7004].cur = 3; SP[7004].recharging = false")
check("trigger row, 3 charges: true", ev("(select(1, NS.CheckTrigger(ROWT)))") is True)
# the options: shown only with the Cooldown section, cleared by Remove, carried by 'copy section'
opts = open(os.path.join(ROOT, "XayaUI_Options", "Options.lua"), encoding="utf-8").read()
check("the Cooldown section hides countGCD / Seconds left / Charges with the section",
      '"cdState", "countGCD", "cdTimeOp", "cdChargeOp", "maxCharges"' in opts)
check("Remove clears countGCD and the comparisons", "rule.countGCD, rule.cdTimeOp, rule.cdTimeSec, rule.cdChargeOp, rule.cdChargeVal = nil, nil, nil, nil, nil" in opts)
check("copying the Cooldown section carries them", "dst.cdTimeOp, dst.cdTimeSec, dst.cdChargeOp, dst.cdChargeVal = src.cdTimeOp, src.cdTimeSec, src.cdChargeOp, src.cdChargeVal" in opts
      and "dst.cdState, dst.countGCD = src.cdState, src.countGCD" in opts)
print(); print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED"); sys.exit(1 if fails else 0)
