# tests/recycle_bin_run.py: the Recycle Bin (#88, XayaUI/RecycleBin.lua) and the delete paths in the settings window
# (XayaUI_Options/Options.lua and the rule editor, XayaUI_Rules/Editor/*.lua).
# Checks what ends up where: which rules and groups are live, which are in the bin, and what comes back on Restore.
# Run from the repo root: python3 tests/recycle_bin_run.py   Needs: pip install lupa.
import glob, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

def window_src():   # (P3 options split) the settings window's code: Options.lua and the rule editor's files (Rules 0.7.0: XayaUI_Rules/Editor/)
    d = os.path.join(ROOT, "XayaUI_Options")
    return "\n".join(open(p, encoding="utf-8").read() for p in [os.path.join(d, "Options.lua")] + sorted(glob.glob(os.path.join(ROOT, "XayaUI_Rules", "Editor", "*.lua"))))

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
NOW = 1793660000
time = function() return NOW end
date = function(f, t) return "2026-11-04 06:00" end
CueRulesDB = {}
dropped, refreshed, uidN = {}, {}, 0
ns = { rules = {}, folders = {} }
function ns.DropVisual(r) dropped[#dropped + 1] = r end
function ns.RefreshVisual(r) refreshed[#refreshed + 1] = r end
function ns.MarkDirty() end
function ns.NewUID() uidN = uidN + 1; return "unew" .. uidN end
function ns.NormalizeRule(r) r.normalized = true end
''')
# (core 0.6.74) the bin's kinds are registered through the Platform's contract (Modules.lua ns.RegisterBinKind), which core loads first
lua.execute('local fn = assert(loadfile(...)); fn("XayaUI", ns)'.replace("...", repr(os.path.join(ROOT, "XayaUI/Modules.lua")).replace("'", '"')))
lua.execute('local fn = assert(loadfile(...)); fn("XayaUI", ns)'.replace("...", repr(os.path.join(ROOT, "XayaUI/RecycleBin.lua")).replace("'", '"')))
lua.execute('local fn = assert(loadfile(...)); fn("XayaUI_Rules", ns)'.replace("...", repr(os.path.join(ROOT, "XayaUI_Rules/RuleBin.lua")).replace("'", '"')))   # (P4) the rule kinds
out = lua.execute(r'''
local fails, n, lines = 0, 0, {}
local function check(name, cond, extra)
  n = n + 1
  if not cond then fails = fails + 1; lines[#lines + 1] = "FAIL: " .. name .. (extra and ("  -> " .. tostring(extra)) or "") end
end
local function has(list, x) for _, v in ipairs(list) do if v == x then return true end end return false end
local function reset() ns.rules, ns.folders, CueRulesDB, dropped, refreshed = {}, {}, {}, {}, {}; NOW = 1793660000 end
local function byUid(u) for _, r in ipairs(ns.rules) do if r.uid == u then return r end end end
local function fold(id) for _, f in ipairs(ns.folders) do if f.id == id then return f end end end

-- 1. one rule with its cues and condition; another rule untouched
reset()
local P = { id = "f100", name = "Parent" }; ns.folders = { P }
local A = { uid = "uA", name = "A", folder = "f100" }
local c1 = { uid = "uc1", parentUid = "uA", isCue = true }
local c2 = { uid = "uc2", parentUid = "uA", isCue = true }
local cond = { uid = "ucond", parentUid = "uA" }
local B = { uid = "uB", name = "B" }
ns.rules = { A, c1, B, c2, cond }
local item = ns.RecycleRule(A)
check("rule: item made", item and item.kind == "rule")
check("rule: only B is live", #ns.rules == 1 and ns.rules[1] == B, #ns.rules)
check("rule: cues and condition went with it", #item.rules == 4)
check("rule: displays dropped for all four", #dropped == 4, #dropped)
check("rule: listed in the bin", #ns.RecycleItems() == 1 and ns.RecycleItems()[1].rules == 1)
local ok, note = ns.RecycleRestore(item.id)
check("rule restore: ok", ok)
check("rule restore: all five live", #ns.rules == 5)
check("rule restore: same group", byUid("uA").folder == "f100")
check("rule restore: cues still point at it", byUid("uc1").parentUid == "uA" and byUid("ucond").parentUid == "uA")
check("rule restore: bin empty", #ns.RecycleItems() == 0)
check("rule restore: displays refreshed", #refreshed == 4, #refreshed)

-- 2. its group is gone when restored: top level, and the note says so
reset()
ns.folders = { { id = "f200", name = "G" } }
local R = { uid = "uR", name = "R", folder = "f200" }
ns.rules = { R }
local it = ns.RecycleRule(R)
ns.folders = {}
local ok2, note2 = ns.RecycleRestore(it.id)
check("orphan: restored at the top level", ok2 and byUid("uR").folder == nil)
check("orphan: note says top level", type(note2) == "string" and note2:find("top level", 1, true) ~= nil, note2)

-- 3. a live rule took the uid meanwhile: the restored rule gets a new uid and its cues follow
reset()
local X = { uid = "uX", name = "X" }; local xc = { uid = "uxc", parentUid = "uX", isCue = true }
ns.rules = { X, xc }
local it3 = ns.RecycleRule(X)
local clash = { uid = "uX", name = "Imported X" }; ns.rules[#ns.rules + 1] = clash
ns.RecycleRestore(it3.id)
check("uid clash: the live rule keeps its uid", byUid("uX") == clash)
check("uid clash: restored rule renamed uid", X.uid ~= "uX" and X.uid:find("unew", 1, true) == 1, X.uid)
check("uid clash: its cue follows", xc.parentUid == X.uid)

-- 4. several rules: one item each, restored one at a time
reset()
local m1, m2, m3 = { uid = "u1" }, { uid = "u2" }, { uid = "u3" }
ns.rules = { m1, m2, m3 }
check("multi: two items", ns.RecycleRules({ m1, m3 }) == 2 and #ns.RecycleItems() == 2)
local first = ns.RecycleItems()[1]
ns.RecycleRestore(first.id)
check("multi: one back, one still in the bin", #ns.rules == 2 and #ns.RecycleItems() == 1)

-- 5. a group on its own: contents move up; Restore moves back what is still there
reset()
local Top = { id = "f1", name = "Top" }; local G = { id = "f2", name = "G", parent = "f1" }; local H = { id = "f3", name = "H", parent = "f2" }
ns.folders = { Top, G, H }
local r1 = { uid = "ur1", folder = "f2" }; local r2 = { uid = "ur2", folder = "f2" }
ns.rules = { r1, r2 }
local it5 = ns.RecycleFolder(G)
check("group: gone from the live groups", fold("f2") == nil)
check("group: rules moved up", r1.folder == "f1" and r2.folder == "f1")
check("group: nested group moved up", H.parent == "f1")
check("group: no rule went to the bin", #ns.rules == 2)
r2.folder = nil   -- the player moved r2 somewhere else in the meantime
ns.RecycleRestore(it5.id)
check("group restore: group back", fold("f2") == G and G.parent == "f1")
check("group restore: r1 back inside", r1.folder == "f2")
check("group restore: r2 left where the player put it", r2.folder == nil)
check("group restore: nested group back inside", H.parent == "f2")

-- 6. a group with its contents: ONE item, restored together
reset()
local G6 = { id = "f10", name = "G6" }; local H6 = { id = "f11", name = "H6", parent = "f10" }; local O = { id = "f12", name = "Other" }
ns.folders = { G6, H6, O }
local a = { uid = "ua", folder = "f10" }; local ac = { uid = "uac", parentUid = "ua", isCue = true, folder = "f10" }
local b = { uid = "ub", folder = "f11" }; local keep = { uid = "uk", folder = "f12" }
ns.rules = { a, ac, b, keep }
local it6, nTop = ns.RecycleFolderAll(G6)
check("group+contents: one item", #ns.RecycleItems() == 1 and it6.kind == "groupAll")
check("group+contents: two rules counted", nTop == 2, nTop)
check("group+contents: only the other group's rule is live", #ns.rules == 1 and ns.rules[1] == keep)
check("group+contents: only the other group is live", #ns.folders == 1 and ns.folders[1] == O)
check("group+contents: listed with 2 rules and 2 groups", ns.RecycleItems()[1].rules == 2 and ns.RecycleItems()[1].groups == 2)
ns.RecycleRestore(it6.id)
check("group+contents restore: all rules back", #ns.rules == 4)
check("group+contents restore: groups back with their links", fold("f10") == G6 and fold("f11") == H6 and H6.parent == "f10")
check("group+contents restore: rules back in their groups", a.folder == "f10" and b.folder == "f11" and ac.parentUid == "ua")

-- 7. a live group took the id meanwhile: the restored group gets a new id, and its rules and nested group follow
reset()
local G7 = { id = "f20", name = "G7" }; local H7 = { id = "f21", name = "H7", parent = "f20" }
ns.folders = { G7, H7 }
local q = { uid = "uq", folder = "f20" }; local q2 = { uid = "uq2", folder = "f21" }
ns.rules = { q, q2 }
local it7 = ns.RecycleFolderAll(G7)
local taken = { id = "f20", name = "New group" }; ns.folders[#ns.folders + 1] = taken
ns.RecycleRestore(it7.id)
check("id clash: the live group keeps its id", fold("f20") == taken)
check("id clash: restored group has a new id", G7.id ~= "f20" and fold(G7.id) == G7, G7.id)
check("id clash: its rule follows", q.folder == G7.id)
check("id clash: its nested group follows", H7.parent == G7.id)
check("id clash: nested group's rule kept", q2.folder == H7.id)

-- 8. keep time: 7 days by default, 36 hours / 3 days / 14 days allowed, anything else refused
reset()
check("keep: default 7 days", ns.RecycleKeepHours() == 168 and ns.RecycleKeepLabel() == "7 days")
check("keep: prompt names it", ns.RecycleBinNote():find("7 days", 1, true) ~= nil, ns.RecycleBinNote())
ns.SetRecycleKeepHours(5)
check("keep: 5 hours refused", ns.RecycleKeepHours() == 168)
ns.rules = { { uid = "up" } }
ns.RecycleRule(ns.rules[1])
NOW = NOW + 167 * 3600
check("purge: still there after 167 h", ns.RecyclePurge() == 0 and #ns.RecycleItems() == 1)
check("purge: hours left about 1", math.abs(ns.RecycleItems()[1].hoursLeft - 1) < 0.01, ns.RecycleItems()[1].hoursLeft)
NOW = NOW + 2 * 3600
check("purge: gone after 169 h", ns.RecyclePurge() == 1 and #ns.RecycleItems() == 0)
ns.rules = { { uid = "uq9" } }
ns.RecycleRule(ns.rules[1])
NOW = NOW + 37 * 3600
ns.SetRecycleKeepHours(336)
check("keep: 14 days keeps a 37 h old item", #ns.RecycleItems() == 1)
-- FA-14 (core 0.6.67; Xaya: "Ask first"): the page asks with this count before a shorter time removes anything
check("FA-14 RecycleWouldPurge: 36 hours would remove the 37 h old item, 72 hours none, and nothing is removed by asking",
  ns.RecycleWouldPurge and ns.RecycleWouldPurge(36) == 1 and ns.RecycleWouldPurge(72) == 0 and #ns.RecycleItems() == 1,
  ns.RecycleWouldPurge and ns.RecycleWouldPurge(36))
ns.SetRecycleKeepHours(36)
check("keep: switching to 36 hours removes a 37 h old item at once", #ns.RecycleItems() == 0 and ns.RecycleKeepLabel() == "36 hours")

-- 9. Empty Recycle Bin and Delete now
reset()
ns.rules = { { uid = "e1" }, { uid = "e2" }, { uid = "e3" } }
ns.RecycleRules({ ns.rules[1], ns.rules[2], ns.rules[3] })
local one = ns.RecycleItems()[1]
check("delete now: one removed", ns.RecycleDeleteNow(one.id) and #ns.RecycleItems() == 2)
check("empty: returns the count", ns.RecycleEmpty() == 2 and #ns.RecycleItems() == 0)
check("restore of a removed item refused", not ns.RecycleRestore(one.id))

-- 10. newest first
reset()
ns.rules = { { uid = "o1", name = "old" }, { uid = "o2", name = "new" } }
ns.RecycleRule(ns.rules[1]); NOW = NOW + 60; ns.RecycleRule(ns.rules[1])
check("list: newest first", ns.RecycleItems()[1].name == "new")

return table.concat(lines, "\n") .. "\n@@" .. n .. "@@" .. fails
''')
text = str(out)
body, _, tail = text.rpartition("\n@@")
n_lua, f_lua = (int(x) for x in tail.split("@@"))
if body.strip():
    print(body)

# Wiring: every user delete path in the settings window (Options.lua, the rule editor) goes through the bin, and none removes rules or groups itself.
src = window_src()
wiring_fail, wiring_n = 0, 0


def body_of(start_pat, length=1400):
    m = re.search(start_pat, src)
    return src[m.start():m.start() + length] if m else ""


for name, pat, want in [
    ("Info tab Delete this rule", r'name = "Delete this rule"', "ns.RecycleRule(rule)"),
    ("sidebar DeleteRule", r"local function DeleteRule\(rule\)", "ns.RecycleRule(rule)"),
    ("DeleteFolder (contents move up)", r"local function DeleteFolder\(f\)", "ns.RecycleFolder(f)"),
    ("DeleteFolderAll", r"function ns\.DeleteFolderAll\(f\)", "ns.RecycleFolderAll(f)"),
    ("MultiDelete", r"function ns\.MultiDelete\(\)", "ns.RecycleRules(list)"),
    ("Delete key", r"function ns\.DeleteKey\(\)", "ns.RecycleRule(rule)"),
]:
    wiring_n += 1
    b = body_of(pat, 700)
    cut = b.find("\nend")   # the function's own body only
    b = b if cut < 0 else b[:cut]
    if want not in b or "table.remove(ns.rules" in b or "table.remove(ns.folders" in b:
        wiring_fail += 1
        print("FAIL: %s does not go through the Recycle Bin" % name)
wiring_n += 1
keep = body_of(r'name = "Keep deleted items for"', 1600)
if "RecycleWouldPurge" not in keep or "XAYAUI_CONFIRM" not in keep:
    wiring_fail += 1
    print("FAIL: FA-14 the keep time does not ask before removing items for good")
wiring_n += 1
if "not built yet (GitHub issue #88)" in src:
    wiring_fail += 1
    print("FAIL: the Recycle Bin page still says it is not built")
wiring_n += 1
if "RecycleBin.lua" not in open(os.path.join(ROOT, "XayaUI/XayaUI.toc"), encoding="utf-8").read():
    wiring_fail += 1
    print("FAIL: XayaUI.toc does not load RecycleBin.lua")

total, fails = n_lua + wiring_n, f_lua + wiring_fail
print("%d checks  FAILS: %d" % (total, fails))
sys.exit(1 if fails else 0)
