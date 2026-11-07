#!/usr/bin/env python3
"""In-game QA walkthroughs for the UI bugs session's work (XayaUI_DevAssist 0.7.11, QAWalks-display.lua). Standing rule V21 (Xaya
2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with
pre-fill confirmation options or data capturing".
Checks, on the real addons in the stand-in game: the six walkthroughs are registered with prefill on, every step has a check or is a
question (noVerdict); their own checks give the right verdict on the stand-in: the Rules sub-tab row (28 px, four even tabs, Auto-Generate
Rules at the right), Data Panels off (no section tab) and on (24 px, even), the Data Panels switch's hover (three lines), the theme's
Muted grey, Advanced customization (off, then on, then back), the Calculator page (summary, closed box, icon without a name; open box),
Release Guard's Where (no Everywhere) and the stat labels (GCD, Movement Speed, Critical Strike Effectiveness); the settings the
walkthroughs change are put back. Negative control: QAWalks-display.lua does not exist on main 486942c (every check fails there).
Run: python3 tests/qa_walks_display_run.py   (Lua 5.1 via lupa; slow)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local QA = rawget(_G, "XayaUI_DevQA")
local ns = rawget(_G, "XayaUI_NS")
check("Dev Assist has the QA walkthroughs", QA and QA.walks ~= nil)
if not QA then return R end
local IDS = { "ui-tab-rows", "ui-switch-hovers", "ui-theme-advanced", "ui-calc-infobox", "ui-release-guard", "ui-stat-gcd", "ui-nesting" }
for _, id in ipairs(IDS) do
  local w = QA.walks[id]
  local okSteps = w ~= nil
  for _, st in ipairs(w and w.steps or {}) do if not (type(st.check) == "function" or st.noVerdict) then okSteps = false end end
  check(id .. ": registered, pre-fill on, every step has a check or is a question", w ~= nil and w.prefill == true and okSteps)
end
local function step(id, i, setup)
  local st = QA.walks[id] and QA.walks[id].steps[i]
  if not st then return false, "no step" end
  if setup and st.setup then st.setup(); W.tick(0.2, 4) end
  local ok, a, b = pcall(st.check)
  if not ok then return false, "error: " .. tostring(a) end
  return a, b
end
local function stepCheck(name, id, i, setup, want)
  local v, note = step(id, i, setup)
  check(name .. "  (" .. tostring(note) .. ")", (v and true or false) == (want ~= false), note)
end
local db = CueRulesDB
local dpWas = db.dataPanels and db.dataPanels.general and db.dataPanels.general.enabled
stepCheck("tab rows 1: the Rules sub-tab row passes", "ui-tab-rows", 1, true)
stepCheck("tab rows 3: Data Panels off, no section tab", "ui-tab-rows", 3, true)
stepCheck("tab rows 4: Data Panels on, even 24 px section tabs", "ui-tab-rows", 4, true)
stepCheck("tab rows 5: theme text size Large, the Rules tabs grow", "ui-tab-rows", 5, true)
local st6 = QA.walks["ui-tab-rows"].steps[6]; st6.setup(); W.tick(0.2, 2)
check("tab rows 6: Data Panels and the text size are put back", (db.dataPanels.general.enabled and true or false) == (dpWas and true or false) and (db.theme.size == nil or db.theme.size == "M"), tostring(db.theme.size))
stepCheck("hovers 1: the Data Panels tick box shows three lines", "ui-switch-hovers", 1, true)
stepCheck("hovers 3: the off grey is the theme's Muted text", "ui-switch-hovers", 3, false)
stepCheck("theme 1: Advanced customization is off by default", "ui-theme-advanced", 1, true)
stepCheck("theme 2: on, the tab colours are offered", "ui-theme-advanced", 2, true)
stepCheck("theme 3: put back", "ui-theme-advanced", 3, true)
check("  ...and it really is off again", not ns.Theme.Advanced())
stepCheck("calculator 1: summary, closed box, the icon without a name", "ui-calc-infobox", 1, true)
stepCheck("calculator 2: the box opens", "ui-calc-infobox", 2, true)
if ns.infoBoxOpen then ns.infoBoxOpen["bonus.calculator"] = nil end
stepCheck("release guard 1: Where has no Everywhere", "ui-release-guard", 1, false)
stepCheck("release guard 2: with no death window, the check says so (no verdict)", "ui-release-guard", 2, false, false)
stepCheck("stat labels: GCD, Movement Speed, Critical Strike Effectiveness", "ui-stat-gcd", 1, false)
stepCheck("nesting (UI-69): Layout's name 8 px right of Chat Panel's", "ui-nesting", 1, true)
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
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
