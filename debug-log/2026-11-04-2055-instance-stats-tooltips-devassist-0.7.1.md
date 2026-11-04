# /xuidev instance, stats and tooltips captures (XayaUI_DevAssist 0.7.1; fork: main)
Logged 2026-11-04 20:55 UTC. Session 014bN6tSy3HbUDWYQsk69naX, branch `claude/inspiring-mendel-8r8qao` (draft PR #386). Nothing here has
run in the game.

## Request
SESSION-START-SUMMARY section 4, item 2 (backlog F): the in-game captures for the content data pulls. Xaya, 2026-11-04 20:48 UTC:
"optimize for the highest cost token expenditure that you can complete within a 1h window", then "pick the biggest task, and
fast-track it". Picked because it is unblocked, lives in its own addon folder (another session works in parallel on PR #385: QoL and
core 0.6.32), and Xaya's dungeon run on 2026-11-05 (run sheet step 7) can collect it if it is on `main` first. Plan and decision
graph: `docs/plans/INSTANCE-CAPTURE-2026-11-04.md`.

## Scope (V4: every reader and caller touched)
- `XayaUI_DevAssist/Probe.lua`: new section 12; hooks at the end of `Identity` (nameplate added / combat flag change; NR skipped),
  in `Cast` (CS / CC / CL), in `Anchor` (on, resume, zone, encounter, off), and `IX.enc` set at ENCOUNTER_START, cleared at
  ENCOUNTER_END; status line 12; `GD.RuleSpellIDs` exported (the existing `RuleIDs`, for TooltipCapture.lua); `GD.Instance`,
  `GD.InstanceSummary`.
- `XayaUI_DevAssist/DevAssist.lua`: `/xuidev instance | stats | tooltips` routes, help text, `/xuidev status` fields.
- `XayaUI_DevAssist/AuraCatalogue.lua`: `mplus.seasonValues` from `C_MythicPlus.GetCurrentSeasonValues()`.
- `XayaUI_DevAssist/StatsCapture.lua`, `TooltipCapture.lua` (new; written by a parallel sub-agent of this session, see below).
- `XayaUI_DevAssist/XayaUI_DevAssist.toc`: 0.7.1, the two files, Notes.
- Other readers of the same calls, unchanged: `XayaUI_Bonus/Tooltips.lua:607-693` reads `GetUnitCriteriaProgressValues` for the
  enemy-forces tooltip line (it displays; Dev Assist records). No parity test: they do not decide the same thing.
- Saved data: new `XayaUIDevAssistDB.instance`, `.stats`, `.tooltips`; `.probe` unchanged except one hook-free field.

## API (V2; quoted in full in the Probe.lua section 12 header)
- `C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)` -> actualValue, percentValue, percentValueString · MayReturnNothing,
  SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted.
- `C_ScenarioInfo.GetScenarioStepInfo`, `GetCriteriaInfo` · MayReturnNothing, SecretArguments=AllowedWhenUntainted (structures
  ScenarioStepInfo, ScenarioCriteriaInfo, `docs/reference/api/structures.md:6101, 6207`).
- `C_ChallengeMode.GetActiveChallengeMapID`, `GetActiveKeystoneInfo`, `C_MythicPlus.GetCurrentSeasonValues`, `GetCurrentSeason`:
  no flags (`namespaces.md:746-747, 3297-3298`).
- `C_UnitAuras.GetAuraDataByIndex` · RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted.
  AuraData's fields are not in the generated reference.
- `UnitExists` · SecretArguments=AllowedWhenUntainted. Identity reads as in section 6 (`UnitCreatureID`:
  RequiresUnitIdentityAccess, SecretWhenUnitIdentityRestricted).
- INFERENCES (marked in the code): AuraData has `spellId` / `name` on enemy units as on the player; which criterion is the
  enemy-forces bar (every criterion is kept with isWeightedProgress and totalQuantity, so it can be chosen afterwards);
  displaySeasonID equals the client table's DisplaySeasonID.

## Design
- One recorder: the instance summary rides on the probe's existing enemy reads and secrecy path (the design note in the summary),
  so it collects only while `/xuidev probe on`; `/xuidev instance` also reads the visible units on demand.
- Keyed by creature ID. When the game hides the creature ID (expected in combat: SecretWhenUnitIdentityRestricted), the sighting is
  counted under the instance (`hidden`) and a readable cast spell is kept under the instance (`orphanCasts`): never guessed onto a
  creature.
- Players are never filed (UnitIsPlayer must read false). Caps: 600 creatures, 30 spells and 30 auras each, 200 orphan spells per
  instance, 40 auras per filter, 20 criteria.

## Tests (V1, V5, V8)
- `tests/devassist_instance_run.py` (new): 39 checks in the probe test's stand-in world (secret sentinel that raises on any use),
  outcome-based (what lands in `XayaUIDevAssistDB.instance` and in chat). Negative control: 7 deliberate breaks (each hook cut,
  players filed, secret Mythic+ stored, no auras), each caught by at least one check. The first run caught a gap: a player's nameplate
  counted as a hidden creature under one break went unnoticed; a check was added.
- `tests/devassist_rename_run.py`: the toc check now accepts version 0.7.0 or later (it pinned 0.7.0).
- `tests/devassist_probe_run.py` (99 checks, 103 breaks), `devassist_api_run.py`, `devassist_catalogue_run.py`,
  `lua_pitfalls_run.py`: pass.

## Not verified
Everything in game: QA J13-J16. Whether creature IDs, Mythic+ counts and enemy auras are readable out of combat in a Mythic+ run at
all is exactly what J14 answers.
