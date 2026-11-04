# Handoff: rule / combat engine session (2026-11-04, session 014bN6tV8wAAEXAShpTKqUfz)
Logged 2026-11-04 21:40 UTC. Read with SESSION-START-SUMMARY.md. Branch `claude/fervent-cerf-hldtwn`, PR heyitsxaya/XayaUI#389
(core / Options 0.6.34-0.6.35).

## Who owns what (agreed between the parallel sessions on 2026-11-04)
- **Engine session (this one):** `XayaUI/Combat/`, `XayaUI/Engine.lua`, `XayaUI/Triggers.lua`, the trigger / cooldown / aura reads in
  `XayaUI/Conditions.lua`, spell-trigger options B4-B6, Fel Flame Fortification (G), Boiling Point (H).
- **Options / Stat Calculator session** (`claude/cool-ramanujan-ewx8e5`): load-context part of Conditions.lua (`CheckContextRaw`,
  `IdListChecks`), mover view and frame anchoring, the group page builder (it offered to take the group-page items once Xaya answers).
- **"Outstanding build item selection" session** (PR #386): `XayaUI_DevAssist/`, QoL enchant slots, Bonus tooltips (unclaimed otherwise).
- Landing: whoever lands second merges main in, regenerates MANIFEST.md5 and reruns the full suite on the new head.

## Done here
- Triage of every open rule / combat engine issue: `debug-log/2026-11-04-2132-...-0.6.34.md` (table: fixed in code / waiting on data /
  waiting on Xaya / obsolete). QA B100-B113 written for the fixed but never-checked items.
- Options 0.6.34: group "Pause preview animations" on the Display tab. Core 0.6.34: #121. Core / Options 0.6.35: "Exact spell ID" (B4).
- `docs/plans/GROUP-PAGE-REVIEW-2026-11-04.md`: every open note on the group page, 10 questions (nothing built).
- EllesmereUI unlock mode read for behaviour only (Xaya's request about position snapping); the summary went to the Options session.
- Fiery Brand (handoff from PR #386): rule evaluation never resolves aura IDs through `ns.AuraSources` / `ns.AuraModel`; a trigger watches
  the stored ID. Only the editor's aura search may offer both 207771 and 207744; which is the debuff needs `/xuidev auras` in game.

## Waiting on Xaya (one question each; the session's task list is not kept between chats)
1. B5 "Track: Auto / Charges / Spell cooldown": what each choice does (proposal: Auto = today; Charges = always count charges;
   Spell cooldown = ignore charges, ready while the spell's own cooldown is not running). Or drop it.
2. B6 "track even if not known": wanted at all? (an unknown spell reads "ready" in the game's report)
3. #375 speech cue channel: the game's speech call has no channel (`C_VoiceChat.SpeakText`). Speech keeps the TTS output / sound
   cues only get the #372 group override / both.
4. #115 (D7): is up to 50 ms between a game change and its sound acceptable? If not, it is part of #309 routing.
5. Close obsolete issues #303, #93, #280, #294, #67, #19 (and #365, which she confirmed on 0.6.8)?
6. Positioning (EllesmereUI behaviour implies; the code belongs to the Options session): #268 two-point anchors, #61 snap vs anchor,
   arrow-key nudges, changes held until save; #343 which drag.
7. Group page: the 10 questions in GROUP-PAGE-REVIEW.

## Waiting on in-game data
#307 / #309 (`/xui perf` capture, QA B56), #311 and #301 (`/xuiengine` in combat), #332 (Divine Arbiter ID), #315 (rule export),
#353 (QA B110), #155 (QA B111), B4's open fact (QA B113), G / H (Dev Assist `/xuidev instance` from her dungeon run, IN-GAME-DATA step 7).

## Next for the engine (not blocked)
- #309: per-step garbage on her rules is down from 52.49 to 13.79 KB and time from 0.884 to 0.663 ms (core 0.6.40, 0.6.41, 0.6.44; see
  `debug-log/2026-11-04-2338-engine-garbage-measured-on-her-rules.md`). Event-to-rule routing (large) only after the perf capture, so it
  can be measured before / after; design notes in the triage entry.
- Ownership added later the same evening: the Dev Assist session (PR #386) owns `XayaUI/AuraSources.lua` with the search indexes, and the
  QoL cursor highlight / trail. `Visual.lua` per-frame display work stays with the engine session.

## Container notes
- Harness indexes: build the API doc concatenation with a short Python script (`sorted(glob(...))`, one `-- ===== FILE: <name>` line
  before each file). A bash `for f in $(ls ...)` loop produced a single marker here and the index came out empty (1 file, 1 unparsed).
- Without the indexes the fresh-install harness fails 17x on `C_Texture` (a missing-index artefact); with them main passes ALL CHECKS.
