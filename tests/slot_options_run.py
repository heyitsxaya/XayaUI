#!/usr/bin/env python3
"""Improved Character Display: one "Item level" option and one "Enchants" option, each with a Style (Xaya, REQUEST-LOG A24 #7, her answer
"1 with the caveat needs review in game"; option 1: "One 'Item level' option and one 'Enchants' option, each with a style choice: on the
slot or beside it. The overlap is gone.").

What the player sees, on the stand-in character window (tests/char_world.lua, tests/char_pane_geometry.lua; Helm 336 in slot 1 with no
enchant, Ring 330 in slot 11 enchanted "Radiant Mastery" with one empty socket; every item and number is a TEST STAND-IN):
  A  QoL > Improved Character Display: an "Item level" option and an "Enchants" option, each followed by a "Style" choice with exactly
     "On the slot" and "Beside the slot"; no Slot Overlays part, no greyed item level or enchant mark; the Enchant Slots are still there.
     A Style is greyed while its option is off.
  B  On the slot / Beside the slot draw where they say: the item level at the bottom of the slot or as the first line beside it (same
     number, same track color); the enchant check E? / E at the top of the slot or the enchant's name / "No enchant" beside it. Every
     combination of the two styles: exactly one item level and one enchant display per slot. Off: none.
  C  The one-time move of saved settings (each from a fresh login with the old layout saved): each player sees what they saw before.
     Where both the beside-the-slot enchant and the enchant check were ticked, only the first showed: Enchants, Beside the slot.
     It runs once: a later choice is kept at the next login.
  D  Profiles: an older string (QoL part format 1 or 2) still imports: its old keys are read the same way, after the Blizzard Reskin part
     (which carries the item details' keys) is in; a format-3 string is imported as it is (a style it does not hold is its default).
  D4-D5 (review round 2) an older string's QoL part imported without its Blizzard Reskin part: the settings saved now (already the two
     options) are kept, never read as the old keys; the string's old marks are added as at the move.
  E  The in-game walkthrough "slot-options" (V22): its verdicts on the stand-in, the review step for Xaya (no verdict), the put-back.
     E7: "improved-character-display" step 5 (QAWalks-character-split.lua) asks for the two options, not the gone Slot Overlays.
     E8 (integration): no step of that file's walkthroughs names the gone "Item level on each slot" or Slot Overlays ("character-split"
         step 1 did).
Negative control: XUI_ROOT=<checkout of af1f2ba> python3 tests/slot_options_run.py FAILS (A, B, C, D).
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
placePane()
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
local function vis(f) return f ~= nil and f.shown == true and (f.alpha or 1) > 0 end
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
local function styleOk(sel)
  if type(sel) ~= "table" or sel.type ~= "select" then return false end
  local vals, n = V(sel.values) or {}, 0
  for _ in pairs(vals) do n = n + 1 end
  local order = {}
  for _, k in ipairs(sel.sorting or {}) do order[#order + 1] = vals[k] end
  return n == 2 and table.concat(order, "|") == "On the slot|Beside the slot", table.concat(order, "|")
end
checkp("A1 QoL > Improved Character Display has an \"Item level\" option followed by its Style: \"On the slot\" / \"Beside the slot\"", function()
  local ok, got = styleOk(a.ilvlStyle)
  return a.ilvl and V(a.ilvl.name) == "Item level" and ok and a.ilvlStyle.order > a.ilvl.order and a.ilvlStyle.order < a.enchants.order, got end)
checkp("A2 ...and an \"Enchants\" option followed by its Style: \"On the slot\" / \"Beside the slot\"", function()
  local ok, got = styleOk(a.enchantStyle)
  return a.enchants and V(a.enchants.name) == "Enchants" and ok and a.enchantStyle.order > a.enchants.order, got end)
checkp("A3 the overlap is gone: no Slot Overlays part, and no other control on the page draws an item level or an enchant check", function()
  local bad = {}
  local function walk(node)
    for k, v in pairs(node.args or {}) do
      if type(v) == "table" then
        local n = V(v.name)
        if n == "Slot overlays" or n == "Slot Overlays" or n == "Enchant check" or n == "Item level on each slot" or n == "Enchants beside the slots"
          or (n == "Item level" and v ~= a.ilvl) then bad[#bad + 1] = tostring(n) end
        walk(v)
      end
    end
  end
  walk(pg)
  return a.overlayPart == nil and #bad == 0, table.concat(bad, ", ") end)
checkp("A4 the Enchant Slots are still on the page (the slots the enchant check and \"No enchant\" look at)", function()
  local es = a.enchantSlotsPage
  return es and V(es.name) == "Enchant Slots" and es.args.slot1 and es.args.slot1.get({}) == true end)
checkp("A5 the defaults: Item level on the slot, Enchants beside the slot (where each showed before)", function()
  return a.ilvlStyle.get({}) == "slot" and a.enchantStyle.get({}) == "beside" end)
checkp("A6 a Style is greyed while its option is off, live while it is on", function()
  local live = not V(a.ilvlStyle.disabled) and not V(a.enchantStyle.disabled)
  a.ilvl.set({}, false); a.enchants.set({}, false)
  local off = V(a.ilvlStyle.disabled) == true and V(a.enchantStyle.disabled) == true
  a.ilvl.set({}, true); a.enchants.set({}, true)
  return live and off end)
'''))

# B. what each style draws ----------------------------------------------------------------------------------------------------------
totals.append(lua_with("CueRulesDB = {}\n" + ON, r'''
openWindow()
local a = page().args
checkp("B1 Item level, On the slot: Head 336 at the bottom of the slot, nothing beside it", function()
  local d = SD_(CharacterHeadSlot)
  local p = d.ilvl and d.ilvl.pts and d.ilvl.pts[1]
  return onSlotIlvl("HeadSlot") == "336" and besideIlvl("HeadSlot") == nil and p and p[1] == "BOTTOM" and p[2] == CharacterHeadSlot, tostring(onSlotIlvl("HeadSlot")) end)
a.ilvlStyle.set({}, "beside")
checkp("B2 Item level, Beside the slot: Head 336 beside the slot (to its right, the left column), none on the slot", function()
  local r, s = RECT(SD_(CharacterHeadSlot).ilvlRow), RECT(CharacterHeadSlot)
  return besideIlvl("HeadSlot") == "336" and onSlotIlvl("HeadSlot") == nil and r and s and r.l >= s.r, besideIlvl("HeadSlot") end)
checkp("  ...in its track color (Hero step 4 of 6: purple at 82%), as on the slot; the ring beside its slot too (330, the right column: to its left)", function()
  local c = SD_(CharacterHeadSlot).ilvlRow.text.color
  local r, s = RECT(SD_(CharacterFinger0Slot).ilvlRow), RECT(CharacterFinger0Slot)
  return c and math.abs(c[1] - 0.6 * 0.82) < 0.01 and math.abs(c[3] - 0.9 * 0.82) < 0.01 and besideIlvl("Finger0Slot") == "330" and r.r <= s.l end)
checkp("  ...first in the block, above the enchant line", function()
  local i, e = RECT(SD_(CharacterFinger0Slot).ilvlRow), RECT(SD_(CharacterFinger0Slot).enchantRow)
  return i and e and i.b >= e.t end)
a.ilvlStyle.set({}, "slot")
checkp("B3 Enchants, Beside the slot: the ring's enchant by name and \"No enchant\" beside the head; no E / E? on the slots", function()
  return besideEnchant("Finger0Slot") == "Radiant Mastery" and besideEnchant("HeadSlot") == "No enchant" and marksOn("HeadSlot") == nil and marksOn("Finger0Slot") == nil end)
a.enchantStyle.set({}, "slot")
checkp("B4 Enchants, On the slot: E? (orange) at the top of the head, E (green) on the ring; nothing beside them", function()
  local raw = ns.CharDisplay_SlotMarks("HeadSlot")
  return marksOn("HeadSlot") == "E?" and marksOn("Finger0Slot") == "E" and besideEnchant("HeadSlot") == nil and besideEnchant("Finger0Slot") == nil
    and tostring(raw):find("|cffff8f40", 1, true) ~= nil, tostring(raw) end)
checkp("  ...the embellishment and the gems stay beside the slot (the gems: their own option, unchanged)", function()
  local n = 0; for _, f in ipairs(SD_(CharacterFinger0Slot).sockets or {}) do if f.shown then n = n + 1 end end
  return n == 1 end)
local bad = {}
for _, ist in ipairs({ "slot", "beside" }) do for _, est in ipairs({ "slot", "beside" }) do
  a.ilvlStyle.set({}, ist); a.enchantStyle.set({}, est)
  for _, name in ipairs({ "HeadSlot", "Finger0Slot" }) do
    if ilvlCount(name) ~= 1 or enchCount(name) ~= 1 then bad[#bad + 1] = ("%s %s/%s: %d item levels, %d enchants"):format(name, ist, est, ilvlCount(name), enchCount(name)) end
  end
end end
check("B5 every combination of the two styles: exactly one item level and one enchant display on each slot (the overlap is gone)", #bad == 0, table.concat(bad, "; "))
a.ilvl.set({}, false); a.enchants.set({}, false)
checkp("B6 Item level and Enchants off: no item level and no enchant anywhere on the slots", function()
  return ilvlCount("HeadSlot") == 0 and ilvlCount("Finger0Slot") == 0 and enchCount("HeadSlot") == 0 and enchCount("Finger0Slot") == 0 end)
'''))

# C. the one-time move of saved settings (each a fresh login with the old layout saved) ----------------------------------------------
def case(name, rk, tk, body):
    saved = ("CueRulesDB = {}\nXayaUIQoLDB = { storeVersion = 1, characterReskin = { features = true, _merged = true, %s }, characterToolkit = { %s } }\n" % (rk, tk))
    totals.append(lua_with(saved, "openWindow()\nlocal c = ns.CharDisplay_Cfg()\n" + body.replace("__NAME__", name)))

case("C1", "ilvl = false, enchants = false, gems = false", "overlays = true, ovIlvl = true, ovEnchants = false, ovSockets = false", r'''
checkp("__NAME__ before: only the Slot Overlays' item level showed: after the move Item level is on, On the slot, and Head 336 shows on the slot (once)", function()
  return c.ilvl == true and c.ilvlStyle == nil and onSlotIlvl("HeadSlot") == "336" and ilvlCount("HeadSlot") == 1 and enchCount("HeadSlot") == 0 end)''')
case("C2", "ilvl = true, enchants = false, gems = true", "overlays = true, ovIlvl = true, ovEnchants = true, ovSockets = true", r'''
checkp("__NAME__ before: the item level on the slot and the Slot Overlays' enchant check: after the move Enchants is on, On the slot (head E?), the item level on the slot", function()
  return c.enchants == true and c.enchantStyle == "slot" and marksOn("HeadSlot") == "E?" and besideEnchant("HeadSlot") == nil and onSlotIlvl("HeadSlot") == "336" and ilvlCount("HeadSlot") == 1 end)''')
case("C3", "ilvl = true, enchants = true, gems = true", "overlays = true, ovIlvl = true, ovEnchants = true, ovSockets = true", r'''
checkp("__NAME__ before: both the enchant beside the slot and the enchant check ticked (only the first showed): after the move Enchants, Beside the slot", function()
  return c.enchants == true and c.enchantStyle == nil and besideEnchant("HeadSlot") == "No enchant" and marksOn("HeadSlot") == nil and ilvlCount("HeadSlot") == 1 end)''')
case("C4", "ilvl = false, enchants = false, gems = false", "overlays = false", r'''
checkp("__NAME__ before: neither item level nor enchant showed: after the move both are off and nothing shows", function()
  return c.ilvl == false and c.enchants == false and ilvlCount("HeadSlot") == 0 and enchCount("HeadSlot") == 0 and marksOn("Finger0Slot") == nil end)''')
case("C5", "ilvl = true, enchants = true, gems = false", "overlays = true, ovIlvl = false, ovEnchants = false, ovSockets = true", r'''
checkp("__NAME__ before: the Slot Overlays' empty-socket count with the gems beside the slots off: after the move Empty sockets is ticked and the ring shows 1S", function()
  return c.socketMark == true and marksOn("Finger0Slot") == "1S" and page().args.socketMark.get({}) == true end)''')
case("C6", "ilvl = true, enchants = true, gems = true", "overlays = false", r'''
checkp("__NAME__ before: the defaults (item level on the slot, enchant beside it): after the move the same, nothing saved for the styles (profile strings unchanged)", function()
  local t = XayaUIQoLDB.characterToolkit
  return c.ilvl == true and c.enchants == true and t.ilvlStyle == nil and t.enchantStyle == nil and t.socketMark == nil
    and onSlotIlvl("HeadSlot") == "336" and besideEnchant("HeadSlot") == "No enchant" end)
checkp("  ...it runs once: a style chosen afterwards is kept at the next read (its mark starts with \"_\": no profile carries it)", function()
  c.ilvlStyle = "beside"; ns.CharDisplay_MigrateSlotOptions()
  local snap = ns.ProfilePartsByKey and ns.ProfilePartsByKey().reskin and ns.ProfilePartsByKey().reskin.snapshot()
  return ns.CharDisplay_Cfg().ilvlStyle == "beside" and XayaUIQoLDB.characterReskin._slotOpts == true and snap and snap.characterReskin._slotOpts == nil end)''')

# D. profiles --------------------------------------------------------------------------------------------------------------------------
PP = P("XayaUI_QoL/ProfilePart.lua")
D_SAVED = "CueRulesDB = {}\n" + ON
totals.append(lua_with(D_SAVED, r'''
assert(loadfile(__PP__))("XayaUI_QoL", ns)
openWindow()
local qol, rsk = ns.ProfilePartsByKey().qol, ns.ProfilePartsByKey().reskin
checkp("D0 the QoL profile part is format 3", function() return qol.version == 3 end)
-- an older string (format 2) made by a player who had the enchant check on and the enchant beside the slot off: the QoL part, then the
-- Blizzard Reskin part, as Profiles applies them (in one pass, in their order), then the next frame
HOLD = true
qol.apply({ characterToolkit = { enabled = false, overlays = true, ovIlvl = true, ovEnchants = true, ovSockets = true, ovSize = 11 } }, "merge", 2)
rsk.apply({ characterReskin = { ilvl = true, enchants = false, gems = true, statList = true } }, "merge", 1)
NextFrame(); openWindow()
checkp("D1 an older string (QoL part format 2) with the enchant check on and the enchant beside the slot off: after the import Enchants is On the slot (head E?)", function()
  local c = ns.CharDisplay_Cfg()
  return c.enchants == true and c.enchantStyle == "slot" and marksOn("HeadSlot") == "E?" and besideEnchant("HeadSlot") == nil, tostring(marksOn("HeadSlot")) end)
checkp("  ...and the item level as it was (on the slot, once)", function() return onSlotIlvl("HeadSlot") == "336" and ilvlCount("HeadSlot") == 1 end)
-- a string made now (format 3) by a player with Enchants beside the slot (the default style: not in the string), imported over the
-- On the slot above: the style it does not hold is its default; the old keys it still carries are not read again
qol.apply({ characterToolkit = { overlays = true, ovEnchants = true, ovIlvl = true, ovSockets = true } }, "merge", 3)
rsk.apply({ characterReskin = { ilvl = true, enchants = true, gems = true } }, "merge", 1)
NextFrame(); openWindow()
checkp("D2 a format-3 string with Enchants beside the slot, imported over On the slot: Enchants beside the slot (its style's default), the old keys it carries not read", function()
  local c = ns.CharDisplay_Cfg()
  return c.enchantStyle == nil and besideEnchant("HeadSlot") == "No enchant" and marksOn("HeadSlot") == nil end)
'''.replace("__PP__", PP)))
totals.append(lua_with(D_SAVED, r'''
assert(loadfile(__PP__))("XayaUI_QoL", ns)
openWindow()
local qol, rsk = ns.ProfilePartsByKey().qol, ns.ProfilePartsByKey().reskin
HOLD = true
qol.apply({ characterToolkit = { enabled = true, overlays = true, ovIlvl = true, ovEnchants = true, ovSockets = true } }, "merge", 1)
rsk.apply({ characterReskin = { ilvl = true, enchants = true, gems = true } }, "merge", 1)
NextFrame(); openWindow()
checkp("D3 an older string (format 1) with the item details and the marks on: Item level on the slot, Enchants beside the slot (only those showed), Empty sockets ticked (it yields to the gems, as before)", function()
  local c = ns.CharDisplay_Cfg()
  return c.ilvlStyle == nil and c.enchantStyle == nil and c.socketMark == true and onSlotIlvl("HeadSlot") == "336" and besideEnchant("HeadSlot") == "No enchant"
    and marksOn("HeadSlot") == nil and marksOn("Finger0Slot") == nil end)
'''.replace("__PP__", PP)))

# D4-D5 (review round 2) an older string's QoL part imported WITHOUT its Blizzard Reskin part: the item level / enchant settings saved now
# already mean the two options and are kept as they are (never read as the old keys); the string's old slot marks are added as at the move
totals.append(lua_with(D_SAVED, r'''
assert(loadfile(__PP__))("XayaUI_QoL", ns)
openWindow()
local qol = ns.ProfilePartsByKey().qol
local c = ns.CharDisplay_Cfg()
c.ilvlStyle, c.enchantStyle = "beside", "slot"; ns.CharDisplay_Apply()
HOLD = true
qol.apply({ characterToolkit = { enabled = true, overlays = false, ovIlvl = true, ovEnchants = true, ovSockets = true } }, "merge", 2)
NextFrame(); openWindow()
checkp("D4 Item level beside the slot and Enchants on the slot, then an older QoL part alone (its slot marks off): both stay as they were (no flip to Beside, no reset to On the slot)", function()
  c = ns.CharDisplay_Cfg()
  return c.ilvl == true and c.ilvlStyle == "beside" and c.enchants == true and c.enchantStyle == "slot" and besideIlvl("HeadSlot") == "336"
    and marksOn("HeadSlot") == "E?" and besideEnchant("HeadSlot") == nil, ("%s/%s/%s"):format(tostring(c.ilvlStyle), tostring(c.enchantStyle), tostring(marksOn("HeadSlot")))
end)
c.enchants = false; ns.CharDisplay_Apply()
HOLD = true
qol.apply({ characterToolkit = { enabled = true, overlays = true, ovIlvl = true, ovEnchants = true, ovSockets = false } }, "merge", 2)
NextFrame(); openWindow()
checkp("D5 Enchants off, then an older QoL part alone with the enchant check on: Enchants on, On the slot (head E?), the item level still beside the slot", function()
  c = ns.CharDisplay_Cfg()
  return c.enchants == true and c.enchantStyle == "slot" and marksOn("HeadSlot") == "E?" and c.ilvlStyle == "beside" and ilvlCount("HeadSlot") == 1 end)
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
check("E1 registers \"slot-options\" with prefill and six steps; its review step is titled for Xaya's in-game review and asks her (no verdict)",
  def ~= nil and def.prefill == true and #def.steps == 6 and def.steps[5].noVerdict == true and def.steps[5].text:find("Xaya's in-game review", 1, true) ~= nil)
if def then
  local c = ns.CharDisplay_Cfg()
  c.ilvlStyle, c.enchantStyle = "beside", "slot"; ns.CharDisplay_Apply(); openWindow()
  local ok1, note1 = def.steps[1].check()
  check("E2 step 1 captures what the settings are now (data, no verdict)", def.steps[1].noVerdict == true and ok1 == true and tostring(note1):find("Item level: Beside the slot; Enchants: On the slot", 1, true) ~= nil, note1)
  def.steps[2].setup(); openWindow()
  local ok2, note2 = def.steps[2].check()
  check("E3 step 2 after Do it for me: item level on the slot, enchants beside it (verdict Pass)", ok2 == true and onSlotIlvl("HeadSlot") == "336" and besideEnchant("HeadSlot") == "No enchant", note2)
  def.steps[3].setup(); openWindow()
  local ok3, note3 = def.steps[3].check()
  check("E4 step 3 after Do it for me: the item level beside the slot (verdict Pass)", ok3 == true and besideIlvl("HeadSlot") == "336" and onSlotIlvl("HeadSlot") == nil, note3)
  def.steps[4].setup(); openWindow()
  local ok4, note4 = def.steps[4].check()
  check("E5 step 4 after Do it for me: E? on the head, nothing beside it (verdict Pass)", ok4 == true and marksOn("HeadSlot") == "E?" and besideEnchant("HeadSlot") == nil, note4)
  def.steps[6].setup()
  local c2 = ns.CharDisplay_Cfg()
  check("E6 the last step puts the item level and enchants and their styles back as they were before step 2", c2.ilvl == true and c2.enchants == true
    and c2.ilvlStyle == "beside" and c2.enchantStyle == "slot")
end
'''.replace("__WALK__", WALK)))

# E7 (review round 2) the walkthroughs that pointed at the gone Slot Overlays: "improved-character-display" step 5
#    (QAWalks-character-split.lua) now asks for Item level and Enchants On the slot, and passes on the slots that show them
WALK2 = P("XayaUI_DevAssist/QAWalks-character-split.lua")
totals.append(lua_with("CueRulesDB = {}\n" + ON, r'''
local regd = {}
XayaUI_DevQA = { Register = function(id, def) regd[id] = def end }
XayaUI_NS = ns
local f = loadfile(__WALK__)
if f then f() end
local def = regd["improved-character-display"]
checkp("E7 \"improved-character-display\" step 5 no longer asks for Slot Overlays: with Item level and Enchants on the slot and the window open, Pass", function()
  local st = def.steps[5]
  if st.text:find("Slot Overlays", 1, true) then return false, "still names Slot Overlays" end
  local c = ns.CharDisplay_Cfg(); c.ilvl, c.enchants, c.enchantStyle = true, true, "slot"; ns.CharDisplay_Apply(); openWindow()
  local v, note = st.check()
  return v == true, note end)
-- E8 (integration) no step of that file's walkthroughs asks the tester to tick the gone option names ("Item level on each slot" is now
-- "Item level")
local stale = {}
for id, d in pairs(regd) do for i, st in ipairs(d.steps or {}) do
  local t = tostring(st.text or "")
  if t:find("Item level on each slot", 1, true) or t:find("Slot Overlays", 1, true) or t:find("Slot overlays", 1, true) then stale[#stale + 1] = id .. " step " .. i end
end end
check("E8 no step of QAWalks-character-split.lua's walkthroughs names the gone \"Item level on each slot\" or Slot Overlays", #stale == 0, table.concat(stale, ", "))
'''.replace("__WALK__", WALK2)))

n = sum(t[0] for t in totals); fails = sum(t[1] for t in totals)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
