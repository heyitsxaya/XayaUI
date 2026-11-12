# Aura checks in combat: what EllesmereUI does, and our own design (2026-11-12)

Request: REQUEST-LOG A23 SD-54. Her words: "check how EUI checks. it does not fail and performance is kept low". The question is how
XayaUI Rules decides which aura rules to check again, and when, in combat. Today the engine checks every live aura rule again on
every UNIT_AURA, up to 30 times a second (round 5, gate 2).

Status: study and proposal only. No addon file was changed. Building the design is a later round. It needs her answers to the
questions in section 7.

Limit, stated as V25 asks: a cloud session has no game client. Every statement below about how the game or EllesmereUI behaves
in a live fight was read from source text or from the API reference. None of it was measured in game. Such statements are marked
**UNVERIFIED IN GAME** or **INFERENCE**.

---

## 1. Where the EllesmereUI source came from

1. **Her Google Drive folder "Reference Addons (REFERENCE AND READ ONLY)".** Found by title search and read only. Nothing in it
   was written, moved, renamed or deleted. It holds EllesmereUI (core), EllesmereUICooldownManager,
   EllesmereUIAuraBuffReminders and the other EllesmereUI modules, dated 2026-11-08.
2. **The public GitHub repository EllesmereGaming/EllesmereUI**, release v9.8.4 (commit d83ffb7, 2026-11-10). It was cloned
   (shallow, git hooks off) into the session scratchpad at `eui-study/src/github/`. Getting her Drive files one at a time would
   have taken many large downloads, so the public copy was read for most files. Each file was then checked against her Drive
   copy by size: her copies have Windows line endings, so the public file's size was recomputed with those line endings. One of
   her Drive files was downloaded in full (`eui-study/src/drive/`) and read directly.

Every file was read as text only. Nothing was run. The only parsing was a size check and a base64 decode, done with
`python3 -I` scripts kept in a separate folder (`eui-study/tools/`).

| File studied (EllesmereUI) | Same as her Drive copy? |
|---|---|
| core `EllesmereUI_AuraKit.lua` (the shared Blizzard aura-container layer) | yes, same size (125,226 bytes) |
| core `EllesmereUI_Ticker.lua` (self-stopping tickers) | yes (9,607) |
| Cooldown Manager `EUI_CDM_HookViewers.lua` (hooks on Blizzard's Cooldown Manager, the 10-per-second "buff ticker") | yes (70,748) |
| Cooldown Manager `EUI_CDM_HookIconWatch.lua` | yes (90,189) |
| Cooldown Manager `EUI_CDM_BuffBarGroups.lua` | yes (55,202) |
| Cooldown Manager `EllesmereUICdmFakeActive.lua` | yes (99,211) |
| Cooldown Manager `EllesmereUICdmBarGlows.lua`, `EllesmereUICdmBarGlowConditions.lua` | yes (37,527; 3,183) |
| Cooldown Manager `EUI_CDM_AuraIcons.lua` | yes (15,730) |
| Aura Buff Reminders `EUI_AuraBuffReminders_Auras.lua` | yes (45,120) |
| Aura Buff Reminders `EUI_AuraBuffReminders_Refresh.lua` | no: her copy (68,005) is older than v9.8.4 (77,980). Her copy was downloaded and read directly; the refresh pacing described below is the same in both |
| Aura Buff Reminders `EUI_AuraBuffReminders_Lifecycle.lua` | no: her copy is 41,385 bytes, v9.8.4 is 43,745. The v9.8.4 copy was read. Its event handling may differ slightly from the version she runs (INFERENCE) |

"Same size" is strong evidence that two copies are the same, not proof (INFERENCE).

---

## 2. How EllesmereUI decides what to check again, and when

Described in our own words. No code, data or text was copied.

### 2.1 Which aura events it listens to

- **Its own aura displays (unit frames, raid frames, nameplates, Cooldown Manager custom aura icons) do not listen to aura events
  at all.** They are built on Blizzard's aura container widget, which the game added in 12.1. EllesmereUI declares, once, which
  auras a container shows: a filter, or a list of spell IDs for a single slot. After that, Blizzard's own code finds the auras,
  draws icon, time and stacks, and registers UNIT_AURA itself. Blizzard's code holds that registration only while the container
  has content and is visible. Where the client allows it (12.1.5), a switched-off group is not processed, and a container whose
  groups are all off stops listening.
- **Whether a buff is active, for its glow and condition logic ("Bar Glows" and their extra conditions), is read from Blizzard's
  Cooldown Manager icons, not from the aura API.** It listens for:
  - UNIT_AURA on the player, and on the target only while some glow tracks an aura on the target. A glow on your own buffs never
    pays for the target's aura traffic, such as a raid boss's;
  - totem updates, world entry and target change;
  - post-hooks on Blizzard's Cooldown Manager items: an icon becoming active or inactive, an icon being given another spell, and
    the icon pool handing out a new icon.
- **The "custom active state" feature** registers UNIT_AURA on the player only while one of its few built-in aura rules (gated by
  class and spec) or a form rule needs it. It unregisters UNIT_AURA otherwise.
- **The buff reminders** (raid buffs, flasks, food and the like) listen to the player's UNIT_AURA always. They listen to the
  whole group's UNIT_AURA only out of combat, and only for classes that need it. They drop the group-wide registration when
  combat starts, because in combat they only check the player's own auras.

### 2.2 What it reads from the UNIT_AURA payload

It reads the payload only to decide whether something big may have changed, never to decide which rule to check:

- If the payload, or any of its fields (full update, added, removed, updated), is secret, it treats the event as "something
  changed". A secret value cannot be tested for true or false.
- If the payload is readable and says full update, added auras or removed auras, it marks the icon set as possibly changed. A
  stack change (updated auras) counts only while a glow that depends on stacks exists.
- It does **not** keep a general map from aura instance ID to spell. The one exception is narrow: for a few known druid form
  exception auras, it remembers which instance ID belongs to which aura, and only when that ID is readable.

### 2.3 What it keeps between events

- **A "something changed" flag**, set by every event and every hook above. Setting it costs one assignment.
- **A change counter for the icon set.** It goes up only when icons may have been added, removed or given another spell.
- **One "which spells are active right now" table** (spell ID to true), plus a stack table used only for stack-gated glows. It is
  rebuilt by walking Blizzard's four Cooldown Manager icon pools, and only when the change counter moved. While the ticker runs,
  there is also a one-second safety rebuild. An icon counts as active when Blizzard marked it as set from an aura or gave it an
  aura instance. In the two buff viewers, a shown icon that is not a placeholder also counts, so totems and summoned-pet "buffs",
  which Blizzard never gives an aura instance, still count.
- Every glow entry and every extra condition then reads that one table, so the cost of a check does not grow with the number of
  events.

### 2.4 How it limits work per event and per frame

- **Per event: almost nothing.** The handler sets the flag, may bump the counter, and starts a ticker if it is not already
  running.
- **The ticker** is a looping animation group with a 0.1 s duration: the game's engine wakes it 10 times a second, with no
  per-frame Lua script. Each wake does the full pass only if the flag is set. It also stops itself after about one second of
  wakes with nothing to do. When nothing changes, nothing runs.
- **So the pace is at most 10 full passes a second**, however many aura events arrive. A burst of 100 UNIT_AURA events in one
  second costs at most 10 passes.
- The reminders coalesce their refresh to **at most one every 0.5 s**, in and out of combat (checked in her Drive copy). Group
  aura events are gathered into one delayed refresh.
- Building containers runs on a shared worker with **one per-frame time budget** (8 ms), first come, first served. Combat lowers
  the budget, never drops the work. A job the game stops for running too long is resumed on the next frame.

### 2.5 Whether it lets Blizzard do the work

Yes, wherever it can:

- Aura displays are Blizzard aura containers. Blizzard's code finds the aura, draws it, and reads the secret values. EllesmereUI
  only configures the containers.
- "Is this buff up" comes from the icons Blizzard's own Cooldown Manager keeps current. Blizzard's code runs the aura scan, and
  EllesmereUI reads plain flags on those icons.
- A consequence (INFERENCE): a Bar Glow can only follow a buff that the player has put in Blizzard's Cooldown Manager. An aura
  that no Blizzard frame tracks gets an aura-container slot of its own. That slot can show the aura, but EllesmereUI's code
  cannot ask whether it is up.
- Its code comments say that the game charges a frame's script and engine work to the addon whose code created the frame, so
  aura containers XayaUI creates may count in XayaUI's own CPU reading. This conflicts with the note at the top of our
  `XayaUI_Rules/Combat/AuraDisplay.lua`, which says the containers' work is counted under Blizzard_AuraContainer. **UNVERIFIED IN
  GAME.** It matters for V33, because her AddOn Usage reading may already include the containers' work.

### 2.6 How it copes with Midnight's secret values

- It never compares, tests or does arithmetic on a secret value. A secret is either handed straight to a widget that accepts it,
  or treated as "unknown, assume it changed".
- In combat, the buff reminders ask the aura API only about spells the game reports as not secret. They check this with the game's
  own per-spell secrecy call, plus a fixed list of their own. Every other buff falls back to a snapshot of the player's auras taken
  at encounter start or combat start, just before the game hides them.
- An icon's spell ID can be hidden while its aura is up. It keeps the IDs it resolved while they were readable, and reads
  "active" from flags Blizzard leaves readable.

### 2.7 Secrecy flags of every game API it relies on (our 12.1.5 reference, `docs/reference/api/`)

| API it relies on | Flags in our reference | What that means for a design |
|---|---|---|
| `UNIT_AURA` (unitTarget, updateInfo: UnitAuraUpdateInfo), events.md:1581 | SecretWhenAurasRestricted, SynchronousEvent | When auras are restricted (combat, restricted content), the payload is secret: nothing in it can be used to route |
| `UnitAuraUpdateInfo`, structures.md:7700 | isFullUpdate (bool), removedAuraInstanceIDs, addedAuras, updatedAuraInstanceIDs (all nilable) | Usable only while not restricted |
| `C_UnitAuras.GetPlayerAuraBySpellID`, namespaces.md:5334 | RequiresNonSecretAura, SecretWhenUnitAuraRestricted | Answers in combat only for spells the game keeps not secret |
| `C_UnitAuras.GetUnitAuraBySpellID`, namespaces.md:5337 | RequiresNonSecretAura, SecretWhenUnitAuraRestricted | Same, for another unit |
| `C_UnitAuras.GetAuraDataByIndex`, namespaces.md:5323 | RequiresUnitAuraAccess, SecretWhenUnitAuraRestricted | A scan by index: refused while restricted (EllesmereUI says it errors in Mythic+ and raids even out of combat; INFERENCE) |
| `C_Secrets.ShouldSpellAuraBeSecret`, namespaces.md:4223 | SecretArguments=AllowedWhenUntainted | EllesmereUI uses its "false" answer as "readable now". Our Conditions.lua deliberately only reports it (gap 20): what "false" promises is not documented |
| `C_Secrets.ShouldAurasBeSecret`, namespaces.md:4221 | (none) | Plain "are auras restricted now" |
| `C_Secrets.GetSpellAuraSecrecy`, namespaces.md:4216 | SecretArguments=AllowedWhenUntainted | NeverSecret = readable in combat (what our AuraTrackable uses) |
| `PLAYER_TOTEM_UPDATE`, `PLAYER_TARGET_CHANGED`, events.md:1225 / 1223 | SynchronousEvent | Plain events |
| `COOLDOWN_VIEWER_DATA_LOADED`, `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`, events.md:470-471 | SynchronousEvent | Plain events |
| AnimationGroup `SetLooping`, widgets.md:59 | SecretArguments=NotAllowed | Plain |
| Aura container widget (`AddAuraGroup`, `AddAuraSlot`, `SetAuraGroupEnabled`, `SetAuraGroupMaxFrameCount`, `SetUnit`, `UpdateAllAuras`) and the Cooldown Manager icon fields and methods (an icon's "set from aura" flag, its aura instance ID, its active-state change, the pool's acquire) | **not in our generated reference** | Blizzard UI source only. Our AuraDisplay.lua and Timing.lua already use some of these from Blizzard's published UI source. Anything new must be checked there first (V2), never taken from EllesmereUI |

---

## 3. What XayaUI Rules does today, and why it costs

From `XayaUI_Rules/Engine.lua`, `Conditions.lua`, `Triggers.lua`, `Timing.lua` and `AuraAlias.lua` at HEAD 89ea79a plus the
working tree.

- One UNIT_AURA on you marks "aura". On the next frame, at most once per 1/30 s in a burst, **every live rule that reads your
  auras is checked again in full** (`ns.Evaluate`: conditions, triggers, display). In the gate profile, 179 of 300 rules read
  auras. Round 5 measured about 416 bytes of garbage per rule step.
- One UNIT_AURA on the target or focus marks "tgt", and **every live target-debuff rule is checked again in full**, at the same
  pace. In a raid, the boss's UNIT_AURA fires for every raid member's aura on it. Each "Target Debuff (yours)" row then asks the
  game for the whole list of your debuffs on that unit (a new table each time) and walks it. With 16 such rules, that is 16
  copies of the same list per pass.
- A Cooldown Manager icon alert (aura applied or removed, cooldown started or ready; `Timing.lua`) marks "everything", and
  **every live rule** is checked again.
- The Cooldown Manager icon index (`Conditions.lua` BuildCDMIndex) is rebuilt at most every 0.25 s while something asks. Each
  rebuild makes new tables for every viewer's children and every icon's IDs.
- Out of combat the payload is readable, but the engine does not look at it. Only AuraAlias.lua reads the added auras, to learn
  same-name buffs.

The result (round 5 review): in the busiest case, 92% of engine runs changed nothing on screen. The fight allocates about
2.5 MB/s, and almost all of it comes from these full re-checks.

---

## 4. Our own design for XayaUI Rules: "check the aura once, re-check only the rules it changed"

The idea, in one line: **read each watched aura once per burst, compare it with what we read last time, and check again only the
rules whose aura answer changed.** The answers come from exactly the same reads a rule makes today (aura API when readable, then the
Cooldown Manager icon, then the existing fallbacks), so no answer changes. Only the number of full rule checks drops.

This differs from EllesmereUI in substance. EllesmereUI keeps one "active" table built only from Cooldown Manager icons, on a
10-per-second ticker. Our rules also answer from the aura API when it is readable, from NeverSecret spells, from learned aliases,
for target and focus debuffs, and from stacks and seconds left, and they must keep doing so (V32). So our unit of work is "one
watched aura ID", read by our own reader, and our pace stays event-driven with no ticker.

### 4.1 The watch list (built once per change, never per event)

When the live lists are rebuilt (settings change or a load fact change: the existing `LiveChanged` point in Engine.lua), build per
unit (player, target, focus):

- `watch[unit]`: the distinct aura IDs the live rules read. That is each rule's main aura ID and its extra IDs, each aura row's ID
  and its Cooldown Manager ID, the aliases AuraAlias.lua has learned for those IDs, and the rule's own spell when the "Tracked
  Buffs" fallback can apply.
- `readers[unit][id]`: the live rules that read that ID.
- `always[unit]`: the live aura rules whose answer cannot be pinned to an ID: a matched-by-name fallback, a row type the engine
  does not know, anything new. These are checked again on every aura burst for that unit, as every aura rule is today. This list
  keeps the design from ever missing an aura (fails safe).

Cost: one pass over the live rules per real change, as today. Nothing per event.

### 4.2 The signals, and what each one marks

| Signal | Marks |
|---|---|
| UNIT_AURA, payload readable (not restricted) | Added auras: their spell IDs, if watched. Removed or updated instance IDs: looked up in a small instance-ID-to-spell memory (4.4); watched ones are marked. Full update, or an instance ID the memory cannot vouch for: the whole unit |
| UNIT_AURA, payload secret (restricted, combat) | The whole unit is due for a snapshot pass (4.3). Nothing in the payload is ever tested |
| A Cooldown Manager icon alert or aura update (the hooks Timing.lua already has, from Blizzard's own source) | Only the IDs that icon stands for. Today these mark every live rule |
| Target or focus changed | That unit, in full (as today) |
| Load fact, talents, settings | Everything, once (as today) |

### 4.3 The snapshot pass (the only work an aura burst causes)

On the next frame after a signal (the existing `Kick` and `Drive`, the same first-frame latency as today), for each unit that is
due:

1. For each marked ID (or every ID in `watch[unit]` when the whole unit is due), read its answer **once**. The answer is present,
   absent or unknown, plus a small "version": readable stacks and expiration when the game shows them, or the Cooldown Manager
   icon's applied and updated moments that Timing.lua already notes. For target and focus, your debuffs on that unit are listed
   **once** per pass and shared by every reader, instead of once per row.
2. Compare each answer with the stored one. Only when it differs, put that ID's readers on the run list. Store the new answer in a
   table that is reused, so no new table is made per pass.
3. Check the run list in full (as today), plus `always[unit]`.

Cost per pass: one cheap read per watched ID of that unit, then a full check only of the rules whose aura changed. Today the cost is
a full check of every aura rule. Rough sizing, an INFERENCE to be measured by the gate: the gate profile reads perhaps 60 to 100
distinct aura IDs for 179 aura rules. In a typical burst, 0 to 3 rules change. The aura part of a pass should therefore cost a
small fraction of today's, and allocate nothing.

### 4.4 The instance-ID memory (out of combat only)

A table from aura instance ID to spell ID, holding **watched IDs only**. It is filled from added auras and from readable reads,
cleared on full update, world entry, unit change and restriction start, and capped in size. A removed or updated instance ID that
is not in it is ignored only while the memory is marked complete (built from a readable full read since the last clear). Otherwise
the whole unit is snapshotted. In combat the payload is secret, so this memory is not used. Its only job is to let readable bursts
out of combat skip unrelated auras entirely.

### 4.5 Two fixes the snapshot pass needs

- **The Cooldown Manager icon index becomes event-driven.** It is rebuilt only when an icon is given another spell, the pool hands
  out an icon, or a viewer is shown or hidden. All three are Blizzard UI methods that must be confirmed in Blizzard's own source
  (V2). Rebuilds reuse their tables. Today the index is rebuilt every 0.25 s and makes new tables each time.
- **Icon alerts are routed** to the readers of that icon's IDs, instead of marking every live rule.

### 4.6 One behavior gap the study found (V32 risk, UNVERIFIED IN GAME)

EllesmereUI counts a **shown, non-placeholder icon in a Tracked Buffs viewer** as active even when Blizzard gave it no aura
instance (totems, summoned pets shown as buffs). Our `FrameActive` (Conditions.lua) counts only the "set from aura" flag or an
aura instance ID. So a rule watching a totem or pet "buff" through the Cooldown Manager may read "absent" while the icon is lit. This
is an INFERENCE from the two readings, not seen in game. Proposed: check it in game first. If confirmed, our reader counts a shown
icon in the two buff viewers as active, guarded the same way as today, with its own test.

---

## 5. What the player keeps (V32: no missed aura), and how each is proved

Each line becomes a check in a new test, `tests/fix_r6_aura_routing_run.py`. It must fail on the pre-change files and pass after
(V31), with the player-visible outcome asserted: the display shown or hidden, the sound played.

1. A proc on you in combat, secret payload, Cooldown Manager icon lights: the display shows and the sound plays on the next frame,
   as today.
2. The same proc falls off: the display hides on the next frame.
3. A NeverSecret aura in combat with no Cooldown Manager icon: still answered by the aura API (the snapshot reads it).
4. Out of combat, readable payload: an unrelated aura on you checks **zero** aura rules again. A watched aura added, removed or
   refreshed checks only its readers.
5. Full update, world entry, target or focus change: every aura rule of that unit is checked again once.
6. A rule that matches by name, or has an unknown row type: checked again on every burst (the `always` list), never skipped.
7. A learned alias (AuraAlias.lua) appearing: its reader is checked again.
8. Stacks or seconds left changing while readable: the version changes, so the reader is checked again. Threshold moments keep
   their Timing.lua deadlines.
9. Raid storm on the boss: 300 target UNIT_AURA events a second cause at most 30 passes. Each pass lists your debuffs once and
   checks no rule fully unless one of your watched debuffs changed.
10. Load conditions (mounted, combat, group, talents) are untouched. They stay on the load-fact path.
11. `/xui disable`: no snapshot, no event registration (as today).

Gates to run: `gate_performance_run.py` (P1 runs with no change, P3 loops over all rules, P4 allocation), `gate_mouse_run.py` and
`gate_keyboard_run.py` (unchanged paths, run anyway), the harness and the full suite.

---

## 6. Implications in plain English

- **Nothing you see should change**, except that it costs less. The same reads give the same answers. A rule just isn't re-checked
  when its aura did not change.
- **In combat, the work drops the most.** Every aura change today re-checks every aura rule. After the change, an aura change costs
  one quick look at each aura your rules watch, and a full re-check only of the rules whose aura actually changed.
- **Raids get the biggest drop**, because the boss's aura list changes constantly for other players' debuffs. Your rules would look
  at your own debuffs once per burst instead of once per rule.
- **Out of combat, unrelated auras cost nothing.** A party member's buff landing on you, or a food buff ticking, re-checks no rule
  unless a rule watches that aura.
- **The worst case is no worse than today.** When the game hides everything and every watched aura changes at once, the pass checks
  the same rules today's engine checks, plus one quick read per watched aura.
- **Small memory cost:** a few kilobytes for the watch lists and last answers, built once and reused.
- **Still open:** the gate's "runs with no visible change" count in combat. A snapshot pass that finds nothing changed is cheap,
  but it is still a run. Whether the gate accepts that, or the pace in a burst should be lower, is her decision (7.1).
- **UNVERIFIED IN GAME:** that Blizzard's Cooldown Manager icon is up to date on the frame after UNIT_AURA (today's design assumes
  the same); the totem and pet gap in 4.6; the CPU billing question in 2.5.

---

## 7. Her decisions (to be asked through the question flow, V19)

1. **Pace in a burst.** The first aura change after a quiet spell is always handled on the next frame. During a burst, (a) keep up
   to 30 passes a second for your own auras and for target and focus, as today, which is cheaper per pass but the same count;
   (b) 30 for your own auras and 10 for target and focus, so a target-debuff display can lag up to 0.1 s in a raid, the pace
   EllesmereUI uses for its glows; or (c) 10 for both. Recommended: (b).
2. **Files.** SD-54 names Engine.lua, Conditions.lua and AuraAlias.lua. The design also needs `Triggers.lua` (the target-debuff row
   reads the shared list instead of its own) and `Timing.lua` (alerts routed by icon ID). Both need her OK for the build round.
3. **The totem and pet icon gap (4.6):** check it in game first (recommended), or build the fix with the rest and mark it UNVERIFIED.
4. **V33 reading:** whether to measure, in one in-game fight, whether the aura containers XayaUI creates count in XayaUI Rules'
   AddOn Usage number (2.5). It decides what the 2% budget includes.

---

## 8. Independence note (house rule #290, her words: "Reference addons ... exist only to sanity-check our own work. Never copy
code, data, assets or text from them, not even adapted. Every idea or concept we implement is our own design and our own code.
When comparing, record only what behaviour was checked and that our implementation is independent.")

- **Behavior checked:** which aura events EllesmereUI listens to and when it registers them; what it reads from the UNIT_AURA
  payload; what it keeps between events; how it paces work (a dirty flag, a 10-per-second self-stopping ticker, a change counter,
  a 0.5 s reminder refresh, a per-frame build budget); that it lets Blizzard's aura containers and Cooldown Manager icons do the
  aura work; and how it treats secret values. Files listed in section 1.
- **Nothing was copied:** no code, data, spell lists, assets or text. No EllesmereUI identifier is proposed for our code. The
  Blizzard methods named here are Blizzard's own. Any new one must be checked in Blizzard's published UI source before use (V2).
- **Our design is our own:** a per-unit watch list of aura IDs built from our own rules, a read-once-and-compare pass using our
  existing reader, routing of our existing Timing.lua hooks, and an out-of-combat instance-ID memory. EllesmereUI uses none of these.
  It answers its glows from one Cooldown Manager table on a ticker.
- **Handling:** the EllesmereUI files are kept only in the session scratchpad (`eui-study/src/`), apart from our scripts
  (`eui-study/tools/`), read as text, never run. Nothing of them is in this repository.
