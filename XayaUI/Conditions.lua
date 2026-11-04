-------------------------------------------------------------------------------
-- Conditions.lua : read game state WITHOUT ever comparing a secret value.
--
-- Every read is pcall-wrapped and every value is checked with issecretvalue()
-- before it is compared. Anything unreadable becomes nil ("unknown"), and a
-- rule that depends on an unknown input does NOT fire (silent, never wrong).
-------------------------------------------------------------------------------
local addonName, ns = ...

local issecret = issecretvalue or function() return false end
ns.IsSecret = issecret

-- One field read, run under pcall without building a closure per call.
local function Field(t, key) return t[key] end
ns.Field = Field

-- Clean boolean field from a table, or nil if missing/secret.
local function CleanBool(t, key)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(Field, t, key)
    if not ok or issecret(v) or v == nil then return nil end
    return v and true or false
end

local function CleanNumber(t, key)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(Field, t, key)
    if not ok or issecret(v) or v == nil then return nil end
    if type(v) ~= "number" then return nil end
    return v
end

-------------------------------------------------------------------------------
-- Cooldown / charges
-- Returns a table:
--   known  : boolean, false if the inputs could not be read cleanly
--   max    : effective max charges
--   onCd   : main cooldown running (ignoring the GCD)
--   atMax  : all charges available (charge spells) / off cooldown (others)
--   empty  : no charges (EXPERIMENTAL for multi-charge spells)
--   why    : short note for /xui status
-------------------------------------------------------------------------------
local ReadCooldownRaw
function ns.ReadCooldown(rule)
    -- the same spell is often watched by several rules: read it once per engine step (the result is only ever read)
    local memo = ns.StepMemo and ns.StepMemo("cooldown")
    if not memo then return ReadCooldownRaw(rule) end
    local id, mc = rule.spellID or 0, rule.maxCharges or 0
    local byId = memo[id]
    if not byId then byId = {}; memo[id] = byId end
    local r = byId[mc]
    if not r then r = ReadCooldownRaw(rule); byId[mc] = r end
    return r
end
function ReadCooldownRaw(rule)
    local id = rule.spellID
    local r = { known = false, max = 1 }
    if not id or id == 0 then r.why = "no spell"; return r end

    local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
    if not ok or type(cd) ~= "table" then r.why = "cooldown unreadable"; return r end
    local cdActive = CleanBool(cd, "isActive")
    local onGCD = CleanBool(cd, "isOnGCD")
    if cdActive == nil then
        -- hidden (combat): the duration engine's estimate - exact start from the Cooldown Manager + the measured length
        local T = ns.Timing
        local ready, _, label
        if T then ready, _, label = T.CooldownEstimate(id) end
        if not ready then r.why = "cooldown hidden in combat, no estimate yet (see /xui timing)"; return r end
        r.onCd = GetTime() < ready
        r.readyAt, r.estimated = ready, true
        r.atMax, r.empty = not r.onCd, r.onCd
        r.known, r.why = true, label
        return r
    end
    r.onCd = cdActive and not onGCD
    if cdActive and not onGCD and ns.Timing then ns.Timing.LearnCooldown(id, CleanNumber(cd, "duration"), onGCD) end

    local okc, ch = pcall(C_Spell.GetSpellCharges, id)
    local maxC = okc and CleanNumber(ch, "maxCharges") or nil
    if (not maxC or maxC < 2) and (rule.maxCharges or 0) > 1 then
        -- manual override: only meaningful if the game did report a charge table
        if okc and type(ch) == "table" then maxC = rule.maxCharges end
    end
    r.max = maxC or 1

    if r.max > 1 then
        local active = CleanBool(ch, "isActive") -- false <=> at max charges (NeverSecret)
        if active == nil then r.why = "charges.isActive secret/nil"; return r end
        r.atMax = not active
        r.empty = r.onCd            -- inference: main cooldown only runs at 0 charges
        r.why = "multi-charge (max " .. r.max .. "), empty=inferred"
    else
        r.atMax = not r.onCd
        r.empty = r.onCd
        r.why = "single-charge"
    end
    r.known = true
    return r
end

-- Does cdState match? returns true/false/nil(unknown)
function ns.CheckCooldownState(rule, cdInfo)
    local s = rule.cdState
    if ns.Ignored(s) then return true end
    if not cdInfo or not cdInfo.known then return nil end
    if s == "ready" then return cdInfo.atMax end
    if s == "notReady" then return not cdInfo.atMax end
    if s == "empty" then return cdInfo.empty end
    if s == "hasCharge" then return not cdInfo.empty end
    return nil
end

-------------------------------------------------------------------------------
-- Buff presence
-- Method 1: C_UnitAuras.GetPlayerAuraBySpellID (skipped if secret)
-- Method 2: Blizzard Cooldown Manager frames (wasSetFromAura / auraInstanceID)
-- Returns present(true/false/nil), source string
-------------------------------------------------------------------------------
local VIEWERS = {
    "BuffIconCooldownViewer", "BuffBarCooldownViewer",
    "EssentialCooldownViewer", "UtilityCooldownViewer",
}

-- Cooldown Manager frame index. Reading every viewer's children and every frame's IDs once per tick (instead of once per rule per
-- tick) keeps the cost the same however many rules track auras. Before this, each Buff / Aura rule whose aura was absent walked all
-- four viewers and built two throw-away closures per frame, several times a second: the garbage alone dragged the frame rate down.
local cdmIndex, cdmTick, cdmAt = {}, -1, -1
local function GetSpellIDOf(frame) return frame.GetSpellID and frame:GetSpellID() end
-- Is a Cooldown Manager icon showing a live aura? wasSetFromAura is a plain boolean Blizzard sets itself. The instance id is
-- secret while auras are restricted (seen in game: "iid=secret"): a secret id means an aura IS assigned, and it is only ever
-- passed to issecretvalue, never compared or tested for truth (whether a boolean test of a secret is allowed is not documented).
local function FrameActive(fr)
    if fr.wasSetFromAura == true then return true end
    local iid = fr.auraInstanceID
    if issecret(iid) then return true end
    return iid ~= nil
end
local function IndexID(idx, v, fr, vname)
    if not issecret(v) and type(v) == "number" then
        local l = idx[v]
        if not l then l = {}; idx[v] = l end
        local n = #l
        if n == 0 or l[n][1] ~= fr then l[n + 1] = { fr, vname } end   -- one entry per frame per ID
    end
end
local function BuildCDMIndex()
    local idx = {}
    for _, vname in ipairs(VIEWERS) do
        local v = _G[vname]
        if v and v.GetChildren then
            local kids = { v:GetChildren() }
            for i = 1, #kids do
                local fr = kids[i]
                if fr then
                    if ns.Timing then ns.Timing.HookFrame(fr) end   -- exact applied / removed / cooldown moments (Timing.lua)
                    local ok, sid = pcall(GetSpellIDOf, fr)
                    if ok then IndexID(idx, sid, fr, vname) end
                    local info = fr.cooldownInfo
                    if type(info) == "table" then
                        IndexID(idx, info.spellID, fr, vname)
                        IndexID(idx, info.overrideSpellID, fr, vname)
                        IndexID(idx, info.overrideTooltipSpellID, fr, vname)
                        if type(info.linkedSpellIDs) == "table" then
                            for _, l in ipairs(info.linkedSpellIDs) do IndexID(idx, l, fr, vname) end
                        end
                    end
                end
            end
        end
    end
    return idx
end
local FindCDMFrame
function ns.FindCDMFrame(id) return FindCDMFrame(id) end
function FindCDMFrame(id)
    -- several viewers can hold a frame for the same spell (buff icon, buff bar, cooldown): an ACTIVE match wins,
    -- otherwise the first match is returned (so an inactive placeholder cannot hide a live aura)
    local now = GetTime()
    -- rebuilt at most every 0.25 s: which spell a viewer frame stands for rarely changes, and whether it is ACTIVE is read live below
    if cdmAt < 0 or now - cdmAt >= 0.25 or now < cdmAt then
        cdmIndex, cdmTick, cdmAt = BuildCDMIndex(), ns.tickID, now
    end
    local list = cdmIndex[id]
    if not list then return nil end
    local firstFr, firstName
    for i = 1, #list do
        local fr, vname = list[i][1], list[i][2]
        local okA, act = pcall(FrameActive, fr)
        if okA and act then return fr, vname end
        if not firstFr then firstFr, firstName = fr, vname end
    end
    return firstFr, firstName
end

-- The Cooldown Manager frame that tracks spell `id` as a BUFF (Tracked Buffs icons or bars), never a cooldown icon. An active
-- match wins, as in FindCDMFrame.
local BUFF_VIEWERS = { BuffIconCooldownViewer = true, BuffBarCooldownViewer = true }
local function FindTrackedBuffFrame(id)
    FindCDMFrame(id)   -- (rebuilds the index when it is stale)
    local list = cdmIndex[id]
    if not list then return nil end
    local firstFr, firstName
    for i = 1, #list do
        local fr, vname = list[i][1], list[i][2]
        if BUFF_VIEWERS[vname] then
            local okA, act = pcall(FrameActive, fr)
            if okA and act then return fr, vname end
            if not firstFr then firstFr, firstName = fr, vname end
        end
    end
    return firstFr, firstName
end
ns.FindTrackedBuffFrame = FindTrackedBuffFrame

-- Are aura reads restricted (secret) right now?
local function AurasRestricted()
    if not (C_Secrets and C_Secrets.ShouldAurasBeSecret) then return false end
    local ok, v = pcall(C_Secrets.ShouldAurasBeSecret)
    if not ok then return true end
    if issecret(v) then return true end
    return v == true
end
ns.AurasRestricted = AurasRestricted

-- Is THIS spell's aura still readable while restricted? (per-spell classification,
-- cached; the game can reclassify on hotfix, so the cache clears on world entry)
local secrecyCache = {}
function ns.ClearSecrecyCache() secrecyCache = {} end
local function AuraTrackable(id)
    local c = secrecyCache[id]
    if c ~= nil then return c end
    local result = false
    if C_Secrets and C_Secrets.GetSpellAuraSecrecy and Enum and Enum.SecrecyLevel then
        local ok, level = pcall(C_Secrets.GetSpellAuraSecrecy, id)
        result = ok and not issecret(level) and level == Enum.SecrecyLevel.NeverSecret
    end
    secrecyCache[id] = result
    return result
end
ns.AuraTrackable = AuraTrackable

local function ReadAuraAPI(id)
    local fn = C_UnitAuras and (C_UnitAuras.GetUnitAuraBySpellID or nil)
    local ok, aura
    if fn then
        ok, aura = pcall(fn, "player", id)
    elseif C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
    else
        return "error"
    end
    if not ok then return "error" end
    if issecret(aura) then return "secret" end
    if aura ~= nil then return "found", aura end
    return "nil"
end

-- Reference to a live aura for duration text, stacks and shield amount. Only READABLE values are kept: a secret instance id or
-- stack count is useless to addon code anyway (12.1.5: the aura calls that take an instance id refuse secret arguments from
-- addon code and need aura access, which combat withholds), and keeping it would hand a secret to every reader downstream.
-- ref.hiddenID marks "an aura is there, its id is hidden" for /xui status.
local function CleanNum(t, k)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(Field, t, k)
    if ok and type(v) == "number" and not issecret(v) then return v end
end
local function MakeRef(aura, frame, unit)
    local ref = {}
    -- the unit the aura is on: every later read by instance id must name it (a debuff's id means nothing on "player")
    if not unit and frame then
        local okU, u = pcall(Field, frame, "auraDataUnit")
        if okU and type(u) == "string" and not issecret(u) then unit = u end
    end
    ref.unit = unit or "player"
    local src = (type(aura) == "table") and aura or frame
    if src then
        local ok, iid = pcall(Field, src, "auraInstanceID")
        if ok and issecret(iid) then ref.hiddenID = true
        elseif ok and type(iid) == "number" then ref.instanceID = iid end
    end
    if type(aura) == "table" then
        ref.applications = CleanNum(aura, "applications")
        ref.expiration, ref.duration = CleanNum(aura, "expirationTime"), CleanNum(aura, "duration")
        if not (ref.expiration and ref.duration) then ref.expiration, ref.duration = nil, nil end
    end
    return ref
end
ns.MakeAuraRef = MakeRef
local function BuffPresentRaw(id)
    if not id or id == 0 then return nil, "no buff" end
    -- A real aura table proves presence, in any context.
    local api, aura = ReadAuraAPI(id)
    if api == "found" then
        if ns.LearnStacks then pcall(ns.LearnStacks, id, aura) end   -- what the stack count can be (#300; CountSupport below)
        return true, "aura API", MakeRef(aura)
    end
    -- Cooldown Manager frame: authoritative when the buff is tracked there.
    local fr, vname = FindCDMFrame(id)
    if fr then
        local okA, active = pcall(FrameActive, fr)
        active = okA and active or false
        -- diagnostic detail for /xui status: what the frame actually reports (secret-safe, no arithmetic)
        local okd, detail = pcall(function()
            local iid = fr.auraInstanceID
            local u = fr.auraDataUnit
            return ("iid=%s wasAura=%s shown=%s unit=%s"):format(
                issecret(iid) and "secret" or tostring(iid),
                tostring(fr.wasSetFromAura == true), tostring(fr:IsShown() and true or false),
                issecret(u) and "secret" or tostring(u))
        end)
        return active and true or false, "CDM frame (" .. vname .. (okd and (": " .. detail) or "") .. ")", active and MakeRef(nil, fr) or nil
    end
    -- No proof of presence. "nil" only means MISSING if the read can be trusted.
    if api == "nil" then
        if not AurasRestricted() then return false, "aura API (unrestricted)" end
        if AuraTrackable(id) then return false, "aura API (NeverSecret spell)" end
        return nil, "unknown: restricted + spell not readable + not in CDM"
    end
    return nil, "unreadable (" .. api .. ")"
end

-------------------------------------------------------------------------------
-- Buff time left.
-- Tier 1: the aura table's own numbers (readable only).
-- Tier 2: the game's duration object (C_UnitAuras.GetAuraDuration -> GetRemainingDuration / GetTotalDuration). Used only
--         when the answer is a plain number; a secret answer is never compared or divided (Blizzard blocks that).
-- Tier 3 (opt-in per rule, rule.buffEstimate): when the game hides the time, estimate it as "moment the buff appeared +
--         the duration last seen while it was readable". Marked ref.estimated. Wrong for buffs that get refreshed or
--         extended while up (no appear event happens), so it is never on by default.
-------------------------------------------------------------------------------
local presentSince, seenAbsent = {}, {}
local function LearnedTable()
    if type(CueRulesDB) ~= "table" then return nil end
    if type(CueRulesDB.learnedAuraDur) ~= "table" then CueRulesDB.learnedAuraDur = {} end
    return CueRulesDB.learnedAuraDur
end

-- returns expiration, totalDuration (either may be nil), note
local function DurationObjectTimes(iid, unit)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDuration) then return nil, nil, "no duration API" end
    local ok, obj = pcall(C_UnitAuras.GetAuraDuration, unit or "player", iid)
    if not ok then return nil, nil, "duration object call refused" end
    if obj == nil then return nil, nil, "no duration object" end
    if issecret(obj) or type(obj) ~= "table" and type(obj) ~= "userdata" then return nil, nil, "duration object unusable" end
    local okR, rem = pcall(function() return obj:GetRemainingDuration() end)
    if not okR then return nil, nil, "remaining time call failed" end
    if issecret(rem) then return nil, nil, "remaining time is secret" end
    if type(rem) ~= "number" then return nil, nil, "remaining time missing" end
    local okT, tot = pcall(function() return obj:GetTotalDuration() end)
    if not (okT and type(tot) == "number" and not issecret(tot) and tot > 0) then tot = nil end
    return GetTime() + rem, tot, "duration object"
end

-- One Buff / Aura trigger can watch several auras that mean the same thing (rule.buffAlt = extra spell IDs beside rule.buffID).
-- Present = ANY of them is present (the first present one supplies stacks / time left). Missing = ALL are absent.
-- If none is present and any answer is unknown (hidden in combat), the answer stays unknown, so a rule never fires on a guess.
-- The same reading serves every aura trigger row (Triggers.lua "Buff / Aura (another)"): ns.AuraPresentList(mainID, extraIDs).
-- Returns present (true / false / nil), source text, aura reference, and the ID that was found (for the time estimate).
function ns.AuraPresentList(mainID, alts)
    local p1, s1, r1 = ns.BuffPresent(mainID)
    if type(alts) ~= "table" or #alts == 0 then return p1, s1, r1, mainID end
    if p1 == true then return true, s1, r1, mainID end
    local unknown, unkSrc = (p1 == nil), (p1 == nil) and s1 or nil
    for _, id in ipairs(alts) do
        local p, s, r = ns.BuffPresent(id)
        if p == true then return true, "aura " .. tostring(id) .. ": " .. tostring(s), r, id end
        if p == nil then unknown = true; unkSrc = unkSrc or s end
    end
    if unknown then return nil, unkSrc or "unreadable" end
    return false, s1
end
-- When the game hides the aura (combat) and no Cooldown Manager frame carries any of the rule's aura IDs, the rule's OWN spell may
-- still be in the Cooldown Manager's Tracked Buffs: that icon is lit exactly while the spell's buff is up (it is what the Cooldown
-- Manager shows, and what other addons that skin it read). Insivius, 2026-11-04: Death and Decay (spell 43265) tracked in his
-- Cooldown Manager, rule watching auras 188290 / 434034: the aura IDs matched no frame, and 434034 could never be read, so
-- "missing" stayed unknown in combat and the rule never fired. Used only when the answer is otherwise unknown, only for a Tracked
-- Buffs frame (not a cooldown icon), and only when one of the rule's aura IDs has the spell's own name (or is the spell), so a rule
-- whose cooldown spell and aura are unrelated is never answered from the wrong icon.
local nameCache = {}
local function SpellNameOf(id)
    local n = nameCache[id]
    if n == nil then
        local ok, v = pcall(C_Spell.GetSpellName, id)
        n = (ok and type(v) == "string" and not issecret(v) and v ~= "") and v or false
        nameCache[id] = n
    end
    return n or nil
end
local function TrackedBuffOfSpell(rule)
    local sid = tonumber(rule.spellID) or 0
    if sid <= 0 then return nil end
    local sname = SpellNameOf(sid)
    local same = false
    local function Test(a)
        a = tonumber(a)
        if not a or a <= 0 or same then return end
        if a == sid or (sname and SpellNameOf(a) == sname) then same = true end
    end
    Test(rule.buffID)
    if type(rule.buffAlt) == "table" then for _, a in ipairs(rule.buffAlt) do Test(a) end end
    if not same then return nil end
    local fr, vname = FindTrackedBuffFrame(sid)
    if not fr then return nil end
    local okA, active = pcall(FrameActive, fr)
    active = okA and active or false
    return active and true or false, "CDM tracked buff of the rule's spell " .. sid .. " (" .. tostring(vname) .. "; same name as the aura)",
        active and MakeRef(nil, fr) or nil
end
function ns.BuffPresentAny(rule)
    local p, s, r, w = ns.AuraPresentList(rule and rule.buffID, rule and rule.buffAlt)
    if p == nil and rule then
        local ok, fp, fs, fr = pcall(TrackedBuffOfSpell, rule)
        if ok and fp ~= nil then return fp, fs, fr, rule.buffID end
    end
    return p, s, r, w
end

local BuffPresentOnce
-- (one read per aura per engine step: several rules often watch the same aura, and the tracker's side effects should run once)
function ns.BuffPresent(id)
    local memo = id and ns.StepMemo and ns.StepMemo("buff")
    if not memo then return BuffPresentOnce(id) end
    local m = memo[id]
    if not m then
        m = {}
        m[1], m[2], m[3] = BuffPresentOnce(id)
        memo[id] = m
    end
    return m[1], m[2], m[3]
end
function BuffPresentOnce(id)
    local present, src, ref = BuffPresentRaw(id)
    if not id or id == 0 then return present, src, ref end
    local now = GetTime()
    -- appear / disappear tracking for the opt-in estimate (only a seen absence makes an appearance count)
    if present == false then
        seenAbsent[id] = true; presentSince[id] = nil
    elseif present == true then
        -- appeared: stamped with the aura event that caused it when that was just now (the step runs up to 50 ms later)
        if not presentSince[id] and seenAbsent[id] then
            local ev = ns.lastAuraEventAt
            presentSince[id] = (ev and now - ev >= 0 and now - ev < 0.3) and ev or now
        end
    end
    local rawPresent = present
    local T = ns.AuraTracker
    if present == false then
        if ns.AuraModel and ns.AuraModel.NoteAbsent then ns.AuraModel.NoteAbsent(id) end
        if T and T.Observe then pcall(T.Observe, id, false, src, nil) end
    elseif present == nil then
        -- The game hides this aura right now (combat).  The tracker ranks the remaining evidence (consumed, aura-ID link,
        -- latest of cast-anchored model / last exact read) and may answer true (estimate or linked), false (a linked ID left
        -- the list, or a registered consumer fired) or nothing.  An estimate can only say "up".  Its numbers are marked
        -- ref.estimated and never stored as learned durations.
        if T and T.Resolve then
            local okT, handled, tp, ts, tr = pcall(T.Resolve, id)
            if okT and handled then present, src, ref = tp, ts, tr end
        elseif ns.AuraModel and ns.AuraModel.EstimatePresent then
            local okM, eP, eRef, eNote = pcall(ns.AuraModel.EstimatePresent, id)
            if okM and eP then return true, "model estimate (" .. tostring(eNote) .. ")", eRef end
        end
    end
    if present ~= true or type(ref) ~= "table" then return present, src, ref end
    local note
    -- An estimated time is replaced by the game's own duration object whenever that answers with a plain number.
    if not ref.expiration or ref.estimated then
        if ref.instanceID then
            local exp, tot
            exp, tot, note = DurationObjectTimes(ref.instanceID, ref.unit)
            if exp then
                ref.expiration = exp
                if tot then ref.duration = tot end
                ref.timeSource = "duration object"
                ref.estimated = nil
            end
        end
    end
    if ref.expiration then
        ref.timeSource = ref.timeSource or "aura API"
        if ref.duration and ref.duration > 0 and not ref.estimated then
            local L = LearnedTable()
            if L then L[id] = ref.duration end
        end
    else
        ref.timeNote = note or "no readable time"
    end
    if rawPresent == true and T and T.Observe then pcall(T.Observe, id, true, src, ref) end
    return present, (src or "") .. " | time: " .. (ref.timeSource or ref.timeNote), ref
end

-- When the game hides a present buff's time: the duration engine's estimate (Timing.lua: exact start from the Cooldown
-- Manager or your cast + the measured length). On for every rule unless switched off (rule.buffEstimate == false); readable
-- numbers are never replaced.
local estimatePool = setmetatable({}, { __mode = "k" })   -- one copy table per owner (rule or trigger row), reused every step
-- The estimate for aura `id` when ref has no readable time: a copy of ref with the estimated time (the original may be shared by other
-- rules this step), or nil plus nothing when there is no estimate yet. owner = the rule or the trigger row the copy belongs to.
function ns.AuraEstimateInto(owner, id, ref)
    if type(ref) ~= "table" or ref.expiration then return nil end
    id = tonumber(id)
    local exp, dur, label
    if ns.Timing and id then exp, dur, label = ns.Timing.AuraEstimate(id, presentSince[id]) end
    if not exp then return nil end
    local own = (ns.InStep and ns.InStep()) and estimatePool[owner]
    if own then for k in pairs(own) do own[k] = nil end
    else own = {}; if ns.InStep and ns.InStep() then estimatePool[owner] = own end end
    for k, v in pairs(ref) do own[k] = v end
    own.expiration, own.duration, own.estimated, own.timeSource = exp, dur, true, label
    return own, label
end
function ns.ApplyBuffEstimate(rule, info)
    local ref = info.buffRef
    if rule.buffEstimate == false or info.present ~= true or type(ref) ~= "table" or ref.expiration then return end
    local own, label = ns.AuraEstimateInto(rule, info.buffWhich or rule.buffID, ref)
    if own then
        info.buffRef = own
        if ns.statusDetail then info.buffSource = tostring(info.buffSource):gsub(" | time: .*$", "") .. " | time: " .. label end
    elseif ns.statusDetail then
        info.buffSource = tostring(info.buffSource) .. " | no time estimate yet (see /xui timing)"
    end
end

-- The aura a rule's display shows when the rule has no built-in Buff / Aura: the first present aura among its "Buff / Aura
-- (another)" and "Target Debuff (yours)" trigger rows, as those rows read it this step (Triggers.lua ns.TriggerAuraRef: the one store of
-- row auras, which conditions read too, with the row's own extra IDs and its duration-engine estimate). Display only. Returns a ref or nil.
function ns.AuraRowRef(rule)
    local list = type(rule.extra) == "table" and rule.extra.list
    if type(list) ~= "table" or not ns.TriggerAuraRef then return nil end
    for _, t in ipairs(list) do
        if type(t) == "table" and (t.type == "buffAura" or t.type == "targetDebuff") and t.state ~= "no" then
            local present, ref = ns.TriggerAuraRef(t)
            if present == true and type(ref) == "table" then return ref end
        end
    end
    return nil
end

-- "Seconds left" as part of an aura trigger (#173, #278, #314): op = ">=" | "<=" | ">" | "<" (nil / "" = any time left), sec = number.
-- present must be true (a missing aura is decided by the trigger's state). true / false / nil (time unknown: hidden and no estimate yet).
-- Registers the moments the answer will change so the engine re-checks on that frame. A permanent aura has unlimited time left.
ns.TIME_OPS = { values = { any = "Any time left", [">="] = "At least", ["<="] = "At most", [">"] = "More than", ["<"] = "Less than" },
    order = { "any", ">=", "<=", ">", "<" } }
function ns.AuraTimeLeft(ref)
    if type(ref) ~= "table" then return nil end
    local exp, dur = ref.expiration, ref.duration
    if type(exp) ~= "number" or issecret(exp) then return nil end
    if exp == 0 and (dur == 0 or dur == nil) then return math.huge end
    if exp <= 0 then return nil end
    return math.max(0, exp - GetTime())
end
function ns.TimeLeftCheck(op, sec, ref)
    if op == nil or op == "" or op == "any" then return true end
    local rem = ns.AuraTimeLeft(ref)
    if rem == nil then return nil end
    sec = tonumber(sec) or 0
    if rem ~= math.huge and ns.Timing and ns.Timing.Deadline then
        local now = GetTime()
        if rem > sec then ns.Timing.Deadline(now + (rem - sec)) end
        if rem > 0 then ns.Timing.Deadline(now + rem) end
    end
    if op == ">=" then return rem >= sec elseif op == "<=" then return rem <= sec
    elseif op == ">" then return rem > sec elseif op == "<" then return rem < sec end
    return true
end

-------------------------------------------------------------------------------
-- Is this spell currently placed on an action bar (any of the 12 standard bars, main paging included)?
-- Rebuilt at most once per engine tick (ns.RefreshActionBarSpells), so this is a cheap lookup.
-------------------------------------------------------------------------------
local actionBarSpells = {}
-- C_ActionBar.HasAction (12.x); the old global only through Compat.lua
local function SlotHasAction(slot)
    local ok, v = pcall(ns.Compat.HasAction, slot)
    return ok and v or false
end
function ns.RefreshActionBarSpells()
    local set = {}
    for slot = 1, 180 do   -- covers the 12 standard bars incl. stance/vehicle paging (1-120) plus extra bar pages
        if SlotHasAction(slot) then
            local okI, atype, id = pcall(GetActionInfo, slot)
            if okI and not issecret(atype) and not issecret(id) then
                if atype == "spell" and id then
                    set[id] = true
                elseif atype == "macro" and id and GetMacroSpell then
                    local okm, mSpellID = pcall(GetMacroSpell, id)
                    if okm and mSpellID then set[mSpellID] = true end
                end
            end
        end
    end
    actionBarSpells = set
end
-- id may be a spell OR an item's associated spell is not resolved here (items on bars are rare for rule targets;
-- only the spell case is handled, which covers class/talent abilities). Unverified: macro-cast spells, vehicle bars.
function ns.SpellOnActionBar(id)
    if not id or id == 0 then return true end   -- nothing to require -> do not gate
    return actionBarSpells[id] == true
end

-- Talents in the player's current class/spec/hero trees (for the options dropdown).
-- Built from C_Traits; cached until the talent config or spec changes.
function ns.BuildTalentList()
    if ns.talentList then return ns.talentList end
    local list, seen = {}, {}
    local okc, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if okc and configID then
        local okI, cfg = pcall(C_Traits.GetConfigInfo, configID)
        for _, treeID in ipairs((okI and cfg and cfg.treeIDs) or {}) do
            local okN, nodes = pcall(C_Traits.GetTreeNodes, treeID)
            for _, nodeID in ipairs(okN and nodes or {}) do
                local okn, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                if okn and node and node.isVisible and node.entryIDs then
                    for _, entryID in ipairs(node.entryIDs) do
                        local oke, e = pcall(C_Traits.GetEntryInfo, configID, entryID)
                        local defID = oke and e and e.definitionID
                        local okd, d = false, nil
                        if defID then okd, d = pcall(C_Traits.GetDefinitionInfo, defID) end
                        local sid = okd and d and d.spellID
                        if sid and not seen[sid] then
                            seen[sid] = true
                            local okn2, name = pcall(C_Spell.GetSpellName, sid)
                            if okn2 and name then
                                list[#list + 1] = { id = sid, name = name, choice = #node.entryIDs > 1 }
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    ns.talentList = list
    return list
end

-- Active (non-passive) spells in the player's spellbook, current spec only (for the Trigger > Cooldown dropdown).
-- Cached until spec / talents / spellbook change.
function ns.BuildSpellList()
    if ns.spellList then return ns.spellList end
    local list, seen = {}, {}
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local okn, nLines = false, nil
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then okn, nLines = pcall(C_SpellBook.GetNumSpellBookSkillLines) end
    if bank ~= nil and okn and nLines then
        for i = 1, nLines do
            local oki, line = pcall(C_SpellBook.GetSpellBookSkillLineInfo, i)
            if oki and line and not line.offSpecID then
                for j = 1, (line.numSpellBookItems or 0) do
                    local okI, it = pcall(C_SpellBook.GetSpellBookItemInfo, (line.itemIndexOffset or 0) + j, bank)
                    if okI and it and it.spellID and not it.isPassive and not it.isOffSpec
                        and (it.itemType == nil or not Enum.SpellBookItemType or it.itemType == Enum.SpellBookItemType.Spell) then
                        local sid = it.spellID
                        if not seen[sid] then
                            seen[sid] = true
                            local okS, name = pcall(C_Spell.GetSpellName, sid)
                            local okT, icon = pcall(C_Spell.GetSpellTexture, sid)
                            if okS and name then list[#list + 1] = { id = sid, name = name, icon = okT and icon or nil } end
                        end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) if a.name == b.name then return a.id < b.id end return a.name < b.name end)
    ns.spellList = list
    return list
end

-- Base cooldown of a spell in seconds (0 = none / unreadable). Uses the static base cooldown (talent / haste reductions are NOT
-- applied) and, for charge spells, the per-charge recharge time when the game lets us read it (it is secret in combat).
local function BaseCooldownSec(sid)
    local best = 0
    local fn = (C_Spell and C_Spell.GetSpellBaseCooldown) or GetSpellBaseCooldown
    if fn then
        local ok, ms = pcall(fn, sid)
        if ok and not issecret(ms) and type(ms) == "number" and ms > 0 then best = ms / 1000 end
    end
    if C_Spell and C_Spell.GetSpellCharges then
        local ok, ch = pcall(C_Spell.GetSpellCharges, sid)
        if ok and type(ch) == "table" then
            local d = ch.cooldownDuration
            if not issecret(d) and type(d) == "number" and d > best then best = d end
        end
    end
    return best
end
ns.BaseCooldownSec = BaseCooldownSec

-- Spells whose base cooldown is >= minSec, for the CURRENT class + specialization:
--   * every active spell in the spellbook (class + current spec + general lines), and
--   * every active talent in the class / spec / hero trees, including talents that are not picked (includeUnpicked).
-- Each entry: { id, name, icon, cd, talent = true when the spell is also a talent }.
function ns.CollectCooldownSpells(minSec, includeUnpicked)
    minSec = tonumber(minSec) or 0
    local out, byId = {}, {}
    local isTalent = {}
    for _, t in ipairs(ns.BuildTalentList()) do isTalent[t.id] = t end
    for _, sp in ipairs(ns.BuildSpellList()) do
        local cd = BaseCooldownSec(sp.id)
        if cd > 0 and cd >= minSec then
            local e = { id = sp.id, name = sp.name, icon = sp.icon, cd = cd, talent = isTalent[sp.id] and true or nil }
            byId[sp.id] = e; out[#out + 1] = e
        end
    end
    if includeUnpicked then
        for _, t in ipairs(ns.BuildTalentList()) do
            if not byId[t.id] then
                local cd = BaseCooldownSec(t.id)
                if cd > 0 and cd >= minSec then
                    local okT, icon = pcall(C_Spell.GetSpellTexture, t.id)
                    local e = { id = t.id, name = t.name, icon = okT and icon or nil, cd = cd, talent = true }
                    byId[t.id] = e; out[#out + 1] = e
                end
            end
        end
    end
    table.sort(out, function(a, b) if a.name == b.name then return a.id < b.id end return a.name < b.name end)
    return out
end

function ns.CheckBuffState(rule, present)
    local s = rule.buffState
    if ns.Ignored(s) then return true end
    if present == nil then return nil end
    if s == "missing" then return present == false end
    if s == "present" then return present == true end
    return nil
end

-------------------------------------------------------------------------------
-- Talent known?  returns true/false/nil
-------------------------------------------------------------------------------
function ns.ReadTalentKnown(id)
    if not id or id == 0 then return nil end
    local fn = IsPlayerSpell or (C_SpellBook and C_SpellBook.IsSpellKnown)
    if not fn then return nil end
    local ok, v = pcall(fn, id)
    if not ok or issecret(v) then return nil end
    return v and true or false
end

-- Talent requirements: rule.talents = { {id=, state="known"|"notKnown"}, ... } combined by rule.talentMode
-- (none = ignore, all = every entry must match, any = at least one). Returns true/false/nil(unknown), detail text.
function ns.CheckTalents(rule)
    local mode = rule.talentMode
    if mode == nil or mode == "" or mode == "none" then return true, "no talent requirement" end
    local list = rule.talents or {}
    if #list == 0 then return true, "no talents added" end
    local anyTrue, anyNil, allTrue = false, false, true
    local parts = {}
    for _, t in ipairs(list) do
        local known = ns.ReadTalentKnown(t.id)
        local ok
        if known ~= nil then ok = (known == (t.state ~= "notKnown")) end
        parts[#parts + 1] = tostring(t.id) .. "=" .. (ok == nil and "?" or (ok and "ok" or "no"))
        if ok == true then anyTrue = true else allTrue = false end
        if ok == nil then anyNil = true end
    end
    local detail = mode .. ": " .. table.concat(parts, " ")
    if mode == "any" then
        if anyTrue then return true, detail end
        if anyNil then return nil, detail end
        return false, detail
    end
    -- all
    if allTrue then return true, detail end
    -- some entry is not true: false only if an entry is definitely false
    for _, t in ipairs(list) do
        local known = ns.ReadTalentKnown(t.id)
        if known ~= nil and known ~= (t.state ~= "notKnown") then return false, detail end
    end
    return nil, detail
end

-------------------------------------------------------------------------------
-- Load conditions (context). Data-driven so the options UI can generate them.
-- Each read is pcall'd; an unreadable value is nil (unknown) and a rule that
-- restricts on an unknown value does not fire.
-------------------------------------------------------------------------------
-- Tick-box sets: value true = must be one of these, "not" = must NOT be this. Empty set = no restriction.
-- Passes when the value is not marked "not" and, if any true entries exist, is one of them.
-- The key "*" is the explicit "All" choice of the Specialization / Role radios: it restricts nothing.
function ns.SetActive(set)
    for k in pairs(set or {}) do if k ~= "*" then return true end end
    return false
end
function ns.SetMatch(set, value)
    if set[value] == "not" then return false end
    local hasOn = false
    for k, st in pairs(set) do if st == true and k ~= "*" then hasOn = true; break end end
    if hasOn then return set[value] == true end
    return true
end

ns.LOAD_TRI = {
    { key = "combat", label = "Combat", yes = "Only in combat", no = "Only out of combat",
      read = function() return UnitAffectingCombat("player") or InCombatLockdown() end },
    { key = "group", label = "Group", yes = "Only in a group", no = "Only when solo",
      read = function() return IsInGroup() end },
    { key = "raid", label = "Raid group", yes = "Only in a raid group", no = "Not in a raid group",
      read = function() return IsInRaid() end },
    { key = "instance", label = "Instance", yes = "Only inside an instance", no = "Only in the open world",
      read = function() return (IsInInstance()) end },
    { key = "mythicPlus", label = "Mythic+ keystone", yes = "Only during a Mythic+", no = "Not during a Mythic+",
      read = function() return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
          and C_ChallengeMode.IsChallengeModeActive() end },
    { key = "encounter", label = "Boss encounter", yes = "Only during a boss encounter", no = "Only outside boss encounters",
      read = function() return ns.Compat.InEncounter() end },
    { key = "mounted", label = "Mounted", yes = "Only when mounted", no = "Only when not mounted",
      read = function() return IsMounted() end },
    { key = "resting", label = "Resting area", yes = "Only in a resting area", no = "Only outside resting areas",
      read = function() return IsResting() end },
}

ns.INSTANCE_TYPES = {
    none = "Open world", party = "Dungeon", raid = "Raid",
    pvp = "Battleground", arena = "Arena", scenario = "Scenario",
}
ns.INSTANCE_TYPE_ORDER = { "none", "party", "raid", "pvp", "arena", "scenario" }

local function CurrentSpec()
    local idx
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        idx = C_SpecializationInfo.GetSpecialization()
    elseif GetSpecialization then
        idx = GetSpecialization()
    end
    if not idx then return nil end
    local id, role
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        local a, _, _, _, r = C_SpecializationInfo.GetSpecializationInfo(idx)
        id, role = a, r
    elseif GetSpecializationInfo then
        local a, _, _, _, r = GetSpecializationInfo(idx)
        id, role = a, r
    end
    return id, role
end

function ns.CurrentSpecID() local id = CurrentSpec(); return id end

function ns.ReadContext()
    local ctx = {}
    for _, c in ipairs(ns.LOAD_TRI) do
        local ok, v = pcall(c.read)
        if ok and v ~= nil and not issecret(v) then ctx[c.key] = v and true or false end
    end
    local okI, _, itype = pcall(IsInInstance)
    if okI and not issecret(itype) then ctx.instanceType = itype end
    local okC, _, cfile = pcall(UnitClass, "player")
    if okC and type(cfile) == "string" and not issecret(cfile) then ctx.class = cfile end
    local ok, id, role = pcall(CurrentSpec)
    if ok then
        if not issecret(id) then ctx.specID = id end
        if not issecret(role) then ctx.role = role end
    end
    -- active hero talent specialization (SubTreeID); 0 = none chosen yet; absent when the API is missing
    if C_ClassTalents and C_ClassTalents.GetActiveHeroTalentSpec then
        local okH, hid = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
        if okH and not issecret(hid) then ctx.hero = tonumber(hid) or 0 end
    end
    -- every value a load check reads, in one string: equal strings = equal load answers (ns.CheckContext memo)
    local parts = {}
    for i, c in ipairs(ns.LOAD_TRI) do local v = ctx[c.key]; parts[i] = (v == nil) and "?" or (v and "1" or "0") end
    parts[#parts + 1] = tostring(ctx.instanceType); parts[#parts + 1] = tostring(ctx.specID)
    parts[#parts + 1] = tostring(ctx.role); parts[#parts + 1] = tostring(ctx.hero); parts[#parts + 1] = tostring(ctx.class)
    ctx.sig = table.concat(parts, "|")
    return ctx
end

-- Load conditions. Every active (non-ignored) condition yields true / false / nil(unknown).
-- load.mode "any": at least one active condition must be true. Otherwise (blank / "all") every one must be.
-- Returns ok(bool), name of the failing condition(s).
local function known(v, result) if v == nil then return nil end return result end

local CheckContextRaw
local ctxMemo = setmetatable({}, { __mode = "k" })
function ns.CheckContext(rule, ctx)
    -- memo per rule: same context values (ctx.sig) and no settings edit since (ns.configVersion), re-checked at least once a second
    local sig = ctx and ctx.sig
    if not sig then return CheckContextRaw(rule, ctx) end
    local now, ver = math.floor(GetTime()), ns.configVersion or 0
    local m = ctxMemo[rule]
    if m and m.sig == sig and m.ver == ver and m.sec == now then return m.ok, m.fail end
    local ok, fail = CheckContextRaw(rule, ctx)
    if not m then m = {}; ctxMemo[rule] = m end
    m.sig, m.ver, m.sec, m.ok, m.fail = sig, ver, now, ok, fail
    return ok, fail
end
function CheckContextRaw(rule, ctx)
    local load = rule.load or {}
    local ov, ovFolder = ns.FolderLoadOverride(rule)   -- a folder's Never / Always beats the rule's own load mode
    if ov == "never" then return false, "load: never (folder " .. tostring(ovFolder and ovFolder.name) .. ")" end
    if ov == "always" then return true end
    do   -- a group's own spec / role / instance-type conditions apply on top of the rule's (nearest group first, then its parents)
        local fid, guard = rule.folder, 0
        while fid and guard < 32 do
            local f = ns.FolderById(fid)
            if not f then break end
            if ns.SetActive(f.loadClasses) and not (ctx.class ~= nil and ns.SetMatch(f.loadClasses, ctx.class)) then
                return false, "group " .. tostring(f.name) .. ": class" .. (ctx.class == nil and " (unknown)" or "")
            end
            if ns.SetActive(f.loadSpecs) and not (ctx.specID ~= nil and ns.SetMatch(f.loadSpecs, tostring(ctx.specID))) then
                return false, "group " .. tostring(f.name) .. ": specialization" .. (ctx.specID == nil and " (unknown)" or "")
            end
            if ns.SetActive(f.loadRoles) and not (ctx.role ~= nil and ns.SetMatch(f.loadRoles, ctx.role)) then
                return false, "group " .. tostring(f.name) .. ": role" .. (ctx.role == nil and " (unknown)" or "")
            end
            if ns.SetActive(f.loadInst) and not (ctx.instanceType ~= nil and ns.SetMatch(f.loadInst, ctx.instanceType)) then
                return false, "group " .. tostring(f.name) .. ": instance type" .. (ctx.instanceType == nil and " (unknown)" or "")
            end
            fid, guard = f.parent, guard + 1
        end
    end
    if load.mode == "never" then return false, "load: never" end
    if load.mode == "always" then return true end
    local checks = {}
    for _, c in ipairs(ns.LOAD_TRI) do
        local s = load[c.key]
        if not ns.Ignored(s) then
            local actual = ctx[c.key]
            checks[#checks + 1] = { key = c.key, ok = known(actual, (s == "yes" and actual == true) or (s == "no" and actual == false)) }
        end
    end
    if load.instanceTypes and next(load.instanceTypes) then
        checks[#checks + 1] = { key = "instance type", ok = known(ctx.instanceType, ctx.instanceType ~= nil and ns.SetMatch(load.instanceTypes, ctx.instanceType)) }
    end
    -- multi-select sets (empty / missing = any); the old single specID / role are still honored for saved rules
    if load.classUse ~= false and ns.SetActive(load.classes) then
        checks[#checks + 1] = { key = "class", ok = known(ctx.class, ctx.class ~= nil and ns.SetMatch(load.classes, ctx.class)) }
    end
    if load.specUse ~= false and ns.SetActive(load.specs) then
        checks[#checks + 1] = { key = "spec", ok = known(ctx.specID, ctx.specID ~= nil and ns.SetMatch(load.specs, tostring(ctx.specID))) }
    elseif load.specUse ~= false and (load.specID or 0) > 0 then
        checks[#checks + 1] = { key = "spec", ok = known(ctx.specID, ctx.specID == load.specID) }
    end
    if load.roleUse ~= false and ns.SetActive(load.roles) then
        checks[#checks + 1] = { key = "role", ok = known(ctx.role, ctx.role ~= nil and ns.SetMatch(load.roles, ctx.role)) }
    elseif load.roleUse ~= false and not ns.Ignored(load.role) then
        checks[#checks + 1] = { key = "role", ok = known(ctx.role, ctx.role == load.role) }
    end
    if load.heroUse ~= false and ns.SetActive(load.heroes) then
        checks[#checks + 1] = { key = "hero talents", ok = known(ctx.hero, ctx.hero ~= nil and ctx.hero > 0 and ns.SetMatch(load.heroes, tostring(ctx.hero))) }
    end
    if #checks == 0 then return true end
    if load.mode == "any" then
        local unknown
        for _, c in ipairs(checks) do
            if c.ok == true then return true end
            if c.ok == nil then unknown = true end
        end
        return false, "none of the conditions matched" .. (unknown and " (some unknown)" or "")
    end
    for _, c in ipairs(checks) do
        if c.ok ~= true then return false, c.key .. (c.ok == nil and " (unknown)" or "") end
    end
    return true
end

-------------------------------------------------------------------------------
-- Full rule evaluation. Returns result(bool), info(table)
-------------------------------------------------------------------------------
-- One evaluation per rule per engine tick: outcome rules read their parent's result, so the parent must not be read twice.
-- Only used inside the engine (ns.tickID is set there) and only for the SAME ctx table.
local evalCache = setmetatable({}, { __mode = "k" })
local function unset(v) return v == nil or v == "" end
local function Remember(rule, ctx, res, info)
    if not ns.tickID then return end
    local c = evalCache[rule]   -- one entry per rule, reused every tick
    if not c then c = {}; evalCache[rule] = c end
    c.tick, c.ctx, c.res, c.info = ns.tickID, ctx, res, info
end

-- The result table a rule fills this step. During an engine step each rule reuses its own table (emptied first), so a few
-- hundred rules no longer make a few hundred tables of garbage per step; outside a step (options, /xui status) it is new.
-- Whoever keeps it (the runtime, a display's per-frame effects) always sees the rule's latest result.
local infoPool = setmetatable({}, { __mode = "k" })
function ns.InfoFor(rule)
    if not (ns.InStep and ns.InStep()) then return { missing = {} } end
    local t = infoPool[rule]
    if not t then t = { missing = {} }; infoPool[rule] = t; return t end
    local missing = t.missing
    for k in pairs(t) do t[k] = nil end
    for i = #missing, 1, -1 do missing[i] = nil end
    t.missing = missing
    return t
end

function ns.Evaluate(rule, ctx)
    ctx = ctx or ns.ReadContext()
    local c = ns.tickID and evalCache[rule]
    if c and c.tick == ns.tickID and c.ctx == ctx then return c.res, c.info end
    if rule.parentUid and ns.EvaluateOutcome then
        local res, oinfo = ns.EvaluateOutcome(rule, ctx)
        Remember(rule, ctx, res, oinfo)
        return res, oinfo
    end
    local info = ns.InfoFor(rule)
    info.ctx = ctx
    info.cd = ns.ReadCooldown(rule)
    info.present, info.buffSource, info.buffRef, info.buffWhich = ns.BuffPresentAny(rule)
    if rule.buffEstimate ~= false and info.present == true then ns.ApplyBuffEstimate(rule, info) end
    info.cdOK = ns.CheckCooldownState(rule, info.cd)
    info.buffOK = ns.CheckBuffState(rule, info.present)
    -- "with N seconds left" on the built-in Buff / Aura (only with State = present): unknown time keeps the trigger unknown
    if info.buffOK == true and rule.buffState == "present" and rule.buffTimeOp and rule.buffTimeOp ~= "any" then
        info.buffOK = ns.TimeLeftCheck(rule.buffTimeOp, rule.buffTimeSec, info.buffRef)
        if info.buffOK == nil and ns.statusDetail then info.buffSource = tostring(info.buffSource) .. " | seconds left unknown" end
    end
    info.ctxOK, info.ctxFail = ns.CheckContext(rule, ctx)
    info.talentOK, info.talentDetail = ns.CheckTalents(rule)
    if ns.CheckExtraTriggers then info.extraOK, info.extraDetail, info.extraRows, info.extraWhys = ns.CheckExtraTriggers(rule) else info.extraOK = true end
    -- no built-in aura to show: the display takes its time / stacks from the first present aura trigger row (after the rows ran)
    if info.buffRef == nil and type(rule.extra) == "table" then info.auraRef = ns.AuraRowRef(rule) end
    -- the core cooldown / buff dropdowns must be chosen ("none" counts as a choice)
    -- Triggers are added by hand (Triggers.lua): a section only needs its state chosen once it is "used" (added from the
    -- menu, or an ID is set). A rule with no trigger at all and both states blank cannot fire; both states set to "none"
    -- is still the explicit "load conditions only" rule.
    local hasExtra = type(rule.extra) == "table" and type(rule.extra.list) == "table" and #rule.extra.list > 0
    local cdUsed = rule.useCooldown == true or (tonumber(rule.spellID) or 0) ~= 0
    local buffUsed = rule.useBuff == true or (tonumber(rule.buffID) or 0) ~= 0
    local anyTrigger = cdUsed or buffUsed or hasExtra
    if not anyTrigger and unset(rule.cdState) and unset(rule.buffState) then
        info.missing[#info.missing + 1] = "a trigger (none added yet)"
    else
        if unset(rule.cdState) and (cdUsed or not anyTrigger) then info.missing[#info.missing + 1] = "cooldown state" end
        if unset(rule.buffState) and (buffUsed or not anyTrigger) then info.missing[#info.missing + 1] = "buff state" end
    end
    -- talents are optional: a blank talentMode counts as "ignore talents"
    -- Triggers combine as ALL (default) unless the rule's "activates when" setting names ANY or one trigger (Triggers.lua CombineTriggers).
    local trigOK, trigTri
    if ns.CombineTriggers then trigOK, trigTri = ns.CombineTriggers(rule, info) end
    if trigOK == nil then
        trigOK = (info.cdOK == true) and (info.buffOK == true) and (info.extraOK == true)
        info.trigMode = "all"
    else
        info.trigMode, info.trigTri = rule.trigMode, trigTri
    end
    info.trigOK = trigOK
    info.result = trigOK and info.ctxOK and (info.talentOK == true) and (#info.missing == 0)
    Remember(rule, ctx, info.result, info)
    return info.result, info
end

-- "Loaded" = enabled, load conditions pass and talent requirement passes (cooldown / buff state are NOT part of it).
function ns.IsLoaded(rule, ctx)
    if not rule.enabled then return false end
    if rule.parentUid and ns.FindParentRule then   -- an outcome loads exactly when its parent does
        local p = ns.FindParentRule(rule)
        if p then return ns.IsLoaded(p, ctx) end
    end
    local ok, c = pcall(ns.CheckContext, rule, ctx or ns.ReadContext())
    if not ok or c ~= true then return false end
    local okT, t = pcall(ns.CheckTalents, rule)
    return okT and t == true
end

function ns.WhyNot(info)
    local t = {}
    if info.missing and #info.missing > 0 then t[#t + 1] = "not set: " .. table.concat(info.missing, ", ") end
    if info.cdOK ~= true then t[#t + 1] = "cooldown=" .. tostring(info.cdOK) end
    if info.buffOK ~= true then t[#t + 1] = "buff=" .. tostring(info.buffOK) .. " (" .. tostring(info.buffSource) .. ")" end
    if info.talentOK ~= true then t[#t + 1] = "talent=" .. tostring(info.talentOK) end
    if info.extraOK ~= true then t[#t + 1] = "extra=" .. tostring(info.extraOK) .. " (" .. tostring(info.extraDetail) .. ")" end
    if info.outcome and info.whenOK ~= true then t[#t + 1] = "combination=" .. tostring(info.whenOK) .. " (" .. tostring(info.whenDetail) .. ")" end
    if not info.ctxOK then t[#t + 1] = "load:" .. tostring(info.ctxFail) end
    return table.concat(t, ", ")
end

-------------------------------------------------------------------------------
-- Diagnostics for in-game testing
-------------------------------------------------------------------------------
local function Show(v)
    if v == nil then return "nil" end
    if issecret(v) then return "<SECRET>" end
    return tostring(v)
end

function ns.Probe(spellID)
    if not spellID then ns.Print("usage: /xui probe <spellID>") return end
    ns.Print("probe spell " .. spellID
        .. "  (auras secret now? " .. Show(C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) .. ")")
    local ok, cd = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok and type(cd) == "table" then
        for _, k in ipairs({ "isActive", "isOnGCD", "isEnabled", "duration", "startTime" }) do
            ns.Print("  cooldown." .. k .. " = " .. Show(cd[k]))
        end
    else
        ns.Print("  GetSpellCooldown failed/nil")
    end
    local okc, ch = pcall(C_Spell.GetSpellCharges, spellID)
    if okc and type(ch) == "table" then
        for _, k in ipairs({ "isActive", "maxCharges", "currentCharges" }) do
            ns.Print("  charges." .. k .. " = " .. Show(ch[k]))
        end
    else
        ns.Print("  GetSpellCharges nil (not a charge spell)")
    end
    local present, src = ns.BuffPresent(spellID)
    ns.Print("  as a BUFF id -> present=" .. Show(present) .. " via " .. src)
    ns.Print("  aura reads restricted now: " .. tostring(ns.AurasRestricted())
        .. " | this spell's aura NeverSecret: " .. tostring(ns.AuraTrackable(spellID)))
    if C_Secrets and C_Secrets.ShouldCooldownsBeSecret then
        local okk, cv = pcall(C_Secrets.ShouldCooldownsBeSecret)
        ns.Print("  cooldown reads restricted now: " .. Show(okk and cv or "error"))
    end
end

-- Same detail as /xui status, but written to the ring-buffer log (ns.Log) instead of chat, so it can be read
-- from the settings window's debug console tray AFTER a fight without typing anything while in combat.
-- The periodic in-combat snapshot ("combat tick") logs only rules whose answer changed since the last snapshot, and reads the
-- engine's own latest results instead of evaluating every rule a second time; combat start / end log everything.
local snapLast = setmetatable({}, { __mode = "k" })
function ns.LogStatusSnapshot(tag)
    if not ns.rules or #ns.rules == 0 then return end
    local ctx = ns.ReadContext()
    local changesOnly = tag == "combat tick"
    ns.Log("-- status snapshot (%s) -- spec=%s role=%s combat=%s%s", tostring(tag or "?"),
        tostring(ctx.specID), tostring(ctx.role), tostring(ctx.combat), changesOnly and " (changes only)" or "")
    for i, r in ipairs(ns.rules) do
        if r.enabled then
            local rt = ns.runtime and ns.runtime[r]
            local ok, res, info
            if rt and rt.info then ok, res, info = true, rt.info.result, rt.info
            else ok, res, info = pcall(ns.Evaluate, r, ctx) end
            local key = ok and (tostring(res) .. tostring(info.cdOK) .. tostring(info.buffOK) .. tostring(info.ctxOK) .. tostring(info.extraOK)) or "error"
            local same = snapLast[r] == key
            snapLast[r] = key
            if changesOnly and same then
                -- unchanged: not logged
            elseif ok then
                ns.Log("#%d %s result=%s | cd:%s(%s) buff:%s(%s via %s) ctx:%s talent:%s extra:%s",
                    i, r.name, tostring(res), tostring(r.cdState), tostring(info.cdOK),
                    tostring(r.buffState), tostring(info.buffOK), tostring(info.buffSource),
                    tostring(info.ctxOK), tostring(info.talentOK), tostring(info.extraOK))
            else
                ns.Log("#%d %s ERROR: %s", i, r.name, tostring(res))
            end
        end
    end
end

local PrintStatusRaw
function ns.PrintStatus()
    ns.statusDetail = true   -- readable time-source labels while /xui status runs (Timing.lua)
    local ok, err = pcall(PrintStatusRaw)
    ns.statusDetail = nil
    if not ok then ns.Print("status failed: " .. tostring(err)) end
end
function PrintStatusRaw()
    if not ns.rules or #ns.rules == 0 then ns.Print("no rules") return end
    local ctx = ns.ReadContext()
    ns.Print(("context: combat=%s group=%s raid=%s instance=%s(%s) mplus=%s encounter=%s mounted=%s spec=%s role=%s"):format(
        tostring(ctx.combat), tostring(ctx.group), tostring(ctx.raid), tostring(ctx.instance),
        tostring(ctx.instanceType), tostring(ctx.mythicPlus), tostring(ctx.encounter),
        tostring(ctx.mounted), tostring(ctx.specID), tostring(ctx.role)))
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


-------------------------------------------------------------------------------
-- What can a stack / charge count show for a rule (#300)? It follows what the rule's triggers track:
--   * a Cooldown trigger counts CHARGES, only when the spell really has more than one (the game's maxCharges, or the rule's override);
--   * an aura trigger counts STACKS when the aura can stack. First the game's own answer, C_Spell.GetSpellMaxCumulativeAuraApplications
--     (12.1.5 Spell docs; secret while auras are restricted, so read out of combat / in the options window). A readable answer above 1
--     means it stacks; 0 or 1 means it does not, unless this client has SEEN it above 1 (the meaning of 0 / 1 is not confirmed in game).
--     When the game gives no answer, this client's own observations: an aura seen at least twice and never above 1 does not stack.
--     An aura never seen and not answered stays "may stack", so a real stacking aura is not hidden by a guess;
--   * a trigger that tracks neither (item count, totem, range, player state ...) has nothing to count.
-- Callers hide count options when nothing can be counted; an option that is already in use stays visible.
-------------------------------------------------------------------------------
do
local MIN_SEEN = 2
local function Store()
    if type(CueRulesDB) ~= "table" then return nil end
    if type(CueRulesDB.learnedAuraStacks) ~= "table" then CueRulesDB.learnedAuraStacks = {} end
    return CueRulesDB.learnedAuraStacks
end
local lastIid = {}   -- spellID -> auraInstanceID last counted (session only)
-- Called by the aura reader with the spell ID it asked for and the aura table it got back (readable numbers only).
function ns.LearnStacks(id, aura)
    local db = Store()
    id = tonumber(id)
    if not db or not id or id == 0 or type(aura) ~= "table" then return end
    local oka, apps = pcall(function() return aura.applications end)
    if not oka or type(apps) ~= "number" or issecret(apps) then return end
    local okI, iid = pcall(function() return aura.auraInstanceID end)
    if not okI or issecret(iid) then iid = nil end
    local e = db[id]
    if type(e) ~= "table" then e = { max = 0, seen = 0 }; db[id] = e end
    if apps > (tonumber(e.max) or 0) then e.max = apps end
    if iid == nil then
        if (tonumber(e.seen) or 0) == 0 then e.seen = 1 end
    elseif lastIid[id] ~= iid then
        lastIid[id] = iid
        e.seen = (tonumber(e.seen) or 0) + 1
    end
end
-- the game's maximum stack count for an aura, or nil when it does not say (missing call, secret, error)
function ns.AuraMaxStacks(id)
    id = tonumber(id) or 0
    if id == 0 or not (C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications) then return nil end
    local ok, n = pcall(C_Spell.GetSpellMaxCumulativeAuraApplications, id)
    if not ok or issecret(n) or type(n) ~= "number" then return nil end
    return n
end
-- true = can (or may) stack, false = does not stack
function ns.AuraMayStack(id)
    id = tonumber(id) or 0
    if id == 0 then return false end
    local db = Store()
    local e = db and db[id]
    if type(e) == "table" and (tonumber(e.max) or 0) > 1 then return true end
    local m = ns.AuraMaxStacks(id)
    if m ~= nil then return m > 1 end
    if type(e) == "table" and (tonumber(e.seen) or 0) >= MIN_SEEN then return false end
    return true
end
function ns.SpellHasCharges(id, override)
    id = tonumber(id) or 0
    if (tonumber(override) or 0) > 1 then return true end
    if id == 0 or not (C_Spell and C_Spell.GetSpellCharges) then return false end
    local ok, ch = pcall(C_Spell.GetSpellCharges, id)
    if ok and type(ch) == "table" then
        local m = ch.maxCharges
        if type(m) == "number" and not issecret(m) and m > 1 then return true end
    end
    return false
end
local function AnyStacks(ids)
    for _, id in ipairs(ids) do if ns.AuraMayStack(id) then return true end end
    return false
end
-- returns { charges = bool, stacks = bool, any = bool } for a rule (cues and conditions follow their rule's triggers)
function ns.CountSupport(rule)
    local r = rule
    if rule and rule.parentUid and ns.FindParentRule then r = ns.FindParentRule(rule) or rule end
    local out = { charges = false, stacks = false }
    if type(r) ~= "table" then out.any = true; out.charges, out.stacks = true, true; return out end
    if ns.CooldownUsed and ns.CooldownUsed(r) and ns.SpellHasCharges(r.spellID, r.maxCharges) then out.charges = true end
    if ns.BuffUsed and ns.BuffUsed(r) then
        local ids = { r.buffID }
        for _, id in ipairs(type(r.buffAlt) == "table" and r.buffAlt or {}) do ids[#ids + 1] = id end
        if AnyStacks(ids) then out.stacks = true end
    end
    local list = type(r.extra) == "table" and type(r.extra.list) == "table" and r.extra.list or {}
    for _, t in ipairs(list) do
        if type(t) == "table" and (t.type == "buffAura" or t.type == "targetDebuff") then
            local ids = { t.spellID }
            for _, id in ipairs(type(t.alt) == "table" and t.alt or {}) do ids[#ids + 1] = id end
            if AnyStacks(ids) then out.stacks = true end
        end
    end
    out.any = out.charges or out.stacks
    return out
end
-- one aura trigger row (or the built-in, row = nil): can its stack count be more than 1?
function ns.TriggerMayStack(rule, row)
    if row then
        local ids = { row.spellID }
        for _, id in ipairs(type(row.alt) == "table" and row.alt or {}) do ids[#ids + 1] = id end
        return AnyStacks(ids)
    end
    local ids = { rule.buffID }
    for _, id in ipairs(type(rule.buffAlt) == "table" and rule.buffAlt or {}) do ids[#ids + 1] = id end
    return AnyStacks(ids)
end
end
