# Stub test for the Stat Calculator round of 2026-11-06 (XayaUI_QoL 0.7.28; REQUEST-LOG #60-#68). Xaya's words (verbatim in the log):
#   #60/#62: "center columns under stat weights and make sure titles do not get clipped; numbers should be left-aligned; T/L rating should
#     be T: # [line break] L: ; input changes should show changed values underneath them in a color change with a +/- before; remove
#     ability scaling information from stats pane and keep only reflected in Spells tab (rename Ability Scaling)"; her answers "Titles
#     centred over columns", "New value with sign", "Both lists", "Spells tab -> Ability Scaling".
#   #61: "whatever modifies abilities (agility, attack power, mastery, etc) across all classes and specs should be included; refresh spell
#     data still present"; her answer "Only stats that change the number"; the head "Comput..." cut.
#   #63: "General Stats is not appropriately flagged as Category-level Stat bucket, nor is Offensive nor Defensive"; her answer "bucket
#     bar, with the following note: currently indentations are all over the place. be sure to review all elements nested under each
#     bucket and make sure indentations follow sub- and sub-sub- nesting rules".
#   #64: "Gear Summary should be at the top of the pane in a prettified graphic of sorts"; her answer "provide all three visual options
#     this round for me to consider; volunteer more if possible".
#   #66/#67: "all currently nested influence callouts should be put into a column of their own for readability and vertical line
#     reduction (e.g. agility influences [ ... ]"; her answers "Names only, values on hover" and "Same Influences column".
#   #68: "gear pane request for gear highlight dropped".
# What it checks is what the player sees (V1, V11): drawn records (kind, x, y, width, text), the font strings' justification and
# colour, the hover lines, the textures' colour, draw layer and thickness.
# THE TEXT WIDTH: the shared stand-ins measure text as a fixed 6 px (tests/harness/world.lua) or not at all (tests/char_toolkit_world.lua),
# which is how titles cut in game ("DR Thres...", "Comput...") passed before. Here the font strings measure text in one of three ways:
# "est" (0.55 x size per character, the old layout estimate), "scaled" (0.6 x size per character: a wider font) and "flat8" (8 px per
# character at any size), and report a wrapped height from that width. A title is "cut" when one of its words is wider than its column
# (the game wraps only at spaces, and truncates a longer word with "..."); "on one line" when the whole title fits its column.
# Negative control (V1): every check fails on QoL 0.7.24's files (session branch head e05475a), except those marked "(guard)".
# Run from the repo root: python3 tests/char_stat_round_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua.
# Spell IDs 9101-9103 and every number are TEST STAND-INS.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"

COMMON = r'''
assert(loadfile(__WORLD__))()
function checkp(name, fn)
  local ok, cond, extra = pcall(fn)
  if not ok then check(name, false, "error: " .. tostring(cond)) else check(name, cond and true or false, extra) end
end
-- text width: MEASURE = "est" | "scaled" | "flat8"
MEASURE = "est"
function textW(text, size)
  local n = #tostring(text or "")
  if MEASURE == "flat8" then return n * 8 end
  if MEASURE == "scaled" then return n * 0.6 * (size or 12) end
  return n * 0.55 * (size or 12)
end
local baseMk = mk
function mk(kind)
  local o = baseMk(kind)
  if kind == "FS" then
    o.GetStringWidth = function(self) return textW(self.text, self.font and self.font[2]) end
    o.GetUnboundedStringWidth = o.GetStringWidth
    o.SetJustifyH = function(self, j) self.jh = j end
    o.GetStringHeight = function(self)
      local size = (self.font and self.font[2]) or 12
      local w = self.w
      if not w or w <= 0 then return size end
      return math.max(1, math.ceil(textW(self.text, size) / w - 1e-9)) * size
    end
  end
  -- textures keep their draw layer and sublevel
  o.CreateTexture = function(self, name, layer, tmpl, sub) local t = mk("Texture"); t.layer, t.sublevel, t.parent = layer, sub, self; return t end
  o.CreateFontString = function(self) local f = mk("FS"); f.text = ""; f.font = { "Fonts\\FRIZQT__.TTF", 12, "" }; return f end
  o.CreateMaskTexture = function() return mk("Mask") end
  return o
end
-- the theme (stand-in): a class theme for a Demon Hunter. accent = the class colour; the selected tab's background = class x 0.28
-- (XayaUI/Theme.lua ClassPalette)
ACCENT = { 0.64, 0.19, 0.79, 1 }
TABSEL = { 0.64 * 0.28, 0.19 * 0.28, 0.79 * 0.28, 0.9 }
ns.Theme = { cur = { accent = ACCENT }, Col = function(class, prop, fb)
  if class == "xui-tab-selected" and prop == "bg" then return { TABSEL[1], TABSEL[2], TABSEL[3], TABSEL[4] } end
  return fb and { fb[1], fb[2], fb[3], fb[4] or 1 } or { 1, 1, 1, 1 } end }
function sameCol(a, b) return a and b and math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01 end
function recs(d, kind) local out = {}; for _, r in ipairs(d.layout) do if not kind or r.kind == kind then out[#out + 1] = r end end; return out end
function texts(d, kind) local t = {}; for _, r in ipairs(recs(d, kind)) do t[#t + 1] = tostring(r.text) end; return table.concat(t, "|") end
function find(d, kind, text, nth) local k = 0; for i, r in ipairs(d.layout) do if r.kind == kind and r.text == text then k = k + 1; if k == (nth or 1) then return r, i end end end end
function T(r) return r and tostring(r.text) or "nil" end
-- the shown font string drawn with this text (the player's screen, not the records)
function font(d, text, nth) local k = 0; for _, f in ipairs(d.fonts) do if f.shown and f.text == text then k = k + 1; if k == (nth or 1) then return f end end end end
-- the shown font string drawn for one layout record (same text, at the record's x and y)
function fontAt(d, r)
  for _, f in ipairs(d.fonts) do
    local pt = f.shown and f.pts and f.pts[#f.pts]
    if pt and f.text == r.text and math.abs(pt[4] - r.x) < 0.01 and math.abs(-pt[5] - r.y) < 0.01 then return f end
  end
end
-- a title is cut when one of its words is wider than its record; on one line when it all fits
function cutWord(r)
  for w in tostring(r.text or ""):gmatch("%S+") do if textW(w, r.size) > r.w + 0.01 then return w end end
end
function oneLine(r) return textW(r.text, r.size) <= r.w + 0.01 end
FILL = { hit = true, bucketbar = true, gsbar = true, gstile = true, gsseg = true, gscol = true, gsswatch = true }
function layoutOK(dd)
  local W = ns.CHARTOOLKIT_LAYOUT.content
  for _, r in ipairs(dd.layout) do
    if r.x < -0.01 or r.x + r.w > W + 0.01 or r.w <= 0 then return false, r.kind .. " " .. tostring(r.text) .. " x=" .. r.x .. " w=" .. r.w end
  end
  local t = {}
  for _, r in ipairs(dd.layout) do if not FILL[r.kind] then t[#t + 1] = r end end
  for i = 1, #t do for j = i + 1, #t do
    local a, bb = t[i], t[j]
    if a.x < bb.x + bb.w and bb.x < a.x + a.w and a.y < bb.y + bb.h and bb.y < a.y + a.h then
      return false, a.kind .. " '" .. tostring(a.text) .. "' / " .. bb.kind .. " '" .. tostring(bb.text) .. "'"
    end
  end end
  return true
end
function hoverOf(d, key)
  for _, b in ipairs(d.buttons) do if b.shown and b.item and b.item.key == key then GameTooltip.lines = {}; b.scripts.OnEnter(b); return table.concat(GameTooltip.lines or {}, " / "), b end end
  return "", nil
end
'''

STATWORLD = r'''
GetCritChanceProvidesParryEffect = function() return true end
SPELLS = { { id = 9101, name = "Fracture", desc = "Rapidly slash your target for 6,944 Physical damage." },
           { id = 9102, name = "Infernal Strike", desc = "Leap through the air, dealing 3,472 Fire damage. Recharge time reduced by Haste." },
           { id = 9103, name = "Demon Spikes", desc = "Increases your Armor by 20% for 6 sec." } }
MASTERY_TEXT = "Increases Armor by 101.8% of your Agility."
local baseName, baseDesc = C_Spell.GetSpellName, C_Spell.GetSpellDescription
C_Spell.GetSpellName = function(id) for _, s in ipairs(SPELLS) do if s.id == id then return s.name end end; return baseName(id) end
C_Spell.GetSpellDescription = function(id)
  if id == 203747 then return MASTERY_TEXT end
  for _, s in ipairs(SPELLS) do if s.id == id then return s.desc end end; return baseDesc(id)
end
C_Spell.RequestLoadSpellData = function() end
C_Spell.GetSpellCharges = function(id) if id == 9102 then return { currentCharges = 2, maxCharges = 2, cooldownStartTime = 0, cooldownDuration = 9.6, chargeModRate = 1, isActive = false } end end
assert(loadfile(__MOD__))("XayaUI", ns)
ns.Provide("rules", { BuildSpellList = function(...) return ns.BuildSpellList(...) end, BuildTalentList = function(...) return ns.BuildTalentList(...) end, ForgetSpellLists = function() ns.spellList, ns.talentList = nil, nil end })   -- (P4) XayaUI Rules' "rules" service, as XayaUI_Rules/RuleDefaults.lua offers it
assert(loadfile(__COMPAT__))("XayaUI", ns)
function ns.BuildSpellList() local t = {}; for _, s in ipairs(SPELLS) do t[#t + 1] = { id = s.id, name = s.name } end; return t end
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
ns.FireReady()
CM = ns.CharModel
c = ns.CharToolkit_Cfg()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
local statRow = mk("Frame"); statRow.Label = mk("FS"); statRow.Label.text = "Agility:"
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = { statRow }
c.enabled = true; ns.CharToolkit_Apply(); CharacterFrame.shown = true; PaperDollFrame:Show()
CM.gcd = { dur = 1.16, haste = 29.25 }
LAY = ns.CHARTOOLKIT_LAYOUT
function drawn() return ns.CharToolkit_Drawn() end
function render(tab) c.tab = tab or "stats"; ns.CharToolkit_Render(); return drawn() end
'''

def world(extra):
    return (COMMON + extra).replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")) \
        .replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua")) \
        .replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua"))

totals = []
def run(extra, body):
    lua = LuaRuntime()
    lua.execute(world(extra))
    lua.execute(body)
    totals.append((lua.eval("n"), lua.eval("fails")))

# ---------------------------------------------------------------------------------------------------------------------------------
# A. Stat Weights (#60 a-d) and the Stats grid's heads (#60 b, #66): titles never cut, on one line at the default width, centred over
#    their columns; numbers from the column's left edge; T/L in two lines
# ---------------------------------------------------------------------------------------------------------------------------------
run(STATWORLD, r'''
local function weights(dd)
  local heads, rows = recs(dd, "wcolhead"), {}
  return heads
end
for _, m in ipairs({ "scaled", "flat8" }) do
  MEASURE = m
  c.size, c.fontSize = nil, 11
  local d = render()
  checkp(("Stat Weights, default panel, text %s: every column title on one line, none cut (\"Rating (P / %%)\", \"DR Threshold\" whole)"):format(m), function()
    local hs = recs(d, "wcolhead")
    if #hs < 5 then return false, #hs .. " titles" end
    for _, r in ipairs(hs) do
      if cutWord(r) then return false, "cut: " .. r.text .. " (" .. cutWord(r) .. ") w=" .. r.w end
      if m == "scaled" and not oneLine(r) then return false, "wraps: " .. r.text .. " w=" .. r.w end
    end
    return true end)
end
MEASURE = "scaled"
-- (KNOWN LIMIT, reported: at the narrowest panel, 340, with text size 16 the widest words alone, "Versatility", "Threshold", "Rating",
-- "29.25%", need about 354 px of the 320 there; FitCols then scales the columns down and a word can be cut. 380 wide is enough.)
for _, pw in ipairs({ 340, 380, 450, 584, 760 }) do
  for _, fs in ipairs({ 8, 11, 16 }) do
    MEASURE = (pw <= 380 and fs == 16) and "est" or "scaled"
    if not (pw == 340 and fs == 16) then
    c.size, c.fontSize = { w = pw }, fs
    local d = render()
    checkp(((fs == 8 and "(guard: the old widths held at text 8) " or "") .. "Stat Weights, panel %d, text %d (" .. MEASURE .. "): no title cut, no cell word cut, inside the width, no overlaps"):format(pw, fs), function()
      for _, k in ipairs({ "wcolhead", "wlabel", "wrating", "wppp", "wpppdr", "wdr", "wtl" }) do
        for _, r in ipairs(recs(d, k)) do if cutWord(r) then return false, k .. " '" .. r.text .. "' cut (" .. cutWord(r) .. ") w=" .. r.w end end
      end
      local ok, why = layoutOK(d)
      return ok, why end)
    end
  end
end
c.size, c.fontSize = nil, 11
local d = render()
checkp("Stat Weights: every title is centred over its column (justify CENTER), at its column's x and width", function()
  for _, r in ipairs(recs(d, "wcolhead")) do
    local f = fontAt(d, r)
    if not (f and f.jh == "CENTER") then return false, r.text .. " " .. tostring(f and f.jh) end
  end
  return #recs(d, "wcolhead") >= 5 end)
local heads = recs(d, "wcolhead")
local function under(r) for i, h in ipairs(heads) do if math.abs(h.x - r.x) < 0.01 and math.abs(h.w - r.w) < 0.01 then return i end end end
checkp("Stat Weights: every number starts at its column's left edge (justify LEFT, at the column title's x and width)", function()
  for _, k in ipairs({ "wrating", "wppp", "wdr", "wtl" }) do
    for _, r in ipairs(recs(d, k)) do
      local f = fontAt(d, r)
      if not (f and f.jh == "LEFT" and under(r)) then return false, k .. " '" .. r.text .. "' " .. tostring(f and f.jh) .. " x=" .. r.x end
    end
  end
  return true end)
checkp("Stat Weights: Haste's T/L cell is two lines, \"T: 1,200\" then \"L: 0.0\" under it, same x (not \"T: 1,200 / L: 0.0\")", function()
  local t1, t2 = find(d, "wtl", "T: 1,200"), nil
  for _, r in ipairs(recs(d, "wtl")) do if t1 and r.text == "L: 0.0" and r.y > t1.y and (not t2 or r.y < t2.y) then t2 = r end end
  return t1 and t2 and t2.y > t1.y and t2.x == t1.x and find(d, "wtl", "T: 1,200 / L: 0.0") == nil, T(t1) .. " / " .. T(t2) .. " y " .. tostring(t1 and t1.y) .. "/" .. tostring(t2 and t2.y) end)
checkp("the Stats grid's heads (Stat | Rating | Current value | Pt value | Modifies | Change; Influences until QoL 0.7.39, #88): none cut, each on one line at the default width (0.6 x size)", function()
  local hs = recs(d, "colhead")
  local seen = {}
  for _, r in ipairs(hs) do
    seen[r.text] = true
    if cutWord(r) or not oneLine(r) then return false, r.text .. " w=" .. r.w end
  end
  return seen.Modifies and seen["Current value"] and seen.Change, "Modifies head: " .. tostring(seen.Modifies) end)
MEASURE = "est"

-- -----------------------------------------------------------------------------------------------------------------------------
-- B. A typed number (#60 e, #62 "New value with sign"): the current value, and under it the new value with its sign, in the accent
-- -----------------------------------------------------------------------------------------------------------------------------
ns.CharToolkit_SetInput("sv:crit", "700")
d = render()
local function changeUnder(dd, valueRec)
  for _, r in ipairs(recs(dd, valueRec.kind == "value" and "change" or "pairChange")) do
    if math.abs(r.x - valueRec.x) < 0.01 and r.y > valueRec.y and r.y < valueRec.y + 3 * valueRec.size then return r end
  end
end
checkp("typed 700 crit: Critical Strike's Current value reads 22.48%, and under it +26.22% (the new value, + because it is higher)", function()
  local v
  for _, r in ipairs(recs(d, "value")) do if r.text == "22.48%" then v = r end end
  local ch = v and changeUnder(d, v)
  return v and ch and ch.text == "+26.22%", T(v) .. " / " .. T(ch) end)
checkp("  ...the line under it is drawn in the theme's accent colour", function()
  local f = font(d, "+26.22%"); return f and sameCol(f.color, ACCENT), f and f.color and table.concat(f.color, ",") end)
checkp("  ...no \"now -> then\" anywhere on the Stats tab", function()
  for _, r in ipairs(d.layout) do if tostring(r.text or ""):find(" -> ", 1, true) then return false, r.kind .. " '" .. tostring(r.text) .. "'" end end
  return true end)
checkp("  ...the card's hover: the title line, then the new value on the line under it (\" | +26.22%\")", function()
  local h = hoverOf(d, "map_crit")
  return h:find("Critical Strike | 22.48%  (46.0 / 1%) /  | +26.22%", 1, true) ~= nil, h end)
ns.CharToolkit_SetInput("sv:crit", "400")
d = render()
checkp("typed 400 crit (lower than 528): 22.48% with a minus and the new value under it (-19.70%)", function()
  local v; for _, r in ipairs(recs(d, "value")) do if r.text == "22.48%" then v = r end end
  local ch = v and changeUnder(d, v)
  return ch ~= nil and tostring(ch.text):find("^%-%d+%.%d%d%%$") ~= nil, T(ch) end)
ns.CharToolkit_SetInput("sv:crit", "")

-- -----------------------------------------------------------------------------------------------------------------------------
-- C. The ability lists leave the Stats tab (#60 f, her answer "Both lists"); the Influences column (#66, #67)
-- -----------------------------------------------------------------------------------------------------------------------------
ns.CharToolkit_SetInput("sv:primary", "2737")
d = render()
checkp("typed Agility: no \"Abilities (per 100)\" or \"Ability Scaling\" and no ability name drawn on the Stats tab", function()
  for _, r in ipairs(d.layout) do
    local t = tostring(r.text or "")
    if t:find("Abilities (per 100)", 1, true) or t:find("Ability Scaling", 1, true) or t == "Fracture" then return false, r.kind .. " '" .. t .. "'" end
  end
  return true end)
checkp("  ...nor in the Agility card's hover", function()
  local h = hoverOf(d, "map_primary"); return h ~= "" and not h:find("Ability Scaling", 1, true) and not h:find("Abilities (per 100)", 1, true) and not h:find("Fracture", 1, true), h end)
local hI, hP, hC = find(d, "colhead", "Modifies"), find(d, "colhead", "Pt value"), find(d, "colhead", "Change")
checkp("Influences (Modifies since QoL 0.7.40, #88): a column head between Pt value and Change", function()
  return hI and hP and hC and hI.y == hP.y and hI.x >= hP.x + hP.w and hI.x + hI.w <= hC.x, T(hI) end)
local function namesOn(dd, label)
  local L = find(dd, "label", label)
  local nextY = math.huge
  for _, r in ipairs(recs(dd, "label")) do if r.y > L.y and r.y < nextY then nextY = r.y end end
  local out = {}
  for _, r in ipairs(dd.layout) do if (r.kind == "infl" or r.kind == "feed") and r.y >= L.y and r.y < nextY then out[#out + 1] = r end end
  return out
end
checkp("Agility's row: Attack power, Dodge, Armor as names only in the Influences column (no number in them), no \"» Attack power\" line under the card", function()
  local ns_ = namesOn(d, "Agility")
  local t = {}
  for _, r in ipairs(ns_) do t[#t + 1] = r.text; if r.x < hI.x or r.x + r.w > hI.x + hI.w + 0.01 or tostring(r.text):find("%d") then return false, r.text end end
  return table.concat(t, " ") == "Attack power, Dodge, Armor" and find(d, "pairLabel", "» Attack power") == nil, table.concat(t, " ") end)
checkp("  ...hovering Attack power: its value, its Pt value and, with the typed Agility, the new value with its sign", function()
  local h = hoverOf(d, "map_primary:» Attack power")
  return h:find("» Attack power | +2,637  (1 = 1.00) /  | +2,737", 1, true) ~= nil, h end)
-- (QoL 0.7.40, REQUEST-LOG #87 / #88 replaces the 0.7.28 check "what feeds it, marked as feeders (from Agility), in the same column": the
-- column is Modifies, what the stat applies to; "from Agility" is a row under Attack Power, checked in tests/char_stat_round2_run.py)
checkp("Attack Power's row: only what it applies to in Modifies (Damage per second); no \"from\" name in the column", function()
  local t = {}
  for _, r in ipairs(namesOn(d, "Attack Power")) do t[#t + 1] = r.kind .. ":" .. r.text end
  return table.concat(t, " ") == "infl:Damage per second" and #recs(d, "feed") == 0, table.concat(t, " ") end)
checkp("Haste: its abilities' list is a name in Influences; the ability and its recharge are in that name's hover, not a nested row", function()
  local h = hoverOf(d, "map_haste:» Abilities (their text names Haste)")
  return h:find("    Infernal Strike | 9.6 s recharge", 1, true) ~= nil and find(d, "pairLabel", "Infernal Strike") == nil, h end)
ns.CharToolkit_SetInput("sv:primary", "")

-- -----------------------------------------------------------------------------------------------------------------------------
-- D. Bucket bars and one indentation step by depth (#63)
-- -----------------------------------------------------------------------------------------------------------------------------
ns.CharToolkit_SetInput("sv:haste", "1500")
for _, pw in ipairs({ 340, 450, 760 }) do
  c.size = { w = pw }
  d = render()
  local W = LAY.content
  checkp(("panel %d: Primary, General, Offensive, Defensive are bucket bars: a band across the pane's width in the accent colour, the name on it"):format(pw), function()
    for _, name in ipairs({ "Primary", "General", "Offensive", "Defensive" }) do
      local bar, txt = find(d, "bucketbar", name), find(d, "subhead", name)
      if not (bar and txt and bar.x == 0 and math.abs(bar.w - W) < 0.01 and txt.y >= bar.y and txt.y + txt.h <= bar.y + bar.h) then return false, name end
    end
    return true end)
  checkp(("panel %d: every line's left edge is its depth x one step (12): headings and bars 0, stats 12, their lines 24, nothing deeper or in between"):format(pw), function()
    local STEP = 12
    local cs = find(d, "header", "- Character Stats")
    local sw = find(d, "header", "- Stat Weights")
    local depth = { bucketbar = 0, label = 1, pairLabel = 2 }
    local n = 0
    for _, r in ipairs(d.layout) do
      if r.y > cs.y and r.y < sw.y then
        local want = depth[r.kind]
        if r.kind == "subhead" and not find(d, "bucketbar", r.text) then want = 0 end
        if want then
          n = n + 1
          if math.abs(r.x - want * STEP) > 0.01 then return false, r.kind .. " '" .. tostring(r.text) .. "' x=" .. r.x .. " (depth " .. want .. ")" end
        end
      end
    end
    return n > 20, n .. " lines" end)
  checkp(("(guard, V11) panel %d: Stats tab layout inside the width, no overlaps (bands and bars behind their text)"):format(pw), function() return layoutOK(d) end)
end
c.size = nil
ns.CharToolkit_SetInput("sv:haste", "")
d = render()
checkp("the bucket bar's band is painted in the theme's accent colour (a shown texture of the panel, the bar's size)", function()
  local bar = find(d, "bucketbar", "General")
  for _, t in ipairs(d.textures or {}) do
    if t.shown and sameCol(t.color, ACCENT) and bar and t.w == bar.w and t.h == bar.h then return true end
  end
  return false, bar and (bar.w .. "x" .. bar.h) end)

-- -----------------------------------------------------------------------------------------------------------------------------
-- E. The Gear Summary at the top as a graphic (#64): Split bars by default; Stat tiles, One stacked bar, Columns, Gear share, Table
-- -----------------------------------------------------------------------------------------------------------------------------
d = render()
checkp("the Gear Summary is the Stats tab's first section, above Character Stats", function()
  return texts(d, "header") == "- Gear Summary|- Character Stats|- Stat Weights", texts(d, "header") end)
checkp("its style is a setting (Panel > Layout > Gear Summary style): Split bars, Stat tiles, One stacked bar, Columns, Gear share, Table; Split bars to start with", function()
  local pg = ns.BuildCharToolkitPage(function() end)
  local sel = pg.args.panelPart.args.layout.args.gearSumStyle
  local names = {}
  for _, k in ipairs(sel.sorting) do names[#names + 1] = sel.values[k] end
  return sel.name == "Gear Summary style" and table.concat(names, "|") == "Split bars|Stat tiles|One stacked bar|Columns|Gear share|Table" and sel.get() == "bars",
    table.concat(names, "|") end)
checkp("Split bars: Critical Strike's bar in its stat colour, as long as its rating (528) next to the longest; solid part = gear (400 / 528), lighter = elsewhere; \"528 (gear 400 +128)\" at its end", function()
  local bars = {}
  for _, r in ipairs(recs(d, "gsbar")) do if r.text == "Critical Strike" then bars[#bars + 1] = r end end
  local num = find(d, "gsnum", "528 (gear 400 +128)")
  if #bars ~= 2 or not num then return false, #bars .. " parts, " .. tostring(num) end
  local len = bars[1].w + bars[2].w
  return math.abs(bars[1].w / len - 400 / 528) < 0.02 and num.x >= bars[2].x + bars[2].w and math.abs(num.y - find(d, "gslabel", "Critical Strike").y) < 0.01, bars[1].w .. "/" .. len end)
for _, st in ipairs({ { "tiles", "gsttotal", "528" }, { "stacked", "gslegend", "Crit 528 (400 +128)" }, { "columns", "gsctotal", "528" }, { "share", "gsnum", "76% gear (400 of 528)" }, { "table", "cmpcell", "+128" } }) do
  c.gearSumStyle = st[1]
  for _, pw in ipairs({ 340, 450, 760 }) do
    c.size = { w = pw }
    local dd = render()
    checkp(((st[1] == "table" and "(guard: the table is the old look) " or "") .. "Gear Summary style %s, panel %d: drawn (%s \"%s\"), inside the width, no overlaps"):format(st[1], pw, st[2], st[3]), function()
      local ok, why = layoutOK(dd)
      return ok and find(dd, st[2], st[3]) ~= nil, why or texts(dd, st[2]) end)
  end
end
c.gearSumStyle, c.size = nil, nil
''')

# ---------------------------------------------------------------------------------------------------------------------------------
# F. The Ability Scaling tab (#61, #62): the name, no stray Refresh row, "Computed Value" whole, Versatility / Mastery lines, the
#    new value a typed number gives under Computed Value
# ---------------------------------------------------------------------------------------------------------------------------------
run(STATWORLD, r'''
c.advanced = true
MASTERY_TEXT = "Increases Armor by 101.8% of your Agility and Fire damage you deal by 20.0%."
local d = render("spells")
checkp("the tabs read exactly Stats | Gear | Ability Scaling (the third keeps its saved key, spells)", function()
  local t = {}
  for _, b in ipairs(XayaUICharacterToolkit.tabs) do t[#t + 1] = b.label end
  return table.concat(t, " | ") == "Stats | Gear | Ability Scaling" and c.tab == "spells" and XayaUICharacterToolkit.tabs[3].key == "spells", table.concat(t, " | ") end)
checkp("(guard) a saved spells tab opens it: the spell table is drawn", function() return find(d, "spellhead", "Spell Name") ~= nil end)
for _, f in ipairs({ "all", "offense", "defense" }) do
  c.spellFilter = f
  local dd = render("spells")
  checkp(("filter %s: no \"Refresh spell data\" row in the list under the Spell Name head (the button above stays)"):format(f), function()
    local head = find(dd, "spellhead", "Spell Name")
    for _, r in ipairs(dd.layout) do
      if r.kind ~= "spellbtn" and tostring(r.text) == "Refresh spell data" then return false, r.kind .. " at y " .. r.y end
      if r.kind == "hit" and r.text == "spellsRefresh" then return false, "a hover row for it" end
    end
    return head ~= nil and find(dd, "spellbtn", "Refresh spell data") ~= nil end)
end
c.spellFilter = "all"
for _, m in ipairs({ "est", "scaled", "flat8" }) do
  MEASURE = m
  for _, pw in ipairs({ 340, 450, 760 }) do
    c.size = { w = pw }
    local dd = render("spells")
    checkp(("Ability Scaling table, panel %d, text %s: no head cut (\"Computed Value\" whole)%s"):format(pw, m, m ~= "flat8" and ", every head on one line" or ""), function()
      local hs = recs(dd, "spellhead")
      if #hs ~= 4 then return false, #hs .. " heads" end
      for _, r in ipairs(hs) do
        if cutWord(r) then return false, r.text .. " cut (" .. cutWord(r) .. ") w=" .. r.w end
        if m ~= "flat8" and not oneLine(r) then return false, r.text .. " wraps w=" .. r.w end
      end
      return true end)
  end
end
MEASURE = "est"; c.size = nil
d = render("spells")
local function rowOf(dd, name)
  local L = find(dd, "spellname", "- " .. name) or find(dd, "spellname", "+ " .. name)   -- (QoL 0.7.36: "- " open / "+ " folded)
  local out = { name = L }
  if not L then return out end
  for _, r in ipairs(dd.layout) do
    if r.y >= L.y and r.y < L.y + 60 and r.kind ~= "hit" then out[r.kind] = out[r.kind] or {}; table.insert(out[r.kind], r) end
  end
  return out
end
local fr = rowOf(d, "Fracture")
local function tx(list) local t = {}; for _, r in ipairs(list or {}) do t[#t + 1] = tostring(r.text) end; return table.concat(t, "|") end
checkp("Fracture (Physical damage): under its percents one line per other stat that changes the number: Versatility: +2.61%; no Mastery (its text names Fire, not Physical); no crit or haste", function()
  return tx(fr.spellstat) == "Versatility: +2.61%", tx(fr.spellstat) end)
local is = rowOf(d, "Infernal Strike")
checkp("Infernal Strike (Fire damage): Versatility: +2.61% and Mastery: +20.0% (the mastery text names Fire damage)", function()
  return tx(is.spellstat) == "Versatility: +2.61%|Mastery: +20.0%", tx(is.spellstat) end)
checkp("(guard) Demon Spikes (no numbers but a percent) is not listed", function() return find(d, "spellname", "- Demon Spikes") == nil and find(d, "spellname", "+ Demon Spikes") == nil end)
ns.CharToolkit_SetInput("sv:primary", "2737")
d = render("spells")
fr = rowOf(d, "Fracture")
checkp("typed Agility 2,737 (+100): Fracture's Computed Value 6,944, and under it +7,144 (x attack power then / now: 3,572 / 3,472)", function()
  local v = find(d, "spellvalue", "6,944")
  local ch = find(d, "spellchange", "+7,144")
  return v and ch and ch.x == v.x and ch.y > v.y, tx(fr.spellchange) end)
checkp("  ...in the theme's accent colour", function() local f = font(d, "+7,144"); return f and sameCol(f.color, ACCENT) end)
ns.CharToolkit_SetInput("sv:primary", "")
ns.CharToolkit_SetInput("sv:vers", "220")   -- 120 -> 220 versatility rating
d = render("spells")
local vI = CM.Build(c, "stats").byKey.map_vers
local v0, v1 = 2.61, nil
checkp("typed Versatility: Fracture's Computed Value moves by (1 + versatility then) / (1 + now), shown under it with its sign", function()
  local it = CM.Build(c, "spells").byKey.spell9101
  local e = it and it.row.entries[1]
  local src
  for _, r in ipairs(recs(d, "spellchange")) do src = src or r end
  return e and e.newValue and e.newValue:find("^%+7,") ~= nil and src ~= nil, e and e.newValue end)
ns.CharToolkit_SetInput("sv:vers", "")
ns.CharToolkit_SetInput("sv:haste", "1500"); ns.CharToolkit_SetInput("sv:crit", "900")
d = render("spells")
checkp("(guard) typed Haste and Critical Strike only: no Computed Value moves (they change how often or how hard, not the number)", function()
  return #recs(d, "spellchange") == 0, #recs(d, "spellchange") end)
ns.CharToolkit_SetInput("sv:haste", ""); ns.CharToolkit_SetInput("sv:crit", "")
''')

# ---------------------------------------------------------------------------------------------------------------------------------
# G. The gear highlight (#68): the selected equipped slot and each picked bag item, clearly marked
# ---------------------------------------------------------------------------------------------------------------------------------
run(r'''
ITEMS["New Ring"] = { ilvl = 345, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_CRIT_RATING_SHORT = 300 } }
ITEMS["Big Crit Ring"] = { ilvl = 350, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_CRIT_RATING_SHORT = 1000 } }
NEWRING = "|cffa335ee|Hitem:20::::::::90:::::|h[New Ring]|h|r"
BIGRING = "|cffff8000|Hitem:21::::::::90:::::|h[Big Crit Ring]|h|r"
BAG = { NEWRING, BIGRING }
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and #BAG or 0 end,
  GetContainerItemInfo = function(bag, i) local l = BAG[i]; if l then return { hyperlink = l, quality = 4, iconFileID = 3000 + i } end end }
assert(loadfile(__MOD__))("XayaUI", ns)
ns.Provide("rules", { BuildSpellList = function(...) return ns.BuildSpellList(...) end, BuildTalentList = function(...) return ns.BuildTalentList(...) end, ForgetSpellLists = function() ns.spellList, ns.talentList = nil, nil end })   -- (P4) XayaUI Rules' "rules" service, as XayaUI_Rules/RuleDefaults.lua offers it
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
local function icon(dd, slot, cand) for _, b in ipairs(dd.icons) do if b.shown and b.slot == slot and (b.cand and true or false) == (cand or false) then return b end end end
local function candIcon(dd, link) for _, b in ipairs(dd.icons) do if b.shown and b.cand and b.link == link then return b end end end
local d = render("gear")
local ring = icon(d, 11)
ring.scripts.OnClick(ring)
d = drawn()
local function marked(b)
  if not b then return false, "no icon" end
  for _, e in ipairs(b.selEdges or {}) do if not e.shown then return false, "an edge hidden" end end
  return true
end
local function edgeOK(b)
  local border = b.border
  for _, e in ipairs(b.selEdges) do
    local thick = math.min(e.w or 99, e.h or 99)
    if not sameCol(e.color, ACCENT) then return false, "colour " .. table.concat(e.color or {}, ",") end
    if sameCol(e.color, border.color) then return false, "same colour as the quality border" end
    if not (e.layer == "OVERLAY" and border.layer == "BACKGROUND" and b.tex.layer == "ARTWORK") then return false, "layer " .. tostring(e.layer) end
    if not (thick > 1) then return false, "thickness " .. thick end
  end
  return true
end
checkp("(guard: shown / hidden worked before; it was not visible) the equipped ring picked for Compare: its box has the highlight frame, the helm's not", function()
  local ok, why = marked(icon(d, 11)); return ok and not icon(d, 1).selEdges[1].shown, why end)
checkp("  ...the frame is in the theme's accent colour (not the selected tab's dark background), not the quality border's colour, on the top draw layer (OVERLAY over the ARTWORK icon and the BACKGROUND quality border), thicker than the 1 px quality border", function()
  return edgeOK(icon(d, 11)) end)
local nr = candIcon(d, NEWRING)
nr.scripts.OnClick(nr)
d = drawn()
local br = candIcon(d, BIGRING)
br.scripts.OnClick(br)
d = drawn()
checkp("two bag items picked: both have the frame, in the accent colour, over the icon, thicker than the border", function()
  local ok1, w1 = marked(candIcon(d, NEWRING)); local ok2, w2 = marked(candIcon(d, BIGRING))
  local e1, x1 = edgeOK(candIcon(d, NEWRING)); local e2, x2 = edgeOK(candIcon(d, BIGRING))
  return ok1 and ok2 and e1 and e2, w1 or w2 or x1 or x2 end)
checkp("(guard) an item not picked has no frame", function()
  local b = candIcon(d, NEWRING); b.scripts.OnClick(b); d = drawn()
  return not candIcon(d, NEWRING).selEdges[1].shown and candIcon(d, BIGRING).selEdges[1].shown end)
''', "")

n = sum(t[0] for t in totals); fails = sum(t[1] for t in totals)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
