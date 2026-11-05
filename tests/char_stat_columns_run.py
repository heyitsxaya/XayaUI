# Stub test for the Stat Calculator's columns (XayaUI_QoL 0.7.15). Xaya 2026-11-05 (her words): "do multiple columns: for cleaner
# presentation * Stat | Current Value | Pt Value | etc", with a screenshot of the Primary stats section, where each line was
# "label ... value" with the detail glued into the value ("+2,671  (1 = 1.00)", "+2,396  (89.7% of Agility, mastery)").
# What it checks is what the player sees (V1, V11):
#   - every stat section of the Stats tab, and the Gear comparison's "What it changes", has a column head Stat | Current value |
#     Pt value (Rating over a rating card's box; Note once the panel is wide enough);
#   - each line's current value, Pt value and note are separate font strings, at the x and width of their column head; the old
#     "(1 = x)" text is no longer glued into the value; the abilities list is a note of its own;
#   - narrow panel: the note goes under its line (from the Current value column), wide panel: in its own column, same row;
#   - layout at the smallest, default, and widest panel, text sizes 8 / 11 / 16, typed numbers: inside the width, no overlaps,
#     with font strings that report a wrapped height (estimated 0.55 x size per character);
#   - the hovers and the character window's stat tooltips still carry every number (one text column: CM.PairText);
#   - the Gear Summary is a table (Gear | Character | Elsewhere).
# Checks marked "(guard)" pin behaviour that did not change, "(guard, V11)" the layout rules, which held before too, and "(setup)" the
# starting state: these pass on QoL 0.7.14's files as well. Every other check fails on 0.7.14's files (negative control, 2026-11-05).
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
local function drawn() return ns.CharToolkit_Drawn() end
local function render(tab) c.tab = tab or "stats"; ns.CharToolkit_Render(); return drawn() end
local function setWidth(w) c.size = { w = w, h = 600 }; P.sizing = nil end   -- the panel width the corner grip would leave (content = w - 20)
local function recs(d, kind) local out = {}; for _, r in ipairs(d.layout) do if r.kind == kind then out[#out + 1] = r end end; return out end
local function find(d, kind, text, nth)
  local k = 0
  for i, r in ipairs(d.layout) do if r.kind == kind and r.text == text then k = k + 1; if k == (nth or 1) then return r, i end end end
end
-- the cells of one drawn line: its label record, then the value / Pt value / note records placed for it (until the next line starts)
local LINE_START = { label = true, pairLabel = true, header = true, colhead = true, input = true, cmpcell = true }
local function lineCells(d, labelKind, label, nth)
  local L, i = find(d, labelKind, label, nth)
  if not L then return {} end
  local out = { label = L }
  local pre = labelKind == "pairLabel" and "pair" or ""
  local function K(s) return pre == "" and s or (pre .. s:sub(1, 1):upper() .. s:sub(2)) end
  for j = i + 1, #d.layout do
    local r = d.layout[j]
    if LINE_START[r.kind] then break end
    if r.kind == K("value") then out.value = r elseif r.kind == K("per") then out.per = r elseif r.kind == K("note") then out.note = r end
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

-- 1. Default panel (380 wide, content 360): Primary stats as in her screenshot ------------------------------------------------
c.size = nil
local d = render()
check("(setup) the default content width is 360 (the panel 380)", LAY.content == 360, LAY.content)
local hStat, hVal, hPer = find(d, "colhead", "Stat"), find(d, "colhead", "Current value"), find(d, "colhead", "Pt value")
check("Primary stats has a column head: Stat | Current value | Pt value", hStat and hVal and hPer and hStat.x == 0 and hStat.y < hVal.y + 1 and hVal.y == hPer.y
  and hVal.y > find(d, "header", "- Primary stats").y and hVal.y < (find(d, "label", "Agility") or { y = -1 }).y, T(hStat) .. " " .. T(hVal) .. " " .. T(hPer))
check("  ...the head reads left to right Stat, Current value, Pt value; no Note head on a narrow panel (the note goes under its line)",
  hStat and hVal and hPer and hStat.x < hVal.x and hVal.x < hPer.x and find(d, "colhead", "Note") == nil)
local agi = lineCells(d, "label", "Agility")
check("Agility: its current value 2,637 sits in the Current value column (same x and width as the head)", T(agi.value) == "2,637" and at(agi.value, hVal), T(agi.value))
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
local ab = lineCells(d, "pairLabel", "» Abilities (per 100)")
check("» Abilities (per 100): the list is a note on the line itself (no empty value cell), readable: wrapped, not cut",
  T(ab.note) == "Fracture +200, Infernal Strike +100" and ab.value == nil and ab.note.y == ab.label.y and ab.note.x == hVal.x
  and ab.note.w == LAY.content - hVal.x, T(ab.note))
local hp = lineCells(d, "pairLabel", "» Health")
check("Stamina » Health: value 1,476,516 and Pt value 21.20 in their columns", T(hp.value) == "1,476,516" and at(hp.value, hVal) and T(hp.per) == "21.20" and at(hp.per, hPer),
  T(hp.value) .. " | " .. T(hp.per))
-- every line of every Stats section: the same columns
local heads = recs(d, "colhead")
local nVal = 0
for _, r in ipairs(heads) do if r.text == "Current value" then nVal = nVal + 1 end end
check("every Stats section has the column head (Primary, Secondary, Tertiary, Offense, Defense: 5)", nVal == 5, nVal)
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
-- rating cards: Stat | Rating (the box) | Current value | Pt value
local hRat = find(d, "colhead", "Rating")
local cr = lineCells(d, "label", "Critical Strike")
local crBox
for _, r in ipairs(recs(d, "input")) do if r.text == "sv:crit" then crBox = r end end
check("(guard) Secondary stats: Rating over the box column; the crit box sits under it", hRat and crBox and crBox.x == hRat.x and crBox.y == cr.label.y, T(hRat))
check("Critical Strike: 22.48% in Current value, 46.0 / 1% (rating per 1%, #382) in Pt value", T(cr.value) == "22.48%" and at(cr.value, find(d, "colhead", "Current value", 2))
  and T(cr.per) == "46.0 / 1%" and at(cr.per, find(d, "colhead", "Pt value", 2)), T(cr.value) .. " | " .. T(cr.per))
local pa = lineCells(d, "pairLabel", "» Parry")
check("  » Parry: +10.15% | 52.0 / 1% (crit rating for 1% parry) | note before DR", T(pa.value) == "+10.15%" and T(pa.per) == "52.0 / 1%" and T(pa.note) == "before DR", T(pa.value) .. " | " .. T(pa.per) .. " | " .. T(pa.note))
local dr = lineCells(d, "pairLabel", "Diminishing returns")
check("  Diminishing returns: value none yet, the next threshold in the note", T(dr.value) == "none yet" and T(dr.note) == "next at 1,380 rating (852 away)", T(dr.value) .. " | " .. T(dr.note))
local hasteAb = lineCells(d, "pairLabel", "» Abilities (their text names Haste)")
check("  Haste's abilities and their recharge: a note on the line", T(hasteAb.note) == "Infernal Strike (9.6 s recharge)" and hasteAb.value == nil, T(hasteAb.note))
local ok1, why1 = layoutOK(d)
check("(guard, V11) layout, default width: inside the width, no overlaps (wrapped heights)", ok1, why1)

-- 2. Wide panel (760: content 740): the note gets its own column ------------------------------------------------------------
setWidth(760)
d = render()
local hNote = find(d, "colhead", "Note")
hVal, hPer = find(d, "colhead", "Current value"), find(d, "colhead", "Pt value")
check("wide panel: a Note column head after Pt value", hNote and hPer and hNote.x >= hPer.x + hPer.w and hNote.y == hPer.y and LAY.content == 740, T(hNote))
ar = lineCells(d, "pairLabel", "» Armor")
check("  ...» Armor: value, Pt value and note side by side on one line, each at its head's x", T(ar.note) == "101.8% of Agility, mastery" and ar.note.x == hNote.x
  and ar.note.y == ar.label.y and at(ar.value, hVal) and at(ar.per, hPer), T(ar.note))
ab = lineCells(d, "pairLabel", "» Abilities (per 100)")
check("  ...the abilities list in the Note column, on its line", T(ab.note) == "Fracture +200, Infernal Strike +100" and ab.note.x == hNote.x and ab.note.y == ab.label.y, T(ab.note))
local okN = true
for _, k in ipairs({ "note", "pairNote" }) do for _, r in ipairs(recs(d, k)) do if r.x ~= hNote.x then okN = false end end end
check("  ...every note on the Stats tab is in the Note column", okN and #recs(d, "pairNote") >= 5, #recs(d, "pairNote"))

-- 3. Layout (V11): smallest, default, just below and at the wide threshold, widest; text sizes; typed numbers ----------------
ns.CharToolkit_SetInput("sv:crit", "700"); ns.CharToolkit_SetInput("sv:primary", "2737"); ns.CharToolkit_SetInput("sv:haste", "1500")
for _, pw in ipairs({ 340, 380, 539, 540, 760 }) do
  for _, fs in ipairs({ 8, 11, 16 }) do
    c.fontSize = fs; setWidth(pw)
    local ok, why = layoutOK(render())
    check(("(guard, V11) layout, panel %d wide, text size %d, typed numbers: inside the width, no overlaps"):format(pw, fs), ok, why)
  end
end
c.fontSize = 11
setWidth(380)
d = render()
local ch = lineCells(d, "pairLabel", "» Abilities with your number")
check("typed Agility: » Abilities with your number in a note on its line (now -> then)", T(ch.note) == "Fracture 6,944 -> 7,144, Infernal Strike 3,472 -> 3,572" and ch.value == nil, T(ch.note))
ap = lineCells(d, "pairLabel", "» Attack power")
check("typed Agility: » Attack power +2,637 -> +2,737 in Current value, Pt value 1.00 beside it", T(ap.value) == "+2,637 -> +2,737" and T(ap.per) == "1.00", T(ap.value) .. " | " .. T(ap.per))
ns.CharToolkit_SetInput("sv:crit", ""); ns.CharToolkit_SetInput("sv:primary", ""); ns.CharToolkit_SetInput("sv:haste", "")
c.size = nil

-- 4. Hovers and the character window's tooltips keep every number -------------------------------------------------------------
d = render()
local function tipLines(b) GameTooltip.lines = {}; b.scripts.OnEnter(b); return GameTooltip.lines end
local function has(lines, s) for _, l in ipairs(lines) do if tostring(l):find(s, 1, true) then return true end end; return false end
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
check("(guard) the Agility hover lists the abilities", has(tl, "» Abilities (per 100) | Fracture +200, Infernal Strike +100"))
c.tooltips = true
GameTooltip:SetOwner(statRow); statRow.hooks.OnEnter[1](statRow)
local cw = GameTooltip.lines or {}
check("character window, Agility tooltip: » Attack power +2,637 (1 = 1.00) and » Armor with 1 = 1.02 and its note (one text column)",
  has(cw, "» Attack power | +2,637  (1 = 1.00)") and has(cw, "» Armor | +2,684  (1 = 1.02); 101.8% of Agility, mastery"), table.concat(cw, " / "))
statRow.Label.text = "Critical Strike:"
GameTooltip:SetOwner(statRow); statRow.hooks.OnEnter[1](statRow)
cw = GameTooltip.lines or {}
check("(guard) character window, crit tooltip: Diminishing returns 'none yet; next at 1,380 rating (852 away)'", has(cw, "Diminishing returns | none yet; next at 1,380 rating (852 away)"), table.concat(cw, " / "))
check("  ...» Parry with its words: '52.0 crit rating = 1% parry'", has(cw, "» Parry | +10.15%  (52.0 crit rating = 1% parry); before DR"), table.concat(cw, " / "))

-- 5. The Gear tab: "What it changes" in the same columns; the Summary as a table ----------------------------------------------
CM.gearSlot = 1; ns.CharToolkit_SetInput("item", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r")
d = render("gear")
local ghVal, ghPer = find(d, "colhead", "Current value"), find(d, "colhead", "Pt value")
local gEff = find(d, "header", "- What it changes")
check("Gear > What it changes: a column head Stat | Current value | Pt value under its header", gEff and ghVal and ghPer and ghVal.y > gEff.y and find(d, "colhead", "Stat") ~= nil, T(ghVal))
check("  ...no box on the Gear tab: Current value takes the box column's room (168 wide), Pt value keeps the Stats tab's x (296)",
  ghVal and ghPer and ghVal.w == 168 and ghPer.x == 296 and find(d, "colhead", "Rating") == nil, ghVal and (ghVal.w .. " / " .. ghPer.x))
local gap = lineCells(d, "pairLabel", "» Attack power")
check("  ...+100 Agility: » Attack power +2,637 -> +2,737 in Current value, 1.00 in Pt value", T(gap.value) == "+2,637 -> +2,737" and at(gap.value, ghVal) and T(gap.per) == "1.00" and at(gap.per, ghPer),
  T(gap.value) .. " | " .. T(gap.per))
local gab = lineCells(d, "pairLabel", "» Abilities with your number")
check("  ...» Abilities with your number kept (its change is in its note)", T(gab.note) == "Fracture 6,944 -> 7,144, Infernal Strike 3,472 -> 3,572", T(gab.note))
local gHealth = lineCells(d, "pairLabel", "» Health")
check("  ...+900 Stamina: » Health 1,476,516 -> 1,495,596 and Pt value 21.20", T(gHealth.value) == "1,476,516 -> 1,495,596" and T(gHealth.per) == "21.20", T(gHealth.value) .. " | " .. T(gHealth.per))
local sGear, sChar, sElse = find(d, "colhead", "Gear"), find(d, "colhead", "Character"), find(d, "colhead", "Elsewhere")
check("Gear > Summary: a table with Gear | Character | Elsewhere heads", sGear and sChar and sElse and sGear.x < sChar.x and sChar.x < sElse.x, T(sGear))
local sumHead, sumLabel = find(d, "header", "- Summary"), nil
for _, r in ipairs(recs(d, "label")) do if not sumLabel and sumHead and r.text == "Critical Strike" and r.y > sumHead.y then sumLabel = r end end
local sc = {}
for _, r in ipairs(recs(d, "cmpcell")) do if sumLabel and r.y == sumLabel.y then sc[#sc + 1] = r end end
check("  ...Critical Strike: 400 | 528 | +128, each in its own cell under its head", #sc == 3 and sc[1].text == "400" and sc[2].text == "528" and sc[3].text == "+128"
  and sc[1].x == sGear.x and sc[2].x == sChar.x and sc[3].x == sElse.x, #sc)
for _, fs in ipairs({ 8, 11, 16 }) do
  c.fontSize = fs
  local ok, why = layoutOK(render("gear"))
  check("(guard, V11) layout, Gear with a comparison, text size " .. fs .. ": inside the width, no overlaps", ok, why)
end
c.fontSize = 11; ns.CharToolkit_SetInput("item", ""); CM.gearSlot = nil

-- 6. What did not change ------------------------------------------------------------------------------------------------------
c.advanced = true
d = render("spells")
local sp = lineCells(d, "pairLabel", "6,944")
check("(guard) the Spells tab keeps its lines as they were: '6,944' | '... of attack power; 1 Agility = +...'", sp.value ~= nil
  and tostring(sp.value.text):find("of attack power; 1 Agility = +", 1, true) ~= nil, T(sp.value))
c.advanced = false
d = render()
check("(guard) the Show: % button stays hidden (#382; the settings' Rating lines are left for Xaya's decision)", not P.modeBtn.shown)
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
   .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
