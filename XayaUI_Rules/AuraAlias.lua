-- XayaUI: AuraAlias -- the same buff under another spell ID, learned in the player's own game.
--
-- WHY (Xaya, 2026-11-07, externals and raid defensives: "I turned EUI ones on because XUI isn't reliably performing"): a rule matches
-- an aura by its exact spell ID, in XayaUI's own reading (Conditions.lua) and in the game's aura container (Combat/AuraDisplay.lua,
-- includeSpellIDs compares the AURA's spell ID: Blizzard_AuraContainerUtil.lua). Several raid defensives are cast under one ID and put
-- a buff with another ID on you. In the 2026-11-01 game capture (docs/reference/spells) these have a second ID with the same name and
-- no cooldown: Anti-Magic Zone 51052 / 145629, Darkness 196718 / 209426, Power Word: Barrier 62618 / 81782, Rallying Cry
-- 97462 / 97463, Spirit Link Totem 98008 / 325174, Ancestral Vigor 207400 / 207401. Which of each pair is the buff is an INFERENCE,
-- so nothing is shipped: a rule that lists the cast ID would never match, in or out of combat, until the link is SEEN here.
--
-- WHAT IT DOES: while the game shows auras (out of combat), a helpful aura that appears on the player with a duration, whose name equals
-- the name of an aura ID one of your rules lists, but whose ID differs, is recorded as that ID's alias (CueRulesDB.auraAlias). Both
-- readers then count it: XayaUI's reading says "aura 81782 (same name as 62618, learned in game)", and the container's include list
-- gains the alias, so the display is drawn in combat too. Safety: the name must match exactly and the aura must be on the player;
-- auras with no duration (passives, talents) are never learned; an ID whose own aura is on you at the same moment, or was read as a
-- buff on you this session, is not aliased (two different buffs that share a name); several candidates are all kept (never one
-- picked), at most 4 per ID. The status note lists what was learned.
-- /xui debug status and the J25 walkthrough list what was learned. Built from Blizzard's API documentation only (UNIT_AURA
-- updateInfo.addedAuras, C_UnitAuras.GetAuraDataByIndex / GetUnitAuraBySpellID, C_Spell.GetSpellName).
--
-- COST: one event handler for the player's own UNIT_AURA. In combat it returns at once (the payload is secret there: events.md
-- UNIT_AURA SecretWhenAurasRestricted). With no rule listing an aura ID it returns at once too (V14). The name index of the rules'
-- aura IDs is built once when the rule list changes (another list, another length, or a settings edit: ns.configVersion, bumped by
-- ns.MarkDirty), never on a timer: V27 (Xaya, SD-28/29) "nothing loops over all rules on every game event". Each UNIT_AURA then
-- looks the added auras up by name in that index.
local _, ns = ...
ns = XayaUI_NS or ns

local issecret = issecretvalue or function() return false end
local pcall, type, pairs, ipairs, tonumber = pcall, type, pairs, ipairs, tonumber
local MAX_ALIASES = 4
local RETRY_TTL = 10   -- seconds: an aura ID whose spell name the game did not give yet is asked again at most this often

local CoreS = ns.Settings("core")   -- (core 0.6.75, P2 settings seam: the same CueRulesDB.auraAlias as before)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("core", "XayaUI_Rules", "XayaUIRulesDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)
local function Store()
    if not ns.SettingsReady("core") then return nil end
    local t = CoreS.auraAlias
    if type(t) ~= "table" then t = {}; CoreS.auraAlias = t end
    return t
end

-- [auraID] = { [aliasID] = true } or nil. Read on every aura read, so no table is made here, and the saved table is kept in an
-- upvalue, read again only when the settings epoch moves (Modules.lua section 0b: no metamethod per aura read).
local aliasT, aliasEp
function ns.AuraAliasesOf(id)
    if aliasEp ~= ns.settingsEpoch then aliasT, aliasEp = CoreS.auraAlias, ns.settingsEpoch end
    local t = aliasT
    if type(t) ~= "table" then return nil end
    local a = t[id]
    if type(a) == "table" and next(a) then return a end
    return nil
end

-- name -> { auraID, ... } for every aura ID a rule lists (built-in Buff / Aura, its extra IDs, "Buff / Aura (another)" rows)
local nameIndex, indexN = {}, 0
local iList, iLen, iVer = nil, -1, -1    -- the rule list, its length and ns.configVersion the index was built from
local missing, missingN, retryAt = {}, 0, 0   -- aura IDs whose name was not readable at the build (asked again, only those)
local function SpellName(id)
    if not (C_Spell and C_Spell.GetSpellName) then return nil end
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and type(n) == "string" and not issecret(n) and n ~= "" then return n end
end
local function AddID(idx, seen, id)
    id = tonumber(id)
    if not id or id <= 0 or seen[id] then return end
    seen[id] = true
    local n = SpellName(id)
    if not n then missingN = missingN + 1; missing[missingN] = id; return end
    local l = idx[n]
    if not l then l = {}; idx[n] = l end
    l[#l + 1] = id
    indexN = indexN + 1
end
local function BuildIndex(rules)
    local idx, seen = {}, {}
    indexN, missing, missingN = 0, {}, 0
    for _, r in ipairs(rules) do
        if type(r) == "table" and r.enabled ~= false then
            if r.useBuff ~= false then
                AddID(idx, seen, r.buffID)
                if type(r.buffAlt) == "table" then for _, a in ipairs(r.buffAlt) do AddID(idx, seen, a) end end
            end
            local list = type(r.extra) == "table" and type(r.extra.list) == "table" and r.extra.list or nil
            if list then
                for _, t in ipairs(list) do
                    if type(t) == "table" and t.type == "buffAura" then
                        AddID(idx, seen, t.spellID)
                        if type(t.alt) == "table" then for _, a in ipairs(t.alt) do AddID(idx, seen, a) end end
                    end
                end
            end
        end
    end
    return idx
end
-- the IDs whose name was missing are asked again (only those, at most every RETRY_TTL seconds); a name found joins the index
local function RetryMissing()
    local now = GetTime and GetTime() or 0
    if now >= retryAt and now - retryAt < RETRY_TTL then return end
    retryAt = now
    local keep = 0
    for i = 1, missingN do
        local id = missing[i]
        missing[i] = nil
        local n = SpellName(id)
        if n then
            local l = nameIndex[n]
            if not l then l = {}; nameIndex[n] = l end
            l[#l + 1] = id
            indexN = indexN + 1
        else
            keep = keep + 1; missing[keep] = id
        end
    end
    missingN = keep
end
local function Index()
    local rules = ns.rules
    if type(rules) ~= "table" then nameIndex, indexN, missingN = {}, 0, 0; iList = nil; return nameIndex end
    if rules ~= iList or #rules ~= iLen or (ns.configVersion or 0) ~= iVer then
        nameIndex = BuildIndex(rules)
        iList, iLen, iVer = rules, #rules, ns.configVersion or 0
        retryAt = GetTime and GetTime() or 0
    elseif missingN > 0 then
        RetryMissing()
    end
    return nameIndex
end
function ns.AuraAliasForget() iList = nil end   -- (tests: build the index again on the next aura event)

local function Field(t, k) return t[k] end
local function Clean(a, k, want)
    local ok, v = pcall(Field, a, k)
    if ok and not issecret(v) and type(v) == want then return v end
end
local function OwnAuraUp(id)
    local fn = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
    if not fn then return false end
    local ok, a = pcall(fn, "player", id)
    return ok and a ~= nil and not issecret(a)
end

-- One readable aura on the player: learn it if it is a rule aura's namesake. Returns true when something new was recorded.
local function Consider(a, idx)
    if type(a) ~= "table" or issecret(a) then return false end
    local sid, name = Clean(a, "spellId", "number"), Clean(a, "name", "string")
    if not (sid and name) then return false end
    local list = idx[name]
    if not list then return false end
    local helpful = Clean(a, "isHelpful", "boolean")
    if helpful == false then return false end
    local dur = Clean(a, "duration", "number")
    if not (dur and dur > 0) then return false end   -- passives / talents have no duration: never learned
    local store, changed = nil, false
    for _, id in ipairs(list) do
        -- never: the rule's own ID is a buff on you right now, or was read as one this session (then it needs no alias, and this
        -- namesake is a different buff that shares the name; hub F2 guard)
        if id ~= sid and not OwnAuraUp(id) and not (ns.AuraSeenReadable and ns.AuraSeenReadable(id)) then
            store = store or Store()
            if not store then return false end
            local al = store[id]
            if type(al) ~= "table" then al = {}; store[id] = al end
            if not al[sid] then
                local n = 0
                for _ in pairs(al) do n = n + 1 end
                if n < MAX_ALIASES then
                    al[sid] = true
                    changed = true
                    if ns.Log then pcall(ns.Log, ("aura alias learned: %d (%s) counts for rule aura %d"):format(sid, name, id)) end
                end
            end
        end
    end
    return changed
end

local function Restricted()
    if not ns.AurasRestricted then return true end
    local ok, r = pcall(ns.AurasRestricted)
    return not ok or r and true or false
end

local function ScanAll(idx)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return false end
    local changed = false
    for i = 1, 40 do
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or a == nil or issecret(a) then break end
        if Consider(a, idx) then changed = true end
    end
    return changed
end

local function OnAura(updateInfo)
    if Restricted() then return end                 -- combat: the payload is secret (UNIT_AURA SecretWhenAurasRestricted)
    local idx = Index()
    if indexN == 0 then return end                  -- no rule lists an aura ID: nothing to learn (V14)
    local changed = false
    if type(updateInfo) ~= "table" or issecret(updateInfo) or updateInfo.isFullUpdate == true then
        changed = ScanAll(idx)
    else
        local added = updateInfo.addedAuras
        if type(added) == "table" and not issecret(added) then
            for _, a in ipairs(added) do if Consider(a, idx) then changed = true end end
        end
    end
    if changed and ns.AuraDisplay and ns.AuraDisplay.QueueBuild then pcall(ns.AuraDisplay.QueueBuild) end   -- the container's include list
    -- (round 6, SD-54) the engine's aura checks index the rules' aura IDs by spell ID: the alias joins that index, and the checks are read
    if changed and ns.EngineAliasLearned then pcall(ns.EngineAliasLearned) end
end
ns._AuraAliasOnAura = OnAura   -- (tests)

if CreateFrame then
    local f = CreateFrame("Frame")
    if f.RegisterUnitEvent then f:RegisterUnitEvent("UNIT_AURA", "player") else f:RegisterEvent("UNIT_AURA") end
    f:SetScript("OnEvent", function(_, _, unit, updateInfo)
        if unit ~= "player" then return end
        pcall(OnAura, updateInfo)
    end)
end
