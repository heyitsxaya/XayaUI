# Memory report: what XayaUI holds after login (2026-11-11)

Request: REQUEST-LOG A23 SD-38 (the memory step joins the V27 gate before bundle 1 lands: "measure what each file and saved table holds
after login; shrink what is not needed; a memory budget in the gate; her saved data (rules, backups, drafts) is not removed without
asking") and SD-41 (her answer on the memory budget: "Measure first, then set (Recommended)").

Status: measured and proposed. Nothing is cut and no budget is enforced yet. Every cut below that would remove or shorten her saved data
is marked **NEEDS HER OK**; the budget numbers are proposals for her to set (V16, V19: through the question flow).

Reproduce: `python3 tests/memory_report_run.py` (about 30 s; prints every number in this report and ends with `FAILS: 0`; it fails only if
it cannot measure). `--json PATH` writes every number, every holder included. `--saved DIR` also measures her own saved files (see
"Checking against her real files" below).

## How it was measured, and what the numbers are not

* The stand-in game (tests/harness/world.lua and loader.lua) runs the real addon files in Lua 5.1 (lupa), the way the game loads them:
  each addon's files in .toc order, then its saved variables, then ADDON_LOADED, then the login events and 12 seconds of play out of
  combat. XayaUI (Platform) and XayaUI Rules are loaded; XayaUI Options is not (it loads on demand, as at login), and is measured
  separately below.
* Every number is an **estimate, not a game number**. The game runs a modified 64-bit Lua 5.1, so code, tables and strings cost about
  what they cost here (INFERENCE: Blizzard does not publish its allocator). Three known differences:
  1. The stand-in keeps every frame's points, scripts and children in Lua tables. The game keeps them in C, outside an addon's memory
     (INFERENCE from how GetAddOnMemoryUsage behaves). These stand-in records are measured and taken out of every number here (8.8 MB
     for the realistic profile's 5,237 frame objects).
  2. The game's AddOns list shows memory that includes garbage not yet collected; every number here is after a full collection.
  3. Which addon the game books memory to: the game counts what an addon's code allocates and what its saved variables hold to that
     addon (INFERENCE: this is how large saved files show up as addon memory; not documented in docs/reference/api/). So CueRulesDB is
     booked to XayaUI Platform, XayaUIRulesDB and XayaUITalentDB to XayaUI Rules, and the rule editor's work while the window is open
     to XayaUI Rules (its code), not to XayaUI Options.
* Methods: (a) per file, collectgarbage around `loadstring` (compiled code) and around running it (what it keeps); (c) per saved part,
  collectgarbage around loading it from its saved text (exact for Lua 5.1); (b) and (d) by walking every table, string and closure each
  holder reaches (64 B a table, 16 B an array slot, 40 B a hash slot, 37 B plus its length a string, 40 B plus 8 B an upvalue a
  closure; each object counted once, for the first holder that reaches it). Check: the walk plus the compiled code comes to 22.84 MB
  against the measured 23.50 MB (97%).
* Two runs give identical numbers. Measured on the working tree of 2026-11-11 (HEAD 9a03d68 with round-5 edits in progress); on HEAD
  itself the Platform's files hold 8 KB less (MouseTracker.lua is not in HEAD's .toc yet) and every other number is the same.
* **UNVERIFIED IN GAME.** Nothing here was measured in the game client.

### The two saved-data profiles

* **Fresh install:** nothing saved.
* **Realistic profile** (what a long-used install keeps, each part made the way the code makes it; how much of each her own files hold
  is not known here, INFERENCE): tests/gate_common.py's rule list (300 entries: 66 buff, 40 cooldown, 24 bar, 20 game-sound, 20 hover,
  16 debuff rules, 37 icon and 53 sound cues; 17 groups including static, dynamic and nested), saved by a logout; 3 rule backups
  (2 of hers and the "Rules before the settings move" backup that RuleShare.lua's migration guard makes); the old copy of the rules that
  the settings move left in CueRulesDB (XayaUI/Modules.lua section 0c: "copy, never move", "kept untouched until P6"); 20 deleted rules in
  the Recycle Bin; 30 drafts (the default "Keep up to"); a full error log (50 entries); the detailed debug record an earlier Dev Assist
  left in CueRulesDB (3,000 lines, its default); the last bug report text; a talent scan of every class (XayaUITalentDB, about 2,900 talent
  nodes, an estimate of Midnight's trees); learned aura and cooldown data for 4 specs.

## The short answer

| | Fresh install | Realistic profile | Her reading in game (SD-38) |
|---|---:|---:|---:|
| XayaUI Platform | 0.79 MB | 11.62 MB | 11 MB |
| XayaUI Rules | 2.97 MB | 11.88 MB | 12 MB |
| XayaUI Options (not loaded at login) | 0 | 0 (1.28 MB once /xui loads it) | 976 KB |

* With nothing saved, XayaUI holds about 3.8 MB at login, almost all of it code: Platform 0.79 MB (about one EllesmereUI module, 0.86 to
  0.97 MB), Rules 2.97 MB (about 1.5 times OPie's 2 MB; half of KiraUI-Plugin's 6 MB). Half of Rules' code (about 1.3 to 1.5 MB) is the
  rule editor, read at login because it is merged into Rules (her answer, SD-41: "Keep it merged").
* With the realistic profile the totals come close to her readings. About 16 of the 23.5 MB are copies of saved data: the 3 backups
  (7.8 MB, 2.6 MB each), the old copy of the rules left by the settings move (2.6 MB), and the talent scan (2.8 MB). The live rule list
  itself is 2.6 MB (8.8 KB per rule).
* That the totals match her readings suggests her files hold something like this profile, but it proves nothing about which parts:
  her own two saved files settle it (below).
* The largest cuts that lose nothing she uses all change her saved data, so each needs her OK: the old rules copy, the backup format,
  the talent scan's format or place, and two leftover texts.

## Totals at login, by part

The stand-in's frame records are taken out. "Its files" = the code and the tables the files build as the game reads them; "login" =
PLAYER_LOGIN, PLAYER_ENTERING_WORLD and the first 12 seconds out of combat.

| | Its files (compiled code) | Saved variables | ADDON_LOADED | Login | Total |
|---|---:|---:|---:|---:|---:|
| Platform, fresh | 0.79 MB (0.63 MB) | 0 | 1.9 KB | 3.0 KB | 0.79 MB |
| Rules, fresh | 2.93 MB (2.78 MB) | 0 | 3.6 KB | 37.6 KB | 2.97 MB |
| Platform, realistic | 0.79 MB (0.63 MB) | 10.83 MB | 0.4 KB | 2.0 KB | 11.62 MB |
| Rules, realistic | 2.92 MB (2.77 MB) | 5.92 MB | 1.49 MB | 1.54 MB | 11.88 MB |

Rules' ADDON_LOADED, realistic: it builds a display for each of the 203 rules that have one, whether or not the rule can show here:
4,396 frame objects (622 frames, 1,899 textures, 836 font strings, 203 cooldowns, 406 animation groups, 406 alpha animations,
24 status bars), with 0.56 MB of XayaUI's own fields and scripts on them. Login adds 693 more (68 aura containers for the combat engine,
111 buttons, 282 textures and others) and the engine's per-rule state (ns.runtime 437 KB, ns.AuraDisplay 209 KB, caches about 0.2 MB).
In the game the frame objects themselves live outside the addon's memory but are still game memory (INFERENCE).

## (a) Compiled code per file

Source size, compiled code (in load order, and alone in a Lua state of its own), and what the file keeps after it ran (its code plus the
tables it built). Fresh install; the files' numbers do not depend on the saved data. (1) Sidebar.lua's in-order number includes a
one-time growth of Lua's string table (about 220 KB) that all files share; its own code is about 240 KB.

| File | Source | Compiled (load order) | Compiled (alone) | Kept after it ran |
|---|---:|---:|---:|---:|
| XayaUI/Libs/LibStub/LibStub.lua | 1.3 KB | 2.7 KB | 2.6 KB | 3.4 KB |
| XayaUI/LocalSounds.lua | 27.0 KB | 49.9 KB | 55.9 KB | 64.3 KB |
| XayaUI/LocalGraphics.lua | 21.6 KB | 36.2 KB | 42.1 KB | 45.3 KB |
| XayaUI/UserMedia.lua | 4.2 KB | 6.2 KB | 9.3 KB | 7.6 KB |
| XayaUI/Core.lua | 33.1 KB | 47.5 KB | 56.7 KB | 51.7 KB |
| XayaUI/KeyCatch.lua | 17.8 KB | 18.8 KB | 23.4 KB | 21.7 KB |
| XayaUI/Modules.lua | 112.2 KB | 143.5 KB | 166.3 KB | 175.8 KB |
| XayaUI/Compat.lua | 6.5 KB | 7.8 KB | 11.2 KB | 8.4 KB |
| XayaUI/RecycleBin.lua | 7.3 KB | 13.4 KB | 16.7 KB | 14.0 KB |
| XayaUI/Sound.lua | 9.1 KB | 15.5 KB | 19.4 KB | 15.7 KB |
| XayaUI/Share.lua | 15.1 KB | 25.7 KB | 29.9 KB | 29.2 KB |
| XayaUI/Theme.lua | 74.0 KB | 118.0 KB | 129.7 KB | 204.7 KB |
| XayaUI/GameMenuButton.lua | 18.8 KB | 29.2 KB | 35.6 KB | 30.3 KB |
| XayaUI/MinimapButton.lua | 19.8 KB | 39.2 KB | 50.7 KB | 39.5 KB |
| XayaUI/Console.lua | 24.6 KB | 36.6 KB | 49.9 KB | 37.2 KB |
| XayaUI/DebugRecord.lua | 29.6 KB | 46.7 KB | 59.8 KB | 52.9 KB |
| XayaUI/MouseTracker.lua | 7.0 KB | 7.3 KB | 10.6 KB | 7.2 KB |
| **XayaUI Platform, 17 files** | 0.42 MB | 0.63 MB | 0.75 MB | 0.79 MB |
| XayaUI_Rules/RuleDefaults.lua | 36.1 KB | 49.7 KB | 60.2 KB | 70.0 KB |
| XayaUI_Rules/TextureList.lua | 3.1 KB | 8.9 KB | 10.9 KB | 12.6 KB |
| XayaUI_Rules/ProcGlows.lua | 7.9 KB | 8.0 KB | 8.0 KB | 14.1 KB |
| XayaUI_Rules/SetBonusAuras.lua | 3.8 KB | 2.8 KB | 2.9 KB | 6.8 KB |
| XayaUI_Rules/Conditions.lua | 120.9 KB | 158.7 KB | 184.7 KB | 167.7 KB |
| XayaUI_Rules/AuraAlias.lua | 9.2 KB | 12.3 KB | 16.6 KB | 12.7 KB |
| XayaUI_Rules/Timing.lua | 8.7 KB | 9.9 KB | 13.7 KB | 11.0 KB |
| XayaUI_Rules/ClassLearn.lua | 7.5 KB | 10.4 KB | 15.4 KB | 10.6 KB |
| XayaUI_Rules/TalentDump.lua | 9.9 KB | 14.4 KB | 19.3 KB | 14.3 KB |
| XayaUI_Rules/Triggers.lua | 85.4 KB | 126.2 KB | 152.3 KB | 169.5 KB |
| XayaUI_Rules/Outcomes.lua | 21.5 KB | 32.7 KB | 39.6 KB | 33.1 KB |
| XayaUI_Rules/Cues.lua | 17.4 KB | 25.2 KB | 31.0 KB | 25.5 KB |
| XayaUI_Rules/RuleBin.lua | 22.6 KB | 34.3 KB | 39.8 KB | 35.8 KB |
| XayaUI_Rules/Actions.lua | 23.4 KB | 43.5 KB | 53.0 KB | 45.5 KB |
| XayaUI_Rules/Visual.lua | 220.2 KB | 335.4 KB | 370.3 KB | 375.5 KB |
| XayaUI_Rules/BarCue.lua | 38.7 KB | 58.1 KB | 72.2 KB | 62.8 KB |
| XayaUI_Rules/RuleShare.lua | 18.5 KB | 26.0 KB | 32.4 KB | 27.1 KB |
| XayaUI_Rules/Engine.lua | 30.7 KB | 40.9 KB | 54.0 KB | 42.3 KB |
| XayaUI_Rules/AuraSound.lua | 31.9 KB | 41.3 KB | 53.5 KB | 44.3 KB |
| XayaUI_Rules/AuraSources.lua | 9.6 KB | 14.8 KB | 19.5 KB | 15.2 KB |
| XayaUI_Rules/AuraList.lua | 13.4 KB | 20.8 KB | 27.4 KB | 21.5 KB |
| XayaUI_Rules/Combat/AuraModel.lua | 35.8 KB | 53.7 KB | 67.3 KB | 55.6 KB |
| XayaUI_Rules/Combat/AuraTracker.lua | 27.6 KB | 38.0 KB | 45.2 KB | 40.9 KB |
| XayaUI_Rules/Combat/AuraSetup.lua | 20.3 KB | 37.4 KB | 50.7 KB | 38.7 KB |
| XayaUI_Rules/Combat/AuraDisplay.lua | 89.4 KB | 113.7 KB | 136.7 KB | 123.5 KB |
| **XayaUI Rules without the editor, 25 files** | 0.89 MB | 1.29 MB | 1.54 MB | 1.44 MB |
| XayaUI_Rules/Editor/Drafts.lua | 42.2 KB | 73.2 KB | 86.0 KB | 72.9 KB |
| XayaUI_Rules/Editor/TriggersEditor.lua | 26.4 KB | 54.6 KB | 66.5 KB | 54.3 KB |
| XayaUI_Rules/Editor/OutcomesEditor.lua | 35.6 KB | 74.4 KB | 87.6 KB | 74.1 KB |
| XayaUI_Rules/Editor/DisplayTab.lua | 38.7 KB | 79.5 KB | 91.7 KB | 79.1 KB |
| XayaUI_Rules/Editor/RuleSearch.lua | 18.1 KB | 32.4 KB | 38.2 KB | 32.0 KB |
| XayaUI_Rules/Editor/AutoPicker.lua | 51.6 KB | 81.3 KB | 95.2 KB | 80.9 KB |
| XayaUI_Rules/Editor/TreeHelpers.lua | 24.0 KB | 32.5 KB | 37.5 KB | 32.1 KB |
| XayaUI_Rules/Editor/Editor.lua | 159.1 KB | 304.7 KB | 343.9 KB | 304.3 KB |
| XayaUI_Rules/Editor/ShelvedElements.lua | 14.5 KB | 30.7 KB | 38.3 KB | 30.5 KB |
| XayaUI_Rules/Editor/RulesTree.lua | 114.5 KB | 196.6 KB | 230.0 KB | 196.3 KB |
| XayaUI_Rules/Editor/Sidebar.lua | 117.6 KB | 461.9 KB (1) | 240.2 KB | 461.6 KB (1) |
| XayaUI_Rules/Editor/RuleMerge.lua | 15.7 KB | 22.2 KB | 28.3 KB | 21.9 KB |
| XayaUI_Rules/Editor/SpellSearch.lua | 31.7 KB | 54.8 KB | 69.6 KB | 54.4 KB |
| XayaUI_Rules/Editor/SaveBar.lua | 6.6 KB | 9.7 KB | 15.2 KB | 9.3 KB |
| XayaUI_Rules/Editor/RuleSettings.lua | 11.0 KB | 16.7 KB | 21.8 KB | 16.3 KB |
| **The rule editor (Editor/), 15 files** | 0.69 MB | 1.49 MB (1) | 1.45 MB | 1.48 MB (1) |

The editor's files build nothing at login (each wraps its work in one set-up function run when the window first opens), but the game
must still hold their compiled code: about 1.3 to 1.5 MB, the price of "Keep it merged".

## (b) Tables each file builds at load

Named holders (a key of the shared namespace ns, a file's local table, a global) of 2 KB and more; smaller ones are summed per file.
`python3 tests/memory_report_run.py` lists every holder of 1 KB and more; `--json` holds all of them. Built by the files alone, before
any saved data.

| File | Holder | Size | Tables / strings / closures |
|---|---|---:|---:|
| XayaUI/Theme.lua | ns.Theme (the theme presets and their functions) | 122.2 KB | 612 / 247 / 88 |
| XayaUI/Theme.lua | 37 smaller holders | 4.3 KB | |
| XayaUI/LocalSounds.lua | ns.LocalSounds (the sound list for the pickers) | 71.9 KB | 263 / 524 / 0 |
| XayaUI/LocalGraphics.lua | ns.LocalGraphics (the art list for the pickers) | 50.2 KB | 150 / 298 / 0 |
| XayaUI/Modules.lua | functions in ns (closures) | 13.7 KB | 0 / 2 / 106 |
| XayaUI/Modules.lua | local profileParts | 6.7 KB | 12 / 30 / 9 |
| XayaUI/Modules.lua | local settingsOwned | 5.9 KB | 8 / 0 / 0 |
| XayaUI/Modules.lua | local SETTINGS_KEYS | 5.4 KB | 8 / 55 / 0 |
| XayaUI/Modules.lua | ns.MODULES | 4.2 KB | 15 / 34 / 0 |
| XayaUI/Modules.lua | local LEGACY_SPLIT | 4.0 KB | 6 / 35 / 0 |
| XayaUI/Modules.lua | ns.Style | 2.9 KB | 9 / 21 / 0 |
| XayaUI/Modules.lua | local COMBAT_LOCK_EXEMPT | 2.4 KB | 1 / 18 / 0 |
| XayaUI/Modules.lua | 83 smaller holders | 14.2 KB | |
| XayaUI/DebugRecord.lua | ns.ERROR_CODES | 8.8 KB | 22 / 56 / 0 |
| XayaUI/DebugRecord.lua | functions in ns; ns.DebugRecordInfo; 12 smaller | 8.6 KB | |
| XayaUI/Core.lua | local BUILTIN_FONTS; functions in ns; 27 smaller | 12.2 KB | |
| (no file) | ns, the namespace table itself (after both addons: 40.1 KB) | 10.1 KB | |
| XayaUI/Share.lua | ns.Share; local B64R; 9 smaller | 7.5 KB | |
| XayaUI/GameMenuButton.lua, MinimapButton.lua, KeyCatch.lua, Console.lua, Compat.lua, Sound.lua, RecycleBin.lua, MouseTracker.lua, LibStub.lua, UserMedia.lua | small holders | 31.5 KB together | |
| XayaUI_Rules/Triggers.lua | ns.TRIGGER_TYPES (the trigger catalog) | 77.5 KB | 225 / 262 / 40 |
| XayaUI_Rules/Triggers.lua | ns.LOC_EFFECTS; functions in ns; 28 smaller | 15.2 KB | |
| XayaUI_Rules/Visual.lua | functions in ns (closures) | 16.5 KB | 0 / 1 / 105 |
| XayaUI_Rules/Visual.lua | local SNAP_TARGETS | 6.7 KB | 31 / 40 / 0 |
| XayaUI_Rules/Visual.lua | local GA | 5.7 KB | 3 / 24 / 22 |
| XayaUI_Rules/Visual.lua | local SNAP_POS; 137 smaller | 32.2 KB | |
| XayaUI_Rules/Conditions.lua | functions in ns; ns.LOAD_TRI; 84 smaller | 28.3 KB | |
| XayaUI_Rules/RuleDefaults.lua | ns.RULE_DEFAULTS | 10.5 KB | 29 / 52 / 0 |
| XayaUI_Rules/RuleDefaults.lua | functions in ns; ns.BAR_DEFAULTS; ns.DEFAULT_FOLDERS; 22 smaller | 12.1 KB | |
| XayaUI_Rules/Combat/AuraDisplay.lua | ns.AuraDisplay; 64 smaller | 19.7 KB | |
| XayaUI_Rules/Combat/AuraModel.lua | ns.AuraModel; 20 smaller | 16.7 KB | |
| XayaUI_Rules/BarCue.lua | functions in ns; ns.BAR_CUE_DEFAULTS; 38 smaller | 15.6 KB | |
| XayaUI_Rules/TextureList.lua | ns.TextureList | 14.2 KB | 86 / 85 / 0 |
| XayaUI_Rules/ProcGlows.lua | ns.PROC_GLOW_AURAS | 14.1 KB | 107 / 0 / 0 |
| XayaUI_Rules/AuraSound.lua | ns.AuraSound; 23 smaller | 12.8 KB | |
| XayaUI_Rules/Combat/AuraTracker.lua, Actions.lua, Engine.lua, SetBonusAuras.lua, AuraSetup.lua, Timing.lua, Cues.lua, AuraAlias.lua, Outcomes.lua, AuraList.lua, AuraSources.lua, RuleBin.lua, ClassLearn.lua, RuleShare.lua, TalentDump.lua, Editor/Drafts.lua | small holders | 60.3 KB together | |

Built at load by the files: about 0.39 MB (Platform) and 0.36 MB (Rules). None of it grows.

## (c) Saved variables, as loaded

Exact: each part loaded from its saved text with a collection before and after. "Text" is the compact saved text; the game's file adds
tabs, line breaks and "-- [n]" comments, so the file on disk is larger (INFERENCE: about 1.5 to 2.5 times).

**Fresh install:** none of the three saved variables exists.

**Realistic profile:**

| Saved variable (addon) | Part | In memory | Text | Count | What reads it |
|---|---|---:|---:|---|---|
| CueRulesDB (Platform) | **all** | **10.83 MB** | 2.72 MB | | |
| | profiles (rule backups) | 7.81 MB | 1.72 MB | 3 backups, 2.60 MB each | Profiles > Backups (Load, show as text, delete) |
| | rules (old copy left by the settings move) | 2.59 MB | 585 KB | 300 rules | nothing after the move (Modules.lua section 0c; the QA walkthrough on qa-installer-branch) |
| | recycleBin | 175.7 KB | 38.3 KB | 20 deleted rules | Rules > Recycle Bin; kept 7 days by default |
| | debugRecord (left by Dev Assist) | 113.0 KB | 228.2 KB | 3,000 lines | nothing on main (Dev Assist only) |
| | lastBugReport | 111.4 KB | 112.6 KB | one text | nothing (written by /xui bug, never read) |
| | errorLog | 27.5 KB | 53.5 KB | 50 entries (the cap) | /xui report, /xui bug |
| | folders (old copy) | 13.6 KB | 2.2 KB | 17 groups | nothing after the move |
| | 8 smaller parts (ui, theme, minimap, version, ...) | 3.8 KB | | | |
| XayaUIRulesDB (Rules) | **all** | **3.13 MB** | 0.70 MB | | |
| | rules | 2.59 MB | 585 KB | 300, 8.8 KB each | the rules themselves |
| | drafts | 453.4 KB | 98.3 KB | 30 (the default cap), 15.1 KB each | Drafts page (with "Prompt for saving" on) |
| | classLearn | 51.1 KB | 13.2 KB | 4 specs | auto-populate in the editor |
| | folders | 12.8 KB | 2.2 KB | 17 groups | the groups |
| | learnedCooldown, learnedAuraDur, procGlowSeen, learnedAuraStacks | 32.4 KB | 5.9 KB | 440 entries | the engine (timing, proc glows) |
| | 12 smaller parts | 3.6 KB | | | |
| XayaUITalentDB (Rules) | **all** | **2.79 MB** | 524 KB | 13 classes, about 220 KB each | the editor's talent search (SpellSearch.lua), /xui debug talents |

Each rule takes 8.8 KB in memory against about 2 KB of text: every rule is saved with all its settings, defaults included (its display,
text, sound, load and trigger tables), and every table costs at least 64 bytes plus 40 bytes a key. Test: the same 300 rules keeping only
what differs from a new rule take 0.99 MB of tables instead of 2.59 MB (62% less; strings shared, so tables only). INFERENCE: that is
lossless only if every reader goes through NormalizeRule.

No other saved variable is declared on main: XayaUI_Options has none; the old modules' own saved variables (XayaUIChatDB and the others)
are not loaded while those addons are not installed. The old modules' keys still kept in CueRulesDB from before their own stores were
made (chat, qol, notepad and others) are not in this profile; their size in her file is unknown (INFERENCE: settings, small).

## (d) The 20 largest holders after login (realistic profile)

| # | Holder | Size | Addon (as the game books it, INFERENCE) |
|---:|---|---:|---|
| 1 | CueRulesDB.profiles (3 rule backups) | 7.82 MB | Platform |
| 2 | XayaUITalentDB.classes (talent scan) | 2.83 MB | Rules |
| 3 | XayaUIRulesDB.rules (the rules) | 2.59 MB | Rules |
| 4 | CueRulesDB.rules (old copy of the rules) | 2.59 MB | Platform |
| 5 | Rules' displays built at ADDON_LOADED: XayaUI's fields and scripts on 4,396 frame objects | 559.0 KB | Rules |
| 6 | XayaUIRulesDB.drafts | 446.0 KB | Rules |
| 7 | ns.runtime (the engine's state per rule; Engine.lua) | 437.2 KB | Rules |
| 8 | ns.AuraDisplay (combat engine displays; Combat/AuraDisplay.lua) | 208.7 KB | Rules |
| 9 | CueRulesDB.recycleBin | 176.1 KB | Platform |
| 10 | CueRulesDB.debugRecord | 136.6 KB | Platform |
| 11 | frames made at login: XayaUI's fields and scripts on them | 130.8 KB | Rules (mostly) |
| 12 | ns.Theme (Theme.lua) | 121.8 KB | Platform |
| 13 | CueRulesDB.lastBugReport | 111.2 KB | Platform |
| 14 | Conditions.lua: local evalCache | 85.9 KB | Rules |
| 15 | ns.AuraTracker (Combat/AuraTracker.lua) | 81.4 KB | Rules |
| 16 | ns.TRIGGER_TYPES (Triggers.lua) | 77.3 KB | Rules |
| 17 | ns.LocalSounds (LocalSounds.lua) | 71.8 KB | Platform |
| 18 | Engine.lua: local depCache | 58.7 KB | Rules |
| 19 | Conditions.lua: local ctxMemo | 53.7 KB | Rules |
| 20 | ns.LocalGraphics (LocalGraphics.lua) | 50.2 KB | Platform |

The compiled code (3.4 MB for both addons, in load order) is not a holder in this list; it would sit between rows 1 and 2.
Fresh install, largest: ns.Theme 121.8 KB, ns.TRIGGER_TYPES 77.5 KB, ns.LocalSounds 71.9 KB, ns.LocalGraphics 50.2 KB, the namespace
table 40.1 KB.

## XayaUI Options (loads when /xui first opens the window)

| | Stand-in |
|---|---:|
| Loading it (38 files including AceGUI and AceConfig; compiled 1.13 MB) | 1.28 MB |
| While the window is open on the realistic profile (rule editor built, 1,076 frame objects) | +4.35 MB |
| Kept after closing it and a collection | +0.45 MB |

Largest files: Skin.lua 221 KB, Options.lua 187 KB, InfoPaneData.lua 157 KB (of which about 55 KB is text tables built at load),
AceConfigDialog 76 KB, InfoPane.lua 54 KB, TreePaint.lua 45 KB, AceGUI 43 KB, ThemeEditor.lua 42 KB. Her reading, 976 KB, is close to
the load cost. INFERENCE: what the rule editor builds while the window is open is booked by the game to XayaUI Rules (it is Rules' code).

## What can be cut

Nothing below is built yet. "Loses nothing she uses" means every feature works as now; a cut that removes or shortens her saved data is
**NEEDS HER OK** even when nothing is lost. Savings are for the realistic profile.

### XayaUI Platform (11.62 MB realistic; 0.79 MB without saved data)

| # | Cut | Saves | What changes for her | Label |
|---|---|---:|---|---|
| P-1 | Remove the old copy of the rules (and groups, bars, other moved keys) that the settings move left in CueRulesDB ("kept untouched until P6", Modules.lua:306) | about 2.6 MB | Nothing in this version reads it. Going back to an XayaUI from before the move would find no rules (the "Rules before the settings move" backup, or an export, brings them back). | **NEEDS HER OK** |
| P-2 | Keep each rule backup as one text (the text a share string carries), read only when she loads that backup | about 1.8 to 2.0 MB per backup (2.6 MB to about 0.6 to 0.8 MB); 5.4 to 6 MB for 3 | Backups load, show as text and delete as now. An XayaUI older than the change could not read the new backups. | **NEEDS HER OK** |
| P-3 | Delete the "Rules before the settings move" backup once she has checked her rules | 2.6 MB (0.6 to 0.8 MB after P-2) | One fewer backup in Profiles > Backups | **NEEDS HER OK** |
| P-4 | Clear Dev Assist's detailed debug record left in CueRulesDB | 113 KB at 3,000 lines (up to about 0.4 MB at its 10,000-line setting) | Nothing on main shows it; Dev Assist (qa-installer-branch) would start a new record | **NEEDS HER OK** |
| P-5 | Stop keeping the last bug report text, and clear the kept one | 111 KB here (the size of her last report) | /xui bug builds the report fresh each time, as now; the old text is not kept | **NEEDS HER OK** |
| P-6 | Build the sound list, the art list and the theme presets the first time something needs them, not at load | up to about 0.24 MB (122 + 72 + 50 KB) | Nothing visible; a few milliseconds move to the first use. Check first which of them login needs (the theme in use does). | proposal (no saved data) |

Keep as they are (bounded): the error log (50 entries, 27.5 KB), the Recycle Bin (items leave after 7 days by default), the settings.
Backups grow only when she makes one (Options.lua:754 is the only caller): bounded by her.

With P-1 to P-5 and one backup kept, the realistic profile's Platform would hold about 1.6 to 1.8 MB at login (code 0.79 MB plus about
0.9 MB of saved data).

### XayaUI Rules (11.88 MB realistic; 2.97 MB without saved data)

| # | Cut | Saves | What changes for her | Label |
|---|---|---:|---|---|
| R-1 | The talent scan (XayaUITalentDB) is loaded at every login but read only by the editor's talent search and /xui debug talents. Either (a) keep it as one text per class, read the first time the talent search needs it; or (b) do not keep it, and scan when the talent search first needs it (about one second, out of combat, as /xui debug talents does now); or (c) move it to a load-on-demand data addon with its own saved variable (one more entry in the AddOns list) | (a) about 2.3 MB (2.79 MB to about 0.5 MB); (b) and (c) 2.79 MB | (a) nothing visible; (b) the first talent search after a login waits about a second; (c) one more AddOns entry | **NEEDS HER OK** (a and b change her saved data; c is a packaging choice like SD-41). Only applies if she ran /xui debug talents. |
| R-2 | Build a rule's display when it can first show here (its load conditions pass), not every display at load | up to 0.56 MB of Lua fields plus most of the 4,396 frame objects (game memory outside the addon count), in proportion to the rules that do not load on this character / spec | Nothing visible; building moves to the moment a rule starts to load (talent or spec change, joining a group); a few milliseconds per display, possibly at a pull. Needs its own design and test (V24, V27). | proposal (no saved data) |
| R-3 | Keep in each rule only what differs from a new rule | in memory only if defaults are read through a lookup at run time (2.59 MB to about 1.0 MB, and the same share of drafts and backups), which costs the engine a lookup per setting read (V27); saved this way but filled in at load, it saves only file size and login garbage | Nothing visible if every reader goes through NormalizeRule (INFERENCE, to prove) | **NEEDS HER OK**; not recommended now |
| R-4 | Lower the default "Keep up to" for drafts from 30 to 10 | about 0.3 MB at the cap | 20 fewer drafts kept | **NEEDS HER OK**; not recommended (bounded already) |
| R-5 | The rule editor's code (about 1.3 to 1.5 MB at login) | | Her answer (SD-41) is "Keep it merged". Information only: as its own load-on-demand addon it would cost nothing at login. | no cut proposed |

Keep (needed while rules run, and in proportion to the rules): the engine's state (ns.runtime 437 KB), the combat engine's displays
(209 KB), the aura tracker (81 KB), the engine caches (evalCache 86 KB, depCache 59 KB, ctxMemo 54 KB), the learned data (about 85 KB;
INFERENCE: it grows only with the auras and spells her rules use, and classLearn starts over on each game build).

With R-1 (a) and today's display building, the realistic profile's Rules would hold about 9.6 MB; with R-1 (b or c) about 9.1 MB; R-2
lowers that further in proportion to the rules that do not load where she plays.

### XayaUI Options (0 at login; 1.28 MB once loaded)

| # | Cut | Saves | What changes for her | Label |
|---|---|---:|---|---|
| O-1 | Build the information pane's text tables (InfoPaneData.lua) the first time that pane is shown | about 55 KB | Nothing visible | proposal (no saved data) |

Options already loads only on demand and gives back all but 0.45 MB after the window closes. No further cut is proposed.

## Proposed memory budget for the V27 gate

Measured by tests/memory_report_run.py in the stand-in, on the gate's own profile (the realistic profile above), not on her files: the
gate judges what the code makes, and her saved data is reported, not failed. Each budget is today's number plus about 15%, so the gate
catches growth now; the right-hand column is the budget after the cuts she approves (the expected number, rounded up). Once she sets the numbers, the script becomes the
gate test (tests/gate_memory_run.py) and fails when a number goes over.

| Addon | Measured | Now | Budget (today's code) | Budget after approved cuts |
|---|---|---:|---:|---:|
| Platform | its files at login (code and tables) | 0.79 MB | 0.9 MB | 0.8 MB (with P-6) |
| Platform | ADDON_LOADED and login, fresh install | 5 KB | 0.1 MB | 0.1 MB |
| Platform | one rule backup of the 300-rule profile | 2.60 MB | 3.0 MB | 0.9 MB (P-2) |
| Platform | saved keys nothing reads (old rules copy, debug record, last bug report) | 2.8 MB | report only | 0 (P-1, P-4, P-5) |
| Platform | total at login, gate profile | 11.62 MB | 13.4 MB | 2.0 MB (one backup) |
| Rules | its files at login (code and tables; editor included, SD-41) | 2.93 MB | 3.4 MB | 3.4 MB |
| Rules | per rule: saved rule, display and engine state at login (300 rules) | 19.2 KB | 22 KB | 18 KB (R-2; depends on her rules) |
| Rules | the talent scan at login | 2.79 MB | 3.2 MB | 0.6 MB (R-1 a) or 0 (R-1 b, c) |
| Rules | drafts at the default cap | 0.45 MB | 0.5 MB | 0.5 MB |
| Rules | total at login, gate profile | 11.88 MB | 13.7 MB | 10.0 MB (R-1 a), 9.5 MB (R-1 b, c) |
| Options | loading it | 1.28 MB | 1.5 MB | 1.5 MB |
| Options | kept after one open and close (300 rules) | 0.45 MB | 0.55 MB | 0.55 MB |
| Options | while the window is open (300 rules) | 4.35 MB | 5.0 MB | 5.0 MB |

For scale (her readings, SD-38 / SD-40): an EllesmereUI module about 0.9 MB, OPie 2 MB, KiraUI-Plugin 6 MB. Platform's code and tables
(0.79 MB) are already at an EllesmereUI module's size; what makes Platform 11 MB is saved data.

## Questions for her (to go through the question flow, V19)

1. P-1: remove the old copy of the rules from CueRulesDB? (Recommended: yes, after she checks her rules and keeps one backup.)
2. P-2: keep rule backups as one text each? (Recommended: yes.)
3. P-3: delete the "Rules before the settings move" backup? (Recommended: her choice after P-1.)
4. P-4 and P-5: clear the left-over debug record and stop keeping the last bug report? (Recommended: yes.)
5. R-1: the talent scan: (a) one text per class, (b) scan when needed, (c) its own load-on-demand addon, or keep as is? (Recommended: a.)
6. R-2: build displays only for rules that can show here? (Recommended: yes, as its own reviewed change.)
7. R-3 and R-4: leave as they are? (Recommended: yes.)
8. The budget: set it at the "today's code" column now, and lower it as cuts land? (Recommended: yes.)

## Checking against her real files

Her two saved files settle what this profile only estimates. They are `WTF\Account\<account>\SavedVariables\XayaUI.lua` (CueRulesDB) and
`XayaUI_Rules.lua` (XayaUIRulesDB, XayaUITalentDB), never committed. Put both in a folder and run
`python3 tests/memory_report_run.py --saved <folder>`: the report adds a "saved" profile with the same part-by-part numbers. The sizes of
the two files on disk alone already tell most of it (this profile's compact text: CueRulesDB 2.72 MB, XayaUIRulesDB 0.70 MB,
XayaUITalentDB 0.52 MB).

## Limits

* Stand-in estimates only (Lua 5.1 in lupa); the game's numbers differ by its allocator, its frame objects and uncollected garbage.
  **UNVERIFIED IN GAME.**
* The realistic profile is built, not hers: how many backups, drafts, deleted rules and talent scans her files hold is unknown
  (INFERENCE). The match with her 11 MB / 12 MB readings is consistent with it, not proof.
* Which addon the game books saved variables and frames to is INFERENCE (not documented in docs/reference/api/).
* The talent scan's size is an estimate of Midnight's trees (about 51 class nodes, 45 per spec, 3 hero trees of 11 per class).
* The walk's sizes (b, d) are estimates from Lua 5.1's table layout; they come to 97% of the measured total.
