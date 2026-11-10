-- SeviathsUsefulTools - Talent Advisor
-- On the talents page: three sections, Raid, Mythic+ and Delves. For the one you pick, it compares what you have chosen with the
-- recommended builds of your specialization (Data/TalentBuilds.lua) and suggests
--   * the hero talents in the middle (the tree most of the builds of that content use),
--   * the next talents to take, best first, and a glow on them in the tree,
--   * talents you took that almost no build of that content uses.
-- It follows you: change a talent and the suggestions change. The "worth" of a talent is how many of the recommended builds of
-- that content take it. The builds are refreshed outside the game (tools/bake_talent_builds.py), so the suggestions follow
-- every patch and expansion as soon as the data is refreshed. The addon cannot read what a talent does or simulate damage.

local _, SFP = ...

local A = {}
SFP.TalentAdvisor = A

local function secret(v) return issecretvalue and issecretvalue(v) end

---------------------------------------------------------------------------
-- reading a talent import string (Blizzard's loadout format, version 2)
---------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64IDX = {}
for i = 1, #B64 do B64IDX[B64:sub(i, i)] = i - 1 end

-- the bits of the string, six per character, lowest bit first
local function toBits(str)
    local bits, n = {}, 0
    for i = 1, #str do
        local v = B64IDX[str:sub(i, i)]
        if not v then return nil end
        for k = 0, 5 do
            n = n + 1
            bits[n] = math.floor(v / 2 ^ k) % 2
        end
    end
    return bits
end

local function take(bits, pos, count)
    local v = 0
    for k = 0, count - 1 do
        local b = bits[pos + k]
        if b == nil then return nil, pos end
        v = v + b * 2 ^ k
    end
    return v, pos + count
end

-- returns { version, specID, picks = { [nodeID] = { rank (nil = all ranks), choice (entry index) } } } or nil
-- nodeIDs: the node IDs of the class's whole talent tree, sorted from low to high (how the game writes them)
function A.Decode(str, nodeIDs, maxRankOf)
    local bits = toBits(str)
    if not bits then return nil end
    local version, pos = take(bits, 1, 8)
    local specID
    specID, pos = take(bits, pos, 16)
    if not (version and specID) then return nil end
    pos = pos + 128   -- the tree hash
    local out = { version = version, specID = specID, picks = {} }
    if not nodeIDs then return out end
    for _, nodeID in ipairs(nodeIDs) do
        local selected
        selected, pos = take(bits, pos, 1)
        if selected == nil then return nil end
        if selected == 1 then
            local purchased
            purchased, pos = take(bits, pos, 1)
            if purchased == 1 then
                local partial, rank, choice = nil, nil, nil
                partial, pos = take(bits, pos, 1)
                if partial == 1 then rank, pos = take(bits, pos, 6) end
                local isChoice
                isChoice, pos = take(bits, pos, 1)
                if isChoice == 1 then choice, pos = take(bits, pos, 2); choice = choice and (choice + 1) end
                if partial == nil or isChoice == nil then return nil end
                out.picks[nodeID] = { rank = rank or (maxRankOf and maxRankOf(nodeID)) or 1, choice = choice }
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- the data of the player's specialization and tree
---------------------------------------------------------------------------
local cache   -- { key, configID, treeID, nodeIDs, builds = { {name, kinds, picks, hero} }, shares = { raid = {}, ... }, ... }

local function playerSpec()
    local _, token = UnitClass("player")
    local idx = GetSpecialization and GetSpecialization()
    if not idx then return nil end
    local specID, name = GetSpecializationInfo(idx)
    if type(name) ~= "string" or secret(name) then return nil end
    return token, name, specID
end

local function configID()
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
        if ok and type(id) == "number" then return id end
    end
end

local function nodeInfo(cfg, nodeID)
    local ok, info = pcall(C_Traits.GetNodeInfo, cfg, nodeID)
    if ok and type(info) == "table" then return info end
end

local function talentName(cfg, entryID)
    local okE, entry = pcall(C_Traits.GetEntryInfo, cfg, entryID)
    if not okE or type(entry) ~= "table" or not entry.definitionID then return nil end
    local okD, def = pcall(C_Traits.GetDefinitionInfo, entry.definitionID)
    if not okD or type(def) ~= "table" then return nil end
    if def.overrideName and def.overrideName ~= "" then return def.overrideName end
    if def.spellID and C_Spell and C_Spell.GetSpellName then
        local ok, nm = pcall(C_Spell.GetSpellName, def.spellID)
        if ok and nm then return nm end
    end
    return nil
end

local function heroNameOf(cfg, nodeIDs, picks)
    -- the hero tree a build (or your own loadout) uses: the choice made on the node that selects the hero tree
    for _, nodeID in ipairs(nodeIDs) do
        local info = nodeInfo(cfg, nodeID)
        if info and info.type == (Enum.TraitNodeType and Enum.TraitNodeType.SubTreeSelection) and info.entryIDs then
            local p = picks[nodeID]
            local entryID = p and p.choice and info.entryIDs[p.choice]
            if entryID then
                local okE, entry = pcall(C_Traits.GetEntryInfo, cfg, entryID)
                if okE and type(entry) == "table" and entry.subTreeID then
                    local okS, sub = pcall(C_Traits.GetSubTreeInfo, cfg, entry.subTreeID)
                    if okS and type(sub) == "table" then return sub.name, entry.subTreeID end
                end
            end
        end
    end
end

-- WoW Forever has no Mythic+ and no delves: the advisor offers Raid and Dungeon, and lists the builds of every specialization (talent tree) of your class
local FOREVER = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
local CONTENTS = FOREVER and { raid = "Raid", dungeon = "Dungeon" } or { raid = "Raid", mythic = "Mythic+", delves = "Delves" }
A.CONTENTS = CONTENTS

-- builds that count for a content, with a weight (the first build listed for a content is the guide's recommended one)
local function affixName(id)
    local okI, nm = pcall(C_ChallengeMode.GetAffixInfo, id)
    if okI and type(nm) == "string" and nm ~= "" then return nm end
    local row = SFP.Affixes and SFP.Affixes[id]
    return row and row[1] or ("affix " .. id)
end

-- this week's Mythic+ affixes, read from the game (so they follow every weekly reset): { ids = {}, names = {} }
local function weekAffixes()
    local out = { ids = {}, names = {} }
    local list
    if C_MythicPlus and C_MythicPlus.GetCurrentAffixes then
        local ok, l = pcall(C_MythicPlus.GetCurrentAffixes)
        if ok and type(l) == "table" then list = l end
    end
    if list and #list > 0 then
        for _, a in ipairs(list) do
            if type(a.id) == "number" then out.ids[a.id] = true; out.names[#out.names + 1] = affixName(a.id) end
        end
    elseif SFP.db and SFP.db.lastKeyAffixes then
        -- the game gave none yet: the ones learned from your last key
        for _, id in ipairs(SFP.db.lastKeyAffixes) do out.ids[id] = true; out.names[#out.names + 1] = affixName(id) end
    end
    return out
end

-- learned from play: the affixes of a key you enter are saved (and counted as seen)
local function learnKeyAffixes()
    if not (SFP.db and C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo) then return end
    local ok, level, ids = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
    if not ok or type(ids) ~= "table" or #ids == 0 then return end
    SFP.db.lastKeyAffixes = {}
    SFP.db.seenAffixes = SFP.db.seenAffixes or {}
    for _, id in ipairs(ids) do
        SFP.db.lastKeyAffixes[#SFP.db.lastKeyAffixes + 1] = id
        SFP.db.seenAffixes[id] = (SFP.db.seenAffixes[id] or 0) + 1
    end
    SFP.db.lastKeyAffixesAt = time()
end

-- Tyrannical (9) makes the bosses hard: a build for one target counts more. Fortified (10) makes the trash hard: a build for
-- many targets counts more. The guides give no build per other affix, so those change no weight (they are only shown).
local function weightOf(build, content, aff)
    local w
    if build.kinds[content] then
        -- the guide's own pick counts double: it says "recommended" in its name, or it is the first build listed for the content
        w = (build.recommended or build.first[content]) and 2 or 1
    elseif build.kinds.other then
        w = 0.5   -- a build without a content named (a boss build, a variant) counts a little everywhere
    end
    -- a build of an older season (no longer on the guide pages) counts less the older it is: 0.6, 0.4, then 0.25
    if w and build.oldAt then
        local days = (time() - build.oldAt) / 86400
        w = w * (days < 60 and 0.6 or days < 180 and 0.4 or 0.25)
    end
    -- a build seen on other players (learned) is only an example: it counts half
    -- (older ones count less: a build from an old season still teaches, but this season's counts more)
    if w and build.seen then
        local days = (time() - (build.seenAt or time())) / 86400
        w = w * 0.5 * (days < 30 and 1 or days < 120 and 0.7 or 0.4)
    end
    if w and content == "mythic" and aff then
        local n = (build.name or ""):lower()
        local single = build.kinds.raid or n:find("single") or n:find("boss")
        local many = n:find("aoe") or n:find("cleave") or n:find("dungeon") or n:find("mythic")
        -- a build seen in a key with the same affixes as this week: counts more for every affix they share (up to +1)
        if build.affixes then
            local shared = 0
            for _, id in ipairs(build.affixes) do if aff.ids[id] then shared = shared + 1 end end
            w = w + math.min(1, shared * 0.5)
        end
        if aff.ids[9] and single then w = w + 1 end
        if aff.ids[10] and many then w = w + 1 end
    end
    return w
end

-- learning talents from what it sees: the loadout of a player you inspect, and your own when you enter a raid, a key or a delve.
-- Saved per specialization (newest 40, no doubles) and counted as examples next to the guide's builds.
local function contentNow()
    local _, kind = IsInInstance()
    if kind == "raid" then return "raid" end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then return "mythic" end
    if kind == "scenario" then return "delves" end
    return "other"
end

local function saveSeen(str, who)
    if type(str) ~= "string" or secret(str) or #str < 40 or not SFP.db then return end
    local dec = A.Decode(str)
    if not dec or dec.version ~= 2 then return end
    local okS, _, _, _, _, _, classFile = pcall(GetSpecializationInfoByID, dec.specID)
    local _, specName, _, _, _, class = GetSpecializationInfoByID(dec.specID)
    class = class or classFile
    if type(specName) ~= "string" or type(class) ~= "string" then return end
    local key = class .. ":" .. specName
    if not (SFP.TalentBuilds and SFP.TalentBuilds[key]) then return end
    SFP.db.seenBuilds = SFP.db.seenBuilds or {}
    local list = SFP.db.seenBuilds[key] or {}
    SFP.db.seenBuilds[key] = list
    for _, r in ipairs(list) do if r.s == str then r.t = time() return end end
    -- in a key: remember this week's affixes with the build, so builds seen under the same affixes count more later
    local aff
    if contentNow() == "mythic" then
        local okK, _, ids = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
        if okK and type(ids) == "table" and #ids > 0 then aff = {}; for i, id in ipairs(ids) do aff[i] = id end end
    end
    table.insert(list, 1, { s = str, c = contentNow(), n = who, t = time(), a = aff })
    while #list > 120 do table.remove(list) end   -- old seasons stay (they count less), the oldest go first
    cache = nil
end

local function learnInspected()
    if not (C_Traits and C_Traits.GenerateInspectImportString) then return end
    local ok, str = pcall(C_Traits.GenerateInspectImportString, "target")
    if ok then
        local name = UnitName and UnitName("target")
        saveSeen(str, (type(name) == "string" and not secret(name)) and name or "player")
    end
end

local function learnOwn()
    local cfg = configID()
    if not (cfg and C_Traits and C_Traits.GenerateImportString) then return end
    local ok, str = pcall(C_Traits.GenerateImportString, cfg)
    if ok then saveSeen(str, "you") end
end
A.LearnOwn = learnOwn
A.SaveSeen = saveSeen

-- your own loadout as an import string (shared with other players who have the addon)
function A.MyLoadout()
    local cfg = configID()
    if not (cfg and C_Traits and C_Traits.GenerateImportString) then return nil end
    local ok, str = pcall(C_Traits.GenerateImportString, cfg)
    if ok and type(str) == "string" and not secret(str) then return str end
    return nil
end

local function load()
    local token, spec, specID = playerSpec()
    if not (token and C_Traits and C_ClassTalents) then return nil end
    local cfg = configID()
    if not cfg then return nil end
    local key = token .. ":" .. spec
    if cache and cache.key == key and cache.cfg == cfg then return cache end
    local list = SFP.TalentBuilds and SFP.TalentBuilds[key]
    if not list then return nil end
    local okT, treeID = pcall(C_ClassTalents.GetTraitTreeForSpec, specID)
    if not okT or not treeID then return nil end
    local okN, nodes = pcall(C_Traits.GetTreeNodes, treeID)
    if not okN or type(nodes) ~= "table" then return nil end
    local nodeIDs = {}
    for i, id in ipairs(nodes) do nodeIDs[i] = id end
    table.sort(nodeIDs)
    local function maxRankOf(nodeID)
        local info = nodeInfo(cfg, nodeID)
        return info and info.maxRanks or 1
    end
    local data = { key = key, cfg = cfg, treeID = treeID, nodeIDs = nodeIDs, builds = {}, list = list }
    local firstOf = {}
    for _, row in ipairs(list) do
        local name, kindText, str = row[1], row[2], row[3]
        local kinds = {}
        for k in tostring(kindText):gmatch("[^,]+") do kinds[k] = true end
        local dec = A.Decode(str, nodeIDs, maxRankOf)
        -- a string that does not fit this tree (another spec, a damaged string) is left out
        if dec and dec.specID == specID then
            local build = { name = name, kinds = kinds, picks = dec.picks, first = {}, recommended = tostring(name):lower():find("recommended", 1, true) ~= nil }
            -- row[5]: the day an older season's build was last on a guide page (empty = on a page now)
            local y, mo, d = tostring(row[5] or ""):match("^(%d+)-(%d+)-(%d+)$")
            if y then build.oldAt = time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = 12 }) end
            for k in pairs(kinds) do
                if not firstOf[k] then firstOf[k] = true; build.first[k] = true end
            end
            build.hero = heroNameOf(cfg, nodeIDs, dec.picks)
            data.builds[#data.builds + 1] = build
        end
    end
    -- a build whose hero tree could not be read from its talents: the guide names it in the build name ("Archon Raid")
    local heroSet = {}
    for _, b in ipairs(data.builds) do if b.hero then heroSet[b.hero] = true end end
    for _, b in ipairs(data.builds) do
        if not b.hero then
            for hname in pairs(heroSet) do
                if tostring(b.name):lower():find(hname:lower(), 1, true) then b.hero = hname break end
            end
        end
    end
    -- builds seen on other players and on you (learned in play): examples next to the guide's builds
    for _, row in ipairs((SFP.db and SFP.db.seenBuilds and SFP.db.seenBuilds[key]) or {}) do
        local dec = A.Decode(row.s, nodeIDs, maxRankOf)
        if dec and dec.specID == specID then
            local kinds = { [row.c or "other"] = true }
            data.builds[#data.builds + 1] = { name = "seen: " .. (row.n or "?"), kinds = kinds, picks = dec.picks, first = {}, seen = true, seenAt = row.t, affixes = row.a,
                hero = heroNameOf(cfg, nodeIDs, dec.picks) }
        end
    end
    cache = data
    return data
end

function A.ResetCache() cache = nil end

---------------------------------------------------------------------------
-- the suggestions
---------------------------------------------------------------------------
-- what the player has chosen now: { [nodeID] = { rank, choice } }
local function mine(data)
    local out = {}
    for _, nodeID in ipairs(data.nodeIDs) do
        local info = nodeInfo(data.cfg, nodeID)
        if info and (info.currentRank or 0) > 0 then
            local choice
            if info.activeEntry and info.entryIDs and (info.type == (Enum.TraitNodeType and Enum.TraitNodeType.Selection)
                or info.type == (Enum.TraitNodeType and Enum.TraitNodeType.SubTreeSelection)) then
                for i, id in ipairs(info.entryIDs) do if id == info.activeEntry.entryID then choice = i end end
            end
            out[nodeID] = { rank = info.currentRank, choice = choice }
        end
    end
    return out
end

function A.Suggest(content)
    local data = load()
    if not data or #data.builds == 0 then return nil end
    local cfg = data.cfg
    local my = mine(data)
    local myHero = heroNameOf(cfg, data.nodeIDs, my)
    -- which guide build your talents are closest to (the share of talents the two have in common)
    local mineKeys, nMine = {}, 0
    for id, p in pairs(my) do mineKeys[id .. ":" .. tostring(p.choice or 0)] = true; nMine = nMine + 1 end
    local matchName, matchPct
    for _, b in ipairs(data.builds) do
        if not b.seen then
            local inter, nB = 0, 0
            for id, p in pairs(b.picks) do
                nB = nB + 1
                if mineKeys[id .. ":" .. tostring(p.choice or 0)] then inter = inter + 1 end
            end
            local union = nB + nMine - inter
            local pct = union > 0 and inter / union or 0
            if not matchPct or pct > matchPct then matchName, matchPct = b.name, pct end
        end
    end
    local aff = (content == "mythic") and weekAffixes() or nil
    local weightOf = function(b, c) return weightOf(b, c, aff) end

    -- the hero tree: yours when you chose one, else the one most builds of this content use
    local heroScore, total = {}, 0
    for _, b in ipairs(data.builds) do
        local w = weightOf(b, content)
        if w and b.hero then heroScore[b.hero] = (heroScore[b.hero] or 0) + w; total = total + w end
    end
    local bestHero, bestScore
    for name, s in pairs(heroScore) do if not bestScore or s > bestScore then bestHero, bestScore = name, s end end
    local useHero = myHero or bestHero

    -- the builds that count: this content, and the hero tree in use
    local used, wsum = {}, 0
    for _, b in ipairs(data.builds) do
        local w = weightOf(b, content)
        if w and (not useHero or not b.hero or b.hero == useHero) then used[#used + 1] = { b = b, w = w }; wsum = wsum + w end
    end
    if wsum == 0 then
        for _, b in ipairs(data.builds) do used[#used + 1] = { b = b, w = 1 }; wsum = wsum + 1 end
    end
    -- the best standard build (highest weight, first one listed)
    local best
    for _, u in ipairs(used) do if not best or u.w > best.w then best = u end end

    -- the worth of a talent: the share of the counted builds that take it (a choice: the same choice)
    local share = {}
    for _, u in ipairs(used) do
        for nodeID, p in pairs(u.b.picks) do
            local key = nodeID .. ":" .. tostring(p.choice or 0)
            share[key] = (share[key] or 0) + u.w / wsum
        end
    end

    local nextPicks, drop, wanted, swaps = {}, {}, {}, {}
    -- which tree a node is in: the hero tree (middle), or the class tree (left) or the spec tree (right)
    local lo, hi
    for _, nodeID in ipairs(data.nodeIDs) do
        local info = nodeInfo(cfg, nodeID)
        if info and not info.subTreeID and info.posX then
            lo = (not lo or info.posX < lo) and info.posX or lo
            hi = (not hi or info.posX > hi) and info.posX or hi
        end
    end
    local mid = (lo and hi) and (lo + hi) / 2 or 0
    local function sideOf(info)
        if info.subTreeID then return "hero" end
        return (info.posX or 0) < mid and "class" or "spec"
    end
    for _, nodeID in ipairs(data.nodeIDs) do
        local info = nodeInfo(cfg, nodeID)
        if info then
            local mineP = my[nodeID]
            -- every choice the builds make on this node, best first
            local bestChoice, bestShare
            for key, s in pairs(share) do
                local id, ch = key:match("^(%d+):(%d+)$")
                if tonumber(id) == nodeID and (not bestShare or s > bestShare) then bestChoice, bestShare = tonumber(ch), s end
            end
            local maxRanks = info.maxRanks or 1
            if bestShare and bestShare >= 0.5 and (info.currentRank or 0) < maxRanks
                and (not mineP or bestChoice == 0 or mineP.choice == bestChoice) then
                local entryID = info.entryIDs and info.entryIDs[(bestChoice and bestChoice > 0) and bestChoice or 1]
                local row = { nodeID = nodeID, share = bestShare, name = entryID and talentName(cfg, entryID) or ("talent " .. nodeID), y = info.posY or 0, side = sideOf(info) }
                -- one you can take now, or one the builds take that you cannot reach yet (no points / path not open)
                if info.canPurchaseRank then nextPicks[#nextPicks + 1] = row else wanted[#wanted + 1] = row end
            elseif mineP and mineP.choice and bestChoice and bestChoice > 0 and mineP.choice ~= bestChoice and bestShare and bestShare >= 0.5 then
                -- a choice node where you took the option fewer builds take: say which one is better
                local mineID = info.entryIDs and info.entryIDs[mineP.choice]
                local betterID = info.entryIDs and info.entryIDs[bestChoice]
                swaps[#swaps + 1] = {
                    nodeID = nodeID, side = sideOf(info),
                    mine = mineID and talentName(cfg, mineID) or "yours", mineShare = share[nodeID .. ":" .. mineP.choice] or 0,
                    better = betterID and talentName(cfg, betterID) or "the other", betterShare = bestShare,
                }
            elseif mineP and (share[nodeID .. ":" .. tostring(mineP.choice or 0)] or 0) < 0.2 then
                -- taken, but almost none of the counted builds takes it
                local entryID = info.activeEntry and info.activeEntry.entryID
                local isHeroOrClassFree = info.isGranted or (info.currentRank and info.currentRank == 0)
                if entryID and not isHeroOrClassFree and info.ranksPurchased and info.ranksPurchased > 0 then
                    drop[#drop + 1] = { nodeID = nodeID, side = sideOf(info), name = talentName(cfg, entryID) or ("talent " .. nodeID),
                        share = share[nodeID .. ":" .. tostring(mineP.choice or 0)] or 0 }
                end
            end
        end
    end
    local function bySharePos(a, b)
        if a.share ~= b.share then return a.share > b.share end
        return a.y < b.y
    end
    table.sort(nextPicks, bySharePos)
    table.sort(wanted, bySharePos)
    table.sort(drop, function(a, b) return a.share < b.share end)
    return {
        spec = data.key, content = content, hero = useHero, heroChosen = myHero ~= nil,
        heroShare = (bestHero and total > 0) and (heroScore[bestHero] / total) or nil, bestHero = bestHero,
        matchName = matchName, matchPct = matchPct,
        best = best and best.b.name, builds = #used, affixes = aff and aff.names or nil,
        nextPicks = nextPicks, drop = drop, wanted = wanted, swaps = swaps,
        heroShares = (function()
            local l = {}
            for name, sc in pairs(heroScore) do l[#l + 1] = { name = name, share = total > 0 and sc / total or 0 } end
            table.sort(l, function(a, b) return a.share > b.share end)
            return l
        end)(),
    }
end

-- the talents of a player as a short summary: the hero tree and the guide build they are closest to.
-- cfg is the active config (yourself) or the inspect config (a player you inspected).
function A.Summarize(cfg, specID, token, specName)
    if not (cfg and specID and token and type(specName) == "string") then return nil end
    local okT, treeID = pcall(C_ClassTalents.GetTraitTreeForSpec, specID)
    if not okT or not treeID then return nil end
    local okN, nodes = pcall(C_Traits.GetTreeNodes, treeID)
    if not okN or type(nodes) ~= "table" then return nil end
    local nodeIDs = {}
    for i, id in ipairs(nodes) do nodeIDs[i] = id end
    table.sort(nodeIDs)
    local my = mine({ cfg = cfg, nodeIDs = nodeIDs })
    local nMine, mineKeys = 0, {}
    for id, p in pairs(my) do mineKeys[id .. ":" .. tostring(p.choice or 0)] = true; nMine = nMine + 1 end
    if nMine == 0 then return nil end
    local out = { hero = heroNameOf(cfg, nodeIDs, my) }
    local list = SFP.TalentBuilds and SFP.TalentBuilds[token .. ":" .. specName]
    local function maxRankOf(nodeID)
        local info = nodeInfo(cfg, nodeID)
        return info and info.maxRanks or 1
    end
    for _, row in ipairs(list or {}) do
        local dec = A.Decode(row[3], nodeIDs, maxRankOf)
        if dec and dec.specID == specID then
            local inter, nB = 0, 0
            for id, p in pairs(dec.picks) do
                nB = nB + 1
                if mineKeys[id .. ":" .. tostring(p.choice or 0)] then inter = inter + 1 end
            end
            local pct = (nB + nMine - inter) > 0 and inter / (nB + nMine - inter) or 0
            if not out.matchPct or pct > out.matchPct then out.matchName, out.matchPct = row[1], pct end
            -- the closest build of each content (Raid, Mythic+, Delves)
            out.per = out.per or {}
            for k in tostring(row[2]):gmatch("[^,]+") do
                local cur = out.per[k]
                if CONTENTS[k] and (not cur or pct > cur.pct) then out.per[k] = { name = row[1], pct = pct } end
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- the panel and the glow
---------------------------------------------------------------------------
-- WoW Forever: the game's Talents window has no known name: it is found by its title ("Talents") among the frames of the screen
local function hasTitle(frame, depth)
    if depth > 3 then return false end
    local okR, regions = pcall(function() return { frame:GetRegions() } end)
    for _, r in ipairs(okR and regions or {}) do
        local okT, txt = pcall(function() return r.GetText and r:GetText() end)
        if okT and type(txt) == "string" and not secret(txt) and txt == (TALENTS or "Talents") then return true end
    end
    local okC, kids = pcall(function() return { frame:GetChildren() } end)
    for _, k in ipairs(okC and kids or {}) do
        if depth < 3 and hasTitle(k, depth + 1) then return true end
    end
    return false
end

local talentWindow
function A.FindTalentWindow()
    if talentWindow and talentWindow.IsShown and select(2, pcall(talentWindow.IsShown, talentWindow)) == true then return talentWindow end
    talentWindow = nil
    local okK, kids = pcall(function() return { UIParent:GetChildren() } end)
    for _, k in ipairs(okK and kids or {}) do
        local okS, sh = pcall(function() return k:IsShown() end)
        local okW, w = pcall(function() return k:GetWidth() end)
        if okS and sh == true and okW and type(w) == "number" and not secret(w) and w > 500 and hasTitle(k, 0) then
            talentWindow = k
            break
        end
    end
    return talentWindow
end

local win, text, glows = nil, nil, {}
local sections = {}
local specBtns = {}   -- Forever: one button per specialization (talent tree) of your class

-- the section you picked (Raid / Mythic+ / Delves) is saved for each specialization, and as the default for the others
local function specKey()
    local token, spec = playerSpec()
    return token and spec and (token .. ":" .. spec) or nil
end

local function content()
    local k = specKey()
    local per = k and SFP.db.talentContentBySpec and SFP.db.talentContentBySpec[k]
    local c = (per and CONTENTS[per] and per) or SFP.db.talentContent
    return (c and CONTENTS[c]) and c or "raid"
end

local function setContent(c)
    SFP.db.talentContent = c
    local k = specKey()
    if k then
        SFP.db.talentContentBySpec = SFP.db.talentContentBySpec or {}
        SFP.db.talentContentBySpec[k] = c
    end
end

local function clearGlows()
    for _, g in ipairs(glows) do g:Hide() end
end

local function glowOn(nodeID, index)
    local frame = _G.PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame or _G.ClassTalentFrame and ClassTalentFrame.TalentsTab
    if not (frame and frame.GetTalentButtonByNodeID) then return end
    local ok, btn = pcall(frame.GetTalentButtonByNodeID, frame, nodeID)
    if not (ok and btn) then return end
    local g = glows[index]
    if not g then
        g = btn:CreateTexture(nil, "OVERLAY")
        g:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        g:SetBlendMode("ADD")
        glows[index] = g
    end
    g:SetParent(btn)
    g:ClearAllPoints()
    g:SetPoint("CENTER", btn, "CENTER", 0, 0)
    local w = (btn:GetWidth() or 40) * 2.7
    g.base = w
    g:SetSize(w, w)
    g:SetVertexColor(0.15, 0.5, 1, 1)
    g:Show()
end

-- the window is as tall as its text and never sits over the bottom action bars
local function fitWindow()
    if not (win and text) then return end
    -- shrunk: only the title and the three buttons stay
    local shrunk = SFP.db and SFP.db.talentShrunk
    text:SetShown(not shrunk)
    if win.shrinkBtn then win.shrinkBtn:SetText(shrunk and "+" or "-") end
    -- shrunk: the Raid / Dungeon buttons stay in the bar, next to the title (a click on one opens the window again)
    for _, btn in pairs(sections) do
        if FOREVER and btn.homeX then
            btn:ClearAllPoints()
            if shrunk then btn:SetPoint("TOPLEFT", btn.homeX + 100, -6) else btn:SetPoint("TOPLEFT", btn.homeX, -32) end
            btn:Show()
        else
            btn:SetShown(not shrunk)
        end
    end
    for _, btn in pairs(specBtns) do btn:SetShown(not shrunk) end
    if win.roleBtns and shrunk then for _, b in ipairs(win.roleBtns) do b:Hide() end end
    -- shrunk: the big metal frame is left out (it is taller than the 34 px bar and showed as lone lines): a plain bar with a gold edge
    if win.NineSlice then win.NineSlice:SetShown(not shrunk) end
    if win.seviathBase then win.seviathBase:SetShown(not shrunk) end
    if shrunk then
        win:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        win:SetBackdropBorderColor(0.8, 0.65, 0.3, 1)
    elseif win.GetBackdrop and win:GetBackdrop() then
        win:SetBackdrop(nil)
    end
    local h = shrunk and 34 or math.max(160, math.min(text:GetStringHeight() + 84 + (FOREVER and (28 + (win.extraH or 0)) or 0), (UIParent:GetHeight() or 800) - 140))
    if FOREVER and win.child then
        win.child:SetHeight(text:GetStringHeight() + 10 + (win.extraH or 0))
        win.scroll:SetShown(not shrunk)
    end
    if math.abs((win:GetHeight() or 0) - h) > 1 then win:SetHeight(h) end
    local b, l, t = win:GetBottom(), win:GetLeft(), win:GetTop()
    if b and l and t and b < 130 then
        win:ClearAllPoints()
        win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t + (130 - b))
    end
end

-- the best build of every content (Raid, Mythic+, Delves) with its hero talents; recomputed every few seconds only
local bestCache, bestAt
local function bestBuilds()
    if bestCache and GetTime() - (bestAt or 0) < 3 then return bestCache end
    local out = {}
    for _, key in ipairs({ "raid", "mythic", "delves" }) do
        local ok, sc = pcall(A.Suggest, key)
        if ok and sc then
            out[#out + 1] = ("|cffffd100%s|r: %s%s"):format(CONTENTS[key], sc.best or "?", sc.hero and (" |cff808080(" .. sc.hero .. ")|r") or "")
        end
    end
    bestCache, bestAt = out, GetTime()
    return out
end

-- the builds of "forever:Tree=Talent:rank,Talent:rank;Tree=..." as { { tree, points, { {name, rank}, ... } }, ... }
local function readForeverBuild(str)
    local out = {}
    for part in tostring(str):gsub("^forever:", ""):gmatch("[^;]+") do
        local tree, list = part:match("^(.-)=(.*)$")
        if tree and list ~= "" then
            local talents, points = {}, 0
            for item in list:gmatch("[^,]+") do
                local name, rank = item:match("^(.-):(%d+)$")
                if name then
                    rank = tonumber(rank)
                    talents[#talents + 1] = { name, rank }
                    points = points + rank
                end
            end
            out[#out + 1] = { tree, points, talents }
        end
    end
    return out
end

-- Forever: every specialization of your class with its recommended builds for the chosen content (a build for raids counts for dungeons too
-- when the specialization has no dungeon build of its own)
local function foreverSpecs()
    local _, token = UnitClass("player")
    local specs = {}
    for key in pairs(SFP.TalentBuilds or {}) do
        local cls, spec = key:match("^(%u+):(.+)$")
        if cls == token then specs[#specs + 1] = spec end
    end
    table.sort(specs)
    return token, specs
end

-- the talents you took, by name: { [talent name] = rank } (nil when the game does not answer); read again at most every 2 seconds
local takenCache, takenAt
local function takenTalents()
    if takenAt and GetTime() - takenAt < 2 then return takenCache end
    takenCache, takenAt = nil, GetTime()
    if not (C_ClassTalents and C_Traits and C_ClassTalents.GetActiveConfigID) then return nil end
    local ok, cfg = pcall(C_ClassTalents.GetActiveConfigID)
    if not ok or type(cfg) ~= "number" then return nil end
    local okC, info = pcall(C_Traits.GetConfigInfo, cfg)
    if not okC or type(info) ~= "table" or type(info.treeIDs) ~= "table" then return nil end
    local taken = {}
    for _, treeID in ipairs(info.treeIDs) do
        local okN, nodes = pcall(C_Traits.GetTreeNodes, treeID)
        for _, nodeID in ipairs(okN and nodes or {}) do
            local okI, ni = pcall(C_Traits.GetNodeInfo, cfg, nodeID)
            local rank = okI and type(ni) == "table" and ni.currentRank
            if type(rank) == "number" and not secret(rank) and rank > 0 then
                local entry = ni.activeEntry and ni.activeEntry.entryID or (ni.entryIDs and ni.entryIDs[1])
                local okE, ei = pcall(C_Traits.GetEntryInfo, cfg, entry or 0)
                local okD, di = pcall(C_Traits.GetDefinitionInfo, okE and type(ei) == "table" and ei.definitionID or 0)
                local name = okD and type(di) == "table" and (di.overrideName or (di.spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(di.spellID)))
                if type(name) == "string" and not secret(name) then taken[name] = rank end
            end
        end
    end
    takenCache = taken
    return taken
end

-- every talent of your class from the game: { name, description, rank, max, x, spellID }, grouped into the three trees by where they stand in the window
-- (the trees stand side by side, in the order of their names: Arms, Fury, Protection). Read again at most every 5 seconds.
local treeCache, treeAt
local function readTrees(token, specs)
    if treeAt and GetTime() - treeAt < 5 then return treeCache end
    treeCache, treeAt = nil, GetTime()
    if not (C_ClassTalents and C_Traits and C_ClassTalents.GetActiveConfigID) then return nil end
    local ok, cfg = pcall(C_ClassTalents.GetActiveConfigID)
    if not ok or type(cfg) ~= "number" then return nil end
    local okC, info = pcall(C_Traits.GetConfigInfo, cfg)
    if not okC or type(info) ~= "table" or type(info.treeIDs) ~= "table" then return nil end
    local list, minX, maxX = {}, math.huge, -math.huge
    for _, treeID in ipairs(info.treeIDs) do
        local okN, nodes = pcall(C_Traits.GetTreeNodes, treeID)
        for _, nodeID in ipairs(okN and nodes or {}) do
            local okI, ni = pcall(C_Traits.GetNodeInfo, cfg, nodeID)
            if okI and type(ni) == "table" then
                local entry = ni.entryIDs and ni.entryIDs[1]
                local okE, ei = pcall(C_Traits.GetEntryInfo, cfg, entry or 0)
                local okD, di = pcall(C_Traits.GetDefinitionInfo, okE and type(ei) == "table" and ei.definitionID or 0)
                local spellID = okD and type(di) == "table" and di.spellID
                local name = okD and type(di) == "table" and (di.overrideName or (spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)))
                if type(name) == "string" and not secret(name) then
                    local desc = ""
                    if spellID and C_Spell then
                        if C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, spellID) end
                        local okS, d = pcall(C_Spell.GetSpellDescription, spellID)
                        if okS and type(d) == "string" and not secret(d) then desc = d end
                    end
                    local x = type(ni.posX) == "number" and ni.posX or 0
                    minX, maxX = math.min(minX, x), math.max(maxX, x)
                    local icon
                    if spellID and C_Spell and C_Spell.GetSpellTexture then
                        local okX, tex = pcall(C_Spell.GetSpellTexture, spellID)
                        if okX and not secret(tex) then icon = tex end
                    end
                    list[#list + 1] = { name = name, desc = desc, rank = ni.currentRank or 0, max = ni.maxRanks or 1, x = x, y = type(ni.posY) == "number" and ni.posY or 0, icon = icon, nodeID = nodeID, cfg = cfg, edges = ni.visibleEdges }
                end
            end
        end
    end
    if #list == 0 then return nil end
    -- what can be taken next: a talent with no talent above it in the tree (the first row), or one whose parent talent (the arrow into it) is taken in full;
    -- so the suggestions are the first row and the talents around the ones you picked
    local byNode, parents = {}, {}
    for _, t in ipairs(list) do byNode[t.nodeID] = t end
    for _, t in ipairs(list) do
        for _, e in ipairs(type(t.edges) == "table" and t.edges or {}) do
            local target = type(e) == "table" and e.targetNode
            if target and byNode[target] then
                parents[target] = parents[target] or {}
                parents[target][#parents[target] + 1] = t
            end
        end
    end
    for _, t in ipairs(list) do
        local ps = parents[t.nodeID]
        t.avail = true
        if ps then
            t.avail = false
            for _, p in ipairs(ps) do if p.rank >= p.max then t.avail = true end end
        end
    end
    -- three columns by position; each column is the tree whose talent names (from the builds) it holds the most of
    local span = (maxX - minX) + 1e-6
    local cols = { {}, {}, {} }
    for _, t in ipairs(list) do
        t.col = math.min(3, math.floor((t.x - minX) / span * 3) + 1)
        cols[t.col][#cols[t.col] + 1] = t
    end
    local names = {}
    for _, spec in ipairs(specs) do
        names[spec] = {}
        for _, row in ipairs(SFP.TalentBuilds[token .. ":" .. spec] or {}) do
            for _, tr in ipairs(readForeverBuild(row[3])) do
                if tr[1] == spec then for _, tl in ipairs(tr[3]) do names[spec][tl[1]] = true end end
            end
        end
    end
    -- the rows of each tree (top to bottom): a row opens when the tree holds 5 points for every row above it (the first row is always open)
    for c = 1, 3 do
        local ys, seenY, points = {}, {}, 0
        for _, t in ipairs(cols[c]) do
            points = points + (t.rank or 0)
            if not seenY[t.y] then seenY[t.y] = true; ys[#ys + 1] = t.y end
        end
        table.sort(ys)
        local rowOf = {}
        for i, y in ipairs(ys) do rowOf[y] = i - 1 end
        for _, t in ipairs(cols[c]) do
            if rowOf[t.y] * 5 > points then t.avail = false end
        end
    end
    local out = {}
    for c = 1, 3 do
        local bestSpec, bestN = specs[c], -1
        for _, spec in ipairs(specs) do
            local n = 0
            for _, t in ipairs(cols[c]) do if names[spec][t.name] then n = n + 1 end end
            if n > bestN then bestSpec, bestN = spec, n end
        end
        out[bestSpec] = cols[c]
    end
    treeCache = out
    return out
end

-- what a talent does, read from its description: the more of what the role wants, the higher it scores
local WANT = {
    dps = { { "damage", 2 }, { "critical strike", 2 }, { "haste", 2 }, { "attack speed", 2 }, { "attack power", 1.5 }, { "spell power", 1.5 }, { "hit chance", 1.5 },
        { "armor penetration", 1.5 }, { "extra attack", 1.5 }, { "chance to", 0.5 } },
    tank = { { "armor", 2 }, { "block", 2 }, { "parry", 2 }, { "dodge", 2 }, { "threat", 2 }, { "damage taken", 2 }, { "reduces damage", 2 }, { "stamina", 1.5 }, { "health", 1 } },
    healer = { { "healing", 2 }, { "heal ", 1.5 }, { "mana", 1.5 }, { "regenerat", 1.5 }, { "spirit", 1 }, { "critical", 1 }, { "spell power", 1 } },
}

-- Feral plays as a cat (damage) and as a bear (tank): both lists of words count
WANT.feral = {}
for _, w in ipairs(WANT.dps) do WANT.feral[#WANT.feral + 1] = w end
for _, w in ipairs(WANT.tank) do WANT.feral[#WANT.feral + 1] = w end

local function roleOf(token, spec)
    -- a role picked with the buttons (Feral: Cat dps or Bear tank)
    local pick = SFP.db and SFP.db.talentRole and SFP.db.talentRole[token .. ":" .. tostring(spec)]
    if pick == "tank" or pick == "dps" then return pick end
    if spec == "Feral Combat" then return "feral" end
    if spec == "Protection" then return "tank" end
    if spec == "Holy" or spec == "Discipline" or spec == "Restoration" then return "healer" end
    return "dps"
end

-- the words of a description that say a talent gives a stat (the stat priority of the specialization is made of these stats)
local STAT_WORDS = {
    ["weapon dps"] = { "weapon damage", "weapon speed", "melee damage", "two-hand", "dual wield", "main hand", "off-hand", "damage with" },
    ["weapon damage"] = { "weapon damage", "weapon speed", "melee damage", "two-hand", "dual wield", "ranged damage", "damage with" },
    ["hit chance"] = { "hit chance", "chance to hit", "miss" },
    ["expertise"] = { "expertise", "dodge", "parry" },
    ["critical strike"] = { "critical strike", "critical" },
    ["strength"] = { "strength" }, ["agility"] = { "agility" }, ["intellect"] = { "intellect" }, ["spirit"] = { "spirit" },
    ["stamina"] = { "stamina", "health" }, ["attack power"] = { "attack power" },
    ["spell power"] = { "spell power", "spell damage", "damage dealt by" },
    ["healing power"] = { "healing", "heal " }, ["mp5"] = { "mana", "regenerat" },
    ["haste"] = { "haste", "attack speed", "casting speed", "cast time" },
    ["armor"] = { "armor" }, ["avoidance"] = { "dodge", "parry", "avoid" }, ["defense"] = { "defense", "block" }, ["dodge"] = { "dodge" },
    ["weapon skill"] = { "weapon skill", "expertise" }, ["spell pierce"] = { "penetration", "resistance" },
}

-- the words that count for one specialization, from its own stat priority (the first stat counts most); a specialization without one uses its role's words
local weightCache = {}
local function weightsFor(token, spec, role)
    local key = token .. ":" .. spec
    if weightCache[key] then return weightCache[key] end
    local out = {}
    local lists = SFP.StatPriority and SFP.StatPriority[key]
    if lists then
        for _, list in ipairs(lists) do
            local n = #list
            for i, stat in ipairs(list) do
                local words = STAT_WORDS[stat:lower()]
                if words then
                    for _, w in ipairs(words) do out[#out + 1] = { w, (n - i + 1) * 0.8, stat } end
                end
            end
        end
    end
    -- a little for the role's own words too (damage for a damage spec ...)
    for _, w in ipairs(WANT[role] or {}) do out[#out + 1] = { w[1], w[2] * 0.25, w[1] } end
    weightCache[key] = out
    return out
end

local function benefitScore(desc, weights)
    local d = tostring(desc):lower()
    local score, tags, seenTag = 0, {}, {}
    for _, w in ipairs(weights) do
        if d:find(w[1], 1, true) then
            score = score + w[2]
            if not seenTag[w[3]] then seenTag[w[3]] = true; tags[#tags + 1] = (w[3]:gsub("%s+$", "")) end
        end
    end
    local top = 0
    for n in d:gmatch("(%d+%.?%d*)%%") do top = math.max(top, tonumber(n) or 0) end
    score = score + math.min(top, 30) / 10
    return score, tags
end

-- the specialization you play, found from the talents you took: the tree (of the builds' talents) most of your points are in; nil before you
-- have points or when the game does not answer
local function detectForeverSpec(token, specs)
    local taken = takenTalents()
    if not taken then return nil end
    local points = {}
    -- the points of each tree: every talent name of the tree (from all its builds) you took, counted once
    local seen = {}
    for _, spec in ipairs(specs) do
        for _, row in ipairs(SFP.TalentBuilds[token .. ":" .. spec] or {}) do
            for _, t in ipairs(readForeverBuild(row[3])) do
                for _, tl in ipairs(t[3]) do
                    local key = t[1] .. "|" .. tl[1]
                    if taken[tl[1]] and not seen[key] then seen[key] = true; points[t[1]] = (points[t[1]] or 0) + taken[tl[1]] end
                end
            end
        end
    end
    local best, bestN = nil, 0
    for _, spec in ipairs(specs) do
        if (points[spec] or 0) > bestN then best, bestN = spec, points[spec] end
    end
    return best
end
A.DetectedSpec = function() local token, specs = foreverSpecs(); return detectForeverSpec(token, specs) end

local function foreverSpec()
    local token, specs = foreverSpecs()
    SFP.db.talentSpecForever = SFP.db.talentSpecForever or {}
    -- the one you picked with the buttons; else the one found from your talents; else the first
    local want = SFP.db.talentSpecForever[token]
    for _, s in ipairs(specs) do if s == want then return token, s, specs, false end end
    local found = detectForeverSpec(token, specs)
    for _, s in ipairs(specs) do if s == found then return token, s, specs, true end end
    return token, specs[1], specs, false
end

-- the buttons of the specializations, made once for the class
local function makeSpecButtons()
    if #specBtns > 0 or not win then return end
    local token, _, specs = foreverSpec()
    local x = 14
    for _, spec in ipairs(specs) do
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        b:SetSize(math.max(70, 7 * #spec + 14), 22)
        b:SetPoint("TOPLEFT", x, -58)
        b:SetText(spec)
        b.spec = spec
        b:SetScript("OnClick", function()
            SFP.db.talentSpecForever[token] = spec
            local onShow = win and win:GetScript("OnShow")
            if onShow then onShow(win) end   -- draws the window again (refresh is defined further down)
        end)
        specBtns[#specBtns + 1] = b
        x = x + b:GetWidth() + 6
    end
    -- "Auto": the specialization is found from your talents again (you can change it any time with these buttons)
    local auto = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    auto:SetSize(48, 22)
    auto:SetPoint("TOPLEFT", x, -58)
    auto:SetText("Auto")
    auto:SetScript("OnClick", function()
        SFP.db.talentSpecForever[token] = nil
        local onShow = win and win:GetScript("OnShow")
        if onShow then onShow(win) end
    end)
    specBtns[#specBtns + 1] = auto
end

-- the talent buttons of the game's Talents window are found by their icon: the button whose picture is the icon of the talent
local function talentButtons()
    local f = A.FindTalentWindow and A.FindTalentWindow()
    local out = {}
    if not f then return out end
    local seen = 0
    local function walk(fr, depth)
        if depth > 7 or seen > 4000 then return end
        seen = seen + 1
        local okT, ot = pcall(function() return fr:GetObjectType() end)
        local okW, w = pcall(function() return fr:GetWidth() end)
        if okT and (ot == "Button" or ot == "CheckButton") and okW and type(w) == "number" and not secret(w) and w >= 28 and w <= 80 then out[#out + 1] = fr end
        local okC, kids = pcall(function() return { fr:GetChildren() } end)
        for _, k in ipairs(okC and kids or {}) do walk(k, depth + 1) end
    end
    walk(f, 0)
    return out
end

local function buttonWithIcon(buttons, icon)
    if not icon then return nil end
    for _, b in ipairs(buttons) do
        local okR, regions = pcall(function() return { b:GetRegions() } end)
        for _, r in ipairs(okR and regions or {}) do
            local okT, tex = pcall(function() return r.GetTexture and r:GetTexture() end)
            if okT and tex ~= nil and not secret(tex) and tex == icon then return b end
        end
    end
    return nil
end

local function glowButton(btn, index)
    local g = glows[index]
    if not g then
        g = btn:CreateTexture(nil, "OVERLAY")
        g:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        g:SetBlendMode("ADD")
        glows[index] = g
    end
    g:SetParent(btn)
    g:ClearAllPoints()
    g:SetPoint("CENTER", btn, "CENTER", 0, 0)
    local w = (btn:GetWidth() or 40) * 2.7
    g:SetSize(w, w)
    g:SetVertexColor(0.15, 0.5, 1, 1)
    g:Show()
end

-- a click on a talent of the list: one rank of it is put in the Talents window (it is not final until you press Apply Changes there)
local function pickTalent(t)
    if not (C_Traits and C_Traits.PurchaseRank and t.cfg and t.nodeID) then
        SFP:Print("The game gives no way to select talents from here.")
        return
    end
    local ok, res = pcall(C_Traits.PurchaseRank, t.cfg, t.nodeID)
    if ok and res then
        SFP:Print(("Selected %s - press Apply Changes in the Talents window to keep it."):format(t.name))
    else
        SFP:Print(("Cannot select %s now: no unspent talent point, or what it needs is not taken yet."):format(t.name))
    end
    treeAt = nil
end

local ROW_H = 20
local function setRows(items, top)
    win.rows = win.rows or {}
    for i, it in ipairs(items) do
        local b = win.rows[i]
        if not b then
            b = CreateFrame("Button", nil, win.child)
            b:SetHeight(ROW_H - 2)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", 4, 0)
            b.text:SetJustifyH("LEFT")
            b.hl = b:CreateTexture(nil, "HIGHLIGHT")
            b.hl:SetAllPoints()
            b.hl:SetColorTexture(0.9, 0.28, 0.24, 0.18)
            b:SetScript("OnEnter", function(self)
                if not self.tip then return end
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:AddLine(self.tip[1], 0.9, 0.28, 0.24)
                if self.tip[2] and self.tip[2] ~= "" then GameTooltip:AddLine(self.tip[2], 1, 1, 1, true) end
                if self.tip[3] and self.tip[3] ~= "" then GameTooltip:AddLine(self.tip[3], 0.7, 0.7, 0.7, true) end
                if self.click then GameTooltip:AddLine("Click: select this talent", 0.4, 1, 0.5) end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function(self) if self.click then self.click() end end)
            win.rows[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", win.child, "TOPLEFT", 0, -(top + (i - 1) * ROW_H))
        b:SetPoint("RIGHT", win.child, "RIGHT", 0, 0)
        b.text:SetText(it.label)
        b.tip = it.tip
        b.click = it.click
        b:Show()
    end
    for i = #items + 1, #win.rows do win.rows[i]:Hide() end
    win.extraH = #items * ROW_H
end

local function refreshForever()
    local c = content()
    setRows({}, 0)
    for key, btn in pairs(sections) do btn:SetEnabled(key ~= c) end
    clearGlows()
    makeSpecButtons()
    local token, chosen, specs, auto = foreverSpec()
    for _, b in ipairs(specBtns) do if b.spec then b:SetEnabled(b.spec ~= chosen) end end
    -- the role buttons only for a specialization with two roles
    if win and win.roleBtns then
        local pick = SFP.db.talentRole and SFP.db.talentRole[token .. ":" .. tostring(chosen)]
        for _, b in ipairs(win.roleBtns) do
            b:SetShown(chosen == "Feral Combat")
            b:SetEnabled(pick ~= b.role)
        end
    end
    local taken = takenTalents()
    if #specs == 0 then
        text:SetText("|cff808080No talent builds for your class yet.|r")
        fitWindow()
        return
    end
    local lines = { ("|cffffd100%s|r  |cff808080(%s, %s builds%s)|r"):format(chosen, token:sub(1, 1) .. token:sub(2):lower(), CONTENTS[c],
        auto and ", found from your talents" or ""), "" }
    if true then   -- only the benefit system: the talents ranked by what they do (the guide builds only add to the score)
        -- the talents of the chosen tree ranked by their descriptions
        local role = roleOf(token, chosen)
        local trees = readTrees(token, specs)
        local mine = trees and trees[chosen]
        if not mine then
            text:SetText("|cff808080The game gave no talent data yet. Open the Talents window and try again.|r")
            fitWindow()
            return
        end
        -- the guide builds of this specialization are the guidance: a talent they take counts more (the share of the builds that take it)
        local rows, taking = {}, {}
        do
            -- the builds of the content you chose (Raid or Dungeon); when the spec has none of that content, its other raid and dungeon builds
            local all = SFP.TalentBuilds[token .. ":" .. chosen] or {}
            for _, r in ipairs(all) do if r[2] == c then rows[#rows + 1] = r end end
            if #rows == 0 then for _, r in ipairs(all) do if r[2] ~= "other" then rows[#rows + 1] = r end end end
            -- the role picked (tank or dps): only the builds of that role (a build that fits both stays)
            local pick = SFP.db.talentRole and SFP.db.talentRole[token .. ":" .. chosen]
            if pick then
                local kept = {}
                for _, r in ipairs(rows) do
                    local nm = tostring(r[1]):lower()
                    local isTank, isDps = nm:find("tank") or nm:find("bear"), nm:find("dps") or nm:find("cat")
                    if (pick == "tank" and (isTank or not isDps)) or (pick == "dps" and (isDps or not isTank)) then kept[#kept + 1] = r end
                end
                if #kept > 0 then rows = kept end
            end
        end
        for _, row in ipairs(rows) do
            local seen = {}
            for _, tr in ipairs(readForeverBuild(row[3])) do
                for _, tl in ipairs(tr[3]) do
                    if not seen[tl[1]] then seen[tl[1]] = true; taking[tl[1]] = (taking[tl[1]] or 0) + 1 end
                end
            end
        end
        local scored = {}
        for _, t in ipairs(mine) do
            local s, tags = benefitScore(t.desc, weightsFor(token, chosen, role))
            local n = taking[t.name] or 0
            if #rows > 0 and n > 0 then s = s + 4 * n / #rows; tags[#tags + 1] = ("in %d of %d guide builds"):format(n, #rows) end
            scored[#scored + 1] = { t = t, s = s, tags = tags }
        end
        table.sort(scored, function(a, b) if a.s ~= b.s then return a.s > b.s end return a.t.name < b.t.name end)
        lines[1] = ("|cffffd100%s|r  |cff808080(%s, %s)|r"):format(chosen, token:sub(1, 1) .. token:sub(2):lower(), role == "feral" and "cat or bear" or role)
        -- the talents as buttons (hover shows what the talent does); the best ones you do not have yet flash in the Talents window
        local items, flashed, buttons = {}, 0, nil
        for i = 1, #scored do
            local e = scored[i]
            if #items < 8 and e.s > 0 and e.t.rank < e.t.max and e.t.avail then
                local have = e.t.rank >= e.t.max
                local d = e.t.desc:gsub("%s+", " ")
                -- the short reason: the stats of the spec it gives (not the filler words, not the guide count)
                local why = {}
                for _, tg in ipairs(e.tags) do
                    if #why < 2 and not tg:find("chance to", 1, true) and not tg:find("guide builds", 1, true) then why[#why + 1] = tg end
                end
                items[#items + 1] = {
                    label = ("|cffffffff%d. %s|r %d/%d  |cff808080%s|r"):format(#items + 1, e.t.name, e.t.rank, e.t.max, table.concat(why, ", ")),
                    tip = { ("%s  %d/%d"):format(e.t.name, e.t.rank, e.t.max), d, table.concat(e.tags, ", ") },
                    click = (not have) and function() pickTalent(e.t) end or nil,
                }
                if not have and flashed < 5 and e.t.icon then
                    buttons = buttons or talentButtons()
                    local btn = buttonWithIcon(buttons, e.t.icon)
                    if btn then flashed = flashed + 1; glowButton(btn, flashed) end
                end
            end
        end
        lines[#lines + 1] = "|cffffd100Take next, best first.|r Click to select, hover to see what it does."
        if flashed > 0 then lines[#lines + 1] = ("|cffffd100The %d best flash in the Talents window.|r"):format(flashed) end
        if #items == 0 then lines[#lines + 1] = "|cff40ff40Nothing to add: you have the best talents of this tree.|r" end
        text:SetText(table.concat(lines, "\n"))
        setRows(items, text:GetStringHeight() + 8)
        fitWindow()
        return
    end
    for _, spec in ipairs({ chosen }) do
        local rows = SFP.TalentBuilds[token .. ":" .. spec]
        local own, other = {}, {}
        for _, row in ipairs(rows) do
            if row[2] == c then own[#own + 1] = row elseif row[2] == "raid" or row[2] == "dungeon" then other[#other + 1] = row end
        end
        local show = {}
        for _, r in ipairs(#own > 0 and own or other) do show[#show + 1] = r end
        for _, row in ipairs(rows) do if row[2] == "other" then show[#show + 1] = row end end
        for _, row in ipairs(show) do
            local trees = readForeverBuild(row[3])
            local spent = {}
            for _, t in ipairs(trees) do spent[#spent + 1] = t[2] end
            lines[#lines + 1] = ("  |cffffffff%s|r%s  |cff808080(%s)|r"):format(row[1], row[2] == "other" and "  |cff808080PvP / leveling|r" or "", table.concat(spent, " / "))
            -- what is still missing for this build, in the order the guide lists it (a talent with its rank short: "Cruelty 2/5")
            if taken then
                local missing, have, need = {}, 0, 0
                for _, t in ipairs(trees) do
                    for _, tl in ipairs(t[3]) do
                        local got = math.min(taken[tl[1]] or 0, tl[2])
                        have, need = have + got, need + tl[2]
                        if got < tl[2] then missing[#missing + 1] = ("%s %d/%d"):format(tl[1], got, tl[2]) end
                    end
                end
                if #missing == 0 then
                    lines[#lines + 1] = "    |cff40ff40You have this build.|r"
                else
                    local shown = {}
                    for i = 1, math.min(5, #missing) do shown[i] = missing[i] end
                    lines[#lines + 1] = ("    |cffffd100Take next|r |cff808080(%d of %d points)|r: %s%s"):format(have, need, table.concat(shown, ", "), #missing > 5 and (" ... +" .. (#missing - 5)) or "")
                end
            end
            for _, t in ipairs(trees) do
                local names = {}
                for i, tl in ipairs(t[3]) do
                    local got = taken and taken[tl[1]] or 0
                    local text = tl[1] .. (tl[2] > 1 and (" " .. tl[2]) or "")
                    names[i] = (taken and got >= tl[2]) and ("|cff40ff40" .. text .. "|r") or text
                end
                lines[#lines + 1] = ("    |cffffd100%s|r: %s"):format(t[1], table.concat(names, ", "))
            end
        end
        lines[#lines + 1] = ""
    end
    lines[#lines + 1] = ("|cff808080Builds: Icy Veins, WoW Forever, read %s. Take the talents in the order of the list.|r"):format(SFP.TalentBuildsBaked or "?")
    text:SetText(table.concat(lines, "\n"))
    fitWindow()
end

local function refresh()
    if not (win and win:IsShown()) then return end
    if FOREVER then return refreshForever() end
    local c = content()
    for key, btn in pairs(sections) do btn:SetEnabled(key ~= c) end
    local ok, s = pcall(A.Suggest, c)
    clearGlows()
    if not ok or not s then
        local token, spec = playerSpec()
        text:SetText(("|cff808080No talent advice for %s yet.|r\nThe talent builds are loaded when the talent window shows your own specialization, and only for the specializations in the data (patch %s)."):format(
            spec and (token .. " " .. spec) or "this specialization", SFP.TalentBuildsPatch or "?"))
        return
    end
    local lines = {}
    lines[#lines + 1] = ("|cffffd100%s|r  best build: |cffffd100%s|r  (%d build%s counted)"):format(CONTENTS[c], s.best or "?", s.builds, s.builds == 1 and "" or "s")
    -- what you chose (the hero talents in the middle) and the best build of each content, side by side
    lines[#lines + 1] = ("You chose: hero talents |cffffd100%s|r"):format(s.heroChosen and s.hero or "none yet")
    if s.matchName and (s.matchPct or 0) >= 0.4 then
        lines[#lines + 1] = ("Your talents are closest to: |cffffd100%s|r |cff808080(%d%% the same)|r"):format(s.matchName, math.floor(s.matchPct * 100 + 0.5))
    end
    for _, line in ipairs(bestBuilds()) do lines[#lines + 1] = line end
    if s.affixes and #s.affixes > 0 then
        lines[#lines + 1] = "This week's affixes: |cffffd100" .. table.concat(s.affixes, ", ") .. "|r  |cff808080(Tyrannical favours single-target builds, Fortified many-target builds)|r"
    end
    if s.bestHero or s.hero then
        if s.heroChosen then
            lines[#lines + 1] = ("Hero talents (middle): you chose |cffffd100%s|r%s"):format(s.hero,
                (s.bestHero and s.bestHero ~= s.hero) and ("  |cffff9040(the %s builds mostly use %s)|r"):format(CONTENTS[c], s.bestHero) or "  |cff40ff40(the most used)|r")
        else
            lines[#lines + 1] = ("Hero talents (middle): take |cffffd100%s|r  (%d%% of the %s builds)"):format(s.hero, math.floor((s.heroShare or 0) * 100 + 0.5), CONTENTS[c])
        end
    end
    if s.heroShares and #s.heroShares > 1 then
        local parts = {}
        for i, h in ipairs(s.heroShares) do
            parts[i] = ("%s%s|r %d%%"):format(i == 1 and "|cff40ff40" or "|cffc0c0c0", h.name, math.floor(h.share * 100 + 0.5))
        end
        lines[#lines + 1] = "Which hero tree is better for " .. CONTENTS[c] .. ": " .. table.concat(parts, "  vs  ")
    end
    lines[#lines + 1] = ""
    local gi = 0
    -- both sides at the same time: the best few of the class tree (left), the spec tree (right) and the hero tree (middle)
    local SIDE_NAME = { class = "Class tree (left)", spec = "Spec tree (right)", hero = "Hero talents (middle)" }
    -- every suggestion flashes in the tree (class, spec and hero side alike); the menu only counts them
    local function flashAll(list)
        local per = { class = 0, spec = 0, hero = 0 }
        for _, p in ipairs(list) do
            per[p.side or "spec"] = (per[p.side or "spec"] or 0) + 1
            gi = gi + 1; glowOn(p.nodeID, gi)
        end
        return ("%d class (left), %d spec (right), %d hero (middle)"):format(per.class, per.spec, per.hero)
    end
    if #s.nextPicks > 0 then
        lines[#lines + 1] = "|cffffd100Flashing in the tree, take these:|r " .. flashAll(s.nextPicks)
    elseif #s.wanted > 0 then
        lines[#lines + 1] = "|cffffd100No point to spend on these yet, flashing the ones still missing:|r " .. flashAll(s.wanted)
    else
        lines[#lines + 1] = "|cff40ff40Nothing to add: everything the builds take, you have.|r"
    end
    -- the better option of a choice node and the talents you have that the builds hardly take flash too (no list in the menu)
    -- only what to take flashes: talents you already have (rank 1 and so on) do not
    if #s.swaps > 0 then
        lines[#lines + 1] = ("|cffff9040Better choice:|r %d node%s where you took the option fewer builds take"):format(#s.swaps, #s.swaps == 1 and "" or "s")
    end
    if #s.drop > 0 then
        local names = {}
        for i = 1, math.min(4, #s.drop) do names[i] = s.drop[i].name end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cffff9040No build of this content takes:|r " .. table.concat(names, ", ")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("|cff808080Builds: Method.gg, patch %s, read %s. A talent's worth is the share of the builds that take it; the addon cannot simulate damage.|r"):format(
        SFP.TalentBuildsPatch or "?", SFP.TalentBuildsBaked or "?")
    text:SetText(table.concat(lines, "\n"))
    fitWindow()
end

local function build()
    if win then return end
    win = SFP.MakeToolWindow("SeviathsUsefulToolsTalentAdvisor", "Talent advisor", FOREVER and 520 or 360, 330)
    if FOREVER then
        -- the list scrolls when it is longer than the window: the text lives in the window's scroll frame, below the buttons
        win.scroll:ClearAllPoints()
        win.scroll:SetPoint("TOPLEFT", 12, -88)
        win.scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    else
        win.scroll:Hide()
    end
    -- shrink / grow (the close button hides it; the button on the talents window brings it back)
    local sb = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    sb:SetSize(22, 20)
    sb:SetPoint("TOPRIGHT", -8, -6)
    if win.closeBtn then win.closeBtn:Hide() end
    sb:SetText("-")
    sb:SetScript("OnClick", function()
        SFP.db.talentShrunk = not SFP.db.talentShrunk
        fitWindow()
    end)
    win.shrinkBtn = sb
    local order = FOREVER and { { "raid", "Raid" }, { "dungeon", "Dungeon" } } or { { "raid", "Raid" }, { "mythic", "Mythic+" }, { "delves", "Delves" } }
    local x = 14
    for _, o in ipairs(order) do
        local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        b:SetSize(104, 22)
        b:SetPoint("TOPLEFT", x, -32)
        b:SetText(o[2])
        b:SetScript("OnClick", function()
            if FOREVER and SFP.db and SFP.db.talentShrunk then SFP.db.talentShrunk = false end
            setContent(o[1]); refresh()
        end)
        sections[o[1]] = b
        b.homeX = x
        x = x + 110
    end
    -- Feral Combat has two roles: Cat (damage) and Bear (tank): the buttons choose which builds and stats the advice follows
    if FOREVER then
        local function roleBtn(label, role, x2)
            local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
            b:SetSize(104, 22)
            b:SetPoint("TOPLEFT", x2, -32)
            b:SetText(label)
            b:SetScript("OnClick", function()
                local _, tk = UnitClass("player")
                local token2, _, _, _ = foreverSpec()
                local _, chosen = foreverSpec()
                SFP.db.talentRole = SFP.db.talentRole or {}
                SFP.db.talentRole[(token2 or tk) .. ":" .. tostring(chosen)] = role
                refresh()
            end)
            b.role = role
            return b
        end
        win.roleBtns = { roleBtn("Cat (dps)", "dps", x), roleBtn("Bear (tank)", "tank", x + 110) }
    end
    if FOREVER then
        text = win.text
        text:SetWidth(470)
    else
        text = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", 14, -64)
        text:SetWidth(330)
    end
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(3)
    win:SetScript("OnShow", function(self)
        if FOREVER then
            self:SetFrameStrata("FULLSCREEN_DIALOG")   -- in front of the Talents window
            self:Raise()
            -- the Talents window of the game is big: the advisor goes where it does not cover it - right of it, else left, else below, else above
            local f = A.FindTalentWindow()
            if f and not self.dockedTo then
                local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
                local fl, fr, ft, fb = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
                local w, h = self:GetWidth(), self:GetHeight()
                if fl and fr and ft and fb then
                    self:ClearAllPoints()
                    if sw - fr >= w + 4 then self:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, 0)
                    elseif fl >= w + 4 then self:SetPoint("TOPRIGHT", f, "TOPLEFT", -4, 0)
                    elseif fb >= h + 4 then self:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -4)
                    elseif sh - ft >= h + 4 then self:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 4)
                    else self:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -4, -4) end
                    self.dockedTo = f
                end
            end
        elseif not (SFP.db.windowPos and SFP.db.windowPos["SeviathsUsefulToolsTalentAdvisor"]) then
            local f = _G.PlayerSpellsFrame or _G.ClassTalentFrame
            if f then
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, 0)
                -- saved against the screen, not against the talents window (the saved position is read from UIParent)
                local l, t = self:GetLeft(), self:GetTop()
                if l and t then self:ClearAllPoints(); self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t) end
            end
        end
        self:SetClampedToScreen(true)
        refresh()
    end)
    win:SetScript("OnHide", function() clearGlows(); if win then win.dockedTo = nil end end)
    local acc = 0
    win:SetScript("OnUpdate", function(_, dt)
        -- the flashing: every glow pulses
        local a = 0.45 + 0.55 * math.abs(math.sin(GetTime() * 4))
        for _, g in ipairs(glows) do if g:IsShown() then g:SetAlpha(a) end end
        acc = acc + dt
        if acc >= 0.3 then acc = 0; SFP:Safe("talent advisor", refresh) end
    end)
end

function SFP:ShowTalentAdvisor()
    build()
    win:Show()
end

-- opens with the talents page, goes with it
local hooked
local function hookFrame()
    local f = _G.PlayerSpellsFrame
    if hooked or not f then return end
    local tf = f.TalentsFrame
    if not tf then return end
    hooked = true
    tf:HookScript("OnShow", function()
        A.ResetCache()
        if SFP.db.talentAdvisor ~= false and SFP.db.talentAdvisorOpen ~= false then SFP:Safe("talent advisor", SFP.ShowTalentAdvisor, SFP) end
    end)
    tf:HookScript("OnHide", function() if win then win:Hide() end end)
end

---------------------------------------------------------------------------
-- the hero tree choice window (Archon / Voidweaver ...): says which one is better for each content
---------------------------------------------------------------------------
local heroDialog, heroLabel, heroNames, heroAt = nil, nil, nil, 0

-- some frames on the screen are forbidden to addons (touching them is an error): skip those
local function usable(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
end

-- IsShown / GetWidth of some frames give "secret" values to addons: read them safely, a secret counts as hidden / 0
local function shown(f)
    if not usable(f) or not f.IsShown then return false end
    local ok, v = pcall(f.IsShown, f)
    if not ok or secret(v) then return false end
    return v and true or false
end
local function widthOf(f)
    if not usable(f) or not f.GetWidth then return 0 end
    local ok, v = pcall(f.GetWidth, f)
    if not ok or secret(v) or type(v) ~= "number" then return 0 end
    return v
end

local function textHasHero(frame, names)
    if not usable(frame) then return false end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            local t = region:GetText()
            if type(t) == "string" and not secret(t) and names[t:lower()] then return true end
        end
    end
    return false
end

-- a shown frame (any depth) that has a text with a hero tree name: returns that frame
-- the hero tree names (distinct) found in the texts of a frame and everything below it
local function heroNamesIn(frame, names, depth, found)
    found = found or {}
    if not usable(frame) then return found end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" and shown(region) then
            local t = region:GetText()
            if type(t) == "string" and not secret(t) and names[t:lower()] then found[t:lower()] = true end
        end
    end
    if depth > 0 then
        for _, child in ipairs({ frame:GetChildren() }) do
            if shown(child) and child ~= win then heroNamesIn(child, names, depth - 1, found) end
        end
    end
    return found
end

-- a frame with a text that has a hero tree name, whose window (see windowAround) shows two or more of the names:
-- that is the choice window, not the single tree in the middle of the talents page
local windowAround
local function scanFor(frame, names, depth)
    if not usable(frame) or depth < 0 then return nil end
    for _, child in ipairs({ frame:GetChildren() }) do
        if shown(child) and child ~= win then
            if textHasHero(child, names) then
                local w = windowAround(child)
                local n = 0
                for _ in pairs(heroNamesIn(w, names, 8)) do n = n + 1 end
                if n >= 2 then return child end
            end
            local sub = scanFor(child, names, depth - 1)
            if sub then return sub end
        end
    end
    return nil
end

-- from the frame with the name text, up to the window around the two columns (the first one wide enough to hold both)
function windowAround(frame)
    local f = frame
    while usable(f) and usable(f:GetParent()) and f:GetParent() ~= UIParent and widthOf(f) < 800 do f = f:GetParent() end
    return f
end

local function findHeroDialog(names)
    for _, n in ipairs({ "HeroTalentsSelectionDialog", "HeroSpecDialog" }) do
        local f = _G[n]
        if shown(f) then return f end
    end
    local hit = scanFor(_G.PlayerSpellsFrame, names, 7)
    if not hit then
        for _, child in ipairs({ UIParent:GetChildren() }) do
            if shown(child) and child ~= win and child ~= _G.PlayerSpellsFrame then
                if textHasHero(child, names) then hit = child break end
                hit = scanFor(child, names, 5)
                if hit then break end
            end
        end
    end
    return hit and windowAround(hit) or nil
end

local function updateHeroDialog()
    local ok, s = pcall(A.Suggest, "raid")
    if not ok or not s or not s.heroShares or #s.heroShares < 2 then
        if heroLabel then heroLabel:Hide() end
        return
    end
    heroNames = {}
    for _, h in ipairs(s.heroShares) do heroNames[h.name:lower()] = true end
    if not shown(heroDialog) then
        heroDialog = findHeroDialog(heroNames)
        heroLabel = nil
    end
    if not heroDialog then return end
    if not heroLabel then
        heroLabel = heroDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        heroLabel:SetPoint("BOTTOM", heroDialog, "BOTTOM", 0, 10)
        heroLabel:SetWidth(math.max(400, (widthOf(heroDialog) > 0 and widthOf(heroDialog) or 800) - 40))
        heroLabel:SetJustifyH("CENTER")
        heroLabel:SetSpacing(3)
    end
    local lines = { "|cffffd100Seviaths advisor - the better hero tree:|r" }
    for _, key in ipairs({ "raid", "mythic", "delves" }) do
        local okC, sc = pcall(A.Suggest, key)
        if okC and sc and sc.heroShares and #sc.heroShares > 0 then
            local parts = {}
            for i, h in ipairs(sc.heroShares) do
                parts[i] = ("%s%s %d%%|r"):format(i == 1 and "|cff40ff40" or "|cffc0c0c0", h.name, math.floor(h.share * 100 + 0.5))
            end
            lines[#lines + 1] = ("|cffffd100%s|r: %s"):format(CONTENTS[key], table.concat(parts, "  vs  "))
        end
    end
    heroLabel:SetText(table.concat(lines, "\n"))
    heroLabel:Show()
end

-- the talents page can be built late or switched to from another tab: watch it, open and close the advisor with it
local wasUp
local heroTick = 0
C_Timer.NewTicker(0.5, function()
    heroTick = heroTick + 1
    if wasUp and heroTick % 2 == 0 then SFP:Safe("hero choice advisor", updateHeroDialog) end
    local f = _G.PlayerSpellsFrame
    local tf = f and f.TalentsFrame
    local up = shown(f) and shown(tf)
    if up == wasUp then return end
    wasUp = up
    if up then
        -- a small button on the talents window brings the advisor back after it was closed
        local f = _G.PlayerSpellsFrame
        if f and not A.reopen then
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(110, 20)
            b:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -4, 2)
            b:SetText("Talent advisor")
            b:SetScript("OnClick", function()
                -- closed or opened by you: saved, so the talents window opens it the same way next time
                if win and win:IsShown() then
                    SFP.db.talentAdvisorOpen = false
                    win:Hide()
                else
                    SFP.db.talentAdvisorOpen = true
                    SFP:Safe("talent advisor", SFP.ShowTalentAdvisor, SFP)
                end
            end)
            A.reopen = b
        end
        if A.reopen then A.reopen:Show() end
        A.ResetCache()
        if SFP.db and SFP.db.talentAdvisor ~= false and SFP.db.talentAdvisorOpen ~= false then SFP:Safe("talent advisor", SFP.ShowTalentAdvisor, SFP) end
    elseif win then
        win:Hide()
    end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("TRAIT_CONFIG_UPDATED")
ev:RegisterEvent("TRAIT_NODE_CHANGED")
ev:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")
ev:RegisterEvent("INSPECT_READY")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CHALLENGE_MODE_START")
ev:RegisterEvent("CHALLENGE_MODE_KEYSTONE_SLOTTED")
ev:SetScript("OnEvent", function(_, event, name)
    if event == "INSPECT_READY" then
        SFP:Safe("talent learning", learnInspected)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(5, function() SFP:Safe("talent learning", learnOwn) end)
    elseif event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_KEYSTONE_SLOTTED" then
        C_Timer.After(1, function() SFP:Safe("key affixes", learnKeyAffixes) end)
        if event == "CHALLENGE_MODE_START" then C_Timer.After(2, function() SFP:Safe("talent learning", learnOwn) end) end
    elseif event == "ADDON_LOADED" then
        if name == "Blizzard_PlayerSpells" or name == "Blizzard_ClassTalentUI" then
            C_Timer.After(0, function() SFP:Safe("talent advisor hook", hookFrame) end)
        end
    else
        A.ResetCache()
        -- points added or taken back: the suggestions follow at once
        C_Timer.After(0.1, function() SFP:Safe("talent advisor", refresh) end)
    end
end)
SFP:OnLogin(function() SFP:Safe("talent advisor hook", hookFrame) end)
