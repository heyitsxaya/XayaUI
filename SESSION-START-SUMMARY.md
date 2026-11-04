# XayaUI: session-start summary

Read this first in any new chat about XayaUI. It is meant to be enough on its own; the full record is in the two trackers below.
Last updated 2026-11-04 15:30 UTC by Claude Code session 014bN6tStyDJVemzE9tX7F38 (earlier the same day: 014bN6tUvbkCv9Ha9VgNF4Xa, 014bN6tVdvvFNcwwRRBHuqTv). Facts were checked in that session unless marked (unverified) or (inference).

## 1. How this project is tracked
Every piece of addon work is multi-session (Xaya, 2026-11-04). New chat: read this file, then glob the repo root and `debug-log/` for `*SUMMARY*`, `*LOGIC*`, `*CONTEXT*`, `*SESSION*`, `*handoff*` files and read the newest.

| File | Role | Update when |
|---|---|---|
| `ROADMAP.md` | **Full tracker**: every feature, its status, its weakest point, open questions, parked and dropped items with reasons | a feature's status, scope, or decision changes |
| `debug-log/` | **History**: one entry per change or finding, named `YYYY-MM-DD-HHMM-topic-version.md` | every change, in the same commit |
| `SESSION-START-SUMMARY.md` (this file) | **Cold start**: rules, active items, pending actions, how to work here | an active item or pending action changes; at the end of a session |
| GitHub issues | one issue per feature or defect; labels `decision-needed`, `unverified-in-game`, `roadmap` | as work happens |
| `docs/process/VERIFICATION.md` | **How every change is checked** (rules V1-V13); `RETROSPECTIVE.md` says why each rule exists | a new kind of slip gets past |

Project documents outside the repo (Claude project docs, the Drive `Feature sketches` folder) hold long specs; ROADMAP section 13 says so. They are not readable from a cloud session.

## 2. Standing rules
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
- **"Profile"** means only the whole addon as configured (#354 is asking whether that changes).
- **Wording to Xaya:** truth first; flag inferences; no unearned compliments; state what is not verified in game.

## 3. Addons (versions from the .toc files, 2026-11-04 15:30; `main` gets them once the full suite passes, see section 5)
| Folder | Version | Holds |
|---|---|---|
| `XayaUI` | 0.6.23 | core: rules, cues, conditions, actions, combat aura engine (`Combat/`), themes, console and debug record, minimap and ESC-menu buttons |
| `XayaUI_Options` | 0.6.18 | the settings window (loads on first open; Ace3 libs) |
| `XayaUI_Chat` | 0.6.7 | Chat Panel, Chat Bar, filters, history, privacy cover |
| `XayaUI_QoL` | 0.7.1 | Cursor Highlight, Gradient Cursor Trail, Character Toolkit (phase 2: one model, sheet, What If, slot overlays) |
| `XayaUI_Bonus` | 0.6.6 | tooltips, Notepad, data panels |
| `XayaUI_Reskin` | 0.6.0 | Game Menu skin |
| `XayaUI_Media`, `XayaUI_DevAssist` | 1.0, 0.7.0 | user media folder; XayaUI Dev Assist, the developer tool (was `XayaUI_GameDump` before 0.7.0): API, talents, Cooldown Manager catalogue, aura log, `/xuidev probe` (`/xuidump` still works) |
Saved settings: one account-wide table, `CueRulesDB` (QoL parts use `CueRulesDB.cursorHighlight`, `.cursorTrail`, `.characterToolkit`). Nothing is saved per character yet.

## 4. Active items

**NEXT SESSION: START HERE (handoff written 2026-11-04 15:30 UTC)**
1. **Build the two harness indexes before any full-suite run** (both gitignored; section 6 has the steps). Without
   `framexml_index.json` the harness skips its deprecated-name check. That is how `CharacterToolkit.lua` (QoL 0.7.0) named the
   fallback-only global `ChatEdit_InsertLink` unnoticed; fixed in QoL 0.7.1 / core 0.6.23 through `Compat.lua`.
2. **In-game captures for the data pulls** (Xaya's list, 2026-11-04). The offline part is done: `docs/reference/content/` (see
   `debug-log/2026-11-04-1523-content-data-pulls-offline.md`).
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
4. **`main` status:** core up to 0.6.23, Options 0.6.18, Chat 0.6.7, QoL 0.7.1, Dev Assist 0.7.0, Bonus 0.6.6, Reskin 0.6.0 and
   `docs/reference/content/` are on `main` (the commit that carries this line; the session reply names it).
   Later versions land on `main` only after the full suite passes on them; the session's reply says when, with the commit.

## 6. How to work here (cloud session)
- **Process:** follow `docs/process/VERIFICATION.md` (the project skill `.claude/skills/xayaui-change` sums it up). `python3 tools/precheck.py` must end with `FAILS: 0` before a commit (`--base origin/main` before pushing to main).
- **Harness indexes** (gitignored; a new container has neither, and the harness then skips its widget, event and deprecated-name
  checks). Build both from the public mirror of Blizzard's UI code, in the scratchpad:
  1. `git init`, `git remote add origin https://github.com/Gethe/wow-ui-source.git`, `git fetch --depth=30 --filter=blob:none origin live`,
     `git checkout d07eb00` ("12.1.5 (70688)", the build of Drive's `WOW-API-FULL-12.1.5.70688-*`; `297d7aa` is 70783).
  2. Concatenate `Interface/AddOns/Blizzard_APIDocumentationGenerated/*.lua` (sorted) into one `WOW-API-FULL-<anything>.txt` in its
     own folder, with a line `-- ===== FILE: <file name>` before each file.
  3. `python3 tests/harness/build_api_index.py <that folder> tests/harness/api_index.json` (expect 622 files, 0 unparsed) and
     `python3 tests/harness/build_framexml_index.py <checkout> tests/harness/framexml_index.json` (18235 names, 232 deprecated-only).
  A full suite run then takes about 26 minutes; run it in the background on a snapshot worktree of the exact commit.
- **Tests:** `pip install lupa`, then `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py` (full) or `--quick`. On 2026-11-04 (core 0.6.11) the full suite passed: 68 groups and the whole-addon harness. Anything red is new. New feature: add `tests/<name>_run.py` (Lua 5.1 via `tests/lua51.py`); its last line must carry `FAILS: 0` or another marker `run_all.py` accepts.
- **Every change:** bump the addon's `## Version` and `## X-Date` in its .toc; add a debug-log entry; update `USER-GUIDE.md` (its section 13 has the rules: describe behavior, not history); add QA-CHECKLIST lines for in-game checks; `git add` first, then `python3 tools/manifest.py` (it lists only tracked files), then commit.
- **Git:** one branch per session as assigned; push with `git push -u origin <branch>`; open a draft PR. Tag pushes and branch deletions are refused by the session's git proxy (403): do not retry; list them for Xaya. GitHub actions go through the GitHub MCP tools; `gh` only for search (`gh api -X GET search/issues -f q='repo:heyitsxaya/XayaUI is:issue ...'`).
- **Sync beyond GitHub** (local AddOns folder, Drive copy, checksums in both): described in `debug-log/2026-11-02-handoff-*.md`. Those notes predate the 0.6.0 folder layout, so check them before following them (unverified).
- **Game API facts:** check `docs/reference/` FIRST (Xaya's core reference, 2026-11-04: the live client's API with signatures and secret rules, and every class's talents and spells; the full private version with spell text is in Drive "Blizzard API Data"), then the 12.1.5 API documentation or an in-game probe (`XayaUI_DevAssist`, `/xuidev api` / `toolkit`) before relying on them; say which.

## 7. Key files
`docs/process/` (verification rules, retrospective), `tools/precheck.py`, `docs/reference/` (core reference: API, talents/spells, `charges.md`, `procs.md`), `ROADMAP.md`, `USER-GUIDE.md`, `QA-CHECKLIST.md`, `README.md`, `MANIFEST.md5`, `debug-log/`, `XayaUI/Modules.lua` (feature contract), `XayaUI/Core.lua` (`ns.Print`, saved settings), `XayaUI_Options/Options.lua` (settings window), `tests/run_all.py`, `tests/harness/` (whole-addon harness), `tools/manifest.py`, `shelved/` (old QoL Elements, loaded by nothing).
