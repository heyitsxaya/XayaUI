# Platform split: design (2026-11-07)

Status: **DESIGN, not approved.** No code moves until Xaya approves this file (open questions in section 9).
Written by session_014bN6tWwZM5hKvbZkMFd4zN on branch `claude/lucid-mayer-pv4ytn`, against main `b777793`.
Every count below was measured on `b777793`; how each was taken is in section 11.

## 1. The decision in one paragraph

XayaUI becomes a **Platform** (the foundation every addon runs on) plus modules on top of it. The rule and aura tracking that the
`XayaUI` folder holds today becomes its own module, **Core**. Every module keeps its own settings, registers what it shares, what it
puts in a profile and what goes in the Recycle Bin, and can be switched off without touching anyone else. A player who never makes a
rule turns Core off, and none of its files load.

## 2. Xaya's decisions (her words, 2026-11-07)

| Id | Her words | What it settles |
|---|---|---|
| PS-1 | "We don't have to use the name "core" for the platform functionality. We can leave the original "core functionality" of the addon — trigger, cue, etc tracking — as core and create "platform" as the foundational layer upon which everything — including "core" runs." | Names: Platform and Core (section 3) |
| PS-2 | "Re: game menu — change the name to include the name "button" like the minimap" | `GameMenu.lua` becomes `GameMenuButton.lua`, Platform (section 4) |
| PS-3 | "Minimap button is part of core / Share is part of core / User media, user sounds, debugging, error handling also part of core" ("core" here = the platform, per PS-1) | Those files are Platform (section 4) |
| PS-4 | "Recycle Bin can be moved to XayaUI "core" and not "rule tracking," because it houses more than one type of file delete" | Recycle Bin is a Platform service with registered kinds (section 6.3) |
| PS-5 | "Options technically essential to core operating as a platform — part of core?" | Options is Platform, kept as its own load-on-demand folder (section 7) |
| PS-6 | "Does sharer / import / export have "universal plumbing" configured for each model to tie into? If not, it should — it should support sharing across all modules a user has installed." | Profile parts are registered by each module (section 6.1) |
| PS-7 | "I imagine we want individual modules to hold their own settings, correct?" | Each module gets its own saved variables, migrated in stages (section 5) |
| PS-8 | "Yes, I think we need to prioritize this." | The split goes first; see the freeze in section 8 |

## 3. Names and folders

| Folder | Title in the AddOns list | What it is |
|---|---|---|
| `XayaUI` | XayaUI Platform | The foundation: namespace, module contract, settings stores, theme, share codec, Recycle Bin, profiles, sounds and media lists, console, debug record and error handling, minimap button, game menu button |
| `XayaUI_Core` (new) | XayaUI Core | Rule and aura tracking: rules, groups, triggers, conditions, cues, outcomes, actions, the engine, combat aura tracking, visuals, bars |
| `XayaUI_Options` | XayaUI Options | The settings window, still load-on-demand (section 7) |
| `XayaUI_Chat`, `_QoL`, `_Bonus`, `_Reskin`, `_Nameplates`, `_DevAssist`, `_Media` | unchanged | Modules on the Platform |

**Why the Platform keeps the folder name `XayaUI`:** WoW keeps an addon's saved variables under the name of the folder that declares
them, and `CueRulesDB` (today: the 313 rules and every module's settings) is declared by `XayaUI`. Keeping the folder name means no
data is lost on the day of the split, and every module's `## Dependencies: XayaUI` line stays correct. The reverse (a new
`XayaUI_Platform` folder) would leave all settings attached to tracking: switching Core off would cut every module off from its data.
This storage rule is general WoW knowledge, not checked against `docs/reference/` in this session; the first worker confirms it there.

Older docs and version notes say "core 0.6.x" for today's `XayaUI` folder (platform and tracking together). From the split on,
"Core" means the tracking module only.

## 4. Where every file of today's `XayaUI` folder goes

Sorted by each file's own header comment and by who calls it. Lines are today's.

**Platform (stays in `XayaUI`): 13 files plus the split-off half of Core.lua**

| File | Lines | Note |
|---|---|---|
| Core.lua (platform half) | part of 1,064 | namespace, saved-variable setup, error routing, flat button helper, slash command plumbing (section 4.1) |
| Modules.lua | 593 | the module contract; grows in section 6 |
| Theme.lua | 680 | |
| Share.lua (codec half) | part of 603 | codec, JSON, theme kind; the rules kind moves to Core (section 6.2) |
| RecycleBin.lua (bin half) | part of 507 | storage, keep-times, restore plumbing; the rule kinds move to Core (section 6.3) |
| Sound.lua | 208 | also used by Chat (`XayaUI_Chat/Sounds.lua`) |
| LocalSounds.lua, LocalGraphics.lua, UserMedia.lua | 270, 155, 87 | see risk R7 for LocalSounds |
| Console.lua | 404 | one `ns.rules` read (moves behind a Core service) |
| DebugRecord.lua | 465 | |
| Compat.lua | 125 | |
| MinimapButton.lua | 316 | rows come from `ns.RegisterLauncher` already |
| GameMenu.lua → **GameMenuButton.lua** | 363 | an entry point, not a reskin: its header says it "NEVER edits a pooled button's art" (PS-2) |
| Libs/LibStub | 150 | the 4 unused LibStub self-test files are a separate decision already with Xaya |

**Core (moves to `XayaUI_Core`): 23 files, 14,372 lines in total today**

Engine.lua, Conditions.lua, Triggers.lua, Outcomes.lua, Actions.lua, Cues.lua, Timing.lua, Visual.lua, BarCue.lua, ProcGlows.lua,
SetBonusAuras.lua, TextureList.lua, ClassLearn.lua, TalentDump.lua, AuraAlias.lua, AuraList.lua, AuraSound.lua, AuraSources.lua,
Combat/AuraModel.lua, Combat/AuraTracker.lua, Combat/AuraSetup.lua, Combat/AuraDisplay.lua, plus the rule halves of RecycleBin.lua
and Share.lua and the rule half of Core.lua.

TalentDump keeps its own saved variable `XayaUITalentDB`; it is declared by the `XayaUI` folder today, so it moves to the Core toc.
Its contents are a scan of the game's talent trees, rebuilt by the scan; INFERENCE from its header: losing the old copy only costs a
re-scan. The first worker confirms that before moving it.

### 4.1 Core.lua is mixed and has to be cut

Its header: "namespace, saved variables, rule defaults, slash commands". Today it reads `ns.folders` 19 times, `ns.rules` 11 times and
`ns.RuleKind` 3 times. Platform keeps the namespace, saved-variable setup, error routing, the flat button helper and the slash command
table. Core takes: rule defaults and the rule shape upgrade, buff bar defaults, group ids and sources, the engine's step index, folder
load overrides, the default categories, the folder-enforced sound channel, and the QoL "stats text" box defaults (those go to QoL).

### 4.2 Character pane: split across three modules (Q5)

Today all of it is QoL: CharacterModel.lua (3,573 lines, the stat model), CharacterToolkit.lua (2,799: the docked panel with Stats /
Gear / Ability Scaling tabs, slot overlays, extra stat tooltip lines), CharacterReskin.lua (1,505: the character window in XayaUI's
look) and StatMath.lua (225: rating math, including diminishing-returns thresholds). Her split, mapped to that code (the mapping is an
INFERENCE from the file headers; the worker on this area confirms it piece by piece):

| Her piece | Module | Today's code (inferred) |
|---|---|---|
| Advanced Character Stats pane window | Bonus | CharacterToolkit's docked panel and tabs |
| Diminishing returns | Bonus or QoL (her pick; proposed Bonus) | StatMath's threshold math and where the panel shows it |
| Simple character / dressing room UI with a customizable stat display | QoL | the slot overlays and stat display options in CharacterToolkit / CharacterReskin |
| Clean reskin as the visual base | Reskin | the look half of CharacterReskin.lua |

CharacterModel.lua is used by every piece; it stays one model, offered as the existing `statModel` service by the module that owns
the base stat display (QoL), and read by Bonus through the service. This is its own phase-sized job (about 8,100 lines across three
addons), scheduled after P4 so it is done on the new layout once.

## 5. Settings: every module keeps its own

Today QoL, Chat, Bonus and Reskin have no saved variables of their own: their settings are keys of `CueRulesDB`. There are 490 direct
`CueRulesDB` references (core 200, Options 126, DevAssist 81, QoL 32, Reskin 23, Bonus 19, Chat 9) and 40+ top-level keys.
Nameplates already has its own (`XayaUINameplatesDB`, 0 references to `CueRulesDB`): the pattern works here.

Target owners (INFERENCE from key names; the seam step confirms each against the code):

| Store (new saved variable) | Keys moving into it |
|---|---|
| Platform (`CueRulesDB`, kept) | theme, themes, ui, minimap, profiles, recycleBin, errorLog, errors, lastBugReport, debugRecord, version |
| Core (`XayaUICoreDB`) | rules, folders, bars, barGroup, drafts, moverDraft, auraAlias, auraModel, auraSources, auraTracker, classLearn, learnedAuraDur, learnedAuraStacks, procGlowSeen |
| QoL (`XayaUIQoLDB`) | qol, cursor, cursorHighlight, cursorTrail, characterToolkit, characterReskin, shoppingList, releaseGuard |
| Chat (`XayaUIChatDB`) | chat, chat2 |
| Bonus (`XayaUIBonusDB`) | dataPanels, tooltips, calculator, notepad |
| Reskin (`XayaUIReskinDB`) | reskinTabOff |
| DevAssist (`XayaUIDevAssistDB`) | perfLog, idProbeStream, chatProbe |

Open: whether `characterReskin` belongs to QoL (where the file is) or Reskin; Profiles currently files it under "Blizzard Reskin".

**Order (the code move and the data move never ship in the same step):**

1. **Seam.** `ns.Settings(module)` returns that module's settings table. At first it returns the module's keys inside `CueRulesDB`,
   so nothing moves and nothing a player sees changes. All 490 references go through it, one area at a time. A test fails on any
   direct `CueRulesDB` use outside Platform.
2. **One module at a time, copy, never move.** On first load, when the module's own store is empty and its old keys exist, copy them
   across and record the version they came from. The old keys stay untouched for two releases, so going back to an older build loses
   nothing. Smallest first: Reskin, then Chat, Bonus, QoL, DevAssist.
3. **Rules last.** Before the copy: make a backup string with the existing Backup feature. After it: count rules and groups on both
   sides; on any difference, keep reading the old store and report it. The old copy stays until Xaya confirms in game.
4. **Clean-up** of the old keys only after Xaya's in-game confirmation for that module. Each migration has a walkthrough whose check
   compares the old and new values, so she only clicks Accept.

## 6. Platform services every module plugs into

All go in `Modules.lua` next to today's `RegisterSettingsPage`, `RegisterCommand`, `RegisterLauncher` and `RegisterReskin`. Each
call is wrapped in pcall, as today, so one module's error never stops another.

### 6.1 Profile parts (PS-6)

Today `XayaUI_Options/Profiles.lua` has a fixed list, `P.COMPONENTS`, naming every module's keys by hand. What that costs now:
Nameplates cannot be exported at all, Chat's `chat` / `chat2` sit under "Blizzard Reskin", and every new module is invisible to
Profiles until someone edits the list.

New: `ns.RegisterProfilePart{ key, label, module, snapshot(), apply(data, mode), never = {...}, version }`.

- Profiles lists the parts of the modules that are installed and switched on.
- A pasted profile keeps parts for modules this player does not have; Import shows them as "needs XayaUI Chat" and skips them.
- Each part carries its own format version, like share kinds already do.
- Personal data stays out, as today: Notepad text, the Shopping List, learned aura data, backups, drafts, logs.
- Core registers "Rules and groups"; Nameplates registers its own part (fixes today's gap).

### 6.2 Share kinds

`Share.RegisterKind` already exists and already is the universal codec (rules `XUI1`, theme `XUITHEME1`, profile `XUIPROFILE1`).
Change: the rules kind (and its "wait until combat ends" step) moves from Share.lua to Core and registers itself. No string format
changes, so every string shared before the split still imports.

### 6.3 Recycle Bin kinds (PS-4)

Today the bin only holds rule items: rules, groups, and the cues, conditions and triggers removed in the rule editor ("Drafts and
backups do not go here"). New: `ns.RegisterBinKind{ kind, label, describe(item), restore(item) }`. Core registers its five rule
kinds; the bin's storage, keep-times and page stay in Platform. Any module can register later (Notepad pages, shopping lists) without
the bin knowing about it.

### 6.4 Services between modules

Bonus is the only feature addon that reads tracking code today: `ns.AuraSources` and `ns.AuraModel` (enhanced tooltips, INFERENCE
from the names). Core offers them through the existing service registry (`ns.Provide` / `ns.Service`); Bonus asks for them and
shows nothing extra when Core is off. QoL, Chat, Reskin and Nameplates reference no tracking code (direct references checked; lookups
by string at runtime were not).

### 6.5 Engine with zero rules

Today `Engine.lua` registers its events unconditionally (lines 404-405, including the player's aura updates) and sets a per-frame
OnUpdate (line 448). Not checked: whether that handler returns early with zero rules. After the split a player who never uses rules
switches Core off; separately, Core should register nothing until it has one active rule (rule V14).

## 7. Options

Options stays its own folder. Its toc says it "Loads the first time you open it ... so it costs nothing until then"
(`## LoadOnDemand: 1`); folding it into `XayaUI` would make every player load it at login.

- **Platform part:** the window, top tabs, shared helpers (`ns.OptionsApi`), Skin.lua, Profiles.lua, ImportWindow.lua, InfoPane,
  AddonInfo.lua, ThemeEditor.lua, the Ace libraries.
- **Feature pages already live in their own modules.** 25 pages are registered with `ns.RegisterSettingsPage` from the feature
  addons themselves: Reskin 13 (including GameMenuSkin.lua), QoL 5, Bonus 3, Chat 2, DevAssist 2, Nameplates 1. None of those addons
  is load-on-demand, so their page code is already read at login; only the page tables are built when the window opens. That is the
  established pattern, and the split keeps it. (An earlier draft of this section proposed moving pages into
  `XayaUI_Options/Pages/<Module>.lua`; that contradicted the pattern and is withdrawn.)
- **Core's editor is the exception today:** TriggersEditor.lua, OutcomesEditor.lua, DisplayTab.lua, RuleSearch.lua,
  AutoPicker.lua, Drafts.lua (INFERENCE from its name) and the rules-tree part of the 9,033-line Options.lua (291 top-level functions,
  touched by 42 of 190 code commits since 11-01) live inside Options. Q1 decides where they go.
- **What else is left in Options.lua** after the rule editor leaves (QoL is named there 69 times) is checked in P3: page code moves
  to its module; window plumbing stays.

## 8. Freeze while the split runs (PS-8)

Testing everything now and again after the split is double work, and every branch open during the move conflicts with it.

- **No new features** until the split lands.
- **Fast-lane fixes only** for bugs that block Xaya's play: one addon, about 20 lines or fewer.
- **Baseline before the move:** about 10 walkthroughs on main `b777793` covering the core paths (list to agree, Q3), so a bug found
  after the split can be told apart from one that was already there.
- **Questions:** only the ones that shape the split are answered now (section 9, and D8-Q1).
- **D8** (held, 28 files, touches the engine) is either released before the move or rebased after it (Q4).
- The freeze is reviewed once phase P2 has a measured pace; if the split is going to take weeks, it is reconsidered.

### 8.1 Baseline walkthroughs (picked 2026-11-07, run once on main before P1)

Chosen to touch every part the split moves, all runnable solo outside a group (no step asks for a group, instance or the Auction
House; checked by searching each walkthrough's steps). Open each from `/xui dev qa` > All walkthroughs.

| # | Walkthrough id | What it covers in the split |
|---|---|---|
| 1 | settings-toplevel | Settings window top tabs and Profiles (Options platform part, profile parts) |
| 2 | perf-settings-click (J31) | Settings click speed: the number to compare after Options.lua is cut |
| 3 | audit-engine | Engine: hidden-buff estimate, glow on delete, errors in the report (rule module, error handling) |
| 4 | audit-opt-bin | Red X to the Recycle Bin (bin kinds) |
| 5 | audit-backup-replace | Backups: Load (replace) (the backup the rules migration relies on) |
| 6 | bars-cues | Bar cues (engine plus visuals) |
| 7 | chat-improved-split | Chat Panel and Improved Chat on and off apart (modules switch independently) |
| 8 | reskin-switches | All reskins and each reskin's tick box (Reskin module) |
| 9 | audit-shopping-list | Shopping List per-character settings (QoL saved data) |
| 10 | statcalc-rows | Stat Calculator rows (the character pane that splits across Bonus / QoL / Reskin) |

Friends who test (2026-11-07): the same freeze applies. They skip the backlog; if they want to help now, they run these same 10 on
their own characters, since a different class and setup catches what one setup misses.

## 9. Open questions for Xaya

| Q | Question | Recommendation |
|---|---|---|
| Q1 | Where does the rule editor go? Every other module already owns its pages (section 7). | **Rule module owns it, in its own load-on-demand folder** (e.g. `XayaUI_Rules_Options`) that the settings window loads when it opens and the rule module is on. Same ownership as every other module, and the biggest editor still costs nothing until opened. Her answer (2026-11-07): asked where the other pages live; this row now answers that |
| Q2 | Name for the tracking module. Her answer (2026-11-07): "XayaUI" (platform) and "XayaUI Core" — "unless you think that the core should be renamed in this process to more directly account for its functionality and purpose." | **Proposed: "XayaUI Rules", folder `XayaUI_Rules`**: it matches the Rules tab players already use, and switching off something named "Core" reads as breaking the addon. Waits for her pick |
| Q3 | Baseline check: before any code moves, she runs about 10 walkthroughs on today's main once, so a bug found after the split can be told apart from one that was already there. Her answer: "unsure what this refers to" (explained 2026-11-07) | A worker picks the 10 and sends them as one list; she only runs them |
| Q4 | D8 in plain terms: should Release Guard switch itself on automatically in raids with 20 or more players? It is built and passes the suite, untested in game, held by her O-109. Her answer: "unsure ... I'm thinking top down, not bottom-up" (re-asked top-down 2026-11-07) | If yes: land it before the move and put its walkthrough in the baseline. If no or not now: park it; it is redone on the new layout later |
| Q5 | Character pane. Her answer (2026-11-07, verbatim): "The Advanced Character Stats pane window is a Bonus feature; a diminishing returns element is a either a bonus feature or a qol feature; the simple character/dressing room UI with the ability to customize stat display overhaul is a qol feature; and just a simple clean ui reskin that serves as the visual base is the reskin" | Settled except diminishing returns; section 4.2. Proposed: diminishing returns goes to Bonus, with the advanced stats it explains; waits for her pick |
| Q6 | Freeze. Her answer (2026-11-07): "a freeze sounds fine — do you want this to include even my going through the qa walk throughs?" | **Approved.** Yes, it includes the 148-walkthrough backlog: she runs only the baseline (Q3) and anything that blocks her own play |

## 10. Phases

Each phase lands on main as one complete step and passes the full suite, the Lua pitfall check and precheck on its exact commit.
Phases marked "in game" add walkthroughs and wait for Xaya's Accept before the next one starts.

| Phase | What | Moves data? | In game |
|---|---|---|---|
| P0 | Freeze, baseline walkthroughs on `b777793`, answers to Q1-Q6 | no | yes (baseline) |
| P1 | Platform services: `RegisterProfilePart`, `RegisterBinKind`, Core-side services for Bonus; Profiles reads registered parts | no | yes |
| P2 | Settings seam: `ns.Settings(module)`, all 490 references, the "no direct CueRulesDB" test | no | regression only |
| P3 | Options pages cut into `Pages/<Module>.lua` | no | regression only |
| P4 | Code move: `XayaUI_Core` folder, the 23 files, Core.lua / Share.lua / RecycleBin.lua cut, `GameMenuButton.lua`, test and tool paths (16 files name tracking files, 58 name platform files) | no | yes (full regression) |
| P5 | Settings migration, one module per step, rules last (section 5) | yes, copy only | yes, per module |
| P6 | Remove old `CueRulesDB` keys, module by module, after her confirmation | yes | yes |

No time estimate yet: P2 is the first phase large enough to measure the pace on.

## 11. Risks

| Id | Risk | Guard |
|---|---|---|
| R1 | A migration loses or changes saved data, worst case the rules | Copy, never move; counts compared; backup string first; old keys kept two releases |
| R2 | A bug after the move cannot be told apart from an old one | Baseline walkthroughs on `b777793` (P0) |
| R3 | Load order: a module reaches Platform or Core before they are ready | `ns.WhenReady` and services only; the existing static cross-addon check extended to the new folder |
| R4 | Branches open during P4 conflict with every moved file | Freeze; only fast-lane fixes; one session runs P4 while no area worker is active |
| R5 | Area ownership guessed from file names is wrong (Drafts.lua, key owners) | The seam step (P2) confirms every key and file against the code |
| R6 | Old share strings stop importing | String formats do not change; a test imports a pre-split string of each kind |
| R7 | `LocalSounds.lua` says some sounds were "copied from the BigWigs addon" with their license files; the standing rules forbid copying assets from other addons. Precheck already warns that 229 listed sound files and 149 graphics are not in the repository | Already tracked as issues #333 / #290; settle them before the media lists move into Platform |
| R8 | The 9,033-line Options.lua cut breaks a settings page | P3 lands alone and gets a regression pass; pages compared before and after by the existing Options tests |

## 12. Alternatives considered

| Considered | Decision | Why |
|---|---|---|
| Keep every module's settings in `CueRulesDB` | Rejected (PS-7) | One store means one bad write can damage everything; Platform would know every module's keys; Nameplates shows the separate pattern works |
| New `XayaUI_Platform` folder, `XayaUI` stays tracking | Rejected | Saved variables follow the folder name: all settings would stay attached to tracking |
| Fold Options into `XayaUI` | Rejected | Loses load-on-demand: every player pays for the settings window at login |
| Move every feature page into Options (`Pages/<Module>.lua`) | Withdrawn | 25 pages already live in their own modules; that is the established pattern (section 7) |
| Move code and data in one release | Rejected | A failure could not be traced to either change, and the rules are in that data |
| Test the 148-walkthrough backlog first, split later | Rejected (PS-8) | Most of that testing would have to be repeated after the move |
| Folder-per-session context with no area split inside `XayaUI` | Superseded | The split itself makes Platform and Core separate areas |

## 13. How the counts were taken (main `b777793`)

- Lines: `git show origin/main:<file> | wc -l`, per file; tracking total 14,372 + platform 5,333 + LibStub 150 = 19,855 lines of Lua
  in `XayaUI`.
- File roles: each file's header comment, and `git grep` for tracking names (`ns.rules`, `ns.folders`, `ns.Engine`, `ns.Aura*`, ...)
  in each platform file and in each feature addon.
- 490 = `git grep -oh 'CueRulesDB'` per addon folder (200 + 126 + 81 + 32 + 23 + 19 + 9).
- Options.lua: 9,033 lines, 291 lines starting `function` / `local function`; 42 of 190 non-merge code commits since 2026-11-01
  touch it.
- Test paths: `git grep -l` in `tests/` and `tools/` for `XayaUI/<tracking file>` (16) and `XayaUI/(Core|Modules|Theme|Share|Console).lua` (58).
