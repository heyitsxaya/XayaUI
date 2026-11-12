#!/usr/bin/env python3
"""Round 5, V27 gate fixes in XayaUI/MinimapButton.lua and XayaUI_Rules/Engine.lua (label gate2).

V27 (Xaya, 2026-11-10, REQUEST-LOG A23 SD-28 / SD-29, her words): "nothing impacts mouse ability to interact with (click, toggle, use,
etc) in-game objects, buttons, or screen panning once xui options window is closed" and "zero code loops, zero unnecessary complex
calculations, zero floating numbers"; her answers: mouse "Hover only, clicks pass" (the minimap menu closes on any click or Esc without
catching that click), loops "No running loops", numbers "Whole-pixel / no float math". SD-35: her right-click on a lootable corpse was
not recognized; the suspect named then was the minimap list's full-screen click catcher. SD-49: "The latency dropped for mouse clicks
after I turned off xui".

Minimap button (what the player gets):
  M1 with the list open, a click in the middle of the screen reaches the game: no shown XayaUI frame there takes clicks
  M2 that click (a mouse press on the game world) closes the list
  M3 a press on one of the list's own rows does not close the list before the row acts; the row's action runs
  M4 a press on the minimap button while the list is open leaves it to the button, whose click closes the list (no close-and-reopen)
  M5 Esc closes the list: it is in UISpecialFrames, the game's own Esc handling
  M6 with the list closed nothing listens for mouse presses
  M7 the button sits on whole pixels (the angle math gave -61.44, -43.02), and its pieces have whole-pixel sizes at any size
  M8 a drag stores whole degrees, as the slider does
Rules engine (what the player gets, and what it costs):
  E1 idle: rules loaded, nothing changing for 30 s: the engine has no OnUpdate script running and re-checks no rule (before: every
     frame, every rule five times a second)
  E2 a buff appearing shows its display on the next frame (kept)
  E3 a display's countdown keeps counting in whole seconds with no event at all (kept: a stored moment, not a tick)
  E4 a cooldown "ready" rule fires when the cooldown ends with no event at that moment (the stored end; before: up to 0.2 s later)
  E5 in combat, where the game hides the cooldown's end, the rule still fires within one TICK of the end (kept: re-checked only while
     it runs) and nothing is re-checked once it has fired
  E6 "cast within 3 seconds": true after the cast, false 3 s later with no event (kept: the stored end of the window)
  E7 a repeat sound repeats with no event (kept)
  E8 "Only when mounted": mounting shows the display on the next frame (a load fact; before: up to 50 ms later)
  E9 a cast, movement or target change (ns.MarkStateDirty) re-checks only the loaded rules, not the 290 rules that are not loaded
     (before: every rule)
  E10 a target debuff rule follows UNIT_AURA on the target on the next frame (registered only while such a rule is loaded; before: the
      next 0.2 s tick)
  E11 /xui disable: no OnUpdate, no timer, no input event; /xui enable: the rules are back on the next frame
Every check marked [new] fails on the pre-change files (proved on a copy, r5copy-gate2); the others are behaviour kept (V32).
Run: python3 tests/fix_r5_gate2_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- the game's reads this test drives: the player's auras, cooldowns (readable, or secret in combat), mounted
local AUR, CDS, SECRET = {}, {}, false
local nextIID = 500
local function gain(id, dur) nextIID = nextIID + 1; AUR[id] = { auraInstanceID = nextIID, spellId = id, name = "Spell " .. id, icon = 136243, applications = 1,
  duration = dur, expirationTime = W.now + dur, isHelpful = true, sourceUnit = "player", isFromPlayerOrPlayerPet = true }; return AUR[id] end
local mounted = false
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
local function copy(t) if not t then return nil end local o = {}; for k, v in pairs(t) do o[k] = v end; return o end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return copy(AUR[id]) end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit == "player" then return copy(AUR[id]) end end
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, iid) for _, a in pairs(AUR) do if a.auraInstanceID == iid then return copy(a) end end end
C_Spell.GetSpellCooldown = function(id)
  local c = CDS[tonumber(id) or 0]
  if c and W.now < c.s + c.d then
    if SECRET then return { startTime = W.MarkSecret and W.MarkSecret(c.s + 0) or c.s, duration = W.MarkSecret and W.MarkSecret(c.d + 0) or c.d, isEnabled = true, modRate = 1, isActive = true, isOnGCD = false } end
    return { startTime = c.s, duration = c.d, isEnabled = true, modRate = 1, isActive = true, isOnGCD = false }
  end
  return { startTime = 0, duration = 0, isEnabled = true, modRate = 1, isActive = false, isOnGCD = false }
end
C_SpellBook = C_SpellBook or {}
C_SpellBook.IsSpellKnownOrInSpellBook = function() return true end
IsPlayerSpell = function() return true end
IsMounted = function() return mounted end

-------------------------------------------------------------------------------------------------------------------------------
-- the minimap button
-------------------------------------------------------------------------------------------------------------------------------
do
  ns.Minimap_Refresh()
  local b = rawget(_G, "XayaUIMinimapButton")
  check("the minimap button is shown", b ~= nil and b:IsVisible())
  if b then
    local ran = 0
    ns.RegisterLauncher({ "gate2test", "Gate test row", "a row for this test", function() ran = ran + 1 end, order = 99 })
    ns.minimapDB.closeOnClick = true
    -- M1: the frames that take a click in the middle of the screen (a Button takes clicks unless told not to; any frame with the mouse
    -- on), before and while the list is open
    local function takers()
      local out = {}
      local cx, cy = (UIParent:GetWidth() or 1920) / 2, (UIParent:GetHeight() or 1080) / 2
      for _, o in ipairs(W.objects) do
        if o ~= UIParent and o ~= WorldFrame and (o._kind == "Button" or o._mouse) and o:IsVisible() then
          local r = W.rect(o)
          if r and r.w and r.w > 0 and r.l <= cx and cx <= r.l + r.w and r.b <= cy and cy <= r.b + r.h then out[o] = string.format("%s %dx%d", o._kind, r.w, r.h) end
        end
      end
      return out
    end
    local before = takers()
    b:Click("LeftButton"); W.tick(0.05, 1)
    local menu = rawget(_G, "XayaUIMinimapMenu")
    check("a click on the button opens the list", menu ~= nil and menu:IsVisible())
    local taker
    for o, what in pairs(takers()) do if not before[o] then taker = what end end
    check("[new] M1 with the list open, a click in the middle of the screen is not taken by any XayaUI frame (it reaches the game)", taker == nil, taker)
    -- M2: a mouse press on the game world
    W.mouseOver = WorldFrame; W.fire("GLOBAL_MOUSE_DOWN", "LeftButton"); W.fire("GLOBAL_MOUSE_UP", "LeftButton"); W.mouseOver = nil
    check("[new] M2 that press on the game world closes the list", not menu:IsVisible())
    -- M3: a press on a row of the list
    if menu:IsVisible() then menu:Hide() end
    b:Click("LeftButton"); W.tick(0.05, 1)
    local row
    for _, r in ipairs(menu.rows or {}) do if r:IsShown() and r.entry and r.entry[1] == "gate2test" then row = r end end
    if row then
      W.mouseOver = row; W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
      local stillOpen = menu:IsVisible()
      row:Click("LeftButton"); W.fire("GLOBAL_MOUSE_UP", "LeftButton"); W.mouseOver = nil
      check("M3 a press on a row of the list leaves it open until the row acts, and the row's action runs", stillOpen and ran == 1, tostring(stillOpen) .. " / " .. ran)
    else
      check("M3 the test row is in the list", false)
    end
    -- M4: the opening button pressed while the list is open
    if menu:IsVisible() then menu:Hide() end
    b:Click("LeftButton"); W.tick(0.05, 1)
    W.mouseOver = b; W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    local openAfterDown = menu:IsVisible()
    b:Click("LeftButton"); W.fire("GLOBAL_MOUSE_UP", "LeftButton"); W.mouseOver = nil; W.tick(0.05, 1)
    check("M4 a press on the minimap button with the list open is left to the button: its click closes the list (no close and reopen)",
      openAfterDown and not menu:IsVisible(), tostring(openAfterDown) .. " / " .. tostring(menu:IsVisible()))
    -- M5: Esc
    local special = false
    for _, n in ipairs(UISpecialFrames or {}) do if n == "XayaUIMinimapMenu" then special = true end end
    check("[new] M5 Esc closes the list: XayaUIMinimapMenu is in UISpecialFrames (the game's own Esc handling)", special)
    -- M6: closed, nothing listens
    if menu:IsVisible() then menu:Hide() end
    check("M6 with the list closed, nothing listens for mouse presses", not (menu._events and menu._events.GLOBAL_MOUSE_DOWN))
    -- M7: whole pixels
    local function whole(v) return type(v) ~= "number" or v == math.floor(v) end
    ns.minimapDB.angle = 215; ns.minimapDB.size = 31; ns.Minimap_Refresh()
    local p = b._pts[1]
    check("[new] M7 the button sits on whole pixels at 215 degrees", p and whole(p[4]) and whole(p[5]), p and (tostring(p[4]) .. ", " .. tostring(p[5])))
    ns.minimapDB.size = 24; ns.Minimap_Refresh()
    local okSizes = whole(b.icon._w) and whole(b.bg._w) and whole(b.mask._w) and whole(b.border._w) and whole(b.icon._pts[1][5])
    check("[new] M7 at size 24 every piece has a whole-pixel size and offset", okSizes,
      table.concat({ tostring(b.icon._w), tostring(b.bg._w), tostring(b.border._w), tostring(b.icon._pts[1][5]) }, ", "))
    ns.minimapDB.size = 31; ns.Minimap_Refresh()
    -- M8: a drag stores whole degrees
    local GCP = GetCursorPosition
    GetCursorPosition = function() local mx, my = Minimap:GetCenter(); return mx + 37.3, my + 11.9 end
    local ds = b._scripts.OnDragStart; ds(b)
    local ou = b._scripts.OnUpdate; if ou then ou(b, 0.016) end
    b._scripts.OnDragStop(b)
    GetCursorPosition = GCP
    check("[new] M8 a drag stores whole degrees, as the slider sets them", whole(ns.minimapDB.angle), ns.minimapDB.angle)
    ns.minimapDB.angle = 215; ns.Minimap_Refresh()
  end
end

-------------------------------------------------------------------------------------------------------------------------------
-- the rules engine
-------------------------------------------------------------------------------------------------------------------------------
local played = 0
PlaySound = function() played = played + 1; return true, 1 end
PlaySoundFile = function() played = played + 1; return true, 1 end
ns.rules = {}
local function mk(name, f)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.visual.enabled, r.sound.enabled = false, false; f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local function snd(r) r.sound.enabled = true; r.sound.source, r.sound.value = "kit", "8959" end
-- a buff with a display and its countdown
local BUFF = mk("buff", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1001, "present", "none"
  r.visual.enabled = true; r.visual.trigger = "buffActive"; r.visual.text = r.visual.text or {}; r.visual.text.enabled = true; r.visual.text.decimals = false end)
-- a cooldown "ready" rule with a sound
local CD = mk("cd", function(r) r.useCooldown, r.spellID, r.cdState, r.buffState = true, 2001, "ready", "none"; snd(r) end)
-- "cast within 3 seconds"
local CAST = mk("cast", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "castSucceeded", spellID = 0, window = 3, state = "yes" } } } end)
-- a repeat sound while the buff is up
local REP = mk("repeat", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1002, "present", "none"; r.repeatSec = 2; snd(r) end)
-- only when mounted
local MOUNT = mk("mounted", function(r) r.cdState, r.buffState = "none", "none"; r.load = r.load or {}; r.load.mounted = "yes"
  r.visual.enabled = true; r.visual.trigger = "condition" end)
-- a target debuff rule
local TGT = mk("tgt", function(r) r.cdState, r.buffState = "none", "none"; r.extra = { list = { { type = "targetDebuff", spellID = 3001, unit = "target", state = "yes" } } } end)
-- 290 rules that do not load here (only in a raid group)
local NL = {}
for i = 1, 290 do NL[i] = mk("not loaded " .. i, function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1100 + i, "present", "none"
  r.load = r.load or {}; r.load.raid = "yes" end) end
ns.MarkDirty(); W.tick(0.05, 2)

local n = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) n[r] = (n[r] or 0) + 1; return E0(r, ...) end
local function reset() for k in pairs(n) do n[k] = nil end end
local function total() local t = 0; for _, v in pairs(n) do t = t + v end; return t end
local function engineOnUpdate()
  for _, o in ipairs(W.objects) do
    local fn = o._scripts and o._scripts.OnUpdate
    if fn then local info = debug.getinfo(fn, "S"); if info and tostring(info.source):find("Engine.lua", 1, true) then return true end end
  end
  return false
end
local function pendingTimers() local c = 0; for _, t in ipairs(W.timers) do if not t.cancelled then c = c + 1 end end; return c end
local function frameOf(rule) local l = ns.VisualFramesOf and ns.VisualFramesOf(rule); return l and l[1] end
local function shown(rule) local fr = frameOf(rule); return fr ~= nil and fr:IsShown() end

-- E1 idle
W.tick(0.5, 2)
reset()
local timers0 = pendingTimers()
local ouSeen = false
for _ = 1, 300 do W.tick(0.1, 1); ouSeen = ouSeen or engineOnUpdate() end
check("[new] E1 idle 30 s with rules loaded and nothing changing: the engine's OnUpdate never runs", not ouSeen)
check("[new] E1 idle 30 s: no rule is re-checked", total() == 0, total())
check("E1 idle 30 s: no timer is left waiting", pendingTimers() == 0, pendingTimers() .. " (before: " .. timers0 .. ")")

-- E2 a buff appears: its display on the next frame
gain(1001, 10)
W.fire("UNIT_AURA", "player", { addedAuras = { AUR[1001] } }); W.tick(1 / 60, 1)
check("E2 a buff appearing shows its display on the next frame", shown(BUFF))
local fr = frameOf(BUFF)
local function txt() return fr and fr.text and fr.text._text end
local t0 = txt()
-- E3 the countdown, with no event for 3.5 s
W.tick(0.1, 35)
local t1 = txt()
check("E3 the display's countdown keeps counting with no event (10 s buff, 3.5 s later it reads 6 or 7)", t1 == "6" or t1 == "7" or t1 == "6s" or t1 == "7s",
  tostring(t0) .. " -> " .. tostring(t1))
AUR[1001] = nil; W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { 501 } }); W.tick(1 / 60, 2)
check("E2 the buff gone hides its display on the next frame", not shown(BUFF))

-- E4 a cooldown ends with no event
played = 0
W.tick(0.1, 1)   -- (round 7, SD-61 "10/s for all": a quiet tenth of a second since the last aura / cooldown re-check, so this event's is the
                 -- very next frame; inside that tenth it would wait for the pace)
CDS[2001] = { s = W.now, d = 5 }
W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(1 / 60, 2)
local rtCD = ns.runtime[CD]
check("E4 the cooldown rule is false while the cooldown runs", rtCD and rtCD.active == false, rtCD and tostring(rtCD.active))
W.tick(0.25, 19)   -- 4.75 s, no event
check("E4 still not ready at 4.8 s", played == 0, played)
W.tick(0.1, 3)
check("[new] E4 the cooldown 'ready' rule fires at the cooldown's end (within 0.1 s), with no event at that moment (before: up to the next 0.2 s tick)", played == 1 and rtCD.active == true, played)

-- E5 in combat the end is hidden: re-checked only while it runs
W.enterCombat(); W.tick(0.1, 2)
SECRET = true; played = 0
CDS[2001] = { s = W.now, d = 3.125 }
local secretS, secretD = CDS[2001].s, CDS[2001].d
W.fire("SPELL_UPDATE_COOLDOWN"); W.tick(1 / 60, 2)
reset()
W.tick(0.1, 28)
local whileRuns = n[CD] or 0
local firedAt
for _ = 1, 10 do if played == 0 then W.tick(0.05, 1); if played > 0 then firedAt = W.now end end end
check("E5 in combat (the cooldown's end hidden) the rule fires within one TICK of the end", played == 1, played)
check("E5 while the hidden cooldown runs, the rule is re-checked at most once per TICK (2.8 s: at most 15 times)", whileRuns >= 5 and whileRuns <= 15, whileRuns)
reset()
W.tick(0.1, 20)
check("[new] E5 once it has fired, nothing is re-checked any more (2 s, nothing changing)", (n[CD] or 0) == 0 and not engineOnUpdate(), tostring(n[CD]))
SECRET = false; W.ClearSecret(secretS); W.ClearSecret(secretD)
W.leaveCombat(); W.tick(0.1, 2)

-- E6 cast within 3 seconds
W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 2001); W.tick(1 / 60, 4)
local rtC = ns.runtime[CAST]
check("E6 'cast within 3 s' is true after the cast", rtC and rtC.active == true)
W.tick(0.1, 31)
check("E6 'cast within 3 s' is false 3 s later with no event", rtC and rtC.active == false, rtC and tostring(rtC.active))

-- E7 a repeat sound
played = 0
gain(1002, 30); W.fire("UNIT_AURA", "player", { addedAuras = { AUR[1002] } }); W.tick(1 / 60, 2)
local p0 = played
W.tick(0.1, 45)
check("E7 a repeat sound plays again every 2 s with no event (4.5 s: 2 more)", p0 == 1 and played == 3, p0 .. " -> " .. played)
AUR[1002] = nil; W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { 0 } }); W.tick(1 / 60, 2)

-- E8 only when mounted
mounted = true; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); W.tick(1 / 60, 2)
check("[new] E8 'Only when mounted': mounting shows the display on the next frame (before: up to 50 ms later)", shown(MOUNT))
mounted = false; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); W.tick(1 / 60, 2)
check("E8 dismounting hides it on the next frame", not shown(MOUNT))

-- E9 a state change re-checks only the loaded rules
W.tick(0.5, 1); reset()
W.fire("PLAYER_STARTED_MOVING"); W.tick(0.06, 2)
local nl = 0
for i = 1, #NL do nl = nl + (n[NL[i]] or 0) end
check("[new] E9 a state change (movement) re-checks the loaded rules and none of the 290 rules that do not load here", nl == 0 and (n[CAST] or 0) >= 1,
  "not loaded re-checked: " .. nl .. ", loaded: " .. tostring(n[CAST]))

-- E10 target debuffs
local hasT = false
UnitExists = (function(UE) return function(u) if u == "target" then return hasT end return UE(u) end end)(UnitExists)
local DEB = {}
C_UnitAuras.GetUnitAuras = function(unit, filter) if unit == "target" and hasT then return DEB end return {} end
hasT = true; W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.06, 2)
DEB[1] = { spellId = 3001, auraInstanceID = 9001, duration = 10, expirationTime = W.now + 10, applications = 1, sourceUnit = "player", isHarmful = true }
W.fire("UNIT_AURA", "target", { addedAuras = DEB }); W.tick(1 / 60, 2)
local rtT = ns.runtime[TGT]
check("[new] E10 a target debuff rule follows UNIT_AURA on the target on the next frame (before: at the next 0.2 s tick)", rtT and rtT.active == true, rtT and tostring(rtT.active))
W.tick(0.1, 1)   -- (round 7, SD-61: a quiet tenth of a second first, as above)
DEB[1] = nil; W.fire("UNIT_AURA", "target", { removedAuraInstanceIDs = { 9001 } }); W.tick(1 / 60, 2)
check("E10 ... and the debuff gone clears it", rtT and rtT.active == false)

-- E11 /xui disable
ns.SetRulesDisabled(true); W.tick(0.1, 2); reset()
W.fire("SPELL_UPDATE_COOLDOWN"); W.fire("UNIT_AURA", "player"); W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.1, 20)
check("E11 /xui disable: nothing re-checked, no OnUpdate, no timer", total() == 0 and not engineOnUpdate() and pendingTimers() == 0,
  total() .. " / " .. tostring(engineOnUpdate()) .. " / " .. pendingTimers())
ns.SetRulesDisabled(false); W.tick(1 / 60, 2)
check("E11 /xui enable: every rule is checked again on the next frame", (n[CD] or 0) >= 1 and (n[BUFF] or 0) >= 1)
ns.Evaluate = E0
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
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    print("FAILS: %d" % (bad + len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
