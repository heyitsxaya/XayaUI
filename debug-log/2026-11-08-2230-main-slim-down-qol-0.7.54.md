# 2026-11-08 22:30 UTC: main slim-down: Blizzard Reskin, Nameplates and parked code move to qa-installer-branch (XayaUI 0.6.84, QoL 0.7.54, Dev Assist 0.7.72)

Session: session_014bN6tUcjxM3wmJBjpyxQDS, branch `claude/confident-cray-42xtgz`, PR #519. REQUEST-LOG A21: TRI-4 to TRI-8.

## Her words (verbatim)
- TRI-4: "For now, main is now going to include ONLY the following modules: * bonus features * rules * QoL * core + settings  All other things should be migrated to QA branch moving forward so I can focus on designing and optimizing the essential elements"
- TRI-5 (answers): Dev Assist "Keep on main (Recommended)"; Media "Keep on main as part of core (Recommended)".
- TRI-6: "Anything else not listed for main should also migrate to the QA branch"; shelved/ and roadmap-features/: "Move both to QA (Recommended)".
- TRI-7: "The Chat is part of bonus features, so keep it on main — just remove all blizzard reskins for the time being"
- TRI-8: "1. The character reskin component should follow the same logic as improved chat: if no reskin is present, reskin it; otherwise let the current reskin run and only run the other components"

## What changed
1. **Branch layout.** `main` keeps XayaUI, XayaUI_Options, XayaUI_Rules, XayaUI_Rules_Options, XayaUI_Chat, XayaUI_QoL, XayaUI_Bonus,
   XayaUI_DevAssist, XayaUI_Media, plus docs/, tests/, tools/, debug-log/. Removed from main (they stay on qa-installer-branch):
   XayaUI_Reskin, XayaUI_Nameplates, shelved/, roadmap-features/, and the 7 tests that only test Reskin / Nameplates
   (friend_class_colors, gamemenu, nameplates, qa_walks_reskin, reskin_blizzard_skins, reskin_tab, reskin_tab_switch).
   The list is `tools/qa-only-paths.txt`.
2. **No sync between the branches.** This branch first rewrote `tools/sync-qa-branch.sh` to build qa-installer-branch as main plus the
   QA-only paths (simulated and working). Before it landed, main c92f4c4 (session 014bN6tUDLJ6T742DewZDg1s) removed the mirror workflow on
   Xaya's word "disconnect QA and main mirroring", so the rewrite was dropped in the merge: main's disconnected script and the workflow's
   removal are kept as they are. qa-installer-branch already holds every QA-only path at its newest content (checked at its tip 8ce0e7f,
   another session's QA build: each path identical to main 3eb0c4b; main changed none of them after it), so nothing had to be copied there.
3. **Tests that cover both** (28 files): they read folder presence and print `SKIP (QA-branch module absent: ...)` for the module part
   on main; on a full checkout every one runs the same checks as before (check counts compared file by file against the originals).
   Two needed more than a skip: options_split_parity (the skipped tabs now depend on which module is absent: with Chat present the
   "settings" tab is compared again; the Theme page is dropped from the expected list only when Reskin, Chat and QoL are all away)
   and tooltip_parity (the Latency hover lists the loaded addons: absent addons' lines are dropped, the total lowered by one stand-in
   size each, and the addon lines compared as a set because equal sizes have no fixed order).
4. **Dev Assist 0.7.72.** `QA.Register` takes `needs = "<addon>"` on a walkthrough or a step; where that addon is not installed (core
   ns.ModuleState "missing"; a switched-off addon keeps its walkthroughs) it is not listed. QAWalks-reskin / -friends / -nameplates
   return early without their addon; the checklist generator gives sections G (Blizzard Reskin) and K (Nameplates) `needs`.
   New walkthrough "Main without Blizzard Reskin and Nameplates (A5)" in QAWalks-platform.lua (pre-fill checks: both addons read
   "missing"; settings window opens with no new XayaUI error; no listed walkthrough or step needs a missing addon).
5. **Character Reskin (QoL 0.7.54, core 0.6.84), TRI-8.** Before: the look half (switch, chrome, stat-list art, opacity, width) was
   kept only in Blizzard Reskin's store; without that addon it was a throwaway table forced off, so on the slimmed main the switch could
   never turn on. Now: with XayaUI_Reskin not installed the look half is kept in QoL's own settings (`characterReskinLook`, saved only
   once a value differs from its default; core SETTINGS_KEYS gives the key to qol). An installed but switched-off Blizzard Reskin
   still keeps the look off (unchanged). The look also stays off while another addon skins the character window, as Chat Panel does
   beside another chat skin (Chat Core.lua C.BlockedReason); the features (item level, enchants, gems, stat list) run either way:
   EllesmereUIBlizzardSkin loaded; or ElvUI loaded unless its settings read E.private.skins.blizzard.enable == false or .character ==
   false. **INFERENCE:** those ElvUI key names were not checked against ElvUI's code in this session; anything unreadable counts as ElvUI
   skinning the window (fail safe: nothing drawn over it). `/xui reskin on` works without Blizzard Reskin (saves, asks the reload).

## Scope (V4)
- Folder references from kept modules to the removed ones: comments, optional service lookups (`ns.Service`), core's module list
  (`Modules.lua` MODULES), `DebugRecord.lua` folder codes, Options page comments, `CharacterReskin.lua` (the look store). Only the
  last one changed behaviour; the others already handle an absent addon.
- Settings: Chat Panel's master switch (`ns.ReskinTabOn`) is core's (`CueRulesDB.reskinTabOff`), so the Chat Panel works without
  XayaUI_Reskin. The Theme page and the Blizzard UI tab keep the Chat Panel and Character Pane pages.
- Tests: every test that names XayaUI_Chat / Reskin / Nameplates (55 files) was run with the folders removed.

## Checks run
- Full suite on main's layout (`XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`): ALL CHECKS PASS (247 test
  groups + the whole-addon harness, every fresh-install combination of the present addons).
- Full suite on a full layout (this tree plus the QA-only paths from main 3eb0c4b): all pass. Two tests
  (preview_icons, sidebar_multi_link) ask `git ls-files`; they failed only while that copy was not a git repository, and pass in one.
- New test `tests/char_reskin_noreskin_run.py` (16 checks, five cases in separate Lua states): fails on the old CharacterReskin.lua
  (A: switch forced off, look not drawn; B: no other-skin check), passes on the new.
- `python3 tests/lua_pitfalls_run.py`: FAILS: 0. `python3 tools/qa_walks_from_checklist.py --check`: in sync.

## Not checked / open
- Nothing here has run in the game. QA-CHECKLIST A5 and the A5 walkthrough cover the install; char_reskin_noreskin covers the reskin.
- ElvUI's skin setting names (above) are an INFERENCE.
- Saved look settings in XayaUIReskinDB.characterReskin are not read on main (that saved variable loads only with its addon), so the
  character reskin starts from its defaults (off) there.
- Other sessions' branches that still change XayaUI_Reskin / XayaUI_Nameplates would re-add them to main if merged there; that work
  belongs on qa-installer-branch now (tools/qa-only-paths.txt).
- Tests edited for "Chat absent" keep that branch of code, unused now that Chat stays on main.
