# Rule editor folder: XayaUI_Rules_Options is its own load-on-demand addon (Options 0.6.87, XayaUI 0.6.77, XayaUI_Rules_Options 0.6.77; platform split P4b)

Logged 2026-11-07 22:14 UTC. Branch `claude/lucid-mayer-pv4ytn`, on main 767b498 (P4 at 232552d plus two Patch Notes commits).
Plan: `docs/plans/PLATFORM-SPLIT-2026-11-07.md` sections 3, 7, 9 (Q1, proposed answer in use), 10, 11 (R3). P4 debug log section "Left in
place / for Xaya" listed the three blockers solved here. No saved data moves; nothing a player sees changes (tests below).
Versions: Options 0.6.87, XayaUI 0.6.77 (Modules.lua, one call), XayaUI_Rules_Options 0.6.77 (new), Dev Assist 0.7.58 (walkthrough).
XayaUI Rules: no code change (stays 0.6.76). QA step H15; walkthroughs "rule-editor-folder" (part 1) and "rule-editor-folder-off"
(part 2, after the /reload), `XayaUI_DevAssist/QAWalks-rule-editor-folder.lua`.

## Move map

| Old | New |
|---|---|
| XayaUI_Options/RuleEditor/*.lua (14 files) | XayaUI_Rules_Options/*.lua (git mv; same names, toc order: the six that loaded before Options.lua first, then the eight after it) |
| RuleEditor/Sidebar.lua: MakeChevron, NEUTRAL_TINT, SelectedUV, TREE_GRAD / TREE_BAR, RowTier / PaintRowText / HookRowHover, PaintBanner, SIDE_COL, Tree.RowSwitch / SwitchClick / OneSentence / SwitchTip / PaintRowSwitch, DecorateButton (generic part), SafeDecorate, DecorateTree | XayaUI_Options/TreePaint.lua |
| RuleEditor/SpellSearch.lua: LeftRestore, HookRelease, LeftAlign, Walk, ns.DecorateTrees | XayaUI_Options/TreePaint.lua |
| DecorateButton's rules-tree parts (BANNER_TINT tiers, ROOT_KEYS / UPPER_ROOTS, spacer rows, guide bars, multi-select wash, Resolve, Smart Categories rows, menus / drag / rename hooks, reorder arrows, QoL row tick boxes, eye / headphone, Smart Categories note, locks) | stay in XayaUI_Rules_Options/Sidebar.lua as `ns.OptionsApi.TreePaint.rules` (RowKind, BannerTint, Spacer, Begin, Hooks, Reorder, RowToggle, Icons, Note, Side); SpellSearch.lua adds `Widget` (spell tooltips, search boxes) |
| Options.lua line `ns.OptionsApi.AutoPicker = ns.AutoPicker` | XayaUI_Rules_Options/AutoPicker.lua |

Every moved block is the old text (extracted by line ranges); the only edits are the hook calls replacing the rule-specific lines,
in the same order as before (TreePaint DecorateButton: PaintBanner, then rules Begin = guides, multi-select, Resolve, Smart-Categories
"gone" rows, then the xuiGone restore, rules Hooks, ... rules Side last).

## The three P4 blockers
1. **Painting.** DecorateButton / DecorateTrees painted every tab's rows (the feature tick boxes too) and Skin.lua wraps ns.DecorateTrees
   at its load. The generic painting is now XayaUI_Options/TreePaint.lua (toc: after Options.lua, before Skin.lua, so Skin.lua wraps
   it as before); the rules tree's parts are hooks the editor registers when it loads. With XayaUI Rules off, TP.rules is nil and the
   rows are painted with the generic part only, which is what the old code did for feature rows (its rule parts returned nothing for
   them: Resolve nil, no multi-select, ROW_TOGGLES miss, no note; PaintGuides draws nothing while ns.TREE_BARS_ENABLED is unset).
   Behaviour difference, Rules off only: the old code also hooked OnClick / drag / double-click on feature rows (they did nothing there);
   now no hook is placed (V14).
2. **Load order.** The six editor files that loaded before Options.lua used nothing of it at load except one line in Options.lua
   reading ns.AutoPicker (moved into AutoPicker.lua). In the new addon every file loads after XayaUI_Options. Wrap order checked:
   Options.lua's hooksecurefunc on AceConfigDialog Open / FeedGroup and its Open wrap still come before RulesTree.lua's FeedGroup /
   SelectGroup wraps (as in P3); Skin.lua wraps nothing the editor wraps.
   Options.lua now reaches the editor only through `ns.OptionsApi.RuleEditor` (`RE`): BuildRulesTab, SettingsRows, SelectedRule,
   StatusText as in P3, plus the 21 functions it called on `ns` (DraftsOnOpen, SaveRulesSub, DeleteKey, UndoKey, Multi*, SaveBarUpdate
   ...), published at the end of RuleSettings.lua (the addon's last file). Skin.lua's 4 multi-select calls the same way. Every call is
   guarded (DeleteKey, MultiReset, MultiDelete, MultiClear, IsEditLocked and the strip's SelectedRule were not).
   **Loading:** `ns.OptionsApi.LoadRuleEditor()` (Options.lua), once per session, only while the "rules" service is there (XayaUI
   Rules on): `C_AddOns.LoadAddOn("XayaUI_Rules_Options")`. Called by core right after XayaUI_Options loaded (Modules.lua
   ns.LoadOptions -> ns.Options.AfterLoad), which is every way into the window (/xui, minimap, ns.EditRule, ns.EditFolder,
   ns.OpenSettingsPage, Dev Assist's ns.LoadOptions), and by Toggle for a caller that loaded XayaUI_Options another way. Loading after
   XayaUI_Options returned (not from inside its own files) avoids loading an addon whose dependency is still loading.
3. **Navigation.** ns.OpenPage("drafts" / "creator"), ns.OpenDraftSettings, ns.UI.Creator / ns.UI.Drafts stay in Options.lua. The
   editor is loaded before any of them can be reached (they exist only once XayaUI_Options is loaded, and LoadOptions loads the
   editor right after); with the editor absent (XayaUI Rules off, or the folder missing) they return at once. The Rules tab and the
   Settings rule rows are built only when the editor is there (EditorOn = XayaUI Rules on and BuildRulesTab present).

## V2: the API
`C_AddOns.LoadAddOn(name: uiAddon)` -> `loaded: bool?, value: string?` · SecretArguments=AllowedWhenUntainted
(docs/reference/api/namespaces.md:164; the entry in full; no further documented edge cases). `C_AddOns.IsAddOnLoaded(name: uiAddon)`
-> `loadedOrLoading: bool, loaded: bool` (namespaces.md:162; used by the walkthrough). Blizzard's own UI source is not in this
repository (no FrameXML copy, tests/harness has no framexml index), so how Blizzard's UI calls LoadAddOn was not checked; the call
follows core's own use for XayaUI_Options (Modules.lua ns.LoadOptions: pcall, then the addon's state for the message).
INFERENCES: that the game loads a LoadOnDemand addon whose dependencies are all loaded when LoadAddOn is called after the dependency's
LoadAddOn returned (the stand-in does); that `## LoadWith` (not in docs/reference) would be an alternative; not used.

## Load timing
| | At login | First window open | Later opens, EditRule, OpenPage ... |
|---|---|---|---|
| XayaUI Rules on | XayaUI, XayaUI_Rules (no Options file, no editor file) | XayaUI_Options (incl. TreePaint.lua), then XayaUI_Rules_Options (14 files, once) | nothing more |
| XayaUI Rules off | XayaUI | XayaUI_Options only; none of the 14 editor files (they were read before P4b: V14 now "never loads", strict) | nothing |
| XayaUI Rules on, editor folder missing / off | as on | XayaUI_Options; one XayaUI message; no Rules tab | nothing |
Harness file counts: Rules + Options 91 -> 92 files (TreePaint.lua); Options without Rules 90 -> 77.

## V4 scope (what names the moved code)
- tocs: XayaUI_Options (14 lines out, TreePaint.lua in), XayaUI_Rules_Options (new), XayaUI_DevAssist (walkthrough).
- Platform: XayaUI/Modules.lua ns.LoadOptions (AfterLoad). Options.lua (RE calls, EditorOn, LoadRuleEditor, guards), Skin.lua (4 calls).
- Dev Assist readers (through ns.OptionsApi, unchanged names): QAWalks.lua (EditRule / EditFolder after ns.LoadOptions, DeleteFolderAll),
  QAWalks-audit*.lua, QAWalks-display.lua (SIDE_COL, now TreePaint.lua), QAWalks-generate.lua (AutoPicker, now set by AutoPicker.lua),
  CoreDebug.lua (IconReport after ns.LoadOptions). tools/: none name the files (manifest, precheck, qa tools use `XayaUI*`).
- Install lists: README.md (table row, install line), docs/QA-CHECKLIST.md A1.
- Static cross-addon check (tests/harness/run.py boundary_checks): unchanged rule; it flagged Options.lua / Skin.lua using 21 names
  of the new addon, which is why they go through ns.OptionsApi.RuleEditor now; and one ns.UI use in the new walkthrough (fixed).

## Tests
- New `tests/tree_paint_parity_run.py`: what is drawn (every shown tree row's height, alpha, font, colour, text, anchors, insets and every
  decoration's anchors / size / tick state; headings and tab boxes) on every tab and Rules sub-tab (and with a rule selected), XayaUI
  Rules on and off, against a golden made on 232552d (`tests/tree_paint_parity_golden.json`): identical (20 checks). Negative controls:
  the name inset +1 px in TreePaint.lua fails 14 checks; the spacer rule changed in the hook fails 1; on 232552d the V14 check fails.
- New `tests/rule_editor_load_run.py` (22 checks): Rules on, the 14 files are read once from XayaUI_Rules_Options with one LoadAddOn at
  the first open and never again (re-open, EditRule, OpenSettingsPage, Drafts, Creator, Rule Creation, which land on their tabs);
  Rules off, none read and no load asked, the navigations do nothing; folder missing, no Rules tab and one message. On 232552d: 7 fail.
- New `tests/qa_walk_rule_editor_folder_run.py` (12 checks): both walkthrough parts with their verdicts; fails on 232552d (no walkthrough).
- `tests/options_split_parity_run.py`: unchanged, passes against the existing golden (Rules on and off: 95 checks).
- Paths / setup only: art_picker, art_rows, aspect, cue_volume, load_class, debug_record, drafts, spell_search_scope (file paths);
  count_gcd, recycle_bin (glob of the editor folder); drag_drop, preview_layout, trigger_parity, core_off_costs_nothing,
  options_bonus_off_costs_nothing (XayaUI_Rules_Options in the enabled list; the latter's OnUpdate counter also counts the editor's
  folder as the window's); settings_seam (the new folder's name taken out of the installed-addons lists, as P4 did for XayaUI_Rules);
  tooltip_parity (0 KB for the new folder in the memory list, as P4 did); tests/harness/run.py (XayaUI_Rules_Options always on, plus
  one combination without it: 67 combinations).

## Left for Xaya
- Wording written here: the toc Title "XayaUI Rules Options" and Notes; the README row; the three messages when the editor cannot
  load (disabled / not installed / other), modelled on the XayaUI Options ones; QA H15 text.
- Whether a missing editor folder should say anything at all (now: one message per session) is hers.
- UNTESTED IN GAME.
