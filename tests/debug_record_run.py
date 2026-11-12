"""Core 0.6.20: Advanced Debugging and XayaUI's messages in their own frame (Xaya, 2026-11-04: "enabling 'advanced' [should] facilitate
automatic tracking ... (some sort of dump file) ... so a user doesn't have to remember console lines", "the messages should also print to
their own frame either like bug sack or in their own dedicated chat panel").
Since core 0.6.56 (REQUEST-LOG #82) core keeps only XayaUI's errors and warnings with codes (CueRulesDB.errorLog); the detailed record
(11 kinds of line, their switches, the probe switch) was XayaUI Dev Assist's, which lives on qa-installer-branch, not on main (REQUEST-LOG
A23). Runs the real XayaUI/Core.lua, Modules.lua and DebugRecord.lua against stand-in chat and console window, and the real Settings >
Debugging rows of XayaUI_Options/Options.lua (BuildAddonSettings). Checks where each message ends up (chat, the console window, both;
in combat), that a message naming another player is never kept, the coded error record, what to send, and that core alone never
makes the detailed record (CueRulesDB.debugRecord).
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
-- (as the game's Frame:RegisterEvent / UnregisterEvent: a frame is registered for an event once, and can let it go; core 0.6.47
-- registers the record's events only while they are switched on, so they come and go)
function M:RegisterEvent(e) EVENTS[e] = EVENTS[e] or {}; for _, f in ipairs(EVENTS[e]) do if f == self then return true end end; table.insert(EVENTS[e], self); return true end
function M:UnregisterEvent(e) local l = EVENTS[e] or {}; for i = #l, 1, -1 do if l[i] == self then table.remove(l, i) end end; return false end
function FIRE(e, ...) for _, f in ipairs(EVENTS[e] or {}) do local s = f["_s_OnEvent"]; if s then s(f, e, ...) end end end
date = function(fmt) return fmt == "%H:%M:%S" and "12:00:00" or "2026-11-04 12:00:00" end
GetBuildInfo = function() return "12.1.5", "70783" end
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
# (round 7, REQUEST-LOG A23 SD-58) messages into the console window (ns.ConsoleMessage) are XayaUI_Debug's, loaded while Advanced Debugging
# is on; these checks play a session where it is loaded (its first file says so to core). Without it: tests/fix_r7_debug_tools_run.py.
for f in ("XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI_Rules/RuleDefaults.lua", "XayaUI/DebugRecord.lua", "XayaUI_Debug/Tools.lua",
          "XayaUI_Debug/Console.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute("NS.SettingsOpenAllForTests()")   # (P5) every settings store opens, as the addons' ADDON_LOADED would
L.execute(r'''
local ns = NS
WINDOW = { open = false, calls = 0 }
ns.ConsoleWindow = function(show) WINDOW.calls = WINDOW.calls + 1; WINDOW.open = show and true or false end
ns.ConsoleWindowOn = function() return WINDOW.open end
SINK = {}
ns.ConsoleSink = function(line) SINK[#SINK + 1] = line end
ns.Fire = function() end
function UI() return NS.SettingsUiRoutedForTests() end   -- (P5) CueRulesDB.ui as before
-- core alone (no XayaUI Dev Assist on main) never makes the detailed record
function NOREC() return CueRulesDB.debugRecord == nil end
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
check("off: nothing goes to the console window, nothing is recorded", E("#SINK == 0 and NOREC()"))
L.execute("NS.Log('a log line')")
check("off: console lines are not recorded either", E("NOREC()"))

# 2. Advanced Debugging on: its own frame
L.execute("UI().advancedDebug = true; NS.DebugSettingsChanged(); RESET(); NS.Print('engine says hi')")
check("on: messages go to the XayaUI console window by default, not chat", E("#CHAT == 0 and #SINK == 1 and SINK[1]:find('engine says hi') ~= nil"))
check("on: the console window opens when a message arrives", E("WINDOW.open == true"))
L.execute("NS.Log('rule FIRED x')")
check("on, core alone: no detailed record is made (messages and console lines are not kept)", E("NOREC()"))
L.execute("RESET(); COMBAT = true; NS.Print('in combat'); ")
check("in combat: the line is collected but the window does not pop up mid-fight", E("#SINK == 1 and WINDOW.open == false"))
L.execute("COMBAT = false; FIRE('PLAYER_REGEN_ENABLED')")
check("combat ends: the window opens then", E("WINDOW.open == true"))
L.execute("UI().msgDest = 'both'; RESET(); NS.Print('to both')")
check("'Both': chat and the console window", E("#CHAT == 1 and #SINK == 1"))
L.execute("UI().msgDest = 'chat'; RESET(); NS.Print('chat only')")
check("'Chat window' chosen with Advanced Debugging on: chat only", E("#CHAT == 1 and #SINK == 0"))
L.execute("UI().msgDest = nil")

# 3. what is never kept, and collected output
L.execute("RESET(); NS.PrintPrivate('Ignoring Somebody-Realm (Ctrl + right-click)')")
check("a message naming another player is shown", E("#SINK == 1 and SINK[1]:find('Somebody', 1, true) ~= nil"))
L.execute("BUFHAS = function(t) for _, l in ipairs(NS.logBuf or {}) do if l:find(t, 1, true) then return true end end return false end")
check("  ...and is not in the console's line buffer (what the bug report, 'Copy' and a reopened window read)",
      E("NS.logBuf ~= nil and not BUFHAS('Somebody')"))
L.execute("NS.Print('an ordinary line')")
check("  (an ordinary message is in that buffer, so the check above can fail)", E("BUFHAS('an ordinary line')"))
L.execute("UI().msgDest = 'both'; RESET(); NS.PrintPrivate('Saved Otherperson note'); UI().msgDest = nil")
check("  ...'Both': shown in chat and the window, still not in the buffer",
      E("#CHAT == 1 and #SINK == 1 and not BUFHAS('Otherperson')"))
L.execute("OUTP = NS.CaptureOutput(function() NS.PrintPrivate('Thirdperson') end)")
check("  ...and never collected into captured output", E("#OUTP == 0"))
L.execute("OUT = NS.CaptureOutput(function() NS.Print('collected line') end)")
check("collected output is returned to the caller, not shown", E("OUT[1] == 'collected line' and not BUFHAS('collected line')"), E("tostring(OUT[1])"))

# 4. XayaUI's own Lua errors (core 0.6.56: the coded record, CueRulesDB.errorLog; XUI-E001 for a core or Rules file)
L.execute("RESET(); HANDLER('Interface/AddOns/XayaUI_Rules/Engine.lua:12: boom')")
check("an XayaUI error is recorded (XUI-E001) and shown in the console window (not chat)", E("CueRulesDB.errorLog[1] ~= nil and CueRulesDB.errorLog[1].code == 'XUI-E001' and CueRulesDB.errorLog[1].msg:find('boom', 1, true) ~= nil and #SINK >= 1 and SINK[1]:find('error') ~= nil and #CHAT == 0"))   # (and a console line naming its code, from the record)
L.execute("HANDLER('Interface/AddOns/XayaUI_Rules/Engine.lua:5: always kept')")
check("a second XayaUI error is kept too, newest first (in the coded record)", E("CueRulesDB.errorLog[1].msg:find('always kept', 1, true) ~= nil and CueRulesDB.errorLog[2].msg:find('boom', 1, true) ~= nil"))
check("core alone still makes no detailed record", E("NOREC()"))

# 5. the real Settings > Debugging toggles (XayaUI_Options/Options.lua, BuildAddonSettings) drive the behaviour above.
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
build = L.eval("function(src) local f, e = loadstring('local ns = ns; local CoreS, PlatS, QolS = ns.Settings(\"core\"), ns.Settings(\"platform\"), ns.Settings(\"qol\")\\n' .. src .. '\\nreturn BuildAddonSettings()', '@Options.lua(BuildAddonSettings)');"
               " if not f then error(e) end; setfenv(f, OPTENV); return f() end")
# (P3 options split, Options 0.6.83) the page's rule rows come from the rule editor (Rules 0.7.0: XayaUI_Rules/Editor/RuleSettings.lua):
# its function goes first (the file's body is one set-up function, EditorFileInit: only SettingsRows itself is taken)
rs = open(os.path.join(ROOT, "XayaUI_Rules", "Editor", "RuleSettings.lua"), encoding="utf-8").read()
rs_end = "\n    return display, rules\nend\n"
rs = rs[rs.index("function ns.OptionsApi.RuleEditor.SettingsRows"):rs.index(rs_end) + len(rs_end)]
L.execute("NS.OptionsApi = NS.OptionsApi or {}; NS.OptionsApi.RuleEditor = NS.OptionsApi.RuleEditor or {}")
dbg = build(rs + "\n" + opt[i:j])["args"]["debug"]["args"]
L.globals().DBG = dbg
L.execute("""function OPT(k) return DBG[k] end
function SET(k, v) OPT(k).set(nil, v) end; function GET(k) return OPT(k).get() end""")
L.execute("UI().advancedDebug = nil; UI().msgDest = nil; UI().consoleAutoOpen = nil")
L.execute("SET('advancedDebug', true)")
check("Settings: ticking Advanced Debugging switches it on", E("UI().advancedDebug == true and GET('advancedDebug') == true"))
L.execute("RESET(); NS.Print('to the window')")
check("  ...and messages then go to the console window", E("#SINK == 1 and #CHAT == 0"))
L.execute("SET('consoleAutoOpen', false)")
check("Settings: unticking 'Open the console window when a message arrives' is saved", E("UI().consoleAutoOpen == false and GET('consoleAutoOpen') == false"),
      E("tostring(UI().consoleAutoOpen)"))
L.execute("RESET(); UI().msgDest = nil; NS.Print('quiet line')")
check("  ...and a message then collects in the console window without opening it", E("#SINK == 1 and WINDOW.open == false"))
L.execute("SET('consoleAutoOpen', true); RESET(); NS.Print('loud line')")
check("Settings: ticking it again opens the window on the next message", E("UI().consoleAutoOpen == nil and GET('consoleAutoOpen') == true and WINDOW.open == true"))
L.execute("SET('msgDest', 'chat'); RESET(); NS.Print('to chat now')")
check("Settings: 'XayaUI's messages' = Chat window sends messages to chat", E("GET('msgDest') == 'chat' and #CHAT == 1 and #SINK == 0"))
L.execute("SET('advancedDebug', false)")
check("Settings: unticking Advanced Debugging is saved", E("UI().advancedDebug == false and GET('advancedDebug') == false"))
check("Settings: the Debugging page has no detailed-record or probe switch (they were XayaUI Dev Assist's)",
      E("DBG.recordOn == nil and DBG.debugProbe == nil and DBG.recWhat == nil"))
L.execute("UI().msgDest = nil; UI().advancedDebug = true; NS.DebugSettingsChanged()")

# 6. actions the game blocked: a warning (XUI-W001) in the coded record for XayaUI's own; another addon's is not kept
L.execute("CueRulesDB.errorLog = {}; local H = NS.DebugRecordInfo.handlers; H.ADDON_ACTION_BLOCKED('XayaUI', 'CastSpellByID'); H.ADDON_ACTION_FORBIDDEN('SomeOtherAddon', 'Jump')")
check("an action the game blocked for XayaUI is kept (XUI-W001); another addon's is not",
      E("#CueRulesDB.errorLog == 1 and CueRulesDB.errorLog[1].code == 'XUI-W001' and CueRulesDB.errorLog[1].kind == 'warning' "
        "and CueRulesDB.errorLog[1].msg:find(\"XayaUI's call to CastSpellByID\", 1, true) ~= nil"), E("CueRulesDB.errorLog[1] and CueRulesDB.errorLog[1].msg"))

# 7. what to send: the files and where they are, as copyable text
L.execute("IsBetaBuild = function() return false end; IsPublicTestClient = function() return false end")
check("the path of XayaUI.lua, with the account folder marked for the player to fill in",
      E("NS.SavedFilePath('XayaUI.lua') == 'World of Warcraft\\\\_retail_\\\\WTF\\\\Account\\\\<YOUR ACCOUNT FOLDER>\\\\SavedVariables\\\\XayaUI.lua'"), E("NS.SavedFilePath('XayaUI.lua')"))
L.execute("IsPublicTestClient = function() return true end")
check("  ...a test client's own game folder", E("NS.SavedFilePath('XayaUI.lua'):find('\\\\_ptr_\\\\WTF', 1, true) ~= nil and NS.SendText():find('_xptr_', 1, true) ~= nil"))
L.execute("IsPublicTestClient = function() return false end")
check("the steps: /reload first, the folder, the files", E("NS.SendText():find('/reload', 1, true) and NS.SendText():find('XayaUI.lua', 1, true) and NS.SendText():find('<YOUR ACCOUNT FOLDER>', 1, true)") is not None and E("NS.SendText():find('/reload', 1, true) ~= nil"))
check("  ...a developer addon's file is listed only when it says which file it is (through its service)",
      E("NS.SendText():find('XayaUI_DevAssist.lua', 1, true) == nil"))
L.execute("SEND = DBG.send.args")
check("Settings: the developer file's box is hidden while no addon says its file", E("SEND.sendDev.hidden() == true"))
L.execute("NS.Provide('gameDataProbe', { On = function() end, Off = function() end, Active = function() return false end, savedFile = 'XayaUI_DevTest.lua', savedWhat = 'test captures' })")
check("  ...and then it is", E("NS.SendText():find('XayaUI_DevTest.lua  (test captures)', 1, true) ~= nil"))

# 8. the real Settings > Debugging "What to send" (Options.lua)
L.execute("IsBetaBuild = function() return false end; IsPublicTestClient = function() return false end")
check("Settings: 'What to send' shows XayaUI.lua's path in a box to copy, and typing in it changes nothing",
      E("SEND.sendCore.get():find('SavedVariables\\\\XayaUI.lua', 1, true) ~= nil") and (L.execute("SEND.sendCore.set(nil, 'typed over')") or True)
      and E("SEND.sendCore.get():find('<YOUR ACCOUNT FOLDER>', 1, true) ~= nil"))
check("Settings: the developer file's box shows only when that addon says its file", E("SEND.sendDev.hidden() == false and SEND.sendDev.get():find('XayaUI_DevTest.lua', 1, true) ~= nil"))
check("Settings: 'What to send' is shown even with Advanced Debugging off (a bug report needs it too)", E("DBG.send.hidden == nil"))

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
