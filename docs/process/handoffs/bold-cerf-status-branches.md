# Handoff: Daily status check and branch cleanup list (2026-11-08)

- Session: session_014bN6tWYS45jH9wSdj2RSxM · Project: heyitsxaya/XayaUI · Branch: `claude/bold-cerf-17je6r`, based on main `fda1e29`, this docs-only commit on top (pushed: yes) · Open PRs: none from this session · Released/live: nothing; this session never changed code.
- Written 2026-11-17 at the hub's request (session_014bN6tUNTxxZDiYNEg9dw75, the "HUB MERGE" message).

## 1. Purpose and scope
A short, read-only Q&A session on 2026-11-08. Xaya asked:
1. "Hi Claude! What's outstanding for today?"
2. "can you send me a full list of branches that have all of their code either updated on main or directly on main? how many branches do I need to clean up?"
3. Mid-turn she sent "rule group display reference" with 5 screenshots (section 4, Q1).

The session never changed or pushed code. Before this handoff it had pushed nothing.

## 2. Current state

| Item | State | Verified? |
|---|---|---|
| "Outstanding today" answer (11-08) | Given in chat. Everything unblocked was on main `3eb0c4b`. Waiting on Xaya: in-game test (Open Questions doc section 5); Open Questions rows A1-A8, A10-A19, B4, B5, C20-C29, D3; P6; PN-1; D8 held (PR #446). Source: `docs/process/handoffs/platform-split-lead.md` (10:00 UTC update). | Correct for 11-08 10:06 UTC. **Not re-checked since. Likely out of date.** |
| Branch audit (11-08) | `docs/process/BRANCHES-2026-11-08.md` (copied from the scratchpad into this commit). 77 branches besides main: 62 with all code on main (groups A-D), 7 replaced by a branch that is not on main (E), 8 to keep (F). One delete command per branch, each refusing a branch whose head moved. | Checked against main `3eb0c4b` on 11-08. **Out of date now:** the remote has 31 branches (was 78), main is 84 commits ahead, and main no longer contains `XayaUI_Chat`, `XayaUI_QoL`, `XayaUI_Reskin`, `XayaUI_DevAssist`, `XayaUI_Nameplates`, `XayaUI_Media`, `XayaUI_Rules_Options`, `tools/`, `debug-log/`, `.claude/`, `.github/`, `roadmap-features/`, `shelved/`. Inference: a deliberate restructure on main between 11-08 and 11-12. I did not look into why. |
| 2026-11-17 standing rules | Received from session_014bN6tVBGo8BHkHu65TAcjD as a relayed message. Being followed here. | **Not confirmed by Xaya directly** (Q3). |

## 3. Xaya's decisions
None in this session. Her three messages are quoted in section 1; none of them decided anything.

## 4. Open questions for Xaya (none answered yet)
- **Q1. Rule group display reference.** Her words: "rule group display reference". The 5 screenshots exist **only in this chat's transcript**; I saved no image. What they show, as I described it to her: a search box with a clear button; "Loaded" / "Not Loaded" section headers that collapse; a group row that expands into indented children with up/down reorder arrows; nested groups (a group inside a group); a highlighted selected row; a right-click menu with Rename, Copy settings, Convert to, Duplicate, Export. Inference: this is the WeakAuras options list (I judged that from how it looks; she didn't name it). Her rule #290 means we use it for layout and behaviour only, never code or art.
  Options: (a) a new GitHub issue (type/area/impact labels) that describes the screenshots in words; (b) add it to [heyitsxaya/xayaui#372](https://github.com/heyitsxaya/xayaui/issues/372) and/or [heyitsxaya/xayaui#341](https://github.com/heyitsxaya/xayaui/issues/341) (group page issues); (c) a design pass with wireframes. **Recommendation: (a) linked to #372/#341, and under the 11-17 "CODE: XUI" rule offer her wireframes before any build.** Ask her to re-attach the screenshots to the issue herself, since I couldn't save them.
- **Q2.** "Refresh `docs/SESSION-START-SUMMARY.md`?" It was last updated 2026-11-05, and her multi-session rule requires a current cold-start summary. Recommendation: yes. The hub or lead session should do it after the merge.
- **Q3.** "Did you send the 2026-11-17 rules relayed by session_014bN6tVBGo8BHkHu65TAcjD?" Recommendation: ask her once, at the merge, for all sessions at the same time.
- **Q4.** "Rerun the branch audit before you delete anything?" Recommendation: yes. The 11-08 list predates the restructure (section 2).
- **Q5.** "Main's history restarts at `2d075a5` (P1, 2026-11-07 18:37 UTC), which has no parent commit. Was that intended?" Until she answers, keep `qa-installer-branch` and `archive/*`: on 11-08 they were the only branches holding main's history before P1. Not re-checked on current main.

## 5. In-flight work and next steps
- Nothing in flight.
- Next (successor): rerun the branch audit against current main (method in section "How this was checked" of `BRANCHES-2026-11-08.md`, which tolerates the missing shared history), then file Q1 per Xaya's answer.

## 6. Dependencies on other sessions
- The lander (the only session allowed to push main, per `docs/process/handoffs/lander.md`). This handoff is on this session's own branch, not main. If it should be on main, send it to the lander as docs only.
- The hub (session_014bN6tUNTxxZDiYNEg9dw75) receives this handoff.

## 7. Key files, docs, artifacts, links
- `docs/process/BRANCHES-2026-11-08.md`: the 11-08 branch audit (out of date, see section 2).
- `docs/process/BRANCHES-2026-11-07.md`: the earlier list it built on.
- `docs/process/handoffs/platform-split-lead.md`: the source of the "outstanding" answer.
- XayaUI Open Questions doc: https://claude.ai/artifact/2ALU9A6Z3TpFeexwuBuKUj (not opened by this session).
- The scripts that classified the branches were scratch files and are lost when this session is archived. The method is written out in `BRANCHES-2026-11-08.md`.

## 8. Gotchas
- **Main has no shared history with any branch created before P1.** `git merge-base` fails for those branches, so plain "is it merged" checks call almost everything unmerged. Compare against a branch that keeps the full history (on 11-08, `qa-installer-branch`, whose files equalled main's), and check content line by line.
- `MANIFEST.md5` lists every tracked file except itself, sorted, as md5sums. `tools/manifest.py` is gone from main, so rebuild it with `git ls-files | grep -vx MANIFEST.md5 | sort | xargs md5sum` after `git add`.
- The rule-group screenshots are not in any file (Q1).

## 9. Environment needs (names only)
- GitHub access to `heyitsxaya/xayaui` (MCP tools plus `gh api` search). No secrets needed.

## 10. Suggested successor
- Q1 (rule group display): the session that owns the Rules / group-page UI on current main.
- Q4 and Q5 (branches and main's history): a branch-cleanup or lander session.
- Q2 and Q3: the hub.

## 11. Archive readiness
Ready once this commit is on `origin/claude/bold-cerf-17je6r`. Nothing else lives only in this session: the branch list is committed here, and Xaya's messages and screenshot descriptions are written out above.
