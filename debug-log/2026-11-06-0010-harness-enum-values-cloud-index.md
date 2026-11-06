# Test harness: a test that every Enum value in cloud runs matches the docs (tests only; no addon change)
Logged 2026-11-06 00:10 UTC; corrected 00:22 UTC. Session 014bN6tVFhD1GEbb6ieFgKLz, branch `claude/great-franklin-j4cahh`.

## Found
The full suite for this branch's core change failed `tests/cdm_warn_run.py`; it failed the same way on `main` 0ef9cb0 without the
change. Cause: the stand-in game (`tests/harness/world.lua`) numbered an enum's fields by their place in the API index's list, and the
cloud index (`tests/harness/api_index_from_docs.py`, from `docs/reference/api/api.json`) listed them alphabetically, so
`Enum.SecrecyLevel.NeverSecret` read 2 (documented 0, `docs/reference/api/enums.md`). Across api.json, 5812 of 6614 documented values
were wrong (741 of 856 enums).

## Fixed on `main` first
Session 014bN6tSiDK8R3ZHPmcK9QHR found and fixed the same defect on `main` at 23:59 UTC (7426e7f,
`debug-log/2026-11-05-2359-harness-enum-values-from-docs.md`): the index keeps `{field: value}` and world.lua uses the values. This branch
had its own fix (039e9fa, an `enumValues` table); when `main` was merged in, `main`'s version of both files was kept and this branch's
fix was dropped.

## What this branch adds
- `tests/harness_enum_values_run.py`: builds its own index from the docs in a temporary folder and checks all 6614 documented values
  against the stand-in's `Enum` (main's fix has no test of its own). It passes on `main`'s fix. Negative control: on the code before
  either fix (0ef9cb0), 5812 values differ.
- `tests/cdm_warn_run.py`: 20 checks, 0 failed with `main`'s fix.
