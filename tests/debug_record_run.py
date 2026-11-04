"""Core 0.6.20: Advanced Debugging records automatically and XayaUI's messages get their own frame (Xaya, 2026-11-04: "enabling
'advanced' [should] facilitate automatic tracking ... (some sort of dump file) ... so a user doesn't have to remember console lines",
"the messages should also print to their own frame either like bug sack or in their own dedicated chat panel").
Runs the real XayaUI/Core.lua and XayaUI/DebugRecord.lua (plus the aura answer recorder in Conditions.lua) against stand-in chat,
console window and probe. Checks where each message ends up, what the saved record holds, and what it never holds.
Run: python3 tests/debug_record_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
CHAT = {}
print = function(s) CHAT[#CHAT + 1] = tostring(s) end
DEFAULT_CHAT_FRAME = { AddMessage = function(self, s) CHAT[#CHAT + 1] = tostring(s) end }
HANDLER = nil
seterrorhandler = function(fn) HANDLER = fn end
geterrorhandler = function() return function() end end
debugstack = function() return "" end
COMBAT = false
InCombatLockdown = function() return COMBAT end
EVENTS = {}
local M = FRAME_METHODS
function M:RegisterEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], self) end
function FIRE(e, ...) for _, f in ipairs(EVENTS[e] or {}) do local s = f["_s_OnEvent"]; if s then s(f, e, ...) end end end
date = function(fmt) return fmt == "%H:%M:%S" and "12:00:00" or "2026-11-04 12:00:00" end
GetBuildInfo = function() return "12.1.5", "70783" end
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
for f in ("XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI/DebugRecord.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute(r'''
local ns = NS
WINDOW = { open = false, calls = 0 }
ns.ConsoleWindow = function(show) WINDOW.calls = WINDOW.calls + 1; WINDOW.open = show and true or false end
ns.ConsoleWindowOn = function() return WINDOW.open end
SINK = {}
ns.ConsoleSink = function(line) SINK[#SINK + 1] = line end
ns.Fire = function() end
function UI() CueRulesDB.ui = CueRulesDB.ui or {}; return CueRulesDB.ui end
function RECN() local r = CueRulesDB.debugRecord; return r and #r.lines or 0 end
function REC(i) local r = CueRulesDB.debugRecord; return r and r.lines[i or #r.lines] end
function HAS(kind, text) local r = CueRulesDB.debugRecord; if not r then return false end
  for _, l in ipairs(r.lines) do if l:find(" " .. kind .. " ", 1, true) and l:find(text, 1, true) then return true end end return false end
function RESET() CHAT = {}; SINK = {}; WINDOW.open = false; WINDOW.calls = 0 end
''')
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)
E = L.eval

# 1. Advanced Debugging off: exactly as before
L.execute("RESET(); NS.Print('hello')")
check("off: a message goes to chat, as before", E("#CHAT == 1 and CHAT[1]:find('hello') ~= nil"))
check("off: nothing goes to the console window, nothing is recorded", E("#SINK == 0 and RECN() == 0"))
L.execute("NS.Log('a log line')")
check("off: console lines are not recorded either", E("RECN() == 0"))

# 2. Advanced Debugging on: its own frame and the record
L.execute("UI().advancedDebug = true; NS.DebugSettingsChanged(); RESET(); NS.Print('engine says hi')")
check("on: messages go to the XayaUI console window by default, not chat", E("#CHAT == 0 and #SINK == 1 and SINK[1]:find('engine says hi') ~= nil"))
check("on: the console window opens when a message arrives", E("WINDOW.open == true"))
check("on: the message is in the saved record", E("HAS('msg', 'engine says hi')"))
L.execute("NS.Log('rule FIRED x')")
check("on: console lines are recorded", E("HAS('log', 'rule FIRED x')"))
L.execute("RESET(); COMBAT = true; NS.Print('in combat'); ")
check("in combat: the line is collected but the window does not pop up mid-fight", E("#SINK == 1 and WINDOW.open == false"))
L.execute("COMBAT = false; FIRE('PLAYER_REGEN_ENABLED')")
check("combat ends: the window opens then", E("WINDOW.open == true"))
L.execute("UI().msgDest = 'both'; RESET(); NS.Print('to both')")
check("'Both': chat and the console window", E("#CHAT == 1 and #SINK == 1"))
L.execute("UI().msgDest = 'chat'; RESET(); NS.Print('chat only')")
check("'Chat window' chosen with Advanced Debugging on: chat only, still recorded", E("#CHAT == 1 and #SINK == 0 and HAS('msg', 'chat only')"))
L.execute("UI().msgDest = nil")

# 3. what is never recorded, and collected output
L.execute("RESET(); NS.PrintPrivate('Ignoring Somebody-Realm (Ctrl + right-click)')")
check("a message naming another player is shown but never recorded", E("#SINK == 1 and not HAS('msg', 'Somebody')"))
L.execute("BUFHAS = function(t) for _, l in ipairs(NS.logBuf or {}) do if l:find(t, 1, true) then return true end end return false end")
check("  ...and is not in the console's line buffer (what the bug report, 'Copy' and a reopened window read)",
      E("NS.logBuf ~= nil and not BUFHAS('Somebody')"))
L.execute("NS.Print('an ordinary line')")
check("  (an ordinary message is in that buffer, so the check above can fail)", E("BUFHAS('an ordinary line')"))
L.execute("UI().msgDest = 'both'; RESET(); NS.PrintPrivate('Saved Otherperson note'); UI().msgDest = nil")
check("  ...'Both': shown in chat and the window, still in neither the record nor the buffer",
      E("#CHAT == 1 and #SINK == 1 and not HAS('msg', 'Otherperson') and not BUFHAS('Otherperson')"))
L.execute("OUTP = NS.CaptureOutput(function() NS.PrintPrivate('Thirdperson') end)")
check("  ...and never collected into recorded output (e.g. the engine status at combat end)", E("#OUTP == 0 and not HAS('engine', 'Thirdperson')"))
L.execute("RESET(); NS.Print('after private')")
check("an ordinary message after a private one is recorded again", E("HAS('msg', 'after private')"))
# every message that can name another player goes through ns.PrintPrivate (wiring; the outcome is checked above)
def src(p): return open(os.path.join(ROOT, p), encoding="utf-8").read()
chatCore, chatProbe, notes, msgs = src("XayaUI_Chat/Core.lua"), src("XayaUI_Chat/Probe.lua"), src("XayaUI_Bonus/NotepadShare.lua"), src("XayaUI_Chat/Messages.lua")
check("wiring: /xui chat indent (prints the start of chat lines) is private",
      "local say = ns.PrintPrivate or ns.Print\n            say((\"  line %d: box left" in chatCore and "ns.Print((\"  line %d" not in chatCore)
check("wiring: /xui chatprobe top-left frames (frame text can be a character name) are private",
      "if shown <= 6 then say(\"  top-left: \"" in chatProbe and "ns.Print(\"  top-left" not in chatProbe)
check("wiring: shared-note messages naming the sender are private",
      "SayPrivate(pos and (\"Saved \" .. ShortName(o.sender)" in notes and "SayPrivate(\"Ignoring shared notes from \" .. ShortName(o.sender)" in notes
      and "Say(pos and (\"Saved \"" not in notes.replace("SayPrivate(", "") and "local p = ns.PrintPrivate or ns.Print" in notes)
check("wiring: the Ctrl + right-click ignore message is private", "local say = ns.PrintPrivate or ns.Print" in msgs and "say(\"Ignoring \" .. name" in msgs)
L.execute("OUT = NS.CaptureOutput(function() NS.Print('collected line') end)")
check("collected output (used for the engine status) is neither shown nor recorded as a message", E("OUT[1] == 'collected line' and not HAS('msg', 'collected line')"))

# 4. combat end adds the combat engine's status
L.execute("NS.AuraDisplay = { Status = function() NS.Print('Engine draws: 3 displays') end }; FIRE('PLAYER_REGEN_DISABLED'); FIRE('PLAYER_REGEN_ENABLED')")
check("each combat is marked, and its end records the engine's status (what /xuiengine prints)",
      E("HAS('combat', 'combat start') and HAS('combat', 'combat end') and HAS('engine', 'Engine draws: 3 displays')"))

# 5. XayaUI's own Lua errors
L.execute("RESET(); HANDLER('Interface/AddOns/XayaUI/Engine.lua:12: boom')")
check("an XayaUI error is recorded and shown in the console window (not chat)", E("HAS('error', 'boom') and #SINK == 1 and SINK[1]:find('error') ~= nil and #CHAT == 0"))

# 6. size limit
L.execute("for i = 1, 3300 do NS.RecordLine('log', 'filler ' .. i) end")
check("the record keeps the newest 3000 lines and counts the dropped ones",
      E("RECN() <= 3200 and RECN() >= 3000 and CueRulesDB.debugRecord.dropped > 0 and REC():find('filler 3300') ~= nil"))
L.execute("NS.ClearRecord()")
check("Clear empties it", E("RECN() == 0"))

# 7. the game-data probe follows Advanced Debugging (when installed), and never stops one the player started
L.execute(r'''
PROBE = { on = false, ons = 0, offs = 0 }
NS.Provide("gameDataProbe", { On = function() PROBE.on = true; PROBE.ons = PROBE.ons + 1 end, Off = function() PROBE.on = false; PROBE.offs = PROBE.offs + 1 end,
  Active = function() return PROBE.on end })
NS.DebugSettingsChanged()
''')
check("probe installed: Advanced Debugging switches it on", E("PROBE.on == true and PROBE.ons == 1"))
L.execute("UI().advancedDebug = false; NS.DebugSettingsChanged()")
check("Advanced Debugging off: the probe it started goes off", E("PROBE.on == false and PROBE.offs == 1"))
L.execute("PROBE.on = true; UI().advancedDebug = true; NS.DebugSettingsChanged(); UI().advancedDebug = false; NS.DebugSettingsChanged()")
check("a probe the player started themselves is left running", E("PROBE.on == true and PROBE.offs == 1"))
L.execute("UI().advancedDebug = true; UI().debugProbe = false; PROBE.on = false; NS.DebugSettingsChanged()")
check("'Also run the game-data probe' unticked: not started", E("PROBE.on == false"))

# 8. the real Settings > Debugging toggles (XayaUI_Options/Options.lua, BuildAddonSettings) drive the behaviour above.
#    Each tick box is switched through its own set / get, then the outcome is checked: unticking must stick (a `(not v) and false or nil`
#    setter always stores nil, so "off" could never be saved).
opt = open(os.path.join(ROOT, "XayaUI_Options", "Options.lua"), encoding="utf-8").read()
i = opt.index("local function BuildAddonSettings()"); j = opt.index("\nend\n", i) + 5
L.execute(r'''
local stub = {}
setmetatable(stub, { __index = function() return stub end, __call = function() return nil end })
OPTNS = setmetatable({}, { __index = function(_, k) local v = NS[k]; if v ~= nil then return v end; return stub end,
  __newindex = function(_, k, v) NS[k] = v end })
OPTENV = setmetatable({ ns = OPTNS }, { __index = function(_, k) local v = _G[k]; if v ~= nil then return v end; return stub end })
''')
build = L.eval("function(src) local f, e = loadstring('local ns = ns\\n' .. src .. '\\nreturn BuildAddonSettings()', '@Options.lua(BuildAddonSettings)');"
               " if not f then error(e) end; setfenv(f, OPTENV); return f() end")
dbg = build(opt[i:j])["args"]["debug"]["args"]
L.globals().DBG = dbg
L.execute("function SET(k, v) DBG[k].set(nil, v) end; function GET(k) return DBG[k].get() end")
L.execute("UI().advancedDebug = nil; UI().debugProbe = nil; UI().probeByDebug = nil; PROBE.on = false; PROBE.ons = 0; PROBE.offs = 0")
L.execute("SET('advancedDebug', true)")
check("Settings: ticking Advanced Debugging switches it on (and the probe with it)", E("UI().advancedDebug == true and PROBE.on == true"))
L.execute("SET('consoleAutoOpen', false)")
check("Settings: unticking 'Open the console window when a message arrives' is saved", E("UI().consoleAutoOpen == false and GET('consoleAutoOpen') == false"),
      E("tostring(UI().consoleAutoOpen)"))
L.execute("RESET(); UI().msgDest = nil; NS.Print('quiet line')")
check("  ...and a message then collects in the console window without opening it", E("#SINK == 1 and WINDOW.open == false"))
L.execute("SET('consoleAutoOpen', true); RESET(); NS.Print('loud line')")
check("Settings: ticking it again opens the window on the next message", E("UI().consoleAutoOpen == nil and GET('consoleAutoOpen') == true and WINDOW.open == true"))
L.execute("SET('debugProbe', false)")
check("Settings: unticking 'Also run the game-data probe' is saved and stops the probe Advanced Debugging started",
      E("UI().debugProbe == false and GET('debugProbe') == false and PROBE.on == false"), E("tostring(UI().debugProbe) .. ' ' .. tostring(PROBE.on)"))
L.execute("SET('debugProbe', true)")
check("Settings: ticking it again starts the probe", E("UI().debugProbe == nil and GET('debugProbe') == true and PROBE.on == true"))
L.execute("SET('recordOn', false); NS.RecordLine('log', 'should not be kept')")
check("Settings: unticking 'Keep the debug record' stops recording", E("UI().recordOff == true and GET('recordOn') == false and not HAS('log', 'should not be kept')"))
L.execute("SET('recordOn', true); NS.RecordLine('log', 'kept again')")
check("Settings: ticking it again records", E("UI().recordOff == nil and GET('recordOn') == true and HAS('log', 'kept again')"))
L.execute("SET('msgDest', 'chat'); RESET(); NS.Print('to chat now')")
check("Settings: 'XayaUI's messages' = Chat window sends messages to chat", E("GET('msgDest') == 'chat' and #CHAT == 1 and #SINK == 0"))
L.execute("SET('advancedDebug', false)")
check("Settings: unticking Advanced Debugging stops the probe it started", E("UI().advancedDebug == false and PROBE.on == false"))
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
