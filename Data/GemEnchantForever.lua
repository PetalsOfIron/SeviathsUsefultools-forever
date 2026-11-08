-- SeviathsUsefulTools - gems and enchants of every WoW Forever specialization, made at login from two lists of the data:
--   * the enchants of the Enchanting recipes (Data/RecipeData.lua: "Enchant Chest - Greater Stats" ...), and
--   * the stat priority of each specialization (Data/StatPriority.lua, from Icy Veins).
-- Per slot the enchants whose names carry the stats the specialization wants most are listed, the best first. Forever has no gems in the data yet.

local _, SFP = ...

local SLOTS = {
    { key = "chest", label = "Chest", slot = 5, words = { "Chest" } },
    { key = "wrist", label = "Bracer", slot = 9, words = { "Bracer" } },
    { key = "hands", label = "Gloves", slot = 10, words = { "Gloves" } },
    { key = "feet", label = "Boots", slot = 8, words = { "Boots" } },
    { key = "back", label = "Cloak", slot = 15, words = { "Cloak" } },
    { key = "weapon", label = "Weapon", slot = 16, words = { "Weapon", "2H Weapon" } },
    { key = "offhand", label = "Shield", slot = 17, words = { "Shield" } },
}
SFP.EnchantSlots = SLOTS

-- the words of an enchant name that give a stat of the priority list
local STAT_WORDS = {
    ["strength"] = { "Strength" }, ["agility"] = { "Agility" }, ["intellect"] = { "Intellect" }, ["spirit"] = { "Spirit" },
    ["stamina"] = { "Stamina", "Health" }, ["healing power"] = { "Healing" }, ["spell power"] = { "Spell Power", "Spell Damage", "Fire", "Frost", "Shadow", "Arcane" },
    ["critical strike"] = { "Crit" }, ["hit chance"] = { "Hit" }, ["attack power"] = { "Attack Power" }, ["mp5"] = { "Mana" },
    ["weapon damage"] = { "Damage", "Striking", "Impact", "Crusader", "Mongoose", "Fiery" }, ["weapon dps"] = { "Damage", "Striking", "Impact", "Crusader", "Mongoose", "Fiery" },
    ["armor"] = { "Protection", "Armor" }, ["defense"] = { "Defense", "Protection" }, ["haste"] = { "Haste", "Speed" }, ["expertise"] = { "Expertise", "Skill" },
    ["avoidance"] = { "Dodge", "Parry" }, ["weapon skill"] = { "Skill" }, ["spell pierce"] = { "Penetration" },
}
local TIER = { Lesser = 1, Minor = 0, Greater = 3, Superior = 4, Major = 5, Mighty = 5 }

SFP:OnLogin(function()
    if not (SFP.RecipeData and SFP.StatPriority) then return end
    -- the enchants by slot: { name = "Greater Stats", rank = a number from the first word }
    local bySlot = {}
    for _, row in ipairs(SFP.RecipeData) do
        if row[2] == "Enchanting" then
            local slotName, enchant = row[3]:match("^Enchant ([^%-]+)%s%-%s(.+)$")
            if slotName then
                slotName = slotName:gsub("%s+$", "")
                for _, s in ipairs(SLOTS) do
                    for _, w in ipairs(s.words) do
                        if slotName == w then
                            bySlot[s.key] = bySlot[s.key] or {}
                            local first = enchant:match("^(%a+)")
                            table.insert(bySlot[s.key], { name = enchant, rank = TIER[first] or 2 })
                        end
                    end
                end
            end
        end
    end
    local out = {}
    for key, lists in pairs(SFP.StatPriority) do
        local list = lists[1]
        local rec = { stat = table.concat(list, " > "), gems = {}, gemNote = "Gems are not in the data yet." }
        for _, s in ipairs(SLOTS) do
            local scored = {}
            for _, e in ipairs(bySlot[s.key] or {}) do
                local score = 0
                for i, stat in ipairs(list) do
                    for _, w in ipairs(STAT_WORDS[stat:lower()] or {}) do
                        if e.name:find(w, 1, true) then score = score + (#list - i + 1) break end
                    end
                end
                if score > 0 then scored[#scored + 1] = { name = e.name, score = score * 10 + e.rank } end
            end
            table.sort(scored, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.name < b.name end)
            local names, seen = {}, {}
            for _, e in ipairs(scored) do
                if not seen[e.name] and #names < 3 then seen[e.name] = true; names[#names + 1] = e.name end
            end
            rec[s.key] = names
        end
        out[key] = rec
    end
    SFP.GemEnchantBis = out
    SFP.GemEnchantBisPatch = "Forever"
    if SFP.GemHelper and SFP.GemHelper.ResetPrices then SFP.GemHelper.ResetPrices() end
end)
