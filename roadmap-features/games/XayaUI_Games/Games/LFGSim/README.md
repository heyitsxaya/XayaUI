# LFG simulator: not designed

Waiting on plan question 1 (`docs/plans/GAMES-MODULE-2026-11-05.md`): what "LFG simulator" means.
- (a) A game: you lead a made-up group-finder listing and choose from made-up applicants.
- (b) Practice for the real group finder.
- (c) Something else.

These limits hold whichever reading it is:
- It never calls the real group-finder calls. `C_LFGList.Search` and `C_LFGList.CreateListing` have HasRestrictions (`docs/reference/api/namespaces.md:3019`, `:2952`). Every listing and applicant is made up.
- Made-up applicant names must never be real players' names.
- Real activity names could add flavour through `C_LFGList.GetActivityInfoTable` (MayReturnNothing, `:2963`). This is INFERENCE and is not tried.

Once it is designed, it follows the word game's shape: a rules file without frames, a modes file and a UI file, registered with `Games.Register`.
