-- SeviathsUsefulTools - mining and herbalism: the single best zone for each ore and herb
-- 'Best' = the zone with the most recorded nodes of that type on Wowhead (object spawn data).
-- pts = a spread sample of those node positions, so the glow covers the gathering area.

local _, SFP = ...

SFP.Gather = {}

-- the ores and herbs above (names/icons come from the game client)
SFP.Items[2770] = SFP.Items[2770] or { kind = "ore" }
SFP.Items[2771] = SFP.Items[2771] or { kind = "ore" }
SFP.Items[2775] = SFP.Items[2775] or { kind = "ore" }
SFP.Items[2776] = SFP.Items[2776] or { kind = "ore" }
SFP.Items[2772] = SFP.Items[2772] or { kind = "ore" }
SFP.Items[3858] = SFP.Items[3858] or { kind = "ore" }
SFP.Items[7911] = SFP.Items[7911] or { kind = "ore" }
SFP.Items[10620] = SFP.Items[10620] or { kind = "ore" }
SFP.Items[2447] = SFP.Items[2447] or { kind = "herb" }
SFP.Items[765] = SFP.Items[765] or { kind = "herb" }
SFP.Items[2449] = SFP.Items[2449] or { kind = "herb" }
SFP.Items[785] = SFP.Items[785] or { kind = "herb" }
SFP.Items[2450] = SFP.Items[2450] or { kind = "herb" }
SFP.Items[2453] = SFP.Items[2453] or { kind = "herb" }
SFP.Items[3355] = SFP.Items[3355] or { kind = "herb" }
SFP.Items[3356] = SFP.Items[3356] or { kind = "herb" }
SFP.Items[3369] = SFP.Items[3369] or { kind = "herb" }
SFP.Items[3357] = SFP.Items[3357] or { kind = "herb" }
SFP.Items[3818] = SFP.Items[3818] or { kind = "herb" }
SFP.Items[3358] = SFP.Items[3358] or { kind = "herb" }
SFP.Items[3821] = SFP.Items[3821] or { kind = "herb" }
SFP.Items[4625] = SFP.Items[4625] or { kind = "herb" }
SFP.Items[8831] = SFP.Items[8831] or { kind = "herb" }
SFP.Items[8838] = SFP.Items[8838] or { kind = "herb" }
SFP.Items[8839] = SFP.Items[8839] or { kind = "herb" }
SFP.Items[8845] = SFP.Items[8845] or { kind = "herb" }
SFP.Items[8846] = SFP.Items[8846] or { kind = "herb" }
SFP.Items[13464] = SFP.Items[13464] or { kind = "herb" }
SFP.Items[13463] = SFP.Items[13463] or { kind = "herb" }
SFP.Items[13465] = SFP.Items[13465] or { kind = "herb" }
SFP.Items[13466] = SFP.Items[13466] or { kind = "herb" }
SFP.Items[13467] = SFP.Items[13467] or { kind = "herb" }
SFP.Items[13468] = SFP.Items[13468] or { kind = "herb" }
SFP.Items[3820] = SFP.Items[3820] or { kind = "herb" }
SFP.Items[8836] = SFP.Items[8836] or { kind = "herb" }
