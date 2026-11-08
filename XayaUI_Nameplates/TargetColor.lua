-------------------------------------------------------------------------------
-- TargetColor.lua (XayaUI_Nameplates 0.1.0): your target's health bar in one colour (default teal).
--
-- How: one texture of ours lies over the filled part of the target's Blizzard health bar (anchored to the bar's own fill texture, so it
-- follows the fill without reading the health value). Only the current target's texture is shown.
-- When: PLAYER_TARGET_CHANGED, and NAME_PLATE_UNIT_ADDED / _REMOVED (the target's plate can appear after the target is chosen, and
-- Blizzard re-uses plate frames). Added / removed are handled on the next frame, once Blizzard has set the plate up or released it.
-- Nothing per frame and nothing per tick; no health, name or aura is read.
-- "Which plate is my target?" is asked as C_NamePlate.GetNamePlateForUnit("target"), never UnitIsUnit(plate, "target"): UnitIsUnit is
-- SecretWhenUnitComparisonRestricted (docs/reference/api/globals.md), GetNamePlateForUnit compares nothing (INFERENCE that it answers
-- in Mythic+ combat; the QA walkthrough checks it). Forbidden plates are never asked for (includeForbidden stays false).
-- Off (V14): no frame, no event, no texture, no timer. Turning it off hides the shown texture and unregisters everything.
-- UNTESTED IN GAME.
-------------------------------------------------------------------------------
local _, NP = ...
if not NP.ns then return end

local TC = {}
NP.TargetColor = TC

local driver                                      -- the event frame; made the first time the behaviour is switched on
local overlays = setmetatable({}, { __mode = "k" }) -- Blizzard health bar -> our texture on it
local shown, shownBar                             -- the texture now shown, and its bar
local pending                                     -- a next-frame refresh is queued
local last = "not run yet"                        -- what the last refresh found (for /xui nameplates)

local function PlateFor(unit)
    local N = C_NamePlate
    if not (N and N.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(N.GetNamePlateForUnit, unit)
    if ok then return plate end
end

local function HealthBarOf(plate)
    local uf = plate and plate.UnitFrame
    local box = uf and uf.HealthBarsContainer
    return box and box.healthBar
end

local function Hide()
    if shown then shown:Hide() end
    shown, shownBar = nil, nil
end

local function ShowOn(bar)
    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if not fill then return false end
    local t = overlays[bar]
    if not t then
        t = bar:CreateTexture(nil, "ARTWORK", nil, 7)
        t:SetColorTexture(1, 1, 1, 1)   -- plain white, tinted below (so the tint can be read back with GetVertexColor)
        overlays[bar] = t
    end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
    t:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
    local r, g, b = NP.Color()
    t:SetVertexColor(r, g, b, 1)
    t:Show()
    shown, shownBar = t, bar
    return true
end

function TC.Refresh()
    pending = nil
    if not NP.On() then Hide(); return end   -- a queued refresh that lands after the switch went off
    local plate = PlateFor("target")
    local bar = plate and HealthBarOf(plate)
    if plate and plate == PlateFor("player") then bar = nil end   -- never the personal resource bar
    if bar ~= shownBar then Hide() end
    if not plate then last = "no target nameplate (no target, or its plate is not on screen or is one addons cannot touch)"; return end
    if not bar then last = "the target's nameplate has no Blizzard health bar (hidden by another addon, or your own plate)"; Hide(); return end
    if ShowOn(bar) then last = "target nameplate found; color shown" else last = "the target's health bar has no fill texture"; Hide() end
end

local function Later()
    if pending then return end
    pending = true
    if C_Timer and C_Timer.After then C_Timer.After(0, TC.Refresh) else TC.Refresh() end
end

local function OnEvent(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        TC.Refresh()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- the plate is about to be released for re-use: take our colour off it now if it is the one shown
        local bar = HealthBarOf(PlateFor(unit))
        if bar and bar == shownBar then Hide() end
        Later()
    else -- NAME_PLATE_UNIT_ADDED
        Later()
    end
end

-- switch on or off from the saved setting (login, the settings page)
function TC.Apply()
    local on = NP.On()
    if on then
        if not driver then driver = CreateFrame("Frame") end
        driver:SetScript("OnEvent", OnEvent)
        driver:RegisterEvent("PLAYER_TARGET_CHANGED")
        driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        TC.Refresh()
    else
        if driver then driver:UnregisterAllEvents(); driver:SetScript("OnEvent", nil) end
        pending = nil
        Hide()
        last = "off"
    end
end

function TC.Report() return last end
-- for the QA walkthrough: the texture now shown and the bar it lies on (nil, nil when none)
function TC.Shown() return shown, shownBar end
-- for the QA walkthrough: is the behaviour listening for target changes right now?
function TC.Listening()
    if not (driver and driver.IsEventRegistered) then return false end
    local ok, v = pcall(driver.IsEventRegistered, driver, "PLAYER_TARGET_CHANGED")
    return ok and v and true or false
end
