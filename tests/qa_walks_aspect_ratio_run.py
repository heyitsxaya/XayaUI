#!/usr/bin/env python3
"""In-game QA walkthrough for "Maintain aspect ratio" (Rules Options 0.6.82; XayaUI_DevAssist/QAWalks-aspect-ratio.lua; QA B340-B343;
REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s rows 24-25). Xaya's rule V22 (2026-11-07): "make sure every feature or significant change to
the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game and runs each step as a player would (Do it for me, then she
changes the controls on the page, then the check):
  - registered with pre-fill for B340-B343; the last step is a Done step;
  - before Do it for me: step 1 says "not tested" (nil), never Pass;
  - step 1: Pass, the tick box drawn on the Group tab, unticked, the sliders at 64 / 32; negative: a box saved ticked gives Fail;
  - step 2: before ticking, "not tested"; ticked but width unchanged, "not tested"; width 96 gives Pass with 96 x 48 in the note;
    negative: a display whose height did not follow gives Fail;
  - step 3: height 24 gives Pass (48 x 24);
  - step 4: height 512 gives Pass (512 x 512, clamped), then height 32 gives Pass (64 x 32);
  - step 5: still ticked, "not tested"; unticked and a width change with the height unchanged gives Pass; negative: height changed
    gives Fail;
  - Done: the box is unticked on the QA test group.
The page's controls are changed through the options they draw (their set), as a click on the drawn widget would.
Run: python3 tests/qa_walks_aspect_ratio_run.py"""
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
local def = QA and QA.walks["aspect-ratio"]
check("the aspect ratio walkthrough is registered with pre-fill, for B340-B343", def ~= nil and def.prefill == true and def.qa == "B340, B341, B342, B343")
if not def then return R end
check("its last step is a Done step", def.steps[#def.steps].done == true)
ns.Print = function() end
local ok0 = def.steps[1].check()
check("step 1 before Do it for me: not tested (no verdict)", ok0 == nil, tostring(ok0))
def.steps[1].setup(); W.tick(0.1, 8); if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 3)
local ok1, n1 = def.steps[1].check()
check("step 1: Pass, the box drawn unticked, sliders 64 / 32", ok1 == true and has(n1, "unticked") and has(n1, "Display width 64") and has(n1, "Display height 32"), tostring(ok1) .. " " .. tostring(n1))
-- the drawn widgets' options (what a click on them runs)
local ACD = LibStub("AceConfigDialog-3.0")
local function opt(name)
  local found
  local function walk(w) if type(w) ~= "table" or found then return end; local o = w.GetUserData and w:GetUserData("option"); if o and o.name == name then found = o end; for _, c in ipairs(w.children or {}) do walk(c) end end
  walk(ACD.OpenFrames.CueRules)
  return found
end
local BOX, SW, SH = opt("Maintain aspect ratio"), opt("Display width"), opt("Display height")
check("the box and both sliders are drawn in the window", BOX ~= nil and SW ~= nil and SH ~= nil)
if not (BOX and SW and SH) then return R end
local f = QA.AspectRatioTest.State.fid and ns.FolderById(QA.AspectRatioTest.State.fid)
f.dispAspect = 3
local ok1n, n1n = def.steps[1].check()
check("step 1 negative: a box saved ticked gives Fail", ok1n == false, tostring(ok1n) .. " " .. tostring(n1n))
f.dispAspect = nil
local function redraw() if ns.OptionsApi and ns.OptionsApi.Notify then ns.OptionsApi.Notify() end; W.tick(0.1, 3) end
local ok2a = def.steps[2].check()
check("step 2 before ticking: not tested", ok2a == nil, tostring(ok2a))
BOX.set(nil, true); redraw()
local ok2b = def.steps[2].check()
check("step 2 ticked, width unchanged: not tested", ok2b == nil, tostring(ok2b))
SW.set(nil, 96); redraw()
local ok2, n2 = def.steps[2].check()
check("step 2 width 96: Pass, 96 x 48 in the note", ok2 == true and has(n2, "96 x 48, 96 x 48") and has(n2, "2.000"), tostring(ok2) .. " " .. tostring(n2))
-- negative: one display's height did not follow
local disp = {}
for _, r in ipairs(ns.rules) do if r.folder == f.id then for _, d in ipairs(ns.RuleDisplays(r)) do disp[#disp + 1] = d end end end
local st = QA.AspectRatioTest.State
local sw0, sh0 = st.w, st.h
for _, d in ipairs(disp) do d.visual.w, d.visual.h = 100, 32 end
local ok2n, n2n = def.steps[2].check()
check("step 2 negative: width 100 with height still 32 gives Fail", ok2n == false, tostring(ok2n) .. " " .. tostring(n2n))
for _, d in ipairs(disp) do d.visual.w, d.visual.h = 96, 48 end
st.w, st.h = sw0, sh0
SH.set(nil, 24); redraw()
local ok3, n3 = def.steps[3].check()
check("step 3 height 24: Pass, 48 x 24", ok3 == true and has(n3, "48 x 24, 48 x 24"), tostring(ok3) .. " " .. tostring(n3))
SH.set(nil, 512); redraw()
local ok4, n4 = def.steps[4].check()
check("step 4 height 512: Pass, width stops at 512", ok4 == true and has(n4, "512 x 512, 512 x 512"), tostring(ok4) .. " " .. tostring(n4))
SH.set(nil, 32); redraw()
local ok4b, n4b = def.steps[4].check()
check("step 4 height back to 32: Pass, width 64 again", ok4b == true and has(n4b, "64 x 32, 64 x 32"), tostring(ok4b) .. " " .. tostring(n4b))
local ok5a = def.steps[5].check()
check("step 5 still ticked: not tested", ok5a == nil, tostring(ok5a))
BOX.set(nil, false); redraw()
SW.set(nil, 80); redraw()
local ok5, n5 = def.steps[5].check()
check("step 5 unticked, width 80: Pass, height unchanged", ok5 == true and has(n5, "80 x 32") and has(n5, "unchanged"), tostring(ok5) .. " " .. tostring(n5))
SW.set(nil, 90); for _, d in ipairs(disp) do d.visual.h = 45 end
local ok5n, n5n = def.steps[5].check()
check("step 5 negative: the height changed too gives Fail", ok5n == false and has(n5n, "CHANGED"), tostring(ok5n) .. " " .. tostring(n5n))
f.dispAspect = 2
def.steps[#def.steps].setup()
check("Done: the box is unticked on the QA test group", f.dispAspect == nil and BOX.get() == false)
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
