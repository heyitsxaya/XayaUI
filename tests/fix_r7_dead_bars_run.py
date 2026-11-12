#!/usr/bin/env python3
"""Offline test (round 7, engine-b; V34 audit "Core code that serves only retired QA-branch addons", Rules: "the dead buff-bars hook:
Engine.lua ~979-984 calls ns.Bars_Update, which is never defined" and "ns.VisualDebug (Visual.lua ~4150+)"). What the player gets: the
rule engine runs no code for the retired buff bars and offers no hook for them. Before, every full re-check of the rules looked up
ns.Bars_Update (no file on main defines it) and, had anything put a function there, called it inside the engine's step, timed it and
printed "bars error: ..." to chat when it failed; the engine's database-ready step called ns.Bars_OnDBReady the same way; Visual.lua
kept ns.VisualDebug, a Dev Assist helper nothing on main calls.
Checked: a function planted at ns.Bars_Update / ns.Bars_OnDBReady is never called by a full re-check, at login or by /xui enable, and
ns.VisualDebug is gone. (The buff-bar defaults and set-up in RuleDefaults.lua stay: XayaUI_Rules/RuleShare.lua's backups and import
and the rule editor's Buff Bars pane still read them; see the round-7 report.)
Run: python3 tests/fix_r7_dead_bars_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
local ns = rawget(_G, "XayaUI_NS")
local calls = { update = 0, ready = 0 }
-- planted before login, as another addon could
ns.Bars_Update = function() calls.update = calls.update + 1 end
ns.Bars_OnDBReady = function() calls.ready = calls.ready + 1 end
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local r = ns.NewRule(); r.name = "a rule"; r.enabled = true
r.useBuff, r.buffID, r.buffState, r.cdState = true, 1001, "present", "none"
ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
ns.MarkDirty(); W.tick(1 / 60, 6)
W.enterCombat(); W.tick(1 / 60, 6); W.leaveCombat(); W.tick(1 / 60, 6)
if ns.OnDBReady then ns.OnDBReady() end; W.tick(1 / 60, 6)
ns.SetRulesDisabled(true); W.tick(1 / 60, 3); ns.SetRulesDisabled(false); W.tick(1 / 60, 6)
check("a function at ns.Bars_Update is never called by the engine (login, a settings change, combat start / end, /xui enable)",
  calls.update == 0, calls.update .. " calls")
check("a function at ns.Bars_OnDBReady is never called by the engine's database-ready step", calls.ready == 0, calls.ready .. " calls")
check("ns.VisualDebug (a Dev Assist helper nothing on main calls) is gone", ns.VisualDebug == nil, type(ns.VisualDebug))
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
        print(("ok  " if ok else "FAIL: ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
