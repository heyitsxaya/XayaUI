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
-- (Stat Calculator V25, A24 #7) format 3: written after the move from the Slot Overlays and the item details to the two options Item
-- level and Enchants (each with a style). A part older than format 3 carries the old slot marks' keys: after the import they are read
-- the way the one-time move reads saved settings (ns.CharDisplay_RemapOlder; it runs on the next frame, once the Blizzard Reskin part
-- with the item details' keys is in too), so an older string still shows what it showed when it was made. Keys and values unchanged.
-- A format-3 part: a style (or the Empty sockets mark) it does not hold is set to its default, since none is saved at its default.
local def = { key = "qol", label = "QoL", module = "XayaUI_QoL", order = 40, version = 3,
    db = { "cursorHighlight", "cursorTrail", "characterToolkit", "releaseGuard", "cursor" } }
ns.RegisterProfilePart(def)
local base = def.apply   -- (the Platform's own merge, built by ns.RegisterProfilePart from `db`)
if type(base) == "function" then
    def.apply = function(part, mode, fromVersion)
        local r = base(part, mode, fromVersion)
        local from = tonumber(fromVersion) or 1
        if from < 2 and type(part) == "table" and ns.CharDisplay_MergeOlder then
            local ok, err = pcall(ns.CharDisplay_MergeOlder, part.characterToolkit)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        end
        if from < 3 and type(part) == "table" and ns.CharDisplay_RemapOlder then
            local ok, err = pcall(ns.CharDisplay_RemapOlder, part.characterToolkit)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        elseif from >= 3 and type(part) == "table" and ns.CharDisplay_ImportStyles then
            -- (format 3) a style the string does not hold is its default (it is not saved at its default)
            local ok, err = pcall(ns.CharDisplay_ImportStyles, part.characterToolkit)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        end
        return r
    end
end
-- (review round 2, A24 #7) the move above for an older QoL part needs to know whether the same import also writes the Blizzard Reskin
-- part with the item details' keys (core's own part, order 60, applied after this one in the same pass): its apply tells
-- ns.CharDisplay_NoteDetailsImport first, then writes as before (nothing it writes is changed). Without that part in the import, the
-- item level / enchant settings saved now are kept as the two options they already are.
local rsk = ns.ProfilePartsByKey and ns.ProfilePartsByKey().reskin
if type(rsk) == "table" and type(rsk.apply) == "function" and not rsk.xuiNotesDetails then
    local rbase = rsk.apply
    rsk.xuiNotesDetails = true
    rsk.apply = function(part, ...)
        if type(part) == "table" and ns.CharDisplay_NoteDetailsImport then
            local ok, err = pcall(ns.CharDisplay_NoteDetailsImport, part.characterReskin)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        end
        return rbase(part, ...)
    end
end
