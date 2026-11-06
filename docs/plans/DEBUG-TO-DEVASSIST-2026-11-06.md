# Debug tools that could move to Dev Assist (inventory, 2026-11-06)

Request: REQUEST-LOG FUS-1 and FUS-2 (Xaya, 2026-11-06, her words verbatim in the log). Built from `main` 22abdeb by reading the
code (`git grep` for `RegisterDebugCommand`, `AdvancedDebugOn` / `advancedDebug`, `SLASH_*`, the Settings > Debugging page in
`XayaUI_Options/Options.lua`, `DebugRecord.lua` `DR.CATS`). **Nothing has been moved.** Each row has a proposal waiting for her answer (V16).

## How a move would work (read from the code)
- XayaUI Dev Assist (`XayaUI_DevAssist`) is a separate addon with `## OptionalDeps: XayaUI`, so it loads after XayaUI. It already reaches
  XayaUI's shared namespace (`_G.XayaUI_NS`) and plugs into it (`Probe.lua` offers the "gameDataProbe" service through `ns.Provide`).
  So a diagnostic command can be registered from Dev Assist with core's own `ns.RegisterDebugCommand`, and it still reads the same data.
- What a player gains: an addon that is not installed or is switched off is never read (V14's strict "never loads"). Without Dev Assist,
  the moved commands, settings and help lines are simply not there.
- What it costs: a tester (Xaya) needs Dev Assist enabled to use them. A moved command keeps working only while the core data it reads
  stays where it is.
- Honest size of the gain (from the code, not measured in game): a `/xui debug` command costs nothing until it is typed, apart from its
  file being read at login. So moving the commands mostly removes clutter and login parse work. The one thing that costs a player
  something **while playing** is the debug record behind Advanced Debugging, which is **on by default** (`Core.lua:729`). That is row C1.

## A. Move to Dev Assist (developer diagnostics; proposed: move)
| # | What | Where now | What it does |
|---|---|---|---|
| A1 | Aura ID "via ..." source text | `XayaUI_Bonus/Tooltips.lua` `TT.SourcesOn` (gated on Advanced Debugging) | Says where each Aura ID came from. Her FUS-1: "into dev assist". See question 1. |
| A2 | `/xui debug probe <spellID>`, `probe ids` | `XayaUI/Core.lua` | Reads a spell's / aura's raw answers |
| A3 | `/xui debug timing` | Core.lua | How every cue gets its time in combat |
| A4 | `/xui debug model [setup\|<id>]` | Core.lua | The combat aura duration model |
| A5 | `/xui debug tracker [shadow\|status]` | Core.lua | The combat aura tracker's state |
| A6 | `/xui debug mods` | Core.lua | Each cue's modifiers, step by step |
| A7 | `/xui debug groups` | Core.lua | Each group and where its displays hang |
| A8 | `/xui debug icons` | Core.lua | Which eye / headphone icons the settings window uses |
| A9 | `/xui debug media` | Core.lua | How many pictures and sounds XayaUI_Media lists |
| A10 | `/xui debug seed` | Core.lua | Adds three Vengeance Demon Hunter **test rules** to the player's own rules |
| A11 | `/xui debug map` | Core.lua (core 0.6.49) | World map full-screen report (her #30 bisect) |
| A12 | `/xui debug gamemenu` | `XayaUI/GameMenu.lua`, `XayaUI_Reskin/GameMenuSkin.lua` | The ESC menu button and skin report |
| A13 | `/xui debug chatprobe` | `XayaUI_Chat/Probe.lua` | Read-only chat frame report |
| A14 | `/xui debug widthprobe` | `XayaUI_QoL/CharacterToolkit.lua` | The one-off character window width test (its result is already built in) |
| A15 | `/xui debug perf ui` | Core.lua | Settings window rebuild timing |
| A16 | `/xui debug debuffs`, `/xui debug loc` | Core.lua | Raw debuffs on target / focus; loss of control right now |
| A17 | `/xuitt probe`, `/xuitt lines`, `/xuitt aura` | `XayaUI_Bonus/TooltipsUI.lua` | Raw tooltip lines and aura source reports |
| A18 | `/xui chat wrap`, `/xui chat indent`, `/xui chat whispers` | `XayaUI_Chat/Core.lua` | Measurements printed for bug reports |
| A19 | `/xuiskin pad N`, `/xuiskin alpha X` | `XayaUI/Modules.lua` | Tunes the settings window's look. USER-GUIDE lists `/xuiskin` (skin off) and `alpha` for players: see question 4. |
| A20 | "Also run the game-data probe (XayaUI Dev Assist)" | Settings > Debugging | Already a Dev Assist feature; only its switch sits in core's page |

## B. Keep for players (proposed: keep)
| # | What | Why keep |
|---|---|---|
| B1 | `/xui status`, `/xui auras` (shortcuts in chat) | Her choice on 2026-11-06 ("Debug + shortcut"); they answer "why is my rule not showing" |
| B2 | Console window, "XayaUI's messages" (chat / console / both) | Where every XayaUI message goes |
| B3 | Bug report, error log, "What to send" | How a player sends her a problem |
| B4 | `/xui debug loader` | For when `/xui` will not open the settings window: a player needs it most then |
| B5 | `/xui debug talents` / `/xui talents`, Scan all talents now | Rule creation uses it (Settings > Rule Creation) |
| B6 | Combat Tracking Setup | A player feature (estimates buffs the game hides). It sits on the Debugging page; question 3 |
| B7 | `/xui reskin status`, `/xui shop status`, `/xui stats status`, `/xui chat` | Say what a feature is doing; short and used in support |

## C. Her call (each changes what players have)
| # | What | Options |
|---|---|---|
| C1 | **Advanced Debugging and the debug record** (`XayaUI/DebugRecord.lua`; 11 kinds of line, 8 on by default; Advanced Debugging on by default) | (a) keep in core, **off by default**; (b) move the whole record to Dev Assist (a tester installs Dev Assist to record and send); (c) keep as it is |
| C2 | `/xui debug perf` (the engine meter) | Useful to a player asking "is XayaUI slow?"; move or keep |
| C3 | `/xuiengine` (auto on / off, off / reset <group>, full, refresh) | Engine controls; "full" leaves lean mode, which a player may need. Move or keep |
| C4 | `/xui debug status` and `/xui debug auras` (the console forms) | The chat shortcuts (B1) stay either way; the console forms could go with Dev Assist |

## Questions for Xaya
1. FUS-1, the "via ..." text: (a) on the tooltip, but only while the XayaUI Dev Assist addon is enabled; or (b) off the tooltip,
   printed by a Dev Assist command (`/xuidev aura <spellID>`)?
2. Section A: move all of it, or which rows to keep?
3. Combat Tracking Setup (B6): leave it on the Debugging page, or move it out to Settings > UI Options > Rule Creation?
4. `/xuiskin`: the guide offers `/xuiskin` (skin off) and `alpha` to players. Move only `pad`, or all of it?
5. C1-C4: which option for each?

## Coordination (V17)
The rows touch files other sessions own (Bonus Tooltips: S2; Chat: the Chat session; QoL toolkit, core and Options: S1). Built as one
round and landed once through S1 after her answers.
