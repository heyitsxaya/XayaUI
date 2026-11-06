# Collapse with the bar above the chat: the bar drops to the bottom (XayaUI_Chat 0.6.22; fork: main)
Logged by session 014bN6tV7oStjTuVPEJbytBJ, branch `claude/ui-bugs-focused`. Nothing here has run in the game.

## Request
REQUEST-LOG UI-20 (Xaya, 2026-11-06, sent twice): "pressing the collapse button should collapse the chat data bar down, not pull the
chat up to it" [screenshot: the Chat Bar above the chat, its arrow circled, tooltip "Hide the chat"].

## Cause (read in the code)
`XayaUI_Chat/Frame.lua` C.Layout: the bar was anchored at the block's top whenever "Place the bar" is Above the chat, collapsed or not;
collapsing only hid the pane, so the bar stayed up top with an empty space under it.

## Change
- Collapsed, the bar is anchored at the block's bottom edge whatever its side; shown, as before (top or bottom). The block's place and
  size do not change (it is anchored by its bottom-left corner by default).
- The arrow: down while the chat shows, up while it is hidden (before: it pointed toward a bar above the chat).
- Scope (V4): C.Layout is the only place the bar is anchored; C.SetCollapsed calls it; the mover's resize reads barH / barGap only.

## Test
`tests/chat_collapse_bar_run.py` (new): on Chat 0.6.21 the "collapsed: the bar at the bottom" check fails (bar bottom 322 vs block
bottom 90 in the stand-in); passes now with 5 guards. `tests/chat_run.py` all passed.

## QA
D15.
