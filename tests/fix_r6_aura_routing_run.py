#!/usr/bin/env python3
"""Offline test (round 6, REQUEST-LOG A23 SD-54, her words: "check how EUI checks. it does not fail and performance is kept low"; the
design: docs/plans/AURA-CHECKS-EUI-STUDY-2026-11-12.md section 5; round-5 gate-2 blockers P1 / P3 / P4 and the review-R3 talent net).
What the player sees stays the same; what an event costs drops. Each case asserts the visible outcome AND that the rules whose answer
did not change are not checked again in full (before round 6 every aura or cooldown rule was), so each fails on the round-5 files:
  1. a proc in combat (secret payload; its Cooldown Manager icon lights): its display shows and its sound plays on the next frame;
  2. ... the proc falls off: the display hides on the next frame;
  3. a NeverSecret aura in combat (no icon): answered by the aura API on the next frame;
  4. out of combat an aura no rule watches re-checks no rule and reads nothing; a watched one re-checks only its rule and its cue;
  5. a full update with an aura gone hides its display on the next frame; target and focus changes still re-check every rule;
  6. a rule matched by its Tracked Buffs icon's name is read on every aura event and shows when the icon lights;
  7. a same-name aura learned in game (AuraAlias.lua) shows the rule that lists the other ID;
  8. stacks and time left changing while readable: the count text follows on the next frame;
  9. a raid storm on the boss (other players' debuffs, readable or secret): your debuffs are listed once per pass, no target rule is
     checked again in full, and your debuff appearing shows its rule on the next frame;
 10. load conditions are untouched (dismounting hides a "mounted only" display on the next frame), and a talent picked loads its rule
     on the talent event, on the next frame (round 7, SD-60, her answer "1": events only; an intended change of this check, which
     before asked for a talent picked with none of the talent events to load its rule within about a second by a once-a-second read;
     with no event nothing reads the talents now, tests/fix_r2_engine_followups_run.py);
 11. /xui disable: no check is read, no rule re-checked, no engine timer made, whatever events come (kept as before);
 plus the round-5 engine gaps: a cooldown event with a spell ID re-checks only that spell's rule, one without re-reads the cooldowns
 and re-checks only what changed; a cast re-checks no unrelated rule; a "seconds left" crossing re-checks only its rule and its cues;
 a dynamic group's layout reads only its own members; no frame script stays set while events stream in (one-shot timers instead).
Run: python3 tests/fix_r6_aura_routing_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- the game model
Enum.SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
local G = { auras = {}, nextIID = 100, never = { [8070] = true }, names = { [8010] = "Shield Wall", [8011] = "Shield Wall", [8090] = "Hidden Fury", [8091] = "Hidden Fury" },
  cds = {}, target = { exists = false, debuffs = {}, hidden = false }, focus = { exists = false, debuffs = {} }, icons = {}, listReads = 0 }
local function name(id) return G.names[id] or ("Spell " .. tostring(id)) end
C_Spell.GetSpellName = function(id) return id and name(id) or nil end
local function copy(a) local t = {}; for k, v in pairs(a) do t[k] = v end; return t end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
  if unit ~= "player" then return nil end
  local a = G.auras[id]
  if not a or (W.combat and not G.never[id]) then return nil end
  return copy(a)
end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
C_UnitAuras.GetAuraDataByIndex = function(unit, i)
  if unit ~= "player" or W.combat then return nil end
  local list = {}
  for _, a in pairs(G.auras) do list[#list + 1] = a end
  table.sort(list, function(x, y) return x.auraInstanceID < y.auraInstanceID end)
  return list[i] and copy(list[i]) or nil
end
C_UnitAuras.GetUnitAuras = function(unit)
  G.listReads = G.listReads + 1
  local u = G[unit]
  if not (u and u.exists) then return {} end
  if u.hidden then return W.MarkSecret({}) end
  local out = {}
  for _, d in ipairs(u.debuffs) do if d.mine then out[#out + 1] = d end end
  return out
end
C_Secrets.ShouldAurasBeSecret = function() return W.combat and true or false end
C_Secrets.GetSpellAuraSecrecy = function(id) return G.never[id] and 0 or 2 end
local UE0 = UnitExists
UnitExists = function(u) if u == "target" or u == "focus" then return G[u].exists end return UE0(u) end
C_Spell.GetSpellCooldown = function(id)
  local c = G.cds[id]
  if c and W.now < c.start + c.dur then return { startTime = c.start, duration = c.dur, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 } end
  return { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
end
local function icon(spellID)
  local fr = { wasSetFromAura = false, cooldownInfo = { spellID = spellID } }
  fr.GetSpellID = function() return spellID end
  fr.IsShown = function() return true end
  G.icons[spellID] = fr
  return fr
end
local kids = { icon(8060), icon(8091) }
BuffIconCooldownViewer = { IsVisible = function() return true end, GetChildren = function() return unpack(kids) end }
local function pay(t) if W.combat then return W.MarkSecret(t) end return t end
local function gain(id, dur, stacks)
  local old = G.auras[id]
  G.nextIID = G.nextIID + 1
  local a = { spellId = id, auraInstanceID = G.nextIID, name = name(id), icon = 136243, applications = stacks or 1, duration = dur or 30,
    expirationTime = W.now + (dur or 30), isHelpful = true, sourceUnit = "player" }
  G.auras[id] = a
  W.fire("UNIT_AURA", "player", pay({ addedAuras = { a }, removedAuraInstanceIDs = old and { old.auraInstanceID } or nil }))
  return a
end
local function lose(id) local a = G.auras[id]; if a then G.auras[id] = nil; W.fire("UNIT_AURA", "player", pay({ removedAuraInstanceIDs = { a.auraInstanceID } })) end end
local function nothing() W.fire("UNIT_AURA", "player", pay({ updatedAuraInstanceIDs = { 7777 } })) end
local function debuff(unit, id, mine)
  G.nextIID = G.nextIID + 1
  local d = { spellId = id, auraInstanceID = G.nextIID, duration = 12, expirationTime = W.now + 12, applications = 1, mine = mine }
  table.insert(G[unit].debuffs, d)
  W.fire("UNIT_AURA", unit, pay({ addedAuras = { d } }))
  return d
end
-- the addons and a profile: 40 buff rules with a display and its time text, 16 target-debuff rules, 12 cooldown rules, and the rules
-- each case is about
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local function mk(nm, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.trigger = "condition"; r.visual.text.enabled = true; r.sound.enabled = false
  f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local function buff(nm, id, f) return mk(nm, function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, id, "present", "none"; r.visual.trigger = "buffActive"; if f then f(r) end end) end
local function soundCue(p, file) local c = ns.NewCueRule(p, "sound"); c.sound.source, c.sound.value = "file", file; return c end
local dyn = ns.NewFolder("Dynamic test"); dyn.cType = "dynamic"
local others = {}
for i = 1, 40 do others[#others + 1] = buff("buff " .. i, 300000 + i, function(r) if i <= 10 then r.folder = dyn.id end end) end
local tgts = {}
for i = 1, 16 do tgts[i] = mk("debuff " .. i, function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "targetDebuff", spellID = 340000 + i, unit = "target", state = "yes" } } } end) end
local cds = {}
for i = 1, 12 do cds[i] = mk("cooldown " .. i, function(r) r.useCooldown, r.spellID, r.cdState, r.buffState = true, 400000 + i, "ready", "none" end) end
local PROC = buff("proc", 8060); local procCue = soundCue(PROC, "proc.ogg")
local NEVER = buff("never secret", 8070); soundCue(NEVER, "never.ogg")
local WATCH = buff("watched", 8001, function(r) r.visual.count = { enabled = true, source = "stacks" } end); local watchCue = soundCue(WATCH, "watched.ogg")
local ALIAS = buff("alias", 8010)
local NAMEM = buff("name match", 8090)
local MOUNT = buff("mounted only", 8001, function(r) r.load.mounted = "yes"; r.visual.trigger = "condition" end)
local LEFT = buff("seconds left", 8020, function(r) r.buffTimeOp, r.buffTimeSec = "<=", 5; r.visual.trigger = "condition" end); local leftCue = soundCue(LEFT, "left.ogg")
local MINE = mk("my boss debuff", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "targetDebuff", spellID = 350001, unit = "target", state = "yes" } } } end)
local CAST = mk("cast within", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "castSucceeded", spellID = 9105, window = 2, state = "yes" } } } end)
local TAL = buff("talent rule", 8030, function(r) r.talentMode, r.talents = "all", { { id = 5001, state = "known" } }; r.visual.trigger = "condition" end)
local picked = {}
local IPS0 = IsPlayerSpell
IsPlayerSpell = function(id) if id == 5001 then return picked[id] == true end return IPS0(id) end
ns.MarkDirty()
W.tick(1 / 60, 30)
-- what is counted
local evals = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) evals[r] = (evals[r] or 0) + 1; return E0(r, ...) end
local function reset() for k in pairs(evals) do evals[k] = nil end; G.listReads = 0 end
local function count(list) local n = 0; for _, r in ipairs(list) do if evals[r] then n = n + 1 end end; return n end
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown(r) local fr = framesOf and framesOf[r]; return fr and fr:IsShown() and true or false end
local function played(f) local n = 0; for _, s in ipairs(W.sounds) do if s == f then n = n + 1 end end; return n end
local function frame(n) W.tick(1 / 60, n or 1) end
local function quiet() frame(6) end

-- 4. out of combat (payloads readable)
quiet(); reset()
gain(8888, 10); frame(1)
check("4. out of combat an aura no rule watches re-checks no rule", count(ns.rules) == 0, count(ns.rules) .. " rules re-checked")
quiet(); reset()
local p0 = played("watched.ogg")
gain(8001, 20, 1); frame(1)
check("4. ... a watched aura appearing shows its display and plays its cue on the next frame", shown(WATCH) and played("watched.ogg") == p0 + 1,
  tostring(shown(WATCH)) .. "/" .. (played("watched.ogg") - p0))
check("4. ... and re-checks only the rules that read it (it, its cue, the rule sharing its aura), not the 40 other buff rules",
  count(others) == 0 and (evals[WATCH] or 0) >= 1 and (evals[watchCue] or 0) >= 1, count(others) .. " other buff rules re-checked")
-- 8. stacks
quiet(); reset()
G.auras[8001].applications = 3; G.auras[8001].expirationTime = W.now + 20
W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { G.auras[8001].auraInstanceID } }); frame(1)
local cnt = framesOf[WATCH] and framesOf[WATCH].count and framesOf[WATCH].count:GetText()
check("8. stacks 1 -> 3 while readable: the count text shows 3 on the next frame", tostring(cnt) == "3", cnt)
check("8. ... and no other buff rule is re-checked", count(others) == 0, count(others))
-- 7. a same-name aura learned in game
quiet(); reset()
gain(8011, 25); frame(2)
check("7. a same-name aura learned in game shows the rule that lists the other ID (within 2 frames)", shown(ALIAS), shown(ALIAS))
check("7. ... and no other buff rule is re-checked", count(others) == 0, count(others))
-- 5. full update with an aura gone
quiet(); reset()
G.auras[8011] = nil; G.auras[8001] = nil
W.fire("UNIT_AURA", "player", { isFullUpdate = true }); frame(1)
check("5. a full update with auras gone hides their displays on the next frame", not shown(ALIAS) and not shown(WATCH), tostring(shown(ALIAS)) .. "/" .. tostring(shown(WATCH)))
check("5. ... while the buff rules whose aura did not change are not re-checked", count(others) == 0, count(others))
quiet(); reset()
G.target.exists = true; W.fire("PLAYER_TARGET_CHANGED"); frame(4)
check("5. a target change still re-checks every loaded rule (as before)", count(others) == 40 and count(tgts) == 16, count(others) .. "/" .. count(tgts))
-- 9. raid storm on the boss, readable, then secret
quiet(); reset()
for i = 1, 60 do debuff("target", 6000 + i, false); frame(1) end
check("9. a raid storm on the boss (60 frames of other players' debuffs): no target rule is re-checked", count(tgts) == 0 and not evals[MINE], count(tgts))
reset()
debuff("target", 350001, true); frame(1)
check("9. ... your debuff appearing shows its rule on the next frame", shown(MINE), shown(MINE))
-- 10. load conditions
quiet()
IsMounted = function() return true end; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); gain(8001, 20); frame(3)
check("10. load conditions untouched: mounted, the 'mounted only' display shows", shown(MOUNT), shown(MOUNT))
IsMounted = function() return false end; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); frame(2)
check("10. ... dismounted: it hides within 2 frames", not shown(MOUNT), shown(MOUNT))
gain(8030, 600); frame(3)
check("10. (setup) talent not picked: the talent rule is not shown", not shown(TAL), shown(TAL))
picked[5001] = true; W.fire("TRAIT_CONFIG_UPDATED", 1)   -- (round 7, SD-60: the talent saved; its event)
frame(1)
check("10. a talent picked loads its rule on the talent event, on the next frame (round 7, SD-60: events only)", shown(TAL), shown(TAL))
picked[5001] = false; W.fire("TRAIT_CONFIG_UPDATED", 1)
frame(1)
check("10. ... and dropped again, it unloads on the event, on the next frame", not shown(TAL), shown(TAL))
-- cooldowns
quiet(); reset()
G.cds[400003] = { start = W.now, dur = 30 }; W.fire("SPELL_UPDATE_COOLDOWN", 400003, 400003); frame(1)
check("cooldown with a spell ID: its rule is re-checked on the next frame, the 11 other cooldown rules are not", (evals[cds[3]] or 0) >= 1 and count(cds) == 1, count(cds))
quiet(); reset()
G.cds[400005] = { start = W.now, dur = 30 }; W.fire("SPELL_UPDATE_COOLDOWN"); W.fire("ACTIONBAR_UPDATE_COOLDOWN"); frame(1)
check("cooldown without a spell ID: the cooldowns are read again and only the rule whose cooldown changed is re-checked", (evals[cds[5]] or 0) >= 1 and count(cds) == 1, count(cds))
-- a cast
quiet(); reset()
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-9105-0000", 9105); frame(2)
check("a cast shows its 'cast within' rule on the next frames and re-checks no unrelated rule (no target rule, no other buff rule)",
  shown(CAST) and count(tgts) == 0 and count(others) == 0, tostring(shown(CAST)) .. " " .. count(tgts) .. "/" .. count(others))
-- seconds left
quiet()
gain(8020, 6.5); frame(2)
reset()
local before = played("left.ogg")
for _ = 1, 150 do frame(1); if played("left.ogg") > before then break end end
check("a 'seconds left' threshold crossed: the rule fires (its cue plays)", played("left.ogg") == before + 1, played("left.ogg") - before)
check("... and only that rule and its cue are re-checked at the crossing, not every live rule", count(others) == 0 and count(tgts) == 0, count(others) .. "/" .. count(tgts))
-- dynamic group layout
do
  local rulesReads = 0
  local proxy = setmetatable({}, { __index = function(_, k) return nil end })
  local list = ns.rules
  local mt = { __index = function(t, k) return rawget(list, k) end, __len = function() return #list end }
  -- count reads of the rules' 'folder' field while a dynamic group lays out (its members only, not every rule)
  local spy = {}
  for i, r in ipairs(ns.rules) do
    if not r.folder or r.folder ~= dyn.id then
      local f = r.folder; r.folder = nil
      setmetatable(r, { __index = function(_, k) if k == "folder" then rulesReads = rulesReads + 1; return f end end })
      spy[#spy + 1] = { r, f }
    end
  end
  quiet()
  gain(300003, 30); frame(1)
  for _, e in ipairs(spy) do setmetatable(e[1], nil); e[1].folder = e[2] end
  check("a dynamic group's layout (a member appeared) reads only its own members, not the folder of every rule", rulesReads == 0, rulesReads)
end
-- combat (payloads secret)
W.enterCombat(); frame(5)
quiet(); reset()
local q0 = played("proc.ogg")
G.icons[8060].wasSetFromAura = true; G.auras[8060] = { spellId = 8060, auraInstanceID = 901, name = name(8060), duration = 10, expirationTime = W.now + 10 }
nothing(); frame(1)
check("1. a proc in combat (secret payload, its Cooldown Manager icon lit): display shown and sound played on the next frame",
  shown(PROC) and played("proc.ogg") == q0 + 1, tostring(shown(PROC)) .. "/" .. (played("proc.ogg") - q0))
check("1. ... and the 40 other buff rules are not re-checked in full", count(others) == 0, count(others))
quiet(); reset()
G.icons[8060].wasSetFromAura = false; G.auras[8060] = nil
nothing(); frame(1)
check("2. the proc falls off: its display hides on the next frame", not shown(PROC), shown(PROC))
check("2. ... and the 40 other buff rules are not re-checked in full", count(others) == 0, count(others))
quiet(); reset()
gain(8070, 8); frame(1)
check("3. a NeverSecret aura in combat with no icon: answered by the aura API on the next frame", shown(NEVER), shown(NEVER))
check("3. ... and the other buff rules are not re-checked in full", count(others) == 0, count(others))
quiet(); reset()
G.icons[8091].wasSetFromAura = true; nothing(); frame(1)
check("6. a rule matched by its Tracked Buffs icon's name is read on every aura event: the icon lights, it shows on the next frame", shown(NAMEM), shown(NAMEM))
check("6. ... with no other buff rule re-checked", count(others) == 0, count(others))
G.icons[8091].wasSetFromAura = false; nothing(); frame(2)
quiet(); reset()
G.target.hidden = true
W.fire("UNIT_AURA", "target", pay({})); frame(1)   -- (the list is now hidden: that answer changed once)
quiet(); reset()
for _ = 1, 30 do W.fire("UNIT_AURA", "target", pay({})); frame(1) end
check("9. a secret boss storm (30 frames): your debuffs on the target are listed once per pass (shared by the 17 rows), not once per row",
  G.listReads <= 32, G.listReads .. " list reads")
check("9. ... and no target rule is re-checked in full while nothing changes", count(tgts) == 0, count(tgts))
G.target.hidden = false
W.leaveCombat(); frame(5)
-- no frame script left set while events stream in
do
  local scripted = 0
  local list = {}
  for i, o in ipairs(W.objects) do list[i] = o end
  for _ = 1, 30 do
    nothing(); W.fire("SPELL_UPDATE_COOLDOWN"); frame(1)
    for _, o in ipairs(list) do
      local f = o._scripts and o._scripts.OnUpdate
      if f then local info = debug.getinfo(f, "S"); if info and tostring(info.source):find("Engine.lua", 1, true) then scripted = scripted + 1 end end
    end
  end
  check("P1: while events stream in, the engine sets no frame script (each burst is one one-shot timer)", scripted == 0, scripted .. " frames with Engine.lua's script")
end
-- 11. /xui disable
reset()
local timersBefore = #W.timers
local readsA = 0
local AP0 = ns.AuraPresence
ns.AuraPresence = function(...) readsA = readsA + 1; return AP0(...) end
ns.SetRulesDisabled(true)
for _ = 1, 10 do gain(8001, 10); nothing(); W.fire("SPELL_UPDATE_COOLDOWN"); W.fire("UNIT_AURA", "target", {}); frame(1) end
local engineTimers = 0
for _, t in ipairs(W.timers) do if not t.cancelled then local i = debug.getinfo(t.fn, "S"); if i and tostring(i.source):find("Engine.lua", 1, true) then engineTimers = engineTimers + 1 end end end
check("11. /xui disable: aura and cooldown events read no aura check, re-check no rule, leave no engine timer waiting; nothing is shown",
  readsA == 0 and count(ns.rules) == 0 and engineTimers == 0 and not shown(WATCH), readsA .. " reads, " .. count(ns.rules) .. " rules, " .. engineTimers .. " timers")
ns.AuraPresence = AP0
ns.SetRulesDisabled(false); frame(3)
check("11. /xui enable: the rules answer again", shown(WATCH), shown(WATCH))
return R
end
'''


def main():
    folders = {k: v for k, v in H.find_addons().items() if k != "XayaUI_DevAssist"}
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("ok  " if ok else "FAIL: ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
