#!/usr/bin/env python3
"""Offline test (Options 0.6.4, #343): drag and drop in the Rules sidebar. A rule dropped on the top / bottom half of another rule lands
just above / below it (joining its group); a rule dropped on a group row goes into the group; a group dropped on the top / bottom quarter
of another group goes above / below it, in the middle it nests inside; a group can never go inside itself; reordering only swaps rules
among the list positions their group already uses; the gold line / label feedback; dropping off the list does nothing.
Run: python3 tests/drag_drop_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("   [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("drag hooks present", ns and ns.DragForTest and ns.DragPlace)
if not (ns and ns.DragForTest) then return R end
local D = ns.DragForTest
CueRulesDB.ui = CueRulesDB.ui or {}
ns.folders = { { id = "f1", name = "Defensives" }, { id = "f2", name = "Externals" }, { id = "f3", name = "Inner", parent = "f1" }, { id = "f4", name = "Buffs" } }
local function rule(name, folder) local r = ns.NewRule(); r.name = name; r.folder = folder; r.enabled = true; ns.NormalizeRule(r); r.uid = r.uid or ns.NewUID(); return r end
local A, B, C, X, Y = rule("A", "f1"), rule("B", "f1"), rule("C", "f1"), rule("X", "f2"), rule("Y", nil)
local cueB = rule("B icon", "f1"); cueB.isCue = true; cueB.parentUid = B.uid
ns.rules = { A, X, B, cueB, Y, C }
local function idx(r) for i, x in ipairs(ns.rules) do if x == r then return i end end end
local function names(fid) local o = {} for _, r in ipairs(ns.rules) do if r.folder == fid and not r.parentUid then o[#o + 1] = r.name end end return table.concat(o, ",") end
local function row(key) return { uniquevalue = "all\001" .. key } end
local function ruleRow(r) return row("rule" .. idx(r)) end

-- zones: top / bottom half of a rule row; quarters of a group row (folder drags only)
local zb = { GetTop = function() return 100 end, GetBottom = function() return 80 end, GetEffectiveScale = function() return 1 end, uniquevalue = "all\001f1" }
local cy = 0
local oldCur = GetCursorPosition
GetCursorPosition = function() return 10, cy end
cy = 97; check("zone: rule row top half = above", D.zone(zb, "rule", false) == "before")
cy = 83; check("zone: rule row bottom half = below", D.zone(zb, "rule", false) == "after")
cy = 98; check("zone: group row top quarter (dragging a group) = above", D.zone(zb, "folder", true) == "before")
cy = 90; check("zone: group row middle = into", D.zone(zb, "folder", true) == "into")
cy = 82; check("zone: group row bottom quarter = below", D.zone(zb, "folder", true) == "after")
cy = 98; check("zone: a RULE over a group row always goes into it", D.zone(zb, "rule", true) == "into")
zb.obj = { status = { groups = { ["all\001f1"] = true } } }
cy = 82; check("zone: bottom of an OPEN group = into (below would land after all its contents)", D.zone(zb, "folder", true) == "into")
GetCursorPosition = oldCur

-- the drop target logic
local ok, t, an, wh = D.target(ruleRow(A), "rule", C, "before")
check("rule on rule (top half): above that rule, in its group", ok and t == "f1" and an == A and wh == "before")
ok = D.target(ruleRow(C), "rule", C, "before")
check("rule on itself: no drop", not ok)
ok, t, an, wh = D.target(row("f2"), "rule", A, "before")
check("rule on group row: into the group", ok and t == "f2" and an == nil and wh == "into")
ok, t, an, wh = D.target(row("all"), "rule", A, "into")
check("rule on All rules: top level", ok and t == nil and wh == "into")
ok, t, an, wh = D.target(ruleRow(cueB), "rule", C, "after")
check("rule on a cue row: stands for the cue's rule", ok and an == B and t == "f1")
ok = D.target(row("f3"), "folder", ns.folders[1], "into")
check("group into its own sub-group: refused", not ok)
ok = D.target(row("f1"), "folder", ns.folders[1], "into")
check("group onto itself: refused", not ok)
ok, t, an, wh = D.target(row("f2"), "folder", ns.folders[4], "before")
check("group on group top quarter: above it, same parent", ok and t == nil and an == ns.folders[2] and wh == "before")
ok, t, an, wh = D.target({ uniquevalue = "disabled\001f2" }, "folder", ns.folders[4], "before")
check("Disabled list (flat): no above / below for groups, only into", ok and t == "f2" and an == nil and wh == "into")

-- placing
local slotsBefore = { idx(A), idx(B), idx(C) }
check("place: C above A", ns.DragPlace("rule", C, "f1", A, "before") and names("f1") == "C,A,B", names("f1"))
check("place: the group keeps the same list positions (other rows do not move)", idx(X) == 2 and idx(cueB) == 4 and idx(Y) == 5 and idx(C) == slotsBefore[1], idx(C))
check("place: A below B", ns.DragPlace("rule", A, "f1", B, "after") and names("f1") == "C,B,A", names("f1"))
check("place: the cue stays tied to its rule", cueB.parentUid == B.uid and idx(cueB) == 4)
check("place: Y (top level) below B joins Defensives", ns.DragPlace("rule", Y, "f1", B, "after") and Y.folder == "f1" and names("f1") == "C,B,Y,A", names("f1"))
check("place: X into Defensives with no anchor goes to the end", ns.DragPlace("rule", X, "f1", nil, "into") and names("f1"):sub(-1) == "X", names("f1"))
check("place: a drop onto where it already is changes nothing", ns.DragPlace("rule", B, "f1", C, "after") == false, names("f1"))
CueRulesDB.ui.folderOrdered = nil
check("place: group Buffs above Externals", ns.DragPlace("folder", ns.folders[4], nil, ns.folders[2], "before"))
local top = {}
for _, f in ipairs(ns.folders) do if not f.parent then top[#top + 1] = f.name end end
check("place: top-level group order is now Defensives, Buffs, Externals", table.concat(top, ",") == "Defensives,Buffs,Externals", table.concat(top, ","))
check("place: group order switched to list order (folderOrdered)", CueRulesDB.ui.folderOrdered == true)
local inner = ns.folders[3].name == "Inner" and ns.folders[3] or nil
for _, f in ipairs(ns.folders) do if f.name == "Inner" then inner = f end end
check("place: group Inner (nested) dropped in the middle of Externals nests there", ns.DragPlace("folder", inner, "f2", nil, "into") and inner.parent == "f2")

-- the whole drag: start on a row, feedback while over another, drop
local fakeTree = { buttons = {} }
local function fakeRow(uv, top)
  local b = { uniquevalue = uv, obj = fakeTree, over = false, locked = false }
  function b:IsShown() return true end
  function b:IsMouseOver() return self.over end
  function b:GetTop() return top end
  function b:GetBottom() return top - 20 end
  function b:GetEffectiveScale() return 1 end
  function b:LockHighlight() self.locked = true end
  function b:UnlockHighlight() self.locked = false end
  local tex = {}
  function b:CreateTexture() local t = CreateFrame("Frame"):CreateTexture(); t._owner = b; local gp = t.GetParent; function t:GetParent() return b end; return t end
  fakeTree.buttons[#fakeTree.buttons + 1] = b
  return b
end
local src = fakeRow("all\001f1\001rule" .. idx(A), 200)
local dst = fakeRow("all\001f1\001rule" .. idx(C), 100)
D.start(src)
check("drag starts on a rule row", D.state.obj == A)
dst.over = true
GetCursorPosition = function() return 10, 96 end
local lf = CreateFrame("Frame"); lf.text = lf:CreateFontString()
local okT, eT = pcall(D.state.tick, lf)
local lbl = D.state.shown or ""
local lp = D.state.line and D.state.line._pts and D.state.line._pts[1]
check("while over the top half: a gold line at the TOP of the row, no row glow", okT and D.state.line and D.state.line:IsShown() and not dst.locked and lp and lp[1] == "TOPLEFT", eT)
check("the floating label says 'above C'", lbl:find("above") and lbl:find("C"), lbl)
D.stop(src)
GetCursorPosition = oldCur
check("drop: A now sits above C", names("f1"):find("A,C") ~= nil, names("f1"))
check("drop: line removed afterwards", D.state.line == nil)
-- dropping off the list does nothing
local before = names("f1")
D.start(src); dst.over = false
D.stop(src)
check("drop outside any row: nothing moves", names("f1") == before)
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = ["XayaUI", "XayaUI_Media", "XayaUI_Options"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), H.to_lua(L, {}))
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        if not ok:
            bad += 1
            print("FAIL:", name)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
