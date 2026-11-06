-------------------------------------------------------------------------------
-- Chat/History.lua : the history pane. A window with the recent messages as plain text you can select and copy (Ctrl+C), with one
-- button per chat tab and a search box. Opened from the small button in the pane's corner, a History block on the Chat Bar, or
-- /xui chat history. The lines are kept in memory only (never saved to disk). A message the game marks secret is listed as
-- "[protected message]" because its text cannot be read. Combat log lines are not chat messages and are not recorded.
-- The list is a SNAPSHOT: it stays still while you select text, and "Refresh" (or turning on Live) brings in newer lines.
-- The window can be moved and resized; its size is remembered.
-- Console tab (0.6.5): lines printed with print() (XayaUI's /xui output and other addons' messages) and the game's system messages
-- (CHAT_MSG_SYSTEM) are kept in a list of their own and shown only under "Console", so they do not crowd the chat tabs. Lines an addon
-- writes straight into a chat window without print() (DEFAULT_CHAT_FRAME:AddMessage) are not seen. Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local C = ns.Chat
local issecret = C.IsSecret
local function S() return ns.chat2 end

local TAG = { CHAT_MSG_SAY = "Say", CHAT_MSG_YELL = "Yell", CHAT_MSG_EMOTE = "Emote", CHAT_MSG_TEXT_EMOTE = "Emote", CHAT_MSG_PARTY = "Party",
    CHAT_MSG_PARTY_LEADER = "Party", CHAT_MSG_RAID = "Raid", CHAT_MSG_RAID_LEADER = "Raid", CHAT_MSG_RAID_WARNING = "Raid warning",
    CHAT_MSG_INSTANCE_CHAT = "Instance", CHAT_MSG_INSTANCE_CHAT_LEADER = "Instance", CHAT_MSG_GUILD = "Guild", CHAT_MSG_OFFICER = "Officer",
    CHAT_MSG_WHISPER = "From", CHAT_MSG_WHISPER_INFORM = "To", CHAT_MSG_BN_WHISPER = "From", CHAT_MSG_BN_WHISPER_INFORM = "To", CHAT_MSG_CHANNEL = "Channel" }

local hist, con = {}, {}                  -- chat messages; console lines (print output and system messages)
local tabKey, query = "ALL", ""          -- tabKey: "ALL", "CONSOLE", "WHISPERS", a whisper key ("W:name" / "B:id") or a chat window number
local explicitKey                         -- a tab asked for by C.History_Select (a Chat Bar block) before the window opens
local wname = {}                          -- whisper key -> the name its tab shows (Chat 0.6.15)
local shown = { [hist] = 0, [con] = 0 }  -- per list: how many entries the snapshot in the window already holds
local frame
local function List() return tabKey == "CONSOLE" and con or hist end

-- text without colors, textures, links and name codes (what you would want to paste). Named colors (|cnNAME:) and the colored
-- |K...|k name codes are part of the newer game's text; an unremoved color code would tint everything after it.
-- Chat 0.6.19: "||" (the game's escape for one literal "|") is set aside BEFORE the codes are taken out, then given back as one "|".
-- Up to 0.6.18 the codes went first, so the second "|" of a pair plus the letter after it could be read as a code and removed:
-- "on||off||reset" came out "on|off|eset" (the /xui chat status line), "[on||none]" as "[on| one]", "a||cffff0000b" as "a|b".
-- PIPE is byte 0xFF, which never occurs in UTF-8 text (the game's strings are UTF-8: INFERENCE, not in docs/reference).
local PIPE = "\255"
function C.Plain(text)
    text = text:gsub("||", PIPE)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_%-]+:", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = text:gsub("|K.-|k", "?"):gsub("|n", " ")
    return (text:gsub(PIPE, "|"))
end
-- text from C.Plain, ready for an edit box: every "|" doubled, so none starts a code (Chat 0.6.17; see C.History_Update)
function C.ForEditBox(text) return (tostring(text or ""):gsub("|", "||")) end

-- which chat windows (tabs) show this message right now. Channel messages go by the channel's name, everything else by message group.
function C.Shows(f, group, channelBase)
    if group == "CHANNEL" then
        if type(channelBase) ~= "string" or issecret(channelBase) then return false end
        local up = channelBase:upper()
        for _, name in pairs(type(f.channelList) == "table" and f.channelList or {}) do
            if type(name) == "string" and name:upper() == up then return true end
        end
        return false
    end
    if type(f.messageTypeList) == "table" then
        for _, g in pairs(f.messageTypeList) do if g == group then return true end end
        return false
    end
    local v = ns.Compat.ChatShowsGroup(f, group)
    if v ~= nil then return v end
    return false
end

local function Windows()                  -- { {id=, name=} } for the tabs worth a button
    local out = {}
    for _, f in ipairs(C.Frames()) do
        local id = f.GetID and f:GetID()
        if id and not f.isTemporary then
            local name, shown, docked
            if _G.GetChatWindowInfo then local n, _, _, _, _, _, sh, _, dk = _G.GetChatWindowInfo(id); name, shown, docked = n, sh, dk end
            if not name or name == "" then local tab = C.TabOf(f); local fs = tab and (tab.Text or _G[C.NameOf(tab) .. "Text"]); name = fs and fs.GetText and fs:GetText() or nil end
            if (shown or docked or f == C.Main()) and name and name ~= "" then out[#out + 1] = { id = id, name = name } end
        end
    end
    return out
end
C.History_Windows = Windows

function C.History_Lines()
    -- (the search box gives a typed "|" back doubled, as the game's edit boxes do: INFERENCE; matched against C.Plain's single "|")
    local out, q = {}, (query:gsub("||", "|")):lower()
    for _, e in ipairs(List()) do
        if tabKey == "ALL" or tabKey == "CONSOLE" or (e.frames and e.frames[tabKey]) or (tabKey == "WHISPERS" and e.wkey)
            or (e.wkey and e.wkey == tabKey) then
            local body = e.text and C.Plain(e.text) or "[protected message]"
            local line = ("[%s] %s%s%s"):format(date("%H:%M:%S", e.t), e.tag and (e.tag .. " ") or "", e.who and (e.who .. ": ") or "", body)
            if q == "" or line:lower():find(q, 1, true) then out[#out + 1] = line end
        end
    end
    return out
end

local function NewCount() local l = List(); return #l - shown[l] end
local UpdateStatus

-- one entry into a list, keeping it at the size limit; the open window refreshes (Live) or counts it (snapshot) when it shows that list
local function Keep(list, e)
    local s = S()
    list[#list + 1] = e
    local cap = math.max(20, math.min(2000, tonumber(s and s.histSize) or 300))
    local drop = 0
    while #list > cap do table.remove(list, 1); drop = drop + 1 end
    shown[list] = math.max(0, shown[list] - drop)
    if frame and frame:IsShown() and list == List() then
        if s and s.histLive and not (frame.edit and frame.edit:HasFocus()) then C.History_Update() else UpdateStatus() end
    end
end

-- Whisper tabs (Chat 0.6.15, Xaya 2026-11-05: the history "should also include whisper windows as individual tabs if selected as an
-- option in either blizzard native social options or when toggled within the addon"; "Our own switch should default to the current
-- interface selection in blizzard OR bundle all whispers into a consolidated tab"). Setting histWhispers:
--   "game" (default): follow the game's Options > Social > New Whispers (CVar whisperMode): "New Tab" or "Both" -> one tab per
--                     conversation; "In-line" (or unreadable) -> no whisper tabs (whispers stay in the chat tabs that show them);
--   "one":            every whisper in one "Whispers" tab.
-- A conversation is keyed by the other person: a character by "name-realm", lowercased ("W:ann-realm"; a name without a realm is on
-- your realm, see CharKey); a Battle.net friend by the message's Battle.net ID ("B:id"). Own code. UNTESTED in game.
local WHISPER_EV = { CHAT_MSG_WHISPER = "W", CHAT_MSG_WHISPER_INFORM = "W", CHAT_MSG_BN_WHISPER = "B", CHAT_MSG_BN_WHISPER_INFORM = "B" }
function C.History_WhisperMode()
    local s = S()
    if s and s.histWhispers == "one" then return "one" end
    local get = (_G.C_CVar and _G.C_CVar.GetCVar) or _G.GetCVar
    if get then
        local ok, v = pcall(get, "whisperMode")
        if ok and type(v) == "string" and not issecret(v) and (v == "popout" or v == "popout_and_inline") then return "each" end
    end
    return "none"
end
-- the realm part as the game writes it in "Name-Realm" (no spaces), lowercased for the key
local function RealmKey(r) return (r:gsub("[%s]", "")):lower() end
local function OwnRealm()
    local get = _G.GetNormalizedRealmName
    if type(get) ~= "function" then return nil end
    local ok, r = pcall(get)
    if ok and type(r) == "string" and not issecret(r) and r ~= "" then return r end
    return nil
end
-- Chat 0.6.16 (Xaya: "Server / realm names are typically only dropped in cases where the realm is identical to the player's"): a
-- name with no realm is on your realm, so it gets your realm; "Name-Realm" keeps its own. Two people of the same name on different
-- realms get two tabs. The tab shows the name alone for your realm, "Name-Realm" for another.
local function CharKey(name)
    if type(name) ~= "string" or issecret(name) or name == "" then return nil end
    local short, realm = name:match("^([^%-]+)%-(.+)$")
    if not short then short = name end
    local own = OwnRealm()
    realm = realm or own
    if not realm then return "W:" .. short:lower(), short end   -- your realm unreadable: the name alone
    local label = (own and RealmKey(realm) == RealmKey(own)) and short or (short .. "-" .. realm)
    return "W:" .. short:lower() .. "-" .. RealmKey(realm), label
end
local function BNKey(id)
    if type(id) ~= "number" or issecret(id) then return nil end
    local label = "Battle.net friend"
    local get = _G.C_BattleNet and _G.C_BattleNet.GetAccountInfoByID
    if get then
        local ok, info = pcall(get, id)
        local tag = ok and type(info) == "table" and info.battleTag
        if type(tag) == "string" and not issecret(tag) and tag ~= "" then label = (tag:gsub("#.*$", "")) end
    end
    return "B:" .. id, label
end
C.History_CharKey, C.History_BNKey = CharKey, BNKey

C.OnMessage(function(event, text, author, _, _, _, _, _, _, channelBase, _, _, _, bnID)
    local s = S()
    if not (s and s.histOn) then return end
    local tag = TAG[event]
    if not tag then return end
    local group = C.SOUND_GROUPS and C.SOUND_GROUPS[event]
    if event == "CHAT_MSG_WHISPER_INFORM" then group = "WHISPER" elseif event == "CHAT_MSG_BN_WHISPER_INFORM" then group = "BN_WHISPER" end
    local e = { t = time(), tag = tag, frames = {} }
    if group then
        for _, f in ipairs(C.Frames()) do
            local id = f.GetID and f:GetID()
            if id and C.Shows(f, group, channelBase) then e.frames[id] = true end
        end
    end
    if type(author) == "string" and not issecret(author) then e.who = (author:gsub("%-.+$", "")) end
    local wk = WHISPER_EV[event]
    if wk then
        local key, label
        if wk == "W" then key, label = CharKey(author) else key, label = BNKey(bnID) end
        if key then e.wkey = key; wname[key] = label end
    end
    if type(text) == "string" and not issecret(text) then e.text = text else C.stats.protected = C.stats.protected + 1 end
    Keep(hist, e)
end, function(s) return s.histOn and C.MSG_ALL or nil end)   -- V14: no chat message reaches the history while "Keep recent messages" is off

-- console lines ---------------------------------------------------------------------------------------------------------------
local function ConsoleOn() local s = S(); return s and s.histOn and s.histConsole ~= false and C.On() end
function C.History_Console(tag, ...)            -- tag: "Print" or "System"; the rest are the printed values
    if not ConsoleOn() then return end
    local parts, protected = {}, false
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if issecret(v) then protected = true; break end
        local ok, str = pcall(tostring, v)
        parts[#parts + 1] = ok and str or "?"
    end
    local e = { t = time(), tag = (tag == "System") and "System" or nil, console = true }
    if protected then C.stats.protected = C.stats.protected + 1 else e.text = table.concat(parts, " ") end
    Keep(con, e)
end
-- print(): a post-hook, so the line is shown by the game first and our copy can never stop it. Only calls that look up the global
-- print when they run are seen (XayaUI's ns.Print does; an addon that saved print after the hook was placed is not).
-- V14, the "console" part: the hook and the system-message frame are made the first time "Keep recent messages" and "Keep console
-- lines" are both on (with the Chat Panel on). Turned off, the system messages are unregistered; the print hook cannot be taken back and
-- returns at once until /reload. Up to Chat 0.6.13 both were placed at login: every print() by any addon ran this file's code.
local sys
C.Part("console", function(s) return s.histOn and s.histConsole ~= false end,
    function()
        C.HookOnce("history:print", "print", nil, function(...)
            if not C.on.console then return end
            pcall(C.History_Console, "Print", ...)
        end)
        if not sys then
            sys = CreateFrame("Frame")
            sys:SetScript("OnEvent", function(_, _, text) pcall(C.History_Console, "System", text) end)
        end
        pcall(sys.RegisterEvent, sys, "CHAT_MSG_SYSTEM")
    end,
    function() if sys then pcall(sys.UnregisterEvent, sys, "CHAT_MSG_SYSTEM") end end)

-------------------------------------------------------------------------------
-- The window
-------------------------------------------------------------------------------
local MIN_W, MIN_H = 440, 300
-- the bottom of the window is two rows: the buttons and status line (FOOT_BTN up from the bottom edge), and under them the privacy
-- note, which may wrap to two lines. The scroll area stops above both (FOOT_SCROLL), so no text is drawn over, or hidden behind, another.
-- #351 phase 2: the core margin (M) under the note and a gutter (G) between the bands (the note used to touch the buttons: 2 px)
local M, G = ns.UI_MARGIN, ns.UI_GUTTER
local NOTE_H, BTN_H = 28, 20                                      -- the note's height holds two 10 pt lines; the buttons are 20 tall
local FOOT_NOTE = M                                               -- the note: M above the bottom edge
local FOOT_BTN = FOOT_NOTE + NOTE_H + G                           -- the button row: G above the note
local FOOT_SCROLL = FOOT_BTN + BTN_H + G                          -- the scroll area: G above the button row
local TOP = 34                                                    -- the tab buttons' first row (under the title)

local function Btn(parent, label, w)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 70, 20)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
    b.t = b:CreateFontString(nil, "OVERLAY"); b.t:SetFont(STANDARD_TEXT_FONT, 12, ""); b.t:SetPoint("CENTER"); b.t:SetText(label)
    b.bg:SetColorTexture(1, 1, 1, 0.08)
    return b
end

local function PlaceTabButtons()          -- the tab buttons flow into rows as wide as the window; returns the height they use
    if not frame then return 0 end
    local avail = (frame:GetWidth() or 540) - 24
    local x, row = 0, 0
    for _, b in ipairs(frame.kb) do
        if b:IsShown() then
            local w = b:GetWidth()
            if x > 0 and x + w > avail then x = 0; row = row + 1 end
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + x, -TOP - row * 24)
            x = x + w + 4
        end
    end
    return row * 24 + 20   -- the rows' height: 24 apart, the last one 20 tall
end

local function Relayout()
    if not frame then return end
    local used = PlaceTabButtons()
    frame.search:ClearAllPoints()
    frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -TOP - used - G)            -- G under the tab buttons
    frame.search:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -TOP - used - G)
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -TOP - used - G - 20 - G)   -- G under the 20 px search box
    frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, FOOT_SCROLL)
    frame.edit:SetWidth(math.max(100, (frame:GetWidth() or 540) - 50))
end

local function RebuildTabButtons()
    for _, b in ipairs(frame.kb) do b:Hide() end
    -- order (Chat 0.6.15): the chat tabs, the whisper tabs, Console, then All last (Xaya: "All" is not the default pane)
    local list = {}
    for _, w in ipairs(Windows()) do list[#list + 1] = w end
    local mode = C.History_WhisperMode()
    if mode == "one" then
        list[#list + 1] = { id = "WHISPERS", name = "Whispers" }
    elseif mode == "each" then
        local seen = {}
        for _, e in ipairs(hist) do
            if e.wkey and not seen[e.wkey] then seen[e.wkey] = true; list[#list + 1] = { id = e.wkey, name = wname[e.wkey] or "Whisper" } end
        end
    end
    local s = S()
    if s and s.histConsole ~= false then list[#list + 1] = { id = "CONSOLE", name = "Console" } end
    list[#list + 1] = { id = "ALL", name = "All" }
    for i, w in ipairs(list) do
        local b = frame.kb[i]
        if not b then
            b = Btn(frame, "", 70)
            b:SetScript("OnClick", function(self) tabKey = self.key; C.History_Update() end)
            frame.kb[i] = b
        end
        b.key = w.id
        b.t:SetText(w.name)
        b:SetWidth(math.max(44, math.ceil((b.t:GetStringWidth() or 40)) + 18))
        b:Show()
    end
    local ok = false
    for _, w in ipairs(list) do if w.id == tabKey then ok = true end end
    if not ok then tabKey = list[1].id end   -- the first chat tab (was "All" before Chat 0.6.15)
    frame.tabList = list
end

UpdateStatus = function()
    if not frame then return end
    local n = NewCount()
    local what = (tabKey == "CONSOLE") and " console line" or " newer message"
    if n > 0 then frame.status:SetText(n .. what .. (n == 1 and "" or "s") .. ". Click Refresh.")
    else frame.status:SetText("Up to date.") end
    frame.refresh.bg:SetColorTexture(n > 0 and 0.2 or 1, n > 0 and 0.45 or 1, n > 0 and 0.8 or 1, n > 0 and 0.85 or 0.08)
end

local function Save()
    local s = S(); if not (s and frame) then return end
    s.histW, s.histH = math.floor(frame:GetWidth() + 0.5), math.floor(frame:GetHeight() + 0.5)
    local l, b = frame:GetLeft(), frame:GetBottom()
    if type(l) == "number" and type(b) == "number" then s.histX, s.histY = math.floor(l + 0.5), math.floor(b + 0.5) end
end

local function Build()
    if frame then return end
    local s = S()
    frame = CreateFrame("Frame", "XayaUIChatHistory", UIParent, "BackdropTemplate")
    frame:SetSize(tonumber(s and s.histW) or 540, tonumber(s and s.histH) or 380)
    if s and tonumber(s.histX) and tonumber(s.histY) then frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", s.histX, s.histY)
    else frame:SetPoint("CENTER", 0, 40) end
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true); frame:SetResizable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton"); frame:SetClampedToScreen(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(MIN_W, MIN_H, 1400, 1000) end
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.97); frame:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); Save() end)
    frame:SetScript("OnSizeChanged", function() Relayout() end)
    -- each open shows the chat tab you are on (Chat 0.6.15, Xaya: "active tab, yes"), unless a Chat Bar block asked for one
    frame:SetScript("OnShow", function()
        if explicitKey then tabKey = explicitKey; explicitKey = nil else tabKey = C.History_ActiveKey() end
        RebuildTabButtons(); Relayout(); C.History_Update()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY"); title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Chat history")
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(20, 20); close:SetPoint("TOPRIGHT", -6, -6)
    close.xuiEdge = true   -- a title-bar close button sits at the edge on purpose (#351)
    close.t = close:CreateFontString(nil, "OVERLAY"); close.t:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); close.t:SetPoint("CENTER"); close.t:SetText("X")
    close:SetScript("OnClick", function() frame:Hide() end)
    frame.kb = {}

    local search = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    search:SetHeight(20)
    search:SetFont(STANDARD_TEXT_FONT, 12, ""); search:SetAutoFocus(false)
    search:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    search:SetBackdropColor(0, 0, 0, 0.6); search:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    search:SetTextInsets(6, 6, 0, 0)
    search:SetScript("OnTextChanged", function(self) query = self:GetText() or ""; C.History_Update() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.search = search
    search.hint = search:CreateFontString(nil, "OVERLAY"); search.hint:SetFont(STANDARD_TEXT_FONT, 11, ""); search.hint:SetPoint("LEFT", 8, 0)
    search.hint:SetTextColor(0.5, 0.5, 0.5, 1); search.hint:SetText("Search")

    local scroll = CreateFrame("ScrollFrame", "XayaUIChatHistoryScroll", frame, "UIPanelScrollFrameTemplate")
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFont(STANDARD_TEXT_FONT, 12, ""); edit:SetTextColor(0.9, 0.9, 0.9, 1)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnTextChanged", function(self, user) if user and frame.text then self:SetText(frame.text) end end)   -- selectable, not editable
    scroll:SetScrollChild(edit)
    frame.scroll, frame.edit = scroll, edit

    -- bottom rows (see FOOT_*): buttons and status on the upper one, the note under them
    frame.refresh = Btn(frame, "Refresh", 64); frame.refresh:SetPoint("BOTTOMLEFT", 12, FOOT_BTN)
    frame.refresh:SetScript("OnClick", function() C.History_Update() end)
    frame.live = Btn(frame, "Live: off", 70); frame.live:SetPoint("LEFT", frame.refresh, "RIGHT", G, 0)
    frame.live:SetScript("OnClick", function()
        local st = S(); if not st then return end
        st.histLive = not st.histLive
        frame.live.t:SetText(st.histLive and "Live: on" or "Live: off")
        if st.histLive then C.History_Update() end
    end)
    frame.status = frame:CreateFontString(nil, "OVERLAY"); frame.status:SetFont(STANDARD_TEXT_FONT, 11, ""); frame.status:SetPoint("LEFT", frame.live, "RIGHT", 10, 0)
    frame.status:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -12, FOOT_BTN + 10)   -- bounded on both sides, and on the same height as the Live button's middle (both points must agree vertically)
    frame.status:SetJustifyH("LEFT"); frame.status:SetWordWrap(false)
    frame.status:SetTextColor(0.7, 0.7, 0.7, 1)
    local note = frame:CreateFontString(nil, "OVERLAY"); note:SetFont(STANDARD_TEXT_FONT, 10, "")
    note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, FOOT_NOTE); note:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(2 + 16 + G), FOOT_NOTE)   -- G short of the resize grip (16 px, 2 px in)
    note:SetHeight(NOTE_H); note:SetJustifyH("LEFT"); note:SetJustifyV("BOTTOM"); note:SetWordWrap(true)
    note:SetTextColor(0.55, 0.55, 0.55, 1)
    note:SetText("Select text, Ctrl+C. Kept in memory only. Combat log and protected lines are not recorded. Console: printed lines and system messages.")
    frame.note = note

    -- resize grip
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -2, 2); grip:SetFrameLevel((frame:GetFrameLevel() or 1) + 10)
    grip.xuiEdge = true   -- a corner resize grip sits at the edge on purpose (#351)
    for i = 1, 3 do
        local l = grip:CreateLine(nil, "OVERLAY"); l:SetThickness(1.5); l:SetColorTexture(0.7, 0.7, 0.75, 0.9)
        l:SetStartPoint("BOTTOMRIGHT", grip, -2 - (i - 1) * 4, 2); l:SetEndPoint("BOTTOMRIGHT", grip, -2, 2 + (i - 1) * 4)
    end
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); Save(); Relayout() end)
    frame.grip = grip

    if _G.UISpecialFrames then table.insert(_G.UISpecialFrames, "XayaUIChatHistory") end
    frame:Hide()
end

function C.History_Update()
    if not frame then return end
    local st = S()
    for _, b in ipairs(frame.kb) do
        if b:IsShown() then
            if b.key == tabKey then b.bg:SetColorTexture(0.2, 0.45, 0.8, 0.8); b.t:SetTextColor(1, 1, 1, 1)
            else b.bg:SetColorTexture(1, 1, 1, 0.08); b.t:SetTextColor(0.8, 0.8, 0.8, 1) end
        end
    end
    frame.live.t:SetText((st and st.histLive) and "Live: on" or "Live: off")
    frame.search.hint:SetShown((frame.search:GetText() or "") == "")
    -- (Chat 0.6.17; Xaya 2026-11-06: fix it "in this update") C.Plain gives one "|" per literal pipe; handed to the edit box like that,
    -- a "|" followed by a letter is read as the start of a code ("|t", "|w") and the "|", sometimes with the letter, disappears (her
    -- screenshot of 2026-11-05: "[highlighttrail]", "statusidthprobe"). The edit box gets every pipe doubled, which it shows as one.
    -- INFERENCE (the game's escape rules are not in docs/reference): "||" shows as "|" in an edit box, as it does in chat; QA D12.
    frame.text = C.ForEditBox(table.concat(C.History_Lines(), "\n"))
    frame.edit:SetText(frame.text)
    shown[List()] = #List()
    UpdateStatus()
    C_Timer.After(0, function() if frame.scroll.GetVerticalScrollRange then frame.scroll:SetVerticalScroll(frame.scroll:GetVerticalScrollRange() or 0) end end)
end

function C.History_Toggle()
    Build()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
function C.History_Count() return #hist end
function C.History_ConsoleCount() return #con end
-- a Chat Bar block (or a test) can pick a tab: at once while the window is open, else for its next open
function C.History_Select(key)
    if key == nil then return end
    tabKey = key
    if frame and frame:IsShown() then explicitKey = nil else explicitKey = key end
end

-- the history tab that matches the chat tab you are on: a chat window's number; for one of the game's whisper windows, its
-- conversation's tab ("each") or the Whispers tab ("one"), else the first chat tab (RebuildTabButtons falls back to it)
function C.History_ActiveKey()
    local f = C.ScrollTarget and C.ScrollTarget()
    if type(f) ~= "table" then return nil end
    if f.isTemporary then
        local mode = C.History_WhisperMode()
        if mode == "one" then return "WHISPERS" end
        if mode == "each" then
            local ct, tgt = f.chatType, f.chatTarget
            if ct == "WHISPER" then return (CharKey(tgt)) end
            if ct == "BN_WHISPER" then return (BNKey(tonumber(tgt))) end
        end
        return nil
    end
    return f.GetID and f:GetID() or nil
end

-- the small button in the pane's corner
local btn
local function Refresh(s)
    if not C.On() or not C.Pane() then return end
    if not btn then
        if not s.histButton then return end   -- V14: built the first time "Show the small history button" is on
        btn = CreateFrame("Button", "XayaUIChatHistoryButton", C.Pane())
        btn:SetSize(16, 16); btn:SetFrameStrata("MEDIUM")
        btn.lines = {}
        for i = 1, 3 do
            local t = btn:CreateTexture(nil, "OVERLAY"); t:SetColorTexture(1, 1, 1, 1)
            t:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -3 - (i - 1) * 4); t:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -3 - (i - 1) * 4); t:SetHeight(2)
            btn.lines[i] = t
        end
        btn:SetAlpha(0.35)
        btn:SetScript("OnClick", function() C.History_Toggle() end)
        btn:SetScript("OnEnter", function(self) self:SetAlpha(1); GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("Chat history"); GameTooltip:AddLine("Copy recent messages", 1, 1, 1); GameTooltip:Show() end)
        btn:SetScript("OnLeave", function(self) self:SetAlpha(0.35); GameTooltip:Hide() end)
    end
    -- at the right end of the tab row, where the tabs stop short of it (Frame.lua, C.HIST_RESERVE). Not under the tab row: the
    -- Chat Panel's scroll bar starts there and its up arrow was covered. With the tab row hidden: the text area's top-right corner,
    -- which is left of the scroll bar.
    btn:ClearAllPoints()
    local tabs = C.TabsArea()
    if tabs and s.tabsShow then
        btn:SetPoint("RIGHT", tabs, "RIGHT", -3, 0)
    else
        btn:SetPoint("TOPRIGHT", C.TextArea(), "TOPRIGHT", -3, -3)
    end
    btn:SetShown(s.histButton and not s.collapsed and true or false)
end
C.Register("history", Refresh)
