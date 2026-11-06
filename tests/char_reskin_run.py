# Stub test for QoL > Character Reskin (XayaUI_QoL 0.7.14). Xaya 2026-11-04: "also create a QoL Character Reskin option to toggle on or
# off"; "I want a reskin OF THE CHARACTER MENU AND NOTHING ELSE"; "THIS window needs to look beautiful and CLEAN"; "ilvl colored based on
# ilv tier (track ... AND upgrade tier (color gradient))"; "enchants + gems should show to the side of the character pane".
# Requirements: docs/plans/STAT-CALCULATOR-REQUIREMENTS-2026-11-04.md rows A1-A5, A7. Checks: off by default and untouched while off;
# the window's art faded and ours drawn (region names from Blizzard's live 12.1.5 CharacterFrame.xml / PaperDollFrame.xml /
# SharedUIPanelTemplates.xml); tabs; one item level per slot coloured by track and step; the Character Toolkit's overlays leave theirs
# out; enchant names beside the slots (and "No enchant"); the stat list; every part's own switch; switching off puts everything back;
# the hooks; the error guard; secret values; the settings page.
# Run from the repo root: python3 tests/char_reskin_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua.
# Every number, colour, track and enchant name below is a TEST STAND-IN (no game data).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
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
assert(loadfile(__CT__))("XayaUI_QoL", ns)
assert(loadfile(__RS__))("XayaUI_QoL", ns)
ns.FireReady()
local rc = ns.CharReskin_Cfg()
local tk = ns.CharToolkit_Cfg()
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.002 end
local function col(t, r, g, b) return t and near(t[1], r) and near(t[2], g) and near(t[3], b) end

-- 1. Off by default: Blizzard's window untouched ------------------------------------------------------------------------------
check("off by default (A1: its own switch)", rc.enabled == false and ns.CharReskin_Active() == false)
check("  ...nothing faded while off", CharacterFrame.NineSlice.alpha == 1 and CharacterHeadSlotFrame.alpha == 1 and ns.CharReskinDiag.faded == 0)
check("  ...and no hooks installed while off", #(CharacterFrame.hooks.OnShow or {}) == 0)

-- 2. On: the window (A2) ------------------------------------------------------------------------------------------------------
rc.enabled = true; ns.CharReskin_Apply()
check("on: the frame art, portrait and paper-doll background faded", CharacterFrame.NineSlice.alpha == 0 and CharacterFrame.Bg.alpha == 0
  and CharacterFrame.TopTileStreaks.alpha == 0 and CharacterFrame.PortraitContainer.alpha == 0 and CharacterFrame.Background.alpha == 0)
check("  ...the insets' art too (slots / model area and the stats pane)", CharacterFrame.Inset.Bg.alpha == 0 and CharacterFrame.Inset.NineSlice.alpha == 0
  and CharacterFrame.InsetRight.Bg.alpha == 0 and CharacterFrame.InsetRight.NineSlice.alpha == 0)
check("  ...the model's backgrounds and inner border, and the stats pane's class background", (function()
  for _, n in ipairs(MODEL) do if _G[n].alpha ~= 0 then return false end end; return CharacterStatsPane.ClassBackground.alpha == 0 end)())
check("  ...the title in the theme's title colour", col(CharacterFrame.TitleContainer.TitleText.color, 1, 0.82, 0))
check("  ...tab art faded; the selected tab drawn in the selected colour, the others plain", CharacterFrameTab1.TabTextures[1].alpha == 0
  and CharacterFrameTab1.xuiBg and CharacterFrameTab2.xuiBg and CharacterFrameTab1.xuiBg.color[1] ~= CharacterFrameTab2.xuiBg.color[1])
PanelTemplates_SetTab(CharacterFrame, 2)
check("  ...switching tabs (PanelTemplates_SetTab) moves the selected colour", CharacterFrameTab2.xuiBg.color[1] ~= CharacterFrameTab1.xuiBg.color[1]
  and near(CharacterFrameTab2.xuiBg.color[1], 0.22))
PanelTemplates_SetTab(CharacterFrame, 1)

-- 3. Slots: one item level, track-coloured (A3, A4) ---------------------------------------------------------------------------
check("slots: the slot frame art and bevel faded (A3)", CharacterHeadSlotFrame.alpha == 0 and CharacterHeadSlot.normal.alpha == 0 and CharacterMainHandSlotFrame.alpha == 0)
local hi, ri = CharacterHeadSlot.xuiIlvl, CharacterFinger0Slot.xuiIlvl
check("one item level per slot: Head 336, Ring 330", hi and hi.text == "336" and ri and ri.text == "330", hi and hi.text)
check("  ...Head, Hero step 4 of 6: purple at 82% (55% + 45% x 3/5)", col(hi.color, 0.6 * 0.82, 0.2 * 0.82, 0.9 * 0.82), hi.color and table.concat(hi.color, ","))
check("  ...Ring, Veteran step 1 of 8: green at its dimmest (55%)", col(ri.color, 0.1 * 0.55, 1.0 * 0.55, 0), ri.color and table.concat(ri.color, ","))
check("  ...an empty slot shows none", CharacterNeckSlot.xuiIlvl and CharacterNeckSlot.xuiIlvl.text == "")
check("  ...the track is kept for the hover (Hero 4/6)", CharacterHeadSlot.xuiTrack and CharacterHeadSlot.xuiTrack.track == "Hero" and CharacterHeadSlot.xuiTrack.step == 4)
-- the Character Toolkit's overlays leave their item level (and enchant mark) out while the reskin draws them
tk.enabled, tk.overlays = true, true; ns.CharToolkit_Apply(); ns.CharToolkit_UpdateOverlays()
check("the toolkit's slot overlay leaves out its item level while the reskin draws one (her screenshot had two)",
  ns.CharToolkit_OverlayText("HeadSlot") ~= nil and not tostring(ns.CharToolkit_OverlayText("HeadSlot")):find("336", 1, true), tostring(ns.CharToolkit_OverlayText("HeadSlot")))

-- 4. Enchants beside the slots (A5) -------------------------------------------------------------------------------------------
local re, he = CharacterFinger0Slot.xuiEnchant, CharacterHeadSlot.xuiEnchant
check("the ring's enchant by name, from its tooltip line, without 'Enchanted: ' (green)", re and re.text == "Radiant Mastery" and col(re.color, 0.5, 1, 0.5), re and re.text)
check("  ...the helm: 'No enchant' in orange (the head takes one this expansion)", he and he.text == "No enchant" and col(he.color, 1, 0.56, 0.25), he and he.text)
-- (QoL 0.7.22) the first row of the slot's block, 6 px from the slot (the sockets are rows of the block now); every position check is
-- in tests/char_pane_overlays_run.py
local hr, rr, hs, rs = RECT(he), RECT(re), RECT(CharacterHeadSlot), RECT(CharacterFinger0Slot)
check("  ...left-column slots: to the right of the slot (6 px)", hr and math.abs(hr.l - (hs.r + 6)) < 0.01, rstr(hr))
check("  ...right-column slots: to the left of the slot (6 px)", rr and math.abs(rr.r - (rs.l - 6)) < 0.01, rstr(rr))
check("  ...the toolkit's overlay leaves its enchant mark out too (one per slot)", not tostring(ns.CharToolkit_OverlayText("HeadSlot") or ""):find("E%?"),
  tostring(ns.CharToolkit_OverlayText("HeadSlot")))
local savedLine = ENCHANTED_TOOLTIP_LINE; ENCHANTED_TOOLTIP_LINE = nil
check("CM.SlotEnchant without the game's prefix string: the whole line", CM.SlotEnchant(11) == "Enchanted: Radiant Mastery", CM.SlotEnchant(11))
ENCHANTED_TOOLTIP_LINE = savedLine

-- 5. The stat list (A7) -------------------------------------------------------------------------------------------------------
check("stat list: header art faded, titles in the theme's label colour, a thin rule under each", CharacterStatsPane.AttributesCategory.Background.alpha == 0
  and col(CharacterStatsPane.AttributesCategory.Title.color, 1, 0.82, 0) and CharacterStatsPane.AttributesCategory.xuiRule ~= nil)
check("  ...row art faded; our faint stripe only where Blizzard showed its own (every other row)", STATROWS[1].Background.alpha == 0
  and STATROWS[2].xuiStripe.shown == true and STATROWS[1].xuiStripe.shown == false)
check("  ...labels muted, values in the text colour", col(STATROWS[1].Label.color, 0.75, 0.75, 0.8) and col(STATROWS[1].Value.color, 0.96, 0.96, 0.98))
statRow(true)
PaperDollFrame_UpdateStats()
check("  ...a row Blizzard adds later is styled when it updates the stats (hook)", STATROWS[4].Background.alpha == 0 and STATROWS[4].xuiStripe and STATROWS[4].xuiStripe.shown == true)

-- 6. Hooks keep it current ----------------------------------------------------------------------------------------------------
ITEMS.Helm.ilvl = 340
PaperDollItemSlotButton_Update(CharacterHeadSlot)
check("a slot Blizzard updates (an item swapped) gets its new item level (hook)", CharacterHeadSlot.xuiIlvl.text == "340", CharacterHeadSlot.xuiIlvl.text)
ITEMS.Helm.ilvl = 336

-- 7. Each part has its own switch; off puts everything back -------------------------------------------------------------------
rc.chrome = false; ns.CharReskin_Apply()
check("'Clean window' off: Blizzard's art back, the item levels stay", CharacterFrame.NineSlice.alpha == 1 and CharacterHeadSlotFrame.alpha == 1
  and CharacterHeadSlot.xuiIlvl.shown and CharacterHeadSlot.xuiIlvl.text == "336")
rc.chrome = true; rc.ilvl = false; ns.CharReskin_Apply(); ns.CharToolkit_UpdateOverlays()
check("'Item level' off: ours hidden, the toolkit overlay's item level back", not CharacterHeadSlot.xuiIlvl.shown and tostring(ns.CharToolkit_OverlayText("HeadSlot")):find("336", 1, true) ~= nil,
  tostring(ns.CharToolkit_OverlayText("HeadSlot")))
rc.ilvl = true; rc.stats = false; ns.CharReskin_Apply()
check("'Stat list' off: the row art and colours back", STATROWS[1].Background.alpha == 1 and col(STATROWS[1].Label.color, 1, 0.82, 0) and not STATROWS[2].xuiStripe.shown)
rc.stats = true; rc.enabled = false; ns.CharReskin_Apply()
check("switched off: every faded region back to its alpha", CharacterFrame.NineSlice.alpha == 1 and CharacterFrame.Inset.Bg.alpha == 1 and _G[MODEL[1]].alpha == 1
  and CharacterHeadSlotFrame.alpha == 1 and CharacterHeadSlot.normal.alpha == 1 and CharacterFrameTab1.TabTextures[1].alpha == 1 and ns.CharReskinDiag.faded == 0)
check("  ...every recoloured text back to its colour", col(CharacterFrame.TitleContainer.TitleText.color, 1, 0.82, 0) and col(CharacterStatsPane.AttributesCategory.Title.color, 1, 1, 1))
check("  ...our pieces hidden", not CharacterHeadSlot.xuiIlvl.shown and not CharacterFinger0Slot.xuiEnchant.shown and not CharacterFrameTab1.xuiBg.shown)
PaperDollItemSlotButton_Update(CharacterHeadSlot); PaperDollFrame_UpdateStats()
check("  ...and the hooks do nothing while off", CharacterHeadSlotFrame.alpha == 1 and STATROWS[1].Background.alpha == 1)
rc.enabled = true; ns.CharReskin_Apply()
CharacterFrame:Show()
check("on again: the window reskinned when it opens", CharacterFrame.NineSlice.alpha == 0 and CharacterHeadSlot.xuiIlvl.shown)

-- 8. Track colours (CM.TrackColor) ---------------------------------------------------------------------------------------------
UPG.Helm = { trackString = "Myth", currentLevel = 6, maxLevel = 6 }
check("Myth at its last step: full orange", col((CM.TrackColor(GEAR[1], 4)), 1.0, 0.5, 0.0))
UPG.Helm = { trackString = "Gilded", currentLevel = 2, maxLevel = 4 }
check("a track name it does not know: the item's quality colour (nothing guessed)", col((CM.TrackColor(GEAR[1], 4)), 0.6, 0.2, 0.9))
UPG.Helm = nil
check("no upgrade track: the quality colour", col((CM.TrackColor(GEAR[1], 4)), 0.6, 0.2, 0.9) and select(2, CM.TrackColor(GEAR[1], 4)) == nil)
UPG.Helm = { trackString = "Hero", currentLevel = 4, maxLevel = 6 }

-- 9. Secret values and the error guard ----------------------------------------------------------------------------------------
issecretvalue = function(v) return v == "SECRET" end
local savedU = C_Item.GetItemUpgradeInfo
C_Item.GetItemUpgradeInfo = function() return { trackString = "SECRET", currentLevel = "SECRET", maxLevel = 6 } end
local okS = pcall(ns.CharReskin_Apply)
check("secret upgrade info (in combat): no error, the quality colour instead", okS and col(CharacterHeadSlot.xuiIlvl.color, 0.6, 0.2, 0.9) and not ns.CharReskinDiag.failed,
  CharacterHeadSlot.xuiIlvl.color and table.concat(CharacterHeadSlot.xuiIlvl.color, ","))
C_Item.GetItemUpgradeInfo = savedU; issecretvalue = function() return false end
local savedSI = CM.SlotInfo
CM.SlotInfo = function() error("boom") end
printed = {}
ns.CharReskin_Apply()
check("an error while applying turns the reskin off for the session and gives Blizzard's look back", ns.CharReskinDiag.failed == true
  and CharacterFrame.NineSlice.alpha == 1 and not CharacterHeadSlot.xuiIlvl.shown and ns.CharReskin_Active() == false)
check("  ...and says so once in chat", #printed == 1 and printed[1]:find("Character Reskin hit an error", 1, true) ~= nil, printed[1])
CM.SlotInfo = savedSI
ns.CharToolkit_UpdateOverlays()
check("  ...after it the reskin no longer claims the slots: the toolkit's overlays draw their own item level again", ns.CharReskin_DrawsIlvl() == false
  and tostring(ns.CharToolkit_OverlayText("HeadSlot")):find("336", 1, true) ~= nil, tostring(ns.CharToolkit_OverlayText("HeadSlot")))

-- 10. Settings page and /xui reskin --------------------------------------------------------------------------------------------
local page = ns.BuildCharReskinPage(function() end)
check("settings: Blizzard UI Reskin > Character Pane with its switch and one per part", page.name == "Character Pane" and page.args.enabled and page.args.chrome
  and page.args.ilvl and page.args.enchants and page.args.stats)
check("  ...the parts are greyed out while it is off", (function() rc.enabled = false; local d = page.args.ilvl.disabled(); rc.enabled = true; return d end)() == true)
-- (QoL 0.7.22) the wider window is built: its switch, its extra width (120 - 300, greyed out while it is off) and the background opacity
check("  ...the wider window has its switch (on by default), its extra width (0-300 px in 1 px steps, default 42: 380 / 582) and the background opacity (50-100%, default 95%)",
  page.args.wide and page.args.wide.name:find("Wider window", 1, true) and page.args.widePx.min == 0 and page.args.widePx.max == 300
  and ns.CHARRESKIN_DEFAULTS.wide == true and ns.CHARRESKIN_DEFAULTS.widePx == 42 and page.args.widePx.step == 1 and page.args.bgAlpha.min == 0.5 and ns.CHARRESKIN_DEFAULTS.bgAlpha == 0.95
  and (function() rc.wide = false; local d = page.args.widePx.disabled(); rc.wide = true; return d end)() == true and page.args.width == nil)
CueRulesDB.characterReskin.widePx, CueRulesDB.characterReskin.bgAlpha = 5000, 0.1
local cl = ns.CharReskin_Cfg()
check("  ...a saved value out of range is brought back inside it (300 px, 50%)", cl.widePx == 300 and cl.bgAlpha == 0.5, cl.widePx .. " " .. cl.bgAlpha)
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__GEOM__", P("tests/char_pane_geometry.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
   .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua"))
   .replace("__RS__", P("XayaUI_QoL/CharacterReskin.lua")))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
