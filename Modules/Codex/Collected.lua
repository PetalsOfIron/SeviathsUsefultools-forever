-- Seviath's Codex — what was collected in the game (and shipped with the addon): towns, NPCs, nodes, and the items of the learned
-- item list. Items that are materials go to Materials, the rest to Loot & Items; an entry the Codex does not have yet is made.

local ADDON, ns = SFP_Module("Codex")
local C = ns.CYAN
local SFP = _G.SeviathsUsefulTools

local function zoneOf(map)
    local ok, n = pcall(function() return SFP:ZoneName(map) end)
    return (ok and type(n) == "string" and n ~= "") and n or "Other"
end

-- the first spot of a record whose spots are { [mapID] = { {x, y}, ... } }
local function firstSpot(rec)
    for map, list in pairs(rec.m or {}) do
        local p = type(list) == "table" and list[1]
        if type(p) == "table" and p[1] then return { m = map, x = p[1], y = p[2] } end
    end
end

local function zonesText(rec)
    local out = {}
    for map in pairs(rec.m or {}) do out[#out + 1] = zoneOf(map) end
    table.sort(out)
    return table.concat(out, ", ")
end

local function dropsText(tbl, kills)
    local list = {}
    for id, n in pairs(tbl or {}) do list[#list + 1] = { id, n } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(14, #list) do
        local pct = (kills and kills > 0) and (" " .. math.min(100, math.floor(list[i][2] * 100 / kills + 0.5)) .. "%") or (" x" .. list[i][2])
        out[#out + 1] = "  " .. (SFP.ItemName and SFP:ItemName(list[i][1]) or ("item " .. list[i][1])) .. pct
    end
    if #list > 14 then out[#out + 1] = "  +" .. (#list - 14) .. " more" end
    return table.concat(out, "\n")
end

function ns:LoadCollected()
    local db = SFP and SFP.db
    if not db then return end
    -- towns and cities
    for key, t in pairs(db.towns or {}) do
        if type(t) == "table" and t.n and (t.rest or (t.nNpc or 0) >= 3) and not ns:Get("town:" .. key) then
            local body = {}
            body[#body + 1] = C .. (t.zone or "Town") .. "|r" .. (t.cont and ("  " .. t.cont) or "")
            ns:Add({ cat = "town", id = key, name = t.n, group = t.cont or t.zone or "Other", sub = t.zone or "",
                icon = "Interface\\Icons\\INV_Misc_Map_01", body = table.concat(body, "\n"),
                map = (t.m and t.x) and { m = t.m, x = t.x, y = t.y } or nil, tags = "town city inn village camp" })
        end
    end
    ns:Yield()
    -- NPCs seen in the world: when the Codex already has a page for the same name (a boss, a rare, a creature), the collected text is
    -- put on that page; otherwise a page is made in Monsters & Creatures
    local byName = {}
    for _, cat in ipairs({ "boss", "rare", "creature" }) do
        for _, e in ipairs(ns.byCat[cat] or {}) do
            if e.lname and not byName[e.lname] then byName[e.lname] = e end
        end
    end
    local n = 0
    for id, r in pairs(db.npcs or {}) do
        if type(r) == "table" and r.n and not ns:Get("creature:seen" .. id) and not ns:Get("npc:seen" .. id) and not ns:Get("creature:sut:npc:" .. id) and not ns:Get("npc:sut:npc:" .. id) then
            local body = {}
            body[#body + 1] = C .. (r.t or "NPC") .. "|r" .. (r.f and ("  " .. r.f) or "")
                .. ((r.lmin and r.lmax) and ("  level " .. (r.lmin == r.lmax and r.lmin or (r.lmin .. "-" .. r.lmax))) or "")
            local z = zonesText(r)
            if z ~= "" then body[#body + 1] = "Found in: " .. z end
            if r.d and next(r.d) then body[#body + 1] = "\n" .. C .. "Drops|r\n" .. dropsText(r.d, r.k) end
            if r.s and next(r.s) then body[#body + 1] = "\n" .. C .. "Skinning|r\n" .. dropsText(r.s, r.sk) end
            local spot = firstSpot(r)
            local same = byName[r.n:lower()]
            if same then
                same.seenData = table.concat(body, "\n")
                if not same.map and spot then same.map = spot end
            else
            local fought = (r.k or 0) > 0 or (r.d and next(r.d)) or (r.s and next(r.s))
            ns:Add({ cat = fought and "creature" or "npc", id = "seen" .. id, name = r.n, group = spot and (fought and SFP:ExpansionOfMap(spot.m) or zoneOf(spot.m)) or "Other", sub = r.t or "",
                icon = "Interface\\Icons\\Ability_Hunter_BeastTaming", body = table.concat(body, "\n"), map = spot, tags = "npc " .. (r.t or "") })
            end
            n = n + 1
            if n % 400 == 0 then ns:Yield() end
        end
    end
    -- nodes and objects that were gathered
    n = 0
    for id, r in pairs(db.objects or {}) do
        if type(r) == "table" and r.n and not ns:Get("node:" .. id) then
            local body = {}
            local kind = SFP.ObjectKind and SFP:ObjectKind(r)
            if kind then body[#body + 1] = C .. "Type|r" .. string.char(10) .. kind .. string.char(10) end
            local purpose = SFP.ObjectPurpose and SFP:ObjectPurpose(r)
            if purpose then body[#body + 1] = C .. "What it is for|r" .. string.char(10) .. purpose .. string.char(10) end
            local z = zonesText(r)
            if z ~= "" then body[#body + 1] = "Found in: " .. z end
            if (r.k or 0) > 0 then body[#body + 1] = r.k .. " times gathered" end
            if r.d and next(r.d) then body[#body + 1] = "\n" .. C .. "Gave|r\n" .. dropsText(r.d, r.k) end
            local spot = firstSpot(r)
            -- an object whose name was never read shows what it gave, so it can be told apart
            local label = r.n
            if label:find("^Object %d+$") and r.d then
                local best, bestN
                for item, cnt in pairs(r.d) do if not bestN or cnt > bestN then best, bestN = item, cnt end end
                local nm = best and C_Item.GetItemNameByID(best)
                if nm then label = label .. " (" .. nm .. ")" end
            end
            ns:Add({ cat = "node", id = id, name = label, group = spot and SFP:ExpansionOfMap(spot.m) or "Other",
                icon = "Interface\\Icons\\INV_Misc_Herb_Felblossom", body = table.concat(body, "\n"), map = spot, tags = "node object gather" })
            n = n + 1
            if n % 400 == 0 then ns:Yield() end
        end
    end
end

-- The item pages (about 55,000 entries) are made only when the Items or Materials section is opened, or when a search is typed: the Codex
-- holds a lot of memory for them, and most players never open that section. Made a few thousand per frame, then the list is refreshed.
local itemsState   -- nil = not started, "running", "done"
function ns:ForgetCollectedItems() itemsState = nil end
function ns:ItemsLoaded() return itemsState ~= nil end

function ns:EnsureCollectedItems()
    if itemsState then return end
    local db = SFP and SFP.db
    if not db then return end
    itemsState = "running"
    local ids = {}
    for id in pairs(db.ahItems or {}) do ids[#ids + 1] = { id, "ah" } end
    for id in SeviathsAllPairs(db.knownItems or {}) do ids[#ids + 1] = { id, "known" } end
    local i = 1
    local function step()
        if ns.IsOpen and not ns:IsOpen() then C_Timer.After(1, step) return end   -- paused while the Codex is closed
        local last = math.min(#ids, i + 2499)
        for n = i, last do
            local id, kind = ids[n][1], ids[n][2]
            if kind == "ah" then
                local cls = db.ahItems[id]
                local name = db.ahNames and db.ahNames[id]
                if name and not (db.knownItems and db.knownItems[id]) and not ns:Get("item:" .. id) and cls ~= 7 then
                    local cn = GetItemClassInfo and GetItemClassInfo(cls) or "Other"
                    ns:Add({ cat = "item", id = id, name = name, group = ns:ItemGroupFor(id, cn), icon = C_Item.GetItemIconByID(id),
                        itemID = id, wh = "item=" .. id, sub = cn, lazy = true })
                end
            else
                local r = db.knownItems[id]
                if type(r) == "table" and r.n then
                    if r.c == 7 then
                        if ns.MaybeMaterial then pcall(ns.MaybeMaterial, ns, id, r.n) end
                    elseif not ns:Get("item:" .. id) then
                        ns:Add({ cat = "item", id = id, name = r.n, group = ns:ItemGroupFor(id, (r.t or "Other") .. ((r.st and r.st ~= "" and r.st ~= r.t) and (" - " .. r.st) or ""), r.x),
                            icon = C_Item.GetItemIconByID(id), itemID = id, wh = "item=" .. id,
                            sub = (r.t or "") .. ((r.st and r.st ~= "") and (" - " .. r.st) or "") .. ((r.i and r.i > 0) and ("  item level " .. r.i) or ""), lazy = true })
                    end
                end
            end
        end
        i = last + 1
        if i <= #ids then
            C_Timer.After(0.03, step)
        else
            ids = nil
            itemsState = "done"
            if ns.RefreshList then pcall(ns.RefreshList, ns, true) end
        end
    end
    step()
end
