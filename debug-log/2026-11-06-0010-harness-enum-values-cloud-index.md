# Test harness: Enum values in cloud runs matched the docs in only 115 of 856 enums (tests only; no addon change)
Logged 2026-11-06 00:10 UTC. Session 014bN6tVFhD1GEbb6ieFgKLz, branch `claude/great-franklin-j4cahh`.

## Found
The full suite for core 0.6.49 failed `tests/cdm_warn_run.py` (core 0.6.48 / Options 0.6.43, from the engine session). It fails the same
way on `main` 0ef9cb0 without core 0.6.49, so the failure was not caused by that change. Cause: the stand-in game (`tests/harness/world.lua`)
numbers an enum's fields 0, 1, 2 ... by their place in the API index's list. The index cloud sessions build (`tests/harness/api_index_from_docs.py`, from
`docs/reference/api/api.json`) listed them in api.json's order, which is alphabetical. So `Enum.SecrecyLevel` read NeverSecret = 2,
AlwaysSecret = 0, ContextuallySecret = 1. Documented (`docs/reference/api/enums.md`): NeverSecret = 0, AlwaysSecret = 1,
ContextuallySecret = 2. The test's aura with secrecy 2 then read as never hidden, and nothing was listed. Across api.json: 5812 of 6614
documented values wrong, in 741 of 856 enums. Every cloud full-suite run since `api_index_from_docs.py` was added (merge 4f52abd) ran
with these numbers. The index built on Xaya's machine (`build_api_index.py`, from the raw dump) is not affected as far as this test shows
(the engine session's run passed); its field order was not checked here (no raw dump in the cloud).

## Fixed
- `api_index_from_docs.py`: fields listed in value order, and `enumValues {name: {field: value}}` added to the index.
- `world.lua`: an enum field takes its `enumValues` number when the index has one, else its place in the list (as before, so an index
  from `build_api_index.py` behaves as it did).

## Verification
- `tests/harness_enum_values_run.py` (new): builds its own index from the docs in a temporary folder and checks all 6614 documented values
  against the stand-in's `Enum`. Negative control: with the old builder and world.lua, 5812 differ.
- `tests/cdm_warn_run.py`: 20 checks, 0 failed (was a Lua error at its 11th check in the cloud).
- Full suite: run after this commit (see the reply).
