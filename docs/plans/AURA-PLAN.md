# Aura plan (holistic synthesis of the aura triage) — kept in the repo from 2026-11-04
Status updated 2026-11-04 04:33 UTC. The plan below was written 2026-11-04 from the triage of all issues (groups A, B, C), the Blizzard
API facts and Xaya's captures; the triage reports themselves stay with the session that made them (they quote issue text at length).

## Status
| Item | State |
|---|---|
| Phase 0.1 `/xui auras` (#335) | Built in core 0.6.6, on main (a91f73a). Not run in game yet (QA B18, B19). |
| Phase 0.2 readability per rule (editor, `/xui timing`) | Not started. |
| Phase 0.3 perf guard fixes | Done in core 0.6.13 (guard reads `Blizzard_AuraContainer`, a trip lasts one session); unverified in game (QA B38). |
| Phase 0.4 `/xuiengine` lists every display | Not started. |
| Phase 0.5 doc drift | Not started. |
| Phase 0.6 GameDump capture of the Cooldown Manager catalogue | Widened (Xaya 2026-11-04: "capture every aura possible in the current season and expansion"): `/xuidump auras` = Cooldown Manager catalogue per spec + Encounter Journal (current tier: raid and dungeon boss abilities, loot spells, tier-set bonus spells) + the M+ season's dungeons and affixes + a same-name scan of the whole spell ID range + an out-of-combat aura recorder. Not started. |
| Warcraft Logs | Xaya's exports (`wcl-export` on her Drive) hold each logged player's OWN buff and cast events. A second exporter (Buffs and Debuffs for every actor, friendly and enemy, summarised per report, no player names) is planned so the logs cover every aura seen in current raids and dungeons. |
| Phase 2.1 membership from the parent rule's group | Done in 0.6.6 (`ns.SyncCueFolders`). |
| D4 Manual order in combat, Sort options | Done in 0.6.6; member spacing fixed in 0.6.7 (it was 2 x Spacing in combat). |
| D5 where a dynamic group starts / how lines align | Answered by Xaya 2026-11-04 ("growth informed by anchor placement"): Centered row / column and From anchor point growth, engine-drawn, in 0.6.7. |
| Phase 3.2 AddAuraSound (D2: yes, mutable channel) | Not started; next after the aura capture. |
| Boiling Point (#315) / Divine Arbiter (#332) | Aura IDs received (section 4). Remaining: the in-combat route (AddAuraSound for sounds; Cooldown Manager for text and conditions), and a check of talent load conditions against tier-set auras. |
| Phases 1, 3.1, 3.3 to 3.6, 4, 5, 6 | Not started. |


Priority (Xaya): "this addon first and foremost is an aura tracking addon".
Inputs:
- the triage reports A.md, B.md and C.md, written against 2c7aee8, with re-baseline against main pending in REBASE-ABC.md;
- EUI-techniques.md, Blizzard API facts only;
- Xaya's captures of 2026-11-03/04, in docs/reference/ and the toolkit checks.

## 0. The fact that shapes everything (from the capture, all 13 classes)
- Of 4,899 spells, 4,818 have aura secrecy "ContextuallySecret" (Enum.SecrecyLevel 2): secret in combat, encounters, Mythic+ and PvP.
- Only 22 are NeverSecret: raid buffs (Battle Shout, Arcane Intellect, Mark of the Wild, Power Word: Fortitude, Skyfury, Blessing of the Bronze, Source of Magic), rogue poisons, weapon imbues, Maelstrom Weapon, Icicles, Tip of the Spear and Overflowing Power.
- So practically every aura of every class needs a route other than reading it directly in restricted content.

The sanctioned routes, all from Blizzard's API (B §2 and §3.10; C §5.7):
- **B: Cooldown Manager.** Enumerate it, read item presence, and use its alert hooks: Applied, Removed and PandemicTime give exact moments.
- **C: proc-glow events.** These carry no secrecy flags.
- **D: your own casts.**
- **E: client-played sound.** `C_UnitAuras.AddAuraSound`.
- **F: Blizzard's aura containers.** They draw time and stacks exactly but give no Lua signal back.
- **Game-side gates.** Application bars with a minimum, and secret alpha.

## 1. Root causes (one bug behind many issues)
| # | Root cause | Groups / issues | What the user sees |
|---|---|---|---|
| R1 | In-combat knowledge rests on one fragile side channel. XayaUI never enumerates what the Cooldown Manager can track, never checks that its viewer is shown, ignores PandemicTime and ChargeGained, and uses neither glow events nor AddAuraSound. The editor never says whether a trigger can be read in combat. | B-C1, B-C3, A-C4; #93, #173, #222, #301, #303, #314, #315, #332, Insivius | "no in-combat cues for Divine Arbiter / Boiling Blood"; sounds missing while icons show |
| R2 | Two authorities decide what shows and where. The engine container shows a member whenever its aura is up; it ignores conditions; it uses one container per group in game order with member 1's size and style. XayaUI lays out the rest from the same first spot. | B-C2, C-L1, L2, L3, P1, P2; #56, #262, #280, #306, #308, #310, #311, #318, #344, #347 | "auras not lining up per the group rules"; conditions ignored in combat |
| R3 | The same truth is kept in several places. Aura length has 5 stores, aura start 4 and presence 4. "Loaded" has 6 definitions. There are two aura trigger types and two combiners. The engine's eligibility test differs from the trigger test. | B §3.3, A-C1, A-C3, A-C7, C-P2, C-D1 | rules behave differently by path; fixes in one path don't reach the other |
| R4 | Time-left semantics: an absent buff counts as 0 s left, the duration-object tier is dead in combat, and the estimators disagree. | B-C4; #173, #301, #306, #314 | "seconds left <= 2" fires while the buff is missing |
| R5 | Claims drift away from the code. | A-C6, B-C7, C §0 | "told it's fixed, nothing changed" |
| R6 | Polling cost: every event re-evaluates every rule (up to 20 Hz), and per-step allocations remain. | B-C5, B §3.4 | stickiness, fps loss (#298, #307) |

Examples of R5:
- `/xui auras` (#335) was never on main.
- The perf guard reads the wrong addon name and its trip persists.
- The README and USER-GUIDE describe a `XayaUI_CombatEngine.toc` that doesn't exist.
- #333's fix is missing from main.
- #157 was closed with no fix.

## 2. Dependency-ordered phases (each phase lands, is tested, and is shown to Xaya before the next)
**Phase 0. Truth and diagnostics** (small, unblocks data; no behaviour risk)
1. Restore `/xui auras` (#335): real aura IDs out of combat. This settles the Divine Arbiter 1306161/1306162 question and the Boiling Point/Blood buff ID.
2. Readability per rule:
   - `C_Secrets.GetSpellAuraSecrecy` per aura;
   - a Cooldown Manager catalogue lookup;
   - whether the viewer is shown;
   - whether the aura makes an ability glow (learned out of combat).

   Show it in the rule editor and in `/xui timing`, including sound-only rules (today they are skipped).
3. Perf guard:
   - measure "XayaUI", not "XayaUI_CombatEngine";
   - don't count the shared `Blizzard_AuraContainer`;
   - make a trip non-persistent.
4. `/xuiengine` lists every display, including the ones the engine refuses, with the reason.
5. Fix the doc drift (README / USER-GUIDE / Combat/README).
6. New GameDump capture: the Cooldown Manager catalogue of the current spec (`GetCooldownViewerCategorySet(cat, true)` + `GetCooldownViewerCooldownInfo` for each category). Testers of every class can then fill the reference for every spec.

**Phase 1. One aura truth** (the core rebuild; fixes R1 at the source, R3 for auras)
1. Catalogue per spec (game data, no shipped IDs):
   - the Cooldown Manager entries (spellID, overrideSpellID, linkedSpellIDs, selfAura);
   - the secrecy flag;
   - the glow association;
   - the cast → aura links.

   It is rebuilt on spec, talent and data-loaded events.
2. One aura-state store keyed by (unit, spellID): present, expiresAt, stacks, startedAt and provenance (exact | cdm | glow | cast-estimate | seed | unknown).
   - Fed by: the aura API (unrestricted or NeverSecret), Cooldown Manager hooks (Applied, Removed, PandemicTime, ChargeGained, OnCooldown, Available, from shown viewers only), glow events, own casts, and UNIT_AURA timing stamps.
   - One length table.
3. Cooldown Manager hardening:
   - check viewer shown and enabled, and treat a non-shown viewer as unknown, not false;
   - hook frames when the pool creates them, not up to 0.25 s later;
   - replace the `"CDM frame"` string match with a structured result.
4. One "is this rule loaded" function, used everywhere: rule list, Actions init, DisplayWanted, AuraDisplay.Allowed and LoadsForSpec. Fixes the `"*"` and `specUse` handling.
5. Delete the dead ID-link layer, which re-tests a refused API every combat.

**Phase 2. Displays obey the rules** (fixes R2; needs Phase 1's tri-state presence)
1. Data truth:
   - membership from the parent rule's folder, not the cue's copy;
   - order by parent rule;
   - name sort by the parent's name;
   - eligibility through `ns.BuffUsed`.
2. A tri-state gate per item: false when XayaUI knows it must not show (load, talent, condition false, not on bar); true when it knows it should; unknown otherwise. Engine items show when the gate is not false and the game has the aura. XayaUI-only items show only when the gate is true.
3. One member model with one `Layout()`, used by preview, unlock and the game. A new parity test with N mixed members must fail on today's code.
4. Pinned-slot renderer: one container per group and unit, `AddAuraSlot` per member, anchored out of combat to XayaUI's frames. Each member keeps its own size, art and text style. N members cost N buttons, not 10 per group.
5. Game-side gates for conditions in combat: stacks ≥ N through application bars with `minApplications`; "hide at 0" and shield > 0 through secret alpha.
6. Fidelity around the slot: XayaUI draws border, outline, glow, overlay, strata and modifiers on its own frame. Unlock and preview step the engine aside for the whole group.
7. Optional, only if Xaya wants gapless groups (decision D4): the secure flow renderer, with one aura group per member.

**Phase 3. New signal sources for reactions** (sounds, speech, conditions)
1. A proc-glow trigger from `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE` and `IsSpellOverlayed`. No secrecy flags, so it works in combat.
2. An opt-in "engine sound" through `C_UnitAuras.AddAuraSound`, for auras with no Lua signal. Sound files only, at most 5 s; registered out of combat (decision D2).
3. An opt-in "track in the Cooldown Manager for me" through `C_CooldownViewer.SetLayoutData` (decision D3).
4. Exact charge counts for 2-charge spells (isActive is NeverSecret). For 3 or more charges, ChargeGained / OnCooldown counting, re-synced at max.
5. A stack estimate for Cooldown Manager auras: count `OnUnitAuraUpdatedEvent` hook calls since Applied.
6. Time-left semantics (decision D1): an absent buff is unknown, not 0. `n:buffRemain` also works on trigger rows.

**Phase 4. One trigger model** (A-C1, C2, C3, C7; needs decisions D6 and D9)
1. One Load-tab control model, chosen once by Xaya, implemented in one helper, for both the rule and group Load tabs.
2. One aura trigger type with an ID list, stacks and remaining refs, the estimate, and the readability line. Items get ID lists too (#157). `buffAlt` is normalized on import.
3. One combiner: `extra.mode` folds into `trigMode`, with a saved-rule migration.
4. Tri-state UX: UNKNOWN shown on the final condition line, lights shown without the skin, "Is usable" relabelled.

**Phase 5. Every aura, every class, every spec** (coverage)
1. Catch-all containers by category:
   - your buffs and procs (player HELPFUL from player, `excludeSpellIDs` for rule-tracked ones);
   - your debuffs on target, focus and optionally nameplates (HARMFUL|PLAYER);
   - debuffs on you (HARMFUL, boss / dispel filters);
   - enemy buffs (dispellable / important filters);
   - party buffs.
2. "Seen auras → make a rule": out-of-combat reads, probe history and catalogue entries give one-click rules, each with its own slot, art and sound.
3. Catalogue-driven starter rules per spec from the game's own data (Class/Spec Rule Creator).

**Phase 6. Event-driven evaluation and performance** (R6)
1. Route each event to the rules that depend on it (by unit, spellID, power type), with a slow full sweep as a safety net.
2. Remove the per-step string and closure garbage.
3. Measure in game: `/xui perf` with Xaya's groups.

## 3a. Decisions recorded (Xaya, 2026-11-04)
- D4 (groups): "auras that appear to be shown in the order I set them ... if immolation aura appears, I want it to be displayed in between other running auras."
  - Design: the gapless secure flow in RULE order. Each member is its own aura group in the container: layoutIndex = rule order, own element size, maxFrameCount 1. Blizzard's flow skips empty groups, so an aura that appears takes its place between the running ones, in combat.
  - Mixed groups (cooldowns, 'missing' icons): split into flow segments chained edge to edge around XayaUI's own item frames. Anchors are set out of combat. A hidden XayaUI item collapses to near-zero width, so the next segment closes up. Pinned slots are dropped as the default.
- Sort per dynamic group (Xaya, 2026-11-04): Default, Expiration, Name, Important, Manual ("organize the group and force-save with a reload").
  - The first four are Blizzard's container sorts (AuraContainerSortMethod Default / Expiration / Name / ImportantOnly; BigDefensive is also available) on one aura group.
  - Manual = one aura group per member with layoutIndex = the member's number in XayaUI's own table. Blizzard sorts groups by layoutIndex and skips empty groups (12.1.5 source: Blizzard_CustomAuraContainer.lua GetEffectiveFlowLayoutIndex / SortFlowLayoutDescriptions; AnchorUtil.lua "Empty groups do not contribute spacing or force a new line").
  - Saved, and applied on reload.
- Group display options (Xaya, 2026-11-04 screenshots).
  - Group tab: icon size, growth, icons per row, spacing, sort method (Default / Expiration / Name / Important / Manual), sort direction (Normal / Reverse).
  - Display tab, "Every display": border style and size, icon shape (mask; apply to all or chosen members), zoom, duration swipe, duration text (size, color, on), stacks (size, color, on), font outline, tooltips, right-click to cancel.
  - Engine routes, from the 12.1.5 source (Blizzard_AuraButton.lua):
    - tooltips: the button's own OnEnter tooltip, which is on by default; `SetTooltipAnchorPoint`; `SetHideTooltipInCombat`; off = EnableMouse(false), which also makes the button click-through;
    - right-click cancel: `SetCancelAuraButtons("RightButton")`, done by Blizzard's secure code;
    - swipe: the duration Cooldown's draw swipe;
    - border and shape: textures and a mask made in `initializeFrame`.
  - Also available: pandemic regions and animations, dispel-type textures and text, and application bars.
- More icon options (Xaya, 2026-11-04 second screenshots), for aura AND cooldown icons, group-wide with per-member override:
  - icon scale, spacing, border style / size / colors, custom icon shape (cropped, circle, ...; apply to all or chosen), zoom;
  - duration size / position / color, charge / stack size / position / color;
  - suppress GCD (`C_Spell.GetSpellCooldownDuration(id, ignoreGCD = true)`), always show cooldown edge (Cooldown:SetDrawEdge);
  - pixel glow thickness, charges / stacks only (no icon), hide charge count at 0 (TruncateWhenZero or secret alpha);
  - show tooltip on hover, show keybind (action slot of the spell, then its binding; size and color), mirror key presses (flash on that spell's key; hook on the action button press);
  - pandemic glow style and color (Blizzard's pandemic regions and animations on aura buttons; the Cooldown Manager PandemicTime moment for XayaUI frames);
  - show non-on-use trinkets / hide items if missing (item cooldown displays), bar strata, glows only in combat (global);
  - rotation helper (C_AssistedCombat): to be checked.
- D1 (time left): an absent buff shows no icon and no number, and any time condition on it is NOT met, unless a condition is explicitly set to show it while absent. (Xaya: "EUI does this.")
- D2 (AddAuraSound): yes. The output channel is user-selectable (UnitAuraSoundInfo.outputChannel), default Ambience, so the sound can be muted or lowered alone. Verified: the game gives addons no signal when it plays such a sound (C_Sound has only IsPlaying(handle) and SOUNDKIT_FINISHED for addon-started sounds), so it is for the player's ears. Detection comes from the catalogue, the Cooldown Manager, glow events and containers.
- D3 (Cooldown Manager auto-add): yes, opt-in per rule.

## 3. Decisions only Xaya can make (aura tracking)
- D1 (#173): when the buff is NOT up, should "seconds left <= N" be false/unknown (proposed) or true (today)?
- D2: may XayaUI register client-played sounds (AddAuraSound) for auras it cannot see in combat? Sound files only, at most 5 s, no speech.
- D3: may XayaUI add auras to your Blizzard Cooldown Manager layout automatically (opt-in, per rule)?
- D4: dynamic groups in combat: pinned slots (items keep their place; a hole where an aura is down but XayaUI can't tell) or gapless (Blizzard's own flow; groups made only of aura rules; XayaUI-only items follow as a block)?
- D5: where a dynamic group starts inside its box, and how a line aligns (edge, like Blizzard, or centred)?
- D6: Load tab: does "Always load" bypass Class / Spec? And one model for every list: multi or single, NOT or not, keep or wipe on untick.
- D7 (#115): is up to 50 ms between a game change and its sound acceptable?
- D8 (#353): keep the channel strings Blizzard uses ("SFX"), or test "Master" first?
- D9: merge "Buff / Aura (another)" into one full aura trigger type (rows with ID lists, stacks and time)?
- D10: which catch-all categories, and are nameplates in scope?

## 4. Game data
Received (Xaya, in the session chat, 2026-11-04; how they were read in game was not stated):
- Divine Arbiter: two auras, **1306161** and **1306162**, from a **tier set** bonus (not a talent). The client's talent data has two
  different spells of the same name: 406975 (Highlord's Judgment / Holystrike stacks) and 1296661 (from Divine Purpose).
- Boiling Point: two auras, **1265982** and **1265968**. The talent is 1265790 (Blood, talent entry 96167).
- None of the four aura IDs is in the GameDump capture (it holds talents and spellbook spells, not auras).

Still needed:
- `/xui auras <id>` on a Ret Paladin and a Blood DK, out of combat: whether the Cooldown Manager offers these auras (decides text and
  conditions in combat).
- The Cooldown Manager catalogue per spec (`/xuidump auras`, one run per spec, any tester).
- The Cooldown Manager catalogue per spec (new GameDump capture; one run per spec, any tester).
- Whether those procs make an ability glow (learned automatically once Phase 0 ships).
- `/xui perf` numbers with Xaya's real groups.
