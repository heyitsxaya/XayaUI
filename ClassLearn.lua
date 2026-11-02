-------------------------------------------------------------------------------
-- ClassLearn.lua : per-spec cooldown lists learned from YOUR game client (core module, 0.5.78).
-- Replaces the shipped class data table. Nothing here is copied from anywhere: while you play a spec, this reads that spec's spellbook and
-- talent list through the game's own calls (ns.CollectCooldownSpells) and remembers it in CueRulesDB.classLearn, one entry per spec, dropped
-- when the game build changes. "Auto-populate" then works for every spec you have played once. Every entry is a cooldown ("cd"); buffs and
-- target debuffs are not guessed, so there are none, and every role is "Unsorted" (the optional SPEC_SORT folders in Options.lua still apply).
-- Midnight: all game reads are pcall'd and secret values skipped; learning is skipped in combat and re-tried afterwards.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local CL = {}
ns.ClassLearn = CL

local isSecret = issecretvalue or function() return false end

local function DB()
    local root = _G.CueRulesDB
    if type(root) ~= "table" then return nil end
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
