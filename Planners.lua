-- SeviathsUsefulTools - WoW Forever planners: the Dungeon & Raid Planner, the Quest Planner, the Roleplay (OC) page, and the zone levels on the world map.
-- They take the places of the retail Delve Planner, Delve Keys and Housing Decor pages of the menu.

local _, SFP = ...
local K = SFP.MenuKit
if not K then return end

local CY = "|c" .. (SFP.CYAN_HEX and ("ff" .. SFP.CYAN_HEX) or "ffe6483d")

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
    { 37, 1, 10 }, { 27, 1, 10 }, { 1, 1, 10 }, { 7, 1, 10 }, { 57, 1, 10 }, { 18, 1, 10 },
    { 52, 10, 20 }, { 48, 10, 20 }, { 62, 10, 20 }, { 10, 10, 25 }, { 21, 10, 20 }, { 49, 15, 25 }, { 47, 18, 30 }, { 56, 20, 30 },
    { 25, 20, 30 }, { 63, 18, 30 }, { 65, 15, 27 }, { 64, 25, 35 }, { 2, 30, 40 }, { 14, 30, 40 }, { 50, 30, 45 }, { 210, 30, 45 },
    { 66, 30, 40 }, { 15, 35, 45 }, { 51, 35, 45 }, { 70, 35, 45 }, { 69, 40, 50 }, { 71, 40, 50 }, { 26, 40, 50 }, { 32, 43, 50 },
    { 36, 50, 58 }, { 17, 45, 55 }, { 78, 48, 55 }, { 76, 45, 55 }, { 77, 48, 55 }, { 83, 53, 60 }, { 81, 55, 60 }, { 23, 53, 60 },
    { 22, 51, 58 }, { 80, 55, 60 },
}
local ZONE_LEVEL = {}
for _, z in ipairs(ZONES) do ZONE_LEVEL[z[1]] = z end
SFP.ZoneLevels = ZONE_LEVEL

local function myLevel() local l = UnitLevel("player"); return type(l) == "number" and l or 1 end
local function zoneName(map) local ok, n = pcall(function() return SFP:ZoneName(map) end); return ok and n or ("zone " .. map) end

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

local buildDungeons = K.simplePage("Dungeon & Raid Planner",
    "Plan the dungeons and raids to do next. The list starts with the ones that fit your level (green), then the ones coming up (yellow). Mark a dungeon done when you have what you need from it. " ..
    "Below your level, pick the dungeons that drop good items for your class; at 60, the raids come first.",
    function(pane, y)
        local head = K.mkText(pane, "", 12, y, 480, "GameFontNormal")
        local stats = K.mkText(pane, "", 12, y - 20, 480, "GameFontHighlightSmall")
        local list = SFP.MakeRowList(pane, 8, y - 46, 500, 380, 22)
        local function done() SFP.db.plannerDone = SFP.db.plannerDone or {}; local d = SFP.db.plannerDone[charKey()]; if not d then d = {}; SFP.db.plannerDone[charKey()] = d end return d end
        return function()
            local lvl = myLevel()
            local rows = {}
            for _, d in ipairs(DUNGEONS) do rows[#rows + 1] = { d = d, dist = distance(lvl, d[2], d[3]), raid = d[4] == "raid" } end
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
            local items = {}
            for i, r in ipairs(rows) do
                local d = r.d
                local isDone = done()[d[1]]
                items[i] = {
                    text = ("%s%s|r  %s%s%s"):format(isDone and "|cff606060" or levelColor(lvl, d[2], d[3]), d[1],
                        "|cff808080", d[2] == d[3] and ("level " .. d[2]) or ("level " .. d[2] .. "-" .. d[3]), r.raid and "  raid" or ""),
                    buttons = {
                        { isDone and "Undo" or "Done", 60, function() done()[d[1]] = (not isDone) or nil; SFP:Safe("planner", pane.refresh) end },
                    },
                }
            end
            list:Set(items)
        end
    end)

---------------------------------------------------------------------------
-- Quest Planner
---------------------------------------------------------------------------
local buildQuests = K.simplePage("Quest Planner",
    "Which zones are good for your level, and where to head next. Green zones fit your level, yellow ones are a few levels ahead. Press Map to open the world map on the zone.",
    function(pane, y)
        local head = K.mkText(pane, "", 12, y, 480, "GameFontNormal")
        local list = SFP.MakeRowList(pane, 8, y - 26, 500, 400, 22)
        return function()
            local lvl = myLevel()
            local rows = {}
            for _, z in ipairs(ZONES) do rows[#rows + 1] = { z = z, dist = distance(lvl, z[2], z[3]) } end
            table.sort(rows, function(a, b)
                if a.dist ~= b.dist then return a.dist < b.dist end
                return a.z[2] > b.z[2]   -- of the zones that fit, the one with the higher range first: it leads further on
            end)
            local next1 = rows[1] and zoneName(rows[1].z[1])
            head:SetText(("%sLevel %d|r  -  head to: %s"):format(CY, lvl, next1 and ("|cffffd100" .. next1 .. "|r") or "?"))
            local items = {}
            for i, r in ipairs(rows) do
                local z = r.z
                items[i] = {
                    text = ("%s%s|r  |cff808080level %d-%d%s|r"):format(levelColor(lvl, z[2], z[3]), zoneName(z[1]), z[2], z[3],
                        (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") == z[1]) and "  (you are here)" or ""),
                    buttons = { { "Map", 50, function()
                        if WorldMapFrame then
                            if not WorldMapFrame:IsShown() then ToggleWorldMap() end
                            WorldMapFrame:SetMapID(z[1])
                        end
                    end } },
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
