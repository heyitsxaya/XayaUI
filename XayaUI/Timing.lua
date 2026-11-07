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

-- (core 0.6.75, P2 settings seam) the same CueRulesDB keys, through the core settings view; the tables are kept here and looked up
-- again only when the settings epoch moves (Modules.lua section 0b: no metamethod per hook call)
local CoreS = ns.Settings("core")
local storeT, storeEp = {}, nil
local function Store(key)
    if storeEp ~= ns.settingsEpoch then wipe(storeT); storeEp = ns.settingsEpoch end
    local t = storeT[key]
    if t then return t end
    if not ns.SettingsReady() then return nil end
    t = CoreS[key]
    if type(t) ~= "table" then t = {}; CoreS[key] = t end
    storeT[key], storeEp = t, ns.settingsEpoch
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
    elseif event == CDM_EVENT.Available then self.xuiCdReadyAt = now
    elseif event == CDM_EVENT.ChargeGained then   -- a charge came back (Conditions.lua counts charges in combat with these)
        local l = self.xuiChargeGains
        if not l then l = {}; self.xuiChargeGains = l end
        l[#l + 1] = now
        if #l > 12 then table.remove(l, 1) end
    end
    if ns.MarkStateDirty then ns.MarkStateDirty() end
end
local function OnAuraUpdated(self) self.xuiUpdatedAt = GetTime() end
local function OnReassigned(self)   -- a pooled icon now stands for another spell: its old moments are not this spell's
    self.xuiAppliedAt, self.xuiRemovedAt, self.xuiUpdatedAt, self.xuiCdStartAt, self.xuiCdReadyAt = nil, nil, nil, nil, nil
    self.xuiChargeGains = nil
    self.xuiLastIDs = nil   -- the spell IDs it showed belong to its old spell (Conditions.lua FrameIDs)
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
function T.AuraEstimate(id, detectedAt, frame)
    id = tonumber(id)
    if not id then return nil end
    local fr = frame or (ns.FindCDMFrame and ns.FindCDMFrame(id))   -- frame: the icon that answered (a fallback icon filed under another ID)
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
    -- (the readable label is only built for /xui debug status and snapshots: no string per aura per step in combat)
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
-- 5. Coverage report (/xui debug timing): moved to XayaUI Dev Assist (core 0.6.56; REQUEST-LOG #81), XayaUI_DevAssist/CoreDebug.lua
-------------------------------------------------------------------------------
