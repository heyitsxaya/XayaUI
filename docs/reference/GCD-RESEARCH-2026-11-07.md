# GCD and haste: research for REQUEST-LOG UI-63 (2026-11-07)

Her words: "GCD is generally universal in my understanding and is modified by haste except for energy-resource classes — confirm on
wowhead first and then look into GCD scaling to see if it's universally uniform where haste reduces the GCD. If so, this should be a
standardized calculation".

## What each source says (quoted or close paraphrase; read 2026-11-07)
| Source | Says | Limits |
|---|---|---|
| Wowhead, spell 61304 "Global Cooldown" (https://www.wowhead.com/spell=61304/global-cooldown) | GCD 1.5 seconds | Nothing on haste, energy or a minimum; no comments on the page |
| Wowhead forum "[Haste] Haste and the Global Cooldown" (topic 79086) | (posts not readable without logging in) | Could not be read |
| warcraft.wiki.gg "Global Cooldown" (edited 2 Dec 2025) | "Most abilities have 1.5 seconds"; rogues, Cat Form druids and monks "mostly have 1.0 second"; haste can reduce a 1.5 s-based GCD "to a minimum of 0.75 seconds (1.0 seconds prior to Legion)"; "Haste doesn't affect GCD of agility energy melee classes"; empower abilities 0.5 s; spell 61304 tracks it | No formula; no Midnight notes |
| warcraft.wiki.gg "Haste" (edited 6 Aug 2024, flagged outdated) | the GCD is "calculated using the same formula" as cast time: base / (1 + haste); example 1.5 / 1.63 = 0.94 s; floor 0.75 s, reached at 100% haste | Flagged outdated |
| Blizzard EU forum (Brewmaster) | Brewmaster's 1 s GCD is static (not reduced by haste) | Player post, older |
| Peak of Serenity, Windwalker references (TWW / DF) | most Windwalker abilities on a static 1 s GCD; a few (Soothing Mist, Crackling Jade Lightning) on a hasted 1 s GCD, minimum 0.75 s; Mistweaver 1.5 s hasted | Older expansions |
| Icy Veins, Outlaw Rogue stat priority (12.0.5) | Adrenaline Rush lowers the GCD to 0.8 s from 1.0 s | One ability of one spec |

## Answer to her question
- Her rule holds: most GCDs are 1.5 s and haste shortens them; energy melee (rogues, Cat Form druids, Brewmaster and Windwalker
  monks) have a 1.0 s GCD that haste does not shorten. Mistweaver (mana) is on the 1.5 s hasted GCD.
- Within the hasted group it is uniform: GCD = 1.5 / (1 + haste%/100), never below 0.75 s (reached at 100% haste).
- Not fully universal: a few abilities have their own GCD (empower 0.5 s; a few Windwalker spells on a hasted 1 s GCD), and some buffs or
  talents change it (Outlaw's Adrenaline Rush: 0.8 s). Wowhead itself only confirms the 1.5 s base; the haste rules come from
  warcraft.wiki.gg and the guides above.

## What XayaUI does today (QoL 0.7.37, XayaUI_QoL/CharacterModel.lua, map_gcd)
Reads the live GCD (spell 61304) when one runs, then estimates "unhasted" as reading x (1 + haste) and the GCD "with your numbers" by
the same scaling, for every class. For energy melee this is wrong (a 1.0 s fixed GCD with 20% haste would show 1.20 s unhasted, and
typed haste would seem to shorten it); a "looks like a fixed 1 s GCD" note is the only guard.
