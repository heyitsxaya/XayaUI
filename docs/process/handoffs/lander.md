# Handoff: lander (session_014bN6tSZh6UFB2WcRuyXqBZ, "XayaUI: Patch Notes / Info pane")

Written 2026-11-07 ~14:15 UTC for O-152. Main at the time of writing: **52d07bc1** (+ this file and the hub's e80d383 in the
same push). The successor is the single session that pushes to main; every other session sends it a branch + exact hash +
its own suite result.

## 1. Xaya's requests in this session (verbatim, since 2026-11-06 16:00 UTC) and status

Logged in docs/process/REQUEST-LOG.md section A9 (S9-1 .. S9-7).

| Id | Her words | Status |
|---|---|---|
| S9-1..S9-3 | Question-box answers for the version / Patch Notes / Info pane (Help (FAQ) "built now", pane "Floats above, movable, Esc closes", What's New "minor updates ... 0.7.x vs 0.8.0", "append incremental updates to the top", Readme "sections 1, 2, 4, 5", FAQ groups) | ON MAIN since 687b624 (Options 0.6.56) and follow-ups |
| S9-4 | "I keep refreshing github and I see no major push to main. what the fuck is going on, nothing has been pullable." | ANSWERED (see log) |
| S9-5 | "Claude, I want you to stop focusing on build things and I want you to do actually organize all active sessions. priority should be making sure ALL completed work is pushed to main now. then clean up branches." | DONE: every tested branch is on main (52d07bc1); branch list docs/process/BRANCHES-2026-11-07.md. Branches are deleted by Xaya only. |
| S9-6 | (relayed) "Tell the landing session to merge whatever's missing from main that still lands cleanly and has qa test scripting for in game confirmation prompting available." | DONE (all landings below) |
| S9-7 | (relayed) standing rule: "every feature or significant change ... have an in game qa test walk through with pre-fill confirmation options or data capturing" | RULE V22, applied at every landing |

Orders relayed by the hub that this role follows: O-109 (D8 load condition stays off main), O-151 (no branch holds code not
reflected in main unless outdated/stale), O-152 (this migration), "no questions to Xaya" while the overnight queue runs.

## 2. Landing procedure (do every step, every push)

Work in a git worktree under the scratchpad, never in /home/user/XayaUI's checkout:

1. `git fetch origin main <branch>`; `git worktree add -B push-<n> <dir> origin/main` (or keep one worktree and reset it).
2. **Copy `tests/harness/api_index.json` into the worktree** (untracked; without it ~7 suites fail with nil errors that look
   like real bugs, e.g. AutoPicker.lua:213).
3. Merge with the helper (`mm.py`, copy below in section 8): it auto-resolves only MANIFEST.md5, QAWalks-Checklist.lua,
   InfoPaneData.lua (keep ours, regenerate), *.toc (highest Version, union of file lines) and union docs (QA-CHECKLIST,
   REQUEST-LOG*, PERF-CODE-NOTES). Anything else aborts and is resolved by hand or sent back to the owner.
4. Versions: every addon whose files changed in this landing must be **above main's** (precheck enforces). If two branches
   claim the same number, the later one moves up; edit the toc and the version mentions in its QA lines / walkthrough header.
5. QA ids unique: `grep -o '\*\*[A-K][0-9a-z]*\.\*\*' docs/QA-CHECKLIST.md | sort | uniq -d` must print nothing. The union
   merge duplicates items edited on both sides: keep the newer wording once.
6. Regenerate: `python3 tools/qa_walks_from_checklist.py`, `python3 tools/build_info_pane_data.py`, `python3 tools/manifest.py`.
7. Check every .toc still lists its files (`python3 tests/toc_files_run.py`, now part of the suite).
8. Full suite on the exact commit you will push (~5 min):
   `XUI_API_INDEX=tests/harness/api_index.json python3 tests/run_all.py; python3 tests/lua_pitfalls_run.py; python3 tools/precheck.py --base origin/main`
   Need: RESULT PASS / ALL CHECKS PASS, pitfalls FAILS 0, precheck FAILS 0. Never edit files while it runs.
9. `git fetch origin main && git merge-base --is-ancestor origin/main HEAD && git push origin HEAD:refs/heads/main`. Never force.
10. Tell the owner (hash + any relabel) and the hub; tell the feature-update session what landed (it writes PATCH-NOTES).
    Say "fast-forward" when main moves to the owner's own commit, so nobody mistakes it for a self-push.

## 3. Version registry as landed (main 52d07bc1)

| Addon | Version | Next free |
|---|---|---|
| XayaUI (core) | 0.6.73 | 0.6.74 |
| XayaUI_Options | 0.6.77 | 0.6.78 |
| XayaUI_Chat | 0.6.39 | 0.6.40 |
| XayaUI_QoL | 0.7.45 | 0.7.46 |
| XayaUI_Bonus | 0.6.29 | 0.6.30 |
| XayaUI_Reskin | 0.6.19 | 0.6.20 |
| XayaUI_DevAssist | 0.7.51 | 0.7.52 |
| XayaUI_Nameplates | 0.2.1 | 0.2.2 |
| XayaUI_Media | 1.0 | (assets only) |

Options moves with every PATCH-NOTES change (InfoPaneData.lua is in Options).

## 4. QA ids in use (highest on main)

A4, B279, C2, D30, E3 (E1z226, E2h), F29, G15, H10, I1, J31, K5. Hub-assigned ranges: function audit B260-B299, top tabs
B250-B259, D8 B240-B247 (held). Take the next number above the highest, and re-check after every union merge.

## 5. Branches expected next

| From | Branch | Notes |
|---|---|---|
| UI bugs successor (session_014bN6tVsL5WP5gZHkDeUhPN) | claude/ui-bugs-focused | ns.Tip slices 2+ (UI-51/52), audit follow-ups Q-UIB-9..15 |
| Reskin successor (session_014bN6tSvVzc2HRgXhwF3J2L) | claude/determined-cerf-981pn8 | held items RSK-Q4 (combat HUD), RSK-Q6 (skyriding), RSK-Q14 (micro menu / bags); user-facing strings must be US spelling (qa_walk_audit FA-16) |
| Perf successor (session_014bN6tTqaMKxGcnwALJ4CoU) | claude/perf-notes-*, claude/toc-files-test | mostly docs rows in PERF-CODE-NOTES; Q-PERF-5 settings click |
| Feature update summary (session_014bN6tU26cuzQ9LarKYhZQx) | claude/feature-update-summary | PATCH-NOTES + InfoPaneData + an Options bump each time; it does not run the full suite, you do |
| QA flow (session_014bN6tUZLKHa2NXorHRJghL) | qa-review-popup | QAQuestions.lua data; answers from Xaya will produce follow-up branches in the owning sessions |
| Nameplates | (handoff docs/process/handoffs/nameplates.md) | waits on NP-Q5 onward |

## 6. Held: D8 (O-109)

`claude/d8-raid-rules-ready` @ 248de57 (PR #446): the "People in my group" load condition + Release Guard built-in entry;
28 files vs main. Stays OFF main until Xaya releases it (D8-Q1). If she does: merge origin/main into it in a worktree,
expect conflicts in Options (rule editor), core (load conditions), Dev Assist toc; give it versions above section 3;
its QA ids B240-B247 are reserved; full suite; push. Its predecessors d8-raid-rules, d8-raid-rules-main, fervent-cerf
are superseded (heads in archive/2026-11-07).

## 7. Merge pitfalls seen tonight

- **Whispers.lua dropped from the Chat toc** (f753ba1, taking one side of a toc version conflict). The suite missed it because
  chat_246_whisper_run loads the file directly. Now caught by tests/toc_files_run.py. Never resolve a toc by taking a side.
- **Version clashes**: Bonus 0.6.27 (audit vs top tabs), Options 0.6.75 (two Patch Notes rounds), Dev Assist 0.7.34 / 0.7.46 /
  0.7.48 (three sessions each claiming main+1), Reskin 0.6.30 (a typo'd jump; relabelled 0.6.10). Precheck catches "changed but
  not bumped"; it does not catch two landings choosing the same number, so relabel when merging.
- **QAQuestions.lua ordering**: settings-restructure and the QA flow both edited it; land settings-restructure first, then the
  QA data on top, and take the QA flow's side of that file whole (its owner's instruction).
- **Behaviour split across features**: audit D31 restored the chat fade in the Chat Panel teardown, but after the UI-18/21 split
  the fade is Improved Chat's; fixed with C.RestoreTextFade (Chat 0.6.37). When two branches touch the same feature, read
  the owning switch, not only the diff.
- **Union merges duplicate QA items** edited on both sides (B197, D24, G1-G3); keep the newer text once.
- **prefill = true lost silently** when git takes the other side of a QAWalks line (dynamic-limit-align); qa_walk_run catches it.
- **"Blizzard UI Reskin" → "Blizzard Reskin"** (UI-24): pages landed after the rename must follow it.
- **US spelling** in walkthrough and Patch Notes text (qa_walk_audit FA-16).
- Owners sometimes report a suite run on a sibling tree (e.g. before a message-only amend); always run your own on the
  exact commit.

## 8. Tools

The merge helper used tonight (save as mm.py next to the worktrees; run `python3 mm.py <ref>` inside one):

```python
#!/usr/bin/env python3
# Merge <ref> into the current branch; auto-resolves only generated files, tocs and union docs; aborts otherwise.
import re, subprocess, sys
GEN = {"MANIFEST.md5", "XayaUI_DevAssist/QAWalks-Checklist.lua", "XayaUI_Options/InfoPaneData.lua"}
G = ["git", "-c", "user.name=Claude", "-c", "user.email=noreply@anthropic.com"]
UNION = lambda f: f == "docs/QA-CHECKLIST.md" or f.startswith("docs/process/REQUEST-LOG") or f == "docs/process/PERF-CODE-NOTES.md"
HUNK = r"<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n"
def run(*a, check=False): return subprocess.run(list(a), capture_output=True, text=True, check=check)
def vkey(v): return tuple(int(x) for x in re.findall(r"\d+", v))
def resolve_toc(path):
    def fix(m):
        lines = m.group(1).splitlines() + m.group(2).splitlines()
        vers = [l for l in lines if l.startswith("## Version:")]; dates = [l for l in lines if l.startswith("## X-Date:")]
        out = ([max(vers, key=lambda l: vkey(l.split(":", 1)[1]))] if vers else []) + ([max(dates)] if dates else [])
        for l in lines:
            if not l.startswith(("## Version:", "## X-Date:")) and l not in out: out.append(l)
        return "\n".join(out) + "\n"
    s = re.sub(HUNK, fix, open(path).read(), flags=re.S).split("\n")
    for key in ("## Version:", "## X-Date:"):
        idx = [i for i, l in enumerate(s) if l.startswith(key)]
        if len(idx) > 1:
            s[idx[0]] = max((s[i] for i in idx), key=lambda l: vkey(l.split(":", 1)[1]))
            for i in reversed(idx[1:]): del s[i]
    open(path, "w").write("\n".join(s))
ref = sys.argv[1]
run(*G, "merge", "--no-edit", "-q", ref)
u = run("git", "diff", "--name-only", "--diff-filter=U").stdout.split()
if not u: print("OK  ", ref); sys.exit(0)
bad = [f for f in u if f not in GEN and not f.endswith(".toc") and not UNION(f)]
if bad: run("git", "merge", "--abort"); print("CONFLICT", ref, "->", " ".join(bad)); sys.exit(1)
for f in u:
    if f in GEN: run("git", "checkout", "--ours", f)
    elif UNION(f):
        t = re.sub(HUNK, lambda m: m.group(1) + m.group(2), open(f).read(), flags=re.S); open(f, "w").write(t)
    else: resolve_toc(f)
    run("git", "add", f)
run(*G, "commit", "-q", "--no-edit", check=True)
print("OK  ", ref, "(resolved:", " ".join(u) + ")")
```

After any auto-resolve: check the toc version is above main, de-duplicate QA ids, regenerate, then the full suite.

## 9. Landings of 2026-11-07 (for reference)

72a75126 (5a) → 9acf7fcb (5b, audit + D31 fade fix) → a0b0d1ef (6a, reskin elements) → d8960d80 (6b, top tabs) → 672af3f6
(toc_files test) → 9ab82dce (overnight Patch Notes) → 5c7b3723 / ac0ca795 (reskin pages, fast-forwards) → 84782049 → 2bbc985d
(UI bugs successor) → 6b525b7a (reskin Buttons) → 9a6a43ec → 89f09bb0 → 8ca0e665 → efbf5885 → 291746e0 → f81561d0 (QA data,
fast-forward) → 3e706945 (BRANCHES, fast-forward) → 52d07bc1 (hub final docs, BRANCHES 5dd001d, Patch Notes 2fe281c).
Each had the full suite + pitfalls + precheck green on its exact commit before the push.

## 10. Open questions sent to the flow by this session

None open. (The pane's questions S9-1..S9-3 were answered by Xaya.)

## 11. Next steps for the successor

1. Confirm to the hub that you read this file and that `git log -1 origin/main` matches the hash the hub gives you.
2. Keep one worktree with api_index.json copied in; land incoming branches with section 2.
3. Never delete branches; never force-push main; keep d8-raid-rules-ready off main until Xaya says otherwise.
