#!/usr/bin/env python3
"""Round 5, the combat aura engine is always on (XayaUI_Rules/Combat/AuraDisplay.lua), and the game-played sound's pane lines
(XayaUI_Rules/AuraSound.lua), with the player documents.

Xaya, SD-47 (REQUEST-LOG A23), her words: "As long as there are any rules enabled that operate in combat, the engine must always run.
It can only be turned off by disabling the rules that run in combat or disabling the rules addon". So no saved engine-off state:
  - older versions saved engineDisplay.groups[id] = false (keep a group with XayaUI) and engineDisplay.auto = false (automatic drawing
    off), set by a console command before core 0.6.56 and by XayaUI Dev Assist since; 0.6.12 and older also saved lean mode. Those
    values are ignored and cleared once, with one plain chat line (round 6, review: before, silently), and no text sends the player
    to Dev Assist or a console command (round-4 review blockers: KEPT_REASON, AUTO_OFF_REASON and the /xuiengine status line said
    "only Dev Assist can change it back");
  - round 6 (SD-52, her answer "Remove it (Recommended)"): the performance guard (lean mode, then drawing off for the session) is
    removed; section 4 checks it is gone (it checked the guard's text before).
Round-4 review blocker, AuraSound.lua: the "Not played by the game" line promised "XayaUI plays the sound itself as before, when it can
see the aura" for every reason, also when XayaUI plays nothing (a rule or its sound switched off, a rule not loaded here). Each line now
says only what is true for its reason.
Docs: XayaUI_Rules/Combat/README.md no longer presents "/xuiengine auto off" as the way to turn the engine off; USER-GUIDE explains SD-31
(an "Only when not mounted" game copy is set up as each fight starts, may play while mounted in that fight, and is taken back after) and
SD-47; HELP-FAQ answers both; QA-CHECKLIST has a step for each (B399, B400).

Outcomes only: whether the engine draws a rule's display (D.OwnerOf, the engine's own answer the status screens show), what chat and the
status screens say, and the pane's line. Every check below that is marked [new] fails on the pre-change files (proved on a copy).
Run: python3 tests/fix_r5_engine_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local D = ns and ns.AuraDisplay
check("core and the combat engine are loaded (Dev Assist off, as on main)", ns and D and D.Build and D.OwnerOf and not (ns.DevAssistOn and ns.DevAssistOn()))
if not (ns and D and D.Build and D.OwnerOf) then return R end
local core = ns.Settings("core")

-- 0. a real login with an older version's saved engine-off state (XayaUIRulesDB, set before the files ran, as the game does)
local e0 = core.engineDisplay or {}
check("[new] login with saved 'automatic drawing off', a kept group and lean mode: none of the three is left in the saved data",
  e0.auto == nil and e0.groups == nil and e0.lean == nil, tostring(e0.auto) .. " / " .. tostring(e0.groups) .. " / " .. tostring(e0.lean))

local said = {}
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end
-- the game's aura container cannot run here: a stand-in that takes every call
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
    for _, m in ipairs({ "SetUnit", "SetAuraProcessingPolicy", "SetAuraGroupCandidateFilters", "SetAuraGroupLayout", "SetAuraGroupEnabled",
      "SetAuraGroupSortMethod", "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection", "SetFlowLayoutMaximumLineSize",
      "AddAuraGroup" }) do rawset(o, m, function() end) end
  end
  return o
end

ns.runtime = ns.runtime or {}
local G = ns.NewFolder("Old kept group")
local r = ns.NewRule(); r.name = "Engine buff"; r.folder = G.id; r.enabled = true
r.visual = r.visual or {}; r.visual.enabled = true; r.visual.w, r.visual.h = 40, 40
r.useBuff, r.buffID, r.visual.trigger = true, 73101, "buffActive"
ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }
D.Build()
check("(control) an aura display in a group: the engine draws it", D.OwnerOf(r) == true, select(2, D.OwnerOf(r)))
local HIDDEN = { present = nil, buffSource = "hidden by the game right now (auras are secret, as in combat): aura 73101" }
local function clean(s)
  if type(s) ~= "string" or s:find("Dev Assist", 1, true) or s:find("<group>", 1, true) then return false end
  for _, w in ipairs({ "auto", "on", "off", "reset" }) do if s:find("/xuiengine " .. w .. "[%s%p]") or s:find("/xuiengine " .. w .. "$") then return false end end
  return true
end

-- 1. an older version's "keep this group with XayaUI" (engineDisplay.groups[id] = false), found when the engine next builds
local e = core.engineDisplay
e.groups = { [G.id] = false }
said = {}
D.Build()
local own, why = D.OwnerOf(r)
check("[new] a group kept with XayaUI by an older version: the engine draws its rule anyway (SD-47)", own == true, tostring(own) .. " / " .. tostring(why))
check("[new]   ...the saved choice is cleared", core.engineDisplay.groups == nil, tostring(core.engineDisplay.groups))
-- (round 6: changed from "...silently: no chat line"; the review asked that saved data is not removed without a word)
check("  ...said in one plain chat line that names no command or developer tool", #said == 1 and said[1]:find("old setting", 1, true) ~= nil and clean(said[1]), table.concat(said, " || "))

-- 2. an older version's "automatic drawing off" (engineDisplay.auto = false)
core.engineDisplay.auto = false
said = {}
D.Build()
own, why = D.OwnerOf(r)
check("[new] automatic drawing switched off by an older version (or Dev Assist): the engine draws anyway (SD-47)", own == true, tostring(own) .. " / " .. tostring(why))
check("[new]   ...the saved switch is cleared", core.engineDisplay.auto == nil, tostring(core.engineDisplay.auto))
check("  ...said in one plain chat line that names no command or developer tool", #said == 1 and said[1]:find("old setting", 1, true) ~= nil and clean(said[1]), table.concat(said, " || "))
local note = ns.HiddenAuraNote and ns.HiddenAuraNote(r, HIDDEN)
check("[new]   ...the status screen's sentence for the rule names no developer tool and no command", note == nil or clean(note), note)

-- 3. what /xuiengine says: the engine is on, and nothing names Dev Assist or an off command
core.engineDisplay.auto = false   -- (written again after the build, as Dev Assist's /xuiengine auto off on another branch would)
said = {}
SlashCmdList.XUIENGINE("")
local st = table.concat(said, "\n")
check("[new] /xuiengine: says the combat engine is on", st:find("combat engine: on", 1, true) ~= nil, st)
check("[new]   ...and names no developer tool or off command (no 'only Dev Assist can turn it back on')", clean(st) and not st:find("OFF", 1, true), st)
check("  ...and the rule is still drawn", D.OwnerOf(r) == true)

-- 3b. /xui disable: the one way a player turns the engine off (with the rules); /xuiengine says so, then /xui enable brings it back
ns.SetRulesDisabled(true)
said = {}
SlashCmdList.XUIENGINE("")
st = table.concat(said, "\n")
check("[new] /xui disable, then /xuiengine: says the engine is off because every rule is off, and how it comes back",
  st:find("combat engine is off because every rule is off", 1, true) ~= nil and not st:find("combat engine: on", 1, true) and clean(st), st)
ns.SetRulesDisabled(false); W.tick(0.6, 3); D.Build()
check("(control) /xui enable: the engine draws the rule again", D.OwnerOf(r) == true)

-- 4. (round 6; Xaya, SD-52: "Remove it (Recommended)") no speed guard: three heavy fights (the game's meter reads 5 ms for Blizzard's
-- aura containers at each fight's end) leave the engine drawing, with no guard line. Changed from "the performance guard's own session
-- state (unchanged behavior, her decision)", which tested the guard she removed.
Enum = Enum or {}
Enum.AddOnProfilerMetric = Enum.AddOnProfilerMetric or { RecentAverageTime = 1 }
local realProf = C_AddOnProfiler
C_AddOnProfiler = { GetAddOnMetric = function(name) if name == "Blizzard_AuraContainer" then return 5 end return 0.2 end, IsEnabled = function() return true end }
said = {}
for _ = 1, 6 do W.enterCombat(); W.tick(0.25, 2); W.leaveCombat(); W.tick(0.25, 2) end
own, why = D.OwnerOf(r)
check("[new] six heavy fights in a row: the engine still draws the display (no speed guard, SD-52)", own == true, tostring(own) .. " / " .. tostring(why))
local gl = {}
for _, x in ipairs(said) do if x:find("guard", 1, true) or x:find("lean mode", 1, true) then gl[#gl + 1] = x end end
check("[new]   ...and no guard line in chat", #gl == 0, table.concat(gl, " || "))
said = {}
D.Status()
st = table.concat(said, "\n")
check("[new]   .../xuiengine names no guard and no meter reading", st:find("combat engine: on", 1, true) ~= nil and not st:find("guard", 1, true)
  and not st:find(" ms", 1, true) and clean(st), st)
check("[new]   ...no guard left in the engine", D.GuardCheck == nil and D._guard == nil)
C_AddOnProfiler = realProf

-- 5. the game-played sound's pane line, one per reason (AuraSound.lua A.StatusLine)
local A = ns.AuraSound
check("the game-played sound is loaded", A and A.StatusLine and A.Plan)
if not (A and A.StatusLine) then return R end
Enum = Enum or {}
Enum.UnitAuraSoundTrigger = Enum.UnitAuraSoundTrigger or { Added = 0, ApplicationsIncreased = 1, Removed = 2 }
local REFUSE = false
C_UnitAuras.AddAuraSound = function() if REFUSE then error("not allowed") end return 9001 end
C_UnitAuras.RemoveAuraSound = function() end
local function SoundRule(name, aura)
  local s = ns.NewRule(); s.name = name; s.enabled = true
  s.useBuff, s.buffID, s.buffState = true, aura, "present"
  s.sound = { enabled = true, source = "file", value = "Interface\\AddOns\\SoundPack\\" .. name .. ".ogg", channel = "Master" }
  s.gameSound = { enabled = true, when = "auto", channel = "Ambience", throttle = 1 }
  ns.NormalizeRule(s); ns.rules[#ns.rules + 1] = s
  return s
end
local base = SoundRule("base", 73201)
check("(control) a rule the game can play: planned", A.Plan(base) ~= nil, select(2, A.Plan(base)))
local promise = "XayaUI plays the sound itself"
local function line(rule) local ok, s = pcall(A.StatusLine, rule); return ok and s or ("error: " .. tostring(s)) end

local off = SoundRule("ruleoff", 73202); off.enabled = false
local t = line(off)
check("rule switched off: says why the game does not play it", t:find("Not played by the game", 1, true) and t:find("switched off", 1, true), t)
check("[new]   ...and does not promise that XayaUI plays it (XayaUI plays nothing either)", not t:find(promise, 1, true), t)

local soff = SoundRule("soundoff", 73203); soff.sound.enabled = false
t = line(soff)
check("[new] rule's sound switched off: no promise that XayaUI plays it", t:find("sound is switched off", 1, true) and not t:find(promise, 1, true), t)

local nl = SoundRule("notloaded", 73204); nl.load = { mode = "all", group = "yes" }
ns.NormalizeRule(nl)
t = line(nl)
check("[new] a rule not set to load here (Only in a group, solo): no promise that XayaUI plays it", t:find("Not played by the game", 1, true)
  and t:find("load", 1, true) and not t:find(promise, 1, true), t)

local kit = SoundRule("kit", 73205); kit.sound = { enabled = true, source = "kit", value = 8959 }
t = line(kit)
check("a [Game] sound kit: XayaUI plays it itself, said with its limit (only when it can see the aura)", t:find("sound kit", 1, true)
  and t:find(promise, 1, true) and t:find("only when it can see the aura", 1, true), t)

REFUSE = true
local rf = SoundRule("refused", 73206)
pcall(A.Sync)
t = line(rf)
check("the game refuses the copy: XayaUI plays it itself, said with its limit", t:find("refused", 1, true) and t:find(promise, 1, true)
  and t:find("only when it can see the aura", 1, true), t)
REFUSE = false
check("[new] no line says 'as before' (the old promise for every reason)", not (line(off) .. line(soff) .. line(nl) .. line(kit) .. line(rf)):find("as before", 1, true))
return R
end
'''


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def doc_checks():
    out = []

    def check(name, ok, extra=""):
        out.append((name + ("" if ok else "  [" + str(extra)[:300] + "]"), bool(ok)))

    readme = read("XayaUI_Rules/Combat/README.md")
    check("[new] Combat README: no longer presents '/xuiengine auto off' as the way to turn the engine off",
          "Turning the engine off is `/xuiengine auto off`" not in readme and "cannot be switched off on its own" in readme)
    check("[new] Combat README: quotes SD-47", "the engine must always run" in readme)
    guide = read("docs/USER-GUIDE.md")
    check("[new] USER-GUIDE: an 'Only when not mounted' game copy is set up as each fight starts, may play while mounted in that fight, and is taken back after",
          "**Only when not mounted** copy is also set up as each fight starts" in guide and "it may also play while you are still mounted" in guide
          and "the copy is taken back" in guide)
    check("[new] USER-GUIDE: the engine is always on while rules are on (SD-47), and no 'only Dev Assist changes that back'",
          "**The engine is always on while rules are on**" in guide and "only Dev Assist changes that back" not in guide)
    faq = read("docs/HELP-FAQ.md")
    check("[new] HELP-FAQ: 'Can I switch the combat engine off?' answered (SD-47)", "### Can I switch the combat engine off?" in faq and "`/xui disable`" in faq)
    check("[new] HELP-FAQ: why an 'Only when not mounted' sound can play while mounted in a fight (SD-31)",
          '### My "Only when not mounted" sound played while I was still mounted.' in faq)
    qa = read("docs/QA-CHECKLIST.md")
    b399 = [l for l in qa.splitlines() if l.startswith("- [ ] **B399.**")]
    b400 = [l for l in qa.splitlines() if l.startswith("- [ ] **B400.**")]
    check("[new] QA-CHECKLIST: one B399 step for SD-31 (daze off the mount in a fight; stay mounted to the end, not played after)",
          len(b399) == 1 and "SD-31" in b399[0] and "daze" in b399[0] and "does NOT play" in b399[0], b399)
    check("[new] QA-CHECKLIST: one B400 step for SD-47", len(b400) == 1 and "SD-47" in b400[0] and "combat engine: on" in b400[0], b400)
    check("[new] QA-CHECKLIST: no step still expects 'automatic mode' on or OFF", "automatic mode" not in qa)
    return out


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    # an older version's saved engine-off state, as the game hands it back at login
    saved = {"XayaUI_Rules": {"XayaUIRulesDB": {"engineDisplay": {"auto": False, "groups": {"f-old": False}, "lean": True}}}}
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)] + doc_checks()
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
