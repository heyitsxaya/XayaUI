#!/usr/bin/env python3
"""Review follow-ups (rules review 2026-11-10, docs/plans/RULES-REVIEW-2026-11-10.md: R23 and R7 gaps). Loads the real addons in the
stand-in game (tests/harness) and checks what the player gets.
- R23 a rule's Export popup (right-click > Export) opened in combat does not take the keyboard (W reaches the game); opened out of
      combat it has it (Ctrl+C at once) and lets go when a fight starts. When the popup closes, the game's popup box is handed back
      as it was: it takes the keyboard by itself again for the next popup, and XayaUI no longer acts on it.
- R23 the Import window opened in combat tells her to click the box before pasting (the box has no keyboard); out of combat it says
      to paste; a fight starting while the box had the keyboard switches the help to the click version, a click on the box back.
- R7  "Keep up to" (drafts) lowered, then "Use drafts" switched off: closing the window still drops the oldest drafts (the Drafts
      page says so). With no drafts list at all, closing makes none.
The stand-in's StaticPopup_Show shows nothing, so this test gives it a popup like the game's for the Export checks: one dialog frame
with an edit box that takes the keyboard by itself when shown unless SetAutoFocus(false) (INFERENCE: the game's popup box template
sets no autoFocus, Blizzard_StaticPopup_Game/GameDialog.xml, and an EditBox's default is on), the dialog's OnShow / OnHide calling
the popup's own OnShow / OnHide (Blizzard StaticPopup.lua StaticPopup_OnShow / StaticPopup_OnHide).
Each check fails on the code before this change, except those marked "(regression)".
Run: python3 tests/fix_r2_focus_drafts_run.py"""
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
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
local function who(x) if x == "game" then return "game" end if type(x) == "table" then return (x.GetName and x:GetName()) or tostring(x._kind) end return tostring(x) end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
local nErr0 = #W.errors

-- a popup like the game's (see the header)
local dlg = CreateFrame("Frame", "XuiTestPopup1", UIParent); dlg:Hide()
local eb = CreateFrame("EditBox", nil, dlg)
eb._auto = true
eb.SetAutoFocus = function(self, v) self._auto = v and true or false end
eb.IsAutoFocus = function(self) return self._auto end
dlg.EditBox = eb
dlg.GetEditBox = function(self) return self.EditBox end
dlg:SetScript("OnHide", function(self)
  local info = StaticPopupDialogs[self.which]
  if info and info.OnHide then info.OnHide(self, self.data) end
  eb:SetText("")
end)
local Show0 = StaticPopup_Show
local function Popup(which, text, _, data)
  if dlg:IsShown() then dlg:Hide() end
  dlg.which, dlg.data = which, data
  dlg:Show()
  if eb._auto then eb:SetFocus() end           -- the game's box takes the keyboard by itself when shown
  local info = StaticPopupDialogs[which]
  if info and info.OnShow then info.OnShow(dlg, data) end
  return dlg
end
StaticPopup_Show = Popup

section("R23 export popup", function()
  check("(test set-up) the rule editor is set up (the Export popup is there)", StaticPopupDialogs.XAYAUI_EXPORT ~= nil and ns.UI and ns.UI.ExportRule ~= nil)
  local r = ns.NewRule(); r.name = "Export test"; r.uid = ns.NewUID(); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  -- opened in combat
  W.enterCombat()
  ns.UI.ExportRule(r)
  check("(test set-up) the Export popup shows the export text", dlg:IsShown() and dlg.which == "XAYAUI_EXPORT" and (eb:GetText() or ""):match("%S") ~= nil)
  local g = who(W.pressKey("W"))
  check("R23 Export popup opened in combat: it does not take the keyboard (W reaches the game)", g == "game" and not eb:HasFocus(), g)
  dlg:Hide()
  W.leaveCombat()
  -- opened out of combat, then a fight starts
  ns.UI.ExportRule(r)
  check("(regression) Export popup opened out of combat: its box has the keyboard (Ctrl+C at once)", eb:HasFocus())
  W.enterCombat()
  g = who(W.pressKey("W"))
  check("R23 Export popup left with the keyboard, combat starts: it lets go and W reaches the game", g == "game" and not eb:HasFocus(), g)
  dlg:Hide()
  W.leaveCombat()
  -- handed back as it was: the next popup (any popup, the game's or another addon's) is untouched
  check("(regression) popup closed: the game's popup box takes the keyboard by itself again (as before XayaUI used it)", eb._auto == true, eb._auto)
  StaticPopupDialogs.XUI_TEST_OTHER = { text = "%s", button1 = OKAY, hasEditBox = true }
  Popup("XUI_TEST_OTHER", "other")
  check("(regression) another popup with a box: it has the keyboard", eb:HasFocus())
  W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
  check("(regression) ...XayaUI does not act on that popup's box (a click elsewhere leaves it to the game)", eb:HasFocus())
  dlg:Hide()
end)
StaticPopup_Show = Show0

section("R23 import window help", function()
  check("(test set-up) the import window is there", ns.OpenImportWindow ~= nil)
  W.enterCombat()
  ns.OpenImportWindow()
  local iw = rawget(_G, "XayaUIImportWindow")
  local help = iw and iw.help and iw.help:GetText() or ""
  check("R23 Import window opened in combat: the help says to click the box before pasting",
    help:find("Click the box", 1, true) ~= nil and not iw.box:HasFocus(), help)
  iw:Hide()
  W.leaveCombat()
  ns.OpenImportWindow()
  help = iw.help:GetText() or ""
  check("(regression) Import window opened out of combat: the box has the keyboard and the help says to paste",
    iw.box:HasFocus() and help:find("^Paste exported rules") ~= nil and not help:find("Click", 1, true), help)
  W.enterCombat()
  help = iw.help:GetText() or ""
  check("R23 a fight starts with the Import box focused: it lets go and the help says to click the box first",
    not iw.box:HasFocus() and help:find("Click the box", 1, true) ~= nil, help)
  iw.box:SetFocus(); local fg = iw.box:GetScript("OnEditFocusGained"); if fg then fg(iw.box) end   -- she clicks the box
  help = iw.help:GetText() or ""
  check("(regression) ...she clicks the box: the help says to paste again", help:find("^Paste exported rules") ~= nil, help)
  iw.box:ClearFocus()
  iw:Hide()
  W.leaveCombat()
end)

section("R7 drafts trimmed with drafts off", function()
  local CoreS = ns.Settings("core")
  CoreS.promptSave = true
  CoreS.drafts = {}
  for i = 1, 30 do CoreS.drafts[i] = { id = "d" .. i, uid = "d" .. i, name = "Draft " .. i, ts = 1000 - i, rules = {} } end
  ns.DraftsOnOpen()
  CoreS.draftsMax = 10                         -- "Keep up to" lowered to 10 (it only stores the number, R7)
  CoreS.promptSave = nil; if ns.DraftsApplySetting then ns.DraftsApplySetting() end   -- then "Use drafts" switched off
  ns.DraftsOnClose()
  check("R7 Keep up to lowered, then drafts switched off: closing the window keeps the 10 newest drafts",
    #CoreS.drafts == 10 and CoreS.drafts[1].id == "d1" and CoreS.drafts[10].id == "d10", #CoreS.drafts)
  CoreS.drafts = nil; CoreS.draftsMax = nil
  ns.DraftsOnOpen(); ns.DraftsOnClose()
  check("(regression) drafts off and never used: closing the window makes no drafts list", CoreS.drafts == nil, type(CoreS.drafts))
end)

check("no Lua error and no blocked action in any of this", #W.errors == nErr0, W.errors[#W.errors])
return R
end
'''


def main():
    results = []
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
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
