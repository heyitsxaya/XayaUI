#!/usr/bin/env python3
"""V14 "off costs nothing" for XayaUI_Options and the rule editor (Options 0.6.41; the rule editor's Drafts.lua, then in XayaUI_Rules_Options,
part of XayaUI Rules from Rules 0.7.0, part of XayaUI Options since bundle 1 round 7: XayaUI_Options/RuleEditor/Drafts.lua). Xaya, 2026-11-05: "anything that is disabled in the addon through a
tick box should NEVER LOAD or contribute to performance cost / demand in any way -- make this a standing rule for all current and future
feature / element builds".
Features: the settings window's driver and /xui debug perf frame counter (Options.lua), the debug console strip (Options.lua), "Use drafts"
(Drafts.lua). (This file also checked XayaUI Bonus Features' Tooltips, Data Panels, Notepad, shared notes and Calculator; those checks
were removed with that addon: it is not on this branch, REQUEST-LOG A23. The file keeps its name.)
Per feature: off -> no frame, event or OnUpdate of it exists or runs; on -> it works (the visible result is checked); switched off -> it
stops at once.
Loads the real addons of this branch (XayaUI, XayaUI_Rules with its rule editor, XayaUI_Options) in the stand-in game (tests/harness).
What a file made is found by wrapping CreateFrame and reading which addon file called it (the first XayaUI file on the call stack).
Labels: "(works)" checks that a feature works when on; "(as before)" a fact that was already true; "(sanity)" no Lua error. They pass
on the old code too. Every other check is a cost check and fails on Options 0.6.40 (origin/main 20b805c), see the debug log.
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
-- meters: which addon file made a frame (the first XayaUI file on the call stack)
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
local OPT, DR = "XayaUI_Options/Options.lua", "XayaUI_Options/RuleEditor/Drafts.lua"
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
    -- (bundle 1 round 7, SD-57) the settings window's rule editor is XayaUI_Options/RuleEditor/, under the window's own prefix (from Rules
    -- 0.7.0 to round 7 it was XayaUI_Rules/Editor/ and was counted as the window's here by name)
    local mine = f:sub(1, #prefix) == prefix
    if mine and o._scripts.OnUpdate and o:IsVisible() then n = n + 1 end
  end
  return n
end
local function cost(file)
  local ne, le = events(file)
  return ("%d frames, %d events (%s), %d OnUpdate"):format(frames(file), ne, le, onupdates(file))
end

-------------------------------------------------------------------------------------------------------------------------------------
-- load and log in
-------------------------------------------------------------------------------------------------------------------------------------
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
check("(sanity) core and Rules loaded", ns ~= nil and ns.LoadOptions ~= nil and type(ns.rules) == "table" and ns.Copy ~= nil)
if not (ns and ns.Copy) then return R end
local copies = 0   -- deep copies of rules made by Drafts.lua
local rawCopy = ns.Copy
ns.Copy = function(...) if owner() == DR then copies = copies + 1 end; return rawCopy(...) end

-- the settings window
local ACD
local function openWindow() if not (ACD and ACD.OpenFrames and ACD.OpenFrames.CueRules) then pcall(ns.ToggleUI) end; W.tick(0.05, 6); ACD = LibStub("AceConfigDialog-3.0") end
local function closeWindow() if ACD and ACD.OpenFrames and ACD.OpenFrames.CueRules then pcall(ns.ToggleUI) end; W.tick(0.05, 2) end

if MODE == "off" then
  ---------------------------------------------------------------------------------------------------------------------------------
  -- A. at login
  ---------------------------------------------------------------------------------------------------------------------------------
  check("(as before) A12 the settings window is not loaded at login (LoadOnDemand), nor the rule editor set up", frames(OPT) == 0 and frames(DR) == 0)

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
elseif MODE == "on" then
  ---------------------------------------------------------------------------------------------------------------------------------
  -- E. saved on at login: it works from the start
  ---------------------------------------------------------------------------------------------------------------------------------
  W.tick(0.5, 2)
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
            "ui": {"consoleAutoOpen": False}}}}
    if mode == "on":
        return {"XayaUI": {"CueRulesDB": {
            "rules": rules(2), "folders": FOLDERS,
            "ui": {"promptSave": True, "consoleAutoOpen": False}}}}
    return {}


def world(mode):
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")]
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
    for mode in ("off", "on"):
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
