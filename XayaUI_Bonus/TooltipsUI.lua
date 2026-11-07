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
            TT.Sync()   -- installs, or lets go of, what the switches now need (Tooltips.lua, V14)
            if Notify then Notify() end
        end
    end
    local function toggle(order, name, desc, path, disabled)
        return { type = "toggle", order = order, name = name, desc = desc, width = "full",
                 get = get(path), set = set(path), disabled = disabled }
    end
    -- (V14, Bonus 0.6.12) said under each of the four main switches
    local OFF = " With Enhanced Tooltips off (the tick box on its row on the left), or IDs, Item level, Enemy forces, Formulas and Type colours all off, nothing of the tooltip features is installed or runs. Once one was on, its tooltip hooks stay until you /reload but do nothing."
    local idsOff = function() return not TT.DB().ids.enabled end
    local ids = {
        enabled = toggle(1, "Show IDs on tooltips", "Master switch for the ID lines below." .. OFF, { "ids", "enabled" }),
        npc = toggle(2, "NPC IDs", "Read from the unit's GUID. Skipped when the game hides the GUID.", { "ids", "npc" }, idsOff),
        auraHint = toggle(4, "Say \"not known yet\" when a spell's aura is not known", "Under a spell that lasts for some seconds. The aura's name and ID appear after you cast the spell once out of combat, or hover it while the aura is on you.", { "ids", "auraHint" }, idsOff),
        icon = toggle(3, "Icon IDs (under spell, aura and item lines)", nil, { "ids", "icon" }, idsOff),
    }
    for i, kind in ipairs(TT.ID_KINDS) do
        ids[kind.key] = toggle(10 + i, kind.name, nil, { "ids", kind.key }, idsOff)
    end
    -- (Bonus 0.6.14; Xaya 2026-11-06: "yes, give an enable / disable "Enhanced Tooltips" as a feature") the feature's master switch is
    -- the tick box on its row in the left pane (xuiSwitch, as every other feature's); the four section switches stay on the page
    return {
        type = "group", name = "Enhanced Tooltips", order = 2, childGroups = "tab",
        xuiSwitch = { type = "toggle", name = "Enhanced Tooltips", tip = "Adds IDs, item level, enemy forces, formulas and type colours to game tooltips.",
            desc = "Turns the enhanced tooltips on or off as a whole (IDs, Item level, Enemy forces, Formulas, Type colours). Off: nothing of them is installed or runs, whatever their own switches say; their settings are kept. Once it was on, its tooltip hooks stay until you /reload but do nothing.",
            get = get({ "enabled" }), set = set({ "enabled" }) },
        args = {
            ids = { type = "group", name = "IDs", order = 1, args = ids },
            ilvl = { type = "group", name = "Item level", order = 2, args = {
                enabled = toggle(1, "Show player item level on hover", "Yourself: equipped average. Others: via Inspect, cached." .. OFF, { "ilvl", "enabled" }),
                inspect = toggle(2, "Inspect other players", "Sends one inspect request at a time. Not in combat.", { "ilvl", "inspect" },
                    function() return not TT.DB().ilvl.enabled end),
                cacheSecs = { type = "range", order = 3, name = "Cache seconds", min = 30, max = 600, step = 10, width = "full",
                    get = get({ "ilvl", "cacheSecs" }), set = set({ "ilvl", "cacheSecs" }),
                    disabled = function() return not TT.DB().ilvl.enabled end },
            } },
            forces = { type = "group", name = "Enemy forces", order = 3, args = {
                enabled = toggle(1, "Show count and % on hostile units", "Read live from the game; shown only when the game returns it." .. OFF, { "forces", "enabled" }),
                onlyInDungeon = toggle(2, "Only inside dungeons and raids", nil, { "forces", "onlyInDungeon" },
                    function() return not TT.DB().forces.enabled end),
                onlyMythicPlus = toggle(3, "Only in an active Mythic+ run", nil, { "forces", "onlyMythicPlus" },
                    function() return not TT.DB().forces.enabled end),
                note = { type = "description", order = 9, name = "Crowd control, true sight and casts are not included: they need an enemy database that does not exist yet." },
            } },
            formulas = { type = "group", name = "Formulas", order = 4, args = {
                enabled = toggle(1, "Show formula lines on spell tooltips", "Out of combat only: the game hides stats and cooldown details in combat." .. OFF, { "formulas", "enabled" }),
                cooldown = toggle(2, "Cooldown and recharge", "The game's cooldown or recharge time divided by its rate (haste, when the rate matches your haste), checked against the time the tooltip prints. A spell that is not on cooldown shows only its base time: the game reports the rate only while it runs.", { "formulas", "cooldown" },
                    function() return not TT.DB().formulas.enabled end),
                damage = toggle(3, "Damage ratio", "Each damage number in the spell's text divided by your attack power (strength and agility characters) or spell power (intellect). The ratio already holds every bonus in that number (versatility, talents, auras), so it is not Blizzard's own coefficient. English game text only.", { "formulas", "damage" },
                    function() return not TT.DB().formulas.enabled end),
                note = { type = "description", order = 9, name = "Built only from numbers the game reports while you play. Blizzard's own spell coefficients are not readable by addons." },
            } },
            -- (Bonus 0.6.20; Xaya 2026-11-06, REQUEST-LOG S8-10) damage school and dispel type words coloured
            typeColors = { type = "group", name = "Type colours", order = 5, args = {
                enabled = toggle(1, "Colour damage schools and dispel types", "On spell and aura tooltips: \"fire damage\" becomes \"Fire Damage\" in the game's Fire colour, a dispel type in brackets after it (\"(Magic)\") or at an aura tooltip's top right in its dispel colour. The game's own colours. English game text only." .. OFF, { "typeColors", "enabled" }),
            } },
        },
    }
end

-- At login: what the saved switches need, and nothing for the ones that are off (Bonus 0.6.12, V14; Tooltips.lua TT.Sync). The
-- spec / talent / combat-end / Cooldown Manager events are TT.Sync's, registered only while IDs or Formulas are on.
if ns.AtLogin then ns.AtLogin(TT.Sync)   -- (core Modules.lua: at PLAYER_LOGIN, or at once after it)
else
    local boot = CreateFrame("Frame")
    boot:RegisterEvent("PLAYER_LOGIN")
    boot:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); TT.Sync() end)
end

-- /xuitt (aura, probe, lines: developer reports) is XayaUI Dev Assist's since Bonus 0.6.18 (REQUEST-LOG #81, Xaya 2026-11-06: "Move all
-- of them"; XayaUI_DevAssist/CoreDebug.lua). Without Dev Assist the command does not exist.

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
ns.RegisterSettingsPage("bonus", "tooltips", ns.BuildTooltipsTab)
