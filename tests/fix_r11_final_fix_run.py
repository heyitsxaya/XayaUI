#!/usr/bin/env python3
"""Round 11b final fix: the gate's memory budget reads what is live, not the slots the stand-in's own hidden-value registries grew to
(REQUEST-LOG SD-120 "yes", SD-66 her memory cap "Today +15%, tighten later (Recommended)": 39,959.7 KB = 34,747.6 KB x 1.15).

Found (round 11b final fix, memory play of the key fight, stand-in numbers): the whole Lua state rose by about 5.4 MB during one fight and
kept it after six full collections, while every object reachable from the globals, the stand-in world, the frames, the gate's output and
the registry grew by about 0.2 MB. tests/harness/secret.lua keeps what each hidden value really is in weak-keyed tables (KIND, VALUE,
FORBID, FNAME, STABLE). A collection forgets a hidden value nobody holds, but a Lua 5.1 table keeps the slots it grew to until an insert into
a full table makes it again; the key fight makes hidden values by the thousand between two collections, so KIND and VALUE kept about 2^17
slots each. Remaking KIND, FORBID and STABLE alone took the memory play's end-of-cycle reading from 42,890.8 KB to 40,113.9 KB. The game
holds its hidden values in C: those slots are the stand-in's, not an addon's.

What is checked:
  C1  secret.lua has S.compact(): after 60,000 hidden values are made and let go, a full collection still leaves the registries' slots (the
      state stays at least 2 MB above where it started), and S.compact() followed by a collection gives them back (within 256 KB of the
      start). Fails before this change (no S.compact).
  C2  S.compact() keeps every hidden value someone still holds: a hidden number, string and payload (shape A), a forbidden table (shape C)
      and a shape B table answer as before (S.isHidden, S.reveal, S.shape, canaccesstable, issecrettable), and a hidden value made after
      it is registered as usual.
  C3  the gate compacts before each whole-state reading and never inside a handler: tests/gate_common.py memNow collects, calls S.compact
      and collects again before it reads (a hidden payload's real table holds hidden values of its own and a Lua 5.1 weak-keyed table marks
      its values, so a registry forgets one layer of dead hidden values per collection: rebuilt before the only collection, the gate's
      memory play still read 42,884.2 KB; collected, rebuilt and collected again 37,548.1 KB). The memory budget reading, gate_performance
      memory(), reads memNow through memRead.
Stand-in only: UNVERIFIED IN GAME (nothing here runs in the game).
Run: python3 tests/fix_r11_final_fix_run.py   (Lua 5.1 via lupa; a few seconds)"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.join(HERE, "harness")
SECRET = os.path.join(HARNESS, "secret.lua")
sys.path.insert(0, HARNESS)
import lupa.lua51 as lua51  # noqa: E402

results = []


def check(name, ok, detail=""):
    results.append(bool(ok))
    detail = "" if detail is None else str(detail).replace("\n", " ")
    print(("PASS " if ok else "FAIL ") + name + (("  [%s]" % detail[:400]) if (detail != "" and not ok) else ""))


def main():
    if not os.path.isfile(SECRET):
        print("MISSING INPUT: tests/harness/secret.lua (the shared secret object)")
        check("tests/harness/secret.lua exists", False)
        print("%d checks, %d failed" % (len(results), results.count(False)))
        return 1
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    S = L.eval("function(p) return dofile(p) end")(SECRET)
    r = L.eval(r"""function(S)
      local out = {}
      collectgarbage("collect"); collectgarbage("collect")
      out.m0 = collectgarbage("count")
      for i = 1, 60000 do local h = S.new(i); local t = S.newTable({ i }) end   -- (made and let go at once, as a fight does)
      collectgarbage("collect"); collectgarbage("collect")
      out.m1 = collectgarbage("count")
      out.has = type(S.compact) == "function"
      if out.has then S.compact() end
      collectgarbage("collect"); collectgarbage("collect")
      out.m2 = collectgarbage("count")
      return out
    end""")(S)
    m0, m1, m2, has = r["m0"], r["m1"], r["m2"], r["has"]
    check("C1 secret.lua has S.compact()", bool(has))
    check("C1 ... 60,000 hidden values made and let go leave the registries' slots after a full collection (%.1f KB above the start; "
          "at least 2,048)" % (m1 - m0), m1 - m0 >= 2048, "%.1f -> %.1f KB" % (m0, m1))
    check("C1 ... and S.compact() then a collection gives them back: %.1f KB above the start (at most 256)" % (m2 - m0),
          bool(has) and m2 - m0 <= 256, "%.1f -> %.1f -> %.1f KB" % (m0, m1, m2))
    keep = L.eval(r"""function(S)
      local o = { n = S.new(42), s = S.new("Fireball"), a = S.newTable({ isFullUpdate = true }, "A"), c = S.newTable({ x = 1 }, "C"),
                  b = S.newTable({ y = 2 }, "B") }
      if type(S.compact) == "function" then S.compact() end
      collectgarbage("collect")
      local later = S.new(7)
      local ac, it = rawget(_G, "canaccesstable"), rawget(_G, "issecrettable")
      return S.isHidden(o.n) and S.reveal(o.n) == 42, S.isHidden(o.s) and S.reveal(o.s) == "Fireball", S.shape(o.a) == "A",
        S.shape(o.c) == "C", S.shape(o.b) == "B", S.isHidden(later) and S.reveal(later) == 7
    end""")(S)
    names = ("a hidden number", "a hidden string", "a payload (shape A)", "a forbidden table (shape C)", "a shape B table",
             "a hidden value made after it")
    bad = [n for n, ok in zip(names, keep) if not ok]
    check("C2 S.compact() keeps every hidden value still held (number, string, shapes A, B and C) and registers one made after it",
          not bad, bad)
    src = open(os.path.join(HERE, "gate_common.py"), encoding="utf-8").read()
    mem_now = re.search(r"^local function memNow\(\)(.*)$", src, re.M)
    body = mem_now.group(1) if mem_now else ""
    first, comp = body.find('gc("collect")'), body.find("KF.S.compact()")
    check("C3 the gate's memory reading (gate_common.py memNow) collects, then calls S.compact, then collects again before it reads "
          "(the registries forget dead hidden values only in a collection)",
          bool(mem_now) and 0 <= first < comp and body.find('gc("collect")', comp) > comp
          and body.find('gc("count")', comp) > body.find('gc("collect")', comp), body[:200])
    reads = re.search(r"^local function memRead\(\)\n(.*?)^end", src, re.M | re.S)
    check("C3 ... and memRead, which every budget reading uses, reads through memNow", bool(reads) and "memNow()" in reads.group(1),
          reads.group(1)[:200] if reads else "no memRead")
    print("%d checks, %d failed" % (len(results), results.count(False)))
    return 1 if results.count(False) else 0


if __name__ == "__main__":
    sys.exit(main())
