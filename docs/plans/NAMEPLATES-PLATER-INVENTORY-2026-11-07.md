# Nameplates: inventory of Xaya's Plater setup (2026-11-07)

What her four Plater export strings contain, and what each part does in the game, written in our own words.
Nothing from Plater (code, data, spell or NPC lists, wording) is copied here (#290). The strings themselves stay outside the repo.

## How this was read
- Source: her message in session "Outstanding items 11-06" (session_014bN6tSStpdmmCXviFAqPdQ), 2026-11-07 07:04 UTC: "if you can
  replicate the following mods and profile functionality into xui and make it cost less, here are the nameplate mods and settings I
  rely on", followed by four `!PLATER:2!` strings. Relayed with it: "I rely heavily on these three at least, though" (Aura Reorder,
  Current Target Color, Reorder Nameplate).
- Decoding, for reading only (never run): base64, then raw deflate, then CBOR. Every string decoded to the last byte (5,665 / 1,511 /
  5,665 / 358,662 bytes consumed exactly), so all four arrived intact. Strings 1 and 3 are byte-identical (same SHA-1).
- The decoder and the decoded copies are in the session's scratch folder, outside the repo, and are not committed.

| # | What it is | Size decoded |
|---|---|---|
| 1, 3 | one mod: "Reorder Nameplate" | 5.7 KB |
| 2 | one mod: "Current Target Color" | 1.5 KB |
| 4 | her whole Plater profile: about 400 settings, 12 mods, 48 scripts | 359 KB |

The two mods in strings 1-3 match the copies inside the profile exactly.

## 1. Mods (code that runs on every nameplate)
Twelve mods are in the profile; **three are switched on**, and they are exactly the three she named.

| Mod | On? | When it runs | What it does in game |
|---|---|---|---|
| Reorder Nameplate | **on** | when a nameplate appears | Places the plate's parts: the health bar in the middle of the clickable area, the cast bar right under the health bar (centred, its own width), the power bar under the health bar, and the two aura rows anchored to the health bar per the aura settings. Pets and minor mobs get smaller bars (her values: pets 95 % x 95 %, minor mobs 90 % wide x 95 % tall). It is a copy of Plater's own built-in layout step, so with no edits it gives the same layout Plater already draws (her copy has no edits that change the result; INFERENCE from reading it against its own description "exported to scripts"). |
| Current Target Color | **on** | when a plate appears, **on every plate update tick**, and when the target changes | Paints the health bar of the player's current target one fixed colour (hers: the named colour "teal"); every other plate is put back to its normal colour. Never touches the player's own personal bar. |
| Aura Reorder | **on** | once, at load | Turns on aura sorting and replaces the sort rule: auras on a short priority list (by spell name or ID) go first, bigger number first; everything else ties. Her list is the mod's shipped example (five spells for Shadow Priest and Outlaw Rogue); sort-by-time is off and inverse sort is off, so in practice only those five spells move. INFERENCE: she never edited the list (it matches the example the mod describes). |
| Attacking Specific Unit | off | every plate update | Recolours a plate when its unit attacks a chosen kind of unit. **It is OFF in this export**, yet her chat earlier showed it failing on every plate update ("attempt to perform string conversion on a secret string value"). Either she switched it off after that, or the export is from a different moment. FLAGGED: needs her check, not a question now. |
| Color Automation, Hide Neutral Units, Don't Have Aura, Extra Border, Cast Bar Icon Settings, Execute Range, Combo Points, Players Targeting a Target | off | - | Not used. Listed so nothing is missed. |

## 2. Scripts (code that runs on a trigger: an aura, a cast, or a particular unit)
48 scripts; **34 are on**. Most carry Plater's shipped trigger lists (spell IDs or NPC IDs; counts below, the lists themselves are not
copied). Three are not Plater's shipped set by name: "Auto Set Skull" (off), "M+ Spiteful" (on), "Countdown" (on).

| Kind | On | What the group does |
|---|---|---|
| Cast scripts (cast starts / updates / ends) | 21 on, 8 off | Decorate the cast bar of chosen enemy spells: flashes, a different colour or spark, a glow, a bigger bar, a timer after the cast, a frontal-cone or ground-zone animation, "tank buster", "heal that can't be interrupted", "stop casting", "interruptible once the shield drops", highlight the cast's target name. Trigger lists range from 2 to 94 spell IDs (largest: frontal cones 94, AoE-hit-all 53, void zones 40). |
| Aura scripts (an aura is on the unit) | 7 on | Alert when a listed buff or debuff is on the enemy; blink by time left; show a shield amount as a bar; show a cast-style bar for an aura's duration; fixate warning when an enemy buff means it is chasing you; highlight while an aura is up and the unit casts. Two of them ("Buff Alert", "Debuff Alert") have empty trigger lists, so they do nothing as set. |
| Unit scripts (a particular NPC) | 10 on, 2 off | Colour and highlight important adds (14 NPCs), health-phase markers (1 NPC), "explodes on death" (3 NPCs), fixate on you (5 NPCs + 9 spells), countdown bar for units with timed events (5 NPCs), Spiteful time-to-die (1 NPC), energy amount above the plate, non-elite trash look, add warning colour, fixate target name. |

## 3. Settings (the profile), grouped
Values are hers. Only the settings that change what she sees are listed; Plater's internal bookkeeping (counters, news, caches) is left out.

**Plate size and layout (enemy NPCs)**
- Health bar 135 x 14 out of combat, 145 x 18 in combat. Cast bar 135 x 9 out of combat, 145 x 12 in combat. Power bar 100 x 4.
- Clickable area 140 x 28. Plates stack (no overlap), with overlap spacing 1.1 x 1.3.
- Look: health texture "You Are Beautiful!" (a LibSharedMedia texture), dark background (about 11 % grey, 89 % opaque), 1 px black
  border at 83 %. Cast bar texture "Details Flat".
- Fonts: "Noto Sans SemiCondensed", outline, sizes 9-10 (name, health percent, spell name, cast time); level text off.
- Name above the bar (max width 90, wraps), health percent shown (no decimals), shown out of combat too.

**Colours**
- Threat colouring for the DPS role on (aggro red, no aggro light blue, pulling yellow); tank threat colours off.
- Unit-type colouring on (boss purple, mini-boss blue, caster cyan; elite and trivial colouring off).
- Quest mobs coloured (orange). Tapped mobs grey. Class colours for players.
- NPC colour list: 6 NPCs coloured by ID (indigo). Cast colour list: 15 spells (hot pink). Cast sound list: 15 spells (sounds include
  files from BigWigs and game sound IDs).
- Cast bar colours: normal orange-yellow, channel green, not interruptible grey, interrupted red, important red-orange.

**Target and focus**
- Target highlight on (blue glow texture under the bar, 75 %), target indicator "Silver"; non-targets dimmed to 60 % **in combat only**.
- Focus indicator on (a texture over the bar).
- Mouse-over highlight on (30 %).

**Auras**
- On. Debuffs: the player's own on enemies; Blizzard's own choice of debuffs ("as Blizzard does") on; buffs: Blizzard's choice, the
  unit's own buffs; dispellable buffs shown; crowd control shown as debuffs (border dark red-brown).
- Icon sizes 20 x 17 (row 1) and 13 x 16 (row 2), 10 per row, auto per row; timer on (size 9, no decimals), stack count (size 10).
- Swipe on, reversed. Border coloured by debuff type for debuffs.
- Sorting on (set by Aura Reorder). 4 buffs banned by ID.

**Range and alpha**
- Range check on: out-of-range plates at 65 %, in range or target 90 %.
- Health animation on; colour fade off; update tick every 0.25 s.

**Indicators**
- Elite, rare, world boss, quest, pet, faction, spec icons on; raid mark (extra copy) on.

**Boss mods support**
- On: boss-mod icons above plates (24 x 24), cast rename, glow for important casts and cooldowns.

**Game options Plater set for her** (saved console variables): enemy plates shown, friendly NPC and player plates off, names only for
friendly players, plates kept on screen edge, minimum alpha about 90 %, minimum scale 80 %, overlap 0.8 / 1.3.

**Auto toggles**
- Enemy plates shown in every zone type (on); friendly / combat / stacking auto toggles off.

## 4. Triggers at a glance (what makes Plater do work)
| Trigger | What runs on it |
|---|---|
| Plate appears | layout (Reorder Nameplate), target colour, unit scripts |
| **Every plate update tick (0.25 s, per plate)** | target colour, threat colour, range alpha, unit scripts, aura scripts |
| Every frame while health changes | health bar animation |
| Target changes | target colour, target highlight, dimming |
| Aura added / removed | aura icons, sort, 7 aura scripts |
| Cast start / update / stop | cast bar, 21 cast scripts, cast colours and sounds |
| Combat start / end | in-combat sizes, dimming |
