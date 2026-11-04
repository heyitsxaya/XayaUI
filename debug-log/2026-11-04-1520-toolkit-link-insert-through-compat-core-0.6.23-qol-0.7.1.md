# Character Toolkit: the shift-click hook goes through Compat.lua (XayaUI core 0.6.23, XayaUI_QoL 0.7.1; fork: main)
Logged 2026-11-04 15:20 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Not reported by a player; found by the full offline suite.
Nothing here has run in the game yet.

## How it was found
- The handoff asked to run the full suite on `claude/eloquent-rubin-n9zb99` before landing it on `main`. This cloud container had
  neither harness index (`tests/harness/api_index.json`, `framexml_index.json`; both gitignored).
- Both were rebuilt from the public mirror of Blizzard's UI code, github.com/Gethe/wow-ui-source, branch `live`, commit `d07eb00`
  ("12.1.5 (70688)"): the same build as the Drive files `WOW-API-FULL-12.1.5.70688-*`.
  - The 623 entries of `Blizzard_APIDocumentationGenerated` were concatenated into the dump format `build_api_index.py` reads:
    622 files parsed, 0 unparsed; 4970 functions, 1784 events, 856 enums, 76 widget method lists.
  - Before running them: every one of those files makes exactly one call, `APIDocumentation:AddDocumentationTable`. A grep for
    `os.` / `io.` / `require` / `loadstring` / `dofile` found only the English word "require" inside documentation strings.
  - `build_framexml_index.py` on the same checkout: 18235 names, 232 only as deprecation fallbacks.
- With the FrameXML index present, the harness's static check failed:
  `XayaUI_QoL/CharacterToolkit.lua:412 uses ChatEdit_InsertLink, which 12.1.5 defines only as a deprecation fallback`.
  - INFERENCE: earlier runs did not have `framexml_index.json`, so this check did not run on QoL 0.7.0. The handoff named only
    `api_index.json`.
  - The code is on `main` since QoL 0.7.0. It did not come from the branch being landed.

## Was it a live bug? No (checked in Blizzard's code)
- 12.1.5 (70688 `d07eb00` and 70783 `297d7aa`) defines `ChatEdit_InsertLink` only in
  `Blizzard_DeprecatedChatInfo/Deprecated_ChatFrame.lua:43`: `ChatEdit_InsertLink = ChatFrameUtil.InsertLink;`.
  - That file starts with `if not GetCVarBool("loadDeprecationFallbacks") then return; end`.
  - The real function is `ChatFrameUtil.InsertLink(text)` (`Blizzard_ChatFrameBase/Mainline/ChatFrameUtilOverrides.lua:14`).
    Blizzard's own code calls it directly, for example `Blizzard_AchievementUI.lua:1108` and `SpellFlyout.lua:33`.
- The old code hooked `ChatFrameUtil.InsertLink` first. It used the old global only when that was missing, and only when the
  global was a function. So in 12.1.5 it worked with the setting on or off.
- What was wrong is the rule in `XayaUI/Compat.lua`'s header: "No other file may name an old global". `tests/harness/run.py`
  fails the build when one does. With that check red, the full suite could not pass on `main` or on any branch.

## What changed
- `XayaUI/Compat.lua`: `InsertLink = "ChatEdit_InsertLink"` added to the chat fallback map. `Compat.ChatHookTarget("InsertLink")`
  now answers with `ChatFrameUtil, "InsertLink"`, or `_G, "ChatEdit_InsertLink"` on a client that has only the old name, or nil.
- `XayaUI_QoL/CharacterToolkit.lua`: the What If item box hooks whatever `ns.Compat.ChatHookTarget("InsertLink")` returns.
  - It no longer names `ChatEdit_InsertLink`.
  - If Compat is missing, or neither function exists, nothing is hooked and nothing errors. The box still takes typed IDs.
- Player-visible behaviour is unchanged, so USER-GUIDE.md is not edited (its section 13: describe behaviour, not history).

## Scope (V4)
`git grep "ChatEdit_InsertLink\|ChatFrameUtil.InsertLink"` over the addon folders and tests:
- `XayaUI_QoL/CharacterToolkit.lua:411-412`: the only direct use, now through Compat.
- `XayaUI_Options/Libs/AceGUI-3.0/widgets/AceGUIWidget-EditBox.lua:22-25` and `AceGUIWidget-MultiLineEditBox.lua:19-22`:
  third-party library copies. Not changed: libraries stay as published, and the harness static check did not flag them.
- `tests/char_toolkit2_run.py:310`: calls `ChatFrameUtil.InsertLink` in the stand-in world.
- `XayaUI_Chat/Frame.lua:522`: already uses `ns.Compat.ChatHookTarget` (for ActivateChat / DeactivateChat), the same pattern.

## Tests
- `tests/char_toolkit2_run.py`, 134 to 138 checks:
  - it now loads `XayaUI/Compat.lua` after `Modules.lua`, as `XayaUI.toc` does;
  - older client, with only `ChatEdit_InsertLink`: a shift-clicked item still goes into the item box;
  - neither function: the panel builds and opens on What If, and nothing is hooked;
  - the 12.x path (line 310) still passes.
- **Negative control:**
  - The harness static check, `python3 tests/harness/run.py --fresh-only --only XayaUI_QoL` with both indexes, FAILS on the old
    `CharacterToolkit.lua` (`RESULT: FAIL (1)`, the line above) and passes on the new one.
  - The new behaviour checks also pass on the old file (134 + 4 = 138 there too). They are regression guards for the Compat route,
    not negative controls; the old code reached the same functions directly.
- QA: E1o (shift-click with `loadDeprecationFallbacks` 0).
- Full suite: run on the commit that goes to `main`; the result is in the reply and the next debug-log entry.
