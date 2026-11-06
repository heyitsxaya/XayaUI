-------------------------------------------------------------------------------
-- Engine.lua : evaluates rules on events + a light ticker, fires sounds on
-- the false -> true edge, drives visuals.
-------------------------------------------------------------------------------
local addonName, ns = ...

ns.runtime = setmetatable({}, { __mode = "k" }) -- rule -> { active, lastPlay, visualWanted }

local perf = { on = false }   -- /xui debug perf (see the bottom of this file)
local dirty = true
local TICK = 0.2
local MIN_GAP = 0.05   -- events (UNIT_AURA, cooldown updates) fire many times a second in combat; re-evaluating on each one is what costs frames
local acc = 0
local sinceStep = 0
local forceNow = false   -- an edit in the options window re-evaluates at once, without waiting for MIN_GAP
local snapAcc = 0
local inCombat = false   -- kept by the combat events (was asked of the game on every rendered frame)
local SNAP_EVERY = 5   -- seconds between auto status snapshots while in combat
local barsDirty = true   -- action bar spell set is rebuilt only when a bar event fires or rules change

local function RT(rule)
    local rt = ns.runtime[rule]
    if not rt then rt = { active = false, lastPlay = 0 }; ns.runtime[rule] = rt end
    return rt
end

-- Errors are reported once per rule (and saved to the error log); the other rules keep running.
local function ReportRuleError(rule, rt, err)
    if rt.vErrored then return end
    rt.vErrored = true
    ns.Print("rule '" .. tostring(rule.name) .. "' error (the other rules keep running): " .. tostring(err))
    if ns.CaptureError then pcall(ns.CaptureError, "XayaUI rule: " .. tostring(err)) end
end

-- Actions and sounds run guarded per rule: one failing action can neither stop the step nor block the other rules.
local function Guarded(rule, rt, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ReportRuleError(rule, rt, err) end
end
local function RunActionsSafe(rule, rt, phase) if ns.RunActions then Guarded(rule, rt, ns.RunActions, rule, phase) end end
local function PlaySoundSafe(rule, rt)
    -- the game already plays this rule's sound on the aura itself (AuraSound.lua, opt-in): no second copy
    if ns.AuraSound and ns.AuraSound.Owns(rule) then
        if ns.RecSound then ns.RecSound(rule, "left to the game (it plays this sound on the aura itself)") end
        return
    end
    Guarded(rule, rt, function()
        local how, res = ns.PlaySound(ns.EffectiveSound(rule))
        if ns.RecSound then ns.RecSound(rule, how or "no sound picked", res) end   -- (DebugRecord.lua: nothing when its category is off)
    end)
end
local function HasSound(rule) return ns.KindHas(rule, "sound") end
local function SoundNote(rule)
    local s = rule.sound
    return (s and s.enabled and s.value ~= "" and HasSound(rule)) and "  (sound)" or ""
end

-- Does XayaUI want this rule's own display shown this step?
local function DisplayWanted(rule, info, result)
    local v = rule.visual
    if not (v and v.enabled and ns.KindHas(rule, "visual")) then return false end
    local wanted = false
    if v.trigger == "buffActive" then wanted = info and info.present == true or false
    elseif v.trigger == "condition" then wanted = result and true or false end   -- blank / none: nothing is shown
    -- gate: never show while the rule's identifying spell isn't currently on an action bar
    if wanted and v.requireOnBar and ns.SpellOnActionBar then
        local checkID = (rule.spellID and rule.spellID ~= 0) and rule.spellID or rule.buffID
        if not ns.SpellOnActionBar(checkID) then wanted = false end
    end
    return wanted
end

-- One enabled rule: evaluate; fire on the false -> true edge, repeat, clear; actions; its display.
local function StepEnabled(rule, rt, ctx, now)
    local pt = perf.on and debugprofilestop()
    local ok, result, info = pcall(ns.Evaluate, rule, ctx)
    if pt then local d = debugprofilestop() - pt; perf.evalMs = perf.evalMs + d; perf.rule[rule] = (perf.rule[rule] or 0) + d end
    if not ok then
        local err = result
        result, info = false, nil
        if not rt.errored then rt.errored = true; ns.Print("rule '" .. tostring(rule.name) .. "' error: " .. tostring(err)) end
    end
    rt.info = info
    if ns.RecTrigger then ns.RecTrigger(rule, result, info) end   -- trigger detail for chosen rules (DebugRecord.lua; one test when off)
    -- Actions tab: On Initialization (the rule's load conditions hold), During start, After It Ends
    if not rule.parentUid and ns.RunActions and info then
        if info.ctxOK then
            if not rt.inited then rt.inited = true; RunActionsSafe(rule, rt, "init") end
        elseif info.ctxOK == false then rt.inited = nil end
    end
    if result and not rt.active then
        rt.active, rt.lastPlay = true, now
        if not rule.parentUid then RunActionsSafe(rule, rt, "start") end
        if HasSound(rule) then PlaySoundSafe(rule, rt) end
        ns.LogKind("rule", "|cff55ff55FIRED|r %s%s", tostring(rule.name), SoundNote(rule))
    elseif result then
        local rep = rule.repeatSec or 0
        if rep > 0 and (now - rt.lastPlay) >= rep then
            rt.lastPlay = now
            if HasSound(rule) then PlaySoundSafe(rule, rt) end
            ns.LogKind("rule", "repeat  %s", tostring(rule.name))
        end
    else
        if rt.active then
            ns.LogKind("rule", "cleared %s: %s", tostring(rule.name), info and ns.WhyNot(info) or "error")
            if not rule.parentUid then RunActionsSafe(rule, rt, "finish") end
        end
        rt.active = false
    end
    local wanted = DisplayWanted(rule, info, result)
    local was = rt.visualWanted
    rt.visualWanted = wanted
    -- the debug record's "Displays" category: only a change is reported (the first step of a hidden display is not a change)
    if was ~= wanted and (was ~= nil or wanted) and ns.RecDisplay then
        ns.RecDisplay(rule, wanted, ns.EngineOwns and ns.EngineOwns(rule) and true or false)
    end
    local pv = perf.on and debugprofilestop()
    Guarded(rule, rt, ns.SetVisualShown, rule, wanted)
    -- a display the combat engine draws is hidden here, so its text / fade work is skipped, except its companion texts (shield
    -- amount, spell charges: the game's container cannot draw them; Visual.lua draws them over the engine's icon)
    if wanted and (not (ns.EngineOwns and ns.EngineOwns(rule)) or (ns.EngineCompanion and ns.EngineCompanion(rule))) then
        Guarded(rule, rt, ns.UpdateVisualText, rule, info)
    end
    if pv then local d = debugprofilestop() - pv; perf.visMs = perf.visMs + d; perf.rule[rule] = (perf.rule[rule] or 0) + d end
end

-- One disabled rule: finish what it started and hide its display (once).
local function StepDisabled(rule, rt)
    if rt.active and not rule.parentUid then RunActionsSafe(rule, rt, "finish") end
    rt.active, rt.inited = false, nil
    if rt.visualWanted ~= false or rt.shownOnce == nil then
        rt.shownOnce = true
        Guarded(rule, rt, ns.SetVisualShown, rule, false)
    end
    rt.visualWanted = false
end

-- Preview (transient, set from the sidebar eye / headphone icons): force-show the visual and / or loop the sound without
-- touching the rule's own switches or conditions.
local function StepPreview(rule, rt, now)
    if ns.IsPreview(rule, "visual") and ns.KindHas(rule, "visual") then
        rt.visualWanted = true
        ns.SetVisualShown(rule, true)
        ns.UpdateVisualText(rule, rt.info)
    end
    if ns.IsPreview(rule, "sound") and ns.KindHas(rule, "sound") then
        local iv = ((rule.repeatSec or 0) > 0) and math.max(0.5, rule.repeatSec) or 2
        if now - (rt.pvLast or 0) >= iv then
            rt.pvLast = now
            ns.PlaySoundPreview(ns.EffectiveSound(rule))
        end
    else
        rt.pvLast = nil
    end
end

local function StepRule(rule, ctx, now, off)
    local rt = RT(rule)
    if not off then
        rt.offDone = nil
        StepEnabled(rule, rt, ctx, now)
    else
        StepDisabled(rule, rt)
        -- D7: cleaned up once; from then on Step skips it, unless it is being previewed (the step after a preview ends hides it again)
        rt.offDone = not (ns.IsPreview(rule, "visual") or ns.IsPreview(rule, "sound")) or nil
    end
    StepPreview(rule, rt, now)
end

-- D4 / #309 event routing (core 0.6.56; Xaya 2026-11-06: "either way reduce the ms as much as possible. avoid at all costs compromising on
-- performance of rules while minimizing cpu and ram costs"). A cooldown event re-checks only the rules that read cooldowns, a player
-- aura event only the rules that read your auras, on the very next frame (no 50 ms gap). Every other event, and the 0.2 s tick, steps
-- every rule as before. A plain tick (no event pending) skips a rule that reads only your auras when an aura event already re-checked
-- it since the last full step (an aura change always comes with UNIT_AURA; a time-left threshold forces a full step through Timing.lua).
-- What a rule reads (its own triggers, or its parent's for a cue / condition): "cd", "aura", "other" (anything else: tick + events).
local depCache, depVer = setmetatable({}, { __mode = "k" }), nil
local CD_ROWS = { cooldown = true, actionUsable = true, globalCooldown = true }
local function Deps(rule)
    if depVer ~= ns.configVersion then depVer = ns.configVersion; for k in pairs(depCache) do depCache[k] = nil end end
    local d = depCache[rule]
    if d then return d end
    local r = rule
    if rule.parentUid and ns.FindParentRule then r = ns.FindParentRule(rule) or rule end
    d = {}
    if r.useCooldown and (tonumber(r.spellID) or 0) ~= 0 then d.cd = true end
    if r.useBuff and (tonumber(r.buffID) or 0) ~= 0 then d.aura = true end
    local list = type(r.extra) == "table" and type(r.extra.list) == "table" and r.extra.list or nil
    for _, t in ipairs(list or {}) do
        if type(t) == "table" then
            if CD_ROWS[t.type] then d.cd = true elseif t.type == "buffAura" then d.aura = true else d.other = true end
        end
    end
    if not (d.cd or d.aura or d.other) then d.other = true end   -- reads nothing routed (load, talents ...): tick + events, as before
    d.auraOnly = d.aura and not d.cd and not d.other or nil
    depCache[rule] = d
    return d
end
ns.EngineDeps = Deps   -- (tests)
local routed = {}            -- buckets waiting for their next-frame re-check: routed.cd, routed.aura
local auraCheckedAt = setmetatable({}, { __mode = "k" })   -- rule -> GetTime() of its last aura-routed re-check
local stepFilter, stepSkipFresh   -- set for one Step call
local routedFilter = {}           -- reused for every routed re-check (no table per frame)
local lastCtx                     -- the last full step's context, reused by routed re-checks
local lastFullAt                  -- GetTime() of the last full step

local function Step()
    if not ns.rules then return end
    local filter, skipFresh = stepFilter, stepSkipFresh
    if barsDirty and not filter then
        barsDirty = false
        local need = false
        for _, r in ipairs(ns.rules) do if r.enabled and r.visual and r.visual.requireOnBar then need = true; break end end
        if need and ns.RefreshActionBarSpells then ns.RefreshActionBarSpells() end
    end
    -- a routed re-check reuses the last full step's context (load facts change through events that step everything, or at the tick), so
    -- no context table is made per routed frame
    local ctx = (filter and lastCtx) or ns.ReadContext()
    if not filter then lastCtx = ctx end
    ns.tickID = (ns.tickID or 0) + 1
    local now = GetTime()
    -- every rule runs on its own: bad data in one can never delay or block the others
    -- D7 (core 0.6.56): a switched-off rule (or a cue of one) is skipped once it has been cleaned up: no runtime record is made for a rule
    -- that was never on, and nothing of it runs per step, unless it is previewed
    local pvV, pvS = ns.previewSets and ns.previewSets.visual, ns.previewSets and ns.previewSets.sound
    for _, rule in ipairs(ns.rules) do
        local off = ns.RuleOff(rule)
        local rt0 = off and ns.runtime[rule]
        if not off or (rt0 and not rt0.offDone) or (pvV and pvV[rule]) or (pvS and pvS[rule]) then
            local go = true
            if filter then
                local d = Deps(rule)
                go = (filter.cd and d.cd) or (filter.aura and d.aura) or false
                if go and filter.aura and d.aura then auraCheckedAt[rule] = now end
            elseif skipFresh and not off then
                local d = Deps(rule)
                local at = d.auraOnly and auraCheckedAt[rule]
                if at and lastFullAt and at > lastFullAt then go = false end   -- re-checked by an aura event since the last full step
            end
            if go then
                local ok, err = pcall(StepRule, rule, ctx, now, off)
                if not ok then ReportRuleError(rule, RT(rule), err) end
            end
        end
    end
    if filter then return end   -- a routed re-check: the bars and the rest wait for the next full step
    lastFullAt = now
    if ns.Bars_Update then
        local pb = perf.on and debugprofilestop()
        local okb, errb = pcall(ns.Bars_Update)
        if pb then perf.barsMs = perf.barsMs + (debugprofilestop() - pb) end
        if not okb and not ns.barErr then ns.barErr = true; ns.Print("bars error: " .. tostring(errb)) end
    end
end

-- /xui debug perf: measures the engine on this machine. Off by default; while on, each Step is timed with debugprofilestop,
-- split into rule evaluation / visual updates / bars, with the most expensive rules named. Every report is also saved to
-- CueRulesDB.perfLog (last 6) so it survives /reload and can be read from the saved variables.
local function PerfReset()
    perf.steps, perf.total, perf.max, perf.events, perf.t0 = 0, 0, 0, {}, GetTime()
    perf.evalMs, perf.visMs, perf.barsMs, perf.fxMs, perf.fxN = 0, 0, 0, 0, 0
    perf.rule = {}
    perf.paths = {}
    perf.mem0 = collectgarbage("count")
    ns.perfOn = true
end
function ns.PerfAdd(key, ms)   -- other files add their own timings (per-frame effects)
    if not perf.on then return end
    if key == "fx" then perf.fxMs, perf.fxN = perf.fxMs + ms, perf.fxN + 1 end
end
function ns.PerfPath(rule, tag)   -- which duration-text path a rule took this tick (counted while measuring)
    if not perf.on then return end
    local k = tostring(tag)
    perf.paths[k] = (perf.paths[k] or 0) + 1
end
local rawStep = Step
-- One step with its lookup index (Core.lua) and the group layouts it queued; the index is dropped even if the step fails.
local function IndexedStep()
    if ns.Timing then ns.Timing.ClearDeadline() end   -- this step's checks register the next moments anew
    ns.BeginStepIndex()
    if ns.BeginVisualStep then ns.BeginVisualStep() end
    local ok, err = pcall(rawStep)
    if ns.FlushLayouts then pcall(ns.FlushLayouts) end
    ns.EndStepIndex()
    if not ok then error(err, 0) end
end
Step = function()
    if not perf.on then return IndexedStep() end
    local t = debugprofilestop()
    IndexedStep()
    local d = debugprofilestop() - t
    perf.steps, perf.total = perf.steps + 1, perf.total + d
    if d > perf.max then perf.max = d end
end

-- the game's own per-addon CPU meter (C_AddOnProfiler); read-only, no cost to the addons measured
local function AddonCPU()
    local out = {}
    if not (C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric and Enum and Enum.AddOnProfilerMetric and C_AddOns and C_AddOns.GetNumAddOns) then return nil end
    local M = Enum.AddOnProfilerMetric
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and C_AddOns.IsAddOnLoaded(name) then
            local ok, avg = pcall(C_AddOnProfiler.GetAddOnMetric, name, M.RecentAverageTime)
            local ok2, peak = pcall(C_AddOnProfiler.GetAddOnMetric, name, M.PeakTime)
            if ok and type(avg) == "number" then out[#out + 1] = { name = name, avg = avg, peak = (ok2 and type(peak) == "number") and peak or 0 } end
        end
    end
    table.sort(out, function(x, y) return x.avg > y.avg end)
    return out
end

function ns.PerfCommand(arg)
    arg = tostring(arg or ""):lower():match("^%s*(%a*)") or ""
    if arg == "on" or arg == "reset" then
        perf.on = true; PerfReset()
        ns.Print("perf: measuring. Play (ideally a fight), then /xui debug perf to read it, /xui debug perf off to stop.")
        return
    elseif arg == "off" then
        perf.on = false; ns.perfOn = false
        ns.Print("perf: stopped")
        return
    end
    if not perf.t0 then ns.Print("perf: not measuring. /xui debug perf on, play a while, then /xui debug perf."); return end
    local secs = math.max(0.001, GetTime() - perf.t0)
    local steps = math.max(1, perf.steps)
    local ev, parts = perf.events, {}
    for k, n in pairs(ev) do parts[#parts + 1] = ("%s %.1f/s"):format(k, n / secs) end
    table.sort(parts)
    local rules, on = #(ns.rules or {}), 0
    for _, r in ipairs(ns.rules or {}) do if r.enabled then on = on + 1 end end
    local lines = {}
    local function L(fmt, ...) local t = fmt:format(...); lines[#lines + 1] = t; ns.Print(t) end
    L("perf over %.0fs: %d steps (%.1f/s), %.2f ms avg, %.2f ms worst, %.1f%% of one frame budget at 60 fps (%d rules, %d on)",
        secs, perf.steps, perf.steps / secs, perf.total / steps, perf.max, (perf.total / secs) / 10, rules, on)
    L("perf: per second: rules %.2f ms, visuals %.2f ms, bars %.2f ms, per-frame effects %.2f ms (%d calls)",
        perf.evalMs / secs, perf.visMs / secs, perf.barsMs / secs, perf.fxMs / secs, perf.fxN)
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
    if type(CueRulesDB) == "table" then
        local log = CueRulesDB.perfLog
        if type(log) ~= "table" then log = {}; CueRulesDB.perfLog = log end
        log[#log + 1] = { at = date("%Y-%m-%d %H:%M:%S"), build = ns.version or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("XayaUI", "Version")), combat = (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false, lines = lines }
        while #log > 6 do table.remove(log, 1) end
    end
end

ns.Step = function() return Step() end

-- (ns.configVersion: settings changed, so memos keyed on settings - load checks - start over)
function ns.MarkDirty() dirty = true; forceNow = true; barsDirty = true; ns.configVersion = (ns.configVersion or 0) + 1; ns.Fire("EDITED") end
-- game state changed (a cast, movement, target ...): re-evaluate on the next step, keeping the minimum gap between steps
function ns.MarkStateDirty() dirty = true end

function ns.OnDBReady()
    ns.RefreshAllVisuals()
    if ns.Bars_OnDBReady then ns.Bars_OnDBReady() end
    dirty = true
end

local f = CreateFrame("Frame")
for _, e in ipairs({
    "PLAYER_ENTERING_WORLD", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED", "SPELLS_CHANGED",
    "ACTIONBAR_SLOT_CHANGED", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_PAGE_CHANGED", "UPDATE_SHAPESHIFT_FORM",
    -- a new target / focus changes every "Target Debuff (yours)" answer at once: step now instead of at the next tick
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
}) do f:RegisterEvent(e) end
f:RegisterUnitEvent("UNIT_AURA", "player")
f:SetScript("OnEvent", function(_, event)
    if perf.on then perf.events[event] = (perf.events[event] or 0) + 1 end
    if event == "UNIT_AURA" then ns.lastAuraEventAt = GetTime() end   -- (Conditions.lua stamps an aura's appearance with it)
    if event == "PLAYER_ENTERING_WORLD" then
        if ns.ClearSecrecyCache then ns.ClearSecrecyCache() end
        inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false   -- a /reload can land mid-fight
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" then ns.talentList = nil; ns.spellList = nil end
    -- auto-capture status into the ring-buffer log at combat start/end, since /xui debug status can't be typed mid-fight
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        snapAcc = 0
        if ns.LogStatusSnapshot then ns.LogStatusSnapshot("combat start") end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        if ns.LogStatusSnapshot then ns.LogStatusSnapshot("combat end") end
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" or event == "ACTIONBAR_PAGE_CHANGED" then barsDirty = true end
    -- D4: cooldown and player-aura events re-check only the rules that read them, on the next frame (no full step)
    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then routed.cd = true; return end
    if event == "UNIT_AURA" then routed.aura = true; return end
    dirty = true
end)
-- A failing step must never stop the engine or flood the error window: it is caught here, reported once per distinct
-- message (and saved to the error log), and the next step runs as normal.
local lastStepErr
local function SafeStep()
    local ok, err = pcall(Step)
    if not ok then
        err = tostring(err)
        if err ~= lastStepErr then
            lastStepErr = err
            if ns.Print then ns.Print("engine step error (the engine keeps running): " .. err) end
            if ns.CaptureError then pcall(ns.CaptureError, "XayaUI engine: " .. err) end
        end
    end
end
local Timing = ns.Timing
f:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    sinceStep = sinceStep + elapsed
    -- a time-left threshold ("2 s left") is crossed on this frame: step now, not at the next tick (Timing.lua deadlines)
    if Timing and GetTime() >= Timing.NextDeadline() then dirty, forceNow = true, true; Timing.ClearDeadline() end
    if acc >= TICK or (dirty and (forceNow or sinceStep >= MIN_GAP)) then
        -- a plain tick (nothing changed, no aura event waiting) may skip aura rules an aura event just re-checked
        stepSkipFresh = not dirty and not routed.aura
        dirty, forceNow = false, false
        acc, sinceStep = 0, 0
        routed.cd, routed.aura = nil, nil   -- a full step covers them
        SafeStep()
        stepSkipFresh = nil
    elseif routed.cd or routed.aura then
        -- D4: the rules that read what changed, this frame (at most once per frame); the full step keeps its own pace
        routedFilter.cd, routedFilter.aura = routed.cd, routed.aura
        stepFilter = routedFilter
        routed.cd, routed.aura = nil, nil
        SafeStep()
        stepFilter = nil
    end
    if inCombat then
        snapAcc = snapAcc + elapsed
        if snapAcc >= SNAP_EVERY then
            snapAcc = 0
            if ns.LogStatusSnapshot then ns.LogStatusSnapshot("combat tick") end
        end
    else
        snapAcc = 0
    end
end)
