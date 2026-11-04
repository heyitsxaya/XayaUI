# API reference (XayaUI core reference)

Captured in the live client by XayaUI Game Data Capture (`/xuidump api`): build 12.1.5 (70783), interface 120105, captured 2026-11-03 21:49 (local time).
Signatures, flags and notes come from Blizzard's generated API documentation (12.1.5.70688). Where the client is newer than the documentation, a name can exist without a documented signature.


| | Count |
|---|---|
| Global functions (game, Blizzard UI and loaded addons) | 6411 (685 documented) |
| C_ namespaces | 259 |
| C_ namespace functions | 4793 (4181 documented) |
| Enums | 1823 |
| Numeric ALL-CAPS globals | 2450 |
| Widget types | 20 |
| Documented events | 1784 |
| Documented structures | 841 |

Files: `namespaces.md`, `globals.md`, `enums.md`, `constants.md`, `widgets.md`, `events.md`, `structures.md`, and `api.json` (all of it, machine-readable).

How to read a line: `` `C_Item.GetItemStats(itemLink: cstring)` → `statTable: LuaValueVariant` · SecretArguments=AllowedWhenUntainted ``. `?` after a type means it may be nil; flags are Blizzard's own (for example `SecretReturns`, `RequiresNonSecretAura`, `MayReturnNothing`). A name with no signature exists in the client but is not in the generated documentation (older global functions, Blizzard UI code, addons).

Rebuild: `python3 docs/reference/build_reference.py --saved <XayaUI_GameDump.lua> --docs <Blizzard_APIDocumentationGenerated folder> --out docs/reference --public`.

PUBLIC VERSION (this repository is public): Blizzard's written notes on functions, events and fields are left out, and so are the undocumented globals and numeric globals (they also hold the names of every addon loaded during the capture). The full version, with all of that, is in Xaya's private Google Drive folder "Blizzard API Data" (XayaUI-reference-full-*.zip).
