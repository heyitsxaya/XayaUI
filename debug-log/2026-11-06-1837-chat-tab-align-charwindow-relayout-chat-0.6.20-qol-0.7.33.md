# Chat tab names at one height; character window laid out again after a size change (XayaUI_Chat 0.6.20, XayaUI_QoL 0.7.33; fork: main)
Logged 2026-11-06 18:37 UTC. Session 014bN6tV7oStjTuVPEJbytBJ ("XayaUI: UI bugs (focused)"), branch `claude/ui-bugs-focused`.
Nothing here has run in the game.

## Requests (REQUEST-LOG section A8)
- UI-2 (Xaya, verbatim): "text differences between general / combat log / user created panes should not exist. make sure all align
  properly" [screenshot: "General" lower than the other tab names, white; the others teal].
- UI-4, her answers: "set all v-aligns to the same -- the ones that cannot be changed determine the rest; colors inherit either addon
  override or inherit blizzard-assigned options"; Insivius's character window report: "Fix + diagnostic".
- Insivius (relayed, "New bugs review" row 3): "Text breaks if you make the window wider and then bring it back down".

## Chat tabs (Chat 0.6.20, `XayaUI_Chat/Skin.lua`, `Core.lua`)
- Blizzard's source (Gethe/wow-ui-source 297d7aa = 12.1.5.70783, read in this session): ChatTabArtTemplate's ButtonText is
  CENTER 0, -5, 50 x 8 (FloatingChatFrame.xml:414-418); General (ChatFrame1Tab, xml:697), Combat Log (ChatFrame2Tab, xml:728) and every
  "Create New Window" tab use it. FCF_OpenTemporaryWindow (FloatingChatFrame.lua:711-720) re-anchors a whisper tab's name LEFT of
  chatTab.Left's right edge + 10, -6. With the Chat Panel's tab height (24, not the art's 32) that put whisper names 3 px off the others
  (stand-in: -2 vs -5 from the tab's centre). Confirmed difference.
- General's lower name in her screenshot: no cause found. No XayaUI code moves a tab's name; Blizzard's chat code does not call
  PanelTemplates_SelectTab (which lowers a selected tab's text elsewhere); FCFTab_UpdateColors only colours. INFERENCE: an anchor set by
  something not read here. The fix re-anchors every docked tab's name, so an anchor cause is covered; another cause is not. QA D19 asks
  for `/xui debug chatprobe` if it persists (the probe lists ChatFrame1Tab's anchors).
- Change: StyleTabs anchors every docked tab's name at the template's place (CENTER 0, -5); a whisper tab (it has `conversationIcon`)
  keeps its left alignment at the same x (24 = Left's right edge + 10) and gets the same height. The game's anchors are saved on the
  first styling and given back by C.Teardown. Colours unchanged (her "colors inherit either addon override or blizzard-assigned"): the
  same rule already applies to every tab (theme colour, else the Chat Panel's tab / selected-tab colours).
- Scope (V4): `git grep` TabText / StyleTabs / tab.Text: Skin.lua (StyleTabs, the only writer), History.lua:67 (reads the name only),
  Core.lua C.Teardown (restore). Undocked windows' tabs are not styled by the Chat Panel (unchanged).
- Test: `tests/chat_tab_align_run.py` (new). On Chat 0.6.18 the height check fails (General -9 stand-in, Combat Log -5, whisper -2);
  passes now. `tests/chat_run.py` all passed.

## Character window (QoL 0.7.33, `XayaUI_QoL/CharacterReskin.lua`)
- Reproduction attempt: in the stand-in (tests/char_pane_geometry.lua) widening to 120 and 300 px and back to 42, and closing / opening
  the stats pane, gives exactly the same 22 rows (place, width, font size, text) as before. The layout keeps no state between widths.
- INFERENCE (not seen in the game, her choice "Fix + diagnostic"): right after SetWidth / SetHeight / SetPoint the live client may give
  the old positions to GetLeft / GetRight in that same moment, so the blocks are laid out for the wider window.
- Change: every size change (ApplyWide width change, ApplyTall height change, RestoreTall, RestoreWide, the hook after Blizzard's
  UpdateSize) sets a flag; the next slot layout then queues one more layout on the next frame (C_Timer.After(0)), only while the reskin
  and Enchants or Gems are on. `/xui reskin status` gains a "Size change" line: whether the positions read in the two passes differed
  and by how much. V14: nothing new runs while the reskin is off (the flag is set only by code that runs while it is on).
- Test: `tests/char_pane_overlays_run.py` section G: a widen / narrow guard (same rows); a STAND-IN of the inferred behaviour (the
  slots', model's and Inset's positions read as the 300 px window's until the next frame). On QoL 0.7.32 the next-frame check and the
  status check fail; pass now. char_reskin 51, char_pane_round 27, char_width_probe 20, reskin_tab 22, reskin_tab_switch 24: all pass.

## QA
D19 (chat tabs), E1z83 (character window, and the Size change line that settles the inference).
