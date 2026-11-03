"""Offline test: Profile_SnapshotFolder + encode / decode / apply round trip for a group export (build 0.5.84).
Run: python3 tests/export_group_run.py   (stand-in game; proves the data logic, not the menu or the popup).  Lua 5.1 via lupa."""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
time = os.time; date = os.date; wipe = function(t) for k in pairs(t) do t[k] = nil end end
local function Copy(o) if type(o) ~= "table" then return o end local n = {} for k, v in pairs(o) do n[k] = Copy(v) end return n end
local ns = {}
ns.Copy = Copy
ns.NormalizeRule = function() end; ns.DropVisual = function() end; ns.RefreshAllVisuals = function() end; ns.MarkDirty = function() end
ns.Merge = function() end; ns.BAR_DEFAULTS = {}; ns.NewUID = function() return "u" .. math.random(1e9) end
CueRulesDB = { barGroup = {} }
_G.XayaUI_NS = ns
assert(loadfile("''' + os.path.join(ROOT, "Profile.lua").replace("\\", "/") + r'''"))("XayaUI", ns)
function ns.OutcomesOf(p) local o = {} if not p.uid then return o end for _, r in ipairs(ns.rules) do if r ~= p and r.parentUid == p.uid then o[#o + 1] = r end end return o end
ns.qolBoxes = {}; ns.bars = {}
ns.folders = { { id = "f1", name = "Other" }, { id = "f2", name = "Personal Buff Tracking", cType = "dynamic" }, { id = "f3", name = "Kid", parent = "f2" }, { id = "f4", name = "Elsewhere", parent = "f1" } }
ns.rules = {
  { name = "a", folder = "f2", uid = "ua" },
  { name = "a cue", isCue = true, parentUid = "ua" },                      -- no folder of its own
  { name = "a cond", parentUid = "ua", folder = "f2" },
  { name = "b", folder = "f3", uid = "ub" },
  { name = "b cue", isCue = true, parentUid = "ub", folder = "f3" },
  { name = "outside", folder = "f4", uid = "uo" },
  { name = "outside cue", isCue = true, parentUid = "uo" },
}
results = {}
local function check(n, ok) results[#results + 1] = { n, ok and true or false } end
local snap = ns.Profile_SnapshotFolder(ns.folders[2])
check("2 groups (the group and its nested one)", #snap.folders == 2)
check("top group's parent dropped", snap.folders[1].parent == nil and snap.folders[2].parent == "f2")
check("group settings kept", snap.folders[1].cType == "dynamic")
local names = {}
for _, r in ipairs(snap.rules) do names[r.name] = true end
check("4 rules in, with cues and conditions", #snap.rules == 5 and names["a"] and names["a cue"] and names["a cond"] and names["b"] and names["b cue"])
check("rules outside the group are not exported", not names["outside"] and not names["outside cue"])
check("the live data was not changed", ns.rules[1].folder == "f2" and ns.folders[2].parent == nil)
local txt = assert(ns.Profile_Encode(snap))
local back, err = ns.Profile_Decode(txt)
check("string decodes", back ~= nil)
local before = #ns.rules
local c = ns.Profile_Apply(back, "add")
check("import adds 5 rules, 2 groups and a wrapper", #ns.rules == before + 5 and c.rules == 5 and c.folders == 3)
local wrap
for _, f in ipairs(ns.folders) do if f.name:match("^Imported: ") then wrap = f end end
local top, kid
for _, f in ipairs(ns.folders) do if f.name == "Personal Buff Tracking" and f.id ~= "f2" then top = f end; if f.name == "Kid" and f.id ~= "f3" then kid = f end end
check("imported group sits in the wrapper, nested group inside it", top and kid and top.parent == wrap.id and kid.parent == top.id)
local ua2
for i = before + 1, #ns.rules do if ns.rules[i].name == "a" then ua2 = ns.rules[i] end end
check("imported cue still follows its rule by uid", (function()
  for i = before + 1, #ns.rules do local r = ns.rules[i]; if r.name == "a cue" then return ua2 and r.parentUid == ua2.uid end end end)())
''')
res = L.eval("results"); bad = 0
for i in range(1, len(res) + 1):
    n, ok = res[i][1], res[i][2]
    if not ok: bad += 1; print("FAIL:", n)
print("%d checks, %d failed" % (len(res), bad)); sys.exit(1 if bad else 0)
