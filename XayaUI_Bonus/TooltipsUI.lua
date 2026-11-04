-- TooltipsUI.lua : options group for the Tooltip Modifiers (AceConfig table), plus /xuitt.
local addonName, ns = ...
ns = _G.XayaUI_NS or ns
local TT = ns.TT

-- Returns an AceConfig group; registered as a Bonus Features page (ns.RegisterSettingsPage, Modules.lua).
function ns.BuildTooltipsTab(Notify)
    local function get(path)
        return function() local t = TT.DB(); for _, k in ipairs(path) do t = t[k] end; return t end
    end
    local function set(path)
        return function(_, v)
            local t = TT.DB(); for i = 1, #path - 1 do t = t[path[i]] end
            t[path[#path]] = v
            if Notify then Notify() end
        end
    end
    local function toggle(order, name, desc, path, disabled)
        return { type = "toggle", order = order, name = name, desc = desc, width = "full",
                 get = get(path), set = set(path), disabled = disabled }
    end
    local idsOff = function() return not TT.DB().ids.enabled end
    local ids = {
        enabled = toggle(1, "Show IDs on tooltips", "Master switch for the ID lines below.", { "ids", "enabled" }),
        npc = toggle(2, "NPC IDs", "Read from the unit's GUID. Skipped when the game hides the GUID.", { "ids", "npc" }, idsOff),
        auraHint = toggle(4, "Say \"not known yet\" when a spell's aura is not known", "Under a spell that lasts for some seconds. The aura's name and ID appear after you cast the spell once out of combat, or hover it while the aura is on you.", { "ids", "auraHint" }, idsOff),
        icon = toggle(3, "Icon IDs (under spell, aura and item lines)", nil, { "ids", "icon" }, idsOff),
    }
    for i, kind in ipairs(TT.ID_KINDS) do
        ids[kind.key] = toggle(10 + i, kind.name, nil, { "ids", kind.key }, idsOff)
    end
    return {
        type = "group", name = "Tooltips", order = 2, childGroups = "tab",
        args = {
            ids = { type = "group", name = "IDs", order = 1, args = ids },
            ilvl = { type = "group", name = "Item level", order = 2, args = {
                enabled = toggle(1, "Show player item level on hover", "Yourself: equipped average. Others: via Inspect, cached.", { "ilvl", "enabled" }),
                inspect = toggle(2, "Inspect other players", "Sends one inspect request at a time. Not in combat.", { "ilvl", "inspect" },
                    function() return not TT.DB().ilvl.enabled end),
                cacheSecs = { type = "range", order = 3, name = "Cache seconds", min = 30, max = 600, step = 10, width = "full",
                    get = get({ "ilvl", "cacheSecs" }), set = set({ "ilvl", "cacheSecs" }),
                    disabled = function() return not TT.DB().ilvl.enabled end },
            } },
            forces = { type = "group", name = "Enemy forces", order = 3, args = {
                enabled = toggle(1, "Show count and % on hostile units", "Read live from the game; shown only when the game returns it.", { "forces", "enabled" }),
                onlyInDungeon = toggle(2, "Only inside dungeons and raids", nil, { "forces", "onlyInDungeon" },
                    function() return not TT.DB().forces.enabled end),
                onlyMythicPlus = toggle(3, "Only in an active Mythic+ run", nil, { "forces", "onlyMythicPlus" },
                    function() return not TT.DB().forces.enabled end),
                note = { type = "description", order = 9, name = "Crowd control, true sight and casts are not included: they need an enemy database that does not exist yet." },
            } },
            formulas = { type = "group", name = "Formulas", order = 4, args = {
                enabled = toggle(1, "Show formula lines on spell tooltips", "Out of combat only: the game hides stats and cooldown details in combat.", { "formulas", "enabled" }),
                cooldown = toggle(2, "Cooldown and recharge", "The game's cooldown or recharge time divided by its rate (haste, when the rate matches your haste), checked against the time the tooltip prints. A spell that is not on cooldown shows only its base time: the game reports the rate only while it runs.", { "formulas", "cooldown" },
                    function() return not TT.DB().formulas.enabled end),
                damage = toggle(3, "Damage ratio", "Each damage number in the spell's text divided by your attack power (strength and agility characters) or spell power (intellect). The ratio already holds every bonus in that number (versatility, talents, auras), so it is not Blizzard's own coefficient. English game text only.", { "formulas", "damage" },
                    function() return not TT.DB().formulas.enabled end),
                note = { type = "description", order = 9, name = "Built only from numbers the game reports while you play. Blizzard's own spell coefficients are not readable by addons." },
            } },
        },
    }
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
boot:RegisterEvent("TRAIT_CONFIG_UPDATED")
boot:RegisterEvent("PLAYER_REGEN_ENABLED")
boot:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then TT.DB(); TT.Init() end
    if event ~= "PLAYER_REGEN_ENABLED" then TT.talentHash = nil end   -- talents or spec changed: match observed data again
    -- observed formulas: your own class's data folder only, loaded out of combat; talent changes reset the talent match
    if TT.LoadClassData then pcall(TT.LoadClassData) end
end)

SLASH_XUITT1 = "/xuitt"
SlashCmdList.XUITT = function(msg)
    msg = (msg or ""):lower()
    if msg:find("probe") then TT.Probe()
    elseif msg:find("lines") then TT.DumpLines()
    else print("XayaUI Tooltips: /xuitt probe (point at a unit first), /xuitt lines (raw lines of the tooltip under the mouse)") end
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
ns.RegisterSettingsPage("bonus", "tooltips", ns.BuildTooltipsTab)
