# Terms check: Blizzard EULA, Blizzard's add-on policy, wago.tools (documentation only; no code changed)
Logged 2026-11-04 15:50 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Not legal advice. Nobody here can confirm "good
standing": for Blizzard only Blizzard can; for wago.tools there are no written terms to stand by.

## Question (Xaya, 2026-11-04)
"does our use of this data in any way violate their or blizzard's tos? Confirm that we are in good standing with wago.tools
practices and t&c and the same for blizzard and wow t&c + tos"

## Sources read (primary texts)
- **Blizzard End User License Agreement**, "LAST REVISED March 21, 2024":
  https://www.blizzard.com/en-us/legal/fba4d00f-c7e4-4883-b8b9-1b4500a402ea/blizzard-end-user-license-agreement
  (readable from the cloud session this time; the earlier note in docs/reference/README.md said it was not). Quoted:
  - §1.C.6 Data Mining: "Use any unauthorized process or software that intercepts, collects, reads, or “mines” information"; "Blizzard
    may, at its sole and absolute discretion, allow the use of certain third-party user interfaces."
  - §1.C.1: "reverse engineer, derive source code from, modify, disassemble, decompile, or create derivative works".
  - §2.A.1.i: "you agree that you will not create any work based on the Platform, except as expressly set forth in this Agreement".
  - §1.B: the Platform is for "your personal and non-commercial entertainment purposes only".
- **UI Add-On Development Policy**: https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534 (released March 20,
  2009; reposted on the forums 2018; whether it is the current version could not be confirmed). Summarized (the fetch tool would not
  quote it in full):
  - add-ons must be free;
  - code visible;
  - no negative impact on realms or players;
  - no advertising;
  - no in-game donation requests;
  - content within the game's rating;
  - follow the Terms of Use and EULA;
  - Blizzard may disable any add-on functionality.
- **37 CFR 202.1(a)** (https://www.law.cornell.edu/cfr/text/37/202.1), "Material not subject to copyright": "Words and short phrases
  such as names, titles, and slogans; ...". US law only.
- **wago.tools**, read directly as data, 2026-11-04:
  - `/terms`, `/tos`, `/privacy`, `/about`, `/legal`, `/api` and `/faq` all return 404;
  - the site's script bundle has no "Terms" or "Privacy" text;
  - its footer: "© 2021 - <year> Wago Tools. All rights reserved.", with links to a Discord and a GitHub profile;
  - one fetch tool got HTTP 403 while curl through the session proxy got 200 (INFERENCE: the site filters some automated clients;
    not a published rule).

## Where XayaUI's uses sit
| Use | Reading | Risk |
|---|---|---|
| The addons reading the game while playing (XayaUI, Dev Assist captures) | The "third-party user interfaces" route of §1.C.6, governed by the add-on policy. XayaUI is free and its code is public; no ads or in-game donation requests. | lowest |
| Files built from client data tables via wago.tools: `docs/reference/content/`, `procs.md`, `XayaUI/ProcGlows.lua` and `XayaUI/SetBonusAuras.lua` (the last two ship in the addon) | No express permission found. Read literally, §1.C.6 and §2.A.1.i cover it, even though wago.tools did the extraction. Wowhead, wago.tools, the wow-ui-source mirror and widely used addons publish or ship such data openly: tolerance, not permission. No Blizzard statement authorizing it was found. | highest |
| Blizzard's names in the public repo | Short names are not copyrightable in the US (37 CFR 202.1(a)), which is why only names and numbers are published, no descriptions. The EULA is a contract and can still restrict use. | lower |

## Download practice (wago.tools)
- 19 tables (93 MB), downloaded once in this session.
- The builders cache per build, so a table is never fetched twice for the same build.
- Every generated file names wago.tools and the build.

## Options put to Xaya (her decision)
1. Keep the shipped addon free of client-table data: build set bonuses and proc glows from in-game reads (her standing rule already
   prefers data "learned from the game at runtime").
2. Keep `docs/reference/` as it is (not shipped to players).
3. Ask Blizzard. The 2009 policy named WoWUI@blizzard.com; whether that address is still monitored could not be confirmed.
4. Ask the wago.tools operator through the Discord its site links.

## Changed
`docs/reference/README.md` "Why the split": the "could not be read from the cloud session" note is replaced by the terms summary
above, with a pointer to this entry.
