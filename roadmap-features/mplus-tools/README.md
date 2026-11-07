# Roadmap feature: M+ Tools (RM-MPLUS): scaffold, outline only

Xaya, 2026-11-06 (her words, verbatim; layout kept):

> M+ Tools
>
> * group interrupt + cc tracking
>    * enhance functionality by having the interrupt communicate somehow even if the interrupt does not succeed to improve accuracy?
>    * same for CC
>    * possible to filter these out into a dedicated chat window so players don't have to actually "see" the events happen in chat for the addon to detect it?
>    * detect when spells you input are casting and announce that [marker][unit] is casting [important_spell]
>
> * tank assist
>    * possible to alert you if threat is lowering for a unit in combat so you can prioritize hitting it?
>    * if threat is lost against an enemy, alert the player targeted that they may need to hit a big defensive in party chat (through whisper, party, say, yell toggles)?
>
> * party major offensives, defensives, and raid CDs
>    * track party defensives through the aforementioned way of tracking interrupts, cc, etc
>       * further out roadmap option: pinging a specific icon for a specific cd/defensive/raid cd has configurable options to say/yell/whisper/party chat request the cooldown be used
>    * all cooldowns must be communicated by the addon on the user's behalf, but they don't need to choose to display or track others' on their own (the former allows all addons to function and cross communicate, the latter determines what the user wants to see as meaningful information out of all tracked cooldowns)

Then: "scaffold this out now".

- **Where:** `roadmap-features/mplus-tools/` on this session's branch `claude/ecstatic-cori-sfi3hk` (PR heyitsxaya/XayaUI#424). The other scaffolds each have
  a branch of their own (`roadmap-features/games`, `roadmap-features/rppm`); this session may push only to its own branch, so this one
  can move to `roadmap-features/mplus-tools` when she says so.
- **Status:** outline only. Every `.lua` and `.toc` file here holds comments only and no code that runs. It sits under `roadmap-features/`
  so no tool, test or game reads it (same reason as `roadmap-features/games/README.md`). When the build starts, one
  `git mv roadmap-features/mplus-tools/XayaUI_MPlusTools XayaUI_MPlusTools` puts it in place.
- **Nothing is decided.** The open questions are in section 4. Readings of her words that are mine, not hers, are marked READING.

## 1. Can the game do it? (checked 2026-11-06 against the repo's 12.1.5 reference and Warcraft Wiki)

Every line cites where it comes from. "INFERENCE" means it follows from the cited facts but was not tested. Nothing here was run in game.

| Her bullet | What the game allows | Verdict |
|---|---|---|
| Group interrupt + CC tracking | The combat log is closed to addons: "COMBAT_LOG_EVENT and COMBAT_LOG_EVENT_UNFILTERED will error when trying to register them" (warcraft.wiki.gg, Patch 12.0.0/API changes). `UNIT_SPELLCAST_INTERRUPTED` gives `interruptedBy` but is `SecretWhenUnitSpellCastRestricted` (`docs/reference/api/events.md:1641`). So seeing *other* players' kicks from the game is blocked where casts are restricted (likely all of Mythic+: INFERENCE). A player's addon can always tell what that player itself cast (INFERENCE: own casts; to probe). | Possible only as **each player's addon reporting its own kicks and CC**, i.e. her second sub-bullet. Players without the addon are invisible. |
| "communicate somehow even if the interrupt does not succeed" | Same route: the addon sends "I used my interrupt at time T" whether or not it landed; the cooldown is what the group needs. Whether it *landed* is the restricted part (above). | Possible; "landed or missed" may be unknown in restricted content. |
| "same for CC" | Same as interrupts. | Possible, same limits. |
| "filter these out into a dedicated chat window so players don't ... see the events" | Addon messages (`C_ChatInfo.SendAddonMessage`, `namespaces.md:844`; received as `CHAT_MSG_ADDON`, `events.md:278`) are never printed in any chat window. No hidden chat window is needed. | Yes, and simpler than asked. **But see the lockdown row.** |
| **Lockdown (applies to every row that sends)** | `Enum.SendAddonMessageResult.AddOnMessageLockdown` = 11 (`enums.md:11728-11743`); `C_ChatInfo.InChatMessagingLockdown()` (`namespaces.md:827`); `Enum.AddOnRestrictionType` has `ChallengeMode` = 2 and `Chat` = 5 (`enums.md:497-504`). `XayaUI_Bonus/NotepadShare.lua:12-13` says "Midnight pauses addon messages during boss encounters and Mythic+ runs", citing the SendAddonMessage wiki page, but that page (read 2026-11-06) does not say when the lockdown applies. **I cannot find data to confirm whether addon messages work inside a Mythic+ run.** | **The weakest point of the whole feature.** If messages are locked in a keystone, every cross-player part (interrupts, CC, cooldowns, threat whispers by addon) fails exactly where she wants it. In-game probe first (section 3, P1). |
| "detect when spells you input are casting" | `UnitCastingInfo` / `UnitChannelInfo` (`globals.md:569-571`) and `UNIT_SPELLCAST_START` (`events.md:1647`) are `SecretWhenUnitSpellCastRestricted`. The existing roadmap item RM-INST already found the same limit. | Visual cue: possible even with secret values (a frame can show a secret, INFERENCE from the engine's design). Matching "is this one of my spells": only when the spell ID is readable. |
| "announce that [marker][unit] is casting [important_spell]" | `GetRaidTargetIndex` has `SecretReturns` (`globals.md:247`). `C_ChatInfo.SendChatMessage` has `HasRestrictions` and `SecretArguments=AllowedWhenUntainted` (`namespaces.md:847`): addon code is tainted, so a secret value cannot be put in the message (INFERENCE from the flag). | Chat announcement: only when marker, unit and spell are all readable. Probably not inside a key (INFERENCE). A local sound or speech cue has the same matching limit. |
| Tank assist: "alert you if threat is lowering for a unit" | `UnitDetailedThreatSituation` and `UnitThreatPercentageOfLead` are `SecretWhenUnitThreatValuesRestricted`; `UnitThreatSituation` is `SecretWhenUnitThreatStateRestricted` (`globals.md:582, 715-716`). An alert needs a comparison ("lower than before"), and a secret value cannot be compared. Events `UNIT_THREAT_LIST_UPDATE` / `UNIT_THREAT_SITUATION_UPDATE` (`events.md:1655-1656`) carry only the unit. | A visual (threat shown per nameplate) may work with secret values (INFERENCE). A sound / speech alert works only where threat is readable. When threat values are restricted is not established here. |
| "if threat is lost against an enemy, alert the player targeted ... in party chat (through whisper, party, say, yell toggles)" | Needs: who the mob targets (unit identity may be secret: `SecretWhenUnitIdentityRestricted` on role reads, `globals.md:597`), threat state (above), and an automatic chat post. SendChatMessage: "SAY", "YELL" need a hardware event outdoors and "CHANNEL" always (warcraft.wiki.gg, API_C_ChatInfo.SendChatMessage); a Mythic+ dungeon is an instance, so SAY / YELL / PARTY need no click there (INFERENCE from the wiki's "outdoor world" note). Chat lockdown may still apply. | Possible only where target identity and threat state are readable. The whisper / party / say / yell toggles are simple. |
| Party major offensives, defensives, raid CDs | Other players' cooldowns are not readable from the game for addons (the only documented call for another unit's spell cooldown is `C_Commentator.GetPlayerCooldownInfoByUnit`, `namespaces.md:1178`, which belongs to the game's spectator / commentator mode; that it does not work in a normal group is an INFERENCE). So: **each player's addon reports its own** (her "communicated by the addon on the user's behalf"). Own cooldowns: the engine already reads them. | Possible through addon messages; same lockdown risk. |
| "pinging a specific icon ... request the cooldown be used" (further out) | READING: a click on a cooldown's icon in XayaUI's tracker posts a request ("<name>, please use <cooldown>") on the chosen channel. A click is a hardware event, so SAY / YELL work outdoors too. Blizzard's own ping (`C_Ping.SendMacroPing`, `HasRestrictions`, `namespaces.md:3669`) has only the game's ping kinds (INFERENCE: `PingSubjectType`), so a custom icon ping on the map is not on offer. | Possible as an XayaUI click; not as a Blizzard ping. |
| "all cooldowns must be communicated by the addon on the user's behalf, but they don't need to choose to display" | Sending and showing are separate switches. **Conflict to settle:** standing rule V14 says a switched-off feature costs nothing. Sending while M+ Tools is switched off would break V14. | Her call (section 4, Q1). |

## 2. Proposed layout (outline only)

```
roadmap-features/mplus-tools/
├─ README.md                      this file
├─ XayaUI_MPlusTools/             the add-on (name to be chosen, Q2)
│  ├─ XayaUI_MPlusTools.toc       proposed .toc; module "mplus"; own saved table
│  ├─ MPlus.lua                   start-up, switches (send vs show), keystone and restriction state, V14
│  ├─ Comms.lua                   one addon-message protocol for every part: versions, throttle, lockdown, no secrets sent
│  ├─ Kicks.lua                   own interrupts sent as they are used; the group's kicks received and shown
│  ├─ CC.lua                      the same for crowd control
│  ├─ CastWatch.lua               "spells you input": watch list, enemy cast match, cue and optional announce
│  ├─ Threat.lua                  tank assist: threat per mob, lowering / lost alerts, the targeted player's alert
│  ├─ Cooldowns.lua               own major offensives, defensives and raid CDs sent; the party's received
│  ├─ Requests.lua                further out: click an icon to ask for a cooldown
│  ├─ Announce.lua                every chat post in one place: channel toggles, restrictions, never a secret value
│  ├─ SpellLists.lua              which spells count as interrupt / CC / defensive / offensive / raid CD, and where that comes from
│  ├─ UI/Tracker.lua              the group bars or icons (kicks, CC, cooldowns)
│  ├─ UI/ThreatView.lua           the tank's view
│  └─ UI/Options.lua              the settings page (ns.RegisterSettingsPage)
└─ tests/README.md                the tests each part needs, written to fail first
```

Related roadmap items (not merged into this one): RM-INST (enemy casts, Blizzard's timeline), #278 item 7 (trigger on an interruptible
target / focus cast), RM-RAIDTOOLS-TANKS (tank frame), RM-RAIDTOOLS (Release Guard and Big Wigs data). Whether M+ Tools and Raid Tools
are one home or two is Q2.

## 3. In-game probes before any build

| # | Probe | Why |
|---|---|---|
| P1 | In a keystone, in and out of combat, and in a boss fight: `C_ChatInfo.InChatMessagingLockdown()` and the result of one `SendAddonMessage` on `PARTY` | Decides whether the cross-player half can exist in Mythic+ at all |
| P2 | In a keystone: is `UNIT_SPELLCAST_SUCCEEDED` for `player` readable (spell ID not secret)? | Own kicks, CC and cooldowns must be readable to be sent |
| P3 | In a keystone: `UnitThreatSituation` / `UnitDetailedThreatSituation` on a nameplate, secret or not, in combat | Decides whether threat alerts are possible |
| P4 | In a keystone: `UnitCastingInfo("nameplateN")` spell ID and `GetRaidTargetIndex` secret or not | Decides whether "[marker][unit] is casting [spell]" can be announced |
| P5 | `SendChatMessage` on `PARTY` / `SAY` / `YELL` from an event (no click) inside a dungeon | Decides automatic announcements |

## 4. Open questions for Xaya

1. **Sending when off (V14).** "all cooldowns must be communicated by the addon on the user's behalf": should XayaUI keep sending its
   owner's kicks, CC and cooldowns when M+ Tools is switched off, or only while it is on (V14 says off costs nothing)?
2. **Name and home.** "M+ Tools" as its own addon in the AddOns list, a group in the QoL / Bonus sidebar, or together with Raid Tools?
3. **If P1 finds addon messages locked in keys:** drop the cross-player parts, keep only the player's own view, or wait?
4. **Other addons.** "allows all addons to function and cross communicate": only XayaUI talking to XayaUI (READING), or also reading and
   sending the message formats other cooldown-sharing addons use? Their formats are their own (#290).
5. **"spells you input":** typed spell IDs or names, picked from a list the addon learns in game, or both?
6. **Announcements:** which channel by default, and does an announcement go out automatically or only after you confirm (a chat post
   speaks for you)?
7. **Threat:** "alert you if threat is lowering": a sound, speech, a visual on the nameplate, or a choice? And at what point does
   "lowering" count (a percent, or losing first place)?
8. **"alert the player targeted":** whisper them automatically, or post in party? (Her toggles list whisper, party, say, yell; which is
   the default?)
9. **Which spells are "major":** a list the addon ships per class (from where: the game, or a named public source, #290), or one each
   player builds?
10. **Requests (further out):** the wording of a request message, and whether it whispers the cooldown's owner or posts in party.
