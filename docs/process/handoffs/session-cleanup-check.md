# Handoff: Session cleanup check (process redesign + platform split origin)
- Session: session_014bN6tWwZM5hKvbZkMFd4zN · Project: heyitsxaya/XayaUI · Branch: `claude/lucid-mayer-pv4ytn` (restarted from main fda1e293 for this file; all earlier work merged) · Open PRs: none from this session (PR #459 and #473 merged) · Released/live: everything this session produced is on main (last code commit c00811e, Dev Assist 0.7.53)

## 1. Purpose and scope
Started 2026-11-07 as a morning status check. Became the session that redesigned the process and started the platform split:
- a process-rules draft
- a per-module context plan
- the platform split design
- Phase P0.5 (trustworthy walkthroughs)

On 2026-11-07 ~18:15 UTC it handed the split to "XayaUI: platform split lead" (session_014bN6tX5sAfcgMXdDw6XsNU). **This session's knowledge ends there.** Later progress (P1-P5 per main's history) is recorded by the lead in `docs/process/handoffs/platform-split-lead.md` and `docs/plans/PLATFORM-SPLIT-2026-11-07.md`. Those two files are authoritative, not this one.

## 2. Current state: done / verified / not verified
**Done and on main:**
- `docs/plans/PLATFORM-SPLIT-2026-11-07.md`: design, Xaya's decisions PS-1..PS-49, execution order (section 15).
- Standing rule "UI overhaul switches apply on reload", added to `.claude/skills/xayaui-change/SKILL.md`.
- REQUEST-LOG section A18, rows PS-1..PS-49.
- Dev Assist 0.7.52: sortable walkthrough table, search and tags.
- Dev Assist 0.7.53: walkthrough checks that can't pass without testing, reload-based reskin and chat walkthroughs, Done-page navigation.

**Verified:**
- Full suite, Lua pitfall check and precheck passed on each landed commit (the lander's gate).

**Not verified:**
- Nothing from this session was tested in game except the baseline walkthrough runs Xaya did on 2026-11-07 (results below).
- I have not checked the state of main after 2026-11-07.

**Baseline, 2026-11-07, main f3fbc4b:**

| Walkthrough | Result | Issues |
|---|---|---|
| bars-cues | 4 pass, 4 fail, 1 skip | #461, #462 |
| perf-settings-click (J31) | 2 pass, 2 fail (rule-editor click 136-221 ms) | #467, #482, #483 |
| reskin-switches | 1 pass, 3 fail | #480 |
| chat-improved-split | 2 pass, 1 fail | #480 |
| settings-toplevel | 6 pass, 2 fail | #484 |
| audit-opt-bin | 0 pass, 4 fail | #485, #487 |
| audit-engine | deferred | |

## 3. Xaya's decisions (dated; verbatim; where recorded)
All in REQUEST-LOG A18 (PS-1..PS-49) and PLATFORM-SPLIT section 2 / section 9. Key ones, all 2026-11-07:
- "We don't have to use the name "core" for the platform functionality ... create "platform" as the foundational layer upon which everything — including "core" runs." (PS-1)
- "I imagine we want individual modules to hold their own settings, correct?" (PS-7)
- "Does sharer / import / export have "universal plumbing" configured for each model to tie into? If not, it should" (PS-6)
- "this shouldn't work without a reload, anyway" / "none of these should be toggleable without a reload -- this is the standing convention for all UI overhaul addons" (PS-43, standing rule)
- "please compile all your questions and keep them stashed in a doc" (PS-40)
- "Go ahead with sorting out how you want to refactor / reorganize the codebase -- it's going to need extensive debugging either way" (PS-49, split approved)
- Freeze approved; theme override "Both"; theme controls "Both" (PS-13, PS-34).

## 4. Open questions for Xaya (verbatim; options; recommendation)
As of 2026-11-07, kept in the Claude Doc "XayaUI Open Questions" (https://claude.ai/artifact/2ALU9A6Z3TpFeexwuBuKUj), rows A1-A11, B1-B7, C1-C12 and D1-D4. Some may since have been answered or made moot by the lead session (INFERENCE: P4 landed on main, so B2 / B3 were probably settled). Check the doc before asking. The ones most likely still open:
- A1 "Tooltip color for **Chaos** damage" (bright white / neon pink / neon green). Rec: bright white. (#462)
- A2 "Tooltip color for **Physical**" (silver grey / tan / keep Blizzard yellow). Rec: silver grey. (#462)
- A4 New Buttons hover text "On: the red buttons in Blizzard's windows take XayaUI's flat look. Off: they stay Blizzard's red." (approve / change). Rec: approve. (#468)
- A10 "Your reload rule ...: which switches does it cover?" (UI overhauls only / also small QoL features). Rec: UI overhauls only. (#480)
- A11 "Importing a profile: should each ticked part ... end up exactly like the profile, defaults included?" (match exactly / keep merging). Rec: match exactly. (#484)
- C1-C12: palette, chat borders, window opacity, conflict addons, friend groups, RSK-Q15, text files ("like an app"). See the doc.
- D1, D3, D4: notes I couldn't read (B22 / B24 screenshots, the group-border error text from `/xui report`).

## 5. In-flight work and next steps
None in this session. Next steps are the lead's (split phases, then debugging #460-#487 by area).

## 6. Dependencies on other sessions
- Platform split lead: session_014bN6tX5sAfcgMXdDw6XsNU (owns the split).
- Lander: session_014bN6tTqpzJRGoByn311ErR (only session that pushes main).
- Feature update summary: session_014bN6tU26cuzQ9LarKYhZQx (Patch Notes, V18).

## 7. Key files, docs, artifacts, links
- `docs/plans/PLATFORM-SPLIT-2026-11-07.md`, `docs/process/handoffs/platform-split-lead.md`, `.claude/skills/xayaui-change/SKILL.md`, `docs/process/REQUEST-LOG.md` (section A18).
- Claude Docs: "XayaUI Open Questions" (link above); "XayaUI Standing Process Rules (draft)" (https://claude.ai/artifact/VoLP6CKip53vAvxt1NP5yt): 12 proposed process rules, not approved.
- GitHub issues #460-#487 (all filed from her 2026-11-07 testing).

## 8. Gotchas
- About a third of the 2026-11-07 baseline failures were walkthrough defects, not product bugs. Walkthrough "Pass" results before Dev Assist 0.7.53 are not trustworthy.
- Xaya tests only on main. Her friends' QA was asked to hold during the split.
- She wants one push notification when something needs her, with details in the Open Questions doc, not in chat.

## 9. Environment needs (NAMES only)
None beyond the repo. The full suite needs `tests/harness/api_index.json`, built by `tests/harness/api_index_from_docs.py`.

## 10. Suggested successor
The platform split lead (session_014bN6tX5sAfcgMXdDw6XsNU), or whichever session the hub assigns to XayaUI development.

## 11. Archive readiness
Ready. Nothing uncommitted. All work is on main. This file is the only new content.
