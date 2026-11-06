# #18: an unset load option has no bearing (no code change; test added)

Engine session 2. Her answer (QUESTIONS-engine-session.md "Her answers", #18): "If instance type is not specified, it has no bearing on the
rule loading and firing and should not be considered. This is true for all options that are not outright specified in some way".
Read in the code (Conditions.lua CheckContextRaw): every yes / no fact (ns.LOAD_TRI) is checked only when not ns.Ignored; instance types,
class, spec, role, hero tree only when their set is active (ns.SetActive); ID lists only when non-empty; a group's conditions likewise.
So the code already does what she answered; #18's question (Mythic+ / encounter / instance type while "Instance" is not set) gets: they apply
on their own, "Instance" has no bearing.
Test: tests/unset_load_no_bearing_run.py (5 checks). It is a lock on existing behaviour, so it cannot fail on the old code (V1 negative
control not applicable: nothing was changed). #18 stays open until confirmed in game (V6).
