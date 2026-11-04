# Dynamic groups: Sort (Default, Expiration, Name, Important, Manual) and rule order in combat (XayaUI core 0.6.6, XayaUI_Options 0.6.5; fork: main)
Logged 2026-11-04 04:40 UTC. Branch `claude/eloquent-rubin-n9zb99`. Nothing here has run in the game yet.

## Requests behind this change
Xaya, 2026-11-04:
- "I want auras that appear to be shown in the order I set them in within a dynamic organized group. if immolation aura appears, I want it to be displayed in between other running auras."
- "add to the addons own table names that are dynamically given numbers in a group to have them appear in a sorted order".
- "make sure to provide a sort order option for rules in a dynamic group: default, expiration, name, important, manual (organize the group and force-save with a reload)".

Triage group C found the cause: every engine-drawn member of a dynamic group went into ONE aura group of ONE container. That group was sorted by `AuraContainerSortMethod.Default`, which is roughly game order, and every member was drawn at member 1's size and style. Her Active Mitigation group showed exactly that.

## How it works (Blizzard 12.1.5 source, verified)
- An aura group's layout options take `layoutIndex` (`CustomAuraContainerGroupLayoutDefaultOptions`). Groups are ordered by it (`GetEffectiveFlowLayoutIndex`, `SortFlowLayoutDescriptions`). The flow skips empty groups (AnchorUtil.lua: "Empty groups do not contribute spacing or force a new line").
- Each group has its own sort method: Default, Expiration, Name and ImportantOnly comparators (`AuraContainerUtil.GetAuraSortComparator`), and Normal or Reverse direction.
- Groups are add-only, with no remove. `SetAuraGroupEnabled` switches a group off and refreshes the container itself, through `UpdateAllAuras`.
- A hidden container unregisters its aura events (`ShouldRegisterForDynamicEvents` = `IsVisible() and IsEnabled()`). `OnShow` refreshes it.

## What changed
- **Manual** (default) works as Xaya proposed.
  - XayaUI's table of numbers is the group's rule order. Each member gets its own aura group holding only its own aura IDs, with `layoutIndex` = its number, its own size and look, and at most 1 icon.
  - In combat the game draws the members that are up in that order, with no gaps.
  - **Reverse** numbers from the last rule.
- **Default / Expiration / Name / Important** use one shared aura group with Blizzard's comparator; Reverse uses Blizzard's Reverse direction.
- **One container per group for the session** (`EnsureGroup`):
  - groups are keyed by rule uid + look;
  - a reorder only renumbers;
  - a look change gives that member a new group and switches its old one off;
  - switching between sorts turns groups on and off.
  - No container is replaced, so no hidden buttons pile up.
  - A sanity check against EllesmereUI's notes (API facts only, no code copied) pointed out that groups are add-only and containers are not swapped. The first version of this change did replace containers, and was reworked before commit.
- Load and talent answers per member switch that member's own group (`SetAuraGroupEnabled`). Game sorts filter the shared group as before.
- Group membership comes from the PARENT rule's group. `ns.SyncCueFolders` (Cues.lua) refreshes each cue's copy before XayaUI lays groups out (`RefreshAllVisuals`) and before the engine builds. Before this, a moved rule's cues kept the old group until the settings tree was rebuilt (triage C-L2).
- `ns.GroupSortOf` (Visual.lua) is the one definition. The engine has the same mapping as a fallback, so a setting is never silently ignored.
- XayaUI's own layout (preview, unlocked, displays the engine does not draw) follows the same Sort, using what XayaUI can read:
  - Name: the rule's name.
  - Important: `C_Spell.IsSpellImportant`.
  - Default: `C_Spell.IsPriorityAura`.
  - Expiration: the rule's own time left, soonest first.
- Settings (group, Group tab): **Sort** (5 values), **Reverse**, and **Save order and reload** (Manual only).
- Older saves: "Rule order" = Manual, "Name, A to Z" = Name, "Name, Z to A" = Name reversed.
- `/xuiengine` names the sort. The "different sizes" note now appears only for game sorts.

## Checks
- `tests/aura_display_run.py`: the dynamic-group checks were rewritten for Manual, and new checks added (all pass). They cover:
  - per-member groups with only their own IDs, numbers 1..3, `groupSpacing`;
  - a member that is not loaded switches only its own group; no switching when nothing changed;
  - each game sort with its comparator, and Reverse;
  - old "asc" / "desc" saves;
  - back to Manual reuses the same groups and container;
  - each member keeps its own size;
  - a look change makes one new group and reverts to the old one;
  - reordering only renumbers (same groups, same container).
- The stand-in container now checks `layoutIndex`, `groupSpacing` and `SetAuraGroupEnabled` the way Blizzard validates them.
- `tests/layout_parity_run.py` passes (it first caught `LookKey` being defined below its first use; fixed).
- Full suite and whole-addon harness: see the commit.

Docs: USER-GUIDE ("Sorting a dynamic group"), QA-CHECKLIST B20 and B21.
Files: XayaUI/Combat/AuraDisplay.lua, XayaUI/Visual.lua, XayaUI/Cues.lua, XayaUI_Options/Options.lua, XayaUI_Options/XayaUI_Options.toc (0.6.5), tests/aura_display_run.py, USER-GUIDE.md, QA-CHECKLIST.md, this entry, MANIFEST.md5.

## Not in this change
- Mixed groups, where some members are not engine-drawn (cooldowns, "missing" icons). XayaUI still lays those out itself. The chained-segment design (aura flow segments around XayaUI's own items, with item frames made with `DisableUntrustedLayoutScriptsTemplate`) comes next.
- The group display options from Xaya's screenshots (borders, shapes, swipe, tooltips, right-click cancel, pandemic glow, keybinds, and so on). They are recorded in the aura plan and come next.
