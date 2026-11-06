# Verification process (every change to XayaUI)

Built 2026-11-04 from the defect retrospective ([`RETROSPECTIVE.md`](RETROSPECTIVE.md)). Each rule exists because reported bugs got
past without it; the retrospective names them. Goal: catch defects before a tester does, without relying on comparing against
another addon.

## Before writing code
- **V3 Real data first.** For a reported bug, load the reporter's export or saved data into a test and reproduce the failure before
  fixing it. Keep that test. A converter's output goes through import and the editor in a test.
- **V4 List the scope.** Before changing or removing anything, `git grep` every reader, caller, display kind, trigger type, widget type
  and install path it touches. Write the list in the debug-log entry. Removing a control: list every use it served first.
- **V2 API facts in full.** For every game call: quote the 12.1.5 documentation entry in full (`docs/reference/api/`), including its
  secrecy flags and every documented edge case, and look at how Blizzard's own UI code calls it. Anything not documented is marked
  INFERENCE in the code comment and the debug log, and the code fails safe (unknown, never a guess).
- **V12 Decisions.** A design question goes to the decision list (ROADMAP / AURA-PLAN "Decisions only Xaya can make"), not into code
  or a defect issue. When Xaya answers, check the code against the answer (D1 was answered but the code still returns 0).
- **V9 Rebuild carry-over.** Before rewriting a file or feature from scratch, list its earlier fixes (`git log --follow`, the debug log,
  issue numbers in comments) and keep a test for each.
- **V14 Off costs nothing** (Xaya, 2026-11-05, her words: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to performance cost / demand in any way -- make this a standing rule for all current and future feature / element builds"). For every feature or element with an on/off tick box: while
  it is off, nothing of it is created or runs: no frame, event registration, OnUpdate, ticker or timer, hook, secure hook or
  per-frame / per-event work, and no data built for it. Create those only when it is turned on (or at login when it is saved on),
  and on turning off, hide, unregister and stop them. Two limits the game sets (state them, never hide them): (1) every Lua file of an
  ENABLED addon is read at login, so code in an always-loaded addon still costs its parse and function definitions; "never loads" in
  the strict sense needs a separate LoadOnDemand addon (as XayaUI_Options is) — say which level a feature reaches; (2) the game has
  no way to remove a hooksecurefunc / HookScript hook, so a hook placed while the feature was on stays until /reload: it must return
  at once when the feature is off, and the switch's text says a /reload removes it fully. Test it (V1): with the switch off at login,
  assert no frame of the feature exists, no event of it is registered, no OnUpdate / timer of it runs.

- **V15 Request log** (Xaya, 2026-11-05): "set as your standing rule for ALL instances (current and future) that any time I make a comment, append it to a running log of tasks you MUST solve for. Nothing I submit to you unless otherwise explicitly retracted should EVER be dropped or ignored." Before any work in a session, read `docs/process/REQUEST-LOG.md`; append every
  new message of hers to it (verbatim) in the same turn; when reporting, cite the log numbers closed and still open. A report
  that says "done" for an item not on `main` is wrong.
- **V16 Exact, or confirmed** (Xaya, 2026-11-05): "stop interpreting my suggestions if they appear prescriptive. reiterate them with confirmations if you are uncertain." and "do not guess and implement without providing proposals around that guess with confirmation." Her column lists, labels and layouts are built exactly; an extra
  element (a "Note" column, a "(what feeds it)" label) is a defect. Anything not specified is proposed and confirmed first.
- **V17 One landing per round** (Xaya, 2026-11-05): "all of these unless otherwise specified should have been bundled in with the core update. do a proper fix without pushing in piecemeal -- it creates more back-and-forth noise that is unnecessary"
- **V18 What's new for every new feature** (Xaya, 2026-11-06): "After you finish implementing all current and outstanding character pane changes, please issue a “what’s new” itemized description summary for this feature. Any new feature implemented in the last 24h should also receive this type of blurb"; "Push that specifically to a new session called “feature update summary” to keep the context contained"; "Have all other sessions for their new features do the same. That’s the only thing that new session should be used for." Every session that lands a new feature (or a user-visible change to one) sends the "feature update summary" session (session_014bN6tU26cuzQ9LarKYhZQx; WHATS-NEW.md on branch `claude/feature-update-summary`) an itemized what's-new for it: what the player sees, where to find it (commands, settings), what is not yet tested in game, and the landing commit. Only after it is on `main`. That session is used for nothing else.

## While writing tests
- **V1 Outcome, not input.** Assert what the player sees or hears: drawn positions, text, which sound fires, the final list order. A
  test that only checks a setting was stored or a function was called does not count. Each new test must FAIL on the old code
  (negative control); say so in the debug log.
- **V5 Parity.** Where two paths decide the same thing (engine vs XayaUI, preview vs combat, built-in trigger vs trigger row, editor
  readability line vs runtime), a test compares them.
- **V11 Layout.** For any layout change: both axes, every child inside its parent, no overlaps, text fits (estimated font width),
  strata against Blizzard dialogs.
- One test per documented edge case from V2.

## Before committing
- **V8 Static gate.** `python3 tests/lua_pitfalls_run.py` passes (catches `a and false or b`, which always yields `b`). Any global read
  or write is a failure, not a warning. A commit that deletes a large block lists what it removed in the commit message.
- **V10 `python3 tools/precheck.py`** passes. It checks:
  - debug-log names and "Logged" times are not in the future;
  - `MANIFEST.md5` matches the files git tracks (rebuild it AFTER `git add`);
  - no untracked files in addon folders or at the repo root;
  - an addon whose code changed has a new `## Version` in its `.toc`;
  - QA-CHECKLIST step IDs are unique;
  - every `tests/*_run.py` ends with a pass marker `tests/run_all.py` recognises.
- Run the targeted tests, then the full suite: `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py` (no `tests/harness/api_index.json` in a cloud session: build it first with `python3 tests/harness/api_index_from_docs.py`, from the repo's own docs/reference/api/api.json; without it the harness prints "API documentation: NOT LOADED" and checks no widget method or event, so that run does not count as the full suite). If something
  must reach `main` before the full suite finishes (Xaya asks for it), say so in the commit and the reply, and report the full result
  afterwards.

## Before calling it done
- **V6 Done = on main and confirmed.** Cite the `main` commit. A fix on a branch is not done. An issue closes only after Xaya or a tester
  confirms it in game; until then it carries `unverified-in-game`. A defect whose root cause was never found stays open.
- **V7 Clean install.** Nothing may reference files that are not in the repository (art, sound lists). Tests read only `git ls-files`.
  Installing = copying the `XayaUI*` folders; nothing else is written inside the game folder.
- **V13 In-game loop.** Each fix adds a QA-CHECKLIST step: exact steps and the expected result. The reply to Xaya names the step.

## Reporting
- State what was verified and how; mark inferences; never present an unrun check as passed.
- A claim about another addon, a tool or an API is checked before it is repeated (the retrospective found claims that ran ahead of
  `main`).
