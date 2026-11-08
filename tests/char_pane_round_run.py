# Stub test for the character window round of 2026-11-06 (XayaUI_QoL 0.7.31; REQUEST-LOG #70-#74). Xaya's words (verbatim in the log):
#   #70: "missing details about about all possible stats / the ability to customize how to display stats in the primary character window";
#   #71: her answers: stats "2 but customizable and prettified with colors" (option 2: the lines of the Stat Calculator's Character Stats);
#        customise "Show / hide each stat, Order, % / rating / both, Groups and colours"; #74: default "Everything on".
#   #72: "character pane option should also allow for extra height"; #73: her answer "either one" (built: spread the slots).
# What it checks is what the player sees: the window's height, the slots' places (from their anchors, tests/char_pane_geometry.lua),
# the model's size; the stats pane's lines (text, value, colour, order) drawn by the reskin's own list; the settings that change them;
# the combat wait; V14 (off at login: nothing made).
# Negative control (V1): every check fails on QoL 0.7.28's files (the session branch head e52ee1d), except those marked "(guard)".
# Run from the repo root: python3 tests/char_pane_round_run.py   Needs: pip install lupa. Every number is a TEST STAND-IN.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"

PRELUDE = r'''
assert(loadfile(__WORLD__))()
assert(loadfile(__GEOM__))()
function checkp(name, fn)
  local ok, cond, extra = pcall(fn)
  if not ok then check(name, false, "error: " .. tostring(cond)) else check(name, cond and true or false, extra) end
end
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
LABEL = { 1, 0.82, 0, 1 }
ns.Theme = { listeners = {}, cur = { accent = { 0.64, 0.19, 0.79, 1 } } }
function ns.Theme.Col(class, prop, fb) if class == "xui-label" and prop == "text" then return { LABEL[1], LABEL[2], LABEL[3], 1 } end; return fb and { fb[1], fb[2], fb[3], fb[4] or 1 } or { 1, 1, 1, 1 } end
function ns.Theme.OnResolve(fn) table.insert(ns.Theme.listeners, fn) end
function ns.Theme.OffResolve(fn) end
GEAR, ITEMS, TIP, UPG = {}, {}, {}, {}
GetInventoryItemLink = function(_, slot) return GEAR[slot] end
C_TooltipInfo.GetInventoryItem = function(_, slot) return { lines = TIP[slot] or {} } end
C_Timer.After = function(d, fn) fn() end
-- the stats pane as a frame with a size, inside the window's right part (CharacterFrame.InsetRight)
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
CharacterStatsPane.pts = { { "TOPLEFT", CharacterFrame.InsetRight, "TOPLEFT", 3, -3 }, { "BOTTOMRIGHT", CharacterFrame.InsetRight, "BOTTOMRIGHT", -3, 3 } }
CharacterStatsPane.shown = true
assert(loadfile(__CT__))("XayaUI_QoL", ns)
assert(loadfile(__RS__))("XayaUI_QoL", ns)
function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.01 end
function sameCol(a, b) return a and b and near(a[1], b[1]) and near(a[2], b[2]) and near(a[3], b[3]) end
'''

def lua_with(extra=""):
    lua = LuaRuntime()
    src = (PRELUDE + extra).replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__GEOM__", P("tests/char_pane_geometry.lua")) \
        .replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua")) \
        .replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua")) \
        .replace("__RS__", P("XayaUI_QoL/CharacterReskin.lua"))
    lua.execute(src)
    return lua
totals = []

# ---------------------------------------------------------------------------------------------------------------------------------
# A. Extra height (#72, #73): the window taller, the slot columns spread evenly, the model taller, the weapons down; 0 = Blizzard's
# ---------------------------------------------------------------------------------------------------------------------------------
lua = lua_with(r'''
CueRulesDB.characterReskin = { enabled = true }
''')
lua.execute(r'''
ns.FireReady(); ns.SettingsOpenAllForTests()   -- (P5) the module addons load after XayaUI: their settings stores open (Modules.lua section 0c)
local rc = ns.CharReskin_Cfg()
CharacterFrame:Show(); PaperDollFrame:Show(); ns.CharReskin_Apply()
local LEFT, RIGHT = PANE_SLOTS_LEFT, PANE_SLOTS_RIGHT
local function gaps(list)
  local out = {}
  for i = 2, #list do out[#out + 1] = RECT(_G["Character" .. list[i - 1]]).b - RECT(_G["Character" .. list[i]]).t end
  return out
end
local function all(list, v) for _, x in ipairs(list) do if not near(x, v) then return false end end; return #list > 0 end
local h0, mh0 = CharacterFrame.h, RECT(CharacterModelScene)
local mainB0 = RECT(CharacterMainHandSlot).b - RECT(CharacterFrame).b
checkp("(guard) the default: Extra height 0, the window 424 high, every gap between two slots 4 px, the model 320 high (Blizzard's layout)", function()
  return rc.tallPx == 0 and CharacterFrame.h == 424 and all(gaps(LEFT), 4) and all(gaps(RIGHT), 4) and near(mh0.t - mh0.b, 320), tostring(rc.tallPx) end)
local pts0 = {}
for _, n in ipairs(LEFT) do pts0[n] = { unpack(_G["Character" .. n].pts[#_G["Character" .. n].pts]) } end
rc.tallPx = 70; ns.CharReskin_Apply()
local win, model = RECT(CharacterFrame), RECT(CharacterModelScene)
checkp("Extra height 70: the window is Blizzard's height + 70 (424 -> 494)", function() return CharacterFrame.h == 494, CharacterFrame.h end)
checkp("  ...each column's 7 gaps grow evenly: every gap 4 + 70 / 7 = 14 px, left and right", function()
  return all(gaps(LEFT), 14) and all(gaps(RIGHT), 14), table.concat(gaps(LEFT), ",") end)
checkp("  ...the model is 70 taller (320 -> 390), same width, inside the window", function()
  return near(model.t - model.b, 390) and near(model.r - model.l, 231) and inside(model, win), rstr(model) end)
checkp("(guard)   ...the weapons move down with the window's bottom (same distance from it), the last slots stay above them", function()
  local mh = RECT(CharacterMainHandSlot)
  return near(mh.b - win.b, mainB0) and RECT(CharacterWristSlot).b > mh.b - 0.01, mh.b - win.b end)
checkp("  ...each slot's block may use half of the wider gap (the reskin's band for a slot: 7 px more above and below)", function()
  return ns.CharReskin_TallGap and near(ns.CharReskin_TallGap(), 10) end)
checkp("  .../xui reskin status names it", function()
  printed = {}; ns.RunCommand("reskin", "status")
  for _, l in ipairs(printed) do if l:find("Extra height: on, 70 px taller (424 -> 494)", 1, true) then return true end end
  return false, table.concat(printed, " / ") end)
rc.tallPx = 0; ns.CharReskin_Apply()
checkp("(guard) back to 0: Blizzard's layout exactly (the height 424, every slot's own anchor, the model 320)", function()
  for _, n in ipairs(LEFT) do
    local a, b = pts0[n], _G["Character" .. n].pts[#_G["Character" .. n].pts]
    for i = 1, 5 do if a[i] ~= b[i] then return false, n .. " anchor " .. i end end
  end
  return CharacterFrame.h == 424 and near(RECT(CharacterModelScene).t - RECT(CharacterModelScene).b, 320) and all(gaps(LEFT), 4) end)
combat = true
rc.tallPx = 100; ns.CharReskin_Apply()
checkp("in combat nothing of the height changes; it waits for the end of combat (PLAYER_REGEN_ENABLED)", function()
  local ev = ns.CharReskinWide and ns.CharReskinWide.ev
  return CharacterFrame.h == 424 and ev ~= nil and ev.events.PLAYER_REGEN_ENABLED == true, CharacterFrame.h end)
combat = false
fire("PLAYER_REGEN_ENABLED")
checkp("  ...combat ends: the window grows (424 -> 524), gaps 4 + 100 / 7", function() return CharacterFrame.h == 524 and all(gaps(LEFT), 4 + 100 / 7), CharacterFrame.h end)
rc.wide = false; ns.CharReskin_Apply()
checkp("(guard) the wider window off: Extra height does nothing (Blizzard's height and gaps)", function() return CharacterFrame.h == 424 and all(gaps(RIGHT), 4), CharacterFrame.h end)
rc.wide = true; rc.tallPx = 0; ns.CharReskin_Apply()
local pg = ns.BuildCharReskinPage(function() end)
checkp("the setting: \"Extra height\", 0-300 px in 1 px steps, right under Extra width, greyed while the wider window is off", function()
  local a, w = pg.args.tallPx, pg.args.widePx
  if not a then return false, "no setting" end
  local on = a.disabled()
  rc.wide = false; local off = a.disabled(); rc.wide = true
  return a.name == "Extra height" and a.min == 0 and a.max == 300 and a.step == 1 and a.order > w.order and a.order < pg.args.bgAlpha.order and not on and off end)
''')
totals.append((lua.eval("n"), lua.eval("fails")))

# ---------------------------------------------------------------------------------------------------------------------------------
# B. The full stat list (#70, #71, #74)
# ---------------------------------------------------------------------------------------------------------------------------------
lua = lua_with(r'''
CueRulesDB.characterReskin = { enabled = true }
''')
lua.execute(r'''
ns.FireReady(); ns.SettingsOpenAllForTests()   -- (P5) the module addons load after XayaUI: their settings stores open (Modules.lua section 0c)
local rc = ns.CharReskin_Cfg()
CM.gcd = { dur = 1.16, haste = 29.25 }
CharacterFrame:Show(); PaperDollFrame:Show(); ns.CharReskin_Apply()
local function recs() return ns.CharReskin_StatListRecs and ns.CharReskin_StatListRecs() or {} end
local function texts(kind) local t = {}; for _, r in ipairs(recs()) do if r.kind == kind then t[#t + 1] = r.text end end; return table.concat(t, "|") end
local function rec(text) for _, r in ipairs(recs()) do if r.text == text then return r end end end
local clean = CM.Build(setmetatable({ whatIf = 0, whatIfStats = {}, whatIfPrimary = false }, { __index = {} }), "stats")
local n = 0
for _, sec in ipairs(clean.sections) do if sec.key == "map_character" then for _, it in ipairs(sec.items) do if it.kind ~= "subhead" and it.kind ~= "colhead" then n = n + 1 end end end end
checkp("the reskin on: the stats pane shows the Character Stats headings in order: Core Stats, Primary, General, Offensive, Defensive, Secondaries, Tertiaries", function()
  return texts("group") == "Core Stats|Primary|General|Offensive|Defensive|Secondaries|Tertiaries", texts("group") end)
checkp("  ...and every stat line of Character Stats (her answer \"Everything on\"): " .. n .. " lines, Agility first, Speed last", function()
  local s = {}; for _, r in ipairs(recs()) do if r.kind == "stat" then s[#s + 1] = r.text end end
  return #s == n and s[1] == "Agility" and s[#s] == "Speed", #s .. " " .. table.concat(s, ",") end)
checkp("  ...the values are the Stat Calculator's (Critical Strike 22.48%, Haste 29.25%, Health 1,476,516)", function()
  return rec("Critical Strike").value == clean.byKey.map_crit.value and rec("Critical Strike").value == "22.48%" and rec("Haste").value == "29.25%" and rec("Health").value == "1,476,516",
    tostring(rec("Critical Strike") and rec("Critical Strike").value) end)
checkp("  ...each stat's name in its stat colour (Critical Strike, Versatility); headings in the label colour", function()
  return sameCol(rec("Critical Strike").color, CM.STAT_COLORS.crit) and sameCol(rec("Versatility").color, CM.STAT_COLORS.vers) and sameCol(rec("Secondaries").color, LABEL)
    and sameCol(rec("Critical Strike").fs.color, CM.STAT_COLORS.crit) end)
checkp("  ...drawn on the reskin's own list over Blizzard's pane (a child of CharacterStatsPane, shown, an opaque fill under it)", function()
  local L = ns.CharReskinParts.statList
  return L and L.parent == CharacterStatsPane and L:IsShown() and L.fill and L.fill.color and L.fill.color[4] == 1 end)
local pg = ns.BuildCharReskinPage(function() ns.CharReskin_Apply() end)
local page = pg.args.statListPage or { args = {} }
-- (a stand-in for a missing control on older code, so a check fails instead of the run stopping)
local NOOP = function() end
local DUMMY = { name = function() return "" end, args = setmetatable({}, { __index = function() return { set = NOOP, func = NOOP, hidden = NOOP } end }) }
local function slot(group, i) for k, v in pairs(page.args) do if type(v) == "table" and v.order == group * 100 + i then return v end end; return DUMMY end
local gSec
for gi, k in ipairs({ "Core Stats", "Primary", "General", "Offensive", "Defensive", "Secondaries", "Tertiaries" }) do if k == "Secondaries" then gSec = gi end end
checkp("its settings: a Stat list page with each heading (name, colour) and each stat (show, percent / rating / both, up, down, name, colour)", function()
  local h, s1 = slot(gSec, 0), slot(gSec, 1)
  return page ~= nil and pg.args.statListPage ~= nil and h.args.name and h.args.color and s1.args.show and s1.args.mode and s1.args.up and s1.args.down and s1.args.name and s1.args.color
    and s1.name():find("Critical Strike", 1, true) ~= nil, s1 and s1.name() end)
local s1, s2 = slot(gSec, 1), slot(gSec, 2)
s2.args.show.set(nil, false)
checkp("hide: Haste unticked leaves the list; ticked again it is back", function()
  local gone = rec("Haste") == nil
  s2.args.show.set(nil, true)
  return gone and rec("Haste") ~= nil end)
s1.args.mode.set(nil, "rating")
checkp("percent / rating / both: Critical Strike as its rating (528), then both (528 / 22.48%)", function()
  local r1 = rec("Critical Strike").value
  s1.args.mode.set(nil, "both")
  return r1 == "528" and rec("Critical Strike").value == "528 / 22.48%", r1 .. " | " .. rec("Critical Strike").value end)
checkp("  ...(guard) the mode is offered only where the stat has both (not on Agility)", function() return slot(2, 1).args.mode.hidden() == true and s1.args.mode.hidden() == false end)
s1.args.down.func()
checkp("order: Critical Strike moved down: Haste first, then Critical Strike, in the list and on the page", function()
  local s = {}; for _, r in ipairs(recs()) do if r.kind == "stat" then s[#s + 1] = r.text end end
  local hi, ci
  for i, t in ipairs(s) do if t == "Haste" then hi = i elseif t == "Critical Strike" then ci = i end end
  return hi and ci and hi + 1 == ci and slot(gSec, 1).name():find("Haste", 1, true) ~= nil, hi .. "/" .. ci end)
slot(gSec, 0).args.name.set(nil, "My ratings"); slot(gSec, 0).args.color.set(nil, 0.2, 0.9, 0.3)
slot(gSec, 2).args.name.set(nil, "Crit"); slot(gSec, 2).args.color.set(nil, 1, 1, 1)
checkp("groups and colours: the heading renamed \"My ratings\" and recoloured; Critical Strike renamed \"Crit\" and drawn white", function()
  return rec("My ratings") ~= nil and sameCol(rec("My ratings").color, { 0.2, 0.9, 0.3 }) and rec("Crit") ~= nil and sameCol(rec("Crit").color, { 1, 1, 1 }) and rec("Secondaries") == nil end)
if page.args.reset then page.args.reset.func() end
checkp("Reset the list: names, colours, order, modes back", function()
  return rec("Secondaries") ~= nil and rec("Critical Strike") ~= nil and rec("Critical Strike").value == "22.48%" and sameCol(rec("Critical Strike").color, CM.STAT_COLORS.crit) end)
rc.statList = false; ns.CharReskin_Apply()
checkp("the part switched off (Full stat list): the list hides, Blizzard's own list shows again", function() return not ns.CharReskinParts.statList:IsShown() end)
rc.statList = true; ns.CharReskin_Apply()
rc.enabled = false; ns.CharReskin_Apply()
checkp("the reskin off: the list hides", function() return not ns.CharReskinParts.statList:IsShown() end)
''')
totals.append((lua.eval("n"), lua.eval("fails")))

# V14: off at login: nothing of the list is made
lua = lua_with(r'''
CueRulesDB.characterReskin = { enabled = false }
''')
lua.execute(r'''
ns.FireReady(); ns.SettingsOpenAllForTests()   -- (P5) the module addons load after XayaUI: their settings stores open (Modules.lua section 0c)
CharacterFrame:Show(); PaperDollFrame:Show()
PaperDollFrame_UpdateStats()
checkp("(guard) V14: the reskin off at login: no stat list frame, no height change", function()
  return (ns.CharReskinParts or {}).statList == nil and CharacterFrame.h == 424 end)
''')
totals.append((lua.eval("n"), lua.eval("fails")))

n = sum(t[0] for t in totals); fails = sum(t[1] for t in totals)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
