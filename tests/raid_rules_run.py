#!/usr/bin/env python3
"""Offline test (D8: core 0.6.70, Options 0.6.68, QoL 0.7.42): Release Guard as a built-in entry under Rules > "Raid Rules".
Xaya (docs/plans/D8-RAID-RULES-SPEC-2026-11-07.md, her words): "Rule drives the cover"; load "in instance - raid party size => 20";
"If it's not enabled it does not exist"; "It has to be enabled (it's not exactly a rule) and then the load conditions are applied after
enabling / disabling."; "It belongs in "Raid Rules" under rules"; "A group in the sidebar"; "Yes, built-in entry".
Checks, with the whole addon in the stand-in game:
- the old "Where" setting becomes a Load table (raid -> her default, group -> raid + dungeon, all -> her default: UI-58 "There also
  should not be an everywhere button"), the old value kept;
- the Load table decides (in a raid with 20 -> yes; 19 -> no; a dungeon -> no; the group size unreadable -> no);
- the sidebar: listed under Disabled while off, under Enabled > Loaded / Not Loaded while on, in the fixed RAID RULES group; never in
  ns.rules (so delete / export / duplicate / multi-select / drag / the engine never see it); its page has Settings and the rule Load tab,
  and that Load tab writes the guard's own table; the QoL tab no longer has it;
- "If it's not enabled it does not exist": with the guard off, building the whole options window makes no frame of it.
Negative control (V1): on the code before D8 there is no ns.LoadAllows, no Raid Rules entry and c.load stays a string: every check fails.
Run: python3 tests/raid_rules_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function try(name, fn) local ok, a, b = pcall(fn); if not ok then check(name, false, "error: " .. tostring(a)) else check(name, a, b) end end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 2)
ns = rawget(_G, "XayaUI_NS")
-- the game: a raid instance, group size settable
INST = { true, "raid" }
IsInInstance = function() return INST[1], INST[2] end
NG = 20
GetNumGroupMembers = function() if NG == "err" then error("no") end return NG end
-- 1) migration of the old "Where" value
local function migrate(old)
  CueRulesDB.releaseGuard = { enabled = false, load = old }
  local c = ns.ReleaseGuard_Cfg and ns.ReleaseGuard_Cfg()
  return c, c and c.load
end
try("migration: old 'raid' (the default) -> in an instance, Raid, at least 20 in the group; old value kept", function()
  local c, L = migrate("raid")
  return type(L) == "table" and L.instance == "yes" and L.instanceTypes.raid == true and L.instanceTypes.party == nil and L.groupMin == 20 and c.loadOld == "raid" end)
try("migration: old 'group' (raids and dungeons) -> in an instance, Raid or Dungeon, any size; old value kept", function()
  local c, L = migrate("group")
  return type(L) == "table" and L.instance == "yes" and L.instanceTypes.raid == true and L.instanceTypes.party == true and L.groupMin == nil and c.loadOld == "group" end)
try("migration: old 'all' (Everywhere; UI-58: no Everywhere) -> her default; old value kept", function()
  local c, L = migrate("all")
  return type(L) == "table" and L.instanceTypes.raid == true and L.groupMin == 20 and c.loadOld == "all" end)
try("never saved -> her default; a second read keeps what is there (no repeat migration)", function()
  CueRulesDB.releaseGuard = nil
  local c = ns.ReleaseGuard_Cfg()
  c.load.groupMin = 25
  local c2 = ns.ReleaseGuard_Cfg()
  return c2.load.groupMin == 25 and c2.load.instanceTypes.raid == true and c2.loadOld == nil end)
-- 2) the Load table decides
CueRulesDB.releaseGuard = { enabled = true }
local c = ns.ReleaseGuard_Cfg()
local function here() ns.configVersion = (ns.configVersion or 0) + 1; return ns.ReleaseGuard_LoadsHere and ns.ReleaseGuard_LoadsHere() end
INST, NG = { true, "raid" }, 20
check("in a raid with 20 people: the guard works", here() == true)
NG = 19
check("in a raid with 19 people: it does not", here() == false)
INST, NG = { true, "party" }, 25
check("in a dungeon with 25 people: it does not", here() == false)
INST, NG = { true, "raid" }, "err"
check("group size unreadable: it does not (unknown, never a guess)", here() == false)
NG = 20
-- 3) the sidebar
local function tree() return ns.BuildOptionsTable() end
local function node(t, ...) local g = t; for _, k in ipairs({ ... }) do g = type(g) == "table" and type(g.args) == "table" and g.args[k] or nil end return g end
c.enabled = false
local T = tree()
check("off: listed under Disabled", node(T, "cooldowns", "disabledTab", "disabled", "releaseguard") ~= nil)
check("off: not under Enabled", node(T, "cooldowns", "enabledTab", "loaded", "releaseguard") == nil and node(T, "cooldowns", "enabledTab", "notloaded", "releaseguard") == nil)
c.enabled = true
T = tree()
check("on, in a raid of 20: listed under Enabled > Loaded", node(T, "cooldowns", "enabledTab", "loaded", "releaseguard") ~= nil
  and node(T, "cooldowns", "disabledTab", "disabled", "releaseguard") == nil)
NG = 5; ns.configVersion = (ns.configVersion or 0) + 1
T = tree()
check("on, 5 in the group: listed under Enabled > Not Loaded", node(T, "cooldowns", "enabledTab", "notloaded", "releaseguard") ~= nil)
NG = 20
local rr = node(T, "cooldowns", "smartTab", "raidrules")
check("a fixed RAID RULES group in the sidebar, holding Release Guard", rr ~= nil and rr.name == "RAID RULES" and node(rr, "releaseguard") ~= nil)
local e = node(rr, "releaseguard")
local function deep(g, key, d)
  d = d or 0
  if type(g) ~= "table" or type(g.args) ~= "table" or d > 6 then return nil end
  if g.args[key] then return g.args[key] end
  for _, v in pairs(g.args) do local x = deep(v, key, d + 1); if x then return x end end
end
check("its page: Settings (on / off, text, flavour texts, key) and the rule Load tab", e and node(e, "settings", "enabled") and node(e, "settings", "text")
  and node(e, "settings", "flavors") and node(e, "settings", "modifier") and node(e, "load", "groupMin") and deep(node(e, "load"), "instanceTypes") and true or false)
local nr = #(ns.rules or {})
local inRules = false
for _, r in ipairs(ns.rules or {}) do if r == c then inRules = true end end
check("not a rule record (delete / export / duplicate / multi-select / drag and the engine work on ns.rules only)", not inRules and #(ns.rules or {}) == nr)
try("the Load tab writes the guard's own table (People in my group: 25, then 0 = any)", function()
  local g = node(e, "load", "groupMin")
  g.set(nil, 25); local a = c.load.groupMin
  g.set(nil, 0)
  local ok = a == 25 and c.load.groupMin == nil
  c.load.groupMin = 20
  return ok, tostring(a) end)
try("the on / off on its page is the guard's own switch", function()
  local t = node(e, "settings", "enabled")
  t.set({}, false); local off = c.enabled == false
  t.set({}, true)
  return off and c.enabled == true end)
check("the QoL tab has no Release Guard page any more", node(T, "qol", "releaseguard") == nil)
-- 4) "If it's not enabled it does not exist" with the options window built
c.enabled = false; if ns.ReleaseGuard_Apply then ns.ReleaseGuard_Apply() end
tree()
check("off: building the whole options window makes no Release Guard frame", rawget(_G, "XayaUIReleaseGuard") == nil)
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
