# "Game Dump" renamed "Dev Assist" (XayaUI_DevAssist 0.7.0, XayaUI_Options 0.6.18, XayaUI_Bonus 0.6.6; fork: main)
Logged 2026-11-04 14:53 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Request (Xaya, 2026-11-04)
"Is it possible to rename the 'game dump' module into 'dev assist?'". Yes; done.

## What changed
- **Folder.** `XayaUI_GameDump` → `XayaUI_DevAssist` (`git mv`, history kept).
  - `XayaUI_GameDump.toc` → `XayaUI_DevAssist.toc`; `GameDump.lua` → `DevAssist.lua`.
  - Title "XayaUI Game Data Capture" → **"XayaUI Dev Assist"**. Version 0.7.0, because the saved file changes.
- **Saved data.** New table `XayaUIDevAssistDB`, in `XayaUI_DevAssist.lua` (the game names the file after the folder).
  - Why not keep the old table name: an old `XayaUI_GameDump` copy left in AddOns would load too. Two addons sharing one saved global
    can let the game write one file's data over the other's. With separate names they cannot touch each other.
  - Captures saved before the rename stay in `XayaUI_GameDump.lua` and are sent as they are.
  - `tools/formula_fit.py` and `docs/reference/build_reference.py` read either name.
- **Commands.** `/xuidev` is the command. `/xuidump` is registered on the same handler (`SLASH_XAYAUIDEV2`), so the run sheet for
  2026-11-05 works word for word; it now says `/xuidev`. `/xuiformula` is unchanged.
- **Old copy left in AddOns** (testers copy folders by hand from `qa-installer-branch`).
  - At login, if `XayaUI_GameDump` is loaded (`C_AddOns.IsAddOnLoaded`), Dev Assist calls `C_AddOns.DisableAddOn("XayaUI_GameDump")`.
    Both calls are documented in `docs/reference/api/namespaces.md`.
  - The old copy is off from the next /reload. One chat line says so, says to delete the folder, and says where its captures are.
  - **Not documented:** which characters DisableAddOn's default `character` argument ("0") covers. QA J12 asks the tester to note it.
- **XayaUI finds it only through its service** ("gameDataProbe", Modules.lua contract), which now also gives `name`, `Open` (the
  window) and `savedFile` ("What to send").
  - Settings > Debugging: the "Dev Assist (separate tool)" box opens it through the service. The old code read the old addon's
    global `_G.XayaUIGameDump` from XayaUI_Options; that line is gone.
  - Core names neither folder (checked by the new test).
- **Kept as history:** the debug logs, `docs/process/RETROSPECTIVE.md`, `docs/plans/AURA-PLAN.md`, and the generated API reference.
  The reference records that it came from a XayaUI_GameDump capture, which is still true. QA steps keep their "(GameDump 0.x)" version
  labels.
- **Updated to the new names:**
  - USER-GUIDE 12.13 (now "Dev Assist", with the old-name note) and 12.14;
  - README;
  - the 2026-11-05 run sheet: copy the new folder, delete the old one, new file name, "What to send";
  - the formula walkthrough;
  - QA section J (commands), B35, B51, B57, and the new J12;
  - `.gitignore` comment, SESSION-START-SUMMARY, and Bonus Tooltips comments.

## Scope (V4)
`git grep XayaUI_GameDump / GameDump / xuidump / Game Data Capture` over the whole repository found 255 mentions before the change:
- the addon's 5 Lua files and toc;
- Options (1 group, 1 toggle label);
- Bonus (2 comments);
- 2 tools;
- 7 tests (3 renamed `gamedump_*_run.py` → `devassist_*_run.py`);
- `.gitignore`;
- 15 documents.

After the change, the new test lists the places allowed to name the old folder, and fails on any other.

## Checks
- **`tests/devassist_rename_run.py`** (new, 25 checks):
  - both commands on one handler, no handler left on the old key;
  - the guard (old copy loaded → switched off once, with the message; not there → silent; no DisableAddOn → asks the player);
  - the service and Settings;
  - core naming neither folder;
  - toc equals the folder's Lua files;
  - both tools reading either table name;
  - no stray old name.
- `devassist_api_run` (27), `devassist_catalogue_run` (53), `devassist_probe_run` (99), `formula_capture_run`: pass under the new
  names.
- Negative control: on the commit before, `XayaUI_DevAssist` does not exist and the rename test fails at loading.

## Decision graph
```
Rename possible?
├─ only the title (folder stays XayaUI_GameDump) ......... cheapest, no data step, but the folder and file keep the old name;
│                                                            rejected: Xaya asked to rename the module
├─ folder + title + commands ............................. chosen
│   ├─ saved table: keep XayaUIGameDumpDB? ............... no: an old copy loaded beside the new one would share it (data loss risk)
│   │   └─ new XayaUIDevAssistDB; old file sent as-is; tools read both
│   ├─ /xuidump: drop? .................................. no: the 2026-11-05 run sheet and testers' habits use it; kept as an alias
│   ├─ old copy in AddOns: ignore / refuse to run / switch it off?
│   │   └─ switch it off for the next /reload + one message (refusing to run would block the new tool for a whole session)
│   └─ Settings opened it by its global ................. replaced by the service (the global's name changed; the contract exists)
└─ history documents: rewrite? ........................... no: they record what was true when written
```

Files: XayaUI_DevAssist/* (renamed from XayaUI_GameDump/*), XayaUI_Options/Options.lua, XayaUI_Options.toc, XayaUI_Bonus/Tooltips.lua,
XayaUI_Bonus.toc, tools/formula_fit.py, docs/reference/build_reference.py, tests/devassist_{api,catalogue,probe}_run.py (renamed),
tests/devassist_rename_run.py (new), tests/formula_capture_run.py, tests/disabled_tree_run.py, tests/display_tab_run.py,
tests/debug_record_run.py, .gitignore, README.md, USER-GUIDE.md, QA-CHECKLIST.md, SESSION-START-SUMMARY.md,
docs/process/IN-GAME-DATA-2026-11-05.md, XayaUI_DevAssist/FORMULA-CAPTURE-WALKTHROUGH.md, this entry, MANIFEST.md5.
