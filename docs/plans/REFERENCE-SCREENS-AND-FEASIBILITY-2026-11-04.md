# Reference screens (Xaya, 2026-11-04) and what the 12.1.5 API allows

Xaya: "all of these screenshots are important reference points". The screenshots are of another addon's options window (WeakAuras).
Per her rule on reference addons, only the **properties they show** are recorded here, as her spec, in our own words. No code, text
or assets were copied, and XayaUI's implementation is its own design.

**The images are not in the repository.** They existed only in the chat, and a cloud session cannot save chat images. To keep them,
add them under `docs/issue-screenshots/` or in the Drive process folder.

## The screens (properties, in our words)
1. **Group (container) tab.** Xaya's instruction: put these on XayaUI's group **Group** tab; her earlier "Group Display" rename is
   reverted.
   - horizontal / vertical alignment of children;
   - distribute horizontally / vertically (-100..100);
   - space horizontally / vertically (-100..100);
   - border settings: border style, backdrop style, border offset (0-32), border size (1-64), border inset (1-32), border color,
     backdrop color, border on / off;
   - anchor point to a screen point, X / Y offset;
   - frame strata.
2. **Dynamic group settings.** Xaya's instruction: evaluate what the API allows.
   - group icon (with file picker);
   - grow direction (incl. centered vertical);
   - group by frame (unit frames);
   - align (center);
   - item order (bottom to top);
   - space;
   - stagger;
   - sort (none);
   - limit (number shown);
   - animated expand / collapse;
   - group scale;
   - group alpha;
   - flat frame levels;
   - border settings.
3. **Progress bar display.**
   - fill direction (e.g. right to left) and inverse;
   - minimum / maximum progress;
   - smooth progress;
   - bar color with optional gradient (orientation, start, end);
   - background color;
   - bar alpha;
   - show icon;
   - show spark;
   - width, height, X / Y offset, frame strata;
   - sub-elements.
   - Xaya: progress bars must be a display kind in rules and both engines, groups must support every texture type, and dynamic
     groups must hold several bars (priority after the current fixes).
4. **Icon display.**
   - color tint, desaturate;
   - icon source (live from the trigger) with a fallback icon;
   - tooltip on mouseover;
   - zoom;
   - cooldown swipe overlay: enable, inverse, show swipe, show edge, hide the game's timer numbers, use the game's cooldown-rate;
   - width, height;
   - "anchored to" (screen / parent group);
   - a 9-point anchor picker and a 9-point "to group's" point picker;
   - X / Y offset;
   - frame strata;
   - sub-elements: background, text elements with color and a display-text pattern.
5. **Spell trigger (cooldown / charges / count).**
   - trigger combination "required for activation";
   - exact spell match;
   - track cooldowns (auto);
   - show global cooldown;
   - show loss of control;
   - ignore rune cooldown;
   - disable spell-known check;
   - follow the cooldown of charge N;
   - remaining time, charges and spell count, each with an operator and a value;
   - show: always / on cooldown / ready.
   - Xaya: whatever the API supports should be in XayaUI's trigger pane.
6. **Conditions that run custom code** (e.g. trigger 2's remaining time <= 3 sets a per-rule variable on, > 3 sets it off), with
   "else if" and property changes. Xaya: ideally supported at some point (future).
7. **Load conditions.**
   - zone ID(s);
   - encounter ID(s);
   - instance size type;
   - instance difficulty;
   - instance type;
   - raid role (main tank / main assist / other);
   - item equipped.
   - Xaya: add the ones the API supports.
8. **Dynamic group with position settings.**
   - X / Y offset;
   - anchor (top);
   - anchored to (screen / parent group);
   - "to group's" point;
   - frame strata.
   - Xaya's arrow points at the "to group's" point. Read as her answer to #268's wording question (this point -> anchored to ->
     the target's point); to be confirmed.

## What the API allows (research by a read-only agent, 2026-11-04; claims carry the files and flags it cited, not each re-checked)
- **X** = drawn by XayaUI's own frames: any layout. In combat XayaUI is refused aura reads (`Combat/AuraDisplay.lua:4`), so which
  items show and their time left come from estimates.
- **E** = drawn by the combat engine (Blizzard's CustomAuraContainer): exact in combat, but only flow layout (element size, spacing,
  maxFrameCount, sort method / direction; `AuraDisplay.lua:524-556`). It never rebuilds in combat.

**Exists (fully or partly) today:**
- grow (8 directions);
- space;
- sort (Manual, Default, Expiration, Name, Important, Reverse);
- group scale / alpha;
- container anchor + X / Y;
- strata (group);
- align / distribute buttons (static groups, one-shot);
- fill direction / min-max (progress textures);
- background color;
- tint / desaturate / zoom;
- display tooltip;
- size;
- one 9-point anchor (inside / outside).

**Missing, and possible with no secret values:**
- group icon picker;
- row align;
- stagger;
- limit (E's maxFrameCount; X yes);
- animated expand / collapse (X only);
- flat frame levels (partly via Z-index);
- group border / backdrop and group background (BackdropTemplate or textures; fixed box);
- a saved distribute gap;
- per-display strata (#125);
- a separate "to" anchor point (#268: `SetPoint` takes both points);
- gradient (`Texture:SetGradient`);
- spark (follows the bar's fill edge, no numbers);
- cooldown swipe options (`SetDrawSwipe`, `SetDrawEdge`, `SetReverse`, `SetHideCountdownNumbers`; E feasible at build);
- fallback icon picker;
- text tokens.

**Limited by Midnight's secrecy:**
- sort by time left (X: estimates only);
- custom sort (would see secret values);
- group by frame (unit identity is secret; friendly-unit spell matching unproven);
- a live icon from the trigger on X (needs AuraData, SecretWhenUnitAuraRestricted);
- the cooldown-rate option (not confirmed).

**Progress bars in combat:**
- E single slots: yes; Blizzard drives the bar (`StatusBar:SetTimerDuration`, AuraDisplay.lua:453).
- X bars: `C_UnitAuras.GetAuraDuration` + `SetTimerDuration` read no number in Lua, but need an aura instance ID
  (RequiresUnitAuraAccess). INFERENCE, unverified in game.
- Bars inside E dynamic groups are not drawn today (AuraDisplay.lua:247). That is the gap behind Xaya's "dynamic groups will need to
  be able to support multiple progress bars".

**Open design questions** (Xaya's call):
1. When a group uses something E cannot draw, should XayaUI draw it (losing exact combat times) or disable the option?
2. Border / background: a fixed box, or fitted to the items showing?
3. Limit only with the game's sorts?
4. Group by frame: which frames?
5. Bars: a real StatusBar kind (spark, gradient, ticks), or extend progress textures?
6. Strata on the Display tab (#349 / #125)?
7. #268 wording (see screen 8).
8. Swipe on by default for E?
9. Which text tokens?
10. A custom sort?
11. Save the space gap?

## Spell cooldown trigger options (screen 5) and load conditions (screen 7): research, 2026-11-04 (read-only agent; flags as it quoted them from `docs/reference/api`, not each re-checked; nothing tested in game)

**Trigger options already in XayaUI:**
- required for activation: ALL / ANY / only one (`XayaUI_Options/TriggersEditor.lua:304-327`; AND / OR / NOT rows on the Conditions
  tab);
- pick by name, ID or spellbook;
- show when: fully ready / has a charge / not ready / empty / ignore cooldown (`Options.lua:110-117`).

**Feasible and missing, in order of value:**
1. **Count the global cooldown.** `SpellCooldownInfo.isOnGCD` is NeverSecret.
2. **Remaining time and charge comparisons on the trigger itself.** Today they are only on the Conditions tab. The time in combat is
   an estimate from the Cooldown Manager; charges are counted from your casts.
3. **A loss-of-control lockout counts as on cooldown.** `C_Spell.GetSpellLossOfControlCooldownInfo`; `isActive` is NeverSecret
   (INFERENCE that it is readable in combat).
4. **An exact spell ID toggle,** so a talent replacement is not followed (`C_Spell.GetOverrideSpell`).
5. **Track: Auto / Charges / Spell cooldown.**
6. **Track even if not known,** with a warning: the game reports an unknown spell as not active, so it would read "ready".
7. **Spell count** (`C_Spell.GetSpellCastCount` / `GetSpellDisplayCount`): comparisons out of combat only; it can still be shown.

**Not feasible in combat:**
- **Ignore rune cooldown:** needs the spell's start time and duration, which are hidden when cooldowns are restricted.
- **Cooldown of charge N:** the charge count and recharge times are hidden, and the game's duration object covers only the current
  recharge.
- **Spell count comparisons:** both calls are SecretWhenCooldownsRestricted.

**Open questions:**
- Does a Death Knight rune spell's `GetSpellCooldown` include the rune recharge?
- Is the loss-of-control `isActive` readable in combat?
- Is `isOnGCD` reliable at evaluation time?
- Is `C_Secrets.ShouldCooldownsBeSecret` true in all combat or only in some content?

**Load conditions:**
| Condition | Today | Route | Proposal |
|---|---|---|---|
| Zone ID(s) | missing | `C_Map.GetBestMapForUnit("player")`, `GetInstanceInfo()` instanceID (no secret flags) | "Map / instance IDs" list with a "current ID" helper |
| Encounter ID(s) | partly ("in a boss encounter") | ENCOUNTER_START / END encounterID (no secret flags); no getter for the current ID, so a /reload mid-pull loses it | "Encounter IDs" list; register ENCOUNTER_START / END in core |
| Instance size | missing | `GetInstanceInfo()` maxPlayers; `GetDifficultyInfo` | size tick boxes |
| Difficulty | missing (Mythic+ yes / no only) | `GetInstanceInfo()` difficultyID; `GetDifficultyInfo` | difficulty tick boxes named by the game |
| Instance type | exists | `IsInInstance()` | none |
| Raid role (MT / MA) | missing (the spec role exists) | `GetPartyAssignment` is undocumented in the reference | an in-game Dev Assist probe first, then Main Tank / Main Assist |
| Item equipped | partly (a trigger exists) | `C_Item.IsEquippedItem` | an "Item equipped (IDs)" load row reusing the trigger's read |

**How load is re-checked:**
- Load is re-read every 0.2 s engine step, so polling catches changes, but a new value must be added to the load memo string
  (`Conditions.lua:1409-1435`).
- Encounter IDs arrive only with the event.
- A value the game will not give fails the check (the rule does not load).
- Group-level load would need the same rows.
