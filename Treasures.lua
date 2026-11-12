-- SeviathsUsefulTools - treasures on the world map
--
-- Every treasure chest, cache or skull you open is recorded with what it gave (Collector.lua: SFP.db.objects). Here each of them is a very small box on the world
-- map at the place you opened it; hover the box to see the loot, each item with its chance (the same lines as the tooltip of the chest itself). The minimap
-- already shows treasures in the game, so there are no boxes there.

local _, SFP = ...

local SIZE = 9            -- screen pixels of the dot
local pins, used = {}, 0
local byMapTime = {}
local byMap = {}          -- [map] = list of { id, rec, x, y }: made when a map is asked for, dropped when the loot changes
local layer

local function canvas()
    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    return sc and sc.Child
end

local function canvasScale()
    local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
    return (sc and sc.GetCanvasScale and sc:GetCanvasScale()) or 1
end

-- a place recorded on map `from`, as a place on map `to` (the chest was opened on a part of the zone, the map shown may be the whole zone or the continent)
local function convert(from, x, y, to)
    if from == to then return x, y end
    if not (C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return end
    local ok, cont, wp = pcall(C_Map.GetWorldPosFromMapPos, from, CreateVector2D(x, y))
    if not ok or not cont or not wp then return end
    local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, wp, to)   -- it returns the map id, then the position
    if not ok2 or type(pos) ~= "table" or not pos.GetXY then return end
    local tx, ty = pos:GetXY()
    if type(tx) == "number" and type(ty) == "number" and tx >= 0 and tx <= 1 and ty >= 0 and ty <= 1 then return tx, ty end
end

-- a treasure: an object the game showed as a loot icon where you opened it (rec.tr, set by the Collector). Objects recorded before that was noted count when they
-- look like one: a name, opened once or twice, not a quest objective, not a gathering node
local npcNames, npcNamesAt
local function isMobName(n)
    -- an "object" that carries the name of a monster is a monster's corpse, not a treasure
    if type(n) ~= "string" then return false end
    local npcs = SFP.db and SFP.db.npcs
    if not npcs then return false end
    if not npcNames or (npcNamesAt or 0) < time() - 300 then
        npcNames, npcNamesAt = {}, time()
        for _, r in (SeviathsAllPairs or pairs)(npcs) do
            if type(r) == "table" and type(r.n) == "string" then npcNames[r.n] = true end
        end
    end
    return npcNames[n] == true
end

local function isTreasure(rec)
    if type(rec) ~= "table" or type(rec.d) ~= "table" or not next(rec.d) or type(rec.m) ~= "table" then return false end
    if isMobName(rec.n) then return false end
    if (rec.k or 0) < 1 then return false end
    if rec.qs and next(rec.qs) then return false end
    if rec.ot then return false end   -- a quest objective or a gathering node has its type text saved
    if SFP.ObjectKind and SFP:ObjectKind({ d = rec.d }) then return false end   -- the kind by its items only
    if rec.tr then return true end   -- the game showed it as a loot icon: a treasure, whatever it gave
    if WOW_PROJECT_ID and WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then
        -- WoW Forever shows no loot icons for chests (the game's vignettes are not there), so rec.tr is never set: a chest is known by its name instead. Crates,
        -- barrels and quest objects (rec.ot, saved above) stay out.
        local n = type(rec.n) == "string" and rec.n:lower() or ""
        for _, w in ipairs({ "chest", "cache", "coffer", "strongbox", "lockbox", "footlocker", "treasure", "trove", "stash", "hoard", "satchel", "sack", "bag", "lockbox" }) do
            if n:find(w, 1, true) then return true end
        end
        return false
    end
    if (rec.k or 0) > 2 then return false end
    if not (type(rec.n) == "string" and not rec.n:find("^Object %d+$") and not rec.n:find("Seviath", 1, true)) then return false end
    -- the clues and objects of quest lines give quest items; a treasure gives ordinary items
    for itemID in pairs(rec.d) do
        local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok and classID == 12 then return false end
    end
    return true
end

-- the treasures recorded for one map (made when the map is asked for, dropped when the loot changes)
-- what THIS character has opened (per character, like the rare scanner): { [objectID] = { { map, x, y }, ... } }; the box of an opened treasure is not shown
-- for this character, the characters that did not open it still see it
local function openedList()
    SeviathsGuildHelperCharDB = SeviathsGuildHelperCharDB or {}
    SeviathsGuildHelperCharDB.openedTreasures = SeviathsGuildHelperCharDB.openedTreasures or {}
    return SeviathsGuildHelperCharDB.openedTreasures
end

function SFP.NoteOpened(id, map, x, y)
    local list = openedList()
    list[id] = list[id] or {}
    local now = time()
    for _, o in ipairs(list[id]) do
        if o[1] == map and math.abs(o[2] - x) < 0.02 and math.abs(o[3] - y) < 0.02 then
            -- opened again at the same place: it respawns, after about the shortest time seen between two openings (a day until two openings are known)
            if o[4] and now - o[4] > 60 then
                o[5] = math.min(o[5] or (now - o[4]), now - o[4])
                -- the chest itself learns it: the respawn time is kept with the chest (shipped with the addon), so every character and player uses it
                local rec = SFP.db and SFP.db.objects and SFP.db.objects[id]
                if type(rec) == "table" then rec.rs = math.min(rec.rs or o[5], o[5]) end
            elseif not o[4] then o[5] = 86400 end
            o[4] = now
            wipe(byMap)
            return
        end
    end
    list[id][#list[id] + 1] = { map, x, y, now }
    wipe(byMap)
end

local function openedHere(id, map, x, y)
    local mine = openedList()[id]
    if not mine then return false end
    for _, o in ipairs(mine) do
        local ox, oy = nil, nil
        local rec = SFP.db and SFP.db.objects and SFP.db.objects[id]
        local iv = math.min(o[5] or math.huge, type(rec) == "table" and tonumber(rec.rs) or math.huge)   -- this character's own time, or the one learned by everybody
        if not (iv < math.huge and o[4] and time() - o[4] >= iv) then ox, oy = convert(o[1], o[2], o[3], map) end   -- one that respawns is back after its time
        if ox and math.abs(ox - x) < 0.02 and math.abs(oy - y) < 0.02 then return true end
    end
    return false
end

-- the first character that logs in after the lists were made per character is the one that opened all the chests recorded so far: they count as opened for it
-- (the other characters start with an empty list and still see them)
local function seedOpened()
    if not (SFP.db and SFP.db.objects) or SFP.db.treasuresSeeded then return end
    SFP.db.treasuresSeeded = true
    local list = openedList()
    local now = time()
    for id, rec in (SeviathsAllPairs or pairs)(SFP.db.objects) do
        if type(id) == "number" and isTreasure(rec) then
            for from, pts in pairs(rec.m) do
                if type(pts) == "table" and type(from) == "number" then
                    for _, p in ipairs(pts) do
                        if type(p) == "table" and p[1] and p[2] then
                            list[id] = list[id] or {}
                            list[id][#list[id] + 1] = { from, p[1], p[2] }   -- no time: when it is opened again it counts as respawning
                        end
                    end
                end
            end
        end
    end
    wipe(byMap)
end

local function treasuresOf(map)
    local list = byMap[map]
    if list and (byMapTime[map] or 0) > time() - 120 then return list end
    list = {}
    byMapTime[map] = time()
    local objects = SFP.db and SFP.db.objects
    if objects then
        for id, rec in (SeviathsAllPairs or pairs)(objects) do
            if type(id) == "number" and isTreasure(rec) then
                for from, pts in pairs(rec.m) do
                    if type(pts) == "table" and type(from) == "number" then
                        for _, p in ipairs(pts) do
                            if type(p) == "table" and p[1] and p[2] then
                                local x, y = convert(from, p[1], p[2], map)
                                if x then list[#list + 1] = { id = id, rec = rec, x = x, y = y } end   -- (also the chests you opened: "all chests"; they are not taken off the map)
                            end
                        end
                    end
                end
            end
        end
    end
    -- treasures at the same spot are one pin: their loot is put together
    local merged = {}
    for _, t in ipairs(list) do
        local into
        for _, m in ipairs(merged) do
            if math.abs(m.x - t.x) < 0.01 and math.abs(m.y - t.y) < 0.01 then into = m break end
        end
        if not into then
            into = { id = t.id, x = t.x, y = t.y, rec = { n = t.rec.n, k = 0, d = {}, q = {}, ids = {}, count = 0 } }
            merged[#merged + 1] = into
        end
        local r, tr = t.rec, into.rec
        if not tr.ids[t.id] then
            tr.ids[t.id] = true
            tr.count = tr.count + 1
            tr.k = tr.k + (r.k or 0)
            for item, c in pairs(r.d or {}) do tr.d[item] = (tr.d[item] or 0) + c end
            for item, qr in pairs(r.q or {}) do
                local e = tr.q[item]
                if type(qr) == "table" and type(qr[1]) == "number" and type(qr[2]) == "number" then
                    if not e then tr.q[item] = { qr[1], qr[2] }
                    else e[1] = math.min(e[1], qr[1]); e[2] = math.max(e[2], qr[2]) end
                end
            end
            if tr.count > 1 and r.n and tr.n ~= r.n then tr.n = tr.n .. " / " .. r.n end
        end
    end
    byMap[map] = merged
    return merged
end

-- the recorded herb and ore nodes: an object that gave something and is a gathering node (rec.gt "herb" or "ore", else by what it gave or its type text)
local function nodeKind(rec)
    if type(rec) ~= "table" or type(rec.d) ~= "table" or not next(rec.d) or type(rec.m) ~= "table" or (rec.k or 0) < 1 then return nil end
    if rec.gt == "herb" or rec.gt == "ore" then return rec.gt end
    local k = SFP.ObjectKind and SFP:ObjectKind(rec)
    local lk = type(k) == "string" and k:lower() or ""
    if lk:find("herb", 1, true) then return "herb" end
    if lk:find("min", 1, true) or lk:find("ore", 1, true) then return "ore" end
end

local byMapNodes = {}
local function nodesOf(map)
    local list = byMapNodes[map]
    if list then return list end
    list = {}
    local objects = SFP.db and SFP.db.objects
    if objects then
        for id, rec in (SeviathsAllPairs or pairs)(objects) do
            local kind = type(id) == "number" and nodeKind(rec)
            if kind then
                for from, pts in pairs(rec.m) do
                    if type(pts) == "table" and type(from) == "number" then
                        for _, p in ipairs(pts) do
                            if type(p) == "table" and p[1] and p[2] then
                                local x, y = convert(from, p[1], p[2], map)
                                if x then list[#list + 1] = { id = id, rec = rec, x = x, y = y, kind = kind } end
                            end
                        end
                    end
                end
            end
        end
    end
    -- nodes of the same kind close together are one place: their loot is put together (other ores or herbs gathered from the same spot)
    local merged = {}
    for _, n in ipairs(list) do
        local into
        for _, m in ipairs(merged) do
            if m.kind == n.kind and math.abs(m.x - n.x) < 0.01 and math.abs(m.y - n.y) < 0.01 then into = m break end
        end
        if not into then
            into = { id = n.id, x = n.x, y = n.y, kind = n.kind, rec = { n = n.rec.n, k = 0, d = {}, q = {}, ids = {} } }
            merged[#merged + 1] = into
        end
        local r, t = n.rec, into.rec
        if not t.ids[n.id] then
            t.ids[n.id] = true
            t.k = t.k + (r.k or 0)
            for item, c in pairs(r.d) do t.d[item] = (t.d[item] or 0) + c end
            for item, qr in pairs(r.q or {}) do
                local e = t.q[item]
                if type(qr) == "table" and type(qr[1]) == "number" and type(qr[2]) == "number" then
                    if not e then t.q[item] = { qr[1], qr[2] }
                    else e[1] = math.min(e[1], qr[1]); e[2] = math.max(e[2], qr[2]) end
                end
            end
        end
    end
    byMapNodes[map] = merged
    return merged
end

local npins, nused = {}, 0
local function getNodePin()
    nused = nused + 1
    local p = npins[nused]
    if not p then
        p = CreateFrame("Button", nil, layer)
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetAllPoints()
        p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        p:SetScript("OnEnter", function(self)
            local t = SFP.Tip and SFP.Tip() or GameTooltip
            t:SetOwner(self, "ANCHOR_RIGHT")
            t:ClearLines()
            t:AddLine(tostring(self.rec.n or ("Node " .. tostring(self.id))), 0.4, 1, 0.55)
            t:AddLine(self.kind == "herb" and "Herb node" or "Mining node", 0.7, 0.7, 0.7)
            if SFP.ObjectLootLines then SFP.ObjectLootLines(t, self.rec) end
            t:Show()
        end)
        p:SetScript("OnLeave", function() (SFP.Tip and SFP.Tip() or GameTooltip):Hide() end)
        npins[nused] = p
    end
    p:Show()
    return p
end

local function getPin()
    used = used + 1
    local p = pins[used]
    if not p then
        p = CreateFrame("Button", nil, layer)
        -- a round blue dot with a pale ring: easy to find on the map (the grey dot picture of the game, painted blue)
        p.edge = p:CreateTexture(nil, "BACKGROUND")
        p.edge:SetPoint("TOPLEFT", -1.5, 1.5)
        p.edge:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
        p.edge:SetTexture("Interface\\COMMON\\Indicator-Gray")
        p.edge:SetVertexColor(0.85, 0.93, 1, 0.95)
        p.fill = p:CreateTexture(nil, "ARTWORK")
        p.fill:SetAllPoints()
        p.fill:SetTexture("Interface\\COMMON\\Indicator-Gray")
        p.fill:SetVertexColor(0.12, 0.45, 1, 1)
        p:SetScript("OnEnter", function(self)
            local t = SFP.Tip and SFP.Tip() or GameTooltip
            t:SetOwner(self, "ANCHOR_RIGHT")
            t:ClearLines()
            t:AddLine(tostring(self.rec.n or ("Treasure " .. tostring(self.id))), 0.9, 0.28, 0.24)
            if SFP.ObjectLootLines then SFP.ObjectLootLines(t, self.rec) end
            t:Show()
        end)
        p:SetScript("OnLeave", function() (SFP.Tip and SFP.Tip() or GameTooltip):Hide() end)
        pins[used] = p
    end
    p:Show()
    return p
end


-- the picture of a service pin by what it is
local SERVICE_ICONS = {
    { "auction", "Interface\\Icons\\INV_Misc_Coin_02" }, { "bank", "Interface\\Icons\\INV_Misc_Bag_10" },
    { "alchemy", "Interface\\Icons\\Trade_Alchemy" }, { "blacksmith", "Interface\\Icons\\Trade_BlackSmithing" }, { "enchant", "Interface\\Icons\\Trade_Engraving" },
    { "engineer", "Interface\\Icons\\Trade_Engineering" }, { "inscription", "Interface\\Icons\\INV_Inscription_Tradeskill01" }, { "jewelcraft", "Interface\\Icons\\INV_Misc_Gem_01" },
    { "leatherwork", "Interface\\Icons\\Trade_LeatherWorking" }, { "tailor", "Interface\\Icons\\Trade_Tailoring" }, { "herbalism", "Interface\\Icons\\Trade_Herbalism" },
    { "mining", "Interface\\Icons\\Trade_Mining" }, { "skinning", "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" }, { "cooking", "Interface\\Icons\\INV_Misc_Food_15" },
    { "fishing", "Interface\\Icons\\Trade_Fishing" }, { "first aid", "Interface\\Icons\\Spell_Holy_SealOfSacrifice" }, { "archaeology", "Interface\\Icons\\Trade_Archaeology" },
}
local AUCTION_ICON = SERVICE_ICONS[1][2]
local function serviceIcon(what)
    local low = tostring(what or ""):lower()
    for _, e in ipairs(SERVICE_ICONS) do
        if low:find(e[1], 1, true) then return e[2] end
    end
    return "Interface\\Icons\\INV_Misc_Book_09"
end

-- the points of interest of the map itself (the game lists the Auction House and the profession trainers of a city): pins for them even when you never visited them
local poiCache = {}
local function poiServices(map)
    local c = poiCache[map]
    if c and c.t > time() - 60 then return c.list end
    local list = {}
    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo then
        local okL, ids = pcall(C_AreaPoiInfo.GetAreaPOIForMap, map)
        for _, pid in ipairs(okL and type(ids) == "table" and ids or {}) do
            local okI, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, map, pid)
            if okI and type(info) == "table" and type(info.name) == "string" and info.position and info.position.GetXY then
                local low = info.name:lower()
                local what
                if low:find("auction house", 1, true) then what = "Auction house"
                elseif low:find("bank", 1, true) and not low:find("banker's", 1, true) then what = "Bank"
                elseif low:find("trainer", 1, true) then
                    for _, prof in ipairs(SFP.PROFESSION_WORDS or {}) do
                        if low:find(prof, 1, true) then what = info.name break end
                    end
                end
                if what then
                    local x, y = info.position:GetXY()
                    list[#list + 1] = { n = info.name, x = x, y = y, what = what }
                end
            end
        end
    end
    poiCache[map] = { t = time(), list = list }
    return list
end

local spins, sused = {}, 0
local function getServicePin()
    sused = sused + 1
    local p = spins[sused]
    if not p then
        p = CreateFrame("Button", nil, layer)
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetAllPoints()
        p:SetScript("OnEnter", function(self)
            local t = SFP.Tip and SFP.Tip() or GameTooltip
            t:SetOwner(self, "ANCHOR_RIGHT")
            t:ClearLines()
            t:AddLine(tostring(self.what or self.name or "?"), 1, 0.82, 0.2)
            if self.name and self.name ~= self.what then t:AddLine(tostring(self.name), 0.75, 0.75, 0.75) end
            if self.note then t:AddLine(self.note, 0.55, 0.55, 0.55) end
            t:Show()
        end)
        p:SetScript("OnLeave", function() (SFP.Tip and SFP.Tip() or GameTooltip):Hide() end)
        spins[sused] = p
    end
    p:Show()
    return p
end

local function update()
    if not layer then return end
    for i = 1, #spins do spins[i]:Hide() end
    sused = 0
    for i = 1, #pins do pins[i]:Hide() end
    for i = 1, #npins do npins[i]:Hide() end
    used, nused = 0, 0
    if not (WorldMapFrame and WorldMapFrame:IsShown()) or not SFP.db then return end
    local c = canvas()
    local map = WorldMapFrame:GetMapID()
    if not (c and map) then return end
    -- only on the map of a zone (or smaller): not on the continent, the world or the cosmic map
    local info = C_Map.GetMapInfo(map)
    if info and type(info.mapType) == "number" and info.mapType < (Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3) then return end
    local w, h = c:GetWidth(), c:GetHeight()
    if not w or w <= 0 then return end
    local size = math.max(SIZE / canvasScale(), 3)
    local hidden = SFP.db and SFP.db.hiddenTreasures
    for _, t in ipairs(SFP.db.showTreasures ~= false and treasuresOf(map) or {}) do
      if not (hidden and hidden[t.id]) then
        local p = getPin()
        p:SetSize(size, size)
        p:ClearAllPoints()
        p:SetPoint("CENTER", c, "TOPLEFT", t.x * w, -t.y * h)
        p.id, p.rec = t.id, t.rec
      end
    end
    -- services: auction houses, bankers and trainers (the points of interest of the map first, then the NPCs you spoke to or pointed at). Small icons; a hover says what it is.
    do
        local have = {}
        local ssize = math.max(size * 1.15, 6)
        local function put(x, y, name, what, icon, note)
            local p = getServicePin()
            p:SetSize(ssize, ssize)
            p:ClearAllPoints()
            p:SetPoint("CENTER", c, "TOPLEFT", x * w, -y * h)
            p.name, p.what, p.note = name, what, note
            p.icon:SetTexture(icon)
            p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            have[#have + 1] = { x = x, y = y, icon = icon }
        end
        local function near(x, y, icon)
            for _, e in ipairs(have) do
                if e.icon == icon and math.abs(e.x - x) < (icon == AUCTION_ICON and 0.04 or 0.012) and math.abs(e.y - y) < (icon == AUCTION_ICON and 0.04 or 0.012) then return true end
            end
            return false
        end
        if SFP.db.showServices ~= false then
            for _, e in ipairs(poiServices(map)) do
                put(e.x, e.y, e.n, e.what, serviceIcon(e.what), "Shown by the map of the game")
            end
            -- the trainers, bankers and auctioneers of the game's data (Data/ServicePins.lua, WoW Forever), of your side
            local mine = UnitFactionGroup and UnitFactionGroup("player")
            for _, e in ipairs((SFP.ServicePins and SFP.ServicePins[map]) or {}) do
                local f = e[6]
                if not (f and f ~= "" and mine and not f:find(mine:sub(1, 1), 1, true)) and not near(e[3], e[4], serviceIcon(e[1])) then
                    put(e[3], e[4], e[5], e[1], serviceIcon(e[1]), nil)
                end
            end
            -- where the game data (Data/ServicePins.lua) knows the services, only it is used: the places you spoke to an NPC from are not the places of the NPCs
            if SFP.db.npcPos and not SFP.ServicePins then
                for id, r in pairs(SFP.db.npcPos) do
                    local what
                    local k = r.k
                    if k and k.auctioneer then what = "Auction house"
                    elseif k and k.banker then what = "Bank"
                    elseif k and k.proftrainer then what = r.prof or "Profession trainer"
                    end
                    if what and type(r.m) == "number" and r.x and r.y then
                        local x, y = convert(r.m, r.x, r.y, map)
                        if x and not near(x, y, serviceIcon(what)) then
                            put(x, y, r.n, what, serviceIcon(what), "You spoke to this NPC")
                        end
                    end
                end
            end
        end
    end
    -- the herb and ore nodes (the switches are the Herbalism and Mining ones of the map layers)
    local showH, showO = SFP.db and SFP.db.showHerbs, SFP.db and SFP.db.showMining
    if showH or showO then
        for _, n in ipairs(nodesOf(map)) do
            if (n.kind == "herb" and showH) or (n.kind == "ore" and showO) then
                local p = getNodePin()
                p:SetSize(size * 1.3, size * 1.3)
                p:ClearAllPoints()
                p:SetPoint("CENTER", c, "TOPLEFT", n.x * w, -n.y * h)
                p.id, p.rec, p.kind = n.id, n.rec, n.kind
                p.icon:SetTexture(SFP.KindIcon and SFP.KindIcon[n.kind] or (n.kind == "ore" and "Interface\\Icons\\INV_Ore_Copper_01" or "Interface\\Icons\\INV_Misc_Herb_01"))
            end
        end
    end
end

-- /treasures: what the boxes are made from (for when none show): the objects recorded, how many gave loot, how many are treasures, how many are on this map
SLASH_SEVIATHSTREASURES1 = "/treasures"
SlashCmdList["SEVIATHSTREASURES"] = function()
    local objects = SFP.db and SFP.db.objects
    local total, loot, tre, why = 0, 0, 0, { quest = 0, gather = 0, qitem = 0, nokill = 0, nomap = 0 }
    for id, rec in (SeviathsAllPairs or pairs)(objects or {}) do
        total = total + 1
        if type(rec) == "table" and type(rec.d) == "table" and next(rec.d) then
            loot = loot + 1
            if type(rec.m) ~= "table" then why.nomap = why.nomap + 1
            elseif (rec.k or 0) < 1 then why.nokill = why.nokill + 1
            elseif rec.qs and next(rec.qs) then why.quest = why.quest + 1
            elseif SFP.ObjectKind and SFP:ObjectKind({ d = rec.d }) then why.gather = why.gather + 1
            elseif isTreasure(rec) then tre = tre + 1
            else why.qitem = why.qitem + 1 end
        end
    end
    local map = WorldMapFrame and WorldMapFrame:GetMapID()
    byMap = {}
    local onMap = map and #treasuresOf(map) or 0
    SFP:Print(("treasures: %d objects recorded, %d gave loot, %d are treasures (left out: %d quest, %d gathering, %d quest item, %d no place)"):format(
        total, loot, tre, why.quest, why.gather, why.qitem, why.nomap))
    SFP:Print(("treasures on the map shown (%s): %d; boxes on the map: %d; layer: %s; show treasures: %s"):format(
        tostring(map), onMap, used, layer and "yes" or "NO", tostring(SFP.db and SFP.db.showTreasures ~= false)))
    local c = canvas()
    if c then SFP:Print(("canvas %.0f x %.0f, scale %.2f, level %d, strata %s; layer level %d, shown %s"):format(c:GetWidth() or 0, c:GetHeight() or 0, canvasScale(),
        c:GetFrameLevel() or 0, tostring(c:GetFrameStrata()), layer and layer:GetFrameLevel() or -1, tostring(layer and layer:IsShown()))) end
    local p = pins[1]
    if p then
        local pt, rel, rp, x, y = p:GetPoint()
        SFP:Print(("box 1: %s at %.1f, %.1f of %s; size %.1f; shown %s, visible %s, alpha %.2f, level %d, mouse %s; place %.3f, %.3f"):format(
            tostring(p.rec and p.rec.n), x or 0, y or 0, tostring(rp), p:GetWidth() or 0, tostring(p:IsShown()), tostring(p:IsVisible()), p:GetEffectiveAlpha() or 0,
            p:GetFrameLevel() or 0, tostring(p:IsMouseEnabled()), byMap[map] and byMap[map][1] and byMap[map][1].x or -1, byMap[map] and byMap[map][1] and byMap[map][1].y or -1))
    end
end

-- for the points menu: the treasures of a map, one entry for each treasure (an object with several places counts once)
function SFP.TreasuresOfMap(map)
    local seen, out = {}, {}
    for _, t in ipairs(treasuresOf(map)) do
        if not seen[t.id] then seen[t.id] = true; out[#out + 1] = t end
    end
    table.sort(out, function(a, b) return tostring(a.rec.n) < tostring(b.rec.n) end)
    return out
end

function SFP.RefreshTreasures()
    if WorldMapFrame and WorldMapFrame:IsShown() then update() end
end

SFP:OnLogin(function()
    if not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
    local c = canvas()
    if not c then return end
    C_Timer.After(8, function() SFP:Safe("treasures seed", seedOpened); if WorldMapFrame:IsShown() then update() end end)
    layer = CreateFrame("Frame", nil, c)
    layer:SetAllPoints(c)
    layer:SetFrameLevel(math.min((c:GetFrameLevel() or 0) + 3500, 9000))   -- above the map's own icons
    layer:EnableMouse(false)   -- only the little boxes take the mouse
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", update) end
    WorldMapFrame:HookScript("OnShow", update)
    if WorldMapFrame.ScrollContainer.HookScript then pcall(WorldMapFrame.ScrollContainer.HookScript, WorldMapFrame.ScrollContainer, "OnMouseWheel", function() C_Timer.After(0.05, update) end) end
    -- a treasure opened now: the boxes are made again after the loot is recorded
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("LOOT_CLOSED")
    ev:SetScript("OnEvent", function()
        C_Timer.After(1, function()
            wipe(byMap); wipe(byMapNodes)
            if WorldMapFrame:IsShown() then SFP:Safe("treasures", update) end
        end)
    end)
end)
