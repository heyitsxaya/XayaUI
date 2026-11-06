#!/usr/bin/env python3
"""Offline test (#18): a load option that is not set has no bearing on loading. Xaya, 2026-11-06 (her answer to #18): "If instance type is
not specified, it has no bearing on the rule loading and firing and should not be considered. This is true for all options that are not
outright specified in some way".
Checks the load decision (ns.CheckContext) of a rule with nothing set: it loads whatever every yes / no load fact reads (true, false or
unknown) and whatever the instance type, class, spec, role and hero tree are; then, for every yes / no option one at a time, setting it
restricts by that option only (the others still have no bearing), including #18's case: "Only during a Mythic+" / "Only during a boss
encounter" / instance type Raid set while "Instance" is not.
Run: python3 tests/unset_load_no_bearing_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
ns.folders = {}
local r = ns.NewRule(); r.name = "Nothing set"; r.enabled = true; ns.NormalizeRule(r)
local base = ns.ReadContext()
local function ctx(over)
  local c = {}
  for k, v in pairs(base) do c[k] = v end
  c.sig = nil
  for k, v in pairs(over or {}) do if v == "nil" then c[k] = nil else c[k] = v end end
  return c
end
local function loads(rule, over) local ok, why = ns.CheckContextRaw and ns.CheckContextRaw(rule, ctx(over)) or ns.CheckContext(rule, ctx(over)); return ok == true, why end
-- 1. nothing set: loads in every combination of facts
local allOK, bad = true, ""
for _, c in ipairs(ns.LOAD_TRI) do
  for _, v in ipairs({ true, false, "nil" }) do
    local ok, why = loads(r, { [c.key] = v })
    if not ok then allOK = false; bad = bad .. c.key .. "=" .. tostring(v) .. ":" .. tostring(why) .. " " end
  end
end
for _, it in ipairs({ "none", "party", "raid", "pvp", "arena", "scenario", "nil" }) do
  local ok, why = loads(r, { instanceType = it })
  if not ok then allOK = false; bad = bad .. "instanceType=" .. it .. ":" .. tostring(why) .. " " end
end
for _, over in ipairs({ { class = "WARRIOR" }, { class = "nil" }, { specID = 1 }, { specID = "nil" }, { role = "HEALER" }, { role = "nil" }, { hero = 0 }, { hero = "nil" } }) do
  local ok, why = loads(r, over)
  if not ok then allOK = false; bad = bad .. tostring(next(over)) .. ":" .. tostring(why) .. " " end
end
check("nothing set: loads whatever every load fact reads (" .. #ns.LOAD_TRI .. " yes / no facts x true / false / unknown, instance type, class, spec, role, hero tree)", allOK, bad)
-- 2. one option set at a time: it alone restricts
local oneOK, bad2 = true, ""
for _, c in ipairs(ns.LOAD_TRI) do
  r.load[c.key] = "yes"
  local okT = loads(r, { [c.key] = true })
  local okF = loads(r, { [c.key] = false })
  -- the others keep reading anything: flip every other fact to false and the rule still loads when this one is true
  local over = { [c.key] = true }
  for _, o in ipairs(ns.LOAD_TRI) do if o.key ~= c.key then over[o.key] = false end end
  local okOthers = loads(r, over)
  if not (okT and not okF and okOthers) then oneOK = false; bad2 = bad2 .. c.key .. " " end
  r.load[c.key] = nil
  ns.NormalizeRule(r)
end
check("each yes / no option set alone restricts by that option only (every other unset option still has no bearing)", oneOK, bad2)
-- 3. #18's case: Mythic+ / boss encounter / instance type set while "Instance" is not set
r.load.mythicPlus = "yes"
check("#18: 'Only during a Mythic+' set, 'Instance' not set: loads during a Mythic+, whatever 'Instance' reads", loads(r, { mythicPlus = true, instance = false })
  and loads(r, { mythicPlus = true, instance = "nil" }) and not loads(r, { mythicPlus = false, instance = true }))
r.load.mythicPlus = nil; r.load.encounter = "yes"
check("#18: 'Only during a boss encounter' set, 'Instance' not set: the encounter alone decides", loads(r, { encounter = true, instance = false })
  and not loads(r, { encounter = false, instance = true }))
r.load.encounter = nil; r.load.instanceTypes = { raid = true }
check("#18: instance type Raid set, 'Instance' not set: the instance type alone decides", loads(r, { instanceType = "raid", instance = false })
  and not loads(r, { instanceType = "party", instance = true }))
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
