#!/usr/bin/env python3
"""Bundle 1 round 11: the Stat Calculator when it cannot load, its unknown words, and its AddOns-list descriptions.
Round 10 final review (R10-FINAL-RESULT final.blockers 4 and 5, concern 9), the round 11a final review (R11A-RESULT final.blockers 3,
its concerns on the loader's lines, the error record's codes and the mutation survivors) and Xaya's answers (REQUEST-LOG, verbatim):
  SD-105 "Load at first open (Recommended)"; the gap it lists: if the calculator's own files stop with a Lua error while loading, the
         game still reports the folder as loaded, so /xui stats showed nothing and said nothing, '/xui stats status' said 'on, not
         loaded yet' and the settings page said its options appear after the first open, all three untrue.
  SD-146 "Repeat the reason each time (Recommended)": while the Stat Calculator cannot load, every /xui stats prints its one-line
         reason (it said it once, then nothing).
  SD-118 its words work only while it is on; core's rule for /xui: an unknown word prints help.
  SD-139 "Prints should be sent to chat but also sent directly to an error tracking file": a chat line that reports an error is saved
         in XayaUI's error record (CueRulesDB.errorLog) with its code and a repeat count.
On the real addons of this tree in the stand-in game (tests/harness), what the player sees and gets:
  E   one of the calculator's three files stops with a Lua error while loading (a stand-in error put into the file: at its top, in its
      middle, just before its start-up or its last function; once as an error that names no file, error(msg, 0)): /xui stats prints
      one line saying its files stopped with a Lua error, on every try (the same line, no second load); '/xui stats status' says it
      could not load this session and why; its settings page says it could not load (never "Its options appear here after you first
      open"), and with the settings window open the drawn page says so too; the minimap row leaves the list; the character window
      opening says and runs nothing; nothing of the half-read calculator is called (no Lua error beyond the one put in); '/xui stats
      off' still works. The error still reaches the error handler that was active (the one put in is recorded once, as itself), that
      handler is active again after the load.
      (round 11 repair, the stand-down) StatCalculator.lua does nothing when an earlier file stopped: a probe put on StatCalculator.lua's
      first line (it shifts no line number and survives any edit of the file) shows that when the game began reading it, the model was
      not whole (no "statModel" service) and, with the error watch on, the loader had already seen the error (FilesErrored); then none
      of its functions or settings exist, it offers no service, makes no frame and no hook. (This replaces repair 1's probe, which sat
      in front of the start-up's own text, SEEN_AT: once the file stands down at its top that line is never reached, so the probe moved
      to the first line and proves the same thing earlier, plus the stand-down itself.) A stop in StatMath.lua makes StatModel.lua stand
      down too. A stop inside StatCalculator.lua leaves its services unoffered (a half-read calculator offers nothing).
      (round 11 repair 2) StatCalculator.lua itself reports an error while it is read and goes on to its end (a helper run under
      xpcall): the loader counts it as not loaded, and its start-up must not run either: no frame, no hook on the character window, no
      service (its second stand-down reading, LoadBroken, just before the start-up; before repair 2 it made its event frame and a
      second hook on the character window for a calculator nothing calls).
      (round 11 repair, the record, SD-139) the error put in is saved once under the Stat Calculator's code XUI-E009, never core's
      XUI-E001, however the error names its file (its own file, no file with the stack inside the message, no file reported where it
      was raised, a SharedXML helper's file, a shortened file name); the chat reason is saved as an XUI-E009 error, one entry counted
      each time it was told (3 tries and the status line: 4); nothing else is saved.
      (round 11 repair 2, the claim's safety: R11A repair-1 review blocker) after the failed load, an unrelated XayaUI Lua error (core's
      own file, "Interface/AddOns/XayaUI/Core.lua:5: XUI_TEST unrelated later error [case k]", raised through the active error handler as
      the game reports one) is still saved, once, under its own code XUI-E001, and reaches the earlier handler: the message the loader
      filed and claimed (XayaUI/DebugRecord.lua ns.RecordLoadError) never makes core's record skip a different error. This matters most
      where core's handler did not record the claimed message at all (a shortened file name, a SharedXML helper's file), which leaves
      the claim open after the load.
      (round 11 repair, no watch) with the error handler held by another addon (seterrorhandler does nothing), a stop late in
      StatModel.lua, in StatMath.lua, in the middle of StatCalculator.lua or before its last function is still found (the end-of-file
      marks) and everything above holds, except that the error put in is filed only by core's own handler: it must then never be filed
      under another code than XUI-E009, and it is filed exactly once there, a shortened file name included (round 11a final fix: core's
      ns.ErrorFolder reads a name Lua shortened, "...ddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua"; before it, the two
      StatCalculator.lua cases were filed nowhere and printed a NOTE).
      Also with debugstack raising (a client without it): the error is still counted, filed and passed on.
  B   (round 11 repair, SD-138 (b) survivor "FromPart without pcall") an error object whose text cannot be read (its __tostring raises)
      is raised in StatMath.lua while loading: the earlier handler still receives it, the calculator says it could not load, nothing
      else is said or raised.
  W   a healthy calculator while another addon's code raises a Lua error during the same load (its ADDON_LOADED handler): that error is
      not the calculator's; it opens and shows, the error reaches the earlier handler, that handler is active again, and nothing is saved
      in XayaUI's record. (round 11 repair, SD-138 (b) survivor "PART_IN_PATH without its brackets") also from a folder whose name ends
      with the calculator's folder name (Old_XayaUI_Bonus_StatCalculator/) and from a file whose name starts with it
      (OtherAddon/XayaUI_Bonus_StatCalculatorSkin.lua).
  H   a healthy calculator while another addon replaces the error handler during the same load (chaining the one it found): the other
      addon's handler is still the active one after the load, and a Lua error a calculator file raises later in play reaches it and
      the earlier handler but is not a load error (still loaded, FilesErrored() false, /xui stats still works); it is saved once under
      XUI-E009 by core's handler, and so is one that names the file as Lua 5.1 writes it, shortened ("...ddOns/XayaUI_Bonus_
      StatCalculator/StatCalculator.lua:20: ...", round 11a final fix).
  R   (SD-146) switched off in the game's AddOns list, and its folder not installed: three /xui stats in a row print the same one line
      three times; one load is asked for, not three; these two reasons are the player's own setup, ordinary messages: nothing is saved.
  U   while on: '/xui stats <word it does not know>' (a typo, "on", "show") prints exactly the stats help line and opens, closes and
      loads nothing, before and after the first open; the help line is the same as '/xui stats help'.
  N   the AddOns list's descriptions (.toc '## Notes', what the player reads in the game's AddOns list) are true.
  F   (round 11 repair) the end-of-file marks the loader and the stand-downs read: XayaUI_Bonus_StatCalculator.toc reads StatMath.lua,
      StatModel.lua, StatCalculator.lua in that order (each stand-down reads the file before it); each file's last statement is its
      Provide of its service, and that service is offered nowhere else; the loader reads exactly those three marks.
Error record and the honest-result guard (tests/run_all.py): every session runs with its own clock offset (time() shifted by whole days)
so its record entries keep apart from another session's equal entries; the test reads each session's record, checks it, and declares
on its last lines, as EXPECT_ERRORS XUI-E009 <n>, the XUI-E009 entries it causes on purpose and checks: the error put into a file (its
message carries its own case mark, "XUI_TEST stand-in load error [case k]"; the lines that raise it are BREAK_LINES below), the chat
reason it typed /xui stats and status for, and H's later error ("...StatCalculator.lua:10: XUI_TEST stand-in load error [H]", raised
by the test's own geterrorhandler()(...) call). It also declares, as EXPECT_ERRORS XUI-E001 <n>, the one unrelated later error of each
E case, caused on purpose by the S_ERR line 'geterrorhandler()("__UNRELATED__")' (the message "Interface/AddOns/XayaUI/Core.lua:5:
XUI_TEST unrelated later error [case k]": core's file, so core's code XUI-E001) and checked there. Any other entry is left undeclared,
so the guard fails on it. (round 11 repair 2, R11A repair-1 review blocker) Both numbers are FIXED by the cases, never summed from the
record the guard compares them with: XUI-E001 is one per E case (len(cases)); XUI-E009 is, per E case, OWN (the error(s) put in: 1, or
2 in the two-errors case; with nothing watched also 1, filed by core's handler, see OWN in main) plus
4 (the chat reason told 3 times and by the status line), plus B's reason told once and H's one later error. Until repair 2 they were
summed from the record's own marked entries, so an entry a break dropped also dropped out of the declaration and the guard never saw
it: the named check was the only catch (proved: the reviewer's break below, with the named check taken out, passed the guard).
SD-138 (b) survivor notes (the round 11a reviewer's survivors with no written note):
  * debugstack's arguments in the loader (debugstack(1, 20, 0)): NOT CATCHABLE HERE, a known survivor (repair 2 ran it: (2, 5, 0)
    passes every check). The stand-in's debugstack ignores its arguments (tests/harness/world.lua: 'debugstack = function() return
    debug.traceback("", 2) end'), and what they mean is not in docs/reference/api, so a stand-in that honors them would invent API
    facts (V2). A change there (fewer lines, another start) can only be seen in game. Harm if it were wrong in game: the watch would
    miss a calculator file on the stack only for an error whose message names no calculator file; the end-of-file marks still find a
    stop, so the calculator still says it could not load; only the record's code for that one error could fall back to core's reading.
    UNVERIFIED IN GAME.
  * PART_IN_PATH without its brackets: caught by the two W cases above (a check fails: the calculator would be called not loaded).
  * FromPart without pcall: caught by B (the earlier handler would never receive the error). debugstack without pcall: caught by the
    E case with a raising debugstack (the record and the handler checks fail).
  * watch.saw never reset: the reset was dead code (ReadFiles runs once per session, after Load set loadTried; watch.saw starts false)
    and is removed, so there is nothing left to break.
  This unit's own breaks (scratchpad r11r_statcalc_mut.py, 27 breaks of the changed lines; 26 caught by named checks here):
  * (round 11 repair 2) the reviewer's break "skip the next Lua-error record whatever it is" (DebugRecord.lua ns.RecordError:
    'if c ~= nil then return ce end', the text comparison dropped): CAUGHT by the E check "an unrelated XayaUI Lua error raised after
    the failed load is still saved, once, under its own code XUI-E001" (it fails in each case where core's handler left the claim open:
    every StatCalculator.lua case, the SharedXML-helper cases, the gamecontinue case and the raising-debugstack case), and (repair 2)
    by the guard on its own too: "M1 ERROR RECORD: XUI-E001 x9, declared 19", also with that named check taken out.
  * (round 11 repair 2) StatCalculator.lua's second stand-down reading (LoadBroken just before its start-up) removed, LoadBroken
    without its FilesErrored test, LoadBroken without its "statModel" test, the top stand-down removed: each CAUGHT by named E checks
    (2, 4, 3 and 11 failed). The loader filing nothing (RecordLoadError call dropped): CAUGHT by named checks and by the guard on both
    codes. The nohandler StatCalculator.lua OWN changed from 0 to 1: CAUGHT (2 failed, and the guard).
  * survivor "the claim is kept until it matches" (XayaUI/DebugRecord.lua ns.RecordError clears the claim at the next Lua-error record,
    match or not; the break clears it only on a match): NOT CATCHABLE, HARMLESS: the two behave the same in every case that can happen.
    The two differ only when a later record carries the very same text as a claim that core's handler did not consume. Core decides
    from the message's own file when it names one (the same text, the same answer: it does not record that text later either), and from
    the stack only for a message with no file of its own, which is the calculator's error text and is not raised again in the same
    session (the load is tried once, SD-146). The unrelated-later-error check above shows a different text is never skipped under
    either rule. Kept as written because a claim that lasts for one record only is the simpler rule to read.
  * caught after a new case was added for it: "the watch counts only the first error" (the two-errors-in-one-load case).
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
CALC = "XayaUI_Bonus_StatCalculator"

# each session's clock offset (whole days) and its record helpers; first in every scenario, before anything can be saved
PRE = r'''
do local t0 = time; local shift = __SHIFT__; time = function() return t0() + shift end end
local function record()
  local db = rawget(_G, "CueRulesDB")
  local log = type(db) == "table" and rawget(db, "errorLog") or nil
  local t = {}
  if type(log) == "table" then for _, e in ipairs(log) do if type(e) == "table" then t[#t + 1] = e end end end
  return t
end
local function entriesWith(sub) local t = {}; for _, e in ipairs(record()) do if tostring(e.msg):find(sub, 1, true) then t[#t + 1] = e end end; return t end
local function entriesEqual(text) local t = {}; for _, e in ipairs(record()) do if e.msg == text then t[#t + 1] = e end end; return t end
local function dumpRecord()
  local t = {}
  for _, e in ipairs(record()) do t[#t + 1] = tostring(e.code) .. " x" .. tostring(e.n) .. " " .. tostring(e.msg):sub(1, 90) end
  return #t .. " entries: " .. table.concat(t, " || ")
end
'''

# put a stand-in Lua error into one of the calculator's files as the harness reads it (before the given text, or at its top), and a
# probe on StatCalculator.lua's first line
BREAK = r'''
local BREAK_FILE, BREAK_BEFORE, BREAK_KIND = __FILE__, __BEFORE__, __KIND__
-- (round 11 repair) an optional second error in the same load, in another file (its message carries the case mark too, then " 2")
local BREAK2_FILE, BREAK2_BEFORE, BREAK2_KIND = __FILE2__, __BEFORE2__, __KIND2__
local broke = 0
-- how the stand-in error is raised in the file (each message carries this case's own mark, __CMARK__):
--   plain   error(msg): the message names the file it was raised in
--   level0  error(msg, 0): no location; the stand-in game appends the stack to the message (tests/harness/world.lua safecall)
--   game0   no location, reported the way the game reports it (INFERENCE): the active error handler is called where the error was raised
--           (xpcall with that handler), so only the stack at that moment (debugstack) names the calculator's file; the file then stops
--   helper  a helper the file calls at load raises it (a stand-in named Interface/SharedXML/Mixin.lua): the message names the helper's
--           file, never the calculator's (the stand-in appends the stack)
--   gamehelper  the same helper, reported the way the game reports it: only debugstack names the calculator's file; the file stops
--   gamecontinue  the same, but the file goes on after the error was reported (it ran its helper under xpcall): the file ENDS, so only
--           the error watch (FilesErrored) can tell StatCalculator.lua's stand-down; the loader counts it as not loaded (errs safe)
--   badobj  an error object (a table) whose text cannot be read (its __tostring raises), reported the way the game reports it
local CMARK = "__CMARK__"
local HELPER = "loadstring(\"error('__CMARK__')\", \"@Interface/SharedXML/Mixin.lua\")"
local BREAK_LINES = {
  plain = "error(\"__CMARK__\")\n",
  level0 = "error(\"__CMARK__\", 0)\n",
  game0 = "xpcall(function() error(\"__CMARK__\", 0) end, geterrorhandler()) do return end\n",
  helper = HELPER .. "()\n",
  gamehelper = "xpcall(" .. HELPER .. ", geterrorhandler()) do return end\n",
  gamecontinue = "xpcall(" .. HELPER .. ", geterrorhandler())\n",
  badobj = "xpcall(function() error(setmetatable({ xuiTestObject = true }, { __tostring = function() error('unreadable') end })) end, geterrorhandler()) do return end\n",
}
-- (round 11 repair) the probe: what StatCalculator.lua's stand-down can read when the game begins the file. Put on the file's first
-- line, in front of everything (so no line number moves, and no edit of the file can leave it out): FilesErrored (the loader's watch),
-- whether the "statModel" and "statMath" services (the end-of-file marks of the two files before it) are there.
local PROBE = "do local N = rawget(_G, 'XayaUI_NS'); local L = N and N.StatCalcLoader; rawset(_G, 'XUI_TEST_SEEN', { errored = (L and L.FilesErrored and L.FilesErrored()) and true or false, model = (N and N.Service and N.Service('statModel')) ~= nil, math = (N and N.Service and N.Service('statMath')) ~= nil }) end "
do
  local inner = loadstring
  local function put(src, name, file, before, kind, suffix)
    if file and type(src) == "string" and type(name) == "string" and name:sub(-#file - 1) == "/" .. file then
      local line = BREAK_LINES[kind]
      local i, j = line:find(CMARK, 1, true)
      if i and suffix ~= "" then line = line:sub(1, j) .. suffix .. line:sub(j + 1) end
      if before == "" then src = line .. src; broke = broke + 1
      else
        local i = src:find("\n" .. before, 1, true)
        if i then src = src:sub(1, i) .. line .. src:sub(i + 1); broke = broke + 1 end
      end
    end
    return src
  end
  loadstring = function(src, name)
    src = put(src, name, BREAK_FILE, BREAK_BEFORE, BREAK_KIND, "")
    src = put(src, name, BREAK2_FILE, BREAK2_BEFORE, BREAK2_KIND, " 2")
    if type(src) == "string" and type(name) == "string" and name:sub(-19) == "/StatCalculator.lua" then src = PROBE .. src end
    return inner(src, name)
  end
end
'''

# frames made while a file of the calculator itself is on the call stack (after COMMON, which counts XayaUI_Bonus's and its together)
CALC_FRAMES = r'''
local calcFrames = 0
do
  local cf0 = CreateFrame
  CreateFrame = function(...)
    local f = cf0(...)
    for lv = 2, 60 do
      local info = debug.getinfo(lv, "S")
      if not info then break end
      -- (a file's chunk only: its source is "@<path>"; a test chunk's source is its own text, which names the folder)
      local src = info.source or ""
      if src:sub(1, 1) == "@" and src:find("/XayaUI_Bonus_StatCalculator/", 1, true) then calcFrames = calcFrames + 1; break end
    end
    return f
  end
end
'''

SAVED = "The error is saved: /xui bug shows it (needs Advanced Debugging)."
ERRORED = "the Stat Calculator is on, but its files stopped with a Lua error while loading. " + SAVED
ERRORED_STATUS = "Stat Calculator: on, but it could not load this session. Its files stopped with a Lua error while loading. " + SAVED
DISABLED = "the Stat Calculator is on, but XayaUI Bonus Features: Stat Calculator is switched off in the game's AddOns list. Turn it on, then /reload."
MISSING = "the Stat Calculator is on, but its folder XayaUI_Bonus_StatCalculator is not installed: it belongs next to XayaUI_Bonus in Interface\\AddOns."
HELP = "/xui stats: open or close the Stat Calculator. Also: /xui stats options | status | off"
NOTYET = "Stat Calculator: on, not loaded yet (it loads the first time you open it)."
H_MARK = MARK + " [H]"
H_MSG = "Interface/AddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua:10: " + H_MARK
# (round 11a final fix, R11A final review blocker 2) the same file's name as Lua 5.1 writes it in a message: 63 characters, longer than
# the 52 it keeps, so shortened after "..." (tests/fix_r11_error_record_run.py L checks every shipped file's shortened name)
H_CUT_MARK = MARK + " [H cut]"
H_CUT_MSG = "...ddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua:20: " + H_CUT_MARK
# (round 11 repair 2) E's unrelated later error: core's own file, so core's code XUI-E001; each case's mark is its own
UNRELATED = "XUI_TEST unrelated later error"

# E: a file of the calculator stops with a Lua error while loading. WINDOW_ON: also with the settings window open (the drawn page)
S_ERR = r'''
return function(W, L, ARGS)
local WINDOW_ON, STRICT = ARGS.window, ARGS.strict
local PUT = ARGS.second and 2 or 1   -- (the errors put in: one, or two in two files)
local OWN = ARGS.own                 -- (round 11 repair 2) how many of them the record must hold, fixed by the case table (main below)
''' + PRE + BREAK + R10.COMMON + CALC_FRAMES + R10.LOGIN + R10.WINDOW + r'''
-- another addon holds the error handler: seterrorhandler does nothing from now on
if ARGS.nohandler then seterrorhandler = function() end end
-- a client whose debugstack raises (or is missing)
if ARGS.badstack then debugstack = function() error("XUI_TEST no debugstack in this client") end end
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
-- a stand-in for the handler that was active before the load (core's chain, the game's error frame, BugSack): it notes the first addon
-- folder the stack names when the error reaches it, the way core's ns.ErrorFolder files an error that names no file
local probeFolder
local hBefore = geterrorhandler()
local function probe(m)
  if probeFolder == nil and tostring(m):find("__MARK__", 1, true) then
    probeFolder = debug.traceback("", 1):match("dOns[/\\]([%w_]+)[/\\]") or false
  end
  return hBefore(m)
end
if not ARGS.nohandler then seterrorhandler(probe) end
local h0 = geterrorhandler()
local hooks0 = cfHooks
n = #said
ns.RunCommand("stats", ""); W.tick(0.1, 3)
local got = saidSince(n)
check("E ...the error handler that was active before the load is active again after it", geterrorhandler() == h0)
if BREAK_KIND == "game0" then
  -- (the loader's watch passes the error on as a tail call: its own file is not on the stack the next handler reads, so an error that
  -- names no file is still filed under the calculator's folder there, not XayaUI_Bonus's)
  check("E ...the next handler sees the calculator's file first on the stack, not XayaUI_Bonus's loader", probeFolder == "XayaUI_Bonus_StatCalculator",
    tostring(probeFolder))
end
local last = tostring(W.errors[#W.errors])
check("E /xui stats: the stand-in error was put into the file and raised once while loading, and reached the earlier handler as itself (the game still calls the folder loaded)",
  broke == PUT and errCount() == e0 + PUT and last:find("__CMARK__", 1, true) ~= nil and not last:find("^error handler failed") and loaded(),
  broke .. " broken, errors " .. (errCount() - e0) .. ", loaded " .. tostring(loaded()) .. ": " .. last:sub(1, 120))
-- (round 11 repair) the stand-down, read where it happens: StatCalculator.lua's first line
local seen = rawget(_G, "XUI_TEST_SEEN")
check("E ...the probe on StatCalculator.lua's first line ran (the game began reading that file)", type(seen) == "table", tostring(seen))
seen = type(seen) == "table" and seen or {}
local calcGone = ns.StatCalc_Apply == nil and ns.STATCALC_DEFAULTS == nil and ns.BuildStatCalcPage == nil
if ARGS.continues then
  -- (an earlier file reported an error and went on to its end: the model is whole, only the loader's watch knows)
  check("E ...when the game began StatCalculator.lua the model was whole, but the loader had already seen the calculator's error (FilesErrored)",
    seen.model == true and seen.errored == true, tostring(seen.model) .. " " .. tostring(seen.errored))
  check("E ...StatCalculator.lua stood down at its top on that signal alone: none of its functions or settings exist, no statCalc / statCalcDebug service",
    calcGone and ns.Service("statCalc") == nil and ns.Service("statCalcDebug") == nil)
elseif BREAK_FILE ~= "StatCalculator.lua" then
  check("E ...when the game began StatCalculator.lua, the model was not whole: no statModel service (the signal its stand-down reads)",
    seen.model == false, tostring(seen.model))
  if not ARGS.nohandler then
    check("E ...and the loader had already seen the calculator's error (FilesErrored, the stand-down's second signal)", seen.errored == true,
      tostring(seen.errored))
  end
  check("E ...StatCalculator.lua stood down at its top: none of its functions or settings exist, no statCalc / statCalcDebug service",
    calcGone and ns.Service("statCalc") == nil and ns.Service("statCalcDebug") == nil)
  if BREAK_FILE == "StatMath.lua" then
    check("E ...StatModel.lua stood down at its top too: no statModel service, no model table", ns.Service("statModel") == nil and ns.StatModel == nil)
  end
else
  check("E ...when the game began StatCalculator.lua nothing was wrong yet (statMath and statModel there, no calculator error seen)",
    seen.model == true and seen.math == true and seen.errored == false, tostring(seen.model) .. " " .. tostring(seen.math) .. " " .. tostring(seen.errored))
  check("E ...the half-read calculator offers nothing: no statCalc / statCalcDebug service", ns.Service("statCalc") == nil and ns.Service("statCalcDebug") == nil)
end
check("E ...the calculator's files made no frame, no secure hook and no hook on the character window (only the loader's one, made at login)",
  calcFrames == 0 and hookN == 0 and cfHooks == hooks0 and hooks0 == 1, calcFrames .. " frames, " .. hookN .. " hooks, character window hooks " .. hooks0 .. " -> " .. cfHooks)
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
  check("E ...and no Lua error at all beyond the one put in", errCount() == e0 + PUT, errCount() - e0)
end
-- (round 11 repair, SD-139) XayaUI's error record
local own = entriesWith("__CMARK__")
do
  local ok = #own == OWN
  for _, e in ipairs(own) do ok = ok and e.code == "XUI-E009" and e.kind == "error" and e.n == 1 end
  if ARGS.nohandler then
    -- (round 11 repair 2: exact, was "at most once") nothing watched: only core's own handler files it (see OWN in main); since the
    -- round 11a final fix core also reads a file name Lua shortened, so every case files it once
    check(("E ...(nothing watched) the error put in is saved exactly %d time(s), only under the Stat Calculator's code XUI-E009"):format(OWN),
      ok, dumpRecord())
  else
    check("E ...the error put in is saved once, under the Stat Calculator's code XUI-E009 (never core's XUI-E001), whatever its message names"
      .. (PUT == 2 and " (each of the two)" or ""), ok and OWN == PUT, dumpRecord())
  end
end
local say = entriesEqual("__ERRORED__")
check("E ...the chat reason is saved as an error under XUI-E009 (SD-139), one entry counted each time it was told (3 tries and the status line: 4)",
  #say == 1 and say[1].code == "XUI-E009" and say[1].kind == "error" and say[1].n == 4, dumpRecord())
check("E ...nothing else is in the error record", #record() == #own + #say, dumpRecord())
-- (round 11 repair 2, the claim's safety) an unrelated XayaUI Lua error after the failed load, reported through the active handler as
-- the game reports one: saved once under its own code, never swallowed by the loader's claim (DebugRecord.lua ns.RecordLoadError)
local r0, eU = #record(), errCount()
geterrorhandler()("__UNRELATED__")
local un = entriesWith("__UNRELATED_MARK__")
check("E ...an unrelated XayaUI Lua error raised after the failed load is still saved, once, under its own code XUI-E001, and reaches the earlier handler",
  #un == 1 and un[1].code == "XUI-E001" and un[1].kind == "error" and un[1].n == 1 and #record() == r0 + 1 and errCount() == eU + 1
  and tostring(W.errors[#W.errors]):find("__UNRELATED_MARK__", 1, true) ~= nil, dumpRecord())
end)
return R
end
'''

# B (round 11 repair): an error object whose text cannot be read, raised in StatMath.lua while loading, reported as the game does
S_BADOBJ = r'''
return function(W, L)
''' + PRE + BREAK + R10.COMMON + R10.LOGIN + r'''
section("B", function()
local sawObj = false
local hBefore = geterrorhandler()
seterrorhandler(function(m) if type(m) == "table" and rawget(m, "xuiTestObject") then sawObj = true; return end; return hBefore(m) end)
local e0 = #W.errors
local n = #said
ns.RunCommand("stats", ""); W.tick(0.1, 3)
local got = saidSince(n)
check("B setup: the error object was raised in StatMath.lua while loading and the file stopped there (the game still calls the folder loaded)",
  broke == 1 and ns.Service("statMath") == nil and loaded(), broke)
check("B ...the earlier handler still received the error object: the watch passed it on although its text cannot be read", sawObj)
check("B ...one line saying its files stopped with a Lua error (the end-of-file marks; the watch could not read this one); nothing shows",
  #got == 1 and got[1] == "__ERRORED__" and not shown(), table.concat(got, " / "))
check("B ...the watch did not count it (FilesErrored false), and StatModel.lua and StatCalculator.lua still stood down",
  ns.StatCalcLoader.FilesErrored() == false and ns.Service("statModel") == nil and ns.Service("statCalc") == nil and ns.StatCalc_Apply == nil)
check("B ...no Lua error at all", #W.errors == e0, #W.errors - e0)
local say = entriesEqual("__ERRORED__")
check("B ...only the chat reason is saved (XUI-E009, told once)", #record() == 1 and #say == 1 and say[1].code == "XUI-E009" and say[1].n == 1, dumpRecord())
end)
return R
end
'''

# W: a healthy calculator, while another addon's ADDON_LOADED handler raises a Lua error during the same load
S_OTHER = r'''
return function(W, L, PATH)
''' + PRE + R10.COMMON + R10.LOGIN + r'''
local other = CreateFrame("Frame")
other:RegisterEvent("ADDON_LOADED")
other:SetScript("OnEvent", loadstring("local _, _, name = ...; if name == 'XayaUI_Bonus_StatCalculator' then error('another addon broke') end",
  "@" .. PATH))
section("W", function()
local e0, h0 = #W.errors, geterrorhandler()
local n = #said
ns.RunCommand("stats", ""); W.tick(0.1, 3)
local got = saidSince(n)
local last = tostring(W.errors[#W.errors] or "")
check("W setup: the other addon's error was raised during the load and reached the earlier handler (recorded once)",
  #W.errors == e0 + 1 and last:find("another addon broke", 1, true) ~= nil and loaded(), #W.errors - e0)
check("W ...it is not the calculator's: '/xui stats' opens it (shown, nothing said)", shown() and #got == 0, table.concat(got, " / "))
check("W ...counted as loaded, and FilesErrored() is false", ns.StatCalcLoader.Loaded() == true and ns.StatCalcLoader.FilesErrored() == false)
check("W ...the error handler that was active before the load is active again after it", geterrorhandler() == h0)
n = #said
ns.RunCommand("stats", "status")
got = saidSince(n)
check("W ...'/xui stats status' is the calculator's own status line", #got == 1 and got[1]:find("^Stat Calculator: on, panel ") ~= nil,
  table.concat(got, " / "))
check("W ...nothing is saved in XayaUI's error record (another addon's error is not XayaUI's)", #record() == 0, dumpRecord())
end)
return R
end
'''


# H: a healthy calculator while another addon replaces the error handler during the same load (its ADDON_LOADED handler, chaining the
# one it found, as an error-catching addon loaded on demand would): its handler must stay active after the load, and an error the
# calculator raises later in play is not a load error
S_SWAP = r'''
return function(W, L)
''' + PRE + R10.COMMON + R10.LOGIN + r'''
local theirs, found, theirsSaw = nil, nil, 0
local other = CreateFrame("Frame")
other:RegisterEvent("ADDON_LOADED")
other:SetScript("OnEvent", function(_, _, name)
  if name ~= "XayaUI_Bonus_StatCalculator" or theirs then return end
  found = geterrorhandler()
  theirs = function(m) theirsSaw = theirsSaw + 1; return found(m) end
  seterrorhandler(theirs)
end)
section("H", function()
local h0 = geterrorhandler()
local n = #said
ns.RunCommand("stats", ""); W.tick(0.1, 3)
local got = saidSince(n)
check("H setup: the other addon put its handler in during the load (in front of the one active then)", theirs ~= nil and found ~= nil and found ~= h0)
check("H ...the calculator opens (shown, nothing said), counted as loaded, FilesErrored() false", shown() and #got == 0
  and ns.StatCalcLoader.Loaded() == true and ns.StatCalcLoader.FilesErrored() == false, table.concat(got, " / "))
check("H ...after the load the other addon's handler is still the active one (the loader did not put its old one back over it)",
  geterrorhandler() == theirs)
-- later, in play: a Lua error raised in a calculator file reaches the active handler (the game's report of it)
local e0 = #W.errors
geterrorhandler()("__H_MSG__")
check("H a later error in a calculator file reaches the other addon's handler and the one before the load (recorded once)",
  theirsSaw == 1 and #W.errors == e0 + 1 and tostring(W.errors[#W.errors]):find("__H_MARK__", 1, true) ~= nil, #W.errors - e0)
check("H ...it is not a load error: still loaded, FilesErrored() still false",
  ns.StatCalcLoader.Loaded() == true and ns.StatCalcLoader.FilesErrored() == false, tostring(ns.StatCalcLoader.FilesErrored()))
local own = entriesWith("__H_MARK__")
check("H ...it is saved once, under the Stat Calculator's code XUI-E009, and nothing else is saved", #own == 1 and own[1].code == "XUI-E009"
  and own[1].n == 1 and #record() == 1, dumpRecord())
-- (round 11a final fix) a later error naming the file as Lua writes it, shortened: before the fix core's handler filed nothing for it
e0 = #W.errors
geterrorhandler()("__H_CUT_MSG__")
local cut = entriesWith("__H_CUT_MARK__")
check("H ...a later error with the file's name as Lua writes it ('...ddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua:20:') reaches both handlers and is saved once under XUI-E009 too",
  theirsSaw == 2 and #W.errors == e0 + 1 and #cut == 1 and cut[1].code == "XUI-E009" and cut[1].kind == "error" and cut[1].n == 1
  and #record() == 2, dumpRecord())
n = #said
ns.RunCommand("stats", ""); W.tick(0.1, 2)
got = saidSince(n)
check("H ...'/xui stats' still closes it, nothing said", not shown() and #got == 0, table.concat(got, " / "))
end)
return R
end
'''

# R: switched off in the AddOns list / not installed: the reason on every try (SD-146)
S_REPEAT = r'''
return function(W, L, LINE)
''' + PRE + R10.COMMON + R10.LOGIN + r'''
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
check("R ...the player's own setup, an ordinary message: nothing is saved in the error record", #record() == 0, dumpRecord())
end)
return R
end
'''

# U: unknown words while on
S_UNKNOWN = r'''
return function(W, L)
''' + PRE + R10.COMMON + R10.LOGIN + r'''
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
check("U ...nothing is saved in the error record", #record() == 0, dumpRecord())
end)
-- X (round 11 repair, R11A concern: '/xui bug shows errors' was untrue with Advanced Debugging off, the default)
section("X", function()
local n = #said
SlashCmdList["XAYAUI"]("bug")   -- (typed as the player types it: /xui bug)
local b = saidSince(n)
check("X with Advanced Debugging off (the default), /xui bug only says it needs Advanced Debugging (what the reworded lines now say)",
  #b == 1 and b[1]:find("needs Advanced Debugging", 1, true) ~= nil and not ns.AdvancedDebugOn(), table.concat(b, " / "))
check("X a /xui word of an addon that is not installed: says Lua errors are saved and that /xui bug needs Advanced Debugging (XayaUI QoL, /xui stats: SD-89)",
  ns.ModuleMissingText("stats") == "/xui stats is part of XayaUI QoL, which is not installed or failed to load. Lua errors are saved: /xui bug shows them (needs Advanced Debugging).",
  tostring(ns.ModuleMissingText("stats")))
check("X a /xui word its loaded addon never registered: the same (XayaUI Bonus Features, /xui calc)",
  ns.ModuleMissingText("calc") == "/xui calc did not respond: XayaUI Bonus Features is loaded, but the command was never registered. Lua errors are saved: /xui bug shows them (needs Advanced Debugging).",
  tostring(ns.ModuleMissingText("calc")))
end)
return R
end
'''

# the error record of a finished session, read with rawget only (the stand-in's _G reports every unknown global it is asked for)
RECORD_LUA = r'''function()
  local db = rawget(_G, "CueRulesDB")
  local log = type(db) == "table" and rawget(db, "errorLog") or nil
  local out = {}
  if type(log) == "table" then
    for _, e in ipairs(log) do
      if type(e) == "table" then out[#out + 1] = tostring(rawget(e, "code")) .. "\t" .. tostring(rawget(e, "n")) .. "\t" .. tostring(rawget(e, "msg")) end
    end
  end
  return table.concat(out, "\n\001")
end'''


def fill(src, cmark=MARK, shift=0, umark=UNRELATED):
    src = src.replace("__UNRELATED__", "Interface/AddOns/XayaUI/Core.lua:5: " + umark).replace("__UNRELATED_MARK__", umark)
    return (src.replace("__ERRORED_STATUS__", ERRORED_STATUS).replace("__ERRORED__", ERRORED).replace("__NOTYET__", NOTYET)
            .replace("__HELP__", HELP).replace("__H_MSG__", H_MSG).replace("__H_MARK__", H_MARK).replace("__H_CUT_MSG__", H_CUT_MSG).replace("__H_CUT_MARK__", H_CUT_MARK)
            .replace("__CMARK__", cmark).replace("__MARK__", MARK).replace("__SHIFT__", str(int(shift))))


def lua_str(s):
    return "nil" if s is None else '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


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
    rec = []
    for row in str(L.eval(RECORD_LUA)() or "").split("\n\001"):
        if row:
            code, n, msg = (row.split("\t", 2) + ["", "", ""])[:3]
            rec.append((code, int(float(n)) if n not in ("", "nil") else 1, msg))
    return results, errs, rec


def toc_notes(folder):
    for line in open(os.path.join(ROOT, folder, folder + ".toc"), encoding="utf-8"):
        if line.startswith("## Notes:"):
            return line.split(":", 1)[1].strip()
    return ""


def notes_checks():
    out = []
    b, s = toc_notes("XayaUI_Bonus"), toc_notes(CALC)
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


# F: the end-of-file marks (round 11 repair)
MARKS = (("StatMath.lua", "statMath", 'if ns.Provide then ns.Provide("statMath", M) end'),
         ("StatModel.lua", "statModel", 'if ns.Provide then ns.Provide("statModel", { CM = CM }) end'),
         ("StatCalculator.lua", "statCalc", 'if ns.Provide then ns.Provide("statCalcDebug", DEBUG_SERVICE); ns.Provide("statCalc", CALC_SERVICE) end'))


def code_lines(text):
    return [ln.strip() for ln in text.splitlines() if ln.strip() and not ln.strip().startswith("--")]


def mark_checks():
    out = []
    toc = [ln.strip() for ln in open(os.path.join(ROOT, CALC, CALC + ".toc"), encoding="utf-8")
           if ln.strip() and not ln.startswith("#")]
    out.append(("F XayaUI_Bonus_StatCalculator.toc reads StatMath.lua, StatModel.lua, StatCalculator.lua, in that order (each stand-down reads "
                "the file before it)", toc == [m[0] for m in MARKS], toc))
    srcs = {}
    for f in sorted(os.listdir(os.path.join(ROOT, CALC))):
        if f.endswith(".lua"):
            srcs[f] = open(os.path.join(ROOT, CALC, f), encoding="utf-8").read()
    for f, svc, line in MARKS:
        lines = code_lines(srcs.get(f, ""))
        out.append(("F %s's last statement is its end-of-file mark: %s" % (f, line), bool(lines) and lines[-1] == line,
                    lines[-1] if lines else "(no file)"))
    offers = {}
    for f, text in srcs.items():
        for m in re.finditer(r'Provide\(\s*"(stat\w+)"', "\n".join(code_lines(text))):
            offers.setdefault(m.group(1), []).append(f)
    want = {"statMath": ["StatMath.lua"], "statModel": ["StatModel.lua"], "statCalc": ["StatCalculator.lua"],
            "statCalcDebug": ["StatCalculator.lua"]}
    out.append(("F each service is offered once, by its own file's last statement only (a half-read file offers nothing)", offers == want,
                offers))
    loader = open(os.path.join(ROOT, "XayaUI_Bonus", "StatCalculatorLoader.lua"), encoding="utf-8").read()
    out.append(("F the loader counts the calculator as whole by exactly those three marks (FilesComplete)",
                'local MARKS = { "statMath", "statModel", "statCalc" }' in loader, "MARKS line"))
    return out


# X (static): no shipped line says "/xui bug shows errors" any more; the two error lines with no stand-in path here say the same as
# the others (the settings window that cannot load: Modules.lua ns.LoadOptions; the rule editor: Options.lua LoadRuleEditor)
WORDING = (("XayaUI/Modules.lua", '"the settings window could not load (" .. tostring(ok and reason or loaded) .. "). The error is saved: /xui bug shows it (needs Advanced Debugging)."'),
           ("XayaUI_Options/Options.lua", '"the rule editor could not be set up: the Rules tab is left out. The error is saved: /xui bug shows it (needs Advanced Debugging)."'),
           ("XayaUI_Bonus/StatCalculatorLoader.lua", 'local SAVED = "' + SAVED + '"'))


def wording_checks():
    out, old = [], []
    for top in sorted(os.listdir(ROOT)):
        d = os.path.join(ROOT, top)
        if not (top.startswith("XayaUI") and os.path.isdir(d)):
            continue
        for dp, _dn, fns in os.walk(d):
            for fn in fns:
                if fn.endswith(".lua") and "/xui bug shows errors" in "\n".join(code_lines(open(os.path.join(dp, fn), encoding="utf-8", errors="replace").read())):
                    old.append(os.path.relpath(os.path.join(dp, fn), ROOT))   # (code lines only: a comment may quote the old line)
    out.append(("X no XayaUI file says '/xui bug shows errors' (untrue with Advanced Debugging off, the default)", not old, old))
    for f, text in WORDING:
        out.append(("X %s says the error is saved and /xui bug needs Advanced Debugging" % f,
                    text in open(os.path.join(ROOT, f), encoding="utf-8").read(), text[:60]))
    return out


def main():
    bad = n = 0
    errs_all = []
    # (round 11 repair 2, R11A repair-1 review blocker) what the honest-result guard is told is FIXED by this table and the cases, never
    # counted from the record it is compared with: a break that drops or re-files an entry then fails the guard on its own, besides
    # the named check that reads the same entry (before repair 2 both numbers were summed from the record, so the guard could never
    # see a missing entry: the named check was the only catch).
    declared = []   # (case, XUI-E009 entries this test causes on purpose and checks: fixed per case)
    declared1 = []  # (case, XUI-E001 entries: E's unrelated later error, one per E case)

    def report(tag, results, errs, allowed=0, allowed_other=None, later=0):
        nonlocal bad, n
        for name, ok in results:
            n += 1
            print(("PASS " if ok else "FAIL ") + "[%s] %s" % (tag, name))
            bad += 0 if ok else 1
        mine = [e for e in errs if MARK in e]
        lat = [e for e in errs if UNRELATED in e]
        other = [e for e in errs if MARK not in e and UNRELATED not in e]
        if later or lat:
            # (round 11 repair 2, E) exactly the unrelated later error the test raised, and no other
            n += 1
            ok = len(lat) == later
            print(("PASS " if ok else "FAIL ") + "[%s] exactly %d unrelated later Lua error (the one raised after the load)" % (tag, later))
            bad += 0 if ok else 1
        if allowed_other:
            # (W) exactly the one error the other addon raised, and nothing else
            n += 1
            ok = len(other) == 1 and allowed_other in other[0]
            print(("PASS " if ok else "FAIL ") + "[%s] exactly 1 Lua error, the other addon's" % tag)
            bad += 0 if ok else 1
            other = [] if ok else other
        if allowed:
            n += 1
            ok = len(mine) == allowed
            print(("PASS " if ok else "FAIL ") + "[%s] exactly %d stand-in load error (the one put in)" % (tag, allowed))
            bad += 0 if ok else 1
        errs_all.extend("[%s] %s" % (tag, e) for e in other + (mine if not allowed else []))

    # the chat reason's one XUI-E009 entry, counted each time it was told: E types /xui stats three times and '/xui stats status' once
    # (S_ERR), B types /xui stats once (S_BADOBJ); the counts the Lua checks read (say[1].n == 4, == 1)
    TOLD_E, TOLD_B = 4, 1

    ON = R10.ON
    MIDDLE = "local CALC_SERVICE = {"
    START_UP = 'ns.WhenSettingsReady("bonus", function()\n    if Cfg() then ns.StatCalc_Apply() end'
    SOLVE = "function M.Solve(g, target, lo, hi, increasing)"
    VALUEFOR = "function CM.ValueFor(it, mode)"
    COMMAND = "function ns.StatCalc_Command(arg)"
    # E: (tag, file, before, settings window open, extra)
    cases = (
        ("StatCalculator.lua stops at its top, settings window open", "StatCalculator.lua", "", True, {}),
        ("StatCalculator.lua stops in its middle (before its services are made)", "StatCalculator.lua", MIDDLE, False, {}),
        ("StatCalculator.lua stops just before its start-up", "StatCalculator.lua", START_UP, False, {}),
        ("StatCalculator.lua stops before its last function, settings window open", "StatCalculator.lua", COMMAND, True, {}),
        # (round 11a final blocker 3: this case raised 'ValueFor' (a nil value) at the character window before the stand-down)
        ("StatModel.lua stops before its last function", "StatModel.lua", VALUEFOR, False, {}),
        ("StatMath.lua stops before its last function", "StatMath.lua", SOLVE, False, {}),
        ("StatMath.lua stops with an error that names no file", "StatMath.lua", SOLVE, False, {"kind": "level0"}),
        # as the game reports an error: the handler runs where it was raised, nothing is appended to the message
        ("StatMath.lua stops with an error that names no file, reported as the game does", "StatMath.lua", SOLVE, False, {"kind": "game0"}),
        # the error is raised by a helper the file calls at load: the message names the helper's file
        ("StatMath.lua stops in a helper it calls (SharedXML stand-in)", "StatMath.lua", SOLVE, False, {"kind": "helper"}),
        ("StatMath.lua stops in a helper it calls, reported as the game does", "StatMath.lua", SOLVE, False, {"kind": "gamehelper"}),
        ("StatCalculator.lua stops in a helper it calls, reported as the game does", "StatCalculator.lua", COMMAND, True, {"kind": "gamehelper"}),
        # an earlier file reports an error and still runs to its end (its helper ran under xpcall): only the watch knows (FilesErrored)
        ("StatModel.lua reports an error from a helper and goes on to its end", "StatModel.lua", VALUEFOR, False,
         {"kind": "gamecontinue", "continues": True}),
        # two calculator errors in one load: StatMath.lua reports one and goes on, then StatModel.lua stops with one that names no file
        # (the watch files every calculator error of the load, not only the first)
        ("two errors in one load: StatMath.lua reports one and goes on, StatModel.lua stops with one that names no file", "StatModel.lua",
         VALUEFOR, False, {"kind": "level0", "second": ("StatMath.lua", SOLVE, "gamecontinue")}),
        # a client whose debugstack raises: the message alone names the folder
        ("debugstack raises, StatCalculator.lua stops at its top", "StatCalculator.lua", "", False, {"badstack": True}),
        # (round 11 repair 2) StatCalculator.lua itself reports an error and goes on to its end: its start-up must not run (LoadBroken's
        # second reading); before repair 2 it made its event frame and a hook on the character window for a calculator never called
        ("StatCalculator.lua reports an error from a helper and goes on to its end", "StatCalculator.lua", MIDDLE, False,
         {"kind": "gamecontinue"}),
        # the error handler cannot be chained (another addon holds it): the end-of-file marks alone
        ("error handler held by another addon, StatCalculator.lua stops in its middle", "StatCalculator.lua", MIDDLE, False, {"nohandler": True}),
        ("error handler held by another addon, StatCalculator.lua stops before its last function", "StatCalculator.lua", COMMAND, False,
         {"nohandler": True}),
        ("error handler held by another addon, StatModel.lua stops before its last function", "StatModel.lua", VALUEFOR, False, {"nohandler": True}),
        ("error handler held by another addon, StatMath.lua stops before its last function", "StatMath.lua", SOLVE, False, {"nohandler": True}),
    )
    k = 0
    for k, (tag, f, before, window, extra) in enumerate(cases, 1):
        cmark = "%s [case %d]" % (MARK, k)
        umark = "%s [case %d]" % (UNRELATED, k)
        second = extra.pop("second", None) or (None, None, None)
        # (round 11 repair 2) OWN: the record entries the error(s) put in must leave, fixed here. Watched: each one, filed by the loader
        # under XUI-E009. Nothing watched (nohandler): only core's own handler can file it, from the message's file name.
        # "Interface/AddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua" is 63 characters; Lua 5.1 keeps the last 52 of a longer
        # chunk name, so its message reads "...ddOns/XayaUI_Bonus_StatCalculator/StatCalculator.lua:N: ...". (round 11a final fix, R11A
        # final review blocker 2) core's ns.ErrorFolder (XayaUI/Core.lua) now reads that shortened name, so every nohandler case files
        # it once (was 0 for the two StatCalculator.lua cases, printed as a NOTE; the exact check below now fails on 0)
        put = 2 if second[0] else 1
        own = put
        src = (fill(S_ERR, cmark, k * 1000000, umark).replace("__FILE__", lua_str(f)).replace("__BEFORE__", lua_str(before))
               .replace("__KIND__", lua_str(extra.get("kind", "plain")))
               .replace("__FILE2__", lua_str(second[0])).replace("__BEFORE2__", lua_str(second[1])).replace("__KIND2__", lua_str(second[2])))
        r, e, rec = session(src, dict({"window": window, "strict": True, "second": second[0] is not None, "own": own}, **extra), ON)
        report(tag, r, e, allowed=put, later=1)
        declared.append((tag, own + TOLD_E))
        declared1.append((tag, 1))   # (its one unrelated later error: S_ERR 'geterrorhandler()("__UNRELATED__")')
    k += 1
    src = (fill(S_BADOBJ, "%s [case %d]" % (MARK, k), k * 1000000).replace("__FILE__", lua_str("StatMath.lua")).replace("__BEFORE__", lua_str(SOLVE))
           .replace("__KIND__", lua_str("badobj")).replace("__FILE2__", "nil").replace("__BEFORE2__", "nil").replace("__KIND2__", "nil"))
    r, e, rec = session(src, None, ON)
    report("an error object whose text cannot be read", r, e)
    declared.append(("an error object whose text cannot be read", TOLD_B))   # (the chat reason, told once; the object is not filed)
    for path in ("Interface/AddOns/OtherAddon/Other.lua", "Interface/AddOns/Old_XayaUI_Bonus_StatCalculator/Other.lua",
                 "Interface/AddOns/OtherAddon/XayaUI_Bonus_StatCalculatorSkin.lua"):
        k += 1
        tag = "another addon's error during the load (%s)" % path
        r, e, rec = session(fill(S_OTHER, MARK, k * 1000000), path, ON)
        report(tag, r, e, allowed_other=path.split("/")[-1])
    k += 1
    r, e, rec = session(fill(S_SWAP, MARK, k * 1000000), None, ON)
    report("another addon replaces the error handler during the load", r, e, allowed=2)
    # (H's two later errors in play, raised by the test's own geterrorhandler()("__H_MSG__") and geterrorhandler()("__H_CUT_MSG__")
    # calls: each filed once by core under XUI-E009)
    declared.append(("another addon replaces the error handler during the load (the two later errors in play)", 2))
    # R: SD-146 for the other two causes
    for tag, line, off, gone in (("switched off in the AddOns list", DISABLED, (CALC,), ()),
                                 ("folder not installed", MISSING, (), (CALC,))):
        k += 1
        r, e, rec = session(fill(S_REPEAT, MARK, k * 1000000), line, ON, off, gone)
        report(tag, r, e)
    k += 1
    r, e, rec = session(fill(S_UNKNOWN, MARK, k * 1000000), None, ON)
    report("unknown words, on", r, e)
    for name, ok, extra in notes_checks():
        n += 1
        print(("PASS " if ok else "FAIL ") + "[AddOns list] " + name + ("" if ok else "  [%s]" % (extra,)))
        bad += 0 if ok else 1
    for name, ok, extra in wording_checks():
        n += 1
        print(("PASS " if ok else "FAIL ") + "[wording] " + name + ("" if ok else "  [%s]" % (extra,)))
        bad += 0 if ok else 1
    for name, ok, extra in mark_checks():
        n += 1
        print(("PASS " if ok else "FAIL ") + "[end-of-file marks] " + name + ("" if ok else "  [%s]" % (extra,)))
        bad += 0 if ok else 1
    for x in errs_all:
        print("ERROR in the game stand-in:", x[:600])
    # the error record entries this test caused on purpose, each checked above (the honest-result guard, tests/run_all.py, compares)
    total = sum(c for _t, c in declared)
    print("caused on purpose and checked, XUI-E009: " + "; ".join("%s %d" % (t, c) for t, c in declared))
    print("EXPECT_ERRORS XUI-E009 %d" % total)
    # (round 11 repair 2) E's unrelated later error, one per E case: S_ERR 'geterrorhandler()("__UNRELATED__")'
    print("caused on purpose and checked, XUI-E001: " + "; ".join("%s %d" % (t, c) for t, c in declared1))
    print("EXPECT_ERRORS XUI-E001 %d" % len(cases))
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs_all)))
    sys.exit(1 if bad or errs_all or n == 0 else 0)


if __name__ == "__main__":
    main()
