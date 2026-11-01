-------------------------------------------------------------------------------
-- ChatReskin.lua : ElvUI Chat Reskin (QoL feature). Phase 1: styling and behaviour of the
-- Blizzard chat frames. Own code only: it mirrors the OPTION SET of ElvUI's chat module,
-- written from scratch (ElvUI's licence reserves all rights; private modification only).
-- It never reads or edits message text in this phase, so Midnight "secret value" chat text is
-- not touched.
--
-- Phase 1: chat + tab fonts, buffer size, scroll step and auto-return, text fade, chat window
-- background colour/opacity, selected-tab colour, sticky chat, edit-box alt-key / history,
-- combat repeat guard, voice-button hiding.
-- NOT built yet (need message text + secret-value guards): timestamps, short/hidden channel
-- names, URL links, emotion/role icons, copy lines/button, class-coloured mentions, keyword and
-- channel alerts, spam throttle, chat history, BattleTag names, Quick Join messages, hyperlink
-- hover tooltips. NOT built (needs its own panel system): separate left/right panels, panel
-- textures, datatext panel anchors, tab selector arrow style.
-- UNTESTED in game. Same feature also exists in the Xaya-EUI plugin; only one may run (guard below).
-- /xui chat prints what this module found and applied.
-------------------------------------------------------------------------------
local addonName, ns = ...

-- Defaults seeded from Xaya's old ElvUI profile where she changed them (font size 15, outline,
-- tab size 15, panel colour 0,0,0 at 0.3157 opacity); otherwise ElvUI's own default values.
ns.CHAT_DEFAULTS = {
    enabled = false,
    font = "lsm:PT Sans Narrow", fontSize = 15, fontOutline = "outline",
    tabFont = "lsm:PT Sans Narrow", tabFontSize = 15, tabFontOutline = "shadow",
    maxLines = 100,
    numScrollMessages = 3, scrollDownInterval = 15,
    fade = true, inactivityTimer = 100,
    setWindowColor = false, winR = 0, winG = 0, winB = 0, winAlpha = 32,   -- alpha in percent
    tabSelectedTextEnabled = true, tabR = 1, tabG = 1, tabB = 1,
    sticky = true, useAltKey = false, editboxHistorySize = 20,
    enableCombatRepeat = true, numAllowedCombatRepeat = 5,
    hideVoiceButtons = false,
}

local CHAT_OUTLINE = { none = "None", outline = "Outline", thick = "Thick outline", shadow = "Shadow" }
local CHAT_OUTLINE_ORDER = { "none", "outline", "thick", "shadow" }
local STICKY_TYPES = { "SAY", "EMOTE", "YELL", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
    "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "WHISPER", "BN_WHISPER", "CHANNEL" }
local VOICE_BUTTONS = { "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }

local errors, applied = {}, {}   -- feature -> first error text / true when it ran
local hooked = {}                -- frame/global key -> true (each hook installed once)
local lastScroll = {}            -- chat frame -> GetTime() of the last mouse-wheel scroll
local ticker

local function Store()
    return ns.chatDB
end

-- Runs fn protected; remembers the first error per feature for /xui chat.
local function Try(feature, fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then
        if applied[feature] == nil then applied[feature] = true end
    else
        applied[feature] = false
        if not errors[feature] then errors[feature] = tostring(err) end
    end
    return ok
end

local function ChatFrames()
    local out = {}
    for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if f then out[#out + 1] = f end
    end
    return out
end
local function EditBoxOf(frame) return frame.editBox or _G[(frame:GetName() or "") .. "EditBox"] end
local function TabOf(frame) return frame.tab or _G[(frame:GetName() or "") .. "Tab"] end

-------------------------------------------------------------------------------
-- Guard: never run on top of another chat skin
-------------------------------------------------------------------------------
local function IsLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) and true or false end
    return IsAddOnLoaded and IsAddOnLoaded(name) and true or false
end

function ns.ChatReskin_BlockedReason()
    if IsLoaded("EllesmereUIChat") then
        return "EllesmereUIChat is loaded. Disable it in the AddOn list and reload."
    end
    if IsLoaded("ElvUI") then
        local ok, enabled = pcall(function()
            local E = _G.ElvUI and _G.ElvUI[1]
            return E and E.private and E.private.chat and E.private.chat.enable
        end)
        if ok and enabled then return "ElvUI's chat module is on. Turn it off in ElvUI (or disable ElvUI) and reload." end
    end
    -- the Xaya-EUI plugin has the same feature; only one copy may style the chat frames
    if IsLoaded("Xaya-EUI") and type(_G.XayaEUIDB) == "table" and type(_G.XayaEUIDB.chat) == "table" and _G.XayaEUIDB.chat.enabled then
        return "The ElvUI Chat Reskin in the Xaya-EUI plugin is on. Turn off one of the two and reload."
    end
    return nil
end

-------------------------------------------------------------------------------
-- Fonts
-------------------------------------------------------------------------------
local function Flags(mode)
    if mode == "outline" then return "OUTLINE" elseif mode == "thick" then return "THICKOUTLINE" end
    return ""
end

local function ApplyFonts(s)
    local path, flags = ns.FontPath(s.font), Flags(s.fontOutline)
    local tpath, tflags = ns.FontPath(s.tabFont), Flags(s.tabFontOutline)
    for _, f in ipairs(ChatFrames()) do
        Try("chatFont", function()
            f:SetFont(path, s.fontSize, flags)
            if s.fontOutline == "shadow" then f:SetShadowOffset(1, -1) else f:SetShadowOffset(0, 0) end
        end)
        Try("editBoxFont", function()
            local eb = EditBoxOf(f)
            if not eb then return end
            eb:SetFont(path, s.fontSize, flags)
            local header = eb.header or _G[(eb:GetName() or "") .. "Header"]
            if header then header:SetFont(path, s.fontSize, flags) end
        end)
        Try("tabFont", function()
            local tab = TabOf(f)
            local text = tab and (tab.Text or _G[(tab:GetName() or "") .. "Text"])
            if not text then return end
            text:SetFont(tpath, s.tabFontSize, tflags)
            if s.tabFontOutline == "shadow" then text:SetShadowOffset(1, -1) else text:SetShadowOffset(0, 0) end
        end)
    end
end

-------------------------------------------------------------------------------
-- Buffer, scrolling, fade
-------------------------------------------------------------------------------
local function ScrollHook(f)
    if hooked[f] then return end
    hooked[f] = true
    f:HookScript("OnMouseWheel", function(self, delta)
        lastScroll[self] = GetTime()
        local s = Store()
        if not s or not s.enabled then return end
        local extra = (tonumber(s.numScrollMessages) or 3) - 1
        if extra < 1 or IsShiftKeyDown() or IsControlKeyDown() then return end
        for _ = 1, extra do
            if delta > 0 then self:ScrollUp() else self:ScrollDown() end
        end
    end)
end

local function ApplyBuffer(s)
    for _, f in ipairs(ChatFrames()) do
        Try("maxLines", function() f:SetMaxLines(s.maxLines) end)
        Try("scrollStep", ScrollHook, f)
        Try("fade", function()
            f:SetFading(s.fade and true or false)
            if s.fade then f:SetTimeVisible(s.inactivityTimer) end
        end)
    end
end

local function EnsureTicker(s)
    if ticker then ticker:Cancel() ticker = nil end
    local interval = tonumber(s.scrollDownInterval) or 0
    if not s.enabled or interval <= 0 then return end
    ticker = C_Timer.NewTicker(1, function()
        local now = GetTime()
        for f, t in pairs(lastScroll) do
            if now - t >= interval and f.AtBottom and not f:AtBottom() then
                f:ScrollToBottom()
                lastScroll[f] = now
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Window background, tabs, edit box, voice buttons
-------------------------------------------------------------------------------
local function ApplyWindow(s)
    if not s.setWindowColor then return end
    for _, f in ipairs(ChatFrames()) do
        Try("windowColor", function()
            -- Blizzard's own functions: they also save the colour in Blizzard's chat settings.
            if _G.FCF_SetWindowColor then _G.FCF_SetWindowColor(f, s.winR, s.winG, s.winB) end
            if _G.FCF_SetWindowAlpha then _G.FCF_SetWindowAlpha(f, (s.winAlpha or 32) / 100) end
        end)
    end
end

local function UpdateTabColors()
    local s = Store()
    if not s or not s.enabled or not s.tabSelectedTextEnabled then return end
    for _, f in ipairs(ChatFrames()) do
        Try("tabColor", function()
            local tab = TabOf(f)
            local text = tab and (tab.Text or _G[(tab:GetName() or "") .. "Text"])
            if not text then return end
            local selected = _G.FCFDock_GetSelectedWindow and _G.GENERAL_CHAT_DOCK
                and _G.FCFDock_GetSelectedWindow(_G.GENERAL_CHAT_DOCK) == f
            if selected then text:SetTextColor(s.tabR, s.tabG, s.tabB) end
        end)
    end
end

local function InstallGlobalHooks()
    local function hook(name, fn)
        if hooked[name] or type(_G[name]) ~= "function" then return end
        hooked[name] = true
        hooksecurefunc(name, fn)
    end
    hook("FCFTab_UpdateColors", function() C_Timer.After(0, UpdateTabColors) end)
    hook("FCFDock_SelectWindow", function() C_Timer.After(0, UpdateTabColors) end)
    hook("FCF_SetChatWindowFontSize", function() C_Timer.After(0, ns.ChatReskin_Refresh) end)
end

local function RepeatRun(text)
    local n, last = #text, text:sub(-1)
    if n == 0 then return 0 end
    local run = 1
    for i = n - 1, 1, -1 do
        if text:sub(i, i) == last then run = run + 1 else break end
    end
    return run
end

local function ApplyEditBox(s)
    if s.sticky and _G.ChatTypeInfo then
        Try("sticky", function()
            for _, t in ipairs(STICKY_TYPES) do
                if _G.ChatTypeInfo[t] then _G.ChatTypeInfo[t].sticky = 1 end
            end
        end)
    end
    for _, f in ipairs(ChatFrames()) do
        local eb = EditBoxOf(f)
        if eb then
            Try("altKey", function() eb:SetAltArrowKeyMode(s.useAltKey and true or false) end)
            Try("editHistory", function() eb:SetHistoryLines(s.editboxHistorySize) end)
            Try("combatRepeat", function()
                if hooked[eb] then return end
                hooked[eb] = true
                eb:HookScript("OnTextChanged", function(self, userInput)
                    local c = Store()
                    if not userInput or not c or not c.enabled or not c.enableCombatRepeat then return end
                    if not UnitAffectingCombat("player") then return end
                    if RepeatRun(self:GetText() or "") > (tonumber(c.numAllowedCombatRepeat) or 5) then
                        self:SetText("")
                        if _G.ChatEdit_DeactivateChat then _G.ChatEdit_DeactivateChat(self) else self:ClearFocus() end
                    end
                end)
            end)
        end
    end
end

local function ApplyVoice(s)
    if not s.hideVoiceButtons then return end
    for _, name in ipairs(VOICE_BUTTONS) do
        local b = _G[name]
        if b then Try("voiceButtons", function() b:SetAlpha(0); b:EnableMouse(false) end) end
    end
end

-------------------------------------------------------------------------------
-- Refresh + events
-------------------------------------------------------------------------------
function ns.ChatReskin_Refresh()
    local s = Store()
    if not s or not s.enabled then
        if ticker then ticker:Cancel() ticker = nil end
        return
    end
    if ns.ChatReskin_BlockedReason() then return end
    InstallGlobalHooks()
    ApplyFonts(s)
    ApplyBuffer(s)
    ApplyWindow(s)
    ApplyEditBox(s)
    ApplyVoice(s)
    UpdateTabColors()
    EnsureTicker(s)
end

function ns.ChatReskin_OnDBReady()
    CueRulesDB.chat = CueRulesDB.chat or {}
    ns.Merge(CueRulesDB.chat, ns.CHAT_DEFAULTS)
    ns.chatDB = CueRulesDB.chat
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("UPDATE_CHAT_WINDOWS")
driver:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
driver:SetScript("OnEvent", function() C_Timer.After(0, ns.ChatReskin_Refresh) end)

-- /xui chat
function ns.ChatReskin_Debug()
    local say = ns.Print
    local s = Store()
    if not s then say("chat: saved settings not ready yet.") return end
    say("chat: enabled=" .. tostring(s.enabled) .. "  blocked=" .. tostring(ns.ChatReskin_BlockedReason() or "no"))
    say("chat: frames found=" .. #ChatFrames() .. "  font path=" .. tostring(ns.FontPath(s.font)))
    say("chat: FCF_SetWindowColor=" .. tostring(type(_G.FCF_SetWindowColor) == "function")
        .. " FCFTab_UpdateColors=" .. tostring(type(_G.FCFTab_UpdateColors) == "function")
        .. " FCFDock_SelectWindow=" .. tostring(type(_G.FCFDock_SelectWindow) == "function")
        .. " GENERAL_CHAT_DOCK=" .. tostring(_G.GENERAL_CHAT_DOCK ~= nil))
    for feature, ok in pairs(applied) do
        say("  " .. feature .. ": " .. (ok and "ran" or ("ERROR " .. tostring(errors[feature]))))
    end
    if next(applied) == nil then say("  (nothing applied yet: module off, blocked, or no refresh yet)") end
end

-------------------------------------------------------------------------------
-- Options page (tab "QoL UI Updates" > left tree entry "ElvUI Chat Reskin")
-------------------------------------------------------------------------------
function ns.BuildChatTab(Notify)
    local s = ns.chatDB
    if not s then return nil end
    local function Re() ns.ChatReskin_Refresh(); if Notify then Notify() end end
    local function tog(name, field, order, desc)
        return { type = "toggle", name = name, desc = desc, order = order, width = "double",
            get = function() return s[field] and true or false end,
            set = function(_, v) s[field] = v and true or false; Re() end }
    end
    local function rng(name, field, order, min, max, desc)
        return { type = "range", name = name, desc = desc, order = order, min = min, max = max, step = 1,
            get = function() return s[field] end, set = function(_, v) s[field] = v; Re() end }
    end
    local function fontSel(name, field, order)
        return { type = "select", name = name, order = order,
            values = function() local v = ns.FontList(); return v end,
            sorting = function() local _, o = ns.FontList(); return o end,
            get = function() return s[field] end, set = function(_, v) s[field] = v; Re() end }
    end
    local function outSel(name, field, order)
        return { type = "select", name = name, order = order, values = CHAT_OUTLINE, sorting = CHAT_OUTLINE_ORDER,
            get = function() return s[field] end, set = function(_, v) s[field] = v; Re() end }
    end
    local function col(name, rf, gf, bf, order)
        return { type = "color", name = name, order = order, hasAlpha = false,
            get = function() return s[rf], s[gf], s[bf], 1 end,
            set = function(_, r, g, b) s[rf], s[gf], s[bf] = r, g, b; Re() end }
    end
    -- One entry in the left tree of the "QoL UI Updates" tab (built in Options.lua); its four sections are tabs in the right pane.
    local chatReskin = {
        type = "group", name = "ElvUI Chat Reskin", order = 1, childGroups = "tab",
        args = {
            general = { type = "group", name = "General", order = 1, args = {
                blocked = { type = "description", order = 1, width = "full", fontSize = "medium",
                    hidden = function() return ns.ChatReskin_BlockedReason() == nil end,
                    name = function() return "|cffff5555Blocked:|r " .. tostring(ns.ChatReskin_BlockedReason()) end },
                intro = { type = "description", order = 2, width = "full",
                    name = "Brings ElvUI's chat options to the normal Blizzard chat frames. Phase 1 changes looks and behaviour only; it does not read or change message text. Turning it off fully takes effect after /reload. /xui chat shows what ran." },
                enabled = tog("Enable ElvUI Chat Reskin", "enabled", 3),
                hideVoice = tog("Hide voice chat buttons", "hideVoiceButtons", 4),
                notBuilt = { type = "description", order = 9, width = "full", fontSize = "small",
                    name = "|cffaaaaaaNot built yet:|r timestamps, short/hidden channel names, URL links, emotion and role icons, copy lines/button, class-coloured mentions, keyword and channel alerts, spam throttle, chat history, BattleTag names, Quick Join messages, hyperlink hover tooltips (they need message text and secret-value guards); separate left/right panels, panel textures, datatext panel anchors, tab selector arrow (they need a panel system)." },
            } },
            fonts = { type = "group", name = "Fonts & Tabs", order = 2, args = {
                font = fontSel("Chat font", "font", 1), fontSize = rng("Chat font size", "fontSize", 2, 6, 40),
                fontOutline = outSel("Chat font outline", "fontOutline", 3),
                tabFont = fontSel("Tab font", "tabFont", 4), tabFontSize = rng("Tab font size", "tabFontSize", 5, 6, 40),
                tabFontOutline = outSel("Tab font outline", "tabFontOutline", 6),
                tabSel = tog("Colorize selected tab text", "tabSelectedTextEnabled", 7),
                tabCol = col("Selected tab text color", "tabR", "tabG", "tabB", 8),
            } },
            scroll = { type = "group", name = "Scrolling & Fade", order = 3, args = {
                maxLines = rng("Max lines", "maxLines", 1, 10, 5000),
                step = rng("Scroll messages per step", "numScrollMessages", 2, 1, 12),
                back = rng("Scroll back down after (seconds, 0 = off)", "scrollDownInterval", 3, 0, 120),
                fade = tog("Fade chat text when inactive", "fade", 4),
                timer = rng("Inactivity timer (seconds)", "inactivityTimer", 5, 10, 600),
            } },
            window = { type = "group", name = "Window & Edit Box", order = 4, args = {
                bgNote = { type = "description", order = 1, width = "full",
                    name = "The background uses Blizzard's own chat window colour, which Blizzard saves; turning this off does not reset it (change it back in Blizzard's chat settings)." },
                bg = tog("Set chat window background", "setWindowColor", 2),
                bgCol = col("Backdrop color", "winR", "winG", "winB", 3),
                bgAlpha = rng("Backdrop opacity (%)", "winAlpha", 4, 0, 100),
                editHeader = { type = "header", name = "Edit box", order = 10 },
                sticky = tog("Sticky chat", "sticky", 11, "Keep the last chat channel when the edit box opens again."),
                alt = tog("Use Alt key for cursor movement", "useAltKey", 12),
                hist = rng("Edit box history", "editboxHistorySize", 13, 5, 50),
                repHeader = { type = "header", name = "Combat repeat", order = 20 },
                rep = tog("Close edit box on repeated characters in combat", "enableCombatRepeat", 21),
                repN = rng("Repeats allowed", "numAllowedCombatRepeat", 22, 1, 20),
            } },
        },
    }
    return chatReskin
end
