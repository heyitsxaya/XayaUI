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
-- (round 11a) The round 10 final review's Stat Calculator blockers and her SD-146 answer:
--   SD-105 gap: the game reports a load-on-demand addon as loaded even when one of its files stopped with a Lua error (the game runs
--     each file of the .toc on its own: an error stops that file only; INFERENCE for the game, the stand-in does the same). The loader
--     now counts the calculator as loaded only when no Lua error came from its folder while the game read it (ReadFiles below: the
--     error handler is chained, never replaced, for that one call) and its services show the entries this loader calls
--     (FilesComplete below); otherwise it says it could not load (chat, '/xui stats status', the settings page), and nothing of the
--     half-read calculator is called. (repair 1) The error watch covers every file of the calculator, StatMath.lua and the end of
--     StatCalculator.lua included, which the service probe alone could not see.
--   SD-146, her answer "Repeat the reason each time (Recommended)": while the calculator cannot load this session (switched off in the
--     game's AddOns list, not installed, or its files stopped with an error), every '/xui stats' prints the same one-line reason, not
--     only the first. The character window opening says it once (its first try) and then nothing: a window the player opens for
--     other reasons should not repeat it.
--   '/xui stats <word it does not know>' prints the stats help line and opens or closes nothing (core's rule for /xui: an unknown word
--     prints help). Technical choice (SD-145): a typo such as "/xui stats stauts" used to open or close the panel, which the player
--     did not ask for; the help line names the words that work.
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
-- (round 11a, SD-105 gap) whether the calculator's files ran to their ends, as far as XayaUI_Bonus can see them. The loader reads the
-- calculator only through core's services (Modules.lua section 7: XayaUI_Bonus never names XayaUI_Bonus_StatCalculator's functions;
-- the harness's boundary check holds every addon to that), so each file is probed by the last service entry it offers:
--   StatModel.lua       the statModel service and its CM.ValueFor (CM is the model's own table; ValueFor is its last function)
--   StatCalculator.lua  the statCalc service with the entries this loader calls, and the statCalcDebug service, offered after all of
--                       the file but its last 210 lines (the spell resolver, the settings page builder, its /xui stats part, start-up)
-- What this probe cannot see: StatMath.lua offers no service (StatModel.lua reads it by name), and StatCalculator.lua's last 210 lines
-- offer none either. Those stops are seen by the error watch (ReadFiles below); the probe stays as the second, independent signal for
-- a game where the error handler cannot be chained (another addon may hold it), and it alone guards a calculator loaded some other way.
-- (statCalcDebug is read as "the file ran past this point": if that service is ever offered only with Advanced Debugging on, this
-- line must change; tests/fix_r10_statcalc fails loudly on a healthy calculator reported as not loaded.)
-- Once true it stays true (nothing of a loaded addon is unloaded before /reload), so the answer is kept and later reads cost nothing.
local complete = false
local function FilesComplete()
    if complete then return true end
    local S = ns.Service
    if not S then return false end
    local model, calc, dbg = S("statModel"), Calc(), S("statCalcDebug")
    complete = type(model) == "table" and type(model.CM) == "table" and type(model.CM.ValueFor) == "function"
        and type(calc) == "table" and type(calc.Toggle) == "function" and type(calc.Apply) == "function"
        and type(calc.Shown) == "function" and type(calc.Command) == "function"
        and type(dbg) == "table"
    return complete
end
local function InLockdown() return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false end
local function Changed() if ns.Fire then ns.Fire("CONFIG_CHANGED") end end   -- (core section 6: an open settings window redraws)

-------------------------------------------------------------------------------
-- Load at first open (SD-105)
-------------------------------------------------------------------------------
local loadTried, loadOk = false, false

-- (round 11a repair 1, SD-105 gap) the one LoadAddOn call, with a watch on the Lua errors raised while the game reads the calculator's
-- files. The game reports an error in an addon's file through the active error handler and goes on with the next file (INFERENCE:
-- geterrorhandler / seterrorhandler and that behavior are not in docs/reference/api; core Core.lua chains its handler the same way;
-- the stand-in game does the same). So, for this one call only, OnLoadError is put in front of the handler that is active (core's
-- chain, the game's error frame, BugSack...): every error still reaches that handler with the same message, and an error whose file
-- is in the calculator's folder marks the load as failed. Afterwards the earlier handler is put back, unless something else replaced
-- the handler during the call (then theirs stays, and OnLoadError, still in their chain, only passes errors on). Fails safe: when the
-- handler cannot be read or set (another addon holds it), nothing is watched and FilesComplete is the only signal.
-- One function made once at file load (SD-90), one table: nothing is made per call, and nothing runs outside this one call.
local watch = { on = false, saw = false, prev = nil }
local PART_IN_PATH = "[/\\%.]" .. PART .. "[/\\]"   -- the folder inside a file path ("...ddOns/XayaUI_Bonus_StatCalculator/...")
-- whether an error message comes from one of the calculator's files: its own location ("<path>.lua:12: ..."), else (an error with no
-- location: error(msg, 0), a table) the stack the game reports it with
local function FromPart(msg)
    local text = tostring(msg)
    local loc = text:match("^%s*([^\n]-%.lua):%d+:")
    if loc then return ("/" .. loc):find(PART_IN_PATH) ~= nil end
    -- no location: the stack decides, as the message carries it (the stand-in appends it), else as the game reports it now
    if text:find(PART_IN_PATH) then return true end
    local ok, stack = pcall(debugstack, 3, 12, 0)
    return ok and type(stack) == "string" and stack:find(PART_IN_PATH) ~= nil
end
local function OnLoadError(msg)
    if watch.on and not watch.saw then
        local ok, mine = pcall(FromPart, msg)
        if ok and mine then watch.saw = true end
    end
    local prev = watch.prev
    if prev then return prev(msg) end
end
-- C_AddOns.LoadAddOn(PART) under the watch; returns pcall's ok, the game's loaded and reason, and whether a calculator file errored
local function ReadFiles(A)
    local get, set = geterrorhandler, seterrorhandler
    local watching = false
    if type(get) == "function" and type(set) == "function" then
        local okG, prev = pcall(get)
        if okG and type(prev) == "function" and prev ~= OnLoadError then
            watch.prev, watch.saw = prev, false
            watching = pcall(set, OnLoadError) and get() == OnLoadError
            watch.on = watching
        end
    end
    local ok, loaded, reason = pcall(A.LoadAddOn, PART)
    watch.on = false
    if watching and get() == OnLoadError then pcall(set, watch.prev) end
    return ok, loaded, reason, watch.saw
end
-- Why it could not load this session, set once by the failed load: `loadSay` is the chat line /xui stats prints on every try (SD-146),
-- `loadWhy` the '/xui stats status' line (round 10 repair 2). One pair per cause, so the two never disagree.
-- (The status lines stay named locals: the player documents quote them, and tests/fix_r10_docs reads WHY_DISABLED from this file.)
local WHY_DISABLED = "Stat Calculator: on, but it could not load this session. It is switched off in the game's AddOns list: turn it on, then /reload."
local WHY_MISSING = "Stat Calculator: on, but it could not load this session. Its folder XayaUI_Bonus_StatCalculator is not installed."
local WHY_ERRORED = "Stat Calculator: on, but it could not load this session. Its files stopped with a Lua error while loading: /xui bug shows errors."
local WHY_OTHER = "Stat Calculator: on, but it could not load this session. /xui bug shows errors."
local WHY = {
    disabled = { status = WHY_DISABLED,
        say = "the Stat Calculator is on, but XayaUI Bonus Features: Stat Calculator is switched off in the game's AddOns list. Turn it on, then /reload." },
    missing = { status = WHY_MISSING,
        say = "the Stat Calculator is on, but its folder XayaUI_Bonus_StatCalculator is not installed: it belongs next to XayaUI_Bonus in Interface\\AddOns." },
    -- (round 11a, SD-105 gap) the game loaded the folder, but one of its files stopped with a Lua error
    errored = { status = WHY_ERRORED, say = "the Stat Calculator is on, but its files stopped with a Lua error while loading. /xui bug shows errors." },
    other = { status = WHY_OTHER },   -- (its chat line carries the game's own reason: Load below)
}
local loadSay, loadWhy = nil, WHY_OTHER
-- the one-line reason, printed by every /xui stats while it cannot load (SD-146) and by the character window's first try
local function SayWhy() if loadSay and ns.Print then ns.Print(loadSay) end end
-- the calculator, only once it is loaded whole (nil before its first open, and for the whole session after a failed load: nothing of a
-- half-read calculator is ever called)
local function LoadedCalc()
    if loadTried and not loadOk then return nil end
    if FilesComplete() then return Calc() end
    return nil
end
-- returns whether it is loaded, and whether this call tried to load it (true also when that try failed: the caller then says why)
local function Load()
    if loadTried then return loadOk, false end
    if FilesComplete() then loadTried, loadOk = true, true; return true, false end   -- (already loaded some other way: nothing to load)
    if InLockdown() then return false, false end   -- (SD-100) never in combat lockdown; nothing waits for its end (SD-102)
    loadTried = true
    local A = C_AddOns
    local ok, loaded, reason, errored = false, nil, nil, false
    if A and A.LoadAddOn then ok, loaded, reason, errored = ReadFiles(A) end
    -- (round 11a, SD-105 gap) the game's "loaded" is not enough: no file may have stopped with an error, and the entries this loader
    -- calls must be there
    loadOk = (ok and loaded and not errored and FilesComplete()) and true or false
    Changed()   -- (an open settings window redraws: its detailed options, or the line saying it could not load; never a stale line)
    if loadOk then return true, true end
    -- (as the settings window's own load does, core ns.LoadOptions) one line saying why
    local cause
    if ok and loaded then cause = "errored"
    else
        local state = ns.ModuleState and ns.ModuleState(PART)
        cause = (state == "disabled" or state == "missing") and state or "other"
    end
    loadWhy = WHY[cause].status
    loadSay = WHY[cause].say or ("the Stat Calculator could not load (" .. tostring(ok and reason or loaded) .. "). /xui bug shows errors.")
    return false, true
end

-- open or close the panel: the minimap row and /xui stats. The first open loads the calculator; opening it may already have docked the
-- panel beside the open character window (its start-up), which counts as this open. (V26, A24 #3 "Hide silently") in combat nothing
-- happens and nothing is said.
local function OpenOrToggle()
    if not Saved() or InLockdown() then return end
    local ok, now = Load()
    -- (SD-146 "Repeat the reason each time") it could not load this session: the same one line on every try, never silence
    if not ok then if loadTried then SayWhy() end; return end
    local calc = LoadedCalc()
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
    local ok, tried = Load()
    if not ok then if tried then SayWhy() end; return end   -- (its first try says why once; loadTried then ends every later call)
    local calc = LoadedCalc()
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
    local calc = LoadedCalc()
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

-- (tests, read only, and the calculator's off line) whether the load was asked for this session and whether it worked; the part.
-- (round 11a repair 1) FilesErrored: true from the moment a calculator file stopped with a Lua error during this session's load (the
-- error watch above), so a later file of the calculator can see, while it is still being read, that an earlier one did not finish
-- and stand down instead of starting on a half-read model (that stand-down is the calculator's own: XayaUI_Bonus_StatCalculator).
ns.StatCalcLoader = { Tried = function() return loadTried end, Loaded = function() return loadOk end, Saved = function() return Saved() end,
    Hooked = function() return hooked end, Part = SC_PART, SwitchChanged = SwitchChanged,
    FilesErrored = function() return watch.saw end }

local function Switch(Notify)
    return { type = "toggle", order = 1, name = LABEL,
        desc = "On, the Stat Calculator loads the first time you open it. Off, nothing of it runs; once it has loaded, its memory is freed at your next /reload.",
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
    local calc = LoadedCalc()
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
local HELP = "/xui stats: open or close the Stat Calculator. Also: /xui stats options | status | off"
local function Command(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "" then OpenOrToggle(); return end
    if arg == "options" or arg == "settings" then ns.OpenSettingsPage("bonus", "statcalc"); return end
    if arg == "off" then
        local loaded = loadOk
        SetOn(false)
        if not loaded then ns.Print("The Stat Calculator is off.") end   -- (loaded: SwitchChanged's line says it, with the memory)
        return
    end
    if arg == "status" then
        local calc = LoadedCalc()
        if calc and calc.Command then calc.Command("status"); return end
        -- (round 10 repair 2) after a failed load this session, say so and why, as the page does (NoteText); never "not loaded yet"
        if loadTried and not loadOk then ns.Print(loadWhy); return end
        ns.Print("Stat Calculator: on, not loaded yet (it loads the first time you open it).")
        return
    end
    -- "help", and (round 11a) any word it does not know (core's rule for /xui: an unknown word prints help): the help line only;
    -- nothing opens, closes or loads
    ns.Print(HELP)
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
                local calc = LoadedCalc()
                if calc then return (calc.Available and calc.Available()) and true or false end
                if loadTried then return false end   -- (it could not load: chat said why)
                return BonusS.characterToolkit.panel ~= false
            end })
    end
    ns.RegisterSettingsPage("bonus", "statcalc", BuildPage)
    ns.RegisterCommand("stats", Command, "/xui stats [options|status|off] (Stat Calculator panel)", SC_PART)
end)
