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
        local ok = q.req <= lvl and (q.side == 0 or q.side == side or side == 0)
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

function QM:Draw()
    for _, p in ipairs(pins) do p:Hide() end
    if not (SFP.db and SFP.db.questMarkers ~= false and SFP.QuestGivers and WorldMapFrame and WorldMapFrame:IsShown()) then return end
    local map = WorldMapFrame:GetMapID()
    local list = map and SFP.QuestGivers[map]
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
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:SetScript("OnEvent", function() if WorldMapFrame:IsShown() then draw() end end)
end)

-- the old call of WorldMap.lua (zones of quests): nothing more to draw there
function QM:DrawZones() end
