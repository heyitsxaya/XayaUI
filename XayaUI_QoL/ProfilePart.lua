-------------------------------------------------------------------------------
-- ProfilePart.lua (XayaUI_QoL 0.7.46): QoL's part of a profile (Profiles > Import / Export), registered with the Platform
-- (core Modules.lua ns.RegisterProfilePart; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.1). The keys are the ones Profiles.lua
-- listed for "QoL" before (Options 0.6.72), so a profile string is unchanged. The Shopping List stays out (personal data).
-------------------------------------------------------------------------------
local _, ns = ...
ns = rawget(_G, "XayaUI_NS") or ns
if not (ns and ns.RegisterProfilePart) then return end
-- (QoL 0.7.56, Stat Calculator V25) format 2: written after Improved Character Display's one-time merge of the old switches
-- (ImprovedCharacterDisplay.lua). A format-1 part (made before it) is imported as before, then read the way the merge reads saved
-- settings (ns.CharDisplay_MergeOlder), so an older string shows on the character window what it showed when it was made. The keys
-- and values are unchanged; only the part's information (partInfo.qol, v = 2) is new in the string.
local def = { key = "qol", label = "QoL", module = "XayaUI_QoL", order = 40, version = 2,
    db = { "cursorHighlight", "cursorTrail", "characterToolkit", "releaseGuard", "cursor" } }
ns.RegisterProfilePart(def)
local base = def.apply   -- (the Platform's own merge, built by ns.RegisterProfilePart from `db`)
if type(base) == "function" then
    def.apply = function(part, mode, fromVersion)
        local r = base(part, mode, fromVersion)
        if (tonumber(fromVersion) or 1) < 2 and type(part) == "table" and ns.CharDisplay_MergeOlder then
            local ok, err = pcall(ns.CharDisplay_MergeOlder, part.characterToolkit)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        end
        return r
    end
end
