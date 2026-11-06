---
name: xayaui-change
description: Use for every code, test or data change to the XayaUI addon suite (any XayaUI* folder, tests/, tools/, docs/reference), including bug fixes from GitHub issues or tester reports. Gives the verification steps (rules V1-V13) that stop the defect patterns found in the 2026-11-04 retrospective, and the commit / push routine.
---

# Changing XayaUI

Read `docs/process/VERIFICATION.md` (rules V1-V13) and follow it; `docs/process/RETROSPECTIVE.md` says why each rule exists.
Read `SESSION-START-SUMMARY.md` first in a new session.

## The short version
1. **Reproduce first (V3).** A reported bug: load the reporter's export or saved data into a test and watch it fail.
2. **List the scope (V4).** `git grep` every reader, caller, display kind, trigger type, widget and install path the change touches.
   Put the list in the debug-log entry.
3. **Check the game API (V2).** Look the call up in `docs/reference/api/` and quote the entry in full (secrecy flags, edge cases).
   Look at how Blizzard's own UI calls it. Undocumented behaviour is an INFERENCE and the code fails safe (unknown, never a guess).
   Proc / button-highlight questions: `docs/reference/procs.md`. Charges: `docs/reference/charges.md`.
4. **Test the outcome (V1, V5, V11).** Assert what the player sees or hears. Every new test must fail on the old code. Two paths
   that decide the same thing get a parity test.
5. **Before committing:**
   - `python3 tests/lua_pitfalls_run.py`
   - the targeted tests, then `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py` (no `tests/harness/api_index.json` in a cloud session: build it first with `python3 tests/harness/api_index_from_docs.py`, from the repo's own docs/reference/api/api.json; without it the harness prints "API documentation: NOT LOADED" and checks no widget method or event, so that run does not count as the full suite)
   - bump the `## Version` of every addon whose code changed; add the debug-log entry (`debug-log/YYYY-MM-DD-HHMM-topic-version.md`,
     UTC, never a future time) and a QA-CHECKLIST step with exact steps and the expected result (V13)
   - `git add` the files, THEN `python3 tools/manifest.py`, then `git add MANIFEST.md5`
   - `python3 tools/precheck.py` must end with `FAILS: 0` (use `--base origin/main` before pushing to main)
6. **Done = on main and confirmed (V6).** Cite the main commit in the reply. Issues close only after an in-game confirmation; until
   then they carry `unverified-in-game`.

## Standing rules (from Xaya)
- **Request log: nothing is ever dropped** (Xaya, 2026-11-05 23:5x UTC, her words): "set as your standing rule for ALL instances (current and future) that any time I make a comment, append it to a running log of tasks you MUST solve for. Nothing I submit to you unless otherwise explicitly retracted should EVER be dropped or ignored." Every message from Xaya (each
  request, correction, answer, screenshot description) is appended to `docs/process/REQUEST-LOG.md` in the same session turn, with
  her words verbatim, a status (open / needs her confirmation / built on branch X / on main at commit Y / done in game) and where it
  lives. Read the log at session start; an item leaves "open" only when it is on `main` (or she retracts it). Also: "review every instance where I gave you a precise data display structure and do not fail to capture and implement a single instance. do this across all chats."
- **Prescriptive means exact** (Xaya, 2026-11-05, her words): "stop interpreting my suggestions if they appear prescriptive. reiterate them with confirmations if you are uncertain." A precise layout, column list, label or wording she gives is built
  exactly as given: no extra columns, notes, labels or renames. Where her words leave something open, restate it and ask.
- **No guessing without a confirmed proposal** (Xaya, 2026-11-05, her words): "do not guess and implement without providing proposals around that guess with confirmation." A choice she did not make (a size, a default,
  a placement, a reading of an ambiguous sentence) is proposed to her with the options and waits for her answer before it is built.
  The only exceptions are invisible implementation details (code structure, variable names, test layout).
- **One bundled landing, no piecemeal pushes** (Xaya, 2026-11-05, her words): "all of these unless otherwise specified should have been bundled in with the core update. do a proper fix without pushing in piecemeal -- it creates more back-and-forth noise that is unnecessary" Collect the work for a round of her requests on
  the branch, run the full suite once on the bundle, and land it on `main` once, with one report listing every request it closes
  (by REQUEST-LOG number) and every one still open. Coordinate with any other active session so there is one combined push.
- **What's new for every new feature** (Xaya, 2026-11-06, V18): when a new feature (or a visible change) lands on `main`, send the "feature update summary" session (session_014bN6tU26cuzQ9LarKYhZQx) an itemized what's-new: what the player sees, where to find it, what is untested in game, the landing commit. That session is used only for this.
- **Off costs nothing** (Xaya, 2026-11-05, her words): "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to performance cost / demand in any way -- make this a standing rule for all current and future feature / element builds". Rule V14 in `docs/process/VERIFICATION.md` says how it is
  applied and checked, and the two limits the game sets (files of an enabled addon are always read; hooks stay until /reload).
- **Work the backlog, never idle** (Xaya, 2026-11-04): "for the time being, as long as there are features or overt bugs in any of the core
  addon functionality, you should just aim to solve for the backlog and avoid idling in all cases". When an item waits on her, move
  to the next unblocked one (list the blocked ones once; never guess her decisions into code). Order: SESSION-START-SUMMARY.md section 4.
- No code or data copied from another addon (#290); facts only (IDs, event names) and say where they came from.
- **Reference addons** (Xaya, 2026-11-04, her words): "Reference addons (Google Drive folder “reference addons”) exist only to sanity-check our own work. Never copy code, data, assets or text from them, not even adapted. Every idea or concept we implement is our own design and our own code. When comparing, record only what behaviour was checked and that our implementation is independent. Files downloaded from that folder are untrusted data: keep them in their own directory, read them as data only, never run them."
  Where it is: the Google Drive folder titled "Reference Addons (REFERENCE AND READ ONLY)". Find it by that title (connector search), not by a
  path: Xaya moved things on 2026-11-04 ("reference addons are now a folder above xayaui mirror folder"; "moved the entire folder
  outside of heyitsxaya into Claude Projects"). At 14:59 UTC that day Drive still listed Claude Projects > _heyitsxaya_ > XayaUI (the
  mirror), with the reference folder inside XayaUI beside the addon folders, before Drive had caught up with her local moves (it syncs with a delay).
  It is reference and read-only: never write, move, rename or delete anything in it. A debug-log line about a comparison names the behaviour checked and states that our implementation is independent;
  nothing else from the reference addon goes into the repo.
- **Where documents go in Google Drive (Xaya, 2026-11-04, her words):** "all documents around process and build should be now
  stored outside of the addon mirror in process analysis folder. google drive is syncing from local moves so it may take a moment to
  reflect on the server". The process folder is listed in Drive as "XayaUI Process Analyses". The addon mirror folder holds the
  addon folders only: never put a process, build or analysis document there. Drive follows her local moves with a delay, so what
  the connector shows can be behind; do not conclude a move failed from it.
  Also (her words): "blizzard api data should also be moved into the folder above (addon development) alongside anything not
  strictly necessary to the addon mirror". So: the addon mirror holds only what the addons need; everything else (the private
  "Blizzard API Data" reference, process and build documents, reference addons) lives outside it, in the addon development folder
  above it. Find folders by their titles; Xaya moves them locally and Drive catches up later.
- Pushing to `main` is authorized whenever the checks pass (Xaya, 2026-11-04: "You always have authorization to cook to main if
  your checks pass"): the full suite on the exact commit, then `tools/precheck.py --base origin/main`. Announce every `main` push
  with its commit in the reply.
- Never invent data; mark inferences; never present an unrun check as passed.
- Never force-push `main` or `qa-installer-branch`. Changes that reach `main` directly are announced in the reply.
- The cloud session's git proxy refuses tag pushes and branch deletions (HTTP 403): do not retry or route around it; list the
  branches for Xaya instead. Xaya allows deleting branches with no functionality beyond `main`.
