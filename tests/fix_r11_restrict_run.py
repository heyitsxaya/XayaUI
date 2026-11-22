#!/usr/bin/env python3
"""Round 11b, the hidden-data fight, steps 2 and 3 (REQUEST-LOG SD-120, her answer "yes": the stand-in hides aura and cooldown data the way
keys, raids and boss fights do, including restricted but out of combat; SD-126: raids are covered by unit tests; SD-127: every payload shape
counts). The restriction state machine, its drivers and the hidden reads of tests/harness/world.lua; build spec sections 2.2, 3.2, 3.3 and
tests T3, T4, T5, T6, T7, T11 (kept in the private XUI-Docs repo). Every check reads what addon code is handed or refused, or what the
gate's integrity checks will read (W.restrictionLog), in the stand-in game.

  T3  the drivers in the default order and with each flip (combat enter and leave, key start and complete, encounter start and end);
      while an Activating event is dispatched IsAddOnRestrictionActive is false for every type; a key between pulls is hidden; an
      encounter while out of combat is hidden; a raid or dungeon out of combat is readable (Map and Chat only); Chat (5,1)/(5,0) on an
      instance and on an encounter outside one; NeverSecret beats the state and AlwaysSecret hides with no restriction; aura instance IDs
      are random and re-randomized at a key's start and an encounter's start, with a hidden full update; W.combat set on its own leaves
      every restriction as it is (a HARNESS CONTRACT, not game behaviour).
  T4  while auras are hidden, addon code is refused the index / slot / instance-ID reads, GetUnitAuras and GetUnitAuraInstanceIDs (every
      RequiresUnitAuraAccess function of api.json); the spell-ID and name reads give nil, or the data of a NeverSecret spell; an
      AlwaysSecret spell gives nil always; GetSpellMaxCumulativeAuraApplications is hidden, readable for NeverSecret; UNIT_AURA payloads
      are hidden tables in the shape asked for (A, B, C).
  T5  cooldowns and charges are hidden field by field (isEnabled, isActive, isOnGCD, maxCharges readable); a NeverSecret spell is fully
      readable; a duration object says HasSecretValues and hides its times, while IsZero / HasExpired / IsActive stay readable; zero-span
      when the cooldown is not active and at max charges; a Cooldown widget fed the object runs out (OnCooldownDone).
  T6  aura buttons of Blizzard's container refuse addon code while auras are hidden, except inside initializeFrame and (native widget
      methods) before PLAYER_LOGIN; not once auras are readable; the stand-in's own and the gate's code still reach them.
  T7  the API guard: a hidden value handed by addon code to Button:SetText, SetShown, Slider:SetValue, Cooldown:SetCooldown or
      FontString:SetAlpha errors; FontString:SetText, StatusBar:SetValue and Frame:SetAlpha take it; a hidden STRING to StatusBar:SetValue
      errors; the rules are read per object type from the index built from api.json (not widgets.md, which lists one flag per name).
  TC  what the stand-in bills to addon code (V27 / V33; spec 3.1 and 4.4.5): a hidden value a guarded method allows costs what a plain
      one costs, and the guard adds at most 15 instructions to the stand-in's body; the C-API readers (cooldowns, charges, duration
      objects, aura reads) bill the call and secret.lua's shell only, readable or hidden; a raising reader body is raised at the addon's
      line and its helper survives; aura buttons cost a raw method call / an ordinary widget lookup while auras are readable, before and
      after a hidden spell (they change form only when the hidden state flips).
  W   through the loader (every addon play): a file the loader ran is addon code (its refused call is a Lua error at its own line), and
      a forbidden payload or hidden number an addon keeps in its saved data is written as nil at logout, with no save problem.
  T11 combat order: PLAYER_REGEN_DISABLED is handled before the lockdown, in tests/harness/scenario.lua and fix_r7_engine_alloc_run.py
      (they use W.enterCombat / W.leaveCombat), and no kept file of the spec's combat table fires PLAYER_REGEN_DISABLED while it holds
      W.combat = true. (T11 guards round 11a's fix: it passes on this unit's pre-change files too; its proof is the broken copy.)
Fails on the tree before this change (world.lua with fixed answers: no W.setRestriction, ShouldAurasBeSecret always false, no guard, no
forbidden buttons); passes after. On that tree the event-order checks fail too: a driver the old world lacks is fired by the test's own
fallback, which first logs "NO DRIVER W.<name>", so no order check can pass on the test's copy of the order. Checks that do pass there
are controls (no false alarm, nil reads paired with failing positives, the TC "no extra cost" checks the unguarded old world trivially
meets) and T11, which guards round 11a's fix. The TC section fails on this unit's first build (Lua-side guard decision and readers, the
aura buttons' lookup hop).
Run: python3 tests/fix_r11_restrict_run.py   (Lua 5.1 via lupa; needs the API index: tests/harness/api_index.json or XUI_API_INDEX)
     XUI_RESTRICT_HARNESS=<folder with world.lua and secret.lua> plays another stand-in (a private pre-change copy, a broken copy);
     XUI_RESTRICT_TESTS=<folder> reads T11's files from another tests folder."""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

STANDIN = os.environ.get("XUI_RESTRICT_HARNESS") or os.path.join(HERE, "harness")
TESTS = os.environ.get("XUI_RESTRICT_TESTS") or HERE
ROOT = os.path.dirname(HERE)

checks = fails = 0


def check(name, ok, detail=""):
    global checks, fails
    checks += 1
    detail = "" if detail is None else str(detail).replace("\n", " ")[:400]
    if not ok:
        fails += 1
    print(("PASS " if ok else "FAIL ") + name + (("  [%s]" % detail) if detail else ""))


API_RAW = H.load_api()
if not (isinstance(API_RAW.get("secrecy"), dict) and API_RAW["secrecy"].get("widgets")):
    print("MISSING INPUT: the API index's secrecy section (build it: python3 tests/harness/api_index_from_docs.py, or set XUI_API_INDEX)")
    check("the API index carries the secrecy flags of api.json", False)
API_SLIM = {k: v for k, v in API_RAW.items() if k != "framexml"}

PRELUDE = r'''
local R = {}
function out(name, ok, detail) R[#R + 1] = { name = name, ok = ok and true or false, detail = detail ~= nil and tostring(detail) or "" } end
-- a chunk of "addon code" (tainted: loaded from Interface/AddOns/, as the loader names every addon file)
function addon(src) return assert(loadstring(src, "@Interface/AddOns/XayaUI_Probe/probe.lua")) end
-- every event this test listens to, in order: "EVENT a b" (b of ADDON_RESTRICTION_STATE_CHANGED is the state)
LOG, SEEN = {}, {}
local f = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "CHALLENGE_MODE_START",
  "CHALLENGE_MODE_COMPLETED", "ENCOUNTER_START", "ENCOUNTER_END", "UNIT_AURA", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do f:RegisterEvent(e) end
f:SetScript("OnEvent", function(_, e, a, b)
  local s
  if e == "ADDON_RESTRICTION_STATE_CHANGED" then s = "RS " .. tostring(a) .. " " .. tostring(b)
  elseif e == "UNIT_AURA" then s = "UNIT_AURA " .. tostring(a) .. (issecretvalue(b) and " hidden" or " readable")
  else s = e end
  LOG[#LOG + 1] = s
  -- what code reading the state sees during this dispatch
  local active = {}
  for _, t in ipairs({ 0, 1, 2, 4, 5 }) do active[#active + 1] = tostring(C_RestrictedActions.IsAddOnRestrictionActive(t)) end
  SEEN[#SEEN + 1] = { ev = s, lock = InCombatLockdown(), affecting = UnitAffectingCombat("player"), auras = C_Secrets.ShouldAurasBeSecret(),
    active = table.concat(active, ","), st = { [0] = C_RestrictedActions.GetAddOnRestrictionState(0), [1] = C_RestrictedActions.GetAddOnRestrictionState(1),
    [2] = C_RestrictedActions.GetAddOnRestrictionState(2), [4] = C_RestrictedActions.GetAddOnRestrictionState(4), [5] = C_RestrictedActions.GetAddOnRestrictionState(5) },
    key = C_ChallengeMode.IsChallengeModeActive() }
end)
function reset() LOG, SEEN = {}, {} end
function seq() return table.concat(LOG, " | ") end
function seen(ev) for _, s in ipairs(SEEN) do if s.ev == ev then return s end end return nil end
-- A stand-in without a driver (the pre-change world): the test fires that driver's events by hand, so the checks below fail as assertions
-- on what the old world answers (e.g. ShouldAurasBeSecret false inside a key), not on a missing function. Each hand-fired driver first
-- writes "NO DRIVER W.<name>" into the event log, so no event-order check can pass on the test's own copy of the spec's order: an order
-- check passes only when the world's own driver fired the events (V31 step 3: new-behaviour checks fail on the pre-change world).
S = W.S or dofile(SECRET_PATH)
local function RS(t, st) W.fire("ADDON_RESTRICTION_STATE_CHANGED", t, st) end
local FB, fakeID = {}, 100
function FB.enterInstance(kind) W.fire("PLAYER_ENTERING_WORLD", false, false); W.fire("ZONE_CHANGED_NEW_AREA"); RS(4, 1); if kind == "party" or kind == "raid" then RS(5, 1) end end
function FB.leaveInstance() RS(5, 0); RS(4, 0); W.fire("PLAYER_ENTERING_WORLD", false, false); W.fire("ZONE_CHANGED_NEW_AREA") end
function FB.startKey(map) RS(2, 1); W.fire("UNIT_AURA", "player", { isFullUpdate = true }); W.fire("CHALLENGE_MODE_START", map) end
function FB.completeKey() W.fire("CHALLENGE_MODE_COMPLETED"); RS(2, 0) end
function FB.startEncounter(id, name, d, n) RS(1, 1); W.fire("UNIT_AURA", "player", { isFullUpdate = true }); W.fire("ENCOUNTER_START", id, name, d, n) end
function FB.endEncounter(ok) W.fire("ENCOUNTER_END", 0, "", 0, 0, ok or 1, {}); RS(1, 0) end
function FB.addAura(unit, f) fakeID = fakeID + 1; local a = { auraInstanceID = fakeID }; for k, v in pairs(f or {}) do a[k] = v end; return a end
function FB.removeAura() end
function FB.setCooldown() end
function FB.setCharges() end
function FB.methodRule() return nil end
local DRIVERS = { enterInstance = true, leaveInstance = true, startKey = true, completeKey = true, startEncounter = true, endEncounter = true }
local missing = {}
for k, fn in pairs(FB) do
  if W[k] == nil then
    W[k] = DRIVERS[k] and function(...) LOG[#LOG + 1] = "NO DRIVER W." .. k; return fn(...) end or fn
    missing[#missing + 1] = k
  end
end
for _, k in ipairs({ "restrictionLog", "auraSecrecy", "cdSecrecy", "auraMaxStacks", "AURA_ACCESS", "auraButtons" }) do
  if W[k] == nil then W[k] = {}; missing[#missing + 1] = k end
end
W.TEXT_FORBIDDEN = W.TEXT_FORBIDDEN or "forbidden"
if #missing > 0 then table.sort(missing); out("NOTE the stand-in lacks " .. table.concat(missing, ", ") .. " (its events are fired by hand)", false) end
'''


def play(title, body):
    """One fresh Lua state and stand-in world; body is Lua that calls out(name, ok, detail). Returns nothing; reports each out()."""
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, API_SLIM)
    try:
        W = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(STANDIN, "world.lua"), api)
    except Exception as e:  # a stand-in that does not load
        check("%s: the stand-in world loads" % title, False, e)
        return None
    L.globals().W = W
    L.globals().SECRET_PATH = os.path.join(STANDIN, "secret.lua")
    runner = L.eval("function(src) local f = assert(loadstring(src, '=fix_r11_restrict')); local ok, r = pcall(f); return ok, r end")
    # the body runs in a function of its own: an error ends it, the checks made so far still count, and the error is a FAIL
    src = PRELUDE + "\nlocal okBody, errBody = pcall(function()\n" + body + "\nend)\nif not okBody then out('section ran to its end', false, errBody) end\nreturn R"
    ok, res = runner(src)
    if not ok:
        check("%s: section ran to its end" % title, False, res)
        return W
    n = 0
    for i in range(1, len(res) + 1):
        e = res[i]
        check("%s: %s" % (title, e.name), e.ok, e.detail)
        n += 1
    if n == 0:
        check("%s: section reported checks" % title, False)
    return W


# -------------------------------------------------------------------------------------------------------------------------------------
# T3: the state machine and its drivers
# -------------------------------------------------------------------------------------------------------------------------------------
T3_COMBAT = r'''
-- the defaults first, on a world no check has touched: the spec's order (PLAYER_REGEN_DISABLED first; (0,0) before PLAYER_REGEN_ENABLED)
out("the default flips are the spec's order (combatRestrictFirst false, combatLeaveRestrictFirst true, keyRestrictFirst true, "
  .. "keyCompleteRestrictFirst false, encounterRestrictFirst true, encounterEndRestrictFirst false)", W.combatRestrictFirst == false
  and W.combatLeaveRestrictFirst == true and W.keyRestrictFirst == true and W.keyCompleteRestrictFirst == false and W.encounterRestrictFirst == true
  and W.encounterEndRestrictFirst == false)
reset(); W.enterCombat(); W.leaveCombat()
out("default combat play: PLAYER_REGEN_DISABLED, (0,1), (0,0), PLAYER_REGEN_ENABLED", seq() == "PLAYER_REGEN_DISABLED | RS 0 1 | RS 0 0 | PLAYER_REGEN_ENABLED", seq())
W.restrictionLog = {}
-- combat, both settings of each flip
for _, flip in ipairs({ false, true }) do
  W.combatRestrictFirst = flip
  reset(); W.enterCombat()
  local want = flip and "RS 0 1 | PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_DISABLED | RS 0 1"
  out("combat start (combatRestrictFirst=" .. tostring(flip) .. "): the events in order " .. want, seq() == want, seq())
  local rd, rs = seen("PLAYER_REGEN_DISABLED"), seen("RS 0 1")
  out("... PLAYER_REGEN_DISABLED is handled with the lockdown off and the player already affecting combat (T11)", rd and rd.lock == false and rd.affecting == true,
    rd and (tostring(rd.lock) .. " " .. tostring(rd.affecting)))
  out("... during (0,1): state 1 (Activating), IsAddOnRestrictionActive false for every type, the lockdown off", rs and rs.st[0] == 1 and rs.active == "false,false,false,false,false" and rs.lock == false,
    rs and (rs.st[0] .. " " .. rs.active))
  out("... then: lockdown on, Combat Active (2), auras and cooldowns hidden", InCombatLockdown() == true and C_RestrictedActions.GetAddOnRestrictionState(0) == 2
    and C_RestrictedActions.IsAddOnRestrictionActive(0) == true and C_Secrets.ShouldAurasBeSecret() == true and C_Secrets.ShouldCooldownsBeSecret() == true)
  W.combatLeaveRestrictFirst = not flip
  reset(); W.leaveCombat()
  local wantL = (not flip) and "RS 0 0 | PLAYER_REGEN_ENABLED" or "PLAYER_REGEN_ENABLED | RS 0 0"
  out("combat end (combatLeaveRestrictFirst=" .. tostring(not flip) .. "): the events in order " .. wantL, seq() == wantL, seq())
  local re = seen("PLAYER_REGEN_ENABLED")
  out("... PLAYER_REGEN_ENABLED is handled with the lockdown already off (T11)", re and re.lock == false and re.affecting == false, re and tostring(re.lock))
  out("... then: Combat Inactive, auras readable", C_RestrictedActions.GetAddOnRestrictionState(0) == 0 and C_Secrets.ShouldAurasBeSecret() == false and not InCombatLockdown())
end
W.combatRestrictFirst, W.combatLeaveRestrictFirst = false, true
-- W.combat alone: a harness contract, NOT game behaviour (the game's lockdown and Combat restriction coincide apart from their edges)
reset(); W.combat = true
out("HARNESS CONTRACT (not the game): W.combat = true alone gives the lockdown and leaves every restriction Inactive, auras readable",
  InCombatLockdown() == true and C_RestrictedActions.GetAddOnRestrictionState(0) == 0 and C_Secrets.ShouldAurasBeSecret() == false and #LOG == 0, seq())
W.combat = false
local okR, errR = pcall(W.setRestriction, 3, true)
out("a restriction the stand-in does not model (3, PvP match: spec L5) is refused loudly, by the world's own W.setRestriction", type(W.setRestriction) == "function"
  and not okR and tostring(errR):find("not modelled", 1, true) ~= nil, errR)
out("the restriction log keeps every (type, state) fired, in order (for the gate's integrity checks)", #W.restrictionLog == 4 and W.restrictionLog[1][1] == 0
  and W.restrictionLog[1][2] == 1 and W.restrictionLog[2][2] == 0 and W.restrictionLog[4][2] == 0, #W.restrictionLog)
'''

T3_KEY = r'''
local flips = { false, true }
for _, flip in ipairs(flips) do
  reset(); W.enterInstance("party", 8)
  out("dungeon entry (flip run " .. tostring(flip) .. "): loading events, then (4,1), then (5,1)",
    seq() == "PLAYER_ENTERING_WORLD | ZONE_CHANGED_NEW_AREA | RS 4 1 | RS 5 1", seq())
  local inInst, kind = IsInInstance()
  local _, itype, diff, _, maxP = GetInstanceInfo()
  out("... IsInInstance / GetInstanceInfo answer the dungeon (party, difficulty 8, 5 players)", inInst == true and kind == "party" and itype == "party" and diff == 8 and maxP == 5,
    tostring(kind) .. " " .. tostring(diff))
  out("... a dungeon before the key keeps auras and cooldowns readable (Map and Chat Active only)", C_Secrets.ShouldAurasBeSecret() == false
    and C_Secrets.ShouldCooldownsBeSecret() == false and C_RestrictedActions.GetAddOnRestrictionState(4) == 2 and C_RestrictedActions.GetAddOnRestrictionState(5) == 2)
  W.keyRestrictFirst = not flip
  reset(); W.startKey(501, 12, { 9, 10 })
  local want = (not flip) and "RS 2 1 | UNIT_AURA player hidden | CHALLENGE_MODE_START" or "CHALLENGE_MODE_START | RS 2 1 | UNIT_AURA player hidden"
  out("key start (keyRestrictFirst=" .. tostring(not flip) .. "): " .. want, seq() == want, seq())
  local cms = seen("CHALLENGE_MODE_START")
  out("... CHALLENGE_MODE_START: IsChallengeModeActive true; " .. ((not flip) and "auras already hidden" or "auras not yet hidden"),
    cms and cms.key == true and cms.auras == (not flip), cms and tostring(cms.auras))
  out("... the key between pulls (out of combat) is hidden: ShouldAurasBeSecret and ShouldCooldownsBeSecret true, state 2 = 2, 5 = 2",
    not InCombatLockdown() and C_Secrets.ShouldAurasBeSecret() == true and C_Secrets.ShouldCooldownsBeSecret() == true
    and C_RestrictedActions.GetAddOnRestrictionState(2) == 2 and C_RestrictedActions.GetAddOnRestrictionState(5) == 2)
  local lvl, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
  out("... the keystone answers (level 12, two affixes, map 501)", lvl == 12 and type(affixes) == "table" and #affixes == 2 and C_ChallengeMode.GetActiveChallengeMapID() == 501)
  W.keyCompleteRestrictFirst = flip
  reset(); W.completeKey()
  local wantC = (not flip) and "CHALLENGE_MODE_COMPLETED | RS 2 0" or "RS 2 0 | CHALLENGE_MODE_COMPLETED"
  out("key completed (keyCompleteRestrictFirst=" .. tostring(flip) .. "): " .. wantC, seq() == wantC, seq())
  local cmc = seen("CHALLENGE_MODE_COMPLETED")
  out("... CHALLENGE_MODE_COMPLETED is handled " .. ((not flip) and "while the key is still Active" or "after it ended"),
    cmc and cmc.st[2] == ((not flip) and 2 or 0), cmc and cmc.st[2])
  out("... after the key, in the dungeon: readable again, Chat still Active (the map holds it), Map Active",
    C_Secrets.ShouldAurasBeSecret() == false and C_RestrictedActions.GetAddOnRestrictionState(5) == 2 and C_RestrictedActions.GetAddOnRestrictionState(4) == 2
    and C_ChallengeMode.IsChallengeModeActive() == false)
  reset(); W.leaveInstance()
  out("leaving: (5,0), then (4,0), then the loading events", seq() == "RS 5 0 | RS 4 0 | PLAYER_ENTERING_WORLD | ZONE_CHANGED_NEW_AREA", seq())
  out("... IsInInstance false again", (IsInInstance()) == false)
end
W.keyRestrictFirst, W.keyCompleteRestrictFirst = true, false
'''

T3_ENCOUNTER = r'''
for _, flip in ipairs({ false, true }) do
  reset(); W.enterInstance("raid", 16)
  out("raid entry (flip run " .. tostring(flip) .. "): (4,1) and (5,1), auras and cooldowns readable between bosses (Map and Chat only)",
    seq() == "PLAYER_ENTERING_WORLD | ZONE_CHANGED_NEW_AREA | RS 4 1 | RS 5 1" and C_Secrets.ShouldAurasBeSecret() == false and C_Secrets.ShouldCooldownsBeSecret() == false, seq())
  W.addAura("player", { spellId = 4100, duration = 30 }, true)
  W.setCooldown(4200, W.now, 20)
  local c = C_Spell.GetSpellCooldown(4200)
  out("... between bosses a cooldown reads in the clear and an aura by spell ID is handed", not issecretvalue(c.startTime) and not issecretvalue(c.duration)
    and C_UnitAuras.GetPlayerAuraBySpellID(4100) ~= nil)
  W.encounterRestrictFirst = not flip
  reset(); W.startEncounter(3001, "Stand-in Boss", 16, 20)
  local want = (not flip) and "RS 1 1 | UNIT_AURA player hidden | ENCOUNTER_START" or "ENCOUNTER_START | RS 1 1 | UNIT_AURA player hidden"
  out("boss pull in the raid (encounterRestrictFirst=" .. tostring(not flip) .. "): " .. want .. " (Chat is already Active: no second (5,1))", seq() == want, seq())
  out("... an encounter while out of combat is hidden (INFERENCE, RACD:27)", not InCombatLockdown() and C_Secrets.ShouldAurasBeSecret() == true
    and C_Secrets.ShouldCooldownsBeSecret() == true and C_InstanceEncounter.IsEncounterInProgress() == true)
  W.encounterEndRestrictFirst = flip
  reset(); W.endEncounter(1)
  local wantE = (not flip) and "ENCOUNTER_END | RS 1 0" or "RS 1 0 | ENCOUNTER_END"
  out("boss kill (encounterEndRestrictFirst=" .. tostring(flip) .. "): " .. wantE .. " (the raid map keeps Chat)", seq() == wantE, seq())
  local ee = seen("ENCOUNTER_END")
  out("... ENCOUNTER_END is handled " .. ((not flip) and "while the encounter is still Active" or "after it ended"), ee and ee.st[1] == ((not flip) and 2 or 0), ee and ee.st[1])
  out("... after the boss: readable again, Chat still Active", C_Secrets.ShouldAurasBeSecret() == false and C_RestrictedActions.GetAddOnRestrictionState(5) == 2)
  W.leaveInstance()
end
W.encounterRestrictFirst, W.encounterEndRestrictFirst = true, false
-- an encounter outside any instance map: the encounter itself holds Chat
reset(); W.startEncounter(3002, "Field Boss", 0, 5)
out("an encounter outside an instance: (1,1), then (5,1) (the encounter holds Chat), then the hidden full update and ENCOUNTER_START",
  seq() == "RS 1 1 | RS 5 1 | UNIT_AURA player hidden | ENCOUNTER_START", seq())
reset(); W.endEncounter(0)
out("... its end: ENCOUNTER_END, (1,0), then (5,0)", seq() == "ENCOUNTER_END | RS 1 0 | RS 5 0", seq())
-- Activating during a key: every type reads not active while the event is dispatched (RAD:58, literal reading)
W.enterInstance("party", 8); W.startKey(502)
reset(); W.startEncounter(3003, "Key Boss", 8, 5)
local rs = seen("RS 1 1")
out("an Activating event inside a running key: GetAddOnRestrictionState(1) = 1, IsAddOnRestrictionActive false for every type (even the running key's)",
  rs and rs.st[1] == 1 and rs.st[2] == 2 and rs.active == "false,false,false,false,false", rs and rs.active)
out("... after it: Encounter and ChallengeMode both read active", C_RestrictedActions.IsAddOnRestrictionActive(1) == true and C_RestrictedActions.IsAddOnRestrictionActive(2) == true)
-- combat inside the key's boss: leaving combat leaves the boss hidden; ending the boss leaves the key hidden
W.enterCombat(); W.leaveCombat()
out("combat ends during the boss: still hidden (the encounter)", C_Secrets.ShouldAurasBeSecret() == true)
W.endEncounter(1)
out("the boss ends inside the key: still hidden (the key)", C_Secrets.ShouldAurasBeSecret() == true)
W.completeKey(); W.leaveInstance()
out("key completed and dungeon left: every restriction Inactive", C_RestrictedActions.GetAddOnRestrictionState(0) + C_RestrictedActions.GetAddOnRestrictionState(1)
  + C_RestrictedActions.GetAddOnRestrictionState(2) + C_RestrictedActions.GetAddOnRestrictionState(4) + C_RestrictedActions.GetAddOnRestrictionState(5) == 0)
'''

T3_SECRECY = r'''
W.auraSecrecy[7001] = 0   -- NeverSecret
W.auraSecrecy[7002] = 1   -- AlwaysSecret
W.cdSecrecy[7101] = 0
W.cdSecrecy[7102] = 1
out("an unknown spell is ContextuallySecret (2) for auras and cooldowns", C_Secrets.GetSpellAuraSecrecy(999999) == 2 and C_Secrets.GetSpellCooldownSecrecy(999999) == 2,
  tostring(C_Secrets.GetSpellAuraSecrecy(999999)))
out("C_Secrets.HasSecretRestrictions is true (retail; the safer answer)", C_Secrets.HasSecretRestrictions() == true)
out("no restriction: AlwaysSecret still hides (ShouldSpellAuraBeSecret / ShouldSpellCooldownBeSecret true), the others do not",
  C_Secrets.ShouldSpellAuraBeSecret(7002) == true and C_Secrets.ShouldSpellCooldownBeSecret(7102) == true and C_Secrets.ShouldSpellAuraBeSecret(7001) == false
  and C_Secrets.ShouldSpellAuraBeSecret(999999) == false)
W.addAura("player", { spellId = 7001 }, true); W.addAura("player", { spellId = 7002 }, true); W.addAura("player", { spellId = 7003 }, true)
W.setCooldown(7102, W.now, 30)
out("no restriction: an AlwaysSecret aura by spell ID is nil, a ContextuallySecret one is handed",
  C_UnitAuras.GetPlayerAuraBySpellID(7002) == nil and C_UnitAuras.GetPlayerAuraBySpellID(7003) ~= nil)
out("no restriction: an AlwaysSecret cooldown is hidden", issecretvalue(C_Spell.GetSpellCooldown(7102).startTime) == true)
W.enterCombat()
out("in combat: NeverSecret beats the state (aura handed, ShouldSpellAuraBeSecret false)", C_UnitAuras.GetPlayerAuraBySpellID(7001) ~= nil and C_Secrets.ShouldSpellAuraBeSecret(7001) == false)
out("in combat: a ContextuallySecret aura by spell ID is nil", C_UnitAuras.GetPlayerAuraBySpellID(7003) == nil and C_Secrets.ShouldSpellAuraBeSecret(7003) == true)
W.setCooldown(7101, W.now, 30)
local c = C_Spell.GetSpellCooldown(7101)
out("in combat: a NeverSecret cooldown is fully readable", not issecretvalue(c.startTime) and not issecretvalue(c.duration) and not issecretvalue(c.modRate) and c.isActive == true)
W.leaveCombat()
'''

T3_IDS = r'''
local a1 = W.addAura("player", { spellId = 8001 }, true)
local a2 = W.addAura("player", { spellId = 8002 }, true)
local a3 = W.addAura("target", { spellId = 8003, isHelpful = false }, true)
local function ids() return { a1.auraInstanceID, a2.auraInstanceID, a3.auraInstanceID } end
local function sequential(t)
  local s = { t[1], t[2], t[3] }; table.sort(s)
  return s[2] - s[1] == 1 and s[3] - s[2] == 1
end
local before = ids()
out("aura instance IDs are random, not handed in order", not sequential(before) and before[2] ~= before[1] + 1, table.concat(before, ","))
W.enterInstance("party", 8)
reset(); W.startKey(503)
local afterKey = ids()
local changed = afterKey[1] ~= before[1] and afterKey[2] ~= before[2] and afterKey[3] ~= before[3]
out("key start re-randomizes every aura instance ID (not renumbered in order)", changed and not sequential(afterKey), table.concat(afterKey, ","))
out("... and sends a hidden full update to the player and to every unit holding an aura (target)",
  seq() == "RS 2 1 | UNIT_AURA player hidden | UNIT_AURA target hidden | CHALLENGE_MODE_START", seq())
local okOld = C_UnitAuras.GetAuraDataByAuraInstanceID("player", before[1])
out("... an old instance ID no longer names the aura (read by the stand-in's own code)", okOld == nil)
W.startEncounter(3004, "Key Boss", 8, 5)
local afterBoss = ids()
out("encounter start re-randomizes them again", afterBoss[1] ~= afterKey[1] and afterBoss[2] ~= afterKey[2] and afterBoss[3] ~= afterKey[3], table.concat(afterBoss, ","))
W.endEncounter(1); W.completeKey(); W.leaveInstance()
'''

# -------------------------------------------------------------------------------------------------------------------------------------
# T4: aura reads while hidden
# -------------------------------------------------------------------------------------------------------------------------------------
T4_READS = r'''
local mine = W.addAura("player", { spellId = 9001, duration = 20 }, true)
W.addAura("player", { spellId = 9002 }, true)
W.auraSecrecy[9002] = 0
W.auraSecrecy[9003] = 1
W.addAura("player", { spellId = 9003 }, true)
W.auraMaxStacks[9001], W.auraMaxStacks[9002], W.auraMaxStacks[9003] = 3, 5, 2
local probe = addon([[
local P = {}
function P.call(name, ...) local ns, fn = name:match("^([^.]+)%.(.+)$"); local r = _G[ns][fn](...); return r end   -- line 3
function P.idx() local r = C_UnitAuras.GetAuraDataByIndex("player", 1, "HELPFUL"); return r end
function P.iid(id) local r = C_UnitAuras.GetAuraDataByAuraInstanceID("player", id); return r end
function P.list() local r = C_UnitAuras.GetUnitAuras("player", "HELPFUL"); return r end
function P.ids() local r = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HELPFUL"); return r end
function P.spell(id) return C_UnitAuras.GetPlayerAuraBySpellID(id) end
function P.uspell(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
function P.name(n) return C_UnitAuras.GetAuraDataBySpellName("player", n, "HELPFUL") end
function P.max(id) return C_Spell.GetSpellMaxCumulativeAuraApplications(id) end
return P
]])()
-- readable: everything answers
out("readable: the index, instance-ID, list and ID-list reads answer addon code", probe.idx() ~= nil and probe.iid(mine.auraInstanceID) ~= nil and #probe.list() == 3 and #probe.ids() == 3)
out("readable: GetSpellMaxCumulativeAuraApplications answers in the clear (3)", probe.max(9001) == 3 and not issecretvalue(probe.max(9001)))
W.enterCombat()
local function refused(fn, ...)
  local ok, e = pcall(fn, ...)
  return (not ok) and tostring(e) or nil
end
for _, case in ipairs({ { "GetAuraDataByIndex", probe.idx }, { "GetAuraDataByAuraInstanceID", probe.iid, mine.auraInstanceID },
    { "GetUnitAuras", probe.list }, { "GetUnitAuraInstanceIDs", probe.ids } }) do
  local e = refused(case[2], case[3])
  out("hidden: addon code's " .. case[1] .. " errors (RequiresUnitAuraAccess)", e ~= nil and e:find(case[1], 1, true) ~= nil and e:find("XayaUI_Probe/probe.lua", 1, true) ~= nil
    and e:find("(execution tainted by 'XayaUI_Probe')", 1, true) ~= nil, e)
end
-- every RequiresUnitAuraAccess function of api.json refuses, called by addon code
local bad, n = {}, 0
for _, name in ipairs(W.AURA_ACCESS) do
  n = n + 1
  local ok = pcall(probe.call, name, "player", 1, "HELPFUL")
  if ok then bad[#bad + 1] = name end
end
out("hidden: every RequiresUnitAuraAccess function (" .. n .. ", from api.json) refuses addon code", n == 24 and #bad == 0, table.concat(bad, ","))
out("hidden: the stand-in's own (untainted) code still reads by instance ID", C_UnitAuras.GetAuraDataByAuraInstanceID("player", mine.auraInstanceID) ~= nil)
out("hidden: a ContextuallySecret aura by spell ID / unit and spell ID / name is nil",
  probe.spell(9001) == nil and probe.uspell(9001) == nil and probe.name("Spell 9001") == nil)
local nev = probe.spell(9002)
out("hidden: a NeverSecret aura by spell ID is handed, readable", nev ~= nil and nev.spellId == 9002 and not issecretvalue(nev.spellId) and probe.name("Spell 9002") ~= nil)
out("hidden: an AlwaysSecret aura by spell ID is nil", probe.spell(9003) == nil)
local mx = probe.max(9001)
out("hidden: GetSpellMaxCumulativeAuraApplications is a hidden number (its real value kept)", issecretvalue(mx) and S.reveal(mx) == 3)
out("hidden: ... readable for a NeverSecret spell", probe.max(9002) == 5 and not issecretvalue(probe.max(9002)))
W.leaveCombat()
out("readable again: addon code's reads answer", probe.idx() ~= nil and #probe.ids() == 3)
out("readable: an AlwaysSecret aura by spell ID is nil even with no restriction", probe.spell(9003) == nil)
out("readable: GetSpellMaxCumulativeAuraApplications of an AlwaysSecret spell is hidden with no restriction", issecretvalue(probe.max(9003)) == true)
local always
for _, a in ipairs(probe.list()) do if S.shape(a) == "B" then always = a end end
out("readable: an AlwaysSecret aura read by instance ID / list comes back with every field hidden (INFERENCE)", always ~= nil and issecrettable(always) == true
  and issecretvalue(always.spellId) == true)
'''

T4_PAYLOAD = r'''
local got = {}
local f = CreateFrame("Frame"); f:RegisterEvent("UNIT_AURA")
f:SetScript("OnEvent", function(_, _, unit, info) got[#got + 1] = { unit = unit, info = info } end)
W.addAura("player", { spellId = 9101 })
out("readable: UNIT_AURA's payload is a plain table with the added aura", #got == 1 and not issecretvalue(got[1].info) and type(got[1].info.addedAuras) == "table")
for _, shape in ipairs({ "A", "B", "C" }) do
  got = {}
  W.payloadShape = shape
  W.enterCombat()
  local a = W.addAura("player", { spellId = 9102 })
  W.removeAura("player", a.auraInstanceID)
  local p = got[1] and got[1].info
  local okShape = S.shape(p) == shape
  local detail = shape == "A" and (issecretvalue(p) and type(p) == "table")
    or shape == "B" and (issecrettable(p) and canaccesstable(p) and issecretvalue(p.addedAuras))
    or shape == "C" and (canaccesstable(p) == false and not pcall(function() return p.isFullUpdate end))
  out("hidden, shape " .. shape .. ": UNIT_AURA's payload is a hidden table in that shape; unitTarget stays readable (spec 2.2)",
    #got == 2 and okShape and detail and got[1].unit == "player" and not issecretvalue(got[1].unit), #got)
  W.leaveCombat()
end
W.payloadShape = "A"
'''

# -------------------------------------------------------------------------------------------------------------------------------------
# T5: cooldowns, charges and duration objects
# -------------------------------------------------------------------------------------------------------------------------------------
T5_COOLDOWNS = r'''
W.setCooldown(9201, W.now, 30, { isOnGCD = false, activeCategory = 4 })
W.setCharges(9202, 1, 2, W.now, 12)
W.setCharges(9203, 2, 2)
local c0 = C_Spell.GetSpellCooldown(9201)
out("readable: a cooldown reads in the clear (startTime, duration, isActive true)", not issecretvalue(c0.startTime) and c0.duration == 30 and c0.isActive == true and c0.isOnGCD == false)
local idle = C_Spell.GetSpellCooldown(9299)
out("readable: a spell not on cooldown reads isActive false (a readable NeverSecret field)", idle.isActive == false and idle.isEnabled == true and idle.duration == 0)
W.enterCombat()
local c = C_Spell.GetSpellCooldown(9201)
out("hidden: startTime, duration, modRate and activeCategory are hidden numbers with their real values", issecretvalue(c.startTime) and issecretvalue(c.duration)
  and issecretvalue(c.modRate) and issecretvalue(c.activeCategory) and S.reveal(c.duration) == 30 and S.reveal(c.activeCategory) == 4)
out("hidden: isEnabled, isActive and isOnGCD stay readable booleans", c.isEnabled == true and c.isActive == true and c.isOnGCD == false
  and type(c.isActive) == "boolean" and not issecretvalue(c.isActive))
local ch = C_Spell.GetSpellCharges(9202)
out("hidden: charges hide currentCharges and the cooldown times; maxCharges and isActive stay readable", issecretvalue(ch.currentCharges) and issecretvalue(ch.cooldownStartTime)
  and issecretvalue(ch.cooldownDuration) and issecretvalue(ch.chargeModRate) and ch.maxCharges == 2 and ch.isActive == true and S.reveal(ch.currentCharges) == 1)
out("hidden: GetSpellCastCount is hidden", issecretvalue(C_Spell.GetSpellCastCount(9201)) == true)
W.cdSecrecy[9204] = 0; W.setCooldown(9204, W.now, 8)
local nv = C_Spell.GetSpellCooldown(9204)
out("hidden: a NeverSecret spell's cooldown is fully readable", not issecretvalue(nv.startTime) and nv.duration == 8 and not issecretvalue(nv.modRate))
-- duration objects
local d = C_Spell.GetSpellCooldownDuration(9201)
out("hidden: the duration object itself is readable and says HasSecretValues() true", d ~= nil and not issecretvalue(d) and d:HasSecretValues() == true)
local rem = d:GetRemainingDuration()
out("hidden: its time getters answer hidden numbers (GetRemainingDuration, GetTotalDuration, GetEndTime, GetStartTime, GetElapsedDuration)",
  issecretvalue(rem) and issecretvalue(d:GetTotalDuration()) and issecretvalue(d:GetEndTime()) and issecretvalue(d:GetStartTime()) and issecretvalue(d:GetElapsedDuration())
  and S.reveal(d:GetTotalDuration()) == 30 and S.reveal(rem) == 30)
out("hidden: IsZero, HasExpired and IsActive stay readable booleans (false, false, true)", d:IsZero() == false and d:HasExpired() == false and d:IsActive() == true
  and not issecretvalue(d:IsZero()) and not issecretvalue(d:HasExpired()) and not issecretvalue(d:IsActive()))
local z = C_Spell.GetSpellCooldownDuration(9299)
out("hidden: a spell not on cooldown gives a zero-span object (IsZero true, HasExpired true, IsActive false)", z ~= nil and z:IsZero() == true and z:HasExpired() == true
  and z:IsActive() == false and S.reveal(z:GetTotalDuration()) == 0)
local zc = C_Spell.GetSpellChargeDuration(9203)
out("hidden: at max charges GetSpellChargeDuration gives a zero-span object", zc ~= nil and zc:IsZero() == true and zc:HasExpired() == true)
-- the charge read still names the last recharge's times at max charges (a reader may answer so): the object stays zero-span
local GC0 = C_Spell.GetSpellCharges
C_Spell.GetSpellCharges = function() return { currentCharges = S.new(2), maxCharges = 2, cooldownStartTime = S.new(W.now - 1), cooldownDuration = S.new(12),
  chargeModRate = S.new(1), isActive = false } end
local zc2 = C_Spell.GetSpellChargeDuration(9203)
C_Spell.GetSpellCharges = GC0
out("hidden: ... also when the charge read still names the last recharge's times (zero-span at max, confirmed)", zc2 ~= nil and zc2:IsZero() == true
  and zc2:HasSecretValues() == true)
local rc = C_Spell.GetSpellChargeDuration(9202)
out("hidden: a recharging spell's charge object counts its recharge (12 s), times hidden", rc ~= nil and rc:IsZero() == false and rc:HasSecretValues() == true
  and S.reveal(rc:GetTotalDuration()) == 12)
W.setCooldown(9205, W.now, 1.5, { isOnGCD = true })
out("hidden: only the global cooldown running and ignoreGCD true: a zero-span object", C_Spell.GetSpellCooldownDuration(9205, true):IsZero() == true
  and C_Spell.GetSpellCooldownDuration(9205, false):IsZero() == false)
local cp = d:Copy()
out("hidden: Copy keeps the object readable and its values hidden", not issecretvalue(cp) and cp:HasSecretValues() == true and issecretvalue(cp:GetRemainingDuration()))
W.leaveCombat()
local dr = C_Spell.GetSpellCooldownDuration(9201)
out("readable: the object says HasSecretValues() false and its times read in the clear", dr:HasSecretValues() == false and not issecretvalue(dr:GetRemainingDuration())
  and dr:GetTotalDuration() == 30)
-- a Cooldown widget fed the object runs out: OnCooldownDone
W.enterCombat()
local w = CreateFrame("Cooldown", nil, UIParent)
local done = 0
w:SetScript("OnCooldownDone", function() done = done + 1 end)
w:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(9201), false)
W.tick(10, 1)
out("a Cooldown fed a hidden object does not run out before its end", done == 0)
W.tick(25, 1)
out("... and runs out once past it (OnCooldownDone once)", done == 1)
local w2 = CreateFrame("Cooldown", nil, UIParent); local done2 = 0
w2:SetScript("OnCooldownDone", function() done2 = done2 + 1 end)
w2:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(9299))
W.tick(1, 2)
out("a zero-span object with clearIfZero left at its default clears the widget: no OnCooldownDone", done2 == 0)
w2:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(9299), false)
W.tick(0.1, 1)
out("... with clearIfZero false it ends at once (INFERENCE, the reading Engine.lua relies on)", done2 == 1)
W.leaveCombat()
local made = C_DurationUtil.CreateDuration()
made:SetTimeFromStart(W.now, 10)
out("C_DurationUtil.CreateDuration makes a readable object that counts (SetTimeFromStart 10 s)", made:HasSecretValues() == false and made:GetTotalDuration() == 10 and made:IsActive() == true)
'''

# -------------------------------------------------------------------------------------------------------------------------------------
# T6: forbidden aura buttons
# -------------------------------------------------------------------------------------------------------------------------------------
T6_BUTTONS = r'''
local inInit = {}
local probe = addon([[
local P = {}
function P.make(log)
  local c = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
  c:SetSize(100, 40); c:SetPoint("CENTER")
  c:AddAuraGroup("g", "HELPFUL", { initializeFrame = function(b)
    local ok1 = pcall(b.SetIcon, b, 136243)
    local ok2 = pcall(b.SetSize, b, 30, 30)
    local ok3 = pcall(function() b:SetPoint("CENTER") end)
    log.init = ok1 and ok2 and ok3
  end })
  return c
end
function P.icon(b) b:SetIcon(136243) end                    -- line 13
function P.size(b) b:SetSize(28, 28) end
function P.pcallIcon(b) return pcall(b.SetIcon, b, 1) end
return P
]])()
W.enterCombat()
local log = {}
probe.make(log)
local e = W.auraButtons[#W.auraButtons]
local b = e and e.button
out("hidden: inside initializeFrame addon code may call the button (SetIcon, SetSize, SetPoint)", log.init == true)
local ok, err = pcall(probe.icon, b)
out("hidden: after initializeFrame, addon code calling a button method errors (forbidden object, at the calling line)", not ok and tostring(err):find(W.TEXT_FORBIDDEN, 1, true) ~= nil
  and tostring(err):find("probe.lua:13", 1, true) ~= nil and tostring(err):find("XayaUI_Probe", 1, true) ~= nil, err)
out("hidden: ... also when called through pcall(b.SetIcon, b)", probe.pcallIcon(b) == false)
out("hidden, before PLAYER_LOGIN (a UI reload): native widget calls (SetSize) are allowed", pcall(probe.size, b))
W.fire("PLAYER_LOGIN")
out("hidden, after PLAYER_LOGIN: native widget calls (SetSize) error too", not pcall(probe.size, b))
-- the stand-in's own sync and the gate's inspection are the game's own code
out("hidden: the stand-in's / the gate's own code shows and reads the button (untainted)", pcall(function() b:SetShown(true); return b:IsShown() end) and b:IsShown() == true)
W.leaveCombat()
out("readable again: the button is not forbidden (SetIcon and SetSize from addon code)", pcall(probe.icon, b) and pcall(probe.size, b))
W.startEncounter(1, "Boss", 0, 5)
out("hidden by an encounter (out of combat): forbidden again", not pcall(probe.icon, b))
W.endEncounter(1)
out("the container's own buttons list is the stand-in's (W.auraButtons), group kept", e ~= nil and e.group ~= nil and e.key == "g")
'''

# -------------------------------------------------------------------------------------------------------------------------------------
# T7: the API guard
# -------------------------------------------------------------------------------------------------------------------------------------
T7_GUARD = r'''
local hn, hs = S.new(0.5), S.new("hidden text")
local probe = addon([[
local P = {}
function P.call(f, m, ...) local r = f[m](f, ...); return r end   -- line 2 (no tail call: Lua 5.1 would drop this frame)
return P
]])()
local frames = {
  Button = CreateFrame("Button", nil, UIParent), Frame = CreateFrame("Frame", nil, UIParent), Slider = CreateFrame("Slider", nil, UIParent),
  StatusBar = CreateFrame("StatusBar", nil, UIParent), Cooldown = CreateFrame("Cooldown", nil, UIParent), EditBox = CreateFrame("EditBox", nil, UIParent),
}
frames.FontString = frames.Frame:CreateFontString(nil, "OVERLAY")
frames.Texture = frames.Frame:CreateTexture(nil, "ARTWORK")
local function try(kind, m, ...) local ok, e = pcall(probe.call, frames[kind], m, ...); return ok, tostring(e) end
local ARG = "Secret values are only allowed during untainted execution for this argument."
for _, case in ipairs({ { "Button", "SetText", hs }, { "Frame", "SetShown", hn }, { "Texture", "SetShown", hn }, { "Slider", "SetValue", hn },
    { "Slider", "SetMinMaxValues", hn, 1 }, { "Cooldown", "SetCooldown", hn, 5 }, { "FontString", "SetAlpha", hn }, { "EditBox", "SetText", hs } }) do
  local ok, e = try(case[1], case[2], case[3], case[4])
  out("a hidden value to " .. case[1] .. ":" .. case[2] .. " from addon code errors 'bad argument #1 ... untainted execution'", not ok
    and e:find("bad argument #1 to '" .. case[2] .. "'", 1, true) ~= nil and e:find(ARG, 1, true) ~= nil and e:find("(execution tainted by 'XayaUI_Probe')", 1, true) ~= nil
    and e:find("probe.lua:2", 1, true) ~= nil, e)
end
for _, case in ipairs({ { "FontString", "SetText", hs }, { "FontString", "SetText", hn }, { "StatusBar", "SetValue", hn }, { "StatusBar", "SetMinMaxValues", hn, hn },
    { "Frame", "SetAlpha", hn }, { "Texture", "SetAlpha", hn }, { "Texture", "SetVertexColor", hn, hn, hn } }) do
  local ok, e = try(case[1], case[2], case[3], case[4], case[5])
  out("a hidden number or string to " .. case[1] .. ":" .. case[2] .. " from addon code is taken (AllowedWhenTainted)", ok, e)
end
try("FontString", "SetText", hs)
out("... FontString:SetText keeps the hidden text it was given (the widget, not addon code, reads it)", rawequal(frames.FontString._text, hs) and S.reveal(frames.FontString._text) == "hidden text")
for _, case in ipairs({ { "StatusBar", "SetValue", hs }, { "Frame", "SetAlpha", hs }, { "StatusBar", "SetMinMaxValues", 0, hs } }) do
  local ok, e = try(case[1], case[2], case[3], case[4])
  local pos = case[4] ~= nil and 2 or 1
  out("a hidden STRING to a number parameter of " .. case[1] .. ":" .. case[2] .. " errors (patch 12.0.0 notes)", not ok and e:find("bad argument #" .. pos .. " to '" .. case[2] .. "'", 1, true) ~= nil
    and e:find("number conversion", 1, true) ~= nil, e)
end
local plainOK = select(1, try("Button", "SetText", "plain")) and select(1, try("Frame", "SetShown", true)) and select(1, try("Slider", "SetValue", 3))
  and select(1, try("Cooldown", "SetCooldown", W.now, 5)) and select(1, try("FontString", "SetAlpha", 0.5))
out("plain values pass every guarded method (no false alarm)", plainOK)
out("untainted code (the stand-in, the gate, a test) may hand a hidden value to Button:SetText", pcall(frames.Button.SetText, frames.Button, hs))
local okSz, eSz = pcall(frames.Frame.SetSize, frames.Frame, hn, hn)
out("... and a hidden size to Frame:SetSize: the stand-in's body converts natively (the game's C code), no error inside world.lua", okSz, eSz)
out("a duration object (readable) passes Cooldown:SetCooldownFromDurationObject", select(1, try("Cooldown", "SetCooldownFromDurationObject", C_Spell.GetSpellCooldownDuration(1))))
local quietBad = {}
for _, m in ipairs({ "SetCooldownUNIX", "SetCooldownDuration", "SetCooldownFromExpirationTime" }) do
  if frames.Cooldown[m] and select(1, try("Cooldown", m, hn, 5)) then quietBad[#quietBad + 1] = m end
end
out("documented Cooldown methods the stand-in does not implement are guarded too (SetCooldownUNIX, SetCooldownDuration, SetCooldownFromExpirationTime)", #quietBad == 0,
  table.concat(quietBad, ","))
local GM = W.GUARDED_METHODS or {}
out("only methods that hand the game a value are guarded (SetShown, SetText, SetValue yes; queries such as GetWidth, IsShown no: stated limit)",
  GM.SetShown == true and GM.SetText == true and GM.SetValue == true and GM.GetWidth == nil and GM.IsShown == nil)
local sb, sl = W.methodRule("StatusBar", "SetValue"), W.methodRule("Slider", "SetValue")
out("the rules are per object type: StatusBar:SetValue AllowedWhenTainted, Slider:SetValue AllowedWhenUntainted", sb and sb[1] == "tainted" and sl and sl[1] == "untainted")
local fa, fsa = W.methodRule("Frame", "SetAlpha"), W.methodRule("FontString", "SetAlpha")
out("... Frame:SetAlpha AllowedWhenTainted (SimpleFrameAPI), FontString:SetAlpha AllowedWhenUntainted (SimpleFontAPI answers first)", fa and fa[1] == "tainted" and fsa and fsa[1] == "untainted")
'''


# -------------------------------------------------------------------------------------------------------------------------------------
# TC: what the stand-in bills to addon code (V27 / V33; spec 3.1 and 4.4.5: the stand-in's own work is host-side, not billed)
# -------------------------------------------------------------------------------------------------------------------------------------
# Instructions counted by a count hook on the playing thread (as the gate counts), 1,000 calls from an addon chunk, per call. Every bound
# is read against a reference measured in the same loop (a host-side C-like call, a raw function field, an unguarded twin), so the loop's
# own shape cancels out. Stand-in numbers, not WoW CPU.
TC_COST = r'''
local probe = addon([[
local P = {}
function P.run(n, f, a, b, c) for i = 1, n do f(a, b, c) end end
function P.m(n, o, m, a, b) for i = 1, n do o[m](o, a, b) end end
return P
]])()
local count = 0
local function hook() count = count + 1 end
local function per(fn, ...) count = 0; debug.sethook(hook, "", 1); fn(1000, ...); debug.sethook(); return count / 1000 end
local hn, hs = S.new(0.5), S.new("hidden text")
local ref = per(probe.run, issecretvalue, 1)                   -- a C-like call (host-side issecretvalue): the call alone
local fr = CreateFrame("Frame", nil, UIParent)
local fs = fr:CreateFontString(nil, "OVERLAY")
local sb = CreateFrame("StatusBar", nil, UIParent)
-- the guard decides host-side: a hidden value it allows costs exactly what a plain one does
W.enterCombat()
for _, c in ipairs({ { fs, "SetText", "plain", hs, "FontString:SetText" }, { sb, "SetValue", 3, hn, "StatusBar:SetValue" }, { fr, "SetAlpha", 0.5, hn, "Frame:SetAlpha" } }) do
  local plain, hidden = per(probe.m, c[1], c[2], c[3]), per(probe.m, c[1], c[2], c[4])
  out("cost: " .. c[5] .. " with a hidden value it allows costs what a plain value costs (the guard's decision is host-side)",
    math.abs(hidden - plain) <= 0.5, string.format("plain %.1f, hidden %.1f per call", plain, hidden))
end
-- the guard's own cost on a plain value: one Lua wrapper (12 instructions: the verdict call, its test, the tail call to the body) and the
-- host-side verdict (0), so at most 15 over the unguarded body called directly (the probe's o[m] lookup is 1 more); a Lua-side decision
-- (the pre-repair guard's methodRule and refusal) would add 30 and more
local GB = W.GUARD_BODY or {}
for _, c in ipairs({ { fs, "SetText", "plain", "FontString:SetText" }, { sb, "SetValue", 3, "StatusBar:SetValue" } }) do
  local guarded = per(probe.m, c[1], c[2], c[3])
  local body = GB[c[2]] and per(probe.run, GB[c[2]], c[1], c[3])
  out("cost: " .. c[4] .. " with a plain value: the guard adds at most 15 instructions to the stand-in's body", body ~= nil and guarded - body <= 15,
    string.format("guarded %.1f, body %s per call", guarded, body and string.format("%.1f", body) or "(W.GUARD_BODY missing)"))
end
-- the stand-in's C-API readers run host-side: the caller pays the call and the 5-instruction shell, whatever the body does
W.setCooldown(9601, W.now, 30); W.setCharges(9602, 1, 2, W.now, 12)
local a = W.addAura("player", { spellId = 9603, duration = 20 }, true)
local d = C_Spell.GetSpellCooldownDuration(9601)
local reads = {
  { "C_Spell.GetSpellCooldown (hidden)", C_Spell.GetSpellCooldown, 9601 }, { "C_Spell.GetSpellCharges (hidden)", C_Spell.GetSpellCharges, 9602 },
  { "C_Spell.GetSpellCooldownDuration (hidden)", C_Spell.GetSpellCooldownDuration, 9601 },
  { "C_Spell.GetSpellChargeDuration (hidden)", C_Spell.GetSpellChargeDuration, 9602 },
  { "C_Spell.GetSpellMaxCumulativeAuraApplications (hidden)", C_Spell.GetSpellMaxCumulativeAuraApplications, 9603 },
  { "C_UnitAuras.GetPlayerAuraBySpellID (hidden: nil)", C_UnitAuras.GetPlayerAuraBySpellID, 9603 },
  { "duration object GetRemainingDuration (hidden)", d.GetRemainingDuration, d },
}
for _, r in ipairs(reads) do
  local c = per(probe.run, r[2], r[3])
  out("cost: " .. r[1] .. " bills the call and the shell only (at most 6 over a C-like call)", c - ref <= 6, string.format("%.1f against %.1f per call", c, ref))
end
W.leaveCombat()
local readsClear = {
  { "C_Spell.GetSpellCooldown (readable)", C_Spell.GetSpellCooldown, 9601 },
  { "C_UnitAuras.GetAuraDataByAuraInstanceID (readable; behind the Lua aura-access check)", C_UnitAuras.GetAuraDataByAuraInstanceID, "player", a.auraInstanceID },
  { "C_UnitAuras.GetAuraDataByIndex (readable; behind the Lua aura-access check)", C_UnitAuras.GetAuraDataByIndex, "player", 1 },
}
for _, r in ipairs(readsClear) do
  local c = per(probe.run, r[2], r[3], r[4])
  out("cost: " .. r[1] .. " at most 12 over a C-like call", c - ref <= 12, string.format("%.1f against %.1f per call", c, ref))
end
-- a reader that raises (a stand-in fault, or a reader a test replaced) raises at the caller's line, and the host-side helper survives
local GC0 = C_Spell.GetSpellCharges
C_Spell.GetSpellCharges = function() error("boom") end
local ok, e = pcall(addon("return function() local d = C_Spell.GetSpellChargeDuration(9602); return d end   -- line 1")())
C_Spell.GetSpellCharges = GC0
out("a raising reader body comes back as the stand-in's fault, raised at the addon's line", not ok and tostring(e):find("internal fault in the stand-in's C_Spell.GetSpellChargeDuration", 1, true) ~= nil
  and tostring(e):find("probe.lua:1", 1, true) ~= nil, e)
local d2 = C_Spell.GetSpellChargeDuration(9602)
out("... and the reader works again afterwards (its helper thread did not end)", d2 ~= nil and d2:IsZero() == false, S.health())
-- aura buttons cost nothing extra while auras are readable: a raw method field and the widget lookup, as before round 11b
local c = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
c:AddAuraGroup("g", "HELPFUL", { initializeFrame = function() end })
local b = W.auraButtons[#W.auraButtons].button
local twin = { SetIcon = function() end }                       -- a raw function field: what a readable button's own method must cost
local plainFrame = CreateFrame("Button", nil, UIParent)          -- an ordinary widget: what a readable button's native method must cost
local function buttonCosts(when)
  local icon, rawc = per(probe.m, b, "SetIcon", 1), per(probe.m, twin, "SetIcon", 1)
  local size, plainSize = per(probe.m, b, "SetSize", 30, 30), per(probe.m, plainFrame, "SetSize", 30, 30)
  out("cost (" .. when .. "): an aura button's SetIcon costs a raw method call, its SetSize an ordinary widget's (no lookup hop)",
    math.abs(icon - rawc) <= 0.5 and math.abs(size - plainSize) <= 0.5, string.format("SetIcon %.1f / raw %.1f, SetSize %.1f / widget %.1f", icon, rawc, size, plainSize))
end
buttonCosts("readable, made while readable")
W.enterCombat()
out("... while hidden the same button refuses addon code (it changed form on the flip)", not pcall(probe.m, 1, b, "SetIcon", 1))
local c2 = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
c2:AddAuraGroup("g2", "HELPFUL", { initializeFrame = function() end })
local b2 = W.auraButtons[#W.auraButtons].button
out("... and a button made while hidden refuses it too", not pcall(probe.m, 1, b2, "SetIcon", 1))
W.leaveCombat()
buttonCosts("readable again after a hidden spell")
b = b2
buttonCosts("readable, a button made while hidden")
'''

# -------------------------------------------------------------------------------------------------------------------------------------
# W: through the loader (every addon play): an addon file is addon code, and a forbidden payload kept in saved data does not break logout
# -------------------------------------------------------------------------------------------------------------------------------------
PROBE_TOC = "## Interface: 120105\n## Title: XayaUI Restrict Probe\n## SavedVariables: XRP_DB\nprobe.lua\n"
PROBE_LUA = r"""
local f = CreateFrame("Frame")
f:RegisterEvent("UNIT_AURA")
f:SetScript("OnEvent", function(_, _, unit, info)
  XRP_DB = XRP_DB or {}
  XRP_DB.last = info                                  -- keeps the payload (hidden: shape C in this play)
  XRP_DB.n = C_Spell.GetSpellCooldown(61304).duration -- a hidden number while cooldowns are hidden
  XRP_DB.plain = 7
  f:SetShown(XRP_DB.n)                                -- line 9: a hidden value to SetShown (refused: AllowedWhenUntainted)
end)
"""
W_LOADER = r'''
W.fire("PLAYER_LOGIN")
W.payloadShape = "C"
W.enterCombat()
W.addAura("player", { spellId = 9301 })
local refused
for _, e in ipairs(W.errors) do if e:find("Interface/AddOns/XayaUI_RestrictProbe/probe.lua:9", 1, true) and e:find("SetShown", 1, true) then refused = e end end
out("an addon file the loader ran is addon code: its SetShown with a hidden value is refused at its own line (as a Lua error the game reports)",
  refused ~= nil and refused:find("(execution tainted by 'XayaUI_RestrictProbe')", 1, true) ~= nil, refused or W.errors[#W.errors])
out("... the payload it kept is the forbidden table (shape C)", S.shape(rawget(_G, "XRP_DB") and XRP_DB.last) == "C")
W.leaveCombat()
local ok, saved, issues = pcall(LD.logout)
local db = ok and saved and saved.XayaUI_RestrictProbe and saved.XayaUI_RestrictProbe.XRP_DB
out("logout with a forbidden payload and a hidden number in saved data: no Lua error, both written as nil, the plain value kept, no save issue",
  ok and db ~= nil and db.last == nil and db.n == nil and db.plain == 7 and #issues == 0, ok and (#issues .. " issues") or saved)
'''


def play_loader(title, body):
    """A stand-in session with the loader and the probe addon (a scratch folder made here), then body (Lua with out(), LD = the loader)."""
    import tempfile, shutil
    tmp = tempfile.mkdtemp(prefix="xui-restrict-")
    try:
        d = os.path.join(tmp, "XayaUI_RestrictProbe")
        os.makedirs(d)
        open(os.path.join(d, "XayaUI_RestrictProbe.toc"), "w").write(PROBE_TOC)
        open(os.path.join(d, "probe.lua"), "w").write(PROBE_LUA)
        L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
        api = H.to_lua(L, API_SLIM)
        try:
            W = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(STANDIN, "world.lua"), api)
            opts = L.eval("function(dir) return { folders = { XayaUI_RestrictProbe = dir }, saved = {} } end")(d)
            LD = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(STANDIN, "loader.lua"), W, opts)
        except Exception as e:
            check("%s: the stand-in world and loader load" % title, False, e)
            return
        L.globals().W, L.globals().LD = W, LD
        L.globals().SECRET_PATH = os.path.join(STANDIN, "secret.lua")
        LD.startup()
        runner = L.eval("function(src) local f = assert(loadstring(src, '=fix_r11_restrict')); local ok, r = pcall(f); return ok, r end")
        src = PRELUDE + "\nlocal okBody, errBody = pcall(function()\n" + body + "\nend)\nif not okBody then out('section ran to its end', false, errBody) end\nreturn R"
        ok, res = runner(src)
        if not ok:
            check("%s: section ran to its end" % title, False, res)
            return
        for i in range(1, len(res) + 1):
            check("%s: %s" % (title, res[i].name), res[i].ok, res[i].detail)
        if len(res) == 0:
            check("%s: section reported checks" % title, False)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def widgets_md_trap():
    """The guard's rule for StatusBar:SetValue must not be what widgets.md shows for SetValue (one entry per name: the Slider's flag)."""
    p = os.path.join(ROOT, "docs", "reference", "api", "widgets.md")
    if not os.path.isfile(p):
        return None
    for line in open(p, encoding="utf-8"):
        if line.startswith("- `SetValue("):
            return line
    return None


# -------------------------------------------------------------------------------------------------------------------------------------
# T11: combat order in the files of the spec's combat table
# -------------------------------------------------------------------------------------------------------------------------------------
T11_USE_DRIVER = [os.path.join("harness", "scenario.lua"), "fix_r7_engine_alloc_run.py"]
T11_KEPT = ["fix_r4_lock_run.py", "element_menu_run.py", "harness_lockdown_run.py", "info_pane_run.py", "mover_session_run.py", "options_open_cost.lua"]
TOKEN = re.compile(r'W\.combat\s*=\s*(true|false)\b|W\.enterCombat\(\)|W\.leaveCombat\(\)|fire\(\s*"PLAYER_REGEN_DISABLED"')


def regen_while_locked(path):
    """Read a file in order: the lines that fire PLAYER_REGEN_DISABLED while the file holds W.combat = true (Lua comments skipped)."""
    bad, combat = [], False
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        code = line.split("--", 1)[0]
        for m in TOKEN.finditer(code):
            t = m.group(0)
            if t.startswith("W.combat"):
                combat = m.group(1) == "true"
            elif t == "W.enterCombat()":
                combat = True
            elif t == "W.leaveCombat()":
                combat = False
            elif combat:
                bad.append(n)
    return bad


def main():
    play("T3 combat", T3_COMBAT)
    play("T3 key", T3_KEY)
    play("T3 encounter", T3_ENCOUNTER)
    play("T3 secrecy", T3_SECRECY)
    play("T3 aura IDs", T3_IDS)
    play("T4 reads", T4_READS)
    play("T4 payloads", T4_PAYLOAD)
    play("T5 cooldowns", T5_COOLDOWNS)
    play("T6 aura buttons", T6_BUTTONS)
    play("T7 API guard", T7_GUARD)
    play("TC stand-in cost", TC_COST)
    play_loader("W loader", W_LOADER)
    line = widgets_md_trap()
    check("T7 API guard: widgets.md lists one SetValue (the Slider's AllowedWhenUntainted), which the guard does not follow for a StatusBar",
          line is not None and "AllowedWhenUntainted" in line, (line or "").strip()[:160])
    for rel in T11_USE_DRIVER:
        p = os.path.join(TESTS, rel)
        if not os.path.isfile(p):
            print("MISSING INPUT: %s" % p)
            check("T11: %s exists" % rel, False)
            continue
        src = open(p, encoding="utf-8").read()
        uses = "W.enterCombat()" in src and "W.leaveCombat()" in src
        check("T11: %s plays combat with W.enterCombat / W.leaveCombat (PLAYER_REGEN_DISABLED before the lockdown)" % rel, uses)
        bad = regen_while_locked(p)
        check("T11: %s never fires PLAYER_REGEN_DISABLED while it holds W.combat = true" % rel, not bad, bad)
    for rel in T11_KEPT:
        p = os.path.join(TESTS, rel)
        if not os.path.isfile(p):
            print("MISSING INPUT: %s" % p)
            check("T11: %s exists" % rel, False)
            continue
        bad = regen_while_locked(p)
        check("T11: kept file %s never fires PLAYER_REGEN_DISABLED while it holds W.combat = true" % rel, not bad, bad)
    print("UNVERIFIED IN GAME: the stand-in (tests/harness/world.lua) is a mock; every event order, the payload shapes, the forbidden-button and "
          "aura-access texts and the duration-object booleans are INFERENCE (build spec section 8 has the in-game steps).")
    print("%d checks, %d failed" % (checks, fails))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
