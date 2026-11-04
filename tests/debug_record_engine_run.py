"""Core 0.6.22: the debug record's lines that come from the engine itself (Xaya, 2026-11-04: Advanced Debugging "user-readable and
cpu friendly (perhaps discrete functionality toggles ...)", "configurable to cover every single thing you need to properly debug
something from game-side").

Runs XayaUI's real core files through the real engine step (Engine.lua Step) against stand-in game calls, with Advanced Debugging on,
and checks what lands in the record: rules firing and clearing, snapshots, sounds (which sound, channel, the game's answer), trigger
detail for a chosen rule (once per change), displays shown and hidden, and that an aura whose answer did not change costs no string work.
Spell / aura IDs are stand-ins. Run: python3 tests/debug_record_engine_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
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
date = function(fmt) return fmt == "%H:%M:%S" and "12:00:00" or "2026-11-04 12:00:00" end
''')
toc = [l.strip() for l in open(os.path.join(ROOT, "XayaUI", "XayaUI.toc")) if l.strip() and not l.startswith("#")]
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
skip = ("Libs", "Console.lua", "GameMenu", "MinimapButton", "AuraSources", "Combat/")
failed = []
for f in toc:
    f = f.replace("\\", "/")
    if f.startswith(skip) or not f.endswith(".lua"):
        continue
    try:
        load(open(os.path.join(ROOT, "XayaUI", f), encoding="utf-8").read(), f, ns)
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
ns.Print = function() end           -- (messages are not what this test is about)
CueRulesDB.ui = { advancedDebug = true }
ns.rules = {}
CueRulesDB.rules = ns.rules
local function snd(file) return { enabled = true, source = "file", value = file, channel = "Master" } end
P = { uid = "P", name = "Proc", enabled = true, useBuff = true, buffID = 5001, buffState = "present", cdState = "none",
  load = { mode = "always" }, sound = snd("parent.ogg"), visual = { enabled = false } }
Q = { uid = "Q", name = "Other", enabled = true, useBuff = true, buffID = 5002, buffState = "present", cdState = "none",
  load = { mode = "always" }, sound = snd("other.ogg"), visual = { enabled = false } }
ns.rules[1] = P; ns.rules[2] = Q
for _, r in ipairs(ns.rules) do if ns.NormalizeRule then pcall(ns.NormalizeRule, r) end end
ns.DebugSettingsChanged()
function STEP(n) for i = 1, (n or 1) do NOW = NOW + 0.2; ns.Step() end end
function AURA(id, on) AURAS[id] = on and { spellId = id, auraInstanceID = id * 10, applications = 0, expirationTime = 0, duration = 0 } or nil end
function LINES(label, text) local n = 0; local r = CueRulesDB.debugRecord; if not r then return 0 end
  for _, l in ipairs(r.lines) do if l:find("^%S+  " .. label .. "%s") and (not text or l:find(text, 1, true)) then n = n + 1 end end return n end
function CLEAR() NS.ClearRecord() end
''')
E = L.eval

# 1. rules firing and clearing, with the sound each played
L.execute("AURA(5001, false); STEP(3); CLEAR(); AURA(5001, true); STEP(3)")
check("a rule fires: one 'Rule' line", E("LINES('Rule', 'FIRED Proc') == 1"), E("LINES('Rule')"))
check("  ...and its sound: which file, channel, and what the game answered", E("LINES('Sound', \"'Proc': sound file parent.ogg on Master | the game returned true\") == 1"),
      E("CueRulesDB.debugRecord and table.concat(CueRulesDB.debugRecord.lines, ' // ') or 'none'"))
L.execute("AURA(5001, false); STEP(2)")
check("it clears: one 'Rule' line with why", E("LINES('Rule', 'cleared Proc: buff=false') == 1"))
L.execute("NS.SetRecCat('rules', false); NS.SetRecCat('sounds', false); NS.DebugSettingsChanged(); CLEAR(); AURA(5001, true); STEP(2)")
check("rules and sounds switched off: no such lines (the sound still plays)", E("LINES('Rule') == 0 and LINES('Sound') == 0 and PLAYED[#PLAYED] == 'parent.ogg'"))
L.execute("NS.SetRecCat('rules', true); NS.SetRecCat('sounds', true); NS.DebugSettingsChanged(); AURA(5001, false); STEP(2)")

# 2. snapshots are their own category
L.execute("CLEAR(); NS.LogStatusSnapshot('combat start')")
check("a status snapshot is recorded as 'Snapshot' lines (header and one per rule)", E("LINES('Snapshot', 'status snapshot (combat start)') == 1 and LINES('Snapshot', 'Proc result=') == 1"))
L.execute("NS.SetRecCat('snapshots', false); CLEAR(); NS.LogStatusSnapshot('combat start')")
check("  ...switched off: none (the console still gets them)", E("LINES('Snapshot') == 0 and #NS.logBuf > 0"))
L.execute("NS.SetRecCat('snapshots', true)")

# 3. trigger detail for a chosen rule: once per change, nothing for the others
L.execute("NS.SetRecCat('triggers', true); CueRulesDB.ui.recFocus = { P = true }; NS.DebugSettingsChanged(); CLEAR(); STEP(5)")
check("trigger detail: the chosen rule's answer is written once, not on every step", E("LINES('Trigger', \"'Proc' does not fire\") == 1"), E("LINES('Trigger')"))
L.execute("AURA(5001, true); STEP(5)")
check("  ...and again when it changes, saying where the aura answer came from", E("LINES('Trigger', \"'Proc' fires | aura true via\") == 1"))
check("  ...a rule not chosen gets no trigger lines", E("LINES('Trigger', 'Other') == 0"))
L.execute("CueRulesDB.ui.recFocus = nil; NS.DebugSettingsChanged(); CLEAR(); AURA(5001, false); STEP(3)")
check("  ...no rule chosen: none", E("LINES('Trigger') == 0"))

# 4. CPU: an aura whose answer did not change does no string work in the record's aura hook
L.execute(r'''
PATN = 0
local realMatch = string.match
string.match = function(s, pat, ...) if pat == "^([^%(:|]+)" then PATN = PATN + 1 end return realMatch(s, pat, ...) end
CLEAR(); AURA(5001, true); STEP(1); PATN = 0; STEP(20)
''')
check("CPU: 20 steps with the same aura answers: the aura hook builds no text (0 pattern matches)", E("PATN") == 0, E("PATN"))
L.execute("AURA(5001, false); STEP(1)")
check("  ...a changed answer is worked out and written (1 line)", E("PATN") >= 1 and E("LINES('Aura', '(5001): missing')") == 1)
L.execute("CueRulesDB.ui.advancedDebug = false; NS.DebugSettingsChanged(); CLEAR(); PATN = 0; AURA(5001, true); STEP(10); AURA(5001, false); STEP(10)")
check("CPU: Advanced Debugging off: the hook builds no text and nothing is recorded", E("PATN") == 0 and E("CueRulesDB.debugRecord == nil"))
L.execute("string.match = string.match; CueRulesDB.ui.advancedDebug = true; NS.DebugSettingsChanged()")

# 5. displays shown and hidden (the engine reports a change only)
L.execute(r'''
NS.SetRecCat('displays', true)
CALLS = {}
local real = NS.RecDisplay
NS.RecDisplay = function(rule, shown, byEngine) CALLS[#CALLS + 1] = tostring(rule.name) .. ":" .. tostring(shown); return real(rule, shown, byEngine) end
P.visual = { enabled = true, trigger = "condition" }
AURA(5001, false); STEP(3); CLEAR(); CALLS = {}
AURA(5001, true); STEP(4); AURA(5001, false); STEP(4)
''')
check("displays: one report when it appears and one when it goes, not one per step", E("#CALLS") == 2 and E("CALLS[1]") == "Proc:true" and E("CALLS[2]") == "Proc:false",
      E("table.concat(CALLS, ', ')"))
check("  ...written as readable lines", E("LINES('Display', \"'Proc' display shown\") == 1 and LINES('Display', \"'Proc' display hidden\") == 1"))
check("  ...a display that starts hidden is not reported as a change", E("LINES('Display', 'Other') == 0"))

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
