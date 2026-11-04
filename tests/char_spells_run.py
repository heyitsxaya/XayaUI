# Stub test for QoL > Character Toolkit, Stat Calculator step 1 (XayaUI_QoL 0.7.7). Xaya 2026-11-04: "remove defense and offense tabs
# from stat calculator, they should be filters for 'Spells' that show stat conversion rate into the offensive/defensive spell scaling"
# and "spells pane still needs a full auto-populate". Checks: the tab row (no Defense / Offense tabs; a saved one opens Spells with
# that filter), the spell list (hand-added first, then every spellbook spell with numbers; the rest counted, or listed with the
# setting), spell power for an Intellect spec, the word-based filter (and a hand-set one), the stat sections under each filter,
# skipped durations / distances / counts, descriptions asked for once and the redraw when they arrive, the filter buttons
# (click, hover, hidden on other tabs, layout V11), and the settings page.
# Run from the repo root: python3 tests/char_spells_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua.
# The spell IDs and descriptions below are TEST STAND-INS written for this test (made-up IDs 9001-9008); no game data.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
assert(loadfile(__WORLD__))()
-- a stand-in spellbook: the list core's ns.BuildSpellList returns, and the descriptions the game would send
SPELLS = {
  { id = 9001, name = "Flame Ring", desc = "Engulf yourself in flames, instantly causing 12,345 Fire damage to enemies within 8 yards and 2,000 Fire damage over 6 sec." },
  { id = 9002, name = "Fel Breath", desc = "Unleash fel, damaging enemies in front of you for 30,000 Fire damage over 2 sec. Causing damage also heals you for up to 40,000 health." },
  { id = 9003, name = "Spike Guard", desc = "Surge with power, increasing your Armor by 20% for 6 sec." },
  { id = 9004, name = "Glide", desc = "Reduce your falling speed." },
  { id = 9005, name = "Ward", desc = "Absorbs 50,000 damage for 10 sec." },
  { id = 9006, name = "Slow Loader", desc = "" },     -- the game has not sent this description yet
  { id = 9007, name = "Shout", desc = "Inspire up to 5 allies within 40 yards for 1 min." },
}
DESC = {}
for _, s in ipairs(SPELLS) do DESC[s.id] = s.desc end
DESC[263642] = "Rapidly slash your target for 6,944 Physical damage, and shatter 2 Lesser Soul Fragments."
C_Spell.GetSpellName = function(id) if id == 263642 then return "Fracture" end; for _, s in ipairs(SPELLS) do if s.id == id then return s.name end end end
C_Spell.GetSpellDescription = function(id) return DESC[id] end
loadAsked = {}
C_Spell.RequestLoadSpellData = function(id) loadAsked[#loadAsked + 1] = id end
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
listCalls = 0
function ns.BuildSpellList()
  listCalls = listCalls + 1
  local t = {}
  for _, s in ipairs(SPELLS) do t[#t + 1] = { id = s.id, name = s.name } end
  t[#t + 1] = { id = 263642, name = "Fracture" }   -- also added by hand below: listed once, as the hand-added one
  return t
end
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
ns.FireReady()
local CM = ns.CharModel
local c = ns.CharToolkit_Cfg()
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
c.enabled = true
ns.CharToolkit_Apply()
CharacterFrame.shown = true; PaperDollFrame:Show()
local function drawn() return ns.CharToolkit_Drawn() end
local function render(tab) c.tab = tab; ns.CharToolkit_Render(); return drawn() end
local function recs(d, kind) local out = {}; for _, r in ipairs(d.layout) do if not kind or r.kind == kind then out[#out + 1] = r end end; return out end
local function texts(d, kind) local t = {}; for _, r in ipairs(recs(d, kind)) do t[#t + 1] = r.text end; return t end
local function keys(sec) local t = {}; for _, it in ipairs(sec and sec.items or {}) do t[#t + 1] = it.key end; return table.concat(t, ",") end
local function spellSec(m) for _, s in ipairs(m.sections) do if s.key == "spellmath" then return s end end end
local function secTitles(m) local t = {}; for _, s in ipairs(m.sections) do t[#t + 1] = s.title end; return table.concat(t, "|") end

-- 1. The tab row --------------------------------------------------------------------------------------------------------------
local tabKeys = {}
for _, t in ipairs(CM.TABS) do tabKeys[#tabKeys + 1] = t[1] end
check("tabs: Stats, Gear, What If, Spells (Defense and Offense are filters now; no Sheet since QoL 0.7.13)", table.concat(tabKeys, ",") == "stats,gear,whatif,spells", table.concat(tabKeys, ","))
c.tab = "defense"; c = ns.CharToolkit_Cfg()
check("a saved Defense tab opens Spells with the Defense filter", c.tab == "spells" and c.spellFilter == "defense", tostring(c.tab) .. " " .. tostring(c.spellFilter))
c.tab = "offense"; c = ns.CharToolkit_Cfg()
check("a saved Offense tab opens Spells with the Offense filter", c.tab == "spells" and c.spellFilter == "offense", tostring(c.tab) .. " " .. tostring(c.spellFilter))
c.spellFilter = "bogus"; c = ns.CharToolkit_Cfg()
check("an unknown filter becomes All", c.spellFilter == "all", c.spellFilter)
local okD = pcall(CM.Build, c, "defense")
check("the model still builds Defense / Offense for the tooltips and the sheet", okD and CM.Build(c, "defense").byKey.armor ~= nil and CM.Build(c, "offense").byKey.ap ~= nil)

-- 2. Numbers: durations, distances and counts are skipped --------------------------------------------------------------------
local nums = CM.Numbers(DESC[9001])
check("numbers: 12,345 and 2,000 kept; 8 yards and 6 sec skipped", table.concat(nums, ",") == "12345,2000", table.concat(nums, ","))
nums = CM.Numbers(DESC[9007])
check("numbers: 5 allies, 40 yards, 1 min all skipped", #nums == 0, table.concat(nums, ","))
nums = CM.Numbers("Deals 6,944 Physical damage. 15% more.")
check("numbers: percentages still skipped", table.concat(nums, ",") == "6944", table.concat(nums, ","))
LARGE_NUMBER_SEPERATOR = ""
local okN, numsE = pcall(CM.Numbers, "Deals 6,944 damage and 15% more.")
check("numbers: an empty thousands separator falls back to a comma (before QoL 0.7.7 it raised 'malformed pattern')",
  okN and table.concat(numsE, ",") == "6944", okN and table.concat(numsE, ",") or numsE)
LARGE_NUMBER_SEPERATOR = ","

-- 3. Offense / defense from the words ---------------------------------------------------------------------------------------
check("kind: damage only -> offense", CM.SpellKind(DESC[9001]) == "offense", CM.SpellKind(DESC[9001]))
check("kind: damage and heals -> both", CM.SpellKind(DESC[9002]) == "both", CM.SpellKind(DESC[9002]))
check("kind: armor -> defense", CM.SpellKind(DESC[9003]) == "defense", CM.SpellKind(DESC[9003]))
check("kind: absorbs N damage -> defense (that damage is not dealt)", CM.SpellKind(DESC[9005]) == "defense", CM.SpellKind(DESC[9005]))
check("kind: 'reduces damage taken' -> defense", CM.SpellKind("Reduces damage taken by 20% for 8 sec.") == "defense")
check("kind: 'health' is not 'heal' (an execute is offense)", CM.SpellKind("Attempt to finish off a foe below 20% health, dealing 9,000 damage.") == "offense")
check("kind: no words -> nil (All only)", CM.SpellKind(DESC[9004]) == nil)

-- 4. Spell Math off: the note, and the stat sections under the filters ------------------------------------------------------
c.advanced = false
c.spellFilter = "all"
local m = CM.Build(c, "spells")
check("Spell Math off: one note, no spells", keys(spellSec(m)) == "spellsOff", keys(spellSec(m)))
check("Spell Math off: All draws only the Spells section", secTitles(m) == "Spells", secTitles(m))
c.spellFilter = "defense"
m = CM.Build(c, "spells")
check("Defense filter: the defensive stat sections follow (Health and armor, Avoidance, Damage taken)",
  secTitles(m) == "Defensive spells|Health and armor|Avoidance|Damage taken", secTitles(m))
c.spellFilter = "offense"
m = CM.Build(c, "spells")
check("Offense filter: the offensive stat sections follow (Power, Weapons, Timing and resources)",
  secTitles(m) == "Offensive spells|Power|Weapons|Timing and resources", secTitles(m))

-- 5. Auto-populate -----------------------------------------------------------------------------------------------------------
c.advanced = true
c.spells = { { id = 263642, base = "ap" } }
c.spellFilter = "all"
loadAsked = {}
m = CM.Build(c, "spells")
local sec = spellSec(m)
check("All: the hand-added spell first, then every spellbook spell with numbers; Fracture once",
  keys(sec) == "spell263642,spell9001,spell9002,spell9005,spellsNoNumbers,spellsLoading", keys(sec))
check("  ...spells without numbers are counted, not listed (Spike Guard 20% only, Glide, Shout)", m.byKey.spellsNoNumbers.label == "3 without numbers", m.byKey.spellsNoNumbers.label)
check("  ...a description the game has not sent is asked for once", #loadAsked == 1 and loadAsked[1] == 9006, table.concat(loadAsked, ","))
CM.Build(c, "spells")
check("  ...and not asked for again on the next build", #loadAsked == 1, #loadAsked)
check("  ...the loading note says how many", m.byKey.spellsLoading.label == "1 still loading", m.byKey.spellsLoading.label)
local fr = m.byKey.spell9001
check("a listed spell: 12,345 / attack power 3,472 = 355.6% of attack power", fr and tostring(fr.pairs[1].value):find("355.6% of attack power", 1, true) ~= nil,
  fr and fr.pairs[1] and fr.pairs[1].value)
check("  ...its hover says it came from the spellbook and why attack power", tipHas(fr, "From your spellbook") and tipHas(fr, "primary stat is Agility"))
check("  ...and which filter its words put it in", tipHas(fr, "Filter: offense, from the words"))
c.spellsAll = true
m = CM.Build(c, "spells")
check("'List spells without numbers': Spike Guard, Glide and Shout listed too", m.byKey.spell9003 ~= nil and m.byKey.spell9004 ~= nil and m.byKey.spell9007 ~= nil
  and m.byKey.spellsNoNumbers == nil, keys(spellSec(m)))
c.spellsAll = false

-- 6. Filters -----------------------------------------------------------------------------------------------------------------
c.spellFilter = "offense"
m = CM.Build(c, "spells")
check("Offense: Fracture, Flame Ring, Fel Breath (both); not Ward", keys(spellSec(m)) == "spell263642,spell9001,spell9002,spellsLoading", keys(spellSec(m)))
c.spellFilter = "defense"
m = CM.Build(c, "spells")
check("Defense: Fel Breath (both), Ward; Spike Guard counted (no numbers); not Fracture", keys(spellSec(m)) == "spell9002,spell9005,spellsNoNumbers,spellsLoading", keys(spellSec(m)))
c.spells[1].kind = "defense"
m = CM.Build(c, "spells")
check("a hand-added spell set to Defense shows under Defense", m.byKey.spell263642 ~= nil and tipHas(m.byKey.spell263642, "set by hand"))
c.spells[1].kind = nil
c.spellFilter = "all"

-- 7. An Intellect spec: listed spells use spell power ------------------------------------------------------------------------
local savedSpec = C_SpecializationInfo.GetSpecializationInfo
C_SpecializationInfo.GetSpecializationInfo = function() return 63, "Fire", "", 0, "DAMAGER", 4 end
m = CM.Build(c, "spells")
check("Intellect spec: a listed spell is measured against spell power (12,345 / 500 = 2469.0%)", tostring(m.byKey.spell9001.pairs[1].value):find("2469.0% of spell power", 1, true) ~= nil,
  m.byKey.spell9001.pairs[1].value)
check("  ...the hand-added spell keeps its own setting (attack power)", tostring(m.byKey.spell263642.pairs[1].value):find("attack power", 1, true) ~= nil)
C_SpecializationInfo.GetSpecializationInfo = savedSpec

-- 8. No spell list (core without it) and nothing added ----------------------------------------------------------------------
local savedList = ns.BuildSpellList
ns.BuildSpellList = nil
c.spells = {}
m = CM.Build(c, "spells")
check("no spellbook list and nothing added: one note", keys(spellSec(m)) == "noSpells", keys(spellSec(m)))
ns.BuildSpellList = function() error("boom") end
local okE = pcall(CM.Build, c, "spells")
check("a failing spellbook list does not break the tab", okE)
ns.BuildSpellList = savedList
c.spells = { { id = 263642, base = "ap" } }

-- 9. The panel: filter buttons ----------------------------------------------------------------------------------------------
local d = render("spells")
local fl = {}
for _, b in ipairs(d.filters) do if b.shown then fl[#fl + 1] = b.text.text end end
check("Spells tab: three filter buttons All, Offense, Defense", table.concat(fl, ",") == "All,Offense,Defense", table.concat(fl, ","))
check("  ...drawn above the first header", recs(d, "filter")[1] and recs(d, "header")[1] and recs(d, "header")[1].y >= recs(d, "filter")[1].y + recs(d, "filter")[1].h,
  recs(d, "header")[1] and recs(d, "header")[1].y)
local def = d.filters[3]
GameTooltip.lines = {}
def.scripts.OnEnter(def)
local tipOK = false
for _, l in ipairs(GameTooltip.lines or {}) do if tostring(l):find("defensive stats", 1, true) then tipOK = true end end
check("  ...hovering one says what it shows", tipOK)
def.scripts.OnClick(def)
d = drawn()
check("  ...clicking Defense switches the filter and redraws (Defensive spells header)", c.spellFilter == "defense" and texts(d, "header")[1] == "- Defensive spells",
  tostring(c.spellFilter) .. " " .. tostring(texts(d, "header")[1]))
d = render("stats")
local anyShown = false
for _, b in ipairs(d.filters) do if b.shown then anyShown = true end end
check("  ...the filter buttons are hidden on other tabs", not anyShown and #recs(d, "filter") == 0)
-- layout (V11): inside the content width, no two text elements overlap
local W = ns.CHARTOOLKIT_LAYOUT.content
local function layoutOK(dd)
  for _, r in ipairs(dd.layout) do
    if r.x < 0 or r.x + r.w > W + 0.01 or r.w <= 0 then return false, r.kind .. " " .. tostring(r.text) end
  end
  local t = {}
  for _, r in ipairs(dd.layout) do if r.kind ~= "hit" and r.kind ~= "cell" then t[#t + 1] = r end end
  for i = 1, #t do for j = i + 1, #t do
    local a, bb = t[i], t[j]
    if a.x < bb.x + bb.w and bb.x < a.x + a.w and a.y < bb.y + bb.h and bb.y < a.y + a.h then return false, a.kind .. " '" .. tostring(a.text) .. "' / " .. bb.kind .. " '" .. tostring(bb.text) .. "'" end
  end end
  return true
end
for _, f in ipairs({ "all", "offense", "defense" }) do
  c.spellFilter = f
  local ok, why = layoutOK(render("spells"))
  check("layout Spells / " .. f .. ": inside the content width, no overlaps", ok, why)
end

-- 10. Redraws: a description it asked for arrives; the spellbook changes ------------------------------------------------------
c.spellFilter = "all"
render("spells")
local renders = 0
local savedRender = ns.CharToolkit_Render
ns.CharToolkit_Render = function(...) renders = renders + 1; return savedRender(...) end
fire("SPELL_DATA_LOAD_RESULT", 424242, true)
check("a description nobody here asked for: no redraw", renders == 0, renders)
DESC[9006] = "Hurl a stone for 8,000 Physical damage."
fire("SPELL_DATA_LOAD_RESULT", 9006, true)
check("the asked-for description arrives: the panel redraws and lists the spell", renders == 1 and drawn().model.byKey.spell9006 ~= nil, renders)
fire("SPELLS_CHANGED")
check("the spellbook changes: the panel redraws", renders == 2, renders)
render("gear"); renders = 0
fire("SPELLS_CHANGED")
check("on another tab: no redraw for spell events", renders == 0, renders)
ns.CharToolkit_Render = savedRender

-- 10b. #380 / #378: the spell ID beside the name; the spell's number lines at the panel's text size -------------------------------
c.tab = "spells"; c.spellFilter = "all"; c.fontSize = 11
d = render("spells")
local fl = drawn().model.byKey.spell9001
check("#380: a spell's line reads its name, then \"Spell ID: N\" (no \"#N\" at the right edge)", fl and fl.label:find("^Flame Ring") ~= nil and fl.label:find("Spell ID: 9001", 1, true) ~= nil
  and fl.value == "", fl and (fl.label .. " | " .. tostring(fl.value)))
local lab
for _, r in ipairs(recs(d, "label")) do if tostring(r.text):find("Spell ID: 9001", 1, true) then lab = r end end
check("  ...drawn across the whole width (no value column beside it)", lab ~= nil and lab.w == ns.CHARTOOLKIT_LAYOUT.content, lab and lab.w)
local big, small = 0, 0
for _, r in ipairs(recs(d, "pairValue")) do if r.size == c.fontSize then big = big + 1 else small = small + 1 end end
check("#378: the spell math lines are drawn at the panel's text size (11), not one smaller", big > 0 and small == 0, big .. " at 11, " .. small .. " smaller")
local pv
for _, r in ipairs(recs(d, "pairValue")) do if tostring(r.text):find("of attack power", 1, true) then pv = r end end
local Wc = ns.CHARTOOLKIT_LAYOUT.content
check("  ...their value gets 70% of the line, so \"N% of attack power; 1 Agility = +N\" fits one line more often", pv ~= nil and pv.w == Wc - 12 - math.floor((Wc - 12) * 0.3), pv and pv.w)
d = render("gear")
local sm = 0
for _, r in ipairs(recs(d, "pairValue")) do if r.size == c.fontSize - 1 then sm = sm + 1 end end
check("  ...other tabs keep their smaller detail lines", sm > 0, sm)
c.tab = "spells"

-- 11. Settings -----------------------------------------------------------------------------------------------------------------
local page = ns.BuildCharToolkitPage(function() end)
local sp = page.args.spells.args
check("settings: 'List spells without numbers' toggle", sp.spellsAll and sp.spellsAll.type == "toggle")
sp.spellsAll.set(nil, true)
check("  ...sets it", c.spellsAll == true)
sp.spellsAll.set(nil, false)
check("settings: a hand-added spell has a Filter dropdown", sp.s1 and sp.s1.args.kind and sp.s1.args.kind.type == "select")
sp.s1.args.kind.set(nil, "both")
check("  ...setting it stores the filter", c.spells[1].kind == "both", c.spells[1].kind)
sp.s1.args.kind.set(nil, "auto")
check("  ...'From its description' clears it", c.spells[1].kind == nil)
c.spells[1].kind = "bogus"; c = ns.CharToolkit_Cfg()
check("a bad saved filter on a spell is dropped", c.spells[1].kind == nil)
C_SpecializationInfo.GetSpecializationInfo = function() return 63, "Fire", "", 0, "DAMAGER", 4 end
c.spells = {}
sp.add.set(nil, "Fracture")
check("adding a spell by hand on an Intellect spec starts it on spell power", c.spells[1] and c.spells[1].base == "sp", c.spells[1] and c.spells[1].base)
C_SpecializationInfo.GetSpecializationInfo = savedSpec
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
   .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
