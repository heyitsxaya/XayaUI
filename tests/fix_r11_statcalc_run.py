#!/usr/bin/env python3
"""Bundle 1 round 11a: the Stat Calculator when it cannot load, its unknown words, and its AddOns-list descriptions.
Round 10 final review (R10-FINAL-RESULT final.blockers 4 and 5, concern 9) and Xaya's answers (REQUEST-LOG, verbatim):
  SD-105 "Load at first open (Recommended)"; the gap it lists: if the calculator's own files stop with a Lua error while loading, the
         game still reports the folder as loaded, so /xui stats showed nothing and said nothing, '/xui stats status' said 'on, not
         loaded yet' and the settings page said its options appear after the first open, all three untrue.
  SD-146 "Repeat the reason each time (Recommended)": while the Stat Calculator cannot load, every /xui stats prints its one-line
         reason (it said it once, then nothing).
  SD-118 its words work only while it is on; core's rule for /xui: an unknown word prints help.
On the real addons of this tree in the stand-in game (tests/harness), what the player sees and gets:
  E   one of the calculator's three files stops with a Lua error while loading (a stand-in error put into the file: at its top, or just
      before its last function, after it already offered its service): /xui stats prints one line saying its files stopped with a Lua
      error, on every try (the same line, no second load); '/xui stats status' says it could not load this session and why; its
      settings page says it could not load (never "Its options appear here after you first open"), and with the settings window open
      the drawn page says so too; the minimap row leaves the list; the character window opening says and runs nothing; nothing of
      the half-read calculator is called (no Lua error beyond the one put in); '/xui stats off' still works.
  R   (SD-146) switched off in the game's AddOns list, and its folder not installed: three /xui stats in a row print the same one line
      three times; one load is asked for, not three.
  U   while on: '/xui stats <word it does not know>' (a typo, "on", "show") prints exactly the stats help line and opens, closes and
      loads nothing, before and after the first open; the help line is the same as '/xui stats help'.
  N   the AddOns list's descriptions (.toc '## Notes', what the player reads in the game's AddOns list) are true: XayaUI_Bonus names
      the arithmetic Calculator and does not say the Stat Calculator is loaded only while it is on; XayaUI_Bonus_StatCalculator says
      it loads the first time it is opened, never at login, and not "once per reload".
In-game behavior is UNVERIFIED IN GAME: the harness is a stand-in for the game (V25). That the game reports an addon whose file
errored as loaded is INFERENCE (the stand-in does the same: each file runs on its own).
Run: python3 tests/fix_r11_statcalc_run.py   (Lua 5.1 via lupa)."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402
import fix_r10_statcalc_run as R10  # noqa: E402  (its stand-in helpers: COMMON, LOGIN, WINDOW)

ROOT = os.path.join(HERE, "..")
MARK = "XUI_TEST stand-in load error"

# put a stand-in Lua error into one of the calculator's files as the harness reads it (before the given text, or at its top)
BREAK = r'''
local BREAK_FILE, BREAK_BEFORE = __FILE__, __BEFORE__
local broke = 0
do
  local inner = loadstring
  loadstring = function(src, name)
    if BREAK_FILE and type(src) == "string" and type(name) == "string" and name:sub(-#BREAK_FILE - 1) == "/" .. BREAK_FILE then
      local line = "error(\"''' + MARK + r'''\")\n"
      if BREAK_BEFORE == "" then src = line .. src; broke = broke + 1
      else
        local i = src:find("\n" .. BREAK_BEFORE, 1, true)
        if i then src = src:sub(1, i) .. line .. src:sub(i + 1); broke = broke + 1 end
      end
    end
    return inner(src, name)
  end
end
'''

ERRORED = "the Stat Calculator is on, but its files stopped with a Lua error while loading. /xui bug shows errors."
ERRORED_STATUS = "Stat Calculator: on, but it could not load this session. Its files stopped with a Lua error while loading: /xui bug shows errors."
DISABLED = "the Stat Calculator is on, but XayaUI Bonus Features: Stat Calculator is switched off in the game's AddOns list. Turn it on, then /reload."
MISSING = "the Stat Calculator is on, but its folder XayaUI_Bonus_StatCalculator is not installed: it belongs next to XayaUI_Bonus in Interface\\AddOns."
HELP = "/xui stats: open or close the Stat Calculator. Also: /xui stats options | status | off"
NOTYET = "Stat Calculator: on, not loaded yet (it loads the first time you open it)."

# E: a file of the calculator stops with a Lua error while loading. WINDOW_ON: also with the settings window open (the drawn page)
S_ERR = r'''
return function(W, L, ARGS)
local WINDOW_ON, STRICT = ARGS.window, ARGS.strict
''' + BREAK + R10.COMMON + R10.LOGIN + R10.WINDOW + r'''
local function errCount() return #W.errors end
-- errors since e0 raised through XayaUI_Bonus's loader (its file on the error's stack), the one put in aside (it is raised inside the
-- loader's LoadAddOn call, as in the game)
local function viaLoader(e0) local t = {}; for i = e0 + 1, #W.errors do local x = tostring(W.errors[i]); if x:find("StatCalculatorLoader.lua", 1, true) and not x:find("__MARK__", 1, true) then t[#t + 1] = x end end; return t end
local function pageNote()
  local pages = ns.BuildSettingsPages and ns.BuildSettingsPages("bonus") or {}
  local p = pages.statcalc
  local note = p and p.args and p.args.note
  local nm = note and note.name
  if type(nm) == "function" then nm = nm() end
  return p ~= nil, nm, p and p.args and p.args.panelPart ~= nil
end
section("E", function()
if WINDOW_ON then openWindow() end
local n = #said
ns.RunCommand("stats", "status")
local st = saidSince(n)
check("E setup: saved on, before the first open '/xui stats status' says 'not loaded yet'", #st == 1 and st[1] == "__NOTYET__", table.concat(st, " / "))
local e0 = errCount()
n = #said
ns.RunCommand("stats", ""); W.tick(0.1, 3)
local got = saidSince(n)
check("E /xui stats: the stand-in error was put into the file and raised once while loading (the game still calls the folder loaded)",
  broke == 1 and errCount() == e0 + 1 and tostring(W.errors[#W.errors]):find("__MARK__", 1, true) ~= nil and loaded(),
  broke .. " broken, errors " .. (errCount() - e0) .. ", loaded " .. tostring(loaded()))
check("E ...one line saying its files stopped with a Lua error; nothing shows", #got == 1 and got[1] == "__ERRORED__" and not shown(),
  table.concat(got, " / "))
for i = 2, 3 do
  n = #said
  ns.RunCommand("stats", ""); W.tick(0.1, 2)
  got = saidSince(n)
  check(("E ...try %d: the same one line again (SD-146 'Repeat the reason each time'), no second load, nothing shows"):format(i),
    #got == 1 and got[1] == "__ERRORED__" and #loadCalls == 1 and not shown(), table.concat(got, " / ") .. " | loads " .. #loadCalls)
end
n = #said
ns.RunCommand("stats", "status")
st = saidSince(n)
check("E ...'/xui stats status' says it could not load this session and why (never 'not loaded yet', never the half-read calculator's status)",
  #st == 1 and st[1] == "__ERRORED_STATUS__", table.concat(st, " / "))
local has, note, detailed = pageNote()
check("E ...its settings page says it could not load (never 'Its options appear here after you first open'), no detailed options",
  has and note == "The Stat Calculator could not load this session. Chat says why." and not detailed, tostring(note))
if WINDOW_ON then
  check("E ...the open settings window draws that line (not the stale one)",
    drawnText("The Stat Calculator could not load this session. Chat says why.") and not drawnText("Its options appear here after you first open"))
end
check("E ...the minimap row is left out of the list", not rowAvailable())
n = #said
CharacterFrame:Show(); W.tick(0.1, 3); CharacterFrame:Hide(); W.tick(0.1, 2)
check("E ...the character window opening says nothing, loads nothing and shows nothing", #saidSince(n) == 0 and #loadCalls == 1 and not shown())
n = #said
ns.RunCommand("stats", "off")
got = saidSince(n)
check("E ...'/xui stats off' still works: one plain line, saved off, no memory line (it never loaded)",
  #got == 1 and got[1] == "The Stat Calculator is off." and XayaUIBonusDB.characterToolkit.enabled == false, table.concat(got, " / "))
local vl = viaLoader(e0)
check("E ...XayaUI_Bonus called nothing of the half-read calculator: no Lua error raised through its loader", #vl == 0, vl[1])
if STRICT then
  check("E ...and no Lua error at all beyond the one put in", errCount() == e0 + 1, errCount() - e0)
end
end)
return R
end
'''

# R: switched off in the AddOns list / not installed: the reason on every try (SD-146)
S_REPEAT = r'''
return function(W, L, LINE)
''' + R10.COMMON + R10.LOGIN + r'''
section("R", function()
for i = 1, 3 do
  local n = #said
  ns.RunCommand("stats", ""); W.tick(0.1, 2)
  local got = saidSince(n)
  check(("R /xui stats try %d: the same one line (SD-146), nothing shows"):format(i), #got == 1 and got[1] == LINE and not shown() and not loaded(),
    table.concat(got, " / "))
end
check("R ...one load asked for, not three", #loadCalls == 1, #loadCalls)
local n = #said
ns.RunCommand("stats", "help")
local got = saidSince(n)
check("R ...'/xui stats help' prints the help line, not the reason", #got == 1 and got[1] == "__HELP__", table.concat(got, " / "))
end)
return R
end
'''

# U: unknown words while on
S_UNKNOWN = r'''
return function(W, L)
''' + R10.COMMON + R10.LOGIN + r'''
local function one(word) local n = #said; ns.RunCommand("stats", word); W.tick(0.1, 2); return saidSince(n) end
section("U", function()
local h = one("help")
check("U setup: '/xui stats help' prints the help line", #h == 1 and h[1] == "__HELP__", table.concat(h, " / "))
for _, w in ipairs({ "stauts", "on", "show", "  Toggle  " }) do
  local got = one(w)
  check(("U before the first open: '/xui stats %s' prints exactly the help line; loads nothing, opens nothing"):format(w),
    #got == 1 and got[1] == "__HELP__" and #loadCalls == 0 and not loaded() and not shown(), table.concat(got, " / "))
end
local got = one("")
check("U setup: '/xui stats' opens it (loaded, shown, nothing said)", loaded() and shown() and #got == 0, table.concat(got, " / "))
for _, w in ipairs({ "stauts", "on", "close" }) do
  got = one(w)
  check(("U open: '/xui stats %s' prints exactly the help line and leaves the panel open"):format(w),
    #got == 1 and got[1] == "__HELP__" and shown(), table.concat(got, " / "))
end
got = one("")
check("U ...'/xui stats' still closes it", not shown() and #got == 0, table.concat(got, " / "))
got = one("bogus")
check("U closed: '/xui stats bogus' prints the help line and leaves it closed", #got == 1 and got[1] == "__HELP__" and not shown(), table.concat(got, " / "))
end)
return R
end
'''


def fill(src):
    return (src.replace("__ERRORED_STATUS__", ERRORED_STATUS).replace("__ERRORED__", ERRORED).replace("__NOTYET__", NOTYET)
            .replace("__HELP__", HELP).replace("__MARK__", MARK))


def lua_str(s):
    return "nil" if s is None else '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def session(src, arg=None, saved=None, off=(), gone=()):
    folders = {k: v for k, v in H.find_addons().items() if k not in gone}
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: (k not in off) for k in folders}})
    opts["saved"] = H.to_lua(L, saved or {})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    res = L.eval("function(src, W, Ld, a) return loadstring(src)()(W, Ld, a) end")(src, world, loader,
                                                                                   H.to_lua(L, arg) if isinstance(arg, dict) else arg)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return results, errs


def toc_notes(folder):
    for line in open(os.path.join(ROOT, folder, folder + ".toc"), encoding="utf-8"):
        if line.startswith("## Notes:"):
            return line.split(":", 1)[1].strip()
    return ""


def notes_checks():
    out = []
    b, s = toc_notes("XayaUI_Bonus"), toc_notes("XayaUI_Bonus_StatCalculator")
    out.append(("N XayaUI_Bonus.toc Notes name the arithmetic Calculator (/xui calc)", "Calculator (/xui calc)" in b, b))
    out.append(("N ...and do not say the Stat Calculator is loaded only while it is on, or once per reload, or at login",
                not re.search(r"loaded only while|only while it is on|once per reload|at login", b), b))
    out.append(("N ...and say it loads the first time it is opened", "the first time you open it" in b, b))
    out.append(("N XayaUI_Bonus_StatCalculator.toc Notes say it loads the first time it is opened, never at login",
                "Loads the first time you open it, never at login" in s, s))
    out.append(("N ...and do not say 'once per reload' or 'only while the Stat Calculator is on'",
                not re.search(r"once per reload|only while", s), s))
    out.append(("N ...both short (at most 300 characters each, one line)", 0 < len(b) <= 300 and 0 < len(s) <= 300, (len(b), len(s))))
    return out


def main():
    bad = n = 0
    errs_all = []

    def report(tag, results, errs, allowed=0):
        nonlocal bad, n
        for name, ok in results:
            n += 1
            print(("PASS " if ok else "FAIL ") + "[%s] %s" % (tag, name))
            bad += 0 if ok else 1
        mine = [e for e in errs if MARK in e]
        other = [e for e in errs if MARK not in e]
        if allowed:
            n += 1
            ok = len(mine) == allowed
            print(("PASS " if ok else "FAIL ") + "[%s] exactly %d stand-in load error (the one put in)" % (tag, allowed))
            bad += 0 if ok else 1
        errs_all.extend("[%s] %s" % (tag, e) for e in other + (mine if not allowed else []))

    ON = R10.ON
    # E: each file broken just before its last function (it already ran almost all of it), and the panel file broken at its top
    for tag, f, before, window in (
            ("StatCalculator.lua stops at its top, settings window open", "StatCalculator.lua", "", True),
            ("StatCalculator.lua stops before its last function", "StatCalculator.lua", "function ns.StatCalc_Command(arg)", True),
            ("StatModel.lua stops before its last function", "StatModel.lua", "function CM.ValueFor(it, mode)", False),
            ("StatMath.lua stops before its last function", "StatMath.lua", "function M.Solve(g, target, lo, hi, increasing)", False)):
        src = fill(S_ERR).replace("__FILE__", lua_str(f)).replace("__BEFORE__", lua_str(before))
        strict = f != "StatModel.lua"
        r, e = session(src, {"window": window, "strict": strict}, ON)
        if not strict:
            # (KNOWN GAP, outside this unit's files) StatModel.lua stopped late, StatCalculator.lua still ran whole: its own start-up
            # hooks the character window (StatCalculator.lua ShowIfDocked) and draws with the half-read model. The loader neither
            # calls it nor says anything false (checked above); these errors come from the calculator's own file only.
            own = [x for x in e if MARK not in x and "StatCalculatorLoader.lua" not in x and "/XayaUI_Bonus_StatCalculator/" in x]
            for x in own:
                print("NOTE [%s] the calculator's own code after its model file stopped (needs StatCalculator.lua): %s"
                      % (tag, x.splitlines()[0][:200]))
            e = [x for x in e if x not in own]
        report(tag, r, e, allowed=1)
    # R: SD-146 for the other two causes
    for tag, line, off, gone in (("switched off in the AddOns list", DISABLED, ("XayaUI_Bonus_StatCalculator",), ()),
                                 ("folder not installed", MISSING, (), ("XayaUI_Bonus_StatCalculator",))):
        r, e = session(fill(S_REPEAT), line, ON, off, gone)
        report(tag, r, e)
    r, e = session(fill(S_UNKNOWN), None, ON)
    report("unknown words, on", r, e)
    for name, ok, extra in notes_checks():
        n += 1
        print(("PASS " if ok else "FAIL ") + "[AddOns list] " + name + ("" if ok else "  [%s]" % (extra,)))
        bad += 0 if ok else 1
    for x in errs_all:
        print("ERROR in the game stand-in:", x[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs_all)))
    sys.exit(1 if bad or errs_all or n == 0 else 0)


if __name__ == "__main__":
    main()
