-------------------------------------------------------------------------------
-- StatsText.lua (XayaUI_QoL 0.7.49; platform split P5, docs/plans/PLATFORM-SPLIT-2026-11-07.md section 5): the shelved QoL "stats text"
-- boxes' defaults and their saved list. Moved here from the Platform's XayaUI/Core.lua (P4 left them there; PS-52: "The QoL 'stats text'
-- box defaults that P4 left in the Platform's Core.lua move to QoL now"). The boxes themselves are shelved (shelved/QoL.lua is not
-- loaded); the list is still kept, shared by the rules' backups and the rules tree (the "statsText" service below).
-- Saved: XayaUIQoLDB.qol.boxes (CueRulesDB.qol.boxes before P5). With XayaUI QoL switched off nothing of it is made (V14).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local QolS = ns.Settings("qol")

-- QoL "stats text" box defaults (see shelved/QoL.lua)
ns.QOL_BOX_DEFAULTS = {
    name = "Stats",
    enabled = true,
    format = "Crit {crit}   Haste {haste}\nMastery {mastery}   Vers {vers}",
    size = 14,   -- outline / justify / showCombat: blank until chosen (fallbacks: outline / left / always)
    color = { 1, 1, 1, 1 }, alpha = 1,
    decimals = 1,
    x = 0, y = -250,
}

-- the saved list, set up once QoL's settings are open (this addon's ADDON_LOADED; Modules.lua section 0c), as the Platform did it at its
-- own load before P5
ns.WhenSettingsReady("qol", function()
    local q = QolS.qol
    if type(q) ~= "table" then q = {}; QolS.qol = q end
    q.boxes = q.boxes or {}
    for _, b in ipairs(q.boxes) do
        ns.Merge(b, ns.QOL_BOX_DEFAULTS)
        if b.showCombat == "any" then b.showCombat = "none" end
    end
    ns.qolBoxes = q.boxes
end)
-- the rules' backups and the rules tree (XayaUI Rules / Rules Options) reach the list through this service; absent while QoL is off
if ns.Provide then ns.Provide("statsText", { Boxes = function() return ns.qolBoxes end, DEFAULTS = ns.QOL_BOX_DEFAULTS }) end
