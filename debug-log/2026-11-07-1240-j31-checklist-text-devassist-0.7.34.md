# J31 checklist text after landing (Dev Assist 0.7.34; docs + generated walkthrough text only)

Session: perf successor (session_014bN6tTqaMKxGcnwALJ4CoU). After the lander merged 8ae0b95 (f27bee9) and relabelled it (f056997:
Options 0.6.70, J28 -> J31), docs/QA-CHECKLIST.md item J31 still named the walkthrough "(J28)" and Options 0.6.69. Fixed the item's
text; XayaUI_DevAssist/QAWalks-Checklist.lua regenerated (tools/qa_walks_from_checklist.py), which is the only Dev Assist change.
Also docs: REQUEST-LOG A15 P-16 now "on main"; PERF-CODE-NOTES: the perf-click row marked on main, the UI-bugs successor's
ns.Tip note (12:00 UTC) logged. No runtime change. Tests: tests/qa_walk_run.py (in sync), tools/precheck.py --base origin/main.
