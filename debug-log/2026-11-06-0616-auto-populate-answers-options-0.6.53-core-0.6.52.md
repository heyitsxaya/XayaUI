# Auto-populate table rebuilt to Xaya's answers; Cooldown Manager message wording (Options 0.6.53, core 0.6.52)

Version note: built as Options 0.6.49; renumbered 0.6.53 at landing (main reached 0.6.50; 0.6.51 / 0.6.52 are held by #417 / #418; coordinator session 014bN6tSy3HbUDWYQsk69naX, 16:57 UTC).

Logged 2026-11-06 06:16 UTC; placement changed and renumbered 17:10 UTC. Engine session 2 (continues session 014bN6tV8wAAEXAShpTKqUfz; branch claude/fervent-cerf-hldtwn, PR #409).
Request log: REQUEST-LOG-session-014bN6tV8wAAEXAShpTKqUfz.md E25, E26, E27, E33, E23 (wording), E34. UNTESTED in game.

## Her spec (V16): every item is her answer, nothing added beyond it
Source: docs/process/QUESTIONS-engine-session.md, "Her answers" (A1-A17, B1-B3) and "Round 2 answers" (asked this session in the
question prompt, 2026-11-06 ~05:50-06:05 UTC):
- A3 title + help text (her "Accept proposal": "Auto-populate: <Spec>" / "Auto-populate: <Class> (all specs)", the two help lines);
  A4 Reload list + Close; buttons in one row Advanced | Populate | Reload list | Close (accepted); A5 a Spec column after Name (accepted).
- A11 buckets Spell CD / Aura / Debuff with clear headers, each with its own tick box; A-Z within.
- Cue set-up column. Speech: "[ ] Customize"; ticking opens "Small typing window" (her round-2 answer); default text: cooldown = its
  name, When missing = "<name> ended", When present = its name ("Says the name"). Sound / Texture / Progress texture: a picker that must
  be picked (A6 "request customization" / "force choice from drop down list"). Extra cues: "1 for now, flag for potential revision pending
  feedback" = own controls per extra in the same cell. FLAGGED for revision.
- Unfinished rows: not made, stay ticked in the table, popup with OK ("Popup window with OK") showing her text verbatim:
  "error issue making the following rules: [<names>]. Please finish configuring them to create them."
- A7 debuff + Speech / Sound -> When missing (only while she has not picked a trigger herself).
- A8 talent switch: the spec you are in follows it; another spec lists all its talent cooldowns (the learned list holds them all:
  ClassLearn.lua calls ns.CollectCooldownSpells(0, true)).
- A9 "Populate"; A10 cue names "<spell> (<cue type>)" (cueName and name); A14 made rows leave the table; A16 icon + name in the table only;
  A17 "(soonTM)"; A12 widths fit contents.
- Placement (her message 2026-11-06 ~17:00 UTC, E36: "3 across, offset down, 3 across, return to center and offset up" / "This applies only
  to rules auto populated that have not yet been manually moved"; her answers "Rows centred on C" and "Re-laid out together"; it replaces
  the 3 x 3 blocks of dde9f0d): rows of 3 centred on the screen centre (the 2nd cue of a row on it), rows in the order centre, below,
  above, further below, further above. Each placed cue remembers its place (visual.autoPos); on each Populate the cues whose position is
  still that place are laid out again with the new ones; a cue moved by hand no longer matches and keeps its position.
- "Hide / Show already generated rules (can potentially cause duplicates)": hidden by default; on: listed unticked ("on repopulated without
  selecting them"), the header tick box re-selects all, Populate makes a ticked one even though its rule exists.
- B1 "Right word + name": "This aura (<name>) requires ..." / "This debuff (<name>) ..."; B2 second sentence kept; B3 verbatim.

## My choices inside her answers (invisible or flagged; listed so she can overrule)
- Spacing: 4 px between cues; the step is the largest cue laid out (64 px icon, 128 px texture / text default) + 4. NOT confirmed by
  her: QA B154 asks for a screenshot. Rows keep alternating below / above without limit; with very many cues they reach the screen edge.
- "Already generated" = a rule with the same trigger (spell / aura, state) anywhere under <Class> > <Spec>.
- Speech "Customize" with an empty box or Cancel leaves it as it was. Unticking returns to the default text.
- The "Choose a sound" / "Choose a picture" entries are red: they are the "marked" rows of her accepted help text.
- Result line, empty-list line and tooltips keep their 0.6.46 wording with "Make" -> "Populate" (A9 settled only the button; the rest
  is still OPEN for her).
- The typing window's title "Speech text for <name>".
- The table's help text keeps arg.xuiKeep, so the window's info pass (Options.lua) does not fold it into an info icon.

## Scope (V4)
- XayaUI_Options/AutoPicker.lua (rewritten from 0.6.46; carry-over V9: candidates from the learned list / spellbook / Cooldown Manager,
  the 0.6.42 "when" read, the Class > Spec > cue type groups, the duplicate check, talent cooldowns load only while picked, every cue
  type, Advanced extra cues: each kept and still tested).
- XayaUI_Options/Options.lua: ns.SoundChoices, ns.TexChoices, ns.ApplyArtPick (the cue editor's "Or pick art" now calls ns.ApplyArtPick:
  the same code moved, no change of behaviour); BuildClassCreator texts ("Populate").
- XayaUI_Options/Skin.lua: arg.xuiSubCell (the 2nd+ control of one table cell: no 4 px gutter before it and not counted in the row's
  gutters), so a row whose Cue set-up cell holds two controls keeps every column aligned. Only AutoPicker.lua sets it.
- XayaUI/Triggers.lua ns.CdmNeedText; its only reader is XayaUI_Options/DisplayTab.lua ns.CdmWarnArg (Display tab and Cues tab).

## Game API (V2)
- StaticPopup_Show / StaticPopupDialogs with hasEditBox: the same pattern as XAYAUI_RENAME (Options.lua), raised to TOOLTIP strata over
  the FULLSCREEN_DIALOG settings window. No new game call. Placement writes the cue's visual x / y, the offsets Visual.lua already anchors
  to the screen centre.

## Tests (V1, V11)
- tests/auto_picker_run.py rewritten (75 checks): order by type then A-Z, A8 per button, A7, A6 texts, title / help, exactly the allowed
  elements, button row order, bucket headers + bucket ticks, Cue set-up controls (Customize opens the typing window and the cell shows the
  typed text; red "Choose" pickers; extra cues sharing the cell), Populate with unfinished rows (her alert verbatim, made rows leave,
  unfinished stay), set-ups carried into the cues, A10 names, the placement (row order, centring, re-layout of unmoved cues, a moved cue kept), Reload / Hide-Show / duplicate,
  all-specs Spec column and title, Close.
- tests/auto_table_layout_run.py extended: the Cue set-up column (a split cell measured from its first control's left to its last's
  right), the Spec column (all-specs list), the bucket headers on one line inside the box.
- tests/cdm_warn_run.py: B1 exact text (name, no ID), debuff word, B3 exact text, ID fallback.
- Negative control: the new auto_picker test on the 0.6.46 AutoPicker.lua stops at its first missing piece (AP.DefaultSay); the cdm test
  on the old Triggers.lua fails 3 checks (old text "(Spell 1001, 1001)" and "cannot be tracked in combat").

## Not verified
- Nothing here was seen in game. Font widths are estimated by character count (A12): a long sound name may be cut inside its dropdown.
- QA: B151-B155 rewritten for 0.6.53 (they were never released); B159 for the message wording.
