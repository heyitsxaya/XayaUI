"""(P5 settings migration, docs/plans/PLATFORM-SPLIT-2026-11-07.md section 5 steps 2-3) What the tests need to know about where each
module keeps its settings, read from XayaUI/Modules.lua itself (sections 0b / 0c) so the tests follow the code:
  layout(root)        {"keys": {module: [keys]}, "stores": {module: {"addon", "var"}}, "underUi": {module: [keys]},
                       "split": {key: {"owner", "rest", "sub": [sub keys]}}}
  project(merged, lay) the saved variables ({variable: value}, merged across addon folders) with every module store folded back into
                       CueRulesDB as it was laid out before P5 (keys from ui back into ui, the split characterReskin joined, the copy's
                       marks dropped): what the old code would have saved, so a hash made before P5 can be compared.
  STORE_MARKS         the fields the copy writes next to the settings in a store."""
import os, re
import lupa.lua51 as lua51

STORE_MARKS = {"storeVersion", "migratedFrom", "migratedAt", "migratedBy", "migratedKeys", "migrationMismatch"}


def _block(src, name):
    start = src.index("local %s = {" % name)
    i = src.index("{", start)
    depth = 0
    for j in range(i, len(src)):
        c = src[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return src[start:j + 1]
    raise ValueError(name)


def _py(v):
    if lua51.lua_type(v) == "table":
        keys = list(v.keys())
        if keys and all(isinstance(k, int) for k in keys):
            return [_py(v[k]) for k in sorted(keys)]
        return {str(k): _py(v[k]) for k in keys}
    return v


def layout(root):
    src = open(os.path.join(root, "XayaUI", "Modules.lua"), encoding="utf-8").read()
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    code = "\n".join(_block(src, n) for n in ("SETTINGS_KEYS", "LEGACY_UNDER_UI", "LEGACY_SPLIT", "SETTINGS_STORES"))
    t = L.execute(code + "\nreturn { keys = SETTINGS_KEYS, underUi = LEGACY_UNDER_UI, split = LEGACY_SPLIT, stores = SETTINGS_STORES }")
    out = _py(t)
    out["underUi"] = {m: sorted(k for k, v in (ks or {}).items() if v) for m, ks in (out.get("underUi") or {}).items()}
    out["split"] = {k: {"owner": d["owner"], "rest": d["rest"], "sub": sorted(s for s, v in d["sub"].items() if v)}
                    for k, d in (out.get("split") or {}).items()}
    out["stores"] = out.get("stores") or {}
    return out


def project(merged, lay):
    """merged: {variable: value}. Returns a new dict: each module store folded back into CueRulesDB, the store variables removed
    (Dev Assist's store keeps its own non-settings data under its name)."""
    import copy
    out = copy.deepcopy(merged)
    db = out.get("CueRulesDB")
    for module, st in sorted(lay["stores"].items()):
        store = out.get(st["var"])
        if not isinstance(store, dict):
            continue
        under = set(lay["underUi"].get(module, []))
        for k in lay["keys"][module]:
            if k not in store:
                continue
            v = store.pop(k)
            if db is None:
                db = out["CueRulesDB"] = {}
            if k in under:
                db.setdefault("ui", {})[k] = v
            elif k in lay["split"] and isinstance(v, dict):
                tgt = db.get(k)
                if not isinstance(tgt, dict):
                    tgt = db[k] = {}
                tgt.update(v)
            else:
                db[k] = v
        for m in STORE_MARKS:
            store.pop(m, None)
        if not store:
            out.pop(st["var"], None)
    return out
