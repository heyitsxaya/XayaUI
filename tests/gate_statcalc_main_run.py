#!/usr/bin/env python3
"""V27 release gate for XayaUI Bonus Features on main (Bonus 0.6.45: the Stat Calculator, REQUEST-LOG A24 #10 / #11).
Xaya, V27 (REQUEST-LOG A23 SD-28 / SD-29, her words): "Conditions every single build on main has to pass: * nothing impacts mouse
ability to interact with ... in-game objects, buttons, or screen panning once xui options window is closed * nothing impacts keyboard
ability to interact with the game once xui options window is closed ... * zero code loops, zero unnecessary complex calculations, zero
floating numbers ... and no runaway functions." Her readings: loops "No running loops"; numbers "Whole-pixel / no float math"; mouse
"Hover only, clicks pass". Main had no gate test for an addon other than core, Options and Rules; this one covers XayaUI_Bonus.
The keyboard part is covered for every XayaUI file by tests/key_propagation_run.py and tests/key_review_run.py (they read every
addon folder, XayaUI_Bonus included) and for the Stat Calculator itself by tests/statcalc_keys_run.py.
  S1  static, every Lua file of XayaUI_Bonus (git ls-files): no OnUpdate script set or hooked, no repeating timer (C_Timer.NewTicker /
      NewTimer), and the only C_Timer.After is the redraw throttle in StatCalculator.lua (one at a time, 0.25 s); no file switches the
      keyboard on or sets the key pass-on flag (only core's KeyCatch.lua may).
  R1  (V14) the Stat Calculator off at login (a fresh install): XayaUI_Bonus made no frame, registered no event, placed no hook and
      started no timer; nothing of it is shown.
  R2  on, panel closed, character window closed: during 10 s of idle frames no XayaUI_Bonus frame has an OnUpdate script, no timer is
      started, and its event frame listens only to the start and end of combat and to spec / level changes.
  R3  the panel open on its own: 10 s of idle frames start no timer and run no OnUpdate (nothing polls); the panel's size and its
      position offsets are whole pixels, and so is the saved place after a drag.
  R4  in combat (V26): the panel is hidden, so it takes no click; the event frame listens to PLAYER_REGEN_ENABLED only; 10 s of combat
      frames start no timer. After combat it comes back.
  R5  closed (its close button, or the Stat Calculator switched off): the panel is hidden, so it takes no click (mouse passes to the
      game) and no event but combat start / end and spec / level remains (none at all when switched off).
Negative control (2026-11-12): with an OnUpdate script and a C_Timer.NewTicker added to the panel's build in StatCalculator.lua, 5 of
23 fail (S1 twice, R3, R4, R5: the OnUpdate is seen in each idle window).
The harness is a stand-in for the game (tests/harness): in-game cost, taint and mouse behavior are UNVERIFIED IN GAME
(docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md section H).
Run: python3 tests/gate_statcalc_main_run.py   (Lua 5.1 via lupa)"""
import os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[" .. MODE .. "] " .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- meters: anything made while a XayaUI_Bonus file is on the call stack is the Stat Calculator's (core helpers it calls included)
-- the innermost XayaUI file on the call stack is a XayaUI_Bonus file, or a core helper (FlatButton, KeyFocusGuard, ...) that a XayaUI_Bonus
-- file called directly (the next XayaUI file up is XayaUI_Bonus's)
local function fromBonus()
  local seen = 0
  for lv = 3, 60 do
    local info = debug.getinfo(lv, "S")
    if not info then break end
    local f = (info.source or ""):match("Interface/AddOns/(XayaUI[%w_]*)/")
    if f then
      seen = seen + 1
      if f == "XayaUI_Bonus" then return true end
      if seen >= 2 or f ~= "XayaUI" then return false end
    end
  end
  return false
end
local hooks, timers = 0, 0
local rawCreate = CreateFrame
CreateFrame = function(...) local f = rawCreate(...); if fromBonus() then rawset(f, "_bonus", true) end; return f end
local rawHook = hooksecurefunc
hooksecurefunc = function(a, b, c) if fromBonus() then hooks = hooks + 1 end; return rawHook(a, b, c) end
for _, k in ipairs({ "After", "NewTimer", "NewTicker" }) do
  local raw = C_Timer[k]
  C_Timer[k] = function(...) if fromBonus() then timers = timers + 1 end; return raw(...) end
end
local function mine() local t = {}; for _, o in ipairs(W.objects) do if rawget(o, "_bonus") then t[#t + 1] = o end end; return t end
local function events()
  local set, list = {}, {}
  for _, o in ipairs(mine()) do for e in pairs(o._events) do if not set[e] then set[e] = true; list[#list + 1] = e end end end
  table.sort(list)
  return table.concat(list, ","), set
end
local function onupdates() local n = 0; for _, o in ipairs(mine()) do if o._scripts.OnUpdate then n = n + 1 end end; return n end
-- frames of it that could take a click now: shown, visible and mouse-enabled (a bare event frame takes none)
local function shown() local n = 0; for _, o in ipairs(mine()) do if o:IsVisible() and rawget(o, "_mouse") then n = n + 1 end end; return n end
local function whole(v) return type(v) == "number" and v == math.floor(v) end

rawset(_G, "CharacterFrame", CreateFrame("Frame", "CharacterFrame", UIParent)); CharacterFrame:Hide()
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
local sc = ns.Service("statCalc")
check("(sanity) the Stat Calculator's service is there", sc ~= nil)
if not sc then return R end

if MODE == "fresh" then
  -- R1 off at login
  local ev = events()
  check("R1 off at login: XayaUI_Bonus made no frame, registered no event, placed no hook, started no timer",
    #mine() == 0 and ev == "" and hooks == 0 and timers == 0, #mine() .. " frames, events " .. ev .. ", " .. hooks .. " hooks, " .. timers .. " timers")
  W.tick(1 / 60, 600)
  check("R1 ...and 10 s of frames later still nothing of it exists or runs", #mine() == 0 and timers == 0 and onupdates() == 0, #mine())
  return R
end

-- on (as a player who turned it on), panel closed, character window closed
local c = sc.Cfg(); c.enabled, c.panel = true, true; ns.StatCalc_Apply(); W.tick(0.1, 3)
if sc.Shown() then sc.Close() end
W.tick(0.1, 3)
local t0 = timers
W.tick(1 / 60, 600)
local ev, set = events()
check("R2 on, panel closed: 10 s of idle frames start no timer and no XayaUI_Bonus frame has an OnUpdate", timers == t0 and onupdates() == 0, (timers - t0) .. " timers, " .. onupdates() .. " OnUpdate")
check("R2 ...its events are only combat start / end and spec / level changes", ev == "PLAYER_LEVEL_UP,PLAYER_REGEN_DISABLED,PLAYER_REGEN_ENABLED,PLAYER_SPECIALIZATION_CHANGED", ev)
check("R2 ...nothing of it is shown (the mouse reaches the game)", shown() == 0, shown())

-- R3 open on its own
sc.Open("stats"); W.tick(0.1, 5)
local panel = rawget(_G, "XayaUIStatCalculator")
check("R3 setup: the panel is open on its own", panel ~= nil and panel:IsShown())
if not panel then return R end
t0 = timers
local drawn0 = ns.Service("statCalcDebug") and ns.Service("statCalcDebug").Builds() or 0
W.tick(1 / 60, 600)
local drawn1 = ns.Service("statCalcDebug") and ns.Service("statCalcDebug").Builds() or 0
check("R3 open and idle for 10 s: no timer started, no OnUpdate, no stat model built (nothing polls)", timers == t0 and onupdates() == 0 and drawn1 == drawn0,
  (timers - t0) .. " timers, " .. onupdates() .. " OnUpdate, " .. (drawn1 - drawn0) .. " builds")
local w, h = panel:GetWidth(), panel:GetHeight()
local p, rel, rp, x, y = panel:GetPoint(1)
check("R3 the panel's size and its position offsets are whole pixels", whole(w) and whole(h) and whole(x or 0) and whole(y or 0),
  tostring(w) .. "x" .. tostring(h) .. " @ " .. tostring(x) .. "," .. tostring(y))
if panel._scripts.OnDragStart and panel._scripts.OnDragStop then
  panel._scripts.OnDragStart(panel)
  panel:ClearAllPoints(); panel:SetPoint("CENTER", UIParent, "CENTER", 37.4, -12.6)
  panel._scripts.OnDragStop(panel)
end
c = sc.Cfg()
check("R3 the saved place after a drag is whole pixels", type(c.free) == "table" and whole(c.free.x) and whole(c.free.y), c.free and (tostring(c.free.x) .. "," .. tostring(c.free.y)))

-- R4 combat
W.enterCombat(); W.tick(0.1, 2)
ev = events()
check("R4 in combat: the panel is hidden (it takes no click) and only PLAYER_REGEN_ENABLED is listened to", not panel:IsShown() and ev == "PLAYER_REGEN_ENABLED", ev)
t0 = timers
W.tick(1 / 60, 600)
check("R4 ...10 s of combat frames start no timer and run no OnUpdate", timers == t0 and onupdates() == 0, timers - t0)
W.leaveCombat(); W.tick(0.1, 5)
check("R4 after combat it comes back on its own", panel:IsShown())

-- R5 closed and switched off
sc.Close(); W.tick(0.1, 2)
ev = events()
check("R5 closed: hidden (the mouse reaches the game) and only combat start / end, spec and level are listened to", not panel:IsShown() and shown() == 0
  and ev == "PLAYER_LEVEL_UP,PLAYER_REGEN_DISABLED,PLAYER_REGEN_ENABLED,PLAYER_SPECIALIZATION_CHANGED", ev)
c.enabled = false; ns.StatCalc_Apply(); W.tick(0.1, 2)
ev = events()
t0 = timers
W.tick(1 / 60, 600)
check("R5 switched off: nothing shown, no event, no timer, no OnUpdate", shown() == 0 and ev == "" and timers == t0 and onupdates() == 0, ev)
return R
end
'''


def static():
    out = []
    files = subprocess.run(["git", "ls-files", "XayaUI_Bonus"], cwd=ROOT, capture_output=True, text=True).stdout.split()
    lua = [f for f in files if f.endswith(".lua")]
    out.append(("S1 XayaUI_Bonus's Lua files are tracked (%d)" % len(lua), len(lua) > 0))
    onupd, tick, after, keys = [], [], [], []
    for f in lua:
        for i, ln in enumerate(open(os.path.join(ROOT, f), encoding="utf-8").read().split("\n")):
            code = ln.split("--")[0]
            if re.search(r"""["']OnUpdate["']""", code):
                onupd.append("%s:%d" % (f, i + 1))
            if re.search(r"C_Timer\.(NewTicker|NewTimer)", code):
                tick.append("%s:%d" % (f, i + 1))
            if re.search(r"C_Timer\.After", code):
                after.append("%s:%d" % (f, i + 1))
            if re.search(r"SetPropagateKeyboardInput|EnableKeyboard\s*\(", code):
                keys.append("%s:%d" % (f, i + 1))
    out.append(("S1 no OnUpdate script set or hooked in XayaUI_Bonus" + ("" if not onupd else "  [" + ", ".join(onupd) + "]"), not onupd))
    out.append(("S1 no repeating timer (C_Timer.NewTicker / NewTimer)" + ("" if not tick else "  [" + ", ".join(tick) + "]"), not tick))
    out.append(("S1 the only C_Timer.After is the redraw throttle in StatCalculator.lua" + ("" if len(after) == 1 else "  [" + ", ".join(after) + "]"),
                len(after) == 1 and after[0].startswith("XayaUI_Bonus/StatCalculator.lua:")))
    out.append(("S1 no file switches the keyboard on or sets the key pass-on flag (only core's KeyCatch.lua may)" + ("" if not keys else "  [" + ", ".join(keys) + "]"), not keys))
    return out


def session(mode):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)
    out = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    out.append(("[%s] no Lua error in the stand-in game" % mode + ("" if not errs else "  [" + errs[0][:300] + "]"), not errs))
    return out


def main():
    results = static() + session("fresh") + session("on")
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + str(name)[:600])
        bad += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
