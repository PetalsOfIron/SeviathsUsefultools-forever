-- Seviath's Codex — Best grinding spots
-- A top 10 of the farm spots the addon knows, ranked by what the loot is worth on the auction house right now.
-- Monsters: value per kill (your own kills when you have enough of them, else an estimate from the items the
-- spot lists). Gathering: value per node. Spots with many spawn points rank a little higher (more to kill).
-- It is an estimate to compare spots, not a gold-per-hour promise: prices differ per realm.

local ADDON, ns = SFP_Module("Codex")
local C = ns.CYAN

local TOP = 10
local MAX_PER_ZONE = 3
-- chance that a kill gives one of these (from Wowhead drop data of typical farm monsters); only a guide
local RATE = { leather = 0.75, meat = 0.5, element = 0.35, cloth = 0.07, enchant = 0.15 }
local GATHER_YIELD = 1.5   -- items per node with normal gathering gear

local function main() return _G.SeviathsUsefulTools end

local function money(c)
    c = math.floor((c or 0) + 0.5)
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return math.floor(c / 10000) .. "g"
end

local function priceOf(S, id)
    local p = S:GetPrice(id)
    return (p and p > 0) and p or 0
end

-- every farm spot with a value, best first
local function Candidates()
    local S = main()
    local out = {}
    if not (S and S.db and S.zoneByMap) then return out end
    for mapID, zone in pairs(S.zoneByMap) do
        for _, sp in ipairs(zone.spawns or {}) do
            if sp.points and #sp.points > 0 and not (sp.rare or sp.hunter or sp.special) then
                local value, basis, items = 0, "estimate", {}
                if sp.gather then
                    local id = sp.items and sp.items[1]
                    local p = id and priceOf(S, id) or 0
                    value = p * GATHER_YIELD
                    basis = "per node"
                    if id then items[1] = { id = id, p = p } end
                else
                    local rec = sp.npc and sp.npc > 0 and S.Npc and S:Npc(sp.npc)
                    if sp.learned and sp.counts and (sp.kills or 0) >= 3 then
                        -- a spot the addon learned from your own kills (account-wide): measured drop rates
                        for id, n in pairs(sp.counts) do
                            local p = priceOf(S, id)
                            value = value + p * n / sp.kills
                            if p > 0 then items[#items + 1] = { id = id, p = p } end
                        end
                        basis = "your kills (" .. sp.kills .. ")"
                    elseif rec and (rec.k or 0) >= 3 and rec.d then
                        for id, n in pairs(rec.d) do
                            local p = priceOf(S, id)
                            value = value + p * n / rec.k
                            if p > 0 then items[#items + 1] = { id = id, p = p } end
                        end
                        basis = "your kills (" .. rec.k .. ")"
                    else
                        for _, id in ipairs(sp.items or {}) do
                            local info = S.Items and S.Items[id]
                            local rate = info and RATE[info.kind]
                            local p = priceOf(S, id)
                            if rate and p > 0 then
                                value = value + p * rate
                                items[#items + 1] = { id = id, p = p }
                            end
                        end
                    end
                end
                if value > 0 then
                    local density = math.min(#sp.points, 40) / 40
                    table.sort(items, function(a, b) return a.p > b.p end)
                    out[#out + 1] = {
                        current = (S.zoneExp[mapID] and S.zoneExp[mapID].key) == "midnight",
                        map = mapID, sp = sp, value = value, basis = basis, items = items, gather = sp.gather,
                        score = value * (0.5 + 0.5 * density), points = #sp.points,
                    }
                end
            end
        end
    end
    -- the current expansion first (what you can do with a normal character today), then older content, each by score
    table.sort(out, function(a, b)
        if a.current ~= b.current then return a.current end
        return a.score > b.score
    end)
    return out
end

local MAX_GATHER = 4   -- the list is about grinding: gathering spots take at most four of the ten places

local function TopSpots()
    local list, perZone, gathers = {}, {}, 0
    for _, c in ipairs(Candidates()) do
        local zoneOk = (perZone[c.map] or 0) < MAX_PER_ZONE
        local gatherOk = not c.gather or gathers < MAX_GATHER
        if zoneOk and gatherOk then
            perZone[c.map] = (perZone[c.map] or 0) + 1
            if c.gather then gathers = gathers + 1 end
            list[#list + 1] = c
            if #list >= TOP then break end
        end
    end
    return list
end

local function ZoneAndExp(S, mapID)
    local zone = S:ZoneName(mapID)
    local exp = S.zoneExp and S.zoneExp[mapID]
    return zone, exp and exp.name or ""
end

-- (re)build the ten entries; safe to call again, the entries are updated in place
function ns:LoadGrind()
    local S = main()
    local top = TopSpots()
    for i = 1, TOP do
        local c = top[i]
        local key = "grind:" .. i
        local e = self:Get(key)
        if c then
            local zone, exp = ZoneAndExp(S, c.map)
            local first = c.items[1] and c.items[1].id
            local name = ("#%d  %s — %s"):format(i, c.sp.name or "?", zone)
            local fields = {
                name = name, lname = name:lower(), grind = c, order = i, openMap = c.map,
                icon = first and C_Item.GetItemIconByID(first) or "Interface\\Icons\\INV_Misc_Coin_01",
                sub = zone .. " " .. exp .. " " .. (c.gather and "gathering" or "monsters"),
                map = c.sp.hx and { m = c.map, x = c.sp.hx, y = c.sp.hy } or nil,
            }
            if e then
                for k, v in pairs(fields) do e[k] = v end
                if self.PrepareSearch then self.PrepareSearch(e) end
            else
                fields.cat, fields.id, fields.group = "grind", i, "Top 10 by estimated gold (Midnight first)"
                fields.tags = "grind grinding farm gold best spot " .. zone:lower()
                self:Add(fields)
            end
        elseif e then
            e.grind = nil; e.name = ("#%d  (not enough price data yet)"):format(i); e.lname = e.name:lower()
        end
    end
    -- nothing priced yet: say what to do
    if #top == 0 and not self:Get("grind:1") then
        self:Add({ cat = "grind", id = 1, group = "Top 10 by estimated gold (Midnight first)", order = 1,
            name = "No prices yet - how to get the ranking", icon = "Interface\\Icons\\INV_Misc_Coin_01",
            body = "The ranking uses auction house prices. Open the auction house once (the addon scans it), or install Auctionator or TradeSkillMaster and scan there. Then reopen the Codex." })
    end
    self.grindTime = GetTime and GetTime() or 0
end

function ns:RefreshGrind()
    if self.grindTime and GetTime and GetTime() - self.grindTime < 20 then return end
    if self.LoadGrind then self:LoadGrind() end
end

function ns:GrindText(e)
    local c = e.grind
    local S = main()
    local out = {}
    local zone, exp = ZoneAndExp(S, c.map)
    out[#out + 1] = C .. "Where|r\n" .. zone .. (exp ~= "" and (" (" .. exp .. ")") or "")
        .. (e.map and ("  " .. ns:Coords(e.map):gsub("^.-%s", "")) or "")
    local what = c.gather and "per node" or "per kill"
    out[#out + 1] = C .. "Worth|r\n~" .. money(c.value) .. " " .. what .. "   |cff888888(" ..
        (c.basis == "estimate" and "estimate from the items this spot gives and today's prices" or c.basis) .. ")|r"
    out[#out + 1] = C .. (c.gather and "Spawns|r\n" or "Monsters|r\n") .. c.points .. " spawn points on the map" ..
        (c.sp.npc and c.sp.npc > 0 and ("   |cff888888NPC " .. c.sp.npc .. "|r") or "")
    if #c.items > 0 then
        local lines = {}
        for i = 1, math.min(6, #c.items) do
            local it = c.items[i]
            lines[#lines + 1] = "• " .. (S:ItemName(it.id)) .. "   " .. money(it.p)
        end
        out[#out + 1] = C .. "What you get|r\n" .. table.concat(lines, "\n")
    end
    -- why this spot is on the list
    local why = {}
    local top = c.items[1]
    if top and c.value > 0 then
        local share = math.floor(top.p * 100 / math.max(c.value, 1) + 0.5)
        if c.basis == "estimate" then
            why[#why + 1] = ("%s sells for %s and is the best item here (about %d%% of the value by the estimate)."):format(S:ItemName(top.id), money(top.p), math.min(share, 100))
        else
            why[#why + 1] = ("%s sells for %s and is the best item here."):format(S:ItemName(top.id), money(top.p))
        end
    end
    why[#why + 1] = ("About %s %s at today's prices%s."):format(money(c.value), c.gather and "per node" or "per kill",
        c.basis == "estimate" and " (an estimate)" or (" - measured from " .. c.basis:gsub("^your kills ", "your kills ")))
    if c.points >= 20 then
        why[#why + 1] = ("%d spawn points: there is almost always one close by, so you rarely wait."):format(c.points)
    elseif c.points >= 8 then
        why[#why + 1] = ("%d spawn points: enough to keep moving between them."):format(c.points)
    else
        why[#why + 1] = ("only %d spawn points, so it is slower to keep going."):format(c.points)
    end
    out[#out + 1] = C .. "Why it is #" .. (e.order or "?") .. "|r\n" .. table.concat(why, " ")
    if not c.current then
        out[#out + 1] = "|cffffd100Older content: this spot is not from the current expansion. It is listed because there were fewer than ten priced Midnight spots.|r"
    end
    out[#out + 1] = "|cff888888How the ranking works: Midnight spots come first, then older content. Inside each, by value per kill or node at current auction prices, a little higher for spots with " ..
        "many spawn points. Prices differ per realm, so scan the auction house (or use Auctionator / TSM) to keep this current. " ..
        "It compares spots with each other; it is not a gold-per-hour promise.|r"
    return table.concat(out, "\n\n")
end
