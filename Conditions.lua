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

-- Clean boolean field from a table, or nil if missing/secret.
local function CleanBool(t, key)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(function() return t[key] end)
    if not ok or v == nil or issecret(v) then return nil end
    return v and true or false
end

local function CleanNumber(t, key)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(function() return t[key] end)
    if not ok or v == nil or issecret(v) then return nil end
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
function ns.ReadCooldown(rule)
    local id = rule.spellID
    local r = { known = false, max = 1 }
    if not id or id == 0 then r.why = "no spell"; return r end

    local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
    if not ok or type(cd) ~= "table" then r.why = "cooldown unreadable"; return r end
    local cdActive = CleanBool(cd, "isActive")
    local onGCD = CleanBool(cd, "isOnGCD")
    if cdActive == nil then r.why = "cooldown.isActive secret/nil"; return r end
    r.onCd = cdActive and not onGCD

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

local function FrameMatches(frame, id)
    local function eq(v) return v ~= nil and not issecret(v) and v == id end
    local ok, sid = pcall(function() return frame.GetSpellID and frame:GetSpellID() end)
    if ok and eq(sid) then return true end
    local info = frame.cooldownInfo
    if type(info) == "table" then
        if eq(info.spellID) or eq(info.overrideSpellID) or eq(info.overrideTooltipSpellID) then
            return true
        end
        if type(info.linkedSpellIDs) == "table" then
            for _, l in ipairs(info.linkedSpellIDs) do if eq(l) then return true end end
        end
    end
    return false
end

local function FindCDMFrame(id)
    for _, vname in ipairs(VIEWERS) do
        local v = _G[vname]
        if v and v.GetChildren then
            local kids = { v:GetChildren() }
            for i = 1, #kids do
                local fr = kids[i]
                if fr and FrameMatches(fr, id) then return fr, vname end
            end
        end
    end
end

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

-- Reference to a live aura for duration text. Numbers are only kept when readable.
local function CleanNum(t, k)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(function() return t[k] end)
    if ok and type(v) == "number" and not issecret(v) then return v end
end
local function MakeRef(aura, frame)
    local ref = {}
    if type(aura) == "table" then
        local ok, iid = pcall(function() return aura.auraInstanceID end)
        if ok then ref.instanceID = iid end
        local oka, apps = pcall(function() return aura.applications end)
        if oka then ref.applications = apps end   -- may be secret; only ever passed to SetText
        ref.expiration, ref.duration = CleanNum(aura, "expirationTime"), CleanNum(aura, "duration")
        if not (ref.expiration and ref.duration) then ref.expiration, ref.duration = nil, nil end
    elseif frame then
        local ok, iid = pcall(function() return frame.auraInstanceID end)
        if ok then ref.instanceID = iid end
    end
    return ref
end
function ns.BuffPresent(id)
    if not id or id == 0 then return nil, "no buff" end
    -- A real aura table proves presence, in any context.
    local api, aura = ReadAuraAPI(id)
    if api == "found" then return true, "aura API", MakeRef(aura) end
    -- Cooldown Manager frame: authoritative when the buff is tracked there.
    local fr, vname = FindCDMFrame(id)
    if fr then
        local active = (fr.wasSetFromAura == true) or (fr.auraInstanceID ~= nil)
        return active and true or false, "CDM frame (" .. vname .. ")", active and MakeRef(nil, fr) or nil
    end
    -- No proof of presence. "nil" only means MISSING if the read can be trusted.
    if api == "nil" then
        if not AurasRestricted() then return false, "aura API (unrestricted)" end
        if AuraTrackable(id) then return false, "aura API (NeverSecret spell)" end
        return nil, "unknown: restricted + spell not readable + not in CDM"
    end
    return nil, "unreadable (" .. api .. ")"
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
      read = function() return IsEncounterInProgress() end },
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

function ns.ReadContext()
    local ctx = {}
    for _, c in ipairs(ns.LOAD_TRI) do
        local ok, v = pcall(c.read)
        if ok and v ~= nil and not issecret(v) then ctx[c.key] = v and true or false end
    end
    local okI, _, itype = pcall(IsInInstance)
    if okI and not issecret(itype) then ctx.instanceType = itype end
    local ok, id, role = pcall(CurrentSpec)
    if ok then
        if not issecret(id) then ctx.specID = id end
        if not issecret(role) then ctx.role = role end
    end
    return ctx
end

-- Load conditions. Every active (non-ignored) condition yields true / false / nil(unknown).
-- load.mode "any": at least one active condition must be true. Otherwise (blank / "all") every one must be.
-- Returns ok(bool), name of the failing condition(s).
local function known(v, result) if v == nil then return nil end return result end

function ns.CheckContext(rule, ctx)
    local load = rule.load or {}
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
        checks[#checks + 1] = { key = "instance type", ok = known(ctx.instanceType, load.instanceTypes[ctx.instanceType] and true or false) }
    end
    if (load.specID or 0) > 0 then
        checks[#checks + 1] = { key = "spec", ok = known(ctx.specID, ctx.specID == load.specID) }
    end
    if not ns.Ignored(load.role) then
        checks[#checks + 1] = { key = "role", ok = known(ctx.role, ctx.role == load.role) }
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
function ns.Evaluate(rule, ctx)
    ctx = ctx or ns.ReadContext()
    local info = { ctx = ctx }
    info.cd = ns.ReadCooldown(rule)
    info.present, info.buffSource, info.buffRef = ns.BuffPresent(rule.buffID)
    info.cdOK = ns.CheckCooldownState(rule, info.cd)
    info.buffOK = ns.CheckBuffState(rule, info.present)
    info.ctxOK, info.ctxFail = ns.CheckContext(rule, ctx)
    info.talentOK, info.talentDetail = ns.CheckTalents(rule)
    -- the three core dropdowns must be chosen ("none" counts as a choice)
    info.missing = {}
    local function unset(v) return v == nil or v == "" end
    if unset(rule.cdState) then info.missing[#info.missing + 1] = "cooldown state" end
    if unset(rule.buffState) then info.missing[#info.missing + 1] = "buff state" end
    if unset(rule.talentMode) then info.missing[#info.missing + 1] = "talent condition" end
    info.result = (info.cdOK == true) and (info.buffOK == true) and info.ctxOK
        and (info.talentOK == true) and (#info.missing == 0)
    return info.result, info
end

-- "Loaded" = enabled, load conditions pass and talent requirement passes (cooldown / buff state are NOT part of it).
function ns.IsLoaded(rule, ctx)
    if not rule.enabled then return false end
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

function ns.PrintStatus()
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
            r.cdState, tostring(info.cdOK), r.buffState, tostring(info.buffOK),
            info.buffSource or "?", tostring(info.ctxOK), tostring(info.talentOK),
            tostring(info.talentDetail)))
        ns.Print("    cooldown: " .. (info.cd.why or "?"))
    end
end
