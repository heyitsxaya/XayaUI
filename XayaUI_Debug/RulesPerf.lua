-------------------------------------------------------------------------------
-- XayaUI Debug: the engine perf report, /xui debug perf [on|off] (XayaUI Rules' combat engine timed on this machine). Moved from
-- XayaUI_Rules/Engine.lua in bundle 1 round 7 (REQUEST-LOG A23 SD-58, her answer on the debug tools: "1 but nothing loads unless
-- "Debugging" is enabled"; Tools.lua says how this addon loads). The timing points stay in the engine (Engine.lua: each step, rule
-- evaluation, visual updates, per rule, the events counted); this file only switches them on and off and prints what they read, through
-- the engine's ns.EnginePerfSet and ns.EnginePerfReadings. With Advanced Debugging off this file is never read, so the points are never
-- switched on. The copy of each report that was saved for XayaUI Dev Assist (XayaUIDevAssistDB.perfLog) is no longer written: Dev Assist
-- is retired to qa-installer-branch (SD-2).
-- How the player reaches it: core's /xui debug perf (XayaUI/Core.lua) calls XayaUI Rules' "rules" service (RuleDefaults.lua), which
-- asks this addon's "rulesdebug" service (Modules.lua ns.Provide / ns.Service) for PerfCommand, defined here. With XayaUI Rules switched off this file defines nothing (core then says the command needs it).
-- V26 (combat lock): exempt, read-only debugging; it works in combat. V24 / V25 cost: nothing until typed; while measuring, the engine's
-- timing points (one debugprofilestop pair per step and per rule); the report allocates its lines once, when it is typed.
-- Game API (docs/reference/api/, 12.1.5): C_AddOnProfiler.GetAddOnMetric(name: cstring, metric: AddOnProfilerMetric) -> result: number
-- (namespaces.md:130, SecretArguments=AllowedWhenUntainted; XayaUI passes the game's own addon names and enum values);
-- Enum.AddOnProfilerMetric RecentAverageTime = 1, PeakTime = 4 (enums.md:464); C_AddOns.GetNumAddOns() -> numAddOns (namespaces.md:157);
-- C_AddOns.GetAddOnName(index: uiAddon) -> name (namespaces.md:152; round 8 repair: the list is read by index through this documented
-- call; only a game without it falls back to C_AddOns.GetAddOnInfo(name: uiAddon) -> name, ... (namespaces.md:148) with the index, an
-- INFERENCE); C_AddOns.IsAddOnLoaded(name: uiAddon) -> loadedOrLoading, loaded (namespaces.md:162). INFERENCE (not documented): the
-- metrics are milliseconds per frame. Every call is guarded; a failed or missing one leaves its line out, never a guess.
-- collectgarbage("count") is the Lua library's (not a game API): Lua memory in KB, read only when the report is typed.
--
-- Round 8, the performance tracker (REQUEST-LOG A23 SD-68, her words: "a performance tracker loaded in to test and validate performance";
-- "performance measurement built in for me to test"). /xui debug perf on also starts a measurement of the engine's pass counts
-- (ns.EngineStats: whole numbers XayaUI Rules raises in place; this file only reads them, never writes or resets them), the game's own
-- CPU meter for each XayaUI addon and each one's Lua memory; /xui debug perf off stops it; /xui debug perf prints the report, while it
-- runs (so far) or after it stopped. INFERENCE (a debug tool: the command words and the layout are this design, not hers): the same
-- on / off / report words as before; one line per counted path with its count and the most in 1 s (below), her limit of 10 a second
-- (SD-66: "every re-check path at most 10 a second") next to the seven re-check paths (routed, all, settle, pollRange, pollCd, wake,
-- alert; the two redraw counts are writes, not re-checks); one line per XayaUI addon. A missing figure says "unavailable".
-- Its own cost (V27 / V33): ONE ticker per measurement (C_Timer.NewTicker with a file-level function, namespaces.md:4672), every 0.23 s
-- (STEP below says why not 0.25), that stops itself after 2609 ticks (2609 x 0.23 s = 600.07 s = 10 minutes; INFERENCE: the cap, so a
-- forgotten measurement cannot run on) or at /xui debug perf off. Each tick reads GetTime() once and the 9 counters into tables made at
-- file load (no allocation); about once a second (every 4th tick: 4 x 0.23 s = 0.92 s) it reads one CPU figure per XayaUI addon.
-- Measured in the stand-in (round 8 repair 2, tests/fix_r8_debug_range_run.py R6: a count hook over 1200 ticks 233.8 ms apart, 300 of
-- them reading the CPU meter): 1,130,138 / 1200 = 942 Lua instructions a tick (repair 1's 4-read ring, the same way: 983); 1 / 0.23 =
-- 4.35 ticks a second, so 942 / 0.23 = 4,096 a second, only while a measurement runs.
-- Nothing runs while no measurement runs, and nothing at all with Advanced Debugging off.
-- "Most in 1 s" (round 8 repairs 1 and 2). Reads come every 0.23 s or a little later, so they cannot say where inside a read a pass
-- fell; the report gives the true most in any 1 s window as a range, low to high, that always holds it. Each tick notes GetTime() in a
-- ring of the last 8 reads (made at file load). Low: the most counted in any run of reads that lasted 1.00 s or less in all (all those
-- passes fell within 1 s, so the true figure is at least this). High: the most counted in any run of reads a 1 s window could touch,
-- that is every run whose inner reads (all but its first and last) lasted 1.00 s or less (the true figure is at most this). "over":
-- the low figure is past her limit; "possibly over": only the high one is; a plain "(limit 10/s)" only when the high one is 10 or less.
-- Repair 1 kept only the low figure (and 4 reads past 1 s), so a real burst of 11 inside 0.95 s read "9" or "10" with no warning.
-- A 1 s window can touch 6 reads, not 5: at 60 fps a read takes 14 frames (14 x 16.7 ms = 233.8 ms), 4 inner reads take 4 x 233.8 =
-- 935 ms, which leaves 1000 - 935 = 65 ms for the window to reach into one read before and one after. The cost of the range is that a
-- path running steadily at exactly 10 a second reads "possibly over" (about 10 to 14 at 60 fps: 6 reads x 2.338 passes = 14.0):
-- reads 0.23 s apart cannot rule out 11 there. INFERENCE (debug tool design, flagged, not asked).
-- Game API (docs/reference/api/, 12.1.5): C_Timer.NewTicker(seconds, callback, iterations?) -> cbObject (namespaces.md:4672);
-- Enum.AddOnProfilerMetric.PeakTime = 4 (enums.md:470); C_AddOnProfiler.IsEnabled() -> enabled (namespaces.md:135); GetFramerate() ->
-- framerate (globals.md:181: "% of a frame" = ms / (1000 / framerate), at the frame rate when the report is typed);
-- UpdateAddOnMemoryUsage() (globals.md:732) then GetAddOnMemoryUsage(name: uiAddon) -> result (globals.md:118,
-- SecretArguments=AllowedWhenUntainted; the names come from the game's own list), read at the start, at the stop and when the report is
-- typed, never per tick. INFERENCE (not documented): the memory figure is in KB; "recent average" covers the last moments, so the
-- tracker also keeps the most it read about once a second while measuring. GetTime() -> time (globals.md:287), once per tick.
-- Round 8 repair, what the report now also says plainly: "% of a frame" is not the CPU percent on the game's AddOn Usage screen, which
-- V33's limits are read on (C_AddOnProfiler.GetApplicationMetric and GetOverallMetric, namespaces.md:131-132, are documented, but the
-- public reference has no notes on what they cover, so the tracker does not build a percent from them: that would be a guess);
-- /xui debug perf on also switches on XayaUI Rules' timing points, so XayaUI Rules' CPU and memory here include them; after the stop
-- the engine lines use the stop time and the Lua memory read at the stop (before, the time and memory when the report was typed); an
-- installed XayaUI addon that is not loaded says "not loaded" instead of figures (memory for one loaded after the start says so).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI) and XayaUI Rules
if not (ns.EnginePerfSet and ns.EnginePerfReadings) then return end   -- (XayaUI Rules is switched off: nothing to measure)

-- one installed addon's name by its place in the game's list (C_AddOns.GetAddOnName, documented with the index; see the top)
local function AddonName(A, i)
    local f = A.GetAddOnName or A.GetAddOnInfo
    if not f then return nil end
    local ok, name = pcall(f, i)
    if ok and type(name) == "string" then return name end
    return nil
end
-- loaded now: true / false, or nil when the game cannot say (then the figures are given, as before)
local function Loaded(name)
    local A = C_AddOns
    if not (A and A.IsAddOnLoaded) then return nil end
    local ok, either, loaded = pcall(A.IsAddOnLoaded, name)
    if not ok then return nil end
    if loaded ~= nil then return loaded and true or false end
    return either and true or false
end

-- the game's own per-addon CPU meter (C_AddOnProfiler); read-only, no cost to the addons measured
local function AddonCPU()
    local P, A, E = C_AddOnProfiler, C_AddOns, Enum and Enum.AddOnProfilerMetric
    if not (P and P.GetAddOnMetric and E and A and A.GetNumAddOns and (A.GetAddOnName or A.GetAddOnInfo) and A.IsAddOnLoaded) then return nil end
    local out = {}
    local okN, total = pcall(A.GetNumAddOns)
    for i = 1, (okN and tonumber(total)) or 0 do
        local name = AddonName(A, i)
        local okL, loaded = false, false
        if name then okL, loaded = pcall(A.IsAddOnLoaded, name) end
        if okL and loaded then
            local ok, avg = pcall(P.GetAddOnMetric, name, E.RecentAverageTime)
            local ok2, peak = pcall(P.GetAddOnMetric, name, E.PeakTime)
            if ok and type(avg) == "number" then out[#out + 1] = { name = name, avg = avg, peak = (ok2 and type(peak) == "number") and peak or 0 } end
        end
    end
    table.sort(out, function(x, y) return x.avg > y.avg end)
    return out
end

-- The performance tracker (round 8, SD-68; see the top of this file).
local PATHS = { "routed", "all", "settle", "pollRange", "pollCd", "wake", "alert", "redrawText", "redrawFill" }
local WHAT = { routed = "aura and cooldown re-checks", all = "every-live-rule re-checks", settle = "full settles",
    pollRange = "0.2 s range re-checks", pollCd = "0.2 s hidden cooldown-end re-checks", wake = "wake timer fires",
    alert = "Cooldown Manager alert re-checks", redrawText = "tenths texts rewritten", redrawFill = "bar fills and wipe steps written" }   -- (round 10: the count includes each whole-pixel step of an icon's Progress-Bar Wipe, Visual.lua)
local RECHECK = { routed = true, all = true, settle = true, pollRange = true, pollCd = true, wake = true, alert = true }
local LIMIT = 10            -- her limit for every re-check path, a second (SD-66)
-- seconds between ticks. INFERENCE (UNVERIFIED IN GAME): the game runs a ticker on frames, so a tick comes on the first frame at or
-- after STEP: at most STEP + one frame. With 0.25 s at about 60 fps (frames of 16.6 to 16.8 ms) a tick took 15 frames (15 x 16.7 ms
-- = 0.2505 s), so 4 ticks took 1.002 s: never "in 1 s"; the sure window was 3 ticks (0.75 s) and a real "over" read only "possibly
-- over". With 0.23 s: 14 frames (14 x 16.7 = 233.8 ms; 13 frames = 217.1 ms is short of 0.23 s), 4 ticks = 0.935 s. A tick is at most
-- 0.23 s + one frame, so 4 ticks stay within 1 s at 50 fps or more (0.23 + 0.02 = 0.25 s) and at many lower rates (30 fps: 7 x 33.3
-- ms = 0.233 s, 4 = 0.933 s); at others (22 fps: 6 x 45.5 ms = 0.273 s, 4 = 1.09 s) the 4-tick count is shown with its real length.
local STEP = 0.23
local WINDOW = 1.000001     -- a run of ticks counts as "in 1 s" when it lasted 1.00 s or less (the millionth: rounding in the sums)
local MAX_TICKS = 2609      -- 2609 x 0.23 s = 600.07 s: the measurement stops itself after 10 minutes
local MAIN = { "XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug" }   -- (only if the game's list cannot be read)
local RING = 8              -- reads kept: a 1 s window touches at most 6 reads 0.23 s long (see the top); 8 leaves room for early ones
local BEFORE = 1000         -- (seconds) a ring slot not yet read "began" this long before the start, so no run reaches into it
-- every table the ticks use is made here, once (a tick allocates nothing). high = the low figure (most in reads that lasted 1.00 s or
-- less); top = the high figure (most in reads a 1 s window could touch); tstart = when each ring slot began; span[j] = how long the
-- last j reads took; short = the ring was too small for one window (reads came faster than expected), so a high figure may be low.
local m = { on = false, ticks = 0, base = {}, last = {}, final = {}, high = {}, top = {}, ring = {}, names = {}, cpuHigh = {},
    mem0 = {}, mem1 = {}, loaded0 = {}, loaded1 = {}, tstart = {}, span = {}, tlast = 0, short = false }
for j = 1, RING do m.tstart[j], m.span[j] = 0, 0 end
for i = 1, #PATHS do local r = {}; for j = 1, RING do r[j] = 0 end; m.ring[PATHS[i]] = r end

local function Metric(name, metric)   -- one figure from the game's addon meter, or nil (never guessed)
    local P = C_AddOnProfiler
    if not (P and P.GetAddOnMetric and metric) then return nil end
    local ok, v = pcall(P.GetAddOnMetric, name, metric)
    if ok and type(v) == "number" and not (issecretvalue and issecretvalue(v)) then return v end
    return nil
end
local function ReadMemory(into, loaded)   -- KB per XayaUI addon; false where it cannot be read; loaded: true / false / nil per addon
    local ok = type(UpdateAddOnMemoryUsage) == "function" and pcall(UpdateAddOnMemoryUsage)
    for i = 1, #m.names do
        local okM, v = false, nil
        if ok and type(GetAddOnMemoryUsage) == "function" then okM, v = pcall(GetAddOnMemoryUsage, m.names[i]) end
        into[i] = (okM and type(v) == "number" and not (issecretvalue and issecretvalue(v))) and v or false
        if loaded then local l = Loaded(m.names[i]); if l == nil then loaded[i] = "?" else loaded[i] = l end end
    end
end
local function FindAddons()   -- the installed XayaUI addons, from the game's own list (once per start)
    local names, A = m.names, C_AddOns
    for i = #names, 1, -1 do names[i] = nil end
    if A and A.GetNumAddOns then
        local okN, total = pcall(A.GetNumAddOns)
        for i = 1, (okN and tonumber(total)) or 0 do
            local name = AddonName(A, i)
            if name and name:sub(1, 6) == "XayaUI" then names[#names + 1] = name end
        end
    end
    if #names == 0 then for i = 1, #MAIN do names[i] = MAIN[i] end end
end

local function Sample()   -- the counters since the last tick, into this tick's ring slot, with the time it ended
    local now = GetTime()
    local slot = m.ticks % RING + 1
    local tstart, span = m.tstart, m.span
    tstart[slot] = m.tlast; m.tlast = now
    local s = slot   -- span[j]: how long the last j reads took (back to the start of the slot j - 1 places before this one)
    for j = 1, RING do span[j] = now - tstart[s]; s = s - 1; if s == 0 then s = RING end end
    -- low: the last nLow reads lasted 1.00 s or less in all; high: a 1 s window can touch the last nHigh reads (their inner reads,
    -- 2 to nHigh - 1 counted back, lasted 1.00 s or less: span[j - 1] - span[1]); spans only grow with j, so the first miss ends each
    local nLow, nHigh = 0, 2
    while nLow < RING and span[nLow + 1] <= WINDOW do nLow = nLow + 1 end
    while nHigh < RING and span[nHigh] - span[1] <= WINDOW do nHigh = nHigh + 1 end
    if span[RING] - span[1] <= WINDOW then m.short = true end   -- (a window could reach past the ring: never at 0.23 s reads)
    local ES = ns.EngineStats
    for i = 1, #PATHS do
        local k = PATHS[i]
        local v = ES and ES[k]
        if m.base[k] and type(v) == "number" then
            local r = m.ring[k]
            r[slot] = v - m.last[k]; m.last[k] = v
            local n, at = 0, slot
            for j = 1, nHigh do
                n = n + r[at]; at = at - 1; if at == 0 then at = RING end
                if j == nLow and n > m.high[k] then m.high[k] = n end
            end
            if n > m.top[k] then m.top[k] = n end
        end
    end
end
local function SampleCPU()   -- about once a second: the most each XayaUI addon's recent average reached while measuring
    local E = Enum and Enum.AddOnProfilerMetric
    local metric = E and E.RecentAverageTime
    for i = 1, #m.names do
        local v = Metric(m.names[i], metric)
        if v and (not m.cpuHigh[i] or v > m.cpuHigh[i]) then m.cpuHigh[i] = v end
    end
end

local Tick
local function StopMeasuring(why)
    if not m.on then return end
    Sample()   -- (the passes since the last tick)
    m.on, m.t1 = false, GetTime()
    m.gc1 = collectgarbage("count")
    if m.ticker then m.ticker:Cancel(); m.ticker = nil end
    local ES = ns.EngineStats
    for i = 1, #PATHS do
        local k = PATHS[i]
        local v = ES and ES[k]
        m.final[k] = type(v) == "number" and v or false
    end
    ReadMemory(m.mem1, m.loaded1)
    if why == "cap" then
        ns.EnginePerfSet(false)
        ns.Print("perf: stopped after 10 minutes, the longest one measurement runs. /xui debug perf shows the report.")
    end
end
function Tick()   -- (file-level: the ticker is made once per measurement, with this same function)
    if not m.on then return end
    Sample()
    m.ticks = m.ticks + 1
    if m.ticks % 4 == 0 then SampleCPU() end
    if m.ticks >= MAX_TICKS then StopMeasuring("cap") end
end
local function StartMeasuring()
    if m.ticker then m.ticker:Cancel(); m.ticker = nil end
    FindAddons()
    local ES = ns.EngineStats
    m.hadStats = type(ES) == "table"
    for i = 1, #PATHS do
        local k = PATHS[i]
        local v = ES and ES[k]
        local r = m.ring[k]
        for j = 1, RING do r[j] = 0 end
        if type(v) == "number" then m.base[k], m.last[k] = v, v else m.base[k], m.last[k] = false, 0 end
        m.high[k], m.top[k] = 0, 0
        m.final[k] = false
    end
    for i = 1, #m.names do m.cpuHigh[i] = false; m.mem1[i] = false; m.loaded1[i] = false end
    for i = #m.names + 1, #m.cpuHigh do m.cpuHigh[i] = nil end
    ReadMemory(m.mem0, m.loaded0)
    m.on, m.t0, m.t1, m.ticks, m.gc1 = true, GetTime(), nil, 0, nil
    m.tlast, m.short = m.t0, false
    local tstart = m.tstart
    for j = 1, RING do tstart[j] = m.t0 - BEFORE end
    if C_Timer and C_Timer.NewTicker then m.ticker = C_Timer.NewTicker(STEP, Tick, MAX_TICKS) end
end
ns.DebugPerfTick = function() return Tick() end   -- (tests: the same tick the ticker runs)

local function TrackerReport(L)
    if not m.t0 then return end
    local secs = math.max(0.001, (m.t1 or GetTime()) - m.t0)
    L("perf: engine passes over %.0fs%s (counted by XayaUI Rules; read every 0.23 s or a little later, timed with GetTime):",
        secs, m.on and " so far" or "")
    local ES = ns.EngineStats
    if not m.hadStats then
        L("perf: engine passes: unavailable (this XayaUI Rules does not count them)")
    else
        L("perf: 'most in 1 s' is a range when reads 0.23 s apart cannot pin it down: low counts only reads within 1 s, high every read a 1 s window could touch. 'over': low is more than %d. 'possibly over': only high is. A path running steadily at %d/s can read 'possibly over'.", LIMIT, LIMIT)
        if m.short then L("perf: note: reads came faster than expected, so a high figure may be too low.") end
        for i = 1, #PATHS do
            local k = PATHS[i]
            local now
            if m.on then now = ES and ES[k] else now = m.final[k] end
            if m.base[k] and type(now) == "number" then
                local low, high = m.high[k], m.top[k]
                local most = high > low and ("most in 1 s %d to %d"):format(low, high) or ("most in 1 s %d"):format(low)
                local limit = ""
                if RECHECK[k] then
                    if low > LIMIT then limit = (" (limit %d/s: over)"):format(LIMIT)
                    elseif high > LIMIT then limit = (" (limit %d/s: possibly over)"):format(LIMIT)
                    else limit = (" (limit %d/s)"):format(LIMIT) end
                end
                L("perf: %s (%s): %d, %s%s", k, WHAT[k], now - m.base[k], most, limit)
            else
                L("perf: %s (%s): unavailable", k, WHAT[k])
            end
        end
    end
    -- each XayaUI addon: the game's CPU meter and its Lua memory
    local P = C_AddOnProfiler
    local E = Enum and Enum.AddOnProfilerMetric
    local cpuWhy
    if not (P and P.GetAddOnMetric and E) then cpuWhy = "the game's addon meter (C_AddOnProfiler) is not available here"
    else
        local okE, enabled = pcall(P.IsEnabled)
        if okE and enabled == false then cpuWhy = "the game's addon meter is off" end
    end
    local okF, fps = pcall(GetFramerate)
    local frameMs = (okF and type(fps) == "number" and not (issecretvalue and issecretvalue(fps)) and fps > 0) and (1000 / fps) or nil
    if frameMs then L("perf: each XayaUI addon, the game's meter in ms per frame (a frame is %.1f ms at the current %.0f fps):", frameMs, fps)
    else L("perf: each XayaUI addon, the game's meter in ms per frame (frame length unavailable, so no %%):") end
    L("perf: note: '%% of a frame' is not the CPU %% on the game's AddOn Usage screen; read that screen for your CPU limits.")
    L("perf: note: perf on also turns on XayaUI Rules' timing points, so its CPU and memory here include them.")
    local function Ms(v)
        if not v then return "unavailable" end
        if frameMs then return ("%.2f ms (%.1f%% of a frame)"):format(v, v / frameMs * 100) end
        return ("%.2f ms"):format(v)
    end
    local memNow, loadedNow = {}, {}
    if m.on then ReadMemory(memNow, loadedNow) else memNow, loadedNow = m.mem1, m.loaded1 end
    local when = m.on and "now" or "at the stop"
    for i = 1, #m.names do
        local name = m.names[i]
        if loadedNow[i] == false then
            L("perf: %s: not loaded%s", name, m.on and "" or " at the stop")
        else
            local cpu
            if cpuWhy then cpu = "CPU unavailable (" .. cpuWhy .. ")"
            else
                cpu = ("CPU recent %s, most read while measuring %s, peak %s"):format(Ms(Metric(name, E.RecentAverageTime)),
                    Ms(m.cpuHigh[i] or nil), Ms(Metric(name, E.PeakTime)))
            end
            local mem
            local a, b = m.mem0[i], memNow[i]
            if type(b) == "number" and m.loaded0[i] == false then
                mem = ("Lua memory %.0f KB %s (loaded after the start)"):format(b, when)
            elseif type(b) == "number" and type(a) == "number" then
                mem = ("Lua memory %.0f KB %s, %+.0f KB since the start"):format(b, when, b - a)
            elseif type(b) == "number" then
                mem = ("Lua memory %.0f KB %s (at the start: unavailable)"):format(b, when)
            else
                mem = "Lua memory unavailable"
            end
            L("perf: %s: %s; %s", name, cpu, mem)
        end
    end
end
ns.DebugPerfMeasuring = function() return m.on end   -- (tests)

function ns.PerfCommand(arg)
    arg = tostring(arg or ""):lower():match("^%s*(%a*)") or ""
    if arg == "on" or arg == "reset" then
        ns.EnginePerfSet(true)
        StartMeasuring()
        ns.Print("perf: measuring. Play (ideally a fight), then /xui debug perf to read it, /xui debug perf off to stop.")
        return
    elseif arg == "off" then
        ns.EnginePerfSet(false)
        StopMeasuring("off")
        ns.Print("perf: stopped. /xui debug perf shows the report.")
        return
    end
    local perf = ns.EnginePerfReadings()
    if not perf then ns.Print("perf: not measuring. /xui debug perf on, play a while, then /xui debug perf."); return end
    -- (round 8 repair) after the stop, the time and the Lua memory at the stop, so every line of one report covers the same stretch
    local stopped = not perf.on and not m.on and m.t1 and m.t1 >= perf.t0
    local tEnd = stopped and m.t1 or GetTime()
    local memEnd = stopped and m.gc1 or collectgarbage("count")
    local secs = math.max(0.001, tEnd - perf.t0)
    local steps = math.max(1, perf.steps)
    local parts = {}
    for k, n in pairs(perf.events) do parts[#parts + 1] = ("%s %.1f/s"):format(k, n / secs) end
    table.sort(parts)
    local rules, on = #(ns.rules or {}), 0
    for _, r in ipairs(ns.rules or {}) do if r.enabled then on = on + 1 end end
    local function L(fmt, ...) ns.Print(fmt:format(...)) end
    L("perf over %.0fs: %d steps (%.1f/s), %.2f ms avg, %.2f ms worst, %.1f%% of one frame budget at 60 fps (%d rules, %d on)",
        secs, perf.steps, perf.steps / secs, perf.total / steps, perf.max, (perf.total / secs) / 10, rules, on)
    L("perf: per second: rules %.2f ms, visuals %.2f ms, per-frame effects %.2f ms (%d calls)",
        perf.evalMs / secs, perf.visMs / secs, perf.fxMs / secs, perf.fxN)
    local top = {}
    for r, ms in pairs(perf.rule) do top[#top + 1] = { r, ms } end
    table.sort(top, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(5, #top) do
        local r = top[i][1]
        L("perf: #%d %.2f ms/s  %s%s", i, top[i][2] / secs, tostring(r.name), r.isCue and " (cue)" or "")
    end
    L("perf: Lua memory %.0f KB %s, %+.0f KB/s since start (a high number means garbage)", memEnd, stopped and "at the stop" or "now",
        (memEnd - perf.mem0) / secs)
    L("perf: events %s", #parts > 0 and table.concat(parts, ", ") or "none counted yet")
    local pp = {}
    for k, n in pairs(perf.paths) do pp[#pp + 1] = ("%s x%d"):format(k, n) end
    table.sort(pp)
    if #pp > 0 then L("perf: duration-text paths: %s", table.concat(pp, ", ")) end
    local cpu = AddonCPU()
    if cpu then
        local bits = {}
        for i = 1, math.min(8, #cpu) do bits[#bits + 1] = ("%s %.2f/%.1f"):format(cpu[i].name, cpu[i].avg, cpu[i].peak) end
        L("perf: game's own addon meter, recent avg/peak ms per frame, top 8: %s", table.concat(bits, "; "))
    else
        L("perf: the game's addon meter (C_AddOnProfiler) is not available here")
    end
    TrackerReport(L)
end
-- (XayaUI Rules' "rules" service asks here: RuleDefaults.lua)
local svc = ns.Service("rulesdebug") or {}
svc.PerfCommand = ns.PerfCommand
ns.Provide("rulesdebug", svc)
