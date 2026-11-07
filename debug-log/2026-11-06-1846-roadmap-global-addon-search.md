# Roadmap: global addon search added as RM-GSEARCH (docs only)
Logged 2026-11-06 18:46 UTC. Session branch `claude/ecstatic-cori-sfi3hk`. Nothing in the addons changed (no version bump, no QA-CHECKLIST step: no code).

## Request (Xaya, 2026-11-06, her words)
"add to the roadmap feature list a global addon search to look for all hits of a given search query (settings, user-generated rules, options, etc)"

## What changed
- ROADMAP.md: new section "Logged 2026-11-06" with row RM-GSEARCH (Candidate, nothing built); a pointer from M4 (section 5); RM-GSEARCH added to the waiting-on-decision list (section 10).
- The row records her words verbatim. The first-stage description is labelled as a reading of her words, not hers, and the six open questions are for her (V16: nothing is built until she answers).

## Checked in the repository (for the weakest point)
- A per-rule option search exists: `XayaUI_Options/RuleSearch.lua` (header: smart keywords, `/pattern/`, up to 12 results, click opens the tab; Xaya 2026-11-04). The sidebar filter is #132 / M4 (from ROADMAP).
- Settings pages are built by functions on demand: `ns.RegisterSettingsPage` and `ns.BuildSettingsPages` in `XayaUI/Modules.lua` (lines 16, 203, 284). The settings window is a load-on-demand addon.
- INFERENCE, not tested: a search over options needs either those page trees built or a hand-kept index; which is cheaper was not measured.
