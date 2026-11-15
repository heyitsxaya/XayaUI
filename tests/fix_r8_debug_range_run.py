#!/usr/bin/env python3
"""Round 8 (bundle 1), repair pass 2 of the performance tracker in XayaUI_Debug (/xui debug perf): "most in 1 s" as a range.

Xaya's answers (REQUEST-LOG A23), her words: SD-68, "a performance tracker loaded in to test and validate performance" and
"performance measurement built in for me to test"; SD-66, "every re-check path at most 10 a second" (option 1; "the 11-in-a-second
overshoot is a bug and is fixed").

The reviewer's blocker on repair 1: "most in 1 s" counted only runs of reads that lasted 1.00 s or less (at most 4 reads, 935 ms at
60 fps), and "possibly over" looked only at 4 reads past 1 s. A 1 s window can touch more reads than that, so a real burst of 11 inside
0.95 s read "most in 1 s 9" or "10" with a plain "(limit 10/s)": the tracker said her limit was kept when it was not. Repair 2 gives a
range, low to high: low = the most in any run of reads that lasted 1.00 s or less (the true figure is at least this), high = the most
in any run of reads a 1 s window could touch, that is every run whose inner reads lasted 1.00 s or less (the true figure is at most
this). "over" when low passes 10, "possibly over" when only high does, a plain "(limit 10/s)" only when high is 10 or less.
Each check says what she sees. [new] = fails on the files before repair 2 (proved on a private copy).
  R1 [new] the reviewer's case: one burst of 11 passes inside 0.95 s between 5-a-second passes, at about 60 fps (frames of 16.6, 16.7,
     16.8 ms), through the stand-in's real ticker, at 50 start offsets 4.7 ms apart: every one of the 50 reports says "over" or
     "possibly over" (before: 50 of 50 said a plain "(limit 10/s)"), and every range holds the true 11.
  R2 [new] a window that touches 6 reads (the reviewer suggested 5): reads 233.8 ms apart (14 frames at 60 fps), 3 passes in the last
     30 ms of read 1, 5 in reads 2 to 5, 3 in the first 35 ms of read 6: 11 in 1 s, while every run of 5 reads holds 8. The report
     says "most in 1 s 7 to 11 (limit 10/s: possibly over)": a 5-read figure (8) would have said her limit was kept.
  R3 [new] the range always holds the true figure: 36 seeded random runs (bursts and quiet stretches at 22, 30, 60 and 144 fps, frames
     jittered), each checked against the true most in any 1 s window worked out from the pass times: low <= true <= high every time;
     "over" only when the true figure is past 10; a plain "(limit 10/s)" only when it is 10 or less.
  R4 [new] a steady 5 a second (the 0.2 s re-checks' pace) at 60 fps reads within her limit with no warning (5 to 8; the
     range holds the true figure, 6 here: the passes land on frames; before: 'most in 1 s 5', below the true 6).
  R5 (control) no "a high figure may be too low" note in a normal measurement (the ring of 8 reads is enough at 0.23 s reads).
  R7 [new] reads faster than expected (0.1 s apart, by hand): the report says "a high figure may be too low".
  R6 (control) a tick still allocates nothing (100 ticks, collector stopped), and its cost is counted: Lua instructions per tick,
     measured with a count hook over 1200 ticks at 60 fps spacing (300 of them read the CPU meter), at most 1,500 (942 measured;
     983 for repair 1 the same way).
Run: python3 tests/fix_r8_debug_range_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
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
local function first(lines, text) for _, l in ipairs(lines) do if l:find(text, 1, true) then return l end end end
local E = Enum.AddOnProfilerMetric
C_AddOnProfiler.GetAddOnMetric = function(name, metric) if metric == E.RecentAverageTime then return 0.05 end; return 0.5 end
C_AddOnProfiler.IsEnabled = function() return true end
GetFramerate = function() return 60 end
GetAddOnMemoryUsage = function(name) return 100 end
UpdateAddOnMemoryUsage = function() end
L.startup()
local ns = rawget(_G, "XayaUI_NS")
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
CueRulesDB.ui.msgDest = "chat"
local ES = ns.EngineStats
local function report() local n = #W.printed; ns.PerfCommand(""); return since(n) end

-- the true most in any 1 s window [x, x + 1), from sorted pass times
local function truth(pt)
  local best, a = 0, 1
  for b = 1, #pt do while pt[b] - pt[a] >= 1 - 1e-9 do a = a + 1 end; if b - a + 1 > best then best = b - a + 1 end end
  return best
end
-- the low and high figures and the verdict from a report line
local function parse(ln)
  local lo, hi = ln:match("most in 1 s (%d+) to (%d+)")
  if not lo then lo = ln:match("most in 1 s (%d+)"); hi = lo end
  local verdict = ln:find("possibly over", 1, true) and "possibly" or (ln:find(": over)", 1, true) and "over") or (ln:find("(limit 10/s)", 1, true) and "kept") or "?"
  return tonumber(lo), tonumber(hi), verdict
end
-- one measurement through the stand-in's real ticker, driven frame by frame; passes at the given times (seconds from the start)
local function run(frameMs, passTimes, path)
  ns.PerfCommand("on")
  local t0, k, i = W.now, 1, 0
  local endT = (passTimes[#passTimes] or 0) + 1.5
  while W.now - t0 < endT do
    i = i + 1
    local dt = frameMs[(i - 1) % #frameMs + 1] / 1000
    local t = W.now + dt - t0
    while passTimes[k] and passTimes[k] <= t do ES[path] = ES[path] + 1; passTimes[k] = t; k = k + 1 end   -- (a pass happens on a frame)
    W.tick(dt)
  end
  ns.PerfCommand("off")
  local r = report()
  return truth(passTimes), first(r, "perf: " .. path .. " (") or "(no line)", r
end

-- R1: the reviewer's burst
local F60 = { 16.6, 16.7, 16.8 }
local warned, held, plainN, sample = 0, 0, 0, nil
for off = 0, 49 do
  local pt = {}
  for j = 0, 9 do pt[#pt + 1] = 0.1 + j * 0.2 end
  local b0 = 2.2 + off * 0.0047
  for j = 0, 10 do pt[#pt + 1] = b0 + j * 0.095 end   -- 11 passes over 10 x 0.095 = 0.95 s
  for j = 0, 9 do pt[#pt + 1] = b0 + 1.3 + j * 0.2 end
  local tr, ln = run(F60, pt, "settle")
  local lo, hi, v = parse(ln)
  if v == "over" or v == "possibly" then warned = warned + 1 elseif v == "kept" then plainN = plainN + 1; sample = sample or ln end
  if tr == 11 and lo and lo <= tr and tr <= hi then held = held + 1 end
end
check("[new] R1 a burst of 11 inside 0.95 s at about 60 fps, 50 start offsets: all 50 say 'over' or 'possibly over' (" .. warned .. "), none a plain limit (" .. plainN .. "); the range holds the true 11 in all 50 (" .. held .. ")",
  warned == 50 and plainN == 0 and held == 50, sample)

-- R2: a window touching 6 reads; reads by hand 233.8 ms apart (14 frames at 60 fps), counters raised before each read
ns.PerfCommand("on")
local T0, D = W.now, 0.2338
local perRead = { 0, 0, 3, 1, 1, 2, 1, 3, 0, 0, 0, 0 }   -- reads 3 to 8 are the window's 6 reads ("read 1" to "read 6" above)
local times = {}
for k = 1, #perRead do
  local tEnd = D * k
  if k == 3 then times[#times + 1] = tEnd - 0.025; times[#times + 1] = tEnd - 0.015; times[#times + 1] = tEnd - 0.005 end   -- last 30 ms
  if k >= 4 and k <= 7 then for q = 1, perRead[k] do times[#times + 1] = tEnd - D + D * q / (perRead[k] + 1) end end
  if k == 8 then times[#times + 1] = tEnd - D + 0.005; times[#times + 1] = tEnd - D + 0.015; times[#times + 1] = tEnd - D + 0.025 end   -- first 35 ms
  ES.routed = ES.routed + perRead[k]
  W.now = T0 + tEnd; ns.DebugPerfTick()
end
ns.PerfCommand("off")
table.sort(times)
local tr2 = truth(times)
local most5 = 0
for a = 1, #perRead - 4 do local n = 0; for b = a, a + 4 do n = n + perRead[b] end; if n > most5 then most5 = n end end
local rep = report()
local ln2 = first(rep, "perf: routed (") or "(no line)"
check("[new] R2 a window touching 6 reads holds " .. tr2 .. " while every 5 reads hold at most " .. most5 .. ": 'most in 1 s 7 to 11 (limit 10/s: possibly over)'",
  tr2 == 11 and most5 == 8 and ln2 == "XayaUI: perf: routed (aura and cooldown re-checks): 11, most in 1 s 7 to 11 (limit 10/s: possibly over)", ln2)

-- R3: seeded random runs
local seed = 12345
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
local FPS = { 22, 30, 60, 144 }
local bad, n3, overWrong, keptWrong, kinds = {}, 0, 0, 0, { over = 0, possibly = 0, kept = 0 }
for trial = 1, 36 do
  local fps = FPS[(trial - 1) % #FPS + 1]
  local frames = {}
  for i = 1, 7 do frames[i] = (1000 / fps) * (0.9 + 0.2 * rnd()) end
  local pt, t = {}, 0.05
  while t < 6 do
    if rnd() < 0.25 then   -- a burst: 6 to 14 passes, 40 to 120 ms apart
      local n, gap = 6 + math.floor(rnd() * 9), 0.04 + rnd() * 0.08
      for q = 1, n do pt[#pt + 1] = t; t = t + gap end
    else
      t = t + 0.15 + rnd() * 0.5; pt[#pt + 1] = t
    end
  end
  local tr, ln = run(frames, pt, "all")
  local lo, hi, v = parse(ln)
  n3 = n3 + 1
  kinds[v] = (kinds[v] or 0) + 1
  if not (lo and lo <= tr and tr <= hi) then bad[#bad + 1] = ("fps %d truth %d: %s"):format(fps, tr, ln) end
  if v == "over" and tr <= 10 then overWrong = overWrong + 1 end
  if v == "kept" and tr > 10 then keptWrong = keptWrong + 1 end
end
check(("[new] R3 36 seeded random runs: low <= true <= high in every one (%d broke it); 'over' never at 10 or less (%d), a plain limit never past 10 (%d); verdicts over %d, possibly %d, kept %d"):format(#bad, overWrong, keptWrong, kinds.over or 0, kinds.possibly or 0, kinds.kept or 0),
  n3 == 36 and #bad == 0 and overWrong == 0 and keptWrong == 0 and (kinds.over or 0) > 0 and (kinds.kept or 0) > 0, bad[1])

-- R4 / R5: a steady 5 a second at about 60 fps
local pt = {}; for j = 0, 50 do pt[#pt + 1] = 0.013 + j * 0.2 end
local tr4, ln4, rep4 = run(F60, pt, "pollRange")
local lo4, hi4, v4 = parse(ln4)
-- (low: 4 reads over 935 ms hold 4 or 5; high: 6 reads over 6 x 233.8 = 1,403 ms hold at most 1.403 / 0.2 = 7.0, so 7 or 8)
-- (the passes land on frames, so 0.2 s apart becomes 183 to 217 ms apart and the true most in 1 s can be 6)
check("[new] R4 a steady 5 a second: within her limit, no warning (true " .. tr4 .. ", range " .. tostring(lo4) .. " to " .. tostring(hi4) .. ")",
  tr4 <= 6 and v4 == "kept" and lo4 <= tr4 and tr4 <= hi4 and hi4 <= 8, ln4)
local note = false
for _, l in ipairs(rep4) do if l:find("may be too low", 1, true) then note = true end end
check("R5 (control) no 'a high figure may be too low' note in a normal measurement", not note and #rep4 > 5)

-- R6: allocation and cost per tick
ns.PerfCommand("on"); T0 = W.now
for k = 1, 8 do ES.routed = ES.routed + 1; W.now = T0 + D * k; ns.DebugPerfTick() end
collectgarbage("collect"); collectgarbage("stop")
local c0 = collectgarbage("count")
for k = 9, 108 do ES.routed = ES.routed + 2; ES.redrawFill = ES.redrawFill + 3; W.now = T0 + D * k + (k % 3) * 0.001; ns.DebugPerfTick() end
local grew = (collectgarbage("count") - c0) * 1024
collectgarbage("restart")
local ins = 0
debug.sethook(function() ins = ins + 1 end, "", 1)
for k = 109, 1308 do ES.routed = ES.routed + 2; ES.all = ES.all + 1; ES.redrawFill = ES.redrawFill + 3; W.now = T0 + D * k; ns.DebugPerfTick() end
debug.sethook()
ns.PerfCommand("off")
local perTick = ins / 1200
check(("R6 (control) a tick allocates nothing (%d bytes over 100) and costs %.0f Lua instructions (at most 1,500; %d over 1200 ticks)"):format(grew, perTick, ins),
  grew == 0 and perTick <= 1500, perTick)
-- R7: reads by hand 0.1 s apart (faster than the ticker ever runs): 6 inner reads take 0.6 s, so a 1 s window could reach past the
-- 8 reads kept, and the report says a high figure may be too low
ns.PerfCommand("on"); T0 = W.now
for k = 1, 20 do ES.wake = ES.wake + 1; W.now = T0 + 0.1 * k; ns.DebugPerfTick() end
ns.PerfCommand("off")
local rep7 = report()
local note7 = false
for _, l in ipairs(rep7) do if l == "XayaUI: perf: note: reads came faster than expected, so a high figure may be too low." then note7 = true end end
check("[new] R7 reads 0.1 s apart: the report says a high figure may be too low", note7, first(rep7, "perf: wake ("))
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
    print("fix_r8_debug_range: %d checks, %d failed, %d Lua errors" % (len(results), bad, len(errors)))
    sys.exit(1 if bad or errors else 0)


if __name__ == "__main__":
    main()
