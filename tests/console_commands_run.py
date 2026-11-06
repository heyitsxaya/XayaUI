#!/usr/bin/env python3
"""The console window's command line and /xui debug (core 0.6.50).
Xaya, 2026-11-05: "XUI Console does nothing and has no input options" (screenshot: an empty console window, four buttons, nothing to
type in), and of the /xui help list: "can't some of these be consolidated into a /xui debug _____ ? this is a LOT of noise" (29 lines).
What the player sees, checked here with the real addons in the stand-in game:
  1. /xui help lists the player's commands (17 lines with the Shopping List's /xui shop): /xui debug, and the two shortcuts /xui status and /xui auras (Xaya 2026-11-06),
     no other diagnostic command; pipes in it are doubled ("||", shown as "|"; she chose "Back to '|'" over "[on/off]").
  2. /xui debug lists every diagnostic command as "/xui debug <name>"; each listed name runs; an unknown one says so and lists them;
     the loader check is /xui debug loader (was window: "Rename it" -> "/xui debug loader").
  3. The old forms (/xui chatprobe, /xui perf, /xui stats widthprobe ...) no longer run (Xaya 2026-11-06: "let's move to /xui debug
     ____", "7. Retire"): each prints /xui help instead. A feature's debug command whose addon is off says so as "/xui debug <name>".
  4. The console window has a command line inside it, under the log, clear of the resize grip. With XayaUI's messages set to the
     chat window (Xaya's case), a command typed there prints in the console window and not in chat; the typed line is echoed;
     "/xui ..." and "/xayaui ..." work typed in full; another addon's slash command is refused, not run; afterwards messages go
     to chat again; a command that errors shows the error in the window and leaves nothing switched on.
  5. An empty console window says what to type and where XayaUI's other messages go; the first line hides that; Clear shows it again.
  6. Only what is sent to the console shows there (Xaya 2026-11-06: "Only xui console messages should display"): with messages set
     to the chat window, a message, a private message and an error notice stay out of the open console window and its buffer; set
     to the console window, they show there. /save typed in the console reloads the interface (Xaya 2026-11-06: "Yes, but /save
     should trigger a reload"); /reload too ("Both work"); other slash commands stay refused.
  7. Any /xui debug command, typed in the normal chat box too, opens the console window and prints there, not in chat ("Debug cmds
     open console"); the shortcuts /xui status and /xui auras print in chat whatever the message setting ("/xui auras prints to chat
     instead", status "Yes, same as auras"); a shortcut typed in the console window prints there.
Negative control: on core 0.6.48 (no command line, /xui debug was a one-line loader check, help listed 29 commands) checks in
1, 2, 3, 4 and 5 fail; on 8ae717b (old forms still ran) the checks in 3 fail; on 2e8b00a (chat messages copied into the open
console, no /save) the checks in 6 fail; on 0fa76ef (before her answers of 2026-11-06 ~04:30 UTC) 16 checks of 1 (shortcuts,
pipes), 2 (loader), 6 (/reload) and 7 fail.
Run: python3 tests/console_commands_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function run(s) return ns.CaptureOutput(function() SlashCmdList.XAYAUI(s) end) end

-- 1. /xui help --------------------------------------------------------------------------------------------------------------------
local help = run("help")
local cmds, pipe = {}, nil
for i = 2, #help do
  local p = plain(help[i])
  local c = p:match("^  (/xui%s%S+)") or p:match("^  (/xui)%s")
  if c then cmds[#cmds + 1] = c end
  if p:gsub("||", ""):find("|", 1, true) then pipe = p end
end
check("help: a header with the count, then that many lines", help[1] == ("commands (%d):"):format(#help - 1), help[1])
-- (QoL 0.7.32 adds the Shopping List's /xui shop, a player command: 16 + 1)
check("help: 17 lines (it was 29; 16 plus the Shopping List's /xui shop)", #help - 1 == 17, #help - 1)
check("help: /xui shop is listed", (function() for _, c in ipairs(cmds) do if c == "/xui shop" then return true end end end)() == true, table.concat(cmds, " "))
local diag = { "status", "probe", "debuffs", "perf", "timing", "seed", "talents", "model", "tracker", "loc", "media", "gamemenu",
  "auras", "chatprobe", "mods", "groups", "icons" }
local SHORT = { status = true, auras = true }
local leaked
for _, c in ipairs(cmds) do for _, d in ipairs(diag) do if c == "/xui " .. d and not SHORT[d] then leaked = c end end end
for i = 2, #help do if plain(help[i]):find("widthprobe", 1, true) then leaked = plain(help[i]) end end
check("help: no diagnostic command is listed but the two shortcuts", leaked == nil, leaked)
local helpText = plain(table.concat(help, "\n"))
check("help: the shortcut /xui status is listed, printing in chat", helpText:find("/xui status  every rule's answer right now, and why; in chat", 1, true) ~= nil, helpText)
check("help: the shortcut /xui auras is listed, printing in chat", helpText:find("/xui auras [target||focus||pet] [debuffs] or <spellID>  aura IDs, and whether XayaUI can follow them in combat; in chat", 1, true) ~= nil, helpText)
local has = {}
for _, c in ipairs(cmds) do has[c] = true end
check("help: /xui debug is listed, with what it does", has["/xui debug"] and table.concat(help, "\n"):find("diagnostic commands", 1, true) ~= nil)
for _, c in ipairs({ "/xui", "/xui console", "/xui bug", "/xui unlock", "/xui chat", "/xui stats", "/xui cursor", "/xui notes" }) do
  check("help: still lists " .. c, has[c] == true)
end
check("help: every '|' doubled (shown as one), none left single", pipe == nil, pipe)
check("help: option lists read [on|off] again (no [on/off])", helpText:find("[highlight||trail]", 1, true) ~= nil and helpText:find("[on||off||options||status]", 1, true) ~= nil
  and not helpText:find("on/off", 1, true), helpText)

-- 2. /xui debug -------------------------------------------------------------------------------------------------------------------
local dbg = run("debug")
local names, badLine = {}, nil
for i = 2, #dbg do
  local p = plain(dbg[i])
  local n = p:match("^  /xui debug (%S+)")
  if n then names[n] = true else badLine = p end
end
check("debug: a header with the count", dbg[1] ~= nil and dbg[1]:match("^debug commands %((%d+)%)") ~= nil
  and tonumber(dbg[1]:match("%((%d+)%)")) == #dbg - 1, dbg[1])
check("debug: every line is '/xui debug <name> ...'", badLine == nil, badLine)
local missing = {}
for _, d in ipairs(diag) do if not names[d] then missing[#missing + 1] = d end end
for _, d in ipairs({ "loader", "widthprobe", "map" }) do if not names[d] then missing[#missing + 1] = d end end
check("debug: lists every diagnostic command (core and the features')", #missing == 0, table.concat(missing, ", "))
local dpipe
for i = 1, #dbg do if plain(dbg[i]):gsub("||", ""):find("|", 1, true) then dpipe = dbg[i] end end
check("debug: every '|' doubled, none left single", dpipe == nil, dpipe)
check("debug: option lists read [target|focus] again", plain(table.concat(dbg, "\n")):find("debuffs [target||focus] [spellID]", 1, true) ~= nil)
-- each listed name runs (the stand-in game answers what it can; no Lua error, never "no debug command")
local errs0 = #W.errors
local notRun = {}
for n in pairs(names) do
  if n ~= "seed" then
    local out = run("debug " .. n)
    if #out > 0 and out[1]:find("there is no debug command", 1, true) then notRun[#notRun + 1] = n end
  end
end
check("debug: every listed name runs", #notRun == 0, table.concat(notRun, ", "))
check("debug: running them all made no Lua error", #W.errors == errs0, W.errors[#W.errors])
local unk = run("debug nosuch")
check("debug: an unknown name says so, then lists them", unk[1] == 'there is no debug command "nosuch".' and unk[2] ~= nil
  and unk[2]:match("^debug commands %(") ~= nil, unk[1])
local win = run("debug loader")
check("debug loader: the old /xui debug loader check", win[1] ~= nil and win[1]:find("debug: ToggleUI=", 1, true) ~= nil, win[1])
check("debug window (its old name) is gone", (run("debug window")[1] or "") == 'there is no debug command "window".')

-- 3. the old forms no longer run: each prints /xui help ------------------------------------------------------------------------
local helpLines = #help
for _, old in ipairs({ "perf", "loc", "gamemenu", "chatprobe", "probe 203720", "mods", "seed", "stats widthprobe" }) do
  local before = ns.rules and #ns.rules or 0
  local probeCalls, realProbe = 0, ns.CharWidthProbe_Run
  if realProbe then ns.CharWidthProbe_Run = function(...) probeCalls = probeCalls + 1 end end
  local out = run(old)
  ns.CharWidthProbe_Run = realProbe
  local isHelp = out[1] == help[1] and #out == helpLines
  -- (a /xui stats word it does not know toggles the panel, as before; it must not start the width probe)
  if old == "stats widthprobe" then isHelp = realProbe ~= nil and probeCalls == 0 end
  check(("old form /xui %s no longer runs (prints /xui help)"):format(old), isHelp and (ns.rules and #ns.rules or 0) == before, out[1])
end
check("/xui debug status still runs", (function() local o = run("debug status"); return o[1] ~= nil and o[1] ~= help[1] end)())
-- a feature's debug command whose addon is off: worded as /xui debug <name> (Modules.lua ns.ModuleMissingText(cmd, true))
local realState = ns.ModuleState
ns.ModuleState = function(a) if a == "XayaUI_Chat" then return "disabled" end return realState(a) end
local realRun = ns.RunDebugCommand
ns.RunDebugCommand = function(c, a) if c == "chatprobe" then return false end return realRun(c, a) end
local off = run("debug chatprobe")
ns.ModuleState, ns.RunDebugCommand = realState, realRun
check("/xui debug chatprobe with XayaUI Chat off says so, as /xui debug chatprobe", off[1] ~= nil
  and off[1]:find("/xui debug chatprobe is part of XayaUI Chat, which is switched off", 1, true) ~= nil, off[1])
local offTop = run("chatprobe")
check("/xui chatprobe (old form) is not reported as 'never registered'", offTop[1] == help[1], offTop[1])

-- 4. the console window's command line --------------------------------------------------------------------------------------------
CueRulesDB.ui.msgDest = "chat"   -- Xaya's case: XayaUI's messages go to the chat window
if ns.ConsoleWindow then ns.ConsoleWindow(true) end
local cw = rawget(_G, "XayaUIConsoleWindow")
check("the console window opens", cw ~= nil and cw:IsShown())
if not cw then return R end
local cmd = rawget(cw, "cmd")
check("the console window has a command line (an edit box)", cmd ~= nil and cmd._kind == "EditBox", cmd and cmd._kind)
if not cmd then return R end
local wr, er, lr = W.rect(cw), W.rect(cmd), W.rect(cw.log)
check("command line: inside the window, along the bottom", er.l >= wr.l + 10 - 0.01 and er.b >= wr.b + 10 - 0.01 and er.l + er.w <= wr.l + wr.w - 10 + 0.01,
  ("window %g,%g %gx%g; line %g,%g %gx%g"):format(wr.l, wr.b, wr.w, wr.h, er.l, er.b, er.w, er.h))
check("command line: under the log, a gutter between (no overlap)", er.b + er.h + 10 <= lr.b + 0.01, ("line top %g, log bottom %g"):format(er.b + er.h, lr.b))
check("command line: clear of the resize grip in the corner", er.l + er.w <= wr.l + wr.w - 18 - 0.01, er.l + er.w)
check("command line: tall enough for a line of chat font (20 px)", er.h >= 20, er.h)
local hint = rawget(cmd, "hint")
check("command line: an empty, unfocused line says what to type", hint ~= nil and hint:IsShown() and (hint._text or ""):find("Enter", 1, true) ~= nil)

-- 5 (part). the empty window
local empty = rawget(cw, "empty")
cw.log._lines = {}
if ns.logBuf then for k in pairs(ns.logBuf) do ns.logBuf[k] = nil end end
-- (Clear, as the button does)
local clearBtn
for _, k in ipairs({ cw:GetChildren() }) do if k._kind == "Button" and k._text == "Clear" then clearBtn = k end end
check("the Clear button is there", clearBtn ~= nil)
if clearBtn then clearBtn:GetScript("OnClick")(clearBtn) end
check("empty window: a hint says what to type", empty ~= nil and empty:IsShown() and (empty._text or ""):find("Type a XayaUI command", 1, true) ~= nil,
  empty and empty._text)
check("empty window: the hint says XayaUI's other messages go to the chat window", empty ~= nil and (empty._text or ""):find("go to the chat window", 1, true) ~= nil,
  empty and empty._text)

local history, histSpy = {}, nil
histSpy = function(self, t) history[#history + 1] = t end
rawset(cmd, "AddHistoryLine", histSpy)
local function type_(s)
  cmd:SetText(s)
  cmd:GetScript("OnEnterPressed")(cmd)
end
local function lines() local out = {}; for _, l in ipairs(cw.log._lines or {}) do out[#out + 1] = plain(l) end; return out end
local function has_(list, s) for _, l in ipairs(list) do if l:find(s, 1, true) then return l end end end

local chat0, n0 = #W.printed, #(cw.log._lines or {})
type_("debug status")
local got = lines()
check("typed 'debug status': the typed line is echoed in the window", has_(got, "> /xui debug status") ~= nil)
check("typed 'debug status': its output shows in the console window", #got > n0 + 1 and (has_(got, "context:") or has_(got, "no rules")) ~= nil,
  table.concat(got, " / "):sub(1, 300))
check("typed 'debug status': nothing went to chat (messages are set to chat)", #W.printed == chat0, W.printed[#W.printed])
check("typed 'debug status': the first line hid the empty-window hint", empty and not empty:IsShown())
check("typed 'debug status': the line is cleared for the next command", (cmd:GetText() or "") == "")
check("typed 'debug status': kept in the line's history (Up brings it back)", history[#history] == "debug status", history[#history])

chat0, n0 = #W.printed, #(cw.log._lines or {})
type_("/xui help")
got = lines()
check("typed '/xui help' in full: the command list shows in the window", has_(got, "commands (") ~= nil and #got > n0 + 5)
check("typed '/xui help': nothing went to chat", #W.printed == chat0, W.printed[#W.printed])
n0 = #(cw.log._lines or {})
type_("/XAYAUI debug")
got = lines()
check("typed '/XAYAUI debug' (the other name, any case): the debug list shows", has_(got, "debug commands (") ~= nil and #got > n0 + 5)

local danced = false
local realDance = SlashCmdList.DANCE
SlashCmdList.DANCE = function() danced = true end
local hist0 = #history
n0 = #(cw.log._lines or {})
type_("/dance")
got = lines()
check("typed '/dance' (a game command): refused, not run", danced == false and has_(got, "Only XayaUI's own commands run here") ~= nil)
check("typed '/dance': not kept in the history", #history == hist0)
SlashCmdList.DANCE = realDance

check("after a typed command: the console routing is off again", ns.consoleRunning == nil)
chat0 = #W.printed
ns.Print("a message after the command")
check("after a typed command: XayaUI's messages go to chat again", #W.printed == chat0 + 1 and W.printed[#W.printed]:find("a message after the command", 1, true) ~= nil)

ns.RegisterCommand("xuitestboom", function() error("boom from a test command") end)
type_("xuitestboom")
got = lines()
check("a command that errors: the error shows in the window", has_(got, "boom from a test command") ~= nil, table.concat(got, " / "):sub(-200))
check("a command that errors: the console routing is off again", ns.consoleRunning == nil)
type_("   ")
check("a blank line runs nothing and keeps nothing", #history == hist0 + 1, #history)   -- (+1: the erroring command ran and is kept)

-- 5 (rest). Clear shows the hint again
if clearBtn then clearBtn:GetScript("OnClick")(clearBtn) end
check("Clear: the hint shows again", empty and empty:IsShown())
check("the hint says XayaUI's other messages go to the chat window, nothing about showing here", empty and (empty._text or ""):find("go to the chat window (Settings", 1, true) ~= nil,
  empty and empty._text)

-- 6. only what is sent to the console shows there; /save reloads -------------------------------------------------------------------
local function inBuf(t) for _, l in ipairs(ns.logBuf) do if l:find(t, 1, true) then return true end end; return false end
CueRulesDB.ui.msgDest = "chat"
chat0, n0 = #W.printed, #(cw.log._lines or {})
ns.Print("chat-only test one")
got = lines()
check("chat setting, window open: the message is in chat", #W.printed == chat0 + 1 and W.printed[#W.printed]:find("chat-only test one", 1, true) ~= nil)
check("chat setting, window open: ...and NOT in the console window", has_(got, "chat-only test one") == nil and #got == n0, got[#got])
check("chat setting, window open: ...nor in the console's buffer (Copy, bug report)", not inBuf("chat-only test one"))
ns.PrintPrivate("a private chat-only line")
check("chat setting: a private message stays out of the console window", has_(lines(), "a private chat-only line") == nil)
CueRulesDB.ui.advancedDebug = true
pcall(geterrorhandler(), "Interface/AddOns/XayaUI/Test.lua:1: a test error notice")
-- (the notice line itself, "[XayaUI error] ..."; the error log's own "Lua error captured" line reaches the console through ns.Log, as before)
check("chat setting: a XayaUI error notice stays out of the console window", has_(lines(), "[XayaUI error] Interface/AddOns/XayaUI/Test.lua:1: a test error notice") == nil)
CueRulesDB.ui.msgDest = "console"
ns.Print("console test one")
check("console setting: the message shows in the console window", has_(lines(), "console test one") ~= nil)
CueRulesDB.ui.msgDest = "chat"
-- /save
local reloads = 0
local realC_UI, realReloadUI = rawget(_G, "C_UI"), rawget(_G, "ReloadUI")
C_UI = setmetatable({ Reload = function() reloads = reloads + 1 end }, { __index = realC_UI })
ReloadUI = function() reloads = reloads + 100 end
local hist1 = #history
type_("/save")
check("typed '/save': the interface reloads, once, through C_UI.Reload", reloads == 1, reloads)
check("typed '/save': it says so in the window", has_(lines(), "> /save") ~= nil)
check("typed '/save': kept in the history", #history == hist1 + 1 and history[#history] == "/save", history[#history])
type_("/SAVE")
check("typed '/SAVE' (any case): reloads too", reloads == 2, reloads)
C_UI = nil
type_("/save")
check("no C_UI.Reload: ReloadUI is used instead", reloads == 102, reloads)
C_UI, ReloadUI = realC_UI, realReloadUI
reloads = 0
C_UI = setmetatable({ Reload = function() reloads = reloads + 1 end }, { __index = realC_UI })
type_("/reload")
check("typed '/reload': reloads too (Xaya: 'Both work')", reloads == 1 and has_(lines(), "> /reload") ~= nil, reloads)
reloads = 0
type_("/save now")
check("typed '/save now' (more than /save): refused, no reload", reloads == 0)
type_("/dance")
check("the refusal names /save and /reload", has_(lines(), "Only XayaUI's own commands run here (and /save or /reload, which reload the interface)") ~= nil)
C_UI = realC_UI

-- 7. /xui debug opens the console and prints there; the shortcuts print in chat --------------------------------------------------
local function inBuf2(t) for _, l in ipairs(ns.logBuf) do if plain(l):find(t, 1, true) then return true end end; return false end
local function chatHas(from, t) for i = from + 1, #W.printed do if plain(W.printed[i]):find(t, 1, true) then return true end end; return false end
CueRulesDB.ui.msgDest = "chat"
if ns.ConsoleWindow then ns.ConsoleWindow(false) end
check("(set-up) the console window is closed", not ns.ConsoleWindowOn())
chat0 = #W.printed
SlashCmdList.XAYAUI("debug loader")   -- typed in the normal chat box
check("/xui debug loader typed in chat: the console window opens", ns.ConsoleWindowOn())
check("...its output is in the console window", has_(lines(), "debug: ToggleUI=") ~= nil)
check("...and not in chat", not chatHas(chat0, "debug: ToggleUI="))
check("...routing is off again afterwards", ns.consoleRunning == nil)
if ns.ConsoleWindow then ns.ConsoleWindow(false) end
chat0 = #W.printed
SlashCmdList.XAYAUI("debug")
check("/xui debug (the list) typed in chat: opens the console window, the list is there, not in chat",
  ns.ConsoleWindowOn() and has_(lines(), "debug commands (") ~= nil and not chatHas(chat0, "debug commands ("))
-- shortcuts: in chat, whatever the setting
CueRulesDB.ui.msgDest = "console"
chat0 = #W.printed
SlashCmdList.XAYAUI("debug window")   -- (a line in the console, so the buffer has something new to compare)
local buf0 = #ns.logBuf
SlashCmdList.XAYAUI("status")
local statusInChat = chatHas(chat0, "no rules") or chatHas(chat0, "context:")
check("/xui status (shortcut), messages set to the console window: prints in chat", statusInChat, W.printed[#W.printed])
check("...and not in the console window's buffer", #ns.logBuf == buf0, ns.logBuf[#ns.logBuf])
check("...routing is off again afterwards", ns.chatRunning == nil and ns.consoleRunning == nil)
chat0 = #W.printed
SlashCmdList.XAYAUI("auras")
check("/xui auras (shortcut): prints its list in chat", chatHas(chat0, "auras:"), W.printed[#W.printed])
SlashCmdList.XAYAUI("debug status")
check("/xui debug status, same setting: in the console window", has_(lines(), "no rules") ~= nil or has_(lines(), "context:") ~= nil)
-- a shortcut typed in the console window prints there
CueRulesDB.ui.msgDest = "chat"
chat0 = #W.printed
type_("status")
check("'status' typed in the console window: prints there, not in chat",
  not (chatHas(chat0, "no rules") or chatHas(chat0, "context:")) and (has_(lines(), "> /xui status") ~= nil))
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    # (the test's own erroring command and error notice are expected in the error handler's list; any other error fails the run)
    errs = [e for e in errs if "boom from a test command" not in str(e) and "a test error notice" not in str(e)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
