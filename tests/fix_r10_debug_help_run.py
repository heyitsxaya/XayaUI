#!/usr/bin/env python3
"""SD-118 for Advanced Debugging (bundle 1 round 10, repair 1; REQUEST-LOG SD-118, a STANDING RULE, her answer "All parts, say how
(Recommended)"): a part's chat words work only while that part is on, and /xui help lists a part's words only while it is on.

Advanced Debugging (the debug tools, the load-on-demand folder XayaUI_Debug, SD-58: "1 but nothing loads unless "Debugging" is
enabled") is a part with its own switch, /xui > Settings > Debugging. Its words are core's /xui console, /xui bug, /xui report and the
shortcuts /xui status and /xui auras (Core.lua). Since round 7 each of them answers with one line while the tools are not loaded
(DebugRecord.lua ns.DebugToolsNeeded). Before this repair /xui help still listed all five while that part was off. This test checks that
the help list now matches what the words do. The part counts as on when its tools were loaded at this login or /reload, because an off
part is detected once per reload (SD-56, her words: "should be detected once per reload"; V34).
What the player sees, checked here with the real addons in the stand-in game (XayaUI, XayaUI_Rules, XayaUI_Options, XayaUI_Debug; the
Bonus folders are left out so the list is core's alone and does not depend on the Bonus units' work):
  OFF          fresh install (Advanced Debugging off, the tools not loaded): /xui help lists exactly /xui, /xui unlock, /xui debug,
               /xui disable, /xui enable (five; header count five); none of console, bug, report, status, auras. Typing each of those
               five prints exactly one line, "<what> needs Advanced Debugging: turn it on in /xui > Settings > Debugging, then type
               /reload.", and XayaUI_Debug stays unloaded (nothing of the part is read). /xui debug is listed and still runs its list.
  PENDING      turned on in the settings during the session, no /reload yet (the tools are still not loaded): the help list still
               leaves the five out; typing /xui console prints the one "needs a /reload" line; XayaUI_Debug stays unloaded.
  ON           Advanced Debugging on at the login (the tools loaded): /xui help lists core's ten in its order, the five included.
  NOT LOADED   Advanced Debugging on, but XayaUI_Debug switched off in the game's AddOns list (so the tools are not loaded): the five are
               left out; /xui report prints one line naming the AddOns list.
  RULES OFF    Advanced Debugging on, XayaUI Rules switched off in the AddOns list: console, bug and report are listed; status, auras,
               unlock, disable and enable are not (XayaUI Rules' words, P4; control for the two filters together).
Negative control: on the pre-repair Core.lua (DEBUG_HELP absent) the OFF, PENDING and NOT LOADED help checks fail (the five are listed
while the part is off); the typed-word lines and ON pass before and after (they were already right). Mutations (see the round 10 repair
report): the filter always on (the five never listed) fails ON and RULES OFF; the filter reading the saved switch instead of the loaded
tools fails PENDING and NOT LOADED; one word dropped from DEBUG_HELP fails OFF.
Run: python3 tests/fix_r10_debug_help_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, case)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { case .. ": " .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
-- what one command shows the player: the lines printed in chat and the lines drawn in the console window (with the tools loaded the
-- console window is opened first, so each line is drawn as it comes), each without the "XayaUI: " name and without color codes
local SHOWN_NAME = "|cff33ccffXayaUI|r: "
local function unname(l) l = tostring(l); if l:sub(1, #SHOWN_NAME) == SHOWN_NAME then return l:sub(#SHOWN_NAME + 1) end; return l end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function consoleLines() local cw = rawget(_G, "XayaUIConsoleWindow"); return cw and cw.log and cw.log._lines end
local function run(s)
  if ns.DebugToolsLoaded() and not ns.ConsoleWindowOn() then ns.ConsoleWindow(true) end
  local c0, log0 = #W.printed, consoleLines()
  local n0 = log0 and #log0 or 0
  local ok, err = pcall(SlashCmdList.XAYAUI, s); W.tick(0.1, 2)
  local out = {}
  for i = c0 + 1, #W.printed do out[#out + 1] = plain(unname(W.printed[i])) end
  local log = consoleLines()
  if log then for i = (log == log0 and n0 or 0) + 1, #log do out[#out + 1] = plain(unname(log[i])) end end
  if not ok then out[#out + 1] = "(error: " .. tostring(err) .. ")" end
  return out
end
-- the commands /xui help lists, in order ("/xui", "/xui console", ...), and whether its header count matches
local function helpCmds()
  local h = run("help")
  local cmds = {}
  for i = 2, #h do local c = h[i]:match("^  (/xui%s%S+)") or h[i]:match("^  (/xui)%s") or h[i]:match("^  (/xui)$"); if c then cmds[#cmds + 1] = c end end
  return cmds, h[1] == ("commands (%d):"):format(#h - 1) and #cmds == #h - 1, h
end
local FIVE = { "console", "bug", "report", "status", "auras" }
local WHAT = { console = "The console window (/xui console)", bug = "The bug report (/xui bug)", report = "The debug report (/xui report)",
  status = "/xui status", auras = "/xui auras" }
local function listed(cmds, w) for _, c in ipairs(cmds) do if c == "/xui " .. w then return true end end return false end
local function noneOfFive(cmds) for _, w in ipairs(FIVE) do if listed(cmds, w) then return false, "/xui " .. w end end return true end
local function dbgLoaded() return C_AddOns.IsAddOnLoaded("XayaUI_Debug") and true or false end
local OFF_CORE = { "/xui", "/xui unlock", "/xui debug", "/xui disable", "/xui enable" }
local ALL_CORE = { "/xui", "/xui console", "/xui bug", "/xui report", "/xui unlock", "/xui status", "/xui auras", "/xui debug", "/xui disable", "/xui enable" }

if case == "OFF" or case == "PENDING" then
  check("setup: Advanced Debugging is off and the debug tools are not loaded", not ns.AdvancedDebugOn() and not ns.DebugToolsLoaded() and not dbgLoaded())
  if case == "PENDING" then
    CueRulesDB.ui.advancedDebug = true   -- the tick in /xui > Settings > Debugging, no /reload yet
    check("setup: turned on in the settings, the tools still not loaded (they load at the next /reload)", ns.AdvancedDebugOn() and not ns.DebugToolsLoaded() and not dbgLoaded())
  end
  local cmds, headerOk, h = helpCmds()
  check("/xui help has a header with its count", headerOk, h[1])
  check("/xui help lists none of console, bug, report, status, auras (Advanced Debugging's words) while its tools are not loaded", noneOfFive(cmds), select(2, noneOfFive(cmds)))
  check("/xui help lists exactly " .. table.concat(OFF_CORE, ", ") .. ", in that order", table.concat(cmds, ",") == table.concat(OFF_CORE, ","), table.concat(cmds, " "))
  for _, w in ipairs(FIVE) do
    local out = run(w)
    local want = case == "OFF" and (WHAT[w] .. " needs Advanced Debugging: turn it on in /xui > Settings > Debugging, then type /reload.")
      or (WHAT[w] .. " needs a /reload: the debug tools load at the next login or /reload while Advanced Debugging is on.")
    check(("/xui %s prints exactly one line: '%s'"):format(w, want), #out == 1 and out[1] == want, table.concat(out, " / "))
  end
  check("typing those words left XayaUI_Debug unloaded (nothing of the part is read)", not dbgLoaded(), "loaded")
  local d = run("debug")
  local dl = table.concat(d, "\n")
  check("/xui debug still runs its list (loader and talents run without the tools)", dl:find("/xui debug loader", 1, true) ~= nil and dl:find("/xui debug talents", 1, true) ~= nil, dl)
elseif case == "ON" then
  check("setup: Advanced Debugging on at the login, the debug tools loaded", ns.AdvancedDebugOn() and ns.DebugToolsLoaded() and dbgLoaded())
  local cmds, headerOk, h = helpCmds()
  check("/xui help has a header with its count", headerOk, h[1])
  check("/xui help lists core's ten, console, bug, report, status and auras included, in its order", table.concat(cmds, ",") == table.concat(ALL_CORE, ","), table.concat(cmds, " "))
  local out = run("report")
  local any
  for _, l in ipairs(out) do if l:find("needs Advanced Debugging", 1, true) or l:find("needs a /reload", 1, true) then any = l end end
  check("/xui report runs (no 'needs Advanced Debugging' line)", any == nil, any)
elseif case == "NOT LOADED" then
  check("setup: Advanced Debugging on, XayaUI_Debug switched off in the AddOns list, the tools not loaded", ns.AdvancedDebugOn() and not ns.DebugToolsLoaded() and not dbgLoaded())
  local cmds, headerOk, h = helpCmds()
  check("/xui help has a header with its count", headerOk, h[1])
  check("/xui help lists none of console, bug, report, status, auras", noneOfFive(cmds), select(2, noneOfFive(cmds)))
  check("/xui help lists exactly " .. table.concat(OFF_CORE, ", "), table.concat(cmds, ",") == table.concat(OFF_CORE, ","), table.concat(cmds, " "))
  local out = run("report")
  local want = "The debug report (/xui report) is one of the debug tools (XayaUI Debug), which is switched off in the game's AddOns list. Turn it on, then type /reload."
  check("/xui report prints exactly one line naming the AddOns list", #out == 1 and out[1] == want, table.concat(out, " / "))
elseif case == "RULES OFF" then
  check("setup: Advanced Debugging on and its tools loaded, XayaUI Rules not loaded", ns.DebugToolsLoaded() and not C_AddOns.IsAddOnLoaded("XayaUI_Rules"))
  local cmds, headerOk, h = helpCmds()
  check("/xui help has a header with its count", headerOk, h[1])
  local want = { "/xui", "/xui console", "/xui bug", "/xui report", "/xui debug" }
  check("/xui help lists exactly " .. table.concat(want, ", ") .. " (Rules' unlock, status, auras, disable, enable left out)",
    table.concat(cmds, ",") == table.concat(want, ","), table.concat(cmds, " "))
end
return R
end
'''

CASES = [
    # case, addons switched off in the AddOns list, Advanced Debugging saved on
    ("OFF", (), False),
    ("PENDING", (), False),
    ("ON", (), True),
    ("NOT LOADED", ("XayaUI_Debug",), True),
    ("RULES OFF", ("XayaUI_Rules",), True),
]


def run_case(case, off, debug_on):
    folders = H.find_addons()
    enabled = [f for f in folders if f in ("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug") and f not in off]
    saved = {"XayaUI": {"CueRulesDB": {"ui": {"advancedDebug": True}}}} if debug_on else {}
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, W, Ld, c) return loadstring(src)()(W, Ld, c) end")(LUA, world, loader, case)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", e[:600])
    return len(res), bad, len(errs)


def main():
    n = b = e = 0
    for case, off, dbg in CASES:
        n1, b1, e1 = run_case(case, off, dbg)
        n, b, e = n + n1, b + b1, e + e1
    print("%d checks, %d failed, %d Lua errors" % (n, b, e))
    sys.exit(1 if (b or e) else 0)


if __name__ == "__main__":
    main()
