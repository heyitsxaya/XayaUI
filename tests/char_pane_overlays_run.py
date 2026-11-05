# The character pane's slot overlays (XayaUI_QoL 0.7.19). Xaya's report of 2026-11-05, "character pane is broken": every slot showed
# its item level twice, a shirt "1", small "15" / "25" numbers on some slots, enchant labels cut off ("Enchant Helm - E...") running
# over the model, its camera buttons and each other, one of them purple ("Ancient Hash'ey B..."); then her direction: "correctly
# word wrap enchant lines" and "show gem sockets and gems socketed". Her settings at the time (her second screenshot): Character
# Reskin on, Clean window off, Item level / Enchants / Stat list on; the Character Toolkit on with its Slot Overlays.
# Checks what the player sees, in Blizzard's real window geometry (tests/char_pane_geometry.lua, from the live 12.1.5 XML):
#   1. reproduction in her settings: one XayaUI item level per slot (none on the shirt); the toolkit's empty-socket marks only where a
#      socket has no gem;
#   2. the enchant labels: the whole name, wrapped, in one colour; every line fits its width (estimated font width); each label inside
#      its slot's band and its side of the window; no two labels overlap; none covers a slot, a socket, the weapon slots' art or an
#      item level; none meets the model's camera buttons while they show; at 338 and 540 px (stats pane open) and a wider window;
#   3. the sockets: one per gem socket, the gem's icon or an empty socket, the gem on hover, placed where the game puts its own;
#   4. every combination of the reskin's and the toolkit's switches: one item level, one socket mark and one enchant mark per slot;
#   5. /xui reskin status names text on the slots that is not XayaUI's (another addon's item level);
#   6. V14: a part that is off reads nothing, creates nothing, listens to nothing.
# Run from the repo root: python3 tests/char_pane_overlays_run.py   Needs: pip install lupa.
# Every item, gem, socket and enchant below is a TEST STAND-IN. Names are real ones from Blizzard's client data
# (docs/reference/content/items.json, build 12.1.5.70783) where her screenshot shows their start; "+41 Agility/Strength & 41 Stamina"
# is made up past the "+41 Agility/Strengt" she showed. Which gems she has is not known: the gems are stand-ins.
import os, sys
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
placePane(338)
function PaperDollItemSlotButton_Update(btn) end
function PaperDollFrame_UpdateStats() end
function PanelTemplates_SetTab(frame, id) frame.selectedTab = id end
ENCHANTED_TOOLTIP_LINE = "Enchanted: %s"
EMPTY_SOCKET_PRISMATIC = "Prismatic Socket"
-- her gear: item level 334 (her 333.75 equipped), Hero track; a shirt (item level 1), no tabard
local LIST = {
  { 1, "Helm", 1 }, { 2, "Amulet", 2 }, { 3, "Spaulders", 0 }, { 15, "Cloak", 0 }, { 5, "Chestguard", 0 }, { 4, "Shirt", 0 },
  { 9, "Bracers", 1 }, { 10, "Gloves", 0 }, { 6, "Belt", 1 }, { 7, "Legguards", 0 }, { 8, "Boots", 0 }, { 11, "Ring A", 2 },
  { 12, "Ring B", 2 }, { 13, "Trinket A", 0 }, { 14, "Trinket B", 0 }, { 16, "Glaive A", 1 }, { 17, "Glaive B", 0 } }
ENCH = { [1] = "Enchant Helm - Empowered Rune of Avoidance", [3] = "Enchant Shoulders - Akil'zon's Swiftness",
  [5] = "Enchant Chest - Mark of the Rootwarden", [6] = "Ancient Hash'ey Battle Art: Ursine's Ironhide",
  [7] = "+41 Agility/Strength & 41 Stamina", [8] = "Enchant Boots - Shaladrassil's Roots", [11] = "Enchant Ring - Eyes of the Eagle",
  [12] = "Enchant Ring - Eyes of the Eagle", [16] = "Enchant Weapon - Acuity of the Ren'dorei", [17] = "Enchant Weapon - Flames of the Sin'dorei" }
GEAR, ITEMS, TIP, UPG = {}, {}, {}, {}
for _, e in ipairs(LIST) do
  local slot, name, sockets = e[1], e[2], e[3]
  GEAR[slot] = ("|cffa335ee|Hitem:%d:%s::::::::90:::::|h[%s]|h|r"):format(1000 + slot, ENCH[slot] and "7000" or "", name)
  ITEMS[name] = { ilvl = (slot == 4) and 1 or 334, loc = "INVTYPE_X", class = (slot == 16 or slot == 17) and 2 or 4,
    stats = { ITEM_MOD_AGILITY_SHORT = 500, EMPTY_SOCKET_PRISMATIC = sockets > 0 and sockets or nil } }
  UPG[name] = { trackString = "Hero", currentLevel = 6, maxLevel = 6 }
  if ENCH[slot] then TIP[slot] = { { type = 15, leftText = "Enchanted: " .. ENCH[slot] } } end
end
-- the purple one: the line carries the epic colour in its text, after the "Enchanted: " (INFERENCE from her screenshot: the label read
-- "Ancient Hash'ey B..." in purple, so the prefix was taken off and a colour code stayed)
TIP[6] = { { type = 15, leftText = "Enchanted: |cffa335ee" .. ENCH[6] .. "|r" } }
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
C_TooltipInfo.GetInventoryItem = function(_, slot) return { lines = TIP[slot] or {} } end
GameTooltip.SetHyperlink = function(self, l) self.link = l end
timers = {}
C_Timer.After = function(d, fn) timers[#timers + 1] = d; fn() end
assert(loadfile(__CT__))("XayaUI_QoL", ns)
assert(loadfile(__RS__))("XayaUI_QoL", ns)
-- XayaUI's texts on one slot: the reskin's item level and label, the toolkit overlay's item level and marks
function shownText(fs) return fs and fs.shown and (fs.alpha or 1) > 0 and fs.text ~= nil and fs.text ~= "" end
function ilvlTexts(name)
  local n, b = 0, _G["Character" .. name]
  if shownText(b.xuiIlvl) then n = n + 1 end
  local ti = ns.CharToolkit_OverlayText(name)
  if ti and ti ~= "" then n = n + 1 end
  return n
end
function marks(name) local _, m = ns.CharToolkit_OverlayText(name); return (m or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
function sockets(name) local b, out = _G["Character" .. name], {}; for _, f in ipairs(b.xuiSockets or {}) do if f.shown then out[#out + 1] = f end end; return out end
ALL = {}
for _, n in ipairs(PANE_SLOTS_LEFT) do ALL[#ALL + 1] = n end
for _, n in ipairs(PANE_SLOTS_RIGHT) do ALL[#ALL + 1] = n end
ALL[#ALL + 1] = "MainHandSlot"; ALL[#ALL + 1] = "SecondaryHandSlot"
SLOT_ID = {}
for _, s in ipairs(CM.SLOTS) do SLOT_ID[s[4]] = s[1] end
LEFTSET = {}
for _, n in ipairs(PANE_SLOTS_LEFT) do LEFTSET[n] = true end
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
import json
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

# ---------------------------------------------------------------------------------------------------------------------------------
# 1-5: her settings, then every combination
# ---------------------------------------------------------------------------------------------------------------------------------
lua = lua_with(ALLNAMES + r'''
local tk = ns.CharToolkit_Cfg()
tk.enchantSlots = { [1] = true, [3] = true, [5] = true, [7] = true, [8] = true, [9] = true, [11] = true, [12] = true, [16] = true, [17] = true }
tk.enchantSlotsSet = true   -- she ticked her wrist too: "No enchant" there
''')
run(lua, r'''
FireReadyDone = ns.FireReady()
local rc, tk = ns.CharReskin_Cfg(), ns.CharToolkit_Cfg()
-- her settings (second screenshot): reskin on, Clean window off, item level, enchants, stat list on; toolkit and its slot overlays on
rc.enabled, rc.chrome, rc.ilvl, rc.enchants, rc.stats = true, false, true, true, true
tk.enabled, tk.overlays, tk.panel = true, true, false
ns.CharToolkit_Apply(); ns.CharReskin_Apply()
CharacterFrame:Show()
CharacterModelScene.ControlFrame:Hide()

-- 1. reproduction: what XayaUI draws on each slot -------------------------------------------------------------------------------
local bad = {}
for _, name in ipairs(ALL) do
  local want = (GEAR[SLOT_ID[name]] and name ~= "ShirtSlot") and 1 or 0
  if ilvlTexts(name) ~= want then bad[#bad + 1] = name .. "=" .. ilvlTexts(name) end
end
check("her settings: XayaUI draws exactly one item level on each equipped slot, none on the shirt (her pane: a shirt \"1\")", #bad == 0, table.concat(bad, " "))
check("  ...the shirt's \"1\" is gone (its item level says nothing; the Gear tab leaves the shirt out too)", not shownText(CharacterShirtSlot.xuiIlvl), CharacterShirtSlot.xuiIlvl and CharacterShirtSlot.xuiIlvl.text)

-- 2. the enchant labels ---------------------------------------------------------------------------------------------------------
local GOOD, WARN = { 0.5, 1, 0.5 }, { 1, 0.56, 0.25 }
local function near(c, t) return c and math.abs(c[1] - t[1]) < 0.01 and math.abs(c[2] - t[2]) < 0.01 and math.abs(c[3] - t[3]) < 0.01 end
EXPECT = {}
for slot, txt in pairs(ENCH) do EXPECT[slot] = { txt, GOOD } end
EXPECT[9] = { "No enchant", WARN }
function labelChecks(tag)
  local missing, cut, colour, fit = {}, {}, {}, {}
  for _, name in ipairs(ALL) do
    local fs, e = _G["Character" .. name].xuiEnchant, EXPECT[SLOT_ID[name]]
    if e then
      local lines = seenLines(fs)
      local seen = table.concat(lines, " ")
      if not shownText(fs) then missing[#missing + 1] = name
      elseif seen ~= e[1] then cut[#cut + 1] = name .. ": " .. seen end
      if tostring(fs.text):find("|c", 1, true) or not near(fs.color, e[2]) then colour[#colour + 1] = name end
      local size = fs.font and fs.font[2] or 0
      if size < 8 or size > 10 then fit[#fit + 1] = name .. " size " .. size end
      for _, l in ipairs(lines) do if #l * CHAR_W(size) > (fs.w or 0) + 0.01 then fit[#fit + 1] = name .. ": " .. l end end
    elseif shownText(fs) then missing[#missing + 1] = name .. " (a label where none is due: " .. fs.text .. ")" end
  end
  -- (one check: every enchanted slot has its label, none elsewhere; the whole name, wrapped; every line within the label's width)
  local all = {}
  for _, t in ipairs({ missing, cut, fit }) do for _, x in ipairs(t) do all[#all + 1] = x end end
  check(tag .. "every enchanted slot shows the whole name, word-wrapped, every line within its width at 8-10 pt, nothing cut (her pane: \"Enchant Helm - E...\")",
    #all == 0, table.concat(all, " | "))
  check(tag .. "  ...in one colour: green, or orange for \"No enchant\" (her pane: the Hash'ey one in purple)", #colour == 0, table.concat(colour, " "))
end
function layoutProblems(camShown)
  local inset = RECT(CharacterFrame.Inset)
  local head, hands = RECT(CharacterHeadSlot), RECT(CharacterHandsSlot)
  local mid = (head.r + hands.l) / 2
  local gut = ns.UI_GUTTER
  local labels, slots, socks, ilvls, arts = {}, {}, {}, {}, {}
  for _, name in ipairs(ALL) do
    local b = _G["Character" .. name]
    slots[#slots + 1] = { name, RECT(b) }
    if shownText(b.xuiEnchant) then labels[#labels + 1] = { name, RECT(b.xuiEnchant), b } end
    if shownText(b.xuiIlvl) then ilvls[#ilvls + 1] = { name, RECT(b.xuiIlvl) } end
    for i, f in ipairs(sockets(name)) do socks[#socks + 1] = { name .. "#" .. i, RECT(f) } end
  end
  for _, k in ipairs({ "MainHandSlot", "SecondaryHandSlot", "MainHandSide", "SecondaryHandSide" }) do arts[#arts + 1] = { k .. " art", RECT(ART[k]) } end
  local band, side, inwin, ov, slotov, camov = {}, {}, {}, {}, {}, {}
  local lastL, lastR = RECT(CharacterWristSlot), RECT(CharacterTrinket1Slot)
  for _, L in ipairs(labels) do
    local name, r, b = L[1], L[2], L[3]
    local sr = RECT(b)
    if not r then band[#band + 1] = name .. " (no rectangle)"
    else
      if name == "MainHandSlot" or name == "SecondaryHandSlot" then
        local top = (name == "MainHandSlot" and lastL or lastR).b - 2
        if r.t > top + 0.01 or r.b < inset.b - 0.01 then band[#band + 1] = name .. " " .. rstr(r) end
      elseif r.t > sr.t + 2.01 or r.b < sr.b - 2.01 then band[#band + 1] = name .. " " .. rstr(r) end
      if LEFTSET[name] or name == "MainHandSlot" then if r.r > mid - gut / 2 + 0.01 then side[#side + 1] = name .. " " .. rstr(r) end
      elseif r.l < mid + gut / 2 - 0.01 then side[#side + 1] = name .. " " .. rstr(r) end
      if not inside(r, inset) then inwin[#inwin + 1] = name .. " " .. rstr(r) end
    end
  end
  for i = 1, #labels do for j = i + 1, #labels do
    if overlaps(labels[i][2], labels[j][2]) then ov[#ov + 1] = labels[i][1] .. " / " .. labels[j][1] end
  end end
  for _, L in ipairs(labels) do
    for _, other in ipairs({ slots, socks, ilvls, arts }) do
      for _, o in ipairs(other) do if overlaps(L[2], o[2]) then slotov[#slotov + 1] = L[1] .. " / " .. o[1] end end
    end
  end
  local cam = RECT(CharacterModelScene.ControlFrame)
  if camShown then for _, L in ipairs(labels) do if overlaps(L[2], cam) then camov[#camov + 1] = L[1] .. " " .. rstr(L[2]) end end end
  -- (one V11 check per window: band, side, inside the window, no overlaps; the camera buttons while they show)
  local all = {}
  for _, t in ipairs({ band, side, inwin, ov, slotov, camov }) do for _, x in ipairs(t) do all[#all + 1] = x end end
  -- the sockets: inside the window, clear of the slots, the camera buttons and each other
  local sbad = {}
  for i, s in ipairs(socks) do
    if not inside(s[2], inset) then sbad[#sbad + 1] = s[1] .. " outside " .. rstr(s[2]) end
    for _, o in ipairs(slots) do if overlaps(s[2], o[2]) then sbad[#sbad + 1] = s[1] .. " / " .. o[1] end end
    for _, o in ipairs(ilvls) do if overlaps(s[2], o[2]) then sbad[#sbad + 1] = s[1] .. " / " .. o[1] .. " item level" end end
    if overlaps(s[2], cam) then sbad[#sbad + 1] = s[1] .. " / camera" end
    for j = i + 1, #socks do if overlaps(s[2], socks[j][2]) then sbad[#sbad + 1] = s[1] .. " / " .. socks[j][1] end end
  end
  return all, sbad, #socks
end
function layoutChecks(tag, camShown)
  local all, sbad, nsock = layoutProblems(camShown)
  check(tag .. "every label inside its slot's band (the weapons' under the side columns), on its side of the window (a gutter apart, #351), inside the window; no two overlap; none covers a slot, a socket, an item level or the weapon slots' art"
    .. (camShown and "; none meets the model's camera buttons while they show (her pane: the head row ran over them)" or ""), #all == 0, table.concat(all, "; "))
  check(tag .. "the sockets: inside the window, clear of the slots, the item levels, the camera buttons and each other", nsock > 0 and #sbad == 0, table.concat(sbad, "; "))
end
labelChecks("338 px: ")
layoutChecks("338 px, camera buttons hidden: ", false)
CharacterModelScene.ControlFrame:Show()
layoutChecks("338 px, camera buttons shown: ", true)
local hidden = {}
for _, name in ipairs(ALL) do local fs = _G["Character" .. name].xuiEnchant; if fs and fs.text ~= "" and (fs.alpha or 1) == 0 then hidden[#hidden + 1] = name end end
CharacterModelScene.ControlFrame:Hide()
local back = true
for _, name in ipairs(ALL) do local fs = _G["Character" .. name].xuiEnchant; if fs and (fs.alpha or 1) == 0 then back = false end end
check("  ...only the labels that meet them hide (DECISION: the head row's), and only while they show", table.concat(hidden, ",") == "HeadSlot" and back, table.concat(hidden, ","))

-- the window with the stats pane open (540 wide): the paper doll does not move
placePane(540); ns.CharReskin_Apply()
labelChecks("540 px: ")
CharacterModelScene.ControlFrame:Show()
layoutChecks("540 px, camera buttons shown: ", true)
CharacterModelScene.ControlFrame:Hide()
-- a wider window (the width probe's 120 px: the Inset, the model and the right column move out, the main hand by 60)
placePane(458)
CharacterFrame.Inset.pts[2] = { "BOTTOMRIGHT", CharacterFrame, "BOTTOMLEFT", 338 - 6 + 120, 4 }
CharacterModelScene.w = 231 + 120
CharacterMainHandSlot.pts = { { "BOTTOMLEFT", PaperDollItemsFrame, "BOTTOMLEFT", 130 + 60, 16 } }
ns.CharReskin_Apply()
labelChecks("wider window: ")
CharacterModelScene.ControlFrame:Show()
layoutChecks("wider window, camera buttons shown: ", true)
CharacterModelScene.ControlFrame:Hide()
placePane(338); ns.CharReskin_Apply()

-- every enchant name of this expansion in the client data, on the slots it goes on (the head and the hands rows with the camera
-- buttons shown too): the whole name shown, nothing cut, the layout holds
local savedTIP, bad, sizes = TIP, {}, {}
for _, e in ipairs(ALLNAMES) do
  TIP = {}
  for k, v in pairs(savedTIP) do TIP[k] = v end
  for _, slot in ipairs(e.slots) do TIP[slot] = { { type = 15, leftText = "Enchanted: " .. e.name } } end
  CharacterModelScene.ControlFrame:Hide()
  ns.CharReskin_Apply()
  for _, slot in ipairs(e.slots) do
    local name
    for n2, id in pairs(SLOT_ID) do if id == slot then name = n2 end end
    local fs = _G["Character" .. name].xuiEnchant
    local seen = table.concat(seenLines(fs), " ")
    if not shownText(fs) or seen ~= e.name then bad[#bad + 1] = name .. ": " .. seen end
    for _, l in ipairs(seenLines(fs)) do if #l * CHAR_W(fs.font[2]) > fs.w + 0.01 then bad[#bad + 1] = name .. " line too wide: " .. l end end
    sizes[fs.font[2]] = (sizes[fs.font[2]] or 0) + 1
  end
  local p1 = layoutProblems(false)
  CharacterModelScene.ControlFrame:Show()
  local p2 = layoutProblems(true)
  for _, x in ipairs(p1) do bad[#bad + 1] = e.name .. ": " .. x end
  for _, x in ipairs(p2) do bad[#bad + 1] = e.name .. " (camera shown): " .. x end
end
CharacterModelScene.ControlFrame:Hide()
TIP = savedTIP; ns.CharReskin_Apply()
check(("every enchant name of this expansion in the client data (%d names) on its slots: the whole name, every line within its width, the layout holds (sizes used: 10 pt %d, 9 pt %d, 8 pt %d)")
  :format(#ALLNAMES, sizes[10] or 0, sizes[9] or 0, sizes[8] or 0), #bad == 0, bad[1] and (bad[1] .. (#bad > 1 and (" (+" .. (#bad - 1) .. " more)") or "")))

-- the window open but a slot without a position on the first pass (INFERENCE: possible in the frame it opens): laid out on a retry
local realGetLeft, realAfter, nextFrame = CharacterHeadSlot.GetLeft, C_Timer.After, false
CharacterHeadSlot.GetLeft = function(self) if not nextFrame then return nil end; return realGetLeft(self) end
C_Timer.After = function(d, fn) nextFrame = true; return realAfter(d, fn) end
ns.CharReskin_Apply()
CharacterHeadSlot.GetLeft, C_Timer.After = realGetLeft, realAfter
check("the slots with no position yet when the window opens: the labels are laid out on the next frame (the whole name)",
  nextFrame and table.concat(seenLines(CharacterHeadSlot.xuiEnchant), " ") == ENCH[1] and table.concat(seenLines(CharacterFeetSlot.xuiEnchant), " ") == ENCH[8],
  table.concat(seenLines(CharacterHeadSlot.xuiEnchant), " "))

-- 3. the sockets ----------------------------------------------------------------------------------------------------------------
local nb = sockets("NeckSlot")
check("sockets: the neck's two, both with their gem's icon; none on a slot without sockets (DECISION: the reskin draws them; the game's own display is for Timerunning only)",
  #nb == 2 and nb[1].gem.shown and nb[1].gem.tex == 9002 and nb[2].gem.shown and nb[2].gem.tex == 9003 and #sockets("ChestSlot") == 0 and #sockets("HandsSlot") == 0, #nb)
local ra = sockets("Finger0Slot")
check("  ...Ring A: its gem, then an empty socket (no gem art in it)", #ra == 2 and ra[1].gem.shown and ra[1].gem.tex == 9002 and not ra[2].gem.shown, #ra)
local hr, nr, mr, wr = RECT(CharacterHeadSlot), RECT(nb[1]), RECT(sockets("MainHandSlot")[1]), RECT(CharacterMainHandSlot)
local rb = RECT(ra[1]); local r0 = RECT(CharacterFinger0Slot)
check("  ...where the game puts its own: 7 px beside the slot, toward the model (left and right columns)", nr ~= nil and rb ~= nil and math.abs(nr.l - (RECT(CharacterNeckSlot).r + 7)) < 0.01
  and math.abs(rb.r - (r0.l - 7)) < 0.01, rstr(nr) .. " / " .. rstr(rb))
check("  ...the main hand's under the weapon", mr and mr.t <= wr.b + 0.01 and mr.l >= wr.l - 0.01 and mr.r <= wr.r + 0.01, rstr(mr))
GameTooltip.link = nil; if nb[1] then nb[1].scripts.OnEnter(nb[1]) end
check("  ...hover a gem: the gem's own tooltip (its link)", tostring(GameTooltip.link):find("Flawless Masterful Amethyst", 1, true) ~= nil, tostring(GameTooltip.link))
GameTooltip.lines = {}; if ra[2] then ra[2].scripts.OnEnter(ra[2]) end
check("  ...hover an empty socket: its type, from the game's own string", GameTooltip.lines[1] == "Prismatic Socket", tostring(GameTooltip.lines[1]))

-- the toolkit's marks: "nS" counts sockets without a gem; left out while the reskin draws the sockets
local m = {}
for _, name in ipairs(ALL) do if marks(name):find("S", 1, true) then m[#m + 1] = name end end
check("while the reskin draws the sockets the toolkit leaves its socket mark out (one per slot)", #m == 0, table.concat(m, " "))
rc.gems = false; ns.CharReskin_Apply()
check("  ...gems off: the reskin's sockets go, and the toolkit's mark counts only sockets without a gem: neck (both filled) none (her pane: \"25\" = 2S)",
  #sockets("NeckSlot") == 0 and marks("NeckSlot") == "", marks("NeckSlot"))
check("  ...Ring A one empty: 1S; Ring B (both filled) none; the bracers' empty one: 1S", marks("Finger0Slot"):find("1S", 1, true) ~= nil
  and not marks("Finger1Slot"):find("S", 1, true) and marks("WristSlot"):find("1S", 1, true) ~= nil,
  marks("Finger0Slot") .. " | " .. marks("Finger1Slot") .. " | " .. marks("WristSlot"))
rc.gems = true; ns.CharReskin_Apply()

-- the same count in the Stat Calculator's Gear tab (V4: the other readers of the slot's socket count)
CM.gearSlot = 2
local gm = ns.CharToolkit_Model("gear")
local function grow(key) for _, r in ipairs(gm) do if r.key == key then return r end end end
local amulet = grow("gc_sockets")
CM.gearSlot = nil
gm = ns.CharToolkit_Model("gear")
local sum = grow("gearSum_sockets")
check("Gear tab: the amulet (both sockets filled) has no Empty sockets row; the Summary counts 3 (bracers, Ring A, Glaive A)",
  amulet == nil and sum and sum.cells[1] == "3", (amulet and table.concat(amulet.cells, "|") or "none") .. " / " .. (sum and sum.cells[1] or "none"))

-- 5. who else draws on the slots ---------------------------------------------------------------------------------------------------
local other = mk("FS"); other.text = "|cffa335ee334|r"; other.shown = true; other.debugName = "OtherAddonHeadItemLevel"
addRegion(CharacterHeadSlot, other)
printed = {}
ns.RunCommand("reskin", "status")
local said = table.concat(printed, "\n")
check("/xui reskin status names text on the slots that is not XayaUI's (another addon's item level)", said:find("OtherAddonHeadItemLevel", 1, true) ~= nil
  and said:find("Head 334", 1, true) ~= nil, said)
check("  ...and not XayaUI's own (the reskin's item level and labels, the toolkit's marks)", not said:find("Enchant Helm", 1, true) and said:find("not XayaUI's (1)", 1, true) ~= nil, said)
other.shown = false

-- 4. every combination of the switches: one item level, one socket mark, one enchant mark per slot ---------------------------------
local combos, badc = 0, {}
for _, ron in ipairs({ false, true }) do for _, ril in ipairs({ false, true }) do for _, ren in ipairs({ false, true }) do for _, rge in ipairs({ false, true }) do
for _, ton in ipairs({ false, true }) do for _, tov in ipairs({ false, true }) do
  rc.enabled, rc.ilvl, rc.enchants, rc.gems = ron, ril, ren, rge
  tk.enabled, tk.overlays = ton, tov
  ns.CharReskin_Apply(); ns.CharToolkit_Apply(); ns.CharToolkit_UpdateOverlays()
  combos = combos + 1
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
end end end end end end
check(("every combination of the reskin's and the toolkit's switches (%d): one item level per slot (none on the shirt), at most one socket mark and one enchant mark"):format(combos),
  #badc == 0, badc[1] and (badc[1] .. (#badc > 1 and (" (+" .. (#badc - 1) .. " more)") or "")))
''')

# ---------------------------------------------------------------------------------------------------------------------------------
# 6. V14: a part that is off reads nothing, creates nothing, listens to nothing (each from a fresh login)
# ---------------------------------------------------------------------------------------------------------------------------------
lua = lua_with(r'''
CueRulesDB.characterReskin = { enabled = true, chrome = true, ilvl = false, enchants = false, gems = false, stats = false }
CueRulesDB.characterToolkit = { enabled = true, overlays = false, panel = false }
HOOKS = {}
local baseHook = hooksecurefunc
hooksecurefunc = function(a, b, c)
  HOOKS[#HOOKS + 1] = { name = type(a) == "string" and a or b, src = debug.getinfo(2, "S").source }
  return baseHook(a, b, c)
end
function toolkitSlotHooks()
  local k = 0
  for _, h in ipairs(HOOKS) do if h.name == "PaperDollItemSlotButton_Update" and h.src:find("CharacterToolkit.lua", 1, true) then k = k + 1 end end
  return k
end
''')
run(lua, r'''
local hookBefore = PaperDollItemSlotButton_Update
local createdBefore = #created
ns.FireReady()
CharacterFrame:Show()
linkReads = 0
ns.CharReskin_Apply()
local sock = 0
for _, name in ipairs(ALL) do if _G["Character" .. name].xuiSockets then sock = sock + 1 end end
check("V14: only the Clean window on: the reskin reads no item and creates no socket (no item level, gems or enchant part is on)", linkReads == 0 and sock == 0, linkReads .. " reads, " .. sock .. " sockets")
local regd = {}
for i = createdBefore + 1, #created do if tostring(created[i].src):find("CharacterReskin.lua", 1, true) then for e in pairs(created[i].events) do regd[#regd + 1] = e end end end
check("  ...and listens to no item event", #regd == 0, table.concat(regd, " "))
-- the toolkit is on, its slot overlays off: it does not hook the slot buttons
local hooksOff = toolkitSlotHooks()
timers = {}
fire("PLAYER_EQUIPMENT_CHANGED", 1, true)
local t02 = 0
for _, d in ipairs(timers) do if d == 0.2 then t02 = t02 + 1 end end
local tk = ns.CharToolkit_Cfg(); tk.overlays = true; ns.CharToolkit_Apply()
check("V14: the toolkit on with its slot overlays off: no hook on the slot buttons and no overlay refresh on an item event; switched on: one hook, the overlay drawn",
  hooksOff == 0 and t02 == 0 and toolkitSlotHooks() == 1 and ns.CharToolkit_OverlayText("HeadSlot") ~= nil, hooksOff .. " hooks, " .. t02 .. " refreshes")
-- the reskin switched off: its event frame listens to nothing
local rc = ns.CharReskin_Cfg(); rc.ilvl = true; ns.CharReskin_Apply()
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
local before, hookBefore = #created, PaperDollItemSlotButton_Update
ns.FireReady()
CharacterFrame:Show(); CharacterModelScene.ControlFrame:Show()
check("V14: both off at login: no frame created, the slot buttons not hooked, nothing drawn on a slot", #created == before
  and PaperDollItemSlotButton_Update == hookBefore and not CharacterHeadSlot.xuiIlvl and not CharacterHeadSlot.xuiEnchant and not CharacterHeadSlot.xuiSockets
  and #(CharacterModelScene.ControlFrame.hooks.OnShow or {}) == 0, #created - before)
''')

print("%d checks, %d failed" % (TOTAL_N, TOTAL_F))
sys.exit(1 if TOTAL_F else 0)
