#!/usr/bin/env python3
"""The console window's command line and /xui debug (core 0.6.49).
Xaya, 2026-11-05: "XUI Console does nothing and has no input options" (screenshot: an empty console window, four buttons, nothing to
type in), and of the /xui help list: "can't some of these be consolidated into a /xui debug _____ ? this is a LOT of noise" (29 lines).
What the player sees, checked here with the real addons in the stand-in game:
  1. /xui help lists only the player's commands (no diagnostic one), one of them /xui debug; no "|" is printed in it (the chat
     history window dropped a doubled pipe and the letter after it: "[highlighttrail]", "statusidthprobe" in her screenshot).
  2. /xui debug lists every diagnostic command as "/xui debug <name>"; each listed name runs; an unknown one says so and lists them.
  3. Parity (V5): the old form (/xui status, /xui auras target) prints exactly what /xui debug status / auras target prints.
  4. The console window has a command line inside it, under the log, clear of the resize grip. With XayaUI's messages set to the
     chat window (Xaya's case), a command typed there prints in the console window and not in chat; the typed line is echoed;
     "/xui ..." and "/xayaui ..." work typed in full; another addon's slash command is refused, not run; afterwards messages go
     to chat again; a command that errors shows the error in the window and leaves nothing switched on.
  5. An empty console window says what to type and where XayaUI's other messages go; the first line hides that; Clear shows it again.
Negative control: on core 0.6.48 (no command line, /xui debug was a one-line loader check, help listed 29 commands) checks in
1, 2, 3 (debug forms), 4 and 5 fail.
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
  if p:find("|", 1, true) then pipe = p end
end
check("help: a header with the count, then that many lines", help[1] == ("commands (%d):"):format(#help - 1), help[1])
check("help: 15 lines at most (it was 29)", #help - 1 <= 15 and #help - 1 >= 10, #help - 1)
local diag = { "status", "probe", "debuffs", "perf", "timing", "seed", "talents", "model", "tracker", "loc", "media", "gamemenu",
  "auras", "chatprobe", "mods", "groups", "icons" }
local leaked
for _, c in ipairs(cmds) do for _, d in ipairs(diag) do if c == "/xui " .. d then leaked = c end end end
for i = 2, #help do if plain(help[i]):find("widthprobe", 1, true) then leaked = plain(help[i]) end end
check("help: no diagnostic command is listed", leaked == nil, leaked)
local has = {}
for _, c in ipairs(cmds) do has[c] = true end
check("help: /xui debug is listed, with what it does", has["/xui debug"] and table.concat(help, "\n"):find("diagnostic commands", 1, true) ~= nil)
for _, c in ipairs({ "/xui", "/xui console", "/xui bug", "/xui unlock", "/xui chat", "/xui stats", "/xui cursor", "/xui notes" }) do
  check("help: still lists " .. c, has[c] == true)
end
check("help: no '|' printed (option lists read [on/off])", pipe == nil, pipe)

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
for _, d in ipairs({ "window", "widthprobe" }) do if not names[d] then missing[#missing + 1] = d end end
check("debug: lists every diagnostic command (core and the features')", #missing == 0, table.concat(missing, ", "))
local dpipe
for i = 1, #dbg do if plain(dbg[i]):find("|", 1, true) then dpipe = dbg[i] end end
check("debug: no '|' printed", dpipe == nil, dpipe)
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
local win = run("debug window")
check("debug window: the old /xui debug loader check", win[1] ~= nil and win[1]:find("debug: ToggleUI=", 1, true) ~= nil, win[1])

-- 3. parity: the old form prints what the /xui debug form prints ------------------------------------------------------------------
local function same(a, b)
  if #a ~= #b or #a == 0 then return false, ("%d vs %d lines"):format(#a, #b) end
  for i = 1, #a do if a[i] ~= b[i] then return false, a[i] .. " <> " .. b[i] end end
  return true
end
for _, pair in ipairs({ { "status", "debug status" }, { "auras target", "debug auras target" }, { "perf", "debug perf" },
                        { "loc", "debug loc" }, { "gamemenu", "debug gamemenu" } }) do
  local ok, why = same(run(pair[1]), run(pair[2]))
  check(("parity: /xui %s prints what /xui %s prints"):format(pair[1], pair[2]), ok, why)
end

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

local reloaded = false
local realReload = SlashCmdList.RELOAD
SlashCmdList.RELOAD = function() reloaded = true end
local hist0 = #history
n0 = #(cw.log._lines or {})
type_("/reload")
got = lines()
check("typed '/reload': refused, not run", reloaded == false and has_(got, "Only XayaUI's own commands run here") ~= nil)
check("typed '/reload': not kept in the history", #history == hist0)
SlashCmdList.RELOAD = realReload

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
    # (the test's own erroring command is expected in the error handler's list; any other error fails the run)
    errs = [e for e in errs if "boom from a test command" not in str(e)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
