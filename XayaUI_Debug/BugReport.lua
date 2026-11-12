-------------------------------------------------------------------------------
-- XayaUI Debug: the bug report (/xui bug, and Settings > Debugging > Create bug report). Moved from XayaUI/Console.lua in bundle 1 round 7
-- (REQUEST-LOG A23 SD-58: the bug report is one of the debug tools, read only while Advanced Debugging is on; Tools.lua says how this
-- addon loads). Version, game build, recent errors and console lines as plain text, with no character name, realm, or rule contents.
-- It reads the error record that XayaUI core keeps (XayaUI/DebugRecord.lua: ns.ErrorCount, ns.ErrorEntries) and the log buffer
-- (ns.logBuf, XayaUI/Core.lua). V26: exempt from the combat lock (her words: "the error / bug report").
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI)
local Plain = ns.PlainText   -- (XayaUI/Console.lua)

-- the Platform's settings, through its view (Modules.lua section 0b: only the Platform's own files name its saved variable)
local PlatS = ns.Settings and ns.Settings("platform")
local function Ui()
    if not (PlatS and ns.SettingsReady()) then return {} end
    local u = PlatS.ui
    if type(u) ~= "table" then u = {}; PlatS.ui = u end
    return u
end

-- XayaUI core's version (the report names the Platform's, as before the move)
local function AddonVersion()
    local f = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(f, ns.name or "XayaUI", "Version")
    return (ok and v) or "?"
end

-------------------------------------------------------------------------------
-- Bug report
-------------------------------------------------------------------------------
function ns.BuildBugReport(description, includeAddons)
    local L = {}
    local function add(s) L[#L + 1] = s end
    local gv, gb, gd, toc = "?", "?", "?", "?"
    if GetBuildInfo then gv, gb, gd, toc = GetBuildInfo() end
    add("XayaUI bug report")
    add(("XayaUI version: %s | game %s (build %s, %s, interface %s)"):format(AddonVersion(), tostring(gv), tostring(gb), tostring(gd), tostring(toc)))
    add(("Report made: %s (local time)"):format(date("%Y-%m-%d %H:%M:%S")))
    local R = ns.Service and ns.Service("rules")   -- (P4) XayaUI Rules' "rules" service; nil while it is switched off
    local spec = R and R.CurrentSpecID() or nil
    add(("Spec ID: %s | in combat: %s | locale: %s"):format(tostring(spec), tostring((UnitAffectingCombat and UnitAffectingCombat("player")) and true or false), tostring(GetLocale and GetLocale() or "?")))
    local nr, nc, ncond = 0, 0, 0
    for _, r in ipairs(R and R.Rules() or {}) do
        if r.isCue then nc = nc + 1 elseif r.parentUid then ncond = ncond + 1 else nr = nr + 1 end
    end
    add(("Rules: %d | cues: %d | conditions: %d | skin on: %s"):format(nr, nc, ncond, (ns.Options and tostring(ns.Options.SkinOn()) or "window not loaded")))
    add("(No character name or realm, and no rule settings. Rule names appear in the console lines below, and in XayaUI Dev Assist's detailed record when it is on.)")
    add("")
    add("What happened:")
    add((description and description:match("%S")) and description or "(not filled in)")
    add("")
    local total, kinds = ns.ErrorCount()
    add(("Errors and warnings from XayaUI: %d occurrence(s), %d different (codes: /xui report)"):format(total, kinds))
    for i, e in ipairs(ns.ErrorEntries()) do
        if i > 15 then add("... " .. (kinds - 15) .. " more not shown"); break end
        add(("[%d] %s x%d | first %s | last %s | version %s%s"):format(i, tostring(e.code), e.n or 1, date("%m-%d %H:%M", e.first or 0), date("%m-%d %H:%M", e.last or 0), tostring(e.ver), e.combat and " | in combat" or ""))
        add("    " .. tostring(e.msg))
        if e.stack and e.stack ~= "" then add("    stack: " .. e.stack:gsub("\n", " / ")) end
    end
    add("")
    add("Last console lines:")
    local buf = ns.logBuf or {}
    for i = math.max(1, #buf - 59), #buf do add("  " .. Plain(buf[i])) end
    -- the saved debug record (DebugRecord.lua, kept while Advanced Debugging is on): the newest 1500 lines here, all of them in the
    -- SavedVariables file. It holds rule names, spell IDs and XayaUI's own messages. Messages that name another player (ns.PrintPrivate) are
    -- never kept: not in the record, and not in ns.logBuf, which the "Last console lines" above read.
    local rn, rdrop, rstart = 0, 0, nil
    if ns.RecordSummary then rn, rdrop, rstart = ns.RecordSummary() end
    if rn > 0 then
        local lines = PlatS.debugRecord.lines
        add("")
        add(("Debug record: %d lines since %s%s (newest %d below; all of them are in XayaUI.lua, see WHAT TO SEND at the end):"):format(
            rn, tostring(rstart), rdrop > 0 and (", " .. rdrop .. " older lines dropped") or "", math.min(rn, 1500)))
        for i = math.max(1, rn - 1499), rn do add("  " .. tostring(lines[i])) end
    end
    if includeAddons then
        add("")
        local names = {}
        local n = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or 0
        for i = 1, n do
            local nm = C_AddOns.GetAddOnInfo(i)
            if nm and C_AddOns.IsAddOnLoaded(nm) then names[#names + 1] = nm end
        end
        add("Loaded addons (" .. #names .. "): " .. table.concat(names, ", "))
    end
    if ns.SendText then add(""); add(ns.SendText()) end   -- the files to send and where they are (DebugRecord.lua)
    return table.concat(L, "\n")
end
function ns.ShowBugReport()
    local u = Ui()
    -- (round 6, SD-55 "Dead logs") shown, not kept: nothing read the saved copy (CueRulesDB.lastBugReport, let go at login: DebugRecord.lua)
    ns.ShowCopyBox("XayaUI bug report", ns.BuildBugReport(u.bugText, u.bugAddons))
end
