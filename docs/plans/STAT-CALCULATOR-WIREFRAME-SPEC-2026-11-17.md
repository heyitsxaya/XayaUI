# XayaUI wireframe spec: Stat Calculator panel + Improved Character Display

Taken from code only. Read-only; nothing in either repo was changed.

## Conventions

- Every measure cites `file:line`. A value worked out from cited constants shows its arithmetic and is marked **derived**. Anything that is not in the code is marked **INFERENCE**.
- Units are WoW UI units (pixels at UI scale 1). y grows downward inside the panel's content frame (the code places at `-y`).
- File aliases:
  - **SC** = `/home/user/XayaUI-main/XayaUI_Bonus_StatCalculator/StatCalculator.lua` (main, fda1e29)
  - **SM** = `/home/user/XayaUI-main/XayaUI_Bonus_StatCalculator/StatModel.lua` (main)
  - **LD** = `/home/user/XayaUI-main/XayaUI_Bonus/StatCalculatorLoader.lua` (main)
  - **MOD** = `/home/user/XayaUI-main/XayaUI/Modules.lua` (main; core spacing)
  - **TH** = `/home/user/XayaUI-main/XayaUI/Theme.lua` (main; theme tokens)
  - **ICD** = `/home/user/XayaUI/XayaUI_QoL/ImprovedCharacterDisplay.lua` (branch claude/stat-calculator-v25, dd97910)
  - **CR** = `/home/user/XayaUI/XayaUI_QoL/CharacterReskin.lua` (same branch)
  - **QSM** = `/home/user/XayaUI/XayaUI_QoL/StatModel.lua` (same branch; the model ICD reads)
- **Fonts:** XayaUI's theme font (`ns.Theme.FontPath()`) is used where the code calls SetFont. The fallback is the template's own font (SC:327-336) or `Fonts\FRIZQT__.TTF` (ICD:501, ICD:520-523). Where the code never calls SetFont, the size is the Blizzard template's default (the template name is given; its size is **INFERENCE**).
- **Colors** are theme tokens. The default base theme is `"class"` (TH:113): the class color drives `accent`, `label`, `buttonText`, `tabSelBg` and `border` (TH:142-158). The base token defaults (TH:24-44) and the code's own fallbacks are listed in §0.

---

## 0. Shared spacing and theme tokens

```json
{
  "ns.Style": {
    "margin": 10, "gutter": 10,                       // MOD:602-603
    "UI_MARGIN = Style.margin, UI_GUTTER = Style.gutter" : "MOD:625",
    "divider.size": 1,                                // MOD:618
    "nest": {"child": 8, "level": 8},                 // MOD:612 (settings left pane)
    "switch.size": 16,                                // MOD:614 (tick box on a settings tree row)
    "tabTop": {"h":32,"font":14}, "tabSub": {"h":27,"font":11.5}, "tabSection": {"h":24,"font":11,"minW":60}  // MOD:606-610 (settings window tabs)
  },
  "theme tokens (XUI defaults, TH:24-44)": {
    "accent": [0.75,0.25,1.00,1], "label": [1.00,0.82,0.00,1], "text": [0.96,0.96,0.98,1],
    "textMuted": [0.60,0.60,0.65,1], "windowBg": [0.06,0.06,0.06,1], "paneBg": [0.04,0.04,0.04,1],
    "border": [0.30,0.30,0.30,1], "titleBar": [0.13,0.13,0.13,1], "buttonBg": [0.04,0.04,0.04,0.70],
    "buttonText": [1.00,0.82,0.00,1], "tabBg": [0.03,0.03,0.03,0.70], "tabSelBg": [0.22,0.10,0.30,0.90],
    "tabSelBorder": [0.80,0.50,1.00,1], "danger": [1.00,0.12,0.12,1]
  },
  "class base overrides (TH:142-158)": {
    "accent": "class color", "label": "mix(class, white, 0.25)", "buttonText": "mix(class, white, 0.25)",
    "tabSelBg": "class*0.28, a 0.9", "border": "mix(0.30 grey, class, 0.15)"
  },
  "classes (TH:61-71)": {
    "xui-window": "bg=windowBg, border=border", "xui-titlebar": "text=label", "xui-pane": "bg=paneBg",
    "xui-tab": "bg=tabBg, text=label", "xui-tab-selected": "bg=tabSelBg, text=text",
    "xui-button": "bg=buttonBg, text=buttonText", "xui-label": "text=label", "xui-text": "text=text",
    "xui-text-muted": "text=textMuted"
  }
}
```

---

# SCREEN 1: Stat Calculator panel (main, fda1e29)

## 1.1 What it is and how it opens

- It is a load-on-demand addon, `XayaUI_Bonus_StatCalculator`. It is loaded at login only while the switch is on (LD:13-16, LD:83-91).
- It is OFF by default: `enabled = false` (SC:107).
- On main there is **no Stat Calc button on the character window**. Main has no Improved Character Display, so the panel opens and closes with the character window, from the minimap list row, and from `/xui stats` (SC:15-17).
- Minimap list row (LD:169-171):
  - id `"stats"`, label `"Stat Calculator"`, `order = 12`.
  - Its hover text is `"Show or hide the Stat Calculator on its own, without the character window (also /xui stats)"`.
  - It is hidden while the calculator is not loaded, while it or its panel is off, and in combat (LD:23-24).
- Frame name `XayaUIStatCalculator` (SC:361). It is added to `UISpecialFrames`, so Esc closes it (SC:819-823).

## 1.2 Panel frame

```json
{
  "default size": {
    "width": 450,                         // PANEL_W, SC:352 (comment: "up to 450px", was 380)
    "height (Min mode, default)": 440,    // heightSmall, SC:121; applied each draw SC:2443
    "height (Max mode)": 760,             // heightLarge, SC:121
    "size before first draw": "450 x 400 // SC:812 (replaced by the mode height at first render)",
    "default sizeMode": "small"           // SC:120
  },
  "limits (corner grip and settings)": {"minW":340,"maxW":760,"minH":300,"maxH":1100},   // SC:132, SC:863
  "width rule": [
    "saved grip width c.size.w (clamped 340..760) else 450 (SC:2340, SC:171-173)",
    "auto-widened for the draw only to fit the Stat Weights pane: want = need + 2*PAD, capped at screen width, never saved (SC:2341-2346)"
  ],
  "PAD (inner margin)": 10,               // ns.UI_MARGIN, SC:352 + MOD:602
  "GUT (gutter)": 10,                     // ns.UI_GUTTER, SC:352 + MOD:603
  "content width W": "panel width - 2*PAD = 430 at default (derived, SC:358)",
  "strata": "the character window's strata, else MEDIUM (SC:813, SC:1012-1013)",
  "clamped to screen": true,              // SC:824
  "background": "texture over the whole panel, xui-window bg (code fallback 0.04,0.04,0.06), alpha = opacity setting (default 0.92) (SC:836-837, SC:2394-2396, SC:113)",
  "border": "4 x 1px edges, xui-window border (fallback 0.35,0.35,0.40) (SC:838-844, SC:2397-2398)"
}
```

## 1.3 Docking and stand-alone

```json
{
  "docked (character window shown)": {
    "side right (default, SC:109)": "panel TOPLEFT -> CharacterFrame TOPRIGHT, x +GUT(10), y 0   // SC:1016",
    "side left": "panel TOPRIGHT -> CharacterFrame TOPLEFT, x -GUT(-10), y 0                    // SC:1015",
    "drag": "disabled while docked (SC:828)",
    "closes with": "the character window; its open state is kept (SC:2851-2855)",
    "Esc": "closes the character window first; the panel closes with it (SC:817)"
  },
  "stand-alone (opened while the character window is closed)": {
    "anchor": "CENTER of UIParent + (c.free.x, c.free.y), default (0,0)   // SC:1018, SC:118",
    "drag": "LeftButton drag moves it; the centre offset is saved to c.free (SC:827-835)",
    "character window opens": "Place() docks it beside the window while that is open (SC:1014); when the window closes it stays open and goes back to its own place (SC:2851-2854, SC:2871-2874)",
    "Esc / close": "saved as closed (SC:2694-2699)"
  },
  "open state": "c.panelOpen (default true, SC:119) is kept between sessions. Opening the character window shows the panel if it was left open (SC:2627-2641)"
}
```

## 1.4 Combat behaviour (V26 "Hide silently")

- Combat starts (`PLAYER_REGEN_DISABLED`). The panel hides with no message, every Change box lets go of the keyboard, and drag or resize stops (SC:2719-2729). The saved open state is kept (SC:2704).
- In combat:
  - nothing opens it: SetOpen returns, and so do tab, fold, input and Min/Max (SC:2876, SC:937, SC:718);
  - no model is built and nothing is drawn (SC:2392);
  - the minimap row is hidden (LD:23-24);
  - `Available()` is false, which also hides QA's Stat Calc button (SC:2466-2469, SC:2481).
- Combat ends. The panel reopens if it was open: on its own if it was stand-alone, docked if the character window is open (SC:2732-2749).

## 1.5 Vertical layout of the fixed header (panel coordinates, y down from the top)

```json
{
  "TITLE_H": 18,   // SC:353
  "NAME_H": 18,    // SC:356
  "HEADER": "TITLE_H + GUT + NAME_H + GUT + 20 + GUT = 18+10+18+10+20+10 = 86 (derived, SC:357)",
  "rows": [
    {"row":"title row", "y":10, "h":18, "source":"PAD (SC:846, SC:910)"},
    {"row":"item-level header", "y":"PAD+TITLE_H+GUT = 38 (derived, SC:852)", "h":18},
    {"row":"header rule (1px)", "y":"38 + NAME_H + floor(GUT/2) = 61 (derived, SC:858-860)", "x":"PAD .. width-PAD"},
    {"row":"tab row", "y":"PAD+TITLE_H+GUT+NAME_H+GUT = 66 (derived, SC:932, SC:2358)", "h":20},
    {"row":"scroll content top", "y":"PAD+HEADER = 96 (derived, SC:947)", "bottom":"PAD from bottom (SC:948)", "x":"PAD .. width-PAD"}
  ],
  "scroll": "mouse wheel, 40 units per notch (SC:955); no visible scroll bar is created (INFERENCE: none in code)"
}
```

### Title bar controls (left to right)

```json
[
  {"id":"title", "text":"Stat Calculator", "anchor":"TOPLEFT (PAD, -PAD) = (10,-10)", "template":"GameFontNormal",
   "size":"fontSize+2 = 13 at default 11", "color":"xui-titlebar text (fallback 1,0.82,0)",
   "src":"SC:845-847, SC:2399-2400"},
  {"id":"Min/Max button", "size":"40 x 18", "anchor":"TOPRIGHT (-(22+GUT), -PAD) = (-32,-10)",
   "label":"\"Max\" in small mode, \"Min\" in large mode", "text template":"GameFontHighlightSmall (size not set: INFERENCE template default)",
   "bg":"xui-button bg (fallback 0.04,0.04,0.04,0.7)", "text color":"xui-button text (fallback 1,0.82,0)",
   "hover":"title \"Larger\"/\"Smaller\" + \"Switches between the two heights set in Bonus Features > Stat Calculator > Panel (now 440 and 760). Drag the bottom-right corner to resize freely; that sets the current one.\"",
   "src":"SC:908-924, SC:2402-2406"},
  {"id":"close", "template":"UIPanelCloseButton", "size":"24 x 24", "anchor":"TOPRIGHT (+2,+2)", "src":"SC:900-903"}
]
```

### Header line (under the title)

- Left text `"Equipped %.1f"`, for example `Equipped 332.9`. Right text `"Max (bags) %.1f"`, for example `Max (bags) 334.6` (SC:2366-2369; examples SC:849-850).
- Font size 14 (`HEADER_SIZE`, SC:2365). Color: xui-label text (SC:2373, SC:2380). No wrap.
- Each half is `floor((W-GUT)/2)` wide, which is 210 at default (**derived**, SC:2375, SC:2379).
- Left is LEFT-justified at `(PAD, -38)`; right is RIGHT-justified at `TOPRIGHT (-PAD, -38)` (SC:853-856).
- Rule under it: xui-window border at alpha 0.6 (SC:2383-2384).

### Tab row

```json
{
  "tabs (order)": ["Stats", "Gear", "Ability Scaling"],   // SM:3527 (keys stats, gear, spells)
  "default tab": "stats",                                 // SC:122
  "geometry": "tab i: x = PAD + floor((i-1)*W/3), width = floor(i*W/3) - floor((i-1)*W/3) - 2, height 20 (SC:930-932, SC:2355-2358)",
  "default W=430 (derived)": [{"x":10,"w":141},{"x":153,"w":141},{"x":296,"w":142}],
  "label": "centered, GameFontHighlightSmall (size not set: INFERENCE template default) (SC:934)",
  "selected": "bg xui-tab-selected (fallback 0.22,0.1,0.3,0.9), text xui-tab-selected text (fallback white)",
  "unselected": "bg xui-tab (fallback 0.03,0.03,0.03,0.7), text xui-tab text (fallback 1,0.82,0)",
  "colors src": "SC:2408-2415"
}
```

### Resize grip

- 16x16, at `BOTTOMRIGHT (-2,+2)`, frame level +10 (SC:864-866).
- Drawn as six 2x2 squares at offsets (2,2), (6,2), (10,2), (2,6), (6,6), (2,10) from its bottom-right (SC:868-874), in the muted color at alpha 0.9 (SC:2385).
- Hover title `"Drag to resize"` (SC:894-895).
- On release: the width is saved only if the drag changed it, and the height becomes the current mode's height (SC:876-889).

## 1.6 Content-area building blocks (shared by all tabs)

- **Text size default** `fontSize = 11`, range 8-16 (SC:112, SC:157). Below, `size` means this setting.
- **Section header bar** (SC:2067-2082; Hdr SC:472-485):
  - Full width W, height `size+7`, which is 18 at default (**derived**).
  - Text `"- Title"` when open, `"+ Title"` when folded. Font `size+1` (12), color xui-label (fallback 1,0.82,0), anchored LEFT `(0,+1)`.
  - 1px bottom line in xui-window border at alpha 0.8.
  - The next y is header y + `size+9` (20). A 6 px gap sits before every section but the first (SC:2069).
  - Click the bar to fold the section.
- **Muted text** xui-text-muted (fallback 0.6,0.6,0.65). **Body text** xui-text (fallback 0.96,0.96,0.98) (SC:1298-1299).
- **Row hover highlight**: white at alpha 0.06 (SC:434-436).
- **INDENT = 12** per nesting level (SC:1293). Depth 0 is headings and bucket bars, depth 1 is a stat (x 12), depth 2 is a stat's rows (x 24) (SC:1286-1291).
- **Change colors** for a typed number's new value (SC:305-320):
  - better: the game's GREEN_FONT_COLOR, else (0.5,1,0.5);
  - worse: RED_FONT_COLOR, else the theme danger color, else (1,0.25,0.25);
  - with a color-blind base theme: better is (0.337,0.706,0.914) and worse is (1.00,0.55,0.10) (SC:269);
  - same: the text color.
- **Tone colors**: good (0.5,1,0.5), warn (1,0.56,0.25) (SC:250).
- **Stat name colors**, `CM.STAT_COLORS` (SM:2461-2465):
  - crit (1.00,0.45,0.35), haste (1.00,0.82,0.30), mastery (0.72,0.55,1.00), vers (0.40,0.85,0.45);
  - avoidance (0.35,0.80,0.85), leech (1.00,0.45,0.70), speed (0.55,0.75,1.00);
  - primary (1.00,0.95,0.75), stamina (0.95,0.55,0.45).
- **Placeholder values**: `"hidden in combat"`, `"unavailable"`, `"not given by the game"` (SM:52); `"not given now"` (SM:2717).

## 1.7 Stats tab: sections in order

Built at SM:3553-3554: `StatMapSections` then `StatWeightsSection`.

1. **Gear Summary**, section header `"Gear Summary"` (SM:1065; added first, SM:2846)
2. **Character Stats**, section header `"Character Stats"`, a grid (SM:2881)
3. **Stat Weights**, section header `"Stat Weights"` (SM:3424)

### 1.7.1 Gear Summary (first section)

Style setting `gearSumStyle`, default `"bars"` (SC:123, SM:1057). The choices and their labels (SM:1049-1056):

| key | label | description |
|---|---|---|
| bars | Split bars | One bar per stat: gear solid, the rest lighter. |
| tiles | Stat tiles | A small tile per stat with its total and gear part. |
| stacked | One stacked bar | One bar split by each stat's share, with a legend. |
| columns | Columns | One column per stat: gear solid, the rest lighter. |
| share | Gear share | One bar per stat with its gear percent. |
| table | Table | A table of Gear, Character and Elsewhere. |

**Rows:** one per gear stat that the gear or the character has, in the order Critical Strike, Haste, Mastery, Versatility, Leech, Avoidance, Speed (SM:754-758, SM:1007-1031). The short names are Crit, Haste, Mastery, Vers, Leech, Avoidance, Speed (SM:762).

**Split bars (default)**, from SC:1932-1964:
- Name column: the widest name, at most `floor(W*0.4)`. Name in the stat color, font `size`.
- Bar starts at `nameW + GUT`. Bar height `max(6, size-2)`, which is 9 at default, centered on the text line.
- Gear part is solid; the "elsewhere" part is the stat color at alpha 0.4 (`GS_LIGHT`, SC:1902). The longest bar fills the room.
- Number text after the bar, `+GUT`, font `size-1`, muted. Format `"544 (gear 489 +55)"` (SC:1938).
- If fewer than 40 px are left for the bar, the numbers go under it (SC:1944-1945).
- Row step: `max(lh, nh, size) + 3`.

**Gear share**: same layout. Each bar is full width and the number reads `"90% gear (489 of 544)"` (SC:1937).

**Tiles** (SC:1965-1986):
- Tile background xui-pane bg at alpha 0.9. Padding 4.
- Lines: name `size-1`; total `size+4`; `"gear N"` at `size-2`; diff `size-2`. All centered. Tiles wrap with GUT between them.

**Stacked** (SC:1987-2014):
- One bar, `size+4` tall. Under it a legend: a `max(6,size-3)` swatch, then `"Crit 544 (489 +55)"` at `size-1`.

**Columns** (SC:2015-2039):
- Chart height `4*size`. Total above at `size-1`, short name below at `size-1`.

**Table** (SC:1925-1928, CmpCols SC:1226-1231):
- Columns `Gear | Character | Elsewhere` (SM:1003). The head is `size-1`, muted, right-aligned.
- Name column `floor(W*0.30)`; the 3 value columns share the rest with 4 px gaps.

**After any style:**
- One muted line per stat the game hides right now: `"Critical Strike: hidden in combat"` (SC:2041-2043).
- `"Empty sockets: N"` in the warn color at `size-1` (SC:2044-2046).

### 1.7.2 Character Stats (grid section)

**Tree inside the section, in order** (SM:2885-3400). [L1] is a level-1 heading; [bar] is a level-2 bucket bar.

```
[L1] Core Stats                                   SM:2885
  column head (Stat | (no Rating title) | Current value | Pt value | Change | Modifies)   SM:2886, SM:2606
  [bar] Primary                                   SM:2887
     <your primary stat> e.g. Agility  (has a Change box: input "sv:primary")   SM:2889-2890
     Stamina                                      SM:2932
  [bar] General                                   SM:2945
     Health                                       SM:2947
     <resource(s)> e.g. Mana / Energy / Runes / Runic Power (one row per pool)   SM:2725-2741
     GCD                                          SM:2961
     Movement Speed                               SM:3014
  [bar] Offensive                                 SM:3026
     Attack Power (shown when the spec uses it or it is > 0)   SM:3031-3033
     Spell Power (only when > 0 or hidden)        SM:3060
     Attack Speed                                 SM:3089
     Weapon DPS                                   SM:3106
     Damage                                       SM:3119
     Critical Strike Effectiveness                SM:3139
  [bar] Defensive                                 SM:3155
     Armor                                        SM:3161
     Dodge                                        SM:3207
     Parry                                        SM:3217
     Block (conditional: shield block > 0)        SM:3237
     Stagger (conditional: > 0, i.e. Brewmaster INFERENCE)   SM:3252-3253
[L1] Secondaries                                  SM:3265
  column head (Stat | Rating | Current value | Pt value | Change | Modifies)   SM:3264, SM:3266
     Critical Strike, Haste, Mastery, Versatility (each has a Change box "sv:<key>")   SM:3267-3385, SM:2638
[L1] Tertiaries                                   SM:3387
  column head (with Rating)                       SM:3388
     Avoidance, Leech, Speed (each has a Change box)   SM:3398-3400
```

**Column head row** (SC:1304-1318):
- The head texts are the model's `cols` = `{ "Stat", ratingHead or "", "Current value", "Pt value", changeHead or "", "Modifies" }` (SM:2606). They are drawn at these x positions, left to right:
  - `Stat` at x INDENT (12), LEFT;
  - `Rating` at g.rx, RIGHT (only when a rating title and a Rating column exist);
  - `Current value` at g.vx, RIGHT;
  - `Pt value` at g.px, RIGHT;
  - `Modifies` at g.ix, LEFT;
  - `Change` at g.cx (the far right), LEFT.
- So the **visual column order is `Stat | Rating | Current value | Pt value | Modifies | Change`**. Change is the last cell, `g.cx = W - g.box` (SC:1220).
- The head is `size-1` (10) and muted. Row step `h+3`.

**Column widths** (GridCols, SC:1173-1222). They are measured from the text with `TextW`, not fixed:
- Each column first gets its widest word, then its title on one line, then its widest cell (FitCols SC:1103-1129). Modifies (col 5) takes whatever is left.
- The Change box is `max(44, TextW("Change", size-1))` wide (`GRID_BOX = 44`, SC:1152, SC:1204).
- There is a GUT between columns (SC:1208).
- There is no Rating column when the tab has no rating stat or no box (SC:1205).
- Exact pixel widths depend on the font measure (**INFERENCE**: not computable from code alone).
- Historical comment estimates: Rating ~80, Stat ~112 at the 450 panel (SC:1145-1147).

**Level-1 heading** (Core Stats, Secondaries, Tertiaries), SC:1326-1330:
- x 0, full width, font `size`, color xui-label (fallback 1,0.82,0).
- 4 px above (except the first), 3 px below.

**Bucket bar** (Primary, General, Offensive, Defensive), SC:1331-1339:
- A band across the full W in the theme **accent** color at alpha 0.35 (`BUCKET_ALPHA`, SC:1294). Its height is `lines*(size-1)+4`, which is 14 at default (**derived**).
- Label at x 4, y+2, font `size-1`, body text color.
- 2 px above, 3 px below.

**Stat row** (a card), SC:1343-1456:
- Label at x 12 (INDENT), font `size`, in the stat color (`labelColor`) or body text.
- Rating, right-aligned in the Rating column. Example `"1,287 +1,000"` or `"528 +172"`: your rating, and a typed change beside it (SM:2650, SC:1146).
- Current value, right-aligned. Example `"22.63%"`. A typed number puts its **new value with sign under it**, colored better/worse (`"+2,800"`), 1 px gap (SC:1249).
- Pt value, right-aligned. Example `"46.0 / 1%"` (rating per 1%) or `"1 = 1.00"` (per point) (SM:2610, SM:2615, SM:2656).
- Modifies: comma-separated names of what the stat applies to, for example `Attack power, Dodge, Armor`. They wrap inside the column at `size-1`, in the muted color or the line's own color, and each name has its own hover (SC:1400-1418).
- **Change box**: an EditBox from `InputBoxTemplate` at x `g.cx`, y offset 2 px above the row top. Size `g.box x (size+6)`, which is 44 x 17 at default (**derived**). Font `GameFontHighlightSmall` (SC:674-677). It holds the number itself (yours, or the typed one) (SC:1347-1361). Only stats with an input have one: the primary stat, the secondaries and the tertiaries.
- **Fold mark** `"+"` (folded, the default) or `"-"` (open) at x 0, inside the 12 px indent, muted. Only on stats that have contribution rows (SC:1394-1399).
- **Contribution rows** (open only): x 24 (`2*INDENT`), font `size-1`, muted. Examples: `"from Agility +2,616"`, `"from Mastery"`, `"Diminishing returns  none yet"`, `"From rating"` (shown as `from rating`) (SC:1421-1428, SM:2653-2667, MapNote labels).
- Row step: `max(h, influences height) + 2`, then 4 px after the card (SC:1419, SC:1456).
- **Row label examples from the model:**
  - `Agility`, `Stamina`, `Health`, `Mana`, `GCD`, `Movement Speed`, `Attack Power`, `Weapon DPS`, `Critical Strike Effectiveness`, `Armor`, `Dodge`, `Parry`;
  - `Critical Strike`, `Haste`, `Mastery`, `Versatility`, `Avoidance`, `Leech`, `Speed`.
- **"»" names in the Modifies column:** `Attack power`, `Dodge`, `Parry`, `Armor`, `Health`, `GCD`, `Attack speed`, `Damage per second`, `Damage and healing done`, `Damage taken`, `Area damage taken`, `Healing from damage done`, `Movement speed` (SM MapNote labels, SM:3398-3400).

### 1.7.3 Stat Weights (third section)

**Columns, exactly, in order:** `Stat | Rating | PPP | DR Threshold | T/L Rating | Influences` (SC:1475, SM:3428).

**Rows, in order:** primary stat, Stamina, Critical Strike, Haste, Mastery, Versatility, Avoidance, Leech, Speed (SM:3420). Each label is in its stat color (SM:3471).

**Cells** (SM:3456-3466, SM:3483). Example from her design, Haste:

| Stat | Rating | PPP | DR Threshold | T/L Rating | Influences |
|---|---|---|---|---|---|
| Haste | `1,442 / 32.5%` | `48.9 / 1%` (+ under it, when past a threshold: `DR: 52.1 / 1%` in warn color at size-1) | `1,429` or `none` or `2,000 (passed)` or `after combat` | two lines: `T: 1,429` / `L: 12.2` | `GCD (-0.31 s), Attack Speed (...)` |

- Primary and Stamina rows: only Rating = the stat value; the other cells are empty (SM:3439-3441).
- **Titles**: centered over their columns at `size-1`, muted. They wrap to at most 2 lines and are **bottom-aligned**, so all six end on the same baseline (SC:1579-1598).
- **Cells**: left-aligned from the column's left edge (SC:1467-1472), font `size`. Influences is `size-1`, muted (SC:1617). The row is top-aligned and as tall as its tallest cell, +1, then 4 px between rows (SC:1615-1625).
- **Widths** are measured (WeightCols SC:1548-1569). Influences takes the rest. The panel auto-widens so no word is cut and every title fits on 2 lines (SC:1542-1547, SC:2339-2346).

## 1.8 Gear tab: sections in order

1. **"Equipped"** (SM:1074). One icon per equipped slot, except Shirt and Tabard (SM:974). Slot order: Head, Neck, Shoulder, Back, Chest, Wrist, Hands, Waist, Legs, Feet, Finger 1, Finger 2, Trinket 1, Trinket 2, Main Hand, Off Hand (SM:736-742).
   - Icon 30x30 in cells of 44 (SC:596). That gives `floor(430/44) = 9` per row at default (**derived**, SC:2102).
   - Row step `30 + size + 4` = 45 (**derived**, SC:2104). The icon is centered in its cell.
   - 1px quality-color border (SC:605-608).
   - The item level is centered under the icon (+3 px), `size-1`, in the quality color (SC:2126-2127).
   - The selected icon gets a **3 px accent frame** on top (SC:617-623, SC:2118-2123).
2. **"Compare"**, or `"Compare: <slot label>"` once a slot is selected (SM:1413).
   - Slot labels: `Ring slot #1`, `Ring slot #2`, `Trinket slot #1`, `Trinket slot #2`, `Main-hand`, `Off-hand`; the game's name for other slots (SM:750).
   - Row `"Item"` + input box (SM:1414; drawn at SC:2139-2167):
     - label column `floor(W*0.36)` = 154, label at x 0;
     - box at x `lw+GUT` = 164, width `W - lw - GUT` = 266, height `size+6` = 17 (**derived**).
     - Drop, shift-click or type an item ID.
   - Hint (no slot picked), muted: `"Click an equipped item above to list what you own for it, or put any item in the box."` (SM:1419).
   - `"In your bags"`: an icon row like Equipped, at most 12 items (SM:1425-1431). Up to 3 can be picked (SM:1303).
   - `"Replacing"` / `"Replace instead"` choice rows: `"<slot> (item level N)"` (SM:1443-1445).
3. **"Changes"** (SM:1468). Multi-column table:
   - Head `Stat | Pt value | Equipped | <picked item 1> | <item 2> | <item 3>`. Item names are in their quality color (SM:1470-1472). The head is `size-1`, muted. Stat is LEFT; the others are RIGHT (SC:1834-1839).
   - Rows, in order: `Item level`, `<Primary>` (Pt value e.g. `"1.00 AP"`), `Stamina`, `Armor`, then each gear stat that changes (Pt `"46.0 / 1%"`) with sub-rows `DR threshold` and `True / lost`. Sub-rows are indented 8, at `size-1`, muted. Then `Empty sockets`, `Enchant` (`yes` / `none` / `?`) (SM:1568-1604).
   - Cell format: `"1,405 (-12)"`. The number is left-aligned and its difference in brackets follows it, better/worse colored (SC:1859-1872).
   - Widths: Stat `max(64, floor(W*0.22))` = 94; Pt value `ceil(size*0.55*9.5)` = 58 (**derived**, SC:1778). The item columns fit what is left.
   - If not all picked items fit, a warn line under the head reads `"N more picked: drag the panel's corner wider (or choose a smaller text size) to see them side by side."` (SC:1842-1844).
   - Sub-headings in the label color, `size`, 4 px above: `"Stat effects"`, `"On-use and proc effects"`, `"Spell Changes"` (SM:1708, SM:1742, SM:1814; drawn SC:1846-1850).

## 1.9 Ability Scaling tab

**Top row** (SC:2210-2283):
- **Spell data button** `UIPanelButtonTemplate` (flat-skinned), centered.
  - Width `min(250, W - 2*(20+GUT))` = 250; x `floor((W-250)/2)` = 90; height `size+12` = 23 (**derived**, SC:505, SC:2219-2224). Font `size`.
  - Label: `"Configure spell data"` (Spell Math off) or `"Refresh spell data"` (SM:2329, SM:2341).
- **Filter icon** 20x20 at the right edge (x `W-20`), vertically centered in the row (SC:2234-2237).
  - A funnel made of 4 bars, 14x2, 10x2, 6x2 and 2x4, at top offsets 5, 8, 11, 13 (SC:576-580).
  - A 5x5 dot at the top right (-1,-1) while a filter is on (SC:581).
  - Muted color when off; label color when a filter is on (SC:2242).
- **Filter menu** under the icon, TOPRIGHT at (0,-2) (SC:2260):
  - Width `max(120, ceil(size*0.55*16)+16)` = 120; row height `size+8` = 19; 4 rows + 4 = 80 tall (**derived**, SC:2257-2261).
  - Rows `None`, `Offense`, `Defense`, `Utility` (SM:1930-1935), text at x 8.
  - Selected row: xui-tab-selected colors.
- The sections start at y `h + GUT` = 33 (**derived**, SC:2282).

**Sections:**
- `"Active spells"`, or `"Active offensive spells"` / `"Active defensive spells"` / `"Active utility spells"` by filter (SM:1936).
- `"Inactive: talents not picked"`, folded by default (SM:2385).

**Spell table** (SC:1649-1762):
- Head `Spell Name | Talent Modifiers | % PSV | Computed Value` (x order SC:1672-1674, drawn SC:1689-1692). It is `size-1`, muted, LEFT.
- Each spell:
  - Name line `"- <Spell>"` (open) or `"+ <Spell>"` (folded), font `size`.
  - Under it `"Spell ID: 12345"` (SM:2137) at `size-1`, muted.
  - % PSV: `"83.1% of attack power"` (SM:2158), with `"1 Agility = 0.83"` (SM:2159) under it at `size-1`, muted. Then stat lines such as `"Versatility: +2.61%"`, with the stat name in its color.
  - Talent Modifiers: comma list in the good color, or `none` muted.
  - Computed Value, left-aligned, e.g. `"38,011"`; a typed number puts its new value under it.
  - A 1 px divider between spells: border color at alpha 0.6, at y-3 (SC:1707-1711).
- Widths: Spell Name takes the rest; Talent Modifiers takes up to 22% of W (SC:1666-1670).

## 1.10 Settings page: Bonus Features > Stat Calculator

The tree node is titled `"Stat Calculator"`, order 3, `childGroups = "tree"` (SC:3085). Its row switch is the loader's tick box `"Stat Calculator"` (LD:105-115):
- desc: `"Turns the Stat Calculator on. Off means it is never read; on means it loads once per reload."`
- Changing it saves and asks for a reload.

**Calculator not loaded** (off, or on until a /reload): the page holds one line (LD:118-121, LD:127-130):
- off: `"Off: none of the Stat Calculator is read. Tick it, then /reload to load it and list its options here."`
- on, not loaded yet: `"On after a reload: type /reload to load the Stat Calculator and list its options here."`

**Loaded**, in order:

1. intro text (SC:3090-3091): `"The Stat Calculator: a panel beside the character window (it opens with the window when you left it open) or on its own (the XayaUI minimap button, /xui stats): every stat the game gives in one Character Stats section, ... the Stat Weights pane, and a gear comparison. ... Hidden in combat; it comes back after combat. ... Off by default."`
2. **Panel** child node, order 10, `childGroups = "tab"`. Its row switch is `"Show the panel"` (SC:3030-3032). It has two tabs:
   - **Layout** tab (SC:3034-3069). Options, in order:
     1. `Side`, select: Right / Left (order 2)
     2. `Detail`, select: Every line / Key lines (3)
     3. `Text size`, range 8-16, step 1 (5)
     4. `Reset size`, button: "Resets the panel to its default width and heights (440 and 760)." (5.5)
     5. `Smaller height`, range 300-1100, step 10 (5.6)
     6. `Larger height`, range 300-1100, step 10 (5.7)
     7. `Gear Summary style`, select: Split bars / Stat tiles / One stacked bar / Columns / Gear share / Table (5.8)
     8. `Background`, range 0-100%, step 5% (6)
   - **Your numbers** tab (SC:3070-3076):
     1. `Clear all`, button: "Resets every number you typed in a Change box on the Stats tab."
3. **Spell Math** child node, order 30. Its row switch is `"Spell Math"` (SC:2975-2977). Contents:
   - intro text (SC:2979-2980)
   - `List spells without numbers`, toggle, full width (SC:2981-2982)
   - `Add a spell`, input, double width: "Adds a spell by ID, name or shift-clicked link. Up to 20." (SC:2983-2995)
   - up to 20 inline groups titled `"<Spell name>  (#id)"`. Each has `Scales with` (Attack power / Spell power), `Coefficient %`, `Filter` (From its description / Offense / Defense / Offense and Defense / Utility) and `Remove` (SC:2998-3027).
4. Panel and Spell Math are hidden while the Stat Calculator is off (SC:2965, SC:2976, SC:3031).

---

# SCREEN 2: Improved Character Display on the character window (branch claude/stat-calculator-v25)

## 2.1 Window size variants (Character Reskin's "Wider window"; ICD reads it)

```json
{
  "Blizzard widths (as named in code comments)": {
    "PANEL_DEFAULT_WIDTH (no stats pane)": 338, "CHARACTERFRAME_EXPANDED_WIDTH (with stats pane)": 540   // CR:48-50
  },
  "wider window default": {"widePx": 42, "result": "338 -> 380, 540 -> 582"},   // CR:48-50, CR:54
  "wide default on": true,                                // CR:54 (wide = true, only while the reskin is on; reskin enabled=false by default)
  "Extra width range": "0..300 px, step 1",               // CR:55, CR:808
  "how it widens": "CharacterFrame width = Blizzard width + px; Inset BOTTOMRIGHT at x DW+RO+px; model scene keeps its width (231) and moves right floor(px/2); main hand slot moves right floor(px/2)",   // CR:508-515, CR:322-323
  "example px=42": "model and main hand +21 px (derived)",
  "the 120 px probe": "540 -> 660 tested by her probe (CR:315-316)",
  "Extra height (tallPx)": {"default": 0, "range": "0..300", "rule": "window and model scene +px taller; each of the 7 gaps per slot column grows floor(px/7), first px%7 gaps +1 (CR:54-55, CR:394-457)"},
  "only on the Character tab, out of combat": "CR:487, CR:492-503",
  "Blizzard layout (comment, live source)": {
    "slot buttons": "37 x 37, 4 px apart",                // ICD:474
    "left column ends 7 px before the model; right column starts 8 px after": "ICD:474-475",
    "model scene": "231 x 320 at (52,-66)",               // ICD:475, CR:327-328
    "main hand": "BOTTOMLEFT (130,16)",                   // CR:327-328
    "camera buttons": "TOP -10, 32 high, 2 + n*(32-6) wide, n<=5 -> 132 wide (derived)",   // ICD:475-476, ICD:511
    "weapon slot frame art": "Char-BottomSlot 42 x 53 at (-4, 8); side pieces 6-7; ART_X 10, ART_TOP 8, ART_BOTTOM 9",   // ICD:512
    "Inset bottom": "12 below the weapons' bottom (fallback)"   // ICD:556
  },
  "window height": "Blizzard's own (not in code: INFERENCE)"
}
```

## 2.2 Slot layout

The two columns are from CR:394-395 (TALL_COLS), with LEFT_SLOTS at ICD:496-497. The weapons are from ICD:498.

| Left column (top to bottom) | Right column (top to bottom) |
|---|---|
| HeadSlot | HandsSlot |
| NeckSlot | WaistSlot |
| ShoulderSlot | LegsSlot |
| BackSlot | FeetSlot |
| ChestSlot | Finger0Slot (Finger 1) |
| ShirtSlot | Finger1Slot (Finger 2) |
| TabardSlot | Trinket0Slot (Trinket 1) |
| WristSlot | Trinket1Slot (Trinket 2) |

- Weapons, at the bottom between the columns: MainHandSlot (left), SecondaryHandSlot / Off Hand (right) (ICD:477, ICD:498).
- The character model scene sits between the columns.

## 2.3 Item level on the icon (option "Item level")

```json
{
  "fontstring": "on the slot button, GameFontNormal template",       // ICD:1045
  "anchor": "BOTTOM of slot -> BOTTOM, x 0, y +2",                   // ICD:1046
  "font size": 12, "flags": "OUTLINE",                              // ICD:1047
  "text": "item level rounded, e.g. \"334\"",                       // ICD:1041
  "not on": "Shirt (4) and Tabard (19)",                            // ICD:1038, QSM:1371
  "color (track rule)": {
    "track -> quality color": {"Explorer":"q0 grey","Adventurer":"q0 grey","Veteran":"q2 green","Champion":"q3 blue","Hero":"q4 purple","Myth":"q5 orange"},   // QSM:1395
    "step shading": "color * f, f = 0.55 + 0.45*(cur-1)/(max-1) (step 1 = 55%, last step = 100%)",   // QSM:1410
    "no track": "the item's own quality color; fallback white"     // QSM:1414, ICD:1041
  },
  "hidden when": "another addon's text on the slot shows the same number (ICD:868-878)"
}
```

## 2.4 Enchant / embellishment / gem block (outside right edge of the icon)

**Row order** (ICD:938-1005):
1. Enchant row
2. Embellishment row
3. One row per socket

| Row | Text | Color |
|---|---|---|
| Enchant | Short enchant name, without "Enchant <slot> - " (QSM:1508-1512). Example `"Eyes of the Eagle"` | GOOD (0.5,1,0.5) (ICD:330, ICD:958) |
| No enchant (a ticked Enchant Slot with none) | `"No enchant"` | WARN orange (1,0.56,0.25) (ICD:499, ICD:960) |
| Enchanted, no name given | `"Enchanted"` | GOOD (ICD:962) |
| Embellishment | `"Embellished (n/max): <item name>"`, or `"Embellished: <item name>"` | EMB_COL (0.55,0.8,1) (ICD:515, ICD:979-980) |
| Gem | Socket icon + gem name | GEM_COL (0.92,0.92,0.95) (ICD:515, ICD:995) |
| Empty socket | Socket icon (the game's `character-emptysocket` atlas, else a flat (0.12,0.12,0.14,0.95) square) + the socket type, e.g. `"Prismatic Socket"`, else `"Empty socket"` | WARN orange (ICD:514, ICD:692-694, ICD:998-999) |

**Geometry:**

```json
{
  "x start": "slot right edge + BLOCK_OFF 6",                     // ICD:504, ICD:591
  "band": "slot top + SLOT_PAD 2 .. slot bottom - 2 (plus half the Extra-height gap, except above the first / below the last slot of a column)",   // ICD:503, ICD:583-586
  "right edge, left column": "model left - MODEL_GAP 4 when that leaves >= MIN_COL 40 px, else middle between columns - floor(GUT/2)=5 (runs over the model's side)",   // ICD:504-505, ICD:592-593
  "right edge, right column": "CharacterFrame right - GUT (10): over the stats pane",   // ICD:561, ICD:594-595
  "weapons": {
    "off hand": "x from weapons-art right + GUT .. right column's right edge; vertical: under Trinket1Slot's bottom - 2 .. Inset bottom + 2",   // ICD:576
    "main hand": "LEFT of the weapons: x from left column's left .. weapons-art left - GUT; vertical: under WristSlot - 2 .. Inset bottom + 2; text RIGHT-aligned toward the weapon",   // ICD:574, ICD:538
    "weapons-art box": "min slot left - 10 .. max slot right + 10, top + 8, bottom - 9 (derived from ART_X/ART_TOP/ART_BOTTOM)"   // ICD:553
  },
  "avoids weapons": "a box overlapping the weapon art is split into 'above the weapons' (>= 8 tall) and 'beside them' (>= 20 wide)",   // ICD:598-605
  "vertical placement": "centered on the slot's middle, kept inside the band; moved below/above the camera buttons when there is room",   // ICD:634-643
  "justify": "LEFT for every slot, RIGHT for MainHandSlot",       // ICD:538
  "font": "GameFontNormal fontstrings resized to 10, then 9, then 8 to fit",   // ICD:685, ICD:513
  "socket icon": "16 px, 12 px only when the block does not fit",   // ICD:509
  "gaps": {"between rows": 1, "icon to text": 3, "icons in compact row": 2},   // ICD:508
  "gem texture": "inset 1 px in the socket square",               // ICD:696
  "fallbacks when nothing fits": "each row cut to one line at a word with \"...\", then gems as a single row of icons (no names)",   // ICD:493-494, ICD:791-796
  "camera buttons": "a block that meets them fades to alpha 0 while they show (mouse over the model)",   // ICD:495, ICD:841-852
  "mouse": "hover tooltip only; clicks pass through",             // ICD:645-669
  "row hover": "enchant: the full tooltip line; embellishment: \"Embellished - Name: <name>\" then its effect lines in (0,1,0); gem: the gem's item tooltip"   // ICD:956-997
}
```

## 2.5 Empty-socket mark `2S` (option "Empty sockets")

- Text `"<n>S"`, e.g. `2S` (QSM:1378), in the warn color (1,0.56,0.25) (ICD:439, ICD:330).
- Its own frame covers the slot, frame level +3 (ICD:427-429).
- Fontstring `GameFontHighlightSmall` anchored **TOP (0,-2)** of the slot (ICD:430-431). Size `max(8, ovSize-2)` = 9 at the default ovSize 11, OUTLINE (ICD:436, ICD:78).
- It shows only while it is ticked (off by default) **and** "Gems and sockets beside the slots" is off (ICD:378, ICD:419).

## 2.6 Full stat list (option "Full stat list")

```json
{
  "where": "own ScrollFrame SetAllPoints(CharacterStatsPane), frame level +10, opaque fill xui-pane bg (fallback 0.04,0.04,0.04) at alpha 1",   // ICD:1349-1354, ICD:1373-1374
  "width": "the pane's width; fallback 190 (INFERENCE: the real pane width is Blizzard's)",   // ICD:1362-1365
  "constants": {"LIST_ROW":14, "LIST_HEAD":17, "LIST_SIZE":11, "LIST_PAD":4},   // ICD:1210
  "start y": 4,                                                 // ICD:1394
  "group heading": {
    "x": "level 1 (Core Stats, Secondaries, Tertiaries): 4; level 2 (Primary, General, Offensive, Defensive): 6",   // ICD:1403
    "y": "+2", "font": "level 1: 12, level 2: 11", "color": "xui-label (fallback 1,0.82,0) or her group color",   // ICD:1402-1404
    "rule": "1 px under the text (y+2+h+1), width w-x-4, xui-window border alpha 0.8",   // ICD:1405-1409
    "advance": "max(17, h+5)",                                  // ICD:1411
    "Core Stats shows when any of its 4 level-2 groups has a line": "ICD:1399"
  },
  "stat line": {
    "name": "x 10, width lw = floor((w - 8 - 10) * 0.58), LEFT, size 11, the stat color (CM.STAT_COLORS) or text color",   // ICD:1393, ICD:1415-1417
    "value": "x 10+lw+4, width w-(14+lw)-4, RIGHT, size 11, text color (muted when hidden)",   // ICD:1418-1419
    "example at w=190 (derived)": "lw = 99, value x = 113, value width = 73",
    "row height": "max(14, nameH+2, valueH+2)",                 // ICD:1420
    "after a group": "+3"                                        // ICD:1437
  },
  "value modes for rating stats": "percent (default) \"22.48%\" | rating \"528\" | both \"528 / 22.48%\"",   // ICD:1261-1269
  "groups and lines": "exactly Character Stats' tree (see 1.7.2): Core Stats > Primary / General / Offensive / Defensive, Secondaries, Tertiaries",   // ICD:1215-1250
  "hover": "the name in white, then the Stat Calculator's hover lines (label 0.75,0.75,0.8 / value 0.95)",   // ICD:1289-1301
  "row highlight": "white alpha 0.06",                         // ICD:1426
  "wheel": "28 per notch (LIST_ROW*2)",                         // ICD:1306
  "combat": "keeps its numbers; redrawn once when combat ends"  // ICD:1450-1464
}
```

## 2.7 Stat Calc button

```json
{
  "frame": "XayaUIStatCalcButton, child of CharacterFrame",     // ICD:1485
  "size": "64 x 18",                                            // ICD:1486
  "anchor": "RIGHT -> close button's LEFT, x -4, y 0 (title row); fallback TOPRIGHT of window (-28,-3)",   // ICD:1487-1488
  "label": "Stat Calc", "font": "GameFontHighlightSmall (size not set: INFERENCE template default), centered",   // ICD:1490-1491
  "closed panel": "bg xui-button bg (fallback 0.04,0.04,0.04,0.7), text xui-button text (fallback 1,0.82,0)",   // ICD:1510-1514
  "open panel": "bg xui-tab-selected bg (fallback 0.22,0.1,0.3,0.9), text xui-tab-selected text (fallback white)",
  "hover": "\"Stat Calculator\" + \"Opens or closes the Stat Calculator beside this window; it opens the same way next time. It also opens on its own from the XayaUI minimap button or /xui stats.\"",   // ICD:1497-1498
  "shows when": "Improved Character Display on, its 'Stat Calc button' ticked (default on), and the Stat Calculator says its panel is available (loaded, on, panel on, not in combat)",   // ICD:1508, SC:2466-2469
  "moves with": "the wider window's right edge (INFERENCE per comment ICD:1475-1477)"
}
```

## 2.8 Settings page: QoL > Improved Character Display

- Node `"Improved Character Display"`, order 2, `childGroups = "tree"`. The row switch is `"Improved Character Display"` (ICD:2015-2021). It is off by default (ICD:93).
- Its child pages are **tree nodes, not tabs** (`childGroups = "tree"`, ICD:2021). Whether AceConfig shows them nested in the left tree is **INFERENCE**.

**Main page, in order of `order`:**

1. intro text (0) (ICD:2023-2024): `"What XayaUI adds to the character window: one item level on each slot's icon; each slot's enchant, the embellishment and the gems against the right edge of the slot's icon; the full stat list in the stats pane; the Stat Calc button. ... Off by default."`
2. `Item level`, toggle (3), default on (ICD:2027, ICD:88)
3. `Enchants`, toggle (4), default on (ICD:2028)
4. `Gems and sockets beside the slots`, toggle, full width (5), default on (ICD:2029)
5. `Empty sockets`, toggle, full width (5.5). Default off; greyed while the gems are on (ICD:1995-2002)
6. `Text size`, range 8-16 (5.6). Greyed unless the 2S mark shows (ICD:2005-2008)
7. `Full stat list (every Character Stats line)`, toggle, full width (6.5), default on (ICD:2032)
8. `Stat Calc button`, toggle, full width (7), default on (ICD:2011-2014)

**Child node "Enchant Slots"** (order 20) (ICD:1966-1988, ICD:2034):
- A note.
- One toggle per slot in CM.SLOTS order: Head, Neck, Shoulder, Back, Chest, Shirt, Tabard, Wrist, Hands, Waist, Legs, Feet, Finger 1, Finger 2, Trinket 1, Trinket 2, Main Hand, Off Hand. Labels are the game's slot names (QSM:1193-1199).
- Button `"This expansion's slots"` (order 99).
- Default ticks: Head, Shoulder, Chest, Legs, Feet, both rings, Main Hand, and Off Hand when it holds a weapon (QSM:1341, QSM:1357-1365).

**Child node "Stat list"** (order 50) (ICD:1894-1963, ICD:2025-2026):
- intro, then `Reset the list`.
- Per group, an inline group: `Heading` (input), `Color`, `Default color`.
- Per stat, an inline group: `Show`, `Shows` (Percent / Rating / Both (rating / percent); rating stats only), `Up`, `Down`, `Name`, `Color`, `Default color`.

**Related page**, Blizzard Reskin > Character Reskin (CR:799-815), for the window size: switch `Character Reskin`, then `Clean window`, `Stat list colors`, `Wider window (room for the enchant names)`, `Extra width` (0-300, default 42), `Extra height` (0-300, default 0), `Background opacity` (50%-100%, default 95%).

---

## 3. Open points (not settled by code)

- The pixel widths of the measured table columns (Stats grid, Stat Weights, spells) come from the game's font measure. Only the rules and minimums are in code.
- The default font sizes of Blizzard templates where XayaUI never calls SetFont: tab labels, Min/Max text, Stat Calc label.
- The real width of `CharacterStatsPane` (code fallback 190) and the window's height.
- Whether a block row over the stats pane or the full stat list takes the hover. The code marks this UNVERIFIED IN GAME (ICD:1817-1822).
- On main there is no Stat Calc button or Improved Character Display (SC:15-17). A combined wireframe of both screens shows the QA build.
