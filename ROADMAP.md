# XayaUI Roadmap

Compiled 2026-11-03 against build 0.5.107; section 9 and the #155 row updated the same evening against 0.6.0. This is the single list of every feature suggested for XayaUI, whether built, planned, waiting on a decision, parked, or dropped.

## How to read this

**Status words**
- **Built** means the issue tracker or the build notes say the feature exists in that build. It does not mean it has been confirmed in game. The tracker's `unverified-in-game` label is on 59 issues, so treat everything marked Built as "needs an in-game check" unless it says otherwise.
- **Partly built**: some of the feature exists; the note says what is missing.
- **Planned**: agreed in principle, not started.
- **Candidate**: logged, but it needs answers or a decision first (the open questions are in the linked issue or listed in section 9).
- **Parked**: deliberately set aside.
- **Dropped**: removed or ruled out, with the reason.

**Reliability.** Statuses come from issue titles, labels, and project notes. They are not a fresh audit of the code. Items from the original milestone list (M0 to M12) carry statuses from a 2026-11-01 review, and several have been overtaken by later UI work. Where I could not tell, the note says so. Effort sizes (S, M, L) are estimates, not commitments.

**Standing rules every item follows**
- No code or data copied from another addon goes into XayaUI (issue #290). Class, spell, and item data is learned from the game client at runtime where the game gives it. #290 does not forbid numbers from a credible public database such as Wowhead: they may be used when the source is named next to them (Xaya, 2026-11-04; an earlier wording of this line said "game API only", which was broader than #290).
- Personal data stays local. Personal rules, buff lists, and anything about other players live only in the user's own saved settings and are excluded from profile export unless the user opts in.
- Midnight secret values. Any read that can come back secret is wrapped, checked, and treated as unknown. A value that cannot be read is shown as unavailable, never guessed.
- Options style: a dropdown never takes a whole row alone, labels stay short, and the explanation goes in the tooltip.

Issue numbers refer to this repository. Small interface tweaks, wording changes, and defect reports are tracked as individual issues and are not repeated here; this file lists features and the decisions that gate them. "Unclear" means the issue is open and labeled `unverified-in-game` but has no build number, so I could not tell whether it was built.

---

## 1. Rule model and engine

| ID | Feature | Status | Notes |
|---|---|---|---|
| M0 | Audit and verify the base | Planned, ongoing | An in-game verification pass of recent builds is still outstanding; the glow and icon option audit is folded into M5. |
| M1 | Data model v0.6: aura, cooldown, and combination rule types; schema version; migration with backup; import upgrade | Planned | Largest risk in the whole list: every saved rule must load identically after migration. Blocks M2b, M3, M6d. Effort M-L. |
| M2b | Type sub-tabs (Aura, Cooldown, Combinations) | Planned | Needs M1. |
| M3 | Combinations: named outputs, AND / OR / NOT builder, bundled fire, cycle guard | Partly overtaken | The Cues and Conditions rebuild (#130) covers part of this; the type-based version still needs M1. |
| M6d | Folder force: a folder's settings override all elements of the rules inside it | Planned | Live inheritance, not a bulk write. Trigger IDs are never forced. Needs M1. Effort L. |
| M12 | Custom code | Partly built | Custom code per moment exists in the Actions pane (#179). Still open: custom triggers, conditions, cues, and actions (#225, #258) and a developer interface layer for custom widgets (#224). Imported rules that contain code must arrive disabled. |
| #192 | Trigger pane: "This rule is activated by" ALL / ANY / one trigger | Unclear | |
| #193, #194 | Show TRUE / FALSE / UNKNOWN on each trigger header and condition | Unclear | |
| #147 | Class resource as one trigger type with a resource dropdown (including Runes) | Open | |
| #155 | Player-state conditions: stunned, feared, rooted, silenced | Partly built | A state trigger for the player exists in the code (stun; fear, charm, and incapacitate as one group; root; silence), read from the game's loss-of-control data; not confirmed in game. Extension (separate effects, asleep, slow, snare, target and focus) is in section 9, #278 items 5 and 6. |
| #173 | Aura seconds-left conditions in combat | Partly built | The duration engine (#314, build 0.5.98) lets every cue fire on time left in combat; confirm in game. |
| #222 | Combat tracking model and setup flow, with a capture button for other users | Candidate | |
| #264 | One Buff / Aura trigger takes several aura IDs | Built (0.5.55) | A regression with a second Buff / Aura trigger is reported in #288. |
| RM-188 | Rule build assistant: a guided new-rule wizard | Candidate | Earlier decision was "advanced only, no wizard"; this supersedes it only if Xaya confirms. Output is an ordinary rule, no new data model. |
| RM-151 | Safeguard against accidentally breaking a loaded rule while editing | Partly addressed | Autosave and Drafts (#197, #295) change how edits are saved; whether that is enough is undecided (inference). |
| #111 | Multi-select delete; one "group" concept instead of folders | Built | |
| #131 | Group pages: Group, Display, and Load tabs; group load conditions | Open | |
| #261, #265, #267 | Move a whole group by its container; group positioning options; X / Y entry and center on screen from the move menu | Open | |
| #268 | 9-point anchors (inner and outer) for every display, with X / Y measured from the anchor | Open, **marked high priority** | |
| #266 | Undo the last change while editing a rule | Built (0.5.59) | |
| #276 | Profile import drops group container settings | Open defect | |

## 2. Visuals, cues, and sound

| ID | Feature | Status | Notes |
|---|---|---|---|
| M5 | Glow styles, icon zoom, border, shape and mask, manual width and height, aspect-ratio lock | Partly overlapping | Aspect ratio shipped in 0.5.99 (#313); outline and glow are tracked in #64. Remaining parity gaps need an audit. |
| #125 | Frame strata and level conditions for texture and text | Open | |
| #195, #260 | Per-cue modifiers per condition (tint, desaturate, glow, opacity, strata) | Built, with an open defect | #260 reports that modifiers do not apply. |
| #270, #271 | Icon shapes (cropped, diamond, circle, square); icon size separate from display size | Candidate | |
| M6c, #283 | Hover tooltip on every cue | Built per #283, issue open | Default OFF; hover-enabled frames block mouseover casting beneath them. |
| #281 | Tooltip IDs: show the matching aura ID on item and spell tooltips | Built, issue open | |
| #145 | Speech (text-to-speech) cue | Built | #198: research more voices. |
| #162 | Custom textures, icons, and sounds outside the XayaUI folder | Unclear | |
| #196 | Type a sound file path directly | Unclear | |
| #249 | Every color picker supports transparency | Open | |
| #318 | Dynamic groups: items per row or column and which side extra rows go | Built (0.5.104), issue open | |

## 3. Class, spec, and talent data

| ID | Feature | Status | Notes |
|---|---|---|---|
| M6a | Hero-talent condition and hero-tree picker | Partly built | Code for hero-tree reads exists; the picker's completeness is unconfirmed. |
| M6b | Talent node-graph popup ("Pick from tree") | Planned | Own class only. The list stays as a fallback. |
| M7 | Class and spec seeding skeleton | Partly built | Auto-populate by spec and by class exists (#143, #211). |
| M8 | Community-sourced class data | Re-scoped | Replaced by #290: data is learned from the game client; no third-party-derived data. |
| #105 | Sibling data addon for class, spec, and racial data | Candidate | Design drafted before #290; it may be re-scoped to runtime-learned data only. Needs an in-game test of runtime enumeration. |
| #319 | A Class load condition; the spec list shows only the current character's class | Open | Also supports the stated goal that aura tracking works for all classes and specs. |
| #108 | What Class/Spec Rule Creator skeleton rules should do | Waiting on a decision | |

## 4. Combat aura engine and addon structure

| ID | Feature | Status | Notes |
|---|---|---|---|
| #280, #308 | Combat aura display engine draws tagged groups, then every combat aura, with a performance guard | Built (0.5.87 and later), issues open | The engine lives in the sibling addon `XayaUI_CombatEngine`. |
| #309 | Full review: refactor and optimize the engine for CPU and memory | Open | |
| #310 | Engine-drawn groups follow parent-group position and lock / unlock | Built (0.5.88), issue open | |
| #114 to #119, #298 | Performance items: action bar rescans, per-tick frame lookups, closures in text updates, linear lookups, Cooldown Manager rescans | Open | |
| #227 | Split the options into a sibling addon `XayaUI_Options` | Candidate | Analysis outline only. |
| RM-QOL | Move everything under the QoL UI Updates tab into its own separate QoL addon directory, with XayaUI as a dependency, so users can enable or disable it independently | Planned by Xaya, structure not yet mapped | Xaya is mapping the structure herself before any build. Open question: whether Tooltips moves, since it was folded into core on 2026-11-02. |
| #123 | Refactor: split the largest options file, isolate dormant QoL code | Candidate | |
| #253, #239 | Tooltip base lives in core; a sibling addon is reserved for instance and Mythic+ data | Built (0.5.51), scope is the current expansion and season only | |

## 5. Options window and settings

| ID | Feature | Status | Notes |
|---|---|---|---|
| M2a | Tab skin and Visual / Audio split | Overtaken | Reworked through later UI passes and the Cues, Conditions, and Actions rebuild (#124, #129, #130); not re-audited. |
| M4 | Filter and search | Partly built | A sidebar search filter exists (#132); type, class, spec, and loaded filters are not confirmed. |
| M9 | Meta settings (interface behavior options that are not rule data) | Partly built | Settings tabs exist (#316, #317); the remaining candidates (remember window state, reset window size) are unbuilt. |
| #197, #230, #289, #295 | Save changes, Drafts page, save-as-copy, autosave by default with an option to prompt | Built | |
| #91, #79 to #82 | Gated collapsible panes for dependent options | Epic, waiting on four decisions | Pane wrapper or plain hide; default open or closed; dropdown-dependent options; losing pre-set styling while an element is off. |
| #101, #109 | Addon Info tab with version, last-updated date, credits, and attribution | Built | |
| #223 | Manual override for the default pane height and width | Open | |
| #259 | Condensed option panes: a checkbox with an inline dropdown that appears only when ticked | Open | |
| #231 | Right-click empty space in the Rules sidebar for New Rule, New Group, New Dynamic Group | Open | |
| #291 | Import opens its own window and goes into its own folder | Open | |

## 6. Quality of life

| ID | Feature | Status | Notes |
|---|---|---|---|
| #87 | Backup: write a profile export to a chosen local path on click | Waiting on a decision | Scope, trigger, and file-write behavior to be pinned down. |
| #88 | Recycle bin: deleted rules are held, disabled, and cleared on a schedule | Waiting on a decision | Retention and restore mechanics to be pinned down. |
| | Smart Categories above ALL RULES, collapsed by default, searchable by tracked spell or aura | Partly built | By-type sorting is meant to come from Smart Categories. |
| #234, #245 | Custom data panels and bars (five strips, one to twenty data slots each) | Built | |
| #233, #238, #279, #312 | Game menu button and skinned game menu | Built (0.5.96 fix pending in-game confirmation) | |
| #244, #275, #277, #293, #317 | Minimap button: quick-access list, icon, override, size, circular clip, moved into Settings | Built | |
| #240 to #243, #254 to #256 | Notepad: notes list, formatting, share to chat, import and export, icon toolbar | Built | |
| #272 | Notepad extras: combat time per unit, rule-linked notes, party assignment inputs | Candidate | Feasibility not established. |
| #236, #212 | Custom theme; automatic class colors by default | Built | |
| #228, #252, #253, #281 | Tooltip modifiers (IDs, item level, hostile-unit Mythic+ info) | Rebuilt from scratch on 2026-11-02 using only the documented game API | Tooltip base lives in core; only instance and Mythic+ data goes in an optional data pack. Scope is the current expansion and season. Item level on tooltips is part of this. |
| #199, #200 | Cursor highlight: outline-only style, game cursor art shape | Unclear | The cursor tracker and at-cursor reminders are switched off for now (#103). |
| #273 | Cursor trail gradients as theme options | Open | |
| #126 | Gradient cursor trail with presets and up to six custom colors | Candidate | Extends the switched-off cursor tracker. |
| #320 | FPS and latency tooltips show addon CPU and memory use | Built (0.5.107) | |
| RM-CHAR | Character Toolkit: a tabbed stat panel beside the character window (Overview, Ratings, Defense, Offense, Gear, Spells) and extra lines on its stat tooltips. Goal (Xaya, 2026-11-04): surface everything the API gives, improve on the character window rather than copy it. True rating, lost rating, penalty, rating per 1%, exact rating for the next 1%, diminishing-return thresholds (scanned from the game's converter), rating vs other sources, what-if +N rating, base vs buffs, linked conversions, item level, movement, mastery text, spell power, regen, ranged, stagger, per-slot gear ratings, sockets and durability, and an advanced Spell Math tab | Built (QoL 0.6.2), unverified in game | Not given by the game, so shown as such: primary to armor, primary to dodge, Strength to parry, stat to block, attack power to weapon damage, mastery's percent modifiers. Attack speed and GCD figures are labelled estimates. Open: whether the live converter applies diminishing returns (the panel flags a disagreement); whether to fill the "not given" rows from a named database source now that #290 allows it. |

## 7. Chat Panel (rebuilt cleanly as one feature, #297)

Built in 0.5.90 and revised in 0.5.94, awaiting in-game feedback: the input field inside the chat pane, the data bar as part of the chat, a privacy cover (hides the chat pane and input field), an option to apply the XayaUI theme, spam filtering (repeat suppression, own blocked-phrase list, right-click ignore), link copying, a history pane, and per-tab sounds. Settings start fresh in a new saved-variable table.

| ID | Feature | Status | Notes |
|---|---|---|---|
| #247 | Trade tab (auto-create, take Trade out of other tabs, revert) | Dropped in the rebuild | Restorable from git history; Xaya has not yet said whether to restore it. |
| | Emotion icons, role / mentorship / timerunning icons, Battle.net tag names, Quick Join messages | Not built | From a 2026-11-01 parity review; needs a full message-formatting rebuild. Emotion icons are covered by a separate addon. |

## 8. Diagnostics and tooling

| ID | Feature | Status | Notes |
|---|---|---|---|
| M10 | Version and compatibility check (`/xui version`, drift warning when the client build changes) | Partly built | Addon Info shows versions; the drift warning is not confirmed. Schema version arrives with M1. |
| M11 | Debugging: on / off toggle, ring-buffer log, error dump | Partly built | A console exists. Logged, status unclear: copy text (#201), console in its own window (#202), bug report and saved Lua error log (#203). Never formats secret values. |
| | Game data dump companion addon for probing the live API | Built | Used for in-game probes before features that depend on unverified API behavior. |
| #120, #122 | Unused-code cleanup; repo hygiene (tracked outputs folder, backup files) | Open | |

## 9. New candidates logged 2026-11-03 (nothing built)

Each has a drafted spec with the API facts checked against the 12.1.5 documentation, a stress test, and open questions. Each is filed as a `[Roadmap]` issue: the numbers are in the first column.

| ID | Feature | Weakest point | Open questions |
|---|---|---|---|
| #321 | **Item wishlist feeding a loot-specialization reminder.** A wishlist of items; on entering a matching instance, a reminder when the loot specialization is not the one that can receive the item, with an optional one-click set button. No silent auto-change. | No verified API route from an item to the boss that drops it, so v1 uses a manually chosen source. Creature IDs are secret in instances, so the reminder fires on zoning in, not per boss. Loot specialization filters armor and weapon drops from raid bosses, the Mythic+ chest, and the Great Vault (per Blizzard Support); when the Vault reads it is not established. | Reading of the request; reminder only or also a set button; fire on zone-in; per character or account-wide; one item version or any; season scope; cover the weekly Vault. |
| #322 | **Friends list: class colors by current character.** Color each online friend's name by the class of the character they are on now. | "The friends list" is undecided: Blizzard's window (hook, taint risk), a new XayaUI window, or the Chat Bar Friends block. | Where it shows; offline friends use the last-known character. |
| #323 | **Friends list: search.** | Blizzard's window may already have a search box; a local filter avoids Blizzard's own restricted search call. | Does the current window have search? |
| #324 | **Friends list: preserve a list of friends' alts.** | The game shows only characters that are online now, so the list starts empty and only grows by observation. Third-party character names are stored: local only, minimum data, forget and clear controls, out of export by default. | Friends' alts or the user's own; empty history acceptable; export policy. |
| #325 | **Stat calculator and spell info panel.** What-if input (add N rating of a stat, or equip an item), current versus projected derived stats, two-item side-by-side compare, spell book view. | No API recomputes spell numbers for hypothetical stats; a coefficient table would have to come from a named database (allowed, see the standing rules) and be kept current each patch. The derived-stats layer and a measured spell ratio now exist in the Character Toolkit (RM-CHAR). Proposed v1 is derived stats only, then item compare, then a spell list with current text. Stat reads are secret under restrictions, so out of combat only. Item stat tables may omit gems, enchants, set bonuses, and trinket effects. | Is a derived-stats v1 acceptable; are recomputed spell numbers required and from what licensable source; input order; gem and enchant note. |

Earlier ideas folded into these: "report anticipated stat values" and "item level on tooltips" (stat panel, tooltip modifiers) and "friends list colors, sorted by who can provide what" (the second half needs a class-utility data source and is not part of this request).

### Tester request set (#278, filed 2026-11-02; status checked 2026-11-03 against 0.6.0)

Seven requests from one tester, resubmitted by Xaya on 2026-11-03. One issue (#278) holds all seven; the detail is in the project document `XAYAUI-TESTER-REQUESTS-278-STATUS-2026-11-03`. Nothing new was built for this entry. Two in-game probes come before any new trigger: `/xui loc` while affected by each effect, and a check of whether a target's or focus's cast data is readable in open world, dungeon, raid, and Mythic+.

| # | Request | Status | Weakest point and open question |
|---|---|---|---|
| 1 | Sound and texture cues from remaining buff duration | Partly built (0.5.98, #314); unverified in game | In combat the real numbers are secret, so the engine uses an estimate that can be wrong on refreshes and extensions. Open duration defects: #301, #306, #311. Has the tester re-tested? |
| 2 | Triggers that call a buff "unknown" | Candidate | Unclear meaning: fire on UNKNOWN, show "?" for a hidden value, or show UNKNOWN on headers (#193). Firing on unknown goes against the rule that a rule never fires on a guess, so it would be an explicit choice. |
| 3 | More preloaded textures | Candidate | "More" has no target. Options: more Blizzard art by ID (no new license) or a bundled CC0 pack (needs approval and a `THIRD_PARTY.md` entry). Currently 85 entries. |
| 4 | Cue volume that does not change game audio | Candidate, partial route | The game has a per-sound volume argument for sound kits only; file sounds have none. Speech already has its own volume. Today's slider changes the game's channel volume, which is what the tester objects to. The window would have to say which sources the slider covers. |
| 5 | Track stunned, charmed, feared, asleep (each individually) | Partly built (you only; grouped) | Xaya (2026-11-03): asleep looks like its own effect type but shares a diminishing return with fear. The game's 12.1.5 diminishing-return categories have no separate Fear or Sleep (Root, Taunt, Stun, AoE knockback, Incapacitate, Disorient, Silence, Disarm), so diminishing returns cannot tell sleep from fear. Whether the loss-of-control type separates them is not documented; probe `/xui loc` under a sleep effect. Target and focus reads are secret under restriction. |
| 6 | Track slowed (snared) and rooted (each individually) | Partly built (root only) | Xaya (2026-11-03): a snare is a slow, so this is two effects, not three. No documented source for slows in the loss-of-control data; the speed read is secret under stats restrictions. |
| 7 | Trigger when target or focus casts an interruptible spell | Candidate | The interruptible flag is secret when the game restricts cast data. A sound or speech cue cannot read a secret value; a visual can still be driven from it. Raids and Mythic+ are the likely blocked cases. |

Open questions: 7, listed in the project document (section 6) and in the #278 comment.

## 10. Waiting on a decision

These are logged and need an answer before work starts: #79, #80, #81, #82 (gated panes); #87 (backup); #88 (recycle bin); #90 (what happens when a Specialization or Role is unticked); #108 (skeleton rules); #115 and #117 (engine per-frame step, periodic snapshot); #123 (options refactor); #126 (gradient cursor trail); #151 (loaded-rule safeguard); #188 (rule build assistant); the five new candidates (#321 to #325); and the seven tester requests in #278 (meaning of item 2, scope and design of items 5 to 7, volume and texture approach).

## 11. Parked or dropped

| Item | Why |
|---|---|
| Cursor tracker, at-cursor reminders, stat text boxes, buff bars ("QoL Elements") | Switched off and kept out of the repository for now (#103). Return is a deliberate step. |
| "Update available" between players | Addons have no internet access; low value for a personal addon. Only the schema and dependency drift readings of version checking are planned. |
| A free-form node canvas for the combinations builder | The options library has no canvas widget; a row-based AND / OR builder comes first. |
| A global tooltip toggle | Replaced by a per-rule (now per-cue) option; default OFF. |
| Numeric charge or stack thresholds in combat | Those values are secret in restricted content; compares are hard errors in addon code. |
| Recomputed spell numbers for hypothetical stats | No API. Would need a coefficient table from a named database (allowed since 2026-11-04) kept current each patch; the Character Toolkit shows today's measured ratio and a typed-in coefficient instead. |
| Auto-changing the loot specialization without a prompt | Changes a real setting silently; combat and instance behavior of the call is unverified. |
| Theme class overrides redesign (#215) | Parked. |
| Third-party-derived data and wording | Removed (#290). |

## 12. Proposed order

This is my suggestion, not a commitment.
1. **Verify what already shipped.** An in-game pass over the chat panel (0.5.94), the combat engine and duration engine (0.5.87 to 0.5.98), the game menu skin (0.5.96), and the Cues, Conditions, and Actions rebuild. Several later features stack on these.
2. **#268 (9-point anchors)**, which is marked high priority, and the engine review (#309).
3. **M1 (data model and migration)**, because the type split, combinations, and folder force all wait on it.
4. **M2b, M3, M4**, then **M5** and **M6a to M6d**.
5. **Decisions on the waiting list**, starting with the ones that gate small, self-contained features (backup, recycle bin).
6. **New candidates**, each starting with a short in-game probe of the API behavior it depends on (loot-specialization and item-spec calls, friend account fields, the rating converter and item stat tables).

## 13. Where the detail lives

New chats start from `SESSION-START-SUMMARY.md` (rules, active items, pending actions, how to work here). This file stays the full tracker; `debug-log/` is the history.

This file is the summary. Detailed specs, stress tests, and decision graphs for individual items are kept in the project's Claude documents and the shared Drive `Feature sketches` folder, which are outside this repository. Each item's issue (or, for the 2026-11-03 candidates, its drafted issue text) carries the open questions.
