#!/usr/bin/env python3
"""Round-2 review follow-ups for the rule editor's popups (XayaUI_Rules/Editor/Sidebar.lua) and the stand-in game's text boxes.
Loads the real addons in the stand-in game (tests/harness) and checks what the player gets.
- Export popup (right-click > Export): opened in combat, or once a fight starts, the box has no keyboard, so the popup text says how to
  copy (click the box, then Ctrl+A and Ctrl+C); when she clicks the box the export text is selected again (a click puts the cursor in
  the box and drops the selection: INFERENCE, UNVERIFIED IN GAME; the test models it by clearing the selection before the click).
- Rename popup (right-click > Rename, when the row is not on screen to rename in place): guarded like the Export popup. Picked in
  combat from a menu left open, it does not open at all (V26, round 4: the menu's choices change nothing in combat; one plain line
  says why; this replaced the round-3 check that it opened without the keyboard); opened out of combat it has the keyboard with the name
  selected, and lets go when a fight starts; closed, the game's popup box is handed back as it was.
- The stand-in (tests/harness/world.lua) runs a box's OnEditFocusGained / OnEditFocusLost for SetFocus / ClearFocus and for a click
  (W.click), and one box has the keyboard at a time, as in the game.
The stand-in's StaticPopup_Show shows nothing, so this test gives it a popup like the game's (as tests/fix_r2_focus_drafts_run.py does:
one dialog with an edit box that takes the keyboard by itself when shown unless SetAutoFocus(false), its OnShow / OnHide calling the
popup's own OnShow / OnHide, the box's own Enter / Escape scripts calling the popup's EditBoxOnEnterPressed / EditBoxOnEscapePressed).
Each check fails on the code before this change, except those marked "(regression)".
Run: python3 tests/fix_r3_popups_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
local function who(x) if x == "game" then return "game" end if type(x) == "table" then return (x.GetName and x:GetName()) or tostring(x._kind) end return tostring(x) end

section("stand-in focus scripts", function()
  local a = CreateFrame("EditBox", nil, UIParent)
  local b = CreateFrame("EditBox", nil, UIParent)
  local log = {}
  a:SetScript("OnEditFocusGained", function() log[#log + 1] = "a+" end); a:SetScript("OnEditFocusLost", function() log[#log + 1] = "a-" end)
  b:SetScript("OnEditFocusGained", function() log[#log + 1] = "b+" end); b:SetScript("OnEditFocusLost", function() log[#log + 1] = "b-" end)
  a:SetFocus(); a:SetFocus(); b:SetFocus(); b:ClearFocus(); b:ClearFocus()
  check("stand-in: SetFocus / ClearFocus run the focus scripts, once each, and one box has the keyboard at a time",
    table.concat(log, " ") == "a+ a- b+ b-" and not a:HasFocus() and not b:HasFocus(), table.concat(log, " "))
  log = {}
  local mouse
  W.registeredEvents()   -- (warm)
  local watch = CreateFrame("Frame"); watch:RegisterEvent("GLOBAL_MOUSE_DOWN"); watch:SetScript("OnEvent", function() mouse = a:IsMouseOver() end)
  W.click(a)
  watch:UnregisterEvent("GLOBAL_MOUSE_DOWN")
  check("stand-in: a click on a box: GLOBAL_MOUSE_DOWN with the mouse over it, then the box takes the keyboard (its focus script runs)",
    mouse == true and a:HasFocus() and table.concat(log, " ") == "a+" and not a:IsMouseOver(), tostring(mouse) .. " / " .. table.concat(log, " "))
  b:EnableMouse(false); W.click(b)
  check("(regression) stand-in: a box told not to take the mouse does not take the keyboard when clicked", a:HasFocus() and not b:HasFocus())
  a:ClearFocus()
end)

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false

-- a popup like the game's (see the header); HighlightText is recorded (eb._sel)
local dlg = CreateFrame("Frame", "XuiTestPopup1", UIParent); dlg:Hide()
local eb = CreateFrame("EditBox", nil, dlg)
eb._auto = true
eb.SetAutoFocus = function(self, v) self._auto = v and true or false end
eb.IsAutoFocus = function(self) return self._auto end
eb.HighlightText = function(self) self._sel = true end
-- the game's popup box has its own Enter / Escape scripts, which run the popup's EditBoxOnEnterPressed / EditBoxOnEscapePressed
eb:SetScript("OnEnterPressed", function(self) local info = StaticPopupDialogs[dlg.which]; if info and info.EditBoxOnEnterPressed then info.EditBoxOnEnterPressed(self, dlg.data) end end)
eb:SetScript("OnEscapePressed", function(self) local info = StaticPopupDialogs[dlg.which]; if info and info.EditBoxOnEscapePressed then info.EditBoxOnEscapePressed(self, dlg.data) else dlg:Hide() end end)
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
  dlg.which, dlg.data, dlg.shownText = which, data, text
  dlg:Show()
  if eb._auto then eb:SetFocus() end           -- the game's box takes the keyboard by itself when shown
  local info = StaticPopupDialogs[which]
  if info and info.OnShow then info.OnShow(dlg, data) end
  return dlg
end
StaticPopup_Show = Popup
local function says(s) return tostring(dlg.shownText or "") end

section("export popup", function()
  check("(test set-up) the rule editor is set up (the Export popup is there)", StaticPopupDialogs.XAYAUI_EXPORT ~= nil and ns.UI and ns.UI.ExportRule ~= nil)
  local r = ns.NewRule(); r.name = "Export test"; r.uid = ns.NewUID(); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  W.enterCombat()
  ns.UI.ExportRule(r)
  local t = says()
  check("(regression) Export popup opened in combat: it does not take the keyboard", dlg:IsShown() and not eb:HasFocus())
  check("Export popup opened in combat: the text says how to copy (click the box, then Ctrl+A and Ctrl+C)",
    t:find("click the box", 1, true) ~= nil and t:find("Ctrl+A", 1, true) ~= nil and t:find("Ctrl+C", 1, true) ~= nil, t)
  eb._sel = false                               -- her click puts the cursor in the box: the selection is gone (INFERENCE)
  W.click(eb)
  check("Export popup in combat, she clicks the box: it has the keyboard and the export text is selected again (Ctrl+C copies it)",
    eb:HasFocus() and eb._sel == true, tostring(eb:HasFocus()) .. " / selected " .. tostring(eb._sel))
  dlg:Hide()
  W.leaveCombat()
  -- out of combat, then a fight starts
  local f = ns.NewFolder("Export group")
  r.folder = f.id
  ns.UI.ExportFolder(f)
  t = says()
  check("(regression) Export popup opened out of combat: its box has the keyboard with the text selected", eb:HasFocus() and eb._sel == true)
  check("(test set-up) the group's Export popup shows", dlg.which == "XAYAUI_EXPORT" and says():find("group 'Export group'", 1, true) ~= nil, says())
  check("Export popup (a group): the text also says how to copy when the text is not selected", t:find("Ctrl+A", 1, true) ~= nil, t)
  W.enterCombat()
  local g = who(W.pressKey("W"))
  check("(regression) a fight starts: the export box lets go (W reaches the game)", g == "game" and not eb:HasFocus(), g)
  eb._sel = false
  W.click(eb)
  check("...she clicks the box: the export text is selected again", eb:HasFocus() and eb._sel == true, tostring(eb._sel))
  dlg:Hide()
  W.leaveCombat()
  check("(regression) popup closed: the game's popup box takes the keyboard by itself again", eb._auto == true, eb._auto)
  StaticPopupDialogs.XUI_TEST_OTHER = { text = "%s", button1 = OKAY, hasEditBox = true }
  Popup("XUI_TEST_OTHER", "other")
  eb._sel = false
  eb:ClearFocus(); W.click(eb)
  check("(regression) another popup's box clicked: XayaUI does not select its text (the export hook does nothing then)", eb:HasFocus() and eb._sel == false)
  dlg:Hide(); eb:ClearFocus()
end)

section("rename popup", function()
  check("(test set-up) the Rename popup is there", StaticPopupDialogs.XAYAUI_RENAME ~= nil)
  -- the rule's right-click menu (its buttons by label); Rename uses the popup when the row cannot be renamed in place
  local menu = {}
  local function rec()
    local root = {}
    function root:CreateButton(text, fn) menu[tostring(text)] = fn; return rec() end
    function root:CreateTitle() return rec() end
    function root:CreateDivider() end
    function root:CreateRadio() return rec() end
    function root:CreateCheckbox() return rec() end
    function root:SetScrollMode() end
    function root:AddMenuAcquiredCallback() end
    return root
  end
  MenuUtil.CreateContextMenu = function(owner, gen) gen(owner, rec()) end
  ns.SidebarRenameLater = function() return false end
  local r = ns.NewRule(); r.name = "Old name"; r.enabled = true; r.uid = ns.NewUID(); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  CueRulesDB.rules = ns.rules
  pcall(ns.ToggleUI); W.tick(0.05, 6)
  local ACD = LibStub("AceConfigDialog-3.0")
  pcall(ACD.SelectGroup, ACD, "CueRules", "cooldowns", "enabledTab"); W.tick(0.05, 6)
  local row
  local function walk(f, d)
    if row or not f or d > 60 then return end
    if f.uniquevalue and f:IsShown() and tostring(f.uniquevalue):match("rule" .. #ns.rules .. "$") then row = f end
    for _, c in ipairs({ f:GetChildren() }) do walk(c, d + 1) end
  end
  walk(UIParent, 0)
  check("(test set-up) the rule's row is on screen", row ~= nil)
  if not row then return end
  local function rename() menu = {}; row:Click("RightButton"); return menu.Rename end
  -- picked as a fight starts (the window closes in combat since V26; the popup can still be asked for, e.g. the debugging exemption)
  local fn = rename()
  check("(test set-up) the row's menu has Rename", fn ~= nil)
  if not fn then return end
  -- (V26, round 4: tests/fix_r4_menus_run.py) a menu choice made in combat changes nothing: no popup opens, so nothing can take the
  -- keyboard; one plain line says why. (Before round 4 the popup opened without the keyboard; that path is no longer reachable.)
  W.enterCombat()
  local said, P0 = {}, ns.Print
  ns.Print = function(s) said[#said + 1] = tostring(s) end
  local shownBefore = dlg:IsShown() and dlg.which == "XAYAUI_RENAME"
  fn()
  ns.Print = P0
  local g = who(W.pressKey("W"))
  check("Rename picked from a menu left open into combat: no Rename popup opens and W reaches the game",
    not shownBefore and not (dlg:IsShown() and dlg.which == "XAYAUI_RENAME") and g == "game" and not eb:HasFocus(), g)
  check("  ...the name is unchanged and one plain line says why", r.name == "Old name" and #said == 1 and said[1]:find("during combat", 1, true) ~= nil,
    table.concat(said, " / "))
  W.leaveCombat()
  fn = rename()
  if fn then fn() end
  check("(regression) Rename popup opened out of combat: the box has the keyboard with the name selected, no click hint",
    eb:HasFocus() and eb._sel == true and eb:GetText() == "Old name" and says() == "Rename", says())
  W.enterCombat()
  g = who(W.pressKey("W"))
  check("Rename popup left with the keyboard, combat starts: it lets go and W reaches the game", g == "game" and not eb:HasFocus(), g)
  W.leaveCombat()
  W.click(eb); eb:SetText("New name")
  W.pressKey("ENTER")
  check("(regression) Enter renames the rule and closes the popup", r.name == "New name" and not dlg:IsShown(), r.name)
  check("Rename popup closed: the game's popup box takes the keyboard by itself again", eb._auto == true, eb._auto)
  StaticPopupDialogs.XUI_TEST_OTHER = { text = "%s", button1 = OKAY, hasEditBox = true }
  Popup("XUI_TEST_OTHER", "other")
  W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
  check("(regression) ...another popup's box: XayaUI does not act on it (a click elsewhere leaves it the keyboard)", eb:HasFocus())
  dlg:Hide(); eb:ClearFocus()
end)
StaticPopup_Show = Show0
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
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
