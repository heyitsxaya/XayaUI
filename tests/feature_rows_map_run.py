#!/usr/bin/env python3
"""/xui debug in core: the diagnostic list and core's loader report (core 0.6.50 / 0.6.56; REQUEST-LOG #30 and #81).
This test began as the left-pane feature rows test (Enhanced Tooltips #45, the Character Toolkit's Tooltip lines #46, Notepad #47)
with the world map report /xui debug map (#30). Those features (XayaUI Bonus, XayaUI QoL, the Character Reskin) and the map report
(XayaUI Dev Assist, XayaUI_DevAssist/CoreDebug.lua) are not on this branch, so their checks left with them. What stays is core's
own part of it (XayaUI/Core.lua, CORE_DEBUG):
  - plain /xui debug lists the diagnostic commands and runs none of them; core's loader report is among them, and the map report is
    not (its help line is XayaUI Dev Assist's: "without it they and their help lines do not exist");
  - /xui debug loader is core's loader report, without the map report;
  - core's panel-layout counter (XayaUI/Modules.lua section 9, ns.MapTrace / ns.MapTraceCounts, kept on this branch: "XayaUI's own
    calls are counted whether or not Dev Assist is there") counts core's own two calls into Blizzard's panel manager, through their real
    call sites: the "Open XayaUI" button on the game's Options > AddOns page (Modules.lua, HideUIPanel(SettingsPanel)) and the XayaUI
    button in the Game Menu (GameMenuButton.lua, HideUIPanel(GameMenuFrame)); each only when it really calls it, and nothing else.
    (This replaces the old check through the Character Reskin's calls, which is not on this branch.)
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
local function run(msg) ns._capture = {}; pcall(SlashCmdList.XAYAUI, msg); local t = table.concat(ns._capture, " | "); ns._capture = nil; return t end
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
-- #30 the counter of XayaUI's calls into Blizzard's panel layout (Modules.lua section 9), through core's own two call sites
do
  local SP, GM = "core: HideUIPanel(SettingsPanel)", "core: HideUIPanel(GameMenuFrame)"
  local function counts() return ns.MapTraceCounts and ns.MapTraceCounts() or {} end
  local function n(key) local c = counts()[key]; return c and c.n or 0 end
  local function keys() local l = {}; for k, v in pairs(counts()) do l[#l + 1] = k .. " x" .. tostring(v.n) end; table.sort(l); return table.concat(l, "; ") end
  check("#30 the counter is core's (ns.MapTrace, ns.MapTraceCounts, ns.MapTraceOrder) and counted nothing through login and the /xui debug commands above",
    type(ns.MapTrace) == "function" and type(ns.MapTraceCounts) == "function" and type(ns.MapTraceOrder) == "function"
    and next(counts()) == nil and #ns.MapTraceOrder() == 0, keys())
  -- the "Open XayaUI" button on core's Options > AddOns page
  local open
  for _, o in ipairs(W.objects) do
    if addonsPanel and o:GetParent() == addonsPanel and o.GetText and o:GetText() == "Open XayaUI" then open = o end
  end
  check("(sanity) core's Options > AddOns page and its \"Open XayaUI\" button exist", addonsPanel ~= nil and open ~= nil)
  local function closeWindow() if ns.IsOptionsOpen() then ns.ToggleUI() end; W.tick(0.05, 2) end
  if open then
    SettingsPanel:Hide(); closeWindow()
    open:Click(); W.tick(0.05, 2)
    check("#30 \"Open XayaUI\" with the game's settings window closed: no HideUIPanel call, nothing counted (the window opens)",
      next(counts()) == nil and ns.IsOptionsOpen(), keys())
    SettingsPanel:Show(); closeWindow()
    open:Click(); W.tick(0.05, 2)
    check("#30 \"Open XayaUI\" with the game's settings window shown: core's HideUIPanel(SettingsPanel) is counted once, and only it",
      n(SP) == 1 and keys() == SP .. " x1" and counts()[SP].last ~= nil, keys())
    SettingsPanel:Hide()
  end
  -- the XayaUI button in the Game Menu (switched on by default; the menu's build makes it)
  GameMenuFrame:Show(); GameMenuFrame:InitButtons(); W.tick(0.05, 2)
  local gmb = rawget(_G, "XayaUI_GameMenuButton")
  check("(sanity) the Game Menu's XayaUI button exists", gmb ~= nil)
  if gmb then
    GameMenuFrame:Hide(); closeWindow()
    gmb:Click(); W.tick(0.05, 2)
    check("#30 the Game Menu's XayaUI button with the menu closed: nothing more counted", n(GM) == 0 and keys() == SP .. " x1", keys())
    closeWindow(); GameMenuFrame:Show(); W.enterCombat()
    gmb:Click(); W.tick(0.05, 2)
    check("#30 ...in combat (the menu is hidden with :Hide, not HideUIPanel): nothing more counted", n(GM) == 0 and keys() == SP .. " x1", keys())
    W.leaveCombat(); closeWindow(); GameMenuFrame:Show()
    gmb:Click(); W.tick(0.05, 2)
    check("#30 ...out of combat with the menu shown: core's HideUIPanel(GameMenuFrame) is counted once",
      n(GM) == 1 and counts()[GM].last ~= nil, keys())
  end
  local order = ns.MapTraceOrder and ns.MapTraceOrder() or {}
  check("#30 ...and the counter holds exactly core's two calls, once each, in the order they ran (nothing else counted)",
    keys() == GM .. " x1; " .. SP .. " x1" and #order == 2 and order[1] == SP and order[2] == GM, keys() .. " | " .. table.concat(order, ", "))
end
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    w = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), w,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled},
                     "saved": {"XayaUI": {"CueRulesDB": {"ui": {"consoleAutoOpen": False}}}}}))
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
