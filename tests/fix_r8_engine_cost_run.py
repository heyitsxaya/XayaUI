#!/usr/bin/env python3
"""Offline test (round 8, engine-core item 4: the Rule Builder session's engine-cost findings, RB-30 "Rules session decides"; each fixed
only where it is real and changes nothing the player sees, proven by tests/fix_r6_routing_replay_run.py and by this test).
  1. load checks re-run once a second: ns.CheckContext's memo was keyed on the whole second of GetTime(), so in a fight every live rule
     ran all its load checks again each second although no load fact had changed. Now: none in ten seconds of aura events with the
     same load facts; a real change (mounting) still re-checks them, and a "mounted only" display follows it;
  3. a gear change re-checked every rule: the equipment count was part of the load facts even when no rule or group loads only with an
     item equipped. Now: with no such list, a gear change re-checks only the live rules (the "Item Equipped" / "Set Pieces" rows read
     gear: they still follow it), not every rule; with such a list, every rule, and a rule that loads only with item 5001 equipped
     loads and unloads with it;
  4. another player's spec change: PLAYER_SPECIALIZATION_CHANGED fires for group members too (its unitTarget, events.md:1215); it read
     the load facts and set a timer. Now: a group member's spec change reads nothing; your own still re-checks;
  5. a load event re-checked the rules twice: the encounter starting (ns.LoadEvent) re-checked every live rule AND every rule in the same
     frame. Now: each rule once;
  6. (round 8's own find, item 4) a load-fact change re-built every aura and cooldown check even when the same rules stayed loaded. Now
     only when the live rules changed: such a frame costs clearly less than one that loads or unloads a rule (Lua instructions counted).
Stand-in: the whole-addon harness. UNVERIFIED IN GAME: that the game sends PLAYER_EQUIPMENT_CHANGED for every gear change (events.md
names the event; the load list's "item equipped" answer follows it).
Run: python3 tests/fix_r8_engine_cost_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local FRAME = 1 / 60
local aura = { [1001] = { spellId = 1001, auraInstanceID = 501, name = "Probe", applications = 1, duration = 600, expirationTime = 0, sourceUnit = "player", isHelpful = true } }
C_UnitAuras.GetPlayerAuraBySpellID = function(id) local a = aura[id]; if a then local t = {}; for k, v in pairs(a) do t[k] = v end; return t end end
C_UnitAuras.GetUnitAuraBySpellID = function(u, id) if u == "player" then return C_UnitAuras.GetPlayerAuraBySpellID(id) end end
local mounted, worn = false, {}
IsMounted = function() return mounted end
C_Item = C_Item or {}
C_Item.IsEquippedItem = function(id) return worn[tonumber(id)] == true end
IsEquippedItem = C_Item.IsEquippedItem

W.RemoveAuraContainer()   -- (round 11 repair, standin-repair1) this test measures XayaUI's own drawing of aura displays: a client without Blizzard's aura container,
-- so the combat engine falls back (XUI-W002, declared below) and XayaUI draws them (tests/harness/world.lua)
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local function mk(nm, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.text.enabled = false; r.sound.enabled = false; r.visual.trigger = "condition"
  f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
aura[1001].expirationTime = W.now + 600
local LIVE = {}
for i = 1, 20 do LIVE[i] = mk("aura " .. i, function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1001, "present", "none" end) end
local MT = mk("mounted only", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1001, "present", "none"; r.load.mounted = "yes" end)
local NL = {}
for i = 1, 20 do NL[i] = mk("never here " .. i, function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1001, "present", "none"; r.load.mounted = "yes"; r.load.resting = "yes" end) end
ns.MarkDirty(); W.tick(FRAME, 20)
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown(r) local fr = framesOf and framesOf[r]; return fr and fr:IsShown() and true or false end
-- what is counted: load-check runs (ns.FolderLoadOverride is the first thing each one asks), context reads, full checks of a rule
local loads, ctxReads, ev = 0, 0, {}
local FLO = ns.FolderLoadOverride
ns.FolderLoadOverride = function(...) loads = loads + 1; return FLO(...) end
local RC = ns.ReadContext
ns.ReadContext = function(...) ctxReads = ctxReads + 1; return RC(...) end
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) ev[r] = (ev[r] or 0) + 1; return E0(r, ...) end
local function evN(l) local n = 0; for i = 1, #l do n = n + (ev[l[i]] or 0) end; return n end
local function reset() loads, ctxReads = 0, 0; for k in pairs(ev) do ev[k] = nil end end

-- 1
W.enterCombat(); W.tick(FRAME, 20)
reset()
for i = 1, 300 do
  if i % 6 == 0 then aura[1001].expirationTime = W.now + 600 + i; W.fire("UNIT_AURA", "player", { updatedAuraInstanceIDs = { 501 } }) end
  W.tick(1 / 30, 1)
end
check("1. ten seconds of aura events in a fight with the same load facts: no rule runs its load checks again (before: each live rule once a second)",
  loads == 0, loads)
check("1. ... the rules were re-checked meanwhile (the aura events reached them)", evN(LIVE) > 0, evN(LIVE))
W.leaveCombat(); W.tick(FRAME, 10)
W.tick(0.2, 1)
mounted = true; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); W.tick(FRAME, 3)
check("1. a real load-fact change still runs the load checks: mounted, the 'mounted only' display shows", shown(MT))
W.tick(0.2, 1)
mounted = false; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED"); W.tick(FRAME, 3)
check("1. ... dismounted, it hides", not shown(MT))

-- 3: no rule or group loads with an item equipped
W.tick(0.5, 1); reset()
W.fire("PLAYER_EQUIPMENT_CHANGED", 16, false); W.tick(FRAME, 4)
check("3. a gear change with no 'item equipped' load list: the rules that are not loaded are not checked again (before: every rule)",
  evN(NL) == 0, evN(NL))
check("3. ... the live rules are (their gear rows follow gear)", evN(LIVE) >= #LIVE, evN(LIVE))
-- with such a list
local EQ = mk("with item 5001", function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 1001, "present", "none"; r.load.equipped = { ["5001"] = true } end)
ns.MarkDirty(); W.tick(FRAME, 10)
check("3. (setup) item 5001 not worn: the rule that loads only with it is hidden", not shown(EQ))
W.tick(0.2, 1)
worn[5001] = true; W.fire("PLAYER_EQUIPMENT_CHANGED", 16, true); W.tick(FRAME, 4)
check("3. with an 'item equipped' load list: putting item 5001 on loads its rule within a few frames", shown(EQ))
W.tick(0.2, 1)
worn[5001] = nil; W.fire("PLAYER_EQUIPMENT_CHANGED", 16, false); W.tick(FRAME, 4)
check("3. ... taking it off unloads it", not shown(EQ))

-- 4
W.tick(0.5, 1); reset()
W.fire("PLAYER_SPECIALIZATION_CHANGED", "party1"); W.tick(FRAME, 4)
check("4. a group member's spec change: your load facts are not read and no rule is checked (before: a context read and a timer)",
  ctxReads == 0 and evN(LIVE) == 0 and evN(NL) == 0, ctxReads .. " reads, " .. (evN(LIVE) + evN(NL)) .. " checks")
W.tick(0.5, 1); reset()
W.fire("PLAYER_SPECIALIZATION_CHANGED", "player"); W.tick(FRAME, 4)
check("4. your own spec change is still handled (the load facts are read again)", ctxReads >= 1, ctxReads)

-- 5
W.tick(0.5, 1); reset()
W.fire("ENCOUNTER_START", 2001, "Boss", 16, 20); W.tick(FRAME, 4)
local most = 0
for i = 1, #LIVE do if (ev[LIVE[i]] or 0) > most then most = ev[LIVE[i]] end end
-- (round 9, SD-77 "Route + narrow": the narrowed re-check re-checks only the rules whose load reads the encounter or a row outside the
-- aura / cooldown checks, and the readers of a check whose answer changed: none of these live rules; round 8: each once, before it twice)
check("5. a boss encounter starting (a load event): no live rule here is re-checked (none reads the encounter; round 8: each once, before: twice)", most == 0, most)
W.fire("ENCOUNTER_END", 2001, "Boss", 16, 20, 1); W.tick(FRAME, 4)

-- 6 (round 8, item 4: the full re-check's cost) a load-fact change that loads or unloads no rule (resting: no live rule's load reads it,
-- and the 'never here' rules stay unloaded) no longer builds the aura and cooldown checks again; one that does (mounted) still does
local function frameCost(fire)
  W.tick(0.5, 1)
  local n = 0
  fire()
  debug.sethook(function() n = n + 1 end, "", 100)
  W.tick(FRAME, 1)
  debug.sethook()
  return n * 100
end
local rest = false
IsResting = function() return rest end
local same1 = frameCost(function() rest = not rest; W.fire("PLAYER_UPDATE_RESTING") end)
local same2 = frameCost(function() rest = not rest; W.fire("PLAYER_UPDATE_RESTING") end)
local diff1 = frameCost(function() mounted = true; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED") end)
local diff2 = frameCost(function() mounted = false; W.fire("PLAYER_MOUNT_DISPLAY_CHANGED") end)
local same, diff = math.max(same1, same2), math.min(diff1, diff2)
check("6. a load-fact change that loads no rule and unloads none costs clearly less than one that does (the checks are not built again): "
  .. "at most 93% of it (instruction counts are exact in the stand-in)", same <= 0.93 * diff, ("%d vs %d Lua instructions"):format(same, diff))
check("6. ... and the displays still follow it (mounted at the end of the part: hidden again)", not shown(MT))
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    total = bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], bool(res[i][2])
        total += 1
        print(("ok  " if ok else "FAIL: ") + name)
        bad += 0 if ok else 1
    nerr = len(world.errors)
    for i in range(1, nerr + 1):
        print("ERROR in the game stand-in: %s" % str(world.errors[i])[:600])
    print("EXPECT_ERRORS XUI-W002 1")   # (round 11 repair) one per stand-in session, caused on purpose by W.RemoveAuraContainer() above (Combat/AuraDisplay.lua records it once per session)
    print("%d checks, %d failed, %d Lua errors" % (total, bad, nerr))
    sys.exit(1 if bad or nerr else 0)


if __name__ == "__main__":
    main()
