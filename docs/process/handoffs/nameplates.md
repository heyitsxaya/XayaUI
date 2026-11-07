# Handoff: Nameplates session (session_014bN6tUt2Da7LiGNYKgtM7R), 2026-11-07

Protocol: docs/process/HUB-HANDOFF-2026-11-07.md (O-152). Successor reads this file, then the branch `claude/nameplates-plater`.
Hub: session_014bN6tWMaSvKkwjeonHvvch. Lander: session_014bN6tSZh6UFB2WcRuyXqBZ. QA question flow: session_014bN6tUZLKHa2NXorHRJghL.
Perf session (CLEAN-8 notes): session_014bN6tTxYo6enpkMGsVkMqm.

## Xaya's requests in this session (verbatim), with status
This session started 2026-11-07 ~07:05 UTC. Every request is relayed (her words read verbatim from the opening hub's transcript or
relayed by a hub). Logged in docs/process/REQUEST-LOG.md section A15.

| # | Her words | Status |
|---|---|---|
| NP-1 | "if you can replicate the following mods and profile functionality into xui and make it cost less, here are the nameplate mods and settings I rely on" (followed by four `!PLATER:2!` export strings; the 1st and 3rd are identical) | Slices 1 + 2a (0.2.1): branch `claude/nameplates-plater`@2b9058c, sent to the lander. Remaining slices wait on her answers (see below). |
| NP-2 | (relayed) on "Aura Reorder", "Current Target Color", "Reorder Nameplate": "I rely heavily on these three at least, though" | Current Target Color: built (0.1.0). Reorder Nameplate: Blizzard's own layout matches; no code; a walkthrough step asks her. Aura Reorder: not built, question NP-Q5. |
| NP-3 | (relayed context) mouse lag in Mythic+ only; Plater mod "Attacking Specific Unit" failing on every update with "attempt to perform string conversion on a secret string value"; Plater about 2 % CPU, 33.9 MB | Noted. The mod is OFF in her export (question NP-Q8). The measurement method is in the plan. |
| NP-4 | (relayed, ~08:25 UTC) "I have to go to sleep. I want everything I've requested over the last 16h — and I mean EVERYTHING — implemented and pushed to main when I wake up. ... I should not find ANYTHING is not pushed to main when I wake up." | Slice 2a was built for it. Questions sent to the flow. |
| (relayed) | "you can ask questions after the outstanding items are pushed, to be clear" | Applied: questions go only through the QA flow tonight. |

## Where things are
- Branch `claude/nameplates-plater`, draft PR #442 (subscribed). Tested head: 2b9058c (main bf2ce6a merged in), full suite: ALL CHECKS PASS on 1ed83cf (main 3d38cb0 merged); 2b9058c = 1ed83cf + main bf2ce6a, precheck --base origin/main FAILS 0, targeted tests pass (nameplates, console_commands, display_standard, sidebar_switches, qa_walk, lua_pitfalls, harness).
- Docs: docs/plans/NAMEPLATES-PLATER-INVENTORY-2026-11-07.md (what her Plater export contains, in our own words) and
  docs/plans/NAMEPLATES-PLAN-2026-11-07.md (feasibility per item, flagged readings R1-R6, cost estimate, the perf session's A/B/C
  measurement method, slices).
- Code:
  - `XayaUI_Nameplates/` (new addon, `## DefaultState: disabled`): Core.lua (settings, page QoL > Nameplates, `/xui nameplates`, service "nameplates"), TargetColor.lua (slice 1), BlizzardOptions.lua (slice 2a).
  - `XayaUI_DevAssist/QAWalks-nameplates.lua`: two walkthroughs, prefill.
- Tests: tests/nameplates_run.py (35 checks); tests/console_commands_run.py help count 20; tests/sidebar_switches_run.py lists qol>nameplates.
- QA-CHECKLIST: section K, K1-K5.
- Debug log:
  - debug-log/2026-11-07-0717-nameplates-target-colour-0.1.0-devassist-0.7.14.md
  - debug-log/2026-11-07-0832-nameplates-blizzard-options-0.2.0.md

## Versions claimed
- XayaUI_Nameplates 0.2.1 (new addon; nobody else uses it).
- XayaUI_DevAssist 0.7.32. On 08:45 UTC 0.7.31 was the highest on any branch; the lander may relabel.
- QA ids K1-K5 (section K is new; no other branch used K).

## Questions sent to the QA flow (2026-11-07 ~08:30 UTC)
NP-Q1 base (Blizzard plates vs own plates); NP-Q2 addon disabled by default; NP-Q3 teal / flat colour; NP-Q4 page place; NP-Q5 aura
order; NP-Q6 exact sizes; NP-Q7 spell / NPC-keyed scripts impossible in Mythic+; NP-Q8 is "Attacking Specific Unit" still on.

## Hard rules for the successor
- Never copy Plater's (or any addon's) code, data, spell / NPC lists or text into the repo (#290). Her export strings are not in the
  repo. Should they be needed again, read them from session_014bN6tSStpdmmCXviFAqPdQ's transcript (list_events, kinds ["user"], 2026-11-07
  07:04 UTC). Decode only in a scratch folder (base64 → raw deflate → CBOR) with `python3 -I`. Never run their Lua.
- V14: a nameplate feature costs nothing while off. V22: each change gets a prefill walkthrough. CLEAN-8 notes to the perf session.
- Only the lander pushes main.

## Next steps (after her answers in the QA flow)
1. NP-Q5 → slice 2b aura order: only by the game's own sort rules (`C_UnitAuras.GetUnitAuras` sortRule). Re-laying out Blizzard's aura
   icons needs an in-game taint check first.
2. Her exact threat / quest / tapped colours: tint layer like TargetColor.lua, only where the colour choice reads no secret value
   (threat state is secret for addons in restricted content: plan B3).
3. NP-Q1 (b) → our own plates: a separate, large design (Plater-like cost), only if she chooses it.
4. When the perf session has numbers from the A/B/C method, add them to the plan's cost section (replacing the estimate).
