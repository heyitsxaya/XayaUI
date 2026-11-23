-------------------------------------------------------------------------------
-- XayaUI Debug: the run logger (round 11b). Settings > Debugging > "Advanced debug logging".
--
-- Her words (REQUEST-LOG, verbatim):
--   SD-121 "sure, prompt me before I go into an instance if this is the one I want to log for the test each time until it's done"
--   SD-122 "After loading, before pull (Recommended)": right after the loading screen into a dungeon, key or raid, never in combat, one
--          small window "Log this run for the XayaUI test? Yes / No"
--   SD-123 "Create a separate tick element inside XayaUI debug and by default it should be off except for this one round"
--   SD-124 "Set number of runs (Recommended)": done after 3 logged Mythic+ keys and 2 logged raid bosses; then it stops asking and says
--          once in chat to send the file
--   SD-125 "No, logger ships with it (Recommended)": bundle 1 does not wait for her logs
--   SD-128 "Logger records them (Recommended)": it records the hidden-data spec's section 8 answers itself (counts and yes / no only)
--   SD-149 "Logger box, works alone": its own tick box, working while Advanced Debugging stays off
--   SD-113 (no new addon folder): the code lives here, in XayaUI_Debug.
--
-- HOW IT LOADS (technical choice, SD-145; V14 / V34). XayaUI core (XayaUI/DebugRecord.lua, "The run logger's hook") reads the box. While it
-- is on and this folder is not loaded, one core frame listens to PLAYER_ENTERING_WORLD (a loading screen) and, the first time one lands in
-- a dungeon or raid, loads this folder and calls Arrive below. With Advanced Debugging off, every other file of this folder returns at its
-- first line (ns.DebugToolsWanted), so only the logger runs. With Advanced Debugging on, the folder loads at the login with the tools, and
-- core calls Sync at the login. Loading this file registers nothing: frames and events are made only when the box is on (Sync).
--
-- WHAT IT ASKS. After a loading screen that lands in a dungeon, Mythic+ key or raid (not a /reload: see Arrive), the window "Log this run
-- for the XayaUI test?" with Yes and No. Never in combat: a loading screen that lands in combat lockdown is handled after combat (the
-- arrival waits); if combat starts while the window is up, it hides and comes back after combat, still asking (a question over a pull
-- would cover the fight). "After combat" is the first frame after PLAYER_REGEN_ENABLED, not that event's own frame (repair 2, technical
-- choice, SD-145): the event only arms one 0-second timer (C_Timer.After(0, AfterCombatSafe), a file-level function, SD-90), because
-- setting a run up and showing the window is about 1000 instructions billed to XayaUI_Debug (stand-in: 1046 in the combat-end frame
-- before repair 2, tests/fix_r11_logger_run.py C5), over its cap of 600 (SD-81) at combat end, one of the four capped moments (V33);
-- core's hook defers its folder read the same way. A pull chained before that frame keeps the wait for the next end of combat.
-- INFERENCE (not in docs/reference/api): a 0-second C_Timer.After runs at the next frame, as the stand-in's timers do. While she has
-- not answered, the run is recorded only in memory; No drops it (nothing is saved, the logger lets go of every event but the loading
-- screen one), Yes keeps it from the moment she arrived. It asks again at the next instance, until done (SD-121, SD-124).
-- LEAVING AND COMING BACK (spec section 8 step 9, open question 11). A loading screen out of a logged run into the open world (or any
-- place that is not a dungeon or raid) keeps the run open and marked away (away = 1, with the time she left in seen): it records
-- nothing in the open world and listens only to the loading-screen events. The run keeps its instance ID in the saved file while it is
-- open, away or not (repair 2: as it already does while she is inside, for the /reload resume; a closed run never holds it), so a
-- /reload, a disconnect or a logout while away does not split the run either. Back into the same instance within RESUME_S of leaving,
-- the run resumes without asking (one re-entry counted, the seconds away added, the hidden state at that moment read:
-- "loading-screen-in-run"); into another dungeon or raid, or after RESUME_S, it is closed and the new place asks. The re-entry's own
-- loading screen is recorded too (repair 2): while away, LOADING_SCREEN_ENABLED starts a capture of that loading screen's restriction
-- events (Map and Chat change there, open question 11), kept in front of the resumed run's PE line, dropped if the loading screen does
-- not end in a resume. A finished key is closed as she leaves it: GetInstanceInfo's instanceID names the dungeon, not the visit
-- (INFERENCE: globals.md documents only "instanceID: number"), so a later key in the same dungeon must be a new run; for the same
-- reason a new key started inside an open run that already started one (CHALLENGE_MODE_START after an earlier one, a reset or a
-- finish: an abandoned key followed by a new one) closes that run and opens a new one, kept without asking (repair 2, technical choice:
-- she said Yes for this visit, and the question never shows at a key start, right before the first pull, SD-122). INFERENCE: a key
-- cannot be started in combat lockdown; a start in lockdown is counted (cs) without the split.
--
-- WHAT IT SAVES (XayaUI_Debug.lua in SavedVariables, XayaUIRunLogDB; nothing else is written): counts, yes / no and whole numbers only.
-- NEVER names (no character, realm, dungeon, boss or spell name), chat, GUIDs or spell names; no map or encounter ID. The one ID kept
-- is the instance ID of a run still open (inst: GetInstanceInfo's instanceID, the dungeon's, so a /reload or a re-entry continues the
-- same run); it is dropped when the run closes, so a closed run holds counts only. Per run:
--   kind ("party" | "raid"), difficulty ID, group size, key (0/1), key finished (0/1), bosses killed, wipes, length (s), pulls,
--   the player's UNIT_AURA events heard (and how many while auras were hidden), seconds auras / cooldowns were hidden, times auras became hidden,
--   t10 (length in tenths, for a resume) / leaves / reentries / reloads / awayS (seconds away) / cs (key starts) / cr (key resets) / split (1: opened by a new key in the same
--   instance); while open only: open, inst (the instance ID, dropped at the close), seen (wall-clock seconds), away (1 while away)
--   ev:   the order of the restriction, combat, encounter, key and loading-screen events (spec section 8 step 1, open questions 1-3), each
--         "<tenths of a second since arrival> <code> <arg1> <arg2> L<lockdown> A<auras hidden> C<cooldowns hidden> S<state of types
--         0,1,2,4,5> X<IsAddOnRestrictionActive of types 0,1,2,4,5>" (codes below, EV_CODES)
--   disp: during ADDON_RESTRICTION_STATE_CHANGED, whether IsAddOnRestrictionActive answered true for that type (open question 3)
--   at:   the hidden state at the moments section 8 asks about (key between pulls, raid between bosses, an encounter while not in combat
--         lockdown, a loading screen inside a run: steps 2, 3, 4, 9)
--   shape: the UNIT_AURA payload's shape (step 5): sampled after each state change, counted by signature
--   probe: once per pull, in combat while cooldowns are hidden: the hidden-value operations on the global cooldown's duration, the
--         duration object's readers and the aura instance ID read (steps 6, 7, 8), each ok (1) or error (0); for the readers hidden (1),
--         readable (0) or error (e)
--   pull: one line per pull: length, UNIT_AURA count and the most in one second, seconds hidden, boss, the engine's pass counts
--         (XayaUI Rules' ns.EngineStats), XayaUI's CPU (C_AddOnProfiler) and memory (GetAddOnMemoryUsage) per addon after the pull, and
--         how many errors XayaUI saved during it
--   err:  the errors and warnings XayaUI saved during the run (SD-139 error record), counted by code
--   ver:  the XayaUI versions that logged it
-- Bounds (measured in tests/fix_r11_logger_run.py, stand-in numbers): MAX_RUNS runs, MAX_EV event lines, MAX_PULLS pull lines and
-- MAX_KEYS distinct keys in each count table per run; past a cap a line is dropped and counted (evDrop, pullDrop).
--
-- COST (V27 / V33; XayaUI_Debug's per-event cap is 600 instructions, SD-81). Box off, or no run open: nothing here runs (no frame,
-- event or timer; after "No", only the loading-screen event, which fires at loading screens only; while away from a run, the start of a
-- loading screen too, and a restriction event only between that start and its PLAYER_ENTERING_WORLD). While a run is open, every fight
-- frame stays small (technical choice, SD-145): an event at a state change stores its numbers raw (Raw: the time, a code and the hidden
-- state packed into one number; no string is made; a restriction event reads IsAddOnRestrictionActive for its own type only, the
-- settled reading all five); UNIT_AURA adds to counters and does at most one job per frame (Ua job, round 11b final fix): the fight's
-- settled reading when due, else a step of the once-per-pull probe when due (five small steps 0.2 s apart; its answers packed into one
-- number), else one payload read for the first SHAPE_SAMPLES frames after a change (packed too). No timer is armed in a fight frame (in
-- the gate's key fight each arming bills the frame a timer record; before the final fix the settled reading and the probe ran on timer
-- chains, judged P2 by the gate, and combat start, a boss pull and the boss down cost XayaUI_Debug up to 1,300 instructions, over its
-- 600, SD-81); out of a fight the settled reading's timer is a one-shot, at most one per frame that changed something, and no timer
-- callback arms another (C_Timer.After with file-level functions: no function is made per call, SD-90). UNIT_AURA is heard for the
-- player only (RegisterUnitEvent, widgets.md; as the spec's section 8 step 5 reads it): in a key the target's, the group's and the
-- nameplates' aura messages far outnumber the player's, and each one heard is a handler run in a fight frame (round 11b final fix: the
-- gate's key fight fires the player's and the target's in every fight frame). INFERENCE: a fight sends the player's UNIT_AURA every few
-- frames (her own buffs and their updates); a fight that sends none after its settled reading is due gets no
-- settled reading in the fight and no probe (the reading after combat still comes, from its timer). Everything that makes text (the ev
-- lines, the count tables, the probe line, the pull line with the CPU and memory meters) runs out of combat: at the settled reading
-- SETTLE_S after the last change once combat is over, when a run closes, and at the logout. One after-combat timer at a time.
-- tests/fix_r11_logger_run.py measures the instructions each moment costs (combat start, the boss pull, the boss kill, combat end, the
-- costliest storm frame, the fight frames with the settled reading and the probe steps) and holds each under 600; the gate
-- (tests/gate_performance_run.py) holds every fight frame of the key fight to 600 (SD-81).
-- ERRORS. A handler that fails stops the logger for the session (every event let go, the window hidden) and prints one line through the
-- SD-139 helper (ns.PrintError, XUI-E019: saved in the error record); nothing else of XayaUI is touched. /reload starts it again.
--
-- Game API (docs/reference/api/api.json, 12.1.5; INFERENCE where marked):
--   C_Secrets.ShouldAurasBeSecret() -> bool; C_Secrets.ShouldCooldownsBeSecret() -> bool (no flags)
--   C_RestrictedActions.GetAddOnRestrictionState(type) -> Enum.AddOnRestrictionState (0 Inactive, 1 Activating, 2 Active);
--   C_RestrictedActions.IsAddOnRestrictionActive(type) -> bool (both SecretArguments=AllowedWhenUntainted; only literal numbers passed)
--   Enum.AddOnRestrictionType: Combat 0, Encounter 1, ChallengeMode 2, PvPMatch 3, Map 4, Chat 5 (PvP is not logged, spec L5)
--   InCombatLockdown() (a global; api.json lists it as "documented but not present" in C_RestrictedActions)
--   C_ChallengeMode.IsChallengeModeActive() -> bool; IsInInstance(); GetInstanceInfo() (name is never read)
--   issecretvalue / issecrettable / canaccesstable (SecretArguments=AllowedWhenUntainted: each call is under pcall, and an error is itself
--   recorded as the answer "e")
--   C_UnitAuras.GetUnitAuraInstanceIDs(unit, filter) (RequiresUnitAuraAccess: pcall; the spec's open question 10)
--   C_Spell.GetSpellCooldown(61304) (SecretWhenCooldownsRestricted); C_Spell.GetSpellCooldownDuration(61304) -> LuaDurationObject
--   (61304 is the global cooldown spell, as XayaUI_Rules/Engine.lua and Triggers.lua read it)
--   C_AddOnProfiler.GetAddOnMetric(name, Enum.AddOnProfilerMetric) -> number (EncounterAverageTime 2, RecentAverageTime 1, PeakTime 4);
--   INFERENCE (not documented): milliseconds; saved as whole microseconds
--   UpdateAddOnMemoryUsage(); GetAddOnMemoryUsage(name) -> number; INFERENCE: kilobytes; saved whole
--   C_AddOns.IsAddOnLoaded(name), C_AddOns.GetAddOnMetadata(name, "Version")
--   Events (events.md): ADDON_RESTRICTION_STATE_CHANGED (type, state), PLAYER_REGEN_DISABLED / ENABLED, ENCOUNTER_START (encounterID,
--   encounterName, difficultyID, groupSize), ENCOUNTER_END (..., success), CHALLENGE_MODE_START (mapID), CHALLENGE_MODE_COMPLETED,
--   CHALLENGE_MODE_RESET (mapID), LOADING_SCREEN_ENABLED / DISABLED, PLAYER_ENTERING_WORLD (isInitialLogin, isReloadingUi),
--   PLAYER_LOGOUT, UNIT_AURA (unitTarget, updateInfo; SecretWhenAurasRestricted). Only the documented booleans and numbers are kept;
--   encounterName and mapID are never stored.
-- V26: nothing here opens a XayaUI window but the question, which never shows in combat. V29: the window takes no keyboard.
-- UNVERIFIED IN GAME: all of it (the stand-in plays it in tests/fix_r11_logger_run.py).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI)

local TARGET_KEYS, TARGET_BOSSES = 3, 2   -- (SD-124) done after 3 logged Mythic+ keys and 2 logged raid bosses
local SAVE_FILE = "XayaUI_Debug.lua"      -- the game names the saved-variables file after the addon (XayaUI_Debug.toc ## SavedVariables)
local DB_NAME = "XayaUIRunLogDB"
local FORMAT = 1
local MAX_RUNS, MAX_EV, MAX_PULLS, MAX_KEYS = 8, 200, 40, 24
local SHAPE_SAMPLES = 8        -- UNIT_AURA payloads read after each state change
local SETTLE_S = 2             -- seconds after the last state change before the "settled" reading
local RESUME_S = 900           -- a run (or a "No") belongs to the same visit when its instance is re-entered within this many seconds
local GCD_SPELL = 61304
-- the XayaUI addons whose CPU and memory are read after a pull (short names keep the line small)
local METER_ADDONS = { { "XayaUI", "core" }, { "XayaUI_Rules", "rules" }, { "XayaUI_Options", "opt" }, { "XayaUI_Debug", "dbg" },
    { "XayaUI_Bonus", "bonus" }, { "XayaUI_Bonus_StatCalculator", "calc" } }
-- the event codes of the ev lines (documented here for whoever reads the file)
local EV_CODES = {
    AR = "logger arrived (args: isInitialLogin, isReloadingUi)", Y = "she answered Yes", PE = "PLAYER_ENTERING_WORLD inside the run",
    RS = "ADDON_RESTRICTION_STATE_CHANGED (type, state)", RD = "PLAYER_REGEN_DISABLED", RE = "PLAYER_REGEN_ENABLED",
    ES = "ENCOUNTER_START", EE = "ENCOUNTER_END (success)", CS = "CHALLENGE_MODE_START", CC = "CHALLENGE_MODE_COMPLETED",
    CR = "CHALLENGE_MODE_RESET", LE = "LOADING_SCREEN_ENABLED", LD = "LOADING_SCREEN_DISABLED", ST = "settled reading, " .. SETTLE_S .. " s after a change",
    LV = "a loading screen out of the run (open world): the run stays open for a re-entry within " .. RESUME_S .. " s",
    NK = "a new key started in the same instance: the run before it was closed and this one opened (no question: SD-122)",
}
local issecret = issecretvalue or function() return false end
local floor = math.floor

-------------------------------------------------------------------------------
-- State. Everything below is nil / zero until the box is on and a run starts.
-------------------------------------------------------------------------------
local db                 -- XayaUIRunLogDB, opened at the first Sync / Arrive after the game set it
local evFrame            -- made the first time an event is needed
local evOn = {}          -- [event] = true while registered
local run                -- the run being recorded (pending: in memory only; live: also db.runs[...])
local pending = false    -- the question is up or waiting, run not yet kept
local pendInst           -- instance ID of the pending run
local waitAsk = false    -- the question waits for the end of combat
local declinedInst, declinedAt   -- (memory only) the instance she said No to, and when she was last there
local stopped = false    -- a handler failed: nothing more this session
local lastArrive         -- GetTime() of the last arrival handled (core and this frame may both hand the same loading screen)
local awayRun, awayAt     -- a logged run she left for the open world (also marked away = 1 in the file) and when she left (GetTime)
local capT               -- while away: GetTime() at the start of a loading screen whose restriction events are being captured, else nil
local arriveWait = false          -- a loading screen landed in combat lockdown: handled in the first frame after combat (AfterCombat)
local arriveLogin, arriveReload   -- its two arguments
local afterArmed = false          -- the one 0-second timer after PLAYER_REGEN_ENABLED is armed
local t0 = 0             -- GetTime() at arrival (run time base)
-- counters kept in locals on the hot path, written into the run at Flush
local uaN, uaHidN, uaBase, uaHidBase = 0, 0, 0, 0   -- (uaHidN, the events heard while auras were hidden, is kept by the hide and unhide
                                                   -- moments, never per event: -uaN at a hide, +uaN at the unhide; Flush adds an open one)
local secEnd, secN, peak = 0, 0, 0
local shapeLeft = 0
local shapeN = {}                    -- [packed payload signature] = count, turned into run.shape at Drain
local hidA, hidC = false, false      -- auras / cooldowns hidden now
local hidASince, hidCSince = 0, 0
local hidAAcc, hidCAcc = 0, 0        -- seconds hidden so far this session (added to the run's saved totals at Flush)
local hidABase, hidCBase = 0, 0
local inEnc = false
local pull                           -- the pull in progress or waiting for its meters
-- (round 11b final fix) the settled reading: due at settleDue (nil: none waits). Out of combat a one-shot timer reads it (at most one
-- armed per frame that changed something: ArmSettle); in a fight no timer is armed (each costs a fight frame a timer record, V33), and
-- the first UNIT_AURA at or after settleDue reads it (fightSettle). In the combat-end frame (capped too) the timer is not armed either:
-- the first UNIT_AURA of a later frame arms it (armWanted). No timer callback arms another timer (P2: no chain).
local settleDue, armedAt = nil, nil
local fighting = false               -- between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED of a run
local endT                           -- GetTime() of the last combat-end frame (PLAYER_REGEN_ENABLED)
local fightSettle, armWanted = false, false
local jobT                           -- the frame of the last UNIT_AURA job (at most one job per frame beyond the counters)
local jobs = false                   -- a UNIT_AURA job may be waiting (UaJob clears it when none is)
local jobAfter = 0                   -- the UNIT_AURA count after which jobs may run again (a change's frame and the events right after it run none)
local errBase                        -- [code] = count when the run started
local errSeen = 0                    -- errors XayaUI saved during the run, as of the last out-of-combat reading
-- the raw event buffer: numbers only, turned into ev lines at Drain (out of combat)
local RAW_MAX = 64
local rawN, rawDrop = 0, 0
local rT, rC, rA, rB, rP = {}, {}, {}, {}, {}
local svc = {}
local CODES = { "AR", "Y", "PE", "RS", "RD", "RE", "ES", "EE", "CS", "CC", "CR", "LE", "LD", "ST", "LV", "NK" }
local C_ = {}
for i, c in ipairs(CODES) do C_[c] = i end

-------------------------------------------------------------------------------
-- Small readers (each safe: a missing API reads "?")
-------------------------------------------------------------------------------
local function Arg(v)   -- an event argument: only booleans and whole numbers are kept, never a string
    local t = type(v)
    if v == nil then return "-" end
    if issecret(v) then return "s" end
    if t == "boolean" then return v and "1" or "0" end
    if t == "number" then return tostring(floor(v)) end
    return "?"
end
local function Lockdown() return InCombatLockdown and InCombatLockdown() and true or false end
local function InFight()
    if Lockdown() then return true end
    local ok, v = pcall(UnitAffectingCombat, "player")
    return ok and v == true
end
local function AurasHidden()
    local S = C_Secrets
    if not (S and S.ShouldAurasBeSecret) then return nil end
    local ok, v = pcall(S.ShouldAurasBeSecret)
    if ok and not issecret(v) then return v and true or false end
    return nil
end
local function CooldownsHidden()
    local S = C_Secrets
    if not (S and S.ShouldCooldownsBeSecret) then return nil end
    local ok, v = pcall(S.ShouldCooldownsBeSecret)
    if ok and not issecret(v) then return v and true or false end
    return nil
end
local function KeyActive()
    local C = C_ChallengeMode
    if not (C and C.IsChallengeModeActive) then return false end
    local ok, v = pcall(C.IsChallengeModeActive)
    return ok and v == true
end
local function Tri(v) if v == nil or issecret(v) then return 2 end return v and 1 or 0 end
-- The game functions the fight-frame path calls, looked up once when a run starts (Bind): no table lookup per event. nil when this
-- client has no such function (the part it answers then reads "?").
local fLock, fSA, fSC, fRS, fRA
local stS = nil       -- the five restriction states as last read, packed (nil: to be read again; Pack below)
local acOK, baseP     -- (Pack below)
local stale = false   -- (Pack below: false, or the restriction type read at a restriction event (ALLX: several), to be read again by the next UNIT_AURA frame)
local function BindApi()
    local S, R = C_Secrets, C_RestrictedActions
    fLock = InCombatLockdown
    fSA, fSC = S and S.ShouldAurasBeSecret, S and S.ShouldCooldownsBeSecret
    fRS, fRA = R and R.GetAddOnRestrictionState, R and R.IsAddOnRestrictionActive
    stS, acOK, baseP, stale = nil, false, nil, false   -- (Pack reads them again)
end
-- The hidden state packed into one whole number (no string, no table: it runs at every state-change event, in fights too):
-- ((L * 3 + A) * 3 + C) * 1024 + S) * 243 + X, where L / A / C are lockdown, auras hidden, cooldowns hidden (0 no, 1 yes, 2 unknown),
-- S the states of types 0, 1, 2, 4, 5 in base 4 (0 Inactive, 1 Activating, 2 Active, 3 unknown) and X their IsAddOnRestrictionActive
-- answers in base 3 (0, 1, 2 unknown). Decoded into "L0 A1 C1 S00202 X00101" by StateText. L is read at every event. xt says what else:
--   ALLX (the settled readings, an arrival, a resume): A, C, every S and every X, read now;
--   XONLY (the fight's settled reading): every X read now; A, C and S as last read (the refresh job read them in an earlier frame);
--   a restriction type number (a restriction event of that type): that type's S and X read now (its dispatch is what open question 3
--     asks about; Drain's disp count reads that type only), out of a fight A and C too; the other S as last read, the other X unknown;
--   nil (every other event): A, C and S as last read, X unknown.
-- (round 11b final fix, V33: every event read A, C and all five S, and a restriction event all five X, in fight frames; in the gate's
-- key fight combat start, a boss pull and the boss down cost XayaUI_Debug up to 1,300 instructions, over its 600, SD-81.) "As last read"
-- is kept packed (baseP, from pa, pc, stS). It is exact between restriction events: auras and cooldowns are hidden, and a restriction's
-- state changes, only as a restriction changes, which sends its event (INFERENCE from events.md, ADDON_RESTRICTION_STATE_CHANGED (type,
-- state), and C_Secrets' ShouldAurasBeSecret / ShouldCooldownsBeSecret). The moment right after one (the stand-in's Activating becomes
-- Active, and the auras hide, right after the dispatch, tests/harness/world.lua) is read again: out of a fight by the next event (it
-- reads A, C and all five S); in a fight by the next UNIT_AURA frame (UaJob: stale), so a fight frame never reads them twice, and an
-- event after a restriction event in the same fight frame shows the state that event read. The functions are documented to return a
-- plain boolean or enum number (api.json: no secret-return flag), so they are read as plain values here; were one to return a hidden
-- value, the test of it would raise an error and the logger would stop (svc.Fail), never guess.
local ALLX = -1
local X_DIV = { [0] = 1, 3, 9, nil, 27, 81 }
local S_DIV = { [0] = 1, 4, 16, nil, 64, 256 }
local pa, pc = 2, 2   -- the auras / cooldowns digits as last read (Recompute reads them instead of asking the game again)
acOK = false          -- pa / pc are good to reuse (dropped at every restriction event)
local function ReadS()
    if not fRS then return 1023 end
    return (fRS(0) or 3) + 4 * (fRS(1) or 3) + 16 * (fRS(2) or 3) + 64 * (fRS(4) or 3) + 256 * (fRS(5) or 3)
end
local acNew = false   -- A / C were read since the last Recompute (Transition reads it)
-- baseP: the packed state with L 0 and every X unknown, made from pa, pc and stS (nil: made again when needed)
local function ReadAC()
    pa = fSA and (fSA() and 1 or 0) or 2
    pc = fSC and (fSC() and 1 or 0) or 2
    acOK, acNew, baseP = true, true, nil
end
local function Base()
    if not acOK then ReadAC() end
    if stS == nil then stS = ReadS() end
    baseP = ((pa * 3 + pc) * 1024 + stS) * 243 + 242
    return baseP
end
local XONLY = -2      -- (the fight's settled reading: every X read now; A, C and S as last read, the refresh job having just read them)
local LMUL = 3 * 3 * 1024 * 243   -- (the lockdown digit's weight)
local function Pack(xt, sv)   -- sv: a restriction event's own state argument (its type's S then comes from the event, not a read)
    local L = (fLock and fLock()) and LMUL or 0
    if xt == nil then return (baseP or Base()) + L end   -- (every event but a restriction event and a full reading: L read now)
    if xt >= 0 then
        -- a restriction event: that type's S and X read now; out of a fight A and C too (in a fight the next UNIT_AURA frame does). The
        -- state read is kept (stS, baseP) for the events after it in this frame, and marked stale: the next UNIT_AURA frame reads A, C
        -- and all five S again (UaJob), so the moment right after the dispatch is read too
        if not fighting then ReadAC() end
        local p, d = baseP or Base(), S_DIV[xt]
        stale, jobs = (stale and stale ~= xt) and ALLX or xt, true   -- (the type to read again; two different types: all five)
        if d then
            -- (the event's state argument is that type's state: documented plain, events.md; read only when it is not a number)
            local now = (type(sv) == "number" and sv >= 0 and sv <= 2) and sv or (fRS and fRS(xt))
            if now then
                local dS = 243 * d * (now - floor(stS / d) % 4)
                p = p + dS
                baseP, stS = p, stS + dS / 243
            end
            if fRA then p = p - X_DIV[xt] * (fRA(xt) and 1 or 2) end   -- (242: every digit 2 unknown; that type's digit 2 -> 1 or 0)
        end
        -- (out of a fight, frames are not capped: an event after this one in the same frame reads A, C and S again, as they are after the
        -- dispatch; in a fight it takes them as read here, and the next UNIT_AURA frame reads them again)
        if not fighting then stS, acOK, baseP = nil, false, nil end
        return p + L
    end
    if xt == ALLX then ReadAC(); stS, stale = ReadS(), false end
    local p = baseP or Base()
    if fRA then
        p = p - 242 + (fRA(0) and 1 or 0) + 3 * (fRA(1) and 1 or 0) + 9 * (fRA(2) and 1 or 0) + 27 * (fRA(4) and 1 or 0) + 81 * (fRA(5) and 1 or 0)
    end
    return p + L
end
local TRI_CH, ST_CH = { [0] = "0", "1", "?" }, { [0] = "0", "1", "2", "?" }
local function StateText(p)
    local x = p % 243; p = (p - x) / 243
    local st = p % 1024; p = (p - st) / 1024
    local c = p % 3; p = (p - c) / 3
    local a = p % 3
    local L = (p - a) / 3
    local s0, s1, s2, s4, s5 = st % 4, floor(st / 4) % 4, floor(st / 16) % 4, floor(st / 64) % 4, floor(st / 256) % 4
    local x0, x1, x2, x4, x5 = x % 3, floor(x / 3) % 3, floor(x / 9) % 3, floor(x / 27) % 3, floor(x / 81) % 3
    return ("L%s A%s C%s S%s%s%s%s%s X%s%s%s%s%s"):format(TRI_CH[L], TRI_CH[a], TRI_CH[c], ST_CH[s0], ST_CH[s1], ST_CH[s2], ST_CH[s4], ST_CH[s5],
        TRI_CH[x0], TRI_CH[x1], TRI_CH[x2], TRI_CH[x4], TRI_CH[x5]), x, L
end
-- the "active" answer for one type out of a packed X
local function ActiveOf(x, t) local d = X_DIV[t]; if not d then return "?" end return TRI_CH[floor(x / d) % 3] end
local function InGroupInstance()
    if not IsInInstance then return false end
    local ok, inside, kind = pcall(IsInInstance)
    if ok and inside == true and (kind == "party" or kind == "raid") then return true, kind end
    return false
end
local function Num(v) if type(v) == "number" and not issecret(v) then return floor(v) end return nil end
-- the instance's kind, difficulty, size and ID (the ID only to know a re-entry; never saved in a closed run). Its name is never read.
local function InstanceInfo()
    if not GetInstanceInfo then return nil end
    local ok, _, kind, diff, _, size, _, _, id = pcall(GetInstanceInfo)
    if not ok then return nil end
    return (type(kind) == "string" and not issecret(kind)) and kind or nil, Num(diff), Num(size), Num(id)
end
local function Count(t, key, n)   -- n more (1 by default) for key in a bounded count table
    n = n or 1
    local have = t[key]
    if have then t[key] = have + n; return end
    local k = 0
    for _ in pairs(t) do k = k + 1; if k >= MAX_KEYS then t["(more)"] = (t["(more)"] or 0) + n; return end end
    t[key] = n
end

-------------------------------------------------------------------------------
-- Saved data
-------------------------------------------------------------------------------
-- the saved data, made the first time a run is kept (her Yes): a session that keeps no run (the box on but never in an instance, or only
-- "No") writes nothing to the file at all (repair 2: before, the first loading screen made XayaUIRunLogDB with its code list). PeekDB
-- reads it only when an earlier session made it.
local function OpenDB()
    if db then return db end
    local d = rawget(_G, DB_NAME)
    if type(d) ~= "table" then d = {}; rawset(_G, DB_NAME, d) end
    d.v = d.v or FORMAT
    d.keys = tonumber(d.keys) or 0
    d.bosses = tonumber(d.bosses) or 0
    if type(d.runs) ~= "table" then d.runs = {} end
    d.target = ("%d Mythic+ keys and %d raid bosses"):format(TARGET_KEYS, TARGET_BOSSES)
    d.codes = EV_CODES
    db = d
    return d
end
local function PeekDB()
    if db then return db end
    if type(rawget(_G, DB_NAME)) == "table" then return OpenDB() end
    return nil
end
local NO_RUNS = {}
-- the errors and warnings XayaUI has saved so far (SD-139 record), summed by code
local function ErrSums()
    local out = {}
    local list = ns.ErrorEntries and ns.ErrorEntries() or {}
    for _, e in ipairs(list) do
        if type(e) == "table" and type(e.code) == "string" then out[e.code] = (out[e.code] or 0) + (tonumber(e.n) or 1) end
    end
    return out
end
local function ErrDelta()
    local now, d, total = ErrSums(), {}, 0
    for code, n in pairs(now) do
        local k = n - ((errBase and errBase[code]) or 0)
        if k > 0 then d[code] = k; total = total + k end
    end
    return d, total
end
local function Versions()
    local t = {}
    local A = C_AddOns
    if not (A and A.IsAddOnLoaded and A.GetAddOnMetadata) then return "?" end
    for _, a in ipairs(METER_ADDONS) do
        local ok, loaded = pcall(A.IsAddOnLoaded, a[1])
        if ok and loaded then
            local ok2, v = pcall(A.GetAddOnMetadata, a[1], "Version")
            t[#t + 1] = a[2] .. " " .. ((ok2 and type(v) == "string") and v or "?")
        end
    end
    return table.concat(t, ", ")
end

-------------------------------------------------------------------------------
-- Recording
-------------------------------------------------------------------------------
local GetTime = GetTime or function() return 0 end   -- (looked up once: the clock every event and UNIT_AURA reads)
local function Now() return GetTime() end
local function Wall() return time and time() or 0 end
-- the hidden state changed? (read at state-change events only: the game hides auras and cooldowns only as a restriction changes)
local function Recompute(now)   -- (always right after a Raw, whose Pack read the two answers: pa, pc)
    local a, c = pa == 1, pc == 1
    if a ~= hidA then
        if hidA then hidAAcc, uaHidN = hidAAcc + (now - hidASince), uaHidN + uaN else run.flips, uaHidN = (run.flips or 0) + 1, uaHidN - uaN end
        hidA, hidASince = a, now
    end
    if c ~= hidC then
        if hidC then hidCAcc = hidCAcc + (now - hidCSince) end
        hidC, hidCSince = c, now
    end
end
local function HidTotals(now)
    return hidAAcc + (hidA and (now - hidASince) or 0), hidCAcc + (hidC and (now - hidCSince) or 0)
end
-- one event, raw: its time, code, two arguments (kept as they came; turned into text, never a string argument, at Drain) and the
-- packed hidden state, with the encounter flag as its sign (negative: inside an encounter)
local function Raw(code, a, b, xt)   -- returns the time it read (the handlers pass it on: one GetTime per event)
    local p = Pack(xt, b)   -- (first, also when the buffer is full: Recompute reads its two answers)
    local now = Now()
    if rawN >= RAW_MAX then rawDrop = rawDrop + 1; return now end
    local n = rawN + 1
    rawN = n
    rT[n], rC[n], rA[n], rB[n], rP[n] = now, code, a, b, inEnc and -(p + 1) or p
    return now
end
-- The payload's signature (spec section 8 step 5), packed: h<auras hidden now> u<unitTarget hidden> i<payload hidden> t<issecrettable>
-- a<canaccesstable> f<isFullUpdate: r readable, s hidden, e error, - nil>; t and a read "e" when the call raised an error
local SIG = { [0] = "0", "1", "?", "e" }
local FULL = { [0] = "r", "s", "e", "-" }
local function ReadFull(i) return i.isFullUpdate end
local function Tr(fn, v)   -- 0 / 1 / 2 unknown / 3 error
    if not fn then return 2 end
    local ok, r = pcall(fn, v)
    if not ok then return 3 end
    return Tri(r)
end
local function ShapeCode(unit, info)
    local ok, r = pcall(ReadFull, info)
    local f = (not ok and 2) or (r == nil and 3) or (issecret(r) and 1) or 0
    return (hidA and 1 or 0) + 4 * Tri(issecret(unit)) + 16 * Tri(issecret(info)) + 64 * Tr(issecrettable, info) + 256 * Tr(canaccesstable, info) + 1024 * f
end
local function ShapeText(k)
    return ("h%s u%s i%s t%s a%s f%s"):format(SIG[k % 4], SIG[floor(k / 4) % 4], SIG[floor(k / 16) % 4], SIG[floor(k / 64) % 4],
        SIG[floor(k / 256) % 4], FULL[floor(k / 1024) % 4])
end
-- The probe's answers (spec section 8 steps 6, 7, 8; ProbeStep below), packed into one whole number per probe in the fight (no string
-- there) and turned into the probe's text line at Drain: d the global cooldown's duration (0 none, 1 readable, 2 hidden); while hidden,
-- whether tostring, tonumber, # and a table key read of it worked (1) or raised an error (0); o the duration object (0 no such call,
-- 1 none, 2 the call raised an error, 3 an object); its HasSecretValues (B: 0, 1, s hidden, - nil; 4 an error) and whether IsZero,
-- HasExpired and GetRemainingDuration answered hidden (1), readable (0) or raised an error (2); the aura instance ID read (0 no such call,
-- 1 error, 2 nil, 3 hidden, 4 a table, 5 other).
local probeN = {}   -- [packed answers] = count, turned into run.probe at Drain
local P_TXT = { ok = { [0] = "0", "1" }, b = { [0] = "0", "1", "s", "-", "e" }, hid = { [0] = "0", "1", "e" },
    ids = { [0] = "-", "error", "nil", "hidden", "table", "other" } }
local P_RADIX = { 3, 2, 2, 2, 2, 4, 5, 3, 3, 3, 6 }   -- d, tostring, tonumber, #, key read, o, HasSecretValues, IsZero, HasExpired, Remaining, IDs
local function ProbePack(v)
    local k, m = 0, 1
    for i = 1, #P_RADIX do k = k + (v[i] or 0) * m; m = m * P_RADIX[i] end
    return k
end
local function ProbeText(k)
    local v = {}
    for i = 1, #P_RADIX do local r = P_RADIX[i]; v[i] = k % r; k = (k - v[i]) / r end
    local T = P_TXT
    local a = (v[1] == 2) and ("dur hidden: tostring %s tonumber %s len %s keyread %s"):format(T.ok[v[2]], T.ok[v[3]], T.ok[v[4]], T.ok[v[5]])
        or ("dur " .. ((v[1] == 0) and "none" or "readable"))
    local b = (v[6] == 3) and ("obj HasSecretValues %s IsZero-hidden %s HasExpired-hidden %s Remaining-hidden %s"):format(T.b[v[7]],
        T.hid[v[8]], T.hid[v[9]], T.hid[v[10]]) or ({ [0] = "obj -", "obj none", "obj error" })[v[6]]
    return a .. "; " .. b .. "; auraIDs " .. T.ids[v[11]]
end
local function At(context, st) Count(run.at, context .. " " .. st) end
-- the raw events and payload counts turned into the run's text (out of combat only: string work stays out of the fights)
local function Drain()
    if not run then rawN = 0; return end
    for i = 1, rawN do
        local p = rP[i]
        local enc = p < 0
        if enc then p = -p - 1 end
        local st, x, L = StateText(p)
        local code = CODES[rC[i]] or "?"
        if #run.ev >= MAX_EV then run.evDrop = run.evDrop + 1
        else run.ev[#run.ev + 1] = ("%d %s %s %s %s"):format(floor((rT[i] - t0) * 10), code, Arg(rA[i]), Arg(rB[i]), st) end
        if code == "RS" and type(rA[i]) == "number" and not issecret(rA[i]) then   -- (open question 3)
            Count(run.disp, ("type %s state %s active %s"):format(Arg(rA[i]), Arg(rB[i]), ActiveOf(x, rA[i])))
        end
        if enc and L == 0 then At("encounter-not-in-lockdown", st) end   -- (spec section 8 step 4)
        rA[i], rB[i] = nil, nil
    end
    rawN = 0
    if rawDrop > 0 then run.evDrop = run.evDrop + rawDrop; rawDrop = 0 end
    for k, n in pairs(shapeN) do Count(run.shape, ShapeText(k), n); shapeN[k] = nil end
    for k, n in pairs(probeN) do Count(run.probe, ProbeText(k), n); probeN[k] = nil end
end
-- the run's saved numbers brought up to date (out of combat: at the settled reading, a close and the logout)
local function Flush()
    if not run then return end
    Drain()
    local now = Now()
    run.len = floor(now - t0)
    run.t10 = floor((now - t0) * 10)   -- (the same length in tenths: a resumed run's clock goes on from it, so its lines never go back)
    run.ua, run.uaHid = uaBase + uaN, uaHidBase + uaHidN + (hidA and uaN or 0)
    local a, c = HidTotals(now)
    run.hidA, run.hidC = floor(hidABase + a), floor(hidCBase + c)
    local d, total = ErrDelta()
    run.err, errSeen = d, total
    if run.open then run.seen = Wall() end
end
-- a state change: re-read the hidden state, sample the next payloads, take a settled reading SETTLE_S after the last change. Out of a
-- fight: one one-shot timer per frame that changed something (ArmSettle; a change while one waits moves settleDue, and the earlier
-- timer, finding the reading not due yet, does nothing: no timer callback arms another, P2). In a fight, and in the combat-end frame, no
-- timer: see settleDue above (round 11b final fix).
local SettleSafe   -- (the one file-level function every settle timer calls; defined below)
local Settle
local UaJob        -- (the UNIT_AURA handler's one job per frame; defined below)
local function ArmSettle(now)
    if armedAt ~= now and C_Timer and C_Timer.After then armedAt = now; C_Timer.After(SETTLE_S, SettleSafe) end
end
local trT, trFight   -- the frame of the last Transition, and whether it was in a fight
local function Transition(now)
    now = now or Now()
    if acNew then Recompute(now); acNew = false end
    -- (a second change in the same frame, the fight's state the same and nothing read again: everything below is already so)
    if trT == now and trFight == fighting then return end
    trT, trFight = now, fighting
    shapeLeft, jobT, jobs, jobAfter = SHAPE_SAMPLES, now, true, uaN + 6   -- (payloads and other UNIT_AURA jobs after the next six aura events, about one fight frame of the gate's key fight: its frame stays small)
    settleDue = now + SETTLE_S
    if fighting then fightSettle, armWanted = true, false
    elseif endT == now then fightSettle, armWanted = false, true
    else fightSettle, armWanted = false, false; ArmSettle(now) end
end

-- The probe (spec section 8 steps 6, 7, 8): once per pull, in combat while cooldowns are hidden, in five small steps 0.2 s apart,
-- each run by the first UNIT_AURA due (no timer: round 11b final fix; before, three steps on a timer chain the gate judged P2, each
-- step with its timer about 600 instructions in a fight frame): 1 the global cooldown's duration, and while hidden tostring and
-- tonumber of it; 2 # and a table key read of it; 3 the duration object and its HasSecretValues and IsZero; 4 its HasExpired and
-- GetRemainingDuration; 5 the aura instance ID read, then the answers are counted (packed: ProbePack; text at Drain, out of combat).
-- Each operation: worked (1) or raised an error (0); for the readers, hidden (1), readable (0) or an error (2). A probe that does not
-- finish (no UNIT_AURA before the next pull, or the run closed) is dropped.
local function Len(v) return #v end
local function KeyRead(v) local t = {}; return t[v] end
local function Method(o, name) return o[name](o) end
local function Ok(fn, a) return (pcall(fn, a)) and 1 or 0 end
local function Hid(o, name)
    local ok, r = pcall(Method, o, name)
    if not ok then return 2 end
    return issecret(r) and 1 or 0
end
local probeK, probeDue, probeD, probeO = 0, nil, nil, nil
local probeV = {}
local function ProbeReset() probeK, probeDue, probeD, probeO = 0, nil, nil, nil end
local function ProbeStep(now)
    if not run or stopped then ProbeReset(); return end
    local S, v = C_Spell, probeV
    if probeK == 1 then
        for i = 1, #P_RADIX do v[i] = 0 end
        local d
        if S and S.GetSpellCooldown then
            local ok, c = pcall(S.GetSpellCooldown, GCD_SPELL)
            if ok and type(c) == "table" and not issecret(c) then d = c.duration end
        end
        if d ~= nil and issecret(d) then v[1], v[2], v[3], probeD = 2, Ok(tostring, d), Ok(tonumber, d), d
        else v[1] = (d == nil) and 0 or 1 end
    elseif probeK == 2 then
        if v[1] == 2 then v[4], v[5] = Ok(Len, probeD), Ok(KeyRead, probeD) end
        probeD = nil
    elseif probeK == 3 then
        if S and S.GetSpellCooldownDuration then
            local ok, o = pcall(S.GetSpellCooldownDuration, GCD_SPELL)
            if ok and o ~= nil and not issecret(o) then
                local okH, h = pcall(Method, o, "HasSecretValues")
                v[6], v[7], v[8], probeO = 3, okH and ((h == nil and 3) or (issecret(h) and 2) or (h and 1) or 0) or 4, Hid(o, "IsZero"), o
            else
                v[6] = ok and 1 or 2
            end
        end
    elseif probeK == 4 then
        if probeO then v[9], v[10] = Hid(probeO, "HasExpired"), Hid(probeO, "GetRemainingDuration") end
        probeO = nil
    else
        local U = C_UnitAuras
        if U and U.GetUnitAuraInstanceIDs then
            local ok, r = pcall(U.GetUnitAuraInstanceIDs, "player", "HELPFUL")
            v[11] = (not ok and 1) or (r == nil and 2) or (issecret(r) and 3) or (type(r) == "table" and 4) or 5
        end
        local k = ProbePack(v)
        probeN[k] = (probeN[k] or 0) + 1
        ProbeReset()
        return
    end
    probeK, probeDue = probeK + 1, now + 0.2
end

-- XayaUI's CPU and memory from the game's meters, read once per pull, out of combat
local function Metric(P, name, metric)   -- one CPU reading in whole microseconds (INFERENCE: the game's number is milliseconds)
    if metric == nil then return "?" end
    local ok, v = pcall(P.GetAddOnMetric, name, metric)
    if not ok or type(v) ~= "number" or issecret(v) then return "?" end
    return tostring(floor(v * 1000 + 0.5))
end
local function Loaded(name)
    local A = C_AddOns
    if not (A and A.IsAddOnLoaded) then return false end
    local ok, loaded = pcall(A.IsAddOnLoaded, name)
    return ok and loaded and true or false
end
local function Meters()
    local P, E = C_AddOnProfiler, Enum and Enum.AddOnProfilerMetric
    local cpu, mem = {}, {}
    if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
    for _, a in ipairs(METER_ADDONS) do
        if Loaded(a[1]) then
            if P and P.GetAddOnMetric and E then
                cpu[#cpu + 1] = ("%s=%s/%s/%s"):format(a[2], Metric(P, a[1], E.EncounterAverageTime), Metric(P, a[1], E.RecentAverageTime),
                    Metric(P, a[1], E.PeakTime))
            end
            if GetAddOnMemoryUsage then
                local ok3, kb = pcall(GetAddOnMemoryUsage, a[1])
                mem[#mem + 1] = a[2] .. "=" .. ((ok3 and type(kb) == "number" and not issecret(kb)) and tostring(floor(kb + 0.5)) or "?")
            end
        end
    end
    return (#cpu > 0) and table.concat(cpu, ";") or "-", (#mem > 0) and table.concat(mem, ";") or "-"
end
local ENG = { "routed", "all", "settle", "pollRange", "pollCd", "wake", "alert" }
local function EngineSnap()
    local es = ns.EngineStats
    if type(es) ~= "table" then return nil end
    return { es.routed or 0, es.all or 0, es.settle or 0, es.pollRange or 0, es.pollCd or 0, es.wake or 0, es.alert or 0 }
end
local PullSave
local function PullFill(p)   -- the pull's starting totals (seconds hidden, the engine's passes): from the first UNIT_AURA job after combat start
    local a, c = HidTotals(p.t)
    p.a, p.c, p.eng, p.fill = a, c, EngineSnap(), nil
end
local function PullStart(now)
    if pull and pull.done and not pull.saved then PullSave(false) end   -- (a chained pull: the last one is written without its meters)
    if pull and not pull.done then return end
    probeK, probeDue = 0, nil   -- (a probe the last pull did not finish is dropped)
    -- (round 11b final fix) the combat-start frame keeps only the pull's time and counts; its hidden seconds and the engine's passes so far
    -- are read by the first UNIT_AURA job after it (PullFill), a few frames into the pull (combat start is capped at 600 for XayaUI_Debug)
    pull = { t = now, ua = uaN, err = errSeen, boss = 0, fill = true }
    jobs, secN, peak, secEnd = true, 0, 0, now + 1
end
local function PullEnd(now)   -- (the combat-end frame: the end's raw numbers only; PullSave works the line out, out of combat)
    if not pull or pull.done then return end
    if pull.fill then PullFill(pull) end   -- (no UNIT_AURA job ran in the pull: its start totals are read now)
    local a, c = HidTotals(now)
    pull.done, pull.tE, pull.uaE, pull.pk, pull.aE, pull.cE = true, now, uaN, (secN > peak) and secN or peak, a, c
end
-- the pull's line (out of combat), with the meters unless combat already started again (a chained pull: "-")
function PullSave(withMeters)
    if not pull or not pull.done or pull.saved then return end
    pull.saved = true
    run.pulls = run.pulls + 1
    if #run.pull >= MAX_PULLS then run.pullDrop = run.pullDrop + 1; return end
    local eng = "-"
    local e1 = EngineSnap()
    if e1 and pull.eng then
        local d = {}
        for i = 1, #ENG do d[i] = tostring(e1[i] - pull.eng[i]) end
        eng = table.concat(d, "/")
    end
    local cpu, mem = "-", "-"
    if withMeters then cpu, mem = Meters() end
    local _, errN = ErrDelta()
    run.pull[#run.pull + 1] = ("len %d ua %d peak %d hidA %d hidC %d boss %d eng %s cpu %s mem %s err %d"):format(
        floor(pull.tE - pull.t), pull.uaE - pull.ua, pull.pk, floor(pull.aE - pull.a), floor(pull.cE - pull.c), pull.boss, eng, cpu, mem,
        errN - pull.err)
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local REC_EVENTS = { "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ENCOUNTER_START",
    "ENCOUNTER_END", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET", "LOADING_SCREEN_ENABLED",
    "LOADING_SCREEN_DISABLED", "PLAYER_LOGOUT", "UNIT_AURA" }
local OnEvent
local function SetEvent(e, on)
    if on == (evOn[e] or false) then return end
    if on and not evFrame then
        if not CreateFrame then return end
        evFrame = CreateFrame("Frame")
        evFrame:SetScript("OnEvent", OnEvent)
    end
    if not evFrame then return end
    if on then
        -- (round 11b final fix) the player's UNIT_AURA only (see the header); a hidden unitTarget is then the player's, as AuraAlias.lua reads it
        if e == "UNIT_AURA" and evFrame.RegisterUnitEvent then evFrame:RegisterUnitEvent(e, "player") else evFrame:RegisterEvent(e) end
        evOn[e] = true
    else evFrame:UnregisterEvent(e); evOn[e] = nil end
end
local function Recording(on) for _, e in ipairs(REC_EVENTS) do SetEvent(e, on) end end
local function ReleaseAll() for e in pairs(evOn) do SetEvent(e, false) end end

-------------------------------------------------------------------------------
-- The question window (built the first time it is needed; mouse only, no keyboard: V29)
-------------------------------------------------------------------------------
local prompt
local Answer
local function OnYes() local ok, err = pcall(Answer, true); if not ok and svc.Fail then svc.Fail(err) end end
local function OnNo() local ok, err = pcall(Answer, false); if not ok and svc.Fail then svc.Fail(err) end end
local PROMPT_TEXT = "Log this run for the XayaUI test?"   -- (SD-122, her wording)
local function BuildPrompt()
    local f = CreateFrame("Frame", "XayaUIRunLogPrompt", UIParent, "BackdropTemplate")
    f:SetSize(300, 84)
    f:SetPoint("TOP", UIParent, "TOP", 0, -160)
    f:SetFrameStrata("DIALOG")
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.06, 0.06, 0.07, 0.97)
        f:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
    end
    f:EnableMouse(true)   -- (a window she answers: it takes clicks inside its own rectangle only, V27 / SD-99)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("TOP", 0, -14)
    f.text:SetText(PROMPT_TEXT)
    local yes = CreateFrame("Button", "XayaUIRunLogPromptYes", f, "UIPanelButtonTemplate")
    yes:SetSize(100, 24); yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 14); yes:SetText("Yes")
    yes:SetScript("OnClick", OnYes)
    local no = CreateFrame("Button", "XayaUIRunLogPromptNo", f, "UIPanelButtonTemplate")
    no:SetSize(100, 24); no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 14); no:SetText("No")
    no:SetScript("OnClick", OnNo)
    if ns.FlatButton then ns.FlatButton(yes, true); ns.FlatButton(no) end
    f.yes, f.no = yes, no
    f:Hide()
    return f
end
-- (prompt.up mirrors whether the window is shown: the fight's first frame asks the flag, not the widget, V33)
local function HidePrompt() if prompt then prompt:Hide(); prompt.up = false end end
local function Ask()
    if not pending then waitAsk = false; return end
    if InFight() then waitAsk = true; HidePrompt(); return end   -- (never in combat: it waits for the end of combat)
    waitAsk = false
    prompt = prompt or BuildPrompt()
    prompt:Show(); prompt.up = true
end

-------------------------------------------------------------------------------
-- Runs: start, keep, close
-------------------------------------------------------------------------------
local function NewRun(kind, diff, size, key)
    return { kind = kind, diff = diff, size = size, key = key and 1 or 0, keyDone = 0, kills = 0, wipes = 0, len = 0, pulls = 0,
        ua = 0, uaHid = 0, hidA = 0, hidC = 0, flips = 0, ev = {}, evDrop = 0, pull = {}, pullDrop = 0, shape = {}, probe = {},
        at = {}, disp = {}, err = {}, ver = Versions() }
end
-- the session's counters start from a run's saved totals
local function Bind(r, now, keepRaw)   -- keepRaw: the captured loading-screen events stay in the raw buffer (a re-entry, repair 2)
    BindApi()
    run = r
    -- the run's clock goes on from its saved length (half a tenth past it, so the next line never reads earlier than the last one)
    local t10 = tonumber(r.t10)
    t0 = now - (t10 and ((t10 + 0.5) / 10) or (tonumber(r.len) or 0))
    uaN, uaHidN, uaBase, uaHidBase = 0, 0, tonumber(r.ua) or 0, tonumber(r.uaHid) or 0
    hidAAcc, hidCAcc, hidABase, hidCBase = 0, 0, tonumber(r.hidA) or 0, tonumber(r.hidC) or 0
    hidA, hidC = AurasHidden() == true, CooldownsHidden() == true
    hidASince, hidCSince = now, now
    inEnc, pull, secN, peak, secEnd = false, nil, 0, 0, now + 1
    shapeLeft, jobT, jobs, trT = SHAPE_SAMPLES, nil, true, nil
    ProbeReset()
    fighting, endT, fightSettle, armWanted, settleDue = InFight(), nil, false, false, nil
    if not keepRaw then rawN, rawDrop = 0, 0 end
    for k in pairs(shapeN) do shapeN[k] = nil end
    for k in pairs(probeN) do probeN[k] = nil end
    errBase = ErrSums()
    for code, n in pairs(r.err or {}) do errBase[code] = (errBase[code] or 0) - n end   -- (a resumed run keeps counting from its total)
    errSeen = 0
    for _, n in pairs(r.err or {}) do errSeen = errSeen + n end
end
local function AddRun(r)
    local runs = db.runs
    runs[#runs + 1] = r
    while #runs > MAX_RUNS do
        local drop
        for i, x in ipairs(runs) do if not x.open and (x.keyDone or 0) == 0 and (x.kills or 0) == 0 then drop = i; break end end
        if not drop then for i, x in ipairs(runs) do if not x.open then drop = i; break end end end
        table.remove(runs, drop or 1)
    end
end
-- (SD-124) the one chat line, out of combat only
local function Tell()
    if not db or db.told or not db.done then return end
    if InFight() then return end   -- (said at the next settled reading out of combat)
    db.told = true
    local path = ns.SavedFilePath and ns.SavedFilePath(SAVE_FILE) or SAVE_FILE
    local line = ("The XayaUI test logging is done: %d Mythic+ keys and %d raid bosses logged, so it will not ask again. Type /reload or log out (the game writes the file only then), then send Xaya this file: %s (<YOUR ACCOUNT FOLDER> is your account's folder inside WTF\\Account)."):format(
        db.keys, db.bosses, path)
    if ns.ChatLine then ns.ChatLine(line) end   -- (core's chat-line helper, DebugRecord.lua: in chat whatever "XayaUI's messages" says)
end
-- done marks only; the line comes at the next settled reading out of combat (a fight frame makes no text)
local function CheckDone()
    if not db or db.done then return end
    if db.keys >= TARGET_KEYS and db.bosses >= TARGET_BOSSES then db.done = true end
end
local function Live() return run ~= nil and not pending end
-- close a run: its numbers final, its instance ID dropped (only counts stay)
local function Close(r)
    if r == run then
        if pull and pull.done and not pull.saved then PullSave(not InFight()) end
        Flush()
        run, pull = nil, nil
        Recording(false)
    end
    r.open, r.inst, r.seen, r.away = nil, nil, nil, nil
    if r == awayRun then awayRun, awayAt = nil, nil end
end
-- A loading screen out of the live run into a place that is not a dungeon or raid: the run's numbers brought up to date (seen: the time
-- she left) and kept open, marked away, every event but the loading-screen ones let go (nothing is recorded in the open world).
local function Leave(r)
    Raw(C_.LV)
    if pull and pull.done and not pull.saved then PullSave(not InFight()) end
    Flush()
    r.leaves = (r.leaves or 0) + 1
    r.away = 1
    awayRun, awayAt = r, Now()
    run, pull, inEnc = nil, nil, false
    Recording(false)
end
-- the GetTime() she left an away run at: from memory in this session, else from the saved wall-clock time (a /reload or a login since)
local function LeftAt(r, now)
    if r == awayRun and awayAt then return awayAt end
    local age = Wall() - (tonumber(r.seen) or 0)
    return now - ((age > 0) and age or 0)
end
-- the capture of a loading screen's events while away, dropped (it did not end in a resume)
local function DiscardCapture()
    capT = nil
    if run then return end
    for i = 1, rawN do rA[i], rB[i] = nil, nil end
    rawN, rawDrop = 0, 0
    SetEvent("ADDON_RESTRICTION_STATE_CHANGED", false)
end
-- An open run picked up again at a loading screen inside its instance (a /reload, a login, or a re-entry after Leave). cap: GetTime() at
-- the start of the re-entry's captured loading screen: its events stay in front, and the run's clock goes on from there.
local function Resume(r, inst, now, isLogin, isReload, cap)
    if r.away == 1 then
        r.awayS = (r.awayS or 0) + floor((cap or now) - LeftAt(r, now))
        r.away = nil
    end
    if r == awayRun then awayRun, awayAt = nil, nil end
    capT = nil
    r.inst = inst
    Bind(r, cap or now, cap ~= nil)
    pending = false
    Recording(true)
    if isReload then r.reloads = (r.reloads or 0) + 1 else r.reentries = (r.reentries or 0) + 1 end
    Raw(C_.PE, isLogin, isReload)
    At("loading-screen-in-run", (StateText(Pack(ALLX))))
    Transition()
end
local function DropPending()
    run, pending, pendInst, pull = nil, false, nil, nil
    rawN, rawDrop = 0, 0
    ProbeReset()
    fightSettle, armWanted, settleDue = false, false, nil
    for k in pairs(probeN) do probeN[k] = nil end
    for k in pairs(shapeN) do shapeN[k] = nil end
    waitAsk = false
    HidePrompt()
    Recording(false)
end
function Answer(yes)
    if not pending or not run then HidePrompt(); return end
    HidePrompt()
    waitAsk = false
    if yes then
        pending = false
        OpenDB()
        run.open, run.inst, run.seen = true, pendInst, Wall()
        AddRun(run)
        Raw(C_.Y)
        -- what happened while she had not answered counts too
        if run.keyDone == 1 then db.keys = db.keys + 1 end
        if run.kind == "raid" then db.bosses = db.bosses + run.kills end
        Flush()
        CheckDone()
        Tell()
    else
        declinedInst, declinedAt = pendInst, Now()
        DropPending()
        svc.Sync()
    end
end

-------------------------------------------------------------------------------
-- Handlers (each runs in a fight frame at most a few times per pull: numbers only)
-------------------------------------------------------------------------------
local H = {}
function H.ADDON_RESTRICTION_STATE_CHANGED(t, state)
    -- (the event's own type's IsAddOnRestrictionActive is read; a type that is not a plain number reads all five)
    -- (the payload is documented plain: api.json lists no SecretPayloads flag for this event; a type nil reads all five)
    local xt = t or ALLX
    if not run then if capT then Raw(C_.RS, t, state, xt) end; return end   -- (away: the re-entry's loading screen, captured)
    local now = Raw(C_.RS, t, state, xt); Transition(now)
end
function H.PLAYER_REGEN_DISABLED()
    fighting = true   -- (first: this event's line takes A, C and S as last read, which combat start does not change before its restriction event)
    local now = Raw(C_.RD)
    if prompt and prompt.up then waitAsk = true; HidePrompt() end   -- (combat started before she answered: it waits)
    PullStart(now)
    Transition(now)
end
local AfterCombatSafe   -- (the one file-level function the 0-second timer calls; defined below)
function H.PLAYER_REGEN_ENABLED()
    if run then
        local now = Raw(C_.RE)
        PullEnd(now)
        fighting, endT = false, now
        Transition(now)
    end
    -- (combat is over: the lockdown ends before this event, spec section 2.2) the question that waited, or the arrival that waited, in
    -- the next frame: this frame is combat end, capped at 600 (V33)
    if (arriveWait or (waitAsk and pending)) and not afterArmed then
        afterArmed = true
        if C_Timer and C_Timer.After then C_Timer.After(0, AfterCombatSafe) else AfterCombatSafe() end
    end
end
function H.ENCOUNTER_START()
    inEnc = true
    local now = Raw(C_.ES)
    if pull and not pull.done then pull.boss = 1 end
    Transition(now)
end
function H.ENCOUNTER_END(_, _, _, _, success)
    local now = Raw(C_.EE, success)
    inEnc = false
    if success == 1 then
        run.kills = run.kills + 1
        if Live() and run.kind == "raid" then db.bosses = db.bosses + 1; CheckDone() end
    else
        run.wipes = run.wipes + 1
    end
    Transition(now)
end
-- a new key in a run that already started one (an abandoned key followed by a new one in the same dungeon): the old run closed, a new one
-- opened and kept (see the header, repair 2). Rare and out of combat (INFERENCE: a key cannot start in lockdown): the close's text work
-- runs here.
local function SplitKey()
    local old = run
    local inst = old.inst
    Close(old)
    Bind(NewRun(old.kind, old.diff, old.size, true), Now())
    run.open, run.inst, run.seen, run.split = true, inst, Wall(), 1
    AddRun(run)
    Recording(true)
    Raw(C_.NK)
end
function H.CHALLENGE_MODE_START()
    if Live() and run.key == 1 and ((run.cs or 0) > 0 or run.keyDone == 1 or (run.cr or 0) > 0) and not Lockdown() then SplitKey() end
    Raw(C_.CS); run.key = 1; run.cs = (run.cs or 0) + 1; Transition()
end
function H.CHALLENGE_MODE_COMPLETED()
    Raw(C_.CC)
    if run.keyDone ~= 1 then
        run.keyDone = 1
        if Live() then db.keys = db.keys + 1; CheckDone() end
    end
    Transition()
end
function H.CHALLENGE_MODE_RESET() Raw(C_.CR); run.cr = (run.cr or 0) + 1; Transition() end
function H.LOADING_SCREEN_ENABLED()
    if run then Raw(C_.LE); return end
    if not awayRun then return end
    -- (away) a loading screen starts: its restriction events are captured until PLAYER_ENTERING_WORLD says whether it is a re-entry
    DiscardCapture()
    BindApi()
    capT = Now()
    Raw(C_.LE)
    SetEvent("ADDON_RESTRICTION_STATE_CHANGED", true)
end
function H.LOADING_SCREEN_DISABLED() Raw(C_.LD) end
function H.PLAYER_LOGOUT() if Live() then Flush() end end
function H.PLAYER_ENTERING_WORLD(isLogin, isReload) svc.Arrive(isLogin, isReload) end

function OnEvent(_, event, a, b, c, d, e)
    if event == "UNIT_AURA" then   -- (the busy one: counters, and at most one job per frame while one waits: UaJob)
        if not run then return end
        local n = uaN + 1
        uaN = n
        -- (round 11b final fix) the most in one second is counted four at a time: the clock is read at every fourth event, not at each
        -- (a fight frame hears several, V33), so the pull line's "peak" is a multiple of four, at most three below the true count
        if n % 4 == 0 then
            local now = GetTime()
            if now >= secEnd then
                if secN > peak then peak = secN end
                secN, secEnd = 0, now + 1
            end
            secN = secN + 4
        end
        -- (no job in the change's own frame or the next few events: jobAfter, set at each change; then one per frame)
        if jobs and (n > jobAfter or armWanted) then   -- (the settled reading's timer after combat is armed by the first event after its frame)
            local now = GetTime()
            if now ~= jobT then
                local ok, err = pcall(UaJob, now, a, b)
                if not ok then svc.Fail(err) end
            end
        end
        return
    end
    local h = H[event]
    if not h or stopped then return end
    if not run and event ~= "PLAYER_ENTERING_WORLD" and event ~= "LOADING_SCREEN_ENABLED" and not (arriveWait and event == "PLAYER_REGEN_ENABLED")
        and not (capT and event == "ADDON_RESTRICTION_STATE_CHANGED") then return end
    local ok, err = pcall(h, a, b, c, d, e)
    if not ok then svc.Fail(err) end
end

-- the settled reading, SETTLE_S after the last state change. In a fight (from UNIT_AURA: FightSettle): one raw line, and the probe's
-- start once per pull. Out of combat (the timer: Settle): the text work (Drain), the moments section 8 asks about, the pull's line with
-- the meters, the saved totals, the question if it waits, and the "done" line.
local function FightSettle(now)
    if not run or stopped then return end
    Raw(C_.ST, nil, nil, XONLY)
    if acNew then Recompute(now); acNew = false end
    if pull and not pull.done and not pull.probed and hidC and probeK == 0 then
        pull.probed = true
        probeK, probeDue = 1, now + 0.2   -- (its own frame, not this one: the first UNIT_AURA due runs step 1)
    end
end
function Settle()
    if not run or stopped then return end
    if fighting or Lockdown() then FightSettle(Now()); return end
    local now = Raw(C_.ST, nil, nil, ALLX)
    if acNew then Recompute(now); acNew = false end
    Drain()
    local st = StateText(Pack(ALLX))
    if KeyActive() then At("key-between-pulls", st) end                         -- (spec section 8 step 2)
    if run.kind == "raid" and not inEnc then At("raid-between-bosses", st) end   -- (step 3)
    if pull and pull.done and not pull.saved then PullSave(true) end
    Flush()
    if waitAsk and pending and not InFight() then Ask() end
    if db and db.done and not db.told then Tell() end
end
SettleSafe = function()
    -- (a reading a later change moved, or one a fight reads from UNIT_AURA, or one already read: nothing; no timer is armed from here)
    if fightSettle or settleDue == nil or Now() < settleDue - 0.05 then return end
    settleDue = nil
    local ok, err = pcall(Settle)
    if not ok then svc.Fail(err) end
end
-- one job of the UNIT_AURA handler, at most one per frame (after the counters): the fight's settled reading when due, else the settled
-- reading's timer after combat end (armWanted: the combat-end frame armed none), else a probe step when due, else one payload sample
function UaJob(now, unit, info)
    if armWanted then
        -- (out of combat: the settled reading's timer, one frame after combat end at the earliest; first, so a single aura event after
        -- the fight is enough)
        jobT, armWanted = now, false
        ArmSettle(now)
    elseif pull and pull.fill then
        jobT = now
        PullFill(pull)
    elseif stale or stS == nil or not acOK then
        -- (after a restriction event: the hidden state read again in a frame of its own; only that event's type can have changed since,
        -- so only its state is read again with A and C, unless two types changed or nothing was read yet)
        local t = stale
        jobT, stale = now, false
        ReadAC()
        local d = (t and t ~= ALLX and stS) and S_DIV[t]
        if d and fRS then stS = stS + d * ((fRS(t) or 3) - floor(stS / d) % 4) else stS = ReadS() end
        Base()
        Recompute(now); acNew = false   -- (auras or cooldowns that hid or came back right after that event: their seconds counted from here)
    elseif fightSettle and now >= settleDue then
        jobT, fightSettle, settleDue = now, false, nil
        FightSettle(now)
    elseif probeDue and now >= probeDue then
        jobT = now
        ProbeStep(now)
    elseif shapeLeft > 0 then
        jobT, shapeLeft = now, shapeLeft - 1
        local k = ShapeCode(unit, info)
        shapeN[k] = (shapeN[k] or 0) + 1
    elseif not (fightSettle or probeDue) then
        jobs = false   -- (nothing waits: the counters only, until the next change)
    end
end
-- the first frame after PLAYER_REGEN_ENABLED: the arrival that waited, else the question that waited. A pull chained before this frame
-- (lockdown again) keeps both waiting for the next end of combat (PLAYER_REGEN_ENABLED stays held: in the run's events, or for the wait).
local function AfterCombat()
    if stopped then return end
    if Lockdown() then
        if arriveWait then SetEvent("PLAYER_REGEN_ENABLED", true) end
        return
    end
    if arriveWait then
        arriveWait = false
        svc.Arrive(arriveLogin, arriveReload)
        if not run then SetEvent("PLAYER_REGEN_ENABLED", false) end   -- (held only for that wait)
    elseif waitAsk and pending then
        Ask()
    end
end
AfterCombatSafe = function()
    afterArmed = false
    local ok, err = pcall(AfterCombat)
    if not ok then svc.Fail(err) end
end

-------------------------------------------------------------------------------
-- The "runlog" service core calls (XayaUI/DebugRecord.lua)
-------------------------------------------------------------------------------
-- Brings the events in line with the box and the saved state. Box off: the run in progress is closed and kept (she said Yes to it), an
-- unanswered question is dropped, and every event is let go.
function svc.Sync()
    if stopped then return end
    local on = ns.RunLoggerOn and ns.RunLoggerOn()
    if not on then
        if run then if pending then DropPending() else Close(run) end end
        if db then for _, r in ipairs(db.runs) do if r.open then Close(r) end end end   -- (a run left open or away: closed too)
        DiscardCapture()
        HidePrompt(); waitAsk = false; arriveWait = false
        ReleaseAll()
        return
    end
    local d = PeekDB()
    -- the loading-screen event: needed to ask, and to close an open run; not once done with nothing open
    local openSaved = false
    for _, r in ipairs(d and d.runs or NO_RUNS) do if r.open then openSaved = true end end
    SetEvent("PLAYER_ENTERING_WORLD", not (d and d.done and not run and not openSaved))
    -- while away: the start of a loading screen too (the re-entry's restriction events are captured); a live run holds it itself
    if not run then SetEvent("LOADING_SCREEN_ENABLED", awayRun ~= nil) end
end
-- A loading screen ended (core's frame or this one; the same moment handed twice is handled once). In combat lockdown it waits for the
-- end of combat (H.PLAYER_REGEN_ENABLED): a fight frame sets nothing up.
function svc.Arrive(isLogin, isReload)
    if stopped or not (ns.RunLoggerOn and ns.RunLoggerOn()) then return end
    if Lockdown() then
        arriveWait, arriveLogin, arriveReload = true, isLogin, isReload
        if prompt and prompt.up then waitAsk = true; HidePrompt() end
        SetEvent("PLAYER_REGEN_ENABLED", true)
        return
    end
    if arriveWait then   -- (a later loading screen out of combat replaces the one that waited)
        arriveWait = false
        if not run then SetEvent("PLAYER_REGEN_ENABLED", false) end
    end
    local d = PeekDB()
    local now = Now()
    if lastArrive == now then return end
    lastArrive = now
    local inside = InGroupInstance()
    local kind, diff, size, inst = InstanceInfo()
    local cap = capT   -- (away: the start of this loading screen, whose events were captured)
    if Live() then
        if inside and inst ~= nil and inst == run.inst then   -- (a loading screen inside the run: a /reload, step 9)
            if isReload then run.reloads = (run.reloads or 0) + 1 else run.reentries = (run.reentries or 0) + 1 end
            Raw(C_.PE, isLogin, isReload)
            At("loading-screen-in-run", (StateText(Pack(ALLX))))
            Transition()
            return
        end
        -- another dungeon or raid closes it, and so does leaving a finished key (a later key in the same dungeon is a new run); else the
        -- open world keeps it open for a re-entry (a corpse run, stepping out mid-key)
        if inside or run.keyDone == 1 then Close(run) else Leave(run) end
    elseif not run then
        -- an open run: one she left for the open world (away), or one left open in the saved data (a /reload, a logout or a disconnect
        -- inside it or while away). Fresh: within RESUME_S of leaving (away) or of the last saved reading (seen).
        for _, r in ipairs(d and d.runs or NO_RUNS) do
            if r.open then
                local fresh
                if r.away == 1 then fresh = (now - LeftAt(r, now)) < RESUME_S
                else fresh = (Wall() - (tonumber(r.seen) or 0)) < RESUME_S end
                if fresh and inside and inst ~= nil and r.inst == inst then
                    Resume(r, inst, now, isLogin, isReload, cap); svc.Sync(); return
                elseif fresh and not inside and (r.keyDone or 0) ~= 1 then
                    -- still away, or away now (left open inside, found at an open-world loading screen after a login): kept open
                    if r.away ~= 1 then r.away = 1; r.leaves = (r.leaves or 0) + 1 end
                    if r ~= awayRun then awayRun, awayAt = r, LeftAt(r, now) end
                else
                    Close(r)   -- (another instance, too late, or a finished key: closed, its instance ID dropped)
                end
            end
        end
        if capT then DiscardCapture() end
    end
    if pending then
        if inside and inst == pendInst then Raw(C_.PE, isLogin, isReload); Transition(); return end   -- (same visit: still asking)
        DropPending()
    end
    CheckDone()
    Tell()
    if not inside or (db and db.done) then svc.Sync(); return end
    if isReload then svc.Sync(); return end   -- (a /reload never asks: she was already here; an open run was resumed above)
    if declinedInst ~= nil and declinedInst == inst and (now - (declinedAt or 0)) < RESUME_S then declinedAt = now; svc.Sync(); return end
    -- a new run: recorded in memory until she answers
    Bind(NewRun(kind, diff, size, KeyActive()), now)
    pending, pendInst = true, inst
    Recording(true)
    Raw(C_.AR, isLogin, isReload)
    Transition()
    svc.Sync()
    Ask()
end
function svc.Fail(err)
    if stopped then return end
    stopped = true
    run, pending, pull, rawN = nil, false, nil, 0
    ProbeReset()
    fightSettle, armWanted, settleDue = false, false, nil
    awayRun, awayAt, arriveWait, capT = nil, nil, false, nil
    HidePrompt()
    ReleaseAll()
    if ns.PrintError then
        ns.PrintError("XUI-E019", "The run logger (XayaUI Debug) stopped after an error and logs nothing more until you type /reload. Nothing else is affected.",
            "run logger: " .. tostring(err))
    end
end
-- (tests) what the logger holds now
function svc.State()
    local e = {}
    for k in pairs(evOn) do e[k] = true end
    return { events = e, pending = pending, waitAsk = waitAsk, live = Live(), stopped = stopped, prompt = prompt,
        promptShown = prompt and prompt:IsShown() or false, frame = evFrame, away = awayRun ~= nil, arriveWait = arriveWait }
end
svc.PROMPT_TEXT = PROMPT_TEXT
svc.TARGET_KEYS, svc.TARGET_BOSSES, svc.SAVE_FILE, svc.DB_NAME = TARGET_KEYS, TARGET_BOSSES, SAVE_FILE, DB_NAME
svc.MAX_RUNS, svc.MAX_EV, svc.MAX_PULLS, svc.MAX_KEYS, svc.RAW_MAX = MAX_RUNS, MAX_EV, MAX_PULLS, MAX_KEYS, RAW_MAX
if ns.Provide then ns.Provide("runlog", svc) end
