-- SeviathsUsefulTools - WoW Forever: the quests you can pick up, as yellow exclamation marks on the world map.
-- Quest givers come from Data/QuestGivers.lua (Wowhead); what you can take is decided from your own character: the quest is not done, not in your log,
-- you have the level for it and it is for your faction. The game's own "?" marks for the quests in your log stay as they are.

local _, SFP = ...

local QM = { enabled = true }
SFP.QuestMarkers = QM

local pins = {}
local shown = 0

local function playerFaction()
    local f = UnitFactionGroup("player")
    return f == "Alliance" and 1 or f == "Horde" and 2 or 0
end

-- the quests of one giver that the character can take: { { id, level, name }, ... }
local function available(entry)
    local lvl = UnitLevel("player")
    if type(lvl) ~= "number" then return nil end
    local side = playerFaction()
    local list = entry.parsed
    if not list then
        list = {}
        for part in string.gmatch(entry[4] or "", "[^|]+") do
            local id, ql, req, qs, name = part:match("^(%d+):(%d+):(%d+):(%d+):(.*)$")
            if id then list[#list + 1] = { id = tonumber(id), level = tonumber(ql), req = tonumber(req), side = tonumber(qs), name = name } end
        end
        entry.parsed = list
    end
    local out = {}
    for _, q in ipairs(list) do
        local ok = q.req <= lvl and (q.side == 0 or q.side == 3 or q.side == side or side == 0)   -- (Wowhead: 1 Alliance, 2 Horde, 3 both)
        -- quests far below the level give nothing: left out
        if ok and q.level > 0 and q.level < lvl - 8 and not SFP.db.questMarkersAll then ok = false end
        if ok and C_QuestLog then
            if C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(q.id) then ok = false end
            if ok and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(q.id) then ok = false end
        end
        if ok then out[#out + 1] = q end
    end
    return out
end

local function getPin(i, canvas)
    local p = pins[i]
    if p then return p end
    p = CreateFrame("Button", nil, canvas)
    p:SetSize(20, 20)
    p.icon = p:CreateTexture(nil, "OVERLAY")
    p.icon:SetAllPoints()
    -- the game's own yellow "!" of an available quest
    if p.icon.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestNormal") then
        p.icon:SetAtlas("QuestNormal")
    else
        p.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    end
    p:SetScript("OnEnter", function(self)
        local t = SFP.Tip and SFP.Tip() or GameTooltip
        t:SetOwner(self, "ANCHOR_RIGHT")
        t:AddLine(self.giver or "?", 1, 0.82, 0)
        for _, q in ipairs(self.quests or {}) do
            t:AddLine(("[%d] %s"):format(q.level, q.name), 1, 1, 1)
        end
        t:AddLine("Click: set a waypoint", 0.9, 0.28, 0.24)
        t:Show()
    end)
    p:SetScript("OnLeave", function() (SFP.Tip and SFP.Tip() or GameTooltip):Hide() end)
    p:SetScript("OnClick", function(self)
        if self.map and SFP.SetWaypoint then SFP:SetWaypoint(self.map, self.x, self.y, self.giver) end
    end)
    pins[i] = p
    return p
end

-- the quest givers this character has learned itself: the Codex notes the giver's place (qloc[quest].g) when a quest is picked up or turned in
local function learnedGivers(map)
    local cdb = _G.SeviathsCodexDB
    local out = {}
    if not (cdb and type(cdb.qloc) == "table") then return out end
    local lvl = UnitLevel("player")
    for qid, rec in pairs(cdb.qloc) do
        local g = type(rec) == "table" and rec.g
        if type(qid) == "number" and type(g) == "table" and g.m == map and g.x and g.y and g.n then
            local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(qid)
            local inLog = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(qid)
            if not done and not inLog then
                local qr = type(cdb.quests) == "table" and cdb.quests[qid]
                local title = type(qr) == "table" and qr.t or ("Quest " .. qid)
                local ql = type(qr) == "table" and tonumber(qr.l) or 0
                if ql == 30 then ql = 0 end   -- 30 = level not known
                if not (ql > 0 and type(lvl) == "number" and ql < lvl - 8) then
                    out[#out + 1] = { n = g.n, x = g.x * 100, y = g.y * 100, q = { id = qid, level = ql, name = title } }
                end
            end
        end
    end
    return out
end

function QM:Draw()
    for _, p in ipairs(pins) do p:Hide() end
    if not (SFP.db and SFP.db.questMarkers ~= false and SFP.QuestGivers and WorldMapFrame and WorldMapFrame:IsShown()) then return end
    local map = WorldMapFrame:GetMapID()
    local list = map and (SFP.QuestGivers[map] or {})
    local canvas = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
    if not (list and canvas) then return end
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local n = 0
    for _, e in ipairs(list) do
        local qs = available(e)
        if qs and #qs > 0 then
            n = n + 1
            local p = getPin(n, canvas)
            p.giver, p.quests, p.map, p.x, p.y = e[1], qs, map, e[2] / 100, e[3] / 100
            p:ClearAllPoints()
            p:SetPoint("CENTER", canvas, "TOPLEFT", p.x * w, -p.y * h)
            p:SetFrameLevel(canvas:GetFrameLevel() + 20)
            p:Show()
        end
    end
    -- learned by this character: shown when no known giver is within a few percent of the map
    for _, g in ipairs(learnedGivers(map)) do
        local near = false
        for _, e in ipairs(list) do
            if math.abs(e[2] - g.x) < 1.5 and math.abs(e[3] - g.y) < 1.5 then near = true break end
        end
        if not near then
            n = n + 1
            local p = getPin(n, canvas)
            p.giver, p.quests, p.map, p.x, p.y = g.n, { g.q }, map, g.x / 100, g.y / 100
            p:ClearAllPoints()
            p:SetPoint("CENTER", canvas, "TOPLEFT", p.x * w, -p.y * h)
            p:SetFrameLevel(canvas:GetFrameLevel() + 20)
            p:Show()
        end
    end
end

-- the zone name of the mark is drawn together with the other layers, and again when quests change
SFP:OnLogin(function()
    if not WorldMapFrame then return end
    local function draw() SFP:Safe("quest markers", QM.Draw, QM) end
    WorldMapFrame:HookScript("OnShow", draw)
    if hooksecurefunc and WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() C_Timer.After(0.05, draw) end) end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("QUEST_LOG_UPDATE")
    ev:RegisterEvent("QUEST_TURNED_IN")
    ev:RegisterEvent("QUEST_ACCEPTED")
    ev:RegisterEvent("QUEST_DETAIL")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:SetScript("OnEvent", function(_, event)
        if event == "QUEST_DETAIL" or event == "QUEST_ACCEPTED" then
            -- the camps of a side: a quest seen in a zone is noted for the faction of this character (the Quest Planner uses it)
            local mp = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
            local f = UnitFactionGroup("player")
            if mp and f and SFP.db then
                SFP.db.questSides = SFP.db.questSides or {}
                local rec = SFP.db.questSides[mp] or {}
                SFP.db.questSides[mp] = rec
                rec[f] = (rec[f] or 0) + 1
            end
        end
        if WorldMapFrame:IsShown() then draw() end
    end)
end)

-- the old call of WorldMap.lua (zones of quests): nothing more to draw there
function QM:DrawZones() end

---------------------------------------------------------------------------
-- the same "!" marks on the minimap: the quest givers around you with a quest you can take (known givers and the ones you learned)
---------------------------------------------------------------------------
local mini = {}
local function worldPos(map, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, _, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if ok and pos and pos.x then return pos.x, pos.y end
end

local function miniPin(i)
    local p = mini[i]
    if p then return p end
    p = CreateFrame("Frame", nil, Minimap)
    p:SetSize(16, 16)
    p:SetFrameLevel(Minimap:GetFrameLevel() + 6)
    p.icon = p:CreateTexture(nil, "OVERLAY")
    p.icon:SetAllPoints()
    if p.icon.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestNormal") then
        p.icon:SetAtlas("QuestNormal")
    else
        p.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    end
    mini[i] = p
    return p
end

local list, listMap, listAt = nil, nil, 0
local function givers(map)
    if list and listMap == map and GetTime() - listAt < 5 then return list end
    list, listMap, listAt = {}, map, GetTime()
    for _, e in ipairs((SFP.QuestGivers and SFP.QuestGivers[map]) or {}) do
        local qs = available(e)
        if qs and #qs > 0 then
            local wx, wy = worldPos(map, e[2] / 100, e[3] / 100)
            if wx then list[#list + 1] = { wx = wx, wy = wy } end
        end
    end
    for _, g in ipairs(learnedGivers(map)) do
        local wx, wy = worldPos(map, g.x / 100, g.y / 100)
        if wx then list[#list + 1] = { wx = wx, wy = wy } end
    end
    return list
end

local acc = 0
local drv = CreateFrame("Frame")
drv:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.15 then return end
    acc = 0
    if not (SFP.db and SFP.db.questMarkers ~= false and Minimap and Minimap:IsVisible()) then
        for _, p in ipairs(mini) do p:Hide() end
        return
    end
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    local px, py
    if pos and pos.GetXY then px, py = pos:GetXY() end
    if not px or (issecretvalue and (issecretvalue(px) or issecretvalue(py))) or px <= 0 then for _, p in ipairs(mini) do p:Hide() end return end
    local mx, my = worldPos(map, px, py)
    local radius = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius() or 200
    if not mx or not radius or radius <= 0 then return end
    local rotate = (C_CVar and C_CVar.GetCVar or GetCVar)("rotateMinimap") == "1"
    local face = rotate and GetPlayerFacing() or 0
    local cs, sn = math.cos(face), math.sin(face)
    local scale = (Minimap:GetWidth() / 2) / radius
    local n = 0
    for _, g in ipairs(givers(map)) do
        -- world coordinates: x grows to the west and y to the north in the game's world; the difference is turned into the minimap's east and north
        local ex, ny = -(g.wx - mx), (g.wy - my)
        local x, y = ex * cs + ny * sn, -ex * sn + ny * cs
        if x * x + y * y <= radius * radius * 0.95 then
            n = n + 1
            local p = miniPin(n)
            p:ClearAllPoints()
            p:SetPoint("CENTER", Minimap, "CENTER", x * scale, y * scale)
            p:Show()
        end
    end
    for i = n + 1, #mini do mini[i]:Hide() end
end)
