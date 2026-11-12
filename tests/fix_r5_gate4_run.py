"""Round 5, gate4: the V27 performance gate's three findings in XayaUI_Rules/Conditions.lua and XayaUI_Rules/AuraAlias.lua.

Xaya, 2026-11-10 (V27, REQUEST-LOG A23 SD-28/SD-29, her words): "every single element of the functionality has been built to run
optimally in a high-cost gaming environment. This means zero code loops ... nothing anything that demands cpu or memory resources
beyond what is ABSOLUTELY necessary"; her answer on loops: "No running loops" (nothing loops over all rules on every game event; a
loop runs once, bounded, only when something actually changes).

  1. Conditions.lua, the charge watcher: every SPELL_UPDATE_CHARGES (it fires in the fight) walked all rules twice, made a table per
     rule and read every rule's spell from the game. Now the spells to watch are listed once when the rules change, sorted once into
     the ones with charges, and each event reads only those, without making a table.
  2. AuraAlias.lua: the player's own UNIT_AURA read the spell name of every rule's aura again every 10 seconds. Now the name index is
     built once when the rules change (an edit is picked up at once, not up to 10 seconds later).
Outcomes asserted: the charge count a rule reads in combat (what its icon / text shows) stays right, a rule added or edited is
watched at once, a spell that gains charges is watched, an alias is learned for a rule added a moment ago; and with 300 rules one
event reads only the charge spells (game reads counted), makes no garbage, and does not read 300 spell names.
UNVERIFIED IN GAME: the game is a stand-in (lupa + tests/engine_bench.py); the cost numbers are Lua 5.1 numbers, not in-game timings.
Run: python3 tests/fix_r5_gate4_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.environ.get("XUI_ROOT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
EVENTS = {}
local M = FRAME_METHODS
function M:RegisterEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], self) end
function M:RegisterUnitEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], self) end
function FIRE(e, ...) for _, f in ipairs(EVENTS[e] or {}) do local s = f["_s_OnEvent"]; if s then s(f, e, ...) end end end
C_Timer.After = function() end
COMBAT = false
T = 1000
GetTime = function() return T end
SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
issecretvalue = function(v) return v == SECRET end
InCombatLockdown = function() return COMBAT end
C_Secrets = { ShouldAurasBeSecret = function() return COMBAT end, GetSpellAuraSecrecy = function() return 2 end,
  ShouldSpellAuraBeSecret = function() return COMBAT end }
-- the game, per spell (as tests/charges_combat_run.py): cur, max, recharging (SpellChargeInfo.isActive), cd, hold
SP = {}
function SPELL(id, max) SP[id] = { cur = max, max = max, recharging = false, cd = false, hold = false } end
OVR = {}
C_Spell.GetOverrideSpell = function(id) return OVR[id] or id end
CHARGE_READS = 0
-- REUSE: the stand-in hands back one kept table per spell, so any garbage measured is XayaUI's own (the real game makes a new one)
REUSE, KEPT, KEPTCD = false, {}, {}
C_Spell.GetSpellCharges = function(id)
  CHARGE_READS = CHARGE_READS + 1
  local s = SP[id]; if not s then return nil end
  local t = REUSE and KEPT[id] or {}
  if REUSE then KEPT[id] = t end
  t.currentCharges = COMBAT and SECRET or s.cur; t.maxCharges = s.max; t.isActive = s.recharging
  t.cooldownStartTime = COMBAT and SECRET or 0; t.cooldownDuration = COMBAT and SECRET or 0; t.chargeModRate = 1
  return t
end
C_Spell.GetSpellCooldown = function(id)
  local s = SP[id] or { cd = false, hold = false }
  local t = REUSE and KEPTCD[id] or {}
  if REUSE then KEPTCD[id] = t end
  t.startTime = COMBAT and SECRET or 0; t.duration = COMBAT and SECRET or 0; t.isActive = s.cd; t.isOnGCD = false; t.isEnabled = not s.hold; t.modRate = 1
  return t
end
NAMES = {}
NAME_READS = 0
C_Spell.GetSpellName = function(id) NAME_READS = NAME_READS + 1; if NAMES[id] == false then return nil end return NAMES[id] or ("Spell" .. tostring(id)) end
AURAS = {}
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if COMBAT then return nil end return AURAS[id] end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
C_UnitAuras.GetAuraDataByIndex = function(unit, i) if COMBAT then return SECRET end return nil end
function AURA(id, dur) return { spellId = id, name = NAMES[id] or ("Spell" .. id), duration = dur or 10, expirationTime = T + (dur or 10), applications = 0, auraInstanceID = id * 10, isHelpful = true } end
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{ settingsTestHooks = { keepOld = true } }"); L.globals().NS = ns
for f in ("XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI_Rules/RuleDefaults.lua", "XayaUI_Rules/Conditions.lua", "XayaUI_Rules/Timing.lua",
          "XayaUI_Rules/Triggers.lua", "XayaUI_Rules/Outcomes.lua", "XayaUI_Rules/AuraAlias.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute(r'''
local ns = NS
ns.Print = function() end
ns.Log = function() end
ns.rules = CueRulesDB.rules
function RULE(id, state) return { uid = "r" .. id .. state, name = "R" .. id, enabled = true, useCooldown = true, spellID = id, cdState = state, buffState = "none", load = { mode = "always" } } end
function COUNT(r) local _, info = ns.Evaluate(r, { combat = COMBAT }); return ns.NumRef("n:cdCharges", r, info) end
function READY(r) local _, info = ns.Evaluate(r, { combat = COMBAT }); return info.cdOK end
function CAST(id) ns.NoteChargeCast(id, T) end
function EDIT() ns.configVersion = (ns.configVersion or 0) + 1 end   -- what ns.MarkDirty does to the version (Engine.lua)
-- a 300-rule profile: 296 single-charge cooldown rules on their own spells, 4 charge spells
function PROFILE()
  local list = {}
  for i = 1, 296 do local id = 600000 + i; SPELL(id, 1); list[#list + 1] = RULE(id, "ready") end
  SPELL(43265, 2); DND = RULE(43265, "ready"); list[#list + 1] = DND
  SPELL(43266, 2); C2 = RULE(43266, "hasCharge"); list[#list + 1] = C2
  SPELL(500, 3); R3 = RULE(500, "ready"); list[#list + 1] = R3
  ROWR = { uid = "row", name = "rows", enabled = true, spellID = 0, extra = { list = { { type = "cooldown", spellID = 22001, state = "ready" } } } }
  SPELL(22001, 2); list[#list + 1] = ROWR
  ns.rules = list
  return list
end
''')
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)
def lua(s): return L.execute(s)
def ev(s): return L.eval(s)

# ================================================================ 1. the charge watcher (Conditions.lua)
lua("PROFILE(); FIRE('PLAYER_ENTERING_WORLD')")
check("setup: 300 rules", ev("#NS.rules") == 300)
# one SPELL_UPDATE_CHARGES in the fight: the game is asked only about the 4 charge spells, not the 300 rules' spells
lua("COMBAT = true; T = T + 1; CHARGE_READS = 0; FIRE('SPELL_UPDATE_CHARGES')")
reads = ev("CHARGE_READS")
check("one SPELL_UPDATE_CHARGES with 300 rules reads only the 4 charge spells (was every rule's spell: 300 reads)", reads == 4, reads)
lua("CHARGE_READS = 0; for _ = 1, 30 do FIRE('SPELL_UPDATE_CHARGES') end")
check("30 events: 4 reads each, the list is not built again per event", ev("CHARGE_READS") == 120, ev("CHARGE_READS"))
# no garbage per event (the stand-in hands back kept tables here, so whatever is measured is XayaUI's own)
# Conditions.lua's own SPELL_UPDATE_CHARGES handler (other files' handlers of the event are not this fix's), measured after a warm-up
lua(r'''
REUSE = true
for _, f in ipairs(EVENTS.SPELL_UPDATE_CHARGES or {}) do
  local h = f._s_OnEvent
  if h and debug.getinfo(h, "S").source:find("Conditions.lua", 1, true) then COND_FRAME, COND_H = f, h end
end
function MEASURE(n)
  collectgarbage("collect"); collectgarbage("stop")
  local m0 = collectgarbage("count")
  for _ = 1, n do COND_H(COND_FRAME, "SPELL_UPDATE_CHARGES") end
  local g = (collectgarbage("count") - m0) * 1024
  collectgarbage("restart")
  return g
end
MEASURE(50); GARB = MEASURE(1000); REUSE = false
''')
check("setup: Conditions.lua's charge handler found", ev("COND_H ~= nil"))
garb = ev("GARB")
check("1000 SPELL_UPDATE_CHARGES in combat make no garbage of XayaUI's own (was a table per rule per event: 89 MB over 1000 events here)", garb < 64, "%.0f bytes" % garb)

# what the player reads: Death and Decay (2 charges), a charge used in combat, the recharge not started yet: not full, 1 left
lua("COMBAT = false; T = T + 5; SP[43265].cur = 2; FIRE('PLAYER_REGEN_ENABLED')")
lua("COMBAT = true; FIRE('PLAYER_REGEN_DISABLED'); T = T + 2; CAST(43265); SP[43265].cur = 1; FIRE('SPELL_UPDATE_CHARGES')")
check("in combat, a charge used and its recharge not started: the rule reads not ready (never 'full')", ev("READY(DND)") is False, ev("READY(DND)"))
check("  ...and the count it shows is 1", ev("COUNT(DND)") == 1, ev("COUNT(DND)"))
# the recharge runs, then finishes between engine steps: the watcher sees it on SPELL_UPDATE_CHARGES
lua("T = T + 1; SP[43265].recharging = true; FIRE('SPELL_UPDATE_CHARGES'); T = T + 20; SP[43265].recharging = false; SP[43265].cur = 2; FIRE('SPELL_UPDATE_CHARGES')")
check("a recharge seen to finish on SPELL_UPDATE_CHARGES between engine steps: full again, the rule fires", ev("READY(DND)") is True and ev("COUNT(DND)") == 2,
      (ev("READY(DND)"), ev("COUNT(DND)")))
# the "Cooldown (any spell)" row's spell is watched too (retrospective gap 22)
check("a 'Cooldown (any spell)' row's charge spell is among those read", ev("NS._ChargeState ~= nil") and ev("(function() local n = 0; local o = C_Spell.GetSpellCharges; "
      "local seen; C_Spell.GetSpellCharges = function(id) if id == 22001 then seen = true end; return o(id) end; FIRE('SPELL_UPDATE_CHARGES'); C_Spell.GetSpellCharges = o; return seen == true end)()"))
# a talent override on the bar (read each event, as before)
lua("COMBAT = false; T = T + 1; SPELL(152280, 2); OVR[43265] = 152280; CHARGE_READS = 0")
lua("WHICH = {}; local o = C_Spell.GetSpellCharges; C_Spell.GetSpellCharges = function(id) WHICH[id] = true; return o(id) end; FIRE('SPELL_UPDATE_CHARGES'); C_Spell.GetSpellCharges = o; OVR[43265] = nil")
check("a talent that replaces the spell on the bar: the replacement is read on the next event", ev("WHICH[152280] == true and WHICH[43265] == nil"), ev("WHICH[43265]"))

# a rule edit (ns.MarkDirty bumps ns.configVersion): the new spell is watched at once
lua("SPELL(7700, 2); NS.rules[1].spellID = 7700; EDIT(); WHICH = {}; local o = C_Spell.GetSpellCharges; C_Spell.GetSpellCharges = function(id) WHICH[id] = true; return o(id) end; FIRE('SPELL_UPDATE_CHARGES'); C_Spell.GetSpellCharges = o")
check("a rule edited to a 2-charge spell is watched on the next event", ev("WHICH[7700] == true"))
# a rule switched off: its spell is no longer read
lua("NS.rules[1].enabled = false; EDIT(); WHICH = {}; local o = C_Spell.GetSpellCharges; C_Spell.GetSpellCharges = function(id) WHICH[id] = true; return o(id) end; FIRE('SPELL_UPDATE_CHARGES'); C_Spell.GetSpellCharges = o; NS.rules[1].enabled = true; EDIT()")
check("a rule switched off: its spell is not read any more", ev("WHICH[7700] == nil"))
# a talent change gives a watched rule's spell charges: picked up on the talent / spell event
lua("SP[600005].max = 2; SP[600005].cur = 2; FIRE('TRAIT_CONFIG_UPDATED'); WHICH = {}; local o = C_Spell.GetSpellCharges; C_Spell.GetSpellCharges = function(id) WHICH[id] = true; return o(id) end; FIRE('SPELL_UPDATE_CHARGES'); C_Spell.GetSpellCharges = o")
check("a talent gives a rule's spell a second charge: watched after the talent event", ev("WHICH[600005] == true"))
# a spell that gains a charge in combat with no talent event (a buff, INFERENCE): watched from the engine's first read of it
lua("SP[600006].max = 2; SP[600006].cur = 2; COMBAT = true; local _ = NS.ReadCooldown(NS.rules[6]); WHICH = {}; local o = C_Spell.GetSpellCharges; C_Spell.GetSpellCharges = function(id) WHICH[id] = true; return o(id) end; FIRE('SPELL_UPDATE_CHARGES'); C_Spell.GetSpellCharges = o; COMBAT = false")
check("a spell that gains a charge with no talent event: watched once a rule has read it with charges", ev("WHICH[600006] == true"))

# ================================================================ 2. AuraAlias.lua: the rules' aura names, built once per change
lua(r'''
COMBAT = false
local list = {}
for i = 1, 300 do list[i] = { uid = "b" .. i, name = "B" .. i, enabled = true, useBuff = true, buffID = 300000 + i, buffState = "present", load = { mode = "always" } } end
NS.rules = list
CueRulesDB.auraAlias = {}
FIRE("UNIT_AURA", "player", { addedAuras = { AURA(1, 10) } })   -- the first aura event builds the index (one pass)
''')
lua("T = T + 11; NAME_READS = 0; FIRE('UNIT_AURA', 'player', { addedAuras = { AURA(2, 10) } })")
nr = ev("NAME_READS")
check("UNIT_AURA 11 s later, rules unchanged: no rule aura's name is read again (was all 300 every 10 s)", nr <= 1, nr)
lua("NAME_READS = 0; for i = 1, 20 do T = T + 1; FIRE('UNIT_AURA', 'player', { addedAuras = { AURA(3, 10) } }) end")
check("20 more UNIT_AURA over 20 s: still no rule-name reads", ev("NAME_READS") <= 20, ev("NAME_READS"))
# a rule added a moment ago (an edit): its alias is learned on the very next aura event, not up to 10 s later
lua(r'''
NAMES[62618] = "Power Word: Barrier"; NAMES[81782] = "Power Word: Barrier"
PWB = { uid = "pwb", name = "Barrier", enabled = true, useBuff = true, buffID = 62618, buffState = "present", load = { mode = "always" } }
NS.rules[150] = PWB; EDIT()
T = T + 1
AURAS = { [81782] = AURA(81782, 10) }
FIRE("UNIT_AURA", "player", { addedAuras = { AURA(81782, 10) } })
''')
check("a rule edited a moment ago: the same buff under another ID is learned on the next aura event",
      ev("(function() local a = NS.AuraAliasesOf(62618); return a ~= nil and a[81782] == true end)()"))
# a name the game did not give at the build is asked again later (only that ID, not every rule)
lua(r'''
NAMES[777001] = false; NAMES[777002] = "Darkness"
DK = { uid = "dk", name = "Darkness", enabled = true, useBuff = true, buffID = 777001, buffState = "present", load = { mode = "always" } }
NS.rules[151] = DK; EDIT(); T = T + 1
FIRE("UNIT_AURA", "player", { addedAuras = { AURA(5, 10) } })
NAMES[777001] = "Darkness"; T = T + 11; NAME_READS = 0
AURAS = { [777002] = AURA(777002, 8) }
FIRE("UNIT_AURA", "player", { addedAuras = { AURA(777002, 8) } })
''')
check("a rule aura whose name was not readable at first is learned once the game gives its name", ev("(function() local a = NS.AuraAliasesOf(777001); return a ~= nil and a[777002] == true end)()"))
check("  ...asking the game again for that one name, not for all 300 rules", ev("NAME_READS") <= 2, ev("NAME_READS"))
# in combat nothing is read (unchanged)
lua("COMBAT = true; NAME_READS = 0; EDIT(); FIRE('UNIT_AURA', 'player', SECRET); COMBAT = false")
check("in combat the handler returns at once (no name read, even after an edit)", ev("NAME_READS") == 0)

print()
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
