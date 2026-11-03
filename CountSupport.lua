local addonName, ns = ...

-- What can the "Stacks / Charges Count" text show for this rule? It follows what the rule's triggers track:
--   * a Cooldown trigger counts CHARGES, only when the spell really has more than one (the game's own maxCharges, or the rule's override);
--   * a Buff / Aura trigger counts STACKS, unless this client has watched that aura and it never stacked;
--   * a trigger that tracks neither (item count, totem, range, player state ...) has nothing to count.
-- If no trigger can count anything, the count section is hidden (hiding never changes saved values; a section that is already
-- switched on stays visible).
--
-- How an aura is known not to stack: whenever the aura reader finds one of your auras, ns.LearnStacks records the highest
-- readable "applications" value and how many separate applications (auraInstanceIDs) were seen, in CueRulesDB.learnedAuraStacks.
-- An aura counts as non-stacking only after at least MIN_SEEN separate applications were seen and none ever showed more than 1.
-- The game has no call that returns an aura's maximum stacks, so this is an observation, not a lookup. An aura that has not
-- been seen yet is treated as "may stack", never as "cannot", so a real stacking aura is not hidden by a guess.

local MIN_SEEN = 2
local issecret = issecretvalue or function() return false end

local function Store()
    if type(CueRulesDB) ~= "table" then return nil end
    if type(CueRulesDB.learnedAuraStacks) ~= "table" then CueRulesDB.learnedAuraStacks = {} end
    return CueRulesDB.learnedAuraStacks
end

local lastIid = {}   -- spellID -> auraInstanceID last counted (session only)

-- Called by the aura reader with the spell ID it asked for and the aura table it got back.
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
    if apps > (e.max or 0) then e.max = apps end
    if iid == nil then
        if (e.seen or 0) == 0 then e.seen = 1 end
    elseif lastIid[id] ~= iid then
        lastIid[id] = iid
        e.seen = (e.seen or 0) + 1
    end
end

local descCache = {}
local function DescribesStacks(id)
    local v = descCache[id]
    if v ~= nil then return v end
    v = false
    if C_Spell and C_Spell.GetSpellDescription then
        local ok, d = pcall(C_Spell.GetSpellDescription, id)
        if ok and type(d) == "string" and not issecret(d) and d:lower():find("stack", 1, true) then v = true end
    end
    descCache[id] = v
    return v
end

-- true = may stack (or not known yet), false = watched and never stacked
function ns.AuraMayStack(id)
    id = tonumber(id) or 0
    if id == 0 then return false end
    local db = Store()
    local e = db and db[id]
    if type(e) == "table" and (e.max or 0) > 1 then return true end
    if DescribesStacks(id) then return true end
    if type(e) == "table" and (e.seen or 0) >= MIN_SEEN then return false end
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

-- returns { charges = bool, stacks = bool, any = bool }
function ns.CountSupport(rule)
    local r = rule
    if rule and rule.parentUid and ns.FindParentRule then r = ns.FindParentRule(rule) or rule end   -- cues and conditions follow their rule's triggers
    local out = { charges = false, stacks = false }
    if type(r) ~= "table" then out.any = true; return out end
    if ns.CooldownUsed(r) and ns.SpellHasCharges(r.spellID, r.maxCharges) then out.charges = true end
    if ns.BuffUsed(r) then
        if ns.AuraMayStack(r.buffID) then out.stacks = true end
        if type(r.buffAlt) == "table" then
            for _, id in ipairs(r.buffAlt) do if ns.AuraMayStack(id) then out.stacks = true end end
        end
    end
    local list = type(r.extra) == "table" and type(r.extra.list) == "table" and r.extra.list or {}
    for _, t in ipairs(list) do
        if type(t) == "table" then
            if t.type == "buffAura" or t.type == "targetDebuff" then
                if ns.AuraMayStack(t.spellID) then out.stacks = true end
            elseif t.type == "cooldown" then
                if ns.SpellHasCharges(t.spellID, t.maxCharges) then out.charges = true end
            end
        end
    end
    out.any = out.charges or out.stacks
    return out
end
