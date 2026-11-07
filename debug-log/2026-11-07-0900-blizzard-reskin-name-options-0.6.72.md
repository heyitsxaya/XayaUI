# "Blizzard Reskin" in every user-facing string (Options 0.6.72, Chat 0.6.37, QoL 0.7.45, Bonus 0.6.27, Reskin, Dev Assist 0.7.33)

Session 014bN6tWsQ4qcob9VPKD7PV5, branch `claude/settings-restructure`, on top of 1906ad6 (UI-23 to UI-27). Her words (A8 UI-24): tab
label "Blizzard Reskin". The hub (session_014bN6tWMaSvKkwjeonHvvch) gave this follow-up to this session; scope approved: user-facing
strings only, patch-note history (InfoPaneData) and quotes of her words stay as written.

## What changed (string literals only; no logic)
- Options: the Overview switch `ns.OptionsApi.RESKIN_SWITCH` "Enable Blizzard Reskin"; the reload prompt's text.
- Chat: `/xui chat on` and status lines; the Chat Panel switch's tooltip.
- QoL: Shopping List and Character Reskin messages and switch tooltips.
- Bonus: the Data Panels page description.
- Reskin: the Game Menu skin's "could not find the real button" message and the Esc Menu switch's tooltip.
- Dev Assist: walkthrough texts (QAWalks.lua, QAWalks-chat.lua), CharacterWidthProbe's message; new walkthrough "reskin-rename" (H10).
- Docs: open QA-CHECKLIST paths, USER-GUIDE (also the Profiles tab: Import / Export with components, Recycle Bin, no toolbar).

## Scope (V4)
`git grep "Blizzard UI Reskin"` over every XayaUI* folder: every string literal outside InfoPaneData's history renamed; comments left.
Tests reading the strings: reskin_tab_switch_run (switch name, the "> Overview" lines) updated. Still to sweep after they land:
the chat round's #443 (Chat Sidebar.lua, QAWalks-chat.lua, QA D25-D28) and #449 (Reskin FriendColors.lua, QAWalks-friends.lua).

## Runtime (CLEAN-8)
Text only: no events, frames, timers, hooks or saved data changed.

## Tests
reskin_tab_switch_run, reskin_tab_run, char_reskin_run, shopping_list_run, chat_run, qa_walks_profiles_run (H10 step), full suite. Not run in game.
