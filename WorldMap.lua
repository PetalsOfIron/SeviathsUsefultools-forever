-- SeviathsUsefulTools - world map overlay
--
-- Zone map: every spawn point of the farm mobs is a soft cyan glow, so the
--   exact farm spots show up as small glowing cyan areas. Each mob gets its
--   name + coordinates at its busiest spot. Hover a glowing spot to see what
--   drops there and the AH value; Ctrl+Click (Blizzard's own) for a waypoint.
--   Spots never take the mouse, so clicking the map works as normal.
-- Continent map (e.g. Broken Isles): zoomed out = one spot per farm mob,
--   zoomed in = the real spawn areas with labels. Nothing covers the map.
-- The spot layer sits at a high frame level: the zone's explored-area art
--   (and other map addons) are drawn as pins above low levels and hid it.
-- Optional (off by default): whole-zone glow + item panel.

local _, SFP = ...

local overlay, spawnLayer, pool, labels, panel, edges, tip
local poolUsed, labelUsed = 0, 0
local pins, pinLabels = {}, {}
local pinUsed, pinLabelUsed = 0, 0
local lastHover
local GLOW = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function C() return SFP.CYAN end

local function sortedItems(list)
    local copy = {}
    for i, id in ipairs(list) do copy[i] = id end
    table.sort(copy, function(a, b)
        local pa, pb = SFP:GetPrice(a) or -1, SFP:GetPrice(b) or -1
        if pa ~= pb then return pa > pb end
        return a < b
    end)
    return copy
end

-- true when zoneID sits somewhere under mapID (continent -> zone)
local function isUnder(zoneID, mapID)
    local info = C_Map.GetMapInfo(zoneID)
    local p, guard = info and info.parentMapID, 0
    while p and guard < 4 do
        if p == mapID then return true end
        local pi = C_Map.GetMapInfo(p)
        p = pi and pi.parentMapID
        guard = guard + 1
    end
    return false
end

---------------------------------------------------------------------------
-- Spawn spots
---------------------------------------------------------------------------
local STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14|t"
SFP.STAR = STAR
-- hunter class crest: marks creatures hunters can tame (never the grind star)
local HUNTER_ICON = "|TInterface\\Icons\\ClassIcon_Hunter:14:14:0:0:64:64:5:59:5:59|t"
SFP.HUNTER_ICON = HUNTER_ICON
SFP.HUNTER_HEX = "ffabd473"
local HUNTER_TYPE = {
    spirit = "Spirit beast - only Beast Mastery hunters can tame it",
    unique = "Unique-looking pet - any hunter can tame it",
}
SFP.HUNTER_TYPE = HUNTER_TYPE
local COLLECTIBLE = { mount = true, pet = true, toy = true }

-- one loot line: item icon + name (+ drop chance) | source icon + price
local function lootLine(id, bestHere, spot)
    local name = SFP:ItemName(id)
    local info = SFP.Items[id]
    if spot and spot.learned and spot.counts and spot.kills and spot.kills > 0 then
        -- measured from your own kills
        local pct = 100 * (spot.counts[id] or 0) / spot.kills
        name = name .. string.format(" |cffffd100%s%%|r", pct >= 10 and string.format("%.0f", pct) or string.format("%.1f", pct))
    elseif info and info.drop then name = name .. " |cffffd100" .. info.drop .. "|r" end
    if bestHere then name = name .. " |cff40ff40(best spot)|r" end
    local right = SFP:FormatPrice(SFP:GetPrice(id))
    if info and COLLECTIBLE[info.kind] and not SFP:GetPrice(id) then
        right = "|cffa335ee" .. (SFP.KindLabel[info.kind] or "collectible") .. "|r"
    end
    right = SFP:KindIconTag(info and info.kind) .. " " .. right
    tip:AddDoubleLine("|T" .. SFP:ItemIcon(id) .. ":14|t " .. name, right, 1, 1, 1, 1, 1, 1)
end
SFP.MapLootLine = lootLine

local function showInstanceTip(h)
    tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0)
    tip:ClearLines()
    for i, inst in ipairs(h.instances) do
        if i > 1 then tip:AddLine(" ") end
        local raid = inst.kind == "raid"
        tip:AddLine("|T" .. (raid and SFP.RAID_ICON or SFP.DUNGEON_ICON) .. ":16|t " .. inst.name ..
            "  |cffaaaaaa" .. (raid and "Raid" or "Dungeon") .. "|r", 1, 0.5, 0)
        -- mounts first, then sellable BoEs (best price first), then materials
        local mounts, boes, mats, maybe = {}, {}, {}, {}
        for _, id in ipairs(sortedItems(inst.items)) do
            local k = SFP.Items[id] and SFP.Items[id].kind
            if SFP.Items[id] and SFP.Items[id].unconfirmed then
                if SFP.db.showUnconfirmed then maybe[#maybe + 1] = id end
            elseif k == "mount" or k == "pet" or k == "toy" then mounts[#mounts + 1] = id
            elseif k == "boe" then boes[#boes + 1] = id
            else mats[#mats + 1] = id end
        end
        if #mounts > 0 then
            tip:AddLine("Mounts", 0.64, 0.21, 0.93)
            for _, id in ipairs(mounts) do lootLine(id) end
        end
        if #boes > 0 then
            tip:AddLine("BoE gear - sell on the auction house", 0.12, 1, 0)
            for i, id in ipairs(boes) do
                if i > 8 then tip:AddLine("  +" .. (#boes - 8) .. " more BoEs - see the farm browser", 0.6, 0.6, 0.6); break end
                lootLine(id)
            end
        end
        if #mats > 0 then
            tip:AddLine("Materials", 0.6, 0.6, 0.6)
            for _, id in ipairs(mats) do lootLine(id) end
        end
        if inst.note then tip:AddLine(inst.note, 0.8, 0.8, 0.8, true) end
        if #maybe > 0 then
            tip:AddLine("Possible BoEs - unconfirmed, may have been changed", 0.6, 0.6, 0.6)
            for _, id in ipairs(maybe) do
                local price = SFP:GetPrice(id)
                tip:AddDoubleLine("|T" .. SFP:ItemIcon(id) .. ":14|t |cff9d9d9d" .. SFP:ItemName(id):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r",
                    price and SFP:FormatPrice(price) or "|cff808080?|r", 1, 1, 1, 1, 1, 1)
            end
        end

    end
    tip:AddLine(string.format("Entrance  %.1f, %.1f", h.zx * 100, h.zy * 100), 1, 0.82, 0)
    local anyDrop = false
    for _, inst in ipairs(h.instances) do
        for _, id in ipairs(inst.items) do if SFP.Items[id] and SFP.Items[id].drop then anyDrop = true end end
    end
    if anyDrop then tip:AddLine("Drop chances are rough community estimates", 0.5, 0.5, 0.5) end
    tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
    tip:Show()
end

local function showGatherTip(h)
    local s = h.spawn
    local id = s.items[1]
    local ore = s.gather == "ore"
    tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0)
    tip:ClearLines()
    if h.continent then tip:AddLine(SFP:ZoneName(h.zoneID), 1, 1, 1) end
    local c = ore and { r = 1, g = 0.75, b = 0.45 } or { r = 0.35, g = 1, b = 0.6 }
    tip:AddLine(SFP:KindIconTag(s.gather, 16) .. " " .. s.name .. "  |cffaaaaaa" .. (ore and "Mining" or "Herbalism") .. "|r", c.r, c.g, c.b)
    tip:AddLine(string.format("%.1f, %.1f", h.zx * 100, h.zy * 100), 1, 0.82, 0)
    tip:AddLine("|cff40ff40Best zone for " .. SFP:ItemName(id) .. "|r", 1, 1, 1)
    tip:AddLine((s.nodes or "?") .. " recorded nodes in " .. SFP:ZoneName(h.zoneID) .. " - more than any other zone", 0.8, 0.8, 0.8, true)
    tip:AddLine("Gathered", 0.6, 0.6, 0.6)
    lootLine(id)
    if not SFP:GetPrice(id) then tip:AddLine("Prices appear after you open the auction house once", 0.5, 0.5, 0.5) end
    tip:AddLine("Glow = where the nodes spawn (sample of the node positions)", 0.6, 0.6, 0.6, true)
    tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
    tip:Show()
end

local function showClusterTip(h)
    local c = h.cluster
    tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0)
    tip:ClearLines()
    if h.continent then tip:AddLine(SFP:ZoneName(h.zoneID), 1, 1, 1) end
    tip:AddLine(SFP:KindIconTag("ore", 16) .. SFP:KindIconTag("herb", 16) .. " Gathering around here", 1, 0.82, 0.5)
    tip:AddLine(string.format("approx. %.0f, %.0f", h.zx * 100, h.zy * 100), 1, 0.82, 0)
    local ids = {}
    for id in pairs(c.items) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b)
        local ka, kb = SFP.Items[a].kind, SFP.Items[b].kind
        if ka ~= kb then return ka == "ore" end
        return c.items[a] > c.items[b]
    end)
    for _, id in ipairs(ids) do
        local info = SFP.Items[id]
        local price = SFP:GetPrice(id)
        tip:AddDoubleLine(SFP:KindIconTag(info.kind) .. " |T" .. SFP:ItemIcon(id) .. ":14|t " .. SFP:ItemName(id),
            (price and SFP:FormatPrice(price) or "") , 1, 1, 1, 1, 1, 1)
    end
    tip:AddLine("|cff40ff40" .. SFP:ZoneName(h.zoneID) .. " is the best zone for all of these|r", 1, 1, 1, true)
    tip:AddLine("Nodes spawn in the area around this symbol", 0.6, 0.6, 0.6, true)
    tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
    tip:Show()
end

-- several mobs share one marker: list each with what it drops
local function showMultiTip(h)
    tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0)
    tip:ClearLines()
    if h.continent then tip:AddLine(SFP:ZoneName(h.zoneID), 1, 1, 1) end
    tip:AddLine(#h.spawns .. " farm spots in this " .. (h.zonewide and "zone - zoom in to see where" or "area"), 0.6, 0.6, 0.6)
    tip:AddLine(string.format("approx. %.1f, %.1f", h.zx * 100, h.zy * 100), 1, 0.82, 0)
    for i, s in ipairs(h.spawns) do
        if i > 6 then tip:AddLine("+" .. (#h.spawns - 6) .. " more - zoom in to see them", 0.6, 0.6, 0.6); break end
        local col = s.hunter and { 0.67, 0.83, 0.45 } or s.rare and { 1, 0.6, 0.2 } or s.special and { 1, 0.3, 0.85 } or { 0.9, 0.28, 0.24 }
        local title = s.name
        if s.hunter then title = SFP.HUNTER_ICON .. " " .. title .. "  |c" .. SFP.HUNTER_HEX .. "(Hunter tame)|r" end
        if s.rare then title = title .. "  |cffff8000(Rare)|r" end
        if s.grind then title = STAR .. " " .. title end
        tip:AddLine(" ")
        tip:AddLine(title, col[1], col[2], col[3])
        if s.hunter then
            tip:AddLine(SFP.HUNTER_TYPE[s.hunter] or "Hunter tame", 0.8, 0.8, 0.8, true)
        else
            local best = {}
            for _, id in ipairs(s.bestFor or {}) do best[id] = true end
            if s.learned then tip:AddLine("learned from your loot", 1, 0.55, 0.5) end
            for _, id in ipairs(sortedItems(s.items)) do lootLine(id, best[id], s) end
        end
    end
    local zone = SFP.zoneByMap[h.zoneID]
    if zone and not zone.rareOnly then
        tip:AddLine(" ")
        local boeText, boeWhere = SFP:RandomBoeText(h.zoneID)
        tip:AddDoubleLine(boeText, boeWhere, 1, 1, 1, 0.7, 0.7, 0.7)
    end
    tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
    tip:Show()
end

local function showSpotTip(h, owner)
    if h.cluster then return showClusterTip(h) end
    if h.spawns and #h.spawns > 1 then return showMultiTip(h) end
    if h.instances then return showInstanceTip(h) end
    if h.spawn.gather then return showGatherTip(h) end
    local s = h.spawn
    if owner then tip:SetOwner(owner, "ANCHOR_RIGHT") else tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0) end
    tip:ClearLines()
    if h.continent then tip:AddLine(SFP:ZoneName(h.zoneID), 1, 1, 1) end
    local col = s.hunter and { r = 0.67, g = 0.83, b = 0.45 } or s.rare and { r = 1, g = 0.6, b = 0.2 }
        or s.special and { r = 1, g = 0.3, b = 0.85 } or C()
    local title = s.name
    if s.rare then title = title .. "  |cffff8000(Rare)|r" end
    if s.hunter then title = HUNTER_ICON .. " " .. title .. "  |c" .. SFP.HUNTER_HEX .. "(Hunter tame)|r" end
    if s.grind then title = STAR .. " " .. title end
    tip:AddLine(title, col.r, col.g, col.b)
    tip:AddLine(string.format("%.1f, %.1f", h.zx * 100, h.zy * 100), 1, 0.82, 0)
    if s.grind then tip:AddLine(STAR .. " worth grinding", 1, 0.82, 0) end
    if s.special and not s.rare then tip:AddLine("|cffff4dd9Special material spot|r", 1, 1, 1) end
    if s.hunter then
        tip:AddLine(HUNTER_ICON .. " " .. (HUNTER_TYPE[s.hunter] or "Hunter tame"), 0.67, 0.83, 0.45, true)
    end
    if s.note and s.note ~= "" then
        if s.hunter then tip:AddLine("How to tame:", 0.6, 0.6, 0.6) end
        tip:AddLine(s.note, 0.8, 0.8, 0.8, true)
    end

    local best = {}
    for _, id in ipairs(s.bestFor or {}) do best[id] = true end
    local function line(id) lootLine(id, best[id], s) end
    if s.learned then
        tip:AddLine("Learned from your own loot", 1, 0.55, 0.5, true)
    end
    if s.bestFor and not s.rare then
        local names = {}
        for i, id in ipairs(s.bestFor) do names[i] = SFP:ItemName(id) end
        tip:AddLine("|cff40ff40Best spot for " .. table.concat(names, ", ") .. "|r", 1, 1, 1, true)
    end

    if s.hunter then
        tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
        tip:Show()
        return
    end

    -- what this mob / rare drops
    local shown = {}
    if #s.items > 0 then
        tip:AddLine(s.rare and "Collectibles it can drop (not all of its loot)" or "Farmed here", 0.6, 0.6, 0.6)
        for _, id in ipairs(sortedItems(s.items)) do line(id); shown[id] = true end
    end
    -- everything the addon has recorded from its kills (gold too), greys included
    if SFP.AddSpotDrops and not s.gather then
        tip:AddLine(" ")
        SFP.AddSpotDrops(tip, s)
    end

    -- everything else worth farming in this zone (other mobs, zone-wide drops, etc.)
    local zone = SFP.zoneByMap[h.zoneID]
    local rest = {}
    local function mobLoot(id) -- ores, herbs and enchanting mats live in the gathering list, not on mob spots
        local info = SFP.Items[id]
        return not (info and (info.kind == "ore" or info.kind == "herb" or info.kind == "enchant"))
    end
    for _, id in ipairs(zone and zone.items or {}) do
        if not shown[id] and mobLoot(id) then rest[#rest + 1] = id; shown[id] = true end
    end
    local exp = SFP.zoneExp[h.zoneID]
    for _, id in ipairs(exp and exp.anywhere or {}) do
        if not shown[id] and mobLoot(id) then rest[#rest + 1] = id; shown[id] = true end
    end
    if #rest > 0 then
        tip:AddLine("Also in " .. SFP:ZoneName(h.zoneID), 0.6, 0.6, 0.6)
        for _, id in ipairs(sortedItems(rest)) do line(id) end
    end

    if zone and not zone.rareOnly then
        local boeText, boeWhere = SFP:RandomBoeText(h.zoneID)
        tip:AddDoubleLine(boeText, boeWhere, 1, 1, 1, 0.7, 0.7, 0.7)
    end
    local hows, seenHow = {}, {}
    for _, id in ipairs(s.items) do
        local info = SFP.Items[id]
        local how = info and SFP.KindHow[info.kind]
        if how and not seenHow[how] then seenHow[how] = true; hows[#hows + 1] = SFP:KindIconTag(info.kind) .. " " .. how end
    end
    if #hows > 0 then tip:AddLine("Source: " .. table.concat(hows, ",  "), 0.7, 0.7, 0.7, true) end
    local hasPrice = false
    for id in pairs(shown) do if SFP:GetPrice(id) then hasPrice = true; break end end
    if not hasPrice then
        tip:AddLine("Prices appear after you open the auction house once", 0.5, 0.5, 0.5)
    end
    if s.rare then tip:AddLine("Rare spawn - respawn timer varies", 0.6, 0.6, 0.6) end
    tip:AddLine("Ctrl+Click on the map: waypoint here", 0.6, 0.6, 0.6)
    tip:Show()
end

-- the tooltip of a spot as the map shows it, on any frame (the rows of the Rares list use it)
function SFP.ShowSpotTip(owner, s, mapID)
    if not (tip and s) then return end
    showSpotTip({ spawn = s, zoneID = mapID, zx = s.hx or 0, zy = s.hy or 0 }, owner)
end
function SFP.HideSpotTip()
    if tip then tip:Hide() end
end

local hoverList = {}   -- spots on the current map, for hover detection

local function getPin()
    pinUsed = pinUsed + 1
    local p = pins[pinUsed]
    if not p then
        p = CreateFrame("Frame", nil, spawnLayer)
        p:EnableMouse(false) -- never steal clicks: the map still opens zones normally
        p.outer = p:CreateTexture(nil, "BACKGROUND")
        p.outer:SetTexture(GLOW)
        -- normal blending: overlapping markers must not add up to a white-hot blob
        p.outer:SetBlendMode("BLEND")
        p.outer:SetPoint("CENTER")
        p.inner = p:CreateTexture(nil, "ARTWORK")
        p.inner:SetTexture(GLOW)
        p.inner:SetBlendMode("BLEND")
        p.inner:SetPoint("CENTER")
        pins[pinUsed] = p
    end
    if p.icon then p.icon:Hide() end
    if p.icon2 then p.icon2:Hide() end
    if p.pinTex then p.pinTex:Hide() end
    if p.ring then p.ring:Hide(); p.ringAg:Stop() end
    p.outer:Show(); p.inner:Show()
    p:Show()
    return p
end

local function getPinLabel()
    pinLabelUsed = pinLabelUsed + 1
    local fs = pinLabels[pinLabelUsed]
    if not fs then
        fs = spawnLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetFont(fs:GetFont(), 12, "OUTLINE")
        fs:SetJustifyH("CENTER")
        pinLabels[pinLabelUsed] = fs
    end
    fs:ClearAllPoints()
    fs:Show()
    return fs
end

local function clearSpawns()
    for i = 1, #pins do pins[i]:Hide() end
    for i = 1, #pinLabels do pinLabels[i]:Hide() end
    pinUsed, pinLabelUsed = 0, 0
    wipe(hoverList)
end

local function canvasScale()
    local sc = WorldMapFrame.ScrollContainer
    return (sc.GetCanvasScale and sc:GetCanvasScale()) or 1
end

local RARE = { r = 1.0, g = 0.5, b = 0.0 }
local HUNTER = { r = 0.55, g = 0.85, b = 0.25 }
local ORE  = { r = 1.0, g = 0.7, b = 0.35 }
local SPECIAL = { r = 1.0, g = 0.25, b = 0.85 }
local HERB = { r = 0.3, g = 1.0, b = 0.55 }
local function spotColor(sp)
    if sp.gather then return sp.gather == "ore" and ORE or HERB end
    return sp.hunter and HUNTER or sp.rare and RARE or sp.special and SPECIAL or C()
end
-- one id per farm spot, for the "switched off" list (survives reloads)
local function spotKey(sp)
    local k = sp._key
    if not k then
        k = sp.gather and ("g" .. tostring(sp.items and sp.items[1])) or ("n|" .. tostring(sp.name))   -- by name: the same monster listed twice is one spot
        sp._key = k
    end
    return k
end
SFP.SpotKey = spotKey
SFP.hiddenVer = 0   -- changes whenever a spot is switched on or off (drawing caches include it)

-- farm monsters: only the 5 best of each zone, by auction house prices. The choice is saved and kept until the weekly
-- reset (it changes once a week, not at every login or scan; only a choice made before any price was known is redone
-- when the first prices arrive). Ties use fixed data.
local BEST_PER_ZONE = 5
local BEST_KEEP = 7 * 24 * 3600
local function markBest()
    SFP._bestDone = true
    local saved = SFP.db.bestSpots
    -- kept until the weekly reset (the choice made since the last reset stays); without the game's reset timer: 7 days
    local lastReset = time() - BEST_KEEP
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local okR, secs = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if okR and type(secs) == "number" and secs > 0 and secs <= BEST_KEEP then lastReset = time() + secs - BEST_KEEP end
    end
    local keep = saved and saved.stamp and saved.zones and saved.stamp >= lastReset
    local newSaved = keep and saved or { stamp = time(), zones = {}, priced = false }
    for mapID, zone in pairs(SFP.zoneByMap or {}) do
        local farm = {}
        for _, s in ipairs(zone.spawns or {}) do
            if not (s.gather or s.rare or s.special or s.hunter) then
                s._best = false
                if not s.learned then farm[#farm + 1] = s end
            end
        end
        local chosen = keep and saved.zones[mapID]
        if chosen then
            for _, s in ipairs(farm) do if chosen[tostring(s.name)] then s._best = true end end
        else
            -- worth = what the monster's items sell for on the auction house (the saved prices)
            local function worth(s)
                local v = 0
                for _, id in ipairs(s.items or {}) do
                    local ok, p = pcall(SFP.GetPrice, SFP, id)   -- a price lookup that fails must never stop the map from drawing
                    if ok and type(p) == "number" then v = v + p end
                end
                if v > 0 then newSaved.priced = true end
                return v
            end
            local function fixed(s)
                return (s.bestFor and #s.bestFor or 0) * 1000 + (s.grind and 500 or 0) + #(s.items or {}) * 10 + math.min(#(s.points or {}), 9)
            end
            local w, f = {}, {}
            for _, s in ipairs(farm) do w[s], f[s] = worth(s), fixed(s) end
            table.sort(farm, function(a, b)
                if w[a] ~= w[b] then return w[a] > w[b] end
                if f[a] ~= f[b] then return f[a] > f[b] end
                return tostring(a.name) < tostring(b.name)
            end)
            local names = {}
            for i = 1, math.min(BEST_PER_ZONE, #farm) do
                farm[i]._best = true
                names[tostring(farm[i].name)] = true
            end
            newSaved.zones[mapID] = names
        end
    end
    SFP.db.bestSpots = newSaved
end

local function showSpot(sp)
    local hid = SFP.db.hiddenSpots
    if hid and hid[spotKey(sp)] then return false end
    if not (sp.gather or sp.rare or sp.special or sp.hunter) then
        if not SFP._bestDone then markBest() end
        if sp._best == false then return false end
    end
    if sp.gather then return sp.gather == "ore" and SFP.db.showMining or sp.gather == "herb" and SFP.db.showHerbs or false end
    if sp.hunter then return SFP.db.showHunter end
    if sp.rare then return SFP.db.showRares end
    if sp.special then return SFP.db.showSpecial end
    return SFP.db.showSpawns
end

SFP.ShowSpot, SFP.SpotColor = showSpot, spotColor

-- a farm spot is a normal map pin at its place (no cyan circle); when the map opens on a zone the pins ping for a few seconds, then stay still
local function placeFarmPin(p, x, y, h)
    local w, hh = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    local size = math.max(18 / canvasScale(), 10)
    p:SetSize(size, size)
    p.outer:Hide(); p.inner:Hide()
    if not p.pinTex then
        p.pinTex = p:CreateTexture(nil, "OVERLAY")
        p.pinTex:SetAtlas("Waypoint-MapPin-Untracked")
        p.pinTex:SetVertexColor(1, 0.5, 0.45, 1)
        p.ring = p:CreateTexture(nil, "ARTWORK")
        p.ring:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
        p.ring:SetBlendMode("BLEND")
        p.ring:SetVertexColor(0.1, 0.55, 1, 0.9)
        p.ring:SetPoint("CENTER", p, "CENTER", 0, 0)
        p.ringAg = p.ring:CreateAnimationGroup()
        local sc = p.ringAg:CreateAnimation("Scale")
        sc:SetScaleFrom(0.5, 0.5); sc:SetScaleTo(2.6, 2.6); sc:SetDuration(0.8)
        local al = p.ringAg:CreateAnimation("Alpha")
        al:SetFromAlpha(0.95); al:SetToAlpha(0.1); al:SetDuration(0.8)
        p.ringAg:SetScript("OnFinished", function()
            if GetTime() < (p.pingUntil or 0) then p.ringAg:Play() else p.ring:Hide() end
        end)
    end
    p.pinTex:ClearAllPoints()
    p.pinTex:SetSize(size, size)
    p.pinTex:SetPoint("BOTTOM", p, "CENTER", 0, 0)
    p.pinTex:Show()
    p.ring:SetSize(size * 1.6, size * 1.6)
    if GetTime() < (SFP._pingUntil or 0) then
        p.pingUntil = SFP._pingUntil
        p.ring:Show()
        if not p.ringAg:IsPlaying() then p.ringAg:Play() end
    else
        p.ring:Hide()
    end
    p:ClearAllPoints()
    p:SetPoint("CENTER", spawnLayer, "TOPLEFT", x * w, -y * hh)
    h.mx, h.my = x, y
    hoverList[#hoverList + 1] = h
end

local function placePin(p, x, y, outer, outerAlpha, inner, h)
    local s0 = h.spawn
    -- farm spots and special materials
    if s0 and not (s0.rare or s0.hunter or s0.gather) then return placeFarmPin(p, x, y, h) end
    local c = spotColor(h.spawn)
    local w, hh = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    local minPx = 7 / canvasScale() -- never smaller than ~7 screen pixels
    outer, inner = math.max(outer, minPx * 2), math.max(inner, minPx * 0.6)
    p:SetSize(outer, outer)
    p.outer:SetSize(outer, outer)
    -- soft, pale markers: they should hint at a spot, not shout over the map
    local s = h.spawn
    local r, g, b = c.r, c.g, c.b
    if not (s.rare or s.special or s.hunter or s.gather) then r, g, b = r * 0.65 + 0.3, g * 0.65 + 0.3, b * 0.65 + 0.3 end
    p.outer:SetVertexColor(r, g, b, outerAlpha * 0.5)
    p.inner:SetSize(inner, inner)
    p.inner:SetVertexColor(r, g, b, 0.6)
    p:ClearAllPoints()
    p:SetPoint("CENTER", spawnLayer, "TOPLEFT", x * w, -y * hh)
    h.mx, h.my = x, y
    hoverList[#hoverList + 1] = h
end

local function label(x, y, text, lift, shift)
    local w, h = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    local fs = getPinLabel()
    fs:SetFont(fs:GetFont(), math.max(9, 12 / canvasScale()), "OUTLINE")
    fs:SetPoint("BOTTOM", spawnLayer, "TOPLEFT", x * w, -y * h + lift - shift * (28 / canvasScale()))
    fs:SetText(text)
end

local function spotText(s, px, py, more)
    -- BoE farm mobs get a purple "BoE" tag so they stand out on the map
    local tag, hex = "", SFP.CYAN_HEX
    if s.rare then tag, hex = " |cffff8000[Rare]|r", "ffff9933"
        if SFP.db.greyKilled ~= false and s.npc and s.npc > 0 and SFP.RareKilledToday and SFP:RareKilledToday(s.npc) then tag = tag .. " |cff808080[killed today]|r" end
    elseif s.special then tag, hex = " |cffff4dd9[Special]|r", "ffff66e0" end
    if s.gather then
        local hx2 = s.gather == "ore" and "ffffb366" or "ff4dff8c"
        return string.format("%s |c%s%s|r\n|cff40ff40Best zone: %s|r\n|cffffd100%.1f, %.1f|r",
            SFP:KindIconTag(s.gather, 14), hx2, s.name, SFP:ItemName(s.items[1]), (px or s.hx) * 100, (py or s.hy) * 100)
    end
    if s.hunter then
        return string.format("%s |c%s%s|r |c%s[Hunter]|r\n|cffffd100%.1f, %.1f|r",
            HUNTER_ICON, SFP.HUNTER_HEX, s.name, SFP.HUNTER_HEX, (px or s.hx) * 100, (py or s.hy) * 100)
    end
    local star = s.grind and (STAR .. " ") or ""
    for _, id in ipairs(s.items) do
        local info = SFP.Items[id]
        if info and info.kind == "boe" then tag = tag .. " |cffa335ee[BoE]|r"; break end
        if info and info.kind == "mount" then tag = tag .. " |cffffd100[Mount]|r"; break end
        if info and (info.kind == "pet" or info.kind == "toy") then tag = tag .. " |cffffd100[" .. SFP.KindLabel[info.kind] .. "]|r"; break end
    end
    local bestLine = ""
    if s.bestFor and not s.rare then
        local names = {}
        for i, id in ipairs(s.bestFor) do
            local info = SFP.Items[id]
            names[i] = SFP:KindIconTag(info and info.kind, 12) .. SFP:ItemName(id)
        end
        bestLine = "\n|cff40ff40Best spot: " .. table.concat(names, ", ") .. "|r"
    end
    return string.format("%s|c%s%s|r%s%s%s\n|cffffd100%.1f, %.1f|r", star, hex, s.name, tag, more or "", bestLine, (px or s.hx) * 100, (py or s.hy) * 100)
end

-- draw all spawn points of a zone's farm mobs, mapped into the viewed map
-- (rect = zone position on that map; nil when viewing the zone itself)
-- Spawn points are grouped into areas: one small marker per area instead of a
-- glow per spawn point. Mobs of the same kind (farm / rare / special / hunter)
-- whose areas overlap share one marker; hover it to see all of them.
local AREA_R = 0.07
local function spotCat(s)
    return s.hunter and "hunter" or s.rare and "rare" or s.special and "special" or "farm"
end
local function spawnClusters(zone)
    local exact = SFP.db.exactSpots
    local key = (SFP.db.showSpawns and "f" or "") .. (SFP.db.showRares and "r" or "") ..
        (SFP.db.showSpecial and "s" or "") .. (SFP.db.showHunter and "h" or "") .. (exact and "x" or "") .. SFP.hiddenVer
    local radius = exact and 0.0035 or AREA_R
    zone._areas = zone._areas or {}
    if zone._areas[key] then return zone._areas[key] end
    local list = {}
    local buckets = {}
    local seenRare = {}
    for _, s in ipairs(zone.spawns or {}) do
        -- the same rare listed twice (several sources) is drawn once
        local rk = s.rare and ((s.npc and s.npc > 0 and s.npc) or s.name)
        if rk and seenRare[rk] then rk = "dup" elseif rk then seenRare[rk] = true end
        if not s.gather and rk ~= "dup" and showSpot(s) then
            local cat = spotCat(s)
            local pts = s.points
            if s.rare and #pts > 1 then
                -- one approximate marker (and one star) per rare, not one per spawn point
                local sx, sy = 0, 0
                for _, pt in ipairs(pts) do sx, sy = sx + pt[1], sy + pt[2] end
                pts = { { sx / #pts, sy / #pts } }
            end
            if s.rare then
                -- rares: one small marker (and star) each; rares standing right next to each other share it
                for _, pt in ipairs(pts) do
                    local best, bd
                    for _, c in ipairs(list) do
                        if c.cat == "rare" then
                            local dx, dy = c.x - pt[1], c.y - pt[2]
                            local d = dx * dx + dy * dy
                            if d < 0.02 * 0.02 and (not bd or d < bd) then best, bd = c, d end
                        end
                    end
                    if not best then
                        best = { x = pt[1], y = pt[2], n = 0, cat = "rare", count = {}, order = {} }
                        list[#list + 1] = best
                    end
                    best.x = (best.x * best.n + pt[1]) / (best.n + 1)
                    best.y = (best.y * best.n + pt[2]) / (best.n + 1)
                    best.n = best.n + 1
                    if not best.count[s] then best.order[#best.order + 1] = s end
                    best.count[s] = (best.count[s] or 0) + 1
                end
            else
                local b = buckets[cat]
                if not b then b = {}; buckets[cat] = b end
                for _, pt in ipairs(s.points) do b[#b + 1] = { x = pt[1], y = pt[2], s = s } end
            end
        end
    end
    -- farm / special / hunter spots: every separate spot area becomes ONE big circle that covers it
    local CELL, LINK = 0.02, 0.04
    local function cellKey(cx, cy) return (cx + 100) * 1000 + (cy + 100) end
    for cat, items in pairs(buckets) do
        local grid = {}
        for _, it in ipairs(items) do
            local cx, cy = math.floor(it.x / CELL), math.floor(it.y / CELL)
            local k = cellKey(cx, cy)
            local c = grid[k]
            if not c then c = { cx = cx, cy = cy, pts = {} }; grid[k] = c end
            c.pts[#c.pts + 1] = it
        end
        local reach = math.ceil(LINK / CELL)
        local groups = {}
        for _, c0 in pairs(grid) do
            if not c0.seen then
                c0.seen = true
                local g, stack = {}, { c0 }
                while #stack > 0 do
                    local cur = table.remove(stack)
                    for _, it in ipairs(cur.pts) do g[#g + 1] = it end
                    for dx = -reach, reach do
                        for dy = -reach, reach do
                            local nb = grid[cellKey(cur.cx + dx, cur.cy + dy)]
                            if nb and not nb.seen then nb.seen = true; stack[#stack + 1] = nb end
                        end
                    end
                end
                groups[#groups + 1] = g
            end
        end
        -- the circle of one spot: centred on its spawn points, as big as the area that holds most of them
        local function circle(g)
            -- a monster that spawns all over the zone: the circle sits on its busiest place, not on the average of everything
            if #g > 2 then
                local bestN, bestI = 0, 1
                for i, a in ipairs(g) do
                    local n = 0
                    for _, b in ipairs(g) do
                        if (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 < 0.05 ^ 2 then n = n + 1 end
                    end
                    if n > bestN then bestN, bestI = n, i end
                end
                local a, near = g[bestI], {}
                for _, b in ipairs(g) do
                    if (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 < 0.05 ^ 2 then near[#near + 1] = b end
                end
                g = near
            end
            local sx, sy = 0, 0
            for _, it in ipairs(g) do sx, sy = sx + it.x, sy + it.y end
            local cx, cy = sx / #g, sy / #g
            local c = { x = cx, y = cy, n = #g, cat = cat, count = {}, order = {}, rad = 0 }
            local dist = {}
            for _, it in ipairs(g) do
                dist[#dist + 1] = math.sqrt((it.x - cx) ^ 2 + (it.y - cy) ^ 2)
                if not c.count[it.s] then c.order[#c.order + 1] = it.s end
                c.count[it.s] = (c.count[it.s] or 0) + 1
            end
            table.sort(dist)
            c.rad = dist[math.max(1, math.ceil(#dist * 0.85))] or 0
            return c
        end
        -- one circle per spot (monster): exactly where it is, hovering it shows only that spot
        local bySpot, spotOrder = {}, {}
        for _, it in ipairs(items) do
            if not bySpot[it.s] then bySpot[it.s] = {}; spotOrder[#spotOrder + 1] = it.s end
            table.insert(bySpot[it.s], it)
        end
        for _, s in ipairs(spotOrder) do
            local c = circle(bySpot[s])
            c.rad = math.min(math.max(c.rad * 0.9, 0.015), 0.04)   -- small, a little smaller than the spot's own area
            table.insert(list, 1, c)   -- circles first, so rares and stars stay on top
        end
    end
    for _, c in ipairs(list) do
        table.sort(c.order, function(a, b) return c.count[a] > c.count[b] end)
    end
    zone._areas[key] = list
    return list
end

SFP.SpotClusters = spawnClusters   -- the minimap draws the same circles

-- after an update every farm spot starts unticked in the spot list; the player ticks each one by choice
SFP:OnLogin(function()
    C_Timer.After(4, function()
        if not (SFP.db and SFP.db.hideSpotsPending) then return end
        SFP.db.hideSpotsPending = nil
        SFP.db.hiddenSpots = SFP.db.hiddenSpots or {}
        for _, zone in pairs(SFP.zoneByMap or {}) do
            for _, s in ipairs(zone.spawns or {}) do
                if not (s.gather or s.rare or s.special or s.hunter) then SFP.db.hiddenSpots[spotKey(s)] = true end
            end
        end
        SFP.hiddenVer = SFP.hiddenVer + 1
        for _, z in pairs(SFP.zoneByMap or {}) do z._areas, z._clusters = nil, nil end
        if SFP.RefreshWorldMap then pcall(SFP.RefreshWorldMap) end
    end)
end)

-- symbol on top of a marker, always visible (no text needed):
-- gold star = rare / BoE spot worth grinding, hunter crest = hunter tame
local STAR_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local HUNTER_TEX = "Interface\\Icons\\ClassIcon_Hunter"
local function markSymbol(p, spawns, sc)
    local tex
    for _, s in ipairs(spawns) do
        if s.hunter then tex = tex or HUNTER_TEX end
        if s.grind then tex = STAR_TEX end
    end
    if not tex then return end
    if not p.icon then p.icon = p:CreateTexture(nil, "OVERLAY") end
    local size = 14 / sc
    p.icon:ClearAllPoints()
    p.icon:SetPoint("CENTER")
    p.icon:SetSize(size, size)
    p.icon:SetTexture(tex)
    if tex == HUNTER_TEX then p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) else p.icon:SetTexCoord(0, 1, 0, 1) end
    p.icon:Show()
end

local function drawAreas(zoneID, rect, unit, withLabels)
    local zone = SFP.zoneByMap[zoneID]
    local l, r, t, b = 0, 1, 0, 1
    if rect then l, r, t, b = rect[1], rect[2], rect[3], rect[4] end
    local sc = canvasScale()
    local placed = {}
    for _, c in ipairs(spawnClusters(zone)) do
        local main = c.order[1]
        local x, y = l + c.x * (r - l), t + c.y * (b - t)
        -- small marker, fixed size on screen; a little bigger for busy areas
        local big = math.min(1 + (c.n - 1) * 0.04, 1.6)
        if SFP.db.exactSpots then big = 1 end
        local p = getPin()
        local hv = { spawn = main, spawns = c.order, zoneID = zoneID, zx = c.x, zy = c.y, continent = rect ~= nil }
        if c.rad then
            -- the one big grind-zone circle: its size is the area the farm spots cover
            local wl = spawnLayer:GetWidth()
            hv.rad = c.rad * (r - l)
            placePin(p, x, y, 2 * hv.rad * wl, 0.55, 4 / sc, hv)
        else
            placePin(p, x, y, (SFP.db.exactSpots and 10 or 13 * big) / sc, 0.55, (SFP.db.exactSpots and 4 or 5 * big) / sc, hv)
        end
        markSymbol(p, c.order, sc)
        -- a rare you killed today: grey until the daily reset
        if SFP.db.greyKilled ~= false and main.rare and main.npc and main.npc > 0 and SFP.RareKilledToday and SFP:RareKilledToday(main.npc) then
            p.outer:SetVertexColor(0.55, 0.55, 0.55, 0.3)
            p.inner:SetVertexColor(0.6, 0.6, 0.6, 0.5)
        end
        if withLabels and SFP.db.showLabels then
            local shift = 0
            for _, q in ipairs(placed) do
                if math.abs(q[1] - x) < 0.06 * (r - l) and math.abs(q[2] - y) < 0.04 * (b - t) then shift = shift + 1 end
            end
            placed[#placed + 1] = { x, y }
            local more = #c.order > 1 and (" |cffaaaaaa+" .. (#c.order - 1) .. " more|r") or nil
            label(x, y, spotText(main, c.x, c.y, more), 10 / sc + 4, shift)
        end
    end
end

-- Zone map: every spawn point glows; overlapping glows form a cyan area
local function drawZoneSpawns(zoneID)
    local zone = SFP.zoneByMap[zoneID]
    if not zone or not zone.spawns then return end
    local w = spawnLayer:GetWidth()
    if w <= 0 then return end
    drawAreas(zoneID, nil, w / 100, true)
end

-- Continent map: zoomed out = one bright spot per farm mob;
-- zoomed in = the real spawn areas + name/coordinate labels, like the zone map
local function drawContinentSpots(mapID)
    local w = spawnLayer:GetWidth()
    if w <= 0 then return end
    local unit = w / 100
    local sc = WorldMapFrame.ScrollContainer
    local zoomed = sc.IsZoomedIn and sc:IsZoomedIn()
    for zoneID, zone in pairs(SFP.zoneByMap) do
        if zone.spawns and SFP:IsValuableZone(zoneID) and isUnder(zoneID, mapID) then
            local l, r, t, b = C_Map.GetMapRectOnMap(zoneID, mapID)
            if l and r > l and b > t then
                if zoomed then
                    drawAreas(zoneID, { l, r, t, b }, unit, true)
                else
                    -- zoomed out: ONE big marker per zone; hover it for every farm mob of that zone
                    local order, sx, sy, n = {}, 0, 0, 0
                    for _, s in ipairs(zone.spawns) do
                        if showSpot(s) and not s.gather and s.points and #s.points > 0 then
                            order[#order + 1] = s
                            for _, pt in ipairs(s.points) do sx, sy, n = sx + pt[1], sy + pt[2], n + 1 end
                        end
                    end
                    if n > 0 then
                        table.sort(order, function(a, b)
                            if (a.grind and 1 or 0) ~= (b.grind and 1 or 0) then return a.grind and true or false end
                            return #a.points > #b.points
                        end)
                        local zx, zy = sx / n, sy / n
                        local sc = canvasScale()
                        local big = math.min(1 + math.sqrt(#order) * 0.15, 2.4)
                        local p = getPin()
                        placePin(p, l + zx * (r - l), t + zy * (b - t), 15 * big / sc, 0.55, 5 * big / sc,
                            { spawn = order[1], spawns = order, zoneID = zoneID, zx = zx, zy = zy, continent = true, zonewide = true })
                        markSymbol(p, order, sc)
                    end
                end
            end
        end
    end
end

-- Mining / herbalism: a few small symbols per zone instead of glows. Node
-- positions of all ores/herbs whose best zone this is are grouped into
-- areas; each area gets one symbol listing every material found around it.
local CLUSTER_R = 0.12
local function gatherClusters(zone)
    local key = (SFP.db.showMining and "o" or "") .. (SFP.db.showHerbs and "h" or "") .. SFP.hiddenVer
    zone._clusters = zone._clusters or {}
    if zone._clusters[key] then return zone._clusters[key] end
    local list = {}
    for _, s in ipairs(zone.spawns or {}) do
        if s.gather and showSpot(s) then
            local id = s.items[1]
            for _, pt in ipairs(s.points) do
                local best, bd
                for _, c in ipairs(list) do
                    local dx, dy = c.x - pt[1], c.y - pt[2]
                    local d = dx * dx + dy * dy
                    if d < CLUSTER_R * CLUSTER_R and (not bd or d < bd) then best, bd = c, d end
                end
                if not best then
                    best = { x = pt[1], y = pt[2], n = 0, items = {}, kinds = {} }
                    list[#list + 1] = best
                end
                best.x = (best.x * best.n + pt[1]) / (best.n + 1)
                best.y = (best.y * best.n + pt[2]) / (best.n + 1)
                best.n = best.n + 1
                best.items[id] = (best.items[id] or 0) + 1
                best.kinds[s.gather] = true
            end
        end
    end
    zone._clusters[key] = list
    return list
end

local function placeSymbol(x, y, c, zoneID, continent, w, hh)
    local p = getPin()
    local size = 7 / canvasScale()   -- the herb and ore symbols are as small as the blue treasure boxes
    p:SetSize(size * 1.6, size * 1.6)
    p.outer:SetSize(1, 1); p.outer:SetVertexColor(0, 0, 0, 0)
    p.inner:SetSize(1, 1); p.inner:SetVertexColor(0, 0, 0, 0)
    if not p.icon then p.icon = p:CreateTexture(nil, "OVERLAY") end
    if not p.icon2 then p.icon2 = p:CreateTexture(nil, "OVERLAY") end
    local both = c.kinds.ore and c.kinds.herb
    p.icon:ClearAllPoints()
    p.icon:SetPoint("CENTER", both and -size * 0.3 or 0, 0)
    p.icon:SetSize(size, size)
    p.icon:SetTexture(SFP.KindIcon[c.kinds.ore and "ore" or "herb"])
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.icon:Show()
    if both then
        p.icon2:ClearAllPoints()
        p.icon2:SetPoint("CENTER", size * 0.35, -size * 0.25)
        p.icon2:SetSize(size * 0.8, size * 0.8)
        p.icon2:SetTexture(SFP.KindIcon.herb)
        p.icon2:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        p.icon2:Show()
    else
        p.icon2:Hide()
    end
    p:ClearAllPoints()
    p:SetPoint("CENTER", spawnLayer, "TOPLEFT", x * w, -y * hh)
    hoverList[#hoverList + 1] = { cluster = c, zoneID = zoneID, mx = x, my = y, zx = c.x, zy = c.y, continent = continent }
end

local function drawGatherSymbols(zoneID, rect)
    local zone = SFP.zoneByMap[zoneID]
    if not zone or not zone.spawns then return end
    local w, hh = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    if w <= 0 then return end
    local l, r, t, b = 0, 1, 0, 1
    if rect then l, r, t, b = rect[1], rect[2], rect[3], rect[4] end
    for _, c in ipairs(gatherClusters(zone)) do
        placeSymbol(l + c.x * (r - l), t + c.y * (b - t), c, zoneID, rect ~= nil, w, hh)
    end
end

local function drawGatherContinent(mapID)
    local sc = WorldMapFrame.ScrollContainer
    local zoomed = sc.IsZoomedIn and sc:IsZoomedIn()
    local w, hh = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    for zoneID, zone in pairs(SFP.zoneByMap) do
        if zone.spawns and isUnder(zoneID, mapID) then
            local l, r, t, b = C_Map.GetMapRectOnMap(zoneID, mapID)
            if l and r > l and b > t then
                if zoomed then
                    drawGatherSymbols(zoneID, { l, r, t, b })
                else -- zoomed out: one symbol per zone holding all its materials
                    local all = { x = 0, y = 0, n = 0, items = {}, kinds = {} }
                    for _, c in ipairs(gatherClusters(zone)) do
                        all.x, all.y, all.n = all.x + c.x * c.n, all.y + c.y * c.n, all.n + c.n
                        for id, k in pairs(c.items) do all.items[id] = (all.items[id] or 0) + k end
                        for k in pairs(c.kinds) do all.kinds[k] = true end
                    end
                    if all.n > 0 then
                        all.x, all.y = all.x / all.n, all.y / all.n
                        placeSymbol(l + all.x * (r - l), t + all.y * (b - t), all, zoneID, true, w, hh)
                    end
                end
            end
        end
    end
end

-- Dungeon / raid entrances on the viewed map (icon + loot on hover)
local function drawInstances(mapID)
    local w, hh = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    if w <= 0 then return end
    local groups = {}
    for _, exp in ipairs(SFP.Expansions) do
        for _, inst in ipairs(exp.instances or {}) do
            local e = SFP:FindEntrance(inst)
            local want = (inst.kind == "raid") and SFP.db.showRaids or (inst.kind ~= "raid" and SFP.db.showDungeons)
            if want and #inst.items > 0 and e and e.map == mapID then
                local key = string.format("%.3f:%.3f", e.x, e.y)
                local g = groups[key]
                if not g then g = { x = e.x, y = e.y, list = {} }; groups[key] = g end
                table.insert(g.list, inst)
            end
        end
    end
    local size = 22 / canvasScale()
    for _, g in pairs(groups) do
        local p = getPin()
        local raid = false
        for _, inst in ipairs(g.list) do if inst.kind == "raid" then raid = true end end
        p:SetSize(size * 1.8, size * 1.8)
        p.outer:SetSize(size * 1.8, size * 1.8)
        p.outer:SetVertexColor(1, 0.5, 0, 0.35)
        p.inner:SetSize(1, 1)
        p.inner:SetVertexColor(0, 0, 0, 0)
        if not p.icon then p.icon = p:CreateTexture(nil, "OVERLAY") end
        p.icon:ClearAllPoints(); p.icon:SetPoint("CENTER"); p.icon:SetTexCoord(0, 1, 0, 1)
        p.icon:SetTexture(raid and SFP.RAID_ICON or SFP.DUNGEON_ICON)
        p.icon:SetSize(size, size)
        p.icon:Show()
        p:ClearAllPoints()
        p:SetPoint("CENTER", spawnLayer, "TOPLEFT", g.x * w, -g.y * hh)
        hoverList[#hoverList + 1] = { instances = g.list, mx = g.x, my = g.y, zx = g.x, zy = g.y }
    end
end

---------------------------------------------------------------------------
-- Optional whole-zone glow (off by default)
---------------------------------------------------------------------------
local function getTexture()
    poolUsed = poolUsed + 1
    local t = pool[poolUsed]
    if not t then
        t = overlay:CreateTexture(nil, "OVERLAY")
        t:SetBlendMode("ADD")
        pool[poolUsed] = t
    end
    t:ClearAllPoints()
    t:SetTexCoord(0, 1, 0, 1)
    t:Show()
    return t
end

local function releaseAll()
    for i = 1, #pool do pool[i]:Hide() end
    poolUsed = 0
end

-- the farm route (SFP:BuildRoute): a yellow line from spot to spot
local routeLines = {}
local function drawRoute(mapID)
    for _, l in ipairs(routeLines) do l:Hide() end
    local r = SFP.route
    if SFP.db.showRoute == false or not r or r.map ~= mapID or #r.pts < 2 or not spawnLayer then return end
    local w, h = spawnLayer:GetWidth(), spawnLayer:GetHeight()
    for i = 1, #r.pts - 1 do
        local l = routeLines[i]
        if not l then l = spawnLayer:CreateLine(nil, "OVERLAY"); routeLines[i] = l end
        l:SetThickness(2)
        l:SetColorTexture(1, 0.9, 0.2, 0.9)
        l:SetStartPoint("TOPLEFT", spawnLayer, r.pts[i].x * w, -r.pts[i].y * h)
        l:SetEndPoint("TOPLEFT", spawnLayer, r.pts[i + 1].x * w, -r.pts[i + 1].y * h)
        l:Show()
    end
end

local function pointInZone(parentMap, zoneID, l, r, t, b)
    local function hit(x, y)
        local info = C_Map.GetMapInfoAtPosition(parentMap, x, y)
        return info and info.mapID == zoneID
    end
    local cx, cy = (l + r) / 2, (t + b) / 2
    if hit(cx, cy) then return cx, cy end
    for i = 1, 5 do
        for j = 1, 5 do
            local x, y = l + (r - l) * (i / 6), t + (b - t) * (j / 6)
            if hit(x, y) then return x, y end
        end
    end
end

SFP.IsUnderMap = function(z, m) return isUnder(z, m) end

local function drawZoneFill(parentMap, zoneID, cr, cg, cb, ca)
    local l, r, t, b = C_Map.GetMapRectOnMap(zoneID, parentMap)
    if not l or r <= l or b <= t then return end
    local w, h = overlay:GetWidth(), overlay:GetHeight()
    local c = C()
    local px, py = pointInZone(parentMap, zoneID, l, r, t, b)
    if not px then return end
    local fileDataID, atlasID, texPctX, texPctY, texX, texY, scrollX, scrollY =
        C_Map.GetMapHighlightInfoAtPosition(parentMap, px, py)
    if not ((fileDataID and fileDataID > 0) or atlasID) then return end
    local tex = getTexture()
    if atlasID then
        tex:SetAtlas(atlasID, true, "TRILINEAR")
        tex:SetPoint("CENTER", overlay, "CENTER", ((scrollX + 0.5 * texX) - 0.5) * w, -((scrollY + 0.5 * texY) - 0.5) * h)
    else
        tex:SetTexture(fileDataID, nil, nil, "LINEAR")
        tex:SetTexCoord(0, texPctX, 0, texPctY)
        tex:SetSize(texX * w, texY * h)
        tex:SetPoint("TOPLEFT", overlay, "TOPLEFT", scrollX * w, -scrollY * h)
    end
    tex:SetVertexColor(cr or c.r, cg or c.g, cb or c.b, ca or 0.45)
end
SFP.DrawZoneFill = drawZoneFill

---------------------------------------------------------------------------
-- Optional item panel (off by default; turn on in the browser)
---------------------------------------------------------------------------
local ROW_H = 16
local function panelRow(i)
    panel.rows = panel.rows or {}
    local row = panel.rows[i]
    if row then row:Show(); return row end
    row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(14, 14)
    row.icon:SetPoint("LEFT")
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.left:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.left:SetJustifyH("LEFT")
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetPoint("RIGHT")
    row.left:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnEnter", function(self)
        if self.itemID then
            SFP.Tip():SetOwner(self, "ANCHOR_LEFT")
            SFP.Tip():SetItemByID(self.itemID)
            SFP.Tip():AddLine("Right-click: Wowhead link", 0.9, 0.28, 0.24)
            SFP.Tip():Show()
        end
    end)
    row:SetScript("OnLeave", function() SFP.Tip():Hide() end)
    row:SetScript("OnClick", function(self, button)
        if self.itemID and button == "RightButton" then SFP:ShowWowhead(self.itemID)
        elseif self.waypoint then
            local wp = self.waypoint
            SFP:SetWaypoint(wp.map, wp.x, wp.y, wp.label)
        end
    end)
    panel.rows[i] = row
    return row
end

local function fillPanel(zoneID)
    local zone = SFP.zoneByMap[zoneID]
    local n = 0
    local function add()
        n = n + 1
        local r = panelRow(n)
        local y = -26 - (n - 1) * ROW_H
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
        r:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, y)
        return r
    end
    panel.title:SetText("|c" .. SFP.CYAN_HEX .. SFP:ZoneName(zoneID) .. "|r")
    for _, id in ipairs(sortedItems(zone.items)) do
        local r = add()
        r.itemID, r.waypoint = id, nil
        r.icon:SetTexture(SFP:ItemIcon(id)); r.icon:Show()
        r.left:SetText(SFP:ItemName(id))
        r.right:SetText(SFP:FormatPrice(SFP:GetPrice(id)))
    end
    for _, s in ipairs(zone.spawns or {}) do
        local r = add()
        r.itemID, r.waypoint = nil, { map = zoneID, x = s.hx, y = s.hy, label = s.name }
        r.icon:Hide()
        r.left:SetText("|c" .. SFP.CYAN_HEX .. s.name .. "|r")
        r.right:SetText(string.format("%.1f, %.1f", s.hx * 100, s.hy * 100))
    end
    if panel.rows then for i = n + 1, #panel.rows do panel.rows[i]:Hide() end end
    panel:SetHeight(34 + n * ROW_H)
end

---------------------------------------------------------------------------
-- Gathering list (side of the zone map): the expansion's ores and herbs and
-- the best zone for each. Click a row to open that zone.
---------------------------------------------------------------------------
local gatherPanel
local GROW_H = 28   -- room after each material

-- (the side lists used to be draggable; they are fixed now)
local function makeMovable(f, key, sc)
    do return end   -- the side lists are fixed: they sit above their button on the line below the map
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    local function stop()
        f:StopMovingOrSizing()
        local l, t, sl, st = f:GetLeft(), f:GetTop(), sc:GetLeft(), sc:GetTop()
        if l and t and sl and st then
            SFP.db.panelPos = SFP.db.panelPos or {}
            SFP.db.panelPos[key] = { l - sl, t - st }
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", sc, "TOPLEFT", l - sl, t - st)
        end
    end
    for _, h in ipairs({ f, f.head }) do
        h:RegisterForDrag("LeftButton")
        h:SetScript("OnDragStart", function() f:StartMoving() end)
        h:SetScript("OnDragStop", stop)
    end
    local pos = SFP.db.panelPos and SFP.db.panelPos[key]
    if pos then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", sc, "TOPLEFT", pos[1], pos[2])
    end
end

local function buildGatherPanel()
    local sc = WorldMapFrame.ScrollContainer
    local f = CreateFrame("Frame", "SeviathsUsefulToolsGatherList", sc, "BackdropTemplate")
    f:SetFrameStrata("HIGH")
    f:SetWidth(262)
    f:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -8, 8)
    SFP.BlizzardFrame(f)
    f:SetBackdropColor(0.05, 0.04, 0.02, 0.95)
    f:SetBackdropBorderColor(1, 0.7, 0.35, 0.8)
    f:EnableMouse(true)

    f.head = CreateFrame("Button", nil, f)
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.head:SetPoint("TOPRIGHT", 0, 0)
    f.head:SetHeight(20)
    f.title = f.head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("LEFT", 7, 0)
    f.toggle = f.head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.toggle:SetPoint("RIGHT", -7, 0)
    f.head:SetScript("OnClick", function()
        SFP.db.gatherCollapsed = not SFP.db.gatherCollapsed
        SFP.RefreshWorldMap()
    end)
    f.rows = {}
    makeMovable(f, "gather", sc)
    return f
end

local function gatherRow(i)
    local r = gatherPanel.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, gatherPanel)
    r:SetHeight(GROW_H)
    r:SetPoint("LEFT", 4, 0)
    r:SetPoint("RIGHT", -4, 0)
    r.kind = r:CreateTexture(nil, "ARTWORK")
    r.kind:SetSize(13, 13)
    r.kind:SetPoint("LEFT", 2, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(15, 15)
    r.icon:SetPoint("LEFT", r.kind, "RIGHT", 3, 0)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)   -- one line: a long name is cut instead of running into the next row
    r.name:SetMaxLines(1)
    r.best = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.best:SetPoint("LEFT", r.name, "RIGHT", 12, 0)
    r.best:SetJustifyH("LEFT")
    r:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    r:SetScript("OnEnter", function(self)
        if not self.item then return end
        SFP.Tip():SetOwner(self, "ANCHOR_LEFT")
        SFP.Tip():SetItemByID(self.item)
        SFP.Tip():AddLine(" ")
        SFP.Tip():AddLine(self.bestText, 0.25, 1, 0.25, true)
        if self.target then SFP.Tip():AddLine("Click: open that zone", 0.9, 0.28, 0.24) end
        SFP.Tip():Show()
    end)
    r:SetScript("OnLeave", function() SFP.Tip():Hide() end)
    r:SetScript("OnClick", function(self)
        if self.target and self.target ~= WorldMapFrame:GetMapID() then WorldMapFrame:SetMapID(self.target) end
    end)
    gatherPanel.rows[i] = r
    return r
end

-- what spawns in this zone: every ore/herb (any expansion) with recorded
-- nodes here, most common first, plus the best zone for each
local function gatherHere(mapID)
    local rows, seen = {}, {}
    local exp = SFP:ExpansionForMap(mapID)
    for _, g in ipairs(SFP.Gather or {}) do
        if not seen[g.item] then
            local counts = SFP.GatherZones and SFP.GatherZones[g.item]
            local here, bestMap, bestN
            if counts then
                here = counts[mapID]
                for m, c in pairs(counts) do if not bestN or c > bestN then bestMap, bestN = m, c end end
            elseif g.listOnly then
                -- not a node of its own (bonus loot, dungeon-only node, mob drop): list it in
                -- the zones named in g.zones, or across the expansion when none are given
                if g.zones then
                    for _, zm in ipairs(g.zones) do if zm == mapID then here = 0 end end
                elseif exp and exp.key == g.exp then here = 0 end
                bestMap = g.zones and nil or g.map
            elseif g.map == mapID then
                here, bestMap, bestN = g.nodes or 0, g.map, g.nodes
            end
            if here then
                seen[g.item] = true
                rows[#rows + 1] = { item = g.item, kind = g.kind, here = here, best = bestMap, bestN = bestN, exp = g.exp, how = g.how }
            end
        end
    end
    -- the special materials of the zone (rare hides, lure beasts, special cloth): the monsters that drop them
    local zone = SFP.zoneByMap[mapID]
    for _, sp in ipairs(zone and zone.spawns or {}) do
        if sp.special and sp.items and sp.items[1] and not seen[sp.items[1]] then
            seen[sp.items[1]] = true
            rows[#rows + 1] = { item = sp.items[1], kind = "special", here = sp.points and #sp.points or 0, best = mapID, how = "from " .. tostring(sp.name) }
        end
    end
    table.sort(rows, function(a, b)
        if a.kind ~= b.kind then return a.kind == "ore" end
        if a.here ~= b.here then return a.here > b.here end
        return a.item < b.item
    end)
    return rows
end
SFP.GatherHere = gatherHere

local function drawGatherList(mapID)
    local rows = gatherHere(mapID)
    gatherPanel = gatherPanel or buildGatherPanel()
    gatherPanel.title:SetText("|cffffb366Mining|r & |cff4dff8cHerbalism|r  |cffaaaaaa" .. SFP:ZoneName(mapID) .. "|r")
    gatherPanel.toggle:SetText(SFP.db.gatherCollapsed ~= false and "[+]" or "[-]")
    if SFP.db.gatherCollapsed ~= false then gatherPanel:Hide() return end
    local n = 0
    if not SFP.db.gatherCollapsed then
        if #rows == 0 then
            n = 1
            local r = gatherRow(1)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 4, -20); r:SetPoint("TOPRIGHT", -4, -20)
            r.item, r.target = nil, nil
            r.kind:SetTexture(nil); r.icon:SetTexture(nil)
            r.name:SetText("|cff808080No node data for this zone in the addon yet|r")
            r.best:SetText("")
            r:Show()
        end
        for _, g in ipairs(rows) do
            n = n + 1
            local r = gatherRow(n)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 4, -20 - (n - 1) * GROW_H)
            r:SetPoint("TOPRIGHT", -4, -20 - (n - 1) * GROW_H)
            r.item, r.target = g.item, g.best
            r.kind:SetTexture(SFP.KindIcon[g.kind])
            r.icon:SetTexture(SFP:ItemIcon(g.item))
            local count = g.here > 0 and (" |cff808080(" .. g.here .. ")|r") or ""
            r.name:SetText(SFP:ItemName(g.item) .. count)
            if g.best == mapID then
                r.best:SetText("|cff40ff40best zone: here|r")
                r.bestText = "This is the best zone for it" .. (g.bestN and (" - " .. g.bestN .. " recorded nodes") or "")
            elseif g.best then
                local zoneName = SFP:ZoneName(g.best)
                r.best:SetText("|cffaaaaaabest:|r |cffffd100" .. zoneName .. "|r")
                r.bestText = (g.here > 0 and (g.here .. " recorded nodes here. ") or "") ..
                    "Best zone: " .. zoneName .. (g.bestN and (" (" .. g.bestN .. " nodes)") or "")
            else
                r.best:SetText("|cffaaaaaaevery zone|r")
                r.bestText = "Spawns in every zone of this expansion"
            end
            if g.how then
                r.best:SetText("|cffffd100how to get it|r")
                r.bestText = g.how
            end
            r.name:SetWidth(0)
            r:Show()
        end
    end
    for i = n + 1, #gatherPanel.rows do gatherPanel.rows[i]:Hide() end
    gatherPanel:SetHeight(24 + n * GROW_H)
    gatherPanel:Show()
    if SFP.DockPanels then SFP.DockPanels() end
end

---------------------------------------------------------------------------
-- Farm spot list (left side of the zone map): every spot of the zone with a
-- checkbox; unticked spots disappear from the map and the minimap.
---------------------------------------------------------------------------
local spotPanel
local SROW_H = 18

local SPOT_GROUPS = {
    { "farm", "Farm monsters" }, { "rare", "Rares" }, { "hunter", "Hunter tames" },
    { "special", "Special materials" }, { "ore", "Mining spots" }, { "herb", "Herb spots" },
}

local function spotGroup(s)
    return s.gather or spotCat(s)
end

local function groupOn(g)
    local db = SFP.db
    if g == "farm" then return db.showSpawns elseif g == "rare" then return db.showRares
    elseif g == "hunter" then return db.showHunter elseif g == "special" then return db.showSpecial
    elseif g == "ore" then return db.showMining elseif g == "herb" then return db.showHerbs end
    return true
end

local function spotEntries(zone)
    local by = {}
    if not SFP._bestDone then markBest() end
    for _, s in ipairs(zone.spawns or {}) do
        -- ores, herbs and special materials are listed in the Mining & Herbalism list, not here
        if s.points and s._best ~= false and spotGroup(s) == "rare" then
            local g = spotGroup(s)
            by[g] = by[g] or {}
            by[g][#by[g] + 1] = s
        end
    end
    local out = {}
    for _, grp in ipairs(SPOT_GROUPS) do
        local list = by[grp[1]]
        if list then
            table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
            out[#out + 1] = { header = grp[2], group = grp[1] }
            local seen = {}
            for _, s in ipairs(list) do
                local k = spotKey(s)
                if not seen[k] then
                    seen[k] = true
                    out[#out + 1] = { spot = s, group = grp[1] }
                end
            end
        end
    end
    return out
end

-- ticking a spot of a kind whose layer switch is off turns that layer on, so the spot really shows
local GROUP_SWITCH = { farm = "showSpawns", rare = "showRares", hunter = "showHunter", special = "showSpecial", ore = "showMining", herb = "showHerbs" }
local function enableGroup(g)
    local k = GROUP_SWITCH[g]
    if k and not SFP.db[k] then SFP.db[k] = true end
    if not SFP.db.mapOverlay then SFP.db.mapOverlay = true end
end

local function setSpotsHidden(zone, keys, hide, group)
    if not hide and group then enableGroup(group) end
    SFP.db.hiddenSpots = SFP.db.hiddenSpots or {}
    for _, k in ipairs(keys) do SFP.db.hiddenSpots[k] = hide and true or nil end
    SFP.hiddenVer = SFP.hiddenVer + 1
    zone._areas, zone._clusters = nil, nil
    SFP.RefreshWorldMap()
end

local drawSpotList

local function buildSpotPanel()
    local sc = WorldMapFrame.ScrollContainer
    local f = CreateFrame("Frame", "SeviathsUsefulToolsSpotList", sc, "BackdropTemplate")
    f:SetFrameStrata("HIGH")
    f:SetWidth(250)
    f:SetPoint("TOPLEFT", sc, "TOPLEFT", 8, -8)
    SFP.BlizzardFrame(f)
    f:SetBackdropColor(0.02, 0.05, 0.06, 0.95)
    f:SetBackdropBorderColor(0.9, 0.28, 0.24, 0.8)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        self.offset = (self.offset or 0) - delta * 3
        if self.mapID then drawSpotList(self.mapID) end
    end)

    f.head = CreateFrame("Button", nil, f)
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.head:SetPoint("TOPRIGHT", 0, 0)
    f.head:SetHeight(20)
    f.title = f.head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("LEFT", 7, 0)
    f.toggle = f.head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.toggle:SetPoint("RIGHT", -7, 0)
    f.head:SetScript("OnClick", function()
        SFP.db.raresCollapsed = not SFP.db.raresCollapsed
        SFP.RefreshWorldMap()
    end)

    -- tick box on the map itself: show or hide the yellow route line (same switch as on the Settings page)
    local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetSize(18, 18)
    cb:SetPoint("BOTTOMLEFT", 6, 4)   -- inside the menu, at the bottom left (the list's own switch)
    cb:SetHitRectInsets(0, -64, 0, 0)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 0, 0)
    cb.label:SetText("Route line")
    cb:SetScript("OnClick", function(self)
        SFP.db.showRoute = self:GetChecked() and true or false
        SFP.RefreshWorldMap()
    end)
    cb:SetScript("OnEnter", function(self)
        SFP.Tip():SetOwner(self, "ANCHOR_RIGHT")
        SFP.Tip():AddLine("Show or hide the yellow farm route line on this map.", 1, 1, 1, true)
        SFP.Tip():Show()
    end)
    cb:SetScript("OnLeave", function() SFP.Tip():Hide() end)
    f.routeCheck = cb

    local function link(text, anchor, x)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(60, 16)
        b:SetFrameLevel(f.head:GetFrameLevel() + 5)
        b:SetPoint("TOPLEFT", x, -21)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("LEFT")
        b.text:SetText("|cffe6483d" .. text .. "|r")
        b:SetWidth(b.text:GetStringWidth() + 4)
        return b
    end
    f.allOn = link("Show all", nil, 8)
    f.allOff = link("Hide all", nil, 70)
    f.route = link("Route", nil, 132)
    f.routeClear = link("Clear route", nil, 176)
    f.rows = {}
    -- bottom button: the 10 best farm spots of the game by current auction prices, with a waypoint each
    f.top = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.top:SetSize(150, 20)
    f.top:SetPoint("BOTTOMRIGHT", -4, 4)
    f.top:SetText("Top 10 best spots")
    f.top:SetFrameLevel(f.head:GetFrameLevel() + 5)
    f.top:SetScript("OnClick", function() if SFP.ShowTopSpots then SFP:ShowTopSpots() end end)
    makeMovable(f, "spots", sc)
    return f
end

local function spotRow(i)
    local r = spotPanel.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, spotPanel)
    r:SetHeight(SROW_H)
    r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
    r.check:SetSize(20, 20)
    r.check:SetPoint("LEFT", 0, 0)
    r.check:SetScript("OnClick", function(self)
        local s = r.spot
        if not s then return end
        local zone = SFP.zoneByMap[spotPanel.mapID]
        if zone then setSpotsHidden(zone, { spotKey(s) }, not self:GetChecked(), spotGroup(s)) end
    end)
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(9, 9)
    r.dot:SetPoint("LEFT", r.check, "RIGHT", 1, 0)
    r.dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.dot, "RIGHT", 4, 0)
    r.name:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.name:SetJustifyH("LEFT")
    r:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    r:RegisterForClicks("LeftButtonUp")
    r:SetScript("OnEnter", function(self)
        local s = self.spot
        if not s then return end
        local c = spotColor(s)
        SFP.Tip():SetOwner(self, "ANCHOR_RIGHT")
        SFP.Tip():AddLine(s.name or "?", c.r, c.g, c.b)
        -- everything the monster drops: what the addon collected from its kills (the shipped data too), each with how often and its price;
        -- the items this spot is listed for come first when nothing is known about the monster yet
        local drops, kills = {}, s.kills or 0
        local rec = s.npc and SFP.Npc and SFP:Npc(s.npc)
        if type(rec) == "table" then
            kills = math.max(kills, rec.k or 0)
            for _, src in ipairs({ rec.d or {}, rec.s or {} }) do
                for id, q in pairs(src) do if type(q) == "number" then drops[id] = (drops[id] or 0) + q end end
            end
        end
        for id, q in pairs(s.counts or {}) do drops[id] = math.max(drops[id] or 0, q) end
        for _, id in ipairs(s.items or {}) do if not drops[id] then drops[id] = 0 end end
        -- the items Wowhead lists for this monster (dungeon monsters and bosses too)
        local listed = s.npc and SFP.WowheadDrops and SFP:WowheadDrops(s.npc)
        if listed then for _, id in ipairs(listed) do if not drops[id] then drops[id] = 0 end end end
        local order = {}
        for id in pairs(drops) do if not (SFP.IsQuestLoot and SFP.IsQuestLoot(id)) then order[#order + 1] = id end end
        table.sort(order, function(a, c2)
            if drops[a] ~= drops[c2] then return drops[a] > drops[c2] end
            return a < c2
        end)
        if #order > 0 then
            SFP.Tip():AddLine("Drops", 0.8, 0.8, 0.8)
        end
        for n, id in ipairs(order) do
            if n > 40 then SFP.Tip():AddLine("+" .. (#order - 40) .. " more", 0.6, 0.6, 0.6) break end
            local chance = SFP.ChanceText(drops[id], kills)
            local pct = chance ~= "" and ("  " .. chance) or ""
            local price = SFP:GetPrice(id)
            SFP.Tip():AddDoubleLine("|T" .. SFP:ItemIcon(id) .. ":12|t " .. SFP:ItemName(id) .. pct, SFP.SoldTag(id) .. (price and SFP:FormatPrice(price) or ""), 1, 1, 1, 1, 1, 1)
        end
        if s.hx then SFP.Tip():AddLine(string.format("%.1f, %.1f", s.hx * 100, s.hy * 100), 1, 0.82, 0) end
        SFP.Tip():AddLine("Click: show or hide this spot on the map", 0.9, 0.28, 0.24)
        SFP.Tip():Show()
    end)
    r:SetScript("OnLeave", function() SFP.Tip():Hide() end)
    r:SetScript("OnClick", function(self)
        -- the list only shows or hides spots (the tick box); clicking a name sets nothing, farm spots and rares alike
        local s = self.spot
        if not s then return end
        local zone = SFP.zoneByMap[spotPanel.mapID]
        if zone then setSpotsHidden(zone, { spotKey(s) }, not (SFP.db.hiddenSpots and SFP.db.hiddenSpots[spotKey(s)]), spotGroup(s)) end
    end)
    spotPanel.rows[i] = r
    return r
end

drawSpotList = function(mapID)
    local zone = SFP.zoneByMap[mapID]
    if not zone or not zone.spawns or #zone.spawns == 0 then
        if spotPanel then spotPanel:Hide() end
        return
    end
    spotPanel = spotPanel or buildSpotPanel()
    spotPanel.mapID = mapID
    local entries = spotEntries(zone)
    local nSpots, nHidden, keys, groups = 0, 0, {}, {}
    for _, e in ipairs(entries) do
        if e.spot then
            groups[e.group] = true
            nSpots = nSpots + 1
            keys[#keys + 1] = spotKey(e.spot)
            if SFP.db.hiddenSpots and SFP.db.hiddenSpots[spotKey(e.spot)] then nHidden = nHidden + 1 end
        end
    end
    spotPanel.title:SetText("|cffff8000Rares|r  |cffaaaaaa" .. (nSpots - nHidden) .. "/" .. nSpots .. "|r")
    spotPanel.toggle:SetText(SFP.db.raresCollapsed ~= false and "[+]" or "[-]")
    -- closed: nothing of it stays on the map (the button below the map opens it)
    if SFP.db.raresCollapsed ~= false then spotPanel:Hide() return end
    spotPanel.routeCheck:Hide()
    spotPanel.allOn:SetScript("OnClick", function()
        for g in pairs(groups) do enableGroup(g) end
        setSpotsHidden(zone, keys, false)
    end)
    spotPanel.allOff:SetScript("OnClick", function() setSpotsHidden(zone, keys, true) end)
    spotPanel.route:SetScript("OnClick", function() SFP:BuildRoute(mapID) end)
    spotPanel.routeClear:SetScript("OnClick", function() SFP:ClearRoute() end)
    spotPanel.route:Hide()
    spotPanel.routeClear:Hide()
    spotPanel.allOn:SetShown(not SFP.db.raresCollapsed)
    spotPanel.allOff:SetShown(not SFP.db.raresCollapsed)

    local shown = 0
    if not SFP.db.raresCollapsed then
        local sc = WorldMapFrame.ScrollContainer
        local maxRows = math.max(6, math.floor((sc:GetHeight() - 80) / SROW_H))
        local maxOffset = math.max(0, #entries - maxRows)
        spotPanel.offset = math.min(math.max(spotPanel.offset or 0, 0), maxOffset)
        for i = 1, math.min(maxRows, #entries - spotPanel.offset) do
            local e = entries[spotPanel.offset + i]
            shown = shown + 1
            local r = spotRow(shown)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 4, -38 - (shown - 1) * SROW_H)
            r:SetPoint("TOPRIGHT", -4, -38 - (shown - 1) * SROW_H)
            if e.header then
                r.spot = nil
                r.check:Hide(); r.dot:Hide()
                r.name:ClearAllPoints()
                r.name:SetPoint("LEFT", r, "LEFT", 4, 0)
                r.name:SetPoint("RIGHT", r, "RIGHT", -2, 0)
                r.name:SetText("|cffffd100" .. e.header .. "|r" .. (groupOn(e.group) and "" or "  |cff808080(off in the menu)|r"))
            else
                local s = e.spot
                local off = SFP.db.hiddenSpots and SFP.db.hiddenSpots[spotKey(s)]
                r.spot = s
                r.check:Show(); r.dot:Show()
                r.check:SetChecked(not off)
                r.name:ClearAllPoints()
                r.name:SetPoint("LEFT", r.dot, "RIGHT", 4, 0)
                r.name:SetPoint("RIGHT", r, "RIGHT", -2, 0)
                local c = spotColor(s)
                r.dot:SetVertexColor(c.r, c.g, c.b, off and 0.3 or 1)
                local star = s.grind and (STAR .. " ") or ""
                r.name:SetText(off and ("|cff808080" .. tostring(s.name) .. "|r") or (star .. tostring(s.name)))
            end
            r:Show()
        end
    end
    for i = shown + 1, #spotPanel.rows do spotPanel.rows[i]:Hide() end
    spotPanel:SetHeight((SFP.db.raresCollapsed and 22) or (42 + shown * SROW_H + 8))
    spotPanel.top:Hide()
    spotPanel:Show()
    if SFP.DockPanels then SFP.DockPanels() end
end

---------------------------------------------------------------------------
-- Whole-zone hover tooltip (only with the whole-zone glow option)
---------------------------------------------------------------------------
local lastSpot, lastScale, lastZoomed
local refresh -- forward

local function onUpdate(self, elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t < 0.05 then return end
    self.t = 0
    if not WorldMapFrame:IsShown() then return end

    -- redraw when the map zooms in/out so spots switch between overview and areas
    local sc = WorldMapFrame.ScrollContainer
    local scale = (sc.GetCanvasScale and sc:GetCanvasScale()) or 1
    local zoomed = sc.IsZoomedIn and sc:IsZoomedIn() or false
    if lastScale and (math.abs(scale - lastScale) > 0.01 or zoomed ~= lastZoomed) then
        lastScale, lastZoomed = scale, zoomed
        refresh()
        return
    end
    lastScale, lastZoomed = scale, zoomed

    if not (SFP.db and SFP.db.mapOverlay) or not sc:IsMouseOver() then
        if lastSpot or lastHover then tip:Hide(); lastSpot, lastHover = nil, nil end
        return
    end

    -- a quest (or any other map pin) under the cursor comes first: its own tooltip is shown, not ours
    local focus = (GetMouseFoci and GetMouseFoci()[1]) or (GetMouseFocus and GetMouseFocus())
    local other = GameTooltip:IsShown() and GameTooltip:GetOwner()
    if other and other ~= UIParent and other ~= tip and other.IsMouseOver and other:IsMouseOver() then
        -- the game / another addon already shows a tooltip for something under the cursor: that one wins
        if lastSpot or lastHover then tip:Hide(); lastSpot, lastHover = nil, nil end
        return
    end
    if focus and (focus.questID or focus.pinTemplate or focus.owningMap or focus.poiInfo) then
        if lastSpot or lastHover then tip:Hide(); lastSpot, lastHover = nil, nil end
        return
    end

    -- nearest glowing spot under the cursor (frames don't take the mouse)
    local x, y = WorldMapFrame:GetNormalizedCursorPosition()
    if not x then return end
    local cw, ch = spawnLayer:GetWidth() * scale, spawnLayer:GetHeight() * scale
    local best, bestD = nil, 14 * 14 -- within ~14 screen pixels
    local disc, discR
    for _, h in ipairs(hoverList) do
        local dx, dy = (h.mx - x) * cw, (h.my - y) * ch
        local d = dx * dx + dy * dy
        if h.rad then
            -- the big grind-zone circle: anywhere inside it counts, but small markers on top of it win
            local rr = h.rad * cw
            if d < rr * rr and (not discR or rr < discR) then disc, discR = h, rr end
        elseif d < bestD then best, bestD = h, d end
    end
    best = best or disc
    if best then
        if best ~= lastSpot then lastSpot = best; lastHover = nil; showSpotTip(best) end
        return
    elseif lastSpot then
        tip:Hide(); lastSpot = nil
    end

    -- optional whole-zone hover tooltip
    if not SFP.db.zoneFill then return end
    local mapID = WorldMapFrame:GetMapID()
    local info = C_Map.GetMapInfoAtPosition(mapID, x, y)
    local zoneID = info and info.mapID
    if zoneID and zoneID ~= mapID and SFP:IsValuableZone(zoneID) then
        if zoneID ~= lastHover then
            lastHover = zoneID
            tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 18, 0)
            tip:ClearLines()
            tip:AddLine(SFP:ZoneName(zoneID), C().r, C().g, C().b)
            for _, id in ipairs(sortedItems(SFP.zoneByMap[zoneID].items)) do
                local info = SFP.Items[id]
                if not (info and (info.kind == "ore" or info.kind == "herb")) then tip:AddDoubleLine("|T" .. SFP:ItemIcon(id) .. ":14|t " .. SFP:ItemName(id),
                    SFP:FormatPrice(SFP:GetPrice(id)), 1, 1, 1, 1, 1, 1) end
            end
            local boeText, boeWhere = SFP:RandomBoeText(zoneID)
            tip:AddDoubleLine(boeText, boeWhere, 1, 1, 1, 0.7, 0.7, 0.7)
            tip:Show()
        end
    elseif lastHover then
        tip:Hide(); lastHover = nil
    end
end

---------------------------------------------------------------------------
-- Collectables of the zone (side list): under it the mounts that dungeons and raids with an entrance on this map drop (drop chance and
-- auction price on hover) and the tameable hunter pets (spirit beasts and unique looks) of the zone. A click sets a waypoint and opens
-- the map there.
---------------------------------------------------------------------------
local collPanel
local LROW_H = 18

local function chanceText(id)
    local info = SFP.Items[id]
    return info and info.drop or nil
end

-- the boss of an instance that drops an item (from the Adventure Guide read)
local function bossOf(id, instName)
    for _, l in ipairs(SFP.lootIndex and SFP.lootIndex[id] or {}) do
        if l[1] == instName and l[2] and l[2] ~= "" then return l[2] end
    end
end

-- the mount lines of one instance, added to a tooltip
local function addMountLines(t, inst)
    local any = false
    for _, id in ipairs(inst.items) do
        local info = SFP.Items[id]
        if info and info.kind == "mount" then
            if not any then t:AddLine("Mounts", 0.64, 0.21, 0.93); any = true end
            local ch = chanceText(id)
            local boss = bossOf(id, inst.name)
            local price = SFP:GetPrice(id)
            t:AddDoubleLine("|T" .. SFP:ItemIcon(id) .. ":14|t " .. SFP:ItemName(id) .. (boss and (" |cffaaaaaa" .. boss .. "|r") or ""),
                (ch and ("|cffffd100" .. ch .. "|r  ") or "|cff808080chance not known|r  ") .. (price and SFP:FormatPrice(price) or ""), 1, 1, 1, 1, 1, 1)
        end
    end
    return any
end

local function buildCollPanel()
    local sc = WorldMapFrame.ScrollContainer
    local f = CreateFrame("Frame", "SeviathsUsefulToolsCollectablesList", sc, "BackdropTemplate")
    f:SetFrameStrata("HIGH")
    f:SetWidth(262)
    f:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -8, -8)
    SFP.BlizzardFrame(f)
    f:SetBackdropColor(0.05, 0.04, 0.02, 0.95)
    f:SetBackdropBorderColor(0.64, 0.21, 0.93, 0.8)
    f:EnableMouse(true)
    f.head = CreateFrame("Button", nil, f)
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.head:SetPoint("TOPRIGHT", 0, 0)
    f.head:SetHeight(20)
    f.title = f.head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("LEFT", 7, 0)
    f.toggle = f.head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.toggle:SetPoint("RIGHT", -7, 0)
    f.head:SetScript("OnClick", function()
        SFP.db.collCollapsed = not SFP.db.collCollapsed
        SFP.RefreshWorldMap()
    end)
    f.rows = {}
    makeMovable(f, "collectables", sc)
    return f
end

local function collRow(f, i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f)
    r:SetHeight(LROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(15, 15)
    r.icon:SetPoint("LEFT", 6, 0)
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.right:SetPoint("RIGHT", -4, 0)
    r.right:SetJustifyH("RIGHT")
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
    r.name:SetPoint("RIGHT", r.right, "LEFT", -4, 0)
    r.name:SetJustifyH("LEFT")
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    r.hl:SetBlendMode("ADD")
    r:SetScript("OnEnter", function(self)
        if self.header then return end
        local t = SFP.Tip()
        t:SetOwner(self, "ANCHOR_LEFT")
        if self.item then t:SetItemByID(self.item) end
        for _, l in ipairs(self.lines or {}) do t:AddLine(l, 1, 1, 1, true) end
        t:AddLine("Click: set a waypoint and open the map there", 0.9, 0.28, 0.24)
        t:Show()
    end)
    r:SetScript("OnLeave", function() SFP.Tip():Hide() end)
    r:SetScript("OnClick", function(self)
        if self.header or not self.map then return end
        SFP:SetWaypoint(self.map, self.x, self.y, self.label)
        if SFP.PingSpot then SFP.PingSpot(self.map, self.x, self.y) end
        if WorldMapFrame:GetMapID() ~= self.map then WorldMapFrame:SetMapID(self.map) end
    end)
    f.rows[i] = r
    return r
end

local function mountRows(mapID)
    local rows, seen = {}, {}
    for _, exp in ipairs(SFP.Expansions) do
        for _, inst in ipairs(exp.instances or {}) do
            local e = SFP:FindEntrance(inst)
            if e and e.map == mapID then
                for _, id in ipairs(inst.items) do
                    local info = SFP.Items[id]
                    if info and info.kind == "mount" and not seen[id .. inst.name] then
                        seen[id .. inst.name] = true
                        local ch = chanceText(id)
                        local boss = bossOf(id, inst.name)
                        local price = SFP:GetPrice(id)
                        local lines = {
                            (inst.kind == "raid" and "Raid: " or "Dungeon: ") .. inst.name .. (boss and (" - " .. boss) or ""),
                            "Drop chance: " .. (ch or "not known yet"),
                        }
                        if price then lines[#lines + 1] = "Auction price: " .. SFP:FormatPrice(price) end
                        rows[#rows + 1] = { item = id, map = e.map, x = e.x, y = e.y, label = inst.name, icon = SFP:ItemIcon(id),
                            name = SFP:ItemName(id), right = "|cffaaaaaa" .. inst.name .. "|r", lines = lines }
                    end
                end
            end
        end
    end
    return rows
end

local function petRows(mapID)
    local rows = {}
    local zone = SFP.zoneByMap[mapID]
    for _, sp in ipairs(zone and zone.spawns or {}) do
        if sp.hunter and type(sp.pts) == "string" then
            local x, y = sp.pts:match("([%d%.]+),([%d%.]+)")
            if x then
                rows[#rows + 1] = { map = mapID, x = tonumber(x) / 100, y = tonumber(y) / 100, label = sp.name,
                    icon = "Interface\\Icons\\ClassIcon_Hunter", name = sp.name,
                    right = sp.hunter == "spirit" and "|cffabd473spirit beast|r" or "|cffabd473unique look|r",
                    lines = { SFP.HUNTER_TYPE[sp.hunter] or "Hunter tame", sp.note } }
            end
        end
    end
    return rows
end

---------------------------------------------------------------------------
-- Farm spots and Rares of the zone, as lists like the others: a row is a monster, a click sets a waypoint on it (and pings the spot on
-- the map). Nothing is switched on or off here any more. Ores, herbs and special materials are in the Mining & Herbalism list, hunter pets
-- in the Hunter search.
---------------------------------------------------------------------------
local simplePanels = {}
local SIMPLE_H = 22

-- all the drops of a monster (collected data), with how often and the price
local function addSpotDrops(t, s)
    local drops, kills = {}, s.kills or 0
    local rec = s.npc and SFP.Npc and SFP:Npc(s.npc)
    if type(rec) == "table" then
        kills = math.max(kills, rec.k or 0)
        for _, src in ipairs({ rec.d or {}, rec.s or {} }) do
            for id, q in pairs(src) do if type(q) == "number" then drops[id] = (drops[id] or 0) + q end end
        end
    end
    for id, q in pairs(s.counts or {}) do drops[id] = math.max(drops[id] or 0, q) end
    -- the items Wowhead lists for this monster (dungeon monsters and bosses too)
    local listed = s.npc and SFP.WowheadDrops and SFP:WowheadDrops(s.npc)
    if listed then for _, id in ipairs(listed) do if drops[id] == nil then drops[id] = 0 end end end
    -- what the guides list for it (collectibles and farm items): known, but not its whole loot
    local guide = {}
    for _, id in ipairs(s.items or {}) do if not drops[id] or drops[id] == 0 then guide[#guide + 1] = id; drops[id] = nil end end
    local order = {}
    for id, q in pairs(drops) do if not (SFP.IsQuestLoot and SFP.IsQuestLoot(id)) then order[#order + 1] = id end end
    table.sort(order, function(a, c)
        if drops[a] ~= drops[c] then return drops[a] > drops[c] end
        return a < c
    end)
    local function itemLine(id, q)
        local price = SFP:GetPrice(id)
        local chance = SFP.ChanceText(q, kills)
        if chance == "" and q and q > 0 and kills >= 1 then chance = string.format("%d%%", math.min(100, math.floor(q * 100 / kills + 0.5))) end
        local per = ((q and q > 0 and kills >= 1) and ("  |cff808080x" .. q .. "|r") or "") .. (chance ~= "" and ("  " .. chance) or "")
        t:AddDoubleLine("|T" .. SFP:ItemIcon(id) .. ":12|t " .. SFP:ItemName(id) .. per, (SFP.PriceText and SFP.PriceText(id)) or (price and SFP:FormatPrice(price)) or "", 1, 1, 1, 1, 1, 1)
    end
    if #order > 0 then t:AddLine("Recorded drops", 0.8, 0.8, 0.8) end
    local gold = SFP.MonsterGold and SFP.MonsterGold(s)
    if gold then t:AddDoubleLine("|TInterface\\Icons\\INV_Misc_Coin_01:12|t Gold", SFP:FormatPrice(math.floor(gold)) .. " per kill", 1, 1, 1, 1, 1, 1) end
    for n, id in ipairs(order) do
        if n > 40 then t:AddLine("+" .. (#order - 40) .. " more", 0.6, 0.6, 0.6) break end
        itemLine(id, drops[id])
    end
    if #guide > 0 then
        t:AddLine((#order > 0 and "Also known from the guides" or "Known from the guides (not all of its loot)"), 0.8, 0.8, 0.8)
        for _, id in ipairs(guide) do itemLine(id) end
    end
    if #order == 0 and #guide == 0 and not gold then t:AddLine("No loot recorded yet - kill it and everything it drops is kept", 0.6, 0.6, 0.6, true) end
end

SFP.AddSpotDrops = addSpotDrops

-- gold per kill of a monster (copper), and over how many looted kills it was measured
function SFP.MonsterGold(s)
    local rec = s.npc and SFP.Npc and SFP:Npc(s.npc)
    if type(rec) == "table" and rec.g and (rec.gk or 0) > 0 then return rec.g / rec.gk, rec.gk end
end

local function waypointAt(map, x, y, label)
    if WorldMapFrame:GetMapID() ~= map then WorldMapFrame:SetMapID(map) end
    if x and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        SFP:Print(string.format("Waypoint set: %s, %s %.1f, %.1f", tostring(label), SFP:ZoneName(map), x * 100, y * 100))
        if SFP.PingSpot then SFP.PingSpot(map, x, y) end
    end
end

-- the monsters of the zone that Wowhead lists drops for (the shipped monsters with a place): farm spots too, with those items; once per zone and session.
-- A monster the zone already lists by name is left as it is.
local function addWowheadSpawns(zone)
    if not zone or zone._wh or not zone.map or not SFP.ShippedNpcIDs or not SFP.WowheadDrops then return end
    zone._wh = true
    zone.spawns = zone.spawns or {}
    local have = {}
    for _, s in ipairs(zone.spawns) do have[tostring(s.name):lower()] = true end
    for _, id in ipairs(SFP:ShippedNpcIDs(zone.map)) do
        local drops = SFP:WowheadDrops(id)
        local rec = drops and SFP:Npc(id)
        local pts = type(rec) == "table" and type(rec.m) == "table" and rec.m[zone.map]
        if type(pts) == "table" and pts[1] and type(rec.n) == "string" and not rec.n:find("^NPC ") and not have[rec.n:lower()] then
            local items = {}
            for _, itemID in ipairs(drops) do
                local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID)
                if q ~= 0 and #items < 40 then items[#items + 1] = itemID end   -- gray items stay in the monster's loot table only
            end
            if #items > 0 then
                local points, sx, sy = {}, 0, 0
                for _, p in ipairs(pts) do points[#points + 1] = { p[1], p[2] }; sx, sy = sx + p[1], sy + p[2] end
                zone.spawns[#zone.spawns + 1] = { name = rec.n, npc = id, items = items, points = points, hx = sx / #points, hy = sy / #points, wowhead = true }
                have[rec.n:lower()] = true
            end
        end
    end
end

local function spotsOfGroup(zone, group)
    local list, seen = {}, {}
    addWowheadSpawns(zone)
    if not SFP._bestDone then markBest() end
    for _, s in ipairs(zone and zone.spawns or {}) do
        -- every spot of the database, not only the best one of each item (the map markers still show only the best)
        if s.points and spotGroup(s) == group then
            -- a monster that drops a battle pet is listed under Battle pets (with its waypoint), not under Farm spots
            local petDrop = false   -- a monster that drops a battle pet stays in Farm spots too (the pet has its waypoint under Battle pets as well)
            local k = spotKey(s)
            if not petDrop and not seen[k] then seen[k] = true; list[#list + 1] = s end
        end
    end
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

SFP.FarmSpotsOf = function(mapID, group) return spotsOfGroup(SFP.zoneByMap[mapID], group) end

function SFP.HasFarmLists(mapID)
    local zone = SFP.zoneByMap[mapID]
    return #spotsOfGroup(zone, "farm") > 0, #spotsOfGroup(zone, "rare") > 0
end

local function buildSimplePanel(key, color)
    local sc = WorldMapFrame.ScrollContainer
    local f = CreateFrame("Frame", "SeviathsUsefulTools" .. key .. "List", sc, "BackdropTemplate")
    f:SetFrameStrata("HIGH")
    f:SetWidth(262)
    f:SetPoint("BOTTOMRIGHT", sc, "BOTTOMRIGHT", -8, 8)
    SFP.BlizzardFrame(f)
    f:SetBackdropColor(0.05, 0.04, 0.02, 0.9)
    f:SetBackdropBorderColor(color[1], color[2], color[3], 0.8)
    f:EnableMouse(true)
    f.head = CreateFrame("Button", nil, f)
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.head:SetPoint("TOPRIGHT", 0, 0)
    f.head:SetHeight(20)
    f.title = f.head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("LEFT", 7, 0)
    f.toggle = f.head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.toggle:SetPoint("RIGHT", -7, 0)
    f.head:SetScript("OnClick", function()
        SFP.db[key == "spots" and "spotsCollapsed" or "raresCollapsed"] = true
        SFP.RefreshWorldMap()
    end)
    f.toggle:SetText("[-]")
    f.rows = {}
    return f
end

local function simpleRow(f, i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f)
    r:SetHeight(SIMPLE_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("LEFT", 6, 0)
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.right:SetPoint("RIGHT", -4, 0)
    r.right:SetJustifyH("RIGHT")
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
    r.name:SetPoint("RIGHT", r.right, "LEFT", -4, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.name:SetMaxLines(1)
    r:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    r:SetScript("OnEnter", function(self)
        local t = SFP.Tip()
        t:SetOwner(self, "ANCHOR_LEFT")
        t:AddLine(self.label or "?", 1, 0.82, 0)
        if self.spot then addSpotDrops(t, self.spot) end
        t:AddLine("Click: set a waypoint on it", 0.9, 0.28, 0.24)
        t:Show()
    end)
    r:SetScript("OnLeave", function() SFP.Tip():Hide() end)
    r:SetScript("OnClick", function(self) if self.map then waypointAt(self.map, self.x, self.y, self.label) end end)
    f.rows[i] = r
    return r
end

local function drawSimple(key, flag, title, color, mapID, spots)
    local f = simplePanels[key]
    if SFP.db[flag] ~= false or #spots == 0 then if f then f:Hide() end return end
    if not f then f = buildSimplePanel(key, color); simplePanels[key] = f end
    f.title:SetText(title .. "  |cffaaaaaa" .. SFP:ZoneName(mapID) .. "|r")
    for i, s in ipairs(spots) do
        local r = simpleRow(f, i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 4, -22 - (i - 1) * SIMPLE_H)
        r:SetPoint("TOPRIGHT", -4, -22 - (i - 1) * SIMPLE_H)
        r.spot, r.label, r.map = s, s.name, mapID
        r.x, r.y = s.hx, s.hy
        local id = s.items and s.items[1]
        r.icon:SetTexture(id and SFP:ItemIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark")
        r.name:SetText(tostring(s.name))
        r.right:SetText("|cffff3030WAYPOINT|r")
        r:Show()
    end
    for i = #spots + 1, #f.rows do f.rows[i]:Hide() end
    local extra = 0
    if key == "spots" then
        if not f.foot then
            f.foot = CreateFrame("Frame", nil, f)
            f.foot:SetPoint("BOTTOMLEFT", 0, 0)
            f.foot:SetPoint("BOTTOMRIGHT", 0, 0)
            f.foot:SetHeight(58)
            f.routeCheck = CreateFrame("CheckButton", nil, f.foot, "UICheckButtonTemplate")
            f.routeCheck:SetSize(20, 20)
            f.routeCheck:SetPoint("TOPLEFT", 4, -3)
            f.routeCheck:SetHitRectInsets(0, -60, 0, 0)
            f.routeCheck.label = f.routeCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f.routeCheck.label:SetPoint("LEFT", f.routeCheck, "RIGHT", 0, 0)
            f.routeCheck.label:SetText("Route line")
            f.routeCheck:SetScript("OnClick", function(self)
                SFP.db.showRoute = self:GetChecked() and true or false
                SFP.RefreshWorldMap()
            end)
            f.route = CreateFrame("Button", nil, f.foot, "UIPanelButtonTemplate")
            f.route:SetSize(70, 22); f.route:SetPoint("TOPRIGHT", -78, -3); f.route:SetText("Route")
            f.clear = CreateFrame("Button", nil, f.foot, "UIPanelButtonTemplate")
            f.clear:SetSize(70, 22); f.clear:SetPoint("TOPRIGHT", -4, -3); f.clear:SetText("Clear")
            f.top = CreateFrame("Button", nil, f.foot, "UIPanelButtonTemplate")
            f.top:SetHeight(24); f.top:SetPoint("BOTTOMLEFT", 4, 4); f.top:SetPoint("BOTTOMRIGHT", -4, 4)
            f.top:SetText("Top 10 best spots")
            f.clear:SetScript("OnClick", function() SFP:ClearRoute() end)
            f.top:SetScript("OnClick", function() if SFP.ShowTopSpots then SFP:ShowTopSpots() end end)
        end
        f.routeCheck:SetChecked(SFP.db.showRoute ~= false)
        f.route:SetScript("OnClick", function() SFP:BuildRoute(mapID) end)
        f.foot:Show()
        extra = 58
    end
    f:SetHeight(26 + #spots * SIMPLE_H + extra)
    f:Show()
    if SFP.DockPanels then SFP.DockPanels() end
end

local drawFarmScroll   -- defined below
local function drawFarmLists(mapID)
    local zone = SFP.zoneByMap[mapID]
    drawFarmScroll(mapID, spotsOfGroup(zone, "farm"))
end

---------------------------------------------------------------------------
-- The Farm spots list: a block per monster - its name, its place and a big red waypoint, then everything it drops (grey items too)
-- with how often and the price, and a wide space before the next monster. It scrolls.
---------------------------------------------------------------------------
local function areaAt(map, x, y)
    if C_Map.GetMapInfoAtPosition and x and y then
        local ok, info = pcall(C_Map.GetMapInfoAtPosition, map, x, y)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
    end
    return SFP:ZoneName(map)
end
SFP.AreaAt = areaAt

-- every item a monster drops, most often first: { { id, qty } }, and its kill count
local function monsterLoot(s)
    local drops, kills = {}, s.kills or 0
    local rec = s.npc and SFP.Npc and SFP:Npc(s.npc)
    if type(rec) == "table" then
        kills = math.max(kills, rec.k or 0)
        -- the same as the hover on the map: what was looted from its kills and from its body
        for _, src in ipairs({ rec.d or {}, rec.s or {} }) do
            for id, q in pairs(src) do if type(q) == "number" then drops[id] = (drops[id] or 0) + q end end
        end
    end
    for id, q in pairs(s.counts or {}) do drops[id] = math.max(drops[id] or 0, q) end
    for _, id in ipairs(s.items or {}) do if not drops[id] then drops[id] = 0 end end
    -- the items Wowhead lists for this monster (gear, bags, pets ...), also the ones nobody here has seen drop yet
    local listed = s.npc and SFP.WowheadDrops and SFP:WowheadDrops(s.npc)
    if listed then for _, id in ipairs(listed) do if not drops[id] then drops[id] = 0 end end end
    local order = {}
    for id, q in pairs(drops) do if not (SFP.IsQuestLoot and SFP.IsQuestLoot(id)) then order[#order + 1] = { id = id, q = q } end end
    table.sort(order, function(a, c)
        if a.q ~= c.q then return a.q > c.q end
        return a.id < c.id
    end)
    return order, kills
end
SFP.MonsterLoot = monsterLoot

local farmPanel
local function buildFarmPanel()
    local sc = WorldMapFrame.ScrollContainer
    local f = CreateFrame("Frame", "SeviathsUsefulToolsFarmList", WorldMapFrame, "BackdropTemplate")
    f:SetFrameStrata("HIGH")
    f:SetSize(420, 520)
    SFP.BlizzardFrame(f)
    f:SetBackdropColor(0.02, 0.03, 0.05, 0.96)
    f:SetBackdropBorderColor(0.9, 0.28, 0.24, 0.9)
    f:EnableMouse(true)
    f.head = CreateFrame("Button", nil, f)
    f.head:SetPoint("TOPLEFT", 0, 0)
    f.head:SetPoint("TOPRIGHT", 0, 0)
    f.head:SetHeight(24)
    f.title = f.head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("LEFT", 10, 0)
    f.toggle = f.head:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.toggle:SetPoint("RIGHT", -8, 0)
    f.toggle:SetText("[-]")
    f.head:SetScript("OnClick", function()
        SFP.db.spotsCollapsed = true
        SFP.RefreshWorldMap()
    end)
    f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 8, -28)
    f.scroll:SetPoint("BOTTOMRIGHT", -28, 62)
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetSize(380, 1)
    f.scroll:SetScrollChild(f.content)
    f.rows = {}
    -- the footer: route line tick box, Route, Clear, and the ten best spots
    f.foot = CreateFrame("Frame", nil, f)
    f.foot:SetPoint("BOTTOMLEFT", 0, 0)
    f.foot:SetPoint("BOTTOMRIGHT", 0, 0)
    f.foot:SetHeight(58)
    f.routeCheck = CreateFrame("CheckButton", nil, f.foot, "UICheckButtonTemplate")
    f.routeCheck:SetSize(20, 20)
    f.routeCheck:SetPoint("TOPLEFT", 6, -4)
    f.routeCheck:SetHitRectInsets(0, -60, 0, 0)
    f.routeCheck.label = f.routeCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.routeCheck.label:SetPoint("LEFT", f.routeCheck, "RIGHT", 0, 0)
    f.routeCheck.label:SetText("Route line")
    f.routeCheck:SetScript("OnClick", function(self)
        SFP.db.showRoute = self:GetChecked() and true or false
        SFP.RefreshWorldMap()
    end)
    f.route = CreateFrame("Button", nil, f.foot, "UIPanelButtonTemplate")
    f.route:SetSize(80, 22); f.route:SetPoint("TOPRIGHT", -92, -4); f.route:SetText("Route")
    f.clear = CreateFrame("Button", nil, f.foot, "UIPanelButtonTemplate")
    f.clear:SetSize(80, 22); f.clear:SetPoint("TOPRIGHT", -8, -4); f.clear:SetText("Clear")
    f.top = CreateFrame("Button", nil, f.foot, "UIPanelButtonTemplate")
    f.top:SetHeight(24); f.top:SetPoint("BOTTOMLEFT", 8, 6); f.top:SetPoint("BOTTOMRIGHT", -8, 6)
    f.top:SetText("Top 10 best spots")
    f.clear:SetScript("OnClick", function() SFP:ClearRoute() end)
    f.top:SetScript("OnClick", function() if SFP.ShowTopSpots then SFP:ShowTopSpots() end end)
    return f
end

local function farmRow(f, i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f.content)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.right = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.right:SetPoint("RIGHT", -4, 0)
    r.right:SetJustifyH("RIGHT")
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r.text:SetMaxLines(1)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    r.hl:SetBlendMode("ADD")
    r:SetScript("OnEnter", function(self)
        local t = SFP.Tip()
        t:SetOwner(self, "ANCHOR_LEFT")
        if self.item then t:SetItemByID(self.item) else t:AddLine(self.hint or "", 1, 1, 1, true) end
        t:Show()
    end)
    r:SetScript("OnLeave", function() SFP.Tip():Hide() end)
    r:SetScript("OnClick", function(self) if self.map then waypointAt(self.map, self.x, self.y, self.label) end end)
    f.rows[i] = r
    return r
end

drawFarmScroll = function(mapID, spots)
    if SFP.db.spotsCollapsed ~= false or #spots == 0 then if farmPanel then farmPanel:Hide() end return end
    if not farmPanel then farmPanel = buildFarmPanel() end
    local f = farmPanel
    f.title:SetText("|c" .. SFP.CYAN_HEX .. "Farm spots|r  |cffaaaaaa" .. SFP:ZoneName(mapID) .. "|r")
    f.routeCheck:SetChecked(SFP.db.showRoute ~= false)
    f.route:SetScript("OnClick", function() SFP:BuildRoute(mapID) end)
    local y, n = 0, 0
    local function put(h, setup)
        n = n + 1
        local r = farmRow(f, n)
        r:SetHeight(h)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", 0, -y)
        r.item, r.map, r.x, r.y, r.label, r.hint = nil, nil, nil, nil, nil, nil
        r.icon:ClearAllPoints()
        r.text:ClearAllPoints()
        r.right:SetText("")
        r.hl:Show()
        setup(r)
        r:Show()
        y = y + h
    end
    for _, s in ipairs(spots) do
        local loot, kills = monsterLoot(s)
        local x0, y0 = s.hx, s.hy
        local firstId = s.items and s.items[1]
        -- the monster: name and a big red waypoint
        put(34, function(r)
            r.icon:SetSize(26, 26); r.icon:SetPoint("LEFT", 4, 0)
            r.icon:SetTexture(firstId and SFP:ItemIcon(firstId) or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.right:SetFontObject("GameFontNormalLarge")
            r.right:SetText("|cffff3030WAYPOINT|r")
            r.text:SetFontObject("GameFontNormalLarge")
            r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
            r.text:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
            r.text:SetText("|cffe6483d" .. tostring(s.name) .. "|r")
            r.map, r.x, r.y, r.label = mapID, x0, y0, s.name
            r.hint = "Click: set a waypoint on " .. tostring(s.name)
        end)
        -- its place
        put(22, function(r)
            r.icon:SetSize(1, 1); r.icon:SetPoint("LEFT", 8, 0); r.icon:SetTexture(nil)
            r.right:SetFontObject("GameFontNormal")
            r.text:SetFontObject("GameFontHighlight")
            r.text:SetPoint("LEFT", r.icon, "RIGHT", 28, 0)
            r.text:SetPoint("RIGHT", r, "RIGHT", -4, 0)
            r.text:SetText("|cffffd100" .. areaAt(mapID, x0, y0) .. "|r  |cff808080" ..
                (x0 and string.format("%.1f, %.1f", x0 * 100, y0 * 100) or "") .. "|r")
            r.map, r.x, r.y, r.label = mapID, x0, y0, s.name
            r.hint = "Click: set a waypoint on " .. tostring(s.name)
        end)
        -- everything it drops, greys included
        for _, d in ipairs(loot) do
            put(22, function(r)
                r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", 28, 0)
                r.icon:SetTexture(SFP:ItemIcon(d.id))
                r.right:SetFontObject("GameFontHighlightSmall")
                local price = SFP:GetPrice(d.id)
                local pct = (kills >= 3 and d.q > 0) and ("|cffffd100" .. math.min(100, math.floor(d.q / kills * 1000) / 10) .. "%|r  ") or ""
                r.right:SetText(pct .. (price and SFP:FormatPrice(price) or ""))
                r.text:SetFontObject("GameFontHighlight")
                r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
                r.text:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
                r.text:SetText(SFP:ItemName(d.id))
                r.item = d.id
                r.hl:Show()
            end)
        end
        if #loot == 0 then
            put(22, function(r)
                r.icon:SetSize(1, 1); r.icon:SetPoint("LEFT", 8, 0); r.icon:SetTexture(nil)
                r.text:SetPoint("LEFT", r.icon, "RIGHT", 28, 0)
                r.text:SetPoint("RIGHT", r, "RIGHT", -4, 0)
                r.text:SetText("|cff808080no loot recorded yet|r")
                r.hl:Hide()
            end)
        end
        -- a wide space before the next monster
        put(30, function(r)
            r.icon:SetSize(1, 1); r.icon:SetPoint("LEFT", 0, 0); r.icon:SetTexture(nil)
            r.text:SetPoint("LEFT", r, "LEFT", 0, 0)
            r.text:SetText("")
            r.hl:Hide()
        end)
    end
    for i = n + 1, #f.rows do f.rows[i]:Hide() end
    f.content:SetHeight(math.max(y, 1))
    f:Show()
    if SFP.DockPanels then SFP.DockPanels() end
end

function SFP.HasCollectables(mapID)
    return #mountRows(mapID) > 0 or #petRows(mapID) > 0
end

-- the side lists sit above their button on the line below the map (see MaterialGuide.lua)
function SFP.DockPanels()
    -- every list opens like the big search window: on the right of the map, in the empty screen next to it, as tall as the map; the
    -- buttons that open them are in one line right below the map
    local function dock(panel, full)
        if not panel then return end
        if panel:GetParent() ~= WorldMapFrame then panel:SetParent(WorldMapFrame) end
        panel:SetClampedToScreen(false)
        panel:SetFrameStrata("DIALOG")   -- above the map's side tabs, which stand just outside its right edge
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", 48, 0)
        if full then panel:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMRIGHT", 48, 0) end   -- only the Farm spots list is as tall as the map
        local mr, ms = WorldMapFrame:GetRight(), WorldMapFrame:GetEffectiveScale()
        local ur, us = UIParent:GetRight(), UIParent:GetEffectiveScale()
        local ps = panel:GetEffectiveScale()
        local space = (mr and ur and ps > 0) and ((ur * us - mr * ms) / ps) or 0
        panel:SetWidth(space >= 450 and math.min(space - 52, full and 460 or 400) or 400)
    end
    dock(gatherPanel)
    dock(farmPanel, true)
    dock(spotPanel)
    dock(collPanel)
    if farmPanel then farmPanel.content:SetWidth(math.max(farmPanel:GetWidth() - 40, 300)) end
end

local function drawCollectables(mapID)
    local mr, pr = mountRows(mapID), petRows(mapID)
    if #mr == 0 and #pr == 0 then return end
    collPanel = collPanel or buildCollPanel()
    local collapsed = SFP.db.collCollapsed ~= false
    collPanel.title:SetText("|cffa335eeCollectables|r  |cffaaaaaa" .. SFP:ZoneName(mapID) .. "|r")
    collPanel.toggle:SetText(collapsed and "[+]" or "[-]")
    if collapsed then collPanel:Hide() return end
    local n = 0
    local function add(d)
        n = n + 1
        local r = collRow(collPanel, n)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 4, -20 - (n - 1) * LROW_H)
        r:SetPoint("TOPRIGHT", -4, -20 - (n - 1) * LROW_H)
        r.header = d.header
        r.item, r.map, r.x, r.y, r.label, r.lines = d.item, d.map, d.x, d.y, d.label, d.lines
        r.icon:SetTexture(d.icon)
        r.name:SetText(d.name)
        r.right:SetText(d.right or "")
        r.hl:SetShown(not d.header)
        r:Show()
    end
    if not collapsed then
        if #mr > 0 then
            add({ header = true, name = "|cffa335eeMounts|r", right = "|cff808080dungeons and raids here|r" })
            for _, d in ipairs(mr) do add(d) end
        end
        if #pr > 0 then
            add({ header = true, name = "|c" .. SFP.HUNTER_HEX .. "Hunter pets|r", right = "|cff808080tameable here|r" })
            for _, d in ipairs(pr) do add(d) end
        end
    end
    for i = n + 1, #collPanel.rows do collPanel.rows[i]:Hide() end
    collPanel:SetHeight(24 + n * LROW_H)
    collPanel:Show()
    if SFP.DockPanels then SFP.DockPanels() end
end

-- the game's own dungeon/raid circles on the map: the mounts of that instance are added to its tooltip
local pinHooked
local function hookEntrancePins()
    if pinHooked then return end
    local mix = _G.DungeonEntrancePinMixin
    if not mix or not mix.OnMouseEnter then return end
    pinHooked = true
    hooksecurefunc(mix, "OnMouseEnter", function(pin)
        pcall(function()
            local name = pin.name
            if not name and pin.journalInstanceID and EJ_GetInstanceInfo then name = EJ_GetInstanceInfo(pin.journalInstanceID) end
            if type(name) ~= "string" then return end
            local lname = name:lower()
            for _, exp in ipairs(SFP.Expansions) do
                for _, inst in ipairs(exp.instances or {}) do
                    if inst.name:lower() == lname or (inst.alias and inst.alias:lower() == lname) then
                        if GameTooltip:IsShown() and addMountLines(GameTooltip, inst) then GameTooltip:Show() end
                    end
                end
            end
        end)
    end)
end

-- A ping on the map where a waypoint was set: three bright rings that grow and fade at the spot (about four seconds), and a pin above
-- it that bounces. It shows when the map has opened at that zone.
local pingFrame
function SFP.PingSpot(map, x, y)
    if not (map and x and y) then return end
    C_Timer.After(0.4, function()
        if not (WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == map and spawnLayer) then return end
        local w, h = spawnLayer:GetWidth(), spawnLayer:GetHeight()
        if not w or w <= 0 then return end
        if not pingFrame then
            pingFrame = CreateFrame("Frame", nil, spawnLayer)
            pingFrame:SetFrameStrata("HIGH")
            pingFrame:SetSize(10, 10)
            pingFrame.rings = {}
            for i = 1, 3 do
                local t = pingFrame:CreateTexture(nil, "OVERLAY")
                t:SetTexture("Interface\\Cooldown\\ping4")
                t:SetBlendMode("ADD")
                t:SetPoint("CENTER")
                t:SetSize(40, 40)
                t:SetVertexColor(0.25, 0.6, 1, 1)
                local ag = t:CreateAnimationGroup()
                ag:SetLooping("REPEAT")
                local sc = ag:CreateAnimation("Scale")
                sc:SetScaleFrom(0.3, 0.3)
                sc:SetScaleTo(3.2, 3.2)
                sc:SetDuration(1.4)
                sc:SetStartDelay((i - 1) * 0.45)
                local al = ag:CreateAnimation("Alpha")
                al:SetFromAlpha(1)
                al:SetToAlpha(0)
                al:SetDuration(1.4)
                al:SetStartDelay((i - 1) * 0.45)
                t.ag = ag
                pingFrame.rings[i] = t
            end
            pingFrame.disc = pingFrame:CreateTexture(nil, "ARTWORK")
            pingFrame.disc:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
            pingFrame.disc:SetPoint("CENTER")
            pingFrame.disc:SetSize(54, 54)
            pingFrame.disc:SetVertexColor(0.1, 0.55, 1, 0.9)
            local dg = pingFrame.disc:CreateAnimationGroup()
            dg:SetLooping("BOUNCE")
            local ds = dg:CreateAnimation("Scale")
            ds:SetScaleFrom(0.6, 0.6); ds:SetScaleTo(1.6, 1.6); ds:SetDuration(0.55)
            local da = dg:CreateAnimation("Alpha")
            da:SetFromAlpha(1); da:SetToAlpha(0.3); da:SetDuration(0.55)
            pingFrame.disc.ag = dg
            pingFrame.pin = pingFrame:CreateTexture(nil, "OVERLAY")
            pingFrame.pin:SetAtlas("Waypoint-MapPin-Tracked")
            pingFrame.pin:SetSize(34, 34)
            pingFrame.pin:SetPoint("BOTTOM", pingFrame, "CENTER", 0, 0)
            local pg = pingFrame.pin:CreateAnimationGroup()
            pg:SetLooping("BOUNCE")
            local tr = pg:CreateAnimation("Translation")
            tr:SetOffset(0, 10)
            tr:SetDuration(0.5)
            pingFrame.pin.ag = pg
        end
        pingFrame:ClearAllPoints()
        pingFrame:SetPoint("CENTER", spawnLayer, "TOPLEFT", x * w, -y * h)
        pingFrame:Show()
        for _, t in ipairs(pingFrame.rings) do t.ag:Stop(); t.ag:Play() end
        pingFrame.pin.ag:Stop(); pingFrame.pin.ag:Play()
        pingFrame.disc.ag:Stop(); pingFrame.disc.ag:Play()
        pingFrame.token = (pingFrame.token or 0) + 1
        local token = pingFrame.token
        C_Timer.After(5, function()
            if pingFrame.token == token then
                for _, t in ipairs(pingFrame.rings) do t.ag:Stop() end
                pingFrame.pin.ag:Stop()
                pingFrame.disc.ag:Stop()
                pingFrame:Hide()
            end
        end)
    end)
end

-- A click on the waypoint pin on the map, with either mouse button, removes it (a button laid over the pin, shown while the map is on
-- the waypoint's zone)
local wpButton
local function updateWaypointButton()
    local show = false
    -- the waypoint's place on the map being viewed: it is also shown on the maps around the one it was set on (a region, a neighbour
    -- zone), so the position is asked for the viewed map
    local viewed = WorldMapFrame:GetMapID()
    local pos = viewed and C_Map.GetUserWaypointPositionForMap and C_Map.GetUserWaypointPositionForMap(viewed)
    local wp
    if pos then
        local px, py = pos:GetXY()
        wp = { position = { x = px, y = py } }
    else
        local w0 = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
        if w0 and w0.position and w0.uiMapID == viewed then wp = w0 end
    end
    if WorldMapFrame:IsShown() and spawnLayer and wp and wp.position then
        local w, h = spawnLayer:GetWidth(), spawnLayer:GetHeight()
        if w and w > 0 then
            if not wpButton then
                wpButton = CreateFrame("Button", nil, spawnLayer)
                wpButton:SetFrameStrata("HIGH")
                wpButton:SetFrameLevel(spawnLayer:GetFrameLevel() + 50)
                wpButton:SetSize(44, 44)
                wpButton:RegisterForClicks("AnyUp")
                -- any button, on the press (not the release): the map's own handling of the mouse cannot take it first
                wpButton:RegisterForClicks("AnyDown", "AnyUp")
                local function remove(self)
                    local ok, err = pcall(function()
                        if C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
                        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(false) end
                    end)
                    if not ok then SFP:Print("Could not remove the waypoint: " .. tostring(err)) return end
                    self:Hide()
                    SFP.Tip():Hide()
                    SFP:Print("Waypoint removed.")
                end
                wpButton:SetScript("OnClick", remove)
                wpButton:SetScript("OnEnter", function(self)
                    SFP.Tip():SetOwner(self, "ANCHOR_RIGHT")
                    SFP.Tip():AddLine("Waypoint", 1, 0.2, 0.2)
                    SFP.Tip():AddLine("Click (either button): remove it", 1, 1, 1)
                    SFP.Tip():Show()
                end)
                wpButton:SetScript("OnLeave", function() SFP.Tip():Hide() end)
            end
            local x, y = wp.position.x, wp.position.y
            wpButton:ClearAllPoints()
            wpButton:SetPoint("CENTER", spawnLayer, "TOPLEFT", x * w, -y * h)   -- the pin is drawn centred on its place
            wpButton:Show()
            show = true
        end
    end
    if wpButton and not show then wpButton:Hide() end
end
SFP.UpdateWaypointButton = updateWaypointButton
do
    local wf = CreateFrame("Frame")
    wf:RegisterEvent("USER_WAYPOINT_UPDATED")
    wf:SetScript("OnEvent", function() C_Timer.After(0.1, function() pcall(updateWaypointButton) end) end)
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
refresh = function()
    if not overlay or not SFP.db or not SFP.zoneByMap then return end
    releaseAll()
    clearSpawns()
    panel:Hide()
    if gatherPanel then gatherPanel:Hide() end
    if spotPanel then spotPanel:Hide() end
    if farmPanel then farmPanel:Hide() end
    if collPanel then collPanel:Hide() end
    hookEntrancePins()
    for _, e in ipairs(edges) do e:Hide() end
    if WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() and SFP.QuestMarkers then
        SFP:Safe("quest zones", SFP.QuestMarkers.DrawZones, SFP.QuestMarkers, WorldMapFrame:GetMapID())
    end
    pcall(updateWaypointButton)
    if not SFP.db.mapOverlay or not WorldMapFrame:IsShown() then return end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end
    if SFP._pingMap ~= mapID then SFP._pingMap = mapID; SFP._pingUntil = GetTime() + 5 end
    if SFP.db.showDungeons or SFP.db.showRaids then drawInstances(mapID) end
    if SFP.db.showGatherList then
        local info = C_Map.GetMapInfo(mapID)
        local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
        if SFP.zoneByMap[mapID] or (info and info.mapType == zoneType) then drawGatherList(mapID) end
    end
    if SFP.db.showSpotList and SFP.zoneByMap[mapID] then SFP:Safe("spot list", drawSpotList, mapID) end
    SFP:Safe("farm lists", drawFarmLists, mapID)
    SFP:Safe("collectables", drawCollectables, mapID)

    if SFP.db.spotsCollapsed == false then drawRoute(mapID) end   -- the route line shows only while the Farm spots menu is open
    if SFP.zoneByMap[mapID] then
        -- inside a farm zone
        if SFP:IsValuableZone(mapID) then
            if SFP.db.showSpawns or SFP.db.showRares or SFP.db.showHunter or SFP.db.showSpecial then drawZoneSpawns(mapID) end
            -- the shipped herb and ore nodes are not drawn any more: the map shows the nodes you gathered (Treasures.lua)
            if SFP.db.zoneFill then for _, e in ipairs(edges) do e:Show() end end
            if SFP.db.zonePanel then fillPanel(mapID); panel:Show() end
        end
    else
        -- continent / bigger map: small spots at the farm locations
        -- spots only on the zone maps (close view); the continent / world view stays clean
        if SFP.db.continentSpots then
            if SFP.db.showSpawns or SFP.db.showRares or SFP.db.showHunter or SFP.db.showSpecial then drawContinentSpots(mapID) end
        end
        if SFP.db.zoneFill then
            for zoneID in pairs(SFP.zoneByMap) do
                if SFP:IsValuableZone(zoneID) and isUnder(zoneID, mapID) then drawZoneFill(mapID, zoneID) end
            end
        end
    end
end
SFP.RefreshWorldMap = refresh

function SFP.SetRoute(mapID, pts)
    SFP.route = (mapID and pts) and { map = mapID, pts = pts } or nil
    refresh()
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
SFP:OnLogin(function()
    local canvas = WorldMapFrame:GetCanvas()
    local c = C()

    overlay = CreateFrame("Frame", nil, canvas)
    overlay:SetAllPoints(canvas)
    overlay:SetFrameLevel(canvas:GetFrameLevel() + 10)
    pool, labels = {}, {}

    spawnLayer = CreateFrame("Frame", nil, canvas)
    spawnLayer:SetAllPoints(canvas)
    -- high frame level: stay above other map addons' overlays
    spawnLayer:SetFrameLevel(math.min(canvas:GetFrameLevel() + 3000, 9000))
    -- no pulsing: the spots stay calm and pale
    spawnLayer:SetAlpha(0.85)

    local sc = WorldMapFrame.ScrollContainer
    edges = {}
    local function edge(p1, p2, horiz)
        local t = sc:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(c.r, c.g, c.b, 0.8)
        t:SetPoint(p1); t:SetPoint(p2)
        if horiz then t:SetHeight(3) else t:SetWidth(3) end
        t:Hide()
        edges[#edges + 1] = t
    end
    edge("TOPLEFT", "TOPRIGHT", true)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge("TOPLEFT", "BOTTOMLEFT", false)
    edge("TOPRIGHT", "BOTTOMRIGHT", false)

    panel = CreateFrame("Frame", "SeviathsUsefulToolsZonePanel", sc, "BackdropTemplate")
    panel:SetWidth(240)
    panel:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -10, -10)
    panel:SetFrameStrata("HIGH")
    SFP.BlizzardFrame(panel)
    panel:SetBackdropColor(0, 0.05, 0.08, 0.95)
    panel:SetBackdropBorderColor(c.r, c.g, c.b, 0.9)
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", 8, -7)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() panel:Hide() end)
    panel:Hide()

    tip = CreateFrame("GameTooltip", "SeviathsUsefulToolsMapTip", UIParent, "GameTooltipTemplate")
    tip:SetFrameStrata("TOOLTIP")

    local watcher = CreateFrame("Frame", nil, WorldMapFrame)
    watcher:SetScript("OnUpdate", onUpdate)

    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", refresh) end
    WorldMapFrame:HookScript("OnShow", function() C_Timer.After(0, refresh) end)
    WorldMapFrame:HookScript("OnHide", function() if tip then tip:Hide() end; lastHover, lastSpot = nil, nil end)
    canvas:HookScript("OnSizeChanged", refresh)

    SFP:OnRefresh(refresh)
end)
