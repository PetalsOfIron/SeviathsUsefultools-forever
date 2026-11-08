-- SeviathsUsefulTools - Core
-- Shared helpers, saved settings, price lookups, Wowhead links, slash commands.

local ADDON, SFP = ...
_G.SeviathsUsefulTools = SFP
SFP.RETAIL = true -- this build is for the retail game (Midnight)

-- The game's own tables are never written to when they already have what we need: writing to
-- a Blizzard table (even with the same value) taints it and breaks protected actions such as
-- right-clicking an item in the bags (ADDON_ACTION_FORBIDDEN). Only a missing piece is filled in.
if not _G.C_Item then _G.C_Item = {} end
if not C_Item.GetItemInfo then C_Item.GetItemInfo = GetItemInfo end
if not C_Item.GetItemIconByID then C_Item.GetItemIconByID = GetItemIcon end
if not C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID = function(id) GetItemInfo(id) end end

-- Merged modules (Codex, Dungeons & Raids, Guild Helper) each get their own private
-- table; ADDON is the Farm Pack's name so their ADDON_LOADED checks still match.
local modules = {}
function SFP_Module(name)
    modules[name] = modules[name] or {}
    return ADDON, modules[name]
end

-- Every internal error is kept (and shown once through the normal error handler, so BugSack
-- sees it): /sfp errors prints them.
SFP.errors = {}
local seenErr = {}
function SFP:CatchError(where, err)
    local msg = where .. ": " .. tostring(err)
    if seenErr[msg] then return end
    seenErr[msg] = true
    self.errors[#self.errors + 1] = msg
    local h = geterrorhandler and geterrorhandler()
    if h then h(msg) end
end
function SFP:Safe(where, fn, ...)
    local n, args = select("#", ...), { ... }
    local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, function(e)
        return tostring(e) .. (debugstack and ("\n" .. debugstack(2, 8, 0)) or "")
    end)
    if not ok then self:CatchError(where, err) end
    return ok
end

local function meta(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(ADDON, field) or nil
end
SFP.NAME    = "SeviathsUsefulTools"
SFP.VERSION = meta("Version") or "dev"
SFP.AUTHOR  = meta("Author") or "Seviath"

SFP.CYAN = { r = 1, g = 0.82, b = 0 }   -- the gold of the game's own titles


-- the word WAYPOINT in a row of a list is a real red button (the look of the map buttons): the row's text is written as before, the word is taken out of it and
-- the button shown at the right edge; pressing it does what a click on the row does
function SFP.AttachWaypointButton(r)
    if not r or not r.right or r.wpButton then return end
    local btn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
    btn:SetSize(84, 18)
    btn:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    btn:SetText("Waypoint")
    btn:SetScript("OnClick", function()
        if r.click then r.click(r)
        else local h = r:GetScript("OnClick"); if h then h(r) end end
    end)
    btn:Hide()
    r.wpButton = btn
    local fs = r.right
    local raw = fs.SetText
    fs.SetText = function(self, text)
        if type(text) == "string" and text:find("WAYPOINT", 1, true) then
            local rest = text:gsub("|c%x%x%x%x%x%x%x%x?WAYPOINT|r", ""):gsub("WAYPOINT", ""):gsub("^%s+", ""):gsub("%s+$", "")
            btn:Show()
            self:ClearAllPoints()
            self:SetPoint("RIGHT", btn, "LEFT", -8, 0)
            raw(self, rest)
        else
            btn:Hide()
            self:ClearAllPoints()
            self:SetPoint("RIGHT", r, "RIGHT", -6, 0)
            raw(self, text)
        end
    end
end

-- the look of the windows: the dark dialog background of the game (red tinted), a red tooltip-style border, and the snake in a corner
local SNAKE = "Interface\\AddOns\\SeviathsUsefulTools\\Media\\snake_tile.tga"
-- opens the game's own Looking For Group window (the call that does it differs between versions of the game: the first one that exists is used)
function SFP.OpenGroupFinder()
    for _, name in ipairs({ "PVEFrame_ToggleFrame", "ToggleLFGParentFrame", "ToggleLFDParentFrame", "LFGParentFrame_Toggle", "ToggleGroupFinder" }) do
        local fn = _G[name]
        if type(fn) == "function" and pcall(fn) then return true end
    end
    for _, name in ipairs({ "PVEFrame", "LFGParentFrame", "LFGListFrame" }) do
        local fr = _G[name]
        if fr and fr.Show then
            local ok = pcall(function() if fr:IsShown() then fr:Hide() else fr:Show() end end)
            if ok then return true end
        end
    end
    SFP:Print("Could not open the Looking For Group window: open it with its key (default I).")
end

function SFP.BlizzardFrame(f, big)
    if not f or not f.SetBackdrop then return end
    if big == "inset" then
        -- a panel inside a window: the game's own inset art (the rock background and the inset frame of the quest log / map)
        f:SetBackdrop(nil)
        if not f.seviathMarble then
            local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
            bg:SetAllPoints()
            bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
            bg:SetHorizTile(true)
            bg:SetVertTile(true)
            bg:SetVertexColor(0.62, 0.62, 0.62, 1)   -- darker, like the inset of the quest log
            f.seviathMarble = bg
            local ok = NineSliceUtil and NineSliceUtil.ApplyLayoutByName and pcall(NineSliceUtil.ApplyLayoutByName, f, "InsetFrameTemplate")
            if not ok then
                f:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
                f:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
            end
            f.SetBackdropColor = function() end
            f.SetBackdropBorderColor = function() end
        end
        return
    end
    if big == "small" then
        -- a small window (the farm session controls): the marble of the game's windows with a gold edge
        f:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropBorderColor(0.8, 0.65, 0.3, 1)
        if not f.seviathBase then
            local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
            bg:SetPoint("TOPLEFT", 3, -3)
            bg:SetPoint("BOTTOMRIGHT", -3, 3)
            bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble", "REPEAT", "REPEAT")
            bg:SetHorizTile(true)
            bg:SetVertTile(true)
            f.seviathBase = bg
            f.SetBackdropColor = function() end
            f.SetBackdropBorderColor = function() end
        end
        return
    end
    if not big then
        -- a small frame (a button, a row, a panel): flat and red
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0.09, 0.04, 0.04, 0.95)
        f:SetBackdropBorderColor(0.9, 0.28, 0.24, 0.8)
        return
    end
    -- a window: the game's own frame art, the way the quest log and the map are made: the marble background and the metal frame (nine slice), and the
    -- snake in a corner. Later color calls on a window (old per-window tints) are ignored.
    f:SetBackdrop(nil)
    if not f.seviathBase then
        local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints()
        bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble", "REPEAT", "REPEAT")
        bg:SetHorizTile(true)
        bg:SetVertTile(true)
        f.seviathBase = bg
        local ok = NineSliceUtil and NineSliceUtil.ApplyLayoutByName and pcall(NineSliceUtil.ApplyLayoutByName, f, "ButtonFrameTemplateNoPortrait")
        if not ok then
            f:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
        end
        f.SetBackdropColor = function() end
        f.SetBackdropBorderColor = function() end
    end
    -- the window's title sits on the top bar of the frame
    -- (the title is made after the frame is styled, so it is placed a moment later)
    -- the close (X) button sits in the top bar of the frame like the game's own windows, in every window of the addon
    C_Timer.After(0, function()
        for _, c in ipairs({ f:GetChildren() }) do
            if c.GetObjectType and c:GetObjectType() == "Button" and c.GetNormalTexture then
                local nt = c:GetNormalTexture()
                local path = nt and nt.GetTexture and nt:GetTexture()
                if type(path) == "string" and path:find("MinimizeButton", 1, true) then
                    c:ClearAllPoints()
                    c:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, 5)
                end
            end
        end
    end)
    C_Timer.After(0, function()
        for _, key in ipairs({ "title", "header", "Title" }) do
            local t = rawget(f, key)
            if type(t) == "table" and t.GetObjectType and t:GetObjectType() == "FontString" then
                -- a title at the top left: a little higher, onto the bar (the other texts stay where they are)
                local p, rel, rp, x, y = t:GetPoint(1)
                if p == "TOPLEFT" and type(y) == "number" and y <= -6 and y >= -14 and not t.seviathNudged then
                    t.seviathNudged = true
                    t:SetPoint(p, rel, rp, x, y + 5)
                end
            end
        end
    end)
    if not f.seviathSnake then
        local tex = f:CreateTexture(nil, "BACKGROUND", nil, 2)
        tex:SetTexture(SNAKE)
        tex:SetSize(190, 190)
        tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
        tex:SetVertexColor(0.95, 0.2, 0.18)
        tex:SetAlpha(0.22)
        f.seviathSnake = tex
    end
end
SFP.CYAN_HEX = "ffffd100"
SFP.WOWHEAD_ITEM = "https://www.wowhead.com/item=%d"

local defaults = {
    mapOverlay   = true,   -- cyan zones on the world map
    zonePanel    = false,  -- optional item panel when viewing a farm zone
    zoneFill     = false,  -- optional: light whole zones instead of just the farm spots
    showSpawns   = false,  -- cyan farm monster spots (off at the start: only rares are on, turn the rest on in the map's layer menu)
    showRares    = false,  -- orange glowing rare spawns (mounts, pets, toys)
    showHunter   = false,  -- green hunter tames (spirit beasts, unique-look pets)
    showMining   = false,  -- (off at the start) best zone for each ore (amber glow)
    showHerbs    = false,  -- (off at the start, everyone can turn it on) best zone for each herb (mint glow)
    showDungeons = false,  -- (off at the start) dungeon entrance icons with their loot
    showRaids    = false,  -- (off at the start) raid entrance icons with their loot
    showLabels   = false,  -- name / coordinate text next to the markers (off: info only on hover)
    showSpecial  = false,  -- magenta spots for special materials (rare hides, lures, special cloth)
    showGatherList = true, -- side list on zone maps: the expansion's ores/herbs + their best zone
    showRoute = true,      -- draw the farm route (spot list: Route button) on the map
    autoGroupComp = true,  -- open the group makeup by itself in a group of 5 or more
    zoneCheck = true,      -- one line about what you still miss when you enter a zone
    greyKilled = true,     -- grey out rares you killed today on the map
    rareAlerts = true,     -- chat line when a rare you still miss something from appears nearby
    rareAlertSound = true, -- and a sound with it
    showSpotList = true,   -- side list on zone maps: every farm spot of the zone, each one can be switched off
    spotsCollapsed = true,
    hiddenSpots  = {},     -- [spot key] = true: switched off in the spot list (map and minimap)
    showUnconfirmed = true, -- possible BoEs from guides that may have changed (listed separately)
    learn        = true,   -- remember where you loot farm materials / BoEs and show those spots
    continentSpots = false, -- spots on continent / world maps (off: only on zone maps)
    exactSpots   = true,   -- one exact marker per spawn point instead of merged areas
    minimapSpots = true,   -- farm spots / rares / nodes on the minimap too
    npcs         = {},     -- [npcID] = learned monster (Collector.lua)
    knownItems   = {},     -- [itemID] = learned item
    objects      = {},     -- [objectID] = learned gathering node
    recipes      = {},     -- ["Profession|Recipe"] = crafting recipe with its reagents
    itemZones    = {},     -- [itemID][uiMapID] = { l = looted here, q = quest reward here } (ItemInfo.lua)
    learned      = {},     -- [uiMapID][npcID] = { name, kills, items = {[itemID]=count}, pts = {{x,y}} }
    mapMenu      = { open = false },
    minimap      = { hide = false, angle = 215 },
    minimapGlow  = true,   -- button pulses cyan inside a farm zone
    tooltip      = true,   -- add farm info + Wowhead link line to item tooltips
    minValue     = 0,      -- copper; only light zones whose best item is worth at least this
    rescanHours  = 12,     -- the auction bar shows prices older than this as old
    prices       = {},     -- [itemID] = { p = copper per unit, t = time() }: newest price seen on any realm
    realmPrices  = {},     -- [realm key][itemID] = { p, t }: what each character's auction house showed
    realmScan    = {},     -- [realm key] = time of the last scan there
    lastScan     = 0,
    browser      = { exp = 1, sortByValue = false },
}

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- every window of the addon lives in one layer and comes to the front when it opens or is clicked
function SFP.RegisterWindow(f)
    if not f or f.SeviathsFront or not f.HookScript then return end
    f.SeviathsFront = true
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    if f.SetToplevel then f:SetToplevel(true) end
    -- raise now and again a moment later: the click that opened the window can raise the menu above it afterwards
    -- every window remembers where you put it and opens exactly there next time
    local name = f.GetName and f:GetName()
    if name then
        local function savePos(self)
            if not SFP.db then return end
            local point, _, rel, x, y = self:GetPoint()
            if point then
                SFP.db.windowPos = SFP.db.windowPos or {}
                SFP.db.windowPos[name] = { point, rel or "CENTER", x, y }
            end
        end
        f:HookScript("OnDragStop", savePos)
        f:HookScript("OnHide", savePos)
        f:HookScript("OnShow", function(self)
            local pos = SFP.db and SFP.db.windowPos and SFP.db.windowPos[name]
            if pos then
                self:ClearAllPoints()
                self:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
            end
        end)
    end
    f:HookScript("OnShow", function(self)
        self:Raise()
        C_Timer.After(0, function() if self:IsShown() then self:Raise() end end)
        C_Timer.After(0.15, function() if self:IsShown() then self:Raise() end end)
    end)
    f:HookScript("OnMouseDown", function(self) self:Raise() end)
end

-- Our own tooltip for our own frames (map spots, menus, minimap). Using the shared GameTooltip from addon code
-- taints it, and Blizzard's map pins and widgets then fail with 'execution tainted by SeviathsUsefulTools'.
local ownTip
function SFP.Tip()
    if not ownTip then
        ownTip = CreateFrame("GameTooltip", "SeviathsUsefulToolsTip", UIParent, "GameTooltipTemplate")
        ownTip:SetFrameStrata("TOOLTIP")
    end
    return ownTip
end

function SFP:Print(msg)
    print("|c" .. self.CYAN_HEX .. "SeviathsUsefulTools|r: " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Indexes built from the shipped data
---------------------------------------------------------------------------
function SFP:BuildIndex()
    self.zoneByMap   = {}   -- [uiMapID] = zone entry
    self.zoneExp     = {}   -- [uiMapID] = expansion entry
    self.itemSources = {}   -- [itemID] = { "Zone/Instance label", ... }
    self.trackedIDs  = {}   -- [itemID] = true (incl. crafting tiers)

    local function addSource(itemID, label)
        local list = self.itemSources[itemID]
        if not list then list = {}; self.itemSources[itemID] = list end
        for _, l in ipairs(list) do if l == label then return end end
        list[#list + 1] = label
    end

    local function track(itemID)
        self.trackedIDs[itemID] = true
        local info = self.Items[itemID]
        if info and info.tiers then
            for _, t in ipairs(info.tiers) do self.trackedIDs[t] = true end
        end
    end

    for _, exp in ipairs(self.Expansions) do
        for _, zone in ipairs(exp.zones) do
            self.zoneByMap[zone.map] = zone
            self.zoneExp[zone.map] = exp
            zone.instances = zone.instances or {}
            for _, id in ipairs(zone.items) do
                track(id)
                addSource(id, self:ZoneName(zone.map))
            end
        end
        for _, inst in ipairs(exp.instances or {}) do
            local zone = self.zoneByMap[inst.map]
            if not zone then -- instance in a zone with no other farm: list the zone anyway
                zone = { map = inst.map, items = {}, instances = {}, rareOnly = true }
                table.insert(exp.zones, zone)
                self.zoneByMap[inst.map] = zone
                self.zoneExp[inst.map] = exp
            end
            table.insert(zone.instances, inst)
            inst.exp = exp
            for _, id in ipairs(inst.items) do
                track(id)
                addSource(id, inst.name)
            end
        end
        for _, id in ipairs(exp.anywhere or {}) do
            track(id)
            addSource(id, exp.name .. " (any zone)")
        end
    end

    -- parse "x,y;x,y" spawn strings and find the busiest spot for the label
    local function parsePoints(sp)
        local pts = {}
        for x, y in sp.pts:gmatch("([%d%.]+),([%d%.]+)") do
            pts[#pts + 1] = { tonumber(x) / 100, tonumber(y) / 100 }
        end
        if #pts == 0 then return false end
        local best, bestN = pts[1], -1
        for _, a in ipairs(pts) do
            local n = 0
            for _, b in ipairs(pts) do
                local dx, dy = a[1] - b[1], a[2] - b[2]
                if dx * dx + dy * dy < 0.0016 then n = n + 1 end -- within 4 map units
            end
            if n > bestN then best, bestN = a, n end
        end
        sp.points, sp.hx, sp.hy = pts, best[1], best[2]
        return true
    end

    -- monster spawn points (Data/Spawns.lua): add their items to the zone
    for mapID, list in pairs(self.Spawns or {}) do
        local zone = self.zoneByMap[mapID]
        if zone and not zone.spawns then
            zone.spawns = {}
            for _, sp in ipairs(list) do
                if parsePoints(sp) then
                    for _, id in ipairs(sp.items) do
                        local info = self.Items[id]
                        if info and info.kind == "boe" then sp.grind = true end
                        if info and info.special then sp.special = true end
                    end
                    zone.spawns[#zone.spawns + 1] = sp
                    for _, id in ipairs(sp.items) do
                        local have = false
                        for _, z in ipairs(zone.items) do if z == id then have = true; break end end
                        if not have then table.insert(zone.items, id) end
                        track(id)
                        addSource(id, self:ZoneName(mapID))
                    end
                end
            end
        end
    end

    -- best farm spot per creature material = the mob with the most spawn points
    local bestN, bestSp = {}, {}
    for _, zone in pairs(self.zoneByMap) do
        for _, sp in ipairs(zone.spawns or {}) do
            for _, id in ipairs(sp.items) do
                if #sp.points > (bestN[id] or 0) then bestN[id], bestSp[id] = #sp.points, sp end
            end
        end
    end
    for id, sp in pairs(bestSp) do
        sp.bestFor = sp.bestFor or {}
        table.insert(sp.bestFor, id)
    end

    -- mining / herbalism (Data/Gathering.lua): one spot per ore/herb in its best zone
    local expByKey = {}
    for _, exp in ipairs(self.Expansions) do expByKey[exp.key] = exp end
    self.gatherByExp = {}
    for _, g in ipairs(self.Gather or {}) do
        local list = self.gatherByExp[g.exp]
        if not list then list = {}; self.gatherByExp[g.exp] = list end
        list[#list + 1] = g
        track(g.item)
    end
    for _, g in ipairs(self.Gather or {}) do
      if not g.listOnly then
        local zone = self.zoneByMap[g.map]
        local exp = expByKey[g.exp]
        if not zone and exp then
            zone = { map = g.map, items = {}, instances = {}, rareOnly = true }
            table.insert(exp.zones, zone)
            self.zoneByMap[g.map] = zone
            self.zoneExp[g.map] = exp
        end
        if zone and not g.done then
            g.done = true
            local sp = { name = g.name, items = { g.item }, pts = g.pts, gather = g.kind, nodes = g.nodes, bestFor = { g.item } }
            if parsePoints(sp) then
                zone.spawns = zone.spawns or {}
                zone.spawns[#zone.spawns + 1] = sp
                local have = false
                for _, z in ipairs(zone.items) do if z == g.item then have = true; break end end
                if not have then table.insert(zone.items, g.item) end
                track(g.item)
                addSource(g.item, self:ZoneName(g.map) .. " (best zone)")
            end
        end
      end
    end

    -- notable rares (Data/Rares.lua): shown as orange spots; zones that only
    -- have rares are added to their expansion so they light up too
    for mapID, list in pairs(self.Rares or {}) do
        local zone = self.zoneByMap[mapID]
        local exp = expByKey[list.exp]
        if not zone and exp then
            zone = { map = mapID, items = {}, instances = {}, rareOnly = true }
            table.insert(exp.zones, zone)
            self.zoneByMap[mapID] = zone
            self.zoneExp[mapID] = exp
        end
        if zone and not zone.rareDone then
            zone.rareDone = true
            zone.spawns = zone.spawns or {}
            for _, sp in ipairs(list) do
                if parsePoints(sp) then
                    -- hunter tames get their own symbol/colour instead of the rare look
                    sp.rare = not sp.hunter
                    -- worth grinding = drops something collectible or sellable
                    for _, id in ipairs(sp.items) do
                        local info = self.Items[id]
                        if info and (info.kind == "mount" or info.kind == "pet" or info.kind == "toy" or info.kind == "boe") then
                            sp.grind = true
                        end
                    end
                    zone.spawns[#zone.spawns + 1] = sp
                    for _, id in ipairs(sp.items) do addSource(id, sp.name) end
                end
            end
        end
    end
end

-- which expansion a map belongs to, for any zone (also ones with no farm data):
-- known zones first, then the continent it sits on. Cataclysm / TBC / Midnight
-- zones placed on the old continents are listed explicitly.
local CONTINENT_EXP = {
    [12] = "classic", [13] = "classic", [101] = "tbc", [113] = "wrath", [948] = "cata", [424] = "mop",
    [572] = "wod", [619] = "legion", [905] = "legion", [875] = "bfa", [876] = "bfa", [1550] = "sl",
    [1978] = "df", [2274] = "tww",
}
local ZONE_EXP = {
    -- Cataclysm zones on the old continents
    [198] = "cata", [201] = "cata", [203] = "cata", [204] = "cata", [205] = "cata", [207] = "cata",
    [241] = "cata", [244] = "cata", [245] = "cata", [249] = "cata", [174] = "cata", [194] = "cata", [217] = "cata",
    -- Burning Crusade blood elf / draenei zones
    [94] = "tbc", [95] = "tbc", [97] = "tbc", [103] = "tbc", [106] = "tbc", [110] = "tbc", [122] = "tbc",
    -- Midnight
    [2393] = "midnight", [2395] = "midnight", [2405] = "midnight", [2413] = "midnight", [2424] = "midnight", [2437] = "midnight",
}
function SFP:ExpansionForMap(mapID)
    if self.zoneExp and self.zoneExp[mapID] then return self.zoneExp[mapID] end
    local byKey = {}
    for _, exp in ipairs(self.Expansions) do byKey[exp.key] = exp end
    if ZONE_EXP[mapID] then return byKey[ZONE_EXP[mapID]] end
    -- maps added with Midnight (e.g. The Coiled Isle) sit under the old continents:
    -- every map ID from Midnight's range on belongs to Midnight
    if mapID >= 2393 then return byKey.midnight end
    local m, guard = mapID, 0
    while m and guard < 6 do
        if CONTINENT_EXP[m] then return byKey[CONTINENT_EXP[m]] end
        local info = C_Map.GetMapInfo(m)
        m = info and info.parentMapID
        guard = guard + 1
    end
    return nil
end

function SFP:AddItemSource(itemID, label)
    local list = self.itemSources[itemID]
    if not list then list = {}; self.itemSources[itemID] = list end
    for _, l in ipairs(list) do if l == label then return end end
    list[#list + 1] = label
end

function SFP:ZoneName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or ("Map " .. mapID)
end

-- Random green/blue BoE gear: any mob can drop it, so it is shown as one
-- general line per zone. Level range comes from the game (zones scale).
SFP.RANDOM_BOE_COLOR = "|cff1eff00"
function SFP:RandomBoeText(mapID)
    local text = "|cff1eff00Random green|r & |cff0070ddblue|r BoE gear"
    local lo, hi
    if C_Map.GetMapLevels then lo, hi = C_Map.GetMapLevels(mapID) end
    if lo and hi and hi > 0 then
        if lo == hi then return text, "any mob, lvl " .. lo end
        return text, "any mob, lvl " .. lo .. "-" .. hi
    end
    return text, "any mob in this zone"
end

---------------------------------------------------------------------------
-- Prices
---------------------------------------------------------------------------
-- Returns copper per unit (cheapest crafting tier for Dragonflight reagents)
-- connected realms share one auction house: key = all of them, sorted
local realmKey
local groupsSaved
function SFP:RealmKey()
    if realmKey then
        if not groupsSaved and self.db then
            groupsSaved = true
            self.db.realmGroups = self.db.realmGroups or {}
            for r in realmKey:gmatch("[^,]+") do self.db.realmGroups[r] = realmKey end
        end
        return realmKey
    end
    local list
    if GetAutoCompleteRealms then
        local ok, r = pcall(GetAutoCompleteRealms)
        if ok and type(r) == "table" and #r > 0 then list = { unpack(r) } end
    end
    if not list then
        local n = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName())
        if not n or n == "" then return "unknown" end
        list = { n }
    end
    table.sort(list)
    realmKey = table.concat(list, ",")
    -- WoW Forever has one big server split into four kinds (Normal, PvP, Roleplay, Roleplay PvP): each kind has its own auction house, so its own
    -- prices and its own shipped gold data, named by the kind
    if WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then
        local nm = tostring(list[1] or "")
        local kind = nm:find("RPPVP$") and "RPPVP" or nm:find("RP$") and "RP" or nm:find("PVP$") and "PVP" or "Normal"
        local old = realmKey
        realmKey = "Forever" .. kind
        -- what was saved under the old realm key moves to the kind
        if self.db and self.db.realmPrices and self.db.realmPrices[old] and not self.db.realmPrices[realmKey] then
            self.db.realmPrices[realmKey] = self.db.realmPrices[old]
            self.db.realmPrices[old] = nil
        end
        if self.db and self.db.realmScan and self.db.realmScan[old] and not self.db.realmScan[realmKey] then
            self.db.realmScan[realmKey] = self.db.realmScan[old]
            self.db.realmScan[old] = nil
        end
        list = { realmKey }
    end
    -- every realm of this group is remembered with its group (db.realmGroups): shipped with the addon, so a player who logs into a realm
    -- someone else played knows which realms share its auction house and which shipped prices are its own
    if self.db then
        self.db.realmGroups = self.db.realmGroups or {}
        for _, r in ipairs(list) do self.db.realmGroups[r] = realmKey end
    end
    return realmKey
end

-- the price list of this character's realm (made on first use)
function SFP:RealmPrices()
    local rp = self.db.realmPrices
    local key = self:RealmKey()
    rp[key] = rp[key] or {}
    return rp[key]
end

function SFP:LastScan()
    return (self.db.realmScan and self.db.realmScan[self:RealmKey()]) or 0
end

-- remember a price: for this realm, and as the newest price seen anywhere
function SFP:StorePrice(itemID, copper, fromOtherAddon)
    if not itemID or not copper or copper <= 0 then return end
    -- a price from this addon's own scan stays until the next scan; one copied from Auctionator / TSM is marked and may be refreshed
    local rec = { p = copper, t = time(), ext = fromOtherAddon or nil }
    self:RealmPrices()[itemID] = rec
    self.db.prices[itemID] = { p = copper, t = rec.t, ext = fromOtherAddon or nil }
    -- remember how the price moves (for "typical price" in the BoE deals list): a sample when it changed or every 6 h
    local all = self.db.priceHist
    if not all then all = {}; self.db.priceHist = all end
    local realm = self:RealmKey()
    all[realm] = all[realm] or {}
    -- a history is one flat list { price1, time1, price2, time2, ... } (a table per sample used a lot of memory: 190,000 of them)
    local list = all[realm][itemID]
    if not list then list = {}; all[realm][itemID] = list end
    if type(list[1]) == "table" then list = SFP.FlatHistory(list); all[realm][itemID] = list end
    local lastP, lastT = list[#list - 1], list[#list]
    if not lastP or math.abs(lastP - copper) > lastP * 0.02 or rec.t - lastT > 21600 then
        list[#list + 1] = copper
        list[#list + 1] = rec.t
        if #list > 28 then table.remove(list, 1); table.remove(list, 1) end
    end
end

-- an older history ({ {p=, t=}, ... }) as the flat list
function SFP.FlatHistory(old)
    local flat = {}
    for _, s in ipairs(old) do
        if type(s) == "table" and s.p then flat[#flat + 1] = s.p; flat[#flat + 1] = s.t or 0 end
    end
    return flat
end

-- the old histories are turned into flat lists in the background (a few thousand per step)
function SFP:CompactPriceHist()
    local all = self.db and self.db.priceHist
    if not all then return end
    local jobs = {}
    for realm, items in pairs(all) do
        local ids = {}
        for id, list in pairs(items) do if type(list) == "table" and type(list[1]) == "table" then ids[#ids + 1] = id end end
        if #ids > 0 then jobs[#jobs + 1] = { items = items, ids = ids, i = 1 } end
    end
    local j = 1
    local function step()
        local job = jobs[j]
        if not job then return end
        for n = job.i, math.min(#job.ids, job.i + 2999) do
            local id = job.ids[n]
            job.items[id] = SFP.FlatHistory(job.items[id])
        end
        job.i = job.i + 3000
        if job.i > #job.ids then j = j + 1 end
        C_Timer.After(0.05, step)
    end
    step()
end

-- a price from Auctionator or TradeSkillMaster, whichever has one (nil when neither is installed / knows the item)
-- the Settings page can switch Auctionator and TradeSkillMaster prices off
function SFP:ExternalOn(src)
    if src == "Auctionator" then return self.db.useAuctionator ~= false end
    if src == "TradeSkillMaster" then return self.db.useTSM ~= false end
    return self.db.useAuctionator ~= false or self.db.useTSM ~= false   -- older saved prices without a name
end

function SFP:ExternalPrice(id)
    if self.db.useAuctionator ~= false and Auctionator and Auctionator.API and Auctionator.API.v1 then
        local ok, v = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ADDON, id)
        if ok and type(v) == "number" and v > 0 then return v, "Auctionator" end
    end
    if self.db.useTSM ~= false and TSM_API and TSM_API.GetCustomPriceValue then
        for _, src in ipairs({ "DBMinBuyout", "DBMarket", "DBRegionMarketAvg" }) do
            local ok, v = pcall(TSM_API.GetCustomPriceValue, src, "i:" .. id)
            if ok and type(v) == "number" and v > 0 then return v, "TradeSkillMaster" end
        end
    end
end

-- the cheapest listings of a recipe product from the last fast scan: { n = how many are listed, p = { cheapest first, up to 6 } }
function SFP:Listings(itemID)
    local all = self.db.ahListings
    local realm = all and all[self:RealmKey()]
    return realm and realm[itemID] or nil
end

-- does an item sell at the auction house? From what happened to the auctions of it (AuctionSold.lua; the data of other players ships with the addon):
-- true = it sold, false = it never sold (its auctions ran out and came back in the mailbox), nil = nothing known. A gray item is never judged (it is
-- worth its vendor price).
function SFP:SoldState(itemID)
    if type(itemID) ~= "number" then return nil end
    if C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID) == 0 then return true end
    local all = self.db and self.db.ahOutcome
    local function state(id)
        local o = all and all[id]
        if type(o) ~= "table" then return nil end
        if (o.s or 0) > 0 then return true end
        if (o.e or 0) > 0 then return false end
    end
    local st = state(itemID)
    if st ~= nil then return st end
    local info = self.Items and self.Items[itemID]
    if info and info.tiers then
        local any
        for _, t in ipairs(info.tiers) do
            local ts = state(t)
            if ts == true then return true end
            if ts == false then any = false end
        end
        return any
    end
    return nil
end

-- the little text after an item of a monster's loot: "sold" / "never sold" (nothing for a gray item or an item nothing is known about)
function SFP.SoldTag(itemID)
    local st = SFP:SoldState(itemID)
    if st == nil then return "" end
    if C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID) == 0 then return "" end
    return st and "|cff40ff40sold|r  " or "|cffff6040never sold|r  "
end

-- the price of every item of the last whole-auction-house scan on this realm: [itemID] = copper (compact, replaced by each fast scan)
function SFP:AllPrices(create)
    local all = self.db.ahAll
    if not all then
        if not create then return nil end
        all = {}
        self.db.ahAll = all
    end
    local realm = self:RealmKey()
    if not all[realm] and create then all[realm] = {} end
    return all[realm]
end

-- the price of an item by its NAME, from the item names the scans saved: crafted gear and other items that have several item IDs
-- (one per quality) are found this way too; the cheapest one counts
function SFP:PriceByName(name)
    if type(name) ~= "string" or name == "" then return nil end
    if not self._nameIdx then
        local idx = {}
        for id, nm in pairs(self.db.ahNames or {}) do
            if type(nm) == "string" then
                local k = nm:lower()
                local l = idx[k]
                if not l then l = {}; idx[k] = l end
                l[#l + 1] = id
            end
        end
        self._nameIdx = idx
    end
    local ids = self._nameIdx[name:lower()]
    if not ids then return nil end
    local best
    for _, id in ipairs(ids) do
        local p = self:GetPrice(id)
        if p and (not best or p < best) then best = p end
    end
    return best
end

-- the price shipped with the addon (collected/gold.<realm>.lua: prices scanned on the author's realms): this realm group's, else a part of
-- it, else any shipped realm (prices of other servers are usually close). Returns copper and the time it was scanned.
-- the realms that share an auction house with this one, from the shipped list (compared without spaces, apostrophes and hyphens)
local connIndex
local function plain(s) return (tostring(s):gsub("[%s'-]", "")) end
function SFP:ConnectedWith(realm)
    if not connIndex then
        connIndex = {}
        for _, g in ipairs(self.ConnectedRealms or {}) do
            local names = {}
            for i = 2, #g do names[#names + 1] = g[i] end
            for _, n in ipairs(names) do connIndex[plain(n)] = names end
        end
    end
    return connIndex[plain(realm)] or {}
end

-- a shipped price list is stored as long texts ("id,price;id,price;..."); the table is made only for the list this player uses
local function shippedP(R)
    if not R.p then
        local p = {}
        for _, text in ipairs(R.s or {}) do
            for k, v in text:gmatch("(%d+),(%d+);") do p[tonumber(k)] = tonumber(v) end
        end
        R.p, R.s = p, nil
    end
    return R.p
end

local shippedRealm, shippedFreed
function SFP:ShippedPriceTime(id)
    local _, t = self:ShippedPrice(id)
    return t
end
-- the name of the shipped price list in use for this realm (nil when none)
function SFP:ShippedRealmName()
    self:ShippedPrice(0)   -- makes the choice
    local G = _G.SeviathsUsefulToolsGold
    if not (G and shippedRealm) then return nil end
    for name, r in pairs(G) do if r == shippedRealm then return name end end
end

function SFP:ShippedPrice(id)
    local G = _G.SeviathsUsefulToolsGold
    if not G then return nil end
    if shippedRealm == nil then
        local key = self:RealmKey()
        shippedRealm = G[key] or false
        if not shippedRealm then
            -- connected realms share one auction house: a shipped group that has any realm of this player's group (or the other way round)
            -- is the same auction house, whichever of its realms was scanned
            local mine = {}
            for part in tostring(key):gmatch("[^,]+") do
                mine[plain(part)] = true
                -- the realms known to share its auction house (learned by any player of the addon, shipped in realmGroups)
                local grp = self.db and self.db.realmGroups and self.db.realmGroups[part]
                for other in tostring(grp or ""):gmatch("[^,]+") do mine[plain(other)] = true end
                -- and the list shipped for all regions (Data/ConnectedRealms.lua)
                for _, other in ipairs(self:ConnectedWith(part)) do mine[plain(other)] = true end
            end
            for gkey, r in pairs(G) do
                for part in tostring(gkey):gmatch("[^,]+") do
                    if mine[plain(part)] then shippedRealm = r break end
                end
                if shippedRealm then break end
            end
        end
        if not shippedRealm then
            -- the nearest guess: the shipped realm with the most prices
            local bestN = 0
            for _, r in pairs(G) do
                local n = r.n or 0
                if n > bestN then bestN, shippedRealm = n, r end
            end
            shippedRealm = shippedRealm or false
        end
    end
    -- the price lists of the other realms are not needed in this session: their texts are released (only this realm's list and the
    -- region's commodity list stay)
    if shippedRealm and not shippedFreed then
        shippedFreed = true
        local region0 = GetCurrentRegion and GetCurrentRegion()
        local keep = ({ [1] = "REGION_US", [2] = "REGION_KR", [3] = "REGION_EU", [4] = "REGION_TW" })[region0 or 0]
        for name, r in pairs(G) do
            if r ~= shippedRealm and name ~= keep then r.s, r.p = nil, nil end
        end
    end
    local rec = shippedRealm and shippedP(shippedRealm)[id]
    if rec then return rec, shippedRealm.t end
    -- commodities (materials, consumables, reagents) are one price list for the whole region: the region's file covers every realm of it
    local region = GetCurrentRegion and GetCurrentRegion()
    local regionKey = ({ [1] = "REGION_US", [2] = "REGION_KR", [3] = "REGION_EU", [4] = "REGION_TW" })[region or 0]
    local rr = regionKey and G[regionKey]
    local rrec = rr and shippedP(rr)[id]
    if rrec then return rrec, rr.t end
end

function SFP:GetPrice(itemID)
    -- a gray item is worth what a vendor pays for it: the auction price is ignored
    if itemID and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID) == 0 then
        local sell = select(11, C_Item.GetItemInfo(itemID))
        return (type(sell) == "number" and sell > 0) and sell or nil
    end
    local best
    local here = self:RealmPrices()
    local everything = self:AllPrices()
    local function consider(id)
        -- this realm's own price first; else the newest price any character saw
        local rec = here[id]
        if not rec and everything and everything[id] then rec = { p = everything[id] } end   -- seen by a whole-auction-house scan
        if rec and rec.ext and not self:ExternalOn(rec.ext) then rec = nil end   -- a copied price of a source you switched off
        if not rec or (rec.ext and time() - (rec.t or 0) > 3600) then
            local v, src = self:ExternalPrice(id)
            if v then
                self:StorePrice(id, v, src or true)
                rec = here[id]
            end
        end
        rec = rec or self.db.prices[id]
        if rec and rec.ext and not self:ExternalOn(rec.ext) then rec = nil end
        -- the shipped price fills in an item this player never scanned; a price from his own scan stays until his next scan (a newer shipped price
        -- never replaces it)
        if not rec then
            local sp = self:ShippedPrice(id)
            if sp then rec = { p = sp, t = self:ShippedPriceTime(id) } end
        end
        local p = rec and rec.p
        if p and (not best or p < best) then best = p end
    end
    consider(itemID)
    local info = self.Items[itemID]
    if info and info.tiers then
        for _, t in ipairs(info.tiers) do consider(t) end
    end
    return best
end

-- how many of an item fit in one stack (nil when the game does not know the item yet)
function SFP:StackCount(itemID)
    local info = C_Item and C_Item.GetItemInfo
    if not info then return nil end
    local ok, _, _, _, _, _, _, _, stack = pcall(info, itemID)
    if ok and type(stack) == "number" and stack > 0 then return stack end
    return nil
end

-- the chance of an item from a monster, from your own kills, short: "12% 1/8 chance" = 12%, one in 8 kills. It is worked out from the saved drops and kills each time
-- it is shown, so it changes every time the item drops; nothing until the monster was killed 3 times (the number of kills you made is never shown).
function SFP.ChanceText(count, kills, minKills, word)
    if type(count) ~= "number" or type(kills) ~= "number" or count <= 0 or kills < (minKills or 3) then return "" end
    local pct = math.min(100, count / kills * 100)
    local oneIn = math.max(1, math.floor(kills / count + 0.5))
    local p = pct >= 10 and string.format("%d", math.floor(pct + 0.5)) or string.format("%.1f", pct)
    -- word: what is counted - "pickup" for a chest or a cache ("33% 1/3 pickup chance"); nothing for a monster ("33% 1/3 chance")
    local label
    if oneIn <= 1 then label = "every " .. (word or "kill") else label = "1/" .. oneIn .. (word and (" " .. word) or "") end
    return "|cffffd100" .. p .. "%|r |cff808080" .. label .. " chance|r"
end

function SFP:FormatPrice(copper)
    if not copper then return "|cff808080no AH data|r" end
    if GetMoneyString then return GetMoneyString(copper, true) end
    return string.format("%dg", math.floor(copper / 10000))
end

-- Best single-item value in a list of itemIDs
function SFP:ListValue(items)
    local best = 0
    for _, id in ipairs(items) do
        local p = self:GetPrice(id)
        if p and p > best then best = p end
    end
    return best
end

function SFP:ZoneValue(zone)
    local v = self:ListValue(zone.items)
    for _, inst in ipairs(zone.instances or {}) do
        v = math.max(v, self:ListValue(inst.items))
    end
    return v
end

-- A zone glows cyan if it is in the data and passes the value filter
function SFP:IsValuableZone(mapID)
    local zone = self.zoneByMap and self.zoneByMap[mapID]
    if not zone then return false end
    local minV = self.db.minValue or 0
    if minV <= 0 then return true end
    return self:ZoneValue(zone) >= minV
end

---------------------------------------------------------------------------
-- Item display helpers
---------------------------------------------------------------------------
function SFP:ItemName(itemID)
    local name, _, quality = C_Item.GetItemInfo(itemID)
    if not name then
        C_Item.RequestLoadItemDataByID(itemID)
        return "|cff808080item " .. itemID .. "|r", nil
    end
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    local hex = color and color.hex or "|cffffffff"
    return hex .. name .. "|r", quality
end

-- the icon of an item is kept in the saved data (db.itemIcon, shipped with the collected data), so lists show it before the game has
-- loaded the item
function SFP:StoreIcon(itemID)
    if not (self.db and itemID) then return nil end
    local icon = C_Item.GetItemIconByID(itemID)
    if type(icon) == "number" and not (issecretvalue and issecretvalue(icon)) then
        local t = self.db.itemIcon
        if not t then t = {}; self.db.itemIcon = t end
        if t[itemID] ~= icon then t[itemID] = icon end
        return icon
    end
end

function SFP:ItemIcon(itemID)
    local icon = self:StoreIcon(itemID)
    if icon then return icon end
    local kept = self.db and self.db.itemIcon and self.db.itemIcon[itemID]
    if kept then return kept end
    -- a shipped gray item (Wowhead's list) carries its icon name
    local rec = self.db and self.db.knownItems and self.db.knownItems[itemID]
    if type(rec) == "table" and rec.ic then return "Interface\\Icons\\" .. rec.ic end
    return 134400
end

function SFP:ItemExtra(itemID)
    local info = self.Items[itemID]
    if not info then return nil end
    local parts = {}
    local icon = self.KindIconTag and self:KindIconTag(info.kind, 12) or ""
    if icon ~= "" then parts[#parts + 1] = icon .. " |cff9d9d9d" .. (self.KindLabel[info.kind] or "") .. "|r" end
    if info.drop then parts[#parts + 1] = "|cffffd100drop " .. info.drop .. "|r" end
    if info.note then parts[#parts + 1] = "|cffaaaaaa" .. info.note .. "|r"
    elseif self.KindHow and self.KindHow[info.kind] then parts[#parts + 1] = "|cff808080" .. self.KindHow[info.kind] .. "|r" end
    if #parts == 0 then return nil end
    return table.concat(parts, "  ")
end

---------------------------------------------------------------------------
-- Waypoints
---------------------------------------------------------------------------
function SFP:SetWaypoint(mapID, x, y, label)
    if not (C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapID)) then
        self:Print("Can't place a waypoint on that map.")
        return
    end
    -- clicking the same waypoint again removes it
    local cur = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    if cur and cur.uiMapID == mapID and cur.position
        and math.abs(cur.position.x - x) < 0.001 and math.abs(cur.position.y - y) < 0.001 then
        C_Map.ClearUserWaypoint()
        self:Print("Waypoint removed.")
        return
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    self:Print(string.format("Waypoint set: %s %.1f, %.1f", label or self:ZoneName(mapID), x * 100, y * 100))
    -- show the waypoint: open the world map on the map it is on
    if not InCombatLockdown() then
        pcall(self.OpenMapTo, self, mapID)
        C_Timer.After(0.15, function() pcall(SFP.FlashMapSpot, SFP, mapID, x, y) end)
    end
end

-- a click (left or right) on the waypoint pin of the world map removes it (the pin is hooked, not replaced)
local function hookWaypointPins()
    if not (WorldMapFrame and WorldMapFrame.EnumeratePinsByTemplate) then return end
    local ok, iter, a, b = pcall(WorldMapFrame.EnumeratePinsByTemplate, WorldMapFrame, "UserWaypointPinTemplate")
    if not ok or not iter then return end
    for _, pin in iter, a, b do
        if pin and pin.HookScript and not pin.sfpRightClick then
            pin.sfpRightClick = true
            if pin.EnableMouse then pcall(pin.EnableMouse, pin, true) end
            pin:HookScript("OnMouseUp", function(self, button)
                if (button == "RightButton" or button == "LeftButton") and C_Map.ClearUserWaypoint then
                    C_Map.ClearUserWaypoint()
                    SFP:Print("Waypoint removed.")
                end
            end)
        end
    end
end
local wpf = CreateFrame("Frame")
wpf:RegisterEvent("USER_WAYPOINT_UPDATED")
wpf:SetScript("OnEvent", function()
    C_Timer.After(0.2, function() pcall(hookWaypointPins) end)
end)
if WorldMapFrame and WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow", function() C_Timer.After(0.3, function() pcall(hookWaypointPins) end) end)
end

-- a pulsing ring on the world map at the waypoint, for a few seconds, so it is easy to find
local flash
function SFP:FlashMapSpot(mapID, x, y)
    local canvas = WorldMapFrame and WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
    if not (canvas and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() == mapID) then return end
    if not flash then
        flash = CreateFrame("Frame", nil, canvas)
        flash:SetSize(64, 64)
        flash:SetFrameStrata("TOOLTIP")
        flash.rings = {}
        for i = 1, 2 do
            local t = flash:CreateTexture(nil, "OVERLAY")
            t:SetTexture("Interface\\Minimap\\Ping\\ping2")
            t:SetVertexColor(0.1, 0.45, 1)
            t:SetPoint("CENTER")
            t:SetSize(96, 96)
            local ag = t:CreateAnimationGroup()
            ag:SetLooping("REPEAT")
            local sc = ag:CreateAnimation("Scale")
            sc:SetScaleFrom(0.3, 0.3); sc:SetScaleTo(2.6, 2.6); sc:SetDuration(1.1); sc:SetStartDelay((i - 1) * 0.55)
            local al = ag:CreateAnimation("Alpha")
            al:SetFromAlpha(1); al:SetToAlpha(0); al:SetDuration(1.1); al:SetStartDelay((i - 1) * 0.55)
            t.ag = ag
            flash.rings[i] = t
        end
        local dot = flash:CreateTexture(nil, "OVERLAY")
        dot:SetTexture("Interface\\Minimap\\Ping\\ping2")
        dot:SetVertexColor(0.1, 0.45, 1)
        dot:SetSize(28, 28)
        dot:SetPoint("CENTER")
        -- a bouncing arrow above the spot for the first seconds
        local arrow = flash:CreateTexture(nil, "OVERLAY")
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("NPE_ArrowDown") then
            arrow:SetAtlas("NPE_ArrowDown")
        else
            arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
        end
        arrow:SetDesaturated(true)
        arrow:SetVertexColor(0.1, 0.45, 1)
        arrow:SetSize(44, 44)
        arrow:SetPoint("BOTTOM", flash, "CENTER", 0, 10)
        local bag = arrow:CreateAnimationGroup()
        bag:SetLooping("BOUNCE")
        local tr = bag:CreateAnimation("Translation")
        tr:SetOffset(0, 16); tr:SetDuration(0.35)
        flash.arrow, flash.arrowAnim = arrow, bag
        flash:EnableMouse(true)
        flash:SetScript("OnMouseUp", function(self, button)
            if (button == "RightButton" or button == "LeftButton") and C_Map.ClearUserWaypoint then
                C_Map.ClearUserWaypoint()
                SFP:Print("Waypoint removed.")
                self.untilT = 0
            end
        end)
        flash:SetScript("OnUpdate", function(self)
            if self.arrow and GetTime() > (self.arrowT or 0) then self.arrow:Hide(); self.arrowAnim:Stop() end
            if GetTime() > (self.untilT or 0) or not WorldMapFrame:IsShown() or WorldMapFrame:GetMapID() ~= self.mapID then
                self:Hide()
                for _, t in ipairs(self.rings) do t.ag:Stop() end
            end
        end)
    end
    flash:SetParent(canvas)
    flash:ClearAllPoints()
    flash:SetPoint("CENTER", canvas, "TOPLEFT", x * canvas:GetWidth(), -y * canvas:GetHeight())
    flash.mapID, flash.untilT, flash.arrowT = mapID, GetTime() + 8, GetTime() + 4
    flash.arrow:Show(); flash.arrowAnim:Play()
    flash:Show()
    for _, t in ipairs(flash.rings) do t.ag:Play() end
end

function SFP:OpenMapTo(mapID)
    if not WorldMapFrame:IsShown() then
        if ToggleWorldMap then ToggleWorldMap() else WorldMapFrame:Show() end
    end
    WorldMapFrame:SetMapID(mapID)
end

-- Instance entrances are read from the game's own Encounter Journal data,
-- so the coordinates are always the live ones.
function SFP:FindEntrance(inst)
    if inst._entrance ~= nil then return inst._entrance or nil end
    inst._entrance = false
    local function fromDatabase()
        local q = self.QuestieEntrance and (self:QuestieEntrance(inst.name) or (inst.alias and self:QuestieEntrance(inst.alias)))
        if q then inst._entrance = { map = q.map, x = q.x, y = q.y }; return inst._entrance end
        return nil
    end
    if not (C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap) then return fromDatabase() end
    local want = { [inst.name:lower()] = true }
    if inst.alias then want[inst.alias:lower()] = true end
    local maps = { inst.map }
    if inst.entranceMap then table.insert(maps, 1, inst.entranceMap) end
    for _, m in ipairs(maps) do
        local list = C_EncounterJournal.GetDungeonEntrancesForMap(m)
        for _, e in ipairs(list or {}) do
            if e.name and want[e.name:lower()] and e.position then
                local x, y = e.position:GetXY()
                inst._entrance = { map = m, x = x, y = y }
                return inst._entrance
            end
        end
    end
    return fromDatabase()
end

---------------------------------------------------------------------------
-- Wowhead link popup
---------------------------------------------------------------------------
StaticPopupDialogs["SEVIATHSUSEFULTOOLS_WOWHEAD"] = {
    text = "Wowhead link for %s\nPress Ctrl+C to copy:",
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 320,
    OnShow = function(self, data)
        local eb = (self.GetEditBox and self:GetEditBox()) or self.editBox or self.EditBox
        if eb then
            eb:SetText(data or "")
            eb:SetFocus()
            eb:HighlightText()
        end
    end,
    EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(eb) eb:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function SFP:ShowWowhead(itemID)
    local name = C_Item.GetItemInfo(itemID) or ("item " .. itemID)
    StaticPopup_Show("SEVIATHSUSEFULTOOLS_WOWHEAD", name, nil, string.format(self.WOWHEAD_ITEM, itemID))
end

---------------------------------------------------------------------------
-- Item tooltip line
---------------------------------------------------------------------------
local function OnItemTooltip(tooltip, data)
    -- a gray item (and the monsters that drop it) is in the load-on-demand data: it is read now, for the first one shown
    do
        local id0 = data and data.id
        if type(id0) == "number" and not (issecretvalue and issecretvalue(id0)) and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id0) == 0 and SFP.LoadMonsterData then
            pcall(SFP.LoadMonsterData, SFP)
        end
    end
    if not SFP.db or not SFP.db.tooltip then return end
    local itemID = data and data.id
    -- weapons and armor: the transmog line (where the look comes from, for which classes, and where you looted it yourself)
    if type(itemID) == "number" and not (issecretvalue and issecretvalue(itemID)) and SFP.TransmogItem then
        local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, itemID)
        if ok and (classID == 2 or classID == 4) then
            local tm = SFP:TransmogItem(itemID)
            if tm and tm.source then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cffa335eeTransmog|r  " .. tm.source .. (tm.sourceName and (": " .. tm.sourceName) or ""), 0.8, 0.8, 0.8, true)
                if tm.classes then tooltip:AddLine("For: " .. table.concat(tm.classes, ", "), 0.8, 0.8, 0.8, true) end
                local from = SFP.db.itemFrom and SFP.db.itemFrom[itemID]
                if from and from.src then
                    local n = 0
                    for key, src in pairs(from.src) do
                        n = n + 1
                        if n > 3 then break end
                        local kind, id = key:match("^(%a+):(%d+)$")
                        local nm
                        if kind == "npc" then
                            id = tonumber(id)
                            nm = (SFP.db.killPos and SFP.db.killPos[id] and SFP.db.killPos[id].n) or (SFP.db.npcPos and SFP.db.npcPos[id] and SFP.db.npcPos[id].n)
                        end
                        tooltip:AddLine("Looted from " .. (nm or key) .. " x" .. (src.c or 1) .. ((src.m and C_Map.GetMapInfo(src.m)) and (", " .. C_Map.GetMapInfo(src.m).name) or ""), 0.7, 0.9, 0.7, true)
                    end
                end
            end
        end
    end
    if not itemID or not SFP.trackedIDs or not SFP.trackedIDs[itemID] then return end
    local base = itemID
    if not SFP.itemSources[itemID] then
        for id, info in pairs(SFP.Items) do
            if info.tiers then
                for _, t in ipairs(info.tiers) do if t == itemID then base = id end end
            end
        end
    end
    local sources = SFP.itemSources[base]
    -- the auction price first, right under the normal sell price, like on every other item
    local ahFirst = SFP:GetPrice(itemID)
    if ahFirst and ahFirst > 0 then
        tooltip:AddLine("|cffff6a60Auction price:|r " .. SFP:FormatPrice(ahFirst), 1, 1, 1)
        -- the stack right under it, written the same way
        local stackFirst = SFP:StackCount(itemID)
        if stackFirst and stackFirst > 1 then
            tooltip:AddLine(("|cffff6a60Auction price (stack of %d):|r "):format(stackFirst) .. SFP:FormatPrice(ahFirst * stackFirst), 1, 1, 1)
        end
    end
    tooltip:AddLine(" ")
    tooltip:AddLine("|c" .. SFP.CYAN_HEX .. "SeviathsUsefulTools|r")
    if sources then
        local shown = {}
        for i = 1, math.min(4, #sources) do shown[i] = sources[i] end
        local more = #sources > 4 and (" +" .. (#sources - 4) .. " more") or ""
        tooltip:AddLine("Farm: " .. table.concat(shown, ", ") .. more, 0.8, 0.8, 0.8, true)
    end
    -- own scan first; Auctionator / TradeSkillMaster when there is none of our own
    local ahPrice = SFP:GetPrice(itemID)
    -- what crafting orders pay for this item (read from the orders the game listed), like the auction price above
    local tip, orders = SFP.OrderPrice and SFP:OrderPrice(itemID)
    if tip then
        tooltip:AddDoubleLine(("Crafting orders (%d):"):format(orders), SFP:FormatPrice(tip), 0.8, 0.8, 0.8, 1, 0.55, 0.5)
    end
    local extra = SFP:ItemExtra(base)
    if extra then tooltip:AddLine(extra, 1, 1, 1, true) end
    tooltip:AddLine("wowhead.com/item=" .. itemID, 0.5, 0.5, 0.5)
end

---------------------------------------------------------------------------
-- Current zone (for the minimap signal)
---------------------------------------------------------------------------
function SFP:PlayerFarmZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while mapID and guard < 6 do
        if self.zoneByMap[mapID] then return mapID end
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
        guard = guard + 1
    end
    return nil
end

---------------------------------------------------------------------------
-- Refresh hub: anything showing prices or cyan zones re-reads here
---------------------------------------------------------------------------
SFP.listeners = {}
function SFP:OnRefresh(fn) table.insert(self.listeners, fn) end
function SFP:RefreshAll()
    for i, fn in ipairs(self.listeners) do self:Safe("refresh #" .. i, fn) end
end

---------------------------------------------------------------------------
-- Events & slash commands
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
SFP.events = events
pcall(events.RegisterEvent, events, "ADDON_LOADED")
pcall(events.RegisterEvent, events, "PLAYER_LOGIN")
pcall(events.RegisterEvent, events, "ZONE_CHANGED_NEW_AREA")
pcall(events.RegisterEvent, events, "GET_ITEM_INFO_RECEIVED")

local itemInfoPending = false
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        SeviathsUsefulToolsDB = SeviathsUsefulToolsDB or {}
        -- the big tables were saved as text pieces: turned back into tables before anything reads them
        if SeviathsUnpackSaved then pcall(SeviathsUnpackSaved, SeviathsUsefulToolsDB) end
        local freshInstall = next(SeviathsUsefulToolsDB) == nil
        copyDefaults(defaults, SeviathsUsefulToolsDB)
        SFP.db = SeviathsUsefulToolsDB
        if freshInstall then SFP.db.treasuresSeeded = true end   -- a new install has no chests opened yet: the first character sees them all
        -- the map texts (names and coordinates next to the markers) are hidden again after every update and on a new install;
        -- they can be turned on again in the map's layer menu ("Labels")
        if SFP.db.labelsVersion ~= SFP.VERSION then
            SFP.db.showLabels = false
            if not freshInstall then
                -- after an update every pin except the rares starts hidden, on the world map and on the minimap; the player turns on what they want
                for _, k in ipairs({ "showSpawns", "showSpecial", "showHunter", "showMining", "showHerbs",
                    "showDungeons", "showRaids" }) do
                    SFP.db[k] = false
                end
                SFP.db.showRares = false      -- (WoW Forever: every spot layer starts off)
                SFP.db.minimapSpots = true    -- and they show on the minimap too
            end
            -- every single farm spot starts unticked in the spot list, after an update and on a new install (WorldMap.lua)
            SFP.db.hideSpotsPending = true
            SFP.db.labelsVersion = SFP.VERSION
        end
        -- what the addon learned elsewhere (Data/Learned.lua, see tools/merge_learned.py): fill in what this account lacks
        local seed = SFP.Seed
        if seed and SFP.db.seedStamp ~= seed.stamp then
            local function fill(dst, src, depth)
                for k, v in pairs(src) do
                    if dst[k] == nil then dst[k] = v
                    elseif type(dst[k]) == "table" and type(v) == "table" and depth < 4 then fill(dst[k], v, depth + 1) end
                end
            end
            for _, key in ipairs({ "npcs", "knownItems", "objects", "learned", "npcPos", "questSeen", "npcSpots", "itemZones", "learnedCurios", "learnedDecor", "ahItems", "ahNames" }) do
                if type(seed[key]) == "table" then
                    SFP.db[key] = SFP.db[key] or {}
                    fill(SFP.db[key], seed[key], 1)
                end
            end
            SFP.db.seedStamp = seed.stamp
        end
        -- 1.3: the map now shows small farm spots; panel + whole-zone glow become opt-in
        if (SFP.db.schema or 1) < 2 then
            SFP.db.zonePanel = false
            SFP.db.zoneFill = false
            SFP.db.showSpawns = false   -- (a new install starts with every spot layer off)
            SFP.db.schema = 2
        end
        -- WoW Forever: the farm spots were switched on by that step on a new install; off once, the player turns them on where they want them
        if not SFP.db.spawnsOffOnce then
            SFP.db.spawnsOffOnce = true
            SFP.db.showSpawns = false
        end
        -- 1.11: map text only on hover - labels off for everyone once
        if (SFP.db.schema or 2) < 3 then
            SFP.db.showLabels = false
            SFP.db.schema = 3
        end
        -- 1.7 combined toggles were split in 1.8
        if SFP.db.showGather == false then SFP.db.showMining, SFP.db.showHerbs = false, false end
        if SFP.db.showInstances == false then SFP.db.showDungeons, SFP.db.showRaids = false, false end
        SFP.db.showGather, SFP.db.showInstances = nil, nil
    elseif event == "PLAYER_LOGIN" then
        SFP:Safe("BuildIndex", SFP.BuildIndex, SFP)
        if TooltipDataProcessor and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
        end
        for i, fn in ipairs(SFP.loginHandlers or {}) do SFP:Safe("login #" .. i, fn) end
        SFP:RefreshAll()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        SFP:RefreshAll()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- names/icons arrive async; batch one refresh
        if not itemInfoPending then
            itemInfoPending = true
            C_Timer.After(0.5, function() itemInfoPending = false; SFP:RefreshAll() end)
        end
    end
end)

function SFP:OnLogin(fn)
    self.loginHandlers = self.loginHandlers or {}
    table.insert(self.loginHandlers, fn)
end

-- the four separate Seviaths addons are inside this one now: running both doubles buttons and commands
SFP.loginHandlers = SFP.loginHandlers or {}
table.insert(SFP.loginHandlers, function()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local old = {}
    for _, n in ipairs({ "SeviathsFarmPack", "SeviathsCodex", "SeviathsDungeonsRaids", "SeviathsGuildHelper" }) do
        if isLoaded and isLoaded(n) then old[#old + 1] = n end
    end
    if #old > 0 then
        C_Timer.After(6, function()
            SFP:Print("|cffff8040Please disable " .. table.concat(old, ", ") .. "|r in the AddOns list - SeviathsUsefulTools already contains it (your saved data is shared).")
        end)
    end
end)

SLASH_SEVIATHSUSEFULTOOLS1 = "/sfp"
SLASH_SEVIATHSUSEFULTOOLS2 = "/farmpack"
SLASH_SEVIATHSUSEFULTOOLS3 = "/sut"
SlashCmdList["SEVIATHSUSEFULTOOLS"] = function(msg)
    local rawMsg = msg or ""   -- with its capital letters (names and realms)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.*)$")
    if cmd == "" or cmd == "show" then
        if SFP.ToggleMenu then SFP:ToggleMenu() else SFP:ToggleBrowser() end
    elseif cmd == "browser" or cmd == "farm" then
        SFP:ToggleBrowser()
    elseif cmd == "rio" then
        if SFP.Social and SFP.Social.RioDebug then SFP.Social.RioDebug((rawMsg:gsub("^%s*[Rr][Ii][Oo]%s*", ""))) else SFP:Print("not loaded yet") end
    elseif cmd == "cleardrops" then
        -- forgets the recorded drops of the monster you target (for a monster that was given items of other monsters by an old bug)
        local guid = UnitGUID and UnitGUID("target")
        local id = type(guid) == "string" and not (issecretvalue and issecretvalue(guid)) and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
        local rec = id and SFP.db and SFP.db.npcs and SFP.db.npcs[id]
        if type(rec) == "table" then
            rec.d, rec.s = nil, nil
            SFP.dropIndex = nil
            SFP:Print("Recorded drops of " .. tostring(rec.n or id) .. " cleared - kill it again and its loot is recorded.")
            if SFP.RefreshAll then SFP:RefreshAll() end
        else
            SFP:Print("Target a monster first.")
        end
    elseif cmd == "talents" then
        -- WoW Forever: what the game gives the talent advisor (to adapt it to the Forever talent trees)
        local function has(v) return v ~= nil and "yes" or "no" end
        SFP:Print(("talent APIs: GetSpecialization %s, C_Traits %s, C_ClassTalents %s, GetNumTalentTabs %s, GetTalentInfo %s, C_SpecializationInfo %s"):format(
            has(GetSpecialization), has(C_Traits), has(C_ClassTalents), has(GetNumTalentTabs), has(GetTalentInfo), has(C_SpecializationInfo)))
        SFP:Print(("frames: PlayerSpellsFrame %s, ClassTalentFrame %s, PlayerTalentFrame %s, TalentFrame %s"):format(
            has(_G.PlayerSpellsFrame), has(_G.ClassTalentFrame), has(_G.PlayerTalentFrame), has(_G.TalentFrame)))
        if GetNumTalentTabs then
            local okT, tabs = pcall(GetNumTalentTabs)
            if okT then
                for t = 1, tabs or 0 do
                    local okN, name, _, spent = pcall(GetTalentTabInfo, t)
                    SFP:Print(("tab %d: %s (%s points)"):format(t, okN and tostring(name) or "?", tostring(spent)))
                end
            end
        end
        if GetSpecialization then
            local okS, idx = pcall(GetSpecialization)
            SFP:Print("GetSpecialization: " .. tostring(okS and idx))
        end
        SFP:Print(("project %s, build %s, level %s"):format(tostring(WOW_PROJECT_ID), tostring(select(4, GetBuildInfo())), tostring(UnitLevel("player"))))
    elseif cmd == "nodes" then
        -- the talent nodes of the first tree column with position, rank and what the game says about them (to check which talents can be taken)
        local ok, cfg = pcall(C_ClassTalents.GetActiveConfigID)
        local okC, info = pcall(C_Traits.GetConfigInfo, ok and cfg or 0)
        local tree = okC and info and info.treeIDs and info.treeIDs[1]
        local okN, nodes = pcall(C_Traits.GetTreeNodes, tree or 0)
        local rows = {}
        for _, id in ipairs(okN and nodes or {}) do
            local okI, ni = pcall(C_Traits.GetNodeInfo, cfg, id)
            if okI and type(ni) == "table" and (ni.posX or 0) < 2000 then
                local edges = {}
                for _, e in ipairs(type(ni.visibleEdges) == "table" and ni.visibleEdges or {}) do edges[#edges + 1] = tostring(e.targetNode) end
                rows[#rows + 1] = { ni.posX or 0, ni.posY or 0, ("%d  x%s y%s  rank %s/%s  avail %s edgesOK %s canBuy %s  ->%s"):format(id, tostring(ni.posX), tostring(ni.posY), tostring(ni.currentRank), tostring(ni.maxRanks),
                    tostring(ni.isAvailable), tostring(ni.meetsEdgeRequirements), tostring(ni.canPurchaseRank), table.concat(edges, ",")) }
            end
        end
        table.sort(rows, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] < b[1] end)
        SFP:Print(#rows .. " nodes with x below 2000; the first 24:")
        for i = 1, math.min(24, #rows) do SFP:Print(rows[i][3]) end
    elseif cmd == "groups" then
        -- the categories of the group finder of this game (for the group tools): number and name
        if not (C_LFGList and C_LFGList.GetAvailableCategories) then SFP:Print("no group finder calls in this game") return end
        local ok, cats = pcall(C_LFGList.GetAvailableCategories)
        SFP:Print("categories: " .. tostring(ok and cats and #cats))
        for _, id in ipairs(ok and cats or {}) do
            local okI, info = pcall(C_LFGList.GetLfgCategoryInfo, id)
            local name = okI and type(info) == "table" and info.name
            SFP:Print(("  %d  %s%s"):format(id, tostring(name), (SFP.Social and SFP.Social.KindOfCategory) and "" or ""))
        end
    elseif cmd == "qmark" then
        -- the quest givers the map marks come from, nearest to you first, with the place the data has for each and your own place (to check them in the game)
        local map = C_Map.GetBestMapForUnit("player")
        local pos = map and C_Map.GetPlayerMapPosition(map, "player")
        local px, py = 0, 0
        if pos and pos.GetXY then px, py = pos:GetXY() end
        SFP:Print(("map %s, you are at %.1f, %.1f"):format(tostring(map), px * 100, py * 100))
        local rows = {}
        for _, e in ipairs((SFP.QuestGivers and SFP.QuestGivers[map]) or {}) do
            rows[#rows + 1] = { e = e, d = (e[2] - px * 100) ^ 2 + (e[3] - py * 100) ^ 2 }
        end
        table.sort(rows, function(a, b) return a.d < b.d end)
        for i = 1, math.min(8, #rows) do
            SFP:Print(("  %s  %.1f, %.1f  (%s)"):format(rows[i].e[1], rows[i].e[2], rows[i].e[3], tostring(rows[i].e[4]):sub(1, 50)))
        end
        if #rows == 0 then SFP:Print("  no quest givers in the data for this map") end
    elseif cmd == "lfg" then
        -- which group finder frames this game has, and which one the group tools found (open the Looking For Group window first)
        for _, name in ipairs({ "LFGListFrame", "LFGParentFrame", "PVEFrame", "LFDParentFrame", "GroupFinderFrame" }) do
            local fr = _G[name]
            SFP:Print(("%s: %s"):format(name, fr and (fr:IsVisible() and "visible" or "hidden") or "none"))
        end
        -- the frames inside the group finder window that are shown now, by name (open the Who tab first): to find the list of the Who tab
        local host = (_G.LFGListFrame and _G.LFGListFrame:IsVisible() and _G.LFGListFrame) or (_G.PVEFrame and _G.PVEFrame:IsVisible() and _G.PVEFrame)
        local function walk(fr, depth, shown)
            if depth > 4 then return end
            for _, c in ipairs({ fr:GetChildren() }) do
                local okV, vis = pcall(c.IsVisible, c)
                if okV and vis then
                    local nm = c.GetName and c:GetName()
                    if nm then shown[#shown + 1] = nm end
                    walk(c, depth + 1, shown)
                end
            end
        end
        if host then
            local shown = {}
            walk(host, 0, shown)
            SFP:Print("visible named frames in the group finder: " .. (#shown > 0 and table.concat(shown, ", "):sub(1, 900) or "none"))
        end
        local S2 = _G.SeviathsDungeonsRaids
        SFP:Print("group tools window: " .. tostring(S2 and "known" or "no handle") .. "; /sut groups to open it by hand")
    elseif cmd == "window" then
        -- finds the Talents window by its title (open it first)
        local ta = SFP.TalentAdvisor
        local f = ta and ta.FindTalentWindow and ta.FindTalentWindow()
        if f then
            local okN, dn = pcall(function() return f:GetDebugName() end)
            SFP:Print("Talents window: " .. tostring(okN and dn or f:GetName()) .. ", width " .. tostring(f:GetWidth()))
        else
            SFP:Print("Talents window not found (is it open?)")
        end
    elseif cmd == "window2" then
        -- how the talent buttons of the Talents window are made (open the window first): which fields and methods they have
        local ta = SFP.TalentAdvisor
        local f = ta and ta.FindTalentWindow and ta.FindTalentWindow()
        if not f then SFP:Print("Talents window not found (is it open?)") return end
        local buttons, seen = {}, 0
        local function walk(fr, depth)
            if depth > 7 or seen > 4000 then return end
            seen = seen + 1
            local okT, ot = pcall(function() return fr:GetObjectType() end)
            local okW, w = pcall(function() return fr:GetWidth() end)
            if okT and (ot == "Button" or ot == "CheckButton") and okW and type(w) == "number" and not (issecretvalue and issecretvalue(w)) and w >= 28 and w <= 80 then buttons[#buttons + 1] = fr end
            local okC, kids = pcall(function() return { fr:GetChildren() } end)
            for _, k in ipairs(okC and kids or {}) do walk(k, depth + 1) end
        end
        walk(f, 0)
        SFP:Print(("%d buttons of 28 to 80 px in the window (%d frames walked)"):format(#buttons, seen))
        for i = 1, math.min(3, #buttons) do
            local b = buttons[i]
            local keys = {}
            for k, v in pairs(b) do if type(k) == "string" then keys[#keys + 1] = k .. ":" .. type(v) end end
            table.sort(keys)
            local okN, dn = pcall(function() return b:GetDebugName() end)
            SFP:Print(("button %d %s: %s"):format(i, tostring(okN and dn), table.concat(keys, " ", 1, math.min(#keys, 30))))
            local mt = getmetatable(b)
            local idx = mt and mt.__index
            if type(idx) == "table" then
                local ms = {}
                for k, v in pairs(idx) do if type(k) == "string" and type(v) == "function" and (k:find("Node") or k:find("Entry") or k:find("Spell") or k:find("Talent") or k:find("Rank")) then ms[#ms + 1] = k end end
                table.sort(ms)
                SFP:Print("  methods: " .. table.concat(ms, ", ", 1, math.min(#ms, 25)))
            end
        end
    elseif cmd == "shown" then
        -- the frames of the game with Talent, Spec, Trait or Class in their name: to find the talent window (open it first)
        local names = {}
        for k, v in pairs(_G) do
            if type(k) == "string" and type(v) == "table" and not k:find("^Seviaths") and (k:find("Talent") or k:find("Spec") or k:find("Trait") or k:find("Class")) then
                local okT, ot = pcall(function() return v.GetObjectType and v:GetObjectType() end)
                if okT and type(ot) == "string" and (ot == "Frame" or ot == "Button" or ot == "ScrollFrame") then
                    local okS, sh = pcall(function() return v:IsShown() end)
                    names[#names + 1] = k .. ((okS and sh == true) and "*" or "")
                end
            end
        end
        table.sort(names)
        local line, count = "", 0
        for _, n in ipairs(names) do
            if count < 90 then
                if #line + #n > 170 then SFP:Print(line); line = "" end
                line = line .. n .. ", "
                count = count + 1
            end
        end
        SFP:Print(line)
        SFP:Print(#names .. " frames found (a * means shown now)")
    elseif cmd == "talents2" then
        -- WoW Forever: the talent system in detail (which frames, which spec calls, the trait tree of the player)
        local frames, specFns = {}, {}
        for k, v in pairs(_G) do
            if type(k) == "string" and type(v) == "table" and v.GetObjectType and (k:find("Talent") or k:find("SpellsFrame") or k:find("SpecFrame")) and #frames < 25 then frames[#frames + 1] = k end
        end
        table.sort(frames)
        SFP:Print("frames: " .. table.concat(frames, ", "))
        if C_SpecializationInfo then
            for k, v in pairs(C_SpecializationInfo) do if type(v) == "function" then specFns[#specFns + 1] = k end end
            table.sort(specFns)
            SFP:Print("C_SpecializationInfo: " .. table.concat(specFns, ", "))
            if C_SpecializationInfo.GetSpecialization then
                local ok, idx = pcall(C_SpecializationInfo.GetSpecialization)
                SFP:Print("C_SpecializationInfo.GetSpecialization: " .. tostring(ok and idx))
                if ok and idx and C_SpecializationInfo.GetSpecializationInfo then
                    SFP:Print("spec info: " .. table.concat({ tostring(select(2, pcall(C_SpecializationInfo.GetSpecializationInfo, idx))), tostring(select(3, pcall(C_SpecializationInfo.GetSpecializationInfo, idx))) }, " / "))
                end
            end
            if C_SpecializationInfo.GetNumSpecializations then SFP:Print("number of specs: " .. tostring(select(2, pcall(C_SpecializationInfo.GetNumSpecializations)))) end
        end
        if C_ClassTalents then
            local ok, cfg = pcall(C_ClassTalents.GetActiveConfigID)
            SFP:Print("active config: " .. tostring(ok and cfg))
            local fns = {}
            for k, v in pairs(C_ClassTalents) do if type(v) == "function" then fns[#fns + 1] = k end end
            table.sort(fns)
            SFP:Print("C_ClassTalents: " .. table.concat(fns, ", "))
            if ok and cfg and C_Traits and C_Traits.GetConfigInfo then
                local okC, info = pcall(C_Traits.GetConfigInfo, cfg)
                if okC and type(info) == "table" then
                    SFP:Print("config: type " .. tostring(info.type) .. ", trees " .. tostring(info.treeIDs and #info.treeIDs) .. ", name " .. tostring(info.name))
                    local tree = info.treeIDs and info.treeIDs[1]
                    if tree then
                        local okN, nodes = pcall(C_Traits.GetTreeNodes, tree)
                        SFP:Print("tree " .. tostring(tree) .. ": " .. tostring(okN and nodes and #nodes) .. " nodes")
                        local shown = 0
                        for _, id in ipairs(okN and nodes or {}) do
                            if shown < 6 then
                                local okI, ni = pcall(C_Traits.GetNodeInfo, cfg, id)
                                local entry = okI and ni and ni.entryIDs and ni.entryIDs[1]
                                local okE, ei = pcall(C_Traits.GetEntryInfo, cfg, entry or 0)
                                local okD, di = pcall(C_Traits.GetDefinitionInfo, okE and ei and ei.definitionID or 0)
                                local name = okD and di and (di.overrideName or (di.spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(di.spellID)))
                                SFP:Print(("node %d: %s, rank %s/%s, tree-page %s"):format(id, tostring(name), tostring(ni and ni.currentRank), tostring(ni and ni.maxRanks), tostring(ni and ni.subTreeID)))
                                shown = shown + 1
                            end
                        end
                    end
                end
            end
        end
    elseif cmd == "near" then
        if SFP.Social and SFP.Social.NearDebug then SFP.Social.NearDebug(rest) else SFP:Print("not loaded yet") end
    elseif cmd == "stats" then
        -- which of the game's statistics the delve / key / raid boss totals read
        if SFP.Social and SFP.Social.StatsDebug then SFP.Social.StatsDebug() else SFP:Print("not loaded yet") end
    elseif cmd == "version" or cmd == "about" then
        SFP:Print("version " .. SFP.VERSION .. " by " .. SFP.AUTHOR .. " - Classic to Midnight, data from wowhead.com")
        if SFP.OpenAbout then SFP:OpenAbout() end
    elseif cmd == "map" then
        SFP.db.mapOverlay = not SFP.db.mapOverlay
        SFP:Print("World map overlay " .. (SFP.db.mapOverlay and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "spawns" then
        SFP.db.showSpawns = not SFP.db.showSpawns
        SFP:Print("Monster spawn glows " .. (SFP.db.showSpawns and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "rares" then
        SFP.db.showRares = not SFP.db.showRares
        SFP:Print("Rare spots " .. (SFP.db.showRares and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "hunter" then
        SFP.db.showHunter = not SFP.db.showHunter
        SFP:Print("Hunter tame spots " .. (SFP.db.showHunter and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "gather" then
        local on = not (SFP.db.showMining or SFP.db.showHerbs)
        SFP.db.showMining, SFP.db.showHerbs = on, on
        SFP:Print("Mining & herbalism spots " .. (on and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "dungeons" then
        local on = not (SFP.db.showDungeons or SFP.db.showRaids)
        SFP.db.showDungeons, SFP.db.showRaids = on, on
        SFP:Print("Dungeon/raid icons " .. (on and "ON" or "OFF"))
        SFP:RefreshAll()
    elseif cmd == "mapbutton" then
        SFP.db.mapMenu.hide = not SFP.db.mapMenu.hide
        SFP:Print("World map layer button " .. (SFP.db.mapMenu.hide and "hidden" or "shown"))
        SFP:RefreshAll()
    elseif cmd == "learn" then
        local arg = (rest or ""):lower()
        if arg == "reset" then
            SFP:ResetLearned()
            SFP:Print("Learned farm spots cleared.")
        else
            SFP.db.learn = not SFP.db.learn
            SFP:Print("Learning farm spots from your loot " .. (SFP.db.learn and "ON" or "OFF"))
        end
    elseif cmd == "loot" then
        SFP:Print("Re-reading dungeon and raid loot from the Adventure Guide...")
        SFP:ScanInstanceLoot(true)
    elseif cmd == "minimap" then
        SFP.db.minimap.hide = not SFP.db.minimap.hide
        SFP:Print("Minimap button " .. (SFP.db.minimap.hide and "hidden" or "shown"))
        SFP:RefreshAll()
    elseif cmd == "scan" then
        SFP:StartScan(true)
    elseif cmd == "scanlog" or cmd == "scaninfo" then
        -- what the last scans did: which kind, how old, how many items have a price, and which sections the section scan read
        local last = SFP:LastScan()
        local snap = SFP:AllPrices()
        local n = 0
        for _ in pairs(snap or {}) do n = n + 1 end
        SFP:Print(("Last scan: %s (%s). Whole-auction-house snapshot: %d items priced."):format(
            last > 0 and (date and date("%d %b %H:%M", last) or tostring(last)) or "never",
            SFP.db.lastScanKind or "unknown kind", n))
        local log, parts = SFP.db.scanLog, {}
        for cid, count in pairs(log or {}) do parts[#parts + 1] = ("class %s: %d"):format(tostring(cid), tonumber(count) or 0) end
        table.sort(parts)
        if #parts > 0 then
            SFP:Print("Sections read by the last section scan: " .. table.concat(parts, ", "))
        else
            SFP:Print("No section scan has been run (the fast scan reads the whole auction house in one go and does not use sections).")
        end
    elseif cmd == "min" then
        local g = tonumber(rest)
        if g then
            SFP.db.minValue = math.floor(g * 10000)
            SFP:Print("Zones light up when their best item is worth at least " .. SFP:FormatPrice(SFP.db.minValue))
            SFP:RefreshAll()
        else
            SFP:Print("Usage: /sfp min <gold>   (0 = light every farm zone)")
        end
    elseif cmd == "scanitems" then
        if SFP.ScanProgress then
            local pct, mats = SFP:ScanProgress()
            SFP:Print(("Item scan: %d%% of the item IDs asked, %d crafting materials known."):format(pct, mats))
        end
    elseif cmd == "questdebug" or cmd == "questcompare" or cmd == "plates" or cmd == "quests" or cmd == "questie" or cmd == "log" then
        SFP:Print("Quest markers and the quest log window are not part of the retail edition (the game has its own).")
    elseif cmd == "learnall" then
        SFP.db.learnAll = (SFP.db.learnAll == false)
        SFP:Print("Learning everything constantly " .. (SFP.db.learnAll and "ON" or "OFF") .. " (kept in the addon's saved data)")
    elseif cmd == "comparelevel" then
        SFP.db.compareMineOnly = not SFP.db.compareMineOnly
        SFP:Print("Monster comparison: " .. (SFP.db.compareMineOnly and "my level and below only" or "all levels"))
    elseif cmd == "craft" then
        if SFP.PrintCraftProfit then SFP:PrintCraftProfit() end
    elseif cmd == "income" then
        if SFP.ToggleIncomeMessages then SFP:ToggleIncomeMessages() end
    elseif cmd == "sold" then
        if SFP.ToggleAuctionSold then SFP:ToggleAuctionSold() end
    elseif cmd == "alts" then
        SFP:ShowAlts()
    elseif cmd == "keys" then
        SFP:ShowKeys()
    elseif cmd == "delve" then
        SFP:Print((SFP:DelveAdvice():gsub("\n\n", "  ")))
    elseif cmd == "ach" then
        SFP:ShowAchPlanner()
    elseif cmd == "zone" then
        SFP:ZoneCheck(false)
    elseif cmd == "decor" then
        SFP:ShowDecor()
    elseif cmd == "weekly" then
        SFP:ShowWeekly()
    elseif cmd == "flip" or cmd == "deals" then
        SFP:ShowDeals()
    elseif cmd == "shop" then
        SFP:ShowShop()
    elseif cmd == "route" then
        if rest == "clear" then SFP:ClearRoute() else
            local m = WorldMapFrame and WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() or C_Map.GetBestMapForUnit("player")
            if m then SFP:BuildRoute(m) end
        end
    elseif cmd == "session" then
        SFP:SessionToggle(rest)
    elseif cmd == "next" then
        SFP:PrintFarmNext()
    elseif cmd == "export" then
        SFP:ShowExport()
    elseif cmd == "import" then
        SFP:ShowImport()
    elseif cmd == "alerts" then
        SFP.db.rareAlerts = (SFP.db.rareAlerts == false)
        SFP:Print("Rare alerts " .. (SFP.db.rareAlerts ~= false and "ON" or "OFF"))
    elseif cmd == "mem" then
        -- how much memory this addon holds (the shipped data is big): to see whether it is what makes the game stutter
        collectgarbage("collect")
        UpdateAddOnMemoryUsage()
        local kb = GetAddOnMemoryUsage("SeviathsUsefulTools") or 0
        SFP:Print(("Memory used by this addon: %.0f MB (the whole interface: %.0f MB)."):format(kb / 1024, collectgarbage("count") / 1024))
        if rest == "detail" then
            -- which tables are big: the number of tables inside each (a table costs about 100-200 bytes), counted once; it can take a few seconds
            local function nodes(t, depth)
                local n = 1
                if depth < 6 then
                    for _, v in pairs(t) do if type(v) == "table" then n = n + nodes(v, depth + 1) end end
                end
                return n
            end
            local rows = {}
            local function add(label, t) if type(t) == "table" then rows[#rows + 1] = { label, nodes(t, 0) } end end
            for _, dbName in ipairs({ "SeviathsUsefulToolsDB", "SeviathsCodexDB", "SeviathsDungeonsRaidsDB" }) do
                local db = _G[dbName]
                if type(db) == "table" then for k, v in pairs(db) do add(dbName:gsub("Seviaths", ""):gsub("DB", "") .. "." .. tostring(k), v) end end
            end
            add("shipped prices", _G.SeviathsUsefulToolsGold)
            add("shipped data (left)", _G.SeviathsUsefulToolsCollected)
            local cx = _G.SeviathsCodex
            if cx then add("codex entries", cx.entries) end
            table.sort(rows, function(x, y) return x[2] > y[2] end)
            for i = 1, math.min(14, #rows) do SFP:Print(("%s: %d tables"):format(rows[i][1], rows[i][2])) end
            -- the Codex: how many pages exist now, and how many of them came from the collected data (the ones that are taken out on close)
            if cx and cx.byCat then
                local total, lazy = 0, 0
                for cat, list in pairs(cx.byCat) do
                    for _, e in ipairs(list) do total = total + 1; if e.lazy then lazy = lazy + 1 end end
                end
                local shown = cx.IsOpen and cx:IsOpen()
                SFP:Print(("Codex pages: %d (%d from collected data, to be removed on close); window %s"):format(total, lazy, shown and "open" or "closed"))
                local lz = cx.lazy
                if lz then
                    for cat, s in pairs(lz) do
                        local built, groups = 0, 0
                        for _ in pairs(s.built or {}) do built = built + 1 end
                        for _ in pairs(s.groups or {}) do groups = groups + 1 end
                        SFP:Print(("lazy %s: state %s, %d groups counted, %d built"):format(cat, tostring(s.state), groups, built))
                    end
                end
            end
        end
    elseif cmd == "fastscan" then
        -- for testing: the addon's own 15-minute wait is skipped and a fast scan is asked for at once. The game may still ignore a
        -- request that comes too soon after another one (then the bar waits 2 minutes and the addon says so).
        SFP.db.lastReplicate = nil
        if SFP.TryFullScan then SFP:TryFullScan(true) end
    elseif cmd == "sections" then
        -- for testing: only the section scan (the second scan), at once; the auction house window must be open
        if SFP.StartCategoryScan and not SFP:StartCategoryScan() then SFP:Print("The section scan could not start (is the auction house open?).") end
    elseif cmd == "history" then
        if rest == "rescan" then
            SFP.db.historyReport = true
            SFP:Print("Reading your transmog collection again (in the background)...")
            SFP:ScanTransmogHistory(true)
        else
            local h = SFP.db.history
            local items, mons, mnt, pets, boe = 0, 0, 0, 0, 0
            for _ in pairs(h and h.boe or {}) do boe = boe + 1 end
            for _ in pairs(h and h.items or {}) do items = items + 1 end
            for _, r in pairs(h and h.by or {}) do
                mons = mons + 1
                mnt = mnt + (r.mounts and #r.mounts or 0)
                pets = pets + (r.pets and #r.pets or 0)
            end
            SFP:Print(("Collection history: %d transmog items (%d world-drop / BoE), %d mounts and %d pets that drop from %d monsters and bosses. /sfp history rescan reads it again."):format(items, boe, mnt, pets, mons))
        end
    elseif cmd == "tipdebug" then
        SFP.tipDebug = not SFP.tipDebug
        SFP:Print("Tooltip debug " .. (SFP.tipDebug and "ON - hover a monster" or "OFF"))
    elseif cmd == "menu" then
        if SFP.ToggleMenu then SFP:ToggleMenu() end
    elseif cmd == "errors" then
        if #SFP.errors == 0 then SFP:Print("No internal errors recorded.") end
        for i, e in ipairs(SFP.errors) do SFP:Print(i .. ": " .. e) end
    elseif cmd == "know" then
        if SFP.ToggleMenu then SFP:ToggleMenu("know") end
    elseif cmd == "codex" then
        SFP:RunModule("SEVIATHSCODEX", rest)
    elseif cmd == "groups" or cmd == "sdr" then
        SFP:RunModule("SEVIATHSDUNGEONSRAIDS", rest)
    elseif cmd == "guild" or cmd == "gi" then
        SFP:RunModule("SEVIATHSGUILDHELPER", rest)
    elseif cmd == "tooltip" then
        SFP.db.tooltip = not SFP.db.tooltip
        SFP:Print("Item tooltip lines " .. (SFP.db.tooltip and "ON" or "OFF"))
    else
        SFP:Print("version " .. SFP.VERSION)
        SFP:Print("/sfp - open the farm browser")
        SFP:Print("/sfp version - version info + options page")
        SFP:Print("/sfp map - toggle the cyan world map overlay")
        SFP:Print("/sfp spawns - toggle the glowing monster spawn spots")
        SFP:Print("/sfp rares - toggle the orange rare spots")
        SFP:Print("/sfp hunter - toggle the green hunter tame spots")
        SFP:Print("/sfp gather - toggle mining & herbalism best-zone spots")
        SFP:Print("/sfp dungeons - toggle dungeon/raid entrance icons")
        SFP:Print("/sfp mapbutton - show/hide the layer button on the world map")
        SFP:Print("/sfp loot - re-read dungeon/raid mounts and BoEs from the Adventure Guide")
        SFP:Print("/sfp learn - learning farm spots from your loot on/off (/sfp learn reset clears them)")
        SFP:Print("/sfp minimap - show/hide the minimap button")
        SFP:Print("/sfp scan - rescan AH prices (auction house must be open)")
        SFP:Print("/sfp min <gold> - only light zones worth at least this much")
        SFP:Print("/sfp tooltip - toggle the item tooltip lines")
        SFP:Print("/sfp history - what your transmog, mount and pet collections say you already looted (rescan to refresh)")
        SFP:Print("/sfp alts - every character: level, item level, gold, professions, weekly")
        SFP:Print("/sfp keys - delve keys and the bountiful delves today")
        SFP:Print("/sfp delve - companion role and curio hint for your spec")
        SFP:Print("/sfp ach - achievement planner")
        SFP:Print("/sfp zone - what you still miss in this zone or instance")
        SFP:Print("/sfp decor - Midnight housing decor recipes")
        SFP:Print("/sfp weekly - Great Vault, raid lockouts and rare kills of all your characters")
        SFP:Print("/sfp flip - BoE items now against their typical price")
        SFP:Print("/sfp shop - recipe planner: reagents, prices, where to farm them")
        SFP:Print("/sfp route [clear] - loop through the ticked spots of this map")
        SFP:Print("/sfp session - start / stop a farm session (kills, gold, loot, per hour); /sfp session hide")
        SFP:Print("/sfp next - which rare to farm next (missing mounts, pets, toys; nearest first)")
        SFP:Print("/sfp alerts - sound and chat line when a rare you still miss something from appears nearby")
        SFP:Print("/sfp export | import - share what the addon learned as a copy-paste string")
        SFP:Print("/sfp craft - the most profitable recipes you know")
        SFP:Print("/sfp income - toggle the gold messages (vendor, mail, quests)")
        SFP:Print("/sfp sold - toggle the chat message when an auction sells")
        SFP:Print("/sfp learnall - learn everything constantly on/off")
        SFP:Print("/sfp comparelevel - compare monsters at my level and below / all levels")
        SFP:Print("/sfp menu - the main menu with everything")
        SFP:Print("/sfp know - everything the addon has learned (monsters, items, recipes)")
        SFP:Print("/sfp errors - show internal errors")
        SFP:Print("/sfp codex [search] - encyclopedia (also /codex)")
        SFP:Print("/sfp groups - Dungeons & Raids group tools (also /sdr)")
        SFP:Print("/sfp guild - Guild Helper (also /gi)")
    end
end
