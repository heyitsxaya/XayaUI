#!/usr/bin/env python3
"""Offline test (core 0.6.56, Options 0.6.55): #2, the per-talent Known / Not known control is a three-click toggle. Xaya, 2026-11-06
(her answer to #2): "three-click toggle (Known green / Not known red / not set)".
Checks what she sees and what loads: the talent row's control reads "Known" in green, one click "Not known" in red, another "Not set", a
third back to Known (AceGUI's tri-state order true -> nil -> false); a talent "Not set" has no bearing on loading (#18), Known / Not known
still decide; a talent saved before (no state) still reads as Known.
Run: python3 tests/talent_tri_toggle_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
local known = { [111] = true, [222] = false }
ns.ReadTalentKnown = function(id) return known[id] end
local r = ns.NewRule(); r.name = "Talent rule"; r.enabled = true; ns.NormalizeRule(r)
r.talentMode = "all"; r.talents = { { id = 111 } }   -- saved before: no state
ns.rules = { r }
local ok1 = ns.CheckTalents(r)
check("a talent saved without a state still reads as Known (picked -> loads)", ok1 == true)
known[111] = false
check("... and not picked -> does not load", ns.CheckTalents(r) == false)
r.talents[1].state = "none"
check("'Not set': no bearing (loads whether or not the talent is picked)", ns.CheckTalents(r) == true)
r.talents[1].state = "notKnown"
check("'Not known': loads only while the talent is not picked", ns.CheckTalents(r) == true)
known[111] = true
check("... and not while it is picked", ns.CheckTalents(r) == false)
-- the control in the Load tab
r.talents[1].state = nil
local built = ns.BuildOptionsTable()
local ctl
local function find(t, d)
  if type(t) ~= "table" or d > 40 or ctl then return end
  if t.args and t.args.talent1 and t.args.talent1.args and t.args.talent1.args.state then ctl = t.args.talent1.args.state; return end
  for _, v in pairs(t.args or {}) do find(v, d + 1) end
end
find(built, 0)
check("the talent row has the three-state control", ctl ~= nil and ctl.type == "toggle" and ctl.tristate == true)
if not ctl then return R end
local function nm() return type(ctl.name) == "function" and ctl.name() or ctl.name end
check("starts as 'Known' in green", nm() == "|cff55ff55Known|r" and ctl.get() == true, nm())
-- AceGUI's click order for a tri-state box: true -> nil -> false -> true
ctl.set(nil, nil)
check("one click: 'Not known' in red", nm() == "|cffff5555Not known|r" and r.talents[1].state == "notKnown" and ctl.get() == nil, nm())
ctl.set(nil, false)
check("another click: 'Not set'", nm() == "Not set" and r.talents[1].state == "none" and ctl.get() == false, nm())
ctl.set(nil, true)
check("a third click: back to 'Known'", nm() == "|cff55ff55Known|r" and r.talents[1].state == "known")
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
