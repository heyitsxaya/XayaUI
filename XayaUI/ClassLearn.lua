-------------------------------------------------------------------------------
-- ClassLearn.lua : per-spec cooldown lists learned from YOUR game client (core module, 0.5.78).
-- Replaces the shipped class data table. Nothing here is copied from anywhere: while you play a spec, this reads that spec's spellbook and
-- talent list through the game's own calls (ns.CollectCooldownSpells) and remembers it in CueRulesDB.classLearn, one entry per spec, dropped
-- when the game build changes. "Auto-populate" then works for every spec you have played once. Entries are cooldowns ("cd") and, since core
-- 0.6.56 (C1), the auras ("aura") and target debuffs ("debuff") that spec's Cooldown Manager offers (read, never guessed); every role is
-- "Unsorted" (the optional SPEC_SORT folders in Options.lua still apply).
-- Midnight: all game reads are pcall'd and secret values skipped; learning is skipped in combat and re-tried afterwards.
-------------------------------------------------------------------------------
local _, ns = ...
local CoreS = ns.Settings("core")   -- (core 0.6.75, P2 settings seam: the same CueRulesDB keys as before)
ns = _G.XayaUI_NS or ns
local CL = {}
ns.ClassLearn = CL

local isSecret = issecretvalue or function() return false end

local function DB()
    if not ns.SettingsReady() then return nil end
    local root = CoreS
    local okB, _, bn = pcall(GetBuildInfo)
    local build = okB and bn or "?"
    local d = root.classLearn
    if type(d) ~= "table" or d.build ~= build or type(d.specs) ~= "table" then
        d = { build = build, specs = {} }
        root.classLearn = d
    end
    return d
end

local function HasCharges(id)
    local ok, ci = pcall(C_Spell.GetSpellCharges, id)
    if not ok or type(ci) ~= "table" or isSecret(ci) then return nil end
    local mx = ci.maxCharges
    if type(mx) == "number" and not isSecret(mx) and mx > 1 then return true end
end

-- Auras on you and target debuffs, from the Cooldown Manager's catalogue for the spec you are in now (C1, core 0.6.56; Xaya 2026-11-06:
-- "Build it"; moved here from XayaUI_Options/AutoPicker.lua so the learner and the auto-populate table share one reader).
-- C_CooldownViewer.GetCooldownViewerCategorySet(category, true) and GetCooldownViewerCooldownInfo (docs/reference/api/namespaces.md:1370-1371,
-- structures.md:1798). An entry with hasAura = true is an aura: selfAura = true on you, selfAura = false on your target (INFERENCE: the
-- documentation lists these fields without describing them). Its aura ID is its first linkedSpellIDs entry (else its spellID).
-- Returns { aura = { {id, cdmID, name}, ... }, debuff = { ... } }; secret or missing values are skipped.
local function SpellName(id)
    if not (C_Spell and C_Spell.GetSpellName) then return nil end
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and type(n) == "string" and not isSecret(n) and n ~= "" then return n end
end
function ns.CdmAuraCatalogue()
    local out, seen = { aura = {}, debuff = {} }, { aura = {}, debuff = {} }
    local CV = C_CooldownViewer
    if not (CV and CV.GetCooldownViewerCategorySet and CV.GetCooldownViewerCooldownInfo) then return out end
    local cats = (Enum and Enum.CooldownViewerCategory) or { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 }
    local values = {}
    for _, v in pairs(cats) do if type(v) == "number" then values[#values + 1] = v end end
    table.sort(values)
    for _, cat in ipairs(values) do
        local ok, ids = pcall(CV.GetCooldownViewerCategorySet, cat, true)
        if ok and type(ids) == "table" and not isSecret(ids) then
            for _, cid in ipairs(ids) do
                local okI, info = pcall(CV.GetCooldownViewerCooldownInfo, cid)
                local kind = okI and type(info) == "table" and info.hasAura == true
                    and ((info.selfAura == true and "aura") or (info.selfAura == false and "debuff")) or nil
                if kind then
                    local sp = (info.spellID ~= nil and not isSecret(info.spellID)) and tonumber(info.spellID) or nil
                    local linked = type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs[1]
                    local aura = (linked ~= nil and linked ~= false and not isSecret(linked) and tonumber(linked)) or sp
                    if aura and aura > 0 and not seen[kind][aura] then
                        seen[kind][aura] = true
                        local list = out[kind]
                        list[#list + 1] = { id = aura, cdmID = (sp and sp ~= aura) and sp or nil, name = SpellName(aura) or (sp and SpellName(sp)) }
                    end
                end
            end
        end
    end
    return out
end

-- Read the active spec now. Returns specID or nil, reason.
function CL.Learn()
    local d = DB()
    if not d then return nil, "no saved data yet" end
    if InCombatLockdown and InCombatLockdown() then return nil, "in combat" end
    local specID = ns.CurrentSpecID and ns.CurrentSpecID()
    if not specID or not ns.CollectCooldownSpells then return nil, "no active spec" end
    local ok, list = pcall(ns.CollectCooldownSpells, 0, true)
    if not ok or type(list) ~= "table" or #list == 0 then return nil, "nothing readable" end
    local entries = {}
    for _, sp in ipairs(list) do
        if type(sp.id) == "number" and type(sp.name) == "string" then
            entries[#entries + 1] = { id = sp.id, name = sp.name, kind = "cd", role = "Unsorted", talent = sp.talent or nil, charges = HasCharges(sp.id) }
        end
    end
    -- C1: this spec's auras on you and target debuffs from the Cooldown Manager, so another spec's list can show them later
    local okC, cat = pcall(ns.CdmAuraCatalogue)
    if okC and type(cat) == "table" then
        for _, kind in ipairs({ "aura", "debuff" }) do
            for _, a in ipairs(cat[kind] or {}) do
                if a.name then entries[#entries + 1] = { id = a.id, cdmID = a.cdmID, name = a.name, kind = kind, role = "Unsorted" } end
            end
        end
    end
    local okS, _, specName = pcall(GetSpecializationInfoByID, specID)
    local className, token = UnitClass("player")
    d.specs[specID] = { class = className, classToken = token, spec = okS and specName or nil, entries = entries, learned = (date and date("%Y-%m-%d")) or nil }
    ns.CLASS_AURA_DATA = d.specs
    return specID
end

-- Make the learned table the one the rest of the addon reads.
function CL.Bind()
    local d = DB()
    ns.CLASS_AURA_DATA = d and d.specs or {}
end

local pending
local function Later()
    if pending then return end
    pending = true
    C_Timer.After(3, function() pending = false; pcall(CL.Learn) end)   -- debounce: talent changes fire several events
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, ev, unit)
    if ev == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
    if ev == "PLAYER_ENTERING_WORLD" then CL.Bind() end
    local d = DB()
    if ev == "PLAYER_REGEN_ENABLED" then
        local sid = ns.CurrentSpecID and ns.CurrentSpecID()
        if d and sid and d.specs[sid] then return end   -- only a spec never learned needs the retry
    end
    Later()
end)
