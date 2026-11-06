# Open questions for Xaya: engine session (014bN6tV8wAAEXAShpTKqUfz)

Asked 2026-11-06, at her request: "send me all the questions you need answering for this segment".

- Every item is a proposal or a decision only she can make (V16). Nothing listed here is built.
- An answer such as "A1 yes, A2 b" is enough.
- Where a recommendation is given, it is marked as such. The reasons are stated, and they are inferences unless a source is cited.

## A. Auto-populate table (PR #409, Options 0.6.44-0.6.46): built exactly to her spec; these are the additions

- **A1 (P1).** In "class » specialization » cue type » name", is "name" the rule's own name (the spell's name), with each rule inside its
  cue-type group? (Built that way.) Or should "name" be a group per name?
- **A2 (P2).** Show the list 40 rows a page?
  - Every row is 6-7 controls, and the settings window redraws them all on every click.
  - INFERENCE, not measured in game: the all-specs list (~200 rows) may make each click slow.
  - QA B154 asks for a `/xui perf` reading.
- **A3 (P3).** A title on the frame (e.g. "Auto-populate: Vengeance (42 offered)") and a two-line help text: yes / no?
- **A4 (P4).** "Reload list" and "Close" buttons: yes / no?
- **A5 (P5).** In the all-specs list, show which spec each row belongs to:
  - (a) the spec's name above its rows;
  - (b) a Spec column;
  - (c) nothing (as built).
- **A6 (P6).** What new cues start with. Today they start empty, as "+ New rule" starts them. For each, yes / no:
  - (a) speech says "<name> ready" (cooldown), "<name> missing" (When missing) or "<name>" (When present);
  - (b) sound starts with the game's raid warning sound;
  - (c) texture / progress texture start with the spell's own icon as art;
  - (d) shown cues are laid out in rows of 8 (today they all start at the screen centre).
- **A7 (P7).** A debuff whose cue is Speech or Sound defaults to "When missing" (a reminder to put it back up): yes / no?
- **A8 (P8).** "Include talents I have not picked": apply it to the spec you are in only?
  - With it off today, every talent cooldown of your OTHER specs is hidden too, because the game answers "known" only for the active
    spec.
- **A9 (P9).** Wording, or give your own:
  - the button "Make the ticked rules";
  - its result line ("Made 4 rule(s) in Demon Hunter > Vengeance (4) ...");
  - the empty-list line;
  - the hover tooltips.
- **A10 (P10).** Cue names: "<spell> (icon)" / "(speech)" / ..., or the default "<spell> (cue)"?
- **A11 (P11).** Row order: Spell CD, then Aura, then Debuff, by name within each. OK, or another order?
- **A12 (P12).** Column widths as built: tick 8 %, Name 24 %, Type 11 %, Trigger 20 %, Cue type 19 %, Combat load 18 %. OK?
- **A13 (P13).** Cue-type group names: Icons, Progress Textures, Textures, Text, Speech, Sounds (the Smart Categories names). OK?
- **A14 (P14).** After Make: keep the ticks (as now), or untick the rows that were made?
- **A15 (P15).** Progress bar needs a design first (RM-BARS, the WeakAuras reference you named). It stays "not yet" until then. OK?
- **A16 (P16).** A spell icon beside each name in the Name column: back in, or out (as now)?
- **A17 (P17).** Progress bar and Custom (the addon has neither yet):
  - (a) listed, marked "(not yet)", never made (as now);
  - (b) listed without the marker;
  - (c) left out until they exist.

## B. Cooldown Manager warning (on main: core 0.6.48 / Options 0.6.43). S1 has asked you this too; one answer covers both.

Your sentence: "this _____ requires blizzard's cooldown manager to track it before it can be tracked by the addon."

- **B1.** What fills the blank?
  - (a) "aura" / "debuff";
  - (b) the aura's name;
  - (c) "aura (<name>, <ID>)" (as built);
  - (d) something else.
- **B2.** The second sentence I added: "In the Cooldown Manager's settings, move it to Tracked Buffs or Tracked Bars (the game hides it in
  combat, encounters, Mythic+ and PvP)." Keep or remove?
- **B3.** When the Cooldown Manager does not offer that aura for your spec, I show a different line: "This aura (...) cannot be tracked
  in combat: the game hides it there, and Blizzard's Cooldown Manager does not offer it for your current spec." Keep it, or always show
  your sentence?
- **B4.** "Enable tracking" button. The game offers no call to add an aura to the Cooldown Manager. Two possible routes:
  - (1) call Blizzard's own settings code: risky, because XayaUI could break the Cooldown Manager's hidden-aura reading (inference from
    Blizzard's code);
  - (2) rewrite the saved Cooldown Manager layout: undocumented, needs a /reload, and can be overwritten by Blizzard's window.
  Try route 2 as a one-off in-game test first (Dev Assist), then decide? yes / no.

## C. Learning auras and debuffs per spec

- **C1.** Build a core learner that records each spec's Cooldown Manager auras and debuffs while you play that spec, as cooldowns are
  learned today?
  - It lets the all-specs table list them for every spec, not only the one you are in.
  - It also lets the spell data capture hold debuffs (your earlier question).
  - yes / no.

## D. Rule engine decisions (from the engine-issue triage, 2026-11-04)

- **D1 (B5).** The cooldown trigger's "Track: Auto / Charges / Spell cooldown" choice. Proposal:
  - Auto = today's behaviour;
  - Charges = always count charges;
  - Spell cooldown = ignore charges: ready while the spell's own cooldown is not running.
  Accept, change, or drop the choice?
- **D2 (B6).** "Track even if not known": wanted at all? (The game reports a spell you do not know as "ready".)
- **D3 (#375).** The speech cue's sound channel. The game's speech call `C_VoiceChat.SpeakText(voiceID, text, rate, volume, overlap)`
  has no channel. The speech cue already has voice, speed and volume. Options:
  - (a) close #375 as not possible;
  - (b) speech keeps the game's speech output, and only sound cues get the group sound-channel override (#372);
  - (c) both (a) and (b).
- **D4 (#115 / D7).** Is up to 50 ms between a change in the game and its sound acceptable? If not, it becomes part of #309
  (event-to-rule routing).
- **D5.** Close the issues the triage found obsolete or superseded: #303, #93, #280, #294, #67, #19? And #365, which you confirmed on
  0.6.8? (Reasons per issue in section F.)
- **D6.** Positioning decisions implied by EllesmereUI's unlock mode (behaviour only; the code belongs to the Options session):
  - #268: two-point anchors;
  - #61: snap vs anchor;
  - arrow-key nudges;
  - changes held until Save;
  - #343: which drag.
  Details in section F.
- **D7. Disabled rules "cost nothing at all"** (your "ideally, yes"). What a disabled rule costs today (read in the code):
  - the engine still visits it on every step, which is cheap: two checks (Engine.lua `StepRule`);
  - it keeps a runtime record;
  - the display refresh still builds its display frame (hidden) if its display was on (Visual.lua `ns.RefreshAllVisuals`);
  - the charge watcher already skips it.
  Proposal:
  - (a) the engine leaves disabled rules out of its list entirely;
  - (b) a disabled rule's display frame is never built, and is released when you switch the rule off;
  - (c) the settings window still lists it under Disabled, so it can be switched back on.
  Accept (a)-(c)?
- **D8. "DO NOT RELEASE" pre-created rule** (the rule half; the click-blocking cover is S1's). Proposal, built from existing parts:
  - trigger: Player State "alive" = No;
  - load: in a raid group, during a boss encounter;
  - cue: a large red text "DO NOT RELEASE" at screen centre, plus the raid warning sound;
  - offered in the Class/Spec Rule Creator as a "pre-created rule" (your word: "Rule templates is a bit of a misnomer. They are
    pre-created rules").
  Open points:
  - (i) "alive = No" is also true after you release (as a ghost). Should it hide once you are a ghost? That needs a small new check.
  - (ii) Text, size, colour, sound?
  - (iii) Only raids, or dungeons too?

## E. Group page (docs/plans/GROUP-PAGE-REVIEW-2026-11-04.md; the code belongs to the Options session)

- **E1.** Tab order and the default tab: Config | Group | Display | Load, or Group | Config | ...? Which tab opens first?
- **E2.** Group Sort on Config: the existing Sort (Manual / Default / Expiration / Name / Important + Reverse)? Should static groups see it?
- **E3.** Type and Sort on Config (#372), or Sort beside Grow on the Group tab (screen 2)?
- **E4.** Group Size:
  - (a) auto or set, with clip and wrap as separate tick boxes;
  - (b) a third "specific size" mode where you pick clip or wrap.
  Should auto fit only the items that are showing?
- **E5.** Border / background: a fixed box, or fitted to the items showing?
- **E6.** Strata, opacity, scale: stay on Display ("Whole group") or move to the Group tab?
- **E7.** Align / distribute / space: one-shot buttons, or saved values that keep applying? On the Group tab or on Display?
- **E8.** Delete / New / Enable buttons: on Config, in a row above the tabs, or only in the sidebar's right-click menu?
- **E9.** #262 / #59: which option should change what on screen? Should static items scale to fit the box?
- **E10.** Nested groups: offer "anchored to: screen / parent group" (screen 8)? And the #268 wording.
- Contradictions between your notes (one answer each):
  - #372 puts Position / Growth / Size on a "Group Display" tab; a later instruction puts them on the Group tab and reverts the rename.
  - #372 puts Sort on Config; AURA-PLAN 3a and screen 2 put it beside Growth.
  - Strata: screen 1 says the Group tab; #131 and the code use Display.
  - Icon size: AURA-PLAN says the Group tab; the code has it on Display.

## Her answers (2026-11-06, question prompts; verbatim where she typed text)
- A1: rule's own name (as built).
- A2: decide after a perf test (QA B154).
- A3: title and help text.
- A4: both Reload list and Close.
- A5: a Spec column.
- A6 (split): speech: cooldown says its name; aura ends: "_____ ended"; When present: "custom"; plus "a tick box underneath for STT to
  'customize'". Sound: "same as previous: request customization from the user". Texture / progress texture: "force choice from drop
  down list". Placement: spread in rows of 8.
- Cue set-up controls: an extra column (preview: [x] Customize / sound picker / picture picker per row).
- Forced pick unmet: "all rules completed get made; the ones that don't stay in the tray and an alert pops saying "error issue making
  the following rules: []. Please finish configuring them to create them.""
- A7: yes, When missing for debuffs with Speech / Sound.
- A8: "depends on the button pressed -- spec or all dependent"; for another spec: show them all.
- A9: button "Populate".
- A10: named by type ("<spell> (icon)").
- A11: "Type, then A-Z, with clear headers and the ability to full deselect full buckets".
- A13: OK as built.
- A14: remove made rows from the table.
- A15: "yes, new window will build to drop excessive context" (progress bar designed in a new session).
- A16: "icon and name only in the creation process -- don't embed in the actual rule name".
- A17: listed "(soonTM)".
- B1: "This aura / debuff (name) requires..."
- B2: keep the second sentence.
- B3: "Blizzard's Cooldown Manager does not offer in-combat tracking for this aura for your current spec. Rule might not work reliably."
  Note: "(EUI allows you to add extra things to track via custom aura bars -- we can figure out workarounds like overlaying textures on
  them and setting the actual bars to zero, ex)".
- B4: explore the EUI-style workaround (custom aura bars, textures overlaid, bars set to zero): a proposal first.
- C1: "determine performance cost first".
- D1: "customized" -> "force user choice like with other cue customizations".
- D2: "a spell as not known currently due to talents must have the load condition talent known baked in. this is true for all
  talent-dependent or -modified abilities".
- D3: "allow for the option of speech channel override but otherwise allow sounds to be set to their own channel (generally SFX)";
  told speech cannot take a channel: no speech override (no emulation); sound cues get their own channel, SFX by default.
- D4: 50 ms not acceptable -> part of #309 routing.
- D5: "unknown, push to progress bar cues session".
- D7: "1 unless 2 has more performance cost" (engine skips disabled rules; no frame; Disabled tab still lists them).
- D8: hide as a ghost; load "configurable, by default raid only"; look: "black box over the "release" button that says "NO RELEASE"
  (customizable); also allow cycling through flavor texts (configurable) "BAD MONKEY," "death comes for us all," "NOPE," "Disagree,"
  "WTB Rez"".
- D6: #268 separate points; #61 lasting anchor (as built); #343 rule rows in the sidebar; arrow-key nudges yes; moves held until Save.
- #334 files: both (quieter copies + slider moved to Settings).
- #278 item 2: "requires further testing in game -- refer to EUI codebase to see how you can manually add buff tracking through his
  cooldown manager".
- #23: "Rules that would only track something if a talent is known should be talent dependent loads and not fire if the talent is
  [NOT] selected" (confirmed: load only while the talent is picked).
- #18: "If instance type is not specified, it has no bearing on the rule loading and firing and should not be considered. This is true
  for all options that are not outright specified in some way".
- #2: three-click toggle (Known green / Not known red / not set).
- #278 items 5 / 6: "This is not true. I can track sigil of chains slow on an enemy as well as sigil of silence and sigil of misery.
  Nova and imprison also track. Reevaluate this" -> re-check in code and game before any proposal.
- A12: fit contents.
- Group page (for the Options session): tabs Group | Display | Load | Config (Group first); Sort beside Grow on Group; size = auto or
  set + clip / wrap tick boxes; auto fits the showing items, border follows; strata / opacity / scale on Group; align / distribute /
  spacing saved and kept applying; Delete / New / Enable on Config; nested groups get "anchored to: screen / parent group"; static
  group scaling: "Toggle / prompt"; icon size on Group; position / growth / size on Group (no "Group Display" rename).

## Round 2 answers (2026-11-06 ~05:50 UTC, engine session 2 = session_014bN6tV8wAAEXAShpTKqUfz continuation; question prompts)
- Speech Customize: "Small typing window" (ticking Customize opens a small window to type the text; the cell then shows the text).
- Speech, aura / debuff "When present": "Says the name" (starts saying "<name>"; Customize lets her change it; never blocks the row).
- Extra cues needing a set-up: "1 for now, flag for potential revision pending feedback" (option 1 = own controls per extra in the
  Cue set-up cell; unpicked = row unfinished). FLAGGED: may be revised after her feedback.
- The unfinished-rows alert: "Popup window with OK" (game-style popup, her exact text, OK button).

## Round 3 answers (2026-11-06 ~17:00 UTC; question prompt)
- Her message: "3 across, offset down, 3 across, return to center and offset up" / "This applies only to rules auto populated that have
  not yet been manually moved".
- Shape: "Rows centred on C": each row of 3 centred on the screen centre; rows in the order centre, below, above, further below, further
  above, alternating (replaces the 3 x 3 blocks).
- Not moved: "Re-laid out together": on each Populate every auto-populated cue not moved by hand is placed again with the new ones in one
  pattern; cues she moved stay where she put them and are left out.

## Round 4 answers (2026-11-06 ~19:10 UTC; question prompt)
- D7: "Accept 1-3": (1) the engine skips disabled rules entirely after a one-time switch-off clean-up; (2) a disabled rule (and its cues)
  never gets a display frame, and its frame is freed when switched off; (3) the Disabled tab still lists them.
- D7 preview: "Still works": the sidebar eye / headphone preview of a disabled rule still works; its frame exists only while previewed.

## Round 5 answers (2026-11-06 ~21:10 UTC; question prompt)
- D8: "Rule drives the cover": the Release Guard cover's on/off moves into a pre-created rule (its Load decides where it is active),
  instead of QoL's own setting. Needs S1's agreement (S1 owns the cover).
- D1 (Track: Auto / Charges / Spell cooldown as a forced choice): "unsure what this is -- defer for now unless flagged as an essential solve
  for functionality". Deferred; not essential (Auto is today's behaviour and works).
