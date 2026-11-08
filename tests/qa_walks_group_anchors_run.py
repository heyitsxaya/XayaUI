#!/usr/bin/env python3
"""In-game QA walkthrough for the group anchors of Rules 0.6.82 (XayaUI_DevAssist 0.7.72, XayaUI_DevAssist/QAWalks-group-anchors.lua; QA
B350-B356; REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #14, #16, #18, #28 and her answer on hand-placed groups). Xaya's rule V22
(2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through
with pre-fill confirmation options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game and runs each step as a player would (Do it for me, then the check):
  - registered with pre-fill for B350-B356; the last step is a Done step; B353 is a question (noVerdict) with the update's record;
  - before Do it for me: "not tested" (nil), never Pass;
  - step 1 (grid corner): Pass; negative: the group's point moved without the icons gives Fail;
  - step 2 (outline): Pass; negative: the group moved after the check's snapshot gives Fail ("MOVED");
  - step 3 (Icons move): Pass; negative: X / Y changed gives Fail;
  - step 5 (picker): nil before Shift; pointing at the target's tab and Shift: Pass; negative: linked to another group gives Fail;
  - steps 6-8 (follows, settings list, deleted): Pass;
  - Done: the target group is gone, the mover view is closed, the QA test group's position settings are back.
Run: python3 tests/qa_walks_group_anchors_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function has(s, p) return type(s) == "string" and s:find(p, 1, true) ~= nil end
SHIFT, CX, CY = false, 0, 0
IsShiftKeyDown = function() return SHIFT end
GetCursorPosition = function() return CX, CY end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local QA = rawget(_G, "XayaUI_DevQA")
local def = QA and QA.walks["group-anchors"]
check("the group anchors walkthrough is registered with pre-fill, for B350-B356", def ~= nil and def.prefill == true and def.qa == "B350, B351, B352, B353, B354, B355, B356", def and def.qa)
if not def then return R end
check("its last step is a Done step", def.steps[#def.steps].done == true)
check("step 4 (the one-time update) is a question for her", def.steps[4].noVerdict == true)
ns.Print = function() end
local ok0 = def.steps[1].check()
check("step 1 before Do it for me: not tested (no verdict)", ok0 == nil, tostring(ok0))
local function run(i) local st = def.steps[i]; if st.setup then st.setup() end; W.tick(0.1, 6); if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 3); return st.check() end
local ok1, n1 = run(1)
check("step 1 (a Right grid, Bottom left): Pass, the grid's bottom-left on the point", ok1 == true and has(n1, "on it"), n1)
local T = QA.GroupAnchorsTest
local tgt
for _, f in ipairs(ns.folders) do if f.name == "QA anchor target" then tgt = f end end
if tgt then
  tgt.cX = 10   -- the group's point moved, the icons not redrawn
  local okn, nn = def.steps[1].check()
  check("step 1 negative: icons off the group's point give Fail", okn == false and has(nn, "OFF by"), tostring(okn) .. " " .. tostring(nn))
  tgt.cX = 0; ns.RefreshAllVisuals()
else check("step 1 made the QA anchor target", false) end
local okb = def.steps[2].check()
check("step 2 before Do it for me: not tested (no verdict)", okb == nil, tostring(okb))
local ok2, n2 = run(2)
check("step 2 (hand-placed, Bottom left, one display not showing): Pass", ok2 == true and has(n2, "on it") and has(n2, "did not move") and has(n2, "not showing"), n2)
local g = ns.FolderById(T.State.fid)
g.cX = 25; ns.RefreshAllVisuals()
local ok2n, n2n = def.steps[2].check()
check("step 2 negative: the group moved since the snapshot gives Fail", ok2n == false and has(n2n, "MOVED"), tostring(ok2n) .. " " .. tostring(n2n))
g.cX = 0; ns.RefreshAllVisuals()
local ok3, n3 = run(3)
check("step 3 (point changed to Top right): Pass, X / Y unchanged", ok3 == true and has(n3, "on it") and has(n3, "unchanged"), n3)
g.cX = 5
local ok3n, n3n = def.steps[3].check()
check("step 3 negative: X / Y changed gives Fail", ok3n == false and has(n3n, "CHANGED"), tostring(ok3n) .. " " .. tostring(n3n))
g.cX = 0; ns.RefreshAllVisuals()
local ok4, n4 = def.steps[4].check()
check("step 4 (the one-time update): a question with the record in the note", ok4 == nil and has(n4, "Update done: yes"), n4)
local st5 = def.steps[5]
st5.setup(); W.tick(0.1, 4)
local ok5a = st5.check()
check("step 5 before Shift: not tested (no verdict)", ok5a == nil, tostring(ok5a))
local P = ns.FramePicker()
check("step 5's Do it for me opens the picker for the QA test group", P and P:IsShown() and P.forGroup == g)
local tag = ns.GroupTagFor(tgt.id)
local l, b, w, h = tag:GetRect()
CX, CY = l + w / 2, b + h / 2; W.tick(0.05, 1)
check("  ...the QA anchor target's tab is outlined with its name", P.candGroup == tgt and P.hi.label:GetText() == "QA anchor target", tostring(P.candName))
SHIFT = true; W.tick(0.05, 1); SHIFT = false; W.tick(0.05, 2)
local ok5, n5 = st5.check()
check("step 5 after Shift: Pass, anchored to the target, in place, the box names it", ok5 == true and has(n5, "the QA anchor target") and has(n5, "Anchored to group 'QA anchor target'"), n5)
local keep = g.cGroup
g.cGroup = "f0"
local ok5n, n5n = st5.check()
check("step 5 negative: linked to another group gives Fail", ok5n == false, tostring(ok5n) .. " " .. tostring(n5n))
g.cGroup = keep; ns.RefreshAllVisuals()
local ok6, n6 = run(6)
check("step 6 (the target moves): Pass, the group moved with it", ok6 == true and has(n6, "moved X +40.0, Y +20.0"), n6)
local ok7, n7 = run(7)
check("step 7 (settings: Another group, its list): Pass", ok7 == true and has(n7, "has 'Another group'") and has(n7, "without the group itself"), tostring(ok7) .. " " .. tostring(n7))
local ok8, n8 = run(8)
check("step 8 (the target deleted): Pass, stays put, link cleared", ok8 == true and has(n8, "stayed where it was") and has(n8, "is cleared"), n8)
def.steps[#def.steps].setup(); W.tick(0.1, 3)
local gone = true
for _, f in ipairs(ns.folders) do if f.name == "QA anchor target" then gone = false end end
check("Done: the target group is gone, the mover view is closed, the QA test group's settings are back", gone and not ns.unlocked and g.cRel == nil and g.cPoint == nil)
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + str(name)[:900])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    return 1 if bad or errs else 0


if __name__ == "__main__":
    sys.exit(main())
