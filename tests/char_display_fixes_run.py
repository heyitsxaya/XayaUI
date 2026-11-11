# Improved Character Display and Character Reskin: no option goes quiet, distinct names (V25 unit C; review findings SC-069, SC-103,
# docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md). What the player sees in the built settings pages and on the slots:
#   1. (A24 #7) QoL > Improved Character Display: the Slot Overlays part and its greyed Item level / Enchant check marks are gone (one
#      "Item level" and one "Enchants" option, no style since A24 #9; tests/slot_options_run.py). The Empty sockets mark is kept as it was: while
#      "Gems and sockets beside the slots" already shows the sockets, its tick box is greyed, shows unticked, and its hover names the option
#      to turn off; with that option off the box is ticked and live again and the slot shows the mark. The box and the slot never disagree
#      (gems, the mark, round 3's unused Enchants style key, and after an error stops the item details). The Text size slider is greyed
#      exactly when no mark shows on the slots (A24 #9: the empty-socket count is the only mark left).
#   2. Blizzard Reskin > Character Reskin: the toggle that colors Blizzard's stat list is "Stat list colors", and no label on that page
#      is the same as a label on the Improved Character Display page.
# Run from the repo root: python3 tests/char_display_fixes_run.py [tree root]   (default: this repo). Needs: pip install lupa.
# The tree-root argument loads the addon files and the stand-in world from another checkout (the negative control: the checkpoint
# f34cc33 must FAIL these checks). Every item and number is a TEST STAND-IN (tests/char_world.lua: Helm 336 in slot 1, no enchant;
# Ring 330 in slot 11, enchanted, one empty socket).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"

lua = LuaRuntime()
lua.execute(r'''
assert(loadfile(__WORLD__))()
assert(loadfile(__GEOM__))()
-- (stand-ins of this test's own: Blizzard's character window regions the look reads; names from Blizzard's 12.1.5 XML)
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
  local b = mk("ItemButton"); b.id = s[1]; local nt = reg(); b.GetNormalTexture = function() return nt end
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
assert(loadfile(__ICD__))("XayaUI_QoL", ns)
assert(loadfile(__RS__))("XayaUI_QoL", ns)
ns.FireReady(); ns.SettingsDeclareStore("reskin", "XayaUI_Reskin", "XayaUIReskinDB"); ns.SettingsOpenAllForTests()
''' .replace("__WORLD__", P("tests/char_world.lua")).replace("__GEOM__", P("tests/char_pane_geometry.lua")).replace("__MOD__", P("XayaUI/Modules.lua"))
    .replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/StatModel.lua"))
    .replace("__ICD__", P("XayaUI_QoL/ImprovedCharacterDisplay.lua")).replace("__RS__", P("XayaUI_QoL/CharacterReskin.lua")))

lua.execute(r'''
local rc = RC()
local CM = ns.StatModel
-- what an options control shows: a value or a function of it (as the options window reads them)
local function V(x) if type(x) == "function" then return x({}) end; return x end
local function disabled(opt) return V(opt.disabled) == true end
local function ticked(opt) return opt.get({}) == true end
local function hover(opt) return tostring(V(opt.desc) or "") end
local NONE = { get = function() return nil end }
-- (A24 #7, #9) the page's options: Item level and Enchants (no Style since A24 #9), the Empty sockets mark and the mark's Text size
local function show()
  local pg = ns.BuildCharDisplayPage(function() RSA(); ns.CharDisplay_UpdateOverlays() end)
  local a = pg.args
  return { ilvl = a.ilvl or NONE, ilvlStyle = a.ilvlStyle or NONE, enchants = a.enchants or NONE, enchantStyle = a.enchantStyle or NONE,
    sockets = a.socketMark or NONE, size = a.markSize or NONE }, pg
end
local function plain(text) return (tostring(text or "")):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
local function marksOn(slotName) return plain(ns.CharDisplay_SlotMarks and ns.CharDisplay_SlotMarks(slotName)) end
-- one sentence (UI-65 "briefer, more direct"): no full stop followed by more text
local function oneSentence(text) return not tostring(text):find("%.%s+%S") end

-- Improved Character Display on with its defaults (item level on the slot, enchants and gems beside the slots, the full stat list)
CharacterFrame:Show(); PaperDollFrame:Show()
rc.features = true; RSA()
local o, dpage = show()

-- 1a. (A24 #7) no greyed item level or enchant mark: the Slot Overlays part is gone ------------------------------------------------
check("1a. (A24 #7) no Slot Overlays part, and no \"Item level on each slot\" / \"Enchants beside the slots\" / \"Enchant check\" control (the overlap is gone)",
  dpage.args.overlayPart == nil and V(o.ilvl.name) == "Item level" and V(o.enchants.name) == "Enchants", tostring(V(o.ilvl.name)) .. " / " .. tostring(V(o.enchants.name)))
check("  ...Item level and Enchants are live and ticked with Improved Character Display on (nothing greyed)", not disabled(o.ilvl) and ticked(o.ilvl)
  and not disabled(o.enchants) and ticked(o.enchants))

-- 1c. Empty sockets (kept as it was: A24 #7 did not decide the gems and sockets) -------------------------------------------------------
check("1c. \"Gems and sockets beside the slots\" on: the \"Empty sockets\" box is greyed and unticked", disabled(o.sockets) and not ticked(o.sockets))
check("  ...its hover names \"Gems and sockets beside the slots\" and says to turn it off",
  hover(o.sockets):find("Greyed", 1, true) ~= nil and hover(o.sockets):find("\"Gems and sockets beside the slots\"", 1, true) ~= nil and hover(o.sockets):find("off", 1, true) ~= nil, hover(o.sockets))
check("  ...(review round 2) the greyed hover is one short sentence (UI-65)", oneSentence(hover(o.sockets)) and #hover(o.sockets) <= 100, hover(o.sockets))
rc.socketMark = true; rc.gems = false; RSA(); ns.CharDisplay_UpdateOverlays(); o = show()
local mk = marksOn("Finger0Slot")
check("\"Gems and sockets beside the slots\" off: \"Empty sockets\" live and ticked, plain hover, and the ring (one empty socket) shows 1S",
  not disabled(o.sockets) and ticked(o.sockets) and hover(o.sockets):find("Greyed", 1, true) == nil and mk:find("1S", 1, true) ~= nil, mk)
rc.gems = true; RSA()

-- 1d. parity: the box and the slot never disagree (gems on / off, Enchants each style, the mark ticked or not)
local bad = {}
for _, combo in ipairs({ { true, true }, { true, false }, { false, true }, { false, false } }) do
  for _, sty in ipairs({ "slot", "beside" }) do
    rc.gems, rc.socketMark, rc.enchantStyle = combo[1], combo[2] or nil, sty ~= "beside" and sty or nil; RSA(); ns.CharDisplay_UpdateOverlays(); o = show()
    local rMk = marksOn("Finger0Slot")
    if ((ticked(o.sockets) and not disabled(o.sockets)) == (rMk:find("1S", 1, true) ~= nil)) == false then
      bad[#bad + 1] = tostring(combo[1]) .. "/" .. tostring(combo[2]) .. "/" .. sty
    end
  end
end
check("1d. the Empty sockets box is ticked and live exactly when its mark shows on the slot (gems, the mark, round 3's unused Enchants style key)", #bad == 0, table.concat(bad, " "))
rc.gems, rc.socketMark, rc.enchantStyle = true, nil, nil; RSA()

-- 1f. (review round 2) the Text size slider never looks live while no mark can show: greyed exactly when no mark draws on any slot
local badSz = {}
local function sizeCase(label, ench, sty, gems, sock)
  rc.enchants, rc.enchantStyle, rc.gems, rc.socketMark = ench, sty, gems, sock; RSA(); ns.CharDisplay_UpdateOverlays(); o = show()
  local anyMark = marksOn("HeadSlot") ~= "" or marksOn("Finger0Slot") ~= ""
  if disabled(o.size) == anyMark then badSz[#badSz + 1] = label .. (anyMark and " (a mark shows, slider greyed)" or " (no mark, slider live)") end
  return o.size
end
for _, ench in ipairs({ true, false }) do for _, sty in ipairs({ "slot", false }) do for _, gems in ipairs({ true, false }) do for _, sock in ipairs({ true, false }) do
  sizeCase(("%s/%s/%s/%s"):format(tostring(ench), tostring(sty), tostring(gems), tostring(sock)), ench, sty or nil, gems, sock or nil)
end end end end
check("1f. Text size is greyed exactly when no mark shows on the slots (16 combinations of Enchants, round 3's unused style key, the gems and Empty sockets)", #badSz == 0, table.concat(badSz, "; "))
local sz = sizeCase("defaults", true, nil, true, nil)
check("  ...with the defaults (enchants and gems beside the slots) it is greyed and its hover says why in one sentence",
  disabled(sz) and hover(sz):find("Greyed", 1, true) ~= nil and oneSentence(hover(sz)), hover(sz))
sz = sizeCase("enchants, old style key 'slot'", true, "slot", true, nil)
check("  ...(A24 #9) Enchants with round 3's style key \"slot\" saved: no enchant mark on the slots any more, so it stays greyed", disabled(sz) and marksOn("HeadSlot") == "", hover(sz))
sz = sizeCase("empty sockets, gems off", true, nil, false, true)
check("  ...with the empty-socket count showing (gems off, Empty sockets ticked) it is live, with a plain hover", not disabled(sz) and hover(sz) ~= "" and hover(sz):find("Greyed", 1, true) == nil, hover(sz))
rc.ilvl, rc.enchants, rc.gems, rc.enchantStyle, rc.socketMark = true, true, true, nil, nil; RSA()

-- 2. Blizzard Reskin > Character Reskin: "Stat list colors"; no label the same as one on Improved Character Display -------------------
local rpage = ns.BuildCharReskinPage(function() end)
check("2a. Blizzard Reskin > Character Reskin: the stat list toggle reads \"Stat list colors\"", rpage.args.stats and V(rpage.args.stats.name) == "Stat list colors",
  tostring(rpage.args.stats and V(rpage.args.stats.name)))
local function labels(node, out, path)
  for k, v in pairs(node.args or {}) do
    if type(v) == "table" and v.type ~= "description" then
      local n = V(v.name)
      if type(n) == "string" and n ~= "" then out[n] = (path ~= "" and (path .. " > ") or "") .. k end
      if v.args then labels(v, out, (path ~= "" and (path .. " > ") or "") .. k) end
    end
  end
  return out
end
local _, dpage = show()
local rl, dl, same = labels(rpage, {}, ""), labels(dpage, {}, ""), {}
for n, at in pairs(rl) do if dl[n] then same[#same + 1] = ("%q (reskin %s / display %s)"):format(n, at, dl[n]) end end
check("2b. no label on the Character Reskin page is also a label on the Improved Character Display page", #same == 0, table.concat(same, "; "))
check("2c. (review round 2) the \"Stat list colors\" hover is one sentence (UI-65)", oneSentence(V(rpage.args.stats.desc) or ""), tostring(V(rpage.args.stats.desc)))
check("  ...(guard) the Improved Character Display page still has its \"Stat list\" page", dpage.args.statListPage and V(dpage.args.statListPage.name) == "Stat list")
''')

# 3. The walkthrough (XayaUI_DevAssist/QAWalks-chardisplay-fixes.lua) run against this world with a stand-in framework: its prefilled
#    verdicts are the ones a player would be offered. (A24 #7) It checks the mark that is still greyed (Empty sockets, while the gems
#    beside the slots show) and the Text size slider: step 1 Pass after Do it for me; step 2 captures the hover; step 3 Pass; the last
#    step puts the settings back.
WALK = os.path.join(ROOT, "XayaUI_DevAssist", "QAWalks-chardisplay-fixes.lua")
lua.execute(r'''
local WALK = __WALK__
local fh = io.open(WALK, "r")
check("3. the walkthrough file is there (XayaUI_DevAssist/QAWalks-chardisplay-fixes.lua)", fh ~= nil)
if fh then
  fh:close()
  local reg = {}
  XayaUI_DevQA = { Register = function(id, def) reg[id] = def end }
  XayaUI_NS = ns
  assert(loadfile(WALK))()
  local def = reg["chardisplay-fixes"]
  check("  ...registers \"chardisplay-fixes\" with prefill and five steps", def ~= nil and def.prefill == true and #def.steps == 5)
  if def then
    local rc = RC()
    rc.ilvl, rc.enchants, rc.enchantStyle, rc.gems, rc.socketMark = false, false, "slot", false, nil; RSA()
    def.steps[1].setup()
    local ok1, note1 = def.steps[1].check()
    check("  ...step 1 after Do it for me: the Empty sockets box greyed with the reason (verdict Pass)", ok1 == true, note1)
    local ok2, note2 = def.steps[2].check()
    check("  ...step 2 (a question for the player) captures the hover text", def.steps[2].noVerdict == true and tostring(note2):find("Gems and sockets beside the slots", 1, true) ~= nil, note2)
    def.steps[3].setup()
    local ok3, note3 = def.steps[3].check()
    check("  ...step 3 after Do it for me: Text size greyed with the reason (verdict Pass)", ok3 == true, note3)
    local ok4, note4 = def.steps[4].check()
    check("  ...step 4: Character Reskin's toggle reads Stat list colors (verdict Pass)", ok4 == true, note4)
    def.steps[5].setup()
    check("  ...the last step puts Enchants, its Style, the gems and Empty sockets back as they were", rc.ilvl == false and rc.enchants == false
      and rc.enchantStyle == "slot" and rc.gems == false and rc.socketMark == nil)
  end
end
'''.replace("__WALK__", "'" + WALK.replace("\\", "/") + "'"))
# 1e (last: it stops the item details for the rest of this run)
lua.execute(r'''
local CM = ns.StatModel
local function V(x) if type(x) == "function" then return x({}) end; return x end
local function plain(text) return (tostring(text or "")):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
local function show()
  local pg = ns.BuildCharDisplayPage(function() RSA(); ns.CharDisplay_UpdateOverlays() end)
  return { sockets = pg.args.socketMark }, pg
end
local function disabled(opt) return V(opt.disabled) == true end
local function ticked(opt) return opt.get({}) == true end
local rc = RC(); rc.features, rc.gems, rc.socketMark = true, true, true; RSA()
local o, mk
-- 1e. after an error stops the item details for the session, the gems beside the slots no longer draw: the Empty sockets mark draws
-- again and its box is live again too (the box and the slot agree)
local savedSI = CM.SlotInfo
CM.SlotInfo = function() error("boom") end
RSA()
CM.SlotInfo = savedSI
ns.CharDisplay_UpdateOverlays(); o = show()
mk = plain(ns.CharDisplay_SlotMarks("Finger0Slot"))
check("1e. the item details stopped after an error: \"Empty sockets\" is live and ticked and the ring shows 1S", ns.CharDisplay_Active() == false
  and not disabled(o.sockets) and ticked(o.sockets) and mk:find("1S", 1, true) ~= nil, mk)

''')
# 4. (review round 2, SC-041) the retired term: no code identifier, comment or player-facing text in this unit's two code files says
#    "toolkit", except the kept saved key characterToolkit (a split key core shares; players never see it)
import re as _re
for rel in ("XayaUI_QoL/ImprovedCharacterDisplay.lua", "XayaUI_QoL/CharacterReskin.lua"):
    src = open(os.path.join(ROOT, rel), encoding="utf-8").read()
    left = [m.group(0) for m in _re.finditer(r"[A-Za-z_]*(?:toolkit|Toolkit|TOOLKIT|\bTK_[A-Z_]+|\btkT\b)[A-Za-z_]*", src) if m.group(0) != "characterToolkit"]
    lua.execute("check(%r, %s, %r)" % ("4. " + rel + ": no 'toolkit' left but the kept saved key characterToolkit", "true" if not left else "false", " ".join(sorted(set(left)))))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
