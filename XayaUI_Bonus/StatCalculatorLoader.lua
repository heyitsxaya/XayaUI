-------------------------------------------------------------------------------
-- StatCalculatorLoader.lua (XayaUI Bonus Features 0.6.46): the tiny loader that is all XayaUI_Bonus keeps of the Stat Calculator.
-- Xaya, REQUEST-LOG A24 #12 (her words): "if the addon or element within an addon is off it should not be read at all. this is true for
-- all addon  elements and should be detected once per reload"; A24 #13, the option she chose ("1"): "XayaUI_Bonus keeps only a tiny
-- loader: the on/off switch, settings page entry, /xui stats and the minimap row. The calculator code moves to
-- XayaUI_Bonus_StatCalculator, shown in the AddOns list under Bonus Features as 'load on demand'. Off means it is never read; on means it
-- loads once per reload." (her note: "unsure how this will look in game -- this might not be okay": docs/plans/
-- STAT-CALCULATOR-MAIN-INGAME-CHECKS.md has the steps to look at the AddOns list).
--
-- What is here (and nothing else of the Stat Calculator):
--   * the saved store's declaration (XayaUIBonusDB, this addon's .toc; core Modules.lua section 0b): the settings stay
--     XayaUIBonusDB.characterToolkit, unchanged, so nothing is moved or reset;
--   * the switch (XayaUIBonusDB.characterToolkit.enabled), read ONCE at PLAYER_LOGIN: on, C_AddOns.LoadAddOn loads
--     XayaUI_Bonus_StatCalculator (StatMath.lua, StatModel.lua, StatCalculator.lua); off, none of its files is read this session.
--     A login in combat lockdown waits for PLAYER_REGEN_ENABLED (LoadAddOn is never called in combat lockdown). Then this file's
--     frame unregisters its events: nothing of it runs again until the next /reload.
--   * changing the switch (the tick box on the Stat Calculator's row, /xui stats on | off) saves the choice and asks for a reload
--     (core ns.SwitchSaveForReload / ns.SwitchCommand, id "bonus.statcalc"), as main's other on / off switch does (the Blizzard Reskin
--     tab switch, core Modules.lua section 5c: "this change takes effect after a reload"); the session keeps what it had until then.
--   * the settings page entry Bonus Features > Stat Calculator: with the calculator loaded its detailed options come from it (the
--     "statCalc" service's Page); off, the page is one line (NoteText below);
--   * /xui stats (on, off, options, help here; status and show / hide from the loaded calculator);
--   * the minimap list's Stat Calculator row, hidden while the calculator is not loaded, while it or its panel is off, and in combat
--     (A24 #8, her words: "Hide it in combat (Recommended)"; the loaded calculator's Available() answers that).
-- The profile part is ProfilePart.lua (this folder).
--
-- Game calls (12.1.5 documentation, docs/reference/api/namespaces.md:164 and 160-163):
--   C_AddOns.LoadAddOn(name: uiAddon) -> loaded: bool?, value: string? · SecretArguments=AllowedWhenUntainted
--   C_AddOns.IsAddOnLoaded(name: uiAddon) -> loadedOrLoading: bool, loaded: bool · SecretArguments=AllowedWhenUntainted
-- (both through core's ns.ModuleState for the message; LoadAddOn wrapped in pcall). InCombatLockdown: namespaces.md lists it as
-- "Documented but not present in this client"; it is read the way Blizzard's own UI reads it, only when it is a function (INFERENCE).
-- PLAYER_LOGIN and PLAYER_REGEN_ENABLED: game events with no payload used here.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("bonus", "XayaUI_Bonus", "XayaUIBonusDB") end   -- (P5) this addon's own saved variable (its .toc)
local BonusS = ns.Settings("bonus")

local PART = "XayaUI_Bonus_StatCalculator"   -- the load-on-demand addon (its own top-level folder: addon folders cannot nest)
local SWITCH, LABEL = "bonus.statcalc", "Stat Calculator"

-- the saved switch (no table is made just to read it)
local function Saved()
    if not ns.SettingsReady("bonus") then return false end
    local c = BonusS.characterToolkit
    return type(c) == "table" and c.enabled == true
end
local function Write(on)
    if not ns.SettingsReady("bonus") then return end
    local c = BonusS.characterToolkit
    if type(c) ~= "table" then c = {}; BonusS.characterToolkit = c end
    c.enabled = on and true or false
end
-- the loaded calculator (nil while it is not loaded)
local function Calc() return ns.Service and ns.Service("statCalc") or nil end
local function InLockdown() return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false end

-------------------------------------------------------------------------------
-- Load once per reload
-------------------------------------------------------------------------------
local loadTried, loadOk = false, false
local ev
local function Load()
    if loadTried then return end
    loadTried = true
    if ev then ev:UnregisterAllEvents() end
    local A = C_AddOns
    local ok, loaded, reason = false, nil, nil
    if A and A.LoadAddOn then ok, loaded, reason = pcall(A.LoadAddOn, PART) end
    loadOk = (ok and loaded) and true or false
    if loadOk or not ns.Print then return end
    -- (as the settings window's own load does, core ns.LoadOptions) one line saying why
    local state = ns.ModuleState and ns.ModuleState(PART)
    if state == "disabled" then
        ns.Print("the Stat Calculator is on, but XayaUI Bonus Features: Stat Calculator is switched off in the game's AddOns list. Turn it on, then /reload.")
    elseif state == "missing" then
        ns.Print("the Stat Calculator is on, but its folder XayaUI_Bonus_StatCalculator is not installed: it belongs next to XayaUI_Bonus in Interface\\AddOns.")
    else
        ns.Print("the Stat Calculator could not load (" .. tostring(ok and reason or loaded) .. "). /xui bug shows errors.")
    end
end
-- PLAYER_LOGIN: the one read of the switch this session
local function OnLogin()
    if not Saved() then ev:UnregisterAllEvents(); return end   -- off: nothing of the calculator is read until the next /reload
    if InLockdown() then
        ev:UnregisterEvent("PLAYER_LOGIN")
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")   -- loaded once combat ends, never in combat lockdown
        return
    end
    Load()
end
ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then OnLogin()
    elseif event == "PLAYER_REGEN_ENABLED" and not InLockdown() then Load() end
end)

-- (tests, read only) whether the load was asked for this session and whether it worked
ns.StatCalcLoader = { Tried = function() return loadTried end, Loaded = function() return loadOk end, Saved = function() return Saved() end }

-------------------------------------------------------------------------------
-- The switch: saves the choice and asks for a reload (the session keeps what it had)
-------------------------------------------------------------------------------
local function Switch(Notify)
    return { type = "toggle", order = 1, name = LABEL,
        desc = "Turns the Stat Calculator on. Off means it is never read; on means it loads once per reload.",
        tip = "Turns on the Stat Calculator.",
        get = function() return Saved() end,
        set = function(_, v)
            local was = Saved()
            if ns.SwitchSaveForReload then ns.SwitchSaveForReload(SWITCH, was, function() Write(v) end, LABEL) else Write(v) end
            if Notify then Notify() end
        end }
end

-- the page's one line while the calculator is not loaded (wording: INFERENCE, proposed to Xaya; see the debug notes of A24 #13)
local function NoteText()
    if Saved() then return "On after a reload: type /reload to load the Stat Calculator and list its options here." end
    return "Off: none of the Stat Calculator is read. Tick it, then /reload to load it and list its options here."
end

local function BuildPage(Notify)
    if not ns.SettingsReady("bonus") then return nil end
    local calc = Calc()
    local page = calc and calc.Page and calc.Page(Notify) or nil
    if type(page) ~= "table" then
        page = { type = "group", name = LABEL, order = 3, childGroups = "tree", args = {
            note = { type = "description", order = 0, width = "full", fontSize = "medium", name = NoteText },
        } }
    end
    page.xuiSwitch = Switch(Notify)
    return page
end

local function Command(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "options" or arg == "settings" then ns.OpenSettingsPage("bonus", "statcalc"); return end
    if arg == "help" then
        ns.Print("/xui stats: show or hide the Stat Calculator (on its own when the character window is closed). /xui stats on | off | options | status")
        return
    end
    if arg == "on" or arg == "off" then
        if not ns.SettingsReady("bonus") then return end
        local on = arg == "on"
        if ns.SwitchCommand then ns.Print(ns.SwitchCommand(SWITCH, Saved(), function() Write(on) end, LABEL, on))
        else Write(on) end
        return
    end
    local calc = Calc()
    if calc and calc.Command then calc.Command(arg); return end
    if arg == "status" then
        ns.Print(Saved() and "Stat Calculator: on after a reload (not loaded this session)." or "Stat Calculator: off (not loaded).")
        return
    end
    ns.Print("Stat Calculator is off. Turn it on in Bonus Features > Stat Calculator (or /xui stats on), then /reload.")
end

-- the page, the command and the minimap row: once Bonus's settings are open (with XayaUI Bonus Features off: none of them)
local registered = false
ns.WhenSettingsReady("bonus", function()
    if registered then return end
    registered = true
    if type(ns.RegisterLauncher) == "function" then
        -- (QoL 0.7.23; Xaya 2026-11-05: "it should also have its own open button on the minimap and should be openable as its own
        -- standalone window without opening the character sheet"; O-100, her answer "No word at all": no "on" / "off") the row is
        -- registered once and its available() keeps it out of the list while the calculator is not loaded, it or its panel is off, or
        -- in combat (A24 #8): core reads available() each time the list opens (XayaUI/MinimapButton.lua), nothing is polled.
        ns.RegisterLauncher({ "stats", "Stat Calculator", "Show or hide the Stat Calculator on its own, without the character window (also /xui stats)",
            function() local calc = Calc(); if calc and calc.Toggle then calc.Toggle() end end, nil, order = 12,
            available = function() local calc = Calc(); return (calc and calc.Available and calc.Available()) and true or false end })
    end
    ns.RegisterSettingsPage("bonus", "statcalc", BuildPage)
    ns.RegisterCommand("stats", Command, "/xui stats [on|off|options|status] (Stat Calculator panel)")
end)
