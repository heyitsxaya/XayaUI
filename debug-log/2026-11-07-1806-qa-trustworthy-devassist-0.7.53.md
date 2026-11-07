# QA walkthroughs made trustworthy before the refactor (Dev Assist 0.7.53; phase P0.5)

Logged 2026-11-07 18:06 UTC. Branch `claude/lucid-mayer-pv4ytn`. Plan: `docs/plans/PLATFORM-SPLIT-2026-11-07.md` section 15, order 1
(P0.5 Testing tools). Issues #461 (bars-cues steps 4 / 5 / 8 / 9), #465 (navigation and list state), #466 (review search row), #467
(J31), #480 (switches around a reload), #481 (title wrap, opaque windows), #484 (clean-up steps not Pass / Fail), #485 (audit-opt-bin
state and clean-up), #486 (comma-splice titles). Scope: XayaUI_DevAssist only (plus tests, docs/QA-CHECKLIST.md, the generated
checklist walkthroughs, MANIFEST). No product code in any other addon changed: where a walkthrough now fails because the product is
broken (for example the J31 search step if the option is not scrolled into view, or bars-cues step 4 on an aura with no type), that is
the intended outcome.

## Runner rules (QAWalk.lua, QATable.lua, QAReview.lua)
- A1 (#461) A step with a `setup` cannot be passed, accepted or marked Done until its setup ran in this run (`run.setupDone[i]`, set
  only when the setup returned without an error). Before it, the check line says "Press Do it for me first: this step's check only
  means something after it has run.", Pass / Done are greyed, Accept is hidden, `QA.Answer("P"/"D")` and `QA.Accept()` record nothing.
  Fail and Skip always work (a setup that cannot run is a failure to report). Back / forward keep it within the run; Run again resets it.
  Consequence: a step whose text offers "(or press Do it for me)" now needs Do it for me pressed before Pass, even when she did it by
  hand (the audit-opt-bin Restore step says so: "press Restore yourself, then Do it for me; it restores it for you if you have not").
- A check returning `nil` (not true / false) = not tested: "Not tested yet: <note>", no Accept, recorded as `a = "?"`. Used where the
  thing under test was not exercised (J31 with no editor redraw, J22 with no other addon error, D52 with no hover, audit-engine with the
  box ticked, audit-chat with nothing to give back, bars step 9 with the settings window closed, the reload parts before a /reload).
- A3 (#484) `done = true` steps (clean-up, put-back, "anything look wrong?"): no Pass / Fail, one Done button (greyed until Do it for
  me), recorded as `r = "D"` (export / import carry it: the import pattern takes `[PFSD]`); its check still runs and its data is kept.
  41 last steps converted (every "Last step: press Do it for me to ..." put-back / remove / delete step, the eleven Reskin "your reskin
  settings are put back", credits-page "close the version pane", perf-load-first "stop the timer", settings-toplevel's "anything look
  wrong?", review-window part 1's prepare-for-reload step) plus the new parts' last steps. Left as verdict steps on purpose: genuine
  questions ("Your call ...", ui-calc-infobox, review-search's last step, reskin-rename, audit-spelling), nameplates-blizzard-options'
  last step (it tests the Put back feature itself), audit-chat's last step (it also asks for the ignore message by eye), review-open.
- A2 `QA.Counts(steps)`; a run with no P and no F (all S, or S + D) is "skipped": QATable `TB.Status` -> "skipped" ("Skipped", grey
  cccccc) in both tables; `QA.StatusText` (and so `RV.Verdict`) -> "Skipped"; the Done page heads such a run "Skipped: no step was
  passed or failed." and counts "N done" apart.
- A4 (#465) Done page: All walkthroughs, Review list, Next in this list. All walkthroughs (list page) has a Review list button (top
  right). Open (in either table) passes the table's current visible order (`T:Ids()`) to `QA.Start(id, { order, from })`; Next = the
  next id after this one in that snapshot (CHOICE, not settled by the spec: the order as the list showed it when the walkthrough was
  opened, so a status tag such as Not run that would drop the finished walkthrough from the list does not lose the place); the chain
  of Next keeps the same snapshot; the last one shows a greyed "Last in this list". Going to a list (All walkthroughs, Review list)
  ends "back to the review when the runner closes" (`RV.ForgetReturn`). The list state: each table already kept its search, chips and
  sort in memory for the session (`T.f`, `sortKey`, `sortDesc`); now pinned by tests across Open -> Done -> All walkthroughs and Review
  list. Memory only: no new key in XayaUIDevAssistDB or CueRulesDB (asserted).
- A5 (#481) the title wraps inside the window (width = window - 14 - 36 for the close button; - 120 more on the list page for Review
  list); the step page's step number and text, the Done page's summary and the list's search row start below `QA.TitleBottom` (12 +
  measured height + 8). Background: `QA.SolidBackground` puts one colour texture (0.05, 0.05, 0.07, `QA.WINDOW_ALPHA` = 0.95) under the
  runner / list, review and question windows (the backdrop draws only the border now). PROVISIONAL: Xaya's answer C4 is pending. The
  theme's "Window opacity" (CueRulesDB.ui.skinAlpha, 0.62 by default, ThemeEditor.lua) is the settings window's see-through look, so it
  is not used here (it would make these windows less opaque). Note: the windows were 0.96 through the backdrop before; the texture does
  not depend on the backdrop template.
- A6 (#466) the review window measures its title and intro line and places the table's search row at max(56, intro top + intro height
  + 10) (`T:SetTop`); the chips, header and rows follow at the next `SetEntries`. Area chips not renamed (her answer pending).

## Checks that passed without testing (fixed)
- bars-cues (B200): step 4 compares the drawn colour with the same bar in Blizzard default (`ns.BarTypeColor(t, "blizzard")`, or the
  colour it already has when there is no type) and fails when equal ("no style changed the bar"); before, an aura with no type
  returned Pass. Step 8 (Type colours) is `noVerdict` (the addon cannot read the tooltip she hovered; coloring a sample line tested
  nothing she sees). Step 9 (Done): the rule and group gone from the data AND `QA.WindowMentions` finds no Rules sidebar row and no
  editor widget showing "XayaUI QA: Bar test" in the open settings window (the setup also asks the window to redraw through the
  optionsDebug service's Notify); window closed -> not tested. Step 5's meaningless result is stopped by A1.
- J31 perf-settings-click: step 1 got Do it for me (opens Rules, starts noting). A post-hook on AceConfigDialog:Open (placed once, only
  after XayaUI_Options is loaded, so it runs after Options' own timing wrapper) records each redraw's ns.perf numbers with the selected
  rule (`OnScreenRule`) and whether its editor was built (not `xuiStub`). Step 1 counts only the last redraw that built the open rule's
  editor; else "no rule-editor redraw measured yet". Step 3 (search) now has a check: the query from the rule's own search box,
  the result buttons the editor shows (its own `xuiSR1..12` options, "Tab  >  section  >  option"), the rule's open tab (status table,
  as `ns.SelectRuleTab` writes it), and an AceGUI widget labelled with one of that tab's results that is visible and inside its scroll
  frame's visible area. Rename is its own step (a sidebar row shows the name).
  INFERENCE (no API entry; AceConfigDialog is a library): every redraw goes through `AceConfigDialog:Open` (its refresh calls it by
  name; Options.lua times it there). The hook cannot be removed (game limit); it returns at once for other windows.
- reskin-switches (E2e) and chat-improved-split (D25), Xaya's rule "UI overhaul switches apply on reload": three parts each (ids kept
  for part 1; new `reskin-switches-reload`, `reskin-switches-back`, `chat-improved-split-reload`, `chat-improved-split-back`; qa kept).
  Reskin part 1 flips Enable Blizzard Reskin through its own option (`LastTree().args.reskin.args.reskinOverview.args.enable.set`,
  which saves and asks "reload now?") and checks the saved value and the question (`StaticPopup_Visible` when the game has it, else
  whether Options defined XAYAUI_RESKIN_RELOAD this session: INFERENCE, StaticPopup_Visible is FrameXML, not in docs/reference/api).
  After the /reload, part 2 reads the look against the switch part 1 recorded in its saved result (`QA.SeenNote`): chat `C.skin`
  against `C.On()` (chatDebug service), Esc menu: the `XayaUI_GameMenuPanel` frame (built on the first open while the look is on; with
  the menu open, whether it is shown) against the gameMenuSkin service's `Active()`; the character window has no service that says
  whether its look is drawn (QoL's characterReskin service only has WideOn), so the note says what to expect and she judges it (Dev
  Assist may not read another addon's ns functions: the suite's static check refuses it). What it cannot read yet ("press Esc once")
  is "not tested". Part 2 flips
  back; part 3 reads it again. Chat part 1 only saves the switches (no `C.Refresh`: nothing applied before the /reload) and records
  yours ("was: panel=1 improved=1 bar=0 collapsed=0") in its result, which part 3's last step reads to save them back. A /reload is told
  apart by a module flag that only lives until the reload. No saved key of their own (asserted).
- audit-opt-bin (FA-11 / D25, #485) and the other audit-opt walkthroughs: every step finds the test data by its tag (`qaAuditOpt`) and
  names, never by step 1's memory; a run starts by removing what earlier runs left (tagged groups, rules and the Recycle Bin items
  whose rules / groups carry the tag; audit D35: never an untagged group, even one with the same name); clean-up removes tagged bin
  items instead of "everything not in the bin before" (lost on a /reload). Step 2 says Profiles > Recycle Bin.
- Stale menu paths fixed (checked against XayaUI_Options/Options.lua: Recycle Bin is a sub-tab of Profiles, Options 0.6.72 l. 5129 /
  4023; Backups are under Profiles > Export, l. 3905; Settings > UI Options > Rule Creation / Theme, l. 5365; the ignore click is QoL >
  Improved Chat > Filters > Quick ignore, XayaUI_Chat/Options.lua l. 295 / 307; no toolbar): audit-opt-bin steps 1-2, audit-opt-load
  step 2, audit-bin-words, audit-backup-replace, audit-chat, ui-switch-hovers, ui-theme-advanced; the old reskin-switches text (a box on
  the tab button, removed in Options 0.6.55); and in open QA-CHECKLIST items B30, B131, B223, B226, B262, B264, B278 (their generated
  walkthrough steps follow).

## B6: vacuous passes found (grep of every walkthrough check for an unconditional `return true` and for empty loops)
Fixed:
- audit-engine step 1 (D28): box ticked returned Pass -> not tested (nil). Step 2: `check = return true, "by eye"` removed (noVerdict).
- audit-chat step 2 (D31): "nothing to give back" returned Pass -> not tested (nil).
- perf-other-errors (J22): 0 other addons' errors returned Pass -> not tested (nil).
- audit-tooltips-aura-off step 1 (D52): 0 lookups with no hover returned Pass -> counts spell / item hovers (post-hook on
  Enhanced Tooltips' `TT.OnIDData`, looked up by name on every hover); no hover -> not tested.
- externals-combat step 4 (J26): "nothing learned is fine" returned Pass whatever it found -> noVerdict (data capture).
- audit-notepad-format step 5: zero format-bar buttons read as "all 0 buttons" Pass -> Fail.
- audit-spelling step 1: zero texts read -> not tested. ui-short-hovers: zero hover texts -> Fail. chat-fade-controls steps 1-2: no icon
  found -> Fail.
- bars-cues step 4 (above).
Legitimate (left): every `return true, data` inside a `noVerdict` step (no Accept is offered: audit-shopping-list 2, audit-shopping-ah,
audit-notepad-share 2, audit-notepad-restore, audit-talents-init 2, audit-bin-words 1, chat-fade-controls question, shopping-list 4,
mover-session 3, audit-opt-inputs 3); nameplates-target-colour "off: nothing shown, nothing listening" (it tests the off state after
switching it off); perf-log-gate "nothing reads the rule log" (the readers list is the thing tested); auto-generate filter "all" (any
listed kind fits the filter); externals-combat step 1 (its expectation is the listing itself, after "no aura rule" fails);
nameplates-blizzard-options last step (Put back reported by the feature).

## Text (#486)
- audit-engine: "Combat tracking: hidden buffs are not guessed when that box is off; a glow stops when its rule is deleted; errors show
  in /xui report (D28, D56, D57)".
- audit-shopping-list: "Shopping List: each character keeps its own defaults; Forget clears what it used; To buy adds amounts up; /xui
  shop does not switch it on (FA-7, D13-D15)".
- The other 8 Baseline titles checked: no comma splice (their commas join a list or an "and" clause). Part titles for the two split
  walkthroughs: "(part 1 of 3)" placed before the trailing code group so the codes still go to the Codes column.

## New walkthrough (V22) and QA step
- J33: "Walkthrough runner: Do it for me first, Done steps, Skipped and the Done page" in three parts (`qa-runner-nav`,
  `qa-runner-skip`, `qa-runner-nav-2`, QAWalks-review.lua, prefill): part 1 step 1 records Pass's state and the check line when Do it
  for me is pressed (greyed / "Do it for me first") and that it was opened from a list with part 2 next; step 2 (Done) reads the
  buttons; part 3 reads `QA.lastNext` (memory only), part 1's recorded D, part 2's Skipped status, and the list's kept search.
- QA-CHECKLIST: J33 added; notes appended to E2e, D25, J31; stale paths above. `python3 tools/qa_walks_from_checklist.py` run.

## V4 scope
- Runner callers of `QA.Start`: QATable onOpen (list), QAReview `RV.OpenWalk` (review), Run again, Next; tests call it directly.
- `QA.Answer` / `QA.Accept` / `QA.DoSetup` / `QA.RunCheck`: QAWalk.lua only, tests. `QA.StatusText`: QAReview `RV.Verdict`.
- `TB.Status` readers: `TB.Entry` (status column, chips, sort). `QA.ImportCode` pattern (P/F/S -> P/F/S/D).
- Walkthrough step fields read by the runner: text, setup, check, noVerdict, done (new), key.
- Files: QAWalk.lua, QATable.lua, QAReview.lua, QAWalks.lua, QAWalks-bars.lua, QAWalks-perf.lua, QAWalks-chat.lua,
  QAWalks-audit-options.lua, QAWalks-audit.lua, QAWalks-audit-qol-bonus.lua, QAWalks-display.lua, QAWalks-externals.lua,
  QAWalks-review.lua, QAWalks-profiles.lua, QAWalks-statcalc.lua, QAWalks-reskin.lua, QAWalks-debug.lua, QAWalks-friends.lua,
  QAWalks-generate.lua, QAWalks-nameplates.lua, QAWalks-Checklist.lua (generated), XayaUI_DevAssist.toc.

## Tests (V1: each new check fails on Dev Assist 0.7.52; run against a worktree of d5598ae with the new tests copied in)
- New `tests/qa_runner_run.py` (A1-A6, J33 played through, no new saved key): old code fails at the first check (no `QA.NextId`).
- New `tests/qa_walks_reload_run.py` (four real sessions with logout / saved files / login): old code has no parts.
- Extended: qa_walk_run (gating, Done, summary, export D), qa_table_run (Skipped), qa_walks_bars_run (step 4 no type, 8 noVerdict, 9
  sidebar rows, stale row, window closed), qa_perf_walks_run (J31 1/3/4, J22 none), qa_walks_audit_options_run (#485 leftovers,
  reload, tags, stale paths), qa_walk_audit_run (B6), audit_qol_bonus_run (D52 hovers), qa_walks_chat_run (split part 1, gating,
  no icon), qa_walks_display_run (no hover text), externals_in_combat_run (step 4 noVerdict). Each new assertion failed on the old
  code (one test index was corrected after the negative run showed it passing for the wrong step).

UNTESTED IN GAME.
