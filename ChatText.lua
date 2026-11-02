-------------------------------------------------------------------------------
-- ChatText.lua : Chat Reskin, phase 2 (message text features). Own code only.
--
-- Message text is edited in two places:
--   * chat message FILTERS (URL links, keyword and class-color highlighting, spam throttle, alert sounds, class cache),
--     run once per message even when several chat windows show it (the result is cached by line ID);
--   * a wrapper around each chat window's AddMessage (short / hidden channel names, timestamps, copy-line arrow, history).
-- MIDNIGHT SECRET VALUES: text the game marks as secret cannot be read or changed by addons. Such messages are passed through
-- untouched (no timestamp, no link, no history, no copy) and counted for /xui chat. That limit is the game's, not a choice.
-- UNTESTED in game. Pure text helpers (ns.ChatText.Stamp / Channels / Urls / Words) are checked offline.
-------------------------------------------------------------------------------
local addonName, ns = ...

local T = {}
ns.ChatText = T

local issecret = _G.issecretvalue or function() return false end
local classNames = {}      -- lower-case player name (with and without realm) -> class token
local stats = { secretSkipped = 0, filtered = 0, blocked = 0, stamped = 0, saved = 0, replayed = 0, soundsPlayed = 0 }
T.stats = stats
local errors = {}
local lineCache, lineCount = {}, 0
local throttle = {}
local soundUntil = 0

local function Store() return ns.chatDB end
local function On(s) return s and s.enabled and not (ns.ChatReskin_BlockedReason and ns.ChatReskin_BlockedReason()) end
local function Try(what, fn, ...)
    local ok, a, b = pcall(fn, ...)
    if not ok and not errors[what] then errors[what] = tostring(a) end
    return ok, a, b
end
function T.Errors() return errors end

local function Hex(r, g, b)
    return string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5))
end
local function Esc(s) return (tostring(s):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end

-------------------------------------------------------------------------------
-- Pure text helpers (no game calls except globals read with fallbacks)
-------------------------------------------------------------------------------
T.STAMP_FORMATS = {
    NONE = "None", ["%I:%M "] = "03:27", ["%I:%M:%S "] = "03:27:32", ["%I:%M %p "] = "03:27 PM", ["%I:%M:%S %p "] = "03:27:32 PM",
    ["%H:%M "] = "15:27", ["%H:%M:%S "] = "15:27:32",
}
T.STAMP_ORDER = { "NONE", "%I:%M ", "%I:%M:%S ", "%I:%M %p ", "%I:%M:%S %p ", "%H:%M ", "%H:%M:%S " }

-- "[15:27:32] " (with color) for a time stamp; returns "" for NONE.
function T.Stamp(fmt, when, useColor, r, g, b)
    if not fmt or fmt == "NONE" or fmt == "" then return "" end
    local ok, text = pcall(_G.date or os.date, fmt, when)
    if not ok or not text then return "" end
    text = text:gsub(" ", ""):gsub("AM", " AM"):gsub("PM", " PM")
    if useColor then return Hex(r, g, b) .. "[" .. text .. "]|r " end
    return "[" .. text .. "] "
end

local SHORT = { GUILD = "G", PARTY = "P", RAID = "R", OFFICER = "O", PARTY_LEADER = "PL", RAID_LEADER = "RL",
    INSTANCE_CHAT = "I", INSTANCE_CHAT_LEADER = "IL" }
local function Word(globalName)   -- "%s whispers: " -> "whispers" (the game's own localized word)
    local g = _G[globalName]
    return type(g) == "string" and g:match("%%s%s+([^%s:]+)") or nil
end

-- Short ([2. Trade - City] -> [2], [Guild] -> [G]) or hidden channel names, plus the shorter whisper / say / yell, AFK, DND and raid warning tags.
function T.Channels(msg, hide)
    msg = msg:gsub("|Hchannel:(.-)|h%[(.-)%]|h", function(link)
        if hide then return "" end
        local short = SHORT[link:upper()] or link:gsub("^channel:", "")
        return "|Hchannel:" .. link .. "|h[" .. short .. "]|h"
    end)
    for _, g in ipairs({ "CHAT_WHISPER_GET", "CHAT_SAY_GET", "CHAT_YELL_GET" }) do
        local w = Word(g) or ({ CHAT_WHISPER_GET = "whispers", CHAT_SAY_GET = "says", CHAT_YELL_GET = "yells" })[g]
        msg = msg:gsub("^(.-|h) " .. Esc(w), "%1")
    end
    local afk, dnd = _G.AFK or "AFK", _G.DND or "DND"
    msg = msg:gsub("<" .. Esc(afk) .. ">", "[|cffFF9900" .. afk .. "|r] "):gsub("<" .. Esc(dnd) .. ">", "[|cffFF3333" .. dnd .. "|r] ")
    if _G.RAID_WARNING then msg = msg:gsub("^%[" .. Esc(_G.RAID_WARNING) .. "%]", "[RW]") end
    return msg
end

-- Hide every hyperlink (and the text colored around it) behind a placeholder so word and URL scans never touch it.
local function Protect(text, store)
    local function hold(seg) store[#store + 1] = seg; return "\1" .. #store .. "\2" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x|H.-|h.-|h|r", hold)
    text = text:gsub("|H.-|h.-|h", hold)
    text = text:gsub("|T.-|t", hold)
    text = text:gsub("|A.-|a", hold)
    return text
end
local function Restore(text, store)
    for _ = 1, 3 do   -- links produced inside held segments are restored on the next pass
        text = text:gsub("\1(%d+)\2", function(i) return store[tonumber(i)] or "" end)
        if not text:find("\1", 1, true) then break end
    end
    return text
end

local URL_PATTERNS = {
    { "(%a[%w+.-]*://[^%s\1\2|]+)" },
    { "(www%.[%w_-]+%.[^%s\1\2|]+)" },
    { "([%w_%.%-]+@[%w_%-]+%.[%w_%.%-]+)" },
    { "(%f[%d]%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?:%d+)" },
    { "(%f[%d]%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?%f[%D])" },
}
-- [url] hyperlinks. Trailing punctuation stays outside the link.
function T.Urls(text)
    local store = {}
    text = Protect(text, store)
    local found = false
    for _, p in ipairs(URL_PATTERNS) do
        text = text:gsub(p[1], function(url)
            local trail = url:match("[%.,;:!%?%)]+$") or ""
            if trail ~= "" then url = url:sub(1, #url - #trail) end
            if url == "" then return nil end
            found = true
            store[#store + 1] = "|cffffffff[|Hxuiurl:" .. url .. "|h" .. url .. "|h]|r"
            return "\1" .. #store .. "\2" .. trail
        end)
    end
    return Restore(text, store), found
end

-- Highlight keywords (color) and class-color player names. kw: { [lowerword] = true }, classOf(lowerword) -> r, g, b or nil.
-- Returns text, keywordHit (true when a keyword was found).
function T.Words(text, kw, kwColor, classOf)
    local store = {}
    text = Protect(text, store)
    local hit = false
    text = text:gsub("(%S+)", function(tok)
        if tok:find("\1", 1, true) then return nil end
        local pre, core, post = tok:match("^(%p*)(.-)(%p*)$")
        if not core or core == "" then return nil end
        local low = core:lower()
        if kw and kw[low] then
            hit = true
            return pre .. Hex(kwColor[1], kwColor[2], kwColor[3]) .. core .. "|r" .. post
        end
        if classOf then
            local r, g, b = classOf(low)
            if r then return pre .. Hex(r, g, b) .. core .. "|r" .. post end
        end
        return nil
    end)
    return Restore(text, store), hit
end

-- Plain text for the copy window: raid icons -> {star}, other textures dropped, hyperlinks reduced to their text.
function T.CleanLine(text)
    text = text:gsub("|TInterface\\TargetingFrame\\UI%-RaidTargetingIcon_(%d+):0|t", function(n)
        local name = _G["RAID_TARGET_" .. n]
        return name and ("{" .. name:lower() .. "}") or ""
    end)
    text = text:gsub("(%s?)|T.-|t(%s?)", function(a, b) return (a ~= "" and a) or (b ~= "" and b) or "" end)
    text = text:gsub("(%s?)|A.-|a(%s?)", function(a, b) return (a ~= "" and a) or (b ~= "" and b) or "" end)
    text = text:gsub("|H(.-)|h(.-)|h", function(_, shown) return shown end)
    return text
end

-------------------------------------------------------------------------------
-- Classes of players seen (for colored mentions and tab colors)
-------------------------------------------------------------------------------
local function ClassColor(class)
    local tbl = (_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS)
    local c = tbl and class and tbl[class]
    if c then return c.r, c.g, c.b end
end
function T.ClassOf(lowerName)
    local class = classNames[lowerName]
    if class then return ClassColor(class) end
end
function T.ClassToken(name) return name and classNames[name:lower()] end

local function Learn(name, class)
    if not (name and class) or issecret(name) or issecret(class) then return end
    classNames[name:lower()] = class
    local short = name:match("^([^%-]+)%-")
    if short then classNames[short:lower()] = class end
end

local function LearnGUID(guid)
    if not guid or issecret(guid) or type(guid) ~= "string" or guid == "" then return end
    local ok, _, class, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
    if ok and class and name and name ~= "" then
        Learn(name, class)
        if realm and realm ~= "" then Learn(name .. "-" .. realm, class) end
    end
end

local function LearnRoster()
    local function unit(u)
        if UnitExists(u) and UnitIsPlayer(u) then
            local name, realm = UnitName(u)
            local _, class = UnitClass(u)
            if name then
                Learn(name, class)
                if realm and realm ~= "" then Learn(name .. "-" .. realm, class) end
            end
        end
    end
    unit("player")
    for i = 1, 4 do unit("party" .. i) end
    for i = 1, 40 do unit("raid" .. i) end
end

-------------------------------------------------------------------------------
-- Sounds ("source|value", chosen in the options with the same list the rules use)
-------------------------------------------------------------------------------
function T.PlayChoice(choice)
    if type(choice) ~= "string" or choice == "" then return end
    local source, value = choice:match("^([^|]+)|(.*)$")
    if not source then return end
    if ns.PlaySound then pcall(ns.PlaySound, { enabled = true, source = source, value = value, channel = "Master" }) end
    stats.soundsPlayed = stats.soundsPlayed + 1
end

local ALERT_OF_EVENT = {
    CHAT_MSG_WHISPER = "alertWHISPER", CHAT_MSG_BN_WHISPER = "alertWHISPER",
    CHAT_MSG_GUILD = "alertGUILD", CHAT_MSG_OFFICER = "alertOFFICER",
    CHAT_MSG_PARTY = "alertPARTY", CHAT_MSG_PARTY_LEADER = "alertPARTY",
    CHAT_MSG_RAID = "alertRAID", CHAT_MSG_RAID_LEADER = "alertRAID", CHAT_MSG_RAID_WARNING = "alertRAID",
    CHAT_MSG_INSTANCE_CHAT = "alertINSTANCE", CHAT_MSG_INSTANCE_CHAT_LEADER = "alertINSTANCE",
    CHAT_MSG_CHANNEL = "alertCHANNEL",
}
local THROTTLED_EVENTS = { CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_CHANNEL = true }

local keywordSet, keywordSrc
local function Keywords(s)
    local src = tostring(s.keywords or "")
    if src ~= keywordSrc then
        keywordSrc, keywordSet = src, {}
        for item in src:gmatch("[^,]+") do
            local word = item:gsub("^%s+", ""):gsub("%s+$", "")
            if word ~= "" then
                if word == "%MYNAME%" then word = UnitName("player") or word end
                keywordSet[word:lower()] = true
            end
        end
    end
    return keywordSet
end

local me
local function IsMe(author)
    me = me or (UnitName("player") or "")
    if not author or issecret(author) or type(author) ~= "string" then return false end
    return author == me or author:match("^([^%-]+)") == me
end

local function Decide(s, event, msg, author, ...)
    local res = { msg = msg }
    local guid = select(10, ...)
    LearnGUID(guid)
    local mine = IsMe(author)
    -- spam throttle: the same author repeating the same text inside the interval is dropped (own messages never)
    local interval = tonumber(s.throttleInterval) or 0
    if interval > 0 and THROTTLED_EVENTS[event] and not mine and type(author) == "string" and not issecret(author) then
        local key = author:upper() .. msg
        local now = GetTime()
        local last = throttle[key]
        if last and now - last <= interval then
            res.block = true
            stats.blocked = stats.blocked + 1
            return res
        end
        throttle[key] = now
        if next(throttle) and math.random() < 0.02 then   -- tidy now and then
            for k, t in pairs(throttle) do if now - t > interval then throttle[k] = nil end end
        end
    end
    local text = msg
    if s.url then local t2 = T.Urls(text); text = t2 end
    local alertOK = not mine and (GetTime() >= soundUntil) and not (s.noAlertInCombat and InCombatLockdown())
    local kwHit
    if s.keywordsOn ~= false or s.classColorMentions then
        local kw = s.keywordsOn ~= false and Keywords(s) or nil
        local color = { s.kwR or 0.3, s.kwG or 1, s.kwB or 0.3 }
        text, kwHit = T.Words(text, kw, color, s.classColorMentions and T.ClassOf or nil)
    end
    res.msg = text
    if alertOK then
        local key = ALERT_OF_EVENT[event]
        local chosen = key and s[key]
        if event == "CHAT_MSG_CHANNEL" then
            -- per named channel (General, Trade, ...): the part before " - " of the channel's base name; "Numbered channels" is the fallback
            local base = select(7, ...)
            if type(base) == "string" and not issecret(base) then
                base = base:match("^(.-)%s+%-%s") or base
                local per = type(s.alertChan) == "table" and s.alertChan[base]
                if per and per ~= "" then chosen = per end
            end
        end
        local choice = (kwHit and s.keywordSound ~= "" and s.keywordSound) or chosen
        if choice and choice ~= "" then
            soundUntil = GetTime() + 5
            T.PlayChoice(choice)
        end
    end
    if (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER") and s.flashClientIcon and _G.FlashClientIcon then
        pcall(_G.FlashClientIcon)
    end
    stats.filtered = stats.filtered + 1
    return res
end

local function Filter(_, event, msg, author, ...)
    local s = Store()
    if not On(s) then return false end
    if type(msg) ~= "string" then return false end
    if issecret(msg) then stats.secretSkipped = stats.secretSkipped + 1; return false end
    local lineID = select(9, ...)
    local res
    local cacheable = lineID and not issecret(lineID)
    if cacheable then res = lineCache[lineID] end
    if not res then
        local ok, r = pcall(Decide, s, event, msg, author, ...)
        res = ok and r or { msg = msg }
        if not ok and not errors.filter then errors.filter = tostring(r) end
        if cacheable then
            lineCount = lineCount + 1
            if lineCount > 200 then lineCache, lineCount = {}, 1 end
            lineCache[lineID] = res
        end
    end
    if res.block then return true end
    if res.msg ~= msg then return false, res.msg, author, ... end
    return false
end

local FILTER_EVENTS = { "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" }
local filtersAdded
local function AddFilters()
    if filtersAdded or not _G.ChatFrame_AddMessageEventFilter then return end
    filtersAdded = true
    for _, ev in ipairs(FILTER_EVENTS) do Try("addFilter", _G.ChatFrame_AddMessageEventFilter, ev, Filter) end
end

-------------------------------------------------------------------------------
-- History (the lines as displayed, saved per character; replayed once after login)
-------------------------------------------------------------------------------
local HIST_TYPE = {
    CHAT_MSG_WHISPER = "histWHISPER", CHAT_MSG_WHISPER_INFORM = "histWHISPER", CHAT_MSG_BN_WHISPER = "histWHISPER", CHAT_MSG_BN_WHISPER_INFORM = "histWHISPER",
    CHAT_MSG_GUILD = "histGUILD", CHAT_MSG_OFFICER = "histGUILD", CHAT_MSG_GUILD_ACHIEVEMENT = "histGUILD",
    CHAT_MSG_PARTY = "histPARTY", CHAT_MSG_PARTY_LEADER = "histPARTY",
    CHAT_MSG_RAID = "histRAID", CHAT_MSG_RAID_LEADER = "histRAID", CHAT_MSG_RAID_WARNING = "histRAID",
    CHAT_MSG_INSTANCE_CHAT = "histINSTANCE", CHAT_MSG_INSTANCE_CHAT_LEADER = "histINSTANCE",
    CHAT_MSG_CHANNEL = "histCHANNEL", CHAT_MSG_SAY = "histSAY", CHAT_MSG_YELL = "histYELL",
}
local function CharKey() return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "?") end
local function History(create)
    if not CueRulesDB then return nil end
    CueRulesDB.chatHistory = CueRulesDB.chatHistory or {}
    local k = CharKey()
    if create and not CueRulesDB.chatHistory[k] then CueRulesDB.chatHistory[k] = {} end
    return CueRulesDB.chatHistory[k]
end
function T.ClearHistory() if CueRulesDB and CueRulesDB.chatHistory then CueRulesDB.chatHistory[CharKey()] = {} end end

local function SaveLine(s, frame, body, r, g, b, event)
    if not s.chatHistory or T.replaying then return end
    local key = event and HIST_TYPE[event]
    if not key or s[key] == false then return end
    local h = History(true)
    if not h then return end
    local id = frame:GetID()
    local list = h[id]
    if not list then list = {}; h[id] = list end
    list[#list + 1] = { body, r or 1, g or 1, b or 1, time(), event }
    local cap = math.max(10, tonumber(s.historySize) or 100)
    while #list > cap do table.remove(list, 1) end
    stats.saved = stats.saved + 1
end

-------------------------------------------------------------------------------
-- AddMessage wrapper
-------------------------------------------------------------------------------
local ARROW = "|TInterface\\ChatFrame\\ChatFrameExpandArrow:12|t"
local function Edit(self, s, msg, r, g, b, id, accessID, typeID, event)
    if msg:match("^%s*$") then return msg end
    local body = msg
    if s.shortChannels or s.hideChannels then body = T.Channels(body, s.hideChannels) end
    SaveLine(s, self, body, r, g, b, event)
    local fmt = s.timeStampFormat
    if fmt and fmt ~= "NONE" then
        local when = T.replayTime
        if not when then
            if s.timeStampLocalTime then when = time()
            else
                local st = _G.C_DateAndTime and _G.C_DateAndTime.GetServerTimeLocal and _G.C_DateAndTime.GetServerTimeLocal()
                when = st or time()
            end
        end
        body = T.Stamp(fmt, when, s.useCustomTimeColor, s.timeR, s.timeG, s.timeB) .. body
        stats.stamped = stats.stamped + 1
    end
    if s.copyChatLines then body = "|Hxuicpl:" .. self:GetID() .. "|h" .. ARROW .. "|h " .. body end
    return body
end

local function Wrapped(self, msg, ...)
    local orig = self.xuiOrigAddMessage
    local s = Store()
    if On(s) and type(msg) == "string" then
        if issecret(msg) then
            stats.secretSkipped = stats.secretSkipped + 1
        else
            local ok, body = pcall(Edit, self, s, msg, ...)
            if ok and type(body) == "string" then msg = body
            elseif not ok and not errors.addMessage then errors.addMessage = tostring(body) end
        end
    end
    return orig(self, msg, ...)
end

local function Frames()
    local out = {}
    local names = _G.CHAT_FRAMES
    if type(names) == "table" and #names > 0 then
        for _, n in ipairs(names) do if _G[n] then out[#out + 1] = _G[n] end end
    else
        for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do if _G["ChatFrame" .. i] then out[#out + 1] = _G["ChatFrame" .. i] end end
    end
    return out
end
T.Frames = Frames

local function WrapFrame(f)
    if f.xuiOrigAddMessage or type(f.AddMessage) ~= "function" then return end
    f.xuiOrigAddMessage = f.AddMessage
    f.AddMessage = Wrapped
end

function T.Replay()
    local s = Store()
    if not On(s) or not s.chatHistory or T.replayed then return end
    T.replayed = true
    local h = History(false)
    if not h then return end
    T.replaying = true
    for _, f in ipairs(Frames()) do
        local list = h[f:GetID()]
        if list then
            for _, e in ipairs(list) do
                T.replayTime = e[5]
                Try("replay", f.AddMessage, f, e[1], e[2], e[3], e[4])
                stats.replayed = stats.replayed + 1
            end
        end
    end
    T.replayTime, T.replaying = nil, nil
end

-------------------------------------------------------------------------------
-- Hyperlinks: [url] and copy-line clicks, hover tooltips
-------------------------------------------------------------------------------
local function PutInEditBox(text)
    if not text or text == "" then return end
    local eb = _G.ChatEdit_ChooseBoxForSend and _G.ChatEdit_ChooseBoxForSend()
    if not eb then return end
    if not eb:IsShown() and _G.ChatEdit_ActivateChat then _G.ChatEdit_ActivateChat(eb) end
    eb:SetText("")
    eb:Insert(text)
    eb:HighlightText()
end

local function CopyLine(chatID)
    local chat = _G["ChatFrame" .. tostring(chatID)]
    if not chat or not chat.FindCharacterAndLineIndexAtCoordinate then return end
    local x, y = GetCursorPosition()
    local scale = chat:GetEffectiveScale()
    local _, index = chat:FindCharacterAndLineIndexAtCoordinate(x / scale, y / scale)
    local line = index and chat.visibleLines and chat.visibleLines[index]
    local msg = line and line.messageInfo and line.messageInfo.message
    if type(msg) ~= "string" or issecret(msg) then return end
    msg = T.CleanLine(msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    PutInEditBox(msg)
end

local function InstallLinkHandler()
    if T.linkHooked or not _G.ItemRefTooltip or type(_G.ItemRefTooltip.SetHyperlink) ~= "function" then return end
    T.linkHooked = true
    local orig = _G.ItemRefTooltip.SetHyperlink
    _G.ItemRefTooltip.SetHyperlink = function(self, link, ...)
        if type(link) == "string" and not issecret(link) then
            local kind = link:match("^(xui%a+):")
            if kind then
                local data = link:sub(#kind + 2)
                if kind == "xuiurl" then Try("urlClick", PutInEditBox, data)
                elseif kind == "xuicpl" then Try("copyLine", CopyLine, data) end
                pcall(self.Hide, self)
                return
            end
        end
        return orig(self, link, ...)
    end
end

local HOVER_TYPES = { achievement = true, apower = true, currency = true, enchant = true, glyph = true, instancelock = true,
    item = true, keystone = true, quest = true, spell = true, talent = true, unit = true }
local hoverFrame
local function HookHover(f)
    if f.xuiHoverHooked then return end
    f.xuiHoverHooked = true
    f:HookScript("OnHyperlinkEnter", function(self, link)
        local s = Store()
        if not (On(s) and s.hyperlinkHover) or InCombatLockdown() or type(link) ~= "string" or issecret(link) then return end
        local kind = link:match("^([^:]+)")
        if HOVER_TYPES[kind] then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            pcall(GameTooltip.SetHyperlink, GameTooltip, link)
            GameTooltip:Show()
            hoverFrame = self
        end
    end)
    f:HookScript("OnHyperlinkLeave", function() if hoverFrame then hoverFrame = nil; GameTooltip:Hide() end end)
    f:HookScript("OnMouseWheel", function(self) if hoverFrame == self then hoverFrame = nil; GameTooltip:Hide() end end)
end

-------------------------------------------------------------------------------
-- Copy button and copy window
-------------------------------------------------------------------------------
local copyWin
local function BuildCopyWindow()
    if copyWin then return copyWin end
    local f = CreateFrame("Frame", "XayaUICopyChatFrame", UIParent, "BackdropTemplate")
    f:SetSize(700, 220)
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 6)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.04, 0.04, 0.04, 0.92)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    f:EnableMouse(true); f:SetMovable(true); f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(300, 120) end
    f:Hide()
    table.insert(_G.UISpecialFrames, "XayaUICopyChatFrame")
    f:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then self:StartMoving(); self.moving = true
        elseif btn == "RightButton" then self:StartSizing(); self.sizing = true end
    end)
    f:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing(); self.moving, self.sizing = nil, nil end)
    f:SetScript("OnHide", function(self) self:StopMovingOrSizing(); self.moving, self.sizing = nil, nil end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Copy chat   (drag to move, right-drag to resize; Ctrl+A, Ctrl+C to copy)")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local sf = CreateFrame("ScrollFrame", "XayaUICopyChatScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -28); sf:SetPoint("BOTTOMRIGHT", -28, 8)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetMaxLetters(0); eb:SetAutoFocus(false); eb:EnableMouse(true)
    eb:SetFontObject("ChatFontNormal")
    eb:SetWidth(sf:GetWidth())
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    sf:SetScrollChild(eb)
    sf:SetScript("OnSizeChanged", function(self, w) eb:SetWidth(w) end)
    f.edit, f.scroll = eb, sf
    copyWin = f
    return f
end

local function GetLines(frame)
    local lines = {}
    local skipped = 0
    local n = frame.GetNumMessages and frame:GetNumMessages() or 0
    for i = 1, n do
        local msg, r, g, b = frame:GetMessageInfo(i)
        if type(msg) == "string" and not issecret(msg) then
            lines[#lines + 1] = Hex(r or 1, g or 1, b or 1) .. T.CleanLine(msg) .. "|r"
        elseif msg ~= nil then
            skipped = skipped + 1
        end
    end
    return lines, skipped
end

function T.CopyChat(frame)
    local win = BuildCopyWindow()
    if win:IsShown() then win.edit:SetText(""); win:Hide() return end
    local lines, skipped = GetLines(frame)
    local text = table.concat(lines, " \n")
    if skipped > 0 then
        text = "(" .. skipped .. " protected line" .. (skipped == 1 and "" or "s") .. " cannot be copied: the game hides their text from addons.)\n" .. text
    end
    win.edit:SetText(text)
    win:Show()
    C_Timer.After(0, function()
        local _, mx = win.scroll.ScrollBar and win.scroll.ScrollBar:GetMinMaxValues()
        if mx and win.scroll.SetVerticalScroll then win.scroll:SetVerticalScroll(mx) end
    end)
end

local function EnsureCopyButton(f)
    if f.xuiCopy then return f.xuiCopy end
    local b = CreateFrame("Button", nil, f)
    b:SetSize(20, 22)
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -4)
    b:SetFrameLevel(f:GetFrameLevel() + 6)
    b.tex = b:CreateTexture(nil, "OVERLAY")
    b.tex:SetAllPoints()
    b.tex:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
    b:SetAlpha(0.35)
    b:SetScript("OnClick", function() local ok, err = pcall(T.CopyChat, f); if not ok and not errors.copy then errors.copy = tostring(err) end end)
    b:SetScript("OnEnter", function(self) self:SetAlpha(1); GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText("Copy chat"); GameTooltip:Show() end)
    b:SetScript("OnLeave", function(self) GameTooltip:Hide(); local s = Store(); self:SetAlpha((s and s.tabFadeUntilHover) and 0 or 0.35) end)
    f.xuiCopy = b
    return b
end

-------------------------------------------------------------------------------
-- Edit box: character count, /tt and /gr, saved history (own up / down handling)
-------------------------------------------------------------------------------
local function EditHistory(create)
    if not CueRulesDB then return nil end
    CueRulesDB.chatEditHistory = CueRulesDB.chatEditHistory or {}
    local k = CharKey()
    if create and not CueRulesDB.chatEditHistory[k] then CueRulesDB.chatEditHistory[k] = {} end
    return CueRulesDB.chatEditHistory[k]
end
function T.ClearEditHistory() if CueRulesDB and CueRulesDB.chatEditHistory then CueRulesDB.chatEditHistory[CharKey()] = {} end end

local function AddEditHistory(line)
    local s = Store()
    if not On(s) or not s.customEditHistory then return end
    if type(line) ~= "string" or issecret(line) then return end
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line == "" then return end
    local cmd = line:match("^/%w+")
    if cmd and _G.IsSecureCmd and _G.IsSecureCmd(cmd) then return end
    local h = EditHistory(true)
    for i, t in ipairs(h) do if t == line then table.remove(h, i) break end end
    h[#h + 1] = line
    while #h > (tonumber(s.editboxHistorySize) or 20) do table.remove(h, 1) end
end

local function GroupCommand()
    local _, instanceType = GetInstanceInfo()
    if instanceType == "pvp" then return "/bg " end
    if IsInRaid() then return "/ra " end
    if IsInGroup() then return "/p " end
    return "/s "
end

local function HookEditBox(eb)
    if eb.xuiTextHooked then return end
    eb.xuiTextHooked = true
    eb.xuiHistIndex = 0
    local count = eb:CreateFontString(nil, "ARTWORK")
    count:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    count:SetTextColor(0.75, 0.75, 0.75, 0.6)
    count:SetPoint("TOPRIGHT", eb, "TOPRIGHT", -5, 0)
    count:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", -5, 0)
    count:SetJustifyH("CENTER")
    eb.xuiCount = count
    eb:HookScript("OnTextChanged", function(self, userInput)
        local s = Store()
        if not On(s) then self.xuiCount:SetText(""); return end
        local text = self:GetText() or ""
        if issecret(text) then return end
        local len = #text
        if len == 4 and userInput then
            if text == "/tt " then
                local name, realm = UnitName("target")
                if name then
                    name = name:gsub("%s", "")
                    if realm and realm ~= "" then name = name .. "-" .. realm:gsub("[%s%-]", "") end
                    if _G.ChatFrame_SendTell then _G.ChatFrame_SendTell(name, self.chatFrame) end
                elseif _G.UIErrorsFrame then
                    _G.UIErrorsFrame:AddMessage("Invalid target", 1, 0.2, 0.2, 1)
                end
            elseif text == "/gr " then
                self:SetText(GroupCommand())
                if _G.ChatEdit_ParseText then _G.ChatEdit_ParseText(self, 0) end
            end
        end
        if s.characterCount then
            local link = 0
            text:gsub("(|c%x-|H.-|h).-|h|r", function(a) link = link + #a + 4 end)
            len = len - link
            self.xuiCount:SetText(len > 0 and (255 - len) or "")
        else
            self.xuiCount:SetText("")
        end
    end)
    eb:HookScript("OnKeyDown", function(self, key)
        local s = Store()
        if not (On(s) and s.customEditHistory) or (key ~= "UP" and key ~= "DOWN") then return end
        local h = EditHistory(false)
        if not h or #h == 0 then return end
        if key == "DOWN" then
            self.xuiHistIndex = self.xuiHistIndex - 1
            if self.xuiHistIndex < 1 then self.xuiHistIndex = 0; self:SetText(""); return end
        else
            self.xuiHistIndex = math.min(#h, self.xuiHistIndex + 1)
        end
        self:SetText((h[#h - (self.xuiHistIndex - 1)] or ""))
    end)
    eb:HookScript("OnEditFocusLost", function(self) self.xuiHistIndex = 0 end)
    if eb.AddHistoryLine then pcall(hooksecurefunc, eb, "AddHistoryLine", function(_, line) AddEditHistory(line) end) end
    eb:HookScript("OnEnterPressed", function(self)
        local s = Store()
        if On(s) and s.customEditHistory and self.ClearHistory then pcall(self.ClearHistory, self) end   -- own history replaces the game's
    end)
end

-------------------------------------------------------------------------------
-- Apply
-------------------------------------------------------------------------------
function T.Apply(s)
    if not On(s) then
        for _, f in ipairs(Frames()) do if f.xuiCopy then f.xuiCopy:Hide() end end
        return
    end
    AddFilters()
    Try("linkHandler", InstallLinkHandler)
    LearnRoster()
    for _, f in ipairs(Frames()) do
        Try("wrap", WrapFrame, f)
        Try("hover", HookHover, f)
        Try("copyButton", function()
            local b = EnsureCopyButton(f)
            b:SetShown(not s.hideCopyButton)
        end)
        local eb = f.editBox or _G[(f:GetName() or "") .. "EditBox"]
        if eb then Try("editBox", HookEditBox, eb) end
    end
    -- saved edit-box history -> each box's own up/down list is read from the saved list, nothing to preload
end

function T.Debug(say)
    say("chat text: filtered=" .. stats.filtered .. " blocked(spam)=" .. stats.blocked .. " stamped=" .. stats.stamped
        .. " history saved=" .. stats.saved .. " replayed=" .. stats.replayed .. " sounds=" .. stats.soundsPlayed
        .. " skipped(secret)=" .. stats.secretSkipped)
    local any
    for k, v in pairs(errors) do say("  chat text ERROR " .. k .. ": " .. v); any = true end
    if not any then say("  chat text: no errors recorded") end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UPDATE_CHAT_WINDOWS")
ev:SetScript("OnEvent", function(_, event)
    if event == "GROUP_ROSTER_UPDATE" then Try("roster", LearnRoster) return end
    if event == "PLAYER_LOGIN" then C_Timer.After(2, function() Try("replay", T.Replay) end) end
    C_Timer.After(0, function() local s = Store(); if s then T.Apply(s) end end)
end)
if _G.hooksecurefunc and _G.FCF_OpenTemporaryWindow then
    hooksecurefunc("FCF_OpenTemporaryWindow", function() C_Timer.After(0, function() local s = Store(); if s then T.Apply(s) end end) end)
end
