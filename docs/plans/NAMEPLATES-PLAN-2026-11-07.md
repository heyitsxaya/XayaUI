# Nameplates: can XayaUI replace Xaya's Plater setup, and cost less? (2026-11-07)

Her request (2026-11-07 07:04 UTC, her words): "if you can replicate the following mods and profile functionality into xui and make it
cost less, here are the nameplate mods and settings I rely on". What her setup contains: `NAMEPLATES-PLATER-INVENTORY-2026-11-07.md`.
REQUEST-LOG: A15 (NP-1).

**Short answer.** Part of it, yes, and cheaper; all of it, no.
- **Cheaper:** yes, if XayaUI builds on **Blizzard's own nameplates** and adds only what Blizzard does not do. Then the addon's work
  happens only when something changes (the target changes, a plate appears). No per-frame or per-tick work, and no secret values read.
- **Not all of it:** about half of her 34 active scripts key on enemy spell IDs or NPC IDs. In Mythic+ combat the game hides those
  from addons. So those scripts cannot work there for Plater either (INFERENCE, see B2). The look (her textures, fonts, exact pixel
  sizes) cannot be put on Blizzard's plates without rebuilding the plates, and rebuilding them is Plater's own design, with Plater's
  costs.
- **Cost figures below are estimates until measured.** The performance-test session owns measuring (CLEAN-8 note sent).

## Flagged readings (her standing order: no questions until her older items are on main)
Each one is the most conservative reading, written down and built that way. She can overturn any of them.
| # | Open point | Reading taken |
|---|---|---|
| R1 | Build on Blizzard's plates, or draw our own (as Plater does)? | **Blizzard's plates.** Cheapest, least taint risk, and fully reversible: switching the addon off gives Blizzard's plates back. Drawing our own is phase 3, only if she wants Plater's look. |
| R2 | Where the switch lives | A new addon, **XayaUI_Nameplates**, that is **disabled by default** in the game's AddOns list (`## DefaultState: disabled`). Off = never loaded (V14, strict level). Inside it, each behaviour has its own tick box. |
| R3 | Target colour | "teal" as she set it, read as the CSS named colour teal, rgb(0, 128, 128) (W3C CSS Color Module Level 4, named colours). Plater's own "teal" value was not looked up (#290). A colour picker beside it, as the mod's own setting allowed. On by default once the addon is enabled (enabling the addon is the opt-in). |
| R4 | Settings page place | XayaUI settings, QoL tab, "Nameplates". |
| R5 | Plater still installed | XayaUI_Nameplates draws on Blizzard's health bar only. With Plater on, Blizzard's bars are hidden, so ours shows nothing. `/xui nameplates` says so. Nothing is done to Plater. |
| R6 | "Attacking Specific Unit" | It is **off** in the export she sent, but her chat showed it erroring. Not built (she did not list it), and B2 says it cannot work in Mythic+ anyway. |

## B. Feasibility, item by item (Midnight 12.1.5)
Sources: `docs/reference/api/` (captured from the 12.1.5 client) and Blizzard's own nameplate code (Gethe/wow-ui-source at commit
297d7aa "12.1.5 (70783)", the same commit as the reskin review; read only, nothing copied).

### B1. What the game lets an addon do with nameplates
- Find a plate: `C_NamePlate.GetNamePlateForUnit(unitToken, includeForbidden = false)` → the plate frame (SecretArguments=AllowedWhenUntainted);
  `C_NamePlate.GetNamePlates()`. Events: `NAME_PLATE_UNIT_ADDED`, `NAME_PLATE_UNIT_REMOVED`, `NAME_PLATE_CREATED`, `PLAYER_TARGET_CHANGED`.
- **Forbidden plates:** Blizzard keeps a second pool of forbidden plates (`Blizzard_NamePlates.lua:31-32`, `FORBIDDEN_NAME_PLATE_*`
  events). Addons cannot touch them. Which plates are forbidden (friendly plates in instances, by common knowledge) is INFERENCE.
- **Plate size:** `C_NamePlate.SetNamePlateSize` carries `HasRestrictions` (not callable at all times; INFERENCE: not in combat).
- **"Is this plate my target?"** `UnitIsUnit(unit1, unit2)` is `SecretWhenUnitComparisonRestricted`: in restricted content the answer
  can be secret to an addon. Blizzard's own plates call it, but Blizzard's code is untainted. **Our way round it:** ask the game for
  the target's plate directly, `C_NamePlate.GetNamePlateForUnit("target")`. It compares nothing and reads no secret. INFERENCE: it
  returns the plate in Mythic+ combat too. The walkthrough checks it in game.
- Unit identity: `UnitCreatureID` and `UnitGUID` are `SecretWhenUnitIdentityRestricted`; `UnitName` is `SecretWhenUnitNameIdentityRestricted`.
- Casts: `UnitCastingInfo` / `UnitChannelInfo` / `UnitCastingDuration` take `UnitTokenPvPRestrictedForAddOns`; enemy cast spell IDs are
  secret when spell casts are restricted (RM-INST research, ROADMAP).
- Auras: `C_UnitAuras.GetUnitAuras(unit, filter, maxCount, sortRule, sortDirection)` (RequiresUnitAuraAccess; `UNIT_AURA` is
  `SecretWhenAurasRestricted`). The game sorts by itself: `Enum.UnitAuraSortRule` Unsorted, Default, BigDefensive, Expiration,
  ExpirationOnly, Name, NameOnly; direction Normal or Reverse.
- Health: `UnitHealth` is `SecretReturns`. A health bar an addon draws must hand the secret straight to a bar, never format or compare it.
  That Plater still shows health in 12.1.5 means the game allows it for addon bars (INFERENCE from her own use, tocversion 120105 in her export).
- Colours: `StatusBar:SetStatusBarColor` and `Texture:SetVertexColor` accept secret values even from addon code (SecretArguments=AllowedWhenTainted).

### B2. What Blizzard's own plates already do (12.1.5)
From `Enum.NamePlate*` and `Blizzard_NamePlates`:
- Styles (Modern, Thin, Block, HealthFocus, CastFocus, Legacy, Classic) and sizes (Small, Medium, Large, ExtraLarge, Huge).
- Cast bar: spell name, icon, the cast's target, **highlight important casts**, highlight when you are the cast's target; an
  uninterruptible shield.
- Threat: progressive, flash, or health-bar colour.
- Health text: percent and/or value.
- Auras: enemy NPC buffs, debuffs, crowd control, sorted by Blizzard's own rule.
- Target and focus: a border in the target colour and in the focus colour; every other plate slightly darkened.
- Class colours, raid markers, classification (elite / rare) icons, simplified plates for minions and minor mobs.

### B3. Per item: match, differ, impossible
| Item (inventory) | Verdict | Why / how |
|---|---|---|
| **Current Target Color** | **Match** | Our own tinted layer over the fill of the target's Blizzard health bar, shown on target change and plate added. No secret read. Slice 1. |
| **Reorder Nameplate** | **Match by default** | Her copy lays the plate out the way Plater's own layout does: health bar centred, cast bar under it, auras above. Blizzard's plates use the same order. Exact pixel sizes (145 x 18 in combat) differ: Blizzard offers 5 size steps, not pixels. Nothing to build; the walkthrough shows it. |
| **Aura Reorder** | **Differ** | Her list only moves five priest / rogue spells (the mod's example). Sorting by spell name needs the aura's name, which the game hides for enemy auras in restricted combat (RM-INST; INFERENCE until probed). The game's own sort rules (B1) do work with hidden auras. Proposal for slice 2: a "sort by" choice using the game's rules (Expiration, Name, BigDefensive), plus "your own auras first". |
| Threat colours (DPS), quest colour, tapped grey, class colours | Differ | Blizzard's threat display "health-bar colour" covers aggro / no aggro; her exact colours need our own tint layer (slice 2, same technique as the target colour). Threat state is `SecretWhenUnitThreatStateRestricted` for addons: a tint by threat cannot be chosen by our code in restricted combat, Blizzard's own can. |
| Unit-type colours (boss, mini-boss, caster) | Partly | Classification (`UnitClassification`) is readable; "caster" is Plater's own judgement. |
| NPC colour list (6 NPCs), important adds, explode-on-death, countdown, Spiteful, fixate on you (unit scripts by NPC ID) | **Impossible in Mythic+ combat** | Needs the NPC ID, which is `SecretWhenUnitIdentityRestricted`. Possible out of combat (colour fixed when the plate first appears before the pull; INFERENCE, needs the probe). |
| Cast scripts by spell ID (21 on), cast colours (15), cast sounds (15) | **Impossible in Mythic+ combat** for addons | Enemy cast spell IDs are secret when restricted. Blizzard's "highlight important casts" is the game's own replacement and is free. |
| Aura scripts by spell (7 on) | Impossible in restricted combat | Same: enemy aura identity hidden. |
| Range alpha (65 % / 90 %) | Differ | Blizzard's own range fade (game options) instead; Plater's per-tick range check is one of its costs. |
| Textures, fonts, borders | Differ | Possible on Blizzard's bars as art changes (texture, font, colour calls), with the reskin caution for protected frames (BLIZZARD-RESKIN-CANDIDATES, tier C). Slice 3. |
| Boss-mod icons | Not planned | Belongs to the boss-mod addon. |
| Saved game options (plates shown, overlap, alpha, scale) | Match | They are the game's own settings; they stay as they are without Plater. |

## Where the cost goes, and how ours avoids it
**Estimates, not measurements.** Plater's work, from her settings (inventory section 4):
1. **A tick per plate every 0.25 s** (her update interval). On each tick, every "Nameplate Updated" mod runs. Current Target Color is
   one of them, so it repaints every plate four times a second although the target changes rarely. With 15 plates in a pull that is
   about 60 repaints a second. Arithmetic: 15 plates x 4 ticks per second = 60.
2. **Health animation** runs every frame on plates whose health is moving.
3. **Range check** each tick.
4. **34 scripts** checked on every cast and aura event.
5. **Errors:** a mod that errors on every update (her "Attacking Specific Unit" report) pays for the error handler each time. That
   alone can cost more than the mod's work. INFERENCE: one candidate for the Mythic+-only mouse lag, because Mythic+ is where the
   secret values appear.

Ours (slice 1): one handler on `PLAYER_TARGET_CHANGED` and one on plate added / removed. Each asks for the target's plate once and shows
or hides one texture. In a pull that is a handful of calls per target change, not 60 a second. No OnUpdate, no timer except one
next-frame call per plate added, no string work, no secret read.

**What cannot be claimed:** Blizzard's plates have their own cost. It shows under Blizzard, not under any addon, in the AddOn CPU
tooltip. So "Plater 2 % vs XayaUI 0 %" would not be a fair comparison. The fair one is frame time in the same pull, with Plater
vs with Blizzard's plates plus XayaUI_Nameplates. I asked the performance-test session for that method.

## C. What she gets, slice by slice
| Slice | Content | State |
|---|---|---|
| 1 | XayaUI_Nameplates 0.1.0: the addon itself (disabled by default), **Target colour** (on, teal, colour picker), `/xui nameplates` status (Plater loaded? target plate found?), V14 test, QA walkthrough | built on branch `claude/nameplates-plater` |
| 2 | Aura order by the game's own sort rules; threat / quest / tapped tint colours; health text and other Blizzard options exposed from our page | proposal; needs her answers once her older items are on main |
| 3 | Her look on Blizzard's bars (texture, font, border), size step | proposal; taint check in game first |
| - | Spell- and NPC-keyed scripts in Mythic+ combat | not possible for any addon (B3) |

**What she must do to use slice 1:** enable "XayaUI Nameplates" in the AddOns list and **disable Plater**. She loses everything Plater
draws that Blizzard does not (B3), so this is a trial, not a swap yet. Re-enabling Plater undoes it.

## Questions for her (to send once her older items are on main; V19 question flow)
1. R1: Blizzard's plates as the base (cheap), or our own plates for Plater's look (costlier, phase 3)?
2. Which of the impossible-in-Mythic+ items (B3) does she rely on out of combat or outside Mythic+? Those can be built for there.
3. Aura order: which of the game's sort rules?
4. Her exact sizes: is the nearest Blizzard size step acceptable?
