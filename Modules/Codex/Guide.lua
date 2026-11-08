-- Seviath's Codex — hand-written new-player guide articles
-- Written for this addon (CC BY-NC 3.0). Kept evergreen on purpose: numbers
-- and names that change every season live in the live journals, not here.

local ADDON, ns = SFP_Module("Codex")
local C = "|cffffd100"   -- cyan headings
local R = "|r"

ns.GUIDE = {
------------------------------------------------------------------------
-- Start here
------------------------------------------------------------------------
{ id = "codex", group = "1. Start Here", title = "How to use the Codex", icon = "INV_Misc_Book_09",
  tags = "help search waypoint",
  body = [[
Type anything in the search box at the top — a boss, a dungeon, an item, a mount, a pet, an achievement, a title — and the Codex searches every section at once. Click a section on the left to browse it by expansion or type.

]]..C.."Buttons on a page"..R..[[

• Show on map — puts an arrow on your map and minimap (uses TomTom if you have it).
• Adventure Guide / Collections — opens the matching Blizzard window.
• Wowhead link — a link you can copy (Ctrl+C) for full comments and guides.

]]..C.."Where the data comes from"..R..[[

Dungeons, raids, bosses, abilities, loot, entrances, mounts, pets, achievements, transmog sets and quests are read straight from your game client, so they are always correct for the current patch. The first time you log in it takes a minute or two to read most of it in the background.

Quests are the big one: the Codex asks the server about every quest once (about 30–60 minutes of background reading the first time, it pauses in combat and continues next login). After that they load instantly. Each quest page shows only what to do — the objectives — not the story text. The bar at the bottom shows progress.

Slash commands: /codex, /codex <search>, /codex minimap, /codex reindex]] },

{ id = "first-steps", group = "1. Start Here", title = "Your first hours: what to do", icon = "Achievement_Quests_Completed_01",
  tags = "new player leveling start beginner",
  body = [[
1. Finish your starting area and the introduction quests — they teach movement, combat and your class.
2. Pick a ]]..C.."specialization"..R..[[ (Talents window, N) — it decides your role: tank, healer or damage.
3. Level by questing, running dungeons (the Group Finder queues you automatically) or both.
4. Talk to ]]..C.."Chromie"..R..[[ in Stormwind or Orgrimmar to choose which older expansion you level in (Chromie Time). Pick the one whose story or look you like most — they all level you equally.
5. The level cap in Midnight is 90. At max level the current expansion opens up: world quests, delves, dungeons, raids, professions and renown.

Tip: set your Hearthstone at an inn in a city you visit often. It's your free teleport home.]] },

{ id = "roles", group = "1. Start Here", title = "Classes, specs and roles", icon = "ClassIcon_Warrior",
  tags = "tank healer dps damage class spec talents",
  body = [[
Every class has 2–4 specializations. Each spec has one role:

]]..C.."Tank"..R..[[ — holds the enemies' attention and takes the hits. Leads the pace in dungeons.
]]..C.."Healer"..R..[[ — keeps the group alive.
]]..C.."Damage (DPS)"..R..[[ — kills things, avoids standing in bad stuff.

You can change spec any time out of combat for free. Talents are saved per spec as loadouts, and you can import builds people share as text strings (Talents window » Import).

Damage roles have the longest queue in the Group Finder; tanks and healers get in fastest.]] },

{ id = "gear", group = "1. Start Here", title = "Gear, item level and upgrades", icon = "INV_Chest_Plate16",
  tags = "ilvl item level gear upgrade crest stats",
  body = [[
]]..C.."Item level (ilvl)"..R..[[ is the main number that says how strong a piece is. Your average ilvl shows in the character window (C).

Where gear comes from, from easiest to hardest: world quests and leveling » normal/heroic dungeons and delves » Mythic+ and raids.

Most current-season gear can be ]]..C.."upgraded"..R..[[ at an upgrade vendor in the expansion hub using the season's upgrade currencies. The tooltip shows the upgrade track (for example 2/6).

Stats: your main stat (Strength, Agility or Intellect) matters most; secondary stats (Crit, Haste, Mastery, Versatility) depend on your spec — check a class guide for priorities.]] },

{ id = "warband", group = "1. Start Here", title = "Warband: what's shared between your characters", icon = "Achievement_Character_Human_Female",
  tags = "warband account alt bank warbound reputation",
  body = [[
Your ]]..C.."Warband"..R..[[ is every character on your account. Shared across it:

• Mounts, pets, toys, transmog appearances and most achievements.
• The Warband bank tab at any banker — put items there to move them to alts.
• Many reputations and renown (marked as Warband on the reputation panel).
• Items marked ]]..C.."Warbound"..R..[[ (or "Warbound until equipped") can be sent to your own alts but not traded.

Alts level faster thanks to account-wide progress and heirlooms (see the Heirloom tab in Collections).]] },

{ id = "keys", group = "1. Start Here", title = "Keys and windows you will use every day", icon = "INV_Misc_Note_02",
  tags = "keybind shortcut hotkey window map bags talents character quest log group finder collections",
  body = [[
Default keys (you can change them in Options » Keybindings):

]]..C.."M"..R..[[ — world map
]]..C.."B"..R..[[ — all bags
]]..C.."C"..R..[[ — character and gear
]]..C.."N"..R..[[ — talents
]]..C.."P"..R..[[ — spellbook
]]..C.."L"..R..[[ — quest log
]]..C.."I"..R..[[ — Group Finder
]]..C.."Y"..R..[[ — achievements
]]..C.."O"..R..[[ — social and friends
]]..C.."Shift+P"..R..[[ — collections (mounts, pets, toys, transmog)
]]..C.."Shift+J"..R..[[ — Adventure Guide

Useful habits:
• Right-click a quest giver's quest in the tracker to see it on the map; Shift+click a quest in the log to track it.
• Click the small bag-sort button at the top of your bags to tidy them, and use "Sell all junk" at any vendor (the coin button that appears there).
• Use /reload if the interface acts strange; it is safe and fast.]] },

{ id = "newbie-tips", group = "1. Start Here", title = "Tips nobody tells new players", icon = "INV_Misc_Bag_10",
  tags = "tips beginner new player rested xp repair auto loot flight points durability hearthstone",
  body = [[
• ]]..C.."Rested experience"..R..[[: log out in an inn or a city and you earn bonus experience while away. Your next kills give extra XP (the bar turns blue).
• ]]..C.."Repair"..R..[[: gear loses durability when you die. A vendor with an anvil icon repairs it for a small price. Don't let it reach zero.
• ]]..C.."Auto Loot"..R..[[: turn it on in Options » Controls so a corpse empties into your bags with one click (hold Shift to loot manually).
• ]]..C.."Flight points"..R..[[: talk to a flight master in each new zone to learn the point; later you can fly there from any other one.
• ]]..C.."Bags are limited"..R..[[: buy or craft bigger bags early, and put things you do not need now in the Warband bank.
• ]]..C.."Not a rush"..R..[[: you do not have to follow a "best" order. Leveling, dungeons, pets, mounts and professions all count as progress.
• Read the tooltip of every new ability and item; it tells you what it does and how much it costs.
• Ask in the guild or in a dungeon "first time here, any tips?" — most players are glad to help.]] },

{ id = "loot-rules", group = "1. Start Here", title = "Loot rules and group manners", icon = "INV_Misc_Bag_09",
  tags = "need greed pass loot roll group etiquette dungeon queue leave",
  body = [[
When a dungeon or raid drops an item, everyone who can use it gets a roll window:

]]..C.."Need"..R..[[ — only if the item is an upgrade for the spec you are playing (or you will use it as a main item).
]]..C.."Greed"..R..[[ — you would sell or disenchant it, or use it as a spare.
]]..C.."Transmog"..R..[[ — you only want the look (shown when you do not have the appearance yet).
]]..C.."Pass"..R..[[ — you do not want it.

Manners that keep groups friendly:
• Do not Need on gear for another spec or for selling, unless the group agreed.
• Say "hi" and "ready" in chat; tell the group if you are new — they will explain the bosses.
• Do not leave right after a wipe; one more try is often enough.
• Tanks lead the pace: in a dungeon follow the tank unless told otherwise.

Loot you won can be traded to a group member within 2 hours if it is not an upgrade for you.]] },

{ id = "combat-basics", group = "1. Start Here", title = "Combat basics and staying alive", icon = "Ability_Warrior_Rampage",
  tags = "combat interrupt kick defensive cooldown red circle avoid aoe death resurrect corpse spirit healer",
  body = [[
• ]]..C.."Stay out of the red"..R..[[: red circles, cones and lines on the ground are damage coming. Step out of them; this alone is most of what keeps players alive in dungeons.
• ]]..C.."Interrupt"..R..[[ (kick): most classes have a short interrupt. Use it on enemy casts that show a shield or a dangerous cast bar.
• ]]..C.."Defensive abilities"..R..[[: every class has a few. Use one when your health is dropping, not at one percent.
• ]]..C.."Health potions and food"..R..[[: eat or drink out of combat to heal; potions work in combat.
• Kill the small adds first if your group says so; focus the marked target in a group.

If you die:
• Click ]]..C.."Release Spirit"..R..[[ and run back to your body as a ghost; when you stand on your corpse press Resurrect. Or accept a resurrect from a healer.
• The ]]..C.."Spirit Healer"..R..[[ revives you right away at a small durability cost if the run back is too far.
• In dungeons and raids you can often be resurrected by a combat resurrection; wait for the group's call.]] },

{ id = "lingo", group = "1. Start Here", title = "Chat lingo and abbreviations", icon = "INV_Letter_15",
  tags = "lfg lfm dps tank healer aoe cc cd boe bop lfr wq mount farm alt rp glossary",
  body = [[
]]..C.."LFG / LFM"..R..[[ — looking for group / looking for more.
]]..C.."DPS"..R..[[ — damage dealer.
]]..C.."M+ / key"..R..[[ — Mythic+ dungeon and its keystone.
]]..C.."LFR"..R..[[ — Raid Finder (easiest raid).
]]..C.."AoE"..R..[[ — damage to many enemies at once.
]]..C.."CC"..R..[[ — crowd control (stun, sleep, root...).
]]..C.."CD"..R..[[ — cooldown, an ability you can use again later.
]]..C.."BoE / BoP"..R..[[ — bind on equip / bind on pickup.
]]..C.."WQ"..R..[[ — world quest.
]]..C.."Alt"..R..[[ — another of your characters.
]]..C.."Farm"..R..[[ — kill or gather the same thing over and over for loot.
]]..C.."RNG"..R..[[ — random luck.
]]..C.."BRB / AFK"..R..[[ — be right back / away from keyboard.
]]..C.."Pug"..R..[[ — a group of strangers from the Group Finder.
]]..C.."GG"..R..[[ — good game, said after a run.

Typing /who <name> or checking the Group Finder entry tells you about a player; use the player tags in this addon's Groups page for your own notes on people.]] },

{ id = "tools", group = "1. Start Here", title = "What Seviath's Useful Tools does and where", icon = "INV_Misc_Map_01",
  tags = "addon seviath useful tools menu minimap farm map decor delve planner auction alt overview what where",
  body = [[
Open the menu with the minimap button or ]]..C.."/sut"..R..[[. The left list is the whole addon:

• ]]..C.."Farm & Map, Farm Route, Farm Session"..R..[[ — farm spots on the world map, a route through them, and a timer with gold gained.
• ]]..C.."Rare Alerts, Killed Today, What To Farm Next"..R..[[ — rares that still drop a mount, pet or toy you miss; best first.
• ]]..C.."My Collections, Housing Decor"..R..[[ — plan the mounts and decor you want; the lists show owned and missing.
• ]]..C.."Delve Planner, Delve Keys"..R..[[ — best companion setup per spec and per delve.
• ]]..C.."Zone Check"..R..[[ — what you still miss in the zone you stand in, with a waypoint button per rare.
• ]]..C.."Weekly Checklist, Alt Overview"..R..[[ — what is left this week and a list of all your characters, bags, bank and gold.
• ]]..C.."BoE Deals"..R..[[ — auction prices; scan the auction house once to fill them. ]]..C.."Recipe Planner"..R..[[ — pick recipes of any profession and get the reagents to buy, their prices and the profit.
• ]]..C.."Guides (Codex)"..R..[[ — this guide book.

All saved data is shared by all your characters. The addon is new and still being tested: if something looks wrong, tell the author.]] },

------------------------------------------------------------------------
-- Group content
------------------------------------------------------------------------
{ id = "dungeons", group = "2. Dungeons, Raids & Delves", title = "Dungeons and their difficulties", icon = "INV_Misc_Key_14",
  tags = "dungeon normal heroic mythic group finder",
  body = [[
A dungeon is a 5-player instance: 1 tank, 1 healer, 3 damage.

]]..C.."Normal"..R..[[ — leveling and fresh max-level characters. Queue with the Group Finder (I).
]]..C.."Heroic"..R..[[ — harder, better loot, still queueable.
]]..C.."Mythic"..R..[[ — no queue: form a group yourself (Premade Groups) and walk in.
]]..C.."Mythic+"..R..[[ — Mythic with a timer and a keystone (see "Mythic+ keystones").

Don't have a group? ]]..C.."Follower Dungeons"..R..[[ let you run selected dungeons with NPC companions.

Find any dungeon's entrance in the Entrances section of this Codex, and each boss's abilities and loot under Bosses.]] },

{ id = "mplus", group = "2. Dungeons, Raids & Delves", title = "Mythic+ keystones", icon = "INV_Relics_Hourglass",
  tags = "mythic plus m+ keystone key affix timer rating",
  body = [[
After your first Mythic dungeon each week you get a ]]..C.."keystone"..R..[[ in your bags. Put it in the font at the dungeon's start and the run begins with a timer.

• Beat the timer » the key upgrades (+1 to +3 levels) and you get better rewards.
• Run out of time » you still get loot, but the key goes down a level.
• Higher keys add ]]..C.."affixes"..R..[[ — extra rules that make the run harder.

Your best runs give you a Mythic+ rating (visible in the Group Finder) and fill the Dungeon row of your Great Vault. Only the dungeons in the current season's rotation can be keystone dungeons — in this Codex they're tagged "current season".]] },

{ id = "raids", group = "2. Dungeons, Raids & Delves", title = "Raids and difficulties", icon = "Achievement_Boss_Ragnaros",
  tags = "raid lfr normal heroic mythic lockout",
  body = [[
Raids are big instances for 10–30 players (Mythic is exactly 20).

]]..C.."Raid Finder (LFR)"..R..[[ — queue and go, easiest, split into wings.
]]..C.."Normal / Heroic"..R..[[ — 10–30 players, group with Premade Groups or a guild.
]]..C.."Mythic"..R..[[ — 20 players, the hardest content in the game.

Each difficulty has a weekly ]]..C.."lockout"..R..[[: each boss gives loot once per week per difficulty. The reset is weekly (Wednesday in Europe, Tuesday in the Americas).]] },

{ id = "delves", group = "2. Dungeons, Raids & Delves", title = "Delves (solo-friendly)", icon = "INV_Misc_Lantern_01",
  tags = "delve solo companion tier bountiful key",
  body = [[
Delves are short adventures for 1–5 players with an NPC companion who heals or fights with you (in Midnight the companion is Valeera). They have tiers — higher tiers are harder and give better loot.

• Entrances show on the world map as delve icons.
• ]]..C.."Bountiful"..R..[[ delves (marked on the map) give an extra chest if you bring the season's delve key.
• Delves count for the World row of the Great Vault.

Great for players who prefer to play alone or at their own pace.]] },

{ id = "vault", group = "2. Dungeons, Raids & Delves", title = "The Great Vault (weekly reward)", icon = "INV_Misc_Treasurechest02b",
  tags = "great vault weekly chest reward",
  body = [[
Every week you fill up to 9 slots in the ]]..C.."Great Vault"..R..[[ (in the expansion hub):

• Raid row — by bosses killed.
• Dungeon row — by Mythic / Mythic+ dungeons completed.
• World row — by delves and other world activities.

After the weekly reset you open it and choose ONE item from the unlocked slots. Better runs = better choices. Even a few runs a week is worth it.]] },

{ id = "timewalking", group = "2. Dungeons, Raids & Delves", title = "Timewalking", icon = "Spell_Holy_BorrowedTime",
  tags = "timewalking old dungeon scaled event badges",
  body = [[
During Timewalking weeks (see the calendar) you can queue for old-expansion dungeons scaled to your level. Rewards include Timewarped Badges, which buy old-expansion mounts, pets, toys and transmog from Timewalking vendors.

Timewalking also counts for some weekly quests and can give current-level gear.]] },

{ id = "legacy", group = "2. Dungeons, Raids & Delves", title = "Soloing old raids for mounts & transmog", icon = "Achievement_Boss_LichKing",
  tags = "legacy solo old raid mount transmog farm lockout",
  body = [[
At max level you can solo most raids from older expansions. They use ]]..C.."Legacy Loot"..R..[[: bosses drop loot just for you, so you get everything.

Easy classic mount farms (weekly lockouts):
• ]]..C.."Invincible"..R..[[ — The Lich King, Icecrown Citadel (25 Heroic).
• ]]..C.."Ashes of Al'ar"..R..[[ — Kael'thas, Tempest Keep (The Eye).
• ]]..C.."Mimiron's Head"..R..[[ — Yogg-Saron with no keepers helping, Ulduar.
• ]]..C.."Fiery Warhorse"..R..[[ — Attumen the Huntsman, Karazhan.
• ]]..C.."Blue Proto-Drake"..R..[[ — Skadi the Ruthless, Utgarde Pinnacle (Heroic).
• ]]..C.."Swift White Hawkstrider"..R..[[ — Kael'thas, Magisters' Terrace (Heroic).
• ]]..C.."Rivendare's Deathcharger"..R..[[ — Lord Aurius Rivendare, Stratholme.

Search any of these names in the Codex to see the boss, the instance and the entrance with a map arrow. Drop rates are low — farm a few every week.]] },

{ id = "groupfinder", group = "2. Dungeons, Raids & Delves", title = "Finding a group", icon = "INV_Misc_GroupNeedMore",
  tags = "group finder premade lfg guild",
  body = [[
]]..C.."Group Finder"..R..[[ (I) has two parts:

• Dungeon Finder / Raid Finder — automatic queue for Normal/Heroic dungeons and LFR.
• Premade Groups — player-made listings for everything else: Mythic+, raids, delves, quests, PvP, custom.

Tips: write your goal in the listing ("learning", "fast run", "for achievement"), check the leader's rating, and be honest if it's your first time — many groups are happy to explain.

]]..C.."Seviath's Dungeons & Raids"..R..[[ (sister addon) makes Premade Groups faster to use, and ]]..C.."Seviath's Guild Helper"..R..[[ helps find and invite guild members.]] },

------------------------------------------------------------------------
-- The world
------------------------------------------------------------------------
{ id = "travel", group = "3. World & Travel", title = "Getting around: hearth, portals, flying", icon = "Spell_Arcane_PortalStormwind",
  tags = "travel portal room hearthstone flying flight path taxi",
  body = [[
]]..C.."Hearthstone"..R..[[ — teleports you to the inn you bound it to. Many toys work as extra hearthstones.
]]..C.."Flight masters"..R..[[ — talk to them to fly between discovered points.
]]..C.."Portal rooms"..R..[[ — Stormwind (Mage Quarter area) and Orgrimmar have rooms full of portals to every expansion's hub. This is the fastest way to old content.
]]..C.."Skyriding"..R..[[ — fast dynamic flying with charges you spend to boost. You can switch a mount to Steady Flight for classic flying.

Each Entrances page in this Codex includes how to reach that continent.]] },

{ id = "oldworld", group = "3. World & Travel", title = "Famous old places and how to enter", icon = "INV_Misc_Map_01",
  tags = "entrance old raid caverns of time blackrock karazhan black temple icecrown",
  body = [[
Some places new players often can't find:

• ]]..C.."Blackrock Mountain"..R..[[ — between Searing Gorge and Burning Steppes. Inside: Blackrock Depths, Blackwing Lair, Molten Core and more.
• ]]..C.."Caverns of Time"..R..[[ — Tanaris (Kalimdor). Many dungeons and raids from history.
• ]]..C.."Karazhan"..R..[[ — Deadwind Pass (Eastern Kingdoms).
• ]]..C.."Black Temple"..R..[[ — Shadowmoon Valley (Outland).
• ]]..C.."Icecrown Citadel"..R..[[ — Icecrown (Northrend).
• ]]..C.."Ulduar"..R..[[ — The Storm Peaks (Northrend).

Open the ]]..C.."Entrances"..R..[[ section and press Show on map — every dungeon and raid entrance the game knows is listed with exact coordinates.]] },

{ id = "quests", group = "3. World & Travel", title = "How quests work", icon = "INV_Misc_Note_01",
  tags = "quest daily weekly world campaign elite group objectives",
  body = [[
]]..C.."Yellow !"..R..[[ — a quest you can pick up. ]]..C.."Blue !"..R..[[ — a repeatable one (daily/weekly). ]]..C.."?"..R..[[ — ready to hand in.

Quest types you'll see:
• Normal — do the objectives once, hand in, done.
• Daily / Weekly — repeatable after the daily or weekly reset.
• World quests — appear on the map with a timer, no pick-up needed; just go there.
• Campaign — the expansion's main chain; often unlocks features (flying, renown, zones).
• Elite / Group — tougher enemies; bring a friend or a group.
• Dungeon / Raid — objectives inside an instance.

Your quest log (L) holds a limited number of quests; abandon old ones you don't need. Use the map (M) — objective areas are highlighted and the tracker on the right shows progress.

The Quests section lists every quest with only its objectives (what to do), its type, expansion and whether this character has done it.]] },

{ id = "worldquests", group = "3. World & Travel", title = "World quests, renown and reputation", icon = "Achievement_Reputation_01",
  tags = "world quest renown reputation faction rewards",
  body = [[
]]..C.."World quests"..R..[[ — short repeatable quests on the map with a timer and a reward icon. Do the ones whose rewards you need.
]]..C.."Renown"..R..[[ — each current-expansion faction has renown levels. Raising them unlocks mounts, transmog, pets, recipes, and sometimes gameplay features.
]]..C.."Reputation"..R..[[ — older factions use classic levels (Friendly » Exalted). Some sell mounts and recipes at Exalted.

Track progress in the reputation panel (Character window » Reputation).]] },

{ id = "rares", group = "3. World & Travel", title = "Rares and treasures", icon = "Achievement_Boss_Archaedas",
  tags = "rare elite treasure skull silver dragon",
  body = [[
]]..C.."Rares"..R..[[ are special enemies with a silver dragon around their portrait. They respawn on timers and can drop mounts, pets, toys and transmog. Many show as skull icons on the map when up.

]]..C.."Treasures"..R..[[ are chests hidden around zones, often with achievements for finding them all.

Every rare that shows up on your minimap is saved to the Bosses section (Rares groups) with its exact spot, for all your characters.]] },

{ id = "housing", group = "3. World & Travel", title = "Player housing: first steps", icon = "INV_Misc_Rune_01",
  tags = "housing house decor neighborhood plot endeavor favor dye founders point razorwind shores",
  body = [[
• ]]..C.."Getting a house"..R..[[ — enter a neighborhood, finish the short intro quest in your quest log, open the map, go to an open plot icon and use its sign to buy it. Then do the decor tutorial inside the house.
• ]]..C.."Neighborhoods"..R..[[ — Founder's Point (Alliance-themed) and Razorwind Shores (Horde-themed). A new copy opens when one fills. The central town has decor vendors, house upgrade NPCs and dye trainers.
• ]]..C.."Ownership"..R..[[ — your Warband can own up to 2 houses, one in each neighborhood. You can pack up and move any time and pay only the new plot's price. The decor placed in a house belongs to that house.
• ]]..C.."Visiting"..R..[[ — public neighborhoods are open to everyone on the server; private ones are for a guild or an invited group.
• ]]..C.."Endeavors"..R..[[ — monthly tasks shared by the whole neighborhood (crafting, gathering, dungeons, raids). They give endeavor currency and Neighborhood Favor. Favor levels up your house and the neighborhood's renown; the currency buys decor from visiting vendors.
• ]]..C.."Other decor sources"..R..[[ — achievements, quests, professions, drops, reputation, and event vendors (for example Hallow's End and Brewfest sell decor for their event tokens).

The Housing Decor page of this addon shows what you own, what you miss and where to get it.]] },

------------------------------------------------------------------------
-- Collections
------------------------------------------------------------------------
{ id = "mounts", group = "4. Collections", title = "Getting mounts", icon = "Ability_Mount_RidingHorse",
  tags = "mount collect riding drop vendor reputation",
  body = [[
Mounts come from: drops (bosses, rares), vendors (gold or currencies), reputation/renown, achievements, quests, professions, events, the Trading Post and the shop.

The ]]..C.."Mounts"..R..[[ section here lists every mount in the game grouped by how you get it, with the exact source text from the game (boss, zone, cost). Uncollected ones are shown dimmed.

Search a boss name to see if it drops a mount, or search "drop" + a zone name.]] },

{ id = "pets", group = "4. Collections", title = "Battle pets and pet battles", icon = "INV_Box_PetCarrier_01",
  tags = "pet battle wild family strong weak trainer",
  body = [[
Talk to a Battle Pet Trainer in any city to unlock pet battles. Then click wild pets (paw icons in zones) to fight and capture them.

]]..C.."Family strengths"..R..[[ (attacker deals extra damage to):
Humanoid » Dragonkin · Dragonkin » Magic · Magic » Flying · Flying » Aquatic · Aquatic » Elemental · Elemental » Mechanical · Mechanical » Beast · Beast » Critter · Critter » Undead · Undead » Humanoid

Rarity: Poor < Common < Uncommon < Rare. Stones from pet battles upgrade rarity.

The Battle Pets section lists every obtainable species grouped by family, with where to find it.]] },

{ id = "transmog", group = "4. Collections", title = "Transmog (appearances)", icon = "INV_Chest_Cloth_17",
  tags = "transmog appearance wardrobe outfit look",
  body = [[
When you loot or equip gear you can wear, its appearance is added to your ]]..C.."Wardrobe"..R..[[ (Collections » Appearances) for your whole Warband.

Change your look at a Transmogrifier NPC in any major city — it costs a little gold. Save full looks as outfits.

Farm old raids (see "Soloing old raids") to collect armor sets. The Transmog Sets section here lists every set by expansion, with which pieces you already have.]] },

{ id = "achievements", group = "4. Collections", title = "Achievements and titles", icon = "Achievement_Quests_Completed_08",
  tags = "achievement title points reward",
  body = [[
Achievements (Y) track goals: exploration, quests, dungeons, raids, PvP, collections and more. Many give rewards: ]]..C.."titles"..R..[[, mounts, pets, toys, décor.

Search "title" in the Codex to find achievements that reward a title, or "reward" to see everything that gives something. Each achievement page shows your criteria progress.]] },

------------------------------------------------------------------------
-- Professions
------------------------------------------------------------------------
{ id = "professions", group = "5. Professions", title = "Professions: the basics", icon = "Trade_BlackSmithing",
  tags = "profession gathering crafting trainer cooking fishing",
  body = [[
You can learn ]]..C.."two primary professions"..R..[[ plus the secondary ones (Cooking, Fishing, Archaeology).

]]..C.."Gathering"..R..[[: Herbalism, Mining, Skinning — collect materials from nodes and corpses. Easy gold and good for beginners.
]]..C.."Crafting"..R..[[: Alchemy, Blacksmithing, Enchanting, Engineering, Inscription, Jewelcrafting, Leatherworking, Tailoring — turn materials into gear, potions and more.

Each expansion has its own skill line (e.g. "Classic Mining", current-expansion Mining). Learn from a trainer in the expansion hub. A classic pair: one gathering + one crafting that uses it (Mining + Blacksmithing, Herbalism + Alchemy, Skinning + Leatherworking).]] },

{ id = "prof-modern", group = "5. Professions", title = "Knowledge, specializations and quality", icon = "INV_Misc_Book_10",
  tags = "knowledge points specialization quality rank concentration crafting order",
  body = [[
Current-expansion professions have:

• ]]..C.."Knowledge points"..R..[[ — earned from weekly quests, treatises, first crafts and hidden treasures. Spend them in the profession's specialization trees.
• ]]..C.."Quality ranks"..R..[[ on materials and crafts — higher-rank reagents give higher-quality results.
• ]]..C.."Crafting orders"..R..[[ — other players (and NPCs) send you orders to craft with their materials, and you earn a commission.

Pick one specialization and stay focused — spreading points too thin is a common beginner mistake.]] },

{ id = "mats", group = "5. Professions", title = "Finding materials (mats & reagents)", icon = "INV_Misc_Herb_Felblossom",
  tags = "mats reagents materials farm cloth leather ore herb",
  body = [[
• ]]..C.."Herbs and ore"..R..[[ — nodes in the open world (track them from the minimap's tracking menu).
• ]]..C.."Leather"..R..[[ — skin beasts after killing them (Skinning).
• ]]..C.."Cloth"..R..[[ — drops from humanoid enemies; no profession needed.
• ]]..C.."Enchanting dust"..R..[[ — disenchant green-or-better gear.
• ]]..C.."Meat and fish"..R..[[ — beasts and fishing pools, for Cooking.

The ]]..C.."Gold Farming"..R..[[ section lists the best places to make gold right now, with live auction prices if you use Auctionator. For open-world farm spots on the map, use ]]..C.."Seviath's Farm Pack"..R..[[.]] },

------------------------------------------------------------------------
-- Economy
------------------------------------------------------------------------
{ id = "auction", group = "6. Gold & Trading", title = "The Auction House", icon = "INV_Misc_Coin_02",
  tags = "auction house ah sell buy commodity deposit gold",
  body = [[
Auction Houses are in every capital. Two kinds of listings:

• ]]..C.."Commodities"..R..[[ (mats, potions): one shared price list — you buy the cheapest first.
• ]]..C.."Items"..R..[[ (gear, mounts, pets): individual listings.

Selling costs a small deposit (returned if it sells) and the house takes a 5% cut. Check prices before listing, and don't undercut by a lot — you only lose gold.]] },

{ id = "binding", group = "6. Gold & Trading", title = "Soulbound, BoE and Warbound", icon = "INV_Misc_Key_03",
  tags = "soulbound boe bind on equip warbound trade",
  body = [[
]]..C.."Soulbound"..R..[[ — yours forever; can't be traded.
]]..C.."Binds when equipped (BoE)"..R..[[ — tradeable and sellable until someone wears it. Often worth gold!
]]..C.."Warbound"..R..[[ — can move between your own characters via the Warband bank, not to other players.
]]..C.."Warbound until equipped"..R..[[ — like BoE but only within your Warband.

Group loot you got in a dungeon or raid can be traded to group members for 2 hours if it isn't an upgrade for you.]] },

{ id = "gold", group = "6. Gold & Trading", title = "Simple ways to make gold", icon = "INV_Misc_Coin_01",
  tags = "gold money farm sell",
  body = [[
• Gather: herbs, ore, leather and cloth always sell.
• Sell BoE gear and recipes from old raids on the Auction House.
• Do world quests with gold rewards.
• Crafting orders if you have a crafting profession.
• Old content farming — Seviath's Farm Pack shows the best open-world spots per expansion with auction values.

Never buy gold from outside the game — it gets accounts banned.]] },
{ id = "dungeon-roles", group = "2. Dungeons, Raids & Delves", title = "Your job in a dungeon (tank, healer, damage)", icon = "Ability_Warrior_DefensiveStance",
  tags = "tank healer dps interrupt kick dispel bloodlust heroism time warp battle res combat res deserter pull mark",
  body = [[
]]..C.."Tank"..R..[[ — you set the pace. Pull the next group only when the healer and the damage dealers are ready (wait if someone is drinking). Mark the target to kill first. Turn bosses away from the group so cone and cleave attacks miss your teammates. Use defensive abilities early, not at the last second. Pick up enemies that run to the healer.

]]..C.."Healer"..R..[[ — keep the tank up first, then everyone else. Remove harmful effects when you can. Drink between pulls so you start every pull with mana. Stand out of the red like everyone else.

]]..C.."Damage"..R..[[ — kill the marked target first. Do not pull on your own. Save big cooldowns for bosses and tough packs. Your other job: ]]..C.."interrupt"..R..[[. Use your kick on dangerous casts (a shield on the cast bar, or a cast that hurts the group).

]]..C.."Removing debuffs"..R..[[ — the border colour of a debuff tells its kind: blue = Magic, purple = Curse, brown = Disease, green = Poison. Each class can remove only some kinds.

]]..C.."Bloodlust / Heroism / Time Warp"..R..[[ — a button for the whole group that makes everyone cast faster for a short time. Shamans, mages, evokers and hunters (through a pet) have one. Use it on a boss or a big fight, not on the first trash pack.

]]..C.."Battle resurrection"..R..[[ — some classes (for example druid, death knight, paladin, warlock) can bring a dead player back in combat. The group shares a few charges, so do not spend one on a trash pack.

]]..C.."Leaving early"..R..[[ — if you leave a Dungeon Finder group before it ends you get the Deserter debuff and cannot queue for a while. Finish the run or ask the group first.]] },

{ id = "weekly-routine", group = "2. Dungeons, Raids & Delves", title = "A simple weekly routine at max level", icon = "INV_Misc_Note_06",
  tags = "weekly routine reset checklist vault keystone delve world quest renown",
  body = [[
Reset is Wednesday in Europe and Tuesday in the Americas. A short list that covers the important rewards:

1. Open the ]]..C.."Great Vault"..R..[[ and pick your item.
2. Do the expansion's ]]..C.."weekly quest"..R..[[ in the hub.
3. Run a Mythic dungeon to get a keystone, then use it.
4. Do the ]]..C.."delves"..R..[[ and the world quests that give things you need.
5. Spend your ]]..C.."renown"..R..[[ progress on the faction that sells what you want.
6. Do each ]]..C.."profession's weekly"..R..[[ tasks for knowledge points.
7. Check the Traveler's Log and the housing Endeavor tasks.
8. Pick one old raid mount or transmog and kill the boss (weekly lockout).

The Weekly Checklist in this addon shows what is left. You do not have to do all of it; pick the three that give you what you want.]] },

{ id = "raid-basics", group = "2. Dungeons, Raids & Delves", title = "Raid basics", icon = "Achievement_Boss_Kelthuzad_01",
  tags = "raid ready check marker mechanics soak stack spread tank swap wipe personal loot journal",
  body = [[
• Before a pull: repair, eat food, use your flask, have potions ready. The raid leader starts a ]]..C.."ready check"..R..[[.
• ]]..C.."Raid markers"..R..[[ — icons the leader puts on targets or on the floor so everyone looks at the same thing.
• ]]..C.."Learn the boss first"..R..[[ — the Adventure Guide (Shift+J) and this Codex show each boss's abilities with a role icon for who they hurt.
• Call-out words: ]]..C.."stack"..R..[[ (stand together), ]]..C.."spread"..R..[[ (stand apart), ]]..C.."soak"..R..[[ (stand in a circle to share the damage), ]]..C.."adds"..R..[[ (extra enemies), ]]..C.."swap"..R..[[ (the second tank takes over), ]]..C.."kite"..R..[[ (keep moving).
• Wipes are normal while learning. Say you are new; most raid leaders explain the first time.
• Loot in most raid groups is personal: each boss gives each player their own chance, so you are not competing with the group.]] },

{ id = "ui-setup", group = "1. Start Here", title = "Set up your screen (Edit Mode, bars, nameplates)", icon = "INV_Misc_Gear_01",
  tags = "edit mode action bars nameplates ui interface cooldown manager damage meter options search layout",
  body = [[
• ]]..C.."Edit Mode"..R..[[ — press Esc and choose Edit Mode. You can drag, resize and hide almost every frame on screen (bags, action bars, minimap, raid frames, chat). Save the result as a layout; you can keep a different layout per spec.
• ]]..C.."Action bars"..R..[[ — turn on extra bars in the Options (use the search box at the top of Options and type "action bar"), then place them in Edit Mode.
• ]]..C.."Nameplates"..R..[[ — the health bars above enemies. Press V to switch enemy nameplates on or off. The Options (search "nameplate") change their size and what they show.
• ]]..C.."Cooldown Manager and Damage Meter"..R..[[ — Blizzard has both built in. Search the Options for "Cooldown" and "Damage Meter" to switch them on, then move them in Edit Mode.
• ]]..C.."Options search"..R..[[ — the box at the top of the Options window finds any setting by name. Menu paths change between patches, so search instead of remembering a path.

Tip: change one thing at a time; if the screen looks wrong, /reload and check Edit Mode.]] },

{ id = "addons-midnight", group = "1. Start Here", title = "Addons in Midnight", icon = "INV_Misc_EngGizmos_17",
  tags = "addons weakauras bigwigs dbm details damage meter boss timeline restricted combat curseforge",
  body = [[
Midnight changed what addons may do ]]..C.."in combat"..R..[[. The idea: addons can change how information looks, but not what the player acts on.

• ]]..C.."Boss warnings"..R..[[ — the game has a built-in boss ability timeline and alerts. Boss-mod addons can no longer read combat events to detect mechanics the way they did.
• ]]..C.."Damage meter"..R..[[ — a basic one is built in. Meter addons can show limited data during a fight.
• ]]..C.."WeakAuras"..R..[[ — triggers that depend on combat events may not work anymore.
• ]]..C.."Messages between players"..R..[[ — addon messages can be limited during raid boss fights and timed Mythic+ runs, and work normally between pulls.

Still fine: addons that restyle the UI, and tools for bags, the map, the Auction House, collections and planning (like this one).

Where to get addons: CurseForge, Wago or WoWInterface only. Check that the addon page says it supports the current patch and read the latest comments.]] },

{ id = "currencies", group = "1. Start Here", title = "Currencies", icon = "INV_Misc_Coin_17",
  tags = "currency currencies crest cap weekly cap warband transfer honor conquest",
  body = [[
Almost every system pays in its own currency, not gold. Open the ]]..C.."Currency"..R..[[ tab in the Character window (C) to see all of them.

• ]]..C.."Total cap and weekly cap"..R..[[ — many currencies have a maximum you can hold and a maximum you can earn per week. Hover one to see both.
• ]]..C.."Show on the backpack"..R..[[ — tick "Show on Backpack" on a currency to keep it in view at the bottom of your bags.
• ]]..C.."Warband transfer"..R..[[ — some currencies can be moved to another character of yours: right-click the currency and look for the transfer option.
• ]]..C.."Seasonal currencies"..R..[[ — gear upgrades use currencies that change each season. Read the tooltip and the upgrade vendor in the expansion hub.
• ]]..C.."Where it is spent"..R..[[ — decor, mounts, pets, toys and old transmog all have vendors that take a currency. The Codex shows the cost on those pages.

Do not hoard currencies you cannot use; do not spend a scarce one before checking what else it buys.]] },

{ id = "social", group = "1. Start Here", title = "Guilds, communities and friends", icon = "INV_Misc_Note_05",
  tags = "guild community friends battle.net chat trade general quick join ignore report",
  body = [[
• ]]..C.."Guild & Communities (J)"..R..[[ — find a guild in Guild Finder, or make a Community for friends. Communities have their own chat and can organise events.
• ]]..C.."Social panel (O)"..R..[[ — Battle.net friends show up across Blizzard games. Quick Join shows groups your friends are in; click to ask to join.
• ]]..C.."Chat channels"..R..[[ — General is for the zone; Trade is for buying and selling and works in cities only. Right-click a chat tab to choose which channels you see.
• ]]..C.."Whisper"..R..[[ — type /w name message, or click a name.
• ]]..C.."Problems"..R..[[ — right-click a player and choose Ignore or Report. Reports go to Blizzard.

A good guild is active at the times you play, has people of your level, and has a goal you share (raids, keys, relaxed). Ask for a trial period.]] },

{ id = "tooltip", group = "1. Start Here", title = "Reading an item tooltip", icon = "INV_Misc_Spyglass_03",
  tags = "tooltip item level stats armor type red text compare shift upgrade arrow vendor price",
  body = [[
• ]]..C.."Item level"..R..[[ — the number at the top. Higher is stronger.
• ]]..C.."Hold Shift"..R..[[ while you hover an item to see your equipped item beside it.
• ]]..C.."Green arrow"..R..[[ on an item in your bags — it is an upgrade for that slot.
• ]]..C.."Red text"..R..[[ — you cannot use it (wrong armor type, level or spec).
• ]]..C.."Armor type"..R..[[ — cloth, leather, mail or plate. Wearing your class's own type gives a bonus to your main stat.
• ]]..C.."Equip / Use / Chance on hit"..R..[[ — the effect lines. "Use" is a button you press.
• ]]..C.."Binding line"..R..[[ — Soulbound, Binds when picked up/equipped, Warbound (see "Soulbound, BoE and Warbound").
• ]]..C.."Sell price"..R..[[ at the bottom — what a vendor pays. It is often far lower than the Auction House price.]] },

{ id = "safety", group = "1. Start Here", title = "Account safety and scams", icon = "INV_Misc_Key_03",
  tags = "safety scam phishing authenticator password gold buying token",
  body = [[
• Turn on the ]]..C.."Battle.net Authenticator"..R..[[ (the Battle.net app) in your account settings.
• Blizzard never asks for your password in a whisper, chat or email. Do not click "free mount", "account verify" or giveaway links.
• Never buy gold, boosts or accounts outside the game. It gets accounts banned.
• Get gold the allowed way: the ]]..C.."WoW Token"..R..[[ on the Auction House sells for gold and is bought with real money.
• Be wary of anyone who offers you a large amount of free gold in a trade or a "giveaway". It is often a scam, or gold from hacked accounts or gold sellers. That gold can be taken back and the accounts that took it can be warned or banned. Say no, do not click their links, and report them.
• Do not trade items for a promise. Trade only inside the trade window and check the window before you click accept.
• Install addons only from CurseForge, Wago or WoWInterface.]] },

{ id = "midnight", group = "1. Start Here", title = "Midnight at a glance", icon = "INV_Misc_Map_01",
  tags = "midnight 12.0 level 90 haranir devourer eversong harandar voidstorm zulaman silvermoon",
  body = [[
]]..C.."Written for the Midnight launch (2026). Parts may change with patches."..R..[[

• ]]..C.."Level cap 90."..R..[[
• ]]..C.."Four zones:"..R..[[ Eversong Woods, Zul'Aman, Harandar and Voidstorm. Silvermoon City was rebuilt.
• ]]..C.."Haranir"..R..[[ — a new allied race.
• ]]..C.."Devourer"..R..[[ — a third Demon Hunter specialization.
• ]]..C.."Valeera"..R..[[ is the companion in delves. ]]..C.."Prey"..R..[[ hunts are a new opt-in open-world system.
• ]]..C.."Four renown factions:"..R..[[ Silvermoon Court, Amani Tribe, Hara'ti and The Singularity.
• ]]..C.."Transmog was reworked."..R..[[ Each slot can remember its look. Check the Transmog window before you change outfits.
• ]]..C.."Skyriding"..R..[[ was simplified compared with earlier versions.]] },

{ id = "pvp", group = "7. PvP", title = "PvP for beginners", icon = "Achievement_PVP_A_01",
  tags = "pvp battleground arena rated solo shuffle blitz war mode honor conquest brawl deserter",
  body = [[
Open the Group Finder (I) and use the ]]..C.."Player vs. Player"..R..[[ tab. The modes the game offers there:

]]..C.."Battlegrounds"..R..[[ — team objective maps. Random battlegrounds are the best way to start. Play the objective; chasing kills loses games.
]]..C.."Arenas"..R..[[ — small teams (2v2, 3v3). Practice matches are not rated; rated ones give a rating.
]]..C.."Solo Shuffle and Blitz"..R..[[ — rated modes you can queue for alone, no premade group needed.
]]..C.."War Mode"..R..[[ — a switch you can turn on in your faction capital. In the open world you can then fight (and be fought by) other players who have it on, in return for extra rewards.

]]..C.."Currencies"..R..[[ — Honor comes from any PvP and buys honor gear. Conquest comes from rated play and buys the stronger gear. Find the PvP vendors in your faction capital.

Tips: PvP uses its own talent row, so check it before you queue. The game scales item level inside PvP, so gear matters less than in a raid. Leaving a battleground early gives the Deserter debuff.]] },

{ id = "prey", group = "3. World & Travel", title = "Prey hunts", icon = "Ability_Hunter_SniperShot",
  tags = "prey hunt astalor bloodsworn murder row silvermoon preyhunter journey",
  body = [[
Prey is an opt-in hunting system in the open world. You sign up with ]]..C.."Astalor Bloodsworn"..R..[[ in Silvermoon, then track and kill a powerful enemy in a zone. There are several difficulty levels. Rewards include cosmetics, mounts, titles and housing decor. Progress counts toward the ]]..C.."Preyhunter's Journey"..R..[[, whose ranks unlock vendor items.]] },

{ id = "trading-post", group = "4. Collections", title = "Trading Post and Traveler's Log", icon = "INV_Misc_Bag_09",
  tags = "trading post traveler's log tender monthly cosmetics perks",
  body = [[
Open the ]]..C.."Traveler's Log"..R..[[ in the Adventure Guide (Shift+J). It lists monthly activities (kill a boss, finish a dungeon, craft something). Each one pays a currency (Trader's Tender). The ]]..C.."Trading Post"..R..[[ sells cosmetics, mounts and pets for it. Its stock changes every month, so spend what you have before the month ends if something you want is there.]] },

{ id = "prof-leveling", group = "5. Professions", title = "Leveling a profession", icon = "Trade_Engineering",
  tags = "profession leveling skill concentration crafting order trainer",
  body = [[
1. Learn the profession from the trainer in the expansion hub. Open it with K.
2. Use the tab of the newest skill line. Craft the cheapest recipe that can still raise your skill (the recipe tooltip tells you).
3. ]]..C.."Crafting orders"..R..[[ — instead of searching the Auction House, post an order from the profession window and a crafter makes it for a commission. If you are the crafter, answer orders from the Orders tab.
4. ]]..C.."Concentration"..R..[[ — a resource that refills slowly over time. Spend it on crafts where a higher quality is worth the materials.
5. Do the weekly knowledge tasks before you spend gold on anything else.]] },

{ id = "gold-mistakes", group = "6. Gold & Trading", title = "Common gold mistakes", icon = "INV_Misc_Coin_03",
  tags = "gold mistakes boe vendor trash token warband bank",
  body = [[
• Selling a green or blue Bind-on-Equip piece to a vendor. Check the Auction House first.
• Vendoring crafting materials (cloth, leather, herbs) as "junk".
• Undercutting a price by a lot. You only lose gold.
• Leaving gold on one character. The Warband bank can hold gold your other characters can use.
• Buying cosmetics before bags and your profession.
• Buying gold from sellers. See "Account safety and scams".]] },
{ id = "talents", group = "1. Start Here", title = "Talents: class, spec and hero trees", icon = "Ability_Marksmanship",
  tags = "talents talent tree class hero apex loadout import export respec points build",
  body = [[
Open your talents with ]]..C.."N"..R..[[. They come in parts:

• ]]..C.."Class tree"..R..[[ — abilities every spec of your class can pick from.
• ]]..C.."Spec tree"..R..[[ — abilities for the spec you are playing now.
• ]]..C.."Hero tree"..R..[[ — an extra tree you unlock around level 71. Each spec chooses between hero trees; choose one.
• Midnight raises the level cap to 90 and adds more talent points, including a new set of end-of-tree talents.

]]..C.."Loadouts"..R..[[ — save a set of talents under a name (Talents window » Loadouts) and switch with one click. Make one for dungeons, one for raids and one for solo play.

]]..C.."Importing builds"..R..[[ — class guide websites give you a long text string. In the Talents window choose Import, paste it and accept. It sets every point for you.

]]..C.."Changing talents"..R..[[ — inside a city or other resting area it is free. Elsewhere you may need an item or a place that allows it; the game tells you when you click.

Tip: do not copy a "max damage" build on your first day. Read what each talent does and pick the ones that make your class fun.]] },

{ id = "stats-words", group = "1. Start Here", title = "Stats and resources in plain words", icon = "Spell_Holy_BlessingOfStrength",
  tags = "stats crit haste mastery versatility stamina armor leech avoidance resource mana rage energy focus gcd cooldown proc dot hot threat aggro line of sight diminishing returns",
  body = [[
]]..C.."Main stats"..R..[[
• Strength, Agility, Intellect — your class's main stat; it raises damage or healing. Use gear with your main stat.
• Stamina — more health.
• Armor — less physical damage taken.

]]..C.."Secondary stats"..R..[[
• Critical Strike — chance to do double damage or healing.
• Haste — faster casting, faster attacks, faster resource gain.
• Mastery — a bonus that is different for each spec; read your spec's mastery text.
• Versatility — more damage and healing, and less damage taken.
Bonus stats: Leech (heal from damage), Avoidance (less damage from area attacks), Speed (move faster).

]]..C.."Resources"..R..[[
• Mana — casters and healers; refills slowly and by drinking.
• Rage — builds when you hit or are hit.
• Energy / Focus — fills steadily on its own.
• Special bars — combo points, holy power, soul shards, runes and others.

]]..C.."Words you will hear"..R..[[
• GCD — the short pause after most abilities (about 1.5 seconds, shorter with haste).
• Cooldown (CD) — an ability you can use again after a wait.
• Proc — a random bonus that happens when you attack.
• DoT / HoT — damage or healing that ticks over time.
• Aggro / threat — the enemy's choice of who to hit. The tank wants it; damage dealers should not take it.
• Line of sight — a wall between you and a caster stops the spell. Hide behind a pillar.
• Diminishing returns — in PvP the same stun or fear gets shorter each time and then stops working for a while.]] },

{ id = "targeting", group = "1. Start Here", title = "Targeting and mouse basics", icon = "Ability_Hunter_MarkedForDeath",
  tags = "target tab focus assist mouseover interact soft target click nameplate",
  body = [[
• ]]..C.."Tab"..R..[[ — selects the nearest enemy in front of you. Press it again for the next one.
• ]]..C.."Click"..R..[[ an enemy, a nameplate or a party member's frame to target them.
• ]]..C.."Focus target"..R..[[ — a second target you keep while attacking something else (useful for interrupts). Set it from the right-click menu of a portrait, or bind a key in the keybindings.
• ]]..C.."Assist"..R..[[ — copy the target of another player (the tank in a dungeon) with a key or by right-clicking their frame.
• ]]..C.."Interact"..R..[[ — a key press that talks to the nearest NPC or opens the nearest object. Bind it in the keybindings and you can play with fewer mouse clicks.
• ]]..C.."Soft targeting"..R..[[ — the game can pick the thing in front of you automatically; search the Options for "target" to turn it on or off.

If a button does not seem to work, check that you have the right target selected; the portrait at the top left shows it.]] },

{ id = "comfort", group = "1. Start Here", title = "Comfort and accessibility settings", icon = "INV_Misc_Eye_01",
  tags = "accessibility colorblind text size ui scale camera motion subtitles text to speech sound captions",
  body = [[
Use the search box at the top of the Options window; menu names move between patches.

• Search ]]..C.."Accessibility"..R..[[ — colour-blind modes, text-to-speech and other aids.
• Search ]]..C.."UI scale"..R..[[ or ]]..C.."text"..R..[[ — make the whole interface larger. Edit Mode can enlarge single parts like chat.
• Search ]]..C.."camera"..R..[[ — lower shaking and movement if you get dizzy.
• Search ]]..C.."sound"..R..[[ — turn music down, silence ambience, play sound when the game is in the background.
• Search ]]..C.."floating combat text"..R..[[ — numbers over enemies; turn them down if the screen feels cluttered.
• Chat can get a bigger font, a different background and its own tabs (right-click a tab).

Take breaks. A long play session after leveling a character in a day is a good way to get tired of the game.]] },

{ id = "troubleshooting", group = "1. Start Here", title = "Fixing common problems (lag, FPS, UI, errors)", icon = "INV_Misc_Wrench_01",
  tags = "lag fps latency crash addon error reload reset ui repair graphics wtf cache console scripterrors",
  body = [[
]]..C.."The interface looks wrong or an addon is stuck"..R..[[ — type /reload. It is safe and fast.

]]..C.."An error message pops up"..R..[[ — an addon is the usual cause. Open the AddOns list at the character screen and disable addons one by one until the error goes. To see error details type /console scriptErrors 1; type /console scriptErrors 0 to hide them again.

]]..C.."Lag"..R..[[ — the network icon shows two delays: Home (your internet to the game) and World (the game server). High Home means your connection; high World means the server or the area is busy. Close downloads and other streams, use a cable if you can.

]]..C.."Low frame rate"..R..[[ — lower the graphics quality in the Options, lower view distance and particle density, and use the separate "Raid and Battleground" graphics settings so big fights run smoother.

]]..C.."The whole interface is broken"..R..[[ — close the game and rename (do not delete) the Interface and WTF folders in the game's folder; start the game and it makes new ones. You can copy your settings back later.

]]..C.."The game will not start or files are corrupt"..R..[[ — in the Battle.net app choose the game, click the gear and use Scan and Repair.

If nothing helps, ask in the Blizzard support forums or in your guild and include the exact error text.]] },

{ id = "mplus-start", group = "2. Dungeons, Raids & Delves", title = "Mythic+ for beginners", icon = "INV_Relics_Hourglass",
  tags = "mythic plus m+ keystone start beginner affix fortified tyrannical teleport portal room upgrade crest vault rating",
  body = [[
Start here if the page "Mythic+ keystones" left you wondering where to begin.

1. Get your gear to a good level with normal and heroic dungeons, world quests and delves.
2. Run a ]]..C.."Mythic"..R..[[ dungeon (no timer) so you get your keystone for the week.
3. Join a ]]..C.."low key"..R..[[ from Premade Groups; write "learning" in your application. Low keys have gentler affixes.
4. Higher keys add weekly affixes: ]]..C.."Fortified"..R..[[ (stronger trash) and ]]..C.."Tyrannical"..R..[[ (stronger bosses) alternate week by week, and the highest keys add more rules. The Mythic+ window shows this week's affixes.
5. Beat the timer to upgrade the key; the run's rating counts toward your Mythic+ rating and the Great Vault.

]]..C.."Teleports"..R..[[ — timing a high enough key in a dungeon this season gives you a teleport spell to it. The expansion hub has a Mythic+ portal room.

]]..C.."Upgrades"..R..[[ — the Item Upgrade Vendor and the Crest Exchange vendor are in the expansion hub (Silvermoon City in Midnight).

]]..C.."Season rewards"..R..[[ — each season has rating goals that give a mount and a title.

|cff888888Affixes and key ranges change every season. Check the in-game Mythic+ window.|r]] },

{ id = "delves-deep", group = "2. Dungeons, Raids & Delves", title = "Delves in depth", icon = "INV_Misc_Lantern_01",
  tags = "delve tier valeera companion curio bountiful coffer key shards revive vault nemesis undercoin",
  body = [[
• ]]..C.."What a delve is"..R..[[ — a short run (about 10 to 15 minutes), solo or with up to 4 others, with Valeera as your companion.
• ]]..C.."Tiers"..R..[[ — tier 1 is the easiest. Higher tiers need an achievement first, and gear stops improving at a certain tier; above that you earn crests instead. The in-game delve window shows which.
• ]]..C.."Valeera"..R..[[ — pick her role (healer, damage or tank) and her curios at the start of a delve and at each checkpoint. Use the Delve Planner in this addon to pick a setup for your spec.
• ]]..C.."Revives"..R..[[ — every death uses a revive; low tiers have no limit, higher tiers have a few. A checkpoint gives you one back. How many you keep changes how good your reward is.
• ]]..C.."Bountiful delves"..R..[[ — they have a glowing icon on the map and a coffer at the end. The coffer needs a key, which you make from key shards from world activities and quests. The bountiful delves change every day.
• ]]..C.."Great Vault"..R..[[ — delves you finish in a week open the delve slots of the Vault. More runs and higher tiers give better choices.
• ]]..C.."Nemesis delve"..R..[[ — at higher tiers stronger enemies appear; beating their packs upgrades the strongbox, and the boss can be called with an item bought in Silvermoon.

|cff888888Tier numbers, revive counts and rewards belong to the current season. Check the in-game delve window.|r]] },

{ id = "dungeon-access", group = "2. Dungeons, Raids & Delves", title = "Getting to a dungeon fast", icon = "Spell_Arcane_PortalOrgrimmar",
  tags = "dungeon entrance meeting stone summon summoning stone portal teleport warlock mage group finder walk",
  body = [[
• ]]..C.."Group Finder queue"..R..[[ — when the queue pops and you accept, the game teleports you into the dungeon. When it ends you are teleported back. This is the easiest way.
• ]]..C.."Premade group"..R..[[ — the group meets at the dungeon entrance outside. Find the entrance in the Entrances section of the Codex and press Show on map.
• ]]..C.."Meeting stone"..R..[[ — a stone at most dungeon entrances. Click it to summon group members who are too far away.
• ]]..C.."Warlock summon"..R..[[ — warlocks can summon the group from further away.
• ]]..C.."Mage portals"..R..[[ — mages can open a portal to a capital city. Ask nicely, and tip.
• ]]..C.."Dungeon teleports"..R..[[ — timing a high Mythic+ key unlocks a teleport spell for that dungeon.
• ]]..C.."Hearthstone and portal rooms"..R..[[ — see "Getting around".

If you arrive late, say so in chat; do not rush into a pull without the tank.]] },

{ id = "consumables", group = "2. Dungeons, Raids & Delves", title = "Food, flasks and potions", icon = "INV_Potion_93",
  tags = "food flask potion consumable healthstone feast cauldron rune well fed buff oil cooking alchemy",
  body = [[
Raiders and key runners use consumables for a small but real power boost. New players can skip most of them, but they are cheap and good to know.

• ]]..C.."Food"..R..[[ — eat before a run for a "Well Fed" buff that adds a stat. Cooks make it; you can also buy it at the Auction House.
• ]]..C.."Flasks"..R..[[ — a long-lasting buff made by alchemists. Drink one before a raid or a hard key.
• ]]..C.."Potions"..R..[[ — a health potion heals you in combat. A combat potion raises damage for a short time. Each type has its own cooldown. Keep a health potion on your action bar.
• ]]..C.."Healthstones"..R..[[ — ask a warlock for one. It heals you right away in combat and is free.
• ]]..C.."Feasts and cauldrons"..R..[[ — a cook or alchemist can place one that gives the whole group the buff. Ask in group chat before you spend your own.
• ]]..C.."Runes and oils"..R..[[ — extra buffs for raiders and key runners.

Use them for raids and high keys, not for leveling. Use the Auction House price to decide whether you buy or craft.]] },

{ id = "adventure-guide", group = "3. World & Travel", title = "The Adventure Guide and the Dungeon Journal", icon = "INV_Misc_Book_09",
  tags = "adventure guide shift j dungeon journal suggested content loot filter bosses traveler's log item sets",
  body = [[
Open the Adventure Guide with ]]..C.."Shift+J"..R..[[.

• ]]..C.."Suggested Content"..R..[[ — what the game recommends for your level and item level right now: quests, dungeons, delves, raids. This is the best answer to "what should I do next?".
• ]]..C.."Dungeons and Raids (the Journal)"..R..[[ — every instance with its bosses, their abilities (with a role icon for tank, healer or damage) and their loot. Use the loot filter to show items for your class and spec only, and the difficulty selector to see the loot of each difficulty.
• ]]..C.."Item Sets"..R..[[ — shows the pieces of tier sets and where they come from.
• ]]..C.."Traveler's Log"..R..[[ — the monthly activities and the Trading Post.

Read a boss's abilities in the Journal before your first run. Seeing what is coming makes the fight easier. The Codex shows the same boss pages with entrance maps.]] },

{ id = "events", group = "3. World & Travel", title = "Holiday events and the calendar", icon = "INV_Misc_Note_03",
  tags = "holiday event calendar darkmoon faire hallow's end winter veil brewfest lunar festival love is in the air noblegarden midsummer pilgrim's bounty",
  body = [[
Open the calendar with the small calendar button at your minimap. It lists every event with the real dates and any timewalking or bonus weeks.

Usual times of the year (the exact dates change, so check the calendar):

• ]]..C.."Darkmoon Faire"..R..[[ — a fair that opens the first week of every month. Games, quests, profession work and a few collectibles.
• ]]..C.."Lunar Festival"..R..[[ — around January and February.
• ]]..C.."Love is in the Air"..R..[[ — around February.
• ]]..C.."Noblegarden"..R..[[ — in spring.
• ]]..C.."Children's Week"..R..[[ — in spring.
• ]]..C.."Midsummer Fire Festival"..R..[[ — around the end of June.
• ]]..C.."Brewfest"..R..[[ — September and early October.
• ]]..C.."Hallow's End"..R..[[ — around the end of October.
• ]]..C.."Pilgrim's Bounty"..R..[[ — November.
• ]]..C.."Winter Veil"..R..[[ — mid-December to the new year.

Events give achievements, titles, pets, toys, mounts, transmog and housing decor. Some decor vendors take event tokens. Event decor can only be bought while the event runs, so check the Housing Decor page in this addon before it ends.]] },

{ id = "collections-window", group = "4. Collections", title = "Heirlooms, toys and the Collections window", icon = "INV_Misc_Toy_10",
  tags = "heirloom toy box collections favorite mount random mount hearthstone toy warband shift p",
  body = [[
Open the Collections window with ]]..C.."Shift+P"..R..[[.

• ]]..C.."Mounts"..R..[[ — mark mounts as favourites with the star. The "Summon Random Favorite Mount" button picks one of them for you.
• ]]..C.."Pets"..R..[[ — your battle pets and companion pets. Right-click to summon one.
• ]]..C.."Toys"..R..[[ — fun items you can use for free: costumes, fireworks, extra hearthstones. They are shared by your whole Warband.
• ]]..C.."Heirlooms"..R..[[ — special gear that gives you bonus experience while leveling and grows with your level. They are bought from heirloom vendors in the capital cities and shared by all your characters, so they pay back fast if you level more than one character.
• ]]..C.."Appearances"..R..[[ — your transmog wardrobe (see the Transmog page).

Use the search box in each tab and the "collected / not collected" filters to see what you are missing. The Codex and the My Collections page of this addon show where to get what you miss.]] },

{ id = "secondary-profs", group = "5. Professions", title = "Cooking, Fishing and Archaeology", icon = "INV_Misc_Fish_02",
  tags = "cooking fishing archaeology secondary profession pole lure pool digsite survey artifact",
  body = [[
Secondary professions are free to learn on every character and do not use your two main profession slots.

]]..C.."Cooking"..R..[[ — makes food for your own buffs and for sale. Learn recipes from trainers and vendors; find rarer ones as drops or in the world. Raw meat, fish and spices come from beasts, fishing and vendors.

]]..C.."Fishing"..R..[[ — equip a fishing pole and cast near water or at a fishing pool (patches of bubbling or rippling water). Lures raise your skill for a short time. You catch fish for Cooking, gold and sometimes pets and mounts.

]]..C.."Archaeology"..R..[[ — open the Archaeology window, pick a dig site on the map and use the survey tool to find fragments. When you have enough, solve the artifact for transmog, toys, pets and rare mounts. It is slow and relaxing.

All three work well beside a gathering profession as a quiet money maker, and you can do them while you wait for a group.]] },
{ id = "how-updates", group = "1. Start Here", title = "How expansions, patches and seasons work", icon = "INV_Misc_Note_01",
  tags = "expansion patch season ptr hotfix 12.0 12.1 early access raid opening reset rating new season",
  body = [[
Knowing how the game updates helps you tell why a guide is right or wrong.

• ]]..C.."Expansion"..R..[[ — a big release, about every two years. Midnight (patch 12.0) came out in 2026 and raised the level cap to 90, with new zones, dungeons, raids and systems.
• ]]..C.."Patch"..R..[[ — an update. The numbers tell you the size: 12.0 is the expansion, 12.1 and 12.2 are big content patches (new zones, raids, features), and the third digit (12.0.5) is a smaller update.
• ]]..C.."Raid opening"..R..[[ — raids do not all open on day one; they open in steps after launch, and higher difficulties come a little later.
• ]]..C.."Season"..R..[[ — a period of several months inside an expansion. A new season resets the Mythic+ rating, changes the Mythic+ dungeon list and gear item levels, and brings new upgrade currencies and rewards.
• ]]..C.."Hotfix"..R..[[ — a quick fix from Blizzard that does not need a download. Things change without a patch number.
• ]]..C.."Test servers (PTR)"..R..[[ — players test the next patch early. Anything you read about a patch before it is live may change.

Why it matters: a guide that mentions item levels, affixes or currencies from an old season is out of date, even if the rest is right.]] },

{ id = "realms", group = "1. Start Here", title = "Realms and servers", icon = "INV_Misc_Map_01",
  tags = "realm server connected realm region cross realm transfer name change pve pvp rp auction house",
  body = [[
• ]]..C.."Realm"..R..[[ — one copy of the game world. You choose one when you make a character. You can play on any realm of your region with the same account.
• ]]..C.."Connected realms"..R..[[ — small realms are joined into one group. They share an Auction House and the same people in the open world.
• ]]..C.."Cross-realm play"..R..[[ — the Group Finder, Premade Groups, dungeons, raids and PvP put players from many realms together. You are not stuck with your own realm's population.
• ]]..C.."Types"..R..[[ — Normal (PvE) realms, PvP realms and Role-Playing realms. On a Normal realm you are only fought in PvP if you choose it (War Mode). Role-Playing realms expect in-character chat.
• ]]..C.."Your Warband"..R..[[ — mounts, pets, toys, appearances and the Warband bank follow you across realms on your account.
• ]]..C.."Auction House"..R..[[ — shared by connected realms, not by all realms. Prices from this addon say which realm they were scanned on.
• ]]..C.."Moving"..R..[[ — a character can be moved to another realm or renamed with a paid service. Do it only if you must; a guild and friends on one realm are worth more than a realm's size.]] },

{ id = "returning", group = "1. Start Here", title = "Coming back after a break (checklist)", icon = "INV_Misc_Note_06",
  tags = "returning player comeback catch up checklist talents hero talents gear warband bank housing mail",
  body = [[
A short order that works for most people:

1. ]]..C.."Update the game and your addons."..R..[[ Disable addons that say they do not work with the current patch.
2. ]]..C.."Log in on the character you liked best"..R..[[ and read your mail. Old mail may hold gold and gear.
3. ]]..C.."Re-check your talents (N)."..R..[[ An old build may be invalid or weak. Pick a hero talent tree (see "Talents").
4. ]]..C.."Check your gear."..R..[[ The Adventure Guide (Shift+J) shows what to do for your item level. Heroic dungeons, world quests and delves are the usual way back up.
5. ]]..C.."Follow the current expansion's campaign"..R..[[ from the start. It gives gear and unlocks features such as renown and flying.
6. ]]..C.."Look through your Warband bank and your alts."..R..[[ You may have gold, currencies, Bind-on-Equip gear and heirlooms waiting.
7. ]]..C.."Open the Great Vault"..R..[[ at your next reset.
8. ]]..C.."Try one new system"..R..[[ such as housing, delves or the Prey hunts. You do not have to do them all.
9. ]]..C.."Open the calendar"..R..[[ to see the holiday event running.
10. ]]..C.."Sell what you no longer need"..R..[[ on the Auction House. Scan prices with this addon first.

Be ready to feel behind. Almost everything is catch-up now, and it takes a few weeks, not months.]] },

{ id = "solo-play", group = "1. Start Here", title = "Playing alone: what you can do solo", icon = "Achievement_Character_Human_Male",
  tags = "solo alone single player delve follower dungeon world quest legacy raid pet battle archaeology fishing housing transmog achievement",
  body = [[
You do not need a group for much of the game.

• ]]..C.."Delves"..R..[[ — built for 1 to 5 players, with Valeera as your companion. Higher tiers give better gear.
• ]]..C.."Follower dungeons"..R..[[ — run chosen dungeons with NPC companions instead of players.
• ]]..C.."World quests, rares and treasures"..R..[[ — everything in the open world works alone.
• ]]..C.."Prey hunts"..R..[[ — opt-in open-world hunts with gear, cosmetic and decor rewards.
• ]]..C.."Soloing old raids"..R..[[ — at max level you can kill most old bosses alone for mounts and transmog (see "Soloing old raids").
• ]]..C.."Pet battles"..R..[[ — a calm one-player game inside the game.
• ]]..C.."Collecting"..R..[[ — mounts, pets, toys, transmog sets and achievements.
• ]]..C.."Professions"..R..[[ — gathering, crafting, cooking, fishing and archaeology.
• ]]..C.."Housing"..R..[[ — decorate and visit others.

For group content without pressure, use the Raid Finder (easiest raid difficulty) and the Group Finder with "learning" in the listing.]] },

{ id = "leveling", group = "1. Start Here", title = "Leveling without wasting time", icon = "Achievement_Level_90",
  tags = "leveling level faster experience rested chromie time heirloom campaign dungeon side quests",
  body = [[
• ]]..C.."Follow the main storyline (campaign)."..R..[[ It gives the most experience per minute and unlocks features. Do the side quests you find on the way; skip detours.
• ]]..C.."Chromie Time"..R..[[ — pick one older expansion at Chromie in Stormwind or Orgrimmar. Choose the one with the story you like; quest rewards scale to your level.
• ]]..C.."Dungeons while you level"..R..[[ — queue for dungeons with the Group Finder while you quest. A dungeon gives experience, gear and a short rest from travel.
• ]]..C.."Heirlooms"..R..[[ — pieces that give bonus experience (see the Heirlooms page). They pay back if you level more than one character.
• ]]..C.."Rested experience"..R..[[ — log out in an inn or a city and you earn bonus experience.
• ]]..C.."Don't rush"..R..[[ — max level is where the choices begin. A character you like playing beats a fast one you don't.

|cff888888Some content needs an earlier campaign finished first. The Adventure Guide tells you what you need to continue.|r]] },

{ id = "gear-tracks", group = "2. Dungeons, Raids & Delves", title = "Gear tracks: where each level of gear comes from", icon = "INV_Chest_Plate16",
  tags = "gear track adventurer veteran champion hero myth crest upgrade rank vault item level raid mythic plus delve prey crafted",
  body = [[
Each piece of gear belongs to a ]]..C.."track"..R..[[. The track tells you how far it can be upgraded. From weakest to strongest: ]]..C.."Adventurer, Veteran, Champion, Hero, Myth"..R..[[. A piece has a rank in its track (for example 2/6); upgrade vendors raise the rank with ]]..C.."crests"..R..[[ and gold.

In general, harder content gives a higher track:
• ]]..C.."World"..R..[[ — world quests, rares and Prey hunts give the lower tracks; harder Prey difficulties give higher ones.
• ]]..C.."Dungeons"..R..[[ — Heroic gives lower tracks; Mythic gives higher ones.
• ]]..C.."Delves"..R..[[ — higher tiers and bountiful delves with a coffer key give better gear.
• ]]..C.."Mythic+"..R..[[ — higher keys give higher tracks, and the Great Vault slot for a high key is the best one.
• ]]..C.."Raids"..R..[[ — each difficulty gives a higher track than the one below it. Each boss gives loot once a week.
• ]]..C.."Crafted gear"..R..[[ — quality and upgrades come from the profession (crests and special materials).
• ]]..C.."Great Vault"..R..[[ — one pick each week, usually better than what you could find in the same week.

How to climb: get mid-track gear from Mythic dungeons and delves, then higher tracks from keys and Heroic raid bosses. Upgrade the pieces you will keep. Do not spend crests on gear you will replace next week.

|cff888888The exact track for each activity changes every season. Check the item level shown in the Group Finder and the Adventure Guide, and the upgrade tooltip on the item.|r]] },

{ id = "bags-bank", group = "6. Gold & Trading", title = "Bags, bank and Warband bank", icon = "INV_Misc_Bag_08",
  tags = "bag bank warband bank reagent bag sort inventory space slots gold transfer",
  body = [[
• ]]..C.."Bags"..R..[[ — you have a few bag slots plus one reagent bag slot that holds crafting materials only. Bigger bags (crafted by tailors, bought or found) are the cheapest way to gain space.
• ]]..C.."Sort and sell"..R..[[ — the clean-up button in your bags sorts them. At a vendor the "sell all junk" button sells grey items.
• ]]..C.."Bank"..R..[[ — your character's own storage. Open it at any banker.
• ]]..C.."Warband bank"..R..[[ — storage shared by every character on your account. Put things there to move them to your other characters. It also holds gold, which any character can withdraw.
• ]]..C.."Which items fit"..R..[[ — Warbound items can go in the Warband bank. Soulbound items cannot be moved. Bind-on-Equip items can be moved.
• ]]..C.."Habits that save space"..R..[[ — keep crafting materials in the reagent bag, put quest items and things you might need later in the bank, and do a clean-up before a long trip.

Tip: before you vendor "junk" gear, check its value on the Auction House. Rare Bind-on-Equip pieces can be worth a lot. The Alt Overview page of this addon lists what your characters carry and have in the bank.]] },

{ id = "mail-trade", group = "6. Gold & Trading", title = "Mail and trading safely", icon = "INV_Letter_15",
  tags = "mail trade window cod cash on delivery scam gold send alt attachments expire",
  body = [[
• ]]..C.."Mail"..R..[[ — open any mailbox in a town. You can attach items and gold to a letter. Mail between your own characters arrives at once; mail that is not collected returns to the sender after a while.
• ]]..C.."Cash on delivery"..R..[[ — a letter that asks the receiver to pay before they can take the item. Read the price before you accept one. Scammers use it.
• ]]..C.."Trade window"..R..[[ — click a player and choose Trade. Both players put in items or gold, and both press Accept. Check the other side before you accept. Nothing happens until both have accepted.
• ]]..C.."Soulbound items"..R..[[ — cannot be traded or mailed. Loot from a group can be traded to group members for 2 hours.
• ]]..C.."Warbound items"..R..[[ — can go to your own characters (Warband bank), not to other players.
• ]]..C.."Be wary of anyone who offers you a large amount of free gold in a trade."..R..[[ Nobody gives away a fortune for nothing. It is often a scam (they want something back, a "fee", a link or your login), or gold taken from hacked accounts or bought from gold sellers. Gold like that can be removed by Blizzard, and accounts that take part can be warned or banned. Say no, do not click any link they send, and report the player.
• ]]..C.."Never"..R..[[ trade gold or items to a stranger who "will pay later" or who needs "a test". Never accept an item that asks you to enter your password or click a link.

If something goes wrong, take a screenshot and report the player (right-click » Report).]] },

{ id = "learn-more", group = "1. Start Here", title = "Where to learn more, and how to spot an outdated guide", icon = "INV_Misc_Book_11",
  tags = "guide wowhead icy veins method wiki outdated patch season source youtube forum help",
  body = [[
Good places: ]]..C.."Wowhead"..R..[[ (database and guides), ]]..C.."Icy Veins"..R..[[ and ]]..C.."Method"..R..[[ (class and content guides), ]]..C.."Warcraft Wiki"..R..[[ (reference), and Blizzard's own news and forums for patch notes. Your guild and the Codex in this addon are good too.

How to tell a guide is old:
• It mentions currencies, mounts or systems from earlier expansions only as if they are the current ones.
• The patch or season in the title is not the current one.
• Item level numbers are far from what you see in the game.
• The page is a "boost" or "account" sale page in disguise. Many search results for game guides are shops. A shop page can contain correct information, but it exists to sell you something.

Rules of thumb:
• Check the date and the patch number first.
• Compare two sources. If they disagree, ask in game or check the in-game text.
• Class tips and numbers change more than basics like "stay out of the red".
• In the game, the tooltip is the final word.]] },
{ id = "choose-play", group = "1. Start Here", title = "How to choose what to play", icon = "ClassIcon_Paladin",
  tags = "choose class spec what to play first character main alt role fun enjoy best class trial",
  body = [[
The honest answer: ]]..C.."the best class is the one you want to keep playing."..R..[[ The strongest class on paper is a bad choice if it bores you. Every class can level, do delves, run dungeons and raid. The differences between them are small next to the difference between a player who enjoys the game and one who does not.

Choose in this order:

1. ]]..C.."How do you want to fight?"..R..[[ Close up or from a distance? With a pet or without? Quick and busy, or slow and simple?
2. ]]..C.."What role do you want?"..R..[[ Tank, healer or damage. Tanks and healers are asked for more often, so groups form faster for them.
3. ]]..C.."What do you want to do most?"..R..[[ Play alone, run dungeons with friends, raid, PvP, collect things. See "Choosing by what you want to do".
4. ]]..C.."What do you like to look at?"..R..[[ You will look at your character for hundreds of hours. Armor type, weapons and effects matter.
5. ]]..C.."Then check the lists."..R..[[ Tier lists are the last step, not the first (see the tier list pages).

Try before you commit: leveling to 10 on a few classes takes an hour each. You can change spec for free out of combat, so a class gives you 2 to 4 ways to play. Your Warband shares mounts, pets, toys and appearances, so a second character never starts from zero.

Some classes and allied races have their own requirements to create or unlock; the character creation screen shows what you need.]] },

{ id = "all-classes", group = "1. Start Here", title = "All 13 classes in one list", icon = "ClassIcon_Warrior",
  tags = "classes death knight demon hunter druid evoker hunter mage monk paladin priest rogue shaman warlock warrior armor roles specs pet resource",
  body = [[
]]..C.."Armor types"..R..[[ — cloth: mage, priest, warlock. Leather: demon hunter, druid, monk, rogue. Mail: evoker, hunter, shaman. Plate: death knight, paladin, warrior.

• ]]..C.."Death Knight"..R..[[ — plate, melee. Blood (tank), Frost, Unholy. Uses runes and runic power. Heals itself by fighting. Raises a dead ally in combat.
• ]]..C.."Demon Hunter"..R..[[ — leather, melee, very mobile. Havoc, Vengeance (tank) and Devourer (new in Midnight).
• ]]..C.."Druid"..R..[[ — leather, a bit of everything. Balance (ranged), Feral (melee), Guardian (tank), Restoration (healer). Shapeshifts; raises a dead ally in combat.
• ]]..C.."Evoker"..R..[[ — mail, mid-range. Devastation, Preservation (healer), Augmentation (boosts the allies). Flies without a mount.
• ]]..C.."Hunter"..R..[[ — mail, with a pet. Beast Mastery, Marksmanship (ranged), Survival (melee). Traps and kiting; the pet can tank. The pet gives the group a bloodlust-type boost.
• ]]..C.."Mage"..R..[[ — cloth, ranged. Arcane, Fire, Frost. Portals to cities, food for the group, a bloodlust (Time Warp).
• ]]..C.."Monk"..R..[[ — leather, quick on its feet. Brewmaster (tank), Mistweaver (healer), Windwalker (melee damage).
• ]]..C.."Paladin"..R..[[ — plate, can fill any role. Holy (healer), Protection (tank), Retribution (melee damage). Strong self-healing. Raises a dead ally in combat.
• ]]..C.."Priest"..R..[[ — cloth, ranged. Discipline and Holy (healers), Shadow (damage). Strong at shielding and healing.
• ]]..C.."Rogue"..R..[[ — leather, melee. Assassination, Outlaw, Subtlety. Stealth lets you choose your fights and skip groups of enemies.
• ]]..C.."Shaman"..R..[[ — mail, a mix of melee and ranged. Elemental (ranged), Enhancement (melee), Restoration (healer). Brings a bloodlust (Bloodlust or Heroism).
• ]]..C.."Warlock"..R..[[ — cloth, ranged, with a demon. Affliction, Demonology, Destruction. Soulstones and Healthstones for the group; can summon players to a dungeon.
• ]]..C.."Warrior"..R..[[ — plate, melee. Arms, Fury, Protection (tank). Simple resource (rage), lots of mobility.

]]..C.."Tanks"..R..[[: Blood, Vengeance, Guardian, Brewmaster, Protection Paladin, Protection Warrior.
]]..C.."Healers"..R..[[: Restoration Druid, Preservation, Mistweaver, Holy Paladin, Discipline, Holy Priest, Restoration Shaman.

|cff888888Check the character screen: it shows the current classes and specs.|r]] },

{ id = "easy-classes", group = "1. Start Here", title = "Easy to start, good for playing alone", icon = "Ability_Warrior_Charge",
  tags = "easy beginner solo class paladin hunter warlock death knight druid self heal pet tank blood guardian protection",
  body = [[
These picks are common advice from guide writers. They are opinions, not rules.

• ]]..C.."Paladin"..R..[[ — can be any role, takes hits well and heals itself. Downside: no ranged option.
• ]]..C.."Hunter"..R..[[ — the pet fights or even tanks for you, and traps and slows help you control a fight. Damage only.
• ]]..C.."Warlock"..R..[[ — a strong demon pet, healing tools and good utility for groups. Damage only.
• ]]..C.."Death Knight"..R..[[ — heals itself by fighting. Blood is regarded as a very safe tank.
• ]]..C.."Druid"..R..[[ — can fill every role and has good travel tools.
• ]]..C.."Safest tanks to learn on"..R..[[ — Blood Death Knight, Protection Paladin, Guardian Druid.

A ]]..C.."squishy class"..R..[[ (mage, priest) is fine in delves: your companion Valeera can take the tank or healer role while you do the damage.

Things that make a class harder: many buttons, a lot of positioning, or a lot of timing. If you are new, start with a class that has fewer buttons and add the harder one later.]] },

{ id = "choose-by-goal", group = "1. Start Here", title = "Choosing by what you want to do", icon = "INV_Misc_Map02",
  tags = "choose class playstyle delve dungeon raid pvp solo farming collecting transmog mount old raid travel utility",
  body = [[
• ]]..C.."Mostly alone (delves, world quests, collecting)"..R..[[ — self-healing classes and pet classes (see "Easy to start, good for playing alone").
• ]]..C.."Dungeons and Mythic+"..R..[[ — any class can; check the tier list for the current week if you want a top spot. Tanks and healers are asked for most.
• ]]..C.."Raiding"..R..[[ — pick the role your guild needs. Utility matters in a raid: a bloodlust, a battle resurrection or a big group buff.
• ]]..C.."PvP"..R..[[ — survival tools and crowd control matter as much as damage. Read a PvP list for the season (they differ from the PvE lists).
• ]]..C.."Farming old raids and rares for mounts and transmog"..R..[[ — mobility and self-healing help, since you will fight a lot.
• ]]..C.."Travel and quality of life"..R..[[ — druids (shapeshift), mages (portals), evokers (fly without a mount), rogues (stealth past enemies).
• ]]..C.."Gathering and crafting"..R..[[ — any class can learn any profession. Pick the profession first if gold is your goal.

You can always have more than one character. Many players keep a main for group content and an alt for solo play.]] },

{ id = "tier-lists", group = "1. Start Here", title = "Tier lists: what they are and how to read them", icon = "INV_Misc_Note_02",
  tags = "tier list s tier a tier meta ranking spec dps tank healer mythic plus raid data average max popularity outdated",
  body = [[
A ]]..C.."tier list"..R..[[ ranks specs from S (best) down to D. It tells you how well a spec does ]]..C.."right now"..R..[[. It does not tell you if a spec is fun, easy or good for you.

How to read one:

• ]]..C.."Check the date and the content."..R..[[ There are separate lists for Mythic+, raid, delves and PvP. A spec can be at the top for one and low for another.
• ]]..C.."Look at the data."..R..[[ Some lists are built from real player logs (damage or healing done); others are the writer's opinion. Opinion lists are fine for a first guess.
• ]]..C.."Tiers show distance, not an exact order."..R..[[ Specs in the same tier are close.
• ]]..C.."Top-player data is not your data."..R..[[ Many lists use only the best players. A spec that is hard to play looks great there and may not feel great for you.
• ]]..C.."Average or max?"..R..[[ Average shows typical results; max shows the best single result. Average is the better guide.
• ]]..C.."Early in a season the sample is small."..R..[[ Numbers shift as players learn and Blizzard changes balance.
• ]]..C.."Support specs look low."..R..[[ A spec that boosts its allies shows low damage on a damage list, but makes the group stronger.
• ]]..C.."S tier does not mean required. D tier does not mean unplayable."..R..[[ In most content a skilled player in any spec does fine.

The same season can give different lists on different dates and with different data, so do not treat one list as final.]] },

{ id = "tier-sources", group = "1. Start Here", title = "Where to find tier lists and class guides", icon = "INV_Misc_Book_11",
  tags = "tier list site icy veins method wowhead wow.gg archon raider.io warcraft logs class guide talent build import",
  body = [[
]]..C.."For tier lists and rankings"..R..[[
• ]]..C.."Icy Veins"..R..[[ — written tier lists for Mythic+ and raid, updated through the season.
• ]]..C.."wow.gg"..R..[[ — Mythic+ rankings built from the top players' logs.
• ]]..C.."Archon.gg"..R..[[ and ]]..C.."Warcraft Logs"..R..[[ — rankings and logs of raid and dungeon runs; players use them to compare themselves with others of their spec.
• ]]..C.."Raider.IO"..R..[[ — Mythic+ ratings and profiles.

]]..C.."For class and spec guides (rotation, talents, gear, stats)"..R..[[
• ]]..C.."Icy Veins"..R..[[, ]]..C.."Method"..R..[[ and ]]..C.."Wowhead"..R..[[ have guides for every spec. Most offer talent builds you can import (Talents window » Import).
• ]]..C.."Warcraft Wiki"..R..[[ — plain reference for abilities and mechanics.

Tips: use the guide of your ]]..C.."spec"..R..[[, not the class. Check that its patch and season match yours. Treat a build as a starting point and change it to fit how you play.]] },

{ id = "group-wants", group = "2. Dungeons, Raids & Delves", title = "What groups ask for (and what they don't)", icon = "INV_Misc_GroupNeedMore",
  tags = "group requirements rating item level bloodlust battle res spec role premade application listing what groups want",
  body = [[
When you apply to a Premade Group, the leader usually looks at:

• ]]..C.."Your role"..R..[[ — a tank or a healer is wanted first.
• ]]..C.."Your item level"..R..[[ and, for Mythic+, your ]]..C.."rating"..R..[[.
• ]]..C.."Utility"..R..[[ — a group often wants a bloodlust (shaman, mage, evoker or a hunter pet) and a battle resurrection (for example druid, death knight, paladin or warlock). Having one is nice; groups rarely refuse a good player over it.
• ]]..C.."Your attitude"..R..[[ — the note you write. "Learning, will listen" helps more than you think.

What groups usually do not need:
• A "top" spec. In keys below the highest levels, play what you enjoy. If a leader refuses a spec only because of the tier list, find another group.
• A perfect build. A reasonable build and clean play beats a copied one played badly.

If a group says "no X spec", do not argue. The Group Finder always has another group.]] },

{ id = "choose-race", group = "1. Start Here", title = "Choosing a race", icon = "Achievement_Character_Human_Male",
  tags = "race allied race void elf human orc racial ability faction horde alliance appearance cross faction",
  body = [[
• ]]..C.."Appearance first."..R..[[ Racial abilities are small bonuses. Do not pick a race for a few percent; pick the one you like to look at.
• ]]..C.."Faction"..R..[[ — Alliance or Horde decides your starting area and your capital city. In housing, Founder's Point is the Alliance-themed neighborhood and Razorwind Shores the Horde-themed one.
• ]]..C.."Class limits"..R..[[ — not every race can play every class. The character creation screen only shows the classes your race can use.
• ]]..C.."Allied races"..R..[[ — extra races that unlock through reputation or achievements; the character screen shows what you need.
• ]]..C.."Changing later"..R..[[ — a paid service changes race, faction or appearance later. A barber changes hair and face for free or a small price.

Cross-faction play exists in some systems (check the Group Finder and your guild options if you play with friends on the other faction).]] },

{ id = "first-evening", group = "1. Start Here", title = "Learning your spec: a first-evening plan", icon = "Ability_Marksmanship",
  tags = "learn spec rotation practice training dummy action bar keybind talents guide combat assist",
  body = [[
1. ]]..C.."Read the spec's description"..R..[[ in the talent window or character screen. It tells you the playstyle in two lines.
2. ]]..C.."Open a guide for your spec"..R..[[ (Icy Veins, Method or Wowhead) and read the first page: what the spec does, its buttons, its resource.
3. ]]..C.."Import a recommended build"..R..[[ and keep it for a week. (See the Talents page.)
4. ]]..C.."Set up your bars."..R..[[ Put your main buttons where your fingers rest: keys 1 to 5 and the ones next to them. Move less-used buttons to extra bars. Bind your interrupt and defensive to easy keys.
5. ]]..C.."Practice on a training dummy."..R..[[ Capital cities have target dummies. Pull a dummy and use your buttons until you do not need to look at the keyboard.
6. ]]..C.."Try a rotation helper if you want one."..R..[[ Blizzard has an optional helper called Assisted Highlight (search the Options for "assist"). It highlights the next suggested ability on your action bars. Turn it off when you know your buttons. See "Rotation helpers: what still works in Midnight".
7. ]]..C.."Do a few delves or normal dungeons"..R..[[ before you join a hard key. Say you are learning.
8. ]]..C.."Review one thing at a time."..R..[[ Today: interrupts. Tomorrow: defensives. After that: damage.

Do not compare your numbers with the top of a list. Compare them with yesterday's.]] },
{ id = "prof-choose", group = "5. Professions", title = "How to choose your professions", icon = "Trade_Engineering",
  tags = "choose profession first which profession pick two primary secondary gold gear fun gathering crafting unlearn alt",
  body = [[
You can have ]]..C.."two primary professions"..R..[[ and the secondary ones (Cooking, Fishing, Archaeology). Ask yourself:

1. ]]..C.."What do I want from it?"..R..[[
   • Gold — see "How to know which profession pays".
   • Gear and consumables for myself — a crafting profession (blacksmithing, leatherworking and tailoring make gear; alchemy, cooking and inscription make potions, flasks and food).
   • Fun and collecting — some professions give toys, pets, housing decor and cosmetic rewards; archaeology and fishing are calm.
2. ]]..C.."Do I like to run around or sit and craft?"..R..[[ Gatherers spend their time in the world. Crafters spend it in cities and at the Auction House.
3. ]]..C.."Can I afford the start?"..R..[[ Gathering costs nothing but time. Crafting needs materials, which you buy or gather.
4. ]]..C.."Can my other characters help?"..R..[[ Your alts can take the professions your main did not. With your Warband, you can supply each other.

Rules of thumb:
• A good start for a first character is one gathering and one crafting profession that go together (see the next page).
• Change your mind early. Before you drop a profession, read the warning in the profession window to see what you lose.
• Do not pick by a list alone. The best profession is the one you will actually use each week.]] },

{ id = "prof-pairs", group = "5. Professions", title = "Gathering or crafting? Good pairs", icon = "INV_Pick_02",
  tags = "gathering crafting pair mining herbalism skinning blacksmithing jewelcrafting engineering alchemy inscription leatherworking tailoring enchanting",
  body = [[
]]..C.."Gathering professions"..R..[[ collect materials from the world: Mining (ore and gems), Herbalism (herbs), Skinning (leather and hides). They need no recipes and sell well when a new expansion starts.

]]..C.."Crafting professions"..R..[[ turn materials into goods:
• Alchemy — potions, flasks, cauldrons (herbs).
• Blacksmithing — plate and mail armor, weapons (ore).
• Engineering — gadgets, tools, some gear (ore, other parts).
• Enchanting — improves gear; disenchants gear into materials.
• Inscription — glyphs, tomes, some gear items (herbs).
• Jewelcrafting — rings, necklaces and gems (ore, gems).
• Leatherworking — leather and mail armor (leather).
• Tailoring — cloth armor, bags and some utility (cloth from monsters).

]]..C.."Pairs that save work"..R..[[
• Mining + Blacksmithing, Jewelcrafting or Engineering.
• Herbalism + Alchemy or Inscription.
• Skinning + Leatherworking.
• Tailoring needs cloth, which drops from enemies; it pairs with any gathering.
• Enchanting pairs with any crafting profession that makes gear, since you can disenchant it.
• Two gathering professions (for example Herbalism + Mining) are a simple way to make gold without ever crafting.

Cooking and Fishing go well with any pair. You can level them alongside.

|cff888888Check each profession's trainer for what it makes now.|r]] },

{ id = "prof-pays", group = "5. Professions", title = "How to know which profession pays", icon = "INV_Misc_Coin_02",
  tags = "profession tier list gold best profession market competition concentration undermine exchange craftsim auctionator tsm price server",
  body = [[
A profession's earnings depend on ]]..C.."your realm's market"..R..[[, not on a general list. Use a list as a first guess and check your own Auction House.

Questions that decide it:
• ]]..C.."How early are we in the expansion?"..R..[[ Early on, gatherers do well: everyone needs materials and few are in stock. Later, as materials pile up, crafters of gear and consumables often earn more.
• ]]..C.."Are products quality-based?"..R..[[ If a product has quality tiers, a good crafter can sell a better version for more. If there are no tiers, many sellers compete and margins stay thin.
• ]]..C.."How many are selling it?"..R..[[ Many cheap listings mean competition.
• ]]..C.."What do raiders and key runners need this week?"..R..[[ Flasks, potions and food sell best before raid nights.
• ]]..C.."Can you make it at a profit?"..R..[[ Price of the item minus the price of materials, minus the 5% Auction House cut.

Tools that help:
• ]]..C.."Auctionator"..R..[[ or ]]..C.."TradeSkillMaster"..R..[[ — price tools; this addon reads prices from them and shows profit on tooltips.
• ]]..C.."CraftSim"..R..[[ — an addon that simulates a craft with your stats and tells you the profit.
• ]]..C.."The Undermine Exchange"..R..[[ — a website that tracks realm prices.

Two writers on the same site disagreed on which profession ranks first this season. That is why this guide gives no fixed ranking.]] },

{ id = "crafting-orders", group = "5. Professions", title = "Crafting orders, Concentration and timing", icon = "INV_Misc_Note_01",
  tags = "crafting orders concentration knowledge weekly patron personal public guild order commission quality timing",
  body = [[
• ]]..C.."Crafting orders"..R..[[ — a customer posts the item they want. You craft it and earn the commission. You can answer public orders, or orders sent to you personally or to your guild. Order profit depends on your realm, how many customers there are and how much they pay.
• ]]..C.."Concentration"..R..[[ — a resource that refills slowly with time. Spending it improves the quality of a craft. If you save it, you can use it at the busiest time.
• ]]..C.."Timing"..R..[[ — orders tend to be best before raid nights and Mythic+ runs. Saving Concentration for these busy periods can give you better margins.
• ]]..C.."Knowledge points"..R..[[ — earned from weekly quests, treatises, first-time crafts and treasures in the world. Spend them in the specialization tree of the profession.
• ]]..C.."Specialize"..R..[[ — pick one branch and put most points in it. Spreading points across everything makes you average at everything.

Weekly habit: open each profession, do its weekly quest, use any treatise, and craft the one-time recipes for knowledge. The Weekly Checklist of this addon shows what is left.]] },

{ id = "farm-worth", group = "6. Gold & Trading", title = "How to tell if a farming spot is worth it", icon = "INV_Misc_Coin_01",
  tags = "farm spot worth gold per hour drop rate price respawn competition test session worth grinding compare",
  body = [[
A farm is "good" if it gives more gold ]]..C.."per hour"..R..[[ than the other things you could do. Work it out:

]]..C.."Gold per hour = items per hour × price × 0.95 (the Auction House cut) − what you spent"..R..[[

How to get the numbers:
1. ]]..C.."Time it."..R..[[ Farm for 15 minutes and count what you looted. Multiply by four. The Farm Session window in this addon does this and shows the gold gained.
2. ]]..C.."Look up the price"..R..[[ of each item on the Auction House (scan with this addon) and use the price you can really sell at, not the highest listing.
3. ]]..C.."Include travel and reset time."..R..[[ A spot with a long run back is worth less.
4. ]]..C.."Compare"..R..[[ with the "Worth grinding" verdict, the "What To Farm Next" list and the Best Grinding Spots in this addon, and with a different activity such as a bountiful delve or world quests.

Things that change the result:
• ]]..C.."Competition"..R..[[ — if many players farm the same spot, spawns are gone and the price falls.
• ]]..C.."Selling too much"..R..[[ — if you put 200 of one item on the market, you lower its price. Sell some now and keep some for later.
• ]]..C.."Price swings"..R..[[ — prices change with patches, raid days and new seasons.
• ]]..C.."Drop rate"..R..[[ — a rare drop can pay well but make a bad hour.
• ]]..C.."Bag space"..R..[[ — a spot that fills your bags fast costs you a trip to sell.
• ]]..C.."Your own gear"..R..[[ — if you kill slowly, a spot with strong monsters is worse for you than for someone else.

Do not trust one spot or one number. Test it, write down the result, and compare.]] },

{ id = "gathering-midnight", group = "5. Professions", title = "Midnight gathering: finding nodes", icon = "INV_Misc_Herb_Felblossom",
  tags = "midnight gathering herbs ore nodes eversong harandar zul'aman voidstorm route farm overload",
  body = [[
• ]]..C.."Zones"..R..[[ — the four Midnight zones (Eversong Woods, Zul'Aman, Harandar, Voidstorm) all have herbs and ore. Zones differ in layout: open ground is easy, ledges and aggressive enemies slow you down.
• ]]..C.."Route"..R..[[ — follow the edge of a zone at a steady height so nodes on ledges are easier to spot, then cross the middle.
• ]]..C.."Special nodes"..R..[[ — Midnight adds special gathering nodes and materials; the gathering window and the profession's knowledge tree explain them.
• ]]..C.."Herbs sell well"..R..[[ because potions, flasks and food use them.
• ]]..C.."In this addon"..R..[[ — the Farm & Map page shows node spots from real node data for Midnight ores and herbs, with the best zone, node counts and glowing spots on the map. The Codex tab Gold Farming describes the best gathering zones.
• Use ]]..C.."Tracking"..R..[[ (the minimap button) to show herbs or ore as dots.]] },

{ id = "farm-compare", group = "6. Gold & Trading", title = "Other ways to farm: what to compare", icon = "INV_Misc_Coin_03",
  tags = "gold methods delves bountiful world quest old raid transmog mounts boe rare farm auction flipping crafting orders dailies compare",
  body = [[
Gold comes from many places. Compare them with the formula on the page "How to tell if a farming spot is worth it".

• ]]..C.."Gathering"..R..[[ — steady and easy; best early in an expansion.
• ]]..C.."Crafting"..R..[[ — needs a profession but is not tied to the world; best when you stay up to date with demand.
• ]]..C.."Bountiful delves"..R..[[ — loot and gear; the gear can be sold if it is Bind-on-Equip.
• ]]..C.."World quests and rares"..R..[[ — gold and items while you play normally.
• ]]..C.."Old raids and dungeons"..R..[[ — soloing legacy content for transmog, mounts and Bind-on-Equip drops. The Rares and Farm pages of this addon list them with prices.
• ]]..C.."Bind-on-Equip gear and recipes"..R..[[ — drops from raids and dungeons that you sell on the Auction House. The BoE Deals page shows current prices.
• ]]..C.."Monsters"..R..[[ — cloth, leather, meat and special items from creatures. The "Worth grinding" verdict compares creature types.
• ]]..C.."Auction House trading (flipping)"..R..[[ — buy cheap, sell dear. It needs patience and market knowledge. Losing gold is easy; start with small amounts.

If a method needs a lot of attention for little gold, drop it. If you enjoy a lower-paying method, that counts too.]] },

{ id = "prof-mistakes", group = "5. Professions", title = "Profession mistakes to avoid", icon = "INV_Misc_Wrench_01",
  tags = "profession mistakes leveling two at once vendor materials drop wrong profession tier list alt knowledge points",
  body = [[
• ]]..C.."Choosing only by a tier list."..R..[[ Lists change and ignore your realm and your taste.
• ]]..C.."Skipping the weekly knowledge tasks."..R..[[ They are the cheapest way to raise your skill level.
• ]]..C.."Crafting everything at once."..R..[[ Craft what your realm buys, not what is easy.
• ]]..C.."Selling materials too cheap."..R..[[ Check the price before you vendor or list. Cloth, leather and herbs are worth gold.
• ]]..C.."Learning too many branches in the specialization tree."..R..[[ Focus on one.
• ]]..C.."Forgetting your alts."..R..[[ Spare characters can hold the professions you did not pick.
• ]]..C.."Spending Concentration on low-profit crafts."..R..[[ Save it for items that sell.
• ]]..C.."Never checking the market."..R..[[ Open the Auction House once a day. Prices tell you what the server wants.]] },

{ id = "rotation-helpers", group = "1. Start Here", title = "Rotation helpers: what still works in Midnight", icon = "Ability_Marksmanship",
  tags = "rotation helper hekili ovale assisted highlight single button assistant next ability priority addon",
  body = [[
A ]]..C.."rotation"..R..[[ is the order in which you press your damage buttons. A ]]..C.."rotation helper"..R..[[ shows you the next button.

]]..C.."What changed in Midnight."..R..[[ Rotation helper addons used to read the fight (your buffs, the enemy's debuffs, your resources) to decide the next ability. Blizzard now hides much of that data from addons during combat, so helpers of that kind are reported to be no longer usable in play.

]]..C.."What works now"..R..[[
• ]]..C.."Assisted Highlight"..R..[[ — Blizzard's own, built into the default interface. It highlights the next suggested ability on your action bars. Switch it on in the Options (type "assist" in the search box).
• ]]..C.."Single-Button Assistant"..R..[[ — Blizzard's rotation assistant.
• Some addons are built on Blizzard's assistant and show its suggestions in another place or as a short queue. They use only what Blizzard's assistant tells them, so their list is a priority list, not a full plan. Check an addon's CurseForge page for "supports the current patch" before you install it.

]]..C.."Use them like a coach, not an autopilot"..R..[[
• A helper does not know the fight. It will not move you out of the red, hold a cooldown for the boss or save a big attack for the add.
• It is simplified. Experienced players beat it, because they know when to break the order.
• It helps you learn: use it for a week, then look at what it presses and why, then switch it off.]] },

{ id = "cooldown-manager", group = "1. Start Here", title = "Cooldown Manager and WeakAuras", icon = "INV_Misc_PocketWatch_01",
  tags = "cooldown manager weakauras buff tracker cooldown centered proc icons tracking essential utility",
  body = [[
]]..C.."WeakAuras"..R..[[ made icons and bars out of anything in a fight: procs, cooldowns, buffs. In Midnight most reactive combat triggers no longer work, because addons cannot read combat events the way they did. It still loads and works for things outside combat.

]]..C.."Blizzard's Cooldown Manager"..R..[[ is the built-in replacement. It shows your important cooldowns and buffs near the middle of your screen.
• Turn it on and set what it shows in the Options (type "cooldown" in the search box).
• Move it with Edit Mode (Esc » Edit Mode).
• Put the most important cooldowns where you can see them without looking away from the fight.

Some addons restyle or tidy the Cooldown Manager; they change how it looks and add no data.

Rule: addons can change how information looks, not what the player acts on.]] },

{ id = "must-addons", group = "1. Start Here", title = "Must-have addons: the short list and how to install them", icon = "INV_Misc_EngGizmos_17",
  tags = "must have addons essential best addons install curseforge wago addon manager details bigwigs dbm pawn auctionator bugsack plater leatrix update disable",
  body = [[
If you install only a few, take these: the most help for a new player for the least effort.

]]..C.."The five to install first"..R..[[
1. ]]..C.."BigWigs (with LittleWigs for dungeons) or DBM"..R..[[ — boss timers and alerts. Pick one, not both. Check that the page says it supports the current patch.
2. ]]..C.."Details"..R..[[ — a damage and healing meter.
3. ]]..C.."Pawn"..R..[[ — marks items in your bags that are upgrades for your spec.
4. ]]..C.."Auctionator"..R..[[ — prices in tooltips and a better Auction House window. This addon reads its prices.
5. ]]..C.."BugSack and BugGrabber"..R..[[ — catch addon errors quietly, so a broken addon does not spam your screen, and show which addon is the cause.

]]..C.."Then, by what you do"..R..[[
• Mythic+ player: Angry Keystones (timers) and a nameplate addon such as Plater.
• Collector or explorer: HandyNotes, RareScanner, AllTheThings.
• Crafter or gold maker: CraftSim and Auctionator.
• Comfort: Leatrix Plus (auto-repair, auto-sell junk, tidy minimap).
• Farming, rares, decor, delves and auction tools: Seviath's Useful Tools.

]]..C.."How to install and keep them safe"..R..[[
1. Use the CurseForge or Wago app, or download from CurseForge, Wago or WoWInterface. Do not take addons from links in chat or from video descriptions you do not trust.
2. The addon goes into the folder Interface\AddOns inside the game's retail folder (the apps do this for you).
3. Start the game. At the character screen click AddOns to see them and switch them on or off.
4. If an addon causes errors or lag, switch it off and test again. Disable them one at a time.
5. After each game patch, update the addons. If one says it is out of date, check its page for a new version before you force it on.

Rules of thumb: fewer is better (every addon uses memory and can cause errors); never enter your password in an addon; an addon that promises to "play for you" is against the rules (see "What not to use").]] },

{ id = "more-addons", group = "1. Start Here", title = "More addons worth having", icon = "INV_Misc_Book_09",
  tags = "addons recommended details plater platynator threat plates pawn leatrix angry keystones bigwigs dbm handynotes rarescanner auctionator craftsim bugsack alltheThings narcissus",
  body = [[
Install only from CurseForge, Wago or WoWInterface. Fewer is better.

]]..C.."Fights and groups"..R..[[
• BigWigs / LittleWigs or DBM — boss timers and alerts.
• Details — a damage and healing meter. It shows less during a fight than before, but it still works for checking your numbers afterwards.
• Plater, Platynator or Threat Plates — nameplates you can customise (size, debuffs, colour).
• Angry Keystones — Mythic+ timers.

]]..C.."Gear and quality of life"..R..[[
• Pawn — shows if an item is an upgrade, using stat weights for your spec.
• Leatrix Plus — many small comforts: auto-repair, auto-sell junk, tidy minimap buttons.
• Better Blizzard Frames, Account Wide Interface Settings, Dialogue UI, Narcissus, Plumber, Titan Panel — interface comfort and information bars.

]]..C.."Finding things"..R..[[
• HandyNotes — marks treasures and collectibles on the map.
• RareScanner — alerts you when a rare appears.
• AllTheThings — tracks mounts, transmog, achievements.
• Seviath's Useful Tools — the farm spots, rares, decor, delve planner and auction tools in this book.

]]..C.."Gold"..R..[[
• Auctionator — prices in tooltips and a better Auction House window.
• CraftSim — shows the profit of a craft.

]]..C.."Errors"..R..[[
• BugSack and BugGrabber — catch addon errors quietly and keep a log.

Tip: when you update the game, update your addons too; turn off any that say they are not made for the current patch.]] },

{ id = "max-damage", group = "1. Start Here", title = "Getting the most damage: ten habits", icon = "Ability_Warrior_Rampage",
  tags = "max dps maximize damage tips habits uptime cooldowns movement priority target aoe single target interrupts death downtime opener",
  body = [[
Most of the difference between a good and a great player is these ten things, not a secret button.

1. ]]..C.."Keep pressing buttons."..R..[[ Every second you do nothing is damage lost. Stay in range, face the target and keep your global cooldown busy.
2. ]]..C.."Know your opener and your big cooldowns."..R..[[ Press your strongest abilities every time they come back, unless the boss is about to die or leave. Do not sit on them "for later".
3. ]]..C.."Line up cooldowns."..R..[[ Use them together with your group's bloodlust and with raid buffs.
4. ]]..C.."Do not die."..R..[[ A dead player does no damage. Use your defensives early, stand out of the red, and heal with potions and healthstones.
5. ]]..C.."Plan your movement."..R..[[ Stay near the target and move only when you must. Use instant abilities while you move.
6. ]]..C.."Use the right target priority."..R..[[ Kill the marked target first; kill adds that hurt the group; switch to the boss when it is open.
7. ]]..C.."Single target and many targets are different."..R..[[ Use your area abilities when three or more enemies are close, your single-target ones for a boss.
8. ]]..C.."Keep your damage-over-time effects up."..R..[[ If you have them, refresh them before they end.
9. ]]..C.."Interrupt."..R..[[ A kick on a dangerous cast is worth more than a few seconds of damage.
10. ]]..C.."Prepare."..R..[[ Food, flask, potion, talents for the content (a raid build and a dungeon build are different) and a correct action bar.

Order of importance: do not die, do not stand idle, press the right buttons, use cooldowns well. Fine-tuning comes after that.]] },

{ id = "damage-gear", group = "1. Start Here", title = "Gear, gems, enchants and consumables for damage", icon = "INV_Misc_Gem_01",
  tags = "gear gems enchants consumables stat priority trinkets embellishments hero talents build pawn raidbots droptimizer bis best in slot",
  body = [[
After habits, gear is the next gain.

• ]]..C.."Item level first."..R..[[ A higher item level beats a better stat on a lower piece. See the gear tracks page.
• ]]..C.."Stat priority."..R..[[ Each spec has a preferred order of Critical Strike, Haste, Mastery and Versatility. Spec guides list it, and Pawn can use it to mark upgrades in your bags.
• ]]..C.."Gems and enchants."..R..[[ Put a gem in every socket and an enchant on every slot that takes one. Spec guides have a page with the current best choices.
• ]]..C.."Consumables."..R..[[ Food, a flask, a potion and (for raids) runes or weapon oils. See "Food, flasks and potions".
• ]]..C.."Talents and hero talents."..R..[[ Pick the build made for the content. Dungeon builds favour many enemies; raid builds favour a single boss.
• ]]..C.."Trinkets and other special pieces."..R..[[ Some give a big boost to damage. Read their text, and read the spec guide's list of best trinkets.
• ]]..C.."Upgrade where it counts."..R..[[ Spend crests on the pieces you will keep.

|cff888888Exact stat priorities and best gems and enchants change by patch; use the current spec guides.|r]] },

{ id = "check-yourself", group = "1. Start Here", title = "Checking yourself: logs, meters and simulations", icon = "INV_Misc_Spyglass_03",
  tags = "warcraft logs wowanalyzer details meter parse simulation simulationcraft raidbots compare dps check improve review",
  body = [[
Numbers show you what to fix.

• ]]..C.."Details (meter)"..R..[[ — look at your damage, the abilities you used and how much time you spent not casting. Compare yourself with players of the same spec and item level, not with the top of the list.
• ]]..C.."Warcraft Logs"..R..[[ — players upload their raids and dungeons here. You can see damage per ability and rankings against other players of your spec.
• ]]..C.."WoWAnalyzer"..R..[[ — a site that reads a log and tells you in plain words where you lost damage (idle time, late cooldowns).
• ]]..C.."SimulationCraft and Raidbots"..R..[[ — programs and a website that simulate your character and tell you which items or talents give the most damage. Useful for choosing between two pieces of gear.
• ]]..C.."Training dummy"..R..[[ — a cheap test: five minutes on a dummy, then change one thing and repeat.

How to read a result:
• Compare average, not best.
• One bad fight tells you little; look at three.
• The goal is to improve, not to match a number.
• Dungeons and raids with many enemies or movement lower damage for everyone. Compare the same fight.]] },

{ id = "no-bots", group = "1. Start Here", title = "What not to use: tools that break the rules", icon = "INV_Misc_Key_03",
  tags = "bot automation macro one button rotation ban terms of service cheat third party program keystroke",
  body = [[
• ]]..C.."Programs that play for you."..R..[[ Software outside the game that presses keys, moves your character or runs a rotation for you is against the rules and gets accounts banned. This includes "one-button" tools and bots.
• ]]..C.."Macros are limited."..R..[[ The game's own macros cannot press many abilities with one click in a loop on purpose. Do not search for tricks around that.
• ]]..C.."Allowed:"..R..[[ Blizzard's own Assisted Highlight and Single-Button Assistant, and addons that restyle the interface or show information the game gives them.
• ]]..C.."Where to look if unsure:"..R..[[ the addon's CurseForge page and the Blizzard support site.
• ]]..C.."Buying coaching or carry services"..R..[[ from strangers is a common route to scams (see the account safety page).

If an addon asks for your password or tells you to run a program outside the game, remove it.]] },
}

-- Register the articles as Codex entries
function ns:LoadGuide()
    for i, a in ipairs(self.GUIDE) do
        self:Add({
            cat = "guide", id = a.id, name = a.title, group = a.group,
            icon = "Interface\\Icons\\" .. (a.icon or "INV_Misc_Book_09"),
            sub = a.tags, tags = a.tags, body = a.body, order = i,
        })
    end
end
