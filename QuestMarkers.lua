-- SeviathsUsefulTools - WoW Forever: the quests you can pick up, as yellow exclamation marks on the world map.
-- Quest givers come from Data/QuestGivers.lua (Wowhead); what you can take is decided from your own character: the quest is not done, not in your log,
-- you have the level for it and it is for your faction. The game's own "?" marks for the quests in your log stay as they are.

local _, SFP = ...

local QM = { enabled = true }
SFP.QuestMarkers = QM

local pins = {}
local learnDone   -- (defined below; the drawing code uses it)
local shown = 0

-- is a quest already in your log? Every way the game offers is tried (the calls differ between versions); a log scan by quest number is the last
-- the quests picked up and not yet turned in or dropped: kept from the events of the game too (QUEST_ACCEPTED / QUEST_REMOVED / QUEST_TURNED_IN), because
-- the calls that ask the log differ between versions. Saved per character; a scan of the log replaces it when the log can be read.
local function takenSet()
    if not SFP.db then return {} end
    SFP.db.questsTaken = SFP.db.questsTaken or {}
    local k = (UnitName("player") or "?") .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or "")
    SFP.db.questsTaken[k] = SFP.db.questsTaken[k] or {}
    return SFP.db.questsTaken[k]
end
local logIDs, logAt
local function haveQuest(id)
    if takenSet()[id] then return true end
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
-- the whole account: a quest that any of your characters finished (or had) is known, so its mark is not shown again on another character
local function hadQuest(id)
    local all = SFP.db and SFP.db.questsHad
    if not all then return false end
    for _, t in pairs(all) do
        if type(t) == "table" and (t[id] == 2 or t[id] == true) then return true end
    end
    return false
end
-- is a quest finished? Every way the game offers is asked (they differ between versions): the flag, the list of finished quests, and the quests this addon saw
-- turned in. An older save of this addon noted every quest it ever saw in the log (true): that stays counted as done, so the quests done before stay hidden.
local doneList, doneAt
local function isDone(id)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, v = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
        if ok and v then return true end
    end
    if GetTime() - (doneAt or -999) > 30 then
        doneAt, doneList = GetTime(), {}
        local fn = (C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs) or GetQuestsCompleted
        if fn then
            local ok, t = pcall(fn, doneList)
            if ok and type(t) == "table" then
                for k, v in pairs(t) do if type(v) == "number" then doneList[v] = true elseif v == true then doneList[k] = true end end
            end
        end
    end
    if doneList and doneList[id] then return true end
    return hadQuest(id)   -- (every character of the account)
end

-- does this game have the quest at all? The shipped data comes from Wowhead and holds quests of other versions of the game (Season of Discovery, retail-era
-- events ...). The game itself is asked once per quest (C_QuestLog.RequestLoadQuestByID answers with QUEST_DATA_LOAD_RESULT) and the answer is kept
-- (db.questValid[id]); a quest the game says it does not know is not shown. Without that call in the game, every quest is kept.
local asked, failed = {}, {}
local function questKnown(id)
    if not (C_QuestLog and C_QuestLog.RequestLoadQuestByID and SFP.db) then return true end
    SFP.db.questValid = SFP.db.questValid or {}
    local v = SFP.db.questValid[id]
    if v ~= nil then return v end
    local at = asked[id]
    if not at then
        asked[id] = GetTime()
        pcall(C_QuestLog.RequestLoadQuestByID, id)
        return false   -- shown once the game has answered
    end
    if GetTime() - at > 4 then return true end   -- no answer: the quest is kept (the call may not answer in this game)
    return false
end
QM.Known = questKnown

local function scanLog()
    if not SFP.db then return end
    local n = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    local found, count = {}, 0
    for i = 1, n do
        local qid
        if C_QuestLog and C_QuestLog.GetInfo then
            local ok, info = pcall(C_QuestLog.GetInfo, i)
            qid = ok and type(info) == "table" and not info.isHeader and info.questID or nil
        elseif GetQuestLogTitle then
            local _, _, _, isHeader, _, _, _, id2 = GetQuestLogTitle(i)
            qid = (not isHeader) and id2 or nil
        end
        if qid then found[qid] = true; count = count + 1 end
    end
    -- the log could be read: it is the truth; when it cannot (entries but no numbers), the events keep the set
    if count > 0 or n == 0 then
        local t = takenSet()
        for k in pairs(t) do t[k] = nil end
        for k in pairs(found) do t[k] = true end
    end
end
QM.ScanLog = scanLog
QM.IsDone, QM.InLog, QM.Had = isDone, haveQuest, hadQuest
-- for /sut qmark: what the addon knows about one quest number
function QM.Why(id)
    local flag
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, v = pcall(C_QuestLog.IsQuestFlaggedCompleted, id)
        flag = ok and tostring(v) or "error"
    end
    local kv = SFP.db and SFP.db.questValid and SFP.db.questValid[id]
    return ("flag=%s list=%s had=%s inLog=%s inGame=%s"):format(tostring(flag), tostring(doneList and doneList[id] or false), tostring(hadQuest(id)), tostring(haveQuest(id)), tostring(kv))
end

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

-- what a quest giver really offers: when you talk to one, the list of quests the game offers you is kept (name, place, your level). A shipped quest of that
-- giver that the game does not offer now (a prerequisite not done, done already, not in this game) is not marked, until your level changes.
local function noteOffers()
    if not SFP.db then return end
    local name = UnitName("npc")
    if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then return end
    local ids, any = {}, false
    if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
        local ok, list = pcall(C_GossipInfo.GetAvailableQuests)
        if ok and type(list) == "table" then
            for _, q in ipairs(list) do if type(q) == "table" and q.questID then ids[q.questID] = true; any = true end end
        end
    end
    local mp = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = mp and C_Map.GetPlayerMapPosition(mp, "player")
    local x, y
    if pos and pos.GetXY then x, y = pos:GetXY() end
    if not (mp and x and x > 0) or (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then return end
    -- a quest the game itself offered you is available: it is remembered (a rule of the database that wrongly hides it is overruled, as Questie does it)
    if any then
        SFP.db.questOffered = SFP.db.questOffered or {}
        local mine = SFP.db.questOffered[charId()] or {}
        SFP.db.questOffered[charId()] = mine   -- (per character: another class or race is not offered the same)
        for id in pairs(ids) do mine[id] = true end
    end
    SFP.db.npcOffered = SFP.db.npcOffered or {}
    SFP.db.npcOffered[name] = SFP.db.npcOffered[name] or {}
    local list = SFP.db.npcOffered[name]
    -- one record per place of that name
    local rec
    for _, r in ipairs(list) do if r.m == mp and math.abs(r.x - x * 100) < 6 and math.abs(r.y - y * 100) < 6 then rec = r break end end
    if not rec then rec = {}; list[#list + 1] = rec end
    rec.m, rec.x, rec.y, rec.lvl, rec.ids, rec.t = mp, x * 100, y * 100, UnitLevel("player"), ids, time()
end
QM.NoteOffers = noteOffers
local function notOffered(entry, qid, mp, lvl)
    local list = SFP.db and SFP.db.npcOffered and SFP.db.npcOffered[entry[1]]
    if not list then return false end
    for _, r in ipairs(list) do
        if r.m == mp and r.lvl == lvl and math.abs(r.x - entry[2]) < 6 and math.abs(r.y - entry[3]) < 6 and not r.ids[qid] then return true end
    end
    return false
end

-- chains that Wowhead's series boxes miss, found by playing: quest = the quest that must be turned in before it is offered
QM.PrereqFix = {
    [46] = 71,   -- Bounty on Murlocs (Guard Thomas) comes after the quest that starts at Rolf's corpse (Report to Thomas)
}

-- the quests the GAME says are on offer in a zone for this character (C_QuestOffer, the call behind the available-quest marks of the game's own map):
-- the one source that knows what a giver far away offers. Used only when the game has the call and has answered with quests at least once
-- (a game that answers with an empty list always is not trusted).
local offerSets, offerTrusted = {}, false
local function mapOffers(map)
    if not (map and C_QuestOffer and C_QuestOffer.GetQuestOffersForMap) then return nil end
    local c = offerSets[map]
    if c and GetTime() - c.at < 5 then return c.set end
    local ok, list = pcall(C_QuestOffer.GetQuestOffersForMap, map)
    if not ok or type(list) ~= "table" then return nil end
    local set, n = {}, 0
    for _, o in ipairs(list) do
        local id = type(o) == "table" and (o.questID or o.questId or o.id) or (type(o) == "number" and o)
        if type(id) == "number" then set[id] = true; n = n + 1 end
    end
    if n > 0 then offerTrusted = true end
    offerSets[map] = { set = set, at = GetTime() }
    return set
end
QM.MapOffers = mapOffers

---------------------------------------------------------------------------
-- The rules of the quest database (Data/QuestDB.lua, from Questie / QuestieDB): the same checks Questie makes before it marks a quest as available
---------------------------------------------------------------------------
local RACE_MASK = { [1] = 1, [2] = 2, [3] = 4, [4] = 8, [5] = 16, [6] = 32, [7] = 64, [8] = 128, [9] = 256, [10] = 512, [11] = 1024, [22] = 2097152,
    [24] = 8388608, [25] = 16777216, [26] = 33554432, [95] = 4294967296, [96] = 8589934592 }
local function hasBit(mask, flag) return (mask % (2 * flag)) >= flag end

local function raceOk(rc)
    if not rc or rc == 0 then return true end
    local _, _, raceID = UnitRace("player")
    local flag = RACE_MASK[raceID or 0]
    if not flag then return true end
    return hasBit(rc, flag)
end
local function classOk(cl)
    if not cl or cl == 0 then return true end
    local _, _, classID = UnitClass("player")
    if not classID then return true end
    return hasBit(cl, 2 ^ (classID - 1))
end

-- reputation (faction number -> standing value) and professions (skill number -> rank), read from the game now and then; nil when the game does not tell
local repCache, repAt, skillCache, skillAt
local function playerReps()
    if repCache and GetTime() - (repAt or 0) < 10 then return repCache end
    local t, ok = {}, false
    local okN, n = pcall(function()
        if C_Reputation and C_Reputation.GetNumFactions then return C_Reputation.GetNumFactions() end
        return GetNumFactions and GetNumFactions() or 0
    end)
    if okN and type(n) == "number" then
        for i = 1, n do
            local okI, id, value = pcall(function()
                if C_Reputation and C_Reputation.GetFactionDataByIndex then
                    local d = C_Reputation.GetFactionDataByIndex(i)
                    return d and d.factionID, d and d.currentStanding
                end
                local _, _, _, _, _, bar, _, _, _, _, _, _, _, fid = GetFactionInfo(i)
                return fid, bar
            end)
            if okI and type(id) == "number" and id > 0 and type(value) == "number" then t[id] = value; ok = true end
        end
    end
    repCache, repAt = ok and t or nil, GetTime()
    return repCache
end
local function playerSkills()
    if skillCache and GetTime() - (skillAt or 0) < 10 then return skillCache end
    local t, ok = {}, false
    local okN, n = pcall(function()
        if C_SkillInfo and C_SkillInfo.GetNumSkillLines then return C_SkillInfo.GetNumSkillLines() end
        return GetNumSkillLines and GetNumSkillLines() or 0
    end)
    if okN and type(n) == "number" then
        for i = 1, n do
            local okI, id, rank, header = pcall(function()
                if C_SkillInfo and C_SkillInfo.GetSkillLineInfo then
                    local d = C_SkillInfo.GetSkillLineInfo(i)
                    return d and d.skillID, d and d.rank, d and d.isHeader
                end
                return nil
            end)
            if okI and type(id) == "number" and not header then t[id] = rank or 0; ok = true end
        end
    end
    skillCache, skillAt = ok and t or nil, GetTime()
    return skillCache
end

local function spellKnown(id)
    if not id then return nil end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, v = pcall(C_SpellBook.IsSpellKnown, id)
        if ok then return v and true or false end
    end
    if IsPlayerSpell then
        local ok, v = pcall(IsPlayerSpell, id)
        if ok then return v and true or false end
    end
    return nil
end

-- the quest before: done, or (for a group) a quest exclusive with it done
local function preSingleOk(list)
    for _, id in ipairs(list) do if isDone(id) then return true end end
    return false
end
local function preGroupOk(list)
    for _, id in ipairs(list) do
        if id < 0 then
            if not isDone(-id) then return false end
        elseif not isDone(id) then
            local r = SFP.QDB[id]
            local ex = r and r.ex
            if not ex then return false end
            local any = false
            for _, e in ipairs(ex) do if isDone(e) then any = true break end end
            if not any then return false end
        end
    end
    return true
end

-- is this quest available to this character? (the order of Questie's QuestieDB.IsDoable; the level rules are those of this addon: quests below your level stay)
local function doable(id, rule, lvl)
    if isDone(id) then return false, "done" end
    if haveQuest(id) or hadQuest(id) then return false, "in your log" end
    -- repeatable, daily and weekly quests (the blue "!" of the game) are not marked
    local sf, fl = rule.sf or 0, rule.fl or 0
    if hasBit(sf, 1) or hasBit(fl, 4096) or hasBit(fl, 32768) then return false, "repeatable / daily" end
    if rule.ev and not eventOn(rule.ev) then return false, "event not on" end
    if SFP.db and SFP.db.questOffered and SFP.db.questOffered[charId()] and SFP.db.questOffered[charId()][id] then return true end   -- (a giver offered it to you: it is available whatever the rules say)
    if (rule.r or 0) > lvl then return false, "level " .. tostring(rule.r) end
    -- a quest of a higher level than yours is not marked (a level 60 quest that only asks for level 1 is for later)
    if (rule.l or 0) > lvl then return false, "quest level " .. tostring(rule.l) .. " above yours" end
    if rule.m and rule.m > 0 and lvl > rule.m then return false, "max level" end
    if not raceOk(rule.rc) then return false, "race" end
    if not classOk(rule.cl) then return false, "class" end
    if rule.ps and not preSingleOk(rule.ps) then return false, "quest before (one of " .. table.concat(rule.ps, ",") .. ")" end
    if not rule.ps and rule.pg and not preGroupOk(rule.pg) then return false, "quests before (all of " .. table.concat(rule.pg, ",") .. ")" end
    if rule.pa and not haveQuest(rule.pa) then return false, "parent quest " .. rule.pa .. " not in log" end
    if rule.nx and (isDone(rule.nx) or haveQuest(rule.nx)) then return false, "follow-up " .. rule.nx .. " started" end
    if rule.ex then for _, e in ipairs(rule.ex) do if isDone(e) or haveQuest(e) then return false, "exclusive with " .. e end end end
    if rule.mr or rule.xr then
        local reps = playerReps()
        if reps then
            if rule.mr and (reps[rule.mr[1]] == nil or reps[rule.mr[1]] < rule.mr[2]) then return false, "reputation" end
            if rule.xr and reps[rule.xr[1]] ~= nil and reps[rule.xr[1]] >= rule.xr[2] then return false, "reputation too high" end
        end
    end
    if rule.sk then
        local sk = playerSkills()
        if sk and (sk[rule.sk[1]] == nil or sk[rule.sk[1]] < rule.sk[2]) then return false, "profession" end
    end
    if rule.sp and rule.sp ~= 0 then
        local k = spellKnown(math.abs(rule.sp))
        if k ~= nil then
            if rule.sp > 0 and not k then return false, "spell not known" end
            if rule.sp < 0 and k then return false, "spell known" end
        end
    end
    if rule.bf and (isDone(rule.bf) or haveQuest(rule.bf)) then return false, "its quest is started" end
    if rule.br then for _, b in ipairs(rule.br) do if haveQuest(b) then return false, "breadcrumb in log" end end end
    if rule.db and haveQuest(rule.db) then return false, "disabled by a quest in log" end
    if rule.au and isDone(rule.au) then return false, "gone after " .. rule.au end
    if rule["as"] and not (isDone(rule["as"]) or haveQuest(rule["as"])) then return false, "needs " .. rule["as"] .. " started" end
    return true
end

-- could this character ever take the quest (race, class, not repeatable / event)? Used by the Questing Zone Planner to count the quests of a zone
QM.Eligible = function(id, forFaction)
    local r = SFP.QDB and SFP.QDB[id]
    if not r then return false end
    local sf, fl = r.sf or 0, r.fl or 0
    if hasBit(sf, 1) or hasBit(fl, 4096) or hasBit(fl, 32768) or r.ev then return false end
    return raceOk(r.rc) and classOk(r.cl)
end
QM.Doable = function(id) local r = SFP.QDB and SFP.QDB[id]; if not r then return nil, "not in the database" end return doable(id, r, UnitLevel("player") or 1) end

local function availableDB(entry)
    local lvl = UnitLevel("player")
    if type(lvl) ~= "number" then return nil end
    local f = entry[5]
    if f then
        local mine = UnitFactionGroup("player")
        if (f == "A" and mine == "Horde") or (f == "H" and mine == "Alliance") then return nil end
    end
    local mapNow = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local out = {}
    for _, id in ipairs(entry[4]) do
        local rule = SFP.QDB[id]
        if rule and doable(id, rule, lvl) and questKnown(id) then
            local okOffer = true
            if offerTrusted then
                local offers = mapOffers(mapNow)
                if offers and not offers[id] then okOffer = false end
            end
            if okOffer and not notOffered(entry, id, mapNow, lvl) then
                out[#out + 1] = { id = id, level = rule.l or 0, name = rule.n or ("Quest " .. id) }
            end
        end
    end
    return out
end

local function available(entry)
    if type(entry[4]) == "table" and SFP.QDB then return availableDB(entry) end
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
        if ok and not questKnown(q.id) then ok = false end   -- (a quest of another version of the game)
        -- a quest for another class or race (a rogue quest on a mage), and the quests of Season of Discovery, which this game does not have
        if ok and SFP.QuestReq and SFP.QuestReq[q.id] then
            local rq = SFP.QuestReq[q.id]
            local function has(mask, id) return mask == 0 or not id or (math.floor(mask / 2 ^ (id - 1)) % 2 == 1) end
            local _, _, classID = UnitClass("player")
            local _, _, raceID = UnitRace("player")
            if not has(rq[1], classID) or not has(rq[2], raceID) then ok = false end
        end
        if ok and SFP.QuestRepeat and SFP.QuestRepeat[q.id] then ok = false end   -- (repeatable and daily quests have a blue mark in the game: not marked here)
        if ok and SFP.QuestSoD and SFP.QuestSoD[q.id] and not (SFP.db.learnedQuests and SFP.db.learnedQuests[q.id]) then ok = false end
        local mapNow = WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
        if ok and offerTrusted then
            local offers = mapOffers(mapNow)
            if offers and not offers[q.id] then ok = false end   -- the game does not offer it to this character
        end
        if ok and notOffered(entry, q.id, WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID(), lvl) then ok = false end   -- (the giver was visited and did not offer it)
        -- (quests below your level always show: a low-level quest can still be taken)
        -- a quest of a chain is offered only when the one before it is done
        local prev = (SFP.QuestPrereq and SFP.QuestPrereq[q.id]) or QM.PrereqFix[q.id] or (SFP.db.learnedPrereq and SFP.db.learnedPrereq[q.id])
        if ok and prev and not isDone(prev) then ok = false end
        -- every quest the page of the quest lists as needed first (Data/QuestReqs.lua): all of them must be done
        local need = SFP.QuestNeeds and SFP.QuestNeeds[q.id]
        if ok and need then
            for _, nq in ipairs(need) do if not isDone(nq) then ok = false break end end
        end
        if ok and C_QuestLog then
            if isDone(q.id) then ok = false end
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
    p.icon = p:CreateTexture(nil, "OVERLAY", nil, 7)
    p:SetFrameStrata("FULLSCREEN")
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
            if SFP.db and SFP.db.questMarkerDebug == true and QM.Why then t:AddLine(("   #%d  %s"):format(q.id or 0, QM.Why(q.id or 0)), 0.55, 0.55, 0.55) end   -- (to find why a done quest still shows; /sut qdebug turns it off)
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
        if type(r) == "table" and r.m == map and r.g and r.x and not (SFP.QDB and SFP.QDB[qid]) then   -- (a quest of the database is marked from it, not from what was learned)
            local done = isDone(qid)
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
        if type(qid) == "number" and type(g) == "table" and g.m == map and g.x and g.y and g.n and not (SFP.QDB and SFP.QDB[qid]) then
            local done = isDone(qid)
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

local function hiddenGiver(name, map, x, y)
    do return false end   -- (marks are no longer hidden by hand: the addon has to find out itself)
    local h = SFP.db and SFP.db.hiddenQuestGivers
    return h and h[("%s|%d|%d,%d"):format(tostring(name), map or 0, math.floor(x + 0.5), math.floor(y + 0.5))] or false
end

function QM:Draw()
    SFP:Safe("learn finished quests", learnDone)   -- (at most every 20 seconds)
    for _, p in ipairs(pins) do p:Hide() end
    if not (SFP.db and SFP.db.questMarkers ~= false and (SFP.QStarts or SFP.QuestGivers) and WorldMapFrame and WorldMapFrame:IsShown()) then return end
    local map = WorldMapFrame:GetMapID()
    local list = map and ((SFP.QStarts and SFP.QStarts[map]) or (not SFP.QStarts and SFP.QuestGivers and SFP.QuestGivers[map]) or {})
    local canvas = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
    if not (list and canvas) then return end
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local n = 0
    for _, e in ipairs(list) do
        local qs = (not hiddenGiver(e[1], map, e[2], e[3])) and available(e) or nil
        if qs and #qs > 0 then
            n = n + 1
            local p = getPin(n, canvas)
            p.giver, p.quests, p.map, p.x, p.y = e[1], qs, map, e[2] / 100, e[3] / 100
            p:ClearAllPoints()
            p:SetPoint("CENTER", canvas, "TOPLEFT", p.x * w, -p.y * h)
            p:SetFrameLevel(canvas:GetFrameLevel() + 400)   -- above the map's own marks (your arrow, the quest circles)
            p:Show()
        end
    end
    -- learned by this character: shown when no known giver is within a few percent of the map
    for _, g in ipairs(learnedGivers(map)) do
        local near = false
        for _, e in ipairs(list) do
            if math.abs(e[2] - g.x) < 1.5 and math.abs(e[3] - g.y) < 1.5 then near = true break end
        end
        if not near and not hiddenGiver(g.n, map, g.x, g.y) then
            n = n + 1
            local p = getPin(n, canvas)
            p.giver, p.quests, p.map, p.x, p.y = g.n, { g.q }, map, g.x / 100, g.y / 100
            p:ClearAllPoints()
            p:SetPoint("CENTER", canvas, "TOPLEFT", p.x * w, -p.y * h)
            p:SetFrameLevel(canvas:GetFrameLevel() + 400)   -- above the map's own marks (your arrow, the quest circles)
            p:Show()
        end
    end
end

-- the finished quests of this character, asked of the game in every way it offers and kept in the addon's own list (db.questsHad), so they stay known:
-- the list of finished quests (newer games), the older query that answers with the event QUEST_QUERY_COMPLETE, and the single flag of each quest of the marks
local learnedAt = 0
learnDone = function(force, noQuery)
    if not SFP.db or (not force and GetTime() - learnedAt < 20) then return end
    learnedAt = GetTime()
    local got = 0
    local function take(t)
        if type(t) ~= "table" then return end
        for k, v in pairs(t) do
            local id = (type(v) == "number") and v or ((v == true) and type(k) == "number" and k) or nil
            if id then noteHad(id); got = got + 1 end
        end
    end
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        local ok, t = pcall(C_QuestLog.GetAllCompletedQuestIDs)
        if ok then take(t) end
    end
    if GetQuestsCompleted then
        local t = {}
        local ok, r = pcall(GetQuestsCompleted, t)
        take(type(r) == "table" and r or t)
    end
    if QueryQuestsCompleted and not noQuery then pcall(QueryQuestsCompleted) end   -- the answer comes as QUEST_QUERY_COMPLETE
    QM.learnedCount = got
    doneAt = nil   -- the list of isDone is read again
end
QM.LearnDone = learnDone

-- the zone name of the mark is drawn together with the other layers, and again when quests change
SFP:OnLogin(function()
    if not WorldMapFrame then return end
    local function draw() SFP:Safe("quest markers", QM.Draw, QM) end
    WorldMapFrame:HookScript("OnShow", draw)
    if hooksecurefunc and WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() C_Timer.After(0.05, draw) end) end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("QUEST_LOG_UPDATE")
    C_Timer.After(3, function() SFP:Safe("scan quest log", scanLog) end)
    pcall(ev.RegisterEvent, ev, "QUEST_QUERY_COMPLETE")   -- (an event this game does not have only skips)
    pcall(ev.RegisterEvent, ev, "QUEST_DATA_LOAD_RESULT")   -- (an event this game does not have only skips)
    pcall(ev.RegisterEvent, ev, "GOSSIP_SHOW")   -- (an event this game does not have only skips)
    pcall(ev.RegisterEvent, ev, "QUEST_REMOVED")   -- (an event this game does not have only skips)
    pcall(ev.RegisterEvent, ev, "QUEST_GREETING")   -- (an event this game does not have only skips)
    C_Timer.After(5, function() SFP:Safe("learn finished quests", learnDone, true) end)
    ev:RegisterEvent("QUEST_TURNED_IN")
    ev:RegisterEvent("QUEST_ACCEPTED")
    ev:RegisterEvent("QUEST_DETAIL")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:SetScript("OnEvent", function(_, event, ...)
        if event == "QUEST_TURNED_IN" then noteHad((...)) end
        if event == "QUEST_TURNED_IN" then takenSet()[(...)] = nil end
        if event == "QUEST_REMOVED" then takenSet()[(...)] = nil end
        if event == "QUEST_ACCEPTED" then
            local qid = select(2, ...) or select(1, ...)
            if type(qid) == "number" then takenSet()[qid] = true end
        end
        if event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then SFP:Safe("note offered quests", noteOffers) return end
        if event == "QUEST_DATA_LOAD_RESULT" then
            local qid, success = ...
            if type(qid) == "number" and SFP.db then
                SFP.db.questValid = SFP.db.questValid or {}
                if success then
                    SFP.db.questValid[qid] = true
                else
                    failed[qid] = (failed[qid] or 0) + 1
                    if failed[qid] >= 2 then SFP.db.questValid[qid] = false else pcall(C_QuestLog.RequestLoadQuestByID, qid) end
                end
                if not QM.redrawPending then
                    QM.redrawPending = true
                    C_Timer.After(0.5, function() QM.redrawPending = false; if WorldMapFrame and WorldMapFrame:IsShown() then draw() end end)
                end
            end
            return
        end
        if event == "QUEST_QUERY_COMPLETE" then SFP:Safe("learn finished quests", learnDone, true, true) end
        if event == "QUEST_LOG_UPDATE" then SFP:Safe("scan quest log", scanLog) end   -- (not at ACCEPTED: the log has not got the new quest yet then)
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
