#!/usr/bin/env python3
"""Bundle 1 round 11a: the stand-in game (tests/harness) reads the settings window and enters combat the way the game does, and two
tests no longer end without a result. Round 11 scope items 1, 2 and 8; REQUEST-LOG SD-119 (her real saved settings are run in the
stand-in before landing), SD-138 (every run: a test fails if it checked nothing, if something it needs is missing, or if it prints no
result count; a test that runs too long is HUNG, not passed).

  H  (SD-119, scope item 2) the settings window reads only what the game's window reads (AceConfigDialog-3.0, the copy in
     XayaUI_Options/Libs: CheckOptionHidden first, :1128-1130; a hidden group is never opened, :961/:990/:1017/:1052/:1553; hidden,
     get, set, disabled ... inherited from the groups above, :131-139). Before round 11 the harness called get on options the window
     hides, so her real settings "failed" at XayaUI_Options/RuleEditor/Editor.lua:1727 / :1736 (rule.gameSound is nil exactly when
     those rows are hidden), an error the game cannot raise.
     H1-H2 a real play (XayaUI + Rules + Options) with a rule whose sound cue has no game-played sound: no error, and the
           game-sound rows are counted as hidden; with a game-played sound switched on the rows are shown and read, no error.
     H3-H12 an option table of the test's own, walked by tests/harness/scenario.lua (opts.optionTable): which members the walk reads.
  C  (scope item 1, docs/plans/HIDDEN-DATA-FIGHT-SPEC-2026-11-17.md in XUI-Docs, "Combat order in the existing tests") the fight in a
     play enters combat in the game's order: PLAYER_REGEN_DISABLED is handled while InCombatLockdown() is still false and
     UnitAffectingCombat("player") already true; the lockdown is on during the fight; it is off again before PLAYER_REGEN_ENABLED.
     (warcraft.wiki.gg API_InCombatLockdown: "Combat lockdown begins after the PLAYER_REGEN_DISABLED event fires, and ends before the
     PLAYER_REGEN_ENABLED event fires"; this repository's docs/reference/api lists both events, events.md:1206-1207, but not their
     order. UnitAffectingCombat being true already during PLAYER_REGEN_DISABLED is INFERENCE from the event's meaning.)
     C4 no test in tests/ sets the stand-in's lockdown (W.combat) and then fires PLAYER_REGEN_DISABLED in the same statement.
  D  (test audit 2026-11-17: tests/fix_r10_display_run.py stopped at the suite's 900 s limit with no output, twice) it ends with a
     named FAIL and its count line, never hangs: D1 without the stand-in's API index (an untracked file a fresh clone lacks:
     tests/harness/.gitignore), D2 on addons whose tenths countdown never shows "3.8" (Visual.lua writes whole seconds).
  E  (round 10 final review: tests/fix_r9_gate_scenario_run.py printed nothing inside the suite) stopped from outside (SIGTERM, as a
     time limit does) part-way, it still ends with a named FAIL and its count line on standard output, at once.
Stand-in numbers and behaviour; in-game behaviour is UNVERIFIED IN GAME (V25).
Run: XUI_API_INDEX=tests/harness/api_index.json python3 tests/fix_r11_harness_run.py   (Lua 5.1 via lupa; about 1-2 minutes)"""
import os, re, shutil, signal, subprocess, sys, tempfile, time
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

FAILS, DONE = [], []


def check(name, ok, extra=None):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok or extra is None else "  [%s]" % str(extra)[:600]))
    DONE.append(name)
    if not ok:
        FAILS.append(name)


def play(enabled, saved, option_table_src=None, probe=False):
    """One play session of tests/harness/scenario.lua on this tree's addons (as tests/harness/run.py session()), keeping the scenario's
    own result S and the world W. option_table_src: Lua source of a function returning an option table the walk reads instead of the
    settings window's own (scenario.lua opts.optionTable). probe: a frame made before the addons load records, at each
    PLAYER_REGEN_DISABLED / ENABLED and each UNIT_ / SPELL_ event, what InCombatLockdown() and UnitAffectingCombat("player") answer."""
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    W = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    if probe:
        L.execute(r'''
PROBE = {}
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED"); f:RegisterEvent("PLAYER_REGEN_ENABLED"); f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
f:SetScript("OnEvent", function(_, ev)
  PROBE[#PROBE + 1] = { ev = ev, lock = InCombatLockdown() and true or false, affecting = UnitAffectingCombat("player") and true or false }
end)''')
    o = H.to_lua(L, {"folders": H.find_addons(), "enabled": {k: True for k in enabled}})
    o["saved"] = H.to_lua(L, saved or {})
    ld = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), W, o)
    so = H.to_lua(L, {"writeBack": True})
    if option_table_src:
        so["optionTable"] = L.execute(option_table_src)
    S = L.eval("function(path, W, Ld, o) return dofile(path)(W, Ld, o) end")(os.path.join(H.HERE, "scenario.lua"), W, ld, so)
    return L, W, S


def errors(W):
    return [W.errors[i] for i in range(1, len(W.errors) + 1)]


def hidden_keys(S):
    """The option keys the walk found hidden (scenario.lua S.optionHiddenKeys); None when the scenario keeps no such record."""
    hk = S.optionHiddenKeys
    return None if hk is None else {k: (v[1], v[2]) for k, v in hk.items()}


# a rule and its sound cue (a cue is edited inside its rule's Cues tab; its sound rows are Editor.lua's xuiParts.soundBody, keys snd_*)
PARENT = {"name": "XUI test parent", "enabled": True, "uid": "r11p", "spellID": 100001, "load": {"mode": "always"}}
CUE = {"name": "XUI test sound cue", "enabled": True, "uid": "r11c", "isCue": True, "cueKind": "sound", "parentUid": "r11p",
       "sound": {"enabled": True, "source": "kit", "value": "8959", "channel": "Master"}}
GAME_SOUND_ROWS = ("snd_gameSoundWhen", "snd_gameSoundChannel", "snd_gameSoundThrottle", "snd_gameSoundAlso")


def part_h():
    on = ("XayaUI", "XayaUI_Rules", "XayaUI_Options")
    # H1 a sound cue with no game-played sound: the rows that read rule.gameSound are hidden by the window, never read
    L, W, S = play(on, {"XayaUI": {"CueRulesDB": {"version": 1, "rules": [dict(PARENT), dict(CUE)]}}})
    errs = errors(W)
    gs = [e.split("\n")[0] for e in errs if "gameSound" in e]
    check("H1 a sound cue with no game-played sound: opening the settings window and reading every option raises no error about "
          "rule.gameSound (before round 11: Editor.lua:1727 / :1736, as on her real settings; the game's window never reads the rows "
          "it hides)", not gs, gs[:2])
    check("H1 ... and no other error", not errs, errs[:2])
    he = [S.hiddenErrors[i].split("\n")[0] for i in range(1, len(S.hiddenErrors) + 1)] if S.hiddenErrors else []
    check("H1 ... nor an error in an option the window hides (the hidden rows' get is never called, not even in the shadow)",
          S.hiddenErrors is not None and not any("gameSound" in e for e in he), he[:2] if S.hiddenErrors is not None else "no record kept")
    hk = hidden_keys(S)
    rows = [k for k in GAME_SOUND_ROWS if hk and k in hk]
    check("H1 ... its four game-sound rows were found hidden, so their values were not read (scenario.lua S.optionHiddenKeys)",
          len(rows) == 4, "hidden: %s" % (sorted(k for k in hk if "ound" in k) if hk is not None else "no record kept"))
    check("H1 ... the walk still read the options the window shows (values read: %s)" % S.optionGets, (S.optionGets or 0) > 50)
    # H2 the same cue with the game-played sound switched on: the rows are shown and read
    c = dict(CUE, gameSound={"enabled": True, "when": "auto", "channel": "Ambience", "throttle": 1})
    L, W, S = play(on, {"XayaUI": {"CueRulesDB": {"version": 1, "rules": [dict(PARENT), c]}}})
    errs = errors(W)
    hk = hidden_keys(S)
    check("H2 the game-played sound switched on: no error, and the game-sound rows are shown (not counted hidden)",
          not errs and hk is not None and not any(k in hk for k in GAME_SOUND_ROWS), (errs[:2], sorted(k for k in (hk or {}) if "ound" in k)))

    # H3-H12 the walk on an option table of the test's own: what it reads, in AceConfigDialog's order
    src = r'''
LOG = {}
local function log(s) LOG[s] = (LOG[s] or 0) + 1 end
local function rec(tag, v) return function(info, ...) log(tag); return v end end
local H = { IsHidden = function(self, info) log("meth.hidden"); return true end,
            GetIt = function(self, info) log("meth.get"); return true end,
            GetIt2 = function(self, info) log(self == HANDLER and "meth2.get.self" or "meth2.get.noself"); return true end }
HANDLER = H
return { type = "group", name = "root", handler = H, args = {
  shown = { type = "toggle", name = rec("shown.name", "Shown"), desc = rec("shown.desc", "d"), get = rec("shown.get", true),
            set = rec("shown.set") },
  hid = { type = "toggle", order = rec("hid.order", 1), name = rec("hid.name", "Hid"), hidden = rec("hid.hidden", true),
          desc = rec("hid.desc", "d"), disabled = rec("hid.disabled", false),
          get = function() log("hid.get"); error("XUI_TEST get on a hidden option") end, set = rec("hid.set") },
  dlg = { type = "toggle", name = "Dlg", dialogHidden = true, hidden = rec("dlg.hidden", false), get = rec("dlg.get", true) },
  dlgShown = { type = "toggle", name = "DlgShown", dialogHidden = false, hidden = rec("dlgShown.hidden", true),
               get = rec("dlgShown.get", true) },
  grp = { type = "group", name = "Grp", hidden = function(info) log("grp.hidden:" .. tostring(info[#info])); return true end, args = {
          child = { type = "toggle", name = rec("child.name", "Child"), hidden = false, get = rec("child.get", true),
                    desc = function() log("child.desc"); error("XUI_TEST error inside a hidden group") end } } },
  grp2 = { type = "group", name = "Grp2", hidden = function(info) log("grp2.hidden:" .. tostring(info[#info])); return info[#info] == "secret" end,
           get = rec("grp2.inheritedGet", true), set = rec("grp2.inheritedSet"), args = {
          open = { type = "toggle", name = "Open" },
          secret = { type = "toggle", name = "Secret" } } },
  meth = { type = "toggle", name = "Meth", hidden = "IsHidden", get = "GetIt" },
  meth2 = { type = "toggle", name = "Meth2", get = "GetIt2" },
} }'''
    L, W, S = play(("XayaUI",), {}, option_table_src=src)
    log = dict(L.eval("LOG").items()) if L.eval("LOG") else {}
    hidden_errs = [S.hiddenErrors[i] for i in range(1, len(S.hiddenErrors) + 1)] if S.hiddenErrors else []
    n = lambda k: int(log.get(k, 0))  # noqa: E731
    check("H3 a shown option: its get is read and its value written back (as a click would)", n("shown.get") >= 1 and n("shown.set") >= 1, log)
    check("H4 a hidden option: hidden is asked, its order and name are read (the window sorts and names every option), its get and set "
          "never", n("hid.hidden") >= 1 and n("hid.order") >= 1 and n("hid.name") >= 1 and n("hid.get") == 0 and n("hid.set") == 0, log)
    check("H5 dialogHidden = true wins over hidden (pickfirstset): hidden is not even asked, get never read",
          n("dlg.hidden") == 0 and n("dlg.get") == 0, log)
    check("H6 dialogHidden = false wins over a hidden() that says true: the option is shown and its get read",
          n("dlgShown.hidden") == 0 and n("dlgShown.get") >= 1, log)
    check("H7 a hidden group: nothing inside it has its get read", n("child.get") == 0 and n("grp.hidden:grp") >= 1, log)
    check("H8 an error inside a hidden group is not a FAIL of the play (the game cannot raise it) but is kept as a hidden-option error",
          not any("XUI_TEST" in e for e in errors(W)) and any("error inside a hidden group" in e for e in hidden_errs),
          (errors(W)[:2], hidden_errs[:2]))
    check("H9 hidden is inherited from the group above and asked with each option's own path: 'open' is shown and reads the group's "
          "get, 'secret' is hidden", n("grp2.hidden:open") >= 1 and n("grp2.hidden:secret") >= 1 and n("grp2.inheritedGet") == 1, log)
    check("H10 a hidden given as a method name is called on the handler, and then get is not read", n("meth.hidden") >= 1 and n("meth.get") == 0, log)
    check("H11 a get given as a method name is called on the nearest handler, with the handler as self", n("meth2.get.self") >= 1, log)
    check("H12 the play itself raised no error", not errors(W), errors(W)[:2])


def part_c():
    L, W, S = play(("XayaUI", "XayaUI_Rules"), {}, probe=True)
    P = L.eval("PROBE")
    rows = [dict(P[i].items()) for i in range(1, len(P) + 1)] if P else []
    dis = [r for r in rows if r["ev"] == "PLAYER_REGEN_DISABLED"]
    ena = [r for r in rows if r["ev"] == "PLAYER_REGEN_ENABLED"]
    check("C1 the play's fight: while PLAYER_REGEN_DISABLED is handled, InCombatLockdown() is false and UnitAffectingCombat('player') "
          "true", len(dis) == 1 and not dis[0]["lock"] and dis[0]["affecting"], dis)
    i_dis = rows.index(dis[0]) if dis else 0
    i_ena = rows.index(ena[0]) if ena else len(rows)
    mid = [r for r in rows[i_dis + 1:i_ena] if r["ev"] in ("UNIT_AURA", "SPELL_UPDATE_COOLDOWN")]
    check("C2 during the fight (its unit and spell events), the lockdown is on", bool(mid) and all(r["lock"] and r["affecting"] for r in mid),
          "%d events, %s" % (len(mid), mid[:2]))
    check("C3 while PLAYER_REGEN_ENABLED is handled, the lockdown is already off", len(ena) == 1 and not ena[0]["lock"], ena)
    check("C3 ... and the play raised no error", not errors(W), errors(W)[:2])
    # C4 no test sets the stand-in's lockdown and then fires PLAYER_REGEN_DISABLED (the order before round 11)
    pat = re.compile(r"W\.combat\s*=\s*(?:true|on)\s*;?\s*W\.fire\(\s*(?:on and\s*)?[\"']PLAYER_REGEN_DISABLED")   # (\s spans lines)
    bad = []
    for dp, dn, fs in os.walk(HERE):
        dn[:] = [d for d in dn if d != "__pycache__"]
        for fn in fs:
            if fn.endswith((".py", ".lua")) and fn != os.path.basename(__file__):
                p = os.path.join(dp, fn)
                text = open(p, encoding="utf-8", errors="replace").read()
                for m in pat.finditer(text):
                    bad.append("%s:%d" % (os.path.relpath(p, ROOT), text.count("\n", 0, m.start()) + 1))
    check("C4 no test in tests/ sets the stand-in's lockdown (W.combat) before firing PLAYER_REGEN_DISABLED", not bad, bad)


def tree_copy(edit=None):
    """This tree's addon folders and tests/ in a temp folder of this run (removed by the caller), with an optional edit."""
    dest = tempfile.mkdtemp(prefix="xui_r11_harness-")
    for name in sorted(os.listdir(ROOT)):
        src = os.path.join(ROOT, name)
        if name.startswith("XayaUI") and os.path.isdir(src):
            shutil.copytree(src, os.path.join(dest, name), ignore=shutil.ignore_patterns("Media", "__pycache__"))
    shutil.copytree(HERE, os.path.join(dest, "tests"), ignore=shutil.ignore_patterns("__pycache__", "reports", "api_index.json",
                                                                                       "framexml_index.json"))
    if edit:
        edit(dest)
    return dest


def run_test(tree, name, env_extra, limit):
    env = dict(os.environ, **env_extra)
    t0 = time.time()
    try:
        r = subprocess.run([sys.executable, os.path.join(tree, "tests", name)], capture_output=True, text=True, cwd=tree, env=env,
                           timeout=limit)
        return r.returncode, r.stdout, time.time() - t0
    except subprocess.TimeoutExpired as e:
        out = e.stdout.decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
        return None, out, time.time() - t0


COUNT = re.compile(r"^(\d+) checks, (\d+) failed$")


def part_d():
    api = os.path.abspath(os.environ.get("XUI_API_INDEX", os.path.join(H.HERE, "api_index.json")))
    tree = tree_copy()
    try:
        rc, out, secs = run_test(tree, "fix_r10_display_run.py", {"XUI_API_INDEX": os.path.join(tree, "no-such-index.json")}, 120)
        last = (out.strip().splitlines() or [""])[-1]
        check("D1 fix_r10_display without the stand-in's API index ends at once (%.0f s, limit 120) with exit code 1, a FAIL naming the "
              "missing index, and its count line" % secs,
              rc == 1 and COUNT.match(last) is not None and int(COUNT.match(last).group(2)) >= 1 and "API index" in out,
              "exit %s, last line %r" % (rc, last))
    finally:
        shutil.rmtree(tree, ignore_errors=True)

    def whole_seconds(d):   # the tenths countdown writes whole seconds: "3.8" never shows
        p = os.path.join(d, "XayaUI_Rules", "Visual.lua")
        s = open(p, encoding="utf-8").read()
        old = 's = ("%.1f"):format((k + 1) / 10)'
        if s.count(old) != 1:
            raise RuntimeError("Visual.lua's tenths text line not found (the test needs updating): " + old)
        open(p, "w", encoding="utf-8").write(s.replace(old, 's = ("%.0f"):format((k + 1) / 10)'))
    try:
        tree = tree_copy(whole_seconds)
    except RuntimeError as e:
        check("D2 (setup) the tenths countdown can be broken on purpose", False, e)
        return
    try:
        rc, out, secs = run_test(tree, "fix_r10_display_run.py", {"XUI_API_INDEX": api}, 300)
        last = (out.strip().splitlines() or [""])[-1]
        check("D2 fix_r10_display on addons whose countdown never shows 3.8 ends (%.0f s, limit 300) with a FAIL saying so and its count "
              "line, exit code 1" % secs,
              rc == 1 and COUNT.match(last) is not None and int(COUNT.match(last).group(2)) >= 1 and "reaches 3.8" in out,
              "exit %s, last line %r" % (rc, last))
    finally:
        shutil.rmtree(tree, ignore_errors=True)


def part_e():
    env = dict(os.environ)
    p = subprocess.Popen([sys.executable, os.path.join(HERE, "fix_r9_gate_scenario_run.py")], stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, text=True, cwd=ROOT, env=env)
    time.sleep(8)
    t0 = time.time()
    p.send_signal(signal.SIGTERM)
    try:
        out, err = p.communicate(timeout=60)
    except subprocess.TimeoutExpired:
        p.kill()
        out, err = p.communicate()
    secs = time.time() - t0
    lines = out.strip().splitlines()
    last = (lines or [""])[-1]
    m = COUNT.match(last)
    check("E1 fix_r9_gate_scenario stopped from outside after 8 s (SIGTERM): it ends within 30 s (%.1f s) with a named FAIL and its "
          "count line as the last line of its standard output, exit code not 0" % secs,
          secs < 30 and p.returncode not in (0, None) and m is not None and int(m.group(2)) >= 1
          and any(l.startswith("FAIL the test ran to its end") for l in lines),
          "exit %s, %d lines, last %r, stderr %r" % (p.returncode, len(lines), last, err.strip()[-200:]))


def main():
    sys.stdout.reconfigure(line_buffering=True)
    if not H.load_api().get("functions"):   # (SD-138 M1: something it needs is missing, and it says what)
        check("the stand-in's API index is there (python3 tests/harness/api_index_from_docs.py, or XUI_API_INDEX)", False)
        print("%d checks, %d failed" % (len(DONE), len(FAILS)))
        return 1
    for part in (part_h, part_c, part_d, part_e):
        try:
            part()
        except Exception as e:  # noqa: BLE001  (a part that stops is a named FAIL, the others still run)
            check("%s ran to its end" % part.__name__, False, "%s: %s" % (type(e).__name__, e))
    if not DONE:
        check("the test checked something", False)
    print("%d checks, %d failed" % (len(DONE), len(FAILS)))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
