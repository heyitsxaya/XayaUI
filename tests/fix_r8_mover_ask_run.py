#!/usr/bin/env python3
"""Bundle 1 round 8: unsaved mover moves are asked about when the settings window next opens.
Her answer, REQUEST-LOG A23 SD-68, verbatim: mover unsaved moves: "Ask on next settings open (Recommended)". Recorded as: no login
question; when settings next opens with unsaved moves, one question: Save / Discard / Keep editing. Combat stays as SD-15 decided
("Keep, resume after": the mover reopens with its moves when the window reopens after the fight). V26 (combat lock), V27 (mouse and
keyboard untouched once the window is closed), V28 (window closed, no editing code runs), V29 (keys reach the game).
What the player sees or gets, on the real addons in the stand-in game (tests/harness):
  Q1  a move, then the window closed by hand: one line says the move is kept and she will be asked; nothing asks now; the displays let
      the mouse through.
  Q2  the window opens: one question, "Save" / "Discard" / "Keep editing" in that order, with the number of moves; the mover does NOT
      open by itself (before: it was forced open at every opening until saved or cancelled).
  Q3  Save: the moves stay, the draft is gone, the mover stays closed; the next opening asks nothing.
  Q4  Discard: every display and group goes back (saved numbers and on screen); the draft is gone.
  Q5  Keep editing: the mover opens with the moves (draft kept).
  Q6  ask once: the question closed alone (Escape on it) decides nothing and is not asked again while the window stays open; the
      next opening asks again.
  Q7  Escape the game's way (the key reaches the game, which closes the open special frames and the settings window): nothing decided,
      the displays let the mouse through; the next opening asks again.
  Q8  closing settings while the question is open: the question goes, nothing decided; a click that still reaches a choice changes nothing.
  Q9  combat while the question is open: the window and the question close, nothing decided, a choice in combat changes nothing; after
      combat the window reopens and asks again (the mover is not forced open).
  Q10 SD-15 unchanged: the mover open with a move when combat starts closes; after combat the window reopens with the mover on and the
      move, and nothing asks.
  Q11 /xui unlock with unsaved moves and the window closed: the window opens with the question, not the mover; the Lock Positions
      name (ns.ToggleUnlock) while the question shows opens the mover with the moves and the question goes.
  Q12 /xui disable with the mover open and a move, then the window closed by hand, /xui enable, the window opened: the question (before:
      the mover forced open). The window opened while rules are off asks nothing; /xui enable then asks.
  Q13 V29: while the question shows, the screenshot key and a movement key reach the game.
  Q14 after a /reload with an unsaved move: at login nothing asks and none of the mover is read; the first opening asks; Discard puts
      the display back.
Fails on the files before this change (copy of the pre-change Mover.lua): Q2, Q3, Q4, Q5, Q6, Q7, Q8, Q9, Q11, Q12, Q13, Q14 (the window
opening forced the mover open and nothing asked). Checks marked "(control)" pass on the old files too.
Escape in the game (INFERENCE, Blizzard's own FrameXML, not in docs/reference/api): an unkept Escape runs the game menu toggle, which
closes every shown frame named in UISpecialFrames (the ask dialog is one) and, through AceConfigDialog's own CloseSpecialWindows wrapper
(XayaUI_Options/Libs/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua), the settings window. UNVERIFIED IN GAME.
Run: python3 tests/fix_r8_mover_ask_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L, mode)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if not ns then check("(control) XayaUI loaded", false); return R end
MenuUtil.CreateContextMenu = function() end
local said = {}
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end
local function mark() return #said end
local function since(m) local t = {}; for i = m + 1, #said do t[#t + 1] = said[i] end; return t end
local function has(list, pat) for _, l in ipairs(list) do if l:lower():find(pat, 1, true) then return true end end; return false end
local function joined(list) return table.concat(list, " / ") end
local function slash(s) SlashCmdList.XAYAUI(s); W.tick(0.1, 4) end
local function optionsLoaded() return C_AddOns.IsAddOnLoaded("XayaUI_Options") and true or false end
local function windowOpen() return (ns.IsOptionsOpen and ns.IsOptionsOpen()) and true or false end
local function openWindow() if not windowOpen() then ns.ToggleUI(); W.tick(0.1, 4) end end
local function closeWindow() if windowOpen() then ns.ToggleUI(); W.tick(0.1, 4) end end
local function draft() return ns.Settings("core").moverDraft end
local function askFrame() return rawget(_G, "XayaUIThemeAsk") end
local function asking() local f = askFrame(); return f ~= nil and f:IsShown() and (f.text:GetText() or ""):find("unsaved move", 1, true) ~= nil end
local function askText() local f = askFrame(); return f and f:IsShown() and f.text:GetText() or "(no question)" end
local function btn(i) local f = askFrame(); return f and f.btns and f.btns[i] end
local function click(i) local b = btn(i); if b and b:IsShown() and askFrame():IsShown() then W.click(b); W.tick(0.1, 2) end end
-- a click that still reaches a choice after its dialog was hidden (the button's own script, as a late click would run it)
local function staleClick(i) local b = btn(i); local s = b and b:GetScript("OnClick"); if s then s(b, "LeftButton", false); W.tick(0.1, 2) end end
local function moves() return ns.MoverChanges and #ns.MoverChanges() or -1 end

if mode == "reload" then
  -------------------------------------------------------------------------------------------------------------------------------------
  -- Q14. the session after a /reload with an unsaved move
  -------------------------------------------------------------------------------------------------------------------------------------
  local A
  for _, r in ipairs(ns.rules or {}) do if r.name == "Ask A" then A = r end end
  check("(control) Q14 the moved display's rule is in the saved data", A ~= nil)
  if not A then return R end
  check("Q14 at login: nothing asks and none of the mover is read (the settings window's code is not loaded)",
    askFrame() == nil and W.popup == nil and not optionsLoaded() and not ns.unlocked, tostring(optionsLoaded()))
  check("(control) Q14 the display keeps the moved position (saved), and the draft is kept", A.visual.x == -48 and type(draft()) == "table",
    tostring(A.visual.x))
  section("Q14", function()
    openWindow()
    check("Q14 the first opening of the settings window asks about the move; the mover stays closed",
      windowOpen() and asking() and ns.unlocked ~= true and askText():find("1 unsaved move", 1, true) ~= nil, askText())
    click(2)
    check("Q14 Discard puts the display back and deletes the draft", A.visual.x == -60 and draft() == nil and not asking()
      and ns.unlocked ~= true, tostring(A.visual.x))
  end)
  check("Q14 no Lua error in the stand-in", #W.errors == 0, W.errors[1])
  return R
end

local f = ns.NewFolder("Ask group")
f.cX, f.cY = 100, 50
local function mk(name, x, y)
  local r = ns.NewRule(); r.name = name; r.folder = f.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.size = 40
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local A, B = mk("Ask A", -60, 0), mk("Ask B", 60, 0)
ns.RefreshAllVisuals(); W.tick(0.1, 2)
local function takesMouse(r) local fr = ns.DisplayFrame(r); return fr ~= nil and fr:IsShown() and fr:IsMouseEnabled() end
local function left(r) local fr = ns.DisplayFrame(r); return fr and fr:GetLeft() end

-- one display moved 7 pixels right and the group moved 4 pixels right in the mover, then the window closed by hand (2 moves)
local function pending()
  closeWindow()
  if asking() then askFrame():Hide() end
  slash("unlock")
  ns.MoverSelect("display", A); ns.MoverNudge(7, 0)
  ns.MoverSelect("group", f); ns.MoverNudge(4, 0)
  W.tick(0.05, 2)
  local m = mark()
  closeWindow()
  return since(m)
end
local function isPending() return A.visual.x == -53 and f.cX == 104 and type(draft()) == "table" and moves() == 2 end
local function state() return ("x=%s cX=%s draft=%s moves=%s mover=%s window=%s ask=%s"):format(tostring(A.visual.x), tostring(f.cX),
  tostring(draft() ~= nil), tostring(moves()), tostring(ns.unlocked), tostring(windowOpen()), tostring(asking())) end
local function cleanUp()
  if asking() then click(2) end
  if ns.unlocked and ns.MoverExit then ns.MoverExit("cancel"); W.tick(0.05, 2) end
  closeWindow()
  if draft() and ns.MoverChanges and moves() > 0 then openWindow(); if asking() then click(2) end; closeWindow() end
end

section("Q1-Q3", function()
  local got = pending()
  check("Q1 a move, then the window closed by hand: one line says the moves are kept and she will be asked at the next opening",
    #got == 1 and has(got, "2 unsaved move") and has(got, "asked") and has(got, "settings window"), joined(got))
  check("(control) Q1 nothing asks at the close; the moves stay (saved numbers) and in the draft; the displays let the mouse through",
    isPending() and not asking() and W.popup == nil and not windowOpen() and not ns.unlocked and not takesMouse(A) and not takesMouse(B), state())
  openWindow()
  check("Q2 the window opens: one question with the number of moves", windowOpen() and asking() and askText():find("2 unsaved move", 1, true) ~= nil,
    askText())
  local b1, b2, b3 = btn(1), btn(2), btn(3)
  check("Q2 its buttons are Save / Discard / Keep editing, in that order", b1 and b2 and b3 and b1:IsShown() and b2:IsShown() and b3:IsShown()
    and b1:GetText() == "Save" and b2:GetText() == "Discard" and b3:GetText() == "Keep editing",
    b1 and ("%s / %s / %s"):format(tostring(b1:GetText()), tostring(b2:GetText()), tostring(b3:GetText())))
  check("Q2 the mover does not open by itself (the displays are not draggable samples; no arrow-key frame)",
    ns.unlocked ~= true and not takesMouse(A) and not (rawget(_G, "XayaUIMoverKeys") and XayaUIMoverKeys:IsShown()), state())
  local m = mark()
  click(1)
  check("Q3 Save: the moves stay, the draft is gone, the question closes and the mover stays closed",
    A.visual.x == -53 and f.cX == 104 and draft() == nil and not asking() and ns.unlocked ~= true and windowOpen(), state())
  check("Q3 one line says the moves are saved", has(since(m), "2 move(s) are saved"), joined(since(m)))
  closeWindow(); openWindow()
  check("Q3 the next opening asks nothing", not asking() and ns.unlocked ~= true, state())
  closeWindow()
  A.visual.x = -60; f.cX = 100; ns.RefreshAllVisuals(); if ns.GroupFrame then pcall(ns.GroupFrame, f) end; W.tick(0.05, 2)
end)

section("Q4", function()
  slash("unlock")
  local l0 = left(A)
  if ns.unlocked then ns.ToggleUnlock(); W.tick(0.05, 2) end
  closeWindow()
  pending()
  local l1 = left(A)
  openWindow()
  local m = mark()
  click(2)
  check("Q4 Discard: the display and the group go back (saved numbers), the draft is gone, the question closes",
    A.visual.x == -60 and f.cX == 100 and draft() == nil and not asking() and ns.unlocked ~= true, state())
  check("Q4 ...and the display is back on screen", l0 ~= nil and l1 ~= nil and math.abs((left(A) or 0) - l0) < 0.5 and l1 > l0 + 0.5,
    ("before=%s moved=%s now=%s"):format(tostring(l0), tostring(l1), tostring(left(A))))
  check("Q4 one line says the moves were discarded", has(since(m), "discarded"), joined(since(m)))
  closeWindow()
end)

section("Q5", function()
  pending()
  openWindow()
  local m = mark()
  click(3)
  check("Q5 Keep editing: the mover opens with the moves (draft kept), the question closes",
    ns.unlocked == true and isPending() and takesMouse(A) and not asking() and XayaUIMoverKeys:IsShown(), state())
  check("Q5 one line says the mover is open again with the moves", has(since(m), "2 unsaved move"), joined(since(m)))
  cleanUp()
end)

section("Q6", function()
  pending()
  openWindow()
  check("(control) Q6 setup: the question shows", asking(), state())
  if askFrame() then askFrame():Hide() end   -- Escape on the question alone (it is a special frame: Escape hides it, running nothing)
  W.tick(0.1, 6)
  check("Q6 the question closed alone decides nothing: the moves stay on screen and in the draft, the mover stays closed",
    isPending() and not asking() and ns.unlocked ~= true and windowOpen(), state())
  check("Q6 it is asked once: not again while the window stays open", not asking(), state())
  closeWindow(); openWindow()
  check("Q6 the next opening asks again", asking() and isPending(), state())
  cleanUp()
end)

section("Q7", function()
  pending()
  openWindow()
  check("(control) Q7 setup: the question shows", asking(), state())
  -- the game's Escape: no XayaUI frame keeps the key; the game closes the shown special frames and AceConfigDialog closes its windows
  local where = W.pressKey("ESCAPE")
  check("Q7 Escape is not kept by the question (it reaches the game)", where == "game", tostring(where))
  for _, n in ipairs(UISpecialFrames) do local fr = rawget(_G, n); if fr and fr.IsShown and fr:IsShown() then fr:Hide() end end
  -- what AceConfigDialog's CloseSpecialWindows wrapper adds (its own CloseAll; the stand-in's CloseSpecialWindows is a bare stub)
  local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
  if ACD then ACD:CloseAll() end
  W.tick(0.1, 6)
  check("Q7 Escape closes the question and the settings window and decides nothing", not windowOpen() and not asking() and isPending()
    and ns.unlocked ~= true, state())
  check("Q7 the displays let the mouse through (V27)", not takesMouse(A) and not takesMouse(B), state())
  openWindow()
  check("Q7 the next opening asks again", asking() and isPending(), state())
  cleanUp()
end)

section("Q8", function()
  pending()
  openWindow()
  check("(control) Q8 setup: the question shows", asking(), state())
  closeWindow()
  check("Q8 closing the settings window closes the question and decides nothing (V28)", not asking() and not (askFrame() and askFrame():IsShown())
    and isPending() and ns.unlocked ~= true, state())
  staleClick(2); staleClick(1); staleClick(3)
  check("Q8 a click that still reaches Discard, Save or Keep editing after the close changes nothing", isPending() and ns.unlocked ~= true
    and not windowOpen(), state())
  check("Q8 the displays let the mouse through (V27)", not takesMouse(A) and not takesMouse(B), state())
  cleanUp()
end)

section("Q9", function()
  pending()
  openWindow()
  check("(control) Q9 setup: the question shows", asking(), state())
  W.enterCombat(); W.tick(0.05, 2)
  check("Q9 combat closes the settings window and the question; nothing decided", not windowOpen() and not asking() and isPending()
    and ns.unlocked ~= true, state())
  staleClick(2); staleClick(3)
  check("Q9 a choice that still reaches the code in combat changes nothing (V26)", isPending() and ns.unlocked ~= true, state())
  W.leaveCombat(); W.tick(0.1, 6)
  check("Q9 after combat the window reopens and asks again; the mover is not forced open", windowOpen() and asking() and isPending()
    and ns.unlocked ~= true, state())
  cleanUp()
end)

-- combat start in the game's order as inferred (INFERENCE, unverified in game): when PLAYER_REGEN_DISABLED fires the lockdown has not
-- begun but UnitAffectingCombat("player") is already true. The stand-in sets its one combat flag only after the event.
local function gameCombatStart()
  local uac = UnitAffectingCombat
  UnitAffectingCombat = function() return true end
  W.enterCombat()
  UnitAffectingCombat = uac
  W.tick(0.05, 2)
end
section("Q10", function()
  closeWindow()
  slash("unlock")
  ns.MoverSelect("display", A); ns.MoverNudge(7, 0); W.tick(0.05, 2)
  gameCombatStart()
  check("(control) Q10 SD-15: combat closes the window and the mover; the move stays", not windowOpen() and ns.unlocked ~= true
    and A.visual.x == -53 and not asking(), state())
  W.leaveCombat(); W.tick(0.1, 6)
  check("Q10 SD-15 unchanged: after combat the window reopens with the mover on and the move, and nothing asks", windowOpen()
    and ns.unlocked == true and A.visual.x == -53 and not asking(), state())
  cleanUp()
end)
-- Q10b: the same with the combat flag not yet set at the event (the stand-in's order): only the window's own combat-start close telling
-- the mover (Options.lua Tree.CombatStart calling ns.MoverWindowClosingForCombat) can tell it from a close by hand
section("Q10b", function()
  closeWindow()
  slash("unlock")
  ns.MoverSelect("display", A); ns.MoverNudge(7, 0); W.tick(0.05, 2)
  W.enterCombat(); W.tick(0.05, 2)
  W.leaveCombat(); W.tick(0.1, 6)
  -- (round 9: the Options.lua hook is in, so this counts like every other check; it was shown as SKIP until then)
  check("Q10b SD-15 with the combat flag set only after the event: the mover reopens with the move after combat, nothing asks",
    windowOpen() and ns.unlocked == true and A.visual.x == -53 and not asking(), state())
  cleanUp()
end)

section("Q11", function()
  pending()
  slash("unlock")
  check("Q11 /xui unlock with unsaved moves: the window opens with the question, not the mover", windowOpen() and asking()
    and ns.unlocked ~= true and isPending(), state())
  ns.ToggleUnlock(); W.tick(0.05, 2)
  check("Q11 the Lock Positions name while the question shows: the mover opens with the moves and the question goes",
    ns.unlocked == true and isPending() and not asking(), state())
  cleanUp()
end)

section("Q12", function()
  closeWindow()
  slash("unlock")
  ns.MoverSelect("display", A); ns.MoverNudge(7, 0); W.tick(0.05, 2)
  slash("disable")
  check("(control) Q12 setup: /xui disable closes the mover; the move stays", ns.RulesDisabled == true and ns.unlocked ~= true
    and A.visual.x == -53, state())
  closeWindow()
  slash("enable")
  openWindow()
  check("Q12 /xui disable, the window closed by hand, /xui enable, the window opened: the question, the mover not forced open",
    windowOpen() and asking() and ns.unlocked ~= true and A.visual.x == -53, state())
  click(2)
  check("(control) Q12 Discard puts it back", A.visual.x == -60 and draft() == nil, state())
  closeWindow()
  pending()
  slash("disable")
  openWindow()
  check("Q12 the window opened while rules are off asks nothing", windowOpen() and not asking() and ns.unlocked ~= true, state())
  slash("enable")
  check("Q12 ...and /xui enable asks then", windowOpen() and asking() and ns.unlocked ~= true and isPending(), state())
  cleanUp()
end)

section("Q13", function()
  pending()
  openWindow()
  check("(control) Q13 setup: the question shows", asking(), state())
  local shot, move = W.pressKey("PRINTSCREEN"), W.pressKey("W")
  check("Q13 V29: with the question showing, the screenshot key and a movement key reach the game", shot == "game" and move == "game",
    tostring(shot) .. " " .. tostring(move))
  cleanUp()
end)

-- for Q14: a move left unsaved when the session ends (the mover open, the window open: a /reload)
section("Q14 setup", function()
  closeWindow()
  slash("unlock")
  ns.MoverSelect("display", A); ns.MoverNudge(12, 0); W.tick(0.05, 2)
  check("(control) Q14 setup: the mover is open with one unsaved move when the session ends", ns.unlocked == true and A.visual.x == -48
    and moves() == 1, state())
end)
check("no Lua error in the stand-in", #W.errors == 0, W.errors[1])
return R
end
'''


def session(mode, saved_src):
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    sv = H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    opts["saved"] = sv.Load(saved_src) if saved_src else H.to_lua(L, {})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)
    out = [(str(res[i][1]), bool(res[i][2]), res[i][3]) for i in range(1, len(res) + 1)]
    src = None
    if mode == "play":
        saved, _issues = loader.logout()
        src = sv.Serialize(saved)
    return out, src


def main():
    results, src = session("play", None)
    if src:
        again, _ = session("reload", src)
        results += again
    bad, counted = 0, 0
    for name, good, _tag in results:
        counted += 1
        print(("PASS " if good else "FAIL ") + name)
        bad += 0 if good else 1
    print("%d checks, %d failed" % (counted, bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
