#!/usr/bin/env python3
"""V14 "off costs nothing" for XayaUI_Options and XayaUI_Bonus (Options 0.6.41, Bonus 0.6.12). Xaya, 2026-11-05: "anything that is
disabled in the addon through a tick box should NEVER LOAD or contribute to performance cost / demand in any way -- make this a
standing rule for all current and future feature / element builds".
Features: the settings window's driver and /xui debug perf frame counter (Options.lua), the debug console strip (Options.lua), "Use drafts"
(Drafts.lua), the four Tooltip features (Tooltips.lua, TooltipsUI.lua), Data Panels (DataPanels.lua), "Show Notepad",
its formatting tools and toolbar (Notepad.lua), "Accept notes shared by other XayaUI users" and the share pump (NotepadShare.lua), and the
Calculator (Calculator.lua).
Per feature: saved off at login -> no frame, event, OnUpdate, tooltip post-call or timer of it exists or runs; switched on through its
own settings switch -> it works (the visible result is checked); switched off -> it stops at once.
Loads the real addons (XayaUI, XayaUI_Media, XayaUI_Bonus, XayaUI_Options) in the stand-in game (tests/harness). What a file made is
found by wrapping CreateFrame and reading which addon file called it (the first XayaUI file on the call stack).
Labels: "(works)" checks that a feature works when on; "(as before)" a fact that was already true; "(sanity)" no Lua error. They pass
on the old code too. Every other check is a cost check and fails on Options 0.6.40 / Bonus 0.6.11 (origin/main 20b805c), see the
debug log.
Run: python3 tests/options_bonus_off_costs_nothing_run.py   (Lua 5.1 via lupa; opens the settings window, so it takes a little while)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[" .. MODE .. "] " .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end

-------------------------------------------------------------------------------------------------------------------------------------
-- meters: which addon file made a frame (the first XayaUI file on the call stack); calls of a few game functions by file
-------------------------------------------------------------------------------------------------------------------------------------
local function owner()
  for lv = 3, 40 do
    local info = debug.getinfo(lv, "S")
    if not info then break end
    local f = (info.source or ""):match("Interface/AddOns/(XayaUI[%w_]*/[%w_/]+%.lua)")
    if f then return f end
  end
  return "?"
end
local rawCreate = CreateFrame
CreateFrame = function(...) local f = rawCreate(...); rawset(f, "_owner", owner()); return f end
local calls = {}   -- [name] = { [file] = n }
local function meter(t, k, name)
  local raw = t[k]
  t[k] = function(...) local o = owner(); calls[name] = calls[name] or {}; calls[name][o] = (calls[name][o] or 0) + 1; if raw then return raw(...) end end
end
local function ncalls(name, file) return (calls[name] and calls[name][file]) or 0 end
meter(C_AddOns, "DoesAddOnExist", "DoesAddOnExist")
meter(C_ChatInfo, "RegisterAddonMessagePrefix", "RegisterPrefix")
local TT_, TTUI, DP, NP, NS, CALC, OPT, DR = "XayaUI_Bonus/Tooltips.lua", "XayaUI_Bonus/TooltipsUI.lua", "XayaUI_Bonus/DataPanels.lua",
  "XayaUI_Bonus/Notepad.lua", "XayaUI_Bonus/NotepadShare.lua", "XayaUI_Bonus/Calculator.lua", "XayaUI_Options/Options.lua", "XayaUI_Options/Drafts.lua"
local function owned(file) local l = {}; for _, o in ipairs(W.objects) do if rawget(o, "_owner") == file then l[#l + 1] = o end end; return l end
local function frames(file) return #owned(file) end
local function events(file)
  local set, list = {}, {}
  for _, o in ipairs(owned(file)) do for e in pairs(o._events) do if not set[e] then set[e] = true; list[#list + 1] = e end end end
  table.sort(list)
  return #list, table.concat(list, ","), set
end
local function onupdates(file) local n = 0; for _, o in ipairs(owned(file)) do if o._scripts.OnUpdate then n = n + 1 end end; return n end
local function liveOnUpdates(prefix)   -- OnUpdate scripts that run now (set, on a visible frame), on frames of files under prefix
  local n = 0
  for _, o in ipairs(W.objects) do
    local f = rawget(o, "_owner") or ""
    if f:sub(1, #prefix) == prefix and o._scripts.OnUpdate and o:IsVisible() then n = n + 1 end
  end
  return n
end
local function cost(file)
  local ne, le = events(file)
  return ("%d frames, %d events (%s), %d OnUpdate"):format(frames(file), ne, le, onupdates(file))
end
local function nothing(file) return frames(file) == 0 and events(file) == 0 and onupdates(file) == 0 end
local function posts() return #(W.tooltipPostCalls or {}) end
local tipLines = {}
rawset(GameTooltip, "AddDoubleLine", function(self, a, b) tipLines[#tipLines + 1] = tostring(a) .. " " .. tostring(b) end)
local function hoverSpell(id)   -- the game runs every post-call registered for spell tooltips (Enum.TooltipDataType.Spell)
  tipLines = {}
  for _, p in ipairs(W.tooltipPostCalls or {}) do if p[1] == Enum.TooltipDataType.Spell then p[2](GameTooltip, { id = id }) end end
  return table.concat(tipLines, " / ")
end

-------------------------------------------------------------------------------------------------------------------------------------
-- load and log in
-------------------------------------------------------------------------------------------------------------------------------------
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
check("(sanity) core and Bonus loaded", ns ~= nil and ns.TT ~= nil and ns.BuildNotepadTab ~= nil)
if not (ns and ns.TT) then return R end
local TT = ns.TT
local refreshes = 0
local rawRefresh = ns.Notepad_Refresh
ns.Notepad_Refresh = function(...) refreshes = refreshes + 1; return rawRefresh(...) end
local idCalls = 0
local rawOnID = TT.OnIDData
TT.OnIDData = function(...) idCalls = idCalls + 1; return rawOnID(...) end
local copies = 0   -- deep copies of rules made by Drafts.lua
local rawCopy = ns.Copy
ns.Copy = function(...) if owner() == DR then copies = copies + 1 end; return rawCopy(...) end
local noop = function() end
local function ttSwitch(group, v) local o = ns.BuildTooltipsTab(noop).args[group].args.enabled; o.set({}, v); W.tick(0.05, 2) end
local function npTab() return ns.BuildNotepadTab(noop) end
local function dpTab() return ns.BuildDataPanelsTab(noop) end
local function chatAddon(msg) W.fire("CHAT_MSG_ADDON", "XUINOTE", msg, "PARTY", "Friend-Realm", "", 0, 0, "", 0) end
local function offer() local o = rawget(_G, "XayaUINoteOffer"); return o ~= nil and o:IsShown() end

-- the settings window
local ACD
local function openWindow() if not (ACD and ACD.OpenFrames and ACD.OpenFrames.CueRules) then pcall(ns.ToggleUI) end; W.tick(0.05, 6); ACD = LibStub("AceConfigDialog-3.0") end
local function closeWindow() if ACD and ACD.OpenFrames and ACD.OpenFrames.CueRules then pcall(ns.ToggleUI) end; W.tick(0.05, 2) end

if MODE == "off" then
  ---------------------------------------------------------------------------------------------------------------------------------
  -- A. Bonus features saved off: after login, nothing of them exists or runs
  ---------------------------------------------------------------------------------------------------------------------------------
  check("A1 all five Tooltip features saved off (Type colours since Bonus 0.6.20): no tooltip post-call is installed (10 before)", posts() == 0, posts())
  check("A2 ...and Tooltips.lua / TooltipsUI.lua made no frame and registered no event", nothing(TT_) and nothing(TTUI), cost(TT_) .. " | " .. cost(TTUI))
  check("A3 ...hovering a spell runs no XayaUI code and adds no line", hoverSpell(133) == "" and idCalls == 0, idCalls)
  W.fire("PLAYER_REGEN_DISABLED"); W.fire("PLAYER_REGEN_ENABLED"); W.fire("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
  check("A4 ...combat end and a spec change do not look for the class's formula data addon (Formulas off)", ncalls("DoesAddOnExist", TT_) == 0,
    ncalls("DoesAddOnExist", TT_))
  check("A5 Data Panels saved off (a panel enabled under it): DataPanels.lua made no frame, event or OnUpdate", nothing(DP), cost(DP))
  check("A6 Notepad saved hidden: no Notepad box (about 34 frames before) and no event of Notepad.lua", rawget(_G, "XayaUINotepad") == nil and nothing(NP), cost(NP))
  refreshes = 0
  W.fire("PLAYER_REGEN_DISABLED"); W.fire("PLAYER_REGEN_ENABLED")
  check("A7 ...a combat start and end do not restyle a hidden Notepad", refreshes == 0, refreshes)
  check("A8 'Accept shared notes' saved off, nothing to send: NotepadShare.lua made no frame, event or OnUpdate (the send pump ran every frame)",
    nothing(NS), cost(NS))
  check("A9 ...and the XUINOTE prefix was not registered at login", ncalls("RegisterPrefix", NS) == 0, ncalls("RegisterPrefix", NS))
  chatAddon("D|wxyz|1|2|first half of a note, ")
  npTab().args.share.args.accept.set({}, true); W.tick(0.05, 2)
  chatAddon("D|wxyz|2|2|second half.")
  check("A10 ...a part of a shared note that came while it was off is not kept: switched on, the second part alone offers nothing", not offer())
  check("(as before) A11 the Calculator makes nothing until it is opened", frames(CALC) == 0, cost(CALC))
  check("(as before) A12 the settings window is not loaded at login (LoadOnDemand)", frames(OPT) == 0 and frames(DR) == 0)

  ---------------------------------------------------------------------------------------------------------------------------------
  -- B. switched on through each feature's own settings switch: it works; switched off again: it stops at once
  ---------------------------------------------------------------------------------------------------------------------------------
  -- B1-B6 Tooltips (Bonus Features > Tooltips)
  ttSwitch("ids", true)
  check("(works) B1 'Show IDs on tooltips' on: the post-calls are installed and a spell shows its ID", posts() == 10 and hoverSpell(133):find("Spell ID: 133", 1, true) ~= nil,
    posts() .. " | " .. hoverSpell(133))
  local _, l1, s1 = events(TT_)
  local _, l1b, s1b = events(TTUI)   -- (up to Bonus 0.6.11 they were on TooltipsUI.lua's frame)
  check("(works) B2 ...the spec / talent / Cooldown Manager events are registered (the aura links follow a spec change)",
    (s1.ACTIVE_PLAYER_SPECIALIZATION_CHANGED or s1b.ACTIVE_PLAYER_SPECIALIZATION_CHANGED)
    and (s1.COOLDOWN_VIEWER_DATA_LOADED or s1b.COOLDOWN_VIEWER_DATA_LOADED), l1 .. " | " .. l1b)
  ttSwitch("ids", false)
  idCalls = 0
  check("B3 all five off again: hovering a spell runs no XayaUI code (the post-calls return at once) and adds no line", hoverSpell(133) == "" and idCalls == 0, idCalls)
  check("B4 ...and every event is let go", events(TT_) == 0, cost(TT_))
  ttSwitch("formulas", true)
  local d0 = ncalls("DoesAddOnExist", TT_)
  W.fire("PLAYER_REGEN_ENABLED")
  check("(works) B5 'Show formula lines' on: combat end looks for the class's formula data addon again", ncalls("DoesAddOnExist", TT_) > d0, ncalls("DoesAddOnExist", TT_) - d0)
  ttSwitch("formulas", false)
  local d1 = ncalls("DoesAddOnExist", TT_)
  W.fire("PLAYER_REGEN_ENABLED"); W.fire("TRAIT_CONFIG_UPDATED")
  check("B6 ...off again: combat end and a talent change look for nothing", ncalls("DoesAddOnExist", TT_) == d1 and events(TT_) == 0, cost(TT_))
  -- B7-B10 Data Panels (its tick box on the Bonus Features row)
  dpTab().xuiSwitch.set({}, true); W.tick(0.1, 5)
  local bl = rawget(_G, "XayaUIDataPanel_bl")
  local _, l7, s7 = events(DP)
  check("(works) B7 master switch on: the enabled panel is shown", bl ~= nil and bl:IsShown())
  check("(works) B8 ...its driver runs (four events, one OnUpdate)", s7.PLAYER_REGEN_DISABLED and s7.PLAYER_EQUIPMENT_CHANGED and onupdates(DP) == 1, l7)
  dpTab().xuiSwitch.set({}, false); W.tick(0.1, 2)
  check("(works) B9 master off: the panel is hidden", bl and not bl:IsShown())
  check("B10 ...and the driver's events and OnUpdate are let go", events(DP) == 0 and onupdates(DP) == 0, cost(DP))
  -- B11-B17 Notepad's "Show Notepad" (on its page since Bonus 0.6.14; the row's tick box is the whole feature: bonus_feature_switches_run.py)
  npTab().args.show.set({}, true); W.tick(0.05, 2)
  local box = rawget(_G, "XayaUINotepad")
  local n11, l11 = events(NP)
  check("(works) B11 'Show Notepad' on: the box is shown, with its toolbar", box ~= nil and box:IsShown() and box.tb ~= nil and box.tb:IsShown())
  check("(works) B12 ...its combat and logout events are registered", n11 == 3, l11)
  check("B13 ...'Formatting tools' off: the format bar is not built (it was built hidden)", box and box.fb == nil, tostring(box and box.fb))
  npTab().args.fmt.set({}, true); W.tick(0.05, 1)
  check("(works) B14 'Formatting tools' on: the format bar is built and shown", box.fb ~= nil and box.fb:IsShown())
  npTab().args.show.set({}, false); W.tick(0.05, 1)
  check("(works) B15 'Show Notepad' off: hidden", not box:IsShown())
  check("B16 ...and its events are let go", events(NP) == 0, cost(NP))
  refreshes = 0
  W.fire("PLAYER_REGEN_DISABLED"); W.fire("PLAYER_REGEN_ENABLED")
  check("B17 ...a combat start and end then restyle nothing", refreshes == 0, refreshes)
  -- B18-B21 Accept shared notes (switched on in A10)
  local _, l18, s18 = events(NS)
  check("(works) B18 'Accept shared notes' on: addon messages are listened to, the prefix is registered", s18.CHAT_MSG_ADDON and ncalls("RegisterPrefix", NS) == 1, l18)
  chatAddon("D|abcd|1|1|A whole note in one part.")
  check("(works) B19 ...a shared note is offered", offer())
  local of = rawget(_G, "XayaUINoteOffer"); if of then of:Hide() end
  npTab().args.share.args.accept.set({}, false); W.tick(0.05, 1)
  check("B20 switched off: addon messages are let go", not select(3, events(NS)).CHAT_MSG_ADDON, cost(NS))
  chatAddon("D|efgh|1|1|Another note.")
  check("(works) B21 ...and nothing is offered", not offer())
  -- B22-B25 Calculator
  ns.Calculator_Open(); W.tick(0.05, 1)
  local calc = rawget(_G, "XayaUICalculator")
  check("(works) B22 the Calculator opened: shown", calc ~= nil and calc:IsShown())

  ---------------------------------------------------------------------------------------------------------------------------------
  -- C. the settings window (XayaUI_Options), drafts off (the default)
  ---------------------------------------------------------------------------------------------------------------------------------
  openWindow()
  check("(sanity) C0 the settings window opened", ACD and ACD.OpenFrames and ACD.OpenFrames.CueRules ~= nil)
  check("C1 'Use drafts' off: opening the window copies no rule (each of the " .. #ns.rules .. " was deep-copied at every opening)", copies == 0, copies)
  check("C2 ...and nothing waits for the logout (Drafts.lua's PLAYER_LOGOUT)", events(DR) == 0, cost(DR))
  check("(works) C3 the window's driver runs while it is open", liveOnUpdates("XayaUI_Options/") >= 1, liveOnUpdates("XayaUI_Options/"))
  -- previews and the Rules sub-tab end / are kept when the window closes
  pcall(ACD.SelectGroup, ACD, "CueRules", "cooldowns", "smartTab"); W.tick(0.05, 3)
  ns.SetPreview({ ns.rules[1] }, "visual", true)
  local tray = rawget(_G, "CueRulesTray")
  check("(works) C4 a preview is on, the debug console strip is shown", ns.AnyPreview() and tray ~= nil and tray:IsShown())
  closeWindow()
  check("(works) C5 window closed: the preview is cleared at once, the strip is hidden, the open Rules sub-tab is saved",
    not ns.AnyPreview() and not tray:IsShown() and CueRulesDB.ui.rulesSub == "smartTab", tostring(ns.AnyPreview()) .. " " .. tostring(CueRulesDB.ui.rulesSub))
  check("C6 ...and no OnUpdate of XayaUI_Options runs while it is closed (the driver and the /xui debug perf counter ran every frame)",
    liveOnUpdates("XayaUI_Options/") == 0, liveOnUpdates("XayaUI_Options/"))
  local asks = 0
  local rawAny = ns.AnyPreview
  ns.AnyPreview = function(...) asks = asks + 1; return rawAny(...) end
  W.tick(0.1, 20)
  ns.AnyPreview = rawAny
  check("C7 ...two seconds with the window closed: the driver does no work (it read the previews every 0.25 s)", asks == 0, asks)
  local drawn = {}
  rawset(tray.log, "AddMessage", function(self, line) drawn[#drawn + 1] = tostring(line) end)
  ns.Log("a line while the window is closed")
  check("C8 a log line while the window is closed is not drawn into the hidden debug strip", #drawn == 0, #drawn)
  openWindow()
  local missed = false
  for _, l in ipairs(drawn) do if l:find("a line while the window is closed", 1, true) then missed = true end end
  check("(works) C9 the window opened again: the strip shows the line it missed", tray:IsShown() and missed, table.concat(drawn, " / "))
  -- undo with drafts off: the first edit of a rule can still be undone
  local rule
  for _, r in ipairs(ns.rules) do if not r.parentUid and r.isCue ~= true and type(r.uid) == "string" then rule = r; break end end
  local uid, group = rule.uid, 0
  for _, r in ipairs(ns.rules) do if (r.uid == uid and not r.parentUid) or r.parentUid == uid then group = group + 1 end end
  copies = 0
  ns.OptionsApi.EditRule(rule); W.tick(0.05, 6)
  check("C10 drafts off: showing a rule copies that rule (with its cues) only, " .. group .. " of " .. #ns.rules, copies == group, copies)
  rule.xuiTestEdit = 1; ns.MarkDirty(); W.tick(0.1, 10)
  pcall(ns.UndoKey, false); W.tick(0.05, 2)
  local now
  for _, r in ipairs(ns.rules) do if r.uid == uid and not r.parentUid then now = r end end
  check("(works) C11 ...Ctrl+Z after the first edit puts the rule back as it was when it was shown", now and now.xuiTestEdit == nil, now and now.xuiTestEdit)
  closeWindow()
  -- /xui debug perf: its frame counter runs only while tracing
  ns.perf = ns.perf or { n = 0 }; ns.perf.show = true
  openWindow()
  check("(works) C12 /xui debug perf on: the frame counter runs", liveOnUpdates("XayaUI_Options/") >= 2, liveOnUpdates("XayaUI_Options/"))
  closeWindow()
  ns.perf.show = false
  W.tick(0.05, 2)
  check("C13 /xui debug perf off, window closed: nothing of XayaUI_Options runs", liveOnUpdates("XayaUI_Options/") == 0, liveOnUpdates("XayaUI_Options/"))
elseif MODE == "defaults" then
  ---------------------------------------------------------------------------------------------------------------------------------
  -- D. a fresh install: what is on by default works, what is off by default costs nothing
  ---------------------------------------------------------------------------------------------------------------------------------
  check("(works) D1 the Tooltip features are on by default: the post-calls are installed, a spell shows its ID", posts() == 10
    and hoverSpell(133):find("Spell ID: 133", 1, true) ~= nil, posts())
  local _, ld, setd = events(TT_)
  check("D2 ...no INSPECT_READY is registered while no inspect request waits", not setd.INSPECT_READY, ld)
  check("D3 Data Panels off by default: nothing of DataPanels.lua exists", nothing(DP), cost(DP))
  check("D4 Notepad hidden by default: nothing of Notepad.lua exists", rawget(_G, "XayaUINotepad") == nil and nothing(NP), cost(NP))
  local _, ls, sets = events(NS)
  check("(works) D5 'Accept shared notes' is on by default: addon messages are listened to", sets.CHAT_MSG_ADDON, ls)
  check("D6 ...nothing to send: the send pump does not run", onupdates(NS) == 0, cost(NS))
  local sent0 = #W.addonMessages
  local okS = ns.NotepadShare_Send("A note to share.", "PARTY")
  check("(works) D7 sharing a note: the pump runs and sends it", okS and onupdates(NS) == 1, cost(NS))
  W.tick(0.1, 10)
  check("(works) D8 ...the note went out", #W.addonMessages > sent0, #W.addonMessages - sent0)
  check("D9 ...queue empty: the pump stops", onupdates(NS) == 0, cost(NS))
elseif MODE == "on" then
  ---------------------------------------------------------------------------------------------------------------------------------
  -- E. saved on at login: each works from the start
  ---------------------------------------------------------------------------------------------------------------------------------
  local box = rawget(_G, "XayaUINotepad")
  check("(works) E1 Notepad saved shown: the box is shown after login", box ~= nil and box:IsShown())
  check("E2 ...'Show toolbar' and 'Formatting tools' saved off: neither bar is built (both were built hidden)", box and box.tb == nil and box.fb == nil)
  W.tick(0.5, 2)
  local bl = rawget(_G, "XayaUIDataPanel_bl")
  check("(works) E3 Data Panels saved on: the panel is shown, its driver runs", bl ~= nil and bl:IsShown() and onupdates(DP) == 1, cost(DP))
  openWindow()
  check("(works) E4 'Use drafts' on: opening the window keeps every rule's saved version", copies >= #ns.rules, copies .. " of " .. #ns.rules)
  local _, le, sete = events(DR)
  check("(works) E5 ...and the logout moves unsaved rules to Drafts (PLAYER_LOGOUT registered while the window is open)", sete.PLAYER_LOGOUT, le)
  closeWindow()
  check("E6 window closed: the logout watch is let go", events(DR) == 0, cost(DR))
end
return R
end
'''


def rules(n):   # in one group, which the sidebar shows collapsed (a long list of rows makes the stand-in's layout slow)
    out = []
    for i in range(1, n + 1):
        out.append({"uid": "u%02d" % i, "name": "Rule %d" % i, "enabled": True, "folder": "g1", "useBuff": True, "buffID": 1000 + i,
                    "buffState": "present", "cdState": "none", "load": {"mode": "always"}})
    return out


FOLDERS = [{"id": "g1", "name": "Test group"}]


def saved_for(mode):
    if mode == "off":
        return {"XayaUI": {"CueRulesDB": {
            "rules": rules(2), "folders": FOLDERS,
            "tooltips": {"ids": {"enabled": False}, "ilvl": {"enabled": False}, "forces": {"enabled": False}, "formulas": {"enabled": False},
                         "typeColors": {"enabled": False}},   # (Bonus 0.6.20: the fifth section, Type colours)
            "dataPanels": {"general": {"enabled": False}, "bl": {"enabled": True}},
            "notepad": {"shown": False, "acceptShares": False},
            "ui": {"consoleAutoOpen": False}}}}
    if mode == "on":
        return {"XayaUI": {"CueRulesDB": {
            "rules": rules(2), "folders": FOLDERS,
            "dataPanels": {"general": {"enabled": True}, "bl": {"enabled": True}},
            "notepad": {"shown": True, "toolbar": False, "format": False},
            "ui": {"promptSave": True, "consoleAutoOpen": False}}}}
    return {}


def world(mode):
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Media", "XayaUI_Bonus", "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    w = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), w,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved_for(mode)}))
    res = L.eval("function(src, W, Ld, mode) return loadstring(src)()(W, Ld, mode) end")(LUA, w, loader, mode)
    return res, w


def main():
    total, bad, errs = 0, 0, 0
    for mode in ("off", "defaults", "on"):
        res, w = world(mode)
        for i in range(1, len(res) + 1):
            name, ok = res[i][1], res[i][2]
            print(("PASS " if ok else "FAIL ") + name)
            total += 1
            if not ok:
                bad += 1
        for i in range(1, len(w.errors) + 1):
            print("ERROR in the game stand-in [%s]: %s" % (mode, str(w.errors[i])[:700]))
            errs += 1
    print("%d checks, %d failed, %d Lua errors" % (total, bad, errs))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
