# Stub test for the Stat Calculator round of 2026-11-07 (XayaUI_QoL 0.7.40; REQUEST-LOG #87-#91, B2). Xaya's words (verbatim in the log):
#   #87: "changes "Modified By" column and "Modifies" columns to separate the from and applies to elements"
#   #88: "put the numerical contributions on a row for each stat -- make each stat collapsible, in which case the rows bundle neatly into
#        the tooltip"; her answers: rows "\"Modified By\" only (Recommended)"; default "Collapsed (Recommended)"; columns "Only
#        \"Modifies\" column (Recommended)"
#   #89: "compare item selection should also have a clear highlight for selections" (screenshot "Compare: Trinket slot #2")
#   #90: "+/- signs should be in () to the right of the compared values -- set the number values to left-align to make space"
#   #91: "name, class, and spec not needed on stat calculator. Instead, set this section to display currently equipped ilvl and on the
#        right side max ilvl (in bags)"
#   B2 (reading taken): the "% / rating" toggle removed in all three places (title-row button, per-line click, Settings "Rating lines"
#        and its reset button).
# What it checks is what the player sees (V1, V11): drawn records (kind, x, y, width, text), font strings' justification and colour,
# hovers, the frame's textures, saved settings across a rebuild. Layout claims (the header's two halves, the bracketed differences on one
# line, the columns) are checked with three text measures ("est" 0.55 x size per character, "scaled" 0.6 x size, "flat8" 8 px a
# character), as tests/char_stat_round_run.py does, because the shared stand-ins measure 6 px a character or nothing.
# The last part runs the in-game QA walkthroughs (XayaUI_DevAssist/QAWalks-statcalc.lua) on this stand-in: each step's own check gives
# Pass on the new code (pre-fill), reading only through core's service list.
# Negative control (V1): every check fails on QoL 0.7.39 / Dev Assist 0.7.12 (main 6b25c9b) except those marked "(guard)"; debug-log
# 2026-11-07 ... qol-0.7.40 has the counts.
# Run from the repo root: python3 tests/char_stat_round2_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua.
# Every number, item and link here is a TEST STAND-IN.
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"

# the measuring stand-ins and helpers of tests/char_stat_round_run.py (COMMON and STATWORLD), reused as they are
_src = open(os.path.join(ROOT, "tests", "char_stat_round_run.py"), encoding="utf-8").read()
COMMON = re.search(r"^COMMON = r'''(.*?)'''", _src, re.S | re.M).group(1)
STATWORLD = re.search(r"^STATWORLD = r'''(.*?)'''", _src, re.S | re.M).group(1)
EXTRA = r'''
-- textures report their draw layer as the game does (GetDrawLayer -> layer, sublevel)
local mk2 = mk
function mk(kind)
  local o = mk2(kind)
  o.GetDrawLayer = function(self) return self.layer, self.sublevel end
  local cs = o.CreateTexture
  o.CreateTexture = function(self, ...) local t = cs(self, ...); t.GetDrawLayer = function(tt) return tt.layer, tt.sublevel end; return t end
  return o
end
'''

def world(extra):
    return (COMMON + EXTRA + extra).replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")) \
        .replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua")) \
        .replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")) \
        .replace("__QAW__", P("XayaUI_DevAssist/QAWalk.lua")).replace("__QAS__", P("XayaUI_DevAssist/QAWalks-statcalc.lua"))

totals = []
def run(extra, body):
    lua = LuaRuntime()
    lua.execute(world(extra))
    lua.execute(body)
    totals.append((lua.eval("n"), lua.eval("fails")))

# the stand-in mastery text names attack power, so Attack Power has two feeders: Agility and Mastery
STAT2 = STATWORLD.replace('MASTERY_TEXT = "Increases Armor by 101.8% of your Agility."',
                          'MASTERY_TEXT = "Increases Armor by 101.8% of your Agility and attack power by 27.80%."')

# ---------------------------------------------------------------------------------------------------------------------------------
# A. #87 / #88: one row per contribution that feeds a stat; each stat folds (folded by default, remembered per stat); Modifies column
# ---------------------------------------------------------------------------------------------------------------------------------
run(STAT2, r'''
local d = render()
local function rowSpan(dd, label)
  local L = find(dd, "label", label)
  if not L then return nil end
  local nextY = math.huge
  for _, r in ipairs(recs(dd, "label")) do if r.y > L.y and r.y < nextY then nextY = r.y end end
  return L, nextY
end
local function under(dd, label, kind)
  local L, ny = rowSpan(dd, label)
  local out = {}
  if not L then return out end
  for _, r in ipairs(dd.layout) do if r.kind == kind and r.y >= L.y and r.y < ny then out[#out + 1] = r end end
  return out
end
local function mark(dd, label)
  local L = find(dd, "label", label)
  for _, r in ipairs(recs(dd, "fold")) do if L and math.abs(r.y - L.y) < 0.01 then return r end end
end
local function txt(list) local t = {}; for _, r in ipairs(list) do t[#t + 1] = tostring(r.text) end; return table.concat(t, "|") end
checkp("the column head is \"Modifies\" (her answer: only a \"Modifies\" column), no \"Influences\", no \"Modified By\"", function()
  return find(d, "colhead", "Modifies") ~= nil and find(d, "colhead", "Influences") == nil and find(d, "colhead", "Modified By") == nil, texts(d, "colhead") end)
checkp("folded by default (a fresh profile): Attack Power shows \"+\" in the indent left of its name, and no row under it", function()
  local m = mark(d, "Attack Power"); local L = find(d, "label", "Attack Power")
  return m and m.text == "+" and m.x == 0 and m.x + m.w <= L.x and #under(d, "Attack Power", "pairLabel") == 0 and next(c.statOpen) == nil,
    tostring(m and m.text) .. " / " .. txt(under(d, "Attack Power", "pairLabel")) end)
checkp("Attack Power's Modifies cell: only what it applies to (Damage per second), no \"from\" name", function()
  return txt(under(d, "Attack Power", "infl")) == "Damage per second" and #recs(d, "feed") == 0, txt(under(d, "Attack Power", "infl")) end)
local h, hb = hoverOf(d, "map_ap")
checkp("folded: the rows are in Attack Power's hover, each with its number (From Agility +2,637, From Mastery +27.80%), and the hover says a click shows them", function()
  return h:find("From Agility | +2,637  (1 = 1.00)", 1, true) ~= nil and h:find("From Mastery | +27.80%", 1, true) ~= nil
    and h:find("Click: show these rows under the stat.", 1, true) ~= nil, h end)
checkp("(guard) a stat with nothing under it (Agility: only what it modifies) has no fold mark", function() return mark(d, "Agility") == nil end)
-- click the stat's row
hb.scripts.OnClick(hb)
d = drawn()
checkp("a click on Attack Power opens it: the mark reads \"-\", the choice is saved (statOpen.map_ap)", function()
  local m = mark(d, "Attack Power"); return m and m.text == "-" and c.statOpen.map_ap == true, tostring(m and m.text) end)
checkp("  ...one row per contribution that feeds it, one indent in (x 24), with its number: \"from Agility\" +2,637, \"from Mastery\" +27.80%", function()
  local labels, vals = under(d, "Attack Power", "pairLabel"), under(d, "Attack Power", "pairValue")
  local fa, fm = find(d, "pairLabel", "from Agility"), find(d, "pairLabel", "from Mastery")
  local va, vm
  for _, v in ipairs(vals) do if fa and v.y == fa.y then va = v end; if fm and v.y == fm.y then vm = v end end
  return fa and fm and fa.x == 24 and fm.x == 24 and va and vm and va.text == "+2,637" and vm.text == "+27.80%", txt(labels) .. " / " .. txt(vals) end)
checkp("  ...each number in the Current value column (the head's x and width)", function()
  local hv = find(d, "colhead", "Current value", 1)
  local ok = #under(d, "Attack Power", "pairValue") >= 2
  for _, v in ipairs(under(d, "Attack Power", "pairValue")) do
    local hd; for _, r in ipairs(recs(d, "colhead")) do if r.text == "Current value" and r.y < v.y then hd = r end end
    if not (hd and v.x == hd.x and v.w == hd.w) then ok = false end
  end
  return ok end)
checkp("  ...the other stats stay folded (Critical Strike: \"+\", no Diminishing returns row)", function()
  local m = mark(d, "Critical Strike"); return m and m.text == "+" and find(d, "pairLabel", "Diminishing returns") == nil end)
-- typed change: the new value with its sign under a row's number (existing behaviour on those rows too)
ns.CharToolkit_SetInput("sv:primary", "2737")
d = render()
checkp("typed Agility 2,737: under \"from Agility\" +2,637 its new value +2,737 with the sign, in the accent colour", function()
  local fa = find(d, "pairLabel", "from Agility")
  local v, ch
  for _, r in ipairs(recs(d, "pairValue")) do if fa and r.y == fa.y then v = r end end
  for _, r in ipairs(recs(d, "pairChange")) do if v and r.x == v.x and r.y > v.y and r.y < v.y + 3 * v.size then ch = r end end
  local f = ch and fontAt(d, ch)
  return v and ch and v.text == "+2,637" and ch.text == "+2,737" and f and sameCol(f.color, ACCENT), T(v) .. " / " .. T(ch) end)
ns.CharToolkit_SetInput("sv:primary", "")
-- remembered per stat: a rebuild from the saved settings keeps Attack Power open, every other stat folded
local saved = CueRulesDB.characterToolkit
local c2 = ns.CharToolkit_Cfg()
d = render()
checkp("remembered per stat (saved settings): after a rebuild Attack Power is still open, Critical Strike folded", function()
  local a, k = mark(d, "Attack Power"), mark(d, "Critical Strike")
  return c2 == saved and c2.statOpen.map_ap == true and a and a.text == "-" and k and k.text == "+" end)
-- click again: folded
local _, hb2 = hoverOf(d, "map_ap")
hb2.scripts.OnClick(hb2)
d = drawn()
checkp("a second click folds it again: \"+\", no rows, nothing saved for it", function()
  local m = mark(d, "Attack Power"); return m and m.text == "+" and #under(d, "Attack Power", "pairLabel") == 0 and c.statOpen.map_ap == nil end)
-- saved junk is cleaned
c.statOpen = c.statOpen or {}   -- (QoL 0.7.39 has no statOpen: the negative-control run keeps going)
c.statOpen.bogus = "yes"; c.statOpen[5] = true
ns.CharToolkit_Cfg()
checkp("a saved value other than true is dropped from statOpen", function() return c.statOpen.bogus == nil and c.statOpen[5] == nil end)
-- every stat open: the layout at three widths, three text sizes, three measures
for k in pairs(c.statOpen) do c.statOpen[k] = nil end
local all = {}
for _, it in ipairs(CM.Build(c, "stats").sections[2].items) do if it.key then all[#all + 1] = it.key end end
for _, k in ipairs(all) do c.statOpen[k] = true end
-- (KNOWN LIMIT, not new: at the narrowest panel and at text 16 on the default one, or with a wide font, the grid's mins do not fit and
-- FitCols scales the columns, so a head word can be cut; QoL 0.7.39 cut the same heads there and more ("Influences" too). The head
-- check runs where the heads fitted before; the layout check everywhere.)
for _, m in ipairs({ "est", "scaled", "flat8" }) do
  MEASURE = m
  for _, pw in ipairs({ 340, 450, 760 }) do
    for _, fs in ipairs({ 8, 11, 16 }) do
      local headsFit = pw == 760 or (m ~= "flat8" and (fs == 8 or (pw == 450 and fs == 11)))
      c.size, c.fontSize = { w = pw }, fs
      local dd = render()
      checkp(("every stat open, panel %d, text %d, measure %s: inside the width, no overlaps%s, the fold marks in the indent"):format(pw, fs, m,
        headsFit and ", no head cut (Modifies whole)" or ""), function()
        local ok, why = layoutOK(dd)
        if not ok then return false, why end
        if headsFit then for _, r in ipairs(recs(dd, "colhead")) do if cutWord(r) then return false, "cut: " .. r.text end end end
        for _, r in ipairs(recs(dd, "fold")) do if r.x ~= 0 or r.w ~= ns.CHARTOOLKIT_INDENT then return false, "mark at " .. r.x end end
        return find(dd, "pairLabel", "from Agility") ~= nil, "no from Agility row" end)
    end
  end
end
MEASURE = "est"; c.size, c.fontSize = nil, 11
''')

# ---------------------------------------------------------------------------------------------------------------------------------
# B. #89: the picked compare item gets the same clear frame as the selected equipped slot (#68), with the item links 12.x uses
# ---------------------------------------------------------------------------------------------------------------------------------
GEARWORLD = r'''
ITEMS["Idol"] = { ilvl = 330, loc = "INVTYPE_TRINKET", stats = { ITEM_MOD_MASTERY_RATING_SHORT = 200 } }
ITEMS["Tumor of the Swarm"] = { ilvl = 346, loc = "INVTYPE_TRINKET", stats = { ITEM_MOD_HASTE_RATING_SHORT = 300 } }
ITEMS["Other Trinket"] = { ilvl = 340, loc = "INVTYPE_TRINKET", stats = { ITEM_MOD_CRIT_RATING_SHORT = 250 } }
ITEMS["New Ring"] = { ilvl = 345, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_CRIT_RATING_SHORT = 300, ITEM_MOD_MASTERY_RATING_SHORT = 388 } }
ITEMS["Big Crit Ring"] = { ilvl = 350, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_CRIT_RATING_SHORT = 1000 } }
GEAR[13] = "|cnIQ4:|Hitem:13::::::::90:::::|h[Idol]|h|r"
GEAR[14] = "|cnIQ4:|Hitem:14::::::::90:::::|h[Idol]|h|r"
-- the bags' links in the form 12.x gives them: a NAMED quality colour, |cnIQ4: (XayaUI_Chat/History.lua strips the same form)
TUMOR = "|cnIQ4:|Hitem:31::::::::90:::::|h[Tumor of the Swarm]|h|r"
OTHERT = "|cnIQ3:|Hitem:32::::::::90:::::|h[Other Trinket]|h|r"
NEWRING = "|cnIQ4:|Hitem:20::::::::90:::::|h[New Ring]|h|r"
BIGRING = "|cnIQ5:|Hitem:21::::::::90:::::|h[Big Crit Ring]|h|r"
BAG = { TUMOR, OTHERT, NEWRING, BIGRING }
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and #BAG or 0 end,
  GetContainerItemInfo = function(bag, i) local l = BAG[i]; if l then return { hyperlink = l, quality = 4, iconFileID = 3000 + i } end end }
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
function ns.BuildSpellList() return {} end
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
ns.FireReady()
CM = ns.CharModel
c = ns.CharToolkit_Cfg()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
c.enabled = true; ns.CharToolkit_Apply(); CharacterFrame.shown = true; PaperDollFrame:Show()
function drawn() return ns.CharToolkit_Drawn() end
function render(tab) c.tab = tab; ns.CharToolkit_Render(); return drawn() end
function icon(dd, slot) for _, b in ipairs(dd.icons) do if b.shown and b.slot == slot and not b.cand then return b end end end
function candIcon(dd, link) for _, b in ipairs(dd.icons) do if b.shown and b.cand and b.link == link then return b end end end
function framed(b)
  if not b then return false, "no icon" end
  for _, e in ipairs(b.selEdges or {}) do
    if not e.shown then return false, "an edge hidden" end
    if not sameCol(e.color, ACCENT) then return false, "not the accent colour" end
    if not (e.layer == "OVERLAY" and e.sublevel == 7) then return false, "layer " .. tostring(e.layer) .. " " .. tostring(e.sublevel) end
    if math.max(e.w or 0, e.h or 0) ~= 3 then return false, "thickness " .. tostring(e.w) .. "/" .. tostring(e.h) end
  end
  return #(b.selEdges or {}) == 4, "edges " .. #(b.selEdges or {})
end
'''
run(GEARWORLD, r'''
local d = render("gear")
local t2 = icon(d, 14)
t2.scripts.OnClick(t2)
d = drawn()
checkp("(guard) her screenshot: Trinket slot #2 picked, \"Compare: Trinket slot #2\", the trinkets in the bags listed as icons", function()
  return find(d, "header", "- Compare: Trinket slot #2") ~= nil and candIcon(d, TUMOR) ~= nil and candIcon(d, OTHERT) ~= nil end)
local tu = candIcon(d, TUMOR)
tu.scripts.OnClick(tu)
d = drawn()
checkp("a click on Tumor of the Swarm (a |cnIQ4: link): it gets the clear frame (3 px, the theme's accent, OVERLAY 7 over the icon), as the equipped slot has (#68)", function()
  local ok, why = framed(candIcon(d, TUMOR)); local ok2 = framed(icon(d, 14))
  return ok and ok2 and candIcon(d, TUMOR).selected, why end)
checkp("  (guard) ...the item compared is that one (its column in Changes, as before), and the other trinket has no frame", function()
  return find(d, "mhead", "Tumor of the Swarm") ~= nil and not candIcon(d, OTHERT).selEdges[1].shown end)
checkp("  (guard) ...the Item box holds the whole link as the bags gave it", function() return d.boxes.item.text == TUMOR, d.boxes.item.text end)
tu = candIcon(d, TUMOR); tu.scripts.OnClick(tu); d = drawn()
checkp("(guard) a second click lets it go: no frame, no column", function()
  return not candIcon(d, TUMOR).selEdges[1].shown and find(d, "mhead", "Tumor of the Swarm") == nil end)
-- the same item put in the box (shift-click / typed link) marks its icon too
ns.CharToolkit_SetInput("item", OTHERT)
d = drawn()
checkp("an item shift-clicked into the box (|cnIQ3: link) marks its icon in the list too", function() return framed(candIcon(d, OTHERT)) end)
checkp("(guard) the model: CM.ResolveItemLink keeps a named-colour link whole; two links of one item match (CM.InList by item string)", function()
  return CM.ResolveItemLink("  " .. TUMOR .. " ") == TUMOR and CM.InList({ "|Hitem:31::::::::90:::::|h[Tumor of the Swarm]|h" }, TUMOR) == 1
    and CM.InList({ NEWRING }, TUMOR) == nil end)
ns.CharToolkit_SetInput("item", "")
-- rings: several picked, each framed
local r1 = icon(drawn(), 11); r1.scripts.OnClick(r1); d = drawn()
local a = candIcon(d, NEWRING); a.scripts.OnClick(a); d = drawn()
local b = candIcon(d, BIGRING); b.scripts.OnClick(b); d = drawn()
checkp("two rings picked (|cnIQ4: and |cnIQ5: links): both framed", function()
  local ok1, w1 = framed(candIcon(d, NEWRING)); local ok2, w2 = framed(candIcon(d, BIGRING)); return ok1 and ok2, w1 or w2 end)

-- -----------------------------------------------------------------------------------------------------------------------------
-- C. #90: Changes: each compared number left-aligned, its difference in brackets to its right on the same line
-- -----------------------------------------------------------------------------------------------------------------------------
local function rowOf(dd, label)
  local L, i = find(dd, "mlabel", label)
  local out = { label = L, cells = {}, diffs = {}, subs = {} }
  if not L then return out end
  for j = i + 1, #dd.layout do
    local r = dd.layout[j]
    if r.kind == "mlabel" or r.kind == "msubhead" or r.kind == "mnote" or r.kind == "header" then break end
    if r.kind == "mcell" then out.cells[#out.cells + 1] = r elseif r.kind == "mdiff" then out.diffs[#out.diffs + 1] = r elseif r.kind == "msub" then out.subs[#out.subs + 1] = r end
  end
  return out
end
local function besideOK(dd)
  -- every difference: on its number's line, a space after it, inside the column; every number font string justified LEFT
  local cells, n = recs(dd, "mcell"), 0
  for _, df in ipairs(recs(dd, "mdiff")) do
    local cell
    for _, cc in ipairs(cells) do if cc.y == df.y and math.abs(df.x - (cc.x + cc.w + ns.CharToolkit_TextW(" ", cc.size))) < 0.01 then cell = cc end end
    if not cell then return false, "under or apart: " .. tostring(df.text) .. " at " .. df.x .. "," .. df.y end
    if not tostring(df.text):find("^%([%+%-][%d,%.]+%)$") then return false, "not in brackets: " .. tostring(df.text) end
    n = n + 1
  end
  for _, cc in ipairs(cells) do local f = fontAt(dd, cc); if not (f and f.jh == "LEFT") then return false, "cell " .. tostring(cc.text) .. " " .. tostring(f and f.jh) end end
  return n > 0, n .. " differences"
end
c.size, c.fontSize = nil, 11
d = render("gear")
local cr = rowOf(d, "Critical Strike")
checkp("Critical Strike: Equipped 100 | New Ring 300 (+200) | Big Crit Ring 1,000 (+900): \"(+200)\" right of 300 on the same line, no line under it", function()
  return T(cr.cells[1]) == "100" and T(cr.cells[2]) == "300" and T(cr.diffs[1]) == "(+200)" and cr.diffs[1].y == cr.cells[2].y and cr.diffs[1].x > cr.cells[2].x
    and #cr.subs == 0, T(cr.cells[2]) .. " " .. T(cr.diffs[1]) end)
checkp("  ...in the better / worse colour (green: more crit)", function() local f = fontAt(d, cr.diffs[1]); return f and f.color and f.color[2] > 0.9 and f.color[1] < 0.6 end)
local ms = rowOf(d, "Mastery")
checkp("Mastery: Equipped 400 | New Ring 388 (-12): the form of her example \"1,405 (-12)\", orange (less)", function()
  local f = ms.diffs[1] and fontAt(d, ms.diffs[1])
  return T(ms.cells[2]) == "388" and T(ms.diffs[1]) == "(-12)" and ms.diffs[1].y == ms.cells[2].y and f and f.color[1] > 0.9 and f.color[2] < 0.7, T(ms.cells[2]) .. " " .. T(ms.diffs[1]) end)
checkp("(guard) DR threshold's \"crosses ...\" and True / lost's \"L ...\" stay the line under their number", function()
  local tl = rowOf(d, "True / lost"); return #tl.subs > 0 and tostring(tl.subs[1].text):find("^L ") ~= nil end)
for _, m in ipairs({ "est", "scaled", "flat8" }) do
  MEASURE = m
  for _, pw in ipairs({ 340, 450, 760 }) do
    for _, fs in ipairs({ 8, 11, 16 }) do
      c.size, c.fontSize = { w = pw }, fs
      local dd = render("gear")
      local narrow = (pw == 340 and fs == 16)   -- (the one place a column may be narrower than "number (difference)": it goes under)
      checkp(("%sChanges, panel %d, text %d, measure %s: inside the width, no overlaps%s"):format(narrow and "(guard) " or "", pw, fs, m, narrow and "" or "; every difference beside its number, numbers left-aligned"), function()
        local ok, why = layoutOK(dd)
        if not ok then return false, why end
        if narrow then return true end
        return besideOK(dd) end)
    end
  end
end
MEASURE = "est"; c.size, c.fontSize = nil, 11
''')

# ---------------------------------------------------------------------------------------------------------------------------------
# D. #91: the header: equipped item level on the left, max (in bags) on the right; no name, class or spec
# E. B2: the % / rating toggle is gone in all three places; the saved keys are dropped
# ---------------------------------------------------------------------------------------------------------------------------------
run(STATWORLD, r'''
UnitName = function(u) if u == "player" then return "Xaya", nil end end
UnitClass = function(u) if u == "player" then return "Demon Hunter", "DEMONHUNTER", 12 end end
C_ClassColor = { GetClassColor = function(f) if f == "DEMONHUNTER" then return { r = 0.64, g = 0.19, b = 0.79 } end end }
local Pn = XayaUICharacterToolkit
local d = render()
local function allPanelText()
  local t = {}
  for _, k in ipairs({ "hEq", "hMax", "hName", "hSpec", "hIlvl", "hIlvlSub", "title" }) do if Pn[k] then t[#t + 1] = tostring(Pn[k].text) end end
  return table.concat(t, " | ")
end
checkp("header: left \"Equipped 334.2\" (GetAverageItemLevel's equipped 334.25), right \"Max (bags) 335.5\" (its overall 335.5)", function()
  return Pn.hEq and Pn.hEq.text == "Equipped 334.2" and Pn.hMax and Pn.hMax.text == "Max (bags) 335.5", allPanelText() end)
checkp("  ...no name, class or spec anywhere in it (Xaya, Demon Hunter, Vengeance), no class colour", function()
  local t = allPanelText()
  return not t:find("Xaya", 1, true) and not t:find("Demon Hunter", 1, true) and not t:find("Vengeance", 1, true)
    and not (Pn.hEq.color and sameCol(Pn.hEq.color, { 0.64, 0.19, 0.79 })), t end)
checkp("  ...left half anchored left, right half anchored right, each justified to its side", function()
  local pl, pr = Pn.hEq.pts[#Pn.hEq.pts], Pn.hMax.pts[#Pn.hMax.pts]
  return pl[1] == "TOPLEFT" and pr[1] == "TOPRIGHT" and Pn.hEq.jh == "LEFT" and Pn.hMax.jh == "RIGHT" end)
for _, m in ipairs({ "est", "scaled", "flat8" }) do
  MEASURE = m
  for _, pw in ipairs({ 340, 450, 760 }) do
    c.size = { w = pw }
    render()
    checkp(("header, panel %d, measure %s: each text on one line in its half; the halves never meet (a gutter between)"):format(pw, m), function()
      local W, L = ns.CHARTOOLKIT_LAYOUT.content, ns.CHARTOOLKIT_LAYOUT
      local a, b = Pn.hEq, Pn.hMax
      local size = a.font[2]
      local fits = textW(a.text, size) <= a.w and textW(b.text, b.font[2]) <= b.w
      return fits and a.w + b.w + ns.UI_GUTTER <= W, ("%s %.0f / %s %.0f in %d + %d of %d"):format(a.text, textW(a.text, size), b.text, textW(b.text, size), a.w, b.w, W) end)
  end
end
MEASURE = "est"; c.size = nil
checkp("  ...the tabs sit under the one-line header (title row, gutter, header, gutter)", function()
  local L = ns.CHARTOOLKIT_LAYOUT
  local pt = Pn.tabs[1].pts[#Pn.tabs[1].pts]
  return pt and pt[5] == -(L.pad + L.header - 20 - ns.UI_GUTTER) and L.header < 18 + 10 + 32 + 10 + 20 + 10, pt and pt[5] end)
local realAvg = GetAverageItemLevel
GetAverageItemLevel = nil; render()
checkp("no item level from the game: both halves empty (nothing guessed)", function() return Pn.hEq.text == "" and Pn.hMax.text == "" end)
GetAverageItemLevel = function() return SECRET, SECRET end; misuse = 0; render()
checkp("secret item levels: both empty, never compared or formatted", function() return Pn.hEq.text == "" and Pn.hMax.text == "" and misuse == 0 end)
GetAverageItemLevel = realAvg; render()

-- E. B2
checkp("B2: no \"Show: % / rating\" button is made in the title row (it was made and hidden)", function() return Pn.modeBtn == nil end)
checkp("B2: the old functions of the toggle are gone (FlipLine, SetValueMode, ModeFor)", function()
  return ns.CharToolkit_FlipLine == nil and ns.CharToolkit_SetValueMode == nil and ns.CharToolkit_ModeFor == nil end)
local pg = ns.BuildCharToolkitPage(function() end)
checkp("B2: Settings > Panel > Layout has no \"Rating lines\"; Your numbers has no \"Reset line flips\" (Clear all stays)", function()
  local p = pg.args.panelPart.args
  return p.layout.args.valueMode == nil and p.values.args.resetLines == nil and p.values.args.clear ~= nil end)
CueRulesDB.characterToolkit.valueMode = "rating"; CueRulesDB.characterToolkit.lineModes = { crit = "rating" }
c = ns.CharToolkit_Cfg()
checkp("B2: an old profile's valueMode / lineModes are dropped when the settings are read (harmless: nothing reads them)", function()
  return c.valueMode == nil and c.lineModes == nil and ns.CHARTOOLKIT_DEFAULTS.valueMode == nil and ns.CHARTOOLKIT_DEFAULTS.lineModes == nil end)
d = render()
local h, b = hoverOf(d, "map_crit")
checkp("B2: Critical Strike's hover offers no % / rating flip; a click opens its lines instead of flipping", function()
  if not b then return false, "no hover" end
  b.scripts.OnClick(b)
  local dd = drawn()
  return not h:find("Click: show the rating", 1, true) and not h:find("Click: show the percent", 1, true) and c.statOpen.map_crit == true
    and find(dd, "pairLabel", "Diminishing returns") ~= nil, h end)
''')

# ---------------------------------------------------------------------------------------------------------------------------------
# G. The in-game QA walkthroughs (V20 / V22): registered, pre-fill on, and each step's own check gives Pass on this code, read through
#    core's service list only (QAWalks-statcalc.lua names no QoL table)
# ---------------------------------------------------------------------------------------------------------------------------------
_qp = os.path.join(ROOT, "XayaUI_DevAssist", "QAWalks-statcalc.lua")
qas = open(_qp, encoding="utf-8").read() if os.path.exists(_qp) else ""   # (absent before Dev Assist 0.7.13)
code = re.sub(r"--[^\n]*", "", qas)
bad = [w for w in ("CharToolkit_", "CharModel", "XayaUICharacterToolkit", "CueRulesDB", "ns.InfoPane", "XayaUIInfoPane") if w in code]
n_static = 1; f_static = 0 if not bad else 1
print(("ok:   " if not bad else "FAIL: ") + "(guard) QAWalks-statcalc.lua reads the addons only through ns.Service (no QoL / Options table named)" + ("" if not bad else "  -> " + ", ".join(bad)))
totals.append((n_static, f_static))
run(GEARWORLD.replace("assert(loadfile(__MOD__))", "_G.XayaUI_NS = ns\nassert(loadfile(__MOD__))") + r'''
XayaUIDevAssistDB = {}
assert(loadfile(__QAW__))()
local qas = loadfile(__QAS__)   -- (absent before Dev Assist 0.7.13: the negative-control run keeps going and its checks fail)
if qas then qas() end
QA = XayaUI_DevQA
GetAverageItemLevel = function() return 335.5, 334.25 end
''', r'''
local ids = { "statcalc-rows", "statcalc-compare-highlight", "statcalc-changes-brackets", "statcalc-header", "statcalc-no-rating-toggle", "credits-page" }
local qaIds = { "E1z195", "E1z196", "E1z197", "E1z198", "E1z199", "E1z200" }
checkp("six walkthroughs registered, one per item (A-F), each with its QA id and pre-fill on", function()
  for i, id in ipairs(ids) do
    local w = QA.walks[id]
    if not (w and w.qa == qaIds[i] and w.prefill == true and #w.steps >= 2) then return false, id end
  end
  return true end)
local function st(id, i) return QA.walks[id] and QA.walks[id].steps[i] or { check = function() return false, "no walkthrough " .. id end } end
local function go(id, i) local s = st(id, i); if s.setup then s.setup() end; if s.check then return s.check() end; return true, "(no check)" end
-- A: rows (on the gear stand-in: the stats tab of a plain character)
checkp("walk A step 1 (Do it for me opens Stats): Pass", function() return go("statcalc-rows", 1) end)
checkp("walk A step 2 (Attack Power folded): Pass", function() return go("statcalc-rows", 2) end)
checkp("walk A step 3 (Do it for me opens it, from rows drawn): Pass", function() return go("statcalc-rows", 3) end)
ns.CharToolkit_SetInput("sv:primary", "2737")
checkp("walk A step 4 (typed number: a new value under a row): Pass", function() return go("statcalc-rows", 4) end)
ns.CharToolkit_SetInput("sv:primary", "")
checkp("walk A step 5 (still open after a rebuild, others folded): Pass", function() return go("statcalc-rows", 5) end)
checkp("walk A step 6 (Do it for me folds it): Pass", function() return go("statcalc-rows", 6) end)
checkp("walk A last step puts the tab and the open stats back", function() local ok = go("statcalc-rows", 7); return ok and c.statOpen.map_ap == nil end)
-- B: the compare highlight
checkp("walk B step 1 before a slot is picked: Fail (the check sees nothing picked)", function() local s = st("statcalc-compare-highlight", 1); s.setup(); return not s.check() end)
local r1 = icon(render("gear"), 11); r1.scripts.OnClick(r1)
checkp("walk B step 1 after a ring is picked: Pass", function() return st("statcalc-compare-highlight", 1).check() end)
local a = candIcon(drawn(), NEWRING); a.scripts.OnClick(a)
checkp("walk B step 2 after a bag ring is clicked (|cnIQ4: link): Pass (frame shown, on top, 3 px)", function() return st("statcalc-compare-highlight", 2).check() end)
-- C: brackets
checkp("walk C step 2 (Changes: every difference beside its number): Pass", function() return go("statcalc-changes-brackets", 2) end)
a = candIcon(drawn(), NEWRING); a.scripts.OnClick(a)
checkp("walk B step 3 after the same ring is clicked again: Pass", function() return st("statcalc-compare-highlight", 3).check() end)
checkp("walk B last step puts the tab back", function() return go("statcalc-compare-highlight", 4) end)
-- D: header
checkp("walk D step 1 (header texts match the game's two item levels; no name): Pass", function() return go("statcalc-header", 1) end)
checkp("walk D step 2 is a question for the person (no verdict offered)", function() return st("statcalc-header", 2).noVerdict == true and st("statcalc-header", 2).check == nil end)
-- E: toggle gone
checkp("walk E step 1 (no button, no saved keys): Pass", function() return go("statcalc-no-rating-toggle", 1) end)
checkp("walk E step 2 (no Rating lines, no Reset line flips): Pass", function() return go("statcalc-no-rating-toggle", 2) end)
-- F: XayaUI Options is not in this stand-in: the credits walkthrough says so instead of failing silently (tests/info_pane_run.py runs it)
checkp("(guard) walk F with XayaUI Options not loaded: its check says the pane is not open", function()
  local ok, why = st("credits-page", 1).check(); return ok == false and tostring(why):find("not open", 1, true) ~= nil, why end)
''')

n = sum(t[0] for t in totals); fails = sum(t[1] for t in totals)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
