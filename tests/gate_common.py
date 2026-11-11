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
             combat / in a group; static groups, dynamic groups and a nested group); she logs out (saved variables written).
  session B  the next login on what session A saved (as the game does: the profile is there at ADDON_LOADED), then:
             the settings window opens and is used (rules selected with a click, Ctrl+click and hover; the rule search typed in;
             a group's slider dragged; a rule's right-click menu and a dropdown list opened), the mover (/xui unlock) opened and
             closed, the window closed; the minimap button's list opened and closed with a click elsewhere;
             then the busiest case for 60 simulated seconds in three equal 20-second cycles (30 frames a second): a fight with
             UNIT_AURA (player and target), SPELL_UPDATE_COOLDOWN, SPELL_UPDATE_CHARGES and ACTIONBAR_UPDATE_COOLDOWN / _STATE /
             _USABLE storms every frame, auras gained and lost, spells cast, a group joined and left, a mount and a dismount,
             a loading screen; then 30 seconds idle out of combat with nothing on screen changing.
The window stays closed from the close onward: every frame the gates judge is "after the window is closed".

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
    stopped; allocations made inside the stand-in's own widget methods (it stores points and colours in Lua tables; the game does not)
    and by the gate's own measuring are taken out.
Run one gate: python3 tests/gate_<name>_run.py   (Lua 5.1 via lupa)."""
import os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

ROOT = os.path.dirname(HERE)
ADDONS = ("XayaUI", "XayaUI_Rules", "XayaUI_Options")

# ---------------------------------------------------------------------------------------------------------------------------------
# the game's aura container (Blizzard_AuraContainer) and the aura / cooldown reads: installed in both sessions before the addons load
# ---------------------------------------------------------------------------------------------------------------------------------
GAME_LUA = r'''
return function(W)
local G = { auras = {}, byInstance = {}, cds = {}, mounted = false, group = false, raid = false, nextInstance = 100 }
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
    for _, m in ipairs({ "SetUnit", "UpdateAllAuras", "SetAuraProcessingPolicy", "SetAuraGroupCandidateFilters", "SetAuraGroupLayout",
        "SetAuraGroupEnabled", "SetAuraGroupSortMethod", "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection",
        "SetFlowLayoutMaximumLineSize", "RemoveAuraGroup", "ClearAuraGroups" }) do rawset(f, m, noop) end
    rawset(f, "AddAuraGroup", function(self, key, filter, o)
      self.groups[key] = o
      if type(o) == "table" and type(o.initializeFrame) == "function" then
        local b = realCreate("Button", nil, self)
        for _, m in ipairs({ "SetIcon", "SetDurationCooldown", "SetDurationText", "SetDurationBar", "SetApplicationCount", "SetApplicationBar",
            "SetSpellName", "AddDispelTypeTexture", "ApplyDispelTypeTexture" }) do rawset(b, m, noop) end
        b:EnableMouse(false)   -- (Blizzard's aura buttons: the engine sets their mouse itself)
        pcall(o.initializeFrame, b)
      end
    end)
  end
  return f
end
-- the auras the player has right now: [spellID] = aura data (the game's AuraData fields the rules read)
local function auraFor(id) return G.auras[id] end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit == "player" then return auraFor(id) end return nil end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return auraFor(id) end
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, iid) return G.byInstance[iid] end
C_UnitAuras.GetAuraDataBySpellName = function() return nil end
-- the target's debuffs cast by the player ("HARMFUL|PLAYER"): a list the scenario keeps (G.targetDebuffs)
G.targetDebuffs, G.target = {}, false
C_UnitAuras.GetUnitAuras = function(unit, filter) if unit == "target" and G.target then return G.targetDebuffs end return {} end
local UE0 = UnitExists
UnitExists = function(u) if u == "target" then return G.target end return UE0(u) end
C_UnitAuras.AddAuraSound = function() G.nextInstance = G.nextInstance + 1; return G.nextInstance end
C_UnitAuras.RemoveAuraSound = function() end
C_Spell.GetSpellCooldown = function(id)
  local c = G.cds[tonumber(id) or 0]
  if c then return c end
  return G.readyCD
end
G.readyCD = { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
IsMounted = function() return G.mounted end
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
function G.cast(id, dur) G.cds[id] = { startTime = W.now, duration = dur, isEnabled = true, modRate = 1 } end
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
local made = { buff = 0, cd = 0, bar = 0, soundCue = 0, iconCue = 0, game = 0, hover = 0, debuff = 0 }
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
-- 5. hover-tooltip displays (V27: hover allowed, clicks pass)
for i = 1, 20 do
  rule("Hover " .. i, function(r)
    r.useBuff, r.buffID, r.buffState = true, 330000 + i, "present"
    display(r, 32, 32); r.visual.trigger = "buffActive"; r.visual.hoverTip = true
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


def _world(L, saved_source=None):
    """A stand-in game (tests/harness/world.lua + loader.lua) with XayaUI, XayaUI_Rules and XayaUI_Options switched on."""
    folders = H.find_addons()
    sv = H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    game = L.eval("function(src, W) return loadstring(src)()(W) end")(GAME_LUA, world)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders if k in ADDONS}})
    opts["saved"] = sv.Load(saved_source) if saved_source else L.table()
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    return world, loader, game, sv


def build_profile():
    """Session A: the ~300-rule profile, saved by a logout. Returns (saved source, rule count, kinds made, group count, Lua errors)."""
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world, loader, game, sv = _world(L)
    out, n, made, nf = L.eval("function(src, W, Ld, G) return loadstring(src)()(W, Ld, G) end")(PROFILE_LUA, world, loader, game)
    errors = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return sv.Serialize(out), n, H.lua_to_py(made), nf, errors
