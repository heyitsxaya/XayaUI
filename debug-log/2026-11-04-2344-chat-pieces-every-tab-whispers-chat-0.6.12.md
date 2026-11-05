# Chat Panel: pieces of every tab, the window list's layer, a whisper-tab report (Chat 0.6.12)
Logged 2026-11-04 23:44 UTC. Session branch `claude/clever-noether-0o0uuj`, on top of `main` fb23e4b (Chat 0.6.11). Nothing here has
run in the game.

## Report (Xaya, 2026-11-04, two screenshots, Party tab selected)
1. "whispers are not shown as their own tabs even though the option is enabled."
2. "the selector gets hidden by the privacy icon": the game's list of chat windows ("7 Chat Windows": General, Combat Log, Trade, Party,
   Guild, Self, debugging) opened from the arrow at the tab row's end, with the eye button drawn over the Trade and Party rows.
3. "scroll to the bottom button is hidden by scroll bar": the second screenshot shows the double-chevron arrow under a grey bar in the
   column right of the text.
INFERENCE: the purple ring in the first screenshot is Xaya's Cursor Highlight, not a mark on the picture.

## 2. The window list under the privacy button
- The list has no layer of its own. `FloatingChatFrame.xml` (wow-ui-source live 12.1.5.70783): `<Frame name="DockManagerTemplate"
  frameStrata="LOW" ...>`; the list is `<Frame name="$parentList" inherits="DockManagerOverflowListTemplate" parentKey="list">` inside
  the overflow button, and `DockManagerOverflowListTemplate` sets no `frameStrata`. So it is drawn in LOW.
- XayaUI's pieces it hangs over: privacy button `SetFrameStrata("MEDIUM"); SetFrameLevel(60)` (Privacy.lua), Chat Panel scroll bar
  MEDIUM (Scroll.lua), history button MEDIUM (History.lua), privacy cover DIALOG level 100 (Privacy.lua). All are above LOW.
- Fix: `C.RaiseTabList` (Frame.lua, called from `C.Parts`, so the 3-second upkeep repeats it) sets the list to `FULLSCREEN_DIALOG`, the
  layer the game's own drop-down menus use (`Blizzard_Menu/Menu.lua:2142`: `local strata = "FULLSCREEN_DIALOG";`). Out of combat only.
  The old layer is kept and given back by `C.Teardown` (Chat Panel off).

## 3. The back-to-newest arrow under the scroll bar
- Cause: `C.Parts` (Frame.lua) handled the scroll bar, the back-to-newest arrow and the resize grip of `ChatFrame1` only. Every docked
  window has its own (FloatingChatFrame.xml: `ScrollToBottomButton`, `ResizeButton`; `FloatingChatFrame_OnLoad`:
  `self.ScrollBar:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, 0)`; `self.ScrollBar:SetPoint("BOTTOMLEFT", self.ScrollToBottomButton,
  "TOPLEFT", 0, 2)`), and the arrow's own anchor is `BOTTOMRIGHT` of the resize grip, which sits at the background's bottom-right,
  `7 + scrollbarWidth` (8) px right of the window (`FloatingChatFrame_UpdateBackgroundAnchors`). A docked window fills the primary one
  (`FCFDock_AddChatFrame`: `chatFrame:SetAllPoints(dock.primary)`), which the Chat Panel puts on the text area. So with Party selected,
  the game's scroll bar and arrow were right of the text, in the column of the Chat Panel's scroll bar (MEDIUM, drawn over the arrow,
  LOW). INFERENCE: the grey bar in the second screenshot is the game's own scroll bar thumb (not suppressed on that window).
- Second finding (INFERENCE from the code, not seen in game): the arrow could never be seen on any window while the game's scroll bar
  is hidden. Its art starts at alpha 0 (`<Button parentKey="ScrollToBottomButton" alpha="0">`), and the only code that raises it is
  `FCF_FadeInScrollbar`: `if chatFrame.ScrollBar and chatFrame.ScrollBar:IsShown() then ... UIFrameFadeIn(chatFrame.ScrollToBottomButton,
  .1, chatFrame.ScrollToBottomButton:GetAlpha(), .65)`. The Chat Panel hides that scroll bar by default.
- Fix (Frame.lua):
  - `C.Parts` handles every window in `CHAT_FRAMES`: docked ones get the scroll bar hidden (unless Blizzard's scroll bar is chosen), the
    arrow placed in the text area's bottom-right (`BOTTOMRIGHT` of the text area, 0, 2: as ChatFrame1 had since 0.6.x), the resize grip,
    background and border hidden. A window that is not docked (the player dragged its tab out) gets all of them back, and its arrow its
    own anchor (`C.Forget`, Core.lua).
  - `C.ToBottomUpdate` (upkeep, every 0.3 s): while the game's scroll bar is hidden and the setting is Shown, each docked window's arrow
    is shown at alpha 1 while that window is scrolled up (`GetScrollOffset() > 0`) and hidden at the newest line. A position that cannot
    be read keeps it shown. With Blizzard's scroll bar chosen, or the Chat Panel off, the arrow gets its own alpha and shown state back,
    so the game's fade works as before.
  - Locate ("Show me where each piece is") outlines the scroll bar and arrow of the tab you are looking at, not ChatFrame1's.

## 1. Whisper tabs: no cause found in the code
What was checked (wow-ui-source live 12.1.5.70783, `FloatingChatFrame.lua`):
- The tab is the game's: `FloatingChatFrameManager_OnEvent` opens one with `FCF_OpenTemporaryWindow(chatGroup, chatTarget)` when
  `GetCVar("whisperMode")` is `"popout"` or `"popout_and_inline"` and `FCFManager_GetNumDedicatedFrames(chatGroup, chatTarget) == 0`;
  `FCF_OpenTemporaryWindow` ends with `FCF_DockFrame(chatFrame, (#FCFDock_GetChatFrames(GENERAL_CHAT_DOCK)+1), selectWindow)`.
- The window list counts docked windows: `FCFDockOverflowList_Update`: `list.numTabs:SetFormattedText(CHAT_WINDOWS_COUNT,
  #dockedFrames)`. Xaya's list says 7 and names 7 windows, so no whisper window was docked when the picture was taken.
- XayaUI never opens, closes, hides, undocks or unregisters chat windows or events: `git grep` over every `XayaUI*` addon for `FCF_`,
  `FloatingChat`, `whisperMode`, `CHAT_MSG_WHISPER`, `ChatTypeGroup`, `RemoveMessageGroup`, `ExcludePrivate`, `UnregisterEvent`: only
  XayaUI_Chat's post-hooks (`hooksecurefunc`, they only schedule a refresh), its message filters (they decide what a window prints, not
  whether the manager opens a window) and its own event frames. `UnregisterEvent` appears nowhere in XayaUI_Chat.
- So the code gives no reason. Not guessed into a fix (V12). Built instead: `/xui chat whispers` (Core.lua, READ ONLY): the game's
  setting (`C_CVar.GetCVar("whisperMode")`), whether `FloatingChatFrameManager` is registered for `CHAT_MSG_WHISPER` /
  `CHAT_MSG_BN_WHISPER`, whispers received / sent and whisper tabs the game opened since the last /reload (a post-hook on
  `FCF_OpenTemporaryWindow` that reads only its first argument, the chat type), and the whisper windows there are now (docked /
  floating). No name is read or printed. One line says what the numbers mean (setting In-line; no whisper yet; whispers but no tab).
- Questions for Xaya (QA D4l): the output of `/xui chat whispers` after a whisper; any Lua error with `/console scriptErrors 1`.

## API entries (V2; `docs/reference/api/widgets.md`, `namespaces.md`, build 12.1.5.70783 / docs 70688)
- `SetFrameStrata(strata: FrameStrata)` · IsProtectedFunction, SecretArguments=NotAllowed · SimpleFrameAPI
- `GetFrameStrata()` → `strata: FrameStrata` · SimpleFrameAPI
- `IsEventRegistered(eventName: cstring)` → `isRegistered: bool, units: UnitTokenType?` · ChecksForbiddenAspects=[{'Argument': 'self',
  'Aspect': 'ForbiddenAspect.EventRegistrations'}], ConstSecretAccessor, SecretArguments=AllowedWhenUntainted · SimpleFrameAPI
- `C_CVar.GetCVar(name: cstring)` → `value: string?` · SecretArguments=NotAllowed
- `Show()` · FrameAPIModelSceneFrameActorBase; `Hide()` · FrameAPIModelSceneFrameActorBase
- `SetAlpha(alpha: number)` · SecretArguments=AllowedWhenUntainted, SecretArgumentsAddAspect=[SecretAspect.Alpha] · FrameAPIModelSceneFrameActorBase
- `GetScrollOffset` is not a widget method: it is Lua (`ScrollingMessageFrameMixin:GetScrollOffset() return self.scrollOffset`,
  `Blizzard_SharedXML/ScrollingMessageFrame.lua:213`), read through the existing `C.ScrollPos` (numbers checked for secret).
- INFERENCE: "IsProtectedFunction" blocks the call on protected frames only (SetPoint carries the same flag and XayaUI_Chat has always
  called it on these windows). The window list is not a protected frame; the strata change is still skipped in combat, and every read
  that could be secret is checked with `issecretvalue`.

## Scope (V4)
- Functions changed: `C.Parts`, new `C.RaiseTabList`, `C.ToBottomUpdate`, `C.ToBottomRelease` (Frame.lua); `C.Teardown`, new
  `C.Forget`, `C.WhisperFacts`, `C.WhisperReport`, `C.Command` (Core.lua); Locate.lua's `scroll` and `tobottom` pieces.
- Callers: `C.Parts` from `C.Anchor` and the upkeep (every 3 s); `C.ToBottomUpdate` from `C.Parts` and the upkeep (every 0.3 s);
  `C.Teardown` from `C.Refresh` when the Chat Panel is off or blocked.
- Settings read: `scrollOwn`, `scrollBar`, `toBottom` (Chat > Chat Panel > Layout). Unchanged: the privacy button and cover
  (Privacy.lua), the history button (History.lua), the Chat Panel scroll bar (Scroll.lua; `C.ScrollTarget`, `C.ScrollPos` read only).
- Windows: every name in `CHAT_FRAMES`: ChatFrame1, the Combat Log, user windows, the game's temporary whisper windows; docked and not
  docked.

## Tests
- New `tests/chat_pieces_run.py` (49 checks, `FAILS: 0`). The stand-in world gains the dock's overflow arrow and list (LOW), the arrow at
  alpha 0, ChatFrame2 on ChatFrame1's rectangle, the whisper manager and the whisper CVar, as in the game files quoted above.
  - Negative control: the same file against `main` fb23e4b's Chat code: 29 FAIL, among them the screenshot's overlap (ChatFrame2's arrow
    at x 441-458, the Chat Panel's scroll bar at x 446-456), the list in LOW under MEDIUM / DIALOG, the arrow at alpha 0 while scrolled up,
    Locate on ChatFrame1's arrow, and every whisper-report check but one.
  - The 20 checks that pass on the old code: no module errors (start and end, 2); the world's setup (the list overlaps the eye, the scroll
    bar and the history button, 2; the selected tab is ChatFrame2, 1); what must stay the game's (the list's layer with the Chat Panel off
    and in combat, 2; Blizzard's scroll bar mode, 2; undocked ChatFrame2, 3; Chat Panel off, 2); placements the old code already had
    (ChatFrame1's arrow, ChatFrame2's arrow inside the pane, 2); the arrow not seen at the newest line (2: at alpha 0 the old arrow was never
    seen at all); whisper report lines that must be absent (no name, no "opened no tab" line, 2). They guard the new per-window code; the
    old code passed them by never touching those windows or by printing nothing.
- `tests/chat_run.py` (all passed), `tests/chatprobe_run.py` (20, 0 failed), `tests/window_margins_run.py` (44, 0 failed),
  `tests/modules_run.py` (32, 0 failed), `tests/lua_pitfalls_run.py` (77 files, FAILS: 0).
- QA D4k (the arrow and the window list), D4l (whisper tabs).
