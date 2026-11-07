"""Where a file of the old XayaUI folder lives since the platform split (P4, docs/plans/PLATFORM-SPLIT-2026-11-07.md section 4): the
Platform keeps the folder XayaUI, rule and aura tracking moved to XayaUI_Rules. Tests that load "core" by its toc or by file name read
both folders through these two helpers (the Platform's files first, as the game loads them: XayaUI_Rules depends on XayaUI)."""
import os

CORE_FOLDERS = ("XayaUI", "XayaUI_Rules")


def core_toc_lines(root):
    """The file lines of XayaUI.toc, then of XayaUI_Rules.toc (comments and ## lines left out), as the old XayaUI.toc listed them."""
    out = []
    for folder in CORE_FOLDERS:
        p = os.path.join(root, folder, folder + ".toc")
        if os.path.isfile(p):
            out += [l.strip() for l in open(p) if l.strip() and not l.startswith("#")]
    return out


def core_file(root, rel):
    """The path of a file named as in the old XayaUI.toc ("Engine.lua", "Combat/AuraModel.lua", "Core.lua")."""
    rel = rel.replace("\\", "/")
    for folder in reversed(CORE_FOLDERS):
        p = os.path.join(root, folder, rel)
        if os.path.isfile(p):
            return p
    return os.path.join(root, CORE_FOLDERS[0], rel)
