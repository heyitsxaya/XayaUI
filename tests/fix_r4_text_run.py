#!/usr/bin/env python3
"""Round 4, player text (V26; Xaya 2026-11-10, REQUEST-LOG A23 SD-14 to SD-17, SD-32). Her words: "/xui shouldn't have anything that
allows configuration of rules through the console. It must all be handled through the options and editing interfaces which are not
allowed to open in combat"; /xuiengine full and refresh: "Remove entirely"; the group border / background: "Make it apply to individual
auras, not the whole container"; padding with none saved: "0 px (Recommended)".

What the player reads, checked on the real addons in the stand-in game (Dev Assist NOT loaded, as on main):
- a rule whose group was kept with XayaUI (saved by Dev Assist's /xuiengine off <group>): the reason the engine gives, and the sentence
  the status screen shows when the game hides the aura (Conditions.lua ns.HiddenAuraNote), name no console command and say where it was
  set (old text: "(/xuiengine reset <group> to undo)", a command that does not exist without Dev Assist);
- automatic engine drawing switched off (saved by Dev Assist's /xuiengine auto off): the same (old text: "(/xuiengine auto on)");
- /xuiengine's status in that state names no console command (old text: "XayaUI Dev Assist's /xuiengine auto off");
and in the player documents (docs/USER-GUIDE.md, WHATS-NEW.md, QA-CHECKLIST.md, HELP-FAQ.md, README-INGAME.md):
- no line offers /xuiengine full or /xuiengine refresh unless it says they were removed;
- USER-GUIDE and HELP-FAQ explain the combat lock (quoting the exact line the game prints, read from XayaUI/Modules.lua), what stays
  allowed, /xui disable and /xui enable (the enable line quoted from XayaUI/Core.lua), and that a group's border / background is drawn on
  each display with "Padding around each display" (the slider's name, read from XayaUI_Rules/Editor/RulesTree.lua) starting at 0;
- README-INGAME lists /xui disable and /xui enable.
Old files: every check below fails on them (proved on a copy of the pre-change files).
Run: python3 tests/fix_r4_text_run.py   (Lua 5.1 via lupa)."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local D = ns and ns.AuraDisplay
check("core and the combat engine are loaded (Dev Assist off)", ns and D and D.DB and D.Build and not (ns.DevAssistOn and ns.DevAssistOn()))
if not (ns and D and D.DB and D.Build) then return R end
local said = {}
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end
-- the game's aura container cannot run here: a stand-in that takes every call
CustomAuraContainerAuraProcessingPolicy = CustomAuraContainerAuraProcessingPolicy or { None = 0 }
AuraContainerSortMethod = AuraContainerSortMethod or { Default = 0 }
AuraContainerSortDirection = AuraContainerSortDirection or { Normal = 0, Reverse = 1 }
AnchorUtil = AnchorUtil or {}
AnchorUtil.FlowLayoutAxis = AnchorUtil.FlowLayoutAxis or { Horizontal = 0, Vertical = 1 }
AnchorUtil.FlowDirection = AnchorUtil.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }
local CF = CreateFrame
CreateFrame = function(kind, ...)
  local o = CF(kind == "AuraContainer" and "Frame" or kind, ...)
  if kind == "AuraContainer" then
    for _, m in ipairs({ "SetUnit", "SetAuraProcessingPolicy", "SetAuraGroupCandidateFilters", "SetAuraGroupLayout", "SetAuraGroupEnabled",
      "SetAuraGroupSortMethod", "SetFlowLayoutAxis", "SetFlowLayoutAnchorPoint", "SetFlowLayoutGrowthDirection", "SetFlowLayoutMaximumLineSize",
      "AddAuraGroup" }) do rawset(o, m, function() end) end
  end
  return o
end

ns.runtime = ns.runtime or {}
local G = ns.NewFolder("Kept group")
local r = ns.NewRule(); r.name = "Kept buff"; r.folder = G.id; r.enabled = true
r.visual = r.visual or {}; r.visual.enabled = true; r.visual.w, r.visual.h = 40, 40
r.useBuff, r.buffID, r.visual.trigger = true, 73001, "buffActive"
ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
ns.runtime[r] = { active = true, lastPlay = 0, visualWanted = true }
-- what the status screen shows for this rule while the game hides its aura (Conditions.lua ns.HiddenAuraNote)
local HIDDEN = { present = nil, buffSource = "hidden by the game right now (auras are secret, as in combat): aura 73001" }
local function noCommand(s) return type(s) == "string" and not s:find("/xuiengine", 1, true) and not s:find("<group>", 1, true) end

-- 1. a group kept with XayaUI (the saved choice Dev Assist's /xuiengine off <group> makes)
D.DB().groups[G.id] = false
D.Build()
local why
for _, e in ipairs(D._Left()) do if e[1] == r then why = e[2] end end
check("a kept group: the engine gives a reason for the rule", type(why) == "string", why)
check("  ...the reason names no console command (no /xuiengine reset <group>)", noCommand(why), why)
check("  ...it says plainly where it was set: the developer tool XayaUI Dev Assist", why and why:find("developer tool XayaUI Dev Assist", 1, true), why)
local note = ns.HiddenAuraNote and ns.HiddenAuraNote(r, HIDDEN)
check("  ...the status screen's sentence for the rule names no console command", noCommand(note) and note:find("Dev Assist", 1, true), note)

-- 2. automatic engine drawing off (the saved choice Dev Assist's /xuiengine auto off makes)
D.DB().groups[G.id] = nil
D.DB().auto = false
D.Build()
local own, why2 = D.OwnerOf(r)
check("engine drawing off: the reason for the rule names no console command (no /xuiengine auto on)", own == false and noCommand(why2), tostring(own) .. " / " .. tostring(why2))
check("  ...it says where it was switched off", why2 and why2:find("developer tool XayaUI Dev Assist", 1, true), why2)
note = ns.HiddenAuraNote and ns.HiddenAuraNote(r, HIDDEN)
check("  ...the status screen's sentence names no console command", noCommand(note) and note:find("Dev Assist", 1, true), note)
said = {}
D.Status()
local st = table.concat(said, "\n")
check("  .../xuiengine's status (Dev Assist off) names no command to change it", st ~= "" and not st:find("/xuiengine auto", 1, true) and st:find("Dev Assist", 1, true), st)
D.DB().auto = true
return R
end
'''

DOCS = ["docs/USER-GUIDE.md", "docs/WHATS-NEW.md", "docs/QA-CHECKLIST.md", "docs/HELP-FAQ.md", "docs/README-INGAME.md"]


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def lua_string(src, pattern):
    m = re.search(pattern, src)
    return m.group(1) if m else None


def doc_checks():
    out = []

    def check(name, ok, extra=""):
        out.append((name + ("" if ok else "  [" + str(extra)[:300] + "]"), bool(ok)))

    # no line offers the removed /xuiengine full / refresh as a working command
    for rel in DOCS:
        bad = []
        for n, line in enumerate(read(rel).splitlines(), 1):
            if re.search(r"/xuiengine (full|refresh)", line) and "removed" not in line:
                bad.append("%s:%d" % (rel, n))
        check("%s: no line offers /xuiengine full or refresh (unless it says they were removed)" % rel, not bad, ", ".join(bad))

    modules, core = read("XayaUI/Modules.lua"), read("XayaUI/Core.lua")
    lock_settings = lua_string(modules, r'local LOCK_SETTINGS = "([^"]+)"')
    enable_wait = lua_string(core, r'ns\.CombatLock\("enable", RulesEnableNow, "([^"]+)"\)')
    pad_name = lua_string(read("XayaUI_Rules/Editor/RulesTree.lua"), r'g\.args\.pad = \{ type = "range", name = "([^"]+)"')
    check("the code's lines are found (settings lock line, enable-in-combat line, padding slider name)",
          lock_settings and enable_wait and pad_name, (lock_settings, enable_wait, pad_name))
    for rel in ("docs/USER-GUIDE.md", "docs/HELP-FAQ.md"):
        t = read(rel)
        check("%s: the combat lock quotes the exact line the game prints" % rel, lock_settings and lock_settings in t, lock_settings)
        check("%s: says what stays allowed in combat (/xui disable, /xui report, /xui bug, /xui console)" % rel,
              all(w in t for w in ("Still allowed in combat", "`/xui report`", "`/xui bug`", "`/xui console`")))
        check("%s: says what happens to a window open when combat starts (Rule Drafts, opens again)" % rel,
              "Rule Drafts" in t and "opens again" in t)
        check("%s: explains /xui disable (works in combat) and /xui enable" % rel,
              "`/xui disable`" in t and "`/xui enable`" in t and "works in combat too" in t)
        check("%s: a group's border / background is drawn on each display, padding starting at 0" % rel,
              pad_name and pad_name in t and "starts at 0" in t and "not around the whole group" in t.replace("not as one box around the whole group", "not around the whole group"))
    g = read("docs/USER-GUIDE.md")
    check("USER-GUIDE: the /xui enable in-combat line is quoted exactly", enable_wait and enable_wait in g, enable_wait)
    check("USER-GUIDE: says no command changes rules or the engine", "no command changes them" in g)
    r = read("docs/README-INGAME.md")
    check("README-INGAME: lists /xui disable and /xui enable", "`/xui disable`" in r and "`/xui enable`" in r)
    return out


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)] + doc_checks()
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
