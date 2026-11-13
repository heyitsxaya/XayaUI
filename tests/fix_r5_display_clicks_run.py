#!/usr/bin/env python3
"""V27 release gate, mouse (Xaya 2026-11-10, REQUEST-LOG A23 SD-28, her words: "nothing impacts mouse ability to interact with (click,
toggle, use, etc) in-game objects, buttons, or screen panning once xui options window is closed"; SD-29, her answer: "Hover only, clicks
pass"). Round 5, gate fix "gate1": a rule display drawn by XayaUI (XayaUI_Rules/Visual.lua) took mouse clicks over the game world with the
settings window and the mover closed. Visual.lua turned the mouse off for a display without "Show tooltip on hover" and then, in the
same block, turned clicks back on (SetMouseClickEnabled(true)), so every such display caught the player's clicks and right-click camera
drags where it sat (the V27 mouse gate saw up to 40 at once, in and out of combat).

What the player gets, checked here (the game's mouse model is added on top of tests/harness/world.lua as tests/gate_common.py adds it:
EnableMouse sets clicks and motion together, SetMouseClickEnabled / SetMouseMotionEnabled set one; docs/reference/api/widgets.md:110,
283-284; that EnableMouse sets both is INFERENCE, not documented):
  A a shown display without the hover tooltip, mover closed, settings window closed: a click or a right-drag on it goes to the game
    (it takes no clicks) and it does not see the mouse at all; the same in a fight;
  B a shown display with "Show tooltip on hover": hovering it still shows its tooltip (kept, her answer), clicks still go to the game;
  C the mover (unlocked for moving): the display takes clicks again (a left click opens it in the rule editor, as before) and sees the
    mouse (its hover highlight); closed again, clicks go back to the game;
  D a display whose tooltip is switched off again: it lets go of the mouse completely (nothing left over from the tooltip).
Checks marked "(control)" pass on the old code too; every other check fails on the files before this change.
Run: python3 tests/fix_r5_display_clicks_run.py   (Lua 5.1 via lupa; loads XayaUI, XayaUI_Rules and XayaUI_Options in the stand-in game).
UNVERIFIED IN GAME: the stand-in's mouse model is not the game's."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()

-- the game's mouse model (as tests/gate_common.py): clicks and motion are two switches; EnableMouse sets both
local mt = getmetatable(UIParent)
local proto
for i = 1, 60 do local n, v = debug.getupvalue(mt.__index, i); if not n then break end; if n == "proto" then proto = v end end
assert(proto, "the stand-in's widget prototype was not found")
local CLICKS_BY_DEFAULT = { Button = true, CheckButton = true, EditBox = true, Slider = true }
function proto:EnableMouse(v) v = v and true or false; self._mouse, self._mclick, self._mmotion, self._mouseSet = v, v, v, true end
function proto:SetMouseClickEnabled(v) v = v and true or false
  if not self._mouseSet then self._mmotion = CLICKS_BY_DEFAULT[self._kind] or false end
  self._mclick, self._mouseSet = v, true; self._mouse = v or self._mmotion end
function proto:SetMouseMotionEnabled(v) v = v and true or false
  if not self._mouseSet then self._mclick = CLICKS_BY_DEFAULT[self._kind] or false end
  self._mmotion, self._mouseSet = v, true; self._mouse = v or self._mclick end
proto.EnableMouseMotion = proto.SetMouseMotionEnabled
function proto:IsMouseClickEnabled() if self._mouseSet then return self._mclick and true or false end return CLICKS_BY_DEFAULT[self._kind] or false end
function proto:IsMouseMotionEnabled() if self._mouseSet then return self._mmotion and true or false end return CLICKS_BY_DEFAULT[self._kind] or false end
function proto:IsMouseEnabled() return self:IsMouseClickEnabled() or self:IsMouseMotionEnabled() end
-- where a click lands: the display takes it, or it reaches the game (the world: target, loot, camera drag)
local function clickGoesTo(f) return (f:IsVisible() and f:IsMouseClickEnabled()) and "the display" or "the game" end
local function sees(f) return f:IsVisible() and f:IsMouseMotionEnabled() end

-- the two spells the rules watch are known and off cooldown (ready)
local KNOWN = { [400001] = true, [400041] = true }
local KN0 = C_SpellBook.IsSpellKnownOrInSpellBook
C_SpellBook.IsSpellKnownOrInSpellBook = function(id, bank, ov) if KNOWN[id] then return true end if KN0 then return KN0(id, bank, ov) end return false end
local IPS0 = IsPlayerSpell
IsPlayerSpell = function(id) if KNOWN[id] then return true end if IPS0 then return IPS0(id) end return false end
local CD0 = C_Spell.GetSpellCooldown
C_Spell.GetSpellCooldown = function(id)
  if KNOWN[id] then return { startTime = 0, duration = 0, isEnabled = true, modRate = 1, isActive = false, isOnGCD = false } end
  return CD0(id)
end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
check("(control) XayaUI Rules loaded", ns ~= nil and ns.NewRule ~= nil and ns.VisualFramesOf ~= nil)
if not (ns and ns.NewRule) then return end
MenuUtil.CreateContextMenu = function() end
local edited = {}
ns.EditRule = function(r) edited[#edited + 1] = r end   -- (the rule editor's entry: a left click on an unlocked display calls it)

-- two cooldown-ready icon displays drawn by XayaUI (what the gate saw: "Cooldown 1..4", 44x44, strata HIGH)
ns.rules = ns.rules or {}
local function cdRule(name, spell, tip)
  local r = ns.NewRule(); r.name = name; r.enabled = true
  r.useCooldown, r.spellID, r.cdState = true, spell, "ready"
  local v = r.visual
  v.enabled, v.kind, v.w, v.h = true, "spellicon", 44, 44
  v.trigger = "condition"; v.hoverTip = tip and true or false
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local plain = cdRule("Cooldown 1", 400001, false)
local hover = cdRule("Hover 1", 400041, true)
CueRulesDB.rules = ns.rules
if ns.MarkDirty then ns.MarkDirty() end
ENGINE_STEP(ns)
W.tick(0.1, 6)
local pf, hf = ns.VisualFramesOf(plain)[1], ns.VisualFramesOf(hover)[1]
check("(control) both displays are on screen (settings window and mover closed)", pf ~= nil and hf ~= nil and pf:IsVisible() and hf:IsVisible(),
  tostring(pf and pf:IsVisible()) .. " " .. tostring(hf and hf:IsVisible()))
if not (pf and hf) then return end
check("(control) the settings window is closed and the mover is closed", not (ns.WindowOpen and ns.WindowOpen()) and not ns.unlocked)

-- A. no tooltip: a click / right-drag over it reaches the game; it does not see the mouse
check("A1 a click or right-drag on a display without the hover tooltip goes to the game", clickGoesTo(pf) == "the game", clickGoesTo(pf))
check("(control) A2 that display does not see the mouse at all (nothing over the world takes the cursor)", not sees(pf), tostring(pf:IsMouseMotionEnabled()))
W.enterCombat(); W.tick(0.05, 4); ENGINE_STEP(ns); W.tick(0.05, 2)
check("A3 in a fight: a click on that display still goes to the game", pf:IsVisible() and clickGoesTo(pf) == "the game", clickGoesTo(pf))
W.leaveCombat(); W.tick(0.1, 4)
check("A4 after the fight: still goes to the game", clickGoesTo(pf) == "the game", clickGoesTo(pf))

-- B. "Show tooltip on hover": hover kept, clicks pass
check("(control) B1 a display with the hover tooltip: a click on it goes to the game", clickGoesTo(hf) == "the game", clickGoesTo(hf))
check("(control) B2 it sees the mouse, so hovering it can show the tooltip", sees(hf), tostring(hf:IsMouseMotionEnabled()))
local shown = false
local realShow = ns.ShowCueTooltip
ns.ShowCueTooltip = function(r, f) if r == hover then shown = true end end
local onEnter = hf:GetScript("OnEnter"); if onEnter then onEnter(hf) end
ns.ShowCueTooltip = realShow
check("(control) B3 hovering it shows its tooltip", shown)

-- C. the mover: clicks on (click opens the editor), hover highlight; closed again: clicks pass
-- (bundle 1 round 7, SD-58) the movement unlocks are XayaUI Options' and work only while the settings window is open: its code is loaded
-- and the window counts as open, as the window's driver says when it shows (not drawn here)
ns.LoadOptions(); ns.SetWindowOpen(true)
ns.SetMoveUnlocked({ plain }, true); W.tick(0.1, 3)
pf = ns.VisualFramesOf(plain)[1]
check("(control) C1 unlocked for moving: the display takes clicks (click, right-click menu, drag)", pf:IsVisible() and clickGoesTo(pf) == "the display", clickGoesTo(pf))
check("(control) C2 unlocked for moving: it sees the mouse (its hover highlight)", sees(pf))
W.click(pf, "LeftButton")
check("(control) C3 unlocked: a left click opens it in the rule editor, as before", edited[#edited] == plain, tostring(#edited))
ns.SetMoveUnlocked({ plain }, false); W.tick(0.1, 3)
pf = ns.VisualFramesOf(plain)[1]
check("C4 the mover closed again: a click on the display goes to the game", pf:IsVisible() and clickGoesTo(pf) == "the game", clickGoesTo(pf))
check("(control) C5 the mover closed again: it does not see the mouse", not sees(pf), tostring(pf:IsMouseMotionEnabled()))

-- D. the tooltip switched off again: nothing of it is left
hover.visual.hoverTip = false
ns.RefreshVisual(hover); W.tick(0.1, 3)
hf = ns.VisualFramesOf(hover)[1]
check("D1 hover tooltip switched off: a click on that display goes to the game", hf:IsVisible() and clickGoesTo(hf) == "the game", clickGoesTo(hf))
check("(control) D2 hover tooltip switched off: it does not see the mouse any more", not sees(hf), tostring(hf:IsMouseMotionEnabled()))

end)
if not okAll then check("the test ran without a Lua error", false, errAll) end
return R
end
'''

# (round 7 repair) the engine no longer exports ns.Step: one full engine step is reached through tests/engine_bench.py's helper
_BENCH = open(os.path.join(HERE, "engine_bench.py"), encoding="utf-8").read()
ENGINE_STEP_LUA = _BENCH[_BENCH.index("-- [engine-step helper]"):_BENCH.index("-- [/engine-step helper]")]
LUA = LUA.replace("return function(W, L)\n", "return function(W, L)\n" + ENGINE_STEP_LUA, 1)


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
