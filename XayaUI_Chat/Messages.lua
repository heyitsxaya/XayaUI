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
local ALL = {}
for _, ev in ipairs(C.MSG_EVENTS) do ALL[ev] = true end
C.MSG_ALL = ALL
-- V14: the bus listens only for the events that a switched-on consumer needs (the history, the tab sounds, the whisper sound overrides,
-- "a new message brings the chat back"), and only while the Chat Panel is on. A consumer gives the set of events it wants for the
-- current settings; C.Refresh works the sets out again after every settings change (the "messages" part). With every consumer off, the
-- bus frame is never made. Up to Chat 0.6.13 all 18 events were registered at login, with the Chat Panel off too.
local handlers = {}
-- fn(event, ...) is called for the events that events(s) returns (a set; nil: none). events nil: every chat message event.
function C.OnMessage(fn, events)
    handlers[#handlers + 1] = { fn = fn, events = events or function() return ALL end, want = {} }
end
local bus, wake
local registered = {}
local function OnBusEvent(_, event, ...)
    if wake and C.Touch then C.Touch() end
    for i, h in ipairs(handlers) do
        if h.want[event] then C.Try("message-handler-" .. i, h.fn, event, ...) end
    end
end
local function SyncBus(s)
    wake = (s.fadeOn and s.fadeWake) and true or false
    local need = {}
    if wake then for ev in pairs(ALL) do need[ev] = true end end
    for _, h in ipairs(handlers) do
        h.want = h.events(s) or {}
        for ev in pairs(h.want) do need[ev] = true end
    end
    if not bus then
        if not next(need) then return end
        bus = CreateFrame("Frame")
        bus:SetScript("OnEvent", OnBusEvent)
    end
    for _, ev in ipairs(C.MSG_EVENTS) do
        if need[ev] and not registered[ev] then
            if pcall(bus.RegisterEvent, bus, ev) then registered[ev] = true end
        elseif registered[ev] and not need[ev] then
            pcall(bus.UnregisterEvent, bus, ev); registered[ev] = nil
        end
    end
end
C.Part("messages", function() return true end, SyncBus,
    function()
        wake = false
        for _, h in ipairs(handlers) do h.want = {} end
        if bus then for ev in pairs(registered) do pcall(bus.UnregisterEvent, bus, ev) end end
        registered = {}
    end, SyncBus)

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

-- "Match whole words only" (audit D37, Chat 0.6.31): a phrase matches where it is not part of a longer word. A side needs a word
-- boundary only when the phrase starts / ends with a letter or digit there; bytes of non-ASCII characters (Cyrillic, accents, ...)
-- count as letters. Before, %f[%w] / %f[%W] (ASCII only) meant "wts!", "$gold" and any Cyrillic phrase could never match.
local function WordByte(b) return b ~= nil and (b >= 128 or (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122)) end
local function WholeWord(lower, ph)
    local needL, needR = WordByte(ph:byte(1)), WordByte(ph:byte(#ph))
    local init = 1
    while true do
        local i, j = lower:find(ph, init, true)
        if not i then return false end
        if (not needL or not WordByte(lower:byte(i - 1))) and (not needR or not WordByte(lower:byte(j + 1))) then return true end
        init = i + 1
    end
end
ns.Chat_WholeWord = WholeWord
C.WholeWord = WholeWord   -- (for Dev Assist's QA walkthrough, through the "chatDebug" service: Core.lua)
local function HasPhrase(s, lower)
    for _, ph in ipairs(Phrases(s)) do
        if s.spamWord then
            if WholeWord(lower, ph) then return true end
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
    if not s.spamRepeat and #Phrases(s) == 0 then return false end   -- links only: nothing to decide (no name read, no lower-case copy)
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
    if not C.on.filter then return false end   -- the game keeps the filter until /reload: with its switches off it returns at once
    local s = S()
    if not s then return false end
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

-- the "filter" part: added to the game's chat filters the first time "Hide repeated messages", a blocked phrase or "Make web addresses
-- clickable" is on (with the Chat Panel on). The game's API documentation (docs/reference/api, 12.1.5) lists no way to take a filter
-- out again (ChatFrameUtil.RemoveMessageEventFilter is Blizzard UI code, not documented there: INFERENCE, not relied on), so turned off
-- it stays in the game's list and returns at once on C.on.filter. Up to Chat 0.6.13 it was added with the Chat Panel and, with all
-- three off, still read the sender's name and made a lower-case copy of every message on every chat window.
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

-- (Chat 0.6.25; REQUEST-LOG UI-12 / UI-17, Xaya 2026-11-06: "allow a modifier selector (alt, ctrl. fn(?))"; her answer "detect
-- available modifiers based on available keybinds not already assigned; also allow user to record and save their own keybind")
-- The click that ignores a player is a combination written the way the game writes key bindings: modifiers in the order ALT, CTRL,
-- SHIFT, META, then BUTTON1 / BUTTON2 / BUTTON3 (Blizzard_SharedXML/KeyCommand.lua GetBindingFullInput, wow-ui-source 297d7aa). Saved
-- as s.ignoreCombo; nothing saved = "CTRL-BUTTON2" (Ctrl + right-click, as before). Fn is not offered: the game's API reference has no
-- call that reads it. META (Command) only on a Mac: IsMacClient() -> isMac: bool (globals.md:367).
local BUTTONS = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3" }
local BUTTON_NAMES = { BUTTON1 = "left-click", BUTTON2 = "right-click", BUTTON3 = "middle-click" }
local MOD_NAMES = { ALT = "Alt", CTRL = "Ctrl", SHIFT = "Shift", META = "Cmd" }
function C.ComboNow(button)
    local b = BUTTONS[button or ""]
    if not b then return nil end
    local function down(f) local fn = _G[f]; return type(fn) == "function" and fn() and true or false end
    local out = ""
    if down("IsAltKeyDown") then out = out .. "ALT-" end
    if down("IsControlKeyDown") then out = out .. "CTRL-" end
    if down("IsShiftKeyDown") then out = out .. "SHIFT-" end
    if down("IsMetaKeyDown") then out = out .. "META-" end
    return out .. b
end
function C.ComboName(combo)
    if type(combo) ~= "string" then return "?" end
    local parts = {}
    for seg in combo:gmatch("[^%-]+") do parts[#parts + 1] = MOD_NAMES[seg] or BUTTON_NAMES[seg] or seg end
    return table.concat(parts, " + ")
end
-- the action the game has bound to a combination ("" or nil = none): C_KeyBindings.GetBindingByKey(action: cstring, context:
-- BindingContext?) -> binding: cstring (namespaces.md:2902); Blizzard passes the full input string ("CTRL-BUTTON2") as the first
-- argument (KeyCommand.lua GetBindingFromInput). Unknown (call missing or failing) counts as unbound.
function C.ComboBinding(combo)
    local KB = C_KeyBindings
    if not (KB and KB.GetBindingByKey) then return nil end
    local ok, act = pcall(KB.GetBindingByKey, combo)
    if ok and type(act) == "string" and act ~= "" and not issecret(act) then return act end
    return nil
end
-- every right-click with one or two modifiers that has no key binding of its own
function C.FreeCombos()
    local mods = { "ALT", "CTRL", "SHIFT" }
    if type(IsMacClient) == "function" and IsMacClient() then mods[#mods + 1] = "META" end
    local list = {}
    for i = 1, #mods do
        list[#list + 1] = mods[i] .. "-BUTTON2"
        for j = i + 1, #mods do list[#list + 1] = mods[i] .. "-" .. mods[j] .. "-BUTTON2" end
    end
    local out = {}
    for _, c in ipairs(list) do if not C.ComboBinding(c) then out[#out + 1] = c end end
    return out
end
function C.IgnoreCombo() local s = S(); return (s and type(s.ignoreCombo) == "string" and s.ignoreCombo ~= "") and s.ignoreCombo or "CTRL-BUTTON2" end

-- the recorder: a small box the next modified click on it is taken from (built on first use only)
local rec
function C.RecordCombo(done)
    if not rec then
        rec = CreateFrame("Button", "XayaUIChatComboRecorder", UIParent, "BackdropTemplate")
        rec:SetSize(320, 90); rec:SetPoint("CENTER"); rec:SetFrameStrata("DIALOG")
        rec:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        rec:SetBackdropColor(0.05, 0.05, 0.08, 0.96); rec:SetBackdropBorderColor(1, 0.82, 0, 1)
        rec:RegisterForClicks("AnyUp")
        rec.t = rec:CreateFontString(nil, "OVERLAY"); rec.t:SetFont(STANDARD_TEXT_FONT, 12, ""); rec.t:SetPoint("TOPLEFT", 10, -10); rec.t:SetPoint("BOTTOMRIGHT", -10, 10)
        rec.t:SetJustifyH("CENTER"); rec.t:SetJustifyV("MIDDLE")
        local x = CreateFrame("Button", nil, rec); x:SetSize(16, 16); x:SetPoint("TOPRIGHT", -3, -3)
        x.t = x:CreateFontString(nil, "OVERLAY"); x.t:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE"); x.t:SetPoint("CENTER"); x.t:SetText("X")
        x:SetScript("OnClick", function() rec:Hide() end)
        rec:SetScript("OnClick", function(self, button)
            local combo = C.ComboNow(button)
            if not combo then return end
            if not combo:find("-", 1, true) then
                self.t:SetText("Hold Alt, Ctrl, Shift (or Cmd) while you click: a plain click stays the game's own.\nTry again, or X to close.")
                return
            end
            local s = S(); if s then s.ignoreCombo = combo end
            local act = C.ComboBinding(combo)
            ns.Print("Chat Panel: ignore click set to " .. C.ComboName(combo) .. "." .. (act and (" The game also has a key binding on it (" .. act .. ").") or ""))
            self:Hide()
            if self.done then pcall(self.done) end
        end)
    end
    rec.done = done
    rec.t:SetText("Hold Alt, Ctrl, Shift (or Cmd on a Mac) and click here with the mouse button you want to use.\nX closes without a change.")
    rec:Show()
end

local function OnItemRef(link, text, button)
    if not C.on.itemref then return end   -- a hook the game cannot take back: idle with both switches (or the Chat Panel) off
    if type(link) ~= "string" or issecret(link) then return end
    local s = S()
    if not s then return end
    local a, addon, kind, id = strsplit(":", link)
    if a == "addon" and addon == "XayaUI" and kind == "url" then
        local url = C.LinkTarget(id)
        if url then C.CopyBox(url, "Web address: press Ctrl+C to copy it, then Escape") end
        return
    end
    if s.ignoreClick and a == "player" and C.ComboNow(button) == C.IgnoreCombo() then
        local name = strsplit(":", link:sub(8))
        if name and name ~= "" and not IsMe(name) and C_FriendList and C_FriendList.AddIgnore then
            local ok, added = pcall(C_FriendList.AddIgnore, name)
            -- (names another player: never kept in XayaUI's debug record)
            local say = ns.PrintPrivate or ns.Print
            -- audit D32 (Chat 0.6.31): AddIgnore returns added: bool (namespaces.md); say so only when it was added
            if ok and added then
                say("Ignoring " .. name .. " (" .. C.ComboName(C.IgnoreCombo()) .. "). Remove them in the social window's Ignore list.")
            else
                say("Could not ignore " .. name .. ": the game did not add them (already ignored, or the Ignore list is full).")
            end
        end
    end
end

C.Part("filter", function(s) return s.spamRepeat or s.links or #Phrases(s) > 0 end, Install)
-- the "itemref" part: clicking a web address (made by "Make web addresses clickable") and Ctrl + right-click on a name. The hook is
-- placed the first time either switch is on.
C.Part("itemref", function(s) return s.links or s.ignoreClick end,
    function() C.HookOnce("messages:itemref", "SetItemRef", nil, OnItemRef) end)
