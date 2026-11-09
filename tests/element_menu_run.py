#!/usr/bin/env python3
"""Element menu (core 0.6.80; #495, REQUEST-LOG PS-59). Xaya, 2026-11-08 (her words): "Also with the options panel on, right clicking an
element object should open up an at-cursor menu to allow the user to select "element options" and modify position with x,y inputs".
On the real addons in the stand-in game:
  A Window closed: no element handler is on any frame (each frame's own right-click script is in place), a right-click does what it
    did before (a data panel opens its page; an unlocked display opens its own menu, #61), and no element menu frame exists.
  B Window shown: a right-click on a data panel opens the menu at the cursor with exactly "Element options", X and Y (no title, no other
    row) and does not jump to the page; X / Y show the panel's own cfg.x / cfg.y.
  C "Element options" opens that element's page (data panel -> bonus/datapanels; Notepad -> bonus/utilities/notepad; display -> the
    rule editor on that display) and closes the menu.
  D X / Y write the same saved values the page reads: X + 10 moves cfg.x by 10, the page's X-Offset slider reads the new number, the
    panel is placed at it; a display's visual.x / y (the editor's X / Y); the Notepad's db.x / db.y.
  E A display that has its own right-click menu (#61) keeps every entry of it, in the same order, under its title; the game's context
    menu built from the same list is unchanged (parity with the entries before 0.6.80).
  F Elements with no X / Y setting (chat sidebar, Chat Data Panel) and restyled Blizzard frames show "Element options" only.
  G Combat: a right-click does the old thing (no menu); an open menu closes when combat starts.
  H Closing the window puts every frame's own script back, takes the mouse back from the sidebar strip, hides the menu; the menu's
    events are registered only while it shows.
  I Off costs nothing (V14): with a module off (XayaUI Bonus Features, XayaUI Chat, XayaUI Rules) nothing of it is registered; a data
    panel that is off registers nothing.
Fails on the code before 0.6.80 (no ns.RegisterElement: no menu).
Run: python3 tests/element_menu_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

ROOT = os.path.dirname(HERE)
# XayaUI_Chat is a QA-branch module (absent on main): the checks about its sidebar strip are skipped (printed) while it is absent
HAS_CHAT = os.path.isdir(os.path.join(ROOT, "XayaUI_Chat"))

LUA = r'''
return function(W, L, HAS_CHAT)
local R = {}
local function skipChat(name) R[#R + 1] = { name, "skip" } end
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
-- record page jumps and rule-editor opens (and still do them)
local opened, edited, visualMenus = {}, {}, 0
local rawOpen = ns.OpenSettingsPage
ns.OpenSettingsPage = function(...) opened[#opened + 1] = table.concat({ ... }, "/"); return rawOpen(...) end
local rawEdit = ns.EditRule
ns.EditRule = function(r) edited[#edited + 1] = r; return rawEdit(r) end
local rawVM = ns.ShowVisualMenu
ns.ShowVisualMenu = function(...) visualMenus = visualMenus + 1; return rawVM(...) end
-- the game's context menu, recorded (top-level entries only)
local lastMenu
MenuUtil.CreateContextMenu = function(owner, gen)
  local rec = {}
  local mt = {}
  mt.__index = function() return function() return setmetatable({}, mt) end end
  local sub = setmetatable({}, mt)
  local root = {
    CreateTitle = function(_, t) rec[#rec + 1] = "title:" .. t end,
    CreateDivider = function() rec[#rec + 1] = "-" end,
    CreateRadio = function(_, t) rec[#rec + 1] = "radio:" .. t; return sub end,
    CreateButton = function(_, t) rec[#rec + 1] = t; return sub end,
  }
  local ok, err = pcall(gen, owner, root)
  if not ok then rec[#rec + 1] = "ERR:" .. tostring(err) end
  lastMenu = rec
  return root
end

-- a rule with a display cue, unlocked for moving (it takes clicks only then, as before)
ns.rules = ns.rules or {}
local r = ns.NewRule(); r.name = "Demon Spikes"; r.enabled = true; r.useBuff, r.buffID, r.buffState = true, 1001, "present"
r.visual.enabled, r.sound.enabled = false, false
ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
local cue = ns.NewCueRule(r, "texture"); cue.visual.kind, cue.visual.tex = "file", "Interface\\Icons\\INV_Misc_QuestionMark"
cue.visual.x, cue.visual.y = 40, -20
ns.SetMoveUnlocked({ cue }, true); ns.Step(); W.tick(0.1, 3)
local dfr = ns.VisualFramesOf(cue)[1]
-- the left data panel, on
local dp = ns.Service("dataPanelsDebug")
ns.Settings("bonus").dataPanels.general.enabled = true
local cfg = dp.Cfg("bl"); cfg.enabled = true; cfg.x, cfg.y = 30, 12
dp.Refresh("bl"); W.tick(0.1, 2)
local panel = _G.XayaUIDataPanel_bl
local slot1 = panel and select(1, panel:GetChildren())
-- the Notepad, shown
ns.Notepad_SetShown(true); W.tick(0.1, 2)
local note = _G.XayaUINotepad
local ndb = ns.notepadDB
local sidebar = _G.XayaUIChatSidebar
if HAS_CHAT then
  check("the test's elements exist (display, data panel, Notepad, chat sidebar)", dfr and panel and note and sidebar and true or false,
    tostring(dfr) .. tostring(panel) .. tostring(note) .. tostring(sidebar))
else
  check("the test's elements exist (display, data panel, Notepad; XayaUI_Chat is absent: no chat sidebar)", dfr and panel and note and sidebar == nil and true or false,
    tostring(dfr) .. tostring(panel) .. tostring(note) .. tostring(sidebar))
end

local defs, order = ns.ElementDefs()
R.registered = table.concat(order, " ")
local panelUp, slotClick, dispUp, noteUp = panel:GetScript("OnMouseUp"), slot1:GetScript("OnClick"), dfr:GetScript("OnMouseUp"), note:GetScript("OnMouseUp")
-- A: window closed
check("A closed: no element handler on any frame", ns.ElementHandlersAttached() == 0, ns.ElementHandlersAttached())
check("A closed: no element menu frame exists", ns.ElementMenu() == nil and _G.XayaUIElementMenu == nil)
if HAS_CHAT then check("A closed: the chat sidebar strip does not take the mouse", not sidebar:IsMouseEnabled())
else skipChat("A closed: the chat sidebar strip does not take the mouse") end
opened = {}
ns.ElementRightClick(panel, "OnMouseUp")
check("A closed: right-click on a data panel opens its page (as before)", opened[1] == "bonus/datapanels", table.concat(opened, ","))
-- (that opened the window: close it again for the display check)
pcall(ns.ToggleUI); W.tick(0.1, 3)
check("A closed again", not ns.ElementWindowIsShown())
visualMenus = 0
ns.SetMoveUnlocked({ cue }, true); ns.Step(); W.tick(0.1, 2)   -- (closing the window ended the unlock: unlock again, as a player would)
ns.ElementRightClick(dfr, "OnMouseUp")
check("A closed: right-click on an unlocked display opens its own menu (#61)", visualMenus == 1 and ns.ElementMenu() == nil, visualMenus)

-- B: window shown
pcall(ns.ToggleUI); W.tick(0.1, 4)
check("B the window is shown", ns.ElementWindowIsShown())
ns.SetMoveUnlocked({ cue }, true); ns.Step(); W.tick(0.1, 2)
check("B the frames carry the right-click while the window is shown", ns.ElementHandlersAttached() >= 4 and panel:GetScript("OnMouseUp") ~= panelUp
  and slot1:GetScript("OnClick") ~= slotClick and dfr:GetScript("OnMouseUp") ~= dispUp, ns.ElementHandlersAttached())
if HAS_CHAT then check("B the chat sidebar strip takes the mouse while the window is shown", sidebar:IsMouseEnabled())
else skipChat("B the chat sidebar strip takes the mouse while the window is shown") end
local function visibleKids(m)
  local out = {}
  for _, k in ipairs({ m:GetChildren() }) do if k:IsShown() then out[#out + 1] = k end end
  return out
end
local function menuShape()
  local m = ns.ElementMenu()
  if not (m and m:IsShown()) then return "none" end
  local t = {}
  if m.title:IsShown() then t[#t + 1] = "title:" .. tostring(m.title:GetText()) end
  for _, k in ipairs(visibleKids(m)) do
    if k == m.title or k == m.xLabel or k == m.yLabel then -- (labels: read with their box)
    elseif k.GetObjectType and k:GetObjectType() == "Texture" then t[#t + 1] = "-"
    elseif k == m.options then t[#t + 1] = "[" .. tostring(k:GetText()) .. "]"
    elseif k == m.x then t[#t + 1] = m.xLabel:IsShown() and (m.xLabel:GetText() .. "=" .. tostring(k:GetText())) or "x?"
    elseif k == m.y then t[#t + 1] = m.yLabel:IsShown() and (m.yLabel:GetText() .. "=" .. tostring(k:GetText())) or "y?"
    else t[#t + 1] = tostring(k:GetText()) end
  end
  return table.concat(t, " | ")
end
opened = {}
ns.ElementRightClick(slot1, "OnClick")
R.panelMenu = menuShape()
check("B right-click on a data panel block: exactly Element options, X and Y (its cfg.x / cfg.y)", R.panelMenu == "[Element options] | X=30 | Y=12", R.panelMenu)
check("B ... and it does not jump to the page", #opened == 0, table.concat(opened, ","))
local m = ns.ElementMenu()
local _, _, _, mx, my = m:GetPoint(1)
check("B the menu opens at the cursor (10 px right of and below it)", m:GetFrameStrata() == "FULLSCREEN_DIALOG" and mx == 960 / UIParent:GetEffectiveScale() + 10
  and my == 540 / UIParent:GetEffectiveScale() - 10, tostring(mx) .. "," .. tostring(my))
check("B the menu's click-outside and combat events are registered while it shows", m:IsEventRegistered("GLOBAL_MOUSE_DOWN") and m:IsEventRegistered("PLAYER_REGEN_DISABLED"))
ns.ElementRightClick(panel, "OnMouseUp")
check("B the panel's own frame (between its blocks) opens the same menu", menuShape() == "[Element options] | X=30 | Y=12", menuShape())

-- D: X + 10 on the data panel
m.x:SetText("40"); ns.ElementMenuApply()
local _, _, _, px, py = panel:GetPoint(1)
local tab = ns.BuildDataPanelsTab(function() end)
local sec = tab.args.general.args.left
local function findArg(g, name, d)   -- the position box's slider (the tooltip box has its own small X-Offset, -30 to 30)
  if type(g) ~= "table" or d > 6 then return nil end
  for _, c in pairs(g.args or {}) do
    if type(c) == "table" and c.type == "range" and c.name == name and c.min == -2000 then return c end
    local hit = findArg(c, name, d + 1); if hit then return hit end
  end
end
local xs, ys = findArg(sec, "X-Offset", 0), findArg(sec, "Y-Offset", 0)
check("D X + 10: the panel's saved X-Offset is 40, Y unchanged", cfg.x == 40 and cfg.y == 12, tostring(cfg.x) .. "," .. tostring(cfg.y))
check("D ... the page's X-Offset / Y-Offset read 40 / 12", xs and ys and xs.get({}) == 40 and ys.get({}) == 12, xs and tostring(xs.get({})))
check("D ... the panel is drawn there", px == 40 and py == 12, tostring(px) .. "," .. tostring(py))
check("D ... the menu shows the new numbers", menuShape() == "[Element options] | X=40 | Y=12", menuShape())
m.y:SetText("abc"); ns.ElementMenuApply()
check("D a box that is not a number changes nothing", cfg.x == 40 and cfg.y == 12 and menuShape() == "[Element options] | X=40 | Y=12", menuShape())
-- C: Element options
opened = {}
m.options:GetScript("OnClick")(m.options, "LeftButton")
check("C Element options on a data panel opens Bonus Features > Data Panels and closes the menu", opened[1] == "bonus/datapanels" and not m:IsShown(), table.concat(opened, ","))

-- E: a display (it has its own menu: its entries stay)
ns.ElementRightClick(dfr, "OnMouseUp")
R.displayMenu = menuShape()
local want = "title:" .. cue.name .. " | [Element options] | X=40 | Y=-20 | Snap Target  > | Linked Auras (move together)  > | Center Vertically | Center Horizontally | Paired Aura  > | - | * Free Move | Drag Snapping  > | - | Edit This Aura"
check("E display: its title, Element options, X / Y (visual.x / y), then every entry of its own menu", R.displayMenu == want, R.displayMenu)
lastMenu = nil
rawVM(cue, dfr)
R.ctx = table.concat(lastMenu or {}, " | ")
check("E the display's own context menu is unchanged (same entries and order as before 0.6.80)",
  R.ctx == "title:" .. cue.name .. " | Snap Target | Linked Auras (move together) | Center Vertically | Center Horizontally | Paired Aura | - | radio:Free Move | Drag Snapping | - | Edit This Aura", R.ctx)
m = ns.ElementMenu()
m.x:SetText("50"); m.y:SetText("-35"); ns.ElementMenuApply()
local _, _, _, fx, fy = dfr:GetPoint(1)
check("E X / Y on a display write its visual.x / visual.y (the editor's X / Y) and move it", cue.visual.x == 50 and cue.visual.y == -35,
  tostring(cue.visual.x) .. "," .. tostring(cue.visual.y) .. " drawn " .. tostring(fx) .. "," .. tostring(fy))
-- a row of the display's own menu still works from here
local centered
for _, b in ipairs(m.shownRows) do if b:GetText() == "Center Horizontally" then b:GetScript("OnClick")(b, "LeftButton"); centered = true end end
check("E a kept entry (Center Horizontally) runs its own action", centered and cue.visual.x == 0, tostring(cue.visual.x))
ns.ElementRightClick(dfr, "OnMouseUp")
edited = {}
m.options:GetScript("OnClick")(m.options, "LeftButton")
check("C Element options on a display opens it in the rule editor", edited[1] == cue, tostring(edited[1]))

-- the Notepad
ns.ElementRightClick(note.bar, "OnMouseUp")
local nshape = menuShape()
check("C/D Notepad: Element options and its own X / Y (db.x / db.y)", nshape == "[Element options] | X=" .. tostring(math.floor(ndb.x + 0.5)) .. " | Y=" .. tostring(math.floor(ndb.y + 0.5)), nshape)
m.x:SetText(tostring((ndb.x or 0) + 10)); local oldY = ndb.y; ns.ElementMenuApply()
local _, _, _, nx = note:GetPoint(1)
check("D Notepad X + 10 is saved and drawn", nx == ndb.x and ndb.y == oldY, tostring(nx) .. " " .. tostring(ndb.x))
opened = {}
m.options:GetScript("OnClick")(m.options, "LeftButton")
check("C Element options on the Notepad opens Bonus Features > Utilities > Notepad", opened[1] == "bonus/utilities/notepad", table.concat(opened, ","))

-- the Calculator and the Shopping List
if ns.Calculator_Open then pcall(ns.Calculator_Open) end
local calc = _G.XayaUICalculator
check("the Calculator exists", calc ~= nil)
if calc then
  ns.ElementRightClick(calc, "OnMouseUp")
  check("C/D Calculator: Element options and its own X / Y (never moved: 0 / 0 from the centre)", menuShape() == "[Element options] | X=0 | Y=0", menuShape())
  m.x:SetText("10"); ns.ElementMenuApply()
  local cd = ns.Settings("bonus").calculator
  local cp, _, _, cx = calc:GetPoint(1)
  check("D Calculator X + 10 is saved (point / x) and drawn", cd.point == "CENTER" and cd.x == 10 and cd.y == 0 and cp == "CENTER" and cx == 10, tostring(cd.x) .. " " .. tostring(cx))
  opened = {}
  m.options:GetScript("OnClick")(m.options, "LeftButton")
  check("C Element options on the Calculator opens Bonus Features > Utilities > Calculator", opened[1] == "bonus/utilities/calculator", table.concat(opened, ","))
end
local sl = ns.Service("shoppingList")
local slc = sl and sl.Cfg()
if slc then
  slc.enabled = true; slc.panel = true
  if ns.SwitchApplyNow then ns.SwitchApplyNow("reskin.shoppinglist") end
  pcall(sl.Apply, true); W.tick(0.1, 2)
end
local slp = _G.XayaUIShoppingList
check("the Shopping List panel exists", slp ~= nil)
if slp then
  ns.ElementRightClick(slp, "OnMouseUp")
  check("C/D Shopping List: Element options and its own X / Y (free.x / free.y)", menuShape() == "[Element options] | X=" .. slc.free.x .. " | Y=" .. slc.free.y, menuShape())
  m.y:SetText(tostring(slc.free.y + 10)); local fx0 = slc.free.x; ns.ElementMenuApply()
  local _, _, _, sx, sy = slp:GetPoint(1)
  check("D Shopping List Y + 10 is saved and drawn", slc.free.x == fx0 and sx == slc.free.x and sy == slc.free.y, tostring(sy) .. " " .. tostring(slc.free.y))
  opened = {}
  m.options:GetScript("OnClick")(m.options, "LeftButton")
  check("C Element options on the Shopping List opens Blizzard Reskin > Shopping List", opened[1] == "reskin/shoppinglist", table.concat(opened, ","))
end

-- F: no X / Y where the element has none, and for a Blizzard frame
if HAS_CHAT then
  ns.ElementRightClick(sidebar, "OnMouseUp")
  R.sidebarMenu = menuShape()
  check("F chat sidebar: Element options only (its place is a side and a gap, no X / Y)", R.sidebarMenu == "[Element options]", R.sidebarMenu)
  opened = {}
  m.options:GetScript("OnClick")(m.options, "LeftButton")
  check("C Element options on the sidebar opens QoL > Improved Chat > Sidebar", opened[1] == "qol/improvedchat/sidebar", table.concat(opened, ","))
else
  skipChat("F chat sidebar: Element options only (its place is a side and a gap, no X / Y)")
  skipChat("C Element options on the sidebar opens QoL > Improved Chat > Sidebar")
end
local blz = W.new("Frame", "XuiTestBlizzardFrame", UIParent); blz:EnableMouse(true)
local blzOwn = 0
blz:SetScript("OnMouseUp", function() blzOwn = blzOwn + 1 end)
local setCalls = 0
ns.RegisterElement({ key = "testBlizzard", blizzard = true, page = { "reskin", "charreskin" }, targets = function(add) add(blz, "OnMouseUp") end,
  getPos = function() return 1, 2 end, setPos = function() setCalls = setCalls + 1 end })
ns.ElementRightClick(blz, "OnMouseUp")
check("F a restyled Blizzard frame: Element options only, and Blizzard's own handler still runs", menuShape() == "[Element options]" and blzOwn == 1, menuShape() .. " " .. blzOwn)
-- a protected frame is never touched
local prot = W.new("Frame", "XuiTestProtected", UIParent); prot.IsProtected = function() return true, true end
local protScript = function() end
prot:SetScript("OnMouseUp", protScript)
ns.RegisterElement({ key = "testProtected", page = { "qol", "x" }, targets = function(add) add(prot, "OnMouseUp") end })
check("G a protected frame gets no handler", prot:GetScript("OnMouseUp") == protScript)

-- G: combat
ns.ElementMenu():Hide()
W.combat = true
opened = {}
ns.ElementRightClick(slot1, "OnClick")
check("G in combat a right-click does the old thing (no menu)", not ns.ElementMenu():IsShown() and opened[1] ~= nil, table.concat(opened, ","))
W.combat = false
ns.ElementRightClick(panel, "OnMouseUp")
W.fire("PLAYER_REGEN_DISABLED")
check("G an open menu closes when combat starts", not ns.ElementMenu():IsShown())
check("H the menu's events are unregistered once it is hidden", not ns.ElementMenu():IsEventRegistered("GLOBAL_MOUSE_DOWN") and not ns.ElementMenu():IsEventRegistered("PLAYER_REGEN_DISABLED"))
ns.ElementRightClick(panel, "OnMouseUp")
W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
check("H a click outside the menu closes it", not ns.ElementMenu():IsShown())

-- H: close the window
ns.ElementRightClick(panel, "OnMouseUp")
if ns.ElementWindowIsShown() then pcall(ns.ToggleUI) end; W.tick(0.1, 4)
check("H window closed: the menu is hidden", not ns.ElementMenu():IsShown())
check("H window closed: every frame has its own script back", ns.ElementHandlersAttached() == 0 and panel:GetScript("OnMouseUp") == panelUp
  and slot1:GetScript("OnClick") == slotClick and dfr:GetScript("OnMouseUp") == dispUp and note:GetScript("OnMouseUp") == noteUp)
if HAS_CHAT then check("H window closed: the sidebar strip no longer takes the mouse", not sidebar:IsMouseEnabled())
else skipChat("H window closed: the sidebar strip no longer takes the mouse") end
opened = {}
ns.ElementRightClick(slot1, "OnClick")
check("H window closed: right-click on a data panel opens its page again (old behaviour)", opened[1] == "bonus/datapanels" and not ns.ElementMenu():IsShown(), table.concat(opened, ","))
if ns.ElementWindowIsShown() then pcall(ns.ToggleUI); W.tick(0.1, 3) end
blzOwn = 0
ns.ElementRightClick(blz, "OnMouseUp")
check("H window closed: the Blizzard frame's hook does nothing (its own handler runs)", blzOwn == 1 and not ns.ElementMenu():IsShown())
return R
end
'''

OFF = r'''
return function(W, L)
local R = {}
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
if ns.ToggleUI then pcall(ns.ToggleUI); W.tick(0.1, 4) end
local _, order = ns.ElementDefs()
R.registered = table.concat(order, " ")
R.attached = ns.ElementHandlersAttached()
R.menu = _G.XayaUIElementMenu ~= nil
return R
end
'''


def session(src, enabled):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld, c) return loadstring(src)()(W, Ld, c) end")(src, world, loader, HAS_CHAT)
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return res, errs


def main():
    folders = H.find_addons()
    bad = n = nskip = 0

    def skip(name):
        nonlocal nskip
        nskip += 1
        print("SKIP (QA-branch module absent: XayaUI_Chat) " + name)

    def check(name, ok, detail=""):
        nonlocal bad, n
        if ok == "skip":
            return skip(name)
        n += 1
        print(("ok  " if ok else "FAIL: ") + name + ("" if ok or not detail else "  [" + str(detail) + "]"))
        if not ok:
            bad += 1

    res, errs = session(LUA, [k for k in folders if k != "XayaUI_DevAssist"])
    for i in range(1, len(res) + 1):
        check(res[i][1], res[i][2])
    print("registered (all on):", res.registered)
    for e in errs:
        print("ERROR in the game stand-in:", e[:600])
        bad += 1

    # I: off costs nothing
    every = [k for k in folders if k != "XayaUI_DevAssist"]
    r, e = session(OFF, every)
    reg = str(r.registered).split()
    check("I all on, nothing shown, no data panel on: no data panel, Notepad, Calculator or display is registered",
          not any(k.startswith("dataPanel:") or k in ("notepad", "calculator", "ruleDisplays", "shoppingList") for k in reg), r.registered)
    check("I window open with nothing to right-click: no menu frame is made", not r.menu)
    for e1 in e:
        print("ERROR:", e1[:400]); bad += 1
    for off in ("XayaUI_Bonus", "XayaUI_Chat", "XayaUI_Rules", "XayaUI_QoL"):
        if off == "XayaUI_Chat" and not HAS_CHAT:
            skip("I %s off: nothing of it is registered" % off)
            continue
        r, e = session(OFF, [k for k in every if k != off and not (off == "XayaUI_Rules" and k == "XayaUI_Rules_Options")])
        reg = str(r.registered).split()
        mine = {"XayaUI_Bonus": ("dataPanel:", "notepad", "calculator"), "XayaUI_Chat": ("chatSidebar", "chatDataPanel"),
                "XayaUI_Rules": ("ruleDisplays",), "XayaUI_QoL": ("shoppingList", "characterPane")}[off]
        check("I %s off: nothing of it is registered" % off, not any(k.startswith(p) for k in reg for p in mine), r.registered)
        for e1 in e:
            print("ERROR:", e1[:400]); bad += 1
    r, e = session(OFF, ["XayaUI", "XayaUI_Options", "XayaUI_Media"])
    check("I every feature module off: no element is registered, no handler, no menu frame",
          str(r.registered) == "" and r.attached == 0 and not r.menu, "%s %s %s" % (r.registered, r.attached, r.menu))
    print("%d checks, %d failed%s" % (n, bad, (", %d skipped (QA-branch module absent: XayaUI_Chat)" % nskip) if nskip else ""))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
