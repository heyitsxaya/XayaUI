#!/usr/bin/env python3
"""Keys reach the game (XayaUI 0.6.85, XayaUI/KeyCatch.lua). Xaya 2026-11-08 (docs/process/REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md
row 56, her words): "WHY DOES THE ADDON KEEP PREVENTING ME FROM SCREENSHOTTING".

What she sees: with the settings window, the mover view (/xui unlock) or the version pane open, every key the window does not use
(the screenshot key PRINTSCREEN, movement) works as without XayaUI, also in combat; a key a window uses (Delete / Ctrl+Z in the
settings window, an arrow in the mover view, Esc in the version pane) is kept for that key only. A XayaUI text box lets go of the
keyboard on Enter (one-line boxes), Escape, a click outside it, and when its window closes.

The stand-in game routes keys the way warcraft.wiki.gg describes it (tests/harness/world.lua, W.pressKey: top-down through the shown
keyboard-enabled frames, stopping at the first that does not pass the key on; "game" = no frame kept it, so key bindings run).
Each check below fails on the code before this change (core 0.6.83 / Options 0.6.106 / Rules 0.6.82 at 2c43f3d), except those marked
"(regression)", which pass on both and guard what must not change.
Run: python3 tests/key_propagation_run.py"""
import os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function who(x) if x == "game" then return "game" end if type(x) == "table" then return (x.GetName and x:GetName()) or tostring(x._kind) end return tostring(x) end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
check("core has the shared key helper (ns.KeyCatch) and the text box helper (ns.KeyFocusGuard)", type(ns.KeyCatch) == "function" and type(ns.KeyFocusGuard) == "function")

-- the helper itself: PRINTSCREEN is never held, a key handler's error never leaves keys stuck
if ns.KeyCatch then
  local t = CreateFrame("Frame", "XUITestKeyGreedy", UIParent); t:SetFrameStrata("TOOLTIP")
  ns.KeyCatch(t, function() return true end)   -- a handler that claims every key
  do local g = who(W.pressKey("PRINTSCREEN")); check("a window that claims every key still leaves PRINTSCREEN to the game", g == "game", g) end
  W.tick(0.02, 1)
  check("  ...and a key it uses is kept from the game", W.pressKey("A") == t)
  W.tick(0.02, 1)
  check("  ...for that key only: on the next frame the flag is back to pass", t:GetPropagateKeyboardInput() == true)
  t:Hide()
  local e = CreateFrame("Frame", "XUITestKeyBroken", UIParent); e:SetFrameStrata("TOOLTIP")
  ns.KeyCatch(e, function() error("broken handler") end)
  local nErr = #W.errors
  check("a key handler with a Lua error leaves the key to the game", who(W.pressKey("W")) == "game")
  check("  ...and the error is reported", #W.errors == nErr + 1)
  while #W.errors > nErr do table.remove(W.errors) end   -- (that error was this test's own)
  e:Hide()
end

-- the settings window (Delete, Ctrl+Z / Ctrl+Y)
local AceGUI, ACD = LibStub("AceGUI-3.0"), LibStub("AceConfigDialog-3.0")
local RE = ns.OptionsApi and ns.OptionsApi.RuleEditor or {}
local deletes = 0
RE.DeleteKey = function() deletes = deletes + 1; return true end
local of = AceGUI:Create("Frame")
ACD.OpenFrames = ACD.OpenFrames or {}
ACD.OpenFrames["CueRules"] = of
of.frame:Show()
ACD:Open("CueRules", of)
W.tick(0.3, 3)
local fr = of.frame
check("settings window: open, it takes keys and passes them on at rest (no key pressed yet)", fr._keyboard == true and fr:GetPropagateKeyboardInput() == true,
  tostring(fr._keyboard) .. " / " .. tostring(fr:GetPropagateKeyboardInput()))
W.enterCombat()
-- (V26, lock-core round 3: the settings window closes as combat starts and opens again when it ends; these checks still hold)
check("(V26) combat starts: the settings window closes", not fr:IsShown())
do local g = who(W.pressKey("PRINTSCREEN")); check("settings window just opened, combat starts: PRINTSCREEN reaches the game", g == "game", g) end
check("  ...and movement (W) reaches the game", who(W.pressKey("W")) == "game")
W.leaveCombat()
-- (V26) combat end opened the window again, in AceConfigDialog's own frame: the checks below use that one
W.tick(0.1, 5); of = ACD.OpenFrames["CueRules"] or of; fr = of.frame
check("(V26) combat ends: the settings window is open again", fr:IsShown())
check("(regression) out of combat PRINTSCREEN reaches the game", who(W.pressKey("PRINTSCREEN")) == "game")
local d0 = deletes
local got = W.pressKey("DELETE")
check("(regression) Delete deletes and is kept from the game", got == fr and deletes == d0 + 1, who(got))
W.tick(0.02, 1)
check("(regression) after Delete the next key (PRINTSCREEN) reaches the game", who(W.pressKey("PRINTSCREEN")) == "game")
W.pressKey("DELETE")
W.enterCombat()
do local g = who(W.pressKey("PRINTSCREEN")); check("after Delete, combat starts: PRINTSCREEN reaches the game", g == "game", g) end
check("  ...and movement (W, D) reaches the game", who(W.pressKey("W")) == "game" and who(W.pressKey("D")) == "game")
local nErr = #W.errors
W.pressKey("DELETE"); W.pressKey("A")
check("(regression) in combat no window touches the restricted flag (no blocked-action error)", #W.errors == nErr, W.errors[#W.errors])
W.leaveCombat()
W.tick(0.1, 5); of = ACD.OpenFrames["CueRules"] or of; fr = of.frame   -- (V26: opened again after combat)
-- the other reading of the game (the flag as it is when the key arrives): the next key, a frame later, still reaches the game
W.keyFlagRead = "before"
W.pressKey("DELETE"); W.tick(0.02, 1)
do local g = who(W.pressKey("PRINTSCREEN")); check("read as 'before the handler': after Delete, the next key (PRINTSCREEN, a frame later) reaches the game", g == "game", g) end
W.keyFlagRead = "after"

-- the version pane (Esc closes the pane only)
local c = of.xuiChrome
if c and c.info and ns.InfoPane then
  c.info:Click()
  local f = ns.InfoPane.Frame()
  check("(regression) version pane: other keys reach the game", f and f:IsShown() and who(W.pressKey("A")) == "game")
  local k = W.pressKey("ESCAPE")
  check("(regression) version pane: Esc closes the pane and is kept from the game (the settings window stays open)", k == f and not f:IsShown() and fr:IsShown(), who(k))
  W.tick(0.02, 1)
  check("version pane closed: it holds no keyboard and its flag is back to pass", f._keyboard == false and f:GetPropagateKeyboardInput() == true,
    tostring(f._keyboard) .. " / " .. tostring(f:GetPropagateKeyboardInput()))
  c.info:Click()
  W.enterCombat()
  check("(regression) version pane open in combat: PRINTSCREEN reaches the game", who(W.pressKey("PRINTSCREEN")) == "game")
  W.leaveCombat()
  f:Hide()
else check("the version pane is there", false) end

-- the window is AceGUI's and is recycled for other addons: after release it takes no keys
-- (V26: each combat closed the window and the end of combat opened it again in AceConfigDialog's own frame: close it the normal way)
if ACD.OpenFrames["CueRules"] then ACD:Close("CueRules") end; ACD.OpenFrames["CueRules"] = nil
check("settings window released: the frame holds no keyboard", fr._keyboard == false, tostring(fr._keyboard))
local other = AceGUI:Create("Frame")   -- another addon's window (often the same frame, recycled)
other.frame:Show()
local d1 = deletes
local k2 = W.pressKey("DELETE")
check("another addon's window from the same pool: Delete reaches the game and deletes no rule", who(k2) == "game" and deletes == d1, who(k2) .. " / " .. (deletes - d1))
AceGUI:Release(other)

-- the mover view (arrow keys)
ns.folders = { { id = "fK", name = "Keys" } }
CueRulesDB.folders = ns.folders
local r = ns.NewRule(); r.name = "Key test"; r.folder = "fK"; r.enabled = true
ns.NormalizeRule(r); r.visual.enabled = true; r.visual.x, r.visual.y = 0, 0
ns.rules = { r }
ns.RefreshAllVisuals()
ns.ToggleUnlock(); W.tick(0.05, 3)
local keys = ns.MoverKeyFrame()
check("mover view open: its key frame takes keys and passes them on at rest", keys and keys._keyboard == true and keys:GetPropagateKeyboardInput() == true)
W.enterCombat()
do local g1, g2 = who(W.pressKey("PRINTSCREEN")), who(W.pressKey("W")); check("mover view just opened, combat starts: PRINTSCREEN and W reach the game", g1 == "game" and g2 == "game", g1 .. " / " .. g2) end
W.leaveCombat()
ns.MoverSelect("display", r)
local x0 = r.visual.x
local k3 = W.pressKey("RIGHT")
check("(regression) the right arrow nudges the selected display and is kept from the game", k3 == keys and r.visual.x == x0 + 1, who(k3) .. " x=" .. tostring(r.visual.x))
W.tick(0.02, 1)
check("(regression) after an arrow the next key (PRINTSCREEN) reaches the game", who(W.pressKey("PRINTSCREEN")) == "game")
W.pressKey("LEFT")
W.enterCombat()
local x1 = r.visual.x
do local g = who(W.pressKey("PRINTSCREEN")); check("after an arrow, combat starts: PRINTSCREEN reaches the game", g == "game", g) end
check("  ...movement (W, LEFT) reaches the game and nothing moves in combat", who(W.pressKey("W")) == "game" and who(W.pressKey("LEFT")) == "game" and r.visual.x == x1)
W.leaveCombat()
W.keyFlagRead = "before"
W.pressKey("UP"); W.tick(0.02, 1)
do local g = who(W.pressKey("PRINTSCREEN")); check("read as 'before the handler': after an arrow, the next key (PRINTSCREEN, a frame later) reaches the game", g == "game", g) end
W.keyFlagRead = "after"
ns.MoverExit("cancel"); W.tick(0.05, 2)
check("mover view closed: its key frame holds no keyboard", keys._keyboard == false and not keys:IsShown())

-- a one-line box with no Enter of its own: the debug report's string box
if ns.ShowDebugReport then
  ns.ShowDebugReport(); W.tick(0.05, 2)
  local win = ns.DebugReportWindow and ns.DebugReportWindow()
  local sb = win and win.str
  if sb then
    sb:SetFocus()
    local en = sb:GetScript("OnEnterPressed")
    if en then en(sb) end
    check("a one-line box with no Enter of its own (debug report string): Enter lets go of the keyboard", en ~= nil and not sb:HasFocus())
    win:Hide()
  else check("the debug report's string box is there", false) end
end
return R
end
'''


def static_audit():
    """Every XayaUI text box goes through ns.KeyFocusGuard; only core's KeyCatch.lua touches the keyboard flag."""
    out = []
    files = subprocess.run(["git", "ls-files", "XayaUI*/*.lua", "XayaUI*/**/*.lua"], cwd=ROOT, capture_output=True, text=True).stdout.split()
    files = sorted(set(f for f in files if "/Libs/" not in f))
    # boxes that handle Enter / Escape / a click outside / hiding themselves (the reason is checked here too)
    EXEMPT = {("XayaUI/Modules.lua", "eb"): "GLOBAL_MOUSE_DOWN"}   # the element menu's X / Y boxes: the menu closes on a click outside
    missing, flag = [], []
    for f in files:
        src = open(os.path.join(ROOT, f), encoding="utf-8").read()
        lines = src.split("\n")
        for i, ln in enumerate(lines):
            code = ln.split("--")[0]
            m = re.search(r'(?:local\s+)?([\w\.]+)\s*=\s*(?:CreateFrame\("EditBox"|.*pcall\(CreateFrame, "EditBox")', code)
            if m:
                var = m.group(1)
                if var in ("ok", "_"):
                    continue
                window = "\n".join(lines[i:i + 45])
                if "KeyFocusGuard(" + var in window:
                    continue
                ex = EXEMPT.get((f, var))
                if ex and ex in window:
                    continue
                missing.append("%s:%d %s" % (f, i + 1, var))
            if re.search(r"SetPropagateKeyboardInput\s*\(|EnableKeyboard\s*\(|SetPropagateKeyboardInput\s*,", code) and f != "XayaUI/KeyCatch.lua":
                flag.append("%s:%d" % (f, i + 1))
    out.append(("every XayaUI text box lets go of the keyboard through core's ns.KeyFocusGuard" + ("" if not missing else "  [" + ", ".join(missing) + "]"), not missing))
    out.append(("only core's KeyCatch.lua switches the keyboard on or sets the pass-on flag" + ("" if not flag else "  [" + ", ".join(flag) + "]"), not flag))
    return out


def main():
    results = static_audit()
    folders = H.find_addons()
    enabled = list(folders)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        # (round 7, REQUEST-LOG A23 SD-58 / SD-61) the console window and the debug report are XayaUI_Debug's, read only while Advanced
        # Debugging is on (off for a new install): saved on here, as every install before round 7 has it, so their key boxes are checked
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {"XayaUI": {"CueRulesDB": {"ui": {"advancedDebug": True}}}}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    for i in range(1, len(res) + 1):
        results.append((res[i][1], res[i][2]))
    bad = 0
    for name, good in results:
        print(("PASS " if good else "FAIL ") + name)
        bad += 0 if good else 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
