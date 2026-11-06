# RM-LAYOUTS: what the tests would check (outline only)

- Capture then apply puts every display and group back exactly (the same check as `tests/mover_session_run.py` Cancel).
- A spec change with two layouts whose load conditions differ: the matching layout's places are applied once, on screen.
- Adding, deleting, renaming or reordering rules between capture and apply: each display still lands in its own place (needs stable
  rule IDs).
- A group that keeps an arrangement (G7) keeps its line after a layout is applied.
- V14: no layouts saved, then no event registered and nothing measured.
