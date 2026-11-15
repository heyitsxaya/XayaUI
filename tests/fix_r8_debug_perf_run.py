#!/usr/bin/env python3
"""Round 8 (bundle 1), the performance tracker in XayaUI_Debug and the engine reading line's missing figure.

Xaya's answers (REQUEST-LOG A23), her words: SD-68, the two 0.2 s cases: "option two with gating and a performance tracker loaded in to
test and validate performance"; the replay allowance: "option 2 with performance measurement built in for me to test"; SD-66, the pace:
"every re-check path at most 10 a second" (option 1); V34: the debug tools are read only while Advanced Debugging is on; V27 / V33: the
tracker's own sampling must not poll outside a measurement nor allocate per tick.

The engine stats contract (round 8): XayaUI Rules keeps ns.EngineStats, whole-number counters raised in place (routed, all, settle,
pollRange, pollCd, wake, alert, redrawText, redrawFill). The tracker only reads them; a missing field is said as "unavailable".

What the player gets, checked with the real addons (XayaUI, XayaUI_Rules, XayaUI_Options and XayaUI_Debug) in the stand-in game. The
ticks are driven by hand (ns.DebugPerfTick, the same function the ticker runs) with the counters raised by the test, so every number is
known. [new] = fails on the pre-change files (proved on a private copy with XayaUI_Debug as it was before round 8):
  P1  [new] /xui debug perf on starts ONE ticker (every 0.23 s, at most 2609 ticks = 10 minutes) and nothing else. (Round 8 repair:
      0.25 s and 2400 before; 0.23 s keeps 4 ticks within 1 s on frames, see XayaUI_Debug/RulesPerf.lua STEP.)
  P2  [new] the report gives, per counted path, the count and the most in any 1 s window; her limit of 10 a second is shown next to the
      seven re-check paths and "over" when it was passed; the two redraw counts have no limit; a missing counter says "unavailable".
  P3  [new] the 1 s windows move one read at a time: a burst of 6 + 6 across a whole-second boundary counts 12 in 1 s (whole
      seconds counted from the start would say 6).
  P4  [new] each XayaUI addon: the game's CPU meter (recent, the most read while measuring, peak) in ms and % of a frame, and its Lua
      memory now / at the stop and since the start.
  P5  [new] a tick allocates nothing (Lua memory unchanged over 100 ticks with the collector stopped); P5b it never refreshes addon
      memory (true before too: there was no tracker).
  P6  [new] /xui debug perf off stops the ticker and the report then gives the stopped figures; nothing runs after.
  P7  [new] a forgotten measurement stops itself after 2609 ticks (10 minutes) with one plain line, and the engine's timing points stop.
  P8  [new] /xui debug perf on while measuring restarts with one ticker (the old one is cancelled).
  P9  [new] without ns.EngineStats (an older XayaUI Rules): one line "engine passes: unavailable", no Lua error.
  P10 [new] the CPU meter switched off: "CPU unavailable (the game's addon meter is off)" per addon, never a guess.
  E1  [new] /xui debug status: a missing XayaUI Rules figure says "XayaUI Rules unavailable" (before: silently left out).
  E2  [new] ...also when Blizzard's aura containers gave no figure (before: the XayaUI Rules figure was dropped there too).
  E3  (control) both figures present: unchanged line with both.
  F1  (control, true before too) Advanced Debugging off: none of the tracker exists and /xui debug perf on starts no ticker (V34).
Run: python3 tests/fix_r8_debug_perf_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
local W, L, phase = ...
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function since(n) local t = {}; for i = n + 1, #W.printed do t[#t + 1] = plain(W.printed[i]) end; return t end
local function count(lines, text) local n = 0; for _, l in ipairs(lines) do if l:find(text, 1, true) then n = n + 1 end end; return n end
local function first(lines, text) for _, l in ipairs(lines) do if l:find(text, 1, true) then return l end end end
local function has(lines, exact) for _, l in ipairs(lines) do if l == exact then return true end end; return false end
-- the game's meters, answered by the test
local recent, peak = { XayaUI_Rules = 0.1 }, { XayaUI_Rules = 1.0 }
local meterOn = true
local E = Enum.AddOnProfilerMetric
C_AddOnProfiler.GetAddOnMetric = function(name, metric)
  if metric == E.RecentAverageTime then return recent[name] or 0.05 end
  if metric == E.PeakTime then return peak[name] or 0.5 end
  return 0
end
C_AddOnProfiler.IsEnabled = function() return meterOn end
GetFramerate = function() return 50 end   -- a frame is 1000 / 50 = 20 ms
local mem, updates = { XayaUI_Rules = 3000, XayaUI = 900 }, 0
GetAddOnMemoryUsage = function(name) return mem[name] or 100 end
UpdateAddOnMemoryUsage = function() updates = updates + 1 end
-- every ticker made, so the test sees how many and how often
local tickers = {}
local NT = C_Timer.NewTicker
C_Timer.NewTicker = function(d, fn, n) local h = NT(d, fn, n); tickers[#tickers + 1] = { d = d, n = n, h = h }; return h end
L.startup()
local ns = rawget(_G, "XayaUI_NS")
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local function slash(cmd) local n = #W.printed; SlashCmdList.XAYAUI(cmd); return since(n) end
local function tick() if ns.DebugPerfTick then ns.DebugPerfTick() else W.tick(0.25) end end   -- (pre-change files: no hand tick)
local function measuring() return ns.DebugPerfMeasuring and ns.DebugPerfMeasuring() end
local function live() local n = 0; for _, t in ipairs(tickers) do if not t.h:IsCancelled() then n = n + 1 end end; return n end

if phase == "off" then
  local t0 = #tickers
  local got = slash("debug perf on")
  check("F1 (control, true before too) Advanced Debugging off: none of the tracker exists and /xui debug perf on starts no ticker (V34: not read)",
    ns.DebugPerfTick == nil and ns.DebugPerfMeasuring == nil and #tickers == t0 and #got == 1, table.concat(got, " / "))
elseif phase == "on" then
  CueRulesDB.ui.msgDest = "chat"
  check("(control) the debug tools and ns.EngineStats are there", ns.DebugToolsLoaded() and type(ns.PerfCommand) == "function"
    and type(ns.EngineStats) == "table")
  local ES = ns.EngineStats
  local savedAlert = ES.alert
  ES.alert = nil   -- (a counter this XayaUI Rules would not have)
  local t0 = #tickers
  local got = slash("debug perf on")   -- (through core's /xui debug perf; its lines go to the console window, read below)
  local cw = rawget(_G, "XayaUIConsoleWindow")
  got = {}
  for _, l in ipairs(cw and cw.log and cw.log._lines or {}) do got[#got + 1] = plain(type(l) == "table" and l[1] or l) end
  if ns.ConsoleWindow then ns.ConsoleWindow(false) end
  check("[new] P1 /xui debug perf on starts ONE ticker, every 0.23 s, at most 2609 ticks (2609 x 0.23 s = 600.07 s)",
    #tickers == t0 + 1 and tickers[#tickers].d == 0.23 and tickers[#tickers].n == 2609 and measuring() == true
      and count(got, "perf: measuring.") == 1, (#tickers - t0) .. " " .. tostring(tickers[#tickers] and tickers[#tickers].d) .. " " .. tostring(tickers[#tickers] and tickers[#tickers].n) .. " " .. table.concat(got, " / "))
  -- 8 hand-driven ticks (2 s): routed +3 each (24, 12 in 1 s), pollRange +1 each (8, 4 in 1 s), redrawText +50 each (400, 200 in 1 s),
  -- all: +6 at ticks 4 and 5 only (a burst across the 1 s mark: 12 in 1 s)
  local u0 = updates
  for i = 1, 8 do
    ES.routed = ES.routed + 3; ES.pollRange = ES.pollRange + 1; ES.redrawText = ES.redrawText + 50
    if i == 4 or i == 5 then ES.all = ES.all + 6 end
    if i == 4 then recent.XayaUI_Rules = 0.5 end   -- (the 4th tick reads the CPU meter: 0.5 ms is the most read)
    if i == 5 then recent.XayaUI_Rules = 0.2 end
    W.now = W.now + 0.25
    tick()
  end
  check("P5b (true before too: no tracker then) the ticks never refresh addon memory (UpdateAddOnMemoryUsage only at start, stop or report)", updates == u0, updates - u0)
  mem.XayaUI_Rules = 3070
  local n = #W.printed
  ns.PerfCommand("off")
  local rep = since(n)
  n = #W.printed
  ns.PerfCommand("")
  rep = since(n)
  check("[new] P6 /xui debug perf off stops the ticker; the report then gives the stopped figures",
    live() == 0 and measuring() == false and count(rep, "perf: engine passes over 2s (counted by XayaUI Rules;") == 1,
    first(rep, "engine passes") or table.concat(rep, " / "):sub(1, 300))
  check("[new] P2a routed: count 24, most in 1 s 12 (4 x 3), past her limit: 'over'",
    has(rep, "XayaUI: perf: routed (aura and cooldown re-checks): 24, most in 1 s 12 (limit 10/s: over)"), first(rep, "perf: routed"))
  check("[new] P2b pollRange: count 8, most in 1 s 4, within her limit",
    has(rep, "XayaUI: perf: pollRange (0.2 s range re-checks): 8, most in 1 s 4 (limit 10/s)"), first(rep, "perf: pollRange"))
  check("[new] P2c redrawText: count 400, most in 1 s 200, no limit shown (a write, not a re-check)",
    has(rep, "XayaUI: perf: redrawText (tenths texts rewritten): 400, most in 1 s 200"), first(rep, "perf: redrawText"))
  check("[new] P2d a counter XayaUI Rules does not have: 'unavailable'",
    has(rep, "XayaUI: perf: alert (Cooldown Manager alert re-checks): unavailable"), first(rep, "perf: alert"))
  check("[new] P2e every path has its line (9), with her limit on the seven re-check paths only",
    count(rep, "XayaUI: perf: routed (") + count(rep, "XayaUI: perf: all (") + count(rep, "XayaUI: perf: settle (") + count(rep, "XayaUI: perf: pollRange (")
      + count(rep, "XayaUI: perf: pollCd (") + count(rep, "XayaUI: perf: wake (") + count(rep, "XayaUI: perf: alert (") + count(rep, "XayaUI: perf: redrawText (")
      + count(rep, "XayaUI: perf: redrawFill (") == 9 and count(rep, "(limit 10/s") == 6 and count(rep, "XayaUI: perf: redrawFill (bar fills written): 0, most in 1 s 0") == 1,
    count(rep, "(limit 10/s"))
  check("[new] P3 a burst of 6 + 6 across the 1 s mark counts 12 in 1 s (windows move one read at a time)",
    has(rep, "XayaUI: perf: all (every-live-rule re-checks): 12, most in 1 s 12 (limit 10/s: over)"), first(rep, "perf: all ("))
  check("[new] P4 XayaUI Rules: CPU recent 0.20 ms (1.0% of a 20 ms frame), most read 0.50 ms (2.5%), peak 1.00 ms (5.0%); Lua memory 3070 KB, +70 KB",
    has(rep, "XayaUI: perf: XayaUI_Rules: CPU recent 0.20 ms (1.0% of a frame), most read while measuring 0.50 ms (2.5% of a frame), peak 1.00 ms (5.0% of a frame); Lua memory 3070 KB at the stop, +70 KB since the start")
      and count(rep, "a frame is 20.0 ms at the current 50 fps") == 1, first(rep, "XayaUI_Rules:"))
  check("[new] P4b one line per XayaUI addon (XayaUI and XayaUI_Debug too)", count(rep, "XayaUI: perf: XayaUI: CPU recent") == 1
    and count(rep, "XayaUI: perf: XayaUI_Debug: CPU recent") == 1, first(rep, "perf: XayaUI: CPU"))
  local t1 = W.now
  W.tick(0.25, 20)
  n = #W.printed; ns.PerfCommand(""); rep = since(n)
  check("[new] P6b nothing runs after the stop: the same figures 5 s later", has(rep, "XayaUI: perf: routed (aura and cooldown re-checks): 24, most in 1 s 12 (limit 10/s: over)")
    and count(rep, "perf: engine passes over 2s") == 1, first(rep, "engine passes"))
  ES.alert = savedAlert or 0
  -- P5: a tick allocates nothing
  ns.PerfCommand("on")
  for i = 1, 8 do ES.routed = ES.routed + 1; tick() end   -- (warm up: every slot written once)
  collectgarbage("collect"); collectgarbage("stop")
  local c0 = collectgarbage("count")
  for i = 1, 100 do ES.routed = ES.routed + 1; ES.redrawFill = ES.redrawFill + 2; tick() end
  local grew = (collectgarbage("count") - c0) * 1024
  collectgarbage("restart")
  check("[new] P5 100 ticks (25 of them reading the CPU meter) allocate nothing: Lua memory unchanged", grew == 0, grew .. " bytes")
  -- P8: on while measuring
  local before = live()
  ns.PerfCommand("on")
  check("[new] P8 /xui debug perf on while measuring: still ONE live ticker (the old one cancelled)", before == 1 and live() == 1, before .. " -> " .. live())
  -- P7: the cap, through the real ticker
  n = #W.printed
  W.tick(0.25, 2700)   -- (the stand-in fires the ticker once a step: 2609 fires stop it; 2700 x 0.25 s = 675 s of game time)
  local capped = since(n)
  check("[new] P7 a forgotten measurement stops itself after 10 minutes with one line; the ticker and the engine's timing points stop",
    count(capped, "XayaUI: perf: stopped after 10 minutes, the longest one measurement runs. /xui debug perf shows the report.") == 1
      and measuring() == false and live() == 0 and not ns.perfOn, table.concat(capped, " / "):sub(1, 300))
  -- P10: the meter switched off
  meterOn = false
  n = #W.printed; ns.PerfCommand(""); rep = since(n)
  meterOn = true
  check("[new] P10 the CPU meter switched off: each addon says 'CPU unavailable (the game's addon meter is off)'",
    count(rep, "XayaUI: perf: XayaUI_Rules: CPU unavailable (the game's addon meter is off); Lua memory") == 1, first(rep, "XayaUI_Rules:"))
  -- P9: no ns.EngineStats at all
  ns.EngineStats = nil
  ns.PerfCommand("on"); W.now = W.now + 0.25; tick()
  n = #W.printed; ns.PerfCommand(""); rep = since(n)
  ns.PerfCommand("off")
  ns.EngineStats = ES
  check("[new] P9 without ns.EngineStats: one line 'engine passes: unavailable', the rest of the report still there",
    count(rep, "XayaUI: perf: engine passes: unavailable (this XayaUI Rules does not count them)") == 1 and count(rep, "perf: routed (") == 0
      and count(rep, "XayaUI: perf: XayaUI_Rules: CPU recent") == 1, table.concat(rep, " / "):sub(1, 300))
  -- E: the engine reading line in /xui debug status
  local M = C_AddOnProfiler.GetAddOnMetric
  local fig = { Blizzard_AuraContainer = 0.3, XayaUI_Rules = nil }
  C_AddOnProfiler.GetAddOnMetric = function(name) return fig[name] end
  ns.DebugEngineReadNow()
  local line = ns.DebugEngineLine()
  check("[new] E1 no XayaUI Rules figure: the line says 'XayaUI Rules unavailable'",
    line:find("Blizzard's aura containers 0.30 ms per frame", 1, true) ~= nil and line:sub(-27) == ", XayaUI Rules unavailable.", line)
  fig.Blizzard_AuraContainer, fig.XayaUI_Rules = nil, 0.42
  ns.DebugEngineReadNow(); line = ns.DebugEngineLine()
  check("[new] E2 no figure for Blizzard's aura containers: says so, and still gives XayaUI Rules 0.42 ms",
    line:find("gave no figure for Blizzard's aura containers (unavailable), XayaUI Rules 0.42 ms.", 1, true) ~= nil, line)
  fig.Blizzard_AuraContainer = 0.3
  ns.DebugEngineReadNow(); line = ns.DebugEngineLine()
  check("E3 (control) both figures: both in the line", line:find("aura containers 0.30 ms per frame", 1, true) ~= nil
    and line:sub(-23) == ", XayaUI Rules 0.42 ms.", line)
  C_AddOnProfiler.GetAddOnMetric = M
end
L.logout()
return R
'''


def session(saved, phase, addons=("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug")):
    folders = H.find_addons()
    enabled = [n for n in folders if n in addons]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    o = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    o["saved"] = H.to_lua(L, saved)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, o)
    res = L.eval("function(src, ...) return loadstring(src)(...) end")(LUA, world, loader, phase)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return results, errs


def main():
    results, errors = [], []
    r, e = session({}, "off")
    results += r; errors += e
    r, e = session({"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"advancedDebug": True}}}}, "on")
    results += r; errors += e
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    for x in errors:
        print("ERROR in the game stand-in:", x[:600])
    print("fix_r8_debug_perf: %d checks, %d failed, %d Lua errors" % (len(results), bad, len(errors)))
    sys.exit(1 if bad or errors else 0)


if __name__ == "__main__":
    main()
