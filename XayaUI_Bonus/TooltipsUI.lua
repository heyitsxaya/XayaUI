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
        },
    }
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function() TT.DB(); TT.Init() end)

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
