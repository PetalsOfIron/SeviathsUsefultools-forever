-- SeviathsUsefulTools - every NPC you speak to
-- Whenever you open a conversation or a window with an NPC (talk, quest, vendor, trainer, flight master, banker,
-- auctioneer, innkeeper ...), the addon saves its name, ID, the map and the spot you stood at, and what it does for you.
-- Saved for all your characters: it is the place list for waypoints later (vendors, quest givers, trainers ...).

local _, SFP = ...

local function secret(v) return issecretvalue and issecretvalue(v) end

-- what an opened window or conversation says the NPC is
local WHAT = {
    GOSSIP_SHOW = "talk", QUEST_DETAIL = "quest giver", QUEST_PROGRESS = "quest", QUEST_COMPLETE = "quest turn-in",
    MERCHANT_SHOW = "vendor", TRAINER_SHOW = "trainer", TAXIMAP_OPENED = "flight master", BANKFRAME_OPENED = "banker",
    AUCTION_HOUSE_SHOW = "auctioneer",
}

local interactionNames
local function interactionName(t)
    if not interactionNames then
        interactionNames = {}
        for name, v in pairs((Enum and Enum.PlayerInteractionType) or {}) do
            if type(name) == "string" and type(v) == "number" then interactionNames[v] = name:lower() end
        end
    end
    return interactionNames[t]
end

local function npcIDFromGUID(guid)
    if type(guid) ~= "string" or secret(guid) then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id)
end

local nameIndex   -- lowercase name -> npcID, rebuilt when a new NPC is added

local function record(what)
    if not SFP.db then return end
    local okU, exists = pcall(UnitExists, "npc")
    if not okU or not exists then return end
    local okG, guid = pcall(UnitGUID, "npc")
    local id = okG and npcIDFromGUID(guid)
    if not id then return end
    local okN, name = pcall(UnitName, "npc")
    if not okN or type(name) ~= "string" or secret(name) or name == "" then return end
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not (pos and pos.GetXY) then return end
    local px, py = pos:GetXY()
    if not px or secret(px) or px <= 0 then return end
    SFP.db.npcPos = SFP.db.npcPos or {}
    local rec = SFP.db.npcPos[id]
    if not rec then
        rec = { n = name, m = m, x = px, y = py, v = 1, k = {}, t = time() }
        SFP.db.npcPos[id] = rec
        nameIndex = nil
    elseif rec.m == m then
        -- the NPC stands still: the spot is the average of every visit
        rec.x = (rec.x * rec.v + px) / (rec.v + 1)
        rec.y = (rec.y * rec.v + py) / (rec.v + 1)
        rec.v = rec.v + 1
        rec.t = time()
    else
        rec.m, rec.x, rec.y, rec.v, rec.t = m, px, py, 1, time()   -- it moved to another map
    end
    rec.n = name
    if what then rec.k[what] = true end
    -- the area of this NPC (the sub-zone): an area with NPCs is a town, also when it is no rest area (db.towns, see below)
    do
        local okS, sub = pcall(GetSubZoneText)
        local info = C_Map.GetMapInfo(m)
        local area = (okS and type(sub) == "string" and not secret(sub) and sub ~= "") and sub or (info and info.name)
        if type(area) == "string" and not secret(area) then
            SFP.db.towns = SFP.db.towns or {}
            local key = m .. ":" .. area
            local town = SFP.db.towns[key]
            if not town then
                town = { n = area, zone = info and info.name, m = m, v = 0, first = time(), seen = 0 }
                SFP.db.towns[key] = town
            end
            town.npcs = town.npcs or {}
            if not town.npcs[id] then
                town.npcs[id] = true
                town.nNpc = (town.nNpc or 0) + 1
                -- the spot of the town: the average of its NPCs
                town.x = town.x and ((town.x * (town.nNpc - 1) + px) / town.nNpc) or px
                town.y = town.y and ((town.y * (town.nNpc - 1) + py) / town.nNpc) or py
            end
            town.t = town.t or time()
        end
    end
    -- the NPC of the quest window that is open: the quest saved next is taken from / turned in to this one
    if what == "quest giver" or what == "quest" or what == "quest turn-in" then
        SFP.lastQuestNpc = { id = id, n = name, k = what, t = time() }
    end
end

-- the place of an NPC you spoke to, by name: { map, x, y, label } or nil
function SFP:LearnedNpcByName(name)
    if type(name) ~= "string" or not (self.db and self.db.npcPos) then return nil end
    if not nameIndex then
        nameIndex = {}
        for id, r in pairs(self.db.npcPos) do
            if type(r) == "table" and r.n then nameIndex[r.n:lower()] = id end
        end
    end
    local id = nameIndex[name:lower()]
    local r = id and self.db.npcPos[id]
    if r and r.m and r.x then return { map = r.m, x = r.x, y = r.y, label = r.n } end
    return nil
end

local f = CreateFrame("Frame")
for ev in pairs(WHAT) do pcall(f.RegisterEvent, f, ev) end
pcall(f.RegisterEvent, f, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
local pending = false
f:SetScript("OnEvent", function(_, event, arg)
    local what = WHAT[event]
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then what = interactionName(arg) end
    if pending then return end
    pending = true
    -- a moment later: the NPC is then the "npc" unit of the window that opened
    C_Timer.After(0.4, function()
        pending = false
        SFP:Safe("npc spot", record, what)
    end)
end)

-- every monster you kill: its name, ID and the spot you killed it from (db.killPos[npcID]), averaged over all kills.
-- The game gives an addon no position for another unit, so the place is where you stood, within spell or melee range of it.
local killedGUID = {}
local killCount = 0

local function noteKill(unit)
    if not SFP.db then return end
    local okU, exists = pcall(UnitExists, unit)
    if not okU or not exists then return end
    local okD, dead = pcall(UnitIsDead, unit)
    if not okD or secret(dead) or not dead then return end
    if UnitIsPlayer(unit) then return end
    local okA, attackable = pcall(UnitCanAttack, "player", unit)
    if not okA or secret(attackable) or not attackable then return end
    local okG, guid = pcall(UnitGUID, unit)
    local id = okG and npcIDFromGUID(guid)
    if not id or killedGUID[guid] then return end
    -- only a kill you were part of: you are in combat, or it was tagged for you
    if not (UnitAffectingCombat("player") or (UnitIsTapDenied and not UnitIsTapDenied(unit))) then return end
    local okN, name = pcall(UnitName, unit)
    if not okN or type(name) ~= "string" or secret(name) or name == "" then return end
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not (pos and pos.GetXY) then return end
    local px, py = pos:GetXY()
    if not px or secret(px) or px <= 0 then return end
    killedGUID[guid] = true
    killCount = killCount + 1
    if killCount % 500 == 0 then killedGUID = {} end   -- the session list does not grow without end
    SFP.db.killPos = SFP.db.killPos or {}
    local rec = SFP.db.killPos[id]
    if not rec then
        rec = { n = name, m = m, x = px, y = py, v = 1, t = time() }
        SFP.db.killPos[id] = rec
    elseif rec.m == m then
        rec.x = (rec.x * rec.v + px) / (rec.v + 1)
        rec.y = (rec.y * rec.v + py) / (rec.v + 1)
        rec.v = rec.v + 1
        rec.t = time()
    else
        -- the same monster in another zone: kept as the zone you kill it in most recently
        rec.m, rec.x, rec.y, rec.v, rec.t = m, px, py, 1, time()
    end
end

local killFrame = CreateFrame("Frame")
killFrame:RegisterEvent("UNIT_HEALTH")
killFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
killFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_HEALTH" and unit ~= "target" and unit ~= "focus" and unit ~= "mouseover" then return end
    SFP:Safe("note kill", noteKill, event == "UNIT_HEALTH" and unit or "target")
end)

-- every item you loot: where it came from (db.itemFrom[itemID].src["npc:ID" / "object:ID"] = { c = times, m, x, y }), from any corpse or
-- object, with the spot you stood at. The addon's other learners keep vendors and materials; this one is for anything that drops.
local function itemIDFromLink(link)
    if type(link) ~= "string" or secret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function noteLootSources()
    if not (SFP.db and GetNumLootItems and GetLootSourceInfo) then return end
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    local px, py
    if pos and pos.GetXY then px, py = pos:GetXY() end
    if not px or secret(px) or px <= 0 then px, py, m = nil, nil, nil end
    SFP.db.itemFrom = SFP.db.itemFrom or {}
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        local itemID = itemIDFromLink(link)
        if itemID then
            local srcs = { GetLootSourceInfo(slot) }
            for i = 1, #srcs, 2 do
                local guid = srcs[i]
                if type(guid) == "string" and not secret(guid) then
                    local kind, _, _, _, _, id = strsplit("-", guid)
                    local key = (kind == "Creature" or kind == "Vehicle") and ("npc:" .. tostring(id))
                        or (kind == "GameObject" and ("object:" .. tostring(id))) or nil
                    if key then
                        local rec = SFP.db.itemFrom[itemID]
                        if not rec then
                            local nm = link:match("%[(.-)%]")
                            rec = { n = nm, src = {} }
                            SFP.db.itemFrom[itemID] = rec
                        end
                        local s = rec.src[key]
                        if not s then
                            -- at most 12 sources per item: the rarest ones are kept, a new one only when there is room
                            local count = 0
                            for _ in pairs(rec.src) do count = count + 1 end
                            if count < 12 then
                                s = { c = 0, m = m, x = px, y = py }
                                rec.src[key] = s
                            end
                        end
                        if s then
                            s.c = s.c + 1
                            if px and s.m == m and s.x then   -- the spot is the average over all drops
                                s.x = (s.x * (s.c - 1) + px) / s.c
                                s.y = (s.y * (s.c - 1) + py) / s.c
                            elseif px and not s.x then
                                s.m, s.x, s.y = m, px, py
                            end
                        end
                        rec.t = time()
                    end
                end
            end
        end
    end
end

local itemLootFrame = CreateFrame("Frame")
itemLootFrame:RegisterEvent("LOOT_OPENED")
itemLootFrame:SetScript("OnEvent", function() SFP:Safe("note loot sources", noteLootSources) end)

-- towns, big and small: every rest area you stand in (inns, villages, camps, cities) is saved by its sub-zone name together with the
-- zone map and where you stood: db.towns["mapID:name"] = { n = name, zone, m, x, y, cont, v (visits), t, first }. A sanctuary city counts too.
-- The NPCs saved above carry the same map ID, so a town's vendors, trainers and flight masters can be found from db.npcPos.
local function noteTown()
    if not SFP.db then return end
    local okR, resting = pcall(IsResting)
    local okZ, zonePvp = pcall(GetZonePVPInfo)
    local sanctuary = okZ and not secret(zonePvp) and zonePvp == "sanctuary"
    if not ((okR and not secret(resting) and resting) or sanctuary) then return end
    local m = C_Map.GetBestMapForUnit("player")
    if not m then return end
    local info = C_Map.GetMapInfo(m)
    if not info or type(info.name) ~= "string" or secret(info.name) then return end
    local t = Enum.UIMapType
    if info.mapType and t and (info.mapType == t.World or info.mapType == t.Continent or info.mapType == t.Cosmic) then return end
    -- the town's name is the sub-zone ("Goldshire"); a city that is its own map has no sub-zone text, then the map name is used
    local okS, sub = pcall(GetSubZoneText)
    local name = (okS and type(sub) == "string" and not secret(sub) and sub ~= "") and sub or info.name
    local cont
    local cur, guard = info, 0
    while cur and cur.parentMapID and cur.parentMapID > 0 and guard < 8 do
        local parent = C_Map.GetMapInfo(cur.parentMapID)
        if parent and parent.mapType == t.Continent then cont = parent.name break end
        cur, guard = parent, guard + 1
    end
    local pos = C_Map.GetPlayerMapPosition(m, "player")
    local px, py
    if pos and pos.GetXY then px, py = pos:GetXY() end
    if not px or secret(px) or px <= 0 then px, py = nil, nil end
    SFP.db.towns = SFP.db.towns or {}
    local key = m .. ":" .. name
    local rec = SFP.db.towns[key]
    if not rec then
        rec = { n = name, zone = info.name, m = m, cont = cont, v = 0, first = time(), seen = 0 }
        SFP.db.towns[key] = rec
    end
    rec.rest = true   -- a rest area
    -- the spot is the average of where you stood in the rest area
    if px then
        rec.seen = (rec.seen or 0) + 1
        rec.x = rec.x and ((rec.x * (rec.seen - 1) + px) / rec.seen) or px
        rec.y = rec.y and ((rec.y * (rec.seen - 1) + py) / rec.seen) or py
    end
    -- one visit per hour in the same town
    if not rec.t or time() - rec.t > 3600 then rec.v = rec.v + 1 end
    rec.t = time()
end

local townFrame = CreateFrame("Frame")
townFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
townFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
townFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
townFrame:RegisterEvent("ZONE_CHANGED")           -- moving between sub-zones (a village, an inn)
townFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
townFrame:SetScript("OnEvent", function()
    C_Timer.After(2, function() SFP:Safe("note town", noteTown) end)
end)

-- the towns the addon knows: a rest area, or an area where you have spoken to at least 3 different NPCs. Newest first.
function SFP:Towns()
    local out = {}
    for key, t in pairs((self.db and self.db.towns) or {}) do
        if t.rest or (t.nNpc or 0) >= 3 then out[#out + 1] = t end
    end
    table.sort(out, function(a, b) return (a.t or 0) > (b.t or 0) end)
    return out
end
