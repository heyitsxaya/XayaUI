# Proposed core hook: finding load-on-demand features (outline only)

## The problem
A load-on-demand add-on runs no code until something loads it, so it cannot register its own minimap row or `/xui` command at login. Today the suite's one load-on-demand add-on, `XayaUI_Options`, is named in core (`ns.OPTIONS_ADDON`, `XayaUI/Modules.lua:252`; loaded by `ns.LoadOptions`, `:253-262`). Doing that again for the games breaks the contract at the top of `Modules.lua`: "Core never calls a feature by name."

## Proposal (not decided)
The add-on's .toc carries its own launcher line:
```
## X-XayaUI-Launcher: Games
## X-XayaUI-Command: games
```
At login, core walks the installed add-ons. For each one that is load-on-demand and has an `X-XayaUI-Launcher` line, it registers:
- a minimap row (`ns.RegisterLauncher`) and a `/xui <command>` (`ns.RegisterCommand`). Each one loads the add-on (`C_AddOns.LoadAddOn`, inside pcall) and then hands the click on to it.

Once loaded, the add-on registers its real handlers through `Modules.lua` as usual and takes over its row and command.

## Calls it would use (12.1.5 reference, `docs/reference/api/namespaces.md`)
- `C_AddOns.GetNumAddOns()` → `numAddOns: number` (:157)
- `C_AddOns.GetAddOnMetadata(name: uiAddon, variable: cstring)` → `value: cstring` · SecretArguments=AllowedWhenUntainted (:151)
- `C_AddOns.IsAddOnLoadOnDemand(name: uiAddon)` → `loadOnDemand: bool` · SecretArguments=AllowedWhenUntainted (:160)
- `C_AddOns.LoadAddOn(name: uiAddon)` → `loaded: bool?, value: string?` · SecretArguments=AllowedWhenUntainted (:164)

INFERENCE, to be checked before building:
- that `uiAddon` takes an index as well as a name;
- that a custom `X-` field can be read before the add-on is loaded;
- that an add-on switched off in the AddOns list is reported as not loadable (`C_AddOns.GetAddOnInfo`'s `loadable` / `reason`, :148).

## What it would touch
- `XayaUI/Modules.lua` (a new section beside section 7) and its contract header.
- A test that a fake add-on with the field gets a row and a command, and that one without it gets neither.
- Possibly `XayaUI_Options` later, if it moves to the same route (not proposed).
