-------------------------------------------------------------------------------
-- GameMenu.lua : adds a "XayaUI" button to the Game Menu (the ESC menu) that opens the XayaUI settings window.
-- Written against Blizzard's own GameMenuFrame only (no other addon's code). Settings > UI Options > Display >
-- "Menu button (ESC menu)": show toggle and style. /xui gamemenu prints diagnostics.
--
-- How it works (rewritten 0.5.41 after "Return to Game" showed Blizzard's red art):
--   * Blizzard rebuilds the menu from a pool of recycled buttons on every open (GameMenuFrame:InitButtons), and other skins
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

-- V14 (core 0.6.47; Xaya 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to
-- performance cost / demand in any way"): `live` is the switch "Show a XayaUI button in the Game Menu", cached. While it is off, nothing
-- of this file is made or placed (no frame, no event, no hook, no theme listener); hooks placed while it was on return at once on it.
local live = false

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

-- Xaya 2026-11-04: "game menu when button is enabled clips incorrectly" (the menu's box ended at the bottom of Return to Game). The
-- menu's own Layout sizes it from its layout entries only; a button another addon places itself (and the extra height it gave the
-- menu) is lost when this file calls Layout after adding its slot. INFERENCE from her screenshot (an EllesmereUI button in the menu)
-- and the fact that it clips only with this button on. So after laying out, the menu is made at least as tall as its lowest shown
-- button plus the bottom padding it had before this file touched it; it is never made shorter.
local function LowestButton(menu)
    local lowest
    local ok, kids = pcall(function() return { menu:GetChildren() } end)
    if not (ok and type(kids) == "table") then return nil end
    for _, ch in ipairs(kids) do
        local okS, shown = pcall(ch.IsShown, ch)
        local okT, ot = pcall(ch.GetObjectType, ch)
        if okS and shown and okT and ot == "Button" then
            local okB, b = pcall(ch.GetBottom, ch)
            local okH, h = pcall(ch.GetHeight, ch)
            if okB and type(b) == "number" and okH and type(h) == "number" and h > 0 and (not lowest or b < lowest) then lowest = b end
        end
    end
    return lowest
end
local function BottomGap(menu)
    local low = LowestButton(menu)
    local okB, mb = pcall(menu.GetBottom, menu)
    if low and okB and type(mb) == "number" then return low - mb end
end
-- The height follows the buttons, shorter as well as taller (core 0.6.39). Core 0.6.32-0.6.38 only ever made it taller and measured
-- the padding again on every open, from the menu as already drawn; a menu whose own layout keeps its height then took the last
-- open's extra row for padding and grew by a row each open (Xaya 2026-11-04: "escape menu looks sus", "closing and reopening the esc
-- menu made it even larger").
local function FitHeight(menu, pad)
    local gap = BottomGap(menu)
    if not gap or not pad then return end
    if math.abs(gap - pad) > 0.5 then
        local okH, h = pcall(menu.GetHeight, menu)
        if okH and type(h) == "number" then pcall(menu.SetHeight, menu, math.max(1, h + (pad - gap))) end
    end
    diag.fit = ("bottom gap %.0f, wanted %.0f"):format(gap, pad)
end
-- The menu's own bottom padding, measured once: the first time the menu is built with the XayaUI row, before this file adds or fits
-- anything. A reading above PAD_MAX is not padding (INFERENCE: a menu already stretched by something else) and the fallback is used.
local naturalPad
local PAD_FALLBACK, PAD_MAX = 16, 60
function ns.GameMenuResetPad() naturalPad = nil end   -- (tests)
ns.GameMenuFitHeight = FitHeight   -- (tests)

local fallbackSlot
local function ResetSlots(menu)
    if menu.buttonPool and menu.buttonPool.EnumerateActive then
        for b in menu.buttonPool:EnumerateActive() do
            if b.xuiGMslot then b.xuiGMslot = nil; b:SetAlpha(1) end
        end
    end
end
-- switched off: our button and slot frame hidden, a pooled button made invisible by the last build given its alpha back
local leftover = false   -- (the switch went off while the menu was open: done at the menu's next build)
local function TidyUp(menu)
    leftover = false
    if btn then btn:Hide() end
    if fallbackSlot then fallbackSlot:Hide() end
    ResetSlots(menu)
end
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
    ResetSlots(menu)
    -- the skin (GameMenuSkin.lua) in OWN LAYOUT mode draws its own XayaUI row; in MATCH mode it needs the real slot below (it draws on it)
    local skin = ns.Service("gameMenuSkin")   -- XayaUI_Reskin, when it is on (Modules.lua section 8)
    local skinOn = skin and skin.Active()
    local match = skinOn and skin.MatchReal()
    if (skinOn and not match) or not Enabled() then if btn then btn:Hide() end; if fallbackSlot then fallbackSlot:Hide() end; return end
    CreateButton(menu)   -- (core 0.6.47: only when the button is drawn; it was made on every open, also with the switch off)

    if not naturalPad then
        local g = BottomGap(menu)   -- the bottom padding as the menu was drawn before this file added anything, the first time
        naturalPad = (g and g > 0 and g <= PAD_MAX) and g or PAD_FALLBACK
        diag.pad = ("natural bottom padding %.0f (read %s)"):format(naturalPad, g and ("%.0f"):format(g) or "nothing")
    end
    local padBefore = naturalPad
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
    if match then btn:Hide() else btn:Show(); Paint() end   -- in match mode the skin draws the row on the slot
    if menu.Layout then menu:Layout() end
    FitHeight(menu, padBefore)
    -- other skins may resize the menu buttons after us: check once more next frame
    if C_Timer then
        C_Timer.After(0, function()
            if anchor and btn and btn:IsShown() and slot then Place(slot, anchor); if menu.Layout then menu:Layout() end end
            FitHeight(menu, padBefore)
        end)
    end
end

local function Hook()
    if diag.hooked or not GameMenuFrame then return end
    local function run(menu)
        -- switched off after it was on: the hook stays (the game cannot take a hook back) and returns at once, after tidying up, once,
        -- what the last build left when the switch went off with the menu open
        if not live then if leftover then pcall(TidyUp, menu) end; return end
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
-- repaint when the theme / class colors change: a listener only while the button is on (Theme.lua OnResolve / OffResolve)
local function OnTheme() if live and btn and btn:IsShown() then Paint() end end
local themeOn = false
local function ThemeListen(on)
    local T = ns.Theme
    if on and not themeOn and T and T.OnResolve then T.OnResolve(OnTheme); themeOn = true
    elseif not on and themeOn and T and T.OffResolve then T.OffResolve(OnTheme); themeOn = false end
end

-- Enable: the hooks are placed at PLAYER_LOGIN when the button is saved on (the moment they were always placed), at once when it is
-- switched on later (the login has passed then). Disable: hides the button now; a slot this file made invisible is put back now when the menu is closed, else
-- at the menu's next build (the change applies the next time the menu opens, as the switch says).
local function Enable()
    live = true
    ThemeListen(true)
    if diag.hooked then return end
    ns.AtLogin(function() if live then Hook() end end)   -- (Modules.lua: at PLAYER_LOGIN, or at once after it)
end
local function Disable()
    live = false
    ThemeListen(false)
    local menu = GameMenuFrame
    if menu and menu.IsShown and menu:IsShown() then leftover = true   -- open now: it stays as drawn until the menu is built again
    elseif menu then TidyUp(menu) end
end
ns.WhenReady(function() if Enabled() then Enable() end end)
function ns.GameMenu_Live() return live end   -- (tests)

function ns.GameMenu_Diagnostics()
    ns.Print(("game menu button: enabled=%s style=%s hooked=%s path=%s anchor=%s opens=%d paints=%d lastError=%s AddButton=%s InitButtons=%s"):format(
        tostring(Enabled()), Style(), tostring(diag.hooked), diag.path, diag.anchor, diag.opens, diag.paints, tostring(diag.lastError),
        tostring(GameMenuFrame and type(GameMenuFrame.AddButton) == "function"),
        tostring(GameMenuFrame and type(GameMenuFrame.InitButtons) == "function")))
    ns.Print("game menu sizes: " .. tostring(diag.sizes) .. "; height fit: " .. tostring(diag.fit) .. "; " .. tostring(diag.pad))
end

function ns.GameMenu_Repaint() if btn and btn:IsShown() then Paint() end end

-- Toggling the option while the menu is open takes effect the next time the menu opens. (Settings > UI Options > Display calls this
-- right after it saved the switch.)
function ns.GameMenu_OnOptionChanged()
    if Enabled() then Enable() else Disable() end
    if GameMenuFrame and GameMenuFrame:IsShown() then ns.Print("the Game Menu button change applies the next time you open the menu.") end
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
ns.RegisterCommand("gamemenu", function() ns.GameMenu_Diagnostics() end, "/xui gamemenu (ESC menu diagnostics)")
