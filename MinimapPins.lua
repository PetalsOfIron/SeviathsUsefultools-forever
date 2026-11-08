-- SeviathsUsefulTools - spots on the minimap
--
-- The same farm spots, rares, hunter tames, special materials and gathering nodes as on the world
-- map, drawn on the minimap around you. Only the spots near you are drawn.
-- With HereBeDragons-Pins (the library Questie, RareScanner and others share) it follows rotation,
-- zoom and any minimap shape set by Leatrix, BasicMinimap and similar addons. Without it the spots
-- are placed here, from the map size, the minimap zoom and the minimap rotation.
--

local ADDON, SFP = ...

local RANGE = 0.12          -- map units around the player (about the minimap view)
local MAXPINS = 90
local TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local HBD
local pool, shown = {}, {}
local currentMap
local lostTicks, lastGood = 0, nil

local function safe(fn, ...)
    local ok, a = pcall(fn, ...)
    if ok then return a end
end

local function getHBD()
    if HBD then return HBD end
    if LibStub then HBD = LibStub("HereBeDragons-Pins-2.0", true) end
    return HBD
end

local function color(s)
    if SFP.SpotColor then return SFP.SpotColor(s) end
    return SFP.CYAN
end

local function acquire()
    local f = table.remove(pool)
    if f then return f end
    f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(12, 12)
    f.outer = f:CreateTexture(nil, "BACKGROUND")
    f.outer:SetAllPoints()
    f.outer:SetTexture(TEX)
    f.outer:SetBlendMode("BLEND")   -- additive glow was far too bright on the dark minimap
    f.inner = f:CreateTexture(nil, "ARTWORK")
    f.inner:SetSize(5, 5)
    f.inner:SetPoint("CENTER")
    f.inner:SetTexture(TEX)
    f.inner:SetBlendMode("BLEND")
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        local s = self.spot
        if not s then return end
        SFP.Tip():SetOwner(self, "ANCHOR_LEFT")
        SFP.Tip():AddLine(s.name or "?", color(s).r, color(s).g, color(s).b)
        local tag = s.gather and ("best zone for " .. (s.gather == "ore" and "ore" or "herbs"))
            or (s.hunter and "hunter tame") or (s.rare and "rare") or (s.special and "special material") or "farm spot"
        SFP.Tip():AddLine(tag, 0.8, 0.8, 0.8)
        if self.cl and #self.cl.order > 1 then
            for i, o in ipairs(self.cl.order) do
                if i > 6 then SFP.Tip():AddLine("+" .. (#self.cl.order - 6) .. " more", 0.6, 0.6, 0.6); break end
                if i > 1 then SFP.Tip():AddLine(o.name or "?", color(o).r, color(o).g, color(o).b) end
            end
        end
        for i, id in ipairs(s.items or {}) do
            if i > 5 then break end
            SFP.Tip():AddLine("|T" .. SFP:ItemIcon(id) .. ":12|t " .. SFP:ItemName(id))
        end
        if s.note and s.note ~= "" then SFP.Tip():AddLine(s.note, 0.6, 0.6, 0.6, true) end
        SFP.Tip():AddLine(string.format("%.1f, %.1f", self.px * 100, self.py * 100), 1, 0.82, 0)
        SFP.Tip():Show()
    end)
    f:SetScript("OnLeave", function() SFP.Tip():Hide() end)
    return f
end

local function release(key)
    local f = shown[key]
    if not f then return end
    local h = getHBD()
    if h then pcall(h.RemoveMinimapIcon, h, SFP, f) end
    f:Hide()
    f.spot = nil
    pool[#pool + 1] = f
    shown[key] = nil
end

---------------------------------------------------------------------------
-- without HereBeDragons: place the spots on the minimap ourselves
---------------------------------------------------------------------------
-- minimap diameter in yards per zoom level (outdoors)
local OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }

local mapSize = {}   -- [mapID] = { width yards, height yards } or false
local function sizeOf(mapID)
    local s = mapSize[mapID]
    if s ~= nil then return s end
    s = false
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local _, a = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
        local _, bx = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 0))
        local _, by = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 1))
        if a and bx and by then
            local w = math.sqrt((bx.x - a.x) ^ 2 + (bx.y - a.y) ^ 2)
            local h = math.sqrt((by.x - a.x) ^ 2 + (by.y - a.y) ^ 2)
            if w > 0 and h > 0 then s = { w, h } end
        end
    end
    mapSize[mapID] = s
    return s
end

local function viewRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local r = C_Minimap.GetViewRadius()
        if type(r) == "number" and r > 0 then return r end
    end
    return (OUTDOOR[Minimap:GetZoom() or 0] or OUTDOOR[3]) / 2
end

-- move every drawn spot to where it belongs around the minimap centre
local function placeOwn()
    if getHBD() or not next(shown) then return end
    local size = currentMap and sizeOf(currentMap)
    local pos = currentMap and C_Map.GetPlayerMapPosition(currentMap, "player")
    local px, py
    if pos and pos.GetXY then px, py = pos:GetXY() end
    if issecretvalue and (issecretvalue(px) or issecretvalue(py)) then px, py = nil, nil end
    if not size or not px or px <= 0 then
        -- the game sometimes has no position for a moment while you move: keep the pins where they are for a few seconds
        if not lastGood or GetTime() - lastGood > 4 then
            for _, f in pairs(shown) do f:Hide() end
        end
        return
    end
    lastGood = GetTime()
    local rotate = (C_CVar and C_CVar.GetCVar or GetCVar)("rotateMinimap") == "1"
    local face = rotate and GetPlayerFacing() or 0
    local cs, sn = math.cos(face), math.sin(face)
    local radius = viewRadius()
    local scale = (Minimap:GetWidth() / 2) / radius
    for _, f in pairs(shown) do
        local ex = (f.px - px) * size[1]     -- yards east
        local ny = -(f.py - py) * size[2]    -- yards north
        local x, y = ex * cs + ny * sn, -ex * sn + ny * cs
        -- hide a little outside, show again a little inside: a pin at the rim does not blink while you walk
        local d2, r2 = x * x + y * y, radius * radius
        if d2 > r2 * 0.99 or (f.rimHidden and d2 > r2 * 0.93) then
            f.rimHidden = true
            f:Hide()
        else
            f.rimHidden = nil
            f:ClearAllPoints()
            f:SetPoint("CENTER", Minimap, "CENTER", x * scale, y * scale)
            f:Show()
        end
    end
end

local function clearAll()
    for key in pairs(shown) do release(key) end
end

local function update()
    local h = getHBD()
    if not SFP.db or not SFP.db.minimapSpots or not SFP.db.mapOverlay or not SFP.zoneByMap then
        clearAll()
        return
    end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local px, py
    if pos and pos.GetXY then px, py = pos:GetXY() end
    if issecretvalue and (issecretvalue(px) or issecretvalue(py)) then px, py = nil, nil end
    local zone = mapID and SFP.zoneByMap[mapID]
    if not zone or not px or px <= 0 or not zone.spawns then
        -- a moment without a position or zone (walking over a sub-zone border) is not a reason to wipe the pins:
        -- they go only when it lasts a few seconds
        lostTicks = lostTicks + 1
        if lostTicks >= 4 then clearAll() end
        return
    end
    lostTicks = 0
    if currentMap ~= mapID then clearAll(); currentMap = mapID end

    local wanted, n = {}, 0
    -- farm spots, rares, specials and hunter tames: the same circles and markers as on the world map
    for _, c in ipairs(SFP.SpotClusters and SFP.SpotClusters(zone) or {}) do
        local dx, dy = c.x - px, c.y - py
        local reach = RANGE + (c.rad or 0)
        if dx * dx + dy * dy < reach * reach then
            n = n + 1
            if n > MAXPINS then break end
            wanted[("%s:%d:%d"):format(c.cat, math.floor(c.x * 1000), math.floor(c.y * 1000))] = { c.order[1], { c.x, c.y }, c }
        end
    end
    for si, s in ipairs(zone.spawns) do
        if s.gather and s.points and SFP.ShowSpot and SFP.ShowSpot(s) then
            for pi, p in ipairs(s.points) do
                local dx, dy = p[1] - px, p[2] - py
                if dx * dx + dy * dy < RANGE * RANGE then
                    n = n + 1
                    if n > MAXPINS then break end
                    wanted[si .. ":" .. pi] = { s, p }
                end
            end
        end
        if n > MAXPINS then break end
    end
    for key in pairs(shown) do
        if not wanted[key] then release(key) end
    end
    -- circles keep their size as the minimap zooms: radius in yards -> pixels
    local msize = sizeOf(mapID)
    local pxPerYard = msize and (Minimap:GetWidth() / 2) / viewRadius() or nil
    for key, f in pairs(shown) do
        local e = wanted[key]
        local cl = e and e[3]
        f.cl = cl
        if cl and cl.rad and msize and pxPerYard then
            local d = math.max(10, 2 * cl.rad * msize[1] * pxPerYard)
            f:SetSize(d, d)
        else
            f:SetSize(12, 12)
        end
    end
    for key, e in pairs(wanted) do
        if not shown[key] then
            local s, p = e[1], e[2]
            local f = acquire()
            local c = color(s)
            f.spot, f.px, f.py, f.cl = s, p[1], p[2], e[3]
            if e[3] and e[3].rad and msize and pxPerYard then
                local d = math.max(10, 2 * e[3].rad * msize[1] * pxPerYard)
                f:SetSize(d, d)
            else
                f:SetSize(12, 12)
            end
            f.outer:SetVertexColor(c.r, c.g, c.b, 0.5)
            f.inner:SetVertexColor(c.r * 0.5 + 0.5, c.g * 0.5 + 0.5, c.b * 0.5 + 0.5, 0.7)
            if h then
                f:Show()
                local ok = pcall(h.AddMinimapIconMap, h, SFP, f, mapID, p[1], p[2], false, false)
                if ok then shown[key] = f else f:Hide(); pool[#pool + 1] = f end
            elseif sizeOf(mapID) then
                f:SetParent(Minimap)
                f:SetFrameLevel(Minimap:GetFrameLevel() + 5)
                shown[key] = f   -- placeOwn() puts it on the minimap
            else
                pool[#pool + 1] = f
            end
        end
    end
    if not h then placeOwn() end
end

local ticker
SFP:OnLogin(function()
    local f = CreateFrame("Frame")
    local acc = 0
    f:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 1 then return end
        acc = 0
        SFP:Safe("minimap spots", update)
    end)
    -- a map refresh no longer wipes every pin (that made them blink): update() adds and removes only what changed
    SFP:OnRefresh(function() acc = 1 end)
    -- no HereBeDragons: keep the spots on the move with the player
    local move = CreateFrame("Frame")
    local acc2 = 0
    move:SetScript("OnUpdate", function(_, dt)
        acc2 = acc2 + dt
        if acc2 < 0.05 then return end
        acc2 = 0
        if next(shown) then SFP:Safe("minimap spots move", placeOwn) end
    end)
end)
