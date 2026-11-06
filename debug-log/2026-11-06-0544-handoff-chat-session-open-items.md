# Handoff: session 014bN6tSuhd4nhS3kubHR58K ("Chat") -> a fresh session (docs only)
Logged 2026-11-06 05:44 UTC on `main` f9e7d16. Xaya, 2026-11-06: "If there's nothing left in this chat to solve at the moment, bundle
all lingering issues or comments issued and port to a new session ... to clear context". Nothing is running or unpushed in that
session; its PR #406 is merged (Chat 0.6.15-0.6.16 and QoL 0.7.21 are on `main` since 7426e7f).

**Her requests from that chat are already logged verbatim** as rows CHAT-1 to CHAT-10 in `docs/process/REQUEST-LOG-CROSS-CHAT.md`
(statuses and owners there; rule V15). This file adds only what that log does not hold: the questions still owed to her, the
evidence behind them, and the next unblocked work. Do not re-ask what a row marks answered.

## 1. Questions still waiting on Xaya (from that chat; none answered yet)
| Row | Question | Options / note | Owner |
|---|---|---|---|
| CHAT-3a | RM-BARS: build progress bars as a **new display kind** that shares the progress source with progress textures? | Recommended (WeakAuras does the same; evidence in `debug-log/2026-11-05-2018-*`). Yes / extend progress textures instead. | unowned |
| CHAT-3b (= S1 #40) | Disabled rules cost nothing: stop stepping a switched-off rule (`Engine.lua` StepRule -> StepDisabled) and build its frames when it is switched on, keeping the editor preview (`StepPreview`) for a rule being edited. | Her answer "ideally, yes" is logged (S1 #40); the engine session owns it and sends a proposal first (V16). WeakAuras evidence is INFERENCE only: `WeakAuras.lua` (231 KB) was too large for the Drive tool. If she wants it proven, she puts that file somewhere a session can read as a normal file. | engine session |
| CHAT-3c | Terms, interim: until the future "database we maintain", do `ProcGlows.lua` and `SetBonusAuras.lua` (built from client tables) stay in the shipped addon, and does the hold on adding new client-table data stay? | (Enchant Slots slot numbers: answered "Slot numbers are fine", S2-32.) | unowned |
| CHAT-3d | #372 Config tab: for an **imported** group, record "Imported" and the date only, or the sender's character name too? Groups made before the change show "not recorded". Replace the "Enable all" / "Disable all" buttons with one toggle? | Sender name = another player's name: under the personal-data rule it stays out of a default export. | unowned (S3 R12, R14) |
| CHAT-3e / CHAT-9 (= S1 #10, #39, #75, #76) | Pre-created rules: in the rule list from the start (switched off) or added from a separate list? Durability reminder: below what percent, or only when an item breaks? Once a player edits a pre-created rule, newer addon versions never overwrite it (suggested). | The DO NOT RELEASE cover design is already answered in the engine session (#75, #76). Pre-created rules should land after CHAT-3b, or each one costs players who never use it. | engine session |
| CHAT-5 | Friends (Blizzard UI Reskin tab): offline friends keep Blizzard's grey or show their last-known class? Search: filter Blizzard's own list (more taint risk) or a result list of ours? Custom friend groups: where they show (Blizzard's list, a XayaUI panel, the Chat Bar Friends block), whether whisper sounds use them, Battle.net friends / character friends / both? | ROADMAP #322, #323, RM-FRIENDGROUPS. | unowned |

## 2. Evidence already gathered (do not redo)
- WeakAuras behaviour check (reference folder, behaviour only, nothing copied): `debug-log/2026-11-05-2018-xaya-decisions-*.md`,
  section "WeakAuras sanity check": bars are their own display type there; group tab option lists (plain and dynamic); origin =
  name / URL / description only, no creator field, no group-level enable toggle.
- Friend colours: data documented in `docs/reference/api` (`BNetGameAccountInfo.classFilename`, structures.md 588-607;
  `FriendInfo.className` / `guid`, structures.md 3135-3146; `GetPlayerInfoByGUID`, globals.md 240). Not checked: the 12.1.5 hook point
  for a friend button and how Blizzard composes a Battle.net friend's name line (needs the UI source, Gethe/wow-ui-source).
- `/notes`, `/calc`: possible; today `/xui notes` (`XayaUI_Bonus/Notepad.lua`) and `/xui calc` (`Calculator.lua`). Plan (ROADMAP
  section 6): register a word only if no addon has taken it, and only while that utility is on (V14). Blizzard's own 12.1.5 command
  list not checked.

## 3. Next unblocked work (no decision needed)
1. CHAT-6 `/notes` and `/calc` (low lift; the plan above). Check the word is free at registration time.
2. CHAT-5 groundwork: confirm the friend-button hook point and the Battle.net name line in the 12.1.5 UI source, then size it
   exactly; build only the colour part (offline colour waits on her answer, default Blizzard's grey until then).

## 4. In game, not seen yet (from that chat)
QA E1z21 (Stat Calculator 450 wide, Rating "528 +172"), D11 (history: active tab, All last, whisper tabs by name and realm).
Two INFERENCES in D11: a Battle.net whisper window's chatTarget equals the message's Battle.net ID; `CHAT_MSG_WHISPER_INFORM`'s author
is the person whispered.
