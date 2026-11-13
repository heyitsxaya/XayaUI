#!/usr/bin/env python3
"""Round 6, Combat Tracking Setup never opens over the game by itself (XayaUI_Options/AuraSetup.lua, the Rules tab's button in
XayaUI_Options/RuleEditor/RulesTree.lua, the settings window's open / close in XayaUI_Options/Options.lua).

Xaya, SD-53 (REQUEST-LOG A23), her answer on the window opening by itself 6 s after login: "first run ever open with settings;
otherwise put a config button in the rules pane". With V27 (SD-28, her words: "nothing impacts mouse ability to interact with ...
in-game objects ... once xui options window is closed"). So:
  S1  after login, a spec change and a loading screen (a minute of play), the window has not opened and nothing was said about it
      (before: it opened 6 s after login, 660 x 560 in the middle of the screen, taking clicks, with a chat line);
  S2  the very first time ever (no spec has a saved or skipped setup, never shown before) it opens together with the settings window;
  S3  it closes when the settings window closes;
  S4  the next opening of the settings window does not open it again;
  S5  a clearly labeled button, "Open Combat Tracking Setup", is on the Rules tab (the page it opens on, Enabled > LOADED, and Smart
      Categories) and opens it;
  S6  closing the settings window closes it again: nothing of it stays on screen;
  S7  both open when combat starts: both close, both come back after the fight, and closing the settings window then closes it too;
  S8  the window's Finish line points to that button (before: to Settings > UI Options > Rule Creation only);
  R1  after a /reload (what this session saved): a minute of play, then the settings window: it does not open;
  R2  a player who finished a setup in an older version (no "shown" record): the settings window does not open it either;
  D   the player documents (USER-GUIDE, HELP-FAQ, the Combat README) say there is no speed guard, where the setup window is, that the
      engine always runs and that old engine-off settings are cleared with a chat line, and no longer say "every 0.2 seconds" or that
      the guard is "a question for Xaya" (round 5 review).
Checks marked [new] fail on the files before this change (proved on a copy); "(control)" checks pass on both, except the saved-data
control, which needs the new "shown" record.
Run: python3 tests/fix_r6_setup_run.py   (Lua 5.1 via lupa; loads XayaUI, XayaUI_Rules and XayaUI_Options in the stand-in game)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L, phase)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local saved1, saved2
local okAll, errAll = pcall(function()

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
check("(control) XayaUI and XayaUI Rules loaded", ns ~= nil and ns.AuraModel ~= nil and SlashCmdList.XAYAUI ~= nil)
if not ns then return end
MenuUtil.CreateContextMenu = function() end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
local lines = {}
local realPrint = ns.Print
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; lines[#lines + 1] = table.concat(t, " ") end
local function has(list, pat) for _, l in ipairs(list) do if l:lower():find(pat, 1, true) then return true end end; return false end
local function joined(list) return table.concat(list, " / ") end
local APP = "CueRules"
local ACD
local function windowOpen()
  ACD = ACD or LibStub("AceConfigDialog-3.0", true)
  return ACD ~= nil and ACD.OpenFrames[APP] ~= nil and ACD.OpenFrames[APP].frame:IsShown()
end
local function setupShown() local f = rawget(_G, "XayaUIAuraSetupFrame"); return f ~= nil and f:IsShown() end
local function toggle() ns.ToggleUI(); W.tick(0.1, 6) end
local function fight() W.enterCombat(); W.tick(0.05, 2) end
local function peace() W.leaveCombat(); W.tick(0.1, 6) end
-- a minute of play: time, a spec change, a loading screen
local function play()
  W.tick(0.5, 60)
  W.fire("PLAYER_SPECIALIZATION_CHANGED", "player"); W.tick(0.5, 20)
  W.fire("PLAYER_ENTERING_WORLD", false, false); W.tick(0.5, 40)
end
local function findW(w, pred)
  if type(w) ~= "table" then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local f = findW(c, pred); if f then return f end end
end
local function setupButton()
  return findW(ACD and ACD.OpenFrames[APP], function(w)
    local o = w.GetUserData and w:GetUserData("option")
    return w.type == "Button" and w.frame and w.frame:IsVisible() and o and o.name == "Open Combat Tracking Setup"
  end)
end

if phase == 1 then
  -- S1
  play()
  check("[new] S1 a minute after login, with a spec change and a loading screen: Combat Tracking Setup has not opened over the game",
    not setupShown())
  check("[new] S1 ...and nothing was said in chat about it", not has(lines, "combat tracking"), joined(lines))
  -- S2 / S3 / S4
  local before = setupShown()
  toggle()
  check("(control) the settings window opens", windowOpen())
  check("[new] S2 the very first time ever: Combat Tracking Setup, not on screen before, opens together with the settings window",
    not before and windowOpen() and setupShown())
  toggle()
  check("[new] S3 the settings window closes: Combat Tracking Setup closes with it", not windowOpen() and not setupShown())
  toggle()
  check("[new] S4 the settings window opens again: Combat Tracking Setup does not open again", windowOpen() and not setupShown())
  -- S5 the Rules tab's button, on the page the Rules tab opens on and on Smart Categories
  pcall(ACD.SelectGroup, ACD, APP, "cooldowns", "enabledTab", "loaded"); W.tick(0.1, 4)
  local b = setupButton()
  check("[new] S5 the Rules tab (Enabled > LOADED) shows a button labeled 'Open Combat Tracking Setup'", b ~= nil)
  if b then W.click(b.frame); W.tick(0.1, 4) end
  check("[new] S5 ...pressing it opens Combat Tracking Setup", b ~= nil and setupShown())
  local f = rawget(_G, "XayaUIAuraSetupFrame")
  if f and f:IsShown() then f:Hide() end
  pcall(ACD.SelectGroup, ACD, APP, "cooldowns", "smartTab", "all"); W.tick(0.1, 4)
  local b2 = setupButton()
  check("[new] S5 the same button is on Rules > Smart Categories", b2 ~= nil)
  if b2 then W.click(b2.frame); W.tick(0.1, 4) end
  -- S6
  toggle()
  check("[new] S6 the settings window closes: Combat Tracking Setup (opened with the button) closes with it, nothing of it on screen",
    not windowOpen() and b2 ~= nil and not setupShown())
  -- S7 combat with both open
  toggle()
  pcall(ACD.SelectGroup, ACD, APP, "cooldowns", "enabledTab", "loaded"); W.tick(0.1, 4)
  ns.AuraSetup_Open(); W.tick(0.1, 4)
  local bothOpen = windowOpen() and setupShown()
  fight()
  local bothShut = not windowOpen() and not setupShown()
  peace()
  check("(control) S7 both open when combat starts: both close, both open again after the fight", bothOpen and bothShut and windowOpen() and setupShown(),
    ("open=%s shut=%s window=%s setup=%s"):format(tostring(bothOpen), tostring(bothShut), tostring(windowOpen()), tostring(setupShown())))
  toggle()
  check("[new] S7 ...then the settings window closes: Combat Tracking Setup closes with it", not windowOpen() and not setupShown())
  -- S8 Finish
  toggle()
  pcall(ACD.SelectGroup, ACD, APP, "cooldowns", "enabledTab", "loaded"); W.tick(0.1, 4)
  b = setupButton(); if b then W.click(b.frame); W.tick(0.1, 4) end
  f = rawget(_G, "XayaUIAuraSetupFrame")
  if f and not f:IsShown() then ns.AuraSetup_Open(); W.tick(0.1, 2) end
  local n0 = #lines
  if f then
    f.next:GetScript("OnClick")(f.next); f.next:GetScript("OnClick")(f.next); W.tick(0.05, 2)
    f.finish:GetScript("OnClick")(f.finish); W.tick(0.05, 2)
  end
  local fin = {}
  for i = n0 + 1, #lines do fin[#fin + 1] = lines[i] end
  check("[new] S8 Finish setup: the chat line points to the Open Combat Tracking Setup button on the Rules tab",
    has(fin, "setup saved") and has(fin, "open combat tracking setup button on the rules tab"), joined(fin))
  toggle()
  check("(control) S8 everything closed at the end", not windowOpen() and not setupShown())
  -- what this session saved; and the same with the "shown" record taken out (a setup finished in an older version)
  local out = L.logout()
  saved1 = out
  local function strip(t, depth)
    if type(t) ~= "table" or depth > 6 then return end
    if type(t.auraModel) == "table" and type(t.auraModel.settings) == "table" then t.auraModel.settings.setupShown = nil end
    for _, v in pairs(t) do strip(v, depth + 1) end
  end
  local function copy(v) if type(v) ~= "table" then return v end local c = {}; for k, x in pairs(v) do c[k] = copy(x) end; return c end
  saved2 = copy(out); strip(saved2, 0)
  local function findAM(t, depth)
    if type(t) ~= "table" or depth > 6 then return nil end
    if type(t.auraModel) == "table" then return t.auraModel end
    for _, v in pairs(t) do local a = findAM(v, depth + 1); if a then return a end end
  end
  local a1, a2 = findAM(saved1, 0), findAM(saved2, 0)
  local done = false
  for _, p in pairs(a2 and a2.specs or {}) do if type(p) == "table" and p.setupDone then done = true end end
  check("(control) the saved data for R1 holds the 'shown' record; the one for R2 has none, and a spec with a finished setup",
    a1 and a1.settings and a1.settings.setupShown == true and a2 and a2.settings and a2.settings.setupShown == nil and done)
else
  -- R1 / R2: a later session
  play()
  check(("(control) R%d a minute of play after a /reload: Combat Tracking Setup has not opened"):format(phase - 1), not setupShown())
  toggle()
  check(("(control) R%d the settings window opens"):format(phase - 1), windowOpen())
  check(("(control) R%d ...and Combat Tracking Setup does not open with it (%s)"):format(phase - 1,
    phase == 2 and "it was shown once already" or "a spec already has a setup, saved by an older version"), windowOpen() and not setupShown())
  toggle()
end
ns.Print = realPrint

end)
check("no Lua error in the test itself", okAll, errAll)
return R, saved1, saved2
end
'''


def session(phase, saved):
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    sv = H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    opts["saved"] = sv.Load(saved) if saved else H.to_lua(L, {})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    res, s1, s2 = L.eval("function(src, W, Ld, p) return loadstring(src)()(W, Ld, p) end")(LUA, world, loader, phase)
    rows = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    src1 = sv.Serialize(s1) if s1 else None
    src2 = sv.Serialize(s2) if s2 else None
    return rows, errs, src1, src2


def doc_checks():
    root = os.path.normpath(os.path.join(HERE, ".."))

    def read(rel):
        with open(os.path.join(root, rel), encoding="utf-8") as fh:
            return fh.read()
    out = []
    ug, faq, rd = read("docs/USER-GUIDE.md"), read("docs/HELP-FAQ.md"), read("XayaUI_Rules/Combat/README.md")
    out.append(("[new] D1 USER-GUIDE: no longer says the engine re-checks every rule about every 0.2 seconds", "every 0.2 seconds" not in ug))
    out.append(("[new] D2 USER-GUIDE: says there is no speed guard (SD-52), and no longer calls it a question for Xaya",
                "There is no speed guard" in ug and "is a question for Xaya" not in ug and "lean mode), then stops drawing" not in ug))
    out.append(("[new] D3 USER-GUIDE: old engine-off settings are cleared with one chat line (not 'without a message')",
                "cleared once, without a message" not in ug and "one chat line says so" in ug))
    out.append(("[new] D4 USER-GUIDE: Combat Tracking Setup never opens over the game by itself; the Open Combat Tracking Setup button on the Rules tab",
                "**Combat Tracking Setup.**" in ug and "never opens over the game by itself" in ug and "**Open Combat Tracking Setup** button on the Rules tab" in ug))
    out.append(("[new] D5 HELP-FAQ: no speed guard, and where the setup window is",
                "no speed guard any more" in faq and "### The Combat Tracking Setup window" in faq and "**Open Combat Tracking Setup** button on the Rules tab" in faq))
    out.append(("[new] D6 Combat README: no speed guard (SD-52) and the setup window's openings (SD-53)",
                "No speed guard" in rd and "Performance guard on Blizzard's container code" not in rd and "first run ever open with settings" in rd
                and "first-run \"Combat Tracking Setup\" window" not in rd))
    return out


def main():
    rows, errs, src1, src2 = session(1, None)
    if src1:
        r2, e2, _, _ = session(2, src1)
        r3, e3, _, _ = session(3, src2)
        rows += r2 + r3
        errs += e2 + e3
    else:
        rows.append(("the first session saved its data (needed for R1 / R2)", False))
    rows += doc_checks()
    bad = 0
    for name, ok in rows:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(rows), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
