# Handoff: XayaUI Rule Builder walkthrough
- **Session:** session_014bN6tSvaDBEe8dCKeMYcgo
- **Project:** heyitsxaya/XayaUI
- **Branch:** `claude/rule-builder` (cut from bundle 1 branch `claude/dazzling-brown-x9fqrm`). The SHA is the commit that adds this file; it is reported to the hub in the reply. Pushed: yes.
- **Open PRs:** draft PR #525 (base: the bundle 1 branch).
- **Released / live:** nothing. Design only; no addon code written.

## 1. Purpose and scope
The Rules session opened this session for Xaya (REQUEST-LOG A23 SD-59). Its request, verbatim: "create a new chat window to facilitate the build of a "Rule Builder" user walkthrough that takes dropdown menu and multi-select inputs to help a user create rules without navigating the complex pane views".

Hard rules for the work:
- The builder must save through the editor's own path: NewRule → NormalizeRule → DraftNew. No second rule format.
- Design only until the Rules session reports that bundle 1 is on main. Then rebase onto main and build.
- Never push to main or qa-installer-branch.
- Reference addons are a sanity check only. No copying of code, data or text.

## 2. Current state
- **Done:** stage-1 design doc, plus a large mockup canvas (17 boards), refined through about 105 of Xaya's canvas comments, logged as RB-1 to RB-106.
- **Also done:**
  - Load-conditions study (M1-M23).
  - Load-conditions performance plan: usage gate first, then M2 and M20 (RB-28).
- **Verified in game:** nothing. The cloud session has no game client.
- **Code facts used in the design (read from the repo, not tested in game):**
  - Outcomes.lua lets a rule own extra outcome rules. Each one has its own AND / OR / NOT combination of the parent's triggers. Combinations and cue conditions map onto this.
  - Cue kinds: Cues.lua `ns.CUE_KINDS`.
  - Glow: Actions.lua.
  - Today's aura reads: HELPFUL auras on the player, and the player's own HARMFUL auras on target or focus (Triggers.lua:746-812).

**Flow drawn on the canvas (top row):**

0 Where it opens → Introduction → 1 Tracking → 2 Show this rule when (ANY / ALL / combination) → 2a Combination of trackers (only when picked) → Create a Cue (visual and audio buckets) → Cue Conditions (when each alert plays) → 3 When it loads → 4 Name and group → 5 Done

- **Under the main row:** the A-F tracking sub-flow, and 3b (one load set opened).
- **Left pane on every builder board:** a "Rule Building Steps" list (RB-105, RB-106).

## 3. Xaya's decisions
All decisions are dated 2026-11-12 or 2026-11-13 unless marked otherwise. They are recorded verbatim in `docs/process/REQUEST-LOG.md` section A25 and folded into `docs/plans/RULE-BUILDER-DESIGN.md` §3. Key recent ones:

- **RB-80 (load):** "instead of "change set," auto-populate "Load Conditions" with the default the user must pick: "always, never, combination" and build from there"
- **RB-100 (load):** "always shouldn't have a modifier". The ALL / ANY choice only applies under Combination.
- **RB-101 and RB-102 (tracker logic):**
  - RB-101: "Show this rule when: * any of the trackers register as "TRUE" * all of the trackers register as "TRUE" * when the following combination of trackers are true (conditional logic)"
  - RB-102, placed on the triggers step: "no, you're correct, it belongs on conditions and not load"
- **RB-90 to RB-97 (cues):**
  - Cue options go "between current windows 2 and 3".
  - Bucketed into "visual cue" and "audio cue".
  - Heading: "Create a Cue / An alert you set up when one of your Tracking events is detected".
  - Question: "What alerts do you want to have set up for this rule? (Choosing how they will appear happens in the next page)".
  - "Cue Conditions >> this goes to next page".
- **RB-95 (wording):** "happens is the wrong verbiage". Tracked things are "detected" or "NOT detected".
- **RB-84, RB-98, RB-99 (load summary wording):** two sentences: "It will load ONLY when you are: …, and NOT …" and "It will NOT load when you are NOT: …, or when you are …".
- **RB-28:** "Usage switch + 3 cheap ones (Recommended)"
- **RB-29:** "drop garrison, remind me to check next time I load the addon"
- **SD-77, 2026-11-15** (relayed by the Rules session): bundle 1 includes a narrowed re-check. RB-28 must rebase on it.
- **SD-132, 2026-11-17:** new standing rules. Summarised in RULE-BUILDER-SESSION-START.md.

## 4. Open questions for Xaya
These are asked in canvas threads and still unanswered. Each line gives the question, then my recommendation.

1. **Step numbering.** The flow now has 7 main steps plus 2a. Renumber "Step N of 5" to 1-7? Cue boards show "step number pending".
   - Recommend: yes, renumber.
2. **Scope.** Stage 1 was triggers only (design §1). Are cues part of stage 1, or a stage 2?
   - Recommend: stage 2, so stage 1 ships smaller and safer.
3. **Cue appearance page.** Add a placeholder "Cue appearance" board after Cue Conditions, per RB-96's "next page"?
   - Recommend: yes.
4. **Chat messages.** Should print, red error text, and say / yell / group messages be a third cue bucket, or stay editor-only?
   - Recommend: editor-only for now.
5. **Combination logic (2a and Cue Conditions).**
   - Allow OR inside one combination, or keep AND-only? Recommend: AND-only in the builder.
   - Keep the NONE option (my inference from "no combination")?
6. **"TRUE" wording.** Keep "TRUE" in capitals and quotes on board 2, even though earlier boards avoid "true" wording?
7. **Done board.** Should it show the step list too, instead of the rule list with the new rule selected?
8. **Load summary alternative.** Use a two-column "LOADS WHEN YOU ARE" / "WON'T LOAD WHEN YOU ARE" layout if the two sentences still read clunky?
9. **Instance set (3b).** Keep two control kinds (tri-state boxes plus type ticks), or one tick list?
10. **Older asks still open.** All are in REQUEST-LOG A25; see those rows for the exact wording.
    - RB-37: true item "on cooldown" state.
    - RB-51 and RB-52: wording of the item preview and the type label.
    - RB-60: Remove versus Cancel tracking.
    - RB-62: meaning of "any".
    - RB-66: Always Show versus group settings.
    - RB-67: load wording in the editor.
    - RB-68: tick boxes on board 2.
    - RB-73: Load tab grouping in the editor.
11. **Reminder RB-29.** Next time you load the addon, stand in your garrison and report whether it counts as an instance, and its instance ID.

No question is pending in the question tool (AskUserQuestion). All of the above live in canvas threads.

## 5. In-flight work and next steps
Nothing is in flight. All work is committed and pushed.

**Next:**
1. Get answers to §4.
2. When the Rules session says bundle 1 is on main:
   - rebase `claude/rule-builder` onto main;
   - run the model and effort check (SD-132; this session runs at medium effort, so high or above is recommended for the build);
   - build RB-28 on bundle 1's engine;
   - build the stage-1 builder against the canvas.
3. **Build-time checks:**
   - Can Outcomes be created through NewRule, NormalizeRule and DraftNew?
   - Can the settings window swap its tree pane for the steps list?
   - Midnight in-combat readability of debuffs on the player and buffs on the target.
   - Who applied a buff (the "Buff source" option).

## 6. Dependencies on other sessions
- **Rules or main session (session_014bN6tVBGo8BHkHu65TAcjD)** must report "bundle 1 on main" before any build. Round 10 is running and round 11 comes before landing.
- **RB-28** rebases on bundle 1's SD-77 engine. Do not build the narrowing separately.

## 7. Key files, docs, artifacts, links
**Design and tracking docs:**
- `docs/plans/RULE-BUILDER-DESIGN.md` (stage-1 design; §3 holds all the RB notes)
- `docs/plans/RULE-BUILDER-TRACKER.md` (full tracker)
- `docs/plans/RULE-BUILDER-SESSION-START.md` (cold-start summary, standing rules)
- `docs/plans/LOAD-CONDITIONS-STUDY.md`
- `docs/plans/LOAD-CONDITIONS-PERF.md`
- `docs/process/REQUEST-LOG.md` §A25 (RB-1 to RB-106, all verbatim)

**Mockup canvas (private to Xaya):**
- Artifact: https://claude.ai/artifact/6jJdZbPfW67t1Xpj9eP426
- Comment URL form: https://claude.ai/code/artifact/2e65cbf7-9707-46b2-8f13-723af552556b
- Board files:
  - main flow: `Main`, `Step1`, `Step3`, `Step4`, `Step4a`, `StepCues`, `StepCueCond`, `Step2`, `Step2b`, `Step5`, `Step6`
  - tracking sub-flow: `CheckFlowA`, `CheckFlowB`, `CheckFlowC`, `CheckFlowD`, `CheckFlowD2`, `CheckFlowE`, `CheckFlowF`
  - layout: `canvas.json`

**Code to reuse (read only so far):**
- Triggers.lua: CombineTriggers, trigMode
- Outcomes.lua
- Cues.lua
- Actions.lua
- Editor/RulesTree.lua: display-type picker, about line 1198
- Editor/TriggersEditor.lua:325
- Editor.lua: AddSquareRadio at 731, Load tab at about 1094

## 8. Gotchas
- **Re-read before republishing.** The canvas is a Design-type artifact. Read the published file and compare it with your copy before republishing files you haven't read this session. Publish refuses unread files.
- **Ambiguous comment anchors.** Comments anchored inside `sc-for` templates don't say which row they point at. Ask, or state your inference.
- **Check layout after edits.**
  - After structural edits, check that the div tags still balance.
  - Check that the board height still fits 860 px. Render it with playwright (replace `{{accent}}` and drop `support.js`).
- **Log every comment.** Xaya's canvas comments must be logged verbatim (V15). Wording changes must keep her exact words (V16).
- **Load vs trigger setting.** Board 3 (load.mode) and board 2 (trigMode / Outcomes) are separate settings. Xaya confirmed this (RB-102).

## 9. Environment needs (names only)
- GitHub access to heyitsxaya/XayaUI
- Artifact tools: Artifact, ArtifactComments
- claude-code-remote `send_message` (to talk to the Rules session)
- No secrets needed

## 10. Suggested successor
A Rule Builder session cut from main after bundle 1 lands. Before it starts building, it should:
- load RULE-BUILDER-SESSION-START.md, RULE-BUILDER-TRACKER.md, RULE-BUILDER-DESIGN.md and REQUEST-LOG §A25;
- re-attach the canvas;
- run at high effort or above.

## 11. Archive readiness
Ready. All work is pushed. The canvas lives on as Xaya's artifact, and its comment threads keep the open questions.
