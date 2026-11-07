# XayaUI_Nameplates 0.1.0: Target colour (docs/plans/NAMEPLATES-PLAN-2026-11-07.md, slice 1) and V14 "off costs nothing".
# Asserts what the player sees: which health bar carries a shown texture of ours, in which colour, anchored to which fill; and what
# exists / runs while the switch is off. Uses its own small stand-in world (frames, textures, nameplates, events, next-frame timers),
# loaded with the addon's real files in .toc order. UnitIsUnit raises if called: the addon must never compare units (the comparison
# can be secret in restricted content). Negative control: on the code before this change (no XayaUI_Nameplates folder) every check
# fails, because the files do not exist.
# Run from the repo root: python3 tests/nameplates_run.py   Needs: pip install lupa.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ADDON = os.path.join(ROOT, "XayaUI_Nameplates")
fails = 0
def check(name, cond, extra=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + ((" :: " + str(extra)) if (extra != "" and not cond) else ""))
    if not cond: fails += 1

WORLD = r'''
W = { frames = {}, textures = {}, timers = {}, prints = {}, pages = {}, commands = {}, compared = 0 }
local function obj(kind, parent)
  local o = { _kind = kind, _parent = parent, _events = {}, _scripts = {}, _shown = true, _points = {} }
  function o:RegisterEvent(e) self._events[e] = true end
  function o:UnregisterEvent(e) self._events[e] = nil end
  function o:UnregisterAllEvents() self._events = {} end
  function o:SetScript(k, f) self._scripts[k] = f end
  function o:Show() self._shown = true end
  function o:Hide() self._shown = false end
  function o:IsShown() return self._shown end
  function o:ClearAllPoints() self._points = {} end
  function o:SetPoint(p, rel, rp, x, y) self._points[#self._points + 1] = { p, rel, rp, x, y } end
  function o:CreateTexture(name, layer, tmpl, sub)
    local t = obj("Texture", self); t._layer, t._sub = layer, sub
    function t:SetColorTexture(r, g, b, a) self._fillc = { r, g, b, a } end
    function t:SetVertexColor(r, g, b, a) self._color = { r, g, b, a or 1 } end
    function t:GetVertexColor() local c = self._color or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
    W.textures[#W.textures + 1] = t
    return t
  end
  return o
end
function CreateFrame(kind, name, parent) local f = obj(kind or "Frame", parent); W.frames[#W.frames + 1] = f; return f end
-- a Blizzard nameplate: base frame -> UnitFrame -> HealthBarsContainer -> healthBar (a status bar with its fill texture)
function W.plate(unit)
  local base = { _unit = unit }
  local bar = obj("StatusBar"); bar._fill = obj("Texture", bar)
  function bar:GetStatusBarTexture() return self._fill end
  base.UnitFrame = { HealthBarsContainer = { healthBar = bar } }
  return base
end
W.plates = {}            -- unit token -> plate frame (what C_NamePlate answers)
C_NamePlate = { GetNamePlateForUnit = function(unit, forbidden)
  if forbidden then error("asked for forbidden plates") end
  return W.plates[unit]
end }
C_Timer = { After = function(s, fn) W.timers[#W.timers + 1] = fn end }
function W.nextFrame() local t = W.timers; W.timers = {}; for _, fn in ipairs(t) do fn() end end
UnitIsUnit = function() W.compared = W.compared + 1; error("UnitIsUnit called") end
C_AddOns = { IsAddOnLoaded = function(n) return W.loaded and W.loaded[n] or false end }
function W.fire(event, ...) for _, f in ipairs(W.frames) do if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end end end
XayaUI_NS = {
  Print = function(s) W.prints[#W.prints + 1] = s end,
  RegisterSettingsPage = function(m, k, b) W.pages[k] = b end,
  RegisterCommand = function(n, fn) W.commands[n] = fn end,
  Provide = function(n, o) W.services = W.services or {}; W.services[n] = o end,
}
-- helpers for the checks
function W.shownOn(plate)       -- the colour of our texture shown on this plate's health bar, or nil
  local bar = plate.UnitFrame.HealthBarsContainer.healthBar
  for _, t in ipairs(W.textures) do if t._parent == bar and t._shown then return t end end
end
function W.nShown() local n = 0; for _, t in ipairs(W.textures) do if t._shown then n = n + 1 end end; return n end
function W.nEvents() local n = 0; for _, f in ipairs(W.frames) do for _ in pairs(f._events) do n = n + 1 end end; return n end
function W.nOnUpdate() local n = 0; for _, f in ipairs(W.frames) do if f._scripts.OnUpdate then n = n + 1 end end; return n end
function W.option(path) local g = W.pages.nameplates(function() end); if path == "switch" then return g.xuiSwitch end; return g.args[path] end
'''

def world(saved="nil", loaded="nil"):
    L = LuaRuntime()
    L.execute(WORLD)
    L.execute("XayaUINameplatesDB = " + saved + "; W.loaded = " + loaded)
    files = [l.strip() for l in open(os.path.join(ADDON, "XayaUI_Nameplates.toc")) if l.strip() and not l.startswith("#")]
    NP = L.eval("{}")
    for f in files:
        chunk = L.eval("function(src, name) return assert(loadstring(src, name)) end")(open(os.path.join(ADDON, f), encoding="utf-8").read(), "@" + f)
        chunk("XayaUI_Nameplates", NP)
    L.execute('W.fire("ADDON_LOADED", "XayaUI_Nameplates")')
    return L, L.eval("W")

def run(L, code): return L.eval("function() " + code + " end")()

TEAL = (0, 128 / 255, 128 / 255)
def color(t):   # what the player sees: the plain colour times the tint
    f, c = t._fillc or {1: 1, 2: 1, 3: 1, 4: 1}, t._color or {1: 1, 2: 1, 3: 1, 4: 1}
    return tuple(f[i] * c[i] for i in (1, 2, 3, 4))
def close(a, b): return all(abs(x - y) < 1e-6 for x, y in zip(a, b))

# A. Switch saved OFF: nothing of Target colour exists or runs ------------------------------------------------------------------
L, W = world("{ targetColor = false }")
run(L, 'W.plates.target = W.plate("nameplate1"); W.plates.nameplate1 = W.plates.target')
check("A1 off at login: no event registered by the addon (the login loader unregistered itself)", W.nEvents() == 0, W.nEvents())
check("A2 off at login: only the loader frame exists; no texture made", len(list(W.frames.values())) == 1 and len(list(W.textures.values())) == 0,
      (len(list(W.frames.values())), len(list(W.textures.values()))))
run(L, 'W.fire("PLAYER_TARGET_CHANGED"); W.fire("NAME_PLATE_UNIT_ADDED", "nameplate1"); W.nextFrame()')
check("A3 off: a target change and a new plate draw nothing and queue nothing", W.nShown() == 0 and len(list(W.timers.values())) == 0)
check("A4 no OnUpdate anywhere", W.nOnUpdate() == 0)

# B. On (the default once the addon is enabled) --------------------------------------------------------------------------------
L, W = world()
check("B0 a fresh install saves Target colour on, colour teal rgb(0,128,128)",
      run(L, "return XayaUINameplatesDB.targetColor") is True and close(tuple(run(L, "local c = XayaUINameplatesDB.color return c[1], c[2], c[3]")), TEAL))
check("B1 on: exactly three events (target changed, plate added, plate removed), no OnUpdate",
      W.nEvents() == 3 and W.nOnUpdate() == 0, W.nEvents())
run(L, 'W.p1 = W.plate("nameplate1"); W.p2 = W.plate("nameplate2"); W.plates.nameplate1 = W.p1; W.plates.nameplate2 = W.p2')
run(L, 'W.plates.target = W.p1; W.fire("PLAYER_TARGET_CHANGED")')
t = run(L, "return W.shownOn(W.p1)")
check("B2 target chosen: its health bar shows our texture in teal, fully opaque", t is not None and close(color(t), TEAL + (1,)), t and color(t))
check("B3 ...anchored to the bar's own fill texture, top-left and bottom-right (follows the fill without reading health)",
      t is not None and run(L, """local t = W.shownOn(W.p1); local f = W.p1.UnitFrame.HealthBarsContainer.healthBar._fill
        return #t._points == 2 and t._points[1][1] == "TOPLEFT" and t._points[1][2] == f and t._points[2][1] == "BOTTOMRIGHT" and t._points[2][2] == f"""))
check("B4 ...drawn over the fill (ARTWORK, sub-level 7) and only on the target", t is not None and t._layer == "ARTWORK" and t._sub == 7 and W.nShown() == 1)
run(L, 'W.plates.target = W.p2; W.fire("PLAYER_TARGET_CHANGED")')
check("B5 target changes: the old plate's colour goes, the new target's comes", run(L, "return W.shownOn(W.p1)") is None and run(L, "return W.shownOn(W.p2)") is not None and W.nShown() == 1)
run(L, 'W.plates.target = nil; W.fire("PLAYER_TARGET_CHANGED")')
check("B6 target cleared: nothing coloured", W.nShown() == 0)

# C. The target's plate appears after the target was chosen; plates are released and re-used --------------------------------
run(L, 'W.p3 = W.plate("nameplate3"); W.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")')   # plate exists but target not set yet
run(L, 'W.plates.target = W.p3; W.plates.nameplate3 = W.p3; W.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")')
check("C1 plate added: handled on the next frame (Blizzard sets the plate up first)", run(L, "return W.shownOn(W.p3)") is None)
run(L, "W.nextFrame()")
check("C2 ...then the target's newly shown plate is coloured", run(L, "return W.shownOn(W.p3)") is not None)
run(L, 'W.fire("NAME_PLATE_UNIT_ADDED", "nameplate1"); W.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")')
check("C3 several plates added in one frame queue one refresh", len(list(W.timers.values())) == 1)
run(L, "W.nextFrame()")
run(L, 'W.fire("NAME_PLATE_UNIT_REMOVED", "nameplate3")')
check("C4 the coloured plate is removed: its colour goes at once (before the frame is re-used for another mob)", W.nShown() == 0)
run(L, 'W.plates.target = nil; W.plates.nameplate3 = nil; W.nextFrame()')
check("C5 ...and stays gone", W.nShown() == 0)

# D. Plates that must not be coloured ------------------------------------------------------------------------------------------
run(L, 'W.me = W.plate("nameplate9"); W.plates.player = W.me; W.plates.target = W.me; W.fire("PLAYER_TARGET_CHANGED")')
check("D1 you target yourself: your own (personal resource) plate is never coloured", W.nShown() == 0)
run(L, 'W.bare = { }; W.plates.target = W.bare; W.fire("PLAYER_TARGET_CHANGED")')
check("D2 a plate without Blizzard's unit frame (another addon replaced it): nothing drawn, no error", W.nShown() == 0)
check("D3 UnitIsUnit was never called (no unit comparison, which can be secret)", run(L, "return W.compared") == 0)

# E. Settings page: colour, Teal, switch off / on -----------------------------------------------------------------------------
run(L, 'W.plates.target = W.p1; W.plates.player = nil; W.fire("PLAYER_TARGET_CHANGED")')
run(L, 'W.option("color").set({}, 1, 0, 1)')
check("E1 a new colour is shown on the target at once", close(color(run(L, "return W.shownOn(W.p1)")), (1, 0, 1, 1)))
run(L, 'W.option("teal").func()')
check("E2 Teal puts teal back", close(color(run(L, "return W.shownOn(W.p1)")), TEAL + (1,)))
run(L, 'W.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")')   # a refresh is queued ...
run(L, 'W.option("switch").set({}, false)')
check("E3 switched off: colour gone, no event registered", W.nShown() == 0 and W.nEvents() == 0, W.nEvents())
run(L, "W.nextFrame()")
check("E4 ...a refresh queued before the switch went off draws nothing", W.nShown() == 0)
check("E5 ...the colour picker is greyed while off", run(L, 'return W.option("color").disabled()') is True)
run(L, 'W.option("switch").set({}, true)')
check("E6 switched back on: the target is coloured again", run(L, "return W.shownOn(W.p1)") is not None and W.nEvents() == 3)

# F. /xui nameplates -----------------------------------------------------------------------------------------------------------
L, W = world(loaded="{ Plater = true }")
run(L, 'W.commands.nameplates("")')
out = " | ".join(list(W.prints.values()))
check("F1 /xui nameplates names Plater when it is loaded (nothing of ours shows then)", "Plater is loaded" in out, out)
check("F2 ...and says target colour is on and what the last refresh found", "target colour on" in out and "no target nameplate" in out, out)

print("nameplates_run: %s" % ("ALL PASS" if fails == 0 else "%d FAIL" % fails))
sys.exit(1 if fails else 0)
