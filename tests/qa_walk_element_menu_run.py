#!/usr/bin/env python3
"""The in-game QA walkthrough for the element menu (XayaUI_DevAssist 0.7.61, QAWalks-element-menu.lua, QA I3; #495, REQUEST-LOG PS-59;
standing rule V22, Xaya 2026-11-07: "make sure every feature or significant change to the codebase / bug report fixes have an in game qa
test walk through with pre-fill confirmation options or data capturing").
On the real addons (every one on) in the stand-in game, with the left data panel on:
  - step 1's Do it for me opens the window and right-clicks the panel: the menu (Element options, X, Y) is read back: Pass;
  - step 2 adds 10 to X: the panel's saved X is 10 more and the box shows it: Pass;
  - step 3 presses Element options: it asked for bonus > datapanels and the menu closed: Pass;
  - step 4 puts X back, closes the window and right-clicks again: no element menu (the panel's own right-click opened its page): Pass;
  - before anything is done, step 1's check gives no verdict (window not open), and a tampered menu (X / Y hidden on a panel) is a Fail.
Negative control: on Dev Assist 0.7.60 the walkthrough does not exist (the registration check fails).
Run: python3 tests/qa_walk_element_menu_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
local QA, ns = rawget(_G, "XayaUI_DevQA"), rawget(_G, "XayaUI_NS")
local RV = QA and QA.Review
if RV and RV.Window and RV.Window() then RV.Window():Hide() end
ns.Print = function() end
check("the walkthrough is registered with pre-fill", QA.walks["element-menu"] and QA.walks["element-menu"].prefill and #QA.walks["element-menu"].steps == 4)
if not QA.walks["element-menu"] then return R end
local dp = ns.Service("dataPanelsDebug")
ns.Settings("bonus").dataPanels.general.enabled = true
local cfg = dp.Cfg("bl"); cfg.enabled = true; cfg.x, cfg.y = 30, 12
dp.Refresh("bl"); W.tick(0.1, 2)
local def = QA.walks["element-menu"]
local v0 = def.steps[1].check()
check("step 1 before anything: no verdict (the window is not open)", v0 == nil, tostring(v0))
QA.Start("element-menu")
local notes, sug = {}, {}
local function Step(i)
  if def.steps[i].setup then QA.DoSetup(); W.tick(0.2, 2) end
  QA.RunCheck()
  local s = QA.State()
  notes[i] = s.seen and s.seen[i] and s.seen[i].d or ""
  local sug = s.suggest
  if i == 1 then
    -- negative: the same menu with its X / Y hidden on a panel that has them
    local m = ns.ElementMenu(); m.x:Hide()
    local vn = def.steps[1].check()
    m.x:Show()
    check("step 1 negative: X / Y missing on an element that has them: Fail", vn == false, tostring(vn))
  end
  QA.Accept()
  return sug
end
sug[1] = Step(1)
check("step 1: the panel's menu is read back (Element options, X 30, Y 12): Pass", (sug[1] and sug[1].r) == "P"
  and notes[1]:find("X 30, Y 12", 1, true) and notes[1]:find("Element options: yes", 1, true), notes[1])
sug[2] = Step(2)
check("step 2: X + 10 saved (40) and shown: Pass", (sug[2] and sug[2].r) == "P" and cfg.x == 40, notes[2])
sug[3] = Step(3)
check("step 3: Element options asked for the Data Panels page and the menu closed: Pass", (sug[3] and sug[3].r) == "P"
  and notes[3]:find("bonus > datapanels", 1, true), notes[3])
sug[4] = Step(4)
check("step 4: X put back (30); window closed, the right-click opened no element menu: Pass", (sug[4] and sug[4].r) == "P" and cfg.x == 30, notes[4])
local res = QA.DB().results["element-menu"]
check("the run is saved with every step Pass", res and res.steps[1].r == "P" and res.steps[4].r == "P", res and tostring(res.steps[1].r))
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("ok  " if ok else "FAIL: ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
