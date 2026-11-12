# Stub test for the Stat Calculator's columns (XayaUI_QoL 0.7.15, 0.7.20). Xaya 2026-11-05 (her words): "do multiple columns: for
# (Bonus 0.6.45, main: ported from qa-installer-branch to main's tree: the stat model and its arithmetic load from XayaUI_Bonus, and nothing of XayaUI QoL is loaded.)
# cleaner presentation * Stat | Current Value | Pt Value | etc", with a screenshot of the Primary stats section, where each line was
# "label ... value" with the detail glued into the value ("+2,671  (1 = 1.00)", "+2,396  (89.7% of Agility, mastery)").
# QoL 0.7.20, Xaya 2026-11-05 (her words, with three screenshots of the Stat Calculator): "put the input box on the far right under a
# new column "Change"", ""abilities with your number" should be renamed to "Ability Scaling"", "ability names should be nested under
# abilities".
# What it checks is what the player sees (V1, V11):
#   - every stat section of the Stats tab, and the Gear comparison's "What it changes", has a column head Stat | Current value |
#     Pt value; Rating over a rating card's rating, Change over the boxes (the far right), Note once the panel is wide enough;
#   - each line's rating, current value, Pt value and note are separate font strings, at the x and width of their column head; the
#     old "(1 = x)" text is no longer glued into the value;
#   - every box is the last cell of its row, under Change, at the content's right edge, a gutter clear of Pt value; Rating shows the
#     rating as text (and keeps yours when you type another number);
#   - "» Ability Scaling" (no "Abilities with your number" anywhere); each ability its own line one indent deeper than the "»" lines,
#     its number in the Current value column, in the model's order; no drawn text joins abilities into one list;
#   - narrow panel: the note goes under its line (from the Current value column), wide panel: in its own column, same row;
#   - layout at the smallest, default, and widest panel, text sizes 8 / 11 / 16, typed numbers: inside the width, no overlaps,
#     with font strings that report a wrapped height (estimated 0.55 x size per character); text that must fit on one line does;
#   - the hovers still carry every number (one text column: CM.PairText; main: the character window's stat tooltip lines are Enhanced
#     Tooltips', not on main, and their checks are left out);
#   - the Gear Summary is a table (Gear | Character | Elsewhere); since QoL 0.7.23 it is on the Stats tab (Character Stats > Gear Summary).
# QoL 0.7.23 (Xaya 2026-11-05): the Stats tab is one Character Stats section; the old section headers are its headings (subhead records),
# the All ratings box is gone (8 boxes, not 9), one column head per heading with lines (Core Stats, Secondaries, Tertiaries). The checks
# here follow those names; the tree itself is checked in tests/char_stat_window_run.py.
# Negative controls (V1). Checks tagged [0.7.20] are new or rewritten for QoL 0.7.20: each fails on QoL 0.7.18's files (the session
# branch head 20b805c, 2026-11-05), except those also marked "(guard)". Untagged checks are from QoL 0.7.15 and pass on 0.7.18 as well
# (behaviour this change keeps); against QoL 0.7.14 they failed, except those marked "(guard)" (behaviour that did not change then),
# "(guard, V11)" (the layout rules, which held before too) and "(setup)" (the starting state).
# QoL 0.7.28 (Xaya 2026-11-06, REQUEST-LOG #60-#67): a sixth column, Influences, between Pt value and Change: what a stat feeds ("»"
# lines) and, marked "from", what feeds it are names there on the card's own row (her answers "Names only, values on hover", "Same
# Influences column"); "» Abilities (per 100)" and "» Ability Scaling" left the Stats tab ("Both lists"); a typed number's new value is
# drawn under the current one with its sign (kind "change"), not "now -> then"; every line is indented by its depth (Stat head and cards
# at 12). The checks that drew those lines are rewritten below and say so; new checks with negative controls: char_stat_round_run.py.
# Run from the repo root: python3 tests/char_stat_columns_run.py   Needs: pip install lupa. Stand-in world: tests/char_world.lua.
# Spell IDs 9101-9103 and their texts are TEST STAND-INS.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
assert(loadfile(__WORLD__))()
-- font strings that report a wrapped height (the shared stand-in always says one line): lines = characters x 0.55 x size / width
local baseMk = mk
function mk(kind)
  local o = baseMk(kind)
  if kind == "FS" then
    o.GetStringHeight = function(self)
      local size = (self.font and self.font[2]) or 12
      local w = self.w
      if not w or w <= 0 then return size end
      return math.max(1, math.ceil(#tostring(self.text or "") * 0.55 * size / w)) * size
    end
  end
  return o
end
GetCritChanceProvidesParryEffect = function() return true end
SPELLS = { { id = 9101, name = "Fracture", desc = "Rapidly slash your target for 6,944 Physical damage." },
           { id = 9102, name = "Infernal Strike", desc = "Leap through the air, dealing 3,472 Fire damage. Recharge time reduced by Haste." },
           { id = 9103, name = "Demon Spikes", desc = "Increases your Armor by 20% for 6 sec." } }
local baseName, baseDesc = C_Spell.GetSpellName, C_Spell.GetSpellDescription
C_Spell.GetSpellName = function(id) for _, s in ipairs(SPELLS) do if s.id == id then return s.name end end; return baseName(id) end
C_Spell.GetSpellDescription = function(id) for _, s in ipairs(SPELLS) do if s.id == id then return s.desc end end; return baseDesc(id) end
C_Spell.GetSpellCharges = function(id) if id == 9102 then return { currentCharges = 2, maxCharges = 2, cooldownStartTime = 0, cooldownDuration = 9.6, chargeModRate = 1, isActive = false } end end
assert(loadfile(__MOD__))("XayaUI", ns)
ns.Provide("rules", { BuildSpellList = function(...) return ns.BuildSpellList(...) end, BuildTalentList = function(...) return ns.BuildTalentList(...) end, ForgetSpellLists = function() ns.spellList, ns.talentList = nil, nil end })   -- (P4) XayaUI Rules' "rules" service, as XayaUI_Rules/RuleDefaults.lua offers it
assert(loadfile(__COMPAT__))("XayaUI", ns)
function ns.BuildSpellList() local t = {}; for _, s in ipairs(SPELLS) do t[#t + 1] = { id = s.id, name = s.name } end; return t end
assert(loadfile(__SM__))("XayaUI_Bonus", ns)
assert(loadfile(__CM__))("XayaUI_Bonus", ns)
assert(loadfile(__CT__))("XayaUI_Bonus", ns)
-- (V25 R4) the extra lines on the character window's stat tooltips are XayaUI Bonus Features' Enhanced Tooltips' (Tooltips.lua section 5)
XayaUI_NS = ns
ns.FireReady(); ns.SettingsOpenAllForTests()   -- (P5) the module addons load after XayaUI: their settings stores open (Modules.lua section 0c)
local CM = ns.StatModel
local c = CWC()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
local statRow = mk("Frame"); statRow.Label = mk("FS"); statRow.Label.text = "Agility:"
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = { statRow }
c.enabled = true; CWA(); CharacterFrame.shown = true; PaperDollFrame:Show()
-- (QoL 0.7.40, REQUEST-LOG #88: every stat is folded by default; these checks read the lines under the stats, so every stat is open
-- here. The fold itself is checked in tests/char_stat_round2_run.py.)
setmetatable(c.statOpen, { __index = function() return true end })
CM.gcd = { dur = 1.16, haste = 29.25 }
local P = XayaUIStatCalculator
local LAY = ns.STATCALC_LAYOUT
local GUT = ns.UI_GUTTER
local function drawn() return ns.StatCalc_Drawn() end
local function render(tab) c.tab = tab or "stats"; ns.StatCalc_Render(); return drawn() end
local function setWidth(w) c.size = { w = w, h = 600 }; P.sizing = nil end   -- the panel width the corner grip would leave (content = w - 20)
local function recs(d, kind) local out = {}; for _, r in ipairs(d.layout) do if r.kind == kind then out[#out + 1] = r end end; return out end
local function find(d, kind, text, nth)
  local k = 0
  for i, r in ipairs(d.layout) do if r.kind == kind and r.text == text then k = k + 1; if k == (nth or 1) then return r, i end end end
end
-- the cells of one drawn line: its label record, then the rating / value / Pt value / note records placed for it (until the next
-- line starts)
local LINE_START = { label = true, pairLabel = true, header = true, colhead = true, input = true, cmpcell = true }
local function cellsFrom(d, i, pre)
  local out = { label = d.layout[i] }
  local function K(s) return pre == "" and s or (pre .. s:sub(1, 1):upper() .. s:sub(2)) end
  for j = i + 1, #d.layout do
    local r = d.layout[j]
    if LINE_START[r.kind] then break end
    if r.kind == K("value") then out.value = r elseif r.kind == K("per") then out.per = r elseif r.kind == K("note") then out.note = r
    elseif r.kind == K("rating") then out.rating = r end
  end
  return out
end
local function lineCells(d, labelKind, label, nth)
  local L, i = find(d, labelKind, label, nth)
  if not L then return {} end
  return cellsFrom(d, i, labelKind == "pairLabel" and "pair" or "")
end
-- the lines nested under a "»" line: the pair lines right after it whose name sits further right than its own
local function nested(d, head, nth)
  local H, i = find(d, "pairLabel", head, nth)
  local out = {}
  if not H then return out end
  for j = i + 1, #d.layout do
    local r = d.layout[j]
    if r.kind == "pairLabel" and r.x > H.x then out[#out + 1] = cellsFrom(d, j, "pair")
    elseif LINE_START[r.kind] then break end
  end
  return out
end
local function T(r) return r and tostring(r.text) or "nil" end
-- (QoL 0.7.28) the Influences names drawn on a card's row (kinds "infl" and "feed"), in order, joined with " "
local function inflOn(d, label)
  local L = find(d, "label", label)
  if not L then return nil end
  local nextY = math.huge
  for _, r in ipairs(recs(d, "label")) do if r.y > L.y and r.y < nextY then nextY = r.y end end
  local out = {}
  for _, r in ipairs(d.layout) do if (r.kind == "infl" or r.kind == "feed") and r.y >= L.y and r.y < nextY then out[#out + 1] = tostring(r.text) end end
  return table.concat(out, " ")
end
local function nameHover(d, key)
  for _, b in ipairs(d.buttons) do if b.shown and b.item and b.item.key == key then GameTooltip.lines = {}; b.scripts.OnEnter(b); return table.concat(GameTooltip.lines or {}, " / "), b end end
  return ""
end
local function at(r, h) return r ~= nil and h ~= nil and r.x == h.x and r.w == h.w end
-- the shown font string with this text (the panel's own font strings, not the layout records)
local function font(d, text) for _, f in ipairs(d.fonts) do if f.shown and f.text == text then return f end end end
local function fontX(f) local pt = f and f.pts and f.pts[#f.pts]; return pt and pt[4] end
local function layoutOK(dd)
  local W = LAY.content
  for _, r in ipairs(dd.layout) do
    if r.x < 0 or r.x + r.w > W + 0.01 or r.w <= 0 then return false, r.kind .. " " .. tostring(r.text) .. " x=" .. r.x .. " w=" .. r.w end
  end
  local t = {}
  -- (QoL 0.7.28: a bucket bar's band and the Gear Summary's bars and tiles are drawn behind their text)
  local FILL = { hit = true, cell = true, bucketbar = true, gsbar = true, gstile = true, gsseg = true, gscol = true, gsswatch = true }
  for _, r in ipairs(dd.layout) do if not FILL[r.kind] then t[#t + 1] = r end end
  for i = 1, #t do for j = i + 1, #t do
    local a, bb = t[i], t[j]
    if a.x < bb.x + bb.w and bb.x < a.x + a.w and a.y < bb.y + bb.h and bb.y < a.y + a.h then
      return false, a.kind .. " '" .. tostring(a.text) .. "' / " .. bb.kind .. " '" .. tostring(bb.text) .. "'"
    end
  end end
  return true
end
-- every box: the last cell of its row (its right edge at the content's edge), under a Change head (same x and width), and every other
-- cell that shares its rows ends a gutter left of it (Pt value included); the box frame itself is anchored there
local function boxesOK(dd, wantN)
  local W = LAY.content
  local heads = {}
  for _, r in ipairs(recs(dd, "colhead")) do if r.text == "Change" then heads[#heads + 1] = r end end
  if #heads == 0 then return false, "no Change head" end
  local n = 0
  for _, b in ipairs(recs(dd, "input")) do
    n = n + 1
    if b.x + b.w ~= W then return false, b.text .. " right edge " .. (b.x + b.w) .. " ~= " .. W end
    if b.x ~= heads[1].x or b.w ~= heads[1].w then return false, b.text .. " not under Change" end
    local f = dd.boxes[b.text]
    local pt = f and f.pts and f.pts[#f.pts]
    if not (pt and pt[4] == b.x and f.w == b.w) then return false, b.text .. " frame at " .. tostring(pt and pt[4]) end
    for _, r in ipairs(dd.layout) do
      if r ~= b and r.kind ~= "hit" and r.kind ~= "bucketbar" and r.y < b.y + b.h and b.y < r.y + r.h and r.x + r.w > b.x - GUT then
        return false, r.kind .. " '" .. tostring(r.text) .. "' reaches the " .. b.text .. " box (" .. (r.x + r.w) .. " > " .. (b.x - GUT) .. ")"
      end
    end
  end
  if wantN and n ~= wantN then return false, n .. " boxes" end
  return true
end
-- a text that names an ability is that name alone (a list joined into one text, or a name with its number, fails)
local ABILITIES = { "Fracture", "Infernal Strike", "Demon Spikes" }
local function joinedText(dd)
  for _, r in ipairs(dd.layout) do
    if r.kind ~= "hit" then
      local t = tostring(r.text or "")
      for _, a in ipairs(ABILITIES) do if t:find(a, 1, true) and t ~= a then return r.kind .. " '" .. t .. "'" end end
    end
  end
end
-- one line by the estimate the wrapped heights use (0.55 x size per character)
local function fits(r) return r ~= nil and #tostring(r.text or "") * 0.55 * (r.size or 0) <= r.w + 0.01 end

-- 1. Default panel (450 wide since QoL 0.7.21, content 430): Primary stats as in her screenshot ------------------------------------------------
c.size = nil
local d = render()
check("[0.7.21] (setup) the default content width is 430 (the panel 450; Xaya: \"up to 450px\")", LAY.content == 430, LAY.content)
local hStat, hVal, hPer = find(d, "colhead", "Stat"), find(d, "colhead", "Current value"), find(d, "colhead", "Pt value")
check("Primary stats has a column head: Stat | Current value | Pt value (QoL 0.7.28: Stat at depth 1, x 12, over the stat names)", hStat and hVal and hPer and hStat.x == 12 and hStat.y < hVal.y + 1 and hVal.y == hPer.y
  and hVal.y > find(d, "subhead", "Core Stats").y and hVal.y < (find(d, "label", "Agility") or { y = -1 }).y, T(hStat) .. " " .. T(hVal) .. " " .. T(hPer))
check("  ...the head reads left to right Stat, Current value, Pt value; no Note head on a narrow panel (the note goes under its line)",
  hStat and hVal and hPer and hStat.x < hVal.x and hVal.x < hPer.x and find(d, "colhead", "Note") == nil)
local hCh = find(d, "colhead", "Change")
check("[0.7.20] Primary stats' head ends with Change, after Pt value, at the content's right edge (the far right)", hCh and hPer and hCh.y == hPer.y
  and hCh.x >= hPer.x + hPer.w + GUT and hCh.x + hCh.w == LAY.content, T(hCh))
local hRat1 = find(d, "colhead", "Rating")
check("[0.7.20] (guard) ...no Rating head over Primary stats (no rating there): the first Rating head is Secondary stats'", hRat1 and hVal and hRat1.y > hVal.y
  and hRat1.y > find(d, "subhead", "Secondaries").y, T(hRat1))
local agi = lineCells(d, "label", "Agility")
check("Agility: its current value 2,637 sits in the Current value column (same x and width as the head)", T(agi.value) == "2,637" and at(agi.value, hVal), T(agi.value))
local agiBox = find(d, "input", "sv:primary")
check("[0.7.20] Agility's box (2637) is under Change on Agility's row: the head's x and width, its right edge at the content's edge",
  agiBox and agi.label and at(agiBox, hCh) and agiBox.y == agi.label.y and agiBox.x + agiBox.w == LAY.content and d.boxes["sv:primary"].text == "2637",
  agiBox and (agiBox.x .. "," .. agiBox.y .. " w " .. agiBox.w))
local agiF = d.boxes["sv:primary"]
local agiPt = agiF and agiF.pts[#agiF.pts]
check("[0.7.20] ...the box frame itself is anchored there (TOPLEFT x = the Change head's x, its width the head's)", agiPt and hCh and agiPt[4] == hCh.x and agiF.w == hCh.w,
  agiPt and agiPt[4])
check("[0.7.20] ...it is the last cell of its row: Agility's name, value and every other cell on that row end a gutter left of it",
  (function() if not agiBox then return false end
    for _, r in ipairs(d.layout) do
      if r ~= agiBox and r.kind ~= "hit" and r.kind ~= "bucketbar" and r.y < agiBox.y + agiBox.h and agiBox.y < r.y + r.h and r.x + r.w > agiBox.x - GUT then return false end
    end
    return true end)())
-- (QoL 0.7.28) the » lines are names in the Influences column now; their numbers are in each name's hover
local hInfl = find(d, "colhead", "Modifies")
check("[0.7.28] Agility's Influences on its own row: Attack power, Dodge, Armor (names only), in the Influences column between Pt value and Change",
  inflOn(d, "Agility") == "Attack power, Dodge, Armor" and hInfl and hInfl.x > hPer.x + hPer.w and hInfl.x + hInfl.w <= hCh.x - GUT
  and find(d, "pairLabel", "» Attack power") == nil, inflOn(d, "Agility"))
local hvAP = nameHover(d, "map_primary:» Attack power")
check("[0.7.28] ...hovering Attack power: its value +2,637 and Pt value (1 = 1.00); the old '(1 = x)' is not drawn in the grid", hvAP:find("» Attack power | +2,637  (1 = 1.00)", 1, true) ~= nil
  -- (QoL 0.7.40, #88: Attack Power's own "from Agility +2,637" row draws that number under Attack Power; it is not on Agility's row)
  and (function() local L = find(d, "label", "Agility"); for _, r in ipairs(d.layout) do if r.text == "+2,637" and L and math.abs(r.y - L.y) < 1 then return false end end; return L ~= nil end)(), hvAP)
check("[0.7.28] ...hovering Armor: +2,684 (1 = 1.02); no note text anywhere ('101.8% of Agility, mastery' drawn nowhere)", nameHover(d, "map_primary:» Armor"):find("» Armor | +2,684  (1 = 1.02)", 1, true) ~= nil
  and (function() for _, r in ipairs(d.layout) do if tostring(r.text):find("101.8% of Agility, mastery", 1, true) then return false end end; return true end)())
check("[0.7.28] ...hovering Dodge: +5.00%, no Pt value", nameHover(d, "map_primary:» Dodge"):find("» Dodge | +5.00%", 1, true) ~= nil, nameHover(d, "map_primary:» Dodge"))
local function drawnText(s) for _, r in ipairs(d.layout) do if tostring(r.text):find(s, 1, true) then return r end end end
check("[0.7.28] no » Abilities (per 100) and no nested ability line on the Stats tab (her answer \"Both lists\")", drawnText("Abilities (per 100)") == nil
  and find(d, "pairLabel", "Fracture") == nil, T(drawnText("Abilities (per 100)")))
check("[0.7.28] Stamina's Influences: Health; hover 1,476,516 (1 = 21.20)", inflOn(d, "Stamina") == "Health" and nameHover(d, "map_stamina:» Health"):find("» Health | 1,476,516  (1 = 21.20)", 1, true) ~= nil,
  inflOn(d, "Stamina"))
-- every line of every Stats section: the same columns
local heads = recs(d, "colhead")
local nVal, nCh, nRat = 0, 0, 0
for _, r in ipairs(heads) do
  if r.text == "Current value" then nVal = nVal + 1 elseif r.text == "Change" then nCh = nCh + 1 elseif r.text == "Rating" then nRat = nRat + 1 end
end
check("every part of Character Stats with stat lines has the column head (Core Stats, Secondaries, Tertiaries: 3; QoL 0.7.23)", nVal == 3, nVal)
check("[0.7.20] a Change head over the three parts with boxes (Core Stats, Secondaries, Tertiaries), none over the Gear Summary (QoL 0.7.28: its own section at the top); Rating over Secondaries and Tertiaries",
  nCh == 3 and nRat == 2 and find(d, "colhead", "Change", 1).y > find(d, "header", "- Character Stats").y, nCh .. " Change, " .. nRat .. " Rating")
local function allAt(kinds, h)
  for _, k in ipairs(kinds) do for _, r in ipairs(recs(d, k)) do
    if not at(r, h) then return false, k .. " '" .. tostring(r.text) .. "' x=" .. r.x .. " w=" .. r.w end
  end end
  return true
end
local okV, whyV = allAt({ "value", "pairValue" }, hVal)
check("every current value on the Stats tab sits at the Current value head's x and width", okV, whyV)
local okP, whyP = allAt({ "per", "pairPer" }, hPer)
check("every Pt value on the Stats tab sits at the Pt value head's x and width", okP and #recs(d, "per") >= 4, whyP or #recs(d, "per"))
local glued
for _, k in ipairs({ "value", "pairValue", "per", "pairPer" }) do for _, r in ipairs(recs(d, k)) do
  local t = tostring(r.text)
  if t:find("(", 1, true) or t:find(";", 1, true) or t:find("of Agility", 1, true) or t:find("before DR", 1, true) then glued = k .. " '" .. t .. "'" end
end end
check("no value or Pt value cell carries a note in brackets (nothing glued)", glued == nil, glued)
-- rating cards: Stat | Rating (the rating as text) | Current value | Pt value | Change (the box)
local hRat, hVal2, hPer2, hCh2 = find(d, "colhead", "Rating"), find(d, "colhead", "Current value", 2), find(d, "colhead", "Pt value", 2), find(d, "colhead", "Change", 2)
check("[0.7.20] Secondary stats' head: Stat | Rating | Current value | Pt value | Change, left to right on one row, Change at the right edge",
  hRat and hVal2 and hPer2 and hCh2 and hRat.y == hVal2.y and hCh2.y == hVal2.y and hRat.x < hVal2.x and hVal2.x < hPer2.x and hPer2.x < hCh2.x
  and hCh2.x + hCh2.w == LAY.content, T(hRat) .. " " .. T(hCh2))
local cr = lineCells(d, "label", "Critical Strike")
check("[0.7.20] Critical Strike: the Rating column shows your rating 528 as text, at the Rating head's x and width, on the card's line",
  T(cr.rating) == "528" and at(cr.rating, hRat) and cr.label and cr.rating.y == cr.label.y, T(cr.rating))
local crBox = find(d, "input", "sv:crit")
check("[0.7.20] ...the crit box (528) is under Change on that line, and Pt value 46.0 / 1% ends a gutter left of it", crBox and cr.label and at(crBox, hCh2)
  and crBox.y == cr.label.y and d.boxes["sv:crit"].text == "528" and cr.per and cr.per.x + cr.per.w + GUT <= crBox.x, crBox and crBox.x)
check("Critical Strike: 22.48% in Current value, 46.0 / 1% (rating per 1%, #382) in Pt value", T(cr.value) == "22.48%" and at(cr.value, hVal2)
  and T(cr.per) == "46.0 / 1%" and at(cr.per, hPer2), T(cr.value) .. " | " .. T(cr.per))
local rh, rm, rv = lineCells(d, "label", "Haste"), lineCells(d, "label", "Mastery"), lineCells(d, "label", "Versatility")
check("[0.7.20] every rating card shows its rating under Rating: Haste 1,200, Mastery 997, Versatility 120", T(rh.rating) == "1,200" and T(rm.rating) == "997"
  and T(rv.rating) == "120" and at(rh.rating, hRat) and at(rm.rating, hRat) and at(rv.rating, hRat), T(rh.rating) .. " " .. T(rm.rating) .. " " .. T(rv.rating))
local okR, whyR = allAt({ "rating" }, hRat)
check("[0.7.20] every rating on the Stats tab sits at the Rating head's x and width (7: 4 secondary, 3 tertiary; none on Primary)",
  okR and #recs(d, "rating") == 7, whyR or #recs(d, "rating"))
local okB, whyB = boxesOK(d, 8)
check("[0.7.20] every box on the Stats tab (8: Agility, 4 secondary, 3 tertiary; All ratings gone in QoL 0.7.23) is under Change, at the right edge, the last cell of its row",
  okB, whyB)
check("  (QoL 0.7.28) Critical Strike's Influences: Parry; hover +10.15% (52.0 crit rating = 1% parry), no \"before DR\" drawn", inflOn(d, "Critical Strike") == "Parry"
  and nameHover(d, "map_crit:» Parry"):find("» Parry | +10.15%  (52.0 crit rating = 1% parry)", 1, true) ~= nil and drawnText("before DR") == nil, inflOn(d, "Critical Strike"))
local dr = lineCells(d, "pairLabel", "Diminishing returns")
check("  Diminishing returns: value none yet; no note (\"next at 1,380 rating (852 away)\" is gone)", T(dr.value) == "none yet" and dr.note == nil
  and drawnText("next at 1,380 rating") == nil, T(dr.value) .. " | " .. T(dr.note))
check("[0.7.28] Haste's Influences: GCD (QoL 0.7.39, UI-62), Attack speed, Abilities; the ability and its recharge are in that name's hover, indented",
  inflOn(d, "Haste") == "GCD, Attack speed, Abilities"
  and nameHover(d, "map_haste:» Abilities"):find("    Infernal Strike | 9.6 s recharge", 1, true) ~= nil and find(d, "pairLabel", "Infernal Strike") == nil,
  inflOn(d, "Haste"))
check("[0.7.20] no comma-joined ability list remains on the Stats tab: every drawn text that names an ability is that name alone", joinedText(d) == nil, joinedText(d))
local ok1, why1 = layoutOK(d)
check("(guard, V11) layout, default width: inside the width, no overlaps (wrapped heights)", ok1, why1)

-- 2. Wide panel (760: content 740): the note gets its own column ------------------------------------------------------------
setWidth(760)
d = render()
-- (QoL 0.7.24) no Note column at any width: the heads are exactly Stat | Rating | Current value | Pt value | Change
hVal, hPer, hCh = find(d, "colhead", "Current value"), find(d, "colhead", "Pt value"), find(d, "colhead", "Change")
-- (the Gear Summary's own table, Gear | Character | Elsewhere, is not a grid head)
local headSet, extra = { Stat = true, Rating = true, ["Current value"] = true, ["Pt value"] = true, Change = true, Modifies = true, Gear = true, Character = true, Elsewhere = true }, {}
for _, r in ipairs(recs(d, "colhead")) do if not headSet[r.text] then extra[#extra + 1] = r.text end end
local hRat = find(d, "colhead", "Rating")
local rowHeads = {}
for _, r in ipairs(recs(d, "colhead")) do if hRat and r.y == hRat.y then rowHeads[#rowHeads + 1] = r end end
table.sort(rowHeads, function(x, y) return x.x < y.x end)
local rh = {}
for _, r in ipairs(rowHeads) do rh[#rh + 1] = r.text end
check("wide panel: no Note column head; a rated section's head reads exactly Stat | Rating | Current value | Pt value | Modifies | Change (QoL 0.7.28 Influences; Modifies since 0.7.40, #88), Change at the far right",
  find(d, "colhead", "Note") == nil and #extra == 0 and table.concat(rh, " | ") == "Stat | Rating | Current value | Pt value | Modifies | Change"
  and hCh.x + hCh.w == LAY.content and LAY.content == 740, table.concat(rh, " | ") .. " / extra: " .. table.concat(extra, ","))
check("[0.7.28] ...wide panel: Agility's Influences on one line in their column, no » line drawn as a row", inflOn(d, "Agility") == "Attack power, Dodge, Armor"
  and (function() local ys = {}; for _, r in ipairs(recs(d, "infl")) do ys[r.y] = true end; local n = 0; for _ in pairs(ys) do n = n + 1 end; return n >= 1 end)()
  and find(d, "pairLabel", "» Armor") == nil, inflOn(d, "Agility"))
check("  ...no note text anywhere on the Stats tab (no note or pairNote cell; \"cast any spell to read it\", \"with your numbers: not given by the game\" gone)",
  #recs(d, "note") == 0 and #recs(d, "pairNote") == 0 and drawnText("cast any spell to read it") == nil and drawnText("with your numbers") == nil,
  #recs(d, "note") .. " / " .. #recs(d, "pairNote"))
okB, whyB = boxesOK(d, 8)
check("[0.7.20] ...every box is still the last cell of its row, under Change", okB, whyB)

-- 3. Layout (V11): smallest, default, just below and at the wide threshold, widest; text sizes; typed numbers ----------------
ns.StatCalc_SetInput("sv:crit", "700"); ns.StatCalc_SetInput("sv:primary", "2737"); ns.StatCalc_SetInput("sv:haste", "1500")
for _, pw in ipairs({ 340, 380, 450, 583, 584, 760 }) do
  for _, fs in ipairs({ 8, 11, 16 }) do
    c.fontSize = fs; setWidth(pw)
    local dd = render()
    local ok, why = layoutOK(dd)
    check(("(guard, V11) layout, panel %d wide, text size %d, typed numbers: inside the width, no overlaps"):format(pw, fs), ok, why)
    local okb, whyb = boxesOK(dd, 8)
    check(("[0.7.20] (V11) panel %d wide, text size %d: every box is under Change at the right edge, a gutter clear of Pt value and every other cell of its row"):format(pw, fs), okb, whyb)
  end
end
c.fontSize = 11
setWidth(450)
d = render()
hVal, hPer, hRat, hCh = find(d, "colhead", "Current value"), find(d, "colhead", "Pt value"), find(d, "colhead", "Rating"), find(d, "colhead", "Change")
check("[0.7.28] typed Agility: no » Ability Scaling and no nested ability line on the Stats tab (the Ability Scaling tab carries it)", drawnText("Ability Scaling") == nil
  and drawnText("Abilities with your number") == nil and find(d, "pairLabel", "Fracture") == nil)
check("[0.7.20] no comma-joined ability list with typed numbers either", joinedText(d) == nil, joinedText(d))
check("[0.7.28] typed Agility: hovering Attack power shows +2,637 (1 = 1.00) and under it +2,737 (the new value with its sign)",
  nameHover(d, "map_primary:» Attack power"):find("» Attack power | +2,637  (1 = 1.00) /  | +2,737", 1, true) ~= nil, nameHover(d, "map_primary:» Attack power"))
cr = lineCells(d, "label", "Critical Strike")
crBox = find(d, "input", "sv:crit")
local crCh
for _, r in ipairs(recs(d, "change")) do if cr.value and r.x == cr.value.x and r.y > cr.value.y and not crCh then crCh = r end end
check("[0.7.21] typed 700 crit: Rating shows your 528 and the change, 528 +172; the box under Change holds 700, Current value 22.48% with +26.22% under it (QoL 0.7.28)", T(cr.rating) == "528 +172"
  and d.boxes["sv:crit"].text == "700" and crBox and crBox.x == hCh.x and T(cr.value) == "22.48%" and T(crCh) == "+26.22%", T(cr.rating) .. " | " .. T(cr.value) .. " | " .. T(crCh))
-- text that must sit on one line does (the estimate): the heads, ratings, Pt values, the nested abilities, the » line's name
local long
for _, r in ipairs(d.layout) do
  -- (QoL 0.7.28: with the sixth column, Influences, at the same 450 width a 10-character rating such as "1,200 +300" may wrap at its
  -- space, and an Influences name inside its narrow column; both reported. "528 +172" still fits, and no word is ever cut.)
  local must = (r.kind == "colhead" and (r.text == "Rating" or r.text == "Change" or r.text == "Current value" or r.text == "Pt value" or r.text == "Modifies"))
    or (r.kind == "rating" and #tostring(r.text) <= 8) or r.kind == "per" or r.kind == "pairPer"
  -- (QoL 0.7.21's "every name fits at the default 450" no longer holds with the sixth column: "Critical Strike" wraps at its space; reported)
  if must and not fits(r) then long = r.kind .. " '" .. tostring(r.text) .. "' w " .. r.w end
  if (r.kind == "rating" or r.kind == "infl" or r.kind == "feed" or r.kind == "label") then
    for w in tostring(r.text):gmatch("%S+") do if #w * 0.55 * r.size > r.w + 0.01 then long = r.kind .. " '" .. tostring(r.text) .. "' cuts '" .. w .. "'" end end
  end
end
check("[0.7.20] text fits on one line (0.55 x size per character), default panel, text size 11, typed numbers: the Rating, Change and Influences heads, every rating up to 8 characters, every Pt value; no rating, stat name or Influences word cut",
  long == nil and #recs(d, "rating") == 7, long)
local fRat = font(d, "528 +172")
check("[0.7.21] ...and '528 +172' is a font string of its own at the Rating column's x (the player's screen)", fRat and hRat and fontX(fRat) == hRat.x and fRat.w == hRat.w, fRat and fontX(fRat))
-- the panel hover with typed numbers: no Ability Scaling in it (QoL 0.7.28)
local agiHover
for _, b in ipairs(d.buttons) do if b.shown and b.item and b.item.key == "map_primary" and not agiHover then agiHover = b end end   -- (the card's row: made first)
GameTooltip.lines = {}
if agiHover then agiHover.scripts.OnEnter(agiHover) end
local tlT = table.concat(GameTooltip.lines or {}, " / ")
check("[0.7.28] the Agility hover with typed numbers: » Attack power +2,637 (1 = 1.00) with +2,737 on the line under it; no Ability Scaling in it",
  tlT:find("» Attack power | +2,637  (1 = 1.00) /  | +2,737", 1, true) ~= nil and tlT:find("Ability Scaling", 1, true) == nil and tlT:find("bilities with your number", 1, true) == nil, tlT)
local hInfl2 = find(d, "colhead", "Modifies")
check("[0.7.28] ...the card's hover covers its row up to the Influences column (names hover on their own; the box stays clickable)", agiHover and hInfl2 and agiHover.w == hInfl2.x - GUT, agiHover and agiHover.w)
ns.StatCalc_SetInput("sv:crit", ""); ns.StatCalc_SetInput("sv:primary", ""); ns.StatCalc_SetInput("sv:haste", "")
c.size = nil

-- 4. Hovers and the character window's tooltips keep every number -------------------------------------------------------------
d = render()
local function tipLines(b) GameTooltip.lines = {}; b.scripts.OnEnter(b); return GameTooltip.lines end
local function has(lines, s) for _, l in ipairs(lines) do if tostring(l):find(s, 1, true) then return true end end; return false end
local function idx(lines, s) for i, l in ipairs(lines) do if tostring(l) == s then return i end end end
local agiLabel
for _, b in ipairs(d.buttons) do if b.shown and b.item and b.item.key == "map_primary" and not agiLabel then agiLabel = b end end
local tl = agiLabel and tipLines(agiLabel) or {}
-- (QoL 0.7.54; Xaya 2026-11-08, her answer "Hide notes unless Dev Assist") the notes show only while XayaUI Dev Assist is loaded
check("(QoL 0.7.54) without XayaUI Dev Assist the Agility hover has no notes, its number rows stay", not has(tl, "GetAttackPowerForStat") and has(tl, "» Attack power | +2,637"), table.concat(tl, " / "))
ns.DevAssistOn = function() return true end
tl = agiLabel and tipLines(agiLabel) or {}
ns.DevAssistOn = nil
check("hovering the Agility card shows where the numbers come from (with XayaUI Dev Assist)", has(tl, "GetAttackPowerForStat"), table.concat(tl, " / "))
check("(guard) the Agility hover lists » Attack power with its Pt value: '+2,637  (1 = 1.00)'", has(tl, "» Attack power | +2,637  (1 = 1.00)"), table.concat(tl, " / "))
check("  ...and » Armor with its Pt value, no note (QoL 0.7.24: the note text is not moved to the hover): '+2,684  (1 = 1.02)'", has(tl, "» Armor | +2,684  (1 = 1.02)")
  and not has(tl, "» Armor | +2,684  (1 = 1.02); 101.8% of Agility, mastery"), table.concat(tl, " / "))
check("[0.7.28] the Agility hover has no » Abilities (per 100) and no ability lines (her answer \"Both lists\")", not has(tl, "Abilities (per 100)") and not has(tl, "Fracture"), table.concat(tl, " / "))
-- (the character window's stat tooltips: Enhanced Tooltips' lines, not on main; their checks are left out of the main port)

-- 5. The Gear tab: QoL 0.7.24 (Xaya 2026-11-05: "side by side and what it changes options are redundant. Rename the section to
-- "Changes""): one Changes table, Stat | Pt value | Equipped | each picked item; the stat map's lines that change are its "Stat effects"
-- rows (now in Equipped, then in the item's column); Ability Scaling became "Spell Changes". (Before: "What it changes" in the stat
-- grid's columns, Current value "now -> then".) The full checks of the new section are in tests/char_spells_compare_run.py.
CM.gearSlot = 1; ns.StatCalc_SetInput("item", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
d = render("gear")
local gChg = find(d, "header", "- Changes")
local hEq, hIt, hPt = find(d, "mhead", "Equipped"), find(d, "mhead", "Better Helm"), find(d, "mhead", "Pt value")
check("Gear > Changes: a column head Stat | Pt value | Equipped | Better Helm under its header (no What it changes, no Side by side)",
  gChg and hEq and hIt and hPt and hEq.y > gChg.y and hPt.x < hEq.x and hEq.x < hIt.x and find(d, "header", "- What it changes") == nil
  and find(d, "header", "- Side by side") == nil, T(hEq))
-- one row of the table: its label record and the cells placed after it (until the next label)
local function mrow(label, nth)
  local L, i = find(d, "mlabel", label, nth)
  local out = { label = L, cells = {}, subs = {} }
  if not L then return out end
  for j = i + 1, #d.layout do
    local r = d.layout[j]
    if r.kind == "mlabel" or r.kind == "msubhead" or r.kind == "mnote" or r.kind == "header" then break end
    if r.kind == "mcell" then out.cells[#out.cells + 1] = r elseif r.kind == "msub" then out.subs[#out.subs + 1] = r elseif r.kind == "mper" then out.per = r end
  end
  return out
end
local gap = mrow("» Attack power")
check("  ...+100 Agility: » Attack power +2,637 in Equipped, +2,737 in Better Helm's column, 1.00 in Pt value", T(gap.cells[1]) == "+2,637" and T(gap.cells[2]) == "+2,737"
  and gap.cells[1].x == hEq.x and gap.cells[2].x == hIt.x and T(gap.per) == "1.00" and gap.per.x == hPt.x, T(gap.cells[1]) .. " | " .. T(gap.cells[2]) .. " | " .. T(gap.per))
local sch = find(d, "msubhead", "Spell Changes")
local fr, inf = mrow("Fracture"), mrow("Infernal Strike", 2)   -- (the first Infernal Strike row is under haste, Stat effects)
check("[0.7.24] ...Ability Scaling is now Spell Changes, after the stat rows: Fracture 6,944 -> 7,144, Infernal Strike 3,472 -> 3,572",
  sch and fr.label and fr.label.y > sch.y and T(fr.cells[1]) == "6,944" and T(fr.cells[2]) == "7,144" and T(inf.cells[1]) == "3,472" and T(inf.cells[2]) == "3,572"
  and find(d, "mlabel", "» Ability Scaling") == nil, T(fr.cells[2]))
local gha = find(d, "mlabel", "» Abilities")
local ghi = mrow("Infernal Strike", 1)
check("[0.7.20] ...200 less haste: haste's ability kept under its » line, nested one indent further: Infernal Strike 9.6 s -> a longer recharge",
  gha and ghi.label and ghi.label.y > gha.y and ghi.label.x > gha.x and T(ghi.cells[1]) == "9.6 s" and T(ghi.cells[2]):find("^%d+%.%d s recharge$") ~= nil,
  T(ghi.cells[1]) .. " | " .. T(ghi.cells[2]))
check("[0.7.20] ...no comma-joined ability list on the Gear tab", joinedText(d) == nil, joinedText(d))
local gHealth = mrow("» Health")
check("  ...+900 Stamina: » Health 1,476,516 -> 1,495,596 and Pt value 21.20", T(gHealth.cells[1]) == "1,476,516" and T(gHealth.cells[2]) == "1,495,596" and T(gHealth.per) == "21.20",
  T(gHealth.cells[2]) .. " | " .. T(gHealth.per))
-- (QoL 0.7.23: the Summary is drawn on the Stats tab, Character Stats > Gear Summary)
local dG = d
c.gearSumStyle = "table"   -- (QoL 0.7.28: the Gear Summary's Table style keeps the table; the default is Split bars)
d = render("stats")
local sGear, sChar, sElse = find(d, "colhead", "Gear"), find(d, "colhead", "Character"), find(d, "colhead", "Elsewhere")
check("Gear Summary (Stats tab): a table with Gear | Character | Elsewhere heads", sGear and sChar and sElse and sGear.x < sChar.x and sChar.x < sElse.x, T(sGear))
local sumHead, sumLabel = find(d, "header", "- Gear Summary"), nil
for _, r in ipairs(recs(d, "label")) do if not sumLabel and sumHead and r.text == "Critical Strike" and r.y > sumHead.y then sumLabel = r end end
local sc2 = {}
for _, r in ipairs(recs(d, "cmpcell")) do if sumLabel and r.y == sumLabel.y then sc2[#sc2 + 1] = r end end
check("  ...Critical Strike: 400 | 528 | +128, each in its own cell under its head", #sc2 == 3 and sc2[1].text == "400" and sc2[2].text == "528" and sc2[3].text == "+128"
  and sc2[1].x == sGear.x and sc2[2].x == sChar.x and sc2[3].x == sElse.x, #sc2)
c.gearSumStyle = nil
for _, fs in ipairs({ 8, 11, 16 }) do
  c.fontSize = fs
  local ok, why = layoutOK(render("gear"))
  check("(guard, V11) layout, Gear with a comparison, text size " .. fs .. ": inside the width, no overlaps", ok, why)
end
c.fontSize = 11; ns.StatCalc_SetInput("item", ""); CM.gearSlot = nil

-- 6. What did not change ------------------------------------------------------------------------------------------------------
c.advanced = true
d = render("spells")
-- (QoL 0.7.24: the spell lines are columns now: Value | % PSV with "1 Agility = +N" under it)
local spv, spp, spr = find(d, "spellvalue", "6,944"), nil, nil
for _, r in ipairs(recs(d, "spellpct")) do if spv and r.y == spv.y then spp = r end end
for _, r in ipairs(recs(d, "spellper")) do if spp and r.x == spp.x and r.y > spp.y and not spr then spr = r end end
check("(guard) the Spells tab keeps its numbers: '6,944' | '... of attack power' with '1 Agility = N' under it", spv ~= nil and spp ~= nil
  and tostring(spp.text):find("of attack power", 1, true) ~= nil and spr ~= nil and tostring(spr.text):find("^1 Agility = %d") ~= nil, T(spp))
c.advanced = false
d = render()
check("(guard) no Show: % button (#382; QoL 0.7.40, B2: not made at all, the settings' Rating lines gone too)", P.modeBtn == nil)
'''.replace("__WORLD__", P("tests/char_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
   .replace("__SM__", P("XayaUI_Bonus/StatMath.lua")).replace("__CM__", P("XayaUI_Bonus/StatModel.lua")).replace("__CT__", P("XayaUI_Bonus/StatCalculator.lua")))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
