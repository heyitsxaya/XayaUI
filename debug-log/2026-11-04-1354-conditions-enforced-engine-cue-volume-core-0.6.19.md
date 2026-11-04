# Conditions are enforced on engine-drawn displays (#260); a cue's own volume for game sounds (#334) (XayaUI core 0.6.19, XayaUI_Options 0.6.15; fork: main)
Logged 2026-11-04 13:54 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Requests (Xaya, 2026-11-04)
- **#260:** "I'm not sure I understand #260. If a condition is enabled it should be enforced in or out of combat."
- **#334:** "Insivius wanted a modifier on the sound cue file itself like the slider for text to speech allows".

## #260: what was wrong
- **The engine ignored conditions.** It draws a rule's first display through Blizzard's aura container, and it showed that display
  whenever the aura was up, even when a condition listing the display was false. It did not draw the condition's changes (opacity,
  grey, tint). Verified in the code: `XayaUI/Combat/AuraDisplay.lua` Allowed checked only load, talents and "only on an action
  bar"; `mods` was not read anywhere in the file.
- **What the player saw** (inference): a conditional icon showing when it should not, and condition changes missing. This is
  Xaya's #260 report, "condition modifications do not apply".

## #260: change
- **Show / hide (Allowed).** A display cue that a condition lists (`ns.CueGated`) shows only while XayaUI's own reading of that cue
  is true. That reading is Cues.lua EvaluateCue `info.result`: one of its switched-on conditions is true.
  - This runs in the engine's existing 0.25 s sync, which already showed and hid slots for load and talents, in combat too
    (pcall'd).
  - It covers single slots and dynamic-group members alike. Groups use SetAuraGroupEnabled / the candidate filter, as for load.
- **Condition changes (ApplyMods).** On a single slot, the true condition's opacity (button alpha), grey (SetDesaturation) and tint
  (SetVertexColor) are drawn on the art and buttons XayaUI made for that slot (recorded in ButtonInit). When the changes end, the
  art is painted again from the display's own settings.
- **Not drawn by the engine (stated in /xuiengine and the guide):**
  - glow and strata;
  - any change inside a dynamic group (the icons there are the game's own).
- **Consequence.** A condition XayaUI cannot read in combat (stacks, a hidden aura time) is not met there, so its display stays
  hidden in combat. That is what "enforced" means under the rule "unknown never fires".

## #334: change
**Facts:**
- `C_Sound.PlaySoundWithOptions(params)` takes `volumeOverride`, for sound kits only (12.1.5 docs, PlaySoundParams).
- Blizzard uses it, on a 0-1 scale (`Blizzard_CombatAudioAlertManager.lua:803`, `CooldownViewerAlert.lua:178`).
- `PlaySoundFile` is not in the generated docs; it takes a file and a channel, with no volume.

**Built:**
- "This cue's volume" (0-100 %) on Sound cues.
- For a [Game] sound below 100 %, the sound plays through PlaySoundWithOptions with volumeOverride. If that call is refused, it
  plays the old way.
- For files, the slider is greyed out with the reason.
- **Not decided yet:** quieter copies of the 33 bundled CC0 sounds (ffmpeg is available to make them); moving the shared
  channel-volume slider out of the cue editor.

## Checks
- **`tests/aura_display_run.py` section 19** (real engine build and sync):
  - checks:
    - a listed display is still engine-drawn;
    - hidden when its condition is false;
    - shown when it is true;
    - hidden when it is unknown;
    - opacity 0.3, grey and red tint drawn;
    - repainted with its own opacity when the changes end;
    - an unlisted display follows the aura as before;
  - **negative control:** the committed AuraDisplay.lua fails 4 (false, unknown, opacity, grey / tint).
  - A check on the `/xuiengine` wording also passed on the old code, so it proved nothing and was removed.
- **`tests/cue_volume_run.py`** (new, 8 checks): runs the real ns.PlaySound. On the committed Sound.lua it fails at once.
- Related suites pass: load_class, cue_fire, aura_gaps. Full suite: see the commit.

Docs: USER-GUIDE (5, 12.9); QA-CHECKLIST B48-B49; DECISIONS-2026-11-04 decisions 1 and 4 updated.
Files: XayaUI/Combat/AuraDisplay.lua, Sound.lua, XayaUI.toc (0.6.19); XayaUI_Options/Options.lua, XayaUI_Options.toc (0.6.15);
tests/aura_display_run.py, tests/cue_volume_run.py (new); USER-GUIDE.md, QA-CHECKLIST.md, docs/process/DECISIONS-2026-11-04.md,
this entry, MANIFEST.md5.
