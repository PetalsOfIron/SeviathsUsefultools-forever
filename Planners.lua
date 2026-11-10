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

-- the character's two names (first name and surname; the game gives the surname where other games have the realm)
local function fullName()
    local n, s = UnitName("player")
    if type(n) ~= "string" then return "?" end
    if type(s) == "string" and s ~= "" and not s:find("Realm") and not s:find("CAMWOW") then return n .. " " .. s end
    return n
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

-- which dungeons are good for a class: the armor and weapons that drop there suit the class (a guide, not a rule)
local ARMOR_OF = { MAGE = "cloth", PRIEST = "cloth", WARLOCK = "cloth", ROGUE = "leather", DRUID = "leather", HUNTER = "mail", SHAMAN = "mail",
    WARRIOR = "plate", PALADIN = "plate" }
local FIT = {
    cloth = { "Scarlet Monastery", "Shadowfang Keep", "Blackfathom Deeps", "Maraudon", "Stratholme", "Scholomance" },
    leather = { "Wailing Caverns", "Razorfen Kraul", "The Deadmines", "Zul'Farrak", "Maraudon", "Scholomance" },
    mail = { "Gnomeregan", "Razorfen Downs", "Uldaman", "Zul'Farrak", "Scarlet Monastery", "Lower Blackrock Spire" },
    plate = { "Scarlet Monastery", "Uldaman", "Blackrock Depths", "Stratholme", "Lower Blackrock Spire", "Dire Maul" },
}
local function fitsClass(name)
    local _, token = UnitClass("player")
    local group = ARMOR_OF[token or ""]
    for _, n in ipairs(FIT[group or ""] or {}) do if n == name then return true, group end end
    return false, group
end

local buildDungeons = K.simplePage("Dungeon & Raid Planner",
    "Two lists: the one on top is your plan (the dungeons and raids you picked; tick one when you are done with it), the one below lists everything you can pick from. " ..
    "A star marks what suits your class. Waypoint sets a marker on the way in (approximate).",
    function(pane, y)
        local head = K.mkText(pane, "", 12, y - 8, 480, "GameFontNormal")
        local stats = K.mkText(pane, "", 12, y - 28, 470, "GameFontHighlightSmall")
        stats:SetHeight(46)
        stats:SetJustifyV("TOP")
        local function done() SFP.db.plannerDone = SFP.db.plannerDone or {}; local d = SFP.db.plannerDone[charKey()]; if not d then d = {}; SFP.db.plannerDone[charKey()] = d end return d end
        local function pick() SFP.db.plannerPick = SFP.db.plannerPick or {}; local d = SFP.db.plannerPick[charKey()]; if not d then d = {}; SFP.db.plannerPick[charKey()] = d end return d end

        -- a scrolling list of rows; mode "plan" = tick means done, mode "all" = tick means in your plan
        local function makeList(top, bottomOffset, mode)
            local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 8, top)
            scroll:SetPoint("TOPRIGHT", -30, top)
            scroll:SetHeight(bottomOffset)
            local child = CreateFrame("Frame", nil, scroll)
            child:SetSize(470, 10)
            scroll:SetScrollChild(child)
            return { child = child, rows = {}, scroll = scroll, mode = mode }
        end
        local function rowFrame(list, i)
            local r = list.rows[i]
            if r then return r end
            r = CreateFrame("Frame", nil, list.child)
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
            list.rows[i] = r
            return r
        end
        local planList, allList
        local H = 8   -- (the lists are placed below)
        planList = makeList(y - 104, 112, "plan")
        local sep = K.mkText(pane, "", 12, y - 226, 470, "GameFontNormal")
        allList = makeList(y - 248, 230, "all")
        local planLabel = K.mkText(pane, "", 12, y - 86, 470, "GameFontNormal")

        local function fillList(list, entries, lvl)
            for i, r in ipairs(entries) do
                local d = r.d
                local row = rowFrame(list, i)
                local isDone = done()[d[1]] and true or false
                local picked = pick()[d[1]] and true or false
                if list.mode == "plan" then
                    row.check:SetChecked(isDone)
                    row.check:SetScript("OnClick", function(self) done()[d[1]] = self:GetChecked() and true or nil; SFP:Safe("planner", pane.refresh) end)
                else
                    row.check:SetChecked(picked)
                    row.check:SetScript("OnClick", function(self) pick()[d[1]] = self:GetChecked() and true or nil; SFP:Safe("planner", pane.refresh) end)
                end
                local star = r.fit and ("|cffffd100*|r ") or ""
                row.text:SetText(("%s%s%s|r  |cff808080%s%s|r"):format(star, (list.mode == "plan" and isDone) and "|cff606060" or "|cffffffff", d[1],
                    d[2] == d[3] and ("level " .. d[2]) or ("level " .. d[2] .. "-" .. d[3]), r.raid and "  raid" or ""))
                row.way.entry = d
                row.way:SetShown(ENTRANCE[d[1]] ~= nil)
                row:Show()
            end
            for i = #entries + 1, #list.rows do list.rows[i]:Hide() end
            list.child:SetHeight(math.max(10, #entries * 24 + 8))
        end

        return function()
            local lvl = myLevel()
            local rows, have = {}, {}
            for _, d in ipairs(DUNGEONS) do
                local fit = fitsClass(d[1])
                rows[#rows + 1] = { d = d, dist = distance(lvl, d[2], d[3]), raid = d[4] == "raid", fit = fit }
                have[d[1]:lower()] = true
            end
            -- every other dungeon and raid the group finder has shown (the Dungeons & Raids tools keep the list): level not known
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
            -- order: what fits your level and your class first, raids first at 60
            table.sort(rows, function(a, b)
                if lvl >= 60 and a.raid ~= b.raid then return a.raid end
                if a.dist ~= b.dist then return a.dist < b.dist end
                if (a.fit and true or false) ~= (b.fit and true or false) then return a.fit end
                return a.d[2] < b.d[2]
            end)
            local planRows, suggest = {}, {}
            for _, r in ipairs(rows) do
                if pick()[r.d[1]] then planRows[#planRows + 1] = r end
                if r.fit and r.dist <= 10 and #suggest < 4 and not done()[r.d[1]] then suggest[#suggest + 1] = r.d[1] end
            end
            local best
            for _, r in ipairs(planRows) do if not done()[r.d[1]] then best = r.d break end end
            head:SetText(("%sLevel %d|r  -  %s"):format(CY, lvl, best and ("next: |cffffd100" .. best[1] .. "|r") or "pick dungeons below for your plan"))
            local _, group = fitsClass("")
            stats:SetText(statLine() .. ((#suggest > 0) and ("\n|cffffd100Good for your class (" .. (group or "?") .. "):|r " .. table.concat(suggest, ", ")) or ""))
            planLabel:SetText(CY .. "Your plan|r  |cff808080(tick when done)|r")
            sep:SetText(CY .. "Choose dungeons and raids|r  |cff808080(tick to add to your plan, * = suits your class)|r")
            fillList(planList, planRows, lvl)
            fillList(allList, rows, lvl)
        end
    end)

---------------------------------------------------------------------------
-- Quest Planner
---------------------------------------------------------------------------
-- a zone is done when every quest of it that you can take (known quest givers: Data/QuestGivers.lua and the ones you learned) is completed;
-- a zone with fewer than 5 known quests is never called done (the quest data is not complete enough)
-- which side a zone belongs to (the other side does not quest there); zones not listed are for both
local ZONE_SIDE = { [1429] = "Alliance", [1426] = "Alliance", [1438] = "Alliance", [1436] = "Alliance", [1432] = "Alliance", [1439] = "Alliance",
    [1433] = "Alliance", [1431] = "Alliance", [1437] = "Alliance",
    [1411] = "Horde", [1412] = "Horde", [1420] = "Horde", [1413] = "Horde", [1421] = "Horde", [1441] = "Horde" }
-- the starting zone of each race: the other starting zones of the side are not suggested
local START_OF = { Human = 1429, Dwarf = 1426, Gnome = 1426, NightElf = 1438, Orc = 1411, Troll = 1411, Tauren = 1412, Scourge = 1420 }
local START_ZONES = { [1429] = true, [1426] = true, [1438] = true, [1411] = true, [1412] = true, [1420] = true }
-- quests of a zone for one side, from the quest giver data of Wowhead (side 1 Alliance, 2 Horde, 3 both) and from what this character saw
local function sideCount(map, faction)
    local want = faction == "Alliance" and 1 or 2
    local n = 0
    if SFP.QStarts and SFP.QDB then
        -- the quest database (Data/QuestDB.lua): quests that the races of that side can take
        local bitsFor = faction == "Alliance" and { 1, 4, 8, 64 } or { 2, 16, 32, 128 }
        local seenQ = {}
        for _, e in ipairs(SFP.QStarts[map] or {}) do
            if e[5] == nil or (e[5] == "A") == (faction == "Alliance") then
                for _, id in ipairs(e[4]) do
                    local r = SFP.QDB[id]
                    if r and not seenQ[id] then
                        local rc = r.rc or 0
                        local ok = rc == 0
                        if not ok then for _, b in ipairs(bitsFor) do if (rc % (2 * b)) >= b then ok = true break end end end
                        if ok then seenQ[id] = true; n = n + 1 end
                    end
                end
            end
        end
        local seen2 = SFP.db and SFP.db.questSides and SFP.db.questSides[map]
        return n + ((seen2 and seen2[faction]) or 0)
    end
    for _, e in ipairs((SFP.QuestGivers and SFP.QuestGivers[map]) or {}) do
        for part in string.gmatch(e[4] or "", "[^|]+") do
            local s = tonumber(part:match("^%d+:%d+:%d+:(%d+):"))
            if s == want then n = n + 1 end
        end
    end
    local seen = SFP.db and SFP.db.questSides and SFP.db.questSides[map]
    return n + ((seen and seen[faction]) or 0)
end

local function zoneFitsMe(z)
    local f = UnitFactionGroup("player")
    local side = ZONE_SIDE[z[1]]
    -- a zone of the other side still counts when enough quests of your own side exist there (camps of your side, from Wowhead and from your own play)
    if side and f and side ~= f and sideCount(z[1], f) < 8 then return false end
    return true
end

local function zoneAutoDone(z)
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return false end
    local lvl = myLevel()
    local f = UnitFactionGroup("player")
    local side = f == "Alliance" and 1 or f == "Horde" and 2 or 0
    local total, open = 0, 0
    if SFP.QStarts and SFP.QDB and SFP.QuestMarkers and SFP.QuestMarkers.Eligible then
        -- the quest database: the quests of the zone this character could take (race, class), in the level range of the zone, up to your level
        local seenQ = {}
        for _, e in ipairs(SFP.QStarts[z[1]] or {}) do
            if e[5] == nil or e[5] == (f == "Alliance" and "A" or "H") then
                for _, id in ipairs(e[4]) do
                    local r = SFP.QDB[id]
                    if r and not seenQ[id] and SFP.QuestMarkers.Eligible(id) and (r.l or 0) >= z[2] and (r.l or 0) <= z[3] + 2 and (r.r or 0) <= lvl then
                        seenQ[id] = true
                        total = total + 1
                        if not C_QuestLog.IsQuestFlaggedCompleted(id) then open = open + 1 end
                    end
                end
            end
        end
        return total >= 5 and open == 0
    end
    for _, e in ipairs((SFP.QuestGivers and SFP.QuestGivers[z[1]]) or {}) do
        for part in string.gmatch(e[4] or "", "[^|]+") do
            local id, ql, req, qs = part:match("^(%d+):(%d+):(%d+):(%d+):")
            id, ql, req, qs = tonumber(id), tonumber(ql), tonumber(req), tonumber(qs)
            if id and (qs == 0 or qs == 3 or qs == side or side == 0) and ql >= z[2] and ql <= z[3] + 2 and req <= lvl then
                total = total + 1
                if not C_QuestLog.IsQuestFlaggedCompleted(id) then open = open + 1 end
            end
        end
    end
    return total >= 5 and open == 0
end

local buildQuests = K.simplePage("Questing Zone Planner",
    "The zones you still need for your level, and where to head next. A zone leaves the list by itself when all the quests of it that you can take are completed. Map opens the world map on the zone.",
    function(pane, y)
        local head = K.mkText(pane, "", 12, y - 6, 480, "GameFontNormal")
        local list = SFP.MakeRowList(pane, 8, y - 34, 500, 380, 22)
        local function done() SFP.db.zoneDone = SFP.db.zoneDone or {}; local d = SFP.db.zoneDone[charKey()]; if not d then d = {}; SFP.db.zoneDone[charKey()] = d end return d end
        local showAll = false
        return function()
            local lvl = myLevel()
            local rows = {}
            for _, z in ipairs(ZONES) do
                local isDone = zoneAutoDone(z)
                local dist = distance(lvl, z[2], z[3])
                if not zoneFitsMe(z) then dist = nil end
                -- what you need: zones that fit your level or are up to 6 levels ahead, and that you have not marked done
                if dist and (showAll or (not isDone and z[3] > lvl and z[2] - lvl <= 6)) then rows[#rows + 1] = { z = z, dist = dist, done = isDone } end
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
                    text = ("%s%s|r  |cff808080level %d-%d%s|r"):format("|cffffffff", zoneName(z[1]), z[2], z[3],
                        (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") == z[1]) and "  (you are here)" or ""),
                    buttons = {
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
-- the fields of the roleplay addons (Total RP, MyRolePlay, XRP): the long texts on the left, the short facts on the right; { key, label, lines, column }
local RP_FIELDS = {
    { "title", "Title or role", 1, 1 }, { "looks", "Looks (physical description)", 3, 1 }, { "traits", "Personality", 3, 1 },
    { "story", "Backstory (history)", 5, 1 }, { "notes", "Notes and plans (private)", 3, 1 },
    { "age", "Age", 1, 2 }, { "height", "Height and build", 1, 2 }, { "eyes", "Eyes and hair", 1, 2 }, { "residence", "Residence", 1, 2 },
    { "birthplace", "Birthplace", 1, 2 }, { "motto", "Motto", 1, 2 }, { "currently", "Currently (what my character is doing)", 2, 2 },
    { "ooc", "Out of character info", 2, 2 },
}

local function rpData() SFP.db.rp = SFP.db.rp or { chars = {} }; return SFP.db.rp end
local function rpOf(key) local d = rpData(); d.chars[key] = d.chars[key] or {}; return d.chars[key] end

local rpSelected
local buildRoleplay = K.simplePage("Roleplay",
    "Type who each of your characters is (your OC; the character's own name is its name): title, looks, personality and backstory. It is saved for the whole account, so every character shows the same data of all of them. " ..
    "Your title, looks, personality and backstory show on the tooltip of your character (notes and plans stay private).",
    function(pane, y)
        -- every character of the account: the key is "Name-Realm", the same as the Alt Overview uses
        local function rpKey()
            return (UnitName("player") or "?") .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or "?"):gsub("[%s%-']", ""))
        end
        local function migrate()
            -- an older profile was saved under the first name only: it moves to the full key of this character
            local d = rpData().chars
            local first, full = charKey(), rpKey()
            if d[first] and not d[full] then d[full] = d[first]; d[first] = nil end
        end
        migrate()
        rpSelected = rpSelected or rpKey()
        if not rpData().chars[rpSelected] then rpSelected = rpKey() end
        rpOf(rpKey())
        local charButtons = {}
        local editors = {}
        local function load()
            local rec = rpOf(rpSelected)
            for _, e in ipairs(editors) do
                if not e.box:HasFocus() then e.box:SetText(rec[e.key] or ""); e.box:SetCursorPosition(0) end
            end
        end
        local function rebuildButtons()
            -- all the characters the addon knows on this account (the Alt Overview list and the profiles saved so far), yours first
            local keys, seen = {}, {}
            local function add(k) if type(k) == "string" and not seen[k] then seen[k] = true; keys[#keys + 1] = k end end
            for k in pairs(SFP.db.alts or {}) do add(k) end
            for k in pairs(rpData().chars) do add(k) end
            add(rpKey())
            table.sort(keys, function(a, b)
                if (a == rpKey()) ~= (b == rpKey()) then return a == rpKey() end
                return a < b
            end)
            local x, row = 12, 0
            for i, k in ipairs(keys) do
                local b = charButtons[i]
                if not b then
                    b = K.mkButton(pane, k, 112, function(self) rpSelected = self.key; SFP:Safe("rp", pane.refresh) end)
                    charButtons[i] = b
                end
                b.key = k
                -- both names of the character: saved when that character logged in (the surname is only known to the character itself)
                local nm = k:match("^(.-)%-") or k
                local rec = rpData().chars[k]
                b.text:SetText(k == rpKey() and fullName() or (type(rec) == "table" and rec.full) or nm)
                b.text:SetTextColor(k == rpSelected and 1 or 0.8, k == rpSelected and 0.82 or 0.8, k == rpSelected and 0 or 0.8)
                -- the button is as wide as the name
                local w = math.max(70, math.ceil(b.text:GetStringWidth()) + 28)
                b:SetWidth(w)
                if x + w > 640 then x, row = 12, row + 1 end
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", x, y - row * 26)
                x = x + w + 6
                b:Show()
            end
            for i = #keys + 1, #charButtons do charButtons[i]:Hide() end
        end
        local top1 = y - 112   -- room for three rows of characters and the status button
        local top2 = top1
        -- in character / out of character, like the roleplay addons have
        -- copy the profile of an installed roleplay addon (Total RP 3, XRP, MyRolePlay) into these fields
        local importBtn
        if SFP.RPBridge and SFP.RPBridge.Which() then
            importBtn = K.mkButton(pane, "Import from " .. SFP.RPBridge.Which(), 230, function()
                local mine = SFP.RPBridge.MyProfile()
                if not mine then SFP:Print("No profile found in " .. SFP.RPBridge.Which() .. " yet.") return end
                local r = rpOf(rpSelected)
                for k, v in pairs(mine) do if k ~= "name" and v and v ~= "" then r[k] = v end end
                SFP:Safe("rp", pane.refresh)
            end, "Copies your own profile of the roleplay addon into this page (only for the character you are playing).")
            importBtn:SetPoint("TOPLEFT", 252, y - 84)
        end
        local statusBtn
        statusBtn = K.mkButton(pane, "", 230, function()
            local r = rpOf(rpSelected)
            r.status = (r.status == "OOC") and "IC" or "OOC"
            statusBtn.text:SetText(r.status == "OOC" and "Out of character (OOC)" or "In character (IC)")
        end, "In character or out of character: shown on the tooltip of your character.")
        statusBtn:SetPoint("TOPLEFT", 12, y - 84)
        for _, f in ipairs(RP_FIELDS) do
            local col = f[4] or 1
            local top = col == 1 and top1 or top2
            local colX, colW = (col == 1) and 12 or 500, (col == 1) and 470 or 230
            K.mkText(pane, f[2], colX, top, colW, "GameFontNormalSmall")
            -- a visible box (dark with a gold edge) to type in
            local h = f[3] * 13 + 10
            local holder = CreateFrame("Frame", nil, pane, "BackdropTemplate")
            holder:SetPoint("TOPLEFT", colX, top - 14)
            holder:SetSize(colW, h)
            holder:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 } })
            holder:SetBackdropColor(0.04, 0.04, 0.05, 0.9)
            holder:SetBackdropBorderColor(0.7, 0.58, 0.3, 1)
            local box = CreateFrame("EditBox", nil, holder)
            box:SetPoint("TOPLEFT", 7, -6)
            box:SetPoint("BOTTOMRIGHT", -7, 6)
            box:SetMultiLine(f[3] > 1)
            box:SetAutoFocus(false)
            box:SetFontObject("GameFontHighlightSmall")
            box:SetMaxLetters(f[3] > 1 and 1500 or 60)
            holder:EnableMouse(true)
            holder:SetScript("OnMouseDown", function() box:SetFocus() end)
            local function save(self) rpOf(rpSelected)[f[1]] = strtrim(self:GetText() or "") end
            box:SetScript("OnEditFocusLost", save)
            -- saved as you type (no Enter needed): the tooltip shows it at once
            box:SetScript("OnTextChanged", function(self, byUser) if byUser then save(self) end end)
            box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            if f[3] == 1 then box:SetScript("OnEnterPressed", function(self) save(self); self:ClearFocus() end) end
            editors[#editors + 1] = { key = f[1], box = box }
            if col == 1 then top1 = top1 - h - 17 else top2 = top2 - h - 17 end
        end
        local baseLoad = load
        return function() rebuildButtons(); baseLoad(); statusBtn.text:SetText(rpOf(rpSelected).status == "OOC" and "Out of character (OOC)" or "In character (IC)") end
    end)

-- your OC on the tooltip of your character
if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tt)
        if tt ~= GameTooltip then return end
        local okU, _, unit = pcall(tt.GetUnit, tt)
        if not okU or not unit or (issecretvalue and issecretvalue(unit)) then return end
        local okS, isMe = pcall(UnitIsUnit, unit, "player")
        if not okS or (issecretvalue and issecretvalue(isMe)) or not isMe then return end
        local rpk = (UnitName("player") or "?") .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or "?"):gsub("[%s%-']", ""))
        local rec = SFP.db and SFP.db.rp and SFP.db.rp.chars and (SFP.db.rp.chars[rpk] or SFP.db.rp.chars[charKey()])
        if rec then
            local title = (rec.title or "") ~= "" and rec.title or nil
            if title or (rec.looks or "") ~= "" or (rec.traits or "") ~= "" or (rec.story or "") ~= "" then tt:AddLine(CY .. fullName() .. "|r") end
            if title then tt:AddLine(title, 1, 1, 1) end
            if (rec.looks or "") ~= "" then tt:AddLine(rec.looks:sub(1, 160), 0.8, 0.8, 0.8, true) end
            if (rec.traits or "") ~= "" then tt:AddLine("|cffffd100Personality:|r " .. rec.traits:sub(1, 120), 0.8, 0.8, 0.8, true) end
            if (rec.story or "") ~= "" then tt:AddLine("|cffffd100Backstory:|r " .. rec.story:sub(1, 240), 0.8, 0.8, 0.8, true) end
            if (rec.age or "") ~= "" then tt:AddLine("|cffffd100Age:|r " .. rec.age:sub(1, 40), 0.8, 0.8, 0.8) end
            if (rec.height or "") ~= "" then tt:AddLine("|cffffd100Height:|r " .. rec.height:sub(1, 60), 0.8, 0.8, 0.8) end
            if (rec.residence or "") ~= "" then tt:AddLine("|cffffd100Residence:|r " .. rec.residence:sub(1, 80), 0.8, 0.8, 0.8) end
            if (rec.motto or "") ~= "" then tt:AddLine("\"" .. rec.motto:sub(1, 100) .. "\"", 0.9, 0.8, 0.5, true) end
            if (rec.currently or "") ~= "" then tt:AddLine("|cffffd100Currently:|r " .. rec.currently:sub(1, 120), 0.8, 0.8, 0.8, true) end
            local any = false
            for _, k in ipairs({ "title", "looks", "traits", "story", "age", "height", "residence", "motto", "currently" }) do if (rec[k] or "") ~= "" then any = true end end
            if any then tt:AddLine(rec.status == "OOC" and "|cffff6060Out of character|r" or "|cff40ff40In character|r") end
            tt:Show()
        end
    end)
end

---------------------------------------------------------------------------
-- every character notes its own full name (first name and surname) at login, so the Roleplay page can show both names of all of them
SFP:OnLogin(function()
    C_Timer.After(2, function()
        if not SFP.db then return end
        local key = (UnitName("player") or "?") .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or "?"):gsub("[%s%-']", ""))
        local d = rpData().chars
        local first = charKey()
        if d[first] and not d[key] then d[key] = d[first]; d[first] = nil end
        d[key] = d[key] or {}
        d[key].full = fullName()
    end)
end)

-- the character sheet: a window with just what the player wrote for the character, read only, with the snake of the addon
local rpCard
function SFP:ShowRoleplayCard()
    if not rpCard then
        rpCard = SFP.MakeToolWindow("SeviathsUsefulToolsRoleplayCard", "", 470, 600)
        local snake = rpCard:CreateTexture(nil, "BACKGROUND", nil, 3)
        snake:SetTexture("Interface\\AddOns\\SeviathsUsefulTools\\Media\\snake_tile.tga")
        snake:SetSize(250, 250)
        snake:SetPoint("TOPRIGHT", rpCard, "TOPRIGHT", -12, -30)
        snake:SetVertexColor(0.95, 0.2, 0.18)
        snake:SetAlpha(0.45)
        local edit = K.mkButton(rpCard, "Edit", 80, function() SFP:ToggleMenu("decor") end)
        edit:SetPoint("TOPRIGHT", rpCard, "TOPRIGHT", -34, 1)
    end
    local n, s = UnitName("player")
    local full = (type(s) == "string" and s ~= "" and not s:find("Realm") and not s:find("CAMWOW")) and (n .. " " .. s) or tostring(n)
    local key = (UnitName("player") or "?") .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or "?"):gsub("[%s%-']", ""))
    local rec = (SFP.db.rp and SFP.db.rp.chars and (SFP.db.rp.chars[key] or SFP.db.rp.chars[UnitName("player") or "?"])) or {}
    local lines = { CY .. full .. "|r" }
    -- every field of the Roleplay page is listed; an empty one stays an empty section
    local function add(label, v, long)
        v = (type(v) == "string") and v or ""
        if long then lines[#lines + 1] = "\n" .. CY .. label .. "|r\n" .. v else lines[#lines + 1] = CY .. label .. ":|r " .. v end
    end
    local race, class = UnitRace("player"), UnitClass("player")
    lines[#lines + 1] = "|cff808080" .. tostring(race or "") .. " " .. tostring(class or "") .. ", level " .. tostring(UnitLevel("player")) .. "|r"
    lines[#lines + 1] = rec.status == "OOC" and "|cffff6060Out of character|r" or "|cff40ff40In character|r"
    lines[#lines + 1] = ""
    add("Title or role", rec.title); add("Age", rec.age); add("Height and build", rec.height); add("Eyes and hair", rec.eyes)
    add("Residence", rec.residence); add("Birthplace", rec.birthplace); add("Motto", rec.motto)
    add("Looks (physical description)", rec.looks, true); add("Personality", rec.traits, true); add("Backstory (history)", rec.story, true)
    add("Currently (what my character is doing)", rec.currently, true); add("Out of character info", rec.ooc, true)
    rpCard.title:SetText("Character")
    rpCard:SetContent(table.concat(lines, "\n"))
    rpCard:Show()
end

-- clicking on your own portrait (or yourself in the world): the menu has an entry that opens the character sheet
if Menu and Menu.ModifyMenu then
    for _, tag in ipairs({ "MENU_UNIT_SELF" }) do
        pcall(Menu.ModifyMenu, tag, function(owner, root)
            root:CreateDivider()
            root:CreateButton("Roleplay information (OC)", function() SFP:ShowRoleplayCard() end)
        end)
    end
end

-- the zone levels on the world map: the level range of the zone under the mouse
---------------------------------------------------------------------------
SFP:OnLogin(function()
    if not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
    -- its own frame above the map's pins, so nothing covers the text; it sits under the game's own zone name at the top of the map
    local holder = CreateFrame("Frame", nil, WorldMapFrame)
    holder:SetFrameStrata("FULLSCREEN_DIALOG")
    holder:SetAllPoints(WorldMapFrame.ScrollContainer)
    holder:EnableMouse(false)
    local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOP", holder, "TOP", 0, -62)
    fs:SetShadowOffset(1, -1)
    local byName
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
            if okM and type(info) == "table" and not z and type(info.name) == "string" then
                -- the zone found by its name when the map number is not one of the list's
                if not byName then
                    byName = {}
                    for _, zz in ipairs(ZONES) do byName[zoneName(zz[1])] = zz end
                end
                z = byName[info.name]
            end
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
    elseif s.key == "keys" then s.label = "Questing Zone Planner"
    elseif s.key == "decor" then s.label = "Roleplay" end
end
K.builders.delve, K.builders.keys, K.builders.decor = buildDungeons, buildQuests, buildRoleplay
