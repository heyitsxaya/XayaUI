#!/usr/bin/env python3
"""Round 5, V27 release gate fixes (gate3): XayaUI/RecycleBin.lua and XayaUI_Rules/Combat/AuraDisplay.lua no longer poll.

Xaya, 2026-11-10 (REQUEST-LOG A23 SD-28 / SD-29, her words): "every single element of the functionality has been built to run optimally in
a high-cost gaming environment. This means zero code loops, ... and no runaway functions." Her answer on loops: "No running loops"
(nothing loops every frame, nothing polls on a timer, nothing loops over all rules on every game event; a loop runs once, bounded, only
when something actually changes). The V27 gate (tests/gate_performance_run.py) found, in these two files:
  * RecycleBin.lua: a 30-minute purge ticker (C_Timer.NewTicker(1800)) armed all session;
  * AuraDisplay.lua: a 4-a-second D.SyncLive ticker (360 runs after the window closed, none changing anything, 37 passes over all 300
    rules per run), a 5-second performance-guard ticker, and about 1046 passes over all 300 rules in each loading screen.
What the player sees / gets, checked here (each check marked [new] fails on the pre-change files, proved on a copy):
  R  the Recycle Bin page never lists or restores an item past its keep time, and the saved data written at logout has none of them,
     with no timer running;
  A  an engine-drawn display follows the rules engine's own re-check of its rule at once (a load fact: combat), the mover view's
     Save / Cancel brings the engine's icons back at once, and a new aura button of a condition-listed cue is drawn with the condition's
     opacity from the start (before: up to a quarter second late, from the ticker);
  B  a loading screen does not rebuild the engine (no hitch); an edit's rebuild makes a bounded number of passes over the rule list;
  G  (round 6, SD-52: the performance guard is removed; G checked that it read the meter at each fight's end) nothing reads the game's
     meter at a fight's end, and heavy fights change nothing the engine draws;
  V  nothing of the two files is still armed after 30 seconds idle; neither makes a repeating timer.
Run: python3 tests/fix_r5_gate3_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end

-- every timer remembers the file that made it (the V27 gate's own measure: what is still armed, what repeats)
local MADE = {}
local function src() local i = debug.getinfo(4, "S"); return i and i.short_src or "?" end   -- (src, tag, the C_Timer stand-in, its caller)
local function tag(kind)
  local s = src()
  local t = W.timers[#W.timers]
  if t then t.src, t.kind = s, kind end
  MADE[#MADE + 1] = { src = s, kind = kind }
end
local A0, T0, K0 = C_Timer.After, C_Timer.NewTimer, C_Timer.NewTicker
C_Timer.After = function(...) local r = A0(...); tag("After"); return r end
C_Timer.NewTimer = function(...) local r = T0(...); tag("NewTimer"); return r end
C_Timer.NewTicker = function(...) local r = K0(...); tag("NewTicker"); return r end
local function from(file) return function(s) return tostring(s):find(file, 1, true) ~= nil end end
local isBin, isAD = from("RecycleBin.lua"), from("AuraDisplay.lua")

-- the game's aura container cannot run here: a stand-in that keeps what XayaUI asks of it (shown state is the frame's own)
CustomAuraContainerAuraProcessingPolicy = CustomAuraContainerAuraProcessingPolicy or { None = 0 }
AuraContainerSortMethod = AuraContainerSortMethod or { Default = 0 }
AuraContainerSortDirection = AuraContainerSortDirection or { Normal = 0, Reverse = 1 }
AnchorUtil = AnchorUtil or {}
AnchorUtil.FlowLayoutAxis = AnchorUtil.FlowLayoutAxis or { Horizontal = 0, Vertical = 1 }
AnchorUtil.FlowDirection = AnchorUtil.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }
local CF = CreateFrame
CreateFrame = function(kind, ...)
  local o = CF(kind == "AuraContainer" and "Frame" or kind, ...)
  if kind == "AuraContainer" then
    rawset(o, "_init", {})
    for _, m in ipairs({ "SetUnit", "SetAuraProcessingPolicy", "SetAuraGroupCandidateFilters", "SetAuraGroupLayout", "SetAuraGroupEnabled",
      "SetAuraGroupSortMethod", "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection", "SetFlowLayoutMaximumLineSize" }) do
      rawset(o, m, function() end)
    end
    rawset(o, "AddAuraGroup", function(self, name, filter, opts) rawget(self, "_init")[name] = opts and opts.initializeFrame end)
  end
  return o
end
-- a new aura button as the game makes it (Blizzard_CustomAuraButton: the methods the engine's look calls)
local function NewButton()
  local b = CF("Frame", nil, UIParent)
  for _, m in ipairs({ "SetIcon", "SetDurationCooldown", "SetDurationText", "SetApplicationCount", "SetDurationBar", "SetApplicationBar",
    "SetSpellName", "AddDispelTypeTexture" }) do rawset(b, m, function() end) end
  return b
end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local D = ns and ns.AuraDisplay
check("core, the Recycle Bin and the combat engine are loaded", ns and D and D.Build and ns.RecycleItems and ns.RecycleRule)
if not (ns and D and D.Build and ns.RecycleItems and ns.RecycleRule) then return R end
local said = {}
local P0 = ns.Print
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end

-------------------------------------------------------------------------------------------------------------------------------------
-- R. Recycle Bin: an item past its keep time (7 days by default)
-------------------------------------------------------------------------------------------------------------------------------------
local NOW = 1793750000
local realTime = time
time = function(t) if t then return realTime(t) end return NOW end
local function binRule(name)
  local r = ns.NewRule(); r.name = name; r.enabled = true; ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  ns.RecycleRule(r)
  return r
end
local function listed(name) for _, it in ipairs(ns.RecycleItems()) do if it.name == name then return it end end end
local fresh = binRule("Bin fresh")
check("(control) a rule just deleted is listed on the Recycle Bin page", listed("Bin fresh") ~= nil)
NOW = NOW + 168 * 3600 + 60   -- 7 days and a minute later, in the same session (no 30-minute tick in between)
check("[new] R1 past its 7 days, in a long session: the Recycle Bin page no longer lists it", listed("Bin fresh") == nil)
local b2 = binRule("Bin page open")
local it2 = listed("Bin page open")
check("(control) a second rule deleted now is listed and could be restored", it2 ~= nil)
NOW = NOW + 168 * 3600 + 60   -- the page stayed open past its time
local okR = ns.RecycleRestore(it2 and it2.id)
local back = false
for _, r in ipairs(ns.rules) do if r == b2 or r.name == "Bin page open" then back = true end end
check("[new] R2 Restore clicked after its time ran out on an open page: not restored ('no longer in the Recycle Bin')", okR == false and not back,
  tostring(okR) .. " / back " .. tostring(back))
binRule("Bin at logout")
NOW = NOW + 168 * 3600 + 60
local before = #(ns.RecycleDB().items)
W.fire("PLAYER_LOGOUT")
local saved = ns.RecycleDB().items
local kept = false
for _, it in ipairs(saved) do if it.name == "Bin at logout" then kept = true end end
check("[new] R3 logout (or /reload) past its time: the saved data written now no longer holds it", before >= 1 and not kept, "items " .. #saved)
binRule("Bin young")
NOW = NOW + 3600
W.fire("PLAYER_LOGOUT")
check("(control) logout an hour after a delete: the item is kept (6 days 23 hours left)", listed("Bin young") ~= nil)
time = realTime

-------------------------------------------------------------------------------------------------------------------------------------
-- A. the combat engine follows the rules engine's re-check of a rule at once
-------------------------------------------------------------------------------------------------------------------------------------
ns.runtime = ns.runtime or {}
local function rule(name, aura)
  local r = ns.NewRule(); r.name = name; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.w, r.visual.h = 40, 40
  r.useBuff, r.buffID, r.buffState = true, aura, "present"
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
-- RC: "Only in combat" (Load tab), shown when its trigger is true: the engine shows its slot only while the rule is loaded
local RC = rule("Engine in combat only", 74101); RC.visual.trigger = "condition"; RC.load.combat = "yes"
-- RB: a plain aura display (shown while the aura is up): its slot steps aside only for the mover view
local RB = rule("Engine plain", 74102); RB.visual.trigger = "buffActive"
-- GP / GQ / GCc: a rule whose display is a texture cue that a condition lists (#260): its condition's opacity is drawn on the slot
local GP = rule("Engine gated", 74103); GP.visual.enabled = false
local GQ = ns.NewCueRule(GP, "texture"); GQ.visual.w, GQ.visual.h, GQ.visual.alpha = 40, 40, 0.8
local GCc = ns.NewRule(); GCc.name = "Condition 1"; GCc.parentUid = GP.uid; GCc.enabled = true; GCc.thenCues = { GQ.cueKey }
ns.NormalizeRule(GCc); GCc.parentUid = GP.uid; GCc.thenCues = { GQ.cueKey }; ns.rules[#ns.rules + 1] = GCc
D.Build(); W.tick(1 / 30, 9)
local SC, SB, SG = D._singles[RC], D._singles[RB], D._singles[GP]
check("(control) the engine draws the three displays on their own slots", SC and SC.ok and SB and SB.ok and SG and SG.ok,
  tostring(SC and SC.ok) .. tostring(SB and SB.ok) .. tostring(SG and SG.ok))
if not (SC and SC.ok and SB and SB.ok and SG and SG.ok) then return R end
check("(control) out of combat the 'Only in combat' display's slot is hidden", not SC.frame:IsShown())

-- A1: combat starts and ends eight times; the game draws a frame (1/60 s) after each: the slot follows the engine's re-check by then
local follow, n = 0, 0
for _ = 1, 8 do
  W.tick(1 / 30, 9)
  W.enterCombat(); W.tick(1 / 60, 1); n = n + 1
  if SC.frame:IsShown() then follow = follow + 1 end
  W.tick(1 / 30, 9)
  W.leaveCombat(); W.tick(1 / 60, 1); n = n + 1
  if not SC.frame:IsShown() then follow = follow + 1 end
end
check("[new] A1 combat starts / ends (a load fact): the 'Only in combat' slot shows / hides on the next frame every time (16 of 16)",
  follow == n, follow .. " of " .. n)
-- A2: the same, told the way the rules engine tells it (Engine.lua StepEnabled stores the rule's answers, then ns.SetVisualShown)
local rt = ns.runtime[RC]
rt.info = { ctxOK = true, talentOK = true }; ns.SetVisualShown(RC, false)
local shownA = SC.frame:IsShown()
rt.info = { ctxOK = false, talentOK = true }; ns.SetVisualShown(RC, false)
local shownB = SC.frame:IsShown()
check("[new] A2 the rules engine's re-check of the rule (no frame drawn in between): the slot follows its answer at once",
  shownA == true and shownB == false, tostring(shownA) .. " / " .. tostring(shownB))

-- A3: the mover view's Save / Cancel brings the engine's icons back at once
check("(control) the plain display's slot shows", SB.frame:IsShown())
ns.ToggleUnlock()
check("(control) the mover view opens: the engine's slot steps aside for XayaUI's sample", ns.unlocked and not SB.frame:IsShown())
ns.MoverExit("cancel")
check("[new] A3 the mover view's Save / Cancel answer closes it: the engine's icon is back at once (no frame drawn in between)",
  not ns.unlocked and SB.frame:IsShown(), tostring(ns.unlocked) .. " / " .. tostring(SB.frame:IsShown()))

-- A4: a condition-listed cue's slot gets a new aura button (the aura just came up): the condition's opacity (0.3) is on it at once
ns.runtime[GQ] = ns.runtime[GQ] or {}
ns.runtime[GQ].info = { result = true, mods = { alpha = 0.3 } }
D.SyncLive()
local init = SG.frame._init and SG.frame._init.main
check("(control) the cue's slot has the game's button maker", type(init) == "function")
local btn = NewButton()
if type(init) == "function" then init(btn) end
check("[new] A4 a new aura button of the cue's slot is drawn with its condition's opacity 0.3 from the start (not the display's own 0.8)",
  math.abs((btn:GetAlpha() or 0) - 0.3) < 0.001, btn:GetAlpha())
ns.runtime[GQ].info = { result = true }
D.SyncLive()
check("(control) the condition's change ends: the button is back at the display's own opacity 0.8", math.abs((btn:GetAlpha() or 0) - 0.8) < 0.001, btn:GetAlpha())

-------------------------------------------------------------------------------------------------------------------------------------
-- B. a loading screen does not rebuild the engine; an edit's rebuild is linear in the rules
-------------------------------------------------------------------------------------------------------------------------------------
local builds, realBuild = 0, D.Build
D.Build = function(...) builds = builds + 1; return realBuild(...) end
W.fire("PLAYER_ENTERING_WORLD", false, false); W.tick(1 / 30, 3)
D.Build = realBuild
check("[new] B1 a loading screen (zone change): the engine is not rebuilt (no rebuild hitch on every loading screen)", builds == 0, builds)
-- 120 more rules with a cue each (a big profile): count the passes over the whole rule list in one rebuild
for i = 1, 120 do
  local r = rule("Big " .. i, 75000 + i); r.visual.trigger = "buffActive"
  if i % 2 == 0 then local c = ns.NewCueRule(r, "text"); c.visual.trigger = "condition" end
end
local list = ns.rules
local passes = 0
local rawI = ipairs
ipairs = function(t) if t == list then passes = passes + 1 end return rawI(t) end
local okB, errB = pcall(D.Build)
ipairs = rawI
check("(control) the rebuild runs", okB, errB)
check("[new] B2 one rebuild with " .. #list .. " rule entries: a few passes over the rule list, not one per rule (rules x rules)",
  passes <= 12, passes .. " passes")

-------------------------------------------------------------------------------------------------------------------------------------
-- G. (round 6; Xaya, SD-52: "Remove it (Recommended)") no speed guard: a fight's end reads no meter and changes nothing the engine draws.
-- Changed from "the performance guard reads the game's meter at the end of each fight", which tested the guard she removed.
-------------------------------------------------------------------------------------------------------------------------------------
Enum = Enum or {}
Enum.AddOnProfilerMetric = Enum.AddOnProfilerMetric or { RecentAverageTime = 1 }
local reads = 0
C_AddOnProfiler = { GetAddOnMetric = function(name) reads = reads + 1; if name == "Blizzard_AuraContainer" then return 5.0 end if name == "XayaUI" then return 0.2 end end }
local function fights(k) for _ = 1, k do W.enterCombat(); W.tick(0.25, 2); W.leaveCombat(); W.tick(0.25, 2) end end
said = {}
fights(6)
local function guardLines() local t = {}; for _, x in ipairs(said) do if x:find("guard", 1, true) or x:find("lean mode", 1, true) then t[#t + 1] = x end end; return t end
check("[new] G1 six heavy fights in a row (5 ms per frame at each fight's end): the meter is never read, no guard line, no guard left",
  reads == 0 and #guardLines() == 0 and D.GuardCheck == nil and D._guard == nil, reads .. " reads; " .. table.concat(guardLines(), " || "))
C_AddOnProfiler = nil
D.Build()

-------------------------------------------------------------------------------------------------------------------------------------
-- V. nothing of the two files polls: no repeating timer, nothing armed after 30 seconds idle
-------------------------------------------------------------------------------------------------------------------------------------
W.tick(0.5, 70)
local pend = {}
for _, t in ipairs(W.timers) do if not t.cancelled and (isBin(t.src) or isAD(t.src)) then pend[#pend + 1] = tostring(t.src) .. " " .. tostring(t.kind) end end
check("[new] V1 after 30 s idle: no timer of RecycleBin.lua or AuraDisplay.lua is still armed", #pend == 0, table.concat(pend, ", "))
local tick = {}
for _, m in ipairs(MADE) do if m.kind == "NewTicker" and (isBin(m.src) or isAD(m.src)) then tick[#tick + 1] = m.src end end
check("[new] V2 neither file made a repeating timer (C_Timer.NewTicker) in this session", #tick == 0, table.concat(tick, ", "))
ns.Print = P0
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
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
