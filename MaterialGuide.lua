-- SeviathsUsefulTools - material search on the world map
--
-- A button at the top of the world map opens a big window (not movable, it opens and closes with the map): on the left every expansion
-- from Classic to Midnight with its zones; the zone you pick shows ONLY the loot of that zone on the right - the materials, pets and
-- gear you can farm from monsters there - and for each item the monsters that drop it. Click a monster: a waypoint is set on it and
-- the map opens at that zone. The search bar looks through all zones at once.

local _, SFP = ...

local ROW_H = 30
local TREE_W = 190
local SECTIONS = {
    { key = "mat",   title = "Materials",   color = "|cff40ff40" },
    { key = "pet",   title = "Battle pets", color = "|cffffd100" },
    { key = "boe",   title = "BoE gear",    color = "|cff0070dd" },
    { key = "other", title = "Other",       color = "|cffa335ee" },
}
local PET_KINDS = { pet = true }
local OTHER_KINDS = { mount = true, toy = true, recipe = true }

-- an item name that is never "item 12345": the game's own name when it has loaded, else the name the addon has stored for it; the window
-- redraws when the game delivers more names
local function iname(id)
    local n = SFP:ItemName(id)
    if n:find("item ", 1, true) and n:find("|cff808080", 1, true) == 1 then
        local k = SFP.db and SFP.db.knownItems and SFP.db.knownItems[id]
        local nm = (type(k) == "table" and k.n) or (SFP.AuctionItems and SFP.AuctionItems[id] and SFP.AuctionItems[id][2])
            or (SFP.db and SFP.db.ahNames and SFP.db.ahNames[id])
        if type(nm) == "string" and nm ~= "" then return nm end
    end
    return n
end

local MONSTER_ICON = "Interface\\Icons\\Ability_Hunter_SniperShot"   -- the icon of a farm spot (a monster), not an item's
local function vendorCost(id)
    local codex = _G.SeviathsCodexDB
    local vi = codex and codex.vendorItems and codex.vendorItems[id]
    local vendors = codex and codex.vendors
    if type(vi) == "table" and vendors then
        for _, key in ipairs(vi) do
            local v = vendors[key]
            local cost = type(v) == "table" and v.items and v.items[id]
            if cost and cost ~= "?" then return cost, v.n end
        end
    end
end

-- the text of an item's price for a list: the auction price, else "vendor <cost>"
local function priceText(id)
    if not id then return "" end
    local ah = SFP:GetPrice(id)
    if ah then return SFP.SoldTag(id) .. SFP:FormatPrice(ah) end
    local cost = vendorCost(id)
    if cost then return SFP.SoldTag(id) .. "|cff808080vendor|r " .. cost end
    return SFP.SoldTag(id)
end

SFP.PriceText = priceText   -- the other lists (the map tooltips) use it too

local function plain(s) return (tostring(s or ""):gsub("|n", "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local win, tree, list, search
local selected          -- map ID of the zone shown
local collapsed = {}    -- [expansion key] = true

local function sectionOf(id)
    local info = SFP.Items[id]
    local k = info and info.kind
    if not k then
        -- an item the addon only collected (not in its farm data): the class the game gave it decides
        local kn = SFP.db and SFP.db.knownItems and SFP.db.knownItems[id]
        local c, s = type(kn) == "table" and kn.c, type(kn) == "table" and kn.s
        if c == 17 or (c == 15 and s == 2) then return "pet" end
        if c == 2 or c == 4 then return "boe" end
        if c == 7 then return "mat" end
        if c == 15 and s == 5 then return "other" end
        if c then return "other" end
    end
    if k == "boe" then return "boe" end
    if PET_KINDS[k] then return "pet" end
    if OTHER_KINDS[k] then return "other" end
    return "mat"
end

---------------------------------------------------------------------------
-- rows (one pool per side)
---------------------------------------------------------------------------
local function rowOf(side, i)
    local r = side.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, side.content)
    r:SetHeight(ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.right:SetPoint("RIGHT", -6, 0)
    r.right:SetJustifyH("RIGHT")
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)   -- one line per row: a long name is cut instead of running into the next row
    r.text:SetMaxLines(1)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    r.hl:SetBlendMode("ADD")
    r:SetScript("OnEnter", function(self)
        if self.spotTip then
            if SFP.ShowSpotTip then SFP.ShowSpotTip(self, self.spotTip[1], self.spotTip[2]) end
        elseif self.tipFn then
            local t = SFP.Tip()
            t:SetOwner(self, "ANCHOR_RIGHT")
            self.tipFn(t)
            t:Show()
        elseif self.item then
            local t = SFP.Tip()
            t:SetOwner(self, "ANCHOR_RIGHT")
            t:SetItemByID(self.item)
            t:Show()
        elseif self.hint then
            local t = SFP.Tip()
            t:SetOwner(self, "ANCHOR_RIGHT")
            t:AddLine(self.hint, 1, 1, 1, true)
            t:Show()
        end
    end)
    r:SetScript("OnLeave", function() SFP.Tip():Hide(); if SFP.HideSpotTip then SFP.HideSpotTip() end end)
    r:SetScript("OnClick", function(self) if self.click then self.click() end end)
    side.rows[i] = r
    return r
end

local function place(side, r, n, indent)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", side.content, "TOPLEFT", 0, -(n - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", side.content, "TOPRIGHT", 0, -(n - 1) * ROW_H)
    r.icon:ClearAllPoints()
    r.icon:SetPoint("LEFT", 4 + indent, 0)
    r.text:ClearAllPoints()
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
    r.text:SetPoint("RIGHT", r.right, "LEFT", -4, 0)
    r.item, r.click, r.hint, r.tipFn, r.spotTip = nil, nil, nil, nil, nil
    r:EnableMouse(true)
    r.right:SetText("")
    r.bg:SetColorTexture(0, 0, 0, 0)
    r.hl:Show()
    r:Show()
end

-- the list is cut into pages that fit the window (Previous / Next below it); the tree on the left just scrolls
local mode = "mat"          -- "mat", "mount", "hunter", "pet", "farm", "rare" or "top"
local matTab = "monsters"   -- the Material search has two tabs: "monsters" and "gather"
local gatherExp = "zone"   -- what the gathering tab shows: "zone" (the zone on the map), "all" or an expansion key
local expSel = "all"        -- expansion key / family shown in the mount, hunter and pet lists
local listPage, listSig = 1, nil
local function finish(side, n)
    for i = n + 1, #side.rows do side.rows[i]:Hide() end
    if side ~= list then
        side.content:SetHeight(math.max(n * ROW_H, 1))
        return
    end
    -- rows that fit: the window's height less the header (64) and the page buttons (40); the scroll frame has no size yet on the first draw
    local winH = (win and win:GetHeight()) or 0
    if winH < 100 then winH = (WorldMapFrame:GetHeight() or 400) end
    local per = math.min(30, math.max(6, math.floor((winH - 104) / ROW_H)))
    local sig = tostring(mode) .. "|" .. tostring(matTab) .. "|" .. tostring(gatherExp) .. "|" .. tostring(selected) .. "|" .. tostring(expSel) .. "|" .. (search and search:GetText() or "")
    if sig ~= listSig then listSig, listPage = sig, 1 end
    local pages = math.max(1, math.ceil(n / per))
    listPage = math.min(math.max(listPage, 1), pages)
    local first = (listPage - 1) * per
    for i = 1, n do
        local r = side.rows[i]
        if i > first and i <= first + per then
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", side.content, "TOPLEFT", 0, -(i - first - 1) * ROW_H)
            r:SetPoint("TOPRIGHT", side.content, "TOPRIGHT", 0, -(i - first - 1) * ROW_H)
            r:Show()
        else
            r:Hide()
        end
    end
    side.content:SetHeight(math.max(math.min(n - first, per) * ROW_H, 1))
    if win and win.pager then
        win.pager.text:SetText("Page " .. listPage .. " / " .. pages .. "   |cff808080" .. n .. " rows|r")
        win.pager.prev:SetEnabled(listPage > 1)
        win.pager.next:SetEnabled(listPage < pages)
        win.pager:SetShown(pages > 1)
    end
end

-- an empty row: the space after each item
local function spacer(n)
    n = n + 1
    local r = rowOf(list, n)
    place(list, r, n, 0)
    r.icon:SetTexture(nil)
    r.text:SetText("")
    r.hl:Hide()
    return n
end

---------------------------------------------------------------------------
-- the loot of one zone: item -> monsters that drop it
---------------------------------------------------------------------------
-- the monsters that drop crafting reagents, by map: what the addon has collected (kills with loot, skinning; the shipped data too) and
-- Data/SpawnsWowhead.lua when it has anything. Built when the window opens and dropped when it closes.
local guideIndex = {}    -- [map] = the monsters of that map with their drops (made when that map is asked for)
local ownByMap             -- [map] = ids of the player's own monsters on it
local mapRecs = {}         -- [map] = { { id, rec } }: the records of that map, own and shipped
local guideMapSet
local itemMode = false   -- the Item search tab: every item; Material search (false) lists only crafting reagents
local reagentCache = {}
local function isGray(id)
    local rec = SFP.db and SFP.db.knownItems and SFP.db.knownItems[id]   -- the player's own record, or the shipped one of a gray item
    if type(rec) == "table" and rec.q ~= nil then return rec.q == 0 end
    if C_Item and C_Item.GetItemQualityByID then
        local ok, q = pcall(C_Item.GetItemQualityByID, id)
        if ok and q == 0 then return true end
    end
    return false
end

-- a crafting reagent: trade goods, anything the game flags as a crafting reagent, and what the addon knows as a material
local function isCraftingReagent(id)
    local c = reagentCache[id]
    if c ~= nil then return c end
    c = false
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, id)
        if ok and classID == 7 then c = true end   -- trade goods
    end
    if not c and C_Item and C_Item.GetItemInfo then
        local ok, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, crafting = pcall(C_Item.GetItemInfo, id)
        if ok and crafting == true then c = true end   -- the game's own crafting reagent flag
    end
    if not c then
        local rec = SFP.db and SFP.db.knownItems and SFP.db.knownItems[id]
        if type(rec) == "table" and rec.c == 7 then c = true end
    end
    if not c then
        local info = SFP.Items and SFP.Items[id]
        if info and info.kind == "mat" then c = true end
    end
    reagentCache[id] = c
    return c
end

-- Material search lists the crafting reagents, Item search every other item (gray items are in neither: they stay in the data and in the loot table of
-- a monster you hover)
local function isReagent(id)
    if id == nil or isGray(id) then return false end
    if itemMode then return not isCraftingReagent(id) end   -- the materials moved to Material search
    return isCraftingReagent(id)
end

local function ownMaps()
    if not ownByMap then
        ownByMap = {}
        for id, rec in pairs(SFP.db and SFP.db.npcs or {}) do
            if type(rec) == "table" and type(rec.m) == "table" then
                for m in pairs(rec.m) do
                    local l = ownByMap[m]
                    if not l then l = {}; ownByMap[m] = l end
                    l[#l + 1] = id
                end
            end
        end
    end
    return ownByMap
end

-- the monsters of one map: the player's own, and the shipped ones of that map (the load-on-demand data is read now, and only the
-- records of this map are turned into tables)
local function recsOfMap(map)
    local c = mapRecs[map]
    if c then return c end
    c = {}
    local seen = {}
    for _, id in ipairs(ownMaps()[map] or {}) do
        local rec = SFP.db.npcs[id]
        if type(rec) == "table" then seen[id] = true; c[#c + 1] = { id = id, rec = rec } end
    end
    for _, id in ipairs(SFP:ShippedNpcIDs(map)) do
        if not seen[id] then
            local rec = SFP:Npc(id)
            if type(rec) == "table" then c[#c + 1] = { id = id, rec = rec } end
        end
    end
    mapRecs[map] = c
    return c
end

-- the maps that have monsters (no record is decoded for this)
local function guideMaps()
    if guideMapSet then return guideMapSet end
    local set = {}
    for m in pairs(ownMaps()) do set[m] = true end
    for m in pairs(SFP:ShippedNpcMaps()) do set[m] = true end
    for m in pairs(SFP.SpawnsWowhead or {}) do set[m] = true end
    for _, r in pairs(SFP.db and SFP.db.rareSeen or {}) do if type(r) == "table" and r.m then set[r.m] = true end end
    guideMapSet = set
    return set
end

local function guideList(map)
    local c = guideIndex[map]
    if c then return c end
    local out = {}
    for _, e in ipairs(recsOfMap(map)) do
        local rec, npcID = e.rec, e.id
        local listed = SFP.WowheadDrops and SFP:WowheadDrops(npcID)   -- what Wowhead lists for this monster (no counts)
        if type(rec.m) == "table" and (rec.d or rec.s or listed) and rec.n then
            local pts = rec.m[map]
            local p = type(pts) == "table" and pts[1]
            if p and p[1] and p[2] then
                local kills = rec.k or 0
                local drop
                for _, id in ipairs(listed or {}) do
                    if isReagent(id) then drop = drop or {}; drop[id] = drop[id] or 0 end
                end
                for _, src in ipairs({ rec.d or {}, rec.s or {} }) do
                    for id, q in pairs(src) do
                        if type(q) == "number" and isReagent(id) then
                            drop = drop or {}
                            local pct = kills >= 3 and math.min(100, math.floor(q / kills * 1000) / 10) or 0
                            drop[id] = math.max(drop[id] or 0, pct)
                        end
                    end
                end
                if drop then
                    out[#out + 1] = { npc = npcID, name = rec.n, pts = string.format("%.1f,%.1f", p[1] * 100, p[2] * 100), drop = drop }
                end
            end
        end
    end
    for _, w in ipairs(SFP.SpawnsWowhead and SFP.SpawnsWowhead[map] or {}) do out[#out + 1] = w end
    guideIndex[map] = out
    return out
end

local function monstersFor(map, id)
    local out = {}
    local zone = SFP.zoneByMap[map]
    for _, sp in ipairs(zone and zone.spawns or {}) do
        if not (sp.rare or sp.special or sp.hunter or sp.gather) then
            for _, it in ipairs(sp.items or {}) do
                if it == id then out[#out + 1] = sp break end
            end
        end
    end
    local have = {}
    for _, sp in ipairs(out) do have[sp.name or ""] = true end
    local extra = {}
    for _, w in ipairs(guideList(map)) do
        if w.drop and w.drop[id] and not have[w.name] then extra[#extra + 1] = w end
    end
    table.sort(extra, function(a, c) return a.drop[id] > c.drop[id] end)
    for _, w in ipairs(extra) do out[#out + 1] = w end
    return out
end

local function zoneItems(map)
    local ids, seen = {}, {}
    local zone = SFP.zoneByMap[map]
    for _, id in ipairs(zone and zone.items or {}) do
        if not seen[id] and SFP.Items[id] and isReagent(id) then seen[id] = true; ids[#ids + 1] = id end
    end
    for _, w in ipairs(guideList(map)) do
        for id in pairs(w.drop or {}) do
            if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
        end
    end
    return ids
end

-- the zones of an expansion: its farm zones and every map the Wowhead data puts reagent monsters on
local zonesCache = {}
local function zonesOf(exp)
    local c = zonesCache[exp.key]
    if c then return c end
    local seen, out = {}, {}
    for _, z in ipairs(exp.zones or {}) do
        if not seen[z.map] then seen[z.map] = true; out[#out + 1] = z.map end
    end
    for map in pairs(guideMaps()) do
        if not seen[map] then
            local e = SFP:ExpansionForMap(map)
            if e == exp then seen[map] = true; out[#out + 1] = map end
        end
    end
    table.sort(out, function(a, c2) return SFP:ZoneName(a) < SFP:ZoneName(c2) end)
    zonesCache[exp.key] = out
    return out
end

local function goToMonster(mapID, sp)
    local x, y = sp.hx, sp.hy
    if not x then local p = sp.points and sp.points[1]; if p then x, y = p[1], p[2] end end
    if not x and sp.pts then
        local px, py = sp.pts:match("([%d%.]+),([%d%.]+)")
        if px then x, y = tonumber(px) / 100, tonumber(py) / 100 end
    end
    if not x then
        -- no exact spot known: the waypoint leads to the zone, the whole zone where the monster is
        if mapID and WorldMapFrame:GetMapID() ~= mapID then WorldMapFrame:SetMapID(mapID) end
        if mapID then SFP:Print(string.format("%s: %s (no exact spot known yet)", tostring(sp.name), SFP:ZoneName(mapID))) end
        return
    end
    -- the map shows that zone and the waypoint sits on the monster (set again, never removed by a second click)
    if WorldMapFrame:GetMapID() ~= mapID then WorldMapFrame:SetMapID(mapID) end
    local placed = false
    if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        placed = true
    end
    if placed then
        SFP:Print(string.format("Waypoint set: %s, %s %.1f, %.1f", tostring(sp.name), SFP:ZoneName(mapID), x * 100, y * 100))
    else
        SFP:Print(string.format("%s: the game does not allow a waypoint on %s - the spot %.1f, %.1f is pinged on the map.", tostring(sp.name), SFP:ZoneName(mapID), x * 100, y * 100))
    end
    if SFP.PingSpot then SFP.PingSpot(mapID, x, y) end
end

-- add the rows of one item (its line and one line per monster); returns the new row count
local function addItem(n, mapID, id, withZone)
    n = n + 1
    local r = rowOf(list, n)
    place(list, r, n, 8)
    r.icon:SetTexture(SFP:ItemIcon(id))
    r.text:SetText(iname(id) .. (withZone and ("  |cff808080" .. SFP:ZoneName(mapID) .. "|r") or ""))
    r.right:SetText(priceText(id))
    r.item = id
    local mons = monstersFor(mapID, id)
    if mons[1] then r.click = function() goToMonster(mapID, mons[1]) end end
    if #mons == 0 then
        local spot = SFP.db and SFP.db.itemSpots and SFP.db.itemSpots[id]
        n = n + 1
        local m = rowOf(list, n)
        place(list, m, n, 30)
        m.icon:SetTexture(nil)
        if type(spot) == "table" and spot.m and spot.x then
            m.text:SetText("|cffe6483dcollected at|r " .. SFP:ZoneName(spot.m) .. "  |cff808080" .. string.format("%.1f, %.1f", spot.x * 100, spot.y * 100) .. "|r")
            m.right:SetText("|cffff3030WAYPOINT|r")
            m.hint = "Click: set a waypoint where you collected it and open the map there"
            m.click = function() goToMonster(spot.m, { hx = spot.x, hy = spot.y, name = iname(id) }) end
            if not r.click then r.click = m.click end
        else
            -- no exact spot: the waypoint leads to the zone (the monsters there, or where it is gathered)
            m.text:SetText("|cffe6483d" .. SFP:ZoneName(mapID) .. "|r  |cff808080whole zone, no exact spot known yet|r")
            m.right:SetText("|cffff3030WAYPOINT|r")
            m.hint = "Click: open the map on " .. SFP:ZoneName(mapID)
            m.click = function() goToMonster(mapID, { name = iname(id) }) end
            if not r.click then r.click = m.click end
        end
    end
    for _, sp in ipairs(mons) do
        n = n + 1
        local m = rowOf(list, n)
        place(list, m, n, 30)
        m.icon:SetTexture(MONSTER_ICON)
        m.text:SetText("|cffe6483d" .. tostring(sp.name) .. "|r")
        local drops = sp.counts and sp.counts[id] and sp.kills and sp.kills > 0
        local wpct = sp.drop and sp.drop[id]
        if wpct == 0 then wpct = nil end
        if drops or wpct then
            local pct = drops and (100 * sp.counts[id] / sp.kills) or wpct
            m.right:SetText(string.format("|cffffd100%s%%|r  |cffff3030WAYPOINT|r", pct >= 10 and string.format("%.0f", pct) or string.format("%.1f", pct)))
        else
            m.right:SetText("|cffff3030WAYPOINT|r")
        end
        m.hint = "Click: set a waypoint on " .. tostring(sp.name) .. " and open the map there"
        m.click = function() goToMonster(mapID, sp) end
    end
    return spacer(n)
end

---------------------------------------------------------------------------
-- Gathering reagents: every ore and herb (and what your own gathering found), with where to gather it. The exact spots your own
-- gathering recorded come first (the area name and the coordinates), then the zones where the item spawns with the number of nodes.
---------------------------------------------------------------------------
local GATHER_SECTIONS = {
    { key = "ore",  title = "Mining",      color = "|cffffb366" },
    { key = "herb", title = "Herbalism",   color = "|cff4dff8c" },
    { key = "other", title = "Other gathering", color = "|cffa335ee" },
}

-- the exact spots recorded from your own gathering (and the shipped ones): [item] = { { map, x, y, area, name } }
local function learnedGatherSpots()
    local out = {}
    local objects = SFP.db and SFP.db.objects
    if not objects then return out end
    local walk = SeviathsAllPairs or pairs
    for _, rec in walk(objects) do
        if type(rec) == "table" and rec.d and rec.m and SFP:ObjectKind(rec) then
            for id in pairs(rec.d) do
                local info = SFP.Items[id]
                local k = SFP.ClassifyItem and SFP:ClassifyItem(id) or (info and info.kind)
                if k == "ore" or k == "herb" or k == "element" or k == "enchant" then
                    local l = out[id]
                    if not l then l = {}; out[id] = l end
                    for map, pts in pairs(rec.m) do
                        for _, p in ipairs(pts) do
                            l[#l + 1] = { map = map, x = p[1], y = p[2], area = p[3], name = rec.n }
                        end
                    end
                end
            end
        end
    end
    return out
end

local function gatherItems()
    local ids, seen = {}, {}
    for _, g in ipairs(SFP.Gather or {}) do
        if not seen[g.item] then seen[g.item] = true; ids[#ids + 1] = g.item end
    end
    for id in pairs(SFP.GatherZones or {}) do
        if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    for id in pairs(learnedGatherSpots()) do
        if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    return ids
end

local function gatherKind(id)
    local k = SFP.Items[id] and SFP.Items[id].kind
    if k == "ore" or k == "herb" then return k end
    return "other"
end

local function openSpot(map, x, y, label)
    if WorldMapFrame:GetMapID() ~= map then WorldMapFrame:SetMapID(map) end
    if x and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        SFP:Print(string.format("Waypoint set: %s, %s %.1f, %.1f", tostring(label), SFP:ZoneName(map), x * 100, y * 100))
        if SFP.PingSpot then SFP.PingSpot(map, x, y) end
    end
end

local learnedCache
local function addGatherItem(n, id, withKind)
    n = n + 1
    local r = rowOf(list, n)
    place(list, r, n, 8)
    r.icon:SetTexture(SFP:ItemIcon(id))
    r.text:SetText(iname(id))
    r.right:SetText(priceText(id))
    r.item = id
    -- exact spots from gathering, nearest to one area name once each
    local seenSpot = {}
    local shown = 0
    for _, s in ipairs(learnedCache and learnedCache[id] or {}) do
        local key = s.map .. "|" .. tostring(s.area or (math.floor(s.x * 100) .. "," .. math.floor(s.y * 100)))
        if not seenSpot[key] and shown < 12 then
            seenSpot[key] = true
            shown = shown + 1
            n = n + 1
            local m = rowOf(list, n)
            place(list, m, n, 30)
            m.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
            m.text:SetText("|cffe6483d" .. (s.area and (s.area .. " - ") or "") .. SFP:ZoneName(s.map) .. "|r  |cff808080" ..
                string.format("%.1f, %.1f", s.x * 100, s.y * 100) .. "|r")
            m.right:SetText("|cffff3030WAYPOINT|r")
            m.hint = "A spot where gathering was recorded. Click: set a waypoint there and open the map"
            m.click = function() openSpot(s.map, s.x, s.y, tostring(s.name or iname(id))) end
            if shown == 1 then r.click = m.click end   -- the name of the material goes to the first spot
        end
    end
    -- the zones it spawns in, most nodes first
    local zones = {}
    for map, count in pairs(SFP.GatherZones and SFP.GatherZones[id] or {}) do zones[#zones + 1] = { map = map, count = count } end
    table.sort(zones, function(a, c) return a.count > c.count end)
    for i, z in ipairs(zones) do
        if i > 8 then break end
        n = n + 1
        local m = rowOf(list, n)
        place(list, m, n, 30)
        m.icon:SetTexture(nil)
        m.text:SetText("|cffffffff" .. SFP:ZoneName(z.map) .. "|r")
        m.right:SetText("|cffffd100" .. z.count .. " nodes|r  |cffff3030WAYPOINT|r")
        m.hint = "Click: open the map of " .. SFP:ZoneName(z.map) .. " with a waypoint on the best spot there"
        m.click = function()
            local x, y
            for _, g in ipairs(SFP.Gather or {}) do
                if g.item == id and g.map == z.map and g.pts then
                    local px, py = g.pts:match("([%d%.]+),([%d%.]+)")
                    if px then x, y = tonumber(px) / 100, tonumber(py) / 100 end
                    break
                end
            end
            openSpot(z.map, x, y, iname(id))
        end
        if i == 1 and not r.click then r.click = m.click end
    end
    if shown == 0 and #zones == 0 then
        n = n + 1
        local m = rowOf(list, n)
        place(list, m, n, 30)
        m.icon:SetTexture(nil)
        m.text:SetText("|cff808080no gathering spot recorded yet|r")
        m.hl:Hide()
    end
    return spacer(n)
end


local function renderGather(q)
    local n = 0
    local ql = q and q:lower() or nil
    win.title:SetText("|cffe6483dGathering|r" .. (ql and ("  |cffffd100" .. q .. "|r") or ""))
    learnedCache = learnedGatherSpots()
    local ids = gatherItems()
    local zoneMap = (gatherExp == "zone" and not ql) and WorldMapFrame:GetMapID() or nil
    if zoneMap then
        local here, keep = {}, {}
        for _, g in ipairs(SFP.Gather or {}) do if g.map == zoneMap then here[g.item] = true end end
        for id, zones in pairs(SFP.GatherZones or {}) do if zones[zoneMap] then here[id] = true end end
        for id, spots in pairs(learnedCache) do
            for _, s in ipairs(spots) do if s.map == zoneMap then here[id] = true break end end
        end
        for _, id in ipairs(ids) do if here[id] then keep[#keep + 1] = id end end
        ids = keep
        win.title:SetText("|cffe6483d" .. SFP:ZoneName(zoneMap) .. "|r  |cffaaaaaaMining & Herbalism|r")
    end
    local expOf = {}
    for _, g in ipairs(SFP.Gather or {}) do expOf[g.item] = expOf[g.item] or g.exp end
    local groups = {}
    for _, exp in ipairs(SFP.Expansions) do groups[#groups + 1] = { key = exp.key, name = exp.name } end
    groups[#groups + 1] = { key = "other", name = "Other" }
    for _, grp in ipairs(groups) do
        if ql or zoneMap or gatherExp == "all" or gatherExp == grp.key then
            for _, sec in ipairs(GATHER_SECTIONS) do
                local mine = {}
                for _, id in ipairs(ids) do
                    local e = expOf[id] or "other"
                    if e == grp.key and gatherKind(id) == sec.key
                        and (not ql or plain(iname(id)):lower():find(ql, 1, true)) then mine[#mine + 1] = id end
                end
                table.sort(mine, function(a, c) return plain(iname(a)) < plain(iname(c)) end)
                if #mine > 0 then
                    n = n + 1
                    local h = rowOf(list, n)
                    place(list, h, n, 0)
                    h.icon:SetTexture(nil)
                    h.text:SetText(sec.color .. grp.name .. " - " .. sec.title .. "|r  |cff808080" .. #mine .. "|r")
                    h.bg:SetColorTexture(1, 1, 1, 0.06)
                    h.hl:Hide()
                    for _, id in ipairs(mine) do n = addGatherItem(n, id) end
                end
            end
        end
    end
    if n == 0 then
        n = 1
        local h = rowOf(list, 1)
        place(list, h, 1, 0)
        h.icon:SetTexture(nil)
        h.text:SetText("|cff808080" .. (zoneMap and "No ore or herb recorded for this zone yet" or "No gathering data for this expansion yet") .. "|r")
        h.hl:Hide()
    end
    finish(list, n)
end


local function renderZone()
    local n = 0
    if not selected then
        finish(list, 0)
        win.title:SetText("Pick a zone on the left, or search for a material")
        return
    end
    win.title:SetText("|cffe6483d" .. SFP:ZoneName(selected) .. "|r")
    local ids = zoneItems(selected)
    for _, sec in ipairs(SECTIONS) do
        local mine = {}
        for _, id in ipairs(ids) do if sectionOf(id) == sec.key then mine[#mine + 1] = id end end
        table.sort(mine, function(a, b) return iname(a):gsub("|c%x%x%x%x%x%x%x%x", "") < iname(b):gsub("|c%x%x%x%x%x%x%x%x", "") end)
        if #mine > 0 then
            n = n + 1
            local h = rowOf(list, n)
            place(list, h, n, 0)
            h.icon:SetTexture(nil)
            h.text:SetText(sec.color .. sec.title .. "|r  |cff808080" .. #mine .. "|r")
            h.bg:SetColorTexture(1, 1, 1, 0.06)
            h.hl:Hide()
            for _, id in ipairs(mine) do n = addItem(n, selected, id, false) end
        end
    end
    if n == 0 then
        n = 1
        local h = rowOf(list, 1)
        place(list, h, 1, 0)
        h.icon:SetTexture(nil)
        h.text:SetText("|cff808080Nothing farmable recorded for this zone yet|r")
        h.hl:Hide()
    end
    finish(list, n)
end

local function renderSearch(q)
    local n = 0
    win.title:SetText("Search: |cffffd100" .. q .. "|r")
    local ql = q:lower()
    for _, exp in ipairs(SFP.Expansions) do
        for _, map in ipairs(zonesOf(exp)) do
            for _, id in ipairs(zoneItems(map)) do
                local nm = (iname(id) or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
                if nm:find(ql, 1, true) and n < 600 then n = addItem(n, map, id, true) end
            end
        end
    end
    if n == 0 then
        n = 1
        local h = rowOf(list, 1)
        place(list, h, 1, 0)
        h.icon:SetTexture(nil)
        h.text:SetText("|cff808080Nothing found|r")
        h.hl:Hide()
    end
    finish(list, n)
end

---------------------------------------------------------------------------
-- Mount search and Hunter search: the same window with another list. The left side picks an expansion (or all), the right side lists
-- every mount / hunter pet with a waypoint on where to get it; the search box filters by name.
---------------------------------------------------------------------------
local entriesCache

local function firstPoint(pts)
    local x, y = tostring(pts or ""):match("([%d%.]+),([%d%.]+)")
    if x then return tonumber(x) / 100, tonumber(y) / 100 end
end

-- every mount: { item, exp, sources = { { text, map, x, y } } }
local function mountEntriesBase()
    local byItem, order = {}, {}
    local function add(id, expKey, src)
        local e = byItem[id]
        if not e then e = { item = id, exp = expKey, sources = {} }; byItem[id] = e; order[#order + 1] = e end
        e.sources[#e.sources + 1] = src
    end
    for _, exp in ipairs(SFP.Expansions) do
        for _, inst in ipairs(exp.instances or {}) do
            for _, id in ipairs(inst.items or {}) do
                local info = SFP.Items[id]
                if info and info.kind == "mount" then
                    local en = SFP:FindEntrance(inst)
                    -- an instance the game gave no entrance for: the place you stood before you went in
                    local rec = SFP.db and SFP.db.instanceEntrances and SFP.db.instanceEntrances[inst.name]
                    if not en and type(rec) == "table" and rec.m then en = { map = rec.m, x = rec.x, y = rec.y } end
                    -- the chance: your own tries and drops of this mount in this instance, else the one from the data
                    local n, d = 0, 0
                    local stats = SFP.db and SFP.db.mountStats and SFP.db.mountStats[id]
                    local prefix = "boss|" .. inst.name:lower() .. "|"
                    for key, st in pairs(stats or {}) do
                        if key:lower():sub(1, #prefix) == prefix then n, d = n + (st.n or 0), d + (st.d or 0) end
                    end
                    local chance = info.drop and ("  |cffffd100" .. info.drop .. "|r") or ""
                    if n > 0 then chance = "  |cff40ff40" .. string.format("%.1f", 100 * d / n) .. "%|r" end
                    add(id, exp.key, { text = (inst.kind == "raid" and "Raid: " or "Dungeon: ") .. inst.name .. chance,
                        map = en and en.map, x = en and en.x, y = en and en.y })
                end
            end
        end
    end
    for map, list in pairs(SFP.Rares or {}) do
        for _, sp in ipairs(list) do
            for _, id in ipairs(sp.items or {}) do
                local info = SFP.Items[id]
                if info and info.kind == "mount" then
                    local x, y = firstPoint(sp.pts)
                    local st = SFP.db and SFP.db.mountStats and SFP.db.mountStats[id] and SFP.db.mountStats[id]["npc|" .. tostring(sp.npc)]
                    local chance = (st and st.n > 0) and ("  |cff40ff40" .. string.format("%.1f", 100 * st.d / st.n) .. "%|r") or ""
                    add(id, list.exp, { text = "Rare: " .. tostring(sp.name) .. chance, zone = SFP:ZoneName(map), map = map, x = x, y = y })
                end
            end
        end
    end
    return order
end

-- every hunter pet: { name, exp, map, x, y, kind }
local function hunterEntries()
    local out, seen = {}, {}
    for map, list in pairs(SFP.Rares or {}) do
        for _, sp in ipairs(list) do
            if sp.hunter then
                local x, y = firstPoint(sp.pts)
                seen[sp.name .. "@" .. map] = true
                out[#out + 1] = { name = sp.name, exp = list.exp, map = map, x = x, y = y,
                    kind = sp.hunter == "spirit" and "spirit beast" or "unique look" }
            end
        end
    end
    -- tameable beasts seen in the game (recorded and shipped by the Codex)
    local beasts = _G.SeviathsCodexDB and _G.SeviathsCodexDB.beasts
    for _, b in (SeviathsAllPairs or pairs)(beasts or {}) do
        if type(b) == "table" and b.n and b.m and not seen[b.n .. "@" .. b.m] then
            seen[b.n .. "@" .. b.m] = true
            local e = SFP:ExpansionForMap(b.m)
            out[#out + 1] = { name = b.n, exp = e and e.key, map = b.m, x = b.x, y = b.y, kind = (b.f or "beast") .. (b.r and " (rare)" or "") }
        end
    end
    return out
end

local function expOrder(key)
    for i, e in ipairs(SFP.Expansions) do if e.key == key then return i end end
    return 99
end

-- what a mount can do, from the journal's mount type: flying (flying, Skyriding, flying + swimming), aquatic (swimming, turtles, seahorses), ground (the rest)
local MOUNT_KIND = {
    [247] = "flying", [248] = "flying", [398] = "flying", [402] = "flying", [407] = "flying", [424] = "flying", [436] = "flying", [445] = "flying",
    [231] = "aquatic", [232] = "aquatic", [254] = "aquatic",
}
local MOUNT_KINDS = { { "flying", "Flying" }, { "ground", "Ground" }, { "aquatic", "Aquatic" }, { "other", "Not in the journal" } }
-- is a mount in the section picked on the left: "all", "type:flying" or "type:flying|expansion", or just an expansion
local function mountSel(e)
    if expSel == "all" then return true end
    local kind, exp = expSel:match("^type:(%a+)|?(.*)$")
    if kind then
        if (e.mtype or "other") ~= kind then return false end
        return exp == "" or e.exp == exp
    end
    return e.exp == expSel
end

local renderPetTree   -- defined below (the battle pets list)
local function renderModeTree()
    if mode == "pet" then return renderPetTree() end
    local n = 1
    local function row(i, text, key, indent, header)
        local r = rowOf(tree, i)
        place(tree, r, i, indent)
        r.icon:SetTexture(nil)
        r.text:SetText((expSel == key and "|cffe6483d" or "|cffffffff") .. text .. "|r")
        r.bg:SetColorTexture(0.9, 0.28, 0.24, expSel == key and 0.15 or 0.06)
        r.click = function()
            expSel = key
            search:SetText("")
            renderModeTree()
            win.refreshList()
        end
    end
    if mode == "mount" then
        row(1, "All mounts", "all", 0)
        for _, kind in ipairs(MOUNT_KINDS) do
            n = n + 1
            row(n, kind[2], "type:" .. kind[1], 8)
            if expSel == "type:" .. kind[1] or expSel:find("^type:" .. kind[1] .. "|") then
                for _, exp in ipairs(SFP.Expansions) do
                    n = n + 1
                    row(n, exp.name, "type:" .. kind[1] .. "|" .. exp.key, 22)
                end
            end
        end
        finish(tree, n)
        return
    end
    row(1, "All expansions", "all", 0)
    for _, exp in ipairs(SFP.Expansions) do
        n = n + 1
        row(n, exp.name, exp.key, 12)
    end
    finish(tree, n)
end

local headerRow, openWaypoint   -- defined below
-- Battle pets: every pet species of the game with its auction price (own realm's last scan); the families on the left filter the list
local function petPrices()
    local all = SFP.db and SFP.db.petPrices
    if type(all) ~= "table" then return {} end
    local own = all[SFP:RealmKey()]
    if own and next(own) then return own end
    for _, t in pairs(all) do if type(t) == "table" and next(t) then return t end end
    return {}
end

-- where a pet's source is: the vendor ("Vendor: Name") or the monster ("Drop: Name") that its source text names, found in the collected
-- vendors and monsters: { map, x, y }
local zoneIndex
local function mapOfZone(name)
    if not zoneIndex then
        zoneIndex = {}
        local list = C_Map.GetMapChildrenInfo and C_Map.GetMapChildrenInfo(946, nil, true) or {}
        for _, m in ipairs(list) do
            if m.name and not zoneIndex[m.name] then zoneIndex[m.name] = m.mapID end
        end
        for _, exp in ipairs(SFP.Expansions) do
            for _, z in ipairs(exp.zones or {}) do
                local nm = SFP:ZoneName(z.map)
                if nm and not zoneIndex[nm] then zoneIndex[nm] = z.map end
            end
        end
    end
    return zoneIndex[name] or zoneIndex[(name:gsub("^The ", ""))] or zoneIndex["The " .. name]
end

local function petSpots(entries)
    local need = {}
    for _, e in ipairs(entries) do
        local src = plain(e.source or "")
        e.vendorName = src:match("Vendor:%s*([^\n]+)")
        e.dropName = src:match("Drop:%s*([^\n]+)")
        if e.vendorName then need[e.vendorName] = true end
        if e.dropName then need[e.dropName] = true end
    end
    for _, e in ipairs(entries) do
        local zn = plain(e.source or ""):match("Zone:%s*([^\n]+)")
        if zn then
            e.zoneName = zn
            e.zoneMap = mapOfZone(zn)
        end
        -- a wild pet: the zones where it is caught (Data/WildPets.lua, from Wowhead); the first one the game knows is where the map opens
        local wild = SFP.WildPets and SFP.WildPets[e.name]
        if wild then
            local names = {}
            for z in wild:gmatch("[^;]+") do
                z = z:gsub("^%s+", ""):gsub("%s+$", "")
                names[#names + 1] = z
                if not e.zoneMap then
                    local m = mapOfZone(z)
                    if m then e.zoneMap = m; e.zoneName = e.zoneName or z end
                end
            end
            e.wildZones = names
            if not e.zoneName and names[1] then e.zoneName = names[1] end
        end
        -- Wowhead's battle pet database: the zone maps of the species (Data/WildPetZones.lua), for pets and zones the lists above lack
        if SFP.WildPetZones then
            local zm = SFP.WildPetZones[e.name]
            if not zm then
                for nm, v in pairs(SFP.WildPetZones) do
                    if nm:lower() == e.name:lower() then zm = v break end
                end
            end
            if zm and zm[1] then
                local here = WorldMapFrame:GetMapID()
                local pick = zm[1]
                for _, m in ipairs(zm) do if m == here then pick = m break end end
                if not e.zoneMap then e.zoneMap = pick end
                if not e.wildZones then
                    local names = {}
                    for _, m in ipairs(zm) do names[#names + 1] = SFP:ZoneName(m) end
                    e.wildZones = names
                end
                e.zoneName = e.zoneName or SFP:ZoneName(e.zoneMap)
            end
        end
    end
    if next(need) == nil then return end
    local found = {}
    local vendors = _G.SeviathsCodexDB and _G.SeviathsCodexDB.vendors
    for key, v in (SeviathsAllPairs or pairs)(vendors or {}) do
        if type(v) == "table" and v.m and v.x then
            local name = v.n or tostring(key):match("^(.-)@")
            if name and need[name] and not found[name] then found[name] = { map = v.m, x = v.x, y = v.y } end
        end
    end
    for _, rec in (SeviathsAllPairs or pairs)(SFP.db and SFP.db.npcs or {}) do
        if type(rec) == "table" and rec.n and need[rec.n] and not found[rec.n] and type(rec.m) == "table" then
            for map, pts in pairs(rec.m) do
                local p = type(pts) == "table" and pts[1]
                if p and p[1] and p[2] then found[rec.n] = { map = map, x = p[1], y = p[2] } break end
            end
        end
    end
    for _, e in ipairs(entries) do
        local cs = SFP.db and SFP.db.petSpots and SFP.db.petSpots[e.name]
        if type(cs) == "table" and cs.m and cs.x then
            e.map, e.x, e.y, e.who, e.collected = cs.m, cs.x, cs.y, "Collected here", true
        end
        local s = (not e.collected) and ((e.vendorName and found[e.vendorName]) or (e.dropName and found[e.dropName]))
        if s then e.map, e.x, e.y = s.map, s.x, s.y end
    end
    -- a pet that is a drop: the monsters that drop its item (farm spots, and every monster the addon has seen drop it) give the waypoint
    local byName = {}
    for _, e in ipairs(entries) do byName[e.name] = e end
    local function petOf(itemId)
        if not (C_PetJournal and C_PetJournal.GetPetInfoByItemID) then return nil end
        local ok, nm = pcall(C_PetJournal.GetPetInfoByItemID, itemId)
        return ok and type(nm) == "string" and byName[nm] or nil
    end
    local codex = _G.SeviathsCodexDB
    local vendorItems, vendors = codex and codex.vendorItems, codex and codex.vendors
    if vendorItems and vendors then
        for id, keys in (SeviathsAllPairs or pairs)(vendorItems) do
            local e = petOf(id)
            if e and type(keys) == "table" then
                for _, key in ipairs(keys) do
                    local v = vendors[key]
                    if type(v) == "table" and v.items and v.items[id] and v.items[id] ~= "?" and not e.vendorCost then
                        e.vendorCost, e.vendorItem = v.items[id], id
                    end
                    if not e.map and type(v) == "table" and v.m and v.x then
                        e.map, e.x, e.y = v.m, v.x, v.y
                        e.who = "Vendor " .. tostring(v.n or tostring(key):match("^(.-)@") or "?")
                        break
                    end
                end
            end
        end
    end
    local checked = {}
    for mapID, zone in pairs(SFP.zoneByMap) do
        for _, sp in ipairs(zone.spawns or {}) do
            for _, id in ipairs(sp.items or {}) do
                local info = SFP.Items[id]
                if info and info.kind == "pet" then
                    local e = petOf(id)
                    if e and not e.map and sp.hx then e.map, e.x, e.y, e.who = mapID, sp.hx, sp.hy, "Drop " .. tostring(sp.name) end
                end
            end
        end
    end
    for _, rec in (SeviathsAllPairs or pairs)(SFP.db and SFP.db.npcs or {}) do
        if type(rec) == "table" and rec.n and type(rec.d) == "table" and type(rec.m) == "table" then
            for id in pairs(rec.d) do
                if checked[id] == nil then checked[id] = petOf(id) or false end
                local e = checked[id]
                if e and not e.map then
                    for map, pts in pairs(rec.m) do
                        local p = type(pts) == "table" and pts[1]
                        if p and p[1] and p[2] then e.map, e.x, e.y, e.who = map, p[1], p[2], "Drop " .. rec.n break end
                    end
                end
            end
        end
    end
    for _, e in ipairs(entries) do
        -- a wild pet with exact places (Data/WildPetSpots.lua, TomTom lines of Wowhead's wild pet guide): the one on the map you are viewing,
        -- else the first
        if not e.map and SFP.WildPetSpots then
            local spots = SFP.WildPetSpots[e.name]
            if not spots then
                for nm, sp in pairs(SFP.WildPetSpots) do
                    if nm:lower() == e.name:lower() then spots = sp break end
                end
            end
            if spots and spots[1] then
                local here = WorldMapFrame:GetMapID()
                local pick = spots[1]
                for _, s in ipairs(spots) do if s[1] == here then pick = s break end end
                e.map, e.x, e.y = pick[1], pick[2], pick[3]
                e.zoneName = SFP:ZoneName(pick[1])
                e.wildCount = #spots
            end
        end
        e.who = e.who or e.vendorName and ("Vendor " .. e.vendorName) or (e.dropName and ("Drop " .. e.dropName)) or nil
    end
end

local function petEntries()
    local out = {}
    if not (C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID) then return out end
    local prices = petPrices()
    for i = 1, 6000 do
        local ok, name, icon, petType, _, source, _, _, canBattle, tradeable = pcall(C_PetJournal.GetPetInfoBySpeciesID, i)
        if ok and type(name) == "string" and name ~= "" then
            local kept = SFP.db and SFP.db.petInfo and SFP.db.petInfo[name]
            if not icon and kept then icon = kept.icon end
            if (not source or source == "") and kept then source = kept.source end
            out[#out + 1] = { species = i, name = name, icon = icon, petType = petType, source = source, tradeable = tradeable,
                canBattle = canBattle, price = prices[i] }
        end
    end
    petSpots(out)
    return out
end

renderPetTree = function()
    local n = 0
    local function row(text, key)
        n = n + 1
        local r = rowOf(tree, n)
        place(tree, r, n, key == "all" and 0 or 12)
        r.icon:SetTexture(nil)
        r.text:SetText((expSel == key and "|cffe6483d" or "|cffffffff") .. text .. "|r")
        r.bg:SetColorTexture(0.9, 0.28, 0.24, expSel == key and 0.15 or 0.06)
        r.click = function()
            expSel = key
            search:SetText("")
            renderPetTree()
            win.refreshList()
        end
    end
    row("All battle pets", "all")
    row("With an auction price", "priced")
    for t = 1, 10 do row(_G["BATTLE_PET_NAME_" .. t] or ("Family " .. t), t) end
    finish(tree, n)
end

local function renderPets(q)
    local ql = q and q:lower() or ""
    win.title:SetText("|cffffd100Battle pets|r" .. (#ql > 0 and ("  |cffffd100" .. q .. "|r") or ""))
    entriesCache = entriesCache or petEntries()
    local entries = {}
    for _, e in ipairs(entriesCache) do
        local ok
        if #ql >= 2 then ok = e.name:lower():find(ql, 1, true)
        elseif expSel == "all" then ok = true
        elseif expSel == "priced" then ok = e.price
        else ok = e.petType == expSel end
        if ok then entries[#entries + 1] = e end
    end
    for _, e in ipairs(entries) do
        local label = plain(e.source or ""):match("^%s*([%a][%a%s%-']-):")
        e.section = label or "Other"
    end
    table.sort(entries, function(a, c)
        if a.section ~= c.section then return a.section < c.section end
        if (a.price and 1 or 0) ~= (c.price and 1 or 0) then return a.price ~= nil end
        if a.price and a.price ~= c.price then return a.price > c.price end
        return a.name < c.name
    end)
    local counts = {}
    for _, e in ipairs(entries) do counts[e.section] = (counts[e.section] or 0) + 1 end
    local n = 0
    local lastSection
    for _, e in ipairs(entries) do
        if n >= 800 then break end
        if e.section ~= lastSection then
            lastSection = e.section
            n = headerRow(n, "|cffffd100" .. e.section .. "|r  |cff808080" .. counts[e.section] .. "|r")
        end
        n = n + 1
        local r = rowOf(list, n)
        place(list, r, n, 8)
        r.icon:SetTexture(e.icon)
        local where = (e.who and (e.who .. (e.zoneName and " - " or "")) or "") .. (e.zoneName or "")
        if e.wildZones and #e.wildZones > 1 and not e.who then
            where = table.concat(e.wildZones, ", ", 1, math.min(#e.wildZones, 3)) .. (#e.wildZones > 3 and (" +" .. (#e.wildZones - 3)) or "")
        end
        r.text:SetText(e.name .. "  |cff808080" .. (_G["BATTLE_PET_NAME_" .. tostring(e.petType)] or "") .. "|r" ..
            (where ~= "" and ("  |cffffd100" .. where .. "|r") or ""))
        local priceStr
        if e.tradeable ~= false and e.price then priceStr = SFP:FormatPrice(e.price)
        elseif e.vendorCost then priceStr = "|cff808080vendor|r " .. e.vendorCost
        elseif e.tradeable == false then priceStr = "|cffff8080not tradeable|r"
        else priceStr = "|cff808080no price yet|r" end
        r.right:SetText(((e.map or e.zoneMap) and "|cffff3030WAYPOINT|r   " or "") .. priceStr)
        r.hint = plain(e.source or "") .. (e.tradeable and "" or "\n|cffff8080Not tradeable|r") .. (e.map and "\n|cffe6483dClick: waypoint at the place and open the map there|r" or "")
        if e.map then r.click = function() openWaypoint(e.map, e.x, e.y, e.vendorName or e.dropName or e.name) end
        elseif e.zoneMap then
            -- no exact spot known: the waypoint opens the map of the zone
            r.click = function()
                WorldMapFrame:SetMapID(e.zoneMap)
                SFP:Print(string.format("%s: no exact spot known, the map of %s is open.", e.name, SFP:ZoneName(e.zoneMap)))
            end
        end
    end
    if n == 0 then n = headerRow(0, "|cff808080Nothing found|r") end
    finish(list, n)
end

openWaypoint = function(map, x, y, label)
    if not map then return end
    if WorldMapFrame:GetMapID() ~= map then WorldMapFrame:SetMapID(map) end
    if x and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        SFP:Print(string.format("Waypoint set: %s, %s %.1f, %.1f", tostring(label), SFP:ZoneName(map), x * 100, y * 100))
        if SFP.PingSpot then SFP.PingSpot(map, x, y) end
    end
end

headerRow = function(n, text)
    n = n + 1
    local h = rowOf(list, n)
    place(list, h, n, 0)
    h.icon:SetTexture(nil)
    h.text:SetText(text)
    h.bg:SetColorTexture(1, 1, 1, 0.06)
    h.hl:Hide()
    return n
end

-- Every mount of the game (the mount journal), with where to get it: the instances and rares the addon knows (with the drop chance - your own
-- count of tries and drops when there is one - and the place), vendors and places named in the journal's own source text, and the places
-- you were when a mount was added. Rarest first.
local function mountEntries()
    local base = mountEntriesBase()
    local MJ = C_MountJournal
    local entries, byMount = {}, {}
    for _, e in ipairs(base) do
        local mid = MJ and MJ.GetMountFromItem and MJ.GetMountFromItem(e.item)
        e.mountID = mid
        if mid then byMount[mid] = e end
        -- the chance of the item: the data's "~1%" or your own tries and drops
        local pct
        local info = SFP.Items[e.item]
        if info and info.drop then pct = tonumber(tostring(info.drop):match("([%d%.]+)")) end
        local stats = SFP.db and SFP.db.mountStats and SFP.db.mountStats[e.item]
        local n, d = 0, 0
        for _, st in pairs(stats or {}) do n, d = n + (st.n or 0), d + (st.d or 0) end
        if n > 0 then pct = 100 * d / n end
        e.rarity = pct
        entries[#entries + 1] = e
    end
    if MJ and MJ.GetMountIDs then
        -- vendor places by name (the Codex records every vendor visited)
        local vend = {}
        local vendors = _G.SeviathsCodexDB and _G.SeviathsCodexDB.vendors
        for key, v in (SeviathsAllPairs or pairs)(vendors or {}) do
            if type(v) == "table" and v.m and v.x then
                local nm = v.n or tostring(key):match("^(.-)@")
                if nm and not vend[nm] then vend[nm] = { map = v.m, x = v.x, y = v.y } end
            end
        end
        -- a cost text with the icons of what is paid: a currency or an item (an older record has only the names)
        local function costIcons(text)
            if type(text) ~= "string" or text:find("|T", 1, true) then return text end
            local parts = {}
            for part in text:gmatch("[^+]+") do
                part = part:gsub("^%s+", ""):gsub("%s+$", "")
                local amount, nm = part:match("^([%d,]+)%s+(.+)$")
                local icon
                if nm and C_Item and C_Item.GetItemInfoInstant then
                    local ok, _, _, _, _, ic = pcall(C_Item.GetItemInfoInstant, nm)
                    if ok and ic then icon = ic end
                end
                if icon then parts[#parts + 1] = amount .. " |T" .. icon .. ":14|t " .. nm else parts[#parts + 1] = part end
            end
            return table.concat(parts, " + ")
        end
        local vendorByMount = {}
        local vitems = _G.SeviathsCodexDB and _G.SeviathsCodexDB.vendorItems
        local vlist = _G.SeviathsCodexDB and _G.SeviathsCodexDB.vendors
        if vitems and vlist and MJ.GetMountFromItem then
            for itemId, keys in (SeviathsAllPairs or pairs)(vitems) do
                local mid2 = type(itemId) == "number" and MJ.GetMountFromItem(itemId)
                if mid2 and type(keys) == "table" then
                    local l = vendorByMount[mid2]
                    if not l then l = {}; vendorByMount[mid2] = l end
                    for _, key in ipairs(keys) do
                        local v = vlist[key]
                        if type(v) == "table" and v.items then
                            l[#l + 1] = { v = v, key = key, cost = costIcons(v.items[itemId]), item = itemId }
                        end
                    end
                end
            end
        end
        for _, mid in ipairs(MJ.GetMountIDs()) do
            local name, _, icon, _, _, _, _, _, _, hide, collected = MJ.GetMountInfoByID(mid)
            if name then
                local e = byMount[mid]
                if not e then
                    e = { mountID = mid, sources = {} }
                    byMount[mid] = e
                    entries[#entries + 1] = e
                end
                e.mountName, e.icon, e.collected = name, icon, collected
                for _, vv in ipairs(vendorByMount[mid] or {}) do
                    local v = vv.v
                    local costStr = (vv.cost and vv.cost ~= "?") and vv.cost or nil
                    e.sources[#e.sources + 1] = {
                        text = "Vendor: " .. tostring(v.n or tostring(vv.key):match("^(.-)@") or "?") .. (costStr and ("  |cffffd100" .. costStr .. "|r") or ""),
                        map = v.m, x = v.x, y = v.y,
                    }
                    if costStr and not e.cost then e.cost = costStr end
                    e.item = e.item or vv.item
                end
                local _, _, src, _, mtid = MJ.GetMountInfoExtraByID(mid)
                e.mtype = MOUNT_KIND[mtid or 0] or "ground"
                src = plain(src or "")
                e.sourceText = src
                -- a place from the journal's text, when the addon's own sources have none
                local hasSpot = false
                for _, s in ipairs(e.sources) do if s.map then hasSpot = true end end
                if not hasSpot and src ~= "" then
                    local vname = src:match("Vendor:%s*([^\n]+)")
                    local zname = src:match("Zone:%s*([^\n]+)")
                    local spot = vname and vend[vname]
                    local zm = zname and mapOfZone(zname)
                    local first = src:gsub("\n+", "  "):sub(1, 90)
                    local s = { text = first }
                    if spot then s.map, s.x, s.y = spot.map, spot.x, spot.y
                    elseif zm then s.zoneMap = zm end
                    s.zone = zname
                    e.sources[#e.sources + 1] = s
                elseif src ~= "" and #e.sources == 0 then
                    e.sources[1] = { text = src:gsub("\n+", "  "):sub(1, 90) }
                end
                -- the guide's source text of this mount
                if SFP.MountGuide then
                    if not SFP._mountGuideLower then
                        SFP._mountGuideLower = {}
                        for gname, gsrc in pairs(SFP.MountGuide) do SFP._mountGuideLower[gname:lower()] = gsrc end
                    end
                    local gsrc = SFP._mountGuideLower[name:lower()]
                    if not gsrc and e.item then gsrc = SFP._mountGuideLower[plain(iname(e.item)):lower()] end
                    if gsrc then
                        local cost = gsrc:match("Costs? ?:? ?([%d,]+ [^|]-)%s*$") or gsrc:match("Costs? ?:? ?([%d,]+ [^|]-)%s*|")
                            or gsrc:match("for ([%d,]+%s*x?%s*[^,;/]+)$") or gsrc:match("^(%d+%s*x%s+.+)$")
                        if cost and costIcons then cost = costIcons(cost) end
                        local gzone = gsrc:match(" %- ([^,]+),") or gsrc:match(" %- ([^,]+)$") or gsrc:match(" in ([%u][^,/]-)$")
                        if gzone then gzone = gzone:gsub("^the ", ""):gsub("%s+$", "") end
                        local gm = gzone and mapOfZone(gzone)
                        local gs = { text = "Guide: " .. gsrc:sub(1, 110), zone = gzone, zoneMap = gm }
                        -- the exact place the guide names (a cache, a skull, a cauldron): a waypoint
                        if SFP.MountGuideSpots then
                            for sname, sp in pairs(SFP.MountGuideSpots) do
                                if gsrc:find(sname, 1, true) and sp[1] then gs.map, gs.x, gs.y = sp[1][1], sp[1][2], sp[1][3]; break end
                            end
                        end
                        e.sources[#e.sources + 1] = gs
                        if cost then e.cost = e.cost or cost end
                    end
                end
                -- a place where you added it: the most exact one
                local here = SFP.db and SFP.db.mountSpots and SFP.db.mountSpots[name]
                if type(here) == "table" and here.m then
                    table.insert(e.sources, 1, { text = "Collected here", map = here.m, x = here.x, y = here.y })
                end
            end
        end
    end
    for _, e in ipairs(entries) do e.rarity = e.rarity or 100 end
    return entries
end

local function renderMounts(q)
    local ql = q and q:lower() or ""
    local n = 0
    win.title:SetText("|cffa335eeMounts|r  |cffaaaaaararest first|r" .. (#ql > 0 and ("  |cffffd100" .. q .. "|r") or ""))
    entriesCache = entriesCache or mountEntries()
    local function nameOf(e) return e.mountName or plain(iname(e.item)) end
    local entries = {}
    for _, e in ipairs(entriesCache) do
        local nm = (nameOf(e) .. " " .. (e.item and plain(iname(e.item)) or "")):lower()
        if (#ql >= 2 and nm:find(ql, 1, true)) or (#ql < 2 and mountSel(e)) then entries[#entries + 1] = e end
    end
    table.sort(entries, function(a, c)
        if a.rarity ~= c.rarity then return a.rarity < c.rarity end
        return nameOf(a) < nameOf(c)
    end)
    for k, e in ipairs(entries) do
        if k > 900 then break end
        n = n + 1
        local r = rowOf(list, n)
        place(list, r, n, 8)
        r.icon:SetTexture(e.item and SFP:ItemIcon(e.item) or e.icon or 134400)
        local chance = e.rarity < 100 and ("  |cff40ff40" .. (e.rarity >= 10 and string.format("%d", math.floor(e.rarity + 0.5)) or string.format("%.1f", e.rarity)) .. "%|r") or ""
        r.text:SetText((e.collected and "|cff40ff40" or "|cffffffff") .. nameOf(e) .. "|r" .. chance)
        -- the price: the auction or vendor price, else what the guide says it costs (a token or currency, not only gold)
        local costText = e.item and priceText(e.item) or ""
        if costText == "" and e.cost then costText = "|cff808080cost|r " .. e.cost end
        r.right:SetText(costText)
        r.item = e.item
        -- the name bar is a waypoint too: the first source with a place
        for _, s in ipairs(e.sources) do
            if s.map then
                r.click = function() openWaypoint(s.map, s.x, s.y, nameOf(e)) end
                break
            elseif s.zoneMap then
                r.click = function() WorldMapFrame:SetMapID(s.zoneMap) end
                break
            end
        end
        for _, s in ipairs(e.sources) do
            n = n + 1
            local m = rowOf(list, n)
            place(list, m, n, 30)
            m.icon:SetTexture(nil)
            m.text:SetText("|cffe6483d" .. s.text .. "|r")
            local located = s.map or s.zoneMap
            m.right:SetText(located and ("|cffff3030WAYPOINT|r" .. (s.zone and ("   |cff808080" .. s.zone .. "|r") or "")) or (s.zone and ("|cff808080" .. s.zone .. "|r") or "|cff808080no place known|r"))
            if s.map then
                m.hint = "Click: set a waypoint and open the map there"
                m.click = function() openWaypoint(s.map, s.x, s.y, nameOf(e)) end
            elseif s.zoneMap then
                m.hint = "Click: open the map of the zone (no exact spot known)"
                m.click = function() WorldMapFrame:SetMapID(s.zoneMap) end
            end
        end
        n = spacer(n)
    end
    if n == 0 then n = headerRow(0, "|cff808080Nothing found|r") end
    finish(list, n)
end

local function renderHunters(q)
    local ql = q and q:lower() or ""
    local n = 0
    win.title:SetText("|cffabd473Hunter pets|r" .. (#ql > 0 and ("  |cffffd100" .. q .. "|r") or ""))
    entriesCache = entriesCache or hunterEntries()
    local entries = {}
    for _, e in ipairs(entriesCache) do
        local nm = tostring(e.name):lower()
        if (#ql >= 2 and (nm:find(ql, 1, true) or tostring(e.kind):lower():find(ql, 1, true)))
            or (#ql < 2 and (expSel == "all" or e.exp == expSel)) then
            entries[#entries + 1] = e
        end
    end
    table.sort(entries, function(a, c)
        if expOrder(a.exp) ~= expOrder(c.exp) then return expOrder(a.exp) < expOrder(c.exp) end
        if a.map ~= c.map then return SFP:ZoneName(a.map) < SFP:ZoneName(c.map) end
        return tostring(a.name) < tostring(c.name)
    end)
    local lastExp
    for _, e in ipairs(entries) do
        if e.exp ~= lastExp then
            lastExp = e.exp
            local en
            for _, x in ipairs(SFP.Expansions) do if x.key == e.exp then en = x.name end end
            n = headerRow(n, "|cffffd100" .. (en or "Other") .. "|r")
        end
        n = n + 1
        local r = rowOf(list, n)
        place(list, r, n, 8)
        r.icon:SetTexture("Interface\\Icons\\ClassIcon_Hunter")
        r.text:SetText("|cffe6483d" .. tostring(e.name) .. "|r")
        r.right:SetText("|cffff3030WAYPOINT|r   |cff808080" .. SFP:ZoneName(e.map) .. "|r   |cffabd473" .. e.kind .. "|r")
        r.hint = (e.x and "Click: set a waypoint and open the map there") or "Click: open the map"
        r.click = function() openWaypoint(e.map, e.x, e.y, tostring(e.name)) end
    end
    if n == 0 then n = headerRow(0, "|cff808080Nothing found|r") end
    finish(list, n)
end

local function setMode(m)
    mode = m
    if win and win.tabs then
        win.tabs.monsters:SetShown(m == "mat")
        win.tabs.gather:SetShown(m == "mat" and not itemMode)
        if win.curBtn then win.curBtn:SetShown(m == "farm" or m == "rare") end
        if win.topBtn then win.topBtn:SetShown(m == "farm" or m == "rare" or m == "top") end
        if win.curBtn then win.curBtn:SetShown(m == "farm" or m == "rare" or m == "top") end
    end
    entriesCache = nil
    expSel = "all"
    if win then
        search:SetText("")
        win.header:SetText("|c" .. SFP.CYAN_HEX .. (m == "top" and "Best 15 spots" or m == "mount" and "Mount search" or m == "hunter" and "Hunter search" or m == "pet" and "Battle pets" or m == "farm" and "Farm spots" or m == "rare" and "Rares" or (itemMode and "Item search" or "Material search")) .. "|r")
    end
end

-- the monsters the addon has collected (kills and loot, with positions), by map: normal monsters (elites too) for Farm spots, rares for
-- Rares; no bosses, no monster that drops a battle pet (those are under Battle pets). Built when first needed, dropped with the window.
local monsterIndex = {}   -- [map] = { farm = {}, rare = {} }, made when that map is asked for
local rareMapSet
local function collectedMonsters(map, group)
    local byMap = monsterIndex[map]
    if not byMap then
        byMap = { farm = {}, rare = {} }
        monsterIndex[map] = byMap
        local npcByName = {}
        for _, e in ipairs(recsOfMap(map)) do
            local npcID, rec = e.id, e.rec
            -- a monster recorded before its name was known ("NPC 246330"): the game is asked for it, and it is left out while it has none
            if type(rec.n) == "string" and rec.n:find("^NPC %d+$") and type(npcID) == "number" and SFP.NpcNameFor then
                local real = SFP:NpcNameFor(npcID)
                if type(real) == "string" and real ~= "" and not real:find("^NPC %d+$") then rec.n = real end
            end
            if rec.n and not npcByName[rec.n] then npcByName[rec.n] = npcID end
            -- a rare is listed as soon as it was seen or killed, with or without loot (the farm data does not have to know it yet)
            local isRare = rec.c == "rare" or rec.c == "rareelite"
            local hasDrops = (type(rec.d) == "table" and next(rec.d) ~= nil) or (type(rec.s) == "table" and next(rec.s) ~= nil)
            if rec.n and not tostring(rec.n):find("^NPC %d+$") and type(rec.m) == "table" and (hasDrops or isRare or (rec.k or 0) > 0) and not rec.boss then
                local cls = rec.c
                local g = (cls == "rare" or cls == "rareelite") and "rare" or ((cls ~= "worldboss" and cls ~= "boss") and "farm" or nil)
                local pts = rec.m[map]
                local p = type(pts) == "table" and pts[1]
                if g and p and p[1] and p[2] then
                    local list = byMap[g]
                    list[#list + 1] = { name = rec.n, npc = npcID, hx = p[1], hy = p[2], items = {}, kills = rec.k or 0, map = map, rare = (g == "rare") or nil,
                        level = rec.lmax or rec.lmin, ctype = rec.t, family = rec.f }
                end
            end
        end
        -- the rares seen on the map: the place, and the loot of the monster of that name when the addon has one
        for _, r in (SeviathsAllPairs or pairs)(SFP.db and SFP.db.rareSeen or {}) do
            if type(r) == "table" and r.n and r.m == map and r.x then
                local dup = false
                for _, s in ipairs(byMap.rare) do if s.name == r.n then dup = true break end end
                if not dup then
                    local npc = npcByName[r.n]
                    local rec = npc and SFP:Npc(npc)
                    byMap.rare[#byMap.rare + 1] = { name = r.n, npc = npc, hx = r.x, hy = r.y, items = {}, kills = rec and rec.k or 0, map = r.m, rare = true,
                        level = rec and (rec.lmax or rec.lmin), ctype = rec and rec.t }
                end
            end
        end
        for _, list in pairs(byMap) do table.sort(list, function(a, c) return a.name < c.name end) end
    end
    return byMap[group] or {}
end

-- Farm spots and Rares: the same window - the zones on the left, and for the zone picked a block per monster: its name and a red
-- WAYPOINT, its place, everything it drops (grey items too) with how often and the price, and a space before the next one
-- the monsters of a zone for Farm spots / Rares: the addon's farm data and the collected monsters, each name once
local function farmSpotsOwn(map, group)
    local spots = (map and SFP.FarmSpotsOf) and SFP.FarmSpotsOf(map, group) or {}
    if not map then return spots end
    local have, merged = {}, {}
    for _, s in ipairs(spots) do have[tostring(s.name):lower()] = true; merged[#merged + 1] = s end
    for _, s in ipairs(collectedMonsters(map, group)) do
        if not have[s.name:lower()] then have[s.name:lower()] = true; merged[#merged + 1] = s end
    end
    return merged
end

-- a map with no monsters of its own (a continent or a region: "Quel'Thalas") shows those of the zones inside it, each with its own map
local function farmSpotsFor(map, group)
    local own = farmSpotsOwn(map, group)
    if #own > 0 or not map or not (C_Map and C_Map.GetMapChildrenInfo) then return own end
    local out = {}
    for _, child in ipairs(C_Map.GetMapChildrenInfo(map, nil, true) or {}) do
        for _, s in ipairs(farmSpotsOwn(child.mapID, group)) do
            if s.map then out[#out + 1] = s
            else out[#out + 1] = setmetatable({ map = child.mapID }, { __index = s }) end
        end
    end
    table.sort(out, function(a, c) return tostring(a.name) < tostring(c.name) end)
    return out
end

-- the blocks of some monsters of one map: name and red WAYPOINT, place, all the loot (grey items too), a space after each
local function renderBlocks(n, map, spots, compact)
    local parentMap = map
    for _, s in ipairs(spots) do
        local map = s.map or parentMap
        local loot, kills = SFP.MonsterLoot(s)
        local x0, y0 = s.hx, s.hy
        local top = loot[1] and loot[1].id or (s.items and s.items[1])
        n = n + 1
        local r = rowOf(list, n)
        place(list, r, n, 8)
        r.icon:SetTexture(MONSTER_ICON)
        r.text:SetText((s.rank and ("|cffffd100" .. s.rank .. ".|r  ") or "") .. "|cffe6483d" .. tostring(s.name) .. "|r")
        r.right:SetText("|cffff3030WAYPOINT|r")
        r.hint = "Click: set a waypoint on " .. tostring(s.name) .. " and open the map there"
        r.click = function() goToMonster(map, s) end
        local function lootTip(t)
            t:AddLine(tostring(s.name), 1, 0.5, 0)
            t:AddLine(SFP:ZoneName(map) .. "  " .. (s.hx and string.format("%.1f, %.1f", s.hx * 100, s.hy * 100) or ""), 1, 0.82, 0)
            if type(s.note) == "string" and s.note ~= "" then t:AddLine(s.note, 0.8, 0.8, 0.8, true) end
            t:AddLine(" ")
            if SFP.AddSpotDrops then SFP.AddSpotDrops(t, s) end
            -- like the map tooltip: everything else worth farming in the zone, any mob there can drop it
            local zone = SFP.zoneByMap[map]
            local exp = SFP.zoneExp and SFP.zoneExp[map]
            local have = {}
            for _, id in ipairs(s.items or {}) do have[id] = true end
            local rest = {}
            local function add(id)
                local info = SFP.Items[id]
                if not have[id] and not (info and (info.kind == "ore" or info.kind == "herb" or info.kind == "enchant")) then
                    have[id] = true
                    rest[#rest + 1] = id
                end
            end
            for _, id in ipairs(zone and zone.items or {}) do add(id) end
            for _, id in ipairs(exp and exp.anywhere or {}) do add(id) end
            if #rest > 0 then
                t:AddLine(" ")
                t:AddLine("Also in " .. SFP:ZoneName(map) .. "  |cff808080any monster there|r", 0.8, 0.8, 0.8)
                table.sort(rest, function(x, y) return (SFP:GetPrice(x) or 0) > (SFP:GetPrice(y) or 0) end)
                for k, id in ipairs(rest) do
                    if k > 30 then t:AddLine("+" .. (#rest - 30) .. " more", 0.6, 0.6, 0.6) break end
                    t:AddDoubleLine("|T" .. SFP:ItemIcon(id) .. ":12|t " .. iname(id), priceText(id), 1, 1, 1, 1, 1, 1)
                end
            end
            t:AddLine("Click: set a waypoint", 0.9, 0.28, 0.24)
        end
        r.spotTip = { s, map }   -- hovering the name shows the map's whole tooltip of that monster
        n = n + 1
        local p = rowOf(list, n)
        place(list, p, n, 30)
        p.icon:SetTexture(nil)
        p.text:SetText("|cffffd100" .. SFP:ZoneName(map) .. "|r  |cffaaaaaa" .. SFP.AreaAt(map, x0, y0) .. "|r  |cff808080" ..
            (x0 and string.format("%.1f, %.1f", x0 * 100, y0 * 100) or "") .. "|r" ..
            ((s.level or s.ctype) and ("  |cff808080" .. (s.level and ("level " .. s.level .. " ") or "") .. (s.family or s.ctype or "") .. "|r") or "") ..
            (s.valueText or ""))
        p.hint = "Click: set a waypoint on " .. tostring(s.name) .. " and open the map there"
        p.click = function() goToMonster(map, s) end
        p.spotTip = { s, map }
        if not compact and type(s.note) == "string" and s.note ~= "" then
            n = n + 1
            local nr = rowOf(list, n)
            place(list, nr, n, 30)
            nr.icon:SetTexture(nil)
            nr.text:SetText("|cffaaaaaa" .. s.note .. "|r")
            nr.hint = s.note
            nr.hl:Hide()
        end
        for _, d in ipairs(compact and {} or loot) do
            n = n + 1
            local l = rowOf(list, n)
            place(list, l, n, 30)
            l.icon:SetTexture(SFP:ItemIcon(d.id))
            l.text:SetText(iname(d.id))
            local price = SFP:GetPrice(d.id)
            -- the amount: what was looted in all, and per kill
            local per = (kills >= 1 and d.q > 0) and (d.q / kills) or nil
            local perText = per and (per >= 10 and string.format("%d", math.floor(per + 0.5)) or string.format("%.1f", per)) or nil
            if d.q > 0 then
                local chance = SFP.ChanceText(d.q, kills)
                if chance == "" and kills >= 1 then chance = string.format("%d%%", math.min(100, math.floor(d.q * 100 / kills + 0.5))) end   -- like the monster tooltip: a plain percentage until 3 kills
                l.text:SetText(iname(d.id) .. "  |cff808080x" .. d.q .. "|r" .. (chance ~= "" and ("  |cff40ff40" .. chance .. "|r") or ""))
            end
            l.right:SetText((perText and ("|cffffd100" .. perText .. " per kill|r   ") or "") .. priceText(d.id))
            -- the materials are plain text here: no highlight, no tooltip, nothing under the mouse
            l:EnableMouse(false)
            l.hl:Hide()
        end
        local gold, goldKills = SFP.MonsterGold and SFP.MonsterGold(s)
        if gold and not compact then
            n = n + 1
            local g = rowOf(list, n)
            place(list, g, n, 30)
            g.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
            g.text:SetText("Gold")
            g.right:SetText("|cffffd100" .. SFP:FormatPrice(math.floor(gold)) .. " per kill|r")
            g:EnableMouse(false)
            g.hl:Hide()
        end
        if compact then
            -- the loot is in the tooltip of the name
        elseif #loot == 0 then
            n = n + 1
            local l = rowOf(list, n)
            place(list, l, n, 30)
            l.icon:SetTexture(nil)
            l.text:SetText("|cff808080" .. (s.note and "no collectible drop known - kill it and its loot is recorded" or "no loot recorded yet") .. "|r")
            l.hl:Hide()
        elseif kills < 1 then
            -- a monster of the farm guide that has no kill recorded: only the items it is listed for are known, not all it drops
            n = n + 1
            local l = rowOf(list, n)
            place(list, l, n, 30)
            l.icon:SetTexture(nil)
            l.text:SetText("|cff808080from the farm guide: only what it is farmed for. Kill it and everything it drops is recorded.|r")
            l:EnableMouse(false)
            l.hl:Hide()
        end
        n = spacer(n)
    end
    return n
end

-- does a zone have monsters for the list (for the zone tree on the left)
local function zoneHasMonsters(map, group)
    if #(SFP.FarmSpotsOf and SFP.FarmSpotsOf(map, group == "rare" and "rare" or "farm") or {}) > 0 then return true end
    -- monsters of the player's own or the shipped data on that map (the records themselves are read only when the zone is picked)
    return guideMaps()[map] and true or false
end

-- the 15 best farm spots of the whole database: the value of what a monster drops per kill (the chance of each item times its auction
-- price), over the monsters with at least 3 kills recorded
local function renderTop()
    local n = 0
    win.title:SetText("|c" .. SFP.CYAN_HEX .. "Best 15 farm spots|r  |cffaaaaaathis week|r")
    local function valueOf(s)
        local loot, kills = SFP.MonsterLoot(s)
        if kills < 3 then return 0 end
        local val = 0
        for _, d in ipairs(loot) do
            local price = SFP:GetPrice(d.id)
            if price and d.q > 0 and SFP:SoldState(d.id) ~= false then val = val + price * d.q / kills end   -- an item that never sells at the auction house is left out
        end
        local gold = SFP.MonsterGold and SFP.MonsterGold(s)
        if gold then val = val + gold end
        return val
    end
    -- the ranking is made once a week, at the weekly reset (with that day's prices), and kept for the week; a spot learned later is in
    -- the database and the search at once, and can be in the next week's ranking
    local resetIn = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
    -- the hour of the next reset, rounded: the seconds left jitter by one, which would flip a plain floor at the hour and remake the ranking again and again
    local weekKey = resetIn and math.floor((time() + resetIn) / 3600 + 0.5) or nil
    local saved = SFP.db.topSpots
    if not (saved and weekKey and saved.week == weekKey and saved.list and #saved.list > 0) then
        local maps, seenMap = {}, {}
        for map in pairs(SFP.zoneByMap) do if not seenMap[map] then seenMap[map] = true; maps[#maps + 1] = map end end
        for map in pairs(guideMaps()) do if not seenMap[map] then seenMap[map] = true; maps[#maps + 1] = map end end
        local ranked = {}
        for _, map in ipairs(maps) do
            for _, s in ipairs(farmSpotsFor(map, "farm")) do
                local val = valueOf(s)
                if val > 0 then ranked[#ranked + 1] = { map = map, name = tostring(s.name), npc = s.npc, val = val } end
            end
        end
        table.sort(ranked, function(a, c) return a.val > c.val end)
        local keep = {}
        for k = 1, math.min(15, #ranked) do keep[k] = { map = ranked[k].map, name = ranked[k].name, npc = ranked[k].npc } end
        saved = { week = weekKey, list = keep }
        if weekKey and #keep > 0 then SFP.db.topSpots = saved end
    end
    for k, e in ipairs(saved.list) do
        for _, s in ipairs(farmSpotsFor(e.map, "farm")) do
            if (e.npc and s.npc == e.npc) or (not e.npc and tostring(s.name) == e.name) then
                local val = valueOf(s)
                s.rank = k
                s.valueText = "   |cff40ff40" .. (val > 0 and (SFP:FormatPrice(math.floor(val)) .. " per kill") or "no price now") .. "|r"
                n = renderBlocks(n, e.map, { s })
                break
            end
        end
    end
    if n == 0 then n = headerRow(0, "|cff808080No monster has enough kills and prices recorded yet|r") end
    finish(list, n)
end

local function renderFarmList(group)
    local n = 0
    local label = group == "rare" and "|cffff8000Rares|r" or ("|c" .. SFP.CYAN_HEX .. "Farm spots|r")
    local q = strtrim(search and search:GetText() or "")
    if #q >= 2 then
        -- a search: the monsters of that name in every zone
        win.title:SetText(label .. "  |cffffd100" .. q .. "|r")
        local ql, found = q:lower(), 0
        local maps, seenMap = {}, {}
        for map in pairs(SFP.zoneByMap) do if not seenMap[map] then seenMap[map] = true; maps[#maps + 1] = map end end
        for map in pairs(guideMaps()) do if not seenMap[map] then seenMap[map] = true; maps[#maps + 1] = map end end
        table.sort(maps, function(a, c) return SFP:ZoneName(a) < SFP:ZoneName(c) end)
        for _, map in ipairs(maps) do
            local mine = {}
            for _, s in ipairs(farmSpotsFor(map, group)) do
                if tostring(s.name):lower():find(ql, 1, true) then mine[#mine + 1] = s end
            end
            if #mine > 0 and found < 80 then
                found = found + #mine
                n = renderBlocks(n, map, mine)
            end
        end
    else
        local map = selected
        if type(map) ~= "number" then map = WorldMapFrame:GetMapID() end
        win.title:SetText(label .. "  |cffaaaaaa" .. (map and SFP:ZoneName(map) or "") .. "|r")
        -- Farm spots and Rares work the same: a row is the name and the place, and hovering it shows the map's whole tooltip of that monster
        if map then n = renderBlocks(n, map, farmSpotsFor(map, group)) end
    end
    if n == 0 then n = headerRow(0, "|cff808080Nothing recorded|r") end
    finish(list, n)
end

local function renderList()
    if not win then return end
    local q = strtrim(search:GetText() or "")
    if mode == "mount" then return renderMounts(q) end
    if mode == "hunter" then return renderHunters(q) end
    if mode == "pet" then return renderPets(q) end
    if mode == "farm" then return renderFarmList("farm") end
    if mode == "top" then return renderTop() end
    if mode == "rare" then return renderFarmList("rare") end
    if matTab == "gather" then return renderGather(#q >= 2 and q or nil) end
    if #q >= 2 then renderSearch(q) else renderZone() end
end

---------------------------------------------------------------------------
-- the tree of expansions and zones
---------------------------------------------------------------------------
local renderTree
local function renderTreeMat()
    local n = 0
    local monsterMode = (mode == "farm" or mode == "rare" or mode == "top")
    local zq = monsterMode and strtrim(search and search:GetText() or "") or ""
    if monsterMode then
        local cur = WorldMapFrame:GetMapID()
        n = 1
        local r = rowOf(tree, 1)
        place(tree, r, 1, 0)
        r.icon:SetTexture(nil)
        r.text:SetText("|cffe6483dCurrent zone|r" .. (cur and ("  |cffaaaaaa" .. SFP:ZoneName(cur) .. "|r") or ""))
        r.bg:SetColorTexture(0.9, 0.28, 0.24, 0.18)
        r.click = function()
            selected = WorldMapFrame:GetMapID()
            search:SetText("")
            renderTree()
            renderList()
        end
    end
    if mode == "mat" and matTab == "gather" then
        local function sub(text, key, indent)
            n = n + 1
            local r = rowOf(tree, n)
            place(tree, r, n, indent)
            r.icon:SetTexture(nil)
            r.text:SetText((gatherExp == key and "|cffe6483d" or "|cffffffff") .. text .. "|r")
            r.bg:SetColorTexture(0.9, 0.28, 0.24, gatherExp == key and 0.15 or 0.06)
            r.click = function() gatherExp = key; search:SetText(""); renderTree(); renderList() end
        end
        local cur = WorldMapFrame:GetMapID()
        sub("Current zone" .. (cur and (": " .. SFP:ZoneName(cur)) or ""), "zone", 0)
        sub("All expansions", "all", 0)
        for _, exp in ipairs(SFP.Expansions) do sub(exp.name, exp.key, 12) end
        finish(tree, n)
        return
    end
    for _, exp in ipairs(SFP.Expansions) do
        local zoneList = zonesOf(exp)
        if monsterMode then
            local keep = {}
            for _, map in ipairs(zoneList) do
                if (#zq < 2 or SFP:ZoneName(map):lower():find(zq:lower(), 1, true)) and zoneHasMonsters(map, mode) then keep[#keep + 1] = map end
            end
            zoneList = keep
        end
        if #zoneList > 0 then
            n = n + 1
            local r = rowOf(tree, n)
            place(tree, r, n, 0)
            local open = not collapsed[exp.key] or #zq >= 2
            r.icon:SetTexture(nil)
            r.text:SetText("|cffffd100" .. (open and "[-] " or "[+] ") .. exp.name .. "|r")
            r.bg:SetColorTexture(1, 1, 1, 0.06)
            r.click = function() collapsed[exp.key] = open or nil; renderTree() end
            if open then
                for _, map in ipairs(zoneList) do
                    n = n + 1
                    local z = rowOf(tree, n)
                    place(tree, z, n, 12)
                    z.icon:SetTexture(nil)
                    z.text:SetText((selected == map and "|cffe6483d" or "|cffffffff") .. SFP:ZoneName(map) .. "|r")
                    if selected == map then z.bg:SetColorTexture(0.9, 0.28, 0.24, 0.15) end
                    z.click = function()
                        if mode == "top" then setMode("farm") end
                        selected = map
                        search:SetText("")
                        renderTree()
                        renderList()
                    end
                end
            end
        end
    end
    finish(tree, n)
end

renderTree = function()
    if mode == "mat" or mode == "farm" or mode == "rare" or mode == "top" then renderTreeMat() else renderModeTree() end
end

local function setTab(t)
    matTab = t
    search:SetText("")
    if win.tabs then
        win.tabs.monsters:SetEnabled(t ~= "monsters")
        win.tabs.gather:SetEnabled(t ~= "gather")
    end
    renderTree()
    renderList()
end

---------------------------------------------------------------------------
-- the window
---------------------------------------------------------------------------
local function scrollSide(parent, x, y, w)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", x, y)
    sf:SetPoint("BOTTOMLEFT", x, 8)
    sf:SetWidth(w)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(w, 1)
    sf:SetScrollChild(content)
    return { scroll = sf, content = content, rows = {} }
end

local function build()
    local sc = WorldMapFrame.ScrollContainer
    win = CreateFrame("Frame", "SeviathsUsefulToolsMaterialGuide", WorldMapFrame, "BackdropTemplate")
    win:SetFrameStrata("DIALOG")
    -- it is not movable. The map cannot be moved either, so the window uses the empty screen to the right of it, as tall as the map;
    -- when the map leaves no room there (a maximized map) it sits at the bottom right of the map instead
    local function fit()
        win:ClearAllPoints()
        local mr, ms = WorldMapFrame:GetRight(), WorldMapFrame:GetEffectiveScale()
        local ur, us = UIParent:GetRight(), UIParent:GetEffectiveScale()
        local ws = win:GetEffectiveScale()
        local space = (mr and ur and ws > 0) and ((ur * us - mr * ms) / ws) or 0
        if space >= 520 then
            win:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", 48, 0)   -- clear of the map's side tabs
            win:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMRIGHT", 48, 0)
            win:SetWidth(math.min(space - 52, 820))
        else
            win:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -8, 8)
            local w, h = sc:GetWidth(), sc:GetHeight()
            if w and w > 0 then win:SetSize(math.max(520, w * 0.46), math.max(360, h * 0.62)) end
        end
    end
    fit()
    win.fit = fit
    sc:HookScript("OnSizeChanged", fit)
    SFP.BlizzardFrame(win, true)
    win:SetBackdropColor(0.02, 0.03, 0.05, 0.96)
    win:SetBackdropBorderColor(0.9, 0.28, 0.24, 0.9)
    win:EnableMouse(true)
    win:Hide()

    win.header = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    win.header:SetPoint("TOPLEFT", 12, -10)
    win.header:SetText("|c" .. SFP.CYAN_HEX .. "Material search|r")

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    search = CreateFrame("EditBox", nil, win, "SearchBoxTemplate")
    search:SetSize(260, 22)
    search:SetPoint("TOPRIGHT", close, "TOPLEFT", -8, -5)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function(self)
        if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(self) end
        if mode == "farm" or mode == "rare" then renderTree() end
        renderList()
    end)

    win.title = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    win.title:SetPoint("TOPLEFT", TREE_W + 34, -40)

    tree = scrollSide(win, 10, -64, TREE_W)
    tree.scroll:ClearAllPoints()
    tree.scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -64)
    tree.scroll:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 10, 40)
    tree.scroll:SetWidth(TREE_W)
    -- Top 10 best spots: always at the bottom of the Farm spots / Rares window
    win.topBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    win.topBtn:SetSize(TREE_W, 26)
    win.topBtn:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 10, 8)
    win.topBtn:SetText("Top 15 best spots")
    win.topBtn:SetScript("OnClick", function()
        setMode("top")
        win.curBtn:Show()
        renderTree()
        renderList()
    end)
    win.topBtn:Hide()
    list = scrollSide(win, TREE_W + 34, -64, 10)
    list.scroll:ClearAllPoints()
    list.scroll:SetPoint("TOPLEFT", win, "TOPLEFT", TREE_W + 34, -64)
    list.scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -30, 40)
    -- the pages: Previous / Next under the list
    local pg = CreateFrame("Frame", nil, win)
    pg:SetHeight(26)
    pg:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", TREE_W + 34, 8)
    pg:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -30, 8)
    pg.prev = CreateFrame("Button", nil, pg, "UIPanelButtonTemplate")
    pg.prev:SetSize(90, 24)
    pg.prev:SetPoint("LEFT", 0, 0)
    pg.prev:SetText("Previous")
    pg.next = CreateFrame("Button", nil, pg, "UIPanelButtonTemplate")
    pg.next:SetSize(90, 24)
    pg.next:SetPoint("RIGHT", 0, 0)
    pg.next:SetText("Next")
    pg.text = pg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pg.text:SetPoint("CENTER")
    pg.prev:SetScript("OnClick", function() listPage = listPage - 1; win.refreshList() end)
    pg.next:SetScript("OnClick", function() listPage = listPage + 1; win.refreshList() end)
    win.pager = pg
    -- the mouse wheel turns the pages of the list
    list.scroll:EnableMouseWheel(true)
    list.scroll:SetScript("OnMouseWheel", function(_, delta)
        listPage = listPage - (delta > 0 and 1 or -1)
        win.refreshList()
    end)
    list.content:SetWidth(list.scroll:GetWidth())
    win:SetScript("OnSizeChanged", function()
        list.content:SetWidth(math.max(list.scroll:GetWidth(), 100))
    end)
    win.refreshList = renderList
    win.curBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    win.curBtn:SetSize(170, 24)
    win.curBtn:SetPoint("TOPLEFT", win, "TOPLEFT", 200, -8)
    win.curBtn:SetText("Show current zone")
    win.curBtn:SetScript("OnClick", function()
        selected = WorldMapFrame:GetMapID()
        search:SetText("")
        renderTree()
        renderList()
    end)
    win.curBtn:Hide()
    win.tabs = {}
    for k, def in ipairs({ { "monsters", "Monsters" }, { "gather", "Mining & Herbalism" } }) do
        local key, text = def[1], def[2]
        local tb = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        tb:SetSize(k == 1 and 90 or 150, 24)
        tb:SetPoint("TOPLEFT", win, "TOPLEFT", 200 + (k - 1) * 94, -8)
        tb:SetText(text)
        tb:SetScript("OnClick", function() setTab(key) end)
        win.tabs[key] = tb
    end
    win.tabs.monsters:SetEnabled(matTab ~= "monsters")
    win.tabs.gather:SetEnabled(matTab ~= "gather")
    win:SetScript("OnHide", function()
        -- everything built for the section that was open is let go
        guideIndex, monsterIndex, mapRecs, ownByMap, guideMapSet = {}, {}, {}, nil, nil
        if SFP.FreeMonsterCache then SFP:FreeMonsterCache() end
        entriesCache = nil
        zonesCache = {}
    end)
    win:SetScript("OnShow", function()
        fit()
        -- the icons of the crafting reagents are stored the first time the window opens (a few hundred a frame), not at login
        if not SFP._reagentIcons then
            SFP._reagentIcons = true
            local ids = {}
            for id, a2 in pairs(SFP.AuctionItems or {}) do if a2[1] == 7 then ids[#ids + 1] = id end end
            for id, info in pairs(SFP.Items or {}) do if info.kind and info.kind ~= "mount" then ids[#ids + 1] = id end end
            local i = 1
            local function step()
                local last = math.min(i + 300, #ids)
                for k = i, last do pcall(SFP.StoreIcon, SFP, ids[k]) end
                i = last + 1
                if i <= #ids then C_Timer.After(0, step) end
            end
            step()
        end
        list.content:SetWidth(math.max(list.scroll:GetWidth(), 100))
        if not selected then
            local m = WorldMapFrame:GetMapID()
            if m and (SFP.zoneByMap[m] or guideMaps()[m]) then selected = m end
        end
        renderTree()
        renderList()
    end)
end

---------------------------------------------------------------------------
-- The line of buttons below the world map, at the right: Farm spots, Collectables, Material search and, last, Mining & Herbalism. Each
-- is a button like "Material search"; the side lists open above their button, one at a time.
---------------------------------------------------------------------------
local row
local rowBtns = {}

local function openMode(m)
    if not win then build() end
    if win:IsShown() and mode == m then win:Hide() return end
    SFP.db.spotsCollapsed, SFP.db.gatherCollapsed, SFP.db.collCollapsed, SFP.db.raresCollapsed = true, true, true, true
    SFP.RefreshWorldMap()
    setMode(m)
    if m == "farm" or m == "rare" then selected = WorldMapFrame:GetMapID() end
    win:Show()
    renderTree()
    renderList()
end
-- Material search and Item search are the same window: only what is listed differs (crafting reagents, or every item)
local function setItemMode(on)
    if itemMode == on then return end
    itemMode = on
    guideIndex, monsterIndex = {}, {}   -- the lists were made for the other kind
    zonesCache = {}
    if matTab == "gather" then matTab = "monsters" end
end
local function openGuide()
    if win and win:IsShown() and mode == "mat" and itemMode then win:Hide() end
    setItemMode(false)
    openMode("mat")
end
local function openItems()
    if not win then build() end
    if win:IsShown() and mode == "mat" and itemMode then win:Hide() return end
    setItemMode(true)
    if win:IsShown() then win:Hide() end
    openMode("mat")
end
local function openGather()
    if not win then build() end
    if win:IsShown() and mode == "mat" and matTab == "gather" then win:Hide() return end
    SFP.db.spotsCollapsed, SFP.db.gatherCollapsed, SFP.db.collCollapsed, SFP.db.raresCollapsed = true, true, true, true
    SFP.RefreshWorldMap()
    setMode("mat")
    gatherExp = "zone"
    win:Show()
    setTab("gather")
end

-- which list a button opens: its collapsed flag in the saved settings (one open at a time)
local FLAGS = { spots = "spotsCollapsed", rares = "raresCollapsed", coll = "collCollapsed", gather = "gatherCollapsed" }
local function openOnly(key)
    if win and win:IsShown() then win:Hide() end
    local wasOpen = SFP.db[FLAGS[key]] == false
    for k, flag in pairs(FLAGS) do SFP.db[flag] = true end
    if not wasOpen then SFP.db[FLAGS[key]] = false end
    SFP.RefreshWorldMap()
end

local function makeButton(key, text, tip, onClick)
    local b = CreateFrame("Button", "SeviathsUsefulToolsRow" .. key, row, "UIPanelButtonTemplate")
    b:SetHeight(26)
    b:SetText(text)
    b:SetWidth(b:GetTextWidth() + 28)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        SFP.Tip():SetOwner(self, "ANCHOR_TOP")
        SFP.Tip():AddLine(text)
        SFP.Tip():AddLine(tip, 1, 1, 1, true)
        SFP.Tip():Show()
    end)
    b:SetScript("OnLeave", function() SFP.Tip():Hide() end)
    rowBtns[key] = b
    return b
end

local function refreshRow()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then if row then row:Hide() end return end
    if not row then
        row = CreateFrame("Frame", "SeviathsUsefulToolsButtonRow", WorldMapFrame)
        row:SetFrameStrata("HIGH")
        row:SetHeight(28)
        row:SetPoint("TOPRIGHT", WorldMapFrame, "BOTTOMRIGHT", -2, 2)
        makeButton("spots", "Farm spots", "The farm spots of this zone, with a checkbox each", function() openMode("farm") end)
        makeButton("coll", "Collectables", "Mounts of the dungeons and raids here, and the hunter pets of the zone", function() openOnly("coll") end)
        makeButton("rares", "Rares", "The rare monsters of this zone with a waypoint each", function() openMode("rare") end)
        makeButton("search", "Material search", "Every zone from Classic to Midnight: the crafting reagents you can farm there and which monsters drop them. Click a monster for a waypoint.", openGuide)
        makeButton("items", "Item search", "Every zone from Classic to Midnight: all the items the monsters there drop except the crafting reagents (those are in Material search) and which monsters drop them. Click a monster for a waypoint.", openItems)
        makeButton("mount", "Mount search", "Every mount with where to get it, Classic to Midnight. Click a source for a waypoint.", function() openMode("mount") end)
        makeButton("hunter", "Hunter search", "Every hunter pet (spirit beasts, unique looks and the tameable beasts seen so far) with a waypoint", function() openMode("hunter") end)
        makeButton("pet", "Battle pets", "Every battle pet with its auction price - search by name, or pick a family", function() openMode("pet") end)
    end
    local map = WorldMapFrame:GetMapID()
    local zone = map and SFP.zoneByMap[map]
    local hasFarm, hasRares = false, false
    if map and SFP.HasFarmLists then hasFarm, hasRares = SFP.HasFarmLists(map) end
    local show = {
        spots = true,   -- the window has its own zone list and search, so these two are always there
        rares = true,
        coll = false,   -- Collectables is covered by Mount search and Hunter search
        search = true,
        items = true,
        mount = true,
        hunter = true,
        pet = true,
    }
    local x = 0
    -- right to left: the last of the line is Mining & Herbalism
    for _, key in ipairs({ "pet", "hunter", "mount", "search", "coll", "rares", "items", "spots" }) do
        local b = rowBtns[key]
        b:ClearAllPoints()
        if show[key] then
            b:SetPoint("RIGHT", row, "RIGHT", -x, 0)
            x = x + b:GetWidth() + 4
            b:Show()
        else
            b:Hide()
        end
    end
    row:SetWidth(math.max(x, 10))
    row:Show()
    if SFP.DockPanels then SFP.DockPanels() end
end

-- a mount added to your collection: where you were is kept as its place (not when bought at the auction house, taken from the mail or traded)
do
    local mf = CreateFrame("Frame")
    mf:RegisterEvent("NEW_MOUNT_ADDED")
    mf:SetScript("OnEvent", function(_, _, mountID)
        pcall(function()
            if not (SFP.db and mountID and C_MountJournal and C_MountJournal.GetMountInfoByID) then return end
            local name = C_MountJournal.GetMountInfoByID(mountID)
            if type(name) ~= "string" or name == "" then return end
            -- the Mount search updates whatever way the mount came (instance, auction house, mail ...): the mount is collected now
            entriesCache = nil
            C_Timer.After(0.5, function()
                if win and win:IsShown() and mode == "mount" and win.refreshList then pcall(win.refreshList) end
            end)
            if IsInInstance and IsInInstance() then return end
            for _, fname in ipairs({ "AuctionHouseFrame", "AuctionFrame", "MailFrame", "TradeFrame" }) do
                local fr = _G[fname]
                if fr and fr.IsShown and fr:IsShown() then return end
            end
            local m = C_Map.GetBestMapForUnit("player")
            local pos = m and C_Map.GetPlayerMapPosition(m, "player")
            if not (m and pos) then return end
            local x, y = pos:GetXY()
            if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return end
            SFP.db.mountSpots = SFP.db.mountSpots or {}
            SFP.db.mountSpots[name] = { m = m, x = math.floor(x * 10000) / 10000, y = math.floor(y * 10000) / 10000 }
            entriesCache = nil
            if win and win:IsShown() and mode == "mount" and win.refreshList then win.refreshList() end
        end)
    end)
end

-- a pet added to your collection (caught, bought, looted, any way): everything about it is kept in db.petInfo - species, name, icon,
-- family, where the game says it comes from, whether it can battle or be traded - and, when it was found in the world (not bought at
-- the auction house, taken from the mail or traded for), where you were: that place is used first by the Battle pets list
do
    local pf = CreateFrame("Frame")
    pf:RegisterEvent("NEW_PET_ADDED")
    pf:SetScript("OnEvent", function(_, _, petGUID)
        pcall(function()
            if not (SFP.db and petGUID and C_PetJournal and C_PetJournal.GetPetInfoByPetID) then return end
            local species, customName = C_PetJournal.GetPetInfoByPetID(petGUID)
            if not species then return end
            local name, icon, petType, companionID, source, description, isWild, canBattle, tradeable, unique, obtainable =
                C_PetJournal.GetPetInfoBySpeciesID(species)
            if type(name) ~= "string" or name == "" then return end
            SFP.db.petInfo = SFP.db.petInfo or {}
            local info = SFP.db.petInfo[name] or {}
            info.species, info.icon, info.type, info.creature = species, icon, petType, companionID
            info.source, info.wild, info.battle, info.tradeable, info.unique = source, isWild, canBattle, tradeable, unique
            if type(customName) == "string" and customName ~= "" then info.custom = customName end   -- the name you gave it
            info.t = time()
            SFP.db.petInfo[name] = info
            if SFP.StoreIcon then SFP:StoreIcon(companionID) end
            -- the place: only where it was really found
            local found = true
            if IsInInstance and IsInInstance() then found = false end
            for _, fname in ipairs({ "AuctionHouseFrame", "AuctionFrame", "MailFrame", "TradeFrame" }) do
                local fr = _G[fname]
                if fr and fr.IsShown and fr:IsShown() then found = false end
            end
            if found then
                local m = C_Map.GetBestMapForUnit("player")
                local pos = m and C_Map.GetPlayerMapPosition(m, "player")
                if m and pos then
                    local x, y = pos:GetXY()
                    if not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then
                        SFP.db.petSpots = SFP.db.petSpots or {}
                        SFP.db.petSpots[name] = { m = m, x = math.floor(x * 10000) / 10000, y = math.floor(y * 10000) / 10000 }
                    end
                end
            end
            entriesCache = nil   -- the list is made again with what was learned
            if win and win:IsShown() and mode == "pet" and win.refreshList then win.refreshList() end
        end)
    end)
end

-- the rares the game shows on the map (the skull icons): name and place are kept in db.rareSeen, so a rare seen on any map is in the Rares
-- list with its place; its loot is matched by name from what the addon knows of it
do
    local lastRun = 0
    local function recordRares()
        if not (SFP.db and C_VignetteInfo and C_VignetteInfo.GetVignettes) then return end
        if GetTime() - lastRun < 3 then return end
        lastRun = GetTime()
        local mapID = (WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID()) or C_Map.GetBestMapForUnit("player")
        if not mapID then return end
        for _, guid in ipairs(C_VignetteInfo.GetVignettes() or {}) do
            local info = C_VignetteInfo.GetVignetteInfo(guid)
            local atlas = info and info.atlasName
            local nm = info and info.name
            if type(nm) == "string" and nm ~= "" and type(atlas) == "string"
                and not (issecretvalue and (issecretvalue(nm) or issecretvalue(atlas))) and atlas:lower():find("kill", 1, true) then
                local pos = C_VignetteInfo.GetVignettePosition(guid, mapID)
                if pos then
                    local x, y = pos:GetXY()
                    if x and y and not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then
                        SFP.db.rareSeen = SFP.db.rareSeen or {}
                        SFP.db.rareSeen[nm .. "@" .. mapID] = { n = nm, m = mapID, x = math.floor(x * 10000) / 10000, y = math.floor(y * 10000) / 10000, t = time() }
                    end
                end
            end
        end
    end
    local vf = CreateFrame("Frame")
    vf:RegisterEvent("VIGNETTES_UPDATED")
    vf:SetScript("OnEvent", function() pcall(recordRares) end)
    SFP:OnRefresh(function() pcall(recordRares) end)
end

local nameWait
local nameFrame = CreateFrame("Frame")
nameFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
nameFrame:SetScript("OnEvent", function(_, _, itemID)
    if itemID and SFP.StoreIcon then SFP:StoreIcon(itemID) end   -- a delivered item: its icon is kept too
    if nameWait or not (win and win:IsShown()) then return end
    nameWait = true
    C_Timer.After(0.5, function()
        nameWait = nil
        if win and win:IsShown() and win.refreshList then pcall(win.refreshList) end
    end)
end)

-- Material search, Item search, Rares and Farm spots update when you loot (a kill, a pickup): what the monsters of the zone drop is read again, a moment after the loot
-- window closes (the Collector records on LOOT_OPENED), at most every few seconds
local lootWait
local LOOT_LIST_MODES = { mat = true, rare = true, farm = true, top = true }   -- the lists a kill changes: materials and items, Rares, Farm spots
local lootFrame = CreateFrame("Frame")
lootFrame:RegisterEvent("LOOT_CLOSED")
lootFrame:SetScript("OnEvent", function()
    if lootWait then return end
    lootWait = true
    C_Timer.After(3, function()
        lootWait = nil
        -- the lists are made again from the new kill, also when the window is closed now (it is up to date the next time it opens)
        guideIndex, monsterIndex, mapRecs, ownByMap, guideMapSet = {}, {}, {}, nil, nil
        zonesCache = {}
        if SFP.FreeMonsterCache then SFP:FreeMonsterCache() end
        if not (win and win:IsShown() and LOOT_LIST_MODES[mode]) then return end
        if win.refreshList then pcall(win.refreshList) end
    end)
end)

SFP:OnLogin(function()
    -- once: the side lists start closed (they are opened with the buttons below the map); older saved settings had the Farm spots list open
    if SFP.db and not SFP.db.panelsClosedV2 then
        SFP.db.panelsClosedV2 = true
        SFP.db.spotsCollapsed, SFP.db.gatherCollapsed, SFP.db.collCollapsed, SFP.db.raresCollapsed = true, true, true, true
    end
    if not WorldMapFrame or not WorldMapFrame.ScrollContainer then return end
    WorldMapFrame:HookScript("OnHide", function()
        if win then win:Hide() end
        if row then row:Hide() end
    end)
    WorldMapFrame:HookScript("OnShow", function() pcall(refreshRow) end)
    SFP:OnRefresh(function() pcall(refreshRow) end)
end)
