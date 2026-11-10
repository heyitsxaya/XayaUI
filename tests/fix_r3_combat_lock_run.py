#!/usr/bin/env python3
"""V26 combat lock (Xaya 2026-11-10, docs/process/VERIFICATION.md V26): "unless flagged for exemption (e.g. debugging), /xui and its
editing windows cannot be opened in active combat". Her answers: asked in combat -> one plain chat line, and it opens by itself when
combat ends (only the last request kept); open when combat starts -> it closes then (unsaved rule edits go to Drafts as on any close)
and reopens where she was when combat ends. Locked: the settings window and the rule editor (every way it opens: /xui, /xui config,
/xui options, ns.EditRule, ns.EditFolder, ns.OpenSettingsPage, the minimap button, the ESC-menu button), the mover (/xui unlock), the
Combat Tracking Setup window, /xui debug talents (the scan), /xui enable. Exempt: /xui report, /xui bug, /xui console, /xui status,
/xui auras, /xui debug status / loader / perf, /xui debug talents status, and /xui disable ("/xui disable: all rules off": every rule
stops, every display and sound stops, until /xui enable or /reload).
Every check is what the player sees or gets: whether a window is on screen, which line is printed, where the window opens, whether a
rule's display shows and its sound plays. Combat runs as in the game (tests/harness/world.lua W.enterCombat: PLAYER_REGEN_DISABLED, then
the lockdown; W.leaveCombat: the lockdown ends, then PLAYER_REGEN_ENABLED).
Checks marked "(control)" pass on the old code too; every other check fails on the files before this change.
Run: python3 tests/fix_r3_combat_lock_run.py   (Lua 5.1 via lupa; loads XayaUI, XayaUI_Rules and XayaUI_Options in the stand-in game)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
check("(control) XayaUI loaded", ns ~= nil and SlashCmdList.XAYAUI ~= nil)
if not ns then return end
MenuUtil.CreateContextMenu = function() end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
-- every line XayaUI prints, in order
local lines = {}
local realPrint = ns.Print
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; lines[#lines + 1] = table.concat(t, " ") end
local function mark() return #lines end
local function since(m) local t = {}; for i = m + 1, #lines do t[#t + 1] = lines[i] end; return t end
local function has(list, pat) for _, l in ipairs(list) do if l:lower():find(pat, 1, true) then return true end end; return false end
local function joined(list) return table.concat(list, " / ") end
local slash = function(s) SlashCmdList.XAYAUI(s); W.tick(0.05, 2) end
local function fight() W.enterCombat(); W.tick(0.05, 2) end
local function peace() W.leaveCombat(); W.tick(0.1, 6) end
local APP = "CueRules"
local ACD   -- (the window's libraries load with the settings addon)
local function windowOpen()
  ACD = ACD or LibStub("AceConfigDialog-3.0", true)
  return ACD ~= nil and ACD.OpenFrames[APP] ~= nil and ACD.OpenFrames[APP].frame:IsShown()
end

-- two rules in a group (the second one is edited below)
ns.folders = { { id = "f1", name = "Defensives" } }
CueRulesDB.folders = ns.folders
ns.rules = {}
for i = 1, 3 do
  local r = ns.NewRule(); r.name = "Rule " .. i; r.enabled = true; r.useBuff = true; r.buffID = 1000 + i; r.buffState = "present"
  r.spellID = 2000 + i; if i > 1 then r.folder = "f1" end
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
end
CueRulesDB.rules = ns.rules
if ns.MarkDirty then ns.MarkDirty() end
W.tick(0.1, 4)

-------------------------------------------------------------------------------------------------------------------------------------
-- A. /xui in combat: one line, the window stays shut; it opens by itself when combat ends
-------------------------------------------------------------------------------------------------------------------------------------
fight()
local m = mark()
slash("")
local got = since(m)
local shutA = not windowOpen()
check("A1 /xui in combat: the settings window does not open", shutA)
check("A2 /xui in combat: one plain line says it opens when combat ends", #got == 1 and has(got, "can't open during combat") and has(got, "when combat ends"), joined(got))
check("A3 /xui in combat: the window's code is not even loaded during the fight", ns.Options == nil, tostring(ns.Options))
peace()
check("A4 combat ends: the settings window (shut through the fight) opens by itself", shutA and windowOpen())
slash(""); W.tick(0.1, 4)
check("(control) /xui out of combat closes it again", not windowOpen())

-------------------------------------------------------------------------------------------------------------------------------------
-- B. every other way the window opens: /xui config, /xui options, the minimap button, the ESC-menu button, ns.EditRule, ns.EditFolder,
--    ns.OpenSettingsPage, the game's AddOns entry (compartment) -- each one line in combat, nothing on screen until combat ends
-------------------------------------------------------------------------------------------------------------------------------------
local mm = rawget(_G, "XayaUIMinimapButton")
GameMenuFrame:InitButtons(); GameMenuFrame:Show(); W.tick(0.05, 2)   -- (the ESC menu builds its entries; XayaUI adds its button)
local esc = rawget(_G, "XayaUI_GameMenuButton")
GameMenuFrame:Hide(); W.tick(0.05, 1)
check("(control) the minimap button and the ESC-menu button exist", mm ~= nil and esc ~= nil, tostring(mm) .. " " .. tostring(esc))
local ways = {
  { "/xui config", function() slash("config") end },
  { "/xui options", function() slash("options") end },
  { "the minimap button (right-click)", function() if mm then mm:GetScript("OnClick")(mm, "RightButton") end end },
  { "the ESC-menu button", function() if esc then esc:GetScript("OnClick")(esc, "LeftButton") end end },
  { "the addon compartment", function() XayaUI_OnCompartmentClick() end },
  { "ns.EditRule (a display's Edit This Aura)", function() ns.EditRule(ns.rules[2]) end },
  { "ns.EditFolder (a group's click)", function() ns.EditFolder(ns.folders[1]) end },
  { "ns.OpenSettingsPage", function() ns.OpenSettingsPage("core", "settings") end },
  { "ns.ToggleUI (the window's own code)", function() ns.ToggleUI() end },
  { "ns.Options.Toggle (the settings addon itself)", function() ns.Options.Toggle() end },
  { "ns.Options.OpenPage (the settings addon itself)", function() ns.Options.OpenPage("core", "settings") end },
}
for i, w in ipairs(ways) do
  fight()
  m = mark()
  pcall(w[2]); W.tick(0.05, 2)
  got = since(m)
  local shut = not windowOpen()
  peace()
  local opened = windowOpen()
  check(("B%d %s in combat: nothing opens, one line; it opens when combat ends"):format(i, w[1]),
    shut and #got == 1 and has(got, "during combat") and opened, ("shut=%s lines=%s opened=%s"):format(tostring(shut), joined(got), tostring(opened)))
  if windowOpen() then ns.Options.Toggle(); W.tick(0.1, 4) end
end
-- the rule editor opens on the rule asked for
fight(); ns.EditRule(ns.rules[3]); W.tick(0.05, 2); local shutB = not windowOpen(); peace()
local S = ns.RulesTreeStatus and ns.RulesTreeStatus()
check("B12 ns.EditRule in combat: shut through the fight, then the editor shows that rule", shutB and windowOpen() and S and type(S.selected) == "string" and S.selected:match("rule3$") ~= nil,
  S and S.selected)
if windowOpen() then ns.Options.Toggle(); W.tick(0.1, 4) end

-------------------------------------------------------------------------------------------------------------------------------------
-- C. only the last request is kept: /xui, then /xui unlock, in one fight -> only the mover opens after
-------------------------------------------------------------------------------------------------------------------------------------
fight()
m = mark()
slash(""); slash("unlock")
got = since(m)
check("C1 /xui unlock in combat: the mover does not open, one line says it opens when combat ends",
  not ns.unlocked and has(got, "mover") and has(got, "when combat ends"), joined(got))
peace()
check("C2 combat ends: only the last request runs (the mover opens, the settings window stays shut)", ns.unlocked == true and not windowOpen(),
  ("unlocked=%s window=%s"):format(tostring(ns.unlocked), tostring(windowOpen())))
if ns.unlocked then ns.ToggleUnlock(); W.tick(0.1, 2) end

-------------------------------------------------------------------------------------------------------------------------------------
-- D. open when combat starts: it closes (unsaved rule edits go to Drafts), and opens again where she was when combat ends
-------------------------------------------------------------------------------------------------------------------------------------
ns.Settings("core").promptSave = true   -- "Prompt for saving and enable drafts" on: closing keeps unsaved rules in Drafts
if windowOpen() then ns.Options.Toggle(); W.tick(0.1, 4) end
if ns.unlocked then ns.ToggleUnlock(); W.tick(0.1, 2) end
slash(""); W.tick(0.1, 4)
local path = { ns.OptionsApi.RuleEditorParts.RulePath(ns.rules[2]) }; path[#path + 1] = "trigger"
ACD:SelectGroup(APP, unpack(path)); W.tick(0.1, 4)
local function where()
  local p, st = {}, nil
  for _ = 1, 16 do
    st = ACD:GetStatusTable(APP, p)
    local sel = st and st.groups and st.groups.selected
    if type(sel) ~= "string" then break end
    for seg in sel:gmatch("[^\001]+") do p[#p + 1] = seg end
  end
  return table.concat(p, "/")
end
local before = where()
check("(control) the window shows Rule 2's Trigger tab", windowOpen() and before:match("trigger$") ~= nil, before)
ns.rules[2].repeatSec = 7; if ns.MarkDirty then ns.MarkDirty() end; W.tick(0.1, 2)   -- an unsaved edit: "repeat every 7 s"
local drafts0 = 0; for _ in pairs(ns.Settings("core").drafts or {}) do drafts0 = drafts0 + 1 end
m = mark()
fight()
got = since(m)
local drafts1 = 0; for _ in pairs(ns.Settings("core").drafts or {}) do drafts1 = drafts1 + 1 end
local shutD = not windowOpen()
check("D1 combat starts: the settings window closes", shutD)
local r2; for _, r in ipairs(ns.rules) do if r.name == "Rule 2" then r2 = r end end
check("D2 combat starts: the unsaved edit went to Drafts and the rule is back to its saved version", drafts1 == drafts0 + 1 and r2 ~= nil and (r2.repeatSec or 0) == 0,
  ("drafts %d -> %d, repeat %s"):format(drafts0, drafts1, tostring(r2 and r2.repeatSec)))
check("D3 combat starts: one plain line says it closed and will open again", has(got, "closed because combat started") and has(got, "when combat ends"), joined(got))
-- in the fight nothing else changes the window's place: a different page is asked for, then she asks for the window again (last wins)
peace()
local after = where()
check("D4 combat ends: the window (shut through the fight) opens again by itself, on the same rule and tab", shutD and windowOpen() and after == before, before .. " -> " .. after)
-- the window was moved to another page while it was shut: it still comes back where she was
fight()
ACD:SelectGroup(APP, "profiles"); W.tick(0.05, 2)
peace()
check("D5 combat ends: it reopens where she was even if the page changed while it was shut", windowOpen() and where() == before, where())
ns.Settings("core").promptSave = false
-- the window closed by hand: combat starts and ends, nothing opens
if windowOpen() then ns.Options.Toggle(); W.tick(0.1, 4) end
fight(); peace()
check("(control) D6 a window she closed herself does not open after combat", not windowOpen())

-------------------------------------------------------------------------------------------------------------------------------------
-- E. Combat Tracking Setup: locked like the settings window; open when combat starts -> closes, reopens on the same step after
-------------------------------------------------------------------------------------------------------------------------------------
if ns.AuraSetup_Open then
  fight()
  m = mark()
  ns.AuraSetup_Open()
  got = since(m)
  local sf = rawget(_G, "XayaUIAuraSetupFrame")
  local shutE = not (sf and sf:IsShown())
  check("E1 Combat Tracking Setup in combat: it does not open, one line says it opens when combat ends",
    shutE and #got == 1 and has(got, "when combat ends"), joined(got))
  peace()
  sf = rawget(_G, "XayaUIAuraSetupFrame")
  check("E2 combat ends: Combat Tracking Setup opens by itself", shutE and sf ~= nil and sf:IsShown())
  if sf and not sf:IsShown() then ns.AuraSetup_Open() end
  if sf then
    sf.next:GetScript("OnClick")(sf.next); sf.next:GetScript("OnClick")(sf.next); W.tick(0.05, 2)   -- step 3 (Review)
    check("(control) it shows step 3 (Finish setup)", sf.finish:IsShown())
    m = mark()
    fight()
    got = since(m)
    local shutE3 = not sf:IsShown()
    check("E3 combat starts: Combat Tracking Setup closes, with one line", shutE3 and has(got, "closed because combat started"), joined(got))
    peace()
    check("E4 combat ends: it (shut through the fight) opens again on step 3", shutE3 and sf:IsShown() and sf.finish:IsShown())
    sf:Hide()
  end
else
  check("E Combat Tracking Setup is loaded", false)
end

-------------------------------------------------------------------------------------------------------------------------------------
-- F. /xui debug talents (the scan) is locked; status is read-only and allowed
-------------------------------------------------------------------------------------------------------------------------------------
fight()
m = mark()
slash("debug talents")
got = since(m)
check("F1 /xui debug talents in combat: no scan, one line says it runs when combat ends", #got == 1 and has(got, "talent scan") and has(got, "when combat ends"), joined(got))
m = mark()
slash("debug talents status")
got = since(m)
check("(control) F2 /xui debug talents status in combat still answers (read-only)", has(got, "talent scan"), joined(got))
m = mark()
peace(); W.tick(0.1, 20)
got = since(m)
check("F3 combat ends: the talent scan runs by itself", #got >= 1 and not has(got, "during combat"), joined(got))

-------------------------------------------------------------------------------------------------------------------------------------
-- G. exempt in combat: /xui status, /xui auras, /xui report, /xui bug, /xui console, /xui debug loader / perf / status
-------------------------------------------------------------------------------------------------------------------------------------
fight()
local reportShown, bugShown, consoleShown = false, false, false
local sR, sB, sC = ns.ShowDebugReport, ns.ShowBugReport, ns.ConsoleWindow
ns.ShowDebugReport = function() reportShown = true end
ns.ShowBugReport = function() bugShown = true end
ns.ConsoleWindow = function() consoleShown = true end
m = mark(); slash("status"); local st = since(m)
m = mark(); slash("auras 12345"); local au = since(m)
slash("report"); slash("bug"); slash("console")
m = mark(); slash("debug loader"); local lo = since(m)
m = mark(); slash("debug perf"); local pf = since(m)
ns.ShowDebugReport, ns.ShowBugReport, ns.ConsoleWindow = sR, sB, sC
check("(control) G1 /xui status, /xui auras, /xui debug loader and perf answer in combat",
  #st > 0 and #au > 0 and #lo > 0 and #pf > 0 and not has(st, "during combat") and not has(lo, "during combat"), joined(st) .. " | " .. joined(lo))
check("(control) G2 /xui report, /xui bug and /xui console open in combat", reportShown and bugShown and consoleShown)
peace()
check("(control) G3 nothing exempt was queued: no window opens after the fight", not windowOpen() and not ns.unlocked)

-------------------------------------------------------------------------------------------------------------------------------------
-- H. /xui disable works in combat: every rule stops (no rule checked, no display, no sound) until /xui enable; /xui enable waits
-------------------------------------------------------------------------------------------------------------------------------------
-- a rule whose condition is true: its display shows and its sound plays (the rule check is the engine's real call, answered here)
local A = ns.rules[1]
A.visual.enabled = true; A.visual.trigger = "condition"; A.visual.kind = "spellicon"
A.sound.enabled = true; A.sound.source = "kit"; A.sound.value = "RAID_WARNING"; A.repeatSec = 1
local truth, checks = true, 0
local realEval = ns.Evaluate
ns.Evaluate = function(rule, ctx)
  if rule ~= A then return realEval(rule, ctx) end
  checks = checks + 1
  return truth, { ctxOK = true, talentOK = true, result = truth }
end
local sounds = 0
local realPlay = ns.PlaySound
ns.PlaySound = function(s) if s == A.sound then sounds = sounds + 1 end; return "kit" end
if ns.MarkDirty then ns.MarkDirty() end
W.tick(0.1, 15)
local function shown() local fs = ns.VisualFramesOf(A); return fs[1] ~= nil and fs[1]:IsShown() end
check("(control) H0 the rule fires: its display shows and its sound plays (and repeats)", shown() and sounds >= 1 and checks > 0, ("shown=%s sounds=%d"):format(tostring(shown()), sounds))
fight()
m = mark()
slash("disable")
got = since(m)
local c0, s0 = checks, sounds
W.tick(0.1, 30)   -- 3 seconds of fight (the rule's sound would repeat every second)
check("H1 /xui disable in combat: one line says every rule is off and how to turn them back on", #got == 1 and has(got, "off") and has(got, "/xui enable"), joined(got))
check("H2 /xui disable in combat: the rule's display is gone at once", not shown())
check("H3 /xui disable: no rule is checked and no sound plays for the rest of the fight", checks == c0 and sounds == s0,
  ("checks +%d, sounds +%d"):format(checks - c0, sounds - s0))
m = mark()
slash("enable")
got = since(m)
W.tick(0.1, 10)
check("H4 /xui enable in combat: one line says rules turn on when combat ends; they stay off", #got == 1 and has(got, "when combat ends") and checks == c0 and not shown(), joined(got))
local offH = checks == c0 and not shown()
peace(); W.tick(0.1, 10)
check("H5 combat ends: rules (off through the fight) are on again (the rule is checked, its display shows, its sound plays)", offH and checks > c0 and shown() and sounds > s0,
  ("checks +%d shown=%s sounds +%d"):format(checks - c0, tostring(shown()), sounds - s0))
-- disable out of combat, then enable out of combat: both at once
slash("disable"); W.tick(0.1, 10)
local c1 = checks
check("H6 /xui disable out of combat: the display goes, nothing is checked", not shown() and checks == c1)
m = mark(); slash("enable"); got = since(m); W.tick(0.1, 10)
check("H7 /xui enable out of combat: rules are on again at once, one line", checks > c1 and shown() and #got == 1 and has(got, "on again"), joined(got))
-- a waiting /xui enable is dropped by a later /xui disable in the same fight
fight(); slash("disable"); slash("enable"); slash("disable"); local c2 = checks; peace(); W.tick(0.1, 10)
check("H8 disable, enable, disable in one fight: rules stay off after combat (the last word wins)", checks == c2 and not shown())
slash("enable"); W.tick(0.1, 4)
-- /xui help lists both
m = mark(); slash("help"); got = since(m)
check("H9 /xui help lists /xui disable and /xui enable", has(got, "/xui disable") and has(got, "/xui enable"), #got)
ns.Evaluate, ns.PlaySound = realEval, realPlay
ns.Print = realPrint

end)
check("no Lua error in the test itself", okAll, errAll)
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    n = len(res)
    for i in range(1, n + 1):
        name, good = res[i][1], res[i][2]
        print(("PASS " if good else "FAIL ") + name)
        bad += 0 if good else 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
