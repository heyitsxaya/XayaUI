-------------------------------------------------------------------------------
-- ProfilePart.lua (XayaUI_QoL 0.7.46): QoL's part of a profile (Profiles > Import / Export), registered with the Platform
-- (core Modules.lua ns.RegisterProfilePart; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.1). The keys are the ones Profiles.lua
-- listed for "QoL" before (Options 0.6.72), so a profile string is unchanged. The Shopping List stays out (personal data).
-------------------------------------------------------------------------------
local _, ns = ...
ns = rawget(_G, "XayaUI_NS") or ns
if not (ns and ns.RegisterProfilePart) then return end
ns.RegisterProfilePart({ key = "qol", label = "QoL", module = "XayaUI_QoL", order = 40, version = 1,
    db = { "cursorHighlight", "cursorTrail", "characterToolkit", "releaseGuard", "cursor" } })
