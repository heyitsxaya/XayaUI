# Merge Rules: use cases and conflicts

*For Xaya, 2026-11-09. Read from branch `claude/keen-pascal-60os7w` (f7035f9). Nothing was changed. Nothing here has been seen in game: the build's own log says "NOT RUN IN GAME" (debug-log/2026-11-08-2121-merge-rules-0.6.82.md:6).*

**How Merge works today (your decisions, rows 19 and 27).** Select several rules, right-click one and choose **Merge N Selected**.
- The rule you right-click is kept. It keeps its own name, display, sound, cues, load settings, talents and conditions.
- Only the other rules' triggers move into it.
- "Aura is on you" triggers join one shared trigger, which is true if **any** of those auras is on you.
- "Aura is missing" triggers join one shared trigger, which is true only if **all** of those auras are gone.
- Any other trigger (a cooldown, an aura with a time limit, an item count and so on) is added as its own extra trigger.
- The kept rule then fires when **any** of its triggers is true.
- The other rules go to the Recycle Bin, one item each.

Where: XayaUI_Rules_Options/RuleMerge.lua:9-17, 107-141, 210-236.

---

## Part 1: Use cases, and what you will see afterwards

### 1. Well Fed variants (your screenshot: Well Fed, Well Fed, Aura 1233706, Aura 1233712)
- **What happens:** all four are "on you" rules, so every ID joins the kept rule's one aura trigger. The build's test checks this with your four rules: one trigger, 5 IDs, and it fires on any one of them (debug log section 4, test C).
- **Display:** the kept rule's display appears whenever any Well Fed is on you. The time left comes from whichever one it finds first (XayaUI_Rules/Conditions.lua:665-676).
- **Icon:** the kept rule's own main aura. If you right-click "Aura 1233706", the icon is that aura's picture even when a different Well Fed is up (XayaUI_Rules/Visual.lua:231-233). See conflict 7.
- **Sound:** the kept rule's sound plays once, when you go from no Well Fed to some Well Fed (XayaUI_Rules/Engine.lua:100-104).
- **Name:** the kept rule keeps its own name. Right-click "Aura 1233706" and the merged rule is still called "Aura 1233706". So right-click the one with the best name.
- **In combat:** the game can still draw this display itself, because everything went into one aura trigger with no extra triggers (XayaUI_Rules/Combat/AuraDisplay.lua:183-191).
- **Afterwards:** the selection is cleared and the list jumps back to its top row (RuleMerge.lua:229, 232). See conflict 1.

### 2. Flasks, potions, augment runes
- **Different strengths or versions of the same item** work exactly like Well Fed: one trigger, any version counts.
- **Different items as "on you" rules** (for example, show an icon while flask *or* rune is up) also work. The display shows while either one is up.
- **Different items as "missing" reminders** is the risky case. See conflict 5.

### 3. Several procs to one display
- **What happens:** all the proc auras join one trigger. The display shows while any proc is up, so you have one icon spot instead of several.
- **Icon:** always the kept rule's main proc, not the proc that is actually up (conflict 7).
- **Sound:** plays when the first proc comes up. If a second proc comes up while the first is still on, there is no new sound, because the rule never turned off (Engine.lua:100-110). See conflict 8.
- **Procs with a time limit** ("only when under 3 seconds left") are kept as their own separate triggers, not joined (RuleMerge.lua:66-72).

### 4. Missing-buff reminders
- **Same buff, several versions** (for example, any Well Fed): this works well. It reminds you only when you have none of them.
- **Different buffs** (for example, flask missing plus food missing): it reminds you only when **both** are missing. See conflict 5.

### 5. Mixed "on you" and "missing" rules
- The "on you" ones join one trigger and the "missing" ones join another. The rule fires if either trigger is true.
- **Different auras** (for example, proc A is up OR buff B is missing): this works, and both share one display and one sound.
- **The same aura on both sides** (Well Fed up AND Well Fed missing): the rule is always on. See conflict 6.

### 6. Cooldowns joined with auras
- **What happens:** a rule's cooldown trigger becomes an extra "cooldown" trigger with all of its settings (RuleMerge.lua:52-57). The kept rule fires when the spell is ready **or** the proc is up.
- **Display:** set to "When the rule fires", it works. Set to "While the buff is present", it ignores the cooldown and any aura that landed as an extra trigger (conflict 14).
- **Icon:** if the kept rule has a cooldown spell, the icon is that spell (Visual.lua:231).
- **In combat:** the game no longer draws the display for you once there are extra triggers (conflict 12).

### 7. Rules in different groups, or with different load settings
- The kept rule stays in its own group and keeps its own load settings, including the group's settings (Conditions.lua:1800-1820).
- The other rules' groups and load settings go to the bin with them. Their auras are now watched whenever the kept rule is loaded. See conflict 3.

---

## Part 2: Conflicts

Each conflict has: what happens today, why it matters in play, the options, and my recommendation.

### Conflict 1: After a merge, the list's top row or the kept rule?
- **Today:** the selection is cleared and the list goes back to its top row, keeping its scroll position, the same as after a delete (RuleMerge.lua:229-232; TreeHelpers.lua:294-306). The build's log says opening the kept rule "was not asked" (debug log section 5).
- **Why it matters:** you just changed a rule and can't see what it now holds. In a long list you have to go and find it.
- **Options:**
  - (a) Top row, as now.
  - (b) Open the kept rule on its Trigger tab, with the list kept in place.
  - (c) Open the kept rule on its Display tab.
- **Recommended: (b).** You see the merged triggers right away, and nothing else moves.

### Conflict 2: Restoring one merged-away rule from the bin
- **Today:** restoring puts the rule back exactly as it was (XayaUI_Rules/RuleBin.lua:319-385). Nothing removes its aura from the kept rule. Nothing is recorded about which rule it was merged into.
- **Why it matters:** the same aura now drives two rules. You get two displays and two sounds every time it comes up, which is clutter and noise in a fight.
- **Options:**
  - (a) Leave it as is.
  - (b) On restore, ask: "Its auras are also in 'X'. Take them out of 'X'?" This removes only the IDs that came from this rule.
  - (c) Do (b) automatically, without asking.
  - (d) Add a single "Undo merge" that puts everything back.
- **Recommended: (b).** You stay in control, and it prevents the double firing. This means a bin item has to remember which rule it was merged into and which IDs it brought.

### Conflict 3: Different load settings, or different groups
- **Today:** only triggers move. The other rules' load settings, group and talents are dropped with them (RuleMerge.lua:10, 107-141). The question names none of the differences (RuleMerge.lua:199-207).
- **Why it matters:** two examples.
  - A raid-only "flask missing" reminder merged into an always-on Well Fed rule now reminds you in the open world.
  - A proc rule limited to one spec is now watched in every spec. That is harmless for "on you" auras you can't get, but noisy for "missing" reminders.
- **Options:**
  - (a) As now.
  - (b) Refuse when load settings differ.
  - (c) Allow it, but list the differences in the question ("'Flask' loaded only in raids; after the merge it follows 'Well Fed': always").
- **Recommended: (c).** It doesn't block the merge, and nothing changes behind your back.

### Conflict 4: Different "seconds left" limits
- **Today:**
  - A plain "on you" aura joins the shared trigger.
  - An "on you with N seconds left" aura becomes its own extra trigger (RuleMerge.lua:66-72).
  - If the kept rule's own aura has a time limit, it isn't used as the shared trigger, so plain auras get a new trigger of their own (RuleMerge.lua:96-99, 130).
- **Why it matters:** with "any trigger fires", the wider trigger always wins.
  - "Well Fed is up" plus "Well Fed under 5 minutes left" fires the whole time Well Fed is up, so the warning does nothing.
  - "Under 5 minutes" plus "under 1 minute" behaves like "under 5 minutes".
- **Options:**
  - (a) As now.
  - (b) Warn in the question when one trigger already covers another.
  - (c) Refuse.
- **Recommended: (b).** Name the trigger that will never matter, and let you decide.

### Conflict 5: "Missing" reminders for different buffs
- **Today:** every "missing" trigger joins one trigger that is true only when all of those auras are gone (RuleMerge.lua:11-13, 111-131; Conditions.lua:660-676).
- **Why it matters:** "Flask missing" plus "Food missing" becomes "remind me only if I have neither". Eat food and the flask reminder goes quiet. This is the opposite of "any trigger fires", which is how you described merged rules in row 27. For versions of the *same* buff (Well Fed), "all gone" is exactly right.
- **Options:**
  - (a) As now.
  - (b) Join "missing" auras only when they are the same buff (same name). Different buffs each keep their own "missing" trigger, so either one missing fires the rule.
  - (c) Ask in the question, one choice per group of auras.
- **Recommended: (b), but it needs your OK,** because it reads "missing ones consolidate with missing" as "versions of the same buff". Inference: "Aura 1233706 / 1233712" in your screenshot may not share the Well Fed name. If so, (b) would keep them apart, and (c) is the safer fallback.

### Conflict 6: The same aura as both "on you" and "missing"
- **Today:** nothing stops it. Both triggers are kept, and with "any trigger fires" one of them is always true.
- **Why it matters:** the display and sound come on and stay on.
- **Options:**
  - (a) As now.
  - (b) Warn.
  - (c) Refuse, with a plain line: "'X' watches Well Fed being up and being missing; merged, it would always fire."
- **Recommended: (c).** No player wants a rule that is always on.

### Conflict 7: The icon shows only one aura
- **Today:** with the icon set to automatic, the picture is the kept rule's cooldown spell, or else its main aura (Visual.lua:216-236). It never follows the aura that is actually up. The time and stacks do follow the aura that was found (Conditions.lua:665-676). Inference: in combat, when the game draws the display itself (case 1), it shows the real aura's icon.
- **Why it matters:** with merged procs or consumables, the icon can show the wrong thing. You can't tell at a glance which proc you have.
- **Options:**
  - (a) As now. You can already pick a fixed spell, item or picture for the icon (Visual.lua:216-229).
  - (b) Automatic icon follows the aura that is up. This costs one picture lookup when the aura changes, not every frame.
  - (c) Show the merged rule's icon choice in the question.
- **Recommended: (b),** with (a) still available to you.

### Conflict 8: Sound plays only on the first aura
- **Today:** the sound plays when the rule turns on, and again only on its repeat timer (Engine.lua:100-110).
- **Why it matters:** with merged procs, a second proc that comes up while the first is still on makes no sound.
- **Options:**
  - (a) As now.
  - (b) Play again when a different aura becomes the active one.
- **Recommended: (a).** This is how every rule works, and (b) risks a burst of sounds in busy fights. If one proc needs its own sound, keep it as its own rule. The question could say "one sound for all".

### Conflict 9: Refusal you did not ask for: rules with 2 or more triggers set to "ALL must be true"
- **Today:** refused with a chat line naming the rule (RuleMerge.lua:86-90).
- **Why it matters:** "spell ready AND buff missing" would become "spell ready OR buff missing" and fire most of the time.
- **Options:**
  - (a) Keep refusing.
  - (b) Allow it and switch the rule to "any" quietly. This changes what it does.
  - (c) Leave that rule out and merge the rest, with a count, the same way edit-locked rules are left out (RuleMerge.lua:212-219).
- **Recommended: (a), and please confirm it,** since you didn't ask for it. (c) is a fair alternative if being blocked feels annoying.

### Conflict 10: Refusal you did not ask for: kept rule has a trigger in use with no state picked
- **Today:** refused (RuleMerge.lua:147-150). A trigger with no state counts as always true (Conditions.lua:319-321, 1446-1448), so with "any trigger fires" the rule would never turn off.
- **A gap:** on the *other* rules, the same empty trigger is dropped without a word. It is noted (RuleMerge.lua:58, 74), but only the kept rule is checked (RuleMerge.lua:147).
- **Recommended:** keep the refusal, and have the question say "'Y' has an empty Cooldown trigger; it is not carried over".

### The other refusals the builder added (RuleMerge.lua:18-21)
- A cue or condition row is part of another rule.
- An aura trigger has no aura ID.
- A shared aura trigger would watch more than 31 auras (its own plus 30 more).
- The rule would end up with more than 12 extra triggers.
- **Recommended:** keep all four. Each one stops a merge that would lose an aura or break the rule, and each names the rule and the fix.

### Conflict 11: In combat, the Cooldown Manager fallback is lost for a merged aura
- **Today:** when the game hides an aura in combat, a rule's built-in aura trigger can ask the Cooldown Manager's icon for the rule's *own* spell (Conditions.lua:925-931, 986-998, 1030). Extra aura triggers never get that help (XayaUI_Rules/Triggers.lua:676). After a merge, a merged-away rule's aura either:
  - uses the kept rule's spell, which only helps if it shares a name with the aura, or
  - lands as an extra trigger with no help at all.
- **Why it matters:** an example is Insivius' Death and Decay case. In combat its answer goes back to "unknown", so the rule stays quiet, and a missing reminder never fires. The build's log calls this "rare; not handled" (debug log section 5, marked as inference).
- **Options:**
  - (a) As now.
  - (b) Warn in the question when a merged-away rule depended on its own spell for this.
  - (c) Let each aura trigger carry its own spell. This needs an engine change in XayaUI Rules.
- **Recommended: (b) now, (c) later.**

### Conflict 12: In combat, the game stops drawing the display when a merge adds extra triggers
- **Today:** the game draws the display for you in combat only if the rule is a single aura trigger. Any extra aura trigger, or "When the rule fires" with other triggers, hands it back to XayaUI (AuraDisplay.lua:183-191, 214-217).
- **When it happens:** Well Fed-style merges keep the game drawing. A merge that adds a cooldown, a time-limited aura, or a second aura trigger loses it.
- **Why it matters (inference from AuraDisplay.lua:3-5, 12-13):** in combat, the time and stacks on that display may be estimated or blank.
- **Options:**
  - (a) Warn in the question.
  - (b) Teach the game-drawn path the "any of these auras" case.
- **Recommended: (a) now, and (b) for the case where every trigger is an "on you" aura.**

### Conflict 13: In combat, one hidden aura makes a joined "missing" trigger unknown
- **Today:** "missing" needs every aura to be confirmed gone. If one aura can't be read in combat, the whole trigger is "unknown" and doesn't fire (Conditions.lua:669-675).
- **Why it matters:** merging a reminder that works in combat with one that doesn't makes both stop working in combat.
- **Recommended:** a one-line note in the question when the merge joins "missing" auras. Most of these reminders matter out of combat anyway.

### Conflict 14: A display set to "While the buff is present" ignores anything merged in as an extra trigger
- **Today:** that display choice looks only at the rule's main aura trigger (Engine.lua:66; Conditions.lua:1962). It ignores extra triggers, including auras that landed there.
- **Why it matters:** the rule fires but the display doesn't show.
- **Recommended:** the question says so and suggests "When the rule fires" for merged rules.

### Conflict 15: The other rules' cues, conditions, displays and sounds go to the bin
- **Today:** each merged-away rule goes to the bin with all its cues and conditions (RuleBin.lua:17-46). The question says they go "with their own settings" (RuleMerge.lua:203-206).
- **Why it matters:** a glow cue or a bar you had on one Well Fed rule disappears. This matches "only triggers merge".
- **Recommended:** keep this. The question names any cues that will leave, so nothing disappears unexpectedly.

---

## Performance

Merging lowers the work each update, because there are fewer rules to check. One shared aura trigger checks its auras in order and stops at the first one it finds (Conditions.lua:665-676). The 31-aura limit keeps that small. No new per-frame work is added. Recommendations 7(b) and 2(b) add work only when something changes.

## Summary of recommendations

| # | Conflict | Recommended |
|---|---|---|
| 1 | Which rule is selected after a merge | Open the kept rule on its Trigger tab, list kept in place |
| 2 | Restore from bin fires twice | Ask "take its auras out of 'X'?" on restore |
| 3 | Different load settings or groups | List the differences in the question, don't refuse |
| 4 | Different "seconds left" limits | Warn when one trigger covers another |
| 5 | "Missing" for different buffs | Join only versions of the same buff (**needs your OK**) |
| 6 | Same aura "on you" and "missing" | Refuse |
| 7 | Icon shows one aura | Automatic icon follows the aura that is up |
| 8 | Sound only on the first aura | Keep as now, and say so |
| 9 | Refusal: "ALL must be true" rules | Keep (**please confirm**) |
| 10 | Refusal: trigger with no state | Keep, and mention dropped empty triggers |
| 11 | Cooldown Manager fallback in combat | Warn now, engine fix later |
| 12 | Game-drawn display in combat | Warn now, extend later |
| 13 | Hidden aura in a joined "missing" trigger | One-line note |
| 14 | "While the buff is present" display | Suggest "When the rule fires" |
| 15 | Cues and displays go to the bin | Name them in the question |
