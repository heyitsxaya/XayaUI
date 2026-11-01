-------------------------------------------------------------------------------
-- ChatReskin.lua : ElvUI Chat Reskin (QoL feature): styling and behavior of the Blizzard chat frames.
-- Own code only: it mirrors the OPTION SET of ElvUI's chat module, written from scratch (ElvUI's
-- license reserves all rights; private modification only).
--
-- This file: fonts, buffer size, scroll step and auto-return, text fade, window background, sticky chat, edit box (alt key, history,
-- position), combat repeat guard, voice-button hiding, the options page, and the shared refresh / events.
-- ChatTabs.lua: tab art, selector, colors, fade. ChatText.lua: timestamps, channel names, URLs, mentions, keywords, alerts, spam
-- throttle, history, copy button / window / lines, hyperlink hover, edit-box extras (character count, /tt, /gr).
-- Message text the game marks secret (Midnight) is never touched; /xui chat counts those lines.
-- NOT built: emotion icons (TwitchEmotes does that), role / mentorship / timerunning icons, Battle.net tag names, Quick Join messages,
-- ElvUI's own left / right chat panels (separate sizes, snapping, textures, datatext anchors, voice panel pin / fade).
-- UNTESTED in game. Same feature also exists in the Xaya-EUI plugin; only one may run (guard below).
-- /xui chat prints what this module found and applied.
-------------------------------------------------------------------------------
local addonName, ns = ...

-- Defaults seeded from Xaya's old ElvUI profile where she changed them (font size 15, outline,
-- tab size 15, panel color 0,0,0 at 0.3157 opacity); otherwise ElvUI's own default values.
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
    -- tabs
    tabSelector = "ARROW1", tabSelR = 0.3, tabSelG = 1, tabSelB = 0.3,
    tabTextR = 0.75, tabTextG = 0.75, tabTextB = 0.75, tabClassWhispers = true, tabDimInactive = true,
    tabBackdrop = true, tabBgR = 0, tabBgG = 0, tabBgB = 0, tabBgAlpha = 45,
    tabBgSelR = 0.18, tabBgSelG = 0.18, tabBgSelB = 0.18, tabBgSelAlpha = 80,
    tabFadeUntilHover = false, tabHeight = 22,
    -- message text (timestamp format seeded from Xaya's old ElvUI profile)
    timeStampFormat = "%H:%M:%S ", timeStampLocalTime = false, useCustomTimeColor = true, timeR = 0.7, timeG = 0.7, timeB = 0.7,
    shortChannels = true, hideChannels = false, url = true, hyperlinkHover = true,
    copyChatLines = false, hideCopyButton = false, classColorMentions = true,
    -- alerts
    keywordsOn = true, keywords = "%MYNAME%", keywordSound = "", kwR = 0.3, kwG = 1, kwB = 0.3,
    alertWHISPER = "", alertGUILD = "", alertOFFICER = "", alertPARTY = "", alertRAID = "", alertINSTANCE = "", alertCHANNEL = "",
    noAlertInCombat = false, flashClientIcon = true,
    -- history and spam
    chatHistory = true, historySize = 100, throttleInterval = 45,
    histWHISPER = true, histGUILD = true, histPARTY = true, histRAID = true, histINSTANCE = true, histCHANNEL = true, histSAY = true, histYELL = true,
    -- edit box
    editBoxPosition = "DEFAULT", characterCount = true, customEditHistory = true,
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
    local names = _G.CHAT_FRAMES   -- includes whisper windows opened later
    if type(names) == "table" and #names > 0 then
        for _, n in ipairs(names) do if _G[n] then out[#out + 1] = _G[n] end end
    else
        for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
            local f = _G["ChatFrame" .. i]
            if f then out[#out + 1] = f end
        end
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
            -- Blizzard's own functions: they also save the color in Blizzard's chat settings.
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

local function PlaceEditBox(eb, f, pos)
    eb:ClearAllPoints()
    if pos == "BELOW_CHAT" then
        eb:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -2, -5)
        eb:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 2, -5)
    elseif pos == "ABOVE_CHAT" then
        eb:SetPoint("BOTTOMLEFT", f, "TOPLEFT", -2, 5)
        eb:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 2, 5)
    end
end

-- Edit box above / below the chat. "Default" leaves Blizzard's own placement alone. The game re-anchors the box whenever it opens,
-- so the position is applied again on activation.
local function ApplyEditBoxPosition(s)
    local pos = s.editBoxPosition
    if pos ~= "BELOW_CHAT" and pos ~= "ABOVE_CHAT" then return end
    for _, f in ipairs(ChatFrames()) do
        local eb = EditBoxOf(f)
        if eb then Try("editBoxPosition", PlaceEditBox, eb, f, pos) end
    end
    if not hooked.editActivate and type(_G.ChatEdit_ActivateChat) == "function" then
        hooked.editActivate = true
        hooksecurefunc("ChatEdit_ActivateChat", function(eb)
            local c = Store()
            if not (c and c.enabled) or (c.editBoxPosition ~= "BELOW_CHAT" and c.editBoxPosition ~= "ABOVE_CHAT") then return end
            local f = eb and (eb.chatFrame or eb:GetParent())
            if f then pcall(PlaceEditBox, eb, f, c.editBoxPosition) end
        end)
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
    ApplyEditBoxPosition(s)
    ApplyVoice(s)
    UpdateTabColors()
    if ns.ChatText and ns.ChatText.Apply then Try("chatText", ns.ChatText.Apply, s) end
    if ns.ChatTabs and ns.ChatTabs.Apply then Try("chatTabs", ns.ChatTabs.Apply, s) end
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
    if ns.ChatText and ns.ChatText.Debug then ns.ChatText.Debug(say) end
    if ns.ChatTabs and ns.ChatTabs.Debug then ns.ChatTabs.Debug(say) end
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
    local function sel(name, field, order, values, sorting, desc, width)
        return { type = "select", name = name, desc = desc, order = order, values = values, sorting = sorting, width = width,
            get = function() return s[field] end, set = function(_, v) s[field] = v; Re() end }
    end
    local function colA(name, field, order, desc)   -- color stored as three fields: <field>R / G / B
        return { type = "color", name = name, desc = desc, order = order, hasAlpha = false,
            get = function() return s[field .. "R"], s[field .. "G"], s[field .. "B"], 1 end,
            set = function(_, r, g, b) s[field .. "R"], s[field .. "G"], s[field .. "B"] = r, g, b; Re() end }
    end
    local soundCache
    local function SoundChoices()
        if not soundCache then
            local values, order = { [""] = "(none)" }, { "" }
            for _, e in ipairs((ns.BuildSoundList and ns.BuildSoundList()) or {}) do
                local k = tostring(e.source) .. "|" .. tostring(e.value)
                if not values[k] then values[k] = e.label; order[#order + 1] = k end
            end
            soundCache = { values, order }
        end
        return soundCache[1], soundCache[2]
    end
    local function soundSel(name, field, order)
        return { type = "select", name = name, order = order,
            values = function() local v = SoundChoices(); return v end,
            sorting = function() local _, o = SoundChoices(); return o end,
            get = function() return s[field] or "" end,
            set = function(_, v) s[field] = v; if v ~= "" and ns.ChatText then ns.ChatText.PlayChoice(v) end; Re() end }
    end
    local function txt(name, field, order, desc)
        return { type = "input", name = name, desc = desc, order = order, width = "full",
            get = function() return s[field] or "" end, set = function(_, v) s[field] = tostring(v or ""); Re() end }
    end
    local function note(text, order, small)
        return { type = "description", order = order, width = "full", fontSize = small and "small" or "medium", name = text }
    end
    local EDIT_POS = { DEFAULT = "Default (Blizzard's place)", BELOW_CHAT = "Below the chat", ABOVE_CHAT = "Above the chat" }
    local EDIT_POS_ORDER = { "DEFAULT", "BELOW_CHAT", "ABOVE_CHAT" }
    local TS = ns.ChatText and ns.ChatText.STAMP_FORMATS or {}
    local TSO = ns.ChatText and ns.ChatText.STAMP_ORDER or {}
    local TSEL = ns.ChatTabs or {}
    -- One entry in the left tree of the "QoL UI Updates" tab (built in Options.lua); its sections are tabs in the right pane.
    local chatReskin = {
        type = "group", name = "ElvUI Chat Reskin", order = 1, childGroups = "tab",
        args = {
            general = { type = "group", name = "General", order = 1, args = {
                blocked = { type = "description", order = 1, width = "full", fontSize = "medium",
                    hidden = function() return ns.ChatReskin_BlockedReason() == nil end,
                    name = function() return "|cffff5555Blocked:|r " .. tostring(ns.ChatReskin_BlockedReason()) end },
                intro = note("Brings ElvUI's chat options to the normal Blizzard chat frames. Turning it off fully takes effect after /reload. /xui chat shows what ran and any error.", 2),
                enabled = tog("Enable ElvUI Chat Reskin", "enabled", 3),
                hideVoice = tog("Hide voice chat buttons", "hideVoiceButtons", 4),
                secretNote = note("|cffaaaaaaProtected messages:|r the game marks some chat text (for example during boss encounters and inside some instances) as secret. Addons cannot read or change it, so such lines get no timestamp, link, color, history, or copy. This is a game limit, and /xui chat counts how many were skipped.", 8, true),
                notBuilt = note("|cffaaaaaaNot built:|r emotion icons (the TwitchEmotes addon does this), role / mentorship / timerunning icons, Battle.net tag names, Quick Join messages, and ElvUI's own left / right chat panels with their datatexts, panel textures, and panel sizes (they need a panel system of their own). Voice button pin / fade options are not built; hiding them is.", 9, true),
            } },
            fonts = { type = "group", name = "Fonts & Tabs", order = 2, args = {
                font = fontSel("Chat font", "font", 1), fontSize = rng("Chat font size", "fontSize", 2, 6, 40),
                fontOutline = outSel("Chat font outline", "fontOutline", 3),
                tabFont = fontSel("Tab font", "tabFont", 4), tabFontSize = rng("Tab font size", "tabFontSize", 5, 6, 40),
                tabFontOutline = outSel("Tab font outline", "tabFontOutline", 6),
                tabHeader = { type = "header", name = "Tabs", order = 10 },
                tabSel = tog("Colorize selected tab text", "tabSelectedTextEnabled", 11),
                tabCol = col("Selected tab text color", "tabR", "tabG", "tabB", 12),
                tabTextCol = col("Other tabs: text color", "tabTextR", "tabTextG", "tabTextB", 13),
                tabWhisper = tog("Whisper tabs in the player's class color", "tabClassWhispers", 14),
                tabDim = tog("Dim tabs that are not selected", "tabDimInactive", 15),
                tabSelector = sel("Selected tab marker", "tabSelector", 16, TSEL.STYLE_NAMES or {}, TSEL.STYLE_ORDER),
                tabSelCol = col("Selected tab marker color", "tabSelR", "tabSelG", "tabSelB", 17),
                tabBg = tog("Flat tab backgrounds (replaces Blizzard's tab art)", "tabBackdrop", 18),
                tabBgCol = col("Tab background color", "tabBgR", "tabBgG", "tabBgB", 19),
                tabBgAlpha = rng("Tab background opacity (%)", "tabBgAlpha", 20, 0, 100),
                tabBgSelCol = col("Selected tab background color", "tabBgSelR", "tabBgSelG", "tabBgSelB", 21),
                tabBgSelAlpha = rng("Selected tab background opacity (%)", "tabBgSelAlpha", 22, 0, 100),
                tabHeight = rng("Tab height", "tabHeight", 23, 16, 40),
                tabFade = tog("Show tab names and the copy button only while the mouse is over the chat or its tab", "tabFadeUntilHover", 24),
            } },
            text = { type = "group", name = "Text & Links", order = 3, args = {
                stampHeader = { type = "header", name = "Timestamps", order = 1 },
                stamp = sel("Timestamp format", "timeStampFormat", 2, TS, TSO, "None turns timestamps off."),
                stampLocal = tog("Use your computer's time (off: server time)", "timeStampLocalTime", 3),
                stampColorOn = tog("Color the timestamp", "useCustomTimeColor", 4),
                stampColor = col("Timestamp color", "timeR", "timeG", "timeB", 5),
                chanHeader = { type = "header", name = "Channel names", order = 10 },
                short = tog("Short channel names ([2. Trade - City] becomes [2], [Guild] becomes [G])", "shortChannels", 11),
                hide = tog("Hide channel names", "hideChannels", 12),
                linkHeader = { type = "header", name = "Links and mentions", order = 20 },
                url = tog("Make web addresses clickable (click puts the address in the edit box, selected for Ctrl+C)", "url", 21),
                hover = tog("Show a tooltip when the mouse is over an item, spell, quest, or achievement link", "hyperlinkHover", 22),
                mention = tog("Color player names in the class color when someone writes them", "classColorMentions", 23,
                    "Works for players seen in chat, in your group, or yourself."),
                copyHeader = { type = "header", name = "Copying", order = 30 },
                copyLines = tog("Arrow in front of each line: click it to put that line in the edit box", "copyChatLines", 31),
                hideCopy = tog("Hide the copy button", "hideCopyButton", 32,
                    "The copy button sits at the top right of each chat window and opens a window with the chat to copy."),
            } },
            alerts = { type = "group", name = "Alerts", order = 4, args = {
                kwOn = tog("Highlight keywords", "keywordsOn", 1),
                kw = txt("Keywords (separated by commas; %MYNAME% is your character's name)", "keywords", 2),
                kwCol = colA("Keyword color", "kw", 3),
                kwSound = soundSel("Keyword sound", "keywordSound", 4),
                chanHeader = { type = "header", name = "Sound when a message arrives", order = 10 },
                aWhisper = soundSel("Whisper", "alertWHISPER", 11),
                aGuild = soundSel("Guild", "alertGUILD", 12),
                aOfficer = soundSel("Officer", "alertOFFICER", 13),
                aParty = soundSel("Party", "alertPARTY", 14),
                aRaid = soundSel("Raid", "alertRAID", 15),
                aInstance = soundSel("Instance", "alertINSTANCE", 16),
                aChannel = soundSel("Numbered channels (General, Trade, ...)", "alertCHANNEL", 17),
                otherHeader = { type = "header", name = "Other", order = 20 },
                noCombat = tog("No alert sounds in combat", "noAlertInCombat", 21),
                flash = tog("Flash the game icon in the taskbar on a whisper", "flashClientIcon", 22),
                limit = note("At most one alert sound plays every five seconds. Own messages never play one.", 23, true),
            } },
            history = { type = "group", name = "History & Spam", order = 5, args = {
                on = tog("Keep chat history across /reload and relog", "chatHistory", 1, "Saves the lines as they were shown. Protected (secret) lines cannot be saved."),
                size = rng("Lines kept per chat window", "historySize", 2, 10, 500),
                types = { type = "header", name = "Keep these kinds of messages", order = 10 },
                hWhisper = tog("Whispers", "histWHISPER", 11), hGuild = tog("Guild and officer", "histGUILD", 12),
                hParty = tog("Party", "histPARTY", 13), hRaid = tog("Raid", "histRAID", 14),
                hInst = tog("Instance", "histINSTANCE", 15), hChan = tog("Numbered channels", "histCHANNEL", 16),
                hSay = tog("Say", "histSAY", 17), hYell = tog("Yell", "histYELL", 18),
                clear = { type = "execute", name = "Clear saved chat history", order = 20,
                    func = function() if ns.ChatText then ns.ChatText.ClearHistory() end end },
                spamHeader = { type = "header", name = "Spam", order = 30 },
                spam = rng("Hide repeats of the same message from the same player for (seconds, 0 = off)", "throttleInterval", 31, 0, 300,
                    "Say, yell, and numbered channels only. Your own messages are never hidden."),
            } },
            scroll = { type = "group", name = "Scroll & Fade", order = 6, args = {
                maxLines = rng("Max lines", "maxLines", 1, 10, 5000),
                step = rng("Scroll messages per step", "numScrollMessages", 2, 1, 12),
                back = rng("Scroll back down after (seconds, 0 = off)", "scrollDownInterval", 3, 0, 120),
                fade = tog("Fade chat text when inactive", "fade", 4),
                timer = rng("Inactivity timer (seconds)", "inactivityTimer", 5, 10, 600),
            } },
            window = { type = "group", name = "Window & Edit Box", order = 7, args = {
                bgNote = note("The background uses Blizzard's own chat window color, which Blizzard saves; turning this off does not reset it (change it back in Blizzard's chat settings).", 1),
                bg = tog("Set chat window background", "setWindowColor", 2),
                bgCol = col("Backdrop color", "winR", "winG", "winB", 3),
                bgAlpha = rng("Backdrop opacity (%)", "winAlpha", 4, 0, 100),
                editHeader = { type = "header", name = "Edit box", order = 10 },
                pos = sel("Edit box position", "editBoxPosition", 11, EDIT_POS, EDIT_POS_ORDER),
                sticky = tog("Sticky chat", "sticky", 12, "Keep the last chat channel when the edit box opens again."),
                alt = tog("Use Alt key for cursor movement", "useAltKey", 13),
                count = tog("Show characters left (of 255) in the edit box", "characterCount", 14),
                custom = tog("Remember typed lines across sessions (Up / Down browse them)", "customEditHistory", 15),
                hist = rng("Edit box history", "editboxHistorySize", 16, 5, 50),
                clearEdit = { type = "execute", name = "Clear saved typed lines", order = 17,
                    func = function() if ns.ChatText then ns.ChatText.ClearEditHistory() end end },
                cmds = note("Typing /tt and a space whispers your target; /gr and a space talks to your group (battleground, raid, party, or say).", 18, true),
                repHeader = { type = "header", name = "Combat repeat", order = 20 },
                rep = tog("Close edit box on repeated characters in combat", "enableCombatRepeat", 21),
                repN = rng("Repeats allowed", "numAllowedCombatRepeat", 22, 1, 20),
            } },
        },
    }
    return chatReskin
end
