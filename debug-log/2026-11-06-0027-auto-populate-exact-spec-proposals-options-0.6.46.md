# Auto-populate table built exactly to Xaya's spec; every addition turned into a proposal (Options 0.6.46)
Logged 2026-11-06 00:27 UTC. Engine session, branch `claude/fervent-cerf-hldtwn` (main 7426e7f merged in at 708c3af). Not on main.

## Why
Xaya's standing rules (2026-11-05, relayed by session S1 and written in docs/process/REQUEST-LOG.md / VERIFICATION.md V15-V17):
- "stop interpreting my suggestions if they appear prescriptive. reiterate them with confirmations if you are uncertain."
- "do not guess and implement without providing proposals around that guess with confirmation."
- One landing per round.

She also told this session directly, of her column list: "note I don't suggest them just for fun, they are prescriptions for initial
display pane configurations".

Measured against V16 ("an extra element ... is a defect. Anything not specified is proposed and confirmed first"), 0.6.44-0.6.45 had:
- one label changed: her "when available / when ready" shortened to "When ready";
- extra elements: a title with a count, a help paragraph, paging, Reload list / Close buttons, spec name rows, "Hide advanced";
- guessed defaults: a debuff's trigger switched to When missing for speech / sound cues; speech text; a starting sound; texture art;
  icon grid positions; cue names; the talents option narrowed to the current spec.

## Built now (exactly her spec, plus only what the table cannot work without)
- A frame below the spec buttons. Title " ": AceConfigDialog draws a group with an empty name as a plain group with no box
  (AceConfigDialog-3.0.lua:1135-1140), and a single space keeps the box with no title text.
- Header row: tick box (ticks every row; clicked again unticks them all) | Name | Type | Trigger | Cue type | Combat load.
- Columns and their values:
  - Type: Spell CD, Aura, Debuff.
  - Trigger: "When available / when ready" and "At max stacks" (cooldowns); "When present" and "When missing" (auras, debuffs). Her
    words.
  - Cue type: every cue type the addon has (0.6.45).
  - Combat load: Any, In combat, Out of combat.
- Every row is shown (no paging).
- At the bottom: "Advanced" (shows or hides the Extra cues column: her answer "Extra cues"), plus what is needed to work:
  - "Make the ticked rules" and its one-line result;
  - a line when there is nothing to list.
- Defaults: unticked, and the first choice of each of her columns (When available / when ready or When present, Icon, Any).
- Cues start exactly as "+ New rule" starts that type (ns.NewTypedCue) and nothing more: no speech text, no sound, no art, no position,
  default cue names.
- "Include talents I have not picked" behaves as before, for every spec.
- Kept from her spec: groups `<Class> > <Spec> > <cue type>` with each rule named after its spell. P1 asks her to confirm this reading.

## Proposals waiting for her (CONFIRM; none of these is built)
- P1. "class » specialization » cue type » name": the last step read as the rule's own name (the spell's name) inside the cue-type
  group. Other reading: one group per name.
- P2. Pages of 40 rows. Every row is 6-7 controls, and the window redraws all of them on each click. INFERENCE, not measured in game:
  an all-specs list of ~200 rows could make each click slow. QA B153 asks for `/xui perf` numbers.
- P3. A frame title ("Auto-populate: <Spec> (<N> offered)") and a two-line help text.
- P4. "Reload list" and "Close" buttons.
- P5. In the all-specs list, the spec's name above its rows, or a Spec column. Without either, rows of different specs look alike.
- P6. Cue starting content:
  - speech: "<name> ready" (cooldown), "<name> missing" (When missing), "<name>" (When present);
  - sound: the game's raid warning sound (the seed rules' default);
  - texture / progress texture: the spell's own icon as art, stored as a file so it still counts as a Texture;
  - shown cues laid out in rows of 8 instead of all at the screen centre.
- P7. A debuff's trigger defaults to When missing when its cue is Speech or Sound (a reminder to put it back up).
- P8. "Include talents I have not picked" read for the current spec only. INFERENCE: the game reads "known" for the active spec only, so
  with the option off every talent cooldown of another spec is left out.
- P9. Wording of "Make the ticked rules", its result line, the empty-list line and the tooltips.
- P10. Cue names "<spell> (icon)" / "(speech)" etc. instead of the default "<spell> (cue)".
- P11. Row order: Spell CD, then Aura, then Debuff; by name within each.
- P12. Column widths (tick 8 %, Name 24 %, Type 11 %, Trigger 20 %, Cue type 19 %, Combat load 18 %).
- P13. Cue-type group names: Icons, Progress Textures, Textures, Text, Speech, Sounds (the Smart Categories names).
- P14. After Make, keep the ticks (as now) or untick the rows that were made.
- P15. Progress bar: needs a design first (RM-BARS, the WeakAuras reference she named). Until then it is listed "(not yet)".
- Capability limit (not a proposal): auras and debuffs are listed for the spec you are in only. The core debuff / aura learner already
  proposed (E24 in the request log) would remove this limit.

## Verification
- `tests/auto_picker_run.py`: 54 checks, now asserting the exact spec. They cover:
  - her labels verbatim;
  - nothing extra in the table: the only keys are the header, the rows, Advanced, Make and its line;
  - the first-choice defaults, and no trigger linked to the cue;
  - the cues starting empty, as "+ New rule" starts them;
  - the talents option applying to every spec.
- Negative control: on 5a57952 (0.6.45) the test fails 10 checks.
- `tests/auto_table_layout_run.py`: 23 checks, now including "the table sits in a frame". With the empty name the check fails (no
  InlineGroup): it found the box disappearing, fixed with the one-space title.
- docs/process/REQUEST-LOG-session-014bN6tV8wAAEXAShpTKqUfz.md: every request of hers in this session (V15).
- Nothing was run in game.
