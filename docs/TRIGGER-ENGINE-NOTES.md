# Trigger engine notes (Midnight 12.x evidence and design decisions)

Source: handoff `...TRIGGERS-AND-OUTCOMES` (2026-10-31). Confidence key: **VERIFIED** = seen in Xaya's game output or run against the real files; **OFFLINE** = stub tests only; **INFERRED** = read from code/docs; **UNVERIFIED** = nobody has checked.

## Target Debuff (yours) in combat

Evidence from Xaya's in-game output (VERIFIED, one sample per state):
- `C_UnitAuras.GetUnitAuras("target","HARMFUL|PLAYER")` **throws** in combat: `Auras cannot be accessed when secret while tainted by 'XayaUI'`.
- `C_UnitAuras.GetAuraDataBySpellName("target", name, "HARMFUL|PLAYER")` returned nil in combat **while the debuff was up** (false negative). The trigger no longer uses it; `ns.TargetAuraByName` remains only for `/xui debuffs <unit> <id>`.
- Blizzard's Cooldown Manager buff icon for the spell exposes plain fields. Debuff up: `iid=secret wasAura=false shown=true unit=target`. Debuff absent (live target): `iid=nil wasAura=false shown=false unit=nil`.
- EllesmereUI draws target debuffs with engine `AuraContainer` groups (filter tokens `HARMFUL`+`PLAYER`), so Lua never reads per-aura data. That route cannot return a boolean to gate a sound, so it was rejected. A developer comment in EUI's `EUI_CDM_BuffBarTick.lua` suggests Blizzard's buff viewer carries player-applied target debuffs and rebinds on target change (INFERRED support, not Blizzard documentation).

Decision logic (`Add("targetDebuff", ...)` in `Triggers.lua`; state "no" inverts):
1. No unit: false. Aura list readable and contains the ID: true (trusted anywhere).
2. List read threw or was incomplete AND unit is target: Cooldown Manager icon for the debuff ID (or optional `cdmID`) active: true. Icon exists but inactive: false (unless row option `cdmAbsent` = "no"). No icon: unknown.
3. Complete, cleanly read list lacking the ID: false only out of combat; unknown in combat.
4. Focus never uses the icon. Unknown means the rule does not fire.

Use case that drove it: Sigil of Spite sound only if the Sigil of Flame debuff (**204598**; the ability is 204596) is on the target.

## Design decisions (rejected options)

| Question | Chosen | Rejected, and why |
|---|---|---|
| Trigger data model | additive `rule.extra = { list = {} }` | split data model (migration risk) |
| Health / power / combat-log trigger types | not offered | Midnight secrecy would make them misfire |
| Outcomes | linked rules (`parentUid`) bundled into the parent's UI | ordered sequences / whole-rule AND/OR/NOT (Xaya did not choose) |
| Multiple cooldowns per rule | new repeatable extra-trigger type `cooldown` (reuses `ns.ReadCooldown` / `ns.CheckCooldownState`) | extra slots in built-in "1. Cooldown" (Outcomes, `ExplainRule`, `trigOrder` assume one `cd` token); Spell Usable "ready" only (binary, no hasCharge / notReady / empty / charge override) |
| Button consistency | same labels/widths/order, short labels | widening buttons (pixel width differs between page and inline group; unverifiable offline) |
| Sigil early-sound cause | Spell Usable ignores cooldown + Sigil activates after 2 s (INFERRED) | tick rate 0.2 s (too small for 1-2 s) |
| "Never fires" cause | `CheckExtraTriggers` returned no rows (x-refs always nil) | blaming the aura API (status output showed x-refs UNKNOWN even out of combat) |

## Offline test method

No Lua runs on Xaya's machine. Tests used Python `lupa` (Lua 5.1) with stubbed WoW globals, loading the **real deployed addon files**. An earlier test loaded scratch copies and hid the row bug, so never repeat that. At the time of the handoff: a 95-check suite and three scenario scripts (deployed-files end-to-end, Cooldown Manager icon states, Sigil of Flame cast timeline) passed against the committed files. The scripts themselves are **not in this repo** (they live in Xaya's project docs as `claude/TRIGGERS-TEST-HARNESS-2026-10-31.md`). This proves syntax and logic only, not the options UI layout.

## Diagnostics

`/xui status` prints `x1(targetDebuff)=true|false|UNKNOWN [reason]`, `combination=`, `sound plays=` for outcomes. `/xui debuffs [target|focus] [spellID]` prints the list-call result and by-name lookup. `/xui probe <spellID>` prints the Cooldown Manager frame including `unit=`. Out-of-combat testing of a rule that loads only in combat needs parent Load > combat set to "none".

## Not an XayaUI bug

The Plater error `bad argument #1 to 'SetWidth' ... Secret values` seen at 08:29 comes from a Plater mod script ("Cast Bar Icon Settings [P]").

## External references that are NOT in this repo

- `Triggers.lua` header points to a `TRIGGERS-TRACKER` port matrix. It lives in Xaya's project docs (`claude/TRIGGERS-TRACKER.md`), so the matrix (and its section 3E backlog of next trigger types and section 6 list of unverified API shapes) is not recoverable from the repo.
- `XAYAUI-ENGINE-AURA-TRACKER.md`, `XAYAUI-DEBUG-LOG.md`, `XAYAUI-REQUEST-LOG.md`, `XAYAUI-LOG-ADDENDUM-2026-10-31.md`: project docs only.
