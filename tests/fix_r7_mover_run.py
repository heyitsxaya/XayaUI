#!/usr/bin/env python3
"""Bundle 1 round 7: the mover moves into XayaUI Options and works only while the settings window is open.
Her words: SD-58 "mover view only available when settings window is open"; SD-64, /xui unlock with the settings window closed:
"either 1 or remove entirely" (option 1 taken: out of combat it opens the settings window with the mover on; closing settings closes
the mover; in combat the combat-lock message and it opens after combat); her mover answer SD-15 for unsaved moves: "Keep, resume after";
V26 (SD-14 "Message + open after"); V28 (window closed, editing stops); V34 (off means not read: XayaUI Options is load-on-demand).
What the player sees or gets, on the real addons in the stand-in game (tests/harness):
  R1 at login, the settings window never opened: none of the mover's code is read (XayaUI Options is not loaded and none of the mover's
     functions exists), and nothing of it is on screen.
  R2 /xui unlock with the window closed, out of combat: the settings window opens and the mover is on (the displays take the mouse as
     draggable samples).
  R3 closing the settings window closes the mover (V28): nothing moved, so nothing is kept; the displays let the mouse through again;
     the mover's arrow-key frame and group tags are hidden.
  R4 a move, then the window closed: the move is kept (the display's position) and in the draft, one line says so; opening the window again opens the
     mover with the move; Cancel moves puts the display back.
  R5 /xui unlock in combat: one line (the combat lock) and nothing opens; when combat ends the settings window opens with the mover on.
  R6 the Lock Positions name (ns.ToggleUnlock) with the window closed does what /xui unlock does: the window opens with the mover on.
  R7 a /reload with an unsaved move (the second session loads what the first saved): at login nothing asks and nothing of the mover is
     read; the display is where it was moved; opening the settings window opens the mover with that move; Cancel puts it back.
  S  the code itself: XayaUI_Rules/Visual.lua keeps positions and anchors only (none of the mover's functions, frames, popups, events or
     key handling; the four names Rules' own files call are one-line forwarders to the mover); no file of XayaUI core or XayaUI Rules
     defines a mover function; XayaUI_Options/Mover.lua defines them and XayaUI_Options.toc lists it.
Fails on the files before this change (proved on a copy of the tree before it): R1 (the mover's functions exist at login), R2 / R5 / R6
(the mover opened with the window shut), R3 / R4 (closing the window left a /xui unlock mover open), R7 (a login question about the
draft), S (Visual.lua holds the mover; there is no Mover.lua). UNVERIFIED IN GAME.
Checks marked "(control)" pass on the old files too.
Run: python3 tests/fix_r7_mover_run.py   (Lua 5.1 via lupa)."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

# the mover's own functions (none may be defined in XayaUI core or XayaUI Rules; Mover.lua defines them)
MOVER_FUNCS = ["MoverChanges", "MoverNudge", "MoverSelect", "MoverSelection", "SetMoverTempLock", "IsMoverTempLocked", "MoverTempLocked",
               "MoverKeyFrame", "MoverPromptShown", "MoverCombatClose", "MoverCombatStarting", "MoverPaused", "PickFrame", "FramePicker",
               "FrameUnderCursor", "GroupTagFor", "RefreshGroupTags", "FolderPathText", "SnapPosition", "SelectVisual", "PairedWith",
               "ClearPair", "SetPair", "LinkMembers", "LinkAura", "UnlinkAura", "ContextMenuOwner", "ContextMenuOwnerShown", "MenuChoice",
               "GuardMenu", "VisualMenuParts", "ShowVisualMenu", "SetWindowOpen", "WindowOpen", "EndWindowState"]
# Rules' own names for the mover (its settings window, its "rules" service and its combat engine call them): forwarders only
FORWARDERS = ["ToggleUnlock", "MoverExit", "SetMoveUnlocked", "SetGroupUnlocked"]
# what only the mover's session code uses (frames, popups, events, keys, drag): none may be left in Visual.lua
MARKERS = ["XayaUIMoverKeys", "XayaUIFramePicker", "XayaUIGroupPosPopup", "XAYAUI_MOVER", "moverDraft", "StartMoving", "GetMouseFoci",
           "KeyCatch", "StaticPopup", "PLAYER_REGEN_DISABLED", "CombatLock", "MenuUtil", "IsMouseButtonDown", "GetCursorPosition",
           "IsShiftKeyDown", "RegisterForDrag", "SetMovable", "pairOf", "LinkMembers", "TakeDraft", "groupTags", "groupHandles"]

LUA = r'''
return function(W, L, mode, NAMES)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if not ns then check("(control) XayaUI loaded", false); return R end
MenuUtil.CreateContextMenu = function() end
local said = {}
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end
local function mark() return #said end
local function since(m) local t = {}; for i = m + 1, #said do t[#t + 1] = said[i] end; return t end
local function has(list, pat) for _, l in ipairs(list) do if l:lower():find(pat, 1, true) then return true end end; return false end
local function joined(list) return table.concat(list, " / ") end
local function slash(s) SlashCmdList.XAYAUI(s); W.tick(0.1, 4) end
local function optionsLoaded() return C_AddOns.IsAddOnLoaded("XayaUI_Options") and true or false end
local function windowOpen() return (ns.IsOptionsOpen and ns.IsOptionsOpen()) and true or false end
local function closeWindow() if windowOpen() then ns.ToggleUI(); W.tick(0.1, 4) end end
local function keysShown() local k = rawget(_G, "XayaUIMoverKeys"); return k ~= nil and k:IsShown() end
local function draft() return ns.Settings("core").moverDraft end

if mode == "reload" then
  -------------------------------------------------------------------------------------------------------------------------------------
  -- R7. the session after a /reload with an unsaved move
  -------------------------------------------------------------------------------------------------------------------------------------
  local A
  for _, r in ipairs(ns.rules or {}) do if r.name == "Mover A" then A = r end end
  check("(control) R7 the moved display's rule is in the saved data", A ~= nil)
  if not A then return R end
  check("R7 at login: nothing asks about the unsaved move, and nothing of the mover is read (the settings window's code is not loaded)",
    W.popup == nil and not optionsLoaded() and not ns.unlocked, tostring(W.popup) .. " " .. tostring(optionsLoaded()))
  check("(control) R7 the display keeps the moved position (saved), and the draft is kept", A.visual.x == -55 and type(draft()) == "table",
    tostring(A.visual.x))
  section("R7", function()
    local m = mark()
    ns.ToggleUI(); W.tick(0.1, 4)
    local got = since(m)
    check("R7 opening the settings window opens the mover with the move (one line says so)", windowOpen() and ns.unlocked == true
      and #ns.MoverChanges() == 1 and has(got, "1 unsaved move"), joined(got))
    ns.MoverExit("cancel"); W.tick(0.1, 2)
    check("(control) R7 Cancel moves puts the display back and deletes the draft", A.visual.x == -60 and draft() == nil and not ns.unlocked, tostring(A.visual.x))
  end)
  return R
end

-------------------------------------------------------------------------------------------------------------------------------------
-- R1. at login
-------------------------------------------------------------------------------------------------------------------------------------
local present = {}
for i = 1, #NAMES do local n = NAMES[i]; if ns[n] ~= nil then present[#present + 1] = n end end
check("R1 at login (window never opened): none of the mover's code is read (XayaUI Options not loaded; none of its functions exists)",
  not optionsLoaded() and #present == 0, tostring(optionsLoaded()) .. " " .. table.concat(present, ","))
check("(control) R1 at login: nothing of the mover is on screen", rawget(_G, "XayaUIMoverKeys") == nil and rawget(_G, "XayaUIFramePicker") == nil
  and rawget(_G, "XayaUIGroupPosPopup") == nil)

local f = ns.NewFolder("Mover group")
local function mk(name, x, y)
  local r = ns.NewRule(); r.name = name; r.folder = f.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.size = 40
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local A, B = mk("Mover A", -60, 0), mk("Mover B", 60, 0)
ns.RefreshAllVisuals(); W.tick(0.1, 2)
local function takesMouse(r) local fr = ns.DisplayFrame(r); return fr ~= nil and fr:IsShown() and fr:IsMouseEnabled() end
check("(control) the displays are not on screen while their auras are down and nothing is unlocked", not takesMouse(A) and not takesMouse(B))

section("R2-R3", function()
  slash("unlock")
  check("R2 /xui unlock with the window closed: the settings window opens and the mover is on (the displays are draggable samples)",
    windowOpen() and ns.unlocked == true and takesMouse(A) and takesMouse(B), ("window=%s mover=%s"):format(tostring(windowOpen()), tostring(ns.unlocked)))
  local tag = ns.GroupTagFor and ns.GroupTagFor(f.id)
  check("(control) R2 the group's mover tag shows", tag ~= nil and tag:IsShown())
  local m = mark()
  closeWindow()
  local got = since(m)
  check("R3 closing the settings window closes the mover (V28): nothing moved, nothing kept", not windowOpen() and not ns.unlocked and draft() == nil,
    ("window=%s mover=%s draft=%s"):format(tostring(windowOpen()), tostring(ns.unlocked), tostring(draft() ~= nil)))
  check("R3 the displays let the mouse through again; the arrow-key frame and the group tag are hidden", not takesMouse(A) and not takesMouse(B)
    and not keysShown() and not (tag and tag:IsShown()))
  check("(control) R3 nothing asks (no Save / Cancel question: nothing moved)", W.popup == nil, W.popup)
end)

section("R4", function()
  closeWindow()
  slash("unlock")
  local x0 = A.visual.x
  ns.MoverSelect("display", A); ns.MoverNudge(9, 0); W.tick(0.05, 2)
  W.popup = nil
  local m = mark()
  closeWindow()
  local got = since(m)
  check("R4 a move, then the window closed: the mover closes, the move is kept (the display's position) and in the draft, nothing asks",
    not windowOpen() and not ns.unlocked and A.visual.x == x0 + 9 and type(draft()) == "table" and #ns.MoverChanges() == 1 and W.popup == nil,
    ("window=%s mover=%s x=%s popup=%s"):format(tostring(windowOpen()), tostring(ns.unlocked), tostring(A.visual.x), tostring(W.popup)))
  check("R4 one line says the move is kept and the mover opens again with the window", #got == 1 and has(got, "unsaved move")
    and has(got, "settings window"), joined(got))
  m = mark()
  ns.ToggleUI(); W.tick(0.1, 4)
  got = since(m)
  check("R4 opening the settings window opens the mover again with the move", windowOpen() and ns.unlocked == true and A.visual.x == x0 + 9
    and takesMouse(A) and has(got, "open again"), joined(got))
  ns.MoverExit("cancel"); W.tick(0.1, 2)
  check("(control) R4 Cancel moves puts the display back", A.visual.x == x0 and draft() == nil and not ns.unlocked, tostring(A.visual.x))
  closeWindow()
end)

section("R5", function()
  closeWindow()
  W.enterCombat(); W.tick(0.05, 2)
  local m = mark()
  slash("unlock")
  local got = since(m)
  check("(control) R5 /xui unlock in combat: one line (the combat lock), nothing opens", #got == 1 and has(got, "can't open during combat")
    and has(got, "when combat ends") and not windowOpen() and not ns.unlocked, joined(got))
  W.leaveCombat(); W.tick(0.1, 6)
  check("R5 combat ends: the settings window opens with the mover on", windowOpen() and ns.unlocked == true,
    ("window=%s mover=%s"):format(tostring(windowOpen()), tostring(ns.unlocked)))
  if ns.unlocked then ns.ToggleUnlock(); W.tick(0.1, 2) end
  closeWindow()
end)

section("R6", function()
  closeWindow()
  ns.ToggleUnlock(); W.tick(0.1, 4)
  check("R6 ns.ToggleUnlock (the Lock Positions name) with the window closed: the settings window opens with the mover on",
    windowOpen() and ns.unlocked == true, ("window=%s mover=%s"):format(tostring(windowOpen()), tostring(ns.unlocked)))
  if ns.unlocked then ns.ToggleUnlock(); W.tick(0.1, 2) end
  closeWindow()
end)

-- for R7: a move left unsaved when the session ends (the mover open, the window open: a /reload)
section("R7 setup", function()
  slash("unlock")
  ns.MoverSelect("display", A); ns.MoverNudge(5, 0); W.tick(0.05, 2)
  check("(control) R7 setup: the mover is open with one unsaved move when the session ends", ns.unlocked == true and A.visual.x == -55
    and #ns.MoverChanges() == 1, tostring(A.visual.x))
end)
check("no Lua error in the stand-in", #W.errors == 0, W.errors[1])
return R
end
'''


def session(mode, saved_src):
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    sv = H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    opts["saved"] = sv.Load(saved_src) if saved_src else H.to_lua(L, {})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    res = L.eval("function(src, W, Ld, m, n) return loadstring(src)()(W, Ld, m, n) end")(LUA, world, loader, mode, H.to_lua(L, MOVER_FUNCS))
    out = [(str(res[i][1]), bool(res[i][2])) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i])[:400] for i in range(1, len(world.errors) + 1)]
    if mode == "reload" and errs:
        out.append(("R7 session: no Lua error in the stand-in  [" + errs[0] + "]", False))
    src = None
    if mode == "play":
        saved, _issues = loader.logout()
        src = sv.Serialize(saved)
    return out, src


def strip_comments(src):
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", "", src, flags=re.S)
    return "\n".join(re.sub(r"--.*$", "", ln) for ln in src.split("\n"))


def defines(code, name):
    return re.search(r"(?m)^\s*(?:function\s+ns\.%s\s*\(|ns\.%s\s*=[^=])" % (name, name), code) is not None


def static_checks():
    out = []
    vis_path = os.path.join(ROOT, "XayaUI_Rules", "Visual.lua")
    vis = strip_comments(open(vis_path, encoding="utf-8").read())
    bad = [n for n in MOVER_FUNCS if defines(vis, n)]
    out.append(("S Visual.lua (XayaUI Rules) defines none of the mover's functions" + ("" if not bad else "  [" + ", ".join(bad) + "]"), not bad))
    fw_bad = []
    for n in FORWARDERS:
        lines = [ln.strip() for ln in vis.split("\n") if re.match(r"\s*function\s+ns\.%s\s*\(" % n, ln)]
        want = "function ns.%s(...) local M = ns.MoverDisplay; if M then return M.%s(...) end end" % (n, n)
        if lines != [want]:
            fw_bad.append("%s: %s" % (n, lines[:1]))
    out.append(("S Rules' four mover names in Visual.lua are one-line forwarders to the mover (XayaUI Options), nothing more"
                + ("" if not fw_bad else "  [" + "; ".join(fw_bad) + "]"), not fw_bad))
    left = [m for m in MARKERS if m in vis]
    out.append(("S Visual.lua keeps no mover session code (frames, popups, combat-start event, keys, drag, draft)"
                + ("" if not left else "  [" + ", ".join(left) + "]"), not left))
    owners = []
    for top in ("XayaUI", "XayaUI_Rules"):
        for d, _, files in os.walk(os.path.join(ROOT, top)):
            if "Libs" in d.split(os.sep):
                continue
            for fn in files:
                if not fn.endswith(".lua"):
                    continue
                p = os.path.join(d, fn)
                c = strip_comments(open(p, encoding="utf-8", errors="replace").read())
                for n in MOVER_FUNCS:
                    if defines(c, n):
                        owners.append("%s: ns.%s" % (os.path.relpath(p, ROOT), n))
    out.append(("S no file of XayaUI core or XayaUI Rules defines a mover function" + ("" if not owners else "  [" + ", ".join(owners[:8]) + "]"),
                not owners))
    mv_path = os.path.join(ROOT, "XayaUI_Options", "Mover.lua")
    mv = strip_comments(open(mv_path, encoding="utf-8").read()) if os.path.isfile(mv_path) else ""
    missing = [n for n in MOVER_FUNCS if not defines(mv, n)]
    toc = open(os.path.join(ROOT, "XayaUI_Options", "XayaUI_Options.toc"), encoding="utf-8").read()
    listed = re.search(r"(?m)^Mover\.lua\s*$", toc) is not None
    out.append(("S XayaUI_Options/Mover.lua defines the mover's functions and XayaUI_Options.toc lists it"
                + ("" if (listed and not missing) else "  [listed=%s missing=%s]" % (listed, ", ".join(missing[:8]))), listed and not missing))
    return out


def main():
    results = static_checks()
    play, src = session("play", None)
    results += play
    if src:
        again, _ = session("reload", src)
        results += again
    bad = 0
    for name, good in results:
        print(("PASS " if good else "FAIL ") + name)
        bad += 0 if good else 1
    print("%d checks, %d failed" % (len(results), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
