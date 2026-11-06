# What's new in XayaUI

**Updated 2026-11-06 evening:** section 3 (below) covers the debug round that landed after this page was first written.

**2026-11-06.** The character pane round landed on `main` at d2ccacd (2026-11-06 07:16 UTC, QoL 0.7.31 and 0.7.32).
Section 1 describes the character pane as it is on `main` now. Section 2 lists the other features that reached `main` in the 24 hours
before that landing (2026-11-05 07:16 UTC to 2026-11-06 07:16 UTC).

**Nothing on this page has been tested in game yet.** Every item below was built and checked with XayaUI's automated tests only.
Where the game may behave differently from the tests, the item says so.

Versions on `main` when this was written (main d2ccacd): XayaUI 0.6.51, Options 0.6.50, QoL 0.7.32, Bonus Features 0.6.17,
Chat 0.6.18, Reskin 0.6.4.

---

## 1. Character pane

Two parts: the **Character Reskin** (Blizzard's character window in XayaUI's look) and the **Stat Calculator** (a panel beside the
character window). Both are off until you turn them on.

### Character window (Character Reskin)
Turn it on: the tick box on the **Character Pane** row of the Blizzard UI Reskin tab (the switch is called Character Reskin;
greyed while the tab's **All reskins** box is unticked), or `/xui reskin on`.
`/xui reskin status` reports what it is doing; `/xui reskin options` opens its settings. Every part below has its own switch.

- **Solid background.** The whole window, the stats list and the added width included, gets a solid fill in your theme's window
  colour, so the game world no longer shows through. **Background opacity** (50% to 100%, default 95%) sets how solid it is.
- **Clean window.** Blizzard's frame art (portrait, stone frame, backdrop picture) is replaced by a thin border, the theme's colours
  for title, tabs and stats list, and plain item slots.
- **One item level per slot, coloured by upgrade track.** Veteran green, Champion blue, Hero purple, Myth orange, Explorer and
  Adventurer grey; dimmer at the first upgrade step, full at the last. If another addon already shows an item level on a slot,
  XayaUI's stays hidden there so you never see two (`/xui reskin status` names the other addon's text). Track names are read in
  English; on other game languages the number uses the item's quality colour.
- **Enchant names beside each slot.** The enchant's own name in green, wrapped, without the "Enchant Ring - " prefix; "No enchant"
  in orange on a slot that should have one. Hover the line to see what the enchant does, as far as the game tells addons
  ("Effect text not given by the game." when it gives only the name).
- **Embellished items.** A light-blue line "Embellished (worn/limit): <item name>". Hover it for "Embellished - Name: <item name>"
  and the item's effect text. (The game does not name the embellishment itself, so the item's name is shown.)
- **Gems and sockets.** One row per socket under the enchant: the gem's icon (16 px; 12 px only where 16 does not fit) and its name;
  an empty socket shows its type ("Prismatic Socket") in orange. Hover a gem for its tooltip.
- **Wider window.** On by default. The Character tab is **Extra width** wider (0 to 300 px, default 42: 380 px without the stats
  list, 582 with it, where Blizzard's are 338 and 540). The model stays its size and centred. When a slot's text has too little room
  beside the model, it runs over the model's edges rather than disappearing (QoL 0.7.28); raise Extra width to keep it clear of the
  model (240 fits every enchant name of this expansion). Long lines that still do not fit are cut at a word with "...": hover for
  the whole line. The width changes only out of combat; a change made in a fight applies when the fight ends.
- **Extra height (QoL 0.7.31).** A slider under Extra width: 0 to 300 px, default 0 (Blizzard's height). The window grows that much
  taller, the gaps between the slots grow evenly, the model gets taller (its width stays), the weapons move down with the bottom of
  the window, and each slot's enchant, embellishment and gem lines may use the extra room. Changes apply out of combat; a change
  made in a fight applies when it ends.
- **Full stat list (QoL 0.7.31).** The character window's stats pane can show every line of the Stat Calculator's Character Stats:
  the headings Core Stats, Primary, General, Offensive, Defensive, Secondaries and Tertiaries and every stat under them, each name
  in its stat colour, with the same numbers the Stat Calculator shows (numbers you typed there are left out). Hover a line for the
  Stat Calculator's hover. On with the reskin, every line shown to start with. Arrange it on **Character Pane > Stat list**: per
  stat Show, Up / Down (its place in its group), Shows (Percent, Rating, or Both as "528 / 22.48%", for secondary and tertiary
  stats), Name, Colour and Default colour; per heading Name and Colour; and **Reset the list**. Turn the part off ("Full stat
  list") for Blizzard's own list.
- **Upgrade fix (QoL 0.7.27).** If you used QoL 0.7.21-0.7.23, your window kept those versions' 240 px extra width. It now changes
  once to the new 42 px default; any other width you chose is kept.
- **Stats list styling.** Theme-coloured headers with a thin rule, muted labels, and a faint stripe on every other row.
- **Safety.** Turning a part off gives Blizzard's look back at once (out of combat). If anything goes wrong while the reskin applies,
  it turns itself off until `/reload` and says so in chat.

### Stat Calculator
Turn it on: **QoL > Character Toolkit** (tick box in the left pane, then **Panel**). Open it with the **Stat Calc** button in the
character window's title row, with **Stat Calculator** in the XayaUI minimap button's list, or with `/xui stats`
(`/xui stats on`, `off`, `options`, `status`).

**The window**
- **Opens on its own.** The minimap row and `/xui stats` open it without the character window, where you last dragged it. It docks
  beside the character window while that is open.
- **Remembers open or closed.** The Stat Calc button opens and closes it, and the next time you open the character window it comes
  back the way you left it.
- **Min / Max.** A button in the title row switches between a smaller height (440 to start) and a larger one (760 to start; longer,
  never full screen). Set both under Panel > Layout (**Smaller height**, **Larger height**); dragging the corner sets the one you are
  in. **Reset size** puts width and heights back.
- **Wider by default.** It opens 450 px wide so every column fits at the default text size; a width you dragged it to is kept.
- **Tabs:** Stats | Gear | Ability Scaling (Ability Scaling was called Spells). The tab you had open is kept.

**Stats tab**
- **Gear Summary at the top, as a graphic.** Your rating in each secondary and tertiary stat, how much comes from your gear's stats
  and how much from elsewhere (gems, enchants, buffs), and your empty sockets. Choose the look under Panel > Layout >
  **Gear Summary style**: Split bars (default), Stat tiles, One stacked bar, Columns, Gear share, or Table. Hover a stat for its
  three numbers.
- **One "Character Stats" section.** Core Stats (Primary; General: health, your resource, global cooldown, movement speed;
  Offensive: attack and spell power, attack speed, weapon damage per second, weapon damage, critical strike effectiveness;
  Defensive: armor, dodge, parry, block, stagger for Brewmasters), then Secondaries, then Tertiaries.
- **Category bars.** Primary, General, Offensive and Defensive are drawn as thin bands in your theme's accent colour, with the stats
  indented under them.
- **Critical strike effectiveness.** No game call gives it, so XayaUI adds up every "critical strike effectiveness by N%" in your
  equipped items' tooltip text (English only; talents and buffs are not included). Hover it to see which items it came from.
- **Columns: Stat | Rating | Current value | Pt value | Influences | Change.** The note column and all note text are gone.
- **Influences column.** The names of what a stat feeds (Agility: Attack power, Dodge, Armor) and, marked "from", what feeds it
  (Attack Power: from Agility). Hover a name for its value, its per-point value and the new value.
- **Try a different number.** Type a number in a stat's **Change** box (the box at the far right of its row) and press Enter.
  Every number it moves shows the new value with its sign underneath ("+2,800") in the accent colour; the Rating cell shows your
  rating with the change beside it ("528 +172"). Empty the box, or type your own number, to put it back. The old "All ratings" box
  is gone. Panel > Your numbers > **Clear all** resets every box.
- **Ability lists moved.** The "Abilities (per 100)" and "Ability Scaling" lists left the Agility / Strength card; they now live on
  the Ability Scaling tab.

**Stat Weights** (a pane under Character Stats; click its header to fold it)
- One row per stat: **Stat | Rating (P / %) | PPP | DR Threshold | T/L Rating | Influences.** Your rating and percent; the rating
  for 1% (and, past a diminishing-return threshold, what the next point gets); the next threshold; T, the rating that counts in
  full, and L, the rating lost to diminishing returns (on two lines); and what the stat feeds now.
- Hover a row for a sentence such as "Haste decreases Global cooldown by 0.34 s". An amount the game does not give reads
  "not given". This is not a simulated damage-per-point weight.
- Column titles are never cut and sit centred over their columns (widths are measured from the game's own text widths). On a narrow
  panel the influences go under each row; at 580 px wide or more they get their own column.

**Gear tab**
- **Click an equipped item to compare it;** click it again to let it go. The picked item now has a clearly visible frame in your
  theme's accent colour (before, the frame was drawn but too dark to see).
- **Slots named clearly:** Ring slot #1 / #2, Trinket slot #1 / #2, Main-hand, Off-hand.
- **Your bag items as icons,** best item level first. Click to pick up to 3 to compare side by side; click again to let one go.
  With two rings, trinkets or one-hand weapons, choose which one they replace.
- **One "Changes" table:** item level, primary stat, Stamina, armor, each rating, sockets and enchant, with each item's change
  (green better, orange worse); under each rating the next diminishing-return threshold and T / L. Then **Stat effects**,
  **Spell Changes** (up to 6 spells, Strength and Agility specs) and **On-use and proc effects**, which reads
  "RPPM not given by the game" where an item has a proc (no game call gives proc rates).
- Durability and repair were removed from every pane.

**Ability Scaling tab** (was Spells)
- **Filter icon** (a funnel) at the right of the top row: None (every spell), Offense, Defense, Utility. The choice is kept.
  (Which filter a spell falls under is a guess from the words of its English description.)
- **Configure / Refresh spell data** is one button above the lists; the stray "Refresh spell data" row inside the list is gone.
- **Columns: Spell Name (spell ID under it) | % PSV | Talent Modifiers | Computed Value.** % PSV shows each number as a percent of
  your attack or spell power and what one point of your primary stat adds. Under it, a line per other stat that changes the
  number: "Versatility: +N%" for spells that deal damage, heal or absorb, and "Mastery: +N%" only where your mastery's text names
  the spell or its school.
- **Computed Value** is never cut. With a number typed on the Stats tab, the new first number shows under it with its sign. This is
  an estimate that assumes the spell's description already counts your versatility and mastery: **not yet checked in game.**
- The "Usable now" line is gone.

**Character window tooltips**
- Hovering a stat in the character window adds a short XayaUI block under Blizzard's text. It now has its own switch:
  **QoL > Character Toolkit > Tooltip lines**; while it is off, nothing of it runs.

**Settings summary**
- Blizzard UI Reskin > Character Pane: every Character Reskin switch, Background opacity, Extra width, Extra height.
- Blizzard UI Reskin > Character Pane > Stat list: the full stat list's lines, order, names and colours.
- QoL > Character Toolkit (tick box in the left pane), with Panel, Slot Overlays, Spell Math and Tooltip lines under it.
- Panel > Layout: side, detail level, rating lines, text size, Gear Summary style, background, Smaller / Larger height, Reset size.

### Also in this round: Release Guard (QoL 0.7.31)
Turn it on: **QoL > Release Guard** (its own row with a tick box; off by default, and while off nothing of it loads or listens).
- When you die, a black box covers the death window's **Release Spirit** button so a misclick does not release you. It reads
  **NO RELEASE** (you can change the text), with a flavour line under it that changes each death: to start, "BAD MONKEY",
  "death comes for us all", "NOPE", "Disagree", "WTB Rez" (edit the list; one per line, each on or off).
- Hold the click-through key (Shift to start; Ctrl or Alt in settings) and the box steps aside so your click reaches Release; let go
  and it is back. It hides once you are a ghost or the window closes.
- Where it works: raids only to start, or raids and dungeons, or everywhere.
- It never presses Release for you; it only covers the button.
- **Not yet tested in game:** whether the death window always comes through the way XayaUI watches for it (a backup check covers
  it).

---

## 2. Other new features (landed on `main` from 2026-11-05 07:16 UTC to 2026-11-06 07:16 UTC)

- **Blizzard UI Reskin settings tab** (Options 0.6.38). Every reskin now has one home: a Blizzard UI Reskin tab with Chat Panel,
  Character Pane and Esc Menu. The old Chat tab is gone. The old shortcuts still open the moved pages: `/xui chat settings`,
  `/xui reskin options`, and the Chat Panel's own settings buttons. The XayaUI button in the Esc menu stays under
  Settings > UI Options > Display.
- **All reskins, and a tick box per reskin** (XayaUI 0.6.51, Options 0.6.50, Chat 0.6.18, Reskin 0.6.4). The Blizzard UI Reskin
  tab button has its own tick box, **All reskins**: untick it and every reskin in the tab is off at once, with Blizzard's own look
  back. Each reskin (Chat Panel, Character Pane, Esc Menu, Shopping List) has its own tick box on its row in the left pane, greyed
  while All reskins is off and keeping its own state. All reskins is on unless you untick it. With it off, nothing of any reskin
  loads at login, and `/xui chat` and `/xui reskin status` say that All reskins is off.
- **Shopping List** (QoL 0.7.32). Off by default; turn it on with the tick box on the Shopping List row of the Blizzard UI Reskin
  tab. `/xui shop` shows or hides the panel (`/xui shop options`, `/xui shop status`).
  - **Missing on your gear:** each enchantable slot without an enchant and each empty socket, with one suggestion each (your own
    default for that slot, else what XayaUI has seen you use most on it). "Other" shows what you used before, what is in your bags
    and, while the Auction House is open, what it has. "+ Add" puts a suggestion in To buy.
  - **To buy:** what you added, with have / need; x removes a line.
  - **Your tracked recipes:** each with its reagents and have / need, counted the way Blizzard's tracker counts them. Finished lines
    are ticked and dimmed. The x on a recipe stops tracking it. Once every reagent is in your bags, it asks whether to stop tracking
    (**Stop** / **Keep**).
  - **The one-per-character gem** (such as this expansion's diamonds): when you are not wearing one, the first empty socket asks
    for it; the other sockets ask for your normal gem. Which gems count is read from the game (unique-equipped, limit 1):
    **not yet confirmed in game.**
  - Enchants you add are counted by the enchant scrolls in your bags whose name holds the enchant's name: **not yet confirmed in
    game.**
  - **Click a name** while the Auction House is open to search for it there; Shift-click links the item.
  - Blizzard's own Professions list in the objective tracker takes your theme's colours (its own switch: "Restyle Blizzard's
    Professions list"). The rest of the objective tracker is unchanged for now.
  - Settings: **Your defaults** (one per enchantable slot and one for gems) and **History** (forget what this character used;
    empty To buy).
- **Dynamic group Sort list reordered** (Options 0.6.50). The group's Sort choices are now listed Default, Expiration, Name,
  Important, Manual. Manual is still the default.
- **Tick boxes in the left pane** (Options 0.6.40). In QoL and Bonus Features, each feature's on / off is a tick box beside its name
  in the left pane; hover it for what it does.
- **Bonus Features > Utilities** (Options 0.6.40). Notepad and Calculator are grouped under a new Utilities entry.
- **Talent scan moved to Settings** (Options 0.6.40). Scan all talents now lives under Settings > UI Options > Rule Creation
  (`/xui talents` still works).
- **Switched-off features cost nothing** (Chat 0.6.14, XayaUI 0.6.47, Reskin 0.6.2, Options 0.6.41, Bonus 0.6.12). A feature you
  turn off no longer runs anything in the background: no timers, no event listening, no frames. A few hooks placed while it was on
  stay idle until `/reload`.
- **Faster console switches; clickable version text; tidier Rules tabs** (XayaUI 0.6.45, Options 0.6.39). The console switches in
  settings no longer pause while the whole window rebuilds. The version text at the bottom of the settings window replaces the
  Addon Info button: click it to open Addon Info; it uses your theme colours. The Rules sub-tab row stays compact instead of
  stretching across the row.
- **`/xui help` is readable and shorter** (XayaUI 0.6.46, 0.6.50). One command per line, with the command in your theme's
  accent colour. Since XayaUI 0.6.50 it is much shorter: only the commands a player uses (17 lines with the Shopping List's
  `/xui shop`; it was 29), with option lists such as [on|off].
- **Type commands in the console** (XayaUI 0.6.50). Open the console with `/xui console`; the line along its bottom takes any
  XayaUI command, with or without `/xui` (for example "debug status"). Press Enter: the command is echoed in grey and its output
  prints in the console. Up and Down bring back earlier commands. `/save` and `/reload` reload the interface; any other game or
  addon slash command is refused with a red line. An empty console says what to type and where your other XayaUI messages go.
  **Not yet tested in game:** whether Up / Down recall works, and whether `/save` and `/reload` work there without a
  "blocked" message.
- **All diagnostic commands under `/xui debug`** (XayaUI 0.6.50). Type `/xui debug` for the list (status, perf, timing, map,
  loader and more). Any `/xui debug` command opens the console and prints there, even when typed in the normal chat box.
  `/xui debug window` is renamed `/xui debug loader` (it says whether the settings window's code can load, for when `/xui`
  will not open it). The old short forms such as `/xui perf` no longer run; they print `/xui help` instead. Two shortcuts stay:
  `/xui status` (every rule's answer right now, and why) and `/xui auras` (aura IDs, and whether XayaUI can follow them in
  combat) print in chat.
- **Chat history shows "|" correctly** (Chat 0.6.17). Lines containing "|" now show every pipe and letter (before, a pipe and
  sometimes the next letter went missing), and searching for text with "|" finds them. **Not yet tested in game:** whether
  copying such a line pastes one "|" or two.
- **Chat history keeps the letter after a "|"** (Chat 0.6.19, on `main` at 4fa2150, 2026-11-06 about 21:20 UTC; a later landing than the
  window above). In the chat history window (the Console tab and the chat tabs), a "|" followed by r, n, c, T, H, A or K no longer
  loses that letter. Example: the `/xui chat` status line used to read "on|off|eset|move|..." and now reads
  "on|off|reset|move|history|wrap|indent|whispers|settings". **Not yet tested in game** (QA D13); what Ctrl+C pastes, one "|" or
  two, is also still unchecked (QA D12).
- **Cursor colours as UI themes** (XayaUI 0.6.46, QoL 0.7.17). Each Gradient Cursor Trail gradient is also a UI theme in
  Settings > Theme ("Cursor trail: <name>"). The trail can follow your UI theme ("Match the UI theme"), and the Cursor Highlight
  can use your theme's accent colour.
- **Chat history: opens where you are; whisper tabs** (Chat 0.6.15, 0.6.16). The history window opens on the chat tab you are on,
  with All moved to the end. Whisper conversations get their own tabs, following the game's New Whispers setting, or all in one
  Whispers tab (History > Whisper tabs). People with the same name on different realms get separate tabs.
- **Choose which auto rules to make** (Options 0.6.41; see the note on version numbers below). Rules > Class/Spec Rule Creator > **Choose which rules
  to make** lists your spec's cooldowns and target debuffs. Tick only the ones you want, pick each one's main cue (Speech, Icon or
  Progress texture; Progress bar is not available yet), choose On the target or Missing from target for debuffs, then
  **Make the ticked rules**. Your choices are kept per spec.
- **Cooldown Manager warnings** (XayaUI 0.6.48, Options 0.6.43). If a rule follows an aura or target debuff that the game hides in
  combat and Blizzard's Cooldown Manager is not tracking, its Display and Cues tabs show a red line saying the Cooldown Manager must
  track it first, and where to add it. XayaUI cannot add it for you: Blizzard keeps that window closed to addons.
- **Enhanced Tooltips switch** (Bonus 0.6.14). The Tooltips feature is now called Enhanced Tooltips and has one tick box that turns
  the whole feature on or off (Bonus Features > Enhanced Tooltips; on by default).
- **Notepad whole-feature switch** (Bonus 0.6.14). The Notepad's tick box (Bonus Features > Utilities > Notepad) turns the whole
  Notepad off, sharing included; your notes are kept. **Show Notepad**, `/xui notes` and the box's x still show and hide it.
- **Calculator switch** (Bonus 0.6.16). The Calculator (Bonus Features > Utilities > Calculator) has its own tick box, on by
  default. Off, its window does not open and its minimap row is gone; `/xui calc <sum>` still answers in chat.
- **`/notes` and `/calc`** (Bonus 0.6.17). Two short commands: `/notes` shows or hides the Notepad like `/xui notes` (only while the Notepad is on) and `/calc`
  does what `/xui calc` does. If another addon already owns either word, XayaUI leaves it alone and the `/xui` forms still work.
  After you turn the Notepad off, `/notes` stays until `/reload` and only says the Notepad is off.
- **Clearer Aura ID lines on tooltips** (Bonus 0.6.13, 0.6.15). On spell tooltips, an aura icon ID that is the same as the spell's
  own icon is no longer repeated. (Since the later landing in section 3 the source text shows only while XayaUI Dev Assist is enabled,
  not under Advanced Debugging.) While **Advanced Debugging** was on (it was on by default), each Aura ID line
  ends in grey with where the ID was found ("via this tooltip", "via Cooldown Manager", "via your casts", "via buff on you",
  "via recorded earlier").
- **`/xui debug map`** (XayaUI 0.6.49; it now prints in the console, like every `/xui debug` command). A report command for the full-screen world map problem: it prints the map's state so the
  cause can be found. It does not fix the problem yet.

## 3. Developer tools moved to Dev Assist, and the debug report (landed on `main` 2026-11-06 evening, main 687b624)

From the debug round (request log FUS-1 to FUS-5, her answers in the question box). Nothing here has been tested in game yet.

- **Developer tools now live in XayaUI Dev Assist.** These commands exist only while the Dev Assist addon is installed and enabled:
  `/xui debug` probe, timing, model, tracker, mods, groups, icons, media, seed, map, gamemenu, chatprobe, widthprobe, perf ui, debuffs
  and loc; `/xuitt` probe, lines and aura; `/xui chat` wrap, indent and whispers; `/xuiskin pad` and `/xuiskin alpha`; and
  `/xuiengine` auto, on, off and reset. Without Dev Assist they are not there. (`/xui debug seed` adds three test rules to your own rules,
  which is why players should not have it.)
- **What players keep:** `/xui debug perf`, `/xui debug loader`, `/xui status`, `/xui auras`, `/xuiskin` (turns the window skin off),
  and `/xuiengine full` and `refresh`.
- **Tooltip "via ..." source text** (the grey "via this tooltip", "via Cooldown Manager" and so on at the end of an Aura ID line) now
  shows only while XayaUI Dev Assist is enabled.
- **Combat Tracking Setup moved** from the Debugging page to Settings > UI Options > Rule Creation.
- **Error codes and a debug report.** XayaUI now records only errors and warnings, each with a code (XUI-E...), and only when they
  happen, so it costs nothing otherwise. `/xui report` opens a readable summary you can screenshot, with a **Copy** string you can send.
  Dev Assist reads that string back with `/xuidev report`. The detailed record kinds (rule snapshots, aura answers, and so on) now live in
  Dev Assist.
- **Documents moved.** The project documents (this page, the user guide, the QA checklist, the roadmap and the session summary) are in
  `docs/`; README and THIRD_PARTY stay at the root.

*Not in this list yet:* the rest of that landing's changes (core 0.6.57, Options 0.6.57, Chat 0.6.25, QoL 0.7.34, Bonus 0.6.19, Reskin 0.6.6,
Dev Assist 0.7.5: the Info pane / Patch Notes, chat changes, the settings window look and more). Their sessions send their own notes;
they are added here only once they arrive and are checked against `main`.

**Version numbers:** two different changes on `main` carry the label Options 0.6.41 (the "switched-off features cost nothing"
work and the auto-rule picker; two sessions numbered them at the same time). They are listed as they are; history is not
renumbered.
