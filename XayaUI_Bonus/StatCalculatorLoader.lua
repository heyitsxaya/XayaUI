-------------------------------------------------------------------------------
-- StatCalculatorLoader.lua (XayaUI Bonus Features 0.6.47): the tiny loader that is all XayaUI_Bonus keeps of the Stat Calculator.
-- Xaya, REQUEST-LOG A24 #12 (her words): "if the addon or element within an addon is off it should not be read at all. this is true for
-- all addon  elements and should be detected once per reload"; A24 #13, the option she chose ("1"): "XayaUI_Bonus keeps only a tiny
-- loader: the on/off switch, settings page entry, /xui stats and the minimap row. The calculator code moves to
-- XayaUI_Bonus_StatCalculator, shown in the AddOns list under Bonus Features as 'load on demand'. Off means it is never read; on means it
-- loads once per reload." (her note: "unsure how this will look in game -- this might not be okay": docs/plans/
-- STAT-CALCULATOR-MAIN-INGAME-CHECKS.md has the steps to look at the AddOns list).
-- (0.6.47, bundle 1 round 10) Her later answers change when it loads and how the switch acts:
--   SD-94 (her words): "if window is not open, it shouldn't use memory"; SD-105, her answer "Load at first open (Recommended)": the
--     calculator is NOT loaded at login; it loads the first time its panel opens (the minimap row, /xui stats, or the character window
--     opening while the panel was left open: docked). Switched off before that first open, nothing of it is ever read.
--   SD-86 (her words): "Bonus itself as a module requires a reload. Only require a reload for an individual item that might require a
--     reload." The switch takes effect at once, with no "Reload now?" question: on = usable now (it loads at its first open); off = inert
--     now (no event, no hook doing work, the panel hidden) and, once it was loaded, one chat line says its memory is freed at the next
--     /reload. No forced memory clear (SD-101).
--   SD-118, her answer "All parts, say how (Recommended)": its words work only while it is switched on. "/xui stats on" no longer exists;
--     while it is off, every /xui stats word prints core's one line ("The Stat Calculator is off. Turn it on in /xui > Bonus Features.").
--   SD-100 (her words): "stat calculator isn't allowed to be open during combat"; SD-102, her answer "Don't reappear": nothing opens or
--     loads it in combat, and nothing of it loads or draws when combat ends.
--   SD-103 (her answer: "unsure, circle back to this within the broader scope of addon load demands"), PARKED: opening the settings
--     window never loads it. Interim: its page shows the switch; the detailed options come from the calculator only when it is already
--     loaded this session, else one plain line says they appear after it is first opened.
--
-- What is here (and nothing else of the Stat Calculator):
--   * the saved store's declaration (XayaUIBonusDB, this addon's .toc; core Modules.lua section 0b): the settings stay
--     XayaUIBonusDB.characterToolkit, unchanged, so nothing is moved or reset;
--   * the switch (XayaUIBonusDB.characterToolkit.enabled): the tick box on the Stat Calculator's row, "/xui stats off" and a profile
--     import all go through SwitchChanged below;
--   * the first open: C_AddOns.LoadAddOn("XayaUI_Bonus_StatCalculator") (StatMath.lua, StatModel.lua, StatCalculator.lua), once per
--     session, never in combat lockdown;
--   * one hook on the character window's OnShow (installed only once the switch is on; it cannot be taken out until /reload, so its
--     first read is the raw saved switch): it loads the calculator when the window opens with the panel left open. Once the
--     calculator is loaded it docks itself (its own hook), and this one returns at once. No event, no timer.
--   * the settings page entry Bonus Features > Stat Calculator: with the calculator loaded its detailed options come from it (the
--     "statCalc" service's Page); not loaded, the page is one line (NoteText below);
--   * /xui stats (options, status, off and help here; opening and closing through the calculator, loaded at the first open);
--   * the minimap list's Stat Calculator row, hidden while it or its panel is off, and in combat (A24 #8, her words: "Hide it in combat
--     (Recommended)").
-- The profile part is ProfilePart.lua (this folder); after an import it calls SwitchChanged (ns.StatCalcLoader.SwitchChanged).
--
-- Game calls (12.1.5 documentation, docs/reference/api/namespaces.md:164 and 160-163):
--   C_AddOns.LoadAddOn(name: uiAddon) -> loaded: bool?, value: string? · SecretArguments=AllowedWhenUntainted
--   C_AddOns.IsAddOnLoaded(name: uiAddon) -> loadedOrLoading: bool, loaded: bool · SecretArguments=AllowedWhenUntainted
-- (both through core's ns.ModuleState for the message; LoadAddOn wrapped in pcall). InCombatLockdown: namespaces.md lists it as
-- "Documented but not present in this client"; it is read the way Blizzard's own UI reads it, only when it is a function (INFERENCE).
-- Frame:HookScript on the game's character window (PaperDollFrame, else CharacterFrame, as the calculator itself reads it): a post-hook,
-- nothing of the window is replaced (V25 (4)). PLAYER_LOGIN: listened to only when the character window did not exist yet when the
-- switch was read (never in the usual case: the game's own windows exist before addons load, INFERENCE), and once.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("bonus", "XayaUI_Bonus", "XayaUIBonusDB") end   -- (P5) this addon's own saved variable (its .toc)
local BonusS = ns.Settings("bonus")

local PART = "XayaUI_Bonus_StatCalculator"   -- the load-on-demand addon (its own top-level folder: addon folders cannot nest)
local LABEL = "Stat Calculator"

-- the saved switch, read raw (no table is made just to read it); exactly true only while on
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
-- (SD-118) the Stat Calculator as a part for core's commands (Modules.lua section 2): its words run only while isOn() is true; else core
-- prints ns.PartOffText(part): "The Stat Calculator is off. Turn it on in /xui > Bonus Features."
local SC_PART = { name = LABEL, isOn = Saved, where = "/xui > Bonus Features" }
-- the loaded calculator (nil while it is not loaded)
local function Calc() return ns.Service and ns.Service("statCalc") or nil end
local function InLockdown() return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false end
local function Changed() if ns.Fire then ns.Fire("CONFIG_CHANGED") end end   -- (core section 6: an open settings window redraws)

-------------------------------------------------------------------------------
-- Load at first open (SD-105)
-------------------------------------------------------------------------------
local loadTried, loadOk = false, false
-- returns whether it is loaded, and whether this call loaded it
local function Load()
    if loadTried then return loadOk, false end
    if Calc() then loadTried, loadOk = true, true; return true, false end   -- (already loaded some other way: nothing to load)
    if InLockdown() then return false, false end   -- (SD-100) never in combat lockdown; nothing waits for its end (SD-102)
    loadTried = true
    local A = C_AddOns
    local ok, loaded, reason = false, nil, nil
    if A and A.LoadAddOn then ok, loaded, reason = pcall(A.LoadAddOn, PART) end
    loadOk = (ok and loaded) and true or false
    if loadOk then
        Changed()   -- (an open settings window: the page now has its detailed options)
        return true, true
    end
    if not ns.Print then return false, false end
    -- (as the settings window's own load does, core ns.LoadOptions) one line saying why
    local state = ns.ModuleState and ns.ModuleState(PART)
    if state == "disabled" then
        ns.Print("the Stat Calculator is on, but XayaUI Bonus Features: Stat Calculator is switched off in the game's AddOns list. Turn it on, then /reload.")
    elseif state == "missing" then
        ns.Print("the Stat Calculator is on, but its folder XayaUI_Bonus_StatCalculator is not installed: it belongs next to XayaUI_Bonus in Interface\\AddOns.")
    else
        ns.Print("the Stat Calculator could not load (" .. tostring(ok and reason or loaded) .. "). /xui bug shows errors.")
    end
    return false, false
end

-- open or close the panel: the minimap row and /xui stats. The first open loads the calculator; opening it may already have docked the
-- panel beside the open character window (its start-up), which counts as this open. (V26, A24 #3 "Hide silently") in combat nothing
-- happens and nothing is said.
local function OpenOrToggle()
    if not Saved() or InLockdown() then return end
    local ok, now = Load()
    if not ok then return end
    local calc = Calc()
    if not (calc and calc.Toggle) then return end
    if now and calc.Shown and calc.Shown() then return end
    calc.Toggle()
end

-- the character window opened (its OnShow, hooked once the switch is on): while the calculator is not loaded and the panel was left
-- open, the first open is now, docked. Every other case returns at its first lines: off, already loaded (its own hook docks it), in
-- combat (SD-100 / SD-102), or the panel left closed.
local hooked = false
local function OnCharacterShown()
    if loadTried or not Saved() or InLockdown() then return end
    local c = BonusS.characterToolkit
    if c.panel == false or c.panelOpen == false then return end
    if not (Load()) then return end
    local calc = Calc()
    if calc and calc.Shown and not calc.Shown() and calc.ShowIfDocked then calc.ShowIfDocked() end
end
local function Owner() return _G.PaperDollFrame or _G.CharacterFrame end
local retry
local function OnLoginRetry(self)
    self:UnregisterAllEvents()
    local owner = Owner()
    if not hooked and owner and owner.HookScript then hooked = true; owner:HookScript("OnShow", OnCharacterShown) end
end
local function InstallHook()
    if hooked then return end
    local owner = Owner()
    if owner and owner.HookScript then
        hooked = true
        owner:HookScript("OnShow", OnCharacterShown)
    elseif not retry and CreateFrame then
        -- (INFERENCE: not the usual case) the window is not there yet: try once more at PLAYER_LOGIN, then listen to nothing
        retry = CreateFrame("Frame")
        retry:SetScript("OnEvent", OnLoginRetry)
        retry:RegisterEvent("PLAYER_LOGIN")
    end
end

-------------------------------------------------------------------------------
-- The switch: at once, no reload question (SD-86, SD-94, SD-105)
-------------------------------------------------------------------------------
-- after the saved switch was written (the tick box, /xui stats off, a profile import); wasOn = the saved switch before the write
local function SwitchChanged(wasOn)
    local on = Saved()
    if on then InstallHook() end
    local calc = Calc()
    if calc and calc.Apply then calc.Apply() end   -- loaded: on again, it listens as before; off, inert now (no event, panel hidden)
    if on == wasOn then return end
    if not on and loadOk and ns.Print then ns.Print("The Stat Calculator is off. Its memory is freed at your next /reload.") end
    Changed()   -- (an open settings window redraws, so its page never shows a stale line; a tick box click redraws it itself)
end
local function SetOn(on)
    if not ns.SettingsReady("bonus") then return end
    local was = Saved()
    Write(on)
    SwitchChanged(was)
end

-- (tests, read only, and the calculator's off line) whether the load was asked for this session and whether it worked; the part
ns.StatCalcLoader = { Tried = function() return loadTried end, Loaded = function() return loadOk end, Saved = function() return Saved() end,
    Hooked = function() return hooked end, Part = SC_PART, SwitchChanged = SwitchChanged }

local function Switch(Notify)
    return { type = "toggle", order = 1, name = LABEL,
        desc = "Turns the Stat Calculator on or off. On, it loads the first time you open it. Off, nothing of it runs; once it has loaded, its memory is freed at your next /reload.",
        tip = "Turns on the Stat Calculator.",
        get = function() return Saved() end,
        set = function(_, v)
            SetOn(v and true or false)
            if Notify then Notify() end
        end }
end

-- the page's one line while the calculator is not loaded (SD-103 is parked: the settings window never loads it)
local function NoteText()
    if loadTried and not loadOk then return "The Stat Calculator could not load this session. Chat says why." end
    if Saved() then return "Its options appear here after you first open the Stat Calculator." end
    return "Off. Turn it on, then open it once, to see its options here."
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

-- /xui stats while the Stat Calculator is on (SD-118: while it is off, core prints its one line and never calls this)
local function Command(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "options" or arg == "settings" then ns.OpenSettingsPage("bonus", "statcalc"); return end
    if arg == "help" then
        ns.Print("/xui stats: open or close the Stat Calculator. Also: /xui stats options | status | off")
        return
    end
    if arg == "off" then
        local loaded = loadOk
        SetOn(false)
        if not loaded then ns.Print("The Stat Calculator is off.") end   -- (loaded: SwitchChanged's line says it, with the memory)
        return
    end
    if arg == "status" then
        local calc = Calc()
        if calc and calc.Command then calc.Command("status"); return end
        ns.Print("Stat Calculator: on, not loaded yet (it loads the first time you open it).")
        return
    end
    OpenOrToggle()
end

-- the page, the command and the minimap row: once Bonus's settings are open (with XayaUI Bonus Features off: none of them)
local registered = false
ns.WhenSettingsReady("bonus", function()
    if registered then return end
    registered = true
    if Saved() then InstallHook() end
    if type(ns.RegisterLauncher) == "function" then
        -- (QoL 0.7.23; Xaya 2026-11-05: "it should also have its own open button on the minimap and should be openable as its own
        -- standalone window without opening the character sheet"; O-100, her answer "No word at all": no "on" / "off") the row is
        -- registered once and its available() keeps it out of the list while the Stat Calculator or its panel is off, while it could
        -- not load, or in combat (A24 #8): core reads available() each time the list opens (XayaUI/MinimapButton.lua), nothing is polled.
        -- (0.6.47, SD-105) before the first open the row is there too: a click on it is the first open.
        ns.RegisterLauncher({ "stats", LABEL, "Show or hide the Stat Calculator on its own, without the character window (also /xui stats)",
            OpenOrToggle, nil, order = 12,
            available = function()
                if not Saved() or InLockdown() then return false end
                local calc = Calc()
                if calc then return (calc.Available and calc.Available()) and true or false end
                if loadTried then return false end   -- (it could not load: chat said why)
                return BonusS.characterToolkit.panel ~= false
            end })
    end
    ns.RegisterSettingsPage("bonus", "statcalc", BuildPage)
    ns.RegisterCommand("stats", Command, "/xui stats [options|status|off] (Stat Calculator panel)", SC_PART)
end)
