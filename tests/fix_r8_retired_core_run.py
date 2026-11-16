#!/usr/bin/env python3
"""Bundle 1 round 8, core code that served only the retired QA-branch addons is removed (round 7 core blocker; V34 audit, its section
"Core code that serves only retired QA-branch addons", which she did not object to; REQUEST-LOG A23 SD-69, her tick "Remove dead
SectionTabs"; V30: main holds XayaUI, XayaUI_Options and XayaUI_Rules, the retired addons live on qa-installer-branch with their own copy
of core). A part was removed only when nothing in XayaUI, XayaUI_Options, XayaUI_Rules or XayaUI_Debug calls it and it changes no saved
data; players' saved settings are never deleted.
What the player gets, on the real addons in the stand-in game ([new] = fails on the pre-change files, proved on a private snapshot):
  M  [new] a saved minimap place "Chat sidebar" (where = "SIDEBAR", the retired XayaUI Chat's) no longer makes the minimap button vanish:
     it is on the minimap at login; Settings > Minimap Button has no "Show it in" choice any more; "Show the minimap button" still hides
     and shows it; the saved `where` value is kept as saved (not deleted), also after the logout.
  G  [new] the ESC-menu button no longer asks the retired Blizzard Reskin's "gameMenuSkin" service: with a stand-in service that says its
     own Esc Menu skin is on (as XayaUI Blizzard Reskin did), the XayaUI button is still drawn in the menu, and the service is never asked.
  C  [new] the minimap button no longer hands its changes to the retired chat sidebar ("chatSidebar" service): a stand-in service is
     never called.
  D  [new] "What to send" lists only XayaUI.lua, even with a stand-in "gameDataProbe" service (XayaUI Dev Assist's file); Settings >
     Debugging has no Dev Assist groups.
  K  /xuiskin with a word after it (once Dev Assist's "pad" / "alpha") prints only the one line saying what /xuiskin does and changes
     nothing (the same as before: with no Dev Assist the removed word list was empty); /xuiskin alone still switches the skin (control).
  R  [new] none of the removed hand-in points exists any more (a retired addon that called one would get nil, not a working hook):
     ns.SetDebugHooks, ns.RegisterReskin, ns.SetReskinTab, ns.RegisterConflict and the overlap flags, ns.InfoBox, ns.MapTrace,
     ns.SectionTabs (SD-69), ns.RegisterSubcommand, the unused reload-switch helpers, ns.SettingsSplitSub, ns.SettingsKeyMove,
     ns.DevAssistOn, the ESC-menu diagnostics and the chat sidebar hooks of the minimap button.
  S  the retired addons' saved settings are untouched: CueRulesDB.chat, .qol, .ui.rsk, .reskinTabOff and .minimap.where are the same
     after the login, a play and the logout.
UNVERIFIED IN GAME (a stand-in game: no real minimap, ESC menu or chat frame).
Run: python3 tests/fix_r8_retired_core_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
local W, L = ...
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function since(n) local t = {}; for i = n + 1, #W.printed do t[#t + 1] = plain(W.printed[i]) end; return t end
-- a stand-in Game Menu that works like Blizzard's (a button pool; AddButton; InitButtons releasing and re-adding every entry), as in
-- tests/core_off_costs_nothing_run.py: the stand-in game's own menu adds no buttons
local M = GameMenuFrame
local pool = { active = {}, free = {} }
function pool:EnumerateActive() local i, t = 0, self.active; return function() i = i + 1; return t[i] end end
M.buttonPool = pool
local nextIdx = 0
function M:AddButton(text, cb)
  local b = table.remove(pool.free) or CreateFrame("Button", nil, M)
  b:SetSize(200, 28); b:SetText(text); b:Show(); b:SetAlpha(1); nextIdx = nextIdx + 1; b.layoutIndex = nextIdx
  pool.active[#pool.active + 1] = b
  return b
end
function M:Layout() end
function M:InitButtons()
  for _, b in ipairs(pool.active) do b:Hide(); pool.free[#pool.free + 1] = b end
  pool.active = {}; nextIdx = 0
  for _, t in ipairs({ "Options", "AddOns", "Macros", "Log Out", "Return to Game" }) do self:AddButton(t) end
  self:Layout()
end
local okAll, errAll = pcall(function()
L.startup()
local ns = rawget(_G, "XayaUI_NS")
-- stand-ins for the retired addons' services, provided the way those addons did (before the login)
local skinAsks, sidebarCalls = 0, 0
ns.Provide("gameMenuSkin", { Active = function() skinAsks = skinAsks + 1; return true end, MatchReal = function() skinAsks = skinAsks + 1; return false end })
ns.Provide("chatSidebar", { Refresh = function() sidebarCalls = sidebarCalls + 1 end })
ns.Provide("gameDataProbe", { savedFile = "XayaUI_DevTest.lua", savedWhat = "test captures", Open = function() end })
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.3, 10)

-- M
local b = rawget(_G, "XayaUIMinimapButton")
check("[new] M a saved place 'Chat sidebar' (where = SIDEBAR): the minimap button is on the minimap at login", b ~= nil and b:IsShown(),
  b and tostring(b:IsShown()) or "no button")
check("M ... and the saved place is kept as saved (not deleted)", CueRulesDB.minimap and CueRulesDB.minimap.where == "SIDEBAR",
  CueRulesDB.minimap and tostring(CueRulesDB.minimap.where))
-- C (every refresh of the button before round 8 handed the change to the sidebar service)
ns.Minimap_Refresh(); W.tick(0.05, 2)
check("[new] C the minimap button never calls the retired chat sidebar's service", sidebarCalls == 0, sidebarCalls)
-- the settings page
local okO = ns.LoadOptions and ns.LoadOptions(); W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local T = okO and ns.BuildOptionsTable and ns.BuildOptionsTable()
local mm = T and T.args.set and T.args.set.args.minimap
check("(sanity) Settings > Minimap Button is there", mm ~= nil and mm.args.show ~= nil)
check("[new] M Settings > Minimap Button has no 'Show it in' (Minimap / Chat sidebar / Both) choice", mm ~= nil and mm.args.where == nil)
if mm then
  mm.args.show.set({}, false); W.tick(0.05, 2)
  check("M 'Show the minimap button' off hides the button", b and not b:IsShown())
  mm.args.show.set({}, true); W.tick(0.05, 2)
  check("M ... and on shows it on the minimap again (with where still SIDEBAR)", b and b:IsShown() and CueRulesDB.minimap.where == "SIDEBAR")
end
check("[new] C ... the sidebar service was not called by those switches either", sidebarCalls == 0, sidebarCalls)

-- G
GameMenuFrame:Show(); GameMenuFrame:InitButtons(); W.tick(0.05, 3)
local gmb = rawget(_G, "XayaUI_GameMenuButton")
check("[new] G the ESC menu shows the XayaUI button although a 'gameMenuSkin' service says its own skin is on", gmb ~= nil and gmb:IsShown(),
  gmb and tostring(gmb:IsShown()) or "no button")
check("[new] G ... and that service is never asked", skinAsks == 0, skinAsks)
GameMenuFrame:Hide(); W.tick(0.05, 1)

-- D
local send = ns.SendText and ns.SendText() or ""
check("[new] D 'What to send' lists only XayaUI.lua, not a 'gameDataProbe' service's file", send:find("XayaUI.lua", 1, true) ~= nil
  and send:find("XayaUI_DevTest.lua", 1, true) == nil, send:match("3%. Send.-\n.-\n") or send:sub(1, 200))
local dbg = T and T.args.set and T.args.set.args.debug
check("[new] D Settings > Debugging has no Dev Assist groups and no developer file box", dbg ~= nil and dbg.args.devPages == nil
  and dbg.args.gameDump == nil and dbg.args.send and dbg.args.send.args.sendDev == nil)

-- K
CueRulesDB.ui = CueRulesDB.ui or {}
local pad0, off0 = CueRulesDB.ui.skinPad, CueRulesDB.ui.skinOff
local n = #W.printed
SlashCmdList.XUISKIN("pad 5")
local got = since(n)
check("K /xuiskin pad 5: one line saying what /xuiskin does, nothing else (no list of Dev Assist words), nothing changed",
  #got == 1 and got[1] == "XayaUI /xuiskin switches the settings window's skin on or off (type it without anything after it)."
  and CueRulesDB.ui.skinPad == pad0 and CueRulesDB.ui.skinOff == off0, table.concat(got, " / "))
n = #W.printed
SlashCmdList.XUISKIN("")
got = since(n)
check("K (control) /xuiskin alone still switches the skin", CueRulesDB.ui.skinOff ~= off0 and #got == 1 and got[1]:find("window skin", 1, true) ~= nil,
  table.concat(got, " / "))
SlashCmdList.XUISKIN("")

-- R
local gone = { "SetDebugHooks", "RegisterReskin", "SetReskinTab", "RegisterConflict", "DetectConflicts", "ConflictLoginLine", "Conflicts",
  "ConflictsFor", "ConflictPageText", "InfoBox", "infoBoxOpen", "MapTrace", "MapTraceCounts", "MapTraceOrder", "SectionTabs",
  "RegisterSubcommand", "RunSubcommand", "SubcommandList", "SubcommandHelp", "SwitchPending", "SwitchApplyNow", "SwitchCommand",
  "SwitchesHeld", "SettingsSplitSub", "SettingsKeyMove", "DevAssistOn", "GameMenuDiag", "GameMenu_DiagState", "Minimap_Where",
  "Minimap_TogglePopupAt", "Minimap_SidebarChanged",
  -- (bundle 1 round 9, REQUEST-LOG A23 SD-83, her answer "Remove both (Recommended)"; intended change: it was in the kept list below)
  "CaptureOutput" }
local still = {}
for _, k in ipairs(gone) do if ns[k] ~= nil then still[#still + 1] = k end end
check("[new] R none of the removed hand-in points exists (" .. #gone .. " names)", #still == 0, table.concat(still, ","))
local kept = { "SwitchInEffect", "SwitchSaveForReload", "ReskinTabOn", "ReskinTabSaved", "SaveReskinTab", "RegisterDebugCommand",
  "RunDebugCommand", "SettingsLegacyGet", "SettingsLegacyMerge", "ModuleMissingText", "Provide", "Service" }
local missing = {}
for _, k in ipairs(kept) do if type(ns[k]) ~= "function" then missing[#missing + 1] = k end end
check("R (control) what still has a caller or touches saved data is still there", #missing == 0, table.concat(missing, ","))

-- S
check("S the retired addons' saved settings are untouched after the login and a play", type(CueRulesDB.chat) == "table" and CueRulesDB.chat.keep == "chat"
  and type(CueRulesDB.qol) == "table" and CueRulesDB.qol.keep == "qol" and CueRulesDB.ui.rsk and CueRulesDB.ui.rsk.keep == "reskin"
  and CueRulesDB.reskinTabOff == true)
end)
check("the session ran to the end", okAll, errAll)
check("no Lua error", #W.errors == 0, W.errors[1])
local out = L.logout()
local db = out.XayaUI and out.XayaUI.CueRulesDB or {}
check("S ... and saved again at the logout, the minimap place too", type(db.chat) == "table" and db.chat.keep == "chat" and type(db.qol) == "table"
  and db.qol.keep == "qol" and type(db.ui) == "table" and type(db.ui.rsk) == "table" and db.ui.rsk.keep == "reskin" and db.reskinTabOff == true
  and type(db.minimap) == "table" and db.minimap.where == "SIDEBAR")
return R
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    saved = {"XayaUI": {"CueRulesDB": {"version": 1, "chat": {"keep": "chat"}, "qol": {"keep": "qol"}, "reskinTabOff": True,
                                      "ui": {"rsk": {"keep": "reskin"}, "msgDest": "chat"},
                                      "minimap": {"hide": False, "where": "SIDEBAR"}}}}
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, ...) return loadstring(src)(...) end")(LUA, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
