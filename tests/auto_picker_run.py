#!/usr/bin/env python3
"""Offline test (XayaUI_Options 0.6.42): the auto-populate picker (AutoPicker.lua). Xaya, 2026-11-05: "Auto-populate rules should also
provide support for target debuffs - you should be able to also customize auto-populate rule behavior to auto-populate with only
specific, selected auto rules and choose their primary cue type (speech to text, icon, progress texture, progress bar) on a
case-by-case basis". Checks what the player gets: which candidates are listed (cooldowns from the learned spec list, target debuffs
from a stand-in Cooldown Manager catalogue, a buff on yourself left out), that only ticked rows become rules, each rule's trigger and
main cue, the debuff "on / missing" choice, progress bar not made, nothing made twice, and the picker on the Class/Spec Rule Creator page.
Run: python3 tests/auto_picker_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
local AP = ns and ns.AutoPicker
check("the picker is loaded with the settings window", AP ~= nil and AP.Candidates ~= nil and AP.Make ~= nil)
if not AP then return R end
local SPEC = ns.CurrentSpecID()
check("stand-in spec is Vengeance (581)", SPEC == 581)
ns.rules, ns.folders = {}, {}
-- the spec's learned cooldown list (ClassLearn.lua shape)
ns.CLASS_AURA_DATA = { [581] = { entries = {
  { kind = "cd", id = 187827, name = "Metamorphosis" },
  { kind = "cd", id = 204021, name = "Fiery Brand", talent = true },
  { kind = "cd", id = 6789, name = "Third" } } } }
-- a stand-in Cooldown Manager catalogue: 11 = a debuff linked to its ability, 12 = a buff on you (left out), 13 = a debuff with no link
local INFO = {
  [11] = { cooldownID = 11, spellID = 204021, linkedSpellIDs = { 207771 }, hasAura = true, selfAura = false, category = 0 },
  [12] = { cooldownID = 12, spellID = 187827, linkedSpellIDs = {}, hasAura = true, selfAura = true, category = 2 },
  [13] = { cooldownID = 13, spellID = 204596, linkedSpellIDs = {}, hasAura = true, selfAura = false, category = 3 },
  [14] = { cooldownID = 14, spellID = 6789, linkedSpellIDs = {}, hasAura = false, selfAura = false, category = 0 } }
C_CooldownViewer = {
  GetCooldownViewerCategorySet = function(cat) if cat == 0 then return { 11, 14 } elseif cat == 2 then return { 12 } elseif cat == 3 then return { 13, 11 } end return {} end,
  GetCooldownViewerCooldownInfo = function(id) return INFO[id] end,
  IsCooldownViewerAvailable = function() return true, "" end }

local C = AP.Candidates(SPEC)
local byKey = {}
for _, c in ipairs(C) do byKey[c.key] = c end
check("candidates: the three learned cooldowns", byKey["cd:187827"] and byKey["cd:204021"] and byKey["cd:6789"] and byKey["cd:204021"].talent == true)
check("candidates: a debuff linked to its ability (aura 207771, Cooldown Manager 204021)",
  byKey["db:207771"] and byKey["db:207771"].kind == "debuff" and byKey["db:207771"].cdmID == 204021)
check("candidates: a debuff with no link (its own ID, no separate Cooldown Manager ID)", byKey["db:204596"] and byKey["db:204596"].cdmID == nil)
check("candidates: a buff on yourself (selfAura) and an entry with no aura are not listed as debuffs", byKey["db:187827"] == nil and byKey["db:6789"] == nil)
check("candidates: 5 in all, cooldowns first, each listed once", #C == 5 and C[1].kind == "cd" and C[4].kind == "debuff" and C[5].kind == "debuff")
check("candidates: another spec gets its learned cooldowns but no debuffs (the Cooldown Manager answers for the current spec only)",
  (function() ns.CLASS_AURA_DATA[577] = { entries = { { kind = "cd", id = 195072, name = "Fel Rush" } } }; local o = AP.Candidates(577); return #o == 1 and o[1].kind == "cd" end)())

-- nothing ticked: nothing made
local made, skipped, notMade, msg = AP.Make(SPEC)
check("nothing ticked: nothing is made, and the message says so", made == 0 and #ns.rules == 0 and tostring(msg):find("Nothing is ticked", 1, true) ~= nil)

-- defaults
local on, cue, when = AP.Choice(SPEC, byKey["db:207771"])
check("defaults: not ticked, Icon, a debuff is true while on the target", on == false and cue == "icon" and when == "on")
AP.SetChoice(SPEC, byKey["db:204596"], "cue", "speech")
local _, cue2, when2 = AP.Choice(SPEC, byKey["db:204596"])
check("defaults: a debuff with a speech cue defaults to 'missing' (a reminder)", cue2 == "speech" and when2 == "missing")

-- tick four, one of them with a progress bar
AP.SetChoice(SPEC, byKey["cd:187827"], "on", true); AP.SetChoice(SPEC, byKey["cd:187827"], "cue", "speech")
AP.SetChoice(SPEC, byKey["cd:204021"], "on", true)                                            -- icon (default)
AP.SetChoice(SPEC, byKey["db:207771"], "on", true); AP.SetChoice(SPEC, byKey["db:207771"], "cue", "progtex")
AP.SetChoice(SPEC, byKey["db:204596"], "on", true)                                            -- speech, missing
AP.SetChoice(SPEC, byKey["cd:6789"], "on", true); AP.SetChoice(SPEC, byKey["cd:6789"], "cue", "bar")
made, skipped, notMade, msg = AP.Make(SPEC)
check("made 4 rules; the progress bar one is not made and the message says why", made == 4 and skipped == 0 and notMade == 1
  and tostring(msg):find("Progress bar", 1, true) ~= nil)
local parents, cues = {}, {}
for _, r in ipairs(ns.rules) do if r.isCue then cues[r.parentUid] = cues[r.parentUid] or {}; table.insert(cues[r.parentUid], r) else parents[#parents + 1] = r end end
local function parentFor(test) for _, r in ipairs(parents) do if test(r) then return r end end end
local meta = parentFor(function(r) return r.spellID == 187827 end)
local brand = parentFor(function(r) return r.spellID == 204021 end)
local function row(r) return r and r.extra and r.extra.list and r.extra.list[1] end
local dOn = parentFor(function(r) local x = row(r); return x and x.spellID == 207771 end)
local dMiss = parentFor(function(r) local x = row(r); return x and x.spellID == 204596 end)
check("4 rules, each with exactly one cue, and no rule for the unticked or progress-bar rows",
  #parents == 4 and meta and brand and dOn and dMiss and #(cues[meta.uid] or {}) == 1 and #(cues[dOn.uid] or {}) == 1
  and parentFor(function(r) return r.spellID == 6789 end) == nil)
check("cooldown rule: Cooldown trigger 'ready', loads only on this spec", meta.useCooldown == true and meta.cdState == "ready"
  and meta.load.specs["581"] == true and meta.sound.enabled == false and meta.visual.enabled == false)
check("cooldown rule with a speech cue that says '<name> ready'", cues[meta.uid][1].cueKind == "speech" and cues[meta.uid][1].sound.source == "tts"
  and cues[meta.uid][1].sound.value == meta.name .. " ready")
check("a talent cooldown loads only while the talent is known", brand.talentMode == "all" and brand.talents[1].id == 204021 and brand.talents[1].state == "known")
check("cooldown rule with an icon cue", cues[brand.uid][1].cueKind == "icon" and cues[brand.uid][1].visual.kind == "spellicon"
  and not (cues[brand.uid][1].visual.fill and cues[brand.uid][1].visual.fill.enabled))
check("debuff rule: a Target Debuff trigger on the target, true while ON it, with the Cooldown Manager ID for combat",
  row(dOn).type == "targetDebuff" and row(dOn).unit == "target" and row(dOn).state == "yes" and row(dOn).cdmID == 204021 and dOn.cdState == "none")
check("debuff rule with a progress texture cue (an icon whose fill is on)", cues[dOn.uid][1].cueKind == "icon" and cues[dOn.uid][1].visual.fill.enabled == true)
check("debuff rule 'missing from target': the trigger is true while the debuff is NOT on, and the speech says '<name> missing'",
  row(dMiss).state == "no" and cues[dMiss.uid][1].cueKind == "speech" and cues[dMiss.uid][1].sound.value == dMiss.name .. " missing")
-- where they went
local function folderName(id) for _, f in ipairs(ns.folders) do if f.id == id then return f.name, f.parent end end end
local mN, mP = folderName(meta.folder)
local dN, dP = folderName(dOn.folder)
local pN = folderName(mP)
local _, specName = GetSpecializationInfoByID(581)   -- id, name, description, ...: the name is the second value
check("rules sit in '<Class> <Spec> - autorule population' > Cooldowns / Target Debuffs", mN == "Cooldowns" and dN == "Target Debuffs" and mP == dP
  and pN == (UnitClass("player") .. " " .. specName .. " - autorule population"))
-- outcome in the engine: no target here, so the debuff is not on it
local ctx = ns.ReadContext()
local okOn, onRes = pcall(ns.Evaluate, dOn, ctx)
local okMiss, missRes = pcall(ns.Evaluate, dMiss, ctx)
check("engine: with no debuff on the target, 'on the target' is false and 'missing' is true", okOn and okMiss and onRes == false and missRes == true)
-- again: nothing twice
local n0 = #ns.rules
made, skipped = AP.Make(SPEC)
check("pressing Make again makes nothing twice (4 skipped)", made == 0 and skipped == 4 and #ns.rules == n0)

-- the picker on the Class/Spec Rule Creator page
local built = ns.BuildOptionsTable()
local function find(t, depth)
  if type(t) ~= "table" or depth > 30 then return nil end
  if t.type == "group" and t.name == "Class/Spec Rule Creator" then return t end
  for _, v in pairs(t.args or {}) do local f = find(v, depth + 1); if f then return f end end
end
local G = find(built, 0)
local a = G and G.args or {}
check("the Rule Creator page has the picker: a header, a row per candidate, Tick all / Untick all / Make", a.apPickHdr and a.apPick1 and a.apPick5
  and a.apCue1 and a.apTickAll and a.apTickNone and a.apMake and a.apPick6 == nil)
local dbRow
for i = 1, 5 do if a["apWhen" .. i] then dbRow = dbRow or i end end
check("only debuff rows have the 'On the target / Missing from target' choice", dbRow == 4 and a.apWhen5 ~= nil and a.apWhen1 == nil)
check("the cue choice lists Speech, Icon, Progress texture and Progress bar (not yet)", a.apCue1.values.speech and a.apCue1.values.icon
  and a.apCue1.values.progtex and tostring(a.apCue1.values.bar):find("not yet", 1, true) ~= nil)
a.apTickNone.func()
check("Untick all on the page unticks every row", a.apPick1.get() == false and a.apPick4.get() == false)
a.apPick2.set(nil, true)
check("ticking a row on the page is remembered for the spec", ns.AutoCfg().picks["581"][C[2].key].on == true)
check("the existing auto-populate buttons are still there", a.apSpec1 ~= nil and a.apClass ~= nil)
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
