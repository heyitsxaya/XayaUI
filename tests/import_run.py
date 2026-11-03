"""Offline test: Profile_Apply puts an import into one folder of its own, and ns.FixFolderIds repairs non-standard group ids.
Run: python3 tests/import_run.py   (stand-in game; proves the data logic, not the window or the tree).  Lua 5.1 via lupa."""
import os, re
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
L = LuaRuntime(unpack_returned_tuples=True)
core = open(os.path.join(ROOT, "Core.lua")).read()
m = re.search(r"-- Rename every group whose id.*?\nend\n", core, re.S)
fix = m.group(0)
L.globals().FIXSRC = fix
L.execute(r'''
time = os.time; date = os.date; wipe = function(t) for k in pairs(t) do t[k] = nil end end
local function Copy(o) if type(o) ~= "table" then return o end local n = {} for k, v in pairs(o) do n[k] = Copy(v) end return n end
local ns = {}
ns.Copy = Copy
ns.NormalizeRule = function() end; ns.DropVisual = function() end; ns.RefreshAllVisuals = function() end; ns.MarkDirty = function() end
ns.Merge = function() end; ns.BAR_DEFAULTS = {}; ns.NewUID = function() return "u" .. math.random(1e9) end
CueRulesDB = { barGroup = {} }
_G.XayaUI_NS = ns
ns.Print = ns.Print or function() end
assert(loadfile("''' + os.path.join(ROOT, "Modules.lua").replace("\\", "/") + r'''"))("XayaUI", ns)   -- core contract: ns.Fire (0.6.0)
-- load Profile.lua with the addon vararg
local f = assert(loadfile("''' + os.path.join(ROOT, "Profile.lua").replace("\\", "/") + r'''"))
f("XayaUI", ns)
ns.rules = { { name = "mine", folder = "f111" } }
ns.folders = { { id = "f111", name = "Mine" } }
ns.qolBoxes = {}; ns.bars = {}
local snap = { v = 1, name = "EUI bars", folders = { { id = "feui1", name = "Bar 1", cType = "dynamic", default = "display" }, { id = "feui2", name = "Child", parent = "feui1" } },
  rules = { { name = "a", folder = "feui1", uid = "ua" }, { name = "loose", uid = "ub" }, { name = "cue", isCue = true, parentUid = "ub" }, { name = "c", folder = "feui2", uid = "uc" } } }
local c = ns.Profile_Apply(snap, "add")
results = {}
local function check(n, ok) results[#results + 1] = { n, ok and true or false } end
local function byName(n) for _, x in ipairs(ns.folders) do if x.name == n then return x end end end
local wrap
for _, x in ipairs(ns.folders) do if x.name:match("^Imported: EUI bars %(") then wrap = x end end
check("one wrapper folder, top level", wrap ~= nil and wrap.parent == nil)
check("imported ids are standard form", (function() for _, x in ipairs(ns.folders) do if not x.id:match("^f%d+$") then return false end end return true end)())
local b1, ch = byName("Bar 1"), byName("Child")
check("top-level imported group sits inside the wrapper", b1.parent == wrap.id)
check("nested group keeps its parent", ch.parent == b1.id)
check("group settings kept", b1.cType == "dynamic")
check("built-in category flag not copied", b1.default == nil)
check("grouped rule re-pointed", ns.rules[2].folder == b1.id and ns.rules[5].folder == ch.id)
check("ungrouped rule goes into the wrapper", ns.rules[3].folder == wrap.id)
check("cue rule not given a folder", ns.rules[4].folder == nil)
check("existing rule and folder untouched", ns.rules[1].folder == "f111" and ns.folders[1].id == "f111")
check("counts: 3 groups + wrapper, 4 rules", c.folders == 3 and c.rules == 4)
-- repair of old ids
local env = setmetatable({ ns = ns, time = os.time, math = math, ipairs = ipairs, type = type, tostring = tostring }, { __index = _G })
local fn = assert(loadstring(FIXSRC .. " return ns.FixFolderIds", "fix")); setfenv(fn, env)
local FixFolderIds = fn()
ns.folders = { { id = "f1700000000", name = "ok" }, { id = "feui1", name = "old" }, { id = "feui2", name = "kid", parent = "feui1" } }
ns.rules = { { folder = "feui2" }, { folder = "f1700000000" } }
local n = FixFolderIds()
check("two old ids repaired", n == 2)
check("all ids standard now", (function() for _, x in ipairs(ns.folders) do if not x.id:match("^f%d+$") then return false end end return true end)())
check("child points at renamed parent", ns.folders[3].parent == ns.folders[2].id)
check("rule points at renamed group", ns.rules[1].folder == ns.folders[3].id and ns.rules[2].folder == "f1700000000")
check("second run changes nothing", FixFolderIds() == 0)
''')
res = L.eval("results"); bad = 0
for i in range(1, len(res) + 1):
    n, ok = res[i][1], res[i][2]
    print(("ok:   " if ok else "FAIL: ") + n); bad += 0 if ok else 1
print(f"{len(res)} checks, {bad} failed"); raise SystemExit(1 if bad else 0)
