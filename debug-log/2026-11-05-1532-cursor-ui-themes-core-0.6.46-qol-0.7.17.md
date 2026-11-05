# Cursor trail colors as UI themes, and the UI theme as cursor colors (core 0.6.46, QoL 0.7.17)
Logged 2026-11-05 15:32 UTC. Session 014bN6tWZxqCW85vMEyHdfnt (a worktree agent), branch `worktree-agent-a05d20aefb62fe08e`, based on
`b8017df`. Not pushed; not on `main`.

## Request (Xaya, 2026-11-05, her words)
"map cursor theme colors to UI themes and provide them as theming options as well"

Reading (decided by the main session, both parts opt-in; nothing changes for a user who does not pick them):
1. Each Gradient Cursor Trail gradient becomes a UI base theme in Settings > Theme. The gradient data moves to core so the themes
   work with XayaUI_QoL switched off and both read one table. Keys, names and colors unchanged.
2. The trail gets a "Match the UI theme" gradient and the Cursor Highlight a "Use the UI theme's accent" option, both following
   theme changes, both costing nothing while the cursor features are off (V14).

## Change
- `XayaUI/Theme.lua` (core 0.6.46):
  - `T.CURSOR_PRESETS` / `T.CURSOR_PRESET_ORDER`: the nine gradients, moved verbatim from `XayaUI_QoL/CursorTrail.lua`
    (fel, fire, ocean, aurora, sunset, vapor, rainbow, gold, ice; names Fel ... Frost; colors as they were).
  - `T.Luminance`, `T.Contrast` (WCAG 2.x), `T.MIN_TEXT_CONTRAST = 4.5`, `T.CursorPalette(stops)` (the rule below).
  - Nine built-ins `T.BUILTIN["cursor_<key>"] = { name = "Cursor trail: <Name>", pal = T.CursorPalette(...), cursorPreset = key }`,
    appended to `T.BUILTIN_ORDER` after the color blind ones. The Theme page (`XayaUI_Options/ThemeEditor.lua`, unchanged) lists
    `T.BUILTIN_ORDER` in the Theme list and in Custom's "Start from" list, so they appear in both.
  - `T.TrailStops()`: the gradient for the trail's "Match the UI theme" (rule below).
  - `T.OffResolve(fn)`: takes a theme listener out again (new list built, so a Resolve that is running finishes on the old one).
- `XayaUI_QoL/CursorTrail.lua` (QoL 0.7.17): the local gradient table is gone; `PRESETS` / `PRESET_ORDER` are core's tables
  (`ns.CURSORTRAIL_PRESETS` is the same table object). "Match the UI theme" (saved value `preset = "theme"`) in the Gradient list,
  after the nine gradients, before Custom; `Stops` asks core's `TrailStops`; a theme listener is added only while the trail is on
  AND set to it, removed otherwise. Fallback for a mismatched install (QoL with an older core): white trail, never an error.
  The on/off toggles (`enabled`, `overview.highlightOn` / `trailOn`) were not touched (a parallel change moves them).
- `XayaUI_QoL/CursorHighlight.lua` (QoL 0.7.17): `useThemeColor` (default false) and the toggle "Use the UI theme's accent" on the
  Color and Size tab; the shape is drawn in `ns.Theme.cur.accent` while it is on; the color picker is greyed out (the own color is
  kept and used again when the option is off); a listener re-lays the shape on a theme change, only while the highlight is on AND
  the option is on; a highlight hidden at that moment (combat only, turning) stays hidden.
- `tests/cursor_trail_cost_run.py`: loads core's Theme.lua before CursorTrail.lua (the trail now reads core's gradients); its
  numbers are unchanged (693.3 calls a frame at 5,000 px/s, as before).

## The derivation rule (comment in `T.CursorPalette`)
Only the highlight tokens come from the gradient; everything else keeps the XUI default (window, panes, title bar, borders, button
and tab surfaces, body text, muted text, tree bars, Danger), so every cursor theme is dark with near-white body text.
With `stops` = the gradient, head (next to the cursor) first:
- main = the second color (the first step away from the head; in seven of the nine presets the head is the pale end and the
  second color the gradient's own hue; Vaporwave's head is pink and Rainbow's red, so there it is simply the second color).
- accent = tabSelBorder = main. accentText = main mixed 35 % toward white (the lighter tint Class colors uses).
- label = buttonText = the lightest color of the gradient (highest relative luminance): the most readable color for the most
  read text.
- gradStart (parent-group glow) = the last color (the trail's tail) scaled so its brightest channel is 0.45 (the XUI default
  glow's); tabSelBg = main scaled to 0.30, alpha 0.9 (the default selected tab's); primaryBg = main scaled to 0.45, alpha 0.95;
  primaryBorder = main x 0.85 (as Class colors).
- Readability: accent, accentText, label, buttonText are mixed toward white in 5 % steps until they read at 4.5:1 or better on
  windowBg (accent counts as text: the footer's version link is drawn in it, Options.lua `c.info.Paint`). gradStart and tabSelBg are
  darkened in 5 % steps until body text and accentText read at 4.5:1 on them; primaryBg until buttonText does (both alpha-blended
  over windowBg first).

UI theme -> trail (`T.TrailStops`): a cursor theme (picked, or the "Start from" of a Custom theme whose accent, accentText and
gradStart are not changed) gives exactly its gradient; any other theme gives accentText -> accent -> gradStart (light at the cursor,
dark at the tail, the order the presets run in). The highlight takes `accent`.

## Contrast (WCAG 2.x, computed in `tests/cursor_ui_themes_run.py --report` from the tokens the game resolves)
Calculation: relative luminance L = 0.2126 R + 0.7152 G + 0.0722 B of the linear values (sRGB v -> v / 12.92 when v <= 0.04045,
else ((v + 0.055) / 1.055) ^ 2.4); ratio = (L_lighter + 0.05) / (L_darker + 0.05). windowBg = (0.06, 0.06, 0.06), L = 0.00491.
Background with alpha: blended over windowBg first. Example: Fel accent (0.15, 0.80, 0.45): linear (0.0196, 0.6038, 0.1706),
L = 0.0042 + 0.4319 + 0.0123 = 0.4483; (0.4483 + 0.05) / (0.00491 + 0.05) = 9.08.
Text pairs need 4.5; the last three columns are not text (reported only).

| Theme | accent | accentText | label | buttonText | text on gradStart | accentText on gradStart | text on tabSelBg | accentText on tabSelBg | buttonText on primaryBg | tabSelBorder | primaryBorder | gradStart |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Fel | 9.08 | 11.55 | 14.40 | 14.40 | 11.37 | 7.48 | 9.96 | 6.55 | 4.76 | 9.08 | 6.60 | 1.55 |
| Fire | 8.23 | 10.95 | 16.55 | 16.55 | 10.37 | 6.46 | 12.35 | 7.69 | 7.81 | 8.23 | 6.01 | 1.69 |
| Ocean | 8.96 | 11.50 | 16.99 | 16.99 | 13.72 | 8.98 | 11.56 | 7.57 | 7.15 | 8.96 | 6.52 | 1.28 |
| Aurora | 11.23 | 13.21 | 14.64 | 14.64 | 9.93 | 7.47 | 10.57 | 7.95 | 5.32 | 11.23 | 8.08 | 1.77 |
| Sunset | 8.31 | 11.10 | 15.27 | 15.27 | 12.09 | 7.64 | 12.28 | 7.76 | 7.15 | 8.31 | 6.07 | 1.45 |
| Vaporwave | 7.04 | 10.20 | 15.26 | 15.26 | 7.76 | 4.51 | 12.92 | 7.50 | 7.83 | 7.04 | 5.20 | 2.26 |
| Rainbow | 10.63 | 12.95 | 17.43 | 17.43 | 10.54 | 7.77 | 11.23 | 8.27 | 7.01 | 10.63 | 7.68 | 1.67 |
| Gold | 13.17 | 14.91 | 17.91 | 17.91 | 7.27 | 6.17 | 10.28 | 8.72 | 6.25 | 13.17 | 9.42 | 2.42 |
| Frost | 13.96 | 15.57 | 19.13 | 19.13 | 9.51 | 8.42 | 10.00 | 8.86 | 6.41 | 13.96 | 9.97 | 1.85 |

For comparison, the XUI default: accent 4.91, accentText 8.90, label 13.10 on the same background.
No preset needed lightening (every text color already read at 7.04:1 or better). One needed darkening: Vaporwave's tail
(0.30, 1.00, 0.90) scaled to 0.45 gave accentText on the glow 3.02:1; darkened five steps (to brightest channel 0.3375) it is 4.51:1.
The lightening path is tested with a made-up dark gradient (no preset needs it).

Derived colors (r, g, b, alpha):
| Theme | accent | accentText | label / buttonText | gradStart | tabSelBg | primaryBg | primaryBorder |
|---|---|---|---|---|---|---|---|
| Fel | .15 .80 .45 | .4475 .87 .6425 | .35 1 .25 | .2912 .1059 .45 | .0562 .30 .1687 /.9 | .0844 .45 .2531 /.95 | .1275 .68 .3825 |
| Fire | 1 .55 .10 | 1 .7075 .415 | 1 .95 .40 | .45 .09 .09 | .30 .165 .03 /.9 | .45 .2475 .045 /.95 | .85 .4675 .085 |
| Ocean | .15 .75 .95 | .4475 .8375 .9675 | .70 1 1 | .05 .10 .45 | .0474 .2368 .30 /.9 | .0711 .3553 .45 /.95 | .1275 .6375 .8075 |
| Aurora | .20 .85 .95 | .48 .9025 .9675 | .30 1 .60 | .3553 .1421 .45 | .0632 .2684 .30 /.9 | .0947 .4026 .45 /.95 | .17 .7225 .8075 |
| Sunset | 1 .55 .30 | 1 .7075 .545 | 1 .90 .45 | .18 .135 .45 | .30 .165 .09 /.9 | .45 .2475 .135 /.95 | .85 .4675 .255 |
| Vaporwave | .75 .50 1 | .8375 .675 1 | .30 1 .90 | .1013 .3375 .3038 | .225 .15 .30 /.9 | .3375 .225 .45 /.95 | .6375 .425 .85 |
| Rainbow | 1 .70 .10 | 1 .805 .415 | .95 1 .20 | .3079 .1421 .45 | .30 .21 .03 /.9 | .45 .315 .045 /.95 | .85 .595 .085 |
| Gold | 1 .82 .25 | 1 .883 .5125 | 1 .98 .75 | .45 .2812 .0563 | .30 .246 .075 /.9 | .45 .369 .1125 /.95 | .85 .697 .2125 |
| Frost | .65 .90 1 | .7725 .935 1 | 1 1 1 | .135 .2475 .45 | .195 .27 .30 /.9 | .2925 .405 .45 /.95 | .5525 .765 .85 |

## Scope (V4, `git grep`)
- Gradient table readers: only `XayaUI_QoL/CursorTrail.lua` (Stops, the Gradient list, "Copy a preset into Custom", the
  `ns.CURSORTRAIL_PRESETS` / `_ORDER` exports, which nothing else reads); `tests/cursor_trail_cost_run.py` loads the file alone.
- `T.BUILTIN` / `T.BUILTIN_ORDER` readers: Theme.lua (`IsBase` -> `CleanUnder`, `Save`'s name check, `CheckTheme` on import,
  `Snapshot`, `BasePalette`, `SavedPalette`, `EffBase`), ThemeEditor.lua (Theme list values / sorting, Start from values / sorting).
  Effects: a cursor theme works as a base, a Start from, in saved themes and in imports; `T.Save` now refuses the nine keys
  `cursor_<key>` as theme names; a theme string with such a base imported into an older core falls back to the XUI default.
- Where the derived tokens are drawn (the contrast pairs come from this list): accent: footer version text (Options.lua
  `c.info.Paint`), Game Menu button accent (GameMenu.lua `Accent`), `xui-list-selected` bg, `xui-popup` border; accentText: selected
  rule-list row (`TREE_SEL`), tool-button hover / lit text (Skin.lua `HoverCol`, on the tabSelBg box when lit), footer hover;
  gradStart: the parent-group banner (`ns.TREE_GRAD`, left to black, row text on it); tabSelBg / tabSelBorder: `xui-tab-selected`
  (Options Skin.lua tabs and tool buttons, Chat Skin.lua tabs, QoL CharacterReskin and CharacterToolkit tabs), text = body text;
  label: Skin.lua `GOLD`, `xui-label`, `xui-titlebar`; buttonText: `xui-button`, `xui-button-primary`; primaryBg / primaryBorder:
  `xui-button-primary` (the Add buttons, delete).
- `T.OnResolve` users (none removes itself): GameMenu.lua, XayaUI_Chat/Core.lua, Options.lua (footer link), Options/Skin.lua (2),
  QoL CharacterReskin.lua, CharacterToolkit.lua. `T.listeners` is read only by `T.Resolve` (tests/chat_world.lua and
  tests/char_toolkit2_run.py stub their own).
- `cursorHighlight.color` readers: CursorHighlight.lua `Layout` and the page's color get / set. `cursorTrail.preset` readers:
  CursorTrail.lua `Stops`, the page's get / set.
- Saved data: new `CueRulesDB.cursorHighlight.useThemeColor` (filled with false by `Ensure`), new value `"theme"` for
  `CueRulesDB.cursorTrail.preset` (an older QoL reads an unknown key as Fel), `CueRulesDB.theme.base` may be `cursor_<key>`.
- No new file; no .toc file list change; XayaUI_Options not changed.

## Game API (V2)
No new game call. The new code uses only calls the cursor files already made (`Texture:SetVertexColor`, `Frame:SetAlpha` via the
existing `Layout`) and plain Lua math.

## V14 (off costs nothing)
- Trail: the theme listener exists in core's list only while the trail is on AND set to "Match the UI theme"; switched off, or on
  another gradient, it is removed (`T.OffResolve`). Highlight: only while it is on AND "Use the UI theme's accent" is on.
- With both saved off, login creates no cursor frame and adds no theme listener (same listener count as a session with XayaUI_QoL
  switched off); nine theme changes then create nothing and compute no trail colors (tested).
- Level reached (V14 limit 1): XayaUI_QoL is an always-loaded addon, so its files are still read at login.
- The nine palettes are built when core loads (themes are not a tick-box feature): 0.107 ms for all nine in lupa Lua 5.1 on this
  machine (not a game timing); `T.TrailStops` 0.0008 ms a call, run on a theme change only.

## Inferences (not verified in game)
- INFERENCE: the order in which core's and QoL's PLAYER_LOGIN handlers run is not documented. Nothing depends on it: if the trail
  or highlight applies first, it uses the theme colors resolved so far (`T.cur` starts with the XUI defaults) and the listener
  recolors it when core resolves (PLAYER_LOGIN and again PLAYER_ENTERING_WORLD).
- INFERENCE: contrast is computed against the windowBg token as an opaque color. In game the window background is drawn at the
  window opacity (/xuiskin alpha, 0.62 by default) over the game world, so over a bright scene the real contrast is lower than these
  numbers; that cannot be computed offline. 4.5:1 is WCAG's level AA value for normal-size text, applied to every text token.
- How the nine themes look in game (and whether Xaya likes the mapping) is not checked.

## Decisions made here (Xaya did not specify; each is open to her change)
1. Theme keys `cursor_<preset key>` (kept apart from saved-theme names), shown as "Cursor trail: <Name>", listed after the color
   blind themes and before Custom; also offered in Custom's "Start from".
2. Tokens taken from the gradient: besides accent, accentText, gradStart, tabSelBg, tabSelBorder also label, buttonText, primaryBg,
   primaryBorder (every other colored built-in, Class colors included, tints those too). So labels and headings are not the default
   gold, and the Add buttons are not red, in these themes.
3. The mapping (main = 2nd color, accentText = 35 % tint, labels = lightest color, glow = tail) and the 5 % lighten / darken steps.
4. accent is held to 4.5:1 like the text tokens (it is the footer's version text since Options 0.6.39). Backgrounds that carry
   text (glow, selected tab, primary button) are darkened until the text on them reads at 4.5:1.
5. Frost's labels come out white (its lightest color is white) and Gold's cream: close to body text there.
6. "Match the UI theme" sits after the nine gradients, before Custom; it is not offered in "Copy a preset into Custom".
7. A Custom theme on a cursor theme keeps the exact gradient on the trail unless its accent, accentText or gradStart is changed
   (then the trail takes those three); class-level color overrides are not looked at.
8. Highlight: the accent's color only; its own Opacity setting stays; the color picker is greyed out while the option is on (the
   saved own color is kept and comes back when the option is off); the toggle is the first row of Color and Size.
9. `T.OffResolve` added to core so a switched-off feature's listener is removed rather than left in place returning at once.
10. ThemeEditor.lua not changed: the Theme list's tooltip still names only the older kinds of theme (no Options version needed).
11. The data went into Theme.lua, not a new core file (no .toc change).

## Tests
- `tests/cursor_ui_themes_run.py` (new; the real addons in the stand-in game, three sessions: fresh with both cursor features
  saved off, XayaUI_QoL switched off, an existing user; 131 checks, 11 deliberate breaks):
  - New code: 131 passed; all 11 breaks caught (each makes 1 to 10 checks fail).
  - Old code (`b8017df`, separate worktree, the same test file): 122 checks ran (the 9 others need the highlight option or
    `T.CursorPalette`, which it lacks), 67 failed, 55 passed; the breaks do not apply there (the text is not in the old files).
    The 55 that pass on the old code: 12 are steps the old code also performs (it stores any theme base or gradient name: "picking
    ... sets the theme" x9, "trail set to Match the UI theme", the red accent after a Custom change, "QoL not loaded"); 43 are guards
    that hold on the old code by design: XUI defaults kept (9), text contrast (9: the old code resolves an unknown base to the
    default palette, which also passes), V14 (12), existing users unchanged (13). Their negative control is the breaks: recoloring
    body text, no lightening, no darkening, a Custom's own accent ignored, OffResolve removing nothing, the trail listener kept on
    another gradient / when off, every gradient treated as Match the UI theme, the highlight listener kept with the option off, a
    hidden highlight shown by a theme change, the highlight option on by default. Not covered by a break: the two "no frame at
    login" checks (existing V14 behaviour) and the two TrailStops counters (a second signal next to the listener counts).
  - Parity (V5): the derived palette is computed again in the test (Python) from the gradients as they were at `b8017df` and
    compared token by token with what the game resolves; the trail dots are compared with a Python gradient at set ages.
- `tests/cursor_trail_cost_run.py` (updated): 8 checks, 3 breaks, FAILS: 0; same numbers as before the change.
- `python3 tests/lua_pitfalls_run.py`: 78 files, FAILS: 0. Every changed Lua file compiled with Lua 5.1 `loadstring`.
- Full suite, `XUI_API_INDEX=<index> python3 tests/run_all.py` on the final code (file hashes checked before and after the run):
  89 of 89 `tests/*_run.py` ok; whole-addon harness 33 of 33 combinations ok (0 fail; 1 warning each, the existing
  `debugRecord.lines` drift, also with core alone); `ALL CHECKS PASS`. The index was built from the repository's own
  `docs/reference/api/api.json` (4,970 functions, 1,784 events, 76 widget method lists) with a copy of the uncommitted helper
  `tests/harness/api_index_from_docs.py` found in the main checkout, written outside the repository; `tests/harness/api_index.json`
  does not exist in this checkout.
- QA-CHECKLIST: B118 (the theme list and the look), B119 (Custom on a cursor theme), E1z8 (trail Match the UI theme), E1z9
  (highlight accent).
