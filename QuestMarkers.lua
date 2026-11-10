-- SeviathsUsefulTools - WoW Forever: the quests you can pick up, as yellow exclamation marks on the world map.
-- Quest givers come from Data/QuestGivers.lua (Wowhead); what you can take is decided from your own character: the quest is not done, not in your log,
-- you have the level for it and it is for your faction. The game's own "?" marks for the quests in your log stay as they are.

local _, SFP = ...

local QM = { enabled = true }
SFP.QuestMarkers = QM

local pins = {}
local shown = 0

-- is a quest already in your log? Every way the game offers is tried (the calls differ between versions); a log scan by quest number is the last
local logIDs, logAt
local function haveQuest(id)
    if C_QuestLog then
        if C_QuestLog.IsOnQuest then
            local ok, v = pcall(C_QuestLog.IsOnQuest, id)
            if ok and v then return true end
        end
        if C_QuestLog.GetLogIndexForQuestID then
            local ok, v = pcall(C_QuestLog.GetLogIndexForQuestID, id)
            if ok and v then return true end
        end
    end
    if GetNumQuestLogEntries and (GetQuestLogTitle or (C_QuestLog and C_QuestLog.GetInfo)) then
        if not logIDs or GetTime() - (logAt or 0) > 2 then
            logIDs, logAt = {}, GetTime()
            local n = GetNumQuestLogEntries() or 0
            for i = 1, n do
                local qid
                if C_QuestLog and C_QuestLog.GetInfo then
                    local ok, info = pcall(C_QuestLog.GetInfo, i)
                    qid = ok and type(info) == "table" and not info.isHeader and info.questID or nil
                elseif GetQuestLogTitle then
                    local _, _, _, isHeader, _, _, _, id2 = GetQuestLogTitle(i)
                    qid = (not isHeader) and id2 or nil
                end
                if qid then logIDs[qid] = true end
            end
        end
        return logIDs[id] == true
    end
    return false
end

-- the quests this character has had in its log or finished, kept by the addon (db.questsHad[character][quest]): scanned at login and whenever the log changes,
-- so a quest done before an update of the addon, or by a different route, is still known once it is seen in the log or turned in
local function charId()
    return (UnitName("player") or "?") .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or "")
end
local function noteHad(id)   -- only a quest that was turned in is kept: a quest started and then dropped can be taken again, so its giver keeps the mark
    if type(id) ~= "number" or not SFP.db then return end
    SFP.db.questsHad = SFP.db.questsHad or {}
    local t = SFP.db.questsHad[charId()]
    if not t then t = {}; SFP.db.questsHad[charId()] = t end
    t[id] = 2   -- 2 = turned in (an older save has true for every quest that was ever in the log: those are ignored)
end
local function hadQuest(id)
    local t = SFP.db and SFP.db.questsHad and SFP.db.questsHad[charId()]
    return t and t[id] == 2
end
local function scanLog()
    if not SFP.db then return end
    local n = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    for i = 1, n do
        local qid
        if C_QuestLog and C_QuestLog.GetInfo then
            local ok, info = pcall(C_QuestLog.GetInfo, i)
            qid = ok and type(info) == "table" and not info.isHeader and info.questID or nil
        elseif GetQuestLogTitle then
            local _, _, _, isHeader, _, _, _, id2 = GetQuestLogTitle(i)
            qid = (not isHeader) and id2 or nil
        end
        -- (a quest in the log is known by haveQuest; it is not noted as done here)
    end
end
QM.ScanLog = scanLog

local function playerFaction()
    local f = UnitFactionGroup("player")
    return f == "Alliance" and 1 or f == "Horde" and 2 or 0
end

-- the quests of one giver that the character can take: { { id, level, name }, ... }
-- Holiday event quests are offered only while their event is in the game's calendar. The event of a quest is told by its title (from memory of the events:
-- an approximation) and, for the Darkmoon Faire, by its quest numbers. Calendar names as the game shows them.
local EVENTS = {
    { cal = "Darkmoon", words = { "Darkmoon" } },
    { cal = "Hallow", words = { "Hallow's End", "Candy Bucket", "Smashing the Pumpkin", "Stinking Up", "Pumpkin" } },
    { cal = "Winter Veil", words = { "Winter Veil", "Greatfather", "Metzen", "Smokywood Pastures", "Reindeer" } },
    { cal = "Lunar", words = { "Lunar Festival", "Elune's Blessing", "Festive Lunar" } },
    { cal = "Love", words = { "Love is in the Air", "Bubbly", "Crown Chemical" } },
    { cal = "Midsummer", words = { "Midsummer", "Torch Tossing", "Ribbon Pole", "Fire Festival" } },
    { cal = "Harvest", words = { "Harvest Festival" } },
    { cal = "Brewfest", words = { "Brewfest" } },
    { cal = "Noblegarden", words = { "Noblegarden", "Spring Collection", "Painted Egg" } },
    { cal = "Children", words = { "Children's Week", "Orphan" } },
}
local onCache = {}
local function eventOn(cal)
    local c = onCache[cal]
    if c and GetTime() - c.at < 600 then return c.on end
    local on = false
    if C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent and C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        pcall(function()
            local now = C_DateAndTime.GetCurrentCalendarTime()
            for i = 1, (C_Calendar.GetNumDayEvents(0, now.monthDay) or 0) do
                local ev = C_Calendar.GetDayEvent(0, now.monthDay, i)
                if ev and type(ev.title) == "string" and ev.title:find(cal, 1, true) then on = true end
            end
        end)
    end
    onCache[cal] = { on = on, at = GetTime() }
    return on
end
local function eventOf(id, name)
    if (id >= 7881 and id <= 7999) or (id >= 8222 and id <= 8228) or id >= 80000 then return "Darkmoon" end
    if type(name) == "string" then
        for _, e in ipairs(EVENTS) do
            for _, w in ipairs(e.words) do if name:find(w, 1, true) then return e.cal end end
        end
    end
end
local function eventQuestOn(q)
    local cal = eventOf(q.id, q.name)
    return not cal or eventOn(cal)
end

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
        local ok = eventQuestOn(q) and q.req <= lvl and (q.side == 0 or q.side == 3 or q.side == side or side == 0)   -- (Wowhead: 1 Alliance, 2 Horde, 3 both)
        -- quests far above the level are not offered (the Darkmoon Faire quests of level 60 need only level 1, but are not for a level 6 character)
        if ok and q.level > 0 and q.level > lvl + 6 then ok = false end
        -- (quests below your level always show: a low-level quest can still be taken)
        -- a quest of a chain is offered only when the one before it is done
        local prev = (SFP.QuestPrereq and SFP.QuestPrereq[q.id]) or (SFP.db.learnedPrereq and SFP.db.learnedPrereq[q.id])
        if ok and prev and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and not C_QuestLog.IsQuestFlaggedCompleted(prev) then ok = false end
        if ok and C_QuestLog then
            if C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(q.id) then ok = false end
            if ok and (haveQuest(q.id) or hadQuest(q.id)) then ok = false end
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
            t:AddLine((q.level and q.level > 0) and ("[%d] %s"):format(q.level, q.name) or tostring(q.name), 1, 1, 1)
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
-- what the game shows while you play: the giver of a quest (where you stood, the name of the quest NPC), its level and title, and the chain: a quest
-- offered shortly after another was turned in follows it. Saved in db.learnedQuests and db.learnedPrereq; the marks use them when the shipped data lacks it.
local function learnQuest(questID)
    if type(questID) ~= "number" or questID <= 0 or not SFP.db then return end
    local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
    local pos = okM and map and C_Map.GetPlayerMapPosition(map, "player")
    local x, y
    if pos and pos.GetXY then x, y = pos:GetXY() end
    local nm = UnitName("questnpc")
    if type(nm) ~= "string" or (issecretvalue and issecretvalue(nm)) then nm = nil end
    SFP.db.learnedQuests = SFP.db.learnedQuests or {}
    local rec = SFP.db.learnedQuests[questID] or {}
    SFP.db.learnedQuests[questID] = rec
    if nm and map and x and x > 0 and not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then rec.g, rec.m, rec.x, rec.y = nm, map, x * 100, y * 100 end
    local okL, lvl = pcall(function() return C_QuestLog.GetQuestDifficultyLevel and C_QuestLog.GetQuestDifficultyLevel(questID) end)
    if okL and type(lvl) == "number" and lvl > 0 then rec.l = lvl end
    local okT, title = pcall(function() return C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) end)
    if okT and type(title) == "string" and title ~= "" then rec.t = title end
    -- the text of the quest (its description and objective): the names in it say what comes before and after
    local function safeText(fn)
        local ok, t = pcall(fn)
        return (ok and type(t) == "string" and not (issecretvalue and issecretvalue(t))) and t or ""
    end
    local txt = (safeText(GetObjectiveText or function() return "" end) .. " " .. safeText(GetQuestText or function() return "" end)):lower()
    if txt:gsub("%s", "") ~= "" then rec.o = txt:sub(1, 700) end
    -- the chain, guessed from names: a quest that is given by an NPC (or called by a title) that an earlier quest speaks of follows that quest.
    -- A quest A is the one before B when the text of A names the giver of B (or the title of B) and A is not above B in level.
    if rec.g and not (SFP.QuestPrereq and SFP.QuestPrereq[questID]) then
        local gname = rec.g:lower()
        local best, bestLvl
        for aid, a in pairs(SFP.db.learnedQuests) do
            if aid ~= questID and type(a) == "table" and type(a.o) == "string" and a.g ~= rec.g
               and (a.o:find(gname, 1, true) or (rec.t and #rec.t > 6 and a.o:find(rec.t:lower(), 1, true))) and (a.l or 0) <= (rec.l or 99) then
                if not best or (a.l or 0) > (bestLvl or 0) then best, bestLvl = aid, a.l or 0 end
            end
        end
        -- and the other way: this quest's own text names the giver of a quest that was learned earlier: that one is after this one (not stored here)
        if best then
            SFP.db.learnedPrereq = SFP.db.learnedPrereq or {}
            SFP.db.learnedPrereq[questID] = best
        end
    end
end
QM.LearnQuest = learnQuest

-- the title of a quest: what the character saw, else the Codex, else the game's own quest log data
local function questTitle(qid, rec)
    if type(rec) == "table" and type(rec.t) == "string" and rec.t ~= "" then return rec.t end
    local cdb = _G.SeviathsCodexDB
    local qr = cdb and type(cdb.quests) == "table" and cdb.quests[qid]
    if type(qr) == "table" and type(qr.t) == "string" and qr.t ~= "" then return qr.t end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, t = pcall(C_QuestLog.GetTitleForQuestID, qid)
        if ok and type(t) == "string" and t ~= "" and not (issecretvalue and issecretvalue(t)) then return t end
    end
end

local function learnedQuestGivers(map)
    local out = {}
    for qid, r in pairs((SFP.db and SFP.db.learnedQuests) or {}) do
        if type(r) == "table" and r.m == map and r.g and r.x then
            local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(qid)
            local inLog = haveQuest(qid) or hadQuest(qid)
            local prev = (SFP.QuestPrereq and SFP.QuestPrereq[qid]) or (SFP.db.learnedPrereq and SFP.db.learnedPrereq[qid])
            -- a quest this character has learned was taken by it, so the quest before it was done (the chain is only a guess from names): it is never blocked
            local blocked = false
            if not done and not inLog and not blocked then
                local nm, lv = questTitle(qid, r), r.l
                if not lv then
                    local cdb = _G.SeviathsCodexDB
                    local qr = cdb and type(cdb.quests) == "table" and cdb.quests[qid]
                    lv = type(qr) == "table" and tonumber(qr.l) or 0
                    if lv == 30 then lv = 0 end
                end
                out[#out + 1] = { n = r.g, x = r.x, y = r.y, q = { id = qid, level = lv or 0, name = nm or ("Quest " .. qid) } }
            end
        end
    end
    return out
end

local function learnedGivers(map)
    local cdb = _G.SeviathsCodexDB
    local out = {}
    if not (cdb and type(cdb.qloc) == "table") then return out end
    local lvl = UnitLevel("player")
    for qid, rec in pairs(cdb.qloc) do
        local g = type(rec) == "table" and rec.g
        if type(qid) == "number" and type(g) == "table" and g.m == map and g.x and g.y and g.n then
            local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(qid)
            local inLog = haveQuest(qid) or hadQuest(qid)
            local qr = type(cdb.quests) == "table" and cdb.quests[qid]
            -- a quest the Codex has no title for is from another game (the numbers of retail quests): not shown
            if not done and not inLog and type(qr) == "table" and type(qr.t) == "string" and qr.t ~= "" then
                local title = qr.t
                local ql = type(qr) == "table" and tonumber(qr.l) or 0
                if ql == 30 then ql = 0 end   -- 30 = level not known
                do   -- (low-level quests always show)
                    out[#out + 1] = { n = g.n, x = g.x * 100, y = g.y * 100, q = { id = qid, level = ql, name = title } }
                end
            end
        end
    end
    for _, g in ipairs(learnedQuestGivers(map)) do out[#out + 1] = g end
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
    C_Timer.After(3, function() SFP:Safe("scan quest log", scanLog) end)
    ev:RegisterEvent("QUEST_TURNED_IN")
    ev:RegisterEvent("QUEST_ACCEPTED")
    ev:RegisterEvent("QUEST_DETAIL")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:SetScript("OnEvent", function(_, event, ...)
        if event == "QUEST_TURNED_IN" then noteHad((...)) end
        if event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" then SFP:Safe("scan quest log", scanLog) end
        if event == "QUEST_DETAIL" then SFP:Safe("learn quest", learnQuest, GetQuestID and GetQuestID()) end
        if event == "QUEST_ACCEPTED" then SFP:Safe("learn quest", learnQuest, select(2, ...) or select(1, ...)) end
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

-- the map changes size when the quest log opens beside it or when it is zoomed: the marks are placed again from their map percent by the current size of the
-- map canvas (they were placed once when the map opened, at the size it had then)
local last = {}
local fixer = CreateFrame("Frame")
local acc = 0
fixer:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.2 then return end
    acc = 0
    if not (WorldMapFrame and WorldMapFrame:IsShown()) then return end
    local canvas = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
    if not canvas then return end
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local mapID = WorldMapFrame:GetMapID()
    if w == last.w and h == last.h and mapID == last.map then return end
    last.w, last.h, last.map = w, h, mapID
    SFP:Safe("quest markers", QM.Draw, QM)
end)

-- the old call of WorldMap.lua (zones of quests): nothing more to draw there
function QM:DrawZones() end
