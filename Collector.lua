-- SeviathsUsefulTools - Collector
--
-- Learns from your play and keeps it in the addon's saved variables (account-wide, so every new
-- character starts with everything already known):
--   * monsters: by NPC ID (never overwritten by another name), level, type, family, where seen,
--     kills and everything they dropped (green items included), skinning separately
--   * gathering nodes (herbs, ore, ...) by object ID with where they are and what they gave
--   * every item you loot: quality, type, level, price - tradeskill materials become farm items
--   * recipes of the professions you open: what they make and which reagents they need, so every
--     material can say what it is used for
-- Tooltips use it: monsters show what they drop, items show if they are junk, a crafting material
-- (and what it makes), or gear (and how it compares with what you wear).

local ADDON, SFP = ...

-- UnitGUID of a unit token, nil when the unit is unknown or the game hides the value (secret values)
local function safeGUID(unit)
    if type(unit) ~= "string" or (issecretvalue and issecretvalue(unit)) then return nil end
    local ok, g = pcall(UnitGUID, unit)
    if ok and type(g) == "string" and not (issecretvalue and issecretvalue(g)) then return g end
end


local floor, min, max = math.floor, math.min, math.max

local function guidInfo(guid)
    if not guid or (issecretvalue and issecretvalue(guid)) then return end
    local t, _, _, _, _, id = strsplit("-", guid)
    id = tonumber(id)
    if not id then return end
    if t == "Creature" or t == "Vehicle" then return "npc", id end
    if t == "GameObject" then return "obj", id end
end

local function playerPos()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not map then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return end
    if not x or x <= 0 or y <= 0 then return end
    return map, x, y
end

local function addPoint(rec, map, x, y)
    rec.m = rec.m or {}
    local list = rec.m[map]
    if not list then list = {}; rec.m[map] = list end
    for _, p in ipairs(list) do
        if math.abs(p[1] - x) < 0.012 and math.abs(p[2] - y) < 0.012 then
            if not p[3] then   -- a spot saved before the area name was recorded gets it now
                local okB, a2 = pcall(GetMinimapZoneText)
                if okB and type(a2) == "string" and not (issecretvalue and issecretvalue(a2)) and a2 ~= "" then p[3] = a2 end
            end
            return
        end
    end
    -- the third value is the text of the minimap's zone line at the spot ("Zeb'Alar Lumbermill"), the name of the area
    local okA, area = pcall(GetMinimapZoneText)
    if not okA or type(area) ~= "string" or (issecretvalue and issecretvalue(area)) or area == "" then area = nil end
    if #list < 15 then list[#list + 1] = { floor(x * 10000) / 10000, floor(y * 10000) / 10000, area } end
end

---------------------------------------------------------------------------
-- Spells that tell us what a loot window comes from
---------------------------------------------------------------------------
local GATHER_SPELLS = { 2366, 2575, 8613, 13262, 31252, 51005, 1804, 3365, 921 }
local gatherNames, skinNames = {}, {}
local lastCast = { name = nil, target = nil, t = 0 }

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and GetSpellInfo(id)
end

local function initSpellNames()
    for _, id in ipairs(GATHER_SPELLS) do
        local n = spellName(id)
        if n then gatherNames[n] = id end
    end
    for _, id in ipairs({ 8613, 8617, 8618, 10768, 32678, 50305, 74522, 102216 }) do
        local n = spellName(id)
        if n then skinNames[n] = true end
    end
end

-- the name of an object (a chest, a node, a note) is what its tooltip said when the mouse was over it: kept for a short while, so a
-- object looted by clicking it (no gathering spell) still gets its name
local lastObjectTip = { name = nil, line2 = nil, quest = nil, t = 0 }
pcall(function()
    GameTooltip:HookScript("OnShow", function()
        if UnitExists("mouseover") then return end
        local line = _G.GameTooltipTextLeft1
        local txt = line and line:GetText()
        if type(txt) == "string" and not (issecretvalue and issecretvalue(txt)) and txt ~= "" then
            lastObjectTip.name, lastObjectTip.t = txt, GetTime()
            -- the second line often says what it is ("Herbalism", "Mining", "Treasure"): kept as the object's kind
            local l2 = _G.GameTooltipTextLeft2 and _G.GameTooltipTextLeft2:GetText()
            if type(l2) == "string" and not (issecretvalue and issecretvalue(l2)) and l2 ~= "" and #l2 <= 40 and not l2:find("%d") then
                lastObjectTip.line2 = l2
            else
                lastObjectTip.line2 = nil
            end
            -- a quest objective in the tooltip ("0/1 ...") means the object is for a quest: the line above it is the quest title
            lastObjectTip.quest = nil
            for i = 2, 6 do
                local ln = _G["GameTooltipTextLeft" .. i]
                local s = ln and ln:GetText()
                if type(s) == "string" and not (issecretvalue and issecretvalue(s)) and s:find("%d+/%d+") then
                    local prev = _G["GameTooltipTextLeft" .. (i - 1)]
                    local title = prev and prev:GetText()
                    if type(title) ~= "string" or (issecretvalue and issecretvalue(title)) or i == 2 then title = nil end
                    lastObjectTip.quest = title or "Quest objective"
                    break
                end
            end
        end
    end)
end)

-- what kind of object a recorded object is: what the tooltip said, else by what it gave (herbs, ore, leather ...)
local OBJECT_KIND = { herb = "Herb node", ore = "Mining node", leather = "Skinnable / leather", cloth = "Cloth source",
    meat = "Meat source", element = "Elemental node", enchant = "Disenchant source" }
function SFP:ObjectKind(rec)
    if not rec then return nil end
    if rec.ot then return rec.ot end
    local counts, best, bestN = {}, nil, 0
    for itemID, n in pairs(rec.d or {}) do
        local kind = self.ClassifyItem and self:ClassifyItem(itemID)
        if kind and OBJECT_KIND[kind] then
            counts[kind] = (counts[kind] or 0) + n
            if counts[kind] > bestN then best, bestN = kind, counts[kind] end
        end
    end
    return best and OBJECT_KIND[best] or nil
end

-- what an object is for: the quests it was an objective of, else what it gave
function SFP:ObjectPurpose(rec)
    if not rec then return nil end
    local qs = {}
    for title in pairs(rec.qs or {}) do qs[#qs + 1] = title end
    table.sort(qs)
    if #qs > 0 then return "Quest objective: " .. table.concat(qs, ", ") end
    for itemID in pairs(rec.d or {}) do
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
        if classID == 12 then return "Quest item" end
    end
    local kind = self:ObjectKind(rec)
    if kind then return "Gathering (" .. kind .. ")" end
    if rec.d and next(rec.d) then return "Loot container / treasure" end
end

function SFP:RecentObjectQuest()
    if lastObjectTip.quest and GetTime() - lastObjectTip.t < 12 then return lastObjectTip.quest end
end

function SFP:RecentObjectKind()
    if lastObjectTip.line2 and GetTime() - lastObjectTip.t < 12 then return lastObjectTip.line2 end
end

function SFP:RecentCastTarget()
    local t = lastCast.target
    if t and not (issecretvalue and issecretvalue(t)) and t ~= "" and GetTime() - lastCast.t < 8 then return t end
    local o = lastObjectTip.name
    if o and GetTime() - lastObjectTip.t < 12 then return o end
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
local KIND_BY_SUBCLASS = { [5] = "cloth", [6] = "leather", [7] = "ore", [8] = "meat", [9] = "herb", [10] = "element", [12] = "enchant" }
local pendingItems = {}

-- tradeskill materials become farm items (shown in the browser, tooltips and learned spots)
function SFP:ClassifyItem(id)
    local info = self.Items[id]
    if info then return info.kind end
    local it = self.db and self.db.knownItems[id]
    if not it or it.c ~= 7 then return nil end
    local kind = KIND_BY_SUBCLASS[it.s] or "mat"
    self.Items[id] = { kind = kind, learned = true, note = "learned from your play" }
    self.trackedIDs[id] = true
    return kind
end

-- a quest item (class "Quest", or one the loot window marked as a quest item): never part of a monster's loot table
function SFP.IsQuestLoot(id)
    if type(id) ~= "number" then return false end
    if SFP.db and SFP.db.questLoot and SFP.db.questLoot[id] then return true end
    local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, id)
    return ok and classID == 12
end

local function recordItem(id)
    if not id or not SFP.db then return end
    local name, _, q, ilvl, minLvl, itype, subtype, _, equip, _, price, classID, subID, bind, expID = C_Item.GetItemInfo(id)
    if not name then
        pendingItems[id] = true
        C_Item.RequestLoadItemDataByID(id)
        return
    end
    pendingItems[id] = nil
    local it = SFP.db.knownItems[id] or {}
    it.n, it.q, it.i, it.r = name, q, ilvl, minLvl
    it.t, it.st, it.e, it.p, it.c, it.s, it.b = itype, subtype, equip, price, classID, subID, bind
    if type(expID) == "number" then it.x = expID end   -- the expansion of the item: the Codex groups items by it
    SFP.db.knownItems[id] = it
    SFP:StoreIcon(id)
    SFP:ClassifyItem(id)
end
SFP.RecordItem = recordItem

-- a material seen in a profession window or a crafting order: learned like an item from loot (name, class, farm item), once
function SFP.LearnMaterial(id)
    if type(id) ~= "number" or not SFP.db or not SFP.db.knownItems then return end
    if SFP.db.knownItems[id] then return end
    recordItem(id)
end

---------------------------------------------------------------------------
-- Monsters
---------------------------------------------------------------------------
local function ensureNpc(id, name)
    local rec = SFP.db.npcs[id]
    if not rec then
        -- the shipped record of this monster (its kills, drops and places so far) is the start; what the player collects is added to it
        local shipped = SFP.ShippedNpcRecord and type(id) == "number" and SFP:ShippedNpcRecord(id)
        if type(shipped) == "table" then
            rec = shipped
            if name and rec.n ~= name and (rec.n or ""):find("^NPC %d+$") then rec.n = name end
        else
            rec = { n = name or ("NPC " .. id), k = 0 }
        end
        SFP.db.npcs[id] = rec
    elseif name and rec.n ~= name and not (rec.n or ""):find("^NPC %d+$") then
        -- a stored name is never overwritten: other spellings are kept as aliases
        rec.a = rec.a or {}
        rec.a[name] = true
    elseif name and (rec.n or ""):find("^NPC %d+$") then
        rec.n = name
    end
    return rec
end

-- a value from the game that can be a secret one (in dungeons and fights): the plain value, or nil
local function plainValue(f, ...)
    local ok, v = pcall(f, ...)
    if ok and v ~= nil and not (issecretvalue and issecretvalue(v)) then return v end
end

local function recordUnit(unit)
    if not SFP.db or not UnitExists(unit) then return end
    if plainValue(UnitIsPlayer, unit) or plainValue(UnitPlayerControlled, unit) then return end
    local kind, id = guidInfo(plainValue(UnitGUID, unit))
    if kind ~= "npc" then return end
    local name = plainValue(UnitName, unit)
    if type(name) ~= "string" or name == "" or name == UNKNOWN then return end
    local rec = ensureNpc(id, name)
    local lvl = plainValue(UnitLevel, unit)
    if type(lvl) == "number" and lvl > 0 then
        rec.lmin = min(rec.lmin or lvl, lvl)
        rec.lmax = max(rec.lmax or lvl, lvl)
    elseif lvl == -1 then
        rec.boss = true
    end
    local ctype = plainValue(UnitCreatureType, unit)
    if type(ctype) == "string" then rec.t = rec.t or ctype end
    local family = plainValue(UnitCreatureFamily, unit)
    if type(family) == "string" then rec.f = rec.f or family end
    local cls = plainValue(UnitClassification, unit)
    if type(cls) == "string" and cls ~= "normal" then rec.c = cls end
    local map, x, y = playerPos()
    if map then addPoint(rec, map, x, y) end
end

local seenGuid = {}
-- gold: the money that comes in right after a loot window of monsters is split between them and kept per monster (rec.g = copper in all,
-- rec.gk = looted kills it was counted for), so a monster's gold per kill is known
local lootMoney
local function lootMoneyBegin()
    lootMoney = { t = GetTime(), money = GetMoney(), npcs = {} }
end
local moneyFrame = CreateFrame("Frame")
moneyFrame:RegisterEvent("PLAYER_MONEY")
moneyFrame:SetScript("OnEvent", function()
    local lm = lootMoney
    if not (lm and SFP.db and GetTime() - lm.t < 4) then lootMoney = nil return end
    local delta = GetMoney() - lm.money
    local ids = {}
    for id in pairs(lm.npcs) do ids[#ids + 1] = id end
    if delta > 0 and #ids > 0 then
        local per = delta / #ids
        for _, id in ipairs(ids) do
            local rec = SFP.db.npcs[id]
            if rec then rec.g = floor((rec.g or 0) + per); rec.gk = (rec.gk or 0) + 1 end
        end
    end
    lootMoney = nil
end)

---------------------------------------------------------------------------
-- Mounts: how many tries and how many drops. Every boss kill of a dungeon or raid counts as a try for the mounts that boss can drop; every
-- kill of a rare that can drop a mount counts too; a mount that is looted counts as a drop for the boss (or the rare) it came from. So
-- db.mountStats[itemID][source] = { n = tries, d = drops } and the chance is what the Mount search shows. The place you stood just
-- before you went into a dungeon or raid is kept as its entrance (db.instanceEntrances).
---------------------------------------------------------------------------
local lastBoss
local lastOutdoor
local rareMounts

local function mountStat(itemID, key)
    SFP.db.mountStats = SFP.db.mountStats or {}
    local t = SFP.db.mountStats[itemID]
    if not t then t = {}; SFP.db.mountStats[itemID] = t end
    local s = t[key]
    if not s then s = { n = 0, d = 0 }; t[key] = s end
    return s
end

local function isMountItem(id)
    local info = SFP.Items and SFP.Items[id]
    return info and info.kind == "mount"
end

-- the rares of the addon's own data: a monster that is one of them is marked rare when it is looted, even when it was not the target
local rareNpcs
local function isDataRare(npcID)
    if not rareNpcs then
        rareNpcs = {}
        for _, list in pairs(SFP.Rares or {}) do
            for _, sp in ipairs(list) do
                if sp.npc and not sp.hunter then rareNpcs[sp.npc] = true end
            end
        end
    end
    return rareNpcs[npcID]
end

function SFP:RareKillTry(npcID)
    if not rareMounts then
        rareMounts = {}
        for _, list in pairs(self.Rares or {}) do
            for _, sp in ipairs(list) do
                for _, id in ipairs(sp.items or {}) do
                    if sp.npc and isMountItem(id) then
                        rareMounts[sp.npc] = rareMounts[sp.npc] or {}
                        table.insert(rareMounts[sp.npc], id)
                    end
                end
            end
        end
    end
    for _, id in ipairs(rareMounts[npcID] or {}) do mountStat(id, "npc|" .. npcID).n = mountStat(id, "npc|" .. npcID).n + 1 end
end

-- a raid of an OLD expansion: the raids of the newest expansion in the data (Midnight now) are not old, they do not count for the collector style
local oldRaidCache = {}
local function isOldRaid(instName)
    if type(instName) ~= "string" then return false end
    local c = oldRaidCache[instName]
    if c ~= nil then return c end
    c = true   -- an instance the data does not list is an old one
    local exps = SFP.Expansions or {}
    local newest = exps[#exps]
    for _, z in ipairs(newest and newest.zones or {}) do
        for _, inst in ipairs(z.instances or {}) do
            if inst.name == instName then c = false end
        end
    end
    for _, inst in ipairs(newest and newest.instances or {}) do
        if inst.name == instName then c = false end
    end
    oldRaidCache[instName] = c
    return c
end

local mountFrame = CreateFrame("Frame")
mountFrame:RegisterEvent("BOSS_KILL")
mountFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mountFrame:SetScript("OnEvent", function(_, event, encounterID, encounterName)
    if not SFP.db then return end
    if event == "BOSS_KILL" then
        local inst = GetInstanceInfo()
        if type(inst) ~= "string" or type(encounterName) ~= "string" then return end
        lastBoss = { inst = inst, boss = encounterName, t = GetTime() }
        local li = inst:lower()
        for itemID, list in pairs(SFP.lootIndex or {}) do
            if isMountItem(itemID) then
                for _, l in ipairs(list) do
                    if type(l[1]) == "string" and l[1]:lower() == li and l[2] == encounterName then
                        local s = mountStat(itemID, "boss|" .. inst .. "|" .. encounterName)
                        s.n = s.n + 1
                        -- a boss that can drop a mount killed again: collecting (the old raids), counts for the collector play style - raids only,
                        -- and not Timewalking (everyone can do that)
                        local iname, itype, diff = GetInstanceInfo()
                        if itype == "raid" and diff ~= 33 and isOldRaid(iname) and SFP.Social and SFP.Social.Act then SFP.Social.Act("c_raid") end
                        break
                    end
                end
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local inInstance = IsInInstance and IsInInstance()
        if inInstance then
            local name = GetInstanceInfo()
            if type(name) == "string" and lastOutdoor then
                SFP.db.instanceEntrances = SFP.db.instanceEntrances or {}
                SFP.db.instanceEntrances[name] = { m = lastOutdoor.m, x = lastOutdoor.x, y = lastOutdoor.y }
            end
        end
    end
end)
C_Timer.NewTicker(4, function()
    if not SFP.db or (IsInInstance and IsInInstance()) then return end
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return end
    lastOutdoor = { m = m, x = floor(x * 10000) / 10000, y = floor(y * 10000) / 10000 }
end)

local function onLoot()
    if not SFP.db then return end
    if SFP.SessionLootOpened then SFP:SessionLootOpened() end
    lootMoneyBegin()
    local map, px, py = playerPos()
    -- skinning, and the butchering of the current expansion (found by its name, its spell numbers change)
    local castName = type(lastCast.name) == "string" and lastCast.name:lower() or nil
    local skin = castName and (skinNames[lastCast.name] or castName:find("skinn", 1, true) or castName:find("butcher", 1, true)) and GetTime() - lastCast.t < 8
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        if link and issecretvalue and issecretvalue(link) then link = nil end
        local itemID = link and tonumber(link:match("item:(%d+)"))
        if itemID then
            local okQ, _, _, _, _, _, _, isQuest = pcall(GetLootSlotInfo, slot)
            if okQ and isQuest == true then SFP.db.questLoot = SFP.db.questLoot or {}; SFP.db.questLoot[itemID] = true end
            recordItem(itemID)
            -- a mount looted: a drop for the boss (just killed in an instance) or the monster it came from
            if isMountItem(itemID) then
                local key
                if IsInInstance and IsInInstance() and lastBoss and GetTime() - lastBoss.t < 900 then
                    key = "boss|" .. lastBoss.inst .. "|" .. lastBoss.boss
                else
                    local g1 = GetLootSourceInfo(slot)
                    local k1, id1 = guidInfo(g1)
                    if k1 == "npc" then key = "npc|" .. id1 end
                end
                if key then mountStat(itemID, key).d = mountStat(itemID, key).d + 1 end
            end
            -- the place of the last time it was collected: the Material search shows it as a waypoint when no monster is known for it
            if map and px and py and not (issecretvalue and (issecretvalue(px) or issecretvalue(py))) then
                SFP.db.itemSpots = SFP.db.itemSpots or {}
                SFP.db.itemSpots[itemID] = { m = map, x = floor(px * 10000) / 10000, y = floor(py * 10000) / 10000 }
            end
            if SFP.SessionItem then
                local _, _, qty = GetLootSlotInfo(slot)
                SFP:SessionItem(itemID, qty)
            end
        end
        -- an area loot window lists every corpse for a slot: only the corpses that gave something to this slot count (a quantity of 0 is a corpse
        -- that gave nothing here, its monster must not get the item)
        local sources = {}
        do
            local raw = { GetLootSourceInfo(slot) }
            for i = 1, #raw, 2 do
                local q = raw[i + 1]
                if not (type(q) == "number" and not (issecretvalue and issecretvalue(q)) and q <= 0) then
                    sources[#sources + 1] = raw[i]
                    sources[#sources + 1] = q
                end
            end
        end
        for i = 1, #sources, 2 do
            local guid, qty = sources[i], sources[i + 1] or 1
            local kind, id = guidInfo(guid)
            if not kind and itemID and IsInInstance and IsInInstance() and lastBoss and GetTime() - lastBoss.t < 900 then
                SFP.db.bossLoot = SFP.db.bossLoot or {}
                local inst = SFP.db.bossLoot[lastBoss.inst]
                if not inst then inst = {}; SFP.db.bossLoot[lastBoss.inst] = inst end
                local boss = inst[lastBoss.boss]
                if not boss then boss = { k = 0, d = {} }; inst[lastBoss.boss] = boss end
                boss.d[itemID] = (boss.d[itemID] or 0) + (qty or 1)
                if lastBoss.counted ~= true then lastBoss.counted = true; boss.k = boss.k + 1 end
            end
            if kind == "npc" then
                local name
                if safeGUID("target") == guid then
                    local okN, tn = pcall(UnitName, "target")   -- in a dungeon the name can be a secret value: never an error, never stored
                    if okN and type(tn) == "string" and not (issecretvalue and issecretvalue(tn)) then name = tn end
                end
                if not name and C_TooltipInfo and C_TooltipInfo.GetHyperlink then
                    local okT, data = pcall(C_TooltipInfo.GetHyperlink, "unit:" .. guid)
                    local line = okT and data and data.lines and data.lines[1]
                    local lt = line and line.leftText
                    if type(lt) == "string" and not (issecretvalue and issecretvalue(lt)) and lt ~= "" then name = lt end
                end
                local rec = ensureNpc(id, name)
                -- a monster whose name the loot did not give: asked from the addon's own data (rares, farm spots) before it stays "NPC <id>"
                if (rec.n or ""):find("^NPC %d+$") and SFP.NpcNameFor then
                    local ok, nm = pcall(SFP.NpcNameFor, SFP, id, guid)
                    if ok and type(nm) == "string" and nm ~= "" and not nm:find("^NPC %d+$") then rec.n = nm end
                end
                if not skin and lootMoney then lootMoney.npcs[id] = true end
                SFP.lastLoot = { kind = skin and "s" or "n", name = rec.n, t = GetTime(), itemID = itemID }   -- what the last loot came from (a monster)
                if safeGUID("target") == guid then
                    local okC, cls = pcall(UnitClassification, "target")   -- a secret value in some places: never an error
                    if okC and type(cls) == "string" and not (issecretvalue and issecretvalue(cls)) and cls ~= "normal" then rec.c = cls end
                else
                    -- not the target any more: the class from the unit of that id when the game still has one, else from the rare data
                    local unit = UnitTokenFromGUID and UnitTokenFromGUID(guid)
                    local cls2
                    if unit and not (issecretvalue and issecretvalue(unit)) then
                        local okC2, c2 = pcall(UnitClassification, unit)
                        if okC2 and type(c2) == "string" and not (issecretvalue and issecretvalue(c2)) then cls2 = c2 end
                    end
                    if cls2 and cls2 ~= "normal" then rec.c = cls2
                    elseif not rec.c and isDataRare(id) then rec.c = "rare" end
                end
                if not seenGuid[guid .. (skin and "s" or "")] then
                    seenGuid[guid .. (skin and "s" or "")] = true
                    if skin then rec.sk = (rec.sk or 0) + 1 else rec.k = (rec.k or 0) + 1; if SFP.NoteKill then SFP:NoteKill(id) end; SFP:RareKillTry(id) end
                    if map then addPoint(rec, map, px, py) end
                end
                if itemID and not SFP.IsQuestLoot(itemID) then
                    local tbl
                    if skin then rec.s = rec.s or {}; tbl = rec.s else rec.d = rec.d or {}; tbl = rec.d end
                    tbl[itemID] = (tbl[itemID] or 0) + (qty or 1)
                end
            elseif kind == "obj" then
                local rec = SFP.db.objects[id]
                if not rec then rec = { n = SFP:RecentCastTarget() or ("Object " .. id), k = 0 }; SFP.db.objects[id] = rec end
                local nm = SFP:RecentCastTarget()
                if nm and (rec.n or ""):find("^Object %d+$") then rec.n = nm end
                SFP.lastLoot = { kind = "o", name = rec.n, t = GetTime(), itemID = itemID }   -- ... or an object
                if not rec.ot then rec.ot = SFP:RecentObjectKind() or SFP:ObjectKind(rec) end
                local qt = SFP:RecentObjectQuest()
                if qt then rec.qs = rec.qs or {}; rec.qs[qt] = true end
                -- this character has opened it: its box leaves the map for this character, and a chest opened again at the same place is noted as respawning
                -- (a respawned chest keeps its guid, so this is not only for a new guid)
                if map and px and py and SFP.NoteOpened and itemID then SFP.NoteOpened(id, map, px, py) end
                if not seenGuid[guid] then
                    seenGuid[guid] = true
                    rec.k = (rec.k or 0) + 1
                    if map then addPoint(rec, map, px, py) end
                    -- a treasure: the game shows it as a loot icon (a vignette) right where you stand; a quest objective or a plain object is not
                    if map and px and py and C_VignetteInfo and C_VignetteInfo.GetVignettes then
                        local okV, vigs = pcall(C_VignetteInfo.GetVignettes)
                        for _, vg in ipairs(okV and vigs or {}) do
                            local okI, vi = pcall(C_VignetteInfo.GetVignetteInfo, vg)
                            local atlas = okI and type(vi) == "table" and type(vi.atlasName) == "string" and not (issecretvalue and issecretvalue(vi.atlasName)) and vi.atlasName:lower()
                            if atlas and (atlas:find("loot", 1, true) or atlas:find("treasure", 1, true) or atlas:find("chest", 1, true)) then
                                local okP, vp = pcall(C_VignetteInfo.GetVignettePosition, vg, map)
                                if okP and type(vp) == "table" and vp.GetXY then
                                    local vx, vy = vp:GetXY()
                                    if type(vx) == "number" and math.abs(vx - px) < 0.02 and math.abs(vy - py) < 0.02 then rec.tr = true break end
                                end
                            end
                        end
                    end
                end
                if itemID then
                    rec.d = rec.d or {}
                    rec.d[itemID] = (rec.d[itemID] or 0) + (qty or 1)
                    -- the amount of one pickup (rec.q[item] = { smallest, largest }): a herb or ore node gives a different amount each time
                    local one = tonumber(qty) or 1
                    rec.q = rec.q or {}
                    local qs = rec.q[itemID]
                    if not qs then rec.q[itemID] = { one, one }
                    else
                        if one < qs[1] then qs[1] = one end
                        if one > qs[2] then qs[2] = one end
                    end
                    -- the kind of node, noted once: "herb" or "ore" (by what it gave: the Collector's own item kinds, or the type text of the node)
                    if not rec.gt then
                        local okK = SFP:ObjectKind(rec)
                        local lk = type(okK) == "string" and okK:lower() or ""
                        if lk:find("herb", 1, true) then rec.gt = "herb" elseif lk:find("min", 1, true) or lk:find("ore", 1, true) then rec.gt = "ore" end
                    end
                end
            end
        end
    end
    SFP.dropIndex = nil
end

---------------------------------------------------------------------------
-- Recipes (professions you open)
---------------------------------------------------------------------------
local function itemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

local function scanRecipes()
    if not SFP.db then return end
    local count = 0
    local legacyProf   -- the profession a modern-window scan was about (for the message)
    -- legacy trade skill window
    if GetNumTradeSkills and GetTradeSkillInfo then
        local prof = GetTradeSkillLine and GetTradeSkillLine() or "Profession"
        if prof == "UNKNOWN" then return end
        for i = 1, GetNumTradeSkills() do
            local name, kind = GetTradeSkillInfo(i)
            if name and kind ~= "header" then
                local out = GetTradeSkillItemLink and itemIDFromLink(GetTradeSkillItemLink(i))
                local reag = {}
                for r = 1, (GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0) do
                    local rid = GetTradeSkillReagentItemLink and itemIDFromLink(GetTradeSkillReagentItemLink(i, r))
                    local _, _, cnt = GetTradeSkillReagentInfo(i, r)
                    if rid then reag[#reag + 1] = { rid, cnt or 1 } end
                end
                if not SFP.db.recipes[prof .. "|" .. name] then
                    SFP.db.recipes[prof .. "|" .. name] = { n = name, p = prof, o = out, r = reag }
                    count = count + 1
                end
            end
        end
    -- modern trade skill API
    elseif C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        local base = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
        local prof = base and base.professionName or "Profession"
        for _, rid in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
            -- the list holds every recipe of the profession; only the ones this character really has learned are kept.
            -- A recipe that is already saved is left alone: it is not read again and not counted again.
            local info = C_TradeSkillUI.GetRecipeInfo(rid)
            if info and info.name and info.learned and not SFP.db.recipes[prof .. "|" .. info.name] then
                local schem = C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeSchematic(rid, false)
                if schem then
                    local reag = {}
                    for _, slot in ipairs(schem.reagentSlotSchematics or {}) do
                        for _, rg in ipairs(slot.reagents or {}) do
                            if rg.itemID then reag[#reag + 1] = { rg.itemID, slot.quantityRequired or 1 }; break end
                        end
                    end
                    SFP.db.recipes[prof .. "|" .. info.name] = { n = info.name, p = prof, o = schem.outputItemID, r = reag, id = rid }
                    count = count + 1
                    for _, rg in ipairs(reag) do SFP.LearnMaterial(rg[1]) end   -- the materials too
                end
            end
        end
        legacyProf = prof
    end
    if count > 0 then
        SFP.usedIn, SFP.madeBy = nil, nil
        local total = 0
        for _, r in pairs(SFP.db.recipes) do if r.p == (legacyProf or r.p) then total = total + 1 end end
        SFP:Print(("Saved %d new recipes%s (%d saved for this profession)."):format(count, legacyProf and (" of " .. legacyProf) or "", total))
        if SFP.RefreshAll then SFP:RefreshAll() end
    end
end

local function buildRecipeIndex()
    SFP.usedIn, SFP.madeBy = {}, {}
    for key, r in pairs(SFP.db.recipes) do
        for _, rg in ipairs(r.r or {}) do
            local list = SFP.usedIn[rg[1]]
            if not list then list = {}; SFP.usedIn[rg[1]] = list end
            list[#list + 1] = key
        end
        if r.o then
            local list = SFP.madeBy[r.o]
            if not list then list = {}; SFP.madeBy[r.o] = list end
            list[#list + 1] = key
        end
    end
end

function SFP:RecipeIndex()
    if not self.usedIn then buildRecipeIndex() end
    return self.usedIn, self.madeBy
end

-- what a drop table looks like for items: itemID -> { {npcID, count}, ... }
function SFP:DropIndex()
    if self.dropIndex then return self.dropIndex end
    local idx = {}
    for npcID, rec in pairs(self.db.npcs) do
        for itemID, c in pairs(rec.d or {}) do
            local l = idx[itemID]; if not l then l = {}; idx[itemID] = l end
            l[#l + 1] = { npcID, c, "n" }
        end
        for itemID, c in pairs(rec.s or {}) do
            local l = idx[itemID]; if not l then l = {}; idx[itemID] = l end
            l[#l + 1] = { npcID, c, "s" }
        end
    end
    for objID, rec in pairs(self.db.objects) do
        for itemID, c in pairs(rec.d or {}) do
            local l = idx[itemID]; if not l then l = {}; idx[itemID] = l end
            l[#l + 1] = { objID, c, "o" }
        end
    end
    for _, l in pairs(idx) do table.sort(l, function(a, b) return a[2] > b[2] end) end
    self.dropIndex = idx
    return idx
end

---------------------------------------------------------------------------
-- Facts that are not in the game data
---------------------------------------------------------------------------
-- herbs that also give another herb when picked (Wowhead drop data)
SFP.AlsoGives = {
    [2450] = { 2452, "~39%" },   -- Briarthorn -> Swiftthistle
    [785]  = { 2452, "~20%" },   -- Mageroyal -> Swiftthistle
    [36901] = { 37921, "~32%" }, [36904] = { 37921, "~32%" }, [36907] = { 37921, "~31%" }, [36908] = { 37921, "~27%" }, -- -> Deadnettle
}

local GENERAL_USE = {
    herb = "Alchemy (potions, flasks) and Inscription (milled into pigments)",
    ore = "Blacksmithing, Engineering and Jewelcrafting (prospecting gems)",
    cloth = "Tailoring (cloth armor, bags)",
    leather = "Leatherworking and armor kits",
    meat = "Cooking",
    element = "many crafting professions",
    enchant = "Enchanting",
    mat = "crafting",
}

local SLOT_BY_EQUIP = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}

local function equippedLevel(slots)
    local best
    for _, s in ipairs(slots) do
        local link = GetInventoryItemLink("player", s)
        if not link then return 0 end -- an empty slot: anything is an upgrade
        local lvl = select(4, C_Item.GetItemInfo(link))
        if lvl then best = best and min(best, lvl) or lvl end
    end
    return best
end

local function money(c)
    if not c or c <= 0 then return "" end
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return floor(c / 10000) .. "g"
end

local function itemName(id)
    return SFP:ItemName(id)
end

local function recipeTexts(keys, limit)
    local out = {}
    for i = 1, min(limit, #keys) do
        local r = SFP.db.recipes[keys[i]]
        if r then out[#out + 1] = r.n .. " |cff808080(" .. (r.p or "?") .. ")|r" end
    end
    if #keys > limit then out[#out + 1] = "+" .. (#keys - limit) .. " more" end
    return table.concat(out, ", ")
end

-- the lines our addon adds to an item tooltip
function SFP:ItemTipLines(id, link)
    local lines = {}
    local name, _, q, ilvl, minLvl, itype, subtype, _, equip, _, price, classID = C_Item.GetItemInfo(link or id)
    if not name then return lines end
    -- the real item (bonus IDs, scaling) is in the link: the base item can say "poor" or a low item level
    if link then
        local lq = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(link)
        if lq then q = lq end
        local li = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
        if li and li > 0 then ilvl = li end
    end
    local usedIn, madeBy = self:RecipeIndex()

    if q == 0 then
        lines[#lines + 1] = { "|cff9d9d9dVendor junk|r" .. (price and price > 0 and ("  sells for " .. money(price)) or "") }
    elseif classID == 7 then
        local kind = KIND_BY_SUBCLASS[select(13, C_Item.GetItemInfo(id)) or 0] or "mat"
        lines[#lines + 1] = { "|cff40d0ffCrafting material|r  " .. (subtype or "") }
        if usedIn[id] then
            lines[#lines + 1] = { "Used in: " .. recipeTexts(usedIn[id], 6), 0.85, 0.85, 0.85, true }
        else
            lines[#lines + 1] = { "Used for: " .. (GENERAL_USE[kind] or "crafting") .. "  |cff808080(open a profession window to learn exact recipes)|r", 0.85, 0.85, 0.85, true }
        end
    elseif (classID == 2 or classID == 4) and equip and equip ~= "" and SLOT_BY_EQUIP[equip] then
        local mine = equippedLevel(SLOT_BY_EQUIP[equip])
        local txt, r, g, b
        if mine == 0 then txt, r, g, b = "slot is empty - wear it", 0.3, 1, 0.3
        elseif mine and ilvl then
            local d = ilvl - mine
            if d >= 15 then txt, r, g, b = ("big upgrade (+%d item levels)"):format(d), 0.2, 1, 0.2
            elseif d >= 5 then txt, r, g, b = ("upgrade (+%d)"):format(d), 0.5, 1, 0.3
            elseif d > -5 then txt, r, g, b = "about the same as what you wear", 1, 0.85, 0.2
            else txt, r, g, b = ("below your gear (%d)"):format(d), 1, 0.4, 0.3 end
        end
        local need = (minLvl and minLvl > UnitLevel("player")) and ("  |cffff5050needs level " .. minLvl .. "|r") or ""
        lines[#lines + 1] = { "|cffb0b0ffGear|r  item level " .. (ilvl or "?") .. need }
        if txt then lines[#lines + 1] = { "Compared with your equipped: " .. txt, r, g, b } end
    end
    if madeBy[id] then
        lines[#lines + 1] = { "Craftable: " .. recipeTexts(madeBy[id], 3), 0.85, 0.85, 0.85, true }
    end
    local also = self.AlsoGives[id]
    if also then
        lines[#lines + 1] = { "Also gives: " .. itemName(also[1]) .. " " .. also[2], 0.6, 1, 0.6 }
    end
    local drops = self:DropIndex()[id]
    if drops then
        local out = {}
        for i = 1, min(3, #drops) do
            local d = drops[i]
            local nm
            if d[3] == "o" then nm = (self.db.objects[d[1]] or {}).n else nm = (self.db.npcs[d[1]] or {}).n end
            out[#out + 1] = (nm or "?") .. (d[3] == "s" and " (skinning)" or "") .. " x" .. d[2]
        end
        lines[#lines + 1] = { "Seen from: " .. table.concat(out, ", "), 0.7, 0.7, 0.7, true }
    end
    if not drops and self.QuestieItemSources then
        local src = self:QuestieItemSources(id)
        for _, line in ipairs(src or {}) do lines[#lines + 1] = { line, 0.7, 0.7, 0.7, true } end
    end
    if SFP.ItemInfoLines then SFP:Safe("item info", SFP.ItemInfoLines, SFP, id, lines, drops ~= nil, link) end
    local craft = SFP.CraftProfitLines and SFP:CraftProfitLines(id)
    for _, l in ipairs(craft or {}) do lines[#lines + 1] = l end
    return lines
end

-- farm mobs known from the shipped data: npcID -> items
local function buildSeeds()
    SFP.farmNpc = {}
    for _, list in pairs(SFP.Spawns or {}) do
        for _, sp in ipairs(list) do if sp.npc and sp.npc > 0 then SFP.farmNpc[sp.npc] = sp.items end end
    end
    for _, list in pairs(SFP.Rares or {}) do
        for _, sp in ipairs(list) do if sp.npc and sp.npc > 0 and sp.items and #sp.items > 0 then SFP.farmNpc[sp.npc] = sp.items end end
    end
end

-- true when our lines are already in this tooltip (hooks can fire more than once)
local hasOurLines   -- defined below
-- What an item is for, in a few words: the item's own "Use:" line from the game's tooltip, else what it is (a battle pet, a mount, a toy). It is read once and
-- kept with the other item data (db.itemUse), so it is known from then on; nil when the game does not say.
function SFP:ItemUseText(id)
    if type(id) ~= "number" or not self.db then return nil end
    self.db.itemUse = self.db.itemUse or {}
    -- earlier "nothing to say" answers were kept even when the game's tooltip had not loaded yet: they are asked again once
    if self.db.itemUseV ~= 2 then
        for k, v in pairs(self.db.itemUse) do if v == false then self.db.itemUse[k] = nil end end
        self.db.itemUseV = 2
    end
    local kept = self.db.itemUse[id]
    if kept ~= nil then return kept ~= false and kept or nil end
    local text
    if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
        local ok, name = pcall(C_PetJournal.GetPetInfoByItemID, id)
        if ok and name then text = "Battle pet: teaches you to summon this companion" end
    end
    if not text and C_MountJournal and C_MountJournal.GetMountFromItem then
        local ok, mid = pcall(C_MountJournal.GetMountFromItem, id)
        if ok and mid then text = "Mount" end
    end
    if not text and C_ToyBox and C_ToyBox.GetToyInfo then
        local ok, tid = pcall(C_ToyBox.GetToyInfo, id)
        if ok and tid then text = "Toy" end
    end
    local tooltipRead = false
    if not text and C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
        if ok and type(data) == "table" and type(data.lines) == "table" and #data.lines > 1 then
            tooltipRead = true
            for _, line in ipairs(data.lines) do
                local lt = line and line.leftText
                if type(lt) == "string" and not (issecretvalue and issecretvalue(lt)) then
                    local use = lt:match("^Use:%s*(.+)$") or lt:match("^Teaches%s+(.+)$")
                    if use then
                        text = lt:sub(1, 90)
                        break
                    end
                end
            end
            -- no use line: the item's own description (the quoted text of its tooltip)
            if not text then
                for _, line in ipairs(data.lines) do
                    local lt = line and line.leftText
                    if type(lt) == "string" and not (issecretvalue and issecretvalue(lt)) then
                        local desc = lt:match('^"(.-)"?$')
                        if desc and #desc > 8 then
                            text = (#desc > 90) and (desc:sub(1, 87) .. "...") or desc
                            break
                        end
                    end
                end
            end
        end
    end
    -- a consumable with no use line says what it is: Potion, Elixir, Flask, Food & Drink ...
    if not text and C_Item and C_Item.GetItemInfoInstant then
        local ok, _, itype, isub, _, _, classID = pcall(C_Item.GetItemInfoInstant, id)
        if ok and classID == 0 and type(isub) == "string" and isub ~= "" and isub ~= "Other" then text = isub end
    end
    -- an item the game has not loaded yet is asked again next time; only an answer is kept
    if text then self.db.itemUse[id] = text
    elseif tooltipRead then self.db.itemUse[id] = false   -- the tooltip was read and says nothing
    elseif C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return text
end

-- the loot lines of a recorded object (a chest, a cache ...): each item with its chance ("33% 1/3 chance") from the first time it was opened - for the tooltip of the
-- object and for the little boxes on the world map
function SFP.ObjectLootLines(tt, rec)
    if type(rec) ~= "table" or type(rec.d) ~= "table" then return end
    local list = {}
    for itemID, n in pairs(rec.d) do list[#list + 1] = { itemID, n } end
    table.sort(list, function(a, b)
        if a[2] ~= b[2] then return a[2] > b[2] end
        return a[1] < b[1]
    end)
    local opened = max(1, rec.k or 1)
    for i = 1, min(12, #list) do
        local e = list[i]
        local chance = SFP.ChanceText(e[2], opened, 1, "pickup")
        local price = SFP:GetPrice(e[1])
        local amt = ""
        local qs = rec.q and rec.q[e[1]]
        if type(qs) == "table" and qs[1] then amt = "  |cff808080x" .. (qs[1] == qs[2] and qs[1] or (qs[1] .. "-" .. qs[2])) .. "|r" end
        tt:AddDoubleLine("|T" .. SFP:ItemIcon(e[1]) .. ":12|t " .. SFP:ItemName(e[1]) .. amt .. (chance ~= "" and ("  " .. chance) or ""),
            price and SFP:FormatPrice(price) or "", 1, 1, 1, 1, 1, 1)
        -- what the item is for: its own use text (kept once read), else what the addon knows (a crafting material and its recipes, gear compared with yours ...);
        -- nothing is typed when neither can say, and never where the item was seen
        local why = SFP:ItemUseText(e[1])
        if not why then
            local okT, tl = pcall(SFP.ItemTipLines, SFP, e[1])
            if okT and type(tl) == "table" then
                for _, row in ipairs(tl) do
                    local txt = type(row[1]) == "string" and row[1]
                    if txt and not txt:find("Seen from", 1, true) and not txt:find("Where to get", 1, true) and not txt:find("Dropped by", 1, true)
                        and not txt:find("Info:", 1, true) then why = txt break end
                end
            end
        end
        if why then tt:AddLine("   |cff808080" .. why .. "|r", 1, 1, 1, false) end
    end
    if #list > 12 then tt:AddLine("|cff808080+ " .. (#list - 12) .. " more|r") end
end

-- a treasure chest, a cache, a skull ... (a game object): its loot as you recorded it, shown after the first time you opened it - each item with its chance
-- ("33% 1/3 chance"), the same way as for monsters
local function objectTip(tt, data)
    if not SFP.db or not SFP.db.tooltip or not SFP.db.objects then return end
    local id = data and data.id
    if type(id) ~= "number" or (issecretvalue and issecretvalue(id)) then
        local g = data and data.guid
        if type(g) == "string" and not (issecretvalue and issecretvalue(g)) then
            local kind, gid = guidInfo(g)
            if kind == "obj" then id = gid end
        end
    end
    if type(id) ~= "number" then return end
    local rec = SFP.db.objects[id]
    if type(rec) ~= "table" or type(rec.d) ~= "table" or not next(rec.d) then return end
    if hasOurLines(tt) then return end
    tt:AddLine(" ")
    tt:AddLine("|c" .. SFP.CYAN_HEX .. "Seviaths|r  |cff808080loot|r")
    SFP.ObjectLootLines(tt, rec)
    tt:Show()
end

hasOurLines = function(tt)
    local n = tonumber(tt.NumLines and tt:NumLines()) or 0
    for i = n, 1, -1 do
        local fs = _G[(tt:GetName() or "GameTooltip") .. "TextLeft" .. i]
        local t = fs and fs.GetText and fs:GetText()
        if type(t) == "string" and t:find("Seviaths", 1, true) then return true end
    end
    return false
end

local function unitTip(tt, data)
    local function dbg(msg) if SFP.tipDebug then SFP:Print("unit tooltip: " .. msg) end end
    if not SFP.db or not SFP.db.tooltip then return dbg("tooltip lines are switched off") end
    local guid = data and data.guid
    if guid and (type(guid) ~= "string" or (issecretvalue and issecretvalue(guid))) then guid = nil end
    local unit
    if not guid then
        local ok, _, u = pcall(tt.GetUnit, tt)
        if ok and type(u) == "string" and not (issecretvalue and issecretvalue(u)) then unit = u
        elseif UnitExists("mouseover") then unit = "mouseover" end
        guid = safeGUID(unit)
    end
    if not guid then return dbg("no unit in the tooltip") end
    local kind, id = guidInfo(guid)
    if kind ~= "npc" then return dbg("not a monster") end
    if unit and (UnitIsPlayer(unit) or UnitPlayerControlled(unit)) then return dbg("player or pet") end
    -- friendly NPCs (guards, vendors, auctioneers) are not farm targets: no drop / worth-grinding lines
    local who = unit or ((safeGUID("mouseover") == guid) and "mouseover") or ((safeGUID("target") == guid) and "target")
    if who and not UnitCanAttack("player", who) then return dbg("friendly") end
    if hasOurLines(tt) then return end
    dbg("npc " .. id)
    local rec = SFP.db.npcs[id]
    local seed = SFP.farmNpc and SFP.farmNpc[id]
    tt:AddLine(" ")
    do
        local ql = SFP.QuestObjectiveNpc and SFP:QuestObjectiveNpc(id)
        local byName = not ql and unit and SFP.QuestsByMonsterName and SFP:QuestsByMonsterName(UnitName(unit))
        if byName then
            for i = 1, min(3, #byName) do tt:AddLine("|cffffd100! Quest:|r " .. byName[i], 1, 1, 1, true) end
        elseif not ql and unit and C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest and select(2, pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)) then
            tt:AddLine("|cffffd100! Needed for one of your quests|r")
        end
    end
    tt:AddLine("|c" .. SFP.CYAN_HEX .. "Seviaths|r  |cff808080NPC " .. id .. "|r")
    -- history from before the addon: gear you already own from this monster (your transmog collection)
    do
        local nm = rec and rec.n
        if not nm and unit then local okn, n = pcall(UnitName, unit); if okn then nm = n end end
        local past = SFP.HistoryFor and SFP:HistoryFor(nm)
        if past then tt:AddLine("|cff80ff80" .. SFP:HistoryText(past) .. "|r", 1, 1, 1, true) end
        -- collectibles this one can drop: mount / pet / toy, and whether you already have each
        for _, itemID in ipairs((SFP.farmNpc and SFP.farmNpc[id]) or {}) do
            local own = SFP.OwnedStatus and SFP:OwnedStatus(itemID)
            if own ~= nil then
                tt:AddLine("|T" .. SFP:ItemIcon(itemID) .. ":12|t " .. SFP:ItemName(itemID) .. (own and "  |cff40ff40owned|r" or "  |cffff6060not collected yet|r"))
            end
        end
    end
    local list = {}
    for itemID, c in pairs(rec and rec.d or {}) do if not SFP.IsQuestLoot(itemID) then list[#list + 1] = { itemID, c } end end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local kills = max(1, rec and rec.k or 1)
    local shownIds = {}
    for i = 1, min(8, #list) do
        local e = list[i]
        shownIds[e[1]] = true
        -- the chance from your own kills with how many kills it takes: "12.5% (1 in 8)"; the number of kills itself is not shown
        local chance = SFP.ChanceText(e[2], kills)
        tt:AddDoubleLine("|T" .. SFP:ItemIcon(e[1]) .. ":12|t " .. SFP:ItemName(e[1]),
            SFP.SoldTag(e[1]) .. (chance ~= "" and chance or string.format("%d%%", min(100, floor(e[2] * 100 / kills + 0.5)))), 1, 1, 1, 0.7, 0.7, 0.7)
    end
    -- and what Wowhead lists for this monster (rares, bosses, any monster), the rest of its loot table
    do
        local listed = SFP.WowheadDrops and SFP:WowheadDrops(id)
        if listed then
            local extra = 0
            for _, itemID in ipairs(listed) do
                if not shownIds[itemID] and not (rec and rec.d and rec.d[itemID]) and not SFP.IsQuestLoot(itemID) then
                    extra = extra + 1
                    if extra > 8 then tt:AddLine("|cff808080+ more|r") break end
                    tt:AddDoubleLine("|T" .. SFP:ItemIcon(itemID) .. ":12|t " .. SFP:ItemName(itemID), "|cff808080listed|r", 1, 1, 1, 0.7, 0.7, 0.7)
                end
            end
        end
    end
    if rec and rec.s then
        local sk = {}
        for itemID, c in pairs(rec.s) do sk[#sk + 1] = { itemID, c } end
        table.sort(sk, function(a, b) return a[2] > b[2] end)
        for i = 1, min(3, #sk) do
            tt:AddDoubleLine("|T" .. SFP:ItemIcon(sk[i][1]) .. ":12|t " .. SFP:ItemName(sk[i][1]), "skinning", 1, 1, 1, 0.7, 0.7, 0.7)
        end
    end
    local shown = #list > 0
    if not shown and seed then
        for i = 1, min(6, #seed) do
            tt:AddLine("|T" .. SFP:ItemIcon(seed[i]) .. ":12|t " .. SFP:ItemName(seed[i]) .. "  |cff808080(farm target)|r")
        end
        shown = true
    end
    if not shown and SFP.QuestieDropsOf then
        local known = SFP:QuestieDropsOf(id)
        for i = 1, min(6, known and #known or 0) do
            tt:AddLine("|T" .. SFP:ItemIcon(known[i]) .. ":12|t " .. SFP:ItemName(known[i]) .. "  |cff808080(database)|r")
            shown = true
        end
    end
    -- quests it gives or takes (Questie database)
    local Q, N = SFP.QDB and SFP.QDB.Quest, SFP.QDB and SFP.QDB.Npc
    if Q and N and not (SFP.QuestMarkers and SFP.QuestMarkers.enabled == false) then
        local ok, starts = pcall(N.questStarts, id)
        if ok and starts and #starts > 0 then
            local names = {}
            for i = 1, #starts do
                local qm = SFP.QuestMarkers
                if #names < 3 and (not qm or qm:IsAvailable(starts[i])) then
                    local okn, nm = pcall(Q.name, starts[i])
                    names[#names + 1] = okn and nm or ("quest " .. starts[i])
                end
            end
            if #names > 0 then tt:AddLine("Starts: " .. table.concat(names, ", "), 0.6, 1, 0.6, true) end
        end
    end
    -- an error in the verdict must not take the rest of the tooltip with it
    local worth
    if SFP.GatherLines then
        local u = unit or ((guid and safeGUID("mouseover") == guid) and "mouseover") or "target"
        local ok, res = pcall(SFP.GatherLines, SFP, "n", id, UnitCreatureType(u), UnitLevel(u), UnitName(u))
        if ok then worth = res else dbg("worth grinding failed: " .. tostring(res)) end
    end
    if worth then
        for _, l in ipairs(worth) do tt:AddLine(l[1], l[2], l[3], l[4], true) end
    end
    local objq = SFP.QuestObjectiveNpc and SFP:QuestObjectiveNpc(id)
    if objq then
        for i = 1, min(4, #objq) do tt:AddLine("|cffffd24aQuest|r " .. objq[i], 1, 0.9, 0.5, true) end
    end
    if not shown then
        tt:AddLine("No drops learned yet - kill it and loot to record them", 0.5, 0.5, 0.5, true)
    end
    tt:Show()
end

-- the item block's own header is exactly "Seviaths" (the farm-info block says "SeviathsUsefulTools")
local function hasItemBlock(tt)
    local n = tonumber(tt.NumLines and tt:NumLines()) or 0
    for i = n, 1, -1 do
        local fs = _G[(tt:GetName() or "GameTooltip") .. "TextLeft" .. i]
        local t = fs and fs.GetText and fs:GetText()
        if type(t) == "string" and not (issecretvalue and issecretvalue(t)) and t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") == "Seviaths" then return true end
    end
    return false
end

-- tooltip:GetItem() can fail on some tooltips (comparison / quest reward tooltips): never let it throw
local function tipItemLink(tt)
    if not (tt and tt.GetItem) then return nil end
    local ok, _, link = pcall(tt.GetItem, tt)
    if ok and type(link) == "string" and not (issecretvalue and issecretvalue(link)) then return link end
end

local function itemTip(tt, data)
    if not SFP.db or not SFP.db.tooltip then return end
    if hasItemBlock(tt) then return end
    local id = data and data.id
    if issecretvalue and issecretvalue(id) then return end
    if not id then id = itemIDFromLink(tipItemLink(tt)) end
    if not id then return end
    local link = data and data.hyperlink
    if issecretvalue and issecretvalue(link) then link = nil end
    if not link then link = tipItemLink(tt) end
    -- the auction price right under the normal sell price (the first thing added), not at the bottom of the block; farm items show it in
    -- their own block
    if SFP.GetPrice and not (SFP.trackedIDs and SFP.trackedIDs[id]) then
        local ahp = SFP:GetPrice(id)
        if ahp and ahp > 0 then
            tt:AddLine("|cff66e6ffAuction price:|r " .. SFP:FormatPrice(ahp), 1, 1, 1)
            local stack = SFP:StackCount(id)
            if stack and stack > 1 then
                tt:AddLine(("|cff66e6ffAuction price (stack of %d):|r "):format(stack) .. SFP:FormatPrice(ahp * stack), 1, 1, 1)
            end
        end
    end
    local lines = SFP:ItemTipLines(id, link)
    if #lines == 0 then tt:Show() return end
    tt:AddLine(" ")
    tt:AddLine("|c" .. SFP.CYAN_HEX .. "Seviaths|r")
    for _, l in ipairs(lines) do
        tt:AddLine(l[1], l[2] or 1, l[3] or 1, l[4] or 1, l[5] and true or false)
    end
    tt:Show()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "LOOT_READY", "UNIT_SPELLCAST_SENT",
    "GET_ITEM_INFO_RECEIVED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "BAG_UPDATE_DELAYED", "MERCHANT_SHOW",
    "MERCHANT_UPDATE", "BLACK_MARKET_OPEN", "PERKS_PROGRAM_OPEN", "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED",
    "PLAYERREAGENTBANKSLOTS_CHANGED", "BANK_TAB_SETTINGS_UPDATED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
local recipeTimer
local vendorTimer, bankTimer
ev:SetScript("OnEvent", function(_, event, a, b, c, d)
    -- "Learn everything constantly" off: nothing new is recorded (tooltips keep working)
    if SFP.db and SFP.db.learnAll == false and (event == "UPDATE_MOUSEOVER_UNIT" or event == "PLAYER_TARGET_CHANGED"
        or event == "LOOT_READY" or event == "BAG_UPDATE_DELAYED" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE"
        or event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" or event == "BLACK_MARKET_OPEN" or event == "PERKS_PROGRAM_OPEN"
        or event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERREAGENTBANKSLOTS_CHANGED"
        or event == "BANK_TAB_SETTINGS_UPDATED") then
        return
    end
    if not SFP.db then return end
    if event == "UPDATE_MOUSEOVER_UNIT" then
        SFP:Safe("record mouseover", recordUnit, "mouseover")
        C_Timer.After(0.05, function()
            if GameTooltip:IsShown() and UnitExists("mouseover") then SFP:Safe("monster tooltip", unitTip, GameTooltip) end
        end)
    elseif event == "PLAYER_TARGET_CHANGED" then
        SFP:Safe("record target", recordUnit, "target")
    elseif event == "LOOT_READY" then
        SFP:Safe("record loot", onLoot)
    elseif event == "UNIT_SPELLCAST_SENT" then
        -- the game hides some of these values (secret): then there is simply nothing to remember
        local function open(v) return not (issecretvalue and issecretvalue(v)) end
        if open(a) and a == "player" then
            local spellID = d or c
            local nm = open(spellID) and type(spellID) == "number" and spellName(spellID)
            if nm and open(nm) and (gatherNames[nm] or skinNames[nm]) then
                lastCast.name, lastCast.target, lastCast.t = nm, open(b) and b or nil, GetTime()
            end
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if a and pendingItems[a] then recordItem(a) end
    elseif event == "BAG_UPDATE_DELAYED" then
        -- items that arrived another way (mail, quests, vendors) are learned too
        SFP:Safe("record bags", function()
            -- the backpack, the four bag slots and the reagent bag
            for bag = 0, ((Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5) do
                local n = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
                    or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
                for slot = 1, n do
                    local link = C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)
                        or (GetContainerItemLink and GetContainerItemLink(bag, slot))
                    local id = itemIDFromLink(link)
                    if id and not SFP.db.knownItems[id] then recordItem(id) end
                end
            end
        end)
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" or event == "BLACK_MARKET_OPEN" or event == "PERKS_PROGRAM_OPEN" then
        -- every item any kind of vendor sells is learned too (name, class, materials become farm items), a few at a time:
        -- normal and currency vendors, the black market and the Trading Post
        if vendorTimer then return end
        vendorTimer = true
        -- who and where: the vendor's name and the spot you stand at (the vendor is next to you)
        local vName, vMap, vx, vy
        do
            local okN, nm = pcall(UnitName, "npc")
            if okN and type(nm) == "string" and not (issecretvalue and issecretvalue(nm)) then vName = nm end
            local m = C_Map.GetBestMapForUnit("player")
            local pos = m and C_Map.GetPlayerMapPosition(m, "player")
            if pos and pos.GetXY then
                local px, py = pos:GetXY()
                if px and not (issecretvalue and issecretvalue(px)) and px > 0 then vMap, vx, vy = m, px, py end
            end
        end
        C_Timer.After(0.6, function()
            vendorTimer = nil
            local ids = {}
            local function addID(id) if type(id) == "number" and id > 0 and not SFP.db.knownItems[id] then ids[#ids + 1] = id end end
            if GetMerchantNumItems then
                for i = 1, (GetMerchantNumItems() or 0) do
                    addID(GetMerchantItemID and GetMerchantItemID(i) or itemIDFromLink(GetMerchantItemLink and GetMerchantItemLink(i)))
                end
            end
            if C_BlackMarket and C_BlackMarket.GetNumItems and C_BlackMarket.GetItemInfoByIndex then
                for i = 1, (C_BlackMarket.GetNumItems() or 0) do
                    local ok, info = pcall(C_BlackMarket.GetItemInfoByIndex, i)
                    if ok and type(info) == "table" then addID(info.itemID) end
                end
            end
            if C_PerksProgram and C_PerksProgram.GetAvailableVendorItemIDs and C_PerksProgram.GetVendorItemInfo then
                local okL, list = pcall(C_PerksProgram.GetAvailableVendorItemIDs)
                if okL and type(list) == "table" then
                    for _, vid in ipairs(list) do
                        local okI, info = pcall(C_PerksProgram.GetVendorItemInfo, vid)
                        if okI and type(info) == "table" then addID(info.itemID) end
                    end
                end
            end
            -- collectables and other things the vendor sells are learned with the vendor's name and place:
            -- mounts, pets, toys, housing decor and recipes (the collection planner uses them for waypoints)
            local all, costOf = {}, {}
            -- what an item costs: gold, and every currency or item it also takes (crests, tokens ...)
            local function costText(k)
                local parts = {}
                local price, ext
                if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
                    local okI, info = pcall(C_MerchantFrame.GetItemInfo, k)
                    if okI and type(info) == "table" then price, ext = info.price, info.hasExtendedCost end
                elseif GetMerchantItemInfo then
                    local _, _, p, _, _, _, _, e2 = GetMerchantItemInfo(k)
                    price, ext = p, e2
                end
                if type(price) == "number" and price > 0 then parts[#parts + 1] = math.floor(price / 10000) .. "g " .. (math.floor(price / 100) % 100) .. "s" end
                if ext and GetMerchantItemCostInfo and GetMerchantItemCostItem then
                    for j = 1, (GetMerchantItemCostInfo(k) or 0) do
                        local _, value, link, currencyName = GetMerchantItemCostItem(k, j)
                        local nm = currencyName or (type(link) == "string" and link:match("%[(.-)%]")) or "?"
                        if type(value) == "number" and value > 0 then parts[#parts + 1] = value .. " " .. nm end
                    end
                end
                return #parts > 0 and table.concat(parts, " + ") or nil
            end
            if GetMerchantNumItems then
                for k = 1, (GetMerchantNumItems() or 0) do
                    local id = GetMerchantItemID and GetMerchantItemID(k)
                    if type(id) == "number" and id > 0 then
                        all[#all + 1] = id
                        costOf[id] = costOf[id] or costText(k)
                    end
                end
            end
            local seen = {}
            local function learnKind(id)
                if seen[id] then return end
                seen[id] = true
                local kind, mountID
                if C_MountJournal and C_MountJournal.GetMountFromItem then
                    local ok, mid = pcall(C_MountJournal.GetMountFromItem, id)
                    if ok and type(mid) == "number" and mid > 0 then kind, mountID = "mount", mid end
                end
                if not kind and C_PetJournal and C_PetJournal.GetPetInfoByItemID then
                    local ok, nm = pcall(C_PetJournal.GetPetInfoByItemID, id)
                    if ok and nm then kind = "pet" end
                end
                if not kind and C_ToyBox and C_ToyBox.GetToyInfo then
                    local ok, tid = pcall(C_ToyBox.GetToyInfo, id)
                    if ok and tid then kind = "toy" end
                end
                if not kind and C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
                    local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, id, true)
                    if ok and type(info) == "table" then kind = "decor" end
                end
                if not kind then
                    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(id)
                    if classID == 9 then kind = "recipe" end
                end
                kind = kind or "item"   -- every other item too: gear, soulbound items, materials, consumables, anything a vendor sells
                if vName and vMap then
                    SFP.db.vendorLearned = SFP.db.vendorLearned or {}
                    local rec = SFP.db.vendorLearned[id]
                    local here = { v = vName, m = vMap, x = vx, y = vy, c = costOf[id] }
                    if not rec then
                        SFP.db.vendorLearned[id] = { k = kind, v = vName, m = vMap, x = vx, y = vy, mount = mountID, c = costOf[id] }
                    else
                        -- already known: the cost is refreshed, and a second and third vendor that sells it are kept
                        if costOf[id] and rec.v == vName then rec.c = costOf[id] end
                        if rec.v ~= vName then
                            rec.more = rec.more or {}
                            local have = false
                            for _, o in ipairs(rec.more) do if o.v == vName then have = true; o.c = costOf[id] or o.c end end
                            if not have and #rec.more < 2 then rec.more[#rec.more + 1] = here end
                        end
                    end
                    if (kind == "mount" or kind == "pet" or kind == "toy") and SFP.Items and not SFP.Items[id] then
                        SFP.Items[id] = { kind = kind, note = "Sold by " .. vName, fromVendor = true }
                        if SFP.trackedIDs then SFP.trackedIDs[id] = true end
                    end
                end
            end
            for _, id in ipairs(all) do learnKind(id) end
            local i = 1
            local function step()
                for _ = 1, 20 do
                    if i > #ids then return end
                    if not SFP.db.knownItems[ids[i]] then recordItem(ids[i]) end
                    i = i + 1
                end
                if i <= #ids then C_Timer.After(0.1, step) end
            end
            if #ids > 0 then SFP:Safe("record vendor items", step) end
        end)
    elseif event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERREAGENTBANKSLOTS_CHANGED"
        or event == "BANK_TAB_SETTINGS_UPDATED" then
        -- the items in your bank, reagent bank and warband (account) bank are learned too
        if bankTimer then return end
        bankTimer = true
        C_Timer.After(0.8, function()
            bankTimer = nil
            local bags = {}
            if Enum and Enum.BagIndex then
                for name, idx in pairs(Enum.BagIndex) do
                    if type(name) == "string" and type(idx) == "number"
                        and (name:find("Bank") or name:find("Reagent") or name:find("Account")) then
                        bags[#bags + 1] = idx
                    end
                end
            else
                bags = { -1, 5, 6, 7, 8, 9, 10, 11, -3 }
            end
            table.sort(bags)
            local ids = {}
            for _, bag in ipairs(bags) do
                local n = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
                for slot = 1, (tonumber(n) or 0) do
                    local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
                    local id = type(info) == "table" and info.itemID
                    if type(id) == "number" and id > 0 and not SFP.db.knownItems[id] then ids[#ids + 1] = id end
                end
            end
            local i = 1
            local function step()
                for _ = 1, 25 do
                    if i > #ids then return end
                    if not SFP.db.knownItems[ids[i]] then recordItem(ids[i]) end
                    i = i + 1
                end
                if i <= #ids then C_Timer.After(0.1, step) end
            end
            if #ids > 0 then SFP:Safe("record bank items", step) end
        end)
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        if not recipeTimer then
            recipeTimer = true
            C_Timer.After(1.5, function() recipeTimer = nil; SFP:Safe("scan recipes", scanRecipes) end)
        end
    end
end)

SFP:OnLogin(function()
    -- older versions saved every recipe of an opened profession, learned or not, and the seed data added recipes of another
    -- account: the list starts again once and from now on holds only recipes this account's characters really learned
    if (SFP.db.recipesVersion or 0) < 2 then
        SFP.db.recipes = {}
        SFP.db.recipesVersion = 2
        SFP.usedIn, SFP.madeBy = nil, nil
    end
    initSpellNames()
    buildSeeds()
    -- the collectables learned from vendors join the item list again after each login
    for id, v in pairs(SFP.db.vendorLearned or {}) do
        if (v.k == "mount" or v.k == "pet" or v.k == "toy") and SFP.Items and not SFP.Items[id] then
            SFP.Items[id] = { kind = v.k, note = "Sold by " .. tostring(v.v), fromVendor = true }
            if SFP.trackedIDs then SFP.trackedIDs[id] = true end
        end
    end
    -- the materials of the recipes already saved are learned too (a few at a time, after the game has loaded)
    C_Timer.After(25, function()
        -- the ids first (cheap: no item record is read), then each one is checked against the known items within a time budget per frame
        local cand, seen = {}, {}
        local function add(id)
            if id and not seen[id] then seen[id] = true; cand[#cand + 1] = id end
        end
        for _, r in pairs(SFP.db.recipes or {}) do
            for _, rg in ipairs(r.r or {}) do add(rg[1]) end
        end
        -- and the materials of EVERY crafting profession, from the shipped recipe data (Alchemy to Tailoring), opened or not
        for _, r in ipairs(SFP.RecipeData or {}) do
            for _, rg in ipairs(r[5] or {}) do add(rg[1]) end
        end
        local i = 1
        local function step()
            local t0 = debugprofilestop()
            while cand[i] and debugprofilestop() - t0 < 3 do
                local id = cand[i]
                if not SFP.db.knownItems[id] then SFP.LearnMaterial(id) end
                i = i + 1
            end
            if cand[i] then C_Timer.After(0.1, step) end
        end
        step()
    end)
    -- items we already know that are materials join the farm list straight away
    -- (in the background, a few hundred per frame, one record read at a time: nothing is read all at once at login)
    C_Timer.After(20, function()
        local ids = SeviathsKeys(SFP.db.knownItems)
        local i = 1
        local function step()
            -- a time budget per frame, not a count: a record may have to be decoded when it is read
            local t0 = debugprofilestop()
            while i <= #ids and debugprofilestop() - t0 < 4 do
                SFP:ClassifyItem(ids[i])
                i = i + 1
            end
            if i <= #ids then C_Timer.After(0.05, step) end
        end
        step()
    end)
    local TT = Enum and Enum.TooltipDataType
    local okUnit, okItem = false, false
    if TooltipDataProcessor and TT and TT.Unit then
        okUnit = pcall(TooltipDataProcessor.AddTooltipPostCall, TT.Unit, function(tt, data) if tt == GameTooltip then SFP:Safe("unit tooltip", unitTip, tt, data) end end)
    end
    if TooltipDataProcessor and TT and TT.Object then
        pcall(TooltipDataProcessor.AddTooltipPostCall, TT.Object, function(tt, data) if tt == GameTooltip then SFP:Safe("object tooltip", objectTip, tt, data) end end)
    end
    if TooltipDataProcessor and TT and TT.Item then
        okItem = pcall(TooltipDataProcessor.AddTooltipPostCall, TT.Item, function(tt, data) if tt == GameTooltip or tt == ItemRefTooltip then SFP:Safe("item tooltip", itemTip, tt, data) end end)
    end
    -- both hooks may fire: once per tooltip is enough
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tt) unitTip(tt) end)
    if not okItem then pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", itemTip) end
end)

---------------------------------------------------------------------------
-- Codex bridge: what you met becomes Codex pages (called while the Codex indexes)
---------------------------------------------------------------------------
-- the expansion a zone belongs to, by the continent it is on (Midnight zones by name: they share continents with older ones)
local EXP_BY_CONTINENT = {
    ["eastern kingdoms"] = "Classic", ["kalimdor"] = "Classic", ["outland"] = "The Burning Crusade", ["northrend"] = "Wrath of the Lich King",
    ["the maelstrom"] = "Cataclysm", ["pandaria"] = "Mists of Pandaria", ["draenor"] = "Warlords of Draenor",
    ["broken isles"] = "Legion", ["argus"] = "Legion", ["zandalar"] = "Battle for Azeroth", ["kul tiras"] = "Battle for Azeroth",
    ["shadowlands"] = "Shadowlands", ["dragon isles"] = "Dragonflight", ["khaz algar"] = "The War Within",
}
local EXP_BY_ZONE = {
    ["eversong woods"] = "Midnight", ["silvermoon city"] = "Midnight", ["zul'aman"] = "Midnight", ["harandar"] = "Midnight",
    ["voidstorm"] = "Midnight", ["ghostlands"] = "Midnight",
}
local expCache = {}
function SFP:ExpansionOfMap(map)
    if not map then return "Other" end
    if expCache[map] then return expCache[map] end
    local result
    local m, guard = map, 0
    local first = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    if first and first.name and EXP_BY_ZONE[first.name:lower()] then result = EXP_BY_ZONE[first.name:lower()] end
    while not result and m and guard < 10 do
        local info = C_Map.GetMapInfo(m)
        if not info then break end
        if info.name and EXP_BY_ZONE[info.name:lower()] then result = EXP_BY_ZONE[info.name:lower()] break end
        if Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Continent then
            result = EXP_BY_CONTINENT[(info.name or ""):lower()]
            break
        end
        m = info.parentMapID
        guard = guard + 1
    end
    result = result or "Other"
    expCache[map] = result
    return result
end

function SFP:FeedLearned(cx)
    if not (cx and cx.Add and self.db) then return end
    local c = cx.CYAN or ""
    local function dropText(tbl, kills)
        local list = {}
        for itemID, n in pairs(tbl or {}) do list[#list + 1] = { itemID, n } end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        local out = {}
        for i = 1, min(12, #list) do
            local chance = SFP.ChanceText(list[i][2], kills)
            out[#out + 1] = "• " .. self:ItemName(list[i][1]) .. (chance ~= "" and ("  " .. chance) or ("  %d%%"):format(min(100, floor(list[i][2] * 100 / max(1, kills) + 0.5))))
        end
        return table.concat(out, "\n")
    end
    for id, rec in pairs(self.db.npcs) do
        local where = {}
        local mapFirst
        for map, pts in pairs(rec.m or {}) do
            where[#where + 1] = self:ZoneName(map)
            mapFirst = mapFirst or { map, pts[1] }
        end
        local lvl = rec.lmin and (rec.lmin == rec.lmax and tostring(rec.lmin) or (rec.lmin .. "-" .. rec.lmax)) or "?"
        local body = c .. "Monster|r  ID " .. id .. "\n" ..
            "Level " .. lvl .. (rec.t and ("  " .. rec.t) or "") .. (rec.f and ("  " .. rec.f) or "") ..
            (rec.c and ("  " .. rec.c) or "") ..
            (#where > 0 and ("\n\n" .. c .. "Found in|r\n" .. table.concat(where, ", ")) or "") ..
            ((rec.d and next(rec.d)) and ("\n\n" .. c .. "Drops|r\n" .. dropText(rec.d, rec.k)) or "") ..
            ((rec.s and next(rec.s)) and ("\n\n" .. c .. "Skinning|r\n" .. dropText(rec.s, rec.sk)) or "")
        -- a monster is one that was fought (kills, drops); the rest (vendors, trainers, quest givers, passers-by) are NPCs
        local fought = (rec.k or 0) > 0 or (rec.d and next(rec.d)) or (rec.s and next(rec.s))
        cx:Add({
            cat = fought and "creature" or "npc", id = "sut:npc:" .. id, name = rec.n,
            group = fought and self:ExpansionOfMap(mapFirst and mapFirst[1]) or (where[1] or "Other"),   -- monsters by expansion, NPCs by place
            icon = "Interface\\Icons\\Ability_Warrior_Revenge",
            sub = lvl .. (rec.t and (" " .. rec.t) or ""), body = body,
            map = mapFirst and { m = mapFirst[1], x = mapFirst[2][1], y = mapFirst[2][2] } or nil,
            wh = "npc=" .. id, tags = "monster npc " .. (rec.t or "") .. " " .. (rec.f or ""),
        })
    end
    local usedIn = self:RecipeIndex()
    for itemID, keys in pairs(usedIn) do
        local name = C_Item.GetItemInfo(itemID)
        if name then
            cx:Add({
                cat = "material", id = "sut:mat:" .. itemID, name = name, group = "What it is used for",
                icon = "Interface\\Icons\\INV_Misc_Herb_Felblossom", itemID = itemID,
                sub = #keys .. " recipes", body = c .. "Used in|r\n" .. recipeTexts(keys, 40):gsub(", ", "\n"),
                wh = "item=" .. itemID, tags = "material reagent mats",
            })
        end
    end
end
