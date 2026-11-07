# Overnight status, 2026-11-07

First snapshot ~08:35 UTC by the 11-06 hub; kept current by the overnight hub session_014bN6tWMaSvKkwjeonHvvch until Xaya wakes (~15:30-16:30 UTC). Standing orders and session map: docs/process/HUB-HANDOFF-2026-11-07.md.

## Main
- origin/main at 08:32 UTC: 7b830cf (unchanged since the handoff).

## Log
- 08:30 UTC: new hub took over from session_014bN6tSStpdmmCXviFAqPdQ. Every mapped session told; handoff files requested from the 10 heavy sessions (O-152); "all on main" confirmations requested from the 7 completed sessions; O-151 branch list requested from branch cleanup and the lander. Next check-in 10:02 UTC.

## O-152 migration
| Old session | Scope | Handoff file | Successor | Archived |
|---|---|---|---|---|
| session_014bN6tV7oStjTuVPEJbytBJ | UI bugs | requested | — | no |
| session_014bN6tTxYo6enpkMGsVkMqm | Perf | requested | — | no |
| session_014bN6tSjceDcH6FdJCeukZG | Chat issue review | requested | — | no |
| session_014bN6tTZroPi49dAYwBbeGp | D8 raid rules | requested | — | no |
| session_014bN6tSfFULX4BSXzmZ1yCx | Function audit | requested | — | no |
| session_014bN6tUt2Da7LiGNYKgtM7R | Nameplates | requested | — | no |
| session_014bN6tX7AoZQrGX246YSXjC | Progress bar cues | requested | — | no |
| session_014bN6tUPG6SDvkoa3i3tMu5 | Reskin elements | requested | — | no |
| session_014bN6tSRsJgz4JWyawQp5gk | LFG / Wordle (PAUSED by her words; no successor, archive after RMG-Q0 is in the flow) | corrected 08:40 | — | no |
| session_014bN6tSZh6UFB2WcRuyXqBZ | Lander (last, between landings) | not yet | — | no |

## Completed sessions (archive on confirmation)
| Session | Scope | Confirmation | Archived |
|---|---|---|---|
| session_014bN6tTuH6rxEfggbnTEH3o | Roadmap Features | asked | no |
| session_014bN6tTRFsCmBvVCUDVtrds | Rule generation (still writing a walkthrough) | asked | no |
| session_014bN6tV7wcxBdJHNGwnMXZP | Chat follow-ups | asked | no |
| session_014bN6tSiDK8R3ZHPmcK9QHR | Additional Concepts | asked | no |
| session_014bN6tWZxqCW85vMEyHdfnt | Character Pane (still running) | asked | no |
| session_014bN6tStyDJVemzE9tX7F38 | New Features + Reskins (merging main) | asked | no |
| session_014bN6tSuhd4nhS3kubHR58K | Chat | asked | no |

## Fresh sessions (left alone)
Externals session_014bN6tUA9JtkPEkQ3Qch7iE; chat round session_014bN6tUJW6J1rnMZ6Z7t7c1; QA flow session_014bN6tUZLKHa2NXorHRJghL; top tabs session_014bN6tWsQ4qcob9VPKD7PV5. Feature summary session_014bN6tU26cuzQ9LarKYhZQx and branch cleanup session_014bN6tV8Z5syBadjkfcN2Z4 stay as they are.

## O-151 branches
Snapshot above (from branch cleanup, 08:28). Fresh classified list requested from branch cleanup (docs/process/BRANCHES-2026-11-07.md) and the lander.

## Held (O-109)
D8 load-condition changes: stay off main; first question in the QA flow.

# Snapshot ~08:35 UTC (11-06 hub)

Main = 7b830cf at this snapshot. The rows below are the sessions' own reports (data), condensed.

## Landing queue (lander session_014bN6tSZh6UFB2WcRuyXqBZ; batches of ~70 min)
| Branch / PR | Owner | State |
|---|---|---|
| adoring-hawking-wyda59 e0a408c + info_pane cap bfc79ef | S1 Character Pane (stat calculator #87-#91, B2, B6) | lander suite running |
| chat-246-whisper #439 (665c0c5) | chat issue review | owner suite running; lands before #443 |
| chatrev-landed f2348b3 #437 (docs) | chat issue review | to land |
| function-audit-land ee2e4e6 #441 | function audit (22 of 58 defect rows; rest building overnight) | owner suite running |
| dreamy-edison-pvb3i1 4cc2c221 #436 | bar cues walkthrough | owner suite running |
| cool-ramanujan-ewx8e5 | New Features + Reskins (S3: Dev Assist walkthrough answers, R31) | orphan-looking; lander tests next batch |
| perf-landing-2 2fa2c8a → perf-qol-idle → perf-options | perf (P-9..P-14; P-16 Options open/click building, ETA ~2-3 h) | lands as one chain |
| externals-in-combat 318c8b2 #444 (base perf-landing-2) | externals (core 0.6.69, J26) | owner suite running |
| chat-round-1106 64d8e78 #443 (includes #439) | chat round (UI-3/15/18/19/21) | owner suite running; versions to relabel |
| nameplates-plater 32071a1 #442 | nameplates (new addon XayaUI_Nameplates 0.1.0, off by default; slice 2 building) | owner suite running |
| ui-bugs-focused | UI bugs | building (O-128/O-139/O-146, UI-*) |
| settings-restructure | top tabs + Profiles (UI-23..27) | building, ETA ~2.5 h; Options 0.6.71, Dev Assist 0.7.31, QA B250-B259 |
| qa-review-popup | QA popup + question flow | building; first landing ~11:30 UTC |
| determined-gates-89j6pv 170ac94 #445 (docs) | 11-06 hub | to land |
| Reskin registry (determined-cerf successor) | reskin elements | building, first tranche ~5-6 h |

## Held / not for main
- **HELD (O-109):** d8-raid-rules-main dc7628f (PR #440). All of D8 is the load-condition change. It is question D8-Q1 in the flow. Also fervent-cerf-hldtwn (engine session 2, inactive; the load condition) and d8-raid-rules (#435, superseded).
- **Superseded:** function-audit (#433), perf-test-m-plus (#434), eloquent-wright.
- **Not for main on purpose:** roadmap-features/combined (#429), archive/*, qa-installer-branch.
- **STALE, for Xaya to delete:** roadmap-features/games, /rppm, /layout-profiles; claude/eloquent-rubin-n9zb99, claude/frame-strata-conditions, claude/magical-cray-jmspwv, wip/notepad-icons.
- **Contained in main, for Xaya to delete (20):** bundle-2300, claude/admiring-ride-sm7jrh, adoring-goldberg-19dcfq, chat-issue-review-a14, chat-qa-walks, clever-noether-0o0uuj, determined-cerf-981pn8, determined-gates-89j6pv*, ecstatic-cori-sfi3hk, eloquent-wright-iic6k6, exciting-carson-7gl2bt, feature-update-summary, gallant-allen-gmvfr0, great-franklin-j4cahh, inspiring-mendel-8r8qao, nifty-fermi-vz9z49, patch-notes-info-pane, perf-test-m-plus-land, relaxed-fermi-k3vbex, rule-generation-buttons.
  (*determined-gates has new commits since: #445.)

## Sessions with nothing open (archive once the QA flow confirms it has their questions)
- Additional Concepts session_014bN6tSiDK8R3ZHPmcK9QHR (11 questions sent).
- Chat follow-ups session_014bN6tV7wcxBdJHNGwnMXZP (questions sent).
- Roadmap Features session_014bN6tTuH6rxEfggbnTEH3o (26 questions sent; roadmap-only items stay roadmap).
- Feature update summary session_014bN6tU26cuzQ9LarKYhZQx: keep until it writes "What changed overnight".
- LFG / Wordle session_014bN6tSRsJgz4JWyawQp5gk: paused by her direct words ("Pause on all of this until further notice"). It stays paused; one question RMG-Q0 goes to the flow; then archive.

## Known limits to tell her
- Nothing has been tested in the game.
- D8 load conditions are held (O-109).
- Reskins: tier-C combat frames are not skinned (taint risk; question Q4).
- Nameplates: Aura Reorder is blocked on NP-Q5. The M+ spell / NPC-keyed scripts are judged impossible or risky (plan doc).
- Roadmap items (RM-GSEARCH, Raid Tools, M+ Tools, games, RPPM) are not built. Her words asked for roadmap entries only, or paused them.
- Branch cleanup wants a ping at ~14:30 UTC for its refresh.
