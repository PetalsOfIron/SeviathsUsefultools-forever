-- Seviath's Codex — the dungeons, raids, bosses and entrances of Classic (WoW Forever has no Adventure Guide to read them from).
-- Written for this addon: levels, places and the bosses in the order they are usually met. Coordinates are approximate (percent of the zone map).

local ADDON, ns = SFP_Module("Codex")
local C = ns.CYAN

-- { name, "dungeon" or "raid", level text, zone map, x, y, "where", { bosses } }
local INSTANCES = {
{ "Ragefire Chasm", "dungeon", "13-18", 1454, 52.0, 49.0, "Cleft of Shadow in Orgrimmar (Horde)", { "Oggleflint", "Taragaman the Hungerer", "Jergosh the Invoker", "Bazzalan" } },
{ "Wailing Caverns", "dungeon", "15-25", 1413, 46.0, 36.0, "The Barrens, west of the Crossroads", { "Lady Anacondra", "Lord Cobrahn", "Kresh", "Lord Pythas", "Skum", "Lord Serpentis", "Verdan the Everliving", "Mutanus the Devourer" } },
{ "The Deadmines", "dungeon", "15-21", 1436, 43.0, 72.0, "Moonbrook, Westfall", { "Rhahk'Zor", "Sneed's Shredder", "Gilnid", "Mr. Smite", "Captain Greenskin", "Edwin VanCleef", "Cookie" } },
{ "Shadowfang Keep", "dungeon", "18-25", 1421, 44.0, 68.0, "Silverpine Forest, on the hill near the sea", { "Rethilgore", "Razorclaw the Butcher", "Baron Silverlaine", "Commander Springvale", "Odo the Blindwatcher", "Fenrus the Devourer", "Wolf Master Nandos", "Archmage Arugal" } },
{ "Blackfathom Deeps", "dungeon", "20-30", 1440, 14.0, 14.0, "Ashenvale coast, near Astranaar", { "Ghamoo-ra", "Lady Sarevess", "Gelihast", "Twilight Lord Kelris", "Old Serra'kis", "Aku'mai" } },
{ "The Stockade", "dungeon", "22-30", 1453, 41.0, 58.0, "Stormwind City, the canal district", { "Targorr the Dread", "Kam Deepfury", "Hamhock", "Bazil Thredd", "Dextren Ward" } },
{ "Gnomeregan", "dungeon", "24-33", 1426, 31.0, 38.0, "Dun Morogh, the gnome starting area", { "Grubbis", "Viscous Fallout", "Electrocutioner 6000", "Crowd Pummeler 9-60", "Mekgineer Thermaplugg" } },
{ "Razorfen Kraul", "dungeon", "25-35", 1413, 40.0, 90.0, "The Barrens, south of the Crossroads", { "Aggem Thorncurse", "Death Speaker Jargba", "Overlord Ramtusk", "Agathelos the Raging", "Charlga Razorflank" } },
{ "Scarlet Monastery", "dungeon", "28-38", 1420, 83.0, 32.0, "Tirisfal Glades, near Brill (four wings)", { "Interrogator Vishas", "Houndmaster Loksey", "Arcanist Doan", "Herod", "High Inquisitor Fairbanks", "Scarlet Commander Mograine", "High Inquisitor Whitemane" } },
{ "Razorfen Downs", "dungeon", "35-45", 1413, 50.0, 93.0, "The Barrens, far south", { "Tuten'kash", "Mordresh Fire Eye", "Glutton", "Amnennar the Coldbringer" } },
{ "Uldaman", "dungeon", "35-45", 1418, 42.0, 13.0, "Badlands, north of Kargath", { "Revelosh", "Ironaya", "Obsidian Sentinel", "Ancient Stone Keeper", "Galgann Firehammer", "Archaedas" } },
{ "Zul'Farrak", "dungeon", "42-50", 1446, 39.0, 21.0, "Tanaris, the Sandsorrow Watch", { "Antu'sul", "Theka the Martyr", "Witch Doctor Zum'rah", "Gahz'rilla", "Chief Ukorz Sandscalp" } },
{ "Maraudon", "dungeon", "43-52", 1443, 29.0, 62.0, "Desolace, Mauradon valley", { "Noxxion", "Razorlash", "Lord Vyletongue", "Celebras the Cursed", "Landslide", "Tinkerer Gizlock", "Rotgrip", "Princess Theradras" } },
{ "The Temple of Atal'Hakkar", "dungeon", "45-55", 1435, 70.0, 54.0, "Swamp of Sorrows, on the island", { "Atal'alarion", "Dreamscythe", "Weaver", "Jammal'an the Prophet", "Ogom the Wretched", "Morphaz", "Hazzas", "Shade of Eranikus" } },
{ "Blackrock Depths", "dungeon", "52-60", 1428, 29.0, 38.0, "Blackrock Mountain (Burning Steppes / Searing Gorge)", { "High Interrogator Gerstahn", "Lord Roccor", "Bael'Gar", "Lord Incendius", "Fineous Darkvire", "Warder Stilgiss", "Verek", "Ambassador Flamelash", "Magmus", "Emperor Dagran Thaurissan" } },
{ "Lower Blackrock Spire", "dungeon", "55-60", 1428, 29.0, 38.0, "Blackrock Mountain, the Spire above", { "Highlord Omokk", "Shadow Hunter Vosh'gajin", "War Master Voone", "Mother Smolderweb", "Quartermaster Zigris", "Halycon", "Gizrul the Slavener", "Overlord Wyrmthalak" } },
{ "Upper Blackrock Spire", "dungeon", "58-60", 1428, 29.0, 38.0, "Blackrock Mountain, the top of the Spire (needs the key)", { "Pyroguard Emberseer", "Solakar Flamewreath", "Warchief Rend Blackhand", "Gyth", "The Beast", "General Drakkisath" } },
{ "Stratholme", "dungeon", "58-60", 1423, 31.0, 16.0, "Eastern Plaguelands, the Scarlet city", { "Skul", "Fras Siabi", "Hearthsinger Forresten", "The Unforgiven", "Timmy the Cruel", "Cannon Master Willey", "Archivist Galford", "Balnazzar", "Baroness Anastari", "Nerub'enkan", "Maleki the Pallid", "Magistrate Barthilas", "Ramstein the Gorger", "Baron Rivendare" } },
{ "Scholomance", "dungeon", "58-60", 1422, 69.0, 73.0, "Western Plaguelands, Caer Darrow", { "Kirtonos the Herald", "Jandice Barov", "Rattlegore", "Marduk Blackpool", "Vectus", "Ras Frostwhisper", "Instructor Malicia", "Doctor Theolen Krastinov", "Lorekeeper Polkelt", "The Ravenian", "Lord Alexei Barov", "Lady Illucia Barov", "Darkmaster Gandling" } },
{ "Dire Maul", "dungeon", "55-60", 1444, 65.0, 35.0, "Feralas, the Ruins of Eldre'Thalas (east, west and north wings)", { "Zevrim Thornhoof", "Hydrospawn", "Lethtendris", "Alzzin the Wildshaper", "Tendris Warpwood", "Magister Kalendris", "Immol'thar", "Prince Tortheldrin", "Guard Mol'dar", "Stomper Kreeg", "Captain Kromcrush", "Cho'Rush the Observer", "King Gordok" } },
{ "Molten Core", "raid", "60 (40 players)", 1428, 29.0, 38.0, "Blackrock Mountain, through Blackrock Depths", { "Lucifron", "Magmadar", "Gehennas", "Garr", "Shazzrah", "Baron Geddon", "Sulfuron Harbinger", "Golemagg the Incinerator", "Majordomo Executus", "Ragnaros" } },
{ "Onyxia's Lair", "raid", "60 (40 players)", 1445, 52.0, 76.0, "Dustwallow Marsh, the cave above the swamp", { "Onyxia" } },
{ "Blackwing Lair", "raid", "60 (40 players)", 1428, 29.0, 38.0, "Blackrock Mountain, above Upper Blackrock Spire", { "Razorgore the Untamed", "Vaelastrasz the Corrupt", "Broodlord Lashlayer", "Firemaw", "Ebonroc", "Flamegor", "Chromaggus", "Nefarian" } },
{ "Zul'Gurub", "raid", "60 (20 players)", 1434, 53.0, 17.0, "Stranglethorn Vale, the troll city in the north", { "High Priestess Jeklik", "High Priest Venoxis", "High Priestess Mar'li", "Bloodlord Mandokir", "Gahz'ranka", "High Priest Thekal", "High Priestess Arlokk", "Jin'do the Hexxer", "Hakkar" } },
{ "Ruins of Ahn'Qiraj", "raid", "60 (20 players)", 1451, 29.0, 96.0, "Silithus, the gates in the south", { "Kurinnaxx", "General Rajaxx", "Moam", "Buru the Gorger", "Ayamiss the Hunter", "Ossirian the Unscarred" } },
{ "Temple of Ahn'Qiraj", "raid", "60 (40 players)", 1451, 29.0, 96.0, "Silithus, deeper inside the Qiraji gates", { "The Prophet Skeram", "Battleguard Sartura", "Fankriss the Unyielding", "Viscidus", "Princess Huhuran", "The Twin Emperors", "Ouro", "C'Thun" } },
{ "Naxxramas", "raid", "60 (40 players)", 1423, 39.0, 26.0, "Eastern Plaguelands, the floating necropolis", { "Anub'Rekhan", "Grand Widow Faerlina", "Maexxna", "Noth the Plaguebringer", "Heigan the Unclean", "Loatheb", "Instructor Razuvious", "Gothik the Harvester", "The Four Horsemen", "Patchwerk", "Grobbulus", "Gluth", "Thaddius", "Sapphiron", "Kel'Thuzad" } },
}

function ns:LoadClassicInstances()
    for i, d in ipairs(INSTANCES) do
        local name, kind, level, map, x, y, where, bosses = d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8]
        local isRaid = kind == "raid"
        local mapt = { m = map, x = x / 100, y = y / 100 }
        local list = {}
        for b, boss in ipairs(bosses) do list[#list + 1] = b .. ". " .. boss end
        local entry = self:Add({
            cat = kind, id = name:lower(), name = name, group = "Classic",
            icon = "Interface\\Icons\\" .. (isRaid and "Achievement_Boss_Ragnaros" or "INV_Misc_Key_14"),
            sub = level .. " — " .. where,
            body = C .. "Level|r\n" .. level .. "\n\n" .. C .. "Where|r\n" .. where .. "\n\n" .. C .. "Bosses|r\n" .. table.concat(list, "\n"),
            map = mapt, isRaid = isRaid, tier = "Classic", order = i, tags = "classic " .. (isRaid and "raid" or "dungeon"),
        })
        local ent = self:Add({
            cat = "entrance", id = "classic:" .. name:lower(), name = name, group = "Classic",
            icon = "Interface\\Icons\\Spell_Arcane_PortalDalaran",
            sub = (isRaid and "Raid" or "Dungeon") .. " — " .. where,
            body = C .. "How to enter|r\n" .. where .. "\n\n|cff888888Open the map from this page to place a waypoint at the entrance.|r",
            map = mapt, isRaid = isRaid, tags = "classic entrance",
        })
        if entry and ent and self.Link then self:Link(entry, ent) end
        for b, boss in ipairs(bosses) do
            local be = self:Add({
                cat = "boss", id = name:lower() .. ":" .. boss:lower(), name = boss, group = name,
                icon = "Interface\\Icons\\Achievement_Boss_Archaedas",
                sub = name .. " — boss " .. b .. " of " .. #bosses,
                body = C .. "Where|r\n" .. name .. " (" .. where .. ")\n\n" .. C .. "Order|r\nBoss " .. b .. " of " .. #bosses .. " in the usual run.",
                map = mapt, tags = "classic boss " .. name:lower(), order = b,
            })
            if entry and be and self.Link then self:Link(entry, be) end
        end
    end
end
