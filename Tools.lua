-- SeviathsUsefulTools - tools
--   route   : ticked spots of the zone ordered into a short loop, drawn on the map  (spot list button "Route")
--   weekly  : /sfp weekly  - Great Vault, raid lockouts and rare kills of all your characters
--   deals   : /sfp flip    - BoE items now against their typical price (also a button at the auction house)
--   shop    : /sfp shop    - pick recipes, get the reagent list with prices and where to farm them
-- Only reads the game and the addon's own saved data.

local _, SFP = ...

local function secret(v) return issecretvalue and issecretvalue(v) end
local function money(c)
    c = math.floor((c or 0) + 0.5)
    if GetCoinTextureString then return GetCoinTextureString(c) end
    -- gold, silver and copper, each shown when it is there
    local g, s, cc = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = "|cffffd100" .. g .. "g|r" end
    if s > 0 or g > 0 then parts[#parts + 1] = "|cffc7c7cf" .. s .. "s|r" end
    parts[#parts + 1] = "|cffeda55f" .. cc .. "c|r"
    return table.concat(parts, " ")
end

---------------------------------------------------------------------------
-- a small scrolling text window
---------------------------------------------------------------------------
local function makeWindow(name, title, w, h)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    SFP.RegisterWindow(f)
    SFP.BlizzardFrame(f, true)
    f:SetBackdropColor(0.08, 0.03, 0.03, 0.95)
    f:SetBackdropBorderColor(0.9, 0.28, 0.24, 0.8)
    f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetText(title)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    f.closeBtn = close
    f.scroll = CreateFrame("ScrollFrame", name .. "Scroll", f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", 12, -34)
    f.scroll:SetPoint("BOTTOMRIGHT", -30, 12)
    f.child = CreateFrame("Frame", nil, f.scroll)
    f.child:SetSize(w - 50, 10)
    f.scroll:SetScrollChild(f.child)
    f.text = f.child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("TOPLEFT")
    f.text:SetWidth(w - 56)
    f.text:SetJustifyH("LEFT")
    f.text:SetSpacing(3)
    f.SetContent = function(self, str)
        self.text:SetText(str)
        self.child:SetHeight(self.text:GetStringHeight() + 10)
    end
    f:Hide()
    return f
end

---------------------------------------------------------------------------
-- a scrolling list of rows, each with a text and a few buttons (the saved lists use it)
---------------------------------------------------------------------------
function SFP.MakeRowList(parent, x, y, w, h, rowH)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", x, y)
    sf:SetSize(w - 24, h)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(w - 24, 10)
    sf:SetScrollChild(child)
    local rows = {}
    local list = { scroll = sf }
    -- items: { { text = "...", buttons = { { "label", width, function } , ... } }, ... }
    function list:Set(items)
        for i, it in ipairs(items) do
            local r = rows[i]
            if not r then
                r = CreateFrame("Frame", nil, child)
                r:SetSize(w - 24, rowH)
                r:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
                r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                r.text:SetPoint("LEFT", 4, 0)
                r.text:SetJustifyH("LEFT")
                r.text:SetWordWrap(false)
                r.btns = {}
                -- a row with a unit shows that player's tooltip (all the stats the addon knows) when hovered
                r:EnableMouse(true)
                r:SetScript("OnEnter", function(self)
                    if self.unit and UnitExists(self.unit) then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetUnit(self.unit)
                        GameTooltip:Show()
                    elseif self.tip then
                        -- a row without a unit (a listed player): its own tooltip lines
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        pcall(self.tip, GameTooltip)
                        GameTooltip:Show()
                    end
                end)
                r:SetScript("OnLeave", function() GameTooltip:Hide() end)
                rows[i] = r
            end
            r.unit = it.unit
            r.tip = it.tip
            r.text:SetText(it.text or "")
            -- an optional tick box in front of the row: it.check = true / false, it.onToggle(ticked)
            if it.check ~= nil then
                if not r.tick then
                    r.tick = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
                    r.tick:SetSize(20, 20)
                    r.tick:SetPoint("LEFT", 0, 0)
                end
                r.tick:SetChecked(it.check and true or false)
                r.tick:SetScript("OnClick", function(self) if it.onToggle then it.onToggle(self:GetChecked() and true or false) end end)
                r.tick:Show()
                r.text:ClearAllPoints()
                r.text:SetPoint("LEFT", 24, 0)
            else
                if r.tick then r.tick:Hide() end
                r.text:ClearAllPoints()
                r.text:SetPoint("LEFT", 4, 0)
            end
            local used = 0
            for j = #(it.buttons or {}), 1, -1 do
                local def = it.buttons[j]
                local b = r.btns[j]
                if not b then
                    b = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
                    r.btns[j] = b
                end
                b:SetSize(def[2], rowH - 2)
                b:ClearAllPoints()
                b:SetPoint("RIGHT", r, "RIGHT", -used, 0)
                b:SetText(def[1])
                b:SetScript("OnClick", def[3])
                b:Show()
                used = used + def[2] + 2
            end
            for j = #(it.buttons or {}) + 1, #r.btns do r.btns[j]:Hide() end
            r.text:SetWidth(math.max(40, w - 24 - used - 8 - (it.check ~= nil and 24 or 0)))
            -- a tick row can be clicked anywhere (name included), not only on the small box
            if it.check ~= nil then
                if not r.click then
                    r.click = CreateFrame("Button", nil, r)
                    r.click:SetFrameLevel(r:GetFrameLevel() + 1)
                    r.click:SetScript("OnClick", function() if r.tick then r.tick:Click() end end)
                    -- the click area lies over the row: it passes the hover on, so the tooltip of the row shows
                    r.click:SetScript("OnEnter", function() local h = r:GetScript("OnEnter"); if h then h(r) end end)
                    r.click:SetScript("OnLeave", function() local h = r:GetScript("OnLeave"); if h then h(r) end end)
                    r.click:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
                end
                r.tick:SetFrameLevel(r:GetFrameLevel() + 3)
                r.click:ClearAllPoints()
                r.click:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
                r.click:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -used, 0)
                r.click:Show()
            elseif r.click then
                r.click:Hide()
            end
            r:Show()
        end
        for i = #items + 1, #rows do rows[i]:Hide() end
        child:SetHeight(#items * rowH + 4)
    end
    return list
end

---------------------------------------------------------------------------
-- route: nearest-neighbour loop through the ticked spots of a zone
---------------------------------------------------------------------------
local MAX_ROUTE = 12

function SFP:BuildRoute(mapID, only)
    local zone = self.zoneByMap and self.zoneByMap[mapID]
    if not (zone and zone.spawns) then self:Print("No farm spots on this map."); return end
    local spots, seen = {}, {}
    -- the first place of a rare or a hunter tame ("x,y;x,y" in percent)
    local function firstPlace(sp)
        if sp.hx and sp.hy then return sp.hx, sp.hy end
        local x, y = tostring(sp.pts or ""):match("^([%d%.]+),([%d%.]+)")
        if x then return tonumber(x) / 100, tonumber(y) / 100 end
    end
    local function consider(sp)
        local key = self.SpotKey(sp)
        if seen[key] then return end
        local use
        if only then use = only[key] else use = self.ShowSpot and self.ShowSpot(sp) end
        local x, y = firstPlace(sp)
        if x and use then
            seen[key] = true
            spots[#spots + 1] = { name = sp.name or "?", x = x, y = y }
        end
    end
    for _, sp in ipairs(zone.spawns) do consider(sp) end
    -- rares and hunter tames of the map belong in the route too (a spot of the farm list that is ticked)
    for _, sp in ipairs((self.Rares and self.Rares[mapID]) or {}) do consider(sp) end
    return self:RouteFromSpots(mapID, spots)
end

-- spots = { { name, x, y }, ... } on one map: order them into a loop, draw it, set a waypoint
function SFP:RouteFromSpots(mapID, spots)
    if #spots < 2 then self:Print("Pick at least two spots first."); return end
    -- start next to you when you are in this zone, else at the first spot
    local cx, cy
    if C_Map.GetBestMapForUnit("player") == mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos and pos.GetXY then
            local x, y = pos:GetXY()
            if not secret(x) and not secret(y) and x and x > 0 then cx, cy = x, y end
        end
    end
    local route, left = {}, {}
    for i, s in ipairs(spots) do left[i] = s end
    cx, cy = cx or left[1].x, cy or left[1].y
    while #left > 0 and #route < MAX_ROUTE do
        local bi, bd
        for i, s in ipairs(left) do
            local d = (s.x - cx) ^ 2 + (s.y - cy) ^ 2
            if not bd or d < bd then bi, bd = i, d end
        end
        local s = table.remove(left, bi)
        route[#route + 1] = s
        cx, cy = s.x, s.y
    end
    -- close the loop back to the start
    local pts = {}
    for i, s in ipairs(route) do pts[i] = { x = s.x, y = s.y, name = s.name } end
    pts[#pts + 1] = { x = route[1].x, y = route[1].y, name = route[1].name }
    local total = 0
    for i = 1, #pts - 1 do total = total + math.sqrt((pts[i + 1].x - pts[i].x) ^ 2 + (pts[i + 1].y - pts[i].y) ^ 2) end
    if self.SetRoute then self.SetRoute(mapID, pts) end
    local names = {}
    for i, s in ipairs(route) do names[i] = i .. ". " .. s.name end
    self:Print(("Route of %d spots drawn on the map (about %.0f%% of the map across): %s"):format(#route, total * 100, table.concat(names, "  ")))
    if route[1] and self.SetWaypoint then self:SetWaypoint(mapID, route[1].x, route[1].y, route[1].name) end
end

-- every zone that has farm spots, in expansion order: { map, name, exp, count }
function SFP:RouteZones()
    local out = {}
    local order = {}
    for i, exp in ipairs(self.Expansions or {}) do order[exp.key] = i end
    for mapID, zone in pairs(self.zoneByMap or {}) do
        local n = 0
        for _, sp in ipairs(zone.spawns or {}) do
            if sp.hx and sp.hy then n = n + 1 end
        end
        if n >= 2 then
            local exp = self.zoneExp and self.zoneExp[mapID]
            out[#out + 1] = { map = mapID, name = self:ZoneName(mapID), exp = exp and exp.name or "", expOrder = exp and order[exp.key] or 99, count = n }
        end
    end
    -- two maps with the same name (floors, sub-areas): tell them apart
    local seen = {}
    for _, z in ipairs(out) do seen[z.name] = (seen[z.name] or 0) + 1 end
    for _, z in ipairs(out) do if seen[z.name] > 1 then z.name = z.name .. " (map " .. z.map .. ")" end end
    table.sort(out, function(a, b)
        if a.expOrder ~= b.expOrder then return a.expOrder > b.expOrder end   -- newest expansion first
        return a.name < b.name
    end)
    return out
end

function SFP:ClearRoute()
    if self.SetRoute then self.SetRoute(nil, nil) end
end

---------------------------------------------------------------------------
-- weekly checklist (all characters)
---------------------------------------------------------------------------
local function charKey()
    return (UnitName("player") or "?") .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or "?"):gsub("[%s%-']", ""))
end

local VAULT_TYPES = { { "Raid", "Raid", 1 }, { "Dungeons", "Activities", 2 }, { "World", "World", 6 } }

function SFP:UpdateWeekly()
    if not self.db then return end
    local rec = { t = time(), vault = {}, locks = {} }
    if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
        for _, v in ipairs(VAULT_TYPES) do
            local typ = (Enum and Enum.WeeklyRewardChestThresholdType and Enum.WeeklyRewardChestThresholdType[v[2]]) or v[3]
            local ok, acts = pcall(C_WeeklyRewards.GetActivities, typ)
            if ok and type(acts) == "table" and #acts > 0 then
                local open = 0
                for _, a in ipairs(acts) do
                    if type(a.progress) == "number" and type(a.threshold) == "number" and not secret(a.progress) and a.progress >= a.threshold then open = open + 1 end
                end
                rec.vault[#rec.vault + 1] = ("%s %d/%d"):format(v[1], open, #acts)
            end
        end
    end
    rec.raids, rec.fresh = {}, {}
    local locked = {}
    if GetNumSavedInstances then
        for i = 1, GetNumSavedInstances() do
            local name, _, reset, _, isLocked, _, _, isRaid, _, diffName, numEnc, encProg = GetSavedInstanceInfo(i)
            if isLocked and isRaid and type(name) == "string" and not secret(name) then
                rec.locks[#rec.locks + 1] = ("%s (%s) %s/%s"):format(name, tostring(diffName or "?"), tostring(encProg or "?"), tostring(numEnc or "?"))
                locked[name] = true
                local done, left = {}, {}
                for j = 1, tonumber(numEnc) or 0 do
                    local okE, bossName, _, killed = pcall(GetSavedInstanceEncounterInfo, i, j)
                    if okE and type(bossName) == "string" then
                        if killed then done[#done + 1] = bossName else left[#left + 1] = bossName end
                    end
                end
                rec.raids[#rec.raids + 1] = { name = name, diff = tostring(diffName or "?"), done = done, left = left }
            end
        end
    end
    -- the raids of the newest expansion that you have not entered this week
    local newest
    for _, exp in ipairs(self.Expansions or {}) do
        for _, inst in ipairs(exp.instances or {}) do
            if inst.kind == "raid" then newest = exp; break end
        end
    end
    for _, inst in ipairs(newest and newest.instances or {}) do
        if inst.kind == "raid" and not locked[inst.name] then
            local bosses, seen = {}, {}
            for _, list in pairs(self.lootIndex or {}) do
                for _, e in ipairs(list) do
                    if e[1] == inst.name and e[2] and not seen[e[2]] then seen[e[2]] = true; bosses[#bosses + 1] = e[2] end
                end
            end
            table.sort(bosses)
            rec.fresh[#rec.fresh + 1] = { name = inst.name, bosses = bosses }
        end
    end
    local kills = 0
    local k = self.db.killed and self.db.killed[charKey()]
    for id in pairs(k or {}) do if self:RareKilledToday(id) then kills = kills + 1 end end
    rec.rares = kills
    self.db.weekly = self.db.weekly or {}
    self.db.weekly[charKey()] = rec
end

local weeklyWin
function SFP:ShowWeekly()
    self:UpdateWeekly()
    weeklyWin = weeklyWin or makeWindow("SeviathsUsefulToolsWeekly", "Weekly checklist - all your characters", 460, 340)
    local lines = {}
    local keys = {}
    for key in pairs(self.db.weekly or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local r = self.db.weekly[key]
        local age = math.floor((time() - (r.t or 0)) / 3600)
        lines[#lines + 1] = "|cffffd100" .. key .. "|r  |cff808080(" .. (age < 1 and "now" or (age .. " h ago")) .. ")|r"
        lines[#lines + 1] = "  Great Vault: " .. (#r.vault > 0 and table.concat(r.vault, "   ") or "no data")
        lines[#lines + 1] = "  Rares killed today: " .. (r.rares or 0)
        lines[#lines + 1] = "  |cffffd100Raids this week|r"
        for _, raid in ipairs(r.raids or {}) do
            local total = #raid.done + #raid.left
            lines[#lines + 1] = ("    %s (%s)  %d/%d  %s"):format(raid.name, raid.diff, #raid.done, total,
                #raid.left == 0 and "|cff40ff40all done|r" or "|cffff6060to do:|r " .. table.concat(raid.left, ", "))
            if #raid.done > 0 then lines[#lines + 1] = "      |cff40ff40done:|r " .. table.concat(raid.done, ", ") end
        end
        for _, raid in ipairs(r.fresh or {}) do
            lines[#lines + 1] = ("    %s  |cffff6060not started|r%s"):format(raid.name,
                #raid.bosses > 0 and (" - " .. #raid.bosses .. " bosses: " .. table.concat(raid.bosses, ", ")) or "")
        end
        if #(r.raids or {}) == 0 and #(r.fresh or {}) == 0 then lines[#lines + 1] = "    no raid data yet (log in with this character again)" end
        lines[#lines + 1] = ""
    end
    if #lines == 0 then lines[1] = "No data yet." end
    lines[#lines + 1] = "|cff808080A character shows here after you log in with it. World boss and weekly quest status are not in this list: the game's quest numbers for them are not in the addon.|r"
    weeklyWin:SetContent(table.concat(lines, "\n"))
    weeklyWin:Show()
end

local wf = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "WEEKLY_REWARDS_UPDATE", "UPDATE_INSTANCE_INFO" }) do pcall(wf.RegisterEvent, wf, e) end
local weeklyTimer
wf:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" and RequestRaidInfo then pcall(RequestRaidInfo) end
    if weeklyTimer then return end
    weeklyTimer = true
    C_Timer.After(8, function() weeklyTimer = nil; SFP:Safe("weekly", SFP.UpdateWeekly, SFP) end)
end)

---------------------------------------------------------------------------
-- BoE deals: now against the typical price (median of what this realm showed before)
---------------------------------------------------------------------------
local function median(list)
    table.sort(list)
    local n = #list
    if n == 0 then return nil end
    if n % 2 == 1 then return list[(n + 1) / 2] end
    return (list[n / 2] + list[n / 2 + 1]) / 2
end

function SFP:TypicalPrice(itemID)
    local ph = self.db.priceHist and self.db.priceHist[self:RealmKey()]
    local samples = ph and ph[itemID]
    if samples and type(samples[1]) == "table" then samples = self.FlatHistory(samples) end   -- an older history
    if samples and #samples >= 6 then
        local vals = {}
        -- the newest sample is "now"; the typical price is what came before (the flat list is price, time, price, time ...)
        for i = 1, #samples - 2, 2 do vals[#vals + 1] = samples[i] end
        return median(vals), #vals, "your scans"
    end
    -- no history of our own: Auctionator's own price history (when this version offers it)
    if Auctionator and Auctionator.Database and Auctionator.Database.GetPriceHistory then
        for _, key in ipairs({ tostring(itemID), "g:" .. itemID }) do
            local ok, hist = pcall(Auctionator.Database.GetPriceHistory, Auctionator.Database, key)
            if ok and type(hist) == "table" and #hist >= 3 then
                local vals = {}
                for _, h in ipairs(hist) do
                    local v = type(h) == "table" and (h.minSeen or h.min or h.price) or h
                    if type(v) == "number" and v > 0 then vals[#vals + 1] = v end
                end
                if #vals >= 3 then return median(vals), #vals, "Auctionator history" end
            end
        end
    end
    -- TradeSkillMaster keeps a long-term price too
    if TSM_API and TSM_API.GetCustomPriceValue then
        for _, src in ipairs({ "DBHistorical", "DBMarket", "DBRegionMarketAvg" }) do
            local ok, v = pcall(TSM_API.GetCustomPriceValue, src, "i:" .. itemID)
            if ok and type(v) == "number" and v > 0 then return v, 0, "TradeSkillMaster " .. src end
        end
    end
end

function SFP:BoeDeals()
    local out, nohist = {}, {}
    local seen = {}
    local function consider(id)
        if seen[id] then return end
        seen[id] = true
        -- now: our own scan, else Auctionator / TradeSkillMaster
        local now = self:GetPrice(id)
        if now and now > 0 then
            local typical, n, src = self:TypicalPrice(id)
            if typical and typical > 0 then
                out[#out + 1] = { id = id, now = now, typical = typical, n = n, src = src, cut = 1 - now / typical }
            else
                nohist[#nohist + 1] = { id = id, now = now }
            end
        end
    end
    for id, info in pairs(self.Items or {}) do
        if info.kind == "boe" then
            if C_Item and C_Item.RequestLoadItemDataByID and not (C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) then
                pcall(C_Item.RequestLoadItemDataByID, id)
            end
            consider(id)
        end
    end
    -- every bind-on-equip weapon and armor piece (uncommon or better) the auction house scan priced
    local prices = self:AllPrices()
    for id in pairs(prices or {}) do
        if type(id) == "number" and not seen[id] then
            local okI, _, _, quality, _, _, _, _, _, _, _, _, classID, _, bindType = pcall(C_Item.GetItemInfo, id)
            if okI and bindType == nil and C_Item.RequestLoadItemDataByID then
                pcall(C_Item.RequestLoadItemDataByID, id)   -- not loaded yet: the next time the list opens it is there
            elseif okI and bindType == 2 and (classID == 2 or classID == 4) and type(quality) == "number" and quality >= 2 then
                consider(id)
            end
        end
    end
    table.sort(out, function(a, b) return a.cut > b.cut end)
    table.sort(nohist, function(a, b) return a.now > b.now end)
    return out, nohist
end

local dealWin, dealRows
local function renderDeals(self)
    local list, nohist = self:BoeDeals()
    local items = {}
    local function tip(id) return function(tt) tt:SetItemByID(id) end end   -- the tooltip of the item (read from the auction house scan or the game)
    for i, d in ipairs(list) do
        if i > 60 then break end
        local pct = math.floor(d.cut * 100 + 0.5)
        local color = pct >= 20 and "|cff40ff40" or (pct <= -20 and "|cffff6060" or "|cffffffff")
        items[#items + 1] = { tip = tip(d.id), text = ("%s%s%d%%|r  %s   now %s   typical %s  |cff808080(%s)|r"):format(
            color, pct >= 0 and "-" or "+", math.abs(pct), self:ItemName(d.id), money(d.now), money(d.typical),
            d.src == "your scans" and (d.n .. " scans") or d.src) }
    end
    if #items > 0 then
        table.insert(items, 1, { text = "|cff808080Green = cheaper than usual. Prices: your own scans, else Auctionator or TradeSkillMaster. Hover an item for its tooltip.|r" })
    end
    -- items that have a price now but nothing to compare with yet
    if #nohist > 0 then
        items[#items + 1] = { text = "|cffffd100BoE prices now|r  |cff808080(no price history yet - the addon keeps one from now on, so this fills in over a few days)|r" }
        for i, d in ipairs(nohist) do
            if i > 80 then break end
            items[#items + 1] = { tip = tip(d.id), text = ("%s   %s"):format(self:ItemName(d.id), money(d.now)) }
        end
    end
    if #items == 0 then
        items[1] = { text = "No BoE prices known yet. Scan the auction house (button below its window), or install Auctionator or TradeSkillMaster and scan there. Then open this list again." }
    end
    dealRows:Set(items)
end

function SFP:ShowDeals()
    if not dealWin then
        dealWin = makeWindow("SeviathsUsefulToolsDeals", "BoE deals - now against the typical price", 680, 600)
        dealWin.scroll:Hide()
        dealRows = SFP.MakeRowList(dealWin, 12, -34, 650, 548, 26)   -- roomy rows
        local acc = 0
        dealWin:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc < 2 then return end
            acc = 0
            SFP:Safe("deals update", renderDeals, SFP)
        end)
    end
    renderDeals(self)
    dealWin:Show()
end

---------------------------------------------------------------------------
-- recipe planner (the crafting shopping list)
---------------------------------------------------------------------------
local shopWin, shopBox, shopRows = nil, nil, nil
local shopOff = {}   -- recipe keys that are unticked: they stay in the list but are left out of the breakdown
local shopFound = {}  -- the recipes the search found
local shopProf        -- search only this profession (nil = all)
local shopTruncated    -- how many recipes matched when the list shows only the first ones
local shopShowResults   -- defined further down; shopRefresh calls it

-- the list is saved with the addon's data, so it is still there after a relog and on every character
-- recipes: the ones your characters learned (saved), and the shipped list of every recipe of the nine crafting professions
local shipped
local function shippedRecipes()
    if shipped then return shipped end
    shipped = {}
    for _, r in ipairs(SFP.RecipeData or {}) do
        local reag = {}
        for i, rg in ipairs(r[5]) do reag[i] = { rg[1], rg[2] } end
        shipped["s" .. r[1]] = { n = r[3], p = r[2], o = (r[4] and r[4] > 0) and r[4] or nil, r = reag, id = r[1] }
    end
    return shipped
end

local function recipeOf(key)
    return (SFP.db.recipes and SFP.db.recipes[key]) or shippedRecipes()[key]
end

-- profit of one craft from the auction prices: what the product sells for (after the 5% cut) minus the reagents.
-- A few seconds of price memory keeps sorting thousands of recipes quick.
local pcache, pcacheT = {}, 0
local function cachedPrice(id)
    if GetTime() - pcacheT > 5 then wipe(pcache); pcacheT = GetTime() end
    local v = pcache[id]
    if v == nil then
        local ok, p = pcall(SFP.GetPrice, SFP, id)
        v = (ok and type(p) == "number" and p > 0) and p or false
        pcache[id] = v
    end
    return v or nil
end

-- returns profit (copper, negative = loss), cost; nil when the product or a reagent has no price yet
local function recipeProfit(rec)
    if not rec or not rec.o then return nil end
    local sell = cachedPrice(rec.o)
    if not sell and rec.n then
        -- no price for that item ID: the same name at the auction house (crafted gear has an ID per quality)
        local ok, p = pcall(SFP.PriceByName, SFP, rec.n)
        if ok and type(p) == "number" and p > 0 then sell = p end
    end
    if not sell then return nil end
    local cost = 0
    for _, rg in ipairs(rec.r or {}) do
        local p = cachedPrice(rg[1])
        if not p then return nil end
        cost = cost + p * (rg[2] or 1)
    end
    return math.floor(sell * 0.95 - cost), cost
end

local function profitText(rec)
    local profit = recipeProfit(rec)
    if not profit then return "|cff808080profit ?|r" end
    if profit >= 0 then return "|cff40ff40+" .. money(profit) .. "|r" end
    return "|cffff6060-" .. money(-profit) .. "|r"
end

local shopSortProfit, shopKnownOnly = false, false   -- "Best profit" and "My recipes only" (the two extra tabs)
local shopLearned, shopLearnedCount = {}, 0   -- recipes your characters learned ("Profession|Name"), and how many lead the best-profit list

-- the professions of this character with their skill, for the window title (it follows when you level up)
local function skillLine()
    if not (GetProfessions and GetProfessionInfo) then return "" end
    local parts = {}
    for _, idx in ipairs({ GetProfessions() }) do
        if idx then
            local ok, name, _, skill, maxSkill = pcall(GetProfessionInfo, idx)
            if ok and type(name) == "string" and type(skill) == "number" then
                parts[#parts + 1] = ("%s %d/%d"):format(name, skill, maxSkill or 0)
            end
        end
    end
    return table.concat(parts, ", ")
end

local function shopData()
    SFP.db.shopList = SFP.db.shopList or {}
    return SFP.db.shopList
end

local function shopTotals()
    local need, order = {}, {}
    local products, productValue = {}, 0
    for _, entry in ipairs(shopData()) do
        local rec = recipeOf(entry.key)
        if rec and not shopOff[entry.key] then
            for _, rg in ipairs(rec.r or {}) do
                local id, cnt = rg[1], rg[2] or 1
                if not need[id] then need[id] = 0; order[#order + 1] = id end
                need[id] = need[id] + cnt * entry.qty
            end
            if rec.o then
                local p = SFP:GetPrice(rec.o)
                if p and p > 0 then productValue = productValue + p * entry.qty * 0.95 end
            end
            products[#products + 1] = ("%dx %s"):format(entry.qty, rec.n or entry.key)
        end
    end
    return need, order, products, productValue
end

local shopRefresh
-- the tooltip of a recipe: the item it makes, else the recipe's spell, else its name
local function recipeTip(rec)
    return function(tt)
        if rec and rec.o and rec.o > 0 then
            if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, rec.o) end
            tt:SetItemByID(rec.o)
        elseif rec and rec.id and tt.SetSpellByID then tt:SetSpellByID(rec.id)
        else tt:SetText((rec and rec.n) or "?") end
        -- what the recipe needs, so the tooltip is never empty (an item the game has not loaded yet shows only its name)
        if rec and rec.r and #rec.r > 0 then
            tt:AddLine(" ")
            tt:AddLine("|cffffd100Reagents:|r")
            for _, rg in ipairs(rec.r) do
                local nm = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(rg[1])
                tt:AddLine(("  %dx %s"):format(rg[2] or 1, nm or ("item " .. rg[1])), 0.9, 0.9, 0.9)
            end
        end
        tt:Show()
    end
end

local function shopFillRows()
    local items = {}
    for i, entry in ipairs(shopData()) do
        local rec = recipeOf(entry.key)
        local key = entry.key
        items[#items + 1] = {
            text = ("%dx %s%s"):format(entry.qty, (rec and rec.n) or entry.key, rec and "" or "  |cffff6060(recipe not known on this account)|r"),
            check = not shopOff[key],
            tip = recipeTip(rec),
            onToggle = function(on) shopOff[key] = (not on) or nil; shopRefresh() end,
            buttons = {
                { "-", 24, function()
                    entry.qty = entry.qty - 1
                    if entry.qty < 1 then table.remove(shopData(), i) end
                    shopRefresh()
                end },
                { tostring(entry.qty), 34, function() end },   -- the amount, between - and +
                { "+", 24, function() entry.qty = entry.qty + 1; shopRefresh() end },
                { "Remove", 60, function() shopOff[key] = nil; table.remove(shopData(), i); shopRefresh() end },
            },
        }
    end
    shopRows:Set(items)
end

shopRefresh = function()
    if not shopWin then return end
    -- the title shows the professions with their skill, so it follows when you level up
    local sk = skillLine()
    shopWin.title:SetText("Recipe planner" .. (sk ~= "" and ("   |cff808080" .. sk .. "|r") or ""))
    shopFillRows()
    local lines = {}
    if #shopData() == 0 then
        lines[1] = "Type part of a recipe name above and click a result to add it. The list is saved: you can add, remove or change the amount of each entry whenever you want. The recipes are the ones the addon learned when you opened your professions."
    else
        local need, order, products, productValue = shopTotals()
        lines[#lines + 1] = "|cffffd100Making:|r " .. (#products > 0 and table.concat(products, ", ") or "|cff808080nothing ticked - tick the recipes you want in the list above|r")
        lines[#lines + 1] = ""
        local total, unknown = 0, 0
        for _, id in ipairs(order) do
            local unit = SFP:GetPrice(id) or 0
            local cost = unit * need[id]
            total = total + cost
            if unit <= 0 then unknown = unknown + 1 end
            local src = SFP.itemSources and SFP.itemSources[id]
            local farm = (src and src[1]) and ("  |cff80ff80farm: " .. src[1] .. "|r") or ""
            local stack = SFP:StackCount(id)
            local stackText = (unit > 0 and stack and stack > 1) and ("   |cff808080stack of " .. stack .. ": " .. money(unit * stack) .. "|r") or ""
            lines[#lines + 1] = ("%dx %s   %s each = %s%s%s"):format(need[id], SFP:ItemName(id), unit > 0 and money(unit) or "|cffff6060no price|r", unit > 0 and money(cost) or "?", stackText, farm)
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cffffd100Buying all reagents:|r " .. money(total) .. (unknown > 0 and ("  |cffff6060(" .. unknown .. " without a price)|r") or "")
        if productValue > 0 then
            lines[#lines + 1] = "|cffffd100The crafts sell for about:|r " .. money(productValue) .. " (after the 5% auction cut)  ->  " ..
                (productValue - total >= 0 and ("|cff40ff40profit " .. money(productValue - total)) or ("|cffff6060loss " .. money(total - productValue))) .. "|r"
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "|cff808080Farm or buy? A reagent is worth farming when your gold per hour from it (run /sfp session while you farm it) is more than the time you would spend buying it back. " ..
            "Green 'farm:' marks reagents the addon knows a place for.|r"
    end
    shopWin:SetContent(table.concat(lines, "\n"))
    shopShowResults()
end

local function shopIndex(key)
    for i, e in ipairs(shopData()) do if e.key == key then return i end end
end

local shopResRows
shopShowResults = function()
    if not shopResRows then return end
    local items = {}
    for idx, key in ipairs(shopFound) do
        local rec = recipeOf(key)
        -- best profit: two blocks, what you learned and what you have not learned yet
        if shopSortProfit and idx == 1 and shopLearnedCount > 0 then
            items[#items + 1] = { text = "|cff40ff40Learned - best profit first|r", buttons = {} }
        end
        if shopSortProfit and idx == shopLearnedCount + 1 then
            items[#items + 1] = { text = "|cffff9040Not learned yet - best profit first|r", buttons = {} }
        end
        local learned = rec and shopLearned[(rec.p or "") .. "|" .. (rec.n or "")]
        items[#items + 1] = {
            text = ((rec and rec.n) or key) .. "  |cff808080" .. ((rec and rec.p) or "") .. "|r  " .. profitText(rec) ..
                (learned and "  |cff40ff40learned|r" or "  |cffff9040not learned|r"),
            check = shopIndex(key) ~= nil,
            tip = recipeTip(rec),
            onToggle = function(on)
                local i = shopIndex(key)
                if on and not i then
                    shopData()[#shopData() + 1] = { key = key, qty = 1 }
                elseif not on and i then
                    shopOff[key] = nil
                    table.remove(shopData(), i)
                end
                shopRefresh()
            end,
        }
    end
    if #items == 0 then
        items[1] = { text = shopProf and ("|cff808080No " .. shopProf .. " recipes found.|r")
            or "|cff808080No recipes yet. Open your professions once so the addon learns their recipes.|r", buttons = {} }
    else
        table.insert(items, 1, { text = "|cff808080" .. (shopTruncated and ("first " .. #shopFound .. " of " .. shopTruncated .. " - type or pick a profession to narrow it") or (#shopFound .. " recipes")) .. " - click a recipe to add it, click again to remove it|r", buttons = {} })
    end
    shopResRows:Set(items)
end

local SHOP_MAX = 400

-- with nothing typed this is the browse menu: every recipe the addon knows (or the chosen profession's), just click to add
local function shopSearch(text)
    text = (text or ""):lower()
    shopFound = {}
    shopTruncated = false
    local learnedNames = {}
    shopLearned = learnedNames
    shopLearnedCount = 0
    local function consider(key, rec)
        if (#text >= 2 or not shopProf or rec.p == shopProf) and (#text < 2 or (rec.n or ""):lower():find(text, 1, true)) then
            shopFound[#shopFound + 1] = key
        end
    end
    -- recipes saved before the characters were noted belong to the character that is playing now (once)
    local me = (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "")
    if not SFP.db.recipesByDone then
        SFP.db.recipesByDone = true
        for _, rec in pairs(SFP.db.recipes or {}) do if not rec.by then rec.by = { [me] = true } end end
    end
    for key, rec in pairs(SFP.db.recipes or {}) do
        learnedNames[(rec.p or "") .. "|" .. (rec.n or "")] = true
        -- only what this character has not learned yet is listed
        if not (rec.by and rec.by[me]) then consider(key, rec) end
    end
    -- the shipped recipes; one your characters learned themselves is not listed twice.
    -- "My recipes only": just the ones your characters learned (they grow when you level a profession and open it)
    if not shopKnownOnly then
        for key, rec in pairs(shippedRecipes()) do
            if not learnedNames[(rec.p or "") .. "|" .. (rec.n or "")] then consider(key, rec) end
        end
    end
    if shopSortProfit then
        -- best profit first: only crafts whose product and reagents have an auction price
        local profit, kept = {}, {}
        for _, key in ipairs(shopFound) do
            local p = recipeProfit(recipeOf(key))
            if p then profit[key] = p; kept[#kept + 1] = key end
        end
        -- the recipes you learned come first (best profit first), then the ones you have not learned yet
        local known, unknown = {}, {}
        for _, key in ipairs(kept) do
            local r = recipeOf(key)
            if r and learnedNames[(r.p or "") .. "|" .. (r.n or "")] then known[#known + 1] = key else unknown[#unknown + 1] = key end
        end
        local function byProfit(x, y)
            if profit[x] ~= profit[y] then return profit[x] > profit[y] end
            return x < y
        end
        table.sort(known, byProfit)
        table.sort(unknown, byProfit)
        shopFound = {}
        for _, key in ipairs(known) do shopFound[#shopFound + 1] = key end
        for _, key in ipairs(unknown) do shopFound[#shopFound + 1] = key end
        shopLearnedCount = #known
    else
        table.sort(shopFound, function(x, y)
            local rx, ry = recipeOf(x), recipeOf(y)
            local px, py = (rx and rx.p) or "", (ry and ry.p) or ""
            if px ~= py then return px < py end
            local nx, ny = (rx and rx.n) or x, (ry and ry.n) or y
            if nx ~= ny then return nx < ny end
            return x < y
        end)
    end
    if #shopFound > SHOP_MAX then
        shopTruncated = #shopFound
        while #shopFound > SHOP_MAX do table.remove(shopFound) end
    end
    shopShowResults()
end
-- leveling a profession or learning a recipe: the recipe list and the profits are read again
do
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "NEW_RECIPE_LEARNED", "TRADE_SKILL_LIST_UPDATE" }) do
        pcall(f.RegisterEvent, f, e)
    end
    local pending = false
    f:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        C_Timer.After(2, function()
            pending = false
            if shopWin and shopWin:IsShown() then SFP:Safe("recipe list", shopSearch, shopBox and shopBox:GetText() or ""); shopRefresh() end
        end)
    end)
end

-- an auction scan finished (or prices changed): redraw what shows prices
function SFP:PricesChanged()
    wipe(pcache); pcacheT = 0
    SFP._nameIdx = nil   -- the item names of the scan are indexed again when needed
    if SFP.API and SFP.API.Fire then pcall(SFP.API.Fire) end   -- other addons that registered a callback
    if SFP.GemHelper then SFP.GemHelper.ResetPrices() end
    -- the best 5 farm spots of each zone change once a week; only a choice made before any price was known is redone now
    local bs = SFP.db and SFP.db.bestSpots
    if bs and bs.priced == false then
        SFP.db.bestSpots = nil
        SFP._bestDone = nil
        for _, z in pairs(SFP.zoneByMap or {}) do z._areas, z._clusters = nil, nil end
        SFP.hiddenVer = (SFP.hiddenVer or 0) + 1
        if SFP.RefreshWorldMap then pcall(SFP.RefreshWorldMap) end
    end
    if SFP.TopSpotsChanged then pcall(SFP.TopSpotsChanged) end
    if shopWin and shopWin:IsShown() then shopRefresh() end
    local okM, _, cns = pcall(SFP_Module, "Codex")
    if okM and cns then
        cns.grindTime = nil
        if cns.LoadGrind then cns:LoadGrind() end
        if cns.RefreshList then cns:RefreshList(true) end
    end
end

function SFP:ShowShop()
    if not shopWin then
        local acc = 0
        shopWin = makeWindow("SeviathsUsefulToolsShop", "Recipe planner", 540, 740)
        shopWin.scroll:SetPoint("TOPLEFT", 12, -520)
        shopBox = CreateFrame("EditBox", nil, shopWin, "InputBoxTemplate")
        shopBox:SetSize(240, 22)
        shopBox:SetPoint("TOPLEFT", 22, -34)
        shopBox:SetAutoFocus(false)
        shopBox:SetScript("OnTextChanged", function(self) shopSearch(self:GetText()) end)
        shopBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local function bar(text, w, x, y, h, fn)
            local b = CreateFrame("Button", nil, shopWin, "UIPanelButtonTemplate")
            b:SetSize(w, h)
            b:SetPoint("TOPLEFT", x, y)
            b:SetText(text)
            b:SetScript("OnClick", fn)
            return b
        end
        bar("Add all shown", 110, 272, -34, 22, function()
            for _, key in ipairs(shopFound) do
                if not shopIndex(key) then shopData()[#shopData() + 1] = { key = key, qty = 1 } end
            end
            shopRefresh()
        end)
        bar("Remove all", 100, 386, -34, 22, function() wipe(shopData()); wipe(shopOff); shopRefresh() end)
        shopWin.tabs = {}
        shopResRows = SFP.MakeRowList(shopWin, 18, -152, 510, 128, 20)
        local label = shopWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 22, -290)
        label:SetText("Your list (saved)")
        local expl = shopWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        expl:SetPoint("TOPLEFT", 22, -308)
        expl:SetWidth(490)
        expl:SetJustifyH("LEFT")
        expl:SetText("|cffffd100Tick a recipe|r to show the reagents to buy for it below. Tick one for that recipe alone, several for those together, or press |cffffd100Tick all|r for everything on the list.")
        bar("Tick all", 70, 380, -286, 20, function() wipe(shopOff); shopRefresh() end)
        bar("Tick none", 70, 454, -286, 20, function()
            for _, e in ipairs(shopData()) do shopOff[e.key] = true end
            shopRefresh()
        end)
        shopRows = SFP.MakeRowList(shopWin, 18, -342, 510, 170, 20)
        -- prices come from the auction scans and from Auctionator / TSM: redraw every few seconds while it is open
        shopWin:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc >= 5 then acc = 0; shopRefresh() end
        end)
    end
    -- one tab per profession the addon knows recipes for, all visible at once (typing searches every profession)
    do
        -- every crafting profession gets a tab, learned or not; others the addon learned are added
        local names, seen = {}, {}
        for _, nm in ipairs({ "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering", "Inscription", "Jewelcrafting", "Leatherworking", "Tailoring" }) do
            seen[nm] = true; names[#names + 1] = nm
        end
        for _, rec in pairs(SFP.db.recipes or {}) do
            if rec.p and rec.p ~= "" and not seen[rec.p] then seen[rec.p] = true; names[#names + 1] = rec.p end
        end
        table.sort(names)
        table.insert(names, 1, false)
        names[#names + 1] = "@profit"   -- two switches that sit in the tab row
        names[#names + 1] = "@known"
        local function specialLabel(s)
            if s == "@profit" then return "Best profit: " .. (shopSortProfit and "ON" or "OFF") end
            return "My recipes only: " .. (shopKnownOnly and "ON" or "OFF")
        end
        local x, y = 22, -62
        for i, nm in ipairs(names) do
            local special = type(nm) == "string" and nm:sub(1, 1) == "@" and nm or nil
            local label = special and specialLabel(special) or (nm or "All")
            local width = math.max(54, #label * 7 + 16)
            if x + width > 520 then x, y = 22, y - 26 end
            local tb = shopWin.tabs[i]
            if not tb then
                tb = CreateFrame("Button", nil, shopWin, "UIPanelButtonTemplate")
                shopWin.tabs[i] = tb
            end
            tb:SetSize(width, 22)
            tb:ClearAllPoints()
            tb:SetPoint("TOPLEFT", x, y)
            tb.special = special
            tb.prof = (not special) and (nm or nil) or nil
            tb:SetText(label)
            tb:SetScript("OnClick", function(self)
                if self.special == "@profit" then
                    shopSortProfit = not shopSortProfit
                    self:SetText(specialLabel(self.special))
                elseif self.special == "@known" then
                    shopKnownOnly = not shopKnownOnly
                    self:SetText(specialLabel(self.special))
                else
                    shopProf = self.prof
                    for _, t in ipairs(shopWin.tabs) do t:SetEnabled(t.special or t.prof ~= shopProf) end
                end
                shopSearch(shopBox:GetText())
            end)
            tb:SetEnabled(tb.special and true or (tb.prof ~= shopProf))
            tb:Show()
            x = x + width + 4
        end
        for i = #names + 1, #shopWin.tabs do shopWin.tabs[i]:Hide() end
    end
    shopWin:Show()
    shopSearch(shopBox:GetText())   -- recipes learned since the last time show up
    shopRefresh()
end

-- open the planner on one profession, optionally with the best profit first (the button in the profession window)
function SFP:ShowShopFor(prof, bestProfit)
    shopProf = prof
    shopSortProfit = bestProfit and true or false
    self:ShowShop()
    for _, t in ipairs(shopWin.tabs) do
        if t.special == "@profit" then t:SetText("Best profit: " .. (shopSortProfit and "ON" or "OFF")) end
        if not t.special then t:SetEnabled(t.prof ~= shopProf) end
    end
    shopSearch(shopBox:GetText())
end

---------------------------------------------------------------------------
-- farm routes window: every spot of a zone to tick, any zone, build / clear the route
---------------------------------------------------------------------------
local rtWin
local rt = { map = nil, spots = {}, sel = {} }
local function rtKind(sp)
    return sp.gather and (sp.gather == "ore" and "mining" or "herbs") or (sp.rare and "rare") or (sp.hunter and "hunter tame") or (sp.special and "special") or "monsters"
end
local function rtTicked()
    local c = 0
    for _ in pairs(rt.sel) do c = c + 1 end
    return c
end
local function rtFillSpots()
    local q = (rtWin.spotBox:GetText() or ""):lower()
    local n = 0
    for _, sp in ipairs(rt.spots) do
        if q == "" or tostring(sp.name):lower():find(q, 1, true) then
            n = n + 1
            local r = rtWin.rows[n]
            if not r then
                r = CreateFrame("CheckButton", nil, rtWin.spotChild, "UICheckButtonTemplate")
                r:SetSize(22, 22)
                r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                r.label:SetPoint("LEFT", r, "RIGHT", 2, 0)
                r:SetScript("OnClick", function(self)
                    rt.sel[self.key] = self:GetChecked() and true or nil
                    rtWin.count:SetText(("%d of %d spots ticked"):format(rtTicked(), #rt.spots))
                end)
                rtWin.rows[n] = r
            end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", rtWin.spotChild, "TOPLEFT", 0, -(n - 1) * 22)
            r.key = SFP.SpotKey(sp)
            r:SetChecked(rt.sel[r.key] and true or false)
            r.label:SetText(("%s  |cff808080%s|r"):format(sp.name or "?", rtKind(sp)))
            r:Show()
        end
    end
    for i = n + 1, #rtWin.rows do rtWin.rows[i]:Hide() end
    rtWin.spotChild:SetHeight(n * 22 + 6)
    rtWin.count:SetText(("%d of %d spots ticked"):format(rtTicked(), #rt.spots))
end
local function rtSetZone(mapID)
    local zone = mapID and SFP.zoneByMap and SFP.zoneByMap[mapID]
    rt.map, rt.spots, rt.sel = mapID, {}, {}
    if zone then
        for _, sp in ipairs(zone.spawns or {}) do
            if sp.hx and sp.hy then rt.spots[#rt.spots + 1] = sp; rt.sel[SFP.SpotKey(sp)] = true end
        end
    end
    if mapID then
        local have = {}
        for _, sp in ipairs(rt.spots) do have[SFP.SpotKey(sp)] = true end
        -- the rares and hunter tames of the map (ticked), then every other monster of the zone to choose from (not ticked)
        for _, sp in ipairs((SFP.Rares and SFP.Rares[mapID]) or {}) do
            local x, y = tostring(sp.pts or ""):match("^([%d%.]+),([%d%.]+)")
            if x and not have[SFP.SpotKey(sp)] then
                have[SFP.SpotKey(sp)] = true
                local e = { name = sp.name, hx = tonumber(x) / 100, hy = tonumber(y) / 100, rare = (not sp.hunter) or nil, hunter = sp.hunter }
                rt.spots[#rt.spots + 1] = e
                rt.sel[SFP.SpotKey(e)] = true
            end
        end
        for _, id in ipairs(SFP:MonstersOnMap(mapID)) do
            local rec = SFP.Npc and SFP:Npc(id)
            local pts = type(rec) == "table" and type(rec.m) == "table" and rec.m[mapID]
            local p = type(pts) == "table" and pts[1]
            if type(rec) == "table" and rec.n and rec.t ~= "Critter" and type(p) == "table" and p[1] and not have["n|" .. rec.n] then
                have["n|" .. rec.n] = true
                rt.spots[#rt.spots + 1] = { name = rec.n, hx = p[1], hy = p[2], monster = true }
            end
        end
    end
    table.sort(rt.spots, function(a, b) return tostring(a.name) < tostring(b.name) end)
    rtWin.zoneText:SetText(zone and ("Zone: " .. SFP:ZoneName(mapID) .. "  |cff808080(" .. #rt.spots .. " spots and monsters to choose from)|r") or (#rt.spots > 0 and ("Zone: " .. SFP:ZoneName(mapID) .. "  |cff808080(" .. #rt.spots .. " monsters)|r") or "No farm spots here - pick a zone below."))
    rtWin.spotScroll:SetVerticalScroll(0)
    rtFillSpots()
end
local function rtFillZones()
    local q = (rtWin.zoneBox:GetText() or ""):lower()
    local n = 0
    for _, z in ipairs(SFP:RouteZones()) do
        if q == "" or z.name:lower():find(q, 1, true) or z.exp:lower():find(q, 1, true) then
            n = n + 1
            local b = rtWin.zrows[n]
            if not b then
                b = CreateFrame("Button", nil, rtWin.zChild, "UIPanelButtonTemplate")
                b:SetSize(470, 20)
                b:SetScript("OnClick", function(self) if self.zone then rtSetZone(self.zone.map) end end)
                rtWin.zrows[n] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", rtWin.zChild, "TOPLEFT", 0, -(n - 1) * 22)
            b.zone = z
            b:SetText(("%s   |cff808080%s - %d spots|r"):format(z.name, z.exp, z.count))
            b:Show()
        end
    end
    for i = n + 1, #rtWin.zrows do rtWin.zrows[i]:Hide() end
    rtWin.zChild:SetHeight(n * 22 + 6)
end
local function rtButton(text, w, x, y, fn)
    local b = CreateFrame("Button", nil, rtWin, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", fn)
    return b
end
local function rtScroll(y, h)
    local sf = CreateFrame("ScrollFrame", nil, rtWin, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 14, y)
    sf:SetSize(490, h)
    local c = CreateFrame("Frame", nil, sf)
    c:SetSize(480, 10)
    sf:SetScrollChild(c)
    return sf, c
end
function SFP:ShowRouteWindow()
    if not rtWin then
        rtWin = makeWindow("SeviathsUsefulToolsRoutes", "Farm routes", 540, 640)
        rtWin.scroll:Hide()
        rtWin.rows, rtWin.zrows = {}, {}
        rtWin.zoneText = rtWin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rtWin.zoneText:SetPoint("TOPLEFT", 14, -34)
        rtButton("Use the zone I am in", 150, 360, -30, function() rtSetZone(SFP:PlayerFarmZone()) end)
        local l1 = rtWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l1:SetPoint("TOPLEFT", 14, -62)
        l1:SetText("Search spots:")
        rtWin.spotBox = CreateFrame("EditBox", nil, rtWin, "InputBoxTemplate")
        rtWin.spotBox:SetSize(200, 20)
        rtWin.spotBox:SetPoint("TOPLEFT", 100, -58)
        rtWin.spotBox:SetAutoFocus(false)
        rtWin.spotBox:SetScript("OnTextChanged", rtFillSpots)
        rtWin.spotBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        rtWin.count = rtWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rtWin.count:SetPoint("TOPLEFT", 320, -62)
        rtWin.spotScroll, rtWin.spotChild = rtScroll(-84, 290)
        rtButton("Select all", 100, 14, -382, function()
            local q = (rtWin.spotBox:GetText() or ""):lower()
            for _, sp in ipairs(rt.spots) do
                if q == "" or tostring(sp.name):lower():find(q, 1, true) then rt.sel[SFP.SpotKey(sp)] = true end
            end
            rtFillSpots()
        end)
        rtButton("Select none", 100, 118, -382, function() wipe(rt.sel); rtFillSpots() end)
        rtButton("Build route", 120, 222, -382, function()
            if not rt.map then return end
            if SFP.OpenMapTo then SFP:OpenMapTo(rt.map) end
            SFP:BuildRoute(rt.map, rt.sel)
        end)
        rtButton("Clear route", 100, 346, -382, function() SFP:ClearRoute() end)
        local l2 = rtWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        l2:SetPoint("TOPLEFT", 14, -418)
        l2:SetText("Another zone (any expansion):")
        rtWin.zoneBox = CreateFrame("EditBox", nil, rtWin, "InputBoxTemplate")
        rtWin.zoneBox:SetSize(200, 20)
        rtWin.zoneBox:SetPoint("TOPLEFT", 220, -414)
        rtWin.zoneBox:SetAutoFocus(false)
        rtWin.zoneBox:SetScript("OnTextChanged", rtFillZones)
        rtWin.zoneBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        rtWin.zScroll, rtWin.zChild = rtScroll(-440, 190)
        rtFillZones()
        rtSetZone(SFP:PlayerFarmZone())
    end
    rtWin:Show()
end

---------------------------------------------------------------------------
-- what to farm next: all rares you still miss something from, by zone, tick and route
---------------------------------------------------------------------------
local nxWin
local nx = { zone = nil, list = {}, sel = {} }
local function nxKey(c) return tostring(c.map) .. ":" .. tostring(c.sp.name) end

local function nxFill()
    local rows = {}
    local n = 0
    for _, c in ipairs(nx.list) do
        if not nx.zone or c.map == nx.zone then
            n = n + 1
            local r = nxWin.rows[n]
            if not r then
                r = CreateFrame("Frame", nil, nxWin.child)
                r:SetSize(400, 36)
                r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
                r.check:SetSize(22, 22)
                r.check:SetPoint("TOPLEFT", 0, -2)
                r.check:SetScript("OnClick", function(self) nx.sel[r.key] = self:GetChecked() and true or nil end)
                r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                r.text:SetPoint("TOPLEFT", 26, -2)
                r.text:SetWidth(300)
                r.text:SetJustifyH("LEFT")
                r.btn = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
                r.btn:SetSize(70, 20)
                r.btn:SetPoint("TOPRIGHT", 0, -4)
                r.btn:SetText("Waypoint")
                nxWin.rows[n] = r
            end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", nxWin.child, "TOPLEFT", 0, -(n - 1) * 38)
            r.key = nxKey(c)
            r.check:SetChecked(nx.sel[r.key] and true or false)
            local names = {}
            for _, id in ipairs(c.missing) do names[#names + 1] = SFP:ItemName(id) end
            r.text:SetText(("|cffffd100%s|r  %s%s%s\n|cff808080missing:|r %s"):format(c.sp.name, SFP:ZoneName(c.map),
                c.dist and ("  " .. ("%.0f"):format(c.dist * 100) .. " away") or "", c.killed and "  |cff808080killed today|r" or "", table.concat(names, ", ")))
            r.btn:SetScript("OnClick", function() if c.sp.hx then SFP:SetWaypoint(c.map, c.sp.hx, c.sp.hy, c.sp.name) end end)
            r:Show()
        end
    end
    for i = n + 1, #nxWin.rows do nxWin.rows[i]:Hide() end
    nxWin.child:SetHeight(n * 38 + 6)
end

local function nxZones()
    local counts, order = {}, {}
    for _, c in ipairs(nx.list) do
        if not counts[c.map] then counts[c.map] = 0; order[#order + 1] = c.map end
        counts[c.map] = counts[c.map] + 1
    end
    table.sort(order, function(a, b) return counts[a] > counts[b] end)
    local items = { { text = "", buttons = { { (nx.zone == nil and "|cff40ff40" or "") .. "All zones (" .. #nx.list .. ")", 150, function() nx.zone = nil; nxFill() end } } } }
    for _, m in ipairs(order) do
        items[#items + 1] = { text = "", buttons = { { (nx.zone == m and "|cff40ff40" or "") .. SFP:ZoneName(m) .. " (" .. counts[m] .. ")", 150, function() nx.zone = m; nxFill() end } } }
    end
    nxWin.zones:Set(items)
end

local function nxReload()
    local mode = SFP.db.nextSort or "best"
    nx.list = SFP:FarmNext(100000, mode)
    nxWin.sortBtn:SetText(mode == "best" and "Sorted: best first" or "Sorted: nearest first")
    nxZones()
    nxFill()
end

function SFP:ShowNextWindow()
    if not nxWin then
        nxWin = makeWindow("SeviathsUsefulToolsNext", "What to farm next - all rares you miss something from", 640, 600)
        nxWin.scroll:Hide()
        nxWin.rows = {}
        nxWin.sortBtn = CreateFrame("Button", nil, nxWin, "UIPanelButtonTemplate")
        nxWin.sortBtn:SetSize(160, 22)
        nxWin.sortBtn:SetPoint("TOPLEFT", 14, -34)
        nxWin.sortBtn:SetScript("OnClick", function()
            SFP.db.nextSort = (SFP.db.nextSort or "best") == "best" and "near" or "best"
            nxReload()
        end)
        local function btn(text, w, x, fn)
            local b = CreateFrame("Button", nil, nxWin, "UIPanelButtonTemplate")
            b:SetSize(w, 22)
            b:SetPoint("TOPLEFT", x, -34)
            b:SetText(text)
            b:SetScript("OnClick", fn)
            return b
        end
        btn("Select all shown", 120, 184, function()
            for _, c in ipairs(nx.list) do if not nx.zone or c.map == nx.zone then nx.sel[nxKey(c)] = true end end
            nxFill()
        end)
        btn("Select none", 90, 308, function() wipe(nx.sel); nxFill() end)
        btn("Build route", 100, 402, function()
            local byMap, bestMap, bestN = {}, nil, 0
            for _, c in ipairs(nx.list) do
                if nx.sel[nxKey(c)] and c.sp.hx then
                    byMap[c.map] = byMap[c.map] or {}
                    table.insert(byMap[c.map], { name = c.sp.name, x = c.sp.hx, y = c.sp.hy })
                    if #byMap[c.map] > bestN then bestMap, bestN = c.map, #byMap[c.map] end
                end
            end
            if not bestMap then SFP:Print("Tick at least two rares in one zone first."); return end
            if SFP.OpenMapTo then SFP:OpenMapTo(bestMap) end
            SFP:RouteFromSpots(bestMap, byMap[bestMap])
        end)
        btn("Clear route", 90, 508, function() SFP:ClearRoute() end)
        local zs = nxWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        zs:SetPoint("TOPLEFT", 14, -66)
        zs:SetText("Zones (pick one):")
        nxWin.zones = SFP.MakeRowList(nxWin, 10, -82, 176, 500, 24)
        local sf = CreateFrame("ScrollFrame", nil, nxWin, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 200, -70)
        sf:SetSize(400, 512)
        nxWin.child = CreateFrame("Frame", nil, sf)
        nxWin.child:SetSize(400, 10)
        sf:SetScrollChild(nxWin.child)
    end
    nxWin:Show()
    nxReload()
end

SFP.MakeToolWindow = makeWindow
