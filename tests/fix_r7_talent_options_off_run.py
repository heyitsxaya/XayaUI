#!/usr/bin/env python3
"""Bundle 1 round 7, relocate repair: /xui debug talents with XayaUI Options switched off or not installed is never silent.
Since round 7 the talent scan's code is part of XayaUI Options (REQUEST-LOG A23 SD-58, her words: "Move all four (Recommended)"), and
XayaUI_Rules/TalentDump.lua only loads it. With XayaUI Options switched off, the first use printed core's once-per-session line
("the settings window (XayaUI Options) is switched off ...", which does not name the command) and every later use printed NOTHING
(round 7 relocate review, blocker (b); its probe r7rev-relocate/tools/probe_talents.py). Whether the command should work without XayaUI
Options at all is Xaya's decision (relocate repair report, NEEDS_HER_DECISION); this test covers only that it is never silent and says
what it needs.
What the player gets, on the real addons in the stand-in game (tests/harness), her saved talent scan present:
  T1 XayaUI Options switched off: "/xui debug talents status" twice, "/xui debug talents battle" and "/xui debug talents": each prints
     exactly one line, and it names the command and says XayaUI Options is switched off and how to turn it on.
  T2 ... in combat: "/xui debug talents status" prints that same line at once (not "will be shown when combat ends", which could never
     happen while XayaUI Options is off), and nothing more when combat ends.
  T3 ... her saved scan (XayaUITalentDB) is unchanged, no Lua error, the settings window's code did not load.
  T4 XayaUI Options not installed: one line naming the command and saying where the XayaUI_Options folder belongs, on every use.
  C  control, XayaUI Options on: "/xui debug talents status" prints her saved scan's summary (the path is unchanged).
Fails on the files before this repair (proved on a copy of the working tree before the repair, r7copy-relocate-repair: the second status,
the search and the scan print nothing, and the first prints core's line, which does not name the command). UNVERIFIED IN GAME.
Run: python3 tests/fix_r7_talent_options_off_run.py   (Lua 5.1 via lupa)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

SCAN = {"built": "2026-11-06 21:20", "build": 120105, "errors": {},
        "classes": {1: {"name": "Warrior", "token": "WARRIOR", "specs": {71: "Arms"},
                        "nodes": {9001: {"t": 0, "max": 1, "scope": "class", "specs": {71: True},
                                         "e": [{"entry": 1, "spell": 6673, "name": "Battle Shout"}]}}}}}

OFF_LINE = ("/xui debug talents is part of the settings window (XayaUI Options), which is switched off. "
            "Turn it on in the game's AddOns list, then /reload.")
MISSING_LINE = ("/xui debug talents is part of the settings window (XayaUI Options), which is not installed: "
                "the XayaUI_Options folder belongs next to XayaUI in Interface\\AddOns.")

LUA = r'''
return function(W, L, mode, OFF, MISSING)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local said = {}
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end
local function run(cmd) said = {}; SlashCmdList.XAYAUI(cmd); W.tick(0.1, 3); return table.concat(said, " / ") end
local function one(line) return #said == 1 and said[1] == line end
if mode == "on" then
  local got = run("debug talents status")
  check("C control, XayaUI Options on: status prints her saved scan's summary", got:find("Last talent scan 2026-11-06 21:20 (build 120105): 1 classes, 1 nodes.", 1, true) ~= nil, got)
elseif mode == "optoff" then
  local cmds = { "debug talents status", "debug talents status", "debug talents battle", "debug talents" }
  for i, c in ipairs(cmds) do
    local got = run(c)
    check(("T1 Options off, use %d '/xui %s': exactly one line, naming the command and saying XayaUI Options is switched off"):format(i, c), one(OFF), got)
  end
  W.tick(0.1, 30)
  check("T1 ... and nothing more is printed afterwards", #said == 1, table.concat(said, " / "))
  W.enterCombat(); W.tick(0.05, 2)
  local got = run("debug talents status")
  check("T2 in combat, Options off: status prints that same line at once", one(OFF), got)
  W.leaveCombat(); W.tick(0.1, 20)
  check("T2 ... and nothing more when combat ends", #said == 1, table.concat(said, " / "))
  check("T3 her saved scan is unchanged", type(XayaUITalentDB) == "table" and XayaUITalentDB.built == "2026-11-06 21:20" and XayaUITalentDB.classes[1].name == "Warrior")
  check("T3 the settings window's code did not load", not C_AddOns.IsAddOnLoaded("XayaUI_Options"))
elseif mode == "optmissing" then
  for i, c in ipairs({ "debug talents status", "debug talents status", "debug talents" }) do
    local got = run(c)
    check(("T4 Options not installed, use %d '/xui %s': exactly one line, saying where the XayaUI_Options folder belongs"):format(i, c), one(MISSING), got)
  end
end
check("no Lua error (" .. mode .. ")", #W.errors == 0, W.errors[1])
end)
if not okAll then R[#R + 1] = { "the run itself finished (" .. mode .. ")  [" .. tostring(errAll) .. "]", false } end
return R
end
'''


def go(mode):
    folders = H.find_addons()
    if mode == "optmissing":
        folders.pop("XayaUI_Options", None)   # the folder is not installed
    names = list(folders)
    enabled = [n for n in names if not (mode == "optoff" and n == "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled},
                     "saved": {"XayaUI_Rules": {"XayaUITalentDB": SCAN}}}))
    res = L.eval("function(src, W, Ld, m, a, b) return loadstring(src)()(W, Ld, m, a, b) end")(LUA, world, loader, mode, OFF_LINE, MISSING_LINE)
    out = []
    for i in range(1, len(res) + 1):
        out.append((res[i][1], bool(res[i][2])))
    return out


def main():
    results = []
    for m in ("on", "optoff", "optmissing"):
        results += go(m)
    failed = 0
    for name, ok in results:
        print(("ok    " if ok else "FAIL: ") + name)
        if not ok:
            failed += 1
    print("fix_r7_talent_options_off: %d checks, %d failed" % (len(results), failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
