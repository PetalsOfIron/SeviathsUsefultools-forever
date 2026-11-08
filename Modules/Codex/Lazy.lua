-- Seviath's Codex - pages built only for the group that is open.
--
-- The item pages (about 55,000) and the quest pages (about 37,000) made from the collected data are the biggest part of the Codex's memory.
-- Here nothing of them is built when the Codex opens. When the Items or Quests section is opened, a short pass over the data only counts
-- the pages of each group (an expansion: "The War Within", "Midnight" ...) and remembers their IDs; the list shows the groups with their
-- counts. The pages of ONE group are made when that group is expanded (a few thousand, about 2 seconds, in the background) and taken out
-- again when it is collapsed, another section is opened, or the Codex is closed. A search builds everything.

local ADDON, ns = SFP_Module("Codex")
local SFP = _G.SeviathsUsefulTools

local function budgetLoop(total, perFrameMs, fn, done)
    local i = 1
    local function step()
        local t0 = debugprofilestop()
        while i <= total and debugprofilestop() - t0 < perFrameMs do
            fn(i)
            i = i + 1
        end
        if i <= total then C_Timer.After(0, step) elseif done then done() end
    end
    step()
end

ns.lazy = {
    item = { groups = {}, built = {}, state = nil, needExp = {} },    -- state: nil = not indexed, "indexing", "ready"
    quest = { groups = {}, built = {}, state = nil },
    tmog = { groups = {}, built = {}, state = nil },   -- the transmog items of Wowhead's list (SeviathsUsefulTools_Transmog)
}

------------------------------------------------------------------------
-- indexing: which group each record belongs to (IDs only)
------------------------------------------------------------------------
local scanners = {}

scanners.quest = function(done)
    local db = ns.db
    local ids = {}
    for id in SeviathsAllPairs(db.quests or {}) do ids[#ids + 1] = id end
    local lz = ns.lazy.quest
    budgetLoop(#ids, 6, function(n)
        local id = ids[n]
        local q = db.quests[id]
        if type(q) == "table" and q.t and not ns:Get("quest:" .. id) then
            local g = (q.x and _G["EXPANSION_NAME" .. q.x]) or "Other"
            local list = lz.groups[g]
            if not list then list = {}; lz.groups[g] = list end
            list[#list + 1] = id
        end
    end, done)
end

scanners.item = function(done)
    local db = SFP and SFP.db
    if not db then if done then done() end return end
    local ids = {}
    for id in pairs(db.ahItems or {}) do ids[#ids + 1] = id end
    for id in SeviathsAllPairs(db.knownItems or {}) do ids[#ids + 1] = id end
    local lz = ns.lazy.item
    budgetLoop(#ids, 6, function(n)
        local id = ids[n]
        local r = db.knownItems and db.knownItems[id]
        local g
        if type(r) == "table" and r.n then
            if r.c == 7 then
                if ns.MaybeMaterial then pcall(ns.MaybeMaterial, ns, id, r.n) end   -- materials are few: made at once
            elseif not ns:Get("item:" .. id) then
                local ex = r.x or (db.itemExp and db.itemExp[id])
                g = ns:ItemGroupFor(id, (r.t or "Other") .. ((r.st and r.st ~= "" and r.st ~= r.t) and (" - " .. r.st) or ""), ex)
                if ex == nil then ns.lazy.item.needExp[#ns.lazy.item.needExp + 1] = id end
            end
        else
            local cls = db.ahItems and db.ahItems[id]
            local name = db.ahNames and db.ahNames[id]
            if name and cls ~= 7 and not ns:Get("item:" .. id) then
                g = ns:ItemGroupFor(id, GetItemClassInfo and GetItemClassInfo(cls) or "Other")
            end
        end
        if g then
            local list = lz.groups[g]
            if not list then list = {}; lz.groups[g] = list end
            list[#list + 1] = id
        end
    end, function()
        -- then the items of Wowhead's lists (materials, consumables, containers ...) that the player has no record of: Expansion > Type > Subtype
        local blocks = SFP and SFP.ItemBlocks and SFP:ItemBlocks()
        if not blocks then if done then done() end return end
        local keys = {}
        for k in pairs(blocks) do keys[#keys + 1] = k end
        local db = SFP.db
        budgetLoop(#keys, 6, function(n)
            for line in blocks[keys[n]]:gmatch("[^\n]+") do
                local r = SFP.ItemParseLine(line)
                if r and r.quality ~= 0 and not (db and db.knownItems and db.knownItems[r.id]) and not ns:Get("item:" .. r.id) then
                    local exp = (r.tag == "f" and "WoW Forever") or (r.exp and _G["EXPANSION_NAME" .. r.exp]) or "No expansion set yet"
                    local cn = (r.class and GetItemClassInfo and GetItemClassInfo(r.class)) or "Other"
                    local sn = (r.class and r.sub and GetItemSubClassInfo and GetItemSubClassInfo(r.class, r.sub)) or nil
                    local g2 = exp .. " > " .. cn .. ((sn and sn ~= "" and sn ~= cn) and (" > " .. sn) or "")
                    local list = lz.groups[g2]
                    if not list then list = {}; lz.groups[g2] = list end
                    list[#list + 1] = r.id
                end
            end
        end, done)
    end)
end

-- every transmog item, grouped Source > Type > Slot > Quality (the group is a path: the Codex opens each part on its own)
local QUALITY = { [0] = "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Heirloom" }
scanners.tmog = function(done)
    local blocks = SFP and SFP.TransmogBlocks and SFP:TransmogBlocks()
    if not blocks then if done then done() end return end
    local keys = {}
    for k in pairs(blocks) do keys[#keys + 1] = k end
    local lz = ns.lazy.tmog
    budgetLoop(#keys, 6, function(n)
        for line in blocks[keys[n]]:gmatch("[^\n]+") do
            local r = SFP.TransmogParseLine(line)
            if r then
                local g = (r.source or "Other") .. " > " .. (r.type or "Other") .. " > " .. (r.slot or "Other") .. " > " .. (QUALITY[r.quality] or "Other")
                local list = lz.groups[g]
                if not list then list = {}; lz.groups[g] = list end
                list[#list + 1] = r.id
            end
        end
    end, done)
end

function ns:LazyIndex(cat, done)
    local lz = self.lazy[cat]
    if not lz or not scanners[cat] then if done then done() end return end
    if lz.state == "ready" then if done then done() end return end
    if lz.state == "indexing" then
        lz.waiting = lz.waiting or {}
        if done then lz.waiting[#lz.waiting + 1] = done end
        return
    end
    lz.state = "indexing"
    lz.waiting = { done }
    scanners[cat](function()
        lz.state = "ready"
        local w = lz.waiting or {}
        lz.waiting = nil
        for _, fn in ipairs(w) do pcall(fn) end
        if ns.RefreshList then pcall(ns.RefreshList, ns, true) end
    end)
end

------------------------------------------------------------------------
-- making and removing the pages of one group
------------------------------------------------------------------------
local makers = {}

makers.quest = function(id)
    local q = ns.db.quests[id]
    if type(q) == "table" and q.t and ns.AddQuestEntry then ns.AddQuestEntry(id, q) end
end

makers.item = function(id)
    local db = SFP.db
    local r = db.knownItems and db.knownItems[id]
    if type(r) == "table" and r.n then
        if not ns:Get("item:" .. id) then
            ns:Add({ cat = "item", id = id, name = r.n,
                group = ns:ItemGroupFor(id, (r.t or "Other") .. ((r.st and r.st ~= "" and r.st ~= r.t) and (" - " .. r.st) or ""), r.x or (db.itemExp and db.itemExp[id])),
                icon = C_Item.GetItemIconByID(id), itemID = id, wh = "item=" .. id,
                sub = (r.t or "") .. ((r.st and r.st ~= "") and (" - " .. r.st) or "") .. ((r.i and r.i > 0) and ("  item level " .. r.i) or ""),
                lazy = true })
        end
    else
        local cls = db.ahItems and db.ahItems[id]
        local name = db.ahNames and db.ahNames[id]
        if name and not ns:Get("item:" .. id) then
            local cn = GetItemClassInfo and GetItemClassInfo(cls) or "Other"
            ns:Add({ cat = "item", id = id, name = name, group = ns:ItemGroupFor(id, cn), icon = C_Item.GetItemIconByID(id),
                itemID = id, wh = "item=" .. id, sub = cn, lazy = true })
        elseif not name and not ns:Get("item:" .. id) then
            -- an item of Wowhead's lists
            local r = SFP.ShippedItem and SFP:ShippedItem(id)
            if r then
                local exp = (r.tag == "f" and "WoW Forever") or (r.exp and _G["EXPANSION_NAME" .. r.exp]) or "No expansion set yet"
                local cn = (r.class and GetItemClassInfo and GetItemClassInfo(r.class)) or "Other"
                local sn = (r.class and r.sub and GetItemSubClassInfo and GetItemSubClassInfo(r.class, r.sub)) or nil
                ns:Add({ cat = "item", id = id, name = r.name, itemID = id, wh = "item=" .. id, lazy = true, icon = C_Item.GetItemIconByID(id),
                    group = exp .. " > " .. cn .. ((sn and sn ~= "" and sn ~= cn) and (" > " .. sn) or ""),
                    sub = cn .. ((sn and sn ~= "" and sn ~= cn) and (" - " .. sn) or "") .. ((r.level and r.level > 1) and ("  item level " .. r.level) or "") })
            end
        end
    end
end

makers.tmog = function(id)
    local r = SFP:TransmogItem(id)
    if not r or ns:Get("tmog:" .. id) then return end
    local sub = {}
    if r.type or r.slot then sub[#sub + 1] = (r.type or "") .. ((r.type and r.slot) and " " or "") .. (r.slot or "") end
    sub[#sub + 1] = r.source .. (r.sourceName and (": " .. r.sourceName) or "")
    local have
    if C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog then
        local ok, h = pcall(C_TransmogCollection.PlayerHasTransmog, id)
        if ok and type(h) == "boolean" then have = h end
    end
    ns:Add({ cat = "tmog", id = id, name = r.name, itemID = id, wh = "item=" .. id, lazy = true, icon = C_Item.GetItemIconByID(id), collected = have,
        group = (r.source or "Other") .. " > " .. (r.type or "Other") .. " > " .. (r.slot or "Other") .. " > " .. (QUALITY[r.quality] or "Other"),
        sub = table.concat(sub, "  ") })
end

-- a transmog collected now: its page (when it is built) is marked collected and shows where it came from; the loot record (monster, place, weapon
-- or armor) is the one the addon already keeps when you loot, so the page reads it at once
local tmogFrame = CreateFrame("Frame")
pcall(tmogFrame.RegisterEvent, tmogFrame, "TRANSMOG_COLLECTION_SOURCE_ADDED")
tmogFrame:SetScript("OnEvent", function(_, _, sourceID)
    local ok, info = pcall(function() return C_TransmogCollection.GetSourceInfo(sourceID) end)
    local itemID = ok and type(info) == "table" and info.itemID
    if not itemID then return end
    for _, key in ipairs({ "tmog:" .. itemID, "item:" .. itemID }) do
        local e = ns:Get(key)
        if e then e.collected = true end
    end
    if ns.IsOpen and ns:IsOpen() and ns.RefreshList then pcall(ns.RefreshList, ns, true) end
end)

function ns:BuildLazyGroup(cat, group, done)
    local lz = self.lazy[cat]
    local list = lz and lz.groups[group]
    if not list or lz.built[group] or lz.building and lz.building[group] then if done then done() end return end
    lz.building = lz.building or {}
    lz.building[group] = true
    budgetLoop(#list, 8, function(n) pcall(makers[cat], list[n]) end, function()
        lz.building[group] = nil
        lz.built[group] = true
        if ns.RefreshList then pcall(ns.RefreshList, ns, true) end
        if done then done() end
    end)
end

function ns:UnloadLazyGroup(cat, group)
    local lz = self.lazy[cat]
    if not lz or not lz.built[group] then return end
    lz.built[group] = nil
    self:UnloadLazy({ cat }, group)
end

function ns:BuildAllLazy(cat)
    local lz = self.lazy[cat]
    if not lz then return end
    local names = {}
    for g in pairs(lz.groups) do names[#names + 1] = g end
    local i = 0
    local function nextGroup()
        i = i + 1
        if names[i] then ns:BuildLazyGroup(cat, names[i], nextGroup) end
    end
    nextGroup()
end

-- everything of a section out of memory again (also the group lists): made again the next time that section is opened
function ns:UnloadAllLazy(cat)
    local lz = self.lazy[cat]
    if not lz or (lz.state == nil and next(lz.built) == nil) then return end
    self:UnloadLazy({ cat })
    lz.groups, lz.built, lz.building, lz.state, lz.waiting = {}, {}, nil, nil, nil
end

-- the number of pages of a group that are not built yet (for the count of its header)
function ns:LazyPending(cat, group)
    local lz = self.lazy[cat]
    if not lz or lz.built[group] then return 0 end
    local list = lz.groups[group]
    return list and #list or 0
end

------------------------------------------------------------------------
-- Items whose expansion is not known yet (they sit under their type, e.g. "Armor - Cloth") are asked from the game, a few each second,
-- while the Codex is open; the answer is kept in db.itemExp, so the next time the section opens they are in their expansion.
------------------------------------------------------------------------
local pendingExp = {}
local expFrame = CreateFrame("Frame")
expFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
expFrame:SetScript("OnEvent", function(_, _, itemID)
    if not pendingExp[itemID] then return end
    pendingExp[itemID] = nil
    local ok, x = pcall(function() return select(15, C_Item.GetItemInfo(itemID)) end)
    if ok and type(x) == "number" and SFP and SFP.db then
        SFP.db.itemExp = SFP.db.itemExp or {}
        SFP.db.itemExp[itemID] = x
    end
end)

C_Timer.NewTicker(1, function()
    local lz = ns.lazy and ns.lazy.item
    if not lz or lz.state ~= "ready" or #lz.needExp == 0 then return end
    if not (ns.IsOpen and ns:IsOpen()) then return end
    for _ = 1, 60 do
        local id = table.remove(lz.needExp)
        if not id then break end
        local ok, x = pcall(function() return select(15, C_Item.GetItemInfo(id)) end)
        if ok and type(x) == "number" and SFP and SFP.db then
            SFP.db.itemExp = SFP.db.itemExp or {}
            SFP.db.itemExp[id] = x
        else
            pendingExp[id] = true
            if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        end
    end
end)
