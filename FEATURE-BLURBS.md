# XayaUI Feature Writeups

Short blurbs for five features, written from the source (XayaUI 0.5.40). Each has a one-line **tagline**, a **blurb** for a README or addon page, and **status notes** so the text does not promise more than exists. As of the source, none of these were confirmed working in game.

---

## Class/Spec Rule Creator

**Tagline:** Start from your class's cooldowns and auras instead of a blank page.

**Blurb:** The Class/Spec Rule Creator builds a first batch of rules for you. Pick your spec (the buttons come from the game, so every class and spec works), or run it for all specs of your class at once, and XayaUI makes one skeleton rule per tracked cooldown or aura. The rules are sorted into Defensive, Offensive, and Utility folders inside one parent folder named "[Class] [Spec] - autorule population," with anything unclassified landing in Unsorted. You can include talents you have not picked; those rules simply stay unloaded until the talent is known. A separate scan reads every class, spec, and hero talent tree straight from the game, so the data follows each patch rather than a fixed list.

The rules it creates are skeletons: they watch for the cooldown or aura but show and play nothing until you decide what each one should do.

**Status notes:**
- Rules are skeletons by design; their behavior is still to be defined (Xaya's decision).
- The sorting into Defensive, Offensive, and Utility uses curated lists by spell name. The only spec list I could confirm in the code is Vengeance Demon Hunter, labeled as written from general class knowledge and not checked against game data. Other specs use the generated class data, with unsorted spells going to Unsorted.
- **License flag:** `ClassData.lua`'s header says it was generated from public GitHub data files of two other addons (WeakAuras2 templates and Open-Raid-Library). Your project rule is that XayaUI must never be in violation of a license. Check this file's provenance before publishing; I did not evaluate the licenses.

---

## Rule Drafts

**Tagline:** Edit freely. Nothing you were working on gets lost.

**Blurb:** Rules apply the moment you change them, so you can test an edit in game right away. XayaUI keeps a saved version of each rule (with its cues and conditions) from when you opened the options window or last pressed **Save changes**. When a rule differs from its saved version, you get **Save changes** and **Discard changes**, plus **Save as a copy** (keep the edit as a new rule and send this one back) and **Add to drafts** (park the edit and restore the saved version). If you close the window or log out with unsaved edits, those edits are kept on the **Drafts** page instead of vanishing, and the rule returns to its saved state. From Drafts you can **Put back in editor** and keep working, or delete a draft for good. The Drafts page holds up to 30 drafts.

On/off state, name, group, collapse state, sidebar icon, and edit lock are not counted as changes, so flipping a rule on or off never creates a draft.

**Status notes:**
- A rule created in the current window and never saved lives only in Drafts after the window closes.
- Putting a draft back loads it into the editor; it is not saved until you press Save changes.

---

## Custom Data Panels and Bars

**Tagline:** Put the numbers you care about in strips wherever you want them.

**Blurb:** Five on-screen info strips, each holding 1 to 20 data slots: a **Bottom Left Panel** and **Bottom Right Panel** pinned to the screen corners, a full-width **Top Data Bar**, and two free-form strips, **Custom Panel** and **Custom Bar**, that you can drag anywhere. Every slot can show any data type: time, frame rate, latency, gold, durability, free bag slots, or your own custom text, plus a full set of character stats (crit, haste, mastery, versatility, leech, avoidance, dodge, parry, block, item level, armor, primary stats, stamina, max health, absorb). Each strip has its own width, height, growth direction (horizontal or vertical), text alignment, backdrop and border, colors, frame layer, tooltip placement, a hide-in-combat option, and a visibility macro. A shared General page sets the font, outline, and size, and can block clicks and mouseover during combat. Open the settings with `/xui data`, or right-click any strip.

**Status notes:**
- Own code written from the option set only; no third-party addon code or data (per the project note).
- Stats keep their last readable value when the game marks them secret.
- Not yet tested in game. Not yet pushed to GitHub or synced to Google Drive at the time of the project note.
- Not offered: location, movement speed, combat timer, friends, guild, currency, experience, and reputation.

---

## Notepad

**Tagline:** A floating scratchpad that never eats your notes.

**Blurb:** Notepad is a movable, resizable box for typed reminders. It holds any number of notes, with a toolbar to create, duplicate, delete, and flip between them. Text saves as you type, and earlier versions of every note are kept automatically: a new version after a pause in typing, and always just before a big chunk of text is removed. Deleted notes go to a trash, and the **Hist** button opens a Restore list of earlier versions and deleted notes (up to 20 versions per note, 30 in the trash, 8,000 characters per note). The toolbar can sit at the top, bottom, left, or right, and can appear only when your mouse is over the box. Choose the font, size, backdrop opacity, and frame layer; lock it in place; hide it in combat; and have it release the keyboard when combat starts so it never steals your keybinds. Open it with `/xui notepad`, the close button on the box, or the QoL UI Updates > Notepad page.

**Status notes:**
- Own code written against Blizzard's frame API only.
- Not yet tested in game.

---

## Addon Theming and Color Customization

**Tagline:** Make the XayaUI window look the way you want, down to a single button class.

**Blurb:** XayaUI's look is driven by a style sheet in two layers. **Tokens** are the palette: accent, labels, body and muted text, window, panes, borders, title bar, buttons, primary buttons, tabs, selected tabs, tree bars, and danger marks. **Element classes** (window, pane, tab, button, heading, and more) each point at a token, and each class can be overridden on its own, so you can recolor "all buttons" or "all headings" without touching anything else. Start from the default purple, a **class** theme that follows your character's class color (or one you pick by hand), or a built-in preset, including colorblind-friendly palettes for red-weak, green-weak, and blue-yellow color vision, plus a light theme. Switch to **Custom** to layer your own changes on any base, and save themes by name to reuse them. Choose a font and a size (small, medium, or large). A theme is plain data, so importing and exporting a theme never runs code.

**Status notes:**
- The code describes the theme as applying to XayaUI's own interface (options window and related panels). I did not check which other XayaUI elements, such as the data panels, notepad, or chat panel, follow the theme.
- The "light" theme and three colorblind presets are in the source; I did not verify how they look.
