"""Core 0.6.63: rule and status-snapshot log lines are built only while something shows or keeps them (REQUEST-LOG A15 P-9;
Xaya 2026-11-07: "why do I have so much already in it?"). Loads XayaUI's real core files (as tests/engine_bench.py does) with 229
rules, fires combat start / end, steps the engine, and checks what lands in ns.logBuf with no reader, with the console window open,
with the settings window's debug strip shown, and with XayaUI Dev Assist's record keeping that kind.
Negative control: on core 0.6.62 the first two checks FAIL (230 snapshot lines and FIRED lines with nothing reading them).
Run: python3 tests/log_gate_run.py   (needs: pip install lupa)"""
import os, sys
import sys as _sys; _sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__))); import xui_paths as XP  # (P4) core = XayaUI + XayaUI_Rules
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
N = 229
rules = ",\n".join('{ name = "Rule %d", enabled = true, spellID = %d, uid = "u%d" }' % (i, 100000 + i, i) for i in range(1, N + 1))
L.execute("CueRulesDB = { rules = { %s }, folders = {} }" % rules)
L.execute(bench[a:b])
L.execute(r'''
EVENTS = {}
local M = FRAME_METHODS
function M:RegisterEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], self) end
function M:RegisterUnitEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], self) end
function FIRE(e, ...) for _, f in ipairs(EVENTS[e] or {}) do local s = f["_s_OnEvent"]; if s then s(f, e, ...) end end end
''')
toc = XP.core_toc_lines(ROOT)
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
skip = ("Libs", "Console.lua", "GameMenu", "MinimapButton", "AuraSources")
for f in toc:
    f = f.replace("\\", "/")
    if f.startswith(skip) or not f.endswith(".lua"): continue
    load(open(XP.core_file(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute(r'''
local ns = NS
ns.rules = CueRulesDB.rules; ns.folders = CueRulesDB.folders or {}
if ns.NormalizeRule then for _, r in ipairs(ns.rules) do pcall(ns.NormalizeRule, r) end end
ns.Print = function() end
CONSOLE, TRAY, REC = false, false, {}
ns.ConsoleWindowOn = function() return CONSOLE end
ns.LogTrayOn = function() return TRAY end
ns.RecordOn = function(kind) return REC[kind] == true end
ns.RecordLine = function() end
function LINES() return #ns.logBuf end
function CLEAR() for i = #ns.logBuf, 1, -1 do ns.logBuf[i] = nil end end
function HAS(t) for _, l in ipairs(ns.logBuf) do if l:find(t, 1, true) then return true end end return false end
function COMBAT_START() COMBAT = true; FIRE("PLAYER_REGEN_DISABLED") end
function COMBAT_END() COMBAT = false; FIRE("PLAYER_REGEN_ENABLED") end
function STEPS(n) for i = 1, n do NOW = (NOW or 0) + 0.2; ns.Step() end end
-- the rules' answer, set by the test: true = every rule fires, false = every rule clears (the engine logs the change)
FLIP = false
local realEval = ns.Evaluate
ns.Evaluate = function(r, ctx) local ok, res, info = pcall(realEval, r, ctx); info = type(info) == "table" and info or {}; info.ctxOK = true; return FLIP, info end
function FIRE_ALL() FLIP = false; STEPS(2); FLIP = true; STEPS(2) end
''')
fails = []
def check(name, ok):
    print(("ok    " if ok else "FAIL  ") + name)
    if not ok: fails.append(name)
E = lambda s: L.eval(s)

L.execute("CLEAR(); COMBAT_START(); STEPS(10); COMBAT_END()")
check("no reader: combat start / end and engine steps add no rule or snapshot line", E("LINES()") == 0)
L.execute("CLEAR(); FIRE_ALL(); FLIP = false; STEPS(2)")
check("no reader: rules fire and clear, no FIRED or cleared line", not E("HAS('FIRED')") and not E("HAS('cleared')") and E("LINES()") == 0)
L.execute("CLEAR(); CONSOLE = true; COMBAT_START()")
check("console window open: combat start writes the snapshot (header + one line per enabled rule = %d)" % (N + 1), E("LINES()") == N + 1 and E("HAS('status snapshot (combat start)')"))
L.execute("CLEAR(); FIRE_ALL(); FLIP = false; STEPS(2)")
check("console window open: FIRED and cleared lines are logged", E("HAS('FIRED')") and E("HAS('cleared')"))
L.execute("CONSOLE = false; CLEAR(); TRAY = true; COMBAT_END()")
check("settings debug strip shown: the snapshot is written", E("HAS('status snapshot (combat end)')"))
L.execute("TRAY = false; CLEAR(); REC = { snapshot = true }; COMBAT_START()")
check("Dev Assist record keeps snapshots: written", E("HAS('status snapshot (combat start)')"))
L.execute("CLEAR(); REC = { rule = true }; COMBAT_END()")
check("record keeps only rule lines: no snapshot", not E("HAS('status snapshot')"))
L.execute("CLEAR(); FIRE_ALL()")
check("record keeps rule lines: FIRED lines written", E("HAS('FIRED')"))
L.execute("REC = {}; CLEAR(); NS.LogStatusSnapshot('combat tick')")
check("5 s combat tick with no reader: nothing", E("LINES()") == 0)
check("LogWanted is false with no reader, true with any one", E("NS.LogWanted('rule') == false") and (L.execute("CONSOLE = true") or True) and E("NS.LogWanted('snapshot') == true"))

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
