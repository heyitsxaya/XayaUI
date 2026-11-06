#!/usr/bin/env python3
"""The settings sidebar keeps every row it has room for (Options 0.6.52). Reports, 2026-11-06:
  Insivius (relayed by Xaya): "Scroll panel broke when I tried to select "Cursor Highlight". It will not show more than 4 lines at a time
  and forces a scroll to navigate the menu"
  Xaya: "clicking options in the right hand side panel still consistently drops elements nested within it across all tabs. do a full
  review on what causes this bug to occur, because it's a problem with the pane iteself"
Cause (Skin.lua, the sidebar's RefreshTree wrapper): the pass that fits the number of drawn rows to their real heights has a "grow"
loop guarded by `local _, mx = self.scrollbar and self.scrollbar:GetMinMaxValues()`. In Lua an `and` expression keeps only the first
value of a call, so mx was always nil and the grow loop never ran: the remembered count (xuiLines) could only shrink. Any refresh that
measured little room (the window or tree briefly short during a redraw, a row taller than AceGUI's 18 px, a tree widget reused from
another, shorter tree) lowered it for good. The same count also survived on AceGUI's recycled TreeGroup widgets.
Loads the real addons in the stand-in game, opens the settings window on QoL > Cursor > Gradient Cursor Trail and checks what the
player sees: every sidebar row is drawn after (1) opening, (2) a change made in the right-hand pane (the redraw a click there causes),
(3) the window made short and then tall again, (4) a reused tree widget that last served a short tree.
Stand-in: rows get AceGUI's own 18 px height (TreeGroup counts lines as (height - 20) / 18); the stand-in fires no OnSizeChanged, so
after each redraw the test runs the tree frame's own handler, as the game does when the frame gets its height. Unlike
sidebar_switches_run.py it does NOT clear the remembered count first: that clearing is what hid this defect.
Run: python3 tests/sidebar_rows_regrow_run.py   (slow: each redraw of the stand-in window takes many seconds here)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()
do   -- AceGUI's tree rows are 18 px high (AceGUIContainer-TreeGroup.lua counts lines as (height - 20) / 18)
  local init = W.templateInit.OptionsListButtonTemplate
  W.templateInit.OptionsListButtonTemplate = function(f) init(f); f._h = 18 end
end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
CueRulesDB.characterToolkit = CueRulesDB.characterToolkit or {}; CueRulesDB.characterToolkit.enabled = true   -- its parts show as rows
local reg, ACD = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
local function root() return ACD.OpenFrames and ACD.OpenFrames["CueRules"] end
local function findW(w, pred)
  if not w then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local f = findW(c, pred); if f then return f end end
end
local function tree(tab) return findW(root(), function(w) local u = w.type == "TreeGroup" and w:GetUserDataTable(); return u and u.path and u.path[1] == tab and #u.path == 1 end) end
local function sizeChanged()   -- what the game does when the tree frame gets its height: AceGUI's own OnSizeChanged (RefreshTree)
  local t = tree("qol"); local f = t and t.treeframe and t.treeframe:GetScript("OnSizeChanged")
  if f then f(t.treeframe) end
end
local function settle() W.tick(0.05, 6); sizeChanged() end
-- what the player sees in the QoL sidebar: rows drawn, rows the tree has, and whether those drawn fit inside the tree frame
local function seen()
  local t = tree("qol")
  if not t then return 0, 0, false, "no QoL tree" end
  local shown, h = 0, 0
  for _, b in ipairs(t.buttons or {}) do if b:IsShown() then shown = shown + 1; h = h + (b:GetHeight() or 0) end end
  local tfh = t.treeframe and t.treeframe:GetHeight() or 0
  return shown, #(t.lines or {}), h <= tfh, ("%d of %d rows drawn, %.0f px of rows in a %.0f px sidebar, remembered count %s"):format(shown, #(t.lines or {}), h, tfh, tostring(t.xuiLines))
end
local function allRows(label)
  local shown, total, fits, info = seen()
  check(label .. ": every QoL sidebar row is drawn (they fit), none dropped", total > 0 and shown == total and fits, info)
end

pcall(ns.ToggleUI); settle()
ACD:SelectGroup("CueRules", "qol", "cursor", "trail"); settle()
local t0 = tree("qol")
check("the window is open on QoL > Cursor > Gradient Cursor Trail", root() ~= nil and t0 ~= nil)
if not t0 then return end
do   -- every group in the QoL sidebar open, so it has its full list of rows (Character Toolkit's parts, Cursor's parts)
  local st = t0.status or t0.localstatus
  st.groups = st.groups or {}
  for _, l in ipairs(t0.lines or {}) do if l.hasChildren then st.groups[l.uniquevalue] = true end end
  t0:RefreshTree(); settle()
end
do
  local t, uvs = tree("qol"), {}
  for _, l in ipairs(t.lines or {}) do uvs[#uvs + 1] = tostring(l.uniquevalue):gsub("\001", ">") end
  check("the QoL sidebar has every part as a row (Character Toolkit's and Cursor's)", #uvs >= 7, table.concat(uvs, ", "))
end
allRows("1 opened")

-- 2. a change made in the right-hand pane: AceConfigDialog redraws the window (the redraw a click on a tick box or dropdown there causes)
do
  local c = CueRulesDB.cursorTrail or CueRulesDB.cursor
  if type(c) == "table" then c.xuiTestTouch = (c.xuiTestTouch or 0) + 1 end
  reg:NotifyChange("CueRules"); settle()
end
allRows("2 after a change in the right-hand pane")
reg:NotifyChange("CueRules"); settle(); reg:NotifyChange("CueRules"); settle()
allRows("2 after three changes in the right-hand pane")

-- 3. the window made short (fewer rows fit: the list scrolls) and tall again
do
  local fr = root().frame
  local h = fr:GetHeight()
  fr:SetHeight(260); sizeChanged()
  local shown, total = seen()
  check("3 short window: fewer rows drawn, the rest scroll (the list follows the room)", shown > 0 and shown < total, ("%d of %d"):format(shown, total))
  fr:SetHeight(h); sizeChanged()
end
allRows("3 the window tall again")

-- 4. a tree widget reused by AceGUI keeps no count from the tree it served before
do
  local t = tree("qol")
  t.xuiLines = 2   -- what a short tree elsewhere leaves on the widget
  t:RefreshTree(); settle()
end
allRows("4 a remembered count of 2 from before")
do   -- closing the window releases its widgets to AceGUI's pool (the next tree that is built may get this one)
  local t = tree("qol")
  t.xuiLines = 3
  ACD:Close("CueRules"); W.tick(0.05, 3)
  check("4 the window closed: its released tree widget forgets its fitted row count", root() == nil and t.xuiLines == nil, tostring(t.xuiLines))
end
end)
if not okAll then check("the test ran to its end (a Lua error stopped it)", false, errAll) end
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
