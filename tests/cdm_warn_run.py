#!/usr/bin/env python3
"""Offline test (core 0.6.48, Options 0.6.43): Cooldown Manager limits shown where they matter. Xaya, 2026-11-05: "Wherever there are
limits to aura/debuff tracking that are detectable by the addon, create an error message in the relevant display pane or rule display tab
that says 'this _____ requires blizzard's cooldown manager to track it before it can be tracked by the addon.'"
Checks what the player sees: ns.CdmNeeds lists exactly the auras / debuffs the game hides in combat that the Cooldown Manager does not
track (not a never-secret aura, not one the Cooldown Manager tracks, not one a trusted proc glow stands in for, not one whose secrecy the
game will not say), the message wording (Xaya's sentence; another one when the Cooldown Manager does not offer it for the spec), and the
red line at the top of the rule's Display tab and Cues tab (a cue shows its rule's limits too), hidden when there is nothing to say.
Run: python3 tests/cdm_warn_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok) R[#R + 1] = { name, ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
check("ns.CdmNeeds and the Display-tab warning exist", ns and ns.CdmNeeds ~= nil and ns.CdmNeedText ~= nil and ns.CdmWarnArg ~= nil)
if not (ns and ns.CdmNeeds and ns.CdmWarnArg) then return R end
-- secrecy per aura (12.1.5: Enum.SecrecyLevel NeverSecret 0, AlwaysSecret 1, ContextuallySecret 2)
Enum.SecrecyLevel = Enum.SecrecyLevel or { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
local SEC = { [1001] = 2, [1002] = 0, [1003] = 2, [1004] = 2, [2001] = 2, [2002] = 2, [1005] = 2 }
C_Secrets.GetSpellAuraSecrecy = function(id) return SEC[id] end
-- the Cooldown Manager tracks 1003 (an icon is shown) and the ability 3002 that files debuff 2002
local TRACKED = { [1003] = true, [3002] = true }
ns.FindCDMFrame = function(id) return TRACKED[id] and {} or nil end
-- what it offers for this spec (its catalogue): 1001 (not tracked yet), 2002 / 3002; not 1004 or 2001
ns.AuraCatalogue = function() return { [1001] = { "hidden (passive)" }, [2002] = { "Tracked Bars" }, [3002] = { "Tracked Bars" } } end
ns.ProcGlowInfo = function(id) if id == 1005 then return { trusted = true, names = { "Glow" }, yes = 3 } end end
local function rule(name) local r = ns.NewRule(); r.name = name; r.enabled = true; ns.NormalizeRule(r); return r end
ns.rules, ns.folders = {}, {}
local A = rule("Aura rule"); A.useBuff, A.buffID, A.buffState = true, 1001, "present"; A.buffAlt = { 1002, 1003, 1004, 1005 }
A.extra = { list = { { type = "targetDebuff", spellID = 2001, unit = "target", state = "yes" },
                     { type = "targetDebuff", spellID = 2002, cdmID = 3002, unit = "target", state = "yes" },
                     { type = "targetDebuff", spellID = 2001, unit = "target", state = "no" } } }   -- the same untracked debuff again
ns.rules[1] = A
local needs = ns.CdmNeeds(A)
local by = {}
for _, e in ipairs(needs) do by[e.kind .. e.id] = e end
check("a hidden aura the Cooldown Manager offers but does not track is listed, offered", by.aura1001 and by.aura1001.offered == true)
check("a never-secret aura is not listed", by.aura1002 == nil)
check("an aura the Cooldown Manager tracks is not listed", by.aura1003 == nil)
check("a hidden aura it does not offer for this spec is listed, not offered", by.aura1004 and by.aura1004.offered == false)
check("an aura a trusted proc glow stands in for is not listed", by.aura1005 == nil)
check("a target debuff it does not track or offer is listed", by.debuff2001 and by.debuff2001.offered == false)
check("a target debuff tracked through its ability's icon (Cooldown Manager ID) is not listed", by.debuff2002 == nil)
check("a debuff watched by two rows is listed once", (function() local n = 0; for _, e in ipairs(needs) do if e.id == 2001 then n = n + 1 end end; return n == 1 end)())
check("3 limits in all (1001, 1004, debuff 2001), nothing guessed", #needs == 3)
local t1 = ns.CdmNeedText(by.aura1001)
check("message: Xaya's sentence for an aura the Cooldown Manager can track",
  t1:find("This aura (Spell 1001, 1001) requires Blizzard's Cooldown Manager to track it before it can be tracked by the addon.", 1, true) == 1
  and t1:find("Tracked Buffs or Tracked Bars", 1, true) ~= nil)
check("message: a debuff says 'debuff'; one the Cooldown Manager does not offer says it cannot be tracked in combat",
  ns.CdmNeedText(by.debuff2001):find("This debuff (", 1, true) == 1 and ns.CdmNeedText(by.debuff2001):find("cannot be tracked in combat", 1, true) ~= nil)
-- unknown secrecy: not judged; unreadable catalogue: 'offered' unknown, so the main sentence
SEC[1001] = nil
check("an aura whose secrecy the game will not say is not judged", (function() for _, e in ipairs(ns.CdmNeeds(A)) do if e.id == 1001 then return false end end return true end)())
SEC[1001] = 2
ns.AuraCatalogue = function() return {} end
local u = ns.CdmNeeds(A)
local e4; for _, e in ipairs(u) do if e.id == 1004 then e4 = e end end
check("with the catalogue unreadable, 'offered' is unknown and the main sentence is used", e4 and e4.offered == nil
  and ns.CdmNeedText(e4):find("requires Blizzard's Cooldown Manager", 1, true) ~= nil)
ns.AuraCatalogue = function() return { [1001] = { "hidden (passive)" }, [2002] = { "Tracked Bars" }, [3002] = { "Tracked Bars" } } end
-- nothing to say: a rule with only a never-secret aura
local B = rule("Clean rule"); B.useBuff, B.buffID, B.buffState = true, 1002, "present"
ns.rules[2] = B
check("a rule with nothing hidden has no limits", #ns.CdmNeeds(B) == 0)

-- in the settings window
local cue = ns.NewCueRule(A, "icon")
local built = ns.BuildOptionsTable()
local function find(t, want, depth)
  if type(t) ~= "table" or depth > 30 then return nil end
  if t.type == "group" and t.childGroups == "tab" and t.args and t.args.trigger and t.args.display then
    local nm = type(t.name) == "function" and t.name() or t.name
    if nm == want then return t end
  end
  for _, v in pairs(t.args or {}) do local f = find(v, want, depth + 1); if f then return f end end
end
local GA, GB = find(built, "Aura rule", 0), find(built, "Clean rule", 0)
local dw = GA and GA.args.display.args.cdmWarn
local cw = GA and GA.args.cues.args.cdmWarn
check("the rule's Display tab starts with the red message lines", dw and dw.hidden() == false and dw.order < GA.args.display.args.intro.order
  and dw.name():find("requires Blizzard's Cooldown Manager to track it before it can be tracked by the addon", 1, true) ~= nil
  and dw.name():find("|cffff5555", 1, true) ~= nil)
check("the Cues tab shows the same lines", cw and cw.hidden() == false and cw.name() == dw.name())
check("a rule with nothing hidden shows no message", GB and GB.args.display.args.cdmWarn and GB.args.display.args.cdmWarn.hidden() == true)
check("a cue's own Display tab shows its rule's limits", ns.CdmWarnArg(cue).hidden() == false)
TRACKED[1001] = true
check("once the aura is tracked in the Cooldown Manager its line goes away", not dw.name():find("1001", 1, true))
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
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        if not ok:
            bad += 1
            print("FAIL:", name)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
