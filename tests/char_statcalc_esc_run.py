#!/usr/bin/env python3
"""Stat Calculator, A24 #8 (Xaya 2026-11-11, her words, REQUEST-LOG A24 row 8): stand-alone panel "Esc closes; normal layer
(Recommended)"; minimap row "Hide it in combat (Recommended)". On the whole-addon harness (tests/harness: every addon loaded as the game
loads them, with the REAL core XayaUI/KeyCatch.lua and XayaUI/MinimapButton.lua), the Stat Calculator on. What the player gets:
  E1  the panel's own frame name, and nothing else, is added to the game's UISpecialFrames, once (opening it again adds nothing).
  E2  opened on its own (the character window closed): Esc reaches the game (TOGGLEGAMEMENU) and the game's Esc closes it (stand-in for
      UIParent.lua CloseSpecialWindows: every shown frame named in UISpecialFrames is hidden); it counts as a close: the open state is
      saved as closed (c.panelOpen false), so opening the character window afterwards does not bring it back docked.
  E3  (V29) on its own with a Change box focused: the first Esc goes to the box (core's KeyFocusGuard lets go: KeyFocusLastLetGo
      "escape") and the panel stays open; the second Esc closes the panel; the screenshot and movement keys reach the game after each.
  E4  docked (opened with the character window): Esc closes the character window and the panel with it, and its open state is KEPT
      (unchanged: the next character window open docks it again).
  E5  strata: on its own the panel takes the strata of the game's standard windows, read from the character window (MEDIUM; LOW when
      the window says LOW), MEDIUM when the window gives none; docked, the window's strata as before.
  E6  the minimap list (core's own popup, XayaUI/MinimapButton.lua, opened through ns.Minimap_TogglePopupAt): the "Stat Calculator" row
      is there out of combat, is not there in a list opened in combat, and is there again in a list opened after combat.
Stand-ins: the game's Esc (ToggleGameMenu -> CloseAllWindows: the UIPanelWindows, here the character window, then CloseSpecialWindows)
is modeled in this file after UIParent.lua; in-game Esc order, stacking against the bags / map, and the list's look are UNVERIFIED IN
GAME. Negative control: on the base tree (64d0943) 11 of 24 run fail: E1 (2), E2 (3), E3's second Esc, E5 on its own (3), E6 in combat, Q (no walkthrough there, so its steps do not run);
E4 and E5 docked are guards (unchanged behavior) and pass there.
(Bonus 0.6.45, main: ported from qa-installer-branch; Q, the Dev Assist walkthrough check, is left out: no Dev Assist on main.)
Run: python3 tests/char_statcalc_esc_run.py   (Lua 5.1 via lupa; XUI_API_INDEX=tests/harness/api_index.json checks widget methods)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
if not rawget(_G, "CharacterFrame") then rawset(_G, "CharacterFrame", CreateFrame("Frame", "CharacterFrame", UIParent)) end
CharacterFrame:Hide(); CharacterFrame:SetFrameStrata("MEDIUM")
-- the game's Esc, after UIParent.lua: CloseSpecialWindows hides every shown frame named in UISpecialFrames; CloseAllWindows closes the
-- open UIPanelWindows (here the character window) first, then the special windows
local function CloseSpecialWindows()
  local found = false
  for _, name in pairs(UISpecialFrames) do
    local f = rawget(_G, name)
    if f and f.IsShown and f:IsShown() then f:Hide(); found = true end
  end
  return found
end
local function GameEsc()
  local ran = W.pressKey("ESCAPE")
  if ran ~= "game" or W.gameRan ~= "TOGGLEGAMEMENU" then return ran end
  local closed = false
  if CharacterFrame:IsShown() then CharacterFrame:Hide(); closed = true end
  closed = CloseSpecialWindows() or closed
  W.tick(0.1, 1)
  return "game", closed
end
local function keys(label)
  W.tick(0.02, 1)
  local n0 = #W.gameRanLog
  local a, b = W.pressKey("PRINTSCREEN"), W.pressKey("W")
  check(label .. ": PRINTSCREEN and W reach the game", a == "game" and b == "game" and W.gameRanLog[n0 + 1] == "SCREENSHOT" and W.gameRanLog[n0 + 2] == "MOVEFORWARD",
    tostring(a) .. " " .. tostring(b))
end

local sc = ns.Service("statCalc")
check("setup: the statCalc service is there", sc ~= nil)
if not sc then return R end
local c = sc.Cfg(); c.enabled, c.panel = true, true; ns.StatCalc_Apply()

-- E1 ---------------------------------------------------------------------------------------------------------------------------------
local before = {}
for i, n in ipairs(UISpecialFrames) do before[i] = n end
sc.Open("stats"); W.tick(0.1, 3)
local panel = rawget(_G, "XayaUIStatCalculator")
check("setup: the panel is open on its own (the character window closed)", panel ~= nil and panel:IsShown() and panel.standalone == true)
if not panel then return R end
local function count(name) local k = 0; for _, n in ipairs(UISpecialFrames) do if n == name then k = k + 1 end end; return k end
local added = {}
for i = #before + 1, #UISpecialFrames do added[#added + 1] = UISpecialFrames[i] end
check("E1 the panel's own name is in UISpecialFrames, once, and the Stat Calculator added nothing else", count("XayaUIStatCalculator") == 1 and #added == 1 and added[1] == "XayaUIStatCalculator",
  table.concat(added, ","))

-- E5 (on its own) ----------------------------------------------------------------------------------------------------------------------
check("E5 on its own: the standard windows' strata, read from the character window (MEDIUM; HIGH before A24 #8)", panel:GetFrameStrata() == "MEDIUM", panel:GetFrameStrata())
CharacterFrame:SetFrameStrata("LOW"); ns.StatCalc_Render()
check("E5 ...it follows the character window's strata (LOW)", panel:GetFrameStrata() == "LOW", panel:GetFrameStrata())
local rawGet = CharacterFrame.GetFrameStrata
CharacterFrame.GetFrameStrata = function() return nil end; ns.StatCalc_Render()
check("E5 ...MEDIUM when the window gives none", panel:GetFrameStrata() == "MEDIUM", panel:GetFrameStrata())
CharacterFrame.GetFrameStrata = nil; CharacterFrame:SetFrameStrata("MEDIUM"); ns.StatCalc_Render()

-- E2 ---------------------------------------------------------------------------------------------------------------------------------
local ran = GameEsc()
check("E2 on its own: Esc reaches the game's menu key (TOGGLEGAMEMENU) and closes the panel", ran == "game" and not panel:IsShown(), tostring(ran) .. " shown=" .. tostring(panel:IsShown()))
check("E2 ...as its close button: the open state is saved as closed", c.panelOpen == false, tostring(c.panelOpen))
CharacterFrame:Show(); W.tick(0.1, 3)
check("E2 ...so opening the character window afterwards does not bring it back docked", not panel:IsShown())
CharacterFrame:Hide(); W.tick(0.1, 1)
sc.Open("stats"); W.tick(0.1, 3)
check("E1 opened again: still once in UISpecialFrames", count("XayaUIStatCalculator") == 1, count("XayaUIStatCalculator"))

-- E3 (V29) ---------------------------------------------------------------------------------------------------------------------------
local box = sc.Drawn().boxes["sv:crit"]
check("E3 setup: on its own, the Critical Strike Change box drawn", panel:IsShown() and panel.standalone == true and box ~= nil and box:IsVisible())
if box then
  box:SetFocus(); W.now = W.now + 0.01
  W.pressKey("ESCAPE")
  local l = ns.KeyFocusLastLetGo and ns.KeyFocusLastLetGo()
  check("E3 first Esc with the box focused: the box lets go through core (KeyFocusLastLetGo 'escape') and the panel stays open",
    not box:HasFocus() and l and l.how == "escape" and panel:IsShown(), tostring(box:HasFocus()) .. " " .. tostring(l and l.how) .. " shown=" .. tostring(panel:IsShown()))
  keys("E3 after the first Esc")
  GameEsc()
  check("E3 second Esc: the panel closes", not panel:IsShown())
  keys("E3 after the second Esc")
end

-- E4 docked ----------------------------------------------------------------------------------------------------------------------------
sc.Close(); W.tick(0.1, 1)   -- (independent of E2 / E3: on the old tree Esc left the panel open)
CharacterFrame:Show(); sc.Open("stats"); W.tick(0.1, 3)
check("E4 setup: docked beside the open character window", panel:IsShown() and panel.standalone == false and c.panelOpen == true)
check("E5 docked: the character window's strata, as before", panel:GetFrameStrata() == "MEDIUM", panel:GetFrameStrata())
GameEsc()
check("E4 Esc: the character window and the docked panel close", not CharacterFrame:IsShown() and not panel:IsShown())
check("E4 ...its open state is kept (unchanged)", c.panelOpen == true, tostring(c.panelOpen))
CharacterFrame:Show(); W.tick(0.1, 3)
check("E4 ...the next character window open docks it again", panel:IsShown() and panel.standalone == false)
sc.Close(); CharacterFrame:Hide(); W.tick(0.1, 1)

-- E6 the minimap list ------------------------------------------------------------------------------------------------------------------
local anchor = CreateFrame("Button", nil, UIParent)
local function listRows()
  if type(ns.Minimap_TogglePopupAt) ~= "function" then return nil end
  ns.Minimap_TogglePopupAt(anchor)
  local p = rawget(_G, "XayaUIMinimapMenu")
  local out = {}
  if p and p:IsShown() then
    for _, b in ipairs(p.rows or {}) do if b:IsShown() and b.fs then out[#out + 1] = b.fs:GetText() end end
    ns.Minimap_TogglePopupAt(anchor)   -- close it again
  end
  return out
end
local function has(rows, t) for _, r in ipairs(rows or {}) do if r == t then return true end end; return false end
local r1 = listRows()
check("E6 out of combat: the minimap list has the Stat Calculator row", r1 ~= nil and has(r1, "Stat Calculator"), r1 and table.concat(r1, ", "))
W.enterCombat()
local r2 = listRows()
check("E6 a list opened in combat has no Stat Calculator row (the other rows stay)", r2 ~= nil and #r2 > 0 and not has(r2, "Stat Calculator"), r2 and table.concat(r2, ", "))
W.leaveCombat(); W.tick(0.1, 2)
local r3 = listRows()
check("E6 a list opened after combat has it again", r3 ~= nil and has(r3, "Stat Calculator"), r3 and table.concat(r3, ", "))

-- (Q, the in-game walkthrough "statcalc-esc-layer", is Dev Assist's: not on main, so left out of the main port; the in-game checks are
-- written steps in docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md)
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
