# #2: the per-talent Known / Not known control is a three-click toggle (core 0.6.56, Options 0.6.55)

Engine session 2. Her answer (QUESTIONS-engine-session.md "Her answers", #2): "three-click toggle (Known green / Not known red / not set)".
- Options.lua Load tab, Talent List: the "Requirement" dropdown (must be KNOWN / must NOT be known) is replaced by a tri-state toggle, the
  same click pattern as the load conditions: "Known" (green) -> "Not known" (red) -> "Not set" -> "Known" (AceGUI CheckBox tri-state order
  true -> nil -> false). Removed: TALENT_STATE / TALENT_STATE_ORDER (no other reader, git grep).
- Conditions.lua CheckTalents: an entry with state "none" (Not set) is left out (no bearing, her #18 answer); a saved entry without a state
  keeps reading as Known (unchanged for existing rules).
- Scope (V4): readers of rule.talents[].state: CheckTalents (both loops use the filtered list), the auto-populate table (writes "known"),
  Options talent list. Talent scan / class learner do not read it.
- Test: tests/talent_tri_toggle_run.py (10 checks); 6 fail on the old code. QA B195.
