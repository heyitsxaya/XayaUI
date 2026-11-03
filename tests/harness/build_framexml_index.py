# Builds framexml_index.json (NOT committed: derived from Blizzard's UI code) from a checkout of the public mirror of the game's
# own interface code (github.com/Gethe/wow-ui-source, branch live). Lists every global name Blizzard's Lua and XML define, and marks
# the ones that exist only as "deprecation fallbacks" (Blizzard_Deprecated* addons that load only when the loadDeprecationFallbacks
# setting is on). The harness uses it to sort the global names XayaUI reads into: defined by the game's UI / only a deprecated
# fallback (a bug waiting for that setting to be off) / defined nowhere.
# Usage: python3 build_framexml_index.py <wow-ui-source checkout> [out.json]
import json, os, re, sys
src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "framexml_index.json")
defined, deprecated = {}, {}
lua_def = re.compile(r"^(?:function\s+([A-Za-z_][\w]*)\s*\(|([A-Za-z_][\w]*)\s*=[^=])")
xml_name = re.compile(r'<\w+[^>]*\bname="([A-Za-z_][\w]*)"')
for root, _, files in os.walk(os.path.join(src, "Interface")):
    addon = root.split(os.sep + "AddOns" + os.sep)[-1].split(os.sep)[0] if os.sep + "AddOns" + os.sep in root else "FrameXML"
    dep = addon.startswith("Blizzard_Deprecated")
    for f in files:
        p = os.path.join(root, f)
        if f.endswith(".lua"):
            for line in open(p, encoding="utf-8", errors="replace"):
                m = lua_def.match(line)
                if m:
                    n = m.group(1) or m.group(2)
                    if n in ("local", "return", "if", "for", "end", "else", "elseif", "while", "repeat", "until", "do", "then"):
                        continue
                    (deprecated if dep else defined).setdefault(n, addon)
        elif f.endswith(".xml"):
            for n in xml_name.findall(open(p, encoding="utf-8", errors="replace").read()):
                (deprecated if dep else defined).setdefault(n, addon)
only_dep = {k: v for k, v in deprecated.items() if k not in defined}
json.dump({"defined": defined, "deprecatedOnly": only_dep}, open(out, "w"))
print(len(defined), "names defined;", len(only_dep), "only as deprecation fallbacks")
