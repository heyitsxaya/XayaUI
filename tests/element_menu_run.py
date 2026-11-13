#!/usr/bin/env python3
"""Element menu (core 0.6.80; #495, REQUEST-LOG PS-59). Xaya, 2026-11-08 (her words): "Also with the options panel on, right clicking an
element object should open up an at-cursor menu to allow the user to select "element options" and modify position with x,y inputs".
On the real addons in the stand-in game (XayaUI, XayaUI_Options, XayaUI_Rules; the modules that registered the data panels, Notepad,
Calculator, Shopping List and chat sidebar live on another branch). The kept elements are XayaUI Rules' displays; the plain element with
a settings page and an X / Y (what a data panel was) is a stand-in frame this test registers, like the Blizzard and protected frames:
  A Window closed: no element handler is on any frame (each frame's own right-click script is in place), a right-click does what it
    did before (the plain element's own script opens its page; an unlocked display opens its own menu, #61), and no element menu frame exists.
    Before the settings window's code first loads, the menu's code is not read at all (bundle 1 round 7, SD-58: it is XayaUI Options'
    ElementMenu.lua; core keeps the registry): elements registered before that take the right-click once the window opens (B).
  B Window shown: a right-click on the plain element opens the menu at the cursor with exactly "Element options", X and Y (no title, no
    other row) and does not jump to the page; X / Y show the element's own getPos.
  C "Element options" opens that element's page (the plain element -> its registered page; display -> the rule editor on that display)
    and closes the menu.
  D X / Y write through the element's setPos: X + 10 moves the saved x by 10 and the frame is placed at it; a display's visual.x / y
    (the editor's X / Y).
  E A display that has its own right-click menu (#61) keeps every entry of it, in the same order, under its title; the game's context
    menu built from the same list is unchanged (parity with the entries before 0.6.80).
  F Elements with no X / Y setting (a strip stand-in with no getPos / setPos, what the chat sidebar was) and restyled Blizzard frames
    show "Element options" only.
  G Combat: a right-click does the old thing (no menu); an open menu closes when combat starts; a protected frame gets no handler.
  H Closing the window puts every frame's own script back, takes the mouse back from the strip (mouse = true), hides the menu; the menu's
    events are registered only while it shows.
  I Off costs nothing (V14): with XayaUI Rules off nothing of it is registered; with no feature module on, nothing is registered.
Fails on the code before 0.6.80 (no ns.RegisterElement: no menu).
Run: python3 tests/element_menu_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402


LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
-- record page jumps and rule-editor opens (and still do them)
local opened, edited, visualMenus = {}, {}, 0
local rawOpen = ns.OpenSettingsPage
ns.OpenSettingsPage = function(...) opened[#opened + 1] = table.concat({ ... }, "/"); return rawOpen(...) end
local rawEdit = ns.EditRule
ns.EditRule = function(r) edited[#edited + 1] = r; return rawEdit(r) end
-- (bundle 1 round 7, SD-58) the display menu is XayaUI Options' (Mover.lua): counted once the window's code has loaded
local vmHooked, rawVM = false, nil
local function HookVM()
  if vmHooked or not ns.ShowVisualMenu then return end
  vmHooked = true
  rawVM = ns.ShowVisualMenu
  ns.ShowVisualMenu = function(...) visualMenus = visualMenus + 1; return rawVM(...) end
end
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

-- a rule with a display cue, unlocked for moving (it takes clicks only then, as before). (bundle 1 round 7, SD-58) Unlocking is the
-- mover's, which works only while the settings window is open: here the display is first drawn as a sample by a preview (window closed)
ns.rules = ns.rules or {}
local r = ns.NewRule(); r.name = "Demon Spikes"; r.enabled = true; r.useBuff, r.buffID, r.buffState = true, 1001, "present"
r.visual.enabled, r.sound.enabled = false, false
ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
local cue = ns.NewCueRule(r, "texture"); cue.visual.kind, cue.visual.tex = "file", "Interface\\Icons\\INV_Misc_QuestionMark"
cue.visual.x, cue.visual.y = 40, -20
ns.SetPreview({ cue }, "visual", true); ns.RefreshVisual(cue); ENGINE_STEP(ns); W.tick(0.1, 3)
local dfr = ns.VisualFramesOf(cue)[1]
-- a plain element with a settings page and an X / Y (what a data panel was before the modules moved to another branch): a frame and
-- a child button, each with its own right-click script that opens the page (the "old thing" the menu must leave in place)
local pos = { x = 30, y = 12 }
local panel = W.new("Frame", "XuiTestPanel", UIParent); panel:EnableMouse(true)
panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
local slot1 = W.new("Button", "XuiTestPanelSlot", panel)
local function ownRightClick(_, btn) if btn == "RightButton" then ns.OpenSettingsPage("testmod", "testpanel") end end
panel:SetScript("OnMouseUp", ownRightClick); slot1:SetScript("OnClick", ownRightClick)
ns.RegisterElement({ key = "testPanel", page = { "testmod", "testpanel" },
  targets = function(add) add(panel, "OnMouseUp"); add(slot1, "OnClick") end,
  getPos = function() return pos.x, pos.y end,
  setPos = function(_, x, y) pos.x, pos.y = x, y; panel:ClearAllPoints(); panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y) end })
-- a strip that takes the mouse only while the window is shown (what the chat sidebar strip was): EnableMouse(false), mouse = true, and
-- no getPos / setPos (its place is not an X / Y), so its menu is "Element options" only
local strip = W.new("Frame", "XuiTestStrip", UIParent); strip:EnableMouse(false)
local stripUp = function() end
strip:SetScript("OnMouseUp", stripUp)
ns.RegisterElement({ key = "testStrip", mouse = true, page = { "testmod", "strip" }, targets = function(add) add(strip, "OnMouseUp") end })
check("the test's elements exist (display, plain element, mouse strip)", dfr and panel and slot1 and strip and true or false, tostring(dfr) .. tostring(panel) .. tostring(strip))

local defs, order = ns.ElementDefs()
R.registered = table.concat(order, " ")
local panelUp, slotClick, dispUp = panel:GetScript("OnMouseUp"), slot1:GetScript("OnClick"), dfr:GetScript("OnMouseUp")
-- A: window closed. (bundle 1 round 7, REQUEST-LOG A23 SD-58) The menu's code is XayaUI Options' (XayaUI_Options/ElementMenu.lua): until
-- the settings window's code first loads, only core's registry exists (ns.RegisterElement / ns.ElementDefs above), and the test entry
-- points ns.ElementHandlersAttached / ns.ElementMenu / ns.ElementRightClick are not there yet; a right-click is sent the way the game
-- sends it (the frame's own script with "RightButton"), as ns.ElementRightClick does.
local function RightClick(f, script) local fn = f:GetScript(script or "OnMouseUp"); if fn then fn(f, "RightButton") end end
check("A before the window's code ever loaded: the menu's code is not read (no ns.ElementMenu, ns.ElementWindowShown)",
  ns.ElementMenu == nil and ns.ElementWindowShown == nil and ns.ElementHandlersAttached == nil)
check("A closed: no element handler on any frame (each keeps its own right-click script)", panel:GetScript("OnMouseUp") == ownRightClick
  and slot1:GetScript("OnClick") == ownRightClick and strip:GetScript("OnMouseUp") == stripUp)
check("A closed: no element menu frame exists", _G.XayaUIElementMenu == nil)
check("A closed: the strip does not take the mouse", not strip:IsMouseEnabled())
opened = {}
RightClick(panel, "OnMouseUp")
check("A closed: right-click on the plain element runs its own script (it opens its page, as before)", opened[1] == "testmod/testpanel", table.concat(opened, ","))
-- (that opened the window: close it again for the display check)
pcall(ns.ToggleUI); W.tick(0.1, 3)
check("A closed again", not ns.ElementWindowIsShown())
HookVM()
visualMenus = 0
-- (bundle 1 round 7, SD-58, her words: "mover view only available when settings window is open") Before round 7 a display unlocked with
-- the window closed opened its own menu here (#61). Now a display cannot be unlocked while the window is closed: it takes no click and
-- a right-click on it opens no menu (it goes to the game).
ns.SetMoveUnlocked({ cue }, true); ENGINE_STEP(ns); W.tick(0.1, 2)
ns.ElementRightClick(dfr, "OnMouseUp")
check("A closed (SD-58): a display cannot be unlocked for moving while the window is closed: it takes no click, and a right-click opens no menu",
  not ns.IsMoveUnlocked(cue) and not dfr:IsMouseEnabled() and visualMenus == 0 and ns.ElementMenu() == nil,
  tostring(ns.IsMoveUnlocked(cue)) .. " " .. tostring(dfr:IsMouseEnabled()) .. " " .. visualMenus)

-- B: window shown
pcall(ns.ToggleUI); W.tick(0.1, 4)
check("B the window is shown", ns.ElementWindowIsShown())
ns.SetMoveUnlocked({ cue }, true); ENGINE_STEP(ns); W.tick(0.1, 2)
check("B the frames carry the right-click while the window is shown (the element's frame and button, the strip, the display)", ns.ElementHandlersAttached() == 4 and panel:GetScript("OnMouseUp") ~= panelUp
  and slot1:GetScript("OnClick") ~= slotClick and strip:GetScript("OnMouseUp") ~= stripUp and dfr:GetScript("OnMouseUp") ~= dispUp, ns.ElementHandlersAttached())
check("B the strip takes the mouse while the window is shown", strip:IsMouseEnabled())
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
check("B right-click on the element's button: exactly Element options, X and Y (its getPos)", R.panelMenu == "[Element options] | X=30 | Y=12", R.panelMenu)
check("B ... and it does not jump to the page", #opened == 0, table.concat(opened, ","))
local m = ns.ElementMenu()
local _, _, _, mx, my = m:GetPoint(1)
check("B the menu opens at the cursor (10 px right of and below it)", m:GetFrameStrata() == "FULLSCREEN_DIALOG" and mx == 960 / UIParent:GetEffectiveScale() + 10
  and my == 540 / UIParent:GetEffectiveScale() - 10, tostring(mx) .. "," .. tostring(my))
check("B the menu's click-outside and combat events are registered while it shows", m:IsEventRegistered("GLOBAL_MOUSE_DOWN") and m:IsEventRegistered("PLAYER_REGEN_DISABLED"))
ns.ElementRightClick(panel, "OnMouseUp")
check("B the element's own frame (around its button) opens the same menu", menuShape() == "[Element options] | X=30 | Y=12", menuShape())

-- D: X + 10 on the plain element
m.x:SetText("40"); ns.ElementMenuApply()
local _, _, _, px, py = panel:GetPoint(1)
check("D X + 10: the element's saved X is 40, Y unchanged", pos.x == 40 and pos.y == 12, tostring(pos.x) .. "," .. tostring(pos.y))
check("D ... the element is drawn there", px == 40 and py == 12, tostring(px) .. "," .. tostring(py))
check("D ... the menu shows the new numbers", menuShape() == "[Element options] | X=40 | Y=12", menuShape())
m.y:SetText("abc"); ns.ElementMenuApply()
check("D a box that is not a number changes nothing", pos.x == 40 and pos.y == 12 and menuShape() == "[Element options] | X=40 | Y=12", menuShape())
-- C: Element options
opened = {}
m.options:GetScript("OnClick")(m.options, "LeftButton")
check("C Element options on the plain element opens its page and closes the menu", opened[1] == "testmod/testpanel" and not m:IsShown(), table.concat(opened, ","))

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

-- F: no X / Y where the element has none (the strip), and for a Blizzard frame
ns.ElementRightClick(strip, "OnMouseUp")
R.stripMenu = menuShape()
check("F the strip: Element options only (no getPos / setPos: no X / Y)", R.stripMenu == "[Element options]", R.stripMenu)
opened = {}
m.options:GetScript("OnClick")(m.options, "LeftButton")
check("C Element options on the strip opens its page and closes the menu", opened[1] == "testmod/strip" and not m:IsShown(), table.concat(opened, ","))
local blz = W.new("Frame", "XuiTestBlizzardFrame", UIParent); blz:EnableMouse(true)
local blzOwn = 0
blz:SetScript("OnMouseUp", function() blzOwn = blzOwn + 1 end)
local setCalls = 0
ns.RegisterElement({ key = "testBlizzard", blizzard = true, page = { "testmod", "charreskin" }, targets = function(add) add(blz, "OnMouseUp") end,
  getPos = function() return 1, 2 end, setPos = function() setCalls = setCalls + 1 end })
ns.ElementRightClick(blz, "OnMouseUp")
check("F a restyled Blizzard frame: Element options only, and Blizzard's own handler still runs", menuShape() == "[Element options]" and blzOwn == 1, menuShape() .. " " .. blzOwn)
-- a protected frame is never touched
local prot = W.new("Frame", "XuiTestProtected", UIParent); prot.IsProtected = function() return true, true end
local protScript = function() end
prot:SetScript("OnMouseUp", protScript)
ns.RegisterElement({ key = "testProtected", page = { "testmod", "x" }, targets = function(add) add(prot, "OnMouseUp") end })
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
  and slot1:GetScript("OnClick") == slotClick and strip:GetScript("OnMouseUp") == stripUp and dfr:GetScript("OnMouseUp") == dispUp)
check("H window closed: the strip no longer takes the mouse", not strip:IsMouseEnabled())
opened = {}
ns.ElementRightClick(slot1, "OnClick")
check("H window closed: right-click on the plain element opens its page again (old behaviour)", opened[1] == "testmod/testpanel" and not ns.ElementMenu():IsShown(), table.concat(opened, ","))
if ns.ElementWindowIsShown() then pcall(ns.ToggleUI); W.tick(0.1, 3) end
blzOwn = 0
ns.ElementRightClick(blz, "OnMouseUp")
check("H window closed: the Blizzard frame's hook does nothing (its own handler runs)", blzOwn == 1 and not ns.ElementMenu():IsShown())
return R
end
'''

# (round 7 repair) the engine no longer exports ns.Step: one full engine step is reached through tests/engine_bench.py's helper
_BENCH = open(os.path.join(HERE, "engine_bench.py"), encoding="utf-8").read()
ENGINE_STEP_LUA = _BENCH[_BENCH.index("-- [engine-step helper]"):_BENCH.index("-- [/engine-step helper]")]
LUA = LUA.replace("return function(W, L)\n", "return function(W, L)\n" + ENGINE_STEP_LUA, 1)

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
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(src, world, loader)
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return res, errs


def main():
    folders = H.find_addons()
    bad = n = 0

    def check(name, ok, detail=""):
        nonlocal bad, n
        n += 1
        print(("ok  " if ok else "FAIL: ") + name + ("" if ok or not detail else "  [" + str(detail) + "]"))
        if not ok:
            bad += 1

    res, errs = session(LUA, list(folders))
    for i in range(1, len(res) + 1):
        check(res[i][1], res[i][2])
    print("registered (all on):", res.registered)
    for e in errs:
        print("ERROR in the game stand-in:", e[:600])
        bad += 1

    # I: off costs nothing
    every = list(folders)
    r, e = session(OFF, every)
    reg = str(r.registered).split()
    check("I all on, nothing shown: no display is registered", "ruleDisplays" not in reg, r.registered)
    check("I window open with nothing to right-click: no menu frame is made", not r.menu)
    for e1 in e:
        print("ERROR:", e1[:400]); bad += 1
    r, e = session(OFF, [k for k in every if k != "XayaUI_Rules"])
    reg = str(r.registered).split()
    check("I XayaUI_Rules off: nothing of it is registered", "ruleDisplays" not in reg, r.registered)
    for e1 in e:
        print("ERROR:", e1[:400]); bad += 1
    r, e = session(OFF, ["XayaUI", "XayaUI_Options"])
    check("I every feature module off: no element is registered, no handler, no menu frame",
          str(r.registered) == "" and r.attached == 0 and not r.menu, "%s %s %s" % (r.registered, r.attached, r.menu))
    for e1 in e:
        print("ERROR:", e1[:400]); bad += 1
    print("%d checks, %d failed" % (n, bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
