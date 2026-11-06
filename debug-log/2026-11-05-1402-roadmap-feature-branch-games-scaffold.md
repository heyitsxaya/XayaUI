# Roadmap feature branch: games scaffold, outline only (no version change)
Logged 2026-11-05-1402 UTC. Branch: `roadmap-features/games`. Roadmap: RM-GAMES (`docs/plans/GAMES-MODULE-2026-11-05.md`). Session: https://claude.ai/code/session_014bN6tSRsJgz4JWyawQp5gk

Xaya (her words): "Rough scaffolding and proposed code structure (outline only) in a dedicated “roadmap features: ______” brand per feature". Read as "branch" (inference: "brand" taken as a typo). Built:
- `roadmap-features/games/`, which holds the README (layout, structure rules, decision tree), `CORE-HOOK.md`, a proposed `XayaUI_Games/` (the .toc, 11 Lua outline files, an LFG simulator placeholder) and `tests/README.md`.
- Every Lua file is comments only. Checked: `grep -v` for non-comment, non-blank lines found none.

Scope (V4): nothing outside `roadmap-features/` and this entry changed, apart from `MANIFEST.md5`. No addon folder, .toc version, test, USER-GUIDE or QA-CHECKLIST line was touched. The scaffold sits outside the top-level `XayaUI*` folders on purpose: `tools/precheck.py:107` and `:159-161`, `tests/lua_pitfalls_run.py:20-25` and `tools/sync-qa-branch.sh` treat every top-level `XayaUI*` folder as a shipping addon.

Reuse found: puzzle packs are proposed as one more kind of core's share codec (`XayaUI/Share.lua`, `ns.Share.RegisterKind`, a data-only JSON reader), not a new format.

API entries cited from `docs/reference/api/`:
- `C_AddOns.*` (namespaces.md:148-164)
- addon messages (namespaces.md:840-845, enums.md:11106, 11728-11743, events.md:185, 278)
- `C_ChatInfo.SendChatMessage` (namespaces.md:847: HasRestrictions, RestrictedForMacroChatMessages)
- `EnableKeyboard` / `SetPropagateKeyboardInput` (widgets.md:109, 295)
- `C_LFGList.*` (namespaces.md:2952, 2963, 3019)

INFERENCE, marked in the files:
- `uiAddon` takes an index;
- `X-` .toc fields can be read before an addon loads;
- `math.random` cannot be seeded the same on every client;
- an edit box avoids the keyboard restrictions.

Not run: the full suite (no addon code changed).
