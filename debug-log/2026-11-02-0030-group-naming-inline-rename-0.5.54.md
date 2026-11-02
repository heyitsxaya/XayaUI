# Group naming and inline rename (build 0.5.54, fork: main)
Logged 2026-11-02 00:30 UTC. Issue #263. Session: https://claude.ai/code/session_014bN6tVJMhXhJr5SQhrk92Q

Reports (Xaya):
1. "creating a new dynamic group (or anything else) should not auto-populate the name field with any numbers" (screenshot: "Dynamic Group 14 (0)").
2. "clicking rename should allow you to edit within the sidebar" (right-click menu Rename opened a popup).

Cause (read, not run): Options.lua built folder names as "<label> " .. (#ns.folders + 1) in five places; menu Rename called AskRename (popup).
Change: names are now plain; menu Rename calls ns.SidebarRenameLater -> ns.SidebarRename (now handles folders too, 0.1 s delay so the closing menu does not take focus). Popup remains the fallback.
Status: syntax-checked only; not tested in game. Open question: existing groups already named "Group 14" keep their names (not migrated).
