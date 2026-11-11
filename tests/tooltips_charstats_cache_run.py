#!/usr/bin/env python3
"""Enhanced Tooltips > Character stats (XayaUI_Bonus/Tooltips.lua section 5): one model build per change in stats, not one per hover
(Stat Calculator review docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md SC-047 and SC-035, hover side; V25 unit E).
Before: each hover of a character-window stat row ran a full CM.Build(CLEAN, "stats") or CM.Build(CLEAN, nil) (18 item reads, the
armor bisection, a spellbook scan), in combat too. Now the built models are kept between hovers while the window is open and dropped
when they may be stale: Blizzard's PaperDollFrame_UpdateStats (post-hook), the window showing and hiding, and the few changes the model
reads that may move no number the window shows (equipment, item data, gems / enchants, the spellbook), never by comparing numbers.
What the player gets, on the stand-in character window (tests/char_world.lua of the tree under test):
  H  hover Critical Strike, Haste and Mastery (and Critical Strike again) with no stat change: the stat model's CM.Build runs once for
     the stat map, not once per hover (counted on the "statModel" service's own CM.Build); the flat list (Item Level row) once too.
  U  a stat changes (crit rating 528 -> 920) and Blizzard runs PaperDollFrame_UpdateStats: the next crit hover shows the new number
     ("Rating | 920 = +20.00%"), with one more build.
  W  close the window: nothing is kept and no drop event is listened to; change the rating while it is closed and reopen (OnShow only,
     no stat update): the hover shows the new number, nothing stale.
  V  equipment changes with the window open (PLAYER_EQUIPMENT_CHANGED, no stat update): the next hover builds again.
  X  the option off: no event frame, nothing built or kept (V14).
  S  the read-only counter Dev Assist shows (TT.charStatsState.builds) matches the service count.
  C  (round 2, review of unit E) a model built in combat, with crit rating and its bonus secret, holds them as "hidden"; when combat
     ends (PLAYER_REGEN_ENABLED, or ADDON_RESTRICTION_STATE_CHANGED alone) and the values are real again, the next hover shows the
     real Rating line with no PaperDollFrame_UpdateStats in between. In combat two hovers still build once. FAILS on the round-1 tree
     (the in-combat model stayed kept after combat, so the block stayed empty).
  Q  the QA walkthrough's checks on the stand-in, including (round 2) step 2 passing when a stat tick drops the models between hovers,
     step 2 failing when builds rise with no drop, step 3 failing when the swap rebuilt nothing, and step 3 reading a rating written
     with another thousands separator ("1.012").
Every number is a TEST STAND-IN. FAILS on f34cc33 (three builds for three hovers; no kept-model state).
Run: python3 tests/tooltips_charstats_cache_run.py [tree root]   (default: this repository)   Needs: pip install lupa."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, "..")


def P(rel):
    return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"


PRELUDE = r'''
assert(loadfile(__WORLD__))()
function checkp(name, fn)
  local ok, cond, extra = pcall(fn)
  if not ok then check(name, false, "error: " .. tostring(cond)) else check(name, cond and true or false, extra) end
end
STAT_AVERAGE_ITEM_LEVEL = STAT_AVERAGE_ITEM_LEVEL or "Item Level"
CharacterFrame = mk("Frame"); PaperDollFrame = mk("Frame")
local function row(t) local r = mk("Frame"); r.Label = mk("FS"); r.Label.text = t; return r end
ROWS = { crit = row("Critical Strike:"), haste = row("Haste:"), mastery = row("Mastery:"), ilvl = row("Item Level:") }
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = { ROWS.crit, ROWS.haste, ROWS.mastery, ROWS.ilvl }
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
__SAVED__
XayaUI_NS = ns
assert(loadfile(__TT__))("XayaUI_Bonus", ns); assert(loadfile(__TTUI__))("XayaUI_Bonus", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns); assert(loadfile(__CM__))("XayaUI_QoL", ns); assert(loadfile(__ICD__))("XayaUI_QoL", ns)
ns.FireReady(); ns.SettingsOpenAllForTests()
ns.FireLogin()
TT = ns.TT
-- count every model build on the "statModel" service itself, by kind
BUILDS = { stats = 0, all = 0 }
local svc = ns.Service("statModel")
local CM = svc and svc.CM
if CM and CM.Build then
  local raw = CM.Build
  CM.Build = function(cfg, tab) local k = (tab == "stats") and "stats" or (tab == nil and "all" or tostring(tab)); BUILDS[k] = (BUILDS[k] or 0) + 1; return raw(cfg, tab) end
end
function hover(r)
  GameTooltip:SetOwner(r)
  for _, f in ipairs(r.hooks.OnEnter or {}) do f(r) end
  return table.concat(GameTooltip.lines or {}, " / ")
end
function openWindow() CharacterFrame:Show(); PaperDollFrame:Show(); PaperDollFrame_UpdateStats() end
function closeWindow() PaperDollFrame:Hide(); CharacterFrame:Hide() end
function forget() if ForgetModel then ForgetModel() end end   -- (the model's own kept reads, where the tree has them: unit B)
function kept() return TT.CharStatsKept and TT.CharStatsKept() or -1 end
function dropFrame() return TT.charStatsState and TT.charStatsState.ev end
function listening() local f = dropFrame(); local n = 0; for _ in pairs(f and f.events or {}) do n = n + 1 end; return n end
'''

ICD_ON = 'XayaUIQoLDB = { storeVersion = 1, characterReskin = { features = true, statList = false, _merged = true } }'
TICKED = 'XayaUIBonusDB = { storeVersion = 1, tooltips = { charStats = true } }'
UNTICKED = 'XayaUIBonusDB = { storeVersion = 1 }'


def run(saved, body):
    src = (PRELUDE.replace("__SAVED__", saved)
           .replace("__WORLD__", P("tests/char_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
           .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/StatModel.lua"))
           .replace("__ICD__", P("XayaUI_QoL/ImprovedCharacterDisplay.lua"))
           .replace("__TTUI__", P("XayaUI_Bonus/TooltipsUI.lua")).replace("__TT__", P("XayaUI_Bonus/Tooltips.lua")))
    lua = LuaRuntime()
    try:
        lua.execute(src)
        lua.execute(body)
    except Exception as ex:
        print("FAIL the case ran to its end: %s" % str(ex)[:300])
        return (lua.eval("n") or 0), (lua.eval("fails") or 0) + 1
    return lua.eval("n"), lua.eval("fails")


totals = []
print("tree under test: %s" % os.path.abspath(ROOT))

totals.append(run(ICD_ON + "\n" + TICKED + "\n", r'''
openWindow()
BUILDS.stats, BUILDS.all = 0, 0
local s1 = hover(ROWS.crit); local s2 = hover(ROWS.haste); local s3 = hover(ROWS.mastery); local s4 = hover(ROWS.crit)
checkp("H the three hovers show their XayaUI blocks (Critical Strike: 'Rating | 528 = +11.48%')", function()
  return s1:find("Rating | 528 = +11.48%", 1, true) ~= nil and s2:find("XayaUI", 1, true) ~= nil and s3:find("XayaUI", 1, true) ~= nil
    and s4 == s1, s1 end)
checkp("H Critical Strike, Haste, Mastery, Critical Strike with no stat change: the stat map is built once, not once per hover", function()
  return BUILDS.stats == 1, "CM.Build(.., 'stats') ran " .. BUILDS.stats .. " times for 4 hovers" end)
hover(ROWS.ilvl); hover(ROWS.ilvl)
checkp("H ...the flat list (the Item Level row) is built once for two hovers too", function()
  return BUILDS.all == 1, "CM.Build(.., nil) ran " .. BUILDS.all .. " times for 2 hovers" end)
checkp("S the read-only counter (TT.charStatsState.builds) counts the same builds", function()
  local b = TT.charStatsState and TT.charStatsState.builds
  return b == BUILDS.stats + BUILDS.all, tostring(b) .. " vs " .. (BUILDS.stats + BUILDS.all) end)

-- U: a stat changes; Blizzard updates the pane
ratings[9] = 920; forget()
PaperDollFrame_UpdateStats()
local u = hover(ROWS.crit)
checkp("U crit rating 528 -> 920, PaperDollFrame_UpdateStats: the next hover shows 'Rating | 920 = +20.00%'", function()
  return u:find("Rating | 920 = +20.00%", 1, true) ~= nil and not u:find("528", 1, true), u end)
hover(ROWS.haste); hover(ROWS.mastery)
checkp("U ...one build for the change, then kept again for Haste and Mastery", function()
  return BUILDS.stats == 2, "stats builds " .. BUILDS.stats end)

-- W: closed = nothing kept, nothing listened to; reopened = fresh
checkp("W window open: the drop events are listened to", function()
  return dropFrame() ~= nil and listening() >= 1 and dropFrame().events.PLAYER_EQUIPMENT_CHANGED == true, tostring(listening()) end)
closeWindow()
checkp("W window closed: no model kept and no event listened to", function()
  return kept() == 0 and listening() == 0, "kept " .. kept() .. ", events " .. listening() end)
ratings[9] = 1012; forget()
PaperDollFrame:Show(); CharacterFrame:Show()   -- (OnShow only: no PaperDollFrame_UpdateStats)
local w = hover(ROWS.crit)
checkp("W changed while closed, reopened: the hover shows 'Rating | 1,012' (nothing stale)", function()
  return (w:find("Rating | 1,012", 1, true) or w:find("Rating | 1012", 1, true)) ~= nil and not w:find("920", 1, true), w end)

-- V: equipment changes with the window open and no stat update
local b0 = BUILDS.stats
hover(ROWS.crit)
fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
hover(ROWS.crit); hover(ROWS.haste)
checkp("V PLAYER_EQUIPMENT_CHANGED with the window open: the next hover builds again, once", function()
  return BUILDS.stats == b0 + 1, "stats builds " .. b0 .. " -> " .. BUILDS.stats end)
checkp("V ...no secret value was compared or used (the stand-in counts misuse)", function() return misuse == 0, misuse end)
'''))

# C: a model built in combat (secret ratings) is not kept past the end of combat
COMBAT = r'''
openWindow()
local rawB = GetCombatRatingBonus
function secretCrit(on)
  combat = on
  if on then ratings[9] = SECRET; GetCombatRatingBonus = function(i) if i == 9 then return SECRET end return rawB(i) end
  else ratings[9] = 528; GetCombatRatingBonus = rawB end
  forget()
end
secretCrit(true)
BUILDS.stats = 0
local a = hover(ROWS.crit); hover(ROWS.crit)
checkp("C in combat, crit secret: no Rating number is shown, and two hovers build once (nothing extra in combat)", function()
  return not a:find("Rating | 528", 1, true) and BUILDS.stats == 1, a .. " | stats builds " .. BUILDS.stats end)
secretCrit(false)
fire(__END__)
local b = hover(ROWS.crit)
checkp("C combat ends (" .. __END__ .. ", no PaperDollFrame_UpdateStats): the next hover shows the real 'Rating | 528 = +11.48%'", function()
  return b:find("Rating | 528 = +11.48%", 1, true) ~= nil, b end)
checkp("C ...no secret value was compared or used", function() return misuse == 0, misuse end)
'''
totals.append(run(ICD_ON + "\n" + TICKED + "\n", COMBAT.replace("__END__", "'PLAYER_REGEN_ENABLED'")))
totals.append(run(ICD_ON + "\n" + TICKED + "\n", COMBAT.replace("__END__", "'ADDON_RESTRICTION_STATE_CHANGED'")))

# X: the option off: nothing of it
totals.append(run(ICD_ON + "\n" + UNTICKED + "\n", r'''
openWindow(); hover(ROWS.crit); PaperDollFrame_UpdateStats(); closeWindow(); openWindow()
checkp("X the option off: no event frame, no build, nothing kept (V14)", function()
  return dropFrame() == nil and BUILDS.stats == 0 and BUILDS.all == 0 and (kept() == 0) and TT.CharStatsKept ~= nil,
    tostring(dropFrame()) .. "/" .. BUILDS.stats .. "/" .. kept() end)
'''))

# T: switched off with the window open: the kept models go and the events stop; on again with the window open: listened to again
totals.append(run(ICD_ON + "\n" + TICKED + "\n", r'''
openWindow(); hover(ROWS.crit)
TT.DB().charStats = nil; TT.Sync()
checkp("T unticked with the window open: nothing kept, no event listened to, no XayaUI line", function()
  local s = hover(ROWS.crit)
  return kept() == 0 and listening() == 0 and not s:find("XayaUI", 1, true), "kept " .. kept() .. ", events " .. listening() end)
TT.DB().charStats = true; TT.Sync()
checkp("T ticked again with the window still open: the drop events are listened to again and the lines show", function()
  local s = hover(ROWS.crit)
  return listening() >= 1 and s:find("Rating | 528", 1, true) ~= nil, s end)
'''))

# Q: the QA walkthrough (XayaUI_DevAssist/QAWalks-tooltips-charstats.lua) on the stand-in: each check gives the verdict it should
totals.append(run(ICD_ON + "\n" + TICKED + "\n", r'''
WALKS = {}
XayaUI_DevQA = { Register = function(id, w) WALKS[id] = w end }
PaperDollFrame.IsVisible = function(self) return self.shown end   -- (stand-in: the game's IsVisible)
local okL, errL = pcall(function() assert(loadfile(__WALK__))("XayaUI_DevAssist", {}) end)
local W = WALKS["tooltips-charstats-cache"]
checkp("Q the walkthrough loads and registers with prefill = true", function()
  return okL and W ~= nil and W.prefill == true, tostring(errL) end)
local st = W and W.steps or {}
local v1, n1 = st[1].check()
checkp("Q step 1 with the window closed: no verdict, it asks to open the window", function() return v1 == nil and n1:find("open the character window", 1, true) ~= nil, n1 end)
openWindow()
local v1b, n1b = st[1].check()
checkp("Q step 1 with the window open: pass", function() return v1b == true, n1b end)
st[2].setup()
hover(ROWS.crit); hover(ROWS.haste); hover(ROWS.mastery)
local v2, n2 = st[2].check()
checkp("Q step 2 after three hovers: pass, 'rose by 1'", function() return v2 == true and n2:find("rose by 1", 1, true) ~= nil, n2 end)
-- a stat tick between hovers (Blizzard updates the window): the models are rightly dropped and built again; a correct build must pass
PaperDollFrame_UpdateStats(); st[2].setup()   -- (nothing kept at the start, as on a fresh open)
hover(ROWS.crit); PaperDollFrame_UpdateStats(); hover(ROWS.haste); hover(ROWS.mastery)
local v2b, n2b = st[2].check()
checkp("Q step 2 with a stat update between hovers: pass, 'rose by 2 ... with 1 drop(s)'", function()
  return v2b == true and n2b:find("rose by 2 for the hovers, with 1 drop(s)", 1, true) ~= nil, n2b end)
-- builds rising with no drop (a per-hover build, as on f34cc33): fail
st[2].setup()
hover(ROWS.crit); TT.charStatsState.builds = TT.charStatsState.builds + 2
local v2c, n2c = st[2].check()
checkp("Q step 2 with builds rising and no drop: fail", function() return v2c == false, n2c end)
-- step 3 without its own Do it for me: no verdict
local v3a, n3a = st[3].check()
checkp("Q step 3 before its Do it for me: no verdict, it asks for Do it for me", function()
  return v3a == nil and n3a:find("Do it for me", 1, true) ~= nil, n3a end)
-- step 3: an item swap that dropped nothing (the drop missing): fail even though the numbers match
st[3].setup()
hover(ROWS.crit)
local v3b, n3b = st[3].check()
checkp("Q step 3 when nothing was rebuilt after the swap: fail ('rebuilt after the swap: no')", function()
  return v3b == false and n3b:find("rebuilt after the swap: no", 1, true) ~= nil, n3b end)
st[3].setup()
ratings[9] = 700; forget(); fire("PLAYER_EQUIPMENT_CHANGED", 13, true); PaperDollFrame_UpdateStats()
hover(ROWS.crit)
local v3, n3 = st[3].check()
checkp("Q step 3 after a gear change: rebuilt, and the XayaUI Rating line (700) matches the game's crit rating; both captured", function()
  return v3 == true and n3:find("rebuilt after the swap: yes", 1, true) ~= nil and n3:find("XayaUI Rating line: 700", 1, true) ~= nil
    and n3:find("melee 700", 1, true) ~= nil, n3 end)
-- another locale's thousands separator
BreakUpLargeNumbers = function(n) return (tostring(n):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")) end
st[3].setup()
ratings[9] = 1012; forget(); fire("PLAYER_EQUIPMENT_CHANGED", 13, true)
hover(ROWS.crit)
local v3d, n3d = st[3].check()
checkp("Q step 3 reads 'Rating | 1.012' as 1012 (thousands separator of any locale)", function()
  return v3d == true and n3d:find("XayaUI Rating line: 1.012", 1, true) ~= nil and n3d:find("melee 1012", 1, true) ~= nil, n3d end)
BreakUpLargeNumbers = nil
checkp("Q step 4 asks her (noVerdict)", function() return st[4].noVerdict == true end)
'''.replace("__WALK__", P("XayaUI_DevAssist/QAWalks-tooltips-charstats.lua"))))

n = sum(t[0] for t in totals); fails = sum(t[1] for t in totals)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
