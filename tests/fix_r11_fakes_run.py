#!/usr/bin/env python3
"""Round 11b, the hidden-data fight, step 5 (REQUEST-LOG SD-120, her answer "yes": the unit-test stand-ins throw the errors the game throws
on hidden values, through ONE shared secret object; build spec sections 3.3 and 5, test T8, kept in the private XUI-Docs repo).

The six unit-test fakes the spec names are migrated onto the shared secret object (tests/harness/secret.lua) and the restriction state
machine of tests/harness/world.lua: engine_text_run.py, aura_gaps_run.py, tracked_buff_run.py, fix_r10_sound_run.py, timing_run.py (all on
the engine_bench.py stubs) and char_world.lua (the character window tests' world). This test reads what each of them hands the addon code
under test, and what every other test file still keeps, so a fake cannot come back unseen:

  A  the six: no local secret fake (no own issecretvalue, C_Secrets, ShouldAurasBeSecret, type() override or SECRET token table); no
     combat flag of their own deciding what is hidden (COMBAT = true / false); the five bench tests run the one [bench restrictions] block
     (the shared object and world.lua's state machine, below), byte for byte the copy in this file; char_world.lua loads and installs the
     shared object; each bench test's spell-ID aura read answers nil while the aura is hidden (RequiresNonSecretAura, spec 2.2), never a
     hidden token.
  B  the [bench restrictions] block, played: the installed type / issecretvalue / string.format are the shared object's; C_Secrets,
     InCombatLockdown, UnitAffectingCombat, IsInInstance, GetInstanceInfo, C_ChallengeMode and C_InstanceEncounter answer from world.lua's
     restriction state (auras readable out of combat, hidden in combat and in a key between pulls); world's combat events reach the test's
     own event delivery in the spec 3.3 order, lockdown off while PLAYER_REGEN_DISABLED is handled; the bench's own stubs (frames, C_Spell,
     C_UnitAuras) are untouched.
  C  char_world.lua, played: SECRET is a hidden number of the shared object (type "number", issecretvalue true); arithmetic and tostring on
     it raise secret.lua's errors and each counts as misuse, even under the addon's pcall; '== nil' and '..' are allowed (the game allows
     them) and count nothing.
  D  every test file (tests/*.py, tests/*.lua; not the shared stand-in in tests/harness/): the files that still keep a local secret fake
     are exactly the named list below, each with what it keeps (they are outside this unit's files; routed to their owners). A new fake
     fails, and so does a listed file that no longer has one (the list only shrinks).
  E  no test hands a hidden isActive (SpellCooldownInfo.isActive is readable, spec 2.2), except the one named file (routed).
  F  spec 3.3 "State values": no test fires ADDON_RESTRICTION_STATE_CHANGED with state 2 (the game fires Activating 1 and Inactive 0).
  G  spec 3.3 combat table: tests/fix_r4_lock_run.py labels its lockdown without the event as deliberate.

Fails on the tree before this change (the six local fakes, state 2 sent, no label): A, C, F and G fail as assertions (B plays the block of
this file, so it is the control that the block works). Passes after.
Run: python3 tests/fix_r11_fakes_run.py   (Lua 5.1 via lupa)
     XUI_FAKES_TESTS=<a tests folder> reads another tree's tests (a private pre-change copy, a broken copy); its harness/ is played.
Stand-in only: nothing here is World of Warcraft; every rule it enforces is the spec's (INFERENCE where the spec marks it).
"""
import os, re, sys
from lupa.lua51 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.abspath(os.environ.get("XUI_FAKES_TESTS") or HERE)
HARNESS = os.path.join(TESTS, "harness") + os.sep

checks, fails = [0], []
def check(name, ok, extra=""):
    checks[0] += 1
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra)[:500] + "]"))
    if not ok:
        fails.append(name)

def read(name):
    p = os.path.join(TESTS, name)
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8", errors="replace") as f:
        return f.read()

for need in ("harness/world.lua", "harness/secret.lua", "engine_bench.py"):
    if read(need) is None:
        print("MISSING INPUT: %s (under %s)" % (need, TESTS))
        print("%d checks, %d failed" % (checks[0], 1))
        sys.exit(1)

# ------------------------------------------------------------------------------------------------------------------------------------
# The one copy every bench test runs (spec step 5). Its owner should be engine_bench.py (routed); until then each migrated bench test
# carries it between the markers and section A checks every copy is this one.
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
MARK_A, MARK_B = "-- [bench restrictions]", "-- [/bench restrictions]"
def block_of(text):
    a = text.find(MARK_A)
    b = text.find(MARK_B)
    if a < 0 or b < 0:
        return None
    return text[a:b + len(MARK_B)]
CANON = block_of(BENCH_RESTRICTIONS)

BENCH_SIX = ["engine_text_run.py", "aura_gaps_run.py", "tracked_buff_run.py", "fix_r10_sound_run.py", "timing_run.py"]
CHAR_WORLD = "char_world.lua"

# a local secret fake: its own hidden-value test, secrecy answers, type() override or token table (code lines; comments are skipped)
FAKE = [(re.compile(p), what) for p, what in (
    (r"\bissecretvalue\s*=(?!=)", "its own issecretvalue"),
    (r"\bfunction\s+issecretvalue\b", "its own issecretvalue"),
    (r"\bC_Secrets\s*=(?!=)", "its own C_Secrets"),
    (r"\bC_Secrets\.\w+\s*=(?!=)", "its own C_Secrets answer"),
    (r"\bShouldAurasBeSecret\s*=(?!=)\s*function", "its own ShouldAurasBeSecret"),
    (r"(^|[;\s])type\s*=(?!=)\s*function", "its own type()"),
    (r"\bSECRET\w*\s*=(?!=)\s*setmetatable\(", "a SECRET token table"),
)]
COMBAT_FLAG = re.compile(r"\bCOMBAT\s*=(?!=)\s*(true|false)\b")
HIDDEN_ISACTIVE = re.compile(r"\bisActive\s*=(?!=)\s*(SECRET\w*|SEC\b|[\w.]*S\.new\b|[\w.]*MarkSecret\b)")
STATE2 = re.compile(r"ADDON_RESTRICTION_STATE_CHANGED[\"']\s*,\s*\d+\s*,\s*2\b")

def code_lines(text):
    for i, ln in enumerate(text.splitlines(), 1):
        st = ln.strip()
        if st.startswith("--") or st.startswith("#"):
            continue
        yield i, ln

def fakes_in(text):
    out = []
    for i, ln in code_lines(text):
        for rx, what in FAKE:
            if rx.search(ln):
                out.append("%d: %s (%s)" % (i, ln.strip()[:90], what))
    return out

# ------------------------------------------------------------------------------------------------------------------------------------
# A. the six
print("A. the six fakes the spec names: migrated onto the shared secret object and the state machine")
for name in BENCH_SIX + [CHAR_WORLD]:
    t = read(name)
    if t is None:
        check("A %s exists" % name, False, "missing")
        continue
    f = fakes_in(t)
    check("A %s keeps no local secret fake" % name, not f, "; ".join(f[:4]))
for name in BENCH_SIX:
    t = read(name) or ""
    flags = ["%d: %s" % (i, ln.strip()[:90]) for i, ln in code_lines(t) if COMBAT_FLAG.search(ln)]
    check("A %s has no combat flag of its own deciding what is hidden (it drives world.lua: W.enterCombat ...)" % name, not flags, "; ".join(flags[:4]))
    blk = block_of(t)
    check("A %s runs the one [bench restrictions] block, the same as this file's copy" % name,
          blk is not None and blk == CANON and t.count(MARK_A) == 1 and "L.execute(BENCH_RESTRICTIONS" in t,
          "no block" if blk is None else ("differs from the copy in tests/fix_r11_fakes_run.py" if blk != CANON else "not executed once"))
    # the spell-ID aura read: nil while the aura is hidden, never a hidden token (RequiresNonSecretAura)
    m = re.search(r"C_UnitAuras\.GetUnitAuraBySpellID\s*=\s*function\(.*?\n(.*?)\nend", t, re.S)
    body = m.group(1) if m else ""
    ok = bool(m) and re.search(r"ShouldSpellAuraBeSecret\(id\)\s*then\s*return\s+nil\s+end", body) is not None \
        and re.search(r"return\s+SECRET\b|return\s+[\w.]*S\.new", body) is None
    check("A %s: its GetUnitAuraBySpellID answers nil while the aura is hidden, never a hidden token" % name, ok, body[:200] or "not found")
t = read(CHAR_WORLD) or ""
check("A char_world.lua loads the shared object (harness/secret.lua) and installs it (S.install) for the addon files",
      re.search(r"dofile\(.*harness/secret\.lua", t) is not None and re.search(r"\.install\(_G\)", t) is not None)

# ------------------------------------------------------------------------------------------------------------------------------------
# B. the block, played on the bench
print("B. the [bench restrictions] block, played on the engine_bench.py stubs")
bench = read("engine_bench.py")
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute("BENCH_C_SPELL, BENCH_C_UNITAURAS, BENCH_FRAMES, BENCH_CREATE = C_Spell, C_UnitAuras, FRAME_METHODS, CreateFrame")
okB, errB = True, ""
try:
    L.execute(BENCH_RESTRICTIONS, HARNESS)
except Exception as e:
    okB, errB = False, str(e).splitlines()[0]
check("B the block runs on the bench (world.lua in its own environment)", okB, errB)
if okB:
    r = L.execute(r'''
local o = {}
local h = W.S.new(5)
o.isv = type(issecretvalue) == "function" and issecretvalue(h) == true and type(h) == "number" and canaccessvalue(h) == false
o.fmt = issecretvalue(string.format("%d", h)) == true and issecretvalue(("%d"):format(h)) == true
o.untouched = rawequal(C_Spell, BENCH_C_SPELL) and rawequal(C_UnitAuras, BENCH_C_UNITAURAS) and rawequal(FRAME_METHODS, BENCH_FRAMES)
  and rawequal(CreateFrame, BENCH_CREATE)
o.out = not C_Secrets.ShouldAurasBeSecret() and not C_Secrets.ShouldSpellAuraBeSecret(48707) and not C_Secrets.ShouldCooldownsBeSecret()
  and not InCombatLockdown() and not UnitAffectingCombat("player")
local seen = {}
BENCH_FIRE = function(e, t, st)
  seen[#seen + 1] = e .. (t and ("(" .. t .. "," .. st .. ")") or "") .. (InCombatLockdown() and "L" or "-")
end
W.enterCombat()
o.inc = C_Secrets.ShouldAurasBeSecret() and C_Secrets.ShouldSpellAuraBeSecret(48707) and C_Secrets.ShouldSpellCooldownBeSecret(49998)
  and InCombatLockdown() and UnitAffectingCombat("player") and C_RestrictedActions.IsAddOnRestrictionActive(0)
o.enter = table.concat(seen, " ")
seen = {}
W.leaveCombat()
o.leave = table.concat(seen, " ")
o.after = not C_Secrets.ShouldAurasBeSecret() and not InCombatLockdown()
W.auraSecrecy[48707] = 0
W.enterCombat()
o.never = C_Secrets.ShouldSpellAuraBeSecret(48707) == false and C_Secrets.ShouldAurasBeSecret() == true
W.leaveCombat(); W.auraSecrecy[48707] = nil
BENCH_FIRE = nil
W.enterInstance("party", 8)
o.inst = select(1, IsInInstance()) == true and select(3, GetInstanceInfo()) == 8 and not C_Secrets.ShouldAurasBeSecret()
W.startKey(2648, 12)
o.key = C_ChallengeMode.IsChallengeModeActive() == true and C_Secrets.ShouldAurasBeSecret() == true and not InCombatLockdown()
W.completeKey(); W.leaveInstance()
W.startEncounter(3009, "Boss", 16, 20)
o.enc = C_InstanceEncounter.IsEncounterInProgress() == true and C_Secrets.ShouldAurasBeSecret() == true
W.endEncounter(1)
o.encEnd = not C_Secrets.ShouldAurasBeSecret()
return o
''')
    check("B the installed type / issecretvalue / canaccessvalue are the shared object's (a hidden 5: type number, secret, not accessible)", r["isv"])
    check("B string.format and ('%d'):format of a hidden number give a hidden string (the shared string table is wrapped)", r["fmt"])
    check("B the bench's own stubs are untouched (C_Spell, C_UnitAuras, FRAME_METHODS, CreateFrame)", r["untouched"])
    check("B out of combat: auras and cooldowns readable, no lockdown", r["out"])
    check("B W.enterCombat: auras and cooldowns hidden, lockdown on, the Combat restriction active", r["inc"])
    check("B entering combat, the test's own delivery hears PLAYER_REGEN_DISABLED then (0,1), lockdown off for both (spec 3.3)",
          r["enter"] == "PLAYER_REGEN_DISABLED- ADDON_RESTRICTION_STATE_CHANGED(0,1)-", r["enter"])
    check("B leaving combat: (0,0) then PLAYER_REGEN_ENABLED, lockdown already off (spec 3.3)",
          r["leave"] == "ADDON_RESTRICTION_STATE_CHANGED(0,0)- PLAYER_REGEN_ENABLED-", r["leave"])
    check("B after combat: readable again", r["after"])
    check("B a NeverSecret spell (W.auraSecrecy[id] = 0) stays readable in combat while auras are hidden", r["never"])
    check("B a dungeon out of combat is readable; IsInInstance / GetInstanceInfo answer from world.lua", r["inst"])
    check("B a key between pulls: auras hidden with no lockdown (IsChallengeModeActive true)", r["key"])
    check("B a boss encounter out of combat hides auras (INFERENCE, spec 2.2); its end makes them readable", r["enc"] and r["encEnd"])

# ------------------------------------------------------------------------------------------------------------------------------------
# C. char_world.lua, played
print("C. char_world.lua, played")
L2 = LuaRuntime(unpack_returned_tuples=True)
okC, errC = True, ""
try:
    L2.eval("function(p) assert(loadfile(p))() end")(os.path.join(TESTS, CHAR_WORLD))
except Exception as e:
    okC, errC = False, str(e).splitlines()[0]
check("C char_world.lua loads", okC, errC)
if okC:
    r = L2.execute(r'''
local o = {}
local S = dofile(...)
-- (each item under pcall: a broken or old char_world.lua fails the check, it does not stop the test)
local function try(f) local ok, v = pcall(f); return ok and v == true end
o.shared = try(function() return S.isHidden(SECRET) == true and type(SECRET) == "number" and issecretvalue(SECRET) == true end)
o.fmt = try(function() return issecretvalue(string.format("%d", SECRET)) == true end)
o.arith = try(function()
  misuse = 0
  local okA, eA = pcall(function() return SECRET + 1 end)
  return okA == false and misuse == 1 and tostring(eA):find("attempt to perform arithmetic on a secret number value", 1, true) ~= nil
end)
o.tostr = try(function() misuse = 0; local okT = pcall(tostring, SECRET); return okT == false and misuse == 1 end)
o.allowed = try(function() misuse = 0; return (SECRET == nil) == false and issecretvalue("x" .. SECRET) == true and misuse == 0 end)
return o
''', HARNESS + "secret.lua")
    check("C SECRET is a hidden number of the shared object (type number, issecretvalue true), and format is the shared object's", r["shared"] and r["fmt"])
    check("C arithmetic on SECRET raises secret.lua's error and counts one misuse", r["arith"])
    check("C tostring(SECRET) raises and counts one misuse (an addon's pcall cannot hide it from 'misuse')", r["tostr"])
    check("C '== nil' and '..' on SECRET are allowed (as in the game) and count nothing", r["allowed"])

# ------------------------------------------------------------------------------------------------------------------------------------
# D. every test file: the fakes that remain are the named ones (outside this unit's files; routed to their owners)
print("D. every test file: the local secret fakes that remain")
KNOWN = {
    "engine_bench.py": "the bench's own 'issecretvalue() return false' (the migrated tests replace it with the block; the block's owner)",
    "aura_sources_run.py": "token table + own issecretvalue",
    "auras_cmd_run.py": "string token 'SECRET' + own issecretvalue",
    "cdm_warn_run.py": "own C_Secrets.GetSpellAuraSecrecy",
    "char_gear_icons_run.py": "string token 'SECRET' + own issecretvalue, after char_world.lua",
    "char_stat_map_run.py": "string token 'SECRET_R' + own issecretvalue, after char_world.lua",
    "char_toolkit_world.lua": "char_world.lua's old token table, type() override and issecretvalue (a copy for the toolkit tests)",
    "charges_combat_run.py": "token table + own issecretvalue",
    "class_learn_auras_run.py": "own issecretvalue",
    "count_gcd_run.py": "token table + own issecretvalue",
    "cue_fire_run.py": "'nothing is hidden' issecretvalue",
    "engine_garbage_run.py": "own C_Secrets (always hidden)",
    "externals_in_combat_run.py": "token table, own issecretvalue and C_Secrets on COMBAT",
    "fix_r11_logger_run.py": "own C_Secrets answers (the logger unit's probe of hidden moments)",
    "fix_r11_secret_run.py": "not a fake: a T13 measuring table's field named 'type'",
    "fix_r2_aurasound_static_load_run.py": "'nothing is hidden' issecretvalue",
    "fix_r3_sound_run.py": "'nothing is hidden' issecretvalue",
    "fix_r4_sound_run.py": "'nothing is hidden' issecretvalue",
    "fix_r5_gate4_run.py": "token table, own issecretvalue and C_Secrets on COMBAT",
    "fix_r6_aura_routing_run.py": "own C_Secrets.ShouldAurasBeSecret on W.combat over world.lua's",
    "fix_r6_routing_replay_run.py": "own C_Secrets.ShouldAurasBeSecret / GetSpellAuraSecrecy over world.lua's",
    "fix_r9_rules_misc_run.py": "'nothing is hidden' issecretvalue",
    "fix_u4_aurasound_load_run.py": "'nothing is hidden' issecretvalue",
    "load_alloc_run.py": "token table + own issecretvalue",
    "load_ids_run.py": "token table + own issecretvalue",
    "perf_run.py": "C_Secrets = nil (a client without the namespace)",
    "trigger_parity_run.py": "own C_Secrets.GetSpellAuraSecrecy",
    "usage_check.lua": "own issecretvalue in a mock environment",
}
found = {}
for fn in sorted(os.listdir(TESTS)):
    if not (fn.endswith(".py") or fn.endswith(".lua")) or fn == os.path.basename(__file__):
        continue
    t = read(fn) or ""
    f = fakes_in(t)
    if f:
        found[fn] = f
new = sorted(set(found) - set(KNOWN))
stale = sorted(set(KNOWN) - set(found))
check("D no test file outside the named list keeps a local secret fake (%d named, routed to their owners)" % len(KNOWN), not new,
      "; ".join("%s -> %s" % (n, found[n][0]) for n in new[:6]))
check("D every named file still keeps one (the list only shrinks: drop a file from it once it uses the shared object)", not stale, ", ".join(stale))
for n in sorted(KNOWN):
    if n in found:
        print("    KNOWN (routed) %-38s %s" % (n, KNOWN[n]))

# ------------------------------------------------------------------------------------------------------------------------------------
# E. hidden isActive; F. state 2; G. fix_r4_lock's label
print("E-G. impossible inputs and the combat table")
KNOWN_ISACTIVE = {"fix_r8_engine_alert_run.py": "hands isActive = SEC while hidden9106 (routed)"}
iso = {}
for fn in sorted(os.listdir(TESTS)):
    if not (fn.endswith(".py") or fn.endswith(".lua")) or fn == os.path.basename(__file__):
        continue
    t = read(fn) or ""
    h = ["%d: %s" % (i, ln.strip()[:90]) for i, ln in code_lines(t) if HIDDEN_ISACTIVE.search(ln)]
    if h:
        iso[fn] = h
check("E none of the six hands a hidden isActive (SpellCooldownInfo.isActive is readable, spec 2.2)",
      not any(n in iso for n in BENCH_SIX + [CHAR_WORLD]), {n: iso[n] for n in iso if n in BENCH_SIX + [CHAR_WORLD]})
check("E no other test hands one, except the named file (routed)", set(iso) <= set(KNOWN_ISACTIVE),
      {n: iso[n] for n in iso if n not in KNOWN_ISACTIVE})
st2 = {}
for fn in sorted(os.listdir(TESTS)):
    if not (fn.endswith(".py") or fn.endswith(".lua")) or fn == os.path.basename(__file__):
        continue
    t = read(fn) or ""
    h = ["%d: %s" % (i, ln.strip()[:90]) for i, ln in code_lines(t) if STATE2.search(ln)]
    if h:
        st2[fn] = h
check("F no test fires ADDON_RESTRICTION_STATE_CHANGED with state 2 (the game fires Activating 1 and Inactive 0; spec 3.3)", not st2, st2)
t = read("fix_r4_lock_run.py") or ""
check("G fix_r4_lock_run.py labels its lockdown without PLAYER_REGEN_DISABLED as deliberate (spec 3.3 combat table)",
      re.search(r"W\.combat = true\s+--[^\n]*\n\s*--\s*alone, with no PLAYER_REGEN_DISABLED", t) is not None or
      re.search(r"Deliberate: the lockdown\s*\n?\s*-*\s*alone", t) is not None)

print()
print("UNVERIFIED IN GAME: the stand-in (tests/harness/world.lua, secret.lua) is a mock; the event orders and what is hidden when follow the "
      "build spec (INFERENCE where it says so).")
if fails:
    print("FAILED: " + ", ".join(fails))
print("%d checks, %d failed" % (checks[0], len(fails)))
sys.exit(1 if fails else 0)
