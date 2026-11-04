# Advanced Debugging: a switch per kind of line, CPU-friendly hooks, readable record, "What to send" (XayaUI core 0.6.22, XayaUI_Options 0.6.17, XayaUI_GameDump 0.6.2; fork: main)
Logged 2026-11-04 14:43 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Request (Xaya, 2026-11-04)
"configure advanced debugging to be user-readable and cpu friendly (perhaps discrete functionality toggles that are posing issues)
and a notation with a copy/paste file path so users know what to upload and send to me to pass to you", and "be sure to make
advanced debugging be configurable to cover every single thing you need to properly debug something from game-side".

## What changed
- **Categories** (`XayaUI/DebugRecord.lua`, `DR.CATS`). Eleven switches, each with a default and a cost in words:
  - rules, snapshots, aura answers, trigger detail, displays, glows, sounds, game state, engine status, performance, messages;
  - always kept: errors, combat marks, and actions the game blocked for XayaUI (ADDON_ACTION_BLOCKED / FORBIDDEN whose
    `isTainted` names an XayaUI addon).
  - Presets: Light set / Everything / Defaults.
  - Size: 1000 / 3000 / 10000 lines.
  - Settings store only what differs from the default (`CueRulesDB.ui.recCats`).
- **New coverage** ("every single thing ... from game-side"):
  - **trigger detail** for chosen rules (and their cues and conditions), once per change, with `ns.WhyNot`;
  - **displays** shown and hidden, and who draws them (XayaUI or the combat engine);
  - **sounds**: what was played and the game's raw first return value;
  - **game state**:
    - login and /reload: every XayaUI addon's version, load state and load error; game build, client, locale, screen size, UI scale,
      rule counts, spec;
    - spec, talents, gear by slot;
    - zone: instance name, type, difficulty, instance ID, uiMap ID;
    - ENCOUNTER_START / END: ID, difficulty, size, kill or wipe;
    - CHALLENGE_MODE_START / COMPLETED: map, keystone level;
    - group size changes;
    - what the game hides (`C_Secrets.ShouldAurasBeSecret` / `ShouldCooldownsBeSecret`) at each combat start;
  - **performance**: the engine's own `/xui perf` timer, for the combat only, read at its end. A timer the player started is read,
    never stopped.
- **Readable.** Each line is `HH:MM:SS  Label  text`. Combats are numbered, with where and how long. **View the debug record** shows
  a legend of what each label means and which categories are off, then the lines, then "what to send".
- **What to send.**
  - `ns.SendText` / `ns.SavedFilePath` give the steps and the path with `<YOUR ACCOUNT FOLDER>` as a placeholder. The game folder is
    `_retail_`, `_ptr_` (from `IsPublicTestClient`) or `_beta_` (from `IsBetaBuild`).
  - Shown in Settings as copyable boxes (also with Advanced Debugging off), behind the console window's new **What to send** button,
    and at the end of every bug report.
  - The developer addon's file is listed only when its "gameDataProbe" service says its file name (`savedFile`, new). Core never
    names that addon.
- **CPU.**
  - The aura hook (`RecordAura`, on every aura read) now compares the raw answer and source first. An unchanged answer does no string
    work. Measured in `tests/debug_record_engine_run.py`: 20 steps with unchanged auras cost 0 pattern matches; without the fast path,
    40.
  - Trigger detail is behind one upvalue (`triggerWatch`), true only while the category is on and a rule is chosen.
  - Display lines are built only on a change; sound lines only when a sound plays.
  - A category that is off builds no text.
- **Engine and console.** `ns.LogKind(kind, ...)`: the engine's fired / repeat / cleared lines are "rule", snapshots are "snapshot".
  The console is unchanged. `ns.PlaySound` returns what it tried and the game's raw answer. The console window's minimum width is now
  390 px, because its top row holds four buttons.

## Found and fixed while building
- **Switching a default-on category off did nothing.** `type(c) == "table" and c[key] or nil` turns a stored false into nil (= the
  default). The new tests caught it; both readers now use an explicit if. Same family as the 0.6.20 setters (`and false or nil`).
  `tests/lua_pitfalls_run.py` only knows the literal forms; a sweep of `and X[k] or nil` across all addons found one more, below. The
  other hits hold tables, numbers or strings, which cannot be false.
- **The Display tab's multi-display proxy** (`XayaUI_Options/DisplayTab.lua` Proxy, Differs) had the same trap.
  - No visible effect today: its toggles read `t[k] and true or false`, so nil and false look the same.
  - Fixed anyway, because a future `~= false` reader would show a switched-off setting as on.
- **Two of my own test mistakes**, fixed in the test: an `#SINK == 1` that ignored console lines; a missing `ns.NewUID` in the bench.

## Not confirmed (inference, for QA)
- That the account folder is "often a number such as 12345678#1": general knowledge of Battle.net account folders, not checked in
  this session. QA B57 asks the tester to note the real format.
- What `PlaySound` / `PlaySoundFile` return: they are not in the 12.1.5 API documentation (`docs/reference/api`). The record shows
  the raw value and does not interpret it.

## Scope (V4)
- **Every feeder of the record:**
  - Core.lua: ns.Print, ns.Log / LogKind, the error handler;
  - Engine.lua: rule lines, PlaySoundSafe, StepEnabled display and trigger;
  - Conditions.lua: RecordAura, ObserveGlowPairing, LogStatusSnapshot;
  - AuraSound.lua: Sync;
  - DebugRecord.lua: its own event handlers.
- **Every `ns.Log` caller** (7): Engine.lua (3), Conditions.lua (3), Options.lua (1, new-rule line, kept as "rule").
- **Every reader of the record:** Console.lua bug report, Options record info / view, and `ns.RecordText`.

## Checks
- **`tests/debug_record_run.py`:** now 92 checks; categories, size, game state, perf, blocked actions, trigger, display and sound
  lines, what to send, and the real Settings controls for all of it.
- **`tests/debug_record_engine_run.py`** (new, 17 checks): the real engine Step over all core files (rule, sound, snapshot,
  trigger-detail and display lines; the CPU checks).
- **Negative controls:**
  - both files fail on the code before this change (APIs missing);
  - with only the aura fast path removed, the CPU check fails (40 matches);
  - with the category readers as first written, 5 checks failed (the bug above).
- `tests/lua_pitfalls_run.py`: 0.

## Decision graph (process and analysis)
```
Request: readable + CPU friendly + toggles + path + full coverage
├─ Where does CPU go? read every feeder
│   ├─ ns.Log / snapshots: always on, cheap (changes only) ......... keep, but give them a category in the record
│   └─ RecordAura: string work on every aura read when recording ... fast path on raw equality (measured 40 -> 0)
├─ Toggles: one per kind of line, or one per feature? ............. per kind of line: a reader asks "what was recorded", not "which file"
│   ├─ cache the switches in an upvalue table? ..................... no: a settings read is cheap and never goes stale; only
│   │                                                                 trigger detail (every rule, every step) gets an upvalue
│   └─ errors / combat / blocked switchable? ....................... no: always kept, they frame everything else
├─ "Every single thing": what did past debugging need?
│   ├─ which rule, which trigger part, which source ................ trigger detail for chosen rules (all rules = too costly)
│   ├─ where the player was / what the game hid .................... game state + C_Secrets at combat start
│   ├─ did the sound play / the display show ....................... sound and display lines
│   └─ was it slow ................................................. the existing /xui perf timer, combat only
├─ Path: can the addon read the account folder? .................. no API: placeholder + how to find it (not a guess)
│   └─ game folder: IsPublicTestClient / IsBetaBuild (documented) .. _ptr_ / _beta_, else _retail_
└─ Developer addon's file: name it in core? ...................... no (boundary rule): the addon says it through its service
```
Options weighed and not taken:
- a separate "debug profile" window: more UI, and the Settings page already holds the switches;
- recording every trigger of every rule: costs on every rule every step, and makes a record too long to read;
- an automatic upload: no addon can send files, and the files are the player's to share.

Files: XayaUI/DebugRecord.lua, Core.lua, Engine.lua, Conditions.lua, Sound.lua, Console.lua, XayaUI.toc (0.6.22);
XayaUI_Options/Options.lua, DisplayTab.lua, XayaUI_Options.toc (0.6.17); XayaUI_GameDump/Probe.lua, XayaUI_GameDump.toc (0.6.2);
tests/debug_record_run.py, tests/debug_record_engine_run.py (new); USER-GUIDE.md 12.14; QA-CHECKLIST.md B54-B57; this entry; MANIFEST.md5.
