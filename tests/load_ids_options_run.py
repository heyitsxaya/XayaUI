#!/usr/bin/env python3
"""The settings side of the ID-list load conditions (Options 0.6.25 with core 0.6.28): a rule's Load tab has a box "Zones, Instances,
Bosses and Items" with one text box per list (zones, instances, difficulties, sizes, boss encounters, equipped items), "Add current"
buttons that read where you are, a difficulty menu named by the game, and an item search. Builds the real settings tree in the
stand-in game (tests/harness) and drives the rows.
Run: python3 tests/load_ids_options_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- the stand-in place: room 31 in city 30 (the world's own C_Map gives one map with no parent), a named difficulty list
C_Map.GetBestMapForUnit = function() return 31 end
C_Map.GetMapInfo = function(id) local n = ({ [31] = "Room", [30] = "City" })[id]; if n then return { mapID = id, name = n, parentMapID = (id == 31) and 30 or 0 } end end
GetInstanceInfo = function() return "A dungeon", "party", 8, "Mythic Keystone", 5, 0, false, 2649, 0, nil, false end
GetDifficultyInfo = function(id) local n = ({ [1] = "Normal", [8] = "Mythic Keystone", [16] = "Mythic" })[id]; if n then return n, (id == 16) and "raid" or "party" end end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded (ns.BuildOptionsTable)", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end

-- text <-> list
local s = ns.LoadIdParse("2339, -2552 x 7;12")
check("'2339, -2552 x 7;12' reads as 2339, 7 and 12 (one of these) and 2552 (not)",
  s and s["2339"] == true and s["2552"] == "not" and s["7"] == true and s["12"] == true, ns.LoadIdText(s))
check("and is written back sorted, the 'not' ones last: '7, 12, 2339, -2552'", ns.LoadIdText(s) == "7, 12, 2339, -2552", ns.LoadIdText(s))
check("an empty box is no list (nil)", ns.LoadIdParse("") == nil and ns.LoadIdParse("  ,  ") == nil)

local function mk(name, load)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.load = r.load or {}
  for k, v in pairs(load or {}) do r.load[k] = v end
  ns.NormalizeRule(r); return r
end
local plain, withIds = mk("plain"), mk("with ids", { mapIDs = { ["30"] = true } })
ns.folders = { { id = "fA", name = "Always group", loadOverride = "always" } }
local locked = mk("in an Always group"); locked.folder = "fA"
ns.rules = { plain, withIds, locked }
local built = ns.BuildOptionsTable()
local function find(root, pred)
  local seen, stack = {}, { root }
  while #stack > 0 do
    local t = table.remove(stack)
    if type(t) == "table" and not seen[t] then
      seen[t] = true
      if pred(t) then return t end
      for _, v in pairs(t) do if type(v) == "table" then stack[#stack + 1] = v end end
    end
  end
end
local function ruleGroup(rule)   -- the rule's own group: the one whose Load tab's box reads this rule's lists
  return find(built, function(t) return t.args and t.args.load and t.args.load.args and t.args.load.args.loadIds
    and t.args.load.args.loadIds.xuiRule == rule end)
end
local function box(rule) local g = ruleGroup(rule); return g and g.args.load.args.loadIds end
local B1, B2, B3 = box(plain), box(withIds), box(locked)
check("every rule's Load tab has the box, tagged with its rule", B1 ~= nil and B2 ~= nil and B3 ~= nil)
if not (B1 and B2 and B3) then return R end
local body = B1.args.body.args
check("the box holds one text box per list",
  body.ids_mapIDs and body.ids_instanceIDs and body.ids_difficulties and body.ids_sizes and body.ids_encounterIDs and body.ids_equipped)
check("a rule with no list: the box starts closed", B1.args.body.hidden() == true)
check("a rule with a zone list: the box starts open", B2.args.body.hidden() == false)
check("the zone box shows the rule's list as text", B2.args.body.args.ids_mapIDs.get() == "30", B2.args.body.args.ids_mapIDs.get())
body.ids_sizes.set(nil, "5, -25")
check("typing '5, -25' in the sizes box stores 5 (one of these) and 25 (not)",
  plain.load.sizes and plain.load.sizes["5"] == true and plain.load.sizes["25"] == "not")
body.ids_sizes.set(nil, "")
check("emptying the box removes the list", plain.load.sizes == nil)
check("'Here' reads the room with its name", body.now_mapIDs.name() == "Here: Room (31)", body.now_mapIDs.name())
body.add_mapIDs.func()
check("Add current adds the room's map ID", plain.load.mapIDs and plain.load.mapIDs["31"] == true)
check("'Here' reads the instance, the difficulty (named by the game) and the size",
  body.now_instanceIDs.name() == "Here: A dungeon (2649)" and body.now_difficulties.name() == "Here: Mythic Keystone (8)" and body.now_sizes.name() == "Here: 5",
  body.now_instanceIDs.name() .. " | " .. body.now_difficulties.name() .. " | " .. body.now_sizes.name())
local v, o = ns.DifficultyChoices()
check("the difficulty menu lists the game's names with their IDs", v["16"] and v["16"]:find("Mythic", 1, true) and v["16"]:find("16", 1, true) and #o == 3, v["16"])
body.pick_difficulties.set(nil, "16")
check("picking Mythic (16) in the menu adds 16", plain.load.difficulties and plain.load.difficulties["16"] == true)
check("no boss pulled yet: 'Here: unknown' for encounters, Add current greyed out",
  body.now_encounterIDs.name() == "Here: unknown" and body.add_encounterIDs.disabled() == true, body.now_encounterIDs.name())
ns.LoadEvent("ENCOUNTER_START", 3009, "A boss", 8, 5); W.tick(0.1, 1)   -- the "Here" values are read once per frame
check("during a pull: 'Here' names the boss, Add current adds it",
  body.now_encounterIDs.name() == "Here: A boss (3009)" and (body.add_encounterIDs.func() or true) and plain.load.encounterIDs and plain.load.encounterIDs["3009"] == true,
  body.now_encounterIDs.name())
ns.LoadEvent("ENCOUNTER_END", 3009); W.tick(0.1, 1)
check("after the pull: Add current offers the last boss pulled", body.now_encounterIDs.name():find("last pulled", 1, true) ~= nil, body.now_encounterIDs.name())
check("items: an item search adds to the equipped list",
  body.search_equipped and body.search_equipped.arg and type(body.search_equipped.arg.xuiSearch) == "function")
body.search_equipped.arg.xuiSearch(19019)
check("  ...and the picked item is in the list", plain.load.equipped and plain.load.equipped["19019"] == true)
local b3 = B3.args.body.args
check("a rule in an Always group: every row is greyed out",
  b3.ids_mapIDs.disabled() == true and b3.add_mapIDs.disabled() == true and b3.pick_difficulties.disabled() == true and b3.search_equipped.disabled() == true)
check("a rule in no such group: the rows are usable", body.ids_mapIDs.disabled() == false and body.pick_difficulties.disabled() == false)
-- the lists reach the core's load check
local ok1 = ns.CheckContext(withIds, ns.ReadContext())
withIds.load.mapIDs = { ["30"] = "not" }; ns.configVersion = (ns.configVersion or 0) + 1
local ok2 = ns.CheckContext(withIds, ns.ReadContext())
check("the core uses the list: city 30 loads in its room; '-30' does not", ok1 == true and ok2 == false, tostring(ok1) .. " " .. tostring(ok2))
-- a group's Load tab has the same lists (core 0.6.33)
local fG = { id = "fG", name = "Raid auras" }
local gl = ns.FolderLoadConditions(fG)
local gArgs = gl and gl.args and gl.args.loadIds and gl.args.loadIds.args
check("a group's 'Only Load This Group When' has the same lists", gArgs and gArgs.ids_mapIDs and gArgs.ids_encounterIDs and gArgs.ids_equipped)
if gArgs then gArgs.ids_difficulties.set(nil, "16, -17") end
check("typing in the group's difficulty box stores the list on the group", fG.loadIds and fG.loadIds.difficulties and fG.loadIds.difficulties["16"] == true and fG.loadIds.difficulties["17"] == "not")
-- a core without the new load code (older core folder): a note instead of an error
local keep = ns.LoadPlaceNow; ns.LoadPlaceNow = nil; W.tick(0.1, 1)
local okI, txt = pcall(body.intro.name)
local okH, here = pcall(body.now_mapIDs.name)
ns.LoadPlaceNow = keep
check("core without LoadPlaceNow: the box says core 0.6.28 is needed, and 'Here' reads unknown (no error)",
  okI and txt:find("0.6.28", 1, true) ~= nil and okH and here == "Here: unknown", tostring(txt) .. " | " .. tostring(here))
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
