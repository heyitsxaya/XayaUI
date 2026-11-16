#!/usr/bin/env python3
"""Offline test (round 10; the round 9 engine reviewer's test gaps on REQUEST-LOG A23 SD-77, her answer "Route + narrow (Recommended)").

Round 9 made a load fact changing (combat, a boss pull, mounting, joining a group, the zone, gear, talents ...) re-check only the rules it
concerns (XayaUI_Rules/Engine.lua NW.Try, Conditions.lua ns.LoadReads). Whatever else waited for that same frame joins that one pass, as it
joined the full re-check before. The round 9 review found four parts of that joining, and four of the load facts, that no test held: each
could be broken and every test still passed. This test plays each in the whole-addon stand-in and checks what the player sees.

  M1. every-live-rule work waiting in the same frame (a new target, a lost target): mounting and losing your target in the same frame.
      On the next frame a "Player State: Has target" display is gone (broken: it stayed shown, with no target).
  M2. a routed change waiting in the same frame (a resource): mounting, and in the same frame your combo points reach 3. On the next frame the "combo
      points >= 3" display shows.
  M3. a cooldown event in the same frame: in combat, you join a group and in the same frame a running cooldown is cut short (the game
      hides its times). The "Cooldown ready" display returns within two frames of the NEW end (broken: at the old end, a second late).
  M4. the rules on the 0.2 s re-check (a Range Check on the focus, which no event announces) join the pass: the focus comes into range
      just after a 0.2 s re-check, in the same frame as you mount. On the next frame the "focus in range" display shows (broken: only at
      the next 0.2 s re-check, up to 0.2 s later).
  C2. a rule loaded only with one value of hero talents, class, zone (map ID) or an item equipped, with every other load fact the same:
      that value comes (a hero talent switch, a class, a zone change, putting the item on), and the display shows on the next frames;
      the value goes, and it hides. (Test C of tests/fix_r9_engine_narrow_run.py generates rules at random, and in its 45,600 tries no
      answer changed through hero, class, map ID or the gear count, so dropping one of them from ns.LoadReads still passed.)
  C3. for every load fact the engine compares (ns.CTX_FACTS), one rule whose only load condition is that fact: changing the fact changes
      the rule's load answer, and ns.LoadReads names that fact.
Stand-in game: the whole-addon harness (tests/harness), with Cooldown widgets and duration objects stubbed by their documented contracts
(as tests/fix_r7_cd_failsafe_run.py). UNVERIFIED IN GAME. One frame is 1/60 s here (a stand-in number, not WoW's frame rate).
Run: python3 tests/fix_r10_engine_merge_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name, ok and true or false, extra ~= nil and tostring(extra) or nil } end
local FRAME = 1 / 60
-- ---------------------------------------------------------------- the game model
local G = { mounted = false, group = false, target = true, focus = true, inRange = false, combo = 2, hero = 32, class = "DEMONHUNTER",
  map = 3, equipped = false, cd = nil }
IsMounted = function() return G.mounted end
IsInGroup = function() return G.group end
local UE0 = UnitExists
UnitExists = function(u) if u == "target" then return G.target end if u == "focus" then return G.focus end return UE0(u) end
UnitPower = function() return G.combo end
C_Spell.IsSpellInRange = function(id, unit) if unit == "focus" then return G.inRange end return true end
C_ClassTalents.GetActiveHeroTalentSpec = function() return G.hero end
UnitClass = function(u) if u == "player" then return "Class", G.class, 1 end return nil end
C_Map.GetBestMapForUnit = function() return G.map end
C_Map.GetMapInfo = function(id) return { name = "Map " .. tostring(id), mapID = id } end
C_Item.IsEquippedItem = function(id) if id == 5000 then return G.equipped end return false end
IsEquippedItem = C_Item.IsEquippedItem
C_SpellBook.IsSpellKnownOrInSpellBook = function() return true end
IsPlayerSpell = function() return true end
-- (M3) a spell on a cooldown the game hides in combat, timed by the engine's own Cooldown widget fed the duration object (the stand-in of
-- tests/fix_r7_cd_failsafe_run.py: a feed keeps the end; OnCooldownDone runs on the first frame at or after the end, INFERENCE)
local function secret(name) return W.MarkSecret(setmetatable({}, { __tostring = function() return "SECRET " .. name end })) end
local SEC_START, SEC_DUR = secret("start"), secret("duration")
local engineWidgets = {}
local CF0 = CreateFrame
CreateFrame = function(kind, name, parent, template, ...)
  local f = CF0(kind, name, parent, template, ...)
  if kind == "Cooldown" then
    local i = debug.getinfo(2, "S")
    if i and i.source and i.source:find("Engine.lua", 1, true) then
      engineWidgets[#engineWidgets + 1] = f
      rawset(f, "SetCooldownFromDurationObject", function(self, d, clearIfZero)
        if d and d.endAt > W.now then self._endAt = d.endAt elseif clearIfZero ~= false then self._endAt = nil end
      end)
      rawset(f, "Clear", function(self) self._endAt = nil end)
    end
  end
  return f
end
local driver = CF0("Frame")
driver:SetScript("OnUpdate", function()
  for _, w in ipairs(engineWidgets) do
    if w._endAt and W.now >= w._endAt and w:IsVisible() then
      w._endAt = nil
      local fn = w._scripts and w._scripts.OnCooldownDone
      if fn then fn(w) end
    end
  end
end)
local IDLE = { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
local function cdRunning() return G.cd and W.now < G.cd.start + G.cd.len end
C_Spell.GetSpellCooldown = function(id)
  if id ~= 4001 or not cdRunning() then return IDLE end
  return { startTime = SEC_START, duration = SEC_DUR, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
end
C_Spell.GetSpellCooldownDuration = function(id)
  if id ~= 4001 then return nil end
  if cdRunning() then return { startAt = G.cd.start, endAt = G.cd.start + G.cd.len } end
  return { startAt = W.now, endAt = W.now }
end

L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local P = {}
local function mk(nm, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.trigger = "condition"; r.visual.text.enabled = false; r.sound.enabled = false
  r.cdState, r.buffState = "none", "none"
  f(r); ns.NormalizeRule(r); r.visual.x, r.visual.y = 0, 0
  ns.rules[#ns.rules + 1] = r; P[nm] = r; return r
end
local function row(nm, t, f) return mk(nm, function(r) r.extra = { list = { t } }; if f then f(r) end end) end
-- the rules of every case (each case changes only what it plays; the others are there as bystanders)
row("has target", { type = "playerState", what = "target", state = "yes" })
mk("not mounted", function(r) r.load.mounted = "no" end)
row("combo points", { type = "resource", power = "comboPoints", op = ">=", count = 3 })
row("focus in range", { type = "rangeCheck", unit = "focus", spellID = 1, state = "yes" })
mk("cooldown ready", function(r) r.useCooldown, r.spellID, r.cdState = true, 4001, "ready" end)
mk("hero 31 only", function(r) r.load.heroes = { ["31"] = true } end)
mk("warriors only", function(r) r.load.classes = { WARRIOR = true } end)
mk("zone 2 only", function(r) r.load.mapIDs = { ["2"] = true } end)
mk("item 5000 on", function(r) r.load.equipped = { ["5000"] = true } end)
ns.MarkDirty(); W.tick(FRAME, 20); W.tick(0.5, 2)
local frames = ns.VisualProbeState and ns.VisualProbeState()
local function shown(nm) local f = frames and frames[P[nm]]; return f and f:IsShown() and true or false end
local function quiet() W.tick(0.25, 2) end   -- (a quiet moment: every re-check path's pace is free, the next change runs on the next frame)
local ES = ns.EngineStats

if MODE == "M1" then
  check("(setup) with a target and not mounted: 'has target' and 'not mounted' show", shown("has target") and shown("not mounted"))
  quiet()
  G.mounted = true; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
  G.target = false; W.fire("PLAYER_TARGET_CHANGED")
  W.tick(FRAME, 1)
  local a, b = shown("has target"), shown("not mounted")
  check("M1. mounting and losing your target in the same frame: on the next frame 'has target' is gone and 'not mounted' is gone",
    not a and not b, ("has target %s, not mounted %s"):format(tostring(a), tostring(b)))
  W.tick(FRAME, 60)
  check("M1. ... and one second later 'has target' is still gone (nothing left it on screen)", not shown("has target"), tostring(shown("has target")))
elseif MODE == "M2" then
  check("(setup) 2 combo points: the 'combo points >= 3' display is hidden; not mounted", not shown("combo points") and shown("not mounted"))
  quiet()
  -- (the mount first: the settle it asks for is then set to run first, and the narrowed pass must take the power event's work; with
  -- the power event first, a routed pass of its own runs before it)
  G.mounted = true; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
  G.combo = 4; W.fire("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
  W.tick(FRAME, 1)
  local a = shown("combo points")
  check("M2. combo points reach 4 in the same frame as you mount: on the next frame the 'combo points >= 3' display shows",
    a and not shown("not mounted"), ("combo points %s, not mounted %s"):format(tostring(a), tostring(shown("not mounted"))))
elseif MODE == "M3" then
  W.enterCombat(); W.tick(FRAME, 10)
  check("(setup) in combat, out of the cooldown: 'cooldown ready' shows", shown("cooldown ready"))
  G.cd = { start = W.now, len = 3 }
  W.fire("SPELL_UPDATE_COOLDOWN", 4001); W.tick(FRAME, 6)
  check("(setup) the spell goes on its 3 s cooldown (start and duration hidden): 'cooldown ready' hides", not shown("cooldown ready"))
  W.tick(FRAME, 54)   -- (one second in; 6 + 54 = 60 frames = 1 s)
  -- the cooldown is cut to 2 s (a cooldown event; its reading, running with its times hidden, does not change) in the same frame as
  -- joining a group (a load fact: the narrowed pass takes the cooldown event's work)
  -- (the group first, as in M2: the narrowed pass must take the cooldown event's work)
  G.group = true; W.fire("GROUP_ROSTER_UPDATE")
  G.cd.len = 2
  W.fire("SPELL_UPDATE_COOLDOWN", 4001)
  W.tick(FRAME, 3)
  check("(setup) still on cooldown after the cut", not shown("cooldown ready"))
  local endAt = G.cd.start + G.cd.len
  local backAt
  while W.now < endAt + 2 do
    W.tick(FRAME, 1)
    if not backAt and shown("cooldown ready") then backAt = W.now - endAt end
  end
  -- (two frames: 2 x 1/60 s = 33 ms; the old end is 1 s after the new one)
  check("M3. a cooldown cut short in the same frame as joining a group: 'cooldown ready' returns within two frames (33 ms) of the new end",
    backAt ~= nil and backAt <= 2 * FRAME + 0.0005, backAt and ("%.0f ms after the new end"):format(backAt * 1000) or "not shown 2 s after the new end")
elseif MODE == "M4" then
  check("(setup) the focus is out of range: 'focus in range' is hidden; not mounted", not shown("focus in range") and shown("not mounted"))
  quiet()
  -- wait for a 0.2 s re-check of the focus's range to run (ns.EngineStats.pollRange counts them), then one more frame
  local p0 = ES.pollRange
  local guard = 0
  while ES.pollRange == p0 and guard < 60 do W.tick(FRAME, 1); guard = guard + 1 end
  W.tick(FRAME, 1)
  local p1 = ES.pollRange
  G.inRange = true   -- (no event: the game sends none when the focus walks into range)
  G.mounted = true; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
  W.tick(FRAME, 1)
  local a = shown("focus in range")
  check("M4. the focus comes into range just after a 0.2 s re-check, in the same frame as you mount: on the next frame 'focus in range' shows",
    guard < 60 and a and not shown("not mounted"), ("0.2 s re-checks seen %d; focus in range %s"):format(p1 - p0, tostring(a)))
elseif MODE == "C2" then
  local function play(label, nm, set, fire, want)
    quiet()
    set(); fire()
    W.tick(FRAME, 2)
    local a = shown(nm)
    check("C2. " .. label .. ": on the frames after, '" .. nm .. "' " .. (want and "shows" or "hides"), a == want, ("shown %s"):format(tostring(a)))
  end
  check("(setup) hero talents 32, a demon hunter, zone 3, item 5000 not on: none of the four displays shows",
    not (shown("hero 31 only") or shown("warriors only") or shown("zone 2 only") or shown("item 5000 on")))
  play("switching to hero talents 31 (TRAIT_SUB_TREE_CHANGED)", "hero 31 only", function() G.hero = 31 end, function() W.fire("TRAIT_SUB_TREE_CHANGED", 1) end, true)
  play("switching back to hero talents 32", "hero 31 only", function() G.hero = 32 end, function() W.fire("TRAIT_SUB_TREE_CHANGED", 1) end, false)
  play("the class reading Warrior (a load-fact event)", "warriors only", function() G.class = "WARRIOR" end, function() W.fire("ZONE_CHANGED") end, true)
  play("the class reading Demon Hunter again", "warriors only", function() G.class = "DEMONHUNTER" end, function() W.fire("ZONE_CHANGED") end, false)
  play("entering zone 2 (ZONE_CHANGED_NEW_AREA)", "zone 2 only", function() G.map = 2 end, function() W.fire("ZONE_CHANGED_NEW_AREA") end, true)
  play("leaving zone 2", "zone 2 only", function() G.map = 3 end, function() W.fire("ZONE_CHANGED_NEW_AREA") end, false)
  play("putting item 5000 on (PLAYER_EQUIPMENT_CHANGED)", "item 5000 on", function() G.equipped = true end, function() W.fire("PLAYER_EQUIPMENT_CHANGED", 16, true) end, true)
  play("taking item 5000 off", "item 5000 on", function() G.equipped = false end, function() W.fire("PLAYER_EQUIPMENT_CHANGED", 16, false) end, false)
elseif MODE == "C3" then
  -- one rule per load fact, that fact its only load condition: two values of the fact give two load answers, and ns.LoadReads names it
  local TWO = { instanceType = { "party", "raid" }, specID = { 71, 72 }, role = { "TANK", "DAMAGER" }, hero = { 31, 32 }, class = { "WARRIOR", "MAGE" },
    mapID = { 2, 3 }, instanceID = { 600, 601 }, difficultyID = { 8, 1 }, instSize = { 5, 20 }, encounterID = { 2001, 0 } }
  local SET = {
    instanceType = function(l) l.instanceTypes = { party = true } end, specID = function(l) l.specs = { ["71"] = true } end,
    role = function(l) l.roles = { TANK = true } end, hero = function(l) l.heroes = { ["31"] = true } end,
    class = function(l) l.classes = { WARRIOR = true } end, mapID = function(l) l.mapIDs = { ["2"] = true } end,
    instanceID = function(l) l.instanceIDs = { ["600"] = true } end, difficultyID = function(l) l.difficulties = { ["8"] = true } end,
    instSize = function(l) l.sizes = { ["5"] = true } end, encounterID = function(l) l.encounterIDs = { ["2001"] = true } end,
    equipGen = function(l) l.equipped = { ["5000"] = true } end }
  local tri = {}
  for _, c in ipairs(ns.LOAD_TRI) do tri[c.key] = true end
  local bad, n = {}, 0
  for _, fact in ipairs(ns.CTX_FACTS) do
    local r = ns.NewRule(); r.name = "only " .. fact; r.enabled = true
    if tri[fact] then r.load[fact] = "yes" elseif SET[fact] then SET[fact](r.load) end
    ns.rules = { r }; ns.configVersion = (ns.configVersion or 0) + 1
    local reads = {}
    for _, k in ipairs(ns.LoadReads(r)) do reads[k] = true end
    local changes = true
    if fact ~= "equipGen" then   -- (the gear count only tells a gear change apart; the answer reads the item itself, C2 above)
      local a, b = {}, {}
      for _, k in ipairs(ns.CTX_FACTS) do
        local v = TWO[k]
        if v then a[k], b[k] = v[1], v[1] elseif tri[k] then a[k], b[k] = false, false end
      end
      local v = TWO[fact]
      if v then b[fact] = v[2] else a[fact], b[fact] = true, false end
      a.maps, b.maps = { [a.mapID] = true }, { [b.mapID] = true }
      changes = ns.CheckContext(r, a) ~= ns.CheckContext(r, b)
    end
    n = n + 1
    if not changes then bad[#bad + 1] = fact .. ": the answer did not change" end
    if not reads[fact] then bad[#bad + 1] = fact .. ": not named by ns.LoadReads" end
  end
  check(("C3. every load fact the engine compares (%d): a rule loaded only by it changes its answer with it, and ns.LoadReads names it"):format(n),
    #bad == 0 and n >= 15, table.concat(bad, "; "))
end
local errs = {}
for i = 1, #W.errors do errs[#errs + 1] = tostring(W.errors[i]):sub(1, 160) end
check("(" .. MODE .. ") no Lua error", #W.errors == 0, table.concat(errs, " | "))
return R
end
'''


def run_case(mode):
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    return L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)


def main():
    total = bad = 0
    for mode in ("M1", "M2", "M3", "M4", "C2", "C3"):
        res = run_case(mode)
        for i in range(1, len(res) + 1):
            name, ok, extra = res[i][1], bool(res[i][2]), res[i][3]
            total += 1
            bad += 0 if ok else 1
            print(("ok  " if ok else "FAIL: ") + name + ("" if not extra else "  [%s]" % extra))
    print("%d checks, %d failed" % (total, bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
