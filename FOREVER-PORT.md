# SeviathsUsefulTools for WoW Forever - port plan

Made from the retail addon (copy of retail 2.3, 2026-11-08). Interface 16001 (Forever 1.60.1). A feature is never removed without asking first.

## Done (phase 1)
- [x] Addon copied to the Forever AddOns folder (the load-on-demand data folders of retail are not copied).
- [x] Retail data removed: the `Data/*.lua` tables are empty (Items, Rares, Spawns, Gathering, recipes, decor, mounts, pets, talents, gems, realms, guild leaders, players ...), `collected/` is empty, the toc no longer loads collected files.
- [x] Retail talent builds and gem/enchant lists removed (same code, new data to feed).
- [ ] `Data/Items.lua`, `Data/Rares.lua`, `Data/Gathering.lua` still hold lines of mixed data (mounts and rares of all expansions): to be filtered to Classic.

## Done (phase 2: Classic data picked from what the retail addon collected, 2026-11-08)
- [x] Wowhead item lists cut to Classic: 22,851 items with sources (4 item folders), 7,680 transmog items (2 folders), 1,244 monsters with drops, 521 gray items.
- [x] The retail collected data was filtered by Classic items, Classic monsters and Classic zones (maps) and baked into `collected/` and `SeviathsUsefulTools_Monsters`: 1,047 monsters, 9,118 quests, 288 quest places, 198 learned vendor items, 18 towns, 971 loot records, 272 items, vendors, loot zones ... Players, guilds, Raider.IO answers, nameplates are not in it.
- [x] `tools/` copied with Classic-only source lists (`tools/classic_seed.lua` is the seed; scripts: bake_items, bake_drops, bake_transmog, bake_collected run against the Forever folder).
- [x] Talent builds: 43 builds of 27 specializations from Icy Veins' WoW Forever pages (`Data/TalentBuilds.lua`, source list `tools/talent_builds_forever.txt`, bake `tools/bake_talent_builds_forever.py`). Rows are name based ("forever:Tree=Talent:rank,..."). Wowhead has no Forever talent guides yet (only Icy Veins was found).
- [x] 221 items found at the Forever auction house (not in the Classic lists) added to the item data (`tools/add_forever_items.py`, run it again after more scans: it reads the Forever saved data, adds the new items and bakes the item folders).
- [x] Talent advisor reads Forever's talent tree (benefit ranking per spec, flashing, tier rule, click to select). Still to check in game: selecting with unspent points.
- [ ] (old note) The advisor code (`TalentAdvisor.lua`) still reads Blizzard import strings and retail trees: it needs to read the Forever talent trees. Run `/sut talents` in Forever and send the lines: it prints which talent APIs and frames Forever has.
- [ ] Not yet (needs new data): recipes (retail recipes only), wild/classic pets, mounts (Items.lua keeps old mixed lines), rares, spawns/farm spots, gathering, gems/enchants, achievements.

## Done (phase 3, 2026-11-08)
- [x] `Data/Items.lua` (mounts), `Data/Gathering.lua` (ores, herbs) and `Data/Rares.lua` keep only Classic lines: 5 Classic mounts, 35 gathering lines, 4 Classic rares (spirit beasts and others).
- [x] `Data/Spawns.lua`: the Classic farm monsters of the retail farm data (11 zones, 29 monsters). The 1,244 Classic monsters with drops from Wowhead also become farm spots through the drops data.
- [ ] Still little Classic data: rares (4), farm routes, recipes, battle/companion pets, gems and enchants, achievements, quest map marks (quests are in the Codex). They need new Wowhead Classic searches.

## Done (phase 4, 2026-11-08)
- [x] Red reskin: red replaces cyan in all windows, buttons and texts; the windows use the game's dark dialog background with a red border and the snake in a corner (`SFP.BlizzardFrame` in Core.lua; applied to the menu, tool windows, Codex, Dungeons & Raids, Guild Helper, map panels).
- [x] Menu: Delve Planner is now the Dungeon & Raid Planner, Delve Keys is the Quest Planner, Housing Decor is Roleplay (OC name, title, looks, personality, backstory, notes per character, saved for the account, shown on your tooltip). New file `Planners.lua`.
- [x] The world map shows the level range of the zone under the mouse.
- [x] Play styles: Roleplayer added (an OC written, or a roleplay server); the Mythic+ style is "Dungeon player".
- [x] Dungeons & Raids: no Delves and no Mythic+ tabs; the Dungeons filters have group item level (from, up to) and the leader's item level from the collected data.
- [x] 1,536 Classic recipes from Wowhead Classic (`tools/bake_recipes_forever.py`).
- [ ] No data yet: gems and enchants, companion pets, hunter pets (S tier), battle pets, achievements list (the planner reads the game's own achievements), quest marks on the map.

## To do (from the plan)
1. Data: Classic items, materials, mounts, battle pets, recipes, rares, hunter pets (S tier too), gems/enchants, boe deals (after an AH scan), farm spots (from Wowhead to start), farm routes, achievements, dungeons, raids, quests (map marks), Codex (Classic only).
2. Tooltip: every item of a monster shows its auction price; items show "sells / never sells / sometimes sells" in bags.
3. Talent advisor: Classic builds (Wowhead, Icy Veins), sections per spec of the selected class, raid or dungeon choice.
4. Dungeons & raids: Mythic+ key section merged into the Dungeons window, filters by item level and our collected data (no Raider.IO); delves removed; only Classic raids; group search of our own if Forever has none (to find out in game).
5. Delve planner -> dungeon and raid planner; delve keys -> quest planner; world map shows the retail-like level of each zone on hover.
6. Housing decor -> roleplay OC tab (character notes, planner, data shared by all characters).
7. Play styles: roleplayer added, "dungeon player" in place of the mythic player.
8. Reset all player and guild data (new Forever players and guilds are collected).
9. Check the learned data (what is Classic).
10. New red/snake look with Blizzard style backgrounds for all sections.
