-------------------------------------------------------------------------------
-- MinimapButton.lua : a minimap button with a quick-access list. Own code. UNTESTED in game.
--   Left-click   opens a small list of buttons: Notes, Settings, Custom data panels, Chat panel, Chat privacy cover.
--   Right-click  opens the XayaUI settings window.
--   Drag         moves the button around the minimap edge (unless locked).
-- Which entries the list shows, the position, and whether the button is shown at all are settings (QoL UI Updates > Minimap Button).
-------------------------------------------------------------------------------
local ADDON, ns = ...

local DEFAULTS = {
    hide = false,            -- the button itself
    locked = false,          -- no dragging
    angle = 215,             -- degrees around the minimap, 0 = right, 90 = top
    radiusOffset = 5,        -- how far outside the minimap's edge the button sits
    closeOnClick = true,     -- the list closes after a choice
    entries = { notes = true, settings = true, data = true, chat = true, privacy = true },
}
ns.MINIMAP_DEFAULTS = DEFAULTS

local function DB() return ns.minimapDB end
function ns.Minimap_OnDBReady()
    CueRulesDB.minimap = CueRulesDB.minimap or {}
    ns.Merge(CueRulesDB.minimap, DEFAULTS)
    ns.minimapDB = CueRulesDB.minimap
end

-- the quick-access entries: key, label, tooltip, action, optional state text
local ENTRIES = {
    { "notes", "Notes", "Show or hide the notepad (also /xui notes)", function() if ns.Notepad_Toggle then ns.Notepad_Toggle() end end,
        function() local d = ns.notepadDB; return d and d.shown and "on" or "off" end },
    { "settings", "Settings", "Open the XayaUI settings window", function() if ns.ToggleUI then ns.ToggleUI() end end },
    { "data", "Custom data panels", "Open the custom data panels settings (also /xui data)", function() if ns.DataPanels_OpenSettings then ns.DataPanels_OpenSettings() end end },
    { "chat", "Chat panel", "Open the settings of the info bar beside the chat window (also /xui panel)", function() if ns.ChatPanel_ShowWindow then ns.ChatPanel_ShowWindow() end end },
    { "privacy", "Chat privacy cover", "Cover or show the chat (also /xui privacy)",
        function() if ns.ChatPrivacy_Set and ns.chatDB then ns.ChatPrivacy_Set(not ns.chatDB.privOn) end end,
        function() return ns.chatDB and ns.chatDB.privOn and "on" or "off" end },
}
ns.MINIMAP_ENTRIES = ENTRIES

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local button, popup, catcher

local function Place()
    local db = DB(); if not (db and button) then return end
    local m = Minimap
    local w = (m and m.GetWidth and m:GetWidth()) or 140
    local h = (m and m.GetHeight and m:GetHeight()) or w
    local a = math.rad(db.angle or 215)
    local rx, ry = w / 2 + (db.radiusOffset or 5), h / 2 + (db.radiusOffset or 5)
    local x, y = math.cos(a) * rx, math.sin(a) * ry
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then   -- a square minimap: the button rides the square's edge instead of a circle
        local k = math.max(math.abs(x) / rx, math.abs(y) / ry)
        if k > 0 then x, y = x / k, y / k end
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", m or UIParent, "CENTER", x, y)
end

local function ClosePopup() if popup then popup:Hide() end; if catcher then catcher:Hide() end end

local function Visible()
    local db = DB(); local out = {}
    if not db then return out end
    for _, e in ipairs(ENTRIES) do if db.entries[e[1]] then out[#out + 1] = e end end
    return out
end

local function BuildPopup()
    if popup then return popup end
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent); catcher:SetFrameStrata("FULLSCREEN"); catcher:Hide()
    catcher:SetScript("OnClick", ClosePopup)
    popup = CreateFrame("Frame", "XayaUIMinimapMenu", UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG"); popup:SetClampedToScreen(true)
    popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    popup:SetBackdropColor(0.08, 0.08, 0.08, 0.97); popup:SetBackdropBorderColor(0.2, 0.7, 1, 1)
    popup.rows = {}
    popup:Hide()
    return popup
end

local ROW_H, MENU_W = 22, 190
local function Rebuild()
    local p = BuildPopup()
    local list = Visible()
    for i, e in ipairs(list) do
        local b = p.rows[i]
        if not b then
            b = CreateFrame("Button", nil, p)
            b:SetHeight(ROW_H)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(0.2, 0.7, 1, 0.35)
            b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); b.fs:SetPoint("LEFT", 8, 0)
            b.state = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.state:SetPoint("RIGHT", -8, 0)
            b:SetScript("OnClick", function(self)
                local db = DB()
                if db and db.closeOnClick then ClosePopup() end
                if self.entry and self.entry[4] then self.entry[4]() end
                if not (db and db.closeOnClick) then self:GetScript("OnShow")(self) end
            end)
            b:SetScript("OnShow", function(self) local st = self.entry and self.entry[5] and self.entry[5](); self.state:SetText(st and ("|cff888888" .. st .. "|r") or "") end)
            b:SetScript("OnEnter", function(self)
                if not self.entry then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(self.entry[2], 1, 0.82, 0); GameTooltip:AddLine(self.entry[3], 1, 1, 1, true); GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            p.rows[i] = b
        end
        b.entry = e
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 3, -3 - (i - 1) * ROW_H); b:SetPoint("TOPRIGHT", -3, -3 - (i - 1) * ROW_H)
        b.fs:SetText(e[2]); b:Show()
        local st = e[5] and e[5](); b.state:SetText(st and ("|cff888888" .. st .. "|r") or "")
    end
    for i = #list + 1, #p.rows do p.rows[i]:Hide(); p.rows[i].entry = nil end
    p:SetSize(MENU_W, math.max(1, #list) * ROW_H + 6)
    return list
end

local function TogglePopup()
    if popup and popup:IsShown() then ClosePopup() return end
    local list = Rebuild()
    if #list == 0 then if ns.ToggleUI then ns.ToggleUI() end return end
    popup:ClearAllPoints()
    -- open toward the middle of the screen so the list is never cut off
    local cx = button:GetCenter() or 0
    local half = (UIParent:GetWidth() or 1024) / 2
    local _, cy = button:GetCenter()
    local below = (cy or 0) > ((UIParent:GetHeight() or 768) / 2)
    popup:SetPoint(below and "TOP" or "BOTTOM", button, below and "BOTTOM" or "TOP", (cx > half) and -MENU_W / 2 + 10 or MENU_W / 2 - 10, below and -4 or 4)
    catcher:Show(); popup:Show()
end

local function BuildButton()
    if button then return button end
    local b = CreateFrame("Button", "XayaUIMinimapButton", Minimap or UIParent)
    b:SetSize(31, 31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp"); b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetSize(20, 20); b.bg:SetPoint("CENTER", 0, 1); b.bg:SetColorTexture(0.06, 0.06, 0.06, 0.9)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(18, 18); b.icon:SetPoint("CENTER", 0, 1)
    b.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01"); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.border = b:CreateTexture(nil, "OVERLAY"); b.border:SetSize(53, 53); b.border:SetPoint("TOPLEFT")
    b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b:SetScript("OnClick", function(_, btn)
        if b.dragging then return end
        if btn == "RightButton" then ClosePopup(); if ns.ToggleUI then ns.ToggleUI() end else TogglePopup() end
    end)
    b:SetScript("OnDragStart", function(self)
        local db = DB(); if not db or db.locked then return end
        self.dragging = true; ClosePopup()
        self:SetScript("OnUpdate", function()
            local m = Minimap; if not (m and m.GetCenter) then return end
            local mx, my = m:GetCenter(); if not mx then return end
            local px, py = GetCursorPosition()
            local sc = (m.GetEffectiveScale and m:GetEffectiveScale()) or 1
            px, py = px / sc, py / sc
            DB().angle = math.deg(atan2(py - my, px - mx)) % 360
            Place()
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        C_Timer.After(0.05, function() self.dragging = false end)   -- the click that ends a drag is not a click
        if ns.Minimap_Changed then ns.Minimap_Changed() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("XayaUI", 1, 0.82, 0)
        GameTooltip:AddLine("Left-click: quick-access list", 1, 1, 1)
        GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
        local db = DB()
        if db and not db.locked then GameTooltip:AddLine("Drag: move around the minimap", 0.6, 0.6, 0.6) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button = b
    return b
end

function ns.Minimap_Refresh()
    local db = DB(); if not db then return end
    if db.hide then if button then button:Hide() end; ClosePopup() return end
    BuildButton(); Place(); button:Show()
    if popup and popup:IsShown() then Rebuild() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function() C_Timer.After(0.2, ns.Minimap_Refresh) end)

-------------------------------------------------------------------------------
-- options: QoL UI Updates > Minimap Button
-------------------------------------------------------------------------------
function ns.BuildMinimapTab(Notify)
    if not DB() then return nil end
    ns.Minimap_Changed = function() if Notify then Notify() end end
    local function g(k) return function() return DB()[k] end end
    local function s(k) return function(_, v) DB()[k] = v; ns.Minimap_Refresh() end end
    local args = {
        n = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "A button on the minimap. Left-click opens a small list of buttons for the features you pick below; right-click opens this window; drag it to move it around the minimap." },
        show = { type = "toggle", order = 1, name = "Show the minimap button", width = "full", get = function() return not DB().hide end, set = function(_, v) DB().hide = not v; ns.Minimap_Refresh() end },
        lock = { type = "toggle", order = 2, name = "Lock the button's position", disabled = function() return DB().hide end, get = g("locked"), set = function(_, v) DB().locked = v end },
        close = { type = "toggle", order = 3, name = "Close the list after a choice", disabled = function() return DB().hide end, get = g("closeOnClick"), set = function(_, v) DB().closeOnClick = v end },
        angle = { type = "range", order = 4, name = "Position (degrees around the minimap)", min = 0, max = 359, step = 1, disabled = function() return DB().hide end, get = g("angle"), set = s("angle") },
        entries = { type = "group", name = "Buttons in the list", order = 10, inline = true, disabled = function() return DB().hide end, args = {} },
    }
    for i, e in ipairs(ENTRIES) do
        args.entries.args[e[1]] = { type = "toggle", order = i, name = e[2], desc = e[3],
            get = function() return DB().entries[e[1]] and true or false end,
            set = function(_, v) DB().entries[e[1]] = v and true or false; ns.Minimap_Refresh() end }
    end
    return { type = "group", name = "Minimap Button", order = 12, args = args }
end
