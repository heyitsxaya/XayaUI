# Chat Panel: the history button no longer covers the scroll bar, tabs fit the tab row, a 2 px minimum text gutter (XayaUI_Chat 0.6.8; fork: main)
Logged 2026-11-04 16:30 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Reports (Xaya, 2026-11-04, with screenshots)
1. "chat history icon still clips over sidebar": the history button's three lines sit on top of the scroll bar's up arrow.
2. "user-created chat tabs should not have their boxes overflow": the tabs Log, Trade, Party, Guild and Self. The last box runs to the
   panel's right end, under the button there.
3. "chat align now works, but if possible create a small gutter of 2-3px for easier legibility": the chat text touches the panel's
   left edge.

   Her "chat align now works" is an in-game confirmation of #346 (Chat 0.6.6, the clamp fix).

## Causes (from the code, reproduced in the stand-in world)
1. **History button.** `History.lua` placed it at the tab row's BOTTOMRIGHT, 4 px in and 3 px down: under the tab row, at the panel's
   right edge. With the default settings (tab row on, `scrollOwn` on, `histButton` on), the Chat Panel's scroll bar starts there:
   `Scroll.lua:168`, from the text area's top-right, 10 px wide.
   - In `tests/chat_world.lua` the old placement gives the button x 444-460, y 301-317, and the scroll bar column x 446-456, y 145-318:
     they overlap.
   - The earlier fix ("never outside the block") kept the button inside the pane but put it on the scroll bar.
2. **Tabs.** Blizzard sizes the tabs of user-made windows (dynamic tabs, 60-90 px each) inside `FCFDock_UpdateTabs`, from the dock's
   width at that moment. It shows its overflow arrow only when they do not fit: `FCFDock_CalculateTabSize`, in
   `Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua:2023-2135`, wow-ui-source live (12.1.5.70783), read this session.
   - The Chat Panel re-anchors the dock into its tab row (`Frame.lua`, C.Anchor) but never asked Blizzard to lay the tabs out again.
     Nothing in XayaUI_Chat called `FCFDock_UpdateTabs`.
   - INFERENCE (not reproduced in game): the tabs kept sizes worked out for the old, wider dock, so no overflow arrow appeared and the
     last tab ran to the row's end.
3. **Gutter.** The text area starts `textInset` px in from the pane (default 6, setting range 0-30). Text touching the edge fits a
   saved inset of 0 (INFERENCE: her saved settings were not seen). `/xui chat indent` prints the setting and the real positions.

## What changed
- `XayaUI_Chat/History.lua`: the button sits at the right end of the tab row (RIGHT, 3 px in), vertically centred. With the tab row
  hidden, it sits in the text area's top-right corner, which is left of the scroll bar.
- `XayaUI_Chat/Frame.lua`:
  - the dock stops `C.HIST_RESERVE` (22 px: the button and its margins) short of the tab row's right end while the history button is
    on, so the tabs never run under it;
  - after anchoring, when the dock's width differs from the width Blizzard last laid the tabs out for (`C.dockLaidOutW`),
    `FCFDock_UpdateTabs(dock, true)` runs: error-protected, out of combat only (in combat the next layout does it), and only while
    the tab row is shown;
  - the text inset is never under 2 px.
- `XayaUI_Chat/Options.lua`: the "Text inset" slider's minimum is 2. The history-button switch reads "at the end of the tab row".
- `USER-GUIDE.md`: the history button's place; tabs fit the row and the game's overflow arrow lists the rest.

## Scope (V4)
- The history button is created and placed only in `History.lua`. `Locate.lua:22` finds it by its global name (unchanged).
- The dock is anchored only in `Frame.lua` C.Anchor. `C.Glued` checks that it has 2 points on the tab row (still true).
- `textInset` is read in `Frame.lua` (layout), `Options.lua` (slider) and `Core.lua:338` (the indent report).
- `FCFDock_UpdateTabs` is Blizzard's function. Calling it from addon code: the chat dock and its tabs are not protected frames.
  INFERENCE: no taint consequence; it is error-protected and skipped in combat.

## Tests (`tests/chat_run.py`, new checks)
- The dock stops 22 px short of the tab row's end.
- The history button is inside the pane and the tab row, not on the scroll bar, and not on the tabs.
- History button off: the tabs get the whole row.
- Tab row hidden: the button is in the text area's corner, off the scroll bar; back at the row's end when the row returns.
- The tabs are laid out again (forced) once the dock sits in the row, at its new width; not again at the same width; again after the
  panel narrows; not in combat; after combat yes.
- Text inset 0 saved: the text starts 2 px in, and the chat window follows; inset 6 gives 6 px.
- **Negative control:** with the previous `Frame.lua` and `History.lua`, 6 checks fail (dock width, button inside the tab row, button
  on the scroll bar with the overlap geometry above, tab row hidden, tab row back, no tab layout), then the run stops at the missing
  layout call. The gutter checks were not reached on the old code. From its line `Clamp(s.textInset, 0, 30, 6)`, inset 0 would put
  the text at 0 px (INFERENCE, not run).
- QA: D4f, D4g, D4h.
