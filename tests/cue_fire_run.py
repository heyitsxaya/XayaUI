"""Core 0.6.14: a cue fires from the rule's triggers unless a switched-on condition decides it (Xaya, 2026-11-04: "make sure core
logic supports that the cues tab fires based on triggers if no additional conditions are specified").

Runs XayaUI's real core files through the real engine step (Engine.lua Step) against stand-in game calls, and checks what the
player gets: which cue sounds are played, when, and how often. Spell / aura IDs are stand-ins.
  - no conditions: every cue follows the trigger (plays once when it turns true, again only after it was false);
  - conditions: a cue a switched-on condition lists waits for that condition; a cue no condition lists follows the trigger;
  - a switched-off condition keeps the cues it lists silent (its On switch says so); take a cue out of its THEN to free it;
  - the rule not loaded, its trigger unknown, or the cue switched off: nothing fires.
Run: python3 tests/cue_fire_run.py   (needs: pip install lupa)"""
import os, sys
import sys as _sys; _sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__))); import xui_paths as XP  # (P4) core = XayaUI + XayaUI_Rules
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
COMBAT = false
InCombatLockdown = function() return false end
UnitAffectingCombat = function() return false end
issecretvalue = function() return false end
C_Secrets = nil
AURAS = {}
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) return AURAS[id] end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return AURAS[id] end
PLAYED = {}
PlaySoundFile = function(f) PLAYED[#PLAYED + 1] = tostring(f); return true end
PlaySound = function(id) PLAYED[#PLAYED + 1] = "kit:" .. tostring(id); return true end
C_Timer.After = function() end
''')
toc = XP.core_toc_lines(ROOT)
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
skip = ("Libs", "Console.lua", "GameMenu", "MinimapButton", "AuraSources", "Combat/")
failed = []
for f in toc:
    f = f.replace("\\", "/")
    if f.startswith(skip) or not f.endswith(".lua"):
        continue
    try:
        load(open(XP.core_file(ROOT, f), encoding="utf-8").read(), f, ns)
    except Exception as e:
        failed.append((f, str(e)[:200]))

fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)

check("core files load", not failed, failed)
L.execute(r'''
local ns = NS
ns.Print = function() end
ns.Log = function() end
ns.rules = {}
CueRulesDB.rules = ns.rules
local function snd(file) return { enabled = true, source = "file", value = file, channel = "Master" } end
function CUE(parent, key, file) return { uid = parent.uid .. key, name = key, isCue = true, parentUid = parent.uid, cueKey = key, cueKind = "sound",
  enabled = true, sound = snd(file), visual = { enabled = false } } end
function COND(parent, name, when, cues) return { uid = parent.uid .. name, name = name, parentUid = parent.uid, enabled = true,
  when = { list = when }, thenCues = cues } end
P = { uid = "P", name = "Proc", enabled = true, useBuff = true, buffID = 5001, buffState = "present", cdState = "none",
  load = { mode = "always" }, sound = snd("parent.ogg"), visual = { enabled = false } }
A = CUE(P, "qa", "A.ogg")
B = CUE(P, "qb", "B.ogg")
ns.rules[1] = P; ns.rules[2] = A; ns.rules[3] = B
for _, r in ipairs(ns.rules) do if ns.NormalizeRule then pcall(ns.NormalizeRule, r) end end
function STEP(n) for i = 1, (n or 1) do NOW = NOW + 0.2; ns.Step() end end
function COUNT(f) local n = 0 for _, x in ipairs(PLAYED) do if x == f then n = n + 1 end end return n end
function RESET() PLAYED = {} end
function AURA(on, stacks) AURAS[5001] = on and { spellId = 5001, auraInstanceID = 51, applications = stacks or 0, expirationTime = 0, duration = 0 } or nil end
''')
cnt = lambda f: L.eval("COUNT('%s')" % f)

# 1. no conditions: both cues follow the trigger
L.execute("AURA(false); STEP(2); RESET(); AURA(true); STEP(3)")
check("no conditions: buff gained -> cue A plays once", cnt("A.ogg") == 1, cnt("A.ogg"))
check("no conditions: buff gained -> cue B plays once", cnt("B.ogg") == 1, cnt("B.ogg"))
L.execute("STEP(5)")
check("no conditions: stays true -> no repeat (Repeat every is 0)", cnt("A.ogg") == 1 and cnt("B.ogg") == 1)
L.execute("AURA(false); STEP(2); AURA(true); STEP(2)")
check("no conditions: lost and gained again -> plays again", cnt("A.ogg") == 2 and cnt("B.ogg") == 2)

# 2. a condition lists A only (stacks >= 3): A waits for it; B follows the trigger
L.execute(r'''
C1 = COND(P, "Condition 1", { { ref = "n:buffStacks", cmp = ">=", num = 3, op = "and" } }, { "qa" })
NS.rules[#NS.rules + 1] = C1
if NS.NormalizeWhen then NS.NormalizeWhen(C1) end
NS.MarkDirty()
AURA(false); STEP(2); RESET(); AURA(true, 1); STEP(3)
''')
check("condition lists A (stacks >= 3), 1 stack: A does not play", cnt("A.ogg") == 0, cnt("A.ogg"))
check("B, which no condition lists, follows the trigger: plays", cnt("B.ogg") == 1, cnt("B.ogg"))
L.execute("AURA(true, 3); STEP(2)")
check("3 stacks: the condition is true -> A plays", cnt("A.ogg") == 1, cnt("A.ogg"))
check("B does not play again (still the same trigger edge)", cnt("B.ogg") == 1)
check("the Cues tab says what decides each cue", "Condition 1" in str(L.eval("NS.CueFiresNote(A)")) and "triggers" in str(L.eval("NS.CueFiresNote(B)")),
      (L.eval("NS.CueFiresNote(A)"), L.eval("NS.CueFiresNote(B)")))

# 3. the condition switched off: the cue it lists stays silent ("An off condition never plays its cues"); B still follows the trigger
L.execute("C1.enabled = false; NS.MarkDirty(); AURA(false); STEP(2); RESET(); AURA(true, 3); STEP(3)")
check("condition switched off: A, which it lists, stays silent (not turned into a play-on-every-trigger cue)", cnt("A.ogg") == 0, cnt("A.ogg"))
check("condition switched off: B, which no condition lists, still follows the trigger", cnt("B.ogg") == 1)
check("the Cues tab says why A is silent", "Silent" in str(L.eval("NS.CueFiresNote(A)")), L.eval("NS.CueFiresNote(A)"))
L.execute("C1.thenCues = nil; NS.MarkDirty(); AURA(false); STEP(2); RESET(); AURA(true, 1); STEP(3)")
check("A taken out of the (off) condition's THEN: A follows the trigger", cnt("A.ogg") == 1, cnt("A.ogg"))
L.execute("C1.thenCues = { 'qa' }; C1.enabled = true; NS.MarkDirty()")

# 4. nothing fires when the rule cannot fire
L.execute("AURA(false); STEP(2); RESET(); P.enabled = false; NS.MarkDirty(); AURA(true, 3); STEP(3)")
check("the rule switched off: no cue plays", cnt("A.ogg") == 0 and cnt("B.ogg") == 0, (cnt("A.ogg"), cnt("B.ogg")))
L.execute("P.enabled = true; B.enabled = false; NS.MarkDirty(); AURA(false); STEP(2); RESET(); AURA(true, 3); STEP(3)")
check("cue B switched off: B silent, A (its condition true) plays", cnt("B.ogg") == 0 and cnt("A.ogg") == 1, (cnt("A.ogg"), cnt("B.ogg")))
L.execute("B.enabled = true; NS.MarkDirty(); AURA(false); STEP(2); RESET()")
L.execute("C_UnitAuras.GetUnitAuraBySpellID = function() error('blocked') end; C_UnitAuras.GetPlayerAuraBySpellID = C_UnitAuras.GetUnitAuraBySpellID; STEP(3)")
check("trigger unknown (aura unreadable): no cue plays", cnt("A.ogg") == 0 and cnt("B.ogg") == 0, (cnt("A.ogg"), cnt("B.ogg")))
L.execute("C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) return AURAS[id] end; C_UnitAuras.GetPlayerAuraBySpellID = function(id) return AURAS[id] end")
L.execute("P.load = { mode = 'all', specs = { ['999'] = true } }; NS.MarkDirty(); AURA(false); STEP(2); RESET(); AURA(true, 3); STEP(3)")
check("the rule not loaded (another spec): no cue plays", cnt("A.ogg") == 0 and cnt("B.ogg") == 0, (cnt("A.ogg"), cnt("B.ogg")))

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
