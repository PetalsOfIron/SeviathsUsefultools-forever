-- SeviathsUsefulTools - Gem & Enchant Helper
-- Pick a class and specialization: the recommended gems and enchants (Data/GemEnchantBis.lua), what your own gear
-- has, empty sockets, missing enchants, and a planner with auction house prices.
-- Gear check of other players (tooltip) is in Social.lua and uses CheckUnit() from here.

local _, SFP = ...

local GH = {}
SFP.GemHelper = GH

local function secret(v) return issecretvalue and issecretvalue(v) end

GH.CLASSES = {   -- the nine classes of WoW Forever
    { "DRUID", "Druid" }, { "HUNTER", "Hunter" }, { "MAGE", "Mage" }, { "PALADIN", "Paladin" }, { "PRIEST", "Priest" },
    { "ROGUE", "Rogue" }, { "SHAMAN", "Shaman" }, { "WARLOCK", "Warlock" }, { "WARRIOR", "Warrior" },
}

-- specialization names of one class, in alphabetical order, from the data
function GH.SpecsOf(token)
    local out = {}
    for key in pairs(SFP.GemEnchantBis or {}) do
        local c, s = key:match("^([^:]+):(.+)$")
        if c == token then out[#out + 1] = s end
    end
    table.sort(out)
    return out
end

function GH.Data(token, spec)
    return SFP.GemEnchantBis and SFP.GemEnchantBis[token .. ":" .. tostring(spec)]
end

-- the player's own class and current specialization (the default of the menu)
function GH.Own()
    local _, token = UnitClass("player")
    local spec
    -- Forever has no specialization: the one found from the talents (the tree with most points), as in the talent advisor
    local ta = SFP.TalentAdvisor
    if ta and ta.DetectedSpec then
        local okD, found = pcall(ta.DetectedSpec)
        if okD and type(found) == "string" then spec = found end
    end
    if not spec and GetSpecialization and GetSpecializationInfo then
        local idx = GetSpecialization()
        if idx then
            local _, name = GetSpecializationInfo(idx)
            if type(name) == "string" and not secret(name) then spec = name end
        end
    end
    return token, spec
end

function GH.Selected()
    local db = SFP.db
    local ownClass, ownSpec = GH.Own()
    local token = db.gemClass or ownClass
    local spec = db.gemSpec
    if db.gemClass ~= token then spec = nil end
    local list = GH.SpecsOf(token)
    local ok = false
    for _, s in ipairs(list) do if s == spec then ok = true end end
    if not ok then
        spec = (token == ownClass and ownSpec and GH.Data(token, ownSpec)) and ownSpec or list[1]
    end
    return token, spec
end

function GH.SetClass(token)
    SFP.db.gemClass = token
    SFP.db.gemSpec = nil
end

function GH.NextClass(step)
    local token = GH.Selected()
    local idx = 1
    for i, c in ipairs(GH.CLASSES) do if c[1] == token then idx = i end end
    idx = ((idx - 1 + step) % #GH.CLASSES) + 1
    GH.SetClass(GH.CLASSES[idx][1])
end

function GH.NextSpec(step)
    local token, spec = GH.Selected()
    local list = GH.SpecsOf(token)
    local idx = 1
    for i, s in ipairs(list) do if s == spec then idx = i end end
    idx = ((idx - 1 + step) % #list) + 1
    SFP.db.gemClass, SFP.db.gemSpec = token, list[idx]
end

function GH.ClassLabel(token)
    for _, c in ipairs(GH.CLASSES) do if c[1] == token then return c[2] end end
    return token
end

---------------------------------------------------------------------------
-- reading gear (own or inspected unit)
---------------------------------------------------------------------------
local function clean(s)
    if type(s) ~= "string" or secret(s) then return nil end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|A.-|a", ""):gsub("|T.-|t", "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
GH.Clean = clean

local function enchantNameOf(unit, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, unit, slot)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    for _, line in ipairs(data.lines) do
        local t = clean(line.leftText)
        if t then
            local name = t:match("^Enchanted:%s*(.+)$")
            if name then return name end
        end
    end
    return nil
end

local function emptySocketsOf(link)
    local getStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not getStats then return 0 end
    local ok, stats = pcall(getStats, link)
    if not ok or type(stats) ~= "table" then return 0 end
    local n = 0
    for k, v in pairs(stats) do
        if type(k) == "string" and k:find("^EMPTY_SOCKET_") and type(v) == "number" then n = n + v end
    end
    return n
end

local SLOT_LABEL = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulders", [5] = "Chest", [6] = "Belt", [7] = "Legs", [8] = "Boots", [9] = "Wrists",
    [10] = "Hands", [11] = "Ring 1", [12] = "Ring 2", [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Back",
    [16] = "Main hand", [17] = "Off hand",
}

-- what a unit wears: empty sockets per slot, enchant (name) of the enchantable slots, gem names
-- returns { slots = { [slot] = { link, empty, enchantID, enchant, gems = {names} } }, empty = total, missing = { labels }, any = bool }
function GH.CheckUnit(unit)
    local res = { slots = {}, empty = 0, emptyWhere = {}, missing = {}, any = false }
    for slot = 1, 17 do
        if slot ~= 4 then
            local okL, link = pcall(GetInventoryItemLink, unit, slot)
            if okL and type(link) == "string" and not secret(link) then
                res.any = true
                local rec = { link = link, empty = emptySocketsOf(link), gems = {} }
                local enchantID = tonumber(link:match("item:%d+:(%d*)"))
                rec.enchantID = enchantID or 0
                for g = 1, 4 do
                    local okG, gname = pcall(GetItemGem, link, g)
                    if okG and type(gname) == "string" and not secret(gname) then rec.gems[#rec.gems + 1] = gname end
                end
                if rec.empty > 0 then
                    res.empty = res.empty + rec.empty
                    res.emptyWhere[#res.emptyWhere + 1] = (SLOT_LABEL[slot] or ("slot " .. slot)) .. (rec.empty > 1 and (" x" .. rec.empty) or "")
                end
                res.slots[slot] = rec
            end
        end
    end
    for _, es in ipairs(SFP.EnchantSlots or {}) do
        local rec = res.slots[es.slot]
        if rec then
            if rec.enchantID == 0 then
                res.missing[#res.missing + 1] = es.label
            else
                rec.enchant = enchantNameOf(unit, es.slot)
            end
        end
    end
    return res
end

local function sameName(a, b)
    a, b = tostring(a):lower(), tostring(b):lower()
    return a == b or a:find(b, 1, true) ~= nil or b:find(a, 1, true) ~= nil
end

local function inList(name, list)
    for _, n in ipairs(list or {}) do if sameName(name, n) then return true end end
    return false
end

-- compare a check result with the recommended set of a specialization
-- returns { offEnchant = { "Chest: X" }, offGems = { "name" } }
function GH.Compare(res, data)
    local out = { offEnchant = {}, offGems = {} }
    if not (res and data) then return out end
    for _, es in ipairs(SFP.EnchantSlots or {}) do
        local rec = res.slots[es.slot]
        local bis = data[es.key]
        if rec and rec.enchant and bis and #bis > 0 and not inList(rec.enchant, bis) then
            out.offEnchant[#out.offEnchant + 1] = ("%s: %s (best: %s)"):format(es.label, rec.enchant, bis[1])
        end
    end
    local seen = {}
    for _, rec in pairs(res.slots) do
        for _, g in ipairs(rec.gems) do
            if not seen[g] and not inList(g, data.gems) then seen[g] = true; out.offGems[#out.offGems + 1] = g end
        end
    end
    table.sort(out.offGems)
    return out
end

---------------------------------------------------------------------------
-- prices of gems and enchants from the auction house names the scans saved
---------------------------------------------------------------------------
local catalog, catalogByName   -- the catalog of every gem and enchant, and the same by lowercase name (built on demand)
local priceIndex   -- lowercase name -> { itemIDs }
local wantedNames

local function wanted()
    if wantedNames then return wantedNames end
    wantedNames = {}
    for _, d in pairs(SFP.GemEnchantBis or {}) do
        for _, g in ipairs(d.gems or {}) do wantedNames[g:lower()] = true end
        for _, es in ipairs(SFP.EnchantSlots or {}) do
            for _, n in ipairs(d[es.key] or {}) do wantedNames[n:lower()] = true end
        end
    end
    return wantedNames
end

local function buildPriceIndex()
    priceIndex = {}
    local want = wanted()
    for id, name in pairs(SFP.db.ahNames or {}) do
        if type(name) == "string" then
            local low = name:lower()
            -- enchant scrolls read "Enchant Chest - Mark of the Worldsoul": only the part after the dash counts
            local tail = low:match("^enchant[^%-]*%-%s*(.+)$")
            local key = want[low] and low
            if not key and tail then
                tail = tail:gsub("%s*%(.*$", ""):gsub("%s+$", "")   -- drop a "(rank 2)" ending
                if want[tail] then key = tail end
            end
            if key then
                priceIndex[key] = priceIndex[key] or {}
                table.insert(priceIndex[key], id)
            end
        end
    end
end

function GH.ResetPrices() priceIndex = nil; catalog = nil; catalogByName = nil end

-- cheapest known price (copper) and the item ID of a gem or enchant by name, nil when no scan saw it
function GH.PriceOf(name)
    if not priceIndex then buildPriceIndex() end
    local ids = priceIndex[tostring(name):lower()]
    if not ids then return nil end
    local best, bestID
    for _, id in ipairs(ids) do
        local ok, p = pcall(SFP.GetPrice, SFP, id)
        if ok and type(p) == "number" and p > 0 and (not best or p < best) then best, bestID = p, id end
    end
    return best, bestID
end

---------------------------------------------------------------------------
-- the planner: what the player wants to get (saved)
---------------------------------------------------------------------------
-- the plan is saved: { [lowercase name] = { name, kind = "gem" | "enchant", qty } }
function GH.Plan()
    SFP.db.gemPlan = SFP.db.gemPlan or {}
    local plan = SFP.db.gemPlan
    for k, v in pairs(plan) do if type(v) ~= "table" then plan[k] = nil end end   -- an older format is dropped
    return plan
end

function GH.PlanHas(name) return GH.Plan()[tostring(name):lower()] ~= nil end

function GH.PlanSet(name, kind, on, itemID)
    local plan, key = GH.Plan(), tostring(name):lower()
    if on then
        if not plan[key] then plan[key] = { name = name, kind = kind or "gem", qty = 1, itemID = itemID } end
    else
        plan[key] = nil
    end
end

---------------------------------------------------------------------------
-- the catalog of every gem and enchant: the recipes read from Wowhead (Jewelcrafting gems, Enchanting, spellthreads and
-- armor kits), what the auction house scans saw, and the names on the guides
---------------------------------------------------------------------------
local GEM_WORDS = { "Peridot", "Amethyst", "Garnet", "Lapis", "Diamond", "Heliotrope" }

local function isGemName(n)
    for _, w in ipairs(GEM_WORDS) do if n:find(w, 1, true) then return true end end
    return false
end

-- "Enchant Chest - Mark of the Worldsoul" -> "Mark of the Worldsoul"
local function enchantDisplay(n)
    local tail = n:match("^Enchant[^%-]*%-%s*(.+)$")
    return (tail or n:gsub("^Enchant%s+", "")):gsub("%s*%(.*$", "")
end

function GH.Catalog()
    if catalog then return catalog end
    local byName = {}
    local function add(name, kind, itemID, where, rkey)
        if type(name) ~= "string" or name == "" then return end
        local key = name:lower()
        local e = byName[key]
        if not e then
            e = { name = name, kind = kind }
            byName[key] = e
        end
        if itemID and itemID > 0 and not e.itemID then e.itemID = itemID end
        if where and not e.where then e.where = where end
        if rkey and not e.rkey then e.rkey = rkey end   -- the recipe that makes it ("Profession|Recipe"), for "you can craft this"
    end
    -- the guides
    for _, d in pairs(SFP.GemEnchantBis or {}) do
        for _, g in ipairs(d.gems or {}) do add(g, "gem") end
        for _, es in ipairs(SFP.EnchantSlots or {}) do
            for _, n in ipairs(d[es.key] or {}) do add(n, "enchant") end
        end
    end
    -- Wowhead recipes
    -- every recipe whose product is a gem (item class 3) or an item enhancement (class 8) is in, from any expansion;
    -- the item class comes from the game's own item data, so no name has to be guessed
    local instant = C_Item and C_Item.GetItemInfoInstant
    for _, r in ipairs(SFP.RecipeData or {}) do
        local prof, name, out = r[2], r[3], r[4]
        local cls
        if instant and out and out > 0 then
            local ok, _, _, _, _, _, c = pcall(instant, out)
            if ok then cls = c end
        end
        local rk = prof .. "|" .. name
        if cls == 3 then add(name, "gem", out, prof, rk)
        elseif cls == 8 then add(name:find("^Enchant") and enchantDisplay(name) or name, "enchant", out, prof, rk)
        elseif prof == "Jewelcrafting" then add(name, "gem", out, "Jewelcrafting", rk)   -- (Classic has no socketed gems: what Jewelcrafting makes is listed instead)
        elseif prof == "Enchanting" and name:find("^Enchant") then add(enchantDisplay(name), "enchant", out, "Enchanting", rk)
        elseif prof == "Tailoring" and name:find("Spellthread") then add(name, "enchant", out, "Tailoring", rk)
        elseif prof == "Leatherworking" and name:find("Armor Kit") then add(name, "enchant", out, "Leatherworking", rk) end
    end
    -- Classic has no gems to socket: the raw gems and stones are crafting reagents (they are listed here, with where they come from)
    local RAW = { { 774, "Malachite" }, { 818, "Tigerseye" }, { 1210, "Shadowgem" }, { 1206, "Moss Agate" }, { 1705, "Lesser Moonstone" },
        { 1529, "Jade" }, { 3864, "Citrine" }, { 7909, "Aquamarine" }, { 7910, "Star Ruby" }, { 12361, "Blue Sapphire" }, { 12799, "Large Opal" },
        { 12364, "Huge Emerald" }, { 12800, "Azerothian Diamond" }, { 11754, "Black Diamond" }, { 7971, "Black Pearl" }, { 13926, "Golden Pearl" } }
    for _, g in ipairs(RAW) do
        local nm = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(g[1])
        add(type(nm) == "string" and nm ~= "" and nm or g[2], "gem", g[1], "Raw gem - mining, vendors, drops")
    end
    -- what the auction house scans saw (item class 3 = gems, class 8 = item enhancements)
    for id, cls in pairs(SFP.db.ahItems or {}) do
        local nm = SFP.db.ahNames and SFP.db.ahNames[id]
        if type(nm) == "string" then
            if cls == 3 then add(nm, "gem", id, "Auction house")
            elseif cls == 8 then
                if nm:find("^Enchant") then add(enchantDisplay(nm), "enchant", id, "Auction house")
                elseif nm:find("Spellthread") or nm:find("Armor Kit") then add(nm, "enchant", id, "Auction house") end
            end
        end
    end
    catalog = {}
    for _, e in pairs(byName) do catalog[#catalog + 1] = e end
    table.sort(catalog, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        return a.name < b.name
    end)
    return catalog
end

function GH.CatalogByName(name)
    if not catalogByName then
        catalogByName = {}
        for _, e in ipairs(GH.Catalog()) do catalogByName[e.name:lower()] = e end
    end
    return catalogByName[tostring(name):lower()]
end

-- how many of a gem or enchant item you own (bags, bank, reagent bank), and whether one of your characters can craft it
function GH.Owned(e)
    local id = e.itemID
    if not id then
        local c = GH.CatalogByName(e.name)
        id = c and c.itemID
    end
    if not id or not (C_Item and C_Item.GetItemCount) then return 0 end
    local ok, n = pcall(C_Item.GetItemCount, id, true, false, true)
    return (ok and tonumber(n)) or 0
end

function GH.CanCraft(e)
    local rk = e.rkey
    if not rk then
        local c = GH.CatalogByName(e.name)
        rk = c and c.rkey
    end
    return rk and SFP.db.recipes and SFP.db.recipes[rk] and true or false
end

-- price of a catalog or planner entry (copper) or nil: by its item, else by name. A planner entry without an item
-- takes the item of the catalog entry with the same name, so every gem and enchant has the price its item has.
function GH.EntryPrice(e)
    local id = e.itemID
    if not id then
        local c = GH.CatalogByName(e.name)
        id = c and c.itemID
    end
    local best
    if id then
        local ok, p = pcall(SFP.GetPrice, SFP, id)
        if ok and type(p) == "number" and p > 0 then best = p end
    end
    -- scrolls and gems exist in several qualities, each its own item with the same name: the cheapest of them counts
    local byName = GH.PriceOf(e.name)
    if byName and (not best or byName < best) then best = byName end
    return best
end

-- rows for the menu: { text, planKey, name, price } for the chosen specialization
function GH.Rows(token, spec)
    local d = GH.Data(token, spec)
    local rows = {}
    if not d then return rows, nil end
    local own = GH.CheckUnit("player")
    local function priceText(name)
        local p = GH.EntryPrice({ name = name })   -- by the catalog's item, else by name
        return p and (" |cffffd100" .. (GetMoneyString and GetMoneyString(p, true) or p) .. "|r") or " |cff808080no price|r"
    end
    -- gems
    rows[#rows + 1] = { header = "Gems" }
    for i, g in ipairs(d.gems or {}) do
        rows[#rows + 1] = { text = g .. priceText(g), planName = g, kind = "gem", price = (GH.PriceOf(g)) }
    end
    if d.gemNote then rows[#rows + 1] = { note = d.gemNote } end
    -- enchants
    rows[#rows + 1] = { header = "Enchants" }
    for _, es in ipairs(SFP.EnchantSlots or {}) do
        if es.label ~= "Ring 2" then   -- the ring recommendation is for both rings
            local bis = d[es.key] or {}
            local rec = own.slots[es.slot]
            local have
            if not rec then have = "|cff808080nothing equipped|r"
            elseif rec.enchantID == 0 then have = "|cffff6060missing|r"
            elseif rec.enchant then have = (inList(rec.enchant, bis) and "|cff40ff40" or "|cffffd100") .. rec.enchant .. "|r"
            else have = "|cff40ff40enchanted|r" end
            local label = (es.key == "ring") and "Rings" or es.label
            if #bis == 0 then
                rows[#rows + 1] = { text = ("%s: |cff808080no recommendation on the guide|r   you: %s"):format(label, have) }
            else
                rows[#rows + 1] = { text = ("%s: %s%s   you: %s"):format(label, bis[1], priceText(bis[1]), have),
                    planName = bis[1], kind = "enchant", price = (GH.PriceOf(bis[1])) }
                if #bis > 1 then
                    local alt = {}
                    for i = 2, #bis do alt[#alt + 1] = bis[i] end
                    rows[#rows + 1] = { note = "also good: " .. table.concat(alt, ", ") }
                end
            end
        end
    end
    return rows, d, own
end

-- everything in the planner that is ticked and what it costs together: count, total copper, how many have no price
function GH.PlanTotal()
    local total, n, noPrice = 0, 0, 0
    for _, e in pairs(GH.Plan()) do
        if not e.off then
            n = n + (e.qty or 1)
            local p = GH.EntryPrice(e)
            if p then total = total + p * (e.qty or 1) else noPrice = noPrice + 1 end
        end
    end
    return n, total, noPrice
end

---------------------------------------------------------------------------
-- the planner window: every gem and enchant, click to add, tick to count it, prices follow the scans
---------------------------------------------------------------------------
local planWin, planResults, planRows, planBox, planInfo
local planKind = "gem"   -- the list on show: "gem" or "enchant"
local planKindChecked
local planKindBtns

local function moneyText(c)
    return GetMoneyString and GetMoneyString(c, true) or tostring(c)
end

local function planRefresh()
    if not (planWin and planWin:IsShown()) then return end
    local q = (planBox:GetText() or ""):lower()
    local plan = GH.Plan()
    -- two buttons on top, Gems and Enchants: each lists ALL of its kind (every one the addon knows), filtered by the search box;
    -- a click adds one to the planner, another click takes it out
    local counts = { gem = 0, enchant = 0 }
    local items, shown, cap = {}, 0, 900
    -- nothing to show under Gems (Classic has none): open on the Enchants
    if planKind == "gem" and not planKindChecked then
        planKindChecked = true
        local any = false
        for _, e in ipairs(GH.Catalog()) do if e.kind == "gem" then any = true break end end
        if not any then planKind = "enchant" end
    end
    for _, e in ipairs(GH.Catalog()) do
        if #q < 2 or e.name:lower():find(q, 1, true) then
            counts[e.kind] = (counts[e.kind] or 0) + 1
            if e.kind == planKind then
                shown = shown + 1
                if shown <= cap then
                    local p = GH.EntryPrice(e)
                    local own = GH.Owned(e)
                    items[#items + 1] = {
                        text = ("%s  |cff808080%s|r  %s%s%s"):format(e.name, e.where or "",
                            p and ("|cffffd100" .. moneyText(p) .. "|r") or "|cff808080no price|r",
                            own > 0 and ("  |cff66ff66you have " .. own .. "|r") or "",
                            GH.CanCraft(e) and "  |cffff6a60you can craft|r" or ""),
                        check = plan[e.name:lower()] ~= nil,
                        tip = function(tt)
                            local id = e.itemID
                            -- the recipe that makes it (Data/RecipeData.lua): its spell tooltip and reagents
                            local rec
                            if e.rkey then
                                local prof, nm = e.rkey:match("^(.-)|(.+)$")
                                for _, r in ipairs(SFP.RecipeData or {}) do
                                    if r[2] == prof and r[3] == nm then rec = r break end
                                end
                            end
                            if id and id > 0 then tt:SetItemByID(id)
                            elseif rec and tt.SetSpellByID then tt:SetSpellByID(rec[1])
                            else tt:SetText(e.name) end
                            if rec and rec[5] and #rec[5] > 0 then
                                tt:AddLine(" ")
                                tt:AddLine("|cffffd100" .. tostring(rec[2]) .. " - reagents:|r")
                                for _, rg in ipairs(rec[5]) do
                                    local nm = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(rg[1])
                                    tt:AddLine(("  %dx %s"):format(rg[2] or 1, nm or ("item " .. rg[1])), 0.9, 0.9, 0.9)
                                end
                            end
                            tt:Show()
                        end,
                        onToggle = function(on)
                            GH.PlanSet(e.name, e.kind, on, e.itemID)
                            planRefresh()
                        end,
                    }
                end
            end
        end
    end
    if shown > cap then table.insert(items, 1, { text = ("|cff808080%d found, the first %d shown: type a name to narrow it down|r"):format(shown, cap) }) end
    if #items == 0 then items[1] = { text = "|cff808080Nothing matches.|r" } end
    planResults:Set(items)
    -- the two buttons show how many there are
    if planKindBtns then
        planKindBtns.gem:SetText(("Gems (%d)"):format(counts.gem))
        planKindBtns.enchant:SetText(("Enchants (%d)"):format(counts.enchant))
        planKindBtns.gem:SetEnabled(planKind ~= "gem")
        planKindBtns.enchant:SetEnabled(planKind ~= "enchant")
    end
    -- the plan: each can be ticked (counted) or unticked (kept in the list but left out), with an amount
    local list = {}
    for key, e in pairs(plan) do list[#list + 1] = { key = key, e = e } end
    table.sort(list, function(a, b) return a.e.name < b.e.name end)
    local rows = {}
    for _, it in ipairs(list) do
        local e = it.e
        local p = GH.EntryPrice(e)
        rows[#rows + 1] = {
            text = ("%dx %s  %s%s"):format(e.qty or 1, e.name, p and ("|cffffd100" .. moneyText(p) .. " each|r") or "|cff808080no price|r",
                GH.Owned(e) > 0 and ("  |cff66ff66you have " .. GH.Owned(e) .. "|r") or ""),
            check = not e.off,
            onToggle = function(on) e.off = (not on) or nil; planRefresh() end,
            buttons = {
                { "-", 24, function() e.qty = (e.qty or 1) - 1; if e.qty < 1 then plan[it.key] = nil end; planRefresh() end },
                { tostring(e.qty or 1), 34, function() end },
                { "+", 24, function() e.qty = (e.qty or 1) + 1; planRefresh() end },
                { "Remove", 60, function() plan[it.key] = nil; planRefresh() end },
            },
        }
    end
    if #rows == 0 then rows[1] = { text = "|cff808080Nothing planned yet. Click a gem or enchant above to add it.|r" } end
    planRows:Set(rows)
    local n, total, noPrice = GH.PlanTotal()
    planInfo:SetText(n == 0 and "|cff808080Tick what you want to count. Prices follow the auction house scans.|r"
        or ("|cffffd100Total for the ticked ones:|r " .. moneyText(total) .. (noPrice > 0 and ("  |cffff6060(" .. noPrice .. " without a price)|r") or "")))
end
GH.PlannerRefresh = planRefresh

function GH.ShowPlanner()
    if not planWin then
        planWin = SFP.MakeToolWindow("SeviathsUsefulToolsGemPlanner", "Gem & enchant planner", 540, 640)
        planWin.scroll:Hide()
        planBox = CreateFrame("EditBox", nil, planWin, "InputBoxTemplate")
        planBox:SetSize(240, 22)
        planBox:SetPoint("TOPLEFT", 22, -34)
        planBox:SetAutoFocus(false)
        planBox:SetScript("OnTextChanged", function() planRefresh() end)
        planBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local function bar(text, w, x, fn)
            local b = CreateFrame("Button", nil, planWin, "UIPanelButtonTemplate")
            b:SetSize(w, 22)
            b:SetPoint("TOPLEFT", x, -34)
            b:SetText(text)
            b:SetScript("OnClick", fn)
            return b
        end
        -- the two buttons on top: every gem, every enchant
        planKindBtns = {}
        planKindBtns.gem = bar("Gems", 120, 272, function() planKind = "gem"; planRefresh() end)
        planKindBtns.enchant = bar("Enchants", 120, 398, function() planKind = "enchant"; planRefresh() end)
        planResults = SFP.MakeRowList(planWin, 18, -66, 510, 250, 20)
        local label = planWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 22, -330)
        label:SetText("Your planner (saved)")
        local tickAll = bar("Tick all", 70, 380, function()
            for _, e in pairs(GH.Plan()) do e.off = nil end
            planRefresh()
        end)
        tickAll:ClearAllPoints(); tickAll:SetPoint("TOPLEFT", 380, -326); tickAll:SetHeight(20)
        local tickNone = bar("Tick none", 70, 454, function()
            for _, e in pairs(GH.Plan()) do e.off = true end
            planRefresh()
        end)
        tickNone:ClearAllPoints(); tickNone:SetPoint("TOPLEFT", 454, -326); tickNone:SetHeight(20)
        planRows = SFP.MakeRowList(planWin, 18, -352, 510, 220, 20)
        planInfo = planWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        planInfo:SetPoint("TOPLEFT", 22, -586)
        planInfo:SetWidth(490)
        planInfo:SetJustifyH("LEFT")
        -- prices come from the auction house scans: redraw every few seconds while it is open
        local acc = 0
        planWin:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc >= 5 then acc = 0; planRefresh() end
        end)
        planWin:SetScript("OnShow", function() planRefresh() end)
    end
    planWin:Show()
    planRefresh()
end

SFP:OnRefresh(function() GH.ResetPrices() end)
