-------------------------------------------------------------------------------
-- GameMenu.lua : adds a "XayaUI" button to the Game Menu (the ESC menu) that opens the XayaUI settings window.
-- Written against Blizzard's own GameMenuFrame only (no other addon's code). Settings > UI Options > Display >
-- "Menu button (ESC menu)": show toggle and style. /xui gamemenu prints diagnostics.
--
-- How it works (rewritten 0.5.41 after "Return to Game" showed Blizzard's red art):
--   * Blizzard rebuilds the menu from a pool of recycled buttons on every open (GameMenuFrame:InitButtons), and other skins (EllesmereUI)
--     restyle those pooled buttons once. So this file NEVER edits a pooled button's art, font, or color.
--   * It asks the frame for a layout SLOT through the frame's own AddButton (so spacing and menu height stay right), moves the slot
--     to sit after "Macros" (layoutIndex), sizes it like the Macros button, and makes the slot invisible (frame alpha only, put back
--     to 1 the next time the menu is built, because the pool recycles it).
--   * Our own permanent button (a plain Button we create once) is drawn over the slot, sized like the Macros button. All the look is ours.
--   * If AddButton does not exist, an empty frame with a layoutIndex is the slot instead.
-- Style (Settings): "gradient" = class-colored gradient fill, solid text; "standard" = the theme's flat button fill, class-colored gradient text.
-- Untested in game as of this build; the diagnostics line says what ran.
-------------------------------------------------------------------------------
local addonName, ns = ...

local LABEL = "XayaUI"
local diag = { path = "none", hooked = false, anchor = "none", opens = 0, paints = 0, lastError = nil, sizes = "n/a" }
ns.GameMenuDiag = diag

local function Enabled()
    local ui = CueRulesDB and CueRulesDB.ui
    return not (ui and ui.hideGameMenuButton)
end

local function Style()
    local ui = CueRulesDB and CueRulesDB.ui
    return (ui and ui.gameMenuStyle == "standard") and "standard" or "gradient"
end

local function OpenXayaUI()
    diag.opens = diag.opens + 1
    pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 852)
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
-- Colors
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
local function Hex(c) return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
-- per-letter color escapes: a gradient inside a plain FontString
local function GradText(str, c1, c2)
    local n, out = #str, {}
    for i = 1, n do
        local t = n > 1 and (i - 1) / (n - 1) or 0
        out[#out + 1] = Hex({ c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t, c1[3] + (c2[3] - c1[3]) * t }) .. str:sub(i, i)
    end
    return table.concat(out) .. "|r"
end

-------------------------------------------------------------------------------
-- Our button (created once, never pooled)
-------------------------------------------------------------------------------
local btn
local sibling   -- the Macros (or fallback) button we copy font and size from; only read, never changed

local function Paint()
    if not btn then return end
    local bg, bd, tx = Col("bg", { 0.04, 0.04, 0.04, 0.7 }), Col("border", { 0.25, 0.25, 0.25, 1 }), Col("text", { 1, 0.82, 0, 1 })
    local ac = Accent()
    local hover, pressed = btn.hover, btn.pressed
    local fill = bg
    if pressed then fill = { math.min(1, bg[1] + 0.10), math.min(1, bg[2] + 0.10), math.min(1, bg[3] + 0.10), math.max(bg[4], 0.9) } end
    local style = Style()
    if style == "gradient" then
        local k = pressed and 0.70 or (hover and 0.62 or 0.48)
        local left = { ac[1] * k, ac[2] * k, ac[3] * k, math.max(fill[4], 0.95) }
        btn.bg:SetColorTexture(1, 1, 1, 1)
        local ok = pcall(function()
            btn.bg:SetGradient("HORIZONTAL", CreateColor(left[1], left[2], left[3], left[4]), CreateColor(fill[1], fill[2], fill[3], fill[4]))
        end)
        if not ok then btn.bg:SetColorTexture(left[1], left[2], left[3], left[4]) end
    else
        btn.bg:SetColorTexture(fill[1], fill[2], fill[3], fill[4])
    end
    local e = hover and ac or bd
    for i = 1, 4 do btn.e[i]:SetColorTexture(e[1], e[2], e[3], e[4] or 1) end
    btn.glow:SetColorTexture(ac[1], ac[2], ac[3], 1); btn.glow:SetAlpha(hover and 0.28 or 0)
    -- font: copy the Macros button's (read only) so the label matches the other entries
    local sfs = sibling and sibling.GetFontString and sibling:GetFontString()
    if sfs then
        local font, size, flags = sfs:GetFont()
        if font and size then btn.fs:SetFont(font, size, flags or "") end
    elseif not btn.fs:GetFont() then
        btn.fs:SetFontObject(GameFontNormal)
    end
    if style == "standard" then
        btn.fs:SetTextColor(1, 1, 1, 1)
        btn.fs:SetText(GradText(LABEL, ac, { ac[1] + (1 - ac[1]) * 0.7, ac[2] + (1 - ac[2]) * 0.7, ac[3] + (1 - ac[3]) * 0.7 }))
    else
        btn.fs:SetTextColor(tx[1], tx[2], tx[3], tx[4] or 1)
        btn.fs:SetText(LABEL)
    end
    diag.paints = diag.paints + 1
end

local function CreateButton(menu)
    if btn then return btn end
    local b = CreateFrame("Button", "XayaUI_GameMenuButton", menu)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", OpenXayaUI)
    b.bg = b:CreateTexture(nil, "BACKGROUND", nil, -3); b.bg:SetAllPoints(b)
    b.e = {}
    for i = 1, 4 do b.e[i] = b:CreateTexture(nil, "BACKGROUND", nil, -2) end
    b.e[1]:SetPoint("TOPLEFT"); b.e[1]:SetPoint("TOPRIGHT"); b.e[1]:SetHeight(1)
    b.e[2]:SetPoint("BOTTOMLEFT"); b.e[2]:SetPoint("BOTTOMRIGHT"); b.e[2]:SetHeight(1)
    b.e[3]:SetPoint("TOPLEFT"); b.e[3]:SetPoint("BOTTOMLEFT"); b.e[3]:SetWidth(1)
    b.e[4]:SetPoint("TOPRIGHT"); b.e[4]:SetPoint("BOTTOMRIGHT"); b.e[4]:SetWidth(1)
    b.glow = b:CreateTexture(nil, "ARTWORK"); b.glow:SetPoint("TOPLEFT", 1, -1); b.glow:SetPoint("BOTTOMRIGHT", -1, 1); b.glow:SetBlendMode("ADD")
    b.fs = b:CreateFontString(nil, "OVERLAY"); b.fs:SetPoint("CENTER", 0, 0)
    b:SetScript("OnEnter", function(self) self.hover = true; Paint() end)
    b:SetScript("OnLeave", function(self) self.hover, self.pressed = false, false; Paint() end)
    b:SetScript("OnMouseDown", function(self) self.pressed = true; Paint() end)
    b:SetScript("OnMouseUp", function(self) self.pressed = false; Paint() end)
    b:SetScript("OnShow", function(self) self.hover, self.pressed = false, false; Paint() end)
    btn = b
    return b
end

-- repaint when the theme / class colors change
if ns.Theme and ns.Theme.OnResolve then
    ns.Theme.OnResolve(function() if btn and btn:IsShown() then Paint() end end)
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
        if not b.xuiGMslot then
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

local fallbackSlot
local function Place(slot, anchor)
    -- size the slot (and our button) like the Macros button
    local w, h = anchor:GetWidth(), anchor:GetHeight()
    if w and h and w > 0 and h > 0 then
        slot:SetSize(w, h)
        btn:SetSize(w, h)
    end
    btn:ClearAllPoints(); btn:SetPoint("CENTER", slot, "CENTER", 0, 0)
    btn:SetFrameLevel((slot:GetFrameLevel() or 1) + 5)
    diag.sizes = ("macros %.0fx%.0f, slot %.0fx%.0f, ours %.0fx%.0f"):format(w or 0, h or 0, slot:GetWidth() or 0, slot:GetHeight() or 0, btn:GetWidth() or 0, btn:GetHeight() or 0)
end

local function Install(menu)
    -- the pool recycles buttons: a slot we made invisible last time may now be a real menu entry, so put its alpha back
    if menu.buttonPool and menu.buttonPool.EnumerateActive then
        for b in menu.buttonPool:EnumerateActive() do
            if b.xuiGMslot then b.xuiGMslot = nil; b:SetAlpha(1) end
        end
    end
    CreateButton(menu)
    if not Enabled() then btn:Hide(); if fallbackSlot then fallbackSlot:Hide() end; return end

    local anchor, anchorText = FindAnchor(menu)
    diag.anchor = anchorText or "none (appended)"
    sibling = anchor
    local slot
    if type(menu.AddButton) == "function" then
        diag.path = "A (AddButton slot)"
        local before = ActiveSet(menu)
        menu:AddButton(LABEL, OpenXayaUI)
        if menu.buttonPool and menu.buttonPool.EnumerateActive then
            for b in menu.buttonPool:EnumerateActive() do
                if not before[b] then slot = b end
            end
        end
        if slot then
            if anchor and anchor.layoutIndex then slot.layoutIndex = anchor.layoutIndex + 0.5 end
            slot.xuiGMslot = true
            slot:SetAlpha(0)   -- frame alpha only; undone above on the next build
        end
    else
        diag.path = "B (empty slot frame)"
        fallbackSlot = fallbackSlot or CreateFrame("Frame", nil, menu)
        slot = fallbackSlot
        if anchor then slot.layoutIndex = (anchor.layoutIndex or 0) + 0.5 end
        slot:Show()
    end
    if not slot then btn:Hide(); diag.lastError = "no slot created"; return end
    if anchor then Place(slot, anchor) else btn:SetPoint("CENTER", slot, "CENTER") end
    btn:Show()
    Paint()
    if menu.Layout then menu:Layout() end
    -- other skins may resize the menu buttons after us: check once more next frame
    if anchor and C_Timer then
        C_Timer.After(0, function()
            if btn and btn:IsShown() and slot and anchor then Place(slot, anchor); if menu.Layout then menu:Layout() end end
        end)
    end
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
    ns.Print(("game menu button: enabled=%s style=%s hooked=%s path=%s anchor=%s opens=%d paints=%d lastError=%s AddButton=%s InitButtons=%s"):format(
        tostring(Enabled()), Style(), tostring(diag.hooked), diag.path, diag.anchor, diag.opens, diag.paints, tostring(diag.lastError),
        tostring(GameMenuFrame and type(GameMenuFrame.AddButton) == "function"),
        tostring(GameMenuFrame and type(GameMenuFrame.InitButtons) == "function")))
    ns.Print("game menu sizes: " .. tostring(diag.sizes))
end

function ns.GameMenu_Repaint() if btn and btn:IsShown() then Paint() end end

-- Toggling the option while the menu is open takes effect the next time the menu opens.
function ns.GameMenu_OnOptionChanged()
    if GameMenuFrame and GameMenuFrame:IsShown() then ns.Print("the Game Menu button change applies the next time you open the menu.") end
end
