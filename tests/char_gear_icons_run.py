# Stub test for QoL > Character Toolkit, Gear tab icons (XayaUI_QoL 0.7.9). Xaya 2026-11-04: "gear pane should show small icons of the
# gear equipped". Checks: an "Equipped" section first on the Gear tab; one icon per equipped item in slot order (shirt and tabard left
# out); the game's texture, item level and quality colour; the game's item tooltip on hover (GameTooltip:SetInventoryItem, as
# Blizzard's ItemUtil.DisplayEquipSlotTooltip does), the item link as a fallback; the game's modified click; a missing texture shows
# the question mark; nothing equipped; icons hidden on other tabs; layout (V11).
# Run from the repo root: python3 tests/char_gear_icons_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua.
# Textures, item levels and quality colours below are TEST STAND-INS (made-up values), not game data.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
assert(loadfile(__WORLD__))()
-- the world has a Helm (slot 1) and a Ring (slot 11); add a shirt (slot 4, left out) and a weapon (slot 16) with no texture yet
ITEMS.Shirt = { ilvl = 1, loc = "INVTYPE_BODY", stats = {} }
ITEMS.Blade = { ilvl = 340, loc = "INVTYPE_WEAPON", stats = { ITEM_MOD_AGILITY_SHORT = 300 } }
GEAR[4] = "|cffffffff|Hitem:4::::::::90:::::|h[Shirt]|h|r"
GEAR[16] = "|cffa335ee|Hitem:5::::::::90:::::|h[Blade]|h|r"
TEX = { [1] = 1001, [11] = 1011, [4] = 1004 }   -- slot 16 has none (the game has not sent it yet)
QUAL = { [1] = 4, [11] = 3, [4] = 1, [16] = 4 }
GetInventoryItemTexture = function(unit, slot) if GEAR[slot] then return TEX[slot] end end
GetInventoryItemQuality = function(unit, slot) if GEAR[slot] then return QUAL[slot] end end
C_Item.GetItemQualityColor = function(q) return ({ [1] = { 1, 1, 1 }, [3] = { 0.1, 0.4, 0.9 }, [4] = { 0.6, 0.2, 0.9 } })[q][1],
  ({ [1] = { 1, 1, 1 }, [3] = { 0.1, 0.4, 0.9 }, [4] = { 0.6, 0.2, 0.9 } })[q][2], ({ [1] = { 1, 1, 1 }, [3] = { 0.1, 0.4, 0.9 }, [4] = { 0.6, 0.2, 0.9 } })[q][3], "x" end
modClicks = {}
HandleModifiedItemClick = function(link) modClicks[#modClicks + 1] = link; return true end
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
ns.FireReady()
local CM = ns.CharModel
local c = ns.CharToolkit_Cfg()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
GameTooltip = mk("GameTooltip")
invSet = {}
GameTooltip.SetInventoryItem = function(self, unit, slot) invSet[#invSet + 1] = unit .. ":" .. slot; return true end
c.enabled = true
ns.CharToolkit_Apply()
CharacterFrame.shown = true; PaperDollFrame:Show()
local function drawn() return ns.CharToolkit_Drawn() end
local function render(tab) c.tab = tab; ns.CharToolkit_Render(); return drawn() end
local function recs(d, kind) local out = {}; for _, r in ipairs(d.layout) do if not kind or r.kind == kind then out[#out + 1] = r end end; return out end
local function texts(d, kind) local t = {}; for _, r in ipairs(recs(d, kind)) do t[#t + 1] = r.text end; return t end
local function shownIcons(d) local t = {}; for _, b in ipairs(d.icons or {}) do if b.shown then t[#t + 1] = b end end; return t end

-- 1. The model -----------------------------------------------------------------------------------------------------------------
local m = CM.Build(c, "gear")
check("Gear: an Equipped section comes first", m.sections[1] and m.sections[1].key == "gearIcons" and m.sections[1].title == "Equipped", m.sections[1] and m.sections[1].key)
local it = m.byKey.gearIcons
local slots = {}
for _, ic in ipairs(it and it.icons or {}) do slots[#slots + 1] = ic.slot end
check("one icon per equipped item in slot order (Head, Finger 1, Main Hand); the shirt left out", table.concat(slots, ",") == "1,11,16", table.concat(slots, ","))
check("  ...each with the game's texture, item level and quality colour", it.icons[1].tex == 1001 and it.icons[1].ilvl == 336 and it.icons[1].color[1] == 0.6
  and it.icons[2].color[3] == 0.9, tostring(it.icons[1].tex))
check("  ...a texture the game has not sent yet is left empty", it.icons[3].tex == nil)

-- 2. The panel -----------------------------------------------------------------------------------------------------------------
local d = render("gear")
local hs = texts(d, "header")
check("Gear tab headers: Equipped, Compare, Summary, Durability and repair (QoL 0.7.14: the per-slot list became the comparison)",
  table.concat(hs, "|") == "- Equipped|- Compare|- Summary|- Durability and repair", table.concat(hs, "|"))
local ib = shownIcons(d)
check("three icons drawn", #ib == 3, #ib)
for _, b in ipairs(ib) do b.tex.SetTexture = function(self, t) self.texture = t end end
d = render("gear"); ib = shownIcons(d)
check("  ...with the game's textures; the one not sent yet shows the question mark", ib[1].tex.texture == 1001 and ib[2].tex.texture == 1011
  and ib[3].tex.texture == "Interface\\Icons\\INV_Misc_QuestionMark", tostring(ib[3].tex.texture))
local seen = {}
for _, b in ipairs(ib) do seen[#seen + 1] = tostring(b.slot) end
check("  ...in slot order", table.concat(seen, ",") == "1,11,16", table.concat(seen, ","))
check("  ...item levels under them (336, 330, 340)", table.concat(texts(d, "iconText"), ",") == "336,330,340", table.concat(texts(d, "iconText"), ","))
check("  ...the border in the item's quality colour", ib[1].border.color and ib[1].border.color[1] == 0.6 and ib[2].border.color[3] == 0.9)
-- hover: the game's item tooltip for that slot
invSet = {}
ib[2].scripts.OnEnter(ib[2])
check("hover: the game's tooltip for the slot (SetInventoryItem player 11)", invSet[1] == "player:11" and GameTooltip.owner == ib[2], invSet[1])
local savedInv = GameTooltip.SetInventoryItem
GameTooltip.SetInventoryItem = function() error("not available") end
hyper = nil
GameTooltip.SetHyperlink = function(self, link) hyper = link end
ib[1].scripts.OnEnter(ib[1])
check("hover: falls back to the item link when SetInventoryItem fails", hyper == GEAR[1], hyper)
GameTooltip.SetInventoryItem = savedInv
-- shift-click: the game's modified click with the item's link; a plain click picks the slot for the comparison (QoL 0.7.14)
IsShiftKeyDown = function() return true end
ib[3].scripts.OnClick(ib[3])
check("shift-click: the game's HandleModifiedItemClick with the item link", modClicks[1] == GEAR[16] and CM.gearSlot == nil, modClicks[1])
IsShiftKeyDown = function() return false end
ib[3].scripts.OnClick(ib[3])
check("plain click: picks the slot for the comparison (Main Hand), no chat link", CM.gearSlot == 16 and #modClicks == 1, CM.gearSlot)
d = render("gear"); hs = texts(d, "header")
check("  ...the Compare section names the slot", hs[2] == "- Compare: Main Hand", hs[2])
ib = shownIcons(d)
check("  ...and its icon is marked", ib[3].selected == true and ib[1].selected ~= true and ib[3].sel and ib[3].sel:IsShown())
CM.gearSlot = nil; d = render("gear"); ib = shownIcons(d)
-- the hit areas of the line rows do not cover the icons
local cover = false
for _, r in ipairs(recs(d, "hit")) do
  for _, ic in ipairs(recs(d, "icon")) do
    if r.y < ic.y + ic.h and ic.y < r.y + r.h then cover = true end
  end
end
check("no line hover area sits over the icons", not cover)

-- 3. Layout (V11) --------------------------------------------------------------------------------------------------------------
local W = ns.CHARTOOLKIT_LAYOUT.content
local function layoutOK(dd)
  for _, r in ipairs(dd.layout) do
    if r.x < 0 or r.x + r.w > W + 0.01 or r.w <= 0 then return false, r.kind .. " " .. tostring(r.text) .. " x=" .. r.x .. " w=" .. r.w end
  end
  local t = {}
  for _, r in ipairs(dd.layout) do if r.kind ~= "hit" and r.kind ~= "cell" then t[#t + 1] = r end end
  for i = 1, #t do for j = i + 1, #t do
    local a, bb = t[i], t[j]
    if a.x < bb.x + bb.w and bb.x < a.x + a.w and a.y < bb.y + bb.h and bb.y < a.y + a.h then return false, a.kind .. " '" .. tostring(a.text) .. "' / " .. bb.kind .. " '" .. tostring(bb.text) .. "'" end
  end end
  return true
end
local ok, why = layoutOK(d)
check("layout: inside the content width, no overlaps", ok, why)
-- a full set of 16 items wraps onto a second row without overlaps
for _, s2 in ipairs({ 2, 3, 15, 5, 9, 10, 6, 7, 8, 12, 13, 14, 17 }) do GEAR[s2] = "|cffa335ee|Hitem:1::::::::90:::::|h[Helm]|h|r"; TEX[s2] = 2000 + s2 end
d = render("gear")
ib = shownIcons(d)
local rows = {}
for _, r in ipairs(recs(d, "icon")) do rows[r.y] = true end
local nRows = 0; for _ in pairs(rows) do nRows = nRows + 1 end
check("16 items: 16 icons on two rows", #ib == 16 and nRows == 2, #ib .. " icons, " .. nRows .. " rows")
ok, why = layoutOK(d)
check("  ...layout: inside the content width, no overlaps", ok, why)
for c2 = 1, 2 do c.fontSize = (c2 == 1) and 8 or 16; ok, why = layoutOK(render("gear")); check("  ...text size " .. c.fontSize .. ": no overlaps", ok, why) end
c.fontSize = 11

-- 4. Other tabs, nothing equipped -----------------------------------------------------------------------------------------------
d = render("stats")
check("icons hidden on other tabs", #shownIcons(d) == 0 and #recs(d, "icon") == 0)
local savedGear = GEAR
GEAR = {}
m = CM.Build(c, "gear")
check("nothing equipped: one note line, no icons", m.byKey.gearIcons.kind == "note" and m.byKey.gearIcons.value == "nothing equipped" and #m.byKey.gearIcons.icons == 0)
d = render("gear")
check("  ...and the panel draws it without an error", #shownIcons(d) == 0)
GEAR = savedGear
-- secret values: a secret texture or quality is not used
local savedT, savedQ = GetInventoryItemTexture, GetInventoryItemQuality
issecretvalue = function(v) return v == "SECRET" end
GetInventoryItemTexture = function() return "SECRET" end
GetInventoryItemQuality = function() return "SECRET" end
local okS, mS = pcall(CM.Build, c, "gear")
check("secret texture / quality: not used (question mark, plain border)", okS and mS.byKey.gearIcons.icons[1].tex == nil and mS.byKey.gearIcons.icons[1].color == nil, okS and "" or mS)
GetInventoryItemTexture, GetInventoryItemQuality = savedT, savedQ
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
   .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
