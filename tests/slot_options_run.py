#!/usr/bin/env python3
"""Improved Character Display: the slot layout. A24 #7 (one "Item level" option and one "Enchants" option) and A24 #9, Xaya's words:
"Ilvl goes on item block; enchant and gems are both on the outside right border of the icon. Don't remove anything else"; on the Style
select: "I don't know what the style label is, but it sounds unnecessary". Built: no Style select; the item level on the slot's icon;
the enchant, the embellishment and the gems against the OUTSIDE RIGHT edge of the slot's icon, for every slot (built literally;
INFERENCE that she means every column, the right-hand column included; the main hand's block stays left of the weapons, because a block
right of it would cover the off hand's icon). Round 3's style keys (ilvlStyle / enchantStyle) are no longer read; old profiles import.

What the player sees, on the stand-in character window at 540 px (the Character tab with its stats pane; tests/char_world.lua,
tests/char_pane_geometry.lua; Helm 336 in slot 1 with no enchant, Ring 330 in slot 11 enchanted "Radiant Mastery" with one empty
socket; every item and number is a TEST STAND-IN):
  A  QoL > Improved Character Display: "Item level" and "Enchants" tick boxes and no Style dropdown anywhere on the page; everything else
     kept (Gems and sockets, Empty sockets, Text size, Enchant Slots, Full stat list, Stat Calc button); no text names a style or E? / E.
  B  The item level at the bottom of the slot's icon, inside it; the enchant and the gems start right of the slot's icon, 6 px from it,
     in the left column (head) and the right-hand column (ring), left-aligned; no E? / E mark on any slot; no row covers a slot's icon or
     reaches past the window's edge less its gutter; every row starts right of its own slot (but the main hand's); offsets are whole
     pixels. A style key saved in round 3 changes nothing. The empty-socket count, the hovers stay. Item level / Enchants off: none.
     B10: the drawn enchant follows Blizzard's slot redraw. B11: the walkthrough's read counts the rows over the stats pane (the
     right-hand column's: they may take a stat line's hover, UNVERIFIED IN GAME, put to her in the review step).
  C  The one-time move of saved settings: each player keeps what showed (on / off); the move writes no style key.
  D  Profiles: older strings (QoL part format 1 or 2) still import (their slot marks read as on / off); a format-3 string that holds a
     style imports without error and the style changes nothing.
  E  The in-game walkthrough "slot-options" (V22): its verdicts on the stand-in, Xaya's review step (no verdict), the put-back.
     E7: "improved-character-display" step 5 (QAWalks-character-split.lua) asks for Item level and Enchants and passes on what shows.
     E5b: the review step puts each open choice to her (stat hovers, main hand, item level, the removed E? / E, the narrow window).
     E8 (integration): no step of that file's walkthroughs names the gone "Item level on each slot", Slot Overlays or a Style.
Negative control: XUI_ROOT=<checkout of 64d0943> python3 tests/slot_options_run.py FAILS (A, B, C, D, E).
Run from the repo root: python3 tests/slot_options_run.py   Needs: pip install lupa."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("XUI_ROOT") or os.path.join(HERE, "..")


def P(rel, root=None):
    return "'" + os.path.join(root or ROOT, rel).replace("\\", "/") + "'"


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
function PaperDollItemSlotButton_Update(btn) end
function PaperDollFrame_UpdateStats() end
function PanelTemplates_SetTab(frame, id) frame.selectedTab = id end
ENCHANTED_TOOLTIP_LINE = "Enchanted: %s"
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
local CM = ns.StatModel
for _, s in ipairs(CM.SLOTS) do
  local b = mk("ItemButton"); b.id = s[1]; local nt = reg(); b.GetNormalTexture = function() return nt end; b.normal = nt
  _G["Character" .. s[4]] = b; _G["Character" .. s[4] .. "Frame"] = reg()
end
placePane(540)   -- (A24 #9) the Character tab with its stats pane open (CHARACTERFRAME_EXPANDED_WIDTH): the right-hand column's blocks need the room right of it
QCOL = { [4] = { 0.6, 0.2, 0.9 } }
C_Item.GetItemQualityColor = function(q) local c = QCOL[q]; if c then return c[1], c[2], c[3], "x" end end
UPG = { Helm = { trackString = "Hero", currentLevel = 4, maxLevel = 6, maxItemLevel = 346 }, Ring = { trackString = "Veteran", currentLevel = 1, maxLevel = 8, maxItemLevel = 340 } }
C_Item.GetItemUpgradeInfo = function(link) local name = type(link) == "string" and link:match("%[(.-)%]"); return name and UPG[name] end
GetInventoryItemQuality = function(_, slot) if GEAR[slot] then return 4 end end
TIP = { [11] = { { type = 15, leftText = "Enchanted: Radiant Mastery" } } }
C_TooltipInfo.GetInventoryItem = function(_, slot) return { lines = TIP[slot] or {}, repairCost = REPAIR[slot] } end
-- the next frame: C_Timer.After runs at once unless a case holds the queue (D: the profile import's one-frame wait)
HOLD, QUEUED = false, {}
C_Timer.After = function(d, fn) if HOLD then QUEUED[#QUEUED + 1] = fn else fn() end end
function NextFrame() HOLD = false; local q = QUEUED; QUEUED = {}; for _, fn in ipairs(q) do fn() end end
-- the saved variables as the game sets them before the addons' ADDON_LOADED (set by each case below)
__SAVED__
for _, f in ipairs({ __QOLFILES__ }) do assert(loadfile(f))("XayaUI_QoL", ns) end
ns.FireReady()
ns.SettingsDeclareStore("reskin", "XayaUI_Reskin", "XayaUIReskinDB")
ns.SettingsOpenAllForTests()
ns.FireLogin()
function openWindow() CharacterFrame:Show(); PaperDollFrame:Show(); for _, s in ipairs(CM.SLOTS) do PaperDollItemSlotButton_Update(_G["Character" .. s[4]]) end; PaperDollFrame_UpdateStats(); RSA() end
local function plain(t) return (tostring(t or "")):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
function vis(f) return f ~= nil and f.shown == true and (f.alpha or 1) > 0 end
-- what one slot shows: the item level on the slot, the item level beside it, the marks on it, the enchant beside it
function onSlotIlvl(name) local d = SD_(_G["Character" .. name]); return (vis(d.ilvl) and d.ilvl.text ~= "") and d.ilvl.text or nil end
function besideIlvl(name) local d = SD_(_G["Character" .. name]); local r = d.ilvlRow; return (vis(r) and vis(r.text) and r.text.text ~= "") and r.text.text or nil end
function marksOn(name)
  local m
  if ns.CharDisplay_SlotMarks then m = ns.CharDisplay_SlotMarks(name)
  elseif ns.CharDisplay_OverlayText then local _, x = ns.CharDisplay_OverlayText(name); m = x end
  m = plain(m); return m ~= "" and m or nil
end
function oldMarkIlvl(name) if ns.CharDisplay_OverlayText then local x = ns.CharDisplay_OverlayText(name); x = plain(x); return x ~= "" and x or nil end end
function besideEnchant(name) local d = SD_(_G["Character" .. name]); return (vis(d.enchant) and d.enchant.text ~= "") and d.enchant.text or nil end
function ilvlCount(name) local n = 0; if onSlotIlvl(name) then n = n + 1 end; if besideIlvl(name) then n = n + 1 end; if oldMarkIlvl(name) then n = n + 1 end; return n end
function enchCount(name) local n = 0; if besideEnchant(name) then n = n + 1 end; local m = marksOn(name); if m and m:find("E") then n = n + 1 end; return n end
function page() return ns.BuildCharDisplayPage(function() RSA() end) end
function V(x) if type(x) == "function" then return x({}) end; return x end
'''


def lua_with(saved, body):
    qol = ", ".join(P(r) for r in ("XayaUI_QoL/ImprovedCharacterDisplay.lua", "XayaUI_QoL/CharacterReskin.lua")
                    if os.path.isfile(os.path.join(ROOT, r)))
    src = (PRELUDE.replace("__WORLD__", P("tests/char_world.lua", HERE + "/..")).replace("__GEOM__", P("tests/char_pane_geometry.lua", HERE + "/.."))
           .replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
           .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/StatModel.lua"))
           .replace("__QOLFILES__", qol).replace("__SAVED__", saved))
    lua = LuaRuntime()
    lua.execute(src)
    try:
        lua.execute(body)
    except Exception as e:   # a body that stops on an error (the old tree) counts as one failed check
        lua.execute("check(%r, false, %r)" % ("the case ran to the end", str(e)[:300]))
    return lua.eval("n"), lua.eval("fails")


totals = []
ON = "XayaUIQoLDB = { storeVersion = 1, characterReskin = { features = true, _merged = true }, characterToolkit = {} }\n"

# A. the settings page --------------------------------------------------------------------------------------------------------------
totals.append(lua_with("CueRulesDB = {}\n" + ON, r'''
local pg = page()
local a = pg.args
checkp("A1 QoL > Improved Character Display: the \"Item level\" and \"Enchants\" tick boxes are there", function()
  return a.ilvl and a.ilvl.type == "toggle" and V(a.ilvl.name) == "Item level" and a.enchants and a.enchants.type == "toggle" and V(a.enchants.name) == "Enchants" end)
checkp("A2 (A24 #9) no Style dropdown anywhere on the page (her words: \"it sounds unnecessary\")", function()
  local bad = {}
  local function walk(node, path)
    for k, v in pairs(node.args or {}) do
      if type(v) == "table" then
        if (v.type == "select" and V(v.name) == "Style") or k == "ilvlStyle" or k == "enchantStyle" then bad[#bad + 1] = path .. k end
        walk(v, path .. k .. ".")
      end
    end
  end
  walk(pg, "")
  return #bad == 0, table.concat(bad, ", ") end)
checkp("A3 nothing else removed: Gems and sockets, Empty sockets, Text size, Enchant Slots, Full stat list, Stat Calc button, the Stat list page", function()
  return a.gems and a.socketMark and a.markSize and a.enchantSlotsPage and V(a.enchantSlotsPage.name) == "Enchant Slots" and a.statList and a.statCalcButton
    and a.statListPage and a.enchantSlotsPage.args.slot1 and a.enchantSlotsPage.args.slot1.get({}) == true end)
checkp("A4 no label, hover or note on the page names a Style, \"On the slot\", \"Beside the slot\" or the gone E? / E mark", function()
  local bad = {}
  local function walk(node, path)
    for k, v in pairs(node.args or {}) do
      if type(v) == "table" and k ~= "statListPage" then
        for _, fld in ipairs({ "name", "desc" }) do
          local t = tostring(V(v[fld]) or "")
          if t:find("Style", 1, true) or t:find("On the slot", 1, true) or t:find("Beside the slot", 1, true) or t:find("E?", 1, true) then bad[#bad + 1] = path .. k .. "." .. fld end
        end
        walk(v, path .. k .. ".")
      end
    end
  end
  walk(pg, "")
  return #bad == 0, table.concat(bad, ", ") end)
'''))

# B. what the player sees on the window -------------------------------------------------------------------------------------------
totals.append(lua_with("CueRulesDB = {}\n" + ON, r'''
openWindow()
local a = page().args
local function rowsOf(name)
  local d, out = SD_(_G["Character" .. name]), {}
  for _, f in ipairs({ d.enchantRow or false, d.embRow or false, unpack(d.sockets or {}) }) do if f and vis(f) then out[#out + 1] = f end end
  return out
end
local SLOTN = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot", "HandsSlot", "WaistSlot",
  "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot" }
checkp("B1 the item level on the slot's icon: Head 336 and Ring 330 anchored at the bottom of their own slot, inside the icon", function()
  local out = {}
  for _, name in ipairs({ "HeadSlot", "Finger0Slot" }) do
    local b = _G["Character" .. name]; local d = SD_(b)
    local p, r, s = d.ilvl and d.ilvl.pts and d.ilvl.pts[1], RECT(d.ilvl), RECT(b)
    if not (onSlotIlvl(name) and p and p[1] == "BOTTOM" and p[2] == b and inside(r, s)) then out[#out + 1] = name .. " " .. rstr(r) end
  end
  return onSlotIlvl("HeadSlot") == "336" and onSlotIlvl("Finger0Slot") == "330" and ilvlCount("HeadSlot") == 1 and #out == 0, table.concat(out, "; ") end)
checkp("B2 the left column: the head's \"No enchant\" starts right of its icon (6 px), left-aligned", function()
  local r, s = RECT(SD_(CharacterHeadSlot).enchantRow), RECT(CharacterHeadSlot)
  return besideEnchant("HeadSlot") == "No enchant" and r and math.abs(r.l - (s.r + 6)) < 0.01 and SD_(CharacterHeadSlot).enchant.justifyH == "LEFT", rstr(r) end)
checkp("B3 the right-hand column too: the ring's \"Radiant Mastery\" and its empty socket start right of its icon (6 px), left-aligned (before: left of it)", function()
  local r, s = RECT(SD_(CharacterFinger0Slot).enchantRow), RECT(CharacterFinger0Slot)
  local sk = SD_(CharacterFinger0Slot).sockets and SD_(CharacterFinger0Slot).sockets[1]
  local kr = sk and vis(sk) and RECT(sk)
  return besideEnchant("Finger0Slot") == "Radiant Mastery" and r and math.abs(r.l - (s.r + 6)) < 0.01 and kr and kr.l >= s.r + 6 - 0.01
    and SD_(CharacterFinger0Slot).enchant.justifyH == "LEFT", rstr(r) .. " / " .. rstr(kr or nil) end)
checkp("B4 no E? or E mark on any slot (the enchant shows only at the right edge)", function()
  local out = {}
  for _, name in ipairs(SLOTN) do local m = marksOn(name); if m and m:find("E") then out[#out + 1] = name .. " " .. m end end
  return #out == 0, table.concat(out, ", ") end)
checkp("B5 no row covers any slot's icon, none reaches past the window's right edge less its gutter, every row starts right of its own slot's icon (but the main hand's, left of the weapons)", function()
  local win, out, slots = RECT(CharacterFrame), {}, {}
  for _, name in ipairs(SLOTN) do slots[name] = RECT(_G["Character" .. name]) end
  local n = 0
  for _, name in ipairs(SLOTN) do
    for i, f in ipairs(rowsOf(name)) do
      n = n + 1
      local r = RECT(f)
      for o, sr in pairs(slots) do if overlaps(r, sr) then out[#out + 1] = name .. "#" .. i .. " over " .. o end end
      if r.l < win.l or r.r > win.r - ns.UI_GUTTER + 0.01 or r.b < win.b or r.t > win.t then out[#out + 1] = name .. "#" .. i .. " past the window " .. rstr(r) end
      if name ~= "MainHandSlot" and r.l < slots[name].r then out[#out + 1] = name .. "#" .. i .. " not right of its slot " .. rstr(r) end
    end
  end
  return n >= 3 and #out == 0, n .. " rows; " .. table.concat(out, "; ") end)
checkp("B6 whole pixels (V27): every row's and every item level's offsets are whole numbers", function()
  local out, n = {}, 0
  for _, name in ipairs(SLOTN) do
    local d = SD_(_G["Character" .. name])
    local fr = rowsOf(name)
    if d.ilvl then fr[#fr + 1] = d.ilvl end
    for _, f in ipairs(fr) do for _, pt in ipairs(f.pts or {}) do
      for k = 3, 5 do local v = pt[k]; if type(v) == "number" then n = n + 1; if v ~= math.floor(v) then out[#out + 1] = name .. " " .. tostring(v) end end end
    end end
  end
  return n > 0 and #out == 0, table.concat(out, ", ") end)
checkp("B7 a style key saved in round 3 (Item level \"beside\", Enchants \"slot\") changes nothing: the item level on the icon, the enchant at the right edge, no mark", function()
  local c = ns.CharDisplay_Cfg(); c.ilvlStyle, c.enchantStyle = "beside", "slot"; ns.CharDisplay_Apply(); openWindow()
  local ok = onSlotIlvl("HeadSlot") == "336" and ilvlCount("HeadSlot") == 1 and besideEnchant("HeadSlot") == "No enchant" and besideEnchant("Finger0Slot") == "Radiant Mastery"
    and marksOn("HeadSlot") == nil
  c.ilvlStyle, c.enchantStyle = nil, nil; ns.CharDisplay_Apply(); openWindow()
  return ok end)
checkp("B8 nothing else removed: the empty-socket count with the gems off (ring 1S), the enchant's hover", function()
  local c = ns.CharDisplay_Cfg(); c.gems, c.socketMark = false, true; ns.CharDisplay_Apply(); openWindow()
  local sock = marksOn("Finger0Slot") == "1S"
  c.gems, c.socketMark = true, nil; ns.CharDisplay_Apply(); openWindow()
  local tip = SD_(CharacterFinger0Slot).enchantRow.tip
  return sock and type(tip) == "table" and tip[1] ~= nil and tip[1][1] == "Enchanted: Radiant Mastery", tostring(marksOn("Finger0Slot")) end)
-- (review round 2) the drawn enchant row follows Blizzard's slot redraw (the coverage char_statcalc2_run.py section 8 had for the gone
-- E? / E marks): an enchant added to the head, and the ring's changed, show at once at their slot's right edge
checkp("B10 the enchant follows Blizzard's slot redraw: head \"No enchant\" -> its new enchant, ring -> its new enchant, both 6 px right of their icon", function()
  local g1, g11, t1, t11 = GEAR[1], GEAR[11], TIP[1], TIP[11]
  GEAR[1] = "|cffa335ee|Hitem:1:6000:::::::90:::::|h[Helm]|h|r"; TIP[1] = { { type = 15, leftText = "Enchanted: Stand-in Insight" } }
  PaperDollItemSlotButton_Update(CharacterHeadSlot)
  GEAR[11] = "|cffa335ee|Hitem:2:7001:::::::90:::::|h[Ring]|h|r"; TIP[11] = { { type = 15, leftText = "Enchanted: Stand-in Haste" } }
  PaperDollItemSlotButton_Update(CharacterFinger0Slot)
  local h, r = besideEnchant("HeadSlot"), besideEnchant("Finger0Slot")
  local hr, rr = RECT(SD_(CharacterHeadSlot).enchantRow), RECT(SD_(CharacterFinger0Slot).enchantRow)
  local ok = h == "Stand-in Insight" and r == "Stand-in Haste" and hr and rr and math.abs(hr.l - (RECT(CharacterHeadSlot).r + 6)) < 0.01
    and math.abs(rr.l - (RECT(CharacterFinger0Slot).r + 6)) < 0.01 and marksOn("HeadSlot") == nil
  GEAR[1], GEAR[11], TIP[1], TIP[11] = g1, g11, t1, t11
  PaperDollItemSlotButton_Update(CharacterHeadSlot); PaperDollItemSlotButton_Update(CharacterFinger0Slot)
  return ok and besideEnchant("HeadSlot") == "No enchant" and besideEnchant("Finger0Slot") == "Radiant Mastery", tostring(h) .. " / " .. tostring(r) .. " / " .. rstr(rr) end)
-- (review round 2) the right-hand column's rows lie over the stats pane: counted for her review (the walkthrough's note), since a row
-- over a stat line may take that line's hover (UNVERIFIED IN GAME); the left column's never do
checkp("B11 the walkthrough's read counts the rows over the stats pane: the ring's (right-hand column) are, the head's (left column) are not", function()
  local P = ns.Service("charDisplayDebug").Placement()
  local stats = RECT(CharacterFrame.InsetRight)
  local ringOver = overlaps(RECT(SD_(CharacterFinger0Slot).enchantRow), stats)
  local headOver = overlaps(RECT(SD_(CharacterHeadSlot).enchantRow), stats)
  local n = 0
  for _, name in ipairs(SLOTN) do for _, f in ipairs(rowsOf(name)) do if overlaps(RECT(f), stats) then n = n + 1 end end end
  return ringOver and not headOver and n > 0 and P.overStats == n and P.overStatList == 0, ("overStats %s, counted here %d"):format(tostring(P.overStats), n) end)
a.ilvl.set({}, false); a.enchants.set({}, false)
checkp("B9 Item level and Enchants off: no item level and no enchant anywhere on the slots", function()
  return ilvlCount("HeadSlot") == 0 and ilvlCount("Finger0Slot") == 0 and enchCount("HeadSlot") == 0 and enchCount("Finger0Slot") == 0 end)
'''))

# C. the one-time move of saved settings (each a fresh login with the old layout saved) ----------------------------------------------
def case(name, rk, tk, body):
    saved = ("CueRulesDB = {}\nXayaUIQoLDB = { storeVersion = 1, characterReskin = { features = true, _merged = true, %s }, characterToolkit = { %s } }\n" % (rk, tk))
    totals.append(lua_with(saved, "openWindow()\nlocal c = ns.CharDisplay_Cfg()\n" + body.replace("__NAME__", name)))

case("C1", "ilvl = false, enchants = false, gems = false", "overlays = true, ovIlvl = true, ovEnchants = false, ovSockets = false", r'''
checkp("__NAME__ before: only the Slot Overlays' item level showed: after the move Item level is on and Head 336 shows on its icon (once), no enchant", function()
  return c.ilvl == true and onSlotIlvl("HeadSlot") == "336" and ilvlCount("HeadSlot") == 1 and enchCount("HeadSlot") == 0 end)''')
case("C2", "ilvl = true, enchants = false, gems = true", "overlays = true, ovIlvl = true, ovEnchants = true, ovSockets = true", r'''
checkp("__NAME__ before: the item level on the slot and the Slot Overlays' enchant check: after the move Enchants is on, the head's \"No enchant\" at its right edge (no E?), no style key written", function()
  local t = XayaUIQoLDB.characterToolkit
  return c.enchants == true and besideEnchant("HeadSlot") == "No enchant" and marksOn("HeadSlot") == nil and onSlotIlvl("HeadSlot") == "336" and ilvlCount("HeadSlot") == 1
    and t.ilvlStyle == nil and t.enchantStyle == nil end)''')
case("C3", "ilvl = true, enchants = true, gems = true", "overlays = true, ovIlvl = true, ovEnchants = true, ovSockets = true", r'''
checkp("__NAME__ before: both enchant displays ticked: after the move Enchants on, one enchant per slot", function()
  return c.enchants == true and besideEnchant("HeadSlot") == "No enchant" and enchCount("HeadSlot") == 1 and ilvlCount("HeadSlot") == 1 end)''')
case("C4", "ilvl = false, enchants = false, gems = false", "overlays = false", r'''
checkp("__NAME__ before: neither item level nor enchant showed: after the move both are off and nothing shows", function()
  return c.ilvl == false and c.enchants == false and ilvlCount("HeadSlot") == 0 and enchCount("HeadSlot") == 0 and marksOn("Finger0Slot") == nil end)''')
case("C5", "ilvl = true, enchants = true, gems = false", "overlays = true, ovIlvl = false, ovEnchants = false, ovSockets = true", r'''
checkp("__NAME__ before: the Slot Overlays' empty-socket count with the gems off: after the move Empty sockets is ticked and the ring shows 1S", function()
  return c.socketMark == true and marksOn("Finger0Slot") == "1S" and page().args.socketMark.get({}) == true end)''')
case("C6", "ilvl = true, enchants = true, gems = true", "overlays = false", r'''
checkp("__NAME__ before: the defaults: after the move the same, nothing saved for a style or the mark (profile strings unchanged); its mark is not in a profile", function()
  local t = XayaUIQoLDB.characterToolkit
  local snap = ns.ProfilePartsByKey and ns.ProfilePartsByKey().reskin and ns.ProfilePartsByKey().reskin.snapshot()
  return c.ilvl == true and c.enchants == true and t.ilvlStyle == nil and t.enchantStyle == nil and t.socketMark == nil
    and onSlotIlvl("HeadSlot") == "336" and besideEnchant("HeadSlot") == "No enchant" and XayaUIQoLDB.characterReskin._slotOpts == true
    and snap and snap.characterReskin._slotOpts == nil end)''')

# D. profiles --------------------------------------------------------------------------------------------------------------------------
PP = P("XayaUI_QoL/ProfilePart.lua")
D_SAVED = "CueRulesDB = {}\n" + ON
totals.append(lua_with(D_SAVED, r'''
assert(loadfile(__PP__))("XayaUI_QoL", ns)
openWindow()
local qol, rsk = ns.ProfilePartsByKey().qol, ns.ProfilePartsByKey().reskin
checkp("D0 the QoL profile part is still format 3 (its keys unchanged)", function() return qol.version == 3 end)
HOLD = true
qol.apply({ characterToolkit = { enabled = false, overlays = true, ovIlvl = true, ovEnchants = true, ovSockets = true, ovSize = 11 } }, "merge", 2)
rsk.apply({ characterReskin = { ilvl = true, enchants = false, gems = true, statList = true } }, "merge", 1)
NextFrame(); openWindow()
checkp("D1 an older string (QoL part format 2) with the enchant check on and the enchant beside the slot off: after the import Enchants is on, the head's \"No enchant\" at its right edge (no E?)", function()
  local c = ns.CharDisplay_Cfg()
  return c.enchants == true and besideEnchant("HeadSlot") == "No enchant" and marksOn("HeadSlot") == nil and onSlotIlvl("HeadSlot") == "336" and ilvlCount("HeadSlot") == 1, tostring(marksOn("HeadSlot")) end)
local okI = pcall(qol.apply, { characterToolkit = { ilvlStyle = "beside", enchantStyle = "slot", socketMark = true } }, "merge", 3)
pcall(rsk.apply, { characterReskin = { ilvl = true, enchants = true, gems = false } }, "merge", 1)
NextFrame(); openWindow()
checkp("D2 a format-3 string made in round 3 with both styles: imports without error, the styles change nothing (item level on the icon, enchant at the right edge, no E?); its Empty sockets mark is taken (ring 1S)", function()
  local c = ns.CharDisplay_Cfg()
  return okI and onSlotIlvl("HeadSlot") == "336" and ilvlCount("HeadSlot") == 1 and besideEnchant("HeadSlot") == "No enchant" and marksOn("Finger0Slot") == "1S" and c.socketMark == true,
    tostring(marksOn("Finger0Slot")) end)
'''.replace("__PP__", PP)))
totals.append(lua_with(D_SAVED, r'''
assert(loadfile(__PP__))("XayaUI_QoL", ns)
openWindow()
local qol, rsk = ns.ProfilePartsByKey().qol, ns.ProfilePartsByKey().reskin
HOLD = true
qol.apply({ characterToolkit = { enabled = true, overlays = true, ovIlvl = true, ovEnchants = true, ovSockets = true } }, "merge", 1)
rsk.apply({ characterReskin = { ilvl = true, enchants = true, gems = true } }, "merge", 1)
NextFrame(); openWindow()
checkp("D3 an older string (format 1) with the item details and the marks on: item level on the icon, enchant at the right edge, Empty sockets ticked (it yields to the gems, as before)", function()
  local c = ns.CharDisplay_Cfg()
  return c.socketMark == true and onSlotIlvl("HeadSlot") == "336" and besideEnchant("HeadSlot") == "No enchant" and marksOn("HeadSlot") == nil and marksOn("Finger0Slot") == nil end)
'''.replace("__PP__", PP)))
# D4-D5 (review round 2) an older string's QoL part imported WITHOUT its Blizzard Reskin part: the settings saved now are kept (never read
# as the old keys); the string's old slot marks are added as at the move
totals.append(lua_with(D_SAVED, r'''
assert(loadfile(__PP__))("XayaUI_QoL", ns)
openWindow()
local qol = ns.ProfilePartsByKey().qol
local c = ns.CharDisplay_Cfg()
c.enchants = false; ns.CharDisplay_Apply()
HOLD = true
qol.apply({ characterToolkit = { enabled = true, overlays = false, ovIlvl = true, ovEnchants = true, ovSockets = true } }, "merge", 2)
NextFrame(); openWindow()
checkp("D4 Enchants off, then an older QoL part alone with its slot marks off: Enchants stays off, the item level stays on its icon", function()
  c = ns.CharDisplay_Cfg()
  return c.ilvl == true and c.enchants == false and onSlotIlvl("HeadSlot") == "336" and enchCount("HeadSlot") == 0 end)
HOLD = true
qol.apply({ characterToolkit = { enabled = true, overlays = true, ovIlvl = true, ovEnchants = true, ovSockets = false } }, "merge", 2)
NextFrame(); openWindow()
checkp("D5 ...then an older QoL part alone with the enchant check on: Enchants on, at the right edge (no E?), one item level", function()
  c = ns.CharDisplay_Cfg()
  return c.enchants == true and besideEnchant("HeadSlot") == "No enchant" and marksOn("HeadSlot") == nil and ilvlCount("HeadSlot") == 1 end)
'''.replace("__PP__", PP)))

# E. the in-game walkthrough (XayaUI_DevAssist/QAWalks-slot-options.lua) run against this world with a stand-in framework: its prefilled
#    verdicts are the ones a player would be offered; the review step is hers (no verdict); the last step puts her settings back.
WALK = P("XayaUI_DevAssist/QAWalks-slot-options.lua", HERE + "/..")
totals.append(lua_with("CueRulesDB = {}\n" + ON, r'''
local regd = {}
XayaUI_DevQA = { Register = function(id, def) regd[id] = def end }
XayaUI_NS = ns
local f = loadfile(__WALK__)
check("E0 the walkthrough file loads", f ~= nil)
if f then f() end
local def = regd["slot-options"]
local noStyle = true
for _, st in ipairs(def and def.steps or {}) do if st.text:find("Style|r to", 1, true) or st.text:find("Beside the slot", 1, true) or st.text:find("On the slot", 1, true) then noStyle = false end end
check("E1 registers \"slot-options\" with prefill and five steps; step 4 is Xaya's in-game review (no verdict); no step asks for a Style",
  def ~= nil and def.prefill == true and #def.steps == 5 and def.steps[4].noVerdict == true and def.steps[4].text:find("Xaya's in-game review", 1, true) ~= nil and noStyle)
if def and #def.steps == 5 then
  local c = ns.CharDisplay_Cfg()
  c.ilvl, c.enchants, c.gems = false, true, false; ns.CharDisplay_Apply(); openWindow()
  local ok1, note1 = def.steps[1].check()
  check("E2 step 1 captures what the settings are now (data, no verdict)", def.steps[1].noVerdict == true and ok1 == true and tostring(note1):find("Item level: off; Enchants: on; Gems: off", 1, true) ~= nil, note1)
  def.steps[2].setup(); openWindow()
  local ok2, note2 = def.steps[2].check()
  check("E3 step 2 after Do it for me: item levels on their icons, every row right of its slot, none over a slot icon or past the window (verdict Pass)", ok2 == true
    and onSlotIlvl("HeadSlot") == "336" and besideEnchant("Finger0Slot") == "Radiant Mastery", note2)
  local ok3, note3 = def.steps[3].check()
  check("E4 step 3: the settings page has no Style dropdown and keeps the other options (verdict Pass)", ok3 == true, note3)
  local ok4, note4 = def.steps[4].check()
  check("E5 step 4 (her review) captures the layout counts, the rows over the stats pane and over Full stat list lines among them", ok4 == true
    and tostring(note4):find("rows:", 1, true) ~= nil and tostring(note4):find("over the stats pane: ", 1, true) ~= nil
    and tostring(note4):find("over a Full stat list line: ", 1, true) ~= nil, note4)
  local t4 = def.steps[4].text
  check("E5b (review round 2) step 4 puts each open choice to her: the stat hovers under the right-hand column's rows, the main hand not on its right edge, the item level, the removed E? / E check, the narrow window",
    t4:find("does the stat's own tooltip still show", 1, true) ~= nil and t4:find("NOT on its right edge", 1, true) ~= nil and t4:find("bottom of the icon", 1, true) ~= nil
    and t4:find("E? / E enchant check", 1, true) ~= nil and t4:find("want it back", 1, true) ~= nil and t4:find("without the stats pane", 1, true) ~= nil
    and t4:find("open question", 1, true) ~= nil, t4)
  def.steps[5].setup()
  local c2 = ns.CharDisplay_Cfg()
  check("E6 the last step puts Item level, Enchants and the gems back as they were before step 2", c2.ilvl == false and c2.enchants == true and c2.gems == false)
end
'''.replace("__WALK__", WALK)))

# E7 the walkthrough that pointed at the gone Slot Overlays and Style: "improved-character-display" step 5 (QAWalks-character-split.lua)
#    asks for Item level and Enchants, and passes on the slots that show them
WALK2 = P("XayaUI_DevAssist/QAWalks-character-split.lua", HERE + "/..")
totals.append(lua_with("CueRulesDB = {}\n" + ON, r'''
local regd = {}
XayaUI_DevQA = { Register = function(id, def) regd[id] = def end }
XayaUI_NS = ns
local f = loadfile(__WALK__)
if f then f() end
local def = regd["improved-character-display"]
checkp("E7 \"improved-character-display\" step 5 asks for Item level and Enchants (no Slot Overlays, no Style): with both on and the window open, Pass", function()
  local st = def.steps[5]
  if st.text:find("Slot Overlays", 1, true) or st.text:find("Style", 1, true) then return false, "still names Slot Overlays or a Style" end
  local c = ns.CharDisplay_Cfg(); c.ilvl, c.enchants = true, true; ns.CharDisplay_Apply(); openWindow()
  local v, note = st.check()
  return v == true, note end)
local stale = {}
for id, d in pairs(regd) do for i, st in ipairs(d.steps or {}) do
  local t = tostring(st.text or "")
  if t:find("Item level on each slot", 1, true) or t:find("Slot Overlays", 1, true) or t:find("Slot overlays", 1, true) or t:find("Style|r", 1, true) then stale[#stale + 1] = id .. " step " .. i end
end end
check("E8 no step of QAWalks-character-split.lua's walkthroughs names the gone \"Item level on each slot\", Slot Overlays or a Style", #stale == 0, table.concat(stale, ", "))
'''.replace("__WALK__", WALK2)))

n = sum(t[0] for t in totals); fails = sum(t[1] for t in totals)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
