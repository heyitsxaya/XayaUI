-- TalentDump.lua - the entry point of /xui debug talents (Core.lua, through XayaUI Rules' "rules" service, RuleDefaults.lua).
-- (bundle 1 round 7, REQUEST-LOG A23 SD-58, her words: "Move all four (Recommended)"; V34) The talent scan itself (scan every class's
-- talents, the last scan's status, find a talent by name) is XayaUI Options' (XayaUI_Options/TalentDump.lua), read only when the settings
-- window's code loads. The scan it saves stays this addon's saved variable XayaUITalentDB (## SavedVariables in XayaUI_Rules.toc), so no
-- saved scan is lost. This file keeps only the command: out of combat it loads the settings window's code without opening the window
-- (core's ns.LoadOptions; that says itself when XayaUI Options is switched off or missing) and runs the command there. In combat the
-- window's code does not load (V26, Modules.lua ns.LoadOptions): one line, and the command runs when combat ends.
local _, ns = ...; ns = XayaUI_NS or ns -- (P4) XayaUI Rules shares the Platform's namespace (XayaUI/Core.lua)

-- (bundle 1 round 7 repair) With XayaUI Options switched off or not installed, every use says so in one line naming this command. Core's
-- ns.LoadOptions says it only once per session, so without this line the second use printed nothing at all. Read from the game's addon
-- list (C_AddOns.GetAddOnInfo's reason: "DISABLED" or "MISSING"); it loads nothing, so it answers in combat too. Whether this command
-- should work without XayaUI Options at all is Xaya's decision (round 7 relocate repair report); until then it needs it.
local function OptionsUnavailableLine()
    local A = C_AddOns
    if not (A and A.GetAddOnInfo) then return nil end
    local ok, name, _, _, _, reason = pcall(A.GetAddOnInfo, ns.OPTIONS_ADDON or "XayaUI_Options")
    if not ok then return nil end
    if reason == "MISSING" or not name then
        return "/xui debug talents is part of the settings window (XayaUI Options), which is not installed: the XayaUI_Options folder belongs next to XayaUI in Interface\\AddOns."
    elseif reason == "DISABLED" then
        return "/xui debug talents is part of the settings window (XayaUI Options), which is switched off. Turn it on in the game's AddOns list, then /reload."
    end
    return nil
end

function ns.TalentCommand(arg)
    local O = ns.OptionsApi
    if not (O and O.TalentCommand) then
        local off = OptionsUnavailableLine()
        if off then if ns.Print then ns.Print(off) end; return end
        if ns.InCombatLock and ns.InCombatLock() then
            local scan = tostring(arg or ""):match("^%s*(.-)%s*$") == ""
            ns.CombatLock("talents", function() ns.TalentCommand(arg) end, scan
                and "the talent scan can't run during combat. It will run when combat ends."
                or "the last talent scan can't be read during combat. It will be shown when combat ends.")
            return
        end
        if not (ns.LoadOptions and ns.LoadOptions()) then return end
        O = ns.OptionsApi
        if not (O and O.TalentCommand) then return end
    end
    return O.TalentCommand(arg)
end
