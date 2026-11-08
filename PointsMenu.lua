-- SeviathsUsefulTools - the points menu of the world map
--
-- A small button under the map's own pin buttons (top right of the world map) opens a small menu: each kind of point the addon draws (rares, hunter pets,
-- special materials, mining, herbs, and all the treasure chests) can be switched on or off.

local _, SFP = ...

local KINDS = {
    { "showRares",     "Rares",             true },
    { "showHunter",    "Hunter pets",       false },
    { "showSpecial",   "Special materials", false },
    { "showMining",    "Mining nodes",      false },
    { "showHerbs",     "Herb nodes",        false },
    { "showTreasures", "Treasures (all chests)", true },
}

local function isOn(key, default)
    local v = SFP.db and SFP.db[key]
    if v == nil then return default end
    return v and true or false
end

local function redraw()
    SFP.hiddenVer = (SFP.hiddenVer or 0) + 1   -- the cached marker areas are made again
    if SFP.RefreshWorldMap then SFP.RefreshWorldMap() end
    if SFP.RefreshTreasures then SFP.RefreshTreasures() end
end

local function toggleKind(key, default)
    if not SFP.db then return end
    SFP.db[key] = not isOn(key, default)
    redraw()
end

-- one point of the zone: hidden spots are kept by the same key the map uses (db.hiddenSpots), treasures by their object id (db.hiddenTreasures)
local function spotHidden(s)
    local key = SFP.SpotKey and SFP.SpotKey(s)
    return key and SFP.db and SFP.db.hiddenSpots and SFP.db.hiddenSpots[key]
end

local function toggleSpot(s)
    local key = SFP.SpotKey and SFP.SpotKey(s)
    if not (key and SFP.db) then return end
    SFP.db.hiddenSpots = SFP.db.hiddenSpots or {}
    SFP.db.hiddenSpots[key] = (not SFP.db.hiddenSpots[key]) or nil
    redraw()
end

local function spotLabel(s)
    local first = s.items and s.items[1]
    local icon = first and ("|T" .. SFP:ItemIcon(first) .. ":14|t ") or ""
    return icon .. tostring(s.name)
end

local function addSpots(sub, list)
    for _, s in ipairs(list) do
        sub:CreateCheckbox(spotLabel(s), function() return not spotHidden(s) end, function() toggleSpot(s) end)
    end
end

local function openMenu(button)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local map = WorldMapFrame:GetMapID()
    MenuUtil.CreateContextMenu(button, function(_, root)
        root:CreateTitle("Seviaths - points on the map")
        for _, k in ipairs(KINDS) do
            local key, label, default = k[1], k[2], k[3]
            root:CreateCheckbox(label, function() return isOn(key, default) end, function() toggleKind(key, default) end)
        end
    end)
end

SFP:OnLogin(function()
    if not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
    local b = CreateFrame("Button", "SeviathsUsefulToolsPointsButton", WorldMapFrame)
    b:SetSize(32, 32)
    b:SetFrameStrata("HIGH")
    b:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 40)
    -- under the map's own pin buttons: the tracking options button when the game has it, else the top right corner of the map
    local anchor = _G.WorldMapTrackingOptionsButton
    if anchor and anchor.GetObjectType then
        b:SetPoint("TOP", anchor, "BOTTOM", 0, -6)
    else
        b:SetPoint("TOPRIGHT", WorldMapFrame.ScrollContainer, "TOPRIGHT", -8, -90)
    end
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local cy = SFP.CYAN or { r = 0, g = 0.9, b = 1 }
    b.bg:SetVertexColor((cy.r or 0) * 0.4, (cy.g or 0.9) * 0.4, (cy.b or 1) * 0.5, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER")
    b.icon:SetSize(20, 20)
    b.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetAllPoints()
    b.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:SetScript("OnClick", function(self) openMenu(self) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Seviaths - points on the map")
        GameTooltip:AddLine("Switch each kind of point, and every point of this zone, on or off.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Show()
end)
