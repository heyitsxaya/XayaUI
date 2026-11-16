#!/usr/bin/env python3
"""Bundle 1 round 9 (core-options): the debug words left over from XayaUI Dev Assist (REQUEST-LOG A23 SD-83, her answer verbatim:
"Remove both (Recommended)"), and the perf help line. What the player sees, with the real addons in the stand-in game:
  P1. /xui debug lists perf with what it measures now, in plain words: "/xui debug perf [on|off]  measure the combat engine: pass
      counts, CPU and memory" (was "engine timing"; the perf report, XayaUI_Debug/RulesPerf.lua, shows pass counts, the game's CPU meter
      and Lua memory).
  P2. /xui debug perf ui, Advanced Debugging on: core no longer hands "ui" to another addon (XayaUI Dev Assist's settings-window timing,
      retired): it reaches the engine meter, which answers in one line (today: "perf: not measuring. ..."); nothing says "there is no
      debug command". /xui debug perf and /xui debug perf on / off still work as before.
  P3. /xui debug perf ui, Advanced Debugging off: the same one plain line as any other gated debug word (unchanged).
  P4. XayaUI Rules switched off: /xui debug perf says it needs XayaUI Rules, as before; /xui debug perf ui now says the same (before:
      'there is no debug command "perf ui".' and the list; the gate's "perf" carve-out, which served only that hand-off, is gone).
  P5. /xuiengine with any word after it shows the status and its closing line; it never asks another addon to run the word (the
      ns.RunSubcommand / ns.SubcommandList hand-off, removed from core in round 8, is gone from XayaUI_Debug/RulesEngine.lua too), even if
      something sets those names again.
  P6. ns.CaptureOutput is gone, and a message is shown even with a stray ns._capture table set (nothing swallows it).
Negative control: on the pre-change files (round 9 start) P1, P2, P5, P6 and P4's perf ui check fail (16 of 24); P3, P4's perf check
and the P2 on / report / off checks pass on both (controls).
Run: python3 tests/fix_r9_debug_words_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[" .. MODE .. "] " .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- what a command shows the player: the new lines printed in chat and drawn in the console window, without the "XayaUI: " name
local NAME = "|cff33ccffXayaUI|r: "
local function unname(l) l = tostring(l); if l:sub(1, #NAME) == NAME then return l:sub(#NAME + 1) end; return l end
local function consoleLines() local cw = rawget(_G, "XayaUIConsoleWindow"); return cw and cw.log and cw.log._lines end
local function shown(fn, ...)
  if ns.DebugToolsLoaded and ns.DebugToolsLoaded() and not ns.ConsoleWindowOn() then ns.ConsoleWindow(true) end
  local c0, log0 = #W.printed, consoleLines()
  local n0 = log0 and #log0 or 0
  local ok, err = pcall(fn, ...)
  local out = {}
  for i = c0 + 1, #W.printed do out[#out + 1] = plain(unname(W.printed[i])) end
  local log = consoleLines()
  if log then for i = (log == log0 and n0 or 0) + 1, #log do out[#out + 1] = plain(unname(log[i])) end end
  if not ok then out[#out + 1] = "(error: " .. tostring(err) .. ")" end
  return out
end
local function run(s) return shown(SlashCmdList.XAYAUI, s) end
local function J(t) return table.concat(t, " / ") end
local errs0 = #W.errors

if MODE == "on" then
  -- P1
  local list = run("debug")
  local perfLine
  for _, l in ipairs(list) do if l:find("^  /xui debug perf") then perfLine = l end end
  check("P1 /xui debug lists perf as '/xui debug perf [on||off]  measure the combat engine: pass counts, CPU and memory'",
    perfLine == "  /xui debug perf [on||off]  measure the combat engine: pass counts, CPU and memory", perfLine)
  check("P1 ...no 'engine timing' left, and no 'perf ui'", not J(list):find("engine timing", 1, true) and not J(list):find("perf ui", 1, true), J(list))
  -- P2
  local asked = {}
  local rawRun = ns.RunDebugCommand
  ns.RunDebugCommand = function(name, ...) asked[#asked + 1] = tostring(name); return rawRun(name, ...) end
  local ui = run("debug perf ui")
  ns.RunDebugCommand = rawRun
  check("P2 /xui debug perf ui: one line, from the engine meter ('perf: ...')", #ui == 1 and ui[1]:sub(1, 6) == "perf: ", J(ui))
  check("P2 ...not 'there is no debug command', and no list of commands after it", not J(ui):find("no debug command", 1, true)
    and not J(ui):find("debug commands (", 1, true), J(ui))
  check("P2 ...no other addon's command is asked for perf (the Dev Assist hand-off is gone)", #asked == 0, J(asked))
  check("P2 (record) today's answer, not measuring: 'perf: not measuring. /xui debug perf on, play a while, then /xui debug perf.'",
    ui[1] == "perf: not measuring. /xui debug perf on, play a while, then /xui debug perf.", ui[1])
  local on = run("debug perf on")
  check("P2 (control) /xui debug perf on still starts measuring", on[1] ~= nil and on[1]:find("^perf: measuring%.") ~= nil, J(on))
  local rep = run("debug perf")
  check("P2 (control) /xui debug perf then shows the report", rep[1] ~= nil and rep[1]:find("^perf over ") ~= nil, rep[1])
  local off = run("debug perf off")
  check("P2 (control) /xui debug perf off stops", off[1] == "perf: stopped. /xui debug perf shows the report.", J(off))
  -- P5
  local called = {}
  ns.RunSubcommand = function(scope, word) called[#called + 1] = "RunSubcommand " .. tostring(scope) .. " " .. tostring(word); return true end
  ns.SubcommandList = function(scope) called[#called + 1] = "SubcommandList " .. tostring(scope); return "  Also: /xuiengine dev" end
  local base = shown(SlashCmdList.XUIENGINE, "")
  local LAST = "/xuiengine shows what the combat engine draws; it changes nothing.  The engine draws aura displays through the game's own aura frames, so time and stacks show in combat."
  check("P5 /xuiengine alone: the status, ending with its closing line", #base >= 2 and base[#base] == LAST, J(base))
  for _, w in ipairs({ "auto off", "full", "refresh", "nosuch", "dev" }) do
    local o = shown(SlashCmdList.XUIENGINE, w)
    check("P5 /xuiengine " .. w .. ": exactly the same lines as /xuiengine alone", J(o) == J(base), J(o))
  end
  check("P5 ...and no other addon was asked to run the word or list its words (with those names set again)", #called == 0, J(called))
  ns.RunSubcommand, ns.SubcommandList = nil, nil
  -- P6
  check("P6 ns.CaptureOutput is gone", ns.CaptureOutput == nil)
  CueRulesDB.ui.msgDest = "chat"
  ns._capture = {}
  local c0 = #W.printed
  ns.Print("a line with a stray capture table")
  local left = #ns._capture
  ns._capture = nil
  check("P6 a message is shown even with a stray ns._capture table (nothing swallows it)", left == 0 and #W.printed == c0 + 1
    and W.printed[#W.printed]:find("a line with a stray capture table", 1, true) ~= nil, left)
elseif MODE == "off" then
  -- P3
  local ui = run("debug perf ui")
  check("P3 Advanced Debugging off: /xui debug perf ui is the one plain line every gated debug word gives",
    #ui == 1 and ui[1] == "/xui debug perf ui needs Advanced Debugging: turn it on in /xui > Settings > Debugging, then type /reload.", J(ui))
  R.offLine = ui[1]
elseif MODE == "norules" then
  -- P4
  local p = run("debug perf")
  local u = run("debug perf ui")
  local want = ns.ModuleMissingText("perf", true)
  check("P4 XayaUI Rules off: /xui debug perf says it needs XayaUI Rules", #p == 1 and want ~= nil and p[1] == plain(want), J(p))
  check("P4 ...and /xui debug perf ui says the same", #u == 1 and u[1] == p[1], J(u))
  R.norulesLine = p[1]
end
check("no Lua error", #W.errors == errs0, W.errors[#W.errors])
return R
end
'''


def session(mode):
    folders = H.find_addons()
    enabled = {k: True for k in folders}
    saved = {"XayaUI": {"CueRulesDB": {"ui": {"advancedDebug": mode != "off"}}}}
    if mode == "norules":
        enabled["XayaUI_Rules"] = False
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": enabled, "saved": saved}))
    res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)
    out = [(str(res[i][1]), bool(res[i][2])) for i in range(1, len(res) + 1)]
    for k in ("offLine", "norulesLine"):
        if res[k] is not None:
            print("SHOWN [%s] %s" % (mode, res[k]))
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return out, errs


def main():
    bad, n, lua_errs = 0, 0, 0
    for mode in ("on", "off", "norules"):
        out, errs = session(mode)
        for name, ok in out:
            n += 1
            print(("PASS " if ok else "FAIL ") + name)
            bad += 0 if ok else 1
        for e in errs:
            print("ERROR in the game stand-in [%s]: %s" % (mode, e[:600]))
        lua_errs += len(errs)
    print("%d checks, %d failed, %d Lua errors" % (n, bad, lua_errs))
    sys.exit(1 if bad or lua_errs else 0)


if __name__ == "__main__":
    main()
