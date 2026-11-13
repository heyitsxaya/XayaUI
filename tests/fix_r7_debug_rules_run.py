#!/usr/bin/env python3
"""Round 7 (bundle 1), XayaUI Rules' debug tools moved into the debug tools' load-on-demand addon, XayaUI_Debug.

Xaya's answers (REQUEST-LOG A23), her words: SD-58, debug tools: "1 but nothing loads unless "Debugging" is enabled" (one load-on-demand
debug folder: perf report, /xui auras, /xuiengine, /xui status, console window, bug and debug report windows); SD-61, the Debugging
default: "Off by default (Recommended)"; V34: "if the addon or element within an addon is off it should not be read at all ... and should
be detected once per reload"; SD-52, the engine's speed guard: "Remove it (Recommended)", logged as "no lean, no off step; a slow reading
is only reported in /xui debug status"; V26: read-only debug commands are exempt from the combat lock.

What the player gets, checked with the real addons (XayaUI, XayaUI_Rules, XayaUI_Options and XayaUI_Debug) in the stand-in game.
[new] = fails on the pre-change files (proved on a private copy of HEAD b4742900, where these pieces were XayaUI Rules' own code):
  F  Advanced Debugging off (a fresh install): [new] none of the Rules debug code exists (the engine perf report, /xui status, /xui auras
     and its spell facts, /xuiengine's status text); [new] /xuiengine prints ONE plain line, core's: it needs Advanced Debugging and a
     /reload; /xui status, /xui auras and /xui debug perf / status / auras say the same, one line each; [new] in combat /xuiengine
     too, at once; the engine's timing points stay off; the game's addon meter is not read at a fight's end; [new] XayaUI Rules' files
     hold none of that code (V34: not read); the Cooldown Manager catalogue the rules use stays in XayaUI Rules and still works.
  S  Advanced Debugging on: /xuiengine shows the engine's status (what it draws, what XayaUI keeps, "combat engine: on"), changes
     nothing, and works in combat; /xui status shows the context, every rule's answer and why, in combat too; [new] its engine reading
     line (SD-52): "none yet" before a fight; [new] after a fight, what the game's addon meter read at its end for Blizzard's aura
     containers and XayaUI Rules, read only, in chat and [new] in the console window (/xui debug status); [new, round 7 repair, S6b,
     fails on the round-7 first-pass file] the figures only: no threshold, the removed guard's 1.0 ms limit is not named and nothing is
     called slow (whether to add a reference figure or print only when high is Xaya's choice, asked); a 5 ms reading changes nothing
     (no chat line at the fight's end, no guard, the engine still on: a control, true before too); [new] the meter switched off is said
     plainly; /xui debug perf on / report / off works (the perf lines and the game's addon meter); [new] nothing is saved for XayaUI
     Dev Assist (no perfLog), even when its store is there; /xui auras <spell ID> gives the facts.
  N  XayaUI Rules switched off, Advanced Debugging on: the debug tools load with no Lua error, and none of the Rules pieces exists
     (no /xuiengine, no perf report, no status).
Run: python3 tests/fix_r7_debug_rules_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

NEEDS = "needs Advanced Debugging: turn it on in /xui > Settings > Debugging, then type /reload."

LUA = r'''
local W, L, phase, NEEDS = ...
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function since(n) local t = {}; for i = n + 1, #W.printed do t[#t + 1] = plain(W.printed[i]) end; return t end
local function count(lines, text) local n = 0; for _, l in ipairs(lines) do if l:find(text, 1, true) then n = n + 1 end end; return n end
local function first(lines, text) for _, l in ipairs(lines) do if l:find(text, 1, true) then return l end end end
-- the game's addon meter: every read counted (the stand-in's own answers otherwise)
local metric = { Blizzard_AuraContainer = 0.1, XayaUI_Rules = 0.1 }
local reads = 0
C_AddOnProfiler.GetAddOnMetric = function(name, m) reads = reads + 1; return metric[name] or 0.05 end
L.startup()
local ns = rawget(_G, "XayaUI_NS")
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local D = ns.AuraDisplay
local function slash(cmd) local n = #W.printed; SlashCmdList.XAYAUI(cmd); return since(n) end
local function engine(msg) local n = #W.printed; SlashCmdList.XUIENGINE(msg or ""); return since(n) end
local function fight() W.enterCombat(); W.tick(0.1, 3); W.combat = false; W.fire("PLAYER_REGEN_ENABLED"); W.tick(0.1, 5) end
-- a rule to report on (no display: /xui status lists it with its answer and why)
local function addRule()
  local r = ns.NewRule(); r.name = "Status rule"; r.enabled = true; r.useBuff = true; r.buffID = 73501; r.buffState = "present"
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  if ns.MarkDirty then ns.MarkDirty() end
  W.tick(0.1, 3)
  return r
end

if phase == "off" then
  addRule()
  check("(control) XayaUI Rules is loaded and the debug tools are not (Advanced Debugging off by default)",
    D ~= nil and ns.rules ~= nil and ns.AdvancedDebugOn() == false and not ns.DebugToolsLoaded())
  check("[new] F1 none of XayaUI Rules' debug code exists with Advanced Debugging off (perf report, /xui status, /xui auras, its spell facts, /xuiengine's status)",
    ns.PerfCommand == nil and ns.PrintStatus == nil and ns.AurasCommand == nil and ns.AuraFacts == nil and D.Status == nil
      and ns.Service("rulesdebug") == nil,
    tostring(ns.PerfCommand) .. " " .. tostring(ns.PrintStatus) .. " " .. tostring(ns.AurasCommand) .. " " .. tostring(D.Status))
  local got = engine("")
  check("[new] F2 /xuiengine: ONE plain line, core's: '/xuiengine " .. NEEDS .. "'",
    #got == 1 and got[1] == "XayaUI: /xuiengine " .. NEEDS, table.concat(got, " / "))
  got = engine("full")
  check("[new] F3 /xuiengine with a word: the same one line", #got == 1 and got[1] == "XayaUI: /xuiengine " .. NEEDS, table.concat(got, " / "))
  for _, c in ipairs({ { "status", "/xui status" }, { "auras", "/xui auras" }, { "auras 12345", "/xui auras 12345" },
      { "debug perf", "/xui debug perf" }, { "debug perf on", "/xui debug perf on" }, { "debug status", "/xui debug status" },
      { "debug auras target", "/xui debug auras target" } }) do
    got = slash(c[1])
    check("F4 /xui " .. c[1] .. ": one plain line, '" .. c[2] .. " " .. NEEDS .. "'", #got == 1 and got[1] == "XayaUI: " .. c[2] .. " " .. NEEDS,
      table.concat(got, " / "))
  end
  check("F5 /xui debug perf on did not switch the engine's timing points on", not ns.perfOn and not (ns.EnginePerfReadings and ns.EnginePerfReadings()))
  W.enterCombat()
  got = engine("")
  local st = slash("status")
  check("[new] F6 in combat: /xuiengine and /xui status answer at once with the same one line (nothing waits for combat to end)",
    #got == 1 and got[1]:find(NEEDS, 1, true) and #st == 1 and st[1]:find(NEEDS, 1, true) and count(got, "combat") == 0, table.concat(got, " / "))
  reads = 0
  W.combat = false; W.fire("PLAYER_REGEN_ENABLED"); W.tick(0.1, 5)
  check("F7 at a fight's end nothing reads the game's addon meter (no reading is taken while the debug tools are off)", reads == 0, reads)
  check("F8 the Cooldown Manager catalogue the rules use stays in XayaUI Rules and still answers", type(ns.AuraCatalogue) == "function"
    and type(ns.AuraCatalogue()) == "table" and type(ns.ClearAuraCatalogue) == "function")
elseif phase == "on" then
  CueRulesDB.ui.msgDest = "chat"   -- (her setting "XayaUI's messages": chat, so every answer below is read from the chat pane)
  local r = addRule()
  check("(control) Advanced Debugging on: the debug tools are loaded, with XayaUI Rules' pieces",
    ns.DebugToolsLoaded() and type(ns.PrintStatus) == "function" and type(ns.PerfCommand) == "function" and type(ns.AurasCommand) == "function")
  -- /xuiengine
  local got = engine("")
  check("S1 /xuiengine shows the engine's status: what it draws, what XayaUI keeps, that it is on, and that it changes nothing",
    count(got, "XayaUI: Engine draws: ") == 1 and count(got, "combat engine: on (it always runs while any rule is on).") == 1
      and (count(got, "XayaUI keeps") == 1) and count(got, "it changes nothing") == 1 and count(got, NEEDS) == 0, table.concat(got, " / "))
  local builds = 0
  local B = D.Build
  D.Build = function(...) builds = builds + 1; return B(...) end
  got = engine("full"); engine("refresh")
  D.Build = B
  check("S2 /xuiengine full / refresh: only the status, nothing rebuilt (V26, SD-16)", builds == 0 and count(got, "Engine draws: ") == 1, builds)
  -- /xui status and its engine reading line (SD-52)
  got = slash("status")
  check("S3 /xui status: the context, the place, and the rule's answer and why",
    count(got, "XayaUI: context: combat=") == 1 and count(got, "XayaUI: place: map=") == 1 and count(got, "#1 Status rule [on] result=") == 1,
    table.concat(got, " / "):sub(1, 400))
  check("[new] S4 ...with the engine's reading line, before any fight: none yet",
    count(got, "XayaUI: combat engine reading (read only, nothing acts on it): none yet. It is read at the end of each fight.") == 1,
    table.concat(got, " / "):sub(1, 400))
  metric.Blizzard_AuraContainer, metric.XayaUI_Rules = 5.0, 0.42
  local p0 = #W.printed
  fight()
  local atEnd = since(p0)
  check("S5 a slow fight (Blizzard's aura containers read 5 ms at its end): nothing said at the fight's end, the engine still on, no guard",
    #atEnd == 0 and ns.RulesDisabled ~= true and not (D.StatusData and D.StatusData().off) and D.GuardCheck == nil, table.concat(atEnd, " / "))
  got = slash("status")
  local line = first(got, "combat engine reading")
  check("[new] S6 /xui debug status then gives the reading, read only: Blizzard's aura containers 5.00 ms and XayaUI Rules 0.42 ms at the fight's end",
    line ~= nil and line:find("nothing acts on it", 1, true) ~= nil and line:find("at the end of the last fight", 1, true) ~= nil
      and line:find("Blizzard's aura containers 5.00 ms per frame, recent average", 1, true) ~= nil
      and line:find("XayaUI Rules 0.42 ms", 1, true) ~= nil and not line:find("/xui", 1, true), line)
  check("[new r7 repair] S6b ...and gives the figures only: no threshold and no judgment of slowness (not the removed guard's 1.0 ms, no 'slow', no 'guard')",
    line ~= nil and not line:find("1.0 ms", 1, true) and not line:lower():find("slow", 1, true) and not line:lower():find("guard", 1, true)
      and not line:lower():find("for comparison", 1, true), line)
  slash("debug status")
  local cw = rawget(_G, "XayaUIConsoleWindow")
  local shown = {}
  for _, l in ipairs(cw and cw.log and cw.log._lines or {}) do shown[#shown + 1] = plain(type(l) == "table" and l[1] or l) end
  check("[new] S7 /xui debug status prints the same line in the console window (/xui debug opens it)",
    ns.ConsoleWindowOn() and count(shown, "Blizzard's aura containers 5.00 ms per frame") == 1, table.concat(shown, " / "):sub(-300))
  ns.ConsoleWindow(false)
  local IE = C_AddOnProfiler.IsEnabled
  C_AddOnProfiler.IsEnabled = function() return false end
  got = slash("status")
  C_AddOnProfiler.IsEnabled = IE
  check("[new] S8 the game's addon meter switched off: the line says so plainly",
    count(got, "XayaUI: combat engine reading (read only, nothing acts on it): the game's addon meter is off, so there is no reading.") == 1,
    first(got, "combat engine reading"))
  -- in combat (V26: read-only debugging is exempt)
  W.enterCombat()
  local ge, gs = engine(""), slash("status")
  check("S9 in combat: /xuiengine and /xui status answer at once (V26: exempt), no 'during combat' line",
    count(ge, "combat engine: on") == 1 and count(gs, "context: combat=") == 1 and count(ge, "during combat") == 0 and count(gs, "during combat") == 0,
    table.concat(gs, " / "):sub(1, 300))
  W.combat = false; W.fire("PLAYER_REGEN_ENABLED"); W.tick(0.1, 5)
  -- /xui debug perf: on, a report, off; nothing kept for XayaUI Dev Assist even when its store is there
  local dev = {}
  local SR, SS = ns.SettingsReady, ns.Settings
  ns.SettingsReady = function(k, ...) if k == "devassist" then return true end return SR(k, ...) end
  ns.Settings = function(k, ...) if k == "devassist" then return dev end return SS(k, ...) end
  ns.ConsoleWindow(false)
  local n = #W.printed
  ns.PerfCommand("on")
  local on = ns.perfOn == true
  W.tick(0.1, 10); fight()
  ns.PerfCommand("")
  ns.PerfCommand("off")
  local pf = since(n)
  ns.SettingsReady, ns.Settings = SR, SS
  check("S10 /xui debug perf on / report / off: measuring starts, the report gives the engine's lines and the game's own addon meter, and it stops",
    on and count(pf, "XayaUI: perf: measuring.") == 1 and count(pf, "XayaUI: perf over ") == 1 and count(pf, "perf: per second: rules ") == 1
      and count(pf, "perf: game's own addon meter, recent avg/peak ms per frame, top 8: ") == 1 and count(pf, "XayaUI: perf: stopped") == 1
      and not ns.perfOn, table.concat(pf, " / "):sub(1, 500))
  check("[new] S11 nothing is saved for XayaUI Dev Assist (retired to qa-installer-branch): no perfLog, even with its store present",
    dev.perfLog == nil, dev.perfLog and #dev.perfLog)
  got = slash("auras 73501")
  check("S12 /xui auras <spell ID>: that spell's facts, in chat", #got == 1 and got[1]:find("(ID 73501): readable in combat:", 1, true) ~= nil, got[1])
elseif phase == "norules" then
  check("N1 XayaUI Rules off, Advanced Debugging on: the debug tools load", ns.DebugToolsLoaded() == true)
  check("N2 ...and none of the Rules pieces exists: no /xuiengine, no perf report, no status, no aura list",
    SlashCmdList.XUIENGINE == nil and ns.PerfCommand == nil and ns.PrintStatus == nil and ns.AurasCommand == nil
      and ns.Service("rulesdebug") == nil)
  local got = slash("status")
  check("N3 /xui status says it needs XayaUI Rules (one line)", #got == 1 and got[1]:find("XayaUI Rules", 1, true) ~= nil, got[1])
end
local out = L.logout()
return R
'''


def session(saved, phase, addons=("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug")):
    folders = H.find_addons()
    enabled = [n for n in folders if n in addons]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    sv = H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    o = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    o["saved"] = H.to_lua(L, saved)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, o)
    res = L.eval("function(src, ...) return loadstring(src)(...) end")(LUA, world, loader, phase, NEEDS)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return results, errs


# V34 (off means not read): XayaUI Rules' own files (read at every login while it is on) hold none of the debug code
RULES_PATTERNS = [r"function ns\.PrintStatus\b", r"function ns\.PerfCommand\b", r"function ns\.AurasCommand\b", r"function ns\.AuraFacts\b",
                  r"function D\.Status\b", r"\bAddonCPU\b", r"DevS\.perfLog", r"RegisterDebugCommand\(\s*\"auras\"", r"D\.Status\(\)"]


def rules_source_check():
    hits = []
    root = os.path.join(H.ROOT, "XayaUI_Rules")
    for d, _, files in os.walk(root):
        for f in files:
            if not f.endswith(".lua"):
                continue
            p = os.path.join(d, f)
            src = open(p, encoding="utf-8").read()
            for pat in RULES_PATTERNS:
                if re.search(pat, src):
                    hits.append("%s: %s" % (os.path.relpath(p, H.ROOT), pat))
    toc = open(os.path.join(H.ROOT, "XayaUI_Debug", "XayaUI_Debug.toc"), encoding="utf-8").read().splitlines()
    files = [l.strip() for l in toc if l.strip() and not l.startswith("#")]
    want = ["RulesPerf.lua", "RulesStatus.lua", "RulesAuras.lua", "RulesEngine.lua"]
    return [("[new] F9 XayaUI Rules' files (read at every login) hold none of the debug code (V34: off means not read)", not hits, ", ".join(hits)),
            ("[new] F10 the debug tools' addon lists the four Rules pieces after its own files",
             all(w in files for w in want) and files.index("Tools.lua") == 0, ", ".join(files))]


def main():
    results, errors = [], []
    for name, ok, extra in rules_source_check():
        results.append((name + ("" if ok else "  [" + extra + "]"), ok))
    r, e = session({}, "off")
    results += r; errors += e
    r, e = session({"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"advancedDebug": True}}}}, "on")
    results += r; errors += e
    r, e = session({"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"advancedDebug": True}}}}, "norules", ("XayaUI", "XayaUI_Options", "XayaUI_Debug"))
    results += r; errors += e
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    for x in errors:
        print("ERROR in the game stand-in:", x[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errors)))
    sys.exit(1 if bad or errors else 0)


if __name__ == "__main__":
    main()
