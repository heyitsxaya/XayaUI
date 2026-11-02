# HANDOFF 2026-11-02 (13:54 ET / 18:54 UTC): combat-engine chat + local/Drive sync to main

Audience: every Claude instance working on XayaUI. Written by Claude Code session 014bN6tU (https://claude.ai/code/session_014bN6tU1iYkbm3EKdKQxBuS), the in-combat aura tracking chat. Facts below come from commands run in this chat; inferences are marked (inference). Read section 1 before touching the local folder.

## 1. SYNC STATE (verified 18:54 UTC)
| Place | State |
|---|---|
| GitHub `main` | `77bb26f` = 0.5.43 + manifest fix (see 3.6). |
| Local addon folder `...\_retail_\Interface\AddOns\XayaUI` | All 208 tracked files byte-identical to `main` (checked with `git hash-object` per file). `md5sum -c MANIFEST.md5`: 49/49 OK. |
| Google Drive copy `...\My Drive (heyitsxaya@gmail.com)\Claude\Claude Projects\_heyitsxaya_\XayaUI\XayaUI` | All 203 tracked files byte-identical to `main` (`Claude outputs/` excluded by the sync rule). 49/49 OK. Was stuck at 0.5.29 before this. Google Drive adds `desktop.ini` files; ignore them. |
| Local folder's own git repo | **Not realigned.** `HEAD` is still `1d084b5` (old local `main` with unpushed aura commits). The working tree now equals GitHub `main`, so `git status` there shows many changes. See 4.2. |
| `stable` branch | `3c0c741` = 0.5.32, while `main` is 0.5.43. **Violates the stable rule** (at most one version behind). Not moved by me because 0.5.33 to 0.5.43 are all "Untested in game"; Xaya decides. |

How the local folder was synced: `git archive` of `main`, extracted to a scratch dir on the device, then every file copied over in place (`tar -x` straight into the folder fails: deleting files there is not permitted, so tar cannot replace them). Nothing was deleted. Untracked local files (`.bak`, backups) untouched.
Before overwriting, the local files that differed were checked: none had content missing from `main` (local `Core.lua` and `XayaUI.toc` were `main` minus the 0.5.39 chat-privacy lines; `ChatReskin.lua` was the 0.5.37 version; `Options.lua`, `README.md` already matched). Copies of the pre-sync local versions: `Desktop\probe-snapshots\pre-sync-local-20261102\`.

## 2. RULES FOR ALL INSTANCES (from what went wrong today)
1. **Never copy a local file over GitHub's without checking it is newer.** The local folder had a mix: an older `XayaUI.toc` / `Core.lua` without ChatPrivacy, and `ChatPrivacy.lua` missing, while `main` was correct.
2. **Regenerate `MANIFEST.md5` from the GitHub clone, not from the local folder.** `main`'s manifest carried the 0.5.37 checksum for `ChatReskin.lua` for four releases because it was rebuilt from a stale local copy.
3. **Finish all four sync steps for your own change** (XAYAUI-SYNC-RULE): GitHub, local folder, Drive, checksums in both folders. Drive was left behind for 14 versions.
4. **Sibling folder:** `XayaUI_CombatEngine/` (6 files) is part of the repo. Copy it with everything else; the manifest lists its files with paths.
5. **Do not remove line 6 of `Core.lua`** (`ns.name = addonName; XayaUI_NS = ns -- ...`). It is the bridge the combat engine needs. An older `Core.lua` without it makes the combat engine run disconnected (no error, tracking silently stops feeding rules) (inference from the code).
6. **Do not re-add `AuraModel.lua`, `AuraTracker.lua`, `AuraSetup.lua`, `AuraIDProbe.lua` to `XayaUI.toc`.** They load from `XayaUI_CombatEngine/XayaUI_CombatEngine.toc`.
7. **Ownership:** the combat-engine instance owns `XayaUI_CombatEngine/`. Everything else belongs to the core instances. Changes to the bridge need both.
8. Device mount names change when folders are granted; identify folders by content (WoW folder has `.git`), not by mount name.
9. Ref writes through the GitHub REST API are blocked by the session proxy; push with `git push` from a clone (fetch first).

## 3. WHAT THIS CHAT CHANGED (chronological, UTC)
1. **Probe 0.5.26 -> 0.5.27** (`XayaUI_CombatEngine/AuraIDProbe.lua`): out-of-combat identity logging (spell, name, duration, lifetime per aura added/removed) in `CueRulesDB.idProbeStream`. Diagnostic only.
2. **Combat findings** (project docs `claude/XAYAUI-COMBAT-AURA-PROBE-RESULTS-2026-11-02.md`, `claude/XAYAUI-COMBAT-AURA-EVENT-STREAM-RESULTS-2026-11-02.md`):
   - In combat, addon code cannot read aura instance IDs (ID list refused; UNIT_AURA payload fields are secret).
   - The PRESENCE of added/updated/removed in each UNIT_AURA event is readable. Checked against a combat log: every logged removal (37/37), add (41/41) and refresh (268/268) had a matching flag within 0.15 s; flags arrive 0 to 110 ms after the real event. A flag says that some aura changed, not which.
   - Metamorphosis 187827 (Vengeance): 20 s normal cast (15 s base + Vengeful Beast 1265818 +5 s), 10 s when cast free via Untethered Rage (1270476). Same aura ID.
3. **Apex talent data**, all 13 classes / 40 specs: `claude/XAYAUI-APEX-TALENTS-2026-11-02.md` and `Desktop\apex\apex-talents.csv`. Not in the addon.
4. **0.5.29 (`0c6b6c3`): combat engine split into sibling addon `XayaUI_CombatEngine/`** (WeakAuras-style), own toc with `## Dependencies: XayaUI`, interim bridge global `XayaUI_NS`. Details: `XayaUI_CombatEngine/README.md`, project doc `claude/XAYAUI-COMBAT-ENGINE-SPLIT-CONTRACT-DRAFT-2026-11-02.md`. `stable` was moved to 0.5.28 first (it has since been moved to 0.5.32 by another instance).
5. **Issue #227**: prep outline for splitting Options into `XayaUI_Options` (no code changed).
6. **`77bb26f`: `MANIFEST.md5` fix** (ChatReskin.lua checksum). No code change, no version bump.
7. **Local folder and Drive synced to `main`** (section 1).

## 4. PENDING (Xaya)
1. **The combat engine is NOT loading in game yet.** The AddOns folder has no `XayaUI_CombatEngine` entry. Create the junction once (Command Prompt, as administrator if refused), then fully restart WoW:
   `mklink /J "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\XayaUI_CombatEngine" "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\XayaUI\XayaUI_CombatEngine"`
   Then check: "XayaUI Combat Engine" in the AddOns list, `/xui probe ids` answers, Combat Tracking Setup opens.
2. **Realign the local git repo** (its files already match `main`). In Git Bash or a terminal in the XayaUI folder:
   `git branch backup/local-1d084b5-20261102` (keeps the old local commits), then `git fetch origin`, then `git reset origin/main` (mixed reset: moves the branch, keeps files). `git status` should then show only untracked files. Git needs delete permission for its lock files in that folder.
3. Decide where `stable` should point (section 1).
4. Everything from 0.5.29 on is untested in game.
