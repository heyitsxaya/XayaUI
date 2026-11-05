#!/usr/bin/env python3
"""Spell search scope (Options 0.6.37; Xaya 2026-11-04, choosing option B: "go with b"). A search box looks only through what is
relevant to the player by default (this class, the spellbook, the spells the rules use, the auras of the items carried), builds the
whole-game spell index only after "Search all spells", and frees everything when the settings window closes. Before, the first focus of
any search box walked 1.9 million spell IDs and kept the names until /reload (her tooltip: XayaUI_Options 521.4 MB after /xui).
Runs the real addons in the stand-in game (Lua 5.1 via lupa) with controlled spell names, one bag item and two rules.
Checks outcomes: which IDs a search returns and with which tag, how many name lookups were made, whether the indexes hold anything,
whether the aura-source pass runs. Deliberate breaks (BREAKS) must each make a check fail. The last line carries FAILS: <n>.
Run: python3 tests/spell_search_scope_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

OPTIONS = os.path.join(HERE, "..", "XayaUI_Options", "Options.lua")

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings addon loaded with the search test handle", ns and ns.SpellSearchTest ~= nil and ns.SearchOnClose ~= nil)
if not (ns and ns.SpellSearchTest) then return R end
local T, AS = ns.SpellSearchTest, ns.AuraSources

-- the game, controlled: only these spells have names; every name lookup is counted
NAMES = { [204021] = "Fiery Brand", [19705] = "Well Fed", [999001] = "Shadow Grip", [555555] = "Distant Fireworks" }
LOOKUPS = 0
C_Spell.GetSpellName = function(id) LOOKUPS = LOOKUPS + 1; return NAMES[id] end
-- one bag item: a stew whose tooltip embeds the Well Fed aura (the nested spell block AuraSources.lua reads)
C_Container.GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end
C_Container.GetContainerItemInfo = function(bag, slot) if bag == 0 and slot == 1 then return { itemID = 113 } end end
C_Item.GetItemNameByID = function(id) if id == 113 then return "Hearty Stew" end end
C_TooltipInfo = { GetItemByID = function(id)
  if id == 113 then return { lines = { { type = AS.NestedType(), tooltipType = AS.SpellType(), tooltipID = 19705 } } } end
end, GetSpellByID = function() return nil end }
-- two rules: one with a spell of the class, one with a debuff from outside it
ns.rules = { { spellID = 204021 }, { triggers = { { buffID = 999001 } } } }
T.SX.near, T.SX.cs = nil, nil

local function find(list, id) for _, x in ipairs(list or {}) do if x == id then return true end end return false end
local before = LOOKUPS
local r1 = T.Search("well fed", "aura")
check("default: an aura of a carried item is found (Well Fed from the stew)", find(r1, 19705), table.concat(r1, ","))
check("default: it is tagged with the item it comes from", T.SX.tags[19705] == "from Hearty Stew", T.SX.tags[19705])
local r2 = T.Search("shadow grip", "aura")
check("default: a spell a rule uses is found, even from outside the class", find(r2, 999001) and T.SX.tags[999001] == "in your rules", T.SX.tags[999001])
local r3 = T.Search("distant", "aura")
check("default: a spell outside class, rules and bags is not found", not find(r3, 555555))
check("default: no whole-game index (nothing kept, nothing scanning)", T.SI.n == 0 and not T.SI.running and T.SX.II.n == 0 and not T.SX.II.running,
  T.SI.n .. " / " .. tostring(T.SI.running))
check("default: a few name lookups, not a scan of every spell ID", LOOKUPS - before < 2000, LOOKUPS - before)
T.SX.Start("aura")
check("default: the aura-source pass over every item does not start", not (AS.state and AS.state.running))

-- "Search all spells"
T.SX.SearchAll("aura")
check("Search all: the whole-game index starts", T.SX.full == true and (T.SI.running or T.SI.nextId > 1))
for _ = 1, 50 do if not T.SI.running then break end; W.tick(0.016, 1) end
local r4 = T.Search("distant", "aura")
check("Search all: a spell from anywhere in the game is found", find(r4, 555555), table.concat(r4, ","))
check("Search all: the index holds the named spells", T.SI.n >= 4, T.SI.n)

-- closing the settings window frees it all
ns.SearchOnClose()
check("closed: both indexes are empty and nothing scans", T.SI.n == 0 and next(T.SI.names) == nil and not T.SI.running
  and T.SX.II.n == 0 and not T.SX.II.running, T.SI.n)
check("closed: back to the default scope", T.SX.full == false and T.SX.near == nil)
check("closed: the aura-source pass is stopped", not (AS.state and AS.state.running))
local r5 = T.Search("distant", "aura")
check("closed: the far spell is not found again until Search all", not find(r5, 555555))
return R
end
'''

BREAKS = [
    ("whole-game index built on every focus again", "    if not SX.full then return end\n", ""),
    ("closing keeps the index", "        S.names, S.ids, S.n, S.nextId = {}, {}, 0, 1\n", ""),
    ("no near set (rules and bags not searched)", "        local okN, near = pcall(SX.Near)\n", "        local okN, near = false, nil\n"),
]


def run(options_src=None):
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    if options_src is not None:   # a deliberate break: the loader reads Options.lua through io.open; swap its text in
        L.globals().BROKEN_OPTIONS = options_src
        L.execute(r'''
local realOpen = io.open
io.open = function(path, mode)
  if type(path) == "string" and path:find("XayaUI_Options[/\\]Options%.lua$") then
    return { read = function() return BROKEN_OPTIONS end, close = function() end, lines = function() return BROKEN_OPTIONS:gmatch("[^\n]*\n?") end }
  end
  return realOpen(path, mode)
end''')
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    return [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]


src = open(OPTIONS, encoding="utf-8").read()
results = run()
bad = 0
for name, ok in results:
    print(("PASS " if ok else "FAIL ") + name)
    if not ok:
        bad += 1
for name, old, new in BREAKS:
    if src.count(old) != 1:
        print("BREAK %r: text not found exactly once" % name); bad += 1; continue
    r2 = run(src.replace(old, new))
    if all(ok for _, ok in r2) and len(r2) >= len(results):
        print("BREAK %r: no check failed" % name); bad += 1
print("%d checks, %d deliberate breaks  FAILS: %d" % (len(results), len(BREAKS), bad))
