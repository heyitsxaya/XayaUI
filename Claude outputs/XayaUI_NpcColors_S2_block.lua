--[[
  NpcColors entries for the Plater "Color Automation"-style script.
  PASTE BETWEEN "--insert the new mobs here:" AND "} --close custom color bracket".
  Built 2026-10-03 for Midnight Season 2 M+ pool (Altar of Fangs, Murder Row, Den of Nalorakk,
  The Blinding Vale, Voidscar Arena, Ruby Life Pools, Kings' Rest, Temple of Sethraliss).

  COLOR KEY (hotpink + orange = your existing cast-color scheme; yellow = MY PROPOSAL, change freely)
    hotpink = AoE fear / disorient / stun caster
    orange  = volley / big group-wide AoE damage caster
    yellow  = AoE debuff caster (Demoralizing-Shout type)

  CONFIDENCE
    TIER A = named in two independent guides (Method + Icy Veins) -> active below
    TIER B = single source, or names conflict between sources    -> commented out, enable after in-game check
    TIER C = generic "party damage" tag only, not clearly a volley/CC -> commented out, borderline

  CAVEATS
    * Keys are NPC NAMES as written in guides. Plater matches the exact in-game name; a spelling
      difference means silently no color. No npcIDs were shown by either source.
    * Guide data was machine-extracted from web pages; verify in-game (Plater: /plater > Npc Colors tab
      lists mobs once seen, with their real name and ID).
]]

-- ===== TIER A (active) =====

-- Blinding Vale
["Lightfeather Petalwing"] = "hotpink", -- Disorienting Screech (1238294); both guides say interrupt every cast
["Radiant Spellsower"]     = "orange",  -- Light Bolt Volley (1301834); both guides say stop the volley

-- Voidscar Arena
["Voidtouched Magi"]       = "orange",  -- Shadowbolt Volley (1299938); both guides
["Devouring Brutalizer"]   = "orange",  -- Dreadbellow (1252406); group-wide damage, use defensives; both guides

-- ===== TIER B (single source or name conflict) =====
-- ["Sporeblight Belcher"]      = "hotpink", -- Disorienting Screech (1238294) per Method only
-- ["Killvore Screamer"]        = "hotpink", -- Method: "Mass Shriek" (1233398). Icy Veins spells it "Kilivore Screamer" / "Mad Shriek" -> CHECK NAME IN GAME
-- ["Dominated Brawler"]        = "yellow",  -- Demoralizing Shout per Icy Veins only (debuff reducing group damage)
-- ["Ula'tek's Chosen"]         = "yellow",  -- Mass Envenom (1307567) per Method only; interruptible multi-target debuff
-- ["Primal Serpent"]           = "yellow",  -- Piercing Hiss (1294557) per Method only; not clearly AoE
-- ["Sentinel of Winter"]       = "hotpink", -- Raging Squall/Rimeshatter/Frozen Tempest tagged "CC effect" by Method only

-- ===== TIER C (borderline "party damage"; opt in if you want them) =====
-- Altar of Fangs
-- ["Twinfang Harrower"]        = "orange",  -- Paralyzing Shots (1294569)
-- ["Ritual Chieftain"]         = "orange",  -- Blood Sacrifice (1306641)
-- ["Rattling Writhe"]          = "orange",  -- Rattle (1294849)
-- ["Ascendant Serpent"]        = "orange",  -- Infest (1308865)
-- Murder Row
-- ["Massive Felwyrm"]          = "orange",  -- Over-Infused (1256299) pulsing + large AoE on death
-- ["Shivan Punisher"]          = "orange",  -- Demonic Frenzy (1294770)
-- ["Defiled Golem"]            = "orange",  -- Defiled Slam (1294824) heavy channel
-- Den of Nalorakk
-- ["Stormbound Mystic"]        = "orange",  -- Arc Lightning (1297778), interruptible
-- ["Terra Rumbler"]            = "orange",  -- Rumbling Ward (1296519)
-- ["Ruthless Totemcaller"]     = "orange",  -- Magma Totem (1246820)
-- ["Grizzled Warbringer"]      = "orange",  -- Primal Echo (1246957)
-- ["Loa Speaker Nanea"]        = "orange",  -- Volatile Totem (1309925) / Earthquake (1296722)
-- Voidscar Arena
-- ["Enthralled Shaman"]        = "orange",  -- Magma Totem (1246820); both guides want it interrupted
-- ["Brutal Overseer"]          = "orange",  -- Brutal Slams (1298901)
-- ["Angry Krolusk"]            = "orange",  -- Violent Sand (1249621)
-- Ruby Life Pools
-- ["Blazebound Destroyer"]     = "orange",  -- Inferno (373692)
-- ["Thunderhead"]              = "orange",  -- Rolling Thunder (392641)
-- ["Ruinous Stormbringer"]     = "orange",  -- Thunderstorm (385311)
-- ["High Channeler Ryvati"]    = "orange",  -- Tempest Stormshield (1310355)
-- Temple of Sethraliss
-- ["Twisted Hexxer"]           = "orange",  -- Latent Hex (1302153)
-- Kings' Rest
-- ["Shadow-Borne Champion"]    = "orange",  -- Shadow Whirlwind (1305945), avoidable

-- NOT INCLUDED (bosses; health-bar color is moot): Rav'i, The Writhing Coil, Zul'jan, The Hoardmonger,
-- Nalorakk, Charonus, Atroxus, Kokia Blazehoof, Melidrussa Chillworn, Kyrakka & Erkhart, Dazar, Council of Tribes,
-- Adderis & Aspix, Merektha, Galvazzt, Ula'tek (raid).
