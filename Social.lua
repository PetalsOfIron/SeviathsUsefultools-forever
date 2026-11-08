-- SeviathsUsefulTools - players and party
--
-- Player tooltip: item level (read with the game's inspect, for everybody), empty sockets and missing enchants,
-- and, for players who also have this addon, a small profile they share: collected mounts and pets, Mythic+ score,
-- dungeons and raid bosses done this week (numbers only), play style and what they dislike in a group.
-- The profile travels in addon messages (group, guild, or a whisper when you hover the player). No server, nothing leaves the game.

local _, SFP = ...

local S = {}
SFP.Social = S

local PREFIX = "SUTProfile"
local PROFILE_VERSION = 2

local function secret(v) return issecretvalue and issecretvalue(v) end

---------------------------------------------------------------------------
-- settings and the lists the player chooses from
---------------------------------------------------------------------------
-- styles the player can choose by hand; "auto" lets the addon decide from the numbers below
S.STYLES = {
    { "auto",     "Automatic (from my collections, Mythic+ and raids)" },
    { "relaxed",  "Relaxed, no pressure" },
    { "learning", "Learning the content" },
    { "social",   "Social, guild and friends" },
    { "housing",  "Housing fan" },
    { "speed",    "Fast runs and farming" },
    { "roleplay", "Roleplayer" },
    { "farmer",   "Gold farmer" },
    { "collector", "Collector" },
    { "mythic",   (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT) and "Dungeon player" or "Hardcore Mythic+ player" },
    { "raider",   "Serious raider" },
    { "pvp",      "PvP player" },
    { "achiever", "Achievement hunter" },
    { "dailies",  "Daily quest player" },
    { "casual",   "Casual" },
    { "hardcore", "Serious player (plays to win)" },
}
local AUTO_LABEL = { raider = "Serious raider", mythic = (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT) and "Dungeon player" or "Hardcore Mythic+ player",
    delver = "Delve player", roleplayer = "Roleplayer", collector = "Collector",
    achiever = "Achievement hunter", pvp = "PvP player", dailies = "Daily quest player", farmer = "Gold farmer",
    gold = "Gold grinder", ["gold:loot"] = "Gold grinder (farming)", ["gold:daily"] = "Gold grinder (daily quests)",
    ["gold:trade"] = "Gold grinder (auction house)", housing = "Housing fan",
    alliance = "Alliance player", horde = "Horde player", altaholic = "Alt collector", casual = "Casual", hardcore = "Serious player", hardcoremode = "Hardcore (one life)" }
local STYLE_LABEL = { relaxed = "Relaxed", learning = "Learning", social = "Social", speed = "Fast runs and farming", roleplay = "Roleplayer" }

-- what a player can say they dislike in a group (the number is what is sent)
S.DISLIKES = {
    { 1,  "Leaving after one wipe" },
    { 2,  "Blaming players for wipes" },
    { 3,  "Rude or toxic chat" },
    { 4,  "Going AFK or being slow to come back" },
    { 5,  "Ignoring mechanics and interrupts" },
    { 6,  "Pulling before the group is ready" },
    { 7,  "Skipping trash or bosses" },
    { 8,  "Long explanations and too much talking" },
    { 9,  "Ninja looting or greeding everything" },
    { 10, "A silent group with no communication" },
    { 11, "Backseat playing, telling others how to play" },
    { 12, "Strict gear or score checks" },
}
local DISLIKE_TEXT = {}
for _, d in ipairs(S.DISLIKES) do DISLIKE_TEXT[d[1]] = d[2] end

function S.Config()
    SFP.db.social = SFP.db.social or {}
    local c = SFP.db.social
    if c.share == nil then c.share = true end        -- share my profile with other addon users
    if c.tip == nil then c.tip = true end            -- item level and profile on player tooltips
    -- the chat line about the group when it forms: off (nothing is printed in the chat by itself); a saved "on" from before is switched
    -- off once, after that the checkbox in the menu decides
    if c.groupLineQuietDone ~= true then c.groupLine = false; c.groupLineQuietDone = true end
    if c.groupLine == nil then c.groupLine = false end
    if c.style == nil then c.style = "auto" end
    c.dislikes = c.dislikes or {}
    c.stats = c.stats or {}
    return c
end

-- note this character (faction, class, level) so the account's characters are known: Alliance or Horde player, many alts
function S.RecordChar()
    local c = S.Config()
    c.chars = c.chars or {}
    local name = UnitName("player")
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or "?"
    if not name or secret(name) then return end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local _, class = UnitClass("player")
    -- the character as the nameplate would show it: level, class, race, faction, guild with rank, spec and the nameplate text
    local rec = { faction = faction, class = class, level = UnitLevel("player"), t = time() }
    local _, raceToken = UnitRace("player")
    rec.race = raceToken
    local okG, gName, gRank, gIndex = pcall(GetGuildInfo, "player")
    if okG and type(gName) == "string" and gName ~= "" then rec.guild, rec.rank, rec.rankIndex = gName, gRank, gIndex end
    local idx = GetSpecialization and GetSpecialization()
    if idx then
        local _, specName = GetSpecializationInfo(idx)
        if type(specName) == "string" then rec.spec = specName end
    end
    local okP, pvpName = pcall(UnitPVPName, "player")
    if okP and type(pvpName) == "string" and pvpName ~= "" then rec.plate = pvpName end
    c.chars[name .. "-" .. realm] = rec
end

-- The play style counters (activities, the week's numbers, the unique dungeons ...) are for the whole account: S.Char() is the account's table. Only the Done
-- list (dungeons entered, delves finished: S.MineDone) is kept per character.
function S.Char()
    return S.Config()
end

-- what the player DOES: activities are counted per day and kept for 28 days; the play style follows these counts
-- (raid bosses, Mythic+ keys, delves, new collectibles, achievements earned, PvP matches, daily quests, looting, gold by source)
local DAY, WINDOW_DAYS = 86400, 28
function S.Act(name, n)
    local c = S.Char()
    c.act = c.act or {}
    local day = math.floor(time() / DAY)
    local d = c.act[day]
    if not d then
        d = {}
        c.act[day] = d
        for k in pairs(c.act) do if k < day - WINDOW_DAYS then c.act[k] = nil end end
    end
    d[name] = (d[name] or 0) + (n or 1)
end

-- on how many of the last days (of 28) the player did this at all
function S.ActDays(...)
    local c = S.Char()
    local day = math.floor(time() / DAY)
    local n = 0
    for k, d in pairs(c.act or {}) do
        if k >= day - WINDOW_DAYS then
            for i = 1, select("#", ...) do
                if (d[select(i, ...)] or 0) > 0 then n = n + 1 break end
            end
        end
    end
    return n
end

-- the same, since the weekly reset (the play style is decided week by week; it starts again at every reset)
local function weekFromDay()
    local w
    local ok, s = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
    if ok and type(s) == "number" and not secret(s) then w = math.floor((time() + s - 7 * 86400) / 3600) * 3600 end
    return w and math.floor(w / DAY) or (math.floor(time() / DAY) - 6)
end

function S.ActWeekSum(name)
    local c = S.Char()
    local from, sum = weekFromDay(), 0
    for day, d in pairs(c.act or {}) do
        if day >= from then sum = sum + (d[name] or 0) end
    end
    return sum
end

function S.ActWeekDays(...)
    local c = S.Char()
    local from, n = weekFromDay(), 0
    for k, d in pairs(c.act or {}) do
        if k >= from then
            for i = 1, select("#", ...) do
                if (d[select(i, ...)] or 0) > 0 then n = n + 1 break end
            end
        end
    end
    return n
end

function S.ActSum(name)
    local c = S.Char()
    local sum, day = 0, math.floor(time() / DAY)
    for k, d in pairs(c.act or {}) do
        if k >= day - WINDOW_DAYS then sum = sum + (d[name] or 0) end
    end
    return sum
end

-- what you finished since the weekly reset: "dungeon" (a dungeon or a key), "raid" (a raid boss), "delve"
local function weekStart()
    local ok, s = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
    if ok and type(s) == "number" and not secret(s) then return math.floor((time() + s - 7 * 86400) / 3600) * 3600 end
    return nil
end

-- from before the weekly counters existed: the daily activity the addon already kept (days since the weekly reset)
local ACT_OF = { dungeon = "mythic", raid = "raid", delve = "delve" }
local function actThisWeek(name)
    local key, w = ACT_OF[name], weekStart()
    if not (key and w) then return 0 end
    local c = S.Char()
    local sum, from = 0, math.floor(w / DAY)
    for day, d in pairs(c.act or {}) do
        if day >= from then sum = sum + (d[key] or 0) end
    end
    return sum
end

function S.WeekGet(name)
    local c = S.Char()
    local w = weekStart()
    local own = (c.wk and w and c.wk.t == w) and (c.wk[name] or 0) or 0
    return math.max(own, actThisWeek(name))
end

function S.WeekAdd(name)
    local c = S.Char()
    local w = weekStart()
    if not w then return end
    if not (c.wk and c.wk.t == w) then c.wk = { t = w } end   -- a new week: counted from zero
    -- the same finish can arrive twice (two events): one count per minute and kind
    local now = time()
    if c.wk["last_" .. name] and now - c.wk["last_" .. name] < 60 and name ~= "raid" then return end
    c.wk["last_" .. name] = now
    c.wk[name] = (c.wk[name] or 0) + 1
    if name == "raid" then   -- a week with a raid in it (one boss is enough): the weeks in a row make a raider
        c.rweeks = c.rweeks or {}
        c.rweeks[w] = true
        for k in pairs(c.rweeks) do if k < w - 20 * 7 * 86400 then c.rweeks[k] = nil end end
    end
    -- the total in Midnight (all your characters): counted as you do them
    c.tot = c.tot or {}
    c.tot[name] = (c.tot[name] or 0) + 1
end

-- the weeks in a row (counting back from this week, or from last week when this one has no raid yet) with at least one raid boss
function S.RaidStreak()
    local c = S.Char()
    local w = weekStart()
    if not (w and c.rweeks) then return 0 end
    local WEEK = 7 * 86400
    local function had(t)
        for k in pairs(c.rweeks) do if math.abs(k - t) < 12 * 3600 then return true end end
        return false
    end
    local n, t = 0, w
    if not had(t) then t = t - WEEK end   -- this week's raid may still come
    while had(t) do n = n + 1; t = t - WEEK end
    return n
end

-- the dungeons, delves and raid bosses done this week, each ONCE: doing the same one again changes nothing. This is what the play style counts.
function S.UniqueAdd(kind, name)
    if type(name) ~= "string" or name == "" or secret(name) then return end
    local c = S.Char()
    local w = weekStart()
    if not w then return end
    if not (c.wku and c.wku.t == w) then c.wku = { t = w } end
    c.wku[kind] = c.wku[kind] or {}
    c.wku[kind][name:lower()] = true
end

function S.UniqueWeek(kind)
    local c = S.Char()
    local w = weekStart()
    local t = (c.wku and w and c.wku.t == w) and c.wku[kind]
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- gold made this week from monster drops and the auction house (copper): starts from zero at every weekly reset
function S.WeekGoldAdd(copper)
    local c = S.Char()
    local w = weekStart()
    if not w then return end
    if not (c.wk and c.wk.t == w) then c.wk = { t = w } end
    c.wk.gold = (c.wk.gold or 0) + copper
end

function S.WeekGoldGet()
    local c = S.Char()
    local w = weekStart()
    return (c.wk and w and c.wk.t == w) and math.floor((c.wk.gold or 0) / 10000) or 0
end

-- the game's own statistics of completed content, found in the Statistics panel by their names (no ID is guessed).
-- Statistics are per character: each character's number is saved and the total is their sum, so it is all your characters.
-- kind -> test on the lowercase statistic name
local STAT_KINDS = {
    delve = function(l) return l:find("delve", 1, true) and l:find("completed", 1, true) end,
    dungeon = function(l) return (l:find("keystone", 1, true) or l:find("mythic+", 1, true) or l:find("dungeon", 1, true)) and l:find("completed", 1, true) end,
    raid = function(l) return l:find("raid", 1, true) and (l:find("boss", 1, true) and (l:find("defeated", 1, true) or l:find("kill", 1, true))) end,
}

-- { kind = { rank, value, name } } best statistic per kind; the Midnight-named one wins, then the largest value.
-- The Statistics panel has thousands of entries: they are read a few milliseconds per frame (never all in one frame), and done(best, all) is called at the end.
local statRunning
local function scanStats(listAll, done)
    if not (GetStatisticsCategoryList and GetCategoryNumAchievements and GetAchievementInfo and GetStatistic) then if done then done(nil) end return end
    if statRunning then return end
    statRunning = true
    local best, all = {}, {}
    local cats = GetStatisticsCategoryList() or {}
    local ci, ai = 1, 1
    local function step()
        local t0 = debugprofilestop()
        while cats[ci] and debugprofilestop() - t0 < 4 do
            local cat = cats[ci]
            if ai > (GetCategoryNumAchievements(cat) or 0) then
                ci, ai = ci + 1, 1
            else
                local id, name = GetAchievementInfo(cat, ai)
                ai = ai + 1
                if type(name) == "string" and not secret(name) then
                    local l = name:lower()
                    for kind, test in pairs(STAT_KINDS) do
                        if test(l) then
                            local v = tonumber((tostring(GetStatistic(id) or ""):gsub("[^%d]", "")))
                            if v then
                                local rank = l:find("midnight", 1, true) and 2 or 1
                                local cur = best[kind]
                                if not cur or rank > cur.rank or (rank == cur.rank and v > cur.v) then best[kind] = { rank = rank, v = v, name = name } end
                                if listAll then all[#all + 1] = ("%s: %s = %d"):format(kind, name, v) end
                            end
                        end
                    end
                end
            end
        end
        if cats[ci] then
            C_Timer.After(0, step)
        else
            statRunning = false
            if done then done(best, all) end
        end
    end
    step()
end

function S.ReadStats()
    scanStats(false, function(best)
        if not best then return end
        local c = S.Config()
        local okN, n = pcall(UnitName, "player")
        local realm = GetNormalizedRealmName and GetNormalizedRealmName() or ""
        if not okN or type(n) ~= "string" then return end
        c.stat = c.stat or {}
        for kind, b in pairs(best) do
            c.stat[kind] = c.stat[kind] or {}
            c.stat[kind][n .. "-" .. realm] = b.v
        end
    end)
end
S.ReadDelveStat = S.ReadStats

-- /sfp stats: which statistics were found and used
function S.StatsDebug()
    scanStats(true, function(best, all)
        if not best then SFP:Print("the Statistics panel is not available") return end
        for _, line in ipairs(all) do SFP:Print(line) end
        for kind, b in pairs(best) do SFP:Print(("used for %s: %s = %d"):format(kind, b.name, b.v)) end
        if next(best) == nil then SFP:Print("no statistic with delve / dungeon / raid boss and completed / defeated in its name was found") end
    end)
end

function S.TotalGet(name)
    local c = S.Config()
    local own = (S.Char().tot and S.Char().tot[name]) or 0
    local sum = 0
    for _, v in pairs((c.stat and c.stat[name]) or {}) do sum = sum + v end
    return math.max(own, sum)   -- the game's number already holds the ones counted here
end

-- What THIS character has done: the dungeons entered and the delves finished, each once, by name (c.mine[character] = { dungeon = { name = true }, delve = { ... } }).
-- Every character has its own counters. The first character that logs in after the counters were made per character starts with what the
-- account had collected so far; the others start from nothing.
function S.CharKey()
    local okN, n = pcall(UnitName, "player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or ""
    if not okN or type(n) ~= "string" or secret(n) then return nil end
    return n .. "-" .. realm
end

function S.MineDone()
    local c = S.Config()
    local key = S.CharKey() or "?"
    c.mine = c.mine or {}
    local m = c.mine[key]
    if not m then
        m = { dungeon = {}, delve = {} }
        c.mine[key] = m
        if not c.mineSeeded then
            c.mineSeeded = true
            for n in pairs((c.lib and c.lib.dungeon) or {}) do m.dungeon[tostring(n):lower()] = true end
            for n in pairs((c.lib and c.lib.delve) or {}) do m.delve[tostring(n):lower()] = true end
            for n in pairs((c.done and c.done.delve) or {}) do m.delve[tostring(n):lower()] = true end
        end
    end
    -- once: the dungeons of the list counted every dungeon entered; now only Mythic+ ones do, so the old entries are dropped and the list starts again
    if not m.dunMplus then m.dunMplus = true; m.dungeon = {} end
    return m
end

-- The instances you enter are collected (all your characters): raids, dungeons and delves, with how often and on which difficulty.
-- c.lib = { raid = { [name] = { id, n (visits), t (last), diffs = { [difficulty name] = true } } }, dungeon = {...}, delve = {...} }
-- the Done list counts only the real content: a dungeon only as a Mythic+ (the keystone difficulty), raid bosses only from Heroic, and only at the maximum level
-- WoW Forever has no delves and no Mythic+: its Done list is the dungeons you entered and the raid bosses you killed (any level, any difficulty)
local FOREVER = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
local HEROIC_RAID = { [15] = true, [16] = true, [5] = true, [6] = true, [193] = true, [194] = true }
local function atMaxLevel()
    local lvl = UnitLevel and UnitLevel("player")
    local max = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 90
    return type(lvl) == "number" and not secret(lvl) and lvl >= max
end
S.AtMaxLevel = atMaxLevel

function S.NoteInstance()
    local ok, name, itype, diffID, diffName, maxPlayers, _, _, instID = pcall(GetInstanceInfo)
    if not ok or type(name) ~= "string" or secret(name) or name == "" then return end
    local kind = (itype == "raid" and "raid") or (itype == "party" and "dungeon") or (itype == "scenario" and "delve") or nil
    if not kind then return end
    local c = S.Config()
    c.lib = c.lib or {}
    c.lib[kind] = c.lib[kind] or {}
    local rec = c.lib[kind][name]
    if not rec then
        rec = { id = instID, n = 0, diffs = {}, first = time() }
        c.lib[kind][name] = rec
    end
    -- this character's own list: delves, and the dungeons run as Mythic+ (not normal or heroic ones, not while leveling)
    if (kind == "delve" and not FOREVER) or (kind == "dungeon" and (FOREVER or (diffID == 8 and atMaxLevel()))) then S.MineDone()[kind][name:lower()] = true end
    -- a reload inside the same instance is not a new visit
    if not (rec.t and time() - rec.t < 120) then rec.n = rec.n + 1 end
    rec.t = time()
    rec.id = instID or rec.id   -- the game's instance ID
    if type(maxPlayers) == "number" and not secret(maxPlayers) and maxPlayers > 0 then rec.max = maxPlayers end
    if type(diffID) == "number" and not secret(diffID) then rec.diffIDs = rec.diffIDs or {}; rec.diffIDs[diffID] = true end
    -- the map and the Adventure Guide (journal) ID of the place, so the Codex page is found by ID and not only by name
    local okM, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if okM and type(mapID) == "number" and not secret(mapID) then
        rec.map = mapID
        if EJ_GetInstanceForMap then
            local okJ, jid = pcall(EJ_GetInstanceForMap, mapID)
            if okJ and type(jid) == "number" and jid > 0 then rec.jid = jid end
        end
    end
    if type(diffName) == "string" and diffName ~= "" and not secret(diffName) then rec.diffs[diffName] = true end
end

-- a boss killed in a dungeon or raid is saved with the place (c.lib[kind][place].bosses[boss name] = kills, and the encounter ID)
function S.NoteBoss(encounterID, bossName)
    if type(bossName) ~= "string" or secret(bossName) then return end
    local ok, name, itype = pcall(GetInstanceInfo)
    if not ok or type(name) ~= "string" then return end
    local kind = (itype == "raid" and "raid") or (itype == "party" and "dungeon") or nil
    local c = S.Config()
    local rec = kind and c.lib and c.lib[kind] and c.lib[kind][name]
    if not rec then return end
    rec.bosses = rec.bosses or {}
    local b = rec.bosses[bossName] or { n = 0 }
    b.n = b.n + 1
    b.id = (type(encounterID) == "number" and not secret(encounterID)) and encounterID or b.id
    b.t = time()
    rec.bosses[bossName] = b
end

-- quest places: where you accepted and where you turned in each quest (c.lib.quest[questID] = { title, map, x, y, t, doneMap, doneX, doneY })
function S.NoteQuestPlace(questID, turnedIn)
    if type(questID) ~= "number" or secret(questID) then return end
    local m = C_Map.GetBestMapForUnit("player")
    local pos = m and C_Map.GetPlayerMapPosition(m, "player")
    if not (pos and pos.GetXY) then return end
    local x, y = pos:GetXY()
    if not x or secret(x) or x <= 0 then return end
    local c = S.Config()
    c.lib = c.lib or {}
    c.lib.quest = c.lib.quest or {}
    local rec = c.lib.quest[questID]
    if not rec then
        local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
        rec = { title = (type(title) == "string" and not secret(title)) and title or nil }
        c.lib.quest[questID] = rec
    end
    local npc = SFP.lastQuestNpc
    if not (npc and time() - npc.t < 180) then npc = nil end
    if turnedIn then
        rec.doneMap, rec.doneX, rec.doneY = m, x, y
        if npc then rec.turnID, rec.turnName = npc.id, npc.n end
    else
        rec.map, rec.x, rec.y = m, x, y
        if npc then rec.giverID, rec.giverName = npc.id, npc.n end   -- taken from this NPC
    end
    rec.t = time()
end

-- What you have done against the whole of it, from the addon's libraries and the game:
--   delves: the distinct delves finished (counted as you finish them, all your characters) out of the Midnight delves in the Codex list
--   keys:   this season's Mythic+ dungeons you have a run in (the game's own record, so past runs count) out of the season's dungeons
--   raid:   the bosses killed in your raid lockouts this week out of the bosses in them
function S.Progress()
    local out = { delve = { 0, 0 }, key = { 0, 0 }, raid = { 0, 0 }, dun = { 0, 0 } }
    local cx = SFP_Module and select(2, SFP_Module("Codex"))
    local mineDone = S.MineDone()   -- this character's own list
    local done = mineDone.delve
    -- every delve: the Codex list plus the delves the game's group finder lists (a delve missing from our list is not lost)
    local dr = SFP_Module and select(2, SFP_Module("DungeonsRaids"))
    local names = {}
    for _, e in ipairs((cx and cx.DELVE_LIST) or {}) do names[e[1]:lower()] = true end
    for n in pairs((dr and dr.db and dr.db.delve and dr.db.delve.known) or {}) do
        local l = tostring(n):lower()
        local dup = false
        for have in pairs(names) do if have:find(l, 1, true) or l:find(have, 1, true) then dup = true break end end
        if not dup then names[l] = true end
    end
    for n in pairs((S.Config().lib and S.Config().lib.delve) or {}) do
        local l = n:lower()
        local dup = false
        for have in pairs(names) do if have:find(l, 1, true) or l:find(have, 1, true) then dup = true break end end
        if not dup then names[l] = true end
    end
    -- a delve finished that is in none of the lists (named by the game's instance name) counts too
    for dk in pairs(done) do
        if not names[dk] then
            local dup = false
            for have in pairs(names) do if have:find(dk, 1, true) or dk:find(have, 1, true) then dup = true break end end
            if not dup then names[dk] = true end
        end
    end
    -- a delve entered and recorded in the library (a visit) is a delve done: the completion event does not always fire
    local libDone = {}   -- (the visits are in this character's list now)
    -- each finished delve (by any record of it) is matched to ONE delve of the list - the exact name first, else a name that contains it - and the
    -- number done is the number of DIFFERENT delves matched: one delve done many times, or under two spellings, counts once
    local matched = {}
    local function matchOne(key)
        if names[key] then return key end
        for l in pairs(names) do
            if l:find(key, 1, true) or key:find(l, 1, true) then return l end
        end
    end
    for key in pairs(done) do local l = matchOne(key); if l then matched[l] = true end end
    for key in pairs(libDone) do local l = matchOne(key); if l then matched[l] = true end end
    for _ in pairs(names) do out.delve[2] = out.delve[2] + 1 end
    for _ in pairs(matched) do out.delve[1] = out.delve[1] + 1 end
    if C_ChallengeMode and C_ChallengeMode.GetMapTable and C_MythicPlus and C_MythicPlus.GetSeasonBestForMap then
        local ok, maps = pcall(C_ChallengeMode.GetMapTable)
        if ok and type(maps) == "table" then
            for _, id in ipairs(maps) do
                out.key[2] = out.key[2] + 1
                local okB, intime, overtime = pcall(C_MythicPlus.GetSeasonBestForMap, id)
                if okB and (intime or overtime) then out.key[1] = out.key[1] + 1 end
            end
        end
    end
    -- raids: the bosses of the current expansion's raids (Adventure Guide, through the Dungeons & Raids module) and the ones
    -- you killed this week on any difficulty
    local usedLibrary = false
    -- dungeons: this expansion's dungeons (Adventure Guide) and the ones you have entered (collected when you walk in)
    if dr and dr.PlaceTier and dr.db and dr.db.dungeon and GetServerExpansionLevel then
        if dr.LoadEJPlaces then pcall(dr.LoadEJPlaces, dr, "dungeon") end
        local cur, entered = GetServerExpansionLevel() + 1, mineDone.dungeon
        local list = {}
        for name in pairs(dr.db.dungeon.known or {}) do
            if dr:PlaceTier("dungeon", name) == cur then list[#list + 1] = name:lower() end
        end
        out.dun[2] = #list
        -- each dungeon you entered is matched to ONE dungeon of the list; the number done is the number of different dungeons matched
        local matched = {}
        for en in pairs(entered) do
            local el = tostring(en):lower()
            local hit
            for _, l in ipairs(list) do if l == el then hit = l break end end
            if not hit then
                for _, l in ipairs(list) do if l:find(el, 1, true) or el:find(l, 1, true) then hit = l break end end
            end
            if hit then matched[hit] = true end
        end
        for _ in pairs(matched) do out.dun[1] = out.dun[1] + 1 end
    end
    if (FOREVER or atMaxLevel()) and dr and dr.GetBosses and dr.ResolveInstance and dr.PlaceTier and dr.GetMyKills and dr.db and dr.db.raid and GetServerExpansionLevel then
        local cur = GetServerExpansionLevel() + 1
        if dr.LoadEJPlaces then pcall(dr.LoadEJPlaces, dr, "raid") end   -- the raid list with its expansions, read once
        for name in pairs(dr.db.raid.known or {}) do
            if dr:PlaceTier("raid", name) == cur then
                local okR, inst = pcall(dr.ResolveInstance, dr, { name }, true)
                if okR and inst then
                    local bosses = dr:GetBosses(inst)
                    if #bosses > 0 then
                        usedLibrary = true
                        out.raid[2] = out.raid[2] + #bosses
                        local killed = {}
                        for _, diff in ipairs(FOREVER and { "N", "H", "M" } or { "H", "M" }) do   -- retail: from Heroic, Normal and the finder do not count
                            local okK, k = pcall(dr.GetMyKills, dr, inst.name, diff)
                            if okK and type(k) == "table" then for b in pairs(k) do killed[b] = true end end
                        end
                        for _, b in ipairs(bosses) do if killed[b.name] then out.raid[1] = out.raid[1] + 1 end end
                    end
                end
            end
        end
    end
    if not usedLibrary and (FOREVER or atMaxLevel()) and GetNumSavedInstances then
        for i = 1, GetNumSavedInstances() do
            local _, _, _, savedDiff, locked, _, _, isRaid, _, _, numEnc, encProg = GetSavedInstanceInfo(i)
            if isRaid and locked and (FOREVER or HEROIC_RAID[savedDiff]) and type(numEnc) == "number" and type(encProg) == "number" then
                out.raid[2] = out.raid[2] + numEnc
                out.raid[1] = out.raid[1] + encProg
            end
        end
    end
    return out
end

-- a delve was finished: it is marked as done (matched to the Codex list by name)
function S.MarkDelveDone()
    local okI, name = pcall(GetInstanceInfo)
    if not okI or type(name) ~= "string" or secret(name) then return end
    local cx = SFP_Module and select(2, SFP_Module("Codex"))
    local c = S.Config()
    c.done = c.done or {}
    c.done.delve = c.done.delve or {}
    local l = name:lower()
    local mine = S.MineDone().delve
    for _, e in ipairs((cx and cx.DELVE_LIST) or {}) do
        local dn = e[1]:lower()
        if l:find(dn, 1, true) or dn:find(l, 1, true) then c.done.delve[dn] = true; mine[dn] = true return end
    end
    c.done.delve[l] = true
    mine[l] = true
end

-- small counters for the automatic play style (farm sessions started, auction scans, ...)
function S.Count(name)
    S.Act(name, 1)
end

---------------------------------------------------------------------------
-- my own numbers
---------------------------------------------------------------------------
local counts = { mounts = 0, pets = 0, decor = 0, t = 0 }
-- the last counts are kept in the saved data, so the tooltip has numbers right after login (before the background count is done)
local function saveCount(field, n)
    if SFP.db then SFP.db.myCounts = SFP.db.myCounts or {}; SFP.db.myCounts[field] = n end
end
local function shownCount(field)
    local n = counts[field] or 0
    if n > 0 then return n end
    return (SFP.db and SFP.db.myCounts and SFP.db.myCounts[field]) or 0
end

-- owned housing decor, counted over the addon's decor list with the game's catalog (a few hundred per frame)
local function countDecor()
    local H = C_HousingCatalog
    local data = SFP.DecorData
    if not (H and H.GetCatalogEntryInfoByItem and data) then return end
    local i, n = 1, 0
    local function step()
        local stop = math.min(#data, i + 149)
        while i <= stop do
            local itemID = data[i][1]
            if itemID and itemID > 0 then
                local ok, info = pcall(H.GetCatalogEntryInfoByItem, itemID, true)
                if ok and type(info) == "table" then
                    local own = math.max((tonumber(info.quantity) or 0) + (tonumber(info.numPlaced) or 0),
                        (tonumber(info.totalNumStored) or 0) + (tonumber(info.totalNumPlaced) or 0) + (tonumber(info.remainingRedeemable) or 0))
                    if own > 0 then n = n + 1 end
                end
            end
            i = i + 1
        end
        if i <= #data then
            C_Timer.After(0, step)
        else
            -- decor collected since the last count is collecting too (the collector play style)
            local prev = SFP.db and SFP.db.myCounts and SFP.db.myCounts.decor
            counts.decor = n
            saveCount('decor', n)
            if prev and n > prev then S.Act("c_decor", n - prev) end
        end
    end
    step()
end

local function countMounts()
    local MJ = C_MountJournal
    if not (MJ and MJ.GetMountIDs and MJ.GetMountInfoByID) then return end
    local ok, ids = pcall(MJ.GetMountIDs)
    if not ok or type(ids) ~= "table" then return end
    local i, n = 1, 0
    local function step()
        local stop = math.min(#ids, i + 99)
        while i <= stop do
            local okI, _, _, _, _, _, _, _, _, _, _, collected = pcall(MJ.GetMountInfoByID, ids[i])
            if okI and collected == true then n = n + 1 end
            i = i + 1
        end
        if i <= #ids then
            C_Timer.After(0, step)
        else
            counts.mounts = n
            saveCount('mounts', n)
            counts.t = time()
        end
    end
    step()
end

local function refreshCounts()
    if C_PetJournal and C_PetJournal.GetNumPets then
        local ok, _, owned = pcall(C_PetJournal.GetNumPets)
        if ok and type(owned) == "number" then counts.pets = owned; saveCount('pets', owned) end
    end
    countMounts()
    countDecor()
end

local function vaultMax(typeName, fallback)
    if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities) then return 0 end
    local typ = (Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType[typeName]) or fallback
    local ok, acts = pcall(C_WeeklyRewards.GetActivities, typ)
    if not ok or type(acts) ~= "table" then return 0 end
    local best = 0
    for _, a in ipairs(acts) do
        if type(a.progress) == "number" and not secret(a.progress) and a.progress > best then best = a.progress end
    end
    return best
end

local function mplusScore()
    if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local ok, s = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
        if ok and type(s) == "table" and type(s.currentSeasonScore) == "number" then return math.floor(s.currentSeasonScore) end
    end
    return 0
end

-- the play style the addon decides on from the numbers: collections, Mythic+ and raids
-- is this character a Hardcore (one life) character? The game says so: the Hardcore rules call, the Hardcore aura, or a Hardcore realm
function S.IsHardcoreCharacter()
    if C_GameRules and C_GameRules.IsHardcoreActive then
        local ok, v = pcall(C_GameRules.IsHardcoreActive)
        if ok and v == true then return true end
    end
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, 1219201)   -- the Hardcore aura of the game
        if ok and a then return true end
    end
    local realm = GetRealmName and GetRealmName() or ""
    if type(realm) == "string" and not (issecretvalue and issecretvalue(realm)) and realm:lower():find("hardcore", 1, true) then return true end
    return false
end

function S.AutoStyles(p)
    -- by what the player DOES this week (it starts again at every weekly reset), never by how much they own: every activity gets a score
    -- (its count against what a regular player of it does), and the two strongest are the play style
    local a = p.act or {}
    local cand = {}
    -- a few runs make no style: an activity counts only after a lot of it (min), so three delves and something else is not a delver, and
    -- someone who keeps queuing for Mythic+ is a Mythic+ player
    -- and it has to come back on several days of the week: one day of three runs in a row and then nothing is no style either
    -- Short of the minimum it still counts when this was ALL the player did that week (nothing else but this, on several days): someone who only
    -- ran dungeons and delves, and never anything else, is a dungeon and a delve player (gold made on the way does not matter).
    local ALLKEYS = { "raid", "mythic", "dungeon", "delve", "collect", "achv", "pvp", "daily", "session" }
    local function onlyThis(...)
        local mine = {}
        for i = 1, select("#", ...) do mine[select(i, ...)] = true end
        for _, k in ipairs(ALLKEYS) do
            if not mine[k] and (a[k] or 0) > 0 then return false end
        end
        return true
    end
    local function add(id, count, regular, min, ...)
        count = count or 0
        if S.ActWeekDays(...) < (id == "collector" and 2 or 3) then return end   -- the collector is the easiest style to get
        if count >= (min or 1) or (count >= 3 and (id == "mythic" or id == "delver") and onlyThis("mythic", "dungeon", "delve")) then
            cand[#cand + 1] = { id = id, score = count / regular }
        end
    end
    -- Hardcore (one life): decided by the game, not by the numbers: a Hardcore character is a Hardcore player
    if S.IsHardcoreCharacter() then cand[#cand + 1] = { id = "hardcoremode", score = 99 } end
    add("raider", (p.u and p.u.raid) or 0, 8, 6, "raid")
    -- a raid every week, never skipping one (a single boss is enough), is a raid player: 4 weeks in a row or more
    if (p.rstreak or 0) >= 4 then cand[#cand + 1] = { id = "raider", score = 1 + (p.rstreak - 4) / 8 } end                  -- raid bosses killed (this week counts double)
    add("mythic", (p.u and p.u.dungeon) or 0, 8, 6, "mythic", "dungeon")   -- Mythic+ keys and dungeons
    add("delver", (p.u and p.u.delve) or 0, 8, 6, "delve")                 -- delves
    -- the collector: any one section reaches its number - 10 mounts in 28 days; 20 battle pets, toys, decor, old-raid mount bosses or pet battles
    -- in the week (rare kills do not count) (the weekly reset starts them again). The easiest style to get.
    do
        local sections = {
            { "c_mount", 10, false }, { "c_pet", 20, true }, { "c_toy", 20, true }, { "c_decor", 20, true }, { "c_raid", 20, true }, { "c_battle", 20, true },
        }
        local top = 0
        for _, sec in ipairs(sections) do
            local key, need, weekly = sec[1], sec[2], sec[3]
            local n = weekly and (a[key] or 0) or S.ActSum(key)   -- a: this week; ActSum: the last 28 days
            local days = weekly and S.ActWeekDays(key) or S.ActDays(key)
            if n >= need and days >= 2 then top = math.max(top, n / need) end
        end
        if top > 0 then cand[#cand + 1] = { id = "collector", score = top } end
    end
    add("achiever", a.achv, 30, 20, "achv")                                               -- achievements earned
    add("pvp", a.pvp, 10, 10, "pvp")                                                     -- PvP matches
    add("dailies", a.daily, 20, 20, "daily")                                               -- daily and world quests handed in
    add("farmer", (a.loot or 0) + (a.session or 0) * 40, 150, 200, "loot", "session")                -- monsters looted, farm sessions
    -- gold made THIS WEEK from monster drops and the auction house (it pays by mail); quest, world quest and vendor gold does not count. Under 60,000
    -- gold in the week it is not a style, and the count starts again at every weekly reset
    local weekGold = p.wgold or 0
    if weekGold >= 60000 then
        local id = ((a.g_trade or 0) > (a.g_loot or 0)) and "gold:trade" or "gold:loot"
        cand[#cand + 1] = { id = id, score = weekGold / 60000 + (a.scan or 0) / 40 }
    end
    -- a roleplayer: an OC written in the Roleplay page, or a character on a roleplay server (the name of the server ends in RP)
    do
        local rp = SFP.db and SFP.db.rp and SFP.db.rp.chars
        local hasOC = false
        for _, rec in pairs(rp or {}) do if type(rec) == "table" and (rec.name or "") ~= "" then hasOC = true break end end
        local key = SFP.RealmKey and SFP:RealmKey() or ""
        local rpServer = tostring(key):upper():find("RP$") or tostring(key):upper():find("RPPVP")
        if hasOC then cand[#cand + 1] = { id = "roleplayer", score = 6 }
        elseif rpServer then cand[#cand + 1] = { id = "roleplayer", score = 2 } end
    end
    -- the collector is the easiest style to reach, so any other style that is reached overwrites it
    for _, cd in ipairs(cand) do
        if cd.id ~= "collector" then
            for i = #cand, 1, -1 do if cand[i].id == "collector" then table.remove(cand, i) end end
            break
        end
    end
    -- one entry per style: the stronger one when a style was found twice (raider by the week and by the weeks in a row)
    local best = {}
    for _, cd in ipairs(cand) do if not best[cd.id] or cd.score > best[cd.id].score then best[cd.id] = cd end end
    cand = {}
    for _, cd in pairs(best) do cand[#cand + 1] = cd end
    table.sort(cand, function(x, y) if x.score ~= y.score then return x.score > y.score end return x.id < y.id end)
    local out = {}
    for i = 1, math.min(2, #cand) do out[#out + 1] = cand[i].id end   -- the two best
    -- the characters of the account (Alt data): most of them Alliance or Horde, and how many there are
    local total = (p.nAlliance or 0) + (p.nHorde or 0)
    if total >= 3 then
        if (p.nAlliance or 0) / total >= 0.6 then out[#out + 1] = "alliance"
        elseif (p.nHorde or 0) / total >= 0.6 then out[#out + 1] = "horde" end
    end
    if (p.nChars or 0) >= 8 then out[#out + 1] = "altaholic" end
    -- hardcore: heroic or mythic raids and Mythic+ keys of +5 and up this week; casual: anything that is not hardcore (quests, normal and raid finder raids, delves,
    -- normal and heroic dungeons, keys +0 to +4), never the hard kind
    if (a.hardcore or 0) >= 3 then
        out[#out + 1] = "hardcore"
    else
        -- casual: anyone who plays this week and does nothing hardcore - quests, normal content, anything that is not hardcore
        local did = 0
        for _, k in ipairs({ "quest", "daily", "easy", "raid", "mythic", "dungeon", "delve", "collect", "achv", "pvp", "loot", "session" }) do
            did = did + (a[k] or 0)
        end
        if did > 0 then out[#out + 1] = "casual" end
    end
    if #out == 0 then out[1] = "casual" end
    return out
end

local function styleLabels(list)
    local names = {}
    for _, id in ipairs(list) do names[#names + 1] = AUTO_LABEL[id] or STYLE_LABEL[id] or id end
    return table.concat(names, ", ")
end
S.StyleLabels = styleLabels

function S.MyProfile()
    local c = S.Config()
    local overall, equipped = GetAverageItemLevel and GetAverageItemLevel()
    local p = {
        ilvl = math.floor(tonumber(equipped) or tonumber(overall) or 0),
        mplus = mplusScore(),
        ach = (GetTotalAchievementPoints and tonumber(GetTotalAchievementPoints())) or 0,
        mounts = shownCount('mounts'), pets = shownCount('pets'), decor = shownCount('decor'),
        -- done this week: what the addon saw you finish, or the Great Vault row when that is higher
        dw = math.max(vaultMax("Activities", 2), S.WeekGet("dungeon")),
        rw = math.max(vaultMax("Raid", 1), S.WeekGet("raid")),
        dl = math.max(vaultMax("World", 6), S.WeekGet("delve")),
        prog = S.Progress(),   -- done out of the whole: delves, keys, raid bosses
        rstreak = S.RaidStreak(),   -- weeks in a row with a raid
        u = { dungeon = S.UniqueWeek("dungeon"), raid = S.UniqueWeek("raid"), delve = S.UniqueWeek("delve") },   -- unique ones this week
        wgold = S.WeekGoldGet(),   -- gold from monster drops and the auction house since the weekly reset
    }
    -- guild: guild master (rank 0) or officer
    p.role, p.guild = 0, ""
    if GetGuildInfo then
        local okG, gname, _, rankIndex = pcall(GetGuildInfo, "player")
        if okG and type(gname) == "string" and not secret(gname) then
            p.guild = gname:gsub("[;,]", " ")
            if (IsGuildLeader and IsGuildLeader()) or rankIndex == 0 then
                p.role = 2
            elseif C_GuildInfo and C_GuildInfo.IsGuildOfficer and C_GuildInfo.IsGuildOfficer() then
                p.role = 1
            end
        end
    end
    -- the account's characters, as the addon met them (it notes each one when you log in with it)
    p.nAlliance, p.nHorde, p.nChars = 0, 0, 0
    for _, ch in pairs(c.chars or {}) do
        p.nChars = p.nChars + 1
        if ch.faction == "Alliance" then p.nAlliance = p.nAlliance + 1 elseif ch.faction == "Horde" then p.nHorde = p.nHorde + 1 end
    end
    -- "always goes for gold": a lot of gold, farm sessions started, or many auction scans
    local st = c.stats or {}
    -- what the player did this week (the play style is decided from this)
    p.act = {}
    for _, k in ipairs({ "raid", "mythic", "dungeon", "delve", "collect", "achv", "pvp", "daily", "loot", "session", "scan", "easy", "hardcore", "quest", "c_pet", "c_toy", "c_decor", "c_raid", "c_battle",
        "g_loot", "g_daily", "g_quest", "g_trade", "g_other" }) do
        p.act[k] = S.ActWeekSum(k)
    end
    -- several styles can be chosen (c.styles = { id = true }); an older single choice is moved there once
    if c.style and c.style ~= "auto" and not c.styles then c.styles = { [c.style] = true }; c.style = "auto" end
    local chosen = {}
    for id, on in pairs(c.styles or {}) do if on then chosen[#chosen + 1] = id end end
    table.sort(chosen)
    if #chosen == 0 then
        p.style = S.AutoStyles(p)
    else
        p.style = chosen
    end
    local dis = {}
    for id, on in pairs(c.dislikes) do if on then dis[#dis + 1] = tonumber(id) end end
    table.sort(dis)
    p.dis = dis
    return p
end

---------------------------------------------------------------------------
-- the message
---------------------------------------------------------------------------
local function encode(p)
    return table.concat({
        "P", PROFILE_VERSION, p.ilvl, p.mplus, p.ach, p.mounts, p.pets, p.dw, p.rw, p.dl, p.decor,
        table.concat(p.style, ","), table.concat(p.dis, ","), p.role or 0, p.guild or "",
    }, ";")
end

local function split(str, sep)
    local out, pos = {}, 1
    while true do
        local a, b = str:find(sep, pos, true)
        if not a then out[#out + 1] = str:sub(pos); break end
        out[#out + 1] = str:sub(pos, a - 1)
        pos = b + 1
    end
    return out
end

local function decode(text)
    local f = split(text, ";")
    if f[1] ~= "P" or tonumber(f[2]) ~= PROFILE_VERSION then return nil end
    local rec = {
        t = time(), ilvl = tonumber(f[3]) or 0, mplus = tonumber(f[4]) or 0, ach = tonumber(f[5]) or 0,
        mounts = tonumber(f[6]) or 0, pets = tonumber(f[7]) or 0, dw = tonumber(f[8]) or 0, rw = tonumber(f[9]) or 0,
        dl = tonumber(f[10]) or 0, decor = tonumber(f[11]) or 0,
        style = {}, dis = {},
    }
    for id in (f[12] or ""):gmatch("[^,]+") do rec.style[#rec.style + 1] = id end
    for id in (f[13] or ""):gmatch("[^,]+") do rec.dis[#rec.dis + 1] = tonumber(id) end
    rec.role, rec.guild = tonumber(f[14]) or 0, f[15] or ""
    return rec
end

local peers = {}   -- ["Name" or "Name-Realm"] = decoded profile (only this session)
S.peers = peers

local function shortName(n) return (tostring(n):match("^[^-]+")) or tostring(n) end

local function unitKey(unit)
    local ok, n, r = pcall(UnitName, unit)
    if not ok or type(n) ~= "string" or secret(n) then return nil end
    if type(r) == "string" and r ~= "" and not secret(r) then return n .. "-" .. r end
    return n
end

function S.PeerOf(unit)
    local k = unitKey(unit)
    if not k then return nil end
    return peers[k] or peers[shortName(k)]
end

-- the players the addon whispered to (an addon message): if one is offline or does not exist, the game prints "No player named ... is
-- currently playing." in the chat; those lines are hidden for names the addon asked (nobody else's).
local askedNames = {}   -- lowercase name (with and without realm) -> time

local function send(text, channel, target)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    if channel == "WHISPER" and type(target) == "string" then
        local now = GetTime()
        askedNames[target:lower()] = now
        askedNames[((target:match("^([^-]+)")) or target):lower()] = now
    end
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, channel, target)
end

do
    local pattern
    local fmt = _G.ERR_CHAT_PLAYER_NOT_FOUND_S or "No player named '%s' is currently playing."
    pattern = "^" .. fmt:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, msg)
        if type(msg) ~= "string" or secret(msg) then return false end
        local name = msg:match(pattern)
        if not name then return false end
        local t = askedNames[name:lower()] or askedNames[((name:match("^([^-]+)")) or name):lower()]
        -- asked within the last 15 seconds: the line is hidden
        if t and GetTime() - t < 15 then return true end
        return false
    end)
end

local function groupChannel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

local lastBroadcast, lastReply, queried, lastQuery = 0, {}, {}, 0

-- your own talents as a short summary: { hero, matchName, matchPct } (nil when the advisor cannot read them)
local function mySummary()
    local TA = SFP.TalentAdvisor
    local idx = GetSpecialization and GetSpecialization()
    local specID, specName
    if idx then specID, specName = GetSpecializationInfo(idx) end
    local _, token = UnitClass("player")
    local cfg = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not (TA and TA.Summarize and cfg and specID) then return nil end
    local ok, t = pcall(TA.Summarize, cfg, specID, token, specName)
    return ok and t or nil
end

-- what is shared with a player who has the addon: the profile, your talent build ("T"), what it is ("S") and your gear check ("G")
local function sendProfile(channel, target)
    send(encode(S.MyProfile()), channel, target)
    -- done this week and in all of Midnight: dungeons and keys, raid bosses, delves ("W")
    local pr = S.Progress()
    send(("V;%d;%d;%d;%d;%d;%d;%d;%d"):format(pr.delve[1], pr.delve[2], pr.key[1], pr.key[2], pr.raid[1], pr.raid[2], pr.dun[1], pr.dun[2]), channel, target)
    local sum = mySummary()
    if sum and (sum.hero or sum.matchName) then
        local function clean(s) return (tostring(s or ""):gsub("[;]", ",")) end
        local function one(k)
            local p = sum.per and sum.per[k]
            return p and (clean(p.name) .. ";" .. math.floor(p.pct * 100 + 0.5)) or ";0"
        end
        send(("S;%s;%s;%d;%s;%s;%s"):format(clean(sum.hero), clean(sum.matchName), math.floor((sum.matchPct or 0) * 100 + 0.5),
            one("raid"), one("mythic"), one("delves")), channel, target)
    end
    local TA = SFP.TalentAdvisor
    local build = TA and TA.MyLoadout and TA.MyLoadout()
    if build and #build < 240 then send("T;" .. build, channel, target) end
    local GH = SFP.GemHelper
    local okG, g = false, nil
    if GH and GH.CheckUnit then okG, g = pcall(GH.CheckUnit, "player") end
    if okG and type(g) == "table" and g.any then
        send(("G;%d;%s;%s"):format(g.empty or 0, table.concat(g.emptyWhere or {}, ","), table.concat(g.missing or {}, ",")), channel, target)
    end
end

local function broadcastGroup(force)
    if not S.Config().share then return end
    local ch = groupChannel()
    if not ch then return end
    if not force and GetTime() - lastBroadcast < 30 then return end
    lastBroadcast = GetTime()
    sendProfile(ch)
end

local function replyTo(sender, delay)
    if not S.Config().share then return end
    local now = GetTime()
    if lastReply[sender] and now - lastReply[sender] < 20 then return end
    lastReply[sender] = now
    C_Timer.After(delay or 0, function() sendProfile("WHISPER", sender) end)
end

---------------------------------------------------------------------------
-- item level, sockets and enchants of other players: the game's inspect
---------------------------------------------------------------------------
local inspectCache = {}   -- [guid] = { t, ilvl, gear }
local pendingGUID, pendingUnit, lastInspect = nil, nil, 0

local function inspectFresh(guid)
    local c = inspectCache[guid]
    if c and time() - c.t < 300 then return c end
    return nil
end

local function requestInspect(unit)
    if InCombatLockdown and InCombatLockdown() then return end
    if GetTime() - lastInspect < 1.5 then return end
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then return end
    if not (CanInspect and NotifyInspect) then return end
    local okC, can = pcall(CanInspect, unit)
    if not okC or not can then return end
    if CheckInteractDistance and not CheckInteractDistance(unit, 1) then return end
    local okG, guid = pcall(UnitGUID, unit)
    if not okG or type(guid) ~= "string" or secret(guid) then return end
    lastInspect = GetTime()
    pendingGUID = guid
    pendingUnit = unit
    pcall(NotifyInspect, unit)
end

-- The gear of a player as numbers and names, kept with the inspect record: gems (name -> how many), enchants (slot -> name), the empty
-- sockets (where) and the enchantable slots without an enchant. gear is what GemHelper.CheckUnit returns.
function S.GearDetail(gear)
    if type(gear) ~= "table" or not gear.any then return nil end
    local d = { gems = {}, nGems = 0, enchants = {}, nEnchants = 0, empty = gear.empty or 0, emptyWhere = {}, missing = {} }
    for _, w in ipairs(gear.emptyWhere or {}) do d.emptyWhere[#d.emptyWhere + 1] = w end
    for _, m in ipairs(gear.missing or {}) do d.missing[#d.missing + 1] = m end
    for _, rec in pairs(gear.slots or {}) do
        for _, g in ipairs(rec.gems or {}) do d.gems[g] = (d.gems[g] or 0) + 1; d.nGems = d.nGems + 1 end
    end
    for _, es in ipairs(SFP.EnchantSlots or {}) do
        local rec = gear.slots and gear.slots[es.slot]
        -- an enchant counts when the item link carries one (its name is only a bonus: the tooltip text may not be readable)
        if rec and (rec.enchant or (rec.enchantID or 0) > 0) then d.enchants[es.label] = rec.enchant or true; d.nEnchants = d.nEnchants + 1 end
    end
    return d
end

-- the lines for gems and enchants: what the player has, and "No gems" / "No enchants" when there are none
function S.AddGearLines(tt, d)
    if type(d) ~= "table" then return end
    local names = {}
    for g, n in pairs(d.gems or {}) do names[#names + 1] = g .. (n > 1 and (" x" .. n) or "") end
    table.sort(names)
    if #names > 0 then tt:AddLine("Gems: |cffffffff" .. table.concat(names, ", ") .. "|r", 0.8, 0.8, 0.8, true)
    else tt:AddLine("|cffff8080No gems|r" .. ((d.empty or 0) > 0 and "" or " |cff808080(no sockets)|r"), 0.8, 0.8, 0.8, true) end
    if (d.empty or 0) > 0 then
        tt:AddLine(("Empty sockets (%d): %s"):format(d.empty, table.concat(d.emptyWhere or {}, ", ")), 1, 0.4, 0.4, true)
    end
    -- enchants: only whether he has them (how many of the enchantable slots), not which ones; what is missing is named, and counted
    local have = d.nEnchants or 0
    local lacking = #(d.missing or {})
    if have > 0 then
        tt:AddLine(("Enchants: |cffffffff%d of %d slots|r"):format(have, have + lacking), 0.8, 0.8, 0.8)
    else
        tt:AddLine("|cffff8080No enchants|r", 0.8, 0.8, 0.8, true)
    end
    if lacking > 0 then
        tt:AddLine(("Missing enchants (%d): %s"):format(lacking, table.concat(d.missing, ", ")), 1, 0.4, 0.4, true)
    end
end

-- the rest of an inspect: the record is kept (5 minutes in memory, for good in the saved data) and the inspect data is released
local function finishInspect(guid, unit, rec)
    inspectCache[guid] = rec
    -- kept for good (not only 5 minutes): the item level and the talent choice of the player, found again by name-realm
    do
        local key = S.NormKey and S.NormKey(unit)
        if key and SFP.db and (rec.ilvl or rec.talent) then
            SFP.db.inspected = SFP.db.inspected or {}
            SFP.db.inspected[key] = {
                ilvl = rec.ilvl, t = time(), spec = rec.spec,
                tal = rec.talent and { hero = rec.talent.hero, matchName = rec.talent.matchName, matchPct = rec.talent.matchPct } or nil,
                empty = rec.gear and rec.gear.any and rec.gear.empty or nil,
                missing = rec.gear and rec.gear.any and #rec.gear.missing or nil,
                gear = S.GearDetail(rec.gear),
            }
            -- the specialization goes into the player's record with level, class, race, faction and guild
            if rec.spec then
                SFP.db.seenInfo = SFP.db.seenInfo or {}
                local si = SFP.db.seenInfo[key] or {}
                si.spec = rec.spec
                si.t = si.t or time()
                SFP.db.seenInfo[key] = si
            end
        end
    end
    if ClearInspectPlayer then pcall(ClearInspectPlayer) end
    -- show the new numbers on the tooltip that is open
    if GameTooltip:IsShown() then
        local okT, _, tu = pcall(GameTooltip.GetUnit, GameTooltip)
        if okT and tu then
            local okU, g2 = pcall(UnitGUID, tu)
            if okU and g2 == guid then pcall(securecallfunction or function(fn, ...) return fn(...) end, GameTooltip.SetUnit, GameTooltip, tu) end
        end
    end
end

local function inspectReady(guid)
    if guid ~= pendingGUID then return end
    pendingGUID = nil
    local unit
    for _, u in ipairs({ pendingUnit or "mouseover", "mouseover", "target", "focus" }) do
        local ok, g = pcall(UnitGUID, u)
        if ok and type(g) == "string" and not secret(g) and g == guid then unit = u; break end   -- the secret check first: a secret value cannot be compared
    end
    if not unit then return end
    local rec = { t = time() }
    if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local ok, v = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        if ok and type(v) == "number" and not secret(v) and v > 0 then rec.ilvl = math.floor(v)
        elseif ok and type(v) == "number" and not secret(v) and v == 0 then
            -- a new low-level character has no gear that counts: the game answers 0, the item level is 1 (not "reading..." forever)
            local okL, lvl = pcall(UnitLevel, unit)
            if okL and type(lvl) == "number" and not secret(lvl) and lvl > 0 and lvl < 10 then rec.ilvl = 1 end
        end
    end
    local GH = SFP.GemHelper
    if GH then
        local ok, res = pcall(GH.CheckUnit, unit)
        if ok then rec.gear = res end
    end
    -- their talents (hero tree and the closest guide build), read while the inspect data is loaded
    local TA = SFP.TalentAdvisor
    if TA and TA.Summarize and GetInspectSpecialization and Constants and Constants.TraitConsts then
        local okS, specID = pcall(GetInspectSpecialization, unit)
        local okC, _, token = pcall(UnitClass, unit)
        if okS and okC and type(specID) == "number" and specID > 0 then
            local _, specName = GetSpecializationInfoByID(specID)
            rec.specID, rec.spec = specID, (type(specName) == "string" and not secret(specName)) and specName or nil
            local okT, t = pcall(TA.Summarize, Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID, specID, token, specName)
            if okT then rec.talent = t end
        end
    end
    -- the items of the player are often not loaded yet when the inspect answers (no gear, no gems, no enchants): the gear is read again a
    -- moment later, up to 4 times, before the record is finished; the inspect data stays loaded meanwhile
    local tries = 0
    local function attempt()
        tries = tries + 1
        if not (rec.gear and rec.gear.any) and GH then
            local okG, res = pcall(GH.CheckUnit, unit)
            if okG and res and res.any then rec.gear = res end
        end
        local okU, g = pcall(UnitGUID, unit)
        local same = okU and type(g) == "string" and not secret(g) and g == guid
        if (rec.gear and rec.gear.any) or tries >= 4 or not same then
            finishInspect(guid, unit, rec)
        else
            C_Timer.After(0.35, attempt)
        end
    end
    if rec.gear and rec.gear.any then finishInspect(guid, unit, rec) else C_Timer.After(0.35, attempt) end
end

---------------------------------------------------------------------------
-- the tooltip
---------------------------------------------------------------------------
local CY = "|cffffd100"

local function dislikeText(list, max)
    local names = {}
    for _, id in ipairs(list) do if DISLIKE_TEXT[id] then names[#names + 1] = DISLIKE_TEXT[id] end end
    if #names == 0 then return nil end
    if max and #names > max then
        local more = #names - max
        for i = #names, max + 1, -1 do names[i] = nil end
        names[#names + 1] = "+" .. more .. " more"
    end
    return table.concat(names, ", ")
end

-- Raider.IO as a helping tool (everyone uses it): its data file knows players of both factions. who is a unit token or a name,
-- realm the realm for a name. Returns the Mythic+ score and a raid progress text like "5/9 M" (nil for what it does not have).
-- The raid progress is read defensively: its table layout is not checked here, so a layout that differs gives no text.
local function rioInfo(who, realm)
    local RIO = _G.RaiderIO
    if not (RIO and RIO.GetProfile) then return nil end
    local ok, prof
    if realm then
        -- the realm as the game writes it in a name ("ArgentDawn"), as its display name ("Argent Dawn"), and the own realm's display name:
        -- the first one Raider.IO knows
        local tries = { realm }
        local spaced = realm:gsub("(%l)(%u)", "%1 %2")
        if spaced ~= realm then tries[#tries + 1] = spaced end
        local home = GetNormalizedRealmName and GetNormalizedRealmName()
        if home and realm == home and GetRealmName then tries[#tries + 1] = GetRealmName() end
        for _, r in ipairs(tries) do
            ok, prof = pcall(RIO.GetProfile, who, r)
            if ok and type(prof) == "table" then break end
            -- the one-string form "Name-Realm" (realm without spaces) is understood by Raider.IO too
            ok, prof = pcall(RIO.GetProfile, who .. "-" .. r:gsub("%s", ""))
            if ok and type(prof) == "table" then break end
        end
    else
        ok, prof = pcall(RIO.GetProfile, who)
    end
    if not ok or type(prof) ~= "table" then return nil end
    local mk = prof.mythicKeystoneProfile
    local score = type(mk) == "table" and (mk.currentScore or mk.mainCurrentScore) or nil
    if type(score) ~= "number" or secret(score) or score <= 0 then score = nil end
    -- the best run ("+16 MR": level and short name of the dungeon) and the timed runs of the highest milestone ("15+: 12")
    local extra = {}
    if type(mk) == "table" then
        local lvl = mk.maxDungeonLevel
        if type(lvl) == "number" and not secret(lvl) and lvl > 0 then
            local d = type(mk.maxDungeon) == "table" and (mk.maxDungeon.shortNameLocale or mk.maxDungeon.shortName) or nil
            extra.best = "+" .. lvl .. ((type(d) == "string" and not secret(d)) and (" " .. d) or "")
        end
        local wb = mk.warbandCurrentScore
        if type(wb) == "number" and not secret(wb) and wb > 0 then extra.warband = math.floor(wb) end
        -- the season of the previous score, as Raider.IO labels it (0-based id: S1, S2, Post-S1, S4)
        local ps = mk.previousScoreSeason
        if type(ps) ~= "number" and type(mk.mplusPrevious) == "table" then ps = mk.mplusPrevious.season end
        if type(ps) == "number" and not secret(ps) then extra.prevSeason = ({ "S1", "S2", "Post-S1", "S4" })[ps + 1] end
        local ms = type(mk.sortedMilestones) == "table" and mk.sortedMilestones[1] or nil
        if type(ms) == "table" and ms.level and ms.text and not secret(ms.text) then
            extra.timed = ms.level .. "+: " .. tostring(ms.text)
            -- Raider.IO's own label of that milestone ("Timed +12-14 Runs"), the count is extra.timed's text
            if type(ms.label) == "string" and not secret(ms.label) then extra.timedLabel = ms.label end
        end
    end
    -- the previous season's score: shown when there is no score this season yet
    local prev = type(mk) == "table" and mk.previousScore or nil
    if type(prev) ~= "number" or secret(prev) or prev <= 0 then prev = nil end
    local raidText
    local rp = prof.raidProfile
    local list = type(rp) == "table" and (rp.progress or rp.mainProgress) or nil
    local first = type(list) == "table" and list[1] or nil
    if type(first) == "table" then
        local pr = type(first.progress) == "table" and first.progress or first
        local killed = tonumber(pr.killed or pr.cleared or pr.progressCount)
        local total = tonumber((type(first.raid) == "table" and (first.raid.bossCount or first.raid.total)) or pr.total or first.total)
        local diff = pr.difficulty or first.difficulty
        local letter = (diff == 1 or diff == "N") and "N" or (diff == 2 or diff == "H") and "H" or (diff == 3 or diff == "M") and "M" or nil
        if killed and total and total > 0 and not secret(killed) then
            -- as Raider.IO writes it: the raid ("VA"), the difficulty, then the bosses killed
            local rn = type(first.raid) == "table" and (first.raid.shortNameLocale or first.raid.shortName or first.raid.name) or nil
            if type(rn) ~= "string" or secret(rn) then rn = nil end
            raidText = (rn and (rn .. " ") or "") .. (letter and (letter .. " ") or "") .. ("%d/%d"):format(killed, total)
        end
    end
    -- the main's raid progress as Raider.IO writes it: per raid "VA H 8/8 M 6/8" (difficulties in the order given), raids joined by ", "
    local mp = type(rp) == "table" and rp.mainProgress or nil
    if type(mp) == "table" then
        local order, byRaid = {}, {}
        for _, e in ipairs(mp) do
            if type(e) == "table" and type(e.raid) == "table" then
                local rn = e.raid.shortNameLocale or e.raid.shortName or e.raid.name
                local cnt = tonumber(e.progressCount or e.killed)
                local total = tonumber(e.raid.bossCount or e.raid.total)
                local d = e.difficulty
                local L = (d == 1 or d == "N") and "N" or (d == 2 or d == "H") and "H" or (d == 3 or d == "M") and "M" or nil
                if type(rn) == "string" and not secret(rn) and cnt and total and not secret(cnt) and L then
                    if not byRaid[rn] then byRaid[rn] = {}; order[#order + 1] = rn end
                    table.insert(byRaid[rn], L .. " " .. cnt .. "/" .. total)
                end
            end
        end
        local parts = {}
        for _, rn in ipairs(order) do parts[#parts + 1] = rn .. " " .. table.concat(byRaid[rn], " ") end
        if #parts > 0 then extra.main = table.concat(parts, ", ") end
    end
    return score, raidText, prev, extra
end

-- the realms a player without a realm in his name can be on: yours and the realms connected to yours (the game shows no realm for them)
local function realmCandidates()
    local out, seen = {}, {}
    local function add(r)
        if type(r) == "string" and not secret(r) and r ~= "" and not seen[r] then seen[r] = true; out[#out + 1] = r end
    end
    add(GetNormalizedRealmName and GetNormalizedRealmName())
    if GetAutoCompleteRealms then
        local ok, list = pcall(GetAutoCompleteRealms)
        if ok and type(list) == "table" then for _, r in ipairs(list) do add(r) end end
    end
    return out
end

-- Raider.IO for a name: with a realm in the name that realm; without one every realm it can be on, the first with data
local function rioFind(nm, realm)
    if realm then
        local a, b, c, d = rioInfo(nm, realm)
        return a, b, nil, c, d
    end
    -- a name without a realm: the realm found for it before, then the realms it can be on (yours, the connected ones, where this name
    -- was seen), then the search over every realm of the game runs in the background (S.QueueRealmSearch) and the answer is there
    -- on the next refresh
    local cache = SFP.db and SFP.db.nameRealm and SFP.db.nameRealm[nm]
    if cache and cache.realm then
        local sc, raidText, prev, extra = rioInfo(nm, cache.realm)
        if sc or raidText or prev then return sc, raidText, cache.realm, prev, extra end
    end
    local seen = SFP.db and SFP.db.nameRealms and SFP.db.nameRealms[nm]
    local first = {}
    if seen then first[#first + 1] = seen end
    for _, c in ipairs(realmCandidates()) do first[#first + 1] = c end
    for _, cand in ipairs(first) do
        local sc, raidText, prev, extra = rioInfo(nm, cand)
        if sc or raidText or prev then
            if SFP.db then SFP.db.nameRealm = SFP.db.nameRealm or {}; SFP.db.nameRealm[nm] = { realm = cand, t = time() } end
            return sc, raidText, cand, prev, extra
        end
    end
    if S.QueueRealmSearch then S.QueueRealmSearch(nm) end
    return nil
end

-- Raider.IO writes its own lines on a unit tooltip ("Raider.IO M+ Score", "Previous M+ Score (S1)", "Raider.IO Raid Progress" ...).
-- When they are there, this addon adds nothing of its own (no second copy); in a tooltip of a player by name, Raider.IO's own block is
-- asked for (RaiderIO.ShowProfile), so the text is exactly the one Raider.IO writes on the nameplate tooltip.
local function tooltipHasRio(tt)
    if not (tt and tt.NumLines and tt.GetName) then return false end
    local name = tt:GetName()
    if not name then return false end
    for i = 1, tt:NumLines() do
        local fs = _G[name .. "TextLeft" .. i]
        local t = fs and fs:GetText()
        if type(t) == "string" and not secret(t) and t:find("Raider.IO", 1, true) then return true end
    end
    return false
end

local function showRioBlock(tt, nm, realm)
    local RIO = _G.RaiderIO
    if not (RIO and RIO.ShowProfile and tt and tt.GetObjectType and tt:GetObjectType() == "GameTooltip") then return false end
    if type(realm) ~= "string" then return false end
    -- the realm spelled the ways Raider.IO may know it (as in rioInfo): the first one that shows its block
    local tries = { realm }
    local spaced = realm:gsub("(%l)(%u)", "%1 %2")
    if spaced ~= realm then tries[#tries + 1] = spaced end
    local home = GetNormalizedRealmName and GetNormalizedRealmName()
    if home and realm == home and GetRealmName then tries[#tries + 1] = GetRealmName() end
    for _, r in ipairs(tries) do
        local ok, shown = pcall(RIO.ShowProfile, tt, nm, r)
        if ok and shown then return true end
    end
    return false
end

-- The Raider.IO text of a player COPIED as Raider.IO writes it: Raider.IO's own block is rendered into a private tooltip (the same call it
-- makes for its nameplate tooltip) and every line is read back with its colours: { { l = left, r = right, lc = {r,g,b}, rc = {r,g,b} } }.
-- Saved with the player (db.rioLines), so the same text can be shown later, also for a player who is not near, and without Raider.IO.
local rioScanTip
local function captureRioLines(who, realm)
    local RIO = _G.RaiderIO
    if not (RIO and RIO.ShowProfile) then return nil end
    if not rioScanTip then rioScanTip = CreateFrame("GameTooltip", "SeviathsUsefulToolsRioScan", UIParent, "GameTooltipTemplate") end
    rioScanTip:SetOwner(UIParent, "ANCHOR_NONE")
    rioScanTip:ClearLines()
    local ok, shown = pcall(RIO.ShowProfile, rioScanTip, who, realm)
    local out
    if ok and shown then
        out = {}
        for i = 1, rioScanTip:NumLines() do
            local L = _G["SeviathsUsefulToolsRioScanTextLeft" .. i]
            local R = _G["SeviathsUsefulToolsRioScanTextRight" .. i]
            local l = L and L:GetText()
            local r = R and R:GetText()
            if type(l) == "string" and not secret(l) then
                local lr, lg, lb = L:GetTextColor()
                local rr, rg, rb = 1, 1, 1
                if R then rr, rg, rb = R:GetTextColor() end
                out[#out + 1] = { l = l, r = (type(r) == "string" and not secret(r) and r ~= "") and r or nil, lc = { lr, lg, lb }, rc = { rr, rg, rb } }
            end
        end
        if #out == 0 then out = nil end
    end
    rioScanTip:Hide()
    return out
end

local function readTipLines(tip, prefix)
    local out = {}
    for i = 1, tip:NumLines() do
        local L = _G[prefix .. "TextLeft" .. i]
        local R = _G[prefix .. "TextRight" .. i]
        local l = L and L:GetText()
        local r = R and R:GetText()
        if type(l) == "string" and not secret(l) then
            local lr, lg, lb = L:GetTextColor()
            local rr, rg, rb = 1, 1, 1
            if R then rr, rg, rb = R:GetTextColor() end
            out[#out + 1] = { l = l, r = (type(r) == "string" and not secret(r) and r ~= "") and r or nil, lc = { lr, lg, lb }, rc = { rr, rg, rb } }
        end
    end
    return out
end

-- The nameplate of a player COPIED: the game's tooltip of the unit and Raider.IO's own block, line by line.
local function captureNameplateText(unit)
    -- The game's own lines of the unit come from the tooltip DATA (C_TooltipInfo), not from a tooltip frame of ours told to show the unit:
    -- a frame made by an addon is tainted, and the game's health bar code fails on secret values when it runs there.
    local out = {}
    local okI, data = pcall(function() return C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit) end)
    if okI and type(data) == "table" and type(data.lines) == "table" then
        for _, ln in ipairs(data.lines) do
            local l, r = ln.leftText, ln.rightText
            if type(l) == "string" and not secret(l) and l ~= "" then
                local lc, rc = ln.leftColor, ln.rightColor
                local function col(c) return type(c) == "table" and { c.r or 1, c.g or 1, c.b or 1 } or { 1, 1, 1 } end
                out[#out + 1] = { l = l, r = (type(r) == "string" and not secret(r) and r ~= "") and r or nil, lc = col(lc), rc = col(rc) }
            end
        end
    end
    -- Raider.IO's own block: written into a private tooltip that is never told to show a unit
    local RIO = _G.RaiderIO
    if RIO and RIO.ShowProfile then
        if not rioScanTip then rioScanTip = CreateFrame("GameTooltip", "SeviathsUsefulToolsRioScan", UIParent, "GameTooltipTemplate") end
        rioScanTip:SetOwner(UIParent, "ANCHOR_NONE")
        rioScanTip:ClearLines()
        pcall(RIO.ShowProfile, rioScanTip, unit)
        for _, ln in ipairs(readTipLines(rioScanTip, "SeviathsUsefulToolsRioScan")) do out[#out + 1] = ln end
        rioScanTip:Hide()
    end
    if #out == 0 then return nil end
    return out
end

local function addRioLines(tt, lines)
    if type(lines) ~= "table" then return false end
    for _, ln in ipairs(lines) do
        if ln.r then tt:AddDoubleLine(ln.l, ln.r, ln.lc[1], ln.lc[2], ln.lc[3], ln.rc[1], ln.rc[2], ln.rc[3])
        else tt:AddLine(ln.l, ln.lc[1], ln.lc[2], ln.lc[3]) end
    end
    return #lines > 0
end

local function addProfileLines(tt, rec)
    tt:AddLine(CY .. "Seviaths|r")
    -- only what the player has: a number at 0 is left out, and a line with nothing on it is not shown
    local function parts(list)
        local out = {}
        for _, e in ipairs(list) do
            if (e[2] or 0) > 0 then out[#out + 1] = ("%s |cffffffff%d|r"):format(e[1], e[2]) end
        end
        return table.concat(out, "   ")
    end
    local l1 = parts({ { "Mythic+ score", rec.mplus }, { "Achievements", rec.ach } })
    local l2 = parts({ { "Mounts", rec.mounts }, { "Battle pets", rec.pets }, { "Housing decor", rec.decor } })
    local l3
    if rec.prog then
        -- done out of the whole: delves, dungeons, this season's keys, the bosses of this week's raids
        -- the number done is never below what was counted this week (a delve finished this week is a delve done)
        local function pair(label, p, floorN)
            if not (p and p[2] > 0) then return nil end
            local n = math.max(p[1], floorN or 0)
            return ("%s |cffffffff%d / %d|r"):format(label, n, math.max(p[2], n))
        end
        local out = {}
        local entries = FOREVER and { pair("dungeons", rec.prog.dun, rec.dw), pair("raid bosses", rec.prog.raid, rec.rw) }
            or { pair("delves", rec.prog.delve, rec.dl), pair("dungeons", rec.prog.dun, rec.dw), pair("keys", rec.prog.key), pair("raid bosses", rec.prog.raid, rec.rw) }
        for _, e in ipairs(entries) do out[#out + 1] = e end
        l3 = table.concat(out, "   ")
    elseif rec.tot then
        -- done this week / done in all of Midnight (counted by the addon as they are done)
        local out = {}
        for _, e in ipairs(FOREVER and { { "dungeons", rec.dw, rec.tot.dungeon }, { "raid bosses", rec.rw, rec.tot.raid } }
            or { { "delves", rec.dl, rec.tot.delve }, { "dungeons and keys", rec.dw, rec.tot.dungeon }, { "raid bosses", rec.rw, rec.tot.raid } }) do
            local wk, tot = e[2] or 0, e[3] or 0
            -- always shown (also at 0 / 0), so you can see the counting works
            out[#out + 1] = ("%s |cffffffff%d / %d|r"):format(e[1], wk, math.max(wk, tot))
        end
        l3 = table.concat(out, "   ")
    else
        l3 = FOREVER and parts({ { "dungeons", rec.dw }, { "raid bosses", rec.rw } }) or parts({ { "dungeons and keys", rec.dw }, { "raid bosses", rec.rw }, { "delves", rec.dl } })
    end
    if l1 ~= "" then tt:AddLine(l1, 0.8, 0.8, 0.8) end
    -- the collections each on their own line: "Mounts: 131", "Battle pets: 40", "Housing decor: 225"
    for _, e in ipairs({ { "Mounts", rec.mounts }, { "Battle pets", rec.pets }, { "Housing decor", rec.decor } }) do
        if (e[2] or 0) > 0 then tt:AddLine(("%s: |cffffffff%d|r"):format(e[1], e[2]), 0.8, 0.8, 0.8) end
    end
    if l3 ~= "" then tt:AddLine((rec.prog and "Done: " or rec.tot and "This week / in Midnight: " or "This week: ") .. l3, 0.8, 0.8, 0.8, true) end
    -- the faction of the account's characters is not a play style: its own line, the play styles (Casual, Hardcore, Collector, Gold farmer ...) below it
    local plays, sides = {}, {}
    for _, id in ipairs(rec.style) do
        if id == "alliance" or id == "horde" or id == "altaholic" then sides[#sides + 1] = id else plays[#plays + 1] = id end
    end
    if #sides > 0 then tt:AddLine(styleLabels(sides), 0.8, 0.8, 0.8) end
    if #plays > 0 then tt:AddLine("Play style: " .. styleLabels(plays), 1, 0.82, 0) end
    if (rec.role or 0) > 0 then
        tt:AddLine((rec.role == 2 and "Guild Master" or "Guild officer") .. ((rec.guild or "") ~= "" and (" of " .. rec.guild) or ""), 0.4, 1, 0.6)
    end
    local d = dislikeText(rec.dis, 3)
    if d then tt:AddLine("Dislikes in a group: " .. d, 1, 0.5, 0.5, true) end
end

-- what is worked out about your own character for the tooltip (gear check, talents) is kept for a few seconds: the game redraws the tooltip many times a
-- second while the mouse is on it, and doing the whole check each time made the lines come late
local selfKeep = {}
local function keepFor(key, seconds, fn)
    local k = selfKeep[key]
    local now = GetTime()
    if k and now - k.t < seconds then return k.v end
    local ok, v = pcall(fn)
    selfKeep[key] = { t = now, v = ok and v or nil }
    return ok and v or nil
end
S.ForgetSelfTooltip = function() wipe(selfKeep) end

local function playerTooltip(tt, unit)
    local c = S.Config()
    if not c.tip then return end
    -- the unit can be a "secret" value (the world cursor tooltip): every call is guarded, a secret answer ends the tooltip quietly
    if secret(unit) then return end
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if not okP or secret(isPlayer) or not isPlayer then return end
    local okS, isSelf = pcall(UnitIsUnit, unit, "player")
    if not okS or secret(isSelf) then return end
    local okG, guid = pcall(UnitGUID, unit)
    if not okG or type(guid) ~= "string" or secret(guid) then return end
    -- the ID of this player is saved with the name (found again by name or by ID)
    if not isSelf and SFP.db then
        local key = S.NormKey and S.NormKey(unit)
        if key then SFP.db.playerIDs = SFP.db.playerIDs or {}; SFP.db.playerIDs[guid] = key end
    end
    local rec = (not isSelf) and S.PeerOf(unit) or nil
    local insp = (not isSelf) and inspectFresh(guid) or nil
    -- what was read from this player earlier (kept in the addon's saved data)
    local saved = (not isSelf and S.NormKey and SFP.db and SFP.db.inspected) and SFP.db.inspected[S.NormKey(unit) or ""] or nil

    -- item level
    local ilvl
    if isSelf then
        local overall, equipped = GetAverageItemLevel()
        ilvl = math.floor(tonumber(equipped) or tonumber(overall) or 0)
    elseif insp and insp.ilvl then
        ilvl = insp.ilvl
    elseif rec and rec.ilvl and rec.ilvl > 0 then
        ilvl = rec.ilvl
    elseif saved and saved.ilvl then
        ilvl = saved.ilvl .. ""
    end
    if ilvl then
        tt:AddLine("Item level: |cffffffff" .. ilvl .. "|r", 1, 0.82, 0)
    elseif not isSelf then
        requestInspect(unit)
        tt:AddLine("Item level: |cff808080reading... (stay in range)|r", 0.6, 0.6, 0.6)
    end

    -- talents: the hero tree and the guide build closest to theirs
    local tal
    if isSelf then
        tal = keepFor("tal", 5, mySummary)
    elseif insp and insp.talent then
        tal = insp.talent
    elseif rec and rec.talent then
        tal = rec.talent   -- shared by their addon
    elseif saved and saved.tal then
        tal = saved.tal
    end
    if tal and (tal.hero or tal.matchName) then
        -- the talent choice in one short line: the build they have ("Voidweaver Delves"), or the hero tree when no build is close
        local text
        if tal.matchName and (tal.matchPct or 0) >= 0.4 then
            text = tal.matchName
        elseif tal.hero then
            text = tal.hero
        end
        if text then tt:AddLine("Talent choice: |cffffffff" .. text .. "|r", 1, 0.82, 0, true) end
    end
    if S.AddGuildNote then S.AddGuildNote(tt, S.NormKey and S.NormKey(unit) or nil, rec ~= nil) end

    -- sockets and enchants
    local gear
    if isSelf and SFP.GemHelper then gear = keepFor("gear", 5, function() return SFP.GemHelper.CheckUnit("player") end)
    elseif insp and insp.gear then gear = insp.gear
    elseif rec and rec.gear then gear = rec.gear end
    if gear and gear.any then
        S.AddGearLines(tt, S.GearDetail(gear))
        if gear.empty == 0 and #gear.missing == 0 then tt:AddLine("All sockets filled, all enchanted", 0.4, 1, 0.4) end
    elseif saved and saved.gear then
        S.AddGearLines(tt, saved.gear)   -- inspected before: the saved gear
    end

    -- Raider.IO (when installed) knows every player of either faction, from the data file it carries: the score comes from there
    -- first; the baked Blizzard armory below fills in only what Raider.IO does not have
    local rioHadScore = false
    if not (rec and (rec.mplus or 0) > 0 and not isSelf) then
        local RIO = _G.RaiderIO
        if RIO and RIO.GetProfile then
            local sc, raidText, prev = rioInfo(unit)
            rioHadScore = sc ~= nil
            if not tooltipHasRio(tt) then
                if sc then tt:AddLine(("Mythic+ score (Raider.IO): |cffffffff%d|r"):format(sc), 0.8, 0.8, 0.8)
                elseif prev then tt:AddLine(("Mythic+ score (Raider.IO): |cffffffff0|r  |cff808080previous season %d|r"):format(prev), 0.8, 0.8, 0.8) end
                if raidText then tt:AddLine(("Raid progress (Raider.IO): |cffffffff%s|r"):format(raidText), 0.8, 0.8, 0.8) end
            end
        end
    end

    -- baked public character data of a player you met before (tools/bake_players.py), when they share nothing themselves
    if not isSelf and not rec and S.NormKey and SFP.PlayerData then
        local d = SFP.PlayerData[S.NormKey(unit) or ""]
        if d then
            local out = {}
            -- row: { ilvl, achievement points, M+ rating, mounts, pets, date }
            if (d[1] or 0) > 0 then out[#out + 1] = "item level " .. d[1] end
            if (d[3] or 0) > 0 and not rioHadScore then out[#out + 1] = "M+ " .. d[3] end
            if (d[2] or 0) > 0 then out[#out + 1] = d[2] .. " achievement points" end
            if (d[4] or 0) > 0 then out[#out + 1] = d[4] .. " mounts" end
            if (d[5] or 0) > 0 then out[#out + 1] = d[5] .. " pets" end
            if #out > 0 then tt:AddLine(("Armory (%s): %s"):format(d[6] or "?", table.concat(out, ", ")), 0.8, 0.8, 0.8, true) end
        end
    end

    -- the shared profile (players with this addon)
    if isSelf then
        addProfileLines(tt, S.MyProfile())
    elseif rec then
        addProfileLines(tt, rec)
    elseif C_ChatInfo and c.share then
        -- ask them once in a while: if they have the addon they answer by themselves
        local key = unitKey(unit)
        if key and not queried[key] and GetTime() - lastQuery > 3 and UnitIsConnected(unit) and UnitIsFriend("player", unit) then
            queried[key] = GetTime()
            lastQuery = GetTime()
            send("Q", "WHISPER", key)
        end
    end
    tt:Show()
end

---------------------------------------------------------------------------
-- a player by name (the Premade Groups list, applicants): what is known without the player being a unit you can hover
---------------------------------------------------------------------------
local askedByName = {}
-- a player seen by name only (a listed group, an applicant): saved in the list the armory script reads (tools/bake_players.py)
function S.NoteSeenName(fullName)
    if type(fullName) ~= "string" or secret(fullName) or not SFP.db then return end
    local nm, realm = fullName:match("^([^-]+)-(.+)$")
    SFP.db.seenPlayers = SFP.db.seenPlayers or {}
    if not nm then
        -- no realm given by the game: kept as "Name-?" with the realms it can be on (yours and the connected ones); the armory
        -- script tries each of them
        local list = {}
        if GetNormalizedRealmName then list[#list + 1] = GetNormalizedRealmName() end
        if GetAutoCompleteRealms then
            local ok, l = pcall(GetAutoCompleteRealms)
            if ok and type(l) == "table" then for _, r in ipairs(l) do list[#list + 1] = (r:gsub("[%s'-]", "")) end end
        end
        SFP.db.homeRealms = list
        SFP.db.seenPlayers[fullName .. "-?"] = time()
        return
    end
    SFP.db.seenPlayers[nm .. "-" .. realm:gsub("[%s'-]", "")] = time()
end

-- a player ID (GUID, "Player-...") becomes "Name-Realm": players are found by name or by ID
function S.NameFromGUID(guid)
    if type(guid) ~= "string" or secret(guid) or not guid:find("^Player%-") then return nil end
    -- first the addon's own saved data (players met before), then the game
    local saved = SFP.db and SFP.db.playerIDs and SFP.db.playerIDs[guid]
    if saved then return saved end
    if not GetPlayerInfoByGUID then return nil end
    local ok, _, _, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
    if not ok or type(name) ~= "string" or name == "" or secret(name) then return nil end
    if type(realm) == "string" and realm ~= "" and not secret(realm) then return name .. "-" .. realm end
    return name
end

-- one of your own characters (the one you play, or one the addon noted when you played it)
function S.IsOwnCharacter(fullName)
    if type(fullName) ~= "string" then return false end
    local nm, realm = fullName:match("^([^-]+)-(.+)$")
    nm = nm or fullName
    if nm == UnitName("player") then
        local home = GetNormalizedRealmName and GetNormalizedRealmName()
        if not realm or (home and realm:gsub("[%s'-]", "") == home) then return true end
    end
    local chars = S.Config().chars
    if chars then
        local home = GetNormalizedRealmName and GetNormalizedRealmName()
        return chars[nm .. "-" .. ((realm and realm:gsub("[%s'-]", "")) or home or "")] ~= nil
    end
    return false
end

function S.AddByName(tt, fullName)
    local c = S.Config()
    if type(fullName) == "string" and fullName:find("^Player%-") then fullName = S.NameFromGUID(fullName) end
    if not c.tip or type(fullName) ~= "string" or secret(fullName) or fullName == "" then return end
    local nm, realm = fullName:match("^([^-]+)-(.+)$")
    nm = nm or fullName
    local rec = peers[fullName] or peers[nm]
    -- yourself: the character you play (found by name) has the whole profile of this addon, like on your own tooltip
    local isSelfName = false
    if nm == UnitName("player") then
        local home = GetNormalizedRealmName and GetNormalizedRealmName()
        isSelfName = (not realm) or (home ~= nil and realm:gsub("[%s'-]", "") == home)
    end
    -- not heard from yet: ask once (a player with the addon answers by itself; the answer is there on the next hover)
    if not rec and c.share and C_ChatInfo and not askedByName[fullName] and GetTime() - lastQuery > 1.5 then
        askedByName[fullName] = GetTime()
        lastQuery = GetTime()
        send("Q", "WHISPER", fullName)
    end
    local rioHad = false
    if S.AddGuildNote then S.AddGuildNote(tt, fullName, rec ~= nil) end
    -- the nameplate of this player as it was copied when he was seen: the game's own lines and Raider.IO's block, as written
    local copied = false
    if SFP.db and SFP.db.nameplateText then
        local ckeys = {}
        local function addCKey(r)
            if not r then return end
            ckeys[#ckeys + 1] = nm .. "-" .. r:gsub("[%s'-]", "")
            if r:find("[%s'-]") then ckeys[#ckeys + 1] = nm .. "-" .. r:gsub("%s", "") end   -- realms are also saved as the directory writes them (TheSha'tar)
        end
        if realm then addCKey(realm) else
            addCKey(SFP.db.nameRealms and SFP.db.nameRealms[nm])
            addCKey(SFP.db.nameRealm and SFP.db.nameRealm[nm] and SFP.db.nameRealm[nm].realm)
            addCKey(GetNormalizedRealmName and GetNormalizedRealmName())
        end
        for _, ck in ipairs(ckeys) do
            local cp = SFP.db.nameplateText[ck]
            if cp and addRioLines(tt, cp.lines) then copied = true; rioHad = true break end
        end
    end
    -- Raider.IO score, for anyone it knows (the addon's saved answer when Raider.IO is not loaded)
    if not copied and not (_G.RaiderIO and _G.RaiderIO.GetProfile) and SFP.db and SFP.db.rioCache then
        local home0 = GetNormalizedRealmName and GetNormalizedRealmName()
        local c0 = SFP.db.rioCache[nm .. "-" .. ((realm and realm:gsub("[%s'-]", "")) or home0 or "")]
        if c0 then
            if c0.score then tt:AddLine(("Mythic+ score (Raider.IO): |cffffffff%d|r"):format(c0.score), 0.8, 0.8, 0.8) end
            if c0.raid then tt:AddLine(("Raid progress (Raider.IO): |cffffffff%s|r"):format(c0.raid), 0.8, 0.8, 0.8) end
        end
    end
    local RIO = _G.RaiderIO
    if not copied and RIO and RIO.GetProfile and not (rec and (rec.mplus or 0) > 0) then
        local sc, raidText, foundRealm, prev = rioFind(nm, realm)
        rioHad = sc ~= nil
        local where = (not realm and foundRealm) and (", " .. foundRealm) or ""
        -- Raider.IO's own lines when it has the player (the same text as on its nameplate tooltip), else this addon's two lines
        local savedRio = SFP.db and SFP.db.rioLines and SFP.db.rioLines[nm .. "-" .. ((realm or foundRealm or (GetNormalizedRealmName and GetNormalizedRealmName()) or ""):gsub("[%s'-]", ""))]
        if savedRio and addRioLines(tt, savedRio.lines) then
            -- primary: the Raider.IO text copied when the player was seen (his nameplate), as Raider.IO wrote it
        elseif (sc or raidText or prev) and showRioBlock(tt, nm, realm or foundRealm) then
            -- else Raider.IO's own block, asked for now
        else
            if sc then tt:AddLine(("Mythic+ score (Raider.IO%s): |cffffffff%d|r"):format(where, sc), 0.8, 0.8, 0.8)
            elseif prev then tt:AddLine(("Mythic+ score (Raider.IO%s): |cffffffff0|r  |cff808080previous season %d|r"):format(where, prev), 0.8, 0.8, 0.8) end
            if raidText then tt:AddLine(("Raid progress (Raider.IO%s): |cffffffff%s|r"):format(where, raidText), 0.8, 0.8, 0.8) end
        end
    end
    -- everything the addon collected about this player before (nearby scan, inspect, Raider.IO cache), found by name and realm; a name
    -- without a realm is looked up on the realms it was seen on or found on
    if (not rec or isSelfName) and SFP.db then
        local keys = {}
        local function addKey(r)
            if not r then return end
            keys[#keys + 1] = nm .. "-" .. r:gsub("[%s'-]", "")
            if r:find("[%s'-]") then keys[#keys + 1] = nm .. "-" .. r:gsub("%s", "") end
        end
        if realm then addKey(realm) else
            addKey(SFP.db.nameRealms and SFP.db.nameRealms[nm])
            addKey(SFP.db.nameRealm and SFP.db.nameRealm[nm] and SFP.db.nameRealm[nm].realm)
            addKey(GetNormalizedRealmName and GetNormalizedRealmName())
        end
        local foundSaved = false
        for _, key in ipairs(keys) do
            local info = SFP.db.seenInfo and SFP.db.seenInfo[key]
            local sv = SFP.db.inspected and SFP.db.inspected[key]
            local rc = SFP.db.rioCache and SFP.db.rioCache[key]
            if info or sv or rc then
                foundSaved = true
                if info and not copied then
                    -- the nameplate as it was written when the player was seen (name and title)
                    if info.plate then tt:AddLine(info.plate, 1, 0.82, 0) end
                    local head = {}
                    if info.lvl then head[#head + 1] = "Level " .. info.lvl end
                    if info.race then head[#head + 1] = info.race end
                    if info.spec or info.class then head[#head + 1] = ((info.spec and (info.spec .. " ")) or "") .. (info.class or "") end
                    if #head > 0 then tt:AddLine(table.concat(head, " "), 1, 1, 1) end
                    if info.faction or info.guild then
                        tt:AddLine((info.faction or "") .. ((info.faction and info.guild) and "  " or "") .. (info.guild and ("<" .. info.guild .. ">") or "")
                            .. (info.rank and (" " .. info.rank) or ""), 0.8, 0.8, 0.8)
                    end
                    if info.pvp then tt:AddLine("PvP", 1, 0.3, 0.3) end
                end
                if sv and sv.ilvl then tt:AddLine("Item level: |cffffffff" .. sv.ilvl .. "|r", 1, 0.82, 0) end
                local tl = sv and sv.tal
                if tl and ((tl.matchName and (tl.matchPct or 0) >= 0.4) or tl.hero) then
                    tt:AddLine("Talent choice: |cffffffff" .. ((tl.matchName and (tl.matchPct or 0) >= 0.4) and tl.matchName or tl.hero) .. "|r", 1, 0.82, 0, true)
                end
                if sv and sv.gear then
                    S.AddGearLines(tt, sv.gear)
                elseif sv and ((sv.empty or 0) > 0 or (sv.missing or 0) > 0) then
                    tt:AddLine(("%d empty sockets, %d missing enchants"):format(sv.empty or 0, sv.missing or 0), 1, 0.4, 0.4)
                end
                -- the saved Raider.IO answer when the live one gave nothing
                if rc and not rioHad then
                    if rc.score then tt:AddLine(("Mythic+ score (Raider.IO): |cffffffff%d|r"):format(rc.score), 0.8, 0.8, 0.8)
                    elseif rc.prev then tt:AddLine(("Mythic+ score (Raider.IO): |cffffffff0|r  |cff808080previous season %d|r"):format(rc.prev), 0.8, 0.8, 0.8) end
                    if rc.raid then tt:AddLine(("Raid progress (Raider.IO): |cffffffff%s|r"):format(rc.raid), 0.8, 0.8, 0.8) end
                end
                break
            end
        end
        if not foundSaved and not copied and not isSelfName then
            tt:AddLine("Not seen nearby yet: no item level, gems or enchants saved", 0.6, 0.6, 0.6, true)
        end
    end
    -- your other characters (the ones you play but are not logged in on): what the addon noted when you played them (level, class,
    -- faction, item level, spec), also when no nameplate or inspect record of them exists
    if not isSelfName and SFP.db then
        local homeR = GetNormalizedRealmName and GetNormalizedRealmName()
        local key = nm .. "-" .. ((realm and realm:gsub("[%s'-]", "")) or homeR or "")
        local ch = S.Config().chars and S.Config().chars[key]
        local al = SFP.db.alts and SFP.db.alts[key]
        if (ch or al) and not (SFP.db.seenInfo and SFP.db.seenInfo[key]) then
            local head = {}
            local lvl = (al and al.level) or (ch and ch.level)
            if ch and ch.plate then tt:AddLine(ch.plate, 1, 0.82, 0) end
            if lvl then head[#head + 1] = "Level " .. lvl end
            if ch and ch.race then head[#head + 1] = ch.race end
            local spec = (al and al.spec) or (ch and ch.spec)
            if spec then head[#head + 1] = spec end
            local class = (al and al.class) or (ch and ch.class)
            if class then head[#head + 1] = class end
            tt:AddLine(table.concat(head, " "), 1, 1, 1)
            if ch and (ch.faction or ch.guild) then
                tt:AddLine((ch.faction or "") .. ((ch.faction and ch.guild) and "  " or "") .. (ch.guild and ("<" .. ch.guild .. ">") or ""), 0.8, 0.8, 0.8)
            end
            if al and (al.ilvl or 0) > 0 then tt:AddLine("Item level: |cffffffff" .. al.ilvl .. "|r", 1, 0.82, 0) end
            if al and al.profs and #al.profs > 0 then tt:AddLine("Professions: " .. table.concat(al.profs, ", "), 0.8, 0.8, 0.8, true) end
        end
        -- the addon's stats for this character: what is the same for all your characters (achievements, mounts, pets, housing decor,
        -- play style); what belongs to the character logged in now (Mythic+ score, this week, role in the guild) is left out
        if ch or al then
            local mine = S.MyProfile()
            mine.mplus, mine.dw, mine.rw, mine.dl, mine.prog, mine.tot, mine.role, mine.guild = 0, 0, 0, 0, nil, nil, 0, ""
            addProfileLines(tt, mine)
        end
    end
    if isSelfName then
        -- achievements, mounts, pets, decor, what was done, play style, guild role: your own profile
        addProfileLines(tt, S.MyProfile())
        return
    end
    if rec then
        if (rec.ilvl or 0) > 0 then tt:AddLine("Item level: |cffffffff" .. rec.ilvl .. "|r", 1, 0.82, 0) end
        local tal = rec.talent
        if tal and ((tal.matchName and (tal.matchPct or 0) >= 0.4) or tal.hero) then
            tt:AddLine("Talent choice: |cffffffff" .. ((tal.matchName and (tal.matchPct or 0) >= 0.4) and tal.matchName or tal.hero) .. "|r", 1, 0.82, 0, true)
        end
        if rec.gear and rec.gear.any and (rec.gear.empty > 0 or #rec.gear.missing > 0) then
            if rec.gear.empty > 0 then tt:AddLine("Empty sockets: " .. rec.gear.empty, 1, 0.4, 0.4) end
            if #rec.gear.missing > 0 then tt:AddLine("Missing enchants: " .. table.concat(rec.gear.missing, ", "), 1, 0.4, 0.4, true) end
        end
        addProfileLines(tt, rec)
        return
    end
    -- a player you met before: the baked public data
    local d
    if SFP.PlayerData then
        if realm then
            d = SFP.PlayerData[nm .. "-" .. realm:gsub("[%s'-]", "")]
        else
            for _, cand in ipairs(realmCandidates()) do
                d = SFP.PlayerData[nm .. "-" .. cand:gsub("[%s'-]", "")]
                if d then break end
            end
        end
    end
    if d then
        local out = {}
        if (d[1] or 0) > 0 then out[#out + 1] = "item level " .. d[1] end
        if (d[3] or 0) > 0 and not rioHad then out[#out + 1] = "M+ " .. d[3] end
        if (d[2] or 0) > 0 then out[#out + 1] = d[2] .. " achievement points" end
        if (d[4] or 0) > 0 then out[#out + 1] = d[4] .. " mounts" end
        if (d[5] or 0) > 0 then out[#out + 1] = d[5] .. " pets" end
        if #out > 0 then tt:AddLine(("Armory (%s): %s"):format(d[6] or "?", table.concat(out, ", ")), 0.8, 0.8, 0.8, true) end
    end
end

-- the same check as /sfp rio, as one short text: it runs by itself in the tabs for each player that shows no Raider.IO number
function S.RioDiagnose(fullName)
    local RIO = _G.RaiderIO
    if not (RIO and RIO.GetProfile) then return "Raider.IO: not loaded" end
    local nm, realm = tostring(fullName or ""):match("^([^-%s]+)-(.+)$")
    local tries
    if nm then
        local home = GetNormalizedRealmName and GetNormalizedRealmName()
        tries = { realm, (realm:gsub("(%l)(%u)", "%1 %2")), (home and realm == home and GetRealmName and GetRealmName()) or nil }
    else
        -- no realm given: every realm it can be on (yours and the connected ones)
        nm = tostring(fullName or ""):match("^[^-%s]+$")
        if not nm then return nil end
        tries = realmCandidates()
    end
    local out, seen = {}, {}
    for _, r in ipairs(tries) do
        if not seen[r] then
            seen[r] = true
            local ok, prof = pcall(RIO.GetProfile, nm, r)
            local what
            if not ok then what = "error"
            elseif type(prof) ~= "table" then what = "no profile"
            else
                local mk = prof.mythicKeystoneProfile
                local sc = type(mk) == "table" and (mk.currentScore or mk.mainCurrentScore)
                what = "profile" .. ((type(sc) == "number" and not secret(sc)) and (", score " .. math.floor(sc)) or ", no score")
            end
            out[#out + 1] = ('"%s": %s'):format(r, what)
        end
    end
    local extra = ""
    if not realm and SFP.db then
        local c = SFP.db.nameRealm and SFP.db.nameRealm[nm]
        if c and c.realm then extra = "; found on " .. c.realm
        elseif c and c.none then extra = "; searched all " .. #(SFP.Realms or {}) .. " realms: not found"
        else extra = "; searching all " .. #(SFP.Realms or {}) .. " realms ..." end
    end
    return "Raider.IO checked " .. table.concat(out, "; ") .. extra
end

-- /sfp rio Name-Realm: what Raider.IO answers for a player, spelling by spelling (to see why a number does not show)
function S.RioDebug(arg)
    local RIO = _G.RaiderIO
    if not (RIO and RIO.GetProfile) then SFP:Print("Raider.IO is not loaded") return end
    local nm, realm = tostring(arg or ""):match("^([^-%s]+)-(.+)$")
    if not nm then SFP:Print("use: /sfp rio Name-Realm") return end
    local home = GetNormalizedRealmName and GetNormalizedRealmName()
    local tries = { realm, (realm:gsub("(%l)(%u)", "%1 %2")), (home and realm == home and GetRealmName and GetRealmName()) or nil }
    for _, r in ipairs(tries) do
        local ok, prof = pcall(RIO.GetProfile, nm, r)
        local ok2, prof2 = pcall(RIO.GetProfile, nm .. "-" .. r:gsub("%s", ""))
        local function describe(o, p)
            if not o then return "error" end
            if type(p) ~= "table" then return tostring(p) end
            local mk = p.mythicKeystoneProfile
            return "profile, M+ score " .. tostring(type(mk) == "table" and (mk.currentScore or mk.mainCurrentScore) or "none")
                .. ", raid " .. tostring(type(p.raidProfile) == "table" and "yes" or "none")
        end
        SFP:Print(('GetProfile("%s", "%s"): %s;  GetProfile("%s-%s"): %s'):format(nm, r, describe(ok, prof), nm, r:gsub("%s", ""), describe(ok2, prof2)))
    end
end

-- Raider.IO's database: it gives a player only by name (there is no list of all its players to read), so the addon asks it, in the
-- background and a few at a time, for every player the addon has seen, and keeps the answer (db.rioCache[Name-Realm] = { score, raid, t }).
-- The numbers then stay available when Raider.IO is switched off or updated, and are refreshed once a day.
function S.UpdateRioCache()
    local RIO = _G.RaiderIO
    if not (RIO and RIO.GetProfile and SFP.db and SFP.db.seenPlayers) then return end
    SFP.db.rioCache = SFP.db.rioCache or {}
    local done, now = 0, time()
    for key in pairs(SFP.db.seenPlayers) do
        local c = SFP.db.rioCache[key]
        -- a name without a realm ("Name-?") is tried again every time until its realm is found (an old empty answer does not count)
        if not c or now - (c.t or 0) > 86400 or key:sub(-2) == "-?" then
            local nm, realm = key:match("^([^-]+)-(.+)$")
            if nm then
                if realm == "?" then
                    -- a name the game gave without a realm: the realm is searched (rioFind); the answer is saved under the real
                    -- Name-Realm, and nothing is saved while the search has not found it
                    local sc, raidText, foundRealm = rioFind(nm, nil)
                    if foundRealm then
                        SFP.db.rioCache[nm .. "-" .. foundRealm:gsub("[%s'-]", "")] = { score = sc, raid = raidText, t = now }
                        SFP.db.rioCache[key] = nil
                    end
                    SFP.db.seenPlayers[key] = SFP.db.seenPlayers[key]
                else
                    local sc, raidText = rioInfo(nm, realm)
                    SFP.db.rioCache[key] = { score = sc, raid = raidText, t = now }
                end
                done = done + 1
                if done >= 20 then break end   -- a few at a time: no stutter
            end
        end
    end
end

-- one short line about a player by name, for the members of a listed group: "item level 159 - Voidweaver Delves - M+ 2400"
function S.OneLine(fullName)
    if type(fullName) == "string" and fullName:find("^Player%-") then fullName = S.NameFromGUID(fullName) end
    if type(fullName) ~= "string" or secret(fullName) then return nil end
    local nm, realm = fullName:match("^([^-]+)-(.+)$")
    nm = nm or fullName
    local rec = peers[fullName] or peers[nm]
    local out = {}
    if rec then
        if (rec.ilvl or 0) > 0 then out[#out + 1] = "item level " .. rec.ilvl end
        local tal = rec.talent
        if tal and tal.matchName and (tal.matchPct or 0) >= 0.4 then out[#out + 1] = tal.matchName elseif tal and tal.hero then out[#out + 1] = tal.hero end
        if (rec.mplus or 0) > 0 then out[#out + 1] = "M+ " .. rec.mplus end
        -- done this week
        local wk = {}
        if (rec.dl or 0) > 0 then wk[#wk + 1] = rec.dl .. " delves" end
        if (rec.dw or 0) > 0 then wk[#wk + 1] = rec.dw .. " dungeons" end
        if (rec.rw or 0) > 0 then wk[#wk + 1] = rec.rw .. " raid bosses" end
        if #wk > 0 then out[#out + 1] = "week: " .. table.concat(wk, ", ") end
    end
    local RIO = _G.RaiderIO
    if RIO and RIO.GetProfile and not (rec and (rec.mplus or 0) > 0) then
        local sc, raidText = rioFind(nm, realm)
        if sc then out[#out + 1] = "M+ " .. math.floor(sc) end
        if raidText then out[#out + 1] = "raid " .. raidText end
    end
    if #out == 0 then return nil end
    return nm .. ": " .. table.concat(out, " - ")
end

---------------------------------------------------------------------------
-- group window and the one line when a group forms
---------------------------------------------------------------------------
local function groupUnits()
    local out = { "player" }
    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do out[#out + 1] = "raid" .. i end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do if UnitExists("party" .. i) then out[#out + 1] = "party" .. i end end
    end
    return out
end

-- counts of dislikes in the group, most common first
function S.GroupSummary()
    local n, sharing, sumIlvl, cntIlvl = 0, 0, 0, 0
    local dis = {}
    for _, u in ipairs(groupUnits()) do
        if UnitExists(u) then
            n = n + 1
            local rec = UnitIsUnit(u, "player") and S.MyProfile() or S.PeerOf(u)
            if rec then
                sharing = sharing + 1
                for _, id in ipairs(rec.dis or {}) do dis[id] = (dis[id] or 0) + 1 end
            end
            local g = UnitGUID(u)
            local insp = (type(g) == "string" and not secret(g)) and inspectFresh(g) or nil
            local il = (rec and rec.ilvl and rec.ilvl > 0 and rec.ilvl) or (insp and insp.ilvl)
            if il then sumIlvl, cntIlvl = sumIlvl + il, cntIlvl + 1 end
        end
    end
    local list = {}
    for id, c in pairs(dis) do list[#list + 1] = { id = id, c = c } end
    table.sort(list, function(a, b) if a.c ~= b.c then return a.c > b.c end return a.id < b.id end)
    return { members = n, sharing = sharing, avgIlvl = cntIlvl > 0 and math.floor(sumIlvl / cntIlvl) or nil, dislikes = list }
end

local function printGroupLine()
    if not S.Config().groupLine then return end
    local g = S.GroupSummary()
    if g.members < 2 or g.sharing < 2 then return end
    local parts = { ("Group of %d: %d share a profile"):format(g.members, g.sharing) }
    if g.avgIlvl then parts[#parts + 1] = "average item level " .. g.avgIlvl end
    local top = {}
    for i = 1, math.min(3, #g.dislikes) do
        local d = g.dislikes[i]
        top[#top + 1] = ("%s (%d)"):format(DISLIKE_TEXT[d.id] or ("#" .. d.id), d.c)
    end
    if #top > 0 then parts[#parts + 1] = "dislikes: " .. table.concat(top, ", ") end
    SFP:Print(table.concat(parts, "; ") .. ".")
end

-- every member of the group with the whole player tooltip (item level, talent choice, sockets, enchants, achievements, collectables,
-- done counts, play style), as text for a page: the tooltip builder is run on a collector instead of the game tooltip
function S.GroupMembersText()
    local out = {}
    for _, u in ipairs(groupUnits()) do
        if UnitExists(u) then
            local name = UnitName(u) or "?"
            local _, class = UnitClass(u)
            local col = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            local hex = col and col.colorStr and ("|c" .. col.colorStr) or "|cffffffff"
            local lvl = UnitLevel(u)
            local lines = { hex .. name .. "|r" }
            -- the lines the game's own tooltip starts with: guild, level race, faction
            local okGl, guildName = pcall(GetGuildInfo, u)
            if okGl and type(guildName) == "string" and not secret(guildName) and guildName ~= "" then lines[#lines + 1] = "  " .. guildName end
            local okR, race = pcall(UnitRace, u)
            local className = UnitClassBase and select(1, UnitClass(u))
            if type(lvl) == "number" and not secret(lvl) and lvl > 0 then
                lines[#lines + 1] = ("  Level %d %s %s"):format(lvl, (okR and type(race) == "string" and not secret(race)) and race or "", className or "")
            end
            local okF, faction = pcall(UnitFactionGroup, u)
            if okF and type(faction) == "string" and not secret(faction) then lines[#lines + 1] = "  " .. faction end
            local collector = {
                AddLine = function(_, text, r, g, b)
                    if type(text) ~= "string" or text == " " then return end
                    if r then text = ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), text) end
                    lines[#lines + 1] = "  " .. text
                end,
                Show = function() end,
            }
            local ok = pcall(playerTooltip, collector, u)
            if not ok or #lines == 1 then lines[#lines + 1] = "  |cff808080nothing known yet|r" end
            out[#out + 1] = table.concat(lines, "\n")
        end
    end
    if #out == 0 then return "|cff808080Not in a group.|r" end
    return table.concat(out, "\n\n")
end

local groupWin, groupList

local function groupRows()
    local items = {}
    for _, u in ipairs(groupUnits()) do
        if UnitExists(u) then
            local isSelf = UnitIsUnit(u, "player")
            local rec = isSelf and S.MyProfile() or S.PeerOf(u)
            local g = UnitGUID(u)
            local insp = (type(g) == "string" and not secret(g)) and inspectFresh(g) or nil
            local name = UnitName(u) or "?"
            local _, class = UnitClass(u)
            local col = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            local hex = col and col.colorStr and ("|c" .. col.colorStr) or "|cffffffff"
            local il = (rec and rec.ilvl and rec.ilvl > 0 and rec.ilvl) or (insp and insp.ilvl)
            local text = ("%s%s|r  ilvl %s"):format(hex, name, il and ("|cffffffff" .. il .. "|r") or "|cff808080?|r")
            if rec and (rec.role or 0) > 0 then text = text .. (rec.role == 2 and "  |cff66ff99[Guild Master]|r" or "  |cff66ff99[Officer]|r") end
            if rec then
                -- only what the player has: zeros are left out
                if rec.mplus > 0 then text = text .. ("  M+ %d"):format(rec.mplus) end
                local wk = {}
                if rec.dw > 0 then wk[#wk + 1] = rec.dw .. " dungeons" end
                if rec.rw > 0 then wk[#wk + 1] = rec.rw .. " raid bosses" end
                if (rec.dl or 0) > 0 then wk[#wk + 1] = rec.dl .. " delves" end
                if #wk > 0 then text = text .. "  wk " .. table.concat(wk, ", ") end
                if #rec.style > 0 then text = text .. "  " .. styleLabels(rec.style) end
                if #rec.dis > 0 then text = text .. ("  |cffff8080dislikes %d|r"):format(#rec.dis) end
            else
                text = text .. "  |cff808080no addon|r"
            end
            -- Raider.IO of the player (a unit in the group): the score and the raid progress on the row too
            if _G.RaiderIO and _G.RaiderIO.GetProfile then
                local okR, sc, raidText, prev = pcall(rioInfo, u)
                if okR then
                    if sc and not (rec and (rec.mplus or 0) > 0) then text = text .. ("  |cffffd100M+ %d|r"):format(sc)
                    elseif prev and not sc and not (rec and (rec.mplus or 0) > 0) then text = text .. ("  |cff808080M+ prev %d|r"):format(prev) end
                    if raidText then text = text .. ("  |cffb0b0b0raid %s|r"):format(raidText) end
                end
            end
            if insp and insp.gear and insp.gear.any then
                if insp.gear.empty > 0 then text = text .. ("  |cffff6060%d empty sockets|r"):format(insp.gear.empty) end
                if #insp.gear.missing > 0 then text = text .. ("  |cffff6060%d unenchanted|r"):format(#insp.gear.missing) end
            end
            -- the talent choice of the player, when known
            local tal = rec and rec.talent
            if not isSelf and insp and insp.talent then tal = insp.talent end
            if isSelf then tal = mySummary() end
            if tal and ((tal.matchName and (tal.matchPct or 0) >= 0.4) or tal.hero) then
                text = text .. "  |cffffd100" .. ((tal.matchName and (tal.matchPct or 0) >= 0.4) and tal.matchName or tal.hero) .. "|r"
            end
            -- hovering the row shows the player's whole tooltip (item level, talents, sockets, enchants, collectables ...)
            items[#items + 1] = { text = text, buttons = {}, unit = u }
        end
    end
    return items
end

-- shrunk: only the title bar and the - / + button stay; the size is saved
local function fitGroup()
    if not groupWin then return end
    local shrunk = S.Config().groupShrunk
    groupWin.info:SetShown(not shrunk)
    groupList.scroll:SetShown(not shrunk)
    groupWin:SetHeight(shrunk and 34 or 330)
    if groupWin.shrinkBtn then groupWin.shrinkBtn:SetText(shrunk and "+" or "-") end
end

S.GroupRows = groupRows   -- the rows of the group, each with its unit (hover = the player tooltip)

function S.RefreshGroupWindow()
    if not (groupWin and groupWin:IsShown()) then return end
    fitGroup()
    local g = S.GroupSummary()
    local lines = { ("%d in the group, %d share a profile%s."):format(g.members, g.sharing, g.avgIlvl and (", average item level " .. g.avgIlvl) or "") }
    if #g.dislikes > 0 then
        local top = {}
        for i = 1, math.min(5, #g.dislikes) do
            top[#top + 1] = ("%s (%d)"):format(DISLIKE_TEXT[g.dislikes[i].id] or ("#" .. g.dislikes[i].id), g.dislikes[i].c)
        end
        lines[#lines + 1] = "|cffff8080Dislikes in this group:|r " .. table.concat(top, ", ")
    end
    groupWin.info:SetText(table.concat(lines, "\n"))
    groupList:Set(groupRows())
end

function S.ShowGroup(auto)
    local cfg = S.Config()
    -- opened by itself: not when you closed it with the X (it stays closed until you open it yourself)
    if auto and cfg.groupClosed then return end
    if not auto then cfg.groupClosed = false end
    if not groupWin then
        groupWin = SFP.MakeToolWindow("SeviathsUsefulToolsGroup", "Your group", 620, 330)
        groupWin.scroll:Hide()
        groupWin.info = groupWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        groupWin.info:SetPoint("TOPLEFT", 14, -32)
        groupWin.info:SetWidth(590)
        groupWin.info:SetJustifyH("LEFT")
        groupList = SFP.MakeRowList(groupWin, 10, -84, 600, 236, 20)
        groupWin:SetScript("OnShow", function() S.RefreshGroupWindow() end)
        -- - / + shrinks and grows it (saved); the X closes it fully (saved too), its place is saved by the window itself
        local sb = CreateFrame("Button", nil, groupWin, "UIPanelButtonTemplate")
        sb:SetSize(22, 20)
        sb:SetPoint("TOPRIGHT", -30, -6)
        sb:SetText("-")
        sb:SetScript("OnClick", function()
            local c2 = S.Config()
            c2.groupShrunk = not c2.groupShrunk
            fitGroup()
        end)
        groupWin.shrinkBtn = sb
        if groupWin.closeBtn then groupWin.closeBtn:HookScript("OnClick", function() S.Config().groupClosed = true end) end
    end
    groupWin:Show()
    for _, u in ipairs(groupUnits()) do
        if not UnitIsUnit(u, "player") then S.PeerOf(u) end
    end
    broadcastGroup(true)
    S.RefreshGroupWindow()
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "INSPECT_READY", "PLAYER_MONEY",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "LOOT_OPENED", "LOOT_CLOSED", "QUEST_TURNED_IN",
    "BOSS_KILL", "CHALLENGE_MODE_COMPLETED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED",
    "TRANSMOG_COLLECTION_SOURCE_ADDED", "ACHIEVEMENT_EARNED", "PVP_MATCH_COMPLETE", "PET_BATTLE_CLOSE", "LFG_COMPLETION_REWARD", "SCENARIO_COMPLETED", "QUEST_ACCEPTED" }) do
    pcall(ev.RegisterEvent, ev, e)
end

-- where the player's gold comes from: every gain of money is filed under what the player was doing at that moment
local ctx = { merchant = false, mail = false, loot = false, lootT = 0, questT = -10, questDaily = false }
local lastMoney

local function noteMoney()
    if not GetMoney then return end
    local now = GetMoney()
    if type(now) ~= "number" or secret(now) then return end
    local delta = lastMoney and (now - lastMoney) or 0
    lastMoney = now
    if delta <= 0 then return end
    local cat
    local t = GetTime()
    if ctx.merchant then cat = "vendor"
    elseif ctx.mail then cat = "mail"
    elseif t - ctx.questT < 3 then cat = ctx.questDaily and "daily" or "quest"
    elseif ctx.loot or t - ctx.lootT < 3 then cat = "loot"
    else cat = "other" end
    local key = (cat == "mail") and "g_trade" or (cat == "vendor" and "g_other") or ("g_" .. cat)   -- only monster drops and the auction house (it pays by mail) make a gold farmer
    S.Act(key, delta)
    if key == "g_loot" or key == "g_trade" then S.WeekGoldAdd(delta) end
end

local function questTurnedIn(questID)
    S.Act("quest")   -- any quest handed in counts as playing (the casual tag)
    ctx.questT = GetTime()
    ctx.questDaily = false
    if questID and C_QuestLog then
        if C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID) then ctx.questDaily = true
        elseif C_QuestLog.IsRepeatableQuest and C_QuestLog.IsRepeatableQuest(questID) then ctx.questDaily = true end
        if QuestIsDaily and QuestIsDaily() then ctx.questDaily = true end
    end
    if ctx.questDaily then S.Act("daily") end
end

local rosterPending, summaryPending = false, false
local groupAutoShown = false   -- the group window was opened for the group you are in now

ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
    if event == "CHAT_MSG_ADDON" then
        if a1 ~= PREFIX or type(a2) ~= "string" then return end
        local sender = a4
        if type(sender) ~= "string" then return end
        local name = Ambiguate and Ambiguate(sender, "none") or sender
        if name == UnitName("player") then return end
        local kind = a2:sub(1, 1)
        if kind == "Q" then
            replyTo(sender, 0)
        elseif kind == "R" then
            replyTo(sender, math.random(1, 8))
        elseif kind == "T" then
            -- the sender's talent build: the talent advisor learns it as an example
            local TA = SFP.TalentAdvisor
            if TA and TA.SaveSeen then TA.SaveSeen(a2:sub(3), shortName(name)) end
        elseif kind == "V" then
            local f = split(a2, ";")
            local rec = peers[name] or peers[shortName(name)]
            if rec then
                rec.prog = { delve = { tonumber(f[2]) or 0, tonumber(f[3]) or 0 }, key = { tonumber(f[4]) or 0, tonumber(f[5]) or 0 },
                    raid = { tonumber(f[6]) or 0, tonumber(f[7]) or 0 }, dun = { tonumber(f[8]) or 0, tonumber(f[9]) or 0 } }
            end
        elseif kind == "W" then
            local f = split(a2, ";")
            local rec = peers[name] or peers[shortName(name)]
            if rec then
                rec.dw, rec.rw, rec.dl = tonumber(f[2]) or 0, tonumber(f[4]) or 0, tonumber(f[6]) or 0
                rec.tot = { dungeon = tonumber(f[3]) or 0, raid = tonumber(f[5]) or 0, delve = tonumber(f[7]) or 0 }
            end
        elseif kind == "S" then
            -- the sender's talents in short: hero tree, the guide build they are closest to, and how close
            local f = split(a2, ";")
            local rec = peers[name] or peers[shortName(name)]
            if rec then
                rec.talent = { hero = (f[2] ~= "" and f[2]) or nil, matchName = (f[3] ~= "" and f[3]) or nil, matchPct = (tonumber(f[4]) or 0) / 100, per = {} }
                for i, k in ipairs({ "raid", "mythic", "delves" }) do
                    local nm, pc = f[3 + i * 2], tonumber(f[4 + i * 2]) or 0
                    if nm and nm ~= "" then rec.talent.per[k] = { name = nm, pct = pc / 100 } end
                end
            end
        elseif kind == "G" then
            -- the sender's gear check: empty sockets and missing enchants
            local f = split(a2, ";")
            local rec = peers[name] or peers[shortName(name)]
            if rec then
                local where, miss = {}, {}
                for s in (f[3] or ""):gmatch("[^,]+") do where[#where + 1] = s end
                for s in (f[4] or ""):gmatch("[^,]+") do miss[#miss + 1] = s end
                rec.gear = { any = true, empty = tonumber(f[2]) or 0, emptyWhere = where, missing = miss }
            end
        elseif kind == "P" then
            local rec = decode(a2)
            if rec then
                -- the guild and the role (2 = Guild Master, 1 = officer) the other player's addon says: into the guild directory
                if rec.guild and rec.guild ~= "" and (rec.role or 0) > 0 then
                    local pn, pr = tostring(sender):match("^([^-]+)-(.+)$")
                    local realmOf = (pr and pr:gsub("[%s'-]", "")) or (GetNormalizedRealmName and GetNormalizedRealmName())
                    if realmOf then
                        S.GuildNote(realmOf, rec.guild, nil, pn or name, rec.role == 2 and "Guild Master" or "Officer", rec.role == 2 and 0 or 1)
                    end
                end
                peers[name] = rec
                peers[shortName(name)] = peers[shortName(name)] or rec
                if groupWin and groupWin:IsShown() then S.RefreshGroupWindow() end
            end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if not rosterPending then
            rosterPending = true
            C_Timer.After(math.random(2, 6), function()
                rosterPending = false
                SFP:Safe("share profile", broadcastGroup, false)
            end)
        end
        if not summaryPending then
            summaryPending = true
            C_Timer.After(12, function()
                summaryPending = false
                SFP:Safe("group line", printGroupLine)
                -- a group of 2 or more (questing, delves, dungeons, raids, PvP, custom): the group window opens once per group
                SFP:Safe("open group window", function()
                    if not (IsInGroup and IsInGroup()) then groupAutoShown = false return end
                    if groupAutoShown or S.Config().groupAuto ~= true then return end   -- the group window opens by itself only when it was switched on
                    if (GetNumGroupMembers and GetNumGroupMembers() or 0) < 2 then return end
                    groupAutoShown = true
                    S.ShowGroup(true)
                end)
            end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(3, function() SFP:Safe("note instance", S.NoteInstance) end)
        -- in a dungeon, a raid, a delve, a battleground or an arena with other players: the group window opens by itself,
        -- each player in it shows the whole tooltip when hovered (also in custom and PvP groups)
        C_Timer.After(6, function()
            SFP:Safe("open group window", function()
                local c = S.Config()
                if c.groupAuto ~= true then return end
                local okI, inInst, itype = pcall(IsInInstance)
                if not (okI and inInst) then return end
                if itype ~= "party" and itype ~= "raid" and itype ~= "scenario" and itype ~= "pvp" and itype ~= "arena" then return end
                if not (IsInGroup and IsInGroup()) then return end
                S.ShowGroup(true)
            end)
        end)
        -- entering a scenario instance is a delve (the only scenario content in Midnight)
        do
            local okI, inInst, itype = pcall(IsInInstance)
            if okI and inInst and itype == "scenario" then S.Act("delve") end
        end
        if a1 or a2 then   -- log in or reload
            C_Timer.After(10, function() SFP:Safe("note character", S.RecordChar) end)
            C_Timer.After(30, function() SFP:Safe("delve statistic", S.ReadDelveStat) end)
            C_Timer.After(20, function()
                SFP:Safe("counts", refreshCounts)
                if S.Config().share and IsInGuild and IsInGuild() then send("R", "GUILD") end
            end)
            C_Timer.After(40, function()
                if S.Config().share and IsInGuild and IsInGuild() then sendProfile("GUILD") end
            end)
        end
    elseif event == "INSPECT_READY" then
        SFP:Safe("inspect", inspectReady, a1)
    elseif event == "PLAYER_MONEY" then
        SFP:Safe("gold source", noteMoney)
    elseif event == "MERCHANT_SHOW" then ctx.merchant = true
    elseif event == "MERCHANT_CLOSED" then ctx.merchant = false
    elseif event == "MAIL_SHOW" then ctx.mail = true
    elseif event == "MAIL_CLOSED" then ctx.mail = false
    elseif event == "LOOT_OPENED" then ctx.loot, ctx.lootT = true, GetTime(); S.Act("loot")
    elseif event == "BOSS_KILL" then
        SFP:Safe("note boss", S.NoteBoss, a1, a2)
        local _, itype = IsInInstance()
        if itype == "raid" then
            -- heroic and mythic raids are hardcore, normal and raid finder are easy content
            local okD, _, _, diff = pcall(GetInstanceInfo)
            if okD and (diff == 15 or diff == 16) then S.Act("hardcore") else S.Act("easy") end
            S.UniqueAdd("raid", type(a2) == "string" and a2 or nil)   -- the boss: each boss once
            S.Act("raid"); S.WeekAdd("raid"); C_Timer.After(5, function() SFP:Safe("statistics", S.ReadStats); SFP:Safe("share profile", broadcastGroup, true) end)
        elseif itype == "party" then S.Act("dungeon") end
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        S.Act("mythic"); S.WeekAdd("dungeon")
        do local okI, iname = pcall(GetInstanceInfo); if okI then S.UniqueAdd("dungeon", iname) end end
        -- keys from +5 up are hardcore, +0 to +4 are easy content
        local okK, _, keyLevel = pcall(C_ChallengeMode.GetCompletionInfo)
        if okK and type(keyLevel) == "number" and not secret(keyLevel) and keyLevel >= 5 then S.Act("hardcore") else S.Act("easy") end
        C_Timer.After(5, function() SFP:Safe("statistics", S.ReadStats); SFP:Safe("share profile", broadcastGroup, true) end)
    elseif event == "LFG_COMPLETION_REWARD" then
        S.Act("dungeon"); S.WeekAdd("dungeon"); S.Act("easy")
        do local okI, iname = pcall(GetInstanceInfo); if okI then S.UniqueAdd("dungeon", iname) end end
        C_Timer.After(5, function() SFP:Safe("statistics", S.ReadStats); SFP:Safe("share profile", broadcastGroup, true) end)
    elseif event == "SCENARIO_COMPLETED" then
        -- a delve is a scenario: finishing it counts as a delve done this week
        local okI, inInst, itype = pcall(IsInInstance)
        if okI and inInst and itype == "scenario" then
            S.WeekAdd("delve")
            do local okI, iname = pcall(GetInstanceInfo); if okI then S.UniqueAdd("delve", iname) end end
            S.Act("easy")   -- delves count as easy content
            S.MarkDelveDone()
            C_Timer.After(8, function() SFP:Safe("delve statistic", S.ReadDelveStat) end)
            C_Timer.After(5, function() SFP:Safe("statistics", S.ReadStats); SFP:Safe("share profile", broadcastGroup, true) end)
        end
    elseif event == "NEW_MOUNT_ADDED" then S.Act("c_mount")       -- the collector's sections: not transmog (everyone gets that from Timewalking)
    elseif event == "NEW_PET_ADDED" then S.Act("c_pet")
    elseif event == "NEW_TOY_ADDED" then S.Act("c_toy")
    elseif event == "ACHIEVEMENT_EARNED" then S.Act("achv")
    elseif event == "PVP_MATCH_COMPLETE" then S.Act("pvp")
    elseif event == "PET_BATTLE_CLOSE" then S.Act("c_battle")   -- battle pets: wild pet battles, the way to new pets
    elseif event == "LOOT_CLOSED" then ctx.loot, ctx.lootT = false, GetTime()
    elseif event == "QUEST_ACCEPTED" then SFP:Safe("quest place", S.NoteQuestPlace, a1, false)
    elseif event == "QUEST_TURNED_IN" then
        SFP:Safe("quest place", S.NoteQuestPlace, a1, true)
        SFP:Safe("quest turned in", questTurnedIn, a1)
    end
end)

-- Players around you: ask each one once, without any hover. If they have this addon they answer with their profile
-- (item level included), which does not need the inspect range, and it is added at once.
local nearFrame = CreateFrame("Frame")
nearFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
-- "Name-Realm" (the realm always written out) of a player unit, for the list of players seen and the baked data
local function normKey(unit)
    local ok, n, r = pcall(UnitName, unit)
    if not ok or type(n) ~= "string" or secret(n) then return nil end
    if type(r) ~= "string" or r == "" or secret(r) then r = GetNormalizedRealmName and GetNormalizedRealmName() or nil end
    return r and (n .. "-" .. r) or nil
end
S.NormKey = normKey

-- every player that comes near you (either faction) is noted: tools/bake_players.py reads this list and bakes their public
-- character data (Data/PlayerData.lua) so the tooltip can show it next time, without asking anyone
-- at most 3000 NEW players are added to the saved list per session (a session = from login or /reload to the next); the ones already
-- saved are always updated, and nothing saved is ever deleted
local SESSION_NEW_MAX = 3000
local sessionNew = 0
local function canAddSeen(key)
    if SFP.db and SFP.db.seenPlayers and SFP.db.seenPlayers[key] then return true end
    if sessionNew >= SESSION_NEW_MAX then return false end
    sessionNew = sessionNew + 1
    return true
end
S.CanAddSeen = canAddSeen

-- The guild directory: every guild seen on a player (nearby scan, your own guild's roster) is kept by realm, with the players seen in it
-- and their ranks: db.guildDir[realm][guild] = { faction, t, members = { [Name] = { rank, ri (rank index, 0 = Guild Master), t } } }.
-- The Guild Master is rank index 0. Officers are the players of rank index 1 (the usual Officer rank) or with a rank name like
-- officer / lieutenant / co-leader; the rank name is always shown as the game gives it.
function S.GuildNote(realm, guild, faction, name, rankName, rankIndex, memberRealm)
    if not (SFP.db and type(realm) == "string" and type(guild) == "string" and guild ~= "" and type(name) == "string") then return end
    SFP.db.guildDir = SFP.db.guildDir or {}
    local byRealm = SFP.db.guildDir[realm] or {}
    SFP.db.guildDir[realm] = byRealm
    -- meeting the player again rewrites his entry: if he is in another guild now, he is taken out of the old one
    for otherName, other in pairs(byRealm) do
        if otherName ~= guild and other.members and other.members[name] then
            other.members[name] = nil
            if next(other.members) == nil then byRealm[otherName] = nil end
        end
    end
    -- every new guild and new player gets the next number (o): the lists show them in the order they were first saved, newest last
    local function nextOrder()
        SFP.db.order = (SFP.db.order or 0) + 1
        return SFP.db.order
    end
    local g = byRealm[guild] or { members = {}, t = time(), o = nextOrder() }
    byRealm[guild] = g
    g.o = g.o or nextOrder()
    -- the faction of a guild: given, or the one saved for this player (a guild belongs to one faction)
    if not faction and SFP.db.seenInfo then
        local si = SFP.db.seenInfo[name .. "-" .. realm]
        faction = si and si.faction or nil
    end
    g.faction = faction or g.faction
    g.t = time()
    local m = g.members[name] or { o = nextOrder() }
    m.o = m.o or nextOrder()
    m.rank = (type(rankName) == "string" and rankName ~= "") and rankName or m.rank
    if type(rankIndex) == "number" then m.ri = rankIndex end
    -- a guild has one Guild Master: when this player is seen as the Guild Master now, the one saved before is no longer marked
    if m.ri == 0 and rankIndex == 0 then
        for otherName, other in pairs(g.members) do
            if otherName ~= name and other.ri == 0 then
                other.ri = nil
                if other.rank == "Guild Master" then other.rank = nil end
            end
        end
    end
    -- a player seen on a nameplate without a rank the game would give (or a /who answer, which has none): when the guild data of other
    -- sources (Raider.IO's guild data shipped with this addon) says he is the Guild Master or an officer, he is marked as such
    if m.ri == nil then
        local known = SFP.GuildLeaders and SFP.GuildLeaders[realm] and SFP.GuildLeaders[realm][guild]
        if known then
            if known.gm == name then m.ri = 0; m.rank = m.rank or "Guild Master"
            else
                for _, o in ipairs(known.officers or {}) do
                    if o == name then m.ri = 1; m.rank = m.rank or "Officer" break end
                end
            end
        end
    end
    m.t = time()
    if memberRealm then m.realm = memberRealm end
    g.members[name] = m
end

-- who leads a guild: { master = "Name", officers = { "Name", ... } } from the ranks seen
-- players saved with a guild before the directory existed (or when it was not written): their guild is entered in the directory too,
-- so the directory and the nameplate data say the same
function S.BackfillGuilds()
    if not (SFP.db and SFP.db.seenInfo) then return end
    local dir = SFP.db.guildDir or {}
    -- entries saved before the numbering existed get their numbers now, oldest first (by the time they were last updated)
    do
        local old = {}
        for _, guilds in pairs(dir) do
            for gname, g in pairs(guilds) do
                if not g.o then old[#old + 1] = { g, g.t or 0, gname } end
                for mname, m in pairs(g.members or {}) do
                    if not m.o then old[#old + 1] = { m, m.t or 0, mname } end
                end
            end
        end
        table.sort(old, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[3] < b[3] end)
        for _, e in ipairs(old) do
            SFP.db.order = (SFP.db.order or 0) + 1
            e[1].o = SFP.db.order
        end
    end
    if SeviathsLoadAll then SeviathsLoadAll(SFP.db.seenInfo) end
    for key, rec in pairs(SFP.db.seenInfo) do
        local nm, realm = key:match("^([^-]+)-(.+)$")
        if nm and realm and type(rec.guild) == "string" and rec.guild ~= "" then
            local g = dir[realm] and dir[realm][rec.guild]
            if not (g and g.members and g.members[nm]) then
                S.GuildNote(realm, rec.guild, rec.faction, nm, rec.rank, nil)
            end
        end
    end
end

function S.GuildLeaders(g)
    local master, officers = nil, {}
    for name, m in pairs(g.members or {}) do
        if m.ri == 0 then master = name
        else
            local rn = (m.rank or ""):lower()
            if m.ri == 1 or rn:find("officer", 1, true) or rn:find("lieutenant", 1, true) or rn:find("co%-?lead") or rn:find("deputy", 1, true) then
                officers[#officers + 1] = name
            end
        end
    end
    table.sort(officers, function(a, b)
        local oa, ob = g.members[a].o or 0, g.members[b].o or 0
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return master, officers
end

-- counters for /sfp near: why a nearby player was or was not noted
local nearStats = { events = 0, notPlayer = 0, secretPlayer = 0, self = 0, noKey = 0, noted = 0, last = nil }
S.nearStats = nearStats

local function notePlayer(unit)
    nearStats.events = nearStats.events + 1
    if not SFP.db then return end
    -- a "secret" answer (the game hides it from addons) cannot be tested: it is counted and skipped
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if not okP or secret(isPlayer) then nearStats.secretPlayer = nearStats.secretPlayer + 1 return end
    if not isPlayer then nearStats.notPlayer = nearStats.notPlayer + 1 return end
    local okS, isSelf = pcall(UnitIsUnit, unit, "player")
    if okS and not secret(isSelf) and isSelf then nearStats.self = nearStats.self + 1 return end
    local key = normKey(unit)
    if not key then nearStats.noKey = nearStats.noKey + 1 return end
    if not canAddSeen(key) then return end
    nearStats.noted = nearStats.noted + 1
    nearStats.last = key
    -- level, class, race, faction and guild of the player (db.seenInfo[Name-Realm]); what the game hides stays out
    do
        local function safe(fn, ...)
            local ok, a, b = pcall(fn, ...)
            if ok and not secret(a) and not secret(b) then return a, b end
        end
        local info = SFP.db.seenInfo or {}
        SFP.db.seenInfo = info
        local rec = info[key] or {}
        local lvl = safe(UnitLevel, unit)
        if type(lvl) == "number" and lvl > 0 then rec.lvl = lvl end
        local _, classToken = safe(UnitClass, unit)
        if type(classToken) == "string" then rec.class = classToken end
        local _, raceToken = safe(UnitRace, unit)
        if type(raceToken) == "string" then rec.race = raceToken end
        local faction = safe(UnitFactionGroup, unit)
        if type(faction) == "string" then rec.faction = faction end
        local guild = safe(GetGuildInfo, unit)
        -- a player saved with a guild who is seen WITHOUT one (twice, at least 10 minutes apart: a nameplate can show no guild for a moment)
        -- has left it: he is taken out of that guild, and a guild left with nobody (disbanded, or all gone) is removed from the directory
        if rec.guild and not (type(guild) == "string" and guild ~= "") and type(UnitIsPlayer) == "function" then
            local lastCheck = rec.noGuildT
            if not lastCheck then rec.noGuildT = time()
            elseif time() - lastCheck >= 600 then
                local realmOf = key:match("^[^-]+-(.+)$")
                local dir = SFP.db.guildDir and SFP.db.guildDir[realmOf]
                local g = dir and dir[rec.guild]
                if g and g.members then
                    g.members[key:match("^([^-]+)")] = nil
                    if next(g.members) == nil then dir[rec.guild] = nil end
                end
                rec.guild, rec.rank, rec.noGuildT = nil, nil, nil
            end
        elseif type(guild) == "string" and guild ~= "" then
            rec.noGuildT = nil
        end
        rec.guild = (type(guild) == "string" and guild ~= "") and guild or rec.guild
        -- the guild directory: guild, rank and rank index of this player, on his realm
        do
            local okGi, gName, gRank, gIndex = pcall(GetGuildInfo, unit)
            if okGi and type(gRank) == "string" and not secret(gRank) and gRank ~= "" then rec.rank = gRank end
            local okPv, pvp = pcall(UnitIsPVP, unit)
            if okPv and not secret(pvp) then rec.pvp = pvp and true or false end
            if okGi and type(gName) == "string" and not secret(gName) and gName ~= "" then
                local realmOf = key:match("^[^-]+-(.+)$")
                S.GuildNote(realmOf, gName, rec.faction, key:match("^([^-]+)"),
                    (type(gRank) == "string" and not secret(gRank)) and gRank or nil,
                    (type(gIndex) == "number" and not secret(gIndex)) and gIndex or nil)
            end
        end
        -- the nameplate itself: the name as it is written on it (with the title) and where you were when you saw it
        local pvpName = safe(UnitPVPName, unit)
        if type(pvpName) == "string" and pvpName ~= "" then rec.plate = pvpName end
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            rec.m = mapID
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos and pos.GetXY then
                local px, py = pos:GetXY()
                if px and not secret(px) and px > 0 then rec.x, rec.y = px, py end
            end
        end
        rec.t = time()
        info[key] = rec
    end
    -- Raider.IO at the same moment: the Mythic+ score (and last season's) and the raid progress, saved with the player. An answer younger
    -- than an hour is kept, so the many nameplate events of one player do not ask again and again.
    do
        SFP.db.rioCache = SFP.db.rioCache or {}
        local c = SFP.db.rioCache[key]
        if _G.RaiderIO and _G.RaiderIO.GetProfile and (not c or time() - (c.t or 0) > 86400) then
            local sc, raidText, prev, extra = rioInfo(unit)
            SFP.db.rioCache[key] = { score = sc, raid = raidText, prev = prev, best = extra and extra.best, timed = extra and extra.timed, warband = extra and extra.warband, prevSeason = extra and extra.prevSeason, timedLabel = extra and extra.timedLabel, main = extra and extra.main, t = time() }
        end
        -- the nameplate copied: the tooltip of the player with Raider.IO's lines, saved with the player
        local np = SFP.db.nameplateText and SFP.db.nameplateText[key]
        local seenNow = SFP.db.seenInfo and SFP.db.seenInfo[key]
        local changed = np and seenNow and (np.lvl ~= seenNow.lvl or np.guild ~= seenNow.guild or np.plate ~= seenNow.plate)
        if not np or changed or time() - (np.t or 0) > 86400 then
            local lines = captureNameplateText(unit)
            if lines then
                SFP.db.nameplateText = SFP.db.nameplateText or {}
                SFP.db.nameplateText[key] = { lines = lines, t = time(),
                    lvl = seenNow and seenNow.lvl, guild = seenNow and seenNow.guild, plate = seenNow and seenNow.plate }
            end
        end
    end
    SFP.db.seenPlayers = SFP.db.seenPlayers or {}
    SFP.db.seenPlayers[key] = time()
    -- the realm this name was seen on: a listed player of the same name is looked up there first
    local nmSeen, realmSeen = key:match("^([^-]+)-(.+)$")
    if nmSeen then SFP.db.nameRealms = SFP.db.nameRealms or {}; SFP.db.nameRealms[nmSeen] = realmSeen end
    -- the player ID (GUID) of the name, so a player is found by name or by ID in the addon's saved data
    local okG, guid = pcall(UnitGUID, unit)
    if okG and type(guid) == "string" and not secret(guid) then
        SFP.db.playerIDs = SFP.db.playerIDs or {}
        SFP.db.playerIDs[guid] = key
    end
    SFP.seenCount = (SFP.seenCount or 0) + 1   -- the saved list is never trimmed: it grows for good
end

-- the realm of a name the game gives without one (the listed players): where this name was seen, and the search over every realm.
-- The search tests the realms 25 at a time in the background; what is found is kept (db.nameRealm), and a name found nowhere is kept
-- as not found for 3 days. A name that exists on more than one realm gets the first realm that has data, the realm is shown next to it.
local realmQueue, realmCurrent = {}, nil
function S.QueueRealmSearch(nm)
    if not SFP.db or type(nm) ~= "string" then return end
    local c = SFP.db.nameRealm and SFP.db.nameRealm[nm]
    if c and (c.realm or (c.none and time() - (c.t or 0) < 3 * 86400)) then return end
    if realmCurrent and realmCurrent.nm == nm then return end
    for _, q in ipairs(realmQueue) do if q == nm then return end end
    if #realmQueue < 60 then realmQueue[#realmQueue + 1] = nm end
end

C_Timer.NewTicker(0.2, function()
    SFP:Safe("realm search", function()
        if not (_G.RaiderIO and _G.RaiderIO.GetProfile and SFP.db) then return end
        if not realmCurrent then
            local nm = table.remove(realmQueue, 1)
            if not nm then return end
            realmCurrent = { nm = nm, i = 1 }
        end
        local list = SFP.Realms or {}
        local nm, last = realmCurrent.nm, math.min(realmCurrent.i + 24, #list)
        SFP.db.nameRealm = SFP.db.nameRealm or {}
        for i = realmCurrent.i, last do
            local sc, raidText = rioInfo(nm, list[i])
            if sc or raidText then
                SFP.db.nameRealm[nm] = { realm = list[i], t = time() }
                realmCurrent = nil
                return
            end
        end
        realmCurrent.i = last + 1
        if realmCurrent.i > #list then
            SFP.db.nameRealm[nm] = { none = true, t = time() }
            realmCurrent = nil
        end
    end)
end)

-- scanning around you, the closest first: every player with a nameplate (either faction) gets his Raider.IO score and raid progress
-- saved (db.rioCache), so standing in a city already collects the Mythic+ of the people around; the inspect queue below saves item
-- level and talents of the ones who come into inspect range
C_Timer.NewTicker(3, function()
    SFP:Safe("scan nearby", function()
        local RIO = _G.RaiderIO
        if not (RIO and RIO.GetProfile and SFP.db and C_NamePlate and C_NamePlate.GetNamePlates) then return end
        local list = {}
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local u = plate.namePlateUnitToken
            if u and UnitIsPlayer(u) and not UnitIsUnit(u, "player") then
                local okD, d = pcall(UnitDistanceSquared, u)
                list[#list + 1] = { u = u, d = (okD and type(d) == "number" and not secret(d)) and d or 1e9 }
            end
        end
        table.sort(list, function(a, b) return a.d < b.d end)   -- the closest first, then farther out
        SFP.db.rioCache = SFP.db.rioCache or {}
        local done, now = 0, time()
        for _, e in ipairs(list) do
            local key = normKey(e.u)
            local c = key and SFP.db.rioCache[key]
            if key and (not c or now - (c.t or 0) > 86400) then
                local sc, raidText, prev = rioInfo(e.u)
                SFP.db.rioCache[key] = { score = sc, raid = raidText, prev = prev, t = now }
                done = done + 1
                if done >= 15 then break end
            end
        end
    end)
end)

-- players seen in chat (say, yell, emotes, channels such as Trade and General in a city): the chat line carries the player's ID, and
-- from it the name and the real realm. Noted without any nameplate, either faction, so a busy city fills the list by itself.
do
    local chatFrame = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_CHANNEL", "CHAT_MSG_WHISPER",
        "CHAT_MSG_PARTY", "CHAT_MSG_RAID", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_GUILD" }) do
        pcall(chatFrame.RegisterEvent, chatFrame, e)
    end
    chatFrame:SetScript("OnEvent", function(_, _, _, _, _, _, _, _, _, _, _, _, _, guid)
        if type(guid) ~= "string" or secret(guid) or not guid:find("^Player%-") or not SFP.db then return end
        local ok, _, _, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
        if not ok or type(name) ~= "string" or secret(name) or name == "" then return end
        if type(realm) ~= "string" or realm == "" or secret(realm) then realm = GetNormalizedRealmName and GetNormalizedRealmName() end
        if not realm then return end
        realm = realm:gsub("[%s'-]", "")
        local key = name .. "-" .. realm
        if name == UnitName("player") then return end
        if S.CanAddSeen and not S.CanAddSeen(key) then return end
        SFP.db.seenPlayers = SFP.db.seenPlayers or {}
        SFP.db.seenPlayers[key] = time()
        SFP.db.nameRealms = SFP.db.nameRealms or {}
        SFP.db.nameRealms[name] = realm
        SFP.db.playerIDs = SFP.db.playerIDs or {}
        SFP.db.playerIDs[guid] = key
    end)
end

-- /sfp near: how many nameplate events came and what became of them
local function printNear()
    local n = nearStats
    SFP:Print(("nameplate events %d: noted %d, not a player %d, hidden (secret) %d, yourself %d, no name %d; last noted: %s"):format(
        n.events, n.noted, n.notPlayer, n.secretPlayer, n.self, n.noKey, tostring(n.last)))
    local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
    SFP:Print("nameplates on screen now: " .. #plates)
end

-- /sfp near: prints the numbers once. It also prints by itself every 30 seconds, but only when new nameplate events came in since
-- the last time (so it is quiet while nothing happens). It is OFF by default: /sfp near on switches it on, /sfp near off back.
local lastNearPrinted = 0
function S.NearDebug(arg)
    local c = S.Config()
    if arg == "off" then c.nearDebug = false SFP:Print("nearby scan report: off") return end
    if arg == "on" then c.nearDebug = true SFP:Print("nearby scan report: on (every 30 seconds, when something happened)") return end
    printNear()
end

C_Timer.NewTicker(30, function()
    SFP:Safe("near report", function()
        if S.Config().nearDebug ~= true or nearStats.events == lastNearPrinted then return end
        lastNearPrinted = nearStats.events
        printNear()
    end)
end)

-- players who come into range are inspected one at a time (every 2.5 s, never in combat), and what is read stays for 5 minutes:
-- item level, talents, sockets and enchants without the player having this addon. It works within the game's inspect range.
local inspectQueue = {}
local function queueInspect(unit)
    if not (S.Config().autoInspect ~= false and UnitIsPlayer(unit)) or UnitIsUnit(unit, "player") then return end
    local okG, guid = pcall(UnitGUID, unit)
    if not okG or type(guid) ~= "string" or secret(guid) or inspectFresh(guid) then return end
    -- read within the last day (with the gear): not again so soon
    local key = normKey(unit)
    local sv = key and SFP.db and SFP.db.inspected and SFP.db.inspected[key]
    if sv and sv.gear and time() - (sv.t or 0) < 86400 then return end   -- a player is read again only after a day (or when his guild, level or name changed)
    for _, q in ipairs(inspectQueue) do if q.guid == guid then q.unit = unit return end end
    if #inspectQueue < 60 then inspectQueue[#inspectQueue + 1] = { unit = unit, guid = guid, since = GetTime() } end
end

-- The inspect needs the player within about 28 yards, the nameplate shows farther. A player who is not in range yet STAYS in the queue
-- (for up to 90 seconds) and is inspected as soon as he is in range; of those in range the Guild Masters and officers go first, then the
-- closest. One inspect every 1.6 seconds, never in combat.
C_Timer.NewTicker(1.6, function()
    SFP:Safe("inspect queue", function()
        if #inspectQueue == 0 or (InCombatLockdown and InCombatLockdown()) then return end
        if pendingGUID and GetTime() - lastInspect < 5 then return end   -- the last one has not answered yet
        local best, bestScore   -- best is the queue entry itself (the indexes shift while old entries are removed below)
        for i = #inspectQueue, 1, -1 do
            local q = inspectQueue[i]
            local okG, g = pcall(UnitGUID, q.unit)
            if not okG or g ~= q.guid or GetTime() - (q.since or 0) > 90 or inspectFresh(q.guid) then
                table.remove(inspectQueue, i)   -- gone, another player on that nameplate, too old, or done
            else
                local okR, inRange = pcall(CheckInteractDistance, q.unit, 1)
                if okR and inRange and not secret(inRange) then
                    local okD, d = pcall(UnitDistanceSquared, q.unit)
                    d = (okD and type(d) == "number" and not secret(d)) and d or 1e6
                    local okI, _, _, rankIndex = pcall(GetGuildInfo, q.unit)
                    if okI and type(rankIndex) == "number" and not secret(rankIndex) and rankIndex <= 1 then d = d * 0.05 end   -- leaders first
                    if not bestScore or d < bestScore then best, bestScore = q, d end
                end
            end
        end
        if best then
            for i, q in ipairs(inspectQueue) do
                if q == best then table.remove(inspectQueue, i) break end
            end
            requestInspect(best.unit)
        end
    end)
end)

nearFrame:SetScript("OnEvent", function(_, _, unit)
    SFP:Safe("note nearby player", notePlayer, unit)
    SFP:Safe("queue inspect", queueInspect, unit)
    SFP:Safe("ask nearby player", function()
        if not (C_ChatInfo and S.Config().share and unit and UnitIsPlayer(unit)) then return end
        if UnitIsUnit(unit, "player") or not UnitIsConnected(unit) or not UnitIsFriend("player", unit) then return end
        local key = unitKey(unit)
        if not key or peers[key] or peers[shortName(key)] then return end
        local last = queried[key]
        if last and GetTime() - last < 600 then return end
        if GetTime() - lastQuery < 1.5 then return end   -- one ask every moment: a crowd is asked one by one as the plates appear
        queried[key] = GetTime()
        lastQuery = GetTime()
        send("Q", "WHISPER", key)
    end)
end)

SFP:OnLogin(function()
    C_Timer.NewTicker(10, function() SFP:Safe("raider.io cache", S.UpdateRioCache) end)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    C_Timer.NewTicker(1800, function() SFP:Safe("counts", refreshCounts) end)
    lastMoney = GetMoney and GetMoney() or nil   -- the first reading: later gains are counted from here
    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tt)
            if tt ~= GameTooltip then return end
            local ok, _, unit = pcall(tt.GetUnit, tt)
            if ok and unit then SFP:Safe("player tooltip", playerTooltip, tt, unit) end
        end)
    end
end)

---------------------------------------------------------------------------
-- for other addons: everything the addon knows about a player by name, and the same lines as the tooltip.
--   local api = _G.SeviathsUsefulToolsAPI
--   local info = api.GetPlayer("Name-Realm")      -- or just "Name" (the realm is searched); a table, nil when nothing is known
--   api.AddPlayerTooltip(GameTooltip, "Name-Realm")   -- adds the lines (level, guild, item level, talent choice, scores ...)
-- info = { name, realm, lvl, class, race, faction, guild, spec, plate (the nameplate text), ilvl, talent, mplus, raid, empty, missing, seen }
---------------------------------------------------------------------------
SFP.API = SFP.API or {}
_G.SeviathsUsefulToolsAPI = SFP.API

function SFP.API.GetPlayer(fullName)
    if type(fullName) ~= "string" or not SFP.db then return nil end
    local nm, realm = fullName:match("^([^-]+)-(.+)$")
    nm = nm or fullName
    local keys = {}
    local function addKey(r) if r then keys[#keys + 1] = nm .. "-" .. r:gsub("[%s'-]", "") end end
    if realm then addKey(realm) else
        addKey(SFP.db.nameRealms and SFP.db.nameRealms[nm])
        addKey(SFP.db.nameRealm and SFP.db.nameRealm[nm] and SFP.db.nameRealm[nm].realm)
        addKey(GetNormalizedRealmName and GetNormalizedRealmName())
    end
    for _, key in ipairs(keys) do
        local info = SFP.db.seenInfo and SFP.db.seenInfo[key]
        local sv = SFP.db.inspected and SFP.db.inspected[key]
        local rc = SFP.db.rioCache and SFP.db.rioCache[key]
        if info or sv or rc then
            local out = { name = nm, realm = key:match("^[^-]+-(.+)$") }
            if info then for _, f in ipairs({ "lvl", "class", "race", "faction", "guild", "rank", "pvp", "spec", "plate" }) do out[f] = info[f] end end
            if sv then
                out.ilvl, out.empty, out.missing, out.gear = sv.ilvl, sv.empty, sv.missing, sv.gear
                out.spec = out.spec or sv.spec
                local tl = sv.tal
                out.talent = tl and ((tl.matchName and (tl.matchPct or 0) >= 0.4) and tl.matchName or tl.hero) or nil
            end
            if rc then out.mplus, out.raid = rc.score, rc.raid end
            out.seen = (info and info.t) or (sv and sv.t) or (rc and rc.t)
            return out
        end
    end
    return nil
end

function SFP.API.AddPlayerTooltip(tt, fullName)
    if tt and tt.AddLine and S.AddByName then pcall(S.AddByName, tt, fullName) end
end

---------------------------------------------------------------------------
-- Lists that show a custom tooltip for a player and are not a unit: the Communities member list (guild and communities), the club
-- finder's applicants and the like. When the frame the tooltip belongs to carries the player's record (memberInfo / info, with a
-- player ID), the addon's lines are added to that tooltip. It reads the frame, it does not change it.
---------------------------------------------------------------------------
do
    local adding = false
    local function playerOf(owner)
        if type(owner) ~= "table" then return nil end
        local candidates = {}
        local okM, mi = false, nil
        if type(owner.GetMemberInfo) == "function" then okM, mi = pcall(owner.GetMemberInfo, owner) end
        candidates[#candidates + 1] = okM and mi or nil
        candidates[#candidates + 1] = rawget(owner, "memberInfo")
        candidates[#candidates + 1] = rawget(owner, "info")
        candidates[#candidates + 1] = rawget(owner, "applicantInfo")
        for _, t in ipairs(candidates) do
            if type(t) == "table" and not (canaccesstable and not canaccesstable(t)) then
                for _, f in ipairs({ "guid", "playerGuid", "playerGUID" }) do
                    local g = t[f]
                    if type(g) == "string" and not secret(g) and g:find("^Player%-") then
                        local name = S.NameFromGUID(g)
                        if not name and type(t.name) == "string" and not secret(t.name) then name = t.name end
                        if name then return name end
                    end
                end
            end
        end
        return nil
    end

    local function onShow(tt)
        if adding or not SFP.db or not S.Config().tip then return end
        local okO, owner = pcall(tt.GetOwner, tt)
        if not okO or not owner or owner == UIParent then return end
        -- unit tooltips are handled by the unit hook
        local okU, _, unit = pcall(tt.GetUnit, tt)
        if okU and unit then return end
        local name = playerOf(owner)
        if not name then return end
        adding = true
        tt:AddLine(" ")
        pcall(S.AddByName, tt, name)
        adding = false
        tt:Show()
    end

    SFP:OnLogin(function()
        if GameTooltip and GameTooltip.HookScript then
            -- once per tooltip: the flag is reset when the tooltip is cleared
            local done = false
            GameTooltip:HookScript("OnTooltipCleared", function() done = false end)
            hooksecurefunc(GameTooltip, "Show", function(tt)
                if done or adding then return end
                done = true
                SFP:Safe("list tooltip", onShow, tt)
            end)
        end
    end)
end

-- your own guild: the whole roster with every rank goes into the directory (the game gives it for your guild)
do
    local function recordOwnGuild()
        if not (SFP.db and IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then return end
        local okG, gName = pcall(GetGuildInfo, "player")
        if not okG or type(gName) ~= "string" or secret(gName) or gName == "" then return end
        local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
        for i = 1, (GetNumGuildMembers() or 0) do
            local name, rankName, rankIndex = GetGuildRosterInfo(i)
            if type(name) == "string" and not secret(name) then
                local short, realm = name:match("^([^-]+)-(.+)$")
                realm = (realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or ""):gsub("[%s'-]", "")
                -- the realm of the guild: its own roster lists members of connected realms too; they are filed under the guild's realm
                local home = GetNormalizedRealmName and GetNormalizedRealmName() or realm
                S.GuildNote(home, gName, faction, short or name, rankName, type(rankIndex) == "number" and rankIndex or nil)
            end
        end
    end
    local gf = CreateFrame("Frame")
    gf:RegisterEvent("GUILD_ROSTER_UPDATE")
    gf:RegisterEvent("PLAYER_GUILD_UPDATE")
    local queued = false
    gf:SetScript("OnEvent", function()
        if queued then return end
        queued = true
        C_Timer.After(3, function() queued = false; SFP:Safe("own guild roster", recordOwnGuild) end)
    end)
    SFP:OnLogin(function()
        C_Timer.After(15, function()
            if IsInGuild and IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
        end)
    end)
end

---------------------------------------------------------------------------
-- The character you play is recorded like every other player: the same record the nameplate scan makes (level, class, race, faction,
-- guild with rank, spec, nameplate text, place), plus item level, talent choice and Raider.IO, in the same places (seenInfo, inspected,
-- rioCache, guildDir). It is the one player who always has this addon, so the whole chain can be tested on yourself.
---------------------------------------------------------------------------
function S.RecordSelf()
    if not SFP.db then return end
    local name = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if type(name) ~= "string" or not realm then return end
    local key = name .. "-" .. realm:gsub("[%s'-]", "")
    SFP.db.seenInfo = SFP.db.seenInfo or {}
    local rec = SFP.db.seenInfo[key] or {}
    SFP.db.seenInfo[key] = rec
    local lvl = UnitLevel("player")
    if type(lvl) == "number" and lvl > 0 then rec.lvl = lvl end
    local _, classToken = UnitClass("player")
    rec.class = classToken or rec.class
    local _, raceToken = UnitRace("player")
    rec.race = raceToken or rec.race
    rec.faction = UnitFactionGroup("player") or rec.faction
    local okGi, gName, gRank, gIndex = pcall(GetGuildInfo, "player")
    if okGi and type(gName) == "string" and gName ~= "" then
        rec.guild = gName
        S.GuildNote(realm:gsub("[%s'-]", ""), gName, rec.faction, name, gRank, gIndex)
    end
    local idx = GetSpecialization and GetSpecialization()
    local specID, specName
    if idx then specID, specName = GetSpecializationInfo(idx) end
    if type(specName) == "string" then rec.spec = specName end
    local okP, pvpName = pcall(UnitPVPName, "player")
    if okP and type(pvpName) == "string" and pvpName ~= "" then rec.plate = pvpName end
    local mapID = C_Map.GetBestMapForUnit("player")
    if mapID then
        rec.m = mapID
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos and pos.GetXY then
            local px, py = pos:GetXY()
            if px and px > 0 then rec.x, rec.y = px, py end
        end
    end
    rec.t = time()
    -- item level and talent choice (the same record an inspect makes for others)
    local overall, equipped = GetAverageItemLevel()
    local gear = SFP.GemHelper and SFP.GemHelper.CheckUnit and select(2, pcall(SFP.GemHelper.CheckUnit, "player")) or nil
    local sum = mySummary()
    SFP.db.inspected = SFP.db.inspected or {}
    SFP.db.inspected[key] = {
        ilvl = math.floor(tonumber(equipped) or tonumber(overall) or 0), t = time(), spec = rec.spec,
        tal = sum and { hero = sum.hero, matchName = sum.matchName, matchPct = sum.matchPct } or nil,
        empty = type(gear) == "table" and gear.any and gear.empty or nil,
        missing = type(gear) == "table" and gear.any and #gear.missing or nil,
        gear = S.GearDetail(gear),
    }
    -- the nameplate of yourself copied, with Raider.IO's lines
    do
        local lines = captureNameplateText("player")
        if lines then
            SFP.db.nameplateText = SFP.db.nameplateText or {}
            SFP.db.nameplateText[key] = { lines = lines, t = time() }
        end
    end
    -- Raider.IO of yourself
    local sc, raidText = rioInfo("player")
    SFP.db.rioCache = SFP.db.rioCache or {}
    SFP.db.rioCache[key] = { score = sc, raid = raidText, t = time() }
    SFP.db.seenPlayers = SFP.db.seenPlayers or {}
    SFP.db.seenPlayers[key] = time()
    SFP.db.nameRealms = SFP.db.nameRealms or {}
    SFP.db.nameRealms[name] = realm:gsub("[%s'-]", "")
    local g = UnitGUID("player")
    if type(g) == "string" then SFP.db.playerIDs = SFP.db.playerIDs or {}; SFP.db.playerIDs[g] = key end
end

do
    local selfFrame = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_LEVEL_UP", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "PLAYER_GUILD_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do
        pcall(selfFrame.RegisterEvent, selfFrame, e)
    end
    local queued = false
    selfFrame:SetScript("OnEvent", function()
        if queued then return end
        queued = true
        C_Timer.After(5, function() queued = false; SFP:Safe("record myself", S.RecordSelf) end)
    end)
    SFP:OnLogin(function()
        C_Timer.After(20, function() SFP:Safe("record myself", S.RecordSelf) end)
        C_Timer.NewTicker(600, function() SFP:Safe("record myself", S.RecordSelf) end)
    end)
end

-- Raider.IO score and raid progress of a player by name: (score, "5/8 M") or nil; for the lists that show it next to a name
function S.RioShort(fullName)
    if type(fullName) ~= "string" then return nil end
    local nm, realm = fullName:match("^([^-]+)-(.+)$")
    local sc, raidText, _, prev, extra = rioFind(nm or fullName, realm)
    -- the addon's saved answer when Raider.IO has none now (or is not loaded)
    if not sc and not raidText and SFP.db and SFP.db.rioCache and realm then
        local c = SFP.db.rioCache[(nm or fullName) .. "-" .. realm:gsub("[%s'-]", "")]
        if c then sc, raidText, extra, prev = c.score, c.raid, { best = c.best, timed = c.timed, warband = c.warband, prevSeason = c.prevSeason, timedLabel = c.timedLabel, main = c.main }, prev or c.prev end
    end
    -- Raider.IO has nobody by this name: the Mythic+ score the player's own addon shared with us fills the gap (Raider.IO wins when it has one)
    if not sc and not raidText then
        local rec = peers[fullName] or peers[nm or fullName]
        if rec and (rec.mplus or 0) > 0 then sc = rec.mplus; extra = extra or {}; extra.fromAddon = true end
    end
    return sc, raidText, prev, extra
end
