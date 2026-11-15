#!/usr/bin/env python3
"""Round 8 (bundle 1), repair pass 1 of the performance tracker in XayaUI_Debug (/xui debug perf).

Xaya's answers (REQUEST-LOG A23), her words: SD-68, "a performance tracker loaded in to test and validate performance" and
"performance measurement built in for me to test"; SD-66, the pace: "every re-check path at most 10 a second" (option 1).

The review found that "most in 1 s" was the sum of the last 4 ticker reads, called "the highest count in any 1 s window", but the game
runs a ticker on frames, so 4 reads can take longer than 1 s and turn a pace of exactly 10 a second into a false "over" (the very line
she checks her limit with). It also found report lines that did not hold what they said, and behaviour with no test. Each check below
gives what she sees in the report. [new] = fails on the pre-repair files (proved on a private copy with XayaUI_Debug as it was before
this repair); the others are controls that were already true and must stay true.
  W1  [new] reads 0.26 s apart (a ticker running late on frames), the engine at exactly 10 a second (the test works out the true most
      in any 1 s window: 10): no "over"; "most in 1 s" never counts high (8, from 3 reads over 0.78 s); the 4-read count of 11 is
      given with how long those 4 reads took (1.04 s) and marked "possibly over".
  W2  (control) 11 passes in 0.75 s with reads 0.25 s apart, 5 s after the last measurement: "over" (more than 10 in 1.00 s or
      less is certain; the time ring starts afresh with each measurement).
  W2b [new] reads 0.4 s apart (a very slow frame rate), 11 in the first 3 reads (1.2 s): "most in 1 s" 8 (2 reads, 0.8 s), and
      the 11 is given over the 1.20 s since the start (not over a time left from the last measurement), "possibly over".
  W3  (control) exactly 10 in 1 s: within her limit, no "over" (her words: "at most 10").
  W3b [new] reads 0.26 s apart, 10 in 4 reads over 1.04 s: within her limit, no "possibly over" (10 is not more than 10).
  W4  (control) a second /xui debug perf on starts again from zero: an earlier measurement's "over" is not carried into the next.
  W5  (control) the report while measuring ("so far") reads the live counters, and its memory is read when the report is typed.
  W6  (control) a restart clears the CPU "most read while measuring".
  W7  (control) the passes since the last read before the stop are counted (11 in the last 0.1 s: "over").
  W8  [new] after the stop, the engine lines use the stop time and the Lua memory at the stop: typed 10 s later, the same report says
      2 s in both places, and "Lua memory ... at the stop".
  W8b [new] that "at the stop" figure is the Lua memory read at the stop: 300,000 numbers (4,687.5 KB or more) kept after the stop are not in it.
  W9  [new] an installed XayaUI addon that is not loaded (XayaUI_Options, load on demand) says "not loaded", with no figures.
  W9b [new] one loaded after the start says "(loaded after the start)" instead of a "since the start" change.
  W10 [new] the game's addon list is read by index with C_AddOns.GetAddOnName (namespaces.md:152): with GetAddOnInfo refusing an
      index, the tracker still lists every XayaUI addon and the "top 8" line still names them.
  W11 [new] the report says that "% of a frame" is not the AddOn Usage screen's CPU percent, and that XayaUI Rules' figures include the
      timing points perf on switches on.
  W12 [new] the header says how "most in 1 s" is counted (reads 1.00 s apart or less; "possibly over"; a burst can count low).
  W13 (control) a read still allocates nothing with the new time ring (100 reads at uneven spacing, collector stopped).
  W14 [new vs the first repair attempt, which kept reads 0.25 s apart] at about 60 fps (frames of 16.6, 16.7, 16.8 ms), driven frame by
      frame through the stand-in's real ticker: the engine at exactly 10 a second gives "most in 1 s 10" and nothing more; one extra
      pass gives 11, "over"; 12 a second gives 12, "over". With 0.25 s, 4 reads took 1.002 s at 60 fps, so these read "most in 1 s 8"
      or 9 and only "possibly over". (The original pre-repair files pass W14: their 4-read sum happens to match here; W1 is the case
      where it was wrong.)
Run: python3 tests/fix_r8_debug_repair_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
local W, L = ...
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function since(n) local t = {}; for i = n + 1, #W.printed do t[#t + 1] = plain(W.printed[i]) end; return t end
local function count(lines, text) local c = 0; for _, l in ipairs(lines) do if l:find(text, 1, true) then c = c + 1 end end; return c end
local function first(lines, text) for _, l in ipairs(lines) do if l:find(text, 1, true) then return l end end end
local function contains(s, text) return s ~= nil and s:find(text, 1, true) ~= nil end
local function has(lines, exact) for _, l in ipairs(lines) do if l == exact then return true end end; return false end
local recent, peak = { XayaUI_Rules = 0.1 }, { XayaUI_Rules = 1.0 }
local E = Enum.AddOnProfilerMetric
C_AddOnProfiler.GetAddOnMetric = function(name, metric)
  if metric == E.RecentAverageTime then return recent[name] or 0.05 end
  if metric == E.PeakTime then return peak[name] or 0.5 end
  return 0
end
C_AddOnProfiler.IsEnabled = function() return true end
GetFramerate = function() return 50 end
local mem = { XayaUI_Rules = 3000, XayaUI = 900 }
GetAddOnMemoryUsage = function(name) return mem[name] or 100 end
UpdateAddOnMemoryUsage = function() end
L.startup()
local ns = rawget(_G, "XayaUI_NS")
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
CueRulesDB.ui.msgDest = "chat"
local ES = ns.EngineStats
local function report() local n = #W.printed; ns.PerfCommand(""); return since(n) end
local function tick() ns.DebugPerfTick() end

-- W1: reads 0.26 s apart, passes exactly 0.1 s apart (10 a second), never at a read's moment (0.05 + 0.1 j against 0.26 k)
ns.PerfCommand("on")
local T0 = W.now
local passes, j = {}, 0
for k = 1, 40 do
  local tk = T0 + 0.26 * k
  while T0 + 0.05 + 0.1 * j <= tk do passes[#passes + 1] = 0.05 + 0.1 * j; ES.routed = ES.routed + 1; j = j + 1 end
  W.now = tk; tick()
end
W.now = T0 + 0.26 * 40   -- (the stop at the last read's moment: nothing more)
ns.PerfCommand("off")
local truth, a = 0, 1   -- the true most in any 1 s window [x, x + 1), worked out here from the pass times
for b = 1, #passes do while passes[b] - passes[a] >= 1 - 1e-9 do a = a + 1 end; if b - a + 1 > truth then truth = b - a + 1 end end
local rep = report()
local line = first(rep, "perf: routed (") or "(no routed line)"
check("[new] W1 engine at exactly 10/s (true most in any 1 s: " .. truth .. "), reads 0.26 s apart: no 'over', 'most in 1 s' 8 never counts high, the 4-read 11 is given with its 1.04 s and 'possibly over'",
  truth == 10 and has(rep, "XayaUI: perf: routed (aura and cooldown re-checks): " .. #passes .. ", most in 1 s 8; 11 in 4 reads over 1.040 s (limit 10/s: possibly over)"), line)

-- W2: 11 passes in 0.75 s, reads 0.25 s apart, in a measurement started 5 s after the last one (the time ring starts afresh)
W.now = W.now + 5
ns.PerfCommand("on"); T0 = W.now
for k = 1, 8 do
  if k <= 3 then ES.routed = ES.routed + (k == 3 and 3 or 4) end   -- 4 + 4 + 3 = 11 in the first 3 reads (0.75 s)
  W.now = T0 + 0.25 * k; tick()
end
ns.PerfCommand("off"); rep = report()
check("W2 (control) 11 passes within 0.75 s: 'over' (more than 10 in 1.00 s or less)",
  has(rep, "XayaUI: perf: routed (aura and cooldown re-checks): 11, most in 1 s 11 (limit 10/s: over)"), first(rep, "perf: routed ("))

-- W2b: reads 0.4 s apart (a very slow frame rate), 4 + 4 + 3 = 11 in the first 3 reads (1.2 s), 5 s after the last measurement
W.now = W.now + 5
ns.PerfCommand("on"); T0 = W.now
for k = 1, 8 do
  if k <= 3 then ES.routed = ES.routed + (k == 3 and 3 or 4) end
  W.now = T0 + 0.4 * k; tick()
end
ns.PerfCommand("off"); rep = report()
check("[new] W2b reads 0.4 s apart: most in 1 s 8 (2 reads, 0.8 s); the 11 is given over the 1.20 s it really took since the start",
  has(rep, "XayaUI: perf: routed (aura and cooldown re-checks): 11, most in 1 s 8; 11 in 4 reads over 1.200 s (limit 10/s: possibly over)"),
  first(rep, "perf: routed ("))

-- W3: exactly 10 in 1 s
ns.PerfCommand("on"); T0 = W.now
for k = 1, 8 do ES.pollRange = ES.pollRange + ((k % 2 == 1) and 3 or 2); W.now = T0 + 0.25 * k; tick() end   -- 3 + 2 + 3 + 2 = 10 a second
ns.PerfCommand("off"); rep = report()
check("W3 (control) exactly 10 in 1 s: within her limit, not 'over'",
  has(rep, "XayaUI: perf: pollRange (0.2 s range re-checks): 20, most in 1 s 10 (limit 10/s)"), first(rep, "perf: pollRange ("))

-- W3b: 10 in 4 reads that took 1.04 s
ns.PerfCommand("on"); T0 = W.now
for k = 1, 8 do if k <= 4 then ES.pollCd = ES.pollCd + (k == 1 and 4 or 2) end; W.now = T0 + 0.26 * k; tick() end   -- 4 + 2 + 2 + 2 = 10 over 1.04 s
ns.PerfCommand("off"); rep = report()
check("[new] W3b 10 in 4 reads over 1.04 s: within her limit, not 'possibly over'",
  has(rep, "XayaUI: perf: pollCd (0.2 s hidden cooldown-end re-checks): 10, most in 1 s 8; 10 in 4 reads over 1.040 s (limit 10/s)"), first(rep, "perf: pollCd ("))

-- W4: a second 'on' starts from zero (first: 12 in 1 s; then 2 a second)
ns.PerfCommand("on"); T0 = W.now
for k = 1, 4 do ES.wake = ES.wake + 3; W.now = T0 + 0.25 * k; tick() end
ns.PerfCommand("on"); T0 = W.now
for k = 1, 8 do if k % 2 == 0 then ES.wake = ES.wake + 1 end; W.now = T0 + 0.25 * k; tick() end
ns.PerfCommand("off"); rep = report()
check("W4 (control) a second /xui debug perf on starts from zero: the earlier 12 in 1 s ('over') is not carried over",
  has(rep, "XayaUI: perf: wake (wake timer fires): 4, most in 1 s 2 (limit 10/s)"), first(rep, "perf: wake ("))

-- W5 / W6: while measuring ("so far") the live counters and memory; a restart clears the CPU "most read"
recent.XayaUI_Rules = 0.9
ns.PerfCommand("on"); T0 = W.now
for k = 1, 4 do W.now = T0 + 0.25 * k; tick() end   -- (the 4th read reads the CPU meter: 0.90 ms)
recent.XayaUI_Rules = 0.1
ns.PerfCommand("on"); T0 = W.now
for k = 1, 4 do ES.settle = ES.settle + 1; W.now = T0 + 0.25 * k; tick() end   -- (0.10 ms read now)
ES.settle = ES.settle + 3   -- (not read by a tick yet: the report reads the counter itself)
mem.XayaUI_Rules = 3100
rep = report()
check("W5 (control) the report while measuring says 'so far' and reads the live counter (4 read + 3 since) and the memory now",
  count(rep, "XayaUI: perf: engine passes over 1s so far (") == 1 and has(rep, "XayaUI: perf: settle (full settles): 7, most in 1 s 4 (limit 10/s)")
    and count(rep, "Lua memory 3100 KB now, +100 KB since the start") == 1, (first(rep, "perf: settle (") or "") .. " | " .. (first(rep, "XayaUI_Rules: CPU") or ""))
check("W6 (control) a restart clears the CPU 'most read while measuring' (0.90 ms before the restart, 0.10 ms after)",
  count(rep, "XayaUI: perf: XayaUI_Rules: CPU recent 0.10 ms (0.5% of a frame), most read while measuring 0.10 ms (0.5% of a frame)") == 1,
  first(rep, "XayaUI_Rules: CPU"))
ns.PerfCommand("off")

-- W7: the passes after the last read are counted at the stop
ns.PerfCommand("on"); T0 = W.now
for k = 1, 4 do W.now = T0 + 0.25 * k; tick() end
ES.alert = (ES.alert or 0) + 11; W.now = W.now + 0.1
ns.PerfCommand("off"); rep = report()
check("W7 (control) 11 passes in the last 0.1 s before the stop: counted, 'over'",
  has(rep, "XayaUI: perf: alert (Cooldown Manager alert re-checks): 11, most in 1 s 11 (limit 10/s: over)"), first(rep, "perf: alert ("))

-- W8: after the stop, the engine lines use the stop time and the memory at the stop
ns.PerfCommand("on"); T0 = W.now
for k = 1, 8 do W.now = T0 + 0.25 * k; tick() end
ns.PerfCommand("off")
local gcStop = collectgarbage("count")
local keep = {}; for i = 1, 300000 do keep[i] = i end   -- (kept after the stop: 300,000 x 16 bytes = 4,800,000 bytes = 4,687.5 KB, more while the array grows)
local gcLater = collectgarbage("count")
W.now = W.now + 10
rep = report()
check("[new] W8 typed 10 s after a 2 s measurement: both the engine line and the tracker say 2 s, memory 'at the stop'",
  count(rep, "XayaUI: perf over 2s: ") == 1 and count(rep, "XayaUI: perf: engine passes over 2s (") == 1
    and count(rep, "XayaUI: perf: Lua memory ") == 1 and contains(first(rep, "XayaUI: perf: Lua memory "), " KB at the stop, "),
  (first(rep, "XayaUI: perf over") or "") .. " | " .. (first(rep, "XayaUI: perf: Lua memory") or ""))

local memLine = first(rep, "XayaUI: perf: Lua memory ") or ""
local memKB = tonumber(memLine:match("Lua memory (%d+) KB at the stop"))
check("[new] W8b the 'at the stop' memory is the one read at the stop (" .. math.floor(gcStop) .. " KB), not ~" .. math.floor(gcLater) .. " KB when typed",
  gcLater - gcStop > 3000 and memKB ~= nil and math.abs(memKB - gcStop) < 300, memLine)
keep = nil

-- W9: XayaUI_Options is installed but not loaded (load on demand)
local optLoaded = C_AddOns.IsAddOnLoaded("XayaUI_Options")
check("[new] W9 an installed XayaUI addon that is not loaded says 'not loaded', with no figures",
  optLoaded == false and has(rep, "XayaUI: perf: XayaUI_Options: not loaded at the stop") and count(rep, "XayaUI_Options: CPU") == 0,
  tostring(optLoaded) .. " " .. tostring(first(rep, "XayaUI_Options")))
ns.PerfCommand("on")
C_AddOns.LoadAddOn("XayaUI_Options")
rep = report()
ns.PerfCommand("off")
check("[new] W9b loaded after the start: its memory says '(loaded after the start)', not a change since the start",
  C_AddOns.IsAddOnLoaded("XayaUI_Options") == true and count(rep, "XayaUI: perf: XayaUI_Options: CPU recent") == 1
    and contains(first(rep, "XayaUI: perf: XayaUI_Options: CPU"), "Lua memory 100 KB now (loaded after the start)"),
  first(rep, "XayaUI_Options"))

-- W10: the list read by index with the documented C_AddOns.GetAddOnName; GetAddOnInfo refuses an index here
local GI = C_AddOns.GetAddOnInfo
local byIndex = {}
for i = 1, C_AddOns.GetNumAddOns() do byIndex[i] = (GI(i)) end
local nameCalls = 0
C_AddOns.GetAddOnName = function(i) nameCalls = nameCalls + 1; return byIndex[i] end
C_AddOns.GetAddOnInfo = function(n) if type(n) == "number" then return nil end; return GI(n) end
ns.PerfCommand("on"); W.now = W.now + 0.25; tick()
rep = report()
ns.PerfCommand("off")
C_AddOns.GetAddOnInfo, C_AddOns.GetAddOnName = GI, nil
local topLine = first(rep, "perf: game's own addon meter, recent avg/peak ms per frame, top 8: ") or ""
check("[new] W10 read by index through C_AddOns.GetAddOnName: the 'top 8' line still names the XayaUI addons",
  nameCalls > 0 and topLine:find("XayaUI_Rules 0.10/1.0", 1, true) ~= nil and count(rep, "XayaUI: perf: XayaUI_Rules: CPU recent") == 1, topLine)

-- W11 / W12: what the report says about itself
check("[new] W11 the report says '% of a frame' is not the AddOn Usage screen's CPU %, and that XayaUI Rules' figures include the timing points",
  has(rep, "XayaUI: perf: note: '% of a frame' is not the CPU % on the game's AddOn Usage screen; read that screen for your CPU limits.")
    and has(rep, "XayaUI: perf: note: perf on also turns on XayaUI Rules' timing points, so its CPU and memory here include them."),
  first(rep, "perf: note"))
check("[new] W12 the header says how 'most in 1 s' is counted",
  has(rep, "XayaUI: perf: 'most in 1 s' counts only reads 1.00 s apart or less. 'over': more than 10 there. 'possibly over': more than 10 only in 4 reads that took longer than 1 s. A burst split between reads can count low.")
    and count(rep, "(counted by XayaUI Rules; read every 0.23 s or a little later, timed with GetTime):") == 1,
  first(rep, "'most in 1 s'"))

-- W13: a read allocates nothing with the time ring (uneven spacing)
ns.PerfCommand("on"); T0 = W.now
for k = 1, 8 do ES.routed = ES.routed + 1; W.now = T0 + 0.26 * k; tick() end
collectgarbage("collect"); collectgarbage("stop")
local c0 = collectgarbage("count")
for k = 9, 108 do ES.routed = ES.routed + 1; ES.redrawFill = ES.redrawFill + 2; W.now = T0 + 0.25 * k + (k % 3) * 0.01; tick() end
local grew = (collectgarbage("count") - c0) * 1024
collectgarbage("restart")
ns.PerfCommand("off")
check("W13 (control) 100 reads at uneven spacing allocate nothing with the time ring", grew == 0, grew .. " bytes")

-- W14: through the stand-in's real ticker, driven frame by frame (frames of 16.6, 16.7, 16.8 ms: about 60 fps). The stand-in fires a
-- ticker on the first frame at or after its time and re-arms it from that frame, the INFERENCE the tracker's STEP is built on.
local function frames(pace, extraAt, path)
  ns.PerfCommand("on")
  local t0, last, passes = W.now, -1, {}
  for i = 1, 3600 do   -- 60 s of frames
    local dt = (16.6 + (i % 3) * 0.1) / 1000
    local t = W.now + dt - t0
    if t - last >= pace then ES[path] = ES[path] + 1; last = t; passes[#passes + 1] = t end
    if i == extraAt then ES[path] = ES[path] + 1; passes[#passes + 1] = t end
    W.tick(dt)
  end
  ns.PerfCommand("off")
  local truth, a = 0, 1
  for b = 1, #passes do while passes[b] - passes[a] >= 1 - 1e-9 do a = a + 1 end; if b - a + 1 > truth then truth = b - a + 1 end end
  local r = report()
  return truth, #passes, first(r, "perf: " .. path .. " (") or "(no line)"
end
local tr, np, ln = frames(0.0995, nil, "settle")
check("[new vs first repair] W14a at about 60 fps through the real ticker, the engine at exactly 10 a second (true most in 1 s: " .. tr .. "): 'most in 1 s 10', within her limit, no 'possibly over'",
  tr == 10 and ln == "XayaUI: perf: settle (full settles): " .. np .. ", most in 1 s 10 (limit 10/s)", ln)
tr, np, ln = frames(0.0995, 1800, "settle")
check("[new vs first repair] W14b the same with one extra pass (true most in 1 s: " .. tr .. "): 'most in 1 s 11', 'over'",
  tr == 11 and ln == "XayaUI: perf: settle (full settles): " .. np .. ", most in 1 s 11 (limit 10/s: over)", ln)
tr, np, ln = frames(0.08, nil, "settle")
check("[new vs first repair] W14c the engine at 12 a second (true most in 1 s: " .. tr .. "): 'most in 1 s 12', 'over' (sure, not 'possibly')",
  tr == 12 and ln == "XayaUI: perf: settle (full settles): " .. np .. ", most in 1 s 12 (limit 10/s: over)", ln)
L.logout()
return R
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    o = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    o["saved"] = H.to_lua(L, {"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"advancedDebug": True}}}})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, o)
    res = L.eval("function(src, ...) return loadstring(src)(...) end")(LUA, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errors = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    for x in errors:
        print("ERROR in the game stand-in:", x[:600])
    print("fix_r8_debug_repair: %d checks, %d failed, %d Lua errors" % (len(results), bad, len(errors)))
    sys.exit(1 if bad or errors else 0)


if __name__ == "__main__":
    main()
