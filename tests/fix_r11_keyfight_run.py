#!/usr/bin/env python3
"""Round 11b, the hidden-data fight in the V27 gates (build spec steps 6 and 7, section 4; tests/gate_common.py, tests/gate_performance_run.py).

Her answers (verbatim, REQUEST-LOG): SD-120 "yes" (the stand-in and the gates hide aura and cooldown data the way keys, raids and boss
fights do, and the CPU budget is judged on that fight); SD-126 "Key only, raids in smaller tests (Recommended)" (the gate plays a Mythic+
key: three fights, the time between pulls, a boss; a raid boss is covered here, without a speed measure); SD-127 "Yes, fix it first
(Recommended)" (every payload shape blocks landing: the gate plays shape A, unit tests B and C).

What the player gets: a speed gate that measures XayaUI where it is busiest and where the game hides data from it, and that fails when
the play did not really hide anything, so a build cannot pass on readable data it will never see in a key.

  T9   (spec 4.3) one play of the gate's own scenario (a fresh install, the fights at full length), with a probe addon file added: the
       fights are inside one Mythic+ key (CHALLENGE_MODE_START once, CHALLENGE_MODE_COMPLETED once), the restrictions went through
       Activating and Inactive for Combat 0, Encounter 1, ChallengeMode 2, Map 4 and Chat 5 and ended Inactive, every fight got hidden
       UNIT_AURA payloads and no payload inside the key was readable, each boss pull is the key's (difficulty 8, group size 5), the gate
       played payload shape A, the measured play had the line hook off, no Lua error; the gate's loop instrument (its ipairs) meets a
       hidden payload with Lua's own refusal, not a secret-value error of its own; tests/gate_common.py's own integrity checks
       (key_fight_checks) FAIL on copies of the result with a readable payload in the key, no key, a raid-sized boss or the line hook on;
       the gate files never set W.combat themselves.
  T10  (spec 4.4) the stand-in's fingerprint (tests/gate_performance_run.py standin_stamp) changes when world.lua's or secret.lua's code
       changes and when one flag of the API index changes, and not when the index is only re-indented; the scenario's stamp changes
       when the scenario changes; v33() refuses a stored record for another scenario (MISSING INPUT) and an ad60a051 play that raised Lua
       errors (its errors printed); the stand-in's share is printed with both builds' wall-clock time, a shift of the readout above 2%
       FAILs, and a missing ad60a051 share FAILs as MISSING INPUT.
  T12  (spec 3.1) hidden values the stand-in makes for addon code (a hidden number a reader hands back, the hidden string '..' and
       string.format make of it) are not billed to the addon: the probe's handler that makes them inside the key is billed 0 bytes on
       every run (P4); and once dropped they are collected (MEM reads memory after a full collection).
  T3   (raid, SD-126: no speed measure) the gate's ~300-rule profile played in a raid (difficulty 16, 20 players): between bosses auras
       are readable (Map and Chat restrictions on, ChallengeMode never), a buff display shows and the spell-ID read answers; a boss pull
       in combat hides auras (the read gives nil, the payload is hidden, the encounter is in progress) and the boss rules show (two
       for this boss's ID, two for any boss); after the kill the boss rules hide and auras read again; a boss encounter while out of
       combat hides auras too (INFERENCE, RACD:27) and shows only the any-boss rules; no Lua error.
  T14  (round 11b gate repair 1: the words Xaya reads) the draw check's words (tests/gate_performance_run.py drawn) on draw-play data of
       the key fight's shape (no Lua play: the data is built here): the absent target debuffs are printed for every moment with its combat
       and target state, so "shown 6 of 6 with no target selected, 0 of 6 while a target is selected, out of combat too" is what the gate
       says (round 11b's first report read "never shown, out of combat included" from the old line "shown 0 (out of combat 0)", whose second
       number was the combat-end moment with the target still selected); the FAIL for rules that did not change at their moments is still
       raised and names the moment they stopped changing; a display that differs from a full re-check is still a FAIL, but its words no
       longer state the cause as fact (a narrowed re-check that missed a rule, or a hidden cooldown's end that the engine wakes on the next
       frame, SD-60); on data of the readable fight's shape the same words raise no FAIL (the words are read from the data, not fixed).
Run: python3 tests/fix_r11_keyfight_run.py   (Lua 5.1 via lupa; about three to four minutes)
     XUI_KEYFIGHT_SECTIONS=T14 runs only the named sections (comma-separated; for a quick look, never for a result that counts)"""
import contextlib, copy, io, json, os, re, shutil, sys, tempfile, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H              # noqa: E402
import gate_common as GC     # noqa: E402
import gate_performance_run as GP   # noqa: E402

H.require_api("tests/fix_r11_keyfight_run.py")

FAILED, CHECKS = [], [0]


def check(ok, what, detail=""):
    CHECKS[0] += 1
    print("%s  %s%s" % ("ok  " if ok else "FAIL", what, ("   [" + str(detail)[:600] + "]") if (detail and not ok) else ""))
    if not ok:
        FAILED.append(what)


def section(name, fn):
    """A section that raises is a failed check (with the error), never a silent stop."""
    try:
        fn()
    except Exception as e:   # noqa: BLE001  (reported as a failed check)
        import traceback
        check(False, "section %s ran to its end" % name, "%s: %s" % (type(e).__name__, traceback.format_exc()[-900:]))


MARKER = 'checkpoint("right after the settings window closed")'
PROBE_FILE = "@Interface/AddOns/XayaUI_Rules/KeyProbe.lua"
# the probe addon file (compiled as a XayaUI_Rules file, so the gate bills it as it bills the addon): two UNIT_AURA handlers that act
# only on a hidden payload (inside the key and in the fights): A makes the stand-in's hidden values (a hidden number from a reader, '..'
# and string.format of it) and keeps them; B, once, asks ipairs for the payload under pcall and keeps the message
PROBE_SRC = r'''
local P = { aRuns = 0, bMsg = nil, bIndex = nil }
local keepN, keepS, keepF
local fa = CreateFrame("Frame", "XayaUIKeyProbeA")
fa:RegisterEvent("UNIT_AURA")
fa:SetScript("OnEvent", function(_, _, unit, info)
  if issecretvalue(info) then
    local n = C_Spell.GetSpellCastCount(400001)
    keepN = n; keepS = n .. "s"; keepF = string.format("%s", n)
    P.aRuns = P.aRuns + 1
    P.aHidden = issecretvalue(keepN) and issecretvalue(keepS) and issecretvalue(keepF)
  end
end) --@A
local fb = CreateFrame("Frame", "XayaUIKeyProbeB")
fb:RegisterEvent("UNIT_AURA")
fb:SetScript("OnEvent", function(_, _, unit, info)
  if issecretvalue(info) and P.bMsg == nil then
    local ok, e = pcall(ipairs, info)
    P.bMsg = ok and "(no error)" or e
    local ok2, e2 = pcall(function() return info.isFullUpdate end)
    P.bIndex = ok2 and "(no error)" or e2
  end
end) --@B
return P
'''
INSERT = r'''
if CFG.keyProbe then   -- (tests/fix_r11_keyfight_run.py) the probe addon file, from the window's close to the end
  OUT.keyProbe = assert(loadstring(CFG.keyProbe, "@Interface/AddOns/XayaUI_Rules/KeyProbe.lua"))()
end
'''


def probe_line(tag):
    for n, ln in enumerate(PROBE_SRC.split("\n"), 1):
        if ln.rstrip().endswith("--@" + tag):
            return n
    return None


def play_key(scenario=None, module=None):
    """One measured play of the gate's scenario on a fresh install (no profile: fast), the fights at full length (the boss at 8 s and 14 s),
    with the probe file. module: the gate_common module whose scenario and world are played (this checkout's, or a pre-change copy)."""
    gc = module or GC
    scen = scenario or gc.SCENARIO_LUA
    if scen.count(MARKER) != 1:
        raise RuntimeError("the marker %r is not in the scenario once" % MARKER)
    scen = scen.replace(MARKER, MARKER + "\n" + INSERT, 1)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world, loader, game, sv = gc._world(L, debug="off")   # (as the gate: XayaUI_Debug switched on in the AddOns list, Advanced Debugging off)
    cfg = H.to_lua(L, {"perf": True, "verbose": False, "busy": 15.0, "keyProbe": PROBE_SRC, "tree": False})
    res = L.eval("function(src, W, Ld, G, C) return loadstring(src)()(W, Ld, G, C) end")(scen, world, loader, game, cfg)
    return json.loads(json.dumps(H.lua_to_py(res), default=str))


DATA = {}


def t9():
    t0 = time.time()
    d = play_key()
    DATA["key"] = d
    print("      (the key play took %.0f s)" % (time.time() - t0))
    fired = d.get("fired") or {}
    pay = d.get("payloads") or {}
    rl = d.get("restrictions") or {}
    left = d.get("restrictionsLeft") or {}
    encs = GC.vals(d.get("encounters")) if hasattr(GC, "vals") else (d.get("encounters") or [])
    check(int(d.get("errors") or 0) == 0, "T9 the key play raised no Lua error", "; ".join((d.get("errorText") or [])[:3]))
    check(int(fired.get("CHALLENGE_MODE_START") or 0) == 1 and int(fired.get("CHALLENGE_MODE_COMPLETED") or 0) == 1,
          "T9 the three fights are inside one Mythic+ key: CHALLENGE_MODE_START once, CHALLENGE_MODE_COMPLETED once",
          "fired: %s" % fired)
    for t, name in ((0, "Combat"), (1, "Encounter"), (2, "ChallengeMode"), (4, "Map"), (5, "Chat")):
        check(int(rl.get("%d:1" % t) or 0) > 0 and int(rl.get("%d:0" % t) or 0) > 0 and str(left.get(str(t))) == "0",
              "T9 restriction %s (%d): Activating and Inactive fired, Inactive at the end" % (name, t), "counts %s; end %s" % (rl, left))
    for sg in ("fight 1", "fight 2", "fight 3"):
        c = pay.get(sg) or {}
        check(int(c.get("hidden") or 0) > 0 and int(c.get("readable") or 0) == 0,
              "T9 %s: every UNIT_AURA payload is hidden (%s hidden, %s readable)" % (sg, c.get("hidden"), c.get("readable")))
    between = sum(int((pay.get(sg) or {}).get("hidden") or 0) for sg in ("out 1", "out 2", "out 3"))
    check(between > 0 and int(d.get("keyReadable") or 0) == 0,
          "T9 between the pulls (still in the key, out of combat) the payloads are hidden too, and none in the key is readable",
          "hidden between pulls %d; readable in the key %s (first %s)" % (between, d.get("keyReadable"), d.get("keyReadableFirst")))
    check(int((pay.get("effects") or {}).get("readable") or 0) > 0 and int((pay.get("effects") or {}).get("hidden") or 0) == 0,
          "T9 after the key (the effects part, out of the dungeon) the payloads are readable again", "effects %s" % pay.get("effects"))
    check(len(encs) == 3 and all(int(e.get("difficulty") or 0) == 8 and int(e.get("size") or 0) == 5 and e.get("inKey") for e in encs),
          "T9 each of the three boss pulls is the key's boss: difficulty 8, group size 5, inside the key", "pulls %s" % encs)
    shapes = d.get("payloadShapes") or {}
    check(d.get("payloadShape") == "A" and set(shapes) == {"A"}, "T9 the gate plays payload shape A only (spec 4.2)", "%s / %s" % (d.get("payloadShape"), shapes))
    lh = d.get("lineHook") or {}
    check(lh.get("on") is False and not lh.get("armed"), "T9 the measured play has the line hook off (spec 4.3)", "%s" % lh)
    pr = d.get("keyProbe") or {}
    msg = str(pr.get("bMsg"))
    check("table expected, got userdata" in msg and "secret" not in msg,
          "T9 the gate's loop instrument (its ipairs) meets a hidden payload with Lua's own refusal, not a secret-value error of its own",
          "ipairs(payload) said: %s" % msg)
    check("secret" in str(pr.get("bIndex")), "T9 the probe's handler got a hidden payload whose index raises (shape A)", "%s" % pr.get("bIndex"))
    # the gate's own integrity checks have teeth: copies of this result with one thing wrong each
    if not hasattr(GC, "key_fight_checks"):
        check(False, "T9 tests/gate_common.py has its key fight integrity checks (key_fight_checks)")
        return
    ok_now = [w for ok, w, n in GC.key_fight_checks(d) if not ok]
    # (the probe file adds nothing the checks read; the logger is answered in this play too)
    check(not ok_now, "T9 tests/gate_common.py's key fight checks pass on this play", "failing: %s" % ok_now)

    def broken(mut, what, needle):
        dd = copy.deepcopy(d)
        mut(dd)
        bad = [w for ok, w, n in GC.key_fight_checks(dd) if not ok]
        check(any(needle in w for w in bad), "T9 the gate FAILs %s" % what, "failing checks: %s" % bad)
    broken(lambda dd: dd.update(keyReadable=5, keyReadableFirst="busy 2"), "a readable payload inside the key (a stand-in that hides nothing)",
           "no UNIT_AURA payload inside the key was readable")
    broken(lambda dd: dd["payloads"].update({"fight 2": {"hidden": 0, "readable": 974}}), "a fight with no hidden payload",
           "every fight got hidden UNIT_AURA payloads")
    broken(lambda dd: dd["fired"].pop("CHALLENGE_MODE_START", None), "a play with no key", "inside one Mythic+ key")
    broken(lambda dd: dd.update(encounters=[{"id": 2001, "difficulty": 16, "size": 20, "inKey": True}] * 3), "a raid-sized boss (16 / 20)",
           "the key's boss")
    broken(lambda dd: dd["restrictions"].pop("5:1", None), "a play where the Chat restriction never activated", "Activating (1) and Inactive (0)")
    broken(lambda dd: dd.update(lineHook={"on": True, "armed": True, "slot": "line hook"}), "a measured play with the line hook on", "line hook off")
    broken(lambda dd: dd.update(payloadShapes={"A": 10, "C": 2}), "a play that mixed payload shapes", "payload shape A")
    # the gate files never set W.combat themselves (spec 3.2: combat only through W.enterCombat / W.leaveCombat)
    hits = []
    for f in sorted(os.listdir(HERE)):
        if f.startswith("gate_") and f.endswith(".py"):
            with open(os.path.join(HERE, f), encoding="utf-8") as fh:
                for i, ln in enumerate(fh.read().split("\n"), 1):
                    if re.search(r"\bW\.combat\s*=(?!=)", ln.split("--", 1)[0]):
                        hits.append("%s:%d %s" % (f, i, ln.strip()))
    check(not hits, "T9 no gate file sets W.combat itself (combat through the stand-in's drivers only)", "; ".join(hits[:4]))
    check(not GC.scenario_sets_combat(), "T9 the gate's own check finds no W.combat assignment in its Lua", "%s" % GC.scenario_sets_combat())


def t12():
    d = DATA.get("key")
    if d is None:
        check(False, "T12 needs the key play (T9)")
        return
    # the handler's line as the gate keys it: where its function is defined (the SetScript line of fa)
    fa_line = next(n for n, ln in enumerate(PROBE_SRC.split("\n"), 1) if ln.startswith('fa:SetScript("OnEvent", function'))
    src = "XayaUI_Rules/KeyProbe.lua:%d" % fa_line
    ua = (((d.get("stats") or {}).get("ev") or {}).get("UNIT_AURA") or {})
    h = (ua.get("srcs") or {}).get(src) or {}
    by = h.get("byPhase") or {}
    key_phases = [p for p in by if p.startswith("busy")]
    runs = sum(int((by.get(p) or {}).get("n") or 0) for p in key_phases)
    byts = sum(int((by.get(p) or {}).get("bytes") or 0) for p in key_phases)
    pr = d.get("keyProbe") or {}
    check(int(pr.get("aRuns") or 0) > 900 and pr.get("aHidden") is True,
          "T12 inside the key the probe made hidden values on every hidden payload (a hidden number, its '..' and its string.format)",
          "runs %s; hidden %s" % (pr.get("aRuns"), pr.get("aHidden")))
    check(int(pr.get("aRuns") or 0) > 900 and runs > 900 and byts == 0,
          "T12 the stand-in's hidden values are not billed to the addon: the probe's handler, %d runs inside the key (%s of them making hidden "
          "values), billed %d bytes (P4)" % (runs, pr.get("aRuns"), byts), "src %s; phases %s" % (src, sorted(by)))
    # MEM: hidden values are collected once dropped (a full collection, as the memory reading does). What stays is the shared object's
    # registry capacity (its weak tables keep their slots, sized by the most hidden values alive at once): the same after every round
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    kb = L.eval('''function(path)
      local S = dofile(path)
      collectgarbage("collect"); local m0 = collectgarbage("count")
      local out = {}
      for r = 1, 3 do
        local keep = {}
        for i = 1, 20000 do keep[i] = S.new(i) end
        collectgarbage("collect"); local held = collectgarbage("count")
        keep = nil
        collectgarbage("collect"); collectgarbage("collect")
        out[#out + 1] = held - m0; out[#out + 1] = collectgarbage("count") - m0
      end
      return unpack(out)
    end''')(os.path.join(H.HERE, "secret.lua"))
    check(kb[0] > kb[1] + 300 and abs(kb[3] - kb[1]) < 1 and abs(kb[5] - kb[1]) < 1,
          "T12 hidden values are collected once dropped: 20,000 held are %.0f KB over the start; dropped and collected, %.0f KB stay, the same after "
          "the second and third round (%.0f, %.0f KB: no growth; what stays is the stand-in's registry capacity, not the values)" % (
              kb[0], kb[1], kb[3], kb[5]), "%s" % (kb,))


def t10():
    # the stand-in's fingerprint: code of world.lua / secret.lua and the API index
    tmpd = tempfile.mkdtemp(prefix="xui-keyfight-")
    keep_here, keep_env = GC.H.HERE, os.environ.get("XUI_API_INDEX")
    try:
        files = getattr(GP, "V33_STANDIN_FILES", ())
        check("secret.lua" in files, "T10 the stand-in's fingerprint reads tests/harness/secret.lua", "%s" % (files,))
        for f in set(files) | {"secret.lua", "world.lua"}:
            shutil.copyfile(os.path.join(keep_here, f), os.path.join(tmpd, f))
        api_src = keep_env or os.path.join(keep_here, "api_index.json")
        api = os.path.join(tmpd, "api_index.json")
        shutil.copyfile(api_src, api)
        os.environ["XUI_API_INDEX"] = api
        GC.H.HERE = tmpd
        s0 = GP.standin_stamp()

        def edited(fname, extra):
            p = os.path.join(tmpd, fname)
            with open(p, "rb") as fh:
                body = fh.read()
            with open(p, "wb") as fh:
                fh.write(extra(body))
            try:
                return GP.standin_stamp()
            finally:
                with open(p, "wb") as fh:
                    fh.write(body)
        s_world = edited("world.lua", lambda b: b + b"\nlocal _xui_keyfight_probe = 1\n")
        s_secret = edited("secret.lua", lambda b: b.replace(b"local S = {}", b"local S = {} local _xui_keyfight_probe = 1", 1))
        with open(api, encoding="utf-8") as fh:
            idx = json.load(fh)
        key = "SimpleStatusBarAPI:SetValue"
        sec = ((idx.get("secrecy") or {}).get("widgets") or {})
        check(key in sec, "T10 the API index has the secrecy flags of %s (the stand-in's guard reads them)" % key)

        def with_index(mut, indent=None):
            j = copy.deepcopy(idx)
            mut(j)
            with open(api, "w", encoding="utf-8") as fh:
                json.dump(j, fh, indent=indent)
            try:
                return GP.standin_stamp()
            finally:
                shutil.copyfile(api_src, api)
        flip = lambda j: j["secrecy"]["widgets"].__setitem__(key, [("SecretArguments=AllowedWhenUntainted" if "AllowedWhenTainted" in f else f)
                                                                   for f in j["secrecy"]["widgets"][key]])  # noqa: E731
        s_flag = with_index(flip) if key in sec else s0
        s_indent = with_index(lambda j: None, indent=2)
        check(s0 != s_world, "T10 one changed code line of world.lua changes the stand-in's fingerprint", "%s / %s" % (s0, s_world))
        check(s0 != s_secret, "T10 one changed code line of secret.lua changes the stand-in's fingerprint", "%s / %s" % (s0, s_secret))
        check(s0 != s_flag, "T10 one changed secrecy flag of the API index (%s AllowedWhenTainted -> AllowedWhenUntainted) changes it" % key,
              "%s / %s" % (s0, s_flag))
        check(s0 == s_indent, "T10 the API index only re-indented keeps the fingerprint (no needless re-record)", "%s / %s" % (s0, s_indent))
    finally:
        GC.H.HERE = keep_here
        if keep_env is None:
            os.environ.pop("XUI_API_INDEX", None)
        else:
            os.environ["XUI_API_INDEX"] = keep_env
        shutil.rmtree(tmpd, ignore_errors=True)
    st0 = GC.scenario_stamp()
    keep_sc = GC.SCENARIO_LUA
    try:
        GC.SCENARIO_LUA = keep_sc + "\n-- a changed scenario\n"
        st1 = GC.scenario_stamp()
    finally:
        GC.SCENARIO_LUA = keep_sc
    check(st0 != st1, "T10 the scenario's stamp changes when the scenario changes", "%s / %s" % (st0, st1))
    check(GP.V33_RECORDED.get("stamp") == st0 and GP.V33_EVENT_CAPS.get("stamp") == st0 and GP.V33_RECORDED.get("standin") == GP.standin_stamp()
          and GP.V33_EVENT_CAPS.get("standin") == GP.standin_stamp(),
          "T10 the stored V33 records (V33_RECORDED, V33_EVENT_CAPS) are for this scenario and this stand-in (the key fight)",
          "records %s/%s and %s/%s; now %s/%s" % (GP.V33_RECORDED.get("stamp"), GP.V33_RECORDED.get("standin"), GP.V33_EVENT_CAPS.get("stamp"),
                                                   GP.V33_EVENT_CAPS.get("standin"), st0, GP.standin_stamp()))
    d = DATA.get("key")
    if d is None:
        check(False, "T10 needs the key play (T9)")
        return

    def judged(base_entry, recorded=None, fn=None):
        keep_base, keep_rec = list(GP._BASE), GP.V33_RECORDED
        GP._BASE[:] = [base_entry]
        if recorded is not None:
            GP.V33_RECORDED = recorded
        rep = GC.Report("gate_performance")
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                (fn or GP.v33)(d, rep)
        finally:
            GP._BASE[:] = keep_base
            GP.V33_RECORDED = keep_rec
        return rep
    stale = dict(GP.V33_RECORDED, stamp="000000000000")
    r = judged((None, "ad60a051 not played here"), stale)
    check(any("MISSING INPUT" in f[1] for f in r.fails), "T10 v33() refuses a record stored for another scenario (MISSING INPUT)",
          "fails %s" % [f[1][:120] for f in r.fails])
    bad = {"errors": 2, "errorText": ["Interface/AddOns/XayaUI_Rules/Engine.lua:1: attempt to perform arithmetic on a secret number value"],
           "budget": d.get("budget")}
    r = judged((bad, "played now"))
    check(any("raised 2 Lua error" in f[1] for f in r.fails) and any("arithmetic on a secret" in (f[2] or "") for f in r.fails),
          "T10 v33() refuses an ad60a051 play that raised Lua errors, and prints them (spec 4.4.3)", "fails %s" % [(f[1][:100], f[2][:80]) for f in r.fails])
    # the stand-in's share: printed with the wall-clock time; a shift above 2% FAILs; no ad60a051 share is MISSING INPUT
    w = sum(((d.get("budget") or {}).get(s) or {}).get("work", {}).get("XayaUI_Rules", 0) for s in ("fight 1", "fight 2", "fight 3"))
    cur = dict(d, share={"XayaUI_Rules": {"shell": int(w * 0.01 / 5)}}, shareCost={"shell": 5.0}, paceTree=True, _secs=321,
               shareFound={"shell": True, "widget guard": True})
    base_w = 400000.0 * 1350
    base_ok = {"errors": 0, "share": {"XayaUI_Rules": {"shell": int(base_w * 0.012 / 5)}}, "shareCost": {"shell": 5.0}, "_secs": 222, "shareSecs": 111,
               "budget": {s: {"frames": 450, "work": {"XayaUI_Rules": 400000 * 450}} for s in ("fight 1", "fight 2", "fight 3")}}
    if not hasattr(GP, "share_check"):
        check(False, "T10 the gate prints the stand-in's share (gate_performance_run.py share_check)")
        return
    keep_d = d
    try:
        d = cur
        r = judged((base_ok, "played now"), fn=GP.share_check)
        notes = " | ".join(r.notes)
        check("wall-clock" in notes and "321 s" in notes and "stand-in share" in notes and "222" in notes and not r.fails,
              "T10 the stand-in's share is printed for both builds with their wall-clock time (1% and 1.2%: inside 2%, no FAIL)",
              "notes %s; fails %s" % (notes[:500], r.fails))
        base_big = copy.deepcopy(base_ok)
        base_big["share"]["XayaUI_Rules"]["shell"] = int(base_w * 0.05 / 5)
        r = judged((base_big, "played now"), fn=GP.share_check)
        check(any("more than 2%" in f[1] for f in r.fails), "T10 a share that moves the readout by more than 2% FAILs (1% against 5%)",
              "fails %s" % [f[1][:100] for f in r.fails])
        nob = dict(base_ok)
        nob.pop("share")
        r = judged((nob, "played now"), recorded=dict(GP.V33_RECORDED, share=None), fn=GP.share_check)
        check(any("MISSING INPUT" in f[1] for f in r.fails), "T10 no stand-in share for ad60a051 (not played, none stored) FAILs as MISSING INPUT",
              "fails %s" % [f[1][:100] for f in r.fails])
    finally:
        d = keep_d


RAID_LUA = r'''
return function(W, L, G)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.fire("SPELLS_CHANGED"); W.fire("PLAYER_TALENT_UPDATE")
W.tick(0.1, 30)
local ns = rawget(_G, "XayaUI_NS")
local S = W.S
local R = { errorsBefore = #W.errors }
local frames
for i = 1, 60 do local n, v = debug.getupvalue(ns.DisplayFrame, i); if not n then break end; if n == "frames" then frames = v end end
local function shown(name)
  for _, r in ipairs(ns.rules) do if r.name == name then local f = frames and frames[r]; return (f and f:IsVisible()) and true or false end end
  return "no such rule"
end
local function bosses() return { shown("Boss 1"), shown("Boss 2"), shown("Boss 3"), shown("Boss 4") } end
-- a buff display the combat engine owns is drawn by Blizzard's aura container: the engine keeps the buff's aura group on, and the
-- container shows its button while the aura is up (G.syncContainers: the game's secure code)
local function buffUp(id)
  local on, vis = false, false
  for _, e in ipairs(G.buttons) do
    local ids = e.opts.candidateFilters and e.opts.candidateFilters.includeSpellIDs
    if type(ids) == "table" and ids[id] then on = on or e.group.enabled; vis = vis or (rawget(e.button, "_shown") and true or false) end
  end
  return on and vis
end
local payload = G.payload or function(x) return x end
local function aura(unit, info) local p = payload(info); R.lastHidden = S.isHidden(p); W.fire("UNIT_AURA", unit, p) end
local function state()
  return { secret = C_Secrets.ShouldAurasBeSecret(), cdSecret = C_Secrets.ShouldCooldownsBeSecret(), cm = C_RestrictedActions.GetAddOnRestrictionState(2),
    map = C_RestrictedActions.GetAddOnRestrictionState(4), chat = C_RestrictedActions.GetAddOnRestrictionState(5),
    enc = C_InstanceEncounter.IsEncounterInProgress(), lockdown = InCombatLockdown() and true or false,
    read = C_UnitAuras.GetPlayerAuraBySpellID(300037) ~= nil, kind = select(2, IsInInstance()) }
end
-- a raid, between bosses (out of combat): a buff the profile shows (Buff 37: no load condition; its display is the combat engine's)
W.enterInstance("raid", 16, { name = "Gate Raid" }); W.tick(0.1, 10)
local a = G.gain(300037, 120); G.syncContainers(); aura("player", { addedAuras = { a } }); W.tick(0.05, 20)
R.between = state(); R.between.buff = buffUp(300037); R.between.bosses = bosses(); R.between.hidden = R.lastHidden
-- a boss pull in combat (this boss's ID 2001: Boss 1 and 2 name it, Boss 3 and 4 load on any boss)
W.enterCombat(); W.startEncounter(2001, "Raid Boss", 16, 20)
for i = 1, 30 do aura("player", { updatedAuraInstanceIDs = { a.auraInstanceID } }); W.tick(1 / 30, 1) end
R.boss = state(); R.boss.bosses = bosses(); R.boss.hidden = R.lastHidden
-- the kill, combat over: between bosses again
W.endEncounter(1); W.leaveCombat(); W.tick(0.05, 20)
aura("player", { updatedAuraInstanceIDs = { a.auraInstanceID } }); W.tick(0.05, 10)
G.syncContainers(); W.tick(0.05, 2)
R.after = state(); R.after.buff = buffUp(300037); R.after.bosses = bosses(); R.after.hidden = R.lastHidden
-- a boss encounter while out of combat (another boss, 2002)
W.startEncounter(2002, "Raid Boss 2", 16, 20); W.tick(0.05, 20)
aura("player", { updatedAuraInstanceIDs = { a.auraInstanceID } }); W.tick(0.05, 6)
R.ooc = state(); R.ooc.bosses = bosses(); R.ooc.hidden = R.lastHidden
W.endEncounter(0); W.tick(0.05, 10)
W.leaveInstance(); W.tick(0.05, 10)
local rl = {}
for _, e in ipairs(W.restrictionLog or {}) do local k = e[1] .. ":" .. e[2]; rl[k] = (rl[k] or 0) + 1 end
R.restrictions = rl
R.errors = #W.errors
R.errorText = {}
for i = 1, math.min(#W.errors, 5) do R.errorText[i] = tostring(W.errors[i]):sub(1, 300) end
return R
end
'''


def t3_raid():
    t0 = time.time()
    saved, n, made, nf, errs_a = GC.build_profile()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world, loader, game, sv = GC._world(L, saved, debug="off")
    R = H.lua_to_py(L.eval("function(src, W, Ld, G) return loadstring(src)()(W, Ld, G) end")(RAID_LUA, world, loader, game))
    R = json.loads(json.dumps(R, default=str))
    print("      (the raid play took %.0f s; %d rules)" % (time.time() - t0, n))
    b, p, a, o = R.get("between") or {}, R.get("boss") or {}, R.get("after") or {}, R.get("ooc") or {}
    lst = lambda x: GC.vals(x) if hasattr(GC, "vals") else (x or [])   # noqa: E731
    check(int(R.get("errors") or 0) == 0 and not errs_a, "T3 raid: no Lua error in the raid play", "; ".join(lst(R.get("errorText"))))
    check(b.get("kind") == "raid" and str(b.get("map")) == "2" and str(b.get("chat")) == "2" and str(b.get("cm")) == "0" and b.get("secret") is False,
          "T3 raid between bosses: in a raid instance, Map and Chat restrictions on, ChallengeMode off, auras readable", "%s" % b)
    check(b.get("read") is True and b.get("hidden") is False and b.get("buff") is True,
          "T3 raid between bosses: the buff's spell-ID read answers, its payload is readable, and its display shows", "%s" % b)
    check(lst(b.get("bosses")) == [False, False, False, False], "T3 raid between bosses: the boss rules are hidden", "%s" % b.get("bosses"))
    check(p.get("secret") is True and p.get("cdSecret") is True and p.get("enc") is True and p.get("lockdown") is True,
          "T3 raid boss in combat: auras and cooldowns hidden, the encounter in progress, combat lockdown", "%s" % p)
    check(p.get("read") is False and p.get("hidden") is True,
          "T3 raid boss: the spell-ID read gives nil and the UNIT_AURA payload is hidden (shape A)", "%s" % p)
    check(lst(p.get("bosses")) == [True, True, True, True], "T3 raid boss: the boss rules show (Boss 1-2 name boss 2001, Boss 3-4 load on any boss)",
          "%s" % p.get("bosses"))
    check(a.get("secret") is False and a.get("enc") is False and a.get("read") is True and a.get("hidden") is False and a.get("buff") is True,
          "T3 raid after the kill: auras readable again, no encounter, the buff read and shown", "%s" % a)
    check(lst(a.get("bosses")) == [False, False, False, False], "T3 raid after the kill: the boss rules hide again", "%s" % a.get("bosses"))
    check(o.get("secret") is True and o.get("lockdown") is False and o.get("enc") is True and o.get("hidden") is True,
          "T3 raid boss encounter while out of combat: auras hidden although there is no combat lockdown (INFERENCE, RACD:27)", "%s" % o)
    check(lst(o.get("bosses")) == [False, False, True, True], "T3 raid boss 2002 out of combat: only the any-boss rules (Boss 3-4) show", "%s" % o.get("bosses"))
    rl = R.get("restrictions") or {}
    check(all(int(rl.get(k) or 0) > 0 for k in ("0:1", "0:0", "1:1", "1:0", "4:1", "4:0", "5:1", "5:0")) and not rl.get("2:1"),
          "T3 raid: Combat, Encounter, Map and Chat went on and off; ChallengeMode never (no key in a raid)", "%s" % rl)


def draw_play(readable=False, diff_at=None, outkey=True, late_at=None):
    """Draw-play data of the gate's shape (tests/gate_common.py drawCheck: 9 moments x 3 cycles), built here, no Lua: the key fight's
    (readable=False: the 6 absent target debuffs read 0 from "target picked" on, out of combat too, while a target is selected) or the
    readable fight's (readable=True: 6 out of combat, 0 in combat). diff_at: a moment whose read differs from the full re-check by one
    cooldown display, in every cycle (as Cooldown 13 at "group left, target dropped" in the key fight)."""
    target = {"mounted": False, "dismounted": False, "group joined": False, "target picked": True, "combat start": True, "boss pull": True,
              "boss down": True, "combat end": True, "group left, target dropped": False}
    combat = {"combat start", "boss pull", "boss down"}
    out = []
    for cyc in (1, 2, 3):
        for lab in GP.DRAW_LABELS:
            inc = lab in combat
            if readable:
                ab = 0 if inc else 6
            else:
                ab = 6 if not target[lab] else 0
            groups = {"Absent": {"rules": 6, "shown": ab, "alpha": ",".join(["1"] * ab)},
                      "Ooc": {"rules": 6, "shown": 6, "alpha": ",".join(["1" if inc else "0.5"] * 6)},
                      "Boss": {"rules": 4, "shown": 4 if lab == "boss pull" else 0, "alpha": "1,1,1,1" if lab == "boss pull" else ""}}
            diffs = []
            if lab == diff_at:
                diffs = ["91 Cooldown 13: hidden -> after the full re-check: shown, opacity 1, text 8, gray 0, color 1/1/1/1"]
            late = []
            if lab == late_at:
                late = ["91 Cooldown 13: hidden -> after the full re-check: shown, opacity 1, text 8, gray 0, color 1/1/1/1 (its cooldown "
                        "ended 0.0333 s before the read)"]
            out.append({"label": lab, "phase": "busy %d" % cyc, "combat": inc, "ran": True, "n": 348, "ndiff": len(diffs), "diffs": diffs,
                        "groups": groups, "late": late, "nlate": len(late)})
    # (round 11b final fix) the draw play's fight out of the key, on readable data with a target selected (tests/gate_common.py): the
    # absent target debuffs shown with the target picked, not at combat start, shown again at combat end
    if outkey:
        for lab, inc, ab in (("target picked, out of the key", False, 6), ("combat start, out of the key", True, 0),
                             ("combat end, out of the key", False, 6)):
            out.append({"label": lab, "phase": "out of the key", "combat": inc, "ran": True, "n": 348, "ndiff": 0, "diffs": [], "late": [],
                        "nlate": 0, "groups": {"Absent": {"rules": 6, "shown": ab, "alpha": ",".join(["1"] * ab)},
                                               "Ooc": {"rules": 6, "shown": 6, "alpha": ",".join(["1" if inc else "0.5"] * 6)},
                                               "Boss": {"rules": 4, "shown": 0, "alpha": ""}}})
    return {"drawCheck": out, "drawErrors": 0, "paceTree": True}


def t14():
    rep = GC.Report("gate_performance")
    GP.drawn(draw_play(readable=False, diff_at="group left, target dropped"), rep)
    notes = " ".join(rep.notes)
    fails = rep.fails
    cov = [f for f in fails if "the rules that test the narrowed re-check did not change" in f[1]]
    dif = [f for f in fails if f[1].startswith("SD-77: after group left, target dropped")]
    check("with no target selected, out of combat: 6 of 6" in notes and "while a target is selected, out of combat: 0 of 6 (target picked / combat end)"
          in notes and "while a target is selected, in combat: 0 of 6" in notes,
          "T14 key fight: the gate's note says the absent target debuffs show 6 of 6 with no target selected and 0 of 6 while a target is "
          "selected, out of combat (target picked, combat end) and in combat", notes[:700])
    check(not re.search(r"absent target debuffs shown \d+ \(out of combat \d+\)", notes),
          "T14 key fight: the old line 'shown N (out of combat N)', whose second number was the combat-end moment with a target still "
          "selected, is gone", notes[:400])
    # (round 11b final fix) the absent target debuffs change in the draw play's fight out of the key: no FAIL, and the note says so
    check(not cov and "out of the key (readable): target picked [6], combat start [0], combat end [6]" in notes,
          "T14 key fight with the draw play's fight out of the key: the absent target debuffs change there (6 with the target picked, 0 at "
          "combat start, 6 at combat end), so the rules that test the narrowing change at their moments: no FAIL, and the note says it",
          (cov[0][2][:500] if cov else "", notes[:700]))
    rep0 = GC.Report("gate_performance")
    GP.drawn(draw_play(readable=False, outkey=False), rep0)
    cov0 = [f for f in rep0.fails if "the rules that test the narrowed re-check did not change" in f[1]]
    miss0 = [f for f in rep0.fails if "did not run at every moment" in f[1]]
    check(len(cov0) == 1 and "target picked 0 (out of combat, target selected)" in cov0[0][2] and "group left, target dropped 6 (out of combat, "
          "no target)" in cov0[0][2] and "did not run once each" in cov0[0][2] and "the same in cycles 2 and 3" in cov0[0][2] and len(miss0) == 1,
          "T14 key fight WITHOUT the fight out of the key (the round 11b draw play): the FAIL for rules that did not change at their moments is "
          "raised, prints every moment with its combat and target state and says the fight out of the key did not run; the missing moments "
          "FAIL too", (cov0[0][2][:700] if cov0 else rep0.fails))
    rep3 = GC.Report("gate_performance")
    GP.drawn(draw_play(readable=False, late_at="group left, target dropped"), rep3)
    late_note = " ".join(rep3.notes)
    check(not [f for f in rep3.fails if f[1].startswith("SD-77: after")] and "listed, not counted" in late_note and "Cooldown 13" in late_note,
          "T14 a cooldown display whose own end fell in the quiet frames (the late-wake list, gate_common.py KF.lateWake) is printed in a note "
          "every time and is not a FAIL", (rep3.fails, late_note[:400]))
    check(len(dif) == 3 and all("does not tell why" in f[1] and "the narrowed re-check missed a rule" not in f[1] and "SD-60" in f[1]
                                and "display(s) show something other" in f[1] and "one frame later" in f[3] for f in dif),
          "T14 key fight: a display that differs from a full re-check is still a FAIL in each of the 3 cycles, and its words name both "
          "possible causes (a missed rule, SD-77; a hidden cooldown's end woken on the next frame, SD-60) instead of stating one as fact",
          [f[1][:300] for f in dif] or fails)
    rep2 = GC.Report("gate_performance")
    GP.drawn(draw_play(readable=True), rep2)
    notes2 = " ".join(rep2.notes)
    check(not rep2.fails and "while a target is selected, out of combat: 6 of 6 (target picked / combat end)" in notes2
          and "while a target is selected, in combat: 0 of 6" in notes2,
          "T14 readable fight: the same words raise no FAIL and say 6 of 6 while a target is selected out of combat, 0 of 6 in combat (read "
          "from the data, not fixed)", (rep2.fails, notes2[:500]))
    by = GP.draw_group_by_moment(draw_play(readable=False)["drawCheck"][:9] + [dict(c, groups={"Absent": {"rules": 6, "shown": 5}})
                                                                              for c in draw_play(readable=False)["drawCheck"][9:18]], "Absent")
    check("cycle 1: mounted 6" in by and "cycle 2: mounted 5" in by and "the same in" not in by,
          "T14 a cycle that reads differently is printed on its own line, not folded into 'the same in'", by[:400])


ONLY = [x.strip() for x in os.environ.get("XUI_KEYFIGHT_SECTIONS", "").split(",") if x.strip()]


def run_section(name, fn):
    if ONLY and name not in ONLY:
        print("(section %s not run: XUI_KEYFIGHT_SECTIONS=%s)" % (name, ",".join(ONLY)))
        return
    section(name, fn)


run_section("T14", t14)
run_section("T9", t9)
run_section("T12", t12)
run_section("T10", t10)
run_section("T3 raid", t3_raid)
print("UNVERIFIED IN GAME: the stand-in game (tests/harness/world.lua) is a mock; every hidden-data rule it plays that the build spec marks "
      "INFERENCE (payload shape A, the order of the restriction events, an encounter out of combat hiding auras) is unconfirmed in game.")
print("%d checks, %d failed" % (CHECKS[0], len(FAILED)))
sys.exit(1 if FAILED else 0)
