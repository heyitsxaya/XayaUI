-------------------------------------------------------------------------------
-- ChatPrivacy.lua : a privacy cover that sits over the Chat Panel's pane (tabs optional, text and the input line always), toggled by a
-- small eye button beside the chat or with /xui privacy. The Chat Bar and its arrow stay visible. Fill it with a color, a background texture, or your own picture.
-- It only hides the chat visually: messages are still received and logged, and nothing is deleted.
-- Pictures: the game can only load TGA / BLP files that are inside its own Interface folder (it cannot read C:\Users\...).
-- Put yours in Interface\AddOns\XayaUI_Media\ and type the file name (or the path from "Interface\" on) in the picture path box.
-- Own code, written from the option set only. UNTESTED in game.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)

local D = ns.CHAT_DEFAULTS
D.privOn = false                 -- remembered between sessions (the button flips it)
D.privStartHidden = false        -- cover the chat at every login
D.privBtn = true                 -- show the toggle button
D.privBtnX, D.privBtnY = 0, 0    -- fine-tune offsets of the button
D.privMode = "COLOR"             -- COLOR | TEXTURE | IMAGE
D.privR, D.privG, D.privB = 0.04, 0.04, 0.06
D.privAlpha = 100                -- whole cover opacity, percent
D.privFillA = 100                -- the color fill's own opacity, percent
D.privTexA = 100                 -- the texture / picture's own opacity, percent
D.privBtnSize = 28               -- toggle button size in pixels
D.privBtnAlpha = 90              -- toggle button opacity when the mouse is not over it, percent
D.privTexture = "Interface\\DialogFrame\\UI-DialogBox-Background"
D.privTile = false
D.privImageChoice = ""           -- a picture picked from the list
D.privPath = ""                  -- or a typed picture path (wins over the list)
D.privBorder = true
D.privShowText = true
D.privText = "Chat hidden"
D.privCoverTabs = false
D.privReveal = false             -- cover fades away while the mouse is over it

local function Store() return ns.chatDB end
local BASE = "Interface\\AddOns\\XayaUI_Media\\"
local cover, btn

local BUILTIN_TEX = {
    { "Interface\\DialogFrame\\UI-DialogBox-Background", "Dialog background (dark)" },
    { "Interface\\Tooltips\\UI-Tooltip-Background", "Tooltip background (flat)" },
    { "Interface\\FrameGeneral\\UI-Background-Marble", "Marble" },
    { "Interface\\FrameGeneral\\UI-Background-Rock", "Rock" },
    { "Interface\\Buttons\\WHITE8X8", "Solid" },
}

-- picture path -------------------------------------------------------------------------------------------------------------
-- Returns the path the game can load, or nil plus a short reason.
local function NormalizePath(p)
    p = tostring(p or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("/", "\\")
    if p == "" then return nil, "empty" end
    local i = p:lower():find("interface\\", 1, true)
    if i then return p:sub(i) end
    if p:match("^%a:\\") or p:sub(1, 2) == "\\\\" then return nil, "outside" end
    return BASE .. p:gsub("^\\+", "")
end

local function CurrentImage(s)
    if (s.privPath or "") ~= "" then return NormalizePath(s.privPath) end
    if (s.privImageChoice or "") ~= "" then return s.privImageChoice end
    return nil, "empty"
end

-- cover frame ----------------------------------------------------------------------------------------------------------------
local function Target()
    return ns.Chat and ns.Chat.Pane and ns.Chat.Pane() or nil
end

-- over the text and the input line; with "also cover the tabs" the tab row too
local function Anchor(s)
    local pane = Target()
    if not (cover and pane) then return end
    local tabs = ns.Chat.TabsArea and ns.Chat.TabsArea()
    cover:ClearAllPoints()
    if s.privCoverTabs or not tabs then cover:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    else cover:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 0, 0) end
    cover:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    cover.anchoredTo = pane
    -- the tab row stays clickable even when the cover is drawn over it: the cover's mouse area starts below the tab row, so a click
    -- on a tab reaches the tab (the cover still hides how the tabs look; it only stops swallowing their clicks)
    local inset = (s.privCoverTabs and tabs) and (tabs:GetHeight() or 0) or 0
    if cover.SetHitRectInsets then cover:SetHitRectInsets(0, 0, inset, 0) end
end

local function Style(s)
    if not cover then return end
    cover:SetAlpha((s.privAlpha or 100) / 100)
    cover:SetFrameStrata("DIALOG")          -- above the chat text AND the edit box, which the game draws in the dialog layer
    cover:SetFrameLevel(100)
    cover.fill:SetColorTexture(s.privR or 0, s.privG or 0, s.privB or 0, (tonumber(s.privFillA) or 100) / 100)
    local mode = s.privMode or "COLOR"
    local tex = cover.tex
    tex:Hide()
    cover.status = nil
    if mode == "TEXTURE" then
        local path = s.privTexture
        local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
        local n = type(path) == "string" and path:match("^lsm:(.+)$")
        if n and lsm then path = lsm:Fetch("background", n, true) end
        if path then
            tex:SetTexture(path, s.privTile and "REPEAT" or nil, s.privTile and "REPEAT" or nil)
            tex:SetHorizTile(s.privTile and true or false); tex:SetVertTile(s.privTile and true or false)
            tex:SetVertexColor(s.privR or 1, s.privG or 1, s.privB or 1, (tonumber(s.privTexA) or 100) / 100)
            tex:SetTexCoord(0, 1, 0, 1)
            tex:Show()
        end
    elseif mode == "IMAGE" then
        local path, why = CurrentImage(s)
        if path then
            tex:SetTexture(path)
            tex:SetHorizTile(false); tex:SetVertTile(false)
            tex:SetVertexColor(1, 1, 1, (tonumber(s.privTexA) or 100) / 100)
            tex:SetTexCoord(0, 1, 0, 1)
            tex:Show()
            cover.status = "Using: " .. path
        elseif why == "outside" then
            cover.status = "The game cannot read files outside its Interface folder. Copy the picture into Interface\\AddOns\\XayaUI_Media\\ and type just its file name."
        else
            cover.status = "No picture chosen: the cover shows the color."
        end
    end
    local ab = (s.privBorder and 1 or 0)
    cover:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    cover:SetBackdropBorderColor(0, 0, 0, ab)
    local path = ns.FontPath and ns.FontPath(s.font) or STANDARD_TEXT_FONT
    if not cover.label:SetFont(path or STANDARD_TEXT_FONT, 14, "OUTLINE") then cover.label:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE") end
    cover.label:SetText(s.privShowText and (s.privText or "") or "")
end

-- true while the pointer is inside the cover's whole rectangle (the tab row too, even though that part does not take clicks)
local function Over(f)
    local ok, v = pcall(function()
        local l, b, w, h = f:GetRect()
        if not l then return false end
        local x, y = GetCursorPosition()
        local sc = f:GetEffectiveScale() or 1
        x, y = x / sc, y / sc
        return x >= l and x <= l + w and y >= b and y <= b + h
    end)
    return ok and v and true or false
end

local function BuildCover()
    if cover then return cover end
    cover = CreateFrame("Frame", "XayaUIChatPrivacy", UIParent, "BackdropTemplate")
    cover:EnableMouse(true)       -- also stops hover and mouse-wheel scrolling over the hidden chat
    cover.fill = cover:CreateTexture(nil, "BACKGROUND")
    cover.fill:SetAllPoints()
    cover.tex = cover:CreateTexture(nil, "BORDER")
    cover.tex:SetAllPoints()
    cover.label = cover:CreateFontString(nil, "OVERLAY")
    cover.label:SetPoint("CENTER")
    cover.label:SetTextColor(1, 1, 1, 0.8)
    cover:Hide()
    local acc = 0
    cover:SetScript("OnUpdate", function(self, dt)
        acc = acc + dt
        if acc < 0.1 then return end
        acc = 0
        local s = Store(); if not s then return end
        if Target() ~= self.anchoredTo then Anchor(s) end
        local a = (s.privAlpha or 100) / 100
        if s.privReveal and Over(self) then a = 0 end
        if self:GetAlpha() ~= a then self:SetAlpha(a) end
    end)
    return cover
end

-- button (an eye drawn with lines: open = chat visible, slashed = chat covered) ------------------------------------------------
local function DrawEye(b, covered)
    local lines = b.lines
    local k = (b:GetWidth() or 18) / 18   -- the eye is drawn for an 18 pixel button and scaled with the button's size
    local w, h = 6 * k, 3.5 * k
    local function seg(l, x1, y1, x2, y2) l:SetStartPoint("CENTER", b, x1, y1); l:SetEndPoint("CENTER", b, x2, y2) end
    seg(lines[1], -w, 0, 0, h); seg(lines[2], 0, h, w, 0); seg(lines[3], w, 0, 0, -h); seg(lines[4], 0, -h, -w, 0)
    seg(lines[5], -w, -h - 1.5 * k, w, h + 1.5 * k)
    lines[5]:SetShown(covered and true or false)
    b.dot:SetShown(not covered)
    b.dot:SetSize(3 * k, 3 * k)
    local r, g, bl = 1, 0.82, 0
    if covered then r, g, bl = 0.55, 0.85, 1 end
    for i = 1, 5 do lines[i]:SetColorTexture(r, g, bl, 1); lines[i]:SetThickness(math.max(1.5, 1.5 * k)) end
    b.dot:SetColorTexture(r, g, bl, 1)
    -- the button itself shows the state: dark with a gold edge while the chat is visible, blue with a bright edge while it is covered
    if covered then b:SetBackdropColor(0.05, 0.25, 0.5, 0.95); b:SetBackdropBorderColor(0.4, 0.8, 1, 1)
    else b:SetBackdropColor(0, 0, 0, 0.75); b:SetBackdropBorderColor(1, 0.82, 0, 0.9) end
end

local function PlaceButton()
    local s = Store()
    if not (btn and s) then return end
    local c = ns.Chat and ns.Chat.Container and ns.Chat.Container()
    if not c then return end
    local s2 = ns.chat2
    btn:ClearAllPoints()
    -- beside the chat block, level with its top edge (the strip option "Right of the chat" uses the same side: move one with the offsets)
    local past = (s2 and s2.stripMode == "RIGHT") and 34 or 0   -- Blizzard's button strip may sit on that side: stay clear of it
    btn:SetPoint("TOPLEFT", c, "TOPRIGHT", 4 + past + (tonumber(s.privBtnX) or 0), (tonumber(s.privBtnY) or 0))
end

local function BuildButton()
    if btn then return btn end
    btn = CreateFrame("Button", "XayaUIChatPrivacyButton", UIParent, "BackdropTemplate")
    btn:SetSize(28, 28)
    btn:SetFrameStrata("MEDIUM"); btn:SetFrameLevel(60)
    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    btn:SetBackdropColor(0, 0, 0, 0.75); btn:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    btn:SetAlpha(0.9)
    btn.lines = {}
    for i = 1, 5 do local l = btn:CreateLine(nil, "OVERLAY"); l:SetThickness(1.5); btn.lines[i] = l end
    btn.dot = btn:CreateTexture(nil, "OVERLAY"); btn.dot:SetSize(3, 3); btn.dot:SetPoint("CENTER")
    btn:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local s = Store()
        GameTooltip:SetText("Chat privacy")
        GameTooltip:AddLine((s and s.privOn) and "Click: show the chat" or "Click: cover the chat", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self) local st = Store(); self:SetAlpha((tonumber(st and st.privBtnAlpha) or 90) / 100); GameTooltip:Hide() end)
    btn:SetScript("OnClick", function() ns.ChatPrivacy_Set(not (Store() or {}).privOn) end)
    return btn
end

function ns.ChatPrivacy_Refresh()
    local s = Store()
    if not s then return end
    BuildButton()
    local size = math.max(16, math.min(64, tonumber(s.privBtnSize) or 28))
    btn:SetSize(size, size)
    if not (btn.IsMouseOver and btn:IsMouseOver()) then btn:SetAlpha((tonumber(s.privBtnAlpha) or 90) / 100) end
    local collapsed = ns.Chat and ns.Chat.IsCollapsed and ns.Chat.IsCollapsed()
    local canShow = Target() and ns.Chat.On() and not collapsed
    btn:SetShown(canShow and s.privBtn ~= false)
    PlaceButton()
    DrawEye(btn, s.privOn)
    if s.privOn and canShow then
        BuildCover(); Style(s); Anchor(s); cover:Show()
    elseif cover then
        cover:Hide()
    end
end

function ns.ChatPrivacy_Set(v)
    local s = Store(); if not s then return end
    s.privOn = v and true or false
    ns.ChatPrivacy_Refresh()
end

-- keep the button / cover in step with collapse, tab changes and the collapse button moving
local drv = CreateFrame("Frame")
drv:RegisterEvent("PLAYER_ENTERING_WORLD")
drv:RegisterEvent("UPDATE_CHAT_WINDOWS")
local started
drv:SetScript("OnEvent", function()
    C_Timer.After(0.5, function()
        local s = Store()
        if s and not started then started = true; if s.privStartHidden then s.privOn = true end end
        ns.ChatPrivacy_Refresh()
    end)
end)
local acc = 0
drv:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.25 then return end
    acc = 0
    local s = Store()
    if not (s and btn) then return end
    local collapsed = ns.Chat and ns.Chat.IsCollapsed and ns.Chat.IsCollapsed()
    local want = (not collapsed) and s.privBtn ~= false and Target() ~= nil and ns.Chat.On()
    if btn:IsShown() ~= want then btn:SetShown(want); PlaceButton() end
    if s.privOn and cover then
        local should = not collapsed
        if cover:IsShown() ~= should then cover:SetShown(should) end
    end
end)

-- options (a group on the chat page) ----------------------------------------------------------------------------------------
function ns.ChatPrivacy_Options(Notify)
    local function S() return Store() or {} end
    local function set(k, redo) return function(_, v) local s = Store(); if s then s[k] = v end; ns.ChatPrivacy_Refresh(); if redo and Notify then Notify() end end end
    local function get(k) return function() return S()[k] end end
    local function mode(m) return function() return S().privMode ~= m end end
    return { type = "group", name = "Chat Privacy", order = 10, args = {
        n = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "A cover that sits over the Chat Panel's text and input line. The small eye button beside the chat turns it on and off, and so does /xui privacy. It only hides the chat visually; messages still arrive and are still logged." },
        on = { type = "toggle", order = 1, width = "full", name = "Cover the chat now", get = get("privOn"), set = set("privOn") },
        start = { type = "toggle", order = 2, width = "full", name = "Cover the chat at every login", get = get("privStartHidden"), set = set("privStartHidden") },
        btn = { type = "toggle", order = 3, width = "full", name = "Show the toggle button beside the chat", get = function() return S().privBtn ~= false end, set = set("privBtn") },
        bsize = { type = "range", order = 3.5, name = "Button size (pixels)", min = 16, max = 64, step = 1, get = get("privBtnSize"), set = set("privBtnSize") },
        balpha = { type = "range", order = 3.6, name = "Button opacity when the mouse is away (%)", min = 20, max = 100, step = 5, get = get("privBtnAlpha"), set = set("privBtnAlpha") },
        bx = { type = "range", order = 4, name = "Button: move right (pixels)", min = -100, max = 100, step = 1, get = get("privBtnX"), set = set("privBtnX") },
        by = { type = "range", order = 5, name = "Button: move up (pixels)", min = -100, max = 400, step = 1, get = get("privBtnY"), set = set("privBtnY") },
        lookHdr = { type = "header", order = 10, name = "Look" },
        mode = { type = "select", order = 11, name = "Fill with", values = { COLOR = "A color", TEXTURE = "A background texture", IMAGE = "A picture" }, sorting = { "COLOR", "TEXTURE", "IMAGE" },
            get = function() return S().privMode or "COLOR" end, set = set("privMode", true) },
        color = { type = "color", order = 12, name = "Color (the fill, a texture's tint, or behind a picture)", hasAlpha = true,
            get = function() local s = S(); return s.privR or 0, s.privG or 0, s.privB or 0, (tonumber(s.privFillA) or 100) / 100 end,
            set = function(_, r, g, b, a) local s = Store(); if s then s.privR, s.privG, s.privB = r, g, b; if a then s.privFillA = math.floor(a * 100 + 0.5) end end; ns.ChatPrivacy_Refresh() end },
        fillA = { type = "range", order = 12.5, name = "Color fill opacity (%)", desc = "How solid the color is. Set it to 0 to see only the texture or picture.", min = 0, max = 100, step = 5,
            get = function() return tonumber(S().privFillA) or 100 end, set = set("privFillA") },
        texA = { type = "range", order = 13, name = "Texture / picture opacity (%)", hidden = function() return (S().privMode or "COLOR") == "COLOR" end,
            desc = "How solid the background texture or picture is, on its own.", min = 0, max = 100, step = 5,
            get = function() return tonumber(S().privTexA) or 100 end, set = set("privTexA") },
        alpha = { type = "range", order = 13.5, name = "Whole cover opacity (%)", desc = "Fades everything on the cover together: fill, texture or picture, border, and label.", min = 5, max = 100, step = 5, get = get("privAlpha"), set = set("privAlpha") },
        tex = { type = "select", order = 14, name = "Background texture", hidden = mode("TEXTURE"),
            values = function()
                local v = {}
                for _, t in ipairs(BUILTIN_TEX) do v[t[1]] = t[2] end
                local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
                if lsm then for n in pairs(lsm:HashTable("background")) do v["lsm:" .. n] = n end end
                return v
            end,
            sorting = function()
                local o, names = {}, {}
                for _, t in ipairs(BUILTIN_TEX) do o[#o + 1] = t[1] end
                local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
                if lsm then for n in pairs(lsm:HashTable("background")) do names[#names + 1] = n end; table.sort(names); for _, n in ipairs(names) do o[#o + 1] = "lsm:" .. n end end
                return o
            end,
            get = get("privTexture"), set = set("privTexture") },
        tile = { type = "toggle", order = 15, name = "Tile the texture", hidden = mode("TEXTURE"), get = get("privTile"), set = set("privTile") },
        imgNote = { type = "description", order = 16, width = "full", hidden = mode("IMAGE"),
            name = "The game can only load .tga or .blp pictures that are inside its Interface folder (it cannot open files elsewhere on your computer). Copy your picture into Interface\\AddOns\\XayaUI_Media\\ and type its file name below (or a path starting at Interface\\). Sizes of 64, 128, 256, 512, or 1024 pixels work best. A brand-new file needs a full game restart, not /reload." },
        imgPick = { type = "select", order = 17, name = "Pick one of your listed pictures", hidden = mode("IMAGE"),
            values = function()
                pcall(ns.MergeUserMedia)
                local v = { [""] = "(none)" }
                for _, g in ipairs(ns.LocalGraphics or {}) do if g[1]:find("^%[User") then v[g[2]] = g[1] end end
                return v
            end,
            sorting = function()
                local o = { "" }
                for _, g in ipairs(ns.LocalGraphics or {}) do if g[1]:find("^%[User") then o[#o + 1] = g[2] end end
                return o
            end,
            get = get("privImageChoice"), set = set("privImageChoice", true) },
        imgPath = { type = "input", order = 18, width = "full", name = "Or type a picture path or file name (this wins over the list)", hidden = mode("IMAGE"),
            get = get("privPath"), set = set("privPath", true) },
        imgStatus = { type = "description", order = 19, width = "full", hidden = mode("IMAGE"),
            name = function() local s = S(); local p, why = CurrentImage(s)
                if p then return "Using: " .. p .. "\n(A wrong name or an unsupported file draws nothing, so you see the color instead.)" end
                if why == "outside" then return "The game cannot read files outside its Interface folder. Copy the picture into Interface\\AddOns\\XayaUI_Media\\ and type just its file name." end
                return "No picture chosen: the cover shows the color." end },
        border = { type = "toggle", order = 20, name = "Border", get = get("privBorder"), set = set("privBorder") },
        showText = { type = "toggle", order = 21, name = "Show a label on the cover", get = get("privShowText"), set = set("privShowText") },
        text = { type = "input", order = 22, name = "Label", get = get("privText"), set = set("privText") },
        areaHdr = { type = "header", order = 30, name = "Area and behavior" },
        tabs = { type = "toggle", order = 31, width = "full", name = "Also cover the chat tabs", get = get("privCoverTabs"), set = set("privCoverTabs") },
        reveal = { type = "toggle", order = 33, width = "full", name = "Cover fades away while the mouse is over it", get = get("privReveal"), set = set("privReveal") },
    } }
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
local function TogglePrivacy()
    if ns.ChatPrivacy_Set and ns.chatDB then ns.ChatPrivacy_Set(not ns.chatDB.privOn) end
end
ns.RegisterCommand("privacy", function()
    if not ns.chatDB then return end
    TogglePrivacy(); ns.Print("chat privacy cover " .. (ns.chatDB.privOn and "ON" or "OFF"))
end, "/xui privacy (cover or show the chat)")
ns.RegisterLauncher({ "privacy", "Chat privacy cover", "Cover or show the chat (also /xui privacy)", TogglePrivacy,
    function() return ns.chatDB and ns.chatDB.privOn and "on" or "off" end, order = 50 })
