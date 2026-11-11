#!/usr/bin/env python3
"""Stat Calculator gate fixes, unit U2 (XayaUI_Bonus/StatCalculator.lua, XayaUI_QoL/StatModel.lua; V27 / V28 / V14 / V30 gate findings).
On the whole-addon harness (tests/harness: every addon loaded as the game loads them), the Stat Calculator on. What the player gets:
  G003  docked beside the character window the panel takes the window's strata (here MEDIUM), so another game window opened over the
        character window is not covered by it; on its own (the window closed) it takes the same strata (A24 #8; it stayed HIGH before).
  G006  a resize under way (the corner grip pressed: panel.sizing) when combat starts: the move / size is stopped (StopMovingOrSizing)
        and panel.sizing is cleared, so after combat the panel takes its saved height again; the same when the panel hides (its close).
  G012  (= G-014) the panel closed: GET_ITEM_INFO_RECEIVED, UNIT_STATS and COMBAT_RATING_UPDATE are not registered; the start of combat
        is (V26: the Stat Calc button is told: statCalc.Available() false in combat); open: the stat and unit events are registered.
  G019  switched off (Stat Calculator off, or its panel off): its theme listener is taken out of core's list (Theme.OffResolve); on
        again: put back once.
  G020  the chat link hook with the panel closed returns before any work on the link (no string search for "|Hitem:").
  G028  Refresh spell data asks the model (CM.ForgetRulesLists) and never looks up the Rules service itself (ns.Service("rules")); the
        Rules lists are forgotten once.
  G010  every text's y and height in the panel's layout are whole pixels when the game measures a fractional text height (13.4), and
        (round 2) a wrapped text is rounded up (14), never cut to 13.
Round 2 adds two checks (28): no SetFrameStrata on a redraw that changes nothing, and a wrapped text rounded up. Negative controls: on
the tree at 5695993 (before this fix) 11 of the first 26 fail: G003 docked, G006 (3), G012 closed, G019 (2), G020, G028 (2)
and G010.
The harness is a stand-in for the game: in-game stacking, sizing and cost are UNVERIFIED IN GAME.
Run: python3 tests/statcalc_gate_fixes_run.py   (Lua 5.1 via lupa)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
if not rawget(_G, "CharacterFrame") then rawset(_G, "CharacterFrame", CreateFrame("Frame", "CharacterFrame", UIParent)) end
CharacterFrame:Hide(); CharacterFrame:SetFrameStrata("MEDIUM")
local sc, dbg = ns.Service("statCalc"), ns.Service("statCalcDebug")
check("setup: the statCalc and statCalcDebug services are there", sc ~= nil and dbg ~= nil)
if not (sc and dbg) then return R end
local T = ns.Theme
local function listenerSet() local s = {}; for _, f in ipairs(T and T.listeners or {}) do s[f] = true end; return s end
local before = listenerSet()
local c = sc.Cfg(); c.enabled, c.panel = true, true; ns.StatCalc_Apply()

-- G019 -------------------------------------------------------------------------------------------------------------------------
local mine = {}
for f in pairs(listenerSet()) do if not before[f] then mine[#mine + 1] = f end end
check("G019 switched on: the Stat Calculator adds one theme listener", #mine == 1, #mine)
local function present() local s = listenerSet(); local n = 0; for _, f in ipairs(mine) do if s[f] then n = n + 1 end end; return n end
c.enabled = false; ns.StatCalc_Apply()
check("G019 the Stat Calculator switched off: its theme listener is taken out (Theme.OffResolve)", present() == 0, present())
c.enabled = true; ns.StatCalc_Apply()
local mine2 = {}
for f in pairs(listenerSet()) do if not before[f] then mine2[#mine2 + 1] = f end end
check("G019 switched on again: one listener again", #mine2 == 1, #mine2)
mine = mine2
c.panel = false; ns.StatCalc_Apply()
check("G019 its panel switched off: the listener is taken out", present() == 0, present())
c.panel = true; ns.StatCalc_Apply()
check("G019 the panel on again: back once", present() == 1, present())

-- G012 / G014 ------------------------------------------------------------------------------------------------------------------
sc.Open("stats"); W.tick(0.1, 3); sc.Close(); W.tick(0.1, 1)
local panel = rawget(_G, "XayaUIStatCalculator")
check("G012 setup: the panel was built and is closed", panel ~= nil and not panel:IsShown())
check("G012 the panel closed: GET_ITEM_INFO_RECEIVED, UNIT_STATS and COMBAT_RATING_UPDATE are not registered",
  not dbg.Registered("GET_ITEM_INFO_RECEIVED") and not dbg.Registered("UNIT_STATS") and not dbg.Registered("COMBAT_RATING_UPDATE"),
  tostring(dbg.Registered("GET_ITEM_INFO_RECEIVED")) .. " " .. tostring(dbg.Registered("UNIT_STATS")))
check("G012 ...the start of combat, the spec and the level change are", dbg.Registered("PLAYER_REGEN_DISABLED") and dbg.Registered("PLAYER_SPECIALIZATION_CHANGED") and dbg.Registered("PLAYER_LEVEL_UP"))
local avail = {}
sc.OnState(function(open, available) avail[#avail + 1] = available end)
W.enterCombat()
check("G012 combat with the panel closed: the Stat Calc button is told the panel is not available (V26)", avail[#avail] == false and sc.Available() == false, tostring(avail[#avail]))
W.leaveCombat(); W.tick(0.1, 2)
check("G012 ...and available again after combat", sc.Available() == true and avail[#avail] == true)
sc.Open("stats"); W.tick(0.1, 3)
check("G012 the panel open: the stat and unit events are registered (UNIT_STATS, GET_ITEM_INFO_RECEIVED, COMBAT_RATING_UPDATE)",
  dbg.Registered("UNIT_STATS") and dbg.Registered("GET_ITEM_INFO_RECEIVED") and dbg.Registered("COMBAT_RATING_UPDATE"))
sc.Close(); W.tick(0.1, 1)

-- G020 -------------------------------------------------------------------------------------------------------------------------
sc.Open("gear"); W.tick(0.1, 3)
local ib = sc.Drawn().boxes.item
check("G020 setup: the Gear tab's item box was used (its link hook is live)", ib ~= nil and ib.xuiUsed == true)
sc.Close(); W.tick(0.1, 1)
local finds = 0
local rawFind = string.find
string.find = function(s, p, ...) if p == "|Hitem:" then finds = finds + 1 end; return rawFind(s, p, ...) end
local link = "|cffa335ee|Hitem:3::::::::90:::::|h[Better Helm]|h|r"
pcall(ChatFrameUtil.InsertLink, link)
string.find = rawFind
check("G020 a shift-clicked link with the panel closed: the hook returns before searching the link", finds == 0, finds)

-- G028 -------------------------------------------------------------------------------------------------------------------------
sc.Open("spells"); W.tick(0.1, 3)
local CM = ns.Service("statModel") and ns.Service("statModel").CM
check("G028 the model has ForgetRulesLists", CM ~= nil and type(CM.ForgetRulesLists) == "function")
local RS = ns.Service("rules")
local forgets, rawForget = 0, RS and RS.ForgetSpellLists
if RS and rawForget then RS.ForgetSpellLists = function(...) forgets = forgets + 1; return rawForget(...) end end
local lookups, rawService = 0, ns.Service
ns.Service = function(name, ...) if name == "rules" then lookups = lookups + 1 end; return rawService(name, ...) end
ns.StatCalc_Action("refreshSpells")
ns.Service = rawService
if RS and rawForget then RS.ForgetSpellLists = rawForget end
check("G028 Refresh spell data: the Rules service is not looked up again", lookups == 0, lookups)
check("G028 ...and XayaUI Rules' lists are forgotten once (through the model's tie-in)", RS == nil or forgets == 1, forgets)
sc.Close(); W.tick(0.1, 1)

-- G003 -------------------------------------------------------------------------------------------------------------------------
CharacterFrame:Show(); sc.Open("stats"); W.tick(0.1, 3)
check("G003 docked beside the character window: the panel takes the window's strata (MEDIUM)", panel:IsShown() and panel:GetFrameStrata() == "MEDIUM", panel:GetFrameStrata())
-- (round 2, V27 cost) a redraw with nothing changed does not set the strata again
do
  local sets, rawSet = 0, panel.SetFrameStrata
  panel.SetFrameStrata = function(self, ...) sets = sets + 1; return rawSet(self, ...) end
  ns.StatCalc_Render(); ns.StatCalc_Render()
  panel.SetFrameStrata = nil
  check("G003 two redraws with the strata already right: SetFrameStrata is not called again", sets == 0, sets)
end
CharacterFrame:SetFrameStrata("HIGH"); ns.StatCalc_Render()
check("G003 ...follows the window's strata (HIGH)", panel:GetFrameStrata() == "HIGH", panel:GetFrameStrata())
CharacterFrame:SetFrameStrata("MEDIUM")
sc.Close(); CharacterFrame:Hide(); W.tick(0.1, 1)
sc.Open("stats"); W.tick(0.1, 3)
-- (A24 #8, Xaya 2026-11-11: "Esc closes; normal layer (Recommended)") on its own the panel uses the game's standard windows' strata
-- (read from the character window: MEDIUM here), no longer HIGH; tests/char_statcalc_esc_run.py checks it with the window at another one
check("G003 on its own (the window closed): the standard windows' strata, MEDIUM (A24 #8; HIGH until then)", panel:IsShown() and panel.standalone == true and panel:GetFrameStrata() == "MEDIUM", panel:GetFrameStrata())

-- G006 -------------------------------------------------------------------------------------------------------------------------
local stops, rawStop = 0, panel.StopMovingOrSizing
panel.StopMovingOrSizing = function(self, ...) stops = stops + 1; return rawStop(self, ...) end
c.sizeMode = "small"; c.heightSmall = 480; ns.StatCalc_Render()
panel.grip:GetScript("OnMouseDown")(panel.grip)
check("G006 setup: the corner grip pressed (a resize under way)", panel.sizing == true)
panel:SetHeight(300)
stops = 0
W.enterCombat()
check("G006 combat starts during the resize: it is stopped (StopMovingOrSizing) and panel.sizing is cleared", stops >= 1 and panel.sizing == nil, stops .. " " .. tostring(panel.sizing))
W.leaveCombat(); W.tick(0.1, 3)
check("G006 after combat the panel takes its saved height again (480)", panel:IsShown() and math.floor(panel:GetHeight() + 0.5) == 480, panel:GetHeight())
panel.grip:GetScript("OnMouseDown")(panel.grip)
stops = 0
sc.Close(); W.tick(0.1, 1)
check("G006 the panel closed during a resize: stopped and cleared too", stops >= 1 and panel.sizing == nil, stops .. " " .. tostring(panel.sizing))
panel.StopMovingOrSizing = nil

-- G010 -------------------------------------------------------------------------------------------------------------------------
-- the game measures a wrapped text at a fractional height (13.4 here): every y and height drawn stays whole
local P
do
  local idx = getmetatable(panel).__index
  if type(idx) == "function" and debug and debug.getupvalue then
    for i = 1, 20 do local n, v = debug.getupvalue(idx, i); if n == "proto" then P = v end; if not n then break end end
  end
end
check("G010 setup: the stand-in font string measure can be changed", P ~= nil and P.GetStringHeight ~= nil)
if P then
  local rawH = P.GetStringHeight
  P.GetStringHeight = function() return 13.4 end
  local bad, n, cut, wrapped = {}, 0, {}, 0
  for _, tab in ipairs({ "stats", "gear", "spells" }) do
    c.tab = tab; ns.StatCalc_Render()
    for _, r in ipairs(sc.Drawn().layout or {}) do
      n = n + 1
      if type(r.y) == "number" and r.y ~= math.floor(r.y) then bad[#bad + 1] = tab .. ":" .. tostring(r.kind) .. " y=" .. r.y end
      if (r.kind == "text" or r.size) and type(r.h) == "number" and r.h ~= math.floor(r.h) then bad[#bad + 1] = tab .. ":" .. tostring(r.kind) .. " h=" .. r.h end
      if r.wrap and type(r.h) == "number" then
        wrapped = wrapped + 1
        if r.h < 13.4 then cut[#cut + 1] = tab .. ":" .. tostring(r.kind) .. " h=" .. r.h end
      end
    end
  end
  P.GetStringHeight = rawH
  check("G010 a fractional measured text height: every element's y and every text's height are whole pixels (" .. n .. " elements)", n > 0 and #bad == 0, table.concat(bad, ", ", 1, math.min(#bad, 6)))
  -- (round 2) rounded up, never down: the next row never starts inside a wrapped text's measured height (13.4 -> 14, not 13)
  check("G010 ...a wrapped text keeps at least its measured height (13.4 -> 14; " .. wrapped .. " wrapped texts)", wrapped > 0 and #cut == 0, table.concat(cut, ", ", 1, math.min(#cut, 6)))
end
sc.Close()
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + str(name)[:900])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    return 1 if bad or errs else 0


if __name__ == "__main__":
    sys.exit(main())
