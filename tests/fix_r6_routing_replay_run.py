#!/usr/bin/env python3
"""Offline test (round 6, REQUEST-LOG A23 SD-54: the engine's aura and cooldown checks). Proves that no rule answers differently.

The same recorded event streams are played, frame by frame, into two copies of the stand-in game: one with the engine as it was before
round 6 (XayaUI_Rules/Engine.lua, Conditions.lua, AuraAlias.lua, Visual.lua, BarCue.lua, Outcomes.lua, Triggers.lua at commit 89ea79ab,
the round-5 save), and one with the files as they are now. Everything else is the same tree. After every frame, every rule's answer is
compared: whether it is active (its trigger holds), whether XayaUI wants its display shown, whether the display is on screen, the
display's duration text, its count and shield texts, whether it is greyed, and every sound played so far, in order. One allowance, counted
and printed: a duration text shown in tenths of a second may differ by one tenth for a frame (the display redraws its tenths itself,
about 30 times a second, Visual.lua FxOnUpdate; the old engine also redrew them whenever an aura event re-checked every aura rule).

The streams cover, out of combat (payloads readable) and in combat (every UNIT_AURA payload secret): auras gained, lost, refreshed
and stacked; auras no rule watches; extra aura IDs (any one counts); a same-name aura learned in game (AuraAlias.lua); a "seconds left"
threshold crossing; full updates (one with nothing changed, one with an aura gone); a Cooldown Manager icon lit and unlit in combat;
a NeverSecret aura in combat; an aura matched by its Tracked Buffs icon's name; your debuffs on the target (added, a raid storm of
other players' updates, removed, hidden in combat with the Cooldown Manager icon) and on the focus; target and focus changes;
cooldowns started (SPELL_UPDATE_COOLDOWN with and without a spell ID) and ended; charges spent and regained; a spell becoming
usable; your casts ("cast within N seconds"); a shield amount; mounting (a load condition).
Run: python3 tests/fix_r6_routing_replay_run.py   (Lua 5.1 via lupa; needs git, to read the pre-round-6 files)."""
import os, shutil, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

BASE = "89ea79ab"   # the round-5 save: the engine before round 6
OLD_FILES = ["Engine.lua", "Conditions.lua", "AuraAlias.lua", "Visual.lua", "BarCue.lua", "Outcomes.lua", "Triggers.lua"]

LUA = r'''
return function(W, L)
local OUT = { frames = {}, errors = {} }
-- ---------------------------------------------------------------- the game model (identical in both copies)
Enum.SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
local G = { auras = {}, nextIID = 100, never = { [9070] = true }, names = {}, cds = {}, charges = {}, usable = {}, absorb = 0,
  target = { exists = false, debuffs = {}, hidden = false }, focus = { exists = false, debuffs = {} }, icons = {} }
G.names[9010], G.names[9011] = "Shield Wall", "Shield Wall"
G.names[9090], G.names[9091] = "Hidden Fury", "Hidden Fury"
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
C_Spell.GetSpellCooldown = function(id)
  local c = G.cds[id]
  if c and W.now < c.start + c.dur then return { startTime = c.start, duration = c.dur, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 } end
  return { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
end
C_Spell.GetSpellCharges = function(id)
  local c = G.charges[id]
  if not c then return nil end
  return { currentCharges = c.cur, maxCharges = c.max, isActive = c.cur < c.max, cooldownStartTime = c.cur < c.max and c.start or 0,
    cooldownDuration = c.cur < c.max and 20 or 0, chargeModRate = 1 }
end
C_Spell.IsSpellUsable = function(id) local u = G.usable[id]; if u == nil then return true, false end; return u, not u end
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
local function pay(t) if W.combat then return W.MarkSecret(t) end return t end
local function gain(id, dur, stacks)
  local old = G.auras[id]
  G.nextIID = G.nextIID + 1
  local a = { spellId = id, auraInstanceID = G.nextIID, name = name(id), icon = 136243, applications = stacks or 1, duration = dur or 30,
    expirationTime = W.now + (dur or 30), isHelpful = true, sourceUnit = "player", isFromPlayerOrPlayerPet = true }
  G.auras[id] = a
  W.fire("UNIT_AURA", "player", pay({ addedAuras = { a }, removedAuraInstanceIDs = old and { old.auraInstanceID } or nil }))
  return a
end
local function lose(id)
  local a = G.auras[id]
  if not a then return end
  G.auras[id] = nil
  W.fire("UNIT_AURA", "player", pay({ removedAuraInstanceIDs = { a.auraInstanceID } }))
end
local function refresh(id, stacks)
  local a = G.auras[id]
  if not a then return end
  a.expirationTime = W.now + a.duration
  if stacks then a.applications = stacks end
  W.fire("UNIT_AURA", "player", pay({ updatedAuraInstanceIDs = { a.auraInstanceID } }))
end
local function unrelated() W.fire("UNIT_AURA", "player", pay({ updatedAuraInstanceIDs = { 7777 } })) end
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
-- ---------------------------------------------------------------- the addons and the rules
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local SOUND = "Interface\\AddOns\\XayaUI\\Media\\Audio\\CC0\\Kenney\\bong_001.ogg"
local function mk(nm, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.trigger = "condition"; r.visual.text.enabled = true
  r.sound.enabled = false
  f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local function buff(nm, id, f) return mk(nm, function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, id, "present", "none"; r.visual.trigger = "buffActive"; if f then f(r) end end) end
local function cue(p, kind) local c = ns.NewCueRule(p, kind); if kind == "sound" then c.sound.source, c.sound.value = "file", SOUND .. "?" .. p.name end; return c end
local R = {}
R[#R + 1] = buff("plain buff", 9001, function(r) r.visual.count = { enabled = true, source = "stacks" } end)
cue(R[1], "sound"); cue(R[1], "icon")
R[#R + 1] = buff("extra IDs", 9002, function(r) r.buffAlt = { 9003 } end); cue(R[2], "sound")
R[#R + 1] = mk("buff missing", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 9004, "missing", "none" end)
R[#R + 1] = buff("learned alias", 9010); cue(R[4], "sound")
R[#R + 1] = buff("seconds left", 9020, function(r) r.buffTimeOp, r.buffTimeSec = "<=", 5; r.visual.trigger = "condition" end); cue(R[5], "sound")
R[#R + 1] = mk("buff row", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "buffAura", spellID = 9030, state = "yes" } } } end)
R[#R + 1] = mk("target debuff", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "targetDebuff", spellID = 9040, cdmID = 9041, unit = "target", state = "yes" } } } end)
cue(R[7], "sound")
R[#R + 1] = mk("focus debuff", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "targetDebuff", spellID = 9050, unit = "focus", state = "yes" } } } end)
R[#R + 1] = mk("cooldown ready", function(r) r.useCooldown, r.spellID, r.cdState, r.buffState = true, 9100, "ready", "none"; r.visual.desatOnCD = true end)
cue(R[9], "sound")
R[#R + 1] = mk("cooldown row", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "cooldown", spellID = 9101, state = "ready", maxCharges = 0 } } } end)
R[#R + 1] = mk("usable row", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "actionUsable", spellID = 9102, state = "usable" } } } end)
R[#R + 1] = buff("icon in combat", 9060); cue(R[12], "sound")
R[#R + 1] = buff("never secret", 9070); cue(R[13], "sound")
R[#R + 1] = buff("shield", 9080, function(r) r.visual.absorb = { enabled = true, source = "total" } end)
R[#R + 1] = buff("name match", 9090); cue(R[15], "sound")
R[#R + 1] = mk("charges", function(r) r.useCooldown, r.spellID, r.cdState, r.buffState = true, 9103, "hasCharge", "none"; r.visual.count = { enabled = true, source = "charges" } end)
R[#R + 1] = mk("cast within", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "castSucceeded", spellID = 9105, window = 2, state = "yes" } } } end)
R[#R + 1] = buff("not mounted", 9001, function(r) r.load.mounted = "no" end)
R[#R + 1] = mk("buff and cooldown", function(r) r.useBuff, r.buffID, r.buffState, r.useCooldown, r.spellID, r.cdState = true, 9002, "present", true, 9100, "notReady" end)
G.charges[9103] = { cur = 2, max = 2, start = 0 }
ns.MarkDirty()
W.tick(1 / 60, 30)
-- ---------------------------------------------------------------- what the player sees, every frame
local _, framesOf = nil, nil
if ns.VisualProbeState then framesOf = ns.VisualProbeState() end
local function txt(fs) if not fs then return "-" end; if fs.IsShown and not fs:IsShown() then return "hidden" end; local ok, t = pcall(fs.GetText, fs); return ok and tostring(t) or "?" end
local function snap(label)
  local rows = {}
  for i, r in ipairs(ns.rules) do
    local rt = ns.runtime[r]
    local fr = framesOf and framesOf[r]
    local shown = fr and fr:IsShown() and true or false
    local desat = fr and fr.tex and fr.tex.IsDesaturated and fr.tex:IsDesaturated() or false
    rows[i] = table.concat({ tostring(r.name), tostring(rt and rt.active or false), tostring(rt and rt.visualWanted or false), tostring(shown),
      shown and txt(fr.text) or "", shown and txt(fr.count) or "", shown and txt(fr.absorb) or "", tostring(desat and true or false) }, "|")
  end
  OUT.frames[#OUT.frames + 1] = { label = label, rows = rows, sounds = table.concat(W.sounds, ","), now = W.now }
end
local frameN = 0
local function F(label, n) for _ = 1, (n or 1) do W.tick(1 / 60, 1); frameN = frameN + 1; snap(label .. " #" .. frameN) end end
-- ---------------------------------------------------------------- the streams
F("settle", 5)
-- out of combat, payloads readable
gain(9001, 20); F("gain watched", 2)
unrelated(); F("unrelated aura", 2)
gain(8888, 10); F("unwatched aura added", 2)
refresh(9001); F("refresh", 2)
refresh(9001, 3); F("stacks", 2)
gain(9003, 15); F("extra ID gained", 2)
lose(9003); F("extra ID lost", 2)
gain(9002, 15); F("main ID gained", 2)
gain(9010 + 1, 25); F("same-name aura (alias learned)", 3)
gain(9020, 7); F("seconds-left aura", 3)
for _ = 1, 160 do F("waiting for 5 s left", 1) end
gain(9030, 6); F("row aura", 2)
G.absorb = 500; gain(9080, 30); F("shield", 2)
G.absorb = 250; refresh(9080); F("shield hit", 2)
W.fire("UNIT_AURA", "player", { isFullUpdate = true }); F("full update, nothing changed", 2)
G.auras[9001] = nil; W.fire("UNIT_AURA", "player", { isFullUpdate = true }); F("full update, an aura gone", 2)
-- the target and focus
G.target.exists = true; W.fire("PLAYER_TARGET_CHANGED"); F("target", 3)
local d1 = debuff("target", 9040, true); F("your debuff on the target", 2)
for i = 1, 40 do local o = debuff("target", 6000 + i, false); if i % 3 == 0 then undebuff("target", o) end; F("raid storm", 1) end
undebuff("target", d1); F("your debuff gone", 2)
G.focus.exists = true; W.fire("PLAYER_FOCUS_CHANGED"); F("focus", 2)
local d2 = debuff("focus", 9050, true); F("focus debuff", 2)
G.target.exists = false; G.target.debuffs = {}; W.fire("PLAYER_TARGET_CHANGED"); F("target dropped", 2)
-- cooldowns, charges, usability, casts
G.cds[9100] = { start = W.now, dur = 2 }; W.fire("SPELL_UPDATE_COOLDOWN", 9100, 9100); F("cooldown started (spell ID)", 3)
for _ = 1, 140 do F("cooldown running out", 1) end
G.cds[9101] = { start = W.now, dur = 1 }; W.fire("SPELL_UPDATE_COOLDOWN"); W.fire("ACTIONBAR_UPDATE_COOLDOWN"); F("row cooldown (no spell ID)", 3)
for _ = 1, 70 do F("row cooldown running out", 1) end
G.usable[9102] = false; W.fire("SPELL_UPDATE_USABLE"); F("not usable", 2)
G.usable[9102] = true; W.fire("SPELL_UPDATE_USABLE"); F("usable", 2)
G.charges[9103].cur = 1; G.charges[9103].start = W.now; W.fire("SPELL_UPDATE_CHARGES"); F("charge spent", 2)
G.charges[9103].cur = 0; W.fire("SPELL_UPDATE_CHARGES"); W.fire("SPELL_UPDATE_COOLDOWN", 9103); F("no charge", 2)
G.charges[9103].cur = 2; W.fire("SPELL_UPDATE_CHARGES"); F("charges back", 2)
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-9105-0000", 9105); F("cast", 3)
for _ = 1, 130 do F("cast window closing", 1) end
-- a load condition
IsMounted = function() return true end; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); F("mounted", 3)
IsMounted = function() return false end; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); F("dismounted", 3)
-- combat: every UNIT_AURA payload secret
W.enterCombat(); F("combat starts", 3)
for _ = 1, 20 do unrelated(); F("secret storm, nothing changed", 1) end
G.icons[9060].wasSetFromAura = true; G.auras[9060] = { spellId = 9060, auraInstanceID = 501, name = name(9060), applications = 1, duration = 10, expirationTime = W.now + 10 }
unrelated(); F("proc: icon lit (secret payload)", 3)
for _ = 1, 10 do unrelated(); F("secret storm", 1) end
G.icons[9060].wasSetFromAura = false; G.auras[9060] = nil; unrelated(); F("proc gone", 3)
gain(9070, 8); F("NeverSecret aura gained", 2)
lose(9070); F("NeverSecret aura lost", 2)
G.icons[9091].wasSetFromAura = true; unrelated(); F("name-matched icon lit", 3)
G.icons[9091].wasSetFromAura = false; unrelated(); F("name-matched icon unlit", 3)
G.target.exists = true; W.fire("PLAYER_TARGET_CHANGED"); F("target in combat", 2)
G.target.hidden = true; G.icons[9041].wasSetFromAura = true; W.fire("UNIT_AURA", "target", pay({})); F("hidden debuff, icon lit", 3)
for _ = 1, 15 do W.fire("UNIT_AURA", "target", pay({})); F("boss storm (secret)", 1) end
G.icons[9041].wasSetFromAura = false; W.fire("UNIT_AURA", "target", pay({})); F("icon unlit", 3)
gain(9002, 15); F("buff in combat (hidden)", 2)
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-9105-0000", 9105); F("cast in combat", 2)
G.cds[9100] = { start = W.now, dur = 1 }; W.fire("SPELL_UPDATE_COOLDOWN"); F("cooldown in combat", 3)
for _ = 1, 70 do F("cooldown in combat running out", 1) end
W.leaveCombat(); F("combat ends", 5)
gain(9001, 20); F("after combat", 3)
OUT.errors = {}
for i = 1, #W.errors do OUT.errors[i] = tostring(W.errors[i]) end
return OUT
end
'''


def TenthsOnly(a, b):
    """True when two rows differ only in a duration text shown in tenths, by one tenth: the display's own redraw of tenths (Visual.lua
    FxOnUpdate, about 30 times a second) instead of an incidental redraw by the old engine's re-check of every aura rule on every aura
    event. Every other field (and whole seconds) must match exactly."""
    pa, pb = a.split("|"), b.split("|")
    if len(pa) != len(pb):
        return False
    for k in range(len(pa)):
        if pa[k] != pb[k] and k != 4:
            return False
    try:
        ta, tb = float(pa[4]), float(pb[4])
    except ValueError:
        return False
    return "." in pa[4] and "." in pb[4] and abs(ta - tb) <= 0.1001


def run_with(folders):
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    return H.lua_to_py(res)


def main():
    folders = {k: v for k, v in H.find_addons().items() if k != "XayaUI_DevAssist"}
    tmp = tempfile.mkdtemp(prefix="xui_replay_")
    try:
        old = os.path.join(tmp, "XayaUI_Rules")
        shutil.copytree(folders["XayaUI_Rules"], old)
        for f in OLD_FILES:
            src = subprocess.run(["git", "-C", H.ROOT, "show", "%s:XayaUI_Rules/%s" % (BASE, f)], capture_output=True)
            if src.returncode != 0:
                print("FAIL: cannot read %s at %s from git: %s" % (f, BASE, src.stderr.decode()[:200]))
                print("FAILS: 1")
                sys.exit(1)
            with open(os.path.join(old, f), "wb") as fh:
                fh.write(src.stdout)
        a = run_with(dict(folders, XayaUI_Rules=old))
        b = run_with(folders)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    fa, fb = a.get("frames") or [], b.get("frames") or []
    fails = 0
    if len(fa) != len(fb) or not fa:
        print("FAIL: the two runs played a different number of frames (%d, %d)" % (len(fa), len(fb)))
        fails += 1
    diffs = []
    tenths = 0
    rules_n = 0
    for x, y in zip(fa, fb):
        rx, ry = x.get("rows") or [], y.get("rows") or []
        rules_n = max(rules_n, len(rx))
        for i in range(max(len(rx), len(ry))):
            a_, b_ = (rx[i] if i < len(rx) else None), (ry[i] if i < len(ry) else None)
            if a_ != b_ and a_ and b_ and TenthsOnly(a_, b_):
                tenths += 1
                continue
            if a_ != b_:
                diffs.append("%s: rule %d\n      before: %s\n      now:    %s" % (x.get("label"), i + 1, a_, b_))
        if x.get("sounds") != y.get("sounds"):
            diffs.append("%s: sounds\n      before: %s\n      now:    %s" % (x.get("label"), x.get("sounds"), y.get("sounds")))
    for d in diffs[:int(os.environ.get("XUI_REPLAY_SHOW", "25"))]:
        print("DIFF " + d)
    ok = not diffs
    print(("ok  " if ok else "FAIL: ") + "every rule answers the same at every frame (%d frames x %d rules: active, display wanted, on screen, "
          "duration / count / shield text, grey; and every sound in order)%s" % (len(fa), rules_n, "" if ok else " [%d differences]" % len(diffs)))
    fails += 0 if ok else 1
    print("    (duration texts in tenths that differed by one tenth for a frame: %d; the display redraws tenths itself, about 30 times a "
          "second; the old engine also redrew them whenever an aura event re-checked every aura rule)" % tenths)
    # the stream must have exercised the rules: each rule was active at some frame in the run (else the comparison proves little)
    seen = set()
    for x in fb:
        for i, row in enumerate(x.get("rows") or []):
            if row.split("|")[1] == "true":
                seen.add(i)
    never = [fb[0]["rows"][i].split("|")[0] for i in range(rules_n) if i not in seen] if fb else []
    ok2 = not never
    print(("ok  " if ok2 else "FAIL: ") + "every rule turned on at least once in the streams%s" % ("" if ok2 else " [never: %s]" % ", ".join(never)))
    fails += 0 if ok2 else 1
    for side, r in (("before", a), ("now", b)):
        for e in (r.get("errors") or []):
            print("ERROR (%s) in the game stand-in: %s" % (side, str(e)[:500]))
            fails += 1
    print("FAILS: %d" % fails)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
