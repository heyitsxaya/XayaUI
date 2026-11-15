# Load conditions: per-condition CPU and memory evaluation (RB-19)

Her instruction (RB-19), verbatim: "for all of these, do a per-condition performance evaluation and only create each of these load conditions after thoroughly investigating how these can be done with minimal cpu/memory cost. only implement the ones that are obviously easy to track without much performance effort right now"

**Status:** evaluation only. No addon code was changed.

**Method:** a workflow of 34 independent agents, 2026-11-12.
1. One engine analysis: how the load context is read today.
2. One evaluator per condition (15 conditions).
3. Every "easy-now" verdict was then given to two skeptics, each told to refute it. One looked at the busiest case for CPU; the other at correctness and combat safety. A single refutation downgrades the verdict.

**Limits:**
- No game client. Event frequencies and costs in game are INFERENCE unless the source or docs/reference/api proves them.
- Conditions.lua line numbers may move, because bundle 1 round 7 is editing that file.
- The full per-agent output is in the session's workflow journal, run wf_ddbd0e4e-094.

## 1. The main finding: the engine has no "unused costs nothing" path for load facts today

Source: the engine analysis, cited from Engine.lua and Conditions.lua.

**How a load fact is paid for today:**
- `ns.ReadContext` reads every load fact on every context event, whether or not any rule uses it.
- Every fact is part of `ctx.sig`.
- When any part of the signature changes, a full step re-checks every rule (O(N)). Mounting, a subzone change, a gear swap or a roster change can each start one, even when no rule uses that fact.
- All context events are registered all the time.

**What that means for new conditions:** adding one on this path makes every player pay for it. Only three conditions are cheap enough that this does not matter: M2, M14 and M20 (see §2).

**The cheapest correct path,** engine analysis item 8, is three pieces:
- **(A) A usage set.** It is rebuilt once per settings change, as a bounded pass over rules that are on or previewed and their group chain. Off rules don't count (V34); every group level does (V32).
- **(B) Per-condition descriptors.** Each holds the condition's read, its signature part and its events. A fact is read, added to the signature and has its events registered only while it is used.
- **(C) A per-key dirty read.** A condition's event re-reads only that key, and starts a full step only if the value changed and the key is used.

With (A) to (C), an unused condition costs zero reads, zero signature churn and zero registered events. They are a Rules engine change, so they go to the Rules session (§4).

## 2. Verdicts

| Id | Condition | Evaluator | After skeptics | Why (short) |
|---|---|---|---|---|
| M1 | Pet battle (in / not in) | easy-now | **feasible-needs-care** (2/2 skeptics refuted) | This is obviously cheap. - Events: 2-3 low-frequency global events with no payload, firing a few times per pet battle and never in raid or M+ combat (INFERENCE that pet battles cannot happen there). - Read: one O(1) read guarded with pcall and issecret, or no … |
| M2 | In a vehicle (seated): only while you occupy a vehicle / nev | easy-now | **easy-now** (0/2 skeptics refuted) | M2 is easy to add now and cheap. - The read is one O(1) call, UnitInVehicle("player") (globals.md:620). Its only secrecy flag covers arguments, so the answer is readable in combat and M+. - The rule builder already uses this exact read for the vehicle trigger … |
| M3 | Game has swapped your action bar (vehicle / override / posse | easy-now | **feasible-needs-care** (2/2 skeptics refuted) | M3 is obviously cheap, provided it lands on the usage-gated path rather than as an always-on CTX event plus a sig part: - The read is 3 argument-free C_ActionBar booleans, and none is secret: flags are empty in api.json at :23439, :23388 and :23598 (namespaces… |
| M4 | Skyriding possible now (can glide, ground included) | feasible-needs-care | **feasible-needs-care** | On its own, M4 is about as cheap as a load condition gets: - one O(1) C call with no flags, or just the event's boolean payload - one low-frequency edge event with no secret flags (namespaces.md:3694, events.md:1162) - expected to sit still at false in raid an… |
| M5 | Airborne while skyriding (show only while gliding / never th | feasible-needs-care | **feasible-needs-care** | The fact itself is about as cheap as a fact gets: - an edge-triggered event that carries the answer in its payload (events.md:1186), with no secret flags; - an O(1) non-secret read when needed (namespaces.md:3694); - no per-frame work; - essentially no firing … |
| M6 | Inside a house or housing plot (optionally your own) | easy-now | **feasible-needs-care** (2/2 skeptics refuted) | This passes as clearly cheap on every criterion: - The read is O(1): 1-2 argument-free C_Housing calls with no secrecy flags (namespaces.md:2348, 2351; api.json:38074-38087 flags []). - There are only 2 new events, both global, payload-free and rare (events.md… |
| M7 | Delve as its own place kind (inside a delve, lairs excluded  | feasible-needs-care | **feasible-needs-care** | M7 is cheap by nature but not obviously easy now.  Why it is cheap: - The read is O(1): two flag-free boolean getters, with no secrecy flags (namespaces.md:1608, 3433). - The entry and exit events are already registered. - Backup events are low-frequency and n… |
| M22 | Lair as its own place kind (separate from delves) | easy-now | **feasible-needs-care** (1/2 skeptics refuted) | Lair is obviously cheap. It is one no-argument C_DelvesUI.IsInLair() call (namespaces.md:1608) with no secrecy flags, it is O(1), and it allocates nothing beyond one boolean and a 1-character signature part. No new event is needed: the zone events and PLAYER_E… |
| M14 | Instance row does not count your garrison | easy-now | **easy-now** (0/2 skeptics refuted) | On performance this is obviously cheap: - No new event: the re-check events (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA) are already in CTX_EVENTS. - No new API read: instanceID, IsInInstance and its type are already read, with no secrecy flags (globals.md:1… |
| M11 | Zone / sub-zone by name | feasible-needs-care | **feasible-needs-care** | The raw cost is tiny: two unflagged, non-secret O(1) string reads, no new events (all three zone events are already in CTX_EVENTS, Engine.lua:1411), low and discrete event frequency even in raid or M+ (INFERENCE), and an O(1) per-rule set match. It is still no… |
| M8 | Has a target / has an attackable target (and the reverse) | feasible-needs-care | **feasible-needs-care** | The reads are O(1), allocation-free, and have no return-secrecy flags in the reference (globals.md:565, :588). The main event is already registered and already re-checks live rules (Engine.lua:1427, 1604-1617). With a usage gate, the condition costs nothing wh… |
| M17 | Group member count (at least / fewer than N) | feasible-needs-care | **feasible-needs-care** | Close to easy-now, but not obviously cheap under the current engine. Its event is already registered and already runs ReadContext, the read is one O(1) call, and there is no per-frame work. It falls short of the bar in two places. First, the count read (GetNum… |
| M18 | Pet out / no pet (load condition, yes / no / ignore) | easy-now | **feasible-needs-care** (1/2 skeptics refuted) | M18 is obviously cheap. - The read is a single O(1) UnitExists("pet"), not secret (globals.md:588), and already proven in this codebase (Triggers.lua:894). - The single event, UNIT_PET (events.md:1616, no secret payload), is unit-filtered to "player". It is th… |
| M20 | At max level / still levelling (own level) | easy-now | **easy-now** (0/2 skeptics refuted) | This is obviously cheap. It is an O(1) read of two unflagged C APIs (UnitLevel globals.md:667, GetMaxLevelForPlayerExpansion globals.md:202) with no secret returns or payloads. The one needed event, PLAYER_LEVEL_CHANGED / PLAYER_LEVEL_UP (events.md:1192-1193),… |
| M21 | In a PvP setting (War Mode on, battleground; arena is our ad | easy-now | **feasible-needs-care** (1/2 skeptics refuted) | M21 meets every easy-now criterion: - Battleground and arena are already read and already in the signature (instanceType, Conditions.lua ~1861/1879), so that part costs nothing new. - War Mode is one O(1) C call with no secrecy or restriction flags (C_PvP.IsWa… |

**Survived as easy-now (both skeptics failed to refute):**
- **M2, in a vehicle.** One O(1) read, already used by the vehicle trigger, plus two player-only events.
  - Caveat: vehicles do happen in raid encounters. Without the usage gate (A), entering one would start a full step for everyone, so it still needs (A) and (B) to cost nothing when unused.
- **M14, Instance does not count your garrison.** No new event, read or signature part.
  - Caveats: whether the game reports a garrison as an instance at all is INFERENCE, so it needs an in-game check first.
  - **Reference-addon rule:** the candidate garrison instance IDs in the evaluation came from an EUI file. We may not copy that list. Our own list must come from the game itself, for example by reading the instance ID in game while standing in a garrison, or from documented API data.
- **M20, at max level / still levelling.** O(1) reads of two unflagged APIs and one player-only event. Only the yes/no answer goes into the signature, never the level, so levelling below the cap causes no churn.

**Downgraded to feasible-needs-care:**
- **M1, M3, M6, M18, M21:** every skeptic agreed the raw cost is tiny. Their "easy" rating rested on the usage gate (A) to (C), which does not exist yet, and on unverified timing of the game's events.
- **M22:** the claim that it adds no full step on its own is unlabelled INFERENCE.
- **M4, M5, M7, M8, M11, M17:** rated needs-care by their evaluators. The reasons are in the table.
  - M8 needs its own path, because a target change never reaches the load context today.
  - M17 depends on GetNumGroupMembers, which is not in our API reference.
  - M11 needs language-dependent name storage.

## 3. Engine costs found on the way (existing Rules code; not this session's to fix)

Reported to the Rules session, since they bear on V33 and V27:
1. The CheckContext memo key includes `math.floor(GetTime())`. So each live rule re-runs CheckContextRaw once a second in combat, allocating 1 + k tables each time.
2. When the context really changes on the immediate path, ReadContext runs two or three times. The handler's read is discarded: Engine.lua:1599, then Settle at :1206 and Step at :945.
3. `equipGen` starts full steps on every gear change even when no rule has an equipped-item list.
4. PLAYER_SPECIALIZATION_CHANGED is registered globally. Other units' spec changes also re-read the context; only the epoch bump filters on "player".
5. ns.LoadEvent calls MarkStateDirty, which re-checks every live rule, and a full step follows anyway.

## 4. Proposed next step (for her decision)

- **Build now:** M2, M14 (once our own garrison IDs are confirmed in game) and M20, on top of the usage gate (A) and (B). Building them without the gate would add reads, signature churn and events for every player.
- **Later:** with the gate in place, M1, M3, M6, M18, M21 and M22 become close to free. Build them later, as she decides.
- **Hold:** M4, M5, M7, M8, M11 and M17, until their open questions are answered in game.
- **Who builds:** all of this is Rules engine code (Conditions.lua / Engine.lua). It is built after bundle 1 lands, coordinated with the Rules session.
