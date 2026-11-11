# Gate test for Character Reskin (XayaUI_QoL/CharacterReskin.lua), V27 release-gate findings of unit U4-character-reskin:
#   G-009 (Xaya's V27 reading "Whole-pixel / no float math": positions and sizes set in whole pixels): with the wider window on, Extra
#         height spreads the slot columns in whole pixels; 20 px gives the 7 gaps of each column 3, 3, 3, 3, 3, 3, 2 (sum 20) instead of
#         2.857 each; ns.CharReskin_TallGap answers a whole number; the /xui reskin status line prints whole pixels.
#   G-021 (V27 "No running loops" / V28 spirit): the lasting PaperDollItemSlotButton_Update and PaperDollFrame_UpdateStats hooks test
#         whether the character window is shown first, and never run Cfg()'s normalising loop per redraw (the look's answer is worked
#         out once in ns.CharReskin_Apply). Measured by counting ns.SettingsReady / ns.SwitchInEffect calls (Cfg() and On() make them).
#   Round 2 (review): a saved fraction of a pixel is rounded before the off test (0.3 is off, 0.6 is 1 px); the cached answer
#         follows a profile switch without an Apply (new table, new epoch: one recompute, then none) and is forgotten after a Guard error.
# What it checks is what the player sees (each slot's place, from its anchors: tests/char_pane_geometry.lua) and what runs.
# Negative control (V31 step 3): every check not marked "(guard)" FAILS on the pre-change files (base commit 5695993) and passes after.
# Run from the repo root: python3 tests/char_reskin_gate_run.py [tree root]   (default: this repo). Needs: pip install lupa.
# Every number is a TEST STAND-IN except Blizzard's 4 px slot gap (PaperDollFrame.xml).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
TREE = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(HERE, "..")
def P(rel, root=None): return "'" + os.path.join(root or TREE, rel).replace("\\", "/") + "'"

SRC = r'''
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
CM = ns.StatModel
placePane(540)
blizzardSizing()
function PaperDollItemSlotButton_Update(btn) end
function PaperDollFrame_UpdateStats() end
function PanelTemplates_SetTab(frame, id) frame.selectedTab = id end
ENCHANTED_TOOLTIP_LINE = "Enchanted: %s"
ns.Theme = { listeners = {}, cur = { accent = { 0.64, 0.19, 0.79, 1 } } }
function ns.Theme.Col(class, prop, fb) return fb and { fb[1], fb[2], fb[3], fb[4] or 1 } or { 1, 1, 1, 1 } end
function ns.Theme.OnResolve(fn) table.insert(ns.Theme.listeners, fn) end
function ns.Theme.OffResolve(fn) end
GEAR, ITEMS, TIP, UPG = {}, {}, {}, {}
GetInventoryItemLink = function(_, slot) return GEAR[slot] end
C_TooltipInfo.GetInventoryItem = function(_, slot) return { lines = TIP[slot] or {} } end
C_Timer.After = function(d, fn) fn() end
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
CharacterStatsPane.pts = { { "TOPLEFT", CharacterFrame.InsetRight, "TOPLEFT", 3, -3 }, { "BOTTOMRIGHT", CharacterFrame.InsetRight, "BOTTOMRIGHT", -3, 3 } }
CharacterStatsPane.shown = true
CueRulesDB.characterReskin = { enabled = true }
assert(loadfile(__ICD__))("XayaUI_QoL", ns); assert(loadfile(__CT__))("XayaUI_Bonus", ns)
assert(loadfile(__RS__))("XayaUI_QoL", ns)
ns.FireReady(); ns.SettingsDeclareStore("reskin", "XayaUI_Reskin", "XayaUIReskinDB"); ns.SettingsOpenAllForTests()
local rc = ns.CharReskin_Cfg()
rc.enabled = true
CharacterFrame:Show(); PaperDollFrame:Show(); ns.CharReskin_Apply()
local LEFT, RIGHT = PANE_SLOTS_LEFT, PANE_SLOTS_RIGHT
local function whole(x) return type(x) == "number" and x == math.floor(x) end

-- ===== G-009: Extra height in whole pixels =====================================================================================
checkp("(guard) the look is on and Extra height starts at 0 (Blizzard's 4 px gaps)", function()
  return ns.CharReskin_Active() == true and rc.tallPx == 0 and (RECT(CharacterHeadSlot).b - RECT(CharacterNeckSlot).t) == 4 end)
local base = {}
for _, n in ipairs(LEFT) do local p = _G["Character" .. n].pts; base[n] = p[#p][5] end
for _, n in ipairs(RIGHT) do local p = _G["Character" .. n].pts; base[n] = p[#p][5] end
rc.tallPx = 20; ns.CharReskin_Apply()
local function extras(list)   -- what Extra height added to each slot's own y offset (slots 2-8 of a column)
  local out = {}
  for i = 2, #list do local p = _G["Character" .. list[i]].pts; out[#out + 1] = base[list[i]] - p[#p][5] end
  return out
end
local function sum(t) local s = 0; for _, v in ipairs(t) do s = s + v end; return s end
local function allWhole(t) for _, v in ipairs(t) do if not whole(v) then return false end end; return #t > 0 end
checkp("(guard) Extra height 20 applies: the window is 20 taller (424 -> 444)", function() return CharacterFrame.h == 444, CharacterFrame.h end)
checkp("Extra height 20: every slot's SetPoint y offset is a whole pixel (left and right columns)", function()
  for _, list in ipairs({ LEFT, RIGHT }) do
    for i = 2, #list do local p = _G["Character" .. list[i]].pts; if not whole(p[#p][5]) then return false, list[i] .. " y " .. tostring(p[#p][5]) end end
  end
  return true end)
checkp("  ...the 7 added gaps of each column are whole pixels that add up to 20 exactly (3,3,3,3,3,3,2)", function()
  local l, r = extras(LEFT), extras(RIGHT)
  return allWhole(l) and allWhole(r) and sum(l) == 20 and sum(r) == 20 and table.concat(l, ",") == "3,3,3,3,3,3,2"
    and table.concat(r, ",") == "3,3,3,3,3,3,2", table.concat(l, ",") .. " | " .. table.concat(r, ",") end)
checkp("  ...each gap the player sees between two slots is 4 + 2 or 4 + 3 px (whole pixels)", function()
  for i = 2, #LEFT do
    local g = RECT(_G["Character" .. LEFT[i - 1]]).b - RECT(_G["Character" .. LEFT[i]]).t
    if not (math.abs(g - 6) < 0.001 or math.abs(g - 7) < 0.001) then return false, LEFT[i] .. " gap " .. g end
  end
  return true end)
checkp("  ...ns.CharReskin_TallGap answers a whole number (the gap every pair of slots has at least: 2)", function()
  return ns.CharReskin_TallGap() == 2, tostring(ns.CharReskin_TallGap()) end)
checkp("  .../xui reskin status prints whole pixels (no '2.9 px')", function()
  printed = {}; ns.RunCommand("reskin", "status")
  local line
  for _, l in ipairs(printed) do if l:find("Extra height:", 1, true) then line = l end end
  return line ~= nil and not line:find("%d%.%d") and line:find("2 px wider", 1, true) ~= nil, tostring(line) end)
for _, px in ipairs({ 1, 6, 7, 13, 299, 300 }) do
  rc.tallPx = px; ns.CharReskin_Apply()
  checkp(((px % 7 == 0) and "(guard) " or "") .. ("Extra height %d: whole-pixel gaps that add up to %d in both columns"):format(px, px), function()
    local l, r = extras(LEFT), extras(RIGHT)
    return allWhole(l) and allWhole(r) and sum(l) == px and sum(r) == px and CharacterFrame.h == 424 + px,
      table.concat(l, ",") .. " h=" .. CharacterFrame.h end)
end
rc.tallPx = 70; ns.CharReskin_Apply()
checkp("(guard) Extra height 70 (a multiple of 7): every gap 10 more, TallGap 10, as before", function()
  return table.concat(extras(LEFT), ",") == "10,10,10,10,10,10,10" and ns.CharReskin_TallGap() == 10 end)
-- (round 2) a saved fraction is rounded BEFORE the off test: 0.3 (from an import or a typed value) is off, not "on, 0 px taller"
rc.tallPx = 0.3; ns.CharReskin_Apply()
checkp("Extra height 0.3 (rounds to 0): off, Blizzard's layout, and the status line does not claim 'on, 0 px taller'", function()
  for n, y in pairs(base) do local p = _G["Character" .. n].pts; if p[#p][5] ~= y then return false, n end end
  local d = tostring(ns.CharReskinDiag.tall)
  return CharacterFrame.h == 424 and ns.CharReskin_TallGap() == 0 and not d:find("on,", 1, true), d .. " h=" .. CharacterFrame.h end)
rc.tallPx = 0.6; ns.CharReskin_Apply()
checkp("Extra height 0.6 rounds to 1: one whole pixel (the top gap of each column), the window 425", function()
  return table.concat(extras(LEFT), ",") == "1,0,0,0,0,0,0" and CharacterFrame.h == 425, table.concat(extras(LEFT), ",") .. " h=" .. CharacterFrame.h end)
rc.tallPx = 0; ns.CharReskin_Apply()
checkp("(guard) back to 0: every slot's own anchor back (Blizzard's layout), the window 424", function()
  for n, y in pairs(base) do local p = _G["Character" .. n].pts; if p[#p][5] ~= y then return false, n end end
  return CharacterFrame.h == 424 end)

-- ===== G-021: the redraw hooks do no settings work per call ====================================================================
local reads = 0
local SR, SIE = ns.SettingsReady, ns.SwitchInEffect
ns.SettingsReady = function(...) reads = reads + 1; return SR(...) end
ns.SwitchInEffect = function(...) reads = reads + 1; return SIE(...) end
CharacterFrame:Hide()
local art = CharacterHeadSlotFrame
CharacterHeadSlotFrame = mk("Texture"); CharacterHeadSlotFrame.alpha = 1
CharacterHeadSlotFrame.SetAlpha = function(self, a) self.alpha = a end; CharacterHeadSlotFrame.GetAlpha = function(self) return self.alpha end
reads = 0
for _ = 1, 19 do PaperDollItemSlotButton_Update(CharacterHeadSlot) end
PaperDollFrame_UpdateStats()
checkp("window closed: 19 slot redraws and a stats update run no settings read (Cfg() / On() not called)", function() return reads == 0, reads .. " reads" end)
checkp("(guard)   ...and touch nothing (the slot art keeps its alpha)", function() return CharacterHeadSlotFrame.alpha == 1 end)
CharacterFrame:Show()
reads = 0
for _ = 1, 19 do PaperDollItemSlotButton_Update(CharacterHeadSlot) end
for _ = 1, 5 do PaperDollFrame_UpdateStats() end
checkp("window open: slot redraws and stats updates reuse the look's answer worked out at Apply (no settings read per call)", function()
  return reads == 0, reads .. " reads" end)
checkp("(guard)   ...and still do their work (the redrawn slot's frame art faded)", function() return CharacterHeadSlotFrame.alpha == 0, CharacterHeadSlotFrame.alpha end)
ns.SettingsReady, ns.SwitchInEffect = SR, SIE
CharacterHeadSlotFrame = art
-- a settings change goes through ns.CharReskin_Apply (every page setter does): the hooks follow it
rc.chrome = false; ns.CharReskin_Apply()
local art2 = mk("Texture"); art2.alpha = 1; art2.SetAlpha = function(self, a) self.alpha = a end; art2.GetAlpha = function(self) return self.alpha end
CharacterHeadSlotFrame = art2
PaperDollItemSlotButton_Update(CharacterHeadSlot)
checkp("(guard) 'Clean window' unticked (through Apply): the slot hook leaves the art alone", function() return art2.alpha == 1, art2.alpha end)
rc.chrome = true; ns.CharReskin_Apply()
PaperDollItemSlotButton_Update(CharacterHeadSlot)
checkp("(guard) ticked again: the slot hook fades it", function() return art2.alpha == 0, art2.alpha end)
rc.enabled = false; ns.CharReskin_Apply()
art2.alpha = 1
PaperDollItemSlotButton_Update(CharacterHeadSlot)
checkp("(guard) the look off (through Apply): the hook does nothing", function() return art2.alpha == 1, art2.alpha end)

-- (round 2) the cache follows what changes without an Apply
local function newArt() local t = mk("Texture"); t.alpha = 1; t.SetAlpha = function(self, a) self.alpha = a end; t.GetAlpha = function(self) return self.alpha end; return t end
rc.enabled = true; ns.CharReskin_Apply()
art2 = newArt(); CharacterHeadSlotFrame = art2   -- (a fresh texture: Apply's own pass already faded the old one)
PaperDollItemSlotButton_Update(CharacterHeadSlot)
checkp("(guard) the look back on (through Apply): the slot hook fades the art again", function() return art2.alpha == 0, art2.alpha end)
-- a profile switch: the store's table is replaced and the settings epoch moves on, and no ns.CharReskin_Apply runs
local rsv = ns.Settings("reskin")
local prof = {}; for k, v in pairs(rc) do prof[k] = v end; prof.chrome = false
rsv.characterReskin = prof; ns.SettingsChanged()
local r0 = ns.CharReskinDiag.lookReads or 0
art2 = newArt(); CharacterHeadSlotFrame = art2
for _ = 1, 19 do PaperDollItemSlotButton_Update(CharacterHeadSlot) end
checkp("(guard) profile switch without an Apply (new settings table, new epoch): the hook reads the new profile ('Clean window' off: art left alone)", function()
  return art2.alpha == 1 and ns.CharReskin_Cfg() == prof, art2.alpha end)
checkp("  ...and works the answer out once for the new epoch, not per redraw (19 redraws: 1 recompute)", function()
  return (ns.CharReskinDiag.lookReads or 0) - r0 == 1, ((ns.CharReskinDiag.lookReads or 0) - r0) .. " recomputes" end)
prof.chrome = true; ns.CharReskin_Apply()
art2 = newArt(); CharacterHeadSlotFrame = art2
PaperDollItemSlotButton_Update(CharacterHeadSlot)
checkp("(guard) 'Clean window' on in the new profile (through Apply): the hook fades the art", function() return art2.alpha == 0, art2.alpha end)
-- a Guard error forgets the cached answer: the look is off until /reload, so a later redraw does nothing
local bad = mk("Texture"); bad.alpha = 1
bad.SetAlpha = function() error("test: SetAlpha failed") end; bad.GetAlpha = function(self) return self.alpha end
CharacterHeadSlotFrame = bad
local quiet = ns.Print; ns.Print = function() end
PaperDollItemSlotButton_Update(CharacterHeadSlot)
ns.Print = quiet
checkp("(guard) a slot redraw that errors: Guard turns the look off (diag.failed)", function() return ns.CharReskinDiag.failed == true and ns.CharReskin_Active() == false end)
local art3 = newArt()
CharacterHeadSlotFrame = art3
PaperDollItemSlotButton_Update(CharacterHeadSlot)
checkp("(guard)   ...and the cached answer is forgotten: the next redraw (no Apply in between) leaves the art alone", function() return art3.alpha == 1, art3.alpha end)
CharacterHeadSlotFrame = art
'''

def run():
    lua = LuaRuntime()
    src = SRC.replace("__WORLD__", P("tests/char_world.lua", os.path.join(HERE, ".."))).replace("__GEOM__", P("tests/char_pane_geometry.lua", os.path.join(HERE, ".."))) \
        .replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua")) \
        .replace("__CM__", P("XayaUI_QoL/StatModel.lua")).replace("__CT__", P("XayaUI_Bonus/StatCalculator.lua")).replace("__ICD__", P("XayaUI_QoL/ImprovedCharacterDisplay.lua")) \
        .replace("__RS__", P("XayaUI_QoL/CharacterReskin.lua"))
    lua.execute(src)
    return lua.eval("n"), lua.eval("fails")

n, fails = run()
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
