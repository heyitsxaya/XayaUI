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
local function setPhase(p) PHASE = p; OUT.phases[#OUT.phases + 1] = p end

-------------------------------------------------------------------------------------------------------------------------------------
-- where a call comes from: the nearest XayaUI file up the stack (a bundled library under Libs/ only when no XayaUI file is found)
-------------------------------------------------------------------------------------------------------------------------------------
local hookAlloc, standAlloc = 0, 0     -- KB the gate's own measuring and the stand-in's widget methods allocated (taken out)
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
  local m0 = gc("count")
  local lib
  for l = level + 1, level + 16 do
    local info = getinfo(l, "Sl")
    if not info then break end
    local f = short(info.source)
    if f then
      if not isLib(f) then hookAlloc = hookAlloc + (gc("count") - m0); return f .. ":" .. tostring(info.currentline), lib end
      lib = lib or (f .. ":" .. tostring(info.currentline))
    end
  end
  hookAlloc = hookAlloc + (gc("count") - m0)
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
  local where = whereFrom(2)
  if where then
    ORIGIN[f] = where
    local m0 = gc("count"); bump(sub(CREATED, PHASE), where); hookAlloc = hookAlloc + (gc("count") - m0)
  end
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
    local w = whereFrom(2)
    if w and not isLib(w) then local m0 = gc("count"); bump(MOUSECALLS, w .. " " .. what); hookAlloc = hookAlloc + (gc("count") - m0) end
  end
end
function proto:EnableMouse(v) noteMouseCall(self, "EnableMouse"); v = v and true or false; self._mouse, self._mclick, self._mmotion, self._mouseSet = v, v, v, true end
function proto:SetMouseClickEnabled(v) noteMouseCall(self, "SetMouseClickEnabled"); v = v and true or false; self._mclick, self._mouse = v, v; self._mouseSet = true
  if self._mmotion == nil then self._mmotion = CLICKS_BY_DEFAULT[self._kind] or false end end
function proto:SetMouseMotionEnabled(v) noteMouseCall(self, "SetMouseMotionEnabled"); self._mmotion = v and true or false
  if not self._mouseSet then self._mclick = CLICKS_BY_DEFAULT[self._kind] or false; self._mouse = self._mclick; self._mouseSet = true end end
proto.EnableMouseMotion = proto.SetMouseMotionEnabled
function proto:IsMouseClickEnabled() if self._mouseSet then return self._mclick and true or false end return CLICKS_BY_DEFAULT[self._kind] or false end
function proto:IsMouseMotionEnabled() if self._mouseSet then return self._mmotion and true or false end return CLICKS_BY_DEFAULT[self._kind] or false end
function proto:IsMouseEnabled() return self:IsMouseClickEnabled() or self:IsMouseMotionEnabled() end
function proto:EnableMouseWheel(v) noteMouseCall(self, "EnableMouseWheel"); self._wheel = v and true or false end
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
  local w = whereFrom(2)
  if w then local m0 = gc("count"); bump(KBCALLS, w .. " " .. what .. (W.combat and " (in combat)" or "")); hookAlloc = hookAlloc + (gc("count") - m0) end
end
do
  local EK, SP, SF = proto.EnableKeyboard, proto.SetPropagateKeyboardInput, proto.SetFocus
  proto.EnableKeyboard = function(self, v) if v then noteKb("EnableKeyboard(true)") end; return EK(self, v) end
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
local VIS = 0           -- visible changes made so far (text, value, alpha, size, position, colour, shown state of a shown widget)
local NONINT = {}       -- [file:line] = { n, method, example, phases }
local ST = { ev = {}, ou = {}, tm = {}, loops = {}, wide = {}, cyc = {}, idlewin = {}, mem = {}, hooks = {}, timers = {}, created = CREATED }
local function isWhole(v) return type(v) ~= "number" or v == math.floor(v) end
local function noteNonInt(method, a, b, c, d)
  if not CLOSED and not CFG.nonintAlways then return end
  local m0 = gc("count")
  local w = whereFrom(2)
  if w and not isLib(w) then
    local s = NONINT[w]
    if not s then s = { n = 0, method = method, example = string.format("%s(%s, %s, %s, %s)", method, tostring(a), tostring(b), tostring(c), tostring(d)), phases = {} }; NONINT[w] = s end
    s.n = s.n + 1; s.phases[PHASE] = true
  end
  hookAlloc = hookAlloc + (gc("count") - m0)
end
-- the stand-in's widget methods: their own Lua garbage is not XayaUI's (the game stores points and colours in C)
local RUNS_SCRIPTS = { Show = true, Hide = true, SetShown = true, SetValue = true, Click = true, SetFocus = true, ClearFocus = true, Stop = true,
  SetScript = true, HookScript = true }
local function exclEnd(m0, ...) standAlloc = standAlloc + (gc("count") - m0); return ... end
local function changed() if cur then VIS = VIS + 1 end end
for name, orig in pairs(proto) do
  if type(orig) == "function" and not RUNS_SCRIPTS[name] then
    local o = orig
    if name == "SetPoint" then
      proto.SetPoint = function(self, p, rel, rp, x, y)
        local m0 = gc("count")
        local nx, ny = x, y
        if type(rel) == "number" then nx, ny = rel, rp elseif type(rp) == "number" then nx, ny = rp, x end
        if not (isWhole(nx) and isWhole(ny)) then noteNonInt("SetPoint", p, nx, ny) end
        local before
        for _, e in ipairs(self._pts) do if e[1] == p then before = e end end
        local bx, by, brel = before and before[4], before and before[5], before and before[2]
        o(self, p, rel, rp, x, y)
        if (not before or bx ~= (nx or 0) or by ~= (ny or 0)) and self:IsVisible() then changed() end
        standAlloc = standAlloc + (gc("count") - m0)
      end
    elseif name == "SetSize" or name == "SetWidth" or name == "SetHeight" then
      proto[name] = function(self, a, b)
        local m0 = gc("count")
        if not (isWhole(a) and isWhole(b)) then noteNonInt(name, a, b) end
        local w0, h0 = self._w, self._h
        o(self, a, b)
        if (w0 ~= self._w or h0 ~= self._h) and self:IsVisible() then changed() end
        standAlloc = standAlloc + (gc("count") - m0)
      end
    elseif name == "SetText" or name == "SetFormattedText" then
      proto[name] = function(self, ...)
        local m0 = gc("count")
        local t0 = self._text
        o(self, ...)
        if t0 ~= self._text and self:IsVisible() then changed() end
        standAlloc = standAlloc + (gc("count") - m0)
      end
    elseif name == "SetAlpha" or name == "SetTexture" or name == "SetAtlas" or name == "SetDesaturated" or name == "SetDesaturation" or name == "SetRotation" or name == "SetScale" then
      local field = ({ SetAlpha = "_alpha", SetTexture = "_tex", SetAtlas = "_atlas", SetDesaturated = "_desat", SetDesaturation = "_desat", SetRotation = "_rot", SetScale = "_scale" })[name]
      proto[name] = function(self, ...)
        local m0 = gc("count")
        local v0 = rawget(self, field)
        local r1, r2 = o(self, ...)
        if v0 ~= rawget(self, field) and self:IsVisible() then changed() end
        standAlloc = standAlloc + (gc("count") - m0)
        return r1, r2
      end
    elseif name == "SetVertexColor" or name == "SetColorTexture" or name == "SetTextColor" or name == "SetCooldown" or name == "SetStatusBarColor" or name == "SetBackdropColor" or name == "SetBackdropBorderColor" then
      local field = ({ SetVertexColor = "_vc", SetColorTexture = "_color", SetTextColor = "_tc", SetCooldown = "_cd", SetBackdropColor = "_bdcolor", SetBackdropBorderColor = "_bdborder" })[name]
      proto[name] = function(self, a, b, c, d)
        local m0 = gc("count")
        local t0 = field and rawget(self, field)
        local same = t0 and t0[1] == a and t0[2] == b and t0[3] == c and t0[4] == d
        o(self, a, b, c, d)
        if not same and self:IsVisible() then changed() end
        standAlloc = standAlloc + (gc("count") - m0)
      end
    else
      proto[name] = function(self, ...) local m0 = gc("count"); return exclEnd(m0, o(self, ...)) end
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
-- hooks placed after the window closed (they can never be taken off: V28)
do
  local hsf, HS = hooksecurefunc, proto.HookScript
  hooksecurefunc = function(...) if CLOSED then local w = whereFrom(2); if w then local m0 = gc("count"); bump(sub(ST.hooks, PHASE), w .. " hooksecurefunc"); hookAlloc = hookAlloc + (gc("count") - m0) end end; return hsf(...) end
  proto.HookScript = function(self, n, f) if CLOSED then local w = whereFrom(2); if w then local m0 = gc("count"); bump(sub(ST.hooks, PHASE), w .. " HookScript(" .. tostring(n) .. ")"); hookAlloc = hookAlloc + (gc("count") - m0) end end; return HS(self, n, f) end
end
-- timers: who made each one, what kind, and whether it re-arms itself
local TIMERS_SEEN = {}   -- [src] = { kind, every, n made, rearm }
local curTimer
local function addTimer(delay, fn, iterations, kind)
  local m0 = gc("count")
  local src = whereFrom(2) or "?"
  local seen = TIMERS_SEEN[src]
  if not seen then seen = { kind = kind, every = tonumber(delay) or 0, made = 0, rearm = false, phases = {} }; TIMERS_SEEN[src] = seen end
  seen.made = seen.made + 1; seen.phases[PHASE] = true
  if curTimer and curTimer.src == src then seen.rearm = true end
  hookAlloc = hookAlloc + (gc("count") - m0)
  local t = { at = W.now + (tonumber(delay) or 0), fn = fn, every = tonumber(delay) or 0, left = iterations, cancelled = false, src = src, kind = kind }
  t.handle = { Cancel = function() t.cancelled = true end, IsCancelled = function() return t.cancelled end }
  W.timers[#W.timers + 1] = t
  return t.handle
end
C_Timer.After = function(d, fn) addTimer(d, fn, 1, "After") end
C_Timer.NewTimer = function(d, fn) local h; h = addTimer(d, function() fn(h) end, 1, "NewTimer"); return h end
C_Timer.NewTicker = function(d, fn, n) local h; h = addTimer(d, function() fn(h) end, n or math.huge, (n and n <= 1) and "NewTicker(1)" or "NewTicker"); return h end

-- loops over the rule list: ipairs / pairs over a table as long as the rule list (or the rule list / the engine's per-rule state itself)
local LOOPMIN = math.huge
local BIG = setmetatable({}, { __mode = "k" })
local rawipairs, rawpairs = ipairs, pairs
local function noteLoop(n)
  local m0 = gc("count")
  local w = whereFrom(2)
  if w and not isLib(w) then
    local d = sub(ST.loops, cur.kind .. " " .. cur.name)
    local s = d[w]
    if not s then s = { times = 0, max = 0, src = cur.src }; d[w] = s end
    s.times = s.times + 1; if n > s.max then s.max = n end
  end
  hookAlloc = hookAlloc + (gc("count") - m0)
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

-- call counts (debug hook, "call" events only): per dispatch and per window
local DCALLS, WCALLS = {}, {}
local KEYS = {}
local function callhook()
  local m0 = gc("count")
  local info = getinfo(2, "S")
  if info then
    local f = short(info.source)
    if f and not isLib(f) then
      local ks = KEYS[f]; if not ks then ks = {}; KEYS[f] = ks end
      local k = ks[info.linedefined]; if not k then k = f .. ":" .. info.linedefined; ks[info.linedefined] = k end
      DCALLS[k] = (DCALLS[k] or 0) + 1
      WCALLS[k] = (WCALLS[k] or 0) + 1
    end
  end
  hookAlloc = hookAlloc + (gc("count") - m0)
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
local T0 = 0
local function finish(kind, name, src, bytes, vis, owner)
  -- bookkeeping after the measurement (its own garbage is not counted)
  local byKind = (kind == "event") and ST.ev or ((kind == "onupdate") and ST.ou or ST.tm)
  local s = byKind[name]
  if not s then s = { n = 0, bytes = 0, max = 0, idle = 0, vis = 0, byPhase = {}, srcs = {}, wins = {}, winsIdle = {} }; byKind[name] = s end
  s.n = s.n + 1; s.bytes = s.bytes + bytes; if bytes > s.max then s.max = bytes end
  s.vis = s.vis + vis
  if vis == 0 then s.idle = s.idle + 1 end
  local p = s.byPhase[PHASE]; if not p then p = { n = 0, bytes = 0, idle = 0, vis = 0 }; s.byPhase[PHASE] = p end
  p.n = p.n + 1; p.bytes = p.bytes + bytes; p.vis = p.vis + vis; if vis == 0 then p.idle = p.idle + 1 end
  if src then local h = s.srcs[src]; if not h then h = { n = 0, bytes = 0 }; s.srcs[src] = h end; h.n = h.n + 1; h.bytes = h.bytes + bytes end
  if kind ~= "event" then
    local w = math.floor((W.now - T0) / WIN)
    local ww = s.wins[w]; if not ww then ww = { runs = 0, vis = 0, phase = PHASE }; s.wins[w] = ww end
    ww.runs = ww.runs + 1; ww.vis = ww.vis + vis
  end
  -- functions called as often as there are rules in this one dispatch: a loop over every rule
  for k, n in rawpairs(DCALLS) do
    if n >= LOOPMIN then
      local d = sub(ST.wide, kind .. " " .. name)
      local e = d[k]; if not e then e = { times = 0, max = 0, src = src, phases = {} }; d[k] = e end
      e.times = e.times + 1; if n > e.max then e.max = n end; e.phases[PHASE] = true
    end
    DCALLS[k] = nil
  end
end
local function run(kind, name, owner, fn, ...)
  if not (PERF and CLOSED) or cur then return quietRun(fn, ...) end
  local src = srcOf(fn)
  if not src then return quietRun(fn, ...) end
  if kind ~= "event" then name = src end
  local rec = owner   -- (unused; kept for the reader: the frame whose script runs)
  for k in rawpairs(DCALLS) do DCALLS[k] = nil end
  hookAlloc, standAlloc = 0, 0
  local vis0 = VIS
  cur = { kind = kind, name = name, src = src }   -- (made before the measurement starts)
  local m0 = gc("count")
  local ok = quietRun(fn, ...)
  local m1 = gc("count")
  local c = cur
  cur = nil
  local bytes = math.floor(((m1 - m0) - hookAlloc - standAlloc) * 1024 + 0.5)
  if bytes < 0 then bytes = 0 end
  finish(kind, c.name, src, bytes, VIS - vis0, owner)
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
W.tick = function(dt, steps)
  for _ = 1, (steps or 1) do
    W.now = W.now + dt
    local due, keep = {}, {}
    for _, t in rawipairs(W.timers) do
      if t.cancelled then -- dropped
      elseif t.at <= W.now then due[#due + 1] = t else keep[#keep + 1] = t end
    end
    W.timers = keep
    for _, t in rawipairs(due) do
      curTimer = t
      run("timer", t.src or "?", nil, t.fn)
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
    if PERF and CLOSED and gc("count") > (OUT.heapCap or math.huge) then gc("collect"); gc("stop"); OUT.heapCap = gc("count") + 131072 end
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
local function checkpoint(label)
  local cp = { label = label, combat = W.combat, mouse = {}, hover = 0, noArea = {}, wheel = {}, keyboard = {}, focus = {}, keys = {} }
  for _, o in rawipairs(W.objects) do
    local where, viaParent = originOf(o)
    if where and o:IsVisible() and not ALLOWED[o] and not (o._kind == "Texture" or o._kind == "FontString" or o._kind == "MaskTexture" or o._kind == "Line") then
      local click = o:IsMouseClickEnabled() and not passesClicks(o)
      local area, w, h, frac = hasArea(o)
      local nm = o._name or ("a " .. tostring(o._kind))
      if click then
        local e = { name = nm, kind = o._kind, where = where, viaParent = viaParent, w = w, h = h, frac = frac or 0, strata = o:GetFrameStrata(),
          drag = o._scripts.OnDragStart ~= nil, scripts = (o._scripts.OnClick and "OnClick " or "") .. (o._scripts.OnMouseDown and "OnMouseDown " or "") .. (o._scripts.OnMouseUp and "OnMouseUp" or "") }
        if area then cp.mouse[#cp.mouse + 1] = e else cp.noArea[#cp.noArea + 1] = e end
      elseif o:IsMouseMotionEnabled() then cp.hover = cp.hover + 1 end
      if o._wheel and area then cp.wheel[#cp.wheel + 1] = { name = nm, kind = o._kind, where = where, w = w, h = h } end
      if o._keyboard then cp.keyboard[#cp.keyboard + 1] = { name = nm, kind = o._kind, where = where, propagate = o._propagate and true or false } end
    end
    if o._kind == "EditBox" and o._focus then cp.focus[#cp.focus + 1] = { name = o._name or "an edit box", where = where or "not XayaUI's", visible = o:IsVisible() } end
  end
  for _, key in rawipairs({ "PRINTSCREEN", "W", "SPACE" }) do
    local got = W.pressKey(key)
    cp.keys[#cp.keys + 1] = { key = key, reached = (got == "game"), ran = W.gameRan, by = (got ~= "game") and (rawget(got, "_name") or tostring(got and got._kind)) or nil,
      byWhere = (got ~= "game") and originOf(got) or nil }
  end
  OUT.checkpoints[#OUT.checkpoints + 1] = cp
  return cp
end

-------------------------------------------------------------------------------------------------------------------------------------
-- the scenario
-------------------------------------------------------------------------------------------------------------------------------------
local regen = false   -- (as in the game, UnitAffectingCombat("player") is already true when PLAYER_REGEN_DISABLED fires; INFERENCE)
UnitAffectingCombat = function() return (W.combat or regen) and true or false end
local function fight() regen = true; W.enterCombat(); regen = false end
local function peace() W.leaveCombat() end
local FPS = 30
local DT = 1 / FPS
local function frames(sec, each)
  local n = math.floor(sec * FPS + 0.5)
  for i = 1, n do if each then each(i) end; W.tick(DT, 1) end
end

setPhase("login")
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.fire("SPELLS_CHANGED"); W.fire("PLAYER_TALENT_UPDATE")
frames(5)
local ns = rawget(_G, "XayaUI_NS")
assert(ns and ns.rules, "XayaUI Rules did not load")
OUT.rules = #ns.rules
OUT.folders = #(ns.folders or {})
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
  pcall(ACD.SelectGroup, ACD, APP, "cooldowns", "enabledTab", "loaded", ns.folders[#ns.folders] and ns.folders[#ns.folders].id); settle()
  local slider = findW(ACD.OpenFrames[APP], function(w) return w.type == "Slider" and w.frame and w.frame:IsVisible() end)
  if slider then for step = 1, 8 do slider:Fire("OnValueChanged", step * 2); W.tick(DT, 1) end; slider:Fire("OnMouseUp", 16); settle(); used.slider = true end
  local dd = findW(ACD.OpenFrames[APP], function(w) return w.type == "Dropdown" and w.frame and w.frame:IsVisible() end)
  if dd and dd.pullout and dd.pullout.Open then pcall(dd.pullout.Open, dd.pullout, "TOPLEFT", dd.frame, "BOTTOMLEFT", 0, 0); settle(); pcall(dd.pullout.Close, dd.pullout); used.dropdown = true end
end
-- the mover (/xui unlock), opened and closed
if ns.ToggleUnlock then pcall(ns.ToggleUnlock); frames(1); used.moverOpen = ns.IsUnlocked and ns.IsUnlocked() or true; pcall(ns.ToggleUnlock); frames(0.5) end
OUT.used = used
-- she closes the window
pcall(ns.ToggleUI); W.tick(0.1, 40)
OUT.windowClosed = not (ACD and ACD.OpenFrames[APP])
setPhase("closed")
CLOSED = true
T0 = W.now
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
for i = 1, 20 do BUFFS[#BUFFS + 1] = 330000 + i end
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
  W.fire("UNIT_AURA", "player", { addedAuras = { a }, removedAuraInstanceIDs = rem })
end
local function loseOldest()
  local a = table.remove(active, 1)
  if a and G.auras[a.spellId] == a then G.lose(a.spellId); W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { a.auraInstanceID } }) end
end
local function storm(i)
  local a = active[(i % math.max(#active, 1)) + 1]
  if a then a.expirationTime = W.now + a.duration; W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { a.auraInstanceID } })
  else W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 1 } }) end
  W.fire("UNIT_AURA", "target", { updatedAuraInstanceIDs = { 2 } })
  W.fire("SPELL_UPDATE_COOLDOWN")
  if i % 3 == 0 then W.fire("SPELL_UPDATE_CHARGES") end
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
end
local function memNow() gc("collect"); local m = gc("count"); if PERF then gc("stop") end; return m end
if PERF then OUT.memStart = memNow() end
local cycleWin = {}
for cyc = 1, 3 do
  setPhase("busy " .. cyc)
  for k in rawpairs(WCALLS) do WCALLS[k] = nil end
  -- a loading screen into the zone
  W.fire("LOADING_SCREEN_ENABLED"); W.fire("PLAYER_LEAVING_WORLD")
  W.fire("PLAYER_ENTERING_WORLD", false, false); W.fire("ZONE_CHANGED_NEW_AREA"); W.fire("LOADING_SCREEN_DISABLED")
  frames(1)
  -- mounted, then dismounted
  G.mounted = true; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); W.fire("UNIT_AURA", "player", { isFullUpdate = true }); frames(1)
  G.mounted = false; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); W.fire("UNIT_AURA", "player", { isFullUpdate = true }); frames(0.5)
  -- a group joined, a target picked
  G.group = true; W.fire("GROUP_ROSTER_UPDATE"); W.fire("GROUP_ROSTER_UPDATE"); frames(0.25)
  G.target = true; W.fire("PLAYER_TARGET_CHANGED"); frames(0.25)
  -- the fight: 15 seconds of storms
  fight()
  for _ = 1, 4 do gainOne(30) end
  local mid
  frames(15, function(i)
    storm(i)
    if i == 200 then W.fire("GROUP_ROSTER_UPDATE") end   -- someone joins mid-fight
    if i == 225 and not mid then mid = true end
  end)
  OUT.mouseCombat[cyc] = checkpoint("in the fight, cycle " .. cyc)
  peace()
  frames(1)
  -- the group leaves, the target is dropped
  G.group = false; W.fire("GROUP_ROSTER_UPDATE"); G.target = false; G.targetDebuffs = {}; W.fire("PLAYER_TARGET_CHANGED")
  frames(0.5)
  checkpoint("out of combat after the fight, cycle " .. cyc)
  frames(0.5)
  if PERF then
    local snap = {}
    for k, n in rawpairs(WCALLS) do snap[k] = n end
    ST.cyc[cyc] = snap
    OUT.mem = OUT.mem or {}
    OUT.mem[cyc] = memNow()
  end
end
-- idle out of combat: every aura and cooldown gone, nothing on screen changing
setPhase("idle settle")
G.clear(); active = {}
W.fire("UNIT_AURA", "player", { isFullUpdate = true }); W.fire("SPELL_UPDATE_COOLDOWN")
frames(5)
for w = 1, 3 do
  setPhase("idle " .. w)
  for k in rawpairs(WCALLS) do WCALLS[k] = nil end
  frames(10)
  local snap = {}
  for k, n in rawpairs(WCALLS) do snap[k] = n end
  ST.idlewin[w] = snap
end
if PERF then OUT.memEnd = memNow() end
checkpoint("after 30 seconds idle out of combat")
-- timers still waiting at the end, by who made them
local pend = {}
for _, t in rawipairs(W.timers) do if not t.cancelled then local s = pend[t.src or "?"]; if not s then s = { n = 0, kind = t.kind, every = t.every, left = t.left }; pend[t.src or "?"] = s end; s.n = s.n + 1 end end
OUT.timersPending = pend
OUT.timersMade = TIMERS_SEEN
OUT.kbCalls = KBCALLS
OUT.mouseCalls = MOUSECALLS
OUT.nonint = NONINT
OUT.stats = ST
OUT.errors = #W.errors
OUT.errorText = {}
for i = 1, math.min(#W.errors, 12) do OUT.errorText[i] = tostring(W.errors[i]):sub(1, 400) end
OUT.now = W.now
return OUT
end
'''


def run_scenario(perf=False):
    """Sessions A and B. Returns (result as Python data, seconds)."""
    t0 = time.time()
    saved, n, made, nf, errs_a = build_profile()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world, loader, game, sv = _world(L, saved)
    cfg = H.to_lua(L, {"perf": perf})
    if perf:
        L.execute("collectgarbage('stop')")
    res = L.eval("function(src, W, Ld, G, C) return loadstring(src)()(W, Ld, G, C) end")(SCENARIO_LUA, world, loader, game, cfg)
    L.execute("collectgarbage('restart')")
    out = H.lua_to_py(res)
    out["profile"] = {"entries": n, "made": made, "groups": nf, "errorsA": errs_a}
    return out, round(time.time() - t0, 1)
