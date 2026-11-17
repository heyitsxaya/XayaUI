# Handoff: Stat Calculator: six-criteria review and fixes
- Session: session_014bN6tUmdW8ddPT74JogMYj · Project: heyitsxaya/XayaUI · Branch: `claude/stat-calculator-v25` (QA line; pushed: yes) and `claude/stat-calculator-main` @ fda1e29 (= origin/main; pushed: yes)
- Open PRs: none (PR #524 into qa-installer-branch merged by fast-forward 2026-11-11).
- Released / live:
  - main fda1e29: XayaUI_Bonus (loader) + XayaUI_Bonus_StatCalculator (load on demand).
  - qa-installer-branch 049b1dd and later: the Stat Calculator, Improved Character Display and Character Reskin.
  - Branch-only: the 13 docs-only commits after 049b1dd (request log, tracker, wireframe spec, this file).
- Request log: `docs/process/REQUEST-LOG.md` section **A24** (rows 1-24, her words verbatim with status).
- Tracker: `docs/plans/STAT-CALCULATOR-V25-TRACKER.md`. Cold-start summary: `docs/plans/STAT-CALCULATOR-V25-SESSION-SUMMARY.md`.

## 1. Purpose and scope
She asked: "Pass these code quality standards and expectations — alongside all tests you had to conduct — specifically to the character stat tool you designed that currently resides on QA branch."

Scope (A24 #2): the Stat Calculator and its stat model, plus the character window reskin and the QoL character pane. During the work this became three separate elements:
- **Stat Calculator**: ONLY the side panel (A24 #3).
- **Improved Character Display**: everything that changes the character window (A24 #4-#6).
- **Character Reskin**: the window's look.

## 2. Current state
**Done, with tests (standard Lua 5.1 harness, NOT the game):**
- Review: `docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md` (125 findings).
  - All 9 high and 23 medium confirmed findings fixed (5695993).
  - V27-V32 gate audit and fixes (7f31ee7).
- Restructure: the files are now StatCalculator.lua, StatModel.lua, ImprovedCharacterDisplay.lua, CharacterReskin.lua (look only) and StatsTextBoxes.lua. "Character Toolkit" is retired.
- V26 "Hide silently": the panel, Stat Calc button and minimap row hide in combat.
- Esc closes the stand-alone panel, which sits on the normal window layer.
- Stat Weights:
  - Influences is always its own column, with bottom-aligned titles of at most 2 lines.
  - The panel widens so no word is cut.
  - The title is "Rating".
- Character slots: item level on the icon; enchant, gems and embellishment at the icon's right edge; the "Style" select is gone.
- On main:
  - self-contained load-on-demand Stat Calculator under Bonus Features, with a profile part;
  - What's New trimmed to 132 KB;
  - full suite ALL CHECKS PASS on fda1e29, run by me before the push.
- QA branch: the full suite passes except 3 groups that already fail at base, from British spellings in XayaUI_Nameplates / XayaUI_Reskin FriendColors, which are out of scope. precheck FAILS: 0.

**Verified in game:** nothing. Everything is UNVERIFIED IN GAME.
- In-game steps for main: `docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md` (on main).
- QA walks: QAWalks-statcalc*.lua, -statmodel, -chardisplay-*, -tooltips-charstats, -influences, -slot-options.

**Wireframes** (her rule, CODE: XUI): https://claude.ai/artifact/953NkhKfXu9eFBRRKiignh
- Nine boards: the Stats, Gear and Ability Scaling tabs; Stat Calculator settings; Improved Character Display and its settings; the six Gear Summary styles; the DR-bar proposal.
- Spec: `docs/plans/STAT-CALCULATOR-WIREFRAME-SPEC-2026-11-17.md`.
- Her comment changes (A24 #15-#24) are drawn on the wireframe only. **None of them is in code yet.**

## 3. Xaya's decisions
All are in REQUEST-LOG A24, verbatim and dated. The key ones:
- **#3:**
  - "the stat calculator is ONLY the window that appears by the side of the character pane. NOTHING that directly touches the character pane is part of the stat calculator…"
  - fix bundle "Highs + every medium"
  - combat "Hide silently"
- **#4:** "call the character functionality modifications Improved Character Display"
- **#6:** "there is no "character toolkit" and you need to stop using that term because we have retired it."
- **#8:** float math reading confirmed; stats in combat: "for now 1, circle back to this later after we confirm performance is wholly optimized. ask repeatedly, since we might need to dynamically calculate character stats later".
- **#9:** "Widen the panel"; "Ilvl goes on item block; enchant and gems are both on the outside right border of the icon. Don't remove anything else"; Style label "sounds unnecessary".
- **#10-#11:** "1 + Rename to Rating"; "Self-contained but under Bonus Features parent addon folder"; "Push to main when green".
- **#12-#13:** "Trim old What's New text"; "if the addon or element within an addon is off it should not be read at all… detected once per reload" (now standing rule V34); load-on-demand split: "1 but unsure how this will look in game -- this might not be okay"; profiles: "Yes, include them".
- **#16 (supersedes #9 for the right column):** "all these enchant, gem, embellish names go in towards character model".
- **#15, #17-#24:** her wireframe comments (left-align, own tooltip per Influences name, DR bars, dashed DR lines, Configure display button, Stat Calc button at bottom right, waist / wrist / cape).

## 4. Open questions for Xaya (verbatim where possible; my recommendation in brackets)
**Asked in the wireframe's comment threads, awaiting her answers:**
1. Left-align: does it also apply to "Max (bags)" in the header? [No: it pairs with "Equipped" on the left.]
2. DR bars:
   - replace Split bars or apply to every bar style? [every bar style]
   - right-hand text: distance to the next step, or percent lost? [distance]
   - stats with no DR step? [scale to the first step]
   - an option, off by default, to always show every step? [yes]
3. Gear Summary default style: still "Decide after seeing them" (#74). Wireframe board "the six styles".
4. Window space: set the Extra width default to 0, or remove the "wider window" option? [remove it, now that the names face the model]
5. Weapons, under "towards the character model": main hand left of the weapons, off hand right, unchanged? [unchanged]
6. Waist: ticked by default in Enchant Slots?
7. A "No socket" warning on socket-capable slots (wrist, waist)?
8. Check Midnight's enchant slots and update the default Enchant Slots set (Back?): needs research from a credible source.
9. Max secondary stats per item: research a stat-budget source, or measure in game? (thread "do we know what the max possible total secondary stats…")
10. The faded bar part: a different treatment or a legend? (thread "what does this dark color indicate?")
11. Placeholder sizes and positions for "Configure display" (96 x 18, left of close) and Stat Calc (bottom-right, 6 px in).

**Waiting for her in-game test on main:**
- the AddOns list grouping (it is "XayaUI", not literally "under Bonus Features");
- "Reload now?" on toggle (QA acted at once);
- my wording (off-page lines, AddOns title, login / `/xui stats` status lines);
- the right-column rows (now moot if #16 is built);
- "E? / E" mark: "2 but reprompt after pushed to main and I test";
- the standing reminder on stats in combat.

**Also open:**
- Her new CODE: XUI rules (wireframes, three completion questions): how they apply to work in progress was being asked by the main session.
- The Stat Calculator was not yet marked complete against the three questions.
- The filemap / function call index for these files does not exist yet.

## 5. In-flight work and next steps
Nothing is in flight. Next code round, once she finishes the wireframe review:
1. Build A24 #15-#24 in code:
   - left-align;
   - per-name Influences hovers;
   - blocks facing the model;
   - Configure display button;
   - Stat Calc button at bottom right;
   - DR bars, if confirmed;
   - window space.
2. Process for each change: a test that fails on old code; a reviewer; full suite plus precheck on QA; port to main (`claude/stat-calculator-main` worktree) and push when green, per "Push to main when green".
3. Improved Character Display parts live on QA only.

Process used: `.claude/skills/xayaui-change/SKILL.md` on QA, plus her rebuild standards V25-V34 (docs/process/VERIFICATION.md on `claude/dazzling-brown-x9fqrm`).

## 6. Dependencies on other sessions
- **Core (main) needs**, which I did not edit:
  - XayaUI/Modules.lua ns.MODULES maps "stats" to QoL;
  - XayaUI/DebugRecord.lua XUI-E004/E005 texts name retired features ("Character Toolkit");
  - XayaUI/MinimapButton.lua: a minimap list already open when combat starts keeps the Stat Calculator row until it closes.
- **QA's core is older than main's**: the V29 key test (tests/statcalc_keys_run.py) has to be re-run against main's KeyCatch. It passed on main in the port round.
- **Rules session (session_014bN6tVBGo8BHkHu65TAcjD):** owns the standards text (V25-V34) and XAYA-STANDING-RULES.md.
- **V18 what's-new message:** not sent. It goes to the feature-summary session.

## 7. Key files, docs, artifacts, links
- **Code on main:**
  - XayaUI_Bonus/StatCalculatorLoader.lua and ProfilePart.lua;
  - XayaUI_Bonus_StatCalculator/{StatMath,StatModel,StatCalculator}.lua;
  - tests: statcalc_*, char_stat*, char_spells*, gate_statcalc_main, statcalc_lod_run.py.
- **Code on QA:**
  - XayaUI_Bonus/StatCalculator.lua;
  - XayaUI_QoL/{StatModel,StatMath,ImprovedCharacterDisplay,CharacterReskin,StatsTextBoxes}.lua;
  - Enhanced Tooltips character-stat lines: XayaUI_Bonus/Tooltips.lua section 5.
- **Docs:**
  - REQUEST-LOG A24;
  - docs/plans/STAT-CALCULATOR-{REVIEW-2026-11-10, BOUNDARY-MAP-2026-11-10, TO-MAIN-2026-11-11, WIREFRAME-SPEC-2026-11-17, V25-TRACKER, V25-SESSION-SUMMARY}.md;
  - docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md (main).
- **Wireframes:** https://claude.ai/artifact/953NkhKfXu9eFBRRKiignh. Private: she must share it for others to see it.

## 8. Gotchas
- **Saved keys** kept on purpose, to avoid resetting players' settings: XayaUIBonusDB.characterToolkit, XayaUIQoLDB.characterToolkit / characterReskin(.features), page key "chartoolkit", walk id audit-char-toolkit-events.
- **QA's PATCH-NOTES** sits at the 200 KB info-pane cap (about 4 bytes left). Main was trimmed to 132 KB.
- **Main has no tools/** (precheck, manifest, info-pane builder). QA's tools were pointed at the main tree.
- **Skeptic refutation rate** in reviews: 0 of 71 and 1 of 35. Treat severities as a ranking.
- **Wireframe canvas** artboards are `.dc.html` files under project/. My working copy was in the session scratchpad, which is not durable: re-read the artifact before editing.

## 9. Environment needs (names only)
None beyond the repo. A Lua 5.1 harness (lupa) runs the tests. `XUI_API_INDEX` for the full suite.

## 10. Suggested successor
One session for "Stat Calculator + Improved Character Display" holding both branches, at high reasoning effort (her CODE rule on model quality). Load this file, REQUEST-LOG A24 and the session summary first.

## 11. Archive readiness
Ready. All work is committed and pushed; nothing is in flight. Open questions are listed in §4 and are also in the wireframe comment threads.
