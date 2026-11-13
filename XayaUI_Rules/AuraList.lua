-------------------------------------------------------------------------------
-- AuraList.lua : the Cooldown Manager catalogue for the current spec (ns.AuraCatalogue), read by Triggers.lua (ns.CdmNeeds: can an
-- aura be followed in combat) and by the debug tools' /xui debug auras.
--
-- Round 7 (bundle 1; REQUEST-LOG A23 SD-58, her answer on the debug tools: "1 but nothing loads unless "Debugging" is enabled"): the
-- command part, /xui debug auras and its /xui auras shortcut (with the three facts for one spell, ns.AuraFacts), moved to the debug tools'
-- load-on-demand addon (XayaUI_Debug/RulesAuras.lua), read only while Settings > Debugging > Advanced Debugging is on. With it off, core
-- answers both words with one plain line (XayaUI/Core.lua, ns.DebugToolsNeeded). The catalogue stays here.
-- Cooldown Manager catalogue: C_CooldownViewer.GetCooldownViewerCategorySet(category, true) + GetCooldownViewerCooldownInfo, matching
-- spellID / overrideSpellID / overrideTooltipSpellID / linkedSpellIDs. Every value is checked with issecretvalue; nothing secret is kept.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local issecret = issecretvalue or function() return false end

local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    local r = { pcall(fn, ...) }
    if not r[1] then return false end
    for i = 2, #r do if issecret(r[i]) then return false end end
    return true, unpack(r, 2)
end

-------------------------------------------------------------------------------
-- Cooldown Manager catalogue for the current spec: spellID -> list of category names (built on demand, cached until spec change)
-------------------------------------------------------------------------------
local CATEGORY_NAMES = { [0] = "Essential", [1] = "Utility", [2] = "Tracked Buffs", [3] = "Tracked Bars", [-1] = "hidden (active)", [-2] = "hidden (passive)" }
local catalogue, catalogueSpec

local function CurrentSpec()
    local fn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local ok, s = Call(fn)
    return ok and s or nil
end

local function BuildCatalogue()
    local cat = {}
    local CV = C_CooldownViewer
    if not (CV and CV.GetCooldownViewerCategorySet and CV.GetCooldownViewerCooldownInfo) then return cat, false end
    local cats = (Enum and Enum.CooldownViewerCategory) or { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 }
    local function add(id, name)
        if type(id) == "number" and not issecret(id) and id > 0 then
            cat[id] = cat[id] or {}
            for _, n in ipairs(cat[id]) do if n == name then return end end
            cat[id][#cat[id] + 1] = name
        end
    end
    for _, value in pairs(cats) do
        if type(value) == "number" then
            local ok, ids = Call(CV.GetCooldownViewerCategorySet, value, true)
            if ok and type(ids) == "table" then
                local name = CATEGORY_NAMES[value] or ("category " .. value)
                for _, cid in ipairs(ids) do
                    local okI, info = Call(CV.GetCooldownViewerCooldownInfo, cid)
                    if okI and type(info) == "table" then
                        add(info.spellID, name); add(info.overrideSpellID, name); add(info.overrideTooltipSpellID, name)
                        if type(info.linkedSpellIDs) == "table" then for _, l in ipairs(info.linkedSpellIDs) do add(l, name) end end
                    end
                end
            end
        end
    end
    return cat, true
end

function ns.AuraCatalogue()
    local spec = CurrentSpec()
    if not catalogue or catalogueSpec ~= spec then catalogue, catalogueSpec = BuildCatalogue(), spec end
    return catalogue
end
function ns.ClearAuraCatalogue() catalogue = nil end

-- the catalogue follows spec and talent changes
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED", "COOLDOWN_VIEWER_DATA_LOADED", "PLAYER_ENTERING_WORLD" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() catalogue = nil end)
