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
for f in ("XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI_Rules/RuleDefaults.lua", "XayaUI/DebugRecord.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
# (core 0.6.56, REQUEST-LOG #82: the kinds of line, their switches, the probe switch and the record's text are XayaUI Dev Assist's,
# XayaUI_DevAssist/DevRecord.lua; loaded here as the game loads it, after XayaUI. Players without it keep errors and warnings with codes:
# tests/devassist_debug_tools_run.py.)
L.execute("XayaUI_NS = NS")
load(open(os.path.join(ROOT, "XayaUI_DevAssist/DevRecord.lua"), encoding="utf-8").read(), "XayaUI_DevAssist/DevRecord.lua", ns)
L.execute("NS.SettingsOpenAllForTests()")   # (P5) XayaUI Dev Assist's ADDON_LOADED: its store opens
L.execute(r'''
local ns = NS
WINDOW = { open = false, calls = 0 }
ns.ConsoleWindow = function(show) WINDOW.calls = WINDOW.calls + 1; WINDOW.open = show and true or false end
ns.ConsoleWindowOn = function() return WINDOW.open end
SINK = {}
ns.ConsoleSink = function(line) SINK[#SINK + 1] = line end
ns.Fire = function() end
function UI() return NS.SettingsUiRoutedForTests() end   -- (P5) CueRulesDB.ui as before; the record's own settings are Dev Assist's store now
function RECN() local r = CueRulesDB.debugRecord; return r and #r.lines or 0 end
function REC(i) local r = CueRulesDB.debugRecord; return r and r.lines[i or #r.lines] end
-- a line of this kind (shown by its label: "12:00:00  Message  text") that holds this text
function HAS(kind, text) local r = CueRulesDB.debugRecord; if not r then return false end
  local label = NS.DebugRecordInfo.LABEL[kind] or kind
  for _, l in ipairs(r.lines) do if l:find("^%S+  " .. label .. "%s") and l:find(text, 1, true) then return true end end return false end
function NKIND(kind) local r = CueRulesDB.debugRecord; if not r then return 0 end
  local label, n = NS.DebugRecordInfo.LABEL[kind] or kind, 0
  for _, l in ipairs(r.lines) do if l:find("^%S+  " .. label .. "%s") then n = n + 1 end end return n end
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
# (Dev Assist 0.7.5: /xui chat indent and /xui debug chatprobe moved to XayaUI Dev Assist, CoreDebug.lua and ChatProbe.lua)
chatCore, chatProbe, notes, msgs = src("XayaUI_DevAssist/CoreDebug.lua"), src("XayaUI_DevAssist/ChatProbe.lua"), src("XayaUI_Bonus/NotepadShare.lua"), src("XayaUI_Chat/Messages.lua")
check("wiring: /xui chat indent (prints the start of chat lines) is private",
      "local say = ns.PrintPrivate or ns.Print\n            say((\"  line %d: box left" in chatCore and "ns.Print((\"  line %d" not in chatCore)
check("wiring: /xui debug chatprobe top-left frames (frame text can be a character name) are private",
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
      E("HAS('combat', 'combat 1 starts') and HAS('combat', 'combat 1 ends') and HAS('engine', 'Engine draws: 3 displays')"))
check("a line reads 'time  Category  what happened'", E("REC():find('^%d%d:%d%d:%d%d  Engine   Engine draws') ~= nil"), E("tostring(REC())"))

# 5. XayaUI's own Lua errors
L.execute("RESET(); HANDLER('Interface/AddOns/XayaUI_Rules/Engine.lua:12: boom')")
# (core 0.6.56: an error is kept in the coded record, CueRulesDB.errorLog, XUI-E001 for a core file, not as a line of the detailed record)
check("an XayaUI error is recorded (XUI-E001) and shown in the console window (not chat)", E("CueRulesDB.errorLog[1] ~= nil and CueRulesDB.errorLog[1].code == 'XUI-E001' and CueRulesDB.errorLog[1].msg:find('boom', 1, true) ~= nil and #SINK >= 1 and SINK[1]:find('error') ~= nil and #CHAT == 0"))   # (and a console line naming its code, from the record)

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
build = L.eval("function(src) local f, e = loadstring('local ns = ns; local CoreS, PlatS, QolS = ns.Settings(\"core\"), ns.Settings(\"platform\"), ns.Settings(\"qol\")\\n' .. src .. '\\nreturn BuildAddonSettings()', '@Options.lua(BuildAddonSettings)');"
               " if not f then error(e) end; setfenv(f, OPTENV); return f() end")
# (P3 options split, Options 0.6.83) the page's rule rows come from the rule editor (RuleEditor/RuleSettings.lua): its function goes first
rs = open(os.path.join(ROOT, "XayaUI_Rules_Options", "RuleSettings.lua"), encoding="utf-8").read()
rs = rs[rs.index("function ns.OptionsApi.RuleEditor.SettingsRows"):]
L.execute("NS.OptionsApi = NS.OptionsApi or {}; NS.OptionsApi.RuleEditor = NS.OptionsApi.RuleEditor or {}")
dbg = build(rs + "\n" + opt[i:j])["args"]["debug"]["args"]
L.globals().DBG = dbg
# (Options 0.6.55: the probe switch and the detailed record's switches are XayaUI Dev Assist's settings, shown under "Dev Assist settings")
L.execute("""function OPT(k)
  if DBG[k] then return DBG[k] end
  local dp = DBG.devPages and DBG.devPages.args or {}
  for _, page in pairs(dp) do if type(page) == "table" and page.args and page.args[k] then return page.args[k] end end
end
function SET(k, v) OPT(k).set(nil, v) end; function GET(k) return OPT(k).get() end""")
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
check("Settings: unticking 'Keep the detailed record' stops recording", E("UI().recordOff == true and GET('recordOn') == false and not HAS('log', 'should not be kept')"))
L.execute("SET('recordOn', true); NS.RecordLine('log', 'kept again')")
check("Settings: ticking it again records", E("UI().recordOff == nil and GET('recordOn') == true and HAS('log', 'kept again')"))
L.execute("SET('msgDest', 'chat'); RESET(); NS.Print('to chat now')")
check("Settings: 'XayaUI's messages' = Chat window sends messages to chat", E("GET('msgDest') == 'chat' and #CHAT == 1 and #SINK == 0"))
L.execute("SET('advancedDebug', false)")
check("Settings: unticking Advanced Debugging stops the probe it started", E("UI().advancedDebug == false and PROBE.on == false"))

# 9. categories (core 0.6.22, Xaya: "discrete functionality toggles", "cpu friendly"): each kind of line has its own switch
L.execute("NS.Settings('platform').debugRecord = nil; UI().advancedDebug = true; UI().recordOff = nil; UI().recCats = nil; NS.DebugSettingsChanged()")
check("defaults: rules, snapshots, auras, glows, sounds, game, engine, messages on; trigger detail, displays, performance off",
      E("NS.RecCatOn('rules') and NS.RecCatOn('snapshots') and NS.RecCatOn('auras') and NS.RecCatOn('glows') and NS.RecCatOn('sounds') "
        "and NS.RecCatOn('game') and NS.RecCatOn('engine') and NS.RecCatOn('messages') and not NS.RecCatOn('triggers') "
        "and not NS.RecCatOn('displays') and not NS.RecCatOn('perf')"))
L.execute("NS.SetRecCat('messages', false); RESET(); NS.Print('not kept now'); NS.LogKind('rule', 'FIRED kept'); NS.LogKind('snapshot', '#1 snap kept')")
L.execute("SHOWN = function(t) for _, l in ipairs(CHAT) do if l:find(t, 1, true) then return true end end for _, l in ipairs(SINK) do if l:find(t, 1, true) then return true end end return false end")
check("a category switched off: its lines are not kept (the message is still shown)", E("SHOWN('not kept now') and not HAS('msg', 'not kept now')"))
check("  ...other categories still are, each under its own label", E("HAS('rule', 'FIRED kept') and HAS('snapshot', '#1 snap kept')"))
L.execute("NS.SetRecCat('snapshots', false); NS.LogKind('snapshot', '#2 snap gone'); NS.Log('plain log line')")
check("snapshots off: snapshot lines go; a plain console line counts as a rule line", E("not HAS('snapshot', '#2 snap gone') and HAS('log', 'plain log line')"))
check("a setting equal to the default is not stored (the saved settings stay small)", E("UI().recCats.messages == false and UI().recCats.rules == nil"))
L.execute("NS.SetRecCat('messages', true); NS.SetRecCat('snapshots', true)")
check("  ...and switching back to the default removes it", E("UI().recCats == nil"))
L.execute("HANDLER('Interface/AddOns/XayaUI_Rules/Engine.lua:5: always kept'); NS.SetRecPreset('light')")
check("errors are kept whatever the categories (in the coded record)", E("CueRulesDB.errorLog[1].msg:find('always kept', 1, true) ~= nil"))
check("'Light set': rules, game state, messages only", E("NS.RecCatOn('rules') and NS.RecCatOn('game') and NS.RecCatOn('messages') and not NS.RecCatOn('auras') and not NS.RecCatOn('engine')"))
L.execute("NS.SetRecPreset('all')")
check("'Everything': every category", E("NS.RecCatOn('triggers') and NS.RecCatOn('displays') and NS.RecCatOn('perf') and NS.RecCatOn('auras')"))
L.execute("NS.SetRecPreset('default')")
check("'Defaults': back to the defaults, nothing stored", E("UI().recCats == nil and not NS.RecCatOn('perf')"))
L.execute("UI().advancedDebug = false")
check("Advanced Debugging off: every category reads off, but each keeps its own setting for next time",
      E("not NS.RecCatOn('rules') and NS.RecCatSetting('rules') == true and NS.RecCatSetting('perf') == false"))
L.execute("UI().advancedDebug = true")

# 10. size: 1000 / 3000 / 10000 lines
L.execute("NS.Settings('platform').debugRecord = nil; UI().recordMax = 1000; for i = 1, 1300 do NS.LogKind('rule', 'fill ' .. i) end")
check("'Lines kept' 1000: the record keeps about the newest 1000", E("RECN() >= 1000 and RECN() <= 1200 and REC():find('fill 1300') ~= nil"))
L.execute("UI().recordMax = 777")
check("  ...a value that is not one of the choices falls back to 3000", E("NS.DebugRecordInfo.MaxLines() == 3000"))
L.execute("UI().recordMax = nil; NS.Settings('platform').debugRecord = nil")

# 11. game state (category "game"): what the game was doing
L.execute(r"""
GetInstanceInfo = function() return 'Test Dungeon', 'party', 8, 'Mythic Keystone', 5, 0, false, 2810 end
C_Map = { GetBestMapForUnit = function() return 2339 end }
C_Secrets = { ShouldAurasBeSecret = function() return true end, ShouldCooldownsBeSecret = function() return false end }
C_ChallengeMode = { GetActiveKeystoneInfo = function() return 12, {}, true end }
GetNumGroupMembers = function() return 5 end
IsInRaid = function() return false end
GetInventoryItemID = function(_, slot) return slot == 1 and 212345 or nil end
local H = NS.DebugRecordInfo.devHandlers
H.ENCOUNTER_START(3012, 'Test Boss', 8, 5); H.ENCOUNTER_END(3012, 'Test Boss', 8, 5, 0)
H.CHALLENGE_MODE_START(503); H.CHALLENGE_MODE_COMPLETED()
H.GROUP_ROSTER_UPDATE(); H.GROUP_ROSTER_UPDATE()
H.PLAYER_EQUIPMENT_CHANGED(1, true); H.ZONE_CHANGED_NEW_AREA(); H.TRAIT_CONFIG_UPDATED(77)
""")
check("boss encounters: ID, name, difficulty, group size, and kill or wipe",
      E("HAS('game', \"boss encounter 3012 'Test Boss' starts (difficulty 8, 5 players)\") and HAS('game', 'ends: wipe')"))
check("Mythic+: challenge map and keystone level, then completion", E("HAS('game', 'Mythic+ starts: challenge map 503, keystone level 12') and HAS('game', 'Mythic+ completed')"))
check("group size once per change (two updates with the same size: one line)", E("NKIND('game') > 0") and L.eval("(function() local n = 0 for _, l in ipairs(CueRulesDB.debugRecord.lines) do if l:find('group: 5 members', 1, true) then n = n + 1 end end return n end)()") == 1)
check("gear, zone (instance type, difficulty, instance ID, map ID) and talent changes",
      E("HAS('game', 'gear: slot 1 now item 212345') and HAS('game', 'zone: Test Dungeon (party, Mythic Keystone, difficulty 8, instance 2810), map 2339') and HAS('game', 'talents changed')"))
L.execute("FIRE('PLAYER_REGEN_DISABLED')")
check("combat start says where, and what the game hides from addons now", E("HAS('combat', 'starts | Test Dungeon') and HAS('combat', 'the game hides auras: yes, cooldowns: no')"))
L.execute("FIRE('PLAYER_REGEN_ENABLED'); NS.SetRecCat('game', false); local H = NS.DebugRecordInfo.devHandlers; H.ENCOUNTER_START(9999, 'Hidden Boss', 8, 5)")
check("game state off: no game lines", E("not HAS('game', 'Hidden Boss')"))
L.execute("NS.SetRecCat('game', true)")
L.execute("C_AddOns = { GetNumAddOns = function() return 3 end, GetAddOnInfo = function(i) return ({ 'XayaUI', 'XayaUI_Options', 'SomeOtherAddon' })[i] end, "
          "IsAddOnLoaded = function(n) return true, n ~= 'XayaUI_Options' end, DoesAddOnHaveLoadError = function() return false end, "
          "GetAddOnMetadata = function(n) return n == 'XayaUI' and '0.6.22' or '0.6.17' end }; "
          "GetPhysicalScreenSize = function() return 2560, 1440 end; UIParent = { GetEffectiveScale = function() return 0.71 end }; "
          "NS.DebugRecordInfo.devHandlers.PLAYER_ENTERING_WORLD(true, false)")
check("login: game version, every XayaUI addon with its version (and which is not loaded), screen, UI scale, rules",
      E("HAS('session', 'login | game 12.1.5 (build 70783)') and HAS('session', 'XayaUI 0.6.22, XayaUI_Options 0.6.17 (not loaded)') "
        "and HAS('session', 'screen 2560x1440, UI scale 0.710') and not HAS('session', 'SomeOtherAddon')"))

# 12. performance (category "perf"): the engine's timer runs for a combat and its report is recorded
L.execute(r"""
PERF = { calls = {} }
NS.perfOn = false
NS.PerfCommand = function(arg) PERF.calls[#PERF.calls + 1] = arg
  if arg == 'on' then NS.perfOn = true; NS.Print('perf: measuring')
  elseif arg == 'off' then NS.perfOn = false; NS.Print('perf: stopped')
  else NS.Print('perf over 30s: 150 steps, 0.20 ms avg') end end
NS.SetRecCat('perf', true); CHAT = {}; SINK = {}
FIRE('PLAYER_REGEN_DISABLED'); FIRE('PLAYER_REGEN_ENABLED')
""")
check("performance on: the timer starts with the combat and stops after it", E("PERF.calls[1] == 'on' and PERF.calls[2] == '' and PERF.calls[3] == 'off' and NS.perfOn == false"))
check("  ...its report is recorded, and none of its own messages reach the player", E("HAS('perf', 'perf over 30s') and #SINK == 0 and #CHAT == 0"))
L.execute("PERF.calls = {}; NS.perfOn = true; FIRE('PLAYER_REGEN_DISABLED'); FIRE('PLAYER_REGEN_ENABLED')")
check("  ...a timer the player started (/xui debug perf on) is read but never stopped", E("PERF.calls[1] == '' and PERF.calls[2] == nil and NS.perfOn == true"))
L.execute("NS.perfOn = false; NS.SetRecCat('perf', false); PERF.calls = {}; FIRE('PLAYER_REGEN_DISABLED'); FIRE('PLAYER_REGEN_ENABLED')")
check("performance off: the timer is never touched", E("#PERF.calls == 0"))

# 13. actions the game blocked (always kept), trigger / display / sound lines
L.execute("local H = NS.DebugRecordInfo.handlers; H.ADDON_ACTION_BLOCKED('XayaUI', 'CastSpellByID'); H.ADDON_ACTION_FORBIDDEN('SomeOtherAddon', 'Jump')")
check("an action the game blocked for XayaUI is kept; another addon's is not", E("HAS('blocked', \"blocked XayaUI's call to CastSpellByID\") and not HAS('blocked', 'SomeOtherAddon')"))
L.execute("R1 = { uid = 'r1', name = 'Watched' }; R2 = { uid = 'r2', name = 'Other' }; NS.SetRecCat('triggers', true); UI().recFocus = { r1 = true }; NS.DebugSettingsChanged()")
L.execute("NS.WhyNot = function(i) return 'buff=false (aura API)' end")
L.execute("for i = 1, 5 do NS.RecTrigger(R1, false, { buffOK = false, buffSource = 'aura API', cdOK = true }) end; NS.RecTrigger(R2, false, { buffOK = false })")
check("trigger detail: a chosen rule's answer is recorded once per change, with why it does not fire",
      E("NKIND('trigger') == 1 and HAS('trigger', \"'Watched' does not fire: buff=false (aura API)\")"))
check("  ...a rule not chosen is not recorded", E("not HAS('trigger', 'Other')"))
L.execute("NS.RecTrigger(R1, true, { buffOK = true, buffSource = 'aura API | time: duration object', cdOK = true }); "
          "NS.RecTrigger({ uid = 'c1', parentUid = 'r1', isCue = true, name = 'Its cue' }, false, { buffOK = false })")
check("  ...a change is recorded again, and the chosen rule's cues are included", E("HAS('trigger', \"'Watched' fires | aura true via aura API\") and HAS('trigger', \"'Its cue' (cue) does not fire\")"))
L.execute("UI().recFocus = nil; NS.DebugSettingsChanged(); N0 = NKIND('trigger'); NS.RecTrigger(R1, false, { buffOK = false, buffSource = 'x' })")
check("  ...no rule chosen: nothing (and nothing is built)", E("NKIND('trigger') == N0"))
L.execute("NS.SetRecCat('triggers', false); NS.RecDisplay(R1, true, true); NS.SetRecCat('displays', true); NS.RecDisplay(R1, true, true); NS.RecDisplay(R1, false, false)")
check("displays: only with the category on; says who draws it", E("NKIND('display') == 2 and HAS('display', \"'Watched' display shown (drawn by the combat engine)\") and HAS('display', \"'Watched' display hidden\")"))
L.execute("NS.RecSound(R1, 'sound file x.ogg on Master', true); NS.SetRecCat('sounds', false); NS.RecSound(R1, 'sound file y.ogg on Master', true); NS.SetRecCat('sounds', true); NS.SetRecCat('displays', false)")
check("sounds: which sound, channel and the game's raw answer; off: none", E("HAS('sound', \"'Watched': sound file x.ogg on Master | the game returned true\") and not HAS('sound', 'y.ogg')"))

# 14. what to send: the files and where they are, as copyable text
L.execute("IsBetaBuild = function() return false end; IsPublicTestClient = function() return false end")
check("the path of XayaUI.lua, with the account folder marked for the player to fill in",
      E("NS.SavedFilePath('XayaUI.lua') == 'World of Warcraft\\\\_retail_\\\\WTF\\\\Account\\\\<YOUR ACCOUNT FOLDER>\\\\SavedVariables\\\\XayaUI.lua'"), E("NS.SavedFilePath('XayaUI.lua')"))
L.execute("IsPublicTestClient = function() return true end")
check("  ...a test client's own game folder", E("NS.SavedFilePath('XayaUI.lua'):find('\\\\_ptr_\\\\WTF', 1, true) ~= nil and NS.SendText():find('_xptr_', 1, true) ~= nil"))
L.execute("IsPublicTestClient = function() return false end")
check("the steps: /reload first, the folder, the files", E("NS.SendText():find('/reload', 1, true) and NS.SendText():find('XayaUI.lua', 1, true) and NS.SendText():find('<YOUR ACCOUNT FOLDER>', 1, true)") is not None and E("NS.SendText():find('/reload', 1, true) ~= nil"))
check("  ...the developer addon's file is listed only when it says which file it is (through its service)",
      E("NS.SendText():find('XayaUI_DevAssist.lua', 1, true) == nil"))
L.execute("NS.Provide('gameDataProbe', { On = function() end, Off = function() end, Active = function() return false end, savedFile = 'XayaUI_DevTest.lua', savedWhat = 'test captures' })")
check("  ...and then it is", E("NS.SendText():find('XayaUI_DevTest.lua  (test captures)', 1, true) ~= nil"))
L.execute("NS.Settings('platform').debugRecord = nil; NS.LogKind('rule', 'FIRED readable')")
TXT = E("NS.RecordText()")
check("'View the debug record': what each label means, the lines, and what to send",
      "Categories:" in TXT and "Snapshot" in TXT and "FIRED readable" in TXT and "WHAT TO SEND" in TXT and "(off now)" in TXT, TXT[:300])


# 15. the real Settings > Debugging controls for the categories, presets, size, rule picker and "What to send" (Options.lua)
L.execute("UI().advancedDebug = true; UI().recordOff = nil; UI().recCats = nil; UI().msgDest = 'console'; NS.DebugSettingsChanged(); NS.Settings('platform').debugRecord = nil")
# (Options 0.6.55 / Dev Assist 0.7.5: the category boxes, presets, size and rule picker are Dev Assist's settings page "devrecord")
L.execute("W = DBG.devPages.args.devrecord.args; SEND = DBG.send.args")
check("Settings: one tick box per category, each with its cost in the label", E("W.cat_auras ~= nil and W.cat_perf ~= nil and W.cat_triggers ~= nil and W.cat_game ~= nil "
      "and W.cat_auras.name:find('(small)', 1, true) ~= nil and W.cat_perf.name:find('timer', 1, true) ~= nil"))
L.execute("W.cat_messages.set(nil, false); RESET(); NS.Print('settings says no')")
check("Settings: unticking 'XayaUI's messages' stops recording them (they are still shown)",
      E("W.cat_messages.get() == false and SHOWN('settings says no') and not HAS('msg', 'settings says no')"))
L.execute("W.cat_messages.set(nil, true); NS.Print('settings says yes')")
check("Settings: ticking it again records them", E("W.cat_messages.get() == true and HAS('msg', 'settings says yes')"))
L.execute("W.presetLight.func()")
check("Settings: 'Light set' button", E("W.cat_rules.get() and W.cat_game.get() and W.cat_messages.get() and not W.cat_auras.get() and not W.cat_snapshots.get()"))
L.execute("W.presetAll.func()")
check("Settings: 'Everything' button", E("W.cat_perf.get() and W.cat_triggers.get() and W.cat_displays.get()"))
L.execute("W.presetDefault.func()")
check("Settings: 'Defaults' button", E("UI().recCats == nil"))
check("Settings: the rule picker for trigder detail is hidden until 'Trigger detail' is ticked".replace("trigder", "trigger"), E("W.recFocus.hidden() == true"))
L.execute("UIDN = 0; NS.NewUID = function() UIDN = UIDN + 1; return 'gen' .. UIDN end")   # (Outcomes.lua's, not loaded here)
L.execute("W.cat_triggers.set(nil, true); NS.rules = { { uid = 'u1', name = 'First rule' }, { name = 'No uid yet' }, { uid = 'u1c', parentUid = 'u1', isCue = true, name = 'cue' } }")
VALS = L.eval("W.recFocus.values()")
check("Settings: the picker lists rules (not their cues), giving a rule without an ID one", E("W.recFocus.hidden() == false") and
      L.eval("(function() local v = W.recFocus.values(); local n = 0 for k, name in pairs(v) do n = n + 1 end return n == 2 and v.u1 == 'First rule' and NS.rules[2].uid ~= nil and v[NS.rules[2].uid] == 'No uid yet' end)()"))
L.execute("W.recFocus.set(nil, 'u1', true); NS.RecTrigger(NS.rules[1], false, { buffOK = false })")
check("Settings: picking a rule records its trigger detail", E("W.recFocus.get(nil, 'u1') == true and HAS('trigger', \"'First rule' does not fire\")"))
L.execute("W.recFocus.set(nil, 'u1', false)")
check("Settings: unpicking the last rule clears the list", E("UI().recFocus == nil"))
L.execute("W.recordMax.set(nil, 10000)")
check("Settings: 'Lines kept' 10000 is stored; 3000 is the default and stores nothing", E("UI().recordMax == 10000 and W.recordMax.get() == 10000") and
      (L.execute("W.recordMax.set(nil, 3000)") or True) and E("UI().recordMax == nil and W.recordMax.get() == 3000"))
L.execute("IsBetaBuild = function() return false end; IsPublicTestClient = function() return false end")
check("Settings: 'What to send' shows XayaUI.lua's path in a box to copy, and typing in it changes nothing",
      E("SEND.sendCore.get():find('SavedVariables\\\\XayaUI.lua', 1, true) ~= nil") and (L.execute("SEND.sendCore.set(nil, 'typed over')") or True)
      and E("SEND.sendCore.get():find('<YOUR ACCOUNT FOLDER>', 1, true) ~= nil"))
check("Settings: the developer file's box shows only when that addon says its file", E("SEND.sendDev.hidden() == false and SEND.sendDev.get():find('XayaUI_DevTest.lua', 1, true) ~= nil"))
check("Settings: 'What to send' is shown even with Advanced Debugging off (a bug report needs it too)", E("DBG.send.hidden == nil"))

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
