# XayaUI performance audit (offline, code only), 2026-11-07

Written by the performance test session (session_014bN6tTxYo6enpkMGsVkMqm). No game was run. Nothing here is measured. Every
statement about frequency or cost that the code does not fix by itself (a constant, a loop bound) is marked **INFERENCE**. Numbers
that appear are code constants (for example `TICK = 0.2`) or grep counts, never timings.

Scope: the shipping addon folders XayaUI, XayaUI_Options, XayaUI_Chat, XayaUI_QoL, XayaUI_Bonus, XayaUI_Reskin, XayaUI_DevAssist.
Third-party libraries under `*/Libs/` (LibStub; Ace3 AceConfig / AceGUI / CallbackHandler in XayaUI_Options; XayaDataBlocks-1.0 in
Bonus and Chat) exist and are counted only in the "+Libs" column. XayaUI_Media is skipped.

Code base: commit `687b624` (origin/main at audit start). Branch `claude/perf-test-m-plus` at `091f784` (audit start) had the same Lua (`git diff --stat
687b624 HEAD -- '*.lua'` is empty). While this audit was written the working tree held uncommitted Dev Assist changes by another
session (DevRecord.lua, RunRecord.lua, tools/perf_report.py); all counts and line numbers below are for `687b624`, not the working tree.

Two branches that were not on main at 687b624 are reviewed where named. While this audit was being written, origin/main moved to
`28380a9` and this branch merged it (`f2378b5`): both commits below are now on main and in this branch (`git merge-base
--is-ancestor` checked). Their findings therefore apply to main now; their line numbers stay those of the named commits, and the
34 Lua files changed between 687b624 and 28380a9 were not re-audited line by line (counts in section 1 are for 687b624).

| Branch | Commit | What | Where on the remote (at audit start) |
|---|---|---|---|
| D4 event routing | `ba4ec01` "D4 / #115 / #309: event routing, the next-frame re-check (core 0.6.56)" | Engine.lua | `origin/bundle-2300`, `origin/claude/fervent-cerf-hldtwn` |
| S8 bar cues | `9c5e201` (tip of `origin/claude/dreamy-edison-pvb3i1`) | new XayaUI/BarCue.lua, Visual.lua hooks, Bonus Type colours | that branch, and bundle-2300 |

Line numbers for those two are from `git show <commit>:<file>`.

General facts used throughout (Blizzard UI behaviour, not from this repo, so **INFERENCE** where it matters): an `OnUpdate` script
runs once per rendered frame and only while its frame is shown; a frame made with `CreateFrame("Frame")` and no `Hide()` is shown;
`hooksecurefunc` and `HookScript` cannot be removed; `TooltipDataProcessor.AddTooltipPostCall` has no documented removal.

---

## 1. Method and counts

### 1.1 Exact command

Script used (kept outside the repo; reproduce it from this listing). It counts, per addon, **code lines** that match a pattern after
cutting everything from `--` to the end of the line (comments), plus two whole-suite columns: `raw` (comments included, shipping
folders only) and `+Libs` (comments included, Libs included).

```bash
#!/bin/bash
# usage: count.sh [rev]   (run from the repo root; default rev 687b624)
REV=${1:-687b624}
ADDONS="XayaUI XayaUI_Options XayaUI_Chat XayaUI_QoL XayaUI_Bonus XayaUI_Reskin XayaUI_DevAssist"
declare -A PATS=(
 [RegisterEvent]='RegisterEvent[(,]'            # f:RegisterEvent(e) and pcall(f.RegisterEvent, f, e)
 [RegisterUnitEvent]='RegisterUnitEvent[(,]'
 [OnUpdate_any]='OnUpdate'                     # every line naming OnUpdate (set, clear, GetScript, comments in raw)
 [SetScript_OnUpdate]='SetScript\(\s*"OnUpdate"'  # set AND clear (SetScript("OnUpdate", nil))
 [NewTicker]='C_Timer\.NewTicker\('
 [NewTimer]='C_Timer\.NewTimer\('
 [After]='C_Timer\.After\('
 [hooksecurefunc]='hooksecurefunc\s*[(,]'       # hooksecurefunc(...) and pcall(hooksecurefunc, ...)
 [HookScript]='HookScript\('
 [CreateFrame]='CreateFrame\('
 [TooltipPostCall]='TooltipDataProcessor\.AddTooltipPostCall\('
 [format]='(string\.format|[^.a-zA-Z_]format)\('  # string.format( and ("..."):format(
 [concat]='\.\.'                                # lines with at least one .. (also matches "..." varargs)
 [pcall]='pcall\('
 [table_ctor]='=\s*\{\s*\}|\{\s*\}\s*[,)]'       # empty table constructors only: x = {}, f({}), {} ,
)
ORDER="RegisterEvent RegisterUnitEvent OnUpdate_any SetScript_OnUpdate NewTicker NewTimer After hooksecurefunc HookScript CreateFrame TooltipPostCall format concat table_ctor pcall"
printf "%-20s" metric; for a in $ADDONS; do printf "%10s" "${a#XayaUI_}"; done; printf "%8s %8s %8s\n" code raw +Libs
for k in $ORDER; do p=${PATS[$k]}; printf "%-20s" $k; tot=0
 for a in $ADDONS; do
  n=$(git grep -hE "$p" $REV -- "$a/*.lua" ':(exclude)*/Libs/*' | sed -E 's/--.*$//' | grep -cE "$p")
  printf "%10s" $n; tot=$((tot+n)); done
 raw=$(git grep -hE "$p" $REV -- 'XayaUI/*.lua' 'XayaUI_*.lua' ':(exclude)*/Libs/*' ':(exclude)XayaUI_Media/*' | wc -l)
 libs=$(git grep -hE "$p" $REV -- 'XayaUI*/*.lua' ':(exclude)XayaUI_Media/*' | wc -l)
 printf "%8s %8s %8s\n" $tot $raw $libs; done
```

Note: in a git pathspec without `:(glob)`, `*` also matches `/`, so `XayaUI/*.lua` includes `XayaUI/Combat/*.lua`.

### 1.2 Totals at 687b624 (lines, not calls)

| Metric (code lines) | XayaUI | Options | Chat | QoL | Bonus | Reskin | DevAssist | **code** | raw | +Libs |
|---|---|---|---|---|---|---|---|---|---|---|
| RegisterEvent (both forms) | 45 | 1 | 3 | 10 | 10 | 0 | 21 | **90** | 92 | 92 |
| RegisterUnitEvent | 4 | 0 | 0 | 1 | 0 | 0 | 6 | **11** | 11 | 11 |
| any line naming OnUpdate | 18 | 22 | 20 | 6 | 11 | 3 | 6 | **86** | 102 | 132 |
| SetScript("OnUpdate", ...) set + clear | 17 | 21 | 20 | 4 | 9 | 3 | 4 | **78** | 78 | 100 |
| C_Timer.NewTicker( | 4 | 1 | 0 | 0 | 0 | 0 | 1 | **6** | 6 | 6 |
| C_Timer.NewTimer( | 0 | 1 | 0 | 0 | 0 | 0 | 0 | **1** | 1 | 1 |
| C_Timer.After( | 14 | 21 | 5 | 8 | 2 | 1 | 11 | **62** | 62 | 63 |
| hooksecurefunc (both forms) | 8 | 3 | 5 | 9 | 0 | 1 | 0 | **26** | 28 | 32 |
| HookScript( | 2 | 25 | 3 | 9 | 0 | 2 | 0 | **41** | 41 | 43 |
| CreateFrame( | 77 | 69 | 38 | 43 | 54 | 3 | 33 | **317** | 317 | 393 |
| TooltipDataProcessor.AddTooltipPostCall( | 0 | 0 | 0 | 0 | 2 | 0 | 0 | **2** | 2 | 2 |
| format( | 124 | 56 | 14 | 112 | 40 | 0 | 173 | **519** | 521 | 594 |
| `..` (concat or varargs) | 386 | 533 | 125 | 269 | 112 | 3 | 349 | **1777** | 1929 | 2226 |
| empty `{}` constructors | 528 | 418 | 70 | 296 | 55 | 8 | 240 | **1615** | 1616 | 1690 |
| pcall( | 434 | 319 | 72 | 70 | 55 | 21 | 193 | **1164** | 1164 | 1179 |

Old-pattern variant (the one the earlier numbers used), same script with `RegisterEvent\(` and plain `hooksecurefunc`:
`RegisterEvent\(` = 68 code lines, 70 raw; `RegisterUnitEvent\(` = 8.

### 1.3 Why the earlier numbers differ

| Earlier number | Reproduced by | Explanation |
|---|---|---|
| 68 RegisterEvent (other session) | `RegisterEvent\(`, code lines, shipping only | misses the 22 lines of the form `pcall(f.RegisterEvent, f, e)` |
| 70 RegisterEvent (yours) | `RegisterEvent\(`, raw | the same, comments included |
| 8 RegisterUnitEvent | `RegisterUnitEvent\(` | misses 3 `pcall(ev.RegisterUnitEvent, ...)` lines |
| 100 OnUpdate (other session) | `SetScript("OnUpdate"` raw **+Libs** | includes 22 Ace3 lines; counts set and clear lines alike |
| 132 "OnUpdate" lines (yours) | substring `OnUpdate`, raw **+Libs** | 30 of them are in Ace3; 16 are comments |
| 7 NewTicker | substring `NewTicker` | includes the guard `if C_Timer and C_Timer.NewTicker then` (AuraDisplay.lua:1168); 6 calls |
| 73 After | substring `C_Timer.After` +Libs | includes guards like `if C_Timer and C_Timer.After then`; 62 calls in shipping code |
| 47 hooksecurefunc | substring, raw +Libs | includes guards (`if hooksecurefunc then`, `type(hooksecurefunc) == "function"`) and comments; 26 call lines in code |
| 50 HookScript | substring +Libs | includes `.HookScript then` guards; 41 call lines |
| 393 CreateFrame | raw +Libs | 76 in Libs (74 Ace3); 317 in shipping code |

### 1.4 What line counts cannot tell

- A call line is not one registration. Engine.lua:327-334 registers 16 events from one `for ... do f:RegisterEvent(e) end` line.
  Triggers.lua:1262-1272 registers 21 events from three lines. The per-feature event lists are in section 2.
- Helpers hide hooks: Chat `C.HookOnce` (Chat/Core.lua:97-105) places one hook per call site; Timing.lua:68-70 places three hooks per
  Cooldown Manager icon, so the number of live hooks grows with the icons the game makes (**INFERENCE**: tens).
- `{}`, `format` and `..` counts are whole-file. No grep can tell which of them run inside an event or OnUpdate handler. Section 3
  lists the ones found by reading the hot paths. Treat the totals as size indicators only.

---

## 2. Inventory per addon and feature

Columns: **Off?** = does it exist / run while its feature is switched off (V14: off must cost nothing). **Combat** = can it run in
combat. **Class** = frequency class: *frame* (every rendered frame), *burst* (follows a high-rate game event such as UNIT_AURA,
SPELL_UPDATE_COOLDOWN, SPELL_UPDATE_CHARGES, CHAT_MSG_ADDON), *periodic* (fixed interval, constant from code), *one-off* (login,
loading screen, a click). All frequency judgements are **INFERENCE** unless they are a code constant.

### 2.1 XayaUI (core)

| # | file:line | Mechanism | Trigger / events | Combat | Off? | Class |
|---|---|---|---|---|---|---|
| C1 | Engine.lua:326-335 | frame, OnEvent :336 | PLAYER_ENTERING_WORLD, SPELL_UPDATE_COOLDOWN, SPELL_UPDATE_CHARGES, PLAYER_REGEN_DISABLED/ENABLED, GROUP_ROSTER_UPDATE, ZONE_CHANGED_NEW_AREA, PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED, SPELLS_CHANGED, ACTIONBAR_SLOT_CHANGED, UPDATE_BONUS_ACTIONBAR, ACTIONBAR_PAGE_CHANGED, UPDATE_SHAPESHIFT_FORM, PLAYER_TARGET_CHANGED, PLAYER_FOCUS_CHANGED (16) + UNIT_AURA player | yes | always, also with zero enabled rules | burst |
| C2 | Engine.lua:372-391 | OnUpdate | every frame: Timing deadline check; full Step at `TICK = 0.2` or `MIN_GAP = 0.05` after an event; combat snapshot every `SNAP_EVERY = 5` s | yes | always | frame + periodic (5-20 Step/s) |
| C2b | Engine.lua:431-447 (at ba4ec01) | OnUpdate branch | D4: a routed re-check on the next frame after SPELL_UPDATE_COOLDOWN / SPELL_UPDATE_CHARGES / UNIT_AURA | yes | always | frame while events stream |
| C3 | Conditions.lua:220-225 | frame | SPELL_UPDATE_CHARGES, PLAYER_ENTERING_WORLD, PLAYER_REGEN_DISABLED/ENABLED, SPELLS_CHANGED, TRAIT_CONFIG_UPDATED, PLAYER_SPECIALIZATION_CHANGED → WatchCharges (:188) | yes | always, even with no charge rule | burst |
| C4 | Conditions.lua:864-890 | frame | SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE, COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED, PLAYER_ENTERING_WORLD → MarkStateDirty; C_Timer.After(0.15) per glow on a watched button (:876) | yes | always, even with no glow rule | burst (procs) |
| C5 | Conditions.lua:1528-1532 | frame | ENCOUNTER_START/END, PLAYER_ENTERING_WORLD, PLAYER_EQUIPMENT_CHANGED → MarkStateDirty | yes | always | one-off |
| C6 | Triggers.lua:387-395 | frame | PLAYER_EQUIPMENT_CHANGED, GET_ITEM_INFO_RECEIVED, PLAYER_ENTERING_WORLD | yes | always | burst (item info) |
| C7 | Triggers.lua:1262-1288 | frame | PLAYER_EQUIPMENT_CHANGED, BAG_UPDATE_DELAYED, PLAYER_TOTEM_UPDATE, RUNE_POWER_UPDATE, PLAYER_TARGET_CHANGED, PLAYER_FOCUS_CHANGED, PLAYER_DEAD, PLAYER_ALIVE, PLAYER_UNGHOST, PLAYER_STARTED_MOVING, PLAYER_STOPPED_MOVING, PLAYER_FLAGS_CHANGED, LOSS_OF_CONTROL_ADDED/UPDATE, PLAYER_CONTROL_LOST/GAINED; unit (player): UNIT_SPELLCAST_SUCCEEDED, UNIT_PET, UNIT_ENTERED_VEHICLE, UNIT_EXITED_VEHICLE, UNIT_INVENTORY_CHANGED. Each → MarkStateDirty | yes | always, whether or not a rule reads them | burst |
| C8 | Timing.lua:64-71 | hooksecurefunc ×3 per Cooldown Manager icon | TriggerAlertEvent (→ MarkStateDirty), OnUnitAuraUpdatedEvent, OnCooldownIDSet; placed by BuildCDMIndex | yes | permanent once placed | burst (per icon per aura update) |
| C9 | Combat/AuraModel.lua:631-644 | frame | PLAYER_ENTERING_WORLD, PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED, PLAYER_EQUIPMENT_CHANGED, PLAYER_REGEN_ENABLED, SPELL_DATA_LOAD_RESULT; unit (player) UNIT_SPELLCAST_SENT/SUCCEEDED | yes (casts) | always | per cast; SPELL_DATA_LOAD_RESULT debounced 1 s |
| C10 | Combat/AuraTracker.lua:561-567 | frame | PLAYER_REGEN_DISABLED/ENABLED, PLAYER_DEAD, PLAYER_ENTERING_WORLD, PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED | edges | always | one-off |
| C11 | Combat/AuraSetup.lua:354-355; :302 | frames | boot: PLAYER_ENTERING_WORLD, PLAYER_SPECIALIZATION_CHANGED → After(6); window: REGEN events, only after the window was built | no | boot always | one-off |
| C12 | Combat/AuraDisplay.lua:1185-1192 | frame | PLAYER_ENTERING_WORLD, PLAYER_REGEN_ENABLED, PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED → D.Build; PLAYER_TARGET_CHANGED / PLAYER_FOCUS_CHANGED → RefreshUnit (loops slots) | target/focus: yes | always | one-off / per target change |
| C13 | Combat/AuraDisplay.lua:1168-1171 | C_Timer.NewTicker 0.25 s and 5 s | SyncLive, GuardCheck | yes | **always, also with automatic drawing off** (V14) | periodic |
| C14 | Combat/AuraDisplay.lua:1162-1167 | hooksecurefunc ×4 on ns | ToggleUnlock, SetGroupUnlocked, SetMoveUnlocked → SyncLive; MarkDirty → QueueBuild (After 1 s → D.Build → RefreshAllVisuals) | no (Build waits) | always | per edit |
| C15 | ClassLearn.lua:71-86 | frame | PLAYER_ENTERING_WORLD, PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED, PLAYER_REGEN_ENABLED → After(3) | combat end | always | one-off |
| C16 | AuraList.lua:249-253 | frame | PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED, COOLDOWN_VIEWER_DATA_LOADED, PLAYER_ENTERING_WORLD | no | always | one-off |
| C17 | AuraSound.lua:202-216 | frame | its EVENTS, only while a rule ticks "game sound" | – | V14 ok | one-off |
| C18 | Core.lua:801-803; :17 | frame; HookScript OnShow per flat button | ADDON_LOADED, PLAYER_LOGIN | no | – | one-off |
| C19 | DebugRecord.lua:285-300 | frame (SyncEvents) | ADDON_ACTION_BLOCKED/FORBIDDEN while Advanced Debugging is on; Dev Assist's extra events while recording | yes | V14 ok | one-off |
| C20 | Visual.lua:852-874 | OnUpdate, 0.2 s | group box Auto-size watcher | yes | only while an Auto-size group has a border or background | periodic |
| C21 | Visual.lua:2376-2397 | OnUpdate per display, ≤ 1/0.033 s | FxOnUpdate (wipe, fades, flash, tenths) | yes | only while an effect runs on that display | frame-capped ~30/s each |
| C22 | Visual.lua:956, 1184, 1328 | OnUpdate | frame picker; group drag handle; mover-view group tag | rare | only while unlocked / picking | frame |
| C23 | MinimapButton.lua:200; :250 | OnUpdate; frame | drag only; PLAYER_ENTERING_WORLD while the button is on | no | V14 ok | one-off |
| C24 | RecycleBin.lua:287-290 | NewTicker 1800 s | purge | yes | always | periodic (30 min) |
| C25 | Theme.lua:435; :622-623 | NewTicker 0.12 s; frame | only while the colour picker is open; PLAYER_LOGIN, PLAYER_ENTERING_WORLD | no | V14 ok | one-off |
| C26 | Share.lua:380-386 | frame | PLAYER_REGEN_ENABLED while an import waits | – | V14 ok | one-off |
| C27 | AuraSources.lua:171; TalentDump.lua:90 | OnUpdate, time-budgeted | one-off scans, cleared when done | no | – | one-off |
| C28 | GameMenu.lua:315-317 | hooksecurefunc InitButtons / HookScript OnShow | game menu | no | permanent | one-off |
| C29 | UserMedia.lua:86 | frame | PLAYER_LOGIN | no | – | one-off |

### 2.2 XayaUI_Options (LoadOnDemand: 1)

Loaded the first time the settings window opens. **INFERENCE**: rarely open in combat.

| # | file:line | Mechanism | Trigger | Combat | Off? | Class |
|---|---|---|---|---|---|---|
| O1 | Options.lua:5095-5120 | hooksecurefunc AceConfigDialog.Open / FeedGroup | settings window | no | permanent after first load | one-off |
| O2 | Options.lua:7672-7679 | hooksecurefunc("GameTooltip_ShowCompareItem") | every item comparison tooltip, any UI | yes (hover) | permanent once the spell search was used | per hover |
| O3 | Options.lua:5605, 5691, 7265, 7738, 7897, 8377 | OnUpdate | drag, budgeted list builds (4 ms), spell search, perf counter, tree tick | – | only while window / list open | frame |
| O4 | Skin.lua:646, 830, 961, 1741 | OnUpdate; NewTimer 0.4 s → NewTicker 0.07 s | fades, size watch, held stepper buttons | – | while held / animating | frame |
| O5 | Drafts.lua:153-155 | frame | PLAYER_LOGOUT | – | after a draft | one-off |
| O6 | 25 HookScript lines | widget hooks inside the window | window only | – | – | per click |

### 2.3 XayaUI_Chat (Chat Panel on by default)

| # | file:line | Mechanism | Trigger | Combat | Off? | Class |
|---|---|---|---|---|---|---|
| H1 | Core.lua:429-445 | frame | PLAYER_LOGIN, PLAYER_ENTERING_WORLD, UPDATE_CHAT_WINDOWS, UPDATE_FLOATING_CHAT_WINDOWS, DISPLAY_SIZE_CHANGED, UI_SCALE_CHANGED → C.Schedule (After 0) | rare | registered only while the panel part is on | one-off |
| H2 | Messages.lua:31-58 | frame (bus) | up to 18 CHAT_MSG_* (SAY, YELL, EMOTE, PARTY, RAID, INSTANCE_CHAT, GUILD, WHISPER, BN_WHISPER, CHANNEL ...) that a switched-on consumer wants | yes | V14 ok | per chat message |
| H3 | History.lua:212-224 | C.HookOnce on global `print`; frame CHAT_MSG_SYSTEM | Console tab (histConsole default on) | yes | hook permanent, returns while off | per print / system message |
| H4 | Frame.lua:274, 276, 442 | hooksecurefunc Show / SetShown / SetAlpha on Blizzard chat pieces | Blizzard re-shows | yes | permanent, returns while off | per call |
| H5 | Frame.lua:686 | OnUpdate, 0.3 s (`Upkeep`) | anchor check, back-to-newest arrow, rewrap, input hint; C.Parts every 3 s | yes | only while the panel is on | periodic |
| H6 | Scroll.lua:183 | OnUpdate per frame, Update every 0.1 s | own scroll bar (scrollOwn default on) | yes | V14 ok | frame + periodic |
| H7 | Fade.lua:77 | OnUpdate, 0.05 s | fade (fadeOn default off) | yes | V14 ok | periodic |
| H8 | Bar.lua:291; :192 | OnUpdate 1 s; hover OnUpdate | Chat Data Bar (barOn default on); tooltip refresh while hovered | 1 s: yes; hover stops in combat | V14 ok | periodic |
| H9 | Privacy.lua:248 | OnUpdate 0.1 s | cover with reveal on hover | yes | only while covered with reveal | periodic |
| H10 | Locate.lua:82 | OnUpdate | locate boxes shown | no | while shown | frame |
| H11 | Frame.lua:528, 544; Bar.lua:271; Skin.lua:120-121 | drag OnUpdates; HookScript OnSizeChanged / edit focus | user action | no | – | one-off |

### 2.4 XayaUI_QoL (every feature off by default)

| # | file:line | Mechanism | Trigger | Combat | Off? | Class |
|---|---|---|---|---|---|---|
| Q1 | CursorTrail.lua:365 (OnUpdate :205) | OnUpdate per frame | cursor trail on | **yes** (no combat switch; only "hide while mouselooking") | V14 ok | frame |
| Q2 | CursorHighlight.lua:263 (OnUpdate :214) | OnUpdate per frame | cursor highlight on | yes (combatOnly option) | V14 ok | frame |
| Q3 | CharacterToolkit.lua:2367-2376 | frame | 19 events (COMBAT_RATING_UPDATE, MASTERY_UPDATE, SPEED_UPDATE, LIFESTEAL_UPDATE, AVOIDANCE_UPDATE, PLAYER_DAMAGE_DONE_MODS, PLAYER_REGEN_*, PLAYER_TARGET_CHANGED, GET_ITEM_INFO_RECEIVED, SPELL_DATA_LOAD_RESULT, SPELLS_CHANGED ...), 9 unit events on player (UNIT_STATS, UNIT_ATTACK_POWER, UNIT_MAXHEALTH, UNIT_SPELL_HASTE ...), SPELL_UPDATE_COOLDOWN | **yes** | registered while the toolkit is enabled **even while its panel is closed or the panel option is off** (see V14 list) | burst |
| Q4 | CharacterToolkit.lua:2381-2400, 867, 590, 2287 | HookScript owner OnShow/OnHide; hooksecurefunc PaperDollFrame_UpdateStats, PaperDollItemSlotButton_Update, InsertLink targets; HookScript stat rows | character window | rare | permanent, return while off | per update |
| Q5 | CharacterReskin.lua:997, 1006, 1315, 1320-1321, 1325, 1332, 1339 | hooks; `PanelTemplates_SetTab` is global and runs for every tabbed Blizzard window | character window / any tab switch | rare | permanent, return while off | per call |
| Q6 | CharacterReskin.lua:1276; :850 | frame | 4 SLOT_EVENTS while a slot part is on; PLAYER_REGEN_ENABLED while a resize waits | rare | V14 ok | burst (item info) |
| Q7 | ReleaseGuard.lua:123, 158, 163 | frame; hooksecurefunc("StaticPopup_Show") | MODIFIER_STATE_CHANGED while the death box shows; PLAYER_DEAD/ALIVE/UNGHOST while on; every popup | on death | hook permanent | one-off |
| Q8 | ShoppingList.lua:886-901; :860 | frame; hooksecurefunc EndLayout | 9 events (BAG_UPDATE_DELAYED, GET_ITEM_INFO_RECEIVED, AUCTION_HOUSE_*, TRACKED_RECIPE_UPDATE, PLAYER_EQUIPMENT_CHANGED, PLAYER_ENTERING_WORLD, ADDON_LOADED) | bag / item bursts | V14 ok | burst |

### 2.5 XayaUI_Bonus

| # | file:line | Mechanism | Trigger | Combat | Off? | Class |
|---|---|---|---|---|---|---|
| B1 | Tooltips.lua:697-710 | 9 TooltipDataProcessor post-calls (8 ID kinds + Unit) | every tooltip of those types | yes (hover) | placed the first time any section is on; permanent; return at `TT.on` | per hover / tooltip refresh |
| B2 | Tooltips.lua:723-736 | frame | ACTIVE_PLAYER_SPECIALIZATION_CHANGED, TRAIT_CONFIG_UPDATED, PLAYER_REGEN_ENABLED, COOLDOWN_VIEWER_DATA_LOADED, COOLDOWN_VIEWER_TABLE_HOTFIXED while IDs or Formulas on | combat end | V14 ok | one-off |
| B3 | Tooltips.lua:562-570 | frame | INSPECT_READY while one inspect waits | – | V14 ok | one-off |
| B4 | DataPanels.lua:362-373 (OnUpdate :342) | frame + OnUpdate per frame | 4 events; text every 1 s, mouseover alpha every 0.1 s | yes | only while a panel is on (default off) | frame + periodic |
| B5 | DataPanels.lua:252 | hover OnUpdate | panel tooltip; stops in combat | no | – | frame while hovered |
| B6 | Notepad.lua:954; :982-990 | OnUpdate 0.2 s (only while the box is shown); 3 events | Notepad shown | yes if shown | V14 ok | periodic |
| B7 | NotepadShare.lua:603-627 | frame | **CHAT_MSG_ADDON** while "Accept notes shared" (default on) and the Notepad on; PLAYER_REGEN_ENABLED while an offer waits | yes | V14 ok, but on by default | burst (every addon message of every addon) |
| B8 | NotepadShare.lua:219 | OnUpdate pump | only while sending | – | V14 ok | frame |
| B9 | (bar-cue branch) Tooltips.lua TT.ColorTypes | inside B1 | spell / aura tooltip, Type colours on (default on in that branch) | yes | – | per hover |

### 2.6 XayaUI_Reskin

| # | file:line | Mechanism | Trigger | Combat | Off? | Class |
|---|---|---|---|---|---|---|
| R1 | GameMenuSkin.lua:453-455 | hooksecurefunc InitButtons; HookScript OnShow / OnHide on GameMenuFrame | game menu | no | permanent, returns while off | one-off |
| R2 | GameMenuSkin.lua:366 | OnUpdate PollRows | while the menu builds its rows | no | – | frame, short |

### 2.7 XayaUI_DevAssist (LoadOnDemand: 0: loads whenever it is enabled in the AddOns list)

| # | file:line | Mechanism | Trigger | Combat | Off? | Class |
|---|---|---|---|---|---|---|
| D1 | DevAssist.lua:875-876 | frame | ADDON_LOADED, PLAYER_LOGIN | – | – | one-off |
| D2 | DevAssist.lua:663-669 | frame | recorder: UNIT_AURA player+target, UNIT_SPELLCAST_SUCCEEDED player, 4 more | yes | only while the recorder is on | burst |
| D3 | Probe.lua:944-978 | 2 frames | probe on: 29 events with plain RegisterEvent, incl. UNIT_SPELLCAST_START/SUCCEEDED/CHANNEL_START/INTERRUPTED/STOP **for all units**, NAME_PLATE_UNIT_ADDED/REMOVED, UNIT_FLAGS (all units), ENCOUNTER_TIMELINE_*; UNIT_AURA player+target | yes | only while the probe is on | burst (all nameplates in M+) |
| D4 | AuraCatalogue.lua:564-567 | frame | aura log on: **UNIT_AURA for all units** (plain RegisterEvent) | yes | only while on | burst |
| D5 | AuraCatalogue.lua:550-551 | frame | PLAYER_REGEN_ENABLED, always | combat end | always (minor V14) | one-off |
| D6 | FormulaCapture.lua:271; :275-276 | frame | PLAYER_REGEN_ENABLED always; equipment / talents while armed | combat end | always (minor V14) | one-off |
| D7 | AuraIDProbe.lua:375-395 | frame + NewTicker 1 s | on demand | yes | only while on | periodic |
| D8 | CoreDebug.lua:731-737; CharacterWidthProbe.lua:75-76 | frames | whisper diagnostics; ADDON_ACTION_* | – | only while on | one-off |
| D9 | DevAssist.lua:277, 797 | OnUpdate | talent scan (one-off); window 0.5 s while shown | no | – | frame |
| D10 | DevRecord.lua (687b624) :374-396, :405-412 | via core DebugRecord SyncEvents | PLAYER_REGEN_DISABLED/ENABLED while recording; 10 game events while the Game category is on | edges | V14 ok | one-off |

---

## 3. Hot paths in combat

### 3.1 The engine loop (XayaUI/Engine.lua, 687b624)

How a step happens (code facts):

- Every rendered frame (:372): `acc`, `sinceStep` add up; `GetTime() >= Timing.NextDeadline()` is tested; a full Step runs when
  `acc >= TICK` (0.2 s) or when `dirty` and `sinceStep >= MIN_GAP` (0.05 s) or `forceNow`. So a full Step runs 5 to 20 times a
  second. Every OnEvent (:336) sets `dirty`; in combat, UNIT_AURA (player) and SPELL_UPDATE_COOLDOWN keep it set, so **INFERENCE**:
  in Mythic+ combat the engine runs close to 20 full steps a second.
- A full Step (:171-200, wrapped by IndexedStep :224-232 and SafeStep :360-370): `ns.ReadContext()`; `ns.tickID + 1`; for every rule
  `ns.RuleOff`, then `pcall(StepRule)` for each enabled rule (and each off rule once); `ns.Bars_Update` (nil on main).
- Per enabled rule (StepEnabled :75-126): `pcall(ns.Evaluate)`; `ns.RecTrigger` (Dev Assist); actions; edge sound and `ns.LogKind`;
  `DisplayWanted`; `Guarded(ns.SetVisualShown)`; `Guarded(ns.UpdateVisualText)` while shown. At least 4 pcalls per enabled rule per
  step, plus the pcalls inside the reads.
- In combat every 5 s (:382-387): `ns.LogStatusSnapshot("combat tick")`.

D4 routing (ba4ec01; not on main at 687b624, on main since 28380a9): OnEvent returns early for SPELL_UPDATE_COOLDOWN / SPELL_UPDATE_CHARGES (`routed.cd`) and UNIT_AURA
(`routed.aura`). On the next frame, if no full step is due, a routed Step runs with `stepFilter`: it reuses `lastCtx` (no
ReadContext), but still runs IndexedStep (Timing.ClearDeadline, BeginStepIndex, BeginVisualStep, FlushLayouts, EndStepIndex),
increments `ns.tickID`, and walks **every** rule in `ns.rules` calling `ns.RuleOff` and `Deps(rule)` to decide whether to step it.
Confirmed from code: while UNIT_AURA or SPELL_UPDATE_COOLDOWN arrive on consecutive frames, a routed step runs on each of those
frames (at most one per frame). **INFERENCE**: in M+ combat that is most frames.

Optimization candidates in the engine:

| Where | What costs | Why it matters | Fix idea |
|---|---|---|---|
| Engine.lua:179 → Conditions.lua:1612-1641 | ReadContext per full step: new `ctx` table, new `parts` table, `table.concat` signature with ~11 `tostring`, 8 LOAD_TRI reads + IsInInstance, UnitClass, CurrentSpec, GetActiveHeroTalentSpec, C_Map.GetBestMapForUnit, GetInstanceInfo, all in pcall | runs 5-20 times a second whatever the rules need; load facts change only on events | keep one context; refresh each fact on its event (REGEN, ZONE_CHANGED_NEW_AREA, GROUP_ROSTER_UPDATE, ENCOUNTER_*, PLAYER_MOUNT_DISPLAY_CHANGED, PLAYER_UPDATE_RESTING, spec / talent events) or at most once a second; rebuild `sig` only on change. Note: engine session commit 0f3151b adds GetNumGroupMembers here (PERF-CODE-NOTES.md) |
| Engine.lua:186-193 (and the routed path at ba4ec01:226-246) | every step walks all rules; routed steps too | O(all rules) per frame with D4, even when 3 rules read auras | keep per-bucket lists (`cdRules`, `auraRules`) rebuilt on `ns.configVersion`; a routed step iterates only its bucket |
| ba4ec01 IndexedStep + `ns.tickID + 1` | each routed step invalidates the per-tick caches: evalCache (Conditions.lua:1811), StepMemo tables, HasOutcomes (Outcomes.lua:363) | the cost of a "light" re-check includes rebuilding shared caches | let a routed step keep tickID-scoped caches that it does not change, or give it its own sub-tick |
| Outcomes.lua:361-371 | HasOutcomes makes `hasOut = {}` and walks all rules on the first call of every tick (KindHas → HasOutcomes, Core.lua:595) | one table + one full loop per step; per frame with D4 | cache per `ns.configVersion` (rule list edits call MarkDirty), or read `RuleIndex().kids` |
| Engine.lua:53, 62, 95, 101, 122 → Core.lua:581-600 | `ns.KindHas` (→ HasOutcomes, RuleKind → TopFolder chain walk) called 3-5 times per rule per step; `ns.EngineOwns` twice | repeated work with the same answer until an edit | cache kind / hasSound / hasVisual per rule per `configVersion` |
| Engine.lua:96, 102, 106 → Core.lua:111-136 | every fire / repeat / clear: `ns.Log` formats two strings, appends to logBuf, `ns.Fire("LOG")`, ConsoleSink, RecordLine; "cleared" also builds `ns.WhyNot(info)` (table + concats, Conditions.lua:1909-1918) | string work in combat on every edge, read by nobody unless the console or record is open | store raw values in the ring buffer and format on read; build WhyNot only when a reader exists |
| Engine.lua:382-387 → Conditions.lua:1930-1958 | combat snapshot every 5 s: ReadContext + one 5-part string key per enabled rule + ns.Log lines | allocation every 5 s that scales with rule count | compare stored fields, not a concatenated key; skip when no reader |
| Engine.lua:48-51 | `Guarded(rule, rt, function() ... end)` makes a closure per sound played | per fire only | file-level function with arguments |
| Engine.lua:372-391 | with zero enabled rules the OnUpdate still runs every frame and Step still runs at 5 Hz with ReadContext | fixed cost with nothing to do | stop the OnUpdate when no rule is enabled or previewed; restart on MarkDirty |

### 3.2 Rule evaluation (XayaUI/Conditions.lua, Triggers.lua, Cues.lua)

| file:line | What costs | Fix idea |
|---|---|---|
| Conditions.lua:44-55 | ReadCooldown memo key: a 3-part string per exact-spell or charge rule per step | numeric key or a two-level table |
| Conditions.lua:229, 280 | ReadCooldownRaw: new `r` table per distinct spell per step; `r.why` string for every charge spell per step | pool `r` per key per step; build `why` only when `ns.statusDetail` |
| Conditions.lua:188-218 | WatchCharges on every SPELL_UPDATE_CHARGES (and REGEN, spells, talents): new `done`, new `ids`, a 2-element table per enabled rule and per cooldown row, a `{ exactSpell = }` table per id (:207), GetSpellCharges per spell | precompute the charge-spell list on `configVersion` / SPELLS_CHANGED; reuse tables; pass exactSpell as an argument |
| Conditions.lua:405-421, 366-393, 359 | BuildCDMIndex at most every 0.25 s while any rule asks: `{ v:GetChildren() }` per viewer, per icon a new `ids` table, an `Add` closure and a 3-string literal `{ "spellID", ... }`, a `{ fr, vname }` pair per index entry, a new `idx` | rebuild on Cooldown Manager change signals (OnCooldownIDSet is already hooked, Timing.lua:70; COOLDOWN_VIEWER_* events); hoist the literal and closure; reuse tables |
| Conditions.lua:576 | CDM path of BuffPresentRaw builds `"CDM frame (" .. vname .. ": " .. detail .. ")"` with CDMDetail's `format` of 4 `tostring` for every CDM-answered aura, every step | Timing.lua:107 already does the right thing (`ns.statusDetail and string.format(...) or "estimate"`); do the same here |
| Conditions.lua:1093, 1062 | `src .. " \| time: " .. ...` per present aura per step; `"model estimate (" .. note .. ")"` | same: plain constant unless `ns.statusDetail` |
| Conditions.lua:528-551 | MakeRef: a new ref table per present aura read per step | pool per id per step (the presence memo already exists); check that no reader keeps a ref across steps first (runtime `rt.info`, FX `fr.fxInfo` hold infos, not refs; **INFERENCE**: needs a check) |
| Conditions.lua:617, 621 | DurationObjectTimes: two closures per call (`pcall(function() return obj:GetRemainingDuration() end)`) | `pcall(obj.GetRemainingDuration, obj)` |
| Conditions.lua:1386-1418 | CheckTalents per rule with talents, per step: `list` and `parts` tables, a string per talent, `table.concat`, IsPlayerSpell per talent (twice for "all" misses) | memo per rule per (`configVersion`, talent generation from TRAIT_CONFIG_UPDATED / SPELLS_CHANGED); detail only for status |
| Triggers.lua:1002-1025 | CheckExtraTriggers: new `rows` and `whys` tables per rule with rows, per step; `"row " .. i .. ": "` string on unknown | reuse per rule like `ns.InfoFor`; build `firstWhy` lazily |
| Triggers.lua:1099-1131 | CombineTriggers non-default mode: TriggerValues builds a list of small tables per call | iterate in place |
| Cues.lua:37-56, 153-161 | CuesOf / ConditionsOf / CueGated outside a step (AuraDisplay SyncLive, Options) make a new list and scan all rules | cache per `configVersion` |
| Conditions.lua:864-890; Triggers.lua:1262-1288 | glow, movement, rune, totem, bag, loss-of-control events mark the engine dirty even when no rule reads them | register per trigger type in use, rebuilt on `configVersion` |

### 3.3 Displays (XayaUI/Visual.lua)

UpdateVisualText (:2574-2875) runs per shown display per step, and per animated display from FxOnUpdate up to 30 times a second
(:2376-2390, `acc < 0.033`).

| file:line | What costs | Fix idea |
|---|---|---|
| :2631 | `fr.glow:SetSize(...)` on every call while glowing | set on change |
| :2639, 2655, 2668 | `fr.baseTint or { 1, 1, 1, 1 }`, `v.fadeColor or { 1, 0.1, 0.1, 1 }`: a table per call when unset | file-level constant tables |
| :2683-2684 | `pcall(fr.tex.SetDesaturation, ...)` and `fr.tex:SetVertexColor(...)` every call | keep last values on the frame; call on change |
| :2695 | `UnitAffectingCombat("player")` per call when oocAlpha < 1 | use the engine's combat flag (Engine.lua:17 `inCombat`) |
| :2713 | `fr:SetAlpha(alpha)` every call | on change |
| :2744 | wipe key `math.floor(p * 2000) .. dir`: a string per FX frame per display with a fill | two numeric fields |
| :2806 | path 1: `fr.text:SetText(FmtRemaining(...))` every step even when the shown second did not change | key by whole second (as the tenths path already does at :2779) |
| :2828 | path 2: `SetWholeSeconds` formats `"%d"` every step | same keying is impossible with a secret value; leave (the game draws it) or use the duration-text binding as path 4 does |
| :2376-2397 | one OnUpdate per animated display, each a pcall of the whole UpdateVisualText fxOnly path | one shared driver over a list of animated frames; a dedicated FX function that only touches fade / wipe / flash / tenths |
| :603-770 LayoutDynamic | on a member show / hide in combat (QueueLayout → FlushLayouts once per group per step): 4 new tables, 2 loops over all rules (:611, :615), `set` closure per item (:662), `Put` closure (:693), 2-3 `table.sort` with closures, new `lines` tables, `Container(df)` re-applies size, scale, alpha, strata, ClearAllPoints and SetPoint (:450-482) | member list per group cached on `configVersion`; Container re-anchor only when its inputs changed; file-level comparators |
| :852-874, :810-851 | group box Auto watcher every 0.2 s: GroupBounds walks every display frame (`pairs(frames)`) with InFolder (folder chain; FolderById is a linear scan outside a step), GetRect / GetEffectiveScale; `SetBackdrop({ ... })` with a new table every tick when a border is on (:846); `{ 0, 0, 0, 0.45 }` default (:836) | re-measure only when a member shows, hides or moves (SetVisualShown / LayoutDynamic already know); SetBackdrop only when border settings change |
| :2898-2924 SetVisualShown | per enabled rule per step: IsPreview, RuleOff, EngineOwns, Unl, GroupUnl (folder walk only while a group is unlocked) | fine; early-out already exists for `fr:IsShown() == want` |

### 3.4 Combat aura engine (XayaUI/Combat/AuraDisplay.lua)

| file:line | What costs | Fix idea |
|---|---|---|
| :1168-1169 | SyncLive every 0.25 s, always | event-driven: after each engine step that changed `ctxOK` / `talentOK` / cue results, on unlock hooks (already there), on MarkDirty |
| :936-946 → :221-243 Allowed | per slot per tick: `ns.SpellOnActionBar`; for a cue display `ns.CueGated` → `ns.ConditionsOf` outside a step → new list + scan of all rules (Cues.lua:47-56); `RuleUnlocked` → FolderUnlocked (cheap unless a group is unlocked) | cache CueGated per `configVersion` |
| :911-917 ApplyMods | per cue slot with mods, per tick: signature string from 2 `tostring` + `table.concat({ t[1], ... })` (a new table) | compare 6 stored numbers |
| :953-967 | dynamic group with changed members: `ids = {}` and `{ includeSpellIDs = ids }` per change | only on change; acceptable |
| :1170 | GuardCheck every 5 s: two C_AddOnProfiler reads | fine; only when auto drawing is on (currently always) |
| :1176-1183 RefreshUnit | target / focus change: loops all slots, UpdateAllAuras on matching ones | fine |
| :822-905 D.Build | 1 s after every MarkDirty and at each loading screen; ends with RefreshAllVisuals (:817-819) | see 4.1: RefreshAllVisuals is the expensive part |

### 3.5 Other in-combat paths

| Addon | file:line | What costs | Fix idea |
|---|---|---|---|
| QoL | CursorTrail.lua:205-320 | per frame: GetCursorPosition, scale, then `for i = 1, nDots` (:263) over up to `NRIB = 400` dots (ribbon) or `NPT = 48`, also when no dot is alive; per live dot SetVertexColor (+ SetSize on change); the cap (:306-318) calls SetBlendMode, SetSize, ClearAllPoints, SetPoint every frame while fading | keep a live-dot count and return early at 0; walk only the live ring segment; cap: set blend / size on change; add "hide in combat" |
| QoL | CursorHighlight.lua:214-229 | per frame ClearAllPoints + SetPoint even when the cursor did not move; UnitAffectingCombat per frame with combatOnly | compare last x / y; REGEN events for combatOnly |
| QoL | CharacterToolkit.lua:2188-2189 → CharacterModel.lua:956-980 | SPELL_UPDATE_COOLDOWN → ReadGCD: GetSpellCooldown (pcall wrapper), GetHaste, and a new `{ dur, haste }` table when readable, with the panel closed | register SPELL_UPDATE_COOLDOWN and the stat events only while the panel is shown; reuse the table |
| Chat | Frame.lua:664-682 | Upkeep every 0.3 s: `C.Glued` → `C.Frames()` new table (Core.lua:190-200); `C.ToBottomUpdate` → `C.Frames()` again + a `C.Try` closure per chat frame (:413); `hint:SetText` every tick (:680); every 3 s `C.Parts` with closures | cache the frame list on UPDATE_CHAT_WINDOWS; SetText on change; file-level functions |
| Chat | Scroll.lua:103-114, :41 | per-frame Tick; Update every 0.1 s with a pcall closure in ScrollPos | method pcalls; update on scroll / message events |
| Chat | Messages.lua:36 | `"message-handler-" .. i` per handler per chat message, inside C.Try (pcall) | precompute the names |
| Bonus | DataPanels.lua:342-354, 165-171, 72-82, 177 | per-frame accumulator; every 1 s SetText on every slot (format with label colour), AllKeys (new tables, sort with closure, at most once a second), Layout with a new options table and closure for AUTO sizing; every 0.1 s Cfg + IsMouseOver per panel | SetText on change; OnEnter / OnLeave for mouseover; hide in combat is an option already |
| Bonus | NotepadShare.lua:626, 286-294 | CHAT_MSG_ADDON for every addon message (DBM / BigWigs / WeakAuras traffic in groups, **INFERENCE**); early return on prefix | acceptable; optionally register only while in a group |
| Bonus | Tooltips.lua:705-708 | 9 post-calls; spell / item hover with IDs on: AurasFor builds tables, closures and lookups (:200-240); unit hover in M+: forces line with a closure in pcall (:112) | method pcalls; cache per id |
| Core | Timing.lua:64-71 | hooks on every Cooldown Manager icon: GetTime + field writes per icon aura update | fine (cheap); permanent |
| Core | Combat/AuraModel.lua:669-689 | per own cast: windows, `M.OnCastWindows`; while learning: SnapshotAuras and After(0.4) closure | only while learning; fine |

No COMBAT_LOG_EVENT_UNFILTERED handler, no NAME_PLATE handler and no all-unit UNIT_AURA handler exists in shipping code outside Dev
Assist (checked: `git grep -nE 'COMBAT_LOG_EVENT|NAME_PLATE_UNIT|UNIT_AURA' 687b624 -- 'XayaUI*/*.lua' ':(exclude)*/Libs/*'`).

---

## 4. Known costs reported by other sessions: verification

| Report | Verdict | Evidence |
|---|---|---|
| S3 G7: ApplyGroupArrangement loops all `ns.rules` per arranged group on refresh / drag / nudge; RefreshAllVisuals ≈ rules-in-arranged-groups × all rules | **Confirmed, and worse.** RefreshAllVisuals (Visual.lua:2961-2990) calls RefreshVisual per rule; RefreshVisual calls `ArrangeAfter(rule)` (:2249) for every display in a static group; ArrangeAfter → ApplyGroupArrangement (:1616-1631): a loop over all rules to collect members, ArrangeList (sorts with closures, :1565-1612), then `Place` per member, each through `ParentFor` → `Container` (:450). So per refresh: m arranged members × (all rules + m Place calls). With G9 fit on the same group, each Container also runs ItemsExtent (another loop over all rules): m × m × rules (**INFERENCE** from the call graph). Mostly out of combat: RefreshAllVisuals runs at OnDBReady, after every edit (AuraDisplay D.Build 1 s later, :817-819), at loading screens (D.Build on PLAYER_ENTERING_WORLD) and on unlock. Drag: CommitDrag → ArrangeAfter (:1664); nudge: :3101. |
| Same pattern for dynamic groups (not reported) | **Found.** RefreshVisual calls `LayoutDynamic(dyn)` (:2249) for every member of a dynamic group, and LayoutDynamic loops all rules twice (:611, :615). So RefreshAllVisuals is O(dynamic members × rules) too. Fix for both: during RefreshAllVisuals mark groups dirty and lay out / arrange each group once at the end. |
| S3 G9: Scale to fit with cFit loops all rules per Container(f) | **Confirmed.** Container (:450-484) calls `ns.GroupFitScale(f)` when `f.cFit` (:453) → GroupFitNeeded → ItemsExtent (:423-438), a loop over all rules. Container runs for every RefreshVisual of a member (ParentFor :493-503), recursively for every child group (:457-458: a child's Container calls its parent's), from LayoutDynamic (:692) and, while dragging a group handle or mover tag, every frame (:1196, :1343). In combat: a dynamic group nested in a static fit group re-measures on every member show / hide (LayoutDynamic → Container(df) → Container(parent)). Fix: memo the fit factor per group per `configVersion` (positions change only through edits / drags, which bump it or can clear it). |
| S3: group auto-size 0.2 s OnUpdate watcher | **Confirmed.** Visual.lua:852-874. Runs while at least one group has a border or background and Auto size; stops itself otherwise (V14 holds). Runs in combat. Per tick per such group: GroupBounds over all display frames with a folder-chain walk each, a new backdrop table and SetBackdrop when a border is on. |
| Engine D4 routed re-checks may run every frame while aura events stream | **Confirmed on ba4ec01 (on main since 28380a9).** OnEvent sets `routed.aura` / `routed.cd` and returns (Engine.lua:408-410 at ba4ec01); the OnUpdate runs a routed Step on the next frame when no full step is due (:441-447 at ba4ec01). At most one per frame, but nothing limits it below the frame rate. Each routed step walks all rules (Deps is cached; the loop is not), bumps `ns.tickID` (resets evalCache, StepMemo, HasOutcomes) and runs the step-index setup. The commit message reports a stand-in benchmark (not in game); no in-game number exists. |
| Bar cues: per moving bar an effects OnUpdate ~30/s out of combat | **Confirmed, with detail.** `BarCueUpdate` (BarCue.lua:742-780 on 9c5e201) returns true only for a readable fraction (`f ~= nil`), which keeps FxOnUpdate running (Visual.lua diff: `wantsFx ... or barMoving`); with secret times in combat the bar is driven by `SetTimerDuration` and returns false, so no FX (**INFERENCE**: in M+ combat most player aura times are secret). Per FX frame per bar: `ns.BarCueSource` → `OwnerOf` → `ns.FindParentRule` outside a step = a linear scan of `ns.rules` (Outcomes.lua:24-33), once in BarCueUpdate and once more in the `wantsTenths` test when decimals are on; `SetMinMaxValues(0, 1)` and `SetShown` on every frame (SetValue :719-726). Fix: cache the owner per cue per `configVersion`; set min / max once at layout. |
| Bonus "Type colours" line scan per hover | **Confirmed.** `TT.ColorTypes` (Tooltips.lua on 9c5e201) runs on every spell and aura tooltip post-call while the section is on (default on in that branch): GetName, NumLines, then per line a string concat (`name .. "TextLeft" .. i`), a `_G` lookup, GetText, and `ns.BarColorizeTypes` (returns at once when the line has no "damage"; otherwise gmatch, a table and `table.concat`). Runs in combat on hover. Cost class low per hover; higher if the game refreshes the same tooltip repeatedly (**INFERENCE**). Fix: skip when `data` and line count are unchanged for the same tooltip, cache the font string list per tooltip name. |

---

## 5. Existing measurement tools and their gaps

### 5.1 `/xui debug perf` (ns.PerfCommand, Engine.lua:202-311)

- On (`/xui debug perf on`): PerfReset (:205-212) clears counters and stores `collectgarbage("count")`.
- Per Step (:233-240): total ms, step count, worst step, via `debugprofilestop`.
- Per enabled rule (:76-78, :118-125): evaluation ms and visual ms, summed per rule (`perf.rule`).
- Bars (:195-197): ms (nil function on main).
- FX: Visual.lua:2382-2384 adds per-frame effect ms and call count through `ns.PerfAdd("fx")`.
- Duration-text paths: Visual.lua path counters through `ns.PerfPath` (only while measuring).
- Events: counts per event name, **only for the engine's own frame** (:337).
- Report (:270-310): steps/s, avg / worst ms, % of a 60 fps frame, per-second ms for rules / visuals / bars / effects, top 5 rules,
  Lua memory now and KB/s since start, event rates, path counts, and the game's meter for the top 8 loaded addons
  (`C_AddOnProfiler.GetAddOnMetric(name, RecentAverageTime)` and `PeakTime`, :243-257). Each report is saved to `CueRulesDB.perfLog`
  (last 6 only, :305-310).

### 5.2 Dev Assist "perf" category (XayaUI_DevAssist/DevRecord.lua at 687b624)

- Category definition :42 (default off; cost text "a small timer on every engine step, in combat only").
- PLAYER_REGEN_DISABLED (:374-384): if Perf is on and the player has not started perf, runs `PerfCommand("on")`.
- PLAYER_REGEN_ENABLED (:385-396): writes the PerfCommand report lines into the record ("perf" kind), then turns perf off again.
- So each combat gets its own engine report, written to the debug record, with the meter's top-8 line.
- Working tree only (uncommitted at the time of writing, another session): DevRecord adds `DR.AddonMeterLines` (per loaded XayaUI
  addon, plus all addons and the whole game: SessionAverageTime, RecentAverageTime, EncounterAverageTime, PeakTime,
  CountTimeOver5/10/50/100Ms) at combat end and boss end. Not part of 687b624.

### 5.3 Other `debugprofilestop` uses

AuraSources.lua:146-147 (4 ms budget per frame for a scan), Options.lua:7267-7268 (budgeted list build), Options.lua:7908-7913 and
Skin.lua:428-437 (settings window build timing, `/xui debug perf ui`, Dev Assist). None of them measures combat features.

### 5.4 The game's meter (C_AddOnProfiler), from docs/reference/api/api.json (12.1.5, build 70783)

Functions (signatures as documented; the documentation has no description text for any of them):

```
C_AddOnProfiler.AddMeasuredCallEvent(name: stringView)                                   [SecretArguments=AllowedWhenUntainted]
C_AddOnProfiler.AddPerformanceMessageShown(msg: AddOnPerformanceMessage)                  [HasRestrictions, SecretArguments=AllowedWhenUntainted]
C_AddOnProfiler.CheckForPerformanceMessage() -> msg: AddOnPerformanceMessage              [MayReturnNothing]
C_AddOnProfiler.GetAddOnMetric(name: cstring, metric: AddOnProfilerMetric) -> result: number            [SecretArguments=AllowedWhenUntainted]
C_AddOnProfiler.GetApplicationMetric(metric: AddOnProfilerMetric) -> result: number                     [SecretArguments=AllowedWhenUntainted]
C_AddOnProfiler.GetOverallMetric(metric: AddOnProfilerMetric) -> result: number                         [SecretArguments=AllowedWhenUntainted]
C_AddOnProfiler.GetTicksPerSecond() -> frequency: BigInteger
C_AddOnProfiler.GetTopKAddOnsForMetric(metric: AddOnProfilerMetric, k: number) -> results: table<AddOnProfilerResult>   [SecretArguments=AllowedWhenUntainted]
C_AddOnProfiler.IsEnabled() -> enabled: bool
C_AddOnProfiler.MeasureCall(func: LuaValueVariant, arguments: LuaValueVariant) -> results: AddOnProfilerCallResults, returns: LuaValueVariant   [SecretArguments=AllowedWhenUntainted]
```

`Enum.AddOnProfilerMetric` (docs and live client agree): SessionAverageTime = 0, RecentAverageTime = 1, EncounterAverageTime = 2,
LastTime = 3, PeakTime = 4, CountTimeOver1Ms = 5, CountTimeOver5Ms = 6, CountTimeOver10Ms = 7, CountTimeOver50Ms = 8,
CountTimeOver100Ms = 9, CountTimeOver500Ms = 10, CountTimeOver1000Ms = 11.

Structures: `AddOnProfilerCallResults { elapsedMilliseconds, elapsedTicks, allocatedBytes, deallocatedBytes, events:
table<AddOnProfilerCallEvent> }`, `AddOnProfilerCallEvent { name, allocatedBytes, deallocatedBytes, elapsedMilliseconds, elapsedTicks }`,
`AddOnProfilerResult { addOnName, metricValue }`.

### 5.5 Gaps: what cannot be measured per feature today

| Gap | Why |
|---|---|
| Per feature inside one addon | GetAddOnMetric is per addon. Inside XayaUI the engine is timed, but AuraDisplay SyncLive (0.25 s ticker), GuardCheck, the group box watcher, WatchCharges, the glow / trigger event handlers, LayoutDynamic and RefreshAllVisuals are not. Chat, QoL, Bonus, Reskin have no timers at all. |
| Per event handler | `perf.events` counts only the engine frame's events, and counts, not times. |
| Allocation per feature | `collectgarbage("count")` is the whole Lua heap of every addon, so "KB/s since start" (Engine.lua:291) is not XayaUI's alone and is moved by collection cycles (**INFERENCE**). |
| Attribution inside the engine | A parent's evaluation is charged to whichever rule (or cue) asks first in that tick (evalCache), so per-rule ms for cues and their parents are skewed. FX time is one total, not per display. |
| Coverage | The Dev Assist perf category times combats only; the 5-20 Hz out-of-combat steps, loading screens and RefreshAllVisuals are not covered. `CueRulesDB.perfLog` keeps 6 reports; a Mythic+ has more pulls (the debug record keeps them if recording). |
| Observer effect | With perf on, every enabled rule gets 2-4 extra `debugprofilestop` calls per step. Size unknown (**INFERENCE**: small). |
| Meter semantics | No documentation text. Units (ms per frame) and "Recent" window length are **INFERENCE** (Engine.lua and AuraDisplay.lua read them that way). EncounterAverageTime exists, so boss pulls have a per-encounter number; M+ trash pulls have none. |
| Possible new tool | `C_AddOnProfiler.MeasureCall(func, args)` returns elapsed time and allocated / deallocated bytes for one call, and `AddMeasuredCallEvent(name)` appears to tag sections inside it (**INFERENCE** from names and the structure; untested in game; its own overhead unknown). Wrapping SyncLive, the box watcher, WatchCharges or a Chat Upkeep in it while a debug switch is on would give per-feature time and allocation. Event handlers called by the game can only be measured if the handler itself calls MeasureCall on its body. |

---

## 6. Optimization candidates (ranked)

Impact class is **INFERENCE** from frequency × work per call; no timing exists. "Combat" = runs in combat. Ranked by expected gain
for a Mythic+ player with a typical rule set; ties broken by risk.

| ID | Addon | Feature | file:line | Issue | Suggested fix | Impact | Risk | Combat |
|---|---|---|---|---|---|---|---|---|
| PA-1 | XayaUI | Engine context | Conditions.lua:1612-1641 (from Engine.lua:179) | New ctx + parts tables, concat signature and ~14 pcall'd API reads on every full step (5-20/s) | Event-driven context, rebuilt only when a fact changes; sig rebuilt on change | high | med (a missed event = stale load answer) | yes |
| PA-2 | XayaUI | D4 routing (ba4ec01) | Engine.lua:206-246, 441-447 (at ba4ec01) | Routed re-check up to every frame walks all rules, bumps tickID (clears shared caches), runs step-index setup | Per-bucket rule lists by configVersion; keep tick-scoped caches; or cap routed checks per frame budget | high | med | yes |
| PA-3 | XayaUI | Displays | Visual.lua:2631-2713, 2744, 2806 | UpdateVisualText calls setters every step / FX frame without change checks; default tables; wipe key string; duration SetText every step | Cache last values on the frame; constant tables; numeric wipe key; text keyed by second | high | low | yes |
| PA-4 | XayaUI | Aura reads (CDM index) | Conditions.lua:405-421, 366-393, 359 | Index rebuilt every 0.25 s with tables and closures per icon | Rebuild on CDM change signals; hoist closure / literal; reuse tables | med-high | med | yes |
| PA-5 | XayaUI | Charges watcher | Conditions.lua:188-225 | Every SPELL_UPDATE_CHARGES: all rules walked, a table per rule and per id | Precomputed charge-spell list; no per-event tables | med-high | low | yes |
| PA-6 | XayaUI | Aura reads (source text) | Conditions.lua:576, 1062, 1093 | Debug source strings built per aura per step | Build only when `ns.statusDetail` (pattern of Timing.lua:107) | med | low | yes |
| PA-7 | XayaUI | Outcomes | Outcomes.lua:361-371 | HasOutcomes rebuilds a table + full loop every tick | Cache per configVersion | med | low | yes |
| PA-8 | XayaUI | Engine kind checks | Engine.lua:53, 62, 95, 101, 122; Core.lua:581-600 | KindHas / RuleKind / TopFolder 3-5× per rule per step | Cache per rule per configVersion | med | low | yes |
| PA-9 | XayaUI | FX driver | Visual.lua:2376-2397 | One OnUpdate per animated display, each a pcall of the full fxOnly path | One shared driver; a lean FX-only function | med | low | yes |
| PA-10 | XayaUI | Dynamic groups | Visual.lua:603-770, 450-482 | Layout on every member show / hide: tables, 2 full rule loops, closures, sorts, full Container re-anchor | Cached member lists; re-anchor on change; file-level comparators | med | low-med | yes |
| PA-11 | XayaUI | Combat engine sync | AuraDisplay.lua:936-978, 221-243, 911-917; Cues.lua:47-56 | 4 Hz ticker; CueGated scans all rules + allocates per cue slot; ApplyMods builds strings and a table | Event-driven sync; cached CueGated; numeric mod signature | med | med | yes |
| PA-12 | XayaUI | Rule checks (talents) | Conditions.lua:1386-1418 | Tables + strings + IsPlayerSpell per talent per step | Memo per configVersion + talent generation | med | low | yes |
| PA-13 | XayaUI | Rule checks (extra rows) | Triggers.lua:1002-1025 | rows / whys tables per rule per step | Reuse per rule; lazy why | med | low | yes |
| PA-14 | XayaUI | Aura refs | Conditions.lua:528-551, 617, 621 | New ref per present aura per step; 2 closures per duration read | Pool per id per step; method pcalls | med | med (ref lifetime) | yes |
| PA-15 | QoL | Cursor trail | CursorTrail.lua:205-320 (:263, :306-318) | Per frame loop over up to 400 dots even when none is alive; cap setters every frame | Live-dot count + early exit; set-on-change; "hide in combat" option | high when on (default off) | low | yes |
| PA-16 | QoL | Character Toolkit | CharacterToolkit.lua:2367-2376; CharacterModel.lua:956-980 | 29 events incl. SPELL_UPDATE_COOLDOWN while enabled, panel closed; table per GCD read | Register only while the panel is shown; reuse table | med when on (default off) | low | yes |
| PA-17 | XayaUI | Group box watcher | Visual.lua:852-874, 810-851 | 0.2 s re-measure of all frames per auto group; SetBackdrop with new table each tick | Re-measure on member change; SetBackdrop on settings change | med (users with auto boxes) | low | yes |
| PA-18 | XayaUI | Refresh pass (G7 / G9 / dynamic) | Visual.lua:2961-2990, 2249, 1616-1631, 423-453 | O(members × rules) and up to O(m² × rules) per RefreshAllVisuals, run 1 s after every edit and at loading screens | Batch layouts once per group per refresh; memo fit factor per group | med (out of combat; loading screens in M+) | low-med | mostly no |
| PA-19 | XayaUI | Log | Engine.lua:96-106; Core.lua:111-136; Conditions.lua:1909-1918 | Strings, table append, listeners on every fire / clear; WhyNot per clear | Store raw values, format on read; WhyNot only with a reader | low-med | low | yes |
| PA-20 | XayaUI | Combat snapshot | Engine.lua:382-387; Conditions.lua:1930-1958 | Every 5 s: ReadContext + string key per enabled rule | Field compare; skip without a reader | low-med | low | yes |
| PA-21 | XayaUI | Bar cues (9c5e201) | BarCue.lua:107-120, 719-726 | FindParentRule linear scan per FX frame per bar; SetMinMaxValues every frame | Cache owner; set min / max once | med out of combat, low in combat | low | mostly no |
| PA-22 | XayaUI | Cooldown reads | Conditions.lua:44-55, 229, 280 | Key strings, new `r` per spell per step, `why` strings | Numeric keys; pooled `r`; why for status only | low-med | low | yes |
| PA-23 | XayaUI | Unused trigger events | Conditions.lua:864-890; Triggers.lua:1262-1288 | 25 events mark the engine dirty whatever the rules read | Register per trigger type in use | low-med | low-med | yes |
| PA-24 | Chat | Panel upkeep | Frame.lua:664-682, 413; Core.lua:190-200 | 0.3 s: new frame lists, closures per chat frame, SetText every tick | Cached frame list; set-on-change; no closures | low-med (on by default) | low | yes |
| PA-25 | QoL | Cursor highlight | CursorHighlight.lua:214-229 | Re-anchor every frame; UnitAffectingCombat per frame | Move only on cursor change; REGEN events | low-med when on | low | yes |
| PA-26 | Bonus | Data panels | DataPanels.lua:342-354, 165-177, 72-82 | Per-frame accumulator; SetText every second; mouseover poll 10/s | Set-on-change; OnEnter / OnLeave | low-med when on | low | yes |
| PA-27 | XayaUI | Engine idle | Engine.lua:372-391 | OnUpdate + 5 Hz Step with ReadContext when no rule is enabled | Stop when nothing is enabled or previewed | low (high relative for users with no rules) | low | yes |
| PA-28 | XayaUI | AuraDisplay V14 | AuraDisplay.lua:1162-1171, 817-819 | Tickers and the MarkDirty → Build hook run with automatic drawing off | Create tickers only while slots exist; skip Build when auto is off | low | low | yes |
| PA-29 | Chat | Scroll bar | Scroll.lua:103-114, 41 | Per-frame Tick; 0.1 s Update with a pcall closure | Method pcall; event-driven update | low | low | yes |
| PA-30 | Bonus | Tooltips | Tooltips.lua:200-240, 112; ColorTypes (9c5e201) | Tables, closures and per-line string work per tooltip | Method pcalls; cache per id / tooltip | low | low | yes (hover) |
| PA-31 | Chat | Message bus | Messages.lua:36 | String concat per handler per message | Precomputed names | low | none | yes |
| PA-32 | DevAssist | Aura log / probe | AuraCatalogue.lua:566; Probe.lua:944-978 | All-unit UNIT_AURA / casts / nameplates while on | RegisterUnitEvent for the logged units; warn before M+ | high while on (dev only) | low | yes |
| PA-33 | Bonus | Addon messages | NotepadShare.lua:626 | CHAT_MSG_ADDON on by default, every addon message reaches the handler | Optional: register only in a group / while the Notepad is used | low | low (feature loss if gated) | yes |

Top 10 for the M+ baseline to confirm or drop: PA-1, PA-2, PA-3, PA-4, PA-5, PA-6, PA-7, PA-8, PA-9, PA-10. All are in XayaUI core.

---

## 7. Addons ranked by theoretical combat cost (INFERENCE; to be replaced by the M+ baseline)

| Rank | Addon | Default settings | Everything on | Reasoning |
|---|---|---|---|---|
| 1 | XayaUI | highest | highest | Only addon with always-on per-frame code plus 5-20 full steps/s in combat whose work grows with the number of enabled rules (evaluation, aura and cooldown reads with pcalls and allocations), plus per-display FX up to 30/s, a 4 Hz sync ticker, the charges watcher on every SPELL_UPDATE_CHARGES, 25 always-registered state events. With D4 merged, a rule loop up to every frame. |
| 2 | XayaUI_QoL | ~0 (all features off) | can rival core | Cursor trail runs every frame with up to 400 dots, in combat; cursor highlight every frame; Character Toolkit takes SPELL_UPDATE_COOLDOWN and 28 stat events while enabled. |
| 3 | XayaUI_Chat | low | low | On by default: 0.3 s upkeep with small allocations, per-frame scroll tick with 0.1 s work, 1 s data bar, handlers per chat message and per `print`. Nothing scales with combat events. |
| 4 | XayaUI_Bonus | low | low-med | Tooltip post-calls on hover (9 types), CHAT_MSG_ADDON on by default (cheap early return), data panels per-frame accumulator when on. |
| 5 | XayaUI_DevAssist | ~0 | high while probes run | Idle unless a tool is on; the probe and aura log register all-unit events (nameplates, casts, UNIT_AURA), which in M+ are frequent. The Perf category adds timers to every engine step in combat. |
| 6 | XayaUI_Reskin | ~0 | ~0 | Game menu only. |
| 7 | XayaUI_Options | ~0 | ~0 | LoadOnDemand; closed window leaves 3 hooks (AceConfigDialog Open / FeedGroup, GameTooltip_ShowCompareItem). |

---

## 8. V14 findings ("switched off must cost nothing")

| ID | Addon | file:line | What exists while off | Severity (INFERENCE) |
|---|---|---|---|---|
| V-1 | XayaUI | Combat/AuraDisplay.lua:1168-1171 | 0.25 s and 5 s tickers run with automatic engine drawing off (`/xuiengine auto off`, `db.auto == false`) or with no slot built | low |
| V-2 | XayaUI | Combat/AuraDisplay.lua:1166, 817-819, 822-905 | MarkDirty hook schedules D.Build (→ RefreshAllVisuals) 1 s after every edit with automatic drawing off | low (out of combat) |
| V-3 | QoL | CharacterToolkit.lua:2358-2376 | With the toolkit on but its panel option off (`c.panel`), the stat and GCD events (29) stay registered; their handler only serves the panel | med (combat bursts) |
| V-4 | XayaUI | Engine.lua:326-391 | With every rule off, the engine OnUpdate and the 5 Hz Step (ReadContext) still run (D7 made each off rule free, not the engine) | low |
| V-5 | XayaUI | Conditions.lua:220-225, 864-890; Triggers.lua:1262-1288 | Charge, glow, movement, rune, totem, bag, loss-of-control events are handled with no rule using those triggers | low-med |
| V-6 | Bonus | Tooltips.lua:697-710 | 9 tooltip post-calls stay after every section is switched off (no removal API; guarded by `TT.on`; documented in the code) | accepted residue |
| V-7 | Chat / QoL / Reskin / Options / core Timing | hooks listed in 2.3-2.6, Timing.lua:64-71 | permanent hooks that return while off (global `print`, `StaticPopup_Show`, `PanelTemplates_SetTab`, Cooldown Manager icons ...) | accepted residue |
| V-8 | DevAssist | AuraCatalogue.lua:550-551; FormulaCapture.lua:271 | PLAYER_REGEN_ENABLED registered at load whether or not the catalogue / capture is in use | negligible |
