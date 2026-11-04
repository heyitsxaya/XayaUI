# Reference: proc art and button highlights by aura (docs/reference/procs.md; no addon code changed)
Logged 2026-11-04 06:27 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Why
- In combat the game hides most auras from addons.
- The events that light a button (`SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` / `_HIDE`, `IsSpellOverlayed`) and the screen-edge proc art (`SPELL_ACTIVATION_OVERLAY_SHOW` / `_HIDE`) carry no secrecy flag in the 12.1.5 API documentation.
- So a button that only one aura can light tells, by its glow, that the aura is up.
- Blizzard's own handler draws the proc art keyed by the event's spell ID and checks the "show proc art" setting only when drawing (`Blizzard_FrameXML/SpellActivationOverlay.lua:23-33`). The event therefore arrives even with the art turned off.

## Source (facts only)
- Blizzard's client data tables for build 12.1.5.70783 (live on 2026-11-04), as published by wago.tools. Xaya allowed `wago.tools` in the session's network settings for this.
- Tables used:
  - `SpellActivationOverlay`, `SpellClassOptions`, `ChrClasses`, `SpellName`;
  - `SpellAuraOptions`, `SpellMisc`, `SpellDuration`;
  - `SkillLineAbility`, `TraitDefinition`.
- IDs, names and numbers only. No descriptions or other Blizzard text.
- Nothing from any other addon was used.

## What it found (inference until checked in game)
- **Boiling Point (#315):** aura 1265968 lights Blood Boil (50842), and no other aura lights Blood Boil. Base duration 15 s, 1 charge.
- **Divine Arbiter (#332):** none of these buttons is lit by Divine Arbiter alone, so the glow needs the character's talents and set bonus to rule out the other auras.
  - 1306161 lights Divine Storm (53385). Five other auras light Divine Storm, among them Empyrean Power.
  - 1306162 lights Templar's Verdict / Final Verdict (85256 / 383328). Four other auras light those.
  - A third Divine Arbiter aura, **1310461**, lights both buttons.
- Spot checks against how the game is known to behave: Rime → Howling Blast, Killing Machine → Obliterate, Crimson Scourge → Death and Decay, Dark Succor → Death Strike.

## Limits
- "Which buttons an aura lights" = the aura's class set and the spells whose class mask shares a bit with the row's highlight mask. This is the community's reading of these columns, not confirmed in game.
- Not covered:
  - auras with no row;
  - anything the server decides at run time;
  - which spell ID the glow event reports when a spell is replaced.

## Next (task #28)
1. A GameDump probe confirms the glow events in combat.
2. Then a "Spell glows" trigger, built from Blizzard's API docs, with Boiling Point as the first case.

Files: `docs/reference/procs.md` (new), `docs/reference/build_procs.py` (new), `docs/reference/README.md`, this entry, `MANIFEST.md5`.
