# Changelog

## 2.3
### World map
- The Farm spots entry is gone from the points menu (the Farm spots button has its own list).
### Items and monsters
- Farm spots and Rares lists show all the loot of each monster again, with the chance of each item like the monster tooltip ("33% 1/3 chance", a plain percentage until 3 kills).
- Every monster you killed is listed in Farm spots and Rares, also ones with no drop recorded and trivial or low-level ones.
- The lists update with your new kills: they are made again a moment after a loot window closes, also while the window is closed.
- Butchering is recognised as skinning when you loot.
- The Best 15 farm spots no longer change again and again: the weekly list is kept for the whole week.
- Area looting (several corpses in one loot window): an item is only credited to the monsters that gave it, not to every corpse of the window. /sut cleardrops forgets the recorded drops of the monster you target, for monsters that were given other monsters' items before.
### Monsters and prices
- The addon tracks whether an item sells: a sale (the chat message) counts as sold, and an auction that runs out and comes back in the mailbox ("Auction expired") marks the item as never sold if it has never sold. The monster loot tooltip, the Farm spots lists and the Rares lists show "sold" or "never sold" before the price; gray items are never judged. The data is shipped with the addon.
- Worth grinding and the loot worth of a monster ignore items that never sell at the auction house.
- The Best 15 farm spots are worked out the same way: items that never sell are left out.
### Done list
- The Done list counts dungeons only when they are run as Mythic+, and raid bosses only from Heroic difficulty. Normal and finder runs and characters below the maximum level are ignored. The dungeon list of each character starts again with this.
### Premade groups
- The group makeup button (now "My groups setup") is always at the top left of the screen, not only in a group of 5 or more.
- Opening the Dungeons section of Premade Groups opens the Dungeons tab below the maximum level and the Mythic+ tab at the maximum level.
- Renamed: Listed is now "Listed group overview", My Group is "My groups setup", Notes is "Application note Autofill". The Members tab is gone. The tabs are as wide as their names and use a second row when needed.
- Tagged players list: click a tag to change it (toxic to good and so on), type in the note to edit it, x removes the player.
- Tag a player from a portrait: right-click a player in your group or your target or focus and choose "Tag a player".
- Min leader Mythic+ rating filter also uses the Raider.IO scores the addon scanned and saved, not only the Raider.IO addon and the game's own number.
- Leader timed this key from / up to: uses Raider.IO's best run of the leader in that dungeon (and whether it was timed) when the game gives none; without a run in that dungeon the leader's best key overall.
- The leader rating and key filters no longer break when the game hides a leader's numbers (the listing used to be left unfiltered). /sdr why shows what the filters see for the first listings.

## 2.2
### World map
- Herb and ore nodes: the addon records the kind of node and the smallest and largest amount of each pickup. The nodes you have gathered show on the map as small icons; hover one to see what it gave, with the amounts. The Herb nodes and Mining nodes switches of the points menu show or hide them.
- Nodes of the same kind gathered from the same spot are one place on the map with their loot put together.
- The old herb and ore symbols with no data are gone.
- A treasure box leaves the map for the character that opened the chest and stays for your other characters. The first character of an existing install gets all the chests recorded so far as opened; new characters and new installs see all treasures.
- A chest that respawns comes back to the map after the time it took to respawn the last time you opened it (one day until it has been opened twice). A chest opened again at the same place is noted as respawning at once, also in the same session, and the shortest time between two openings counts. The respawn time is kept with the chest and shipped with the addon, so new characters and other players use what was learned.
### Items and monsters
- Quest items are no longer part of a monster's loot table (tooltip, map and lists) and are not recorded as drops any more.
### Other
- The automatic auction house scan when you open it runs once a day instead of once an hour.
- Fixed overlapping texts on the Seviaths settings page (the group makeup button setting).

## 2.1
### World map
- New Item search button (next to Farm spots): every item the monsters of a zone drop, except the crafting reagents. Material search now lists all the crafting reagents. Same window and style.
- The Mining & Herbalism button below the map is gone: Material search opens on the zone you are in, and its Mining & Herbalism tab has the same list.
- Material search, Item search, Rares and Farm spots update by themselves when you kill a monster or pick something up; the Mount search when you collect a mount.
- Farm spots: the monsters of a zone that Wowhead lists drops for (with their places) are farm spots too. More monsters are added with each update.
- Mount search: mounts of every expansion from Classic to Midnight with their source, cost (gold, a currency or an item, with its icon) and a waypoint where the guide names the exact place; sections Flying, Ground and Aquatic.
- When there is no exact spot, a waypoint opens the zone.
### Items, monsters and the Codex
- Transmog Items (97,500 items from Wowhead): where each comes from (drop, vendor, quest ...), its armor or weapon type, slot, classes and level. A new Codex section groups them Source > Type > Slot > Quality; weapon and armor tooltips show the same and where you looted it yourself.
- Loot & Items lists all items of every expansion (Classic to Midnight) as Expansion > Type > Subtype; sections can hold sections inside sections. Items with no expansion are in "No expansion set yet".
- Gray items (6,600) are in the data and in a monster's loot table when you hover it, never in the lists.
- The items Wowhead lists for a monster (5,200 monsters) show in its loot on the map, in Rares and Farm spots, and on the Codex monster and boss pages.
- Codex Rares lists all 339 shipped rares and Monsters & Creatures every shipped monster (not only the ones you saw). Rare pages show place, note and drops.
- Dungeon and raid bosses: what you pick up from a boss is recorded even when the game hides what was looted; shown on the boss page.
- Treasure chests, caches and other objects: hover one you have opened and its tooltip shows what it gave, each item with its chance ("33% 1/3 chance"), from the first time you opened it. Each treasure you open is also a very small blue box on the world map at that place; hover it to see the loot. Under each item a short line says what it is for (its "Use:" text, a battle pet, a mount, a toy, a potion ...); nothing is typed when that is not known.
- A button under the map's own pin buttons opens a small menu to switch each kind of point on the map off or on: farm spots, rares, hunter pets, special materials, mining, herbs, and all treasure chests with one switch.
### Play style (profile tooltip)
- Decided week by week and starting again at every weekly reset; the numbers are for the whole account.
- The dungeon, delve and raid styles count each dungeon, delve and raid boss once a week (6 different ones). A few runs, or one day and then nothing, make no style.
- Gold grinder: 60,000 gold in a week from monster drops and the auction house (not quests or vendors).
- Collector: 10 mounts in 28 days, or 20 in the week of battle pets, toys, decor, old-expansion raid bosses that drop mounts or pet battles. Transmog, rare kills, Timewalking and the current expansion's raids do not count.
- Casual (anyone who plays and does nothing hardcore) and Hardcore (heroic and mythic raids, keys +5 and up) sit next to the other styles.
- The Done line (delves, dungeons, keys, raid bosses) is per character; the first character that logs in after the update keeps what the account had collected.
### Other
- Auction prices: a price from your own scan stays until your next scan; a battle pet the scan does not see keeps its earlier price.
- Tooltips and lists no longer show the number of kills of a monster (it is still counted for the percentages and gold per kill).
- Monster tooltips (the map, hovering any monster, rare or boss, and the Codex pages) show the chance of each item from your kills, with how many kills it takes: "12% 1/8 chance" (12%, one in 8 kills; it updates every time the item drops) (after 3 kills of that monster), and the rest of the items Wowhead lists for it.
- The group makeup window no longer opens by itself in a dungeon: in a group of 5 or more a Group makeup button at the top left opens it.
- Guild Directory: US and EU buttons above the realm buttons (your own region at first).
- The shipped data is cut into small files and small load-on-demand folders; the game reads only the part you look at.
- Fixes: several Lua errors (secret values in dungeons, "script ran too long" at login and in statistics).

## 2.0
### World map
- One line of buttons below the map: Farm spots, Rares, Material search, Mount search, Hunter search, Battle pets, Mining & Herbalism. Each opens in a big window next to the map; only one is open at a time.
- Material search: Monsters tab (zones from Classic to Midnight, the loot of the zone you pick, the monsters that drop each item, a waypoint on each) and a Mining & Herbalism tab (ores and herbs of the current zone, exact gathering spots you recorded, zones with node counts).
- Farm spots and Rares: every zone with its monsters; hover a name for the same tooltip the map shows (everything it drops, gold, the zone's loot). Best 15 farm spots by value per kill, made once a week at the weekly reset.
- Mount search: every mount of the game, rarest first, with its waypoint and its drop chance (your own tries and drops when you have them).
- Hunter search: every hunter pet with a waypoint.
- Battle pets: every pet with its price (vendor price when it cannot be traded), grouped by where it comes from, wild pet zones from Wowhead, waypoints where the exact place is known.
- Waypoints open the map at the place and ping it with a pulsing blue circle; click the pin with either mouse button to remove it.
### Recording
- Gold per kill of every monster, the amount of each material per kill, item icons and names, where an item was collected.
- Rares seen on the map are added to the Rares list; pets and mounts you collect keep their info and the place you found them.
- Boss and rare kills count as tries for the mounts they can drop, a looted mount counts as a drop; the chance updates by itself.
- The place you stood before entering a dungeon or raid is kept as its entrance.
- Vendor costs are saved with the icon and name of the currency or item needed.
### Fixes
- Several Lua errors fixed (nameplate copy, quest tooltip).
- Lists are cut into pages of at most 30 rows; only the open section is built.

## 2.0.0-retail
- New retail edition of SeviathsUsefulTools: Farm Pack + Codex (with Delves) + Dungeons & Raids + Guild Helper in one addon,
  plus the newer features of the classic edition (auction sold / mailbox / vendor messages, crafting and farming profit,
  worth-grinding comparison by creature type, learning of monsters, drops, nodes and recipes, main menu).
- Not carried over because retail does it natively: Questie-style quest marks, the MoP quest database, the MoP materials/mounts data.
- Warns once at login if one of the four old separate addons is still enabled.
- Farm spots learned with the old SeviathsFarmPack (11 maps) are copied in once (Data/Seed.lua).
- Auction prices: one full scan of the whole auction house (like Auctionator) instead of one search per item; falls back to per-item search if the game gives no answer.
- Item tooltips (bags, auction house, links): 'Where to get' (boss drops, vendors you visited, learned drops/nodes) and 'How to use' (recipes, consumables, gems, mounts, pets, toys, bags, gear) lines.
- The addon now learns where you got every item (looted in a zone, quest reward) and shows those zones on item tooltips; saved in the learned data.

- Fixed the "Worth grinding" verdict missing on monsters without a known auction price (the price fallback used a game function retail removed). An error in that verdict can no longer cut off the rest of the monster tooltip.

- Auction prices are now kept per realm (connected realms share one list) on top of the account-wide "newest price" list, so a scan on one character no longer overwrites what another realm showed, and every character sees the prices the others saved. Auctionator prices are saved too. The "prices are old" check is per realm.

- Midnight ores and herbs now have real node data (Wowhead spawn data, all node variants combined): best zone, glowing spots, node counts per zone and node object IDs for Refulgent Copper, Umbral Tin, Brilliant Silver, Tranquility Bloom, Sanguithorn, Azeroot, Argentleaf and Mana Lily; Dazzling Thorium and Nocturnal Lotus are listed as rare bonus drops.

- Midnight farm monsters: added 38 monsters with real spawn points and Wowhead drop rates (hawkstriders, lynx, wyrms, mournbats, consumptors, pangos, hawks, Twilight cloth mobs ...) in Eversong Woods, Zul'Aman, Harandar, Voidstorm, Isle of Quel'Danas, Slayer's Rise, Atal'Aman and The Coiled Isle, so their tooltips and map spots work.

- Minimap farm spots no longer need HereBeDragons (Questie, RareScanner ...): without it the addon places them itself, following the minimap zoom and rotation.

- Farm spot list on the left of every zone map: all farm monsters, rares, hunter tames, special materials, ore and herb spots of the zone, each with its own checkbox (untick = hidden on the map and the minimap), Show all / Hide all, scroll with the mouse wheel, click a name for a waypoint, [-]/[+] to fold it. Switch the list off in the menu ("Farm spot list").

- Prices: when the auction house is not scanned the addon now takes prices from Auctionator or TradeSkillMaster (TSM: DBMinBuyout, then DBMarket); they are saved per realm like scanned prices.

- Delve Planner rebuilt: your class and all its specs are detected (a class change resets it), the comfortable tier is typed into a box, the companion role (Healer/Tank/Damage or best for the spec) and Valeera's curios (10 curios with bonuses, hover for details) are chosen from lists and saved, and every delve the game's map knows is listed with its bountiful state.
- Shopping list and achievement list are saved between sessions; every entry can be removed, and shopping amounts changed, at any time.
- Zone Check shows its result on its own menu page (all missing mounts, pets and toys of the zone) instead of one chat line; Housing Decor lists every decor the game's housing catalog knows with owned/missing and where to get it (shown only when the game gives the catalog).
- Alt Overview: pick a character from a list and see its overview, bags, bank, the warband bank and all the gold (bags are saved while you play, banks when you open them).
- The group makeup window opens by itself in a group of 5 or more (dungeon, raid or open world), once per group; close it with the X or switch it off in the Settings page or on the My Group page.
- The farm route line has a tick box on the world map ('Route line') next to the spot list.
- Fixed: the Learned data page was missing its code in the retail edition; map, minimap and menu tooltips now use the addon's own tooltip frame so Blizzard's map pins are no longer tainted by the addon.
- Housing Decor now lists all 2027 decor items with item IDs and sources (data from Vamoose's Housing Decor Guide, MIT), owned or missing read from the game's housing catalog when it answers.
- Delve Planner: right-click a curio to mark that you own it; the suggested setup then picks the best curio of the ones you have, and the best one is marked.
- Housing Decor browser: pick a type (quest, crafted, achievement, drop, vendor ...) and a place (zone, instance, profession) from lists, search by name or source, filter all/missing/owned.

- Housing Decor: 491 more decor items added with their item and decor IDs (and a name where known); the game's housing catalog fills in missing names and sources and corrects wrong ones, and the corrections are saved.

- War Within farm monsters: 22 more with real spawn points and Wowhead drop rates (Ringing Deeps, Hallowfall, Isle of Dorn, Azj-Kahet, Undermine, K'aresh).
- 84 rare-drop mounts, pets and toys added to the item data (they now show their kind and icon on tooltips and the map).

- Midnight enchanting materials (Eversinging Dust, Radiant Shard, Dawn Crystal, both qualities) are now known to the item data and the Midnight "any zone" list.

- Raid BoE gear (trash / lieutenant drops) with Wowhead-checked item IDs: Midnight Voidspire / March on Quel'Danas, The Venomous Abyss, Nerub-ar Palace, Liberation of Undermine and Manaforge Omega (new raid entry in K'aresh); they show as BoE on tooltips and on the raid entrances.
- 81 Classic / Outland recipe drops (patterns, plans, formulas, schematics, designs) with checked IDs, new "Recipe" item kind.

- Dragonflight raid BoE gear: 9 items each from Vault of the Incarnates and Amirdrassil (IDs from Wowhead's raid loot guides, checked on the item pages). Wowhead has no BoE list for Aberrus yet.

- Midnight recipe drops: 38 patterns, plans, formulas and designs (Windrunner Spire, Magisters' Terrace, The Voidspire, The Dreamrift, Murder Row, Delve chests ...) plus the Amirdrassil recipe satchel, with Wowhead-checked item IDs and where they drop.

- Fixed a Lua error when hovering a world quest reward on the map (the item tooltip hook asked comparison tooltips for their item); tooltip hooks can no longer throw.

- Nerub-ar Palace recipe drops: Plans: Siphoning Stiletto, Pattern: Duskthread Lining, Recipe: Sticky Sweet Treat, Formula: Enchant Weapon - Authority of the Depths (Wowhead-checked IDs).

- Three more War Within recipe drops: Pattern: Adrenal Surge Clasp (Sikran), Plans: Sanctified Steps, Recipe: Feast of the Divine Day.

- 14 Dragonflight raid recipe drops (Vault of the Incarnates / Aberrus patterns, plans, schematics, designs, formulas) with Wowhead-checked IDs and where they drop.

- Aberrus recipe drops (6) and three Dragonflight world recipe drops (Zaralek Cavern and Emerald Dream enchanting crest formulas), IDs checked on Wowhead.

- Recipe tooltips now say where they really drop: the Zaralek Cavern and Emerald Dream crest formulas (rares, elites, chests, Small Somnuts) and Feast of the Divine Day (Radiant Cache).

- 20 Outland rares (Hellfire, Zangarmarsh, Nagrand, Terokkar, Blade's Edge, Netherstorm, Shadowmoon) with NPC IDs and spawn points; Topaz Skyfang added to the Coiled Isle rare drops; Satchel of Pilfered Recipes (Aberrus) added.

- 21 more Northrend rares (Frostbitten / Northern Exposure) and 21 Thaldraszus rares with NPC IDs and spawn points from Wowhead.

- NPC IDs filled in for 159 rares (Siren Isle, Isle of Dorn, Ringing Deeps, Hallowfall, Azj-Kahet, Undermine, Eversong, Voidstorm, Harandar, Zul'Aman, Coiled Isle ...); checked against Wowhead spawn maps. Blightpaw the Depraved added on the Ohn'ahran Plains.

- Rares: S.A.L., Tally Doublespeak, Voltstrike the Charged, Ephemeral Agent Lathyd and Ash'an the Empowered now have their Wowhead NPC IDs and names; Kereke, Rotfist and Zovex are separate entries; three Siren Isle storm-phase rares (Tempest Talon, Brinebough, Slaughtershell) and Zek'ul the Shipbreaker added with spawn points.

- Court of Rats (Ratspit) and Big Mon now have NPC IDs (checked against Wowhead spawn points).

- Gorgrond rare elites (8) and Vyragosa added; 152 rares that had a single map dot now show their full spawn areas from Wowhead.

- Gathering: Stranglekelp, Arthas' Tears and Osmenite Deposit added with best zones and node counts; Grime and Grease (Court of Rats) added; The Dreamrift is listed as a raid (its two recipes); the old quest-marker commands now say they are not in this edition, and the help text lists every command.

- Fixed a Lua error on monster tooltips (the game hides the unit of some tooltips as a secret value, which UnitGUID refused); all GUID lookups now tolerate that.

- Fixed a Lua error when looting (the game hides the target of your last gathering / skinning cast as a secret value); loot, cast and position values are checked before they are compared.

- Codex quest pages explain more: "What the quest says" (the game's own quest text, while the quest is in your log), a "Next step" line for the objective you do next, and advice judged by that step. "Follow the flower trail" no longer shows escort advice - it now says to walk along the glowing trail.

- Hover a quest in the quest log or the objective tracker: the tooltip now says what to do next, how, and where (Codex). `/codex hint` switches these hints (items and quests) on or off.

- Codex: new tab "Best Grinding Spots" - a top 10 of the farm spots ranked by what the loot is worth on the auction house (monsters per kill, gathering per node), with the numbers behind each spot. Needs auction prices (scan, Auctionator or TradeSkillMaster).
- Auction house: a "Scan prices" button and a progress bar below the auction house window (waiting for the answer, reading auctions %, items scanned, done, and when the last scan was).

- Best Grinding Spots also ranks the spots the addon learned from your own kills, with your measured drop rates.

- Items you collected in a zone now join that zone's item list and the item's "farm in" places when the addon loads (learned from your own loot, account-wide).

- Transmog history: the addon reads your transmog collection once in the background (never in combat) and learns which monsters and bosses you already own gear from, from before it was installed. Monster tooltips say "You already own N items from this monster". /sfp history shows the numbers, /sfp history rescan reads it again.

- The collection history now also reads your mounts and battle pets (their "Drop: ..." source), so monster tooltips can say you already own the mount or pet that monster drops.

- Codex quest pages say when a quest was completed on another character of your account (the game keeps that history).

- The collection history keeps itself current: new appearances, mounts and pets are added the moment you get them, and at login it reads again when the number of mounts or pets changed (for example from another character).

- Codex: new tab "My Collection History" - every monster, rare and boss you already own gear, a mount or a pet from (including ones the Codex has no page for), plus one page for the BoE and world-drop gear you own. Boss, monster and item pages show a "Your collection" line. The info page lists the new features.

- My Collection History is grouped into Bosses (by instance), Rares and Monsters.

- Not only what you own: every rare with a mount, pet or toy is listed in My Collection History with "owned" or "not collected yet", and rare tooltips show the same for each collectible.

- Rares you killed today are greyed out on the map and marked "[killed today]" until the daily reset.
- /sfp session: a farm session tracker (kills, gold looted, loot worth, per hour) with a small window.
- /sfp next: which rare to farm next - missing mounts, pets and toys, nearest first, killed-today ones last; sets a waypoint to the first.
- /sfp alerts: a sound and a chat line (with a clickable waypoint) when a rare you still miss something from appears nearby.
- /sfp export and /sfp import: share what the addon learned as a copy-paste string; importing merges and never lowers your counts.

- Farm route: the spot list has a "Route" button that orders the ticked spots of the zone into a loop, draws it on the map and sets a waypoint to the first stop (/sfp route, /sfp route clear).
- /sfp weekly: Great Vault, raid lockouts and rares killed today for all your characters.
- /sfp flip and a "BoE deals" button at the auction house: BoE items now against their typical price (the addon remembers each scan).
- /sfp shop: crafting shopping list - pick recipes, get the reagent totals, prices, the profit and where to farm each reagent.

- Rare alerts can be switched off (and the sound separately) in the menu; /sfp alerts still toggles them.

- Menu: a "Read my collections" button (Farm & Map page) reads your transmog, mounts and pets again and shows when it last ran and what it found.

- Menu: "Grey out rares killed today" switch and a "Forget today's kills" button (Farm & Map page).

- Menu: "Show the farm route on the map" switch (Farm & Map page).

- Menu: two new pages - "Rares & Alerts" (rare alerts, alert sound, grey killed rares, farm route, spot list, read my collections, forget today's kills) and "Tools" (a button for every tool: farm session, what to farm next, weekly checklist, BoE deals, shopping list, route, export / import). Moved there from the Farm & Map page; the Settings page points to them.

- All addon windows (menu, farm browser, Codex, Dungeons & Raids, Guild Helper, tool windows) share one layer and come to the front when they open or are clicked, so a window is never hidden behind another one.

- Settings page: the rare alert, killed-today and farm route switches, the collection buttons and every tool button are now right on the Settings page too (they are also on the Rares & Alerts and Tools pages).

- Menu: every tool has its own entry in the list on the left (Rare Alerts, Killed Today, Farm Route, Farm Session, What To Farm Next, Weekly Checklist, BoE Deals, Shopping List, My Collections, Share Data), each with a short explanation and its buttons. The switches (rare alerts, sound, killed today, route) stay on the Settings page. The menu window is taller and the list is compact.

- New tools, each with its own page in the menu list: Delve Planner (companion role and curio hint for your spec, comfortable tier), Delve Keys (keys, weekly earned, bountiful delves), Achievement Planner (what is left, where, what first), Zone Check (one line about what you still miss when you enter a zone; switch on Settings), Housing Decor (craftable Midnight decor recipes and which you know), Alt Overview (level, item level, gold, professions, weekly for all characters). The menu list scrolls.
- Weekly checklist: every raid with the bosses done and still to do (per difficulty), and the current raids you have not started.
- BoE deals: uses Auctionator or TradeSkillMaster prices when there is no scan of your own, TradeSkillMaster's long-term price as the typical price, and lists BoE prices even without a price history.
- What To Farm Next: a list of rares, each with its own Waypoint button; looks up mount, pet and toy ownership in more ways.
- Farm Session page: separate Start and Stop buttons and the list of commands.

- Farm Route page: a searchable list of every zone with farm spots (newest expansion first); click one to open its map and draw the route.
- Killed Today page: lists everything you killed today per character, with the zone and the time.

- The collection history reads by itself on the first start after the install (about 20 seconds after login, with one chat line saying so) and again when your mount or pet count changes; the My Collections page says so.

- Farm Route page: detects the zone you are in and lists its farm spots with check boxes; tick the ones you want and press Build route. Another zone can be picked from the list below (zones with the same name show their map number).

- The tool pages in the menu now update themselves every two seconds while they are open (What To Farm Next, Farm Session, Killed Today, My Collections and the others), so distances, kills and collections stay current without reopening.

- Prices everywhere in the addon use the same order: your own scan first, then Auctionator, then TradeSkillMaster. The item tooltip "AH (unit)" line and the Codex material and farming prices now follow it too (they used only the addon's own scan or Auctionator by name before).
- BoE deals: the window redraws itself while open so item names fill in, and uses Auctionator's own price history for the typical price when this Auctionator version offers it.
- Auction scan by section like Auctionator with a one-line progress; the bar names the realm and how old the prices are; optional long scan (every item one by one); item IDs and names are learned and shipped (no prices); Auctionator/TSM prices can be switched off in Settings.
- Housing planner: about 3,000 decor with sources and waypoints, tick boxes, owned state; farm routes window, What To Farm Next by zone, farm session window with time and gold.
- Group makeup opens by itself in groups of 5 or more; tier tokens updated for Midnight Season 2 by armor type; every window remembers its position and opens in front.
- Fixes: minimap button works on the first click, scans no longer stop early, decor learning no longer freezes the game.