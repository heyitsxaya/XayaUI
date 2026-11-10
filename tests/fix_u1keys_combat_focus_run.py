#!/usr/bin/env python3
"""Keys stay hers when a fight starts (rules review 2026-11-10, docs/plans/RULES-REVIEW-2026-11-10.md, unit U1-keys: R1, R22, R23, R25).

What she sees:
  R1  the mover view (/xui unlock), the settings window or the version pane opened for the first time in combat: movement (W) and the
      screenshot key (PRINTSCREEN) still reach the game; once the fight ends the window's own keys (an arrow, Delete, Esc) work as before.
  R22 a click on the debug report's summary text does not take the keyboard: PRINTSCREEN (the screenshot the hint asks for) still works.
  R23 a XayaUI text box that has the keyboard lets go when combat starts; the bug-report copy box and the import window opened in
      combat do not take it.
  R25 Esc in the rule search box clears it and the box stays without the keyboard (it took the focus back after the filter rebuild).

The stand-in game (tests/harness/world.lua) is given two game rules here, for this test only:
  * setting or hooking an OnKeyDown script switches the frame's keyboard on (INFERENCE, as the review: AceGUI's Keybinding widget
    calls EnableKeyboard(false) right after setting one; the harness only switches it on through EnableKeyboard);
  * an EditBox takes the mouse unless EnableMouse(false) (INFERENCE: the game's default), and a click on it gives it the keyboard.
Each check fails on the code before this fix, except those marked "(regression)".
Run: python3 tests/fix_u1keys_combat_focus_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
-- (A23 SD-12) the game's focus scripts, for core KeyCatch.lua (it listens for clicks only while a guarded box has the keyboard):
-- SetFocus / ClearFocus run OnEditFocusGained / OnEditFocusLost and one box has the keyboard (the stand-in runs no script; INFERENCE as
-- in tests/fix_r2_closed_window_quiet_run.py)
do
  local P
  local idx = getmetatable(CreateFrame("Frame")).__index
  for i = 1, 50 do local n, v = debug.getupvalue(idx, i); if not n then break end; if n == "proto" then P = v end end
  local cur
  function P:SetFocus()
    if cur == self then return end
    local prev = cur
    cur = self
    if prev and prev._focus then prev._focus = false; local f = prev._scripts.OnEditFocusLost; if f then f(prev) end end
    self._focus = true
    local g = self._scripts.OnEditFocusGained; if g then g(self) end
  end
  function P:ClearFocus()
    if not self._focus then return end
    self._focus = false
    if cur == self then cur = nil end
    local f = self._scripts.OnEditFocusLost; if f then f(self) end
  end
end
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function who(x) if x == "game" then return "game" end if type(x) == "table" then return (x.GetName and x:GetName()) or tostring(x._kind) end return tostring(x) end

-- the two game rules (see the header)
local proto
do
  local probe = CreateFrame("Frame")
  local idx = getmetatable(probe).__index
  for i = 1, 50 do
    local n, v = debug.getupvalue(idx, i)
    if not n then break end
    if n == "proto" then proto = v end
  end
end
check("(test set-up) the stand-in's widget methods are reachable", proto ~= nil)
if not proto then return R end
local realSet, realHook = proto.SetScript, proto.HookScript
proto.SetScript = function(self, n, f, ...) if n == "OnKeyDown" and f then self._keyboard = true end; return realSet(self, n, f, ...) end
proto.HookScript = function(self, n, f, ...) if n == "OnKeyDown" then self._keyboard = true end; return realHook(self, n, f, ...) end
local realCF = CreateFrame
CreateFrame = function(kind, ...) local f = realCF(kind, ...); if kind == "EditBox" then f._mouse = true end; return f end
local function click(box)   -- a click on a box: GLOBAL_MOUSE_DOWN with the mouse over it, then the box takes the keyboard if it takes the mouse
  local over = box.IsMouseOver
  box.IsMouseOver = function() return true end
  W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
  box.IsMouseOver = over
  if box:IsMouseEnabled() then box:SetFocus() end
end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
local nErr0 = #W.errors

-- R1: the mover view opened for the first time in combat
ns.folders = { { id = "fK", name = "Keys" } }
CueRulesDB.folders = ns.folders
local r = ns.NewRule(); r.name = "Key test"; r.folder = "fK"; r.enabled = true
ns.NormalizeRule(r); r.visual.enabled = true; r.visual.x, r.visual.y = 0, 0
ns.rules = { r }
ns.RefreshAllVisuals()
W.enterCombat()
ns.ToggleUnlock(); W.tick(0.05, 3)
local keys = ns.MoverKeyFrame()
check("(test set-up) the mover view opened in combat", keys ~= nil and keys:IsShown())
do local g1, g2 = who(W.pressKey("W")), who(W.pressKey("PRINTSCREEN"))
  check("R1 mover view first opened in combat: movement (W) and PRINTSCREEN reach the game", g1 == "game" and g2 == "game", g1 .. " / " .. g2) end
W.leaveCombat(); W.tick(0.05, 2)
ns.MoverSelect("display", r)
local x0 = r.visual.x
local k = W.pressKey("RIGHT")
check("(regression) after the fight the right arrow nudges the selected display and is kept from the game", k == keys and r.visual.x == x0 + 1, who(k) .. " x=" .. tostring(r.visual.x))
W.tick(0.02, 1)
check("(regression) ...and the next key (PRINTSCREEN) reaches the game", who(W.pressKey("PRINTSCREEN")) == "game")
ns.MoverExit("cancel"); W.tick(0.05, 2)

-- R1: the settings window opened for the first time in combat
local AceGUI, ACD = LibStub("AceGUI-3.0"), LibStub("AceConfigDialog-3.0")
local RE = ns.OptionsApi and ns.OptionsApi.RuleEditor or {}
local deletes = 0
RE.DeleteKey = function() deletes = deletes + 1; return true end
W.enterCombat()
local of = AceGUI:Create("Frame")
ACD.OpenFrames = ACD.OpenFrames or {}
ACD.OpenFrames["CueRules"] = of
of.frame:Show()
ACD:Open("CueRules", of)
W.tick(0.3, 3)
local fr = of.frame
check("(test set-up) the settings window's chrome was built in combat", of.xuiChrome ~= nil)
do local g1, g2 = who(W.pressKey("W")), who(W.pressKey("PRINTSCREEN"))
  check("R1 settings window first opened in combat: W and PRINTSCREEN reach the game", g1 == "game" and g2 == "game", g1 .. " / " .. g2) end
-- R1: the version pane opened for the first time in combat
local c = of.xuiChrome
local pane
if c and c.info and ns.InfoPane then
  c.info:Click(); pane = ns.InfoPane.Frame()
  local g = who(W.pressKey("W"))
  check("R1 version pane first opened in combat: W reaches the game", pane and pane:IsShown() and g == "game", g)
else check("(test set-up) the version pane is there", false) end
W.leaveCombat(); W.tick(0.3, 2)
local d0 = deletes
if pane then
  local kk = W.pressKey("ESCAPE")
  check("(regression) after the fight Esc closes the version pane and is kept from the game", kk == pane and not pane:IsShown(), who(kk))
  W.tick(0.02, 1)
end
local got = W.pressKey("DELETE")
check("(regression) after the fight Delete deletes and is kept from the game", got == fr and deletes == d0 + 1, who(got))
W.tick(0.02, 1)
check("(regression) ...and the next key (PRINTSCREEN) reaches the game", who(W.pressKey("PRINTSCREEN")) == "game")

-- R25: Esc in the rule search box (the box of the open settings window)
local sb
for _, o in ipairs(W.objects) do
  if o._kind == "EditBox" and o.hint and o.hint.GetText and o.hint:GetText() == "Search rules" and o:IsVisible() then sb = o end
end
if sb then
  click(sb)
  for _, ch in ipairs({ "f", "r", "o" }) do sb:SetText((sb:GetText() or "") .. ch); local tc = sb:GetScript("OnTextChanged"); if tc then tc(sb) end end
  W.tick(0.05, 6)   -- the filter debounce (0.25 s) ran with the box focused
  check("(test set-up) the search box has the keyboard while she types", sb:HasFocus())
  local esc = sb:GetScript("OnEscapePressed"); esc(sb)
  local tc = sb:GetScript("OnTextChanged"); if tc then tc(sb) end
  W.tick(0.05, 12)  -- the next debounce and its refocus passes (0.25 s, a frame, 0.35 s)
  check("R25 Esc in the rule search box clears it and the box stays without the keyboard", (sb:GetText() or "") == "" and not sb:HasFocus(),
    tostring(sb:GetText()) .. " / focus=" .. tostring(sb:HasFocus()))
  check("R25 ...so W reaches the game", who(W.pressKey("W")) == "game")
else check("(test set-up) the rule search box is there", false) end
AceGUI:Release(of); ACD.OpenFrames["CueRules"] = nil

-- R23: a box with the keyboard lets go when combat starts; the copy box and the import window opened in combat do not take it
if ns.ShowCopyBox then
  ns.ShowCopyBox("Test", "some text")
  local cb = rawget(_G, "XayaUICopyBox")
  check("(regression) the copy box opened out of combat has the keyboard (the text is selected)", cb and cb.eb:HasFocus())
  W.enterCombat()
  local g = who(W.pressKey("W"))
  check("R23 copy box left with the keyboard, combat starts: it lets go and W reaches the game", g == "game" and not cb.eb:HasFocus(), g)
  cb:Hide()
  ns.ShowCopyBox("Test", "again")
  g = who(W.pressKey("W"))
  check("R23 copy box opened in combat: it does not take the keyboard (W reaches the game)", g == "game" and not cb.eb:HasFocus(), g)
  cb:Hide()
  W.leaveCombat()
else check("(test set-up) ns.ShowCopyBox is there", false) end
if ns.OpenImportWindow then
  W.enterCombat()
  ns.OpenImportWindow()
  local iw = rawget(_G, "XayaUIImportWindow")
  local g = who(W.pressKey("W"))
  check("R23 import window opened in combat: it does not take the keyboard (W reaches the game)", g == "game", g)
  if iw then iw:Hide() end
  W.leaveCombat()
  ns.OpenImportWindow()
  local box
  for _, o in ipairs(W.objects) do if o._kind == "EditBox" and o:HasFocus() then box = o end end
  check("(regression) import window opened out of combat: its box has the keyboard (paste at once)", box ~= nil)
  if iw then iw:Hide() end
end
-- an addon restriction starting (a Mythic+ run: type ChallengeMode 2, state Active 2) lets go too; a Chat restriction does not
if ns.ShowCopyBox then
  local cb = rawget(_G, "XayaUICopyBox")
  ns.ShowCopyBox("Test", "text")
  W.fire("ADDON_RESTRICTION_STATE_CHANGED", 5, 2)
  check("(regression) a chat restriction does not take the keyboard from the box", cb.eb:HasFocus())
  W.fire("ADDON_RESTRICTION_STATE_CHANGED", 2, 2)
  check("R23 a Mythic+ run starting (addon restriction) lets go of the box", not cb.eb:HasFocus())
  cb:Hide()
end

-- R22: a click on the debug report's summary
if ns.ShowDebugReport then
  ns.ShowDebugReport(); W.tick(0.05, 2)
  local win = ns.DebugReportWindow()
  local before = win.text:GetText()
  click(win.text)
  local g = who(W.pressKey("PRINTSCREEN"))
  check("R22 a click on the debug report's summary: PRINTSCREEN still reaches the game (the screenshot the hint asks for)", g == "game", g)
  check("R22 ...and the summary keeps no keyboard", not win.text:HasFocus())
  click(win.str)
  check("(regression) a click on the string box still gives it the keyboard (to copy)", win.str:HasFocus())
  check("(regression) the summary text is unchanged", win.text:GetText() == before)
  win:Hide()
end

check("no Lua error and no blocked action in any of this", #W.errors == nErr0, W.errors[#W.errors])
return R
end
'''


def main():
    results = []
    folders = H.find_addons()
    enabled = list(folders)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    for i in range(1, len(res) + 1):
        results.append((res[i][1], res[i][2]))
    bad = 0
    for name, good in results:
        print(("PASS " if good else "FAIL ") + name)
        bad += 0 if good else 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
