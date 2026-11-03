-------------------------------------------------------------------------------
-- Chat/History.lua : the history pane. A window with the recent messages as plain text you can select and copy (Ctrl+C), with kind
-- buttons and a search box. Opened from the small button in the pane's corner, a History block on the Chat Bar, or /xui chat history.
-- The lines are kept in memory only (never saved to disk). A message the game marks secret is listed as "[protected message]"
-- because its text cannot be read. Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
local C = ns.Chat
local issecret = C.IsSecret
local function S() return ns.chat2 end

local KIND_OF = {
    CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "SAY", CHAT_MSG_EMOTE = "SAY", CHAT_MSG_TEXT_EMOTE = "SAY",
    CHAT_MSG_PARTY = "GROUP", CHAT_MSG_PARTY_LEADER = "GROUP", CHAT_MSG_RAID = "GROUP", CHAT_MSG_RAID_LEADER = "GROUP",
    CHAT_MSG_RAID_WARNING = "GROUP", CHAT_MSG_INSTANCE_CHAT = "GROUP", CHAT_MSG_INSTANCE_CHAT_LEADER = "GROUP",
    CHAT_MSG_GUILD = "GUILD", CHAT_MSG_OFFICER = "GUILD",
    CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_WHISPER_INFORM = "WHISPER", CHAT_MSG_BN_WHISPER = "WHISPER", CHAT_MSG_BN_WHISPER_INFORM = "WHISPER",
    CHAT_MSG_CHANNEL = "CHANNEL",
}
local TAG = { CHAT_MSG_SAY = "Say", CHAT_MSG_YELL = "Yell", CHAT_MSG_EMOTE = "Emote", CHAT_MSG_TEXT_EMOTE = "Emote", CHAT_MSG_PARTY = "Party",
    CHAT_MSG_PARTY_LEADER = "Party", CHAT_MSG_RAID = "Raid", CHAT_MSG_RAID_LEADER = "Raid", CHAT_MSG_RAID_WARNING = "Raid warning",
    CHAT_MSG_INSTANCE_CHAT = "Instance", CHAT_MSG_INSTANCE_CHAT_LEADER = "Instance", CHAT_MSG_GUILD = "Guild", CHAT_MSG_OFFICER = "Officer",
    CHAT_MSG_WHISPER = "From", CHAT_MSG_WHISPER_INFORM = "To", CHAT_MSG_BN_WHISPER = "From", CHAT_MSG_BN_WHISPER_INFORM = "To", CHAT_MSG_CHANNEL = "Channel" }
local KINDS = { { "ALL", "All" }, { "SAY", "Say / Yell" }, { "GROUP", "Group" }, { "GUILD", "Guild" }, { "WHISPER", "Whispers" }, { "CHANNEL", "Channels" } }

local hist = {}
local kind, query = "ALL", ""
local frame

-- text without colors, textures and link wrappers (what you would want to paste)
function C.Plain(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return (text:gsub("||", "|"))
end

function C.History_Lines()
    local out, q = {}, query:lower()
    for _, e in ipairs(hist) do
        if kind == "ALL" or e.kind == kind then
            local body = e.text and C.Plain(e.text) or "[protected message]"
            local line = ("[%s] %s%s%s"):format(date("%H:%M:%S", e.t), e.tag and (e.tag .. " ") or "", e.who and (e.who .. ": ") or "", body)
            if q == "" or line:lower():find(q, 1, true) then out[#out + 1] = line end
        end
    end
    return out
end

C.OnMessage(function(event, text, author)
    local s = S()
    if not (s and s.histOn) then return end
    local k = KIND_OF[event]
    if not k then return end
    local e = { t = time(), kind = k, tag = TAG[event] }
    if type(author) == "string" and not issecret(author) then e.who = (author:gsub("%-.+$", "")) end
    if type(text) == "string" and not issecret(text) then e.text = text else C.stats.protected = C.stats.protected + 1 end
    hist[#hist + 1] = e
    local cap = math.max(20, math.min(2000, tonumber(s.histSize) or 300))
    while #hist > cap do table.remove(hist, 1) end
    if frame and frame:IsShown() then C.History_Update() end
end)

local function Build()
    if frame then return end
    frame = CreateFrame("Frame", "XayaUIChatHistory", UIParent, "BackdropTemplate")
    frame:SetSize(540, 380); frame:SetPoint("CENTER", 0, 40); frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton"); frame:SetClampedToScreen(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.97); frame:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    local title = frame:CreateFontString(nil, "OVERLAY"); title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("Chat history")
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(20, 20); close:SetPoint("TOPRIGHT", -6, -6)
    close.t = close:CreateFontString(nil, "OVERLAY"); close.t:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE"); close.t:SetPoint("CENTER"); close.t:SetText("X")
    close:SetScript("OnClick", function() frame:Hide() end)
    -- kind buttons
    frame.kb = {}
    local x = 12
    for _, k in ipairs(KINDS) do
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(78, 20); b:SetPoint("TOPLEFT", x, -34); x = x + 82
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
        b.t = b:CreateFontString(nil, "OVERLAY"); b.t:SetFont(STANDARD_TEXT_FONT, 12, ""); b.t:SetPoint("CENTER"); b.t:SetText(k[2])
        b:SetScript("OnClick", function() kind = k[1]; C.History_Update() end)
        b.key = k[1]
        frame.kb[#frame.kb + 1] = b
    end
    -- search
    local search = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    search:SetSize(200, 20); search:SetPoint("TOPRIGHT", -12, -60 + 26)
    search:SetFont(STANDARD_TEXT_FONT, 12, ""); search:SetAutoFocus(false)
    search:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    search:SetBackdropColor(0, 0, 0, 0.6); search:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
    search:SetTextInsets(6, 6, 0, 0)
    search:SetScript("OnTextChanged", function(self) query = self:GetText() or ""; C.History_Update() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.search = search
    -- text
    local scroll = CreateFrame("ScrollFrame", "XayaUIChatHistoryScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -62); scroll:SetPoint("BOTTOMRIGHT", -30, 34)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFont(STANDARD_TEXT_FONT, 12, ""); edit:SetWidth(490)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnTextChanged", function(self, user) if user and frame.text then self:SetText(frame.text) end end)   -- selectable, not editable
    scroll:SetScrollChild(edit)
    frame.scroll, frame.edit = scroll, edit
    local note = frame:CreateFontString(nil, "OVERLAY"); note:SetFont(STANDARD_TEXT_FONT, 11, ""); note:SetPoint("BOTTOMLEFT", 12, 12)
    note:SetTextColor(0.7, 0.7, 0.7, 1)
    note:SetText("Select text and press Ctrl+C. Kept in memory only. Protected messages cannot be read.")
    if _G.UISpecialFrames then table.insert(_G.UISpecialFrames, "XayaUIChatHistory") end
    frame:Hide()
end

function C.History_Update()
    if not frame then return end
    for _, b in ipairs(frame.kb) do
        if b.key == kind then b.bg:SetColorTexture(0.2, 0.45, 0.8, 0.8); b.t:SetTextColor(1, 1, 1, 1)
        else b.bg:SetColorTexture(1, 1, 1, 0.08); b.t:SetTextColor(0.8, 0.8, 0.8, 1) end
    end
    frame.text = table.concat(C.History_Lines(), "\n")
    frame.edit:SetText(frame.text)
    C_Timer.After(0, function() if frame.scroll.GetVerticalScrollRange then frame.scroll:SetVerticalScroll(frame.scroll:GetVerticalScrollRange() or 0) end end)
end

function C.History_Toggle()
    Build()
    if frame:IsShown() then frame:Hide() else frame:Show(); C.History_Update() end
end
function C.History_Count() return #hist end

-- the small button in the pane's corner
local btn
local function Refresh(s)
    if not C.On() or not C.Pane() then return end
    if not btn then
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
    btn:ClearAllPoints()
    btn:SetPoint("TOPRIGHT", C.TextArea(), "TOPRIGHT", 14, 2)
    btn:SetShown(s.histButton and not s.collapsed and true or false)
end
C.Register("history", Refresh)
