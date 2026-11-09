#!/usr/bin/env python3
"""tests/harness_lockdown_run.py: the harness world (tests/harness/world.lua) blocks protected calls in combat and lets a test mark
a value secret (fix plan f6-1, the minimal slice; the full part, Blizzard's protected frames by name, is phase 9).
Before: IsProtected() was always false and every call went through in combat, so no test could see a "blocked in combat" bug;
W.secret existed but had no helper and nothing in tests/harness set it. Negative control: run against the old world.lua, the
blocking checks below fail (W.Protect does not exist).
Run: python3 tests/harness_lockdown_run.py   (needs: pip install lupa)"""
import json, os, sys
HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "harness")
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
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


L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
W = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(HERE, "world.lua"), api)
run = L.eval("function(src) return assert(loadstring(src))() end")
L.globals().W = W

# 1. the list of blocked methods is what the 12.1.5 documentation flags IsProtectedFunction on the frame / region API objects
OBJS = {"SimpleFrameAPI", "SimpleScriptRegionAPI", "SimpleScriptRegionResizingAPI", "SimpleRegionAPI"}
wm = json.load(open(os.path.join(ROOT, "docs", "reference", "api", "api.json"), encoding="utf-8"))["docs"]["widgetMethods"]
listed = [W.PROTECTED_METHODS[i] for i in range(1, len(W.PROTECTED_METHODS) + 1)]
undocumented = [m for m in listed if not any(e.get("object") in OBJS and "IsProtectedFunction" in (e.get("flags") or [])
                                             for e in wm.get(m, []))]
check("every blocked method is flagged IsProtectedFunction in the API documentation (%d methods)" % len(listed),
      len(listed) >= 10 and not undocumented, undocumented)

# 2. a protected frame in combat: each listed method does nothing and is recorded as an error
res = run("""
local f = CreateFrame("Frame", "XuiTestProtected", UIParent)
W.Protect(f)
f:SetSize(10, 10); f:SetPoint("CENTER"); f:Show()
local out = { prot = select(1, f:IsProtected()) }
local e0 = #W.errors
W.combat = true
f:Hide(); out.hidBlocked = f:IsShown()
f:SetSize(50, 60); out.sizeKept = (f._w == 10 and f._h == 10)
f:ClearAllPoints(); out.ptsKept = (f:GetNumPoints() == 1)
f:SetPoint("TOPLEFT", 5, 5); out.ptsKept2 = (f:GetNumPoints() == 1 and f:GetPoint(1) == "CENTER")
f:SetParent(nil); out.parentKept = (f:GetParent() == UIParent)
out.errs = #W.errors - e0
out.blocked = #W.blocked
out.msg = W.errors[#W.errors] or ""
-- every listed method, on a fresh protected frame
local g = W.Protect(CreateFrame("Frame", "XuiTestProtected2", UIParent))
local b0 = #W.blocked
for _, m in ipairs(W.PROTECTED_METHODS) do
  if m == "SetPoint" then g[m](g, "CENTER") elseif m == "ClearPoint" then g[m](g, "CENTER")
  elseif m == "SetSize" then g[m](g, 1, 1) elseif m == "SetParent" then g[m](g, UIParent)
  elseif m == "SetFrameStrata" then g[m](g, "HIGH") else g[m](g, 1) end
end
out.allBlocked = #W.blocked - b0
out.nMethods = #W.PROTECTED_METHODS
-- an unprotected frame in combat: works as before
local u = CreateFrame("Frame", "XuiTestPlain", UIParent)
u:Show(); u:Hide(); u:SetSize(7, 8)
out.plainOK = (not u:IsShown()) and u._w == 7 and select(1, u:IsProtected()) == false
-- the protected frame out of combat: works
W.combat = false
local e1 = #W.errors
f:Hide(); f:SetSize(50, 60)
out.afterOK = (not f:IsShown()) and f._w == 50 and #W.errors == e1
-- a frame from a secure template is protected
local s = CreateFrame("Button", "XuiTestSecure", UIParent, "SecureActionButtonTemplate")
out.secureProt = select(1, s:IsProtected())
W.combat = true; s:Hide(); out.secureBlocked = s:IsShown(); W.combat = false
return out
""")
check("W.Protect marks a frame protected (IsProtected() is true)", res.prot is True)
check("in combat: Hide on a protected frame does nothing", res.hidBlocked is True)
check("in combat: SetSize / ClearAllPoints / SetPoint / SetParent do nothing", res.sizeKept and res.ptsKept and res.ptsKept2 and res.parentKept)
check("in combat: each blocked call is recorded as an error (5 calls -> 5 errors) and in W.blocked",
      res.errs == 5 and res.blocked >= 5, (res.errs, res.blocked))
check("the error names the frame, the method and combat lockdown", "XuiTestProtected:SetParent()" in res.msg and "combat lockdown" in res.msg, res.msg[:200])
check("every listed method is blocked on a protected frame in combat (%d of %d)" % (res.allBlocked, res.nMethods), res.allBlocked == res.nMethods)
check("an unprotected frame in combat is not blocked (nothing is protected by default)", res.plainOK is True)
check("a protected frame out of combat is not blocked", res.afterOK is True)
check("a frame made from a Secure template is protected and blocked in combat", res.secureProt is True and res.secureBlocked is True)

# 3. secret values: a test marks one value; nothing else becomes secret
sec = run("""
local o = {}
o.before = issecretvalue("xui-secret-name")
local v = W.MarkSecret("xui-secret-name")
o.ret = (v == "xui-secret-name")
o.secret = issecretvalue("xui-secret-name"); o.can = canaccessvalue("xui-secret-name")
o.other = issecretvalue("another name"); o.num = issecretvalue(5)
W.ClearSecret("xui-secret-name")
o.after = issecretvalue("xui-secret-name")
return o
""")
check("W.MarkSecret: the value is secret (issecretvalue true, canaccessvalue false) and comes back from the call",
      sec.before is False and sec.ret is True and sec.secret is True and sec.can is False)
check("W.MarkSecret marks only that value", sec.other is False and sec.num is False)
check("W.ClearSecret undoes it", sec.after is False)

print("%d checks, %d failed" % (checks, fails))
sys.exit(1 if fails else 0)
