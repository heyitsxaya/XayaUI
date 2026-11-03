# Xaya: Chat Panel feedback round after in-game test of 0.5.90 (XayaUI 0.5.94, fork: main)
Logged 2026-11-03 ~03:00 UTC. GitHub issue: #297 (comment). Reported against build 0.5.90 (kept as 0.5.90 through 0.5.93; chat code unchanged by the engine work).

## Reports and causes (from Blizzard source, Gethe/wow-ui-source, dated 2026-10-31)
1. Sidebar bugged: scroll bar, back-to-newest button, and History button floated at the right edge. Cause: the scroll bar is shown by `SetShown` (a Show-only hook missed it); `ScrollToBottomButton` is anchored to the hidden `ResizeButton`. Fix: suppress registry hooks Show and SetShown; back-to-newest gets its own anchor and an option.
2. History: could not filter to General or Combat; selection impossible while Trade spam rewrote the text; window not resizable. Fix: one button per chat tab (uses each frame's own message groups and channels), snapshot with Refresh and Live, resizable with saved size. Combat Log lines are not chat messages and cannot be recorded (limit, documented).
3. Block align for blocks 2 and 3 did not move text. Cause: GetWidth is unreliable right after anchoring. Fix: relayout on OnSizeChanged and next frame.
4. Mover shows the original Blizzard chat underneath. Cause: FloatingBorderedFrame Background and 8 border textures still drawn at the old offset. Fix: those pieces suppressed per docked frame; mover opaque.
5. Chat content desyncs from the container after some moves. Cause: the game re-anchors ChatFrame1 with single-anchor changes that the old check missed. Fix: Glued() compares every anchor; hooks on SetPoint, ClearAllPoints, StopMovingOrSizing, SetUserPlaced re-anchor.
6. Disabling the Chat Panel broke the chat window. Cause: no teardown. Fix: positions, sizes, fonts, alpha, and tab height are remembered and restored when off.
7. Dropdown took a whole row (style-guide breach). Fix: dropdowns share rows; rule saved to project memory.
8. Menu structure unclear. Fix: tabs now Layout, Appearance, Chat Bar, Fade and hide, Filters, History, Sounds, Privacy.
9. "I have no idea what these settings do because nothing is visible." Fix: new Chat/Locate.lua; Layout tab button "Show me where each piece is", plus per-slider flashes.
10. `/xui chat` and `/xui` help text lost text after a pipe character. Fix: pipes escaped as `||`.
11. Privacy cover showed Blizzard border at the right edge: same cause as 4; privacy button offset +34 when the strip is on the right.

## Verification
Offline stand-in world (tests/chat_world.lua, tests/chat_run.py): 155 checks pass; all other suites pass. NOT verified in game: everything above. Blizzard internals are taken from source, not observed.
Known leftovers: Xaya's stored strip/social offsets (181/207) remain; old tab names changed, so a saved "open on tab" is not stored anywhere. Chat/Core.lua still names EllesmereUIChat in its conflict message (functional detection; flag for Xaya).

Files: Chat/Bar.lua, Core.lua, Frame.lua, History.lua, Locate.lua (new), Options.lua, Skin.lua, Sounds.lua; ChatPrivacy.lua; Core.lua; Options.lua; USER-GUIDE.md (12.10); XayaUI.toc; MANIFEST.md5; tests/chat_world.lua, tests/chat_run.py.
