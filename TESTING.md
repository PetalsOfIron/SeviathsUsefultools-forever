# SeviathsUsefulTools (retail) - tester guide

Everything in this build was written without running it in the game, so you are the first to try it. Thank you!

## 1. Install
1. Close WoW. Copy the `SeviathsUsefulTools` folder into `World of Warcraft\_retail_\Interface\AddOns\`.
2. In the AddOns list (character select) **disable** SeviathsFarmPack, SeviathsCodex, SeviathsDungeonsRaids and
   SeviathsGuildHelper if you have them. Their features are inside this addon now.
3. Turn on Lua errors so bugs show up: type `/console scriptErrors 1` in chat, then `/reload`.
   (Optional but better: install BugSack + BugGrabber, they keep a list of errors.)
4. Optional: Auctionator or TradeSkillMaster. The addon uses their prices when the auction house was not scanned.

## 2. Open it
- `/sfp` opens the main menu. `/sfp help` lists every command.
- Also: the minimap button (`/sfp minimap` shows or hides it) or the addon compartment button.
- Menu pages: layers on the map, the farm browser, guides, options.

## 3. What to try (tick them off)
**World map** (open a zone map, for example Eversong Woods, Harandar, Isle of Dorn)
- Glowing spots: cyan = monster farm spots, orange = rares, green = hunter tames, mining and herb symbols.
- Hover a spot: tooltip with what drops there and the price. Ctrl+Click on the map makes a waypoint.
- **Farm spots list** on the left side of the map: one checkbox per spot. Untick one and it must disappear from the map
  AND the minimap. Test "Show all" / "Hide all", the mouse wheel when the list is long, clicking a name (waypoint) and the [-]/[+] fold button.
- **Gathering list** at the bottom right: ores and herbs of the zone and their best zone.
- The layer button on the map switches each layer on or off. Commands: `/sfp map`, `spawns`, `rares`, `hunter`, `gather`, `dungeons`.

**Minimap**
- Farm spots near you should show on the minimap and move when you move. Also try zooming the minimap and
  turning on "Rotate Minimap" in the game options. They should still line up with the map.

**Monster tooltips**
- Hover monsters: you should see `Seviaths NPC <id>`, kills seen, what it drops and a **Worth grinding** line.
- Hover friendly NPCs (guards, vendors): there must be NO drop lines.
- Kill and loot a few: "kills seen" and the drop list grow. `/sfp know` shows everything it has learned.

**Item tooltips** (bags, auction house, chat links, quest rewards)
- A "Seviaths" block: where to get it (zones), how to use it, and the price.
- Hover a **world quest reward** on the map: this used to throw an error, it must not any more.

**Auction house prices**
- Open the auction house. Chat shows scan progress ("Full scan ..."). `/sfp scan` forces a rescan.
- Prices are saved per realm and shared between your characters: log another character and check an item price.
- With Auctionator or TSM installed: items you never scanned still get a price.

**Money and crafting**
- `/sfp craft` lists the most profitable recipes you know. Crafted items show cost against sell price.
- `/sfp sold` and `/sfp income` switch the yellow chat messages (auction sold, mail gold, vendor sales).

**Dungeons and raids**
- Raid and dungeon entrance icons on the map: hover for the loot (mounts, BoE gear, recipes). `/sfp loot` rereads the Adventure Guide.
- `/sfp browser` (or `/sfp farm`) is the farm browser by expansion.

**Modules**
- `/codex` encyclopedia (search it, try the Delves category), `/sdr` Dungeons and Raids group tools, `/gi` Guild Helper.

## 4. Reporting a problem
Please send:
1. What you did, where (zone) and what you expected.
2. The error text: the red Lua error window, BugSack, or `/sfp errors` in chat. A screenshot is fine.
3. A screenshot of the map or tooltip if it looks wrong.
4. Your other map addons (HandyNotes, Questie, RareScanner ...) in case they clash.

Quick switches while testing: `/sfp tipdebug` (explains why a monster tooltip is missing), `/sfp learn` (learning on/off),
`/sfp comparelevel` (compare monsters at your level or all levels).

## 5. Known limits
- Spawn points, drops and IDs come from Wowhead. Drop chances for rares are not published, so they are not shown.
- Some Midnight rares and monsters were added from guides; a wrong spot or name is worth reporting.
- Open-world BoE gear, Aberrus BoE gear and some world recipe drops are not in yet (no reliable source).
- Retail only. The Mists of Pandaria edition is a separate addon.
