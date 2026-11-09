#!/usr/bin/env python3
"""/xui help prints one command per line (core 0.6.46; Xaya 2026-11-05: "console print is difficult to read": the whole command list
was one line joined by " | ", unreadable in the console window and the chat history's Console tab). Checks the printed lines: a
header with the count, then every command on its own line starting with /xui, the command colored and closed, what it does after it,
literal pipes doubled ("||", shown as "|"; core 0.6.50 printed "/" for a while, Xaya 2026-11-06 chose "Back to '|'"), and no line
holding two commands. (core 0.6.50 moved the diagnostic commands under /xui debug: tests/console_commands_run.py.)
Main holds XayaUI, XayaUI_Options and XayaUI_Rules only (the main slim-down; Rules 0.7.0): neither Options nor Rules registers a
/xui command of its own, so the list is exactly core's eight (Core.lua CORE_HELP, all shown with XayaUI Rules on). The 11 more the
list had before were all registered by the addons that left main (Bonus, Chat, QoL: data, notes, calc, chat, panel, privacy, cursor,
reskin, shop, releaseguard, stats).
Run: python3 tests/xui_help_lines_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
local out = ns.CaptureOutput(function() SlashCmdList.XAYAUI("help") end)
local nCmd = 0
for _, l in ipairs(out) do if l:find("/xui", 1, true) then nCmd = nCmd + 1 end end
check("a header line with the count", out[1] and out[1]:match("^commands %((%d+)%):$") ~= nil and tonumber(out[1]:match("%((%d+)%)")) == #out - 1, out[1])
check("core's eight commands, one per line", #out - 1 == 8 and nCmd == #out - 1, ("%d lines, %d with /xui"):format(#out - 1, nCmd))
-- the commands, in core's order (the colored part of each line, pipes doubled)
local WANT = { "/xui", "/xui console", "/xui bug", "/xui report", "/xui unlock", "/xui status",
  "/xui auras [target||focus||pet] [debuffs] or <spellID>", "/xui debug" }
local got = {}
for i = 2, #out do got[#got + 1] = out[i]:match("^  |cff%x%x%x%x%x%x(.-)|r") or out[i] end
check("the commands are core's, in its order (with XayaUI Rules on: unlock, status and auras included)",
  table.concat(got, "\n") == table.concat(WANT, "\n"), table.concat(got, " ; "))
local two, uncolored, unclosed, badPipe, debugLine, consoleLine = nil, nil, nil, nil, nil, nil
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
end
check("no line holds two commands (the old ' | ' join)", two == nil, two)
check("every line starts with the colored command", uncolored == nil, uncolored)
check("every color is closed", unclosed == nil, unclosed)
check("literal pipes are doubled, color codes are not", badPipe == nil, badPipe)
check("/xui debug is listed with what it does", debugLine ~= nil)
check("the description follows its command without the brackets", consoleLine ~= nil)
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = list(folders)
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
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
