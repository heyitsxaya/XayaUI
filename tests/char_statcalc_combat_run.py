#!/usr/bin/env python3
"""Stat Calculator combat lock (V26; Xaya, REQUEST-LOG A24 #2 "Stat calculator unavailable in combat; character pane openable in
combat" and #3 "Hide silently"). On the stand-in character window (tests/char_world.lua), with the real Stat Calculator
(XayaUI_Bonus/StatCalculator.lua) and Improved Character Display's Stat Calc button (XayaUI_QoL/ImprovedCharacterDisplay.lua):
  C1  the panel docked beside the open character window and the Stat Calc button showing; combat starts (PLAYER_REGEN_DISABLED, then
      the lockdown): both hide, with no message; the panel's saved open state is kept; the stat events stop (only PLAYER_REGEN_ENABLED
      is listened to).
  C2  in combat: the button's click, /xui stats, the statCalc service's Toggle / Open and the minimap row's call open nothing and say
      nothing; closing and opening the character window builds no model and draws nothing; a stat event does nothing; the character
      window itself still opens and closes.
  C3  combat ends with the character window open: the panel comes back docked and drawn, the button shows again, the events are back.
  C4  the character window closed during combat: after combat the panel stays hidden (its trigger is gone), its open state is kept,
      and it docks again the next time the window opens.
  C5  the panel open on its own (the window closed): hidden in combat, back on its own after combat.
  C6  the panel left closed before combat: still closed after combat.
  C7  the Stat Calculator switched on in combat (/xui stats on): nothing shows, nothing is built; after combat it docks beside the
      open window.
Negative control: with the Stat Calculator file before this step (no combat lock; XUI_ROOT=<copy>), C1-C5 and C7 fail (12 of 28: the
  panel stays up, draws and listens in combat).
Every number is a TEST STAND-IN. In-game behavior is UNVERIFIED IN GAME.
Run from the repo root: python3 tests/char_statcalc_combat_run.py   Needs: pip install lupa."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.environ.get("XUI_ROOT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
HERE = os.path.dirname(os.path.abspath(__file__))


def P(rel, root=None):
    return "'" + os.path.join(root or ROOT, rel).replace("\\", "/") + "'"


SRC = r'''
assert(loadfile(__WORLD__))()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__ICD__))("XayaUI_QoL", ns); assert(loadfile(__CT__))("XayaUI_Bonus", ns)
ns.FireReady(); ns.SettingsOpenAllForTests()
local CM = ns.StatModel
local builds = 0
local rawBuild = CM.Build
CM.Build = function(...) builds = builds + 1; return rawBuild(...) end
local function checkp(name, fn)
  local ok, cond, extra = pcall(fn)
  if not ok then check(name, false, "error: " .. tostring(cond)) else check(name, cond and true or false, extra) end
end
local function panel() return _G.XayaUIStatCalculator end
local function panelShown() local p = panel(); return p ~= nil and p:IsShown() end
local function button() return ns.CharDisplay_Button and ns.CharDisplay_Button() end
local function buttonShown() local b = button(); return b ~= nil and b:IsShown() end
local function evFrame()   -- the Stat Calculator's event frame (the only one that listens to COMBAT_RATING_UPDATE)
  for _, f in ipairs(created) do if f.scripts.OnEvent and f.events.COMBAT_RATING_UPDATE then return f end end
end
local function evCount(f) local n = 0; for _ in pairs(f and f.events or {}) do n = n + 1 end; return n end
local function enterCombat() fire("PLAYER_REGEN_DISABLED"); combat = true end   -- (the game: the event first, then the lockdown)
local function leaveCombat() combat = false; fire("PLAYER_REGEN_ENABLED") end
local function openWindow() CharacterFrame:Show(); PaperDollFrame:Show() end
local function closeWindow() PaperDollFrame:Hide(); CharacterFrame:Hide() end
local said = function() return #printed end

local c = CWC()
c.enabled = true
CWA()
openWindow()
checkp("setup: the panel docks beside the open character window and the Stat Calc button shows", function()
  return panelShown() and buttonShown() and c.panelOpen == true, tostring(panelShown()) .. " " .. tostring(buttonShown()) end)
local ev = evFrame()
checkp("setup: the Stat Calculator listens to its stat events (COMBAT_RATING_UPDATE, UNIT_STATS)", function()
  return ev ~= nil and ev.events.COMBAT_RATING_UPDATE and ev.events.UNIT_STATS, evCount(ev) end)

-- C1 combat starts
local p0 = said()
enterCombat()
checkp("C1 combat starts: the panel hides", function() return not panelShown() end)
checkp("  ...the Stat Calc button hides", function() return not buttonShown() end)
checkp("  ...no message (hide silently)", function() return said() == p0, printed[#printed] end)
checkp("  ...the panel's open state is kept for after combat (panelOpen)", function() return c.panelOpen == true end)
checkp("  ...the stat events stop: only PLAYER_REGEN_ENABLED is listened to", function()
  return ev.events.PLAYER_REGEN_ENABLED == true and evCount(ev) == 1, evCount(ev) end)

-- C2 nothing opens it in combat, nothing is built or drawn
builds = 0
local b = button()
if b and b.scripts.OnClick then b.scripts.OnClick(b) end
ns.StatCalc_Toggle()
pcall(ns.RunCommand, "stats", "")
local sc = ns.Service("statCalc")
sc.Toggle()
local okOpen, why = sc.Open("stats")
for _, e in ipairs(ns.Launchers and ns.Launchers() or {}) do if e[1] == "stats" and type(e[4]) == "function" then e[4]() end end
checkp("C2 in combat: the button's click, /xui stats, the service's Toggle / Open and the minimap row open nothing", function()
  return not panelShown() and okOpen == false, tostring(why) end)
checkp("  ...and say nothing", function() return said() == p0, printed[#printed] end)
checkp("  ...the service says the panel is not available (the button stays hidden)", function() return sc.Available() == false and not buttonShown() end)
closeWindow(); openWindow()
checkp("  ...the character window still opens in combat (ours never stops it)", function() return CharacterFrame:IsShown() and PaperDollFrame:IsShown() end)
fire("UNIT_STATS", "player"); fire("COMBAT_RATING_UPDATE")
checkp("  ...closing and opening the window, and a stat event, build no model and draw nothing", function()
  return builds == 0 and not panelShown(), builds end)

-- C3 combat ends with the window open
leaveCombat()
checkp("C3 combat ends, the window open: the panel comes back docked and drawn", function()
  return panelShown() and panel().standalone == false and builds > 0, builds end)
checkp("  ...the Stat Calc button shows again", function() return buttonShown() end)
checkp("  ...the stat events are back", function() return ev.events.COMBAT_RATING_UPDATE == true and ev.events.UNIT_STATS == true and ev.events.PLAYER_REGEN_DISABLED == true end)
checkp("  ...still no message", function() return said() == p0, printed[#printed] end)

-- C4 the window closed during combat
enterCombat()
closeWindow()
leaveCombat()
checkp("C4 the window closed during combat: after combat the panel stays hidden (its trigger is gone)", function() return not panelShown() end)
checkp("  ...its open state is kept", function() return c.panelOpen == true end)
openWindow()
checkp("  ...and it docks again the next time the window opens", function() return panelShown() end)

-- C5 open on its own
closeWindow()
ns.StatCalc_SetOpen(true)
checkp("C5 setup: the panel open on its own (the window closed)", function() return panelShown() and panel().standalone == true end)
enterCombat()
checkp("C5 in combat it hides", function() return not panelShown() end)
leaveCombat()
checkp("  ...after combat it is back on its own", function() return panelShown() and panel().standalone == true end)
ns.StatCalc_SetOpen(false)

-- C6 left closed before combat
openWindow()
checkp("C6 setup: closed by the player (the window open, the panel closed)", function() return not panelShown() and c.panelOpen == false end)
enterCombat(); leaveCombat()
checkp("C6 after combat it stays closed", function() return not panelShown() and c.panelOpen == false end)
ns.StatCalc_SetOpen(true)

-- C7 switched on in combat
ns.StatCalc_Cfg().enabled = false; ns.StatCalc_Apply()   -- (the Stat Calculator only; Improved Character Display stays on)
checkp("C7 setup: the Stat Calculator off: no panel, no button", function() return not panelShown() and not buttonShown() end)
enterCombat()
builds = 0
local p1 = said()
pcall(ns.RunCommand, "stats", "on")
checkp("C7 switched on in combat (/xui stats on): nothing shows and nothing is built", function()
  return not panelShown() and not buttonShown() and builds == 0, builds end)
checkp("  ...it waits for the end of combat (PLAYER_REGEN_ENABLED only)", function() return ev.events.PLAYER_REGEN_ENABLED == true and evCount(ev) == 1, evCount(ev) end)
leaveCombat()
checkp("  ...after combat it docks beside the open window and the button shows", function() return panelShown() and buttonShown() end)
print(n .. " checks, " .. fails .. " failed")
'''


def main():
    src = (SRC.replace("__WORLD__", P("tests/char_world.lua", os.path.join(HERE, ".."))).replace("__MOD__", P("XayaUI/Modules.lua"))
           .replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua"))
           .replace("__CM__", P("XayaUI_QoL/StatModel.lua")).replace("__ICD__", P("XayaUI_QoL/ImprovedCharacterDisplay.lua"))
           .replace("__CT__", P("XayaUI_Bonus/StatCalculator.lua")))
    lua = LuaRuntime()
    lua.execute(src)
    sys.exit(1 if lua.eval("fails") else 0)


if __name__ == "__main__":
    main()
