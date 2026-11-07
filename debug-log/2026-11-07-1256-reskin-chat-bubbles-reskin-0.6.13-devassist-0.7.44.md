# Chat bubbles in the XayaUI look (Reskin 0.6.13, Dev Assist 0.7.44)

Logged 2026-11-07 12:56 UTC. Session 014bN6tSvVzc2HRgXhwF3J2L (reskin successor), branch `claude/determined-cerf-981pn8`. Request row
RESKIN-3, her words: "chat bubbles". Item 4 of the unbuilt list in `docs/process/handoffs/reskin-elements.md`.

## What changed
- `XayaUI_Reskin/BlizzardSkins.lua`: new page **Chat Bubbles** (key `rskbubbles`, saved `CueRulesDB.ui.rsk.bubbles`), off until ticked.
  - Bubbles are read with `C_ChatBubbles.GetAllChatBubbles(false)` (never the forbidden ones). Each bubble's ChatBubbleTemplate child
    (found among its children as the one with `SetCenterColor` and a `String`) takes the theme's window colour on its centre and tail
    (at Background opacity) and the border colour on its border. The colours it had are read first and given back on untick.
  - The game makes no event when a bubble appears. While the page is on, one event frame listens to the chat messages that can show a
    bubble (CHAT_MSG_SAY, _YELL, _MONSTER_SAY, _MONSTER_YELL, _MONSTER_PARTY, _PARTY, _PARTY_LEADER; payloads are not read) and scans the
    bubbles once on the next frame (at most one scan queued at a time). Also one scan when ticked.
  - In instances the game makes bubbles forbidden to addons: they stay Blizzard's (the page and walkthrough say so).
- Choice made without her (to the QA flow): the tail takes the window colour (so it matches the body); text colour left to Blizzard.
- `XayaUI_DevAssist/QAWalks-reskin.lua`: walkthrough "Reskin: chat bubbles" (prefill). She types `/s hello` herself (an addon may not send
  /say outside instances without a key press); the check counts bubbles painted since the walkthrough began (`diag.bubbles`).
- QA-CHECKLIST G12, G8 lists `bubbles` / `bubbleEvents`.

## Scope (V4)
- `git grep -i chatbubble`: no other XayaUI file touches chat bubbles (Chat addon styles the chat frames only).

## V2 (API / source)
- `docs/reference/api/namespaces.md:801`: `C_ChatBubbles.GetAllChatBubbles(includeForbidden: bool = false)` -> `chatBubbles:
  table<ChatBubbleFrame>`, SecretArguments=AllowedWhenUntainted (our argument is a plain false).
- 12.1.5 (Gethe/wow-ui-source 297d7aa, read as data): `Blizzard_ChatBubble/ChatBubbleTemplates.xml:3-13` (NineSlicePanelTemplate,
  String, Tail), `Blizzard_SharedXML/NineSlice.lua:258-283` (Set/GetCenterColor, Set/GetBorderColor).
- INFERENCE: that the template frame is a child of the bubble returned (the usual layout; the code finds it by its methods and does nothing
  if none matches).

## V14
Off: no event frame, no scan. Unticked: events unregistered, painted bubbles get their colours back.

## Tests
- `tests/reskin_blizzard_skins_run.py`: 84 checks (11 new). On the old code `BS.BubblesPage` is nil.
- `tests/qa_walks_reskin_run.py`: 41 checks (5 new).

## Not verified in game
All of it.
