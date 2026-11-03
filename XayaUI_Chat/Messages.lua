-------------------------------------------------------------------------------
-- Chat/Messages.lua : what happens to messages. (1) Spam filters: repeat suppression and your blocked-phrase list, as ordinary game
-- chat filters. (2) Links: web addresses become clickable and open a box with the address selected for Ctrl+C; Ctrl + right-click on a
-- player's name ignores that player. (3) One shared message-event bus for the history and the per-tab sounds.
-- Text the game marks secret (Midnight, in restricted instance states) is NEVER read, filtered, or changed; /xui chat counts those.
-- Own code, written from the documented game API only. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local C = ns.Chat
local issecret = C.IsSecret
local function S() return ns.chat2 end

-- the message event bus ---------------------------------------------------------------------------------------------------------
C.MSG_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL" }
local handlers = {}
function C.OnMessage(fn) handlers[#handlers + 1] = fn end
local bus = CreateFrame("Frame")
for _, ev in ipairs(C.MSG_EVENTS) do pcall(bus.RegisterEvent, bus, ev) end
bus:SetScript("OnEvent", function(_, event, ...)
    if not C.On() then return end
    local s = S()
    if s and s.fadeWake and C.Touch then C.Touch() end
    for i, fn in ipairs(handlers) do C.Try("message-handler-" .. i, fn, event, ...) end
end)

local function PlayerName()
    local n = UnitName and UnitName("player")
    return (n and not issecret(n)) and n or nil
end
local function IsMe(author)
    if type(author) ~= "string" or issecret(author) then return false end
    local me = PlayerName()
    return me ~= nil and (author == me or author:match("^([^%-]+)") == me)
end
C.IsMe = IsMe

-------------------------------------------------------------------------------
-- Spam filters
-------------------------------------------------------------------------------
local SPAM_KINDS = { SAY = true, YELL = true, CHANNEL = true, EMOTE = true, TEXT_EMOTE = true, WHISPER = true }

local cacheText, cacheList
local function Phrases(s)
    local t = s.spamPhrases or ""
    if t ~= cacheText then
        cacheText, cacheList = t, {}
        for line in (t .. "\n"):gmatch("(.-)[\r\n]") do
            local ph = line:gsub("^%s+", ""):gsub("%s+$", ""):lower()
            if #ph >= 2 then cacheList[#cacheList + 1] = ph end
        end
    end
    return cacheList
end

local function HasPhrase(s, lower)
    for _, ph in ipairs(Phrases(s)) do
        if s.spamWord then
            local pat = "%f[%w]" .. (ph:gsub("%p", "%%%0")) .. "%f[%W]"
            if lower:find(pat) then return true end
        elseif lower:find(ph, 1, true) then
            return true
        end
    end
    return false
end

local recent, recentN = {}, 0
local decided, decidedN = {}, 0

local function Decide(s, kind, msg, author)
    if not SPAM_KINDS[kind] then return false end
    if IsMe(author) then return false end
    local lower = msg:lower()
    if HasPhrase(s, lower) then return true end
    if s.spamRepeat and kind ~= "WHISPER" then
        local who = (type(author) == "string" and not issecret(author)) and author:lower() or "?"
        local key = who .. "\0" .. lower
        local now = GetTime()
        local t = recent[key]
        recent[key] = now
        recentN = recentN + 1
        if recentN > 400 then
            for k, v in pairs(recent) do if now - v > (tonumber(s.spamSeconds) or 30) then recent[k] = nil end end
            recentN = 0
        end
        if t and now - t < (tonumber(s.spamSeconds) or 30) then return true end
    end
    return false
end

-------------------------------------------------------------------------------
-- Links
-------------------------------------------------------------------------------
local links, nextLink = {}, 1
local function RegisterUrl(url)
    local id = nextLink
    nextLink = nextLink + 1
    links[id] = url
    links[id - 200] = nil
    return id
end
function C.LinkTarget(id) return links[tonumber(id) or 0] end

local function Hex(r, g, b) return string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5)) end

function C.Linkify(s, msg)
    if not (msg:find("://", 1, true) or msg:find("www.", 1, true)) then return msg end
    local parts = {}
    local function keep(piece) parts[#parts + 1] = piece; return "\1" .. #parts .. "\2" end
    local text = msg:gsub("(|H.-|h.-|h)", keep)            -- existing hyperlinks stay as they are
    local color = Hex(s.linkR, s.linkG, s.linkB)
    local function wrap(url)
        local trail = url:match("[%.,;:!%?%)'\"]+$") or ""
        if trail ~= "" then url = url:sub(1, #url - #trail) end
        if #url < 4 then return url .. trail end
        return keep(color .. "|Haddon:XayaUI:url:" .. RegisterUrl(url) .. "|h[" .. url .. "]|h|r") .. trail
    end
    text = text:gsub("(https?://[%w_%-%.~%%:/%?#%[%]@!%$&'%*%+,;=%(%)]+)", wrap)
    text = text:gsub("(www%.[%w_%-%.]+%.%a%a+[%w_%-%./%?#%%&=~:@%+,;]*)", wrap)
    text = text:gsub("\1(%d+)\2", function(i) return parts[tonumber(i)] end)
    text = text:gsub("\1(%d+)\2", function(i) return parts[tonumber(i)] end)   -- wrapped links hold placeholders of their own
    return text
end

local function Filter(_, event, msg, author, ...)
    local s = S()
    if not (s and C.On()) then return false end
    if type(msg) ~= "string" then return false end
    if issecret(msg) then C.stats.protected = C.stats.protected + 1; return false end
    local kind = event:match("^CHAT_MSG_(.+)$") or event
    local lineID = select(9, ...)
    local verdict
    if type(lineID) == "number" and not issecret(lineID) then verdict = decided[lineID] end
    if verdict == nil then
        verdict = Decide(s, kind, msg, author)
        if verdict then C.stats.suppressed = C.stats.suppressed + 1 end
        if type(lineID) == "number" and not issecret(lineID) then
            decided[lineID] = verdict; decidedN = decidedN + 1
            if decidedN > 600 then decided, decidedN = {}, 0 end
        end
    end
    if verdict then return true end
    if s.links then
        local new = C.Linkify(s, msg)
        if new ~= msg then return false, new, author, ... end
    end
    return false
end
C.Filter = Filter

local function Install()
    if C.hooked.filters then return end
    local add = ns.Compat.Chat("AddMessageEventFilter")   -- ChatFrameUtil.AddMessageEventFilter in 12.x (Compat.lua)
    if not add then return end
    for _, ev in ipairs(C.MSG_EVENTS) do
        if ev ~= "CHAT_MSG_WHISPER_INFORM" and ev ~= "CHAT_MSG_BN_WHISPER_INFORM" then pcall(add, ev, Filter) end
    end
    C.hooked.filters = true
end

-------------------------------------------------------------------------------
-- Clicks: copy a web address; Ctrl + right-click a name to ignore
-------------------------------------------------------------------------------
local copy
function C.CopyBox(text, title)
    if not copy then
        copy = CreateFrame("Frame", "XayaUIChatCopy", UIParent, "BackdropTemplate")
        copy:SetSize(460, 72); copy:SetPoint("CENTER", 0, 120); copy:SetFrameStrata("DIALOG")
        copy:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        copy:SetBackdropColor(0.04, 0.04, 0.06, 0.96); copy:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
        copy.title = copy:CreateFontString(nil, "OVERLAY"); copy.title:SetFont(STANDARD_TEXT_FONT, 12, ""); copy.title:SetPoint("TOPLEFT", 10, -8)
        copy.edit = CreateFrame("EditBox", nil, copy, "BackdropTemplate")
        copy.edit:SetPoint("TOPLEFT", 10, -28); copy.edit:SetPoint("BOTTOMRIGHT", -10, 10)
        copy.edit:SetFont(STANDARD_TEXT_FONT, 13, ""); copy.edit:SetAutoFocus(false)
        copy.edit:SetScript("OnEscapePressed", function() copy:Hide() end)
        copy.edit:SetScript("OnEnterPressed", function() copy:Hide() end)
        copy.edit:SetScript("OnTextChanged", function(self, user) if user and copy.text then self:SetText(copy.text); self:HighlightText() end end)
        if _G.UISpecialFrames then table.insert(_G.UISpecialFrames, "XayaUIChatCopy") end
        copy:Hide()
    end
    copy.text = text
    copy.title:SetText(title or "Press Ctrl+C to copy, then Escape")
    copy.edit:SetText(text or "")
    copy:Show()
    copy.edit:SetFocus(); copy.edit:HighlightText()
end

local function OnItemRef(link, text, button)
    if type(link) ~= "string" or issecret(link) then return end
    local s = S()
    if not (s and C.On()) then return end
    local a, addon, kind, id = strsplit(":", link)
    if a == "addon" and addon == "XayaUI" and kind == "url" then
        local url = C.LinkTarget(id)
        if url then C.CopyBox(url, "Web address: press Ctrl+C to copy it, then Escape") end
        return
    end
    if s.ignoreClick and a == "player" and button == "RightButton" and IsControlKeyDown and IsControlKeyDown() then
        local name = strsplit(":", link:sub(8))
        if name and name ~= "" and not IsMe(name) and C_FriendList and C_FriendList.AddIgnore then
            pcall(C_FriendList.AddIgnore, name)
            ns.Print("Ignoring " .. name .. " (Ctrl + right-click). Remove them in the social window's Ignore list.")
        end
    end
end

local function Refresh()
    if not C.On() then return end
    Install()
    C.HookOnce("messages:itemref", "SetItemRef", nil, OnItemRef)
end
C.Register("messages", Refresh)
