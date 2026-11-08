-- SeviathsUsefulTools - recommended gems and enchants per specialization (Gem & Enchant Helper)
-- Source: the Method.gg "stats, races and consumables" page of each specialization, patch 12.1.5, read 2026-10-31.
-- Facts only (names and order). A line "A > B" means A first. Where a page gives one option per slot, the list has one name.
-- Key: class token : specialization name as the game shows it.
local _, SFP = ...

local BIS = {}
SFP.GemEnchantBis = BIS
SFP.GemEnchantBisPatch = ""

local function E(class, spec, t) BIS[class .. ":" .. spec] = t end

-- the enchantable slots of Midnight Season 1 and the inventory slot numbers they use
-- (cloak and bracer enchants were removed; legs take a Tailoring spellthread or a Leatherworking armor kit)
SFP.EnchantSlots = {}
