#!/usr/bin/env python3
"""Character pane split (docs/plans/PLATFORM-SPLIT-2026-11-07.md section 4.2; Xaya's Q5 answer, PS-53, PS-54).

Stage 1 (QoL 0.7.53; fixes C20, the P5 side effect): the character window's features (item level, enchant and gem blocks, the full
stat list) are QoL's and run whether or not the Character Pane reskin (XayaUI Blizzard Reskin) is on; the reskin only changes the look.
What the player sees, on the stand-in character window (tests/char_toolkit_world.lua, tests/char_pane_geometry.lua):
  S1a  a P5 install whose reskin was on, XayaUI Blizzard Reskin switched off in the AddOns list: the item levels, the ring's enchant
       and the full stat list show; Blizzard's art is untouched (no look). Fails on f870d78 (nothing drawn).
  S1b  XayaUI Blizzard Reskin on, its tab switch (Blizzard Reskin > Overview) off: the same.
  S1c  the reskin on, QoL's Character Pane switch off: only the look changes (art faded, theme colours); no item level, enchant, gem or
       stat list of ours. Fails on f870d78 (the item levels show).
  S1d  a fresh install with XayaUI Blizzard Reskin off: nothing is made, hooked or registered (V14); the switch reads off.
  S1e  the same install, QoL > Character Pane ticked: the features show at once (no reload: a feature toggle inside QoL).
  S1f  profiles: with every default the saved characterReskin has no new key (a profile string is unchanged); the switch is saved
       once on.
Negative control: XUI_ROOT=<checkout of f870d78> python3 tests/char_pane_split_run.py fails S1a, S1b, S1c, S1e.
Every number, item and enchant below is a TEST STAND-IN.
Run from the repo root: python3 tests/char_pane_split_run.py   Needs: pip install lupa."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("XUI_ROOT") or os.path.join(HERE, "..")


def P(rel, root=None):
    return "'" + os.path.join(root or ROOT, rel).replace("\\", "/") + "'"


def first(*rels):
    """The first of these files that exists in ROOT (a file moved between stages)."""
    for r in rels:
        if os.path.isfile(os.path.join(ROOT, r)):
            return P(r)
    return P(rels[0])


PRELUDE = r'''
assert(loadfile(__WORLD__))()
assert(loadfile(__GEOM__))()
function checkp(name, fn)
  local ok, cond, extra = pcall(fn)
  if not ok then check(name, false, "error: " .. tostring(cond)) else check(name, cond and true or false, extra) end
end
function reg(kind) local r = mk(kind or "Texture"); r.alpha = 1; r.SetAlpha = function(self, a) self.alpha = a end; r.GetAlpha = function(self) return self.alpha end; return r end
function fstr(r, g, b) local f = mk("FS"); f.color = { r, g, b, 1 }; f.GetTextColor = function(self) return self.color[1], self.color[2], self.color[3], self.color[4] end; return f end
CharacterFrame = mk("Frame")
for _, k in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "Background" }) do CharacterFrame[k] = reg() end
CharacterFrame.Inset = mk("Frame"); CharacterFrame.Inset.Bg = reg(); CharacterFrame.Inset.NineSlice = reg()
CharacterFrame.InsetRight = mk("Frame"); CharacterFrame.InsetRight.Bg = reg(); CharacterFrame.InsetRight.NineSlice = reg()
CharacterFrame.TitleContainer = { TitleText = fstr(1, 0.82, 0) }
CharacterFrame.selectedTab = 1
for i = 1, 3 do local t = mk("Button"); t.TabTextures = { reg(), reg(), reg() }; _G["CharacterFrameTab" .. i] = t end
PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
CharacterStatsPane.ClassBackground = reg()
for _, k in ipairs({ "ItemLevelCategory", "AttributesCategory", "EnhancementsCategory" }) do
  local cat = mk("Frame"); cat.Background = reg(); cat.Title = fstr(1, 1, 1); CharacterStatsPane[k] = cat
end
CharacterStatsPane.ItemLevelFrame = mk("Frame"); CharacterStatsPane.ItemLevelFrame.Background = reg()
CharacterStatsPane.statsFramePool = { EnumerateActive = function() return function() return nil end end }
CharacterStatsPane.shown = true
HOOKED = {}
function PaperDollItemSlotButton_Update(btn) end
function PaperDollFrame_UpdateStats() end
function PanelTemplates_SetTab(frame, id) frame.selectedTab = id end
local rawHook = hooksecurefunc
hooksecurefunc = function(a, b, c) HOOKED[#HOOKED + 1] = type(a) == "string" and a or b; if rawHook then return rawHook(a, b, c) end
  local name, fn = a, b; local old = _G[name]; _G[name] = function(...) local r = { old(...) }; fn(...); return unpack(r) end end
ENCHANTED_TOOLTIP_LINE = "Enchanted: %s"
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
local CM = ns.CharModel
for _, s in ipairs(CM.SLOTS) do
  local b = mk("ItemButton"); b.id = s[1]; local nt = reg(); b.GetNormalTexture = function() return nt end; b.normal = nt
  _G["Character" .. s[4]] = b; _G["Character" .. s[4] .. "Frame"] = reg()
end
placePane()
QCOL = { [4] = { 0.6, 0.2, 0.9 } }
C_Item.GetItemQualityColor = function(q) local c = QCOL[q]; if c then return c[1], c[2], c[3], "x" end end
UPG = { Helm = { trackString = "Hero", currentLevel = 4, maxLevel = 6, maxItemLevel = 346 }, Ring = { trackString = "Veteran", currentLevel = 1, maxLevel = 8, maxItemLevel = 340 } }
C_Item.GetItemUpgradeInfo = function(link) local name = type(link) == "string" and link:match("%[(.-)%]"); return name and UPG[name] end
GetInventoryItemQuality = function(_, slot) if GEAR[slot] then return 4 end end
TIP = { [11] = { { type = 15, leftText = "Enchanted: Radiant Mastery" } } }
C_TooltipInfo.GetInventoryItem = function(_, slot) return { lines = TIP[slot] or {}, repairCost = REPAIR[slot] } end
C_Timer.After = function(d, fn) fn() end
-- the saved variables as the game sets them before the addons' ADDON_LOADED (set by each case below)
__SAVED__
for _, f in ipairs({ __QOLFILES__ }) do assert(loadfile(f))("XayaUI_QoL", ns) end
ns.FireReady()
__RESKIN_ON__
ns.SettingsOpenAllForTests()
ns.FireLogin()
function looked() return CharacterFrame.NineSlice.alpha == 0 end
function ilvlShown(name) local b = _G["Character" .. name]; return b.xuiIlvl ~= nil and b.xuiIlvl.shown == true and b.xuiIlvl.text or nil end
function enchShown(name) local b = _G["Character" .. name]; return b.xuiEnchant ~= nil and b.xuiEnchant.shown == true and b.xuiEnchant.text or nil end
function listShown() local L = ns.CharReskinParts and ns.CharReskinParts.statList; return L ~= nil and L:IsShown() end
function openWindow() CharacterFrame:Show(); PaperDollFrame:Show(); for _, s in ipairs(CM.SLOTS) do PaperDollItemSlotButton_Update(_G["Character" .. s[4]]) end; PaperDollFrame_UpdateStats() end
'''

def lua_with(saved, reskin_on, body):
    # the QoL files of the character pane that exist in ROOT (stage 2 splits CharacterToolkit.lua; its QoL part is CharacterPane.lua)
    qol = ", ".join(P(r) for r in ("XayaUI_QoL/CharacterToolkit.lua", "XayaUI_QoL/CharacterPane.lua", "XayaUI_QoL/CharacterReskin.lua")
                    if os.path.isfile(os.path.join(ROOT, r)))
    src = (PRELUDE.replace("__WORLD__", P("tests/char_toolkit_world.lua", HERE + "/..")).replace("__GEOM__", P("tests/char_pane_geometry.lua", HERE + "/.."))
           .replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
           .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/CharacterModel.lua"))
           .replace("__QOLFILES__", qol).replace("__SAVED__", saved)
           .replace("__RESKIN_ON__", 'ns.SettingsDeclareStore("reskin", "XayaUI_Reskin", "XayaUIReskinDB")' if reskin_on else "-- (XayaUI Blizzard Reskin switched off: its store is never declared or opened)"))
    lua = LuaRuntime()
    lua.execute(src)
    lua.execute(body)
    return lua.eval("n"), lua.eval("fails")


totals = []

# S1a: a P5 install whose reskin was on; XayaUI Blizzard Reskin switched off in the AddOns list ---------------------------------------
totals.append(lua_with(r'''
CueRulesDB = { characterReskin = { enabled = true, chrome = true, ilvl = true, enchants = true, gems = true, statList = true, stats = true } }
XayaUIQoLDB = { storeVersion = 1, migratedFrom = "CueRulesDB", characterReskin = { ilvl = true, enchants = true, gems = true, statList = true } }
''', False, r'''
openWindow()
checkp("S1a XayaUI Blizzard Reskin off (the reskin was on): the item level shows on each slot (Head 336, Ring 330)", function()
  return ilvlShown("HeadSlot") == "336" and ilvlShown("Finger0Slot") == "330", tostring(ilvlShown("HeadSlot")) end)
checkp("  ...the ring's enchant beside it (Radiant Mastery)", function() return enchShown("Finger0Slot") == "Radiant Mastery", tostring(enchShown("Finger0Slot")) end)
checkp("  ...the full stat list in the stats pane", function() return listShown() end)
checkp("  ...and Blizzard's look is untouched (no reskin: art not faded, title colour unchanged)", function()
  return not looked() and CharacterFrame.TitleContainer.TitleText.color[1] == 1 and CharacterHeadSlotFrame.alpha == 1 end)
checkp("  ...QoL > Character Pane reads on (its first value: the reskin's switch as saved, from the copy CueRulesDB kept)", function()
  local pg = ns.BuildCharPanePage and ns.BuildCharPanePage(function() end)
  return pg and pg.xuiSwitch.get() == true and XayaUIQoLDB.characterReskin.features == true end)
'''))

# S1b: XayaUI Blizzard Reskin on, its tab switch off ---------------------------------------------------------------------------------
totals.append(lua_with(r'''
CueRulesDB = { reskinTabOff = true }
XayaUIQoLDB = { storeVersion = 1, characterReskin = { ilvl = true, enchants = true, gems = true, statList = true } }
XayaUIReskinDB = { storeVersion = 1, characterReskin = { enabled = true, chrome = true, stats = true } }
''', True, r'''
openWindow()
checkp("S1b Blizzard Reskin's tab switch off (the reskin on): the item levels and the enchant show", function()
  return ilvlShown("HeadSlot") == "336" and enchShown("Finger0Slot") == "Radiant Mastery", tostring(ilvlShown("HeadSlot")) end)
checkp("  ...the full stat list too", function() return listShown() end)
checkp("  ...no look", function() return not looked() and (ns.CharReskin_LookActive == nil or ns.CharReskin_LookActive() == false) end)
'''))

# S1c: the reskin on, QoL's Character Pane off -----------------------------------------------------------------------------------------
totals.append(lua_with(r'''
CueRulesDB = {}
XayaUIQoLDB = { storeVersion = 1, characterReskin = { features = false, ilvl = true, enchants = true, gems = true, statList = true } }
XayaUIReskinDB = { storeVersion = 1, characterReskin = { enabled = true, chrome = true, stats = true } }
''', True, r'''
openWindow()
checkp("S1c the reskin on, QoL's Character Pane off: the look changes (Blizzard's art faded, the slot art faded)", function()
  return looked() and CharacterHeadSlotFrame.alpha == 0 and CharacterFrame.Inset.Bg.alpha == 0 end)
checkp("  ...and only the look: no item level, enchant or gem of ours on any slot", function()
  local n = 0
  for _, s in ipairs(ns.CharModel.SLOTS) do
    local b = _G["Character" .. s[4]]
    if ilvlShown(s[4]) or enchShown(s[4]) then n = n + 1 end
    for _, f in ipairs(b.xuiSockets or {}) do if f.shown then n = n + 1 end end
  end
  return n == 0, n end)
checkp("  ...no stat list of ours (Blizzard's own stays)", function() return not listShown() end)
checkp("  ...the toolkit's overlays are told nothing is drawn (they may draw their own)", function()
  return ns.CharReskin_DrawsIlvl() == false and ns.CharReskin_DrawsEnchants() == false and ns.CharReskin_DrawsSockets() == false end)
'''))

# S1d / S1e: a fresh install, XayaUI Blizzard Reskin off ---------------------------------------------------------------------------
totals.append(lua_with(r'''
CueRulesDB = {}
''', False, r'''
openWindow()
checkp("S1d fresh install, Blizzard Reskin off: nothing drawn (QoL's Character Pane is off by default)", function()
  return ilvlShown("HeadSlot") == nil and enchShown("Finger0Slot") == nil and not listShown() and not looked() end)
checkp("  ...V14: no hook, no OnShow handler on the window, nothing registered", function()
  local h = 0; for _, n in ipairs(HOOKED) do if n == "PaperDollItemSlotButton_Update" or n == "PaperDollFrame_UpdateStats" then h = h + 1 end end
  return h == 0 and #(CharacterFrame.hooks.OnShow or {}) == 0 and ns.CharReskin_Active() == false, h end)
checkp("  ...the switch reads off and nothing new is saved", function()
  local pg = ns.BuildCharPanePage and ns.BuildCharPanePage(function() end)
  return pg and pg.xuiSwitch.get() == false and (XayaUIQoLDB.characterReskin or {}).features == nil end)
checkp("S1e QoL > Character Pane ticked: the item levels, the enchant and the stat list show at once", function()
  local pg = ns.BuildCharPanePage(function() end)
  pg.xuiSwitch.set({}, true)
  openWindow()
  return ilvlShown("HeadSlot") == "336" and enchShown("Finger0Slot") == "Radiant Mastery" and listShown() and not looked(), tostring(ilvlShown("HeadSlot")) end)
checkp("  ...unticked: they go", function()
  ns.BuildCharPanePage(function() end).xuiSwitch.set({}, false)
  return ilvlShown("HeadSlot") == nil and enchShown("Finger0Slot") == nil and not listShown() end)
'''))

# S1f: profiles ---------------------------------------------------------------------------------------------------------------------
totals.append(lua_with(r'''
CueRulesDB = {}
''', True, r'''
openWindow(); ns.CharReskin_Cfg()
checkp("S1f every default: the characterReskin a profile saves has no new key (the string is unchanged)", function()
  local v = ns.SettingsLegacyGet("characterReskin")
  return type(v) == "table" and v.features == nil and v.enabled == false and v.ilvl == true end)
checkp("  ...the reskin on: the switch is saved on (true) the first time it is read", function()
  ns.Settings("reskin").characterReskin.enabled = true; ns.CharReskin_Apply()
  return ns.SettingsLegacyGet("characterReskin").features == true end)
'''))

n = sum(t[0] for t in totals); fails = sum(t[1] for t in totals)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
