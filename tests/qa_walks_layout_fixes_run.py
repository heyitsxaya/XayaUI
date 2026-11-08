#!/usr/bin/env python3
"""In-game QA walkthrough for the layout fixes of 2026-11-08 (XayaUI_DevAssist 0.7.72, XayaUI_DevAssist/QAWalks-layout-fixes.lua; QA
B301-B304; REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #7, #11, #12). Xaya's rule V22 (2026-11-07): "make sure every feature or
significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data
capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game and runs each step as a player would (Do it for me, then the check):
  - registered with pre-fill for B301-B305; the last step is a Done step;
  - before Do it for me: step 1 says "not tested" (nil), never Pass;
  - step 1: Pass, one screen line per table row; negative: a cell moved onto the line above gives Fail;
  - step 2: before the drag "not tested" (nil); after the box is moved, Pass with both positions in the note;
  - step 3: Pass, every button fits its label; negative: a button narrowed by hand gives Fail and names it;
  - step 4: Pass; negative: a group anchored to the box is listed and gives Fail;
  - Done: the box is closed and the mover view is closed again.
Run: python3 tests/qa_walks_layout_fixes_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function has(s, p) return type(s) == "string" and s:find(p, 1, true) ~= nil end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local QA = rawget(_G, "XayaUI_DevQA")
local def = QA and QA.walks["layout-fixes"]
check("the layout walkthrough is registered with pre-fill, for B301-B304", def ~= nil and def.prefill == true and def.qa == "B301, B302, B303, B304, B305")
if not def then return R end
check("its last step is a Done step", def.steps[#def.steps].done == true)
ns.Print = function() end
local ok0 = def.steps[1].check()
check("step 1 before Do it for me: not tested (no verdict)", ok0 == nil, tostring(ok0))
local function run(i) local st = def.steps[i]; if st.setup then st.setup() end; W.tick(0.1, 8); if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 3); return st.check() end
local ok1, n1 = run(1)
check("step 1 (the Theme table): Pass, one line per row", ok1 == true and has(n1, "Each line starts with its element's name"), n1)
-- negative: one row's Theme list drawn on the line above
local ACD = LibStub("AceConfigDialog-3.0")
local dd
local function walk(w) if type(w) ~= "table" then return end; local o = w.GetUserData and w:GetUserData("option"); if not dd and w.type == "Dropdown" and o and type(o.arg) == "table" and o.arg.xuiCell then dd = w end; for _, c in ipairs(w.children or {}) do walk(c) end end
walk(ACD.OpenFrames.CueRules)
if dd then
  local p = { dd.frame:GetPoint(1) }
  dd.frame:ClearAllPoints(); dd.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 5000, 5000)
  local okn, nn = def.steps[1].check()
  check("step 1 negative: a cell drawn off its row gives Fail", okn == false, tostring(okn) .. " " .. tostring(nn))
  dd.frame:ClearAllPoints(); dd.frame:SetPoint(unpack(p))
else check("step 1 negative: a Theme list found", false) end
local okb = def.steps[2].check()
check("step 2 before Do it for me: not tested (no verdict)", okb == nil, tostring(okb))
def.steps[2].setup(); W.tick(0.1, 5)
local box = rawget(_G, "XayaUIGroupPosPopup")
check("step 2's Do it for me opens the X / Y box in the mover view", box ~= nil and box:IsShown() and ns.unlocked == true)
local okd = def.steps[2].check()
check("step 2 before the drag: not tested (no verdict)", okd == nil, tostring(okd))
local l, t = box:GetLeft(), box:GetTop()
box:ClearAllPoints(); box:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l + 120, t - 40); W.tick(0.1, 2)
local ok2, n2 = def.steps[2].check()
check("step 2 after the box is moved: Pass, both positions in the note", ok2 == true and has(n2, "The box moved from"), n2)
local ok3, n3 = def.steps[3].check()
check("step 3 (labels): Pass, every label fits", ok3 == true and has(n3, "Every label fits"), n3)
local narrow
for _, k in ipairs({ box:GetChildren() }) do if k:GetObjectType() == "Button" and k:GetText() == "Anchor to the screen (stays in place)" then narrow = k end end
local w0 = narrow and narrow:GetWidth()
if narrow then narrow:SetWidth(100) end
local ok3n, n3n = def.steps[3].check()
check("step 3 negative: a button narrower than its label gives Fail and names it", ok3n == false and has(n3n, "Anchor to the screen"), tostring(ok3n) .. " " .. tostring(n3n))
if narrow then narrow:SetWidth(w0) end
local ok4, n4 = def.steps[4].check()
check("step 4 (picker): Pass, no group anchored to the box", ok4 == true and has(n4, "No group is anchored to it"), n4)
local fo = ns.folders[1]
local saved = { fo.cRel, fo.cFrame }
fo.cRel, fo.cFrame = "custom", "XayaUIGroupPosPopup"
local ok4n, n4n = def.steps[4].check()
check("step 4 negative: a group anchored to the box is listed and gives Fail", ok4n == false and has(n4n, "Anchored to it: " .. tostring(fo.name)), tostring(ok4n) .. " " .. tostring(n4n))
fo.cRel, fo.cFrame = saved[1], saved[2]
local okA0 = def.steps[5].check()
check("step 5 before Do it for me: not tested (no verdict)", okA0 == nil, tostring(okA0))
box.x:SetFocus(); def.steps[5].setup()
check("step 5's Do it for me takes the keyboard from the number boxes", not box.x:HasFocus())
local okA1 = def.steps[5].check()
check("step 5 before any arrow key: not tested (no verdict)", okA1 == nil, tostring(okA1))
local keys = ns.MoverKeyFrame()
keys:GetScript("OnKeyDown")(keys, "RIGHT"); keys:GetScript("OnKeyDown")(keys, "UP")
local ok5, n5 = def.steps[5].check()
check("step 5 after two arrow keys: Pass, moved X +1, Y +1 and the box shows it", ok5 == true and has(n5, "X +1, Y +1"), n5)
def.steps[#def.steps].setup(); W.tick(0.1, 3)
check("Done: the box is closed and the mover view is closed again", not box:IsShown() and not ns.unlocked)
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
