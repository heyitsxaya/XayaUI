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
--     StatCalculator.lua included, which the service probe alone could not see. (repair 2) It also reads the stack when the error's
--     message names another file (a helper the calculator's file called at load raised it).
--   SD-146, her answer "Repeat the reason each time (Recommended)": while the calculator cannot load this session (switched off in the
--     game's AddOns list, not installed, or its files stopped with an error), every '/xui stats' prints the same one-line reason, not
--     only the first. The character window opening says it once (its first try) and then nothing: a window the player opens for
--     other reasons should not repeat it.
--   '/xui stats <word it does not know>' prints the stats help line and opens or closes nothing (core's rule for /xui: an unknown word
--     prints help). Technical choice (SD-145): a typo such as "/xui stats stauts" used to open or close the panel, which the player
--     did not ask for; the help line names the words that work.
-- (round 11 repair, R11A final blocker 3 and concerns) The SD-105 gap closed end to end:
--   * each calculator file offers its service as its LAST statement (StatMath.lua "statMath", StatModel.lua "statModel",
--     StatCalculator.lua "statCalc" and "statCalcDebug"), so a stop anywhere in any of them leaves its service missing; FilesComplete
--     reads those three end-of-file marks. That no longer depends on the error handler: a stop is seen even when another addon holds
--     seterrorhandler (the old known limit).
--   * StatModel.lua and StatCalculator.lua stand down at their tops when the file before them did not end (or, for StatCalculator.lua,
--     when this loader's watch saw a calculator error): a half-read calculator makes no frame, hook or event and raises no Lua error.
--   * the error watch now also files every calculator load error it sees in XayaUI's error record under the calculator's own code
--     (XUI-E009: core DebugRecord.lua ns.RecordLoadError), in every way the game may report it, so core's handler does not file it a
--     second time, or under core's XUI-E001 when the message carries no file of its own.
--   * (SD-139) the reasons that report an error ("its files stopped with a Lua error", "could not load (...)") print through core's
--     ns.PrintError with XUI-E009, so they are saved too; "switched off in the AddOns list" and "not installed" stay ordinary messages
--     (ns.Print), as core's own lines for the settings window are (Modules.lua ns.LoadOptions): they tell the player's own setup, not
--     a failure of XayaUI. Their wording no longer says "/xui bug shows errors": with Advanced Debugging off (the default) /xui bug
--     only says it needs Advanced Debugging, so the lines say the error is saved and that /xui bug needs Advanced Debugging.
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
-- (round 11 repair, SD-105 gap) whether every file of the calculator ran to its end. The loader reads the calculator only through
-- core's services (Modules.lua section 7: XayaUI_Bonus never names XayaUI_Bonus_StatCalculator's functions; the harness's boundary
-- check holds every addon to that), and each calculator file offers its service as its last statement, its end-of-file mark:
--   StatMath.lua        "statMath"   (and StatModel.lua stands down at its top without it)
--   StatModel.lua       "statModel"  (and StatCalculator.lua stands down at its top without it)
--   StatCalculator.lua  "statCalc"   (offered last, after its start-up, with "statCalcDebug")
-- A Lua error raised while the game reads a file stops that file there (Lua's rule for a chunk), so a stop anywhere in any file
-- leaves at least one of the three missing. This needs no error handler: it holds when another addon holds seterrorhandler, and for
-- a calculator loaded some other way. The order of XayaUI_Bonus_StatCalculator.toc is what the stand-downs lean on (each file reads
-- the one before it); tests/fix_r11_statcalc F checks the .toc order and that each mark is its file's last statement.
-- Once true it stays true (nothing of a loaded addon is unloaded before /reload), so the answer is kept and later reads cost nothing.
local MARKS = { "statMath", "statModel", "statCalc" }
local complete = false
local function FilesComplete()
    if complete then return true end
    local S = ns.Service
    if not S then return false end
    for i = 1, #MARKS do
        if type(S(MARKS[i])) ~= "table" then return false end
    end
    complete = true
    return true
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
-- the handler during the call (then theirs stays, and OnLoadError, still in their chain, only passes errors on).
-- What the watch is for since round 11's repair (the end-of-file marks, FilesComplete, decide "loaded" on their own):
--   (1) the error record: each calculator error it sees is filed under the calculator's code (XUI-E009) through core's
--       ns.RecordLoadError (DebugRecord.lua), whatever the message names, so the bug report puts it under the Stat Calculator;
--   (2) FilesErrored: StatCalculator.lua stands down at its top when it is true (an earlier file raised an error this load);
--   (3) a second signal for loadOk: an error the watch counts also makes the load fail (it errs on the side of never calling a
--       half-read calculator; see the known limit at FromPart).
-- KNOWN LIMIT, stated plainly: if another addon holds the error handler (seterrorhandler does nothing, or geterrorhandler does not
-- answer a function), nothing is watched. A file that stops is still found (the end-of-file marks), the calculator still says it could
-- not load, and StatCalculator.lua still stands down after an earlier file stopped (its "statModel" check); what is lost then is (1)
-- and (2): XayaUI files the error only by core's own handler, if that addon passes errors on to it at all, by core's reading of the
-- message (the folder the message names, else the first addon file on the stack), and a Lua error the game reports during the load
-- without stopping a file (a frame script) is not counted. (round 11 repair 2, measured in the stand-in, tests/fix_r11_statcalc E
-- "error handler held by another addon"): core's handler then files nothing at all for an error in StatCalculator.lua, because the
-- game shortens a file name longer than 60 characters ("...ddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua:N: ...", INFERENCE
-- for the game, Lua 5.1's rule in the stand-in) and core's ns.ErrorFolder (XayaUI/Core.lua) reads only a full "AddOns/<folder>/"
-- name; and an error a calculator file reports and then goes on from (a helper run under xpcall) is not seen at all, so that load
-- counts as loaded and StatCalculator.lua starts up (its LoadBroken stand-down reads FilesErrored, which stays false). UNVERIFIED IN
-- GAME.
-- One function made once at file load (SD-90), one table: nothing is made per call, and nothing runs outside this one call. ReadFiles
-- runs once per session (Load sets loadTried before it), so watch.saw starts false and is never reset.
local watch = { on = false, saw = false, prev = nil }
local PART_IN_PATH = "[/\\%.]" .. PART .. "[/\\]"   -- the folder inside a file path ("...ddOns/XayaUI_Bonus_StatCalculator/...")
-- whether an error raised during the load stopped one of the calculator's files: the message names the folder (its own location,
-- "<path>/XayaUI_Bonus_StatCalculator/StatMath.lua:12: ...", or the stack a message carries: the stand-in game appends it), else the
-- stack as the game reports the error now (the handler runs where the error was raised, before the stack unwinds: INFERENCE, as core's
-- handler and BugSack read it). (round 11a repair 2) The stack is read also when the message names another file: a calculator file
-- that stops because a helper it calls at load raised the error (Blizzard's SharedXML Mixin, a core ns.* helper, a library) gets a
-- message naming the helper's file, and only the stack names the calculator's. Another addon's error during the same load (its
-- ADDON_LOADED handler, fired after the calculator's files ran) has no calculator file on its stack and is not counted.
-- PART_IN_PATH: the folder name between a path separator (or the "..." the game puts in front of a shortened file name) and a path
-- separator, so a folder whose name only starts or ends with it ("XayaUI_Bonus_StatCalculatorSkin/", "Old_XayaUI_Bonus_StatCalculator/")
-- is never taken for the calculator's (tests/fix_r11_statcalc W cases).
-- debugstack(1, 20, 0): from the top, 20 lines, none from the bottom (its arguments are INFERENCE: debugstack is not in
-- docs/reference/api; Blizzard's own UI and core's handler call it this way); this file's own lines never match PART_IN_PATH (it is
-- XayaUI_Bonus/StatCalculatorLoader.lua). Read under pcall: a client without it, or one that raises, leaves the message as the only
-- signal. It runs only for an error raised during this one LoadAddOn call.
-- Known limit (INFERENCE): a frame script another addon runs from inside a calculator file at load (a hook on a frame the file
-- shows) and that errors without stopping the file has the calculator's file on its stack too, and is counted: the calculator then
-- says it could not load. It errs on the side of never calling a half-read calculator.
local function FromPart(msg, stack)
    if tostring(msg):find(PART_IN_PATH) then return true end   -- (tostring may raise for an error object: the caller's pcall holds it)
    return type(stack) == "string" and stack:find(PART_IN_PATH) ~= nil
end
local function OnLoadError(msg)
    if watch.on then
        local okS, stack = pcall(debugstack, 1, 20, 0)
        if not (okS and type(stack) == "string") then stack = nil end
        -- (pcall: nothing here may stop the error from reaching the next handler, not even an error object whose text cannot be read)
        local ok, mine = pcall(FromPart, msg, stack)
        if ok and mine then
            watch.saw = true
            -- (round 11 repair) filed under the calculator's code; core's handler, next in the chain, then skips this same message
            if ns.RecordLoadError then pcall(ns.RecordLoadError, PART, msg, stack) end
        end
    end
    local prev = watch.prev
    -- a tail call, kept as one: this file's frame is gone from the stack the next handler reads (BugSack, the game's error frame and
    -- core's handler read it), so for an error that names no file the first addon file there is the calculator's, not XayaUI_Bonus's
    -- (tests/fix_r11_statcalc case game0 reads that stack)
    if prev then return prev(msg) end
end
-- C_AddOns.LoadAddOn(PART) under the watch; returns pcall's ok, the game's loaded and reason, and whether a calculator file errored
local function ReadFiles(A)
    local get, set = geterrorhandler, seterrorhandler
    local watching = false
    if type(get) == "function" and type(set) == "function" then
        local okG, prev = pcall(get)
        if okG and type(prev) == "function" and prev ~= OnLoadError then
            watch.prev = prev
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
-- (round 11 repair, SD-139) `err` marks the causes that are a failure: their lines print through core's ns.PrintError with XUI-E009,
-- the code a Lua error in the calculator's folder has (DebugRecord.lua, CodeOfFolder), so they are saved in the error record with a
-- repeat count; the status line is saved as the same entry as the chat line (the same cause, told again). Switched off in the
-- AddOns list or not installed are the player's own setup and stay ordinary messages (as core's lines for the settings window).
-- Their wording: "The error is saved: /xui bug shows it (needs Advanced Debugging)." is what is true with Advanced Debugging off,
-- the default (/xui bug then only says it needs Advanced Debugging, and how to turn it on).
local SAVED = "The error is saved: /xui bug shows it (needs Advanced Debugging)."
local WHY_DISABLED = "Stat Calculator: on, but it could not load this session. It is switched off in the game's AddOns list: turn it on, then /reload."
local WHY_MISSING = "Stat Calculator: on, but it could not load this session. Its folder XayaUI_Bonus_StatCalculator is not installed."
local WHY_ERRORED = "Stat Calculator: on, but it could not load this session. Its files stopped with a Lua error while loading. " .. SAVED
local WHY_OTHER = "Stat Calculator: on, but it could not load this session. " .. SAVED
local WHY = {
    disabled = { status = WHY_DISABLED,
        say = "the Stat Calculator is on, but XayaUI Bonus Features: Stat Calculator is switched off in the game's AddOns list. Turn it on, then /reload." },
    missing = { status = WHY_MISSING,
        say = "the Stat Calculator is on, but its folder XayaUI_Bonus_StatCalculator is not installed: it belongs next to XayaUI_Bonus in Interface\\AddOns." },
    -- (round 11a, SD-105 gap) the game loaded the folder, but one of its files stopped with a Lua error
    errored = { status = WHY_ERRORED, err = true, say = "the Stat Calculator is on, but its files stopped with a Lua error while loading. " .. SAVED },
    other = { status = WHY_OTHER, err = true },   -- (its chat line carries the game's own reason: Load below)
}
local loadSay, loadWhy, loadErr = nil, WHY_OTHER, false
-- one of the reason lines: an error through core's ns.PrintError (saved, SD-139; the record keeps the chat line `loadSay` for both
-- lines, so one failure is one entry counted each time it is told), else an ordinary message
local function Tell(line)
    if loadErr and ns.PrintError then ns.PrintError("XUI-E009", line, loadSay) elseif ns.Print then ns.Print(line) end
end
-- the one-line reason, printed by every /xui stats while it cannot load (SD-146) and by the character window's first try
local function SayWhy() if loadSay then Tell(loadSay) end end
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
    loadWhy, loadErr = WHY[cause].status, WHY[cause].err == true
    loadSay = WHY[cause].say or ("the Stat Calculator could not load (" .. tostring(ok and reason or loaded) .. "). " .. SAVED)
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
-- (round 11a repair 1) FilesErrored: true from the moment the error watch above saw a Lua error from a calculator file during this
-- session's load, so a later file of the calculator can see, while it is still being read, that an earlier one did not finish and
-- stand down instead of starting on a half-read model (round 11 repair: StatCalculator.lua does, at its top, together with its
-- "statModel" check, which also holds when nothing could be watched).
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
        if loadTried and not loadOk then Tell(loadWhy); return end
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
