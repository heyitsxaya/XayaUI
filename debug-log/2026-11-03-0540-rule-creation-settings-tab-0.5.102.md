# Xaya: move "Condensed rule list" and "Prompt for saving and enable drafts" into their own Rule Creation tab (XayaUI 0.5.102, fork: main)
Logged 2026-11-03 ~05:40 UTC. GitHub issue: #316 (new). Reported against build 0.5.99 (screenshots: Settings > UI Options > Display).
Change: new tab Settings > UI Options > Rule Creation (tab strip: Display | Rule Creation | Theme). It holds "Prompt for saving and enable drafts" (header Saving) and "Condensed rule list (no icons, compact rows)" (header Rule list). Both were on the Display tab. Settings keys are unchanged (ui.promptSave, ui.condensedList), so nothing saved is lost. The old single Settings tab (skin rows off) gets the same tab.
Left on Display (not asked, flagged): "Selected item in the rule list", "Gradient highlight on the top parent group", "Show a rule's spell / buff icon in the rule list". They are also rule-list looks, so Xaya may want them moved next to "Condensed rule list".
Verified: Options.lua parses; no code reads these toggles by tab path. NOT verified in game (the options window was not opened).
Files: Options.lua, USER-GUIDE.md (drafts section, Game Menu "Where"), XayaUI.toc, MANIFEST.md5.
