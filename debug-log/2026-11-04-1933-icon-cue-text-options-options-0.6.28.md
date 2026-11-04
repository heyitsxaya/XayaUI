# Icon and Texture cues get their text options back, inside the options box (XayaUI_Options 0.6.28; fork: main)
Logged 2026-11-04 19:33 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Report
Xaya, 2026-11-04, with a screenshot of an Icon cue (Icon Options: icon source, Size & Orientation, Border & Background): "icon
options should have their own nested text options to display things like progress / duration; stacks; absorb values; etc".

## Cause
- The cue editor (`OutcomesEditor.lua`, EmbedCue) put the cue's Text section from `acts.text`, the old Actions tab's "Text" banner.
- Since Options 0.6.1 (commit 9b7251a) the cue's Actions tab is the new one (On Initialization / During / After). It has no `text`
  entry; only the parts table (`xuiParts`) was carried over. So `acts.text` was nil and Icon / Texture cues showed no text options.
  Only Text cues had them, through `parts.textBody`.
- Found by the new test: on the old file the Text section is missing from both cues (7 of its checks fail).

## What changed (`XayaUI_Options/OutcomesEditor.lua`)
- Icon and Texture cues: a group "Text: duration, stacks / charges, absorb" inside the Icon / Texture Options box (order 900, after
  the box's own sections), holding the cue's three text parts from `parts.textBody`, each with its own on / off and style.
- The box gets its own copy of the art options' table, so the shared table used by the rule's other panes is not changed.
- Text cues are unchanged (flat, with duration text switched on).
- Not checked: whether XayaUI draws these texts on a cue that the combat engine draws in combat. `USER-GUIDE.md` says the engine
  gives a rule's other time / stack displays their own slots; this change only restores the settings.
- `USER-GUIDE.md`, QA B68.

## Tests
- `tests/icon_cue_text_run.py` (new, 12 checks), the real settings tree in the stand-in game with an Icon, a Texture and a Text cue:
  - the section is inside each box, with the three parts, after the box's sections, and not repeated below;
  - each box has its own table;
  - the Text cue stays flat.
  - Negative control: the old file fails 7.
- `tests/lua_pitfalls_run.py`, `tests/cue_sound_guard_run.py`, `tests/delete_keeps_rule_run.py`: pass.
