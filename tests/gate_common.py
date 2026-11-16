#!/usr/bin/env python3
"""Shared scenario for the V27 release-gate tests (tests/gate_mouse_run.py, tests/gate_keyboard_run.py, tests/gate_performance_run.py).

V27 (Xaya, 2026-11-10, REQUEST-LOG A23 SD-28 / SD-29, her words): "Conditions every single build on main has to pass: * nothing impacts
mouse ability to interact with (click, toggle, use, etc) in-game objects, buttons, or screen panning once xui options window is closed
* nothing impacts keyboard ability to interact with the game once xui options window is closed [...] * every single element of the
functionality has been built to run optimally in a high-cost gaming environment. This means zero code loops, zero unnecessary complex
calculations, zero floating numbers, nothing anything that demands cpu or memory resources beyond what is ABSOLUTELY necessary without
any other workarounds, and no runaway functions." Her answers: loops "No running loops", numbers "Whole-pixel / no float math",
mouse "Hover only, clicks pass".

The scenario (the same for the three gates; each gate reads the part it judges):
  session A  a fresh install logs in and a realistic profile of about 300 rules is made through XayaUI's own functions (buff rules
             with icon displays and duration text, cooldown rules, bar cues, sound cues, icon cues, game-played sounds that follow
             "Only when mounted" / "Only when not mounted", hover-tooltip displays, target-debuff rules, rules that load only in
             combat / in a group; rules with a talent requirement (round 7); static groups, dynamic groups and a nested group); she
             logs out (saved variables written).
  session B  the next login on what session A saved (as the game does: the profile is there at ADDON_LOADED), then:
             the settings window opens and is used (rules selected with a click, Ctrl+click and hover; the rule search typed in;
             a group's slider dragged; a rule's right-click menu and a dropdown list opened), the mover (/xui unlock) opened and
             closed, the window closed; the minimap button's list opened and closed with a click elsewhere;
             then the busiest case for 60 simulated seconds in three equal 20-second cycles (30 frames a second): a fight with
             UNIT_AURA (player and target), SPELL_UPDATE_COOLDOWN, SPELL_UPDATE_CHARGES and ACTIONBAR_UPDATE_COOLDOWN / _STATE /
             _USABLE storms every frame, auras gained and lost, spells cast, a group joined and left, a mount and a dismount,
             a loading screen; (round 8) movement started and stopped every half second, a rune change three times a second, a totem
             every 3 s and a stun (loss of control added, then updated) every 5 s in the fight; then 30 seconds idle out of combat
             with nothing on screen changing.
(round 9) Also: every fight runs from the trash into a boss (ENCOUNTER_START 8 s in, ENCOUNTER_END 14 s in) and its combat end and the
second after it are a measured segment of their own ("end N", SD-77); the profile has target debuffs that must be absent, displays with
an out-of-combat opacity of 0.5 and boss rules (SD-77 conditions 2 and 3), and six effect displays and a bar cue that XayaUI draws (SD-79);
before the close the effect displays are previewed and the mover is opened, at 144 frames a second; after the three cycles, an effects
part at 144 frames a second plays the effect displays out of combat until their buffs run out.
Four plays per variant (round 9): the measured play (instructions, allocation, budget; it counts no call: SD-80), the tree play (call
trees for the pace per re-check pass, and the call counts), the draw play (what is drawn after each load-fact change against a full
re-check, SD-77) and the memory play (Lua memory with nothing of the gate's kept: the growth per cycle is the addons' own).
Two variants (round 8): "default" (Settings > Debugging > Advanced Debugging off; XayaUI_Debug switched on in the AddOns list and not
loaded, V34) and "debug" (Advanced Debugging saved on, as every install from before round 7 has it: XayaUI_Debug loaded and measured).
The window stays closed from the close onward: every frame the gates judge is "after the window is closed".
V33 (round 7): every handler's Lua instructions are also summed per addon and per frame drawn, in segments "fight N" (from combat start,
its first second included, to the fight's last frame), "out N" (the rest of cycle N) and "idle"; tests/gate_performance_run.py judges
them against the work budget calibrated on her reading (the same scenario played on origin/main ad60a051: v33_baseline below).
Not played yet (TODO, round 7, engine-b's game-driven timing; SD-60): what the game hides the moment of in combat (a cooldown whose end
is secret, countdown seconds read from a secret duration, the range to a focus / mouseover / pet, a row type the engine does not know).
The stand-in has no secret cooldowns, no duration object that counts down, no OnCooldownDone and no range events, so these need the
stand-in to drive whatever route that unit builds; until then the 0.2 s re-check of such rules is not played and not measured here.

Stand-in limits (V25: a passing gate is not proof of in-game behavior; findings are UNVERIFIED IN GAME):
  * the game's mouse model is added here on top of tests/harness/world.lua: EnableMouse sets clicks and motion together;
    SetMouseClickEnabled / SetMouseMotionEnabled / EnableMouseMotion set one (docs/reference/api/widgets.md:283-284, 111);
    IsMouseEnabled is true when either is on (INFERENCE); SetPropagateMouseClicks(true) passes clicks on (widgets.md:296);
    a Button, CheckButton, EditBox or Slider takes clicks until told not to (INFERENCE: not documented; Blizzard's and every addon's
    buttons work without EnableMouse). EnableMouseWheel(true) is recorded (a shown frame that takes the wheel stops camera zoom; INFERENCE).
  * the game's aura and cooldown reads (C_UnitAuras.GetUnitAuraBySpellID, GetPlayerAuraBySpellID, GetAuraDataByAuraInstanceID,
    C_Spell.GetSpellCooldown) answer from the scenario's own list of active auras and cooldowns; Blizzard's aura container (the combat
    engine's displays) is a minimal stand-in that accepts the documented calls and draws nothing.
  * allocations are measured with collectgarbage("count") around each XayaUI handler (event, OnUpdate, timer) with the collector
    stopped; allocations made inside the stand-in's own widget methods (it stores points and colors in Lua tables; the game does not),
    by the stand-in's C_Timer (its timer record, handle and wrapper closures; round 8, SD-68) and by the gate's own measuring are taken
    out, each exactly once (round 8: nested measuring steps were taken out two or three times before). A timer call that hands C_Timer
    a new closure each time is the addon's own garbage and is reported by the guard (tests/gate_performance_run.py P4, SD-68).
    Instructions (V33) still include the stand-in's and the gate's own Lua (a few hundred per timer call or loop note; conservative).
Run one gate: python3 tests/gate_<name>_run.py   (Lua 5.1 via lupa)."""
import hashlib, inspect, json, os, re, sys, tempfile, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

ROOT = os.path.dirname(HERE)
ADDONS = ("XayaUI", "XayaUI_Rules", "XayaUI_Options")
# (round 8; round 7 review: the gate never loaded XayaUI_Debug) the debug tools' load-on-demand addon, switched on in the game's AddOns
# list as on every install; core loads it at login only while Settings > Debugging > Advanced Debugging (CueRulesDB.ui.advancedDebug)
# is on (XayaUI/DebugRecord.lua, V34). The gate plays two variants of the same scenario:
#   "default"  Advanced Debugging off (a new install): XayaUI_Debug must not be loaded (V34: off means not read);
#   "debug"    Advanced Debugging on (every install from before round 7 saved it on, hers included; SD-64): XayaUI_Debug loaded and measured.
DEBUG_ADDON = "XayaUI_Debug"
VARIANTS = ("default", "debug")

# ---------------------------------------------------------------------------------------------------------------------------------
# the game's aura container (Blizzard_AuraContainer) and the aura / cooldown reads: installed in both sessions before the addons load
# ---------------------------------------------------------------------------------------------------------------------------------
GAME_LUA = r'''
return function(W)
local G = { auras = {}, byInstance = {}, cds = {}, mounted = false, group = false, raid = false, nextInstance = 100, buttons = {}, known = {} }
-- enums the combat engine reads (Blizzard_AuraContainerUtil.lua / AnchorUtil; values as in tests/aura_display_run.py)
AnchorUtil = AnchorUtil or {}
AnchorUtil.FlowLayoutAxis = AnchorUtil.FlowLayoutAxis or { Horizontal = 0, Vertical = 1 }
AnchorUtil.FlowDirection = AnchorUtil.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }
AuraContainerSortMethod = AuraContainerSortMethod or { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3, Expiration = 4, ExpirationOnly = 5, Name = 6, NameOnly = 7, AuraInstanceIDOnly = 8 }
AuraContainerSortDirection = AuraContainerSortDirection or { Normal = 0, Reverse = 1 }
CustomAuraContainerAuraProcessingPolicy = CustomAuraContainerAuraProcessingPolicy or { None = 0, ProcessAura = 1 }
local realCreate = CreateFrame
local function noop() end
CreateFrame = function(kind, name, parent, template, id)
  local f = realCreate(kind, name, parent, template, id)
  if template == "CustomAuraContainerTemplate" then
    rawset(f, "groups", {})
    for _, m in ipairs({ "SetUnit", "UpdateAllAuras", "SetAuraProcessingPolicy", "SetAuraGroupLayout", "SetAuraGroupSortMethod", "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection",
        "SetFlowLayoutMaximumLineSize", "RemoveAuraGroup", "ClearAuraGroups" }) do rawset(f, m, noop) end
    rawset(f, "SetAuraGroupCandidateFilters", function(self, key, cf) local o = self.groups[key]; if o then o.candidateFilters = cf end end)
    rawset(f, "SetAuraGroupEnabled", function(self, key, on) local o = self.groups[key]; if o then o.xuiOff = not on end end)
    rawset(f, "AddAuraGroup", function(self, key, filter, o)
      self.groups[key] = o
      if type(o) == "table" and type(o.initializeFrame) == "function" then
        -- Blizzard's container makes its aura buttons itself and shows one while a matching aura is up (G.syncContainers)
        local b = realCreate("Button", nil, self)
        b:SetSize(36, 36); b:SetPoint("CENTER", self, "CENTER", 0, 0); b:Hide(); rawset(b, "_blizzard", true)
        for _, m in ipairs({ "SetIcon", "SetDurationCooldown", "SetDurationText", "SetDurationBar", "SetApplicationCount", "SetApplicationBar",
            "SetSpellName", "AddDispelTypeTexture", "ApplyDispelTypeTexture" }) do rawset(b, m, noop) end
        pcall(o.initializeFrame, b)
        G.buttons[#G.buttons + 1] = { button = b, opts = o, container = self }
      end
    end)
  end
  return f
end
-- the auras the player has right now: [spellID] = aura data (the game's AuraData fields the rules read). Like the game, every read
-- hands back a new table (the game builds the AuraData table for each call).
local function copy(a) if not a then return nil end; local t = {}; for k, v in pairs(a) do t[k] = v end; return t end
local function auraFor(id) return copy(G.auras[id]) end
-- Blizzard's container: an aura button shows while an aura its group asks for is up (the game's secure code; not XayaUI's work)
function G.syncContainers()
  for _, e in ipairs(G.buttons) do
    local ids = not e.opts.xuiOff and e.opts.candidateFilters and e.opts.candidateFilters.includeSpellIDs
    local up = false
    -- (the engine passes a set: [spellID] = true; Blizzard_AuraContainerUtil.lua also takes a list)
    if type(ids) == "table" then for k, v in pairs(ids) do if G.auras[k] or (type(v) == "number" and G.auras[v]) then up = true; break end end end
    e.button:SetShown(up and e.container:IsVisible() and #e.container._pts > 0)
  end
end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit == "player" then return auraFor(id) end return nil end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return auraFor(id) end
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, iid) return copy(G.byInstance[iid]) end
C_UnitAuras.GetAuraDataBySpellName = function() return nil end
-- the target's debuffs cast by the player ("HARMFUL|PLAYER"): a list the scenario keeps (G.targetDebuffs)
G.targetDebuffs, G.target = {}, false
C_UnitAuras.GetUnitAuras = function(unit, filter) if unit == "target" and G.target then return G.targetDebuffs end return {} end
local UE0 = UnitExists
UnitExists = function(u) if u == "target" then return G.target end return UE0(u) end
C_UnitAuras.AddAuraSound = function() G.nextInstance = G.nextInstance + 1; return G.nextInstance end
C_UnitAuras.RemoveAuraSound = function() end
-- a spell's cooldown (SpellCooldownInfo): a new table per call, as the game returns
C_Spell.GetSpellCooldown = function(id)
  local c = G.cds[tonumber(id) or 0]
  if c and W.now < c.startTime + c.duration then
    return { startTime = c.startTime, duration = c.duration, isEnabled = true, modRate = 1, isActive = true, isOnGCD = false }
  end
  return { startTime = 0, duration = 0, isEnabled = true, modRate = 1, isActive = false, isOnGCD = false }
end
-- the profile's cooldown spells are known (the spellbook)
C_SpellBook = C_SpellBook or {}
local KN0 = C_SpellBook.IsSpellKnownOrInSpellBook
C_SpellBook.IsSpellKnownOrInSpellBook = function(id, bank, ov) if G.known[id] then return true end if KN0 then return KN0(id, bank, ov) end return false end
local IPS0 = IsPlayerSpell
IsPlayerSpell = function(id) if G.known[id] then return true end if IPS0 then return IPS0(id) end return false end
for i = 1, 81 do G.known[400000 + i] = true end   -- (round 9: 61-81 are the out-of-combat opacity, boss and effect rules' spells, never cast)
for i = 1, 4 do G.known[450000 + i] = true end   -- the talents the profile's talent requirements name (PROFILE_LUA 6b)
IsMounted = function() return G.mounted end
-- (round 9, SD-77 condition 3) a boss encounter: C_InstanceEncounter.IsEncounterInProgress (docs/reference/api/namespaces.md:2667, no
-- secrecy flag) answers from the scenario's G.encounter, set with ENCOUNTER_START / ENCOUNTER_END (events.md:560, :562)
G.encounter = false
C_InstanceEncounter = C_InstanceEncounter or {}
C_InstanceEncounter.IsEncounterInProgress = function() return G.encounter end
IsInGroup = function() return G.group end
IsInRaid = function() return G.raid end
GetNumGroupMembers = function() return G.group and (G.raid and 20 or 5) or 0 end
UnitInParty = function(u) return G.group and u ~= nil end
function G.gain(id, dur, unit)
  G.nextInstance = G.nextInstance + 1
  local a = { auraInstanceID = G.nextInstance, spellId = id, name = "Spell " .. id, icon = 136243, applications = 1, duration = dur,
    expirationTime = W.now + dur, isHelpful = (unit or "player") == "player", sourceUnit = "player", isFromPlayerOrPlayerPet = true }
  G.auras[id] = a; G.byInstance[a.auraInstanceID] = a
  return a
end
function G.lose(id)
  local a = G.auras[id]
  if a then G.auras[id] = nil; G.byInstance[a.auraInstanceID] = nil end
  return a
end
function G.cast(id, dur) G.cds[id] = { startTime = W.now, duration = dur } end
function G.clear() G.auras, G.byInstance, G.cds = {}, {}, {} end
return G
end
'''

# ---------------------------------------------------------------------------------------------------------------------------------
# session A: the profile (about 300 rules), made through XayaUI's own functions, then saved by a logout
# ---------------------------------------------------------------------------------------------------------------------------------
PROFILE_LUA = r'''
return function(W, L, G)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
assert(ns and ns.NewRule and ns.rules and ns.folders, "XayaUI Rules did not load")
math.randomseed(27)
local SOUND = "Interface\\AddOns\\XayaUI\\Media\\Audio\\CC0\\Kenney\\bong_001.ogg"
local function folder(name, parent, dynamic)
  local f = ns.NewFolder(name, parent)
  if dynamic then f.cType = "dynamic" end
  return f
end
local statics, dyns = {}, {}
for i = 1, 6 do statics[i] = folder("Static " .. i) end
for i = 1, 5 do dyns[i] = folder("Dynamic " .. i, nil, true) end
local nested = folder("Nested dynamic", statics[1].id, true)
dyns[#dyns + 1] = nested
local function rule(name, f)
  local r = ns.NewRule(); r.name = name; r.enabled = true
  f(r)
  ns.NormalizeRule(r)
  ns.rules[#ns.rules + 1] = r
  return r
end
local function display(r, w, h)
  local v = r.visual
  v.enabled, v.kind, v.w, v.h = true, "spellicon", w or 40, h or 40
  v.text.enabled = true
end
local made = { buff = 0, cd = 0, bar = 0, soundCue = 0, iconCue = 0, game = 0, hover = 0, debuff = 0, talent = 0, absent = 0, ooc = 0, boss = 0, fx = 0 }
-- 1. buff rules with an icon and its duration text: 36 in dynamic groups (the combat engine draws them), 30 in static groups
for i = 1, 66 do
  rule("Buff " .. i, function(r)
    r.useBuff, r.buffID, r.buffState = true, 300000 + i, "present"
    display(r, 36, 36); r.visual.trigger = "buffActive"
    r.folder = (i <= 36) and dyns[(i - 1) % #dyns + 1].id or statics[(i - 1) % #statics + 1].id
    if i % 9 == 0 then r.load.combat = "yes" end
    if i % 11 == 0 then r.load.group = "yes" end
  end)
  made.buff = made.buff + 1
end
-- 2. cooldown rules: an icon while the spell is ready, plus a sound cue
for i = 1, 40 do
  local r = rule("Cooldown " .. i, function(r)
    r.useCooldown, r.spellID, r.cdState = true, 400000 + i, "ready"
    display(r, 44, 44); r.visual.trigger = "condition"; r.visual.desatOnCD = true
    r.folder = statics[(i - 1) % #statics + 1].id
    if i % 7 == 0 then r.load.mounted = "no" end
  end)
  made.cd = made.cd + 1
  local c = ns.NewCueRule(r, "sound"); if c then c.sound.source, c.sound.value = "file", SOUND; made.soundCue = made.soundCue + 1 end
end
-- 3. bar cues on buff rules (aura time left), some in a dynamic group
for i = 1, 24 do
  local r = rule("Bar parent " .. i, function(r)
    r.useBuff, r.buffID, r.buffState = true, 310000 + i, "present"
    r.folder = (i % 2 == 0) and dyns[1].id or nil
  end)
  local c = ns.NewCueRule(r, "bar"); if c then made.bar = made.bar + 1 end
  local c2 = ns.NewCueRule(r, "icon"); if c2 then made.iconCue = made.iconCue + 1 end
end
-- 4. game-played sounds (AuraSound.lua), half of them following the mount state (SD-25)
for i = 1, 20 do
  rule("Game sound " .. i, function(r)
    r.useBuff, r.buffID, r.buffState = true, 320000 + i, "present"
    r.sound.enabled, r.sound.source, r.sound.value = true, "file", SOUND
    r.gameSound = { enabled = true }
    if i % 4 == 1 then r.load.mounted = "yes" elseif i % 4 == 2 then r.load.mounted = "no" end
  end)
  made.game = made.game + 1
end
-- 5. hover-tooltip displays drawn by XayaUI itself (a cooldown-ready icon; V27: hover allowed, clicks pass). (A buff display is drawn
--    by the combat engine's Blizzard container instead: ns.EngineOwns.)
for i = 1, 20 do
  rule("Hover " .. i, function(r)
    r.useCooldown, r.spellID, r.cdState = true, 400040 + i, "ready"
    display(r, 32, 32); r.visual.trigger = "condition"; r.visual.hoverTip = true
    r.folder = statics[(i - 1) % #statics + 1].id
  end)
  made.hover = made.hover + 1
end
-- 6. target debuffs (yours)
for i = 1, 16 do
  rule("Debuff " .. i, function(r)
    r.extra = { list = { { type = "targetDebuff", spellID = 340000 + i, unit = "target", state = "yes" } } }
    display(r, 30, 30); r.visual.trigger = "condition"
    r.folder = dyns[(i - 1) % #dyns + 1].id
  end)
  made.debuff = made.debuff + 1
end
-- 6b. (round 7) rules with a talent requirement: two whose talent is known (loaded) and two that need it not known (not loaded). Talents are
--     read again only on the game's talent events (SD-60, her answer "1"); a re-read on a timer (review R3's once-a-second ticker out of
--     combat while such a rule is switched on) is a repeating timer the gate must see, and before round 7 the profile had no such rule.
for i = 1, 4 do
  rule("Talent " .. i, function(r)
    r.useBuff, r.buffID, r.buffState = true, 300000 + i, "present"
    r.talentMode = "all"; r.talents = { { id = 450000 + i, state = (i % 2 == 1) and "known" or "notKnown" } }
    display(r, 32, 32); r.visual.trigger = "buffActive"
    r.folder = statics[(i - 1) % #statics + 1].id
  end)
  made.talent = made.talent + 1
end
-- 6c. (round 9, SD-77 "Route + narrow", conditions 2 and 3 of docs/plans/R8-ANSWERS-SD73-76-2026-11-15.md) what a re-check narrowed to
--     the changed load fact must not miss, each drawn by XayaUI itself (static groups):
--     target debuffs that must be ABSENT (Triggers.lua: "absent" is unknown in combat, so combat start and end change their answer
--     although no load condition of theirs reads combat); displays with an out-of-combat opacity below 1 (Visual.lua v.oocAlpha: combat
--     changes how they are drawn); rules loaded only during one boss encounter (a Boss encounters list, encounterID) or during any boss
--     encounter (the "Boss encounter" load fact). The spells 400061-400074 are known and never cast, so these icons are "ready".
for i = 1, 6 do
  rule("Absent " .. i, function(r)
    r.extra = { list = { { type = "targetDebuff", spellID = 341000 + i, unit = "target", state = "no" } } }
    display(r, 30, 30); r.visual.trigger = "condition"
    r.folder = statics[(i - 1) % #statics + 1].id
  end)
  made.absent = made.absent + 1
end
for i = 1, 6 do
  rule("Ooc " .. i, function(r)
    r.useCooldown, r.spellID, r.cdState = true, 400060 + i, "ready"
    display(r, 34, 34); r.visual.trigger = "condition"; r.visual.oocAlpha = 0.5
    r.folder = statics[(i - 1) % #statics + 1].id
  end)
  made.ooc = made.ooc + 1
end
for i = 1, 4 do
  rule("Boss " .. i, function(r)
    r.useCooldown, r.spellID, r.cdState = true, 400070 + i, "ready"
    display(r, 34, 34); r.visual.trigger = "condition"
    if i <= 2 then r.load.encounterIDs = { [2001] = true } else r.load.encounter = "yes" end
    r.folder = statics[(i - 1) % #statics + 1].id
  end)
  made.boss = made.boss + 1
end
-- 6d. (round 9, SD-79 "<=30/s, stop if idle") the display effects (Visual.lua FxOnUpdate): fade to gray, fade of the opacity, a flash
--     with its 3 s threshold, a progress wipe, a fade to a color, tenths of a second (every display's duration text shows tenths below
--     5 s, the default) and a bar cue; buffs 330001-330006 and 330010, gained with a short duration and left to run out (SCENARIO_LUA,
--     the effects part). Each also needs its spell ready (400075-400081: known, never cast), so the combat engine's Blizzard container,
--     which draws a buff display that only follows its aura and cannot draw these effects (Combat/AuraDisplay.lua Classify / Drops),
--     leaves it to XayaUI (a rule shown only when its cooldown state also matches), whose effects loop (Visual.lua) draws them
local FXSET = {
  { "fade gray", function(v) v.fadeGrey = true end },
  { "fade opacity", function(v) v.fadeAlpha = true end },
  { "flash", function(v) v.flash = { enabled = true, threshold = 3, speed = 3 } end },
  { "wipe", function(v) v.fill = { enabled = true, reverse = false, min = 0, max = 1 } end },
  { "fade color", function(v) v.fadeGrey = true; v.fadeMode = "color" end },
  { "tenths", function(v) v.text.decimals = true; v.text.decimalBelow = 5 end },
}
for i, fx in ipairs(FXSET) do
  rule("Fx " .. fx[1], function(r)
    r.useBuff, r.buffID, r.buffState = true, 330000 + i, "present"
    r.useCooldown, r.spellID, r.cdState = true, 400074 + i, "ready"
    display(r, 40, 40); r.visual.trigger = "condition"
    fx[2](r.visual)
    r.folder = statics[(i - 1) % #statics + 1].id
  end)
  made.fx = made.fx + 1
end
do
  local p = rule("Fx bar parent", function(r)
    r.useBuff, r.buffID, r.buffState = true, 330010, "present"
    r.useCooldown, r.spellID, r.cdState = true, 400081, "ready"
    r.folder = statics[1].id
  end)
  if ns.NewCueRule(p, "bar") then made.fx = made.fx + 1; made.bar = made.bar + 1 end
end
-- 7. sound and icon cues on rules that have none, up to about 300 entries in the rule list
local i = 0
while #ns.rules < 300 do
  i = i + 1
  local p = ns.rules[(i - 1) % 120 + 1]
  local c = ns.NewCueRule(p, (i % 2 == 0) and "icon" or "sound")
  if not c then break end
  if c.cueKind == "sound" then c.sound.source, c.sound.value = "file", SOUND; made.soundCue = made.soundCue + 1 else made.iconCue = made.iconCue + 1 end
end
-- spread the displays over the screen in whole pixels (a profile she made by dragging)
for k, r in ipairs(ns.rules) do
  if r.visual and r.visual.enabled then r.visual.x, r.visual.y = ((k * 53) % 1200) - 600, ((k * 37) % 600) - 300 end
end
ns.MarkDirty()
W.tick(0.1, 30)
local out, issues = L.logout()
local n = 0
for _, r in ipairs(ns.rules) do n = n + 1 end
return out, n, made, #ns.folders
end
'''


def _world(L, saved_source=None, debug=None):
    """A stand-in game (tests/harness/world.lua + loader.lua) with XayaUI, XayaUI_Rules and XayaUI_Options switched on.
    debug (round 8): None = XayaUI_Debug not in the list (as before); "off" = switched on in the AddOns list, Advanced Debugging as
    saved (off on a new install); "on" = switched on in the list and Advanced Debugging saved on (core loads it at login)."""
    folders = H.find_addons()
    sv = H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    game = L.eval("function(src, W) return loadstring(src)()(W) end")(GAME_LUA, world)
    on = set(ADDONS) | ({DEBUG_ADDON} if debug in ("off", "on") else set())
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders if k in on}})
    opts["saved"] = sv.Load(saved_source) if saved_source else L.table()
    if debug == "on":
        L.eval("function(s) s.XayaUI = s.XayaUI or {}; local c = s.XayaUI.CueRulesDB or {}; s.XayaUI.CueRulesDB = c; "
               "c.ui = c.ui or {}; c.ui.advancedDebug = true end")(opts["saved"])
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    return world, loader, game, sv


def build_profile():
    """Session A: the ~300-rule profile, saved by a logout. Returns (saved source, rule count, kinds made, group count, Lua errors)."""
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world, loader, game, sv = _world(L)
    out, n, made, nf = L.eval("function(src, W, Ld, G) return loadstring(src)()(W, Ld, G) end")(PROFILE_LUA, world, loader, game)
    errors = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return sv.Serialize(out), n, H.lua_to_py(made), nf, errors

# ---------------------------------------------------------------------------------------------------------------------------------
# session B: the instruments (installed before the addons load) and the scenario
# ---------------------------------------------------------------------------------------------------------------------------------
SCENARIO_LUA = r'''
return function(W, L, G, CFG)
local OUT = { checkpoints = {}, minimap = {}, kbCalls = {}, mouseCombat = {}, phases = {}, info = {} }
local PERF = CFG.perf and true or false
local gc, getinfo = collectgarbage, debug.getinfo
local PHASE = "load"
local CLOSED = false            -- the settings window has been closed (the gates judge everything from here on)
local function setPhase(p)
  PHASE = p; if not CFG.memplay then OUT.phases[#OUT.phases + 1] = p end
  if CFG.verbose and io then io.stderr:write(string.format("[gate] %-12s %.1f s\n", p, os.clock())) end
end

-------------------------------------------------------------------------------------------------------------------------------------
-- where a call comes from: the nearest XayaUI file up the stack (a bundled library under Libs/ only when no XayaUI file is found)
-------------------------------------------------------------------------------------------------------------------------------------
-- KB the gate's own measuring and the stand-in's own work (its widget methods, its C_Timer) allocated: taken out of the handler's bytes.
-- (round 8) One total, and every place that takes its own allocation out sets it to "the total when it started + everything allocated
-- since": a measuring step nested inside another (whereFrom inside the stand-in's C_Timer or a widget method) is then taken out once,
-- not twice (before round 8 a nested step was taken out two or three times, which billed the addon less than it allocated).
local EXCL = 0
local function exStart() return gc("count"), EXCL end
local function exEnd(m0, e0) EXCL = e0 + (gc("count") - m0) end
local SHORT = {}                        -- [chunk source] = "XayaUI_Rules/Engine.lua" | false
local function short(src)
  local v = SHORT[src]
  if v == nil then
    v = type(src) == "string" and src:match("^@Interface/AddOns/(XayaUI[%w_]*/.+)$") or false
    SHORT[src] = v
  end
  return v
end
local function isLib(f) return f and f:find("/Libs/", 1, true) ~= nil end
local function whereFrom(level)
  local m0, e0 = exStart()
  local lib
  for l = level + 1, level + 16 do
    local info = getinfo(l, "Sl")
    if not info then break end
    local f = short(info.source)
    if f then
      if not isLib(f) then local w = f .. ":" .. tostring(info.currentline); exEnd(m0, e0); return w, lib end
      lib = lib or (f .. ":" .. tostring(info.currentline))
    end
  end
  exEnd(m0, e0)
  return lib, lib
end

-------------------------------------------------------------------------------------------------------------------------------------
-- the stand-in's widget prototype, the game's mouse model on top of it, and the frames XayaUI makes
-------------------------------------------------------------------------------------------------------------------------------------
local mt = getmetatable(UIParent)
local proto
for i = 1, 60 do local n, v = debug.getupvalue(mt.__index, i); if not n then break end; if n == "proto" then proto = v end end
assert(proto, "the stand-in's widget prototype was not found")
do  -- one shared quiet stand-in per method name (the stand-in made a new closure on every look-up of an undocumented-here method)
  local old, cache = mt.__index, {}
  mt.__index = function(t, k)
    local m = proto[k]
    if m then return m end
    if type(k) ~= "string" then return nil end
    local fl = rawget(t, "_fields")
    if fl and fl[k] ~= nil then return fl[k] end
    local c = cache[k]
    if c == nil then c = old(t, k) or false; if k:match("^[A-Z]") then cache[k] = c end end
    return c or nil
  end
end
do  -- the stand-in's script runner without its per-call tables and closures (the game runs a script without Lua garbage)
  local function quiet(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
      local h = geterrorhandler()
      local hok = pcall(h, tostring(err))
      if not hok then W.errors[#W.errors + 1] = tostring(err) end
    end
    return ok
  end
  for i = 1, 60 do
    local n = debug.getupvalue(proto.Show, i)
    if not n then break end
    if n == "safecall" then debug.setupvalue(proto.Show, i, quiet) end
  end
  OUT.quietSafecall = true
end
local ORIGIN = setmetatable({}, { __mode = "k" })   -- [frame] = "file:line" of the CreateFrame call (XayaUI's)
local CREATED = {}                                  -- [phase] = { [file:line] = n }
local function bump(t, k, by) t[k] = (t[k] or 0) + (by or 1) end
local function sub(t, k) local s = t[k]; if not s then s = {}; t[k] = s end; return s end
local prevCreate = CreateFrame
CreateFrame = function(kind, name, parent, template, id)
  local f = prevCreate(kind, name, parent, template, id)
  if CFG.memplay then return f end   -- (round 9: the memory play keeps no record per frame)
  local m0, e0 = exStart()
  local where = whereFrom(2)
  if where then
    ORIGIN[f] = where
    bump(sub(CREATED, PHASE), where)
  end
  exEnd(m0, e0)
  return f
end
-- the frame that made this object: its own CreateFrame call, or the nearest parent XayaUI made (a template's parts)
local function originOf(o)
  local f, guard = o, 0
  while f and guard < 40 do
    local w = ORIGIN[f]
    if w then return w, f ~= o end
    f = rawget(f, "_parent"); guard = guard + 1
  end
end
-- mouse (docs/reference/api/widgets.md 109-112, 211-213, 283-284, 292, 296; defaults for buttons: INFERENCE)
local CLICKS_BY_DEFAULT = { Button = true, CheckButton = true, EditBox = true, Slider = true }
local MOUSECALLS = {}   -- calls made by XayaUI code in combat, after the window closed: [file:line .. method] = n
local function noteMouseCall(self, what)
  if CLOSED and W.combat then
    local m0, e0 = exStart()
    local w = whereFrom(2)
    if w and not isLib(w) then bump(MOUSECALLS, w .. " " .. what) end
    exEnd(m0, e0)
  end
end
-- the XayaUI line that last turned clicks / motion on (the line a fix changes), kept on the frame
local function by(what)
  local m0, e0 = exStart()
  local w = whereFrom(3)
  w = w and (w .. " " .. what) or nil
  exEnd(m0, e0)
  return w
end
function proto:EnableMouse(v) noteMouseCall(self, "EnableMouse"); v = v and true or false; self._mouse, self._mclick, self._mmotion, self._mouseSet = v, v, v, true
  if v then local b = by("EnableMouse(true)"); self._clickBy, self._motionBy = b, b end end
function proto:SetMouseClickEnabled(v) noteMouseCall(self, "SetMouseClickEnabled"); v = v and true or false; self._mclick, self._mouse = v, v; self._mouseSet = true
  if self._mmotion == nil then self._mmotion = CLICKS_BY_DEFAULT[self._kind] or false end
  if v then self._clickBy = by("SetMouseClickEnabled(true)") end end
function proto:SetMouseMotionEnabled(v) noteMouseCall(self, "SetMouseMotionEnabled"); self._mmotion = v and true or false
  if not self._mouseSet then self._mclick = CLICKS_BY_DEFAULT[self._kind] or false; self._mouse = self._mclick; self._mouseSet = true end
  if v then self._motionBy = by("SetMouseMotionEnabled(true)") end end
proto.EnableMouseMotion = proto.SetMouseMotionEnabled
function proto:IsMouseClickEnabled() if self._mouseSet then return self._mclick and true or false end return CLICKS_BY_DEFAULT[self._kind] or false end
function proto:IsMouseMotionEnabled() if self._mouseSet then return self._mmotion and true or false end return CLICKS_BY_DEFAULT[self._kind] or false end
function proto:IsMouseEnabled() return self:IsMouseClickEnabled() or self:IsMouseMotionEnabled() end
function proto:EnableMouseWheel(v) noteMouseCall(self, "EnableMouseWheel"); self._wheel = v and true or false; if v then self._wheelBy = by("EnableMouseWheel(true)") end end
function proto:IsMouseWheelEnabled() return self._wheel and true or false end
function proto:SetPropagateMouseClicks(v) self._propClicks = v and true or false end
function proto:CanPropagateMouseClicks() return self._propClicks and true or false end
function proto:SetPropagateMouseMotion(v) self._propMotion = v and true or false end
function proto:CanPropagateMouseMotion() return self._propMotion and true or false end
function proto:SetPassThroughButtons(...) self._pass = { ... } end
function proto:IsKeyboardEnabled() return self._keyboard and true or false end
-- keyboard: calls made by XayaUI code after the window closed (V27, V29)
local KBCALLS = {}
local function noteKb(what)
  if not CLOSED then return end
  local m0, e0 = exStart()
  local w = whereFrom(2)
  if w then bump(KBCALLS, w .. " " .. what .. (W.combat and " (in combat)" or "")) end
  exEnd(m0, e0)
end
do
  local EK, SP, SF = proto.EnableKeyboard, proto.SetPropagateKeyboardInput, proto.SetFocus
  proto.EnableKeyboard = function(self, v) if v then noteKb("EnableKeyboard(true)"); self._kbBy = by("EnableKeyboard(true)") end; return EK(self, v) end
  proto.SetPropagateKeyboardInput = function(self, v) noteKb("SetPropagateKeyboardInput(" .. tostring(v) .. ")"); return SP(self, v) end
  proto.SetFocus = function(self) noteKb("SetFocus"); return SF(self) end
  for _, n in ipairs({ "SetOverrideBinding", "SetOverrideBindingClick", "SetOverrideBindingSpell", "SetOverrideBindingMacro", "SetOverrideBindingItem",
      "SetBinding", "SetBindingClick", "SetBindingSpell", "SetBindingMacro", "SetBindingItem" }) do
    local g = rawget(_G, n)
    rawset(_G, n, function(...) noteKb(n); if g then return g(...) end end)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------
-- performance instruments (PERF): dispatches, allocations, visible changes, timers, loops, whole pixels, call counts
-------------------------------------------------------------------------------------------------------------------------------------
local cur = nil         -- the XayaUI handler running now (a dispatch): { kind, name, src }
local T0 = 0            -- the moment the settings window closed
-- what the event being fired is: "storm" (the every-frame combat events: auras, cooldowns, charges, action bars, power, casts),
-- "change" (something the rules read changed: a loading screen, mount, group, target, combat start / end) or "same" (an event the game
-- sends although nothing the rules read changed: a roster update with the same group). Timers and OnUpdate scripts have their own kind.
local CTX = "change"
local VIS = 0           -- visible changes made so far (text, value, alpha, size, position, color, shown state of a shown widget)
local NONINT = {}       -- [file:line] = { n, method, example, phases }
local ST = { ev = {}, ou = {}, tm = {}, loops = {}, wide = {}, cyc = {}, idlewin = {}, mem = {}, hooks = {}, timers = {}, created = CREATED }
local function isWhole(v) return type(v) ~= "number" or v == math.floor(v) end
-- the first addon file up the stack from a widget method (the caller itself, not a XayaUI file further up)
local function directCaller(level)
  for l = level + 1, level + 8 do
    local info = getinfo(l, "Sl")
    if not info then return nil end
    local f = short(info.source)
    if f then return f .. ":" .. tostring(info.currentline), isLib(f) end
  end
end
local function noteNonInt(method, a, b, c, d)
  if not CLOSED and not CFG.nonintAlways then return end
  local m0, e0 = exStart()
  local w, lib = directCaller(2)
  if w and not lib then
    local s = NONINT[w]
    if not s then s = { n = 0, method = method, example = string.format("%s(%s, %s, %s, %s)", method, tostring(a), tostring(b), tostring(c), tostring(d)), phases = {} }; NONINT[w] = s end
    s.n = s.n + 1; s.phases[PHASE] = true
  end
  exEnd(m0, e0)
end
-- the stand-in's widget methods: their own Lua garbage is not XayaUI's (the game stores points and colors in C)
local RUNS_SCRIPTS = { Show = true, Hide = true, SetShown = true, SetValue = true, Click = true, SetFocus = true, ClearFocus = true, Stop = true,
  SetScript = true, HookScript = true }
local function exclEnd(m0, e0, ...) exEnd(m0, e0); return ... end
-- (round 9 repair 1, SD-79) which widget a visible change landed on, for a display redraw a timer makes (REDRAWS, gate_common.py): kept
-- only in the tree play, whose instruction readings are not used. The measured play's changed() is the same as before (no extra Lua
-- instruction in a measured run).
local LASTW, TCHG = nil, nil   -- (tree play) the widget whose method runs now; during a listed redraw timer's run, [widget] = true
local changed
if CFG.tree then
  changed = function() if cur then VIS = VIS + 1; if TCHG and LASTW then TCHG[LASTW] = true end end end
else
  changed = function() if cur then VIS = VIS + 1 end end
end
for name, orig in pairs(proto) do
  if type(orig) == "function" and not RUNS_SCRIPTS[name] then
    local o = orig
    if name == "SetPoint" then
      proto.SetPoint = function(self, p, rel, rp, x, y)
        local m0, e0 = exStart()
        local nx, ny = x, y
        if type(rel) == "number" then nx, ny = rel, rp elseif type(rp) == "number" then nx, ny = rp, x end
        if not (isWhole(nx) and isWhole(ny)) then noteNonInt("SetPoint", p, nx, ny) end
        local before
        for _, e in ipairs(self._pts) do if e[1] == p then before = e end end
        local bx, by, brel = before and before[4], before and before[5], before and before[2]
        o(self, p, rel, rp, x, y)
        if (not before or bx ~= (nx or 0) or by ~= (ny or 0)) and self:IsVisible() then changed() end
        exEnd(m0, e0)
      end
    elseif name == "SetSize" or name == "SetWidth" or name == "SetHeight" then
      proto[name] = function(self, a, b)
        local m0, e0 = exStart()
        if not (isWhole(a) and isWhole(b)) then noteNonInt(name, a, b) end
        local w0, h0 = self._w, self._h
        o(self, a, b)
        if (w0 ~= self._w or h0 ~= self._h) and self:IsVisible() then changed() end
        exEnd(m0, e0)
      end
    elseif name == "SetText" or name == "SetFormattedText" then
      proto[name] = function(self, ...)
        local m0, e0 = exStart()
        local t0 = self._text
        o(self, ...)
        if t0 ~= self._text and self:IsVisible() then changed() end
        exEnd(m0, e0)
      end
    elseif name == "SetAlpha" or name == "SetTexture" or name == "SetAtlas" or name == "SetDesaturated" or name == "SetDesaturation" or name == "SetRotation" or name == "SetScale" then
      local field = ({ SetAlpha = "_alpha", SetTexture = "_tex", SetAtlas = "_atlas", SetDesaturated = "_desat", SetDesaturation = "_desat", SetRotation = "_rot", SetScale = "_scale" })[name]
      proto[name] = function(self, ...)
        local m0, e0 = exStart()
        local v0 = rawget(self, field)
        local r1, r2 = o(self, ...)
        if v0 ~= rawget(self, field) and self:IsVisible() then changed() end
        exEnd(m0, e0)
        return r1, r2
      end
    elseif name == "SetVertexColor" or name == "SetColorTexture" or name == "SetTextColor" or name == "SetCooldown" or name == "SetStatusBarColor" or name == "SetBackdropColor" or name == "SetBackdropBorderColor" then
      local field = ({ SetVertexColor = "_vc", SetColorTexture = "_color", SetTextColor = "_tc", SetCooldown = "_cd", SetBackdropColor = "_bdcolor", SetBackdropBorderColor = "_bdborder" })[name]
      proto[name] = function(self, a, b, c, d)
        local m0, e0 = exStart()
        local t0 = field and rawget(self, field)
        local same = t0 and t0[1] == a and t0[2] == b and t0[3] == c and t0[4] == d
        o(self, a, b, c, d)
        if not same and self:IsVisible() then changed() end
        exEnd(m0, e0)
      end
    elseif name == "SetTexCoord" then
      -- (round 9, SD-79) a progress wipe crops the art with SetTexCoord: a new crop of a shown texture is a visible change
      -- (exact-value compare of the 4 or 8 numbers)
      proto.SetTexCoord = function(self, ...)
        local m0, e0 = exStart()
        local t0, n = rawget(self, "_tc8"), select("#", ...)
        local same = t0 ~= nil and #t0 == n
        if same then for k = 1, n do if t0[k] ~= (select(k, ...)) then same = false; break end end end
        o(self, ...)
        if not same and self:IsVisible() then changed() end
        exEnd(m0, e0)
      end
    else
      proto[name] = function(self, ...) local m0, e0 = exStart(); return exclEnd(m0, e0, o(self, ...)) end
    end
  end
end
do  -- shown state: a change of a shown widget (Show of a hidden one, Hide of a shown one) is a visible change
  local S0, H0, SS0, SV0 = proto.Show, proto.Hide, proto.SetShown, proto.SetValue
  proto.Show = function(self) if not self._shown and (not self._parent or self._parent:IsVisible()) then changed() end; return S0(self) end
  proto.Hide = function(self) if self._shown and self:IsVisible() then changed() end; return H0(self) end
  proto.SetShown = function(self, v) if v then return proto.Show(self) end; return proto.Hide(self) end
  proto.SetValue = function(self, v) if self._value ~= v and self:IsVisible() then changed() end; return SV0(self, v) end
end
if CFG.tree then   -- (round 9 repair 1) the tree play: each method that can change the screen names its widget (LASTW) while it runs
  local function back(p, ...) LASTW = p; return ... end
  for _, name in ipairs({ "SetPoint", "SetSize", "SetWidth", "SetHeight", "SetText", "SetFormattedText", "SetAlpha", "SetTexture", "SetAtlas",
      "SetDesaturated", "SetDesaturation", "SetRotation", "SetScale", "SetVertexColor", "SetColorTexture", "SetTextColor", "SetCooldown",
      "SetStatusBarColor", "SetBackdropColor", "SetBackdropBorderColor", "SetTexCoord", "Show", "Hide", "SetValue" }) do
    local inner = proto[name]
    if type(inner) == "function" then proto[name] = function(self, ...) local p = LASTW; LASTW = self; return back(p, inner(self, ...)) end end
  end
end
-- (round 9, SD-79) a frame script set on a frame that had none: the effects loop starting (again) on that display (see ownNote below)
local ATT = setmetatable({}, { __mode = "k" })   -- [frame] = how many times an OnUpdate script was set on it with none set before
do
  local SS = proto.SetScript
  proto.SetScript = function(self, n, f)
    if n == "OnUpdate" and f ~= nil and self._scripts.OnUpdate == nil then ATT[self] = (ATT[self] or 0) + 1 end
    return SS(self, n, f)
  end
end
-- hooks placed after the window closed (they can never be taken off: V28)
do
  local hsf, HS = hooksecurefunc, proto.HookScript
  hooksecurefunc = function(...) if CLOSED then local m0, e0 = exStart(); local w = whereFrom(2); if w then bump(sub(ST.hooks, PHASE), w .. " hooksecurefunc") end; exEnd(m0, e0) end; return hsf(...) end
  proto.HookScript = function(self, n, f) if CLOSED then local m0, e0 = exStart(); local w = whereFrom(2); if w then bump(sub(ST.hooks, PHASE), w .. " HookScript(" .. tostring(n) .. ")") end; exEnd(m0, e0) end; return HS(self, n, f) end
end
-- timers: who made each one, what kind, and whether it re-arms itself
local TIMERS_SEEN = {}   -- [src] = { kind, every, n made, rearm }
local TIMER_EDGES = {}   -- [src of a running timer] = { [src of a timer it made] = true } (a cycle = a chain that re-arms itself)
local curTimer
-- (round 8, REQUEST-LOG SD-66 / SD-68, her answer "Fix gate + guard + /run test") the guard: a timer call site that hands C_Timer a NEW
-- function object on a later call, made from the same function definition (a closure made per call: C_Timer.After(d, function() X() end)
-- in an event handler), instead of one function made once (a file-level function, as EUI's hot paths and the engine's Kick do). Kept per
-- call site: [site] = { protos = {[definition] = the first function seen}, fresh = {hot, other}, calls = {hot, other}, example }.
-- "hot" = made after the window closed by a handler that runs every frame of a fight (a storm event) or by a timer callback / frame script.
local FRESH = {}
local DEFKEY = setmetatable({}, { __mode = "k" })   -- [function] = "source:linedefined" (its definition)
local function defOf(fn)
  local k = DEFKEY[fn]
  if k == nil then
    local info = type(fn) == "function" and getinfo(fn, "S")
    k = info and (tostring(info.source) .. ":" .. tostring(info.linedefined)) or false
    DEFKEY[fn] = k
  end
  return k
end
-- (round 8, SD-66 / SD-68) everything the stand-in does for a C_Timer call is the stand-in's, not the addon's: its bookkeeping, the
-- timer record, the handle with its two methods and NewTimer / NewTicker's wrapper closure. Each C_Timer function below starts the
-- measure when it is entered (m0, e0) and addTimer ends it after the last of those is made. Before round 8 the measure ended before
-- the record, the handle and the closures were made, so every timer an addon armed was billed to the addon (round 7: the engine's
-- routed timer, armed from UNIT_AURA, made 294 of 1950 UNIT_AURA runs "allocate"). INFERENCE: the game's C_Timer is C code; whether
-- it makes Lua garbage is not in the reference, so it is checked in game (her /run test, a landing step).
local function addTimer(m0, e0, delay, fn, iterations, kind, orig)
  if CFG.memplay then   -- (round 9: the memory play keeps no record per timer; the stand-in's own timer record only)
    local t = { at = W.now + (tonumber(delay) or 0), fn = fn, orig = orig or fn, every = tonumber(delay) or 0, left = iterations, cancelled = false, kind = kind }
    t.handle = { Cancel = function() t.cancelled = true end, IsCancelled = function() return t.cancelled end }
    W.timers[#W.timers + 1] = t
    exEnd(m0, e0)
    return t.handle
  end
  local src = whereFrom(3) or "?"
  local seen = TIMERS_SEEN[src]
  if not seen then seen = { kind = kind, every = tonumber(delay) or 0, made = 0, rearm = false, phases = {} }; TIMERS_SEEN[src] = seen end
  seen.made = seen.made + 1; seen.phases[PHASE] = true
  seen.byPhase = seen.byPhase or {}; seen.byPhase[PHASE] = (seen.byPhase[PHASE] or 0) + 1
  if curTimer and curTimer.src == src then seen.rearm = true end
  if curTimer then local e = TIMER_EDGES[curTimer.src or "?"]; if not e then e = {}; TIMER_EDGES[curTimer.src or "?"] = e end; e[src] = true end
  if CLOSED then
    seen.afterClose = (seen.afterClose or 0) + 1
    -- the guard (above): a new function from the same definition as one this site passed before
    local f = orig or fn
    local def = defOf(f)
    local hot = (cur ~= nil and (cur.kind ~= "event" or CTX == "storm")) and "hot" or "other"
    local g = FRESH[src]
    if not g then g = { protos = {}, fresh = { hot = 0, other = 0 }, calls = { hot = 0, other = 0 } }; FRESH[src] = g end
    g.calls[hot] = g.calls[hot] + 1
    if def then
      local first = g.protos[def]
      if first == nil then g.protos[def] = f
      elseif first ~= f then
        g.fresh[hot] = g.fresh[hot] + 1
        if not g.example then g.example = string.format("%s, %.2f s after the window closed, in %s %s; the function is defined at %s",
            PHASE, W.now - T0, cur and cur.kind or "?", cur and (cur.kind == "event" and (cur.name .. " (" .. CTX .. ")") or cur.src) or "?",
            (tostring(def):gsub("^@Interface/AddOns/", ""))) end
      end
    end
  end
  local t = { at = W.now + (tonumber(delay) or 0), fn = fn, orig = orig or fn, every = tonumber(delay) or 0, left = iterations, cancelled = false, src = src, kind = kind }
  t.handle = { Cancel = function() t.cancelled = true end, IsCancelled = function() return t.cancelled end }
  W.timers[#W.timers + 1] = t
  exEnd(m0, e0)   -- (the record, the handle and its methods, the wrapper, the list slot and the guard's records: the stand-in's)
  return t.handle
end
C_Timer.After = function(d, fn) local m0, e0 = exStart(); addTimer(m0, e0, d, fn, 1, "After") end
C_Timer.NewTimer = function(d, fn) local m0, e0 = exStart(); local h; h = addTimer(m0, e0, d, function() fn(h) end, 1, "NewTimer", fn); return h end
C_Timer.NewTicker = function(d, fn, n) local m0, e0 = exStart(); local h; h = addTimer(m0, e0, d, function() fn(h) end, n or math.huge, (n and n <= 1) and "NewTicker(1)" or "NewTicker", fn); return h end

-- loops over the rule list: ipairs / pairs over a table as long as the rule list (or the rule list / the engine's per-rule state itself)
local LOOPMIN = math.huge
local BIG = setmetatable({}, { __mode = "k" })
local rawipairs, rawpairs = ipairs, pairs
local function noteLoop(n)
  local m0, e0 = exStart()
  local w = whereFrom(2)
  if w and not isLib(w) then
    local d = sub(ST.loops, cur.kind .. " " .. cur.name)
    local s = d[w]
    if not s then s = { times = 0, max = 0, src = cur.src, ctx = {}, phases = {} }; d[w] = s end
    s.times = s.times + 1; if n > s.max then s.max = n end
    local c = (cur.kind == "event") and CTX or cur.kind
    local key = c .. "|" .. cur.src
    s.ctx[key] = (s.ctx[key] or 0) + 1
    s.phases[PHASE] = true
  end
  exEnd(m0, e0)
end
ipairs = function(t)
  if cur and type(t) == "table" then
    local n = BIG[t] or #t
    if n >= LOOPMIN then noteLoop(n) end
  end
  return rawipairs(t)
end
pairs = function(t)
  if cur and type(t) == "table" then
    local n = BIG[t]
    if n and n >= LOOPMIN then noteLoop(n) end
  end
  return rawpairs(t)
end

-- call counts (debug hook, "call" events) per dispatch and per window, and Lua VM instructions per dispatch (the "count" event every
-- INS_STEP instructions: a measure of the work a handler does, whatever loop form it uses)
-- (round 9, SD-80, her answer "Fix it (Recommended)": "measure cost with call counting off; count calls in a separate play") the call
-- counts are taken only in the tree play (CFG.tree, below), never in the play whose instructions the gates read: a Lua "call" hook runs
-- Lua code on every call, and Lua 5.1 counts those instructions too, so before round 9 the call-counting windows (every state-change
-- event and fight frames 31-45) read the every-live-rule pass about 15% heavier (572,050 instructions with counting, 495,792 without,
-- the same frames; docs/plans/R8-ANSWERS-SD73-76-2026-11-15.md). The measured play's hook only counts instructions, from the close to
-- the end, never switched (switching it restarts its counter).
local DCALLS, WCALLS = {}, {}
local KEYS = {}
local INS, INS_STEP = 0, 100
local SAMPLING = false   -- call counting is on only in the sampled windows of the tree play (it slows the stand-in about tenfold)
-- one call into an addon function: level = the level of the function called, seen from the hook that calls countCall
local function countCall(level)
  local m0, e0 = exStart()
  local info = getinfo(level + 1, "S")
  if info then
    local f = short(info.source)
    if f and not isLib(f) then
      local ks = KEYS[f]; if not ks then ks = {}; KEYS[f] = ks end
      local k = ks[info.linedefined]; if not k then k = f .. ":" .. info.linedefined; ks[info.linedefined] = k end
      DCALLS[k] = (DCALLS[k] or 0) + 1
      WCALLS[k] = (WCALLS[k] or 0) + 1
    end
  end
  exEnd(m0, e0)
end
local function callhook(ev)   -- (the measured play: "count" events only)
  if ev == "count" then INS = INS + 1; return end
end

-- the dispatcher: every event handler, OnUpdate script and timer callback of a frame XayaUI made goes through here
local SRCKEY = setmetatable({}, { __mode = "k" })
local function srcOf(fn)
  local k = SRCKEY[fn]
  if k == nil then
    local info = getinfo(fn, "S")
    local f = info and short(info.source)
    k = f and (f .. ":" .. info.linedefined) or false
    SRCKEY[fn] = k
  end
  return k
end
local quietRun = function(fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then local hok = pcall(geterrorhandler(), tostring(err)); if not hok then W.errors[#W.errors + 1] = tostring(err) end end
  return ok
end
local WIN = 2   -- seconds: an OnUpdate or ticker is judged per 2-second window (a countdown in whole seconds changes once a second)
-- V33 work budget (round 7; REQUEST-LOG SD-50 / SD-51, her answer "Proxy gate + your check"): each addon's work per drawn frame, in Lua VM
-- instructions of its own handlers (events, OnUpdate scripts, timer callbacks; an addon's handler is billed for everything it calls,
-- INFERENCE about how the game's AddOn Usage bills), summed per segment: "fight N" (PLAYER_REGEN_DISABLED to the last fight frame of
-- cycle N, the first second included), "out N" (the rest of cycle N) and "idle". The events fired between two frames belong to the next.
local ADDON_OF = {}   -- [file:line] = "XayaUI_Rules" (the addon folder)
local function addonOf(src) local a = ADDON_OF[src]; if a == nil then a = src:match("^(XayaUI[%w_]*)/") or "?"; ADDON_OF[src] = a end; return a end
local BSEG = nil      -- the segment being played, or nil (before the window closed)
local BFRAME = {}     -- [addon] = instructions in the frame being drawn
local BUD = {}        -- [segment] = { frames, work = {[addon]}, peak = {[addon]}, sec = {[addon] = {per second of the segment}}, keys = {[addon] = {[key] = stats}} }
local function budSeg(name)
  local s = BUD[name]
  if not s then s = { frames = 0, work = {}, peak = {}, sec = {}, keys = {} }; BUD[name] = s end
  return s
end
-- her pace (SD-61, "10/s for all, like EUI"; round 8, SD-66, her answer "1": every re-check path at most 10 a second): every timer callback
-- (one-shot or repeating, armed by an event or by itself: routed passes, every-live-rule passes, wakes, polls) and every frame script
-- (OnUpdate) of XayaUI, after the window closed, in ANY sliding one-second window (the first second of a fight included). A window holds
-- the runs in (now - 1 s, now]: at exactly ten a second (0.1 s apart) it holds 10. (PACE_EPS absorbs the float error of adding 1/30 s frames.)
-- (round 8 repair) Kept per FUNCTION a timer callback or frame script runs, not only per callback: the gate notes every XayaUI function
-- entered during such a run (its call tree, once per run), so a re-check pass is counted however many callbacks drive it (one pass run by
-- two timers at 0.12 s each runs 15 a second although each timer runs 7.5). The callback or script itself is one of those functions.
local PACE_N, PACE_RING, PACE_EPS = 10, 32, 1 / 60
local PACE = {}       -- [function file:line] = { kind, kinds = {[kind]}, drivers = {[driver file:line] = runs}, t = {}, v = {}, i = 0, over = {[phase]}, quiet = {[phase]}, firstSec = {[phase]}, most, first }
local FILEPACE = {}   -- [file] = { t = {}, i = 0, most = 0 }: every callback of one file together (report only: her rule is per path)
local FIGHT_AT = nil  -- when the fight being played started (PLAYER_REGEN_DISABLED), for "the first second of a fight"
local function paceNote(src, vis, kind, driver)
  local p = PACE[src]
  if not p then p = { kind = kind, kinds = {}, drivers = {}, t = {}, v = {}, i = 0, over = {}, quiet = {}, allVis = {}, firstSec = {}, most = 0 }; PACE[src] = p end
  if not p.kinds[kind] then p.kinds[kind] = true; if p.kind ~= kind then p.kind = "mixed" end end
  p.drivers[driver] = (p.drivers[driver] or 0) + 1
  p.i = p.i % PACE_RING + 1
  p.t[p.i], p.v[p.i] = W.now, vis
  local n, seen, quietRuns = 0, 0, 0
  for k = 1, PACE_RING do
    local t = p.t[k]
    if t and t > W.now - 1 + PACE_EPS then n = n + 1; seen = seen + (p.v[k] or 0); if (p.v[k] or 0) == 0 then quietRuns = quietRuns + 1 end end
  end
  if n > p.most then p.most = n end
  if n > PACE_N then
    p.over[PHASE] = (p.over[PHASE] or 0) + 1
    if seen == 0 then p.quiet[PHASE] = (p.quiet[PHASE] or 0) + 1 end
    if quietRuns == 0 then p.allVis[PHASE] = (p.allVis[PHASE] or 0) + 1 end   -- every run in that second changed something on screen (report only)
    local inFirst = FIGHT_AT and W.combat and (W.now - FIGHT_AT) <= 1 + PACE_EPS
    if inFirst then p.firstSec[PHASE] = (p.firstSec[PHASE] or 0) + 1 end
    p.first = p.first or string.format("%s, %.2f s after the window closed%s, %d runs in the last second, %d of them changing nothing on screen",
      PHASE, W.now - T0, inFirst and string.format(" (%.2f s into the fight)", W.now - FIGHT_AT) or "", n, quietRuns)
  end
end
-- (round 8 repair 2) every run of a function, whatever runs it: an event handler too, not only a timer callback or frame script. The
-- gate judges the re-check passes it is told of (gate_performance_run.py REPASSES) on this record, so a pass an event handler runs
-- itself (on every UNIT_AURA, say) counts like one a timer runs. Report only for every other function (an event handler runs as often
-- as its event fires).
local PACEX = {}      -- [function file:line] = { t = {}, i = 0, most, over = {[phase]}, firstSec = {[phase]}, first, drivers = {[driver] = runs} }
local function paceAnyNote(src, driver)
  local p = PACEX[src]
  if not p then p = { t = {}, i = 0, most = 0, over = {}, firstSec = {}, drivers = {} }; PACEX[src] = p end
  p.drivers[driver] = (p.drivers[driver] or 0) + 1
  p.i = p.i % PACE_RING + 1
  p.t[p.i] = W.now
  local n = 0
  for k = 1, PACE_RING do local t = p.t[k]; if t and t > W.now - 1 + PACE_EPS then n = n + 1 end end
  if n > p.most then p.most = n end
  if n > PACE_N then
    p.over[PHASE] = (p.over[PHASE] or 0) + 1
    local inFirst = FIGHT_AT and W.combat and (W.now - FIGHT_AT) <= 1 + PACE_EPS
    if inFirst then p.firstSec[PHASE] = (p.firstSec[PHASE] or 0) + 1 end
    p.first = p.first or string.format("%s, %.2f s after the window closed%s, %d runs in the last second", PHASE, W.now - T0,
      inFirst and string.format(" (%.2f s into the fight)", W.now - FIGHT_AT) or "", n)
  end
end
local function filePaceNote(src)
  local file = src:match("^(.-):%d+$") or src
  local fp = FILEPACE[file]
  if not fp then fp = { t = {}, i = 0, most = 0 }; FILEPACE[file] = fp end
  fp.i = fp.i % 64 + 1; fp.t[fp.i] = W.now
  local m = 0
  for k = 1, 64 do local t = fp.t[k]; if t and t > W.now - 1 + PACE_EPS then m = m + 1 end end
  if m > fp.most then fp.most = m end
end
-- the functions a timer callback, frame script or (round 8 repair 2) event handler run enters (its call tree, each once). Taken only in a second play of the scenario
-- (CFG.tree, result() below), never in the play the gates measure: a Lua "call" hook runs Lua code on every call, and those instructions
-- use up the instruction counter's steps (Lua 5.1 counts VM instructions inside a hook too and drops the count events that fall there),
-- and switching the hook on and off around each run restarts the counter; either changes every instruction reading (round 8 repair,
-- tried on ad60a051: 389,042 per fight frame with the hook switched per run, 397,329 with it always on, against 408,425 without it).
-- In the tree play the "call" hook is on from the close to the end and does nothing outside a measured run.
local RUNDEF, RUNLIST, RUNN = {}, {}, 0
local TREE = false
local function treehook(ev)
  if ev == "count" then INS = INS + 1; return end
  -- (round 9, SD-80: the call counts, here only; before, this called the measured play's hook, which read the caller one level too
  -- high (treehook's own chunk, not an addon's), so the tree play counted no call)
  if SAMPLING then countCall(2) end
  if not TREE then return end
  local m0, e0 = exStart()
  local info = getinfo(2, "S")
  if info then
    local f = short(info.source)
    if f and not isLib(f) then
      local ks = KEYS[f]; if not ks then ks = {}; KEYS[f] = ks end
      local k = ks[info.linedefined]; if not k then k = f .. ":" .. info.linedefined; ks[info.linedefined] = k end
      if not RUNDEF[k] then RUNDEF[k] = true; RUNN = RUNN + 1; RUNLIST[RUNN] = k end
    end
  end
  exEnd(m0, e0)
end
-- (round 9, SD-79, her answer "<=30/s, stop if idle (Recommended)": "effects loop at most 30/s per display while a run changes something;
-- the loop stops when a run changes nothing (exact-value compare); the gate gets an effects scenario and counts per display") every
-- frame script's runs are kept per FRAME it runs on, not summed over every frame that runs the same function (before round 9 the display
-- effects loop, Visual.lua FxOnUpdate, was one record for every display together). A frame that is a rule's display (Visual.lua's
-- rule -> frame table, ns.DisplayFrame) is a display; its effects loop is judged per display (gate_performance_run.py): at most FX_N real
-- runs in any sliding second, and no run that changes nothing on screen beyond the single run that finds there is nothing left to
-- animate (a run's visible changes are counted with an exact-value compare of what each widget write sets, as everywhere in the gate).
-- A real run is one that changes something on screen or does at least FX_SKIP Lua instructions: the throttle's early return on the
-- frames between two runs (the game calls a frame script every frame it draws) changes nothing, is a few instructions and is counted
-- apart, as a skip. (round 9 repair 1) A run that changes the screen is always a run, however cheap (before, a cheap loop that changed
-- the screen on every frame was all skips and was never judged); and a script that stays set while it only skips is idle and has not
-- stopped: once the frames it skipped since its last run (or since it was set) add up to more than one second (the window her 30 a
-- second is counted in), every further skip is a violation (FX_WAIT). A frame that is not a display (the engine's next-frame script)
-- counts every invocation, as before.
local FX_N, FX_RING, FX_SKIP = 30, 160, 300   -- (FX_RING: more runs than a second can hold at 144 frames a second)
local FX_EPS = 1e-6   -- (the float error of adding 1/144 s frames; PACE_EPS, 1/60 s, would leave out two frames of a second at 144)
local FX_WAIT = 1     -- seconds of frames a display's script may only skip before it counts as idle and not stopped (repair 1)
local TICKDT = 0      -- the time of the frame being drawn (W.tick): what a skip adds to its display's wait
local FXPRE = false   -- the previews and the mover before the close (see runPre below)
local OWN = setmetatable({}, { __mode = "k" })   -- [frame] = its record
local OWNLIST = {}                               -- the records, in the order made
local DFRAMES = false
local function dframes()   -- Visual.lua's rule -> display frame table (ns.DisplayFrame's upvalue "frames"), or false
  if not DFRAMES then
    local nsx = rawget(_G, "XayaUI_NS")
    if nsx and nsx.DisplayFrame then
      for i = 1, 60 do
        local n, v = debug.getupvalue(nsx.DisplayFrame, i)
        if not n then break end
        if n == "frames" and type(v) == "table" then DFRAMES = v; break end
      end
    end
  end
  return DFRAMES
end
local function displayOf(o)
  if not dframes() then return nil end
  for r, f in rawpairs(DFRAMES) do if f == o then return r end end
end
local function ownNote(o, src, vis, ins)
  local rec = OWN[o]
  if rec == nil or (not rec.display and (ATT[o] or 0) ~= rec.att) then   -- (a frame that was no display yet when last seen: look again)
    local r = displayOf(o)
    if rec == nil then
      rec = { n = #OWNLIST + 1, where = ORIGIN[o], att = -1, runs = 0, skips = 0, changed = 0, idle = 0, streak = 0, t = {}, i = 0, most = 0,
        over = {}, idleOver = {}, runsBy = {}, wins = {}, wait = 0, waits = 0, waitOver = {}, times = {}, tn = 0 }
      OWN[o] = rec; OWNLIST[#OWNLIST + 1] = rec
    end
    rec.display = r ~= nil
    rec.rule = r and tostring(r.name) or rec.rule
  end
  rec.src = rec.src or src
  local a = ATT[o] or 0
  if rec.att ~= a then rec.att = a; rec.streak = 0; rec.wait = 0 end   -- (the loop was set again: its first run may find nothing to do)
  if rec.display and ins < FX_SKIP and vis == 0 then
    rec.skips = rec.skips + 1
    rec.wait = rec.wait + TICKDT
    if rec.wait > FX_WAIT + FX_EPS then   -- (repair 1) set, skipping, nothing run for more than a second: idle and not stopped
      rec.waits = rec.waits + 1
      rec.waitOver[PHASE] = (rec.waitOver[PHASE] or 0) + 1
      rec.firstWait = rec.firstWait or string.format("%s, at %.3f s (%.2f s after the window closed): %.2f s of frames skipped since its "
        .. "last run or since it was set", PHASE, W.now, W.now - T0, rec.wait)
    end
    return
  end
  rec.wait = 0
  rec.runs = rec.runs + 1
  if rec.display and (CLOSED or FXPRE) then rec.tn = rec.tn + 1; rec.times[rec.tn] = W.now end   -- (repair 1: merged with its timer redraws)
  rec.runsBy[PHASE] = (rec.runsBy[PHASE] or 0) + 1
  local viol = false
  if vis > 0 then rec.changed = rec.changed + 1; rec.streak = 0
  else
    rec.idle = rec.idle + 1; rec.streak = rec.streak + 1
    if rec.streak >= 2 then
      viol = true
      rec.idleOver[PHASE] = (rec.idleOver[PHASE] or 0) + 1
      rec.firstIdle = rec.firstIdle or string.format("%s, at %.3f s (%.2f s after the window closed), run %d in a row that changed nothing on "
        .. "screen", PHASE, W.now, W.now - T0, rec.streak)
    end
  end
  rec.i = rec.i % FX_RING + 1; rec.t[rec.i] = W.now
  local n, k = 0, rec.i   -- (newest first: the ring is in time order, so the count stops at the first run outside the second)
  repeat
    local t = rec.t[k]
    if not (t and t > W.now - 1 + FX_EPS) then break end
    n = n + 1; k = (k - 2) % FX_RING + 1
  until k == rec.i
  if n > rec.most then rec.most = n end
  if n > FX_N then
    rec.over[PHASE] = (rec.over[PHASE] or 0) + 1
    rec.first = rec.first or string.format("%s, at %.3f s, %d runs in the second up to it", PHASE, W.now, n)
  end
  local w = math.floor((W.now - T0) / WIN)
  local ww = rec.wins[w]; if not ww then ww = { runs = 0, vis = 0, viol = 0, phase = PHASE }; rec.wins[w] = ww end
  ww.runs = ww.runs + 1; ww.vis = ww.vis + vis; if viol then ww.viol = ww.viol + 1 end
end
local function budNote(kind, name, src, bytes, ins)
  local a = addonOf(src)
  BFRAME[a] = (BFRAME[a] or 0) + ins
  local s = budSeg(BSEG)
  local ks = s.keys[a]; if not ks then ks = {}; s.keys[a] = ks end
  local key = (kind == "event") and name or (kind .. " " .. src)
  local e = ks[key]; if not e then e = { n = 0, ins = 0, max = 0, bytes = 0, allocRuns = 0 }; ks[key] = e end
  e.n = e.n + 1; e.ins = e.ins + ins; if ins > e.max then e.max = ins end
  e.bytes = e.bytes + bytes; if bytes > 0 then e.allocRuns = e.allocRuns + 1 end
end
-- (round 9, SD-77) the frames right after a moment that changes load facts (combat start, a boss pull, a boss kill, combat end): each
-- addon's costliest of them, kept per segment under the moment's name (MOMENT_FRAMES frames: the event's own frame, the next-frame
-- settle and any pass held to the 10-a-second pace, 0.1 s = 3 frames, all fall inside)
local MOMENT, MOMENT_LEFT, MOMENT_FRAMES = nil, 0, 15
local function moment(name) MOMENT, MOMENT_LEFT = name, MOMENT_FRAMES end
local function budFrame()
  if not BSEG then for a in rawpairs(BFRAME) do BFRAME[a] = nil end; MOMENT = nil; return end
  local s = budSeg(BSEG)
  local secIndex = math.floor(s.frames / 30) + 1   -- (30 frames a second: the scenario's FPS)
  s.frames = s.frames + 1
  local mo
  if MOMENT then
    s.moments = s.moments or {}
    mo = s.moments[MOMENT]; if not mo then mo = {}; s.moments[MOMENT] = mo end
    MOMENT_LEFT = MOMENT_LEFT - 1
    if MOMENT_LEFT <= 0 then MOMENT = nil end
  end
  for a, w in rawpairs(BFRAME) do
    s.work[a] = (s.work[a] or 0) + w
    if w > (s.peak[a] or 0) then s.peak[a] = w end
    if mo and w > (mo[a] or 0) then mo[a] = w end
    if secIndex then local q = s.sec[a]; if not q then q = {}; s.sec[a] = q end; q[secIndex] = (q[secIndex] or 0) + w end
    BFRAME[a] = nil
  end
end
local function finish(kind, name, src, bytes, vis, owner, ins)
  -- bookkeeping after the measurement (its own garbage is not counted)
  local byKind = (kind == "event") and ST.ev or ((kind == "onupdate") and ST.ou or ST.tm)
  local s = byKind[name]
  if not s then s = { n = 0, bytes = 0, max = 0, idle = 0, vis = 0, ins = 0, insMax = 0, byPhase = {}, srcs = {}, wins = {}, winsIdle = {} }; byKind[name] = s end
  s.n = s.n + 1; s.bytes = s.bytes + bytes; if bytes > s.max then s.max = bytes end
  s.ins = s.ins + ins; if ins > s.insMax then s.insMax = ins end
  s.vis = s.vis + vis
  if vis == 0 then s.idle = s.idle + 1 end
  local p = s.byPhase[PHASE]; if not p then p = { n = 0, bytes = 0, idle = 0, vis = 0, ins = 0, allocRuns = 0 }; s.byPhase[PHASE] = p end
  p.n = p.n + 1; p.bytes = p.bytes + bytes; p.vis = p.vis + vis; p.ins = p.ins + ins; if vis == 0 then p.idle = p.idle + 1 end
  if bytes > 0 then p.allocRuns = p.allocRuns + 1 end
  if src then
    local h = s.srcs[src]; if not h then h = { n = 0, bytes = 0, ins = 0, insMax = 0, byPhase = {} }; s.srcs[src] = h end
    h.n = h.n + 1; h.bytes = h.bytes + bytes; h.ins = h.ins + ins; if ins > h.insMax then h.insMax = ins end
    local hp = h.byPhase[PHASE]; if not hp then hp = { n = 0, bytes = 0, ins = 0, allocRuns = 0, ctx = {} }; h.byPhase[PHASE] = hp end
    hp.n = hp.n + 1; hp.bytes = hp.bytes + bytes; hp.ins = hp.ins + ins; if bytes > 0 then hp.allocRuns = hp.allocRuns + 1 end
    local c = (kind == "event") and CTX or kind
    local hc = hp.ctx[c]; if not hc then hc = { n = 0, bytes = 0, ins = 0, allocRuns = 0, insMax = 0 }; hp.ctx[c] = hc end
    hc.n = hc.n + 1; hc.bytes = hc.bytes + bytes; hc.ins = hc.ins + ins; if bytes > 0 then hc.allocRuns = hc.allocRuns + 1 end
    if ins > hc.insMax then hc.insMax = ins end
  end
  if BSEG and src then budNote(kind, name, src, bytes, ins) end
  -- (round 9, SD-79) a frame script's run, per frame it runs on; a display's effects loop is judged per display at her 30 a second
  -- (gate_performance_run.py), not at the 10 a second of a re-check path: its call tree is not counted per callback or function here,
  -- but a re-check pass it runs still counts for that pass (paceAnyNote, REPASSES)
  local disp = false
  if kind == "onupdate" and owner and src then ownNote(owner, src, vis, ins); disp = OWN[owner] and OWN[owner].display or false end
  if (kind == "timer" or kind == "onupdate") and src and CLOSED then
    if not disp then filePaceNote(src) end
    if RUNN == 0 and not disp then paceNote(src, vis, kind, src) end   -- (no call tree taken: XUI_GATE_NOHOOK)
    for i = 1, RUNN do local k = RUNLIST[i]; if not disp then paceNote(k, vis, kind, src) end; paceAnyNote(k, src); RUNDEF[k] = nil; RUNLIST[i] = nil end
    RUNN = 0
  elseif RUNN > 0 then   -- (round 8 repair 2) an event handler's call tree (tree play only)
    local driver = "event " .. tostring(name) .. " " .. tostring(src)
    for i = 1, RUNN do local k = RUNLIST[i]; if CLOSED then paceAnyNote(k, driver) end; RUNDEF[k] = nil; RUNLIST[i] = nil end
    RUNN = 0
  end
  if kind ~= "event" then
    local w = math.floor((W.now - T0) / WIN)
    local ww = s.wins[w]; if not ww then ww = { runs = 0, vis = 0, phase = PHASE }; s.wins[w] = ww end
    ww.runs = ww.runs + 1; ww.vis = ww.vis + vis
  end
  -- functions called as often as there are rules in this one dispatch: a loop over every rule
  for k, n in rawpairs(DCALLS) do
    if n >= LOOPMIN then
      local d = sub(ST.wide, kind .. " " .. name)
      local e = d[k]; if not e then e = { times = 0, max = 0, src = src, phases = {}, ctx = {} }; d[k] = e end
      e.times = e.times + 1; if n > e.max then e.max = n end; e.phases[PHASE] = true
      local c = (kind == "event") and CTX or kind
      e.ctx[c] = (e.ctx[c] or 0) + 1
    end
    DCALLS[k] = nil
  end
end
-- (round 9 repair 1; SD-76 asked "whether 10/s covers screen redraws", her answer SD-79 "<=30/s, stop if idle (Recommended)": redraws at
-- most 30 a second PER DISPLAY, the gate counting per display) a display's time-driven parts can also be drawn by a timer instead of a
-- frame script (Visual.lua's wake at the next moment a part changes: the next tenth, the flash threshold, the wipe's next pixel). The
-- timer callbacks that only redraw displays are named in REDRAWS (gate_common.py; CFG.redraws, "file:line" of the callback). In the
-- tree play (the only play that knows which widget a change landed on) every run of such a callback is kept: each display it changed
-- (the display frame its changed widgets sit in, ns.DisplayFrame's table) gets a redraw at that moment, judged per display together with
-- that display's frame-script runs (gate_performance_run.py: at most 30 in any second); a run that changes nothing on any display is an
-- idle run (two in a row: the wake did not stop when nothing was left to draw); a change outside every display is kept (the callback is
-- then not a pure redraw and stays under P2's 10 a second).
local REDRAW = {}
if CFG.tree and CFG.redraws then for k in rawpairs(CFG.redraws) do REDRAW[k] = true end end
local TRED = {}         -- [callback src] = its record
local TCHGBUF = {}
local function redrawNote(src, vis)
  local t = TRED[src]
  if not t then t = { runs = 0, idle = 0, streak = 0, idleOver = {}, outside = 0, disp = {}, byPhase = {} }; TRED[src] = t end
  t.runs = t.runs + 1
  t.byPhase[PHASE] = (t.byPhase[PHASE] or 0) + 1
  local rev, seen, nd = {}, {}, 0
  if dframes() then for r, f in rawpairs(DFRAMES) do rev[f] = r end end
  for w in rawpairs(TCHGBUF) do
    local f, g, r = w, 0, nil
    while f and g < 40 do r = rev[f]; if r then break end; f = rawget(f, "_parent"); g = g + 1 end
    if r then
      if not seen[r] then seen[r] = true; nd = nd + 1 end
    else
      t.outside = t.outside + 1
      t.firstOutside = t.firstOutside or string.format("%s, at %.3f s: a %s (%s)", PHASE, W.now, tostring(rawget(w, "_kind")), tostring(ORIGIN[w] or rawget(w, "_name")))
    end
    TCHGBUF[w] = nil
  end
  if nd == 0 and vis == 0 then
    t.idle = t.idle + 1; t.streak = t.streak + 1
    if t.streak >= 2 then
      t.idleOver[PHASE] = (t.idleOver[PHASE] or 0) + 1
      t.firstIdle = t.firstIdle or string.format("%s, at %.3f s (%.2f s after the window closed), run %d in a row that changed nothing on screen",
        PHASE, W.now, W.now - T0, t.streak)
    end
  else
    t.streak = 0
  end
  for r in rawpairs(seen) do
    local key = tostring(r.name)
    local d = t.disp[key]; if not d then d = { n = 0, times = {}, byPhase = {} }; t.disp[key] = d end
    d.n = d.n + 1; d.times[d.n] = W.now; d.byPhase[PHASE] = (d.byPhase[PHASE] or 0) + 1
  end
end
local function runRedraw(src, fn, ...)   -- (tree play) a listed redraw timer's run before the close (the previews, the mover)
  local vis0 = VIS
  cur = { kind = "timer", name = src, src = src }
  TCHG = TCHGBUF
  local ok = quietRun(fn, ...)
  TCHG = nil
  cur = nil
  redrawNote(src, VIS - vis0)
  return ok
end
-- (round 9, SD-79) the previews and the mover before the window closes (CFG phases "preview" and "unlock"): a frame script's runs are
-- counted per frame (ownNote) and nothing else is measured
local function runPre(owner, fn, ...)
  local src = srcOf(fn)
  if not src then return quietRun(fn, ...) end
  local vis0, i0 = VIS, INS
  cur = { kind = "onupdate", name = src, src = src }
  local ok = quietRun(fn, ...)
  cur = nil
  ownNote(owner, src, VIS - vis0, (INS - i0) * INS_STEP)
  return ok
end
local function run(kind, name, owner, fn, ...)
  if not (PERF and CLOSED) or cur then
    if FXPRE and PERF and kind == "onupdate" and not cur and owner then return runPre(owner, fn, ...) end
    if FXPRE and kind == "timer" and not cur and CFG.tree then   -- (repair 1) a listed redraw timer in the previews and the mover
      local s0 = srcOf(rawget(W, "_srcFn") or fn)
      if s0 and REDRAW[s0] then W._srcFn = nil; return runRedraw(s0, fn, ...) end
    end
    return quietRun(fn, ...)
  end
  local src = srcOf(rawget(W, "_srcFn") or fn)
  W._srcFn = nil
  if not src then return quietRun(fn, ...) end
  local red = kind == "timer" and REDRAW[src]   -- (repair 1, tree play only: REDRAW is empty in the measured play)
  if red then TCHG = TCHGBUF end
  if kind == "onupdate" then name = src end   -- (a timer keeps the line that made it as its name; its function's line is src)
  local rec = owner   -- (unused; kept for the reader: the frame whose script runs)
  for k in rawpairs(DCALLS) do DCALLS[k] = nil end
  EXCL = 0
  local vis0 = VIS
  cur = { kind = kind, name = name, src = src }   -- (made before the measurement starts)
  if CFG.tree then TREE = true end   -- (round 8 repair 2: event handlers too, for the passes an event handler runs itself)
  gc("stop")
  local i0 = INS
  local m0 = gc("count")
  local ok = quietRun(fn, ...)
  local m1 = gc("count")
  local ins = (INS - i0) * INS_STEP
  if CFG.tree then TREE = false end   -- (after the reading: the measured play runs no extra instruction inside it)
  gc("restart")
  local c = cur
  cur = nil
  if red then TCHG = nil; redrawNote(src, VIS - vis0) end
  local bytes = math.floor(((m1 - m0) - EXCL) * 1024 + 0.5)
  if bytes < 0 then bytes = 0 end
  finish(kind, c.name, src, bytes, VIS - vis0, owner, ins)
  return ok
end
-- W.fire / W.tick as the stand-in has them, through the dispatcher
W.fire = function(ev, ...)
  local n, objs, i = 0, W.objects, 1
  while objs[i] do
    local o = objs[i]
    if (o._events[ev] or o._allEvents) and o._scripts.OnEvent then n = n + 1; run("event", ev, o, o._scripts.OnEvent, o, ev, ...) end
    i = i + 1
  end
  return n
end
local FRAMES = {}   -- [phase] = frames drawn
W.tick = function(dt, steps)
  for _ = 1, (steps or 1) do
    W.now = W.now + dt
    TICKDT = dt
    FRAMES[PHASE] = (FRAMES[PHASE] or 0) + 1
    local due, keep = {}, {}
    for _, t in rawipairs(W.timers) do
      if t.cancelled then -- dropped
      elseif t.at <= W.now then due[#due + 1] = t else keep[#keep + 1] = t end
    end
    W.timers = keep
    for _, t in rawipairs(due) do
      curTimer = t
      W._srcFn = t.orig
      run("timer", t.src or "?", nil, t.fn)
      W._srcFn = nil
      curTimer = nil
      if t.left and t.left ~= math.huge then t.left = t.left - 1 end
      if not t.cancelled and t.left and t.left > 0 then t.at = W.now + math.max(t.every, 0.01); W.timers[#W.timers + 1] = t end
    end
    local objs = W.objects
    for i = 1, #objs do
      local o = objs[i]
      local f = o._scripts.OnUpdate
      if f and o:IsVisible() then run("onupdate", nil, o, f, o, dt) end
    end
    budFrame()
  end
end

-------------------------------------------------------------------------------------------------------------------------------------
-- checkpoints: what takes the mouse and the keyboard right now
-------------------------------------------------------------------------------------------------------------------------------------
local SW, SH = GetScreenWidth(), GetScreenHeight()
local ALLOWED = {}   -- frames the player may click with the window closed: the minimap button itself (V27, her answer "Hover only, clicks pass")
local function hasArea(o)
  if #o._pts == 0 and o ~= UIParent then return false, 0, 0 end
  local r = W.rect(o)
  local w = math.max(0, math.min(r.l + r.w, SW) - math.max(r.l, 0))
  local h = math.max(0, math.min(r.b + r.h, SH) - math.max(r.b, 0))
  return w > 0 and h > 0, r.w, r.h, (w * h) / (SW * SH)
end
local function passesClicks(o)
  if o._propClicks then return true end
  local p = o._pass
  if p then local l, r = false, false; for _, b in rawipairs(p) do if b == "LeftButton" then l = true elseif b == "RightButton" then r = true end end; if l and r then return true end end
  return false
end
-- the top-level frame an object sits in (the highest parent below UIParent / the minimap), with its name and the line that made it
local function topOf(o)
  local f, guard = o, 0
  while f and guard < 40 do
    local p = rawget(f, "_parent")
    if not p or p == UIParent or p == rawget(_G, "Minimap") then break end
    f = p; guard = guard + 1
  end
  return f
end
local function inMenu(o)
  local menu = rawget(_G, "XayaUIMinimapMenu")
  local f, guard = o, 0
  while f and menu and guard < 40 do if f == menu then return true end; f = rawget(f, "_parent"); guard = guard + 1 end
  return false
end
local function checkpoint(label)
  local cp = { label = label, combat = W.combat, mouse = {}, hover = 0, hoverList = {}, noArea = {}, wheel = {}, keyboard = {}, kbHidden = {}, engine = {}, focus = {}, keys = {}, shown = {}, big = {} }
  local nsx = rawget(_G, "XayaUI_NS")
  local act = 0
  if nsx and nsx.runtime then for _, rt in rawpairs(nsx.runtime) do if rt.active then act = act + 1 end end end
  cp.activeRules = act
  local ruleOf = {}
  if nsx and nsx.DisplayFrame then
    for i = 1, 60 do
      local n, v = debug.getupvalue(nsx.DisplayFrame, i)
      if not n then break end
      if n == "frames" and type(v) == "table" then for r, f in rawpairs(v) do ruleOf[f] = r end end
    end
  end
  for _, o in rawipairs(W.objects) do
    local where, viaParent = originOf(o)
    if where and not viaParent and o:IsVisible() then bump(cp.shown, where) end
    if where and o:IsVisible() and not ALLOWED[o] and not (o._kind == "Texture" or o._kind == "FontString" or o._kind == "MaskTexture" or o._kind == "Line") then
      local click = o:IsMouseClickEnabled() and not passesClicks(o)
      local area, w, h, frac = hasArea(o)
      local nm = o._name or ("a " .. tostring(o._kind))
      if click and o._blizzard then
        -- an aura button Blizzard's container made for the combat engine: whether the game's button takes clicks is not documented
        -- (the stand-in says yes, as for any Button); XayaUI's initializeFrame did not set it either way
        cp.engine[#cp.engine + 1] = { name = nm, kind = o._kind, where = where, w = select(2, hasArea(o)), h = select(3, hasArea(o)) }
      elseif click then
        local e = { name = nm, rule = ruleOf[o] and tostring(ruleOf[o].name) or nil, kind = o._kind, where = where, viaParent = viaParent, w = w, h = h, frac = frac or 0, strata = o:GetFrameStrata(),
          by = o._clickBy or (o._mouseSet and "?" or ("never set: a " .. o._kind .. " takes clicks by default")),
          top = topOf(o)._name or ("a " .. tostring(topOf(o)._kind)), topWhere = originOf(topOf(o)), inMenu = inMenu(o) or nil,
          drag = o._scripts.OnDragStart ~= nil, scripts = (o._scripts.OnClick and "OnClick " or "") .. (o._scripts.OnMouseDown and "OnMouseDown " or "") .. (o._scripts.OnMouseUp and "OnMouseUp" or "") }
        if area then cp.mouse[#cp.mouse + 1] = e else cp.noArea[#cp.noArea + 1] = e end
      elseif o:IsMouseMotionEnabled() then
        cp.hover = cp.hover + 1
        local area, w, h, frac = hasArea(o)
        cp.hoverList[#cp.hoverList + 1] = { name = nm, rule = ruleOf[o] and tostring(ruleOf[o].name) or nil, kind = o._kind, where = where, by = o._motionBy or "?", w = w, h = h, frac = frac or 0, area = area,
          top = topOf(o)._name or ("a " .. tostring(topOf(o)._kind)), topWhere = originOf(topOf(o)), inMenu = inMenu(o) or nil,
          tip = o._scripts.OnEnter ~= nil }
      end
      if o:IsMouseEnabled() then
        local area, w, h, frac = hasArea(o)
        if area and (frac or 0) >= 0.5 then cp.big[#cp.big + 1] = { name = nm, kind = o._kind, where = where, by = o._clickBy or o._motionBy or (o._mouseSet and "?" or ("never set: a " .. o._kind .. " takes clicks by default")), w = w, h = h, frac = frac,
          click = o:IsMouseClickEnabled() and not passesClicks(o) } end
      end
      if o._wheel and area then cp.wheel[#cp.wheel + 1] = { name = nm, kind = o._kind, where = where, by = o._wheelBy or "?", w = w, h = h } end
      if o._keyboard then cp.keyboard[#cp.keyboard + 1] = { name = nm, kind = o._kind, where = where, by = o._kbBy or "?", propagate = o._propagate and true or false } end
    end
    if where and o._keyboard and not o:IsVisible() then cp.kbHidden[#cp.kbHidden + 1] = { name = o._name or ("a " .. tostring(o._kind)), kind = o._kind, where = where, by = o._kbBy or "?" } end
    if o._kind == "EditBox" and o._focus then cp.focus[#cp.focus + 1] = { name = o._name or "an edit box", where = where or "not XayaUI's", xui = where ~= nil, visible = o:IsVisible() } end
  end
  for _, key in rawipairs({ "PRINTSCREEN", "W", "SPACE" }) do
    local got = W.pressKey(key)
    cp.keys[#cp.keys + 1] = { key = key, reached = (got == "game"), ran = W.gameRan, by = (got ~= "game") and (rawget(got, "_name") or tostring(got and got._kind)) or nil,
      byWhere = (got ~= "game") and originOf(got) or nil }
  end
  if not CFG.memplay then OUT.checkpoints[#OUT.checkpoints + 1] = cp end   -- (round 9: the memory play keeps no record per cycle)
  return cp
end

-------------------------------------------------------------------------------------------------------------------------------------
-- the scenario
-------------------------------------------------------------------------------------------------------------------------------------
local regen = false   -- (as in the game, UnitAffectingCombat("player") is already true when PLAYER_REGEN_DISABLED fires; INFERENCE)
UnitAffectingCombat = function() return (W.combat or regen) and true or false end
local function fight() FIGHT_AT = W.now; regen = true; W.enterCombat(); regen = false end
local function peace() W.leaveCombat() end
local FPS = 30
local BUSY = tonumber(CFG.busy) or 15   -- seconds of fight per cycle (a shorter value only for profiling the gate itself)
local DT = 1 / FPS
local function frames(sec, each)
  local n = math.floor(sec * FPS + 0.5)
  for i = 1, n do if each then each(i) end; W.tick(DT, 1) end
end
-- (round 9, SD-79) the display effects at 144 frames a second (a high-refresh monitor; INFERENCE: her monitor's rate is not known): at
-- 30 frames a second a frame script cannot run more than 30 times a second, so her 30-a-second limit is played where it can be broken
local FPS_FX = 144
local function framesFx(sec, each)
  local n = math.floor(sec * FPS_FX + 0.5)
  for i = 1, n do if each then each(i) end; W.tick(1 / FPS_FX, 1) end
end
-- (round 9, SD-80) the measured play's hook counts instructions only, set once here and never switched (switching restarts its counter);
-- set before login so the previews and the mover before the close (SD-79) are counted too. The tree play's hook is set at the close.
if PERF and not CFG.nohook and not CFG.tree then debug.sethook(callhook, "", INS_STEP) end

setPhase("login")
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.fire("SPELLS_CHANGED"); W.fire("PLAYER_TALENT_UPDATE")
frames(5)
local ns = rawget(_G, "XayaUI_NS")
assert(ns and ns.rules, "XayaUI Rules did not load")
OUT.debugLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("XayaUI_Debug")) and true or false
OUT.variant = CFG.variant or "default"
OUT.rules = #ns.rules
OUT.folders = #(ns.folders or {})
do  -- (round 7) the rules with a talent requirement session A made (PROFILE_LUA 6b): the gate must play them
  local n = 0
  for _, r in rawipairs(ns.rules) do if type(r.talents) == "table" and #r.talents > 0 and r.talentMode and r.talentMode ~= "none" then n = n + 1 end end
  OUT.talentRules = n
end
local N = #ns.rules
LOOPMIN = math.floor(N * 0.8)
BIG[ns.rules] = N
if ns.runtime then BIG[ns.runtime] = N end
OUT.loopMin = LOOPMIN
if rawget(_G, "XayaUIMinimapButton") then ALLOWED[XayaUIMinimapButton] = true end

-- the settings window, used (as tests/fix_r2_closed_window_quiet_run.py uses it)
setPhase("window")
if ns.LoadOptions then pcall(ns.LoadOptions) end; frames(0.2)
ns = rawget(_G, "XayaUI_NS")
OUT.optionsLoaded = ns.BuildOptionsTable ~= nil
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
local APP = "CueRules"
local function settle() W.tick(0.05, 6) end
local function findW(w, pred)
  if type(w) ~= "table" then return nil end
  if pred(w) then return w end
  for _, c in rawipairs(w.children or {}) do local f = findW(c, pred); if f then return f end end
end
local used = {}
pcall(ns.ToggleUI); settle()
used.open = ACD and ACD.OpenFrames[APP] ~= nil
if used.open then
  -- first a group's page, right after the window opens (INFERENCE: after the rule clicks and the search, SelectGroup no longer
  -- reaches the group's page in the stand-in): drag its X offset slider (as tests/fix_u5rulestree_slider_drag_run.py does), open a dropdown
  local grp
  for _, f in rawipairs(ns.folders) do if f.name == "Static 2" then grp = f; break end end   -- (a group with loaded rules: it is in the "loaded" tree)
  used.group = grp and grp.name
  if grp then pcall(ACD.SelectGroup, ACD, APP, "cooldowns", "enabledTab", "loaded", grp.id); settle() end
  local function named(typ, nm)
    return findW(ACD.OpenFrames[APP], function(w)
      local o = w.GetUserData and w:GetUserData("option")
      return w.type == typ and w.frame and w.frame:IsVisible() and (not nm or (o and o.name == nm))
    end)
  end
  local slider = named("Slider", "X offset") or named("Slider")
  if slider then for step = 1, 8 do slider:Fire("OnValueChanged", step * 2); W.tick(DT, 1) end; slider:Fire("OnMouseUp", 16); settle(); used.slider = true end
  local dd = named("Dropdown", "Layer (strata)") or named("Dropdown")
  if dd and dd.button then
    W.click(dd.button); settle()                  -- opens the list as a click on the dropdown's button does
    used.dropdown = dd.open and true or false
    if dd.open then W.click(dd.button); settle() end
  elseif dd and dd.pullout and dd.pullout.Open then
    pcall(dd.pullout.Open, dd.pullout, "TOPLEFT", dd.frame, "BOTTOMLEFT", 0, 0); settle(); pcall(dd.pullout.Close, dd.pullout); used.dropdown = true
  end
  pcall(ACD.SelectGroup, ACD, APP, "cooldowns", "enabledTab", "loaded"); settle()
  local xt = findW(ACD.OpenFrames[APP], function(w) return w.type == "TreeGroup" and ns.RulesTreeStatus and w.status == ns.RulesTreeStatus() end)
  local rows = 0
  for _, b in rawipairs(xt and xt.buttons or {}) do
    if b:IsShown() and rows < 4 and tostring(b.uniquevalue or ""):find("rule", 1, true) then
      rows = rows + 1
      b:Click("LeftButton"); settle()
      IsControlKeyDown = function() return true end; b:Click("LeftButton"); IsControlKeyDown = function() return false end; settle()
      local e = b:GetScript("OnEnter"); if e then pcall(e, b) end
      local l = b:GetScript("OnLeave"); if l then pcall(l, b) end
      if rows == 2 then local up = b:GetScript("OnMouseUp"); if up then pcall(up, b, "RightButton") end; b:Click("RightButton"); settle(); used.menu = true end
    end
  end
  used.rows = rows
  if ns.MultiClear then pcall(ns.MultiClear) end; settle()
  local sb = xt and xt.xuiSearchBox
  if sb then
    W.click(sb); sb:SetText("buff 1"); local f = sb:GetScript("OnTextChanged"); if f then pcall(f, sb, true) end; W.tick(0.1, 6)
    used.search = ns.treeFilter
    local esc = sb:GetScript("OnEscapePressed"); if esc then pcall(esc, sb) end; W.tick(0.1, 4)
  end
end
-- (round 9, SD-79) a preview of the effect displays (the rule editor's preview button, RuleEditor/Sidebar.lua ns.SetPreview), one second
-- at 144 frames a second; their effects run on the sample countdown (Visual.lua SAMPLE_DURATION). Each frame script's runs are counted
-- per display (FXPRE; nothing else is measured before the close).
do
  local objs = {}
  for _, r in rawipairs(ns.rules) do if type(r.name) == "string" and r.name:find("^Fx ") then objs[#objs + 1] = r end end
  used.previewRules = #objs
  if ns.SetPreview and #objs > 0 then
    setPhase("preview"); FXPRE = PERF
    pcall(ns.SetPreview, objs, "visual", true); framesFx(1)
    pcall(ns.SetPreview, objs, "visual", false); frames(0.2)
    FXPRE = false; setPhase("window")
  end
end
-- the mover (/xui unlock), opened and closed; (round 9, SD-79) its second open at 144 frames a second, frame scripts counted per display
if ns.ToggleUnlock then
  setPhase("unlock"); FXPRE = PERF
  pcall(ns.ToggleUnlock); framesFx(1); used.moverOpen = ns.IsUnlocked and ns.IsUnlocked() or true; pcall(ns.ToggleUnlock); frames(0.5)
  FXPRE = false; setPhase("window")
end
OUT.used = used
-- she closes the window
pcall(ns.ToggleUI); W.tick(0.1, 40)
OUT.windowClosed = not (ACD and ACD.OpenFrames[APP])
setPhase("closed")
CLOSED = true
T0 = W.now
-- (round 9, SD-80) the call-counting windows: in the tree play they switch call counting (SAMPLING) on and off; in the measured play
-- they do nothing (its hook, set once below, counts instructions only)
local function sample(on)
  if not PERF then return end
  SAMPLING = on and CFG.tree and not CFG.nosample and true or false
end
local function fireSame(ev, ...) CTX = "same"; W.fire(ev, ...); CTX = "change" end
if PERF and not CFG.nohook and CFG.tree then debug.sethook(treehook, "c", INS_STEP) end   -- (round 8 repair: the tree play, see treehook)
sample(false)
checkpoint("right after the settings window closed")

-- the minimap button's list: opened, then a click on the game world
do
  local b = rawget(_G, "XayaUIMinimapButton")
  local mm = { button = b ~= nil and b:IsVisible() }
  if b then
    b:Click("LeftButton"); frames(0.2)
    local menu = rawget(_G, "XayaUIMinimapMenu")
    mm.opened = menu ~= nil and menu:IsVisible()
    local cp = checkpoint("the minimap button's list is open")
    mm.catchers = cp.mouse
    -- a click on the game world in the middle of the screen: which frame is under it?
    local top, topRank
    local RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
    for _, o in rawipairs(W.objects) do
      if o:IsVisible() and o ~= UIParent and o ~= WorldFrame and not (o._kind == "Texture" or o._kind == "FontString") and o:IsMouseClickEnabled() and not passesClicks(o) and #o._pts > 0 then
        local r = W.rect(o)
        if 960 >= r.l and 960 <= r.l + r.w and 300 >= r.b and 300 <= r.b + r.h then
          local rk = (RANK[o:GetFrameStrata()] or 3) * 1000 + (o:GetFrameLevel() or 0)
          if not topRank or rk > topRank then top, topRank = o, rk end
        end
      end
    end
    mm.clickTakenBy = top and ((top._name or ("a " .. top._kind)) .. " (" .. tostring(originOf(top) or "not XayaUI") .. ")") or nil
    if top then W.click(top, "LeftButton") else W.mouseOver = WorldFrame; W.fire("GLOBAL_MOUSE_DOWN", "LeftButton"); W.fire("GLOBAL_MOUSE_UP", "LeftButton"); W.mouseOver = nil end
    frames(0.2)
    mm.closedByClick = not (menu and menu:IsVisible())
    -- Esc
    if mm.closedByClick then
      b:Click("LeftButton"); frames(0.2)
      local special = false
      for _, n in rawipairs(UISpecialFrames or {}) do if n == "XayaUIMinimapMenu" then special = true end end
      mm.escCloses = special
      local got = W.pressKey("ESCAPE")
      if special and menu and menu:IsVisible() and got == "game" then menu:Hide() end   -- (the game's Esc closes UISpecialFrames)
      mm.escKey = (got == "game") and "reached the game" or ("kept by " .. tostring(got._name or got._kind))
      if menu and menu:IsVisible() then b:Click("LeftButton"); frames(0.2) end
    end
    mm.closedAtEnd = not (menu and menu:IsVisible())
  end
  OUT.minimap = mm
  checkpoint("after the minimap list closed")
end

-- the busiest case: 60 seconds in three 20-second cycles
local BUFFS = {}
for i = 1, 66 do BUFFS[#BUFFS + 1] = 300000 + i end
for i = 1, 24 do BUFFS[#BUFFS + 1] = 310000 + i end
for i = 1, 20 do BUFFS[#BUFFS + 1] = 320000 + i end
local active = {}   -- instance ids of the auras up now, oldest first
local bi, ci = 0, 0
local function gainOne(dur)
  bi = bi % #BUFFS + 1
  local id = BUFFS[bi]
  local old = G.auras[id]
  if old then G.lose(id) end
  local a = G.gain(id, dur)
  active[#active + 1] = a
  local rem = old and { old.auraInstanceID } or nil
  G.syncContainers()
  W.fire("UNIT_AURA", "player", { addedAuras = { a }, removedAuraInstanceIDs = rem })
end
local function loseOldest()
  local a = table.remove(active, 1)
  if a and G.auras[a.spellId] == a then G.lose(a.spellId); G.syncContainers(); W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { a.auraInstanceID } }) end
end
OUT.fired = {}   -- (round 8) how often the scenario fired each of the fight's change events (an integrity check reads it)
local function cfire(ev, ...) OUT.fired[ev] = (OUT.fired[ev] or 0) + 1; W.fire(ev, ...) end
local function storm(i)
  CTX = "storm"
  local a = active[(i % math.max(#active, 1)) + 1]
  if a then a.expirationTime = W.now + a.duration; W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { a.auraInstanceID } })
  else W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 1 } }) end
  W.fire("UNIT_AURA", "target", { updatedAuraInstanceIDs = { 2 } })
  W.fire("SPELL_UPDATE_COOLDOWN")
  W.fire("SPELL_UPDATE_CHARGES")
  W.fire("ACTIONBAR_UPDATE_COOLDOWN"); W.fire("ACTIONBAR_UPDATE_STATE"); W.fire("ACTIONBAR_UPDATE_USABLE")
  W.fire("UNIT_POWER_FREQUENT", "player", "FURY")
  if i % 15 == 0 then gainOne(12) end                      -- an aura gained every half second
  if i % 15 == 7 and #active > 10 then loseOldest() end     -- and an old one lost
  if i % 21 == 0 then                                      -- a spell cast every 0.7 s: its cooldown starts
    ci = ci % 40 + 1
    G.cast(400000 + ci, 8)
    W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1-1-1-" .. (400000 + ci) .. "-0000", 400000 + ci)
  end
  if i % 30 == 0 then                                      -- the target's debuffs change once a second
    local k = (i / 30) % 16 + 1
    G.targetDebuffs = { { spellId = 340000 + k, auraInstanceID = 9000 + k, duration = 10, expirationTime = W.now + 10, applications = 1, sourceUnit = "player" } }
    W.fire("UNIT_AURA", "target", { isFullUpdate = false, addedAuras = G.targetDebuffs })
  end
  -- (round 8; round 7 review: the gate never played these, and each one re-checks every live rule) a fight with movement, a Death
  -- Knight's runes, a totem and a stun. Each is a real change of something a rule reads, so it is fired as a change event, not a storm.
  -- Payloads as docs/reference/api/events.md has them: PLAYER_STARTED_MOVING / PLAYER_STOPPED_MOVING (:1217, :1220; none),
  -- RUNE_POWER_UPDATE (:1334; runeIndex, added?; SecretPayloads: the stand-in hands plain numbers, INFERENCE that a handler that copes
  -- with a secret copes with a plain number), PLAYER_TOTEM_UPDATE (:1225; totemSlot), LOSS_OF_CONTROL_ADDED (:973; unitTarget,
  -- effectIndex), LOSS_OF_CONTROL_UPDATE (:976; unitTarget). How often (INFERENCE, a busy Mythic+ pull): she starts or stops moving every
  -- half second (4 events a second), a rune changes 3 times a second, a totem every 3 seconds, a stun every 5 seconds (added, then two updates).
  CTX = "change"
  if i % 15 == 3 then cfire("PLAYER_STARTED_MOVING") elseif i % 15 == 10 then cfire("PLAYER_STOPPED_MOVING") end
  if i % 10 == 6 then cfire("RUNE_POWER_UPDATE", math.floor(i / 10) % 6 + 1, nil) end
  if i % 90 == 45 then cfire("PLAYER_TOTEM_UPDATE", 1) end
  if i % 150 == 75 then cfire("LOSS_OF_CONTROL_ADDED", "player", 1)
  elseif i % 150 == 76 or i % 150 == 120 then cfire("LOSS_OF_CONTROL_UPDATE", "player") end
end
local function memNow() gc("collect"); return gc("count") end
-- (round 9, item 7 of the round 9 gate task; SD-66) the memory play (CFG.memplay: no instruments, nothing the gate keeps per cycle):
-- the stand-in's list of sounds played (world.lua W.sounds: the game keeps no such list in Lua) is emptied before each reading, so the
-- growth from cycle to cycle is the addons' own (with the stand-in's widget records of the frames they made)
local function memRead()
  if CFG.memplay then W.sounds = {} end
  return memNow()
end
if PERF or CFG.memplay then OUT.memStart = memRead() end
local cycleWin = {}
-- (round 9, SD-77, her answer "Route + narrow (Recommended)") the draw check, played only in the draw play (CFG.drawcheck; nothing is
-- measured there): after a moment that changes load facts, and 6 frames (0.2 s) with no event so every pass held to the pace has run,
-- what every display shows is read; then the engine re-checks EVERY rule (ns.MarkDirty: a settings change, which Engine.lua re-checks in
-- full) in frames of 0 s (nothing that runs on time moves), and what every display shows is read again. A re-check narrowed to the
-- changed fact that missed a rule whose answer or drawing reads that fact (a target debuff that must be absent, an out-of-combat opacity,
-- a boss rule) leaves its display different from the full re-check. Read per display: shown or not; while shown, its opacity, text, gray
-- and color; per aura group of Blizzard's container: whether the engine has it on.
OUT.drawCheck = {}
local DC_GROUPS = { "Absent", "Ooc", "Boss" }
local function drawSnap()
  dframes()
  local snap, groups, n = {}, {}, 0
  for _, g in rawipairs(DC_GROUPS) do groups[g] = { rules = 0, shown = 0, alpha = {} } end
  for idx, r in rawipairs(ns.rules) do
    local f = DFRAMES and DFRAMES[r]
    if f then
      local shown = f:IsVisible()
      local st
      if shown then
        local vc = f.tex and rawget(f.tex, "_vc")
        st = string.format("shown, opacity %s, text %s, gray %s, color %s", tostring(rawget(f, "_alpha")), tostring(f.text and rawget(f.text, "_text")),
          tostring(f.tex and rawget(f.tex, "_desat")), vc and table.concat({ tostring(vc[1]), tostring(vc[2]), tostring(vc[3]), tostring(vc[4]) }, "/") or "-")
      else st = "hidden" end
      snap[idx .. " " .. tostring(r.name)] = st; n = n + 1
      local g = type(r.name) == "string" and groups[r.name:match("^(%a+) %d+$") or ""]
      if g then g.rules = g.rules + 1; if shown then g.shown = g.shown + 1; g.alpha[#g.alpha + 1] = tostring(rawget(f, "_alpha")) end end
    end
  end
  for i, e in rawipairs(G.buttons) do snap["aura group " .. i] = e.opts.xuiOff and "off" or "on"; n = n + 1 end
  for _, g in rawipairs(DC_GROUPS) do groups[g].alpha = table.concat(groups[g].alpha, ",") end
  return snap, groups, n
end
local function drawCheck(label)
  if not CFG.drawcheck then return end
  W.tick(DT, 6)
  local a, ga, n = drawSnap()
  local ES = ns.EngineStats
  local s0 = ES and ES.settle or 0
  pcall(ns.MarkDirty)
  W.tick(0, 3)
  local ran = (ES and ES.settle or 0) > s0
  local b = drawSnap()
  local diffs = {}
  for k, v in rawpairs(a) do if b[k] ~= v then diffs[#diffs + 1] = k .. ": " .. v .. " -> after the full re-check: " .. tostring(b[k]) end end
  for k, v in rawpairs(b) do if a[k] == nil then diffs[#diffs + 1] = k .. ": none -> after the full re-check: " .. v end end
  table.sort(diffs)
  local keep = {}
  for i = 1, math.min(#diffs, 12) do keep[i] = diffs[i] end
  OUT.drawCheck[#OUT.drawCheck + 1] = { label = label, phase = PHASE, combat = W.combat and true or false, ran = ran, n = n, ndiff = #diffs,
    diffs = keep, groups = ga }
end
-- call counting (slow in the stand-in) runs around every state-change event and for 15 frames of each fight, the same in every
-- cycle, so the counts of the three cycles compare; the other instruments run all the time (round 9, SD-80: the counting in the tree
-- play only)
local function sfire(ev, ...) sample(true); W.fire(ev, ...); sample(false) end
local function sfireSame(ev, ...) sample(true); fireSame(ev, ...); sample(false) end
-- (round 9, SD-77 condition 3) a boss pull in every fight: a Mythic+ pull that runs from the trash into the boss (INFERENCE about her
-- play): ENCOUNTER_START 8 s into the fight, ENCOUNTER_END 14 s in (the boss down), combat ending after the fight
local BOSS_AT, BOSS_END, BOSS_ID = 240, 420, 2001
for cyc = 1, 3 do
  setPhase("busy " .. cyc)
  BSEG = "out " .. cyc   -- (V33 budget segments, see budFrame: work done between two frames is billed to the next frame)
  for k in rawpairs(WCALLS) do WCALLS[k] = nil end
  -- every cycle plays the same thing from the same start (so a count that grows from cycle to cycle is the addon's, not the input's)
  G.clear(); active = {}; bi, ci = 0, 0; G.targetDebuffs = {}; G.syncContainers()
  sfire("UNIT_AURA", "player", { isFullUpdate = true })
  -- a loading screen into the zone
  sfire("LOADING_SCREEN_ENABLED"); sfire("PLAYER_LEAVING_WORLD")
  sfire("PLAYER_ENTERING_WORLD", false, false); sfire("ZONE_CHANGED_NEW_AREA"); sfire("LOADING_SCREEN_DISABLED")
  frames(1)
  -- mounted, then dismounted
  G.mounted = true; sfire("PLAYER_MOUNT_DISPLAY_CHANGED"); sfire("UNIT_AURA", "player", { isFullUpdate = true }); frames(1)
  drawCheck("mounted")
  G.mounted = false; sfire("PLAYER_MOUNT_DISPLAY_CHANGED"); sfire("UNIT_AURA", "player", { isFullUpdate = true }); frames(0.5)
  drawCheck("dismounted")
  -- a group joined (the game sends the roster update twice), a target picked
  G.group = true; sfire("GROUP_ROSTER_UPDATE"); sfireSame("GROUP_ROSTER_UPDATE"); frames(0.25)
  drawCheck("group joined")
  G.target = true; sfire("PLAYER_TARGET_CHANGED"); frames(0.25)
  drawCheck("target picked")
  -- the fight: 15 seconds of storms
  BSEG = "fight " .. cyc   -- (the fight's first second is judged like the rest of it)
  moment("combat start")
  sample(true); fight(); sample(false)
  for _ = 1, 4 do gainOne(30) end
  frames(BUSY, function(i)
    -- (the draw play only: right after the moment, before the next storm event, so a target's aura event cannot re-check a missed rule
    -- first; the check itself lets 6 quiet frames pass before it reads)
    if i == 1 then drawCheck("combat start") end
    if i == BOSS_AT + 1 then drawCheck("boss pull") end
    if i == BOSS_END + 1 then drawCheck("boss down") end
    if i == 31 then sample(true) elseif i == 46 then sample(false) end
    storm(i)
    if i == 200 then sfireSame("GROUP_ROSTER_UPDATE") end   -- someone joins mid-fight (the player's group state does not change)
    if i == BOSS_AT then
      G.encounter = true; moment("boss pull")
      sample(true); cfire("ENCOUNTER_START", BOSS_ID, "Gate Boss", 16, 20); sample(false)
    elseif i == BOSS_END then
      G.encounter = false; moment("boss down")
      sample(true); cfire("ENCOUNTER_END", BOSS_ID, "Gate Boss", 16, 20, 1, {}); sample(false)
    end
  end)
  sample(false)
  local cpFight = checkpoint("in the fight, cycle " .. cyc)
  if not CFG.memplay then OUT.mouseCombat[cyc] = cpFight end
  -- (round 9, SD-77) combat ending, and the second after it, are a measured segment of their own ("end N"), judged by the per-event cap
  BSEG = "end " .. cyc
  moment("combat end")
  sample(true); peace(); sample(false)
  frames(0.5)
  drawCheck("combat end")
  frames(0.5)
  BSEG = "out " .. cyc
  -- the group leaves, the target is dropped
  G.group = false; sfire("GROUP_ROSTER_UPDATE"); G.target = false; G.targetDebuffs = {}; sfire("PLAYER_TARGET_CHANGED")
  frames(0.5)
  drawCheck("group left, target dropped")
  checkpoint("out of combat after the fight, cycle " .. cyc)
  frames(0.5)
  if PERF then
    local snap = {}
    for k, n in rawpairs(WCALLS) do snap[k] = n end
    ST.cyc[cyc] = snap
  end
  if PERF or CFG.memplay then
    OUT.mem = OUT.mem or {}
    OUT.mem[cyc] = memRead()
  end
end
-- (round 9, SD-79, her answer "<=30/s, stop if idle (Recommended)") the display effects, out of combat, at 144 frames a second: the six
-- effect displays and the bar cue (PROFILE_LUA 6d) gain their buff for 6 s and are left to run out (fade, the flash from its 3 s
-- threshold, the wipe, tenths below 5 s, the bar), the buffs' removal comes as they expire, then a second with nothing to animate
setPhase("effects")
BSEG = "effects"
G.clear(); active = {}; G.targetDebuffs = {}; G.syncContainers()
W.fire("UNIT_AURA", "player", { isFullUpdate = true })
frames(0.5)
do
  local fxA = {}
  for _, id in rawipairs({ 330001, 330002, 330003, 330004, 330005, 330006, 330010 }) do fxA[#fxA + 1] = G.gain(id, 6) end
  G.syncContainers()
  W.fire("UNIT_AURA", "player", { addedAuras = fxA })
  framesFx(0.1)
  local shown = 0
  dframes()
  for _, r in rawipairs(ns.rules) do
    local f = DFRAMES and DFRAMES[r]
    if f and type(r.name) == "string" and r.name:find("^Fx ") and f:IsVisible() then shown = shown + 1 end
  end
  OUT.fxGained, OUT.fxShown = #fxA, shown
  framesFx(5.9)
  local rem = {}
  for _, a in rawipairs(fxA) do G.lose(a.spellId); rem[#rem + 1] = a.auraInstanceID end
  G.syncContainers()
  W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = rem })
  framesFx(1)
end
-- idle out of combat: every aura and cooldown gone, nothing on screen changing
setPhase("idle settle")
BSEG = "idle settle"
G.clear(); active = {}; G.syncContainers()
W.fire("UNIT_AURA", "player", { isFullUpdate = true }); W.fire("SPELL_UPDATE_COOLDOWN")
frames(5)
BSEG = "idle"
for w = 1, 3 do
  setPhase("idle " .. w)
  for k in rawpairs(WCALLS) do WCALLS[k] = nil end
  sample(true); frames(2); sample(false)   -- call counting for the first 2 seconds of each window
  frames(8)
  local snap = {}
  for k, n in rawpairs(WCALLS) do snap[k] = n end
  ST.idlewin[w] = snap
end
debug.sethook()
BSEG = nil; for a in rawpairs(BFRAME) do BFRAME[a] = nil end
OUT.budget = BUD
local pace = {}
for src, p in rawpairs(PACE) do pace[src] = { kind = p.kind, kinds = p.kinds, drivers = p.drivers, over = p.over, quiet = p.quiet, allVis = p.allVis, firstSec = p.firstSec, most = p.most, first = p.first } end
OUT.pace = pace
local paceAny = {}
for src, p in rawpairs(PACEX) do paceAny[src] = { over = p.over, firstSec = p.firstSec, most = p.most, first = p.first, drivers = p.drivers } end
OUT.paceAny = paceAny
-- (round 9, SD-79) every frame script, per frame it ran on (ownNote)
local owners = {}
for i, rec in rawipairs(OWNLIST) do
  local wins = {}
  for _, ww in rawpairs(rec.wins) do wins[#wins + 1] = ww end
  owners[i] = { display = rec.display, rule = rec.rule, where = rec.where, src = rec.src, runs = rec.runs, skips = rec.skips, changed = rec.changed,
    idle = rec.idle, most = rec.most, over = rec.over, first = rec.first, idleOver = rec.idleOver, firstIdle = rec.firstIdle, runsBy = rec.runsBy,
    attaches = rec.att, wins = wins, waits = rec.waits, waitOver = rec.waitOver, firstWait = rec.firstWait, times = rec.display and rec.times or nil }
end
OUT.owners = owners
OUT.fxRedraw = TRED   -- (repair 1, tree play) the listed redraw timers' runs, per callback and per display
OUT.fxN, OUT.fxSkip, OUT.fpsFx, OUT.fxWait = FX_N, FX_SKIP, FPS_FX, FX_WAIT
OUT.paceN = PACE_N
local fpace = {}
for f, p in rawpairs(FILEPACE) do fpace[f] = p.most end
OUT.filePace = fpace
local fresh = {}
for site, g in rawpairs(FRESH) do fresh[site] = { fresh = g.fresh, calls = g.calls, example = g.example } end
OUT.timerFresh = fresh
if PERF or CFG.memplay then OUT.memEnd = memRead() end
checkpoint("after 30 seconds idle out of combat")
-- timers still waiting at the end, by who made them
local pend = {}
for _, t in rawipairs(W.timers) do if not t.cancelled then local s = pend[t.src or "?"]; if not s then s = { n = 0, kind = t.kind, every = t.every, left = t.left }; pend[t.src or "?"] = s end; s.n = s.n + 1 end end
OUT.timersPending = pend
OUT.timersMade = TIMERS_SEEN
OUT.timerEdges = TIMER_EDGES
OUT.kbCalls = KBCALLS
OUT.mouseCalls = MOUSECALLS
OUT.nonint = NONINT
OUT.frames = FRAMES
OUT.fps = FPS
OUT.stats = ST
OUT.errors = #W.errors
OUT.errorText = {}
for i = 1, math.min(#W.errors, 12) do OUT.errorText[i] = tostring(W.errors[i]):sub(1, 400) end
OUT.now = W.now
return OUT
end
'''


# (round 9 repair 1; SD-76 asked "whether 10/s covers screen redraws"; her answer SD-79 "<=30/s, stop if idle (Recommended)": redraws at
# most 30 a second per display, counted per display) the timer callbacks that only redraw displays, judged per display (at most 30 in any
# second, together with the display's frame-script runs) and for idle runs, instead of P2's 10 a second per callback. A callback here is
# still judged under P2 if a run changes anything outside the displays or runs a re-check pass (gate_performance_run.py REPASSES; a pass
# is judged at 10 a second whatever drives it, SD-78). [addon file] = ((function name as written in the file, what it is), ...)
REDRAWS = {
    "XayaUI_Rules/Visual.lua": (("FxWake", "the display effects' wake (draws each display whose time-driven part changes at that moment)"),),
}


def redraw_lines(root=None):
    """({"file:line": (name, what)}, [names not found]) for REDRAWS, the line being where the function is defined (as the gate keys
    functions)."""
    out, missing = {}, []
    for f, names in sorted(REDRAWS.items()):
        path = os.path.join(root or ROOT, f)
        lines = []
        if os.path.isfile(path):
            with open(path, encoding="utf-8", errors="replace") as fh:
                lines = fh.read().split("\n")
        for name, what in names:
            pat = re.compile(r"^\s*(?:local\s+)?(?:function\s+%s\s*\(|%s\s*=\s*function\s*\()" % (re.escape(name), re.escape(name)))
            hit = next((i + 1 for i, ln in enumerate(lines) if pat.search(ln)), None)
            if hit is None:
                missing.append("%s %s" % (f, name))
            else:
                out["%s:%d" % (f, hit)] = (name, what)
    return out, missing


def run_scenario(perf=True, verbose=False, variant="default", tree=False, drawcheck=False, memplay=False):
    """Sessions A and B. Returns (result as Python data, seconds). variant: "default" (Advanced Debugging off) or "debug" (on).
    tree (round 8 repair): the play that takes the call trees of timer callbacks and frame scripts (P2 pace per re-check pass) and
    (round 9, SD-80) the call counts; its instruction readings are not used (its hook changes them).
    drawcheck (round 9, SD-77): the draw play (perf off): after each moment that changes load facts, what is drawn is compared with what a
    full re-check draws. memplay (round 9): the memory play (perf off): Lua memory at the end of each cycle with nothing of the gate's kept."""
    t0 = time.time()
    saved, n, made, nf, errs_a = build_profile()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world, loader, game, sv = _world(L, saved, debug=("on" if variant == "debug" else "off"))
    cfg = H.to_lua(L, {"perf": perf, "verbose": verbose or bool(os.environ.get("XUI_GATE_VERBOSE")), "variant": variant,
                        "nosample": bool(os.environ.get("XUI_GATE_NOSAMPLE")), "nohook": bool(os.environ.get("XUI_GATE_NOHOOK")),
                        "busy": float(os.environ.get("XUI_GATE_BUSY", "15")), "tree": bool(tree), "drawcheck": bool(drawcheck),
                        "memplay": bool(memplay), "redraws": {k: True for k in redraw_lines()[0]}})
    rl = redraw_lines()[0]
    res = L.eval("function(src, W, Ld, G, C) return loadstring(src)()(W, Ld, G, C) end")(SCENARIO_LUA, world, loader, game, cfg)
    out = H.lua_to_py(res)
    out["profile"] = {"entries": n, "made": made, "groups": nf, "errorsA": errs_a}
    out["redrawLines"] = {k: list(v) for k, v in rl.items()}
    return out, round(time.time() - t0, 1)


# ---------------------------------------------------------------------------------------------------------------------------------
# one run for the three gates: the scenario takes about two minutes, so its result is kept on disk under a key made from every file
# it reads (the addon folders, this file, the harness and the API index); any change to one of them runs it again.
# XUI_GATE_NOCACHE=1 always runs it.
# ---------------------------------------------------------------------------------------------------------------------------------
def _key(variant="default"):
    h = hashlib.sha1()
    h.update(("variant=" + variant).encode())
    files = []
    for name in sorted(os.listdir(ROOT)):
        d = os.path.join(ROOT, name)
        if (name in ADDONS or name == DEBUG_ADDON) and os.path.isdir(d):
            for base, dirs, fs in os.walk(d):
                dirs.sort()
                files += [os.path.join(base, f) for f in sorted(fs)]
    hd = os.path.join(HERE, "harness")
    files += [os.path.join(hd, f) for f in sorted(os.listdir(hd)) if f.endswith((".lua", ".py"))]
    api = os.environ.get("XUI_API_INDEX")
    if api and os.path.isfile(api):
        files.append(os.path.abspath(api))
    # this file's part that runs the game: the three Lua chunks and the functions that start them (the reporting code below is not
    # part of the key, so a change to how a gate reads the result does not run the scenario again)
    for part in (GAME_LUA, PROFILE_LUA, SCENARIO_LUA, inspect.getsource(_world), inspect.getsource(build_profile), inspect.getsource(run_scenario)):
        h.update(part.encode())
    h.update(ROOT.encode())
    h.update((api or "").encode())
    h.update(repr(sorted(REDRAWS.items())).encode())   # (repair 1: the redraw callbacks the tree play keeps per display)
    for f in files:
        h.update(f.encode())
        with open(f, "rb") as fh:
            h.update(fh.read())
    for k in ("XUI_GATE_BUSY", "XUI_GATE_NOSAMPLE", "XUI_GATE_NOHOOK", "XUI_GATE_NOTREE"):
        h.update((k + "=" + os.environ.get(k, "")).encode())
    return h.hexdigest()


def result(variant="default"):
    """The scenario's result (cached; see above). Returns (data, seconds the scenario took, True when read from the cache).
    variant (round 8): "default" (Advanced Debugging off) or "debug" (on: XayaUI_Debug loaded)."""
    d = os.path.join(tempfile.gettempdir(), "xui_gate_cache")
    path = os.path.join(d, _key(variant) + ".json")
    if not os.environ.get("XUI_GATE_NOCACHE") and os.path.isfile(path):
        with open(path) as fh:
            data = json.load(fh)
        return data, data.get("_secs", 0), True
    data, secs = run_scenario(perf=True, variant=variant)
    # (round 8 repair) the pace per re-check pass comes from a second play with the call trees taken (run_scenario tree=True); every
    # other reading stays this play's. XUI_GATE_NOTREE=1 (an old build played for the V33 calibration or the teeth proofs, tree_env)
    # keeps this play's pace per callback only.
    # (round 9, SD-80, her answer "Fix it (Recommended)") the call counts (a function called once per rule in one dispatch, P3; call
    # counts growing from cycle to cycle, P6) come from that second play too: the measured play counts no call, so its instructions are
    # what a play without call counting reads. (round 9, SD-77) a third play checks what is drawn after each load-fact change against a
    # full re-check, and (round 9) a fourth reads Lua memory with nothing of the gate's kept (the growth per cycle is the addons' own).
    # XUI_GATE_NOTREE=1 plays none of the three: no call counts, no draw check, no memory play (only an old build's numbers are read).
    if not os.environ.get("XUI_GATE_NOTREE") and not os.environ.get("XUI_GATE_NOHOOK"):
        tdata, tsecs = run_scenario(perf=True, variant=variant, tree=True)
        data["pace"], data["paceAny"], data["paceTree"] = tdata.get("pace"), tdata.get("paceAny"), True
        data["fxRedraw"] = tdata.get("fxRedraw") or {}   # (repair 1) the listed redraw timers, per display (tree play only)
        st, tst = data.setdefault("stats", {}), tdata.get("stats") or {}
        for k in ("wide", "cyc", "idlewin"):
            st[k] = tst.get(k)
        data["callsFrom"] = "tree play"
        ddata, dsecs = run_scenario(perf=False, variant=variant, drawcheck=True)
        data["drawCheck"], data["drawErrors"], data["drawErrorText"] = ddata.get("drawCheck"), ddata.get("errors"), ddata.get("errorText")
        mdata, msecs = run_scenario(perf=False, variant=variant, memplay=True)
        data["memAddons"] = {"mem": mdata.get("mem"), "memEnd": mdata.get("memEnd"), "memStart": mdata.get("memStart"),
                             "errors": mdata.get("errors")}
        secs = round(secs + tsecs + dsecs + msecs, 1)
    data["_secs"] = secs
    os.makedirs(d, exist_ok=True)
    tmp = path + ".%d.tmp" % os.getpid()
    with open(tmp, "w") as fh:
        json.dump(data, fh, default=str)
    os.replace(tmp, path)
    with open(path) as fh:            # (read back: the gates judge exactly what JSON keeps, cached or not)
        data = json.load(fh)
    return data, secs, False


def cache_path(variant="default"):
    """Where result() keeps this checkout's scenario result (used by tree_result below, in its own process)."""
    return os.path.join(tempfile.gettempdir(), "xui_gate_cache", _key(variant) + ".json")


# ---------------------------------------------------------------------------------------------------------------------------------
# V33 (round 7): the same scenario played on an older build, for the work budget's calibration and for the proofs that the gate's
# checks have teeth (tests/v33_budget_teeth_run.py). A build is the addon folders at a git commit, unpacked once into the temp folder
# next to a copy of this checkout's gate files and harness (so it plays exactly this scenario in exactly this stand-in), and played
# in its own Python process (the harness reads the addons from the folder it sits in).
# ---------------------------------------------------------------------------------------------------------------------------------
V33_BASE_COMMIT = "ad60a051"   # origin/main before bundle 1: her install when she read AddOn Usage (REQUEST-LOG SD-38)


def scenario_stamp():
    """A short hash of the scenario itself (the game stand-in, the profile and the play)."""
    return hashlib.sha1((GAME_LUA + PROFILE_LUA + SCENARIO_LUA).encode()).hexdigest()[:12]


def _harness_files():
    """This checkout's harness files a tree copy takes (not its reports)."""
    hd = os.path.join(HERE, "harness")
    return [os.path.join(hd, f) for f in sorted(os.listdir(hd)) if f.endswith((".lua", ".py", ".json"))]


def _gate_files():
    """This checkout's gate files a tree copy takes, refreshed on every use (the scenario is in gate_common.py, so the copy's
    folder is named by the scenario, not by these files: a change to how a gate reads the result does not play the old build again)."""
    return [os.path.join(HERE, f) for f in sorted(os.listdir(HERE)) if f.startswith(("gate_", "v33_budget_")) and f.endswith(".py")]


def _put(src, to):
    """Copy one file into a tree copy unless it is already the same (written whole, then moved into place)."""
    import shutil
    with open(src, "rb") as fh:
        new = fh.read()
    if os.path.isfile(to):
        with open(to, "rb") as fh:
            if fh.read() == new:
                return
    os.makedirs(os.path.dirname(to), exist_ok=True)
    tmp = to + ".%d.tmp" % os.getpid()
    with open(tmp, "wb") as fh:
        fh.write(new)
    os.replace(tmp, to)


def tree_copy(commit, repo=None):
    """The addon folders at a git commit plus this checkout's harness and gate files, under the temp folder (unpacked once per commit,
    scenario and harness, then reused). Returns the folder, or raises RuntimeError with the reason (no git, unknown commit)."""
    import shutil, subprocess, tarfile, io
    repo = repo or os.environ.get("XUI_V33_REPO") or ROOT
    h = hashlib.sha1((commit + scenario_stamp()).encode())
    for part in (inspect.getsource(_world), inspect.getsource(build_profile), inspect.getsource(run_scenario)):
        h.update(part.encode())
    for f in _harness_files():
        h.update(os.path.relpath(f, HERE).encode())
        with open(f, "rb") as fh:
            h.update(fh.read())
    dest = os.path.join(tempfile.gettempdir(), "xui_v33_trees", "%s-%s" % (commit, h.hexdigest()[:12]))
    if not os.path.isfile(os.path.join(dest, ".complete")):
        try:
            ls = subprocess.run(["git", "-C", repo, "ls-tree", "--name-only", commit], capture_output=True, timeout=60)
            have = set(ls.stdout.decode(errors="replace").split()) if ls.returncode == 0 else set(ADDONS)
            # (round 8) the addon folders the commit has (ad60a051 has no XayaUI_Debug; git archive refuses a path it does not have)
            parts = [a for a in ADDONS + (DEBUG_ADDON,) if a in have] or list(ADDONS)
            r = subprocess.run(["git", "-C", repo, "archive", commit] + parts, capture_output=True, timeout=120)
        except (OSError, subprocess.SubprocessError) as e:
            raise RuntimeError("git could not be run: %s" % e)
        if r.returncode != 0:
            raise RuntimeError("git archive %s failed in %s: %s" % (commit, repo, r.stderr.decode(errors="replace").strip()[:200]))
        tmp = dest + ".%d.tmp" % os.getpid()
        os.makedirs(tmp, exist_ok=True)
        with tarfile.open(fileobj=io.BytesIO(r.stdout)) as tf:
            for m in tf.getmembers():   # (our own repository's folders; nothing outside the copy)
                if m.name.startswith("/") or ".." in m.name.split("/"):
                    raise RuntimeError("unexpected path in git archive: %s" % m.name)
            tf.extractall(tmp)
        for f in _harness_files() + _gate_files():
            _put(f, os.path.join(tmp, "tests", os.path.relpath(f, HERE)))
        open(os.path.join(tmp, ".complete"), "w").close()
        try:
            os.replace(tmp, dest)
        except OSError:                    # (another process made it first)
            shutil.rmtree(tmp, ignore_errors=True)
    for f in _gate_files():
        _put(f, os.path.join(dest, "tests", os.path.relpath(f, HERE)))
    return dest


def tree_env(tree):
    """The environment a tree copy is played in: its own API index, and the repository for its own baseline (git)."""
    env = dict(os.environ)
    own = os.path.join(tree, "tests", "harness", "api_index.json")
    # (round 8) a checkout without the generated index (a fresh clone) plays the copy with the index this run was given
    env["XUI_API_INDEX"] = own if os.path.isfile(own) else os.environ.get("XUI_API_INDEX", own)
    env["XUI_V33_REPO"] = os.environ.get("XUI_V33_REPO") or ROOT
    env["XUI_GATE_NOTREE"] = "1"   # (round 8 repair) an old build's pace is not judged: no second play for its call trees
    return env


def tree_result(tree):
    """The scenario's result for a tree copy (cached like result()). Returns (data, seconds); raises RuntimeError when it did not run."""
    import subprocess
    code = ("import sys; sys.path.insert(0, %r); import gate_common as GC; GC.result(); print(GC.cache_path())" % os.path.join(tree, "tests"))
    t0 = time.time()
    r = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True, cwd=tree, env=tree_env(tree), timeout=1800)
    if r.returncode != 0:
        raise RuntimeError("the scenario did not run in %s: %s" % (tree, (r.stderr or r.stdout).strip()[-400:]))
    path = (r.stdout.strip().splitlines() or [""])[-1]
    with open(path) as fh:
        return json.load(fh), round(time.time() - t0, 1)


def v33_baseline():
    """The V33 calibration run: the scenario on V33_BASE_COMMIT. Returns (data, text saying how it was got) or (None, the reason)."""
    try:
        tree = tree_copy(V33_BASE_COMMIT)
        data, secs = tree_result(tree)
    except (RuntimeError, OSError, ValueError) as e:
        return None, str(e)
    return data, "played now on %s in this scenario (%s; %.0f s, or the cached result)" % (V33_BASE_COMMIT, tree, secs)


def seg_per_frame(data, segs, addon):
    """An addon's work per frame (Lua instructions of its handlers) over the named budget segments, and the frames counted."""
    B = data.get("budget") or {}
    w = sum(((B.get(s) or {}).get("work") or {}).get(addon, 0) for s in segs)
    n = sum((B.get(s) or {}).get("frames", 0) for s in segs)
    return (w / float(n) if n else 0.0), n


# ---------------------------------------------------------------------------------------------------------------------------------
# reporting
# ---------------------------------------------------------------------------------------------------------------------------------
class Report:
    """Collects violations (FAIL) and warnings for one gate and prints them; the last line is what tests/run_all.py reads."""

    def __init__(self, gate):
        self.gate, self.fails, self.warns, self.notes = gate, [], [], []

    def fail(self, where, what, numbers, fix):
        self.fails.append((where, what, numbers, fix))

    def warn(self, where, what, numbers="", fix=""):
        self.warns.append((where, what, numbers, fix))

    def note(self, text):
        self.notes.append(text)

    def show(self, data, secs, cached):
        print("%s (V27 release gate; XayaUI + XayaUI_Options + XayaUI_Rules%s, %s rules, %s groups; scenario %.0f s%s)" % (
            self.gate, " + XayaUI_Debug (Advanced Debugging on: variant \"debug\")" if data.get("variant") == "debug" else "",
            data.get("rules"), data.get("folders"), secs or 0, ", result from the cache" if cached else ""))
        for t in self.notes:
            print("  " + t)
        for i, (where, what, numbers, fix) in enumerate(self.fails, 1):
            print("FAIL %d [%s] %s" % (i, self.gate, where))
            print("    what:    " + what)
            if numbers:
                print("    numbers: " + numbers)
            if fix:
                print("    fix:     " + fix)
        for where, what, numbers, fix in self.warns:
            print("WARNING [%s] %s" % (self.gate, where))
            print("    what:    " + what)
            if numbers:
                print("    numbers: " + numbers)
            if fix:
                print("    note:    " + fix)
        print("UNVERIFIED IN GAME: the stand-in game (tests/harness/world.lua) is a mock; a pass here is not proof of in-game behavior (V25).")
        print("%s: %d violation(s), %d warning(s)  FAILS: %d" % (self.gate, len(self.fails), len(self.warns), len(self.fails)))
        return 1 if self.fails else 0


class Tagged(object):
    """(round 9) A Report seen through a variant's name: every finding of the "debug" variant says which variant it came from."""

    def __init__(self, rep, tag):
        self.rep, self.tag = rep, tag

    def fail(self, where, what, numbers, fix):
        self.rep.fail(self.tag + where, what, numbers, fix)

    def warn(self, where, what, numbers="", fix=""):
        self.rep.warn(self.tag + where, what, numbers, fix)

    def note(self, text):
        self.rep.note(self.tag + text)


DEBUG_TAG = "[Advanced Debugging on] "


def both_variants(gate, judge):
    """(round 9; REQUEST-LOG A23 SD-64: she keeps Advanced Debugging on; round 8 review: gate_mouse and gate_keyboard judged only the
    default variant) a gate's judge on the default variant and, when this checkout has XayaUI_Debug, on the "debug" variant (Advanced
    Debugging on, XayaUI_Debug loaded), its findings tagged. Returns the exit code of Report.show."""
    rep = Report(gate)
    data, secs, cached = result()
    rep.note("variant \"default\" (Advanced Debugging off, XayaUI_Debug switched on in the AddOns list and not loaded: V34)")
    judge(data, rep)
    if not os.path.isdir(os.path.join(ROOT, DEBUG_ADDON)):
        rep.note(DEBUG_TAG + "variant \"debug\" not played: this checkout has no %s folder" % DEBUG_ADDON)
        return rep.show(data, secs, cached)
    ddata, dsecs, dcached = result("debug")
    rep.note(DEBUG_TAG + "variant \"debug\": the same scenario with Settings > Debugging > Advanced Debugging saved on; XayaUI_Debug loaded: %s" %
             ddata.get("debugLoaded"))
    judge(ddata, Tagged(rep, DEBUG_TAG))
    return rep.show(data, (secs or 0) + (dsecs or 0), cached and dcached)


FIGHT_EVENTS = ("PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "RUNE_POWER_UPDATE", "PLAYER_TOTEM_UPDATE", "LOSS_OF_CONTROL_ADDED",
                "LOSS_OF_CONTROL_UPDATE")


def integrity(data, rep):
    """The scenario must have run as planned, or the gate proves nothing (each miss is a FAIL)."""
    used = data.get("used") or {}
    checks = [
        (int(data.get("rules") or 0) >= 290, "the profile has about 300 rule entries", "rules: %s" % data.get("rules")),
        (bool(data.get("optionsLoaded")), "the settings window's addon (XayaUI_Options) loaded", ""),
        (bool(used.get("open")), "the settings window opened", ""),
        (int(used.get("rows") or 0) >= 2, "rules were selected in the rule list", "rows clicked: %s" % used.get("rows")),
        (bool(used.get("search")), "the rule search was typed in", ""),
        (bool(used.get("menu")), "a rule's right-click menu was opened", ""),
        (bool(used.get("moverOpen")), "the mover (/xui unlock) opened", ""),
        (bool(data.get("windowClosed")), "the settings window closed", ""),
        (int(data.get("talentRules") or 0) >= 4, "the profile has its rules with a talent requirement (round 7)",
         "rules with a talent requirement: %s" % data.get("talentRules")),
        (len(data.get("checkpoints") or []) >= 9, "every checkpoint ran (closed, minimap, three fights, three after-fights, idle)",
         "checkpoints: %d" % len(data.get("checkpoints") or [])),
        # (round 8) the fight's movement, rune, totem and loss-of-control events were played (round 7 review: the gate never fired them)
        (all(int((data.get("fired") or {}).get(e) or 0) > 0 for e in FIGHT_EVENTS),
         "the fight played movement, runes, a totem and a loss of control (%s)" % ", ".join(FIGHT_EVENTS),
         "fired: %s" % (data.get("fired") or {})),
        # (round 8, V34) XayaUI_Debug is read only while Advanced Debugging is on: not loaded in the default variant, loaded in "debug"
        ((bool(data.get("debugLoaded")) == (data.get("variant") == "debug")),
         "XayaUI_Debug is loaded exactly when Advanced Debugging is on (variant %s)" % data.get("variant", "default"),
         "XayaUI_Debug loaded: %s" % data.get("debugLoaded")),
        (int(data.get("errors") or 0) == 0, "no Lua error during the scenario", "; ".join((data.get("errorText") or [])[:3])),
        # (round 9, SD-77) every fight has a boss pull and the boss down; the profile has the rules that test the narrowed re-check
        (all(int((data.get("fired") or {}).get(e) or 0) > 0 for e in ("ENCOUNTER_START", "ENCOUNTER_END")),
         "the fights played a boss pull and the boss down (ENCOUNTER_START, ENCOUNTER_END)", "fired: %s" % (data.get("fired") or {})),
        (all(int(((data.get("profile") or {}).get("made") or {}).get(k) or 0) > 0 for k in ("absent", "ooc", "boss", "fx")),
         "the profile has target debuffs that must be absent, out-of-combat opacity displays, boss rules and effect displays (round 9)",
         "made: %s" % ((data.get("profile") or {}).get("made"))),
        # (round 9, SD-79) the effects part: the effect displays were shown, and the preview had rules to show
        (int(data.get("fxShown") or 0) >= 6, "the effects part showed the effect displays", "shown %s of %s" % (data.get("fxShown"), data.get("fxGained"))),
        (int(used.get("previewRules") or 0) >= 6, "the preview before the close had the effect displays to preview", "rules %s" % used.get("previewRules")),
    ]
    for ok, what, numbers in checks:
        if not ok:
            rep.fail("tests/gate_common.py (the scenario)", "the scenario did not run as planned: " + what, numbers,
                     "fix the addon error or the scenario before reading the gate")
    if not used.get("slider"):
        rep.warn("tests/gate_common.py (the scenario)", "no visible slider was found to drag in the selected group's pane")
    if not used.get("dropdown"):
        rep.warn("tests/gate_common.py (the scenario)", "no visible dropdown list was found to open")


def short(where):
    """'XayaUI_Rules/Visual.lua:3007 SetMouseClickEnabled(true)' -> 'XayaUI_Rules/Visual.lua:3007'."""
    return (where or "?").split(" ")[0]
