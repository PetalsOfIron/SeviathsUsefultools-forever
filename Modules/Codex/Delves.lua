-- Seviath's Codex — Delves: every delve with location, what's active today,
-- general delve mechanics and the seasonal Nemesis boss.
-- Locations come live from the game's map. Mechanics written in our own words
-- from Icy Veins / PlayNews guides (Midnight Season 2, 2026).

local ADDON, ns = SFP_Module("Codex")
local C = ns.CYAN

-- Midnight delves by zone (seed list; live map data adds exact spots)
ns.DELVE_LIST = {
    { "Collegiate Calamity", "Silvermoon City" }, { "The Darkway", "Silvermoon City" },
    { "The Shadow Enclave", "Eversong Woods" },
    { "The Grudge Pit", "Harandar" }, { "The Gulf of Memory", "Harandar" },
    { "Parhelion Plaza", "Isle of Quel'Danas" },
    { "Twilight Crypts", "Zul'Aman" }, { "Atal'Aman", "Zul'Aman" },
    { "Shadowguard Point", "Voidstorm" }, { "Sunkiller Sanctum", "Voidstorm" },
    { "Torment's Rise", "Voidstorm" },
}

local GENERAL = C .. "How delves work|r\n"
    .. "• Solo or up to 5 players. An NPC companion (Valeera Sanguinar in Midnight) joins when you're fewer than 5.\n"
    .. "• Pick the tier at the entrance. Higher tiers = tougher enemies, fewer revives, better loot (and better Great Vault rewards).\n"
    .. "• Bountiful delves (shown on the map / Delver's Guide) need a key and give an extra chest — save keys for your highest comfortable tier.\n"
    .. "• Each delve has several story variants with different objectives; the map tooltip shows which one is active.\n"
    .. "• Delves fill the World row of the Great Vault."

local COMPANION = C .. "Companion setup (Valeera)|r\n"
    .. "• Pure damage dealers: set her to Healer.\n• Hybrids (e.g. Retribution, Feral): Tank.\n• Healers and tanks: Damage.\n"
    .. "• Curios: one Combat + one Utility slot, upgradeable. If your class lacks crowd control, take a slow/stun curio."

local TIERS = C .. "Tiers (Season 2)|r\n"
    .. "Tier 1-3: easy, loot up to ilvl 272 at the end.\nTier 4-6: needs decent gear.\nTier 7: big jump in rewards.\nTier 8+: best end-of-run loot (295) and Great Vault (305).\n"
    .. "|cff888888Item levels change each season — check the delve entrance tooltip.|r"

local function DelveText(e)
    local out = {}
    -- what the addon collected when you entered it, and whether you finished it
    local S = _G.SeviathsUsefulTools and _G.SeviathsUsefulTools.Social
    local lib = S and S.Config and S.Config().lib
    local seen = lib and lib.delve and e.name and lib.delve[e.name]
    local done = S and S.Config and S.Config().done and S.Config().done.delve and e.name and S.Config().done.delve[e.name:lower()]
    if seen or done then
        out[#out + 1] = C .. "You|r\nEntered " .. ((seen and seen.n) or 0) .. " time" .. (((seen and seen.n) or 0) == 1 and "" or "s") .. (done and ", finished" or "")
    end
    if e.map then
        local cont = ns.ContinentOf and select(2, ns.ContinentOf(e.map.m))
        out[#out + 1] = C .. "Where|r\n" .. ns:Coords(e.map) .. (cont and (" » " .. cont) or "")
    elseif e.zoneName then
        out[#out + 1] = C .. "Where|r\n" .. e.zoneName .. "\n|cff888888Exact spot appears once the map has been read (open the zone map once).|r"
    end
    if e.today and e.today ~= "" then out[#out + 1] = C .. "Today|r\n" .. e.today end
    if e.desc and e.desc ~= "" then out[#out + 1] = C .. "Active story|r\n" .. e.desc end
    if e.nemesis then out[#out + 1] = C .. "Nemesis delve|r\nThis was the Season 1 Nemesis delve. The current Nemesis boss has its own page under Delves » Seasonal Nemesis." end
    out[#out + 1] = GENERAL
    out[#out + 1] = COMPANION
    out[#out + 1] = TIERS
    return table.concat(out, "\n\n")
end
ns.DelveText = DelveText

------------------------------------------------------------------------
-- Nemesis boss (Season 2)
------------------------------------------------------------------------
local NEMESIS = {
    name = "Az'tarec", where = { m = 2512, x = 0.5123, y = 0.3070 },
    body = C .. "Where|r\nVenomfall Deeps, north part of the Coiled Deeps on the Coiled Isle (top of the Serpent's Tail).\n\n"
        .. C .. "Unlock|r\n• Tier ?: clear a Tier 7 delve with at least one life left (Season 2).\n• Tier ??: clear a Tier 10 delve with at least one life left.\n\n"
        .. C .. "Setup|r\nValeera as Healer (she dispels the poison). A boss-warning addon helps.\n\n"
        .. C .. "Mechanics (fixed order, repeats)|r\n"
        .. "1. Noxious Bile — poison cone at you + pools: sidestep, stay out of pools.\n"
        .. "2. Void Toxin — DoT that ends in a big hit: interrupt it or dispel it.\n"
        .. "3. Soul Extinction — lethal cast: interrupt EVERY time.\n"
        .. "4. Venom Storm — slow poison waves: dodge through the gaps.\n"
        .. "5. Serpent's Strike — heavy hit (tanks only): use a defensive.\n\n"
        .. C .. "Intermissions at 90% / 60% / 30%|r\n"
        .. "He shields himself in the middle and casts Sermon of Ula'tek. The room is split into 4 quadrants: the poisoned ones are shown first, then the same order repeats WITHOUT warnings — memorise the safe quadrants from the first round.\n\n"
        .. C .. "Tier ?? extra|r\nEach intermission also summons an Echo of Az'tarec with the same abilities — kill it before the Sermon ends. Crowd-control the Echo's Soul Extinction to keep your interrupt for the real boss (he's immune to CC). Save big cooldowns for the Echoes.\n\n"
        .. C .. "Rewards|r\nToy, cosmetics, a title and a mount.",
}

------------------------------------------------------------------------
-- Indexer
------------------------------------------------------------------------
function ns:IndexDelves()
    -- seed list
    for _, d in ipairs(self.DELVE_LIST) do
        self:Add({
            cat = "delve", id = d[1]:lower(), name = d[1], group = "1. Midnight — " .. d[2],
            icon = "Interface\\Icons\\INV_Misc_Lantern_01", sub = d[2], zoneName = d[2],
            nemesis = d[1] == "Torment's Rise", tags = "delve " .. d[2],
        })
    end
    -- the delves you entered that the lists above do not have: the addon saved them (with their IDs) when you walked in
    do
        local S = _G.SeviathsUsefulTools and _G.SeviathsUsefulTools.Social
        local lib = S and S.Config and S.Config().lib
        for name, rec in pairs((lib and lib.delve) or {}) do
            local l = name:lower()
            if not self:Get("delve:" .. l) then
                self:Add({
                    cat = "delve", id = l, name = name, group = "1. Midnight — entered",
                    icon = "Interface\\Icons\\INV_Misc_Lantern_01", sub = "Collected when you entered it" .. (rec.id and (" (instance " .. rec.id .. ")") or ""),
                    zoneName = nil, tags = "delve entered",
                })
            end
        end
    end
    -- live: every delve the map knows, with exact spot and today's state
    local zones = C_Map.GetMapChildrenInfo(946, Enum.UIMapType.Zone, true) or {}
    for _, z in ipairs(zones) do
        local ids
        if C_AreaPoiInfo and C_AreaPoiInfo.GetDelvesForMap then
            local ok, r = pcall(C_AreaPoiInfo.GetDelvesForMap, z.mapID)
            if ok then ids = r end
        end
        for _, poiID in ipairs(ids or {}) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(z.mapID, poiID)
            if info and info.name and info.position then
                local bountiful = info.atlasName and info.atlasName:lower():find("bountiful")
                local contID, contName = ns.ContinentOf(z.mapID)
                local exp
                if self.DELVE_GUIDES and self.DELVE_GUIDES[info.name:lower()] then exp = "1. Midnight"
                elseif contName and contName:lower():find("quel'thalas") then exp = "1. Midnight"
                elseif contID == 2274 or (contName and contName:lower():find("khaz algar")) then exp = "2. The War Within"
                else exp = "3. " .. (contName or "Other") end
                local e = self:Add({
                    cat = "delve", id = info.name:lower(), name = info.name,
                    group = exp .. " — " .. z.name,
                    icon = "Interface\\Icons\\INV_Misc_Lantern_01", sub = z.name, zoneName = z.name,
                    tags = "delve " .. z.name,
                })
                if e then
                    e.map = { m = z.mapID, x = info.position.x, y = info.position.y }
                    e.desc = info.description
                    e.today = bountiful and "|cffffd100Bountiful today|r — bring a key for the extra chest." or "Normal today."
                end
            end
        end
        self:Yield()
    end
    -- nemesis
    local n = self:Add({
        cat = "delve", id = "nemesis:" .. NEMESIS.name, name = NEMESIS.name .. " (Nemesis)", group = "0. Seasonal Nemesis",
        icon = "Interface\\Icons\\Achievement_Boss_Archaedas", sub = "Season 2 Nemesis boss", body = NEMESIS.body,
        map = NEMESIS.where, tags = "delve nemesis boss",
    })
end
