#!/usr/bin/env python3
"""Offline test (round 8, engine-core repair 1; the round-8 reviewer's blocker on item 4, RB-30 finding 5).

Round 8 taught the full settle (XayaUI_Rules/Engine.lua Settle) to run the re-checks that waited for it when a load event (a gear
change, an encounter, entering the world: Conditions.lua ns.LoadEvent) left every load fact as it was. That branch read allArmed,
routedArmed and called DoRouted, but those locals were declared further down the file, so Lua compiled all three there as GLOBALS:
nil. The common case after round 8 (a gear change with no "Item Equipped" rule) plus a routed change waiting for that settle stopped
with "attempt to call global 'DoRouted' (a nil value)", and the removed buff's icon stayed on screen until the next aura event.

What the player gets:
  A. a target change, the next frame a gear change and, in the same frame, a buff removed: no Lua error, and the buff's icon hides
     within half a second (and stays hidden 10 s later, with no further event);
  B. a gear change and a buff removed in the same frame (no pass just before): the same;
  C. (static, all of XayaUI_Rules) no file reads or writes, as a global, a name it declares "local" further down (a forward
     reference Lua compiles as a global). Read from the compiled Lua 5.1 bytecode (GETGLOBAL / SETGLOBAL), so a branch the stand-in
     never runs is checked too (the harness's unknown-globals list only sees what runs).
Stand-in: the whole-addon harness (tests/harness). UNVERIFIED IN GAME.
Run: python3 tests/fix_r8_engine_scope_run.py"""
import os, re, struct, sys, glob
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, MODE)
local R = {}
local aura = { [1001] = { spellId = 1001, auraInstanceID = 501, name = "Scope", applications = 1, duration = 30, expirationTime = 0, sourceUnit = "player", isHelpful = true } }
local function copy(a) local t = {}; for k, v in pairs(a) do t[k] = v end; return t end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) local a = aura[id]; return a and copy(a) or nil end
C_UnitAuras.GetUnitAuraBySpellID = function(u, id) if u == "player" then return C_UnitAuras.GetPlayerAuraBySpellID(id) end end
W.RemoveAuraContainer()   -- (round 11 repair, standin-repair1) this test measures XayaUI's own drawing of aura displays: a client without Blizzard's aura container,
-- so the combat engine falls back (XUI-W002, declared below) and XayaUI draws them (tests/harness/world.lua)
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
ns.rules = {}
local r = ns.NewRule(); r.name = "scope"; r.enabled = true
r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
r.visual.text.enabled = false; r.sound.enabled = false; r.visual.trigger = "condition"
r.useBuff, r.buffID, r.buffState, r.cdState = true, 1001, "present", "none"
ns.NormalizeRule(r); ns.rules[1] = r
aura[1001].expirationTime = W.now + 30
ns.MarkDirty(); W.tick(1 / 60, 20); W.tick(0.5, 2)
local fr = ns.VisualProbeState and ns.VisualProbeState()
local function shown() local f = fr and fr[r]; return f and f:IsShown() and true or false end
R[#R + 1] = { "(setup) the buff's icon shows", shown() }
local e0 = #W.errors
if MODE == "A" then W.fire("PLAYER_TARGET_CHANGED"); W.tick(1 / 60, 1) end   -- an every-live-rule pass just ran
W.fire("PLAYER_EQUIPMENT_CHANGED", 13, false)                               -- a load event that changes no load fact
aura[1001] = nil
W.fire("UNIT_AURA", "player", { removedAuraInstanceIDs = { 501 } })        -- in the same frame: the buff goes
W.tick(1 / 60, 30)
R[#R + 1] = { MODE .. ". no Lua error from the engine", #W.errors == e0, #W.errors > e0 and tostring(W.errors[e0 + 1]):sub(1, 160) or nil }
R[#R + 1] = { MODE .. ". the removed buff's icon hides within half a second", not shown() }
W.tick(1, 10)
R[#R + 1] = { MODE .. ". ... and is still hidden 10 s later, with no further event", not shown() }
return R
end
'''


# ---- C: forward references, from the compiled bytecode ------------------------------------------------------------------------
def _dump(path):
    L = H.lua51.LuaRuntime(encoding=None)
    f = L.eval("function(s, n) local fn, e = loadstring(s, n); if not fn then error(e) end; return string.dump(fn) end")
    return f(open(path, "rb").read(), b"@" + path.encode())


def _globals(b):
    """(op, name, line) for every GETGLOBAL (5) / SETGLOBAL (7) in a Lua 5.1 bytecode dump"""
    assert b[:4] == b"\x1bLua" and b[4] == 0x51, "not Lua 5.1 bytecode"
    isz, ssz, insz, nsz = b[7], b[8], b[9], b[10]
    p = [12]
    def rd(n):
        s = b[p[0]:p[0] + n]; p[0] += n; return s
    def ri(): return int.from_bytes(rd(isz), "little")
    def rs():
        n = int.from_bytes(rd(ssz), "little")
        return rd(n)[:-1].decode("utf-8", "replace") if n else None
    out = []
    def fn():
        rs(); ri(); ri(); rd(4)
        code = [int.from_bytes(rd(insz), "little") for _ in range(ri())]
        k = []
        for _ in range(ri()):
            t = rd(1)[0]
            k.append(None if t == 0 else bool(rd(1)[0]) if t == 1 else struct.unpack("<d", rd(nsz))[0] if t == 3 else rs())
        for _ in range(ri()): fn()
        lines = [ri() for _ in range(ri())]
        for _ in range(ri()): rs(); ri(); ri()
        for _ in range(ri()): rs()
        for i, ins in enumerate(code):
            if ins & 0x3F in (5, 7):
                out.append(("read" if ins & 0x3F == 5 else "write", k[ins >> 14], lines[i] if i < len(lines) else 0))
    fn()
    return out


DECL = re.compile(r"\blocal\s+function\s+([A-Za-z_]\w*)|\blocal\s+([A-Za-z_][\w\s,]*?)(?:=|$|\bin\b)")


def forward_refs(path, code_bytes=None):
    decl = {}
    for i, line in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
        for m in DECL.finditer(line.split("--", 1)[0]):
            for nm in ([m.group(1)] if m.group(1) else [x.strip() for x in m.group(2).split(",")]):
                if re.fullmatch(r"[A-Za-z_]\w*", nm or ""):
                    decl.setdefault(nm, []).append(i)
    return [(op, nm, ln, decl[nm]) for op, nm, ln in _globals(code_bytes or _dump(path))
            if nm in decl and any(d > ln for d in decl[nm])]


def main():
    total = bad = nerr = 0
    def report(name, ok, extra=None):
        nonlocal total, bad
        total += 1; bad += 0 if ok else 1
        print(("ok  " if ok else "FAIL: ") + name + ("" if extra is None else "  [%s]" % extra))
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    for mode in ("A", "B"):
        L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
        api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
        world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
        loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
            os.path.join(H.HERE, "loader.lua"), world,
            H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
        res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)
        for i in range(1, len(res) + 1):
            report(res[i][1], bool(res[i][2]), res[i][3])
    files = sorted(glob.glob(os.path.join(ROOT, "XayaUI_Rules", "*.lua")) + glob.glob(os.path.join(ROOT, "XayaUI_Rules", "Combat", "*.lua")))
    found = []
    for f in files:
        for op, nm, ln, d in forward_refs(f):
            found.append("%s:%d %s of global %r, declared local at line %s" % (os.path.relpath(f, ROOT), ln, op, nm, d))
    report("C. no XayaUI_Rules file uses, as a global, a name it declares local further down (%d files)" % len(files), not found,
           "; ".join(found[:6]) if found else None)
    # the scan itself works: a known forward reference is found
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as t:
        t.write("local function A() return B() end\nlocal function B() return 1 end\n")
    probe = forward_refs(t.name); os.unlink(t.name)
    report("C. (the scan finds a planted forward reference)", len(probe) == 1 and probe[0][1] == "B", probe)
    print("EXPECT_ERRORS XUI-W002 2")   # (round 11 repair) one per stand-in session, caused on purpose by W.RemoveAuraContainer() above (Combat/AuraDisplay.lua records it once per session)
    print("%d checks, %d failed, %d Lua errors" % (total, bad, nerr))
    sys.exit(1 if bad or nerr else 0)


if __name__ == "__main__":
    main()
