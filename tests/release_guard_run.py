# Stub test for QoL > Release Guard (XayaUI_QoL 0.7.31; REQUEST-LOG #10, #39, #75, #76). Her words (verbatim in the log): "black box over
# the "release" button that says "NO RELEASE" (customizable); also allow cycling through flavor texts (configurable) "BAD MONKEY," "death
# comes for us all," "NOPE," "Disagree," "WTB Rez""; hide as a ghost; load "configurable, by default raid only"; "requires a modifier key to
# allow click-through", the key a "Choice in settings"; the flavour text changes "Each death".
# What it checks is what the player sees: the box over the DEATH window's Release button (Blizzard_StaticPopup_Game/Mainline/
# GameDialogDefs.lua:183; a stand-in dialog with GetButton1 here), its text, where a click lands (the box while it shows and takes the
# mouse; Release when it has stepped aside), hidden as a ghost, not outside a raid by default; V14: nothing made or registered while off.
# Negative control (V1): every check fails on the session branch head before this change (29a2f85: no Release Guard), except "(guard)".
# Run from the repo root: python3 tests/release_guard_run.py   Needs: pip install lupa. Stand-in world: tests/char_world.lua.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"

SETUP = r'''
assert(loadfile(__WORLD__))()
function checkp(name, fn)
  local ok, cond, extra = pcall(fn)
  if not ok then check(name, false, "error: " .. tostring(cond)) else check(name, cond and true or false, extra) end
end
local baseMk = mk
function mk(kind)
  local o = baseMk(kind)
  o.SetFrameStrata = function(self, s) self.strata = s end
  o.SetFrameLevel = function(self, l) self.level = l end
  o.GetFrameLevel = function(self) return self.level or 1 end
  o.EnableMouse = function(self, v) self.mouse = v end
  o.SetAllPoints = function(self, rel) self.allPoints = rel end
  return o
end
-- the game (stand-ins): instance type, ghost state, modifier keys, the DEATH popup with its first button
INST = { true, "raid" }
IsInInstance = function() return INST[1], INST[2] end
GHOST, DEAD = false, true
UnitIsGhost = function() return GHOST end
UnitIsDeadOrGhost = function() return DEAD or GHOST end
KEYS = {}
IsShiftKeyDown = function() return KEYS.SHIFT == true end
IsControlKeyDown = function() return KEYS.CTRL == true end
IsAltKeyDown = function() return KEYS.ALT == true end
released = 0
DIALOG = mk("Frame"); DIALOG.level = 5
BUTTON1 = mk("Button"); BUTTON1.parent = DIALOG
BUTTON1.scripts.OnClick = function() released = released + 1 end   -- (the game's OnButton1 calls RepopMe())
DIALOG.GetButton1 = function() return BUTTON1 end
StaticPopupDialogs = { DEATH = {} }
StaticPopup_FindVisible = function(which) if which == "DEATH" and DIALOG.shown then return DIALOG end end
StaticPopup_Show = function(which) if which == "DEATH" then DIALOG:Show() end; return DIALOG end
hooked = 0
local rawHook = hooksecurefunc
hooksecurefunc = function(a, b, c)
  hooked = hooked + 1
  if type(a) == "string" then local orig = _G[a]; _G[a] = function(...) local r = orig(...); b(...); return r end
  elseif rawHook then rawHook(a, b, c) end
end
__DB__
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
local before = #created
local rg = loadfile(__RG__)   -- (missing on the code before it: every check then fails, the run goes on)
if rg then rg("XayaUI_QoL", ns) end
ns.FireReady(); ns.SettingsOpenAllForTests()   -- (P5) the module addons load after XayaUI: their settings stores open (Modules.lua section 0c)
madeAtLoad = #created - before
-- a death as the game runs it: PLAYER_DEAD, then the DEATH window shows
function die() DEAD, GHOST = true, false; fire("PLAYER_DEAD"); StaticPopup_Show("DEATH") end
function box() return _G.XayaUIReleaseGuard end
-- where a click on the Release button lands: on the box while it shows over the button and takes the mouse, else on the button
function clickRelease()
  local b = box()
  if b and b.shown and b.mouse ~= false and b.allPoints == BUTTON1 then if b.scripts.OnClick then b.scripts.OnClick(b) end; return "box" end
  BUTTON1.scripts.OnClick(BUTTON1); return "release"
end
'''

def world(db):
    return (SETUP.replace("__DB__", db).replace("__WORLD__", P("tests/char_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua"))
            .replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__RG__", P("XayaUI_QoL/ReleaseGuard.lua")))
totals = []

# off at login (V14)
lua = LuaRuntime()
lua.execute(world("CueRulesDB = { releaseGuard = { enabled = false } }"))
lua.execute(r'''
die()
checkp("(guard) V14: off at login: no frame made, nothing hooked, nothing drawn when she dies; the click reaches Release", function()
  return madeAtLoad == 0 and hooked == 0 and box() == nil and clickRelease() == "release" end)
''')
totals.append((lua.eval("n"), lua.eval("fails")))

lua = LuaRuntime()
lua.execute(world("CueRulesDB = { releaseGuard = { enabled = true } }"))
lua.execute(r'''
local c = ns.ReleaseGuard_Cfg and ns.ReleaseGuard_Cfg() or {}
checkp("the defaults: \"NO RELEASE\", her five flavour texts in order, Shift, raids only", function()
  local f = ns.ReleaseGuard_Flavors(c)
  return c.text == "NO RELEASE" and table.concat(f, "|") == "BAD MONKEY|death comes for us all|NOPE|Disagree|WTB Rez" and c.modifier == "SHIFT" and c.load == "raid" end)
die()
local b = box() or mk("Button")
checkp("dead in a raid: a black box over the DEATH window's Release button (its size and place), above the window", function()
  return b and b.shown and b.allPoints == BUTTON1 and b.bg.color and b.bg.color[1] == 0 and b.bg.color[4] == 1 end)
-- (QoL 0.7.39, UI-57: "Release guard doesn't seem to work outside of instances") the game raises the death window to the top of the
-- DIALOG strata when it shows (StaticPopup_OnShow: dialog:Raise()); a box in that strata can end up behind it. The box is one strata up.
checkp("  ...in the strata above the game's dialogs (FULLSCREEN_DIALOG), so the window raising itself cannot cover it (UI-57)", function()
  return b.strata == "FULLSCREEN_DIALOG", b.strata end)
checkp("  ...reading \"NO RELEASE\" with the first flavour text under it (BAD MONKEY)", function() return b.text.text == "NO RELEASE\nBAD MONKEY", b and b.text.text end)
released = 0
checkp("  ...a click there lands on the box: she is not released", function() return clickRelease() == "box" and released == 0 end)
KEYS.SHIFT = true; fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
checkp("  ...holding Shift: the box steps aside and the click reaches Release", function() return not b.shown and clickRelease() == "release" and released == 1 end)
KEYS.SHIFT = false; fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
checkp("  ...letting go: the box is back", function() return b.shown end)
c.modifier = "CTRL"; KEYS.SHIFT = true; fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
checkp("the key is a setting: with Ctrl chosen, Shift no longer lets the click through; Ctrl does", function()
  local stillThere = b.shown
  KEYS.SHIFT = false; KEYS.CTRL = true; fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
  local gone = not b.shown
  KEYS.CTRL = false; fire("MODIFIER_STATE_CHANGED", "LCTRL", 0)
  return stillThere and gone end)
c.modifier = "SHIFT"
GHOST = true; fire("PLAYER_ALIVE")
checkp("released (a ghost): the box hides", function() return box() ~= nil and not b.shown end)
DIALOG:Hide(); GHOST = false; fire("PLAYER_UNGHOST")
die()
checkp("each death: the next flavour text (death comes for us all), then NOPE", function()
  local t1 = b.text.text
  DIALOG:Hide(); fire("PLAYER_UNGHOST"); die()
  return t1 == "NO RELEASE\ndeath comes for us all" and b.text.text == "NO RELEASE\nNOPE", t1 .. " / " .. b.text.text end)
DIALOG:Hide()
checkp("the window closes (she was resurrected): the box hides", function() return box() ~= nil and not b.shown end)
c.text = "STAY DOWN"; c.flavors = "one\ntwo"; c.index = 0
die()
checkp("her own text and flavour list (one per line), from the first again", function() return b.text.text == "STAY DOWN\none", b.text.text end)
DIALOG:Hide(); fire("PLAYER_UNGHOST")
INST = { true, "party" }
die()
checkp("dead in a dungeon, raids only (the default): no box, the click reaches Release", function() return box() ~= nil and not b.shown and clickRelease() == "release" end)
DIALOG:Hide(); c.load = "group"; die()
checkp("  ...set to raids and dungeons: the box shows", function() return b.shown end)
DIALOG:Hide(); INST = { false, "none" }; die()
checkp("  ...outside an instance: no box", function() return not b.shown end)
DIALOG:Hide()
-- (QoL 0.7.39; UI-58, Xaya: "There also should not be an everywhere button")
c.load = "all"; local c2 = ns.ReleaseGuard_Cfg()
checkp("no Everywhere: a saved Everywhere becomes raids only (the default); outside an instance: no box", function()
  die(); local ok = c2.load == "raid" and not b.shown; DIALOG:Hide(); return ok, c2.load end)
INST = { true, "raid" }; die()
-- /xui releaseguard (UI-57): what it did at the last death, to settle the layering in the game
local said = {}
local oldPrint = ns.Print; ns.Print = function(t) said[#said + 1] = tostring(t) end
if ns.RunCommand then pcall(ns.RunCommand, "releaseguard", "") end
ns.Print = oldPrint
checkp("/xui releaseguard: on, where, here, and the last death's outcome (covered) with the box's state", function()
  local t = table.concat(said, " / ")
  return t:find("Release Guard: on", 1, true) ~= nil and t:find("Raids only", 1, true) ~= nil and t:find("last death: covered", 1, true) ~= nil, t end)
DIALOG:Hide()
c.enabled = false; if ns.ReleaseGuard_Apply then ns.ReleaseGuard_Apply() end
local reg = 0
for _, f in ipairs(created) do for _ in pairs(f.events) do reg = reg + 1 end end
checkp("switched off: nothing registered, no box when she dies", function() die(); return box() ~= nil and reg == 0 and not b.shown, reg end)
local pg = ns.BuildReleaseGuardPage and ns.BuildReleaseGuardPage(function() end) or { args = {} }
checkp("its settings page: the row's tick box, the box's text, flavour on / off and the list, the key (Shift / Ctrl / Alt), where (raids / raids and dungeons)", function()
  local a = pg.args
  return pg.xuiSwitch and a.text and a.flavorOn and a.flavors and a.modifier and a.modifier.values.SHIFT == "Shift" and a.modifier.values.CTRL == "Ctrl" and a.modifier.values.ALT == "Alt"
    and a.load and a.load.values.raid and a.load.values.group end)
checkp("  ...Where offers raids only and raids and dungeons, and no Everywhere (UI-58)", function()
  local n = 0; for _ in pairs(pg.args.load.values) do n = n + 1 end
  return pg.args.load.values.all == nil and n == 2 and #pg.args.load.sorting == 2, n end)
''')
totals.append((lua.eval("n"), lua.eval("fails")))
n = sum(t[0] for t in totals); fails = sum(t[1] for t in totals)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
