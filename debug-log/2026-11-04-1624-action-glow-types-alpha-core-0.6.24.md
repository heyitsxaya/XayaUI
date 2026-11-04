# Actions > Glow a frame: every glow type with its own settings, color with opacity, offsets and layer (XayaUI core 0.6.24; fork: main)
Logged 2026-11-04 16:24 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Request (Xaya, 2026-11-04)
- #249: "All color pickers should support transparency."
- "glow tends to have several glow type options. check what are available and make sure support for each type is available in
  addition to colorizing and opacity / positioning options".

## What was checked first
- **Color pickers (#249):** 16 `type = "color"` options in the addon folders (`/Libs/` excluded); 15 already had `hasAlpha`. The one
  without was the Actions glow color (`XayaUI/Actions.lua:186`). It stored only R, G and B and was drawn with alpha 1
  (`Actions.lua:112`). `Theme.lua`'s only ColorPickerFrame use is a repaint guard, not a picker of its own. Colors written as text
  escape codes still cannot carry opacity (as #249 says).
- **Glow types available:** the Actions glow uses LibCustomGlow-1.0, which XayaUI does not ship: another addon (ElvUI, BigWigs ...)
  provides it.
  - Read in its public source (github.com/Stanzilla/LibCustomGlow, `LibCustomGlow-1.0.lua`, MINOR 25, 2026-11-04). Only behaviour
    and signatures were recorded; no code was copied.
  - `lib.glowList` has exactly four glows: Pixel Glow, Autocast Shine, Action Button Glow, Proc Glow. The Actions tab already
    offered all four, but passed only a color.
  - Each type's settings and defaults:
    - `PixelGlow_Start(r, color, N=8, frequency=0.25 (negative reverses), length=auto, th=1, xOffset, yOffset, border (on unless
      false), key, frameLevel=8)`;
    - `AutoCastGlow_Start(r, color, N=4, frequency (period 8, i.e. 0.125; negative reverses), scale=1, xOffset, yOffset, key,
      frameLevel)`;
    - `ButtonGlow_Start(r, color, frequency, frameLevel)`: frequency > 0 sets `throttle = 0.25/frequency*0.01` for the moving
      border, default throttle 0.01 (= 0.25). It has **no offset**: the library cannot move the button glow;
    - `ProcGlow_Start(r, {color, startAnim=true, xOffset, yOffset, duration=1, key, frameLevel=8})`.
  - **Alpha:** pixel, autocast and proc use `color[4]` in `SetVertexColor`; the button glow uses it in its alpha animation.
  - The copy loaded in game may be older (not checked); QA B58 asks for its version if a setting has no effect.
- **Other glows in XayaUI:** the display's "Glow & Outline" settings (`Options.lua:1821`, drawn by `Visual.lua`). Those are XayaUI's
  own drawing, with color, strength (opacity), size, gap, style and pulse, not LibCustomGlow types. The proc-glow code
  (`Conditions.lua`, `ProcGlows.lua`) only reads Blizzard's glows. Neither was changed. Whether the display glow should also offer the
  four library types is a question for Xaya: it would make the display glow depend on another addon's library.

## What changed (`XayaUI/Actions.lua`)
- **Color:** `hasAlpha = true`; opacity saved as `glowA` (nothing kept when fully opaque); drawn as `color[4]` for every type.
  A non-number is drawn as 1; values are clamped to 0-1.
- **For every type except the button glow:** Offset X / Y (-40..40 px).
- **For every type:** Layer (frame level 1-50, default 8).
- **Per type, each shown only while that type is chosen:**
  - pixel: Lines, Speed (-2..2, negative = reverse, 0 = default), Line length (0 = from the frame), Thickness, Dark border;
  - autocast: Sparkle groups, Speed, Sparkle size;
  - button: Speed of the moving border;
  - proc: Loop length, Start flash.
- **Defaults:** a setting at its default (or 0 where 0 means default) is not saved, and nil is passed, so the library's own default
  applies. A saved value that is not a number passes nil; out of range is clamped (`GN`), so damaged data never reaches the
  library.
- **Caught by the new test before commit:** the first version wrote `x and false or nil` in four places. That always yields nil, so
  unticking Dark border or Start flash would never have been saved or drawn. Rewritten with plain `if` statements.

## Scope (V4)
`git grep "glowR\|glowType\|LibCustomGlow"`: only `XayaUI/Actions.lua` reads and writes these settings (options, `GlowStart`,
`GlowStop`). `ns.ActionsPane` is built by `Options.lua` for the Actions tab. `Profile.lua` strips only `code` / `codeOn` from imports,
and the new fields are plain numbers and booleans.

## Tests
- `tests/action_glow_run.py` (new, 34 checks): a stand-in LibCustomGlow records what each type is handed. Covered:
  - the color picker offers opacity;
  - old rules draw opaque;
  - opacity 0.4 reaches all four types;
  - nothing set passes nil for every setting;
  - each type's settings show only for that type, and the button glow has no offset;
  - settings set through the options reach the library;
  - defaults and 0 keep nothing;
  - damaged values are dropped or clamped.
- **Negative control:** on the previous `Actions.lua`, 11 checks fail (`hasAlpha` nil, alpha 1 after picking 0.4 on all four types,
  the opacity-related checks). The run then stops with an error at the first per-type setting, which does not exist there.
- QA: B58.
