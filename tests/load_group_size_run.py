#!/usr/bin/env python3
"""Offline test (core 0.6.59, Options): D8 part 2, the load condition "People in my group: at least N". Xaya, 2026-11-06: the DO NOT RELEASE
load "in instance - raid party size => 20"; her answer "People in my group".
Checks the load decision: not set (or 0 / 1) has no bearing; set to 20 the rule loads with 20 or more players in the group, not with 19, and
not solo; the group size unreadable -> unknown (does not load); the rule Load tab has the control and it writes the setting.
Run: python3 tests/load_group_size_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 2)
ns = rawget(_G, "XayaUI_NS")
ns.folders = {}
local r = ns.NewRule(); r.name = "G"; r.enabled = true; ns.NormalizeRule(r); ns.rules = { r }
local function loads(n) GetNumGroupMembers = function() return n end; local ok = ns.CheckContext(r, ns.ReadContext()); return ok == true end
check("not set: loads solo and in any group", loads(0) and loads(5) and loads(25))
r.load.groupMin = 20; ns.configVersion = (ns.configVersion or 0) + 1
check("at least 20: loads with 20 and 25 players", loads(20) and loads(25))
check("... not with 19, not solo", not loads(19) and not loads(0))
GetNumGroupMembers = function() error("no") end
check("group size unreadable: does not load (unknown, never a guess)", ns.CheckContext(r, ns.ReadContext()) ~= true)
r.load.groupMin = nil
local built = ns.BuildOptionsTable()
local ctl
local function find(t, d)
  if type(t) ~= "table" or d > 40 or ctl then return end
  if t.args and t.args.groupMin and t.args.groupMin.type == "range" then ctl = t.args.groupMin; return end
  for _, v in pairs(t.args or {}) do find(v, d + 1) end
end
find(built, 0)
check("the rule Load tab has 'People in my group: at least (0 = any)'", ctl ~= nil and tostring(ctl.name):find("People in my group", 1, true) ~= nil)
if ctl then
  ctl.set(nil, 20)
  local set20 = r.load.groupMin == 20
  ctl.set(nil, 0)
  check("the control sets 20 and clears to 'any'", set20 and r.load.groupMin == nil and ctl.get() == 0)
end
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
