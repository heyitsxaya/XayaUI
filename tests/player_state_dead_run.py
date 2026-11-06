#!/usr/bin/env python3
"""Offline test (core 0.6.56, D8): Player State "Dead, not released". Xaya, 2026-11-06 (D8): the DO NOT RELEASE rule "fires while dead and
NOT released" and hides as a ghost. Checks the trigger's answer: alive -> no; dead and not released -> yes; released (a ghost) -> no; either
game answer unreadable (secret / missing) -> unknown (never a guess); it is offered in the Player State list after Alive.
Run: python3 tests/player_state_dead_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
local T = ns.TriggerShared.TYPES.playerState
local vals = T.fields[1].vals
check("'Dead, not released' is offered, right after Alive", vals.values.deadBody == "Dead, not released" and vals.order[1] == "alive" and vals.order[2] == "deadBody")
local function ans(dead, ghost)
  UnitIsDead = function() return dead end
  UnitIsGhost = function() return ghost end
  return T.check({ what = "deadBody", state = "yes" }), T.check({ what = "deadBody", state = "no" })
end
local y, n = ans(false, false)
check("alive: 'Dead, not released' = Yes is false (and = No is true)", y == false and n == true, tostring(y) .. "/" .. tostring(n))
y, n = ans(true, false)
check("dead, not released: Yes is true", y == true and n == false, tostring(y) .. "/" .. tostring(n))
y, n = ans(true, true)
check("released (a ghost): Yes is false", y == false and n == true, tostring(y) .. "/" .. tostring(n))
y, n = ans(false, true)
check("a ghost the game does not call dead: Yes is false", y == false, tostring(y))
UnitIsDead = function() error("no") end; UnitIsGhost = function() return false end
y, n = T.check({ what = "deadBody", state = "yes" }), T.check({ what = "deadBody", state = "no" })
check("unreadable: unknown, neither yes nor no", y == nil and n == nil, tostring(y) .. "/" .. tostring(n))
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
