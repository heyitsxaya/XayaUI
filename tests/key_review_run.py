#!/usr/bin/env python3
"""Keys reach the game, the review's should-fix items (XayaUI 0.6.85 / Options 0.6.106 / Bonus 0.6.38, XayaUI/KeyCatch.lua).
Xaya 2026-11-08 (docs/process/REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md row 56, her words): "WHY DOES THE ADDON KEEP PREVENTING
ME FROM SCREENSHOTTING"; row 59 (Delete / Ctrl+Z / Ctrl+Y): "they are just supposed to be baseline supported by the addon".

What she sees:
  1. no XayaUI text box keeps the keyboard after she is done: the settings window's AceGUI boxes let go on Enter, a click elsewhere
     and when the window closes (with the window skin on or off); the Calculator's line lets go after Enter works the sum out; the
     Console's command line lets go after Enter runs the command;
  2. the screenshot key works by what it is bound to (her screenshot key may not be PRINTSCREEN): a XayaUI window never uses or keeps it;
  3. in combat the settings window's Delete / Ctrl+Z / Ctrl+Y still work, but a key never does two things: a key the game has a
     binding for is the game's alone in combat (the game does not let an addon keep a key back then).

The stand-in game routes keys as tests/harness/world.lua describes (W.pressKey; W.gameRan = the binding the game ran for the key).
Each check fails on the code before this change (fb1fd95), except those marked "(regression)", which pass on both.
Run: python3 tests/key_review_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function who(x) if x == "game" then return "game" end if type(x) == "table" then return (x.GetName and x:GetName()) or tostring(x._kind) end return tostring(x) end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
local ctrl = false
IsControlKeyDown = function() return ctrl end

-- 2. the screenshot key by its binding
do
  local t = CreateFrame("Frame", "XUIReviewGreedy", UIParent); t:SetFrameStrata("TOOLTIP")
  local seen = {}
  ns.KeyCatch(t, function(_, key) seen[#seen + 1] = key; return true end)   -- a window that claims every key
  W.bindings.F12 = "SCREENSHOT"
  local g = W.pressKey("F12")
  check("screenshot bound to F12: a window that claims every key leaves F12 to the game, which takes the picture", g == "game" and W.gameRan == "SCREENSHOT", who(g) .. " / " .. tostring(W.gameRan))
  check("  ...and the window's handler never sees the screenshot key", #seen == 0, table.concat(seen, ","))
  W.tick(0.02, 1)
  W.bindings.PRINTSCREEN = nil   -- PRINTSCREEN unbound: still never kept (the key's name)
  check("(regression) PRINTSCREEN (unbound) is still never kept", who(W.pressKey("PRINTSCREEN")) == "game")
  W.bindings.PRINTSCREEN = "SCREENSHOT"; W.bindings.F12 = nil
  t:Hide()
end

-- the settings window
local AceGUI, ACD = LibStub("AceGUI-3.0"), LibStub("AceConfigDialog-3.0")
local RE = ns.OptionsApi and ns.OptionsApi.RuleEditor or {}
local deletes, undos = 0, 0
RE.DeleteKey = function() deletes = deletes + 1; return true end
RE.UndoKey = function() undos = undos + 1; return true end
local of = AceGUI:Create("Frame")
ACD.OpenFrames = ACD.OpenFrames or {}
ACD.OpenFrames["CueRules"] = of
of.frame:Show()
ACD:Open("CueRules", of)
W.tick(0.3, 3)
local fr = of.frame

do -- her screenshot key is Delete: the window does not delete a rule and the game takes the picture
  W.bindings.DELETE = "SCREENSHOT"
  local d0 = deletes
  local g = W.pressKey("DELETE")
  check("settings window, screenshot bound to Delete: Delete takes the screenshot and deletes no rule", g == "game" and W.gameRan == "SCREENSHOT" and deletes == d0,
    who(g) .. " / " .. tostring(W.gameRan) .. " / deleted " .. (deletes - d0))
  W.bindings.DELETE = nil; W.tick(0.02, 1)
end

-- 3. combat: Delete / Ctrl+Z / Ctrl+Y work, a key never does two things
do
  local d0 = deletes
  local g = W.pressKey("DELETE")
  check("(regression) out of combat, Delete (unbound) deletes and is kept from the game", g == fr and deletes == d0 + 1 and W.gameRan == nil, who(g))
  W.tick(0.02, 1)
  W.bindings.DELETE = "INTERACTTARGET"
  d0 = deletes
  g = W.pressKey("DELETE")
  check("(regression) out of combat, Delete bound in the game: the editor deletes and the game does nothing", g == fr and deletes == d0 + 1 and W.gameRan == nil, who(g) .. " / " .. tostring(W.gameRan))
  W.tick(0.02, 1)
  W.bindings.DELETE = nil

  W.enterCombat()
  d0 = deletes
  g = W.pressKey("DELETE")
  check("(regression) in combat, Delete (unbound) still deletes; the game gets the key and does nothing with it", g == "game" and deletes == d0 + 1 and W.gameRan == nil, who(g) .. " / " .. (deletes - d0))
  W.bindings.DELETE = "INTERACTTARGET"
  d0 = deletes
  g = W.pressKey("DELETE")
  check("in combat, Delete bound in the game: the game runs her binding and the editor deletes nothing (never both)", g == "game" and W.gameRan == "INTERACTTARGET" and deletes == d0,
    who(g) .. " / " .. tostring(W.gameRan) .. " / deleted " .. (deletes - d0))
  W.bindings.DELETE = nil
  ctrl = true
  local u0 = undos
  W.bindings["CTRL-Z"] = "TOGGLEAUTORUN"
  g = W.pressKey("Z")
  check("in combat, Ctrl+Z bound in the game: her binding runs and nothing is undone", W.gameRan == "TOGGLEAUTORUN" and undos == u0, tostring(W.gameRan) .. " / undone " .. (undos - u0))
  W.bindings["CTRL-Z"] = nil
  u0 = undos
  W.pressKey("Y")
  check("(regression) in combat, Ctrl+Y unbound: the editor redoes", undos == u0 + 1)
  ctrl = false
  -- the binding cannot be read (unknown): in combat the editor does not act on the key
  local saved = GetBindingFromClick
  GetBindingFromClick = function() error("unreadable") end
  d0 = deletes
  W.pressKey("DELETE")
  check("in combat, a key whose binding cannot be read is left to the game (the editor does not act)", deletes == d0, deletes - d0)
  GetBindingFromClick = saved
  local nErr = #W.errors
  W.pressKey("DELETE"); W.pressKey("W")
  check("(regression) in combat no window touches the restricted flag (no blocked-action error)", #W.errors == nErr, W.errors[#W.errors])
  W.leaveCombat()
end

AceGUI:Release(of); ACD.OpenFrames["CueRules"] = nil

-- 1. the settings window's AceGUI text boxes (a window holding the same widgets the options pages build)
local bw = AceGUI:Create("Frame")
bw.frame:Show()
local function addBox(kind)
  local w = AceGUI:Create(kind)
  bw:AddChild(w)
  if ns.DecorateTrees then ns.DecorateTrees(bw) end
  return w
end
local of = bw
do
  local w = addBox("EditBox")
  local eb = w.editbox
  eb:SetFocus(); eb:SetText("abc")
  local entered = 0
  w:SetCallback("OnEnterPressed", function() entered = entered + 1 end)
  W.pressKey("ENTER")
  check("settings window text box: Enter takes the value and lets go of the keyboard", entered == 1 and not eb:HasFocus(), "entered " .. entered .. " focus " .. tostring(eb:HasFocus()))
  check("  ...then the screenshot key and movement reach the game", who(W.pressKey("PRINTSCREEN")) == "game" and who(W.pressKey("W")) == "game")
  eb:SetFocus()
  w.frame.IsMouseOver = function() return true end
  W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
  check("(regression) a click on the box itself keeps the cursor", eb:HasFocus())
  w.frame.IsMouseOver = function() return false end
  W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
  check("settings window text box: a click elsewhere lets go", not eb:HasFocus())
  eb:SetFocus()
  of.frame:Hide()
  check("settings window text box: closing the window lets go", not eb:HasFocus())
  of.frame:Show(); W.tick(0.05, 1)

  local m = addBox("MultiLineEditBox")
  local mb = m.editBox
  mb:SetFocus()
  W.pressKey("ENTER")
  check("(regression) a multi-line box keeps Enter (a new line) and the cursor", mb:HasFocus())
  m.frame.IsMouseOver = function() return false end
  W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
  check("settings window multi-line box: a click elsewhere lets go", not mb:HasFocus())

  -- the widget is handed back to AceGUI and on to another addon: XayaUI does not act on it any more
  bw:ReleaseChildren()
  local other = AceGUI:Create("EditBox")
  local ob = other.editbox
  ob:SetFocus()
  if other.frame then other.frame.IsMouseOver = function() return false end end
  ob.IsMouseOver = function() return false end
  W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
  check("(regression) another addon's text box (from AceGUI's pool) is not touched by a click elsewhere", ob:HasFocus())
  W.pressKey("ENTER")
  check("(regression) another addon's text box keeps AceGUI's own Enter (the cursor stays)", ob:HasFocus())
  ob:ClearFocus(); AceGUI:Release(other)

  -- with the window skin off the boxes still let go (the guard is not cosmetic)
  CueRulesDB.ui = CueRulesDB.ui or {}
  CueRulesDB.ui.skinOff = true
  local w2 = addBox("EditBox")
  w2.editbox:SetFocus()
  W.pressKey("ENTER")
  check("window skin off: a settings text box still lets go on Enter", not w2.editbox:HasFocus())
  CueRulesDB.ui.skinOff = nil
end
AceGUI:Release(bw)

-- 1. the Calculator's line: Enter works the sum out and lets go
if ns.Calculator_Open then
  ns.Calculator_Open()
  local cf = rawget(_G, "XayaUICalculator")
  local e = cf and cf.edit
  e:SetText("2+3")
  W.pressKey("ENTER")
  check("(regression) Calculator: Enter works the sum out (5)", cf.result:GetText() == "5", cf.result:GetText())
  check("  ...and lets go of the keyboard: W and the screenshot key reach the game", not e:HasFocus() and who(W.pressKey("W")) == "game" and who(W.pressKey("PRINTSCREEN")) == "game",
    tostring(e:HasFocus()))
  check("(regression) the answer stays in the line, so the next sum builds on it", e:GetText() == "5", e:GetText())
  cf:Hide()
else check("the Calculator is there", false) end

-- 1. the Console's command line: Enter runs the command and lets go
if ns.ConsoleWindow then
  ns.ConsoleWindow(true)
  local cw = rawget(_G, "XayaUIConsoleWindow")
  local cmd = cw and cw.cmd
  if cmd then
    cmd:SetFocus(); cmd:SetText("help")
    W.pressKey("ENTER")
    check("Console: Enter runs the command (the line is cleared) and lets go of the keyboard", cmd:GetText() == "" and not cmd:HasFocus(), tostring(cmd:HasFocus()))
  else check("the Console's command line is there", false) end
  ns.ConsoleWindow(false)
end
return R
end
'''


def main():
    results = []
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
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
