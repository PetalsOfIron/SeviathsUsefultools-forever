-- SeviathsUsefulTools - item data
-- Every item ID here was checked against Wowhead's item data (name + quality).
-- Grey/poor items are left out on purpose. Names and icons come from the game
-- client at runtime, so they show in your own language.
-- drop  = drop chance for BoE items, from Wowhead's drop data / comments (approximate)
-- tiers = Dragonflight crafting-quality versions (all scanned on the AH)

local _, SFP = ...

SFP.Items = {}

-- Dungeon / raid mounts (Cataclysm to The War Within). Drop chances are the usual
-- community estimates (Wowhead comments / guides) - treat them as rough.
local function boss(id, drop, note) SFP.Items[id] = { kind = "mount", drop = drop, note = note } end
-- Classic / TBC / Wrath instance mounts
boss(21218,  "~1-2%", "trash, Temple of Ahn'Qiraj")                -- Blue Qiraji Resonating Crystal
boss(21323,  "~1-2%", "trash, Temple of Ahn'Qiraj")                -- Green Qiraji Resonating Crystal
boss(21324,  "~1-2%", "trash, Temple of Ahn'Qiraj")                -- Yellow Qiraji Resonating Crystal
boss(21321,  "<1%",   "trash, Temple of Ahn'Qiraj (rarest)")       -- Red Qiraji Resonating Crystal
boss(13335,  "~1%",   "Baron Rivendare, Stratholme")               -- Deathcharger's Reins
-- Midnight

-- Possible BoEs, NOT confirmed: listed by guides from test-realm data as Bind on Equip
-- drops from The Venomous Abyss trash lieutenants. Live item data may differ (Blizzard can
-- change binding before release), so they are shown separately as "unconfirmed".
for _, id in ipairs({ 271638, 271445, 271444, 271440, 271441, 271436, 271438, 271435, 271434 }) do
    SFP.Items[id] = { kind = "boe", unconfirmed = true, drop = "rare",
        note = "trash lieutenants, The Venomous Abyss - may have been changed" }
end

-- Enchanting: disenchant BoE gear from that expansion (any zone)
for _, id in ipairs({ 52555, 52719, 52721,     -- Hypnotic Dust, Greater Celestial Essence, Heavenly Shard
                      74249, 74250, 74248,     -- Spirit Dust, Mysterious Essence, Sha Crystal
                      109693, 113588,          -- Draenic Dust, Temporal Crystal
                      124440, 124441, 124442,  -- Arkhana, Leylight Shard, Chaos Crystal
                      152875, 152876, 152877,  -- Gloom Dust, Umbra Shard, Veiled Crystal
                      172230, 172231, 172232,  -- Soul Dust, Sacred Shard, Eternal Crystal
                      194123, 194124, 200113,  -- Chromatic Dust, Vibrant Shard, Resonant Crystal
                      219946, 219949, 219952,  -- Storm Dust, Gleaming Shard, Refulgent Crystal
                    }) do
    SFP.Items[id] = { kind = "enchant" }
end
-- Midnight: quality versions are scanned on the AH too


-- special materials: rare finds, profession-gated cloth, lure / beast-type drops.
-- Spots that drop them glow magenta instead of cyan.
for _, id in ipairs({ 44128, 72163, 172097, 193216, 193222, 193226, 193229, 193232, 212670, 212674,
                      237016, 237017, 238518, 238520, 238525, 238522, 238523, 238528, 238529, 238530 }) do
    if SFP.Items[id] then SFP.Items[id].special = true end
end

SFP.KindOrder = {}
SFP.KindLabel = {}
-- small icon per source, shown on every loot line (tooltips, browser)
SFP.KindIcon = {}
-- how each kind is obtained (drop chances for creature materials are not published)
SFP.KindHow = {}
SFP.DUNGEON_ICON = "Interface\\Minimap\\Dungeon"
SFP.RAID_ICON    = "Interface\\Minimap\\Raid"

function SFP:KindIconTag(kind, size)
    local t = self.KindIcon[kind]
    return t and ("|T" .. t .. ":" .. (size or 13) .. "|t") or ""
end
