# Fade / flash / gray-out placement: reference review and re-asked questions (build 0.5.108, fork: main)
Logged 2026-11-03 19:41 UTC. Issue #284. Session: https://claude.ai/code/session_014bN6tSgdZHF5adcz8FmUXA

Request (Xaya): review how a mature aura addon presents its Display and Conditions options (its source, not copied; a local build of its option tables was used to read the real panels). Note that our Cues + Conditions tabs pair up to that addon's Display + Conditions by a different route. Then re-ask the placement questions.

What the reference does (source-read; partial option-tree dump from a stubbed Lua 5.1 load of its region files):
- Display = one element's static look, plus sub-elements (glow, border, text, tick, extra textures) added as their own sections.
- Conditions = IF / Else If checks on trigger state, then property changes on that look, plus sound, chat and code.
  - "Remaining time" checks are scheduled to the exact moment they are crossed.
- Animations = Start / Main / Finish. The Main animation can be timed relative to the aura's lifetime; that is how a fade over the duration is done there.
- Conditions cannot start an animation (no animation property among the condition-changeable properties). Flash near expiry is not a native condition; its presets use a glow change instead.
- Gray on cooldown is a condition (a color change to gray) written by its templates, not a Display toggle.

Ours: Cues tab = the look of each cue (many cues per rule, sound and speech included). Conditions = IF checks, THEN which cues play, plus per-cue modifiers (glow, desaturate, opacity, tint, strata).
Questions re-asked in chat: placement of gray-out, flash and fade; splitting the mislabeled "Animation Options" section. Nothing changed in code.
