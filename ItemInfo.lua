-- SeviathsUsefulTools - item tooltips: where to get the item, and how to use it
-- Added to the lines SFP:ItemTipLines builds (bags, auction house, links, comparison tooltips).

local _, SFP = ...

local function try(fn, ...)
    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j, k, l, m end
end

local SOURCE_TYPE = { [1] = "Boss drop", [2] = "Quest reward", [3] = "Vendor", [4] = "World drop", [5] = "Achievement", [6] = "Crafted" }

local function mapName(m)
    local info = m and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    return info and info.name or "?"
end

-- ---------------------------------------------------------------- zones
local EXP_KEYS = { [0] = "classic", "tbc", "wrath", "cata", "mop", "wod", "legion", "bfa", "sl", "df", "tww", "midnight" }
local zoneIdx, expByKey

local function zname(map)
    return SFP.ZoneName and SFP:ZoneName(map) or mapName(map)
end

-- the place as the map names it: the area at the spot ("Temple of Halazzi"), then the zone it is in
local function placeName(map, x, y, area)
    local zone = zname(map)
    if type(area) == "string" and area ~= "" and area ~= zone then return area .. " (" .. zone .. ")" end
    if C_Map and C_Map.GetMapInfoAtPosition and type(x) == "number" and type(y) == "number" then
        local ok, info = pcall(C_Map.GetMapInfoAtPosition, map, x, y)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" and info.name ~= zone then
            return info.name .. " (" .. zone .. ")"
        end
    end
    return zone
end

local function buildZoneIdx()
    zoneIdx, expByKey = {}, {}
    local function add(id, map, tag, n)
        if not (id and map) then return end
        local t = zoneIdx[id]
        if not t then t = {}; zoneIdx[id] = t end
        local e = t[map]
        if not e then e = { tag = tag, n = 0 }; t[map] = e end
        e.n = e.n + (n or 1)
    end
    for _, exp in ipairs(SFP.Expansions or {}) do
        expByKey[exp.key] = exp
        for _, z in ipairs(exp.zones or {}) do
            for _, id in ipairs(z.items or {}) do add(id, z.map, "farm", 1) end
        end
    end
    for _, g in ipairs(SFP.Gather or {}) do add(g.item, g.map, g.kind == "herb" and "herb" or "ore", g.nodes) end
    for _, tbl in ipairs({ SFP.Spawns or {}, SFP.Rares or {} }) do
        for map, list in pairs(tbl) do
            for _, sp in ipairs(list) do
                for _, id in ipairs(sp.items or {}) do add(id, map, "monster", 1) end
            end
        end
    end
end

-- best zones of an expansion for ores / herbs (most nodes first)
local function gatherZones(key, kind)
    local best = {}
    for _, g in ipairs(SFP.Gather or {}) do
        if g.exp == key and g.kind == kind and g.map then best[g.map] = (best[g.map] or 0) + (g.nodes or 1) end
    end
    local list = {}
    for m, n in pairs(best) do list[#list + 1] = { m, n } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(4, #list) do out[i] = zname(list[i][1]) end
    return out
end

local function farmZones(key)
    local exp = expByKey[key]
    local out = {}
    if exp then
        for i = 1, math.min(5, #(exp.zones or {})) do out[#out + 1] = zname(exp.zones[i].map) end
    end
    return out
end

local TAG_TEXT = { farm = "farm spot", herb = "herb", ore = "ore", monster = "monster spawn", learned = "you looted it here", quest = "quest reward" }

-- zone texts for an item: exact data first, then what its type and expansion say
local function zoneTexts(id, classID, subID, expID)
    if not zoneIdx then buildZoneIdx() end
    local out = {}
    -- items that come from a person, not from a zone
    if id == 6948 then
        out[#out + 1] = "Vendor: Innkeeper (any innkeeper, free; the one you make your home at)"
        return out
    end
    -- exact sources first: who sells it (the kind of vendor) and which monsters or nodes gave it, each with its zone. A line that is the same
    -- as one already written (the same vendor or monster recorded twice, or in the same place) is written once.
    local seenSrc = {}
    local function addSrc(text)
        if not seenSrc[text] then seenSrc[text] = true; out[#out + 1] = text; return true end
    end
    local CX = _G.SeviathsCodexDB
    local vkeys = CX and CX.vendorItems and CX.vendorItems[id]
    if vkeys and CX.vendors then
        for i = 1, #vkeys do   -- every vendor that sells it
            local v = CX.vendors[vkeys[i]]
            if v and v.n then
                local cdx = _G.SeviathsCodex
                local kind = (cdx and cdx.VendorKind and cdx:VendorKind(v)) or "Vendor"
                addSrc(("Vendor found at: %s - |cffffd100%s|r (%s)"):format(placeName(v.m, v.x, v.y), v.n, kind))
            end
        end
    end
    local drops0 = SFP.db and SFP.DropIndex and SFP:DropIndex()[id]
    -- every monster or node that gave it, each name once, with every different place it was seen at
    local order, bySrc = {}, {}
    for i = 1, math.min(400, #(drops0 or {})) do
        local d = drops0[i]
        local rec = (d[3] == "o") and SFP.db.objects[d[1]] or SFP:Npc(d[1])
        if rec and rec.n then
            local label = d[3] == "o" and "Picked up from" or (d[3] == "s" and "Skinned from" or "Dropped by")
            local key = label .. "" .. rec.n
            local s2 = bySrc[key]
            if not s2 then
                if #order >= 15 then break end
                s2 = { label = label, name = rec.n, kind = d[3], places = {}, seen = {} }
                bySrc[key] = s2
                order[#order + 1] = s2
            end
            if type(rec.m) == "table" then
                for mp, spots in pairs(rec.m) do
                    for _, sp in ipairs(type(spots) == "table" and spots or {}) do
                        local pn = placeName(mp, sp[1], sp[2], sp[3])
                        if not s2.seen[pn] and #s2.places < 5 then s2.seen[pn] = true; s2.places[#s2.places + 1] = pn end
                    end
                end
            end
        end
    end
    for _, s2 in ipairs(order) do
        local where = #s2.places > 0 and table.concat(s2.places, "; ") or nil
        local what = s2.kind == "o" and "(node or object)" or "(monster)"
        addSrc(("%s: |cffffd100%s|r %s%s"):format(s2.label, s2.name, what, where and (" - found at: " .. where) or ""))
    end
    local found = {}
    for map, e in pairs(zoneIdx[id] or {}) do found[map] = { e.tag, e.n } end
    -- zones where you saw monsters / nodes drop it
    local drops = SFP.db and SFP.DropIndex and SFP:DropIndex()[id]
    for _, d in ipairs(drops or {}) do
        local rec = (d[3] == "o") and SFP.db.objects[d[1]] or SFP:Npc(d[1])
        for map in pairs(rec and rec.m or {}) do
            local f = found[map]
            if f then f[2] = f[2] + d[2] else found[map] = { "learned", d[2] } end
        end
    end
    -- zones where you looted it or got it as a quest reward (learned by playing)
    for map, e in pairs(SFP.db and SFP.db.itemZones and SFP.db.itemZones[id] or {}) do
        local n = (e.l or 0) + (e.q or 0)
        local f = found[map]
        if f then f[2] = f[2] + n else found[map] = { (e.l or 0) >= (e.q or 0) and "learned" or "quest", n } end
    end
    local list = {}
    for map, f in pairs(found) do list[#list + 1] = { map, f[1], f[2] } end
    table.sort(list, function(a, b) return a[3] > b[3] end)
    if #list > 0 then
        local parts = {}
        for i = 1, math.min(5, #list) do
            parts[i] = zname(list[i][1]) .. " |cff808080(" .. (TAG_TEXT[list[i][2]] or list[i][2]) .. ")|r"
        end
        out[#out + 1] = "Zones: " .. table.concat(parts, ", ")
    end

    -- by type, in the zones of the item's expansion
    local key = expID and EXP_KEYS[expID]
    local exp = key and expByKey[key]
    if exp and #list == 0 then
        local en = exp.name
        local function add(prefix, zones)
            if #zones > 0 then out[#out + 1] = prefix .. " " .. table.concat(zones, ", ") .. " |cff808080(" .. en .. ")|r" end
        end
        if classID == 3 or (classID == 7 and subID == 4) then
            add("Prospected from " .. en .. " ore, mined in:", gatherZones(key, "ore"))
        elseif classID == 7 and subID == 16 then
            add("Milled from " .. en .. " herbs, found in:", gatherZones(key, "herb"))
        elseif classID == 7 and subID == 9 then
            add("Herb nodes in:", gatherZones(key, "herb"))
        elseif classID == 7 and (subID == 7 or subID == 12) then
            add("Ore veins in:", gatherZones(key, "ore"))
        elseif classID == 7 and (subID == 5 or subID == 6 or subID == 8 or subID == 10 or subID == 11) then
            local what = ({ [5] = "humanoid", [6] = "beast (skinning)", [8] = "beast", [10] = "elemental", [11] = "monster" })[subID]
            add("Dropped by " .. what .. " monsters in:", farmZones(key))
        end
    end
    return out
end

-- ---------------------------------------------------------------- where to get it
local function whereLines(id, lines, seenFromShown, zones)
    local out = {}

    -- instance bosses the game itself knows (gear with an appearance)
    if C_TransmogCollection and C_TransmogCollection.GetItemInfo then
        local _, sourceID = try(C_TransmogCollection.GetItemInfo, id)
        if sourceID then
            local drops = C_TransmogCollection.GetAppearanceSourceDrops and try(C_TransmogCollection.GetAppearanceSourceDrops, sourceID)
            if type(drops) == "table" and #drops > 0 then
                local parts = {}
                for i = 1, math.min(3, #drops) do
                    local d = drops[i]
                    local boss, inst = d.encounter or d.encounterName, d.instance or d.instanceName
                    if boss or inst then
                        parts[#parts + 1] = (boss or "?") .. (inst and (" (" .. inst .. ")") or "")
                    end
                end
                if #parts > 0 then out[#out + 1] = "Drops from: " .. table.concat(parts, ", ") end
            end
            if #out == 0 then
                local src = try(C_TransmogCollection.GetSourceInfo, sourceID)
                local t = src and SOURCE_TYPE[src.sourceType]
                if t then out[#out + 1] = "Source: " .. t end
            end
        end
    end

    -- every dungeon / raid item from the Adventure Guide
    local jl = SFP.lootIndex and SFP.lootIndex[id]
    if jl and #out == 0 then
        local parts = {}
        for i = 1, math.min(3, #jl) do
            local e = jl[i]
            parts[#parts + 1] = (e[2] ~= "" and (e[2] .. " - ") or "") .. e[1] .. (e[3] and " (raid)" or " (dungeon)")
        end
        out[#out + 1] = "Drops from: " .. table.concat(parts, "; ")
    end

    -- vendors you visited (saved by the Codex)
    local db = _G.SeviathsCodexDB
    local keys = db and db.vendorItems and db.vendorItems[id]
    if keys and #keys > 0 then
        local parts = {}
        for i = 1, math.min(3, #keys) do
            local v = db.vendors and db.vendors[keys[i]]
            if v then
                parts[#parts + 1] = v.n .. " (" .. mapName(v.m) .. ")" .. ((v.items and v.items[id]) and (" " .. v.items[id]) or "")
            end
        end
        if #parts > 0 then out[#out + 1] = "Sold by: " .. table.concat(parts, "; ") end
    end

    -- gathering nodes you opened
    local drops = SFP.db and SFP.DropIndex and SFP:DropIndex()[id]
    if drops and not seenFromShown then
        local parts = {}
        for i = 1, math.min(3, #drops) do
            local d = drops[i]
            local rec = (d[3] == "o") and SFP.db.objects[d[1]] or SFP:Npc(d[1])
            parts[#parts + 1] = ((rec and rec.n) or "?") .. (d[3] == "s" and " (skinning)" or "")
        end
        out[#out + 1] = "Dropped by: " .. table.concat(parts, ", ")
    end

    for _, z in ipairs(zones or {}) do out[#out + 1] = z end
    if #out == 0 then
        local _, _, q2, _, _, _, _, _, eq2, _, _, cl2, _, bind = C_Item.GetItemInfo(id)
        if (cl2 == 2 or cl2 == 4) and bind == 2 then
            out[#out + 1] = "Bind on Equip: a world drop, a dungeon / raid drop or crafted - buy it on the auction house"
        elseif cl2 == 7 then
            out[#out + 1] = "Crafting material: gathered, dropped by monsters or bought on the auction house"
        elseif cl2 == 15 or cl2 == 0 then
            out[#out + 1] = "Monster drop, vendor or crafted - the auction house usually has it"
        end
    end
    if #out == 0 then
        out[#out + 1] = "Source not known yet - it is learned when you loot it, see it at a vendor or open a profession"
        lines[#lines + 1] = { "|cff40ff90Where to get:|r |cff808080" .. out[1] .. "|r", 1, 1, 1, true }
        return
    end
    for i, t in ipairs(out) do
        lines[#lines + 1] = { (i == 1 and "|cff40ff90Where to get:|r " or "  ") .. t, 0.85, 0.85, 0.85, true }
    end
end

-- ---------------------------------------------------------------- how to use it
local CONSUMABLE_HINT = {
    ["Potion"] = "right-click to drink it; potions share one cooldown",
    ["Elixir"] = "right-click for a timed buff; lost when you die",
    ["Flask"] = "right-click for a long buff; kept through death",
    ["Food & Drink"] = "right-click and stay still while you eat or drink",
    ["Bandage"] = "right-click, then your target (not in combat for some)",
    ["Vantus Rune"] = "use it in the raid for a boss-specific buff",
    ["Scroll"] = "right-click for a short buff",
    ["Item Enhancement"] = "right-click, then the gear piece to apply it to",
}

local function useLines(id, lines, name, classID, subID, subtype, equip)
    local out = {}
    local spellName, spellID = try(C_Item.GetItemSpell, id)
    if classID == 9 then
        out[#out + 1] = "right-click to learn this recipe" .. (subtype and (" (" .. subtype .. ")") or "") .. "; it is used up"
    elseif classID == 0 then
        out[#out + 1] = CONSUMABLE_HINT[subtype or ""] or "consumable: right-click to use it"
    elseif classID == 1 then
        out[#out + 1] = "a bag: drag it onto a bag slot"
    elseif classID == 3 then
        out[#out + 1] = "a gem: put it in a socket of your gear (right-click it, then click the gear piece)"
    elseif classID == 8 then
        out[#out + 1] = "an enhancement: right-click, then click the gear piece"
    elseif classID == 12 then
        out[#out + 1] = "quest item: " .. (spellName and "right-click to use it for its quest" or "keep it for the quest")
    elseif classID == 16 then
        out[#out + 1] = "a glyph: right-click to learn it"
    elseif classID == 17 or (classID == 15 and subID == 2) then
        out[#out + 1] = "a battle pet: right-click to learn it (it is then in your Pet Journal)"
    elseif classID == 15 and subID == 5 then
        out[#out + 1] = "a mount: right-click to learn it (it is then in your Mount Journal)"
    elseif classID == 7 then
        -- crafting materials are covered by the "Used in" line
    elseif (classID == 2 or classID == 4) and equip and equip ~= "" then
        out[#out + 1] = "right-click to equip it (or drag it onto the slot)"
    end
    if C_ToyBox and C_ToyBox.GetToyInfo and try(C_ToyBox.GetToyInfo, id) then
        local have = _G.PlayerHasToy and try(PlayerHasToy, id)
        out[#out + 1] = "a toy: right-click to " .. (have and "use it (you already have it)" or "add it to your Toy Box")
    end
    if C_MountJournal and C_MountJournal.GetMountFromItem then
        local mountID = try(C_MountJournal.GetMountFromItem, id)
        if mountID and mountID > 0 then
            local collected = select(11, C_MountJournal.GetMountInfoByID(mountID))
            out[#out + 1] = collected and "|cff40ff40mount: you already know it|r" or "|cffffd100mount: you do not have it yet - right-click to learn|r"
        end
    end
    if spellName and classID ~= 12 and #out == 0 then
        out[#out + 1] = "right-click to use: " .. spellName
    end
    if #out == 0 then return end
    for i, t in ipairs(out) do
        lines[#lines + 1] = { (i == 1 and "|cff40d0ffHow to use:|r " or "  ") .. t, 0.85, 0.85, 0.85, true }
    end
end

function SFP:ItemInfoLines(id, lines, seenFromShown, link)
    local name, _, q, _, _, _, subtype, _, equip, _, _, classID, subID = C_Item.GetItemInfo(link or id)
    if link and C_Item.GetItemQualityByID then q = C_Item.GetItemQualityByID(link) or q end
    if not name then return end
    if q == 0 then return end -- junk: nothing to get or use
    local _, _, _, ilvl, minLvl, _, _, stack, _, _, price, _, _, bind, exp = C_Item.GetItemInfo(link or id)
    if link and C_Item.GetDetailedItemLevelInfo then ilvl = C_Item.GetDetailedItemLevelInfo(link) or ilvl end
    local bits = {}
    local BIND = { [1] = "binds when picked up", [2] = "binds when equipped", [3] = "binds when used", [4] = "quest item" }
    if bind and BIND[bind] then bits[#bits + 1] = BIND[bind] end
    if ilvl and ilvl > 1 then bits[#bits + 1] = "item level " .. ilvl end
    if minLvl and minLvl > 1 then bits[#bits + 1] = "needs level " .. minLvl end
    if stack and stack > 1 then bits[#bits + 1] = "stacks to " .. stack end
    local EXP = { [0] = "Classic", "Burning Crusade", "Wrath", "Cataclysm", "Mists", "Warlords", "Legion", "Battle for Azeroth",
        "Shadowlands", "Dragonflight", "The War Within", "Midnight" }
    if exp and EXP[exp] then bits[#bits + 1] = EXP[exp] end
    if #bits > 0 then lines[#lines + 1] = { "|cffb0b0ffInfo:|r " .. table.concat(bits, " - "), 0.8, 0.8, 0.8, true } end
    whereLines(id, lines, seenFromShown, zoneTexts(id, classID, subID, exp))
    useLines(id, lines, name, classID, subID, subtype, equip)
end

-- ---------------------------------------------------------------- learning: where you got each item
local function curMap()
    return C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
end

local function note(link, field)
    if not (SFP.db and link) or SFP.db.learnAll == false then return end
    local id = tonumber(tostring(link):match("item:(%d+)"))
    local map = curMap()
    if not (id and map) then return end
    SFP.db.itemZones = SFP.db.itemZones or {}
    local t = SFP.db.itemZones[id]
    if not t then t = {}; SFP.db.itemZones[id] = t end
    local e = t[map]
    if not e then e = {}; t[map] = e end
    e[field] = (e[field] or 0) + 1
    if SFP.RecordItem then SFP.RecordItem(id) end
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "CHAT_MSG_LOOT")
pcall(ev.RegisterEvent, ev, "QUEST_LOOT_RECEIVED")
ev:SetScript("OnEvent", function(_, event, a, b, ...)
    if event == "CHAT_MSG_LOOT" then
        local text, guid = a, select(10, ...)
        if issecretvalue and (issecretvalue(text) or issecretvalue(guid)) then return end
        if type(text) ~= "string" or guid ~= UnitGUID("player") then return end
        for link in text:gmatch("|Hitem:.-|h%[.-%]|h") do SFP:Safe("item zone", note, link, "l") end
    elseif event == "QUEST_LOOT_RECEIVED" then
        SFP:Safe("item zone", note, b, "q")
    end
end)
