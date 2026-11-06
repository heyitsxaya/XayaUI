"""More load conditions (Xaya 2026-11-04: "more load conditions we should include if they're supported by the current api").
A rule can load only in some zones (the game's map IDs, a zone also matching the maps inside it), some instances (instance IDs), some
difficulties, some instance sizes, some boss encounters (encounter IDs) and while some items are equipped. Every list also takes
"not" entries (a minus before the ID). Runs the real Core.lua and Conditions.lua on the stand-in game of tests/engine_bench.py, with
GetInstanceInfo, C_Map, C_Item.IsEquippedItem and the encounter events stood in here.
Calls (12.1.5 API reference, none marked secret): GetInstanceInfo (docs/reference/api/globals.md:188), C_Map.GetBestMapForUnit /
GetMapInfo (namespaces.md:3150 / 3166), C_Item.IsEquippedItem (namespaces.md:2814), ENCOUNTER_START / ENCOUNTER_END (events.md:560-562).
Run: python3 tests/load_ids_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute("SECRET = {}; function issecretvalue(v) return v ~= nil and SECRET[v] == true end")   # Conditions.lua keeps this function from load time
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
for f in ("XayaUI/Compat.lua", "XayaUI/Core.lua", "XayaUI/Conditions.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute(r'''
local ns = NS
ns.Print = function() end
ns.folders = {}
function ns.FolderById(id) for _, f in ipairs(ns.folders) do if f.id == id then return f end end end
-- the stand-in world: a map tree (a room inside a city inside a zone inside a continent) and an instance
MAPS = { [10] = { parentMapID = 0, name = "Continent" }, [20] = { parentMapID = 10, name = "Zone" },
         [30] = { parentMapID = 20, name = "City" }, [31] = { parentMapID = 30, name = "Room" }, [40] = { parentMapID = 10, name = "Other zone" } }
HERE = 31
C_Map = { GetBestMapForUnit = function(u) return HERE end,
          GetMapInfo = function(id) local m = MAPS[id]; if not m then return nil end; return { mapID = id, name = m.name, mapType = 3, parentMapID = m.parentMapID, flags = 0 } end }
INST = { name = "World", itype = "none", diff = 0, size = 0, id = 2552 }
GetInstanceInfo = function() return INST.name, INST.itype, INST.diff, "", INST.size, 0, false, INST.id, 0, nil, false end
IsInInstance = function() return INST.itype ~= "none", INST.itype end
IN_ENC = false
C_InstanceEncounter = { IsEncounterInProgress = function() return IN_ENC end }
WORN = {}
C_Item = C_Item or {}
C_Item.IsEquippedItem = function(id) return WORN[tonumber(id)] == true end
function ctxNow() return ns.ReadContext() end
function R(load) return { uid = "r", name = "r", enabled = true, load = load } end
function loads(rule) local ok, why = ns.CheckContext(rule, ctxNow()); return ok and true or false, why end
function fire(event, ...) ns.LoadEvent(event, ...) end
''')
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)
lua = lambda s: L.execute(s)

check("the core has the event handler this test drives", lua("return type(NS.LoadEvent) == 'function'"))

# zones (map IDs): the current map and every map it sits in
check("context: the current map and its parents (room 31 in city 30 in zone 20 in continent 10)",
      lua("local c = ctxNow(); local m = c.maps; return c.mapID == 31 and m and m[31] and m[30] and m[20] and m[10] and not m[40]"))
check("zone list with the city: loads in a room of that city", lua("return (loads(R({ mode = 'all', mapIDs = { ['30'] = true } })))"))
check("zone list with the continent: loads anywhere in it", lua("return (loads(R({ mode = 'all', mapIDs = { ['10'] = true } })))"))
check("zone list with another zone only: does NOT load, and says 'zone'",
      lua("local ok, why = loads(R({ mode = 'all', mapIDs = { ['40'] = true } })); return ok == false and why == 'zone'"))
check("'not' entry for the city: does NOT load inside it", lua("return (loads(R({ mode = 'all', mapIDs = { ['30'] = 'not' } }))) == false"))
check("'not' entry for another zone: loads here", lua("return (loads(R({ mode = 'all', mapIDs = { ['40'] = 'not' } })))"))
check("continent ticked, city marked 'not': does NOT load in the city", lua("return (loads(R({ mode = 'all', mapIDs = { ['10'] = true, ['30'] = 'not' } }))) == false"))
check("the game gives no map (loading screen): a zone list makes the answer unknown (does not load)",
      lua("HERE = nil; local ok, why = loads(R({ mode = 'all', mapIDs = { ['10'] = true } })); HERE = 31; return ok == false and why == 'zone (unknown)'"))

# instance ID, difficulty, size
lua("INST = { name = 'A dungeon', itype = 'party', diff = 8, size = 5, id = 2649 }")
check("context: instance ID, difficulty ID and size from GetInstanceInfo",
      lua("local c = ctxNow(); return c.instanceID == 2649 and c.difficultyID == 8 and c.instSize == 5"))
check("instance list with this dungeon: loads", lua("return (loads(R({ mode = 'all', instanceIDs = { ['2649'] = true } })))"))
check("instance list with another one: does NOT load ('instance ID')",
      lua("local ok, why = loads(R({ mode = 'all', instanceIDs = { ['2651'] = true } })); return ok == false and why == 'instance ID'"))
check("difficulty 8 ticked: loads; difficulty 23 only: does NOT",
      lua("return (loads(R({ mode = 'all', difficulties = { ['8'] = true } }))) and not (loads(R({ mode = 'all', difficulties = { ['23'] = true } })))"))
check("difficulty 8 marked 'not': does NOT load", lua("return (loads(R({ mode = 'all', difficulties = { ['8'] = 'not' } }))) == false"))
check("size 5 ticked: loads; size 20 only: does NOT",
      lua("return (loads(R({ mode = 'all', sizes = { ['5'] = true } }))) and not (loads(R({ mode = 'all', sizes = { ['20'] = true } })))"))
lua("INST = { name = 'World', itype = 'none', diff = 0, size = 0, id = 2552 }")
check("open world: a difficulty list with a real difficulty does NOT load (difficulty 0 = none)",
      lua("return (loads(R({ mode = 'all', difficulties = { ['16'] = true } }))) == false"))

# encounters
check("no encounter: encounter ID 0 (none)", lua("IN_ENC = false; return ctxNow().encounterID == 0"))
check("encounter list, no boss pulled: does NOT load ('encounter')",
      lua("local ok, why = loads(R({ mode = 'all', encounterIDs = { ['3009'] = true } })); return ok == false and why == 'encounter'"))
lua("IN_ENC = true; fire('ENCOUNTER_START', 3009, 'A boss', 16, 20)")
check("ENCOUNTER_START 3009: the context has encounter 3009, and the list with 3009 loads",
      lua("return ctxNow().encounterID == 3009 and (loads(R({ mode = 'all', encounterIDs = { ['3009'] = true } })))"))
check("the last encounter seen is kept for the options' 'Add current' (ID and name)",
      lua("local e = NS.LastEncounter(); return e and e.id == 3009 and e.name == 'A boss'"))
check("encounter 3009 marked 'not': does NOT load during it", lua("return (loads(R({ mode = 'all', encounterIDs = { ['3009'] = 'not' } }))) == false"))
lua("IN_ENC = false; fire('ENCOUNTER_END', 3009, 'A boss', 16, 20, 1)")
check("ENCOUNTER_END: back to none, the list no longer loads",
      lua("return ctxNow().encounterID == 0 and (loads(R({ mode = 'all', encounterIDs = { ['3009'] = true } }))) == false"))
lua("IN_ENC = true")
check("in an encounter the game reports, but no ENCOUNTER_START seen (a /reload mid-pull): the ID is unknown, the rule does not load",
      lua("local ok, why = loads(R({ mode = 'all', encounterIDs = { ['3009'] = true } })); return ctxNow().encounterID == nil and ok == false and why == 'encounter (unknown)'"))
lua("IN_ENC = false")
check("a secret encounter ID from the event is not kept", lua("SECRET[777] = true; fire('ENCOUNTER_START', 777, 'X', 16, 20); IN_ENC = true; local id = ctxNow().encounterID; SECRET[777] = nil; IN_ENC = false; fire('ENCOUNTER_END'); return id == nil"))

# items equipped
lua("WORN = { [111] = true }")
check("item 111 worn, list 111: loads", lua("return (loads(R({ mode = 'all', equipped = { ['111'] = true } })))"))
check("list 222 (not worn): does NOT load ('item equipped')",
      lua("local ok, why = loads(R({ mode = 'all', equipped = { ['222'] = true } })); return ok == false and why == 'item equipped'"))
check("list 111 or 222: one worn is enough", lua("return (loads(R({ mode = 'all', equipped = { ['111'] = true, ['222'] = true } })))"))
check("111 marked 'not' while worn: does NOT load", lua("return (loads(R({ mode = 'all', equipped = { ['111'] = 'not' } }))) == false"))
check("an equipment change re-checks the memoized answer (PLAYER_EQUIPMENT_CHANGED changes the context)",
      lua("local s1 = ctxNow().sig; fire('PLAYER_EQUIPMENT_CHANGED', 13, false); return ctxNow().sig ~= s1"))
check("the game cannot say (IsEquippedItem errors): unknown, does not load",
      lua("local f = C_Item.IsEquippedItem; C_Item.IsEquippedItem = function() error('no') end; local ok, why = loads(R({ mode = 'all', equipped = { ['111'] = true } })); C_Item.IsEquippedItem = f; return ok == false and why == 'item equipped (unknown)'"))

# Match ANY, empty lists, the memo string
check("Match ANY: a wrong zone but the right item is enough",
      lua("return (loads(R({ mode = 'any', mapIDs = { ['40'] = true }, equipped = { ['111'] = true } })))"))
check("empty lists restrict nothing", lua("return (loads(R({ mode = 'all', mapIDs = {}, instanceIDs = {}, difficulties = {}, sizes = {}, encounterIDs = {}, equipped = {} })))"))
check("the memo string changes with the map, instance, difficulty, size and encounter",
      lua("""local s = {}
        s[1] = ctxNow().sig; HERE = 40; s[2] = ctxNow().sig; HERE = 31
        INST.diff = 2; s[3] = ctxNow().sig; INST.diff = 0
        INST.id = 1; s[4] = ctxNow().sig; INST.id = 2552
        INST.size = 5; s[5] = ctxNow().sig; INST.size = 0
        IN_ENC = true; fire('ENCOUNTER_START', 5, 'B', 1, 5); s[6] = ctxNow().sig; IN_ENC = false; fire('ENCOUNTER_END', 5)
        for i = 2, 6 do if s[i] == s[1] then return false end end
        return true"""))
check("the old rows still work beside the new lists (open world ticked, a zone list that matches)",
      lua("return (loads(R({ mode = 'all', instanceTypes = { none = true }, mapIDs = { ['20'] = true } }))) and not (loads(R({ mode = 'all', instanceTypes = { raid = true }, mapIDs = { ['20'] = true } })))"))
check("/xui debug status prints the place values (map, instance, difficulty, size, encounter)",
      lua("""local out = {}; local keep = NS.Print; NS.Print = function(t) out[#out + 1] = t end
        NS.rules = { R({ mode = 'all' }) }; NS.Evaluate = NS.Evaluate or function() return true, {} end
        pcall(NS.PrintStatus); NS.Print = keep
        for _, t in ipairs(out) do if t:find('place: map=31 instanceID=2552 difficulty=0 size=0 encounterID=0', 1, true) then return true end end
        return false"""))
# a group's own lists (core 0.6.33): checked for every rule in the group and its nested groups, before the rule's own
lua("""NS.folders = { { id = "gA", name = "Raid auras", loadIds = { mapIDs = { ['40'] = true } } }, { id = "gB", name = "Inner", parent = "gA" },
                      { id = "gC", name = "Always group", loadOverride = "always", loadIds = { mapIDs = { ['40'] = true } } } }""")
check("a group's zone list that does not match: its rule does not load, and the reason names the group",
      lua("local r = R({ mode = 'all' }); r.folder = 'gA'; local ok, why = loads(r); return ok == false and why == 'group Raid auras: zone'"),
      lua("local r = R({ mode = 'all' }); r.folder = 'gA'; local ok, why = loads(r); return tostring(why)"))
check("a rule in a nested group gets its parent group's list too",
      lua("local r = R({ mode = 'all' }); r.folder = 'gB'; return (loads(r)) == false"))
check("the group's list that matches (zone 20, the room's zone): the rule loads",
      lua("NS.folders[1].loadIds.mapIDs = { ['20'] = true }; local r = R({ mode = 'all' }); r.folder = 'gB'; return (loads(r))"))
check("a group set to Always ignores its lists (as it does its other load conditions)",
      lua("local r = R({ mode = 'all' }); r.folder = 'gC'; return (loads(r))"))
lua("NS.folders = {}")
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
