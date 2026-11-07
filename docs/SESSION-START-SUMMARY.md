# XayaUI: session-start summary

Read this first in any new chat about XayaUI. It is meant to be enough on its own; the full record is in the two trackers below.
Last updated 2026-11-05 16:45 UTC by Claude Code session 014bN6tWZxqCW85vMEyHdfnt (before that: 2026-11-04 17:15 UTC, session 014bN6tStyDJVemzE9tX7F38 (earlier the same day: 014bN6tUvbkCv9Ha9VgNF4Xa, 014bN6tVdvvFNcwwRRBHuqTv). Facts were checked in that session unless marked (unverified) or (inference).

## 1. How this project is tracked
Every piece of addon work is multi-session (Xaya, 2026-11-04). New chat: read this file, then glob the repo root and `debug-log/` for `*SUMMARY*`, `*LOGIC*`, `*CONTEXT*`, `*SESSION*`, `*handoff*` files and read the newest.

| File | Role | Update when |
|---|---|---|
| `docs/ROADMAP.md` | **Full tracker**: every feature, its status, its weakest point, open questions, parked and dropped items with reasons | a feature's status, scope, or decision changes |
| `debug-log/` | **History**: one entry per change or finding, named `YYYY-MM-DD-HHMM-topic-version.md` | every change, in the same commit |
| `docs/SESSION-START-SUMMARY.md` (this file) | **Cold start**: rules, active items, pending actions, how to work here | an active item or pending action changes; at the end of a session |
| GitHub issues | one issue per feature or defect; labels `decision-needed`, `unverified-in-game`, `roadmap`, plus `type:` / `area:` / `impact:` on every issue (Xaya 2026-11-06; the skill's "Issue labels" rule) | as work happens |
| `docs/process/VERIFICATION.md` | **How every change is checked** (rules V1-V13); `RETROSPECTIVE.md` says why each rule exists | a new kind of slip gets past |

Project documents outside the repo (Claude project docs, the Drive `Feature sketches` folder) hold long specs; ROADMAP section 13 says so. They are not readable from a cloud session.

## 2. Standing rules
- **Request log: nothing is ever dropped** (Xaya, 2026-11-05 23:5x UTC, her words): "set as your standing rule for ALL instances (current and future) that any time I make a comment, append it to a running log of tasks you MUST solve for. Nothing I submit to you unless otherwise explicitly retracted should EVER be dropped or ignored." Every message from Xaya (each
  request, correction, answer, screenshot description) is appended to `docs/process/REQUEST-LOG.md` in the same session turn, with
  her words verbatim, a status (open / needs her confirmation / built on branch X / on main at commit Y / done in game) and where it
  lives. Read the log at session start; an item leaves "open" only when it is on `main` (or she retracts it). Also: "review every instance where I gave you a precise data display structure and do not fail to capture and implement a single instance. do this across all chats."
- **Prescriptive means exact** (Xaya, 2026-11-05, her words): "stop interpreting my suggestions if they appear prescriptive. reiterate them with confirmations if you are uncertain." A precise layout, column list, label or wording she gives is built
  exactly as given: no extra columns, notes, labels or renames. Where her words leave something open, restate it and ask.
- **No guessing without a confirmed proposal** (Xaya, 2026-11-05, her words): "do not guess and implement without providing proposals around that guess with confirmation." A choice she did not make (a size, a default,
  a placement, a reading of an ambiguous sentence) is proposed to her with the options and waits for her answer before it is built.
  The only exceptions are invisible implementation details (code structure, variable names, test layout).
- **One bundled landing, no piecemeal pushes** (Xaya, 2026-11-05, her words): "all of these unless otherwise specified should have been bundled in with the core update. do a proper fix without pushing in piecemeal -- it creates more back-and-forth noise that is unnecessary" Collect the work for a round of her requests on
  the branch, run the full suite once on the bundle, and land it on `main` once, with one report listing every request it closes
  (by REQUEST-LOG number) and every one still open. Coordinate with any other active session so there is one combined push.
- **What's new for every new feature** (Xaya, 2026-11-06, V18): when a new feature (or a visible change) lands on `main`, send the "feature update summary" session (session_014bN6tU26cuzQ9LarKYhZQx) an itemized what's-new: what the player sees, where to find it, what is untested in game, the landing commit. That session is used only for this.
- **Tell the performance-test session about every code change** (Xaya, 2026-11-06, her words: "Make sure all active sessions communicate any code updates they make so the session designing the test can appropriately account for testing changes it might need to make"; REQUEST-LOG CLEAN-8). After each commit that changes addon code (any `XayaUI*` folder, not docs only), send the performance-test session ("XayaUI: performance test (M+ first)", session_014bN6tTxYo6enpkMGsVkMqm; CLEAN-7) one short note: branch and commit, addon and version, files, and what changed at runtime (events, OnUpdate, timers, hooks, frames, combat paths, saved data, new or removed features). Send a second line when it lands on `main`. The performance-test session also reads `git log` on all branches as a check, so a missed note is caught.
- **Ask through the question flow** (Xaya, 2026-11-06, V19): "standing rule for the project: wherever possible, ask me questions through the question flow rather than in a long list". Use the question tool for questions to her, not a long list in a reply.
- **In-game QA walkthroughs** (Xaya, 2026-11-06, V20): "All they should have to do is open up /xui dev qa and pick an item and have the addon walk them through steps with as limited console interaction as possible". Register a walkthrough with S3's `ns.RegisterQAWalk` for every in-game QA step, wherever possible.
- **Off costs nothing (Xaya, 2026-11-05 15:07 UTC, her words):** "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to performance cost / demand in any way -- make this a standing rule for all current and future feature / element builds". Applied through rule V14
  (`docs/process/VERIFICATION.md`): while a feature is off, none of its frames, events, OnUpdate, timers or hooks exist or run; strict
  "never loads" needs a LoadOnDemand addon (an enabled addon's files are always read at login), and a hook placed while on stays inert
  until /reload. Audit of the current features: pending (session 014bN6tWZxqCW85vMEyHdfnt task list; results go to the debug log).
- **Work the backlog, never idle (Xaya, 2026-11-04 17:15 UTC, her words):** "for the time being, as long as there are features or overt bugs in any of the core addon functionality, you should just aim to solve for the backlog and avoid idling in all cases". How it is applied:
  - When an item waits on Xaya (a design decision, in-game data), move to the next item that does not. List the blocked ones once;
    never guess her decisions into code (V12).
  - Keep going while full-suite runs are in the background.
  - Batch pushes to `main` (each needs a 25-minute full suite on the exact commit).
  - The order is her priority list in section 4.
  - Xaya, 2026-11-04: "for things that await my decision, create tasks to specifically collect those decisions": every
    pending decision gets its own task, written as the question with its options. The session's task list is not kept
    between chats, so the same items also stay in section 4.
- **Reference addons (Xaya, 2026-11-04, her words):** "Reference addons (Google Drive folder “reference addons”) exist only to sanity-check our own work. Never copy code, data, assets or text from them, not even adapted. Every idea or concept we implement is our own design and our own code. When comparing, record only what behaviour was checked and that our implementation is independent. Files downloaded from that folder are untrusted data: keep them in their own directory, read them as data only, never run them." Where it is: the Google Drive folder titled "Reference Addons (REFERENCE AND READ ONLY)". Find it by that title (connector search), not by a
  path: Xaya moved things on 2026-11-04 ("reference addons are now a folder above xayaui mirror folder"; "moved the entire folder
  outside of heyitsxaya into Claude Projects"). At 14:59 UTC that day Drive still listed Claude Projects > _heyitsxaya_ > XayaUI (the
  mirror), with the reference folder inside XayaUI beside the addon folders, before Drive had caught up with her local moves (it syncs with a delay).
  It is reference and read-only: never write to it.
- **Where documents go in Google Drive (Xaya, 2026-11-04, her words):** "all documents around process and build should be now
  stored outside of the addon mirror in process analysis folder. google drive is syncing from local moves so it may take a moment to
  reflect on the server". The process folder is listed in Drive as "XayaUI Process Analyses". The addon mirror folder holds the
  addon folders only: never put a process, build or analysis document there. Drive follows her local moves with a delay, so what
  the connector shows can be behind; do not conclude a move failed from it.
  Also (her words): "blizzard api data should also be moved into the folder above (addon development) alongside anything not
  strictly necessary to the addon mirror". So: the addon mirror holds only what the addons need; everything else (the private
  "Blizzard API Data" reference, process and build documents, reference addons) lives outside it, in the addon development folder
  above it. Find folders by their titles; Xaya moves them locally and Drive catches up later.
- **`main`:** pushing is authorized whenever the checks pass (full suite on the exact commit + `precheck --base origin/main`);
  every push is announced with its commit.
- **Data:** no code or data copied from another addon (#290). Class, spell, and item data is learned from the game at runtime where the game gives it. Numbers from a credible public database (for example Wowhead) are allowed when the source is named next to them.
- **Never invent numbers.** A value that cannot be read or sourced is shown as unavailable or "not given by the game".
- **Midnight secret values:** every read that can come back secret is pcall'd and checked with `issecretvalue`; never compare, format, or guess a secret.
- **Personal data stays local:** personal rules, lists, and anything about other players are never in a default export.
- **Options style:** a dropdown never takes a row alone; short labels; the explanation goes in the tooltip. Settings layout: a feature is a node in the left pane, its parts are child nodes, and a part's sections are tabs (`ns.SectionTabs`).
- **Feature addons never get called by name from core:** they register through `XayaUI/Modules.lua` (`ns.WhenReady`, `ns.RegisterSettingsPage`, `ns.RegisterCommand`, `ns.RegisterLauncher`).
- **"Profile"** (Xaya, 2026-11-06, REQUEST-LOG UI-26 / UI-27, her words: "profiles is expanded as a category bucket to include all user-created customizations, settings, etc"; "individual components can be selected to toggle (review EUI and ElvUI profiling)"): a profile covers every user-created customization and setting (rules, groups, themes, settings, the whole addon), and import / export lets you tick which components to include. Before 2026-11-06 it meant only the whole addon as configured (#354).
- **Wording to Xaya:** truth first; flag inferences; no unearned compliments; state what is not verified in game.
- **Roadmap feature branches (Xaya, 2026-11-05, her words):** "Rough scaffolding and proposed code structure (outline only) in a
  dedicated “roadmap features: ______” brand per feature"; then "Branch, not brand". Applied as:
  - **one branch for all roadmap features**, `roadmap-features/combined` (Xaya, 2026-11-06, her words: "Combine them into one
    roadmap on one branch — the other branches get marked as stale if no code is on them"; draft PR #429). Before that it was one
    branch per feature (games, rppm, layout-profiles); those three are stale (PRs #397, #398, #421 closed);
  - each scaffold sits in its own folder `roadmap-features/<feature>/` on that branch (never a top-level `XayaUI*` folder, which the
    tools treat as shipping); `roadmap-features/README.md` indexes them; a new feature adds a folder, not a branch;
  - comments only, no code that runs; the branch is not for merging.
  Its detail is read only when that feature's work starts; it is not repeated here.

## 3. Addons (versions from the .toc files on `main` a859028, 2026-11-05 16:45 UTC)
| Folder | Version | Holds |
|---|---|---|
| `XayaUI` | 0.6.46 | core: rules, cues, conditions (incl. load by zone / instance / difficulty / size / encounter / item), actions, combat aura engine (`Combat/`), themes, mover view, console and debug record, minimap and ESC-menu buttons |
| `XayaUI_Options` | 0.6.40 | the settings window (loads on first open; Ace3 libs) |
| `XayaUI_Chat` | 0.6.14 | Chat Panel, Chat Bar, filters, history, tab sounds and whisper sound overrides, privacy cover |
| `XayaUI_QoL` | 0.7.18 | Cursor Highlight, Gradient Cursor Trail, Character Toolkit / Stat Calculator panel (one model; Sheet, Stats, Gear with icons, What If with the armor chain, Spells with All / Offense / Defense filters; slot overlays with this expansion's enchant slots by default) |
| `XayaUI_Bonus` | 0.6.11 | tooltips, data panels, Utilities (Notepad, Calculator `/xui calc`) |
| `XayaUI_Reskin` | 0.6.1 | Game Menu skin |
| `XayaUI_Media`, `XayaUI_DevAssist` | 1.0, 0.7.2 | user media folder; XayaUI Dev Assist, the developer tool (was `XayaUI_GameDump` before 0.7.0): API, talents, Cooldown Manager catalogue, aura log, `/xuidev probe` (`/xuidump` still works) |
Saved settings: one account-wide table, `CueRulesDB` (QoL parts use `CueRulesDB.cursorHighlight`, `.cursorTrail`, `.characterToolkit`). Nothing is saved per character yet.

## 4. Active items

**Update 2026-11-05 20:25 UTC (session 014bN6tSuhd4nhS3kubHR58K, branch `claude/admiring-ride-sm7jrh`, draft PR #406):** Xaya answered
(debug-log 2026-11-05-2018 and -2022): RM-BARS and disabled rules: check WeakAuras (done: bars are their own display kind there;
unloaded-aura cost NOT verified, the file was too large for the Drive tool); terms 3b: option a + a database we maintain, as a future
enhancement with the other third-party data items; #372 Config tab = folder name, folder type, original character / source, enable
switch; Group tab = WeakAuras' group options; "DO NOT RELEASE" and a durability / broken-gear reminder become **pre-created rules** (Xaya: "rule templates is a bit of a misnomer"; ready-made rules a player switches on);
chat history: "All" is not the default tab, and whisper windows get their own tabs (Blizzard's New Whispers setting or an addon switch).
Stat Calculator: QoL 0.7.21 built (450 wide, Rating "528 +172"; QA E1z21); all ability lists stay nested. Next free: QoL 0.7.22.

**NEXT SESSION: START HERE (updated 2026-11-05 16:45 UTC, session 014bN6tWZxqCW85vMEyHdfnt)**
`main` = `a859028` or later. Landed today (all full-suite green WITH the API index; none run in game yet):
- core 0.6.45-0.6.46 / Options 0.6.39: console switches without the full options-tree rebuild (B115), version text = Addon Info link in
  theme colors (B116), compact Rules sub-tabs (B117), `/xui help` one command per line (B130), `C_Texture` guard (harness was red on main).
- QoL 0.7.15 Stat Calculator columns (E1z8); core 0.6.46 / QoL 0.7.17 cursor trail presets as UI themes + "Match the UI theme" (B118,
  B119, E1z9, E1z10); Chat 0.6.14 off costs nothing (D6-D10); Options 0.6.40 / QoL 0.7.18 / Bonus 0.6.11 on/off tick boxes in the
  QoL and Bonus left panes, Bonus > Utilities (Calculator, Notepad), talent scan in Settings > UI Options > Rule Creation (B131, E3, F7, F8).
- New standing rule V14 (off costs nothing, section 2). Cloud sessions: build the API index first (section 6).
Running when this was written (worktree agents; results land as merges on the session branch, then `main` after the full suite):
core / Reskin V14 fixes (core 0.6.47, Reskin 0.6.2, QA B140+); character pane fix (QoL 0.7.19, E1z11+: one item level per slot,
enchant lines wrapped, XayaUI's own gem sockets / socketed gems). V14 audit of every feature: scratchpad report summarised in the
debug log of the Chat 0.6.14 entry; still to fix: Options driver after the window closes, Bonus (Notepad share pump, Data Panels
driver, hidden Notepad, tooltip post-calls), QoL Character Reskin / Toolkit off in a session, Drafts copy with drafts off.
Decisions waiting on Xaya (asked 2026-11-05): disabled rules cost nothing?; "DO NOT RELEASE" (QoL click-blocking cover recommended,
or a warning rule template, or both); chat history "should not show except for on the last tab" (3 readings offered); Stat Calculator
(Spells tab columns, rating Pt value form, #382 controls, note column width); cursor themes (Frost / Gold label colors; label and Add
button tinting); tick boxes (Tooltips' four switches, Tooltip lines row, Notepad's box meaning, Utilities order, Reskin tab);
`/xui chat whispers` counters always on with the panel?. Known defect: chat privacy cover defaults never merged on a fresh install.
Next free numbers after the running agents: core 0.6.48, Options 0.6.41, QoL 0.7.20, Bonus 0.6.12, Chat 0.6.15, Reskin 0.6.3;
QA B132-B139 (B140+ for the core V14 agent), E1z12+, D11, F9.

(Previous handoff:) **NEXT SESSION: START HERE (updated 2026-11-04 22:46 UTC)**
`main` = `8d81e3f` or later (check `git log origin/main`). Everything this session built is on it, nothing is pending on the branch:
- Stat Calculator: Spells auto-fill + Offense / Defense filters (QoL 0.7.7, QA E1t), armor chain (0.7.8, E1u), Gear icons (0.7.9,
  E1v), "Spell ID: N" and readable spell lines (0.7.11, #378 #380, E1w), `/xui stats widthprobe` (0.7.12, E1x: the in-game test
  before the wider character window; task 46).
- #351 phase 2: `ns.UI_MARGIN` / `ns.UI_GUTTER` in core `XayaUI/Modules.lua`; console, copy box, Import window, toolkit panel,
  chat history, notepad and its popups, mover popups (B76-B80; `tests/window_margins_run.py`).
- Core 0.6.38: Actions > "Speak it" was silent (B81). Core 0.6.39: the Game Menu grew on every open (Xaya's live report; B82).
- Other sessions: engine core / Options 0.6.34-0.6.35; Dev Assist session: Bonus 0.6.8 (calculator, `e3cf896`), Dev Assist
  0.7.1-0.7.2 (`/xuidev instance`; the probe-log flood fix, `8d81e3f`).
Next free numbers: core 0.6.40, Options 0.6.37, QoL 0.7.13, Bonus 0.6.11, Chat 0.6.13, Dev Assist 0.7.3; QA B83, E1y, F7, J16
(engine session: B100+).
Chat 0.6.12 (session 014bN6tUJ5JTttjgNR2yaUnU, 2026-11-04 23:44 UTC): every docked tab's scroll pieces handled, the back-to-newest arrow
shown while scrolled up, the tab row's window list above the privacy button (QA D4k); whisper tabs: no cause in the code, `/xui chat
whispers` built to collect the facts (QA D4l; `debug-log/2026-11-04-2344-chat-pieces-every-tab-whispers-chat-0.6.12.md`).
Waiting on Xaya: the `/xui chat whispers` output after a whisper (D4l); task 43 (Stat Calculator questions and issues #377 #379 #381 #382 #383 #387), task 46 (the width probe in game),
the QA steps above in game.

**Open with Xaya from session 014bN6tSy3HbUDWYQsk69naX (PR #386, merged), asked 2026-11-04 evening; answers of 2026-11-06 noted per item:**
- Cursor Highlight: "right clicking mouse with the cursor shape enabled makes cursor less responsive". No cause found in the code (the
  frame takes no mouse input; one cursor read and one move per frame). Asked: which feels slow (camera turn / shape lag after release /
  clicks), which shape and style, trail on, "hide while turning" on, and whether it goes away with the shape off.
- Fiery Brand tooltip: her yes (2026-11-06); on `main` 5490478 (Bonus 0.6.13 content, QA F13). Her follow-up (2026-11-06): "only offer this if debugging mode is enabled": the "via ..." source text shows only while Advanced Debugging is on (Bonus 0.6.15, QA F16, branch `claude/inspiring-mendel-8r8qao`, for the next combined push).
- The combat-log analyser (RM-INST's "complete" part, an offline tool in `tools/`): her answer 2026-11-06 "Not now" (stays on the roadmap, not built).
- The Enchant Slots default (QoL 0.7.6): her answers 2026-11-06 "Keep legs flagged" (after the recipe check) and, on the terms question, "Slot numbers are fine". Closed.
- Deferred / dropped by her that evening: talent window labels (#388, deferred); raid role load condition (dropped).

**Three Claude sessions work in parallel (2026-11-04 evening, coordinated by send_message):**
- this one: settings window, Stat Calculator / Character Reskin plans, chat, mover view, load conditions;
- `session_014bN6tSy3HbUDWYQsk69naX` (PR #386): owns `XayaUI_DevAssist/` and QA section J, and the toolkit's Enchant Slots
  default (QoL 0.7.6, CharacterToolkit.lua / CharacterModel.lua SlotOverlay);
- one instance (Xaya, 2026-11-04 evening: "one claude instance is working on the outstanding rule and combat engine issues"; most
  likely `session_014bN6tV8wAAEXAShpTKqUfz`, told by message): rule evaluation and the combat engine (Combat/, Triggers.lua, the
  cooldown / aura reads, Fel Flame Fortification, Boiling Point, B4-B6). This session stays out of those.
- Landing rule agreed: whoever lands second merges `main` in, regenerates MANIFEST.md5 and reruns the full suite on the new head.

**Xaya's answers so far** (plan `docs/plans/STAT-CALCULATOR-REDESIGN-2026-11-04.md`):
- Q5: "a wider character viewport";
- a QoL "Character Reskin" switch (on / off);
- "track even if not known" (B6) dropped unless she wants it.
- Still open (task 43): Q1 (Stat Values: rename or compute), Q2 (reskin scope), Q4 (Gear comparison: side by side or one at a
  time), Q6 (track colours). Q3 was built with a default (only spells with numbers, plus a setting to list the rest).
- Built without her confirmation, flagged to her: the Offense / Defense filters also draw the old tabs' stat sections; spells are
  sorted into filters by English words; listed spells use spell power for Intellect specs, attack power otherwise.

Backlog in Xaya's priority order (work the first one not blocked; see the rule in section 2):
- A. **Progress bars as a display kind**: ON MAIN 28380a96 (PR #417; core 0.6.58 / Options 0.6.59 / Bonus 0.6.20, `XayaUI/BarCue.lua`,
  QA B200-B210 and F21, debug-logs 2026-11-06-0615 / -1757 / -2018 / -2306). Her answers: REQUEST-LOG section A11 (S8-1 to S8-13).
  Waits on: in-game checks (engine bars, dispel colouring, preset strengths: QA B204). XayaUI's own bar fills: roadmap RM-BARFILLS.
- B. **Spell trigger options:** B1-B3 done (count GCD, remaining / charge comparisons, lockout). Open: exact spell ID (memo key and
  charge-watcher design first), track auto / charges / cooldown, track if not known. Not blocked.
- C. **Load conditions:** done on rules (core 0.6.28) and groups (core 0.6.33). Raid role (MT / MA) dropped (Xaya, 2026-11-04:
  "that's not something we care to track").
- Done 2026-11-04 evening on the branch, after this list was first written:
  - **anchor to any frame** (core 0.6.31): group X / Y popup "Anchor to a frame on screen..." (picker: point, press Shift), Snap
    flush, Anchor to the screen; displays: Snap Target > Pick a frame on screen. QA B69.
  - **search in a rule's settings** (Options 0.6.29, `RuleSearch.lua`): above the rule's tabs (move it into the right-hand panel
    if task 23 is decided that way). QA B70.
- B4 (exact spell ID) needs a design first: the cooldown memo key (spellID, maxCharges), the charge watcher and the cast tracker
  all key by the replacement spell. B6 (track if not known) would read an unknown spell as "ready" (the game reports it inactive):
  ask Xaya whether she wants that at all before building it.
- D. **#372 group tabs** (Config tab; Group tab gets the reference screens' container properties and a background; "Group Display"
  rename reverted). BLOCKED on #372's open questions.
- E. **#351:** one margin / gutter everywhere: done offline (phase 1 settings window; phase 2 every other window). Left as they are
  on purpose: the chat container (its text inset is a user setting), menus, data panels, the Game Menu skin. Needs in-game checks
  (B75-B80).
- F. **Dev Assist in-game captures** (item 2 below): `/xuidev instance` built (0.7.1); stats, tooltips, item -> aura not built.
- G. **Fel Flame Fortification (393009):** shows out of combat, not in combat. BLOCKED on her debug record.
- H. **Boiling Point** rule does not fire with a stack-tracking trigger. BLOCKED on her rule export (procs.md: the aura does not
  stack; stacks are unknown in combat).
- Later: conditions with a "run custom code" outcome (ROADMAP RM-CODECOND); friend categories of her own for whisper sounds.
- Done 2026-11-04 evening:
  - on `main` (`f6f98cc`): Insivius's AuraSound crash (Options 0.6.24) and the lua_pitfalls gate rule; B1-B3; the chat tab guard;
  - on the branch: everything listed in the first paragraph. The group-wide "tooltip on hover" already existed: Group page > Display
    tab > "Every display: behavior".
- Other decisions waiting on Xaya:
  - task list items 13-23;
  - #268 wording (working assumption: Anchor -> Anchored To -> To <target>'s point);
  - the terms options (3b);
  - documents out of the repo (3);
  - #273 gradient themes; #131 group tint; #122 un-publish `shelved/`; #259 mockups; display glow library types;
  - DECISIONS-2026-11-04.

1. **Build the two harness indexes before any full-suite run** (both gitignored; section 6 has the steps). Without
   `framexml_index.json` the harness skips its deprecated-name check. That is how `CharacterToolkit.lua` (QoL 0.7.0) named the
   fallback-only global `ChatEdit_InsertLink` unnoticed; fixed in QoL 0.7.1 / core 0.6.23 through `Compat.lua`.
2. **In-game captures for the data pulls** (Xaya's list, 2026-11-04). The offline part is done: `docs/reference/content/` (see
   `debug-log/2026-11-04-1523-content-data-pulls-offline.md`).
   - **Status 2026-11-04 22:45 UTC (session 014bN6tSy3HbUDWYQsk69naX, PR #386):** on `main` 8d81e3f:
     - `/xuidev instance` (Dev Assist 0.7.1, QA J13-J14), built on the probe's enemy reads; it collects while `/xuidev probe` is on.
     - Proc-art hides with no spell ID are counted, not logged (0.7.2, QA J15): in Xaya's open-world probe upload (2026-11-04
       11:23-17:09) 21,685 of them had pushed 22,811 entries out of the 6,000 kept.
     - Not built: `/xuidev stats`, `/xuidev tooltips` (the sub-agent was stopped), item -> aura confirmation.
     - Upload findings (`debug-log/2026-11-04-2218-probe-findings-oh-flood-devassist-0.7.2.md`): mob identity readable in open-world
       combat (188 of 188); own casts and glow IDs readable in combat; UNIT_AURA payload secret in combat; no enemy casts seen;
       Fiery Brand 207771 vs 207744 still unsettled; Fel Flame Fortification (393009) filed under Immolation Aura, out of combat only.
   - **Build in Dev Assist,** each capture marking every read the game hides:
     - `/xuidev instance`: per creature seen on nameplates, target or boss units: ID, name, classification, Mythic+ count; the
       spells it casts and the auras on it when readable; the encounter and instance IDs.
     - `/xuidev stats`: ratings and their percent conversion, out of combat.
     - `/xuidev tooltips`: tooltip lines for the spells, auras and items XayaUI's rules use. This is Blizzard text: it stays in the
       player's saved file, never in the repo.
     - Item -> aura confirmation through the existing cast recorder.
     - Spell scaling already exists: `/xuiformula`, kept per talent loadout, fitted by `tools/formula_fit.py`.
   - **Design note (read before building `/xuidev instance`):** the event probe (`Probe.lua`) already logs nameplate adds and
     enemy casts (codes NA, CS, CC, CL, CI, CT) and reads each mob's `UnitCreatureID`, scrubbed `UnitGUID` and
     `UnitClassification` (Probe.lua:694-713), with its secrecy handling. Still missing: the per-unit Mythic+ count
     (`GetUnitCriteriaProgressValues`), auras on enemies, and a per-creature summary (creature ID -> name, classification,
     count, spells seen cast, auras seen). Building the capture on the probe's mob reads avoids a second recorder (INFERENCE
     from reading the code, not yet designed in detail).
   - **Which season is live** (Xaya, 2026-11-04: "the adventure journal in game will tell you what dungeons are in the current
     season rotation"): `C_ChallengeMode.GetMapTable()` gives the rotation's challenge-mode IDs, and `/xuidev catalogue` already
     saves it (`AuraCatalogue.lua:201`). Add `C_MythicPlus.GetCurrentSeasonValues()` (displaySeasonID; INFERENCE: the same number
     as the client table's DisplaySeasonID), then mark the live season in `instances.json`. Keep both seasons listed.
   - **They settle what the client data cannot:**
     - creature names: only 2 of the 391 enemy-forces rows have one;
     - which creatures cast what;
     - which of a dungeon's two enemy-forces trees the game uses (Kings' Rest 608 / 286, Temple of Sethraliss 687 / 264, Seat of
       the Triumvirate 568 / 329): the one whose total `C_ScenarioInfo.GetCriteriaInfo` shows;
     - where an item's aura really lands;
     - whether `ENCOUNTER_START`'s encounterID is `DungeonEncounter.ID`.
   - **API facts already looked up** (`docs/reference/api`, by session 014bN6tUvbkCv9Ha9VgNF4Xa):
     - `C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)` gives the count per unit (SecretWhenUnitIdentityRestricted);
       `GetCriteriaInfo` gives the total.
     - `UnitCreatureID` and `UnitGUID`: SecretWhenUnitIdentityRestricted.
     - `UNIT_SPELLCAST_*`: SecretWhenUnitSpellCastRestricted.
     - `COMBAT_LOG_EVENT_UNFILTERED`: HasRestrictions; `CombatLogGetCurrentEventInfo` is not in the reference.
     - Stats: `GetCombatRating` / `GetCombatRatingBonus` are SecretWhenUnitStatsRestricted; `GetCombatRatingBonusForCombatRatingValue`
       has no stats flag.
     - `C_TooltipInfo.*`: MayReturnNothing; the aura variants are SecretWhenUnitAuraRestricted.
   - **Then:** tests that fail on the old code, USER-GUIDE 12.13, QA steps, a debug-log entry, versions, the full suite, `main`.
3. **Open with Xaya** (asked 2026-11-04, not answered yet): which Claude-written documents should leave the repo. The options were:
   - narrative out, core stays (recommended): debug-log/, docs/process and docs/plans go to Drive's process analysis folder;
     summary, change skill and VERIFICATION stay;
   - only `Claude outputs/` (done in `4af5571`, on `main` as `89409b4`);
   - everything.

   Until she answers, keep writing debug-log entries as the process requires.
3b. **Open with Xaya: the terms question** (asked 2026-11-04; `debug-log/2026-11-04-1550-terms-check-blizzard-wago.md`). No written
   permission exists for files built from client data. Options, her call:
   - keep the shipped addon free of such data (`ProcGlows.lua`, `SetBonusAuras.lua` built from in-game reads instead);
   - keep `docs/reference/` as it is;
   - ask Blizzard;
   - ask the wago.tools operator.
   Until she answers, do not add new client-table data to shipped addon files.
4. **Waiting on the game:** Advanced Debugging QA B50-B57; Character Toolkit QA E1d-E1o (E1o: shift-click with the deprecation
   fallbacks off).
5. "Task #38" in the previous handoff was that session's own task number. GitHub issue #38 is an unrelated, closed sound-preview
   issue.

| Item | State | Next step |
|---|---|---|
| **Xaya's decisions** | written out in `docs/process/DECISIONS-2026-11-04.md` (27 questions from the 2026-11-04 issue triage); #260, #319 and part of #334 answered and built (0.6.18, 0.6.19) | still open: #343 which drag, #334 for sound files, decision 5 (switched-off condition and its cues), the WA-layout questions |
| Tier sets and glows in aura tracking (core 0.6.20-0.6.21) | built in: 18 set-only auras read missing while their bonus is off (`XayaUI/SetBonusAuras.lua`, generated by `docs/reference/build_set_auras.py`); every aura trigger shows its glow state | only 18 of 169 current bonus spells link an aura in the game data (Divine Arbiter is not one); QA B52 |
| Advanced Debugging (core 0.6.20-0.6.22) | records automatically to `CueRulesDB.debugRecord` in 11 switchable categories (cost shown per switch); trigger detail for chosen rules; game state, perf; "What to send" path boxes; messages to the console window | **unverified in game**: QA B50-B57 |
| **In-game data, 2026-11-05 morning** | `/xuidev probe` built (Dev Assist, then GameDump 0.6.0); run sheet `docs/process/IN-GAME-DATA-2026-11-05.md` | Xaya runs it; then: confirm the glow pairings, `ShouldSpellAuraBeSecret`, AddAuraSound for ordinary auras, override events |
| Retrospective aura gaps | 1, 2, 4, 6-12, 15, 22 fixed in code (core 0.6.13); 5 and 21 partly; 20 reported only; 13 left on purpose; 16 waits on Xaya | in-game QA B33-B40; then gaps 3, 14, 17-19 |
| Cues vs conditions (core 0.6.14) | a cue no condition lists follows the rule's triggers; a switched-off rule silences its cues | QA B41; Xaya may prefer that a switched-off condition frees its cues (decision 5) |
| UI bugs in existing features (Xaya: before new features) | fixed in code: #333 art picker (0.6.15), #352 lone dropdowns, #286 red buttons, #99 cut-off labels (0.6.16), #336 art rows (0.6.17) | next without a decision: #351 one margin / gutter everywhere (large); the rest wait on decisions |
| Character Toolkit (QoL 0.7.0-0.7.1) | phase 2 merged; 0.7.1 hooks shift-click through `Compat.lua`; offline tests pass, **unverified in game** | QA E1d-E1o; Toolkit questions in the decisions file |
| Content data pulls | offline part built (`docs/reference/content/`, build 12.1.5.70783): items, item spells and auras, instances with Mythic+ enemy forces, class / spec IDs | in-game captures (item 2 above) |
| Old-branch features not on `main` | #88 Recycle Bin ported (0.6.12) | #125 strata / level and the old chat features wait on decisions |
| #30 Recycle Bin for themes, notes, backups | **deferred** (Xaya, 2026-11-04) | |
| #268 9-point anchors | open, high priority | decision on "anchor" vs "anchored to" first |
Proposed order (not a commitment): ROADMAP section 12.

## 5. Pending actions for Xaya
1. **Decisions:** `docs/process/DECISIONS-2026-11-04.md`, the first five above all.
2. **In-game:** the probe run sheet (`docs/process/IN-GAME-DATA-2026-11-05.md`); QA-CHECKLIST B33-B57, J7-J11, E1d-E1n. With Advanced
   Debugging on, the debug record collects what is needed; send the bug report or the SavedVariables file.
3. **Branches** (Xaya allows deleting branches with no functionality beyond `main`; the session's git proxy refuses deletions, so
   she deletes them on github.com/heyitsxaya/XayaUI/branches). Standing on 2026-11-04 09:05:
   - **deletable:** `claude/magical-cray-jmspwv` (its Recycle Bin is on `main` since 0.6.12); `claude/eloquent-rubin-n9zb99`
     (all its commits are on `main` since 2026-11-04, cherry-picked with the same tree: `84aea1f` = `5b4db27`);
   - **keep for now:** `claude/frame-strata-conditions` (#125 strata / level, waits on a decision) and `wip/notepad-icons` (see
     `debug-log/2026-11-04-0655-old-branch-audit.md`);
   - **always keep:** `main`, `qa-installer-branch`, the session branch and `archive/2026-11-04`.
4. **`main` status:** `f6f98cc` (2026-11-04 19:05) carries core 0.6.27, Options 0.6.24, Chat 0.6.9, QoL 0.7.1, Bonus 0.6.7, Dev Assist
   0.7.0, Reskin 0.6.0. The branch's later versions (section 3) land on `main` only after the full suite passes on them; the session's
   reply says when, with the commit.

## 6. How to work here (cloud session)
- **Process:** follow `docs/process/VERIFICATION.md` (the project skill `.claude/skills/xayaui-change` sums it up). `python3 tools/precheck.py` must end with `FAILS: 0` before a commit (`--base origin/main` before pushing to main).
- **Harness indexes** (gitignored; a new container has neither, and the harness then skips its widget, event and deprecated-name
  checks). Build both from the public mirror of Blizzard's UI code, in the scratchpad:
  1. `git init`, `git remote add origin https://github.com/Gethe/wow-ui-source.git`, `git fetch --depth=30 --filter=blob:none origin live`,
     `git checkout d07eb00` ("12.1.5 (70688)", the build of Drive's `WOW-API-FULL-12.1.5.70688-*`; `297d7aa` is 70783).
  2. Concatenate `Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua` (sorted) into one `WOW-API-FULL-<anything>.txt` in its
     own folder, with a line `-- ===== FILE: <file name>` before each file. The source files have no trailing newline: add one after
     each file, or each header is glued to the previous file's last line and step 3 reports 1 file / 1 unparsed (found by session
     014bN6tUJ5JTttjgNR2yaUnU).
  3. `python3 tests/harness/build_api_index.py <that folder> tests/harness/api_index.json` (expect 622 files, 0 unparsed) and
     `python3 tests/harness/build_framexml_index.py <checkout> tests/harness/framexml_index.json` (18235 names, 232 deprecated-only).
  A full suite run then takes about 26 minutes; run it in the background on a snapshot worktree of the exact commit.
- **Tests:** `pip install lupa`, then `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py` (full) or `--quick` (no `tests/harness/api_index.json` in a cloud session: build it first with `python3 tests/harness/api_index_from_docs.py`, from the repo's own docs/reference/api/api.json; without it the harness prints "API documentation: NOT LOADED" and checks no widget method or event, so that run does not count as the full suite). On 2026-11-04 (core 0.6.11) the full suite passed: 68 groups and the whole-addon harness. Anything red is new. New feature: add `tests/<name>_run.py` (Lua 5.1 via `tests/lua51.py`); its last line must carry `FAILS: 0` or another marker `run_all.py` accepts.
- **Every change:** bump the addon's `## Version` and `## X-Date` in its .toc; add a debug-log entry; update `docs/USER-GUIDE.md` (its section 13 has the rules: describe behavior, not history); add QA-CHECKLIST lines for in-game checks; `git add` first, then `python3 tools/manifest.py` (it lists only tracked files), then commit.
- **Git:** one branch per session as assigned; push with `git push -u origin <branch>`; open a draft PR. Tag pushes and branch deletions are refused by the session's git proxy (403): do not retry; list them for Xaya. GitHub actions go through the GitHub MCP tools; `gh` only for search (`gh api -X GET search/issues -f q='repo:heyitsxaya/XayaUI is:issue ...'`).
- **Sync beyond GitHub** (local AddOns folder, Drive copy, checksums in both): described in `debug-log/2026-11-02-handoff-*.md`. Those notes predate the 0.6.0 folder layout, so check them before following them (unverified).
- **Game API facts:** check `docs/reference/` FIRST (Xaya's core reference, 2026-11-04: the live client's API with signatures and secret rules, and every class's talents and spells; the full private version with spell text is in Drive "Blizzard API Data"), then the 12.1.5 API documentation or an in-game probe (`XayaUI_DevAssist`, `/xuidev api` / `toolkit`) before relying on them; say which.

## 7. Key files
`docs/process/` (verification rules, retrospective), `tools/precheck.py`, `docs/reference/` (core reference: API, talents/spells, `charges.md`, `procs.md`), `docs/ROADMAP.md`, `docs/USER-GUIDE.md`, `docs/QA-CHECKLIST.md`, `README.md`, `MANIFEST.md5`, `debug-log/`, `XayaUI/Modules.lua` (feature contract), `XayaUI/Core.lua` (`ns.Print`, saved settings), `XayaUI_Options/Options.lua` (settings window), `tests/run_all.py`, `tests/harness/` (whole-addon harness), `tools/manifest.py`, `shelved/` (old QoL Elements, loaded by nothing).
