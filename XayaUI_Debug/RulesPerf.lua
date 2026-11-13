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
-- C_AddOns.GetAddOnInfo(name: uiAddon) -> name, ... (namespaces.md:148); C_AddOns.IsAddOnLoaded(name: uiAddon) -> loadedOrLoading, loaded
-- (namespaces.md:162). INFERENCE (not documented): GetAddOnInfo accepts the list index as uiAddon (the game's own AddOns list reads it so)
-- and the metrics are milliseconds per frame. Every call is guarded; a failed or missing one leaves its line out, never a guess.
-- collectgarbage("count") is the Lua library's (not a game API): Lua memory in KB, read only when the report is typed.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI) and XayaUI Rules
if not (ns.EnginePerfSet and ns.EnginePerfReadings) then return end   -- (XayaUI Rules is switched off: nothing to measure)

-- the game's own per-addon CPU meter (C_AddOnProfiler); read-only, no cost to the addons measured
local function AddonCPU()
    local P, A, E = C_AddOnProfiler, C_AddOns, Enum and Enum.AddOnProfilerMetric
    if not (P and P.GetAddOnMetric and E and A and A.GetNumAddOns and A.GetAddOnInfo and A.IsAddOnLoaded) then return nil end
    local out = {}
    local okN, total = pcall(A.GetNumAddOns)
    for i = 1, (okN and tonumber(total)) or 0 do
        local okI, name = pcall(A.GetAddOnInfo, i)
        local okL, loaded = false, false
        if okI and type(name) == "string" then okL, loaded = pcall(A.IsAddOnLoaded, name) end
        if okL and loaded then
            local ok, avg = pcall(P.GetAddOnMetric, name, E.RecentAverageTime)
            local ok2, peak = pcall(P.GetAddOnMetric, name, E.PeakTime)
            if ok and type(avg) == "number" then out[#out + 1] = { name = name, avg = avg, peak = (ok2 and type(peak) == "number") and peak or 0 } end
        end
    end
    table.sort(out, function(x, y) return x.avg > y.avg end)
    return out
end

function ns.PerfCommand(arg)
    arg = tostring(arg or ""):lower():match("^%s*(%a*)") or ""
    if arg == "on" or arg == "reset" then
        ns.EnginePerfSet(true)
        ns.Print("perf: measuring. Play (ideally a fight), then /xui debug perf to read it, /xui debug perf off to stop.")
        return
    elseif arg == "off" then
        ns.EnginePerfSet(false)
        ns.Print("perf: stopped")
        return
    end
    local perf = ns.EnginePerfReadings()
    if not perf then ns.Print("perf: not measuring. /xui debug perf on, play a while, then /xui debug perf."); return end
    local secs = math.max(0.001, GetTime() - perf.t0)
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
    L("perf: Lua memory %.0f KB now, %+.0f KB/s since start (a high number means garbage)", collectgarbage("count"), (collectgarbage("count") - perf.mem0) / secs)
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
end
-- (XayaUI Rules' "rules" service asks here: RuleDefaults.lua)
local svc = ns.Service("rulesdebug") or {}
svc.PerfCommand = ns.PerfCommand
ns.Provide("rulesdebug", svc)
