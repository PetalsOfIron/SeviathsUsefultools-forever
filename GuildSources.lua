-- SeviathsUsefulTools - guild information from what other addons and the game already collect
-- The guild directory (Social.lua: S.GuildNote) is fed here from two more sources, besides the nameplates, your own guild's roster and the
-- profiles of players who have this addon:
--   * /who results: every addon that scans /who (Fast Guild Invite, Guild Inviter, Guild Roster Manager's tools, this addon's Guild Helper ...)
--     makes the game answer with the guild of each player found. The addon reads those answers as they come (it sends no /who itself),
--     so guilds appear in the directory while any of those addons works.
--   * Guild Roster Manager (GRM): its saved roster of the guilds you were in, with every rank, is read when GRM is installed.
-- Guild Masters and officers also come from Raider.IO's guild data (tools/bake_guilds.py).

local _, SFP = ...
local S = SFP.Social

local function secret(v) return issecretvalue and issecretvalue(v) end

local function realmOf(name)
    local short, realm = tostring(name):match("^([^-]+)-(.+)$")
    return short or name, (realm and realm:gsub("[%s'-]", "")) or (GetNormalizedRealmName and GetNormalizedRealmName()) or nil
end

-- ---------------------------------------------------------------- /who answers
local who = CreateFrame("Frame")
who:RegisterEvent("WHO_LIST_UPDATE")
who:SetScript("OnEvent", function()
    SFP:Safe("guilds from /who", function()
        if not (SFP.db and C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetWhoInfo) then return end
        local faction = UnitFactionGroup and UnitFactionGroup("player") or nil   -- /who answers with players of your own faction
        local n = C_FriendList.GetNumWhoResults() or 0
        for i = 1, math.min(n, 50) do
            local okI, info = pcall(C_FriendList.GetWhoInfo, i)
            if okI and type(info) == "table" and not secret(info.fullName) and type(info.fullName) == "string" then
                local short, realm = realmOf(info.fullName)
                local guild = info.fullGuildName
                if realm and type(guild) == "string" and guild ~= "" and not secret(guild) then
                    S.GuildNote(realm, guild, faction, short, nil, nil)
                    -- the player himself: the same record the nameplate scan makes
                    local key = short .. "-" .. realm
                    if not S.CanAddSeen or S.CanAddSeen(key) then
                        SFP.db.seenPlayers = SFP.db.seenPlayers or {}
                        SFP.db.seenPlayers[key] = time()
                        SFP.db.seenInfo = SFP.db.seenInfo or {}
                        local rec = SFP.db.seenInfo[key] or {}
                        rec.guild = guild
                        rec.faction = faction or rec.faction
                        if type(info.level) == "number" and info.level > 0 then rec.lvl = info.level end
                        if type(info.filename) == "string" and not secret(info.filename) then rec.class = info.filename end
                        rec.t = time()
                        SFP.db.seenInfo[key] = rec
                    end
                end
            end
        end
    end)
end)

-- ---------------------------------------------------------------- Guild Roster Manager
-- GRM_GuildMemberHistory_Save[guildKey][playerKey] = { name, rankName, rankIndex, ... } with guildKey "Guild Name-Realm"
local function importGRM()
    local data = _G.GRM_GuildMemberHistory_Save
    if type(data) ~= "table" or not SFP.db then return 0 end
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local count = 0
    for guildKey, members in pairs(data) do
        if type(guildKey) == "string" and type(members) == "table" then
            local guildName, realm = guildKey:match("^(.*)%-([^%-]+)$")
            if guildName and realm then
                realm = realm:gsub("[%s'-]", "")
                for playerKey, m in pairs(members) do
                    if type(m) == "table" and type(m.rankName) == "string" then
                        local short = tostring(m.name or playerKey):match("^([^-]+)") or playerKey
                        local ri = type(m.rankIndex) == "number" and m.rankIndex or nil
                        S.GuildNote(realm, guildName, nil, short, m.rankName, ri)
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

SFP:OnLogin(function()
    C_Timer.After(40, function() SFP:Safe("import Guild Roster Manager", importGRM) end)
    C_Timer.NewTicker(900, function() SFP:Safe("import Guild Roster Manager", importGRM) end)
end)

-- which sources the directory is using right now (shown at the bottom of the Guild Directory window)
function S.GuildSourcesText()
    local out = { "nameplates", "your guild's roster", "players with this addon", "/who answers" }
    if SFP.GuildLeaders and next(SFP.GuildLeaders) then out[#out + 1] = "Raider.IO guild data" end
    if _G.GRM_GuildMemberHistory_Save then out[#out + 1] = "Guild Roster Manager" end
    if _G.FGI_DB or _G.FGI then out[#out + 1] = "Fast Guild Invite (its /who scans)" end
    if _G.GuildInviterDB then out[#out + 1] = "Guild Inviter (its /who scans)" end
    return "Sources: " .. table.concat(out, ", ")
end

-- ---------------------------------------------------------------- Communities (and your guild's community)
-- C_Club gives every community you are in with the role of each member: Owner, Leader, Moderator, Member. The owner, leaders and
-- moderators go into the directory under the realm "Communities" (a guild's own roster is read in Social.lua with full rank names):
-- Owner = rank 0 (shown as Guild Master), Leader = rank 1 (shown as Officer), Moderator = rank 2.
local function importClubs()
    if not (SFP.db and C_Club and C_Club.GetSubscribedClubs and C_Club.GetClubMembers and C_Club.GetMemberInfo) then return end
    local R = Enum and Enum.ClubRoleIdentifier
    if not R then return end
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local okC, clubs = pcall(C_Club.GetSubscribedClubs)
    if not okC or type(clubs) ~= "table" then return end
    for _, club in ipairs(clubs) do
        local clubName = club.name
        local isGuild = Enum.ClubType and club.clubType == Enum.ClubType.Guild
        if type(clubName) == "string" and not secret(clubName) and club.clubId and not isGuild then
            local okM, members = pcall(C_Club.GetClubMembers, club.clubId)
            if okM and type(members) == "table" and #members <= 1500 then
                for _, mid in ipairs(members) do
                    local okI, info = pcall(C_Club.GetMemberInfo, club.clubId, mid)
                    if okI and type(info) == "table" and type(info.name) == "string" and not secret(info.name) then
                        local role = info.role
                        if role == R.Owner or role == R.Leader or role == R.Moderator then
                            local short, realm = info.name:match("^([^-]+)-(.+)$")
                            local label = (role == R.Owner and "Owner") or (role == R.Leader and "Leader") or "Moderator"
                            S.GuildNote("Communities", clubName, faction, short or info.name,
                                label, (role == R.Owner and 0) or (role == R.Leader and 1) or 2,
                                realm and realm:gsub("[%s'-]", "") or (GetNormalizedRealmName and GetNormalizedRealmName()))
                        end
                    end
                end
            end
        end
    end
end

SFP:OnLogin(function()
    C_Timer.After(50, function() SFP:Safe("import communities", importClubs) end)
    C_Timer.NewTicker(1800, function() SFP:Safe("import communities", importClubs) end)
end)

-- ---------------------------------------------------------------- guild notes
-- The public note every member can write next to his name in the guild roster (often the playstyle). The game gives it only for the
-- guild you are in; it is saved with the player (db.guildNotes["Name-Realm"]) and shown blue in his tooltip.
local function scanNotes()
    if not (SFP.db and IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then return end
    SFP.db.guildNotes = SFP.db.guildNotes or {}
    local home = GetNormalizedRealmName and GetNormalizedRealmName() or ""
    for i = 1, (GetNumGuildMembers() or 0) do
        local name, _, _, _, _, _, note, _, _, _, _, achPoints = GetGuildRosterInfo(i)
        if type(name) == "string" and not secret(name) then
            local short, realm = realmOf(name)
            local key = short .. "-" .. (realm or home)
            -- the achievement points of a guildmate: the roster has them for everyone in the guild, with or without this addon
            if type(achPoints) == "number" and not secret(achPoints) and achPoints > 0 then
                SFP.db.guildAch = SFP.db.guildAch or {}
                SFP.db.guildAch[key] = { pts = achPoints, t = time() }
            end
            if type(note) == "string" and not secret(note) and note ~= "" then
                SFP.db.guildNotes[key] = { note = note, t = time() }
            else
                SFP.db.guildNotes[key] = nil
            end
        end
    end
end

local notesFrame = CreateFrame("Frame")
notesFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
notesFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
local lastScan = 0
notesFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(8, function() if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end end)
        return
    end
    if GetTime() - lastScan < 30 then return end
    lastScan = GetTime()
    SFP:Safe("guild notes", scanNotes)
end)

-- the note of a player (full name "Name-Realm" or just "Name"), as a blue line on a tooltip
function S.AddGuildNote(tt, fullName, hasProfile)
    if not (SFP.db and SFP.db.guildNotes and type(fullName) == "string") then return end
    local short, realm = realmOf(fullName)
    local rec = SFP.db.guildNotes[short .. "-" .. (realm or "")]
        or SFP.db.guildNotes[short .. "-" .. (GetNormalizedRealmName and GetNormalizedRealmName() or "")]
    if rec and rec.note then tt:AddLine("Guild note: " .. rec.note, 0.35, 0.65, 1, true) end
    -- achievement points from the guild roster, when the tooltip has none (the addon's own profile line says them for addon users)
    local ach = SFP.db.guildAch and (SFP.db.guildAch[short .. "-" .. (realm or "")]
        or SFP.db.guildAch[short .. "-" .. (GetNormalizedRealmName and GetNormalizedRealmName() or "")])
    if ach and ach.pts and not hasProfile then   -- a player with this addon has his own achievements line
        local has = false
        local nm = tt.GetName and tt:GetName()
        for i = 2, (tt.NumLines and tt:NumLines() or 0) do
            local ln = nm and _G[nm .. "TextLeft" .. i]
            local txt = ln and ln.GetText and ln:GetText()
            if type(txt) == "string" and not secret(txt) and txt:find("Achievements", 1, true) then has = true break end
        end
        if not has then tt:AddLine("Achievements: |cffffffff" .. ach.pts .. "|r", 0.8, 0.8, 0.8) end
    end
end
