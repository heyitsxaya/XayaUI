#!/usr/bin/env python3
"""Offline test (round 6, REQUEST-LOG A23 SD-54: the engine's aura and cooldown checks; rebuilt in round 7 for SD-63, her answer "Keep,
fix first"). Proves that no rule answers differently, and that nothing is drawn differently, between the engine as it was before round 6
and the engine now.

The same event streams are played, frame by frame, into copies of the stand-in game that differ only in the rule engine: XayaUI_Rules/
Engine.lua, Conditions.lua, AuraAlias.lua, Visual.lua, BarCue.lua, Outcomes.lua and Triggers.lua at commit 89ea79ab (the round-5 save,
before round 6), against the files of the tree this test sits in. Everything else is the same tree.

  1. STRICT (the proof): the old engine runs at the routed pace of the engine under test (its two lines ROUTED_GAP / ROUTED_DUE are
     copied from the Engine.lua under test into the old one; round 7 runs at 10 a second, SD-61 "10/s for all, like EUI"; the pace is
     her decision and is tested in tests/fix_r2_engine_followups_run.py and tests/engine_routing_run.py). After every frame, for every
     rule: whether it is active, whether XayaUI wants its display shown, and what is DRAWN: shown, visible, the duration / count / shield
     texts, grey, opacity, a bar's fill, where the display sits (a dynamic group's layout), who draws it (XayaUI or the combat engine),
     every group frame's shown state and place, and every sound played so far, in order. All must match, frame by frame, with two
     allowances, each counted and printed:
       a. REDRAW: a duration text shown in tenths of a second may differ by one tenth, and a bar's fill by one hundredth, for a frame:
          the display moves them itself (Visual.lua's effects loop, about 30 times a second); the old engine also redrew them whenever
          any aura event re-checked every aura rule (a visible difference she was told of in round 6);
       b. EARLIER: a row may already show what the old engine shows within the next tenth of a second and one frame. The new engine
          runs a pass only when an event changed something a rule reads; the old one ran one for every aura or cooldown event, and each
          pass made the next one wait the pace. So after events no rule reads (a raid's debuffs on your target) the new engine can take
          the next real change on the next frame while the old one still waits: never later, at most one pace window earlier.
     At the last frame of every part of the streams (each is followed by at least a tenth of a second and one frame) every row must
     match exactly (allowance a only): a rule left on an answer it no longer gives (the round-6 stuck icon) cannot hide behind b.
  2. PACE BOUND: against the old engine at its own pace (1/30 s), every row the engine under test draws must be one the old engine drew
     within the last tenth of a second and one frame (it never draws something the old one never did, and lags by at most the pace),
     and the same sounds play.

The streams use readable (non-secret) samples wherever the game gives them, so the routing branches are exercised, not bypassed:
  out of combat, readable payloads: auras added, updated (refresh, stacks) and removed by instance ID; an aura no rule watches; extra IDs;
  a same-name aura learned in game; full updates (nothing changed / an aura gone); a Tracked Buffs icon matched by name lit with a
  readable payload about another aura; a shield amount, and the shield absorbing damage (the aura updated, its duration the same); the target's and the focus's debuffs (yours and a raid's, a storm), target /
  focus changes;
  in combat: NeverSecret auras added, refreshed and removed with readable payloads (alone, and mixed with a hidden entry), secret payloads,
  a Cooldown Manager icon lit / unlit (with a secret payload and with a readable NeverSecret one), the target's debuffs hidden;
  cooldowns: SPELL_UPDATE_COOLDOWN with a spell ID only, with a shared category (two spells), with a start-recovery category (the global
  cooldown), with an item ID (two items sharing a cooldown), with nothing; BAG_UPDATE_COOLDOWN; a cooldown that changed with no
  cooldown event, then a cast; usability changing with a spell-ID cooldown event; charges spent and regained; cooldown ends;
  casts ("cast within N seconds"); a load condition (mounted);
  cue / parent chains: icon, sound and bar cues and a condition with its own cue on rules whose triggers change; rules in a dynamic group;
  timing edges: an aura lost about 10 ms before its parent's whole-second countdown wake just after a routed pass (the round-6 stuck
  icon), and regained (its sound cue plays again); an aura refreshed just after a wake; a "seconds left" threshold crossed with an aura
  event in the same frame; a cooldown ending on a routed pass.
Its power is proved in round 7 on deliberately broken engines (see the round-7 report): each must FAIL this test.
Run: python3 tests/fix_r6_routing_replay_run.py   (Lua 5.1 via lupa; needs git, to read the pre-round-6 files; set XUI_REPLAY_GIT to a
clone of the repository when the tree this test sits in is not one)."""
import os, re, shutil, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

BASE = "89ea79ab"   # the round-5 save: the engine before round 6
OLD_FILES = ["Engine.lua", "Conditions.lua", "AuraAlias.lua", "Visual.lua", "BarCue.lua", "Outcomes.lua", "Triggers.lua"]
FRAME = 1 / 60.0

LUA = r'''
return function(W, L)
local OUT = { frames = {}, errors = {} }
-- ---------------------------------------------------------------- the game model (identical in every copy)
Enum.SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
local G = { auras = {}, nextIID = 100, never = { [9070] = true, [9071] = true }, names = {}, cds = {}, charges = {}, usable = {}, absorb = 0,
  target = { exists = false, debuffs = {}, hidden = false }, focus = { exists = false, debuffs = {} }, icons = {}, gcd = nil, onGCD = { [9304] = true },
  items = { [5555] = { count = 1 }, [5556] = { count = 1 } } }
G.names[9010], G.names[9011] = "Shield Wall", "Shield Wall"
G.names[9090], G.names[9091] = "Hidden Fury", "Hidden Fury"
local secretN = 0
local function SEC() secretN = secretN + 1; return W.MarkSecret("secret-" .. secretN) end   -- (a unique secret value)
local function name(id) return G.names[id] or ("Spell " .. tostring(id)) end
C_Spell.GetSpellName = function(id) return id and name(id) or nil end
local function auraCopy(a) local t = {}; for k, v in pairs(a) do t[k] = v end; return t end
local function readable(id) return not W.combat or G.never[id] end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
  if unit ~= "player" then return nil end
  local a = G.auras[id]
  if not a or not readable(id) then return nil end
  return auraCopy(a)
end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
  if unit ~= "player" or W.combat then return nil end
  local list = {}
  for _, a in pairs(G.auras) do list[#list + 1] = a end
  table.sort(list, function(x, y) return x.auraInstanceID < y.auraInstanceID end)
  return list[i] and auraCopy(list[i]) or nil
end
C_UnitAuras.GetAuraDataByAuraInstanceID = function() return nil end
C_UnitAuras.GetUnitAuras = function(unit, filter)
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
UnitGetTotalAbsorbs = function() return G.absorb end
local function running(c) return c and W.now < c.start + c.dur end
C_Spell.GetSpellCooldown = function(id)
  if id == 61304 then
    if running(G.gcd) then return { startTime = G.gcd.start, duration = G.gcd.dur, isEnabled = true, isActive = true, isOnGCD = true, modRate = 1 } end
    return { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
  end
  local c = G.cds[id]
  if running(c) then return { startTime = c.start, duration = c.dur, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 } end
  if G.onGCD[id] and running(G.gcd) then return { startTime = G.gcd.start, duration = G.gcd.dur, isEnabled = true, isActive = true, isOnGCD = true, modRate = 1 } end
  return { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
end
C_Spell.GetSpellCharges = function(id)
  local c = G.charges[id]
  if not c then return nil end
  return { currentCharges = c.cur, maxCharges = c.max, isActive = c.cur < c.max, cooldownStartTime = c.cur < c.max and c.start or 0,
    cooldownDuration = c.cur < c.max and 20 or 0, chargeModRate = 1 }
end
C_Spell.IsSpellUsable = function(id) local u = G.usable[id]; if u == nil then return true, false end; return u, not u end
C_Item.GetItemCount = function(id) local it = G.items[tonumber(id)]; return it and it.count or 0 end
C_Item.IsUsableItem = function(id) local it = G.items[tonumber(id)]; return (it and it.count > 0) and true or false, false end
local function itemCD(id) local it = G.items[tonumber(id)]; local c = it and it.cd; if running(c) then return c.start, c.dur, 1 end return 0, 0, 1 end
C_Container = C_Container or {}
C_Container.GetItemCooldown = itemCD
C_Item.GetItemCooldown = itemCD
-- a Cooldown Manager buff viewer with icons the test lights and unlights (wasSetFromAura is a plain flag Blizzard sets itself)
local function icon(spellID)
  local fr = { wasSetFromAura = false, auraInstanceID = nil, cooldownInfo = { spellID = spellID } }
  fr.GetSpellID = function() return spellID end
  fr.IsShown = function() return true end
  G.icons[spellID] = fr
  return fr
end
local viewerKids = { icon(9060), icon(9091), icon(9041) }
BuffIconCooldownViewer = { IsVisible = function() return true end, GetChildren = function() return unpack(viewerKids) end }
-- ---------------------------------------------------------------- payload helpers
-- out of combat every payload is readable. In combat: secret auras come as a secret payload (pay), NeverSecret ones as a readable one
-- (payN); mixed() builds a readable payload holding a NeverSecret entry and a hidden one
local function pay(t) if W.combat then return W.MarkSecret(t) end return t end
local function payFor(id, t) if W.combat and not G.never[id] then return W.MarkSecret(t) end return t end
local function newAura(id, dur, stacks)
  G.nextIID = G.nextIID + 1
  return { spellId = id, auraInstanceID = G.nextIID, name = name(id), icon = 136243, applications = stacks or 1, duration = dur or 30,
    expirationTime = W.now + (dur or 30), isHelpful = true, sourceUnit = "player", isFromPlayerOrPlayerPet = true }
end
local function gain(id, dur, stacks)
  local old = G.auras[id]
  local a = newAura(id, dur, stacks)
  G.auras[id] = a
  W.fire("UNIT_AURA", "player", payFor(id, { addedAuras = { a }, removedAuraInstanceIDs = old and { old.auraInstanceID } or nil }))
  return a
end
local function lose(id)
  local a = G.auras[id]
  if not a then return end
  G.auras[id] = nil
  W.fire("UNIT_AURA", "player", payFor(id, { removedAuraInstanceIDs = { a.auraInstanceID } }))
end
local function refresh(id, stacks)
  local a = G.auras[id]
  if not a then return end
  a.expirationTime = W.now + a.duration
  if stacks then a.applications = stacks end
  W.fire("UNIT_AURA", "player", payFor(id, { updatedAuraInstanceIDs = { a.auraInstanceID } }))
end
local function unrelated() W.fire("UNIT_AURA", "player", pay({ updatedAuraInstanceIDs = { 7777 } })) end
local function unrelatedAdd(id) local a = newAura(id, 10); W.fire("UNIT_AURA", "player", pay({ addedAuras = { a } })) end
-- in combat: a readable payload adding NeverSecret aura `id` and carrying one hidden entry (spell and instance secret)
local function mixed(id)
  local a = newAura(id, 8); G.auras[id] = a
  W.fire("UNIT_AURA", "player", { addedAuras = { a, { spellId = SEC(), auraInstanceID = SEC() } } })
end
local function debuff(unit, id, mine)
  G.nextIID = G.nextIID + 1
  local d = { spellId = id, auraInstanceID = G.nextIID, duration = 12, expirationTime = W.now + 12, applications = 1, mine = mine,
    sourceUnit = mine and "player" or "raid7" }
  table.insert(G[unit].debuffs, d)
  W.fire("UNIT_AURA", unit, pay({ addedAuras = { d } }))
  return d
end
local function undebuff(unit, d)
  for i, x in ipairs(G[unit].debuffs) do if x == d then table.remove(G[unit].debuffs, i); break end end
  W.fire("UNIT_AURA", unit, pay({ removedAuraInstanceIDs = { d.auraInstanceID } }))
end
local function cdEvent(...) W.fire("SPELL_UPDATE_COOLDOWN", ...) end
-- ---------------------------------------------------------------- the addons and the rules
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local SOUND = "Interface\\AddOns\\XayaUI\\Media\\Audio\\CC0\\Kenney\\bong_001.ogg"
local dyn = ns.NewFolder("Dynamic row"); dyn.cType = "dynamic"
local function mk(nm, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.trigger = "condition"; r.visual.text.enabled = true
  r.sound.enabled = false
  f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local function buff(nm, id, f) return mk(nm, function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, id, "present", "none"; r.visual.trigger = "buffActive"; if f then f(r) end end) end
local function cd(nm, id, f) return mk(nm, function(r) r.useCooldown, r.spellID, r.cdState, r.buffState = true, id, "ready", "none"; if f then f(r) end end) end
local function row(nm, t) return mk(nm, function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { t } } end) end
local function cue(p, kind)
  local c = ns.NewCueRule(p, kind)
  if kind == "sound" then c.sound.source, c.sound.value = "file", SOUND .. "?" .. p.name end
  if kind == "icon" or kind == "bar" then c.visual.w, c.visual.h = 32, 32 end
  return c
end
local R = {}
R.plain = buff("plain buff", 9001, function(r) r.visual.count = { enabled = true, source = "stacks" }; r.folder = dyn.id end)
cue(R.plain, "sound"); cue(R.plain, "icon"); cue(R.plain, "bar")
-- a condition on the plain buff (3 stacks or more) with an icon cue that only the condition switches on
do
  local gated = cue(R.plain, "icon")
  local c = ns.NewRule(); c.name = "three stacks"; c.parentUid = R.plain.uid; c.enabled = true; c.visual.enabled, c.sound.enabled = false, false
  c.when = { list = { { ref = "n:buffStacks", cmp = ">=", num = 3 } } }; c.thenCues = { gated.cueKey }
  ns.NormalizeRule(c); ns.rules[#ns.rules + 1] = c
end
R.extra = buff("extra IDs", 9002, function(r) r.buffAlt = { 9003 } end); cue(R.extra, "sound")
R.missing = mk("buff missing", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 9004, "missing", "none" end)
R.alias = buff("learned alias", 9010); cue(R.alias, "sound")
R.left = buff("seconds left", 9020, function(r) r.buffTimeOp, r.buffTimeSec = "<=", 5; r.visual.trigger = "condition" end); cue(R.left, "sound")
R.brow = row("buff row", { type = "buffAura", spellID = 9030, state = "yes" })
R.tgt = row("target debuff", { type = "targetDebuff", spellID = 9040, cdmID = 9041, unit = "target", state = "yes" }); cue(R.tgt, "sound")
R.foc = row("focus debuff", { type = "targetDebuff", spellID = 9050, unit = "focus", state = "yes" })
R.cdr = cd("cooldown ready", 9100, function(r) r.visual.desatOnCD = true end); cue(R.cdr, "sound")
R.cdrow = row("cooldown row", { type = "cooldown", spellID = 9101, state = "ready", maxCharges = 0 })
R.usable = row("usable row", { type = "actionUsable", spellID = 9102, state = "usable" })
R.icon = buff("icon in combat", 9060, function(r) r.folder = dyn.id end); cue(R.icon, "sound")
R.never = buff("never secret", 9070); cue(R.never, "sound"); cue(R.never, "icon")
R.never2 = buff("never secret 2", 9071)
R.shield = buff("shield", 9080, function(r) r.visual.absorb = { enabled = true, source = "total" } end)
R.name = buff("name match", 9090); cue(R.name, "sound")
R.charges = mk("charges", function(r) r.useCooldown, r.spellID, r.cdState, r.buffState = true, 9103, "hasCharge", "none"; r.visual.count = { enabled = true, source = "charges" } end)
R.cast = row("cast within", { type = "castSucceeded", spellID = 9105, window = 2, state = "yes" })
R.mounted = buff("not mounted", 9001, function(r) r.load.mounted = "no" end)
R.both = mk("buff and cooldown", function(r) r.useBuff, r.buffID, r.buffState, r.useCooldown, r.spellID, r.cdState = true, 9002, "present", true, 9100, "notReady" end)
-- the round-6 stuck icon: a buff display with a countdown, its icon, sound and bar cues
R.timed = buff("timed parent", 9200, function(r) r.folder = dyn.id end); cue(R.timed, "icon"); cue(R.timed, "sound"); cue(R.timed, "bar")
-- shared cooldown category (9300 and 9301), the global cooldown (9304 counts it), items sharing a cooldown (5555, 5556; spell 9401)
R.shA = cd("shared A", 9300); R.shB = cd("shared B", 9301); cue(R.shB, "sound")
R.gcdc = cd("counts the GCD", 9304, function(r) r.countGCD = true end)
R.gcdrow = row("GCD row", { type = "globalCooldown", state = "yes" })
R.item = row("item row", { type = "itemUsable", itemID = 5556, state = "ready" })
R.itemSpell = cd("item spell", 9401)
G.charges[9103] = { cur = 2, max = 2, start = 0 }
ns.MarkDirty()
W.tick(1 / 60, 30)
-- ---------------------------------------------------------------- what the player sees, every frame
local framesOf, containers = nil, nil
if ns.VisualProbeState then framesOf, containers = ns.VisualProbeState() end
local function txt(fs) if not fs then return "-" end; if fs.IsShown and not fs:IsShown() then return "hidden" end; local ok, t = pcall(fs.GetText, fs); return ok and tostring(t) or "?" end
local function rnd(x) if type(x) ~= "number" then return "-" end return tostring(math.floor(x + 0.5)) end
local function place(fr) local ok, l, b, w, h = pcall(fr.GetRect, fr); if not ok then return "?" end return rnd(l) .. "," .. rnd(b) .. "," .. rnd(w) .. "," .. rnd(h) end
local function bar(fr)
  local b = fr and fr.barF
  if not (b and b:IsShown()) then return "-" end
  local ok, v = pcall(b.GetValue, b)
  return (ok and type(v) == "number") and ("%.2f"):format(v) or "?"
end
local function snap(label)
  local rows = {}
  for i, r in ipairs(ns.rules) do
    local rt = ns.runtime[r]
    local fr = framesOf and framesOf[r]
    local shown = fr and fr:IsShown() and true or false
    local vis = fr and fr:IsVisible() and true or false
    local desat = fr and fr.tex and fr.tex.IsDesaturated and fr.tex:IsDesaturated() or false
    local owns = ns.EngineOwns and ns.EngineOwns(r) and true or false
    rows[i] = table.concat({ tostring(r.name), tostring(rt and rt.active or false), tostring(rt and rt.visualWanted or false), tostring(shown),
      shown and txt(fr.text) or "", shown and txt(fr.count) or "", shown and txt(fr.absorb) or "", tostring(desat and true or false),
      tostring(vis), shown and ("%.2f"):format(fr:GetAlpha() or 1) or "", shown and bar(fr) or "", shown and place(fr) or "", tostring(owns) }, "|")
  end
  local g = {}
  if type(containers) == "table" then   -- (keyed by the group's name: a group's id differs from run to run)
    for k, c in pairs(containers) do
      local nm = tostring(k)
      for _, fo in ipairs(ns.folders or {}) do if fo.id == k then nm = tostring(fo.name) end end
      if type(c) == "table" and c.IsShown then g[#g + 1] = nm .. "=" .. tostring(c:IsShown()) .. (c:IsShown() and ("@" .. place(c)) or "") end
    end
    table.sort(g)
  end
  OUT.frames[#OUT.frames + 1] = { label = label, rows = rows, groups = table.concat(g, ";"), sounds = table.concat(W.sounds, ","), now = W.now }
end
local frameN = 0
local function F(label, n) for _ = 1, (n or 1) do W.tick(1 / 60, 1); frameN = frameN + 1; snap(label .. " #" .. frameN) end end
local function Fine(label, n) for _ = 1, (n or 1) do W.tick(0.002, 1); frameN = frameN + 1; snap(label .. " #" .. frameN) end end
local function upTo(label, t) while W.now + 0.002 <= t do Fine(label, 1) end end
-- ---------------------------------------------------------------- the streams
F("settle", 5)
-- ===== out of combat, payloads readable
gain(9001, 20); F("gain watched", 8)
unrelated(); F("unrelated aura (updated, unknown instance)", 8)
unrelatedAdd(8888); F("unwatched aura added", 8)
refresh(9001); F("refresh (updated instance)", 8)
refresh(9001, 3); F("three stacks: the condition's cue", 8)
refresh(9001, 1); F("one stack: the condition's cue goes", 8)
gain(9003, 15); F("extra ID gained", 8)
lose(9003); F("extra ID lost (removed instance)", 8)
gain(9002, 15); F("main ID gained", 8)
gain(9010 + 1, 25); F("same-name aura (alias learned)", 10)
lose(9011); F("same-name aura lost", 8)
gain(9011, 25); F("same-name aura back (learned ID routed)", 8)
gain(9020, 7); F("seconds-left aura", 8)
for _ = 1, 110 do F("waiting for 5 s left", 1) end
gain(9030, 6); F("row aura", 8)
G.absorb = 500; gain(9080, 30); F("shield", 8)
G.absorb = 250; refresh(9080); F("shield hit", 8)
-- the shield absorbs damage: the game updates the aura (same duration) and the amount drops; only the drawn amount changes
G.absorb = 120; W.fire("UNIT_AURA", "player", pay({ updatedAuraInstanceIDs = { G.auras[9080].auraInstanceID } })); F("shield absorbs damage (same duration)", 8)
G.icons[9091].wasSetFromAura = true; unrelatedAdd(8889); F("name-matched icon lit, readable payload about another aura", 8)
G.icons[9091].wasSetFromAura = false; unrelatedAdd(8890); F("name-matched icon unlit", 8)
W.fire("UNIT_AURA", "player", { isFullUpdate = true }); F("full update, nothing changed", 8)
G.auras[9001] = nil; W.fire("UNIT_AURA", "player", { isFullUpdate = true }); F("full update, an aura gone", 8)
gain(9001, 20); F("gain watched again", 8)
-- ===== the timing edges (fine frames of 2 ms): the round-6 stuck icon, and its sound cue playing again
do
  local tg = W.now
  gain(9200, 10.5); Fine("timed parent gained", 10)
  upTo("timed parent counting", tg + 0.486)
  cdEvent(); Fine("a routed pass just before the parent's wake", 2)
  lose(9200); Fine("aura lost 10 ms before the parent's whole-second wake", 75)
  F("after the loss", 20)
  local t2 = W.now
  gain(9200, 10.5); Fine("timed parent regained (its sound cue again)", 10)
  upTo("timed parent counting", t2 + 0.994)
  refresh(9200); Fine("refreshed just after its whole-second wake", 40)
  F("after the refresh", 10)
  -- a seconds-left threshold crossed in the same frame as an aura event
  local t3 = W.now
  gain(9020, 5.6); Fine("seconds-left aura at 5.6 s", 5)
  upTo("seconds-left aura", t3 + 0.599)
  refresh(9001); Fine("threshold crossed with an aura event in the frame", 40)
  lose(9200); lose(9020); F("edges done", 10)
end
-- the target and focus
G.target.exists = true; W.fire("PLAYER_TARGET_CHANGED"); F("target", 8)
local d1 = debuff("target", 9040, true); F("your debuff on the target (readable)", 8)
for i = 1, 40 do local o = debuff("target", 6000 + i, false); if i % 3 == 0 then undebuff("target", o) end; F("raid storm", 1) end
undebuff("target", d1); F("your debuff gone", 8)
G.focus.exists = true; W.fire("PLAYER_FOCUS_CHANGED"); F("focus", 8)
local d2 = debuff("focus", 9050, true); F("focus debuff", 8)
undebuff("focus", d2); F("focus debuff gone", 8)
G.target.exists = false; G.target.debuffs = {}; W.fire("PLAYER_TARGET_CHANGED"); F("target dropped", 8)
-- ===== cooldowns, charges, usability, items, casts
G.cds[9100] = { start = W.now, dur = 2 }; cdEvent(9100, 9100); F("cooldown started (spell ID only)", 8)
for _ = 1, 125 do F("cooldown running out", 1) end
G.cds[9101] = { start = W.now, dur = 1 }; cdEvent(); W.fire("ACTIONBAR_UPDATE_COOLDOWN"); F("row cooldown (no spell ID)", 8)
for _ = 1, 60 do F("row cooldown running out", 1) end
-- a shared category: one event names spell 9300; 9301 shares its cooldown
G.cds[9300] = { start = W.now, dur = 1.5 }; G.cds[9301] = { start = W.now, dur = 1.5 }; cdEvent(9300, 9300, 77, 0, nil); F("shared category", 8)
for _ = 1, 90 do F("shared cooldown running out", 1) end
-- the global cooldown: a cast of 9306 starts it (start-recovery category 133)
G.gcd = { start = W.now, dur = 1.5 }; cdEvent(9306, 9306, 0, 133, nil); F("global cooldown started", 8)
for _ = 1, 90 do F("global cooldown running out", 1) end
-- an item: using item 5555 (its spell 9400) puts item 5556 and spell 9401 on the same cooldown
G.items[5555].cd = { start = W.now, dur = 1.2 }; G.items[5556].cd = { start = W.now, dur = 1.2 }; G.cds[9401] = { start = W.now, dur = 1.2 }
cdEvent(9400, 9400, 0, 0, 5555); F("item used (item ID)", 8)
for _ = 1, 80 do F("item cooldown running out", 1) end
G.items[5556].cd = { start = W.now, dur = 1 }; W.fire("BAG_UPDATE_COOLDOWN"); F("bag cooldown", 8)
for _ = 1, 70 do F("bag cooldown running out", 1) end
-- usability changed with a spell-ID cooldown event (the usable row is read on every cooldown event)
G.usable[9102] = false; cdEvent(9100, 9100); F("not usable, with a spell-ID cooldown event", 8)
G.usable[9102] = true; W.fire("SPELL_UPDATE_USABLE"); F("usable", 8)
-- a cooldown that changed with no cooldown event, then your cast (a cast re-reads the cooldowns)
G.cds[9101] = { start = W.now, dur = 1 }; W.tick(0.12, 1)
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-9101-0000", 9101); F("a cast after a silent cooldown start", 8)
for _ = 1, 60 do F("row cooldown running out", 1) end
-- charges
G.charges[9103].cur = 1; G.charges[9103].start = W.now; W.fire("SPELL_UPDATE_CHARGES"); F("charge spent", 8)
G.charges[9103].cur = 0; W.fire("SPELL_UPDATE_CHARGES"); cdEvent(9103); F("no charge", 8)
G.charges[9103].cur = 2; W.fire("SPELL_UPDATE_CHARGES"); F("charges back", 8)
-- a cooldown ending on a routed pass
G.cds[9100] = { start = W.now, dur = 0.5 }; cdEvent(9100, 9100); F("short cooldown", 2)
for _ = 1, 26 do cdEvent(); F("cooldown events every frame around its end", 1) end
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-9105-0000", 9105); F("cast", 8)
for _ = 1, 120 do F("cast window closing", 1) end
-- a load condition
IsMounted = function() return true end; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); F("mounted", 8)
IsMounted = function() return false end; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); F("dismounted", 8)
-- ===== combat
W.enterCombat(); F("combat starts", 8)
for _ = 1, 20 do unrelated(); F("secret storm, nothing changed", 1) end
G.icons[9060].wasSetFromAura = true; G.auras[9060] = { spellId = 9060, auraInstanceID = 501, name = name(9060), applications = 1, duration = 10, expirationTime = W.now + 10 }
unrelated(); F("proc: icon lit (secret payload)", 8)
for _ = 1, 10 do unrelated(); F("secret storm", 1) end
G.icons[9060].wasSetFromAura = false; G.auras[9060] = nil; unrelated(); F("proc gone", 8)
gain(9070, 8); F("NeverSecret aura gained (readable payload)", 8)
refresh(9070); F("NeverSecret aura refreshed (readable payload)", 8)
lose(9070); F("NeverSecret aura lost (readable payload)", 8)
-- a Cooldown Manager icon lit while the only payload is a readable one about a NeverSecret aura
G.icons[9060].wasSetFromAura = true; G.auras[9060] = { spellId = 9060, auraInstanceID = 502, name = name(9060), applications = 1, duration = 10, expirationTime = W.now + 10 }
gain(9071, 6); F("icon lit with a readable NeverSecret payload", 8)
G.icons[9060].wasSetFromAura = false; G.auras[9060] = nil; lose(9071); F("icon unlit with a readable NeverSecret payload", 8)
mixed(9070); F("readable payload with a hidden entry", 8)
lose(9070); F("NeverSecret aura lost again", 8)
G.icons[9091].wasSetFromAura = true; unrelated(); F("name-matched icon lit", 8)
G.icons[9091].wasSetFromAura = false; unrelated(); F("name-matched icon unlit", 8)
G.target.exists = true; W.fire("PLAYER_TARGET_CHANGED"); F("target in combat", 8)
G.target.hidden = true; G.icons[9041].wasSetFromAura = true; W.fire("UNIT_AURA", "target", pay({})); F("hidden debuff, icon lit", 8)
for _ = 1, 15 do W.fire("UNIT_AURA", "target", pay({})); F("boss storm (secret)", 1) end
G.icons[9041].wasSetFromAura = false; W.fire("UNIT_AURA", "target", pay({})); F("icon unlit", 8)
gain(9002, 15); F("buff in combat (hidden)", 8)
-- an icon lit with no aura event at all, then your cast (a cast re-reads the checks that do not answer from the aura API)
G.icons[9060].wasSetFromAura = true; G.auras[9060] = { spellId = 9060, auraInstanceID = 503, name = name(9060), applications = 1, duration = 10, expirationTime = W.now + 10 }
W.tick(0.12, 1)
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-9105-0000", 9105); F("cast in combat after a silent icon change", 8)
G.icons[9060].wasSetFromAura = false; G.auras[9060] = nil; unrelated(); F("icon unlit", 8)
G.cds[9100] = { start = W.now, dur = 1 }; cdEvent(); F("cooldown in combat", 8)
for _ = 1, 60 do F("cooldown in combat running out", 1) end
W.leaveCombat(); F("combat ends", 8)
gain(9001, 20); F("after combat", 8)
OUT.errors = {}
for i = 1, #W.errors do OUT.errors[i] = tostring(W.errors[i]) end
return OUT
end
'''

TEXT, BAR = 4, 10   # the duration text's and the bar fill's places in a row
WINDOW = 0.1 + FRAME + 0.003   # one pace window and the frame that crosses it (rounding allowed)


def RedrawOnly(a, b):
    """Allowance a: True when two rows differ only in a duration text shown in tenths (by one tenth) and / or a bar's fill (by one
    hundredth). Every other field, and whole seconds, must match exactly."""
    pa, pb = a.split("|"), b.split("|")
    if len(pa) != len(pb) or pa == pb:
        return False
    for k in range(len(pa)):
        if pa[k] == pb[k]:
            continue
        try:
            x, y = float(pa[k]), float(pb[k])
        except ValueError:
            return False
        if k == TEXT and "." in pa[k] and "." in pb[k] and abs(x - y) <= 0.1001:
            continue
        if k == BAR and abs(x - y) <= 0.0101:
            continue
        return False
    return True


def Same(a, b):
    return a == b or (a is not None and b is not None and RedrawOnly(a, b))


def base(label):
    return re.sub(r" #\d+$", "", label or "")


def run_with(folders):
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    return H.lua_to_py(res)


def git_show(path):
    """The pre-round-6 file, from this tree's git history, or from XUI_REPLAY_GIT's."""
    for repo in [H.ROOT, os.environ.get("XUI_REPLAY_GIT")]:
        if not repo:
            continue
        r = subprocess.run(["git", "-C", repo, "show", "%s:%s" % (BASE, path)], capture_output=True)
        if r.returncode == 0:
            return r.stdout
    return None


PACE_LINES = (r"^local ROUTED_GAP = .*$", r"^local ROUTED_DUE = .*$")


def with_pace(old_src, new_src):
    """The old engine with its two pace lines replaced by the engine under test's (the routed pace; nothing else changes)."""
    out = old_src
    for pat in PACE_LINES:
        m_new = re.search(pat, new_src, re.M)
        if not (m_new and re.search(pat, out, re.M)):
            return None
        out = re.sub(pat, lambda _m, s=m_new.group(0): s, out, count=1, flags=re.M)
    return out


def main():
    folders = {k: v for k, v in H.find_addons().items() if k != "XayaUI_DevAssist"}
    tmp = tempfile.mkdtemp(prefix="xui_replay_")
    fails = 0
    try:
        olds = {}
        for f in OLD_FILES:
            src = git_show("XayaUI_Rules/%s" % f)
            if src is None:
                print("FAIL: cannot read XayaUI_Rules/%s at %s from git (set XUI_REPLAY_GIT to a clone of the repository)" % (f, BASE))
                print("FAILS: 1")
                sys.exit(1)
            olds[f] = src
        new_engine = open(os.path.join(folders["XayaUI_Rules"], "Engine.lua"), encoding="utf-8").read()
        paced = with_pace(olds["Engine.lua"].decode("utf-8"), new_engine)
        if paced is None:
            print("FAIL: the routed pace lines (ROUTED_GAP / ROUTED_DUE) were not found in the engine under test or the old one")
            print("FAILS: 1")
            sys.exit(1)
        trees = {}
        for kind in ("same", "native"):
            d = os.path.join(tmp, kind, "XayaUI_Rules")
            shutil.copytree(folders["XayaUI_Rules"], d)
            for f in OLD_FILES:
                data = olds[f]
                if f == "Engine.lua" and kind == "same":
                    data = paced.encode("utf-8")
                with open(os.path.join(d, f), "wb") as fh:
                    fh.write(data)
            trees[kind] = d
        old_same = run_with(dict(folders, XayaUI_Rules=trees["same"]))
        old_native = run_with(dict(folders, XayaUI_Rules=trees["native"]))
        now = run_with(folders)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    fa, fb, fn = old_same.get("frames") or [], now.get("frames") or [], old_native.get("frames") or []
    m = re.search(PACE_LINES[0], new_engine, re.M)
    print("    (the routed pace of the engine under test, given to the old engine for the strict comparison: %s)" % (m.group(0) if m else "?"))
    if len(fa) != len(fb) or len(fn) != len(fb) or not fa:
        print("FAIL: the runs played a different number of frames (%d, %d, %d)" % (len(fa), len(fn), len(fb)))
        fails += 1
    # 1. STRICT, frame by frame (allowances a and b), and exactly at the end of every part of the streams
    diffs, redraw, earlier, rules_n = [], 0, 0, 0
    nf = min(len(fa), len(fb))

    def ahead(k, get, val):
        """Allowance b: the old engine shows `val` at a frame after k, within one pace window."""
        t = fb[k].get("now") or 0
        j = k + 1
        while j < nf and (fa[j].get("now") or 0) - t <= WINDOW + 1e-9:
            if Same(get(fa[j]), val):
                return True
            j += 1
        return False

    for k in range(nf):
        x, y = fa[k], fb[k]
        last = k + 1 >= nf or base(fa[k + 1].get("label")) != base(x.get("label"))
        rx, ry = x.get("rows") or [], y.get("rows") or []
        rules_n = max(rules_n, len(rx))
        for i in range(max(len(rx), len(ry))):
            a_, b_ = (rx[i] if i < len(rx) else None), (ry[i] if i < len(ry) else None)
            if a_ == b_:
                continue
            if Same(a_, b_):
                redraw += 1
                continue
            if not last and b_ is not None and ahead(k, lambda f, i=i: (f.get("rows") or [None] * (i + 1))[i], b_):
                earlier += 1
                continue
            diffs.append("%s%s: rule %d\n      before: %s\n      now:    %s" % (x.get("label"), " (end of the part)" if last else "", i + 1, a_, b_))
        for key, what in (("groups", "group frames"), ("sounds", "sounds")):
            if x.get(key) == y.get(key):
                continue
            if not last and ahead(k, lambda f, key=key: f.get(key), y.get(key)):
                earlier += 1
                continue
            diffs.append("%s%s: %s\n      before: %s\n      now:    %s" % (x.get("label"), " (end of the part)" if last else "", what, x.get(key), y.get(key)))
    for d in diffs[:int(os.environ.get("XUI_REPLAY_SHOW", "12"))]:
        print("DIFF " + d)
    ok = not diffs
    print(("ok  " if ok else "FAIL: ") + "STRICT: every rule answers and is drawn the same at every frame as in the engine before round 6 at the same "
          "pace (%d frames x %d rules: active, display wanted, shown, visible, duration / count / shield text, grey, opacity, bar fill, place, "
          "drawn by; group frames; every sound in order), and exactly the same at the end of every part of the streams%s"
          % (nf, rules_n, "" if ok else " [%d differences]" % len(diffs)))
    fails += 0 if ok else 1
    print("    (allowance a, REDRAW, visible difference she was told of in round 6: a tenths text by one tenth or a bar fill by one hundredth "
          "for a frame: %d rule-frames)" % redraw)
    print("    (allowance b, EARLIER: already showing what the engine before round 6 showed within the next tenth of a second and one frame: "
          "%d rule-frames)" % earlier)
    # 2. PACE BOUND, against the old engine at its own pace
    lag = WINDOW
    late, worst = [], 0.0
    for k, y in enumerate(fb):
        t = y.get("now") or 0
        ry = y.get("rows") or []
        for i, b_ in enumerate(ry):
            hit = None
            j = k
            while j >= 0 and (t - (fn[j].get("now") or 0)) <= lag + 1e-9:
                rx = fn[j].get("rows") or []
                a_ = rx[i] if i < len(rx) else None
                if Same(a_, b_):
                    hit = t - (fn[j].get("now") or 0)
                    break
                j -= 1
            if hit is None:
                late.append("%s: rule %d drawn as\n      now:    %s\n      the old engine at its own pace never drew that in the %.0f ms before (it drew: %s)"
                            % (y.get("label"), i + 1, b_, lag * 1000, (fn[k].get("rows") or [None] * (i + 1))[i]))
            elif hit > worst:
                worst = hit
    for d in late[:int(os.environ.get("XUI_REPLAY_SHOW", "12"))]:
        print("LATE " + d)
    ok = not late
    print(("ok  " if ok else "FAIL: ") + "PACE BOUND: against the engine before round 6 at its own pace (1/30 s), every row drawn now is one it drew "
          "within the last tenth of a second and one frame%s" % ("" if ok else " [%d rows]" % len(late)))
    fails += 0 if ok else 1
    print("    (the most any row was behind the old engine's: %.0f ms)" % (worst * 1000))
    sa = sorted((fn[-1].get("sounds") or "").split(",")) if fn else []
    sb = sorted((fb[-1].get("sounds") or "").split(",")) if fb else []
    ok = sa == sb
    print(("ok  " if ok else "FAIL: ") + "PACE BOUND: the same sounds play as with the engine before round 6 at its own pace (%d sounds)%s"
          % (len(sb), "" if ok else " [before %d, now %d]" % (len(sa), len(sb))))
    fails += 0 if ok else 1
    # the streams must have exercised the rules: each rule was active at some frame, and shown at some frame when it has a display
    seen, drawn = set(), set()
    for x in fb:
        for i, row in enumerate(x.get("rows") or []):
            p = row.split("|")
            if p[1] == "true":
                seen.add(i)
            if p[3] == "true":
                drawn.add(i)
    never = [fb[0]["rows"][i].split("|")[0] for i in range(rules_n) if i not in seen] if fb else []
    ok2 = not never
    print(("ok  " if ok2 else "FAIL: ") + "every rule turned on at least once in the streams%s" % ("" if ok2 else " [never: %s]" % ", ".join(never)))
    fails += 0 if ok2 else 1
    print("    (rules drawn on screen at some frame: %d of %d)" % (len(drawn), rules_n))
    for side, r in (("before, same pace", old_same), ("before, own pace", old_native), ("now", now)):
        for e in (r.get("errors") or []):
            print("ERROR (%s) in the game stand-in: %s" % (side, str(e)[:500]))
            fails += 1
    print("FAILS: %d" % fails)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
