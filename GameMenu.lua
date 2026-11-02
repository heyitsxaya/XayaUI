-------------------------------------------------------------------------------
-- GameMenu.lua : adds a "XayaUI" button to the Game Menu (the ESC menu) that opens the XayaUI settings window.
-- Written against Blizzard's own GameMenuFrame only (no other addon's code). Settings > UI Options >
-- "Show XayaUI button in the Game Menu" turns it off (CueRulesDB.ui.hideGameMenuButton). /xui gamemenu prints diagnostics.
--
-- Look: the same flat theme button as the settings window (class "xui-button": fill, 1px outline, text color from Theme.lua, so it
-- follows the class-color base theme and any saved theme). Blizzard's red art is hidden (alpha only, undone when the pooled button is
-- reused for another menu entry); hover = flat accent glow + accent outline, press = lighter fill. No animation: instant.
--
-- Path A (preferred): Blizzard rebuilds the menu on every open (GameMenuFrame:InitButtons). After it runs we ask the frame
--   to add one button through its own AddButton, then move that button to sit right after "Macros" (layoutIndex) and re-layout.
-- Path B (fallback, only if AddButton is missing): a child Button using Blizzard's MainMenuFrameButtonTemplate with a layoutIndex.
-- Untested in game as of this build; the diagnostics line says which path ran.
-------------------------------------------------------------------------------
local addonName, ns = ...

local LABEL = "XayaUI"
local diag = { path = "none", hooked = false, anchor = "none", opens = 0, lastError = nil, skinned = 0 }
ns.GameMenuDiag = diag

local function Enabled()
    local ui = CueRulesDB and CueRulesDB.ui
    return not (ui and ui.hideGameMenuButton)
end

local function OpenXayaUI()
    diag.opens = diag.opens + 1
    -- close the menu first, like Blizzard's own entries; never let a blocked hide stop the window from opening
    if GameMenuFrame and GameMenuFrame:IsShown() then
        if InCombatLockdown() then
            pcall(GameMenuFrame.Hide, GameMenuFrame)
        else
            pcall(HideUIPanel, GameMenuFrame)
        end
    end
    if ns.ToggleUI then ns.ToggleUI() else ns.Print("settings window is not available.") end
end

-------------------------------------------------------------------------------
-- Skin: flat theme button
-------------------------------------------------------------------------------
local function Col(prop, fb)
    local T = ns.Theme
    if T and T.Col then return T.Col("xui-button", prop, fb) end
    return { fb[1], fb[2], fb[3], fb[4] or 1 }
end
local function Accent()
    local T = ns.Theme
    local c = T and T.cur and T.cur.accent
    if c then return { c[1], c[2], c[3], c[4] or 1 } end
    local ok, _, file = pcall(UnitClass, "player")
    local rc = ok and file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if rc then return { rc.r, rc.g, rc.b, 1 } end
    return { 0.75, 0.25, 1, 1 }
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local current   -- the one button that carries the skin right now

local function Paint(b)
    local s = b.xuiGM
    if not s then return end
    local bg, bd, tx = Col("bg", { 0.04, 0.04, 0.04, 0.7 }), Col("border", { 0.25, 0.25, 0.25, 1 }), Col("text", { 1, 0.82, 0, 1 })
    local ac = Accent()
    local hover = s.hover
    local pressed = s.pressed
    local fill = bg
    if pressed then fill = { math.min(1, bg[1] + 0.10), math.min(1, bg[2] + 0.10), math.min(1, bg[3] + 0.10), math.max(bg[4], 0.9) } end
    -- class-themed gradient: dark class color on the left fading into the theme's button fill on the right (brighter on hover / press)
    local k = pressed and 0.70 or (hover and 0.62 or 0.48)
    local left = { ac[1] * k, ac[2] * k, ac[3] * k, math.max(fill[4], 0.95) }
    s.bg:SetColorTexture(1, 1, 1, 1)
    local ok = pcall(function()
        s.bg:SetGradient("HORIZONTAL", CreateColor(left[1], left[2], left[3], left[4]), CreateColor(fill[1], fill[2], fill[3], fill[4]))
    end)
    if not ok then s.bg:SetColorTexture(left[1], left[2], left[3], left[4]) end
    local e = hover and ac or bd
    for i = 1, 4 do s.e[i]:SetColorTexture(e[1], e[2], e[3], e[4] or 1) end
    s.glow:SetColorTexture(ac[1], ac[2], ac[3], 1); s.glow:SetAlpha(hover and 0.28 or 0)
    local fs = b.GetFontString and b:GetFontString()
    if fs then fs:SetTextColor(tx[1], tx[2], tx[3], tx[4] or 1) end
end

local function Skin(b)
    if not b.xuiGM then
        local s = { e = {} }
        s.bg = b:CreateTexture(nil, "BACKGROUND", nil, -3)
        s.bg:SetAllPoints(b)
        for i = 1, 4 do s.e[i] = b:CreateTexture(nil, "BACKGROUND", nil, -2) end
        s.e[1]:SetPoint("TOPLEFT"); s.e[1]:SetPoint("TOPRIGHT"); s.e[1]:SetHeight(1)
        s.e[2]:SetPoint("BOTTOMLEFT"); s.e[2]:SetPoint("BOTTOMRIGHT"); s.e[2]:SetHeight(1)
        s.e[3]:SetPoint("TOPLEFT"); s.e[3]:SetPoint("BOTTOMLEFT"); s.e[3]:SetWidth(1)
        s.e[4]:SetPoint("TOPRIGHT"); s.e[4]:SetPoint("BOTTOMRIGHT"); s.e[4]:SetWidth(1)
        s.glow = b:CreateTexture(nil, "ARTWORK", nil, 1)
        s.glow:SetPoint("TOPLEFT", 1, -1); s.glow:SetPoint("BOTTOMRIGHT", -1, 1); s.glow:SetBlendMode("ADD")
        b.xuiGM = s
        b:HookScript("OnEnter", function(self) if self.xuiGMon then self.xuiGM.hover = true; Paint(self) end end)
        b:HookScript("OnLeave", function(self) if self.xuiGMon then self.xuiGM.hover = false; self.xuiGM.pressed = false; Paint(self) end end)
        b:HookScript("OnMouseDown", function(self) if self.xuiGMon then self.xuiGM.pressed = true; Paint(self) end end)
        b:HookScript("OnMouseUp", function(self) if self.xuiGMon then self.xuiGM.pressed = false; Paint(self) end end)
        b:HookScript("OnShow", function(self) if self.xuiGMon then Paint(self) end end)
    end
    local s = b.xuiGM
    -- hide Blizzard's art by alpha (remember the originals so a reused pooled button can be put back)
    if not b.xuiGMon then
        s.regions = {}
        for _, r in ipairs({ b:GetRegions() }) do
            if r:GetObjectType() == "Texture" and r ~= s.bg and r ~= s.glow and not tContains(s.e, r) then
                s.regions[#s.regions + 1] = { r, r:GetAlpha() }
                r:SetAlpha(0)
            end
        end
        local fs = b.GetFontString and b:GetFontString()
        if fs then s.fsColor = { fs:GetTextColor() } end
        b.xuiGMon = true
    end
    s.hover, s.pressed = false, false
    s.bg:Show(); s.glow:Show(); for i = 1, 4 do s.e[i]:Show() end
    current = b
    diag.skinned = diag.skinned + 1
    Paint(b)
end

local function Unskin(b)
    local s = b.xuiGM
    if not (s and b.xuiGMon) then return end
    b.xuiGMon = nil
    s.bg:Hide(); s.glow:Hide(); for i = 1, 4 do s.e[i]:Hide() end
    for _, p in ipairs(s.regions or {}) do p[1]:SetAlpha(p[2]) end
    local fs = b.GetFontString and b:GetFontString()
    if fs and s.fsColor then fs:SetTextColor(unpack(s.fsColor)) end
    if current == b then current = nil end
end

-- repaint when the theme / class colors change
if ns.Theme and ns.Theme.OnResolve then
    ns.Theme.OnResolve(function() if current and current.xuiGMon then Paint(current) end end)
end

-------------------------------------------------------------------------------
-- Menu wiring
-------------------------------------------------------------------------------
-- Blizzard button label text -> anchor so ours lands inside the AddOns / Macros group.
local function FindAnchor(menu)
    local wanted = { MACROS, GAMEMENU_SUPPORT, ADDONS }   -- in preference order (global strings; nil entries are skipped)
    local found = {}
    if not (menu.buttonPool and menu.buttonPool.EnumerateActive) then return nil end
    for b in menu.buttonPool:EnumerateActive() do
        if not b.xuiGMon then
            local ok, t = pcall(b.GetText, b)
            if ok and t then found[t] = b end
        end
    end
    for _, text in ipairs(wanted) do
        if text and found[text] then return found[text], text end
    end
end

local function ActiveSet(menu)
    local set = {}
    if menu.buttonPool and menu.buttonPool.EnumerateActive then
        for b in menu.buttonPool:EnumerateActive() do set[b] = true end
    end
    return set
end

local fallbackBtn
local function Install(menu)
    -- a pooled button we skinned last time may have been handed back out as another menu entry: undo the skin on every one but ours
    if menu.buttonPool and menu.buttonPool.EnumerateActive then
        for b in menu.buttonPool:EnumerateActive() do if b.xuiGMon then Unskin(b) end end
    end
    if not Enabled() then
        if fallbackBtn then Unskin(fallbackBtn); fallbackBtn:Hide() end
        return
    end
    local anchor, anchorText = FindAnchor(menu)
    diag.anchor = anchorText or "none (appended)"

    if type(menu.AddButton) == "function" then
        diag.path = "A (AddButton)"
        local before = ActiveSet(menu)
        menu:AddButton(LABEL, OpenXayaUI)
        if menu.buttonPool and menu.buttonPool.EnumerateActive then
            for b in menu.buttonPool:EnumerateActive() do
                if not before[b] then
                    if anchor and anchor.layoutIndex then b.layoutIndex = anchor.layoutIndex + 0.5 end
                    Skin(b)
                end
            end
        end
    else
        diag.path = "B (own button)"
        if not fallbackBtn then
            fallbackBtn = CreateFrame("Button", "XayaUI_GameMenuButton", menu, "MainMenuFrameButtonTemplate")
            fallbackBtn:SetScript("OnClick", OpenXayaUI)
        end
        fallbackBtn:SetText(LABEL)
        if anchor then
            fallbackBtn:SetSize(anchor:GetWidth(), anchor:GetHeight())
            fallbackBtn.layoutIndex = (anchor.layoutIndex or 0) + 0.5
        end
        fallbackBtn:Show()
        Skin(fallbackBtn)
    end
    if menu.Layout then menu:Layout() end
end

local function Hook()
    if diag.hooked or not GameMenuFrame then return end
    local function run(menu)
        local ok, err = pcall(Install, menu)
        if not ok then diag.lastError = tostring(err); if ns.CaptureError then ns.CaptureError(err) end end
    end
    if type(GameMenuFrame.InitButtons) == "function" then
        hooksecurefunc(GameMenuFrame, "InitButtons", run)
    else
        GameMenuFrame:HookScript("OnShow", run)   -- very old layout: no InitButtons
    end
    diag.hooked = true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() Hook() end)

function ns.GameMenu_Diagnostics()
    ns.Print(("game menu button: enabled=%s hooked=%s path=%s anchor=%s opens=%d skinned=%d lastError=%s AddButton=%s InitButtons=%s"):format(
        tostring(Enabled()), tostring(diag.hooked), diag.path, diag.anchor, diag.opens, diag.skinned, tostring(diag.lastError),
        tostring(GameMenuFrame and type(GameMenuFrame.AddButton) == "function"),
        tostring(GameMenuFrame and type(GameMenuFrame.InitButtons) == "function")))
end

-- Toggling the option while the menu is open takes effect the next time the menu opens.
function ns.GameMenu_OnOptionChanged()
    if GameMenuFrame and GameMenuFrame:IsShown() then ns.Print("the Game Menu button change applies the next time you open the menu.") end
end
