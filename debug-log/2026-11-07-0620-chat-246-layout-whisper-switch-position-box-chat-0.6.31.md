# 2026-11-07 06:20 UTC: Chat settings laid out from Xaya's #246 words, whisper-tab switch, exact X / Y box (Chat 0.6.31, Dev Assist 0.7.13)

Session 014bN6tSjceDcH6FdJCeukZG. REQUEST-LOG A14 CHATREV-10, CHATREV-11; GitHub #246, #430 (from #229 item 5).

## Requests (Xaya, her words)
- CHATREV-10 (2026-11-07, 2 screenshots): "currently creating new whisper tabs by sending a new message don't automatically shift to a new
  whisper window from general tab -- review baseline blizzard behavior". Her New Whispers setting: "Both". Option: "Yes, as an option (Recommended)".
- CHATREV-11: "why is chat functionality still not placed correctly in its appropriate location?"; then "read what I said in the note. for
  the love of everything, ship everything I asked for today and stop asking me questions until everything that is more than 6h old is
  completed and on main". READING (flagged, not asked, per her instruction): "what I said" = her #246 words: "general tab should have font
  options, color + display options, scroll and fade options"; "Chat Tabs should be its own pane"; "Chat history likely belongs in the
  general tab options"; "Timestamp, copying, and links options also likely belong in general options".
- #430 (from #229 item 5): "Clicking the chat box in mover mode should open exact X/Y entry + cardinal arrows".

## Baseline Blizzard behaviour (V2; FloatingChatFrame.lua, wow-ui-source live, FloatingChatFrameManager_OnEvent)
On a whisper with no dedicated window and whisperMode "popout" / "popout_and_inline", the game opens one (FCF_OpenTemporaryWindow). Only
for CHAT_MSG_WHISPER_INFORM / CHAT_MSG_BN_WHISPER_INFORM with whisperMode "popout" ("If you started the whisper, immediately select the
tab") does it call FCF_SelectDockFrame + FCF_FadeInChatFrame. With "popout_and_inline" (her "Both") it stays on the current tab. So her report
is the game's own behaviour for Both, not a XayaUI fault; nothing in XayaUI_Chat selects tabs (git grep: only post-hooks, Skin.lua:219).

## Change
- `XayaUI_Chat/Whispers.lua` (new; part "whisperSelect", default ON: my choice, flagged; she asked for no more questions): with Both, a whisper
  you send that made the game open a whisper window (post-hook on FCF_OpenTemporaryWindow, chat type only, within 0.5 s) selects that
  window one frame later with the game's own two calls. No name / target / text read. V14: events and hook only from the first start.
- `XayaUI_Chat/Options.lua`: parts General, Chat Tabs, Layout, Chat Data Panel, Filters, Sounds, Privacy. General's tabs in her words:
  Font options; Color + display options; Scroll and fade options; Chat history; Timestamp, copying, and links. Controls MOVED (each once;
  settings keys unchanged); Appearance, Fade and hide and History removed (their old part names still open General). Collapse moved to
  Layout ("Hide the chat"). New: Timestamps = the game's own showTimestamps setting (same list as Options > Social > Chat Timestamps,
  Blizzard_SettingsDefinitions_Frame/Social.lua); no message hook.
- `XayaUI_Chat/Frame.lua`: a click on the mover (not a drag's end) opens "Chat position": X, Y (Enter applies), four arrows (1 px, Shift 10),
  kept on screen; built on first use; closes with the mover.
- `XayaUI_Chat/Core.lua`: default whisperSelect = true; the chatDebug service also gives the settings tree (Options) for the walkthrough.
- `XayaUI_DevAssist/QAWalks-chat.lua` (V22): three pre-fill walkthroughs (whisper switch, settings layout incl. timestamps with restore,
  position box). QA D24.
- Versions: Chat 0.6.31 (0.6.29 / 0.6.30 taken on other branches), Dev Assist 0.7.13 (0.7.11 / 0.7.12 taken).

## Scope (V4)
Callers of the moved option keys: tests/chat_run.py (part names; updated to the new structure), tests/reskin_tab_run.py (OpenSettings("look")
now lands on General), Bar.lua / Core.lua OpenSettings("bar") unchanged. tests/chat_world.lua loads Whispers.lua.

## Tests (and fixes from the first full run)
- The hook key "whispers:open" was already Dev Assist's (its /xui chat whispers counter, CoreDebug.lua:738): with the same key, whichever loaded
  first kept the hook and the other was never placed. Whispers.lua now uses "whisperSelect:open" (found by tests/chat_pieces_run.py).
- The position box's arrows get XayaUI's flat button look (tests/flat_buttons_run.py).
- tests/chat_off_costs_nothing_run.py: the new switch is off in its "every switch off" setup; new checks B4c / B4d (on: only the two sent-whisper
  events; off: none).
tests/chat_246_whisper_run.py (new), tests/qa_walks_chat_run.py (extended), tests/chat_run.py, tests/reskin_tab_run.py; full suite: see commit.

## Not verified
Nothing in game. Whether FCF_SelectDockFrame from addon code taints anything in combat is not known (INFERENCE: the game's own chat code
calls it from the same event path; not seen in game).

## CHATREV-12 (added 2026-11-07 ~07:05 UTC): the tab row at two heights
Xaya [screenshot: General and Combat Log lower than Guild, Self and the Talent whisper tab]: "chat is still not displaying tabs correctly --
I thought we said we would fix this".
- Why 0.6.20 did not fix it: it aligned each tab's NAME inside its tab (Skin.lua AlignTabText). The tabs themselves are laid out by the game
  in two groups (FCFDock_UpdateTabs, FloatingChatFrame.lua, wow-ui-source live): static tabs at the dock's BOTTOMLEFT; the others parented
  to the dock's scroll child, LEFT of it (0, -1), i.e. centred on it. In the Chat Panel's tab row the two centres differ. The 0.6.20 test's
  stand-in world gave every tab the same anchor, so it could not see this (V5 gap, now covered).
- Fix: C.AlignTabRow (Skin.lua) moves the first dynamic tab by the difference between its centre and the first static tab's centre
  (her UI-4 answer: "the ones that cannot be changed determine the rest"); the game chains the others to it. Runs after StyleTabs and in a
  post-hook on FCFDock_UpdateTabs (idle while the Chat Panel is off). Measured each time: no drift.
- Test: tests/chat_tab_row_run.py stands in FCFDock_UpdateTabs with the game's anchors (scroll child height 32: a STAND-IN, not read from
  the game); its negative control reproduces the bug with the fix switched off. QA walkthrough "Chat: every tab at one height" (pre-fill).
- Not verified in game.
