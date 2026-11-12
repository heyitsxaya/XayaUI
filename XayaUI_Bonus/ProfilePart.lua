-------------------------------------------------------------------------------
-- ProfilePart.lua (XayaUI Bonus Features 0.6.46): Bonus Features' part of a profile (Profiles > Import / Export), registered with the
-- Platform (core Modules.lua section 9, ns.RegisterProfilePart), as XayaUI Rules registers its own (XayaUI_Rules/RuleShare.lua).
-- Xaya, REQUEST-LOG A24 #13 (her answer): profiles: "Yes, include them (Recommended)": the Stat Calculator's saved settings
-- (XayaUIBonusDB.characterToolkit) travel in profiles.
-- It lives in XayaUI_Bonus (always read while Bonus Features is on), not in the load-on-demand XayaUI_Bonus_StatCalculator, so the part
-- is offered under Export and read under Import whether or not the Stat Calculator is switched on, and Import never says it "needs
-- XayaUI Bonus Features" while Bonus Features is installed and on.
--
-- Format 2 (main): { characterToolkit = the Stat Calculator's keys }. The Platform builds snapshot / check / apply from `db`
-- (core DbPart): characterToolkit is a split key (core LEGACY_SPLIT: XayaUI Bonus Features keeps the Stat Calculator's keys, XayaUI QoL
-- every other one), so an import writes only the Stat Calculator's keys (and the switch `enabled`, a key both halves keep) into
-- XayaUIBonusDB.characterToolkit; keys of Improved Character Display (QoL, not on main) are left out. A reload puts them to work (the
-- part asks for one, like every settings part): the switch decides at login whether the calculator is read at all.
-- Format 1 was qa-installer-branch's Bonus Features part (data panels, tooltips, calculator); none of it is on main, so a format-1
-- part imports nothing here.
-- Older strings from qa-installer-branch: there the Stat Calculator's settings travel in the QoL part (XayaUI_QoL/ProfilePart.lua,
-- db = { ..., "characterToolkit", ... }), not in the Bonus Features part. adopt() (called by XayaUI_Options/Profiles.lua before the
-- parts are cleaned) takes that characterToolkit into this part while no XayaUI QoL is loaded, so such a string imports its Stat
-- Calculator settings; the rest of its QoL part still says it needs XayaUI QoL. INFERENCE: on QA the QoL part's `enabled` is QoL's copy
-- of the switch; QA's own import writes it to both halves (core LEGACY_SPLIT `both`), and so does main.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
if not (ns and ns.RegisterProfilePart) then return end
local BonusS = ns.Settings("bonus")

local def = { key = "bonus", label = "Bonus Features", module = "XayaUI_Bonus", order = 50, version = 2, db = { "characterToolkit" } }
ns.RegisterProfilePart(def)
local base = def.snapshot   -- (the Platform's, built from `db`)
if type(base) == "function" then
    -- the switch: core's old layout reads `enabled` from QoL's half (the split's `both`), which main does not have, so it is added from
    -- Bonus Features' own settings
    def.snapshot = function(name)
        local part = base(name)
        local c = ns.SettingsReady("bonus") and BonusS.characterToolkit
        if type(part) == "table" and type(c) == "table" and c.enabled ~= nil then
            part.characterToolkit = type(part.characterToolkit) == "table" and part.characterToolkit or {}
            part.characterToolkit.enabled = c.enabled == true
        end
        return part
    end
end
local function Copy(v, depth)
    if type(v) ~= "table" or depth > 16 then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Copy(x, depth + 1) end
    return t
end
-- parts = the pasted profile's parts (not yet cleaned)
def.adopt = function(parts)
    local q = type(parts) == "table" and parts.qol
    if type(q) ~= "table" or type(q.characterToolkit) ~= "table" then return end
    local byKey = ns.ProfilePartsByKey and ns.ProfilePartsByKey() or {}
    if byKey.qol then return end   -- XayaUI QoL is loaded: its own part reads it
    local b = parts.bonus
    if b ~= nil and type(b) ~= "table" then return end
    b = b or {}
    if b.characterToolkit == nil then b.characterToolkit = Copy(q.characterToolkit, 1) end
    parts.bonus = b
end
