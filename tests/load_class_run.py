"""Load by class (Conditions.lua with the real Core) and the always-complete class / spec lists (the block in Options.lua).
A rule or group can be limited to any class from any character, and the lists never depend on who is logged in.
Stand-in game (tests/engine_bench.py stubs). Run: python3 tests/load_class_run.py"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
for f in ("XayaUI/Core.lua", "XayaUI/Conditions.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute(r'''
local ns = NS
ns.Print = function() end
-- the logged-in character: a Paladin (Retribution)
PLAYER_CLASS = "PALADIN"
function UnitClass() return PLAYER_CLASS, PLAYER_CLASS, 2 end
ns.folders = {}
CueRulesDB.folders = ns.folders
function ns.FolderById(id) for _, f in ipairs(ns.folders) do if f.id == id then return f end end end
function ctxNow() return ns.ReadContext() end
function R(load) return { uid = "r", name = "r", enabled = true, load = load } end
function loads(rule) local ok, why = ns.CheckContext(rule, ctxNow()); return ok and true or false, why end
''')
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)
lua = lambda s: L.execute(s)

check("context reads the character's class file", lua("return ctxNow().class == 'PALADIN'"))
check("no class ticked: loads on any class", lua("return (loads(R({ mode = 'all' })))"))
check("Death Knight only: does NOT load on a Paladin", lua("local ok = loads(R({ mode = 'all', classes = { DEATHKNIGHT = true } })); return ok == false"))
check("Death Knight only: says why (class)", lua("local _, why = loads(R({ mode = 'all', classes = { DEATHKNIGHT = true } })); return why == 'class'"), lua("local _, why = loads(R({ mode = 'all', classes = { DEATHKNIGHT = true } })); return tostring(why)"))
check("Death Knight or Paladin: loads on a Paladin", lua("return (loads(R({ mode = 'all', classes = { DEATHKNIGHT = true, PALADIN = true } })))"))
check("class box switched off keeps the choice but ignores it", lua("return (loads(R({ mode = 'all', classUse = false, classes = { DEATHKNIGHT = true } })))"))
# #319 (core 0.6.18): "Always load" plus the row's own tick box "Always load: only this class / spec"
check("Always load, Death Knight class, box NOT ticked: loads on a Paladin (unchanged default)",
      lua("return (loads(R({ mode = 'always', classes = { DEATHKNIGHT = true } })))"))
check("Always load, Death Knight class, box ticked: does NOT load on a Paladin",
      lua("return (loads(R({ mode = 'always', alwaysClass = true, classes = { DEATHKNIGHT = true } }))) == false"))
check("  ...and says why", lua("local _, why = loads(R({ mode = 'always', alwaysClass = true, classes = { DEATHKNIGHT = true } })); return tostring(why):find('Always load, only this class') ~= nil"))
check("Always load, Paladin class, box ticked: loads on a Paladin",
      lua("return (loads(R({ mode = 'always', alwaysClass = true, classes = { PALADIN = true } })))"))
check("Always load, box ticked but the Class row switched off: the row is not used",
      lua("return (loads(R({ mode = 'always', alwaysClass = true, classUse = false, classes = { DEATHKNIGHT = true } })))"))
check("Always load ignores the other rows even with the box ticked (role, instance)",
      lua("return (loads(R({ mode = 'always', alwaysClass = true, classes = { PALADIN = true }, roles = { HEALER = true }, combat = 'yes' })))"))
SPEC = L.eval("ns.ReadContext and tostring(NS.ReadContext().specID)")
check("Always load, another spec ticked with its box: does NOT load",
      lua("return (loads(R({ mode = 'always', alwaysSpec = true, specs = { ['999999'] = true } }))) == false"))
check("Always load, another spec ticked, box NOT ticked: loads (unchanged default)",
      lua("return (loads(R({ mode = 'always', specs = { ['999999'] = true } })))"))
# a group set to Always
lua("ns = NS; ns.folders[#ns.folders + 1] = { id = 'gA', name = 'DK auras', loadOverride = 'always', loadClasses = { DEATHKNIGHT = true } }")
check("group Always with a Death Knight class list, box NOT ticked: its rule loads on a Paladin (unchanged)",
      lua("local r = R({ mode = 'all', classes = { PALADIN = true } }); r.folder = 'gA'; return (loads(r))"))
lua("ns.folders[#ns.folders].alwaysClass = true")
check("group Always, box ticked: its rules do NOT load on a Paladin, whatever their own Load tab says",
      lua("local r = R({ mode = 'always' }); r.folder = 'gA'; return (loads(r)) == false"))
lua("table.insert(ns.folders, { id = 'gB', name = 'inner', parent = 'gA' })")
check("  ...also for a rule in a nested group", lua("local r = R({ mode = 'all' }); r.folder = 'gB'; return (loads(r)) == false"))
lua("ns.folders[1].loadClasses = { PALADIN = true }")
check("group Always, box ticked, Paladin listed: loads", lua("local r = R({ mode = 'all' }); r.folder = 'gA'; return (loads(r))"))
check("Always load still wins over the class", lua("return (loads(R({ mode = 'always', classes = { DEATHKNIGHT = true } })))"))
check("Match ANY: a matching class is enough", lua("return (loads(R({ mode = 'any', classes = { PALADIN = true }, specs = { ['999'] = true } })))"))
check("a DK spec set on a Paladin character does not load", lua("return (loads(R({ mode = 'all', specs = { ['250'] = true } }))) == false"))
lua("PLAYER_CLASS = 'DEATHKNIGHT'")
check("same rule loads once the character is a Death Knight (context memo follows the class)", lua("return (loads(R({ mode = 'all', classes = { DEATHKNIGHT = true } })))"))
lua("PLAYER_CLASS = 'PALADIN'")
# groups
lua("NS.folders[1] = { id = 'f1', name = 'DK auras', loadClasses = { DEATHKNIGHT = true } }")
check("group limited to Death Knight: its rule does not load on a Paladin", lua("local r = R({ mode = 'all' }); r.folder = 'f1'; local ok, why = loads(r); return ok == false and tostring(why):find('class') ~= nil"))
check("group Always override is separate; class gate holds for a rule that says Always", lua("local r = R({ mode = 'always' }); r.folder = 'f1'; return (loads(r)) == false"))
lua("NS.folders[1].loadClasses = { PALADIN = true, DEATHKNIGHT = true }")
check("group allowing Paladin: rule loads", lua("local r = R({ mode = 'all' }); r.folder = 'f1'; return (loads(r))"))

# the lists: the block in Options.lua, run against a stand-in class API (13 classes, 3 specs each; the character is a Paladin)
src = open(os.path.join(ROOT, "XayaUI_Options/Options.lua"), encoding="utf-8").read()
i = src.index("local SpecChoices   --"); j = src.index("-- Hero talent specializations of the character's class")
L.globals().BLOCK = src[i:j]
L.execute(r'''
local files = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }
function GetNumClasses() return #files end
function GetClassInfo(i) return files[i], files[i], i end
local SPECS = { [6] = { 250, 251, 252 }, [2] = { 65, 66, 70 }, [12] = { 577, 581 } }
function GetSpecializationInfoForClassID(cid, i) local s = SPECS[cid] or {}; local id = s[i]; if not id then return nil end; return id, "Spec" .. id, "", 100 + id, "DAMAGER" end
rawset(_G, 'C_SpecializationInfo', false)
function GetNumSpecializations() return 3 end
function GetSpecializationInfo(i) local ids = SPECS[2]; return ids[i], "Own" .. ids[i], "", 1, "DAMAGER" end
RAID_CLASS_COLORS = { DEATHKNIGHT = { colorStr = "ffc41e3a" } }
LOCALIZED_CLASS_NAMES_MALE = { DEATHKNIGHT = "Death Knight", PALADIN = "Paladin" }
local nsT = {}
local chunk = loadstring("local ns = ...\n" .. BLOCK .. "\nreturn SpecChoices")
SPEC_FN = chunk(nsT); CLASS_FN = nsT.ClassChoices
''')
check("class list: all 13 classes, whoever is logged in", lua("return #CLASS_FN() == 13"))
check("class list is in a fixed order starting with Death Knight", lua("return CLASS_FN()[1].id == 'DEATHKNIGHT' and CLASS_FN()[8].id == 'PALADIN'"))
check("spec list holds Death Knight specs while on a Paladin", lua("local n = 0; for _, c in ipairs(SPEC_FN()) do if c.class == 'DEATHKNIGHT' then n = n + 1 end end; return n == 3"))
check("spec list holds the Paladin's own specs too", lua("local n = 0; for _, c in ipairs(SPEC_FN()) do if c.class == 'PALADIN' then n = n + 1 end end; return n == 3"))
check("spec list spans several classes (3 + 3 + 2 = 8)", lua("return #SPEC_FN() == 8"), lua("return #SPEC_FN()"))
check("spec ids are strings, as the load check compares them", lua("for _, c in ipairs(SPEC_FN()) do if c.class == 'DEATHKNIGHT' then return c.id == '250' and type(c.id) == 'string' end end"))
check("spec entries carry the class name so they are told apart", lua("for _, c in ipairs(SPEC_FN()) do if c.class == 'DEATHKNIGHT' then return c.text:find('Death Knight') ~= nil end end"))
lua("rawset(_G, 'GetClassInfo', false)")
lua("local nsT = {}; local chunk = loadstring('local ns = ...\\n' .. BLOCK .. '\\nreturn SpecChoices'); SPEC_FN2 = chunk(nsT)")
check("no class API: falls back to the logged-in character's specs (never an empty list)", lua("return #SPEC_FN2() == 3"), lua("return #SPEC_FN2()"))
print("\nALL PASSED" if not fails else "\n%d FAILED" % len(fails)); sys.exit(1 if fails else 0)
