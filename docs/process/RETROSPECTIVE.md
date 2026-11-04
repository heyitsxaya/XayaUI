# Defect retrospective: why reported bugs were not caught first, and what now catches them

Written 2026-11-04. Xaya asked: "review everything out of all the bugs filed and work backwards from their solves -- why did they not
get caught and solved before being reported, and how do you prevent the same mistakes moving forward?" and to "identify gaps in logic
or lacks of tethering talents and abilities together. identify missed opportunities at capturing aura data."

The checks this produced are in [`VERIFICATION.md`](VERIFICATION.md) (rules V1-V13) and `tools/precheck.py`. Every row below names the
rule that would have caught it.

## How this was made
- **Sources:** GitHub issue snapshots (#51-#365), the debug log, triage notes, commit history (`git log --all`), and the code on `main`.
  The debug log starts at 0.5.54 (2026-11-02), so older fixes are traced through commits.
- **Who did what:** four reviewers (Claude subagents) each took one share (#51-#166; #170-#340; #343-#365 plus this session's two
  defects; a code review for logic gaps, talent / ability links and missed aura data). Claude (the main session) merged their reports
  and re-checked the claims marked "checked" below against the code on `main` at 3e71903 / ce787c5.
- **Limits:** the class and "why missed" codes are reviewers' judgments. Rows marked "not re-checked" rely on one reviewer's reading.
  Nothing here was run in the game.

```
Question                      -> Decision (why)
Split the 350 issues?         -> by number range, 3 reviewers (independent reads, no shared bias)
Code gaps separately?         -> 4th reviewer on the code only (talent links / aura data are not in issue text)
Trust reviewer claims?        -> no: spot-check the surprising ones (#333, #319, gap findings 1-22) before writing them as facts
One table or per-reviewer?    -> one table, one row per defect, plus the rule that now catches it (makes the fix list actionable)
```

## Codes used
**Root-cause class:** A in-combat secrecy · B API edge state · C ID / data shape · D lifecycle (an edit or event did not refresh
something) · E two authorities disagree (engine vs XayaUI, preview vs combat, two renderers) · F options UI behaviour · G performance ·
H unverified claim / docs drifted from code · I process slip · J install / environment · K other (mostly layout, lint, unknown cause).

**Why it was not caught:** 1 no test · 2 the test checked inputs, not the outcome · 3 API assumption not checked · 4 never run in game and
no stand-in for it · 5 the user's real data or setup not traced · 6 fix only on a branch · 7 claimed fixed without verification · 8 scope
not listed (not every case, caller or widget) · 9 other.

## Totals (56 defects and questions; features #201 and #203 left out)
Each defect counts once, under its main class and main code.

| Class | A | B | C | D | E | F | G | H | I | J | K |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Count | 2 | 5 | 9 | 3 | 4 | 8 | 1 | 2 | 2 | 3 | 17 |

K (17) = layout or geometry 11 (#73, #99, #128, #152, #153, #154, #159, #171, #331, #340, #351), Lua lint 3 (#112, #113, #121), style 1
(#286), unknown cause 1 (#191), not a defect 1 (#51).

| Why missed | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| Main code | 9 | 5 | 8 | 13 | 4 | 0 | 1 | 8 | 8 |

Sums: classes 2+5+9+3+4+8+1+2+2+3+17 = 56; codes 9+5+8+13+4+0+1+8+8 = 56.
Counting secondary codes too: **"never run in game" touches 24 of 56 (43 %)** (11 in #51-#166, 6 in #170-#340, 7 in #343-#365), and
"claimed fixed without verification" touches 7.

## The recurring patterns, and the rule that now stops each
1. **Never seen in game, and no stand-in that could show it** (24 of 56). Layout, hit areas, flicker, strata and font widths cannot be
   seen offline, and issues were closed without an in-game look. → V11 layout checks in the harness, V13 the in-game loop, V6 close only
   on confirmation.
2. **Tests checked that a setting was stored or a function was called, not what the player sees** (#344, #352, #276, #338, #331, S1).
   One test even asserted the behaviour Xaya had ruled out (#352). → V1 outcome tests with a negative control.
3. **Blizzard behaviour assumed from a partial reading** (#93, #142, #327, #353, #359, S2, #346, S1, #98). → V2 quote the 12.1.5 doc in
   full, every edge case gets a test; anything undocumented is an inference and fails safe.
4. **Scope not listed before changing or removing something** (#288, #311, #319, #347, #348, #355, #153, #166). → V4 list every reader,
   caller, display kind, widget and install path first, in the debug-log entry.
5. **The user's real data and setup not used** (#135, #292, #294, #315, #332, #344, #365, #364). → V3 reproduce with the export or saved
   data, keep it as a permanent test.
6. **Two authorities decide the same thing** (#97, #347, #344, S1; code gap 8). → V5 parity tests.
7. **Claims ahead of `main`** (#333 "fixed in 0.6.2" but not on main; `/xui auras` announced for 0.6.2, landed 0.6.6; #319's QA step
   never written; fixes waiting on unmerged branches for hours). → V6 done = on main (cite the commit) + confirmed.
8. **No static gate** (#112, #113, #121, #133, S6). → V8 lint and Lua-pitfall gate on every commit; large deletions listed.
9. **Earlier fixes lost in a rebuild** (#346: the 0.5.30 chat clamp fix vanished in the 0.5.90 rebuild). → V9 rebuild carry-over list.
10. **Process slips** (#85 concurrent session, version collisions, this session's S3-S8). → V10 `tools/precheck.py`.

## Every defect
"Checked" = Claude re-read the code on `main` for this claim on 2026-11-04.

### #51-#166
| # | What broke | Fix status | Class | Why | Rule |
|---|---|---|---|---|---|
| 51 | A question about the debug console filed as a defect | Not a defect; never answered | K | 9 | V12 |
| 73 | Gaps between letters in sidebar root titles | Done in code (one font string); issue still open | K | 4 | V11 |
| 85 | Kill switch hid At-Cursor Reminders | Not fixed; superseded by #103, feature shelved | I | 9 | V10 |
| 93 | Meta bar, Immolation Aura and buff sounds dead in combat | Partly (engine container 0.5.69 / 0.5.93; CDM timing 0.5.98); open | A | 3 (+4) | V2 |
| 97 | Remove / Move buttons differ by trigger kind | Partly (8f39734); skin-off rows still lack Up / Down | E | 1 | V5 |
| 98 | Sigil of Flame cue fires while on cooldown | Profile used "Is usable"; label unchanged; design questions unanswered | B | 9 | V12, V2 |
| 99 | Target Debuff field labels cut off | Not fixed | K | 4 | V11 |
| 106 | All Rules row jumps on refresh | Fixed 4e2537e; confirmed in game | D | 4 | V11 |
| 112 | Local used before its declaration | Fixed (checked: `XayaUI_Options/Options.lua:366`) | K | 1 | V8 |
| 113 | `_` leaks as a global | Fixed (checked: `Options.lua:5139`) | K | 1 | V8 |
| 121 | Empty `if` branches; shadowed local | Harmless now; still open | K | 1 | V8 |
| 127 | Options window blinks on every click | Partly (eeedad6); whole tree still rebuilt per click; closed unconfirmed | G | 4 (+7) | V6, V13 |
| 128 | Dragging the sidebar separator blanks the window | Duplicate of #187; de03ce4; root cause never found | K | 4 (+7) | V6 |
| 133 | New Rule button did nothing (regression) | Fixed 0031bbe (function deleted by 9125141) | I | 1 | V8 |
| 135 | Smart > Sounds lists rules with no sound | Fixed 01e1577 | C | 5 | V3 |
| 142 | "All Actions" toggle caused blocked-action errors | Hotfix, then feature removed (2568fb7) | B | 3 (+4) | V2 |
| 144 | Sound list offers files other users lack | Partly (probe); 229 untracked entries remain (#290) | J | 4 | V7 |
| 152 | New-rule picker rows overlap | Fixed after repeats; closed unconfirmed | K | 7 (+4) | V6, V11 |
| 153 | Options window covers Blizzard dialogs | Strata HIGH; two stale comments still say FULLSCREEN_DIALOG | K | 8 | V4, V11 |
| 154 | Sidebar scrolls a whole row at a time | Partly (smooth slide, still row steps) | K | 9 | V11 |
| 159 | Text overlaps with several triggers | Not fixed; closed without a repro | K | 4 | V6 |
| 165 | Item search: compare tooltips; pick leaves Item ID unchanged | Hover fixed; pick cause never found; closed | F | 4 (+7) | V6 |
| 166 | Icon cues show no icon | ba53a8b; refresh gap became #285; open | C | 8 | V4 |

### #170-#340
| # | What broke | Fix status | Class | Why | Rule |
|---|---|---|---|---|---|
| 170 | Window drags only by the title text | Partly; drag frame hidden while collapsed | F | 4 (8) | V13, V4 |
| 171 | Close / collapse buttons overrun the ribbon | Fixed (22 px); closed untested | K | 4 (7) | V11, V6 |
| 191 | Picker Texture row opened an icon cue | Cause never found; guard and log line; closed | K | 9 (7) | V6 |
| 276 | Profile import drops group settings | Add mode fixed (0.5.80); issue not updated; validation not built | C | 2 | V1 |
| 285 | Icon stays "?" after an ID is recognised | Fixed (repaint the parent's cues) | D | 1 (4) | V1 |
| 286 | Save-bar buttons in Blizzard red | Fixed; about 10 template buttons still unskinned | K | 1 (4) | V8 |
| 287 | Load tab hid options under Always load | Fixed | F | 9 | V12 |
| 288 | Cannot add a second Buff / Aura trigger | Restored; extended 0.6.5 | F | 8 (1) | V4 |
| 292 | Imported groups lack the eye and menu | Fixed (IDs normalised at load) | C | 5 (1) | V3 |
| 294 | Converted EUI rules lack Conditions rows | Converter fixed outside the repo; unverifiable here | C | 5 | V3 |
| 311 | Anti-Magic Shell: no duration or drain in combat | Engine coverage, toc load, duration bar; still failing per tester | E (+A, J) | 8 (5, 9) | V4, V3, V7 |
| 315 | Boiling Point proc cannot be tracked | Not fixed. **New lead:** aura 1265968 is the only aura that lights Blood Boil (`docs/reference/procs.md`) | C (+A) | 3 (5, 6) | V3, V6 |
| 319 | No Class load condition | Class condition added. **Checked:** "Always load" returns before the class check (`XayaUI/Conditions.lua:1132` vs `:1144`); whether that is right is open decision D6 | D (+H) | 8 (4) | V4, V12 |
| 327 | Twelve calls needed deprecation fallbacks | `XayaUI/Compat.lua`; found by the harness | B | 3 (1) | V2 |
| 331 | Chat history footer clipped | Fixed 0.6.1 + 0.6.4 | K | 4 (2) | V11, V1 |
| 332 | Divine Arbiter not tracked in combat | Not fixed. **New lead:** 1306161 / 1306162 / 1310461 light Divine Storm / Verdict, shared with other Retribution auras (`procs.md`) | C (+A) | 3 (5, 6) | V3 |
| 333 | Art picker lists 149 pictures only the author has | Claimed "fixed in 0.6.2"; **checked: not on main** (149 listed, 0 in the repo) | J (+I) | 9 (6) | V7, V6 |
| 338 | `/xui cursor` never registered | Fixed QoL 0.6.1 | F | 2 | V1 |
| 340 | Rules > Disabled shows parent groups | Fixed (flat list) | K | 1 (9) | V1 |

### #343-#365 and this session's defects
| # | What broke | Fix status | Class | Why | Rule |
|---|---|---|---|---|---|
| 343 | Dragging a rule is awkward | Partly (drop above / below); which drag is meant is undecided | F | 4 (8) | V1, V12 |
| 344 | Reorder in a dynamic group not shown on screen | 0.6.4 / 0.6.6 | C (E) | 2 (5, 7) | V1, V3, V5 |
| 346 | 30-40 px gap left of chat text | Chat 0.6.6; the 0.5.30 fix had been lost in a rebuild | B (I) | 9 (4) | V9 |
| 347 | Separate Text cue missing in game | 0.6.2 / 0.6.3; dynamic groups partial | E | 8 (4) | V5 |
| 348 | Red hover and click-anywhere on headers | Options 0.6.3 | F | 8 (4) | V4 |
| 351 | No standard margin or gutter | Not fixed | K | 1 | V11 |
| 352 | Buttons stretch; a lone dropdown takes a row | Partly (0.6.4 / 0.6.5) | H | 2 (9) | V1, V12 |
| 353 | PlaySound channel type | Likely not a defect (Blizzard passes "SFX"); unverified | H | 3 | V2 |
| 355 | Search box overlaps the scroll bar | 0.6.4 / 0.6.5 | F | 8 (4) | V4 |
| 359 | Combat duration, shield, stacks, debuffs, cooldowns wrong | 0.6.3 (16 fixes) | A (B, E) | 3 | V2 |
| 364 | Battle.net keeps patching the game | Not fixed; cause unconfirmed; installers removed | J | 4 (9) | V7 |
| 365 | Death and Decay rule never fires in combat | 0.6.8; Xaya: "worked" (issue still open) | C (A) | 5 (4) | V3 |
| S1 | Manual-order spacing doubled in combat | 0.6.7 | E (B) | 2 (3) | V1, V5 |
| S2 | Charge rule fired right after a charge was used | 0.6.9 / 0.6.10 | B | 3 (1) | V2 |

### This session's process slips (not counted above)
| # | Slip | Caught | Rule |
|---|---|---|---|
| S3 | Debug-log entry named 04:40 for a 03:51 commit | Renamed 0350 with a note | V10 |
| S4 | 17 Python wheel files staged in the repo root | Removed before the commit | V10 |
| S5 | Manifest rebuilt before new files were staged (GameDump 0.5.0) | Follow-up commit | V10 |
| S6 | `a and false or b` (always `b`): a condition's "off" cue changes could not be set (`OutcomesEditor.lua:240`) | Fixed 0.6.11; `tests/lua_pitfalls_run.py` | V8 |
| S7 | 0.6.8-0.6.11 reached main before the full suite (0.6.8 at Xaya's request) | Full suite afterwards: 68 groups ok, harness PASS | V6 |
| S8 | The new pitfalls test ended without the runner's pass marker, so it was listed as FAIL | Fixed 73598e4 | V10 |
| S9 | Analysis: old branches with no shared history first reported as "ahead 11-14 commits" | Corrected before any deletion | V2 (check the tool's assumption) |
| S10 | While writing this retrospective: the session summary said "Last updated 07:00 UTC" at 06:46 | Caught before the commit; `tools/precheck.py` now checks the summary's time too | V10 |
| S11 | Found by the new precheck: a debug-log entry named `2026-11-02-2400-...` (24:00 is not a time) | Renamed `2026-11-03-0000-...` with a note | V10 |

Near-misses caught before a push: a parity test read stale positions; an extra engine step shifted a timing test; 3-charge counts were
clamped (a guess) before being made strict; a test renamed a spell while names were cached.

## Housekeeping the review turned up (for Xaya)
- **Closed without a fix or a found cause:** #159, #165 (pick half), #191, #128 / #187 (fix never confirmed), #127 (partial).
- **Claimed but not on main:** #333.
- **Open but done in code:** #73, #121; #365 (Xaya confirmed it in game); #276 (add mode).
- **Promised QA step never written:** #319's class-load check.

## Code gaps: logic, talent / ability links, aura data
From the code reviewer, at 0.6.10; each was re-checked against 0.6.11. "Checked" = confirmed in the code; "corrected" = the reviewer's claim was
partly wrong and the row says what is true.

| # | Gap | Status | Impact |
|---|---|---|---|
| 1 | Any Cooldown Manager icon counts as proof, from any viewer, without checking the viewer is shown | **Corrected / checked.** Cooldown icons do pick up your auras (Blizzard `CooldownViewer.lua` RefreshData → RefreshAuraInstance), so "cooldown icons never show the aura" is wrong. True: a **hidden viewer stops listening to aura events** (`CooldownViewer.lua:1744-1754`) and XayaUI never checks this, so a hidden viewer gives stale answers; and Cooldown Manager icons only follow auras **you** cast (`sourceUnit == "player"`). Target Debuff's icon check also runs the player-buff tracker for the debuff ID | "Missing" can fire while the buff is up |
| 2 | An absent aura reads as 0 s left | **Checked** (`Outcomes.lua:148`, `Triggers.lua:613`). Xaya's decision D1: a time condition on an absent buff is NOT met | "seconds left <= 2" fires while the buff is missing |
| 3 | Aura search ranks talents / abilities before the aura with the same name | **Checked** in part (class list learns cooldowns only, `ClassLearn.lua:48`) | Rules get the talent ID, which no aura carries |
| 4 | Replacement spells (overrides) are followed only by the charge / cooldown read | **Checked** (only `ns.SpellOnBar`, `Conditions.lua:107-209`) | Wrong or missing charges, cast triggers and icons for replaced spells |
| 5 | No proc-glow route at all | **Checked** (no `SPELL_ACTIVATION_OVERLAY_GLOW_*` or `IsSpellOverlayed` anywhere) | Procs stay unknown in combat; see `docs/reference/procs.md` |
| 6 | Learned aura length keyed by ID only, written on refreshes too, preferred over the loadout-aware model | **Checked** (`Conditions.lua:697-700`, `Timing.lua` AuraEstimate) | Wrong time left after a talent swap or refresh |
| 7 | The 0.6.10 Tracked Buffs fallback reports the rule's buff ID, so the time estimate finds nothing | **Checked** (`Conditions.lua:630`) | Present, but time left unknown |
| 8 | "Buff / Aura (another)" rows skip the fallback the built-in trigger has | **Checked** (`Triggers.lua:563`) | Same aura answers on one trigger, unknown on the other |
| 9 | Engine icon ignores a row's extra IDs; no rebuild on a talent change | **Checked** (`AuraDisplay.lua:159`, events at `:1111`) | Engine icon empty while the trigger counts a variant |
| 10 | Cooldown read never checks the spell is known | **Checked** (no known-check in ReadCooldownRaw); impact is an inference | "Ready" may fire for an unlearned spell |
| 11 | Cooldown seconds-left uses the estimate even when the never-secret flags answer; a past-due estimate returns 0 | **Checked** (`Outcomes.lua:126-137`) | 0 s while still on cooldown |
| 12 | No set-bonus load option or trigger | **Checked** (set bonus read only for a hash, `AuraModel.lua:118-150`) | Tier-set auras (Divine Arbiter) cannot be tied to the set |
| 13 | One unreadable extra ID makes the whole aura answer unknown | **Checked** (`Conditions.lua:546-551`) | "Missing" blocked in combat |
| 14 | No passive learning; GameDump data unused by core | **Checked** (learning only while the setup window is open) | Aura links, lengths and stack maxima stay empty |
| 15 | The Cooldown Manager catalogue is unused by the engine; override changes in combat not followed | **Checked** (no `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`) | Icons reassigned in combat lose their IDs |
| 16 | "Show while the aura is up" displays ignore load and talents | **Checked**; the code comment says this is deliberate, so it needs Xaya's decision (plan 2.2) | Icons for unloaded rules can show |
| 17 | Two talent readers disagree; `overrideSpellID` read on a structure that has `overriddenSpellID` | **Checked** (`AuraModel.lua:106` falls back to `spellID`, so the read is dead, not wrong) | Small |
| 18 | "Loaded" has several definitions; "Always" says it ignores every condition but talents still apply | **Checked** (`Options.lua:1495` vs `Conditions.lua:1256`) | Rules load differently by path |
| 19 | Rule creators set "no talent" even for talent / hero entries | **Checked** (`Options.lua:2857, 3373`) | Created rules do not follow talents |
| 20 | `C_Secrets.ShouldSpellAuraBeSecret` unused | **Checked** | A trustworthy "absent" is missed (semantics an inference) |
| 21 | Never-secret signals unused: PandemicTime alert, AddAuraSound (D2 approved), the stamped `xuiUpdatedAt` | **Checked** | Lost signals |
| 22 | Charges watched only for the rule's own spell, not "Cooldown (any spell)" rows | **Checked** (`Conditions.lua:180-195`) | Rows read "full" after a /reload in combat |

**Fix order** (each through VERIFICATION.md): 2 (D1 is already decided), 1, 8 with 7, 11, 22, 13, 4, then 5 with task #28, then 6, 9, 10,
12, 14-21.

**Status at core 0.6.13** (2026-11-04, `debug-log/2026-11-04-0824-aura-gaps-core-0.6.13.md`; in code with outcome tests, none confirmed in game yet):
- **Fixed in code:** 1, 2, 4, 6, 7, 8, 9, 10, 11, 12 (Tier Set Pieces Worn trigger), 15, 22.
- **Partly done:**
  - 5: Spell Glows trigger, and the glow fallback, which needs a pairing seen in game first;
  - 21: AddAuraSound opt-in and the per-rule combat line done; PandemicTime and `xuiUpdatedAt` not yet;
  - 20: reported only, by design, until the in-game data settles what "false" promises.
- **Left as is, on purpose:** 13 (would risk a false "missing").
- **Waiting on Xaya:** 16.
- **Not started:** 3, 14, 17, 18, 19.

## Missed aura data, and where it can come from
| Source | What it gives | State |
|---|---|---|
| Blizzard's `SpellActivationOverlay` table | Which buttons each proc aura lights, and whether only that aura lights them | **Indexed:** `docs/reference/procs.md` (build 12.1.5.70783, via wago.tools) |
| Glow, proc-art, override, icon and "now usable" events | Spell-state changes with no secrecy flag (12.1.5 docs) | Planned: task #28; an in-game probe first |
| Combat log file / Warcraft Logs | Exact aura apply / remove times, joined offline with XayaUI's own signal log | Planned: task #28 |
| Cooldown Manager catalogue (`/xuidump catalogue`) | Spell → linked aura IDs per spec | Captured by GameDump; unused by core (gap 14, 15) |
| Our API reference | Secrecy rules per widget aspect | **Fixed 2026-11-04 (core 0.6.13 batch):** `build_reference.py` now keeps Enum names, so `widgets.md` reads `SecretReturnsForAspect=[SecretAspect.BarValue]` (was `[0]`); rebuilt from the same capture and documentation, names were the only change |
