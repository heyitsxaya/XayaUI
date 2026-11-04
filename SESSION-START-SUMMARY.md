# XayaUI: session-start summary

Read this first in any new chat about XayaUI. It is meant to be enough on its own; the full record is in the two trackers below.
Last updated 2026-11-04 by Claude Code session 014bN6tVdvvFNcwwRRBHuqTv. Facts were checked in that session unless marked (unverified) or (inference).

## 1. How this project is tracked
Every piece of addon work is multi-session (Xaya, 2026-11-04). New chat: read this file, then glob the repo root and `debug-log/` for `*SUMMARY*`, `*LOGIC*`, `*CONTEXT*`, `*SESSION*`, `*handoff*` files and read the newest.

| File | Role | Update when |
|---|---|---|
| `ROADMAP.md` | **Full tracker**: every feature, its status, its weakest point, open questions, parked and dropped items with reasons | a feature's status, scope, or decision changes |
| `debug-log/` | **History**: one entry per change or finding, named `YYYY-MM-DD-HHMM-topic-version.md` | every change, in the same commit |
| `SESSION-START-SUMMARY.md` (this file) | **Cold start**: rules, active items, pending actions, how to work here | an active item or pending action changes; at the end of a session |
| GitHub issues | one issue per feature or defect; labels `decision-needed`, `unverified-in-game`, `roadmap` | as work happens |

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

## 3. Addons (versions from the .toc files on `main` + PR #358)
| Folder | Version | Holds |
|---|---|---|
| `XayaUI` | 0.6.2 | core: rules, cues, conditions, actions, combat aura engine (`Combat/`), themes, console, minimap and ESC-menu buttons |
| `XayaUI_Options` | 0.6.3 | the settings window (loads on first open; Ace3 libs) |
| `XayaUI_Chat` | 0.6.4 | Chat Panel, Chat Bar, filters, history, privacy cover |
| `XayaUI_QoL` | 0.6.2 (PR #358) | Cursor Highlight, Gradient Cursor Trail, Character Toolkit |
| `XayaUI_Bonus` | 0.6.0 | tooltips, Notepad, data panels |
| `XayaUI_Reskin` | 0.6.0 | Game Menu skin |
| `XayaUI_Media`, `XayaUI_GameDump` | 1.0, 0.2.0 | user media folder; API probe companion |
Saved settings: one account-wide table, `CueRulesDB` (QoL parts use `CueRulesDB.cursorHighlight`, `.cursorTrail`, `.characterToolkit`). Nothing is saved per character yet.

## 4. Active items
| Item | State | Next step |
|---|---|---|
| PR #358 Character Toolkit (QoL 0.6.2): tabbed panel; goal is to surface everything the API gives, not copy the character window | draft, offline tests pass, **unverified in game** | in-game check (QA-CHECKLIST E1d to E1f); Xaya decides: fill the "not given by the game" rows (primary to armor or dodge, block, AP to damage) from a named database? keep the name "Character Toolkit"? |
| #354 QoL element profiles (per character or global) | decision needed | what a profile holds; named profiles or one switch; the word "profile" |
| #357 chat emotes as a QoL element | queued | not started |
| #278 tester requests (7 items) | partly built | two in-game probes first (`/xui loc` under each effect; target / focus cast readability) |
| #268 9-point anchors | open, **high priority** | |
| M1 data model and migration | planned | blocks M2b, M3, M6d |
| ROADMAP section 10 | decisions waiting | gated panes, backup, recycle bin, and others |
Proposed order (not a commitment): ROADMAP section 12.

## 5. Pending actions for Xaya
1. In-game pass over everything marked Built but unverified (59 issues carry `unverified-in-game`, per ROADMAP).
2. The PR #358 decisions above.
3. Decisions in ROADMAP section 10.

## 6. How to work here (cloud session)
- **Tests:** `pip install lupa`, then `python3 tests/run_all.py --quick`. Known failure already on `main` before 2026-11-04: whole-addon harness, `Options.lua:4596` (`C_Texture` nil in the harness world, slash-command icon report). Anything else red is new. New feature: add `tests/<name>_run.py` (Lua 5.1 via `tests/lua51.py`).
- **Every change:** bump the addon's `## Version` and `## X-Date` in its .toc; add a debug-log entry; update `USER-GUIDE.md` (its section 13 has the rules: describe behavior, not history); add QA-CHECKLIST lines for in-game checks; `git add` first, then `python3 tools/manifest.py` (it lists only tracked files), then commit.
- **Git:** one branch per session as assigned; push with `git push -u origin <branch>`; open a draft PR. GitHub actions go through the GitHub MCP tools; `gh` only for search (`gh api -X GET search/issues -f q='repo:heyitsxaya/XayaUI is:issue ...'`).
- **Sync beyond GitHub** (local AddOns folder, Drive copy, checksums in both): described in `debug-log/2026-11-02-handoff-*.md`. Those notes predate the 0.6.0 folder layout, so check them before following them (unverified).
- **Game API facts:** check against the 12.1.5 API documentation or an in-game probe (`XayaUI_GameDump`) before relying on them; say which.

## 7. Key files
`ROADMAP.md`, `USER-GUIDE.md`, `QA-CHECKLIST.md`, `README.md`, `MANIFEST.md5`, `debug-log/`, `XayaUI/Modules.lua` (feature contract), `XayaUI/Core.lua` (`ns.Print`, saved settings), `XayaUI_Options/Options.lua` (settings window), `tests/run_all.py`, `tests/harness/` (whole-addon harness), `tools/manifest.py`, `shelved/` (old QoL Elements, loaded by nothing).
