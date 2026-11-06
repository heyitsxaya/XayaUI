#!/usr/bin/env python3
"""The stand-in game's Enum values match the 12.1.5 documentation when the API index is built from the repository's docs
(tests/harness/api_index_from_docs.py, the index cloud sessions use).
Found 2026-11-06: the stand-in numbered an enum's fields by their place in the index's list (world.lua), and the docs-built index listed
them alphabetically (api.json keeps them in a dict), so 741 of the 856 enums had wrong numbers in cloud runs, for example
Enum.SecrecyLevel.NeverSecret = 2 instead of 0. tests/cdm_warn_run.py failed in the cloud for that reason and passed on an index built
from the raw dump. The index now carries the values (enumValues) and lists fields in value order; world.lua reads the values.
This test builds its own index in a temporary folder (whatever XUI_API_INDEX points to is not used) and checks every enum of
api.json against the stand-in's Enum table. Negative control: with the old builder and world.lua, 5812 of the 6614 documented
values differ (in 741 enums).
Run: python3 tests/harness_enum_values_run.py   (Lua 5.1 via lupa)."""
import json, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

docs = json.load(open(os.path.join(HERE, "..", "docs", "reference", "api", "api.json"), encoding="utf-8"))["docs"]["enums"]
with tempfile.TemporaryDirectory() as tmp:
    out = os.path.join(tmp, "api_index.json")
    subprocess.run([sys.executable, os.path.join(HERE, "harness", "api_index_from_docs.py"), out], check=True, capture_output=True)
    api = json.load(open(out))
L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), H.to_lua(L, api))
get = L.eval("function(k, f) local e = Enum[k]; return e and rawget(e, f) end")

checks, bad = 0, []
for name, fields in docs.items():
    if not isinstance(fields, dict):
        continue
    for f, v in fields.items():
        checks += 1
        got = get(name, f)
        if got != v:
            bad.append("%s.%s = %r (documented %r)" % (name, f, got, v))
spot = [("SecrecyLevel", "NeverSecret", 0), ("SecrecyLevel", "AlwaysSecret", 1), ("SecrecyLevel", "ContextuallySecret", 2)]
for name, f, v in spot:
    checks += 1
    ok = get(name, f) == v
    print(("PASS " if ok else "FAIL ") + "Enum.%s.%s == %d (docs/reference/api/enums.md)" % (name, f, v))
    if not ok:
        bad.append("%s.%s" % (name, f))
print(("PASS " if not bad else "FAIL ") + "every documented enum value matches in the stand-in (%d fields)" % (checks - len(spot)))
for b in bad[:10]:
    print("   ", b)
print("%d checks, %d failed" % (checks, len(bad)))
sys.exit(1 if bad else 0)
