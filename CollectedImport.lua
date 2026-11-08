-- The data collected in the game and shipped with the addon (collected/*.lua, made by tools/bake_collected.py).
--
-- WoW saves a player's data as one big chunk that can hold only ~262,000 different names and numbers, so shipped data is NEVER copied
-- into the saved data. Two ways are used instead:
--   * BIG tables (quests, loot, materials, the item list, decor): the shipped table is the fallback of the saved one (a metatable), so
--     reading an entry finds the shipped one when the player has none, and SeviathsAllPairs(t) walks both. Entries the player has
--     that the shipped table also has are removed from his saved data (it frees room); only what is new for him is saved.
--   * SMALL tables (nameplates, inspects, Raider.IO answers, guilds, spots ...): put into the saved data once per new shipped version:
--     what is missing is added, the newer record (field "t") wins, world data is overwritten by the shipped values.
local C = _G.SeviathsUsefulToolsCollected
local unpack = unpack or table.unpack

-- a packed record is the text of a Lua table constructor, turned into a table when it is read (a table per record would use 5-10 times more memory)
local loadfn = loadstring or load
local function decode(s)
    if type(s) ~= "string" then return s end
    local fn = loadfn("return " .. s)
    if not fn then return nil end
    local ok, v = pcall(fn)
    return ok and v or nil
end
SeviathsDecode = decode

-- the keys of a saved table and the shipped table behind it, WITHOUT reading (decoding) any record
function SeviathsKeys(t)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    local mt = type(t) == "table" and getmetatable(t)
    local shipped = mt and mt.shipped
    if shipped then
        for k in pairs(shipped) do if rawget(t, k) == nil then keys[#keys + 1] = k end end
    end
    return keys
end

-- walks a saved table and the shipped table behind it (a table without a shipped one is walked as pairs does)
function SeviathsAllPairs(t)
    local mt = type(t) == "table" and getmetatable(t)
    local shipped = mt and mt.shipped
    if not shipped then return pairs(t or {}) end
    local packed = mt.packed
    local k, v
    local phase = 1
    return function()
        if phase == 1 then
            k, v = next(t, k)
            if k ~= nil then return k, v end
            phase, k = 2, nil
        end
        repeat k, v = next(shipped, k) until k == nil or rawget(t, k) == nil
        if k ~= nil and packed then v = decode(v) end
        return k, v
    end
end

if not C then return end

local BIG = {
    SeviathsCodexDB = { quests = true, loot = true, matUses = true, items = true },
    SeviathsUsefulToolsDB = { knownItems = true, learnedDecor = true },
}
local PLAYER_TABLES = {
    seenInfo = true, inspected = true, rioCache = true, nameplateText = true, playerIDs = true, nameRealms = true, nameRealm = true,
    seenPlayers = true, seenBuilds = true, guildNotes = true,
}
local STEP = 1500   -- top-level entries per step

local function isArray(t) return t[1] ~= nil end

local function overwrite(dst, src)
    for k, v in pairs(src) do
        local cur = dst[k]
        if cur == nil then
            dst[k] = v
        elseif type(cur) == "table" and type(v) == "table" then
            if isArray(cur) or isArray(v) then
                if #v >= #cur then dst[k] = v end
            else
                overwrite(cur, v)
            end
        else
            dst[k] = v
        end
    end
end

local function fillMissing(dst, src)
    for k, v in pairs(src) do
        local cur = dst[k]
        if cur == nil then dst[k] = v
        elseif type(cur) == "table" and type(v) == "table" and not isArray(cur) and not isArray(v) then fillMissing(cur, v) end
    end
end

local function mergePlayer(dst, k, v)
    local cur = dst[k]
    if cur == nil then dst[k] = v return end
    if type(cur) == "table" and type(v) == "table" and not isArray(cur) and not isArray(v) then
        if (cur.t or 0) > (v.t or 0) then fillMissing(cur, v) else overwrite(cur, v) end
    elseif type(cur) == "number" and type(v) == "number" then
        dst[k] = math.max(cur, v)
    end
end

-- the guild directory: a player who is in another guild of that realm here is left alone (he moved), the rest is added
local function mergeGuildDir(dst, realm, guilds)
    local byRealm = dst[realm]
    if not byRealm then dst[realm] = guilds return end
    local where = {}
    for gname, g in pairs(byRealm) do
        for name in pairs(g.members or {}) do where[name] = gname end
    end
    for gname, g in pairs(guilds) do
        local cur = byRealm[gname]
        if not cur then
            local members = {}
            for name, m in pairs(g.members or {}) do if not where[name] then members[name] = m end end
            g.members = members
            byRealm[gname] = g
        else
            cur.members = cur.members or {}
            cur.faction = cur.faction or g.faction
            for name, m in pairs(g.members or {}) do
                if not cur.members[name] and not where[name] then cur.members[name] = m end
            end
        end
    end
end

local jobs, ji = {}, 1

local function addJobs(smallAlso)
    -- the big tables ship packed (one string per record): the shipped table is the fallback of the saved one, a record is decoded when read
    for dbName, tables in pairs(C.packed or {}) do
        local db = _G[dbName]
        if type(db) == "table" then
            for key, packed in pairs(tables) do
                if type(db[key]) ~= "table" then db[key] = {} end
                setmetatable(db[key], {
                    __index = function(_, k)
                        local s = packed[k]
                        if s ~= nil then return decode(s) end
                    end,
                    shipped = packed, packed = true,
                })
                local keys = {}
                for k in pairs(db[key]) do keys[#keys + 1] = k end
                jobs[#jobs + 1] = { kind = "prune", dst = db[key], shipped = packed, keys = keys, i = 1 }
            end
        end
    end
    for dbName, tables in pairs(C.data or {}) do
        local db = _G[dbName]
        if type(db) == "table" then
            for key, shipped in pairs(tables) do
                if type(shipped) == "table" then
                    if BIG[dbName] and BIG[dbName][key] then
                        -- big: the shipped table is the fallback; what both have is taken out of the saved one
                        if type(db[key]) ~= "table" then db[key] = {} end
                        setmetatable(db[key], { __index = shipped, shipped = shipped })
                        local keys = {}
                        for k in pairs(db[key]) do keys[#keys + 1] = k end
                        jobs[#jobs + 1] = { kind = "prune", dst = db[key], shipped = shipped, keys = keys, i = 1 }
                    elseif smallAlso then
                        if type(db[key]) ~= "table" then db[key] = {} end
                        local keys = {}
                        for k in pairs(shipped) do keys[#keys + 1] = k end
                        jobs[#jobs + 1] = { kind = "merge", key = key, dst = db[key], shipped = shipped, keys = keys, i = 1 }
                    end
                end
            end
        end
    end
end

local function finish()
    for _, dbName in ipairs({ "SeviathsUsefulToolsDB", "SeviathsCodexDB", "SeviathsDungeonsRaidsDB" }) do
        if type(_G[dbName]) == "table" then _G[dbName].collectedDate = C.date end
    end
    local S = _G.SeviathsUsefulTools and _G.SeviathsUsefulTools.Social
    if S and S.BackfillGuilds then pcall(S.BackfillGuilds) end
end

local function step()
    local job = jobs[ji]
    if not job then finish() return end
    local last = math.min(#job.keys, job.i + STEP - 1)
    for n = job.i, last do
        local k = job.keys[n]
        if job.kind == "prune" then
            if job.shipped[k] ~= nil then job.dst[k] = nil end
        elseif job.key == "guildDir" then
            mergeGuildDir(job.dst, k, job.shipped[k])
        elseif PLAYER_TABLES[job.key] then
            mergePlayer(job.dst, k, job.shipped[k])
        else
            local v = job.shipped[k]
            local cur = job.dst[k]
            if cur == nil then job.dst[k] = v
            elseif type(cur) == "table" and type(v) == "table" then
                if isArray(cur) or isArray(v) then if #v >= #cur then job.dst[k] = v end else overwrite(cur, v) end
            else job.dst[k] = v end
        end
    end
    job.i = last + 1
    if job.i > #job.keys then ji = ji + 1 end
    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    -- the big tables get their fallback at once (every login: a metatable is not saved), the small ones are merged once per new file
    local db = _G.SeviathsUsefulToolsDB
    local first = type(db) == "table" and (db.collectedDate or 0) < (C.date or 0)
    -- all of it at once, right here at the end of the loading screen (a few tenths of a second), not as small steps while playing
    if pcall(addJobs, first) then
        local guard = 0
        while guard < 2000 and jobs[ji] do
            guard = guard + 1
            if not pcall(step) then break end
        end
        if not jobs[ji] then pcall(step) end   -- the last call finishes (dates, guild numbers)
    end
    -- the price list of this realm is made now too, so the first tooltip does not have to
    local S = _G.SeviathsUsefulTools
    if S and S.ShippedPrice then pcall(S.ShippedPrice, S, 0) end
end)

-- the price histories of earlier versions (a table per sample) are turned into flat lists a little after login
local histFrame = CreateFrame("Frame")
histFrame:RegisterEvent("PLAYER_LOGIN")
histFrame:SetScript("OnEvent", function()
    C_Timer.After(5, function()
        local S = _G.SeviathsUsefulTools
        if S and S.CompactPriceHist then pcall(S.CompactPriceHist, S) end
    end)
end)
