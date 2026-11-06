# Auto-populate table: every cue type, set up like "+ New rule"; the drawn layout tested (Options 0.6.45)
Logged 2026-11-06 00:15 UTC. Engine session, branch `claude/fervent-cerf-hldtwn`, on top of 1ebba9a (Options 0.6.44, the table; not on
main yet).

## Request (Xaya, her words, two screenshots of the 0.6.42 picker that is on main)
1. "need to fix display and follow proposed rule of columns and type as specified. also need to actually display proposed column names
   -- note I don't suggest them just for fun, they are prescriptions for initial display pane configurations"
2. On the cue dropdown (Speech / Icon / Progress texture / Progress bar (not yet)): "also note ALL cue types that are supported by the addon
   need to be included in this dropdown menu"

## 1. Display, columns, column names
Her screenshots are of 0.6.42, the picker on main: tick box + name, then a cue dropdown one grid column away, the debuff's "On the
target" on a line of its own, no column names. 1ebba9a (0.6.44, on the PR branch, not yet in game) already replaced it with her table:
a header row Name | Type | Trigger | Cue type | Combat load and one line per row. New here: `tests/auto_table_layout_run.py` checks the
table as AceGUI DRAWS it, not only the option table. It opens the real window in the stand-in game and measures the widgets:
- the column names in her order;
- every row on one line, each cell exactly under its column name;
- rows stacked without overlapping;
- the rows end inside the framed box.
It checks this at the default size, with Advanced, and with the window 200 px narrower.
- Negative controls: on main's code it fails at its first check. With the new table but main's Skin.lua, 6 checks fail (the 30 px grid
  gutter pushes the cells out of line and past the box).
- Found while measuring: AceGUI's own InlineGroup lays its content out 1 px wider than its content frame (`content.width = width - 20`,
  border inset 1 px, AceGUIContainer-InlineGroup.lua). That is stock behaviour, and it stays inside the box's 10 px padding. The test
  allows 1 px there.
- Not measurable offline: whether a long value is cut inside its closed dropdown. The stand-in measures text by character count. QA B151
  asks for a screenshot.

## 2. Every cue type
- The addon's cue kinds are Sound, Speech, Text, Texture, Icon and Custom (Cues.lua `ns.CUE_KINDS` / `ns.CUE_KIND_LABEL`). The
  "+ New rule" types built on them add Progress Texture (a texture cue with fill) and Progress Bar.
- The Cue type dropdown now lists all eight: Icon, Progress texture, Progress bar (not yet), Texture, Text, Speech, Sound, Custom (not yet).
- Two are listed but not made, and the message says so:
  - Progress bar: "+ New rule" makes a Buff Bar for it, but the buff bar module is shelved (`shelved/Bars.lua`, not loaded).
  - Custom: the cue pane says custom cues are "not available yet" (OutcomesEditor.lua).
- Extra cues (Advanced) offer the six that exist.
- Groups: Icons / Progress Textures / Textures / Text / Speech / Sounds, the Smart Categories names where there is one.
- Each cue is now set up exactly as "+ New rule" sets up that type. The set-up moved out of Options.lua `CreateRuleOfType` into
  `ns.NewTypedCue(rule, type)`, which both use, so the two cannot drift apart. The "+ New rule" behaviour is unchanged (same code, moved).
  - Icon: spell icon, 64 x 64, gray on cooldown.
  - Progress Texture: a TEXTURE cue with fill and overlay, base at 0.35. Before, the table made an icon cue with fill, unlike "+ New rule".
  - Text: text cue, duration text, no art.
- Added for the table only:
  - Texture and Progress texture start with the spell's own icon as their art, as a file (`kind = "file"`), so they show something and
    still count as Textures, not Icons, in Smart Categories (`ns.SmartMatch`).
  - Shown cues are laid out in rows of 8, 72 px apart, to fit the 64 px size.

## Verification
- `tests/auto_picker_run.py`: 52 checks (every cue kind listed; the shared set-up per type; texture art and Smart Categories; text cue;
  extra text cue; Textures group; Custom not made). With 1ebba9a's code it fails 9 checks.
- `tests/auto_table_layout_run.py` (new): 20 checks, with the negative controls above.
- Nothing was run in game. QA B151-B155.
