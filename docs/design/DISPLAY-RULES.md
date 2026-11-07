# XayaUI display rules (the standard every window and settings page follows)

Started 2026-11-06 for REQUEST-LOG UI-47 (Xaya, verbatim: "review every single tab within the entire addon and make sure every single
display type is correctly standardized. make sure all design and addon display rules are stored in their own file in the appropriate
location if they aren't already. / refactor all code appropriately. / priority: high.").

- Her own words behind each rule, with sources: [DISPLAY-RULINGS.md](DISPLAY-RULINGS.md) (row numbers in brackets below, e.g. [3.9]).
- A rule here is either **RULED** (her words or her pick in a question box) or **PROPOSED** (waiting for her yes, never built before
  it, V16). Anything still open in the logs is not a rule (DISPLAY-RULINGS section 18).
- The numbers live in code in one place: core `ns.Style` (`XayaUI/Modules.lua`, section 0; section C here). A window or page never repeats a number that is there.
- When she rules something new: add the ruling to DISPLAY-RULINGS.md, the rule here, and the value to `ns.Style`, in the same commit.

## A. Rules (RULED)

### A1. Meta
1. A precise structure she gives (columns, labels, order) is built exactly: nothing added, renamed or reordered [0.1-0.5].
2. Anything she has not decided is proposed through the question flow and waits for her answer [0.4, 0.7].
3. Ideas checked against WeakAuras, ElvUI or EUI: behaviour only, our own design and code [0.8].

### A2. Settings window: tab rows
1. Top tabs: Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings [1.6, 1.7] (built in Options 0.6.72, UI-23..27: no
   toolbar above them; "+ New Rule" is a flat button at the left end of the Rules row; Profiles = Import | Export | Recycle Bin).
2. Top tabs share the row evenly edge to edge, 32 px tall, 14 pt outlined, clearly the parent level [1.4, 1.5, 11.3].
3. Rules sub-tabs: 27 px, 11.5 pt outlined (UI-76: "a little narrower and maybe 3-5% smaller"), each 90% of its even share; Smart Categories, Enabled, Disabled, Drafts share the row evenly; "Auto-Generate Rules" apart
   at the far right [1.9, 11.3; UI-45].
4. Tabs are tabs, not buttons [1.1]. Clicking a tab never resizes the panes [1.2].
5. No tick box on a tab button; a tab's own switch is on its first left-pane row, "Overview", with a reload prompt [3.7].

### A3. Left pane (sidebar)
1. A feature is a row; its parts are child rows; a part's sections are tabs on its page [12.1, 2.2].
2. A child row starts 8 px right of where its parent's name starts (its tick box when it has one, else its name) [2.4, 2.5].
3. Collapse / open buttons as WeakAuras: header rows (Loaded, Not Loaded, ...) at the far right end with the eye just left of it;
   group rows at the row's bottom right of the icon (waiting for her screenshots); 8 px per level [2.6, 2.7, 4.1].
4. An unticked feature's name is grey, and so are its parts [3.8, 3.9].
5. The sidebar keeps every row after any click in the right pane [2.9].

### A4. Switches (tick boxes)
1. Every feature's on / off is the tick box on its left-pane row, not on its page [3.1].
2. Off costs nothing: nothing of it is created or runs [3.2].
3. Hover on a switch: its name, one sentence saying what it is, and Enabled / Disabled; never an "Off: ..." text [9.15].
4. While off, every setting on its pages is greyed (cannot be changed) [3.9]; its page shows its summary only, no empty box [3.10].

### A5. Boxes, borders, dividers
1. The left pane and the right pane: their fills, no border lines, one divider line between them; no other frame around them
   [6.3, 6.4].
2. Lists of like items (spells) are separated by divider lines [6.6].

### A6. Buttons and dropdowns
1. Buttons in the addon's own flat style, never Blizzard's red ones [7.2].
2. A dropdown never takes a whole row alone [8.1].
3. Buttons never stretch to fill a row (#352: small buttons, or a tick box with a dropdown to its right) [DL 0902].

### A7. Words
1. Labels short; no extra words on headings ("what feeds it", "usable now") [9.5]. (That the explanation goes in the tooltip is a project
   rule with no quoted source: [9.1].)
2. Names she chose are used everywhere they show: Chat Data Panel, Data Panels, Auto-Generate Rules, Stat Calculator, In-Game Whispers /
   BNet Whispers / Whispers, Patch Notes [9.4, 9.8-9.10, 9.23; UI-45].

### A8. Colours and fonts
1. Theme colours throughout; text in the theme's font [10.1, 10.2].
2. Text must be legible; nothing "way too tiny" [11.1].
3. Docked chat tabs: one height and style for every tab; colours from the addon override or Blizzard's [11.4, 10.5].
4. The settings window's look comes from the theme: every colour is a theme colour (the off grey is the theme's Muted text, the hover's
   Enabled / Disabled its Body / Muted text), names are in the theme's font, and sizes follow its text size [10.12]. `ns.Style` holds
   structure (sizes, gaps, indents); the theme holds the look.
5. The px / pt values in section C are the theme's Medium text size; Small and Large scale tab heights and names alike (x0.88 / x1.15)
   [11.8].
6. Theme page: an "Advanced customization" switch, off by default, offers the parked colours (tabs, tree bars) and the class overrides;
   while off they are neither offered nor applied [10.13].

### A9. Tooltips and page descriptions (UI-51 / UI-53; how they are built: [BUILD-RULES.md](BUILD-RULES.md) section B)
1. A tooltip: a title line, then up to two sentences about that one tab or control; never a whole section's text.
2. A page: a short summary; its longer description in a box opened and closed by an info icon beside the summary (TRIAL on the
   Calculator page only, until she confirms).

## B. Gaps found in the audit (PROPOSED: each waits for her answer)
Filled in as the tab-by-tab audit (UI-47 step 3) finds display types with no ruling. The audit: [DISPLAY-AUDIT-UI-47-2026-11-07.md](DISPLAY-AUDIT-UI-47-2026-11-07.md). Each gap is asked through the question flow; the
answer moves it to section A.

| # | Display type | What differs today | Proposal | Status |
|---|---|---|---|---|
| G1 | Section tabs inside a page (third level, e.g. Shopping List: Your defaults / History) | small Blizzard-sized tabs, each as wide as its text | RULED [UI-48]: "24 px, 11 pt, even row" (outlined, as the other rows) | built (Options 0.6.63), not seen by her |
| G2 | The box under a page's section tabs (bordered, own scroll bar) | a nested box inside the right pane | RULED [UI-48]: "If the item is not enabled no additional fill should exist"; while on: a fill without a border (INFERENCE, to be seen by her) | built (Options 0.6.63), not seen by her |
| G3 | Titled boxes inside a page (e.g. "Whisper sound overrides", "Tab 1: General") | bordered box per group | RULED [UI-48]: "First try unbordered boxes (darker blocks) and dividing lines" | built (Options 0.6.63), waiting for her look |
| G4 | Text inputs (e.g. "Enchant: Head") | each input stretches the full row | RULED [UI-48]: "Half width, two per row" | built (Options 0.6.63): no width, "full" and "double" inputs; not seen by her |
| G5 | Sliders (190) | Blizzard track / thumb art + Skin.lua step arrows in Blizzard's page-arrow art | keep / flat theme-coloured track, thumb and arrows | PROPOSED: Q-UIB-9 (audit 3.1) |
| G6 | Tick boxes inside pages (~310) | Blizzard's gold tick art; theme text colour only | keep / flat theme square, same as the switches | PROPOSED: Q-UIB-10 (audit 3.2) |
| G7 | Colour swatches (148) | Blizzard swatch frame | keep / flat 1 px theme border | PROPOSED: Q-UIB-10 (audit 3.3) |
| G8 | Multi-selects (16, Rules load conditions) | full-width block, one tick box per value | keep / dropdown with ticks | PROPOSED: Q-UIB-11 (audit 3.4) |
| G9 | Small text blocks (41, Rules tab) | GameFontHighlightSmall beside medium elsewhere | keep / one size (medium) | PROPOSED: Q-UIB-12 (audit 3.5) |
| G10 | Heading "Auto-populate my class / spec" | old feature name | keep / "Auto-Generate Rules for my class / spec" | PROPOSED: Q-UIB-13 (audit 3.6) |
| G11 | Gear Summary style hover | 7 sentences (lists the six styles) | keep until she picks a style / one sentence | PROPOSED: Q-UIB-14 (audit 3.7) |
| G12 | Info icons | older heading (i) (hover + pin) everywhere; UI-53 open / close box on Calculator only | keep both / one icon after the Calculator verdict | PROPOSED: Q-UIB-15 (audit 3.8; waits on Q-UIB-7) |

### Session choices made while building section B (each listed for her look; none is a ruling)
| # | Where | Choice | Why |
|---|---|---|---|
| S1 | Section tabs | a row with under 60 px per tab keeps AceGUI's own layout (`tabSection.minW`) | so no tab name is cut off |
| S2 | Auto-Generate Rules | its name's width at 12 pt + 24 px, at most a third of the row | her answer fixed its place, not its width |
| S3 | Off page with all its text inside tabs (Data Panels, Enhanced Tooltips) | shows the switch's one sentence | otherwise the page would be blank ("just show the summary") |
| S4 | Text inputs drawn by their own widget (spell search and the like) | keep their own size | they are search boxes with their own layout, not plain text lines |

## C. The values (code: core `ns.Style`, `XayaUI/Modules.lua` section 0)
Every window and page reads these; nothing repeats them. Values marked (session) were chosen by a session, not by her. The px / pt values
are at the theme's Medium text size (A8.5). The grey is only the fallback when the theme is missing (A8.4).

| Key | Value | From |
|---|---|---|
| margin, gutter | 10, 10 (session) | #351 [5.1] |
| tabTop.h, tabTop.font, tabTop.outline | 32, 14, true | [1.5] |
| tabSub.h, tabSub.font, tabSub.outline, tabSub.apartGap | 27, 11.5, true, 16 (gap: session) | [UI-45]; 4% smaller [UI-76] (her "3-5% smaller": session's reading) |
| tabSub.share | 0.9 (session) | [UI-76] "a little narrower": each tab 90% of its even share |
| nest.child | 8 | [2.5] |
| nest.level (WeakAuras) | 8 | [2.7] |
| switch.size | 16 (session) | |
| grey | 0.5, 0.5, 0.5 (session) | [3.8] |
| divider.size | 1 px, theme pane border colour (session) | [6.3, 6.6] |
| bodyIndent (trigger / cue / condition panes) | 20 (session) | |
| tabSection.h, tabSection.font, tabSection.outline | 24, 11, true | [UI-48] |
| tabSection.minW | 60 (session) | S1 |
| input.width | half the row (two per row) | [UI-48] |
