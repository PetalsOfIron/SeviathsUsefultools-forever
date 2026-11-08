-- Seviath's Codex — Farming: the best places to make gold
-- Summarised in our own words from community gold guides (Midnight, 2026):
-- wow-professions.com (herbalism/mining routes), wowvendor.com (Aug 2026,
-- skinning / cloth / BoE spots), playnews.gg and nexttier.pro (old content).
-- No reliable gold-per-hour numbers exist — prices differ per realm — so
-- each spot shows LIVE auction prices when Auctionator is installed.

local ADDON, ns = SFP_Module("Codex")
local C = ns.CYAN

local Z = { EVERSONG = 2395, ZULAMAN = 2437, HARANDAR = 2413, VOIDSTORM = 2405 }

ns.FARMS = {
------------------------------------------------------------------------
{ group = "1. Midnight — Herbs & Ore", name = "Eversong Woods (easiest gathering)", zone = "Eversong Woods", zid = Z.EVERSONG,
  tier = "Easy · steady", mats = { "Argentleaf", "Tranquility Bloom", "Sanguithorn", "Azeroot", "Mana Lily", "Refulgent Copper Ore", "Dazzling Thorium" },
  body = "The best place to start gathering: open terrain, few mobs and an easy loop around the whole zone with short trips through the middle. Herbs and ore here; Lightfused nodes (Mote of Light) are mostly in this zone.\n\nHow: fly one big loop, don't backtrack, take every node you pass. Works for herbalism, mining or both." },
{ group = "1. Midnight — Herbs & Ore", name = "Zul'Aman (dual gathering, extra mats from mobs)", zone = "Zul'Aman", zid = Z.ZULAMAN,
  tier = "Medium · higher yield with gear", mats = { "Argentleaf", "Nocturnal Lotus", "Refulgent Copper Ore", "Dazzling Thorium" },
  body = "Best for herbalism + mining together. Wild nodes summon mobs when gathered (herbs and ore) — kill them for extra materials, or pull them away from the node so nobody steals it.\n\nNeeds decent gear. High Deftness lets you gather without getting stuck in fights. Not good for pure leveling of gathering." },
{ group = "1. Midnight — Herbs & Ore", name = "Harandar (dense nodes, annoying terrain)", zone = "Harandar", zid = Z.HARANDAR,
  tier = "Medium · dense but slow", mats = { "Argentleaf", "Tranquility Bloom", "Refulgent Copper Ore" },
  body = "Very dense nodes, but many mobs and lots of up-and-down flying; herbs grow on mushrooms and roots. Mining alone is easier (ore is mostly on the ground).\n\nPrimal nodes are here: overloading one channels 50% of your health for extra motes — stay above 50% and don't interrupt it." },
{ group = "1. Midnight — Herbs & Ore", name = "Voidstorm (dense, fly the edges)", zone = "Voidstorm", zid = Z.VOIDSTORM,
  tier = "Medium · dense", mats = { "Nocturnal Lotus", "Dazzling Thorium" },
  body = "Lots of nodes but a hard layout. Fly along the edge of the map and through the middle where there are fewer mobs. Voidbound nodes live here: gather them while mounted and fly straight up to escape the slowing circle." },
{ group = "1. Midnight — Herbs & Ore", name = "Gathering setup (more gold per node)",
  tier = "Tips", body = "• Tool stats: Finesse = more materials per node (best for gold), Deftness = faster gathering (needed in mob-heavy zones), Perception = rare finds (only worth it if Nocturnal Lotus / Dazzling Thorium sell high on your realm).\n• Buffs: Azeroot Tea (+Deftness) and Darkmoon Firewater (+15% Deftness).\n• Overload: 12-hour cooldown, 30 minutes shorter per Midnight node you gather.\n• Sell early in the week and before raid resets; prices drop as more players gather." },

------------------------------------------------------------------------
{ group = "2. Midnight — Skinning", name = "Renowned Beast circuit (Majestic materials)", tier = "High value · needs skinning spec",
  mats = { "Majestic Hide", "Majestic Claw", "Majestic Fin" },
  body = "Five special beasts drop Majestic Hide / Claw / Fin, which sell for much more than normal leather. Fly the circuit and skin each one.\n\nNeeds: Skinning specialization — take Talented Tracker, then Majestic Materials.\nTip: a rare-tracking addon helps you see when they're up. Each beast below has Show on map." },
{ group = "2. Midnight — Skinning", name = "Gloomclaw", zid = Z.EVERSONG, x = 0.4195, y = 0.7970, tier = "Renowned beast", mats = { "Majestic Hide", "Majestic Claw" },
  body = "Renowned beast in Eversong Woods — part of the skinning circuit." },
{ group = "2. Midnight — Skinning", name = "Silverscale", zid = Z.ZULAMAN, x = 0.4755, y = 0.5365, tier = "Renowned beast", mats = { "Majestic Hide", "Majestic Fin" },
  body = "Renowned beast in Zul'Aman — part of the skinning circuit." },
{ group = "2. Midnight — Skinning", name = "Lumenfin", zid = Z.HARANDAR, x = 0.6663, y = 0.4783, tier = "Renowned beast", mats = { "Majestic Fin" },
  body = "Renowned beast in Harandar — part of the skinning circuit." },
{ group = "2. Midnight — Skinning", name = "Umbrafang", zid = Z.VOIDSTORM, x = 0.5415, y = 0.6527, tier = "Renowned beast", mats = { "Majestic Hide", "Majestic Claw" },
  body = "Renowned beast in Voidstorm — part of the skinning circuit." },
{ group = "2. Midnight — Skinning", name = "Netherscythe", zid = Z.VOIDSTORM, x = 0.4313, y = 0.8281, tier = "Renowned beast", mats = { "Majestic Claw" },
  body = "Renowned beast in Voidstorm — part of the skinning circuit." },

------------------------------------------------------------------------
{ group = "3. Midnight — Cloth & BoE gear", name = "Shadowguard Point delve (best solo cloth)", zid = Z.VOIDSTORM, x = 0.3738, y = 0.4774,
  tier = "High · solo", body = "The best solo cloth farm reported for Midnight. Run it, reset it, run it again — every reset gives fresh humanoids that drop cloth (and sometimes BoE gear)." },
{ group = "3. Midnight — Cloth & BoE gear", name = "The Grudge Pit delve (easier cloth)", zid = Z.HARANDAR, x = 0.7030, y = 0.6714,
  tier = "Medium · easy", body = "An easier solo cloth delve. Same idea: clear, reset, repeat." },
{ group = "3. Midnight — Cloth & BoE gear", name = "Broken Throne, south-west Zul'Aman (group cloth)", zid = Z.ZULAMAN,
  tier = "High · with a group", body = "Big humanoid packs in the south-west of Zul'Aman — best farmed with friends for cloth." },
{ group = "3. Midnight — Cloth & BoE gear", name = "BoE gear from any Midnight mob",
  tier = "Lottery · good with AoE", body = "Almost any enemy in Midnight zones can drop Bind-on-Equip gear, worth gold on the Auction House or for disenchanting. Pick a dense spot and kill in a loop so mobs respawn behind you. Ranged AoE specs do best (Balance Druid, Frost/Fire Mage, Beast Mastery/Marksmanship Hunter)." },

------------------------------------------------------------------------
{ group = "4. Old content — transmog, BoEs, collectibles", name = "How old-content gold works",
  tier = "Read first", body = "Old dungeon and raid mobs give only a small fixed amount of gold per kill (Blizzard scaled it down years ago so soloing isn't a gold fountain). The money in old content comes from:\n• BoE gear and rare transmog appearances to sell.\n• Recipes, pets and mounts (sell or keep).\n• Vendor trash and disenchanting.\nHigh-value items can take weeks to sell — list a few at a time." },
{ group = "4. Old content — transmog, BoEs, collectibles", name = "Blackrock Depths", inst = "Blackrock Depths",
  tier = "Raw gold + BoEs", body = "Huge pulls and lots of mobs: vendor gold and BoE items. Long but rewarding clear." },
{ group = "4. Old content — transmog, BoEs, collectibles", name = "Maraudon", inst = "Maraudon",
  tier = "Transmog + herbs", body = "Very dense mobs, transmog drops and herbs inside." },
{ group = "4. Old content — transmog, BoEs, collectibles", name = "Uldaman", inst = "Uldaman",
  tier = "Rare transmog lottery", body = "Known for rare, valuable transmog appearances — a lottery farm." },
{ group = "4. Old content — transmog, BoEs, collectibles", name = "Razorfen Kraul", inst = "Razorfen Kraul",
  tier = "Fast resets", body = "Short and fast to clear — good to chain many runs (you can enter 10 instances per hour per account)." },
{ group = "4. Old content — transmog, BoEs, collectibles", name = "Legion, BfA & Shadowlands raids",
  tier = "Weekly · low effort", body = "With decent Midnight gear these raids are easy solo. Weekly lockouts, but they give gold from bosses and trash, sellable transmog, low-chance mounts and pets, and lots to disenchant. Do them once a week on every max-level character." },

------------------------------------------------------------------------
{ group = "5. Weekly & passive income", name = "Weekly routine", tier = "Steady",
  body = "• Weekly quests and event caches (reagents and sellable items).\n• Great Vault: take gear you can sell or disenchant if it's not an upgrade.\n• Rares and treasures in Midnight zones (including Zul'Aman) for reagents.\n• Delves: chain a few per day and gather along the way; community reports say the rare reagent Petrified Root comes from delve and Prey caches." },
{ group = "5. Weekly & passive income", name = "Crafting orders & the Auction House", tier = "Best gold per time for crafters",
  body = "• Crafting orders often pay better than selling on the Auction House — if you have a specialized crafter.\n• Buy herbs/ore in the evening when gatherers flood the market, sell mid-week.\n• Stock consumables and gems before a new patch or raid tier.\n• Watch for underpriced mounts, recipes and transmog. A price addon (Auctionator / TSM) helps a lot." },
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
