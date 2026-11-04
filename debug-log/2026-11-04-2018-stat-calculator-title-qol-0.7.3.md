# The toolkit panel's title reads "Stat Calculator" (XayaUI_QoL 0.7.3; fork: main)
Logged 2026-11-04 20:18 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Request
Xaya, 2026-11-04 (screenshot of the toolkit's Stats tab): "'character toolkit' title should be changed to `Stat Calculator`".

## What changed
- `XayaUI_QoL/CharacterToolkit.lua`: the panel title is "Stat Calculator".
- Kept as they are, until she says otherwise: the settings page (QoL > Character Toolkit), the chat messages, and `/xui stats`.
  "Title" was read as the panel's title.
- `USER-GUIDE.md` 12.12, QA E1q.

## Open (asked 2026-11-04)
- "stats pane should be stat value calculator": rename the Stats tab, or make it compute what a point of each stat is worth?
- "'sheet' tab is not intended to be a tab but instead a reskin of the character pane" and "prettify the character window":
  task 40, design first.

## Tests
- `tests/char_toolkit2_run.py` (+1, 152 checks): the title.
- Negative control: the old file fails it ("Character Toolkit").
