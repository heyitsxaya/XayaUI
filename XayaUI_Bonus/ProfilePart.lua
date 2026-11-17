-------------------------------------------------------------------------------
-- ProfilePart.lua (XayaUI Bonus Features 0.6.47): Bonus Features' part of a profile (Profiles > Import / Export), registered with the
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
-- part asks for one, like every settings part). (0.6.47, bundle 1 round 10; REQUEST-LOG SD-94 / SD-105) the switch itself takes effect
-- at once: after the import the loader's switch logic runs (ns.StatCalcLoader.SwitchChanged, XayaUI_Bonus/StatCalculatorLoader.lua), as
-- after a tick on its row: imported on, it is usable now (it loads at its first open); imported off, a loaded calculator is inert now
-- and its memory is freed at the next /reload; a loaded one takes the imported settings at once.
-- Format 1 was qa-installer-branch's Bonus Features part (data panels, tooltips, calculator); of it only the Calculator's switch is on
-- main (below), so a format-1 part imports that and nothing else.
-- Older strings from qa-installer-branch: there the Stat Calculator's settings travel in the QoL part (XayaUI_QoL/ProfilePart.lua,
-- db = { ..., "characterToolkit", ... }), not in the Bonus Features part. adopt() (called by XayaUI_Options/Profiles.lua before the
-- parts are cleaned) takes that characterToolkit into this part while no XayaUI QoL is loaded, so such a string imports its Stat
-- Calculator settings; the rest of its QoL part still says it needs XayaUI QoL. The QoL part's `enabled` is NOT taken: on QA it is the
-- switch of QoL's Improved Character Display (qa-installer-branch 049b1dd XayaUI_QoL/ImprovedCharacterDisplay.lua:146 and :2018, its
-- page's tick box), not the Stat Calculator's own choice,
-- so an older QA string never turns the calculator on or off here; the player's switch stays as it was (review of b1bef6e, issue 1;
-- whether she wants it adopted instead is asked, not built).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
if not (ns and ns.RegisterProfilePart) then return end
local BonusS = ns.Settings("bonus")

-- (0.6.47, bundle 1 round 10; SD-95 / SD-115 / SD-116) the arithmetic Calculator is back inside XayaUI_Bonus (Calculator.lua): its key
-- `calculator` travels as it did in qa-installer-branch's Bonus part (format 1: db "calculator", never history / point / x / y), so only
-- its switch `enabled` is in a profile; your sums and its place on screen stay yours. The format stays 2: a key is only added (the
-- Platform's check takes each `db` key that is there), so a format-2 string from before has no `calculator` and leaves the switch as it
-- is, and an older XayaUI_Bonus reading a newer string leaves `calculator` out; a format-1 (QA) string's `calculator.enabled` imports.
local def = { key = "bonus", label = "Bonus Features", module = "XayaUI_Bonus", order = 50, version = 2, db = { "characterToolkit", "calculator" },
    never = { calculator = { history = true, point = true, x = true, y = true } } }
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
local baseApply = def.apply   -- (the Platform's, built from `db`)
if type(baseApply) == "function" then
    def.apply = function(part, ...)
        local L = ns.StatCalcLoader
        local was = L and L.Saved and L.Saved() or false
        local res = baseApply(part, ...)
        if L and L.SwitchChanged then L.SwitchChanged(was) end
        if ns.Calculator_Sync then ns.Calculator_Sync() end   -- (the Calculator imported off: an open keypad closes at once; on: usable now)
        return res
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
    if b.characterToolkit == nil then
        local c = Copy(q.characterToolkit, 1)
        c.enabled = nil   -- QoL's switch, not the Stat Calculator's (see above)
        b.characterToolkit = c
    end
    parts.bonus = b
end
