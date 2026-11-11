#!/usr/bin/env python3
"""Stat Calculator fixes of 2026-11-10 (XayaUI Bonus Features, XayaUI_Bonus/StatCalculator.lua; docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md).
On the stand-in character window (tests/char_world.lua) with the real Stat Calculator, the real stat model (XayaUI_QoL/StatModel.lua) and
Improved Character Display's Stat Calc button (XayaUI_QoL/ImprovedCharacterDisplay.lua). What the player sees or gets:
  F1  SC-002 / SC-019: a Change box has the keyboard when combat starts (PLAYER_REGEN_DISABLED): it lets go (HasFocus false), whatever
      core's KeyFocusGuard does (core's KeyCatch.lua is not loaded here, and the stand-in panel's hide does not hide its children).
  F2  SC-001 / SC-045 (V26 "Hide silently"): in combat ns.StatCalc_Render, every input (SetInput, PickItem, SelectGearSlot,
      SetCompareSlot, Action, SizeMode, ToggleStat, ToggleSpell, SetSpellFilter) and the statCalc service's wrappers build no stat model,
      draw nothing, change no saved number and say nothing; the build count Dev Assist reads (statCalcDebug.Builds) stays the same; the
      character window still opens. After combat a typed number works again.
  F3  SC-081: with the panel closed SPELL_UPDATE_COOLDOWN is not registered and a cast reads no GCD; the panel shown: registered, and
      opening read the GCD once; in combat: not registered; at the end of combat exactly one GCD read when the panel comes back (its
      own show reads it; round 2: no second read at PLAYER_REGEN_ENABLED), none when the panel stays closed.
  F4  SC-020 (with SC-085 / SC-049, event side): on the Gear tab an item looted into the bags shows after BAG_UPDATE_DELAYED (the model's
      CM.ForgetOwned is called when it has one); GET_ITEM_INFO_RECEIVED for an item the panel does not show causes no redraw, for an
      equipped item it does; PLAYER_TARGET_CHANGED on the Ability Scaling tab (its model reads no target) causes no redraw, on Stats it
      does; TRAIT_CONFIG_UPDATED / PLAYER_TALENT_UPDATE are listened to only while Ability Scaling is shown and clear the talent scan.
  F5  SC-050 (tie-in side): the Stat Calculator page's first build after a reload asks the model to read its tie-ins (CM.ReadTieIns(true),
      a stand-in here); later builds do not.
  F6  SC-102 (round 2): at the default panel width (450) and the default text (11, and 10) the Stat Weights head has six column titles,
      the last "Influences", and every row's influences sit in that column on the row itself, inside the panel, without "Influences: "
      in front (under the row, where there is no title, the line keeps its "Influences: " label). At 450 and every text size 10-14 every column title is on one line (the kept #60 rule, tests/char_stat_round_run.py);
      where six one-line titles do not fit (text 12-14 in this world's measure) the influences go under their row instead (from one
      indent in, x 12, to the right edge). No word cut, no overlap among the pane's cells (V11).
  F7  SC-085 / SC-049 (round 2): the bag and talent events are heard only while their tab is shown, so a change made while the panel
      is on another tab, closed, or hidden by combat is read when the tab is next drawn: the Gear tab's bag list after the bags changed
      on Stats, and after the panel was closed; the talent scan is read again (CM.ClearTalents) on the first Ability Scaling draw after
      another tab, and not again on later draws while it stays shown.
Run against a tree: XUI_ROOT=<a copy of the repository> python3 tests/char_statcalc_fixes_run.py (the stand-in world is always this
checkout's tests/char_world.lua). Negative control: XUI_ROOT=<the tree at f34cc33> fails F1-F6 (see the debug log for the count).
Every number is a TEST STAND-IN. In-game behavior is UNVERIFIED IN GAME.
Run from the repo root: python3 tests/char_statcalc_fixes_run.py   Needs: pip install lupa."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.environ.get("XUI_ROOT") or os.path.join(HERE, "..")


def P(rel, root=None):
    return "'" + os.path.join(root or ROOT, rel).replace("\\", "/") + "'"


SRC = r'''
assert(loadfile(__WORLD__))()
-- extra stand-ins (this test's own; the shared world stays as it is): keyboard focus and IsEventRegistered on every frame made
local rawCF = CreateFrame
CreateFrame = function(...)
  local f = rawCF(...)
  f.SetFocus = function(self) self.focus = true end
  f.ClearFocus = function(self) self.focus = false end
  f.IsEventRegistered = function(self, e) return self.events[e] == true end
  return f
end
-- the bags (C_Container, namespaces.md:1291): one ring in bag 0 at first; LOOT() puts a second one in
BAG = { "|cffa335ee|Hitem:5::::::::90:::::|h[New Ring]|h|r" }
ITEMS["New Ring"] = { ilvl = 345, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_CRIT_RATING_SHORT = 300, ITEM_MOD_HASTE_RATING_SHORT = 150 } }
ITEMS["Loot Ring"] = { ilvl = 350, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_CRIT_RATING_SHORT = 310 } }
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end,
  GetContainerItemInfo = function(bag, i) local l = bag == 0 and BAG[i]; if l then return { hyperlink = l, quality = 4, iconFileID = 1 } end end }
function LOOT() BAG[#BAG + 1] = "|cffa335ee|Hitem:77::::::::90:::::|h[Loot Ring]|h|r" end
CharacterFrame = mk("Frame"); CharacterFrame.h = 600; PaperDollFrame = mk("Frame")
CharacterStatsPane = mk("Frame"); CharacterStatsPane.children = {}
assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__ICD__))("XayaUI_QoL", ns); assert(loadfile(__CT__))("XayaUI_Bonus", ns)
ns.FireReady(); ns.SettingsOpenAllForTests()
local CM = ns.StatModel
-- (F5) a stand-in for the model's tie-in read (unit B adds the real one); installed before any page build
local tieReads, tieArgs = 0, {}
CM.ReadTieIns = function(again) tieReads = tieReads + 1; tieArgs[#tieArgs + 1] = again end
local builds, renders, gcdReads, talentClears, forgets = 0, 0, 0, 0, 0
local rawBuild, rawGCD, rawClear = CM.Build, CM.ReadGCD, CM.ClearTalents
CM.Build = function(...) builds = builds + 1; return rawBuild(...) end
CM.ReadGCD = function(...) gcdReads = gcdReads + 1; return rawGCD(...) end
CM.ClearTalents = function(...) talentClears = talentClears + 1; return rawClear(...) end
local rawRender = ns.StatCalc_Render
ns.StatCalc_Render = function(...) renders = renders + 1; return rawRender(...) end
local function checkp(name, fn)
  local ok, cond, extra = pcall(fn)
  if not ok then check(name, false, "error: " .. tostring(cond)) else check(name, cond and true or false, extra) end
end
local function panel() return _G.XayaUIStatCalculator end
local function panelShown() local p = panel(); return p ~= nil and p:IsShown() end
local function evFrame() for _, f in ipairs(created) do if f.scripts.OnEvent and f.events.COMBAT_RATING_UPDATE then return f end end end
local function registered(e) for _, f in ipairs(created) do if f.events and f.events[e] then return true end end; return false end
local function enterCombat() fire("PLAYER_REGEN_DISABLED"); combat = true end   -- (the game: the event first, then the lockdown)
local function leaveCombat() combat = false; fire("PLAYER_REGEN_ENABLED") end
local function openWindow() CharacterFrame:Show(); PaperDollFrame:Show() end
local function closeWindow() PaperDollFrame:Hide(); CharacterFrame:Hide() end
local function drawn() return ns.StatCalc_Drawn() end
local function recs(d, kind) local out = {}; for _, r in ipairs(d and d.layout or {}) do if r.kind == kind then out[#out + 1] = r end end; return out end

local c = CWC()
c.enabled = true
CWA()
openWindow()
checkp("setup: the panel docks beside the open character window", function() return panelShown() end)
c.tab = "stats"; ns.StatCalc_Render()

-- F1 (SC-002 / SC-019) -------------------------------------------------------------------------------------------------------
local box = drawn().boxes["sv:crit"]
checkp("F1 setup: the Critical Strike Change box is drawn and the player clicks into it (it has the keyboard)", function()
  if not box then return false, "no box" end
  box:SetFocus(); return box:HasFocus() end)
local p0 = #printed
enterCombat()
checkp("F1 combat starts with a Change box focused: the box lets go of the keyboard (HasFocus false)", function() return box and not box:HasFocus() end)
checkp("  ...and the panel is hidden, with no message", function() return not panelShown() and #printed == p0, printed[#printed] end)

-- F2 (SC-001 / SC-045) -------------------------------------------------------------------------------------------------------
local dbg = ns.Service("statCalcDebug")
local sc = ns.Service("statCalc")
local b0, r0, layout0 = builds, 0, drawn().layout
local saved0 = { crit = c.whatIfStats.crit, size = c.sizeMode, filter = c.spellFilter, tab = c.tab, statOpen = c.statOpen.crit, slot = CM.gearSlot,
  cmp = #(CM.compareLinks or {}) }
local dbgBuilds0 = dbg and dbg.Builds and dbg.Builds()
local function noWork(what, fn)
  local bb = builds
  local ok, err = pcall(fn)
  checkp("F2 in combat: " .. what .. " builds no stat model and draws nothing", function()
    return ok and builds == bb and drawn().layout == layout0 and not panelShown(), err or (builds - bb) end)
end
noWork("ns.StatCalc_Render", function() ns.StatCalc_Render() end)
noWork("a typed number (SetInput)", function() ns.StatCalc_SetInput("crit", "500") end)
noWork("a typed item (SetInput item)", function() ns.StatCalc_SetInput("item", "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r") end)
noWork("a picked bag item (PickItem)", function() ns.StatCalc_PickItem("|cffa335ee|Hitem:5::::::::90:::::|h[New Ring]|h|r", 11) end)
noWork("a clicked equipped item (SelectGearSlot)", function() ns.StatCalc_SelectGearSlot(11) end)
noWork("Replace instead (SetCompareSlot)", function() ns.StatCalc_SetCompareSlot(12) end)
noWork("Refresh spell data (Action)", function() ns.StatCalc_Action("refreshSpells") end)
noWork("the Min / Max button (SizeMode)", function() ns.StatCalc_SizeMode() end)
noWork("a stat's fold (ToggleStat)", function() ns.StatCalc_ToggleStat("crit") end)
noWork("a spell's fold (ToggleSpell)", function() ns.StatCalc_ToggleSpell("spell:1") end)
noWork("the spell filter (SetSpellFilter)", function() ns.StatCalc_SetSpellFilter("defense") end)
noWork("the statCalc service's SetInput / ToggleStat / SelectGearSlot / PickItem", function()
  sc.SetInput("haste", "300"); sc.ToggleStat("haste"); sc.SelectGearSlot(1); sc.PickItem("|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r", 1) end)
checkp("F2 ...and nothing it keeps changed: typed numbers, size mode, filter, folds, the compared slot and items", function()
  return c.whatIfStats.crit == saved0.crit and c.whatIfStats.haste == nil and c.sizeMode == saved0.size and c.spellFilter == saved0.filter
    and c.statOpen.crit == saved0.statOpen and c.statOpen.haste == nil and not (c.collapsed or {})["spell:1"] and CM.gearSlot == saved0.slot
    and #(CM.compareLinks or {}) == saved0.cmp,
    ("crit %s haste %s size %s filter %s slot %s compared %d"):format(tostring(c.whatIfStats.crit), tostring(c.whatIfStats.haste), tostring(c.sizeMode),
      tostring(c.spellFilter), tostring(CM.gearSlot), #(CM.compareLinks or {})) end)
checkp("F2 ...and said nothing", function() return #printed == p0, printed[#printed] end)
checkp("F2 the build count Dev Assist reads (statCalcDebug.Builds) did not move in combat", function()
  return dbgBuilds0 ~= nil and dbg.Builds() == dbgBuilds0, tostring(dbgBuilds0) end)
closeWindow(); openWindow()
checkp("F2 the character window still opens in combat; the panel stays hidden and nothing is built", function()
  return CharacterFrame:IsShown() and PaperDollFrame:IsShown() and not panelShown() and builds == b0, builds - b0 end)
-- F3 in combat
checkp("F3 in combat: SPELL_UPDATE_COOLDOWN is not registered", function() return not registered("SPELL_UPDATE_COOLDOWN") end)
local g0 = gcdReads
leaveCombat()
checkp("F2 after combat the panel is back and drawn (a model is built again)", function() return panelShown() and builds > b0, builds - b0 end)
checkp("F3 the end of combat with the panel coming back reads the GCD exactly once (the panel's own show; no second read)", function() return gcdReads == g0 + 1, gcdReads - g0 end)
ns.StatCalc_SetInput("sv:crit", "600")
checkp("F2 after combat a typed number works again (Critical Strike's box: 600 - 528 = +72)", function() return c.whatIfStats.crit == 72, c.whatIfStats.crit end)
ns.StatCalc_SetInput("sv:crit", "")

-- F3 (SC-081) ----------------------------------------------------------------------------------------------------------------------
checkp("F3 the panel shown: SPELL_UPDATE_COOLDOWN is registered", function() return registered("SPELL_UPDATE_COOLDOWN") end)
ns.StatCalc_SetOpen(false)
checkp("F3 the panel closed (its part still on): SPELL_UPDATE_COOLDOWN is not registered; the stat events are", function()
  return not registered("SPELL_UPDATE_COOLDOWN") and registered("UNIT_STATS") and registered("PLAYER_REGEN_DISABLED") end)
g0 = gcdReads
local bb = builds
fire("SPELL_UPDATE_COOLDOWN"); fire("SPELL_UPDATE_COOLDOWN"); fire("SPELL_UPDATE_COOLDOWN")
checkp("F3 ...three casts with the panel closed: no GCD read and no model built", function() return gcdReads == g0 and builds == bb, (gcdReads - g0) .. " " .. (builds - bb) end)
enterCombat(); leaveCombat()
checkp("F3 ...a fight with the panel closed: its end reads no GCD (the next open reads it)", function() return gcdReads == g0 and not panelShown(), gcdReads - g0 end)
ns.StatCalc_SetOpen(true)
checkp("F3 opened again: registered, and opening read the GCD once", function() return registered("SPELL_UPDATE_COOLDOWN") and gcdReads == g0 + 1, gcdReads - g0 end)

-- F4 (SC-020, SC-085 / SC-049 event side) ------------------------------------------------------------------------------------------
c.tab = "gear"; ns.StatCalc_Render()
ns.StatCalc_SelectGearSlot(11)
local function bagIcons()
  local out = {}
  for _, ic in ipairs(drawn().icons) do if ic:IsShown() and ic.cand then out[#out + 1] = tostring(ic.link):match("%[(.-)%]") end end
  table.sort(out); return table.concat(out, ",")
end
checkp("F4 setup: Gear, the ring slot picked: the bag's rings are listed (New Ring)", function() return bagIcons() == "New Ring", bagIcons() end)
checkp("F4 BAG_UPDATE_DELAYED is listened to while Gear is shown", function() return registered("BAG_UPDATE_DELAYED") end)
local realForget = CM.ForgetOwned   -- (the model's own, once unit B's cache lands; a counting stand-in until then)
CM.ForgetOwned = function(...) forgets = forgets + 1; if realForget then return realForget(...) end end
LOOT()
fire("BAG_UPDATE_DELAYED")
checkp("F4 a ring looted while Gear is open shows after BAG_UPDATE_DELAYED (Loot Ring, New Ring)", function() return bagIcons() == "Loot Ring,New Ring", bagIcons() end)
checkp("  ...the model is told to read the bags again (CM.ForgetOwned)", function() return forgets == 1, forgets end)
local rr = renders
fire("GET_ITEM_INFO_RECEIVED", 987654, true)
checkp("F4 GET_ITEM_INFO_RECEIVED for an item the panel does not show (987654, the Auction House): no redraw", function() return renders == rr, renders - rr end)
fire("GET_ITEM_INFO_RECEIVED", 77, true)
checkp("  ...for a bag item the Gear tab shows (77, Loot Ring): it redraws", function() return renders == rr + 1, renders - rr end)
rr = renders
fire("GET_ITEM_INFO_RECEIVED", 1, true)
checkp("  ...for an equipped item (1, Helm): it redraws", function() return renders == rr + 1, renders - rr end)
ns.StatCalc_SelectGearSlot(11)   -- (let the slot go)
c.tab = "spells"; ns.StatCalc_Render()
checkp("F4 Ability Scaling shown: TRAIT_CONFIG_UPDATED and PLAYER_TALENT_UPDATE are listened to, BAG_UPDATE_DELAYED is not", function()
  return registered("TRAIT_CONFIG_UPDATED") and registered("PLAYER_TALENT_UPDATE") and not registered("BAG_UPDATE_DELAYED") end)
rr = renders
local bb2 = builds
fire("PLAYER_TARGET_CHANGED")
checkp("F4 PLAYER_TARGET_CHANGED on Ability Scaling (its model reads no target): no redraw, no model built", function()
  return renders == rr and builds == bb2, (renders - rr) .. " " .. (builds - bb2) end)
fire("GET_ITEM_INFO_RECEIVED", 987654, true)
checkp("  ...GET_ITEM_INFO_RECEIVED for an unrelated item: no redraw", function() return renders == rr, renders - rr end)
local tc = talentClears
fire("TRAIT_CONFIG_UPDATED", 1)
checkp("F4 TRAIT_CONFIG_UPDATED on Ability Scaling: the talent scan is read again (CM.ClearTalents) and it redraws", function()
  return talentClears == tc + 1 and renders == rr + 1, (talentClears - tc) .. " " .. (renders - rr) end)
c.tab = "stats"; ns.StatCalc_Render()
checkp("F4 Stats shown: no talent or bag event is listened to", function()
  return not registered("TRAIT_CONFIG_UPDATED") and not registered("PLAYER_TALENT_UPDATE") and not registered("BAG_UPDATE_DELAYED") end)
rr = renders
fire("PLAYER_TARGET_CHANGED")
checkp("(guard) PLAYER_TARGET_CHANGED on Stats (its stat map reads the target): it redraws", function() return renders == rr + 1, renders - rr end)
ns.StatCalc_SetOpen(false)
rr = renders
fire("GET_ITEM_INFO_RECEIVED", 1, true); fire("PLAYER_TARGET_CHANGED"); fire("UNIT_STATS", "player")
checkp("(guard) the panel closed: nothing redraws", function() return renders == rr, renders - rr end)
ns.StatCalc_SetOpen(true)

-- F5 (SC-050) ---------------------------------------------------------------------------------------------------------------------
local t0 = tieReads
ns.BuildStatCalcPage(function() end)
checkp("F5 the Stat Calculator page's first build after a reload reads the tie-ins once more (CM.ReadTieIns(true))", function()
  return tieReads == t0 + 1 and tieArgs[#tieArgs] == true, tieReads - t0 end)
ns.BuildStatCalcPage(function() end); ns.BuildStatCalcPage(function() end)
checkp("  ...later builds do not", function() return tieReads == t0 + 1, tieReads - t0 end)

-- F6 (SC-102) ---------------------------------------------------------------------------------------------------------------------
local LAY = ns.STATCALC_LAYOUT
local function est(text, size) return #tostring(text or "") * 0.55 * size end   -- (the panel's own fallback measure in this world)
local function cut(r) for w in tostring(r.text or ""):gmatch("%S+") do if est(w, r.size) > r.w + 0.01 then return w end end end
c.size = nil
for fs = 10, 14 do
  c.fontSize = fs; c.tab = "stats"; ns.StatCalc_Render()
  local d = drawn()
  local heads = recs(d, "wcolhead")
  local six = #heads == 6
  checkp(("F6 Stat Weights at 450 wide, text %d: every column title on one line (the kept #60 rule)"):format(fs), function()
    if #heads < 5 then return false, #heads .. " titles" end
    for _, h in ipairs(heads) do if est(h.text, h.size) > h.w + 0.01 then return false, h.text .. " w=" .. h.w end end
    return true end)
  if fs <= 11 then
    checkp(("F6 Stat Weights at 450 wide, text %d (the default and smaller): six column titles, the last Influences"):format(fs), function()
      local names = {}
      for _, h in ipairs(heads) do names[#names + 1] = h.text end
      return six and heads[6].text == "Influences", table.concat(names, "|") end)
  end
  checkp(("F6 Stat Weights at 450 wide, text %d: each row's influences %s, inside the panel, \"Influences: \" in front only under the row; nothing cut, no overlap"):format(fs,
    six and "in the Influences column on its own row" or "under its row (no room for six one-line titles)"), function()
    local labels = {}
    for _, r in ipairs(recs(d, "wlabel")) do labels[#labels + 1] = r end
    local infl = recs(d, "winfl")
    if #infl == 0 or #infl ~= #labels then return false, #infl .. " influence cells for " .. #labels .. " rows" end
    for i, r in ipairs(infl) do
      if six then
        if r.x ~= heads[6].x or r.y ~= labels[i].y then return false, "row " .. labels[i].text .. ": x " .. r.x .. " (title " .. heads[6].x .. "), y " .. r.y .. " (row " .. labels[i].y .. ")" end
      else
        if r.x ~= 12 or not (r.y > labels[i].y) then return false, "row " .. labels[i].text .. ": x " .. r.x .. ", y " .. r.y .. " (row " .. labels[i].y .. ")" end
      end
      if r.x + r.w > LAY.content + 0.01 then return false, "row " .. labels[i].text .. " past the right edge" end
      -- (in the column the title names them; under the row the line keeps its own "Influences: " label, as before)
      if six and tostring(r.text):find("^Influences: ") then return false, "still prefixed: " .. r.text end
      if not six and not tostring(r.text):find("^Influences: ") then return false, "under the row without its label: " .. r.text end
    end
    local all = {}
    for _, k in ipairs({ "wcolhead", "wlabel", "wrating", "wppp", "wpppdr", "wdr", "wtl", "winfl" }) do
      for _, r in ipairs(recs(d, k)) do
        if r.x < -0.01 or r.x + r.w > LAY.content + 0.01 or r.w <= 0 then return false, k .. " '" .. tostring(r.text) .. "' outside x=" .. r.x .. " w=" .. r.w end
        if k ~= "winfl" and cut(r) then return false, k .. " '" .. tostring(r.text) .. "' cut (" .. cut(r) .. ") w=" .. r.w end
        all[#all + 1] = r
      end
    end
    for i = 1, #all do for j = i + 1, #all do
      local a, b = all[i], all[j]
      if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then
        return false, a.kind .. " '" .. tostring(a.text) .. "' / " .. b.kind .. " '" .. tostring(b.text) .. "'"
      end
    end end
    return true end)
end
c.fontSize = 11

-- F7 (SC-085 / SC-049, round 2) ---------------------------------------------------------------------------------------------------
-- (a change the panel's events did not hear is read when its tab is next drawn; with unit B's caches, KC.owned and the talent scan,
-- this failed on round 1: the old bag list stayed)
ITEMS["Third Ring"] = { ilvl = 351, loc = "INVTYPE_FINGER", stats = { ITEM_MOD_MASTERY_RATING_SHORT = 320 } }
c.tab = "gear"; ns.StatCalc_Render()
if not CM.gearSlot then ns.StatCalc_SelectGearSlot(11) end
checkp("F7 setup: Gear, the ring slot picked: Loot Ring and New Ring listed", function() return bagIcons() == "Loot Ring,New Ring", bagIcons() end)
c.tab = "stats"; ns.StatCalc_Render()
BAG[2] = "|cffa335ee|Hitem:78::::::::90:::::|h[Third Ring]|h|r"   -- (Loot Ring sold, Third Ring looted while Stats is shown)
fire("BAG_UPDATE_DELAYED")
c.tab = "gear"; ns.StatCalc_Render()
checkp("F7 the bags changed while Stats was shown: back on Gear the list is the new one (New Ring, Third Ring)", function()
  return bagIcons() == "New Ring,Third Ring", bagIcons() end)
ns.StatCalc_SetOpen(false)
BAG[3] = "|cffa335ee|Hitem:77::::::::90:::::|h[Loot Ring]|h|r"   -- (bought back with the panel closed)
fire("BAG_UPDATE_DELAYED")
ns.StatCalc_SetOpen(true)
checkp("F7 the bags changed while the panel was closed: reopened on Gear, the list is the new one (Loot Ring, New Ring, Third Ring)", function()
  return bagIcons() == "Loot Ring,New Ring,Third Ring", bagIcons() end)
BAG[3] = nil
enterCombat(); fire("BAG_UPDATE_DELAYED"); leaveCombat()
checkp("F7 the bags changed in combat (panel hidden): after combat Gear lists the new bags (New Ring, Third Ring)", function()
  return panelShown() and bagIcons() == "New Ring,Third Ring", bagIcons() end)
local fz = forgets
ns.StatCalc_Render(); ns.StatCalc_Render()
checkp("  ...(cost) later draws while Gear stays shown do not read the bags again", function() return forgets == fz, forgets - fz end)
c.tab = "stats"; ns.StatCalc_Render()
local tc7 = talentClears
c.tab = "spells"; ns.StatCalc_Render()
checkp("F7 Ability Scaling drawn after another tab: the talent scan is read again once (CM.ClearTalents)", function() return talentClears == tc7 + 1, talentClears - tc7 end)
ns.StatCalc_Render(); ns.StatCalc_Render()
checkp("  ...(cost) later draws while it stays shown do not clear it again", function() return talentClears == tc7 + 1, talentClears - tc7 end)
c.tab = "stats"; ns.StatCalc_Render()
c.fontSize = 11
print(n .. " checks, " .. fails .. " failed")
'''


def main():
    src = (SRC.replace("__WORLD__", P("tests/char_world.lua", os.path.join(HERE, ".."))).replace("__MOD__", P("XayaUI/Modules.lua"))
           .replace("__COMPAT__", P("XayaUI/Compat.lua")).replace("__SM__", P("XayaUI_QoL/StatMath.lua"))
           .replace("__CM__", P("XayaUI_QoL/StatModel.lua")).replace("__ICD__", P("XayaUI_QoL/ImprovedCharacterDisplay.lua"))
           .replace("__CT__", P("XayaUI_Bonus/StatCalculator.lua")))
    lua = LuaRuntime()
    lua.execute(src)
    sys.exit(1 if lua.eval("fails") else 0)


if __name__ == "__main__":
    main()
