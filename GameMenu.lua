-------------------------------------------------------------------------------
-- GameMenu.lua : adds a "XayaUI" button to the Game Menu (the ESC menu) that opens the XayaUI settings window.
-- Written against Blizzard's own GameMenuFrame only (no other addon's code). Settings > UI Options >
-- "Show XayaUI button in the Game Menu" turns it off (CueRulesDB.ui.hideGameMenuButton). /xui gamemenu prints diagnostics.
--
-- Path A (preferred): Blizzard rebuilds the menu on every open (GameMenuFrame:InitButtons). After it runs we ask the frame
--   to add one button through its own AddButton, then move that button to sit right after "Macros" (layoutIndex) and re-layout.
-- Path B (fallback, only if AddButton is missing): a child Button using Blizzard's MainMenuFrameButtonTemplate with a layoutIndex.
-- Untested in game as of this build; the diagnostics line says which path ran.
-------------------------------------------------------------------------------
local addonName, ns = ...

local LABEL = "|cff33ccffXayaUI|r"
local diag = { path = "none", hooked = false, anchor = "none", opens = 0, lastError = nil }
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

-- Blizzard button label text -> anchor so ours lands inside the AddOns / Macros group.
local function FindAnchor(menu)
    local wanted = { MACROS, GAMEMENU_SUPPORT, ADDONS }   -- in preference order (global strings; nil entries are skipped)
    local found = {}
    if not (menu.buttonPool and menu.buttonPool.EnumerateActive) then return nil end
    for b in menu.buttonPool:EnumerateActive() do
        local ok, t = pcall(b.GetText, b)
        if ok and t then found[t] = b end
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
    if not Enabled() then
        if fallbackBtn then fallbackBtn:Hide() end
        return
    end
    local anchor, anchorText = FindAnchor(menu)
    diag.anchor = anchorText or "none (appended)"

    if type(menu.AddButton) == "function" then
        diag.path = "A (AddButton)"
        local before = ActiveSet(menu)
        menu:AddButton(LABEL, OpenXayaUI)
        if anchor and anchor.layoutIndex and menu.buttonPool and menu.buttonPool.EnumerateActive then
            for b in menu.buttonPool:EnumerateActive() do
                if not before[b] then b.layoutIndex = anchor.layoutIndex + 0.5 end
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
    ns.Print(("game menu button: enabled=%s hooked=%s path=%s anchor=%s opens=%d lastError=%s AddButton=%s InitButtons=%s"):format(
        tostring(Enabled()), tostring(diag.hooked), diag.path, diag.anchor, diag.opens, tostring(diag.lastError),
        tostring(GameMenuFrame and type(GameMenuFrame.AddButton) == "function"),
        tostring(GameMenuFrame and type(GameMenuFrame.InitButtons) == "function")))
end

-- Toggling the option while the menu is open takes effect the next time the menu opens.
function ns.GameMenu_OnOptionChanged()
    if GameMenuFrame and GameMenuFrame:IsShown() then ns.Print("the Game Menu button change applies the next time you open the menu.") end
end
