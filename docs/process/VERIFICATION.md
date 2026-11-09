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
- **V18 What's new for every new feature** (Xaya, 2026-11-06): "After you finish implementing all current and outstanding character pane changes, please issue a “what’s new” itemized description summary for this feature. Any new feature implemented in the last 24h should also receive this type of blurb"; "Push that specifically to a new session called “feature update summary” to keep the context contained"; "Have all other sessions for their new features do the same. That’s the only thing that new session should be used for." Every session that lands a new feature (or a user-visible change to one) sends the "feature update summary" session (session_014bN6tU26cuzQ9LarKYhZQx; docs/WHATS-NEW.md on branch `claude/feature-update-summary`) an itemized what's-new for it: what the player sees, where to find it (commands, settings), what is not yet tested in game, and the landing commit. Only after it is on `main`. That session is used for nothing else.
- **V19 Ask through the question flow** (Xaya, 2026-11-06): "standing rule for the project: wherever possible, ask me questions through the question flow rather than in a long list". Questions for her go through the question tool (AskUserQuestion: up to 4 questions per call, 2-4 options each, a recommended option first), not as a numbered list in a reply. A list in prose only where the tool cannot carry the question (then say why).
- **V20 In-game QA walkthroughs** (Xaya, 2026-11-06, given in S3's session, relayed verbatim by S3): "For all things you need me to debug or QA in game — wherever possible, design and implement a test script or walkthrough that fires in the game side so it removes all friction for a less technical friend. All they should have to do is open up /xui dev qa and pick an item and have the addon walk them through steps with as limited console interaction as possible". Every QA step that needs the game gets a walkthrough registered with core's shared framework (S3: `/xui dev qa`, `ns.RegisterQAWalk`; one framework, no second one): one step at a time, automatic checks where the addon can read the result, results saved and copyable. QA-CHECKLIST text stays as the written record.
- **V21 Issue labels** (Xaya, 2026-11-06, given in S3's session, relayed verbatim by S3): "creating a standing rule for future issue logging that issues get filed under what type of bug issue they are (ux, ui), what feature or element, if it impacts function, performance, or is a graphical error, etc"; label set: "1 but expand beyond ux ui and use other terms when applicable". Every issue filed or edited carries `type:` (ui, ux, logic, data, compat), `area:<feature>` and `impact:` (function, performance, graphical, crash, saved-data) labels on top of the existing ones. Full list: SKILL.md "Issue labels" (S3, branch claude/cool-ramanujan-ewx8e5 88539fe).
- **V22 QA walkthrough for every change** (Xaya, 2026-11-07, her words): "As a standing rule, make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing". Every new feature, significant change or bug fix lands with a hand-written walkthrough (`XayaUI_DevAssist/QAWalks-<area>.lua`, `XayaUI_DevQA.Register`). Where the addon can read the result, the check returns a verdict and the walkthrough sets `prefill = true` (an "Accept: Pass / Fail" button, recorded only on her click; QAWalk.lua, Dev Assist 0.7.10). Where it cannot judge, the check captures what it reads into the note and the step asks her; a question for her is `noVerdict = true`. Her landing instruction the same day: "merge whatever's missing from main that still lands cleanly and has qa test scripting for in game confirmation prompting available".
- **V24 (GOLDEN RULE for the entire project, her words #61) Built for a real player in a live game** (Xaya, 2026-11-08, her words, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #60): "I want you to build everything safely. I want you to build everything sensibly. I want you to design your code like it's going into a playable video game run by a real human and not like you want the fastest way to get the result. NOTHING should be done without considering human application and feasibility within the scope of a real life human interacting with a live videogame with extensive memory and cpu drain." Every design, build and review answers, in writing (debug log): what the player is doing while this runs (combat, raids, typing, moving, taking screenshots); what it takes from them (keys, mouse, focus, frames above theirs) and how it gives it back in and out of combat; its cost per frame / per event / per login in CPU and memory, with the busiest real case (a raid, 300+ rules, auras changing every frame); what happens with other addons loaded, on /reload, with the feature off (V14); and the failure mode (it degrades quietly, never blocks the game). The fastest way to a passing test is not a design. Reviewers check this list.
- **V25 Her six code criteria, applied to every line of code** (Xaya, 2026-11-09, her words, REQUEST-LOG A23 SD-1): "moving forward, you are not just going to test your code in isolation, but you are always going to review any code you write against the following criteria: * is this code optimized for end-user performance while running World of Warcraft: Midnight? * is this code built and structured in a way that is optimized? * is this code built and structured in a way that is maintainable, clean, efficient, and reliably? * is this code going to break any other functionality within the game? * is this code written to be satisfactory from an end-user's UX/UI standpoint? * is this code going to work well and perform reliably without compromising a user's ability to play the game?" Every change answers all six in its debug-log entry, each with evidence, not an assertion: (1) runtime cost: what runs per frame (OnUpdate), per event and per login, with the busiest real case, and proof that nothing runs while idle or switched off (V14); (2) structure: no duplicated logic, no polling where an event exists, no per-frame table or string allocation, work cached and invalidated by event; (3) maintainability: one owner per concern, no copy-pasted paths that decide the same thing (V11), names a reader can follow; (4) game safety: no replaced Blizzard functions or methods (hooksecurefunc / post-hooks only), no protected calls or secure-frame changes in combat, no taint of Blizzard frames, no global leaks, behavior with other addons loaded and on /reload; (5) UX/UI: V23 questions answered; (6) the player keeps control: never blocks input, keys, focus or the screen, and fails quietly. Limit stated in every report: a cloud session has no game client; the test harness is a mock of the game API, so a passing suite is not proof of in-game cost, taint or behavior. Those three are claimed only from an in-game measurement or check, and until then the report marks them UNVERIFIED IN GAME.

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
  - every `tests/*_run.py` ends with a pass marker `tests/run_all.py` recognizes.
- **American spelling (FA-16 / FA-17)** (Xaya, her words: "literally every text in the addon should follow American spelling rules / Except use the spelling “grey” instead of “gray”"; reported again 2026-11-08: "once again Claude has violated my strict rules around english - american spelling"). `python3 tests/american_spelling_run.py` (part of `tests/run_all.py`) must end with `FAILS: 0`: it reads every Lua string in the addon folders (comments left out), the .toc Title / Notes, the text files shipped in the addons, PATCH-NOTES.md, WHATS-NEW, USER-GUIDE, HELP-FAQ, README-INGAME and QA-CHECKLIST, and fails on any British / Commonwealth spelling (colour, behaviour, centre, catalogue, -ise verbs, labelled, acknowledgement, ...) and on "gray" (her exception: "grey"). Write new text in American spelling; a string that must keep a British spelling (a saved-data key, a walkthrough ID, a typed command alias, her own quoted words) goes in the test's commented ALLOW list with the reason, never by weakening the word list. The in-game check is `/xui dev qa` > "American spelling in the addon's texts (FA-16)".
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
