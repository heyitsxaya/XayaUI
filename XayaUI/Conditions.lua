-------------------------------------------------------------------------------
-- Conditions.lua : read game state WITHOUT ever comparing a secret value.
--
-- Every read is pcall-wrapped and every value is checked with issecretvalue()
-- before it is compared. Anything unreadable becomes nil ("unknown"), and a
-- rule that depends on an unknown input does NOT fire (silent, never wrong).
-------------------------------------------------------------------------------
local addonName, ns = ...
local CoreS = ns.Settings("core")   -- (core 0.6.75, P2 settings seam: the same CueRulesDB keys as before)

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
--   why    : short note for /xui debug status
-------------------------------------------------------------------------------
local ReadCooldownRaw, KnowsSpell
function ns.ReadCooldown(rule)
    -- the same spell is often watched by several rules: read it once per engine step (the result is only ever read)
    local memo = ns.StepMemo and ns.StepMemo("cooldown")
    if not memo then return ReadCooldownRaw(rule) end
    local id, mc = rule.spellID or 0, rule.maxCharges or 0
    -- #309: one flat memo; the plain case (no charge override, following the bar) is keyed by the spell ID itself, so no table
    -- or string is made per spell per step. B4: an exact-ID rule reads another spell than a following one.
    local key = id
    if mc ~= 0 or rule.exactSpell then key = tostring(id) .. "/" .. tostring(mc) .. (rule.exactSpell and "x" or "") end
    local r = memo[key]
    if not r then r = ReadCooldownRaw(rule); memo[key] = r end
    return r
end
-------------------------------------------------------------------------------
-- Charges in combat (0.6.9). The game hides a spell's charge count in combat (SpellChargeInfo.currentCharges is secret), but
-- keeps three things readable (all NeverSecret in 12.1.5): the maximum (maxCharges), whether a charge is recharging
-- (SpellChargeInfo.isActive), and whether the spell's own cooldown runs (SpellCooldownInfo.isActive / isOnGCD / isEnabled).
-- 0.6.8 read "not recharging" as "full". Insivius, 2026-11-04: his Death and Decay rule fired "before he has charges
-- available": a charge that was used is not always recharging at once (Blizzard's documentation: "isActive: False if
-- recharging is not active (ex: at maximum available charges, start time or duration are zero)"; a cooldown can also be on
-- hold), so "not recharging" alone does not prove "full". The count is now built from anchors and your own casts:
--   * out of combat: the exact count (an anchor);
--   * the spell's own cooldown runs (not the global cooldown): 0 charges (Blizzard's Cooldown Manager shows the spell's own
--     cooldown only once no charge is left, Blizzard_CooldownViewer CheckCacheCooldownValuesFromCharges; an anchor);
--   * the spell's own cooldown is on hold (isEnabled false): it cannot be used: not full, count unknown;
--   * full only when nothing is recharging AND none of your casts of the spell came after the last moment it was seen full
--     (an exact read at the maximum, or a recharge seen to finish: recharging -> not recharging);
--   * in between: the last anchor, minus your casts of the spell since, plus the charges the Cooldown Manager reported
--     gained since (its ChargeGained alert, when the spell is in it), kept within what the flags allow. A 2-charge spell that
--     is recharging is exactly 1.
-- Your own casts are readable in combat (UNIT_SPELLCAST_SUCCEEDED on "player"; Triggers.lua). A talent that replaces the
-- spell (an override, C_Spell.GetOverrideSpell) is read instead of the base spell, and its casts count too.
-- When nothing proves the count, it is unknown (nil), never a guess; a rule waiting for it does not fire.
-------------------------------------------------------------------------------
local chargeSeen = {}   -- [readID] = { fullAt = t, anchorN = n, anchorT = t, recharging = bool, max = n }
local castTimes = {}    -- [spellID] = { t1, t2, ... } own casts, newest last (at most 12)
local function NoteCast(spellID, t)
    if type(spellID) ~= "number" or issecret(spellID) then return end
    local l = castTimes[spellID]
    if not l then l = {}; castTimes[spellID] = l end
    l[#l + 1] = t
    if #l > 12 then table.remove(l, 1) end
end
ns.NoteChargeCast = NoteCast
local function CastsAfter(t, a, b)
    local n, last = 0, nil
    for _, id in ipairs({ a, b }) do
        local l = id and castTimes[id]
        if l then
            for i = 1, #l do
                if l[i] > t then n = n + 1; if not last or l[i] > last then last = l[i] end end
            end
        end
        if b == a then break end
    end
    return n, last
end
local function GainsAfter(readID, baseID, t)
    local find = ns.FindCDMFrame
    local fr = find and (find(readID) or find(baseID))
    local l = fr and fr.xuiChargeGains
    local n = 0
    if l then for i = 1, #l do if l[i] > t then n = n + 1 end end end
    return n, l ~= nil
end
function ns.SpellOnBar(id)
    if not (C_Spell and C_Spell.GetOverrideSpell) then return id end
    local ok, ov = pcall(C_Spell.GetOverrideSpell, id)
    if ok and type(ov) == "number" and not issecret(ov) and ov > 0 then return ov end
    return id
end
-- B4 "Exact spell ID": a cooldown trigger (rule or "Cooldown (any spell)" row) with exactSpell ticked reads the spell ID it was
-- given, never the talent that replaces it on the bar. Unticked (default): the spell on the bar, as before.
function ns.CooldownReadID(t, id)
    if t and t.exactSpell then return id end
    return ns.SpellOnBar(id)
end
-- count (or nil), full (true / false / nil), note
local function ChargeState(readID, baseID, ch, maxC, cd)
    local now = GetTime()
    local st = chargeSeen[readID]
    if not st then st = {}; chargeSeen[readID] = st end
    st.max = maxC
    local cur = CleanNumber(ch, "currentCharges")
    local recharging = CleanBool(ch, "isActive")
    if cur then   -- readable (out of combat): exact
        if cur > maxC then cur = maxC end
        st.anchorN, st.anchorT, st.recharging = cur, now, (recharging == nil) and (cur < maxC) or recharging
        if cur >= maxC then st.fullAt = now end
        return cur, cur >= maxC, "exact"
    end
    local prev = st.recharging
    if recharging ~= nil then st.recharging = recharging end
    local cdActive, onGCD, enabled = CleanBool(cd, "isActive"), CleanBool(cd, "isOnGCD"), CleanBool(cd, "isEnabled")
    if cdActive == true and onGCD ~= true then
        -- 0 charges only when a charge is also recharging: some spells lock out for a moment while charges remain (a known
        -- exception, noted in EllesmereUI's comments as "not universal"; API facts only), which reads as not ready, count unknown
        if recharging == true then
            st.anchorN, st.anchorT = 0, now
            return 0, false, "0: the spell's own cooldown runs while a charge recharges (no charge left)"
        end
        return nil, false, "the spell's own cooldown runs but no charge recharges (a lockout): not ready, count unknown"
    end
    if enabled == false then return nil, false, "the spell's cooldown is on hold: not usable, count unknown" end
    if recharging == nil then return nil, nil, "charges unreadable" end
    if recharging == false and prev == true then st.fullAt = now end   -- a recharge just finished
    local fullAt = st.fullAt or -1
    local castsSinceFull = CastsAfter(fullAt, baseID, readID)
    if recharging == false then
        if castsSinceFull == 0 then
            st.anchorN, st.anchorT = maxC, now
            if not st.fullAt then st.fullAt = now end
            return maxC, true, (fullAt < 0) and "full (nothing recharging, none of your casts seen)" or "full"
        end
        -- not recharging, yet a charge was used after it was last seen full: the recharge has not started
        local n
        if st.anchorT and st.anchorN then
            local c = CastsAfter(st.anchorT, baseID, readID)
            local g = GainsAfter(readID, baseID, st.anchorT)
            local v = st.anchorN - c + g
            if v >= 0 and v <= maxC - 1 then n = v end   -- (a count that does not add up stays unknown)
        end
        return n, false, "a charge was used and its recharge has not started yet"
    end
    -- recharging: between 1 and max - 1
    if maxC == 2 then st.anchorN, st.anchorT = 1, now; return 1, false, "1 (recharging, 2 charges)" end
    -- 3 or more: counted only when the Cooldown Manager reports this spell's charge gains, and only when the count adds up
    if st.anchorT and st.anchorN then
        local c = CastsAfter(st.anchorT, baseID, readID)
        local g, tracked = GainsAfter(readID, baseID, st.anchorT)
        if tracked then
            local v = st.anchorN - c + g
            if v >= 1 and v <= maxC - 1 then return v, false, "counted: your casts and the Cooldown Manager's charge gains" end
            return nil, false, "the count does not add up (a cast or a charge gain was missed): unknown until full, 0 or out of combat"
        end
    end
    return nil, false, "recharging; with 3 or more charges the count needs the spell in the Cooldown Manager"
end
ns._ChargeState = ChargeState

-- The watcher: every rule's charge spell is read whenever the game reports a charge change, at login, on talent / spell
-- changes and when combat starts or ends, whether or not the rule is loaded. Out of combat that records the exact count, so a
-- rule that only loads in combat starts from an exact count, and casts from an earlier pull never hold it back; in combat it
-- sees a recharge finish even between engine steps.
local function WatchCharges()
    if not (ns.rules and C_Spell and C_Spell.GetSpellCharges) then return end
    local done = {}
    -- the rule's own spell, and every "Cooldown (any spell)" row (retrospective gap 22: rows were not watched, so after a /reload
    -- in combat a used charge read "full")
    -- each entry: the spell ID and whether it is read exactly (B4) or as the spell on the bar
    local ids = {}
    for _, r in ipairs(ns.rules) do
        if r.enabled ~= false then
            ids[#ids + 1] = { tonumber(r.spellID), r.exactSpell }
            if type(r.extra) == "table" and type(r.extra.list) == "table" then
                for _, row in ipairs(r.extra.list) do
                    if type(row) == "table" and row.type == "cooldown" then ids[#ids + 1] = { tonumber(row.spellID), row.exactSpell } end
                end
            end
        end
    end
    for _, e in ipairs(ids) do
        local id = e[1]
        local readID = (id and id > 0) and ns.CooldownReadID({ exactSpell = e[2] }, id) or nil
        if readID and not done[readID] then
            done[readID] = true
            local okc, ch = pcall(C_Spell.GetSpellCharges, readID)
            local maxC = okc and CleanNumber(ch, "maxCharges") or nil
            if maxC and maxC > 1 then
                local okd, cd = pcall(C_Spell.GetSpellCooldown, readID)
                pcall(ChargeState, readID, id, ch, maxC, okd and cd or nil)
            end
        end
    end
end
ns._WatchCharges = WatchCharges
if CreateFrame then
    local wf = CreateFrame("Frame")
    for _, e in ipairs({ "SPELL_UPDATE_CHARGES", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "SPELLS_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_SPECIALIZATION_CHANGED" }) do pcall(wf.RegisterEvent, wf, e) end
    if wf.SetScript then wf:SetScript("OnEvent", function() pcall(WatchCharges) end) end
end

-- C_SpellBook.IsSpellKnownOrInSpellBook(spellID, bank, includeOverrides): true / false, or nil when unreadable (secret, error)
function KnowsSpell(x, bank)
    local okK, v = pcall(C_SpellBook.IsSpellKnownOrInSpellBook, x, bank, true)
    if okK and not issecret(v) and type(v) == "boolean" then return v end
end
function ReadCooldownRaw(rule)
    local id = rule.spellID
    local r = { known = false, max = 1 }
    if not id or id == 0 then r.why = "no spell"; return r end
    local readID = ns.CooldownReadID(rule, id)   -- a talent that replaces the spell: the one on your bar (unless exactSpell, B4)
    -- A spell you do not have now (talent or specialization swapped away) is "not known", never "ready" (retrospective gap 10;
    -- the game reports isActive = false for it, which read as ready). C_SpellBook.IsSpellKnownOrInSpellBook(spellID, bank,
    -- includeOverrides) has no secrecy flag (12.1.5); the player and the pet spellbook are both asked, and IsPlayerSpell too.
    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
        -- (KnowsSpell is a file-level function, and IsPlayerSpell is called directly: no closure per call; A15 P-10, per-step garbage)
        local petBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
        local known = KnowsSpell(id) or (readID ~= id and KnowsSpell(readID)) or (petBank and KnowsSpell(id, petBank))
        if known == nil and IsPlayerSpell then local okP, v = pcall(IsPlayerSpell, id); if okP and v == true then known = true end end
        if known == false then
            local okP, v = false, nil
            if IsPlayerSpell then okP, v = pcall(IsPlayerSpell, id) end
            if not (okP and v == true) then r.why = "spell not known (talent or specialization)"; return r end
        end
    end

    local ok, cd = pcall(C_Spell.GetSpellCooldown, readID)
    if not ok or type(cd) ~= "table" then r.why = "cooldown unreadable"; return r end
    local cdActive = CleanBool(cd, "isActive")
    local onGCD = CleanBool(cd, "isOnGCD")
    -- the raw global-cooldown fact, for rules that count it (rule.countGCD, ns.CheckCooldownState). SpellCooldownInfo.isOnGCD: bool?
    -- · NeverSecret, Nilable (docs/reference/api/structures.md:6549): readable in combat; nil (not given) counts as "not on the GCD"
    r.onGCD = (onGCD == true)
    -- a loss-of-control lockout (interrupt, silence) on this spell, for rules that count it (rule.countLOC, B3).
    -- C_Spell.GetSpellLossOfControlCooldownInfo -> SpellLossOfControlInfo · MayReturnNothing, SecretWhenCooldownsRestricted
    -- (docs/reference/api/namespaces.md:4411); its isActive is NeverSecret (structures.md:6597), so it reads in combat. Not given = no lockout.
    do
        local fn = C_Spell.GetSpellLossOfControlCooldownInfo
        local okL, loc = false, nil
        if fn then okL, loc = pcall(fn, readID) end
        r.locked = (okL and type(loc) == "table" and CleanBool(loc, "isActive") == true) or false
    end
    local okc, ch = pcall(C_Spell.GetSpellCharges, readID)
    local maxC = okc and CleanNumber(ch, "maxCharges") or nil
    if (not maxC or maxC < 2) and (rule.maxCharges or 0) > 1 then
        -- manual override: only meaningful if the game did report a charge table
        if okc and type(ch) == "table" then maxC = rule.maxCharges end
    end
    r.max = maxC or 1
    if readID ~= id then r.readID = readID end

    if r.max > 1 and type(ch) == "table" then
        local n, full, note = ChargeState(readID, id, ch, r.max, cd)
        r.count, r.atMax = n, full
        if n ~= nil then r.empty = (n == 0) elseif full == true then r.empty = false end
        r.onCd = (cdActive == true and onGCD ~= true) or false
        r.known = (full ~= nil) or (n ~= nil)
        r.why = "charges (max " .. r.max .. "): " .. tostring(note) .. ((readID ~= id) and (" | reading " .. readID .. ", the spell on your bar") or "")
        if cdActive and not onGCD and ns.Timing then ns.Timing.LearnCooldown(id, CleanNumber(cd, "duration"), onGCD) end
        return r
    end

    if cdActive == nil then
        -- hidden (combat): the duration engine's estimate - exact start from the Cooldown Manager + the measured length
        local T = ns.Timing
        local ready, _, label
        if T then ready, _, label = T.CooldownEstimate(id) end
        if not ready then r.why = "cooldown hidden in combat, no estimate yet"; return r end
        r.onCd = GetTime() < ready
        r.readyAt, r.estimated = ready, true
        r.atMax, r.empty = not r.onCd, r.onCd
        r.count = r.onCd and 0 or 1
        r.known, r.why = true, label
        return r
    end
    r.onCd = cdActive and not onGCD
    if cdActive and not onGCD and ns.Timing then ns.Timing.LearnCooldown(id, CleanNumber(cd, "duration"), onGCD) end
    -- an ability on hold (its cooldown starts only after something ends) cannot be used yet
    if CleanBool(cd, "isEnabled") == false then r.onCd = true end
    r.atMax = not r.onCd
    r.empty = r.onCd
    r.count = r.onCd and 0 or 1
    r.why = "single-charge"
    r.known = true
    return r
end

-- Does cdState match? returns true/false/nil(unknown)
-- rule.countGCD (Xaya 2026-11-04 backlog, from the cooldown-trigger options): while the spell is on the global cooldown it cannot be
-- cast, so it counts as on cooldown: not ready, no charge available. The shared reading (ns.ReadCooldown, cached per spell for every
-- rule) is never changed; only this rule's answer is.
function ns.CheckCooldownState(rule, cdInfo)
    local s = rule.cdState
    if ns.Ignored(s) then return true end
    if not cdInfo or not cdInfo.known then return nil end
    if (rule.countGCD and cdInfo.onGCD) or (rule.countLOC and cdInfo.locked) then
        if s == "ready" or s == "hasCharge" then return false end
        if s == "notReady" or s == "empty" then return true end
    end
    if s == "ready" then return cdInfo.atMax end
    if s == "notReady" then if cdInfo.atMax == nil then return nil end return not cdInfo.atMax end
    if s == "empty" then return cdInfo.empty end
    if s == "hasCharge" then if cdInfo.empty == nil then return nil end return not cdInfo.empty end
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
-- A Cooldown Manager icon's spell IDs. The game can hide them (secret) while the icon's aura is active, which is exactly when a
-- rule needs the icon (EllesmereUI's notes say the same of GetSpellID and the cooldownInfo fields; API facts only). So the IDs
-- an icon showed when they were readable are kept on it (xuiLastIDs) and used while they are hidden. Blizzard reuses icons
-- for other spells: Timing.lua clears the kept IDs when an icon is given another spell (OnCooldownIDSet).
local function FrameIDs(fr)
    local ids, hidden = {}, false
    local function Add(v)
        if v == nil then return end
        if issecret(v) then hidden = true; return end
        if type(v) == "number" then ids[#ids + 1] = v end
    end
    local ok, sid = pcall(GetSpellIDOf, fr)
    if ok then Add(sid) else hidden = true end
    local okI, info = pcall(Field, fr, "cooldownInfo")
    if okI and issecret(info) then hidden = true
    elseif okI and type(info) == "table" then
        for _, k in ipairs({ "spellID", "overrideSpellID", "overrideTooltipSpellID" }) do
            local okF, v = pcall(Field, info, k)
            if okF then Add(v) else hidden = true end
        end
        local okL, l = pcall(Field, info, "linkedSpellIDs")
        if okL and issecret(l) then hidden = true
        elseif okL and type(l) == "table" then for _, x in ipairs(l) do Add(x) end end
    end
    if hidden then
        local last = fr.xuiLastIDs
        if type(last) == "table" then for _, x in ipairs(last) do ids[#ids + 1] = x end end
    elseif #ids > 0 then
        fr.xuiLastIDs = ids
    end
    return ids
end
ns._FrameIDs = FrameIDs
-- A viewer that is not visible has stopped listening for aura changes (Blizzard_CooldownViewer CooldownViewerMixin:OnHide
-- unregisters UNIT_AURA, CooldownViewer.lua:1744-1754), so its icons are stale: an unlit icon there does NOT mean "absent".
-- Such viewers are left out of the index, so every Cooldown Manager answer comes from live icons only (retrospective gap 1).
local function ViewerLive(v)
    if not (v and v.IsVisible) then return true end   -- (stand-ins without the method count as live)
    local ok, vis = pcall(v.IsVisible, v)
    if not ok or issecret(vis) then return true end
    return vis == true
end
ns._ViewerLive = ViewerLive
local function BuildCDMIndex()
    local idx = {}
    for _, vname in ipairs(VIEWERS) do
        local v = _G[vname]
        if v and v.GetChildren and ViewerLive(v) then
            local kids = { v:GetChildren() }
            for i = 1, #kids do
                local fr = kids[i]
                if fr then
                    if ns.Timing then ns.Timing.HookFrame(fr) end   -- exact applied / removed / cooldown moments (Timing.lua)
                    for _, x in ipairs(FrameIDs(fr)) do IndexID(idx, x, fr, vname) end
                end
            end
        end
    end
    return idx
end
local FindCDMFrame
function ns.FindCDMFrame(id) return FindCDMFrame(id) end
-- Read-only: is a live Cooldown Manager icon for spell / aura `id` lit (true), present but unlit (false), or is there none (nil)?
-- Unlike ns.BuffPresent it feeds nothing (no presence stamps, no tracker): the Target Debuff trigger asks about the TARGET's
-- debuff, which must not be recorded as the player's buff (retrospective gap 1).
function ns.CDMFrameState(id)
    id = tonumber(id)
    if not id or id == 0 then return nil end
    local fr = FindCDMFrame(id)
    if not fr then return nil end
    local ok, act = pcall(FrameActive, fr)
    if not ok then return nil end
    return act and true or false
end
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
-- ref.hiddenID marks "an aura is there, its id is hidden" for /xui debug status.
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
    if frame then ref.cdmFrame = frame end   -- the Cooldown Manager icon that answered: its applied moment starts the time estimate (gap 7)
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
-- diagnostic detail for /xui debug status: what a Cooldown Manager frame reports (secret-safe, no arithmetic). File level so no closure is made
-- per read (#309).
local function CDMDetail(fr)
    local iid = fr.auraInstanceID
    local u = fr.auraDataUnit
    return ("iid=%s wasAura=%s shown=%s unit=%s"):format(
        issecret(iid) and "secret" or tostring(iid),
        tostring(fr.wasSetFromAura == true), tostring(fr:IsShown() and true or false),
        issecret(u) and "secret" or tostring(u))
end
-- aura IDs read as a real buff on the player this session (not saved): AuraAlias.lua never aliases those (a rule that lists the buff's
-- own ID needs no alias, and a namesake of it is a different buff)
local seenReadable = {}
function ns.AuraSeenReadable(id) return seenReadable[id] == true end
local HIDDEN_PREFIX = "hidden by the game right now (auras are secret, as in combat): aura "
ns.HIDDEN_AURA_PREFIX = HIDDEN_PREFIX
local function BuffPresentRaw(id)
    if not id or id == 0 then return nil, "no buff" end
    -- A real aura table proves presence, in any context.
    local api, aura = ReadAuraAPI(id)
    if api == "found" then
        seenReadable[id] = true   -- this ID is itself a buff on you: never aliased (AuraAlias.lua; hub F2 guard)
        if ns.LearnStacks then pcall(ns.LearnStacks, id, aura) end   -- what the stack count can be (#300; CountSupport below)
        return true, "aura API", MakeRef(aura)
    end
    -- The same buff under another spell ID, learned in this player's own game (AuraAlias.lua: a buff with this aura's name seen on
    -- the player while readable, e.g. a cast ID whose buff carries its own ID). Readable only while the game shows auras.
    if ns.AuraAliasesOf then
        local al = ns.AuraAliasesOf(id)
        if al then
            for aid in pairs(al) do
                local a2, aura2 = ReadAuraAPI(aid)
                if a2 == "found" then
                    return true, "aura " .. tostring(aid) .. " (same name as " .. tostring(id) .. ", learned in game)", MakeRef(aura2)
                end
            end
        end
    end
    -- Cooldown Manager frame: authoritative when the buff is tracked there.
    local fr, vname = FindCDMFrame(id)
    if fr then
        local okA, active = pcall(FrameActive, fr)
        active = okA and active or false
        -- diagnostic detail for /xui debug status: what the frame actually reports (secret-safe, no arithmetic)
        local okd, detail = pcall(CDMDetail, fr)
        return active and true or false, "CDM frame (" .. vname .. (okd and (": " .. detail) or "") .. ")", active and MakeRef(nil, fr) or nil
    end
    -- No proof of presence. "nil" only means MISSING if the read can be trusted.
    if api == "nil" then
        if not AurasRestricted() then return false, "aura API (unrestricted)" end
        if AuraTrackable(id) then return false, "aura API (NeverSecret spell)" end
        -- Gap 20: C_Secrets.ShouldSpellAuraBeSecret(id) (bool, 12.1.5) is NOT used to decide: what "false" promises about a nil read
        -- is undocumented and Blizzard's UI never calls it. It is only reported, so the 2026-11-05 in-game data can settle it.
        local note = ""
        if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret then
            local okS, v = pcall(C_Secrets.ShouldSpellAuraBeSecret, id)
            if okS and not issecret(v) and type(v) == "boolean" then note = v and " (game: aura secret now)" or " (game: aura NOT secret now)" end
        end
        -- Said plainly (Xaya 2026-11-07, externals): the game withholds this aura in combat; XayaUI does not guess. ns.HiddenAuraNote adds,
        -- on the status screens, whether the game's own aura container still draws the rule's display.
        return nil, HIDDEN_PREFIX .. tostring(id) .. " cannot be read and is not in your Cooldown Manager" .. note
    end
    if api == "secret" then return nil, HIDDEN_PREFIX .. tostring(id) .. " is secret and is not in your Cooldown Manager" end
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
local learnedT, learnedEp   -- (P2) kept in an upvalue; looked up again only when the settings epoch moves (Modules.lua section 0b)
local function LearnedTable()
    local t = learnedT
    if learnedEp ~= ns.settingsEpoch or type(t) ~= "table" then
        if not ns.SettingsReady() then return nil end
        t = CoreS.learnedAuraDur
        if type(t) ~= "table" then t = {}; CoreS.learnedAuraDur = t end
        learnedT, learnedEp = t, ns.settingsEpoch
    end
    return t
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
-- is aura ID a the spell sid itself, or does it have the spell's name?
local function SameSpellOrName(a, sid, sname)
    a = tonumber(a)
    if not a or a <= 0 then return false end
    if a == sid then return true end
    return (sname ~= nil and SpellNameOf(a) == sname)
end
local function TrackedBuffOfSpell(spellID, mainID, alts)
    local sid = tonumber(spellID) or 0
    if sid <= 0 then return nil end
    local sname = SpellNameOf(sid)
    -- (no closure per call: A15 P-10, per-step garbage)
    local same = SameSpellOrName(mainID, sid, sname)
    if not same and type(alts) == "table" then
        for _, a in ipairs(alts) do if SameSpellOrName(a, sid, sname) then same = true; break end end
    end
    if not same then return nil end
    local fr, vname = FindTrackedBuffFrame(sid)
    if not fr then return nil end
    local okA, active = pcall(FrameActive, fr)
    active = okA and active or false
    return active and true or false, "CDM tracked buff of the rule's spell " .. sid .. " (" .. tostring(vname) .. "; same name as the aura)",
        active and MakeRef(nil, fr) or nil
end
-- A Tracked Buffs icon or bar (never a cooldown icon) carrying any spell ID with this NAME: Blizzard often files a tracker
-- under the ability rather than the aura it applies (Sigil of Flame: ability 204596, debuff 204598; Death and Decay: 43265 /
-- 188290). Used by the Target Debuff trigger when neither of its IDs matches an icon. true = lit, false = present and not lit,
-- nil = no such icon. The name list is rebuilt with the icon index (at most every 0.25 s).
local byName, byNameAt = {}, -1
function ns.TrackedBuffStateByName(id)
    local name = SpellNameOf(tonumber(id) or 0)
    if not name then return nil end
    FindCDMFrame(tonumber(id) or 0)   -- (refreshes the index when stale)
    if byNameAt ~= cdmAt then
        byName, byNameAt = {}, cdmAt
        for sid, list in pairs(cdmIndex) do
            local n = SpellNameOf(sid)
            if n then
                for i = 1, #list do
                    if BUFF_VIEWERS[list[i][2]] then
                        local l = byName[n]
                        if not l then l = {}; byName[n] = l end
                        l[#l + 1] = list[i][1]
                    end
                end
            end
        end
    end
    local l = byName[name]
    if not l then return nil end
    local any = false
    for i = 1, #l do
        local okA, act = pcall(FrameActive, l[i])
        if okA and act then return true, l[i] end
        any = true
    end
    if any then return false end   -- (not `any and false or nil`: that always yields nil)
    return nil
end
function ns.FindTrackedBuffFrameByName(id)
    local st, fr = ns.TrackedBuffStateByName(id)
    if st == true then return fr end
end

-------------------------------------------------------------------------------
-- Proc glows (retrospective gap 5). SPELL_ACTIVATION_OVERLAY_GLOW_SHOW / _HIDE (spellID) and
-- C_SpellActivationOverlay.IsSpellOverlayed(spellID) -> bool carry no secrecy flag in the 12.1.5 docs, and Blizzard's own buttons
-- use them in combat (ActionButton.lua compares the event's spellID with the action's spell; CooldownViewer.lua RefreshOverlayGlow
-- asks IsSpellOverlayed(self:GetSpellID())). Which ID a glow names (the base spell or its replacement) depends on the caller, so
-- the spell, its replacement on the bar and its base spell are all asked.
-------------------------------------------------------------------------------
local glowOn = {}   -- spellID -> true between GLOW_SHOW and GLOW_HIDE (used only when IsSpellOverlayed cannot be read)
local function GlowIDs(id)
    local ids = { id }
    local ov = ns.SpellOnBar(id)
    if ov ~= id then ids[#ids + 1] = ov end
    if C_Spell and C_Spell.GetBaseSpell then
        local ok, b = pcall(C_Spell.GetBaseSpell, id)
        if ok and type(b) == "number" and not issecret(b) and b > 0 and b ~= id and b ~= ov then ids[#ids + 1] = b end
    end
    return ids
end
-- true (glowing) / false (read: not glowing) / nil (cannot tell); second value: the ID that glows
function ns.SpellGlowing(id)
    id = tonumber(id)
    if not id or id <= 0 then return nil end
    local fn = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
    local read = false
    for _, x in ipairs(GlowIDs(id)) do
        local v
        if fn then
            local ok, r = pcall(fn, x)
            if ok and not issecret(r) and type(r) == "boolean" then v = r end
        end
        if v == true then return true, x end
        if v == false then read = true
        elseif glowOn[x] then return true, x end
    end
    if read then return false end
    return nil
end

-- Glow -> aura. ns.PROC_GLOW_AURAS (ProcGlows.lua, generated from the game's SpellActivationOverlay table) lists, per proc aura, the
-- buttons NO other aura in that table lights. Which buttons a row lights is the community's reading of the table
-- (docs/reference/procs.md), not confirmed in game, so a pairing is trusted only after XayaUI has seen it hold: each time a listed
-- button starts to glow while the aura can be read, the answer is counted (CueRulesDB.procGlowSeen). The glow then answers
-- "present" only after GLOW_TRUST agreeing sightings and no disagreeing one. A button that is not glowing never answers "absent"
-- (a highlight can also wait on a target, range, resources or the cooldown).
local GLOW_TRUST = 2
ns.GLOW_TRUST = GLOW_TRUST
local glowButtons
local function GlowButtons()
    if glowButtons then return glowButtons end
    glowButtons = {}
    if type(ns.PROC_GLOW_AURAS) == "table" then
        for aura, list in pairs(ns.PROC_GLOW_AURAS) do
            for _, b in ipairs(list) do glowButtons[b] = aura end
        end
    end
    return glowButtons
end
local glowT, glowEp   -- (P2) kept in an upvalue; looked up again only when the settings epoch moves (Modules.lua section 0b)
local function GlowSeenDB()
    local g = glowT
    if glowEp ~= ns.settingsEpoch or type(g) ~= "table" then
        if not ns.SettingsReady() then return nil end
        g = CoreS.procGlowSeen
    end
    -- a new table build can pair buttons differently: start counting again
    if type(g) ~= "table" or g.build ~= ns.PROC_GLOW_BUILD or type(g.auras) ~= "table" then
        g = { build = ns.PROC_GLOW_BUILD, auras = {} }
        CoreS.procGlowSeen = g
    end
    glowT, glowEp = g, ns.settingsEpoch
    return g.auras
end
-- The aura's state from a source that does not depend on the glow: the aura API, or a live Cooldown Manager icon. nil = unknown.
local function AuraStateForGlow(aura)
    local api = ReadAuraAPI(aura)
    if api == "found" then return true end
    local st = ns.CDMFrameState(aura)
    if st ~= nil then return st end
    if api == "nil" and (not AurasRestricted() or AuraTrackable(aura)) then return false end
    return nil
end
function ns.ObserveGlowPairing(buttonID)
    local aura = GlowButtons()[tonumber(buttonID) or 0]
    if not aura then return nil end
    local st = AuraStateForGlow(aura)
    if st == nil then return nil end
    local A = GlowSeenDB()
    if not A then return nil end
    local e = A[aura]
    if type(e) ~= "table" then e = { yes = 0, no = 0 }; A[aura] = e end
    if st then e.yes = (e.yes or 0) + 1 else e.no = (e.no or 0) + 1; e.lastNoButton = buttonID end
    -- (V14: the line, and the spell-name lookup in it, only while the record keeps "Proc glows"; DebugRecord.lua)
    if ns.RecordOn and ns.RecordOn("glow") then
        ns.RecordLine("glow", ("button %s glowed; aura %s (%s) was %s: pairing seen %d agree / %d disagree"):format(tostring(buttonID), tostring(aura),
            tostring(SpellNameOf(aura)), st and "on you" or "NOT on you", e.yes or 0, e.no or 0))
    end
    return st
end
-- What the glow fallback knows about aura `aura`: its buttons, the in-game sightings so far, and whether it is trusted (for the trigger's
-- "In combat" line). nil when no button is listed for it.
function ns.ProcGlowInfo(aura)
    aura = tonumber(aura)
    local list = aura and type(ns.PROC_GLOW_AURAS) == "table" and ns.PROC_GLOW_AURAS[aura]
    if not list then return nil end
    local A = GlowSeenDB()
    local e = A and A[aura]
    local yes, no = (type(e) == "table" and e.yes) or 0, (type(e) == "table" and e.no) or 0
    local names = {}
    for i, b in ipairs(list) do names[i] = tostring(SpellNameOf(b) or b) end
    return { buttons = list, names = names, yes = yes, no = no, trusted = (no == 0 and yes >= GLOW_TRUST), need = GLOW_TRUST }
end
-- Is aura `aura` up, judged by a glowing button only it lights? true or nil (never false).
function ns.ProcGlowSaysPresent(aura)
    aura = tonumber(aura)
    local list = aura and type(ns.PROC_GLOW_AURAS) == "table" and ns.PROC_GLOW_AURAS[aura]
    if not list then return nil end
    local A = GlowSeenDB()
    local e = A and A[aura]
    if type(e) ~= "table" or (e.no or 0) > 0 or (e.yes or 0) < GLOW_TRUST then return nil end
    for _, b in ipairs(list) do
        if ns.SpellGlowing(b) == true then return true, b end
    end
    return nil
end
-- Gap 15: when Blizzard reassigns an icon's spell in combat (COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED baseSpellID, overrideSpellID?;
-- CooldownViewer.lua hands it to the item whose base spell it is), the icon's kept IDs learn the new replacement, so an icon whose
-- IDs are hidden right now is still found under it; the frame index is rebuilt on the next read.
function ns.OnSpellOverrideUpdated(base, override)
    cdmAt = -1
    if issecret(base) or issecret(override) or type(base) ~= "number" or type(override) ~= "number" or override <= 0 then return end
    for _, vname in ipairs(VIEWERS) do
        local v = _G[vname]
        if v and v.GetChildren then
            local kids = { v:GetChildren() }
            for i = 1, #kids do
                local last = kids[i] and kids[i].xuiLastIDs
                if type(last) == "table" then
                    local hasBase, hasNew = false, false
                    for _, x in ipairs(last) do
                        if x == base then hasBase = true end
                        if x == override then hasNew = true end
                    end
                    if hasBase and not hasNew then last[#last + 1] = override end
                end
            end
        end
    end
end
if CreateFrame then
    local gf = CreateFrame("Frame")
    for _, e in ipairs({ "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
        "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", "PLAYER_ENTERING_WORLD" }) do pcall(gf.RegisterEvent, gf, e) end
    if gf.SetScript then
        gf:SetScript("OnEvent", function(_, event, a1, a2)
            if event == "PLAYER_ENTERING_WORLD" then glowOn = {}; return end
            if event == "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED" then pcall(ns.OnSpellOverrideUpdated, a1, a2)
            elseif type(a1) == "number" and not issecret(a1) then
                if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
                    glowOn[a1] = true
                    -- the aura and the glow arrive in either order within a frame: look a moment later
                    if GlowButtons()[a1] and C_Timer and C_Timer.After then
                        C_Timer.After(0.15, function() pcall(ns.ObserveGlowPairing, a1) end)
                    end
                else
                    glowOn[a1] = nil
                end
            end
            if ns.MarkStateDirty then ns.MarkStateDirty() end   -- "Spell glows" rows answer on this frame
        end)
    end
end
-- The ONE presence reading for every aura trigger (the rule's built-in Buff / Aura and every "Buff / Aura (another)" row), so the
-- two can never answer differently (retrospective gap 8):
--   1. the aura API / a live Cooldown Manager icon carrying one of the IDs / the tracker (ns.AuraPresentList);
--   2. when that is unknown: the Tracked Buffs icon of the rule's own spell, when an aura has that spell's name (0.6.8);
--   3. then a Tracked Buffs icon filed under the aura's NAME (Blizzard often files a tracker under the ability: 0.6.11 did this
--      for Target Debuff only).
-- Returns present, source text, reference, and the ID it was found under.
-- Tier-set auras (SetBonusAuras.lua, generated from the game's own data): an aura only a set bonus can apply is certainly not on you
-- while that bonus is not active (too few pieces of the set worn, or the bonus is for another specialization). Equipment and spec are
-- readable in combat, so this answers "missing" where the aura itself is hidden. Returns the reason, or nil (no such aura, the bonus
-- is active, or the gear is not known yet).
local function SetBonusOff(id)
    local e = type(ns.SET_BONUS_AURAS) == "table" and ns.SET_BONUS_AURAS[id]
    if type(e) ~= "table" then return nil end
    local counts = ns.EquippedSetCounts and ns.EquippedSetCounts()
    if type(counts) ~= "table" then return nil end
    local have = counts[e.set] or 0
    if have < (e.pieces or 0) then
        return ("its %d-piece set bonus is not active (you wear %d of set %d)"):format(e.pieces, have, e.set)
    end
    local any, specs = false, e.specs or { 0 }
    for _, sp in ipairs(specs) do if sp == 0 then any = true end end
    if not any then
        local cur = ns.CurrentSpecID and ns.CurrentSpecID()
        if cur == nil then return nil end
        for _, sp in ipairs(specs) do if sp == cur then return nil end end
        return "its set bonus is for another specialization"
    end
    return nil
end
ns.SetBonusOff = SetBonusOff
-- #309: the set-bonus pre-check walks the IDs (mainID, then alts) without building a list each step. Returns the first reason when
-- there is at least one ID and every one of them comes only from a set bonus that is off; nil otherwise.
local function AllSetBonusOff(mainID, alts)
    local n, why = 0, nil
    local m = tonumber(mainID)
    if m then
        n = 1
        local w = m > 0 and SetBonusOff(m)
        if not w then return nil end
        why = w
    end
    if type(alts) == "table" then
        for _, a in ipairs(alts) do
            local id = tonumber(a)
            if id then
                n = n + 1
                local w = id > 0 and SetBonusOff(id)
                if not w then return nil end
                why = why or w
            end
        end
    end
    if n > 0 then return why end
    return nil
end
function ns.AuraPresence(mainID, alts, spellID)
    -- 0. every listed aura comes only from a set bonus that is not active: missing, for sure (in combat too)
    do
        local why = AllSetBonusOff(mainID, alts)
        if why then return false, "set bonus: " .. why end
    end
    local p, s, r, w = ns.AuraPresentList(mainID, alts)
    if p ~= nil then return p, s, r, w end
    if spellID then
        local ok, fp, fs, fr = pcall(TrackedBuffOfSpell, spellID, mainID, alts)
        if ok and fp ~= nil then return fp, fs, fr, mainID end
    end
    local ids = { tonumber(mainID) }
    if type(alts) == "table" then for _, a in ipairs(alts) do ids[#ids + 1] = tonumber(a) end end
    local anyIcon, allUnlit = false, true
    for _, id in ipairs(ids) do
        if id and id > 0 and ns.TrackedBuffStateByName then
            local ok, st = pcall(ns.TrackedBuffStateByName, id)
            if ok and st == true then
                local fr = ns.FindTrackedBuffFrameByName and ns.FindTrackedBuffFrameByName(id)
                return true, "CDM tracked buff with the aura's name (" .. tostring(SpellNameOf(id)) .. ")", MakeRef(nil, fr), id
            end
            if ok and st == false then anyIcon = true else allUnlit = false end
        else
            allUnlit = false
        end
    end
    if anyIcon and allUnlit then return false, "CDM tracked buff with the aura's name, not lit" end
    -- 4. a glowing button that only this aura lights, once the pairing has been seen to hold in game (ns.ProcGlowSaysPresent).
    --    Only ever "present": no glow leaves the answer unknown.
    if p == nil and ns.ProcGlowSaysPresent then
        for _, id in ipairs(ids) do
            if id and id > 0 then
                local ok, g, b = pcall(ns.ProcGlowSaysPresent, id)
                if ok and g == true then
                    return true, "proc glow on " .. tostring(SpellNameOf(b) or b) .. " (" .. tostring(b) .. "; pairing seen in game)", MakeRef(nil, nil), id
                end
            end
        end
    end
    return p, s, r, w
end
function ns.BuffPresentAny(rule)
    if not rule then return nil, "no rule" end
    return ns.AuraPresence(rule.buffID, rule.buffAlt, rule.spellID)
end

-- Status screens only (built on demand, never per engine step): when the game hides a rule's aura (combat), say in plain words what
-- the player will see. Blizzard's own aura container (Combat/AuraDisplay.lua) may still draw the display: it matches spell IDs in the
-- game's secure code, which the game permits for buffs on the player (Blizzard_CustomAuraContainer.lua, includeSpellIDs). XayaUI's
-- own reading stays unknown, so sounds, conditions and "missing" displays wait until auras are readable again (never a guess).
-- Returns nil when the rule's aura is readable (or the rule has no aura).
function ns.HiddenAuraNote(rule, info)
    if type(rule) ~= "table" then return nil end
    local p = rule.parentUid and ns.FindParentRule and ns.FindParentRule(rule) or rule
    if not info then
        local rt = ns.runtime and ns.runtime[p]
        info = rt and rt.info
    end
    if not (info and info.present == nil and type(info.buffSource) == "string") then return nil end
    if info.buffSource:sub(1, #HIDDEN_PREFIX) ~= HIDDEN_PREFIX then return nil end
    local D = ns.AuraDisplay
    local own, why
    if D and D.OwnerOf then own, why = D.OwnerOf(p) end
    -- learned same-name IDs, shown so the player can see them (hub F2)
    local learned = ""
    if ns.AuraAliasesOf then
        local t = {}
        local function add(id)
            local al = ns.AuraAliasesOf(tonumber(id))
            if al then for a in pairs(al) do t[#t + 1] = tostring(a) .. " for " .. tostring(id) end end
        end
        add(p.buffID)
        if type(p.buffAlt) == "table" then for _, a in ipairs(p.buffAlt) do add(a) end end
        if #t > 0 then table.sort(t); learned = " Also matched: buff ID " .. table.concat(t, ", ") .. " (same name, learned in game)." end
    end
    if own == true then
        return "the game hides this aura now; the game's own aura container still draws this display (" .. tostring(why)
            .. "). Sounds, conditions and 'missing' wait until the game shows auras again." .. learned
    elseif own == false then
        return "the game hides this aura now, so XayaUI cannot show this display: the game's aura container does not draw it ("
            .. tostring(why) .. ")." .. learned
    end
    return "the game hides this aura now, so XayaUI cannot show this display (no display drawn by the game's aura container)." .. learned
end

-- Advanced Debugging record (DebugRecord.lua): each aura's answer is written down when it changes (present / missing / unknown, and
-- which source gave it), so a combat can be followed afterwards without typing /xui debug status. Off: nothing is built or kept.
local recLast, recP, recS = {}, {}, {}
-- forget what was written, so every aura's current answer is written again (after Clear, or when recording starts)
function ns.ResetRecordedAuras() wipe(recLast); wipe(recP); wipe(recS) end
local function RecordAura(id, present, src)
    -- fast path (core 0.6.22, "cpu friendly"): the same answer from the same source as last time does no string work at all
    if recP[id] == present and recS[id] == src and recLast[id] ~= nil then return end
    if not (ns.RecordOn and ns.RecordOn("aura")) then return end
    recP[id], recS[id] = present, src
    local kind = tostring(src or ""):match("^([^%(:|]+)") or tostring(src)
    kind = kind:gsub("%s+$", "")
    local key = tostring(present) .. "|" .. kind
    if recLast[id] == key then return end
    recLast[id] = key
    -- (%s, not %d: an imported rule can hold a non-numeric ID, and the record must never break the aura read it watches)
    ns.RecordLine("aura", ("%s (%s): %s, %s"):format(tostring(SpellNameOf and SpellNameOf(id) or "?"), tostring(id),
        present == true and "present" or (present == false and "missing" or "unknown"), tostring(src)))
end
local BuffPresentOnce
-- (one read per aura per engine step: several rules often watch the same aura, and the tracker's side effects should run once)
local NOREAD = {}   -- memo marker: the presence read was done and came back unknown (nil)
function ns.BuffPresent(id)
    local memo = id and ns.StepMemo and ns.StepMemo("buff")
    if not memo then
        local p, s, r = BuffPresentOnce(id)
        if id then RecordAura(id, p, s) end
        return p, s, r
    end
    -- #309: flat memos (presence, source, reference) instead of a new table per aura per step; NOREAD marks "unknown" (nil)
    local memoS, memoR = ns.StepMemo("buffS"), ns.StepMemo("buffR")
    local p = memo[id]
    if p == nil then
        local s, r
        p, s, r = BuffPresentOnce(id)
        memoS[id], memoR[id] = s, r
        if id then RecordAura(id, p, s) end
        memo[id] = (p == nil) and NOREAD or p
        return p, s, r
    end
    if p == NOREAD then p = nil end
    return p, memoS[id], memoR[id]
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
        -- learned only from a FRESH application (the aura just appeared after being seen absent): a refresh's total includes the
        -- carried-over time (pandemic), which made the next estimate too long (retrospective gap 6)
        local since = presentSince[id]
        if ref.duration and ref.duration > 0 and not ref.estimated and since and now - since >= 0 and now - since < 1.5 then
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
    if ns.Timing and id then exp, dur, label = ns.Timing.AuraEstimate(id, presentSince[id], ref.cdmFrame) end
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
        info.buffSource = tostring(info.buffSource) .. " | no time estimate yet"
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
-- Comparisons on the cooldown trigger itself (backlog B2, Xaya 2026-11-04): "Seconds left [op] [s]" and "Charges [op] [n]" in the
-- rule's Cooldown section and on "Cooldown (any spell)" rows. Same numbers as the Conditions tab rows (ns.NumRef "n:cdRemain" /
-- "n:cdCharges", Outcomes.lua): exact when the game shows them; in combat the time is the duration engine's estimate and the charge
-- count is built from your casts; nil (not known) keeps the answer unknown, never a guess. AND: a false comparison wins, then unknown.
ns.CMP_OPS = { values = { any = "Any", [">="] = "At least", ["<="] = "At most", ["="] = "Exactly", [">"] = "More than", ["<"] = "Less than" },
    order = { "any", ">=", "<=", "=", ">", "<" } }
local function Cmp(op, x, v)
    if op == ">=" then return x >= v elseif op == "<=" then return x <= v elseif op == "=" then return x == v
    elseif op == ">" then return x > v elseif op == "<" then return x < v end
    return true
end
local function OpOn(op) return op ~= nil and op ~= "" and op ~= "any" and ns.CMP_OPS.values[op] ~= nil end
function ns.CooldownNumChecks(rule, cdInfo)
    local tOn, cOn = OpOn(rule.cdTimeOp), OpOn(rule.cdChargeOp)
    if not tOn and not cOn then return true end
    local anyFalse, anyNil, why = false, false, nil
    if tOn then
        local rem = ns.NumRef and ns.NumRef("n:cdRemain", rule, { cd = cdInfo }) or nil
        if rem == nil then anyNil, why = true, "seconds left unknown"
        else
            local sec = tonumber(rule.cdTimeSec) or 0
            if rem > 0 and ns.Timing and ns.Timing.Deadline then   -- re-check at the moment the answer changes
                local now = GetTime()
                if rem > sec then ns.Timing.Deadline(now + (rem - sec)) end
                ns.Timing.Deadline(now + rem)
            end
            if not Cmp(rule.cdTimeOp, rem, sec) then anyFalse = true end
        end
    end
    if cOn then
        local n = (cdInfo and cdInfo.known) and cdInfo.count or nil
        if n == nil then anyNil, why = true, why or "charge count unknown"
        elseif not Cmp(rule.cdChargeOp, n, tonumber(rule.cdChargeVal) or 0) then anyFalse = true end
    end
    if anyFalse then return false end
    if anyNil then return nil, why end
    return true
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
    -- #2 (core 0.6.56; Xaya: three-click toggle Known / Not known / not set): an entry set to "none" (not set) has no bearing (#18); a
    -- saved entry without a state keeps reading as Known, as before
    local list = {}
    for _, t in ipairs(rule.talents or {}) do if type(t) == "table" and t.state ~= "none" then list[#list + 1] = t end end
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
    if not set then return false end   -- #309: no throwaway {} for a missing set (called for every load row of every rule)
    for k in pairs(set) do if k ~= "*" then return true end end
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

-- Load by zone, instance, difficulty, instance size, boss encounter and equipped item (Xaya 2026-11-04: "more load conditions we
-- should include if they're supported by the current api"). None of these calls or event values is marked secret in the 12.1.5 API
-- reference: GetInstanceInfo (docs/reference/api/globals.md:188), C_Map.GetBestMapForUnit / GetMapInfo (namespaces.md:3150 / 3166),
-- C_Item.IsEquippedItem (namespaces.md:2814), ENCOUNTER_START / ENCOUNTER_END (events.md:560-562). Each read is still pcall'd and
-- checked with issecret; a value the game will not give is unknown, and a rule that needs it does not load.
-- A zone matches the map you are on and every map it sits in (a city's room is in the city, the zone and the continent), so one
-- zone ID covers its sub-maps. The game has no call for the encounter in progress, so its ID comes from ENCOUNTER_START: after a
-- /reload in the middle of a pull it is unknown until the next pull.
local mapChains = {}
local function MapChain(id)
    local c = mapChains[id]
    if c then return c end
    c = { [id] = true }
    local cur = id
    for _ = 1, 16 do
        local ok, info = pcall(C_Map.GetMapInfo, cur)
        local p = ok and type(info) == "table" and info.parentMapID
        if type(p) ~= "number" or issecret(p) or p <= 0 or c[p] then break end
        c[p] = true; cur = p
    end
    mapChains[id] = c
    return c
end
local encNow, encLast, equipGen = nil, nil, 0
function ns.LastEncounter() return encLast end
function ns.LoadEvent(event, a1, a2)
    if event == "ENCOUNTER_START" then
        if type(a1) == "number" and not issecret(a1) then
            encNow = { id = a1, name = (type(a2) == "string" and not issecret(a2)) and a2 or nil }
            encLast = encNow
        else
            encNow = nil
        end
    elseif event == "ENCOUNTER_END" or event == "PLAYER_ENTERING_WORLD" then
        encNow = nil
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        equipGen = equipGen + 1
    end
    if ns.MarkStateDirty then ns.MarkStateDirty() end
end
if CreateFrame then
    local lf = CreateFrame("Frame")
    for _, e in ipairs({ "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED" }) do pcall(lf.RegisterEvent, lf, e) end
    if lf.SetScript then lf:SetScript("OnEvent", function(_, event, ...) ns.LoadEvent(event, ...) end) end
end
local function ReadPlace(ctx)
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and type(m) == "number" and not issecret(m) then
            ctx.mapID = m
            if C_Map.GetMapInfo then ctx.maps = MapChain(m) else ctx.maps = { [m] = true } end
        end
    end
    local ok, _, _, diff, _, size, _, _, instID = pcall(GetInstanceInfo)
    if ok then
        if type(diff) == "number" and not issecret(diff) then ctx.difficultyID = diff end
        if type(size) == "number" and not issecret(size) then ctx.instSize = size end
        if type(instID) == "number" and not issecret(instID) then ctx.instanceID = instID end
    end
    if encNow then ctx.encounterID = encNow.id
    elseif ctx.encounter == false then ctx.encounterID = 0 end   -- the game says no boss encounter is in progress
end
-- Where you are now, with the game's names, for the settings' "Add current" buttons. Any value the game will not give is nil.
function ns.LoadPlaceNow()
    local ctx = ns.ReadContext()
    local out = { mapID = ctx.mapID, instanceID = ctx.instanceID, difficultyID = ctx.difficultyID, size = ctx.instSize,
        encounterID = ctx.encounterID }
    if ctx.mapID and C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, ctx.mapID)
        if ok and type(info) == "table" and type(info.name) == "string" and not issecret(info.name) then out.mapName = info.name end
    end
    local ok, name, _, _, dname = pcall(GetInstanceInfo)
    if ok then
        if type(name) == "string" and not issecret(name) then out.instanceName = name end
        if type(dname) == "string" and not issecret(dname) and dname ~= "" then out.difficultyName = dname end
    end
    if encNow then out.encounterName = encNow.name end
    return out
end
-- An ID list ({ ["2552"] = true, ["2601"] = "not" }) against a set of current IDs (several for a zone and its parent maps, one for
-- the rest): no current ID marked "not", and when any IDs are ticked, one of them is current.
local function IdsMatch(set, current)
    local hasOn, hit = false, false
    for k, st in pairs(set) do
        local n = tonumber(k)
        if st == "not" and n and current[n] then return false end
        if st == true then hasOn = true; if n and current[n] then hit = true end end
    end
    return (not hasOn) or hit
end
-- IdsMatch for one current value, without building { [v] = true } on every check (#309: the engine session's allocation profile,
-- 2026-11-04, found the load checks making tables on every recheck)
local function IdsMatchOne(set, v)
    local hasOn, hit = false, false
    for k, st in pairs(set) do
        local n = tonumber(k)
        if st == "not" and n and n == v then return false end
        if st == true then hasOn = true; if n and n == v then hit = true end end
    end
    return (not hasOn) or hit
end
-- Every numeric item in the set is asked about (as before); an unknown answer makes the whole check unknown; a worn "not" item fails
-- it; otherwise one worn ticked item passes it (or there is none ticked). Same answers as building the worn set and calling IdsMatch,
-- without the table.
local function EquippedMatch(set)
    local fn = (C_Item and C_Item.IsEquippedItem) or IsEquippedItem
    if type(fn) ~= "function" then return nil end
    local hasOn, hit, blocked, unknown = false, false, false, false
    for k, st in pairs(set) do
        local n = tonumber(k)
        if n then
            local ok, v = pcall(fn, n)
            if not ok or v == nil or issecret(v) then unknown = true
            elseif v then
                if st == "not" then blocked = true elseif st == true then hit = true end
            end
        end
        if st == true then hasOn = true end
    end
    if unknown then return nil end
    if blocked then return false end
    return (not hasOn) or hit
end

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
    ReadPlace(ctx)
    -- every value a load check reads, in one string: equal strings = equal load answers (ns.CheckContext memo)
    local parts = {}
    for i, c in ipairs(ns.LOAD_TRI) do local v = ctx[c.key]; parts[i] = (v == nil) and "?" or (v and "1" or "0") end
    parts[#parts + 1] = tostring(ctx.instanceType); parts[#parts + 1] = tostring(ctx.specID)
    parts[#parts + 1] = tostring(ctx.role); parts[#parts + 1] = tostring(ctx.hero); parts[#parts + 1] = tostring(ctx.class)
    parts[#parts + 1] = tostring(ctx.mapID); parts[#parts + 1] = tostring(ctx.instanceID); parts[#parts + 1] = tostring(ctx.difficultyID)
    parts[#parts + 1] = tostring(ctx.instSize); parts[#parts + 1] = tostring(ctx.encounterID); parts[#parts + 1] = tostring(equipGen)
    ctx.sig = table.concat(parts, "|")
    return ctx
end

-- Load conditions. Every active (non-ignored) condition yields true / false / nil(unknown).
-- load.mode "any": at least one active condition must be true. Otherwise (blank / "all") every one must be.
-- Returns ok(bool), name of the failing condition(s).
local function known(v, result) if v == nil then return nil end return result end

-- The ID lists a load table can hold besides zones: saved key, context key, the name a failed check reports (made once, not per check)
local ID_LISTS = { { "instanceIDs", "instanceID", "instance ID" }, { "difficulties", "difficultyID", "difficulty" },
    { "sizes", "instSize", "instance size" }, { "encounterIDs", "encounterID", "encounter" } }
-- Walks the ID-list checks of a load table (a rule's `load`, or a group's `loadIds`), calling sink(acc, key, ok) for each
-- (ok = true / false / nil); stops and returns what sink returns as soon as that is not nil. Makes no tables.
local function IdListWalk(load, ctx, sink, acc)
    if type(load) ~= "table" then return nil end
    local r
    if ns.SetActive(load.mapIDs) then
        r = sink(acc, "zone", known(ctx.maps, ctx.maps and IdsMatch(load.mapIDs, ctx.maps)))
        if r ~= nil then return r end
    end
    for i = 1, #ID_LISTS do
        local d = ID_LISTS[i]
        local set, v = load[d[1]], ctx[d[2]]
        if ns.SetActive(set) then
            r = sink(acc, d[3], known(v, v ~= nil and IdsMatchOne(set, v)))
            if r ~= nil then return r end
        end
    end
    if ns.SetActive(load.equipped) then
        r = sink(acc, "item equipped", EquippedMatch(load.equipped))
        if r ~= nil then return r end
    end
    return nil
end
local function AppendCheck(checks, key, ok) checks[#checks + 1] = { key = key, ok = ok } end
-- the ID-list checks of a rule's load table, appended to `checks` as { key, ok = true / false / nil } (they join its other checks)
local function IdListChecks(load, ctx, checks) IdListWalk(load, ctx, AppendCheck, checks); return checks end
-- a group's lists: every one must match. Returns the first that does not (its name, and false or nil for unknown), or nil.
local failOk
local function FirstFail(_, key, ok) if ok ~= true then failOk = ok; return key end end
local function IdListFirstFail(load, ctx)
    local key = IdListWalk(load, ctx, FirstFail, nil)
    if key then return key, failOk end
end
-- (shared, never written) the load table of a rule that has none, so a recheck makes no new {} for it
local NO_LOAD = {}

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
-- #319 (Xaya, 2026-11-04): "Always load" ignores every load condition, unless the Class or Specialization row has its own tick box
-- "Always load: only this class / spec" ticked (rule: load.alwaysClass / load.alwaysSpec; group: f.alwaysClass / f.alwaysSpec). Then
-- that row still counts. Unticked (the default) = the old behaviour, so no existing rule changes.
local function AlwaysKeeps(classes, classOn, specs, specOn, ctx)
    if classOn and ns.SetActive(classes) and not (ctx.class ~= nil and ns.SetMatch(classes, ctx.class)) then
        return false, "class" .. (ctx.class == nil and " (unknown)" or "")
    end
    if specOn and ns.SetActive(specs) and not (ctx.specID ~= nil and ns.SetMatch(specs, tostring(ctx.specID))) then
        return false, "spec" .. (ctx.specID == nil and " (unknown)" or "")
    end
    return true
end
ns._AlwaysKeeps = AlwaysKeeps
function CheckContextRaw(rule, ctx)
    local load = rule.load or NO_LOAD
    local ov, ovFolder = ns.FolderLoadOverride(rule)   -- a folder's Never / Always beats the rule's own load mode
    if ov == "never" then return false, "load: never (folder " .. tostring(ovFolder and ovFolder.name) .. ")" end
    if ov == "always" then
        -- a group set to Always still applies the class / spec rows it marked "Always load: only this ..." (this group and its parents)
        local fid, guard = rule.folder, 0
        while fid and guard < 32 do
            local f = ns.FolderById(fid)
            if not f then break end
            local ok, why = AlwaysKeeps(f.loadClasses, f.alwaysClass, f.loadSpecs, f.alwaysSpec, ctx)
            if not ok then return false, "group " .. tostring(f.name) .. " (Always load, only this " .. why .. ")" end
            fid, guard = f.parent, guard + 1
        end
        return true
    end
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
            -- the group's own zone / instance / difficulty / size / encounter / item lists (core 0.6.33; every list must match)
            local fk, fok = IdListFirstFail(f.loadIds, ctx)
            if fk then return false, "group " .. tostring(f.name) .. ": " .. fk .. (fok == nil and " (unknown)" or "") end
            fid, guard = f.parent, guard + 1
        end
    end
    if load.mode == "never" then return false, "load: never" end
    if load.mode == "always" then
        local ok, why = AlwaysKeeps(load.classes, load.alwaysClass and load.classUse ~= false,
            load.specs, load.alwaysSpec and load.specUse ~= false, ctx)
        if not ok then return false, "Always load, only this " .. why end
        return true
    end
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
    -- ID lists (zone, instance, difficulty, size, encounter, equipped item); an empty or missing list restricts nothing
    IdListChecks(load, ctx, checks)
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
-- hundred rules no longer make a few hundred tables of garbage per step; outside a step (options, /xui debug status) it is new.
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

-- Load first (core 0.6.66, REQUEST-LOG A15 P-12): during an engine step a rule whose load conditions or talents fail is answered false
-- without reading its cooldown, auras or trigger rows (Xaya's profile: ~229 switched-on rules, 7 loaded; every step read all 229).
-- Load behaviour is unchanged: the answer was false before too (result needs ctxOK and talentOK). The one thing such a rule could
-- still show is a display set to "while the buff is active", on the rule or on one of its cues / conditions (Engine.lua DisplayWanted
-- reads info.present without the load check; cues and conditions copy the parent's info.present): for those rules the buff is still
-- read. Outside a step (the editor's trigger lights, /xui debug status, the outcomes editor) the full answer is computed as before.
local presenceRoots, presenceAt = {}, -1
local function NeedsPresence(rule)
    local ver = ns.configVersion or 0
    if presenceAt ~= ver then
        presenceRoots, presenceAt = {}, ver
        for _, r in ipairs(ns.rules or {}) do
            local v = r.visual
            if type(v) == "table" and v.trigger == "buffActive" then presenceRoots[r.parentUid or r] = true end
        end
    end
    return presenceRoots[rule] or (rule.uid ~= nil and presenceRoots[rule.uid]) or false
end
ns.NeedsPresence = NeedsPresence
function ns.Evaluate(rule, ctx)
    ctx = ctx or ns.ReadContext()
    local inStep = ns.InStep and ns.InStep()
    local c = ns.tickID and evalCache[rule]
    if c and c.tick == ns.tickID and c.ctx == ctx and not (c.info and c.info.skipped and not inStep) then return c.res, c.info end
    if rule.parentUid and ns.EvaluateOutcome then
        local res, oinfo = ns.EvaluateOutcome(rule, ctx)
        Remember(rule, ctx, res, oinfo)
        return res, oinfo
    end
    local info = ns.InfoFor(rule)
    info.ctx = ctx
    info.ctxOK, info.ctxFail = ns.CheckContext(rule, ctx)
    info.talentOK, info.talentDetail = ns.CheckTalents(rule)
    if inStep and not ns.statusDetail and (info.ctxOK ~= true or info.talentOK ~= true) then
        info.skipped = true   -- not loaded: no cooldown, aura or trigger-row read this step
        if NeedsPresence(rule) then
            info.present, info.buffSource, info.buffRef, info.buffWhich = ns.BuffPresentAny(rule)
            if info.buffRef == nil and type(rule.extra) == "table" then info.auraRef = ns.AuraRowRef(rule) end
        end
        info.trigOK, info.result = false, false
        Remember(rule, ctx, false, info)
        return false, info
    end
    info.cd = ns.ReadCooldown(rule)
    info.present, info.buffSource, info.buffRef, info.buffWhich = ns.BuffPresentAny(rule)
    if rule.buffEstimate ~= false and info.present == true then ns.ApplyBuffEstimate(rule, info) end
    info.cdOK = ns.CheckCooldownState(rule, info.cd)
    -- "Seconds left" / "Charges" comparisons of the Cooldown section (B2); AND with the state
    if (rule.cdTimeOp or rule.cdChargeOp) and (not ns.CooldownUsed or ns.CooldownUsed(rule)) then
        local v = ns.CooldownNumChecks(rule, info.cd)
        if v == false then info.cdOK = false elseif v == nil and info.cdOK == true then info.cdOK = nil end
    end
    info.buffOK = ns.CheckBuffState(rule, info.present)
    -- "with N seconds left" on the built-in Buff / Aura (only with State = present): unknown time keeps the trigger unknown
    if info.buffOK == true and rule.buffState == "present" and rule.buffTimeOp and rule.buffTimeOp ~= "any" then
        info.buffOK = ns.TimeLeftCheck(rule.buffTimeOp, rule.buffTimeSec, info.buffRef)
        if info.buffOK == nil and ns.statusDetail then info.buffSource = tostring(info.buffSource) .. " | seconds left unknown" end
    end
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
-- /xui debug probe <spellID> moved to XayaUI Dev Assist (core 0.6.56; Xaya 2026-11-06, REQUEST-LOG #81: "Move all of them"):
-- XayaUI_DevAssist/CoreDebug.lua. Without Dev Assist the command does not exist.
-------------------------------------------------------------------------------
-- Same detail as /xui debug status, but written to the ring-buffer log (ns.Log) instead of chat, so it can be read
-- from the settings window's debug console tray AFTER a fight without typing anything while in combat.
-- The periodic in-combat snapshot ("combat tick") logs only rules whose answer changed since the last snapshot, and reads the
-- engine's own latest results instead of evaluating every rule a second time; combat start / end log everything.
local snapLast = setmetatable({}, { __mode = "k" })
function ns.LogStatusSnapshot(tag)
    if not ns.rules or #ns.rules == 0 then return end
    -- built only while someone can read it (Core.lua ns.LogWanted; A15 P-9): no context read, no per-rule key strings otherwise
    if not (ns.LogWanted and ns.LogWanted("snapshot")) then return end
    local ctx = ns.ReadContext()
    local changesOnly = tag == "combat tick"
    ns.LogKind("snapshot", "-- status snapshot (%s) -- spec=%s role=%s combat=%s%s", tostring(tag or "?"),
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
                ns.LogKind("snapshot", "#%d %s result=%s | cd:%s(%s) buff:%s(%s via %s) ctx:%s talent:%s extra:%s",
                    i, r.name, tostring(res), tostring(r.cdState), tostring(info.cdOK),
                    tostring(r.buffState), tostring(info.buffOK), tostring(info.buffSource),
                    tostring(info.ctxOK), tostring(info.talentOK), tostring(info.extraOK))
            else
                ns.LogKind("snapshot", "#%d %s ERROR: %s", i, r.name, tostring(res))
            end
        end
    end
end

local PrintStatusRaw
function ns.PrintStatus()
    ns.statusDetail = true   -- readable time-source labels while /xui debug status runs (Timing.lua)
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
    ns.Print(("place: map=%s instanceID=%s difficulty=%s size=%s encounterID=%s"):format(tostring(ctx.mapID), tostring(ctx.instanceID),
        tostring(ctx.difficultyID), tostring(ctx.instSize), tostring(ctx.encounterID)))
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
local stacksT, stacksEp   -- (P2) kept in an upvalue; looked up again only when the settings epoch moves (Modules.lua section 0b)
local function Store()
    local t = stacksT
    if stacksEp ~= ns.settingsEpoch or type(t) ~= "table" then
        if not ns.SettingsReady() then return nil end
        t = CoreS.learnedAuraStacks
        if type(t) ~= "table" then t = {}; CoreS.learnedAuraStacks = t end
        stacksT, stacksEp = t, ns.settingsEpoch
    end
    return t
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
