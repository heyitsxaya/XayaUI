# In-game QA walkthroughs: /xui dev qa (XayaUI_DevAssist 0.7.4, core 0.6.55)
Logged 2026-11-06 17:45 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Nothing here has run in the game.

## Her words
- Standing rule: "For all things you need me to debug or QA in game — wherever possible, design and implement a test script or
  walkthrough that fires in the game side so it removes all friction for a less technical friend. All they should have to do is open
  up /xui dev qa and pick an item and have the addon walk them through steps with as limited console interaction as possible".
- Her answers (question flow):
  - "In the Dev Assist addon";
  - "Check, then ask to confirm";
  - "Screenshot, import/export result code, saved file support — all options should be allowed to remove all points of friction";
  - "Both, but start with this session and push older items into a map over the next several days".

## What was built
- **`XayaUI_DevAssist/QAWalk.lua`:** the framework.
  - `XayaUI_DevQA.Register(id, { title, qa, order, steps = { { text, setup, check } } })`.
  - A window made on first open (V14): the list, one step at a time, Do it for me (`setup`), the addon's own check (shown, never
    answers), Pass / Fail / Skip, a note, Back.
  - The end screen offers Screenshot (`Screenshot()`), Export code, Import a code and Run again.
  - Results are saved in `XayaUIDevAssistDB.qa.results`, without names or realms.
  - Codes are `XUIQA1:` + base64 of plain lines. On import, only id / when / v / step lines are read, each length-capped; "|" and
    control characters are removed; a code over 8000 characters is refused.
- **`XayaUI_DevAssist/QAWalks.lua`:** this session's walkthroughs: group page (B171-B172), group size / border / background (B174),
  nested group (B175), sidebar drag (B173), Blizzard UI Reskin switches (E2e), Shopping List (E2a / E2g / E2h). The group ones make
  "QA test group" (two sample rules shown as previews) and delete it in their last step.
- **Commands:**
  - `/xui dev qa` is registered by Dev Assist through core's `ns.RegisterCommand`; `/xuidev qa` is added to its own command.
  - Core: with Dev Assist off, `/xui dev` says to switch it on. Core finds Dev Assist only through its service `gameDataProbe`, so it
    never names the folder (`devassist_rename_run`).
  - Not listed in `/xui help`, so the help count stays 17.

## Limits
- Screenshot uses the game's `Screenshot()` (globals.md:480). INFERENCE: callable from an addon out of combat; not tried in game.
- "Do it for me" steps call XayaUI's own functions. Where XayaUI QoL or Options is off, the step says it could not do it.

## Tests
- `tests/qa_walk_run.py` (new, 25): no window before opening, `/xui dev qa` and `/xuidev qa`, a full run with notes and Back, the
  saved result, Screenshot, the export / import round trip, refused and cleaned codes, the cleanup step, the list status.
- `modules_run`, `console_commands_run` (92), `devassist_*_run`, `lua_pitfalls_run` pass. QA B176.

## The checklist walkthroughs (same day, after "High priority qa items should also be shipped in this first batch")
- Her words: high priority = "Combat display checks, Things you called urgent, Open bugs not yet checked, Everything on main not
  checked"; order: "start with bugs, then UI items that don't impact usage".
- **`tools/qa_walks_from_checklist.py`** writes **`XayaUI_DevAssist/QAWalks-Checklist.lua`** from `QA-CHECKLIST.md` and
  `docs/process/qa-open-bugs.json`: 32 walkthroughs of at most 12 steps, 287 open items. Each item is in one walkthrough only.
  1. Open bugs to confirm: the 17 open issues labelled bug + unverified-in-game (97, 315, 319, 331, 332, 333, 340, 344, 346, 347,
     348, 351, 352, 353, 359, 364, 365), each with the QA IDs that name it.
  2. Looks and layout (no effect on use): 56 items. INFERENCE: chosen by a word rule (look / layout words such as label, colour,
     width, border, tab, tooltip; and none of combat, trigger, fire, sound, save, load, cast, aura, proc, delete, error).
  3. Combat displays: section B-engine. 4. Urgent: #268, #368-#370, the character pane / reskin. 5. Everything else, per section.
- Each step carries its checklist ID (`key`, or `bugNNN`). The saved result and the export code keep it (`kN=` lines), so a result
  still points at the right item after the checklist changes and the walkthroughs are rebuilt.
- The list and the step text scroll (mouse wheel).
- **Upkeep:** after a checklist change, run `python3 tools/qa_walks_from_checklist.py`; `tests/qa_walk_run.py` fails while the
  file is out of date. `qa-open-bugs.json` is refreshed by hand from the issue list (gh is used only for search).
- `tests/qa_walk_run.py`: 32 checks (adds the generated walkthroughs, their order, the scroll, the saved keys and the sync check).
