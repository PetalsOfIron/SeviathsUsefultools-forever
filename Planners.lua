-- SeviathsUsefulTools - WoW Forever planners: the Dungeon & Raid Planner, the Quest Planner, the Roleplay (OC) page, and the zone levels on the world map.
-- They take the places of the retail Delve Planner, Delve Keys and Housing Decor pages of the menu.

local _, SFP = ...
local K = SFP.MenuKit
if not K then return end

local CY = "|c" .. (SFP.CYAN_HEX or "ffffd100")   -- CYAN_HEX already starts with the alpha (ff)

---------------------------------------------------------------------------
-- the level ranges (as in the original game; the guides of Forever may move them a little)
---------------------------------------------------------------------------
local DUNGEONS = {
    { "Ragefire Chasm", 13, 18 }, { "The Deadmines", 15, 21 }, { "Wailing Caverns", 15, 25 }, { "Shadowfang Keep", 18, 25 },
    { "Blackfathom Deeps", 20, 30 }, { "The Stockade", 22, 30 }, { "Gnomeregan", 24, 33 }, { "Razorfen Kraul", 25, 35 },
    { "Scarlet Monastery", 28, 38 }, { "Razorfen Downs", 35, 45 }, { "Uldaman", 35, 45 }, { "Zul'Farrak", 42, 50 },
    { "Maraudon", 43, 52 }, { "The Temple of Atal'Hakkar", 45, 55 }, { "Blackrock Depths", 52, 60 }, { "Lower Blackrock Spire", 55, 60 },
    { "Upper Blackrock Spire", 58, 60 }, { "Stratholme", 58, 60 }, { "Scholomance", 58, 60 }, { "Dire Maul", 58, 60 },
    { "Molten Core", 60, 60, "raid" }, { "Onyxia's Lair", 60, 60, "raid" }, { "Blackwing Lair", 60, 60, "raid" },
    { "Zul'Gurub", 60, 60, "raid" }, { "Ruins of Ahn'Qiraj", 60, 60, "raid" }, { "Temple of Ahn'Qiraj", 60, 60, "raid" },
    { "Naxxramas", 60, 60, "raid" },
}

-- zone map (the game's UiMap number), level range
local ZONES = {
    { 1429, 1, 10 }, { 1426, 1, 10 }, { 1411, 1, 10 }, { 1412, 1, 10 }, { 1438, 1, 10 }, { 1420, 1, 10 },
    { 1436, 10, 20 }, { 1432, 10, 20 }, { 1439, 10, 20 }, { 1413, 10, 25 }, { 1421, 10, 20 }, { 1433, 15, 25 }, { 1431, 18, 30 }, { 1437, 20, 30 },
    { 1424, 20, 30 }, { 1440, 18, 30 }, { 1442, 15, 27 }, { 1441, 25, 35 }, { 1416, 30, 40 }, { 1417, 30, 40 }, { 1434, 30, 45 }, { 1434, 30, 45 },
    { 1443, 30, 40 }, { 1418, 35, 45 }, { 1435, 35, 45 }, { 1445, 35, 45 }, { 1444, 40, 50 }, { 1446, 40, 50 }, { 1425, 40, 50 }, { 1427, 43, 50 },
    { 1428, 50, 58 }, { 1419, 45, 55 }, { 1449, 48, 55 }, { 1447, 45, 55 }, { 1448, 48, 55 }, { 1452, 53, 60 }, { 1451, 55, 60 }, { 1423, 53, 60 },
    { 1422, 51, 58 }, { 1450, 55, 60 },
}
local ZONE_LEVEL = {}
for _, z in ipairs(ZONES) do ZONE_LEVEL[z[1]] = z end
SFP.ZoneLevels = ZONE_LEVEL

local function myLevel() local l = UnitLevel("player"); return type(l) == "number" and l or 1 end
local function zoneName(map)
    local okI, info = pcall(C_Map.GetMapInfo, map)
    if okI and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
    local ok, n = pcall(function() return SFP:ZoneName(map) end)
    return ok and n or ("zone " .. map)
end

local function charKey()
    local n = UnitName("player")
    return type(n) == "string" and n or "?"
end

-- green: the level fits, yellow: a few levels ahead, grey: too low or too high
local function levelColor(lvl, lo, hi)
    if lvl >= lo and lvl <= hi then return "|cff40ff40" end
    if lvl < lo and lo - lvl <= 3 then return "|cffffd100" end
    return "|cff808080"
end

local function distance(lvl, lo, hi)
    if lvl >= lo and lvl <= hi then return 0 end
    return lvl < lo and (lo - lvl) or (lvl - hi)
end

---------------------------------------------------------------------------
-- Dungeon & Raid Planner
---------------------------------------------------------------------------
local function statLine()
    local _, token = UnitClass("player")
    local ta = SFP.TalentAdvisor
    local spec = ta and ta.DetectedSpec and ta.DetectedSpec()
    local list
    if SFP.StatPriority then
        if spec and SFP.StatPriority[token .. ":" .. spec] then list = SFP.StatPriority[token .. ":" .. spec][1]; spec = spec
        else
            for key, lists in pairs(SFP.StatPriority) do
                if key:find("^" .. tostring(token) .. ":") then list = lists[1]; spec = key:match(":(.+)$"); break end
            end
        end
    end
    if not list then return "" end
    return ("For your class (%s %s) choose gear with: %s%s|r"):format(token:sub(1, 1) .. token:sub(2):lower(), spec or "", CY, table.concat(list, " > "))
end

-- where the way in is: the zone map, and the place in percent (approximate: the entrances of the original game)
local ENTRANCE = {
    ["Ragefire Chasm"] = { 1454, 52.5, 49.5 }, ["The Deadmines"] = { 1436, 43, 72 }, ["Wailing Caverns"] = { 1413, 45.7, 36.4 },
    ["Shadowfang Keep"] = { 1421, 44.5, 67.8 }, ["Blackfathom Deeps"] = { 1440, 14.2, 14 }, ["The Stockade"] = { 1453, 41, 57 },
    ["Gnomeregan"] = { 1426, 31.2, 34.5 }, ["Razorfen Kraul"] = { 199, 40.5, 90.5 }, ["Scarlet Monastery"] = { 1420, 85.2, 32.3 },
    ["Razorfen Downs"] = { 199, 47.5, 93 }, ["Uldaman"] = { 1418, 41.8, 12 }, ["Zul'Farrak"] = { 1446, 39, 21 }, ["Maraudon"] = { 1443, 29, 62 },
    ["The Temple of Atal'Hakkar"] = { 1435, 69.8, 53.7 }, ["Blackrock Depths"] = { 1428, 29.5, 38.5 }, ["Lower Blackrock Spire"] = { 1428, 29.5, 38.5 },
    ["Upper Blackrock Spire"] = { 1428, 29.5, 38.5 }, ["Stratholme"] = { 1423, 31.5, 15.7 }, ["Scholomance"] = { 1422, 69.5, 73 }, ["Dire Maul"] = { 1444, 62.5, 30.5 },
    ["Molten Core"] = { 1428, 29.5, 38.5 }, ["Onyxia's Lair"] = { 1445, 52, 76 }, ["Blackwing Lair"] = { 1428, 29.5, 38.5 }, ["Zul'Gurub"] = { 1434, 53, 17.5 },
    ["Ruins of Ahn'Qiraj"] = { 1451, 29, 96 }, ["Temple of Ahn'Qiraj"] = { 1451, 29, 96 }, ["Naxxramas"] = { 1423, 39, 26 },
}

local function waypointTo(map, x, y, label)
    if WorldMapFrame and not WorldMapFrame:IsShown() then pcall(ToggleWorldMap) end
    if WorldMapFrame then pcall(WorldMapFrame.SetMapID, WorldMapFrame, map) end
    if C_Map and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(map) and UiMapPoint then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
        SFP:Print(("Waypoint set: %s, %s %.1f, %.1f"):format(label, zoneName(map), x, y))
    else
        SFP:Print("The map of " .. label .. " opened (no waypoint can be set there).")
    end
end

local buildDungeons = K.simplePage("Dungeon & Raid Planner",
    "Tick a dungeon or raid when you are done with it, untick it to plan it again. The list starts with the ones that fit your level (green), then the ones coming up (yellow). " ..
    "Waypoint sets a marker on the way in (approximate). Below your level pick the dungeons that suit your class; at 60 the raids come first.",
    function(pane, y)
        local head = K.mkText(pane, "", 12, y - 8, 480, "GameFontNormal")
        local stats = K.mkText(pane, "", 12, y - 28, 470, "GameFontHighlightSmall")
        stats:SetHeight(30)
        stats:SetJustifyV("TOP")
        local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, y - 66)
        scroll:SetPoint("BOTTOMRIGHT", -30, 8)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(470, 10)
        scroll:SetScrollChild(child)
        local rowsUI = {}
        local function done() SFP.db.plannerDone = SFP.db.plannerDone or {}; local d = SFP.db.plannerDone[charKey()]; if not d then d = {}; SFP.db.plannerDone[charKey()] = d end return d end
        local function rowFrame(i)
            local r = rowsUI[i]
            if r then return r end
            r = CreateFrame("Frame", nil, child)
            r:SetSize(470, 22)
            r:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
            r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
            r.check:SetSize(22, 22)
            r.check:SetPoint("LEFT", 0, 0)
            r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.text:SetPoint("LEFT", 28, 0)
            r.text:SetWidth(330)
            r.text:SetJustifyH("LEFT")
            r.way = K.mkButton(r, "Waypoint", 78, function(self) local d = self.entry and ENTRANCE[self.entry[1]]; if d then waypointTo(d[1], d[2], d[3], self.entry[1]) end end)
            r.way:SetPoint("RIGHT", 0, 0)
            rowsUI[i] = r
            return r
        end
        return function()
            local lvl = myLevel()
            local rows = {}
            local have = {}
            for _, d in ipairs(DUNGEONS) do rows[#rows + 1] = { d = d, dist = distance(lvl, d[2], d[3]), raid = d[4] == "raid" }; have[d[1]:lower()] = true end
            -- every other dungeon and raid the game's group finder has shown (the Dungeons & Raids tools keep the list): level not known
            local dr = SFP_Module and select(2, SFP_Module("DungeonsRaids"))
            for kind, listName in pairs({ dungeon = "dungeon", raid = "raid" }) do
                local known = dr and dr.db and dr.db[listName] and dr.db[listName].known
                for name in pairs(known or {}) do
                    local l = tostring(name):lower()
                    local dup = have[l]
                    if not dup then for h in pairs(have) do if h:find(l, 1, true) or l:find(h, 1, true) then dup = true break end end end
                    if not dup then
                        have[l] = true
                        rows[#rows + 1] = { d = { tostring(name), 1, 60, kind == "raid" and "raid" or nil }, dist = 50, raid = kind == "raid" }
                    end
                end
            end
            table.sort(rows, function(a, b)
                local ad, bd = done()[a.d[1]], done()[b.d[1]]
                if (ad and true or false) ~= (bd and true or false) then return not ad end
                if lvl >= 60 and a.raid ~= b.raid then return a.raid end
                if a.dist ~= b.dist then return a.dist < b.dist end
                return a.d[2] < b.d[2]
            end)
            local best
            for _, r in ipairs(rows) do if not done()[r.d[1]] then best = r.d break end end
            head:SetText(("%sLevel %d|r  -  next: %s"):format(CY, lvl, best and ("|cffffd100" .. best[1] .. "|r") or "all done"))
            stats:SetText(statLine())
            for i, r in ipairs(rows) do
                local d = r.d
                local row = rowFrame(i)
                local isDone = done()[d[1]] and true or false
                row.check:SetChecked(isDone)
                row.check:SetScript("OnClick", function(self) done()[d[1]] = self:GetChecked() and true or nil; SFP:Safe("planner", pane.refresh) end)
                row.text:SetText(("%s%s|r  |cff808080%s%s|r"):format(isDone and "|cff606060" or levelColor(lvl, d[2], d[3]), d[1],
                    d[2] == d[3] and ("level " .. d[2]) or ("level " .. d[2] .. "-" .. d[3]), r.raid and "  raid" or ""))
                row.way.entry = d
                row.way:SetShown(ENTRANCE[d[1]] ~= nil)
                row:Show()
            end
            for i = #rows + 1, #rowsUI do rowsUI[i]:Hide() end
            child:SetHeight(#rows * 24 + 8)
        end
    end)

---------------------------------------------------------------------------
-- Quest Planner
---------------------------------------------------------------------------
local buildQuests = K.simplePage("Quest Planner",
    "The zones you still need for your level, and where to head next. Green zones fit your level, yellow ones are a few levels ahead. Press Done when you have finished a zone and it leaves the list. Map opens the world map on the zone.",
    function(pane, y)
        local head = K.mkText(pane, "", 12, y - 6, 480, "GameFontNormal")
        local list = SFP.MakeRowList(pane, 8, y - 34, 500, 380, 22)
        local function done() SFP.db.zoneDone = SFP.db.zoneDone or {}; local d = SFP.db.zoneDone[charKey()]; if not d then d = {}; SFP.db.zoneDone[charKey()] = d end return d end
        local showAll = false
        local allBtn = K.mkButton(pane, "Show all", 70, function(self) showAll = not showAll; self.text:SetText(showAll and "Needed only" or "Show all"); SFP:Safe("quests", pane.refresh) end)
        allBtn:SetPoint("TOPRIGHT", -34, y - 4)
        return function()
            local lvl = myLevel()
            local rows = {}
            for _, z in ipairs(ZONES) do
                local isDone = done()[z[1]]
                local dist = distance(lvl, z[2], z[3])
                -- what you need: zones that fit your level or are up to 6 levels ahead, and that you have not marked done
                if showAll or (not isDone and (dist == 0 or (lvl < z[2] and z[2] - lvl <= 6))) then rows[#rows + 1] = { z = z, dist = dist, done = isDone } end
            end
            table.sort(rows, function(a, b)
                if (a.done and true or false) ~= (b.done and true or false) then return not a.done end
                if a.dist ~= b.dist then return a.dist < b.dist end
                return a.z[3] > b.z[3]   -- of the zones that fit, the one with the higher range first: it leads further on
            end)
            local first = rows[1] and not rows[1].done and rows[1].z
            if first then
                head:SetText(("%sHead to %s next|r  |cffffd100(level %d-%d)|r"):format(CY, zoneName(first[1]), first[2], first[3]))
            else
                head:SetText(("%sLevel %d|r  -  no zone left for your level in the list"):format(CY, lvl))
            end
            local items = {}
            for i, r in ipairs(rows) do
                local z = r.z
                items[i] = {
                    text = ("%s%s|r  |cff808080level %d-%d%s|r"):format(r.done and "|cff606060" or levelColor(lvl, z[2], z[3]), zoneName(z[1]), z[2], z[3],
                        (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") == z[1]) and "  (you are here)" or ""),
                    buttons = {
                        { r.done and "Undo" or "Done", 50, function() done()[z[1]] = (not r.done) or nil; SFP:Safe("quests", pane.refresh) end },
                        { "Map", 46, function()
                            if WorldMapFrame then
                                if not WorldMapFrame:IsShown() then ToggleWorldMap() end
                                WorldMapFrame:SetMapID(z[1])
                            end
                        end },
                    },
                }
            end
            list:Set(items)
        end
    end)

---------------------------------------------------------------------------
-- Roleplay: the OC (original character) of each of your characters, saved for the whole account
---------------------------------------------------------------------------
local RP_FIELDS = {
    { "name", "OC name", 1 }, { "title", "Title or role", 1 }, { "looks", "Looks", 3 }, { "traits", "Personality", 3 },
    { "story", "Backstory", 5 }, { "notes", "Notes and plans", 3 },
}

local function rpData() SFP.db.rp = SFP.db.rp or { chars = {} }; return SFP.db.rp end
local function rpOf(key) local d = rpData(); d.chars[key] = d.chars[key] or {}; return d.chars[key] end

local rpSelected
local buildRoleplay = K.simplePage("Roleplay",
    "Type who each of your characters is (your OC): name, title, looks, personality and backstory. It is saved for the whole account, so every character shows the same data of all of them. " ..
    "Your OC name and title show on the tooltip of your character.",
    function(pane, y)
        rpSelected = rpSelected or charKey()
        rpOf(charKey())
        local charButtons = {}
        local editors = {}
        local function load()
            local rec = rpOf(rpSelected)
            for _, e in ipairs(editors) do
                if not e.box:HasFocus() then e.box:SetText(rec[e.key] or ""); e.box:SetCursorPosition(0) end
            end
        end
        local function rebuildButtons()
            local keys = {}
            for k in pairs(rpData().chars) do keys[#keys + 1] = k end
            table.sort(keys)
            for i, k in ipairs(keys) do
                local b = charButtons[i]
                if not b then
                    b = K.mkButton(pane, k, 110, function(self) rpSelected = self.key; SFP:Safe("rp", pane.refresh) end)
                    b:SetPoint("TOPLEFT", 12 + ((i - 1) % 4) * 116, y - math.floor((i - 1) / 4) * 26)
                    charButtons[i] = b
                end
                b.key = k
                local oc = rpOf(k).name
                b.text:SetText(k .. ((oc and oc ~= "") and (" - " .. oc) or ""))
                b.text:SetTextColor(k == rpSelected and 1 or 0.8, k == rpSelected and 0.82 or 0.8, k == rpSelected and 0 or 0.8)
                b:Show()
            end
        end
        local top = y - 56
        for _, f in ipairs(RP_FIELDS) do
            K.mkText(pane, f[2], 12, top, 300, "GameFontNormalSmall")
            local sf = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
            local h = f[3] * 16 + 8
            sf:SetPoint("TOPLEFT", 12, top - 16)
            sf:SetSize(460, h)
            local box = CreateFrame("EditBox", nil, sf)
            box:SetMultiLine(f[3] > 1)
            box:SetAutoFocus(false)
            box:SetFontObject("GameFontHighlightSmall")
            box:SetWidth(450)
            box:SetMaxLetters(f[3] > 1 and 1500 or 60)
            sf:SetScrollChild(box)
            local function save(self) rpOf(rpSelected)[f[1]] = strtrim(self:GetText() or "") end
            box:SetScript("OnEditFocusLost", save)
            box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            if f[3] == 1 then box:SetScript("OnEnterPressed", function(self) save(self); self:ClearFocus() end) end
            editors[#editors + 1] = { key = f[1], box = box }
            top = top - h - 24
        end
        return function() rebuildButtons(); load() end
    end)

-- your OC on the tooltip of your character
if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tt)
        if tt ~= GameTooltip then return end
        local okU, _, unit = pcall(tt.GetUnit, tt)
        if not okU or not unit or (issecretvalue and issecretvalue(unit)) then return end
        local okS, isMe = pcall(UnitIsUnit, unit, "player")
        if not okS or (issecretvalue and issecretvalue(isMe)) or not isMe then return end
        local rec = SFP.db and SFP.db.rp and SFP.db.rp.chars and SFP.db.rp.chars[charKey()]
        if rec and (rec.name or "") ~= "" then
            tt:AddLine(CY .. "OC: " .. rec.name .. "|r" .. ((rec.title or "") ~= "" and (" - " .. rec.title) or ""))
            if (rec.looks or "") ~= "" then tt:AddLine(rec.looks:sub(1, 160), 0.8, 0.8, 0.8, true) end
            tt:Show()
        end
    end)
end

---------------------------------------------------------------------------
-- the zone levels on the world map: the level range of the zone under the mouse
---------------------------------------------------------------------------
SFP:OnLogin(function()
    if not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
    local fs = WorldMapFrame.ScrollContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOP", WorldMapFrame.ScrollContainer, "TOP", 0, -28)
    local driver = CreateFrame("Frame")
    local acc = 0
    driver:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.15 then return end
        acc = 0
        if not WorldMapFrame:IsShown() then return end
        local text = ""
        local okC, x, y = pcall(function() return WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition() end)
        if okC and type(x) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            local okM, info = pcall(C_Map.GetMapInfoAtPosition, WorldMapFrame:GetMapID(), x, y)
            local z = okM and type(info) == "table" and ZONE_LEVEL[info.mapID]
            if z then
                text = ("%s%s|r  |cffffd100level %d-%d|r  |cff808080(as in the original game)|r"):format(CY, zoneName(z[1]), z[2], z[3])
            end
        end
        fs:SetText(text)
    end)
end)

---------------------------------------------------------------------------
-- the menu entries
---------------------------------------------------------------------------
for _, s in ipairs(K.sections) do
    if s.key == "delve" then s.label = "Dungeon & Raid Planner"
    elseif s.key == "keys" then s.label = "Quest Planner"
    elseif s.key == "decor" then s.label = "Roleplay" end
end
K.builders.delve, K.builders.keys, K.builders.decor = buildDungeons, buildQuests, buildRoleplay
