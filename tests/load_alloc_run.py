"""#309 (engine CPU and memory), the load checks: the engine session's allocation profile (2026-11-04) found ns.CheckContext's
recheck (at least once a second per rule) making tables every time: a new {} for a rule without a load table, a new result list for
every group the rule sits in, the ID-list descriptions rebuilt on every call, a { [v] = true } per instance / difficulty / size /
encounter check, and the "worn" set of the equipped-item check. Core 0.6.41 makes none of those. Checks:
  - parity: 3,000 random rules (and their groups' lists) against random places and worn items give the same answer and the same
    reason as a copy of the old checks written here (old algorithm, not old file);
  - allocations: with the collector stopped, a recheck of a rule without a load table in two nested groups without lists, and of a
    rule with ID lists in such groups, allocates at most the stated number of bytes.
Runs the real Core.lua and Conditions.lua on the stand-in game of tests/engine_bench.py (as tests/load_ids_run.py does).
Run: python3 tests/load_alloc_run.py   (needs: pip install lupa)"""
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
COND = os.environ.get("XUI_CONDITIONS", os.path.join(ROOT, "XayaUI_Rules", "Conditions.lua"))   # (a negative control can point at an older copy)
for f in ("XayaUI/Compat.lua", "XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI_Rules/RuleDefaults.lua", COND):
    path = f if os.path.isabs(f) else os.path.join(ROOT, f)
    load(open(path, encoding="utf-8").read(), f, ns)
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

# the old ID-list algorithm, written out here for the parity check (from core 0.6.33-0.6.40: IdsMatch with a { [v] = true } set and
# a worn set for equipped items)
lua(r"""
local function OldIdsMatch(set, current)
  local hasOn, hit = false, false
  for k, st in pairs(set) do
    local n = tonumber(k)
    if st == "not" and n and current[n] then return false end
    if st == true then hasOn = true; if n and current[n] then hit = true end end
  end
  return (not hasOn) or hit
end
local function OldEquipped(set)
  local worn, unknown = {}, false
  for k in pairs(set) do
    local n = tonumber(k)
    if n then local v = C_Item.IsEquippedItem(n); if v == nil then unknown = true else worn[n] = v and true or nil end end
  end
  if unknown then return nil end
  return OldIdsMatch(set, worn)
end
local function active(set) if type(set) ~= "table" then return false end; for k in pairs(set) do if k ~= "*" then return true end end; return false end
local function known(v, r) if v == nil then return nil end; return r end
function OldListChecks(load, ctx)
  local out = {}
  if type(load) ~= "table" then return out end
  if active(load.mapIDs) then out[#out + 1] = { "zone", known(ctx.maps, ctx.maps and OldIdsMatch(load.mapIDs, ctx.maps)) } end
  for _, d in ipairs({ { "instanceIDs", "instanceID", "instance ID" }, { "difficulties", "difficultyID", "difficulty" },
      { "sizes", "instSize", "instance size" }, { "encounterIDs", "encounterID", "encounter" } }) do
    local set, v = load[d[1]], ctx[d[2]]
    if active(set) then out[#out + 1] = { d[3], known(v, v ~= nil and OldIdsMatch(set, { [v] = true })) } end
  end
  if active(load.equipped) then out[#out + 1] = { "item equipped", OldEquipped(load.equipped) } end
  return out
end
-- the answer the old code gave for a rule whose only conditions are ID lists ("all" mode), in groups with lists
function OldAnswer(rule, ctx, groups)
  for _, f in ipairs(groups) do
    for _, c in ipairs(OldListChecks(f.loadIds, ctx)) do
      if c[2] ~= true then return false, "group " .. tostring(f.name) .. ": " .. c[1] .. (c[2] == nil and " (unknown)" or "") end
    end
  end
  for _, c in ipairs(OldListChecks(rule.load, ctx)) do
    if c[2] ~= true then return false, c[1] .. (c[2] == nil and " (unknown)" or "") end
  end
  return true
end
""")

# parity: random lists, places and worn items
lua(r"""
math.randomseed(351)
local function rset(pool)
  local s, n = {}, math.random(0, 3)
  for i = 1, n do s[tostring(pool[math.random(#pool)])] = (math.random() < 0.3) and "not" or true end
  return s
end
local function rload()
  local l = {}
  if math.random() < 0.5 then l.mapIDs = rset({ 10, 20, 30, 31, 40 }) end
  if math.random() < 0.4 then l.instanceIDs = rset({ 2552, 2600, 2700 }) end
  if math.random() < 0.4 then l.difficulties = rset({ 0, 1, 2, 8, 16 }) end
  if math.random() < 0.3 then l.sizes = rset({ 0, 5, 10, 20 }) end
  if math.random() < 0.3 then l.encounterIDs = rset({ 3001, 3002 }) end
  if math.random() < 0.4 then l.equipped = rset({ 101, 102, 103 }) end
  return l
end
PARITY_BAD, PARITY_N = {}, 0
for i = 1, 3000 do
  HERE = ({ 31, 30, 20, 40 })[math.random(4)]
  INST.id = ({ 2552, 2600, 2700 })[math.random(3)]; INST.diff = ({ 0, 1, 8, 16 })[math.random(4)]; INST.size = ({ 0, 5, 20 })[math.random(3)]
  WORN = { [101] = math.random() < 0.5 or nil, [102] = math.random() < 0.5 or nil }
  local unknownItem = math.random() < 0.1
  C_Item.IsEquippedItem = function(id) id = tonumber(id); if unknownItem and id == 103 then return nil end; return WORN[id] == true end
  ns_enc = math.random() < 0.3
  local g1 = { id = "g1", name = "Outer", loadIds = (math.random() < 0.5) and rload() or nil }
  local g2 = { id = "g2", name = "Inner", parent = "g1", loadIds = (math.random() < 0.5) and rload() or nil }
  NS.folders = { g1, g2 }
  local rule = { uid = "p" .. i, name = "p", enabled = true, folder = "g2", load = rload() }
  rule.load.mode = "all"
  local ctx = NS.ReadContext(); ctx.sig = nil
  local okN, whyN = NS.CheckContext(rule, ctx)
  local okO, whyO = OldAnswer(rule, ctx, { g2, g1 })
  PARITY_N = PARITY_N + 1
  if (okN and true or false) ~= (okO and true or false) or (not okN and whyN ~= whyO) then
    if #PARITY_BAD < 3 then PARITY_BAD[#PARITY_BAD + 1] = tostring(okN) .. "/" .. tostring(whyN) .. " vs " .. tostring(okO) .. "/" .. tostring(whyO) end
    PARITY_BAD.n = (PARITY_BAD.n or 0) + 1
  end
end
NS.folders = {}
C_Item.IsEquippedItem = function(id) return WORN[tonumber(id)] == true end
""")
bad = L.eval("PARITY_BAD.n or 0")
check("parity: 3,000 random rules and group lists give the old answers and reasons", bad == 0,
      "%s differ, e.g. %s" % (bad, "; ".join(str(L.eval("PARITY_BAD[%d]" % i)) for i in range(1, min(3, bad) + 1))))

# allocations per recheck (the memo is bypassed: no ctx.sig)
lua(r"""
HERE, INST.id, INST.diff, INST.size = 31, 2552, 0, 0
WORN = { [101] = true }
NS.folders = { { id = "g1", name = "Outer" }, { id = "g2", name = "Inner", parent = "g1" } }
function bytesPer(rule, n)
  local ctx = NS.ReadContext(); ctx.sig = nil
  NS.CheckContext(rule, ctx)
  collectgarbage("collect"); collectgarbage("stop")
  local before = collectgarbage("count")
  for i = 1, n do NS.CheckContext(rule, ctx) end
  local after = collectgarbage("count")
  collectgarbage("restart")
  return (after - before) * 1024 / n
end
PLAIN = { uid = "a1", name = "a1", enabled = true, folder = "g2" }   -- no load table at all
LISTS = { uid = "a2", name = "a2", enabled = true, folder = "g2", load = { mode = "all", mapIDs = { ["30"] = true },
  instanceIDs = { ["2552"] = true }, difficulties = { ["0"] = true }, equipped = { ["101"] = true } } }
""")
plain = L.eval("bytesPer(PLAIN, 2000)")
lists = L.eval("bytesPer(LISTS, 2000)")
print("bytes per recheck: no load table %.0f, four ID lists %.0f" % (plain, lists))
# measured 2026-11-04 in this stand-in (Lua 5.1 via lupa): with core 0.6.40's ns.SetActive the old checks made 832 / 1,720 bytes a
# recheck, these 64 / 704 (the 64 is the rule's own list of checks)
check("a rule with no load table in two groups without lists: at most 80 bytes a recheck (the old checks: about 830)", plain <= 80, "%.0f" % plain)
check("a rule with four ID lists in such groups: at most 800 bytes a recheck (the old checks: about 1,720)", lists <= 800, "%.0f" % lists)
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
