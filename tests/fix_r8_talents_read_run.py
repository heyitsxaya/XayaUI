#!/usr/bin/env python3
"""Bundle 1 round 8, /xui debug talents status and the name search answer anytime (REQUEST-LOG A23 SD-67, her answer on them: "Read-only
answers anytime (Recommended)"; its row: "status and name search answer at once in or out of combat from a small reader kept with the
saved data in Rules; only the scan is locked and lives in Options"). V26: read-only /xui debug commands are exempt from the combat lock,
and "/xui debug talents changes state and is locked" (the scan). Round 7's relocate review: out of combat, "status" loaded all of XayaUI
Options just to print one line, and in combat it was held back until combat ended while XayaUI Options had not loaded yet.
What the player gets, on the real addons in the stand-in game, her saved talent scan present ([new] = fails on the pre-change files):
  A  [new] out of combat, XayaUI Options never loaded: "/xui debug talents status" prints her saved scan's summary at once, and XayaUI
     Options is not loaded for it (the window's code is not read); "/xui debug talents battle" finds the talent, also without loading it.
  B  [new] in combat right after the login, XayaUI Options never loaded: status and the name search answer at once, one line each, the exempt key
     "talentsRead" (core's V26 exempt list) is the one asked; nothing more is printed when combat ends and XayaUI Options stays unloaded.
  C  the scan in combat: exactly the lock line ("the talent scan can't run during combat. It will run when combat ends."), XayaUI Options
     not loaded in combat; when combat ends the scan runs (XayaUI Options loads then, out of combat, and the scan says it started).
  D  [new] XayaUI Options switched off: status and the name search still answer from the saved scan; the scan says in one line that it
     needs XayaUI Options.
  E  [new] no saved scan yet, in combat: status says "No talent scan saved yet." and the name search says to run the scan first, at once;
     the same out of combat.
  F  [new, repair 1] a damaged saved scan (fields of the wrong type: built and scope are tables, cd is a table, the class's spec-name
     list is a number, the class name and spell are missing): status and the name search still answer one line each, with "?" for what
     cannot be read and no cooldown text, and no Lua error. (Round 8 review: '/xui debug talents battle' stopped with
     "TalentDump.lua:47: attempt to concatenate field 'cd' (a table value)" on a saved scan with cd = {y=2}.)
UNVERIFIED IN GAME.
Run: python3 tests/fix_r8_talents_read_run.py   (Lua 5.1 via lupa)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

SCAN = {"built": "2026-11-06 21:20", "build": 120105, "errors": {},
        "classes": {1: {"name": "Warrior", "token": "WARRIOR", "specs": {71: "Arms"},
                        "nodes": {9001: {"t": 0, "max": 1, "scope": "class", "specs": {71: True},
                                         "e": [{"entry": 1, "spell": 6673, "name": "Battle Shout"}]}}}}}
SUMMARY = "Last talent scan 2026-11-06 21:20 (build 120105): 1 classes, 1 nodes."
HIT = "Warrior [class]: Battle Shout (spell 6673) - Arms"
LOCK = "the talent scan can't run during combat. It will run when combat ends."
DAMAGED = {"built": {"y": 1}, "build": {"x": 1}, "errors": {},
           "classes": {1: {"token": "WARRIOR", "specs": 7,
                           "nodes": {9001: {"t": 0, "max": 1, "scope": {"z": 1}, "specs": {71: True},
                                            "e": [{"entry": 1, "name": "Battle Shout", "cd": {"y": 2}, "passive": True}]}}},
                       2: "not a class", 3: {"name": "Mage", "nodes": "not nodes"}}}
DAMAGED_SUMMARY = "Last talent scan ? (build ?): 3 classes, 1 nodes."
DAMAGED_HIT = "? [?]: Battle Shout (spell ?) passive - 71"
OFF = ("/xui debug talents is part of the settings window (XayaUI Options), which is switched off. "
       "Turn it on in the game's AddOns list, then /reload.")

LUA = r'''
return function(W, L, mode, SUMMARY, HIT, LOCK, OFF)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local said = {}
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end
local keys = {}
local rawLock = ns.CombatLock
ns.CombatLock = function(key, ...) keys[#keys + 1] = tostring(key); return rawLock(key, ...) end
local function run(cmd) said = {}; keys = {}; SlashCmdList.XAYAUI(cmd); W.tick(0.1, 3); return table.concat(said, " / ") end
local function one(line) return #said == 1 and said[1] == line end
local function optionsLoaded() return C_AddOns.IsAddOnLoaded("XayaUI_Options") and true or false end
if mode == "on" then
  local got = run("debug talents status")
  check("[new] A out of combat: status prints her saved scan's summary, one line", one(SUMMARY), got)
  check("[new] A ... and XayaUI Options was not loaded for it", not optionsLoaded())
  got = run("debug talents battle")
  check("A out of combat: the name search finds the talent", one(HIT), got)
  check("[new] A ... and XayaUI Options is still not loaded", not optionsLoaded())
  W.enterCombat(); W.tick(0.05, 2)
  got = run("debug talents")
  check("C the scan in combat: exactly the lock line", one(LOCK), got)
  check("C ... through the locked key 'talents', and XayaUI Options is not loaded in combat", keys[1] == "talents" and not optionsLoaded(), table.concat(keys, ","))
  said = {}
  W.leaveCombat(); W.tick(0.1, 30)
  check("C when combat ends the scan runs: XayaUI Options loads then (out of combat) and the scan says it started",
    optionsLoaded() and said[1] == "Scanning all classes (about a second)...", table.concat(said, " / "))
elseif mode == "combatfirst" then
  W.enterCombat(); W.tick(0.05, 2)
  local got = run("debug talents status")
  check("[new] B in combat: status answers at once, one line", one(SUMMARY), got)
  check("[new] B ... through the exempt key 'talentsRead' (core's V26 list says why it is exempt)", keys[1] == "talentsRead"
    and ns.CombatLockExempt("talentsRead") ~= nil, table.concat(keys, ","))
  got = run("debug talents battle")
  check("[new] B in combat: the name search answers at once", one(HIT), got)
  said = {}
  W.leaveCombat(); W.tick(0.1, 20)
  check("[new] B when combat ends nothing more is printed (nothing was held back)", #said == 0, table.concat(said, " / "))
  check("[new] B ... and XayaUI Options is still not loaded", not optionsLoaded())
elseif mode == "optoff" then
  local got = run("debug talents status")
  check("[new] D XayaUI Options switched off: status answers from her saved scan", one(SUMMARY), got)
  got = run("debug talents battle")
  check("[new] D ... and the name search too", one(HIT), got)
  got = run("debug talents")
  check("D the scan says in one line that it needs XayaUI Options", one(OFF), got)
elseif mode == "damaged" then
  local got = run("debug talents status")
  check("[new] F damaged saved scan: status still answers one line, '?' for what cannot be read", one(SUMMARY), got)
  got = run("debug talents battle")
  check("[new] F damaged saved scan: the name search still finds the talent, '?' for what cannot be read, no cooldown text", one(HIT), got)
  W.enterCombat(); W.tick(0.05, 2)
  got = run("debug talents battle")
  check("[new] F ... the same in combat", one(HIT), got)
  W.leaveCombat(); W.tick(0.1, 5)
elseif mode == "noscan" then
  W.enterCombat(); W.tick(0.05, 2)
  local got = run("debug talents status")
  check("[new] E no saved scan, in combat: status says so at once", one("No talent scan saved yet."), got)
  got = run("debug talents battle")
  check("[new] E ... and the name search says to run the scan first", one("No talent scan saved yet - run /xui debug talents first."), got)
  W.leaveCombat(); W.tick(0.1, 5)
  got = run("debug talents status")
  check("E ... out of combat the same", one("No talent scan saved yet."), got)
end
check("no Lua error (" .. mode .. ")", #W.errors == 0, W.errors[1])
end)
if not okAll then R[#R + 1] = { "the run itself finished (" .. mode .. ")  [" .. tostring(errAll) .. "]", false } end
return R
end
'''


def go(mode):
    folders = H.find_addons()
    enabled = [n for n in folders if not (mode == "optoff" and n == "XayaUI_Options") and n != "XayaUI_Debug"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    saved = {} if mode == "noscan" else {"XayaUI_Rules": {"XayaUITalentDB": DAMAGED if mode == "damaged" else SCAN}}
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    summary, hit = (DAMAGED_SUMMARY, DAMAGED_HIT) if mode == "damaged" else (SUMMARY, HIT)
    res = L.eval("function(src, W, Ld, ...) return loadstring(src)()(W, Ld, ...) end")(LUA, world, loader, mode, summary, hit, LOCK, OFF)
    return [(res[i][1], bool(res[i][2])) for i in range(1, len(res) + 1)]


def main():
    results = []
    for m in ("on", "combatfirst", "optoff", "damaged", "noscan"):
        results += go(m)
    failed = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        failed += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
