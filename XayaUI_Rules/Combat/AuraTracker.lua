-- XayaUI: AuraTracker -- layered, evidence-ranked presence tracking for player buffs while the game hides them.
--
-- Design doc: claude/XAYAUI-AURA-TRACKING-DESIGN-2026-11-01.md (project docs).  Summary of what this file does:
--
--   ns.BuffPresent (Conditions.lua) asks the game first (aura API, Cooldown Manager frame).  Those answers are EXACT and are
--   passed to T.Observe.  Only when the game says "unknown" (auras are secret) does it call T.Resolve(id), which ranks the
--   remaining evidence:
--
--     1. consumed:  a cast the player registered as consuming this aura (user rule, nothing is shipped).
--     2. ID diff:   the set of aura instance IDs on the player before/after a readable cast; a new ID is linked to the aura the
--                   cast is expected to cause, and the aura is "present" while that ID stays in the list.  Enabled only if the
--                   game actually returns readable IDs while restricted (capability is detected at runtime, never assumed).
--     3. latest-evidence estimate: the cast-anchored model window (AuraModel) versus the last EXACT read before combat
--                   ("seed", absolute expiration).  Whichever evidence is more recent wins.
--     4. unknown:   nothing credible; the caller treats it as unknown (rules do not fire on unknown).
--
--   An estimate may say "up"; it never says "down".  Only exact evidence (a real read, or a linked ID that left the list for two
--   consecutive snapshots) says "down".  Every answer carries its source in the returned text so the status screen shows
--   whether a rule ran on something exact or on an estimate.
--
--   Shadow mode: when an estimate episode ends because an exact read arrives, the estimate is scored against the truth
--   (ok / early removal missed / extension missed, and expiration error) into CueRulesDB.auraTracker.shadow.  This is how the
--   unvalidated parts (haste, extensions, carry-over, set bonuses) get measured on real play instead of guessed.
--
--   CPU: no OnUpdate, no timers while idle.  Observe/Resolve are table lookups.  The aura-ID list is read only (a) around
--   casts of spells some rule is watching and (b) at most every 0.2 s while a linked ID exists and a rule asks.
--
-- Secret-value safety: values of unknown secrecy are only tested with issecretvalue/type; never compared, formatted or used as
-- table keys before that test.  Every game call is pcall-wrapped.
local _, ns = ...; ns = XayaUI_NS or ns -- part of XayaUI core since 0.6.0 (Combat/); shares its namespace

-- Loaded once: XayaUI itself loads the engine files (XayaUI.toc), so pulling the repo is enough; an old separate
-- XayaUI_CombatEngine folder (installed before 0.6.0) finds this and steps aside (no double load).
ns.engineFiles = ns.engineFiles or {}
if ns.engineFiles.AuraTracker then return end
ns.engineFiles.AuraTracker = true
local T = {}
ns.AuraTracker = T

local issecret = issecretvalue or function() return false end
local GetTime = GetTime
local pcall, type, pairs, ipairs, tostring, tonumber = pcall, type, pairs, ipairs, tostring, tonumber
local tinsert, tsort = table.insert, table.sort

local LOST_FALSE_SECONDS = 20     -- how long a vanished linked ID keeps answering "absent" before it decays to unknown
local PRUNE_AFTER = 180           -- forget auras nobody has asked about for this long
local SNAP_MIN_INTERVAL = 0.2     -- minimum spacing between aura-ID list reads
local MISSING_SNAPS = 2           -- consecutive fresh snapshots without the linked ID before it counts as gone
local MAX_NEW_IDS = 5             -- a cast that makes more new IDs than this is too noisy to link
local LINK_DELAYS = { 0.15, 0.6 } -- when to look for the new ID after a cast
local WATCH_SECONDS = 30          -- a rule must have asked about an aura this recently for a cast to be worth a snapshot
local OVERSTAY_GRACE = 3          -- seconds past the expected end before an ambiguous link is dropped

-------------------------------------------------------------------------------
-- Storage (inside CueRulesDB, no new SavedVariable)
-------------------------------------------------------------------------------
-- (core 0.6.75, P2 settings seam) the same CueRulesDB.auraTracker, through the core settings view; read on every aura event, so the
-- table is kept in an upvalue and looked up again only when the settings epoch moves (Modules.lua section 0b)
local CoreS = ns.Settings("core")
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("core", "XayaUI_Rules", "XayaUIRulesDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)
local dbT, dbEp
local function DB()
    local d = dbT
    if dbEp ~= ns.settingsEpoch or type(d) ~= "table" then
        if not ns.SettingsReady("core") then return nil end
        d = CoreS.auraTracker
        if type(d) ~= "table" then d = { v = 1 }; CoreS.auraTracker = d end
        dbT, dbEp = d, ns.settingsEpoch
    end
    d.settings = d.settings or {}
    d.shadow = d.shadow or {}
    d.consumers = d.consumers or {}
    return d
end
local function Setting(k, default)
    local d = DB()
    if not d then return default end
    local v = d.settings[k]
    if v == nil then return default end
    return v
end
function T.SetSetting(k, v) local d = DB(); if d then d.settings[k] = v end end
function T.Enabled() return Setting("enabled", true) ~= false end
function T.IdDiffEnabled() return Setting("idDiff", true) ~= false end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local S = {}                       -- [auraID] = state
local cap = { ids = nil, dataSpell = nil, note = nil }   -- ids: "readable" | "secret" | "error" | nil (untested)
T.cap = cap
local stats = { linksMade = 0, linksLost = 0, linksDropped = 0, snaps = 0, noisy = 0, refused = 0, consumed = 0 }
T.stats = stats
local combat = { on = false, t0 = nil }
local snap = nil                   -- last aura-ID list { t, set, n }
local pre = {}                     -- [castID] = snapshot taken at UNIT_SPELLCAST_SENT
local lastPrune = 0

local function Restricted()
    if ns.AurasRestricted then
        local ok, r = pcall(ns.AurasRestricted)
        return ok and r and true or false
    end
    return false
end

local function Model() return ns.AuraModel end

local function State(id)
    local s = S[id]
    if not s then s = { id = id, ref = {}, queriedAt = 0, unknownAt = 0, lastKind = nil }; S[id] = s end
    return s
end

local function Prune(now)
    if now - lastPrune < 60 then return end
    lastPrune = now
    for id, s in pairs(S) do
        if now - (s.queriedAt or 0) > PRUNE_AFTER and not s.link and not s.ep then S[id] = nil end
    end
end

-------------------------------------------------------------------------------
-- Shadow records (bounded)
-------------------------------------------------------------------------------
local function Shadow(id)
    local d = DB()
    if not d then return nil end
    local r = d.shadow[id]
    if not r then
        local n = 0
        for _ in pairs(d.shadow) do n = n + 1 end
        if n >= 300 then      -- drop the stalest record
            local oldK, oldT
            for k, v in pairs(d.shadow) do if not oldT or (v.last or 0) < oldT then oldK, oldT = k, v.last or 0 end end
            if oldK then d.shadow[oldK] = nil end
        end
        r = {}
        d.shadow[id] = r
    end
    r.last = time and time() or 0
    return r
end

local function Inc(r, k, by) r[k] = (r[k] or 0) + (by or 1) end

-------------------------------------------------------------------------------
-- Aura-ID list (capability detected at runtime)
-------------------------------------------------------------------------------
local function SaveCap()
    local d = DB()
    if d then d.cap = { ids = cap.ids, dataSpell = cap.dataSpell, note = cap.note, build = select(4, GetBuildInfo()) or 0 } end
end

-- Returns { t, set, n } or nil.  Classifies the capability only while auras are actually restricted: out of combat the list is
-- always readable, which would say nothing about combat.
local function Snap(force)
    if cap.ids == "secret" or cap.ids == "error" then return nil end
    local now = GetTime()
    if snap and not force and now - snap.t < SNAP_MIN_INTERVAL then return snap end
    local api = C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs
    local restricted = Restricted()
    if not api then
        if restricted then cap.ids, cap.note = "error", "GetUnitAuraInstanceIDs missing"; SaveCap() end
        return nil
    end
    stats.snaps = stats.snaps + 1
    local ok, ids = pcall(api, "player", "HELPFUL")      -- the API requires the filter argument (unit, filter [, maxCount, sortRule, sortDirection])
    if not ok then
        if restricted then cap.ids, cap.note = "error", "call refused: " .. tostring(ids):sub(1, 90); SaveCap() end
        return nil
    end
    if type(ids) ~= "table" or issecret(ids) then
        if restricted then cap.ids, cap.note = "secret", "list is secret"; SaveCap() end
        return nil
    end
    local set, n, sec = {}, 0, 0
    local okL = pcall(function()
        for i = 1, #ids do
            local v = ids[i]
            if issecret(v) then sec = sec + 1
            elseif type(v) == "number" then set[v] = true; n = n + 1 end
        end
    end)
    if not okL or sec > 0 then
        if restricted then cap.ids, cap.note = "secret", "IDs are secret values"; SaveCap() end
        return nil
    end
    if restricted and cap.ids ~= "readable" then cap.ids, cap.note = "readable", "IDs readable while restricted"; SaveCap() end
    snap = { t = now, set = set, n = n }
    return snap
end

local function IdDiffUsable()
    return T.Enabled() and T.IdDiffEnabled() and cap.ids ~= "secret" and cap.ids ~= "error"
end

-------------------------------------------------------------------------------
-- Linking: a new aura-instance ID after a readable cast belongs to the aura that cast causes
-------------------------------------------------------------------------------
local function RelevantTargets(castID)
    local M = Model()
    if not (M and M.CastTargets) then return nil end
    local now = GetTime()
    local list
    for _, aid in ipairs(M.CastTargets(castID)) do
        local s = S[aid]
        if s and now - s.unknownAt < WATCH_SECONDS then list = list or {}; list[#list + 1] = aid end
    end
    return list
end

local function ClaimedBy(exceptAura)
    local claimed = {}
    for aid, s in pairs(S) do
        if aid ~= exceptAura and s.link and not s.link.lost then
            for iid in pairs(s.link.ids) do claimed[iid] = aid end
        end
    end
    return claimed
end

-- Keep only IDs that could be this aura.  If the game lets us read the spell ID of an instance in combat, that settles it.
local function Refine(ids, auraID)
    local api = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
    local yes, unknown = {}, {}
    for _, iid in ipairs(ids) do
        local verdict
        if api then
            local ok, data = pcall(api, "player", iid)
            if ok and type(data) == "table" and not issecret(data) then
                local oks, sid = pcall(function() return data.spellId end)
                if oks and type(sid) == "number" and not issecret(sid) then
                    cap.dataSpell = "readable"
                    verdict = (sid == auraID) and "yes" or "no"
                elseif oks and issecret(sid) and cap.dataSpell ~= "readable" then
                    cap.dataSpell = "secret"
                end
            end
        end
        if verdict == "yes" then yes[#yes + 1] = iid
        elseif verdict == nil then unknown[#unknown + 1] = iid end
    end
    if #yes > 0 then return yes, "spell" end
    return unknown, nil
end

local function MakeLink(castID, ids, quality, auraID)
    local L = { ids = {}, n = 0, cast = castID, t0 = GetTime(), q = quality, missing = 0, lost = false, confirmed = 0 }
    for _, iid in ipairs(ids) do L.ids[iid] = true; L.n = L.n + 1 end
    L.src = ("ID diff (%s link, cast %d)"):format(quality, castID)
    L.srcLost = ("ID diff: linked aura ID left the list (cast %d)"):format(castID)
    L.firstID = ids[1]
    return L
end

local function ConfirmLink(castID, rel, before)
    if not (IdDiffUsable() and Restricted()) then return end
    local after = Snap(true)
    if not after then return end
    local now = GetTime()
    for _, aid in ipairs(rel) do
        local s = S[aid]
        if s then
            local claimed = ClaimedBy(aid)
            local fresh = {}
            for iid in pairs(after.set) do
                if not before.set[iid] and not claimed[iid] and not (s.link and s.link.ids[iid]) then fresh[#fresh + 1] = iid end
            end
            if #fresh > 0 then
                if #fresh > MAX_NEW_IDS then
                    stats.noisy = stats.noisy + 1
                else
                    tsort(fresh)
                    local ids, how = Refine(fresh, aid)
                    if #ids > 0 then
                        local q = how or ((#rel == 1) and (#ids == 1 and "sole" or "group") or "ambiguous")
                        local L = s.link
                        if L and not L.lost and L.cast == castID and now - L.t0 < 2 then
                            for _, iid in ipairs(ids) do if not L.ids[iid] then L.ids[iid] = true; L.n = L.n + 1 end end
                        else
                            s.link = MakeLink(castID, ids, q, aid)
                            stats.linksMade = stats.linksMade + 1
                        end
                    else
                        stats.refused = stats.refused + 1
                    end
                end
            end
        end
    end
end

-- Presence of a linked aura from the latest list.  Returns "present", "lost" or nil (no usable link).
local function LinkStatus(s, now)
    local L = s.link
    if not L then return nil end
    local M = Model()
    if L.lost then
        if now - L.lostAt > LOST_FALSE_SECONDS then s.link = nil; return nil end
        return "lost"
    end
    local sn = Snap()
    if sn then
        if sn.t ~= L.lastSnapT then
            L.lastSnapT = sn.t
            local any = false
            for iid in pairs(L.ids) do if sn.set[iid] then any = true; break end end
            if any then
                L.missing = 0
            else
                L.missing = L.missing + 1
                if L.missing >= MISSING_SNAPS then
                    L.lost, L.lostAt = true, now
                    stats.linksLost = stats.linksLost + 1
                    local win = M and M.WindowFor and M.WindowFor(s.id)
                    local r = Shadow(s.id)
                    if r then
                        Inc(r, "idGone")
                        if win and win.expiry - now > 0.5 then Inc(r, "idGoneEarly"); Inc(r, "idGoneEarlyBy", win.expiry - now)
                        else Inc(r, "idGoneOnTime") end
                    end
                    if M and M.CloseWindow then M.CloseWindow(s.id) end
                    return "lost"
                end
            end
        end
    end
    -- An ambiguous link that outlives the expected end is more likely an unrelated aura: drop it, do not trust it.
    local dur = M and M.Resolve and (M.Resolve(s.id) or {}).seconds
    if dur and dur > 0 then
        local over = now - (L.t0 + dur)
        if over > OVERSTAY_GRACE and L.q ~= "sole" and L.q ~= "spell" then
            s.link = nil; stats.linksDropped = stats.linksDropped + 1; return nil
        end
        L.suspect = over > math.max(5, dur * 0.5)
    end
    return "present"
end

-------------------------------------------------------------------------------
-- Estimate episodes (shadow scoring)
-------------------------------------------------------------------------------
local function EpisodeStart(s, kind, expiry)
    local ep = s.ep
    if not ep then ep = { kind = kind, t0 = GetTime(), maxExp = 0 }; s.ep = ep end
    ep.kind = kind
    if expiry and expiry > ep.maxExp then ep.maxExp = expiry end
    ep.lastExp = expiry or ep.lastExp
end

local function CloseEpisode(s, presentExact, ref, now)
    local ep = s.ep
    s.ep = nil
    if not ep then return end
    local r = Shadow(s.id)
    if not r then return end
    Inc(r, "eps")
    if presentExact then
        if ep.maxExp > 0 and now > ep.maxExp + 0.5 then
            Inc(r, "extMissed")         -- the estimate had ended but the aura was still up (refresh/extension/proc not seen)
        else
            Inc(r, "ok")
            if type(ref) == "table" and type(ref.expiration) == "number" and ep.lastExp then
                local err = math.abs(ep.lastExp - ref.expiration)
                Inc(r, "expErrN"); Inc(r, "expErrSum", err)
                if err > (r.expErrMax or 0) then r.expErrMax = err end
            end
        end
    else
        if ep.maxExp > 0 and now < ep.maxExp - 0.5 then
            Inc(r, "earlyMissed"); Inc(r, "earlyMissedBy", ep.maxExp - now)   -- estimate said up, the aura was already gone
        else
            Inc(r, "ok")
        end
    end
end

-------------------------------------------------------------------------------
-- Public: exact observations (called by ns.BuffPresent for true/false only)
-------------------------------------------------------------------------------
function T.Observe(id, present, src, ref)
    if present == nil or not T.Enabled() then return end
    local now = GetTime()
    local s = State(id)
    s.queriedAt = now
    if s.ep then CloseEpisode(s, present, ref, now) end
    local ex = s.exact
    if not ex then ex = {}; s.exact = ex end
    ex.present, ex.t = present, now
    ex.exp, ex.dur, ex.iid = nil, nil, nil
    s.consumedAt = nil
    if present then
        if type(ref) == "table" then
            if type(ref.expiration) == "number" and not issecret(ref.expiration) then ex.exp = ref.expiration end
            if type(ref.duration) == "number" and not issecret(ref.duration) then ex.dur = ref.duration end
            local iid = ref.instanceID
            if type(iid) == "number" and not issecret(iid) then ex.iid = iid end
        end
        local L = s.link
        if L and ex.iid then
            if L.ids[ex.iid] then L.confirmed = L.confirmed + 1
            else
                L.mismatch = (L.mismatch or 0) + 1
                local r = Shadow(id); if r then Inc(r, "linkMismatch") end
            end
        end
        if L and L.lost then       -- the game says it is up after all: the link misled us
            local r = Shadow(id); if r then Inc(r, "linkFalseGone") end
            s.link = nil
        end
    else
        s.link = nil
    end
    Prune(now)
end

-------------------------------------------------------------------------------
-- Public: unknown from the game -> rank the remaining evidence
-- Returns handled, present, src, ref.  handled == false means "no credible evidence; leave it unknown".
-------------------------------------------------------------------------------
local function Wipe(t) for k in pairs(t) do t[k] = nil end return t end

function T.Resolve(id)
    local now = GetTime()
    local s = State(id)
    s.queriedAt, s.unknownAt = now, now
    local M = Model()
    if not M then s.lastKind = "none"; return false end
    -- audit D28 (core 0.6.67): "Estimate buffs the game hides in combat" unticked: no estimate of any kind (the aura-ID link, the
    -- seeded last read and the cast window all estimate); the answer stays unknown, as the tick box says. Before, only the cast-window
    -- estimate was switched off. (The cast events stay: they also feed the out-of-combat duration learning.)
    if M.PresenceEnabled and not M.PresenceEnabled() then s.lastKind = "off"; return false end

    if not T.Enabled() then            -- tracker off: behave exactly like the plain model
        local okM, eP, eRef, eNote = pcall(M.EstimatePresent, id)
        if okM and eP then s.lastKind = "model"; return true, true, "model estimate (" .. tostring(eNote) .. ")", eRef end
        s.lastKind = "unknown"; return false
    end

    -- 1. consumed by a registered consumer cast, and nothing newer contradicts it
    if s.consumedAt then
        local win = M.WindowFor and M.WindowFor(id)
        if (win and win.start > s.consumedAt) or now - s.consumedAt > LOST_FALSE_SECONDS then
            s.consumedAt = nil
        else
            s.lastKind = "consumed"
            return true, false, ("consumed by cast %s"):format(tostring(s.consumedBy)), nil
        end
    end

    -- 2. aura-ID link
    if s.link then
        local st = LinkStatus(s, now)
        if st == "lost" then
            s.lastKind = "link-lost"
            return true, false, s.link.srcLost, nil
        elseif st == "present" then
            local L = s.link
            local ref = Wipe(s.ref)
            ref.instanceID = L.firstID
            local win = M.WindowFor and M.WindowFor(id)
            if win and win.expiry > now then
                ref.expiration, ref.duration, ref.estimated, ref.timeSource = win.expiry, win.dur, true, "model + ID diff"
            else
                ref.estimated, ref.timeSource = true, "ID diff (no timer)"
            end
            EpisodeStart(s, "link", ref.expiration)
            s.lastKind = "link"
            return true, true, L.src .. (L.suspect and " [past expected end]" or ""), ref
        end
    end

    -- 3. latest evidence: model window versus the last exact read (seed)
    local win = M.WindowFor and M.WindowFor(id)
    if win and win.expiry <= now then win = nil; if M.CloseWindow then M.CloseWindow(id) end end
    local ex = s.exact
    local seed = ex and ex.present and ex.exp and ex.exp > now
    if win and (not seed or win.start >= ex.t) then
        local okM, eP, eRef, eNote = pcall(M.EstimatePresent, id)
        if okM and eP then
            EpisodeStart(s, "model", eRef and eRef.expiration)
            s.lastKind = "model"
            return true, true, "model estimate (" .. tostring(eNote) .. ")", eRef
        end
    elseif seed then
        local ref = Wipe(s.ref)
        ref.expiration, ref.duration, ref.estimated, ref.timeSource = ex.exp, ex.dur, true, "seeded from last exact read"
        ref.instanceID = ex.iid
        EpisodeStart(s, "seed", ex.exp)
        s.lastKind = "seed"
        return true, true, "seeded from the last exact read before the game hid it", ref
    end

    s.lastKind = "unknown"
    s.unknownN = (s.unknownN or 0) + 1
    return false
end

-------------------------------------------------------------------------------
-- Casts
-------------------------------------------------------------------------------
local function ConsumerList(castID)
    local d = DB()
    local l = d and d.consumers[castID]
    if type(l) == "table" then return l end
end
function T.AddConsumer(castID, auraID)
    local d = DB(); if not d then return false end
    d.consumers[castID] = d.consumers[castID] or {}
    for _, a in ipairs(d.consumers[castID]) do if a == auraID then return true end end
    tinsert(d.consumers[castID], auraID)
    return true
end
function T.ClearConsumer(castID) local d = DB(); if d then d.consumers[castID] = nil end end

function T.OnCastSent(castID)
    if not IdDiffUsable() or not Restricted() then return end
    if not RelevantTargets(castID) then return end
    pre[castID] = Snap(true)
end

function T.OnCastWindows(castID)
    if not T.Enabled() then return end
    local M = Model()
    local now = GetTime()
    local cons = ConsumerList(castID)
    if cons then
        for _, aid in ipairs(cons) do
            local s = S[aid]
            if s then
                s.consumedAt, s.consumedBy = now, castID
                s.link = nil
                stats.consumed = stats.consumed + 1
            end
            if M and M.CloseWindow then M.CloseWindow(aid) end
        end
    end
    -- the spell was pressed again: a "gone" verdict for what it causes no longer applies
    if M and M.CastTargets then
        for _, aid in ipairs(M.CastTargets(castID)) do
            local s = S[aid]
            if s and s.link and s.link.lost then s.link = nil end
        end
    end
    local before = pre[castID]
    pre[castID] = nil
    if not (before and IdDiffUsable() and Restricted()) then return end
    local rel = RelevantTargets(castID)
    if not rel then return end
    if C_Timer and C_Timer.After then
        for _, delay in ipairs(LINK_DELAYS) do
            C_Timer.After(delay, function() pcall(ConfirmLink, castID, rel, before) end)
        end
    end
end

-------------------------------------------------------------------------------
-- Resets and events
-------------------------------------------------------------------------------
local function ResetAll(reason)
    local M = Model()
    for _, s in pairs(S) do
        s.link, s.exact, s.ep, s.consumedAt = nil, nil, nil, nil
        s.lastKind = nil
    end
    for k in pairs(pre) do pre[k] = nil end
    snap = nil
    if M and M.CloseAllWindows then M.CloseAllWindows() end
    T.lastReset = reason
end
T.ResetAll = ResetAll

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")
f:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        combat.on, combat.t0 = true, GetTime()
        snap = nil
        if cap.ids == "secret" or cap.ids == "error" then cap.ids = nil end   -- retest once per combat
    elseif event == "PLAYER_REGEN_ENABLED" then
        combat.on = false
        for _, s in pairs(S) do s.link = nil end
        for k in pairs(pre) do pre[k] = nil end
        snap = nil
    elseif event == "PLAYER_DEAD" then
        ResetAll("death")
    elseif event == "PLAYER_ENTERING_WORLD" then
        ResetAll("world")
        cap.ids = nil
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if unit == "player" then ResetAll("spec") end
    elseif event == "TRAIT_CONFIG_UPDATED" then
        for _, s in pairs(S) do s.link = nil end
    end
end)

-- Hooks into the model (set after both files loaded; AuraModel calls them under pcall).
local function Install()
    local M = Model()
    if not M then return end
    M.OnCastSent = T.OnCastSent
    M.OnCastWindows = T.OnCastWindows
end
Install()

-------------------------------------------------------------------------------
-- /xui debug tracker moved to XayaUI Dev Assist (core 0.6.56; REQUEST-LOG #81, XayaUI_DevAssist/CoreDebug.lua). It reads the
-- state through these (two table references; nothing runs).
-------------------------------------------------------------------------------
T.states, T.DB = S, DB
