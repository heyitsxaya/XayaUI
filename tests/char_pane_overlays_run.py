# The character pane, end to end (XayaUI_QoL 0.7.19, 0.7.22). Xaya's reports of 2026-11-05: "character pane is broken" (every slot's
# item level twice, a shirt "1", "15" / "25" marks, enchant labels cut off and over the model), then after 0.7.19 "character pane still
# broken" (every enchant label over the 3D model; a large purple item level over each slot plus XayaUI's), "the current invisible
# background is not good", "gemstone display is much too small and doesn't show the gem name socketed", "hovering over the enchant name
# ... should also allow you to see what the enchant does", "embellished items should be hoverable so you can read what the
# embellishment does". Her settings: Character Reskin on, Clean window off, Item level / Enchants / Stat list / Gems on; the Character
# Toolkit on with its Slot Overlays. Her width probe (2026-11-05): "120 px wider (540 -> 660) ... all ok".
# Checks what the player sees, in Blizzard's real window geometry (tests/char_pane_geometry.lua, from the live 12.1.5 XML):
#   A0. (QoL 0.7.24) the default extra width 42 px (380 / 582): widths, what her 12 slots show there (QoL 0.7.28: all drawn, over the
#       model's sides where there is no room beside it; her answer "Over the model");
#   A. her settings with the wider window (on by default; extra width set to 240 px): the window, the model whole and centred, the stats pane placed; one
#      item level per slot (none on the shirt; XayaUI's hidden where another addon's text shows the same number); each slot's block
#      (enchant, embellishment, gems): the whole enchant name, wrapped, every line within its width, inside its band, none over the
#      model or its camera buttons, none over a slot, an item level, the weapon art or another row; gem icons 16 px (12 where 16 does not fit) with the gem's
#      name, the empty socket's type; hover texts from the game's data only; the solid background, also after the window reopens;
#   B. the wider window off (Blizzard's width): the reproduction (the labels lie over the model) and everything else still holding;
#   C. every enchant name of this expansion at the wider width; the extra width at 120 and 300;
#   D. the window's sizing: tabs, the stats pane, combat (nothing changes in combat; the model and main hand go back), the end of combat;
#   E. sockets, the toolkit's marks and the Gear tab's count (QoL 0.7.19); /xui reskin status;
#   F. every combination of the switches; G. V14: off costs nothing.
# Run from the repo root: python3 tests/char_pane_overlays_run.py   Needs: pip install lupa.
# Every item, gem, socket, enchant and tooltip line below is a TEST STAND-IN. Enchant names are real ones from Blizzard's client data
# (docs/reference/content/items.json, build 12.1.5.70783), the ones her 0.7.19 screenshot shows; "+41 Agility/Strength & +27 Armor" is
# her legs' line as she read it (INFERENCE: no space after the "/", the game wrapped there). Which gems she has, which item is
# embellished and the embellishment's text are not known: stand-ins.
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"

PRELUDE = r'''
assert(loadfile(__WORLD__))()
assert(loadfile(__GEOM__))()
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
CM = ns.CharModel
placePane(540)
blizzardSizing()
function PaperDollItemSlotButton_Update(btn) end
function PaperDollFrame_UpdateStats() end
function PanelTemplates_SetTab(frame, id) frame.selectedTab = id end
ENCHANTED_TOOLTIP_LINE = "Enchanted: %s"
EMPTY_SOCKET_PRISMATIC = "Prismatic Socket"
-- the theme (a stand-in for XayaUI/Theme.lua: tokens, T.Col, the resolve listeners)
THEME = { windowBg = { 0.06, 0.06, 0.06, 1 }, paneBg = { 0.04, 0.04, 0.04, 1 }, border = { 0.35, 0.35, 0.4, 1 } }
ns.Theme = { listeners = {} }
local CLS = { ["xui-window"] = { bg = "windowBg", border = "border" }, ["xui-pane"] = { bg = "paneBg", border = "border" } }
function ns.Theme.Col(class, prop, fb) local k = CLS[class] and CLS[class][prop]; local c = k and THEME[k] or fb or { 1, 1, 1, 1 }; return { c[1], c[2], c[3], c[4] } end
function ns.Theme.OnResolve(fn) table.insert(ns.Theme.listeners, fn) end
function ns.Theme.OffResolve(fn) local keep = {}; for _, f in ipairs(ns.Theme.listeners) do if f ~= fn then keep[#keep + 1] = f end end; ns.Theme.listeners = keep end
function ns.Theme.Resolve() for _, f in ipairs(ns.Theme.listeners) do f() end end
-- her gear: item level 334, Hero track; a shirt (item level 1), no tabard
local LIST = {
  { 1, "Helm", 1 }, { 2, "Amulet", 2 }, { 3, "Spaulders", 0 }, { 15, "Cloak", 0 }, { 5, "Chestguard", 0 }, { 4, "Shirt", 0 },
  { 9, "Bracers", 1 }, { 10, "Gloves", 0 }, { 6, "Belt", 1 }, { 7, "Legguards", 0 }, { 8, "Boots", 0 }, { 11, "Ring A", 2 },
  { 12, "Ring B", 2 }, { 13, "Trinket A", 0 }, { 14, "Trinket B", 0 }, { 16, "Glaive A", 1 }, { 17, "Glaive B", 0 } }
ENCH = { [1] = "Enchant Helm - Empowered Rune of Avoidance", [3] = "Enchant Shoulders - Silvermoon's Mending",
  [5] = "Enchant Chest - Mark of the Worldsoul", [6] = "Ancient Hash'ey Battle Art: Ursine's Ironhide",
  [7] = "+41 Agility/Strength & +27 Armor", [8] = "Enchant Boots - Shaladrassil's Roots", [11] = "Enchant Ring - Eyes of the Eagle",
  [12] = "Enchant Ring - Eyes of the Eagle", [16] = "Enchant Weapon - Acuity of the Ren'dorei", [17] = "Enchant Weapon - Acuity of the Ren'dorei" }
GEAR, ITEMS, TIP, UPG = {}, {}, {}, {}
for _, e in ipairs(LIST) do
  local slot, name, sockets = e[1], e[2], e[3]
  GEAR[slot] = ("|cffa335ee|Hitem:%d:%s::::::::90:::::|h[%s]|h|r"):format(1000 + slot, ENCH[slot] and "7000" or "", name)
  ITEMS[name] = { ilvl = (slot == 4) and 1 or 334, loc = "INVTYPE_X", class = (slot == 16 or slot == 17) and 2 or 4,
    stats = { ITEM_MOD_AGILITY_SHORT = 500, EMPTY_SOCKET_PRISMATIC = sockets > 0 and sockets or nil } }
  UPG[name] = { trackString = "Hero", currentLevel = 6, maxLevel = 6 }
  TIP[slot] = {}
  if ENCH[slot] then TIP[slot][1] = { type = 15, leftText = "Enchanted: " .. ENCH[slot] } end
end
-- the purple one: the line carries the epic colour in its text, after the "Enchanted: " (INFERENCE from her 0.7.19 screenshot)
TIP[6] = { { type = 15, leftText = "Enchanted: |cffa335ee" .. ENCH[6] .. "|r" } }
-- an embellished item (stand-in): the bracers, with the game's limit line and an Equip line; a trinket with an Equip line, not embellished
EMB_LINE, EMB_EFFECT = "Unique-Equipped: Embellished (2)", "Equip: Your attacks have a chance to grant 300 Haste for 10 sec."
TIP[9] = { { type = 0, leftText = "|cffffffff" .. EMB_LINE .. "|r" }, { type = 45, leftText = EMB_EFFECT } }
TIP[13] = { { type = 45, leftText = "Equip: Your spells have a chance to deal 5000 Fire damage." } }
-- gems (real names from the client data; which ones she has is not known)
GEMS = { Helm = { 240889 }, Amulet = { 240895, 240905 }, Belt = { 240889 }, ["Ring A"] = { 240895 }, ["Ring B"] = { 240889, 240905 } }
GEM_INFO = { [240889] = { icon = 9001, name = "Flawless Deadly Peridot" }, [240895] = { icon = 9002, name = "Flawless Masterful Amethyst" },
  [240905] = { icon = 9003, name = "Flawless Quick Garnet" } }
-- (empty sockets: the bracers' one, Ring A's second, Glaive A's one)
QCOL = { [0] = { 0.6, 0.6, 0.6 }, [1] = { 1, 1, 1 }, [2] = { 0.1, 1.0, 0.0 }, [3] = { 0.0, 0.4, 1.0 }, [4] = { 0.6, 0.2, 0.9 }, [5] = { 1.0, 0.5, 0.0 } }
C_Item.GetItemQualityColor = function(q) local c = QCOL[q]; if c then return c[1], c[2], c[3], "x" end end
C_Item.GetItemUpgradeInfo = function(link) local name = type(link) == "string" and link:match("%[(.-)%]"); return name and UPG[name] end
GetInventoryItemQuality = function(_, slot) if GEAR[slot] then return slot == 4 and 1 or 4 end end
linkReads = 0
GetInventoryItemLink = function(_, slot) linkReads = linkReads + 1; return GEAR[slot] end
tipReads = 0
C_TooltipInfo.GetInventoryItem = function(_, slot) tipReads = tipReads + 1; if GEAR[slot] then return { lines = TIP[slot] or {} } end end
GameTooltip.SetHyperlink = function(self, l) self.link = l end
timers = {}
C_Timer.After = function(d, fn) timers[#timers + 1] = d; fn() end
assert(loadfile(__CT__))("XayaUI_QoL", ns)
assert(loadfile(__RS__))("XayaUI_QoL", ns)
-- what the player sees on one slot
function shownText(fs) return fs and fs.shown and (fs.alpha or 1) > 0 and fs.text ~= nil and fs.text ~= "" end
function ilvlTexts(name)
  local n, b = 0, _G["Character" .. name]
  if shownText(b.xuiIlvl) then n = n + 1 end
  local ti = ns.CharToolkit_OverlayText(name)
  if ti and ti ~= "" then n = n + 1 end
  return n
end
FOREIGN = {}   -- another addon's item level on a slot (her pane: a large purple number)
function allIlvls(name) local n = ilvlTexts(name); local f = FOREIGN[name]; if f and f.shown then n = n + 1 end; return n end
function marks(name) local _, m = ns.CharToolkit_OverlayText(name); return (m or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
function sockets(name) local b, out = _G["Character" .. name], {}; for _, f in ipairs(b.xuiSockets or {}) do if f.shown then out[#out + 1] = f end end; return out end
-- every visible row of a slot's block (enchant, embellishment, sockets): { frame, its rectangle }
function rowsOf(name)
  local b, out = _G["Character" .. name], {}
  for _, f in ipairs({ b.xuiEnchantRow or false, b.xuiEmbRow or false, unpack(b.xuiSockets or {}) }) do
    if f and f.shown and (f.alpha or 1) > 0 then out[#out + 1] = f end
  end
  return out
end
ALL = {}
for _, n in ipairs(PANE_SLOTS_LEFT) do ALL[#ALL + 1] = n end
for _, n in ipairs(PANE_SLOTS_RIGHT) do ALL[#ALL + 1] = n end
ALL[#ALL + 1] = "MainHandSlot"; ALL[#ALL + 1] = "SecondaryHandSlot"
SLOT_ID = {}
for _, s in ipairs(CM.SLOTS) do SLOT_ID[s[4]] = s[1] end
LEFTSET = {}
for _, n in ipairs(PANE_SLOTS_LEFT) do LEFTSET[n] = true end
GOOD, WARN = { 0.5, 1, 0.5 }, { 1, 0.56, 0.25 }
function near(c, t) return c and math.abs(c[1] - t[1]) < 0.01 and math.abs(c[2] - t[2]) < 0.01 and math.abs(c[3] - t[3]) < 0.01 end
-- the enchant's own name: what is left after "Enchant <slot> - " (the test's own rule, so it does not lean on the code under test)
function SHORT(n) return n:match("^Enchant [^%-]- %- (.+)$") or n end
-- (the parts the code keeps for the tests; empty on code without them, so a check fails instead of the run stopping)
function TXT(f) return (f and f.text and type(f.text) == "table") and table.concat(seenLines(f.text), " ") or "" end
function PARTS() return ns.CharReskinParts or {} end
function WIDE() return ns.CharReskinWide or { } end
function WIDEEV() return (WIDE().ev or { events = {} }).events end
EXPECT = {}
for slot, txt in pairs(ENCH) do EXPECT[slot] = { SHORT(txt), GOOD } end
EXPECT[9] = { "No enchant", WARN }

-- the enchant rows: the whole (short) name, wrapped, every line within its width at 8-10 pt, one colour
function labelProblems()
  local all, colour = {}, {}
  for _, name in ipairs(ALL) do
    local fs, e = _G["Character" .. name].xuiEnchant, EXPECT[SLOT_ID[name]]
    if e then
      local lines = seenLines(fs)
      local seen = table.concat(lines, " ")
      if not shownText(fs) then all[#all + 1] = name .. " missing"
      elseif seen ~= e[1] then all[#all + 1] = name .. ": " .. seen end
      if tostring(fs.text):find("|c", 1, true) or not near(fs.color, e[2]) then colour[#colour + 1] = name end
      local size = fs.font and fs.font[2] or 0
      if size < 8 or size > 10 then all[#all + 1] = name .. " size " .. size end
      for _, l in ipairs(lines) do if #l * CHAR_W(size) > (fs.w or 0) + 0.01 then all[#all + 1] = name .. " too wide: " .. l end end
    elseif shownText(fs) then all[#all + 1] = name .. " (a label where none is due: " .. fs.text .. ")" end
  end
  return all, colour
end
-- every row's rectangle against the window, the model, the camera buttons, the slots, the item levels, the weapon art and each other
function layoutProblems(camShown, wideOn)
  local inset = RECT(CharacterFrame.Inset)
  local head, hands = RECT(CharacterHeadSlot), RECT(CharacterHandsSlot)
  local mid, gut = (head.r + hands.l) / 2, ns.UI_GUTTER
  local model, cam = RECT(CharacterModelScene), RECT(CharacterModelScene.ControlFrame)
  local rows, slots, ilvls, arts = {}, {}, {}, {}
  for _, name in ipairs(ALL) do
    local b = _G["Character" .. name]
    slots[#slots + 1] = { name, RECT(b) }
    if shownText(b.xuiIlvl) then ilvls[#ilvls + 1] = { name, RECT(b.xuiIlvl) } end
    for i, f in ipairs(rowsOf(name)) do rows[#rows + 1] = { name .. "#" .. i, RECT(f), b, name, f } end
  end
  for _, k in ipairs({ "MainHandSlot", "SecondaryHandSlot", "MainHandSide", "SecondaryHandSide" }) do arts[#arts + 1] = { k .. " art", RECT(ART[k]) } end
  local out, overModel = {}, {}
  local lastL, lastR = RECT(CharacterWristSlot), RECT(CharacterTrinket1Slot)
  for _, R in ipairs(rows) do
    local id, r, b, name, f = R[1], R[2], R[3], R[4], R[5]
    local sr = RECT(b)
    if not r then out[#out + 1] = id .. " (no rectangle)"
    else
      if name == "MainHandSlot" or name == "SecondaryHandSlot" then
        local top = (name == "MainHandSlot" and lastL or lastR).b - 2
        if r.t > top + 0.01 or r.b < inset.b - 0.01 then out[#out + 1] = id .. " outside its band " .. rstr(r) end
      elseif r.t > sr.t + 2.01 or r.b < sr.b - 2.01 then out[#out + 1] = id .. " outside its band " .. rstr(r) end
      if not wideOn then
        if LEFTSET[name] or name == "MainHandSlot" then if r.r > mid - gut / 2 + 0.01 then out[#out + 1] = id .. " past the middle " .. rstr(r) end
        elseif r.l < mid + gut / 2 - 0.01 then out[#out + 1] = id .. " past the middle " .. rstr(r) end
      end
      if not inside(r, inset) then out[#out + 1] = id .. " outside the window " .. rstr(r) end
      if overlaps(r, model) then overModel[#overModel + 1] = id .. " " .. rstr(r) end
      if camShown and overlaps(r, cam) then out[#out + 1] = id .. " over the camera buttons " .. rstr(r) end
      if f.text and f.text.shown then
        local tr = RECT(f.text)
        if tr and not inside(tr, r) and f.text.text ~= "" then out[#out + 1] = id .. " text outside its row" end
      end
    end
  end
  for i = 1, #rows do for j = i + 1, #rows do if overlaps(rows[i][2], rows[j][2]) then out[#out + 1] = rows[i][1] .. " / " .. rows[j][1] end end end
  for _, R in ipairs(rows) do
    for _, other in ipairs({ slots, ilvls, arts }) do
      for _, o in ipairs(other) do if overlaps(R[2], o[2]) then out[#out + 1] = R[1] .. " / " .. o[1] end end
    end
  end
  return out, overModel, #rows
end
function list(t, k) return t[1] and (table.concat(t, "; ", 1, math.min(#t, k or 6)) .. (#t > (k or 6) and (" (+" .. (#t - (k or 6)) .. " more)") or "")) or "" end
'''

def lua_with(prelude_extra=""):
    lua = LuaRuntime()
    src = (PRELUDE + prelude_extra).replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__GEOM__", P("tests/char_pane_geometry.lua")) \
        .replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua")) \
        .replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")) \
        .replace("__RS__", P("XayaUI_QoL/CharacterReskin.lua"))
    lua.execute(src)
    return lua

# every enchant name of this expansion (Blizzard's client data, docs/reference/content/items.json: Item Enhancements, classID 8) by slot:
# subclass 0 helm, 2 shoulders, 4 chest, 9 boots, 10 rings, 11 weapons (not the profession-tool ones), 14 the Hash'ey battle arts (on the
# waist, as in her screenshot). Armor kits and spellthreads are left out: their tooltip line is the stat text, not the item's name.
_items = json.load(open(os.path.join(ROOT, "docs", "reference", "content", "items.json"), encoding="utf-8"))["data"]
_slots = {0: [1], 2: [3], 4: [5], 9: [8], 10: [11, 12], 11: [16, 17], 14: [6]}
_names = {}
for it in _items:
    if it["classID"] != 8 or it["subclassID"] not in _slots: continue
    nm = it["name"]
    if it["subclassID"] == 11 and not nm.startswith("Enchant Weapon"): continue
    if it["subclassID"] == 14 and "Battle Art" not in nm: continue
    _names[nm] = _slots[it["subclassID"]]
ALLNAMES = "ALLNAMES = {" + ", ".join('{ name = %s, slots = { %s } }' % (json.dumps(n), ", ".join(str(x) for x in sl)) for n, sl in sorted(_names.items())) + "}\n"

TOTAL_N, TOTAL_F = 0, 0
def run(lua, code):
    global TOTAL_N, TOTAL_F
    lua.execute(code)
    TOTAL_N += lua.eval("n"); TOTAL_F += lua.eval("fails")

lua = lua_with(ALLNAMES + r'''
local tk = ns.CharToolkit_Cfg()
tk.enchantSlots = { [1] = true, [3] = true, [5] = true, [7] = true, [8] = true, [9] = true, [11] = true, [12] = true, [16] = true, [17] = true }
tk.enchantSlotsSet = true   -- she ticked her wrist too: "No enchant" there
''')
run(lua, r'''
ns.FireReady()
rc, tk = ns.CharReskin_Cfg(), ns.CharToolkit_Cfg()
-- her settings: reskin on, Clean window off, item level, enchants, gems, stat list on (the wider window: its default, on);
-- the toolkit and its slot overlays on
rc.enabled, rc.chrome, rc.ilvl, rc.enchants, rc.gems, rc.stats = true, false, true, true, true, true
tk.enabled, tk.overlays, tk.panel = true, true, false
CharacterFrame:Show(); PaperDollFrame:Show()
ns.CharToolkit_Apply(); ns.CharReskin_Apply()
CharacterModelScene.ControlFrame:Hide()

-- A0. (QoL 0.7.24) the default extra width: 42 px (Xaya 2026-11-06: "Push to 380px before stats pane and request feedback
-- confirmation"; Blizzard's PANEL_DEFAULT_WIDTH 338, CHARACTERFRAME_EXPANDED_WIDTH 540). What her 12 slots' blocks show there.
do
  local cf = CharacterFrame
  local w582 = cf.w
  STATS_OPEN = false; cf:UpdateSize()
  local w380 = cf.w
  STATS_OPEN = true; cf:UpdateSize()
  check("A0. the default extra width is 42 px: the window is 380 wide without the stats pane (Blizzard 338) and 582 with it (Blizzard 540)",
    ns.CHARRESKIN_DEFAULTS.widePx == 42 and rc.widePx == 42 and w380 == 380 and w582 == 582 and cf.w == 582, w380 .. " / " .. w582)
  local model, head, hands = RECT(CharacterModelScene), RECT(CharacterHeadSlot), RECT(CharacterHandsSlot)
  check("(guard, V11)   ...the model keeps its width (231 x 320) and sits centred between the slot columns (28 / 29 px each side)",
    math.abs(model.r - model.l - 231) < 0.01 and math.abs((model.l - head.r) - (hands.l - model.r)) <= 1.01 and model.l - head.r >= 28,
    rstr(model) .. " head.r " .. head.r .. " hands.l " .. hands.l)
  local out, overModel, nrows = layoutProblems(false, true)
  -- (QoL 0.7.28; Xaya at 0.7.27: "character pane now missing all previous information around gems, enchangs, embellishments, etc"; her
  -- answer "Over the model"; REQUEST-LOG #69 / #71) at 380 the blocks beside the head ... rings run toward the middle, over the model's
  -- sides, as at Blizzard's width; before, none was allowed there and they were not drawn
  check("A0. at 380 / 582 the blocks with no room beside the model run over its sides (her answer \"Over the model\"; 0.7.24-0.7.27 kept them off it and hid them)",
    #overModel > 0, nrows)
  check("(guard, V11)   ...each row inside its slot's band and the window; no two overlap; none covers a slot, an item level or the weapon art", #out == 0, list(out))
  CharacterModelScene.ControlFrame:Show()
  local outC = layoutProblems(true, true)
  check("(guard, V11)   ...with the camera buttons shown: none meets them", #outC == 0, list(outC))
  CharacterModelScene.ControlFrame:Hide()
  -- what she sees on her 12 slots with a block (enchant, embellishment, gems): drawn whole, cut at a word, or not drawn (no room)
  local HER12 = { "HeadSlot", "NeckSlot", "ShoulderSlot", "ChestSlot", "WristSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot",
    "Finger1Slot", "MainHandSlot", "SecondaryHandSlot" }
  local whole, cut, none = {}, {}, {}
  for _, name in ipairs(HER12) do
    local L = _G["Character" .. name].xuiLabel
    if not L or #rowsOf(name) == 0 then none[#none + 1] = name elseif L.cut then cut[#cut + 1] = name else whole[#whole + 1] = name end
  end
  A0_COUNTS = ("whole %d (%s); cut %d (%s); not drawn %d (%s)"):format(#whole, table.concat(whole, ","), #cut, table.concat(cut, ","), #none, table.concat(none, ","))
  check("A0. her 12 slots at 380: every block is drawn (QoL 0.7.28: none hidden for lack of room; at 0.7.24-0.7.27 ten were not drawn), at most cut at a word",
    #none == 0 and #whole + #cut == 12, A0_COUNTS)
  local mhs = sockets("MainHandSlot")
  check("  ...the main hand's empty socket shows at 16 px with its type (her answer: \"16 px\")", #mhs == 1 and mhs[1].bg.w == 16 and mhs[1].bg.h == 16
    and TXT(mhs[1]) == "Prismatic Socket", #mhs == 1 and (mhs[1].bg.w .. " " .. TXT(mhs[1])) or #mhs)
end
-- the rest of A: the extra width set to 240 (the room every block of hers needs; the 0.7.22 checks)
rc.widePx = 240; ns.CharReskin_Apply()

-- A. her settings, the wider window ----------------------------------------------------------------------------------------------
local cf, inset, model = CharacterFrame, RECT(CharacterFrame.Inset), RECT(CharacterModelScene)
local win, head, hands, stats = RECT(cf), RECT(CharacterHeadSlot), RECT(CharacterHandsSlot), RECT(cf.InsetRight)
check("A. the wider window is on by default with the reskin; extra width set to 240: 240 px wider on the Character tab with the stats pane (540 -> 780), the game asked to place its panels again",
  rc.wide == true and cf.w == 780 and panelCalls >= 1, cf.w .. " / " .. panelCalls)
check("  ...the model keeps its width (231 x 320), whole inside the window, centred between the slot columns (127 / 128 px each side)",
  math.abs(model.r - model.l - 231) < 0.01 and math.abs(model.t - model.b - 320) < 0.01 and inside(model, inset)
  and math.abs((model.l - head.r) - (hands.l - model.r)) <= 1.01 and model.l - head.r >= 120, rstr(model) .. " head.r " .. head.r .. " hands.l " .. hands.l)
local mh, oh = RECT(CharacterMainHandSlot), RECT(CharacterSecondaryHandSlot)
check("  ...the weapons centred under the model (moved 120 px, as the probe moved them by half); the right column and the stats pane moved out with the Inset",
  math.abs(mh.l - (win.l + 130 + 120)) < 0.01 and math.abs(((mh.l + oh.r) / 2) - ((model.l + model.r) / 2)) <= 2 and math.abs(hands.r - (inset.r - 4)) < 0.01
  and math.abs(inset.r - (win.l + 338 - 6 + 240)) < 0.01 and stats and stats.l >= inset.r and inside(stats, win),
  rstr(mh) .. " / " .. rstr(stats))
-- one item level per slot
local bad = {}
for _, name in ipairs(ALL) do
  local want = (GEAR[SLOT_ID[name]] and name ~= "ShirtSlot") and 1 or 0
  if ilvlTexts(name) ~= want then bad[#bad + 1] = name .. "=" .. ilvlTexts(name) end
end
check("A. XayaUI draws exactly one item level on each equipped slot, none on the shirt (her 0.7.18 pane: a shirt \"1\")", #bad == 0, table.concat(bad, " "))
-- the enchant rows
local lp, colour = labelProblems()
check("A. every enchanted slot shows its enchant's whole name (without \"Enchant <slot> - \"), word-wrapped, every line within its width at 8-10 pt, nothing cut",
  #lp == 0, list(lp))
check("  ...in one colour: green, or orange for \"No enchant\" (her 0.7.18 pane: the Hash'ey one in purple)", #colour == 0, table.concat(colour, " "))
local out, overModel, nrows = layoutProblems(false, true)
check("A. no row of any slot's block (enchant, embellishment, gem) lies over the 3D model (her report: every label over the model's body)",
  nrows > 15 and #overModel == 0, nrows .. " rows; " .. list(overModel))
check("  ...each row inside its slot's band (the weapons' under the side columns), inside the window; no two overlap; none covers a slot, an item level or the weapon art",
  #out == 0, list(out))
CharacterModelScene.ControlFrame:Show()
local out2 = layoutProblems(true, true)
local hid = {}
for _, name in ipairs(ALL) do local f = _G["Character" .. name].xuiEnchantRow; if f and f.shown and (f.alpha or 1) == 0 then hid[#hid + 1] = name end end
check("  ...with the camera buttons shown (mouse over the model): none meets them, and none has to hide", #out2 == 0 and #hid == 0, list(out2) .. table.concat(hid, ","))
CharacterModelScene.ControlFrame:Hide()
-- gems: bigger icons, the gem's name, the empty socket's type
local nb, ra = sockets("NeckSlot"), sockets("Finger0Slot")
local function icon(f) return f and f.bg and f.bg.w or 0 end
local small = {}
for _, name in ipairs(ALL) do for i, f in ipairs(sockets(name)) do if icon(f) < 12 or (f.bg.h or 0) < 12 then small[#small + 1] = name .. "#" .. i .. " " .. icon(f) end end end
-- (QoL 0.7.24; her answer 2026-11-06: "16 px") 16 px where the block fits it, 12 only where 16 does not fit (her rings: three rows each)
local sizesBy = {}
for _, name in ipairs(ALL) do for _, f in ipairs(sockets(name)) do sizesBy[#sizesBy + 1] = name .. "=" .. icon(f) end end
local SIXTEEN = { HeadSlot = true, NeckSlot = true, WristSlot = true, WaistSlot = true, MainHandSlot = true }
local wrong = {}
for _, name in ipairs(ALL) do for _, f in ipairs(sockets(name)) do
  local want = SIXTEEN[name] and 16 or ((name == "Finger0Slot" or name == "Finger1Slot") and 12 or -1)
  if icon(f) ~= want or (f.bg.h or 0) ~= want then wrong[#wrong + 1] = name .. "=" .. icon(f) end
end end
check("A. gem / socket icons 16 px (her answer \"16 px\"; the game's own is 11): head, neck, wrist, waist, main hand; 12 px only on the two rings, where three rows do not fit at 16",
  #small == 0 and #wrong == 0 and #sizesBy == 10, table.concat(wrong, " ") .. " / " .. table.concat(sizesBy, " "))
check("  ...a name line per socketed gem: the neck's two (\"Flawless Masterful Amethyst\", \"Flawless Quick Garnet\"), with their icons",
  #nb == 2 and TXT(nb[1]) == "Flawless Masterful Amethyst" and TXT(nb[2]) == "Flawless Quick Garnet"
  and nb[1].gem.shown and nb[1].gem.tex == 9002 and nb[2].gem.tex == 9003, #nb == 2 and (TXT(nb[1]) .. " | " .. TXT(nb[2])) or #nb)
check("  ...an empty socket: the game's string for its type (\"Prismatic Socket\") in orange, no gem icon (Ring A's second)",
  #ra == 2 and TXT(ra[2]) == "Prismatic Socket" and near(ra[2].text.color, WARN) and not ra[2].gem.shown, #ra == 2 and TXT(ra[2]) or #ra)
-- a gem whose name the game has not loaded yet: the icon only, the name when the item info arrives (GET_ITEM_INFO_RECEIVED)
local saved = GEM_INFO[240889].name
GEM_INFO[240889].name = nil
ns.CharReskin_Apply()
local hb = sockets("HeadSlot")[1]
local before = hb and hb.text and hb.text.text
GEM_INFO[240889].name = saved
fire("GET_ITEM_INFO_RECEIVED", 240889, true)
check("  ...a gem name not loaded yet: its icon only (nothing guessed); filled in when the game sends the item (GET_ITEM_INFO_RECEIVED)",
  before == "" and hb.gem.shown and TXT(sockets("HeadSlot")[1]) == saved, tostring(before) .. " -> " .. TXT(sockets("HeadSlot")[1]))
-- hover: what the enchant does, as the game gives it; nothing invented
local function hover(f) GameTooltip.lines, GameTooltip.link = {}, nil; if f and f.scripts.OnEnter then f.scripts.OnEnter(f) end; return table.concat(GameTooltip.lines or {}, " | ") end
local legs, ring = hover(CharacterLegsSlot.xuiEnchantRow), hover(CharacterFinger0Slot.xuiEnchantRow)
check("A. hover the legs' enchant: the game's line with its stats, nothing added (\"Enchanted: +41 Agility/Strength & +27 Armor\")",
  legs == "Enchanted: +41 Agility/Strength & +27 Armor", legs)
check("  ...hover a ring's: the whole line, and that the game gives no effect text for it (no text invented)",
  ring == "Enchanted: Enchant Ring - Eyes of the Eagle | Effect text not given by the game.", ring)
hover(nb[1])
check("  ...hover a gem's name: the gem's own tooltip (its link)", TXT(nb[1]) ~= "" and tostring(GameTooltip.link):find("Flawless Masterful Amethyst", 1, true) ~= nil, tostring(GameTooltip.link))
check("  ...the rows take the mouse only over themselves (each row's rectangle is outside every slot: checked above); the slot keeps its clicks",
  CharacterLegsSlot.xuiEnchantRow ~= nil and CharacterLegsSlot.xuiEnchantRow.parent == CharacterLegsSlot and not overlaps(RECT(CharacterLegsSlot.xuiEnchantRow), RECT(CharacterLegsSlot)))
-- the embellishment
local emb = CharacterWristSlot.xuiEmbRow
local embT = emb and emb.shown and emb.text.text
local eh = emb and hover(emb) or ""
local plain = {}
for _, name in ipairs(ALL) do local f = _G["Character" .. name].xuiEmbRow; if name ~= "WristSlot" and f and f.shown then plain[#plain + 1] = name end end
-- (QoL 0.7.24; Xaya: "put Embellished - Name: ______ and a line break before the description of the embellishment. Detect if it is (1/2)
-- or (2/2)"; "pane line says embellished (2/2): name — the rest goes in tooltip")
check("A. the embellished bracers' pane line reads exactly \"Embellished (1/2): Bracers\" (worn / the game's own limit; the item's name); no other item shows one",
  embT == "Embellished (1/2): Bracers" and #plain == 0, tostring(embT) .. " / " .. table.concat(plain, " "))
check("  ...hover it: \"Embellished - Name: Bracers\", then on the next line the description as the game gives it (nothing else)",
  eh == "Embellished - Name: Bracers | " .. EMB_EFFECT, eh)
TIP[12] = { { type = 0, leftText = EMB_LINE }, { type = 45, leftText = EMB_EFFECT } }   -- a second embellished item (Ring B): 2 of 2
ns.CharReskin_Apply()
local emb2 = CharacterWristSlot.xuiEmbRow
check("  ...two embellished items worn: \"Embellished (2/2): <name>\" on each", emb2 and emb2.text.text == "Embellished (2/2): Bracers"
  and CharacterFinger1Slot.xuiEmbRow and CharacterFinger1Slot.xuiEmbRow.shown and CharacterFinger1Slot.xuiEmbRow.text.text == "Embellished (2/2): Ring B",
  tostring(emb2 and emb2.text.text) .. " / " .. tostring(CharacterFinger1Slot.xuiEmbRow and CharacterFinger1Slot.xuiEmbRow.text.text))
TIP[12] = { { type = 15, leftText = "Enchanted: " .. ENCH[12] } }
ns.CharReskin_Apply()
-- the background
local own = PARTS()
local bg = own.bg or {}
check("A. the background: solid (95%), the theme's window colour, covering the whole window (the stats pane and the wider area) with Clean window off",
  bg and bg.shown and bg.color and near(bg.color, THEME.windowBg) and math.abs(bg.color[4] - 0.95) < 0.001 and RECT(bg).l == win.l and RECT(bg).r == win.r
  and RECT(bg).t == win.t and RECT(bg).b == win.b, bg and rstr(RECT(bg)))
CharacterFrame:Hide(); CharacterFrame:Show()
check("  ...still there after the window is closed and opened again (her \"invisible background\": each reopen hid it)", bg.shown == true)
rc.chrome = true; ns.CharReskin_Apply(); CharacterFrame:Hide(); CharacterFrame:Show()
local edges = own.edges or {}
check("  ...Clean window on: after a reopen ours is shown again (background, border, the stats pane's fill in the theme's pane colour)",
  bg.shown and edges[1] and edges[1].shown and own.stats and own.stats.shown and near(own.stats.color, THEME.paneBg))
rc.bgAlpha = 0.7; ns.CharReskin_Apply()
check("  ...its opacity follows the page's \"Background opacity\" (70%)", bg.color ~= nil and math.abs(bg.color[4] - 0.7) < 0.001, bg.color and bg.color[4])
rc.enabled = false; ns.CharReskin_Apply(); LISTEN0 = #ns.Theme.listeners; rc.enabled = true; ns.CharReskin_Apply()
THEME.windowBg = { 0.2, 0.1, 0.3, 1 }; ns.Theme.Resolve()
check("  ...a theme change repaints it (one listener, there only while the reskin is on)", near(bg.color, THEME.windowBg) and #ns.Theme.listeners == LISTEN0 + 1,
  #ns.Theme.listeners .. " / " .. LISTEN0)
THEME.windowBg = { 0.06, 0.06, 0.06, 1 }; rc.bgAlpha, rc.chrome = 0.95, false; ns.CharReskin_Apply()
-- one item level per slot when another addon draws its own (her 0.7.19 pane: a large purple number plus ours)
for _, name in ipairs(ALL) do
  local id = SLOT_ID[name]
  if GEAR[id] and id ~= 4 then
    local f = mk("FS"); f.text = "|cffa335ee334|r"; f.shown = true; f.debugName = "OtherAddon" .. name .. "ItemLevel"; addRegion(_G["Character" .. name], f); FOREIGN[name] = f
  end
end
ns.CharReskin_Apply()
local two = {}
for _, name in ipairs(ALL) do local want = (GEAR[SLOT_ID[name]] and name ~= "ShirtSlot") and 1 or 0; if allIlvls(name) ~= want then two[#two + 1] = name .. "=" .. allIlvls(name) end end
check("A. another addon's item level on every slot, the same number: XayaUI's stays hidden, ONE number per slot (the other addon's text untouched)",
  #two == 0 and FOREIGN.HeadSlot.shown and FOREIGN.HeadSlot.text == "|cffa335ee334|r", table.concat(two, " "))
FOREIGN.Finger0Slot.text = "335"; FOREIGN.NeckSlot.shown = false
ns.CharReskin_Apply()
check("  ...a different number there (Ring A): XayaUI's shown; none there (the neck): XayaUI's shown", shownText(CharacterFinger0Slot.xuiIlvl) and shownText(CharacterNeckSlot.xuiIlvl)
  and not shownText(CharacterHeadSlot.xuiIlvl))
-- another addon that writes its number after XayaUI (its hook runs later): looked at again on the next frame
FOREIGN.NeckSlot.shown = true
timers = {}
PaperDollItemSlotButton_Update(CharacterNeckSlot)
check("  ...an addon that writes after XayaUI: checked again on the next frame (one timer), then hidden", not shownText(CharacterNeckSlot.xuiIlvl) and #timers >= 1, #timers)
printed = {}
ns.RunCommand("reskin", "status")
local said = table.concat(printed, "\n")
check("  .../xui reskin status names the other text (frame name) and says on how many slots XayaUI's is hidden and how to keep one",
  said:find("OtherAddonHeadSlotItemLevel", 1, true) ~= nil and said:find("Head 334", 1, true) ~= nil and said:find("hidden on 15 slot", 1, true) ~= nil
  and said:find("turn the other addon's item level off", 1, true) ~= nil and not said:find("Eyes of the Eagle", 1, true), said)
for _, f in pairs(FOREIGN) do f.shown = false end
FOREIGN = {}
ns.CharReskin_Apply()

-- B. the wider window off: Blizzard's width -----------------------------------------------------------------------------------------
local wasW = CharacterFrame.w
rc.wide = false; ns.CharReskin_Apply()
model = RECT(CharacterModelScene)
check("B. wider window switched off (from 780): Blizzard's width back (540), the model and the main hand back at Blizzard's places (52, -66 / 130, 16)",
  wasW == 780 and CharacterFrame.w == 540 and math.abs(model.l - (RECT(CharacterFrame).l + 52)) < 0.01 and math.abs(RECT(CharacterMainHandSlot).l - (RECT(CharacterFrame).l + 130)) < 0.01,
  CharacterFrame.w .. " " .. rstr(model))
local lpB = labelProblems()
local outB, overB = layoutProblems(false, false)
check("B. the reproduction (her report): at Blizzard's width the enchant rows lie over the model (the columns are 7-8 px from it)", #overB > 0, #overB)
-- (QoL 0.7.24) the wrist's block (No enchant, "Embellished (1/2): Bracers", its socket) no longer fits beside the weapons at Blizzard's
-- width (59 px): its pane line now carries the item's name, so it is not drawn there (never cut in a word or over the weapons)
local lpB2 = {}
for _, p in ipairs(lpB) do if p ~= "WristSlot missing" then lpB2[#lpB2 + 1] = p end end
check("  ...everything else holds: the whole names, wrapped; every row inside its band, its side of the window, no overlaps (the wrist's block is not drawn: it does not fit)",
  #lpB2 == 0 and #outB == 0 and #rowsOf("WristSlot") == 0, list(lpB2) .. list(outB) .. " wrist rows " .. #rowsOf("WristSlot"))
CharacterModelScene.ControlFrame:Show()
local outB2 = layoutProblems(true, false)
local hidB = {}
for _, name in ipairs(ALL) do local f = _G["Character" .. name].xuiEnchantRow; if f and f.text.text ~= "" and (f.alpha or 1) == 0 then hidB[#hidB + 1] = name end end
check("  ...with the camera buttons shown none meets them: the blocks that cannot clear them hide while they show (the head and waist rows)",
  #outB2 == 0 and #hidB >= 1, list(outB2) .. " hidden: " .. table.concat(hidB, ","))
CharacterModelScene.ControlFrame:Hide()
rc.wide = true; ns.CharReskin_Apply()

-- C. every enchant name of this expansion, and the extra width at 120 and 300 -------------------------------------------------------
local savedTIP, badC, sizes = TIP, {}, {}
for _, e in ipairs(ALLNAMES) do
  TIP = {}
  for k, v in pairs(savedTIP) do TIP[k] = v end
  for _, slot in ipairs(e.slots) do TIP[slot] = { { type = 15, leftText = "Enchanted: " .. e.name } } end
  ns.CharReskin_Apply()
  for _, slot in ipairs(e.slots) do
    local name
    for n2, id in pairs(SLOT_ID) do if id == slot then name = n2 end end
    local fs = _G["Character" .. name].xuiEnchant
    local seen = table.concat(seenLines(fs), " ")
    if not shownText(fs) or seen ~= SHORT(e.name) then badC[#badC + 1] = name .. ": " .. seen end
    for _, l in ipairs(seenLines(fs)) do if #l * CHAR_W(fs.font[2]) > fs.w + 0.01 then badC[#badC + 1] = name .. " line too wide: " .. l end end
    sizes[fs.font[2]] = (sizes[fs.font[2]] or 0) + 1
  end
  local p1, o1 = layoutProblems(false, true)
  for _, x in ipairs(p1) do badC[#badC + 1] = e.name .. ": " .. x end
  for _, x in ipairs(o1) do badC[#badC + 1] = e.name .. " over the model: " .. x end
end
TIP = savedTIP; ns.CharReskin_Apply()
check(("C. every enchant name of this expansion in the client data (%d) on its slots, at the wider window: the whole name, every line within its width, nothing over the model, the layout holds (10 pt %d, 9 pt %d, 8 pt %d)")
  :format(#ALLNAMES, sizes[10] or 0, sizes[9] or 0, sizes[8] or 0), #badC == 0, list(badC, 2))
for _, px in ipairs({ 120, 300 }) do
  rc.widePx = px; ns.CharReskin_Apply()
  local o, ov, nr = layoutProblems(false, true)
  local cut = ns.CharReskinDiag.cut
  check(("C. extra width %d px (window %d): no row over the model, inside bands, no overlaps (%d rows; %d blocks cut to fit at a word)"):format(px, CharacterFrame.w, nr, cut),
    CharacterFrame.w == 540 + px and #o == 0 and #ov == 0, list(o) .. list(ov))
end
rc.widePx = 240; ns.CharReskin_Apply()
check("  ...back to 240: 780 wide, the base width remembered (not widened twice)", CharacterFrame.w == 780, CharacterFrame.w)

-- D. the window's sizing: tabs, the stats pane, combat -----------------------------------------------------------------------------
cf.activeSubframe = "ReputationFrame"; PaperDollFrame:Hide(); cf:UpdateSize()
local otherTab = cf.w
cf.activeSubframe = "PaperDollFrame"; cf:UpdateSize(); PaperDollFrame:Show()
check("D. another tab: Blizzard's width (338); back on the Character tab: wider again (780)", otherTab == 338 and cf.w == 780
  and ns.CharReskin_WideOn ~= nil and ns.CharReskin_WideOn(), otherTab .. " / " .. cf.w)
STATS_OPEN = false; cf:UpdateSize()
check("  ...the stats pane closed (Blizzard 338): 578; opened again: 780", cf.w == 578 and (function() STATS_OPEN = true; cf:UpdateSize(); return cf.w == 780 end)(), cf.w)
combat = true
local evBefore = WIDEEV().PLAYER_REGEN_ENABLED
STATS_OPEN = false; cf:UpdateSize()
local mm = RECT(CharacterModelScene)
check("D. in combat Blizzard puts its width back (338): XayaUI does not size the window; the model and the main hand go back to Blizzard's places; it waits for the end of combat",
  cf.w == 338 and math.abs(mm.l - (RECT(cf).l + 52)) < 0.01 and math.abs(RECT(CharacterMainHandSlot).l - (RECT(cf).l + 130)) < 0.01
  and not evBefore and WIDEEV().PLAYER_REGEN_ENABLED == true, cf.w .. " " .. rstr(mm))
local o3, ov3 = layoutProblems(false, false)
check("  ...meanwhile the blocks laid out for Blizzard's width (inside their bands, no overlaps)", #o3 == 0, list(o3))
combat = false
fire("PLAYER_REGEN_ENABLED")
check("  ...combat ends: wider again (338 + 240 = 578) and it stops listening for the end of combat", cf.w == 578 and WIDE().ev ~= nil and next(WIDEEV()) == nil, cf.w)
STATS_OPEN = true; cf:UpdateSize()
combat = true; rc.wide = false; ns.CharReskin_Apply()
local inCombatW = cf.w
combat = false; fire("PLAYER_REGEN_ENABLED")
check("D. switched off in combat: nothing changes until the fight ends (780), then Blizzard's width and places", inCombatW == 780 and cf.w == 540 and math.abs(RECT(CharacterModelScene).l - (RECT(cf).l + 52)) < 0.01, cf.w)
rc.wide = true; ns.CharReskin_Apply()
check("  ...wider window on: 780 again", cf.w == 780, cf.w)

-- E. sockets and the toolkit's marks (QoL 0.7.19) --------------------------------------------------------------------------------
local m = {}
for _, name in ipairs(ALL) do if marks(name):find("S", 1, true) then m[#m + 1] = name end end
check("E. while the reskin draws the sockets the toolkit leaves its socket mark out (one per slot)", #m == 0, table.concat(m, " "))
rc.gems = false; ns.CharReskin_Apply()
check("  ...gems off: the reskin's sockets go, and the toolkit's mark counts only sockets without a gem: neck (both filled) none (her pane: \"25\" = 2S)",
  #sockets("NeckSlot") == 0 and marks("NeckSlot") == "", marks("NeckSlot"))
check("  ...Ring A one empty: 1S; Ring B (both filled) none; the bracers' empty one: 1S", marks("Finger0Slot"):find("1S", 1, true) ~= nil
  and not marks("Finger1Slot"):find("S", 1, true) and marks("WristSlot"):find("1S", 1, true) ~= nil,
  marks("Finger0Slot") .. " | " .. marks("Finger1Slot") .. " | " .. marks("WristSlot"))
rc.gems = true; ns.CharReskin_Apply()
CM.gearSlot = 2
local gm = ns.CharToolkit_Model("gear")
local function grow(key) for _, r in ipairs(gm) do if r.key == key then return r end end end
local amulet = grow("gc_sockets")
CM.gearSlot = nil
gm = ns.CharToolkit_Model("stats")   -- (QoL 0.7.23: the Summary is on the Stats tab, Character Stats > Gear Summary)
local sum = grow("gearSum_sockets")
check("E. Gear tab: the amulet (both sockets filled) has no Empty sockets row; the Gear Summary (Stats tab since QoL 0.7.23) counts 3 (bracers, Ring A, Glaive A)",
  amulet == nil and sum and sum.cells[1] == "3", (amulet and table.concat(amulet.cells, "|") or "none") .. " / " .. (sum and sum.cells[1] or "none"))
-- the window open but a slot without a position on the first pass (INFERENCE: possible in the frame it opens): laid out on a retry
local realGetLeft, realAfter, nextFrame = CharacterHeadSlot.GetLeft, C_Timer.After, false
CharacterHeadSlot.GetLeft = function(self) if not nextFrame then return nil end; return realGetLeft(self) end
C_Timer.After = function(d, fn) nextFrame = true; return realAfter(d, fn) end
ns.CharReskin_Apply()
CharacterHeadSlot.GetLeft, C_Timer.After = realGetLeft, realAfter
check("E. the slots with no position yet when the window opens: the blocks are laid out on the next frame (the whole name)",
  nextFrame and table.concat(seenLines(CharacterHeadSlot.xuiEnchant), " ") == SHORT(ENCH[1]) and table.concat(seenLines(CharacterFeetSlot.xuiEnchant), " ") == SHORT(ENCH[8]),
  table.concat(seenLines(CharacterHeadSlot.xuiEnchant), " "))

-- F. every combination of the switches: one item level, one socket mark, one enchant mark per slot -------------------------------
local combos, badc = 0, {}
for _, ron in ipairs({ false, true }) do for _, ril in ipairs({ false, true }) do for _, ren in ipairs({ false, true }) do for _, rge in ipairs({ false, true }) do
for _, ton in ipairs({ false, true }) do for _, tov in ipairs({ false, true }) do for _, rwi in ipairs({ false, true }) do
  rc.enabled, rc.ilvl, rc.enchants, rc.gems, rc.wide = ron, ril, ren, rge, rwi
  tk.enabled, tk.overlays = ton, tov
  ns.CharReskin_Apply(); ns.CharToolkit_Apply(); ns.CharToolkit_UpdateOverlays()
  combos = combos + 1
  local wantW = (ron and rwi) and 780 or 540
  if CharacterFrame.w ~= wantW then badc[#badc + 1] = ("width %d (want %d) r%s w%s"):format(CharacterFrame.w, wantW, tostring(ron), tostring(rwi)) end
  for _, name in ipairs(ALL) do
    local slot = SLOT_ID[name]
    local drawer = (ron and ril) or (ton and tov)
    local want = (drawer and GEAR[slot] and slot ~= 4 and slot ~= 19) and 1 or 0
    local il = ilvlTexts(name)
    local sockMarks = (#sockets(name) > 0 and 1 or 0) + (marks(name):find("%dS") and 1 or 0)
    local b = _G["Character" .. name]
    local enchMarks = (shownText(b.xuiEnchant) and 1 or 0) + (marks(name):find("E") and 1 or 0)
    if il ~= want or sockMarks > 1 or enchMarks > 1 then
      badc[#badc + 1] = ("%s r%s/%s/%s/%s t%s/%s: ilvl %d (want %d), sockets %d, enchant %d"):format(name, tostring(ron), tostring(ril), tostring(ren),
        tostring(rge), tostring(ton), tostring(tov), il, want, sockMarks, enchMarks)
    end
  end
  if ron and rwi then local _, ov = layoutProblems(false, true); for _, x in ipairs(ov) do badc[#badc + 1] = "over the model: " .. x end end
end end end end end end end
check(("F. every combination of the reskin's (with the wider window) and the toolkit's switches (%d): one item level per slot (none on the shirt), at most one socket and one enchant mark, the width as switched, nothing over the model while wider"):format(combos),
  #badc == 0, list(badc, 2))
rc.enabled, rc.wide = true, true; ns.CharReskin_Apply()
local onW, onBg = CharacterFrame.w, PARTS().bg and PARTS().bg.shown
rc.enabled = false; ns.CharReskin_Apply()
check("F. the reskin switched off (from 780, background shown): Blizzard's width and places, the theme listener gone, the background hidden",
  onW == 780 and onBg and CharacterFrame.w == 540 and math.abs(RECT(CharacterModelScene).l - (RECT(cf).l + 52)) < 0.01 and #ns.Theme.listeners == LISTEN0 and not (PARTS().bg and PARTS().bg.shown),
  CharacterFrame.w .. " / " .. #ns.Theme.listeners)
''')

# ---------------------------------------------------------------------------------------------------------------------------------
# G. V14: a part that is off reads nothing, creates nothing, listens to nothing (each from a fresh login)
# ---------------------------------------------------------------------------------------------------------------------------------
lua = lua_with(r'''
CueRulesDB.characterReskin = { enabled = true, chrome = true, ilvl = false, enchants = false, gems = false, stats = false, wide = false }
CueRulesDB.characterToolkit = { enabled = true, overlays = false, panel = false }
HOOKS = {}
local baseHook = hooksecurefunc
hooksecurefunc = function(a, b, c)
  HOOKS[#HOOKS + 1] = { name = type(a) == "string" and a or b, src = debug.getinfo(2, "S").source }
  return baseHook(a, b, c)
end
PDHOOKS = {}
rawset(PaperDollFrame, "HookScript", function(self, sc, f)
  PDHOOKS[#PDHOOKS + 1] = debug.getinfo(2, "S").source
  self.hooks[sc] = self.hooks[sc] or {}; table.insert(self.hooks[sc], f)
end)
function pdHooksFrom(file) local k = 0; for _, src in ipairs(PDHOOKS) do if src:find(file, 1, true) then k = k + 1 end end; return k end
function hooksFrom(name, file)
  local k = 0
  for _, h in ipairs(HOOKS) do if h.name == name and h.src:find(file, 1, true) then k = k + 1 end end
  return k
end
''')
run(lua, r'''
local createdBefore = #created
local updateSize = CharacterFrame.UpdateSize
ns.FireReady()
CharacterFrame:Show(); PaperDollFrame:Show()
linkReads, tipReads = 0, 0
ns.CharReskin_Apply()
local sock = 0
for _, name in ipairs(ALL) do if _G["Character" .. name].xuiSockets or _G["Character" .. name].xuiEnchantRow then sock = sock + 1 end end
check("V14: only the Clean window on: the reskin reads no item and no tooltip, creates no row (no item level, gems or enchant part is on)",
  linkReads == 0 and tipReads == 0 and sock == 0, linkReads .. " reads, " .. tipReads .. " tooltips, " .. sock .. " rows")
local regd = {}
for i = createdBefore + 1, #created do if tostring(created[i].src):find("CharacterReskin.lua", 1, true) then for e in pairs(created[i].events) do regd[#regd + 1] = e end end end
check("  ...and listens to no item event", #regd == 0, table.concat(regd, " "))
check("V14: the wider window off at login: the window's UpdateSize not hooked, the Character tab not hooked, no frame waiting for combat, the width untouched",
  CharacterFrame.UpdateSize == updateSize and hooksFrom("UpdateSize", "CharacterReskin.lua") == 0 and pdHooksFrom("CharacterReskin.lua") == 0
  and WIDE().ev == nil and CharacterFrame.w == 540, ("%s %d %d %s %d"):format(tostring(CharacterFrame.UpdateSize == updateSize),
  hooksFrom("UpdateSize", "CharacterReskin.lua"), pdHooksFrom("CharacterReskin.lua"), tostring(WIDE().ev), CharacterFrame.w))
local rc = ns.CharReskin_Cfg(); rc.wide = true; ns.CharReskin_Apply()
check("  ...switched on: one hook on UpdateSize and one on the Character tab, wider (582, the default +42); off again: Blizzard's width, the hooks return at once (a /reload removes them)",
  hooksFrom("UpdateSize", "CharacterReskin.lua") == 1 and pdHooksFrom("CharacterReskin.lua") == 1 and CharacterFrame.w == 582 and (function()
    rc.wide = false; ns.CharReskin_Apply(); local w1 = CharacterFrame.w; CharacterFrame:UpdateSize(); return w1 == 540 and CharacterFrame.w == 540 end)(), CharacterFrame.w)
-- the toolkit is on, its slot overlays off: it does not hook the slot buttons
local hooksOff = hooksFrom("PaperDollItemSlotButton_Update", "CharacterToolkit.lua")
timers = {}
fire("PLAYER_EQUIPMENT_CHANGED", 1, true)
local t02 = 0
for _, d in ipairs(timers) do if d == 0.2 then t02 = t02 + 1 end end
local tk = ns.CharToolkit_Cfg(); tk.overlays = true; ns.CharToolkit_Apply()
check("V14: the toolkit on with its slot overlays off: no hook on the slot buttons and no overlay refresh on an item event; switched on: one hook, the overlay drawn",
  hooksOff == 0 and t02 == 0 and hooksFrom("PaperDollItemSlotButton_Update", "CharacterToolkit.lua") == 1 and ns.CharToolkit_OverlayText("HeadSlot") ~= nil, hooksOff .. " hooks, " .. t02 .. " refreshes")
-- the reskin switched off: its event frame listens to nothing
rc.ilvl = true; ns.CharReskin_Apply()
local listening = {}
for i = createdBefore + 1, #created do if tostring(created[i].src):find("CharacterReskin.lua", 1, true) and created[i].events.PLAYER_EQUIPMENT_CHANGED then listening[#listening + 1] = i end end
rc.enabled = false; ns.CharReskin_Apply()
local still = 0
for _, i in ipairs(listening) do for _ in pairs(created[i].events) do still = still + 1 end end
check("V14: the reskin listens to item changes while its item level is on; switched off, its event frame listens to nothing", #listening == 1 and still == 0, #listening .. " / " .. still)
''')

lua = lua_with(r'''
CueRulesDB.characterReskin = { enabled = false }
CueRulesDB.characterToolkit = { enabled = false }
''')
run(lua, r'''
local before, hookBefore, sizeBefore = #created, PaperDollItemSlotButton_Update, CharacterFrame.UpdateSize
ns.FireReady()
CharacterFrame:Show(); CharacterModelScene.ControlFrame:Show(); PaperDollFrame:Show()
check("V14: both off at login: no frame created, nothing hooked (slots, UpdateSize, the Character tab), no theme listener, nothing drawn, Blizzard's width",
  #created == before and PaperDollItemSlotButton_Update == hookBefore and CharacterFrame.UpdateSize == sizeBefore and #(PaperDollFrame.hooks.OnShow or {}) == 0
  and #ns.Theme.listeners == 0 and not CharacterHeadSlot.xuiIlvl and not CharacterHeadSlot.xuiEnchant and not CharacterHeadSlot.xuiSockets
  and #(CharacterModelScene.ControlFrame.hooks.OnShow or {}) == 0 and CharacterFrame.w == 540, #created - before)
''')

print("%d checks, %d failed" % (TOTAL_N, TOTAL_F))
sys.exit(1 if TOTAL_F else 0)
