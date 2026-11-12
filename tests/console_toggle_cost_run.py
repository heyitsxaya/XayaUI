#!/usr/bin/env python3
"""The console switches answer at once (core 0.6.45, Options 0.6.39; Xaya 2026-11-05: "console toggle has a still long time").
Every redraw of the settings window built the whole options tree (every rule, in several lists): 0.44-0.64 s of Lua with 229 rules
in this harness. A click on "Console window" or "Show the debug console" redrew the window twice (AceConfigDialog's own redraw after
any toggle, plus one XayaUI asked for), so two full builds per click, and the debug console strip waited for the next 0.25 s tick.
Now: the window and the strip change on the click itself, the one redraw reuses the tree drawn last (no build), and the switch still
shows the new state. Safety: any other change still gets a fresh tree; nothing is reused once the window is closed.
A fresh build is counted as a NEW table handed to the dialog (works the same on the old code, where every redraw built one).
Run: python3 tests/console_toggle_cost_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa; slow: each redraw
of the stand-in window takes several seconds here, not in the game)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
local P = ns.NewRule(); P.name = "Demon Spikes"; P.enabled = true; P.useCd = true; P.spellID = 203720; P.cdState = "ready"; ns.NormalizeRule(P)
ns.rules = { P }; CueRulesDB.rules = ns.rules
local reg, ACD = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
-- count what the dialog is handed (a new table = a fresh build) and how often it redraws
local fresh, redraws, lastT = 0, 0, nil
local orig = reg.tables["CueRules"]
reg.tables["CueRules"] = function(...) local t = orig(...); if t ~= lastT then fresh = fresh + 1 end; lastT = t; return t end
local realOpen = ACD.Open
ACD.Open = function(self, app, ...) if app == "CueRules" then redraws = redraws + 1 end; return realOpen(self, app, ...) end
pcall(ns.ToggleUI); W.tick(0.1, 4)
ns.pageOpen = "settings"
ACD:SelectGroup("CueRules", "set", "debug"); W.tick(0.1, 4)
local of = ACD.OpenFrames and ACD.OpenFrames["CueRules"]
check("the settings window is open on Settings > Debugging", of ~= nil and of.frame:IsShown())
if not of then return R end
local function find(w, key)
  if not w then return nil end
  local u = w.GetUserDataTable and w:GetUserDataTable()
  if u and u.option and u.path and u.path[#u.path] == key then return w end
  for _, c in ipairs(w.children or {}) do local f = find(c, key); if f then return f end end
end
local function click(key, value)   -- a click on the switch, as AceGUI's check box reports it
  local w = find(ACD.OpenFrames["CueRules"], key)
  if not w then return false end
  fresh, redraws = 0, 0
  w:Fire("OnValueChanged", value)
  return true
end
local function shownTick(key) local w = find(ACD.OpenFrames["CueRules"], key); return w and w:GetValue() end
local tray = function() return _G.CueRulesTray end

-- "Console window"
check("the Console window switch is on the page", click("consoleWin", true))
check("Console window on: the console window is open on the click itself", ns.ConsoleWindowOn() == true)
local f1, r1 = fresh, redraws
W.tick(0.05, 6)
check("Console window on: no fresh options tree (was 2 builds a click)", fresh == 0, ("%d fresh, %d redraws (at the click: %d / %d)"):format(fresh, redraws, f1, r1))
check("Console window on: one redraw (AceConfigDialog's own), not two", redraws == 1, redraws)
check("...and the redrawn switch shows it ticked", shownTick("consoleWin") == true, tostring(shownTick("consoleWin")))
click("consoleWin", false)
check("Console window off: closed on the click itself", ns.ConsoleWindowOn() == false)
W.tick(0.05, 6)
check("Console window off: no fresh tree, one redraw", fresh == 0 and redraws == 1, ("%d fresh, %d redraws"):format(fresh, redraws))
check("...and the switch shows it unticked", shownTick("consoleWin") == false, tostring(shownTick("consoleWin")))

-- "Show the debug console" (the strip under the window)
W.tick(0.3, 2)
check("the debug console strip is shown to start with", tray() ~= nil and tray():IsShown())
check("the Show the debug console switch is on the page", click("showConsole", false))
check("strip off: hidden on the click itself (not on the next 0.25 s tick)", tray() and not tray():IsShown())
W.tick(0.05, 6)
check("strip off: no fresh tree, one redraw", fresh == 0 and redraws == 1, ("%d fresh, %d redraws"):format(fresh, redraws))
check("...still hidden, switch unticked", tray() and not tray():IsShown() and shownTick("showConsole") == false)
click("showConsole", true)
check("strip on: shown on the click itself", tray() and tray():IsShown())
W.tick(0.05, 6)
check("strip on: no fresh tree, one redraw", fresh == 0 and redraws == 1, ("%d fresh, %d redraws"):format(fresh, redraws))

-- the console window opened from outside the settings window (/xui console, its close X, a message opening it)
fresh, redraws = 0, 0
ns.ConsoleWindow(true)
check("opened from outside: no redraw in the same frame", redraws == 0, redraws)
W.tick(0.05, 6)
check("opened from outside: the next frame's redraw reuses the tree", fresh == 0 and redraws == 1, ("%d fresh, %d redraws"):format(fresh, redraws))
check("...and the switch in the open window shows it ticked", shownTick("consoleWin") == true)
fresh, redraws = 0, 0
ns.ConsoleWindow(false)
W.tick(0.05, 6)
check("closed from outside (its X): reuses the tree, switch unticked", fresh == 0 and redraws == 1 and shownTick("consoleWin") == false,
  ("%d fresh, %d redraws"):format(fresh, redraws))

-- safety: a change that needs a fresh tree always gets one
fresh, redraws = 0, 0
ns.ConsoleWindow(true)   -- asks for a "view" redraw (reuse) ...
ns.Fire("CONFIG_CHANGED")   -- ... and a real change in the same frame cancels it
W.tick(0.05, 6)
check("a real change after a console switch still builds a fresh tree", fresh == 1 and redraws == 1, ("%d fresh, %d redraws"):format(fresh, redraws))
fresh, redraws = 0, 0
ns.ConsoleWindow(false)   -- a "view" redraw asked for (next frame) ...
ACD:Open("CueRules")      -- ... and a redraw in the same frame (a settings handler that changed something): fresh
check("a same-frame redraw after a change made outside builds fresh", fresh == 1, fresh)
W.tick(0.05, 6)
P.name = "Renamed in the meantime"
fresh, redraws = 0, 0
ns.Fire("CONFIG_CHANGED")
W.tick(0.05, 6)
check("an ordinary redraw builds a fresh tree", fresh >= 1, fresh)
-- closing the window lets the kept tree go: the next opening builds fresh even right after a console switch
pcall(ns.ToggleUI); W.tick(0.3, 3)
check("the settings window closed", not (ACD.OpenFrames["CueRules"] and ACD.OpenFrames["CueRules"].frame:IsShown()))
ns.ConsoleWindow(true); W.tick(0.05, 2)
fresh, redraws = 0, 0
pcall(ns.ToggleUI); W.tick(0.1, 4)
check("reopened after a console switch: a fresh tree, not the one from before closing", fresh >= 1, fresh)
ns.ConsoleWindow(false); W.tick(0.05, 2)
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        # (round 7, REQUEST-LOG A23 SD-58 / SD-61) the console window and the reports are XayaUI_Debug's, read only while Advanced Debugging is on (off for a new install): saved on here, as every install before round 7 has it
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {"XayaUI": {"CueRulesDB": {"ui": {"advancedDebug": True}}}}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
