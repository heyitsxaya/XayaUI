#!/usr/bin/env python3
"""Enhanced Tooltips > Character stats (XayaUI_Bonus/Tooltips.lua section 5, TooltipsUI.lua): the V27 / V14 gate fixes of unit
U3-tooltips-charstats (gate findings G-013 and G-018).
What the player gets, on the stand-in character window (tests/char_world.lua of the tree under test):
  R  (G-013, V27 "no running loops") Blizzard updates the stat pane again and again with the same rows (PaperDollFrame_UpdateStats,
     possibly many times in combat): the pane's children are not walked again (a non-row child of the pane counts every look at its
     Label, which only a walk does). A new row (the child count changes) is walked once and its hover shows the XayaUI block.
  K  (G-013) hovering stat rows reads the game's label strings (STAT_HASTE, SPELL_STAT1_NAME, ...: each read counted through a
     metatable on _G) only on the first hover after a reload, not on every hover; every row still finds its stat (parity with the old
     in-order search: Critical Strike, Haste, Mastery, Versatility, Armor, Strength -> stat1, Agility -> stat2, Intellect -> stat4,
     Stamina -> stamina, "Global Cooldown" -> gcd, an unknown label -> nothing).
  P  (G-018, V14 "off costs nothing") the option off (the default): building the Enhanced Tooltips page after a reload gives Improved
     Character Display no callback (its OnChange is not called) and the option's disabled state still follows Improved Character Display.
     Ticking the option gives the callback once; untick / tick again and another page build do not give it again. With the option on
     at login the callback is given at login, once, and the page build adds none. After the option is unticked the kept callback only
     notes the new value (the page's disabled state follows) and puts no lines on.
  L  (round 2 of the unit; the reviewer's regression) Improved Character Display switched live (its page's switch: saved value +
     ns.CharDisplay_Apply, no reload) while Character stats is unticked and no callback was given: switched off, the option is greyed
     and ticking it puts no lines on (no XayaUI block on a hover: lines only with both elements on); switched on, the option is not
     greyed and ticking it puts the lines on. Both directions after the page was built with the other value.
Every number and string is a TEST STAND-IN. FAILS on 5695993 (R: the pane is walked on every update; K: every hover reads the label
strings again; P: the page build with the option off subscribes). L passes on 5695993 (it subscribed at the page build) and failed
on round 1 of the unit.
Run: python3 tests/tooltips_charstats_gate_run.py [tree root]   (default: this repository)   Needs: pip install lupa."""
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
ROW = row
ROWS = { crit = row("Critical Strike:"), haste = row("Haste:"), mastery = row("Mastery:"), ilvl = row("Item Level:") }
-- a child of the pane that is not a stat row (a header, say): counts every look at its Label, which only a walk of the children makes
LABEL_LOOKS = 0
OTHER = setmetatable({}, { __index = function(_, k) if k == "Label" then LABEL_LOOKS = LABEL_LOOKS + 1 end return nil end })
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = { ROWS.crit, OTHER, ROWS.haste, ROWS.mastery, ROWS.ilvl }
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
__SAVED__
XayaUI_NS = ns
assert(loadfile(__TT__))("XayaUI_Bonus", ns); assert(loadfile(__TTUI__))("XayaUI_Bonus", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns); assert(loadfile(__CM__))("XayaUI_QoL", ns); assert(loadfile(__ICD__))("XayaUI_QoL", ns)
-- count every callback given to Improved Character Display's OnChange (before the login, so the login's own read is counted)
SUBS = 0; LISTENER = nil
local d = ns.Service("charDisplay")
if d and d.OnChange then
  local raw = d.OnChange
  d.OnChange = function(fn) SUBS = SUBS + 1; LISTENER = fn; return raw(fn) end
end
ns.FireReady(); ns.SettingsOpenAllForTests()
ns.FireLogin()
TT = ns.TT
function hover(r)
  GameTooltip:SetOwner(r)
  for _, f in ipairs(r.hooks.OnEnter or {}) do f(r) end
  return table.concat(GameTooltip.lines or {}, " / ")
end
function openWindow() CharacterFrame:Show(); PaperDollFrame:Show(); PaperDollFrame_UpdateStats() end
function setICD(v) XayaUIQoLDB.characterReskin.features = v; ns.SettingsChanged(); ns.CharDisplay_Apply() end
function page() local p = ns.BuildTooltipsTab(function() end); return p, p.args.charStats end
-- the game's label strings the stat rows are matched against: each read through _G counted
LABEL_GLOBALS = { "STAT_CRITICAL_STRIKE", "STAT_HASTE", "STAT_MASTERY", "STAT_VERSATILITY", "STAT_AVOIDANCE", "STAT_LIFESTEAL",
  "STAT_SPEED", "STAT_ARMOR", "STAT_DODGE", "STAT_PARRY", "STAT_BLOCK", "STAT_ATTACK_POWER", "WEAPON_SPEED", "STAT_ATTACK_SPEED",
  "DAMAGE", "STAT_STAGGER", "STAT_SPELLPOWER", "STAT_AVERAGE_ITEM_LEVEL", "SPELL_STAT1_NAME", "SPELL_STAT2_NAME", "SPELL_STAT3_NAME",
  "SPELL_STAT4_NAME" }
function countLabelReads()
  local hidden = {}
  for _, k in ipairs(LABEL_GLOBALS) do hidden[k] = rawget(_G, k); rawset(_G, k, nil) end
  LABEL_READS = 0
  local mt = getmetatable(_G) or {}
  local prev = mt.__index
  mt.__index = function(t, k)
    if hidden[k] ~= nil then LABEL_READS = LABEL_READS + 1; return hidden[k] end
    if type(prev) == "function" then return prev(t, k) elseif type(prev) == "table" then return prev[k] end
  end
  setmetatable(_G, mt)
end
'''

ICD_ON = 'XayaUIQoLDB = { storeVersion = 1, characterReskin = { features = true, statList = false, _merged = true } }'
ICD_OFF = 'XayaUIQoLDB = { storeVersion = 1, characterReskin = { features = false, statList = false, _merged = true } }'
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

# R: the pane's children walked only when their count changes
totals.append(run(ICD_ON + "\n" + TICKED + "\n", r'''
openWindow()
local s0 = hover(ROWS.crit)
checkp("R (positive control) the Critical Strike row shows the XayaUI block", function()
  return s0:find("Rating | 528", 1, true) ~= nil, s0 end)
local looks0 = LABEL_LOOKS
for i = 1, 20 do PaperDollFrame_UpdateStats() end
checkp("R 20 stat updates with the same rows: the pane's children are not walked again (no look at a child's Label)", function()
  return LABEL_LOOKS == looks0, "looks " .. looks0 .. " -> " .. LABEL_LOOKS end)
-- a new row appears (Blizzard's pool makes one more): the count changes, walked once, and the new row is hooked
local vers = ROW("Versatility:")
table.insert(CharacterStatsPane.children, vers)
PaperDollFrame_UpdateStats(); PaperDollFrame_UpdateStats(); PaperDollFrame_UpdateStats()
checkp("R a new row (the child count changed): one walk for three updates", function()
  return LABEL_LOOKS == looks0 + 1, "looks " .. looks0 .. " -> " .. LABEL_LOOKS end)
local sv = hover(vers)
checkp("R ...and the new Versatility row's hover shows the XayaUI block", function()
  return sv:find("XayaUI", 1, true) ~= nil and #(vers.hooks.OnEnter or {}) == 1, sv end)
checkp("R ...each row is hooked once (no second OnEnter hook on the old rows)", function()
  return #(ROWS.crit.hooks.OnEnter or {}) == 1 and #(ROWS.haste.hooks.OnEnter or {}) == 1, #(ROWS.crit.hooks.OnEnter or {}) end)
'''))

# K: the label strings are read once, not per hover; every row still finds its stat
totals.append(run(ICD_ON + "\n" + TICKED + "\n", r'''
countLabelReads()
openWindow()
hover(ROWS.crit)
local first = LABEL_READS
local s1, s2, s3
for i = 1, 5 do s1 = hover(ROWS.crit); s2 = hover(ROWS.haste); s3 = hover(ROWS.mastery) end
checkp("K (positive control) the first hover after a reload read the label strings", function() return first > 0, first end)
checkp("K 15 more hovers (Critical Strike, Haste, Mastery x5) read no label string again", function()
  return LABEL_READS == first, "reads " .. first .. " -> " .. LABEL_READS end)
checkp("K ...and the hovers still show their XayaUI blocks", function()
  return s1:find("Rating | 528", 1, true) ~= nil and s2:find("XayaUI", 1, true) ~= nil and s3:find("XayaUI", 1, true) ~= nil, s1 end)
local want = { ["Critical Strike:"] = "crit", ["Haste:"] = "haste", ["Mastery"] = "mastery", ["Versatility:"] = "vers",
  ["Armor:"] = "armor", ["|cffffffffStrength|r:"] = "stat1", ["Agility:"] = "stat2", ["  Intellect: "] = "stat4",
  ["Stamina:"] = "stamina", ["Item Level:"] = "ilvl", ["Global Cooldown:"] = "gcd", ["Nonsense:"] = false }
for label, key in pairs(want) do
  checkp("K the label '" .. label .. "' finds " .. tostring(key), function()
    local k = TT.CharStatKey(label)
    return (k or false) == key, tostring(k) end)
end
'''))

# P: the page build with the option off gives Improved Character Display no callback
totals.append(run(ICD_ON + "\n" + UNTICKED + "\n", r'''
checkp("P (setup) Improved Character Display's OnChange is counted", function() return ns.Service("charDisplay").OnChange ~= nil end)
local before = SUBS
local _, cs = page()
checkp("P option off: building the Enhanced Tooltips page gives Improved Character Display no callback", function()
  return SUBS == before, "OnChange called " .. (SUBS - before) .. " time(s)" end)
checkp("P ...the option's disabled state still follows Improved Character Display (on: not greyed)", function()
  return cs.args and TT.CharStatsDisplayOn() == true, tostring(TT.CharStatsDisplayOn()) end)
page()
checkp("P ...a second build gives none either", function() return SUBS == before, SUBS end)
TT.DB().charStats = true; TT.Sync()
checkp("P ticking the option gives the callback, once", function() return SUBS == before + 1, SUBS - before end)
TT.DB().charStats = nil; TT.Sync(); TT.DB().charStats = true; TT.Sync(); page()
checkp("P untick, tick again, another page build: still once", function() return SUBS == before + 1, SUBS - before end)
-- unticked again: the kept callback only notes the value
TT.DB().charStats = nil; TT.Sync()
openWindow()
if LISTENER then LISTENER(false) end
checkp("P unticked, Improved Character Display switched off: the page's disabled state follows (greyed)", function()
  return TT.CharStatsDisplayOn() == false end)
if LISTENER then LISTENER(true) end
local s = hover(ROWS.crit)
checkp("P ...switched on again with the option unticked: no XayaUI line on the stat rows", function()
  return TT.CharStatsDisplayOn() == true and TT.charStatsOn == false and not s:find("XayaUI", 1, true), s end)
'''))
totals.append(run(ICD_ON + "\n" + TICKED + "\n", r'''
checkp("P option on at login: the callback was given at login, once", function() return SUBS == 1, SUBS end)
page()
checkp("P ...the page's first build adds none", function() return SUBS == 1, SUBS end)
if LISTENER then LISTENER(false) end
checkp("P ...Improved Character Display switched off: the lines go off", function() return TT.charStatsOn == false end)
if LISTENER then LISTENER(true) end
openWindow()
local s = hover(ROWS.crit)
checkp("P ...and on again: the lines are back", function() return TT.charStatsOn == true and s:find("Rating | 528", 1, true) ~= nil, s end)
'''))
totals.append(run(ICD_OFF + "\n" + UNTICKED + "\n", r'''
local _, cs = page()
checkp("P Improved Character Display off, option off: the page build reads it as off (greyed) and gives no callback", function()
  return TT.CharStatsDisplayOn() == false and SUBS == 0 and cs.args.enabled.disabled() == true, SUBS end)
'''))

# L: Improved Character Display switched live while the option is unticked (no callback given yet)
totals.append(run(ICD_ON + "\n" + UNTICKED + "\n", r'''
local _, cs = page()
checkp("L (setup) page built with Improved Character Display on: not greyed, no callback", function()
  return cs.args.enabled.disabled() == false and TT.charStatsState.subscribed ~= true, tostring(cs.args.enabled.disabled()) end)
setICD(false)
checkp("L (setup) Improved Character Display is off now (its own service says so)", function() return ns.Service("charDisplay").On() == false end)
checkp("L switched off without a reload: the option is greyed and its note shows", function()
  return cs.args.enabled.disabled() == true and cs.args.note.hidden() == false, tostring(cs.args.enabled.disabled()) end)
-- the greyed toggle cannot be ticked from the page; ticking it anyway (a stale page) must still put no lines on
TT.DB().charStats = true; TT.Sync()
openWindow()
local s = hover(ROWS.crit)
checkp("L ...ticked anyway: the lines stay off (both elements must be on) and no XayaUI block on a hover", function()
  return TT.charStatsOn == false and not s:find("XayaUI", 1, true), tostring(TT.charStatsOn) .. " | " .. s end)
setICD(true)
local s2 = hover(ROWS.crit)
checkp("L ...Improved Character Display on again: the callback given at the tick puts the lines on", function()
  return TT.charStatsOn == true and s2:find("Rating | 528", 1, true) ~= nil, s2 end)
'''))
totals.append(run(ICD_OFF + "\n" + UNTICKED + "\n", r'''
local _, cs = page()
checkp("L (setup) page built with Improved Character Display off: greyed", function() return cs.args.enabled.disabled() == true end)
setICD(true)
checkp("L (setup) Improved Character Display is on now (its own service says so)", function() return ns.Service("charDisplay").On() == true end)
checkp("L switched on without a reload: the option is not greyed any more and the note is hidden", function()
  return cs.args.enabled.disabled() == false and cs.args.note.hidden() == true, tostring(cs.args.enabled.disabled()) end)
checkp("L ...still no callback given (the option is unticked)", function() return SUBS == 0 and TT.charStatsState.subscribed ~= true, SUBS end)
cs.args.enabled.set(nil, true)
openWindow()
local s = hover(ROWS.crit)
checkp("L ...ticking it puts the lines on and gives the callback once", function()
  return TT.charStatsOn == true and SUBS == 1 and s:find("Rating | 528", 1, true) ~= nil, SUBS .. " | " .. s end)
setICD(false)
checkp("L ...and Improved Character Display off again: the lines go off (told by the callback)", function() return TT.charStatsOn == false end)
'''))

# Q: the walkthrough (XayaUI_DevAssist/QAWalks-tooltips-charstats.lua, id "tooltips-charstats-gate") on the stand-in: each check gives the verdict it should
WALK = r"""
WALKS = {}
XayaUI_DevQA = { Register = function(id, w) WALKS[id] = w end }
PaperDollFrame.IsVisible = function(self) return self.shown end
local okL, errL = pcall(function() assert(loadfile(__WALK__))("XayaUI_DevAssist", {}) end)
W = WALKS["tooltips-charstats-gate"]
checkp("Q the walkthrough loads and registers with prefill = true", function() return okL and W ~= nil and W.prefill == true, tostring(errL) end)
st = W and W.steps or {}
"""
totals.append(run(ICD_ON + "\n" + UNTICKED + "\n", (WALK + r"""
local v0, n0 = st[1].check()
checkp("Q step 1 before the page was built: no verdict, it asks to open the page", function() return v0 == nil and n0:find("open /xui", 1, true) ~= nil, n0 end)
page()
local v1, n1 = st[1].check()
checkp("Q step 1 after the page build with the option unticked: pass, 'callback given no'", function()
  return v1 == true and n1:find("callback given no", 1, true) ~= nil, n1 end)
TT.charStatsState.subscribed = true
local v1b = st[1].check()
checkp("Q step 1 when a callback was given (the old page build): fail", function() return v1b == false end)
TT.charStatsState.subscribed = false
local v2a, n2a = st[2].check()
checkp("Q step 2 before Improved Character Display is unticked: no verdict, it asks for that", function()
  return v2a == nil and n2a:find("untick Improved Character Display", 1, true) ~= nil, n2a end)
setICD(false)
local v2, n2 = st[2].check()
checkp("Q step 2 Improved Character Display unticked live: pass, read as off", function()
  return v2 == true and n2:find("read as off", 1, true) ~= nil, n2 end)
setICD(true)
local v3, n3 = st[3].check()
checkp("Q step 3 ticked again live: pass, read as on, callback given no", function()
  return v3 == true and n3:find("read as on", 1, true) ~= nil and n3:find("callback given no", 1, true) ~= nil, n3 end)
local v4a, n4a = st[4].check()
checkp("Q step 4 still unticked: no verdict", function() return v4a == nil, n4a end)
TT.DB().charStats = true; TT.Sync()
local v4, n4 = st[4].check()
checkp("Q step 4 ticked: pass, 'callback given yes', lines on", function()
  return v4 == true and n4:find("callback given yes", 1, true) ~= nil and n4:find("lines on", 1, true) ~= nil, n4 end)
openWindow(); hover(ROWS.crit)
local v5a, n5a = st[5].check()
checkp("Q step 5 before its Do it for me: no verdict", function() return v5a == nil and n5a:find("Do it for me", 1, true) ~= nil, n5a end)
st[5].setup()
for i = 1, 3 do hover(ROWS.crit); hover(ROWS.haste); hover(ROWS.mastery); PaperDollFrame_UpdateStats() end
local v5, n5 = st[5].check()
checkp("Q step 5 after hovers and stat updates with the same rows: pass, '+0' label work", function()
  return v5 == true and n5:find("label strings made plain +0", 1, true) ~= nil, n5 end)
TT.charStatsState.labelPlains = TT.charStatsState.labelPlains + 22
local v5b = st[5].check()
checkp("Q step 5 when the labels were made plain again (the old per-hover work): fail", function() return v5b == false end)
checkp("Q step 6 asks her (noVerdict); step 7 is the done step", function() return st[6].noVerdict == true and st[7].done == true end)
""").replace("__WALK__", P("XayaUI_DevAssist/QAWalks-tooltips-charstats.lua"))))

n = sum(t[0] for t in totals); fails = sum(t[1] for t in totals)
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
