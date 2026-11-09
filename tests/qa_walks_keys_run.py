#!/usr/bin/env python3
"""In-game QA walkthrough for "keys reach the game" (XayaUI 0.6.85 KeyCatch.lua; XayaUI_DevAssist/QAWalks-keys.lua; QA B390-B395;
REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md row 56, her words: "WHY DOES THE ADDON KEEP PREVENTING ME FROM SCREENSHOTTING").
Xaya's rule V22 (2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test
walk through with pre-fill confirmation options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game and plays each step as a player would (Do it for me, the keys or
events the step asks for, then the check):
  - registered with pre-fill for B390-B395; the last step is a Done step; nothing is listened to before the first step (V14);
  - each step: "not tested" (nil) before Do it for me and before the player did what it asks, Pass after;
  - negatives: the settings window keeping every key gives Fail (B390); Esc closing the settings window too gives Fail (B393);
    a screenshot key taken by the Calculator's line gives Fail (B394);
  - Done: the Calculator, the version pane and the mover view are closed; the walkthrough stops listening.
Run: python3 tests/qa_walks_keys_run.py"""
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
local def = QA and QA.walks["keys"]
check("the keys walkthrough is registered with pre-fill, for B390-B395", def ~= nil and def.prefill == true and def.qa == "B390, B391, B392, B393, B394, B395")
if not def then return R end
check("its last step is a Done step", def.steps[#def.steps].done == true)
check("V14: nothing is listened to before the first step", QA.KeysTest.EventFrame() == nil)
ns.Print = function() end
local function step(i) return def.steps[i] end
local function setup(i) step(i).setup(); W.tick(0.1, 5) end
local function shot() W.now = W.now + 0.01; W.fire("SCREENSHOT_SUCCEEDED") end
local function walk() W.now = W.now + 0.01; W.fire("PLAYER_STARTED_MOVING") end

-- B390
check("step 1 before Do it for me: not tested", step(1).check() == nil)
setup(1)
local ACD = LibStub("AceConfigDialog-3.0")
local root = ACD.OpenFrames and ACD.OpenFrames.CueRules
check("step 1's Do it for me opens the settings window", root ~= nil)
local a0, n0 = step(1).check()
check("step 1 before Print Screen: not tested, and the note says the window passes keys on", a0 == nil and has(n0, "keys passed on to the game: true"), tostring(a0) .. " " .. tostring(n0))
shot()
local a1 = step(1).check()
check("step 1 after one screenshot: not tested yet (Ctrl+Z, then Print Screen again)", a1 == nil, tostring(a1))
shot()
local a2, n2 = step(1).check()
check("step 1 after both screenshots: Pass, the count in the note", a2 == true and has(n2, "Screenshots taken with it open: 2"), tostring(a2) .. " " .. tostring(n2))
if root then
  root.frame._propagate = false   -- the window as it was before 0.6.85 after a key it used: it kept every key
  local an, nn = step(1).check()
  check("step 1 negative: a window that keeps every key gives Fail", an == false and has(nn, "keeps every key"), tostring(an) .. " " .. tostring(nn))
  root.frame._propagate = true
end

-- B391
check("step 2 before Do it for me: not tested", step(2).check() == nil)
setup(2)
check("step 2's Do it for me opens the mover view", ns.unlocked == true)
check("step 2 before an arrow: not tested", step(2).check() == nil)
local got = W.pressKey("RIGHT")
check("  ...the arrow key is used by the mover view", got == ns.MoverKeyFrame(), tostring(got))
check("step 2 after the arrow, before Print Screen: not tested", step(2).check() == nil)
W.tick(0.02, 1)
check("  ...and the screenshot key then reaches the game", W.pressKey("PRINTSCREEN") == "game")
shot()
local b2, m2 = step(2).check()
check("step 2 after the arrow and a screenshot: Pass", b2 == true and has(m2, "X +1, Y +0") and has(m2, "in the mover view: 1"), tostring(b2) .. " " .. tostring(m2))

-- B392
setup(3)
check("step 3 before the fight: not tested", step(3).check() == nil)
W.enterCombat()
check("  ...in combat the screenshot key and W reach the game", W.pressKey("PRINTSCREEN") == "game" and W.pressKey("W") == "game")
shot(); walk()
W.leaveCombat()
local c3, k3 = step(3).check()
check("step 3 after a screenshot and walking in combat: Pass", c3 == true and has(k3, "1 screenshot(s), 1 time(s)"), tostring(c3) .. " " .. tostring(k3))

-- B393
if ns.unlocked and ns.MoverExit then ns.MoverExit("cancel"); W.tick(0.05, 2) end
check("step 4 before Do it for me: not tested", step(4).check() == nil)
setup(4)
local pane = ns.InfoPane and ns.InfoPane.Frame()
check("step 4's Do it for me opens the version pane", pane and pane:IsShown())
check("step 4 before Esc: not tested", step(4).check() == nil)
W.pressKey("ESCAPE")
local d4, e4 = step(4).check()
check("step 4 after Esc: Pass, the pane closed and the settings window stayed", d4 == true, tostring(d4) .. " " .. tostring(e4))
local keep = ACD.OpenFrames.CueRules
ACD.OpenFrames.CueRules = nil
local dn, en = step(4).check()
check("step 4 negative: the settings window closed too gives Fail", dn == false and has(en, "closed the settings window too"), tostring(dn) .. " " .. tostring(en))
ACD.OpenFrames.CueRules = keep

-- B394
check("step 5 before Do it for me: not tested", step(5).check() == nil)
setup(5)
local calc = rawget(_G, "XayaUICalculator")
check("step 5's Do it for me opens the Calculator with the cursor in its line", calc and calc.edit:HasFocus())
check("step 5 before the click: not tested", step(5).check() == nil)
shot()   -- (stand-in: a screenshot while the line has the cursor; with the fix the game would not get the key)
local fn, gn = step(5).check()
check("step 5 negative: a screenshot while the line kept the cursor gives Fail", fn == false and has(gn, "kept the keyboard"), tostring(fn) .. " " .. tostring(gn))
QA.KeysTest.State.t5 = W.now + 0.001
W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")   -- a click on the game world
check("  ...a click on the game world takes the cursor out of the line", not calc.edit:HasFocus())
check("step 5 after the click, before Print Screen: not tested", step(5).check() == nil)
shot()
local f5, g5 = step(5).check()
check("step 5 after the click and a screenshot: Pass", f5 == true, tostring(f5) .. " " .. tostring(g5))

-- B395
setup(6)
ns.treeFilter = ""
check("step 6 before a search: not tested", step(6).check() == nil)
ns.treeFilter = "spikes"
check("step 6 after a search, before walking: not tested", step(6).check() == nil)
walk()
local h6, i6 = step(6).check()
check("step 6 after a search and walking: Pass", h6 == true and has(i6, "'spikes'"), tostring(h6) .. " " .. tostring(i6))
ns.treeFilter = ""

-- Done
ns.ToggleUnlock(); W.tick(0.05, 2)   -- (the mover view, as step 2 left it open)
QA.KeysTest.State.unlockedByUs = true
calc:Show()
step(#def.steps).setup(); W.tick(0.1, 3)
local evf = QA.KeysTest.EventFrame()
check("Done: the Calculator and the mover view are closed, and the walkthrough stops listening",
  not calc:IsShown() and not ns.unlocked and evf and not evf:IsEventRegistered("SCREENSHOT_SUCCEEDED") and not evf:IsEventRegistered("PLAYER_STARTED_MOVING"))
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
