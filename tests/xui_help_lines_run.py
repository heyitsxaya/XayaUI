#!/usr/bin/env python3
"""/xui help prints one command per line (core 0.6.46; Xaya 2026-11-05: "console print is difficult to read": the whole command list
was one line joined by " | ", unreadable in the console window and the chat history's Console tab). Checks the printed lines: a
header with the count, then every command on its own line starting with /xui, the command colored and closed, what it does after it,
literal pipes doubled ("||", shown as "|"; core 0.6.50 printed "/" for a while, Xaya 2026-11-06 chose "Back to '|'"), and no line
holding two commands. (core 0.6.50 moved the diagnostic commands under /xui debug: tests/console_commands_run.py.)
This branch holds XayaUI, XayaUI_Options, XayaUI_Rules, XayaUI_Debug (load-on-demand), XayaUI_Bonus and XayaUI_Bonus_StatCalculator
(load-on-demand). Neither Options nor Rules registers a /xui command of its own; core's ten are Core.lua CORE_HELP (all shown with XayaUI
Rules on; ten since V26 added /xui disable and /xui enable). The 11 more the list had before the main slim-down were all registered by
the addons that left main (Bonus, Chat, QoL: data, notes, calc, chat, panel, privacy, cursor, reskin, shop, releaseguard, stats).
XayaUI Bonus Features (main's) registers the words of its parts: /xui stats (the Stat Calculator) and, from round 10, /xui calc and
/xui calculator (the arithmetic Calculator, SD-95 / SD-115 / SD-116). (bundle 1 round 10, REQUEST-LOG SD-118, intended change) a part's
words are listed only while the part is switched on: on this test's fresh install the Stat Calculator is off, so /xui stats is not
listed (eleven lines before round 10, ten now); the Calculator is on by default, so its words are listed once Bonus registers them.
(round 10 repair 1, SD-118, intended change) the same holds for Advanced Debugging (the debug tools, XayaUI_Debug, SD-58), whose words are
core's /xui console, bug, report, status and auras: they are listed only while its tools are loaded (on at this login or /reload,
SD-56). So the test runs twice: on a fresh install (Advanced Debugging off) core lists five (/xui, unlock, debug, disable, enable); with
Advanced Debugging saved on, core's ten. tests/fix_r10_debug_help_run.py checks the off, pending, on and not-loaded cases in full.
Run: python3 tests/xui_help_lines_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, dbgOn)
local R = {}
local TAG = dbgOn and "[Advanced Debugging on] " or "[fresh install, Advanced Debugging off] "
local function check(name, ok, extra) R[#R + 1] = { TAG .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
-- (bundle 1 round 9, REQUEST-LOG A23 SD-83, her answer "Remove both (Recommended)": ns.CaptureOutput is gone) what a command shows the
-- player, read from the stand-in game: the lines printed in chat (W.printed) and the lines drawn in the console window, each without the
-- "XayaUI: " name in front, in that order (one command prints in one of the two). With the debug tools loaded the console window is opened
-- first, so each line is drawn as it comes (a window opening in the middle of a command first draws the older lines it missed). A Lua
-- error in the command ends the list as "(error: ...)".
local SHOWN_NAME = "|cff33ccffXayaUI|r: "
local function unname(l) l = tostring(l); if l:sub(1, #SHOWN_NAME) == SHOWN_NAME then return l:sub(#SHOWN_NAME + 1) end; return l end
local function consoleLines() local cw = rawget(_G, "XayaUIConsoleWindow"); return cw and cw.log and cw.log._lines end
local function shown(fn, ...)
  if ns.DebugToolsLoaded and ns.DebugToolsLoaded() and not ns.ConsoleWindowOn() then ns.ConsoleWindow(true) end
  local c0, log0 = #W.printed, consoleLines()
  local n0 = log0 and #log0 or 0
  local ok, err = pcall(fn, ...)
  local out = {}
  for i = c0 + 1, #W.printed do out[#out + 1] = unname(W.printed[i]) end
  local log = consoleLines()
  if log then for i = (log == log0 and n0 or 0) + 1, #log do out[#out + 1] = unname(log[i]) end end
  if not ok then out[#out + 1] = "(error: " .. tostring(err) .. ")" end
  return out
end
local out = shown(SlashCmdList.XAYAUI, "help")
local nCmd = 0
for _, l in ipairs(out) do if l:find("/xui", 1, true) then nCmd = nCmd + 1 end end
check("a header line with the count", out[1] and out[1]:match("^commands %((%d+)%):$") ~= nil and tonumber(out[1]:match("%((%d+)%)")) == #out - 1, out[1])
-- (V26, lock-core round 3: ten since /xui disable and /xui enable were added)
-- (Bonus 0.6.45, A24 #10) XayaUI Bonus Features is on main with the Stat Calculator: its /xui stats is the loader's.
-- (bundle 1 round 10, SD-118, intended change) listed only while the Stat Calculator is switched on (XayaUIBonusDB.characterToolkit
-- .enabled): off on this fresh install, so not listed. The Calculator's words (on by default, SD-116) follow core's ten once registered.
local SC_ON = C_AddOns.IsAddOnLoaded("XayaUI_Bonus") and true or false
local scSwitch = SC_ON and type(rawget(_G, "XayaUIBonusDB")) == "table" and type(XayaUIBonusDB.characterToolkit) == "table"
  and XayaUIBonusDB.characterToolkit.enabled == true or false
check("setup: the Stat Calculator is off on this fresh install", scSwitch == false, scSwitch)
local got = {}
for i = 2, #out do got[#got + 1] = out[i]:match("^  |cff%x%x%x%x%x%x(.-)|r") or out[i] end
local calc = {}   -- the Calculator's lines, as printed (its help text is the calculator unit's)
for _, g in ipairs(got) do if SC_ON and (g:find("^/xui calc ") or g == "/xui calc" or g:find("^/xui calculator")) then calc[#calc + 1] = g end end
-- (round 10 repair 1, SD-118, intended change) Advanced Debugging's five (console, bug, report, status, auras) only while its tools are loaded
check("setup: the debug tools are " .. (dbgOn and "loaded" or "not loaded"), (ns.DebugToolsLoaded() and true or false) == dbgOn, ns.DebugToolsLoaded())
local nCore = dbgOn and 10 or 5
local nWant = nCore + #calc
check("core's " .. nCore .. " commands" .. (#calc > 0 and (" and the Calculator's " .. #calc) or "") .. ", one per line; no /xui stats while the Stat Calculator is off (SD-118)",
  #out - 1 == nWant and nCmd == #out - 1, ("%d lines, %d with /xui"):format(#out - 1, nCmd))
-- the commands, in core's order (the colored part of each line, pipes doubled)
local WANT = dbgOn and { "/xui", "/xui console", "/xui bug", "/xui report", "/xui unlock", "/xui status",
  "/xui auras [target||focus||pet] [debuffs] or <spellID>", "/xui debug", "/xui disable", "/xui enable" }
  or { "/xui", "/xui unlock", "/xui debug", "/xui disable", "/xui enable" }
for _, c in ipairs(calc) do WANT[#WANT + 1] = c end
check("the commands are core's, in its order (with XayaUI Rules on: unlock included; console, bug, report, status and auras only with Advanced Debugging on)",
  table.concat(got, "\n") == table.concat(WANT, "\n"), table.concat(got, " ; "))
local two, uncolored, unclosed, badPipe, debugLine, consoleLine, unlockLine = nil, nil, nil, nil, nil, nil, nil
for i = 2, #out do
  local l = out[i]
  local _, n = l:gsub("/xui ", "")
  local _, n2 = l:gsub("/xui$", "")
  if n + n2 > 1 then two = l end
  if not l:find("^  |cff%x%x%x%x%x%x/xui") then uncolored = l end
  if not l:find("|r", 1, true) then unclosed = l end
  local stripped = l:gsub("^  |cff%x%x%x%x%x%x", ""):gsub("|r", "", 1)
  if stripped:gsub("||", ""):find("|", 1, true) then badPipe = l end
  if l:find("/xui debug|r  diagnostic commands", 1, true) then debugLine = l end
  if l:find("/xui console|r  the XayaUI console", 1, true) then consoleLine = l end
  if l:find("/xui unlock|r  drag displays and groups; again to lock", 1, true) then unlockLine = l end
end
check("no line holds two commands (the old ' | ' join)", two == nil, two)
check("every line starts with the colored command", uncolored == nil, uncolored)
check("every color is closed", unclosed == nil, unclosed)
check("literal pipes are doubled, color codes are not", badPipe == nil, badPipe)
check("/xui debug is listed with what it does", debugLine ~= nil)
check("the description follows its command without the brackets", unlockLine ~= nil and (consoleLine ~= nil) == dbgOn)
return R
end
'''


def run_once(dbg_on):
    folders = H.find_addons()
    enabled = list(folders)
    saved = {"XayaUI": {"CueRulesDB": {"ui": {"advancedDebug": True}}}} if dbg_on else {}
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, W, Ld, d) return loadstring(src)()(W, Ld, d) end")(LUA, world, loader, dbg_on)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    return len(res), bad, len(errs)


def main():
    n1, b1, e1 = run_once(False)
    n2, b2, e2 = run_once(True)
    print("%d checks, %d failed, %d Lua errors" % (n1 + n2, b1 + b2, e1 + e2))
    sys.exit(1 if (b1 + b2 + e1 + e2) else 0)


if __name__ == "__main__":
    main()
