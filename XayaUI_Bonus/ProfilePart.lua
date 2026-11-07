-------------------------------------------------------------------------------
-- ProfilePart.lua (XayaUI_Bonus 0.6.30): Bonus Features' part of a profile (Profiles > Import / Export), registered with the Platform
-- (core Modules.lua ns.RegisterProfilePart; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.1). The keys and what is left out are
-- the ones Profiles.lua listed for "Bonus Features" before (Options 0.6.72), so a profile string is unchanged. The Notepad stays out
-- (personal data).
-------------------------------------------------------------------------------
local _, ns = ...
ns = rawget(_G, "XayaUI_NS") or ns
if not (ns and ns.RegisterProfilePart) then return end
ns.RegisterProfilePart({ key = "bonus", label = "Bonus Features", module = "XayaUI_Bonus", order = 50, version = 1,
    db = { "dataPanels", "tooltips", "calculator" },
    never = {
        calculator = { history = true, point = true, x = true, y = true },
        tooltips = { selfAura = true },   -- learned from your own buffs on this computer
    } })
