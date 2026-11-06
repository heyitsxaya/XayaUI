# /xui debug <name> only; messages set to chat also show in the open console window (core 0.6.50, Options 0.6.48)
Logged 2026-11-06 00:44 UTC. Session 014bN6tVFhD1GEbb6ieFgKLz, branch `claude/great-franklin-j4cahh` (on 8ae717b). Not on `main` (V16, V17).
CORRECTED 2026-11-06 00:48 UTC (debug-log/2026-11-06-0048-console-save-only-console-messages-core-0.6.50.md): the mapping below was
wrong. Her next message answered questions 4, 5, 7, 8, 9 of the list of nine, so this message answered questions 1-3 of that list.
Part 2 (chat-routed messages copied into the open console) was never asked for; her answer to that question is "Only xui console
messages should display", and it was taken out. Part 1 (old forms retired) stands: her "7. Retire".

## Xaya's answers (2026-11-06, her words; request log row 4)
"1) let’s move to /xui debug ____ — routinely used things can maybe get shortcut commands
2) yes as long as it doesn’t negatively impact performance
3) example context for either case!"
Read as answers to the three decisions in the first report of 2026-11-05/06 (old forms vs /xui debug only; chat-routed messages in the
open console; /xui auras in help or debug), whose content they match; the later list of nine was numbered differently. INFERENCE,
stated to her for correction.

## Built
1. Old forms taken out (her 1). `XayaUI/Core.lua`: the dispatcher no longer runs `coreDebug[cmd]` at the top level; an old word prints
   /xui help (which names /xui debug). `XayaUI/Modules.lua`: `ns.RegisterDebugCommand` no longer registers the top-level name;
   `ns.MODULES` keeps feature debug names apart (`debug = { "chatprobe" }`, `{ "widthprobe" }`), and `ns.ModuleOfCommand(cmd, isDebug)` /
   `ns.ModuleMissingText(cmd, isDebug)` word them "/xui debug <name>" (without this, /xui chatprobe with Chat loaded would have said
   "never registered"). `XayaUI_QoL/CharacterToolkit.lua`: /xui stats widthprobe removed (an unknown /xui stats word toggles the panel,
   as before). Every message that told the player to type an old form now says /xui debug <name>: AuraList, AuraIDProbe, AuraModel,
   AuraSetup, AuraTracker, Conditions, Engine, TalentDump, Triggers, Visual, Outcomes, Timing, DebugRecord, Console, Cues, Modules (the
   game's AddOns options panel text), Options.lua and Skin.lua, Chat Probe.lua, QoL CharacterReskin / CharacterWidthProbe, Reskin
   GameMenuSkin (same regular expression over each file, then read through). USER-GUIDE and QA-CHECKLIST updated likewise.
   Historical records (debug-log, RETROSPECTIVE, plans, ROADMAP rows about past work) keep the forms of their time.
   "Shortcut commands": not built (V16). Proposal to Xaya: /xui status and /xui auras as shortcuts. Evidence (mentions in the repo's
   docs, a proxy for routine use, not measured play): status 31 (18 QA steps), perf 27 (20 in debug-log requests), gamemenu 24, auras 17,
   timing 13, chatprobe 13, widthprobe 12, loc 7; the rest 4 or fewer.
2. Chat-routed messages in the open console (her 2). `Core.lua ns.Print` and the error handler: when the destination is "chat" and the
   console window is open (`ns.ConsoleWindowOn`), it becomes "both" for that message. Cost (her condition): per message, one function
   call and one IsShown once the window exists; no frame, event, timer or per-frame work (V14); while the window is closed nothing of
   the console is called (tested). Messages are not buffered while it is closed (only while it is open, as asked). The console's empty
   hint and the "XayaUI's messages" tooltip (Options 0.6.48) say so. QA B152.
3. /xui auras (her 3): examples of both cases sent to her; no change.

## Scope (V4)
`git grep -E "/xui (status|probe|debuffs|perf|timing|seed|talents|model|tracker|loc|media|mods|groups|icons|gamemenu|auras|chatprobe)\b|/xui stats widthprobe"`
over the addon folders, USER-GUIDE, QA-CHECKLIST, XayaUI/Combat/README.md and tests: 25 code files, 3 docs, 13 tests changed
(counts in the commit). Callers of the removed top-level handlers: `tests/harness/scenario.lua` (command list now uses "debug <name>",
plus "status", "debug nosuch" and "debug widthprobe off"), `tests/auras_cmd_run.py` (now `ns.RunDebugCommand`). `ns.MessageDest`
readers are as listed in the 0005 entry; only `ns.Print` and the error handler mirror.

## Verification
- `tests/console_commands_run.py`: 72 checks, 0 failed. New: the old forms status, auras target, perf, loc, gamemenu, chatprobe,
  probe, mods, seed print /xui help and run nothing (seed adds no rule); /xui stats widthprobe does not start the probe; /xui debug
  chatprobe with Chat off says "/xui debug chatprobe is part of XayaUI Chat, which is switched off"; /xui chatprobe is not "never
  registered"; chat setting with the window open: message in chat, in the window and in the buffer, the line keeps no focus; a private
  message drawn, not buffered; a XayaUI error notice ("[XayaUI error] ...") in the window; window closed: `ns.ConsoleMessage` not called,
  nothing buffered, nothing drawn on reopening. Negative control: on 8ae717b 17 of the 72 fail (sections 3 and 6).
- Also passing: xui_help_lines, auras_cmd, char_width_probe, charges_combat, chatprobe, debug_record, engine_text, gamemenu, load_ids,
  options_bonus_off_costs_nothing, sidebar_switches, timing, modules, char_toolkit; `lua_pitfalls_run` FAILS: 0. Full suite: see the reply.
- Not run in game. QA B151 (rewritten for the old forms), B152 (new).
