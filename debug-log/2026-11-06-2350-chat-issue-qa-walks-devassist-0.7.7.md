# 2026-11-06 23:50 UTC: QA walkthroughs for the old chat issues, with a pre-filled answer (XayaUI_DevAssist 0.7.7)

Session 014bN6tSjceDcH6FdJCeukZG (chat-issue review, sub-session of "Outstanding items 11-06"). REQUEST-LOG A14, CHATREV-1 / CHATREV-6.

## Request (Xaya, 2026-11-06, question box, her words)
- On #210: "2 and ensure qa has a handler that can automatically generate an answer"
- Scope: "For every issue here" (#210, #229 items 1-4, #250, #296)
- On #296: "Have qa handler test behavior and then decide"
- How the answer is recorded: "Pre-fill, I confirm" (offered options: auto-record for chat walks only / for every walk / pre-fill, I confirm)

## Change
- `XayaUI_DevAssist/QAWalks-chat.lua` (new): four walkthroughs, `chat-210-mover-collapse`, `chat-229-pieces`, `chat-250-collapse-size`,
  `chat-296-panel-follows`, registered with `prefill = true`. Each check reads the real frames (GetLeft / GetBottom / GetWidth /
  GetHeight, IsShown, GetAlpha, GetParent, GetEffectiveScale; every read pcall'd, secret values treated as unreadable) and returns a
  verdict with what it read. Step 1 remembers the Chat Panel settings it will change; the last step puts them back.
  What the frames cannot tell (a chevron drawn whole, outlines from anything other than Blizzard's border pieces) is said in the step text.
- `XayaUI_DevAssist/QAWalk.lua`: pre-fill. For a walkthrough with `prefill = true`, the check's verdict is offered on an "Accept: Pass" /
  "Accept: Fail" button; clicking records it with the addon's reading as the note (a typed note is kept). Nothing is recorded without
  the click. No Accept when the check errors or on a step with `noVerdict = true` (#296's last step is her decision). Walkthroughs
  without `prefill` are unchanged ("you still decide").
- `XayaUI_DevAssist.toc`: 0.7.7 (0.7.6 is taken by bundle-2300); QAWalks-chat.lua listed after QAWalks.lua.
- QA-CHECKLIST D21 (D20 is in use on another branch); QAWalks-Checklist.lua regenerated.

## Scope (V4)
`git grep` of the frames and calls the checks read: `XayaUIChatArrow`, `XayaUIChatMover`, `XayaUIChatCollapse` (old ChatDock.lua at
cbd1346, removed in #297), `C.Container / Pane / Bar / Main / Frames / NameOf / ButtonFrameOf / Glued / Clamped / IsCollapsed /
SetCollapsed / ToggleMover / Layout / On` (XayaUI_Chat Core.lua, Frame.lua). Settings changed and restored: x, y, point, width, height,
collapsed, barOn, barSide, stripMode, fadeBar. QA framework callers of RunCheck / ShowStep / Answer: QAWalk.lua only.

## Tests
- `tests/qa_walks_chat_run.py` (new): every step on the real XayaUI_Chat in the stand-in world; negative controls (collapse that does
  nothing, a border piece showing, a strip over the chat, the game's clamp on, a panel left behind, the old floating arrow) each give
  Fail; settings put back; Accept shows the verdict, records only on click, keeps a typed note, absent without pre-fill and on noVerdict.
  On main without this change the test cannot load the walkthroughs (fails).
- `tests/lua_pitfalls_run.py`, `tests/qa_walk_run.py`, full suite: see the commit message.

## Not verified
Nothing here has run in game. The stand-in world's GetEffectiveScale is always 1, so the #250 scale check is only exercised for
equality, not for a UI scale below 1.
