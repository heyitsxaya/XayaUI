# Fix plan 2026-11-08: full tracker

The full record for the fix plan from the code review of `main` at 3eb0c4b (2026-11-08). The cold-start file is
`FIX-PLAN-2026-11-08-SESSION-SUMMARY.md` next to this one. The page with checkboxes is `FIX-PLAN-2026-11-08.html` (open it in a
browser; ticks are kept in that browser only, so the **Status** column below is the shared record).

Facts here were checked in session 014bN6tUDLJ6T742DewZDg1s unless marked (unverified) or (inference).

## 1. Sources

| Item | Where | State |
|---|---|---|
| Plan page (Xaya's upload, original order) | not in the repo; uploaded to session 014bN6tUDLJ6T742DewZDg1s as `xayaui-fixes.html` | superseded by the reordered copy |
| Plan page, reordered | `docs/plans/FIX-PLAN-2026-11-08.html` | current |
| Full evidence file the page cites, `xayaui-review-2026-11-08.md` | not in the repo, not in the upload | **missing**: the ~64 findings not on the page, and the "0 refuted" / "no regressions" claims, cannot be checked until it is found |

## 2. What the page claims vs what it shows

| | Header | Rows on the page |
|---|---|---|
| Findings | 132 (2 high, 31 medium, 99 low) | 68 rows (2 high, 28 medium, 38 low) |
| Verdicts | 27 confirmed, 6 plausible, 22 downgraded, 0 refuted (55 checked) | 24 confirmed, 5 plausible, 19 downgraded, 20 unverified |
| Coverage | 14 filed, 32 partly, 29 related, 57 new | 6 covered, 17 partial, 16 related, 29 new (before the filter fix) |

Calculation: row counts are from parsing every `<li class="fix">` in the page (data-sev, data-cov, and the first verdict tag).
The two sets agree only if some rows bundle several findings; the page does not say which (inference).

## 3. Decisions

| # | Date (UTC) | Decision | By | Why | Other options considered |
|---|---|---|---|---|---|
| D1 | 2026-11-08 | Reorder the phases; fix the "New only" filter | Xaya ("reorder the phases and fix the filter") | Review found the order broke the page's own rule and the filter hid rows with new findings | — |
| D2 | 2026-11-08 | Test checks that can falsely pass go first (phase 1) | Claude (proposal; Xaya may overrule) | Every later fix is verified by these tools; `options_click_cost` cannot fail at line 378 | Keep them in phase 6 (rejected: phases 1-5 would be checked by a suite known to be wrong); move all test work first (rejected: the harness-depth items are large and would block player fixes for long) |
| D3 | 2026-11-08 | Split the old "Test trust" phase: small fixes in phase 1, large harness work in phase 9 | Claude | Secret-value / combat-lockdown emulation is a project, not a fix | — |
| D4 | 2026-11-08 | Plausible-only items with feature-removing fixes get their own phase (5) behind the in-game check | Claude | The ESC-menu and Game Menu fixes rebuild or remove features on unconfirmed findings | Leave them in "Remaining correctness" (rejected: nothing stopped a fix before the check) |
| D5 | 2026-11-08 | "Imported folder cycle" (f1-4) moved to Import hardening | Claude | Same input (pasted strings), same pass | — |
| D6 | 2026-11-08 | Checkbox IDs kept (f1-1 ... f7-14) though rows moved | Claude | Ticks already saved in a browser stay on the right row; the IDs no longer match the phase numbers | Renumber (rejected: loses saved ticks) |
| D7 | 2026-11-08 | Rows that mix a new finding with a tracked one carry two coverage tokens (`related new`, `covered new`, `partial new`) | Claude | The filter compared the attribute to exactly "new"; f5-4, f6-1, f7-10, f7-2 were hidden | Retag them as "new" (rejected: the page's coverage would then misstate the tracked half) |
| D8 | open | f1-15 "Exactly N seconds": remove the choice, or keep it with a tolerance window | **Xaya** (V16: no guessing) | It changes what players can pick | — |

## 4. Severity notes from the spot-check (not changed on the page)

- f1-14 "Timestamp helpers defined twice": duplicate code in the same scope; harmless. A cleanup, not a correctness bug.
- f1-12 "Chat verdict cache": real; the cost is one extra `Decide` call per 600 cached lines.
- f6-4 "Saved file executed as code": medium only if the tools are run on files from testers; low on Xaya's own files.

## 5. Rows

Phase numbers are the reordered ones. "Spot-check" is what session 014bN6tUDLJ6T742DewZDg1s found in the code at 3eb0c4b; "not checked"
means the plan's verdict is the only evidence. Status values: open, branch `<name>`, main `<commit>`, done in game, dropped (with reason).

| ID | Phase | Sev | Verdict (plan) | Coverage | Fix | Spot-check 2026-11-08 | Status |
|---|---|---|---|---|---|---|---|
| f1-10 | 1 | med | Confirmed | related | options_click_cost forces the counters it checks | holds (options_click_cost.lua:378 sets builds, fills = 1, 1 before the check) | open |
| f1-9 | 1 | low | Downgraded | related | run_all.py counts "10 failed" as a pass | holds (run_all.py:16 substring match; also needs exit 0) | open |
| f6-6 | 1 | med | Confirmed | new | precheck ignores git errors | not checked | open |
| f6-3 | 1 | med | Confirmed | new | Saved-variable round trip stringifies numeric keys | not checked | open |
| f6-4 | 1 | med | Confirmed | new | Two tools execute a player's saved file as code | holds for formula_fit (lua51.py runtime keeps os/io); severity depends on running it on testers' files | open |
| f1-11 | 1 | med | Confirmed | related | perf_report reads perfLog from the wrong store | holds (perf_report.py:238, 353 read CueRulesDB; Engine.lua:276-381 writes the Dev Assist store) | open |
| f1-1 | 2 | high | Confirmed | related | Theme page Save, Export and Import never work | holds (ThemeEditor.lua:73, 278-308; rebuilt via Options.lua:377-386, 589) | open |
| f1-2 | 2 | high | Confirmed | related | Deleted dynamic group keeps drawing auras | holds (AuraDisplay.lua:1012-1024: only folders still in ns.folders are hidden) | open |
| f1-3 | 2 | med | Confirmed, worse | new | Stale Target Debuff numbers fire conditions | not checked | open |
| f1-5 | 2 | med | Confirmed | new | Privacy cover misses the input line above the tabs | consistent with Privacy.lua:73-86; InputPos not traced | open |
| f1-6 | 2 | med | Confirmed | partial | Display → Sound conversion makes junk rules | partly: originals removed without RecycleRule (Sidebar.lua:1017-1022); child-row half not traced | open |
| f1-7 | 2 | med | Confirmed | partial | Gear compare matches equip location, not slot | not checked | open |
| f5-1 | 2 | med | Confirmed | related | Routed steps clear the Timing deadline | not checked | open |
| f5-4 | 2 | med | Confirmed | related new | Deleted group box stays; group drag uses wrong scale | not checked | open |
| f5-5 | 2 | med | Confirmed | partial | Edit lock bypassed by drag and folder menu | not checked | open |
| f2-1 | 3 | med | Downgraded from high | related | OnHide hook reverts drafts from another addon's window | not checked | open |
| f2-2 | 3 | med | Confirmed, worse | new | Spell search survives EditBox recycling | not checked | open |
| f2-3 | 3 | med | Confirmed, worse | new | RefreshTree wrappers, Delete-key hook, OnRelease wrapper, pullout patch | not checked | open |
| f2-5 | 3 | med | Confirmed | new | Slider arrows recreated on every acquire | not checked | open |
| f2-4 | 3 | low | Downgraded | related | Blank-space right-click menu on other trees | not checked | open |
| f3-1 | 4 | med | Downgraded from high | new | Sidebar popups delete from a dead rule copy | not checked | open |
| f3-2 | 4 | med | Confirmed, worse | partial | QA walks overwrite or lose the settings snapshot | not checked | open |
| f3-4 | 4 | med | Plausible | new | QA check swaps GameTooltip methods by assignment | not checked | open |
| f3-3 | 4 | low | Downgraded | partial | Shared QA test group carries leftovers | not checked | open |
| f5-2 | 5 | med | Plausible | covered | ESC-menu hook writes Blizzard's pooled buttons | not checked | open |
| f5-3 | 5 | med | Plausible | partial | Game Menu skin own-layout forwards clicks | not checked | open |
| f1-8 | 5 | low | Plausible | new | Data Panels touch state drivers in combat | not checked | open |
| f5-6 | 5 | low | Plausible | new | One secret aura field aborts a recorder batch | not checked | open |
| f4-1 | 6 | med | Confirmed, worse | new | Normalization never type-checks fields | not checked | open |
| f1-4 | 6 | low | Downgraded | new | Imported folder cycle overflows the stack | not checked | open |
| f4-2 | 6 | low | Downgraded | related | Themes profile part merges field by field | not checked | open |
| f4-3 | 6 | low | Unverified | related | Imported rules keep chat-sending actions silently | not checked | open |
| f4-4 | 6 | low | Unverified | new | Remapped uids can collide | not checked | open |
| f4-5 | 6 | low | Unverified | partial | Replace-import removes the default categories | not checked | open |
| f4-6 | 6 | low | Unverified | related | Cleared cueKey is never repaired | not checked | open |
| f4-7 | 6 | low | Unverified | partial | Import window: untrusted name concatenated; theme import skips "Discard?" | not checked | open |
| f4-8 | 6 | low | Unverified | related | Partial store survives an OpenStore error | not checked | open |
| f1-12 | 7 | low | Unverified | new | Chat verdict cache drops the verdict it just stored | holds (Messages.lua:197-198); cost is one extra Decide per 600 lines | open |
| f1-13 | 7 | low | Unverified | new | Search strips UTF-8 bytes one at a time | holds (SpellSearch.lua:162, RuleSearch.lua:33) | open |
| f1-14 | 7 | low | Unverified | new | Timestamp helpers defined twice | holds (Chat/Options.lua:483 and :532); dead code, not a correctness bug | open |
| f1-15 | 7 | low | Unverified | new | "Exactly N seconds" compares floats with == | holds (Conditions.lua:1244 x == v) | open |
| f1-16 | 7 | low | Unverified | new | Avoidance gain coloured as worse | not checked | open |
| f1-17 | 7 | low | Unverified | partial | QA note records "true" instead of the note; no Skipped chip | not checked | open |
| f5-7 | 7 | low | Unverified | related | Second return of R() never sees HIDDEN; Change box resets in combat | not checked | open |
| f5-8 | 7 | low | Unverified | new | Error handler can recurse until C stack overflow | not checked | open |
| f5-9 | 7 | low | Unverified | new | Sound handles discarded, previews stack | not checked | open |
| f5-10 | 7 | low | Unverified | new | Chat sidebar stop in combat strands Blizzard buttons | not checked | open |
| f5-11 | 7 | low | Unverified | new | Recycle Bin purges items of unloaded modules | not checked | open |
| f5-12 | 7 | low | Unverified | partial | Shopping List history double-counts after unreadable reads | not checked | open |
| f7-7 | 8 | med | Confirmed | partial | Any GET_ITEM_INFO_RECEIVED rebuilds two panels | not checked | open |
| f7-8 | 8 | med | Confirmed | new | Chat history Live rebuilds all lines per message | not checked | open |
| f7-9 | 8 | med | Confirmed | partial | Options tree rebuilds and sidebar rescans | not checked | open |
| f7-10 | 8 | med | Confirmed | partial new | Theme changes schedule uncoalesced skin passes; dropdowns re-measured | not checked | open |
| f7-12 | 8 | med | Confirmed | new | Ability Scaling scans spells × talents per render | not checked | open |
| f7-1 | 8 | low | Downgraded | covered | Cooldown Manager index rebuilt 4× a second | not checked | open |
| f7-2 | 8 | low | Downgraded | partial new | Display frames and aura containers leak on every edit | not checked | open |
| f7-3 | 8 | low | Downgraded | covered | Auto-size group box runs a 5 Hz OnUpdate forever | not checked | open |
| f7-4 | 8 | low | Downgraded | partial | Every cast runs the duration model | not checked | open |
| f7-5 | 8 | low | Downgraded | new | Chat input open/close triggers a full refresh | not checked | open |
| f7-6 | 8 | low | Downgraded | partial | Stats tab redoes 36 item reads per render | not checked | open |
| f7-11 | 8 | low | Downgraded | partial | DevAssist probe inflates Mythic+ perf recordings | not checked | open |
| f7-13 | 8 | low | Downgraded | related | Aura bars rebuild tooltip data every step | not checked | open |
| f7-14 | 8 | low | Unverified | covered | Per-step allocations on the hot path | not checked | open |
| f6-1 | 9 | med | Downgraded from high | covered new | Harness never produces secrets or combat lockdown | not checked | open |
| f6-2 | 9 | low | Downgraded | covered | Enums numbered by position in the API index | not checked | open |
| f6-5 | 9 | low | Downgraded | new | engine_bench.py no longer runs | not checked | open |
| f6-7 | 9 | low | Unverified | related | Harness and chat_world stubs differ from the game | not checked | open |
| f6-8 | 9 | low | Downgraded | new | perf_report reader is quadratic | not checked | open |

## 6. History

| Date (UTC) | Session | What |
|---|---|---|
| 2026-11-08 | 014bN6tUDLJ6T742DewZDg1s | Xaya asked for a review of the uploaded plan. 13 claims checked in the code at 3eb0c4b; all hold, 3 over-rated. Plan-level problems: test fixes too late, order broke its own rule, "New only" hid 4 rows, header counts not reproducible from the page, plausible items had fixes before their check. |
| 2026-11-08 | 014bN6tUDLJ6T742DewZDg1s | Xaya: multi-session; reorder and fix the filter. Page copied into the repo, reordered into 9 phases (D2-D6), filter fixed (D7), this tracker and the session summary made. Checked in headless Chromium: 9 phases, 68 rows, "New only" shows 33 (29 + the 4 mixed rows), ticking updates the count, no horizontal scroll at 390 px, no script errors. |
