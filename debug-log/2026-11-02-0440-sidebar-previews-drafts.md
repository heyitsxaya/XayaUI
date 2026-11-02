# 2026-11-02 04:40 ET — sidebar previews, Drafts discard bar, eye scroll reset

Local build 0.5.27 (the GitHub toc reads 0.5.20, so the repo is behind the local folder). Fork instance: n/a.

Reported by Xaya, in order:
1. Sidebar preview (eye) icons activate previews in the wrong places, and preview disabled rules.
2. Clicking the HUD group eye lit more than what is nested in HUD and did not preview every element.
3. UI flashes when switching between groups. NOT FIXED: cause not found. Next step: `/xui perf` trace after clicking between two groups.
4. Drafts: a modified rule is not collected into Drafts automatically. Unclear which trigger is meant (closing the window vs. switching rules); no bug found in the close-window path.
5. Discard changes: the Unsaved changes bar stays on other tabs until the window is closed.
6. Clicking an eye moves the sidebar scrollbar to the top.

Changes (commit ea9f058, untested in game):
- Options.lua: group previews skip disabled and out-of-scope rules and take cues from their parent rule (a cue's own folder field can be stale). The eye click no longer rebuilds the window unless the open rule is affected, and the scroll position is restored then.
- Drafts.lua: Discard re-records the baseline from the reverted rule and redraws a second time on the next frame.

Not done: items 3 and 4. A GitHub issue was not created (the issue call was blocked), so this file is the log.
