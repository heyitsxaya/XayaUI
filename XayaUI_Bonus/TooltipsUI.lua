-- TooltipsUI.lua : options group for the Tooltip Modifiers (AceConfig table), plus /xuitt.
local addonName, ns = ...
ns = _G.XayaUI_NS or ns
local TT = ns.TT

-- Returns an AceConfig group; registered as a Bonus Features page (ns.RegisterSettingsPage, Modules.lua).
local pageRead = false
function ns.BuildTooltipsTab(Notify)
    -- (Bonus 0.6.39, V25 R4; Xaya A24 #6) the first time this page is built after a reload, the character stat lines' tie-ins (XayaUI
    -- QoL's Improved Character Display and stat model) are read once more; never again after that (Tooltips.lua section 5)
    if not pageRead then pageRead = true; pcall(TT.CharStatsReadTieIns, true); pcall(TT.CharStatsSync) end
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
    -- (V14, Bonus 0.6.12) once a sentence under each of the four main switches; empty since UI-65 (Bonus 0.6.26: hovers at most two sentences)
    -- (the text it held: off, nothing of the tooltip features runs; hooks placed while on stay until /reload, doing nothing)
    local OFF = ""
    local idsOff = function() return not TT.DB().ids.enabled end
    local ids = {
        enabled = toggle(1, "Show IDs on tooltips", "Shows the ID lines below." .. OFF, { "ids", "enabled" }),
        npc = toggle(2, "NPC IDs", "Shows the NPC's ID. Skipped when the game hides it.", { "ids", "npc" }, idsOff),
        auraHint = toggle(4, "Say \"not known yet\" when a spell's aura is not known", "Shows a note under a spell with a duration until its aura is known. Cast it once out of combat, or hover it while the aura is on you.", { "ids", "auraHint" }, idsOff),
        icon = toggle(3, "Icon IDs (under spell, aura and item lines)", nil, { "ids", "icon" }, idsOff),
    }
    for i, kind in ipairs(TT.ID_KINDS) do
        ids[kind.key] = toggle(10 + i, kind.name, nil, { "ids", kind.key }, idsOff)
    end
    -- (Bonus 0.6.14; Xaya 2026-11-06: "yes, give an enable / disable "Enhanced Tooltips" as a feature") the feature's master switch is
    -- the tick box on its row in the left pane (xuiSwitch, as every other feature's); the four section switches stay on the page
    return {
        type = "group", name = "Enhanced Tooltips", order = 2, childGroups = "tab",
        xuiSwitch = { type = "toggle", name = "Enhanced Tooltips", tip = "Adds IDs, item level, enemy forces, formulas and type colors to game tooltips.",
            desc = "Turns all enhanced tooltips on or off (IDs, Item level, Enemy forces, Formulas, Type colors, Character stats). Off, none of them runs; their settings are kept.",
            get = get({ "enabled" }), set = set({ "enabled" }) },
        args = {
            ids = { type = "group", name = "IDs", order = 1, args = ids },
            ilvl = { type = "group", name = "Item level", order = 2, args = {
                enabled = toggle(1, "Show player item level on hover", "Shows your equipped average, and other players' item level from Inspect." .. OFF, { "ilvl", "enabled" }),
                inspect = toggle(2, "Inspect other players", "Sends one inspect request at a time. Not in combat.", { "ilvl", "inspect" },
                    function() return not TT.DB().ilvl.enabled end),
                cacheSecs = { type = "range", order = 3, name = "Cache seconds", min = 30, max = 600, step = 10, width = "full",
                    get = get({ "ilvl", "cacheSecs" }), set = set({ "ilvl", "cacheSecs" }),
                    disabled = function() return not TT.DB().ilvl.enabled end },
            } },
            forces = { type = "group", name = "Enemy forces", order = 3, args = {
                enabled = toggle(1, "Show count and % on hostile units", "Shown only when the game gives it." .. OFF, { "forces", "enabled" }),
                onlyInDungeon = toggle(2, "Only inside dungeons and raids", nil, { "forces", "onlyInDungeon" },
                    function() return not TT.DB().forces.enabled end),
                onlyMythicPlus = toggle(3, "Only in an active Mythic+ run", nil, { "forces", "onlyMythicPlus" },
                    function() return not TT.DB().forces.enabled end),
                note = { type = "description", order = 9, name = "Crowd control, true sight and casts are not included: they need an enemy database that does not exist yet." },
            } },
            formulas = { type = "group", name = "Formulas", order = 4, args = {
                enabled = toggle(1, "Show formula lines on spell tooltips", "Out of combat only: the game hides stats and cooldown details in combat." .. OFF, { "formulas", "enabled" }),
                cooldown = toggle(2, "Cooldown and recharge", "Shows the cooldown or recharge time divided by its rate (such as haste). A spell not on cooldown shows only its base time.", { "formulas", "cooldown" },
                    function() return not TT.DB().formulas.enabled end),
                damage = toggle(3, "Damage ratio", "Shows each damage number divided by your attack power or spell power, bonuses included. English game text only.", { "formulas", "damage" },
                    function() return not TT.DB().formulas.enabled end),
                note = { type = "description", order = 9, name = "Built only from numbers the game reports while you play. Blizzard's own spell coefficients are not readable by addons." },
            } },
            -- (Bonus 0.6.20; Xaya 2026-11-06, REQUEST-LOG S8-10) damage school and dispel type words coloured
            typeColors = { type = "group", name = "Type colors", order = 5, args = {
                enabled = toggle(1, "Color damage schools and dispel types", "Colors damage schools and dispel types on spell and aura tooltips in the game's colors. English game text only." .. OFF, { "typeColors", "enabled" }),
            } },
            -- (Bonus 0.6.39, V25 R4; Xaya A24 #5 / #6) the extra lines on the character window's own stat tooltips: off by default, and only
            -- while XayaUI QoL's Improved Character Display is on (as read once at the login and once when this page was first built)
            charStats = { type = "group", name = "Character stats", order = 6, args = {
                enabled = { type = "toggle", order = 1, width = "full", name = "Add XayaUI lines to the character window's stat tooltips",
                    desc = "Adds XayaUI's numbers for each stat (rating, rating per 1%, diminishing returns, what it feeds) under its tooltip in the character window. Needs Improved Character Display (QoL) on.",
                    get = function() return TT.DB().charStats == true end,
                    set = function(_, v) TT.DB().charStats = v and true or nil; TT.Sync(); if Notify then Notify() end end,
                    disabled = function() return not TT.CharStatsDisplayOn() end },
                note = { type = "description", order = 9, hidden = function() return TT.CharStatsDisplayOn() end,
                    name = "Turn on Improved Character Display (QoL > Improved Character Display) to use this." },
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
-- (Bonus 0.6.34; PS-56, #469) other addons that change tooltips (Modules.lua section 5d): a flag only, nothing changes here.
-- ElvUI: folder "ElvUI" (https://github.com/tukui-org/ElvUI : ElvUI/ElvUI.toc; module folder Modules/Tooltip).
-- TipTac: folder "TipTac" (https://github.com/frozn/TipTac : TipTac/TipTac.toc; "a tooltip enhancement addon").
-- idTip: folder "idTip" (https://github.com/silverwind/idTip : idTip.toc at the root; "Adds various IDs to the WoW ingame tooltips").
-- (all read 2026-11-08)
if ns.RegisterConflict then
    local function on() local d = TT.DB(); return d and d.enabled and true or false end
    ns.RegisterConflict({ part = "tooltips", label = "Enhanced Tooltips", addons = { "ElvUI", "TipTac" }, what = "tooltips", on = on })
    ns.RegisterConflict({ part = "tooltips", label = "Enhanced Tooltips", addons = { "idTip" }, what = "the IDs shown on tooltips", on = on })
end
