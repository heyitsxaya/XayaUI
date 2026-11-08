# Debug chat defaults: the Sidebar's and the privacy cover's defaults reach the saved settings at login (Chat 0.6.46, Dev Assist 0.7.69)

Logged 2026-11-08 08:48 UTC. Branch `claude/lucid-mayer-pv4ytn`, base 1b974fe (main d200fd0 + W9b 6edd94d + a docs commit). Not on main.
QA step D29; walkthroughs "debug-chatdefaults" and "debug-chatdefaults-reload", `XayaUI_DevAssist/QAWalks-debug-chatdefaults.lua`.
No issue closed or commented. UNTESTED IN GAME.

## The report
- P5 worker (debug-log 2026-11-08-0233 settings-migration-p5, "Found while building"): "in the game, the Sidebar's and privacy cover's
  defaults never reach the saved settings at login. This includes sidebar fade by default (O-143). P5 keeps that behaviour exactly; the
  test stand-in always applied them."
- O-143 / CR-8 (Xaya 2026-11-07, her words): "weird chat appearance when chat fades -- the sidebar icons should also be fading". On main at
  72a7512 with "the sidebar fades with it by default"; that default never reached the game.
- #494 (tester Insivius: "XUI chat bar is sitting on top of my current panel and there's no option to disable it") was named as possibly
  related. Finding: not caused by this. `sbOn` missing reads as on (`s.sbOn ~= false`, Sidebar.lua:311), the same as its default `true`,
  so the sidebar showed exactly as it would with the default saved; this fix changes nothing there. Whether the sidebar should default off
  when another chat addon is loaded is her open decision (C6 / #469): not built.

## Reproduced first (V3)
Whole-addon harness (`tests/harness/loader.lua`: every addon folder loaded from its .toc, files first, then the saved variables, then
ADDON_LOADED), fresh install, on 1b974fe: `XayaUIChatDB.chat2.sbOn / sbFade / sbSide / sbBg / sbGap / sbShow` = nil, `XayaUIChatDB.chat.privR
/ privTexture / privBtnAlpha / privMode / privOn` = nil; with the chat fade on and the chat faded to 0, the sidebar stayed at opacity 1
while its settings page showed "Fade with the chat" ticked (the page's get falls back to the default; the runtime reads `if s.sbFade`).
The chat stand-in (`tests/chat_world.lua`) gave `sbFade = true`.

## Cause (game vs stand-in)
- `XayaUI_Chat/Core.lua` (P5): `ns.WhenSettingsReady("chat", ns.Chat_OnDBReady)` at the end of Core.lua; the store opens at XayaUI Chat's
  ADDON_LOADED (`XayaUI/Core.lua` start-up frame -> `ns.SettingsAddonLoaded` -> `ns.SettingsOpen("chat")` -> the queued Chat_OnDBReady).
- The .toc loads Core.lua first and Privacy.lua, Sidebar.lua last. Privacy.lua fills `ns.CHAT_DEFAULTS`; Sidebar.lua adds
  `C.SIDEBAR_DEFAULTS` into `C.DEFAULTS` (Sidebar.lua:33).
- Chat_OnDBReady merged `C.defaultsAtLoad`, a copy of both tables taken at the END OF CORE.LUA (P5 kept the defaults the game had while
  Chat_OnDBReady ran during Core.lua's load before P5), so neither the Sidebar's nor the privacy cover's defaults were in it.
  `C.EnsureDefaults` then set its once-per-store guard (`defaulted = s`), so the later `C.EnsureDefaults()` in `C.Refresh` and on the
  settings page (Options.lua:50), which would have used the full `C.DEFAULTS`, did nothing.
- The stand-in: `W.start` set `C.defaultsAtLoad = nil` before opening the store, so `C.EnsureDefaults(nil)` used the full `C.DEFAULTS` and
  `ns.Merge(chat, ns.CHAT_DEFAULTS)` the full privacy table. Every chat test therefore ran with every default; the game did not.
- Load order: `docs/reference/api/events.md:36` documents only the event: "`ADDON_LOADED` (addOnName: cstring, containsBindings: bool) ·
  SynchronousEvent · AddOns". That it fires after all of the addon's files ran and its saved variables are set is not in docs/reference:
  INFERENCE (the game's loader as `tests/harness/loader.lua` models it, lines 5-6 and 99-105, and what every addon's start-up relies on).
  The harness was right; the stand-in's shortcut was wrong.

## Fix
- `XayaUI_Chat/Core.lua`: `Chat_OnDBReady` merges the full `ns.CHAT_DEFAULTS` and calls `C.EnsureDefaults()`, which fills from the full
  `C.DEFAULTS`; the `C.defaultsAtLoad` copy is gone. Fill-only (nil keys): `ns.Merge` (XayaUI/Core.lua:259, `if dst[k] == nil`) and
  EnsureDefaults' `if s[k] == nil` never change a saved value, false included. The V14 early return (both chat switches saved off) is
  unchanged: nothing is filled then.
- `C.filledAtLogin = { chat = {key = true}, chat2 = {...} }`: the keys missing from the saved file and filled at this login (read by the
  walkthrough to say saved vs defaulted). Built only when the defaults are filled.
- `tests/chat_world.lua`: `W.start` no longer clears `C.defaultsAtLoad`; it runs the game's code path.
- No default value changed (sbFade stays true, sbOn true, ...). C6 / #469 not built.

## Scope (V4)
`git grep CHAT_DEFAULTS|EnsureDefaults|defaultsAtLoad|SIDEBAR_DEFAULTS|Chat_OnDBReady`: Core.lua (the fill), Options.lua:50 (page build:
EnsureDefaults, a no-op after login either way), Privacy.lua:12 (fills CHAT_DEFAULTS), Sidebar.lua:25-33, tests/chat_run.py:371 / 612 (read
the tables only), tests/chat_world.lua (the stand-in). Readers of the newly filled keys and what changes for a player who never set them:
- Sidebar (`s.sb*`, Sidebar.lua): only `sbFade` read differently (`if s.sbFade`: nil = no fade; now true = fades with the chat when the chat
  fade is on). Every other sb key is read as `~= false`, `== "X"` or with a fallback equal to its default: unchanged.
- Privacy cover (`s.priv*`, Privacy.lua): colour fill `s.privR or 0` (0,0,0) -> 0.04, 0.04, 0.06 (near black); TEXTURE mode with no texture
  picked: nothing drawn -> the dialog background; button opacity / size, cover opacity, offsets: fallbacks already equal the defaults; its
  settings page now shows every value (16 controls showed nothing / nil before: Button size, Button opacity, Whole cover opacity, Color
  0,0,0, the tick boxes...).
- Profile strings: the Blizzard Reskin part's chat2 / chat now carry those 37 keys (14 Sidebar, 23 privacy), each with its default.

## Tests
- New `tests/chat_defaults_run.py` (52 checks), in the whole-addon harness over real /reloads: G fresh install (every Chat / Sidebar / privacy
  default in XayaUIChatDB at login; with the chat fade on the sidebar fades with the chat; the page's "Fade with the chat" tick and the
  sidebar agree, V5; the cover draws its default colour), R after /reload (the file holds them; the second session changes nothing),
  E existing player (a file as Chat 0.6.45 wrote it plus her own values incl. `sbFade = false`, `privR = 1`: every saved value deep-equal
  after login and logout, only the missing keys added with their defaults, her false stays false and the sidebar stays at full strength,
  the cover draws her colour), M pre-P5 player (copied unchanged, defaults added, CueRulesDB untouched), O V14 (both switches off: nothing
  added), S stand-in parity (chat_world's chat2 / chat at start equal the harness's fresh install), Q the walkthrough (below).
  Negative control: with Core.lua and chat_world.lua of 1b974fe, 36 of 52 checks fail (sbFade nil, sidebar opacity 1 with the chat faded
  while its page shows the tick, cover 0,0,0, stand-in differs; the walkthrough's steps 1-3 give Fail there). The E deep-equal checks and
  O pass on the old code too (it never changed a saved value either): they guard the fix.
- Saved-data proof (E): before/after deep-equal for every key the file had (chat2 incl. the nested `sounds` / `whisperSounds` tables, chat,
  storeVersion); added = exactly the 11 missing chat2 keys and the 16 missing chat keys of that file, each with its default.
- Golden tests whose reference is the old code's output, each with the difference found by diffing old vs new and taken out explicitly:
  - `tests/settings_seam_run.py` B (hashes of main 8ced2e3, unchanged): `CHAT_DEFAULTS_ADDED` in canon. Diff of the canon dumps of 1b974fe
    and the new code: all on, both sessions, 18 lines: 14 privacy keys and `chat2.sbGap` added with their defaults, and `chat.privR/G/B`
    0 -> 0.04/0.04/0.06 (the scenario writes back what the settings page shows: before it showed 0,0,0 for the missing colour); core only: 0.
  - `tests/profile_parts_run.py` A and `tests/share_strings_presplit_run.py` B (old strings unchanged): the 37 Chat defaults are taken out
    of the decoded string where they hold their default and the rest must re-encode to the old string byte for byte; a check that all 37
    are there. Decoded diff old vs new: exactly those 37 keys added, nothing else.
  - `tests/options_split_parity_golden.json` regenerated (docstring updated): `--dump` of 1b974fe vs new: 16 lines per variant with Chat on,
    all `qol.improvedchat.privacy.*` get() results (nil -> the default); 0 with Chat off; 0 other lines.
- Run: `python3 tests/lua_pitfalls_run.py` FAILS: 0; chat_*_run.py, chat_run.py, settings_seam_run.py (56/0), settings_migration_run.py
  (92/0), qa_walks_chat_run.py, qa_walk_settings_migration_run.py, profile_parts_run.py (61/0), options_split_parity_run.py (95/0),
  share_strings_presplit_run.py (29/0), qa_walk_run.py; full suite: see the commit report.

## V22 walkthrough
`XayaUI_DevAssist/QAWalks-debug-chatdefaults.lua` (prefill): part 1 step 1 reads sbOn, sbFade, sbSide, sbShow, sbBg, sbPriv, step 2 the
privacy colour, fill, texture, button opacity and size, cover opacity, each "(s)" saved or "(d)" defaulted at this login, verdict: none
missing; step 3 (Do it for me) turns the chat fade on for a moment: the sidebar fades if "Fade with the chat" is ticked, stays if not; the
last step puts her fade settings back. "Ticked" is read as the settings page shows it (a missing value shows ticked), so on the old
code in the game this step gives Fail (ticked, sidebar not fading). Part 2 after /reload: every one "(s)" with the value part 1 read. Tested in the harness over a real
/reload (Q in chat_defaults_run.py), including a negative (missing keys -> Fail) and a saved `sbFade = false` (Pass, stays).

## For Xaya
- What changes in the game for a player who never touched these settings (visible, from filling the defaults the code already declared):
  the sidebar now fades with the chat when "Fade the chat when it is idle" is on (O-143, as the page already showed); the privacy cover's
  colour becomes 0.04/0.04/0.06 instead of 0/0/0 (near black either way); a cover set to Texture with none picked now shows the dialog
  background; the privacy cover's settings page shows its values instead of blanks. A value she set herself is not changed.
- #494 is not explained by this (see above); C6 / #469 (sidebar off by default when another chat addon is loaded) stays her decision.
