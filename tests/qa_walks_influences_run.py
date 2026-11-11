#!/usr/bin/env python3
"""In-game QA walkthrough for the Stat Weights pane's Influences column and its alignment (XayaUI_DevAssist/QAWalks-influences.lua;
XayaUI Bonus Features StatCalculator.lua; REQUEST-LOG A24 #7). Xaya's answer, her words (2026-11-11): "2 but make sure all headings (top
row) are vertically middle-aligned or bottom-aligned and all rows beneath are uniformly vertically aligned amongst themselves"; option
2: "Influences is always its own column, and titles wrap onto two lines when needed". Her rule V22 (2026-11-07): "make sure every
feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation
options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game, then the walkthrough file (it is also in the .toc; loading it again registers the same id again),
with stand-in stat readings (TEST STAND-INS), and runs each step as a player would:
  - registered with pre-fill; the last step is a Done step; step 3 asks the person (noVerdict);
  - before Do it for me: step 1 says "not tested" (nil), never Pass;
  - step 1 (default panel): Pass, six titles with Influences last, every row's influences in that column;
  - step 2 at the narrowest panel (340) and text 16 (what the person sets by hand): still six columns, and the verdict follows what
    the game says is cut short (FontString:IsTruncated, stood in here by a word wider than its font string in this world's 6 px per
    character): Pass only when nothing is cut;
  - negatives: a title moved off the shared bottom line gives Fail; an influences cell moved under its row gives Fail; a cell the game
    reports cut short gives Fail (round 2: before, step 2 gave Pass on a layout with cut text); a game that does not answer
    IsTruncated gives no verdict, never Pass;
  - Done: the panel is put back (closed).
Negative control: on af1f2ba the walkthrough does not exist (the registration check fails); its checks fail on af1f2ba's
StatCalculator.lua at panel 340 (five titles, influences under the row). Round 2: the step 2 and IsTruncated checks fail on the round-1
walkthrough (it gave Pass on a layout with cut text, and Pass when the game did not answer).
Integration: the older walkthrough "statcalc-fixes" (QAWalks-statcalc-fixes.lua) Stat Weights step no longer says every title stays
on one line, and the removed five-title fallback is a Fail there (it gave no verdict); both checks fail with that file as it was at 45d0397.
A24 #9 (Xaya 2026-11-11, "Widen the panel"): step 2 at panel 340 and text 16 gives Pass (the panel widened, nothing in the pane cut)
and its note gives the drawn width; this check fails on 64d0943 (the pane was cut there, and the note had no drawn width).
A24 #9 round 2: step 4 (a corner click without a drag, then the Gear tab: the saved width is kept and the tabs sit in whole pixels)
gives Pass; it fails on 64d0943 and on the round-1 tree (no such step; the click saved the widened width there).
Run: python3 tests/qa_walks_influences_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, walkPath)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
local QA = rawget(_G, "XayaUI_DevQA")
if QA then local f = loadfile(walkPath); if f then f("XayaUI_DevAssist", {}) end end
local ns = rawget(_G, "XayaUI_NS")
local def = QA and QA.walks["statcalc-influences"]
check("the Influences walkthrough is registered with pre-fill", def ~= nil and def.prefill == true)
if not def then return R end
check("its last step is a Done step; step 3 asks the person (no verdict)", def.steps[#def.steps].done == true and def.steps[3].noVerdict == true)
ns.Print = function() end
RAT = { [9] = 500, [10] = 500, [11] = 500, [18] = 600, [19] = 600, [20] = 600, [26] = 400, [29] = 300 }
GetCombatRating = function(i) return RAT[i] or 0 end
GetCombatRatingBonus = function(i) return (RAT[i] or 0) / 40 end
GetCombatRatingBonusForCombatRatingValue = function(i, v) return v / 40 end
GetCritChance = function() return 17.5 end
GetHaste = function() return 15 end
local sc = ns.Service("statCalc")
local c = sc.Cfg()
c.enabled, c.panel = true, true
if ns.StatCalc_Apply then ns.StatCalc_Apply() end
local ok0 = def.steps[1].check()
check("step 1 before Do it for me: not tested (no verdict)", ok0 == nil, tostring(ok0))
def.steps[1].setup(); W.tick(0.1, 3)
local ok1, n1 = def.steps[1].check()
check("step 1 (default panel): Pass, six titles, Influences last, every row's influences in that column", ok1 == true, n1)
-- (integration) the older walkthrough "statcalc-fixes" has a Stat Weights step too: it must tell the tester what the player now sees
-- (six titles always, a title may wrap) and must no longer excuse the removed five-title fallback with no verdict
local fx = QA.walks["statcalc-fixes"]
local fs
for _, s in ipairs(fx and fx.steps or {}) do if tostring(s.text):find("Stat Weights", 1, true) and s.check then fs = fs or s end end
local ft = fs and tostring(fs.text) or ""
check("statcalc-fixes' Stat Weights step: its text no longer says every title stays on one line or offers the five-title fallback (SC-102)",
  fs ~= nil and not ft:find("stays on one line", 1, true) and not ft:find("SC-102", 1, true) and not ft:find("five titles", 1, true)
  and ft:find("wraps onto a second line", 1, true) ~= nil, ft:sub(1, 300))
local okF0 = fs and fs.check()
check("statcalc-fixes' Stat Weights step at the default panel: Pass", okF0 == true, tostring(okF0))
do  -- the removed fallback drawn (five titles, every row's influences under it with "Influences:"): a Fail now, not "no verdict"
  local d0 = sc.Drawn()
  local saved = {}
  for i, r in ipairs(d0.layout) do saved[i] = { r = r, kind = r.kind, text = r.text } end
  for _, r in ipairs(d0.layout) do
    if r.kind == "wcolhead" and r.text == "Influences" then r.kind = "x-removed" end
    if r.kind == "winfl" then r.text = "Influences: " .. tostring(r.text) end
  end
  local okF, nF = fs.check()
  check("statcalc-fixes' Stat Weights step: five titles with an \"Influences:\" line under each row gives Fail (before: no verdict)", okF == false, tostring(okF) .. " " .. tostring(nF))
  for _, s in ipairs(saved) do s.r.kind, s.r.text = s.kind, s.text end
end
-- step 2: the person drags the panel to its narrowest and sets the largest text; here set as the panel's own settings and redrawn
c.size, c.fontSize = { w = 340 }, 16
sc.Close(); sc.Open("stats"); W.tick(0.1, 3)
local d = sc.Drawn()
-- the game's answer to "is this text cut short", stood in: a word wider than the font string's width in this world's measure
local function wordCut(f)
  local w = f.GetWidth and f:GetWidth() or 0
  for word in tostring(f:GetText() or ""):gmatch("%S+") do if #word * 6 > w + 0.01 then return true end end
  return false
end
-- (A24 #9) the Stat Weights pane's own font strings (titles and cells): the ones the step judges
local PANE = { wcolhead = true, wlabel = true, wrating = true, wppp = true, wpppdr = true, wdr = true, wtl = true, winfl = true }
local function inPane(f)
  for _, r in ipairs(d.layout) do if PANE[r.kind] and r.text == f:GetText() then return true end end
  return false
end
local anyCut = false
for _, f in ipairs(d.fonts) do
  f.IsTruncated = function(self) return wordCut(self) end
  if f:IsShown() and inPane(f) and wordCut(f) then anyCut = true end
end
local ok2, n2 = def.steps[2].check()
check("step 2 (panel 340, text 16): six columns with Influences last; Pass only when the game reports nothing in the pane cut short ("
  .. (anyCut and "cut here: Fail" or "nothing cut here: Pass") .. ")", n2:find("6 column titles", 1, true) ~= nil and ok2 == (not anyCut), n2)
-- (A24 #9, Xaya 2026-11-11: "Widen the panel") at the narrowest panel and the largest text the panel widens, so nothing in the pane is
-- cut and the step gives Pass; its note gives the width the panel was drawn at (wider than the 340 the corner left)
check("step 2 (A24 #9): the panel widened past 340, nothing in the pane is cut short, Pass, and the note gives the drawn width",
  not anyCut and ok2 == true and type(d.width) == "number" and d.width > 340 and n2:find(("drawn %d wide"):format(d.width or 0), 1, true) ~= nil, tostring(d.width) .. " " .. n2)
-- negatives: what the player would see wrong
local cutF
for _, f in ipairs(d.fonts) do if f:IsShown() and f:GetText() ~= "" then for _, r in ipairs(d.layout) do if r.kind == "winfl" and r.text == f:GetText() then cutF = cutF or f end end end end
if cutF then cutF.IsTruncated = function() return true end end
local okC, nC = def.steps[2].check()
check("negative: an influences cell the game reports cut short gives Fail, naming it", cutF ~= nil and okC == false and nC:find("cut short", 1, true) ~= nil, nC)
if cutF then cutF.IsTruncated = function(self) return wordCut(self) end end
local saveT = {}
for i, f in ipairs(d.fonts) do saveT[i] = f.IsTruncated; f.IsTruncated = function() error("no answer") end end
local okU, nU = def.steps[2].check()
check("a game that does not answer IsTruncated: no verdict (never Pass)", okU == nil, tostring(okU) .. " " .. tostring(nU))
for i, f in ipairs(d.fonts) do f.IsTruncated = saveT[i] end
local head
for _, r in ipairs(d.layout) do if r.kind == "wcolhead" and r.text == "Stat" then head = r end end
local y0 = head and head.y
if head then head.y = head.y - 7 end
local okN1, nN1 = def.steps[2].check()
check("negative: a title off the shared bottom line gives Fail", okN1 == false, nN1)
if head then head.y = y0 end
local cell
for _, r in ipairs(d.layout) do if r.kind == "winfl" then cell = cell or r end end
local cy = cell and cell.y
if cell then cell.y = cell.y + 20 end
local okN2, nN2 = def.steps[2].check()
check("negative: an influences cell moved under its row gives Fail", okN2 == false, nN2)
if cell then cell.y = cy end
-- (A24 #9 round 2) step 4: the person clicks the corner once without dragging, then the Gear tab. The saved width stays the 340 the
-- corner left in step 2, the Gear tab is drawn at it, the tab row in whole pixels: Pass. (On the round-1 tree the click saved the
-- widened width, and the walkthrough had no such step.)
local P = rawget(_G, "XayaUIStatCalculator")
local wideW = d.width
local down, up = P and P.grip and P.grip:GetScript("OnMouseDown"), P and P.grip and P.grip:GetScript("OnMouseUp")
if down and up then down(P.grip); up(P.grip) end
local gearTab
for _, b in ipairs(P and P.tabs or {}) do if b.key == "gear" then gearTab = b end end
if gearTab then gearTab:GetScript("OnClick")(gearTab) end
W.tick(0.1, 3)
local s4 = def.steps[4]
local ok4, n4
if s4 and s4.check then ok4, n4 = s4.check() end
local win = sc.Window and sc.Window()
check("step 4 (A24 #9): after a corner click without a drag on the widened panel (" .. tostring(wideW) .. "), on the Gear tab: saved width 340, drawn 340, tabs whole: Pass",
  type(wideW) == "number" and wideW > 340 and ok4 == true and c.size and c.size.w == 340 and win and win.width == 340, tostring(ok4) .. " " .. tostring(n4) .. " saved " .. tostring(c.size and c.size.w))
-- negative: had the click saved the widened width (the round-1 behavior), step 4 gives Fail, naming it
c.size = { w = wideW }; ns.StatCalc_Render()
local okN4, nN4
if s4 and s4.check then okN4, nN4 = s4.check() end
check("negative: the widened width saved by the click gives Fail at step 4 (\"the saved width changed\")", okN4 == false and tostring(nN4):find("saved width changed", 1, true) ~= nil, tostring(okN4) .. " " .. tostring(nN4))
c.size, c.fontSize = nil, 11
def.steps[#def.steps].setup(); W.tick(0.1, 3)
check("Done: the panel is put back (closed)", not sc.Shown(), tostring(sc.Shown()))
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
    walk = os.path.join(H.ROOT, "XayaUI_DevAssist", "QAWalks-influences.lua")
    res = L.eval("function(src, W, Ld, p) return loadstring(src)()(W, Ld, p) end")(LUA, world, loader, walk)
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
