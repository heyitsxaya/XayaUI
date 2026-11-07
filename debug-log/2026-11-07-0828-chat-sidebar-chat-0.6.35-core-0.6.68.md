# Chat sidebar (Improved Chat > Sidebar) and "Show it in" for XayaUI's button (Chat 0.6.35, core 0.6.68, Dev Assist 0.7.27)

Session 014bN6tUJW6J1rnMZ6Z7t7c1 (chat-round session), branch `claude/chat-round-1106`.

## Her words (REQUEST-LOG A8 UI-3, UI-17; A16 CR-4, CR-6, CR-7)
- UI-3: "privacy bar should exist in a chat sidebar option that can be set to have a background or none at all. this bar should be configurable to be show on mouseover, auto-hide, etc and the buttons nested within should inherit that behavior. the sidebar should also be moveable to top, bottom, left or right sides and influence chat placement appropriately if it clips into the chat data panel or the end of the screen"
- UI-17: "left, but default chat size should be untouched -- only modify if the user sets a specified width for the whole chat container (including sidebar)"
- CR-6 (question box): auto-hide "Fade and auto hide in combat both tick boxes"; buttons "Privacy cover, Blizzard chat buttons, History + window list, Scroll to bottom, Any other chat-based icon (can be minimap icons the user allows, too — create the option in each feature to choose whether it's a sidebar or minimap icon display; default to having sidebar on if minimap is turned off)"; eye "Moves into sidebar (Recommended)"; fresh install "On with same opacity as chat pane with an additional layer underneath the black using the primary class color for tinting"
- CR-7: minimap icons "XayaUI's own first (Recommended)"

## What changed
- New `XayaUI_Chat/Sidebar.lua`, an Improved Chat part ("sidebar"; `C.PART_GROUP`). A strip outside the chat block (never over the Chat Data Panel, which is part of the block), on Left (default) / Right / Top / Bottom, as long as the block's side, 2 px away, buttons 22 px (14-40). The chat's size is untouched; "Width of the whole chat" (0 = not set) makes pane + sidebar that wide. When the strip would run off the screen, the Chat Panel's block is placed in by that much (its saved place is kept); with the Chat Panel off it stays on screen over the chat's edge (Blizzard's chat is not moved).
- Background (tick box, on): a layer tinted with the player's class colour (RAID_CLASS_COLORS) under the chat pane's background colour, both at the chat pane's background opacity.
- Show: Always / On mouseover (mouse over the strip or the chat; a 0.1 s OnUpdate only in this mode); tick boxes "Fade with the chat" (follows the Improved Chat fade) and "Hide in combat" (PLAYER_REGEN_DISABLED / ENABLED, registered only while the sidebar is on). Hidden while the chat is collapsed. Every button is a child of the strip, so it follows all of this.
- Buttons (each with a tick box): the privacy eye (moved in; back beside the chat with the sidebar off), Blizzard's chat buttons (ChatFrameMenuButton, ChatFrameChannelButton, ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton: re-parented into the strip out of combat only, parent and anchors remembered and given back; only shown ones take a slot), the history button (the tab row no longer keeps room for it), Chat windows (runs the dock's overflow button's click), Newest message (ScrollToBottom on the selected window), and XayaUI's button.
- Core 0.6.62 MinimapButton.lua: Settings > Minimap Button > **Show it in** (Minimap / Chat sidebar / Both; saved `minimap.where`, nothing saved until chosen). Nothing chosen: the sidebar holds XayaUI's button while the minimap button is turned off (her default). `ns.Minimap_TogglePopupAt(anchor)` opens the same quick-access list from the sidebar button.

## Choices made by this session (flagged; not her words)
Button size 22 px; gap 2 px; Show defaults to Always, both tick boxes default off; the order of the buttons; the Chat windows and Newest message glyphs. Other addons' minimap icons in the sidebar: later (her answer "XayaUI's own first").

## Scope (V4)
Frame.lua (Layout: whole-width, clip shift, sidebar refresh; Anchor: tab-row reserve; ApplyAlpha), History.lua (button parent / place), Privacy.lua (button parent / place / size), XayaUI_Chat.toc, core MinimapButton.lua (Refresh, popup anchor, option). No XayaUI_Options file changed.

## Tests
New `tests/chat_sidebar_run.py` (33 checks; on 39cc9b8 only the guard passes before the run stops at the first missing sidebar). Updated: chat_run.py and chat_off_costs_nothing_run.py (sidebar off where they test the old eye / history places), chat_246_whisper_run.py, qa_walks_chat_run.py (walkthrough "chat-sidebar" with two negatives); chat_world.lua exposes `W.proto` and texture draw layers.

## Not verified in game
All of it. Re-parenting Blizzard's chat buttons is done out of combat only (INFERENCE: they are not protected frames; not checked against taint in game). The voice buttons' own show / hide is hooked to lay the strip out again.
