# Formula capture walkthrough

This walkthrough records how your spells' numbers change when your gear changes. From those readings, `tools/formula_fit.py` works out each spell's formula for your spec and talents, for example "Fracture = 2.77 × attack power × (1 + versatility)". The results ship in a small data folder for your class. **XayaUI Bonus Features** then shows them on your spell tooltips as **Observed:** lines.

Nothing here is copied out of the game files. Every number is one the game shows you, read through the normal addon API.

**Time:** about 5 minutes per spec and talent setup.
**Needs:** XayaUI, XayaUI Bonus Features and XayaUI Dev Assist turned on, plus 4 free bag slots.

## Why these steps

Each spell's number is roughly *coefficient × your power × multipliers*. Your power is attack power, or spell power on intellect characters. To find the coefficient, the fit needs the same spell read at **three or more different power levels**, with nothing else changing. Taking gear off changes your power. Talents and auras would change the multipliers, so keep those fixed during one session.

The fit also needs **one change to versatility while your power stays the same**. That shows whether tooltip numbers include versatility. Rings and necklaces are the tool for this, because they carry no Strength, Agility or Intellect.

## Before you start

1. Go somewhere safe, out of combat: a city or an inn. Don't do this in a dungeon, raid, arena or battleground.
2. Remove temporary effects:
   - food and flask buffs, augment runes and weapon oils;
   - buffs from other players (right-click to cancel them where you can);
   - anything that procs, so wait for proc buffs to run out.

   Permanent passives and your talents stay.
3. Choose the talent setup you want to record and don't change it during the session. Changing talents starts a new recording, which is fine but has to be completed separately.
4. Make sure you have 4 free bag slots.

## Steps

1. **Start.** Type `/xuiformula start`. Chat shows `ON` and then `snapshot 1 (start): attack power …`.
   - If it says `no snapshot: core stats unreadable`, you're in combat or in a restricted area. Move and try again.
2. **Wait for each snapshot.** After every gear change, wait about 3 seconds for the next `snapshot N (gear change)` line. Several quick changes count as one snapshot.
3. **Level 1 is your full gear.** Snapshot 1 already covered it.
4. **Lower your power, one change at a time** (3 or more levels). Stop moving gear between changes.
   1. Take off your **main-hand weapon** (snapshot 2).
   2. Take off your **off-hand** or a **trinket that has your main stat** (snapshot 3).
   3. Take off your **chest** or **legs** (snapshot 4).

   After each snapshot, chat lists what this setup still needs. Once you have 3 power levels, that line no longer asks for power levels.
5. **Versatility test.** Leave the gear from step 4 as it is.
   1. Find a **ring or necklace whose tooltip lists Versatility** and no Strength, Agility or Intellect.
   2. Take it off. Your power stays the same and versatility drops, so you should get a new snapshot.
   3. Chat should now say `versatility test done`.
   4. If none of your rings or necklaces has versatility, skip this step. The data will say "versatility not tested".
6. **Haste (no extra step).** Steps 4 and 5 usually change haste too, which is enough to tell whether cooldowns and recharges scale with haste.
7. **Check.** Type `/xuiformula status`. It should end with `This loadout is complete.`
8. **Put your gear back on.** You can type `/xuiformula stop` before doing this, so the recovery snapshots aren't recorded. Recording them is harmless, though.
9. **Next spec or talent setup (optional).** Switch spec or talents, then repeat steps 1 to 8. Each spec and talent combination is its own recording.
10. **Save.** Type `/reload`, or log out. The game writes the data to `WTF\Account\<your account>\SavedVariables\XayaUI_DevAssist.lua` (before Dev Assist 0.7.0: `XayaUI_GameDump.lua`; the tool reads either).
11. **Send the file**, or run the fit yourself:

    ```
    python3 tools/formula_fit.py "PATH\TO\XayaUI_DevAssist.lua"
    python3 tools/formula_fit.py "PATH\TO\XayaUI_DevAssist.lua" --emit
    ```

    - The first command writes `formula-report.md` with every fit.
    - The second also writes `XayaUI_SpellData_<CLASS>` addon folders.

## Commands

| Command | What it does |
|---|---|
| `/xuiformula start` | Starts recording: takes a snapshot now and after every gear or talent change |
| `/xuiformula stop` | Stops recording |
| `/xuiformula now` | Takes one snapshot now, even if nothing changed |
| `/xuiformula status` | Shows what this spec and talent setup still needs |
| `/xuiformula clear` | Deletes this setup's snapshots |
| `/xuiformula clear all` | Deletes every snapshot |

## What the fit accepts, and what it doesn't

- A formula is kept only if it reproduces **every** snapshot within the game's own rounding. It also needs 3 or more power levels. Anything else is listed as "no fit" and is not shipped.
- Numbers that never moved (a 8-yard radius, "2 Soul Fragments", a 9-second duration) aren't formulas and are left out.
- The coefficient includes every multiplier that stayed the same while you changed gear: spec passives and talents. So each formula belongs to the spec and talents you recorded. The tooltip marks it "other talents" when your current talents differ.
- If versatility never changed at a fixed power level, the formula says "versatility not tested".

## What this cannot do

- **No combat values.** The game hides stats in combat, so recording happens out of combat only.
- **Your class only.** The tooltip loads your own class's data folder and nothing else.
- **Tooltip numbers only.** The game rounds what it prints, and damage that never appears in a tooltip can't be observed. Neither can random procs or target-dependent effects.

## Privacy

Snapshots store your class, spec, talent spell IDs, stats, equipped item IDs and spell text. They store no character names or realms.
