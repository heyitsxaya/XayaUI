# Four Generate buttons per spec and for the class, each filters the list; Select all tick box (Options 0.6.54)

Logged 2026-11-06 18:58 UTC. Session 014bN6tTRFsCmBvVCUDVtrds, branch `claude/rule-generation-buttons`, built ON TOP OF the engine branch `claude/fervent-cerf-hldtwn` (Options 0.6.53) at her answer. NOT on `main`: it lands with that branch. UNTESTED in game.
Version note: 0.6.54 follows 0.6.53 on that branch; the coordinator session may renumber at landing (as it did for 0.6.53).
Request log: REQUEST-LOG-session-014bN6tTRFsCmBvVCUDVtrds.md GEN-1 to GEN-4.

## Her words (verbatim, V16) and what is built
- "change auto-populate buttons to say "Generate Rules for {spec}"" and "four buttons per specialization auto-generation: "Generate All Rules for {Spec}" "Generate CD Tracking Rules for {Spec}" "Generate Aura Tracking Rules for {Spec}" "Generate Target Debuff Tracking Rules for {Spec}"": every spec button is now the four, her labels verbatim (`AP.ButtonLabel`, AutoPicker.lua). Read: the first bullet is superseded by the four (she did not object).
- "clicking these buttons should THEN generate a list below. no rules should be auto-shown without a button being clicked first": already the case on the engine branch (`AP.view` is nil until a button is pressed); `main` (0.6.42) listed on page open, which is what her screenshots show. A test asserts no table and no view before a press.
- "these buttons filter out what rules display below": `AP.Load(spec, filter)` with filter all / cd / aura / debuff; `AP.FilterRows`; Reload list, the Hide / Show switch and "Include talents I have not picked" keep the filter.
- "missing select all tick box option to select all": a tick box named "Select all" above the header row (`T.selAll`); ticks and unticks the rows shown only.
- Her answers (question box, 2026-11-06): build on the engine branch table; the class gets the same four ("... for my class"); one Select all tick box at the top of the list.

## Choices that were NOT hers (V16: flagged, each easy to change)
1. The header-row tick box (her earlier column spec, "clicking the header row will select all") is KEPT beside the new Select all. She picked "one tick box at the top of the list", not "both"; removing the header one would drop her earlier prescription. Asked in QA B160.
2. The spec icon stays in front of each spec button's text (it was on the old buttons). The class buttons have none.
3. Button width 3.0 (about 460 px, ESTIMATE: 154 px per unit from the old 1.6-wide button, about 246 px in her screenshot, at 7 px per character). Longest label with an 11-letter spec is about 53 characters. Buttons wrap when the pane is narrow, so a row holds one or two buttons. Not measured in game.
4. New text: when a list is empty the message depends on the button (Aura / Debuff for another spec: "Auras and target debuffs are read from your Cooldown Manager for the spec you are in now. Switch to <Spec>, then press the button again."; CD: "Nothing to list yet: play this spec once (its cooldown list is read from your spellbook)."; Aura / Debuff for your spec: "Nothing to list yet: add your auras and debuffs to the Cooldown Manager."). It is shown as text (arg.xuiKeep), not folded into the (i) icon on the title: the (i) fold hid the old message behind an icon.
5. The page intro said "Press a spec's Auto-populate button (or the one for your whole class)": reworded to name the Generate buttons. The title "Auto-populate: <Spec>" and the header "Auto-populate my class / spec" are unchanged (she asked about buttons only). Question for her: should the title name the button pressed?

## V4 scope (git grep)
- `AP.Load` callers: Options.lua BuildClassCreator (spec buttons, class button, talents switch), AutoPicker.lua (Reload list, the Hide / Show switch). All pass the filter now.
- Button keys changed: `apSpec<i>` and `apClass` became `apSpec<i>all|cd|aura|debuff` and `apClass<filter>`. Readers: tests/auto_picker_run.py only (updated); `git grep apSpec apClass` finds nothing else.
- `AP.Make`, `AP.Candidates`, `AP.Cols`, `AP.Title`, grouping and rule making are untouched: a filtered list makes rules exactly as an unfiltered one.
- Docs: USER-GUIDE 12.1 and section "Where"; QA B151 / B152 button names; QA B160 added.
- Not touched: `ns.ClassAutoPopulateSpec` / the old skeleton path (no UI calls it on the engine branch).

## API facts (V2)
No new game call. Auras and debuffs still come from `C_CooldownViewer` (hasAura, selfAura: INFERENCE, unchanged from 0.6.53, docs/reference/api/namespaces.md:1370-1371, structures.md:1798).

## Tests (V1, V5, V11)
tests/auto_picker_run.py: 77 -> 98 checks. New checks assert what the player sees: the four labels per spec and for the class, no button says "Auto-populate", nothing listed before a press, each filter lists its own kind (3 / 2 / 2 in the stand-in), another spec's Aura button lists nothing and says to switch, the class buttons, Reload and the talents switch keep the filter, Select all above the header row, ticks the rows shown only, unticks, agrees with the header and bucket boxes, and an estimated-fit check for the button width (V11).
Negative control: the same test file against the 0.6.53 source (XayaUI_Options stashed) stops at the first new check with "attempt to index field 'apSpec2all' (a nil value)" (exit 1). One existing check (V16, "nothing she did not ask for is in the table") was changed on purpose to allow her Select all.
