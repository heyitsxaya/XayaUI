#!/usr/bin/env python3
"""/xui debug in core: the diagnostic list and core's loader report (core 0.6.50 / 0.6.56; REQUEST-LOG #30 and #81).
This test began as the left-pane feature rows test (Enhanced Tooltips #45, the Character Toolkit's Tooltip lines #46, Notepad #47)
with the world map report /xui debug map (#30). Those features (XayaUI Bonus, XayaUI QoL, the Character Reskin) and the map report
(XayaUI Dev Assist, XayaUI_DevAssist/CoreDebug.lua) are not on this branch, so their checks left with them. What stays is core's
own part of it (XayaUI/Core.lua, CORE_DEBUG):
  - plain /xui debug lists the diagnostic commands and runs none of them; core's loader report is among them, and the map report is
    not (its help line is XayaUI Dev Assist's: "without it they and their help lines do not exist");
  - /xui debug loader is core's loader report, without the map report;
  - (round 8) core's panel-layout counter (ns.MapTrace) served only Dev Assist's map report and is removed; its two call sites, the
    "Open XayaUI" button on the game's Options > AddOns page and the XayaUI button in the Game Menu, still close the game's window and
    open the settings window (in combat the settings window waits, V26).
It loads the real addons XayaUI and XayaUI_Options in the whole-addon stand-in (tests/harness).
Run: python3 tests/feature_rows_map_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- (the panel core gives the game's Options > AddOns list is made at load: keep it, to press its "Open XayaUI" button below)
local addonsPanel
do
  local raw = Settings.RegisterCanvasLayoutCategory
  Settings.RegisterCanvasLayoutCategory = function(panel, name, ...) if name == "XayaUI" then addonsPanel = panel end; return raw(panel, name, ...) end
end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
check("(sanity) core loaded", ns ~= nil and ns.PrintDebugHelp ~= nil and SlashCmdList.XAYAUI ~= nil)
if not ns then return R end
-- (bundle 1 round 9, REQUEST-LOG A23 SD-83, her answer "Remove both (Recommended)": ns.CaptureOutput is gone) what a command shows the
-- player, read from the stand-in game: the lines printed in chat (W.printed) and the lines drawn in the console window, each without the
-- "XayaUI: " name in front, in that order (one command prints in one of the two). With the debug tools loaded the console window is opened
-- first, so each line is drawn as it comes (a window opening in the middle of a command first draws the older lines it missed). A Lua
-- error in the command ends the list as "(error: ...)".
local SHOWN_NAME = "|cff33ccffXayaUI|r: "
local function unname(l) l = tostring(l); if l:sub(1, #SHOWN_NAME) == SHOWN_NAME then return l:sub(#SHOWN_NAME + 1) end; return l end
local function consoleLines() local cw = rawget(_G, "XayaUIConsoleWindow"); return cw and cw.log and cw.log._lines end
local function shown(fn, ...)
  if ns.DebugToolsLoaded and ns.DebugToolsLoaded() and not ns.ConsoleWindowOn() then ns.ConsoleWindow(true) end
  local c0, log0 = #W.printed, consoleLines()
  local n0 = log0 and #log0 or 0
  local ok, err = pcall(fn, ...)
  local out = {}
  for i = c0 + 1, #W.printed do out[#out + 1] = unname(W.printed[i]) end
  local log = consoleLines()
  if log then for i = (log == log0 and n0 or 0) + 1, #log do out[#out + 1] = unname(log[i]) end end
  if not ok then out[#out + 1] = "(error: " .. tostring(err) .. ")" end
  return out
end
local function run(msg) return table.concat(shown(SlashCmdList.XAYAUI, msg), " | ") end
-- (core 0.6.50: plain /xui debug lists the diagnostic commands; core 0.6.56, #81: the map report is XayaUI Dev Assist's)
do
  local t = run("debug")
  check("#30 plain /xui debug lists core's /xui debug loader and runs none of them; /xui debug map is not listed (XayaUI Dev Assist's, not on this branch)",
    t:find("/xui debug loader", 1, true) ~= nil and not t:find("debug: ToggleUI=", 1, true) and not t:find("/xui debug map", 1, true)
    and not t:find("map: world map:", 1, true), t)
end
do
  local t = run("debug loader")
  check("#30 ...core's own loader report is /xui debug loader, without the map report", t:find("debug: ToggleUI=", 1, true) ~= nil and not t:find("map:", 1, true), t)
end
-- #30 (bundle 1 round 8, V34 audit; intended change) the counter of XayaUI's calls into Blizzard's panel layout (Modules.lua section 9,
-- ns.MapTrace) served only XayaUI Dev Assist's /xui debug map and is removed. Core's two call sites still do what they did: they close
-- the game's own window first and open XayaUI's settings window.
do
  check("#30 the counter is gone from core (ns.MapTrace, ns.MapTraceCounts, ns.MapTraceOrder)",
    ns.MapTrace == nil and ns.MapTraceCounts == nil and ns.MapTraceOrder == nil)
  -- the game's panel manager, watched here (the stand-in's HideUIPanel does nothing of its own)
  local hid = {}
  local rawHide = HideUIPanel
  HideUIPanel = function(f) hid[#hid + 1] = (f == SettingsPanel and "SettingsPanel") or (f == GameMenuFrame and "GameMenuFrame") or tostring(f); return rawHide(f) end
  local function hidList() return table.concat(hid, ",") end
  local open
  for _, o in ipairs(W.objects) do
    if addonsPanel and o:GetParent() == addonsPanel and o.GetText and o:GetText() == "Open XayaUI" then open = o end
  end
  check("(sanity) core's Options > AddOns page and its \"Open XayaUI\" button exist", addonsPanel ~= nil and open ~= nil)
  local function closeWindow() if ns.IsOptionsOpen() then ns.ToggleUI() end; W.tick(0.05, 2) end
  if open then
    SettingsPanel:Hide(); closeWindow()
    open:Click(); W.tick(0.05, 2)
    check("#30 \"Open XayaUI\" with the game's settings window closed: no HideUIPanel call, the settings window opens", #hid == 0 and ns.IsOptionsOpen(), hidList())
    SettingsPanel:Show(); closeWindow()
    open:Click(); W.tick(0.05, 2)
    check("#30 \"Open XayaUI\" with the game's settings window shown: HideUIPanel(SettingsPanel) once, and XayaUI's window opens",
      hidList() == "SettingsPanel" and ns.IsOptionsOpen(), hidList())
    SettingsPanel:Hide()
  end
  GameMenuFrame:Show(); GameMenuFrame:InitButtons(); W.tick(0.05, 2)
  local gmb = rawget(_G, "XayaUI_GameMenuButton")
  check("(sanity) the Game Menu's XayaUI button exists", gmb ~= nil)
  if gmb then
    GameMenuFrame:Hide(); closeWindow()
    gmb:Click(); W.tick(0.05, 2)
    check("#30 the Game Menu's XayaUI button with the menu closed: no HideUIPanel call", hidList() == "SettingsPanel", hidList())
    closeWindow(); GameMenuFrame:Show(); W.enterCombat()
    gmb:Click(); W.tick(0.05, 2)
    check("#30 the Game Menu's XayaUI button in combat: the menu closes with :Hide (no HideUIPanel) and the settings window waits (V26)",
      not GameMenuFrame:IsShown() and hidList() == "SettingsPanel" and not ns.IsOptionsOpen(), hidList())
    W.leaveCombat(); W.tick(0.05, 2); closeWindow(); GameMenuFrame:Show()
    gmb:Click(); W.tick(0.05, 2)
    check("#30 ...out of combat with the menu shown: HideUIPanel(GameMenuFrame) once, and the settings window opens",
      hidList() == "SettingsPanel,GameMenuFrame" and ns.IsOptionsOpen(), hidList())
  end
  HideUIPanel = rawHide
end
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Options", "XayaUI_Debug")]   # (round 7: /xui debug is XayaUI_Debug's)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    w = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), w,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled},
                     # (round 7, SD-58 / SD-61) /xui debug runs only while Advanced Debugging is on (off for a new install): saved on here
                     "saved": {"XayaUI": {"CueRulesDB": {"ui": {"consoleAutoOpen": False, "advancedDebug": True}}}}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, w, loader)
    total, bad = 0, 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        total += 1; bad += 0 if ok else 1
    errs = [str(w.errors[i])[:600] for i in range(1, len(w.errors) + 1)]
    for x in errs:
        print("ERROR in the game stand-in: %s" % x)
    print("%d checks, %d failed, %d Lua errors" % (total, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
