# UI bugs in existing features: lone dropdowns, red buttons, cut-off labels (#352, #286, #99; XayaUI core 0.6.16, XayaUI_Options 0.6.12; fork: main)
Logged 2026-11-04 09:02 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Request
Xaya, 2026-11-04: "review all other open issues around UI bugs and try to tackle those. Prioritize those where possible over
finalizing new features". A triage of all 242 open issues (scratchpad report, not in the repo) ranked them. These three needed no
decision from Xaya.

## #352: a dropdown alone on its row stretched across the whole pane
- **Xaya's standing rule:** "a dropdown must never take a whole row by itself".
- **Cause:** `XayaUI_Options/Skin.lua` FlexPrepass counted a dropdown as stretchable and gave it the row's leftover width, so a
  lone dropdown grew from one grid column to the full pane.
- **Change:** a dropdown alone on its row keeps its own width: one grid column, or its longest option when that is wider. It still
  shares leftover width with other controls on its row.
- **Left as is:**
  - dropdowns the settings code declares full-width on purpose (`width = "full"`);
  - other control types (a lone slider still spans the pane).
- **Test:** `tests/flex_dropdown_run.py` runs the real FlexPrepass. The old code fails 2 of 5 checks.

## #286: buttons still in Blizzard's red style
Triage list, checked one by one:
- **Fixed:**
  - the Debug console tray's Clear / Copy (Options.lua);
  - the "Play all N sounds" dialog's Yes / No (Options.lua);
  - the console window's buttons and the copy box's "Select all" (Console.lua);
  - a group's X / Y position popup (Visual.lua).
- **Already flat:**
  - the multi-select bar (its own flat code in Skin.lua; the triage had it wrong);
  - the Import window;
  - the save bar.
- **Kept on purpose:**
  - "Open XayaUI" inside Blizzard's Settings panel;
  - the window's collapse button, which pairs with Blizzard's close X in the title ribbon.
- **Change:** new `ns.FlatButton(b, primary)` in Core.lua. It applies Skin.lua's flat look at once and again on every show, so it
  follows the skin switch. Without the settings addon it changes nothing.
- **Test:** `tests/flat_buttons_run.py` runs the real helper and scans every addon for red-template buttons. The old code fails 8.

## #99: Target Debuff labels cut off ("Cooldown M...")
- **Change:**
  - "Cooldown Manager ID" and "Unlit icon in combat" (values "Means: debuff absent" / "Stay unknown"), with the full explanation in
    each field's tooltip;
  - "Item set ID (0 = most worn)" on the new Tier Set Pieces trigger.
- **Test:** `tests/trigger_labels_run.py` checks every trigger field label against 45 characters. The old code has 2 over.

## Not done here (from the same triage)
- #336 (art rows start at different places): needs either a fixed preview box drawn by the skin, or a transparent spacer file whose
  existence in the game I cannot confirm.
- #351 (one margin / gutter everywhere): large, every window.
- #260, #343, #334, #319, #284 and the #259 layout requests: need Xaya's decisions first.

Docs: QA-CHECKLIST B43-B45; USER-GUIDE 4.4 (the option's new name).
Files: XayaUI/Core.lua, Console.lua, Visual.lua, Triggers.lua, XayaUI.toc (0.6.16); XayaUI_Options/Skin.lua, Options.lua,
XayaUI_Options.toc (0.6.12); tests/flex_dropdown_run.py, flat_buttons_run.py, trigger_labels_run.py (new); QA-CHECKLIST.md,
USER-GUIDE.md, this entry, MANIFEST.md5.
