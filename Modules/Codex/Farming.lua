-- Seviath's Codex — Farming: the best places to make gold
-- Gold farming for WoW Forever (Classic): gathering routes, skinning, cloth, dungeons, raids and the auction house, in our own words.
-- No reliable gold-per-hour numbers exist — prices differ per realm — so
-- each spot shows LIVE auction prices when Auctionator is installed.

local ADDON, ns = SFP_Module("Codex")
local C = ns.CYAN

local Z = { UNGORO = 1449, WINTERSPRING = 1452, EPL = 1423, WPL = 1422, SILITHUS = 1451, AZSHARA = 1447, FELWOOD = 1448, BADLANDS = 1418 }

ns.FARMS = {
------------------------------------------------------------------------
{ group = "1. Herbs & Ore", name = "Un'Goro Crater (Thorium, Dreamfoil, Golden Sansam)", zone = "Un'Goro Crater", zid = Z.UNGORO,
  tier = "High · steady at 55-60", mats = { "Thorium Ore", "Dreamfoil", "Golden Sansam", "Mountain Silversage" },
  body = "The best all-round gathering zone of Classic: a closed crater with a ring road and many nodes, few elites. Run one loop along the crater wall and the middle valley.\n\nThorium and Dreamfoil sell steadily for Engineering, Alchemy and flasks. The best nodes need Mining 250+ and Herbalism 285+." },
{ group = "1. Herbs & Ore", name = "Winterspring (Mountain Silversage, Black Lotus, Thorium)", zone = "Winterspring", zid = Z.WINTERSPRING,
  tier = "High · cold and long", mats = { "Mountain Silversage", "Black Lotus", "Thorium Ore", "Icecap" },
  body = "Long open valleys with Icecap and Mountain Silversage, thorium veins along the hills, and a chance at Black Lotus (very valuable: flasks need it). Frostsabers and yetis make skinning here worth it too.\n\nTip: Black Lotus spawns are rare; check the known spawn points while you loop." },
{ group = "1. Herbs & Ore", name = "Eastern Plaguelands (Plaguebloom, Thorium, Black Lotus)", zone = "Eastern Plaguelands", zid = Z.EPL,
  tier = "High · dangerous mobs", mats = { "Plaguebloom", "Thorium Ore", "Black Lotus", "Dreamfoil" },
  body = "Full of high-level undead, so best at level 60 with a mount. Plaguebloom is common here, thorium is in the south and east, and Black Lotus can appear. Run the roads and pick the nodes on the way." },
{ group = "1. Herbs & Ore", name = "Silithus (Thorium, Black Lotus)", zone = "Silithus", zid = Z.SILITHUS,
  tier = "Medium · long trips", mats = { "Thorium Ore", "Black Lotus", "Dreamfoil" },
  body = "Thorium veins in the hills and Black Lotus now and then. A lot of elite silithid; keep to the edges and watch for patrols." },
{ group = "1. Herbs & Ore", name = "Azshara (Mountain Silversage, Gromsblood, Mithril)", zone = "Azshara", zid = Z.AZSHARA,
  tier = "Medium · quiet", mats = { "Mountain Silversage", "Gromsblood", "Mithril Ore", "Truesilver Ore" },
  body = "A big quiet zone with low traffic: Mountain Silversage and Gromsblood in the south and along the coast, mithril and truesilver in the hills. A relaxed route for levels 45-55." },
{ group = "1. Herbs & Ore", name = "Felwood (Sungrass, Gromsblood, Dreamfoil)", zone = "Felwood", zid = Z.FELWOOD,
  tier = "Medium · herb loop", mats = { "Sungrass", "Gromsblood", "Dreamfoil", "Plaguebloom" },
  body = "Dense herbs along the valleys, easy to pass between Jaedenar and Emerald Sanctuary. The Songflower buffs here are great before a raid or a run." },
{ group = "1. Herbs & Ore", name = "Badlands (Iron, Mithril, Truesilver)", zone = "Badlands", zid = Z.BADLANDS,
  tier = "Leveling · mining", mats = { "Iron Ore", "Mithril Ore", "Truesilver Ore", "Gold Ore" },
  body = "The classic place to raise Mining from 125 to 230: rich nodes in the open valleys. Mithril and truesilver sell for Engineering and Blacksmithing." },

------------------------------------------------------------------------
{ group = "2. Skinning & Cloth", name = "Un'Goro (Devilsaur Leather, Scorpid Scales)", zone = "Un'Goro Crater", zid = Z.UNGORO,
  tier = "High value · Leatherworking", mats = { "Devilsaur Leather", "Scorpid Scale", "Thick Leather" },
  body = "Devilsaurs (level 55) drop the sought-after Devilsaur Leather but hit hard; kill them with a mount or from range. Scorpids and raptors give scales and Thick Leather for Leatherworking." },
{ group = "2. Skinning & Cloth", name = "Winterspring (Frostsaber Leather)", zone = "Winterspring", zid = Z.WINTERSPRING,
  tier = "High value · quiet", mats = { "Frostsaber Leather", "Rugged Leather" },
  body = "Frostsabers and yeti pull easily and drop Rugged Leather and Frostsaber Leather for cold-weather gear. Skin them as you gather." },
{ group = "2. Skinning & Cloth", name = "Runecloth in the Plaguelands", zone = "Western Plaguelands", zid = Z.WPL,
  tier = "Steady · all classes", mats = { "Runecloth", "Mageweave Cloth", "Silk Cloth" },
  body = "Humanoid undead and furbolgs drop cloth. Runecloth is needed for turn-ins to your faction and for bandages, so it sells well. Pull in groups with AoE and loot as you go." },

------------------------------------------------------------------------
{ group = "3. Dungeons & BoE gear", name = "How gold works in Classic", tier = "Read first",
  body = "• Gold comes from vendor trash, cloth, herbs, ore, leather, and green or blue BoE items sold on the auction house.\n• World drops from level 50+ monsters are the main source of BoE blues; kill many in one area and loot each.\n• The auction houses of the big cities pay best; use Auctionator or the addon's scan to learn real prices.\n• Raid consumables (flasks, fire protection potions, Mongoose) sell very well in the weeks before a raid." },
{ group = "3. Dungeons & BoE gear", name = "Zul'Farrak", inst = "Zul'Farrak",
  tier = "Groups · BoEs + cloth", body = "A fast group run with BoE blues from the trash, plus Mageweave and Silk cloth on the stairs." },
{ group = "3. Dungeons & BoE gear", name = "Maraudon", inst = "Maraudon",
  tier = "Herbs + cloth + BoE", body = "Many mobs close together, rich herbs and cloth. Princess Theradras drops the first epic items for many players." },
{ group = "3. Dungeons & BoE gear", name = "Uldaman", inst = "Uldaman",
  tier = "Levels 38-50", body = "Short runs with good vendor trash and BoE greens." },
{ group = "3. Dungeons & BoE gear", name = "Blackrock Depths", inst = "Blackrock Depths",
  tier = "Big runs · BoEs", body = "Large pulls, Dark Iron ore and rare BoE items. A long run but a rewarding clear." },
{ group = "3. Dungeons & BoE gear", name = "Lower Blackrock Spire", inst = "Lower Blackrock Spire",
  tier = "Fast resets · epics", body = "Short and quick to clear; Rend Blackhand and Gyth drop epic items." },
{ group = "3. Dungeons & BoE gear", name = "Scholomance", inst = "Scholomance",
  tier = "Level 60 dungeon", body = "Big cloth and leather packs for Runecloth, plus epic drops. Good gold per run once you can clear it quickly." },

------------------------------------------------------------------------
{ group = "4. Raids & gold", name = "Molten Core, Onyxia, Blackwing Lair", tier = "Weekly · lockouts",
  body = "At 60 these raids give most of your gold: bosses drop Lava Core, Fiery Core, set tokens and enchanting materials, and the trash drops consumables. Sell what you do not need." },
{ group = "4. Raids & gold", name = "Zul'Gurub, Ruins and Temple of Ahn'Qiraj", tier = "Weekly · profit",
  body = "Zul'Gurub (20 players) drops Bijous and coins for rewards and a lot of vendor gold. The Ahn'Qiraj raids drop Qiraji gear, Elementium Ore and rare crafting reagents." },
{ group = "4. Raids & gold", name = "Naxxramas", tier = "Weekly · endgame",
  body = "The last raid of Classic. Plan for the dungeon-set tokens and the gold from the trash." },

------------------------------------------------------------------------
{ group = "5. Crafting & the auction house", name = "Professions that make money", tier = "Steady",
  body = "• Alchemy: flasks and potions (Major Healing, Mongoose, Greater Arcane) for raiders.\n• Enchanting: scrolls and enchants for Strength, Agility and Spell Power; rods for leveling.\n• Tailoring: bags (Mooncloth, Runecloth) and bandages; the Mooncloth cooldown is a daily gain.\n• Engineering: Goblin Sappers and mining gear.\n• Cooking: raid buffs such as Smoked Desert Dumplings." },
{ group = "5. Crafting & the auction house", name = "Buying and selling", tier = "Best gold per time",
  body = "• Buy herbs and ore in the evening when sellers flood the market, sell on weekdays before raids.\n• Undercut by a copper and relist once or twice a day.\n• The addon's Recipe planner shows what to craft for profit once you scanned the auction house." },
}

-- live price from Auctionator, if installed (copper -> text)
function ns:LivePrice(itemName)
    local S = _G.SeviathsUsefulTools
    local copper
    -- the main addon knows every source: its own scan, Auctionator, TradeSkillMaster
    local id = itemName and C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(itemName)
    if id and S and S.GetPrice then copper = S:GetPrice(id) end
    if not (copper and copper > 0) then
        local api = Auctionator and Auctionator.API and Auctionator.API.v1
        if api and api.GetAuctionPriceByItemName then
            local ok, c = pcall(api.GetAuctionPriceByItemName, "SeviathsCodex", itemName)
            if ok and c and c > 0 then copper = c end
        end
    end
    if copper and copper > 0 then
        return GetCoinTextureString and GetCoinTextureString(copper) or (math.floor(copper / 10000) .. "g")
    end
end

function ns:FarmText(e)
    local f = e.farm
    local out = {}
    if f.tier then out[#out + 1] = C .. "Rating|r\n" .. f.tier end
    if f.zid then
        local where = ns:MapName(f.zid)
        if where == "?" then where = f.zone or "?" end
        if f.x then where = where .. ("  %.1f, %.1f"):format(f.x * 100, f.y * 100) end
        local cont = ns.ContinentOf and select(2, ns.ContinentOf(f.zid))
        out[#out + 1] = C .. "Where|r\n" .. where .. (cont and (" » " .. cont) or "")
    end
    out[#out + 1] = C .. "How|r\n" .. (f.body or "")
    if f.mats then
        local lines, anyPrice = {}, false
        for _, m in ipairs(f.mats) do
            local p = ns:LivePrice(m)
            if p then anyPrice = true end
            lines[#lines + 1] = "• " .. m .. (p and ("   " .. p) or "")
        end
        out[#out + 1] = C .. "What you get|r\n" .. table.concat(lines, "\n")
        out[#out + 1] = anyPrice and "|cff888888Prices: your own scan, else Auctionator or TradeSkillMaster.|r"
            or "|cff888888Gold per hour depends on your realm's prices. Scan the auction house once (or use Auctionator / TradeSkillMaster) and prices appear here.|r"
    end
    if f.inst then
        local inst = ns:FindByName("dungeon", f.inst) or ns:FindByName("raid", f.inst)
        if inst and inst.map then
            out[#out + 1] = C .. "Entrance|r\n" .. ns:Coords(inst.map) .. "\n|cff888888Full route and boss mechanics: Related below.|r"
        end
    end
    return table.concat(out, "\n\n")
end

function ns:LoadFarms()
    for i, f in ipairs(self.FARMS) do
        local e = self:Add({
            cat = "mats", id = "farm" .. i, name = f.name, group = f.group,
            icon = "Interface\\Icons\\" .. (f.mats and "INV_Misc_Herb_Felblossom" or (f.inst and "INV_Misc_Key_14") or "INV_Misc_Coin_01"),
            sub = (f.tier or "") .. " " .. table.concat(f.mats or {}, " "), farm = f, order = i,
            map = (f.zid and f.x) and { m = f.zid, x = f.x, y = f.y } or nil,
            openMap = f.zid, tags = "farm gold " .. (f.zone or ""),
        })
        if e and f.inst then
            local inst = self:FindByName("dungeon", f.inst) or self:FindByName("raid", f.inst)
            if inst then
                self:Link(e, inst)
                if inst.map then e.map = inst.map end
            end
        end
    end
end
