# Stub test for the Stat Calculator round of 2026-11-06 (XayaUI_QoL 0.7.28; REQUEST-LOG #60-#68). Xaya's words (verbatim in the log):
# (Bonus 0.6.45, main: ported from qa-installer-branch to main's tree: the stat model and its arithmetic load from XayaUI_Bonus, and nothing of XayaUI QoL is loaded.)
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
# color, the hover lines, the textures' color, draw layer and thickness.
# THE TEXT WIDTH: the shared stand-ins measure text as a fixed 6 px (tests/harness/world.lua) or not at all (tests/char_world.lua),
# which is how titles cut in game ("DR Thres...", "Comput...") passed before. Here the font strings measure text in one of three ways:
# "est" (0.55 x size per character, the old layout estimate), "scaled" (0.6 x size per character: a wider font) and "flat8" (8 px per
# character at any size), and report a wrapped height from that width. A title is "cut" when one of its words is wider than its column
# (the game wraps only at spaces, and truncates a longer word with "..."); "on one line" when the whole title fits its column.
# Negative control (V1): every check fails on QoL 0.7.24's files (session branch head e05475a), except those marked "(guard)".
# QoL 0.7.54 / Bonus 0.6.38 (Xaya 2026-11-08, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #5 / #6 / #15): the new value a typed number
# gives is no longer in the accent color: green better / red worse (the game's GREEN_FONT_COLOR / RED_FONT_COLOR, stand-ins below with
# their own values so a copied number cannot pass), blue / orange with a XayaUI color-blind base theme (read from XayaUI/Theme.lua's
# colorblind palette), the text color when the same; a stat's name in its color in the hovers and the Ability Scaling rows. Section K;
# its checks fail on 930a0c7 (QoL 0.7.53 / Bonus 0.6.37), except those marked "(guard)".
# Run from the repo root: python3 tests/char_stat_round_run.py   Needs: pip install lupa. Stand-in world: tests/char_world.lua.
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
-- the theme (stand-in): a class theme for a Demon Hunter. accent = the class color; the selected tab's background = class x 0.28
-- (XayaUI/Theme.lua ClassPalette)
ACCENT = { 0.64, 0.19, 0.79, 1 }
TABSEL = { 0.64 * 0.28, 0.19 * 0.28, 0.79 * 0.28, 0.9 }
ns.Theme = { cur = { accent = ACCENT }, Col = function(class, prop, fb)
  if class == "xui-tab-selected" and prop == "bg" then return { TABSEL[1], TABSEL[2], TABSEL[3], TABSEL[4] } end
  return fb and { fb[1], fb[2], fb[3], fb[4] or 1 } or { 1, 1, 1, 1 } end }
-- (A24 #9) each stand-in measure is a font of its own: the theme's font path names it, as switching XayaUI's font does in game (the
-- panel works its width need out again when the font changes, not only the size or the text)
ns.Theme.FontPath = function() return "Fonts\\STANDIN_" .. tostring(MEASURE) .. ".TTF" end
-- (QoL 0.7.54 / Bonus 0.6.38) stand-ins for the game's color objects (ColorMixin, :GetRGB()), with values of their own, so only a
-- color read from them at run time passes
GREEN_FONT_COLOR = { GetRGB = function() return 0.12, 0.88, 0.14 end }
RED_FONT_COLOR = { GetRGB = function() return 0.93, 0.11, 0.09 end }
GREEN, RED = { 0.12, 0.88, 0.14, 1 }, { 0.93, 0.11, 0.09, 1 }
TEXT = { 0.96, 0.96, 0.98, 1 }   -- (the stand-in theme's "xui-text" answer: the panel's own fallback)
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
  local W = ns.STATCALC_LAYOUT.content
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
-- (A24 #9, Xaya 2026-11-11, her words: "Widen the panel") the known limits of A24 #7 round 2 (CUT_LIMIT: words cut where the six
-- columns' widest words did not fit the panel; LINES3_LIMIT: one title on three lines) are gone as allowances: the panel widens to
-- the width the six columns need, so at every panel width, text size and stand-in font NOTHING is cut (sections A, L, M).
-- every cut word in the Stat Weights pane (titles and cells)
function wCuts(d)
  local out = {}
  for _, k in ipairs({ "wcolhead", "wlabel", "wrating", "wppp", "wpppdr", "wdr", "wtl", "winfl" }) do
    for _, r in ipairs(recs(d, k)) do if cutWord(r) then out[#out + 1] = k .. " '" .. tostring(r.text) .. "' (" .. cutWord(r) .. ") w=" .. r.w end end
  end
  return out
end
-- how many lines a title takes in its column: the game wraps at spaces, filling each line first
function titleLines(r)
  local n, cur = 1, nil
  for w in tostring(r.text or ""):gmatch("%S+") do
    local t = cur and (cur .. " " .. w) or w
    if cur and textW(t, r.size) > r.w + 0.01 then n = n + 1; cur = w else cur = t end
  end
  return n
end
function mostLines(d)
  local most, which = 0, ""
  for _, h in ipairs(recs(d, "wcolhead")) do local n = titleLines(h); if n > most then most, which = n, h.text end end
  return most, which
end
-- (A24 #10, Xaya 2026-11-12, her answer verbatim: "1 + Rename to Rating"; option 1: the panel widens so every Stat Weights title fits
-- on at most two lines) THREE_LINES, the cases A24 #9 left open for her ("Rating (P / %)" on three lines at the widest words' width),
-- is EMPTY: every case of the grid ("font:panel width:text size") keeps every title on at most two lines. Negative control (V1): on
-- the pre-change tree (54e6c5d) the 36 cases that were listed here draw "Rating (P / %)" on three lines and fail.
THREE_LINES = {}
-- the check for one drawn case: no title or cell word cut, inside the width, no overlaps, and every title on at most two lines
function limitCheck(d, key)
  return "no title or cell word cut (A24 #9: the panel widens); inside the width, no overlaps; every title on at most two lines (A24 #10)", function()
    local cuts = wCuts(d)
    if #cuts > 0 then return false, table.concat(cuts, "; ") end
    local ok, why = layoutOK(d)
    if not ok then return false, why end
    local most, which = mostLines(d)
    return most <= 2, which .. " on " .. most .. " lines" end
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
assert(loadfile(__SM__))("XayaUI_Bonus", ns)
assert(loadfile(__CM__))("XayaUI_Bonus", ns)
assert(loadfile(__CT__))("XayaUI_Bonus", ns)
ns.FireReady(); ns.SettingsOpenAllForTests()   -- (P5) the module addons load after XayaUI: their settings stores open (Modules.lua section 0c)
CM = ns.StatModel
c = CWC()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
local statRow = mk("Frame"); statRow.Label = mk("FS"); statRow.Label.text = "Agility:"
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = { statRow }
c.enabled = true; CWA(); CharacterFrame.shown = true; PaperDollFrame:Show()
CM.gcd = { dur = 1.16, haste = 29.25 }
LAY = ns.STATCALC_LAYOUT
function drawn() return ns.StatCalc_Drawn() end
function render(tab) c.tab = tab or "stats"; ns.StatCalc_Render(); return drawn() end
'''

def world(extra):
    return (COMMON + extra).replace("__WORLD__", P("tests/char_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")) \
        .replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__SM__", P("XayaUI_Bonus/StatMath.lua")) \
        .replace("__CM__", P("XayaUI_Bonus/StatModel.lua")).replace("__CT__", P("XayaUI_Bonus/StatCalculator.lua"))

totals = []
def run(extra, body):
    lua = LuaRuntime()
    lua.execute(world(extra))
    lua.execute(body)
    totals.append((lua.eval("n"), lua.eval("fails")))

# ---------------------------------------------------------------------------------------------------------------------------------
# A. Stat Weights (#60 a-d) and the Stats grid's heads (#60 b, #66): titles never cut, on one line at the default width, centered over
#    their columns; numbers from the column's left edge; T/L in two lines
# ---------------------------------------------------------------------------------------------------------------------------------
run(STATWORLD, r'''
local function weights(dd)
  local heads, rows = recs(dd, "wcolhead"), {}
  return heads
end
-- (A24 #7, Xaya 2026-11-11: "2 but make sure all headings (top row) are vertically middle-aligned or bottom-aligned ..."; option 2:
-- "Influences is always its own column, and titles wrap onto two lines when needed") her new answer replaces #60's one-line titles for
-- the Stat Weights pane only: a title may wrap, never be cut. #60's one-line check stays for every other table (the Stats grid's heads
-- and the Ability Scaling heads below). Section L checks the six columns and the alignment.
-- The default panel at the default text in all three stand-in fonts: six titles, none cut (a title may wrap). (A24 #9) "flat8" (8 px
-- per character at any size, a much wider font) was a known limit here until the panel widened to the six columns' need.
for _, m in ipairs({ "est", "scaled", "flat8" }) do
  MEASURE = m
  c.size, c.fontSize = nil, 11
  local d = render()
  local hs = recs(d, "wcolhead")
  checkp(("Stat Weights, default panel, text 11, font %s: six column titles, none cut (\"Rating\", \"DR Threshold\" whole; a title may wrap, A24 #7)"):format(m), function()
    if #hs ~= 6 then return false, #hs .. " titles" end
    for _, r in ipairs(hs) do
      if cutWord(r) then return false, "cut: " .. r.text .. " (" .. cutWord(r) .. ") w=" .. r.w end
    end
    return true end)
end
MEASURE = "scaled"
-- Every panel width at text 8, 11, 12, 14 and 16 (12 and 14 added in A24 #7 round 2): no title or cell word cut (A24 #9: the panel
-- widens where the widest words need it); in every case six columns inside the width, no overlaps.
for _, pw in ipairs({ 340, 380, 450, 584, 760 }) do
  for _, fs in ipairs({ 8, 11, 12, 14, 16 }) do
    MEASURE = (pw <= 380 and fs == 16) and "est" or "scaled"
    c.size, c.fontSize = { w = pw }, fs
    local d = render()
    checkp(((fs == 8 and "(guard: the old widths held at text 8) " or "") .. "Stat Weights, panel %d, text %d (" .. MEASURE .. "): "
      .. "no title cut, no cell word cut, inside the width, no overlaps"):format(pw, fs), function()
      if #recs(d, "wcolhead") ~= 6 then return false, #recs(d, "wcolhead") .. " titles" end
      local cuts = wCuts(d)
      if #cuts > 0 then return false, table.concat(cuts, "; ") end
      local ok, why = layoutOK(d)
      return ok, why end)
  end
end
c.size, c.fontSize = nil, 11
local d = render()
checkp("Stat Weights: every title is centered over its column (justify CENTER), at its column's x and width", function()
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
-- B. A typed number (#60 e, #62 "New value with sign"): the current value, and under it the new value with its sign (QoL 0.7.28 to
-- 0.7.53: in the accent; QoL 0.7.54 / Bonus 0.6.38: green when better, red when worse, section K)
-- -----------------------------------------------------------------------------------------------------------------------------
ns.StatCalc_SetInput("sv:crit", "700")
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
checkp("  ...the line under it is drawn in the game's green (more crit is better), not the theme's accent", function()
  local f = font(d, "+26.22%"); return f and sameCol(f.color, GREEN) and not sameCol(f.color, ACCENT), f and f.color and table.concat(f.color, ",") end)
checkp("  ...no \"now -> then\" anywhere on the Stats tab", function()
  for _, r in ipairs(d.layout) do if tostring(r.text or ""):find(" -> ", 1, true) then return false, r.kind .. " '" .. tostring(r.text) .. "'" end end
  return true end)
checkp("  ...the card's hover: the title line, then the new value on the line under it (\" | +26.22%\")", function()
  local h = hoverOf(d, "map_crit")
  return h:find("Critical Strike | 22.48%  (46.0 / 1%) /  | +26.22%", 1, true) ~= nil, h end)
ns.StatCalc_SetInput("sv:crit", "400")
d = render()
checkp("typed 400 crit (lower than 528): 22.48% with a minus and the new value under it (-19.70%)", function()
  local v; for _, r in ipairs(recs(d, "value")) do if r.text == "22.48%" then v = r end end
  local ch = v and changeUnder(d, v)
  return ch ~= nil and tostring(ch.text):find("^%-%d+%.%d%d%%$") ~= nil, T(ch) end)
checkp("  ...drawn in the game's red (less crit is worse)", function()
  local v; for _, r in ipairs(recs(d, "value")) do if r.text == "22.48%" then v = r end end
  local ch = v and changeUnder(d, v)
  local f = ch and fontAt(d, ch)
  return f and sameCol(f.color, RED), f and f.color and table.concat(f.color, ",") end)
ns.StatCalc_SetInput("sv:crit", "")

-- -----------------------------------------------------------------------------------------------------------------------------
-- C. The ability lists leave the Stats tab (#60 f, her answer "Both lists"); the Influences column (#66, #67)
-- -----------------------------------------------------------------------------------------------------------------------------
ns.StatCalc_SetInput("sv:primary", "2737")
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
  local h = hoverOf(d, "map_haste:» Abilities")
  return h:find("    Infernal Strike | 9.6 s recharge", 1, true) ~= nil and find(d, "pairLabel", "Infernal Strike") == nil, h end)
ns.StatCalc_SetInput("sv:primary", "")

-- -----------------------------------------------------------------------------------------------------------------------------
-- D. Bucket bars and one indentation step by depth (#63)
-- -----------------------------------------------------------------------------------------------------------------------------
ns.StatCalc_SetInput("sv:haste", "1500")
for _, pw in ipairs({ 340, 450, 760 }) do
  c.size = { w = pw }
  d = render()
  local W = LAY.content
  checkp(("panel %d: Primary, General, Offensive, Defensive are bucket bars: a band across the pane's width in the accent color, the name on it"):format(pw), function()
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
ns.StatCalc_SetInput("sv:haste", "")
d = render()
checkp("the bucket bar's band is painted in the theme's accent color (a shown texture of the panel, the bar's size)", function()
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
  local pg = CWPage(function() end)
  local sel = pg.args.panelPart.args.layout.args.gearSumStyle
  local names = {}
  for _, k in ipairs(sel.sorting) do names[#names + 1] = sel.values[k] end
  return sel.name == "Gear Summary style" and table.concat(names, "|") == "Split bars|Stat tiles|One stacked bar|Columns|Gear share|Table" and sel.get() == "bars",
    table.concat(names, "|") end)
checkp("Split bars: Critical Strike's bar in its stat color, as long as its rating (528) next to the longest; solid part = gear (400 / 528), lighter = elsewhere; \"528 (gear 400 +128)\" at its end", function()
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
  for _, b in ipairs(XayaUIStatCalculator.tabs) do t[#t + 1] = b.label end
  return table.concat(t, " | ") == "Stats | Gear | Ability Scaling" and c.tab == "spells" and XayaUIStatCalculator.tabs[3].key == "spells", table.concat(t, " | ") end)
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
ns.StatCalc_SetInput("sv:primary", "2737")
d = render("spells")
fr = rowOf(d, "Fracture")
checkp("typed Agility 2,737 (+100): Fracture's Computed Value 6,944, and under it +7,144 (x attack power then / now: 3,572 / 3,472)", function()
  local v = find(d, "spellvalue", "6,944")
  local ch = find(d, "spellchange", "+7,144")
  return v and ch and ch.x == v.x and ch.y > v.y, tx(fr.spellchange) end)
checkp("  ...in the game's green (a larger number is better), not the theme's accent", function() local f = font(d, "+7,144"); return f and sameCol(f.color, GREEN) and not sameCol(f.color, ACCENT), f and f.color and table.concat(f.color, ",") end)
ns.StatCalc_SetInput("sv:primary", "")
ns.StatCalc_SetInput("sv:vers", "220")   -- 120 -> 220 versatility rating
d = render("spells")
local vI = CM.Build(c, "stats").byKey.map_vers
local v0, v1 = 2.61, nil
checkp("typed Versatility: Fracture's Computed Value moves by (1 + versatility then) / (1 + now), shown under it with its sign", function()
  local it = CM.Build(c, "spells").byKey.spell9101
  local e = it and it.row.entries[1]
  local src
  for _, r in ipairs(recs(d, "spellchange")) do src = src or r end
  return e and e.newValue and e.newValue:find("^%+7,") ~= nil and src ~= nil, e and e.newValue end)
ns.StatCalc_SetInput("sv:vers", "")
ns.StatCalc_SetInput("sv:haste", "1500"); ns.StatCalc_SetInput("sv:crit", "900")
d = render("spells")
checkp("(guard) typed Haste and Critical Strike only: no Computed Value moves (they change how often or how hard, not the number)", function()
  return #recs(d, "spellchange") == 0, #recs(d, "spellchange") end)
ns.StatCalc_SetInput("sv:haste", ""); ns.StatCalc_SetInput("sv:crit", "")
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
assert(loadfile(__SM__))("XayaUI_Bonus", ns)
assert(loadfile(__CM__))("XayaUI_Bonus", ns)
assert(loadfile(__CT__))("XayaUI_Bonus", ns)
ns.FireReady(); ns.SettingsOpenAllForTests()   -- (P5) the module addons load after XayaUI: their settings stores open (Modules.lua section 0c)
CM = ns.StatModel
c = CWC()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
c.enabled = true; CWA(); CharacterFrame.shown = true; PaperDollFrame:Show()
function drawn() return ns.StatCalc_Drawn() end
function render(tab) c.tab = tab; ns.StatCalc_Render(); return drawn() end
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
    if not sameCol(e.color, ACCENT) then return false, "color " .. table.concat(e.color or {}, ",") end
    if sameCol(e.color, border.color) then return false, "same color as the quality border" end
    if not (e.layer == "OVERLAY" and border.layer == "BACKGROUND" and b.tex.layer == "ARTWORK") then return false, "layer " .. tostring(e.layer) end
    if not (thick > 1) then return false, "thickness " .. thick end
  end
  return true
end
checkp("(guard: shown / hidden worked before; it was not visible) the equipped ring picked for Compare: its box has the highlight frame, the helm's not", function()
  local ok, why = marked(icon(d, 11)); return ok and not icon(d, 1).selEdges[1].shown, why end)
checkp("  ...the frame is in the theme's accent color (not the selected tab's dark background), not the quality border's color, on the top draw layer (OVERLAY over the ARTWORK icon and the BACKGROUND quality border), thicker than the 1 px quality border", function()
  return edgeOK(icon(d, 11)) end)
local nr = candIcon(d, NEWRING)
nr.scripts.OnClick(nr)
d = drawn()
local br = candIcon(d, BIGRING)
br.scripts.OnClick(br)
d = drawn()
checkp("two bag items picked: both have the frame, in the accent color, over the icon, thicker than the border", function()
  local ok1, w1 = marked(candIcon(d, NEWRING)); local ok2, w2 = marked(candIcon(d, BIGRING))
  local e1, x1 = edgeOK(candIcon(d, NEWRING)); local e2, x2 = edgeOK(candIcon(d, BIGRING))
  return ok1 and ok2 and e1 and e2, w1 or w2 or x1 or x2 end)
checkp("(guard) an item not picked has no frame", function()
  local b = candIcon(d, NEWRING); b.scripts.OnClick(b); d = drawn()
  return not candIcon(d, NEWRING).selEdges[1].shown and candIcon(d, BIGRING).selEdges[1].shown end)
''', "")

# ---------------------------------------------------------------------------------------------------------------------------------
# K. QoL 0.7.54 / Bonus 0.6.38 (Xaya 2026-11-08, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #5 / #6 / #15, her words: "xayaui theme is
#    fine for everything except change numbers and stat colors"; "1 or adjust for color blind mode" (1 = "Green up, red down"); "XayaUI
#    theme only"; stat names "Yes, everywhere (Recommended)"; tooltips "Hide notes unless Dev Assist"). Better / worse by meaning (lower
#    is better for seconds and damage taken), the color-blind pair read from XayaUI/Theme.lua's colorblind palette (by this test, at run
#    time), the text color when the same; stat names in their color in the hovers and the Ability Scaling rows. Fail on 930a0c7
#    (QoL 0.7.53 / Bonus 0.6.37), except those marked "(guard)".
# ---------------------------------------------------------------------------------------------------------------------------------
import re as _re
_TH = open(os.path.join(ROOT, "XayaUI", "Theme.lua"), encoding="utf-8").read()
_CBP = _re.search(r'colorblind = \{ name = .*?pal = \{.*?\} \} \},', _TH, _re.S).group(0)   # (the "colorblind" entry of T.BUILTIN)
CB_ACC = "{ " + _re.search(r'accent = \{ ([\d., ]+) \}', _CBP).group(1) + " }"
CB_DAN = "{ " + _re.search(r'danger = \{ ([\d., ]+) \}', _CBP).group(1) + " }"
run(STATWORLD, (r'''
-- the hover with each line's colors
local function hoverCols(b)
  local out = {}
  GameTooltip.AddDoubleLine = function(self, a, bb, lr, lg, lb, rr, rg, rb) out[#out + 1] = { l = a, r = bb, lc = { lr, lg, lb }, rc = { rr, rg, rb } } end
  GameTooltip.AddLine = function(self, a, r, g, bl) out[#out + 1] = { l = a, lc = { r, g, bl } } end
  b.scripts.OnEnter(b)
  return out
end
local function btn(dd, pred) for _, b in ipairs(dd.buttons) do if b.shown and b.item and pred(b.item) then return b end end end
local function changeUnder(dd, valueRec)
  for _, r in ipairs(recs(dd, valueRec.kind == "value" and "change" or "pairChange")) do
    if math.abs(r.x - valueRec.x) < 0.01 and r.y > valueRec.y and r.y < valueRec.y + 3 * valueRec.size then return r end
  end
end
-- the value record on a card's own line (the card's hover button starts at that line)
local function cardValue(dd, key)
  local hit
  for _, r in ipairs(recs(dd, "hit")) do if r.text == key then hit = r end end
  if not hit then return nil end
  for _, r in ipairs(recs(dd, "value")) do if math.abs(r.y - hit.y) < 0.01 then return r end end
end
-- 1. lower is better: typed Haste 1,500 (from 1,200): the GCD card's new value is shorter, drawn green
ns.StatCalc_SetInput("sv:haste", "1500")
local d = render()
local gv = cardValue(d, "map_gcd")
local gch = gv and changeUnder(d, gv)
checkp("typed more Haste: the GCD card's new value (shorter, \"-1.xx s\") is drawn in the game's green: lower is better for seconds", function()
  local f = gch and fontAt(d, gch)
  return gch and tostring(gch.text):find("^%-%d%.%d%d s$") ~= nil and f and sameCol(f.color, GREEN), T(gv) .. " / " .. T(gch) .. " " .. (f and table.concat(f.color, ",") or "") end)
local av = cardValue(d, "map_aspeed")
local ach = av and changeUnder(d, av)
checkp("  ...the Attack Speed card's new value (a shorter swing) is green too", function()
  local f = ach and fontAt(d, ach); return f and sameCol(f.color, GREEN), T(av) .. " / " .. T(ach) end)
local hb = btn(d, function(it) return it.kind == "infl" and it.label == "» GCD" end)
local hl = hb and hoverCols(hb) or {}
checkp("  ...Haste's Modifies name \"GCD\": its hover's new-value line is green", function()
  local line = hl[2]
  return line ~= nil and tostring(line.r):find("^%-") ~= nil and sameCol(line.rc, GREEN), line and (tostring(line.r) .. " " .. table.concat(line.rc, ",")) end)
-- less Haste: the GCD gets longer: red
ns.StatCalc_SetInput("sv:haste", "900")
d = render()
gv = cardValue(d, "map_gcd"); gch = gv and changeUnder(d, gv)
checkp("typed less Haste: the GCD card's new value (longer, \"+1.xx s\") is drawn in the game's red", function()
  local f = gch and fontAt(d, gch)
  return gch and tostring(gch.text):find("^%+") ~= nil and f and sameCol(f.color, RED), T(gch) .. " " .. (f and table.concat(f.color, ",") or "") end)
-- the same: a change too small to show at two decimals (3 rating): the text color
ns.StatCalc_SetInput("sv:haste", "1203")
d = render()
gv = cardValue(d, "map_gcd"); gch = gv and changeUnder(d, gv)
checkp("typed Haste 1,203 (+3 rating): the GCD's new value reads the same as now: drawn in the theme's text color, not green or red", function()
  local f = gch and fontAt(d, gch)
  local same = gch and gv and tostring(gch.text):gsub("^[%+%-]", "") == tostring(gv.text)
  return same and f and sameCol(f.color, TEXT), T(gv) .. " / " .. T(gch) .. " " .. (f and table.concat(f.color, ",") or "") end)
ns.StatCalc_SetInput("sv:haste", "")
-- 2. damage taken: more Versatility = less damage taken = better (green)
ns.StatCalc_SetInput("sv:vers", "400")
local m = CM.Build(c, "stats").byKey.map_vers
local dt
for _, p in ipairs(m and m.pairs or {}) do if p.label == "» Damage taken" then dt = p end end
checkp("typed more Versatility: \"» Damage taken\" goes down and its new value means better (lower is better for damage taken)", function()
  return dt and dt.newValue and dt.newTone == "better", dt and (tostring(dt.value) .. " / " .. tostring(dt.newValue) .. " " .. tostring(dt.newTone)) end)
d = render()
local vb = btn(d, function(it) return it.kind == "infl" and it.label == "» Damage taken" end)
local vl = vb and hoverCols(vb) or {}
checkp("  ...its hover's new-value line is the game's green", function() return vl[2] ~= nil and sameCol(vl[2].rc, GREEN), vl[2] and table.concat(vl[2].rc, ",") end)
ns.StatCalc_SetInput("sv:vers", "")
-- 3. Avoidance (fix plan f1-16): more Avoidance = less area damage taken: its line goes UP and that is better
ns.StatCalc_SetInput("sv:avoidance", "600")
m = CM.Build(c, "stats").byKey.map_avoidance
local ad
for _, p in ipairs(m and m.pairs or {}) do if p.label == "» Area damage taken" then ad = p end end
checkp("typed Avoidance 600: \"» Area damage taken\" goes up and its new value means better (f1-16: not matched by \"taken\")", function()
  return ad and ad.newValue and ad.newValue:find("^%+") ~= nil and ad.newTone == "better", ad and (tostring(ad.newValue) .. " " .. tostring(ad.newTone)) end)
d = render()
local ab = btn(d, function(it) return it.kind == "infl" and it.label == "» Area damage taken" end)
local al = ab and hoverCols(ab) or {}
checkp("  ...its hover's new-value line is the game's green", function() return al[2] ~= nil and sameCol(al[2].rc, GREEN), al[2] and table.concat(al[2].rc, ",") end)
ns.StatCalc_SetInput("sv:avoidance", "")
-- 4. a XayaUI color-blind base theme: blue better, orange worse (the colorblind palette's accent and danger), never green / red
CB_ACCENT, CB_DANGER = __CBACC__, __CBDAN__
ns.Theme.BUILTIN = { colorblind = { pal = { accent = CB_ACCENT, danger = CB_DANGER } } }
for _, base in ipairs({ "colorblind", "protan", "tritan" }) do
  ns.Theme.EffBase = function() return base end
  ns.StatCalc_SetInput("sv:crit", "700")
  d = render()
  local up = font(d, "+26.22%")
  up = up and { color = { up.color[1], up.color[2], up.color[3] } }   -- (copied now: the panel reuses its font strings on the next draw)
  ns.StatCalc_SetInput("sv:crit", "400")
  d = render()
  local down
  for _, f in ipairs(d.fonts) do if f.shown and tostring(f.text):find("^%-19%.") then down = f end end
  checkp(("base theme \"%s\": more crit drawn blue (the colorblind palette's accent), less crit orange (its danger color)"):format(base), function()
    return up and down and sameCol(up.color, CB_ACCENT) and sameCol(down.color, CB_DANGER),
      (up and table.concat(up.color, ",") or "none") .. " / " .. (down and table.concat(down.color, ",") or "none") end)
end
ns.Theme.EffBase = function() return "default" end
ns.StatCalc_SetInput("sv:crit", "700")
d = render()
checkp("base theme \"default\": the game's green", function() local f = font(d, "+26.22%"); return f and sameCol(f.color, GREEN) end)
-- a saved theme whose own base is the color-blind one counts too (as Theme.lua T.IsLight reads a saved theme's base)
CueRulesDB = CueRulesDB or {}
CueRulesDB.themes = { Mine = { base = "custom", under = "protan" } }
ns.Theme.EffBase = function() return "Mine" end
d = render()
checkp("a saved theme started from a color-blind theme: blue", function() local f = font(d, "+26.22%"); return f and sameCol(f.color, CB_ACCENT) end)
ns.Theme.EffBase = nil; CueRulesDB.themes = nil
ns.StatCalc_SetInput("sv:crit", "")
-- 5. stat names in their color in the hovers (title and lines); other labels keep the theme
d = render()
local cb = btn(d, function(it) return it.key == "map_crit" end)
local cl = cb and hoverCols(cb) or {}
checkp("the Critical Strike card's hover: its title \"Critical Strike\" in the stat's color (CM.STAT_COLORS.crit), not the theme's label color", function()
  return cl[1] ~= nil and cl[1].l == "Critical Strike" and sameCol(cl[1].lc, CM.STAT_COLORS.crit), cl[1] and (tostring(cl[1].l) .. " " .. table.concat(cl[1].lc, ",")) end)
checkp("(guard)  ...a label that is not a stat (\"From rating\") keeps the theme's muted color", function()
  for _, l in ipairs(cl) do if l.l == "From rating" then return sameCol(l.lc, { 0.6, 0.6, 0.65 }), table.concat(l.lc, ",") end end
  return false, "no From rating line" end)
local found
for _, b in ipairs(d.buttons) do
  if b.shown and b.item and type(b.item.pairs) == "table" then
    for _, p in ipairs(b.item.pairs) do if p.label == "From Critical Strike" or p.label == "From Agility" then found = found or { b = b, label = p.label } end end
  end
end
checkp("a hover line \"From Critical Strike\" / \"From Agility\" has its stat's color on the left (the panel's hover did not read it before)", function()
  if not found then return false, "no such line" end
  local key = found.label == "From Agility" and "primary" or "crit"
  for _, l in ipairs(hoverCols(found.b)) do if l.l == found.label then return sameCol(l.lc, CM.STAT_COLORS[key]), found.label .. " " .. table.concat(l.lc, ",") end end
  return false, "line not in the hover" end)
-- the Ability Scaling tab: Fracture's "Versatility: +2.61%": the name in Versatility's color, the number after it as before; its hover too
c.advanced = true   -- (as section F: Spell Math on)
d = render("spells")
checkp("Ability Scaling: \"Versatility: +2.61%\" is drawn with \"Versatility\" in its stat color (a color code around the name), the text recorded as before", function()
  local r = find(d, "spellstat", "Versatility: +2.61%")
  local col = CM.STAT_COLORS.vers
  local code = ("|cff%02x%02x%02x"):format(math.floor(col[1] * 255 + 0.5), math.floor(col[2] * 255 + 0.5), math.floor(col[3] * 255 + 0.5))
  local f
  for _, ff in ipairs(d.fonts) do if ff.shown and ff.text == code .. "Versatility|r: +2.61%" then f = ff end end
  local t = {}; for _, ff in ipairs(d.fonts) do if ff.shown and tostring(ff.text):find("Versatility", 1, true) then t[#t + 1] = ff.text end end
  return r ~= nil and f ~= nil, (r and T(r) or "no record") .. "; drawn: " .. table.concat(t, " ; ") end)
local sb = btn(d, function(it) return it.key == "spell9101" end)
local sl = sb and hoverCols(sb) or {}
checkp("  ...Fracture's hover: the \"Versatility\" line's label in Versatility's color", function()
  for _, l in ipairs(sl) do if l.l == "Versatility" then return sameCol(l.lc, CM.STAT_COLORS.vers), table.concat(l.lc, ",") end end
  return false, "no Versatility line" end)
-- 6. the notes (her answer "Hide notes unless Dev Assist"): the crit card's hover without and with XayaUI Dev Assist
d = render()
cb = btn(d, function(it) return it.key == "map_crit" end)
local function hasLine(lines, s) for _, l in ipairs(lines) do if tostring(l.l):find(s, 1, true) or tostring(l.r or ""):find(s, 1, true) then return true end end end
local off = hoverCols(cb)
ns.DevAssistOn = function() return true end
local on = hoverCols(cb)
ns.DevAssistOn = nil
local note
for _, l in ipairs(on) do if l.r == nil and tostring(l.l):len() > 40 then note = note or l.l end end
checkp("the crit card's hover without XayaUI Dev Assist: the title and its numbers, no note paragraph; with it, the notes too", function()
  return note ~= nil and not hasLine(off, note) and hasLine(off, "Critical Strike") and #on > #off, tostring(note) end)
''').replace("__CBACC__", CB_ACC).replace("__CBDAN__", CB_DAN))

# ---------------------------------------------------------------------------------------------------------------------------------
# L. A24 #7 (Xaya 2026-11-11, her words: "2 but make sure all headings (top row) are vertically middle-aligned or bottom-aligned and
#    all rows beneath are uniformly vertically aligned amongst themselves"; option 2: "Influences is always its own column, and titles
#    wrap onto two lines when needed"). In the Stat Weights pane, at every panel width and text size: six column titles, the last
#    Influences, and each row's influences on the row itself in that column (never a labeled line under the row); the titles share
#    one bottom edge (bottom-aligned chosen; her words allow middle or bottom), and the shown font strings sit where the records say;
#    every cell of every row starts at its row's top, the same gap after every row; whole pixels (V27).
#    Negative control (V1): fails on af1f2ba (the influences went under their row where six one-line titles did not fit, and the
#    titles were top-aligned).
# ---------------------------------------------------------------------------------------------------------------------------------
run(STATWORLD, r'''
local CELLS = { "wlabel", "wrating", "wppp", "wdr", "wtl", "winfl" }
local function whole(v) return v == math.floor(v) end
local function rows(d)
  local out = {}
  for _, r in ipairs(recs(d, "wlabel")) do out[#out + 1] = { label = r, top = r.y } end
  return out
end
local wrapped, shiftedTitle = false, false
for _, m in ipairs({ "est", "scaled" }) do
  MEASURE = m
  for _, pw in ipairs({ 340, 380, 450, 584, 760 }) do
    for _, fs in ipairs({ 8, 10, 11, 12, 14, 16 }) do
      c.size, c.fontSize = { w = pw }, fs
      local d = render()
      local heads = recs(d, "wcolhead")
      local tag = ("panel %d, text %d (%s)"):format(pw, fs, m)
      checkp("A24 #7 Stat Weights, " .. tag .. ": six column titles, the last Influences; each row's influences on the row itself in that column, no \"Influences: \" label", function()
        if #heads ~= 6 or heads[6].text ~= "Influences" then return false, texts(d, "wcolhead") end
        local labels, infl = recs(d, "wlabel"), recs(d, "winfl")
        if #labels == 0 or #infl ~= #labels then return false, #infl .. " influence cells for " .. #labels .. " rows" end
        for i, r in ipairs(infl) do
          if r.x ~= heads[6].x or r.w ~= heads[6].w or r.y ~= labels[i].y then
            return false, labels[i].text .. ": x " .. r.x .. " w " .. r.w .. " y " .. r.y .. " (title x " .. heads[6].x .. " w " .. heads[6].w .. ", row y " .. labels[i].y .. ")"
          end
          if tostring(r.text):find("^Influences: ") then return false, "labeled: " .. r.text end
          if not fontAt(d, r) then return false, "no shown font string at " .. labels[i].text .. "'s influences" end
        end
        return true end)
      checkp("A24 #7 Stat Weights, " .. tag .. ": the column titles are bottom-aligned (one bottom edge), each drawn where its record says", function()
        local bottom
        for _, h in ipairs(heads) do
          bottom = bottom or (h.y + h.h)
          if h.y + h.h ~= bottom then return false, h.text .. " ends at " .. (h.y + h.h) .. ", not " .. bottom end
          if not fontAt(d, h) then return false, "no shown font string for " .. h.text .. " at y " .. h.y end
          if h.h > h.size then wrapped = true end
          if h.y > heads[1].y or h.y < heads[1].y then shiftedTitle = true end
        end
        return #heads == 6 end)
      checkp("A24 #7 Stat Weights, " .. tag .. ": every cell of every row starts at its row's top; the same gap after every row", function()
        local rs, gap = rows(d), nil
        for i, row in ipairs(rs) do
          local nextTop = rs[i + 1] and rs[i + 1].top or math.huge
          local bottom = row.top
          for _, k in ipairs(CELLS) do
            local first
            for _, r in ipairs(recs(d, k)) do
              if r.y >= row.top and r.y < nextTop and (not first or r.y < first.y) then first = r end
              if r.y >= row.top and r.y < nextTop then bottom = math.max(bottom, r.y + r.h) end
            end
            if first and first.y ~= row.top then return false, row.label.text .. ": " .. k .. " '" .. tostring(first.text) .. "' at y " .. first.y .. ", row top " .. row.top end
          end
          for _, r in ipairs(recs(d, "wpppdr")) do if r.y >= row.top and r.y < nextTop then bottom = math.max(bottom, r.y + r.h) end end
          if rs[i + 1] then
            local g = nextTop - bottom
            gap = gap or g
            if g ~= gap then return false, row.label.text .. ": gap " .. g .. " after it, " .. gap .. " after the first row" end
          end
        end
        return #rs > 1, #rs .. " rows" end)
      checkp("A24 #7 Stat Weights, " .. tag .. ": whole pixels (V27): every title and cell at a whole x, y, width and height", function()
        for _, k in ipairs({ "wcolhead", "wlabel", "wrating", "wppp", "wpppdr", "wdr", "wtl", "winfl" }) do
          for _, r in ipairs(recs(d, k)) do
            if not (whole(r.x) and whole(r.y) and whole(r.w) and whole(r.h)) then return false, k .. " '" .. tostring(r.text) .. "' " .. r.x .. "," .. r.y .. " " .. r.w .. "x" .. r.h end
          end
        end
        return true end)
    end
  end
end
-- (A24 #7 round 2; A24 #9) every width x text size x the three stand-in fonts: no word cut (the panel widens to the six columns'
-- need), inside the width, no overlaps
for _, m in ipairs({ "est", "scaled", "flat8" }) do
  MEASURE = m
  for _, pw in ipairs({ 340, 380, 450, 584, 760 }) do
    for _, fs in ipairs({ 8, 10, 11, 12, 14, 16 }) do
      c.size, c.fontSize = { w = pw }, fs
      local d = render()
      local name, fn = limitCheck(d, m .. ":" .. pw .. ":" .. fs)
      checkp(("A24 #7 Stat Weights, panel %d, text %d (%s): "):format(pw, fs, m) .. name, fn)
    end
  end
end
checkp("A24 #10 THREE_LINES is empty: no case is allowed a third title line", function()
  local k = next(THREE_LINES)
  return k == nil, tostring(k) end)
checkp("A24 #7 (guard: the alignment checks above met a wrapped title moved down under the others, so bottom-alignment was exercised)", function()
  return wrapped and shiftedTitle end)
-- the default panel at text 14 in the wider stand-in font (drawn widened to the need): "DR Threshold" wraps onto two lines and is not
-- cut; the one-line titles sit one line lower, on its bottom line
MEASURE = "scaled"
c.size, c.fontSize = nil, 14
local d = render()
local dt, st = find(d, "wcolhead", "DR Threshold"), find(d, "wcolhead", "Stat")
checkp("A24 #7 default panel, text 14 (scaled): \"DR Threshold\" wraps onto two lines, uncut; \"Stat\" sits lower, on the same bottom line", function()
  return dt and st and dt.h == 2 * dt.size and titleLines(dt) == 2 and not cutWord(dt) and st.y == dt.y + dt.size and st.y + st.h == dt.y + dt.h,
    dt and st and ("DR Threshold y " .. dt.y .. " h " .. dt.h .. "; Stat y " .. st.y .. " h " .. st.h) or "missing" end)
checkp("A24 #10 the second Stat Weights title reads exactly \"Rating\"; its hover still explains points and percent", function()
  local hs = recs(d, "wcolhead")
  local tip
  for _, sec in ipairs(d.model.sections) do if sec.weights then for _, it in ipairs(sec.items) do if it.kind == "weighthead" then tip = table.concat(it.tip or {}, " / ") end end end end
  return hs[2] and hs[2].text == "Rating" and tip and tip:find("Rating: your rating (points) and the stat's percent now.", 1, true) ~= nil,
    tostring(hs[2] and hs[2].text) .. " | " .. tostring(tip) end)
-- (A24 #10, option 1: "every title fits on at most two lines") the width is worked out from whatever titles the pane draws, not from
-- the six of today: with a four-word second title (the old "Rating (P / %)", put in the model here) every case of the grid still keeps
-- every title on at most two lines with nothing cut. On the pre-change tree this fails where the old title took three lines.
local baseBuild = CM.Build
CM.Build = function(...)
  local m = baseBuild(...)
  for _, sec in ipairs(m and m.sections or {}) do
    if sec.weights then for _, it in ipairs(sec.items) do
      if it.kind == "weighthead" and type(it.cols) == "table" then
        local cols = {}
        for i, v in ipairs(it.cols) do cols[i] = v end
        cols[2] = "Rating (P / %)"
        it.cols = cols
      end
    end end
  end
  return m
end
local four
for _, m in ipairs({ "est", "scaled", "flat8" }) do
  MEASURE = m
  for _, pw in ipairs({ 340, 380, 450, 584, 760 }) do
    for _, fs in ipairs({ 8, 10, 11, 12, 14, 16 }) do
      c.size, c.fontSize = { w = pw }, fs
      local dd = render()
      local most, which = mostLines(dd)
      if find(dd, "wcolhead", "Rating (P / %)") == nil then four = four or (m .. ":" .. pw .. ":" .. fs .. " title not drawn") end
      if most > 2 or #wCuts(dd) > 0 or not layoutOK(dd) then four = four or (m .. ":" .. pw .. ":" .. fs .. ": " .. which .. " on " .. most .. " lines, cuts " .. #wCuts(dd)) end
    end
  end
end
CM.Build = baseBuild
checkp("A24 #10 a four-word title (\"Rating (P / %)\" in the model): every width x text size x font, every title on at most two lines, nothing cut, no overlaps", function()
  return four == nil, four end)
MEASURE = "est"
c.size, c.fontSize = nil, 11
''')

# ---------------------------------------------------------------------------------------------------------------------------------
# M. A24 #9 (Xaya 2026-11-11, her words: "Widen the panel"; the question was what gives where the six columns' widest words do not fit).
#    With the Stat Weights pane drawn, the panel is exactly as wide as the six columns' widest words and the five gutters need (the
#    narrowest width with nothing cut) wherever the saved width is narrower, docked and on its own; a wider saved width is kept; the
#    saved width (c.size) is not changed; never wider than the screen; whole pixels; worked out once per change of text size or
#    content (a redraw with nothing new measures nothing for it). Negative control (V1): with sections A and L, 72 of 485 fail on
#    64d0943 (the base of this change); the checks marked "(guard)" pass there. Round 2 (the corner grip, the tab row): those two
#    checks also fail on the round-1 tree (2 of 485 there).
# ---------------------------------------------------------------------------------------------------------------------------------
run(STATWORLD, r'''
local GUT, PAD = ns.UI_GUTTER, LAY.pad
local COL = { wlabel = 1, wrating = 2, wppp = 3, wpppdr = 3, wdr = 4, wtl = 5, winfl = 6 }
-- the width the drawn pane needs, measured here from what was drawn: each column's widest word (as the game measures a text: the
-- panel's TextW is the measured width rounded up, plus 1) or (A24 #10) its title's two-line width, whichever is wider (the best
-- space to break the title at: the wider of its two halves, the narrowest such), five gutters and the panel's two margins
local function tw(t, size) return math.ceil(textW(t, size)) + 1 end
local function twoLine(r)
  local ws = {}
  for w in tostring(r.text or ""):gmatch("%S+") do ws[#ws + 1] = w end
  if #ws < 2 then return tw(r.text, r.size) end
  local best
  for k = 1, #ws - 1 do
    local wk = math.max(tw(table.concat(ws, " ", 1, k), r.size), tw(table.concat(ws, " ", k + 1), r.size))
    if not best or wk < best then best = wk end
  end
  return best
end
local function needFromDrawn(d)
  local col = { 0, 0, 0, 0, 0, 0 }
  local function word(i, r)
    for w in tostring(r.text or ""):gmatch("%S+") do col[i] = math.max(col[i], tw(w, r.size)) end
  end
  for i, r in ipairs(recs(d, "wcolhead")) do word(i, r); col[i] = math.max(col[i], twoLine(r)) end
  for k, i in pairs(COL) do for _, r in ipairs(recs(d, k)) do word(i, r) end end
  local n = 5 * GUT + 2 * PAD
  for i = 1, 6 do n = n + col[i] end
  return n
end
local function panelW() local p = rawget(_G, "XayaUIStatCalculator"); return p and p.w end
UIParent.w = 1920
for _, m in ipairs({ "est", "scaled", "flat8" }) do
  MEASURE = m
  for _, docked in ipairs({ true, false }) do
    CharacterFrame.shown = docked
    for _, fs in ipairs({ 8, 11, 14, 16 }) do
      c.size, c.fontSize = { w = 340 }, fs
      local d = render()
      local need, pw = needFromDrawn(d), panelW()
      checkp(("A24 #9 %s, saved width 340, text %d (%s): the panel is max(340, the six columns' need) wide, whole pixels, and nothing is cut"):format(docked and "docked" or "on its own", fs, m), function()
        if #wCuts(d) > 0 then return false, table.concat(wCuts(d), "; ") end
        local want = math.max(340, need)
        return pw == want and pw == math.floor(pw) and LAY.width == pw, "panel " .. tostring(pw) .. ", want " .. want .. " (need " .. need .. ")" end)
    end
  end
end
CharacterFrame.shown = true
MEASURE = "scaled"
c.size, c.fontSize = { w = 340 }, 16
local d = render()
checkp("A24 #9 the widened case is real: at saved width 340, text 16 (scaled), the need is wider than 340 and the panel took it", function()
  return needFromDrawn(d) > 340 and panelW() == needFromDrawn(d), tostring(panelW()) .. " / " .. needFromDrawn(d) end)
checkp("(guard) A24 #9 the saved width is not changed by widening (c.size.w stays 340)", function() return c.size and c.size.w == 340, c.size and c.size.w end)
c.size, c.fontSize = { w = 760 }, 11
d = render()
checkp("(guard) A24 #9 a saved width wider than the need is kept (760 at text 11)", function() return panelW() == 760 and needFromDrawn(d) < 760, tostring(panelW()) end)
-- the screen: never wider than it
UIParent.w = 400.6
MEASURE = "flat8"
c.size, c.fontSize = { w = 340 }, 16
d = render()
checkp("A24 #9 a screen narrower than the need (400.6 wide): the panel is the screen's whole-pixel width, 400, no wider", function()
  return needFromDrawn(d) > 400 and panelW() == 400, tostring(panelW()) .. " need " .. needFromDrawn(d) end)
UIParent.w = 1920
-- folded Stat Weights: nothing of it is drawn, so the panel keeps its saved width
local wkey
for _, sec in ipairs(d.model.sections) do if sec.weights then wkey = sec.key end end
c.collapsed[wkey] = true
d = render()
checkp("(guard) A24 #9 Stat Weights folded (nothing of it drawn): the saved width, 340", function() return panelW() == 340, tostring(panelW()) end)
c.collapsed[wkey] = nil
-- worked out once per change, never on a redraw with nothing new
MEASURE = "scaled"
c.size, c.fontSize = { w = 340 }, 14
render()
local n0 = ns.StatCalc_WidthNeedComputes and ns.StatCalc_WidthNeedComputes()
render(); render()
local n1 = ns.StatCalc_WidthNeedComputes and ns.StatCalc_WidthNeedComputes()
checkp("A24 #9 two redraws with the same text size and content: the width need is not worked out again", function() return n0 ~= nil and n1 == n0, tostring(n0) .. " -> " .. tostring(n1) end)
c.fontSize = 15
render()
local n2 = ns.StatCalc_WidthNeedComputes and ns.StatCalc_WidthNeedComputes()
checkp("A24 #9 the text size changes: worked out once", function() return n1 ~= nil and n2 == n1 + 1, tostring(n1) .. " -> " .. tostring(n2) end)
local oldCrit = ratings[9]
ratings[9] = 1234567   -- the character's Critical Strike rating changes (CR_CRIT 9 in this world): the pane's Rating cell changes
d = render()
local n3 = ns.StatCalc_WidthNeedComputes and ns.StatCalc_WidthNeedComputes()
checkp("A24 #9 the content changes (Critical Strike rating 528 -> 1,234,567): worked out once, and the panel fits the new need", function()
  return n2 ~= nil and n3 == n2 + 1 and panelW() == math.max(340, needFromDrawn(d)) and #wCuts(d) == 0, tostring(n2) .. " -> " .. tostring(n3) .. "; panel " .. tostring(panelW()) end)
ratings[9] = oldCrit
render()
-- the corner grip: a press and release without a drag on a widened panel leaves the saved width (340) as it was, and the next draw
-- is widened again to the need (the widening is never saved)
MEASURE, CharacterFrame.shown = "scaled", true
c.size, c.fontSize = { w = 340 }, 16
d = render()
local P = rawget(_G, "XayaUIStatCalculator")
local wideW = panelW()
P.grip.scripts.OnMouseDown(P.grip); P.grip.scripts.OnMouseUp(P.grip)
d = render()
checkp("A24 #9 the corner grip pressed and released without a drag on a widened panel (saved 340, drawn " .. tostring(wideW) .. "): the saved width stays 340 and the panel is still drawn at the need", function()
  return wideW == needFromDrawn(d) and wideW > 340 and c.size and c.size.w == 340 and panelW() == wideW, "saved " .. tostring(c.size and c.size.w) .. ", drawn " .. tostring(panelW()) end)
-- V27 whole pixels: the three tabs at the widened widths (any content width now): whole x and width, sharing the row, the last
-- ending at the content's right edge
local tabBad
for _, fs in ipairs({ 10, 11, 12, 14, 16 }) do
  for _, m in ipairs({ "est", "scaled", "flat8" }) do
    MEASURE = m; c.size, c.fontSize = { w = 340 }, fs
    render()
    local x = LAY.pad
    for i, b in ipairs(P.tabs) do
      local pt = b.pts[#b.pts]
      local bx = pt and pt[4]
      if not (bx == math.floor(bx) and b.w == math.floor(b.w) and bx >= x and bx <= x + 1) then tabBad = tabBad or (m .. " " .. fs .. " tab " .. i .. " x " .. tostring(bx) .. " w " .. tostring(b.w)) end
      x = bx + b.w + 2
    end
    if not tabBad and math.abs(x - (LAY.pad + LAY.content)) > 0 then tabBad = m .. " " .. fs .. ": tabs end at " .. x .. ", content ends at " .. (LAY.pad + LAY.content) end
  end
end
checkp("A24 #9 / V27 the tab row at every widened width (340 saved, text 10-16, three fonts): each tab at a whole x and whole width, side by side, the last ending at the content's right edge", function()
  return tabBad == nil, tabBad end)
c.size, c.fontSize = nil, 11
MEASURE = "est"
''')

n = sum(t[0] for t in totals); fails = sum(t[1] for t in totals)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
