#!/usr/bin/env python3
"""Character Reskin on main without XayaUI Blizzard Reskin (QoL 0.7.54; REQUEST-LOG TRI-4, TRI-8, 2026-11-08).
Xaya: main holds no Blizzard Reskin ("just remove all blizzard reskins for the time being"); her answer for the character window: "The
character reskin component should follow the same logic as improved chat: if no reskin is present, reskin it; otherwise let the current
reskin run and only run the other components".
On the stand-in character window of tests/char_reskin_run.py (copied from it), each case in its own Lua state:
  A XayaUI_Reskin missing, no other skin: the switch is kept in QoL's own settings (characterReskinLook), the look is active and drawn,
    and the features run. (Before 0.7.54 the look half was a throwaway table forced off: the switch could never be turned on.)
  B EllesmereUIBlizzardSkin loaded: the look stays off (Blizzard's art untouched), the features still draw the item level.
  C ElvUI loaded with its character skin switched off (E.private.skins.blizzard.character == false, INFERENCE on ElvUI's names): the look runs.
  D ElvUI loaded and its settings not readable: counts as ElvUI skinning the window (fail safe): the look stays off.
  E XayaUI_Reskin installed but switched off (state "disabled"): unchanged from before, the look stays off.
Every number is a TEST STAND-IN."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"

ADDONS = r'''
-- the game's addon list as core's ns.ModuleState reads it (namespaces.md: GetAddOnInfo -> name, title, notes, loadable, reason, security)
C_AddOns = {
  IsAddOnLoaded = function(n) return LOADED[n] and true or false end,
  GetAddOnInfo = function(n)
    if STATE[n] == "missing" then return nil, nil, nil, false, "MISSING" end
    if STATE[n] == "disabled" then return n, n, "", false, "DISABLED" end
    return n, n, "", true, nil
  end,
}
'''
SETUP = r'''
assert(loadfile(__WORLD__))()
assert(loadfile(__GEOM__))()   -- (QoL 0.7.19) Blizzard's window with rectangles: the enchant labels are laid out from them
-- regions that remember their alpha; font strings that remember their colour
function reg(kind) local r = mk(kind or "Texture"); r.alpha = 1; r.SetAlpha = function(self, a) self.alpha = a end; r.GetAlpha = function(self) return self.alpha end; return r end
function fstr(r, g, b) local f = mk("FS"); f.color = { r, g, b, 1 }; f.GetTextColor = function(self) return self.color[1], self.color[2], self.color[3], self.color[4] end; return f end
-- the character window (Blizzard's region names)
CharacterFrame = mk("Frame")
for _, k in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "Background" }) do CharacterFrame[k] = reg() end
CharacterFrame.Inset = mk("Frame"); CharacterFrame.Inset.Bg = reg(); CharacterFrame.Inset.NineSlice = reg()
CharacterFrame.InsetRight = mk("Frame"); CharacterFrame.InsetRight.Bg = reg(); CharacterFrame.InsetRight.NineSlice = reg()
CharacterFrame.TitleContainer = { TitleText = fstr(1, 0.82, 0) }
CharacterFrame.selectedTab = 1
for i = 1, 3 do local t = mk("Button"); t.TabTextures = { reg(), reg(), reg() }; _G["CharacterFrameTab" .. i] = t end
MODEL = { "CharacterModelFrameBackgroundTopLeft", "CharacterModelFrameBackgroundTopRight", "CharacterModelFrameBackgroundBotLeft",
  "CharacterModelFrameBackgroundBotRight", "CharacterModelFrameBackgroundOverlay", "PaperDollInnerBorderTopLeft", "PaperDollInnerBorderBottom2" }
for _, n in ipairs(MODEL) do _G[n] = reg() end
PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
CharacterStatsPane.ClassBackground = reg()
for _, k in ipairs({ "ItemLevelCategory", "AttributesCategory", "EnhancementsCategory" }) do
  local cat = mk("Frame"); cat.Background = reg(); cat.Title = fstr(1, 1, 1); CharacterStatsPane[k] = cat
end
CharacterStatsPane.ItemLevelFrame = mk("Frame"); CharacterStatsPane.ItemLevelFrame.Background = reg()
STATROWS = {}
local function statRow(striped) local s = mk("Frame"); s.Background = reg(); s.Background.shown = striped; s.Label = fstr(1, 0.82, 0); s.Value = fstr(1, 1, 1); STATROWS[#STATROWS + 1] = s; return s end
statRow(false); statRow(true); statRow(false)
CharacterStatsPane.statsFramePool = { EnumerateActive = function() local i = 0; return function() i = i + 1; return STATROWS[i] end end }
function PaperDollItemSlotButton_Update(btn) end
function PaperDollFrame_UpdateStats() end
function PanelTemplates_SetTab(frame, id) frame.selectedTab = id end
ENCHANTED_TOOLTIP_LINE = "Enchanted: %s"
-- the slot buttons (names from PaperDollFrame.xml; IDs as the game sets them), each with its frame art and bevel
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
-- items: Helm (336, Hero 4/6), Ring (330, Veteran 1/8, enchanted: "Radiant Mastery")
QCOL = { [0] = { 0.6, 0.6, 0.6 }, [2] = { 0.1, 1.0, 0.0 }, [3] = { 0.0, 0.4, 1.0 }, [4] = { 0.6, 0.2, 0.9 }, [5] = { 1.0, 0.5, 0.0 } }
C_Item.GetItemQualityColor = function(q) local c = QCOL[q]; if c then return c[1], c[2], c[3], "x" end end
UPG = { Helm = { trackString = "Hero", currentLevel = 4, maxLevel = 6, maxItemLevel = 346 }, Ring = { trackString = "Veteran", currentLevel = 1, maxLevel = 8, maxItemLevel = 340 } }
C_Item.GetItemUpgradeInfo = function(link) local name = type(link) == "string" and link:match("%[(.-)%]"); return name and UPG[name] end
GetInventoryItemQuality = function(_, slot) if GEAR[slot] then return 4 end end
TIP = { [11] = { { type = 15, leftText = "Enchanted: Radiant Mastery" } } }
C_TooltipInfo.GetInventoryItem = function(_, slot) return { lines = TIP[slot] or {}, repairCost = REPAIR[slot] } end
assert(loadfile(__CP__))("XayaUI_QoL", ns); assert(loadfile(__CT__))("XayaUI_Bonus", ns)   -- (character pane split stage 2: QoL's part, then the Stat Calculator, XayaUI Bonus Features')
assert(loadfile(__RS__))("XayaUI_QoL", ns)
ns.FireReady(); ns.SettingsOpenAllForTests()   -- XayaUI Blizzard Reskin not installed: no "reskin" store is declared   -- (P5) the module addons load after XayaUI (XayaUI Blizzard Reskin on: it keeps the look half): their settings stores open (Modules.lua section 0c)
'''

def run(case_lua, body):
    lua = LuaRuntime()
    code = (case_lua + ADDONS + SETUP + body)
    for k, v in (("__WORLD__", "tests/char_toolkit_world.lua"), ("__GEOM__", "tests/char_pane_geometry.lua"), ("__MOD__", "XayaUI/Modules.lua"),
                 ("__COMPAT__", "XayaUI/Compat.lua"), ("__SM__", "XayaUI_QoL/StatMath.lua"), ("__CM__", "XayaUI_QoL/CharacterModel.lua"),
                 ("__CT__", "XayaUI_Bonus/CharacterToolkit.lua"), ("__CP__", "XayaUI_QoL/CharacterPane.lua"), ("__RS__", "XayaUI_QoL/CharacterReskin.lua")):
        code = code.replace(k, P(v))
    lua.execute(code)
    return lua.eval("n"), lua.eval("fails")

COMMON = r'''
local rc = ns.CharReskin_Cfg()
local Q = ns.Settings("qol")
Q.characterReskin.features = true
'''
total = bad = 0
cases = [
  ('LOADED = {}; STATE = { XayaUI_Reskin = "missing" }', COMMON + r'''
check("A: without XayaUI Blizzard Reskin the settings still open (QoL's half)", rc ~= nil)
rc.enabled = true
check("A: the switch is saved in QoL's own settings (XayaUIQoLDB.characterReskinLook)", type(Q.characterReskinLook) == "table" and Q.characterReskinLook.enabled == true)
check("A: ...and it stays on (before 0.7.54 the look half was forced off on every read)", ns.CharReskin_Cfg().enabled == true)
check("A: no other skin: the look is active", ns.CharReskin_LookActive() == true and ns.CharReskin_OtherSkin() == nil)
ns.CharReskin_Apply()
check("A: ...and drawn: Blizzard's frame art faded", CharacterFrame.NineSlice.alpha == 0, CharacterFrame.NineSlice.alpha)
check("A: the features run too: one item level on the Head slot (336)", CharacterHeadSlot.xuiIlvl and CharacterHeadSlot.xuiIlvl.text == "336")
'''),
  ('LOADED = { EllesmereUIBlizzardSkin = true }; STATE = { XayaUI_Reskin = "missing" }', COMMON + r'''
rc.enabled = true
check("B: EllesmereUIBlizzardSkin loaded: named as the other skin", ns.CharReskin_OtherSkin() == "EllesmereUIBlizzardSkin")
check("B: ...the look stays off although its switch is on", ns.CharReskin_Cfg().enabled == true and ns.CharReskin_LookActive() == false)
check("B: ...the features still run", ns.CharReskin_FeaturesActive() == true)
ns.CharReskin_Apply()
check("B: Blizzard's (the other skin's) frame art untouched", CharacterFrame.NineSlice.alpha == 1, CharacterFrame.NineSlice.alpha)
check("B: ...and the item level still drawn (336)", CharacterHeadSlot.xuiIlvl and CharacterHeadSlot.xuiIlvl.text == "336")
'''),
  ('LOADED = { ElvUI = true }; STATE = { XayaUI_Reskin = "missing" }; ElvUI = { { private = { skins = { blizzard = { enable = true, character = false } } } } }', COMMON + r'''
rc.enabled = true
check("C: ElvUI with its character skin off: no other skin, the look is active", ns.CharReskin_OtherSkin() == nil and ns.CharReskin_LookActive() == true)
'''),
  ('LOADED = { ElvUI = true }; STATE = { XayaUI_Reskin = "missing" }; ElvUI = { {} }', COMMON + r'''
rc.enabled = true
check("D: ElvUI loaded, its settings not readable: counts as ElvUI skinning the window", ns.CharReskin_OtherSkin() == "ElvUI" and ns.CharReskin_LookActive() == false)
check("D: ...the features still run", ns.CharReskin_FeaturesActive() == true)
'''),
  ('LOADED = {}; STATE = { XayaUI_Reskin = "disabled" }', COMMON + r'''
rc.enabled = true
check("E: Blizzard Reskin installed but switched off: the look stays off, as before", ns.CharReskin_Cfg().enabled == false and ns.CharReskin_LookActive() == false)
check("E: ...nothing stored in QoL for it", Q.characterReskinLook == nil)
'''),
]
for case_lua, body in cases:
    n, f = run(case_lua, body)
    total += n; bad += f
print("%d checks, %d failed" % (total, bad))
sys.exit(1 if bad else 0)
