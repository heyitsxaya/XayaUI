# American spelling in every text the player sees (core 0.6.67, Options 0.6.69, QoL 0.7.42, Bonus 0.6.27, Dev Assist 0.7.19)
Logged 2026-11-07 06:19 UTC. Session 014bN6tSfFULX4BSXzmZ1yCx, branch `claude/function-audit-land`. Not run in the game.

## Request (REQUEST-LOG A11 FA-16 / FA-17, her words verbatim there)
"Make sure all UK/CAN/AUS/NZ spellings of words are not reflected into the addon (including words like “favour”). This also applies to
patch notes, what’s new text — literally every text in the addon should follow American spelling rules" and (FA-16) "Except use the
spelling “grey” instead of “gray”".

## Reading used (FLAGGED: built on the most conservative reading, per her FA-20 "stop asking me questions ... ship")
- Changed: text the player sees: labels, tooltips, descriptions and chat lines (Lua string literals only), the .toc Notes shown in
  the AddOns list, and the texts shown in game or read by players: PATCH-NOTES.md, docs/README-INGAME.md, docs/HELP-FAQ.md (the Info
  pane; InfoPaneData.lua regenerated), docs/WHATS-NEW.md, docs/USER-GUIDE.md, docs/QA-CHECKLIST.md (shown in the QA walkthroughs;
  QAWalks-Checklist.lua regenerated).
- Not changed: code comments, file names (AuraCatalogue.lua), saved-setting keys and table fields (none had a British spelling in a
  key the player's saved data uses: e.g. `flavorOn`, `colorMode` were already American), `code` spans in the docs, and her own
  quoted words in the request logs (kept verbatim).
- "grey": her FA-16 exception is kept (the resend FA-17 did not retract it): player-visible "gray" became "grey" ("Grey out while the
  spell is on cooldown", "(none - grey)", "shown in grey under the trigger number").
- Command words: `/xuidev catalogue` keeps working (it already accepted `catalog` as well); help and docs now show `catalog`.

## Words changed (counted from the diff)
colour / colours / coloured -> color / colors / colored (322), catalogue -> catalog (21), centre / centred / centres -> center /
centered / centers (20), gray / grays / grayed -> grey / greys / greyed (14), flavour -> flavor (7), neighbour -> neighbor (2),
recognised -> recognized (2), labelled -> labeled (1), cancelled -> canceled (1).
Second pass (the audit walkthrough's own spelling check found what the first scanner missed: prefixed words and the -red forms of
-re words): centred -> centered (33), recoloured -> recolored (3). One of the centred ones is inside a quote of her earlier answer
in docs/QA-CHECKLIST.md ("Titles centred over columns"); the checklist is shown in the in-game walkthroughs, so it follows this rule.
Found with a scanner (Lua string literals only; word list of British / Commonwealth spellings: -our, -re, -ogue, -ise/-yse, doubled-l,
licence / defence, whilst / amongst, learnt / spelt, programme, judgement, ageing, ...). After the pass the scanner finds none in
player-visible text (the only match left is the command word `catalogue`, kept so typing it still works).

## Tests
info_pane (43 pass: the Info pane data matches the markdown), lua_pitfalls 0 fails; the full suite runs on the landing commit.
