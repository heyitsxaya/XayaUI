#!/usr/bin/env python3
"""Stat Calculator: the screenshot key and a movement key reach the game (V29 release condition; gate findings G-022 / G-004, G-024,
G-023; Xaya, SD-3: "I STILL cannot take screenshots in the game ... these sorts of bugs cannot ever happen again").
On the whole-addon harness (tests/harness: every addon loaded as the game loads them, with the REAL core XayaUI/KeyCatch.lua and its
ns.KeyFocusGuard), the Stat Calculator on, the character window open and the panel docked beside it. After every step PRINTSCREEN
(bound to SCREENSHOT) and W (bound to MOVEFORWARD) are pressed (W.pressKey) and must reach the game (W.gameRanLog):
  K0  core's ns.KeyFocusGuard is there (a missing guard is a failure here, never skipped silently).
  K1  the panel open, nothing focused.
  K2  the Critical Strike Change box (sv:crit) focused out of combat: it takes the keys while focused (typing); it lets go after Enter
      (core's Enter, enterLetsGo: KeyFocusLastLetGo says "enter"), after Esc (core's own Esc: "escape"), after a click outside
      (GLOBAL_MOUSE_DOWN: "click").
  K3  combat starts (PLAYER_REGEN_DISABLED) with the box focused: the box has let go BEFORE the panel hides (the module's own
      EnterCombat loop, whatever core's hide hook does); both keys reach the game in combat; after combat (PLAYER_REGEN_ENABLED) the
      panel reopens docked and the keys still reach the game.
  K4  the box focused, then the panel closed (its close): the box lets go; the box focused, then the character window closed: the
      docked panel hides with it and the box lets go; both keys reach the game after each.
  K5  K2-K4 again for the Gear tab's item box.
  K6  ADDON_RESTRICTION_STATE_CHANGED (type Encounter 1, state Active 2; events.md:37, enums.md:485) with a box focused: the box lets go
      (gate G-023); an Inactive (0) state does not take the box away from a player typing.
  K7  (round 2) Enter pressed through the real key path still commits the typed amount, and the box lets go.
Negative controls: on the tree at 5695993 (before this fix) 8 of 45 fail: K2 and K5 Enter / Esc (the box let go through its own
scripts, not core's guard: no "enter" / "escape"), and K6 (no restriction handling: the box keeps the keyboard, the keys do not reach
the game). With the EnterCombat ClearFocus loop removed, K3 "let go before the panel hides" fails for both boxes (2 of 45).
CORE DEPENDENCY: this runs against this branch's core (XayaUI/KeyCatch.lua), which is older than main's KeyCatch / KeyFocusGuard fix
bundle. Run it again once that bundle is on this branch. The harness is a stand-in for the game: in-game key routing, focus and
restriction events are UNVERIFIED IN GAME.
Run: python3 tests/statcalc_keys_run.py   (Lua 5.1 via lupa; XUI_API_INDEX=tests/harness/api_index.json checks widget methods)"""
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
CharacterFrame:Hide()
local sc = ns.Service("statCalc")
check("K0 core's ns.KeyFocusGuard is there (the boxes' keyboard guard; V29)", type(ns.KeyFocusGuard) == "function" and type(ns.KeyFocusLastLetGo) == "function")
check("setup: the statCalc service is there", sc ~= nil)
if not sc then return R end
local c = sc.Cfg(); c.enabled, c.panel = true, true; ns.StatCalc_Apply()
CharacterFrame:Show()
sc.Open("stats"); W.tick(0.1, 3)
local panel = rawget(_G, "XayaUIStatCalculator")
check("setup: the panel is open, docked beside the open character window", panel ~= nil and panel:IsShown() and panel.standalone == false)
if not panel then return R end

local function keys(label)
  W.tick(0.02, 1)
  local n0 = #W.gameRanLog
  local a, b = W.pressKey("PRINTSCREEN"), W.pressKey("W")
  local got = {}
  for i = n0 + 1, #W.gameRanLog do got[#got + 1] = W.gameRanLog[i] end
  check(label .. ": PRINTSCREEN and W reach the game (screenshot, move forward)", a == "game" and b == "game" and got[1] == "SCREENSHOT" and got[2] == "MOVEFORWARD",
    tostring(a) .. " " .. tostring(b) .. " " .. table.concat(got, ","))
end
local function lastHow() local l = ns.KeyFocusLastLetGo and ns.KeyFocusLastLetGo(); return l and l.how end
local function stamp() W.now = W.now + 0.01 end
-- the panel is told to hide: record whether a box still had the keyboard at that moment, before any OnHide hook (core's window hook
-- included) runs (K3: the module lets go first, whatever core's hide hook does)
local focusAtHide
local rawHide = panel.Hide
panel.Hide = function(self, ...)
  local f = false; for _, eb in pairs(sc.Drawn().boxes) do if eb:HasFocus() then f = true end end; focusAtHide = f
  return rawHide(self, ...)
end

local function walkBox(tag, tab, key)
  c.tab = tab; ns.StatCalc_Render(); W.tick(0.1, 2)
  local box = sc.Drawn().boxes[key]
  check(tag .. " setup: the " .. key .. " box is drawn on the " .. tab .. " tab", box ~= nil and box:IsVisible())
  if not box then return end
  keys(tag .. " the panel open, nothing focused")
  -- typing: the focused box takes the keys (the player is typing into it)
  box:SetFocus()
  check(tag .. " focused: the box takes the keys while the player types", W.pressKey("PRINTSCREEN") == box)
  -- Enter
  stamp(); W.pressKey("ENTER"); W.tick(0.1, 1)
  check(tag .. " Enter: the box lets go of the keyboard through core (KeyFocusLastLetGo 'enter')", not box:HasFocus() and lastHow() == "enter", tostring(box:HasFocus()) .. " " .. tostring(lastHow()))
  keys(tag .. " after Enter")
  box = sc.Drawn().boxes[key]
  -- Esc
  box:SetFocus(); stamp(); W.pressKey("ESCAPE")
  check(tag .. " Esc: the box lets go through core's own Esc (KeyFocusLastLetGo 'escape')", not box:HasFocus() and lastHow() == "escape", tostring(box:HasFocus()) .. " " .. tostring(lastHow()))
  keys(tag .. " after Esc")
  -- a click outside
  box:SetFocus(); stamp(); W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
  check(tag .. " a click outside (GLOBAL_MOUSE_DOWN): the box lets go ('click')", not box:HasFocus() and lastHow() == "click", tostring(box:HasFocus()) .. " " .. tostring(lastHow()))
  keys(tag .. " after a click outside")
  -- combat with the box focused
  box:SetFocus(); focusAtHide = nil
  W.enterCombat()
  check(tag .. " combat starts with the box focused: it has let go before the panel hides (the module's own loop)", focusAtHide == false and not box:HasFocus(), tostring(focusAtHide))
  check(tag .. "   ...the panel is hidden in combat (V26 hide silently)", not panel:IsShown())
  keys(tag .. " in combat")
  W.leaveCombat(); W.tick(0.1, 3)
  check(tag .. " combat ends: the panel reopens docked", panel:IsShown())
  keys(tag .. " after combat, the panel back")
  -- the panel closed with the box focused
  box = sc.Drawn().boxes[key]
  box:SetFocus(); sc.Close(); W.tick(0.1, 1)
  check(tag .. " the panel closed with the box focused: the box lets go", not panel:IsShown() and not box:HasFocus())
  keys(tag .. " after closing the panel")
  -- the character window closed with the box focused (the docked panel closes with it)
  sc.Open(tab); W.tick(0.1, 2)
  box = sc.Drawn().boxes[key]
  box:SetFocus(); CharacterFrame:Hide(); W.tick(0.1, 1)
  check(tag .. " the character window closed with the box focused: the panel hides and the box lets go", not panel:IsShown() and not box:HasFocus())
  keys(tag .. " after closing the character window")
  CharacterFrame:Show(); W.tick(0.1, 2)
  if not panel:IsShown() then sc.Open(tab); W.tick(0.1, 2) end
end

walkBox("K2-K4 (Critical Strike's Change box)", "stats", "sv:crit")
walkBox("K5 (the Gear tab's item box)", "gear", "item")

-- K6 an addon restriction (Mythic+ / encounter / PvP) becomes active with a box focused
c.tab = "stats"; ns.StatCalc_Render(); W.tick(0.1, 2)
local box = sc.Drawn().boxes["sv:crit"]
check("K6 setup: the panel is open with the Critical Strike box", panel:IsShown() and box ~= nil)
if box then
  box:SetFocus()
  W.fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
  check("K6 a restriction reported Inactive (0): the player keeps typing (the box keeps the keyboard)", box:HasFocus())
  W.fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 2)
  check("K6 a restriction becomes Active (Encounter, 2): the box lets go of the keyboard (gate G-023)", not box:HasFocus())
  keys("K6 with the restriction active")
  box:SetFocus()
  W.fire("ADDON_RESTRICTION_STATE_CHANGED", 4, 1)
  check("K6 ...also while it is Activating (1)", not box:HasFocus())
  keys("K6 after Activating")
end

-- K7 (round 2) Enter through the real key path still commits the typed amount: the box's OnEnterPressed no longer lets go itself and
-- core's enterLetsGo runs after it; the value must be set before the box lets go
c.tab = "stats"; ns.StatCalc_Render(); W.tick(0.1, 2)
box = sc.Drawn().boxes["sv:crit"]
c.whatIfStats = c.whatIfStats or {}
local was = c.whatIfStats.crit or 0
local shown = box and tonumber(box:GetText())
check("K7 setup: the Critical Strike box shows a number", shown ~= nil, box and box:GetText())
if shown then
  box:SetFocus(); box:SetText(tostring(shown + 120)); stamp(); W.pressKey("ENTER"); W.tick(0.1, 2)
  check("K7 Enter (core's key path): the typed amount is committed (+120 over what the box showed)", (c.whatIfStats.crit or 0) == was + 120, tostring(was) .. " -> " .. tostring(c.whatIfStats.crit))
  check("K7 ...and the box has let go", not sc.Drawn().boxes["sv:crit"]:HasFocus())
  keys("K7 after Enter commits")
  ns.StatCalc_SetInput("crit", tostring(was))
end
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
