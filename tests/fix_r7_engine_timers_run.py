#!/usr/bin/env python3
"""Offline test (round 7, engine-b; REQUEST-LOG A23 SD-60, her answer "all timers are supported by EUI, so this is not a real issue.
solve for it, please"). Before round 7 the engine re-checked a set of rules every 0.2 s (TICK, the "polled" set) while what they show
changed at a moment the game hides. Each case now follows what the game drives itself; what the player sees stays the same.
  1. A cooldown's end in combat (its start and duration are secret): a "ready" display hidden while the spell cools down shows again
     when the cooldown ends, with no event at the end. The game counts the cooldown down in a Cooldown widget of the engine's own, fed
     the cooldown's duration object (C_Spell.GetSpellCooldownDuration, Cooldown:SetCooldownFromDurationObject); its OnCooldownDone wakes
     the rule. Checked: shown within two frames of the end (before: up to 0.2 s late), and the rule is not re-checked while the
     cooldown runs (before: five times a second).
  2. The seconds a display's own text shows from an aura time the game hides: the game counts them down itself through a duration
     text binding, with the same whole-seconds format as before ("%d" of the remaining seconds); a refreshed aura (an aura event) binds
     the new time. Checked: the text is bound to the aura's duration object with a formatter that writes what the text wrote before;
     the rule is not re-checked while nothing changes (before: five times a second); a refresh binds the new duration within a tenth
     of a second and a frame.
  3. A preview (the settings window's eye icon) with a duration text: its sample countdown changes its whole second at the exact
     moment (a stored moment), and a sound preview loops on its own stored moment (before: both re-checked every 0.2 s).
  4. A row type the engine does not route: it answers the same every time, so it is not re-checked on a timer (before: five times a
     second for as long as the rule was loaded). Every row type Triggers.lua knows has a route in the engine.
  5. Once the events stop, no engine timer is armed while a hidden cooldown runs and a hidden aura time is shown; the only rules the
     engine still re-checks on a timer are those with a Range Check row on a focus / mouseover / pet (no game event exists for those:
     round 7 report, NEEDS_HER_DECISION).
Stand-in game: the whole-addon harness (tests/harness), with the Cooldown widget, duration objects, the duration text binding and the
number formatter stubbed here by their documented contracts (docs/reference/api: widgets.md:1013, namespaces.md:1640 / 4401 / 4546).
That OnCooldownDone runs at alpha 0 in combat, and the binding's in-game drawing, are UNVERIFIED IN GAME.
Run: python3 tests/fix_r7_engine_timers_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- engine timers (C_Timer calls made from XayaUI_Rules/Engine.lua), with their state
local engineTimers = {}
local function fromEngine() local i = debug.getinfo(3, "S"); return i and i.source and i.source:find("Engine.lua", 1, true) ~= nil end
local A0, T0, K0 = C_Timer.After, C_Timer.NewTimer, C_Timer.NewTicker
C_Timer.After = function(d, fn)
  if fromEngine() then local rec = { at = W.now + (d or 0), done = false }; engineTimers[#engineTimers + 1] = rec; return A0(d, function(...) rec.done = true; return fn(...) end) end
  return A0(d, fn)
end
C_Timer.NewTimer = function(d, fn)
  if fromEngine() then
    local rec = { at = W.now + (d or 0), timer = true, done = false }
    local h = T0(d, function(...) rec.done = true; return fn(...) end)
    rec.handle = h; engineTimers[#engineTimers + 1] = rec
    return h
  end
  return T0(d, fn)
end
C_Timer.NewTicker = function(d, fn, n)
  local h = K0(d, fn, n)
  if fromEngine() then engineTimers[#engineTimers + 1] = { ticker = true, handle = h } end
  return h
end
local function armedEngineTimers()
  local n = 0
  for _, t in ipairs(engineTimers) do
    if t.ticker then if not t.handle:IsCancelled() then n = n + 1 end
    elseif not t.done and not (t.handle and t.handle:IsCancelled()) then n = n + 1 end
  end
  return n
end

-- secret values: unique tables the stand-in marks secret (issecretvalue answers true; arithmetic on them errors, as in the game)
local function secret(name) return W.MarkSecret(setmetatable({}, { __tostring = function() return "SECRET " .. name end })) end
local SEC_START, SEC_DUR, SEC_EXP, SEC_ADUR = secret("start"), secret("duration"), secret("expiration"), secret("aura duration")

-- the game's duration objects (LuaDurationObject): what a widget or a binding is handed; endAt is the stand-in's own field
local function Duration(startAt, len) return { startAt = startAt, endAt = startAt + len, HasSecretValues = function() return true end } end
-- Cooldown widgets made by XayaUI_Rules/Engine.lua: SetCooldownFromDurationObject keeps the end; OnCooldownDone runs on the first frame
-- at or after it while the widget is visible (alpha does not matter), as the game's widget does (INFERENCE, UNVERIFIED IN GAME)
local engineWidgets = {}
local CF0 = CreateFrame
CreateFrame = function(kind, name, parent, template, ...)
  local f = CF0(kind, name, parent, template, ...)
  if kind == "Cooldown" then
    local i = debug.getinfo(2, "S")
    if i and i.source and i.source:find("Engine.lua", 1, true) then
      engineWidgets[#engineWidgets + 1] = f
      rawset(f, "SetCooldownFromDurationObject", function(self, d) self._endAt = d and d.endAt or nil; self._fed = (self._fed or 0) + 1 end)
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
-- the duration text binding (C_DurationUtil.CreateDurationTextBinding) and the number formatter (C_StringUtil.CreateNumericRuleFormatter)
BINDINGS = {}
C_DurationUtil.CreateDurationTextBinding = function()
  local b = { enabled = false }
  function b:SetToDefaults() end
  function b:SetFontString(fs) self.fs = fs end
  function b:SetZeroDurationText(t) self.zero = t end
  function b:SetExpiredText(t) self.expired = t end
  function b:SetFormatter(f) self.fmt = f end
  function b:SetDuration(d) self.dur = d; self.sets = (self.sets or 0) + 1 end
  function b:SetEnabled(e) self.enabled = e end
  BINDINGS[#BINDINGS + 1] = b
  return b
end
Enum.NumericRuleFormatRounding = Enum.NumericRuleFormatRounding or { Nearest = 0, Up = 1, Down = 2 }
C_StringUtil = C_StringUtil or {}
C_StringUtil.CreateNumericRuleFormatter = function()
  local f = { bps = {} }
  function f:SetBreakpoints(b) self.bps = b end
  function f:FormatNumber(x)
    local bp
    for _, p in ipairs(self.bps) do if x >= p.threshold then bp = p; break end end
    if not bp then return "" end
    local v = x
    if bp.step then
      local q = x / bp.step
      if bp.rounding == 1 then q = math.ceil(q - 1e-9) elseif bp.rounding == 2 then q = math.floor(q + 1e-9) else q = math.floor(q + 0.5) end
      v = q * bp.step
    end
    if bp.components then
      local vals = {}
      for i, c in ipairs(bp.components) do
        local y = v; if c.div then y = y / c.div end; if c.mod then y = math.fmod(y, c.mod) end
        if c.step then y = math.floor(y / c.step + 1e-9) * c.step end
        vals[i] = y
      end
      return string.format(bp.format, unpack(vals))
    end
    return string.format(bp.format, v)
  end
  return f
end

-- the world: auras (out of combat readable; aura 1005's time is hidden: secret expiration, readable instance ID) and cooldowns
local G = { auras = {}, nextIID = 100, cds = {} }
local function copy(a) local t = {}; for k, v in pairs(a) do t[k] = v end; return t end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit ~= "player" then return nil end local a = G.auras[id]; return a and copy(a) or nil end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
C_UnitAuras.GetAuraDataByIndex = function(unit, i)
  if unit ~= "player" then return nil end
  local list = {}; for _, a in pairs(G.auras) do list[#list + 1] = a end
  table.sort(list, function(x, y) return x.auraInstanceID < y.auraInstanceID end)
  return list[i] and copy(list[i]) or nil
end
C_UnitAuras.GetAuraDuration = function(unit, iid)
  for _, a in pairs(G.auras) do if a.auraInstanceID == iid then return a._dur end end
  return nil
end
C_Spell.GetSpellCooldown = function(id)
  local c = G.cds[id]
  if c and W.now < c.start + c.dur then
    if W.combat then return { startTime = SEC_START, duration = SEC_DUR, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 } end
    return { startTime = c.start, duration = c.dur, isEnabled = true, isActive = true, isOnGCD = false, modRate = 1 }
  end
  return { startTime = 0, duration = 0, isEnabled = true, isActive = false, isOnGCD = false, modRate = 1 }
end
C_Spell.GetSpellCharges = function() return nil end
local CDDUR = {}
C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD)
  CDDUR[#CDDUR + 1] = { id, ignoreGCD }
  local c = G.cds[id]
  if c and W.now < c.start + c.dur then return Duration(c.start, c.dur) end
  return Duration(W.now, 0)
end
C_Spell.GetSpellChargeDuration = function() return nil end
local function gain(id, dur, hidden)
  G.nextIID = G.nextIID + 1
  local a = { spellId = id, auraInstanceID = G.nextIID, name = "Spell " .. id, icon = 136243, applications = 1, duration = dur,
    expirationTime = W.now + dur, isHelpful = true, sourceUnit = "player" }
  a._dur = Duration(W.now, dur)
  if hidden then a.expirationTime, a.duration = SEC_EXP, SEC_ADUR end
  G.auras[id] = a
  W.fire("UNIT_AURA", "player", { addedAuras = { a } })
  return a
end

L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local function display(r, text)
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.text.enabled = text and true or false; r.sound.enabled = false
end
-- 1: a "ready" display of spell 4001
local CDR = ns.NewRule(); CDR.name = "cooldown ready"; CDR.enabled = true
CDR.useCooldown, CDR.spellID, CDR.cdState, CDR.buffState = true, 4001, "ready", "none"
display(CDR, false); CDR.visual.trigger = "condition"
ns.NormalizeRule(CDR); ns.rules[#ns.rules + 1] = CDR
-- 2: a buff display with its duration text, for aura 1005 (its time hidden)
local TX = ns.NewRule(); TX.name = "hidden time text"; TX.enabled = true
TX.useBuff, TX.buffID, TX.buffState, TX.cdState = true, 1005, "present", "none"
display(TX, true); TX.visual.trigger = "buffActive"
ns.NormalizeRule(TX); ns.rules[#ns.rules + 1] = TX
-- 4: a rule with a row type nothing knows (saved by a newer version, or damaged)
local UK = ns.NewRule(); UK.name = "unknown row"; UK.enabled = true
UK.useBuff, UK.buffID, UK.buffState, UK.cdState = true, 1006, "present", "none"
UK.extra = { mode = "all", list = { { type = "aRowTypeFromTheFuture", spellID = 5 } } }
display(UK, false); UK.visual.trigger = "condition"
ns.NormalizeRule(UK); ns.rules[#ns.rules + 1] = UK
ns.MarkDirty()
W.tick(1 / 60, 30)
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown(r) local fr = framesOf and framesOf[r]; return fr and fr:IsShown() and true or false end
local evals = setmetatable({}, { __mode = "k" })
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) evals[r] = (evals[r] or 0) + 1; return E0(r, ...) end
local function evN(r) return evals[r] or 0 end

---------------------------------------------------------------- 1. a cooldown's end in combat
W.enterCombat(); W.tick(1 / 60, 10)
check("(setup) out of the cooldown the 'ready' display shows", shown(CDR))
G.cds[4001] = { start = W.now, dur = 8 }
W.fire("SPELL_UPDATE_COOLDOWN", 4001); W.tick(1 / 60, 6)
check("(setup) in combat the spell goes on cooldown (start and duration secret): the 'ready' display hides", not shown(CDR))
local e0 = evN(CDR)
local endAt = G.cds[4001].start + G.cds[4001].dur
while W.now < endAt - 0.05 do W.tick(1 / 60, 1) end
check("1. while the hidden cooldown runs (about 8 s, no event), the rule is not re-checked (before: five times a second)",
  evN(CDR) - e0 == 0, evN(CDR) - e0)
local widgetFed = false
for _, w in ipairs(engineWidgets) do if (w._fed or 0) > 0 then widgetFed = true end end
check("1. ... the game counts it down: an engine Cooldown widget was fed the cooldown's duration object (the global cooldown counted, as the cooldown's reading counts it)",
  widgetFed and CDDUR[#CDDUR] and CDDUR[#CDDUR][1] == 4001 and CDDUR[#CDDUR][2] == false, #engineWidgets .. " widgets")
local backAt
while W.now < endAt + 0.5 do W.tick(1 / 60, 1); if not backAt and shown(CDR) then backAt = W.now - endAt end end
check("1. the cooldown ends with no event: the 'ready' display shows within two frames of the end (before: up to 0.2 s late)",
  backAt ~= nil and backAt <= 2 / 60 + 1e-6, backAt and ("%.0f ms"):format(backAt * 1000) or "not shown")
local host = engineWidgets[1] and engineWidgets[1]:GetParent()
check("1. the widgets take no mouse and draw nothing (alpha 0, 1x1 px), on a frame with no parent (hiding the game's UI does not stop them)",
  host ~= nil and host:GetAlpha() == 0 and not host:IsMouseEnabled() and not engineWidgets[1]:IsMouseEnabled() and host:GetParent() == nil,
  host and (tostring(host:GetAlpha()) .. "/" .. tostring(host:IsMouseEnabled()) .. "/" .. tostring(host:GetParent())) or "no widget")

---------------------------------------------------------------- 2. the seconds of a hidden aura time
local a = gain(1005, 30, true); W.tick(1 / 60, 8)
local fr = framesOf[TX]
local b = fr and fr.cdBind
check("(setup) in combat the buff (time hidden, instance readable) shows its display", shown(TX))
check("2. the display's text is counted down by the game: bound to the aura's own duration object and switched on",
  b and b.enabled and b.dur == a._dur and fr.text:IsShown(), b and tostring(b.enabled) or "no binding")
local same = b and b.fmt and true or false
if same then for _, x in ipairs({ 29.6, 12.2, 5, 4.96, 1.04, 0.44 }) do if b.fmt:FormatNumber(x) ~= ("%d"):format(x) then same = false end end end
check("2. ... in the same whole-seconds format the text showed before (29.6 s -> '29', 4.96 s -> '4')", same)
check("2. ... at its end it shows '0', as before", b and b.expired == "0" and b.zero == "0", b and tostring(b.expired))
local t0 = evN(TX)
W.tick(1 / 60, 180)
check("2. three seconds with nothing changing: the rule is not re-checked (before: five times a second)", evN(TX) - t0 == 0, evN(TX) - t0)
-- a refresh: the same aura instance gets a new time (the payload is hidden in combat)
local d2 = Duration(W.now, 30); a._dur = d2; G.auras[1005]._dur = d2
b = b or {}   -- (the code before round 7 made no binding: the checks below then fail, not error)
local sets0, refAt = b.sets or 0, W.now
W.fire("UNIT_AURA", "player", W.MarkSecret({ updatedAuraInstanceIDs = { a.auraInstanceID } }))
local boundAt
while W.now < refAt + 0.4 do W.tick(1 / 60, 1); if not boundAt and (b.sets or 0) > sets0 and b.dur == d2 then boundAt = W.now - refAt end end
check("2. the aura is refreshed (an aura event): the new time is bound within a tenth of a second and a frame",
  boundAt ~= nil and boundAt <= 0.1 + 1 / 60 + 1e-6, boundAt and ("%.0f ms"):format(boundAt * 1000) or "not bound")

---------------------------------------------------------------- 5. nothing scheduled while only the game counts
W.tick(0.25, 4)
check("5. a hidden cooldown running and a hidden aura time shown, no event: no engine timer is armed (the game counts both)",
  (function() G.cds[4001] = { start = W.now, dur = 6 }; W.fire("SPELL_UPDATE_COOLDOWN", 4001); W.tick(1 / 60, 12); return armedEngineTimers() == 0 end)(),
  armedEngineTimers())
G.auras[1005] = nil; W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { a.auraInstanceID } }); W.tick(0.1, 3)
W.leaveCombat(); W.tick(0.1, 3)

---------------------------------------------------------------- 4. a row type nothing routes
local u0 = evN(UK)
W.tick(1 / 60, 180)
check("4. a rule with a row type nothing knows: not re-checked in three quiet seconds (before: five times a second, for as long as it was loaded)",
  evN(UK) - u0 == 0, evN(UK) - u0)
local okUK, rUK, iUK = pcall(ns.Evaluate, UK, nil)
local missing = {}
for key in pairs(ns.TRIGGER_TYPES or {}) do
  local r = ns.NewRule(); r.name = "route " .. key; r.enabled = true; r.useBuff = false
  r.extra = { mode = "all", list = { { type = key, unit = "target" } } }
  local d = ns.EngineDeps(r)
  local routed = d.cd or d.aura or d.tgt or d.power or d.range or d.cast or d.other
  if not routed or d.poll then missing[#missing + 1] = key end
end
table.sort(missing)
check("4. every row type Triggers.lua knows has a route in the engine (an event re-checks it; none is left to a timer)",
  next(ns.TRIGGER_TYPES or {}) ~= nil and #missing == 0, table.concat(missing, ", "))

---------------------------------------------------------------- 3. a preview's sample countdown and sound loop
local PV = ns.NewRule(); PV.name = "preview"; PV.enabled = true
PV.useBuff, PV.buffID, PV.buffState, PV.cdState = true, 1007, "present", "none"
display(PV, true); PV.visual.trigger = "buffActive"
PV.sound.enabled, PV.sound.source, PV.sound.value = true, "file", "Interface\\AddOns\\XayaUI\\Media\\Audio\\CC0\\Kenney\\bong_001.ogg?pv"
ns.NormalizeRule(PV); ns.rules[#ns.rules + 1] = PV
ns.MarkDirty(); W.tick(1 / 60, 4)
ns.SetPreview({ PV }, "visual", true); ns.SetPreview({ PV }, "sound", true); W.tick(1 / 60, 3)
local pfr = framesOf[PV]
local p0, plays = evN(PV), {}
local played0 = #W.sounds
local mark = W.now
-- on every frame of 4.5 s, while the sample shows whole seconds (5 s or more left), the text must show the sample's current whole
-- second (FmtRemaining: the remaining seconds rounded up). A frame that falls in the millisecond between a whole second and its stored
-- moment may still show the last one: at most one such frame per whole second is allowed. (Before: about six stale frames per second.)
local frames, stale, seconds, lastSec = 0, 0, 0, nil
while W.now < mark + 4.5 do
  W.tick(1 / 60, 1)
  if #W.sounds > played0 then for i = played0 + 1, #W.sounds do plays[#plays + 1] = W.now end; played0 = #W.sounds end
  local rem = 12.3 - (ns.SampleTime() % 12.3)
  if rem >= 5 then
    frames = frames + 1
    local want = ("%d"):format(math.ceil(rem))
    if want ~= lastSec then seconds = seconds + 1; lastSec = want end
    if pfr.text:GetText() ~= want then stale = stale + 1 end
  end
end
check("3. the preview's sample countdown shows its current whole second on every frame (a stored moment at each second)",
  frames >= 60 and stale <= seconds, stale .. " stale frames of " .. frames .. ", " .. seconds .. " whole seconds")
check("3. ... and the previewed rule is re-checked about once per sample second and sound loop, not five times a second (before: about 22 in 4.5 s)",
  evN(PV) - p0 <= 12, evN(PV) - p0)
local gapsOK = #plays >= 2
for i = 2, #plays do local g = plays[i] - plays[i - 1]; if g < 2 - 1e-6 or g > 2 + 1 / 60 + 1e-6 then gapsOK = false end end
check("3. the sound preview loops every 2 s on its stored moment (each gap 2 s to 2 s + a frame; before: up to 2.2 s)", gapsOK,
  (function() local o = {}; for i = 2, #plays do o[#o + 1] = ("%.3f"):format(plays[i] - plays[i - 1]) end; return table.concat(o, " ") end)())
ns.ClearPreview(); W.tick(1 / 60, 3)

---------------------------------------------------------------- 5. the one remaining timer re-check, and /xui disable
local RF = ns.NewRule(); RF.name = "range to focus"; RF.enabled = true; RF.useBuff = false
RF.extra = { mode = "all", list = { { type = "rangeCheck", spellID = 6001, unit = "focus", state = "yes" } } }
display(RF, false); RF.visual.trigger = "condition"
ns.NormalizeRule(RF); ns.rules[#ns.rules + 1] = RF
ns.MarkDirty(); W.tick(1 / 60, 4)
local r0, others0 = evN(RF), evN(CDR) + evN(TX) + evN(UK)
W.tick(1 / 60, 60)
check("5. the only rule still re-checked on a timer is the Range Check on a focus (no game event for its range: her decision)",
  evN(RF) - r0 >= 4 and evN(CDR) + evN(TX) + evN(UK) - others0 == 0, (evN(RF) - r0) .. " / " .. (evN(CDR) + evN(TX) + evN(UK) - others0))
ns.SetRulesDisabled(true); W.tick(1 / 60, 3)
local cleared = true
for _, w in ipairs(engineWidgets) do if w._endAt then cleared = false end end
check("/xui disable: every engine cooldown widget is cleared and no engine timer stays armed", cleared and armedEngineTimers() == 0, armedEngineTimers())
ns.SetRulesDisabled(false); W.tick(1 / 60, 3)
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
