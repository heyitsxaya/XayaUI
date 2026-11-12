#!/usr/bin/env python3
"""Round 7 (bundle 1), the debug tools in their own load-on-demand addon, XayaUI_Debug, read only while Advanced Debugging is on.

Xaya's answers (REQUEST-LOG A23), her words: SD-58, debug tools: "1 but nothing loads unless "Debugging" is enabled" (one load-on-demand
debug folder: the console window, the bug and debug report windows, and later the Rules debug pieces); SD-61, the Debugging default: "Off
by default (Recommended)"; SD-64, a saved "on": "any time a user has debugging on, logging in or reloading should print to the chat pane
"advanced debugging is on. to turn this off ..."" (completed: "Advanced debugging is on. To turn this off, open /xui > Settings >
Debugging."); V34: "if the addon or element within an addon is off it should not be read at all ... and should be detected once per
reload"; V26: the console window, the bug report and the debug report are exempt from the combat lock.

What the player gets, checked with the real addons (XayaUI, XayaUI_Rules, XayaUI_Options and XayaUI_Debug, all switched on in the AddOns
list) in the stand-in game. [new] = fails on the pre-change files (proved on a copy of HEAD 2381c09d, where XayaUI_Debug does not exist):
  F  A fresh install: [new] Advanced Debugging is off; [new] no file of XayaUI_Debug is read (the game never loads it); [new] no "Advanced
     debugging is on" line at the login; [new] /xui console, /xui bug, /xui report, /xui debug status / perf / auras, /xui status and
     /xui auras each print ONE plain line saying they need Advanced Debugging and a /reload, and open no window; [new] (round 7 repair)
     /xui debug loader and /xui debug talents status, which are not on her list for the debug folder and stay in core, still run, in
     combat too, and /xui debug lists them with one line saying what the other debug commands need; [new] the same buttons in
     Settings > Debugging (they call the same entry points) do the same; [new] XayaUI's messages go to chat even with a saved choice of
     the console window; [new] in combat the line comes at once (nothing waits for combat to end); turning Advanced Debugging on during
     the session loads nothing ([new] the line then says a /reload is needed); XayaUI's own errors still reach the game's error handler.
  S  A saved "on" (every install before round 7 saved it): it is kept; [new] XayaUI_Debug is loaded once, at the login; [new] one chat line,
     her words, at the login, in chat even with messages set to the console window; /xui console opens the console window, which shows
     the lines logged before it was built (they wait in core's buffer) and a private line that came while it was closed; /xui bug shows
     the bug report; /xui report shows the debug report window; /xui debug opens the console and lists the commands; in combat
     /xui console, /xui bug, /xui report and /xui debug loader work at once (V26).
  N  [new] (round 7 repair) Options switched off on a fresh install: /xui debug loader still reports why the settings window is missing.
  R  [new] A /reload with it on prints the line again (once); turning it off and reloading: no line, [new] nothing of the debug tools read.
  M  [new] The right-click tracker left core (SD-57 "dev tools"): no XayaUI/MouseTracker.lua in XayaUI.toc, /xui debug mouse does not exist.
Run: python3 tests/fix_r7_debug_tools_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

ON_LINE = "Advanced debugging is on. To turn this off, open /xui > Settings > Debugging."
NEEDS = "needs Advanced Debugging: turn it on in /xui > Settings > Debugging, then type /reload."

LUA = r'''
local W, L, phase, ON_LINE, NEEDS = ...
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function since(n) local t = {}; for i = n + 1, #W.printed do t[#t + 1] = plain(W.printed[i]) end; return t end
local function count(lines, text) local n = 0; for _, l in ipairs(lines) do if l:find(text, 1, true) then n = n + 1 end end; return n end
local function loadedTimes(name) local n = 0; for _, a in ipairs(L.loadedOrder) do if a == name then n = n + 1 end end; return n end
local function shown(name) local f = rawget(_G, name); return (f and f.IsShown and f:IsShown()) and true or false end
L.startup()
local ns = rawget(_G, "XayaUI_NS")
local p0 = #W.printed
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local atLogin = since(p0)
local onLines = count(atLogin, "XayaUI: " .. ON_LINE)

if phase == "fresh" then
  check("[new] F1 a fresh install: Advanced Debugging is off (Settings > Debugging reads it unticked)",
    CueRulesDB.ui.advancedDebug ~= true and ns.AdvancedDebugOn() == false, tostring(CueRulesDB.ui.advancedDebug))
  check("F2 ... no file of XayaUI Debug is read (the game never loads it; F3 is the check that fails on the pre-change files, where this code was core's)", loadedTimes("XayaUI_Debug") == 0 and L.loaded.XayaUI_Debug == nil)
  check("[new] F3 ... none of its code exists (console window, bug report, debug report, typed-command runner)",
    ns.BuildBugReport == nil and ns.DebugReportData == nil and ns.ConsoleRun == nil and ns.DebugReportText == nil)
  check("F4 no 'Advanced debugging is on' line at the login", count(atLogin, "Advanced debugging is on") == 0, table.concat(atLogin, " / "))
  local function one(cmd, label)
    local n = #W.printed
    SlashCmdList.XAYAUI(cmd)
    local got = since(n)
    check("[new] F5 /xui " .. cmd .. ": one plain line, '" .. label .. " " .. NEEDS .. "'",
      #got == 1 and got[1] == "XayaUI: " .. label .. " " .. NEEDS, table.concat(got, " / "))
  end
  one("console", "The console window (/xui console)")
  one("bug", "The bug report (/xui bug)")
  one("report", "The debug report (/xui report)")
  one("debug status", "/xui debug status")
  one("debug perf", "/xui debug perf")
  one("debug auras", "/xui debug auras")
  one("status", "/xui status")
  one("auras", "/xui auras")
  -- (round 7 repair) loader and talents are not on her list for the debug folder (SD-58) and stay in core: they still run, in chat
  local n0 = #W.printed
  SlashCmdList.XAYAUI("debug loader")
  local lo = since(n0)
  check("[new] F5b /xui debug loader still runs with Advanced Debugging off: its report in chat, and no 'needs Advanced Debugging' line",
    count(lo, "XayaUI: debug: ToggleUI=") == 1 and count(lo, "XayaUI: debug: settings window ") == 1 and count(lo, "Advanced Debugging") == 0,
    table.concat(lo, " / "))
  n0 = #W.printed
  SlashCmdList.XAYAUI("debug talents status")
  local ta = since(n0)
  check("[new] F5c /xui debug talents status (read-only) still answers with Advanced Debugging off",
    #ta >= 1 and count(ta, "talent scan") >= 1 and count(ta, "Advanced Debugging") == 0, table.concat(ta, " / "))
  n0 = #W.printed
  SlashCmdList.XAYAUI("debug")
  local li = since(n0)
  check("[new] F5d /xui debug lists what runs now (loader, talents), leaves out the debug folder's words, and says in one line what they need",
    count(li, "debug commands (2)") == 1 and count(li, "/xui debug loader") == 1 and count(li, "/xui debug talents") == 1
      and count(li, "/xui debug status") == 0 and count(li, "/xui debug perf") == 0 and count(li, "/xui debug auras") == 0
      and li[#li] == "XayaUI: Every other debug command " .. NEEDS, table.concat(li, " / "))
  check("[new] F6 ... and no window opened: no console window, no copy box, no debug report window",
    rawget(_G, "XayaUIConsoleWindow") == nil and not shown("XayaUICopyBox") and rawget(_G, "XayaUIDebugReport") == nil)
  -- the Settings > Debugging buttons call these same entry points (XayaUI_Options/Options.lua: bugMake, repOpen, consoleWin)
  local n = #W.printed
  ns.ShowBugReport(); ns.ShowDebugReport(); ns.ConsoleWindow(true, true); ns.ConsoleWindow(false, true)
  local got = since(n)
  check("[new] F7 the Settings > Debugging buttons (bug report, debug report, console window on) say the same, one line each; off says nothing",
    #got == 3 and count(got, NEEDS) == 3 and not ns.ConsoleWindowOn(), table.concat(got, " / "))
  CueRulesDB.ui.msgDest = "console"
  n = #W.printed
  ns.Print("a message while the debug tools are not loaded")
  got = since(n)
  check("[new] F8 a saved choice of the console window: XayaUI's messages still go to chat (the window is not there)",
    count(got, "a message while the debug tools are not loaded") == 1 and ns.MessageDest() == "chat", table.concat(got, " / "))
  check("F9 ... and the saved choice is kept, not deleted", CueRulesDB.ui.msgDest == "console")
  -- in combat: the answer comes at once (V26: exempt), nothing waits for combat to end
  W.enterCombat()
  n = #W.printed
  SlashCmdList.XAYAUI("console"); SlashCmdList.XAYAUI("bug")
  got = since(n)
  check("F10 in combat: /xui console and /xui bug answer at once with the same line (no 'during combat' wait)",
    #got == 2 and count(got, NEEDS) == 2 and count(got, "combat") == 0, table.concat(got, " / "))
  SlashCmdList.XAYAUI("debug loader")
  got = since(n)
  check("[new] F10b in combat with Advanced Debugging off: /xui debug loader answers at once (V26)",
    #got == 4 and count(got, "XayaUI: debug: ToggleUI=") == 1 and count(got, "combat") == 0, table.concat(got, " / "))
  W.combat = false; W.fire("PLAYER_REGEN_ENABLED"); W.tick(0.1, 5)
  got = since(n)
  check("F11 ... and nothing opens after combat", #got == 4 and rawget(_G, "XayaUIConsoleWindow") == nil, table.concat(got, " / "))
  -- an error in a XayaUI file still reaches the game's error handler (Core.lua chains it; caught, never swallowed)
  local errs0 = #W.errors
  pcall(geterrorhandler(), "Interface/AddOns/XayaUI_Rules/Engine.lua:1: a test error while debugging is off")
  check("F12 a XayaUI error still reaches the game's own error handler", #W.errors == errs0 + 1, #W.errors - errs0)
  -- turned on during the session: nothing loads now (V34: detected once per reload); the line says a /reload is needed
  CueRulesDB.ui.advancedDebug = true; ns.DebugSettingsChanged()
  n = #W.printed
  SlashCmdList.XAYAUI("bug")
  got = since(n)
  check("F13 turned on during the session: XayaUI Debug is still not read", loadedTimes("XayaUI_Debug") == 0)
  check("[new] F14 ... and /xui bug says it needs a /reload",
    #got == 1 and got[1] == "XayaUI: The bug report (/xui bug) needs a /reload: the debug tools load at the next login or /reload while Advanced Debugging is on.",
    table.concat(got, " / "))
  CueRulesDB.ui.advancedDebug = nil; CueRulesDB.ui.msgDest = nil; ns.DebugSettingsChanged()
  check("[new] M1 the right-click tracker left core: /xui debug mouse does not exist (no command, no file)",
    ns.MouseTrackerCommand == nil and ns.MouseTrackerOn == nil)
elseif phase == "on" then
  check("S1 a saved 'on' is kept", CueRulesDB.ui.advancedDebug == true and ns.AdvancedDebugOn() == true)
  check("[new] S2 XayaUI Debug is loaded once, at the login", loadedTimes("XayaUI_Debug") == 1 and ns.DebugToolsLoaded() == true, loadedTimes("XayaUI_Debug"))
  check("[new] S3 one chat line at the login, her words: '" .. ON_LINE .. "'", onLines == 1, table.concat(atLogin, " / "))
  -- messages set to the console window: her line still goes to the chat pane (her words: "print to the chat pane")
  check("S4 the console window is closed after a login with it saved closed", not ns.ConsoleWindowOn())
  CueRulesDB.ui.msgDest = "chat"   -- (her setting for the steps below; the console choice is checked again at S7)
  ns.Log("a line logged before the console window was built")
  ns.PrintPrivate("a private line before the window")   -- (private: never kept in the buffer; drawn only while the window exists)
  local n = #W.printed
  SlashCmdList.XAYAUI("console")
  local cw = rawget(_G, "XayaUIConsoleWindow")
  local function lines() local t = {}; for _, l in ipairs(cw and cw.log and cw.log._lines or {}) do t[#t + 1] = plain(type(l) == "table" and l[1] or l) end; return t end
  check("S5 /xui console opens the console window", cw ~= nil and cw:IsShown() and ns.ConsoleWindowOn())
  check("S6 ... which shows the lines logged before it was built (they waited in core's buffer)",
    count(lines(), "a line logged before the console window was built") == 1, table.concat(lines(), " / "):sub(-300))
  ns.ConsoleWindow(false)
  ns.PrintPrivate("a private line while the window is closed")
  CueRulesDB.ui.msgDest = "console"
  ns.Print("a console message while the window is closed")
  CueRulesDB.ui.consoleAutoOpen = false
  check("S7 a message set to the console window opens it (Open the console window when a message arrives: on by default)", ns.ConsoleWindowOn())
  ns.ConsoleWindow(false)
  ns.PrintPrivate("another private line while the window is closed")
  ns.ConsoleWindow(true)
  check("S8 a private line that came while it was closed is drawn when it opens again (core's private queue), once",
    count(lines(), "another private line while the window is closed") == 1, table.concat(lines(), " / "):sub(-300))
  CueRulesDB.ui.msgDest = "chat"; CueRulesDB.ui.consoleAutoOpen = nil
  local boxes = {}
  local S0 = ns.ShowCopyBox
  ns.ShowCopyBox = function(t, x) boxes[#boxes + 1] = { t, x }; return S0(t, x) end
  SlashCmdList.XAYAUI("bug")
  local b = boxes[#boxes]
  check("S9 /xui bug shows the bug report to copy", b and b[1] == "XayaUI bug report" and b[2]:find("^XayaUI bug report\nXayaUI version: ") ~= nil
    and shown("XayaUICopyBox"), b and b[2]:sub(1, 60))
  SlashCmdList.XAYAUI("report")
  local rw = rawget(_G, "XayaUIDebugReport")
  check("S10 /xui report shows the debug report window (summary and the XUIREP1 string)", rw ~= nil and rw:IsShown()
    and (rw.text:GetText() or ""):find("^XayaUI debug report") ~= nil and (rw.str:GetText() or ""):find("^XUIREP1:") ~= nil)
  rw:Hide(); rawget(_G, "XayaUICopyBox"):Hide(); ns.ConsoleWindow(false)
  n = #W.printed
  SlashCmdList.XAYAUI("debug")
  check("S11 /xui debug opens the console window and lists the commands there, not in chat",
    ns.ConsoleWindowOn() and count(lines(), "debug commands (") == 1 and count(since(n), "debug commands (") == 0)
  ns.ConsoleWindow(false)
  -- in combat (V26: exempt)
  W.enterCombat()
  n = #W.printed
  SlashCmdList.XAYAUI("console")
  local cOk = ns.ConsoleWindowOn()
  boxes = {}
  SlashCmdList.XAYAUI("bug")
  SlashCmdList.XAYAUI("report")
  SlashCmdList.XAYAUI("debug loader")
  check("S12 in combat: /xui console, /xui bug, /xui report and /xui debug loader work at once (V26: exempt), with no 'during combat' line",
    cOk and #boxes == 1 and rw:IsShown() and count(lines(), "debug: ToggleUI=") >= 1 and count(since(n), "during combat") == 0,
    table.concat(since(n), " / "))
  W.combat = false; W.fire("PLAYER_REGEN_ENABLED"); W.tick(0.1, 5)
  ns.ShowCopyBox = S0
elseif phase == "noopt" then
  -- (round 7 repair; the reviewer's case) a fresh install with XayaUI Options switched off in the AddOns list: /xui will not open the
  -- settings window, where Advanced Debugging is turned on, so the loader report is the player's only way to see why. It must run.
  local n = #W.printed
  SlashCmdList.XAYAUI("debug loader")
  local got = since(n)
  check("[new] N1 Options switched off, Advanced Debugging off: /xui debug loader says the settings window is not loaded (disabled)",
    ns.AdvancedDebugOn() == false and count(got, "XayaUI: debug: settings window not loaded yet (disabled)") == 1
      and count(got, "Advanced Debugging") == 0, table.concat(got, " / "))
elseif phase == "reload" then
  check("[new] R1 a /reload with Advanced Debugging on: the line again, once", onLines == 1, table.concat(atLogin, " / "))
  check("R2 ... and XayaUI Debug is read again, once", loadedTimes("XayaUI_Debug") == 1)
  CueRulesDB.ui.advancedDebug = false; ns.DebugSettingsChanged()
elseif phase == "off" then
  check("R3 turned off, then /reload: no line", count(atLogin, "Advanced debugging is on") == 0, table.concat(atLogin, " / "))
  check("[new] R4 ... and nothing of the debug tools is read (XayaUI Debug not loaded; no console window or report code exists)",
    loadedTimes("XayaUI_Debug") == 0 and ns.BuildBugReport == nil and ns.ConsoleRun == nil and ns.DebugReportData == nil)
end
local out = L.logout()
return R, out
'''


def session(saved, phase, addons=("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug")):
    folders = H.find_addons()
    enabled = [n for n in folders if n in addons]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    sv = H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    o = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    o["saved"] = sv.Load(saved) if isinstance(saved, str) else H.to_lua(L, saved)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, o)
    res, out = L.eval("function(src, ...) return loadstring(src)(...) end")(LUA, world, loader, phase, ON_LINE, NEEDS)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    errs = [e for e in errs if "a test error while debugging is off" not in str(e)]
    return results, errs, sv.Serialize(out)


def main():
    results, errors = [], []
    toc = open(os.path.join(H.ROOT, "XayaUI", "XayaUI.toc"), encoding="utf-8").read()
    results.append(("[new] M2 the right-click tracker left core: XayaUI.toc lists no MouseTracker.lua, and the file is gone",
                    "MouseTracker.lua" not in toc and not os.path.exists(os.path.join(H.ROOT, "XayaUI", "MouseTracker.lua"))))
    r, e, _ = session({}, "fresh")
    results += r; errors += e
    r, e, _ = session({}, "noopt", ("XayaUI", "XayaUI_Rules", "XayaUI_Debug"))
    results += r; errors += e
    r, e, saved = session({"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"advancedDebug": True, "msgDest": "console"}}}}, "on")
    results += r; errors += e
    r, e, saved = session(saved, "reload")
    results += r; errors += e
    r, e, _ = session(saved, "off")
    results += r; errors += e
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    for x in errors:
        print("ERROR in the game stand-in:", str(x)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errors)))
    sys.exit(1 if bad or errors else 0)


if __name__ == "__main__":
    main()
