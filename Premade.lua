-- SeviathsUsefulTools - the Premade Groups list (Dungeons & Raids, the group finder)
-- Every group you see in the list is saved with what the game tells about it and about its leader: the leader's name, class, role, item level, Mythic+ score and PvP
-- rating, the activity, the group's size and wanted level. It is saved in SeviathsUsefulToolsDB.premade (players and groups), shipped with the addon in the zip
-- (tools/bake_collected.py) and so shared with everybody who installs it. Only data the game gives to addons is saved; nothing secret is read.

local _, SFP = ...

local MAX_PLAYERS, MAX_GROUPS = 8000, 3000
local function secret(v) return issecretvalue and issecretvalue(v) end
local function clean(v)
    if v == nil or secret(v) then return nil end
    return v
end

local function store()
    if not SFP.db then return end
    SFP.db.premade = SFP.db.premade or { players = {}, groups = {}, nPlayers = 0, nGroups = 0 }
    return SFP.db.premade
end

local function trim(t, key, max)
    -- the oldest are dropped when there are too many
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    if n <= max then return n end
    local list = {}
    for k, v in pairs(t) do list[#list + 1] = { k, v.t or 0 } end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    for i = 1, n - max do t[list[i][1]] = nil end
    return max
end

local function scanResult(id)
    local db = store()
    if not db then return end
    local ok, info = pcall(C_LFGList.GetSearchResultInfo, id)
    if not ok or type(info) ~= "table" then return end
    local now = time()
    local leader = clean(info.leaderName)
    local activity = info.activityIDs and clean(info.activityIDs[1]) or clean(info.activityID)
    local ilvl = clean(info.requiredItemLevel)
    local rec
    if type(leader) == "string" and leader ~= "" then
        rec = db.players[leader] or { first = now, seen = 0 }
        rec.seen = rec.seen + 1
        rec.t = now
        rec.score = clean(info.leaderOverallDungeonScore) or rec.score
        local pvp = clean(info.leaderPvpRatingInfo)
        if type(pvp) == "table" then rec.pvp = clean(pvp.rating) or rec.pvp end
        rec.activity = activity or rec.activity
        rec.lead = true
        -- class and role of the leader, from the member list (the first member is the leader)
        local okM, role, class = pcall(C_LFGList.GetSearchResultMemberInfo, id, 1)
        if okM then rec.role, rec.class = clean(role) or rec.role, clean(class) or rec.class end
        db.players[leader] = rec
    end
    -- every member whose class is shown: counted by class and role for the group
    local members = {}
    local n = clean(info.numMembers) or 0
    for i = 1, math.min(n, 5) do
        local okM, role, class = pcall(C_LFGList.GetSearchResultMemberInfo, id, i)
        if okM then members[#members + 1] = (clean(class) or "?") .. ":" .. (clean(role) or "?") end
    end
    local key = (leader or "?") .. "|" .. tostring(activity or 0)
    local g = db.groups[key] or { first = now }
    g.t = now
    g.name = clean(info.name) or g.name
    g.activity = activity or g.activity
    g.leader = leader or g.leader
    g.size = n
    g.ilvl = ilvl or g.ilvl
    g.score = clean(info.requiredDungeonScore) or g.score
    g.members = members
    db.groups[key] = g
end

local pending
local function scanAll()
    pending = nil
    if not (C_LFGList and C_LFGList.GetSearchResults) then return end
    local ok, count, results = pcall(C_LFGList.GetSearchResults)
    if not ok or type(results) ~= "table" then return end
    for _, id in ipairs(results) do pcall(scanResult, id) end
    local db = store()
    if db then
        db.nPlayers = trim(db.players, "players", MAX_PLAYERS)
        db.nGroups = trim(db.groups, "groups", MAX_GROUPS)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
f:SetScript("OnEvent", function()
    if pending then return end
    pending = true
    C_Timer.After(1, function() SFP:Safe("premade scan", scanAll) end)
end)

SLASH_SEVIATHSPREMADE1 = "/premade"
SlashCmdList["SEVIATHSPREMADE"] = function()
    local db = store()
    SFP:Print(("premade groups saved: %d players, %d groups"):format(db and db.nPlayers or 0, db and db.nGroups or 0))
end
