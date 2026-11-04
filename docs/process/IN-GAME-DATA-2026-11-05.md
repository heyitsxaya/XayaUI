# In-game data run: Thursday 2026-11-05, morning

For Xaya. The probe records what the game lets an addon read, in and out of combat. Claude reads the file afterwards. You do not
need to read anything in game. Allow about 1 to 1.5 hours. Nothing here changes your rules or your settings.

## Before you start (5 minutes)
1. Copy the `XayaUI_GameDump` folder (version 0.6.0, from `main` once this change is merged) into `AddOns`, next to `XayaUI`. At
   the character screen, open **AddOns**. Turn on **XayaUI** and **XayaUI Game Data Capture**. Check that it shows version 0.6.0.
2. Log in. Type `/console scriptErrors 1` so any Lua error shows on screen.
3. Type `/combatlog`. Chat should say combat logging is **on**. It is a switch: if chat says it turned **off**, type it again.
4. Type `/xuidump probe on`. Chat says `probe: ON` and how many spells it checked.
5. Type `/xuidump probe status`. On the line starting `1 context`, check that it says `combat log true`.

From here, the probe runs by itself until you type `/xuidump probe off`. A `/reload` does not stop it: it starts again and says
"resumed after a reload".

## What to do
Do the steps in this order. Skip any you cannot do; say which ones you skipped.

1. **Proc glows on a training dummy (10 minutes).** Fight a dummy until procs light your buttons. Good examples: Boiling Point on
   Blood Boil (Blood Death Knight), Rime on Howling Blast (Frost Death Knight), Divine Arbiter on Divine Storm or Final Verdict
   (Retribution Paladin). Let each proc light up at least 3 times.
2. **The same procs out of combat.** Get a proc on the dummy, then walk away until combat ends while the button still glows. Do
   this twice. If a proc never lasts that long, say so.
3. **Spells you want checked.** For any other spell or aura ID, type `/xuidump probe spells <id> <id> ...`, for example
   `/xuidump probe spells 59052` (Rime's aura, from `docs/reference/procs.md`). Chat says, for each ID, whether the game hides
   its casts and its aura in combat. These IDs are also watched on your own buffs from then on, so add the aura IDs of your procs
   before step 1 if you can. Boiling Point and Divine Arbiter are already on the built-in list.
4. **A spell that changes into another.** Use an ability that turns into a different one while a buff is up, if your spec has
   one, a few times in and out of combat.
5. **Raid marker test.** Solo, or tell your group first: the skull is visible to everyone.
   - Out of combat, target a mob and type `/xuidump probe mark`. Chat says whether it ran.
   - In combat, target a mob and type `/xuidump probe mark` again.
   - If the game shows a box saying the addon was blocked, click **Ignore**, not Disable. That box is a result too.
6. **Open world combat (10 minutes).** Make sure enemy nameplates are shown. Before pulling, target one mob and set another as
   focus (`/focus`). Pull a few mobs together. Let some of them cast. Interrupt one cast if you can.
7. **One dungeon or Mythic+ run, Voidscar Arena if possible.** Keep combat logging on. Before each pull, look at the mobs so their
   nameplates show. Target and focus one mob before the first pull. Then play normally.
8. **One boss pull.** A dungeon boss counts. A raid boss is a bonus. Let the boss cast its abilities and emotes.
9. **Check.** Type `/xuidump probe status` and take a screenshot of the chat lines, if you like.
10. **Stop.** Type `/xuidump probe off`. Then type `/combatlog` (chat should say logging is off).
11. **Write the file.** Type `/xuidump save`. It reloads the interface and writes the file. Logging out also works.
12. **Upload:**
    - `World of Warcraft\_retail_\WTF\Account\<account>\SavedVariables\XayaUI_GameDump.lua`
    - `World of Warcraft\_retail_\Logs\WoWCombatLog.txt` (zip it first: it can be large)
    - Tell Claude which steps you did, your class and spec, and roughly when you did each step (your clock time).

The probe keeps the newest 6,000 entries, so a long dungeon run can push out the dummy part. The counts in `/xuidump probe status`
are kept in full. To keep the dummy part too, do step 11 and copy the file aside after step 5, then carry on.

## What each part answers
| Step | Probe entries | Question it answers |
|---|---|---|
| 1, 2 | glow show / hide (GS, GH), proc art (OS, OH), spell snapshot | Do proc glows reach an addon in combat, with a readable spell ID? Does `IsSpellOverlayed` agree? Which spell ID does the event name when a spell is replaced (base and override are read too)? Is a spell's required aura (`hasRequiredAura`) readable? |
| 1, 2 | glow pairing (GP), about 0.1 s after each glow | Only when XayaUI core has the proc-glow table (`PROC_GLOW_AURAS`, coming from branch `claude/eloquent-rubin-n9zb99`); otherwise status says `absent`. Is the aura XayaUI pairs with the glow really on you? `found` = agrees; `none` = disagrees; `secret` = hidden, so the glow is the only signal. |
| 1, 3, 6 to 8 | watched spells (AW) at combat start, combat end and each change of your auras | For each watched spell: `ShouldSpellAuraBeSecret`, and whether reading the aura gives found / none / secret. Lined up with the combat log's aura lines, it shows whether "not secret" plus "none" really means the aura is absent (retrospective gap 20). |
| 3 | secrecy list | Is this spell's cast or aura never, always, or sometimes hidden (`C_Secrets` levels)? The built-in list and your XayaUI rules' spells are checked at every `probe on`. |
| 4 | override updates (OV), icon updates (IC) | When the Cooldown Manager reports a spell change, with both IDs and the time. |
| 5 | mark (MK), blocked-action entries (AB, AF) | Can an addon put a raid marker on a mob, in and out of combat? |
| 6, 7 | nameplates (NA, NR, UF), enemy casts (CS, CC, CL, CI, CT) | Is a mob's identity (creature ID, GUID, name) readable out of combat and hidden in combat? Does a nameplate keep its token through a pull? Are enemy cast spell IDs readable, and on which units? Who interrupted? |
| 7, 8 | boss timeline (TA, TR, TS), warnings (EW), emotes (BE), encounter start / end | Which boss timeline fields can an addon read in a pull? Are boss warnings and emotes readable? |
| all | anchors, combat start / end (RD, RE), your casts (PC) | Lines every entry up with the combat log file: the anchors hold the game's timer and your clock; your own casts appear in both. Also: are restrictions, hidden auras and hidden cooldowns switched on, and does the old `LoggingCombat` function still exist for addons? |

## Other captures worth running the same morning (all optional)
Each writes into the same file. Run them out of combat.
- `/xuidump toolkit`: Character Toolkit checks. It records your spells' base global cooldown, the global cooldown now, each item's
  durability and repair cost, the item levels the game builds for one of your items, an item's stats with and without gems, and
  whether the stat pane is there. Run it once away from a vendor and once while talking to a repair vendor.
- `/xuiformula start`: tooltip formula capture. It takes a snapshot of your stats and spell numbers 2 seconds after each gear or
  talent change. Swap gear pieces to change your attack or spell power at least 3 times, and versatility once at the same power.
  `/xuiformula status` says what is still needed; `/xuiformula stop` ends it. The walkthrough is
  `XayaUI_GameDump/FORMULA-CAPTURE-WALKTHROUGH.md`.
- `/xuidump catalogue`: every aura current content points to. Run `/xuidump static` first (10 to 40 seconds). Run the catalogue once
  on each spec you play. It pauses in combat. It changes the Adventure Guide's tier and filters while it runs and puts them back.
- `/xuidump seen`: the aura log. Type it once to start and once to stop. It logs every aura on you, your target, focus and party,
  read out of combat and when combat ends.

Then do step 11 again (`/xuidump save`) so everything is in the file.
