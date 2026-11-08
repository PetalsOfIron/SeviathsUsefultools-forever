-- SeviathsUsefulTools - what your collections say you already looted
-- The game keeps your transmog appearances, mounts and battle pets, each with where it comes from (a boss, a rare,
-- a zone). That is history from before the addon was installed. It is read once in the background (a few entries at a
-- time, never in combat) and saved account-wide:
--   db.history.items[itemID] = true          items you own the appearance of
--   db.history.by[lower monster name] = { n = name, i = instance/zone, c = transmog items, mounts = {...}, pets = {...} }
-- Monster tooltips say what you already own from that monster. /sfp history shows the numbers.

local _, SFP = ...

local CHUNK = 25          -- appearances per step
local PET_CHUNK = 60
local STEP_DELAY = 0.05
local RESCAN_DAYS = 7

local TC = C_TransmogCollection
local running = false

local function secret(v) return issecretvalue and issecretvalue(v) end

local function hist()
    SFP.db.history = SFP.db.history or { items = {}, by = {}, t = 0, visuals = 0 }
    local h = SFP.db.history
    h.items, h.by, h.boe = h.items or {}, h.by or {}, h.boe or {}
    return h
end

local function record(h, name, zone)
    if type(name) ~= "string" or secret(name) or name == "" then return nil end
    local key = name:lower()
    local rec = h.by[key]
    if not rec then rec = { n = name, c = 0, ids = {} }; h.by[key] = rec end
    if type(zone) == "string" and not secret(zone) and zone ~= "" then rec.i = rec.i or zone end
    return rec
end

local function addUnique(list, v)
    for _, x in ipairs(list) do if x == v then return end end
    list[#list + 1] = v
end

---------------------------------------------------------------------------
-- transmog appearances
---------------------------------------------------------------------------
local function allVisuals()
    local list = {}
    if not (TC and TC.GetCategoryAppearances) then return list end
    for cat = 1, 30 do
        local ok, vis = pcall(TC.GetCategoryAppearances, cat)
        if ok and type(vis) == "table" then
            for _, v in ipairs(vis) do
                if v and v.isCollected and v.visualID then list[#list + 1] = v.visualID end
            end
        end
    end
    return list
end

local function readSource(h, sourceID)
    local ok, info = pcall(TC.GetSourceInfo, sourceID)
    if not ok or type(info) ~= "table" or not info.isCollected or not info.itemID then return end
    h.items[info.itemID] = true
    -- open-world drops are the Bind-on-Equip kind of gear: remember them even when no monster is named
    local WORLD = (Enum and Enum.TransmogSource and Enum.TransmogSource.WorldDrop) or 4
    if info.sourceType == WORLD then h.boe[info.itemID] = true end
    local ok2, drops = pcall(TC.GetAppearanceSourceDrops, sourceID)
    if not ok2 or type(drops) ~= "table" then return end
    for _, d in ipairs(drops) do
        local rec = record(h, d.encounter, d.instance)
        if rec and not rec.ids[info.itemID] then rec.ids[info.itemID] = true; rec.c = rec.c + 1 end
    end
end

---------------------------------------------------------------------------
-- mounts and pets: the source text says "Drop: <monster>" and "Zone: <zone>"
---------------------------------------------------------------------------
local function parseSource(text)
    if type(text) ~= "string" or secret(text) then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", "\n")
    local drop = text:match("Drop:%s*([^\n]+)")
    local zone = text:match("Zone:%s*([^\n]+)")
    return drop, zone
end

local function addCollectible(h, kind, label, sourceText)
    local drop, zone = parseSource(sourceText)
    if not drop then return end
    -- several monsters can be named: "A, B"; the first is enough to recognise one
    for piece in drop:gmatch("[^,/]+") do
        local name = piece:gsub("^%s+", ""):gsub("%s+$", "")
        local rec = record(h, name, zone)
        if rec then
            rec[kind] = rec[kind] or {}
            addUnique(rec[kind], label)
        end
    end
end

local function readMounts(h)
    local MJ = C_MountJournal
    if not (MJ and MJ.GetMountIDs and MJ.GetMountInfoByID and MJ.GetMountInfoExtraByID) then return end
    local ok, ids = pcall(MJ.GetMountIDs)
    if not ok or type(ids) ~= "table" then return end
    for _, mountID in ipairs(ids) do
        local ok1, name, _, _, _, _, _, _, _, _, _, isCollected = pcall(MJ.GetMountInfoByID, mountID)
        if ok1 and isCollected and type(name) == "string" and not secret(name) then
            local ok2, _, _, sourceText = pcall(MJ.GetMountInfoExtraByID, mountID)
            if ok2 then addCollectible(h, "mounts", name, sourceText) end
        end
    end
end

local function readPets(h, done)
    local PJ = C_PetJournal
    if not (PJ and PJ.GetOwnedPetIDs and PJ.GetPetInfoByPetID) then return done() end
    local ok, ids = pcall(PJ.GetOwnedPetIDs)
    if not ok or type(ids) ~= "table" then return done() end
    local i, total, seen = 1, #ids, {}
    local function step()
        local stop = math.min(total, i + PET_CHUNK - 1)
        while i <= stop do
            -- name, icon, petType, creatureID, sourceText are the 8th..12th results
            local ok1, speciesID, _, _, _, _, _, _, name, _, _, _, sourceText = pcall(PJ.GetPetInfoByPetID, ids[i])
            if ok1 and speciesID and not seen[speciesID] and type(name) == "string" and not secret(name) then
                seen[speciesID] = true
                addCollectible(h, "pets", name, sourceText)
            end
            i = i + 1
        end
        if i <= total then C_Timer.After(STEP_DELAY, step) else done() end
    end
    step()
end

---------------------------------------------------------------------------
-- has the collection changed since the last read?
---------------------------------------------------------------------------
function SFP:CountMounts()
    local MJ = C_MountJournal
    if not (MJ and MJ.GetMountIDs and MJ.GetMountInfoByID) then return 0 end
    local ok, ids = pcall(MJ.GetMountIDs)
    if not ok or type(ids) ~= "table" then return 0 end
    local n = 0
    for _, id in ipairs(ids) do
        local ok1, _, _, _, _, _, _, _, _, _, _, collected = pcall(MJ.GetMountInfoByID, id)
        if ok1 and collected then n = n + 1 end
    end
    return n
end

function SFP:CountPets()
    local PJ = C_PetJournal
    if not (PJ and PJ.GetOwnedPetIDs) then return 0 end
    local ok, ids = pcall(PJ.GetOwnedPetIDs)
    return (ok and type(ids) == "table") and #ids or 0
end

function SFP:HistoryChanged()
    local h = self.db and self.db.history
    if not h or not h.t or h.t == 0 then return true end
    return (h.nMounts or -1) ~= self:CountMounts() or (h.nPets or -1) ~= self:CountPets()
end

---------------------------------------------------------------------------
-- the scan
---------------------------------------------------------------------------
function SFP:ScanTransmogHistory(force)
    if running or not self.db then return end
    local h = hist()
    if not force and h.t and (time() - h.t) < RESCAN_DAYS * 86400 and not SFP:HistoryChanged() then return end
    running = true
    local function finish()
        h.t = time()
        h.nMounts, h.nPets = SFP:CountMounts(), SFP:CountPets()
        running = false
        if SFP.db.historyReport then
            local n = 0
            for _ in pairs(h.by) do n = n + 1 end
            SFP:Print(("Collections read: %d monsters and bosses you already own something from."):format(n))
        end
    end
    local function collections()
        pcall(readMounts, h)
        readPets(h, finish)
    end
    if not (TC and TC.GetAllAppearanceSources and TC.GetSourceInfo) then return collections() end
    local visuals = allVisuals()
    local i, total = 1, #visuals
    h.visuals = total
    local function step()
        if InCombatLockdown() then C_Timer.After(5, step); return end
        local stop = math.min(total, i + CHUNK - 1)
        while i <= stop do
            local ok, sources = pcall(TC.GetAllAppearanceSources, visuals[i])
            if ok and type(sources) == "table" then
                for _, sid in ipairs(sources) do readSource(h, sid) end
            end
            i = i + 1
        end
        if i <= total then C_Timer.After(STEP_DELAY, step) else collections() end
    end
    step()
end

---------------------------------------------------------------------------
-- do you own this mount / pet / toy item? true / false, nil when it is none of those or unknown
---------------------------------------------------------------------------
function SFP:OwnedStatus(itemID)
    local info = self.Items and self.Items[itemID]
    local kind = info and info.kind
    if C_Item and C_Item.RequestLoadItemDataByID and (kind == "mount" or kind == "pet" or kind == "toy") then
        pcall(C_Item.RequestLoadItemDataByID, itemID)   -- the game answers a moment later; the lists refresh
    end
    if kind == "mount" and C_MountJournal then
        local mountID
        if C_MountJournal.GetMountFromItem then
            local ok, id = pcall(C_MountJournal.GetMountFromItem, itemID)
            if ok then mountID = id end
        end
        -- some mount items are only known through the spell they teach
        if not mountID and C_MountJournal.GetMountFromSpell and C_Item and C_Item.GetItemSpell then
            local okS, _, spellID = pcall(C_Item.GetItemSpell, itemID)
            if okS and spellID then
                local okM, id = pcall(C_MountJournal.GetMountFromSpell, spellID)
                if okM then mountID = id end
            end
        end
        if mountID then
            local ok2, _, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, mountID)
            if ok2 then return collected and true or false end
        end
    elseif kind == "pet" and C_PetJournal and C_PetJournal.GetPetInfoByItemID then
        local ok, _, _, _, _, _, _, _, _, _, _, _, _, speciesID = pcall(C_PetJournal.GetPetInfoByItemID, itemID)
        if ok and speciesID and C_PetJournal.GetNumCollectedInfo then
            local ok2, n = pcall(C_PetJournal.GetNumCollectedInfo, speciesID)
            if ok2 and n then return n > 0 end
        end
    elseif kind == "toy" and PlayerHasToy then
        local ok, has = pcall(PlayerHasToy, itemID)
        if ok then return has and true or false end
    end
    return nil
end

-- what you already own from this monster or boss (nil when nothing is known)
function SFP:HistoryFor(name)
    local h = self.db and self.db.history
    if not (h and h.by) or type(name) ~= "string" or secret(name) then return nil end
    local rec = h.by[name:lower()]
    if rec and (rec.c > 0 or rec.mounts or rec.pets) then return rec end
end

-- one tooltip sentence for a record
function SFP:HistoryText(rec)
    local parts = {}
    if rec.c and rec.c > 0 then parts[#parts + 1] = ("%d item%s"):format(rec.c, rec.c == 1 and "" or "s") end
    if rec.mounts then parts[#parts + 1] = "the mount " .. table.concat(rec.mounts, ", ") end
    if rec.pets then parts[#parts + 1] = "the pet " .. table.concat(rec.pets, ", ") end
    return "You already own " .. table.concat(parts, " and ") .. " from this monster" .. (rec.i and (" (" .. rec.i .. ")") or "")
end

SFP:OnLogin(function()
    local first = not (SFP.db.history and SFP.db.history.t and SFP.db.history.t > 0)
    -- first start after the install: everything is read automatically in the background, nothing is written to the chat
    -- wait until the game is settled, then read in the background (only what is new or changed)
    C_Timer.After(first and 20 or 40, function()
        SFP:Safe("collection history", SFP.ScanTransmogHistory, SFP)
    end)
end)

-- keep it current while you play: new appearances, mounts and pets are added the moment you get them
local ev = CreateFrame("Frame")
for _, e in ipairs({ "TRANSMOG_COLLECTION_SOURCE_ADDED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, arg)
    if not SFP.db or SFP.db.learnAll == false then return end
    SFP:Safe("collection history update", function()
        local h = hist()
        if event == "TRANSMOG_COLLECTION_SOURCE_ADDED" and type(arg) == "number" and TC and TC.GetSourceInfo then
            readSource(h, arg)
        elseif event == "NEW_MOUNT_ADDED" then
            readMounts(h)
            h.nMounts = SFP:CountMounts()
        elseif event == "NEW_PET_ADDED" then
            C_Timer.After(1, function() SFP:Safe("pets", readPets, h, function() h.nPets = SFP:CountPets() end) end)
        end
    end)
end)
