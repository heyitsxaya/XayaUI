#!/usr/bin/env python3
"""Offline test (round 9, display unit; REQUEST-LOG A23 SD-79, her answer "<=30/s, stop if idle (Recommended)", and SD-68, her answer
"option 2 with performance measurement built in for me to test -- if two is too extreme, we go to option 1 as our fallback").

A display's effects (Visual.lua: the fades, the "about to expire" flash, the progress wipe, the tenths of a second, a Bar cue's fill) run
at most 30 times a second while a run changes something on screen, stop when nothing changes, and start again on the next change that
needs them (an event, a threshold, a stored moment) with no visible delay. What the player sees is checked frame by frame at 144 frames a
second (a high-refresh monitor), in a fresh stand-in game with one display per case:

  1. FLASH (threshold 3 s on an 8 s buff): before the threshold nothing runs (no effects run, no frame script); the pulse starts on the
     first frame at or after the threshold moment (before round 9: the loop ran about 30 times a second for 5 s with nothing to change,
     and the pulse started on the loop's next run); after the buff runs out nothing runs while the buff is still listed (no removal event).
  2. FADE OPACITY (3 s buff): every run changes the opacity, at most 30 runs in any second; after the buff runs out, nothing runs; the
     buff refreshed: the fade starts again.
  3. TENTHS (4.5 s buff, tenths below 5 s): on every frame the text is the tenth the countdown has not yet gone below (floor(seconds left x
     10), shown as (key + 1) / 10: one key, one text); each change lands on the first frame of its tenth; every run changes the text
     (none idle; before: about 30 runs a second for 10 changes); no frame script runs at all.
  4. FADE FROM THE GAME'S DURATION OBJECT (an aura whose time the addon cannot read: a permanent buff here, so the curve's value never
     changes): at most the one run that finds nothing changes, then nothing (before: about 30 runs a second for as long as it showed);
     a duration object whose value moves: every run changes it, at most 30 a second, and the loop stops once it no longer moves.
  5. PREVIEW, PAUSED: a previewed fade display runs while the sample moves, and nothing runs while previews are paused (before: about
     30 runs a second, each changing nothing); unpaused, it moves again within two frames.
  6. BAR CUE: the fill moves at most 30 times a second, every run changes it, nothing runs after the buff runs out; an effects run of a
     Bar cue does not look up its parent rule by walking every rule (ns.FindParentRule: before, once per run).
  7. COUNTERS for her performance tracker (XayaUI_Debug, "tenths texts rewritten" / "bar fills written"): ns.EngineStats.redrawText rises
     by exactly the number of tenths texts written, ns.EngineStats.redrawFill by the fills written (before: always 0).
  8. ONE CLOCK (SD-68 option 2: what is drawn does not depend on how often the rules are re-checked): two identical displays on the same
     buff (tenths, fade, flash, wipe, and a Bar cue each), one of them re-checked again on about every third frame: they show exactly
     the same text, opacity, gray, color, wipe and fill on every frame (before: the extra re-checks wrote the rounded seconds, 4.2 at
     4.24 s, and a fresher fill, so the twins differed).
  9. WIPE IN WHOLE PIXELS (V27 "Whole-pixel / no float math"): every point of the wiped art is set in whole pixels, and the wipe runs only
     on the frames its edge reaches the next pixel (none idle; before: fractional points, about 30 runs a second).
 10. A FADE THAT CHANGES NOTHING on screen (a fade to a color equal to the display's own): the run that finds nothing changed stops the
     loop (exact-value compare; before: about 30 runs a second for the whole buff).
Stand-in: the whole-addon harness (tests/harness); C_CurveUtil and C_UnitAuras.GetAuraDuration are stand-ins built here (the stand-in game
has none). INFERENCE / UNVERIFIED IN GAME: in game a curve value from a duration object can be secret; such a value cannot be compared,
so it is counted as a change and its loop runs while the display shows (case 4 covers readable values only).
Run: python3 tests/fix_r9_display_fx_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local FRAME = 1 / 144
-- ---------------------------------------------------------------- the game model: player auras, duration objects, curves
local G = { auras = {}, nextIID = 100, dobj = {} }
local function copy(a) local t = {}; for k, v in pairs(a) do t[k] = v end; return t end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit ~= "player" then return nil end local a = G.auras[id]; return a and copy(a) or nil end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
C_UnitAuras.GetAuraDataByIndex = function(unit, i)
  if unit ~= "player" then return nil end
  local list = {}
  for _, a in pairs(G.auras) do list[#list + 1] = a end
  table.sort(list, function(x, y) return x.auraInstanceID < y.auraInstanceID end)
  return list[i] and copy(list[i]) or nil
end
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, iid) for _, a in pairs(G.auras) do if a.auraInstanceID == iid then return copy(a) end end end
C_UnitAuras.GetAuraDuration = function(unit, iid) return G.dobj[iid] end
local function Curve()
  local c = { pts = {} }
  c.SetType = function() end
  c.AddPoint = function(self, x, y) self.pts[#self.pts + 1] = { x, y } end
  c.At = function(self, x)
    local a, b = self.pts[1], self.pts[2]
    if type(a[2]) == "table" then return a[2] end   -- (color curves: not used by these cases)
    return a[2] + (b[2] - a[2]) * x
  end
  return c
end
C_CurveUtil = { CreateCurve = Curve, CreateColorCurve = Curve }
local function DurObj(pct) return { EvaluateRemainingPercent = function(self, cv) return cv:At(pct()) end } end
-- (case 4) an aura whose time the game hides: its expiration and duration are secret values, its instance id readable
local function secret(nm) return W.MarkSecret(setmetatable({}, { __tostring = function() return "SECRET " .. nm end })) end
local SEC_EXP, SEC_DUR = secret("expiration"), secret("duration")
local function newAura(id, dur)
  G.nextIID = G.nextIID + 1
  local a = { spellId = id, auraInstanceID = G.nextIID, name = "Spell " .. id, icon = 136243, applications = 1, duration = dur or 0,
    expirationTime = W.now + (dur or 0), isHelpful = true, sourceUnit = "player", isFromPlayerOrPlayerPet = true }
  if not dur then a.expirationTime, a.duration = SEC_EXP, SEC_DUR end
  return a
end
local function gain(id, dur)
  local old = G.auras[id]
  local a = newAura(id, dur)
  G.auras[id] = a
  W.fire("UNIT_AURA", "player", { addedAuras = { a }, removedAuraInstanceIDs = old and { old.auraInstanceID } or nil })
  return a
end
local function lose(id)
  local a = G.auras[id]
  if not a then return end
  G.auras[id] = nil
  W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { a.auraInstanceID } })
end
local function refresh(id)
  local a = G.auras[id]
  if type(a.duration) == "number" then a.expirationTime = W.now + a.duration end
  W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { a.auraInstanceID } })
end

W.RemoveAuraContainer()   -- (round 11 repair, standin-repair1) this test measures XayaUI's own drawing of aura displays: a client without Blizzard's aura container,
-- so the combat engine falls back (XUI-W002, declared below) and XayaUI draws them (tests/harness/world.lua)
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local function buff(nm, id, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.useBuff, r.buffID, r.buffState, r.cdState = true, id, "present", "none"
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 40, 40
  r.visual.trigger = "buffActive"; r.visual.text.enabled = false
  r.sound.enabled = false
  f(r.visual, r)
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local FL = buff("flash", 9101, function(v) v.flash = { enabled = true, threshold = 3, speed = 3 } end)
local FA = buff("fade opacity", 9102, function(v) v.fadeAlpha = true end)
local TE = buff("tenths", 9103, function(v) v.text.enabled = true; v.text.decimals = true; v.text.decimalBelow = 5 end)
local DO = buff("fade, duration object (still)", 9104, function(v) v.fadeAlpha = true end)
local DM = buff("fade, duration object (moving)", 9109, function(v) v.fadeAlpha = true end)
local PV = buff("preview fade", 9105, function(v) v.fadeGrey = true end)
local BP = buff("bar parent", 9106, function(v) v.enabled = false end)
local BA = ns.NewCueRule(BP, "bar"); BA.visual.w, BA.visual.h = 120, 20; BA.visual.text.enabled = false; ns.NormalizeRule(BA)
local function twin(nm)
  return buff(nm, 9107, function(v)
    v.text.enabled = true; v.text.decimals = true; v.text.decimalBelow = 5
    v.fadeAlpha = true; v.flash = { enabled = true, threshold = 3, speed = 3 }
    v.fill = { enabled = true, reverse = false, min = 0, max = 1, dir = "bottom" }
  end)
end
local TA, TB = twin("twin A"), twin("twin B")
local TAB = ns.NewCueRule(TA, "bar"); TAB.visual.w, TAB.visual.h = 120, 20; ns.NormalizeRule(TAB)
local TBB = ns.NewCueRule(TB, "bar"); TBB.visual.w, TBB.visual.h = 120, 20; ns.NormalizeRule(TBB)
local TC, TD = buff("twin C (tenths only)", 9110, function(v) v.text.enabled = true; v.text.decimals = true end),
               buff("twin D (tenths only)", 9110, function(v) v.text.enabled = true; v.text.decimals = true end)
local FC = buff("fade to its own color", 9111, function(v) v.fadeGrey = true; v.fadeMode = "color"; v.fadeColor = { 1, 1, 1, 1 } end)
local WI = buff("wipe", 9108, function(v) v.fill = { enabled = true, reverse = false, min = 0, max = 1, dir = "bottom" } end)
ns.MarkDirty()
W.tick(FRAME, 30)

-- ---------------------------------------------------------------- what is measured
local runs, inRun, parentWalks = {}, false, 0
local UVT0 = ns.UpdateVisualText
ns.UpdateVisualText = function(rule, info, fxOnly)
  if fxOnly then runs[rule] = (runs[rule] or 0) + 1 end
  local was = inRun; inRun = fxOnly and true or was
  local a, b, c = UVT0(rule, info, fxOnly)
  inRun = was
  return a, b, c
end
local FPR0 = ns.FindParentRule
ns.FindParentRule = function(rule) if inRun then parentWalks = parentWalks + 1 end return FPR0(rule) end
local function num(x) return type(x) == "number" and ("%.17g"):format(x) or tostring(x) end   -- (exact: as the gate compares)
local function snap(r)
  local fr = ns.DisplayFrame(r)
  if not (fr and fr:IsShown()) then return "hidden" end
  local t = { fr.text:IsShown() and tostring(fr.text:GetText()) or "-", num(fr:GetAlpha()), tostring(fr.tex._desat), num(select(1, fr.tex:GetVertexColor())),
    num(select(2, fr.tex:GetVertexColor())), tostring(fr.tex:IsShown()) }
  for i = 1, 2 do local p, _, _, x, y = fr.tex:GetPoint(i); t[#t + 1] = tostring(p) .. "@" .. num(x) .. "," .. num(y) end
  t[#t + 1] = (fr.barF and fr.barF:IsShown()) and num(fr.barF:GetValue()) or "-"
  return table.concat(t, "|")
end
local function texPoints(r)
  local fr = ns.DisplayFrame(r); local out = {}
  for i = 1, 2 do local _, _, _, x, y = fr.tex:GetPoint(i); out[#out + 1] = x; out[#out + 1] = y end
  return out
end
local function scriptOn(r) local fr = ns.DisplayFrame(r); return fr and fr._scripts and fr._scripts.OnUpdate ~= nil and fr:IsVisible() end
local function watch(list)
  local st = {}
  for _, r in ipairs(list) do st[r] = { runs = 0, idle = 0, changes = 0, script = 0, last = snap(r), times = {}, changeAt = {} } end
  return st
end
-- one frame; extra(rule) may re-check displays after it (case 8)
local function frame(st, after)
  for r, s in pairs(st) do if scriptOn(r) then s.script = s.script + 1 end; s.r0 = runs[r] or 0 end
  W.tick(FRAME, 1)
  if after then after() end
  for r, s in pairs(st) do
    local now = snap(r)
    local dr = (runs[r] or 0) - s.r0
    s.runs = s.runs + dr
    for _ = 1, dr do s.times[#s.times + 1] = W.now end
    if now ~= s.last then s.changes = s.changes + 1; s.changeAt[#s.changeAt + 1] = W.now; s.firstChange = s.firstChange or W.now
    elseif dr > 0 then s.idle = s.idle + dr end
    s.last = now
  end
end
local function mostPerSecond(times)
  local most, j = 0, 1
  for i = 1, #times do
    while times[i] - times[j] > 1 - 1e-6 do j = j + 1 end
    if i - j + 1 > most then most = i - j + 1 end
  end
  return most
end
local function until_(st, t, after) while W.now + FRAME <= t + 1e-9 do frame(st, after) end end
local function shown(r) local fr = ns.DisplayFrame(r); return fr and fr:IsShown() end
-- (round 11 repair) wait for a display to show, at most SHOW_WAIT seconds of frames: a display that never shows is a named failed check,
-- not a run that waits forever (the guard, tests/run_all.py, would read it as HUNG after 600 s). The displays here show on the frame
-- after their aura arrives (case 1 checks that after two frames), so 2 s is ample.
local SHOW_WAIT = 2
local function waitShown(st, r, what)
  local t0 = W.now
  while not shown(r) and W.now - t0 < SHOW_WAIT do frame(st) end
  check("(setup) " .. what .. ": the display shows within " .. SHOW_WAIT .. " s of its aura arriving", shown(r),
    string.format("waited %.2f s", W.now - t0))
end

-- ================================================================ 1. FLASH
do
  local a = gain(9101, 8.0003)
  local M = a.expirationTime - 3
  local st = watch({ FL })
  frame(st); frame(st)   -- (the gain is drawn)
  check("(setup) 1. the flash display shows", shown(FL))
  local s = st[FL]; s.runs, s.script, s.changes, s.firstChange = 0, 0, 0, nil
  until_(st, M - FRAME / 2)
  check("1. FLASH before its 3 s threshold: no effects run and no frame script runs (nothing on screen changes)",
    s.runs == 0 and s.script == 0 and s.changes == 0, string.format("runs %d, frames with the loop's frame script %d, changes %d", s.runs, s.script, s.changes))
  s.firstChange = nil
  until_(st, M + 0.5)
  local firstFrame = nil
  do local t = W.now; while t - FRAME >= M - 1e-9 do t = t - FRAME end; firstFrame = t end
  check("1. ... the pulse starts on the first frame at or after the threshold moment",
    s.changeAt[1] ~= nil and math.abs(s.changeAt[1] - firstFrame) < 1e-6, string.format("first change %.4f s after the threshold, first frame after it %.4f s",
      (s.changeAt[1] or 0) - M, firstFrame - M))
  local idle0, runs0 = s.idle, s.runs
  until_(st, a.expirationTime + 0.2)
  check("1. ... while it pulses, every run changes the opacity, at most 30 runs in any second",
    s.idle == 0 and mostPerSecond(s.times) <= 30 and s.runs > 0, string.format("idle runs %d, most runs in one second %d", s.idle, mostPerSecond(s.times)))
  local r1, sc1 = s.runs, s.script
  until_(st, a.expirationTime + 2.2)
  check("1. ... after the buff ran out (still listed, no removal event): nothing runs for 2 s",
    s.runs == r1 and s.script == sc1, string.format("runs %d, frame-script frames %d", s.runs - r1, s.script - sc1))
  lose(9101); frame(st); frame(st)
end

-- ================================================================ 2. FADE OPACITY (and 7: no counters here)
do
  local a = gain(9102, 3.0003)
  local st = watch({ FA })
  frame(st); frame(st)
  local s = st[FA]; s.runs, s.idle, s.times = 0, 0, {}
  until_(st, a.expirationTime + 0.2)
  check("2. FADE OPACITY: every run changes the opacity, at most 30 runs in any second",
    s.idle == 0 and s.runs >= 60 and mostPerSecond(s.times) <= 30, string.format("runs %d, idle runs %d, most in one second %d", s.runs, s.idle, mostPerSecond(s.times)))
  local r1, sc1 = s.runs, s.script
  until_(st, a.expirationTime + 2.2)
  check("2. ... after the buff ran out: nothing runs for 2 s (before: until the removal event)",
    s.runs == r1 and s.script == sc1, string.format("runs %d, frame-script frames %d", s.runs - r1, s.script - sc1))
  local alpha0 = ns.DisplayFrame(FA):GetAlpha()
  refresh(9102)
  local t0 = W.now
  local moved = nil
  for _ = 1, 40 do frame(st); if not moved and ns.DisplayFrame(FA):GetAlpha() ~= alpha0 then moved = W.now - t0 end end
  local r2 = s.runs
  for _ = 1, 30 do frame(st) end
  check("2. ... the buff refreshed: the fade is drawn again at once and moves again (its loop restarted)",
    moved ~= nil and moved <= 0.1 + 2 * FRAME and s.runs > r2, string.format("drawn %.3f s after the event; runs after it %d", moved or -1, s.runs - r2))
  lose(9102); frame(st); frame(st)
end

-- ================================================================ 3. TENTHS (and 7: the text counter)
do
  local ES = ns.EngineStats or {}
  local a = gain(9103, 4.5003)
  local st = watch({ TE })
  frame(st)
  waitShown(st, TE, "3. the tenths display")
  local s = st[TE]; s.runs, s.idle, s.changes, s.script, s.times = 0, 0, 0, 0, {}
  local text0 = ES.redrawText or 0
  local bad, firstBad, frames_, written = 0, nil, 0, 0
  local lastText = ns.DisplayFrame(TE).text:GetText()
  while a.expirationTime - W.now > FRAME do
    frame(st)
    local rem = a.expirationTime - W.now
    local k = math.floor(rem * 10)
    local want = ("%.1f"):format((k + 1) / 10)
    local got = ns.DisplayFrame(TE).text:GetText()
    frames_ = frames_ + 1
    if got ~= lastText then written = written + 1; lastText = got end
    if got ~= want then bad = bad + 1; firstBad = firstBad or string.format("%.4f s left: shows %s, the tenth not yet gone below is %s", rem, tostring(got), want) end
  end
  check("3. TENTHS: on every frame the text is the tenth the countdown has not yet gone below (one key: floor(seconds left x 10))",
    bad == 0, string.format("%d of %d frames differ%s", bad, frames_, firstBad and ("; first: " .. firstBad) or ""))
  check("3. ... every effects run changes the text (none idle), and no frame script runs",
    s.idle == 0 and s.script == 0 and s.runs > 0, string.format("runs %d, idle %d, changes %d, frame-script frames %d", s.runs, s.idle, s.changes, s.script))
  check("7. COUNTER: ns.EngineStats.redrawText rose by exactly the tenths texts written (her tracker's 'tenths texts rewritten')",
    (ES.redrawText or 0) - text0 == written and written > 0, string.format("rose by %d; texts written %d", (ES.redrawText or 0) - text0, written))
  local r1 = s.runs
  until_(st, a.expirationTime + 1.5)
  check("3. ... after the buff ran out (still listed, no removal event): no effects run for 1.5 s", s.runs == r1, string.format("runs %d", s.runs - r1))
  lose(9103); frame(st); frame(st)
end

-- ================================================================ 4. DURATION OBJECT
do
  local a = gain(9104)   -- (its time hidden: the addon cannot read it)
  G.dobj[a.auraInstanceID] = DurObj(function() return 0.5 end)
  local st = watch({ DO })
  for _ = 1, 72 do frame(st) end   -- (half a second: the gain is drawn at the engine's own pace, at most 10 passes a second)
  check("(setup) 4. the display shows, drawn from the duration object (opacity 0.15 + 0.85 x 0.5)", shown(DO) and math.abs(ns.DisplayFrame(DO):GetAlpha() - 0.575) < 1e-6,
    ns.DisplayFrame(DO):GetAlpha())
  local s = st[DO]; s.runs, s.idle, s.script = 0, 0, 0
  for _ = 1, 288 do frame(st) end
  check("4. FADE FROM A DURATION OBJECT whose value does not move: at most the one run that finds nothing changes, then nothing for 2 s",
    s.runs <= 1 and s.script <= 2, string.format("runs %d, frame-script frames %d", s.runs, s.script))
  local r0, sc0 = s.runs, s.script
  for _ = 1, 5 do
    ns.UpdateVisualText(DO, ns.runtime[DO].info)   -- (a re-check of the rule, as the engine draws one)
    for _ = 1, 29 do frame(st) end
  end
  check("4. ... re-checked five times: still nothing runs (a re-check that draws the same value does not start the loop)",
    s.runs == r0 and s.script == sc0, string.format("runs %d, frame-script frames %d", s.runs - r0, s.script - sc0))
  lose(9104); frame(st); frame(st)
  local b = gain(9109)
  local t0 = W.now
  G.dobj[b.auraInstanceID] = DurObj(function() local p = 1 - (W.now - t0) / 2; if p < 0 then p = 0 end return p end)
  local st2 = watch({ DM })
  for _ = 1, 4 do frame(st2) end
  local s2 = st2[DM]; s2.runs, s2.idle, s2.times = 0, 0, {}
  until_(st2, t0 + 2.0)
  check("4. ... a duration object whose value moves: every run changes the opacity, at most 30 a second",
    s2.idle == 0 and s2.runs >= 40 and mostPerSecond(s2.times) <= 30, string.format("runs %d, idle %d, most in one second %d", s2.runs, s2.idle, mostPerSecond(s2.times)))
  local r1, i1 = s2.runs, s2.idle
  until_(st2, t0 + 4.0)
  check("4. ... once it no longer moves: the one run that finds nothing changed, then nothing", s2.runs - r1 <= 2 and s2.idle - i1 <= 1,
    string.format("runs %d, idle %d", s2.runs - r1, s2.idle - i1))
  lose(9109); frame(st2); frame(st2)
end

-- ================================================================ 5. PREVIEW, PAUSED
do
  ns.SetPreview({ PV }, "visual", true)
  local st = watch({ PV })
  for _ = 1, 10 do frame(st) end
  local s = st[PV]; s.runs, s.idle, s.times, s.script = 0, 0, {}, 0
  for _ = 1, 144 do frame(st) end
  check("5. PREVIEW: a previewed fade moves with the sample, every run changes it, at most 30 a second",
    s.runs >= 25 and s.idle == 0 and mostPerSecond(s.times) <= 30, string.format("runs %d, idle %d, most in one second %d", s.runs, s.idle, mostPerSecond(s.times)))
  ns.SetPreviewPaused(true)
  for _ = 1, 4 do frame(st) end
  local r1, sc1 = s.runs, s.script
  for _ = 1, 288 do frame(st) end
  check("5. ... previews paused: nothing runs for 2 s (before: about 30 runs a second, each changing nothing)",
    s.runs == r1 and s.script == sc1, string.format("runs %d, frame-script frames %d", s.runs - r1, s.script - sc1))
  local g0 = ns.DisplayFrame(PV).tex._desat
  ns.SetPreviewPaused(false)
  local t0, moved = W.now, nil
  for _ = 1, 20 do frame(st); if not moved and ns.DisplayFrame(PV).tex._desat ~= g0 then moved = W.now - t0 end end
  check("5. ... unpaused: it moves again within two frames", moved ~= nil and moved <= 2 * FRAME + 1e-6, string.format("%.4f s", moved or -1))
  ns.SetPreview({ PV }, "visual", false)
  for _ = 1, 10 do frame(st) end
end

-- ================================================================ 6. BAR CUE (and 7: the fill counter)
do
  local ES = ns.EngineStats or {}
  local a = gain(9106, 3.0003)
  local st = watch({ BA })
  frame(st)
  waitShown(st, BA, "6. the bar cue display")
  local s = st[BA]; s.runs, s.idle, s.times = 0, 0, {}
  local fill0, walks0 = ES.redrawFill or 0, parentWalks
  local written, last = 0, ns.DisplayFrame(BA).barF:GetValue()
  while W.now + FRAME <= a.expirationTime + 0.2 do
    frame(st)
    local v = ns.DisplayFrame(BA).barF:GetValue()
    if v ~= last then written = written + 1; last = v end
  end
  check("6. BAR CUE: the fill moves at most 30 times a second and every run changes it",
    s.runs >= 60 and s.idle == 0 and mostPerSecond(s.times) <= 30, string.format("runs %d, idle %d, most in one second %d", s.runs, s.idle, mostPerSecond(s.times)))
  check("6. ... an effects run does not look up the cue's parent by walking every rule (ns.FindParentRule)",
    parentWalks - walks0 == 0, string.format("%d lookups in %d runs", parentWalks - walks0, s.runs))
  check("7. COUNTER: ns.EngineStats.redrawFill rose by exactly the fills written (her tracker's 'bar fills written')",
    (ES.redrawFill or 0) - fill0 == written and written > 0, string.format("rose by %d; fills written %d", (ES.redrawFill or 0) - fill0, written))
  local r1 = s.runs
  until_(st, a.expirationTime + 2.2)
  check("6. ... after the buff ran out: nothing runs for 2 s", s.runs == r1, string.format("runs %d", s.runs - r1))
  lose(9106); frame(st); frame(st)
end

-- ================================================================ 8. ONE CLOCK: twins, one re-checked again on about every third frame
do
  local function twins(id, dur, pairs_, label)
    local a = gain(id, dur)
    local list = {}
    for _, p in ipairs(pairs_) do list[#list + 1] = p[1]; list[#list + 1] = p[2] end
    local st = watch(list)
    frame(st)
    local n, diff, first, frames_ = 0, 0, nil, 0
    local function extra()
      n = n + 1
      if n % 3 == 0 or n % 7 == 0 then
        for _, p in ipairs(pairs_) do
          local rt = ns.runtime[p[2]]
          if rt and rt.visualWanted then ns.UpdateVisualText(p[2], rt.info) end
        end
      end
    end
    while W.now + FRAME <= a.expirationTime + 0.3 do
      frame(st, extra)
      frames_ = frames_ + 1
      for _, p in ipairs(pairs_) do
        local x, y = snap(p[1]), snap(p[2])
        if x ~= y then diff = diff + 1; first = first or string.format("%.4f s left, %s: %s / %s", a.expirationTime - W.now, p[1].name, x, y) end
      end
    end
    check("8. ONE CLOCK (" .. label .. "): a display re-checked again on about every third frame shows exactly what its twin shows, on every frame",
      diff == 0 and frames_ > 100, string.format("%d differing frames of %d%s", diff, frames_, first and ("; first: " .. first) or ""))
    lose(id); frame(st); frame(st)
  end
  twins(9107, 4.8003, { { TA, TB }, { TAB, TBB } }, "tenths, fade, flash, wipe, and a Bar cue's fill")
  twins(9110, 4.6003, { { TC, TD } }, "tenths only")
end

-- ================================================================ 10. A FADE THAT CHANGES NOTHING (its color is the display's own)
do
  local a = gain(9111, 4.0003)
  local st = watch({ FC })
  for _ = 1, 30 do frame(st) end
  check("(setup) 10. the display shows", shown(FC))
  local s = st[FC]; s.runs, s.script, s.idle = 0, 0, 0
  for _ = 1, 288 do frame(st) end
  check("10. a fade to a color equal to the display's own color (nothing on screen changes): at most the one run that finds that, then nothing for 2 s",
    s.runs <= 1 and s.script <= 2, string.format("runs %d, idle %d, frame-script frames %d", s.runs, s.idle, s.script))
  lose(9111); frame(st); frame(st)
end

-- ================================================================ 9. WIPE IN WHOLE PIXELS
do
  local a = gain(9108, 6.0003)
  local st = watch({ WI })
  frame(st)
  waitShown(st, WI, "9. the wipe display")
  local s = st[WI]; s.runs, s.idle, s.times, s.changes = 0, 0, {}, 0
  local frac, firstFrac = 0, nil
  while W.now + FRAME <= a.expirationTime + 0.2 do
    frame(st)
    for _, x in ipairs(texPoints(WI)) do
      if type(x) == "number" and x ~= math.floor(x) then frac = frac + 1; firstFrac = firstFrac or x end
    end
  end
  check("9. WIPE: every point of the wiped art is set in whole pixels", frac == 0, string.format("%d fractional offsets, first %s", frac, tostring(firstFrac)))
  check("9. ... the wipe runs only on frames its edge reaches the next pixel (none idle), at most 30 runs a second",
    s.idle == 0 and s.runs >= 30 and mostPerSecond(s.times) <= 30, string.format("runs %d, idle %d, changes %d, most in one second %d", s.runs, s.idle, s.changes, mostPerSecond(s.times)))
  lose(9108); frame(st); frame(st)
end
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
    total = bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], bool(res[i][2])
        total += 1
        print(("ok  " if ok else "FAIL: ") + name)
        bad += 0 if ok else 1
    nerr = len(world.errors)
    for i in range(1, nerr + 1):
        print("ERROR in the game stand-in: %s" % str(world.errors[i])[:600])
    print("EXPECT_ERRORS XUI-W002 1")   # (round 11 repair) one per stand-in session, caused on purpose by W.RemoveAuraContainer() above (Combat/AuraDisplay.lua records it once per session)
    print("%d checks, %d failed, %d Lua errors" % (total, bad, nerr))
    sys.exit(1 if bad or nerr else 0)


if __name__ == "__main__":
    main()
