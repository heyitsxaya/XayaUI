# Debug tools to XayaUI Dev Assist; error codes and the debug report (core 0.6.56, Options 0.6.55, Chat 0.6.20, QoL 0.7.33, Bonus 0.6.18, Reskin 0.6.5, Dev Assist 0.7.5)

Logged 2026-11-06 18:07 UTC. Session S1 (branch `s1-debug`, from `claude/adoring-hawking-wyda59` a073b40). REQUEST-LOG #81 and #82.
Plan: `docs/plans/DEBUG-TO-DEVASSIST-2026-11-06.md` (rows A1-A20, B1-B7, C1-C4). Her answers (FUS-4, question box): "via" text
"Tooltip, Dev Assist on"; developer diagnostics "Move all of them"; Combat Tracking Setup "Rule Creation"; /xuiskin "move pad and alpha
to dev"; edge cases "Yes, as recommended"; debug record default "On, errors only", kinds "Errors + warnings only", report "Both: string
and screenshot view". Her words for #82: "only there to catch errors and bugs that might be expected within a live, user-facing version
of the addon. these should have error codes built out, auto detection, and auto documenting with a simple debug report that someone can
directly send to me -- either via import/export string or screenshot".

## Scope (V4; `git grep` of every reader and caller)
- Commands: `RegisterDebugCommand` (AuraList.lua auras, GameMenu.lua gamemenu, Chat Probe.lua chatprobe, QoL CharacterToolkit.lua
  widthprobe, Reskin GameMenuSkin.lua gamemenu), Core.lua `CORE_DEBUG`, Modules.lua `ns.MODULES` debug lists, `/xuitt`
  (TooltipsUI.lua), `/xui chat` (Chat Core.lua `C.Command`), `/xuiskin` (Modules.lua), `/xuiengine` (Combat/AuraDisplay.lua).
- Implementations moved (each caller found by `git grep`): ns.Probe, ns.IDProbe (whole file Combat/AuraIDProbe.lua), ns.ProbeDebuffs and
  ns.TargetAuraByName (only the probe used it), ns.ProbeLossOfControl, Timing.Report, ns.ModelCommand, ns.TrackerCommand, ns.ProbeMods,
  ns.ProbeGroups, ns.IconReport (wrapper; Options.IconReport stays in the load-on-demand settings addon), ns.UserMediaReport,
  ns.MapReport / MapReportLines, ns.GameMenu_Diagnostics, ns.GameMenuSkin_Diagnostics, ns.SeedRules, ns.ChatProbe (whole file),
  ns.CharWidthProbe_Run (whole file), TT.AuraReport / DumpLines / Probe, C.IndentReport / WhisperReport / WhisperFacts and the whisper
  counter part. Text that pointed players at a moved command was changed (AuraSetup.lua, Triggers.lua, Conditions.lua, Theme.lua,
  Options.lua, ThemeEditor.lua, GameMenuSkin.lua, the Blizzard Settings panel line in Modules.lua).
- Debug record readers: `RecordLine`, `RecordOn`, `RecCatOn`, `RecTrigger`, `RecDisplay`, `RecSound`, `LogKind` (Engine.lua, Conditions.lua
  glow / aura lines, AuraSound.lua, Core.lua Print / Log), `CaptureError` (Engine.lua, Visual.lua x2, GameMenu.lua, Options.lua,
  GameMenuSkin.lua), `ErrorCount` / `ClearErrorLog` (Options.lua), `RecordSummary` (Console.lua bug report), Settings > Debugging rows.
- Settings: Options.lua Debugging page (advancedDebug, msgDest, recordOn, recWhat, debugProbe, recordInfo, recordView, recordClear, send,
  bug, auraSetup, gameDump) and Rule Creation page.

## What changed
- XayaUI Dev Assist: `CoreDebug.lua` (the moved commands, as they were; registered into core's lists), `DevRecord.lua` (the 11 detailed
  kinds, their switches, the probe switch A20, `/xuidev report` reader), moved whole files `AuraIDProbe.lua`, `ChatProbe.lua`,
  `CharacterWidthProbe.lua`. OptionalDeps now name the feature addons so they load first. `DevAssist.lua` sets `ns.devAssistLoaded`.
- Core: `ns.RegisterSubcommand` / `ns.RunSubcommand` / `ns.SubcommandList` / `ns.SubcommandHelp` (Modules.lua), `ns.DevAssistOn`.
  Read-only accessors for moved reports: `ns.VisualProbeState`, `ns.GameMenu_DiagState`, `ns.MapTraceOrder`, AuraTracker `T.states` /
  `T.DB`, AuraDisplay `D.DB` / `D.FindFolder`. Players keep `/xui debug status, perf, talents, loader, auras`; `perf ui` is handed to
  Dev Assist. `/xui report` added to `/xui help` (18 lines).
- `DebugRecord.lua` rewritten for players: `ns.ERROR_CODES` (19 codes, one-line meaning each), `ns.RecordError` / `ns.RecordWarn` /
  `ns.CaptureError` (kept as an alias), `ns.ErrorEntries`, newest 50 in `CueRulesDB.errorLog` (the list the bug report already read;
  old entries get the code of the folder their text names), blocked-action events only while Advanced Debugging is on, the report
  (`ns.DebugReportData / Text / String / Read`, `ns.ShowDebugReport`), string codec `Share.Pack / Unpack` (same codec as share strings,
  no kind registered, so the Import window refuses it).
- Core.lua error handler: decides by the file the message names (else the first addon file in the stack); only XayaUI* folders are
  recorded; the handler set before is always called (unchanged chaining).
- Warnings wired: AuraDisplay container failure (W002), guard lean (W003), guard off (W004), Chat Panel part failure (W005), blocked
  action (W001). Guarded errors: Engine rule (E010), engine step (E011), Visual (E012), Options move (E013), ESC menu (E014).
- Tooltips: `TT.SourcesOn` reads `ns.DevAssistOn`. Options: Combat Tracking Setup on Rule Creation; Debugging page has the Debug report
  group and "Dev Assist settings" (Dev Assist's pages).

## API facts (V2)
- `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` (isTainted: cstring, function: cstring) · SynchronousEvent · RestrictedActions
  (docs/reference/api/events.md:34-35).
- `seterrorhandler`, `geterrorhandler`, `debugstack` are not in docs/reference/api: INFERENCE from their use since core 0.5 and Blizzard's
  own error frame: the handler receives the error message (with "path:line:" when the error has a location). The code fails safe: no
  location and no addon file in the stack means not recorded.
- `UnitAffectingCombat`, `GetBuildInfo`, `C_AddOns.GetAddOnInfo / IsAddOnLoaded / GetAddOnMetadata`, `GetLocale` are read only when an
  error happens or the report opens; every read is pcall'd.

## Cost while nothing goes wrong (measured)
tests/devassist_debug_tools_run.py F: with Advanced Debugging on (default) and no Dev Assist, 30 s of engine steps, two combats, a zone
change, a /reload event and 40 log lines: **0 calls** into the record's code (call hook on DebugRecord.lua; only the message routing that
serves every XayaUI message ran, 6 calls), errorLog empty, no detailed record, the record's frame holds only ADDON_ACTION_BLOCKED and
ADDON_ACTION_FORBIDDEN (raised by the game only when it blocks an action). Control: the same counter sees the record when an error happens.
V14 level: Dev Assist off = its code is never read (strict); core's DebugRecord.lua is still read at login (parse cost only).

## Tests
- New: `tests/devassist_debug_tools_run.py` (147 checks, two sessions: without and with Dev Assist).
- Updated (they asserted the old places): console_commands_run.py (help 18 lines, the player's debug list, chatprobe absent),
  aura_display_run.py (loads Dev Assist's /xuiengine words), aura_gaps_run.py (aura lines need Dev Assist; new check without it),
  char_width_probe_run.py, chatprobe_run.py, chat_run.py (moved paths, Dev Assist loaded for indent / wrap), chat_pieces_run.py (whispers
  report with Dev Assist; new check without), chat_off_costs_nothing_run.py (B4b: no whisper counter without Dev Assist),
  core_off_costs_nothing_run.py and debug_record_engine_run.py and debug_record_run.py (load DevRecord.lua; errors in the coded record),
  devassist_rename_run.py (comments and the code table may name the folder), engine_text_run.py and timing_run.py (Dev Assist's timing
  report), feature_rows_map_run.py (Dev Assist's map report), tooltips_run.py and tooltip_aura_source_run.py (/xuitt from Dev Assist;
  the "via" gate is Dev Assist; new mutation "sources follow Advanced Debugging again"). tests/chat_world.lua: `W.loadDevAssist()`.
- Negative control on a073b40 (scratch worktree, removed): devassist_debug_tools_run.py 63 of 129 checks fail and the without-Dev-Assist
  run stops in section E (no ns.RecordError); console_commands_run.py 5 fail; chat_off_costs_nothing_run.py 1 fails (B4b);
  aura_gaps_run.py the new check fails; chat_pieces_run.py and tooltip_aura_source_run.py stop (no CoreDebug.lua).

## QA
B180-B183, D14, E1z90, F19 (QA-CHECKLIST); a note at the top says older steps that use a developer command need Dev Assist on; B157, F13,
F16 annotated. In-game walkthrough definitions for S3's framework: `XayaUI_DevAssist/QAWalks-debug.lua`, NOT in the toc until that
framework lands. Not tested in game.

## Root documents moved into docs/ (FUS-6, her answer "All but README, THIRD_PARTY")
Done last, after merging `claude/feature-update-summary` at 2c5ccc6 and then e1cae80 (docs only: REQUEST-LOG FUS-1..FUS-9 and the plan; no WHATS-NEW reorganisation there). `git mv` of
WHATS-NEW.md, USER-GUIDE.md, QA-CHECKLIST.md, ROADMAP.md, SESSION-START-SUMMARY.md into `docs/`. Every reference rewritten to the
`docs/` path (`git grep` of each name: SKILL.md, VERIFICATION.md, REQUEST-LOG.md, REQUEST-LOG-CROSS-CHAT.md, two plans, the ElvUI review,
the summary and the roadmap themselves, tools/precheck.py, tests/precheck_run.py). Left as written: debug-log/ (history) and the
verbatim session request logs (her own words). New precheck group "moved documents" fails on any old root path elsewhere and on a
missing docs/ file; the QA-ID check now fails when the checklist is not found (it passed silently on a missing file). tests/precheck_run.py
has six new checks for it (they fail on the old precheck: no check_doc_paths, and check_qa_ids(None) passed).
