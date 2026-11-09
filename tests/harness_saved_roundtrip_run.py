#!/usr/bin/env python3
"""tests/harness_saved_roundtrip_run.py: the whole-addon harness carries saved variables from one session to the next the way the
game does, as Lua source, so numeric keys stay numbers across a /reload (fix plan f6-3).
Before the fix, tests/harness/run.py passed what a session saved to the next session as Python data (lua_to_py -> to_lua), which
turns every key of a non-list table into a string: { [5] = "x" } came back as { ["5"] = "x" }, so code reading t[5] after a reload
saw nil in the harness while the game sees "x". Negative control: the old route (session()["saved"], the Python data) is run here
too and must show the string keys.
Run: python3 tests/harness_saved_roundtrip_run.py   (needs: pip install lupa)"""
import os, sys, tempfile
HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "harness")
sys.path.insert(0, HERE)
import run as H  # noqa

checks = fails = 0


def check(name, ok, detail=""):
    global checks, fails
    checks += 1
    if not ok:
        fails += 1
        print("FAIL", name, detail)
    else:
        print("ok  ", name)


def key_types(L, t):
    return sorted(L.eval("function(t) local o = {} for k in pairs(t) do o[#o + 1] = type(k) .. ':' .. tostring(k) end return o end")(t).values())


# 1. the serializer on its own: two separate Lua states, as two sessions are
A = H.lua51.LuaRuntime(unpack_returned_tuples=True)
sa = H.savedvars(A)
val = A.eval("""function() return { sparse = { [5] = "five", [12] = "twelve", [1] = "one" }, list = { "a", "b" },
  mixed = { [1] = 1, x = "y", [2.5] = "half", [true] = "yes" }, nested = { [3] = { [7] = 70 } }, s = "quote \\" and \\n newline",
  big = 2^40, neg = -3, frac = 0.1, inf = math.huge, f = function() end } end""")()
src = sa.Serialize(val)
B = H.lua51.LuaRuntime(unpack_returned_tuples=True)
back = H.savedvars(B).Load(src)
check("sparse numeric keys stay numbers in the next Lua state", key_types(B, back["sparse"]) == ["number:1", "number:12", "number:5"],
      key_types(B, back["sparse"]))
check("a list stays a list", back["list"][1] == "a" and back["list"][2] == "b")
check("mixed keys keep their types (number, fraction, string, boolean)",
      key_types(B, back["mixed"]) == ["boolean:true", "number:1", "number:2.5", "string:x"], key_types(B, back["mixed"]))
check("nested numeric keys", back["nested"][3][7] == 70)
check("strings with quotes and newlines", back["s"] == 'quote " and \n newline')
check("numbers: 2^40, -3, 0.1, math.huge", back["big"] == 2 ** 40 and back["neg"] == -3 and back["frac"] == 0.1 and back["inf"] == float("inf"))
check("a function is not saved (the game cannot save one)", back["f"] is None)
check("serializing twice gives the same text (sorted keys)", H.savedvars(B).Serialize(back) == src)

# 2. the old route, for the record: Python data turns those keys into strings (the bug)
old = H.lua_to_py(val["sparse"])
check("negative control: the old Python route turned [5] into '5'", set(old) == {"1", "5", "12"}, old)

# 3. a SavedVariables file (--saved PATH): read_saved_source keeps the key types
with tempfile.TemporaryDirectory() as d:
    p = os.path.join(d, "XayaUI.lua")
    with open(p, "w", encoding="utf-8") as f:
        f.write('CueRulesDB = {\n\t["xuiRoundTrip"] = {\n\t\t[5] = "five",\n\t\t[12] = "twelve",\n\t},\n}\n')
    s = H.read_saved_source(p)
    C = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    t = H.savedvars(C).Load(s)
    check("--saved PATH: the file's [5] / [12] keys reach the session as numbers",
          key_types(C, t["XayaUI"]["CueRulesDB"]["xuiRoundTrip"]) == ["number:12", "number:5"])

# 4. end to end: a real harness session loads saved data with numeric keys, and what it saves at logout keeps them for the /reload
folders = H.find_addons()
seed = H.lua51.LuaRuntime(unpack_returned_tuples=True)
seedSrc = H.savedvars(seed).Serialize(seed.eval('function() return { XayaUI = { CueRulesDB = { xuiRoundTrip = { [5] = "five", [12] = "twelve" } } } } end')())
s1 = H.session(folders, {H.CORE, "XayaUI_Media"}, seedSrc, quick=True)
D = H.lua51.LuaRuntime(unpack_returned_tuples=True)
after = H.savedvars(D).Load(s1["savedSource"])
rt = after["XayaUI"] and after["XayaUI"]["CueRulesDB"] and after["XayaUI"]["CueRulesDB"]["xuiRoundTrip"]
check("a /reload round trip in the harness: the table with keys 5 and 12 comes back with number keys",
      rt is not None and key_types(D, rt) == ["number:12", "number:5"], key_types(D, rt) if rt is not None else s1["errors"][:3])
s2 = H.session(folders, {H.CORE, "XayaUI_Media"}, s1["savedSource"], quick=True)
E = H.lua51.LuaRuntime(unpack_returned_tuples=True)
again = H.savedvars(E).Load(s2["savedSource"])["XayaUI"]["CueRulesDB"]["xuiRoundTrip"]
check("... and again after a second /reload", key_types(E, again) == ["number:12", "number:5"])
# the old route on the same session: hand the next session the Python data, as run_combo used to
s2old = H.session(folders, {H.CORE, "XayaUI_Media"}, s1["saved"], quick=True)
F = H.lua51.LuaRuntime(unpack_returned_tuples=True)
oldrt = H.savedvars(F).Load(s2old["savedSource"])["XayaUI"]["CueRulesDB"]["xuiRoundTrip"]
check("negative control: the old route (Python data) brings the keys back as strings '12' and '5'",
      key_types(F, oldrt) == ["string:12", "string:5"], key_types(F, oldrt))

print("%d checks, %d failed" % (checks, fails))
sys.exit(1 if fails else 0)
