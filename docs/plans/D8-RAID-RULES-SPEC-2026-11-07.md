# D8: Release Guard as a built-in entry under "Raid Rules" (spec for a dedicated session, 2026-11-07)

Written by the engine session 2 (session_014bN6tT7n9v9sqt7pBjKmcc, branch claude/fervent-cerf-hldtwn) when Xaya chose "Fresh session
(Recommended)" for the rest of D8. Every requirement below is her answer, verbatim, from the question prompt
(docs/process/QUESTIONS-engine-session.md, rounds 5 and 7). Anything not settled here is proposed to her first (V16, V19: through the
question prompt). Read docs/process/VERIFICATION.md (V1-V21) and the xayaui-change skill first.

## Her words (verbatim)
- Round 5: D8 = "Rule drives the cover" (the Release Guard cover's on/off is decided by load conditions, not QoL's own setting).
- Round 7:
  - Load: "Load conditions: in instance - raid party size => 20"; the size is "People in my group" (players in your group, at least N).
  - "If it's not enabled it does not exist" (Release Guard's own switch: while off nothing of it is created, registered or hooked: V14).
  - "It has to be enabled (it's not exactly a rule) and then the load conditions are applied after enabling / disabling."
  - "It belongs in "Raid Tools" under rules for now"; corrected: "Sorry, “Raid Rules”".
  - Where: "A group in the sidebar" (a fixed "Raid Rules" entry in the Rules sidebar, like a Smart Category, with Release Guard inside it as
    an item to click and edit).
  - Build approach: "Yes, built-in entry": a fixed "Release Guard" entry inside a fixed "Raid Rules" group; it has the same Load tab as a
    rule; its on/off switch is the guard's on/off; it has its own settings page (text, flavour texts, modifier key) instead of Trigger /
    Cues; it is listed under Rules > Enabled or Disabled like a rule; it cannot be deleted or exported; its sidebar row has no eye /
    headphone.

## Already built (engine session 2; reaches main with the next combined push or after it)
- Player State trigger "Dead, not released" (Triggers.lua; UnitIsDead and not UnitIsGhost; unreadable = unknown).
- Load condition "People in my group: at least N" (renumbered core 0.6.70 / Options 0.6.71 / QA B247; ships with D8 on claude/d8-raid-rules-main) (Conditions.lua ReadContext ctx.groupSize, CheckContextRaw load.groupMin; Options rule
  Load tab slider; test tests/load_group_size_run.py; QA B213; first built as core 0.6.59 / Options 0.6.60).

## To build
1. Storage and migration. Release Guard today: XayaUI_QoL/ReleaseGuard.lua (S1's; S1 agreed this session changes it: "please do the whole
   D8 change yourself ... LoadsHere -> the shared load check, c.load raid/group/all migrated to a load table, old saved settings kept").
   Saved settings: CueRulesDB.releaseGuard { enabled, text, flavorOn, flavors, modifier, load = "raid" | "group" | "all", index }.
   - Give it a rule-style load table. Default (her words): in an instance, instance type Raid, people in my group >= 20:
     { instance = "yes", instanceTypes = { raid = true }, groupMin = 20 }.
   - Migration of the old c.load string (PROPOSE to her before building, V16): "raid" was also the default, so it cannot be told apart from
     an explicit choice. Suggested: "raid" -> her default above; "group" -> instance yes + instance types Raid and Dungeon (no size);
     "all" -> no conditions. Keep the old value in a backup field.
2. Shared load check for non-rule features: core function (e.g. ns.LoadAllows(loadTable)) that runs the same check as a rule's Load
   (Conditions.lua CheckContextRaw on a stable pseudo record; memo by table). ReleaseGuard.lua LoadsHere(c) uses it.
3. The built-in entry ("behaves like a rule where that helps"):
   - A fixed group "Raid Rules" in the Rules sidebar (a Smart-Category-like fixed folder) holding one entry "Release Guard".
   - Listed under Enabled while the guard is on, under Disabled while off (like a rule).
   - Its editor: the rule Load tab (extract the Load builder from Options.lua BuildRule, lines ~1896-2136, into a shared builder) plus a
     Release Guard settings page: on/off, text (default "NO RELEASE"), flavour texts on / list (her five: "BAD MONKEY", "death comes for us
     all", "NOPE", "Disagree", "WTB Rez"), modifier key (Shift / Ctrl / Alt). These move out of the QoL tab (QoL > Release Guard row).
   - Not deletable, not exportable, not duplicable; no eye / headphone; the engine never evaluates it (it is not a cue rule).
   - Every place that lists, deletes, exports, duplicates, moves, multi-selects, counts or exports profiles must handle it (git grep
     DeleteRule, ExportRule, DuplicateRule, MultiDelete, MultiMove, AddMoveMenu, RowMenu, Share kinds, Smart categories, Drafts).
   - Design choice to PROPOSE first (V16): whether it is a real record in ns.rules (builtin = "releaseGuard") or a virtual row; whether
     the "Raid Rules" group can hold her own rules too.
4. V14: while the guard is off nothing of it exists (no frame, event, hook); the load conditions apply only once it is on.
5. Tests: extend tests/release_guard_run.py (17 checks today): migration from each old c.load value; the load conditions decide the cover
   (raid + 20 players yes, 19 no, dungeon no); "If it's not enabled it does not exist" (nothing registered or hooked while off); the sidebar
   entry is listed under Enabled / Disabled, cannot be deleted / exported / duplicated, has no eye / headphone; the Load tab writes the
   guard's load table. Every new test fails on the old code (V1).
6. Docs: debug-log entry, QA steps (next free B number at the time), docs/USER-GUIDE.md, request log, a CLEAN-8 code note to the
   performance-test session (session_014bN6tTxYo6enpkMGsVkMqm), V18 what's-new to session_014bN6tU26cuzQ9LarKYhZQx after landing.

## Coordination
- S1 (session_014bN6tWZxqCW85vMEyHdfnt) owns QoL; agreed this change; QoL version numbers agreed at landing.
- Combined pushes to main go through the collecting session of the moment (ask "Outstanding items 11-06", session_014bN6tSStpdmmCXviFAqPdQ).

## Conservative readings (D8 session, 2026-11-07; built without asking: her "stop asking me questions until everything that is more than
6h old is completed and on main"). Each is open to her correction; none loses a saved setting.
1. Migration of the old "Where": a value she changed keeps exactly its behaviour ("group" = in an instance, Raid or Dungeon, any size). A
   saved "all" takes her default (UI-58, her words: "There also should not be an everywhere button"; QoL 0.7.39 already turned it into
   "raid"). "raid" was the default and cannot be told from untouched: it takes her stated default (Raid, at least 20). The old
   value is kept in c.loadOld.
2. Virtual row, not a record in ns.rules: settings stay in CueRulesDB.releaseGuard; the engine, export, delete, duplicate, multi-select and
   drag never see it.
3. The RAID RULES group holds Release Guard only (her "for now"); her own rules cannot be moved into it.
4. The group sits in the Smart Categories sub-tab (where the fixed categories are); the entry is also listed like a rule under Enabled
   (Loaded / Not Loaded) or Disabled, and counted there.
5. The QoL tab's Release Guard row is removed (her "These move out of the QoL tab"), not left as a pointer.
6. Its row's right-click menu: Enable / Disable only. Its Load tab is the full rule Load tab, talents included.
