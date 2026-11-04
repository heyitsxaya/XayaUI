-------------------------------------------------------------------------------
-- Chat/Locate.lua : "show me where it is". Draws a labeled outline over each piece of the chat (the tab row, text, input line, Chat Bar,
-- Blizzard's button strip, social button, scroll bar, back-to-newest arrow, and the small history and privacy buttons) for a few
-- seconds, so a setting can be understood without guessing where the piece went. A piece the game or an option has hidden is
-- labeled "(hidden)". Settings that move or show a piece flash that piece's outline when you change them. Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local C = ns.Chat

local function Cf() return C.Main() end
local PIECES = {
    { key = "tabs",     label = "Tab row",              get = function() return C.TabsArea() end,  color = { 0.4, 0.8, 1 } },
    { key = "text",     label = "Chat text",            get = function() return C.TextArea() end,  color = { 0.5, 1, 0.5 } },
    { key = "input",    label = "Input line",           get = function() return C.InputArea() end, color = { 1, 0.85, 0.3 } },
    { key = "bar",      label = "Chat Bar",             get = function() return C.Bar() end,       color = { 1, 0.5, 1 } },
    { key = "strip",    label = "Blizzard button strip", get = function() local cf = Cf(); return cf and C.ButtonFrameOf(cf) end, color = { 1, 0.5, 0.3 } },
    { key = "social",   label = "Social button",        get = function() return _G.QuickJoinToastButton end, color = { 1, 0.5, 0.3 } },
    { key = "scroll",   label = "Scroll bar",           get = function() local cf = Cf(); return cf and cf.ScrollBar end, color = { 1, 0.5, 0.3 } },
    { key = "ownscroll", label = "Chat Panel scroll bar", get = function() return C.ScrollBar and C.ScrollBar() end, color = { 0.5, 1, 0.5 } },
    { key = "tobottom", label = "Back-to-newest arrow", get = function() local cf = Cf(); return cf and cf.ScrollToBottomButton end, color = { 1, 0.5, 0.3 } },
    { key = "hist",     label = "History button",       get = function() return _G.XayaUIChatHistoryButton end, color = { 0.8, 0.8, 0.8 } },
    { key = "privacy",  label = "Privacy button",       get = function() return _G.XayaUIChatPrivacyButton end, color = { 0.8, 0.8, 0.8 } },
}
local byKey = {}
for _, p in ipairs(PIECES) do byKey[p.key] = p end

local boxes = {}
local driver

local function Box(p)
    local b = boxes[p.key]
    if b then return b end
    b = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    b:SetFrameStrata("TOOLTIP")
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    b.label:SetTextColor(1, 1, 1, 1)
    b:EnableMouse(false)
    b:Hide()
    boxes[p.key] = b
    return b
end

local function Place(p, seconds)
    local target = p.get()
    local b = Box(p)
    if not (target and target.GetLeft) then b:Hide(); return end
    local ok, l = pcall(target.GetLeft, target)
    if not ok or type(l) ~= "number" then b:Hide(); return end
    local w, h = target:GetWidth() or 0, target:GetHeight() or 0
    b:ClearAllPoints()
    b:SetPoint("CENTER", target, "CENTER", 0, 0)
    b:SetSize(math.max(w, 18), math.max(h, 18))
    local c = p.color
    b:SetBackdropColor(c[1], c[2], c[3], 0.18)
    b:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    local hidden = (target.IsShown and not target:IsShown()) or target._xuiSuppressed
    b.label:SetText(p.label .. (hidden and " (hidden)" or ""))
    b.label:ClearAllPoints()
    b.label:SetPoint("BOTTOM", b, "TOP", 0, 2)
    b.expire = GetTime() + (seconds or 3)
    b:Show()
end

local function Drive()
    if driver then return end
    driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function()
        local now, any = GetTime(), false
        for _, b in pairs(boxes) do
            if b:IsShown() then
                if now >= (b.expire or 0) then b:Hide() else any = true end
            end
        end
    end)
end

-- keys: a list of piece keys, or nil for every piece
function C.Locate(keys, seconds)
    Drive()
    if keys then
        for _, k in ipairs(keys) do if byKey[k] then Place(byKey[k], seconds) end end
    else
        for _, p in ipairs(PIECES) do Place(p, seconds) end
    end
end
function C.LocateClear() for _, b in pairs(boxes) do b:Hide() end end
