# XayaUI: session-start summary

Read this first in any new chat about XayaUI. It is meant to be enough on its own; the full record is in the two trackers below.
Last updated 2026-11-04 14:59 UTC by Claude Code session 014bN6tUvbkCv9Ha9VgNF4Xa (earlier the same day: 014bN6tVdvvFNcwwRRBHuqTv). Facts were checked in that session unless marked (unverified) or (inference).

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
  mirror), with the reference folder inside XayaUI beside the addon folders, so the move had not shown there yet.
  It is reference and read-only: never write to it.
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

## 3. Addons (versions from the .toc files, 2026-11-04 14:46; `main` gets them once the full suite passes, see section 5)
| Folder | Version | Holds |
|---|---|---|
| `XayaUI` | 0.6.22 | core: rules, cues, conditions, actions, combat aura engine (`Combat/`), themes, console and debug record, minimap and ESC-menu buttons |
| `XayaUI_Options` | 0.6.17 | the settings window (loads on first open; Ace3 libs) |
| `XayaUI_Chat` | 0.6.7 | Chat Panel, Chat Bar, filters, history, privacy cover |
| `XayaUI_QoL` | 0.7.0 | Cursor Highlight, Gradient Cursor Trail, Character Toolkit (phase 2: one model, sheet, What If, slot overlays) |
| `XayaUI_Bonus` | 0.6.5 | tooltips, Notepad, data panels |
| `XayaUI_Reskin` | 0.6.0 | Game Menu skin |
| `XayaUI_Media`, `XayaUI_DevAssist` | 1.0, 0.7.0 | user media folder; XayaUI Dev Assist, the developer tool (was `XayaUI_GameDump` before 0.7.0): API, talents, Cooldown Manager catalogue, aura log, `/xuidev probe` (`/xuidump` still works) |
Saved settings: one account-wide table, `CueRulesDB` (QoL parts use `CueRulesDB.cursorHighlight`, `.cursorTrail`, `.characterToolkit`). Nothing is saved per character yet.

## 4. Active items
| Item | State | Next step |
|---|---|---|
| **Xaya's decisions** | written out in `docs/process/DECISIONS-2026-11-04.md` (27 questions from the 2026-11-04 issue triage); #260, #319 and part of #334 answered and built (0.6.18, 0.6.19) | still open: #343 which drag, #334 for sound files, decision 5 (switched-off condition and its cues), the WA-layout questions |
| Tier sets and glows in aura tracking (core 0.6.20-0.6.21) | built in: 18 set-only auras read missing while their bonus is off (`XayaUI/SetBonusAuras.lua`, generated by `docs/reference/build_set_auras.py`); every aura trigger shows its glow state | only 18 of 169 current bonus spells link an aura in the game data (Divine Arbiter is not one); QA B52 |
| Advanced Debugging (core 0.6.20-0.6.22) | records automatically to `CueRulesDB.debugRecord` in 11 switchable categories (cost shown per switch); trigger detail for chosen rules; game state, perf; "What to send" path boxes; messages to the console window | **unverified in game**: QA B50-B57 |
| **In-game data, 2026-11-05 morning** | `/xuidev probe` built (Dev Assist, then GameDump 0.6.0); run sheet `docs/process/IN-GAME-DATA-2026-11-05.md` | Xaya runs it; then: confirm the glow pairings, `ShouldSpellAuraBeSecret`, AddAuraSound for ordinary auras, override events |
| Retrospective aura gaps | 1, 2, 4, 6-12, 15, 22 fixed in code (core 0.6.13); 5 and 21 partly; 20 reported only; 13 left on purpose; 16 waits on Xaya | in-game QA B33-B40; then gaps 3, 14, 17-19 |
| Cues vs conditions (core 0.6.14) | a cue no condition lists follows the rule's triggers; a switched-off rule silences its cues | QA B41; Xaya may prefer that a switched-off condition frees its cues (decision 5) |
| UI bugs in existing features (Xaya: before new features) | fixed in code: #333 art picker (0.6.15), #352 lone dropdowns, #286 red buttons, #99 cut-off labels (0.6.16), #336 art rows (0.6.17) | next without a decision: #351 one margin / gutter everywhere (large); the rest wait on decisions |
| Character Toolkit (QoL 0.7.0) | phase 2 merged, offline tests pass (234 checks), **unverified in game** | QA E1d-E1n; Toolkit questions in the decisions file |
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
   - **deletable:** `claude/magical-cray-jmspwv` (its Recycle Bin is on `main` since 0.6.12);
   - **keep for now:** `claude/frame-strata-conditions` (#125 strata / level, waits on a decision) and `wip/notepad-icons` (see
     `debug-log/2026-11-04-0655-old-branch-audit.md`);
   - **always keep:** `main`, `qa-installer-branch`, the session branch and `archive/2026-11-04`.
4. **`main` status:** core up to 0.6.22, Options 0.6.17, Chat 0.6.7, QoL 0.7.0, GameDump 0.6.2, Bonus 0.6.5 are on `main` (483703a).
   Later versions land on `main` only after the full suite passes on them; the session's reply says when, with the commit.

## 6. How to work here (cloud session)
- **Process:** follow `docs/process/VERIFICATION.md` (the project skill `.claude/skills/xayaui-change` sums it up). `python3 tools/precheck.py` must end with `FAILS: 0` before a commit (`--base origin/main` before pushing to main).
- **Tests:** `pip install lupa`, then `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py` (full) or `--quick`. On 2026-11-04 (core 0.6.11) the full suite passed: 68 groups and the whole-addon harness. Anything red is new. New feature: add `tests/<name>_run.py` (Lua 5.1 via `tests/lua51.py`); its last line must carry `FAILS: 0` or another marker `run_all.py` accepts.
- **Every change:** bump the addon's `## Version` and `## X-Date` in its .toc; add a debug-log entry; update `USER-GUIDE.md` (its section 13 has the rules: describe behavior, not history); add QA-CHECKLIST lines for in-game checks; `git add` first, then `python3 tools/manifest.py` (it lists only tracked files), then commit.
- **Git:** one branch per session as assigned; push with `git push -u origin <branch>`; open a draft PR. Tag pushes and branch deletions are refused by the session's git proxy (403): do not retry; list them for Xaya. GitHub actions go through the GitHub MCP tools; `gh` only for search (`gh api -X GET search/issues -f q='repo:heyitsxaya/XayaUI is:issue ...'`).
- **Sync beyond GitHub** (local AddOns folder, Drive copy, checksums in both): described in `debug-log/2026-11-02-handoff-*.md`. Those notes predate the 0.6.0 folder layout, so check them before following them (unverified).
- **Game API facts:** check `docs/reference/` FIRST (Xaya's core reference, 2026-11-04: the live client's API with signatures and secret rules, and every class's talents and spells; the full private version with spell text is in Drive "Blizzard API Data"), then the 12.1.5 API documentation or an in-game probe (`XayaUI_DevAssist`, `/xuidev api` / `toolkit`) before relying on them; say which.

## 7. Key files
`docs/process/` (verification rules, retrospective), `tools/precheck.py`, `docs/reference/` (core reference: API, talents/spells, `charges.md`, `procs.md`), `ROADMAP.md`, `USER-GUIDE.md`, `QA-CHECKLIST.md`, `README.md`, `MANIFEST.md5`, `debug-log/`, `XayaUI/Modules.lua` (feature contract), `XayaUI/Core.lua` (`ns.Print`, saved settings), `XayaUI_Options/Options.lua` (settings window), `tests/run_all.py`, `tests/harness/` (whole-addon harness), `tools/manifest.py`, `shelved/` (old QoL Elements, loaded by nothing).
