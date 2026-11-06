# Chat history: "||" set aside before codes are stripped (XayaUI_Chat 0.6.19)
Logged 2026-11-06 17:15 UTC by session 014bN6tSStpdmmCXviFAqPdQ (branch `claude/determined-gates-89j6pv`), continuing the WIP of
session 014bN6tTjuXobzzk8oJHeYwn (8e20e1b on `claude/eloquent-wright-iic6k6`), handed over at Xaya's request (REQUEST-LOG #81, #82).
Nothing here has run in the game.

## Her request (REQUEST-LOG O-81)
The chat history window lost literal pipes and sometimes the next letter (her screenshot of 2026-11-05: `[highlighttrail]`,
`statusidthprobe`). Her two strings were already fixed on `main` by Chat 0.6.17 (4fd7c98: `C.ForEditBox` doubles each "|" for the
edit box; QA D12). So a test of her two strings cannot fail on `main`; it fails only on 0.6.16. Said to her plainly.

## The defect left (reproduced)
`C.Plain` (XayaUI_Chat/History.lua) took the codes out first and collapsed "||" last. The second "|" of a "||" pair, plus the letter
after it, was read as a code when that letter starts one (r, n, c + 8 hex, cn..:, T..|t, H..|h, A..|a, K..|k) and removed:
- the `/xui chat` status line (XayaUI_Chat/Core.lua:594, printed with every "|" doubled) read "on|off|eset|move|..." in the Console tab;
- "[on||none]" -> "[on| one]"; "a||cffff0000b" -> "a|b"; "x||Ty||tz" -> "x|z"; "|cffff0000red|r ||n" -> "red | ".
A player's chat line with a typed "|" before one of those letters is hit the same way (the game sends a typed "|" as "||": INFERENCE,
not in docs/reference).

## Fix
`C.Plain` first turns each "||" into byte 0xFF, then strips the codes, then turns 0xFF back into one "|". 0xFF never occurs in UTF-8
text; that the game's strings are UTF-8 is an INFERENCE (not in docs/reference). Left to right, "||" is taken before a following
"|r", so "|||r" gives "|" (the game reads "||" as one "|" and "|r" as a code: INFERENCE consistent with Blizzard's escape rule).
`C.ForEditBox` is unchanged.

## Scope (V4)
`git grep C.Plain`: one caller, `C.History_Lines` (XayaUI_Chat/History.lua:87: display, search and copy text), plus tests/chat_run.py.
The other `Plain()` functions (core Console.lua, DebugRecord.lua, QoL CharacterToolkit.lua, Dev Assist) are separate locals, not
touched. No `/xui help` string other than the `/xui chat` status line hits the case today (checked by that session).

## Ctrl+C (her "decide what Ctrl+C should copy")
Not controllable by the addon: `CopyToClipboard(text: cstring, removeMarkup: bool = false) -> length: number · HasRestrictions,
SecretArguments=AllowedWhenUntainted` (docs/reference/api/globals.md:77; restricted, so addon code cannot use it: INFERENCE). The
edit box has `GetDisplayText()` (widgets.md:1149, MayReturnNothing) but no documented escape rule. Target: one "|" (what the window
shows). QA D12 already asks what pastes; if it pastes "||", the options go to her (proposal first, V16).

## Tests (V1, V5)
tests/chat_run.py: eight `C.Plain` cases and the `/xui chat` status line end to end (print -> Console tab -> `C.History_Lines`
and the edit box's text). On `main`'s History.lua 7 of them fail ("on|off|eset|move", "[on| one]", "a|b", "x|z", "red | ", and the
two end-to-end checks); with the fix all pass. Her two strings stay covered by the 0.6.17 checks.

## QA
D13 (new).

## Checks
`XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py` on e41175a's files: ALL CHECKS PASS (API documentation loaded;
every addon combination 0 fail). `tests/lua_pitfalls_run.py`: FAILS 0. `tools/precheck.py --base origin/main`: FAILS 0, 2 warnings (media
lists, #333 / #290, already on `main`).

## Landing
Held on the branch for the next bundled landing (V17); not on `main`.
