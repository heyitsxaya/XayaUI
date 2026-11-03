-------------------------------------------------------------------------------
-- Timing.lua : the duration engine. Gives every cue an aura's or cooldown's time left in combat, as exactly as the game allows.
--
-- In combat the game hides aura and cooldown numbers from addons (secret values): they can be drawn by the game's own widgets
-- (the combat engine does that for icons, time text and drains), but addon code can never compare them, so a sound, a speech
-- or a condition such as "2 s left" could not fire. This file answers "time left" for that addon code, best source first:
--
--   1. readable numbers (out of combat, and auras the game never hides)          -> exact
--   2. the game's duration object, when it answers with a plain number             -> exact
--   3. an anchored estimate:
--        start = the exact moment Blizzard's Cooldown Manager reports the aura applied / the cooldown started (its icons call
--                TriggerAlertEvent / TriggerAuraAppliedAlert in the game's own code, in combat too; hooked here, read-only),
--                moved to your latest cast of it (a refresh), else the moment the engine first saw it;
--        length = the duration measured the last time the game showed it readable (kept per aura / spell, re-measured
--                 every time it is readable again, so talent and gear changes are picked up), else the timing model's parse;
--        end   = the exact moment the Cooldown Manager reports it removed (or the engine sees it gone).
--   Threshold conditions ("2 s left") are not left to the 0.2 s engine tick: each one registers the moment it will be crossed
--   (T.Deadline) and Engine.lua steps on that very frame.
--
-- Hooks are post-hooks (hooksecurefunc): they only note GetTime(), never change or call anything of Blizzard's.
-------------------------------------------------------------------------------
local _, ns = ...
local T = {}
ns.Timing = T

local issecret = issecretvalue or function() return false end
local CDM_EVENT = Enum and Enum.CooldownViewerAlertEventType or {}

local function Store(key)
    if type(CueRulesDB) ~= "table" then return nil end
    local t = CueRulesDB[key]
    if type(t) ~= "table" then t = {}; CueRulesDB[key] = t end
    return t
end
function T.LearnedAura() return Store("learnedAuraDur") end
function T.LearnedCooldown() return Store("learnedCooldown") end

-------------------------------------------------------------------------------
-- 1. Exact moments from the Cooldown Manager's icons
-------------------------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" })

local function OnAlertEvent(self, event)
    local now = GetTime()
    if event == CDM_EVENT.OnAuraApplied then self.xuiAppliedAt, self.xuiRemovedAt = now, nil
    elseif event == CDM_EVENT.OnAuraRemoved then self.xuiRemovedAt = now
    elseif event == CDM_EVENT.OnCooldown then self.xuiCdStartAt, self.xuiCdReadyAt = now, nil
    elseif event == CDM_EVENT.Available then self.xuiCdReadyAt = now end
    if ns.MarkStateDirty then ns.MarkStateDirty() end
end
local function OnAuraUpdated(self) self.xuiUpdatedAt = GetTime() end
local function OnReassigned(self)   -- a pooled icon now stands for another spell: its old moments are not this spell's
    self.xuiAppliedAt, self.xuiRemovedAt, self.xuiUpdatedAt, self.xuiCdStartAt, self.xuiCdReadyAt = nil, nil, nil, nil, nil
end

-- Called for every Cooldown Manager icon the condition reader indexes (Conditions.lua BuildCDMIndex).
function T.HookFrame(fr)
    if hooked[fr] or not hooksecurefunc or type(fr) ~= "table" then return end
    hooked[fr] = true
    if fr.TriggerAlertEvent then pcall(hooksecurefunc, fr, "TriggerAlertEvent", OnAlertEvent) end
    if fr.OnUnitAuraUpdatedEvent then pcall(hooksecurefunc, fr, "OnUnitAuraUpdatedEvent", OnAuraUpdated) end
    if fr.OnCooldownIDSet then pcall(hooksecurefunc, fr, "OnCooldownIDSet", OnReassigned) end
end

-------------------------------------------------------------------------------
-- 2. Learning lengths whenever the game shows them
-------------------------------------------------------------------------------
-- (auras: Conditions.lua stores learnedAuraDur when an aura's duration is readable)
function T.LearnCooldown(spellID, duration, onGCD)
    if onGCD or type(spellID) ~= "number" or type(duration) ~= "number" or issecret(duration) or duration <= 1.6 then return end
    local L = T.LearnedCooldown()
    if L then L[spellID] = duration end
end

-------------------------------------------------------------------------------
-- 3. Estimates
-------------------------------------------------------------------------------
local function CastWindow(id)
    local M = ns.AuraModel
    return M and M.WindowFor and M.WindowFor(id) or nil
end

-- Time left on a buff the game hides. Returns expiration, duration, label (nil when no estimate can be made).
function T.AuraEstimate(id, detectedAt)
    id = tonumber(id)
    if not id then return nil end
    local fr = ns.FindCDMFrame and ns.FindCDMFrame(id)
    local start, label
    if fr and fr.xuiAppliedAt and not (fr.xuiRemovedAt and fr.xuiRemovedAt >= fr.xuiAppliedAt) then
        start, label = fr.xuiAppliedAt, "applied (Cooldown Manager)"
    end
    local w = CastWindow(id)
    if w and w.start and (not start or w.start > start + 0.05) then start, label = w.start, "your cast" end   -- a refresh
    if not start and detectedAt then start, label = detectedAt, "first seen" end
    if not start then return nil end
    local L = T.LearnedAura()
    local dur, how = L and L[id], "measured"
    if not (type(dur) == "number" and dur > 0) and w and w.dur then dur, how = w.dur, "from the spell text" end
    if not (type(dur) == "number" and dur > 0) then return nil end
    -- (the readable label is only built for /xui status and snapshots: no string per aura per step in combat)
    return start + dur, dur, ns.statusDetail and string.format("estimate: %s + %s %.1fs", label, how, dur) or "estimate"
end

-- Time left on a cooldown the game hides. Returns ready time, duration, label (nil when unknown).
function T.CooldownEstimate(spellID)
    spellID = tonumber(spellID)
    if not spellID then return nil end
    local fr = ns.FindCDMFrame and ns.FindCDMFrame(spellID)
    if not (fr and fr.xuiCdStartAt) then return nil end
    if fr.xuiCdReadyAt and fr.xuiCdReadyAt >= fr.xuiCdStartAt then return fr.xuiCdReadyAt, 0, "ready (Cooldown Manager)" end
    local L = T.LearnedCooldown()
    local dur = L and L[spellID]
    if not (type(dur) == "number" and dur > 0) then return nil end
    return fr.xuiCdStartAt + dur, dur, ns.statusDetail and string.format("estimate: started (Cooldown Manager) + measured %.1fs", dur) or "estimate"
end

-------------------------------------------------------------------------------
-- 4. Deadlines: the next moment a threshold will be crossed; Engine.lua steps on that frame
-------------------------------------------------------------------------------
local nextDeadline = math.huge
function T.Deadline(t)
    if type(t) == "number" and not issecret(t) and t < nextDeadline and t > GetTime() then nextDeadline = t end
end
function T.NextDeadline() return nextDeadline end
function T.ClearDeadline() nextDeadline = math.huge end

-------------------------------------------------------------------------------
-- 5. Coverage: for every rule whose cues depend on time or stacks, how it gets them in combat
-------------------------------------------------------------------------------
local TIME_REFS = { ["n:buffRemain"] = "aura time left", ["n:cdRemain"] = "cooldown time left", ["n:buffStacks"] = "aura stacks", ["n:cdCharges"] = "charges" }

local function Needs(p)
    local needs = {}
    for _, c in ipairs(ns.ConditionsOf and ns.ConditionsOf(p) or {}) do
        if c.enabled ~= false and type(c.when) == "table" and type(c.when.list) == "table" then
            for _, t in ipairs(c.when.list) do if TIME_REFS[t.ref] then needs[t.ref] = true end end
        end
    end
    local displays = { p }
    for _, c in ipairs(ns.CuesOf and ns.CuesOf(p) or {}) do displays[#displays + 1] = c end
    for _, d in ipairs(displays) do
        local v = d.visual
        if v and v.enabled then
            if (v.text and v.text.enabled) or (v.fill and v.fill.enabled) or v.fadeGrey or v.fadeAlpha or (v.flash and v.flash.enabled) then
                needs.display = needs.display or d
            end
            if v.count and v.count.enabled then needs.displayCount = true end
        end
    end
    return needs
end

-- One line per rule; nothing is left unsaid.
function T.Report()
    local P = ns.Print or print
    local rows, ok, warn = {}, 0, 0
    for _, p in ipairs(ns.rules or {}) do
        if not p.parentUid and p.enabled ~= false then
            local needs = Needs(p)
            if next(needs) then
                local parts, bad = {}, false
                local buff = tonumber(p.buffID) or 0
                local spell = tonumber(p.spellID) or 0
                local owned = ns.EngineOwns and needs.display and ns.EngineOwns(needs.display)
                if needs.display then
                    if owned then parts[#parts + 1] = "display: drawn by the game (exact)"
                    else parts[#parts + 1] = "display: XayaUI, using the time below" end
                end
                if needs["n:buffRemain"] or (needs.display and not owned) then
                    if buff == 0 then parts[#parts + 1] = "aura time: no aura on this rule"
                    elseif ns.AuraTrackable and ns.AuraTrackable(buff) then parts[#parts + 1] = "aura time: exact (the game never hides this aura)"
                    else
                        local inCDM = ns.FindCDMFrame and ns.FindCDMFrame(buff)
                        local L = T.LearnedAura()
                        local learned = L and L[buff]
                        if not inCDM then bad = true; parts[#parts + 1] = "aura time: NOT in combat - add this buff to Blizzard's Cooldown Manager (Tracked Buffs)"
                        elseif not learned then bad = true; parts[#parts + 1] = "aura time: needs the buff once out of combat to measure its length"
                        else parts[#parts + 1] = string.format("aura time: estimate from the exact start + measured %.1fs", learned) end
                    end
                end
                if needs["n:cdRemain"] then
                    local Lc = T.LearnedCooldown()
                    if spell == 0 then parts[#parts + 1] = "cooldown time: no spell on this rule"
                    elseif not (ns.FindCDMFrame and ns.FindCDMFrame(spell)) then bad = true; parts[#parts + 1] = "cooldown time: NOT in combat if hidden - add the spell to the Cooldown Manager"
                    elseif not (Lc and Lc[spell]) then bad = true; parts[#parts + 1] = "cooldown time: needs one use out of combat to measure it"
                    else parts[#parts + 1] = string.format("cooldown time: exact when shown, else estimate (measured %.1fs)", Lc[spell]) end
                end
                if needs["n:buffStacks"] then bad = true; parts[#parts + 1] = "aura stacks: the game hides stack counts in combat, so a condition on stacks cannot fire there (the display still shows them)" end
                if needs["n:cdCharges"] then parts[#parts + 1] = "charges: exact when shown" end
                if bad then warn = warn + 1 else ok = ok + 1 end
                rows[#rows + 1] = { bad, tostring(p.name) .. ": " .. table.concat(parts, "; ") }
            end
        end
    end
    P(string.format("timing in combat: %d rule%s covered, %d need%s attention.", ok, ok == 1 and "" or "s", warn, warn == 1 and "s" or ""))
    for _, r in ipairs(rows) do if r[1] then P("  ! " .. r[2]) end end
    for _, r in ipairs(rows) do if not r[1] then P("    " .. r[2]) end end
end
