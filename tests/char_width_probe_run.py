"""QoL 0.7.12: /xui stats widthprobe [px | off], the in-game test the plan asks for before the Character Reskin's wider character
window is built (docs/plans/STAT-CALCULATOR-REDESIGN-2026-11-04.md; Xaya's answer: "a wider character viewport"). Stand-in frames shaped
like Blizzard's live 12.1.5 character window (CharacterFrame with an Inset, CharacterModelScene 231 wide, CharacterMainHandSlot at
BOTTOMLEFT 130, 16; PANEL_DEFAULT_WIDTH and the inset offsets as globals, values made up for the test). Checks: it refuses in combat,
with the window closed, and without the Inset; it widens the window, moves the Inset's right edge, widens the model, centres the main
hand slot, calls UpdateUIPanelPositions; it prints blocked-action events while on; "off" restores through the window's own UpdateSize
and stops listening; px is clamped; nothing runs at load.
Run: python3 tests/char_width_probe_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
assert(loadfile(__WORLD__))()
PANEL_DEFAULT_WIDTH, PANEL_INSET_RIGHT_OFFSET, PANEL_INSET_BOTTOM_OFFSET = 338, -2, 4
COMBAT = false
InCombatLockdown = function() return COMBAT end
panelCalls = 0
UpdateUIPanelPositions = function(f) panelCalls = panelCalls + 1 end
CharacterFrame = mk("Frame"); CharacterFrame.w = 338
CharacterFrame.Inset = mk("Frame")
CharacterFrame.UpdateSize = function(self) self.w = 338; self.Inset.pts = { { "BOTTOMRIGHT", self, "BOTTOMLEFT", 336, 4 } }; self.sized = (self.sized or 0) + 1 end
PaperDollFrame = mk("Frame")
CharacterModelScene = mk("Frame"); CharacterModelScene.w = 231
CharacterMainHandSlot = mk("Frame"); CharacterMainHandSlot.pts = { { "BOTTOMLEFT", PaperDollFrame, "BOTTOMLEFT", 130, 16 } }
CharacterMainHandSlot.GetPoint = function(self, i) local p = self.pts[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
local before = #created
assert(loadfile(__PROBE__))("XayaUI_QoL", ns)
check("nothing is created or changed when the file loads", #created == before and CharacterFrame.w == 338 and panelCalls == 0)
local function said(s) for _, l in ipairs(printed) do if l:find(s, 1, true) then return true end end return false end
-- refusals
printed = {}
ns.CharWidthProbe_Run("")
check("the character window closed: it asks to open it, changes nothing", said("open the character window") and CharacterFrame.w == 338)
CharacterFrame.shown, PaperDollFrame.shown = true, true
COMBAT = true; printed = {}
ns.CharWidthProbe_Run("")
check("in combat: refused, nothing changed", said("out of combat") and CharacterFrame.w == 338 and not ns.CharWidthProbe.on)
COMBAT = false
local inset = CharacterFrame.Inset; CharacterFrame.Inset = false; printed = {}
ns.CharWidthProbe_Run("")
check("no Inset (the window is built differently): refused, nothing changed", said("not built the way") and CharacterFrame.w == 338)
CharacterFrame.Inset = inset
-- (QoL 0.7.22) the Character Reskin's wider window is built on this probe; with it on the probe would widen the window twice
ns.CharReskin_WideOn = function() return true end; printed = {}
ns.CharWidthProbe_Run("")
check("the Character Reskin's wider window on: refused, it says where to turn it off, nothing changed", said("wider window is on") and said("Character Pane")
  and CharacterFrame.w == 338 and not ns.CharWidthProbe.on)
ns.CharReskin_WideOn = nil
-- on
printed = {}
ns.CharWidthProbe_Run("100")
check("on: the window is 100 px wider (338 -> 438)", CharacterFrame.w == 438, CharacterFrame.w)
local ip = CharacterFrame.Inset.pts[#CharacterFrame.Inset.pts]
check("  ...the Inset's right edge moves out by 100 (338 - 2 + 100 = 436 from the window's left)", ip and ip[1] == "BOTTOMRIGHT" and ip[3] == "BOTTOMLEFT" and ip[4] == 436 and ip[5] == 4,
  ip and table.concat({ tostring(ip[1]), tostring(ip[3]), tostring(ip[4]), tostring(ip[5]) }, " "))
check("  ...the model 100 px wider (231 -> 331)", CharacterModelScene.w == 331, CharacterModelScene.w)
local mp = CharacterMainHandSlot.pts[1]
check("  ...the main hand slot moves right by half (130 -> 180), same anchor", mp and mp[1] == "BOTTOMLEFT" and mp[4] == 180 and mp[5] == 16, mp and mp[4])
check("  ...the game is asked to place its panels again", panelCalls == 1, panelCalls)
check("  ...it says what it did and what to try", said("100 px wider (338 -> 438)") and said("Fight a training dummy") and said("widthprobe off"))
check("  ...and listens for blocked actions", ns.CharWidthProbe.ev and ns.CharWidthProbe.ev.events.ADDON_ACTION_BLOCKED and ns.CharWidthProbe.ev.events.ADDON_ACTION_FORBIDDEN)
printed = {}
fire("ADDON_ACTION_BLOCKED", "XayaUI_QoL", "UNKNOWN()")
check("a blocked action is printed with its arguments", said("ADDON_ACTION_BLOCKED") and said("XayaUI_QoL") and ns.CharWidthProbe.blocked == 1)
printed = {}
ns.CharWidthProbe_Run("50")
check("a second start while on is refused", said("already running") and CharacterFrame.w == 438)
-- off
printed = {}
ns.CharWidthProbe_Run("off")
check("off: Blizzard's own UpdateSize puts the width and the Inset back", CharacterFrame.sized == 1 and CharacterFrame.w == 338)
check("  ...the model and the main hand slot restored", CharacterModelScene.w == 231 and CharacterMainHandSlot.pts[1][4] == 130)
check("  ...it stops listening and reports the count, asks for a /reload", next(ns.CharWidthProbe.ev.events) == nil and said("1 blocked-action message") and said("/reload"))
printed = {}
ns.CharWidthProbe_Run("off")
check("off again: says it is not running", said("not running"))
-- clamping
ns.CharWidthProbe_Run("9999")
check("px is clamped to 300", CharacterFrame.w == 638, CharacterFrame.w)
ns.CharWidthProbe_Run("off")
ns.CharWidthProbe_Run("5")
check("px is clamped to 40", CharacterFrame.w == 378, CharacterFrame.w)
ns.CharWidthProbe_Run("off")
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
   .replace("__PROBE__", P("XayaUI_QoL/CharacterWidthProbe.lua")))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
