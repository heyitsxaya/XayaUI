#!/usr/bin/env python3
"""Merge of main's Bonus Features into bundle 1 (round 9, merge repair 1): /xui words that main's XayaUI Bonus Features never registers.

What went wrong (found by the harness play session, tests/harness/scenario.lua, and settings_seam B after the merge of main fda1e293):
core's list of feature addons (XayaUI/Modules.lua ns.MODULES) still gave XayaUI_Bonus the words of the old qa-installer-branch Bonus
(notes, notepad, note, data, calc, calculator). Main's XayaUI_Bonus is a different addon under the same folder name: it registers only
/xui stats (XayaUI_Bonus/StatCalculatorLoader.lua: ns.RegisterCommand("stats", ...)). So with main's Bonus loaded, /xui data and
/xui notes printed in chat: "/xui data did not respond: XayaUI Bonus Features is loaded, but the command was never registered. /xui bug
shows errors." (a false error line, pointing to /xui bug, which is not there while Advanced Debugging is off), and with Bonus switched off
they told the player to turn on Bonus Features, which has no notepad or data panel on main.

What the player sees, checked here with the real addons in the stand-in game, once with every addon on (Bonus loaded) and once with
XayaUI Bonus Features (and its Stat Calculator) installed but switched off in the AddOns list:
  1. /xui notes, /xui notepad, /xui note and /xui data print /xui help in chat (the same as any other word no addon on main has), never a
     "never registered" line and never a line sending the player to XayaUI Bonus Features.
  2. /xui stats, the one word main's Bonus registers, still answers as before: with Bonus on, the Stat Calculator's own line (it is off on
     a fresh install); with Bonus off, the line main's own tests expect (tests/console_commands_run.py).
/xui calc and /xui calculator are left as they were: tests/audit_core_run.py D8 checks that they name XayaUI Bonus Features, so changing
them is Xaya's decision (reported NEEDS_HER_DECISION). Their current output is printed below as INFO lines, not counted as a pass.
Negative control: on the merge commit 6321e10d (Modules.lua with the old Bonus words) checks 1 fail in both runs.
Run: python3 tests/fix_r9_merge_bonus_words_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, bonusOn)
local R, INFO = {}, {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- what one /xui command prints in the chat window (the game's print, as the harness play session reads it)
local function chat(s)
  local before = #W.printed
  SlashCmdList.XAYAUI(s); W.tick(0.1, 2)
  local out = {}
  for i = before + 1, #W.printed do out[#out + 1] = plain(W.printed[i]) end
  return out
end
local loaded = C_AddOns.IsAddOnLoaded("XayaUI_Bonus") and true or false
check("setup: XayaUI Bonus Features is " .. (bonusOn and "loaded" or "not loaded (switched off)"), loaded == bonusOn, loaded)
local help = chat("help")
check("setup: /xui help prints a header line", help[1] ~= nil and help[1]:find("commands (", 1, true) ~= nil, help[1])
local where = bonusOn and "with Bonus Features on" or "with Bonus Features switched off"
for _, w in ipairs({ "notes", "notepad", "note", "data" }) do
  local out = chat(w)
  local text = table.concat(out, "\n")
  check(("/xui %s %s: no 'never registered' line"):format(w, where), not text:find("never registered", 1, true), out[1])
  check(("/xui %s %s: does not send the player to XayaUI Bonus Features"):format(w, where), not text:find("Bonus Features", 1, true), out[1])
  check(("/xui %s %s: prints /xui help, as any word no addon has"):format(w, where), #out == #help and out[1] == help[1], out[1])
end
local st = chat("stats")
if bonusOn then
  check("/xui stats with Bonus Features on: the Stat Calculator answers (off on a fresh install)",
    st[1] == "XayaUI: Stat Calculator is off. Turn it on in Bonus Features > Stat Calculator (or /xui stats on), then /reload.", st[1])
else
  check("/xui stats with Bonus Features switched off: core's line for it, as main's tests expect",
    st[1] ~= nil and st[1]:find("/xui stats is part of ", 1, true) ~= nil, st[1])
end
for _, w in ipairs({ "calc", "calculator" }) do INFO[#INFO + 1] = ("/xui %s %s prints: %s"):format(w, where, tostring(chat(w)[1])) end
return R, INFO
end
'''


def run_once(bonus_on):
    folders = H.find_addons()
    enabled = [f for f in folders if bonus_on or not f.startswith("XayaUI_Bonus")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res, info = L.eval("function(src, W, Ld, b) return loadstring(src)()(W, Ld, b) end")(LUA, world, loader, bonus_on)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    for i in range(1, len(info) + 1):
        print("INFO (not checked; NEEDS_HER_DECISION) " + str(info[i]))
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", e[:600])
    return len(res), bad, len(errs)


def main():
    folders = H.find_addons()
    if "XayaUI_Bonus" not in folders:
        print("FAIL XayaUI_Bonus is not in this tree (this test covers main's Bonus Features after the merge)")
        print("1 checks, 1 failed")
        sys.exit(1)
    n1, b1, e1 = run_once(True)
    n2, b2, e2 = run_once(False)
    print("%d checks, %d failed, %d Lua errors" % (n1 + n2, b1 + b2, e1 + e2))
    sys.exit(1 if (b1 + b2 + e1 + e2) else 0)


if __name__ == "__main__":
    main()
