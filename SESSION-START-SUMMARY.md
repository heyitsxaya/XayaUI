# XayaUI: session-start summary

Read this first in any new chat about XayaUI. It is meant to be enough on its own; the full record is in the two trackers below.
Last updated 2026-11-04 06:46 UTC by Claude Code session 014bN6tUvbkCv9Ha9VgNF4Xa (earlier the same day: 014bN6tVdvvFNcwwRRBHuqTv). Facts were checked in that session unless marked (unverified) or (inference).

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
- **Data:** no code or data copied from another addon (#290). Class, spell, and item data is learned from the game at runtime where the game gives it. Numbers from a credible public database (for example Wowhead) are allowed when the source is named next to them.
- **Never invent numbers.** A value that cannot be read or sourced is shown as unavailable or "not given by the game".
- **Midnight secret values:** every read that can come back secret is pcall'd and checked with `issecretvalue`; never compare, format, or guess a secret.
- **Personal data stays local:** personal rules, lists, and anything about other players are never in a default export.
- **Options style:** a dropdown never takes a row alone; short labels; the explanation goes in the tooltip. Settings layout: a feature is a node in the left pane, its parts are child nodes, and a part's sections are tabs (`ns.SectionTabs`).
- **Feature addons never get called by name from core:** they register through `XayaUI/Modules.lua` (`ns.WhenReady`, `ns.RegisterSettingsPage`, `ns.RegisterCommand`, `ns.RegisterLauncher`).
- **"Profile"** means only the whole addon as configured (#354 is asking whether that changes).
- **Wording to Xaya:** truth first; flag inferences; no unearned compliments; state what is not verified in game.

## 3. Addons (versions from the .toc files on `main`, 2026-11-04)
| Folder | Version | Holds |
|---|---|---|
| `XayaUI` | 0.6.11 | core: rules, cues, conditions, actions, combat aura engine (`Combat/`), themes, console, minimap and ESC-menu buttons |
| `XayaUI_Options` | 0.6.7 | the settings window (loads on first open; Ace3 libs) |
| `XayaUI_Chat` | 0.6.6 | Chat Panel, Chat Bar, filters, history, privacy cover |
| `XayaUI_QoL` | 0.6.2 | Cursor Highlight, Gradient Cursor Trail, Character Toolkit |
| `XayaUI_Bonus` | 0.6.4 | tooltips, Notepad, data panels |
| `XayaUI_Reskin` | 0.6.0 | Game Menu skin |
| `XayaUI_Media`, `XayaUI_GameDump` | 1.0, 0.5.0 | user media folder; game data capture (API, talents, Cooldown Manager catalogue, aura log) |
Saved settings: one account-wide table, `CueRulesDB` (QoL parts use `CueRulesDB.cursorHighlight`, `.cursorTrail`, `.characterToolkit`). Nothing is saved per character yet.

## 4. Active items
| Item | State | Next step |
|---|---|---|
| Code gaps from the retrospective (`docs/process/RETROSPECTIVE.md`, 22 rows) | all re-checked against the code | fix in this order: 2 (D1 time left), 1 (hidden Cooldown Manager viewer), 8 with 7, 11, 22, 13, 4, then 5 |
| Proc glows as aura signals (task 28) | `docs/reference/procs.md` built (wago.tools, build 12.1.5.70783); Boiling Point 1265968 is the only aura that lights Blood Boil | GameDump probe in combat first, then a "Spell glows" trigger, Boiling Point (#315) first, Divine Arbiter (#332) needs talents / set bonus to rule out other auras |
| Old-branch features not on `main` | an audit of 31 old commits is running (#125 strata / level conditions, #88 Recycle Bin, #247 Trade tab, and whatever else it finds) | port them, then the old branches can be deleted |
| Character Toolkit (QoL 0.6.2): tabbed panel; goal is to surface everything the API gives, not copy the character window | merged, offline tests pass, **unverified in game** | in-game check (QA-CHECKLIST E1d to E1f); Xaya decides: fill the "not given by the game" rows (primary to armor or dodge, block, AP to damage) from a named database? keep the name "Character Toolkit"? |
| #354 QoL element profiles (per character or global) | decision needed | what a profile holds; named profiles or one switch; the word "profile" |
| #357 chat emotes as a QoL element | queued | not started |
| #278 tester requests (7 items) | partly built | two in-game probes first (`/xui loc` under each effect; target / focus cast readability) |
| #268 9-point anchors | open, **high priority** | |
| M1 data model and migration | planned | blocks M2b, M3, M6d |
| ROADMAP section 10 | decisions waiting | gated panes, backup, recycle bin, and others |
Proposed order (not a commitment): ROADMAP section 12.

## 5. Pending actions for Xaya
1. **Branches** (Xaya, 2026-11-04: branches with no functionality beyond `main` may be deleted). The cloud session's git proxy refuses branch deletions (HTTP 403), so Xaya deletes them on github.com/heyitsxaya/XayaUI/branches. Cleared and still there on 2026-11-04 06:46: `chat/history-footer-review`, `claude/code-review-2026-10-31`, `claude/confident-edison-pitusd`, `claude/determined-mayer-vm3md8`, `sidebar-spacing-2026-11-02`, `claude/custom-theme-0.5.40` (entirely inside `wip/notepad-icons`). `stable` is a protected branch: remove it from its protection rule first (Settings > Branches or Rules; do not delete a rule that also covers `main`). Keep `main`, `qa-installer-branch`, the session branch and `archive/2026-11-04` (it holds every old head).
2. **#88 Recycle Bin decisions:** how long deleted items stay (the old version: weekly by default), and whether a group deleted with its contents goes to the bin as one item.
3. In-game pass over everything marked Built but unverified (`unverified-in-game` label).
4. The Character Toolkit decisions above; decisions in ROADMAP section 10 and AURA-PLAN section 3.

## 6. How to work here (cloud session)
- **Process:** follow `docs/process/VERIFICATION.md` (the project skill `.claude/skills/xayaui-change` sums it up). `python3 tools/precheck.py` must end with `FAILS: 0` before a commit (`--base origin/main` before pushing to main).
- **Tests:** `pip install lupa`, then `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py` (full) or `--quick`. On 2026-11-04 (core 0.6.11) the full suite passed: 68 groups and the whole-addon harness. Anything red is new. New feature: add `tests/<name>_run.py` (Lua 5.1 via `tests/lua51.py`); its last line must carry `FAILS: 0` or another marker `run_all.py` accepts.
- **Every change:** bump the addon's `## Version` and `## X-Date` in its .toc; add a debug-log entry; update `USER-GUIDE.md` (its section 13 has the rules: describe behavior, not history); add QA-CHECKLIST lines for in-game checks; `git add` first, then `python3 tools/manifest.py` (it lists only tracked files), then commit.
- **Git:** one branch per session as assigned; push with `git push -u origin <branch>`; open a draft PR. Tag pushes and branch deletions are refused by the session's git proxy (403): do not retry; list them for Xaya. GitHub actions go through the GitHub MCP tools; `gh` only for search (`gh api -X GET search/issues -f q='repo:heyitsxaya/XayaUI is:issue ...'`).
- **Sync beyond GitHub** (local AddOns folder, Drive copy, checksums in both): described in `debug-log/2026-11-02-handoff-*.md`. Those notes predate the 0.6.0 folder layout, so check them before following them (unverified).
- **Game API facts:** check `docs/reference/` FIRST (Xaya's core reference, 2026-11-04: the live client's API with signatures and secret rules, and every class's talents and spells; the full private version with spell text is in Drive "Blizzard API Data"), then the 12.1.5 API documentation or an in-game probe (`XayaUI_GameDump`, `/xuidump api` / `toolkit`) before relying on them; say which.

## 7. Key files
`docs/process/` (verification rules, retrospective), `tools/precheck.py`, `docs/reference/` (core reference: API, talents/spells, `charges.md`, `procs.md`), `ROADMAP.md`, `USER-GUIDE.md`, `QA-CHECKLIST.md`, `README.md`, `MANIFEST.md5`, `debug-log/`, `XayaUI/Modules.lua` (feature contract), `XayaUI/Core.lua` (`ns.Print`, saved settings), `XayaUI_Options/Options.lua` (settings window), `tests/run_all.py`, `tests/harness/` (whole-addon harness), `tools/manifest.py`, `shelved/` (old QoL Elements, loaded by nothing).
