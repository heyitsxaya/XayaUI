#!/usr/bin/env python3
"""Group to group anchors, B (Rules 0.6.82; REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #18, her words: "I should be able to anchor
to another rule group's position"; screenshot: the frame picker's banner over another group, Active Mitigation, that it could not
pick). Her decisions, each checked here on the real addons in the stand-in game (tests/harness):
  - it follows the other group's FRAME (stable, no watcher); geometry with scale: tests/group_anchors_run.py;
  - picked BOTH ways: (1) the on-screen picker ('Anchor to a frame on screen...'): every group's mover tag shows while it is open;
    pointing at a group's tag or outline outlines it with the group's name; Shift picks it; a group cannot pick itself or anything
    that makes a loop; (2) "Another group" in the settings page's "Relative to" list, with a group list that leaves loops out;
  - saved as cRel = "group", cGroup = <id>; the mover's Cancel undoes it (F_KEYS); "Anchor to the screen" clears it;
  - the X / Y box reads "Anchored to group '<name>'"; Snap flush works against that group's box;
  - the followed group deleted: "Stays put, link cleared" (the group keeps its place and is placed from the screen);
  - imports re-point the link to the imported copy, and drop a link to a group that was not exported.
Negative control: on 897ae70 (before this change) the picker never offers a group and the checks fail.
Run: python3 tests/group_to_group_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function has(s, p) return type(s) == "string" and s:find(p, 1, true) ~= nil end
SHIFT, FOCI, CX, CY = false, {}, 0, 0
IsShiftKeyDown = function() return SHIFT end
GetMouseFoci = function() return FOCI end
GetCursorPosition = function() return CX, CY end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
check("core loaded with the picker and the group anchor", ns and type(ns.PickFrame) == "function" and type(ns.AnchorGroupToGroup) == "function", ns and type(ns.AnchorGroupToGroup))
if not (ns and ns.AnchorGroupToGroup) then return R end
ns.folders = { { id = "fA", name = "Items + Consumables" }, { id = "fB", name = "Active Mitigation", cType = "dynamic", cGrowth = "DOWN", cX = 300, cY = 0 },
  { id = "fC", name = "Elsewhere", cX = -500, cY = 300 } }
CueRulesDB.folders = ns.folders
local function rule(name, folder, x, y)
  local r = ns.NewRule(); r.name = name; r.folder = folder; r.enabled = true
  ns.NormalizeRule(r); r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.w, r.visual.h = 30, 30
  return r
end
local a1, a2 = rule("Healthstone", "fA", -20, 0), rule("Potion", "fA", 20, 0)
local b1, b2 = rule("Demon Spikes", "fB", 0, 0), rule("Fiery Brand", "fB", 0, 0)
local c1 = rule("Far away", "fC", 0, 0)
ns.rules = { a1, a2, b1, b2, c1 }
CueRulesDB.rules = ns.rules
ns.ToggleUnlock(); W.tick(0.05, 3)
local A, B, C = ns.FolderById("fA"), ns.FolderById("fB"), ns.FolderById("fC")
local function bounds(list)
  local l, b, r, t
  for _, rr in ipairs(list) do
    local f = ns.DisplayFrame(rr); local fl, fb, fw, fh = f:GetRect()
    l = l and math.min(l, fl) or fl; b = b and math.min(b, fb) or fb; r = r and math.max(r, fl + fw) or (fl + fw); t = t and math.max(t, fb + fh) or (fb + fh)
  end
  return l, b, r, t
end
local function near(x, y) return math.abs(x - y) <= 1 end
local function mid(f) local l, b, w, h = f:GetRect(); return l + w / 2, b + h / 2 end

-- (1) the picker, from A's X / Y box
local tagA, tagB = ns.GroupTagFor("fA"), ns.GroupTagFor("fB")
tagA:GetScript("OnMouseUp")(tagA, "RightButton")
local pop = _G.XayaUIGroupPosPopup
local btn
for _, k in ipairs(pop._kids or {}) do if k.GetText and k:GetText() == "Anchor to a frame on screen..." then btn = k end end
if not btn then check("the X / Y box has Anchor to a frame on screen...", false); return R end
local l0, b0, r0, t0 = bounds({ a1, a2 })
btn:Click()
local P = ns.FramePicker()
check("the picker opens for the group, its banner names groups too", P and P:IsShown() and has(P.text:GetText(), "a frame or a group"), P and P.text:GetText())
W.tick(0.05, 2)
check("every group's mover tag shows while the picker is open", tagB:IsShown() and ns.GroupTagFor("fC"):IsShown() and tagB:GetAlpha() > 0)
-- pointing at B's tag
CX, CY = mid(tagB); W.tick(0.05, 1)
check("pointing at another group's tag outlines it, labelled with the group's name", P.candGroup == B and P.hi:IsShown() and P.hi.label:GetText() == "Active Mitigation", tostring(P.candName))
-- pointing at B's outline (inside what it shows)
local bl, bb, br, bt = bounds({ b1, b2 })
CX, CY = (bl + br) / 2, (bb + bt) / 2; W.tick(0.05, 1)
check("pointing at the group's outline picks the same group", P.candGroup == B, tostring(P.candName))
local hl, hb = P.hi:GetLeft(), P.hi:GetBottom()
check("  ...and the outline drawn is around that group's displays (4 px out)", near(hl, bl - 4) and near(hb, bb - 4), ("%.1f,%.1f vs %.1f,%.1f"):format(hl, hb, bl - 4, bb - 4))
-- pointing at its own outline: nothing (a group cannot pick itself)
CX, CY = (l0 + r0) / 2, (b0 + t0) / 2; W.tick(0.05, 1)
check("pointing at the group's own outline offers nothing (a group cannot pick itself)", P.candGroup == nil and not (P.hi:IsShown() and P.hi.label:GetText() == "Items + Consumables"), tostring(P.candName))
-- Shift on B
CX, CY = mid(tagB); W.tick(0.05, 1)
SHIFT = true; W.tick(0.05, 1); SHIFT = false
check("Shift picks it: the picker closes", not P:IsShown())
check("saved as cRel = 'group', cGroup = the other group's id", A.cRel == "group" and A.cGroup == "fB" and A.cFrame == nil, tostring(A.cRel) .. " " .. tostring(A.cGroup))
W.tick(0.05, 2)
local l1, b1_, r1, t1 = bounds({ a1, a2 })
check("anchoring does not move the group", near(l1, l0) and near(b1_, b0) and near(r1, r0) and near(t1, t0), ("%.1f,%.1f -> %.1f,%.1f"):format(l0, b0, l1, b1_))
check("the X / Y box reads Anchored to group '<name>'", has(pop.anchorText:GetText(), "Anchored to group '") and has(pop.anchorText:GetText(), "Active Mitigation"), pop.anchorText:GetText())
check("  ...and Snap flush is offered for it", pop.flush:IsEnabled())
check("the tags shown for the picker went back to the mover view's (still in it: still shown)", tagB:IsShown())
-- B moves: A follows (no watcher: the anchors carry it)
B.cX = (B.cX or 0) + 100; B.cY = (B.cY or 0) + 40; ns.RefreshAllVisuals(); W.tick(0.05, 2)
local l2, b2_ = bounds({ a1, a2 })
check("when the followed group moves (+100, +40) the group moves with it", near(l2, l1 + 100) and near(b2_, b1_ + 40), ("%.1f,%.1f"):format(l2 - l1, b2_ - b1_))
-- the loop: B may not pick A now (A follows B)
local picked
ns.PickFrame("x", function(_, _, g) picked = g end, B)
CX, CY = mid(tagA); W.tick(0.05, 1)
check("a loop is never offered: the followed group cannot pick the group that follows it", P.candGroup == nil, tostring(P.candName))
P.cancel:Click()
check("  ...(Cancel closes the picker)", not P:IsShown() and picked == nil)
-- Snap flush against B's box
ns.SnapGroupFlush(A); W.tick(0.05, 2)
local _, _, r3 = bounds({ a1, a2 })
local bl3 = bounds({ b1, b2 })
check("Snap flush: the group's right edge touches the followed group's left edge", near(r3, bl3), ("%.1f / %.1f"):format(r3, bl3))

-- (2) the settings page: "Another group" and its list
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
local CG = ns.FolderContainerGroup and ns.FolderContainerGroup(A).args
check("the settings page's Relative to list has Another group (saved as 'group')", CG and CG.rel.values.group == "Another group" and (function() for _, k in ipairs(CG.rel.sorting) do if k == "group" then return true end end end)())
local vals = CG and CG.relGroup and CG.relGroup.values()
check("  ...with a group list: the other groups, not this one", vals and vals.fB ~= nil and vals.fC ~= nil and vals.fA == nil, vals and table.concat((function() local t = {}; for k in pairs(vals) do t[#t + 1] = k end; return t end)(), ","))
check("  ...the list shows while Another group is picked, and reads the group it follows", CG and not CG.relGroup.hidden() and CG.relGroup.get() == "fB")
local CGB = ns.FolderContainerGroup(B).args
local valsB = CGB.relGroup.values()
check("  ...a group that would make a loop is left out (B's list has no A: A follows B)", valsB.fA == nil and valsB.fC ~= nil)
CG.rel.set(nil, "screen")
check("  ...picking another entry clears the group link", A.cRel == nil and A.cGroup == nil)
CG.rel.set(nil, "group"); CG.relGroup.set(nil, "fC")
check("  ...picking a group from the list saves it", A.cRel == "group" and A.cGroup == "fC")
CG.relGroup.set(nil, "fB")

-- the mover's Cancel undoes the anchor (the draft was taken when the mover view opened)
ns.MoverExit("cancel"); W.tick(0.05, 2)
check("the mover view's Cancel moves undoes the group anchor (cGroup is part of the draft)", A.cRel == nil and A.cGroup == nil, tostring(A.cRel) .. " " .. tostring(A.cGroup))

-- the picker outside the mover view: the tags show while it is open, and go when it closes
ns.PickFrame("x", function() end, A); W.tick(0.05, 2)
check("outside the mover view, the tags show while the picker is open for a group", tagB:IsShown() and not ns.unlocked)
ns.FramePicker().cancel:Click(); W.tick(0.05, 2)
check("  ...and are gone once it closes", not tagB:IsShown())

-- deleting the followed group: "Stays put, link cleared"
ns.AnchorGroupToGroup(A, B); W.tick(0.05, 2)
check("anchored again through the same path", A.cRel == "group" and A.cGroup == "fB")
local l4, b4 = bounds({ a1, a2 })
ns.RecycleFolder(B); ns.RefreshAllVisuals(); W.tick(0.05, 2)
local l5, b5 = bounds({ a1, a2 })
check("the followed group deleted: the group stays where it is and the link is cleared", A.cRel == nil and A.cGroup == nil and near(l5, l4) and near(b5, b4),
  ("%s %s %.1f,%.1f -> %.1f,%.1f"):format(tostring(A.cRel), tostring(A.cGroup), l4, b4, l5, b5))

-- imports: the link follows the imported copy; a link to a group that was not exported is dropped
ns.folders[#ns.folders + 1] = { id = "fP", name = "Pack" }
ns.folders[#ns.folders + 1] = { id = "fQ", name = "Lead", parent = "fP" }
ns.folders[#ns.folders + 1] = { id = "fR", name = "Follows lead", parent = "fP", cRel = "group", cGroup = "fQ" }
ns.folders[#ns.folders + 1] = { id = "fS", name = "Follows outside", parent = "fP", cRel = "group", cGroup = "fC" }
local snap = ns.Share_SnapshotGroup(ns.FolderById("fP"))
ns.Share_ApplyRules(snap, "add")
local newQ, newR, newS
for _, f in ipairs(ns.folders) do
  if f.id ~= "fQ" and f.name == "Lead" then newQ = f end
  if f.id ~= "fR" and f.name == "Follows lead" then newR = f end
  if f.id ~= "fS" and f.name == "Follows outside" then newS = f end
end
check("import: the copy follows the imported copy of its group", newR and newQ and newR.cRel == "group" and newR.cGroup == newQ.id, newR and tostring(newR.cGroup))
check("import: a link to a group that was not exported is dropped (placed from the screen / parent)", newS and newS.cRel == nil and newS.cGroup == nil, newS and tostring(newS.cGroup))
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
