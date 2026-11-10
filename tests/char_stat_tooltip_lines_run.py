#!/usr/bin/env python3
"""The extra lines on the character window's own stat tooltips, as an option of Bonus Features > Enhanced Tooltips (Stat Calculator
V25 step R4; XayaUI_Bonus/Tooltips.lua section 5, TooltipsUI.lua "Character stats").
Xaya, docs/process/REQUEST-LOG.md section A24, her words:
  #5 "any character pane tooltips get called by improved tooltips but do not by default get loaded. all functionality has inter-addon
     tie-ins that do not by default get used unless the other elements are enabled. this is a SINGLE call per options window open after
     a reload"
  #6 tooltips: "Yes, into Enhanced Tooltips (Recommended)"; tie-in check: "Yes, that's right (Recommended)"
  A22 #15 (session 014bN6tUDLJ6T742DewZDg1s): "Hide notes unless Dev Assist"
What the player gets, on the stand-in character window (tests/char_world.lua); load order as in the game (XayaUI Bonus Features before
XayaUI QoL), then the login:
  D   a fresh install (Enhanced Tooltips on, Improved Character Display on): the option is unticked; nothing is hooked (no stat-row
      hover hook, no PaperDollFrame OnShow hook, no PaperDollFrame_UpdateStats hook); the tie-ins (the "charDisplay" and "statModel"
      services) are not even read; hovering a stat shows no XayaUI line.
  O   the option ticked, Enhanced Tooltips and Improved Character Display on: the Critical Strike tooltip gets the XayaUI block (Rating
      528 = +11.48%, Rating per 1% 46.0, Diminishing returns none yet, with the next threshold in words: her A8 design); no method note
      without XayaUI Dev Assist (A22 #15: the parry row's "before DR"); the tie-ins were read once.
  I   the option ticked, Improved Character Display off: nothing is hooked; the option is greyed with a line saying what it needs.
      Switching Improved Character Display on afterwards (its page) tells Enhanced Tooltips (a push, not a poll): the lines appear;
      off again: they stop (the hook returns at once).
  E   the option ticked, Enhanced Tooltips off: nothing is hooked.
  R   the page: the first build after a reload reads the tie-ins once more, a second build does not; hovers read none.
  N   with XayaUI Dev Assist loaded, a line's note follows its value.
  Q   XayaUI QoL off (no services): the option is greyed; ticked, nothing is hooked and nothing errors.
Every check fails on the code before step R4 (no Enhanced Tooltips option; the lines were XayaUI QoL's and on by default).
Every number is a TEST STAND-IN (tests/char_world.lua).
Run from the repo root: python3 tests/char_stat_tooltip_lines_run.py   Needs: pip install lupa."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")


def P(rel):
    return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"


PRELUDE = r'''
assert(loadfile(__WORLD__))()
function checkp(name, fn)
  local ok, cond, extra = pcall(fn)
  if not ok then check(name, false, "error: " .. tostring(cond)) else check(name, cond and true or false, extra) end
end
CharacterFrame = mk("Frame"); PaperDollFrame = mk("Frame")
STATROW = mk("Frame"); STATROW.Label = mk("FS"); STATROW.Label.text = "Critical Strike:"
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = { STATROW }
HOOKED = {}
local rawHSF = hooksecurefunc
hooksecurefunc = function(a, b, c) local k = type(a) == "string" and a or b; HOOKED[k] = (HOOKED[k] or 0) + 1; if rawHSF then return rawHSF(a, b, c) end end
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
-- count every read of the tie-in services
READS = {}
local rawService = ns.Service
ns.Service = function(name) READS[name] = (READS[name] or 0) + 1; return rawService(name) end
-- the saved variables as the game sets them before the addons' ADDON_LOADED (set by each case below)
__SAVED__
-- XayaUI Bonus Features loads before XayaUI QoL (folder order), as in the game
XayaUI_NS = ns
assert(loadfile(__TT__))("XayaUI_Bonus", ns); assert(loadfile(__TTUI__))("XayaUI_Bonus", ns)
__QOL__
ns.FireReady(); ns.SettingsOpenAllForTests()
ns.FireLogin()
TT = ns.TT
function rowHooks() return STATROW.hooks.OnEnter and #STATROW.hooks.OnEnter or 0 end
function ownerHooks() return PaperDollFrame.hooks.OnShow and #PaperDollFrame.hooks.OnShow or 0 end
function hover()
  GameTooltip:SetOwner(STATROW)
  for _, f in ipairs(STATROW.hooks.OnEnter or {}) do f(STATROW) end
  return table.concat(GameTooltip.lines or {}, " / ")
end
function openWindow() CharacterFrame:Show(); PaperDollFrame:Show(); PaperDollFrame_UpdateStats() end
function page() local p = ns.BuildTooltipsTab(function() end); return p, p.args.charStats end
'''

QOL = '''assert(loadfile(__SM__))("XayaUI_QoL", ns); assert(loadfile(__CM__))("XayaUI_QoL", ns); assert(loadfile(__ICD__))("XayaUI_QoL", ns)'''


def run(saved, body, qol=True):
    src = (PRELUDE.replace("__SAVED__", saved).replace("__QOL__", QOL if qol else "-- (XayaUI QoL switched off in the AddOns list)")
           .replace("__WORLD__", P("tests/char_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
           .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/StatModel.lua"))
           .replace("__ICD__", P("XayaUI_QoL/ImprovedCharacterDisplay.lua"))
           .replace("__TTUI__", P("XayaUI_Bonus/TooltipsUI.lua")).replace("__TT__", P("XayaUI_Bonus/Tooltips.lua")))
    lua = LuaRuntime()
    try:
        lua.execute(src)
        lua.execute(body)
    except Exception as ex:   # (the code before step R4 stops here: counted as a failed check)
        print("FAIL the case ran to its end: %s" % str(ex)[:300])
        return lua.eval("n") or 0, (lua.eval("fails") or 0) + 1
    return lua.eval("n"), lua.eval("fails")


# (its full stat list off: it hooks PaperDollFrame_UpdateStats itself, which would blur the count below)
ICD_ON = 'XayaUIQoLDB = { storeVersion = 1, characterReskin = { features = true, statList = false, _merged = true } }'
ICD_OFF = 'XayaUIQoLDB = { storeVersion = 1, characterReskin = { features = false, statList = false, _merged = true } }'
TICKED = 'XayaUIBonusDB = { storeVersion = 1, tooltips = { charStats = true } }'
totals = []

# D: a fresh install (the option at its default), Improved Character Display on
totals.append(run(ICD_ON + "\nXayaUIBonusDB = { storeVersion = 1 }\n", r'''
openWindow()
checkp("D off by default: Enhanced Tooltips' Character stats option is unticked and nothing is saved for it", function()
  local _, g = page()
  return g ~= nil and g.args.enabled.get({}) == false and TT.DB().charStats == nil, tostring(TT.DB().charStats) end)
checkp("D ...no hook installed: no stat-row hover hook, no PaperDollFrame OnShow hook, no PaperDollFrame_UpdateStats hook (V14)", function()
  return rowHooks() == 0 and ownerHooks() == 0 and (HOOKED.PaperDollFrame_UpdateStats or 0) == 0 and TT.charStatsOn == false,
    rowHooks() .. "/" .. ownerHooks() .. "/" .. tostring(HOOKED.PaperDollFrame_UpdateStats) end)
checkp("D ...the hover shows no XayaUI line", function() local s = hover(); return not s:find("XayaUI", 1, true), s end)
'''))
# D2: at the login (before any page is built) the tie-ins are not read while the option is off
totals.append(run(ICD_ON + "\nXayaUIBonusDB = { storeVersion = 1 }\n", r'''
openWindow(); hover()
checkp("D ...and the tie-ins are not read at all while it is off (no charDisplay / statModel lookup from Enhanced Tooltips)", function()
  return (READS.charDisplay or 0) == 0 and TT.charStatsState.read == false, tostring(READS.charDisplay) end)
'''))

# O: ticked, both elements on
totals.append(run(ICD_ON + "\n" + TICKED + "\n", r'''
openWindow()
local s = hover()
checkp("O ticked, Enhanced Tooltips and Improved Character Display on: the crit tooltip gets the XayaUI block", function()
  return s:find("XayaUI", 1, true) ~= nil and s:find("Rating | 528 = +11.48%", 1, true) ~= nil and s:find("Rating per 1% | 46.0", 1, true) ~= nil
    and s:find("Diminishing returns | none yet", 1, true) ~= nil, s end)
-- (V25 review) the next threshold in words is part of her A8 design for these tooltips ("the next threshold in words"): it shows to
-- everyone; a method note (how a number was read, A22 #15) shows only with XayaUI Dev Assist (the parry row's "before DR")
checkp("O ...the next threshold in words shows without XayaUI Dev Assist (A8): 'Diminishing returns | none yet; next at 1,380 rating (852 away)'", function()
  return s:find("Diminishing returns | none yet; next at 1,380 rating (852 away)", 1, true) ~= nil, s end)
STATROW.Label.text = "Parry:"
local sp = hover()
STATROW.Label.text = "Critical Strike:"
checkp("O ...a method note does not without it (A22 #15): the parry row's 'From Critical Strike' line has no 'before DR'", function()
  return sp:find("From Critical Strike", 1, true) ~= nil and not sp:find("before DR", 1, true), sp end)
checkp("O ...hooked once: one hover hook on the row, one OnShow hook, one PaperDollFrame_UpdateStats hook", function()
  openWindow(); TT.Sync(); TT.Sync()
  return rowHooks() == 1 and ownerHooks() == 1 and (HOOKED.PaperDollFrame_UpdateStats or 0) == 1, rowHooks() .. "/" .. ownerHooks() end)
checkp("O ...the tie-ins were read once (at the login): hovers and syncs read no service", function()
  local before = READS.charDisplay or 0
  hover(); hover(); TT.Sync()
  return before == 1 and (READS.charDisplay or 0) == 1, tostring(before) .. " -> " .. tostring(READS.charDisplay) end)
checkp("O ...unticked: the hook returns at once (no XayaUI line; a /reload removes it)", function()
  local _, g = page(); g.args.enabled.set({}, false)
  local t = hover()
  return TT.DB().charStats == nil and not t:find("XayaUI", 1, true), t end)
'''))

# I: ticked, Improved Character Display off; then switched on and off again on its page
totals.append(run(ICD_OFF + "\n" + TICKED + "\n", r'''
openWindow()
checkp("I ticked, Improved Character Display off: no hook installed, no XayaUI line", function()
  local s = hover()
  return rowHooks() == 0 and ownerHooks() == 0 and (HOOKED.PaperDollFrame_UpdateStats or 0) == 0 and not s:find("XayaUI", 1, true), s end)
checkp("I ...the option is greyed, with a line saying it needs Improved Character Display", function()
  local _, g = page()
  return g.args.enabled.disabled() == true and g.args.note.hidden() == false and g.args.note.name:find("Improved Character Display", 1, true) ~= nil end)
local reads = READS.charDisplay or 0
local cp = ns.BuildCharDisplayPage(function() end)
cp.xuiSwitch.set({}, true)   -- Improved Character Display switched on on its page
openWindow()
checkp("I ...Improved Character Display switched on: it tells Enhanced Tooltips (no new lookup) and the lines appear", function()
  local s = hover()
  return rowHooks() == 1 and s:find("Rating | 528", 1, true) ~= nil and (READS.charDisplay or 0) == reads, s end)
cp.xuiSwitch.set({}, false)
checkp("I ...switched off again: the lines stop (the hook returns at once)", function()
  local s = hover(); return not s:find("XayaUI", 1, true) and TT.charStatsOn == false, s end)
'''))

# E: ticked, Enhanced Tooltips off
totals.append(run(ICD_ON + "\nXayaUIBonusDB = { storeVersion = 1, tooltips = { enabled = false, charStats = true } }\n", r'''
openWindow()
checkp("E ticked, Enhanced Tooltips off: no hook installed, no XayaUI line, the tie-ins not read at the login", function()
  local s = hover()
  return rowHooks() == 0 and ownerHooks() == 0 and not s:find("XayaUI", 1, true) and (READS.charDisplay or 0) == 0, s end)
'''))

# R: the page's once-per-reload read
totals.append(run(ICD_ON + "\n" + TICKED + "\n", r'''
local r0 = READS.charDisplay or 0
page()
local r1 = READS.charDisplay or 0
page(); page(); openWindow(); hover()
checkp("R the first build of the Enhanced Tooltips page after a reload reads the tie-ins once more; later builds and hovers do not", function()
  return r0 == 1 and r1 == 2 and (READS.charDisplay or 0) == 2, r0 .. "/" .. r1 .. "/" .. tostring(READS.charDisplay) end)
'''))

# N: XayaUI Dev Assist loaded
totals.append(run(ICD_ON + "\n" + TICKED + "\nns.devAssistLoaded = true\n", r'''
openWindow()
checkp("N with XayaUI Dev Assist loaded, the note follows its value: 'Diminishing returns | none yet; next at 1,380 rating (852 away)'", function()
  local s = hover(); return s:find("Diminishing returns | none yet; next at 1,380 rating (852 away)", 1, true) ~= nil, s end)
checkp("N ...and a method note too: the parry row's 'From Critical Strike' line says 'before DR'", function()
  STATROW.Label.text = "Parry:"; local s = hover(); STATROW.Label.text = "Critical Strike:"
  return s:find("before DR", 1, true) ~= nil, s end)
'''))

# Q: XayaUI QoL off
totals.append(run(TICKED + "\n", r'''
openWindow()
checkp("Q XayaUI QoL off: the option is greyed; ticked, nothing is hooked, no XayaUI line, no error", function()
  local _, g = page()
  local s = hover()
  return g.args.enabled.disabled() == true and rowHooks() == 0 and ownerHooks() == 0 and not s:find("XayaUI", 1, true), s end)
''', qol=False))

n = sum(t[0] for t in totals); fails = sum(t[1] for t in totals)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
