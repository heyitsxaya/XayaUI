-------------------------------------------------------------------------------
-- XayaUI Debug: /xui debug status, and its /xui status shortcut printed in chat: every rule's answer right now, and why. Moved from
-- XayaUI_Rules/Conditions.lua in bundle 1 round 7 (REQUEST-LOG A23 SD-58, her answer on the debug tools: "1 but nothing loads unless
-- "Debugging" is enabled"; Tools.lua says how this addon loads). The data stays in XayaUI Rules: ns.ReadContext and ns.Evaluate
-- (Conditions.lua), ns.ExplainRule (Outcomes.lua), and ns.WithStatusDetail (Conditions.lua: readable time-source labels while this prints).
-- How the player reaches it: core's /xui debug status and /xui status (XayaUI/Core.lua) call XayaUI Rules' "rules" service
-- (RuleDefaults.lua), which asks this addon's "rulesdebug" service (Modules.lua ns.Provide / ns.Service) for PrintStatus, defined here.
-- With XayaUI Rules switched off this file defines nothing.
-- V26 (combat lock): exempt, read-only debugging; it works in combat. V24 / V25 cost: nothing until typed, then one evaluation per rule.
--
-- The combat engine's reading (SD-52, her answer on the engine's speed guard: "Remove it (Recommended)"; the request log's plan: "no
-- lean, no off step; a slow reading is only reported in /xui debug status"). One read-only line: what the game's own addon meter read at
-- the end of the last fight for Blizzard's aura containers (where the engine's drawing is counted) and for XayaUI Rules. Nothing acts on
-- it: no guard, no lean mode, no off step, no warning code, no chat line of its own. It is read once per fight end (PLAYER_REGEN_ENABLED),
-- by the frame below, which exists only while this addon is loaded (Advanced Debugging on); with it off nothing reads the meter.
-- Game API (docs/reference/api/, 12.1.5): C_AddOnProfiler.GetAddOnMetric(name: cstring, metric: AddOnProfilerMetric) -> result: number
-- (namespaces.md:130, SecretArguments=AllowedWhenUntainted: the names passed are literals); C_AddOnProfiler.IsEnabled() -> enabled: bool
-- (namespaces.md:135); Enum.AddOnProfilerMetric.RecentAverageTime = 1 (enums.md:464); PLAYER_REGEN_ENABLED (events.md:1207,
-- SynchronousEvent). INFERENCE (not documented, carried from the removed guard, UNVERIFIED IN GAME): the containers' work is counted under
-- the name "Blizzard_AuraContainer" (Blizzard's target-frame auras use the same code, so the figure is not XayaUI's alone), the unit is
-- milliseconds per frame, and "recent" covers the last moments of the fight. A missing or failed read is said as such, never guessed.
-- The clock time in the line comes from date (the Lua library's, which the game keeps as a global; not a game API, so not in the
-- reference; guarded: "?" without it).
-- No threshold: the line gives the figures only and never calls a reading slow or fine (round 7 repair: the removed guard's 1.0 ms limit
-- is not named; whether to show a reference figure, print the line only when high, or read at another moment is asked of Xaya).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI) and XayaUI Rules
if not (ns.Evaluate and ns.ReadContext and ns.WithStatusDetail) then return end   -- (XayaUI Rules is switched off: no rules to report)

-- the engine's reading at the end of each fight (read only)
local reading   -- { blizz = ms or nil, rules = ms or nil, at = "HH:MM" } after the first fight end; nil before
local function Metric(name)
    local P, E = C_AddOnProfiler, Enum and Enum.AddOnProfilerMetric
    if not (P and P.GetAddOnMetric and E and E.RecentAverageTime) then return nil end
    local ok, v = pcall(P.GetAddOnMetric, name, E.RecentAverageTime)
    return (ok and type(v) == "number" and not (issecretvalue and issecretvalue(v))) and v or nil
end
local function ReadEngine()
    reading = { blizz = Metric("Blizzard_AuraContainer"), rules = Metric("XayaUI_Rules"), at = date and date("%H:%M") or "?" }
end
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", ReadEngine)
ns.DebugEngineReadNow = ReadEngine   -- (tests: the same read the fight end makes)

local function EngineLine()
    local P = C_AddOnProfiler
    if not (P and P.GetAddOnMetric) then
        return "combat engine reading (read only, nothing acts on it): the game's addon meter (C_AddOnProfiler) is not available here."
    end
    local okE, enabled = pcall(P.IsEnabled)
    if okE and enabled == false then
        return "combat engine reading (read only, nothing acts on it): the game's addon meter is off, so there is no reading."
    end
    if not reading then
        return "combat engine reading (read only, nothing acts on it): none yet. It is read at the end of each fight."
    end
    if not reading.blizz then
        return ("combat engine reading (read only, nothing acts on it): at the end of the last fight (%s) the game's meter gave no figure for Blizzard's aura containers."):format(reading.at)
    end
    return ("combat engine reading (read only, nothing acts on it): at the end of the last fight (%s), Blizzard's aura containers %.2f ms per frame, recent average (this includes Blizzard's own target-frame auras)%s."):format(
        reading.at, reading.blizz, reading.rules and (", XayaUI Rules %.2f ms"):format(reading.rules) or "")
end
ns.DebugEngineLine = EngineLine   -- (tests)

local PrintStatusRaw
function ns.PrintStatus()
    local ok, err = ns.WithStatusDetail(PrintStatusRaw)   -- (readable time-source labels while it prints, Timing.lua)
    if not ok then ns.Print("status failed: " .. tostring(err)) end
end
-- (XayaUI Rules' "rules" service asks here: RuleDefaults.lua)
local svc = ns.Service("rulesdebug") or {}
svc.PrintStatus = ns.PrintStatus
ns.Provide("rulesdebug", svc)
function PrintStatusRaw()
    if not ns.rules or #ns.rules == 0 then ns.Print("no rules") return end
    local ctx = ns.ReadContext()
    ns.Print(("context: combat=%s group=%s raid=%s instance=%s(%s) mplus=%s encounter=%s mounted=%s spec=%s role=%s"):format(
        tostring(ctx.combat), tostring(ctx.group), tostring(ctx.raid), tostring(ctx.instance),
        tostring(ctx.instanceType), tostring(ctx.mythicPlus), tostring(ctx.encounter),
        tostring(ctx.mounted), tostring(ctx.specID), tostring(ctx.role)))
    ns.Print(("place: map=%s instanceID=%s difficulty=%s size=%s encounterID=%s"):format(tostring(ctx.mapID), tostring(ctx.instanceID),
        tostring(ctx.difficultyID), tostring(ctx.instSize), tostring(ctx.encounterID)))
    ns.Print(EngineLine())
    for i, r in ipairs(ns.rules) do
        local res, info = ns.Evaluate(r, ctx)
        ns.Print(("#%d %s [%s] result=%s | cd:%s(%s) buff:%s(%s via %s) ctx:%s talent:%s(known=%s)"):format(
            i, r.name, r.enabled and "on" or "off", tostring(res),
            tostring(r.cdState), tostring(info.cdOK), tostring(r.buffState), tostring(info.buffOK),
            tostring(info.buffSource or "?"), tostring(info.ctxOK), tostring(info.talentOK),
            tostring(info.talentDetail)))
        ns.Print("    cooldown: " .. ((info.cd and info.cd.why) or "?"))
        if ns.ExplainRule then
            local okx, line = pcall(ns.ExplainRule, r, ctx)
            ns.Print("    " .. (okx and line or ("explain failed: " .. tostring(line))))
        end
    end
end
