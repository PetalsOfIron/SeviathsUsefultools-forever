-- SeviathsUsefulTools - auction house prices
-- The first time you open the auction house (and again when prices are older
-- than db.rescanHours) every tracked item is looked up once, throttled, and the
-- cheapest unit price is saved. /sfp scan forces a new scan.

local _, SFP = ...

local queue, qIndex = {}, 0
local scanning, waitingFor, waitTimer = false, nil, nil
local ahOpen = false
local hourTimer   -- starts the next automatic scan when the hour since the last one is over (auction house still open)
local lastFastDone = 0      -- the game keeps sending REPLICATE_ITEM_LIST_UPDATE for a while after a scan: those must not start another
local fastRunning = false   -- a fast scan is waiting for the game or reading its answer: the item-by-item scan must stay out of it

-- what the scan bar on the auction house window shows (AuctionBar.lua draws it)
local function setProgress(phase, done, total)
    local old = SFP.scanState
    SFP.scanState = { phase = phase, done = done or 0, total = total or 0,
        t0 = (phase == "wait" and GetTime()) or (old and old.t0) or GetTime(), t = GetTime() }
    if SFP.UpdateScanBar then SFP:UpdateScanBar() end
end

local function buildQueue()
    wipe(queue)
    -- one-by-one search is slow (the game throttles it): only the farm items themselves, never every item ever seen
    for id in pairs(SFP.trackedIDs) do
        if SFP.RETAIL == nil or SFP.Items[id] then queue[#queue + 1] = id end
    end
    table.sort(queue)
    qIndex = 0
end

local function savePrice(itemID, copper)
    if not itemID then return end
    SFP:StorePrice(itemID, copper)
end

local function markScanned()
    if SFP.Social and SFP.Social.Count then pcall(SFP.Social.Count, "scan") end   -- for the automatic play style
    local t = time()
    SFP.db.lastScan = t
    SFP.db.realmScan = SFP.db.realmScan or {}
    SFP.db.realmScan[SFP:RealmKey()] = t
    -- the planners and the Codex show prices: let them redraw with the new ones
    if SFP.PricesChanged then SFP:Safe("prices changed", SFP.PricesChanged, SFP) end
end

-- the ingredients and products of every crafting recipe are priced by the scans too (Recipe Planner profit)
local craftIDs
local function isCraftID(id)
    if not craftIDs then
        craftIDs = {}
        for _, r in ipairs(SFP.RecipeData or {}) do
            if r[4] and r[4] > 0 then craftIDs[r[4]] = true end
            for _, rg in ipairs(r[5] or {}) do craftIDs[rg[1]] = true end
        end
    end
    return craftIDs[id] and true or false
end

-- the products of the recipes: their cheapest listings are kept one by one (the profession window lists them)
local productIDs
local function isProductID(id)
    if not productIDs then
        productIDs = {}
        for _, r in ipairs(SFP.RecipeData or {}) do
            if r[4] and r[4] > 0 then productIDs[r[4]] = true end
        end
    end
    return productIDs[id] and true or false
end

local step  -- forward declared

local function finishItem()
    if waitTimer then waitTimer:Cancel(); waitTimer = nil end
    waitingFor = nil
    C_Timer.After(0, step)
end

step = function()
    if not scanning or fastRunning then return end
    if not ahOpen then
        scanning = false
        setProgress("idle")
        SFP:Print(string.format("Price scan stopped: %d of %d items scanned (%d%%), %d left. The prices found are saved; it continues next time you open the auction house.",
            qIndex, #queue, math.floor(qIndex * 100 / math.max(1, #queue)), math.max(0, #queue - qIndex)))
        SFP:RefreshAll()
        return
    end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        return -- AUCTION_HOUSE_THROTTLED_SYSTEM_READY resumes us
    end
    qIndex = qIndex + 1
    local id = queue[qIndex]
    if not id and #queue == 0 then
        -- nothing was queued: this is no scan, so it must not count as one (no "done", no new scan time)
        scanning = false
        setProgress("idle")
        return
    end
    if not id then
        scanning = false
        markScanned()
        setProgress("done", #queue, #queue)
        SFP:Print(string.format("Prices updated for %d items.", #queue))
        SFP:RefreshAll()
        return
    end
    waitingFor = id
    setProgress("items", qIndex, #queue)
    local key = C_AuctionHouse.MakeItemKey(id)
    local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
    C_AuctionHouse.SendSearchQuery(key, sorts, true)
    -- nothing listed -> no result event; move on after a short wait
    waitTimer = C_Timer.NewTimer(0.6, finishItem)
    if qIndex % 25 == 0 then
        SFP:RefreshAll()
    end
end

-- full scan: the whole auction house in one request (like other addons), instead of one search per item
local fullWaiting, fullTimer, fullTick = false, nil, nil

local function processReplicate()
    local n = C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetNumReplicateItems() or 0
    local best, i, found, nextPct = {}, 0, 0, 25
    local newIDs, newNames, seenIDs = 0, 0, {}
    local allBest, allCount = {}, 0   -- the cheapest buyout of EVERY item in the auction house (the whole-scan snapshot)
    local listings = {}               -- recipe products: the 6 cheapest buyouts and how many are listed
    local petBest = {}                -- battle pets: the cheapest buyout of each species (all cages share one item ID, the species is in the link)
    local function chunk()
        -- only a few milliseconds of work per frame: the scan runs in the background and the screen never stutters
        local t0 = debugprofilestop and debugprofilestop() or 0
        while i < n and (not debugprofilestop or debugprofilestop() - t0 < 5) do
            local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
            i = i + 1
            -- a gray item is collected (id, name, icon) but its auction price is ignored: the vendor price is what it is worth
            local grey = itemID and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID) == 0
            -- every item seen at the auction house is kept: its ID (with the item class) and its name
            if itemID and SFP.db and not seenIDs[itemID] then
                seenIDs[itemID] = true
                SFP.db.ahItems = SFP.db.ahItems or {}
                if SFP.StoreIcon then SFP:StoreIcon(itemID) end
                if not SFP.db.ahItems[itemID] then
                    local cls = C_Item and C_Item.GetItemInfoInstant and select(6, C_Item.GetItemInfoInstant(itemID))
                    SFP.db.ahItems[itemID] = cls or 0
                    newIDs = newIDs + 1
                end
                if type(name) == "string" and name ~= "" and not (issecretvalue and issecretvalue(name)) then
                    SFP.db.ahNames = SFP.db.ahNames or {}
                    if SFP.db.ahNames[itemID] ~= name then
                        SFP.db.ahNames[itemID] = name
                        newNames = newNames + 1
                    end
                end
            end
            if itemID == 82800 and buyout and buyout > 0 and C_AuctionHouse.GetReplicateItemLink then
                local okL, link = pcall(C_AuctionHouse.GetReplicateItemLink, i - 1)
                local species = okL and type(link) == "string" and not (issecretvalue and issecretvalue(link)) and tonumber(link:match("battlepet:(%d+)"))
                if species and (not petBest[species] or buyout < petBest[species]) then petBest[species] = buyout end
            end
            if itemID and not grey and buyout and buyout > 0 then
                local cur = allBest[itemID]
                if not cur then allBest[itemID] = buyout; allCount = allCount + 1 elseif buyout < cur then allBest[itemID] = buyout end
                if isProductID(itemID) then
                    local l = listings[itemID]
                    if not l then l = { n = 0, p = {} }; listings[itemID] = l end
                    l.n = l.n + 1
                    if not l.max or buyout > l.max then l.max = buyout end   -- the last (dearest) listing
                    local p = l.p
                    -- keep the 6 cheapest, in order
                    local pos = #p + 1
                    for k = 1, #p do if buyout < p[k] then pos = k; break end end
                    if pos <= 6 then
                        table.insert(p, pos, buyout)
                        if #p > 6 then p[#p] = nil end
                    end
                end
            end
            if itemID and not grey and buyout and buyout > 0 and (SFP.trackedIDs[itemID] or isCraftID(itemID)) then
                -- retail lists stackable goods (commodities) per unit already, and every other auction is a single item,
                -- so the buyout is the price of one. (C_AuctionHouse.GetItemCommodityStatus wants an item in your bags,
                -- not an item ID, and made the whole scan fail.)
                local unit = buyout
                if not best[itemID] or unit < best[itemID] then best[itemID] = unit end
            end
        end
        setProgress("read", i, n)
        if i < n then
            C_Timer.After(0, chunk)
        else
            for id, p in pairs(best) do savePrice(id, p); found = found + 1 end
            -- the whole snapshot: every item's price is kept (compact), so any item the scan saw has a price
            SFP.db.ahAll = SFP.db.ahAll or {}
            -- merged into what the realm had: an item not listed this time keeps its earlier price, an item seen now gets the cheapest price of this scan
            local before = SFP.db.ahAll[SFP:RealmKey()]
            if type(before) == "table" then
                for id, p in pairs(before) do if allBest[id] == nil then allBest[id] = p end end
            end
            SFP.db.ahAll[SFP:RealmKey()] = allBest
            if next(petBest) then
                SFP.db.petPrices = SFP.db.petPrices or {}
                -- [speciesID] = copper: merged like the item prices - a pet not listed this time keeps its price until a scan sees it again
                local oldPets = SFP.db.petPrices[SFP:RealmKey()]
                if type(oldPets) == "table" then
                    for sid, p in pairs(oldPets) do if petBest[sid] == nil then petBest[sid] = p end end
                end
                SFP.db.petPrices[SFP:RealmKey()] = petBest
            end
            SFP.db.ahListings = SFP.db.ahListings or {}
            SFP.db.ahListings[SFP:RealmKey()] = listings
            SFP.db.lastScanKind = "fast scan, whole auction house"
            SFP.db.scanLog = nil   -- a fast scan does not use sections
            scanning, fastRunning = false, false
            -- the sections are scanned too, after the fast scan (switch: Settings, "Also scan the sections")
            if SFP.db.autoSections ~= false then
                -- tried again for up to 30 seconds: the window flag or a still-finishing step must not stop the second scan
                local tries = 0
                local function startSections()
                    tries = tries + 1
                    local open = ahOpen or (_G.AuctionHouseFrame and _G.AuctionHouseFrame:IsShown())
                    if not open then SFP:Print("The sections were not read after the fast scan: the auction house window is closed.") return end
                    if scanning then
                        if tries < 20 then C_Timer.After(1.5, startSections)
                        else SFP:Print("The sections were not read after the fast scan: another scan was still running.") end
                        return
                    end
                    SFP:Print("Now reading the sections (second scan)...")
                    if not (SFP.StartCategoryScan and SFP:StartCategoryScan()) then
                        SFP:Print("The section scan could not start (the game gave no category list or refused the search).")
                    end
                end
                C_Timer.After(1.5, startSections)
            end
            lastFastDone = GetTime()
            markScanned()
            setProgress("done", n, n)
            local totalIDs, totalNames = 0, 0
            for _ in pairs(SFP.db.ahItems or {}) do totalIDs = totalIDs + 1 end
            for _ in pairs(SFP.db.ahNames or {}) do totalNames = totalNames + 1 end
            SFP:Print(("Fast scan done: %d auctions read, %d items priced (%d of them farm and crafting items), %d new item IDs (%d saved), %d item names added or updated (%d saved)."):format(
                n, allCount, found, newIDs, totalIDs, newNames, totalNames))
            SFP:RefreshAll()
        end
    end
    -- a failure in the middle of the scan must never leave the scan "running" for good
    local rawChunk = chunk
    chunk = function()
        local ok, err = pcall(rawChunk)
        if not ok then
            scanning, fastRunning = false, false
            setProgress("idle")
            SFP:Print("The fast scan stopped with an error: " .. tostring(err))
        end
    end
    chunk()
end

-- auto = the scan that starts by itself when the auction house opens: it only ever uses the fast scan, which does not touch
-- the Browse window (the section scan searches the auction house itself and moves the list you are looking at)
local autoRetry
function SFP:TryFullScan(auto)
    if not (C_AuctionHouse and C_AuctionHouse.ReplicateItems and C_AuctionHouse.GetReplicateItemInfo) then return false end
    -- the game answers one fast scan request every 15 minutes (the limit is for the whole account); a request inside that
    -- time is ignored without any answer, so none is sent: the addon says so and asks again when the time is over
    local LIMIT = 15 * 60 + 15
    local since = SFP.db and SFP.db.lastReplicate and (time() - SFP.db.lastReplicate) or math.huge
    if since < LIMIT then
        if not auto then
            -- the Scan prices button reads the sections instead: said out loud, so it is clear why the big scan did not run
            self:Print(("No fast scan now: the game allows one every 15 minutes for the whole account, the last one was %d min ago (%d min left). Reading the sections only - they price fewer items than the fast scan."):format(
                math.floor(since / 60), math.ceil((LIMIT - since) / 60)))
            return false
        end
        local wait = LIMIT - since
        self:Print(("The game allows one fast scan every 15 minutes; the last request was %d min ago. The next one starts by itself in %d min while the auction house is open."):format(
            math.floor(since / 60), math.ceil(wait / 60)))
        if autoRetry then autoRetry:Cancel() end
        autoRetry = C_Timer.NewTimer(wait, function()
            if ahOpen and not scanning then SFP:StartScan(true, false, true) end
        end)
        -- the fast scan is not allowed yet, but the sections can be read now
        if SFP.db.autoSections ~= false and not scanning then SFP:StartCategoryScan() end
        return true
    end
    fullWaiting, scanning, fastRunning = true, true, true
    setProgress("wait")
    self:Print("Scanning the auction house in the background...")
    local function failFast(msg)
        fullWaiting, scanning, fastRunning = false, false, false
        if fullTimer then fullTimer:Cancel(); fullTimer = nil end
        setProgress("idle")
        SFP:Print(msg)
        if SFP.db.autoSections ~= false and ahOpen and not scanning then SFP:StartCategoryScan() end
    end
    -- the game drops a request that comes while its message system is busy (right after the window opens): wait until it is ready
    local function send(tries)
        if not fullWaiting then return end
        if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() and tries < 60 then
            C_Timer.After(1, function() send(tries + 1) end)
            return
        end
        SFP.db.lastReplicate = time()
        local ok, err = pcall(C_AuctionHouse.ReplicateItems)
        if not ok then
            failFast("The game refused the fast scan request: " .. tostring(err) .. " - press Scan prices for the section scan.")
        end
    end
    send(0)
    if fullTimer then fullTimer:Cancel() end
    -- no repeating chat messages: the bar at the auction house shows the progress.
    -- A big realm needs time to send the whole auction house: wait up to two minutes (a late answer is still used)
    fullTimer = C_Timer.NewTimer(120, function()
        if fullWaiting then
            fullWaiting, scanning, fastRunning = false, false, false
            setProgress("idle")   -- the bar goes back to showing the last scan time, no green "done"
            if auto then
                -- no answer (the game allows one fast scan every few minutes): wait quietly and ask again, never the section scan
                SFP:Print("The game did not answer the fast scan within 2 minutes (another addon may have used the one request the game allows every 15 minutes). Trying again in 16 minutes while the auction house is open.")
                if autoRetry then autoRetry:Cancel() end
                autoRetry = C_Timer.NewTimer(16 * 60, function()
                    if ahOpen and not scanning then SFP:StartScan(true, false, true) end
                end)
                -- the sections are read meanwhile
                if SFP.db.autoSections ~= false and ahOpen and not scanning then SFP:StartCategoryScan() end
            else
                SFP:Print("No fast scan answer (the game allows one every few minutes) - reading the sections instead.")
                if not SFP:StartCategoryScan() then SFP:StartScan(true, true) end
            end
        end
    end)
    return true
end

-- section scan, the way Auctionator does it: open each auction house category and read its price list
-- (browse results come in big batches with the lowest price per item), instead of one search per item
local catQueue, catIndex, catSeen, catBest, catTimer, catBusy = {}, 0, 0, {}, nil, false
local catAll = {}   -- the cheapest price of every item the section scan saw (added to the whole-scan snapshot at the end)
local catLearned, catSeenIDs, catNewIDs = 0, {}, 0
local catSentIndex = 0
local catNext
local catPaused, weSending, resumeTimer = false, false, nil   -- the scan steps aside while the player searches by hand

local function catFinish()
    if catTimer then catTimer:Cancel(); catTimer = nil end
    local found = 0
    for id, p in pairs(catBest) do savePrice(id, p); found = found + 1 end
    do
        -- every item the sections showed gets its price in the snapshot (later scans of other sections add to it)
        local snap = SFP:AllPrices(true)
        for id, p in pairs(catAll) do snap[id] = p end
        SFP.db.lastScanKind = ("section scan, %d of %d sections"):format(math.min(catIndex, #catQueue), #catQueue)
    end
    scanning, catBusy = false, false
    markScanned()
    setProgress("done", 1, 1)
    local namesLeft = 0
    local okN, left = pcall(SFP.FillAhNames, SFP, 500)
    if okN and type(left) == "number" then namesLeft = left end
    local saved = 0
    for _ in pairs(SFP.db.ahNames or {}) do saved = saved + 1 end
    local allSeen = 0
    for _ in pairs(catAll) do allSeen = allSeen + 1 end
    do
        -- what each section gave (an empty or unanswered section shows 0): to see whether every section of this auction house was read
        local parts = {}
        for i, cid in ipairs(catQueue) do
            local nm = C_Item and C_Item.GetItemClassInfo and C_Item.GetItemClassInfo(cid) or ("class " .. cid)
            parts[i] = ("%s %d"):format(tostring(nm), (SFP.db.scanLog and SFP.db.scanLog[cid]) or 0)
        end
        SFP:Print("Sections read: " .. table.concat(parts, ", ") .. (catIndex <= #catQueue and "" or "."))
    end
    SFP:Print(("Auction scan done: %d items priced (%d of them farm and crafting items), %d new item IDs%s, %d item names saved%s."):format(allSeen, found, catNewIDs,
        catLearned > 0 and (", " .. catLearned .. " new materials") or "", saved, namesLeft > 0 and (" (" .. namesLeft .. " more loading in the background)") or ""))
    SFP:RefreshAll()
    if SFP.db.longScan then
        -- long scan: after the sections, search every tracked item one by one like the old scan (slow, but exact)
        SFP:Print("Long scan: now scanning each item...")
        C_Timer.After(1, function() SFP:StartScan(true, true) end)
    end
end

local function catRead()
    if not catBusy or catPaused then return end   -- paused: the results on screen are the player's own search
    local results = C_AuctionHouse.GetBrowseResults and C_AuctionHouse.GetBrowseResults() or {}
    for i = catSeen + 1, #results do
        local r = results[i]
        local id = r and r.itemKey and r.itemKey.itemID
        local price = r and r.minPrice
        -- every item ID seen at the auction house is kept (item ID -> item class), so the addon knows them all
        if id and SFP.db then
            SFP.db.ahItems = SFP.db.ahItems or {}
            if not SFP.db.ahItems[id] then
                local cls = C_Item and C_Item.GetItemInfoInstant and select(6, C_Item.GetItemInfoInstant(id))
                SFP.db.ahItems[id] = cls or 0
                catNewIDs = catNewIDs + 1
            end
        end
        -- the auction house also teaches the addon: trade goods it has not seen are added to the learned items (and become farm items)
        local tracked = id and SFP.trackedIDs[id]
        local longScan = SFP.db.longScan
        if longScan and id and SFP.RecordItem and not (SFP.db.knownItems and SFP.db.knownItems[id]) then
            SFP.RecordItem(id)   -- long scan: full details of every item
            catSeenIDs[id] = true
        end
        if id and not tracked and not (SFP.db.knownItems and SFP.db.knownItems[id]) and C_Item and C_Item.GetItemInfoInstant then
            local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(id)
            if classID == 7 and SFP.RecordItem then
                SFP.RecordItem(id)
                tracked = SFP.trackedIDs[id]
                catLearned = catLearned + 1
                catSeenIDs[id] = true
            end
        end
        if id and price and price > 0 and (not catAll[id] or price < catAll[id]) then catAll[id] = price end
        -- battle pets: the species is in the item key; its cheapest price is kept per species
        local species = r and r.itemKey and r.itemKey.battlePetSpeciesID
        if type(species) == "number" and species > 0 and price and price > 0 and not (issecretvalue and issecretvalue(species)) then
            SFP.db.petPrices = SFP.db.petPrices or {}
            local mine = SFP.db.petPrices[SFP:RealmKey()]
            if not mine then mine = {}; SFP.db.petPrices[SFP:RealmKey()] = mine end
            if not mine[species] or price < mine[species] then mine[species] = price end
        end
        if id and price and price > 0 and (tracked or catSeenIDs[id] or longScan or isCraftID(id)) and (not catBest[id] or price < catBest[id]) then catBest[id] = price end
    end
    catSeen = #results
    if catTimer then catTimer:Cancel() end
    catTimer = C_Timer.NewTimer(6, function() catNext() end)
    SFP.db.scanLog = SFP.db.scanLog or {}
    SFP.db.scanLog[catQueue[catIndex] or 0] = #results   -- for diagnosis: results read per section
    if C_AuctionHouse.HasFullBrowseResults and C_AuctionHouse.HasFullBrowseResults() then
        catNext()
    elseif C_AuctionHouse.RequestMoreBrowseResults then
        C_AuctionHouse.RequestMoreBrowseResults()
    else
        catNext()
    end
end

local function catSend()
    if not catBusy or catSentIndex == catIndex then return end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        C_Timer.After(0.3, catSend)   -- the game limits how fast we may ask; try again in a moment
        return
    end
    local cid = catQueue[catIndex]
    catSentIndex = catIndex
    catSeen = 0
    setProgress("section", catIndex, #catQueue)
    weSending = true
    pcall(C_AuctionHouse.SendBrowseQuery, {
        searchString = "", filters = {},
        sorts = { { sortOrder = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0, reverseSort = false } },
        itemClassFilters = { { classID = cid } },
    })
    weSending = false
    if catTimer then catTimer:Cancel() end
    catTimer = C_Timer.NewTimer(4, function() catNext() end)   -- an empty category sends no answer: go on
end

catNext = function()
    if catTimer then catTimer:Cancel(); catTimer = nil end
    catIndex = catIndex + 1
    if catIndex > #catQueue then catFinish(); return end
    catSend()
end

-- the player searches by hand while a section scan runs: the scan waits (it does not read or replace their results)
-- and goes on with the same section a few seconds after their last search
if hooksecurefunc and C_AuctionHouse and C_AuctionHouse.SendBrowseQuery then
    hooksecurefunc(C_AuctionHouse, "SendBrowseQuery", function()
        if not catBusy or weSending then return end
        catPaused = true
        if catTimer then catTimer:Cancel(); catTimer = nil end
        setProgress("wait")
        if resumeTimer then resumeTimer:Cancel() end
        resumeTimer = C_Timer.NewTimer(8, function()
            resumeTimer = nil
            if catBusy and catPaused then
                catPaused = false
                catSentIndex = 0   -- send the current section again
                catSend()
            end
        end)
    end)
end

function SFP:StartCategoryScan()
    local AH = C_AuctionHouse
    if not (AH and AH.SendBrowseQuery and AH.GetBrowseResults and Enum and Enum.ItemClass) then return false end
    wipe(catQueue)
    local seen = {}
    -- the sections the auction house window shows on the left (the game's own category list)
    for _, cat in ipairs(_G.AuctionCategories or {}) do
        local f = cat.filters and cat.filters[1]
        local cid = f and f.classID
        if cid and not seen[cid] then seen[cid] = true; catQueue[#catQueue + 1] = cid end
    end
    -- fallback: every item class the game knows
    if #catQueue == 0 then
        local all = {}
        for _, v in pairs(Enum.ItemClass) do if type(v) == "number" then all[#all + 1] = v end end
        table.sort(all)
        for _, v in ipairs(all) do catQueue[#catQueue + 1] = v end
    end
    if #catQueue == 0 then return false end
    catIndex, catSeen, catBusy, catSentIndex = 0, 0, true, 0
    wipe(catBest)
    wipe(catAll)
    wipe(catSeenIDs)
    SFP.db.scanLog = {}
    catLearned = 0
    catNewIDs = 0
    scanning = true
    self:Print("Scanning the auction house...")
    catNext()
    return true
end

SFP.StopCategoryScan = function()
    if catBusy then
        local done, total = math.max(0, catIndex - 1), #catQueue
        catBusy, scanning, catPaused = false, false, false
        if catTimer then catTimer:Cancel(); catTimer = nil end
        if resumeTimer then resumeTimer:Cancel(); resumeTimer = nil end
        -- keep what was read so far
        local saved = 0
        for id, p in pairs(catBest) do savePrice(id, p); saved = saved + 1 end
        setProgress("idle")
        SFP:Print(string.format("Scan stopped: %d of %d sections read (%d%%), prices saved for %d items. Run the scan again to finish.",
            done, total, math.floor(done * 100 / math.max(1, total)), saved))
    end
end

SFP.CategoryScanEvent = function(event)
    if catBusy and (event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED") then
        -- an error while reading a section must not stop the whole scan: it is said once, the section is left and the scan goes on
        local ok, err = pcall(catRead)
        if not ok then
            SFP:Print("Section scan error (the scan goes on with the next section): " .. tostring(err))
            if catTimer then catTimer:Cancel() end
            catTimer = C_Timer.NewTimer(1, function() catNext() end)
        end
    end
end

-- names of the auction items: saved as the game gives them (the game loads item names a moment after it is asked)
function SFP:FillAhNames(limit)
    if not (self.db and self.db.ahItems) then return 0 end
    self.db.ahNames = self.db.ahNames or {}
    local asked, missing = 0, 0
    for id in pairs(self.db.ahItems) do
        if not self.db.ahNames[id] then
            local nm = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
            if nm and nm ~= "" and not (issecretvalue and issecretvalue(nm)) then
                self.db.ahNames[id] = nm
            else
                missing = missing + 1
                if asked < (limit or 300) and C_Item and C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, id)
                    asked = asked + 1
                end
            end
        end
    end
    return missing
end

local nameFrame = CreateFrame("Frame")
pcall(nameFrame.RegisterEvent, nameFrame, "GET_ITEM_INFO_RECEIVED")
nameFrame:SetScript("OnEvent", function(_, _, id, success)
    if id and success ~= false and SFP.db and SFP.db.ahItems and SFP.db.ahItems[id] then
        SFP.db.ahNames = SFP.db.ahNames or {}
        if not SFP.db.ahNames[id] then
            local nm = C_Item.GetItemNameByID(id)
            if nm and nm ~= "" and not (issecretvalue and issecretvalue(nm)) then SFP.db.ahNames[id] = nm end
        end
        if SFP.StoreIcon then SFP:StoreIcon(id) end
    end
end)
-- keep filling in the background until every item has its name
SFP:OnLogin(function()
    C_Timer.NewTicker(15, function()
        if SFP.db and SFP.db.ahItems then SFP:Safe("auction names", SFP.FillAhNames, SFP, 300) end
    end)
end)

function SFP:StartScan(force, noFull, auto)
    if not ahOpen then
        self:Print("Open the auction house first.")
        return
    end
    if scanning then return end
    -- Auctionator keeps its own scan and GetPrice reads it: nothing to wait for
    if not force and not noFull and Auctionator and Auctionator.API and Auctionator.API.v1 then
        if not self.autoAnnounced then
            self.autoAnnounced = true
            self:Print("Using Auctionator's prices (type /sfp scan to run this addon's own scan).")
        end
        return
    end
    -- the fast scan first (the whole auction house in one request, read in small slices in the background so the game never
    -- freezes); the section scan when the game does not allow it right now
    if auto then
        -- started by itself: only the fast scan, nothing that searches the auction house and moves the Browse list
        if not self:TryFullScan(true) then
            -- no fast scan in this game version: the sections do the work
            if SFP.db.autoSections ~= false then
                self:Print("The fast scan is not available - reading the sections instead.")
                self:StartCategoryScan()
            else
                self:Print("The fast scan is not available - press Scan prices for the section scan.")
            end
        end
        return
    end
    if not noFull then
        if self:TryFullScan() then return end
        if self:StartCategoryScan() then return end
    end
    if not force and qIndex > 0 and qIndex < #queue then
        qIndex = qIndex - 1 -- resume the interrupted scan
    else
        buildQueue()
    end
    scanning = true
    self:Print(string.format("Loading auction house prices for %d farm items...", #queue))
    step()
end

local function spanText(s)
    if s >= 3600 then return ("%.1f h"):format(s / 3600) end
    return math.max(1, math.floor(s / 60)) .. " min"
end

local f = CreateFrame("Frame")
pcall(f.RegisterEvent, f, "AUCTION_HOUSE_SHOW")
pcall(f.RegisterEvent, f, "AUCTION_HOUSE_CLOSED")
pcall(f.RegisterEvent, f, "COMMODITY_SEARCH_RESULTS_UPDATED")
pcall(f.RegisterEvent, f, "ITEM_SEARCH_RESULTS_UPDATED")
pcall(f.RegisterEvent, f, "AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
pcall(f.RegisterEvent, f, "REPLICATE_ITEM_LIST_UPDATE")
pcall(f.RegisterEvent, f, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
pcall(f.RegisterEvent, f, "AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        if SFP.CategoryScanEvent then SFP.CategoryScanEvent(event) end
        return
    end
    if event == "AUCTION_HOUSE_SHOW" then
        ahOpen = true
        -- a scan starts by itself when the auction house opens and the last scan is a day old or more (not at every open);
        -- if the window stays open, the next one starts when the day is over
        local RESCAN = 86400
        local age = time() - SFP:LastScan()
        local stale = SFP:LastScan() == 0 or age >= RESCAN
        local resume = qIndex > 0 and qIndex < #queue
        if not stale then
            if hourTimer then hourTimer:Cancel() end
            hourTimer = C_Timer.NewTimer(math.max(5, RESCAN - age), function()
                if ahOpen and not scanning then SFP:StartScan(true, false, true) end
            end)
        end
        if stale or resume then
            -- forced: it also runs when Auctionator or TSM are installed (their prices are not a reason to skip the scan),
            -- so the "last scan" time on the bar is always the real one
            SFP:Print(SFP.db.autoSections ~= false
                and "Auction house opened - scanning: the whole auction house first (in the background), then every section (the Browse list moves while the sections are read; it waits when you search)."
                or "Auction house opened - starting the fast scan in the background (the Browse list is not touched).")
            C_Timer.After(1, function() SFP:StartScan(true, false, true) end)
        else
            -- say why nothing starts, so a silent chat never looks like a broken scan
            local wait = math.max(1, math.ceil((RESCAN - age) / 60))
            SFP:Print(("Auction prices are fresh (scanned %s ago). The next automatic scan starts in about %s if the auction house stays open, or when you open it after that. Press Scan prices to scan now."):format(
                spanText(age), spanText(RESCAN - age)))
        end
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        if fullWaiting then
            fullWaiting = false
            if fullTimer then fullTimer:Cancel(); fullTimer = nil end
            local got = C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetNumReplicateItems() or 0
            SFP:Print(("The auction house answered: reading %d auctions in the background..."):format(got))
            SFP:Safe("full scan", processReplicate)
        elseif ahOpen and not scanning and GetTime() - lastFastDone > 90 then
            -- another addon (Auctionator, TSM) asked the server for the whole auction house: use that answer too, no extra waiting
            scanning, fastRunning = true, true
            setProgress("wait")
            SFP:Safe("full scan", processReplicate)
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ahOpen = false
        if hourTimer then hourTimer:Cancel(); hourTimer = nil end
        if fastRunning and fullWaiting then
            -- closed while waiting for the game's answer: nothing is running any more
            fastRunning, fullWaiting, scanning = false, false, false
            if fullTimer then fullTimer:Cancel(); fullTimer = nil end
            setProgress("idle")
        end
        if SFP.StopCategoryScan then SFP.StopCategoryScan() end
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if catBusy then
            -- the section scan is running (the item-by-item scan must not take over): send the next request
            if catSentIndex ~= catIndex then catSend()
            elseif C_AuctionHouse.HasFullBrowseResults and not C_AuctionHouse.HasFullBrowseResults() and C_AuctionHouse.RequestMoreBrowseResults then
                C_AuctionHouse.RequestMoreBrowseResults()
            end
        elseif scanning and not waitingFor and not fastRunning then step() end
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local itemID = arg1
        if itemID and C_AuctionHouse.GetNumCommoditySearchResults(itemID) > 0 then
            local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
            if r then savePrice(itemID, r.unitPrice) end
        end
        if scanning and waitingFor == itemID then finishItem() end
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local itemKey = arg1
        local itemID = itemKey and itemKey.itemID
        if itemID and C_AuctionHouse.GetNumItemSearchResults(itemKey) > 0 then
            local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, 1)
            if r and r.buyoutAmount then
                local qty = (r.quantity and r.quantity > 0) and r.quantity or 1
                savePrice(itemID, math.floor(r.buyoutAmount / qty))
            end
        end
        if scanning and waitingFor == itemID then finishItem() end
    end
end)

function SFP:IsScanning() return scanning, qIndex, #queue end

---------------------------------------------------------------------------
-- a small public API: other addons can read this addon's prices and scan time, and get told after a scan
--   local api = _G.SeviathsUsefulToolsAPI
--   api.GetPrice(itemID)            -> copper per unit, or nil
--   api.GetPriceFromLink(itemLink)  -> same, from an item link
--   api.GetLastScanTime()           -> time() of the last scan on this realm, 0 if none
--   api.RegisterCallback(fn)        -> fn() is called every time a scan has updated the prices
-- (this addon itself reads Auctionator and TradeSkillMaster prices when it has no scan of its own)
---------------------------------------------------------------------------
do
    local callbacks = {}
    SFP.API = {
        version = 1,
        GetPrice = function(itemID)
            if not (SFP.db and type(itemID) == "number") then return nil end
            local ok, p = pcall(SFP.GetPrice, SFP, itemID)
            if ok and type(p) == "number" and p > 0 then return p end
            return nil
        end,
        GetPriceFromLink = function(link)
            local id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
            return id and SFP.API.GetPrice(id) or nil
        end,
        GetLastScanTime = function() return SFP.db and SFP:LastScan() or 0 end,
        RegisterCallback = function(fn)
            if type(fn) == "function" then callbacks[#callbacks + 1] = fn end
        end,
        Fire = function()
            for _, fn in ipairs(callbacks) do pcall(fn) end
        end,
    }
    _G.SeviathsUsefulToolsAPI = SFP.API
end
