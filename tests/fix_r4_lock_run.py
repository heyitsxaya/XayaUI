#!/usr/bin/env python3
"""Round 4, combat lock and /xui disable gaps from the round-3 review (docs/process/VERIFICATION.md V26, V28; Xaya 2026-11-10, her
answers: "Close, reopen after" for a window open when combat starts; "/xui disable: all rules off"; closing is never held back).
What is checked, as the player sees or gets it:
  U. /xui unlock typed in combat while the mover view is still open closes it at once (no "can't open" line, nothing queued); typed
     in combat while it is closed it still prints one line and opens when combat ends.
  C. Blizzard's color picker opened from a swatch in XayaUI's settings window closes when combat starts; one opened by another
     addon's swatch stays open.
  I. The version / help pane open when combat starts closes with the window and opens again with it after combat, on the same
     tab and section.
  G. /xui disable in combat: every glow a rule's action lit goes out at once (During and On Initialization glows), and no After It
     Ends action runs (its message is not printed). /xui enable after combat: the rule starts fresh, so its On Initialization message
     prints again and its glow comes back.
  M. The /xui disable line says only what is true (displays, glows and sounds stop; a sound already playing finishes); the /xui enable
     line says rules start fresh and their On Initialization actions run again.
  T. The aura tracker stops its event work while rules are off: its events are released, a death does not reset it, a cast does not
     change what it would answer; /xui enable takes the events back.
  O. While rules are off and the settings window is open, one plain line in the window says so (bottom strip, between the version
     link and the Close button, not overlapping either); it goes when rules are turned on; it is hidden while the window is collapsed.
Combat runs as in the game (tests/harness/world.lua W.enterCombat: PLAYER_REGEN_DISABLED, then the lockdown).
Checks marked "(control)" pass on the old code too; every other check fails on the files before this change.
Run: python3 tests/fix_r4_lock_run.py   (Lua 5.1 via lupa; loads XayaUI, XayaUI_Rules and XayaUI_Options in the stand-in game)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
-- LibCustomGlow (installed by other addons in the game), stood in: which frames glow right now
local glowing = {}
do
  local lib = LibStub:NewLibrary("LibCustomGlow-1.0", 1)
  local function on(f) glowing[f] = true end
  local function off(f) glowing[f] = nil end
  lib.ButtonGlow_Start, lib.PixelGlow_Start, lib.AutoCastGlow_Start, lib.ProcGlow_Start = on, on, on, on
  lib.ButtonGlow_Stop, lib.PixelGlow_Stop, lib.AutoCastGlow_Stop, lib.ProcGlow_Stop = off, off, off, off
end

check("(control) XayaUI loaded", ns ~= nil and SlashCmdList.XAYAUI ~= nil)
if not ns then return R end
MenuUtil.CreateContextMenu = function() end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
local lines = {}
local realPrint = ns.Print
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; lines[#lines + 1] = table.concat(t, " ") end
-- what a rule's "Print to my chat window" action writes
local chat = {}
DEFAULT_CHAT_FRAME.AddMessage = function(_, m) chat[#chat + 1] = tostring(m) end
local function mark() return #lines end
local function since(m) local t = {}; for i = m + 1, #lines do t[#t + 1] = lines[i] end; return t end
local function has(list, pat) for _, l in ipairs(list) do if l:lower():find(pat:lower(), 1, true) then return true end end; return false end
local function joined(list) return table.concat(list, " / ") end
local function chatCount(s) local n = 0; for _, l in ipairs(chat) do if l == s then n = n + 1 end end; return n end
local slash = function(s) SlashCmdList.XAYAUI(s); W.tick(0.05, 2) end
local function fight() W.enterCombat(); W.tick(0.05, 2) end
local function peace() W.leaveCombat(); W.tick(0.1, 6) end
local APP = "CueRules"
local ACD
local function windowOpen()
  ACD = ACD or LibStub("AceConfigDialog-3.0", true)
  return ACD ~= nil and ACD.OpenFrames[APP] ~= nil and ACD.OpenFrames[APP].frame:IsShown()
end

ns.folders = {}
CueRulesDB.folders = ns.folders
ns.rules = {}
for i = 1, 2 do
  local r = ns.NewRule(); r.name = "Rule " .. i; r.enabled = true; r.useBuff = true; r.buffID = 1000 + i; r.buffState = "present"
  r.spellID = 2000 + i
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
end
CueRulesDB.rules = ns.rules
if ns.MarkDirty then ns.MarkDirty() end
W.tick(0.1, 4)

-------------------------------------------------------------------------------------------------------------------------------------
-- U. /xui unlock in combat: closing is never held back
-------------------------------------------------------------------------------------------------------------------------------------
section("U", function()
  slash("unlock")
  check("(control) U0 /xui unlock out of combat opens the mover view", ns.unlocked == true)
  W.combat = true   -- the lockdown holds while the view is still open (it was not closed at combat start)
  local m = mark()
  slash("unlock")
  local got = since(m)
  check("U1 /xui unlock in combat with the mover open: the view closes at once", not ns.unlocked, tostring(ns.unlocked))
  check("U2 /xui unlock in combat with the mover open: no line says it can't open", not has(got, "can't open"), joined(got))
  W.combat = false; W.fire("PLAYER_REGEN_ENABLED"); W.tick(0.1, 6)
  check("U3 combat ends: nothing reopens the view she just closed", not ns.unlocked, tostring(ns.unlocked))
  if ns.unlocked then ns.ToggleUnlock(); W.tick(0.1, 2) end
  fight()
  m = mark(); slash("unlock"); got = since(m)
  check("(control) U4 /xui unlock in combat with the mover closed: one line, the view stays closed", not ns.unlocked and #got == 1 and has(got, "when combat ends"), joined(got))
  peace()
  check("(control) U5 combat ends: the view opens", ns.unlocked == true)
  if ns.unlocked then ns.ToggleUnlock(); W.tick(0.1, 2) end
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- C. the color picker: XayaUI's closes at combat start, another addon's stays
-------------------------------------------------------------------------------------------------------------------------------------
section("C", function()
  -- the stand-in picker opens the way the game's does (SetupColorPickerAndShow shows it); the mouse is on the clicked swatch
  ColorPickerFrame.SetupColorPickerAndShow = function(self) self:Show() end
  local focus = nil
  GetMouseFoci = function() return focus and { focus } or {} end
  local r1 = ns.rules[1]
  r1.actions = { start = { glowOn = true, glowTarget = "frame", glowFrame = "XuiR4GlowFrame" } }
  slash(""); W.tick(0.1, 4)
  ACD = ACD or LibStub("AceConfigDialog-3.0", true)
  local AceGUI = LibStub("AceGUI-3.0")   -- (loaded with the settings addon)
  local path = { ns.OptionsApi.RuleEditorParts.RulePath(r1) }; path[#path + 1] = "actions"
  ACD:SelectGroup(APP, unpack(path)); W.tick(0.1, 4)
  local swatch
  local function walk(w, d)
    if swatch or type(w) ~= "table" or d > 30 then return end
    if w.type == "ColorPicker" and w.frame and w.frame:IsVisible() then swatch = w; return end
    for _, ch in ipairs(w.children or {}) do walk(ch, d + 1) end
  end
  walk(ACD.OpenFrames[APP], 0)
  check("(control) C0 the settings window shows a color swatch (the rule's glow color)", windowOpen() and swatch ~= nil)
  if not swatch then return end
  focus = swatch.frame
  swatch.frame:GetScript("OnClick")(swatch.frame, "LeftButton")
  check("(control) C1 clicking XayaUI's swatch opens the color picker", ColorPickerFrame:IsShown())
  local m = mark()
  fight()
  check("C2 combat starts: the color picker XayaUI's swatch opened closes with the window", not ColorPickerFrame:IsShown() and not windowOpen())
  peace()
  if windowOpen() then ns.Options.Toggle(); W.tick(0.1, 4) end
  -- another addon's swatch (its own window, not XayaUI's), XayaUI's window open beside it
  slash(""); W.tick(0.1, 4)
  local other = AceGUI:Create("ColorPicker")
  other.frame:SetParent(UIParent); other.frame:Show()
  focus = other.frame
  other.frame:GetScript("OnClick")(other.frame, "LeftButton")
  check("(control) C3 another addon's swatch opens the color picker", ColorPickerFrame:IsShown())
  fight()
  check("(control) C4 combat starts: XayaUI's window closes", not windowOpen())
  check("(control) C5 combat starts: the picker another addon opened stays open", ColorPickerFrame:IsShown())
  peace()
  ColorPickerFrame:Hide()
  if windowOpen() then ns.Options.Toggle(); W.tick(0.1, 4) end
  AceGUI:Release(other)
  r1.actions = nil
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- I. the version / help pane comes back with the window after combat
-------------------------------------------------------------------------------------------------------------------------------------
section("I", function()
  slash(""); W.tick(0.1, 4)
  ns.InfoPane.OpenHelp(); W.tick(0.05, 2)
  local P = ns.InfoPane
  check("(control) I0 the help pane is open on Info > Help (FAQ)", P.IsShown() and P.state.tab == "info" and P.state.sel.info == "help")
  fight()
  check("(control) I1 combat starts: the window and the pane close", not windowOpen() and not P.IsShown())
  peace()
  check("I2 combat ends: the window opens again and the pane with it, on Info > Help (FAQ)",
    windowOpen() and P.IsShown() and P.state.tab == "info" and P.state.sel.info == "help",
    ("window=%s pane=%s tab=%s sel=%s"):format(tostring(windowOpen()), tostring(P.IsShown()), tostring(P.state.tab), tostring(P.state.sel.info)))
  P.Close()
  if windowOpen() then ns.Options.Toggle(); W.tick(0.1, 4) end
  -- a pane she closed herself does not come back
  slash(""); W.tick(0.1, 4)
  fight(); peace()
  check("(control) I3 the pane closed before the fight does not open after it", windowOpen() and not P.IsShown())
  if windowOpen() then ns.Options.Toggle(); W.tick(0.1, 4) end
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- G. glows go out at /xui disable; rules start fresh at /xui enable. M. the two lines.
-------------------------------------------------------------------------------------------------------------------------------------
section("G", function()
  local gf = CreateFrame("Frame", "XuiR4GlowFrame", UIParent)
  local gi = CreateFrame("Frame", "XuiR4InitGlowFrame", UIParent)
  -- a new rule (its On Initialization runs at its first step)
  local A = ns.NewRule(); A.name = "Rule G"; A.enabled = true; A.useBuff = true; A.buffID = 1099; A.buffState = "present"; A.spellID = 2099
  ns.NormalizeRule(A)
  A.actions = {
    init = { msgOn = true, msgType = "PRINT", msg = "R4 INIT", glowOn = true, glowTarget = "frame", glowFrame = "XuiR4InitGlowFrame" },
    start = { glowOn = true, glowTarget = "frame", glowFrame = "XuiR4GlowFrame", glowType = "pixel" },
    finish = { msgOn = true, msgType = "PRINT", msg = "R4 FINISH" },
  }
  ns.rules[#ns.rules + 1] = A
  local realEval = ns.Evaluate
  ns.Evaluate = function(rule, ctx)
    if rule ~= A then return realEval(rule, ctx) end
    return true, { ctxOK = true, talentOK = true, result = true }
  end
  if ns.MarkDirty then ns.MarkDirty() end
  W.tick(0.1, 15)
  local init0 = chatCount("R4 INIT")
  check("(control) G0 the rule runs: its On Initialization message printed, both glows are on", init0 >= 1 and glowing[gf] and glowing[gi],
    ("init=%d start=%s init=%s"):format(init0, tostring(glowing[gf]), tostring(glowing[gi])))
  fight()
  local m = mark()
  slash("disable")
  local got = since(m)
  W.tick(0.1, 20)
  check("G1 /xui disable in combat: the rule's During glow goes out at once", not glowing[gf])
  check("G2 /xui disable in combat: the rule's On Initialization glow goes out too", not glowing[gi])
  check("(control) G3 /xui disable: the After It Ends action does not run (no message)", chatCount("R4 FINISH") == 0, chatCount("R4 FINISH"))
  check("M1 the /xui disable line names what stops (displays, glows, sounds) and that a sound already playing finishes",
    #got == 1 and has(got, "glows") and has(got, "already playing finishes") and has(got, "/xui enable"), joined(got))
  check("M2 the /xui disable line no longer promises that nothing will play a sound", not has(got, "none will"), joined(got))
  peace()
  check("G4 combat ends: rules still off, the glows stay out", not glowing[gf] and not glowing[gi])
  m = mark()
  slash("enable")
  got = since(m)
  W.tick(0.1, 15)
  check("M3 the /xui enable line says rules start fresh and On Initialization actions run again",
    #got == 1 and has(got, "on again") and has(got, "start fresh") and has(got, "On Initialization"), joined(got))
  check("(control) G5 /xui enable: the rule starts fresh: its On Initialization message prints again and both glows come back",
    chatCount("R4 INIT") == init0 + 1 and glowing[gf] and glowing[gi], ("init %d -> %d"):format(init0, chatCount("R4 INIT")))
  check("(control) G6 nothing ran an After It Ends action through the whole switch", chatCount("R4 FINISH") == 0)
  -- ns.RunActions called while rules are off (any caller) does nothing
  slash("disable"); W.tick(0.1, 4)
  local before = chatCount("R4 INIT")
  ns.RunActions(A, "init")
  check("G7 while rules are off, a rule's actions never run (On Initialization called directly prints nothing)", chatCount("R4 INIT") == before)
  slash("enable"); W.tick(0.1, 10)
  ns.Evaluate = realEval
  A.actions = nil
  for i = #ns.rules, 1, -1 do if ns.rules[i] == A then table.remove(ns.rules, i) end end
  if ns.MarkDirty then ns.MarkDirty() end
  W.tick(0.1, 4)
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- T. the aura tracker stops its event work while rules are off
-------------------------------------------------------------------------------------------------------------------------------------
section("T", function()
  local T = ns.AuraTracker
  check("(control) T0 the aura tracker is loaded", T ~= nil)
  if not T then return end
  local function listeners(e) local n = 0; for _, o in ipairs(W.objects) do if o._events[e] then n = n + 1 end end; return n end
  local n0 = listeners("TRAIT_CONFIG_UPDATED")
  slash("disable"); W.tick(0.1, 2)
  local n1 = listeners("TRAIT_CONFIG_UPDATED")
  check("T1 /xui disable: the tracker's events are released (one listener fewer for talent changes)", n1 == n0 - 1, ("%d -> %d"):format(n0, n1))
  T.lastReset = nil
  W.fire("PLAYER_DEAD"); W.tick(0.05, 1)
  check("T2 while rules are off a death does no tracker work", T.lastReset ~= "death", tostring(T.lastReset))
  -- a cast registered as consuming an aura: while rules are off it changes nothing the tracker would answer
  T.AddConsumer(4242, 4343)
  T.Observe(4343, true, "test")
  local s = T.states[4343]
  if s then s.consumedAt = nil end
  T.OnCastWindows(4242)
  s = T.states[4343]
  check("T3 while rules are off a cast changes nothing the tracker would answer", s == nil or s.consumedAt == nil, s and tostring(s.consumedAt))
  slash("enable"); W.tick(0.1, 4)
  check("(control) T4 /xui enable: the tracker listens again", listeners("TRAIT_CONFIG_UPDATED") == n0, listeners("TRAIT_CONFIG_UPDATED"))
  T.Observe(4343, true, "test")
  T.OnCastWindows(4242)
  s = T.states[4343]
  check("(control) T5 rules on: a consuming cast is noted again", s ~= nil and s.consumedAt ~= nil)
  T.ClearConsumer(4242)
end)

-------------------------------------------------------------------------------------------------------------------------------------
-- O. the rules-off line in the settings window
-------------------------------------------------------------------------------------------------------------------------------------
section("O", function()
  local function offLine()
    local of = ACD.OpenFrames[APP]
    local fr = of and of.frame
    if not fr then return nil end
    for _, ch in ipairs({ fr:GetChildren() }) do
      if ch:IsShown() then
        for _, rg in ipairs({ ch:GetRegions() }) do
          if rg.GetText and rg:IsShown() and tostring(rg:GetText() or ""):find("Rules are off", 1, true) then return ch, rg end
        end
      end
    end
  end
  slash(""); W.tick(0.1, 4)
  check("(control) O0 rules on: no rules-off line in the window", windowOpen() and offLine() == nil)
  slash("disable"); W.tick(0.05, 1)
  local ln, fs = offLine()
  check("O1 /xui disable with the window open: one plain line in the window says rules are off and how to turn them on",
    ln ~= nil and tostring(fs:GetText()):find("/xui enable", 1, true) ~= nil, fs and fs:GetText())
  if ln then
    local of = ACD.OpenFrames[APP]
    local fr = of.frame
    local ver = of.xuiChrome and of.xuiChrome.info
    local closeBtn = ns.OptionsApi.FrameCloseButton and ns.OptionsApi.FrameCloseButton(of)
    local l, r, b, t = ln:GetLeft(), ln:GetRight(), ln:GetBottom(), ln:GetTop()
    local textW = fs:GetStringWidth()
    local ok = l and r and l >= fr:GetLeft() and r <= fr:GetRight() and b >= fr:GetBottom() and t <= fr:GetTop()
    check("O2 the line sits inside the window", ok, ("line %s..%s, window %s..%s"):format(tostring(l), tostring(r), tostring(fr:GetLeft()), tostring(fr:GetRight())))
    check("O3 the line starts right of the version link and does not touch it", ver and l >= ver:GetRight(), ver and ("%s vs %s"):format(tostring(l), tostring(ver:GetRight())))
    check("O4 the line ends left of the Close button and does not touch it", closeBtn == nil or r <= closeBtn:GetLeft(), closeBtn and ("%s vs %s"):format(tostring(r), tostring(closeBtn:GetLeft())))
    check("O5 the text fits the line (estimated width)", textW <= (r - l), ("%s > %s"):format(tostring(textW), tostring(r - l)))
    check("O6 whole-pixel size and place", l == math.floor(l) and r == math.floor(r), ("%s %s"):format(tostring(l), tostring(r)))
    check("O7 the line takes no mouse (clicks pass)", not (ln.IsMouseEnabled and ln:IsMouseEnabled()))
  else
    for _, nm in ipairs({ "O2 inside the window", "O3 right of the version link", "O4 left of the Close button", "O5 text fits", "O6 whole pixels", "O7 takes no mouse" }) do
      check(nm .. " (the line)", false, "no rules-off line")
    end
  end
  slash("enable"); W.tick(0.05, 1)
  check("(control) O8 /xui enable with the window open: the line goes at once", offLine() == nil)
  -- off while the window is closed, then opened: the line is there from the start
  ns.Options.Toggle(); W.tick(0.1, 4)
  slash("disable"); W.tick(0.05, 1)
  slash(""); W.tick(0.1, 4)
  check("O9 rules turned off while the window was closed: the line shows when it opens", offLine() ~= nil)
  -- collapsed: hidden; rules turned on while collapsed, then expanded: still hidden
  local of = ACD.OpenFrames[APP]
  local c = of.xuiChrome
  c.arrow:GetScript("OnClick")(c.arrow); W.tick(0.05, 1)
  local ch = offLine()
  check("(control) O10 the collapsed window shows no rules-off line", ch == nil)
  slash("enable"); W.tick(0.05, 1)
  c.arrow:GetScript("OnClick")(c.arrow); W.tick(0.05, 1)
  check("(control) O11 rules turned on while collapsed: expanded, the window shows no rules-off line", offLine() == nil)
  if windowOpen() then ns.Options.Toggle(); W.tick(0.1, 4) end
end)

ns.Print = realPrint
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
