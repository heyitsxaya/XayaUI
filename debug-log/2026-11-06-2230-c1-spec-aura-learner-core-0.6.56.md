# C1: the per-spec learner keeps each spec's Cooldown Manager auras and debuffs (core 0.6.58, Options 0.6.58)

Version note: built as core 0.6.56; it reaches main as core 0.6.58 / Options 0.6.58 (main had 0.6.57 after the 2026-11-06 bundle).
Engine session 2. Her answer (question prompt, 2026-11-06 ~22:35 UTC): "Build it", after the cost was put to her ("determine performance
cost first"): stand-in measurement, one read of a 120-entry Cooldown Manager catalogue about 0.1 ms (not in game).
- ClassLearn.lua: ns.CdmAuraCatalogue (moved from XayaUI_Options/AutoPicker.lua AP.CdmAuras, same logic; AutoPicker now calls it) and
  CL.Learn saves the spec's auras ("aura") and target debuffs ("debuff") next to its cooldowns. Same timing as before: 3 s after login,
  a spec or talent change, never in combat (retried after combat for a spec never learned). Saved in CueRulesDB.classLearn (dropped on a
  new game build, as before).
- AutoPicker.Candidates: another spec's list adds its learned auras / debuffs; the spec you are in is still read live.
- V2: see the catalogue comment (namespaces.md:1370-1371, structures.md:1798); selfAura meaning is an INFERENCE (undocumented).
- Scope (V4, git grep CLASS_AURA_DATA): AutoPicker.Candidates (filters by kind) and the spell ID search (Options.lua ~7279, which already
  labels "debuff" / "buff" entries): learned auras and debuffs now also appear in the spell search ("spell data capture holds debuffs").
- Tests: tests/class_learn_auras_run.py (6; 3 fail on the old code), tests/auto_picker_run.py C1 check (fails on the old code). QA B200.
