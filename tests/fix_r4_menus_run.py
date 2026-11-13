#!/usr/bin/env python3
"""V26 combat lock for the context menus XayaUI opens (round 4; round-3 review blocker "lock-rules" item 4; docs/process/VERIFICATION.md
V26, her words: rule configuration "must all be handled through the options and editing interfaces which are not allowed to open in
combat"). The game's menu can stay on screen after its window or the mover view has closed, and into a fight.
Menus: the settings window's sidebar (Editor/Sidebar.lua: a row's right-click menu, the blank-space menu, the selection bar's Move
menu) and a display's right-click menu in the mover view (Visual.lua ns.ShowVisualMenu; its entries are also core's element menu rows,
ns.VisualMenuParts).
What is checked, as the player gets it:
  S. a sidebar menu opened before the fight, a choice made in the fight (Disable, Move To, Duplicate, Delete, Rename, New Rule,
     New Group, New Dynamic Group, Move Selected To): nothing changes, no popup opens, one plain line each says why;
     the same choice made after the window closed (out of combat): nothing changes, nothing is printed;
     (control) with the window open out of combat the choice works.
  V. the display menu opened in the mover view, a choice made in the fight (Center Horizontally / Vertically, a Snap Target, Linked
     Auras): the display's saved position, snap and link do not change, one line each; after the mover view closed (out of combat):
     nothing changes; (control) in the mover view out of combat the choice works; core's element menu rows refuse the same way.
     (Bundle 1 round 7, SD-58: the mover and its display menu are XayaUI Options' and live only while the settings window is open; "closed"
     is the window closing, which closes the mover.)
  O. the menus open on XayaUI's own owner frame, which takes no mouse, is hidden when combat starts (PLAYER_REGEN_DISABLED, an event
     it listens to only while shown) and when its window / mover view closes. (UNVERIFIED IN GAME: whether the game's menu closes with
     its owner; the S / V checks hold either way.)
The game's menu is modeled by a recorder: MenuUtil.CreateContextMenu runs the menu's builder on a description that keeps each choice
by its label path ("Move To > Group One"); a choice is then made by calling it, as the game does when she clicks the entry.
Checks marked "(control)" pass on the old code too; every other check fails on the files before this change.
Run: python3 tests/fix_r4_menus_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
-- as in the game, UnitAffectingCombat("player") is already true when PLAYER_REGEN_DISABLED fires (INFERENCE; tests/fix_r3_lock_rules_run.py)
local regen = false
UnitAffectingCombat = function(u) return (W.combat or regen) and true or false end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("(control) XayaUI, its rules and the settings window loaded", ns ~= nil and ns.BuildOptionsTable ~= nil and ns.ShowVisualMenu ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
local lines = {}
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; lines[#lines + 1] = table.concat(t, " ") end
local function mark() return #lines end
local function since(m) local t = {}; for i = m + 1, #lines do t[#t + 1] = lines[i] end; return t end
local function joined(list) return table.concat(list, " / ") end
local function oneCombatLine(list) return #list == 1 and list[1]:lower():find("during combat", 1, true) ~= nil end
local function fight() regen = true; W.enterCombat(); regen = false; W.tick(0.05, 2) end
local function peace() W.leaveCombat(); W.tick(0.1, 6) end
-- the game's popups, modeled: which one is up
local popups = {}
StaticPopup_Show = function(which, text, _, data) popups[which] = { text = text, data = data }; return CreateFrame("Frame") end
StaticPopup_Hide = function(which) popups[which] = nil end
StaticPopup_Visible = function(which) return popups[which] and true or nil end
local function anyPopup() for k in pairs(popups) do return k end end
-- the game's menu, modeled: every choice kept by its label path
local OWNER
local function rec(store, path)
  local d = {}
  function d:CreateButton(text, fn) local p = path .. tostring(text); if fn then store[p] = fn end; return rec(store, p .. " > ") end
  function d:CreateRadio(text, sel, fn) local p = path .. tostring(text); store[p] = fn; return rec(store, p .. " > ") end
  function d:CreateCheckbox(text, sel, fn) local p = path .. tostring(text); store[p] = fn; return rec(store, p .. " > ") end
  function d:CreateTitle() return rec(store, path) end
  function d:CreateDivider() end
  function d:SetScrollMode() end
  function d:AddMenuAcquiredCallback() end
  return d
end
local current
MenuUtil.CreateContextMenu = function(owner, gen) OWNER = owner; current = {}; gen(owner, rec(current, "")) end
local function openMenu(fn) current = nil; fn(); return current or {} end
local function find(menu, pat) for k, v in pairs(menu) do if k:find(pat, 1, true) then return v, k end end end
local function keys(menu) local t = {}; for k in pairs(menu) do t[#t + 1] = k end; table.sort(t); return table.concat(t, " | ") end
local ACD, APP = LibStub("AceConfigDialog-3.0"), "CueRules"
local function windowOpen() return ACD.OpenFrames[APP] ~= nil and ACD.OpenFrames[APP].frame:IsShown() end

-- rules: R1, R2 (top level), DV (a display at 100, 50), DO (another display); one group
ns.folders = { { id = "f1", name = "Group One" } }
CueRulesDB.folders = ns.folders
local function mk(name, x, y)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.useBuff = true; r.buffID = 4000 + #ns.rules; r.buffState = "present"
  ns.NormalizeRule(r); r.visual.enabled = true; r.visual.trigger = "condition"; r.visual.x, r.visual.y = x, y
  ns.rules[#ns.rules + 1] = r
  return r
end
ns.rules = {}
local R1, R2 = mk("Rule One", -200, 0), mk("Rule Two", -200, -60)
local DV, DO = mk("Display rule", 100, 50), mk("Other display", 200, 50)
CueRulesDB.rules = ns.rules
if ns.MarkDirty then ns.MarkDirty() end
W.tick(0.1, 4)

-------------------------------------------------------------------------------------------------------------------------------------
-- S. the settings window's sidebar menus
-------------------------------------------------------------------------------------------------------------------------------------
local rows = {}
local function findRows()
  rows = {}
  local function walk(f, d)
    if not f or d > 60 then return end
    local uv = f.uniquevalue and tostring(f.uniquevalue):match("([^\001]+)$")
    local n = uv and tonumber(uv:match("^rule(%d+)$"))
    if n and f:IsShown() and ns.rules[n] then rows[ns.rules[n]] = rows[ns.rules[n]] or f end
    for _, c in ipairs(f.GetChildren and { f:GetChildren() } or {}) do walk(c, d + 1) end
  end
  walk(UIParent, 0)
end
section("S", function()
  pcall(ns.ToggleUI); W.tick(0.05, 6)
  pcall(ACD.SelectGroup, ACD, APP, "cooldowns", "enabledTab"); W.tick(0.05, 6)
  findRows()
  check("(control) the settings window is open with the two rules' rows", windowOpen() and rows[R1] ~= nil and rows[R2] ~= nil)
  if not (rows[R1] and rows[R2]) then return end
  -- (control) a choice made with the window open, out of combat, works
  local m0 = openMenu(function() rows[R2]:Click("RightButton") end)
  local dis0 = find(m0, "Disable")
  if dis0 then dis0() end
  check("(control) out of combat with the window open, Disable from the row menu works", dis0 ~= nil and R2.enabled == false, keys(m0))
  R2.enabled = true
  -- the three menus, opened before the fight
  local rowMenu = openMenu(function() rows[R1]:Click("RightButton") end)
  check("(control) the row menu has Disable, Move To > Group One, Duplicate, Delete, Rename",
    find(rowMenu, "Disable") and rowMenu["Move To > Group One"] and rowMenu["Duplicate"] and rowMenu["Delete"] and rowMenu["Rename"], keys(rowMenu))
  local rowOwner = OWNER
  check("O1 the sidebar's menu opens on XayaUI's owner frame, shown, taking no mouse, listening for combat start",
    ns.ContextMenuOwnerShown and ns.ContextMenuOwnerShown() and rowOwner and rowOwner:IsShown() and not rowOwner:IsMouseEnabled()
    and rowOwner:IsEventRegistered("PLAYER_REGEN_DISABLED"))
  local blank = openMenu(function() ns.ShowBlankMenu(rows[R1]) end)
  check("(control) the blank-space menu has New Rule, New Group, New Dynamic Group", blank["New Rule"] and blank["New Group"] and blank["New Dynamic Group"], keys(blank))
  IsControlKeyDown = function() return true end
  ns.MultiClick(rows[R1], "LeftButton"); ns.MultiClick(rows[R2], "LeftButton")
  IsControlKeyDown = function() return false end
  local multi = openMenu(function() ns.MultiMoveMenu(rows[R1]) end)
  check("(control) two rules selected; Move Selected To has Group One", ns.MultiCount() == 2 and multi["Group One"] ~= nil, keys(multi))
  local nRules, nFolders = #ns.rules, #ns.folders
  fight()
  check("(control) combat starts: the settings window closes", not windowOpen())
  check("O2 combat starts: the menu's owner frame is hidden and no longer listens for the event", not rowOwner:IsShown()
    and not rowOwner:IsEventRegistered("PLAYER_REGEN_DISABLED"))
  local function inFight(label, fn, still)
    local m = mark()
    local ok, err = pcall(fn)
    local got = since(m)
    check("S " .. label .. " picked in combat: nothing changes, no popup opens, one plain line says why",
      ok and still() and anyPopup() == nil and oneCombatLine(got), tostring(err) .. " / " .. joined(got) .. " / popup " .. tostring((anyPopup())))
    for k in pairs(popups) do popups[k] = nil end
  end
  inFight("row menu > Disable", find(rowMenu, "Disable"), function() return R1.enabled == true end)
  inFight("row menu > Move To > Group One", rowMenu["Move To > Group One"], function() return R1.folder == nil end)
  inFight("row menu > Duplicate", rowMenu["Duplicate"], function() return #ns.rules == nRules end)
  inFight("row menu > Delete", rowMenu["Delete"], function() return #ns.rules == nRules and ns.rules[1] == R1 end)
  inFight("row menu > Rename", rowMenu["Rename"], function() return R1.name == "Rule One" end)
  inFight("blank menu > New Rule", blank["New Rule"], function() return #ns.rules == nRules end)
  inFight("blank menu > New Group", blank["New Group"], function() return #ns.folders == nFolders end)
  inFight("blank menu > New Dynamic Group", blank["New Dynamic Group"], function() return #ns.folders == nFolders end)
  inFight("Move Selected To > Group One", multi["Group One"], function() return R1.folder == nil and R2.folder == nil end)
  peace()
  check("(control) combat ends: the settings window opens again", windowOpen())
  -- the window closed (out of combat): a menu left on screen changes nothing, quietly
  findRows()
  local late = openMenu(function() rows[R1]:Click("RightButton") end)
  local lateOwner = OWNER
  ACD:Close(APP); W.tick(0.05, 4)
  check("(control) the settings window is closed", not windowOpen())
  check("O3 the window closes: the menu's owner frame is hidden", lateOwner ~= nil and not lateOwner:IsShown())
  local m = mark()
  local dis = find(late, "Disable")
  if dis then dis() end
  local mv = late["Move To > Group One"]
  if mv then mv() end
  check("S row menu > Disable / Move To picked after the window closed: nothing changes, nothing is printed",
    dis ~= nil and R1.enabled == true and R1.folder == nil and #since(m) == 0, joined(since(m)))
  if ns.MultiReset then ns.MultiReset() end
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- V. a display's menu in the mover view
-------------------------------------------------------------------------------------------------------------------------------------
section("V", function()
  if windowOpen() then ACD:Close(APP); W.tick(0.05, 4) end
  ns.ToggleUnlock(); W.tick(0.05, 3)
  local fr = ns.DisplayFrame(DV)
  check("(control) /xui unlock: the mover view is open with the display shown", ns.unlocked == true and fr ~= nil and fr:IsShown())
  if not fr then return end
  -- (bundle 1 round 7, SD-58 / SD-64) the mover works only with the settings window open, and while the window is shown a right-click on
  -- a display opens the element menu (XayaUI_Options/ElementMenu.lua, the same entries: tests/element_menu_run.py E). The display's own
  -- menu is opened here the way its right-click did before (ns.ShowVisualMenu, the game's context menu), to check its choices.
  local function rightClick() return openMenu(function() ns.ShowVisualMenu(DV, fr) end) end
  -- (control) a choice in the mover view out of combat works
  if not rawget(_G, "PlayerFrame") then   -- (the game's player frame, modeled: a snap target that exists)
    local pf = CreateFrame("Frame", "PlayerFrame", UIParent); pf:SetSize(200, 80); pf:SetPoint("CENTER", UIParent, "CENTER", -300, -200)
  end
  local SNAP = "Snap Target > Player Frame > Top Center"
  local m0 = rightClick()
  local snap0, snapKey = m0[SNAP], SNAP
  if snap0 then snap0() end
  check("(control) in the mover view out of combat, a Snap Target choice works", snap0 ~= nil and DV.visual.snap ~= nil and DV.visual.snap.target ~= nil,
    tostring(snapKey) .. " / " .. keys(m0))
  local sn = rawget(m0, "Snap Target > None (free position)")
  if sn then sn() end
  DV.visual.snap = nil
  DV.visual.x, DV.visual.y = 100, 50; ns.RefreshVisual(DV)
  local menu = rightClick()
  local owner = OWNER
  check("O4 the display's menu opens on XayaUI's owner frame (not the display), taking no mouse, listening for combat start",
    owner ~= fr and owner ~= nil and owner:IsShown() and not owner:IsMouseEnabled() and owner:IsEventRegistered("PLAYER_REGEN_DISABLED"))
  local snapFn = menu[SNAP]
  local linkFn = menu["Linked Auras (move together) > Other display"]
  check("(control) the display menu has Center Horizontally / Vertically, a Snap Target and Linked Auras > Other display",
    menu["Center Horizontally"] and menu["Center Vertically"] and snapFn and linkFn, keys(menu))
  fight()
  check("(control) combat starts: the mover view closes", ns.unlocked == false)
  check("O5 combat starts: the display menu's owner frame is hidden", not owner:IsShown() and not owner:IsEventRegistered("PLAYER_REGEN_DISABLED"))
  local function inFight(label, fn, still)
    local m = mark()
    local ok, err = pcall(fn or function() error("no such entry") end)
    local got = since(m)
    check("V " .. label .. " picked in combat: the display does not change, one plain line says why", ok and still() and oneCombatLine(got),
      tostring(err) .. " / " .. joined(got) .. (" / x %s y %s snap %s link %s"):format(tostring(DV.visual.x), tostring(DV.visual.y), tostring(DV.visual.snap and DV.visual.snap.target), tostring(DV.link)))
  end
  inFight("Center Horizontally", menu["Center Horizontally"], function() return DV.visual.x == 100 and DV.visual.y == 50 end)
  inFight("Center Vertically", menu["Center Vertically"], function() return DV.visual.x == 100 and DV.visual.y == 50 end)
  inFight("Snap Target > Player Frame > Top Center", snapFn, function() return DV.visual.snap == nil or DV.visual.snap.target == nil end)
  inFight("Linked Auras > Other display", linkFn, function() return DV.link == nil and DO.link == nil end)
  -- core's element menu builds its rows from the same parts
  local parts = ns.VisualMenuParts(DV)
  local cv
  for _, p in ipairs(parts) do if p.text == "Center Vertically" then cv = p.func end end
  inFight("core's element menu row Center Vertically", cv, function() return DV.visual.y == 50 end)
  peace()
  check("(control) combat ends: the mover view opens again", ns.unlocked == true)
  -- the mover view closed (out of combat): a menu left on screen changes nothing, quietly. (bundle 1 round 7, SD-58) The display menu
  -- belongs to the settings window, which the mover needs: closing the window closes the mover and ends the menu (as the window's
  -- element menu always did; before round 7 a mover opened with the window closed ended it by itself)
  local late = rightClick()
  local lateOwner = OWNER
  ns.MoverExit("cancel"); W.tick(0.05, 3)
  if windowOpen() then ACD:Close(APP); W.tick(0.05, 4) end
  check("(control) the mover view and the settings window are closed", ns.unlocked == false and not windowOpen())
  check("O6 the mover view and the window close: the display menu's owner frame is hidden", lateOwner ~= nil and lateOwner ~= fr and not lateOwner:IsShown())
  local m = mark()
  if late["Center Horizontally"] then late["Center Horizontally"]() end
  if late["Center Vertically"] then late["Center Vertically"]() end
  check("V Center Horizontally / Vertically picked after the mover view and the window closed: the display does not move, nothing is printed",
    late["Center Horizontally"] ~= nil and DV.visual.x == 100 and DV.visual.y == 50 and #since(m) == 0, joined(since(m)) .. (" / x %s y %s"):format(tostring(DV.visual.x), tostring(DV.visual.y)))
  W.enterCombat()
  local m3 = mark()
  local opened = openMenu(function() ns.ShowVisualMenu(DV, fr) end)
  check("V the display menu asked for in combat does not open; one plain line", next(opened) == nil and #since(m3) == 1 and since(m3)[1]:find("during combat", 1, true) ~= nil,
    joined(since(m3)) .. " / " .. keys(opened))
  W.leaveCombat(); W.tick(0.05, 2)
end)
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    n = len(res)
    for i in range(1, n + 1):
        name, good = res[i][1], res[i][2]
        print(("PASS " if good else "FAIL ") + name)
        bad += 0 if good else 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
