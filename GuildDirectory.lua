-- SeviathsUsefulTools - Guild Directory window
-- A window of its own: a button for every realm across the top (Argent Dawn, Kazzak, Silvermoon ...); the one you pick lists all the guilds
-- the addon knows on that realm, each with its faction, its Guild Master and its officers (with what is recorded about them, and a
-- Whisper button). The data is collected by the nameplate scan, by your own guild's roster and by the profiles of players who have
-- this addon (see Social.lua: S.GuildNote).

local _, SFP = ...

local FACTION_HEX = { Alliance = "ff4a8cff", Horde = "ffff4a4a" }
local PAGE = 120   -- realm buttons: all of them (the realm bar has no pages any more)
local WIN_W, WIN_H = 1250, 880
local GUILDS_PER_PAGE = 14   -- guilds per page of the list: after every 14 there is a new page, without any end

local win, list, realmButtons, pager = nil, nil, {}, nil
local rioText = {}   -- "Name-Realm" -> { text, t }: what Raider.IO said about a leader, kept for 2 minutes (the lookups are not cheap)
local state = { realm = nil, faction = nil, region = nil, search = "", page = 1, gpage = 1 }
local factionButtons = {}
local regionButtons = {}

-- US or EU: the region of the player at first (the realm lists below show the realms of the region picked)
local EU_LOCALES = { enGB = true, deDE = true, frFR = true, esES = true, itIT = true, ruRU = true, ptPT = true }
local function ownRegion()
    local r = GetCurrentRegion and GetCurrentRegion()
    if r == 3 then return "eu" end
    -- the game's region number is not always the region of the account: a European client language says it too
    local loc = GetLocale and GetLocale()
    if r ~= 1 and loc and EU_LOCALES[loc] then return "eu" end
    local own = GetNormalizedRealmName and GetNormalizedRealmName()
    local v = own and SFP.RealmRegion and SFP.RealmRegion[own]
    if v == "eu" or v == "us" then return v end   -- a realm only one region has
    return (r == 1 or not loc or not EU_LOCALES[loc]) and "us" or "eu"
end

-- does a realm belong to the region picked? A realm name that exists in both regions belongs to the player's own region (the guilds collected
-- here come from the player's own scans), a realm the data does not know too
-- WoW Forever is one big server for everybody (no US and EU, no list of realms): every guild belongs to the one list
local FOREVER = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT

-- the kind of a Forever server, read from its name (the megaserver is split into Normal, PvP, Roleplay and Roleplay PvP): "...Realm10RP" is a roleplay one
local TYPE_ORDER = { "normal", "pvp", "rp", "rppvp" }
local TYPE_LABEL = { normal = "Normal", pvp = "PvP", rp = "Roleplay", rppvp = "Roleplay PvP" }
local function nameType(realm)
    local r = tostring(realm or ""):upper()
    if r:find("RPPVP$") or r:find("PVPRP$") or r:find("RP_?PVP") then return "rppvp" end
    if r:find("PVP$") then return "pvp" end
    if r:find("RP$") then return "rp" end
    return "normal"
end

-- the kind of the server a guild is on: from its server name when that is a real server name ("CAMWOWEU4Realm10RP"); the "realm" Forever gives
-- for most players is only the second part of their name, and the players seen around you are on your own server, so those are of your own kind
local function serverType(realm)
    if tostring(realm or ""):find("Realm%d") then return nameType(realm) end
    local own = SFP.RealmKey and SFP:RealmKey() or (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    return nameType(own)
end

local function inRegion(realm)
    if FOREVER then return true end
    local picked = state.region or ownRegion()
    local v = SFP.RealmRegion and SFP.RealmRegion[realm]
    if v == "us" or v == "eu" then return v == picked end
    return picked == ownRegion()
end

-- the faction of a guild: saved with it, or from the shipped guild data; nil while nothing says
local function factionOfGuild(realm, name, g)
    if g and g.faction then return g.faction end
    local baked = SFP.GuildLeaders and SFP.GuildLeaders[realm] and SFP.GuildLeaders[realm][name]
    return baked and baked.faction or nil
end

local function matchesFaction(realm, name, g)
    local f = factionOfGuild(realm, name, g)
    if state.faction == "Unknown" then return f == nil end
    return f == state.faction
end

-- guilds per faction over all realms (the numbers on the two big buttons)
local function factionCounts()
    local c, seen = { Alliance = 0, Horde = 0, Unknown = 0 }, {}
    for realm, guilds in pairs((SFP.db and SFP.db.guildDir) or {}) do
        for name, g in pairs(guilds) do
            local f = factionOfGuild(realm, name, g)
            -- Forever: a guild seen under two "realms" (the second part of a player's name) is one guild
            local key = FOREVER and (serverType(realm) .. "|" .. name) or nil
            if not (key and seen[key]) then
                if key then seen[key] = true end
                c[f or "Unknown"] = (c[f or "Unknown"] or 0) + 1
            end
        end
    end
    return c
end

-- the realms that have guilds of the faction picked at the top, with how many
local function realms()
    local out, own = {}, GetNormalizedRealmName and GetNormalizedRealmName() or nil
    if not state.faction then state.faction = UnitFactionGroup and UnitFactionGroup("player") or "Horde" end
    if FOREVER then
        -- four choices: Normal, PvP, Roleplay, Roleplay PvP, each with the guilds of the faction picked
        local counts, seen = { normal = 0, pvp = 0, rp = 0, rppvp = 0 }, {}
        for realm, guilds in pairs((SFP.db and SFP.db.guildDir) or {}) do
            local t = serverType(realm)
            seen[t] = seen[t] or {}
            -- a guild is counted once, also when it was seen under two "realms" (the second part of a player's name)
            for name, g in pairs(guilds) do
                if matchesFaction(realm, name, g) and not seen[t][name] then seen[t][name] = true; counts[t] = counts[t] + 1 end
            end
        end
        for _, t in ipairs(TYPE_ORDER) do out[#out + 1] = { realm = t, n = counts[t] } end
        return out
    end
    for realm, guilds in pairs((SFP.db and SFP.db.guildDir) or {}) do
        local n = 0
        if inRegion(realm) then
            for name, g in pairs(guilds) do if matchesFaction(realm, name, g) then n = n + 1 end end
        end
        if n > 0 then out[#out + 1] = { realm = realm, n = n } end
    end
    table.sort(out, function(a, b)
        if (a.realm == own) ~= (b.realm == own) then return a.realm == own end
        if a.n ~= b.n then return a.n > b.n end
        return a.realm < b.realm
    end)
    return out
end

-- "ArgentDawn" -> "Argent Dawn"
-- a Forever player has two names ("Aelora Starweaver"): the game gives the first as the name and the second in the place of the realm
local function fullShown(name, realm)
    if FOREVER and type(realm) == "string" and realm ~= "" and not realm:find("Realm%d") then return name .. " " .. realm end
    return name
end

local function pretty(realm) return (realm:gsub("(%l)(%u)", "%1 %2")) end

local function items(realm, gpage)
    local S = SFP.Social
    local out = {}
    local guilds = {}
    -- the guilds to list: those of one realm, or (Forever) those of every server of the kind picked
    local sources = {}
    if FOREVER then
        for r, gs in pairs((SFP.db.guildDir) or {}) do
            if serverType(r) == realm then for name, g in pairs(gs) do sources[#sources + 1] = { r, name, g } end end
        end
    else
        for name, g in pairs((SFP.db.guildDir and SFP.db.guildDir[realm]) or {}) do sources[#sources + 1] = { realm, name, g } end
    end
    local byName = {}
    for _, s in ipairs(sources) do
        local r, name, g = s[1], s[2], s[3]
        if matchesFaction(r, name, g) and (state.search == "" or name:lower():find(state.search, 1, true)) then
            local n = 0
            for _ in pairs(g.members or {}) do n = n + 1 end
            if FOREVER and byName[name] then
                -- one guild seen under two "realms" (the second part of a player's name): one entry with the members of both
                local e = byName[name]
                for member, m in pairs(g.members or {}) do
                    if not e.g.members[member] then
                        local m2 = {}
                        for k2, v2 in pairs(m) do m2[k2] = v2 end
                        m2.realm = m2.realm or r
                        e.g.members[member] = m2
                    end
                end
                e.g.o = math.min(e.g.o or math.huge, g.o or math.huge)
                if not e.g.faction then e.g.faction = g.faction end
                n = 0
                for _ in pairs(e.g.members) do n = n + 1 end
                e.n = n
            else
                local entry = { name = name, g = g, n = n, realm = r }
                if FOREVER then
                    local copy = { members = {}, o = g.o, faction = g.faction, t = g.t }
                    for member, m in pairs(g.members or {}) do
                        local m2 = {}
                        for k2, v2 in pairs(m) do m2[k2] = v2 end
                        m2.realm = m2.realm or r   -- the second part of the name (Forever players have two names)
                        copy.members[member] = m2
                    end
                    entry.g = copy
                    byName[name] = entry
                end
                guilds[#guilds + 1] = entry
            end
        end
    end
    -- in the order they were first saved: a new guild always comes last
    table.sort(guilds, function(a, b)
        local oa, ob = a.g.o or 0, b.g.o or 0
        if oa ~= ob then return oa < ob end
        return a.name < b.name
    end)
    local api = _G.SeviathsUsefulToolsAPI
    local total = #guilds
    local firstGuild = (gpage - 1) * GUILDS_PER_PAGE + 1
    for i = firstGuild, math.min(total, firstGuild + GUILDS_PER_PAGE - 1) do
        local e = guilds[i]
        local realm = e.realm or realm   -- the server of this guild (Forever: the kind picked holds several)
        -- the faction: saved with the guild, or the one of any of its players the addon knows
        local baked = SFP.GuildLeaders and SFP.GuildLeaders[realm] and SFP.GuildLeaders[realm][e.name]
        if baked and baked.gm and baked.gm:find("%-%d%d%d%d+$") then baked = { officers = baked.officers, faction = baked.faction, date = baked.date } end
        local faction = e.g.faction or (baked and baked.faction)
        if not faction then
            for member in pairs(e.g.members or {}) do
                local pi = api and api.GetPlayer and api.GetPlayer(member .. "-" .. realm)
                if pi and pi.faction then faction = pi.faction; e.g.faction = faction break end
            end
        end
        out[#out + 1] = { text = ("|cffffd100%s|r  |c%s%s|r  |cff808080%d player%s seen|r%s"):format(e.name,
            FACTION_HEX[faction or ""] or "ff808080", faction or "faction not known yet", e.n, e.n == 1 and "" or "s",
            (baked and baked.raid) and ("  |cffb0b0b0raid " .. baked.raid .. " (Raider.IO)|r") or ""), buttons = {} }
        local master, officers = S.GuildLeaders(e.g)

        local function leaderInfo(name)
            local mm = e.g.members and e.g.members[name]
            local full = name .. "-" .. ((mm and mm.realm) or realm)
            local info = api and api.GetPlayer and api.GetPlayer(full)
            local parts = {}
            if name == UnitName("player") then parts[#parts + 1] = "|cff40ff40you (has the addon)|r"
            elseif S.peers and (S.peers[full] or S.peers[name]) then parts[#parts + 1] = "|cff40ff40has the addon|r" end
            if info then
                -- the whole record: level, race, spec and class, faction, guild, item level, talent choice, scores, gems and enchants
                local head = {}
                if info.lvl then head[#head + 1] = "L" .. info.lvl end
                if info.race then head[#head + 1] = info.race end
                if info.spec or info.class then head[#head + 1] = ((info.spec and (info.spec .. " ")) or "") .. (info.class or "") end
                if #head > 0 then parts[#parts + 1] = table.concat(head, " ") end
                if info.faction then parts[#parts + 1] = info.faction end
                if info.guild then parts[#parts + 1] = "<" .. info.guild .. ">" end
                if info.ilvl and info.ilvl > 0 then parts[#parts + 1] = "ilvl " .. info.ilvl end
                if info.talent then parts[#parts + 1] = info.talent end
                if info.mplus then parts[#parts + 1] = "M+ " .. info.mplus end
                if info.raid then parts[#parts + 1] = "raid " .. info.raid end
                local gd = info.gear
                if gd then
                    parts[#parts + 1] = (gd.nGems or 0) > 0 and (gd.nGems .. " gems") or "no gems"
                    local have, lack = gd.nEnchants or 0, #(gd.missing or {})
                    parts[#parts + 1] = have > 0 and (have .. " of " .. (have + lack) .. " enchants") or "no enchants"
                end
            end
            return #parts > 0 and (table.concat(parts, "  -  ")) or "", info
        end

        local function leaderRow(role, name, note)
            local mm = e.g.members and e.g.members[name]
            local full = name .. "-" .. ((mm and mm.realm) or realm)
            local detail, info = leaderInfo(name)
            -- Raider.IO right next to the name: the Mythic+ score and the raid progress (asked once, kept for 2 minutes)
            local rc = rioText[full .. "|short"]
            if not rc or GetTime() - rc.t > 120 then
                local okS, sc, raid, prev, extra = pcall(S.RioShort, full)
                rc = { sc = okS and sc or nil, raid = okS and raid or nil, prev = okS and prev or nil,
                    best = okS and extra and extra.best or nil, timed = okS and extra and extra.timed or nil,
                    warband = okS and extra and extra.warband or nil, prevSeason = okS and extra and extra.prevSeason or nil, fromAddon = okS and extra and extra.fromAddon or nil,
                    timedLabel = okS and extra and extra.timedLabel or nil, main = okS and extra and extra.main or nil, t = GetTime() }
                rioText[full .. "|short"] = rc
            end
            -- recorded: the Raider.IO score and raid progress of the Guild Master / officer are saved with the player (the Raider.IO cache) and
            -- with his entry in the guild, so they stay in the saved data
            if (rc.sc or rc.raid) and SFP.db and not rc.fromAddon then
                SFP.db.rioCache = SFP.db.rioCache or {}
                SFP.db.rioCache[full] = { score = rc.sc, raid = rc.raid, prev = rc.prev, prevSeason = rc.prevSeason, timedLabel = rc.timedLabel, main = rc.main, best = rc.best, timed = rc.timed, warband = rc.warband, t = time() }
                if mm then mm.rio, mm.rioRaid = rc.sc, rc.raid end
            end
            -- three groups, written as Raider.IO writes them; a group that has nothing is left out. The row is one line, so the groups
            -- continue on the lines below it (hover any of them for the whole tooltip)
            local g1, g2, g3 = "", "", ""
            if rc.sc then g1 = g1 .. ("  |cffffd100M+ Score %d|r"):format(rc.sc) .. (rc.fromAddon and " |cff808080(from their addon)|r" or "") end
            if rc.prev then g1 = g1 .. ("  |cffb0b0b0Previous M+ Score%s %d|r"):format(rc.prevSeason and (" (" .. rc.prevSeason .. ")") or "", rc.prev) end
            if rc.warband then g1 = g1 .. ("  |cffb0b0b0Warband M+ Score %d|r"):format(rc.warband) end
            if rc.best then g2 = g2 .. ("  |cffb0b0b0Best Run %s|r"):format(rc.best) end
            if rc.timed then
                local lv, cnt = rc.timed:match("^(%d+%+?): (.+)$")
                g2 = g2 .. ((rc.timedLabel and cnt) and ("  |cffb0b0b0%s %s|r"):format(rc.timedLabel, cnt) or lv and ("  |cffb0b0b0Timed %s Runs %s|r"):format(lv:find("%+") and lv or (lv .. "+"), cnt) or ("  |cffb0b0b0Timed %s|r"):format(rc.timed))
            end
            if rc.raid then g3 = g3 .. ("  |cffb0b0b0Raid Progress %s|r"):format(rc.raid) end
            if rc.main then g3 = g3 .. ("  |cffb0b0b0Main's Progress %s|r"):format(rc.main) end
            local rio = g1
            -- the row shows only the Mythic+ score and the raid progress (Raider.IO's); everything else is in the tooltip on hover
            local function tip(tt)
                tt:AddLine(("%s  |cff808080%s, %s|r"):format(fullShown(name, mm and mm.realm), role, pretty(realm)), 0.9, 0.28, 0.24)
                S.AddByName(tt, full)
            end
            -- the row: the role and the name as the nameplate wrote it; hover: the nameplate and everything recorded about this player
            out[#out + 1] = {
                -- the plain name, without the title of the nameplate (the title is in the tooltip)
                text = ("      %s: %s%s%s"):format(role, fullShown(name, mm and mm.realm), rio,
                    note and ("  |cff808080" .. note .. "|r") or ""),
                buttons = { { "Whisper", 70, function() if ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. full .. " ") end end } },
                tip = tip,
            }
            for _, more in ipairs({ g2, g3 }) do
                if more ~= "" then out[#out + 1] = { text = "              " .. more:gsub("^%s+", ""), buttons = {}, tip = tip } end
            end
        end

        -- the Guild Master: seen by you, else from Raider.IO's guild data (tools/bake_guilds.py), else not known yet
        if master then leaderRow("Guild Master", master)
        elseif baked and baked.gm then leaderRow("Guild Master", baked.gm, "(Raider.IO, " .. (baked.date or "?") .. ")")
        else out[#out + 1] = { text = "      Guild Master: |cff808080not seen yet|r", buttons = {} } end
        -- officers from the same data, when you have not seen that many yourself (rank 1; at most 6 are listed)
        local have = {}
        for _, o in ipairs(officers) do have[o] = true end
        local bakedOfficers = {}
        for _, o in ipairs((baked and baked.officers) or {}) do if not have[o] then bakedOfficers[#bakedOfficers + 1] = o end end
        -- the officers go below the Guild Master; with none seen yet the line says so
        if #officers == 0 and #bakedOfficers == 0 then
            out[#out + 1] = { text = "      Officer: |cff808080not seen yet|r", buttons = {} }
        end
        for _, o in ipairs(officers) do
            local m = e.g.members[o]
            leaderRow("Officer" .. ((m and m.rank) and (" (" .. m.rank .. ")") or ""), o)
        end
        for i, o in ipairs(bakedOfficers) do
            if i > 6 then
                out[#out + 1] = { text = ("      |cff808080+ %d more officers (Raider.IO)|r"):format(#bakedOfficers - 6), buttons = {} }
                break
            end
            leaderRow("Officer", o, "(Raider.IO, " .. (baked.date or "?") .. ")")
        end
        -- space between one guild and the next
        out[#out + 1] = { text = " ", buttons = {} }
        out[#out + 1] = { text = " ", buttons = {} }
    end
    return out, total
end

local FACTION_RGB = { Alliance = { 0.35, 0.6, 1 }, Horde = { 1, 0.3, 0.3 }, Unknown = { 0.7, 0.7, 0.7 } }

local function refresh()
    if not (win and win:IsShown()) then return end
    local rl = realms()
    -- the two big sections at the top: Alliance and Horde (and Unknown while some guild has no faction yet); the one picked is pressed
    local counts = factionCounts()
    for _, f in ipairs({ "Alliance", "Horde", "Unknown" }) do
        local b = factionButtons[f]
        if b then
            b:SetText(("%s  (%d)"):format(f == "Unknown" and "Faction unknown" or f, counts[f] or 0))
            local rgb = FACTION_RGB[f]
            b:GetFontString():SetTextColor(rgb[1], rgb[2], rgb[3])
            b:SetEnabled(state.faction ~= f)
            b:SetShown(f ~= "Unknown" or (counts.Unknown or 0) > 0)
        end
    end
    for key, b in pairs(regionButtons) do b:SetEnabled((state.region or ownRegion()) ~= key) end   -- the region shown is the pressed one
    if #rl == 0 then
        for _, b in ipairs(realmButtons) do b:Hide() end
        pager.text:SetText("")
        pager.gtext:SetText("")
        list:Set({ { text = "|cff808080No " .. tostring(state.faction) .. " guild seen yet. Pass players of a guild (a guild name on their nameplate) and it shows up here.|r", buttons = {} } })
        return
    end
    -- the realm to show: the one picked (when it still exists), else the first
    local found = false
    for _, r in ipairs(rl) do if r.realm == state.realm then found = true end end
    if not found then
        state.realm = FOREVER and serverType("") or rl[1].realm
    end
    -- the realm bar: PAGE buttons per page
    local pages = math.max(1, math.ceil(#rl / PAGE))
    state.page = math.min(math.max(state.page, 1), pages)
    local first = (state.page - 1) * PAGE
    local x, y = 14, -98
    for i = 1, PAGE do
        local r = rl[first + i]
        local b = realmButtons[i]
        if not b then
            b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
            b:SetHeight(22)
            realmButtons[i] = b
        end
        if r then
            b:SetText(("%s (%d)"):format(FOREVER and TYPE_LABEL[r.realm] or pretty(r.realm), r.n))
            local w = math.max(80, b:GetFontString():GetStringWidth() + 20)
            b:SetWidth(w)
            if x + w > WIN_W - 30 then x = 14; y = y - 26 end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", x, y)
            x = x + w + 4
            b:SetEnabled(r.realm ~= state.realm)   -- the realm shown is the pressed one
            b:SetScript("OnClick", function() state.realm = r.realm; state.gpage = 1; refresh() end)
            b:Show()
        else
            b:Hide()
        end
    end
    pager.text:SetText(FOREVER and "" or ("%d realm%s"):format(#rl, #rl == 1 and "" or "s"))
    pager.prev:Hide()
    pager.next:Hide()
    -- below the last row of realm buttons: the pager of the guild list and the search, then the list down to the bottom
    local pagerY = y - 34
    pager.text:ClearAllPoints()
    pager.text:SetPoint("TOPLEFT", 16, pagerY - 4)
    pager.box:ClearAllPoints(); pager.box:SetPoint("TOPRIGHT", -20, pagerY)
    local listTop = pagerY - 34
    list.scroll:ClearAllPoints()
    list.scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 12, listTop)
    list.scroll:SetSize(WIN_W - 12 - 36, WIN_H + listTop - 84)   -- room under the list for the page buttons and the sources line
    -- the list: 14 guilds per page; an error is shown in the list itself (and kept for /sfp errors), not as an empty list
    local okT, _, total = pcall(items, state.realm, 1)
    if not okT then
        SFP:CatchError("guild directory list", _)
        list:Set({ { text = "|cffff6060The list could not be built:|r " .. tostring(_), buttons = {} } })
        return
    end
    local gpages = math.max(1, math.ceil((total or 0) / GUILDS_PER_PAGE))
    state.gpage = math.min(math.max(state.gpage, 1), gpages)
    local okR, rows = pcall(items, state.realm, state.gpage)
    if not okR then
        SFP:CatchError("guild directory page", rows)
        list:Set({ { text = "|cffff6060The page could not be built:|r " .. tostring(rows), buttons = {} } })
        return
    end
    list:Set(rows)
    pager.gtext:SetText(total > 0 and ("Page %d of %d   |cffb0b0b0(guilds %d-%d of %d)|r"):format(state.gpage, gpages,
        (state.gpage - 1) * GUILDS_PER_PAGE + 1, math.min(total, state.gpage * GUILDS_PER_PAGE), total) or "no guild")
    pager.gprev:SetEnabled(state.gpage > 1)
    pager.gnext:SetEnabled(state.gpage < gpages)
end

local function build()
    if win then return end
    win = SFP.MakeToolWindow("SeviathsUsefulToolsGuildDir", "Guild Directory", WIN_W, WIN_H)
    -- closed: what was looked up for the page that was open is forgotten (the rows are made again, for the page that is open, when it opens)
    win:HookScript("OnHide", function() wipe(rioText) end)
    win.scroll:Hide()
    -- the two big sections at the top: Alliance and Horde swap the realm list below (and the guilds) to that faction
    local function bigButton(f, x, w)
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        b:SetSize(w, 30)
        b:SetPoint("TOPLEFT", x, -34)
        b:SetScript("OnClick", function() state.faction = f; state.realm = nil; state.page = 1; state.gpage = 1; refresh() end)
        factionButtons[f] = b
    end
    bigButton("Alliance", 14, 500)
    bigButton("Horde", 518, 500)
    bigButton("Unknown", 1022, 214)
    -- US and EU, above the realm buttons: the realms below are the ones of the region picked
    for i, def in ipairs(FOREVER and {} or { { "us", "US" }, { "eu", "EU" } }) do
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        b:SetSize(70, 22)
        b:SetPoint("TOPLEFT", 14 + (i - 1) * 74, -68)
        b:SetText(def[2])
        b:SetScript("OnClick", function() state.region = def[1]; state.realm = nil; state.page = 1; state.gpage = 1; refresh() end)
        regionButtons[def[1]] = b
    end
    -- the row below the realm buttons: pagers and search
    pager = {}
    pager.prev = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    pager.prev:SetSize(24, 20); pager.prev:SetPoint("TOPLEFT", 14, -154); pager.prev:SetText("<")
    pager.prev:SetScript("OnClick", function() state.page = state.page - 1; refresh() end)
    pager.next = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    pager.next:SetSize(24, 20); pager.next:SetPoint("TOPLEFT", 40, -154); pager.next:SetText(">")
    pager.next:SetScript("OnClick", function() state.page = state.page + 1; refresh() end)
    pager.text = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pager.text:SetPoint("LEFT", pager.next, "RIGHT", 8, 0)
    -- the pages of the guild list (20 guilds each)
    -- the page buttons at the bottom, large, with words: where people look for them
    pager.gprev = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    pager.gprev:SetSize(170, 30); pager.gprev:SetPoint("BOTTOM", win, "BOTTOM", -240, 32); pager.gprev:SetText("<<  Previous page")
    pager.gprev:SetScript("OnClick", function() state.gpage = state.gpage - 1; refresh() end)
    pager.gnext = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    pager.gnext:SetSize(170, 30); pager.gnext:SetPoint("BOTTOM", win, "BOTTOM", 240, 32); pager.gnext:SetText("Next page  >>")
    pager.gnext:SetScript("OnClick", function() state.gpage = state.gpage + 1; refresh() end)
    for _, b in ipairs({ pager.gprev, pager.gnext }) do b:GetFontString():SetTextColor(1, 0.82, 0) end
    pager.gtext = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pager.gtext:SetPoint("BOTTOM", win, "BOTTOM", 0, 39)
    local box = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
    box:SetSize(150, 20); box:SetPoint("TOPRIGHT", -20, -154)
    pager.box = box
    box:SetAutoFocus(false); box:SetMaxLetters(30)
    box:SetScript("OnTextChanged", function(self) state.search = (self:GetText() or ""):lower(); state.gpage = 1; refresh() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local hint = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -1)
    hint:SetText("|cff808080search a guild|r")
    list = SFP.MakeRowList(win, 12, -196, WIN_W - 24, 440, 24)   -- taller rows: more air between the lines (placed by refresh)
    local src = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    src:SetPoint("BOTTOMLEFT", 14, 6)
    src:SetWidth(WIN_W - 30)
    src:SetJustifyH("LEFT")
    win.sources = src
    -- the list follows what the addon learns while the window is open
    local acc = 0
    win:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc >= 20 then acc = 0; SFP:Safe("guild directory", refresh) end
    end)
    win:SetScript("OnShow", function()
        if win.sources and SFP.Social.GuildSourcesText then win.sources:SetText("|cff808080" .. SFP.Social.GuildSourcesText() .. "|r") end
        SFP:Safe("guild directory", refresh)
    end)
end

function SFP:ShowGuildDirectory()
    if SFP.Social and SFP.Social.BackfillGuilds then pcall(SFP.Social.BackfillGuilds) end
    build()
    win:Show()
    win:Raise()
    refresh()
end
