# Stub test for the Stat Calculator's columns (XayaUI_QoL 0.7.15, 0.7.20). Xaya 2026-11-05 (her words): "do multiple columns: for
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
#   - the hovers and the character window's stat tooltips still carry every number (one text column: CM.PairText);
#   - the Gear Summary is a table (Gear | Character | Elsewhere); since QoL 0.7.23 it is on the Stats tab (Character Stats > Gear Summary).
# QoL 0.7.23 (Xaya 2026-11-05): the Stats tab is one Character Stats section; the old section headers are its headings (subhead records),
# the All ratings box is gone (8 boxes, not 9), one column head per heading with lines (Core Stats, Secondaries, Tertiaries). The checks
# here follow those names; the tree itself is checked in tests/char_stat_window_run.py.
# Negative controls (V1). Checks tagged [0.7.20] are new or rewritten for QoL 0.7.20: each fails on QoL 0.7.18's files (the session
# branch head 20b805c, 2026-11-05), except those also marked "(guard)". Untagged checks are from QoL 0.7.15 and pass on 0.7.18 as well
# (behaviour this change keeps); against QoL 0.7.14 they failed, except those marked "(guard)" (behaviour that did not change then),
# "(guard, V11)" (the layout rules, which held before too) and "(setup)" (the starting state).
# Run from the repo root: python3 tests/char_stat_columns_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua.
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
assert(loadfile(__COMPAT__))("XayaUI", ns)
function ns.BuildSpellList() local t = {}; for _, s in ipairs(SPELLS) do t[#t + 1] = { id = s.id, name = s.name } end; return t end
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
ns.FireReady()
local CM = ns.CharModel
local c = ns.CharToolkit_Cfg()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
local statRow = mk("Frame"); statRow.Label = mk("FS"); statRow.Label.text = "Agility:"
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = { statRow }
c.enabled = true; ns.CharToolkit_Apply(); CharacterFrame.shown = true; PaperDollFrame:Show()
CM.gcd = { dur = 1.16, haste = 29.25 }
local P = XayaUICharacterToolkit
local LAY = ns.CHARTOOLKIT_LAYOUT
local GUT = ns.UI_GUTTER
local function drawn() return ns.CharToolkit_Drawn() end
local function render(tab) c.tab = tab or "stats"; ns.CharToolkit_Render(); return drawn() end
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
  for _, r in ipairs(dd.layout) do if r.kind ~= "hit" and r.kind ~= "cell" then t[#t + 1] = r end end
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
      if r ~= b and r.kind ~= "hit" and r.y < b.y + b.h and b.y < r.y + r.h and r.x + r.w > b.x - GUT then
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
check("Primary stats has a column head: Stat | Current value | Pt value", hStat and hVal and hPer and hStat.x == 0 and hStat.y < hVal.y + 1 and hVal.y == hPer.y
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
      if r ~= agiBox and r.kind ~= "hit" and r.y < agiBox.y + agiBox.h and agiBox.y < r.y + r.h and r.x + r.w > agiBox.x - GUT then return false end
    end
    return true end)())
local ap = lineCells(d, "pairLabel", "» Attack power")
check("» Attack power: value +2,637 in the Current value column", T(ap.value) == "+2,637" and at(ap.value, hVal) and ap.value.y == ap.label.y, T(ap.value))
check("  ...its Pt value 1.00 in the Pt value column, on the same line", T(ap.per) == "1.00" and at(ap.per, hPer) and ap.per.y == ap.label.y, T(ap.per))
check("  ...the old '(1 = x)' is no longer glued into the value", ap.value ~= nil and not tostring(ap.value.text):find("(1 =", 1, true) and not tostring(ap.value.text):find("1.00", 1, true))
local fv, fp = font(d, "+2,637"), font(d, "1.00")
check("  ...value and Pt value are separate font strings at their columns' x (the player's screen, not only the records)",
  fv and fp and fv ~= fp and fontX(fv) == hVal.x and fontX(fp) == hPer.x and fv.w == hVal.w and fp.w == hPer.w, tostring(fontX(fv)) .. " / " .. tostring(fontX(fp)))
local ar = lineCells(d, "pairLabel", "» Armor")
check("» Armor: value +2,684, Pt value 1.02 (101.8% of Agility per point, from the mastery text), each in its column",
  T(ar.value) == "+2,684" and at(ar.value, hVal) and T(ar.per) == "1.02" and at(ar.per, hPer), T(ar.value) .. " | " .. T(ar.per))
check("  ...its note '101.8% of Agility, mastery' is a font string of its own, under the line, from the Current value column",
  T(ar.note) == "101.8% of Agility, mastery" and ar.note.x == hVal.x and ar.note.y >= ar.value.y + ar.value.h and ar.note.x + ar.note.w == LAY.content, T(ar.note))
local dg = lineCells(d, "pairLabel", "» Dodge")
check("» Dodge: value +5.00%, no Pt value (the game gives none), no note", T(dg.value) == "+5.00%" and at(dg.value, hVal) and dg.per == nil and dg.note == nil, T(dg.value))
-- the abilities: each its own line nested under "» Abilities (per 100)" (QoL 0.7.20)
local abHead = lineCells(d, "pairLabel", "» Abilities (per 100)")
local ab = nested(d, "» Abilities (per 100)")
check("[0.7.20] » Abilities (per 100): each ability on its own line under it, in the model's order: Fracture, then Infernal Strike",
  #ab == 2 and T(ab[1].label) == "Fracture" and T(ab[2].label) == "Infernal Strike" and abHead.label and ab[1].label.y > abHead.label.y
  and ab[2].label.y > ab[1].label.y, #ab .. " " .. T(ab[1] and ab[1].label))
check("[0.7.20] ...nested: one indent deeper than the » lines (name at x 24, the » line's at 12)", #ab == 2 and abHead.label.x == 12
  and ab[1].label.x == 24 and ab[2].label.x == 24, #ab == 2 and ab[1].label.x)
check("[0.7.20] ...each ability's number in the Current value column, on its own line: Fracture +200, Infernal Strike +100", #ab == 2
  and T(ab[1].value) == "+200" and at(ab[1].value, hVal) and ab[1].value.y == ab[1].label.y and T(ab[2].value) == "+100" and at(ab[2].value, hVal)
  and ab[2].value.y == ab[2].label.y, #ab == 2 and (T(ab[1].value) .. " / " .. T(ab[2].value)))
check("[0.7.20] ...the » line itself holds no list any more (no note, no value): the comma-joined note is gone", abHead.label ~= nil and abHead.note == nil
  and abHead.value == nil and find(d, "pairNote", "Fracture +200, Infernal Strike +100") == nil, T(abHead.note))
local hp = lineCells(d, "pairLabel", "» Health")
check("Stamina » Health: value 1,476,516 and Pt value 21.20 in their columns", T(hp.value) == "1,476,516" and at(hp.value, hVal) and T(hp.per) == "21.20" and at(hp.per, hPer),
  T(hp.value) .. " | " .. T(hp.per))
-- every line of every Stats section: the same columns
local heads = recs(d, "colhead")
local nVal, nCh, nRat = 0, 0, 0
for _, r in ipairs(heads) do
  if r.text == "Current value" then nVal = nVal + 1 elseif r.text == "Change" then nCh = nCh + 1 elseif r.text == "Rating" then nRat = nRat + 1 end
end
check("every part of Character Stats with stat lines has the column head (Core Stats, Secondaries, Tertiaries: 3; QoL 0.7.23)", nVal == 3, nVal)
check("[0.7.20] a Change head over the three parts with boxes (Core Stats, Secondaries, Tertiaries), none over the Gear Summary; Rating over Secondaries and Tertiaries",
  nCh == 3 and nRat == 2 and find(d, "colhead", "Change", 3).y < find(d, "subhead", "Gear Summary").y, nCh .. " Change, " .. nRat .. " Rating")
local function allAt(kinds, h)
  for _, k in ipairs(kinds) do for _, r in ipairs(recs(d, k)) do
    if not at(r, h) then return false, k .. " '" .. tostring(r.text) .. "' x=" .. r.x .. " w=" .. r.w end
  end end
  return true
end
local okV, whyV = allAt({ "value", "pairValue" }, hVal)
check("every current value on the Stats tab sits at the Current value head's x and width", okV, whyV)
local okP, whyP = allAt({ "per", "pairPer" }, hPer)
check("every Pt value on the Stats tab sits at the Pt value head's x and width", okP and #recs(d, "pairPer") >= 6, whyP or #recs(d, "pairPer"))
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
local pa = lineCells(d, "pairLabel", "» Parry")
check("  » Parry: +10.15% | 52.0 / 1% (crit rating for 1% parry) | note before DR", T(pa.value) == "+10.15%" and T(pa.per) == "52.0 / 1%" and T(pa.note) == "before DR", T(pa.value) .. " | " .. T(pa.per) .. " | " .. T(pa.note))
local dr = lineCells(d, "pairLabel", "Diminishing returns")
check("  Diminishing returns: value none yet, the next threshold in the note", T(dr.value) == "none yet" and T(dr.note) == "next at 1,380 rating (852 away)", T(dr.value) .. " | " .. T(dr.note))
local hasteHead, hasteAb = lineCells(d, "pairLabel", "» Abilities (their text names Haste)"), nested(d, "» Abilities (their text names Haste)")
check("[0.7.20] Haste's abilities: each on its own nested line, its recharge in Current value: Infernal Strike 9.6 s recharge (no list in a note)",
  #hasteAb == 1 and T(hasteAb[1].label) == "Infernal Strike" and hasteAb[1].label.x == 24 and T(hasteAb[1].value) == "9.6 s recharge"
  and at(hasteAb[1].value, hVal2) and hasteHead.note == nil, #hasteAb .. " " .. T(hasteHead.note))
check("[0.7.20] no comma-joined ability list remains on the Stats tab: every drawn text that names an ability is that name alone", joinedText(d) == nil, joinedText(d))
local ok1, why1 = layoutOK(d)
check("(guard, V11) layout, default width: inside the width, no overlaps (wrapped heights)", ok1, why1)

-- 2. Wide panel (760: content 740): the note gets its own column ------------------------------------------------------------
setWidth(760)
d = render()
local hNote = find(d, "colhead", "Note")
hVal, hPer, hCh = find(d, "colhead", "Current value"), find(d, "colhead", "Pt value"), find(d, "colhead", "Change")
check("wide panel: a Note column head after Pt value", hNote and hPer and hNote.x >= hPer.x + hPer.w and hNote.y == hPer.y and LAY.content == 740, T(hNote))
check("[0.7.20] ...the Note column sits between Pt value and Change; Change stays at the far right", hNote and hCh and hNote.x + hNote.w + GUT <= hCh.x
  and hCh.y == hNote.y and hCh.x + hCh.w == LAY.content, hNote and hCh and (hNote.x + hNote.w .. " / " .. hCh.x))
ar = lineCells(d, "pairLabel", "» Armor")
check("  ...» Armor: value, Pt value and note side by side on one line, each at its head's x", T(ar.note) == "101.8% of Agility, mastery" and ar.note.x == hNote.x
  and ar.note.y == ar.label.y and at(ar.value, hVal) and at(ar.per, hPer), T(ar.note))
ab = nested(d, "» Abilities (per 100)")
check("[0.7.20] ...the abilities stay nested lines, each number in Current value (nothing in the Note column for them)", #ab == 2 and T(ab[1].value) == "+200"
  and at(ab[1].value, hVal) and ab[1].note == nil and lineCells(d, "pairLabel", "» Abilities (per 100)").note == nil, #ab)
local okN = true
for _, k in ipairs({ "note", "pairNote" }) do for _, r in ipairs(recs(d, k)) do if r.x ~= hNote.x then okN = false end end end
check("  ...every note on the Stats tab is in the Note column", okN and #recs(d, "pairNote") >= 5, #recs(d, "pairNote"))
okB, whyB = boxesOK(d, 8)
check("[0.7.20] ...every box is still the last cell of its row, under Change, right of the Note column", okB, whyB)

-- 3. Layout (V11): smallest, default, just below and at the wide threshold, widest; text sizes; typed numbers ----------------
ns.CharToolkit_SetInput("sv:crit", "700"); ns.CharToolkit_SetInput("sv:primary", "2737"); ns.CharToolkit_SetInput("sv:haste", "1500")
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
check("[0.7.20] typed Agility: the line reads » Ability Scaling, and » Abilities with your number is gone", find(d, "pairLabel", "» Ability Scaling") ~= nil
  and find(d, "pairLabel", "» Abilities with your number") == nil)
local scHead, sc = lineCells(d, "pairLabel", "» Ability Scaling"), nested(d, "» Ability Scaling")
check("[0.7.20] ...each ability on its own line nested under it, now -> then in Current value: Fracture 6,944 -> 7,144, then Infernal Strike 3,472 -> 3,572",
  #sc == 2 and T(sc[1].label) == "Fracture" and T(sc[1].value) == "6,944 -> 7,144" and at(sc[1].value, hVal) and T(sc[2].label) == "Infernal Strike"
  and T(sc[2].value) == "3,472 -> 3,572" and at(sc[2].value, hVal) and sc[1].label.x == 24 and scHead.label.x == 12 and scHead.note == nil,
  #sc .. " " .. T(sc[1] and sc[1].value) .. " / " .. T(scHead.note))
local fsc = font(d, "6,944 -> 7,144")
check("[0.7.20] ...in green (attack power goes up: the numbers grow)", fsc and fsc.color and fsc.color[1] == 0.5 and fsc.color[2] == 1 and fsc.color[3] == 0.5,
  fsc and fsc.color and table.concat(fsc.color, ","))
check("[0.7.20] no comma-joined ability list with typed numbers either", joinedText(d) == nil, joinedText(d))
ap = lineCells(d, "pairLabel", "» Attack power")
check("typed Agility: » Attack power +2,637 -> +2,737 in Current value, Pt value 1.00 beside it", T(ap.value) == "+2,637 -> +2,737" and T(ap.per) == "1.00", T(ap.value) .. " | " .. T(ap.per))
cr = lineCells(d, "label", "Critical Strike")
crBox = find(d, "input", "sv:crit")
check("[0.7.21] typed 700 crit: Rating shows your 528 and the change, 528 +172; the box under Change holds 700, Current value 22.48% -> 26.22%", T(cr.rating) == "528 +172"
  and d.boxes["sv:crit"].text == "700" and crBox and crBox.x == hCh.x and T(cr.value) == "22.48% -> 26.22%", T(cr.rating) .. " | " .. T(cr.value))
-- text that must sit on one line does (the estimate): the heads, ratings, Pt values, the nested abilities, the » line's name
local long
for _, r in ipairs(d.layout) do
  local must = (r.kind == "colhead" and (r.text == "Rating" or r.text == "Change" or r.text == "Current value" or r.text == "Pt value"))
    or r.kind == "rating" or r.kind == "per" or r.kind == "pairPer" or (r.kind == "pairLabel" and (r.x == 24 or r.text == "» Ability Scaling" or r.text == "» Abilities (per 100)"))
    or (r.kind == "label" and r.text == "Critical Strike")   -- QoL 0.7.21: every name fits at the default 450
  if must and not fits(r) then long = r.kind .. " '" .. tostring(r.text) .. "' w " .. r.w end
end
for _, l in ipairs(sc) do if not fits(l.value) then long = "value '" .. T(l.value) .. "'" end end
check("[0.7.20] text fits on one line (0.55 x size per character), default panel, text size 11, typed numbers: the Rating and Change heads, every rating, every Pt value, each ability's name and now -> then, » Ability Scaling",
  long == nil and #recs(d, "rating") == 7, long)
local fRat = font(d, "528 +172")
check("[0.7.21] ...and '528 +172' is a font string of its own at the Rating column's x (the player's screen)", fRat and hRat and fontX(fRat) == hRat.x and fRat.w == hRat.w, fRat and fontX(fRat))
-- the panel hover with typed numbers: Ability Scaling and its lines, the old name nowhere
local agiHover
for _, b in ipairs(d.buttons) do if b.shown and b.item and b.item.key == "map_primary" and b.h and b.h <= c.fontSize + 6 then agiHover = b end end
GameTooltip.lines = {}
if agiHover then agiHover.scripts.OnEnter(agiHover) end
local tlT = table.concat(GameTooltip.lines or {}, " / ")
check("[0.7.20] the Agility hover with typed numbers: » Ability Scaling, then '    Fracture | 6,944 -> 7,144' (indented); 'Abilities with your number' nowhere in it",
  tlT:find("» Ability Scaling |  /     Fracture | 6,944 -> 7,144 /     Infernal Strike | 3,472 -> 3,572", 1, true) ~= nil
  and tlT:find("bilities with your number", 1, true) == nil, tlT)
check("[0.7.20] ...the card's hover covers its line up to the box (name, value, Pt value), not the box", agiHover and hCh and agiHover.w == hCh.x - GUT, agiHover and agiHover.w)
ns.CharToolkit_SetInput("sv:crit", ""); ns.CharToolkit_SetInput("sv:primary", ""); ns.CharToolkit_SetInput("sv:haste", "")
c.size = nil

-- 4. Hovers and the character window's tooltips keep every number -------------------------------------------------------------
d = render()
local function tipLines(b) GameTooltip.lines = {}; b.scripts.OnEnter(b); return GameTooltip.lines end
local function has(lines, s) for _, l in ipairs(lines) do if tostring(l):find(s, 1, true) then return true end end; return false end
local function idx(lines, s) for i, l in ipairs(lines) do if tostring(l) == s then return i end end end
local apRow = find(d, "pairLabel", "» Attack power")
local lineHover
for _, b in ipairs(d.buttons) do
  if b.shown and b.item and b.item.key == "map_primary" then
    local pt = b.pts[#b.pts]
    if pt and -pt[5] <= apRow.y and -pt[5] + b.h > apRow.y then lineHover = b end
  end
end
check("hovering the Agility card's » lines shows its hover too (where the numbers come from)", lineHover ~= nil and has(tipLines(lineHover), "GetAttackPowerForStat"))
local agiLabel
for _, b in ipairs(d.buttons) do if b.shown and b.item and b.item.key == "map_primary" and b.h and b.h <= c.fontSize + 6 then agiLabel = b end end
local tl = agiLabel and tipLines(agiLabel) or {}
check("(guard) the Agility hover lists » Attack power with its Pt value: '+2,637  (1 = 1.00)'", has(tl, "» Attack power | +2,637  (1 = 1.00)"), table.concat(tl, " / "))
check("  ...and » Armor with its Pt value and note: '+2,684  (1 = 1.02); 101.8% of Agility, mastery'", has(tl, "» Armor | +2,684  (1 = 1.02); 101.8% of Agility, mastery"), table.concat(tl, " / "))
local i0, i1, i2 = idx(tl, "» Abilities (per 100) | "), idx(tl, "    Fracture | +200"), idx(tl, "    Infernal Strike | +100")
check("[0.7.20] the Agility hover lists » Abilities (per 100), then each ability on its own indented line: '    Fracture | +200', '    Infernal Strike | +100'",
  i0 and i1 and i2 and i1 == i0 + 1 and i2 == i1 + 1, table.concat(tl, " / "))
c.tooltips = true
GameTooltip:SetOwner(statRow); statRow.hooks.OnEnter[1](statRow)
local cw = GameTooltip.lines or {}
check("character window, Agility tooltip: » Attack power +2,637 (1 = 1.00) and » Armor with 1 = 1.02 and its note (one text column)",
  has(cw, "» Attack power | +2,637  (1 = 1.00)") and has(cw, "» Armor | +2,684  (1 = 1.02); 101.8% of Agility, mastery"), table.concat(cw, " / "))
local j0, j1 = idx(cw, "» Abilities (per 100) | "), idx(cw, "    Fracture | +200")
check("[0.7.20] ...and the abilities one per line, indented under » Abilities (per 100)", j0 and j1 and j1 == j0 + 1 and not has(cw, "Fracture +200,"), table.concat(cw, " / "))
statRow.Label.text = "Critical Strike:"
GameTooltip:SetOwner(statRow); statRow.hooks.OnEnter[1](statRow)
cw = GameTooltip.lines or {}
check("(guard) character window, crit tooltip: Diminishing returns 'none yet; next at 1,380 rating (852 away)'", has(cw, "Diminishing returns | none yet; next at 1,380 rating (852 away)"), table.concat(cw, " / "))
check("  ...» Parry with its words: '52.0 crit rating = 1% parry'", has(cw, "» Parry | +10.15%  (52.0 crit rating = 1% parry); before DR"), table.concat(cw, " / "))

-- 5. The Gear tab: QoL 0.7.24 (Xaya 2026-11-05: "side by side and what it changes options are redundant. Rename the section to
-- "Changes""): one Changes table, Stat | Pt value | Equipped | each picked item; the stat map's lines that change are its "Stat effects"
-- rows (now in Equipped, then in the item's column); Ability Scaling became "Spell Changes". (Before: "What it changes" in the stat
-- grid's columns, Current value "now -> then".) The full checks of the new section are in tests/char_spells_compare_run.py.
CM.gearSlot = 1; ns.CharToolkit_SetInput("item", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
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
local gha = find(d, "mlabel", "» Abilities (their text names Haste)")
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
d = render("stats")
local sGear, sChar, sElse = find(d, "colhead", "Gear"), find(d, "colhead", "Character"), find(d, "colhead", "Elsewhere")
check("Gear Summary (Stats tab): a table with Gear | Character | Elsewhere heads", sGear and sChar and sElse and sGear.x < sChar.x and sChar.x < sElse.x, T(sGear))
local sumHead, sumLabel = find(d, "subhead", "Gear Summary"), nil
for _, r in ipairs(recs(d, "label")) do if not sumLabel and sumHead and r.text == "Critical Strike" and r.y > sumHead.y then sumLabel = r end end
local sc2 = {}
for _, r in ipairs(recs(d, "cmpcell")) do if sumLabel and r.y == sumLabel.y then sc2[#sc2 + 1] = r end end
check("  ...Critical Strike: 400 | 528 | +128, each in its own cell under its head", #sc2 == 3 and sc2[1].text == "400" and sc2[2].text == "528" and sc2[3].text == "+128"
  and sc2[1].x == sGear.x and sc2[2].x == sChar.x and sc2[3].x == sElse.x, #sc2)
for _, fs in ipairs({ 8, 11, 16 }) do
  c.fontSize = fs
  local ok, why = layoutOK(render("gear"))
  check("(guard, V11) layout, Gear with a comparison, text size " .. fs .. ": inside the width, no overlaps", ok, why)
end
c.fontSize = 11; ns.CharToolkit_SetInput("item", ""); CM.gearSlot = nil

-- 6. What did not change ------------------------------------------------------------------------------------------------------
c.advanced = true
d = render("spells")
-- (QoL 0.7.24: the spell lines are columns now: Value | % PSV with "1 Agility = +N" under it)
local spv, spp, spr = find(d, "spellvalue", "6,944"), nil, nil
for _, r in ipairs(recs(d, "spellpct")) do if spv and r.y == spv.y then spp = r end end
for _, r in ipairs(recs(d, "spellper")) do if spp and r.x == spp.x and r.y > spp.y and not spr then spr = r end end
check("(guard) the Spells tab keeps its numbers: '6,944' | '... of attack power' with '1 Agility = +...' under it", spv ~= nil and spp ~= nil
  and tostring(spp.text):find("of attack power", 1, true) ~= nil and spr ~= nil and tostring(spr.text):find("^1 Agility = %+") ~= nil, T(spp))
c.advanced = false
d = render()
check("(guard) the Show: % button stays hidden (#382; the settings' Rating lines are left for Xaya's decision)", not P.modeBtn.shown)
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
   .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
