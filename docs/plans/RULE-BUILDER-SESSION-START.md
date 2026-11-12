# Rule Builder: session start (loads cold)

**What this is.** A guided "Rule Builder" for XayaUI, a World of Warcraft: Midnight addon written in Lua 5.1. It makes rules from dropdowns and multi-selects, one step per page, without the editor panes. Requested by Xaya (SD-59, REQUEST-LOG A25 RB-1).

**Branch.** `claude/rule-builder`, cut from `claude/dazzling-brown-x9fqrm` (bundle 1).
- Coordinate landing with the Rules session (session_014bN6tVBGo8BHkHu65TAcjD) via send_message.
- Never push main or qa-installer-branch.

**Phase.** DESIGN. No addon code until the Rules session reports that bundle 1 is on main, which moves the editor into XayaUI_Options. Then rebase onto main and build there.

**Binding rules.**
- docs/process/VERIFICATION.md: V25-V34 (top section) and V15 (log every message of hers verbatim in REQUEST-LOG A25).
- V16: no guessing; propose and confirm first.
- V19: questions go through the question tool.
- Reference addons: compare behaviour only. Never copy anything from them, and never touch her Drive folder.

**Decided (her answers).**
- Stage 1 covers triggers only: cooldown ready / not ready, charges, buff on me, debuff on target, combinations with All/Any, and load conditions (RB-2, RB-6).
- An explanation box states the exact logic of her choices (RB-7).
- The rule is created only on Finish, through the editor's own NewRule → NormalizeRule → DraftNew path (RB-8).
- The done page has three buttons: Open in editor, Build another rule, Finish (RB-9).
- Entry points: a row in the "+ New rule" picker, and a button in the Auto-Generate Rules tab (RB-4).
- One step per page (RB-5).

- **Name:** an automatic name, editable at any time, with a final step for the name and the group (RB-10).
- **Spell pick:** a dropdown plus a search box (RB-11).
- **Load:** a yes/no question, then the Load tab 1:1 with a logic indicator (RB-12).
- **Combat:** if combat starts, the answers are kept and the builder reopens after combat (RB-13).

**Pending.** RB-14: a load-condition study of EUI and ElvUI (docs/plans/LOAD-CONDITIONS-STUDY.md), then a proposal to Xaya. Also build-time checks (a) and (b) in the design §4. Draft PR #525.

**Key files.**
- docs/plans/RULE-BUILDER-DESIGN.md and RULE-BUILDER-TRACKER.md.
- Rule format and checks: XayaUI_Rules/RuleDefaults.lua and Triggers.lua; `ns.Evaluate` in Conditions.lua.
- Editor (moving to XayaUI_Options): Editor/RulesTree.lua (`CreateRuleOfType`, the picker), Drafts.lua, AutoPicker.lua.

**Tests.** `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py`, plus the gate tests tests/gate_{mouse,keyboard,performance}_run.py.
