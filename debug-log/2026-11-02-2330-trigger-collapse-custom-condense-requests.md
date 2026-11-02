# 2026-11-02 23:30 UTC: trigger collapse, custom triggers, condensed option rows (requests logged, not built)

- Build: XayaUI 0.5.52 on main. Session 014bN6tVJMhXhJr5SQhrk92Q. GitHub issues: #257 (collapsible triggers), #258 (custom triggers; phase 1 of #225), #259 (condense option panes).
- Findings: per-trigger collapse already exists with the skin on (session-only); custom Lua precedent is Actions.lua (loadstring, pcall, stripped on import); no shared 'checkbox + inline dropdown' option builder exists yet.
- Also found: device sync re-encodes PNGs (identical pixels, different bytes), so Media/UI/Notepad/*.png were removed from MANIFEST.md5.
- Asked Xaya for scope before building. Nothing from these three requests is implemented.
- 23:40 UTC bug report (Xaya): "condition modifications do not apply". Issue #260. Not reproduced; code path read, no defect found yet; waiting for which modifier and rule.
- 23:55 UTC answers from Xaya: #257 arrow must always be visible and the duplicate icon is missing; #258 goes to the roadmap (labeled, not built); #259 convert all listed panes plus the Load conditions pane, mockups first; #260 NONE of the modifiers apply. New request #261: moving a whole group should select the parent container, not each rule.
- 0.5.53: added /xui mods (Cues.lua ns.ProbeMods, Visual.lua ns.VisualDebug). Stub-tested (EvaluateCue merge works; report prints). NOT run in game. Root cause of #260 not found.
