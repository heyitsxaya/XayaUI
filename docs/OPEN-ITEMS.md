# Open items, verification checklist and unfiled GitHub issues

Source: three distinct handoff notes (2026-09-24 and two from 2026-10-31; a fourth upload was a byte-identical duplicate). Checked against GitHub on 2026-10-31: newest issue is #93, and **none of the issues below had been filed**. Issue #77 still had **zero comments**.

Before filing, search existing issues and comment instead of duplicating. Suggested labels: `status:open`, `unverified-in-game`, `batch:triggers-2026-10-30`, `type:feature|bug|diagnostic|housekeeping`, `area:midnight-secrets`.

Confidence: items marked INFERRED come from decoded profile exports and code reading; nothing here was run in game. Spell IDs were not verified against a source.

## A. Comment to post on issue #77 (hover highlight)

Missing from GitHub: after R77 shipped, Xaya reported "r77 is not actually working as intended" and, when asked to narrow it, "No highlight appears at all on hover." Two diagnostics were asked and never answered: (1) was `/reload` run after the fix shipped? (2) was the display **unlocked**? In `Visual.lua` the hover handlers are gated by `fr:EnableMouse(Unl(rule))`, so a locked display gets no hover events by design. Static review found `OnEnter`/`OnLeave` attached once, in `GetFrame(rule)`, with no duplicate creation path; never tested against a live repro. Leave #77 open as "needs repro".

Other notes from that handoff: #78 already carries its open product question (per-folder override) in its own body, so nothing to add. A separate draft backlog for "Gated Collapsible Panes" is another session's work (it appears to have since been filed, e.g. epic #91).

## B. Issues to file (triggers / outcomes batch)

Each "Close when" is the acceptance test; do not close on offline results alone.

| ID | Type | State | Title / close when |
|---|---|---|---|
| T01 | feature | implemented, unverified | Additional Triggers (WeakAuras port). In game each type shows a correct "Right now" line; a Player State row fires; old rules unchanged after `/reload`. |
| T02 | feature | implemented, unverified | Outcomes bundled as "Condition N". Create 3 outcomes, collapse/expand with a note, duplicate and delete the parent, `/reload` keeps everything, outcome fires only when its combination is true. |
| T03 | feature | implemented, unverified | Trigger numbering with Up / Down / Remove. Reorder/remove in game; outcome refs still point at the right trigger or show unknown if removed. |
| T04 | feature | implemented, unverified | Target Debuff (yours) with combat support. Positive and negative cases pass in combat with the final build; quick target switch does not misfire. Risks: one sample per state; icon rebind lag after target change; inactive icon under the debuff ID while the active one sits under the ability ID (use the "Cooldown Manager spell ID" box). |
| T05 | bug (fixed) | fixed, unverified | Outcome x-refs always unknown (`CheckExtraTriggers` returned no rows; fixed `f59836d`). Close when an outcome with an x-ref fires out of combat. |
| T06 | bug (fixed) | fixed | `/xui status` crashed on outcome rules (`format` got nil). Fixed in `f59836d`. Close when status lists outcome rules cleanly. |
| T07 | bug (fixed) | fixed, unverified | Aura-call error skipped the Cooldown Manager check; icon must not override a clean aura list. Close as T04. |
| T08 | bug (mitigated) | unconfirmed | Options "script ran too long" in AceConfigRegistry `validateVal`. Mitigation: validation skipped. Root cause unproven. Close when `/xui` opens cleanly with 20+ rules; consider timing `BuildOptions`. |
| T09 | diagnostic | implemented | Per-trigger reasons in `/xui status`, `/xui debuffs`, probe `unit=`. |
| T10 | bug | fix shipped, **profile edit pending** | Sigil of Flame sound fires up to 2 s early and while Flame is on cooldown. Cause (INFERRED): Spell Usable ignores cooldown and Sigil activates after 2 s. Xaya must set the Spell Usable row (204596) to "Usable AND off cooldown (ready to press)". Close when no Torch sound within 2 s of casting Sigil of Flame, and none while on cooldown. Open design question: relabel or warn on "Is usable". |
| T11 | feature | implemented, unverified | Single-rule Export. Export a parent with 3 outcomes, import into a fresh profile and the same profile twice; outcomes stay attached; `maxCharges` stays a number. |
| T12 | enhancement | implemented, unverified | Cooldown State dropdown for spells without charges: single-charge shows 3 options, 2-charge shows 5, old rules keep their entry. |
| T13 | test | open | In-game checklist (section C). |
| T14 | enhancement | open | Outcome gaps: slash commands listing rules by number still count outcomes; preview-icon strip draws one icon per outcome with a display; deleting a parent outside the UI can leave orphan outcomes; folder Copy/Transform drops `uid`/`parentUid`; buff-active visual mode untested; "While the buff is present" visuals ignore Additional Triggers. |
| T15 | housekeeping | open | Merge project logs, decide version bump, clean local `.bak` files (74 on Xaya's machine, gitignored). `CHANGELOG.md` is now in the repo. |

## C. In-game verification checklist (nothing below has been run in game)

1. Sigil of Flame ticking on target: `/xui status` shows `x1(targetDebuff)=true [seen in the Cooldown Manager]`, outcome #20 true, #21 false.
2. Target-switch lag: switch targets mid-fight; an inactive icon might briefly read "absent".
3. Early-sound fix after the T10 profile edit.
4. Options window no longer raises "script ran too long".
5. AceConfig rendering of deeply nested inline "Condition N" groups, and page size.
6. Single-rule export/import round trip.
7. The original trigger types' API reads in 12.1 (`C_Spell.IsSpellUsable`, `IsSpellInRange`, `GetTotemInfo`, `GetShapeshiftFormInfo`, `GetWeaponEnchantInfo`, `GetRuneCooldown`, `UnitPower`, `C_Item.GetItemCount`, GCD via spell 61304, `GetUnitSpeed`). Spell Usable IS readable in combat (seen).
8. Out-of-combat testing needs parent Load > combat set to "none".
9. "Cooldown (any spell)": appears as "Spell: Cooldown (any spell)" in "Add a trigger"; several rows per rule, each x1, x2...; remove/reorder remaps outcome refs; export/import keeps `maxCharges` numeric. Limits: no spellbook dropdown (ID box and name search only); 12 extra triggers per rule; unreadable cooldown in combat = unknown = no fire. Follow-up idea: spellbook picker on the `spell` field kind.
10. Remove / Up / Down look identical in Cooldown, Buff / Aura and extra-trigger sections. If pixel widths differ (extra rows sit in a narrower inline group), use the same group nesting or an explicit relative width.

Seen working in game already (VERIFIED by Xaya's output): new Additional Triggers tab renders; `/xui status` reports in combat; outcome #21 matched in combat with `x1=false` via inactive icon, `x2=true`, `cd=true`.

## D. Other bugs and cleanups from the handoffs

- **UI: truncated labels.** Target Debuff labels "Cooldown Manager spell ID (optional: ...)" and "In combat: an INACTIVE Cooldown Manager icon means ..." render cut off. Shorten them and move the long text into `desc`. Not yet fixed.
- **Companion issue "Outcome has no cd condition"**: the 10-31 companion handoff says outcome "SoS (off CD) + SoF debuff missing, off CD" lacks a `cd` condition; the other handoff decoded the same outcome as `NOT x1 AND x2 AND cd`. The two disagree (different exports), so check the current profile before filing. Optional feature: warn in the outcome builder when a name says "off CD" but no `cd` condition exists.
- **Profile hygiene flags** (INFERRED from two exports, Xaya's personal profile): buff ID 1265924 shared by "L - Soul Barrier" and "L - First In Last Out" (disabled variant uses 1266619); two disabled Reaver's Glaive rules (1283344) never given the "show only while on action bar" option; mixed `load` schemas (`role`/`specID` vs `roles`/`specs`, some without a `combat` key) - check in `ns.CheckContext` whether a missing key means always or never; shared IDs 258920 and 203819 (possibly intentional left/right displays); three stacking Demon Spikes rules (203720) sharing parent uid `u1793400497438958`; four Sigil of Spite outcomes on 390163, two sharing the Temple Bell sound - confirm conditions are mutually exclusive; second export has an empty profile name. Checksum algorithm of the `XUI1:` export string is undocumented.
- **Blocked / gated carry-overs:** matching her Cooldown Manager Tracked Buffs list to her rules (SavedVariables were not accessible; export strings are the workaround); the engine-aura port (EUI in-combat buff logic) waits for her in-game probes `/xui probe 187827` and `/xui probe 258920`.
- **Cautions:** several Claude sessions edited this addon concurrently and an old log noted `.git/index.lock` blocking commits; check `git status` before committing.

## E. Decisions still Xaya's

1. Version bump for `XayaUI.toc` (0.5.5). 2. Relabel or warn on "Is usable" (T10). 3. Add a delay after target change if the target-switch test misfires. 4. Should Additional Triggers also drive "While the buff is present" visuals (currently no)? 5. Next trigger batch (backlog is in the external tracker).
