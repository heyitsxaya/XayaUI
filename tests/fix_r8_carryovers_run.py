#!/usr/bin/env python3
"""Bundle 1 round 8, round 6 carry-overs and one documented-API fix (round 7 summary: "Carry-overs from round 6 still open"; V2: API facts
only from docs/reference/api/).
What the player gets, on the real addons in the stand-in game ([new] = fails on the pre-change files):
  C  [new] copying a settings table whose metatable is not a plain table never stops XayaUI with a Lua error (XayaUI/Core.lua ns.Copy,
     which the rules, profiles and backups go through): a table protected with __metatable = true or a number is copied the plain way,
     and so is one whose metatable holds a __xuiCopy that is not a function; a rule backup's stand-in (a real __xuiCopy) still gives its
     full copy (control).
  B  [new] Profiles > a backup whose saved text is damaged: "Load (replace)" and "Load (add)" say once in chat that it could not be read
     and that nothing was changed, and never follow it with "Loaded '<name>'." or "Added 0 rule(s) ..."; the Profiles page's own line
     says it could not be read; her rules are unchanged. A good backup still loads and says "Loaded '<name>'." (control).
  A  [new] the Combat Tracking Setup window (XayaUI_Options/AuraSetup.lua) ends a drag with Frame:StopMovingOrSizing, the documented call
     (docs/reference/api/widgets.md, Frame), also on a client whose frames would have the undocumented StopMovingAndSettling; no file of
     XayaUI or XayaUI Options names a StartMoving / StopMoving call that widgets.md does not document.
UNVERIFIED IN GAME.
Run: python3 tests/fix_r8_carryovers_run.py   (Lua 5.1 via lupa)"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()
-- (A) a client whose frames also have StopMovingAndSettling: given to the setup window's frame when it is made
local rawCreate = CreateFrame
local settle = function() end
CreateFrame = function(kind, name, ...)
  local f = rawCreate(kind, name, ...)
  if name == "XayaUIAuraSetupFrame" then rawset(f, "StopMovingAndSettling", settle) end
  return f
end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")

-- C
local function tryCopy(t) local ok, v = pcall(ns.Copy, t); return ok, v end
local p1 = setmetatable({ a = 1, b = { c = 2 } }, { __metatable = true })
local ok1, c1 = tryCopy(p1)
check("[new] C a table protected with __metatable = true is copied the plain way, no error", ok1 and type(c1) == "table" and c1.a == 1
  and c1.b.c == 2 and c1.b ~= p1.b, tostring(c1))
local p2 = setmetatable({ a = 3 }, { __metatable = 7 })
local ok2, c2 = tryCopy(p2)
check("[new] C ... and one protected with a number", ok2 and type(c2) == "table" and c2.a == 3, tostring(c2))
local p3 = setmetatable({ a = 4 }, { __xuiCopy = true })
local ok3, c3 = tryCopy(p3)
check("[new] C ... and one whose metatable holds a __xuiCopy that is not a function", ok3 and type(c3) == "table" and c3.a == 4, tostring(c3))
local p4 = setmetatable({}, { __xuiCopy = function() return { full = true } end })
local ok4, c4 = tryCopy(p4)
check("C (control) a backup stand-in's __xuiCopy still gives its full copy", ok4 and type(c4) == "table" and c4.full == true, tostring(c4))
local p5 = setmetatable({ a = 5 }, { __metatable = "locked" })
local ok5, c5 = tryCopy(p5)
check("C (control) a string-protected table is copied the plain way", ok5 and type(c5) == "table" and c5.a == 5, tostring(c5))

-- B
local said = {}
local P0 = ns.Print
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; said[#said + 1] = table.concat(t, " ") end
ns.LoadOptions(); W.tick(0.1, 3); ns = rawget(_G, "XayaUI_NS")
local nRules = #ns.rules
local okG = ns.Backup_Save("Good one", nil)
local okD = ns.Backup_Save("Broken one", nil)
local broken
for _, x in ipairs(ns.Backups()) do if x.name == "Broken one" then broken = x end end
check("(sanity) two backups saved, one kept as text to damage", okG and okD and broken and type(rawget(broken, "text")) == "string")
if broken then rawset(broken, "text", rawget(broken, "text"):sub(1, 20)) end
local T = ns.BuildOptionsTable()
local ex = T.args.profiles.args.export.args
local gi, bi
for i = 1, 20 do
  if ex["p" .. i] and ex["p" .. i].name == "Good one" then gi = i end
  if ex["p" .. i] and ex["p" .. i].name == "Broken one" then bi = i end
end
check("(sanity) both are on the Profiles page", gi ~= nil and bi ~= nil)
if bi then
  for _, how in ipairs({ "replace", "add" }) do
    said = {}
    ex["p" .. bi].args[how].func(); W.tick(0.1, 3)
    local joined = table.concat(said, " / ")
    local nRead = 0
    for _, l in ipairs(said) do if l:find("could not be read", 1, true) then nRead = nRead + 1 end end
    check(("[new] B damaged backup, Load (%s): one chat line saying it could not be read, and no 'Loaded' or 'Added' line after it"):format(how),
      nRead == 1 and not joined:find("Loaded '", 1, true) and not joined:find("Added ", 1, true), joined)
    local msg = tostring(ex.msg.name())
    check(("[new] B ... the Profiles page's line says it could not be read (Load %s)"):format(how),
      msg:find("could not be read", 1, true) ~= nil and not msg:find("Loaded", 1, true), msg)
    check(("B ... and her rules are unchanged (Load %s)"):format(how), #ns.rules == nRules, #ns.rules)
  end
end
if gi then
  said = {}
  ex["p" .. gi].args.replace.func(); W.tick(0.1, 3)
  check("B (control) a good backup still loads and says \"Loaded 'Good one'.\"", table.concat(said, " / "):find("Loaded 'Good one'.", 1, true) ~= nil
    and #ns.rules == nRules, table.concat(said, " / "))
end
ns.Print = P0

-- A
pcall(ns.AuraSetup_Open); W.tick(0.1, 3)
local f = rawget(_G, "XayaUIAuraSetupFrame")
check("(sanity) the Combat Tracking Setup window is made", f ~= nil)
if f then
  local stop = f:GetScript("OnDragStop")
  check("[new] A its drag ends with the documented Frame:StopMovingOrSizing, not StopMovingAndSettling", stop ~= nil and stop ~= settle
    and stop == f.StopMovingOrSizing, stop == settle and "StopMovingAndSettling" or tostring(stop))
  f:Hide()
end
check("no Lua error", #W.errors == 0, W.errors[1])
end)
if not okAll then R[#R + 1] = { "the run itself finished  [" .. tostring(errAll) .. "]", false } end
return R
end
'''


def static_api():
    """A (static): every StartMoving* / StopMoving* name in XayaUI and XayaUI Options code is in widgets.md."""
    doc = open(os.path.join(H.ROOT, "docs", "reference", "api", "widgets.md"), encoding="utf-8").read()
    bad = []
    for addon in ("XayaUI", "XayaUI_Options"):
        for dp, _dn, fn in os.walk(os.path.join(H.ROOT, addon)):
            if "Libs" in dp.split(os.sep):
                continue
            for f in fn:
                if not f.endswith(".lua"):
                    continue
                code = H.strip_comments(open(os.path.join(dp, f), encoding="utf-8", errors="replace").read())
                for name in set(re.findall(r"\b((?:Start|Stop)Moving\w*)\b", code)):
                    if ("`%s(" % name) not in doc:
                        bad.append("%s: %s" % (os.path.relpath(os.path.join(dp, f), H.ROOT), name))
    return [("[new] A no file of XayaUI or XayaUI Options names a StartMoving / StopMoving call missing from widgets.md", not bad, "; ".join(bad))]


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    results = [(res[i][1], bool(res[i][2])) for i in range(1, len(res) + 1)]
    results += [(n + ("" if ok else "  [" + str(x) + "]"), ok) for n, ok, x in static_api()]
    failed = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        failed += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
