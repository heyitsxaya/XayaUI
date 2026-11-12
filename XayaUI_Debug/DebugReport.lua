-------------------------------------------------------------------------------
-- XayaUI Debug: the debug report (/xui report, and Settings > Debugging > Open the debug report). Moved from XayaUI/DebugRecord.lua in
-- bundle 1 round 7 (REQUEST-LOG A23 SD-58: the bug and debug report windows are debug tools, read only while Advanced Debugging is on;
-- Tools.lua says how this addon loads). The record it shows (XayaUI's errors and warnings with their codes) is kept by XayaUI core either
-- way (XayaUI/DebugRecord.lua), so a report opened after a /reload shows what was recorded before. Its reader for imported strings
-- (ns.DebugReportRead) served only XayaUI Dev Assist, which is retired to qa-installer-branch, and was not moved.
-- Her answers (question box, 2026-11-06): report "Both: string and screenshot view". V26: exempt from the combat lock (her words: "the
-- error / bug report").
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI)
local DR = ns.DebugRecordInfo   -- (XayaUI/DebugRecord.lua: Version, GameFolder, MAX_ENTRIES)
local Version = DR.Version

-------------------------------------------------------------------------------
-- The debug report: the same entries as a readable summary (for a screenshot) and as one string (to paste to Xaya)
-------------------------------------------------------------------------------
local REPORT_PREFIX, REPORT_V = "XUIREP1", 1
DR.REPORT_PREFIX = REPORT_PREFIX
local function Clock(t) return (type(t) == "number" and date) and date("%m-%d %H:%M", t) or "?" end
-- The data both views are made from (also what the string carries).
function ns.DebugReportData()
    local d = { v = REPORT_V, made = date and date("%Y-%m-%d %H:%M:%S") or "?", on = ns.AdvancedDebugOn(), entries = {}, addons = {} }
    local okB, ver, build = pcall(GetBuildInfo)
    d.game, d.build = okB and tostring(ver) or "?", okB and tostring(build) or "?"
    local okL, loc = pcall(function() return GetLocale and GetLocale() end)
    d.locale = okL and tostring(loc) or "?"
    d.client = DR.GameFolder() == "_retail_" and "live" or (DR.GameFolder() == "_beta_" and "beta" or "test realm")
    if C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo then
        local okN, total = pcall(C_AddOns.GetNumAddOns)
        for i = 1, (okN and tonumber(total)) or 0 do
            local okI, name = pcall(C_AddOns.GetAddOnInfo, i)
            if okI and type(name) == "string" and name:find("^XayaUI") then
                local okD, _, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
                d.addons[#d.addons + 1] = { name = name, ver = Version(name), loaded = (okD and loaded) and true or false }
            end
        end
    end
    for _, e in ipairs(ns.ErrorEntries()) do
        d.entries[#d.entries + 1] = { code = e.code, kind = e.kind, msg = tostring(e.msg or ""):sub(1, 300),
            stack = e.stack and tostring(e.stack):sub(1, 600) or nil, first = e.first, last = e.last, n = e.n or 1, ver = e.ver,
            combat = e.combat and true or nil }
    end
    return d
end
-- The readable summary. expanded: also each error's stack.
function ns.DebugReportText(d, expanded)
    d = d or ns.DebugReportData()
    local t = {}
    local function add(s) t[#t + 1] = s end
    add(("XayaUI debug report  -  made %s (local time)"):format(tostring(d.made)))
    add(("Game %s (build %s), %s client, locale %s"):format(tostring(d.game), tostring(d.build), tostring(d.client), tostring(d.locale)))
    local a = {}
    for _, x in ipairs(type(d.addons) == "table" and d.addons or {}) do
        a[#a + 1] = ("%s %s%s"):format(tostring(x.name):gsub("^XayaUI_", ""), tostring(x.ver), x.loaded and "" or " (off)")
    end
    add("XayaUI addons: " .. (#a > 0 and table.concat(a, ", ") or "?"))
    local entries = type(d.entries) == "table" and d.entries or {}
    local ne, nw = 0, 0
    for _, e in ipairs(entries) do if e.kind == "warning" then nw = nw + 1 else ne = ne + 1 end end
    if d.on == false then add("Advanced Debugging is OFF: nothing new is recorded (Settings > Debugging).") end
    add(("%d entr%s: %d error%s, %d warning%s (the newest %d are kept)"):format(#entries, #entries == 1 and "y" or "ies", ne,
        ne == 1 and "" or "s", nw, nw == 1 and "" or "s", DR.MAX_ENTRIES))
    if #entries == 0 then add(""); add("No errors or warnings recorded.") end
    for _, e in ipairs(entries) do
        local info = ns.ErrorCodeInfo(e.code)
        add("")
        add(("%s  x%d  %s"):format(tostring(e.code), tonumber(e.n) or 1, info and info.text or "(unknown code)"))
        add(("   first %s, last %s%s, version %s"):format(Clock(e.first), Clock(e.last), e.combat and ", in combat" or "", tostring(e.ver or "?")))
        add("   " .. tostring(e.msg or ""):gsub("\n", " / "))
        if expanded and e.stack and e.stack ~= "" then add("   stack: " .. tostring(e.stack):gsub("\n", " / ")) end
    end
    return table.concat(t, "\n")
end
-- The string: XUIREP1:<checksum>:<base64 of JSON> (XayaUI/Share.lua's codec; not importable as rules or a theme)
function ns.DebugReportString(d)
    if not (ns.Share and ns.Share.Pack) then return nil, "the share codec is not loaded" end
    return ns.Share.Pack(REPORT_PREFIX, d or ns.DebugReportData())
end
-- The window (made the first time it opens). Top: the summary, framed for a screenshot. Bottom: the string, and "Select string".
-- UI-78 (O-128, core 0.6.69; her words: "copy string button doesn't copy"): an addon cannot put text on the clipboard (CopyToClipboard is
-- protected: secure code only), so the button is named for what it does: it selects the string, and the hint then says which keys copy it.
local HINT = "Send Xaya a screenshot of this window, or press Select string, then Ctrl+C (Cmd+C on Mac), and paste the text to her."
local HINT_SELECTED = "The string is selected: now press Ctrl+C (Cmd+C on Mac) to copy it, then paste it to Xaya."
local win
local function BuildWindow()
    local f = CreateFrame("Frame", "XayaUIDebugReport", UIParent, "BackdropTemplate")
    local M, G = ns.UI_MARGIN or 10, ns.UI_GUTTER or 10
    f:SetSize(680, 460)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.06, 0.06, 0.07, 0.97)
    f:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", M, -M)
    f.title:SetText("XayaUI debug report")
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.hint:SetPoint("RIGHT", f, "RIGHT", -(M + 24), 0)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetText(HINT)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    -- the string row along the bottom: a one-line box with the string and the button
    local copy = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copy:SetSize(110, 24); copy:SetPoint("BOTTOMRIGHT", -M, M); copy:SetText("Select string")
    if ns.FlatButton then ns.FlatButton(copy, true) end
    local sbox = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    sbox:SetHeight(24)
    sbox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", M, M); sbox:SetPoint("RIGHT", copy, "LEFT", -G, 0)
    sbox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    sbox:SetBackdropColor(0, 0, 0, 0.5); sbox:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    sbox:SetFontObject(ChatFontNormal); sbox:SetTextInsets(6, 6, 0, 0)
    sbox:SetAutoFocus(false); sbox:SetMaxLetters(0)
    sbox:SetScript("OnEscapePressed", function() f:Hide() end)
    sbox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    -- a click inside the box would drop the selection: select it all again, so Ctrl+C always copies the whole string
    sbox:SetScript("OnMouseUp", function(self) self:HighlightText(); f.hint:SetText(HINT_SELECTED) end)
    copy:SetScript("OnClick", function() sbox:SetFocus(); sbox:HighlightText(); f.hint:SetText(HINT_SELECTED) end)
    f.str, f.copy = sbox, copy
    if ns.KeyFocusGuard then ns.KeyFocusGuard(sbox) end   -- (row 56) lets go of the keyboard: Enter / Esc / a click outside / hiding (core KeyCatch.lua)
    -- the summary
    local sf = CreateFrame("ScrollFrame", "XayaUIDebugReportScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", M, -50); sf:SetPoint("BOTTOMRIGHT", -(M + 22), M + 24 + G)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(680 - 2 * M - 30); eb:SetMaxLetters(0)
    -- (review R22) the summary is for reading and screenshots: no mouse, so a click never gives it the keyboard (PRINTSCREEN, typing
    -- into the report); the click reaches the window, which drags. The string box below stays the one to copy from.
    eb:EnableMouse(false)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    sf:SetScrollChild(eb)
    f.text = eb
    if ns.KeyFocusGuard then ns.KeyFocusGuard(eb) end   -- (row 56) lets go of the keyboard: Enter / Esc / a click outside / hiding (core KeyCatch.lua)
    if UISpecialFrames then table.insert(UISpecialFrames, "XayaUIDebugReport") end
    return f
end
function ns.ShowDebugReport()
    if not CreateFrame then return end
    win = win or BuildWindow()
    local d = ns.DebugReportData()
    win.text:SetText(ns.DebugReportText(d))
    win.str:SetText(ns.DebugReportString(d) or "")
    win.hint:SetText(HINT)
    win:Show()
    return win
end
function ns.DebugReportWindow() return win end   -- (tests)
