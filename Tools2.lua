-- SeviathsUsefulTools - more tools
--   alts     : account overview (level, item level, gold, professions, weekly activities)
--   keys     : delve keys and bountiful delves
--   planner  : delve companion role, curio hints and the tier you are comfortable with
--   ach      : achievement planner (what is left, where, what first)
--   zone     : "missing here" line when you enter a zone or an instance
--   decor    : Midnight housing decor you can craft, and which recipes you know
-- Reads the game and the addon's own data only. Everything is wrapped so a missing game function just shows nothing.

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
local function charKey()
    return (UnitName("player") or "?") .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or "?"):gsub("[%s%-']", ""))
end
local function window(name, title, w, h) return SFP.MakeToolWindow(name, title, w, h) end

---------------------------------------------------------------------------
-- 11. account-wide alt overview
---------------------------------------------------------------------------
-- older saves could store the realm with spaces ("Argent Dawn") when the game had not given its short name yet:
-- fold those into the normal key, keeping the newer record
local function mergeCharKeys(tbl, stamp)
    if type(tbl) ~= "table" then return end
    local moves = {}
    for k in pairs(tbl) do
        local name, realm = k:match("^(.-)%-(.+)$")
        if realm and realm:find("[%s%-']") then moves[#moves + 1] = { k, name .. "-" .. realm:gsub("[%s%-']", "") } end
    end
    for _, m in ipairs(moves) do
        local from, to = m[1], m[2]
        local a, b = tbl[from], tbl[to]
        if not b or (type(a) == "table" and type(b) == "table" and (a[stamp] or 0) > (b[stamp] or 0)) then tbl[to] = a end
        tbl[from] = nil
    end
end

function SFP:UpdateAlt()
    if not self.db then return end
    mergeCharKeys(self.db.alts, "t")
    mergeCharKeys(self.db.weekly, "t")
    mergeCharKeys(self.db.killed, "t")
    if self.db.altSel and self.db.altSel:find("%s") then self.db.altSel = nil end
    local rec = { t = time(), level = UnitLevel("player"), money = GetMoney(), profs = {} }
    -- both names of the character (first name and surname; the game gives the surname where other games have the realm)
    do
        local n, s = UnitName("player")
        if type(n) == "string" then
            rec.full = (type(s) == "string" and s ~= "" and not s:find("Realm") and not s:find("CAMWOW")) and (n .. " " .. s) or n
        end
    end
    local _, class = UnitClass("player")
    rec.class = class
    local okI, _, equipped = pcall(GetAverageItemLevel)
    rec.ilvl = okI and equipped and math.floor(equipped + 0.5) or nil
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex and GetSpecializationInfo then
        local _, specName = GetSpecializationInfo(specIndex)
        rec.spec = specName
    end
    if GetProfessions and GetProfessionInfo then
        for _, idx in ipairs({ GetProfessions() }) do
            if idx then
                local ok, name, _, rank, maxRank = pcall(GetProfessionInfo, idx)
                if ok and type(name) == "string" and not secret(name) then rec.profs[#rec.profs + 1] = ("%s %d/%d"):format(name, rank or 0, maxRank or 0) end
            end
        end
    end
    -- Classic style skill list (WoW Forever): the professions are skill lines with a rank
    if #rec.profs == 0 and GetNumSkillLines and GetSkillLineInfo then
        local PROFS = { Alchemy = 1, Blacksmithing = 1, Enchanting = 1, Engineering = 1, Herbalism = 1, Leatherworking = 1, Mining = 1, Skinning = 1, Tailoring = 1,
            Cooking = 1, ["First Aid"] = 1, Fishing = 1, Jewelcrafting = 1 }
        for i = 1, (GetNumSkillLines() or 0) do
            local ok, name, isHeader, _, rank, _, _, maxRank = pcall(GetSkillLineInfo, i)
            if ok and type(name) == "string" and not isHeader and PROFS[name] and not secret(name) then
                rec.profs[#rec.profs + 1] = ("%s %d/%d"):format(name, tonumber(rank) or 0, tonumber(maxRank) or 0)
            end
        end
    end
    -- the specialization of this game: the Talent Advisor's own detection
    if not rec.spec and SFP.TalentAdvisor and SFP.TalentAdvisor.DetectedSpec then
        local okS, sp = pcall(SFP.TalentAdvisor.DetectedSpec)
        if okS and type(sp) == "string" then rec.spec = sp end
    end
    self.db.alts = self.db.alts or {}
    local old = self.db.alts[charKey()]
    if old then rec.bags, rec.bagsT, rec.bank, rec.bankT = old.bags, old.bagsT, old.bank, old.bankT end
    self.db.alts[charKey()] = rec
end

-- what is in the bags: { [itemID] = count }, read from the given bag slots
local function readBags(ids)
    local counts, any = {}, false
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return counts, false end
    for _, bag in ipairs(ids) do
        local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
        if okN and type(n) == "number" and n > 0 then
            any = true
            for slot = 1, n do
                local okI, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
                if okI and type(info) == "table" and info.itemID and not secret(info.itemID) then
                    counts[info.itemID] = (counts[info.itemID] or 0) + (tonumber(info.stackCount) or 1)
                end
            end
        end
    end
    return counts, any
end

local function bagIDs(kind)
    local first, prefix, n
    if kind == "bags" then return { 0, 1, 2, 3, 4, 5 } end
    if kind == "bank" then first, prefix, n = 6, "CharacterBankTab_", 6 else first, prefix, n = 12, "AccountBankTab_", 5 end
    local ids = {}
    for i = 1, n do
        ids[#ids + 1] = (Enum and Enum.BagIndex and Enum.BagIndex[prefix .. i]) or (first + i - 1)
    end
    return ids
end

local bankOpen = false

-- bags are read all the time; the bank and the warband bank only while the bank window is open
function SFP:SnapshotBags()
    if not self.db then return end
    local key = charKey()
    self.db.alts = self.db.alts or {}
    if not self.db.alts[key] then self:UpdateAlt() end
    local rec = self.db.alts[key]
    if not rec then return end
    rec.bags, rec.bagsT = readBags(bagIDs("bags")), time()
    if bankOpen then
        local cb, anyC = readBags(bagIDs("bank"))
        if anyC then rec.bank, rec.bankT = cb, time() end
        local wb, anyW = readBags(bagIDs("warband"))
        if anyW then
            self.db.warband = self.db.warband or {}
            self.db.warband.items, self.db.warband.t = wb, time()
        end
        if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType then
            local okM, m = pcall(C_Bank.FetchDepositedMoney, Enum.BankType.Account)
            if okM and type(m) == "number" and not secret(m) then
                self.db.warband = self.db.warband or {}
                self.db.warband.money = m
            end
        end
    end
end

local altWin, altRows, altBox, altItems
local altView = "overview"
-- the Warband bank tab is left out while the game has no Warband bank (WoW Forever; the code stays for a later version)
local HAS_WARBAND = not (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
local ALT_VIEWS = { { "overview", "Overview", 80 }, { "bags", "Bags", 60 }, { "bank", "Bank", 60 }, { "warband", "Warband bank", 100 }, { "gold", "All gold", 80 } }
if not HAS_WARBAND then
    for i = #ALT_VIEWS, 1, -1 do if ALT_VIEWS[i][1] == "warband" then table.remove(ALT_VIEWS, i) end end
end
local altViewBtns = {}

local function ago(t)
    if not t then return "never" end
    local m = math.floor((time() - t) / 60)
    if m < 1 then return "just now" end
    if m < 120 then return m .. " min ago" end
    if m < 2880 then return math.floor(m / 60) .. " h ago" end
    return math.floor(m / 1440) .. " days ago"
end

local function itemLines(counts, filter)
    local list, distinct, value = {}, 0, 0
    for id, cnt in pairs(counts or {}) do
        distinct = distinct + 1
        local unit = SFP:GetPrice(id) or 0
        value = value + unit * cnt
        local name = SFP:ItemName(id)
        local plain = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
        if filter == "" or plain:find(filter, 1, true) then list[#list + 1] = { name = name, plain = plain, cnt = cnt, unit = unit } end
    end
    table.sort(list, function(x, y) return x.plain < y.plain end)
    local lines = {}
    for i = 1, math.min(150, #list) do
        local e = list[i]
        lines[#lines + 1] = ("%dx %s%s"):format(e.cnt, e.name, e.unit > 0 and ("  |cff808080" .. money(e.unit) .. " each|r") or "")
    end
    if #list > 150 then lines[#lines + 1] = ("|cff808080+%d more - type part of a name in the search box|r"):format(#list - 150) end
    if #list == 0 then lines[1] = filter ~= "" and "Nothing matches the search." or "Empty." end
    return lines, distinct, value
end

local function altSelected()
    local db = SFP.db
    local keys = {}
    for k in pairs(db.alts or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    if not (db.altSel and db.alts and db.alts[db.altSel]) then
        db.altSel = (db.alts and db.alts[charKey()]) and charKey() or keys[1]
    end
    return db.altSel, keys
end

-- the name to show for a character of the list: both names when it has logged in with this version, else the first name
local function altName(key, rec)
    if type(rec) == "table" and type(rec.full) == "string" and rec.full ~= "" then return rec.full end
    return key:match("^([^-]+)") or key
end

local function altContent(key)
    local db = SFP.db
    local r = key and db.alts and db.alts[key]
    local filter = (altBox and altBox:GetText() or ""):lower()
    local lines = {}
    if altView == "gold" then
        local rows, total = {}, 0
        for k, rec in pairs(db.alts or {}) do rows[#rows + 1] = { k = k, m = rec.money or 0 }; total = total + (rec.money or 0) end
        table.sort(rows, function(x, y) return x.m > y.m end)
        lines[1] = "|cffffd100Gold on every character|r"
        for _, e in ipairs(rows) do lines[#lines + 1] = ("%s   %s"):format(altName(e.k, db.alts[e.k]), money(e.m)) end
        local wb = db.warband and db.warband.money
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Characters together: " .. money(total)
        if HAS_WARBAND then
            lines[#lines + 1] = "Warband bank: " .. (wb and money(wb) or "|cff808080not read yet - open the bank once|r")
            lines[#lines + 1] = "|cffffd100Together: " .. money(total + (wb or 0)) .. "|r"
        end
        return table.concat(lines, "\n")
    end
    if altView == "warband" then
        local w = db.warband
        lines[1] = "|cffffd100Warband bank (shared by all your characters)|r"
        if not (w and w.items) then
            lines[2] = "Not read yet. Open your bank (the Warband tabs) with any character once: the addon saves what is in it."
        else
            local list, distinct, value = itemLines(w.items, filter)
            lines[2] = ("|cff808080Read %s. %d different items worth about %s. Gold in it: %s.|r"):format(ago(w.t), distinct, money(value), w.money and money(w.money) or "?")
            lines[3] = ""
            for _, l in ipairs(list) do lines[#lines + 1] = l end
        end
        return table.concat(lines, "\n")
    end
    if not r then return "No character saved yet. Log in with each character once." end
    local short = key:match("^([^-]+)") or key
    if altView == "bags" or altView == "bank" then
        local data = altView == "bags" and r.bags or r.bank
        lines[1] = ("|cffffd100%s - %s|r"):format(altName(key, r), altView == "bags" and "bags" or "character bank")
        if not data then
            lines[2] = altView == "bags" and ("Not read yet. Log in with " .. short .. " once.") or
                ("Not read yet. Open the bank with " .. short .. " once: the addon saves what is in it.")
        else
            local list, distinct, value = itemLines(data, filter)
            lines[2] = ("|cff808080Read %s. %d different items worth about %s.|r"):format(ago(altView == "bags" and r.bagsT or r.bankT), distinct, money(value))
            lines[3] = ""
            for _, l in ipairs(list) do lines[#lines + 1] = l end
        end
        return table.concat(lines, "\n")
    end
    -- overview
    local age = math.floor((time() - (r.t or 0)) / 3600)
    lines[#lines + 1] = ("|cffffd100%s|r  |cff808080(%s)|r"):format(altName(key, r), age < 1 and "now" or (age .. " h ago"))
    lines[#lines + 1] = ("Level %s %s %s"):format(tostring(r.level or "?"), r.spec or "", r.class or "")
    lines[#lines + 1] = ("Item level %s     Gold %s"):format(tostring(r.ilvl or "?"), money(r.money))
    lines[#lines + 1] = "Professions: " .. (#(r.profs or {}) > 0 and table.concat(r.profs, ", ") or "none")
    local w = db.weekly and db.weekly[key]
    if w then
        lines[#lines + 1] = "Weekly: " .. (#w.vault > 0 and ("Great Vault " .. table.concat(w.vault, " ") .. "   ") or "") ..
            "Raid lockouts: " .. (#w.locks > 0 and #w.locks or "none") .. "   Rares today: " .. (w.rares or 0)
    end
    local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("Bags: %s   Bank: %s"):format(r.bags and (count(r.bags) .. " different items, read " .. ago(r.bagsT)) or "not read yet",
        r.bank and (count(r.bank) .. " different items, read " .. ago(r.bankT)) or "not read yet (open the bank once)")
    if HAS_WARBAND then
        lines[#lines + 1] = "Warband bank: " .. ((db.warband and db.warband.items) and (count(db.warband.items) .. " different items, " .. (db.warband.money and money(db.warband.money) or "?") .. " gold") or "not read yet")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cff808080A character shows here after you log in with it. Use the buttons above to see its bags, bank and everybody's gold. Profession cooldowns are not shown.|r"
    return table.concat(lines, "\n")
end

local function altRefresh()
    if not altWin or not altWin:IsShown() then return end
    SFP:UpdateAlt()
    SFP:SnapshotBags()
    if SFP.UpdateWeekly then pcall(SFP.UpdateWeekly, SFP) end
    local sel, keys = altSelected()
    local items = {}
    for _, k in ipairs(keys) do
        local rec = SFP.db.alts[k]
        local label = (k == sel and "|cff40ff40> |r" or "") .. altName(k, rec) .. (rec.level and (" " .. rec.level) or "")
        items[#items + 1] = { text = "", buttons = { { label, 224, function() SFP.db.altSel = k; altRefresh() end } } }
    end
    altRows:Set(items)
    for _, bt in ipairs(altViewBtns) do bt:SetText((bt.view == altView and "|cff40ff40" or "") .. bt.label) end
    local r = sel and SFP.db.alts[sel]
    if (altView == "bags" or altView == "bank") and r then
        -- the items of the bags or the bank as rows, each with its tooltip on hover
        local data = altView == "bags" and r.bags or r.bank
        altWin.scroll:Hide()
        altItems.scroll:Show()
        local head = {}
        if not data then
            head[1] = { text = altView == "bags" and "Not read yet. Log in with this character once." or "Not read yet. Open the bank with this character once." }
            altItems:Set(head)
        else
            local filter = (altBox and altBox:GetText() or ""):lower()
            local list, value = {}, 0
            for id, cnt in pairs(data) do
                local name = SFP:ItemName(id)
                local plain = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
                local unit = SFP:GetPrice(id) or 0
                value = value + unit * cnt
                if filter == "" or plain:find(filter, 1, true) then list[#list + 1] = { id = id, name = name, plain = plain, cnt = cnt, unit = unit } end
            end
            table.sort(list, function(x, y) return x.plain < y.plain end)
            local rows = { { text = ("|cff808080Read %s. %d different items worth about %s.|r"):format(ago(altView == "bags" and r.bagsT or r.bankT), #list, money(value)) } }
            for _, e in ipairs(list) do
                local id = e.id
                rows[#rows + 1] = { text = ("%dx %s%s"):format(e.cnt, e.name, e.unit > 0 and ("  |cff808080" .. money(e.unit) .. " each|r") or ""),
                    tip = function(tt) tt:SetItemByID(id) end }
            end
            if #list == 0 then rows[#rows + 1] = { text = filter ~= "" and "Nothing matches the search." or "Empty." } end
            altItems:Set(rows)
        end
    else
        if altItems then altItems.scroll:Hide() end
        altWin.scroll:Show()
        altWin:SetContent(altContent(sel))
    end
end

function SFP:ShowAlts()
    self:UpdateAlt()
    self:SnapshotBags()
    if not altWin then
        altWin = window("SeviathsUsefulToolsAlts", "Alt overview - all your characters", 880, 680)
        altWin.scroll:ClearAllPoints()
        altWin.scroll:SetPoint("TOPLEFT", 270, -94)
        altWin.scroll:SetPoint("BOTTOMRIGHT", -30, 12)
        altWin.child:SetWidth(540)
        altWin.text:SetWidth(536)
        local lbl = altWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", 14, -36)
        lbl:SetText("Characters:")
        altRows = SFP.MakeRowList(altWin, 10, -52, 256, 600, 26)
        altItems = SFP.MakeRowList(altWin, 264, -92, 590, 570, 24)
        altItems.scroll:Hide()
        local x = 270
        for _, v in ipairs(ALT_VIEWS) do
            local bt = CreateFrame("Button", nil, altWin, "UIPanelButtonTemplate")
            bt:SetSize(v[3], 22)
            bt:SetPoint("TOPLEFT", x, -34)
            bt.view, bt.label = v[1], v[2]
            bt:SetText(v[2])
            bt:SetScript("OnClick", function() altView = v[1]; altRefresh() end)
            altViewBtns[#altViewBtns + 1] = bt
            x = x + v[3] + 4
        end
        local sl = altWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sl:SetPoint("TOPLEFT", 274, -68)
        sl:SetText("Search items:")
        altBox = CreateFrame("EditBox", nil, altWin, "InputBoxTemplate")
        altBox:SetSize(220, 20)
        altBox:SetPoint("TOPLEFT", 360, -64)
        altBox:SetAutoFocus(false)
        altBox:SetScript("OnTextChanged", function() altRefresh() end)
        altBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local acc = 0
        altWin:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc < 3 then return end
            acc = 0
            SFP:Safe("alt window", altRefresh)
        end)
    end
    altWin:Show()
    altRefresh()
end

local af = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "TRADE_SKILL_LIST_UPDATE", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }) do pcall(af.RegisterEvent, af, e) end
local altTimer, bagTimer
local function isBankType(t)
    local P = Enum and Enum.PlayerInteractionType
    return P and t and (t == P.Banker or t == P.AccountBanker)
end
af:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGOUT" then
        SFP:Safe("alt", SFP.UpdateAlt, SFP)
        SFP:Safe("bags", SFP.SnapshotBags, SFP)
        return
    end
    if event == "BANKFRAME_OPENED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and isBankType(arg1)) then
        bankOpen = true
        C_Timer.After(1.5, function() SFP:Safe("bank", SFP.SnapshotBags, SFP) end)
        return
    end
    if event == "BANKFRAME_CLOSED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and isBankType(arg1)) then
        SFP:Safe("bank", SFP.SnapshotBags, SFP)   -- the last look before it closes
        bankOpen = false
        return
    end
    if event == "BAG_UPDATE_DELAYED" then
        if bagTimer then return end
        bagTimer = true
        C_Timer.After(3, function() bagTimer = nil; SFP:Safe("bags", SFP.SnapshotBags, SFP) end)
        return
    end
    if altTimer then return end
    altTimer = true
    C_Timer.After(10, function()
        altTimer = nil
        SFP:Safe("alt", SFP.UpdateAlt, SFP)
        SFP:Safe("bags", SFP.SnapshotBags, SFP)
    end)
end)

---------------------------------------------------------------------------
-- 6. delve keys and bountiful delves
---------------------------------------------------------------------------
-- the 10 best farm spots of the game by auction house prices, live: it refreshes itself every few seconds and after each scan
local topWin, topList, topTicker
local function topSpots()
    local out = {}
    for mapID, zone in pairs(SFP.zoneByMap or {}) do
        for _, s in ipairs(zone.spawns or {}) do
            if s.hx and not (s.gather or s.rare or s.special or s.hunter) and s.items and #s.items > 0 then
                local v = 0
                for _, id in ipairs(s.items) do v = v + (SFP:GetPrice(id) or 0) end
                if v > 0 then out[#out + 1] = { s = s, map = mapID, v = v } end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.v ~= b.v then return a.v > b.v end
        return tostring(a.s.name) < tostring(b.s.name)
    end)
    local top, seen = {}, {}
    for _, e in ipairs(out) do
        local k = tostring(e.s.name) .. "|" .. e.map
        if not seen[k] then
            seen[k] = true
            top[#top + 1] = e
            if #top >= 10 then break end
        end
    end
    return top
end

local function topRefresh()
    if not (topWin and topWin:IsShown()) then return end
    local items = {}
    for i, e in ipairs(topSpots()) do
        items[i] = {
            text = ("%d. |cffffd100%s|r  |cff808080%s|r  %s"):format(i, tostring(e.s.name), SFP:ZoneName(e.map), SFP:FormatPrice(e.v)),
            buttons = { { "Waypoint", 70, function() SFP:SetWaypoint(e.map, e.s.hx, e.s.hy, e.s.name) end } },
        }
    end
    if #items == 0 then items[1] = { text = "|cff808080No auction prices yet - scan the auction house once.|r", buttons = {} } end
    topList:Set(items)
end

function SFP:ShowTopSpots()
    if not topWin then
        topWin = window("SeviathsUsefulToolsTopSpots", "The 10 best farm spots (auction house prices)", 520, 300)
        topWin.scroll:Hide()
        local info = topWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        info:SetPoint("TOPLEFT", 14, -32)
        info:SetWidth(490)
        info:SetJustifyH("LEFT")
        info:SetText("Worth = what the items of one monster sell for. It updates by itself with the auction prices. Waypoint: go to the spot.")
        topList = SFP.MakeRowList(topWin, 10, -64, 500, 226, 20)
        topWin:SetScript("OnShow", function()
            topRefresh()
            if topTicker then topTicker:Cancel() end
            topTicker = C_Timer.NewTicker(5, topRefresh)
        end)
        topWin:SetScript("OnHide", function() if topTicker then topTicker:Cancel(); topTicker = nil end end)
    end
    topWin:Show()
    topRefresh()
end
function SFP:TopSpotsChanged() topRefresh() end

local DELVE_MAPS = { 2248, 2214, 2215, 2255, 2395, 2437, 2413, 2405, 2393 }

local function keyCurrencies()
    local out = {}
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize) then return out end
    for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyListInfo, i)
        if ok and type(info) == "table" and not info.isHeader and type(info.name) == "string" and not secret(info.name) then
            local n = info.name:lower()
            if n:find("key") or n:find("delve") or n:find("bountiful") then out[#out + 1] = info end
        end
    end
    return out
end

local function bountiful()
    local out = {}
    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetDelvesForMap and C_AreaPoiInfo.GetAreaPOIInfo) then return nil end
    for _, mapID in ipairs(DELVE_MAPS) do
        local ok, ids = pcall(C_AreaPoiInfo.GetDelvesForMap, mapID)
        if ok and type(ids) == "table" then
            for _, poiID in ipairs(ids) do
                local ok2, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
                if ok2 and type(info) == "table" and type(info.atlasName) == "string" and info.atlasName:lower():find("bountiful") then
                    out[#out + 1] = { name = info.name or "?", zone = SFP:ZoneName(mapID) }
                end
            end
        end
    end
    return out
end

local keyWin, keyRares
function SFP:ShowKeys()
    if not keyWin then
        keyWin = window("SeviathsUsefulToolsKeys", "Delve keys and bountiful delves", 480, 650)
        keyWin.scroll:SetPoint("BOTTOMRIGHT", -30, 330)
        local rl = keyWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rl:SetPoint("TOPLEFT", 14, -326)
        rl:SetText("Rares of the Midnight zones (50 shards each): press Waypoint for the nearest spot")
        keyRares = SFP.MakeRowList(keyWin, 10, -346, 460, 296, 20)
    end
    local lines = { "|cffffd100Keys and delve currencies|r" }
    local cur = keyCurrencies()
    for _, c in ipairs(cur) do
        local week = (c.canEarnPerWeek and c.maxWeeklyQuantity and c.maxWeeklyQuantity > 0)
            and ("   this week %d/%d"):format(c.quantityEarnedThisWeek or 0, c.maxWeeklyQuantity) or ""
        lines[#lines + 1] = ("  %s: %d%s"):format(c.name, c.quantity or 0, week)
    end
    if #cur == 0 then lines[#lines + 1] = "  none found (open the currency tab once, or you have none yet)" end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cffffd100Bountiful delves today|r"
    local b = bountiful()
    if b == nil then
        lines[#lines + 1] = "  This game version does not tell addons which delves are bountiful. Open the map: they have the golden delve icon."
    elseif #b == 0 then
        lines[#lines + 1] = "  none found on the maps the addon checks (open the zone maps once so the game loads them)"
    else
        for _, d in ipairs(b) do lines[#lines + 1] = ("  %s - %s"):format(d.name, d.zone) end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cffffd100How keys work|r"
    lines[#lines + 1] = "  - A bountiful delve gives a Bountiful Coffer at the end; opening it needs one Restored Coffer Key."
    lines[#lines + 1] = "  - 100 Coffer Key Shards make 1 key. The conversion happens by itself when you enter a delve, or by talking to Naleidea Rivergleam."
    lines[#lines + 1] = "  - You can earn up to 600 shards a week (6 keys). Shards over the limit are lost, so spend keys before the next reset."
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cffffd100Where to get shards (activity - amount)|r"
    lines[#lines + 1] = "  - Delver's Starter Kit (one time only) - 200"
    lines[#lines + 1] = "  - Prey hunt quests - 75 each (Astalor Bloodsworn, Silvermoon)"
    lines[#lines + 1] = "  - Rares in the Midnight zones - 50 each (list below)"
    lines[#lines + 1] = "  - World quests that offer shards as a reward - 50 each (look at the reward on the map)"
    lines[#lines + 1] = "  - Weekly zone events such as Abundance and Saltheril's Soiree - a chest with shards"
    lines[#lines + 1] = "  - Treasures in the Midnight zones - about 5 each"
    lines[#lines + 1] = "  - Void Motes - 1 each"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "|cffffd100Where to buy keys|r"
    lines[#lines + 1] = "  - Naleidea Rivergleam, Delver's Headquarters, Silvermoon City: sells Restored Coffer Keys (a small number per week, with Undercoin, once you have ranked up the Delver's Journey)."
    lines[#lines + 1] = "|cff808080Amounts come from the Warcraft Wiki and a Midnight Season 2 key guide; they can change with patches. The addon could not verify them in the game.|r"
    -- rares of the Midnight zones, from the addon's own data: a list with a waypoint button for each
    local rareItems, zones = {}, {}
    for mapID, list in pairs(SFP.Rares or {}) do
        if type(list) == "table" and list.exp == "midnight" then zones[#zones + 1] = { map = mapID, zn = SFP:ZoneName(mapID), list = list } end
    end
    table.sort(zones, function(p1, p2) return p1.zn < p2.zn end)
    for _, z in ipairs(zones) do
        local rows = {}
        for _, sp in ipairs(z.list) do
            if sp.name then rows[#rows + 1] = sp end
        end
        table.sort(rows, function(p1, p2) return p1.name < p2.name end)
        if #rows > 0 then
            rareItems[#rareItems + 1] = { text = "|cffffd100" .. z.zn .. "|r", buttons = {} }
            for _, sp in ipairs(rows) do
                local x, y = (sp.pts or ""):match("([%d%.]+),([%d%.]+)")
                local map, pts, nm = z.map, sp.pts, sp.name
                rareItems[#rareItems + 1] = {
                    text = "  " .. nm .. (x and ("  |cff808080" .. x .. ", " .. y .. "|r") or ""),
                    buttons = (pts and pts ~= "") and { { "Waypoint", 70, function() SFP:ZoneCheckWaypoint({ map = map, pts = pts, name = nm }) end } } or {},
                }
            end
        end
    end
    if #rareItems == 0 then rareItems[1] = { text = "|cff808080No Midnight rare data found.|r", buttons = {} } end
    keyRares:Set(rareItems)
    keyWin:SetContent(table.concat(lines, "\n"))
    keyWin:Show()
end

---------------------------------------------------------------------------
-- 5. delve planner: companion role, curios, comfortable tier
---------------------------------------------------------------------------
local HYBRID_SPECS = { [70] = true, [103] = true }   -- Retribution, Feral: tank companion (as the Codex says)

-- Valeera's curios. Source: Icy Veins "Best Valeera Curios in Midnight Season 1" (March 2026), written in our own words.
-- Later seasons add more curios; they are not listed here until they are checked.
SFP.CURIOS = {
    { "Holy Bounding Hand Grenade", "combat", "Now and then she throws a grenade: moderate Holy damage, 50% to stun for 1.5 sec, and it can bounce to another enemy (40%). Safe for the party. Good if your class has no stun." },
    { "Mantle of Stars", "combat", "When a party member falls below 40% health in combat they get a shield worth 50% of their max health, and enemies around them are knocked up and take 25% more damage for 12 sec. An emergency button." },
    { "Nether Entropic Kris", "combat", "She sometimes curses an enemy with Void damage over 30 sec. Each tick has a 15% chance to spread to a nearby enemy, up to 5 stacks. Good against groups." },
    { "Porcelain Blade Tip", "combat", "Her spells and abilities sometimes weaken enemies: 10% more chance to be critically hit for 9 sec. Slightly the best combat curio at the start of Season 1." },
    { "Sanctum's Edict", "combat", "She collects blessings in combat and on kills (1 per normal enemy, 5 per elite). Each blessing gives 1% more healing and damage. At 15 she turns 30% of her current health into a shield that boosts the blessings while it lasts." },
    { "Ebon Crown of Subjugation", "utility", "Opening a Mislaid Curiosity summons a worshipper that adds 1% of your main stat in combat, up to 6 at once. With 6 the bonus per worshipper grows." },
    { "Mandate of Sacred Death", "utility", "When Valeera casts Tools of the Trade (she does near profession nodes) the party's harmful spells get a 5% chance to deal 1% of the target's max health as Holy damage per Mandate, once per target every 2 sec. The strongest utility curio, but it does nothing in delves without profession nodes (for example the Nullaeus fight)." },
    { "Motionless Nulltide", "utility", "Standing still in combat gives a stack every 6 sec (up to 10), each +1% movement speed. Jumping at 10 stacks turns them into 1% haste each for 10 sec and knocks up nearby enemies (once per 20 sec)." },
    { "Overflowing Voidspire", "utility", "After 25 sec of combat you and Valeera deal 18% more damage and healing for 35 sec (35 sec cooldown). Recommended for the Nullaeus fight." },
    { "Time Lost Edict", "utility", "She sometimes makes a zone at an ally: allies get 5% more movement speed, cooldown recharge and cast speed, enemies get the opposite, for 12 sec." },
    -- Season 2 (patch 12.1), from the Seramate PTR guide, Warcraft Wiki and boostroom/expcarry; the list may still change
    { "Essence Trap", "combat", "Season 2: she may place a trap in combat. An enemy within 3 yards triggers a 20% slow for 5 sec, then moderate Nature damage and a 1 sec stun." },
    { "Ouroboric Curse", "combat", "Season 2: when anyone drops below 50% health, nearby enemies are horrified for 8 sec and gain 15% primary damage and 100% Leech, Avoidance and Speed. Once per 2 min; killing Poisoned enemies shortens the cooldown by 12 sec." },
    { "Corrosive Bilespear", "combat", "Season 2: same trigger as Ouroboric Curse, but weaker: horrified 6 sec, 5% primary damage, 50% Leech, Avoidance and Speed. Once per 2 min." },
    { "Soul-Cracking Dreamcatcher", "utility", "Season 2: when a party member interrupts or crowd-controls an Elite, it takes 10% more damage for 30 sec, stacking up to 2 times." },
    { "Dundun's Favor", "utility", "Season 2: a Mislaid Spirit may appear in combat. Walking over a Mislaid Curiosity or Spirit fires 6 Volatile Sprites at random nearby enemies." },
    { "Venom Infusion", "utility", "Season 2: party members are Poisoned on entering combat (1% of current health as Nature damage per minute) but gain 1% movement speed and Haste per 5% health missing, reversed for the first 6 sec. Guides disagree whether this is a combat or utility curio - check in game." },
}
SFP.CURIO_BEST = "Best at the start of Season 1 (Icy Veins): Porcelain Blade Tip (combat) and Mandate of Sacred Death (utility). For the Nullaeus fight take Overflowing Voidspire instead of the Mandate."

-- the companion's curio slots, named by the game's own list (Enum.CompanionConfigSlotTypes), in slot order
function SFP:CurioSlots()
    local out, have = {}, {}
    local E = Enum and Enum.CompanionConfigSlotTypes
    if type(E) == "table" then
        local tmp = {}
        for name, value in pairs(E) do
            if type(name) == "string" and type(value) == "number" then tmp[#tmp + 1] = { name = name, value = value } end
        end
        table.sort(tmp, function(a, b) return a.value < b.value end)
        for _, e in ipairs(tmp) do
            local label = e.name:gsub("(%l)(%u)", "%1 %2")
            out[#out + 1] = { key = e.name:lower(), label = label }
            have[e.name:lower()] = true
        end
    end
    for _, k in ipairs({ "combat", "utility" }) do
        if not have[k] then out[#out + 1] = { key = k, label = k:sub(1, 1):upper() .. k:sub(2) } end
    end
    return out
end

-- tier, companion role and curios are saved per delve; "default" is used by every delve without its own choice
function SFP:DelveCfg()
    local db = self.db
    db.delveCfg = db.delveCfg or {}
    if not db.delveCfg.default then
        db.delveCfg.default = { tier = db.delveTier, companion = db.delveCompanion, curios = db.delveCurios or {} }
    end
    local key = db.delveSel and db.delveSel:lower() or "default"
    db.delveCfg[key] = db.delveCfg[key] or {}
    return db.delveCfg[key], db.delveCfg.default, key
end

function SFP:DelveGet(field, slot)
    local c, d = self:DelveCfg()
    if field == "curio" then
        return (c.curios and c.curios[slot]) or (d.curios and d.curios[slot])
    end
    if c[field] ~= nil then return c[field] end
    return d[field]
end

function SFP:DelveSet(field, value, slot)
    local c, d, key = self:DelveCfg()
    if not c then c = {}; self.db.delveCfg[key] = c end
    if field == "curio" then
        c.curios = c.curios or {}
        c.curios[slot] = value
    else
        c[field] = value
    end
end

-- what the addon's guide data says about running one delve with Valeera (sentences that mention her)
function SFP:DelveTips(name)
    local okM, _, cns = pcall(SFP_Module, "Codex")
    local g = okM and cns and cns.DELVE_GUIDES and cns.DELVE_GUIDES[(name or ""):lower()]
    if not g then return nil end
    local out = { where = g.where, variants = {}, tips = {} }
    for _, v in ipairs(g.variants or {}) do out.variants[#out.variants + 1] = v[1] end
    local function scan(label, text)
        for sentence in tostring(text or ""):gmatch("[^%.]+%.?") do
            if sentence:find("Valeera", 1, true) then out.tips[#out.tips + 1] = label .. ": " .. strtrim(sentence) end
        end
    end
    for _, v in ipairs(g.variants or {}) do scan(v[1], v[2]) end
    for _, b in ipairs(g.bosses or {}) do scan(b[1], b[2]) end
    for _, t in ipairs(g.trash or {}) do scan("Trash", t) end
    return out
end

local function recommendCompanion(spec)
    if not spec then return "Healer" end
    if spec.role == "TANK" or spec.role == "HEALER" then return "Damage" end
    if HYBRID_SPECS[spec.id] then return "Tank" end
    return "Healer"
end

-- class, all its specs, the spec you chose (or the one you play) and the companion role
function SFP:DelveInfo()
    local db = self.db
    local info = { specs = {} }
    local className, _, classID = UnitClass("player")
    info.className, info.classID = className, classID
    if db.delveClass ~= classID then db.delveClass = classID; db.delveSpec = nil end   -- another class: start again
    local n = (GetNumSpecializationsForClassID and classID) and GetNumSpecializationsForClassID(classID) or 0
    for i = 1, n do
        local ok, id, name, _, _, role = pcall(GetSpecializationInfoForClassID, classID, i)
        if ok and id then info.specs[#info.specs + 1] = { id = id, name = name, role = role } end
    end
    local specIndex = GetSpecialization and GetSpecialization()
    if specIndex and GetSpecializationInfo then info.currentID = (GetSpecializationInfo(specIndex)) end
    local want = db.delveSpec or info.currentID
    for _, sp in ipairs(info.specs) do if sp.id == want then info.spec = sp end end
    info.following = db.delveSpec == nil
    info.recommended = recommendCompanion(info.spec)
    info.chosen = self:DelveGet("companion")
    info.companion = info.chosen or info.recommended
    return info
end

-- the setup the guides recommend for the spec selected on the planner (changes when you pick another spec)
-- Sources: Icy Veins (Season 1), expcarry.com / Seramate (Season 2); only curios the addon lists are suggested
-- best curios per slot, in the order the guides give (Season 2 first, then Season 1); other curios are not ranked
SFP.CURIO_RANK = {
    combat = { "Corrosive Bilespear", "Porcelain Blade Tip" },
    utility = { "Soul-Cracking Dreamcatcher", "Mandate of Sacred Death" },
}

-- the best curio of a slot among the ones you marked as owned (right-click a curio on the planner); none marked = best overall
function SFP:BestCurio(slot)
    local owned = self.db.curiosOwned or {}
    local any = false
    for _, cu in ipairs(self.CURIOS or {}) do if cu[2] == slot and owned[cu[1]] then any = true end end
    for _, name in ipairs((self.CURIO_RANK or {})[slot] or {}) do
        if not any or owned[name] then return name, any end
    end
    return nil, any
end

-- curios learned from the game are added to the planner's list (after a /reload they also get a button)
function SFP:MergeLearnedCurios()
    local have = {}
    for _, cu in ipairs(self.CURIOS or {}) do have[cu[1]] = true end
    for name, r in pairs(self.CuriosLearned or {}) do
        if not have[name] then have[name] = true; table.insert(self.CURIOS, { name, r.slot or "combat", (r.text and r.text ~= "") and r.text or "Learned from the game (no description read).", learned = true, spell = r.spell }) end
    end
    for name, r in pairs(self.db and self.db.learnedCurios or {}) do
        if not have[name] then
            table.insert(self.CURIOS, { name, r.slot or "combat", (r.text and r.text ~= "") and r.text or "Learned from your game (no description read).", learned = true, spell = r.spell })
        end
    end
end
SFP:OnLogin(function() SFP:MergeLearnedCurios() end)

-- Reads the curios of the companion from the game (best effort: the delve companion API is not documented well).
-- Marks the ones found as owned. Returns how many were found and a short report of what the game answered.
function SFP:ScanOwnedCurios()
    local report, found = {}, 0
    local D = C_DelvesUI
    if not D then return 0, "The game has no delve interface (C_DelvesUI)." end
    local known = {}
    for _, cu in ipairs(self.CURIOS or {}) do known[cu[1]:lower()] = cu[1] end
    -- a learned curio saved without its description (the spell text was not loaded yet) gets it now
    for _, rec in pairs(self.db and self.db.learnedCurios or {}) do
        if rec.spell and (rec.text == nil or rec.text == "") and C_Spell and C_Spell.GetSpellDescription then
            local okD, t = pcall(C_Spell.GetSpellDescription, rec.spell)
            if okD and type(t) == "string" and t ~= "" and not (issecretvalue and issecretvalue(t)) then rec.text = t end
        end
    end
    local configID
    for _, fname in ipairs({ "GetCompanionConfigID", "GetCurrentCompanionConfigID", "GetCompanionTraitConfigID" }) do
        if type(D[fname]) == "function" then
            local ok, id = pcall(D[fname])
            if ok and type(id) == "number" and id > 0 then configID = id; report[#report + 1] = fname .. " = " .. id; break end
        end
    end
    -- this game version has no "companion config" call: the config of the companion's trait tree is found from the tree itself
    if not configID and C_Traits and C_Traits.GetConfigIDByTreeID then
        local companionID
        if type(D.GetCompanionInfoForActivePlayer) == "function" then
            local okI, info = pcall(D.GetCompanionInfoForActivePlayer)
            if okI then
                if type(info) == "number" then companionID = info
                elseif type(info) == "table" then companionID = info.companionID or info.id or info.creatureID end
                report[#report + 1] = "companion info -> " .. tostring(type(info) == "table" and (info.companionID or info.id) or info)
            end
        end
        local trees = {}
        if type(D.GetTraitTreeForCompanion) == "function" then
            if companionID then
                local okT, tid = pcall(D.GetTraitTreeForCompanion, companionID)
                if okT and type(tid) == "number" then trees[#trees + 1] = tid end
            end
            local okT2, tid2 = pcall(D.GetTraitTreeForCompanion)
            if okT2 and type(tid2) == "number" then trees[#trees + 1] = tid2 end
        end
        for _, tid in ipairs(trees) do
            local okC, cid = pcall(C_Traits.GetConfigIDByTreeID, tid)
            if okC and type(cid) == "number" and cid > 0 then
                configID = cid
                report[#report + 1] = "trait tree " .. tid .. " -> config " .. cid
                break
            end
        end
    end
    local nodes, nodeType = {}, {}
    local E = Enum and Enum.CurioType
    if type(E) == "table" and type(D.GetCurioNodeForCompanion) == "function" then
        for name, v in pairs(E) do
            local ok, node = pcall(D.GetCurioNodeForCompanion, v)
            if ok and type(node) == "number" and node > 0 then nodes[#nodes + 1] = node; nodeType[node] = tostring(name):lower(); report[#report + 1] = "curio type " .. tostring(name) .. " -> node " .. node end
        end
    end
    if configID and C_Traits and #nodes > 0 then
        for _, node in ipairs(nodes) do
            local okN, ni = pcall(C_Traits.GetNodeInfo, configID, node)
            if okN and type(ni) == "table" then
                for _, entryID in ipairs(ni.entryIDs or {}) do
                    local okE, ei = pcall(C_Traits.GetEntryInfo, configID, entryID)
                    local def = okE and type(ei) == "table" and ei.definitionID
                    local okD, di = pcall(C_Traits.GetDefinitionInfo, def or 0)
                    local name = okD and type(di) == "table" and (di.overrideName or (di.spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(di.spellID)))
                    if type(name) == "string" and not (issecretvalue and issecretvalue(name)) then
                        self.db.curiosOwned = self.db.curiosOwned or {}
                        if known[name:lower()] then
                            self.db.curiosOwned[known[name:lower()]] = true
                        else
                            -- a curio the addon did not know: learn it (name, slot, ids, text) and keep it in the saved data
                            local spellID = okD and type(di) == "table" and di.spellID or nil
                            local desc
                            if spellID and C_Spell and C_Spell.GetSpellDescription then
                                local okS, t = pcall(C_Spell.GetSpellDescription, spellID)
                                if okS and type(t) == "string" and not (issecretvalue and issecretvalue(t)) then desc = t end
                            end
                            self.db.learnedCurios = self.db.learnedCurios or {}
                            self.db.learnedCurios[name] = { slot = nodeType[node] or "combat", spell = spellID, node = node, entry = entryID, text = desc }
                            self.db.curiosOwned[name] = true
                            self:MergeLearnedCurios()
                        end
                        found = found + 1
                    end
                end
            end
        end
    end
    if found == 0 then
        local names = {}
        for k, v in pairs(D) do if type(v) == "function" then names[#names + 1] = k end end
        table.sort(names)
        report[#report + 1] = "Nothing matched. Delve functions of this game: " .. table.concat(names, ", ")
    end
    return found, table.concat(report, "; ")
end

function SFP:DelveBestSetup()
    local info = self:DelveInfo()
    local out = { companion = info.recommended, curios = {}, lines = {} }
    if not info.spec then return out end
    -- a delve's own guide can ask for a different companion role (sentences about Valeera)
    local delveNote
    if self.db.delveSel then
        local tips = self:DelveTips(self.db.delveSel)
        local roles, first = {}, nil
        for _, t in ipairs(tips and tips.tips or {}) do
            for _, r in ipairs({ "Healer", "Tank", "Damage" }) do
                if t:find(r, 1, true) then roles[r] = true; first = first or t end
            end
        end
        local n, only = 0, nil
        for r in pairs(roles) do n = n + 1; only = r end
        if n == 1 then out.companion = only; delveNote = first end
    end
    local known = {}
    for _, cu in ipairs(self.CURIOS or {}) do known[cu[1]] = cu[2] end
    local owned = self.db.curiosOwned or {}
    local function pick(slot, ...)
        local list = { ... }
        local anyOwned = false
        for _, cu in ipairs(self.CURIOS or {}) do if cu[2] == slot and owned[cu[1]] then anyOwned = true end end
        for _, name in ipairs(list) do
            if known[name] == slot and (not anyOwned or owned[name]) then out.curios[slot] = name; return end
        end
        -- none of the guide picks owned: the best-ranked one you own, if any
        for _, name in ipairs((self.CURIO_RANK or {})[slot] or {}) do
            if owned[name] then out.curios[slot] = name; return end
        end
    end
    -- Season 2 guide setup (one guide); Season 1 picks as the fallback when those curios are not in the list
    if out.companion == "Healer" then
        pick("combat", "Corrosive Bilespear", "Porcelain Blade Tip")
        pick("utility", "Soul-Cracking Dreamcatcher", "Mandate of Sacred Death")
    elseif out.companion == "Tank" then
        pick("combat", "Mantle of Stars", "Corrosive Bilespear", "Porcelain Blade Tip")
        pick("utility", "Soul-Cracking Dreamcatcher", "Mandate of Sacred Death")
    else
        pick("combat", "Corrosive Bilespear", "Porcelain Blade Tip")
        pick("utility", "Soul-Cracking Dreamcatcher", "Mandate of Sacred Death")
    end
    local L = out.lines
    L[#L + 1] = ("|cffffd100Suggested setup for %s|r"):format(info.spec.name)
    if self.db.delveSel then L[1] = ("|cffffd100Suggested setup for %s in %s|r"):format(info.spec.name, self.db.delveSel) end
    L[#L + 1] = ("  Valeera as |cff40ff40%s|r"):format(out.companion)
    if delveNote then L[#L + 1] = "  |cff808080Why (guide for this delve): " .. delveNote .. "|r" end
    for i, sl in ipairs(self:CurioSlots()) do
        if out.curios[sl.key] then L[#L + 1] = ("  Slot %d %s: |cff40ff40%s|r"):format(i, sl.label, out.curios[sl.key]) end
    end
    L[#L + 1] = "  Poison (Season 2): Frostheart Venom"
    L[#L + 1] = "|cff808080From the Season 2 guides (mostly one guide). Against the Nullaeus fight take Overflowing Voidspire as the utility curio; Mandate of Sacred Death does nothing where there are no profession nodes. Best-in-slot gear is not included: no checked source yet.|r"
    return out
end

function SFP:UseBestSetup()
    local b = self:DelveBestSetup()
    self:DelveSet("companion", b.companion)
    for slot, name in pairs(b.curios) do self:DelveSet("curio", name, slot) end
end

function SFP:DelveAdvice()
    local info = self:DelveInfo()
    local lines = {}
    if not info.spec then
        lines[#lines + 1] = "Your specialization is not known yet."
    else
        lines[#lines + 1] = ("You play %s (%s). Valeera should be |cff40ff40%s|r%s."):format(info.spec.name or "?", (info.spec.role or "?"):lower(), info.companion,
            info.chosen and (info.chosen ~= info.recommended and (" - your choice; the best for this spec is " .. info.recommended) or " - your choice, also the best for this spec") or " - the best for this spec")
        lines[#lines + 1] = "Curios: one Combat and one Utility slot. If your class has no crowd control, take a stun or slow curio. Tanks and healers: a damage curio helps the run go faster."
    end
    local parts = {}
    for i, sl in ipairs(self:CurioSlots()) do
        local n = self:DelveGet("curio", sl.key)
        if n then parts[#parts + 1] = ("Slot %d %s: %s"):format(i, sl.label, n) end
    end
    if #parts > 0 then lines[#lines + 1] = "Your curios: " .. table.concat(parts, "  |  ") end
    local tier = self:DelveGet("tier")
    lines[#lines + 1] = tier and ("Comfortable tier (you set it): |cffffd100" .. tier .. "|r. Use bountiful keys at this tier or one above.")
        or "Type the tier you can do safely into the box; the addon remembers it."
    return table.concat(lines, "\n\n")
end

-- text typed into the tier box: a number from 1 to 11, empty clears it
function SFP:SetDelveTier(text)
    local n = tonumber(text)
    if n then n = math.max(1, math.min(11, math.floor(n))) end
    self:DelveSet("tier", n)
    return n
end

-- every delve: the Codex seed list plus what the game's map shows now (with bountiful)
local delveCache, delveAt
function SFP:DelveList()
    if delveCache and GetTime() - delveAt < 60 then return delveCache end
    local out, seen = {}, {}
    local function add(name, zone, bountiful, live)
        if type(name) ~= "string" or secret(name) then return end
        local k = name:lower()
        local e = seen[k]
        if not e then e = { name = name, zone = zone or "?" }; seen[k] = e; out[#out + 1] = e end
        if live then e.live, e.bountiful, e.zone = true, bountiful, zone or e.zone end
    end
    local okM, _, cns = pcall(SFP_Module, "Codex")
    for _, d in ipairs((okM and cns and cns.DELVE_LIST) or {}) do add(d[1], d[2], nil, false) end
    local okZ, zones = pcall(C_Map.GetMapChildrenInfo, 946, Enum.UIMapType.Zone, true)
    if okZ and type(zones) == "table" and C_AreaPoiInfo and C_AreaPoiInfo.GetDelvesForMap then
        for _, z in ipairs(zones) do
            local ok, ids = pcall(C_AreaPoiInfo.GetDelvesForMap, z.mapID)
            for _, poiID in ipairs((ok and ids) or {}) do
                local okI, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, z.mapID, poiID)
                if okI and info and info.name then
                    local bountiful = info.atlasName and not secret(info.atlasName) and info.atlasName:lower():find("bountiful") and true or false
                    add(info.name, z.name, bountiful, true)
                end
            end
        end
    end
    table.sort(out, function(x, y) if x.zone ~= y.zone then return x.zone < y.zone end return x.name < y.name end)
    delveCache, delveAt = out, GetTime()
    return out
end

---------------------------------------------------------------------------
-- 9. missing here: mounts, pets and toys of the rares and bosses of this zone or instance
---------------------------------------------------------------------------
local function missingHere(mapID, instName, limit)
    local names, count, ents = {}, 0, {}
    local spot
    local function check(itemIDs, label)
        for _, itemID in ipairs(itemIDs or {}) do
            local own = SFP.OwnedStatus and SFP:OwnedStatus(itemID)
            if own == false then
                count = count + 1
                local line = SFP:ItemName(itemID) .. " (" .. label .. ")"
                if not limit or #names < limit then names[#names + 1] = line end
                ents[#ents + 1] = { text = line, spot = spot }
            end
        end
    end
    for _, sp in ipairs((SFP.Rares and SFP.Rares[mapID]) or {}) do
        if sp.items and #sp.items > 0 then
            spot = (sp.pts and sp.pts ~= "") and { map = mapID, pts = sp.pts, name = sp.name } or nil
            check(sp.items, sp.name or "rare")
        end
    end
    spot = nil
    local zone = SFP.zoneByMap and SFP.zoneByMap[mapID]
    for _, inst in ipairs(zone and zone.instances or {}) do
        if not instName or inst.name == instName then check(inst.items, inst.name) end
    end
    return count, names, ents
end

-- the spawn point of a rare that is nearest to the player (pts is "x,y;x,y;..." in percent)
local function nearestSpot(spot)
    local px, py
    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(spot.map, "player")
    if pos and pos.GetXY then px, py = pos:GetXY() end
    local bx, by, bd
    for xs, ys in spot.pts:gmatch("([%d%.]+),([%d%.]+)") do
        local x, y = tonumber(xs) / 100, tonumber(ys) / 100
        local d = px and ((x - px) ^ 2 + (y - py) ^ 2) or 0
        if not bd or d < bd then bx, by, bd = x, y, d end
    end
    return bx, by
end

-- rows for the Zone Check page: { title, rows = { { text, spot } } }, a waypoint button for rares with known spawn points
function SFP:ZoneCheckRows()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return "Your zone is not known yet.", {} end
    local inInstance, itype = IsInInstance()
    local instName = (inInstance and (itype == "party" or itype == "raid")) and (GetInstanceInfo()) or nil
    local _, _, ents = missingHere(mapID, instName)
    return instName or self:ZoneName(mapID), ents
end

function SFP:ZoneCheckWaypoint(spot)
    local x, y = nearestSpot(spot)
    if x then self:SetWaypoint(spot.map, x / 1, y / 1, spot.name) end
end

---------------------------------------------------------------------------
-- 9b. collection planner: mounts (the whole mount journal) and the mounts, pets and toys of the addon's rares and bosses
---------------------------------------------------------------------------
local collList, collBuilding

local function cleanSource(s)
    if type(s) ~= "string" or secret(s) then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("%s*[\r\n]+%s*", "  ")
    return s
end

local function buildCollect()
    if collList or collBuilding then return end
    collBuilding = true
    local byKey, list = {}, {}
    local function add(e)
        local old = byKey[e.key]
        if old then
            if e.pts and not old.pts then old.pts, old.spotMap, old.spotName = e.pts, e.spotMap, e.spotName end
            if e.rareSource then old.source = e.rareSource end
            return old
        end
        byKey[e.key] = e
        list[#list + 1] = e
        return e
    end
    local MJ = C_MountJournal
    -- rares and bosses the addon knows: items of kind mount / pet / toy, with the rare's spawn spots
    local function fromItems(itemIDs, where, spotMap, pts, spotName)
        for _, itemID in ipairs(itemIDs or {}) do
            local info = SFP.Items and SFP.Items[itemID]
            local kind = info and info.kind
            if kind == "mount" or kind == "pet" or kind == "toy" then
                local mountID
                if kind == "mount" and MJ and MJ.GetMountFromItem then
                    local ok, id = pcall(MJ.GetMountFromItem, itemID)
                    if ok and id then mountID = id end
                end
                add({
                    key = mountID and ("m:" .. mountID) or ("i:" .. itemID), kind = kind, itemID = itemID, mountID = mountID,
                    source = where, rareSource = where, pts = pts, spotMap = spotMap, spotName = spotName,
                })
            end
        end
    end
    for mapID, rares in pairs(SFP.Rares or {}) do
        for _, sp in ipairs(type(rares) == "table" and rares or {}) do
            if sp.items then
                fromItems(sp.items, ("Drops from %s (%s)"):format(sp.name or "a rare", SFP:ZoneName(mapID)), mapID, sp.pts, sp.name)
            end
        end
    end
    for _, zone in pairs(SFP.zoneByMap or {}) do
        for _, inst in ipairs(zone.instances or {}) do
            fromItems(inst.items, "Drops in " .. (inst.name or "an instance"), nil, nil, nil)
        end
    end
    -- the mount journal, a few hundred per frame
    local ids = {}
    if MJ and MJ.GetMountIDs then
        local ok, got = pcall(MJ.GetMountIDs)
        if ok and type(got) == "table" then ids = got end
    end
    local function finish()
        collList, collBuilding = list, false
        if SFP.CollPlanChanged then pcall(SFP.CollPlanChanged) end
    end
    -- every toy of the game: the toy box lists only what its filters show, so open them fully, read, and put the player's filters back
    local function readToys()
        local TB = C_ToyBox
        if not (TB and TB.GetToyFromIndex and TB.GetToyInfo) then return end
        local saved = { src = {} }
        local nSrc = (C_PetJournal and C_PetJournal.GetNumPetSources and C_PetJournal.GetNumPetSources()) or 0
        pcall(function()
            saved.col, saved.unc = TB.GetCollectedShown(), TB.GetUncollectedShown()
            for s = 1, nSrc do saved.src[s] = TB.IsSourceTypeFilterChecked(s) end
        end)
        pcall(function()
            TB.SetCollectedShown(true)
            TB.SetUncollectedShown(true)
            TB.SetAllSourceTypeFilters(true)
        end)
        local okN, n = pcall(function() return TB.GetNumFilteredToys and TB.GetNumFilteredToys() or TB.GetNumTotalDisplayedToys() end)
        for t = 1, (okN and tonumber(n)) or 0 do
            local okT, itemID = pcall(TB.GetToyFromIndex, t)
            if okT and type(itemID) == "number" and itemID > 0 then
                local okI, _, name = pcall(TB.GetToyInfo, itemID)
                local e = add({ key = "i:" .. itemID, kind = "toy", itemID = itemID, source = "" })
                if okI and type(name) == "string" and not secret(name) and not e.name then e.name = name end
            end
        end
        pcall(function()
            if saved.col ~= nil then TB.SetCollectedShown(saved.col) end
            if saved.unc ~= nil then TB.SetUncollectedShown(saved.unc) end
            for s = 1, nSrc do
                if saved.src[s] ~= nil then TB.SetSourceTypeFilter(s, saved.src[s]) end
            end
        end)
    end
    -- every collectible battle pet: walk the species numbers (the pet journal list depends on the player's filters)
    local function readPets()
        local PJ = C_PetJournal
        if not (PJ and PJ.GetPetInfoBySpeciesID) then return finish() end
        local byName = {}
        for _, e in ipairs(list) do
            if e.kind == "pet" and not e.speciesID then byName[SFP:CollEntryName(e):lower()] = e end
        end
        local sp, PCH = 1, 200
        local function pstep()
            local stop = math.min(6000, sp + PCH - 1)
            while sp <= stop do
                local ok, name, _, _, _, src, _, _, _, _, _, obtainable = pcall(PJ.GetPetInfoBySpeciesID, sp)
                if ok and type(name) == "string" and not secret(name) and obtainable ~= false then
                    local e = byName[name:lower()]
                    if e then
                        e.speciesID, e.name = sp, name
                        if src and src ~= "" then e.source = cleanSource(src) end
                    else
                        add({ key = "p:" .. sp, kind = "pet", speciesID = sp, name = name, source = cleanSource(src or "") })
                    end
                end
                sp = sp + 1
            end
            if sp <= 6000 then C_Timer.After(0, pstep) else finish() end
        end
        pstep()
    end
    local i, CH = 1, 120
    local function step()
        local stop = math.min(#ids, i + CH - 1)
        while i <= stop do
            local mid = ids[i]
            local ok, name, _, _, _, _, _, _, _, _, hide = pcall(MJ.GetMountInfoByID, mid)
            if ok and type(name) == "string" and not secret(name) and not hide then
                local okX, _, _, src = pcall(MJ.GetMountInfoExtraByID, mid)
                local e = add({ key = "m:" .. mid, kind = "mount", mountID = mid, name = name, source = cleanSource(okX and src or "") })
                if not e.name then e.name = name end
                if e.source == "" and e.rareSource then e.source = e.rareSource end
            end
            i = i + 1
        end
        if i <= #ids then
            C_Timer.After(0, step)
        else
            pcall(readToys)
            readPets()
        end
    end
    step()
end

function SFP:CollectEntries()
    if not collList then SFP:Safe("collections", buildCollect) end
    return collList
end

function SFP:CollEntryName(e)
    if e.name then return e.name end
    return e.itemID and self:ItemName(e.itemID) or "?"
end

-- true / false, nil when unknown
function SFP:CollOwned(e)
    if e.mountID and C_MountJournal and C_MountJournal.GetMountInfoByID then
        local ok, _, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, e.mountID)
        if ok then return collected and true or false end
    end
    if e.speciesID and C_PetJournal and C_PetJournal.GetNumCollectedInfo then
        local ok, n = pcall(C_PetJournal.GetNumCollectedInfo, e.speciesID)
        if ok and type(n) == "number" then return n > 0 end
    end
    if e.kind == "toy" and e.itemID and PlayerHasToy then
        local ok, has = pcall(PlayerHasToy, e.itemID)
        if ok then return has and true or false end
    end
    if e.itemID and self.OwnedStatus then return self:OwnedStatus(e.itemID) end
    return nil
end

-- delve entrances from the map's own points of interest: { { name, map, x, y }, ... }
local delveIndex
local function delveEntrances()
    if delveIndex then return delveIndex end
    delveIndex = {}
    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetDelvesForMap and C_AreaPoiInfo.GetAreaPOIInfo) then return delveIndex end
    for _, mapID in ipairs(DELVE_MAPS) do
        local ok, ids = pcall(C_AreaPoiInfo.GetDelvesForMap, mapID)
        if ok and type(ids) == "table" then
            for _, poiID in ipairs(ids) do
                local ok2, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
                if ok2 and type(info) == "table" and type(info.name) == "string" and not secret(info.name) and info.position then
                    local x, y = info.position:GetXY()
                    if x and y then delveIndex[#delveIndex + 1] = { name = info.name, map = mapID, x = x, y = y } end
                end
            end
        end
    end
    return delveIndex
end

-- the entrance of the raid, dungeon or delve that a source text talks about: { map, x, y, label } or nil
function SFP:EntranceInText(text)
    if type(text) ~= "string" or text == "" or secret(text) then return nil end
    local bestInst
    for _, exp in ipairs(self.Expansions or {}) do
        for _, inst in ipairs(exp.instances or {}) do
            if inst.name and #inst.name >= 4 and text:find(inst.name, 1, true) and (not bestInst or #inst.name > #bestInst.name) then bestInst = inst end
        end
    end
    local bestDelve
    for _, d in ipairs(delveEntrances()) do
        if #d.name >= 4 and text:find(d.name, 1, true) and (not bestDelve or #d.name > #bestDelve.name) then bestDelve = d end
    end
    if bestDelve and (not bestInst or #bestDelve.name > #bestInst.name) then
        return { map = bestDelve.map, x = bestDelve.x, y = bestDelve.y, label = bestDelve.name .. " (delve entrance)" }
    end
    if bestInst then
        local en = self.FindEntrance and self:FindEntrance(bestInst)
        if en then return { map = en.map, x = en.x, y = en.y, label = bestInst.name .. " (entrance)" } end
    end
    return nil
end

-- the vendor, quest giver or boss that a source text names, when the addon knows where that NPC stands
-- (Data/DecorNPCs.lua, read from Wowhead NPC pages): { map, x, y, label } or nil
local monsterIndex, questByTitle
local function monsters()
    if monsterIndex then return monsterIndex end
    monsterIndex = {}
    for _, src in ipairs({ SFP.Rares or {}, SFP.Spawns or {} }) do
        for mapID, list in pairs(src) do
            for _, sp in ipairs(type(list) == "table" and list or {}) do
                if type(sp.name) == "string" and sp.hx and not monsterIndex[sp.name] then
                    monsterIndex[sp.name] = { map = mapID, x = sp.hx, y = sp.hy }
                end
            end
        end
    end
    return monsterIndex
end

-- the place where the Codex saw the giver of a quest of this title (recorded when any of your characters did it)
local function questGiver(title)
    local _, cns = SFP_Module("Codex")
    local db = cns and cns.db
    if not (db and db.quests and db.qloc) then return nil end
    if not questByTitle then
        questByTitle = {}
        for id, q in SeviathsAllPairs(db.quests) do
            if type(q) == "table" and q.t then questByTitle[q.t] = id end
        end
    end
    local id = questByTitle[title]
    local g = id and db.qloc[id] and db.qloc[id].g
    if g and g.m and g.x then return { map = g.m, x = g.x, y = g.y, label = (g.n or "Quest giver") .. " (starts " .. title .. ")" } end
end

-- the vendor, quest giver or monster that a source text names, when a place is known:
-- NPC positions (Data/DecorNPCs.lua), rare and farm-mob spawns, quest givers the Codex recorded
function SFP:NpcInText(text)
    if type(text) ~= "string" or secret(text) then return nil end
    local known = self.DecorNPCs or {}
    local mons = monsters()
    for seg in (text .. "  "):gmatch("(.-)%s%s+") do
        local kind = seg:match("^%s*([%a ]+):")
        seg = seg:gsub("^%s*[%a ]+:%s*", "")
        kind = kind and kind:lower() or ""
        if kind:find("quest", 1, true) then
            local g = questGiver(seg:gsub("%s*$", ""))
            if g then return g end
        end
        for part in (seg .. ","):gmatch("%s*(.-)%s*[,;]") do
            local p = known[part]
            if p and p.map then
                return { map = p.map, x = p.x, y = p.y, label = part .. " (" .. (kind:find("vendor", 1, true) and "vendor" or "NPC") .. ")" }
            end
            -- an NPC you spoke to yourself (saved by the addon whenever you open a conversation or a vendor)
            local mine = self.LearnedNpcByName and self:LearnedNpcByName(part)
            if mine then return { map = mine.map, x = mine.x, y = mine.y, label = part .. " (NPC)" } end
            local m = mons[part]
            if m then return { map = m.map, x = m.x, y = m.y, label = part } end
        end
    end
    return nil
end

-- where to go for a collection entry: the rare's spawn spots, else the entrance of the instance in its source text
function SFP:CollTarget(e)
    if e.pts and e.spotMap then return "spots" end
    if e._ent == nil then
        local text = (e.source or "") .. " " .. (e.rareSource or "")
        -- a vendor you opened that sells it: the place you stood at (learned by the addon from every vendor you open)
        local learned = self.db.vendorLearned
        local found
        if learned then
            if e.itemID and learned[e.itemID] then found = learned[e.itemID]
            elseif e.mountID then
                for _, v in pairs(learned) do if v.mount == e.mountID then found = v; break end end
            end
        end
        if found and found.m and found.x then
            e._ent = { map = found.m, x = found.x, y = found.y, label = tostring(found.v) .. " (vendor)" }
        else
            e._ent = self:NpcInText(text) or self:EntranceInText(text) or false
        end
    end
    return e._ent or nil
end

function SFP:CollWaypoint(e)
    if not e then return end
    if e.pts and e.spotMap then
        self:ZoneCheckWaypoint({ map = e.spotMap, pts = e.pts, name = e.spotName or self:CollEntryName(e) })
        return
    end
    local t = self:CollTarget(e)
    if type(t) == "table" then self:SetWaypoint(t.map, t.x, t.y, t.label) end
end

function SFP:ZoneCheck(quiet)
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local inInstance, itype = IsInInstance()
    local instName = (inInstance and (itype == "party" or itype == "raid")) and (GetInstanceInfo()) or nil
    local count, names = missingHere(mapID, instName, 3)
    if count > 0 then
        self:Print(("Missing here: %d collectible%s - %s%s"):format(count, count == 1 and "" or "s", table.concat(names, ", "),
            count > #names and (" and " .. (count - #names) .. " more") or ""))
    elseif not quiet then
        self:Print("Nothing missing here that the addon knows about (mounts, pets, toys of rares and bosses).")
    end
end

-- the same check as a text for the menu page: every missing collectible with where it comes from
function SFP:ZoneCheckReport()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return "Your zone is not known yet." end
    local inInstance, itype = IsInInstance()
    local instName = (inInstance and (itype == "party" or itype == "raid")) and (GetInstanceInfo()) or nil
    local count, names = missingHere(mapID, instName)
    local lines = { "|cffffd100" .. (instName or self:ZoneName(mapID)) .. "|r", "" }
    if count == 0 then
        lines[#lines + 1] = "Nothing missing here that the addon knows about (mounts, pets and toys of the rares and bosses here)."
    else
        lines[#lines + 1] = ("You still miss %d collectible%s here:"):format(count, count == 1 and "" or "s")
        for _, n in ipairs(names) do lines[#lines + 1] = "  - " .. n end
    end
    return table.concat(lines, "\n")
end

local zf = CreateFrame("Frame")
pcall(zf.RegisterEvent, zf, "ZONE_CHANGED_NEW_AREA")
pcall(zf.RegisterEvent, zf, "PLAYER_ENTERING_WORLD")
local lastZone, zoneTimer
zf:SetScript("OnEvent", function()
    if not (SFP.db and SFP.db.zoneCheck ~= false) or zoneTimer then return end
    zoneTimer = true
    C_Timer.After(6, function()
        zoneTimer = nil
        local m = C_Map.GetBestMapForUnit("player")
        if m and m ~= lastZone then
            lastZone = m
            SFP:Safe("zone check", SFP.ZoneCheck, SFP, true)
        end
    end)
end)

---------------------------------------------------------------------------
-- 10. housing decor you can craft (Midnight): the recipes the addon knows about
---------------------------------------------------------------------------
-- decor named in the Warcraft Tavern / Warcraft Secrets housing articles (no game IDs known): { name, where to get it }
local DECOR_NAMED = {
    { "Jewelcrafter's Tent", "Quest: The Perenolde Tiara (Alliance); Stormwind vendor for gold" },
    { "Akunda the Tapestry", "Quest: Clearing the Fog (Horde); Zuldazar vendor for War Resources" },
    { "Shaohao Ceremonial Bell", "Quest in Kun-Lai Summit; Lorewalkers in the Vale of Eternal Blossoms for gold" },
    { "Head of the Broodmother", "Achievement: More DoTs! (25 Player), Onyxia's Lair" },
    { "Portal to Damnation", "Achievement: Back from the Beyond; Ve'nari in the Maw" },
    { "Iron Dragonmaw Gate", "Achievement: The Master of Twin Peaks; capital-city vendors for Marks of Honor" },
    { "Lorewalker's Bookcase", "Lorewalkers, Revered" },
    { "Empty Lorewalker's Bookcase", "Lorewalkers, Revered" },
    { "Zandalari War Torch", "Talanji's Expedition, Honored" },
    { "Zandalari Sconce", "Talanji's Expedition, Honored" },
    { "Shadowmoon Greenhouse", "Council of Exarchs, Exalted" },
    { "Grand Draenethyst Lamp", "Council of Exarchs, Exalted" },
    { "The Large Razorwind Gazebo", "Neighborhood vendor, Razorwind Shores" },
    { "Wooden Gazebo", "Neighborhood vendor, Founder's Point" },
    { "A Wrought Iron Chandelier", "Neighborhood vendor, Founder's Point" },
    { "Iron Chain Chandelier", "Neighborhood vendor, Razorwind Shores" },
    { "Thunder Totem Brazier", "Neltharion's Lair, final boss" },
    { "Gilnean Circular Rug", "Shadowfang Keep, final boss" },
    { "Fate of All Life Painting", "Waycrest Manor, final boss" },
    { "Tidesage's Fireplace", "Shrine of the Storm, final boss" },
    { "Dalaran Display Shelves", "Inscription (Legion)" },
    { "Draenei Holo-Dais", "Enchanting (Outland)" },
    { "Draenei Holo-Path", "Enchanting (Outland)" },
    { "Intense Mogu Brazier", "Enchanting (Pandaria)" },
    { "Valdrakken Fences", "Jewelcrafting (Dragon Isles)" },
    { "Valdrakken Fenceposts", "Jewelcrafting (Dragon Isles)" },
    { "Draenethyst Sconce", "Jewelcrafting (Draenor)" },
    { "Miniature Replica Dark Portal", "Pre-Launch Event (recipe from a Heavy Junkbox)" },
}

local DECOR = {
    { 1246939, "Haranir Canopy Bed", "Harandar treasures" },
    { 1246943, "Plush Haranir Leather Pillow", "Heavy Trunk (Delves)" },
    { 1246893, "Replica Haranir Mural", "Heavy Trunk (Delves)" },
    { 1246892, "Resplendent Highborne Statue", "Eversong treasures" },
    { 1246894, "Shining Sin'dorei Hourglass", "Challenger's Cache" },
    { 1233132, "Entropic Illuminant", "Voidstorm treasures" },
    { 1233136, "Riftstone", "Heavy Trunk (Delves)" },
    { 1233138, "Silvermoon Spire Fountain", "Heavy Trunk (Delves)" },
    { 1248620, "Restful Bronze Bench", "Victorious Stormarion Pinnacle Cache" },
    { 1229002, "Luxurious Silvermoon Lounge Cushion", "Eversong treasures" },
    { 1246908, "Rootflame Campfire", "Heavy Trunk (Delves)" },
    { 1246903, "Ren'dorei Postage Repository", "Voidstorm treasures" },
}

local decorWin, decorBox, decorSearcher, decorCache, decorAt
local decorMode = "all"
local decorBtns = {}

local function plainText(t)
    return (tostring(t or ""):gsub("|n", "  "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- every decor the game's own housing catalog lists, with the source the game gives for it
-- the decor list is big: it is built in small slices (about 10 ms per frame) so the game never freezes or stops the script
local sliceStart = 0
local function slice()
    if debugprofilestop and coroutine.running() and debugprofilestop() - sliceStart > 10 then coroutine.yield() end
end

local function catalogEntries()
    local H = C_HousingCatalog
    local probe = { api = H ~= nil, searchFn = H and H.CreateCatalogSearcher ~= nil, infoFn = H and H.GetCatalogEntryInfo ~= nil, t = time() }
    if SFP.db then SFP.db.decorProbe = probe end   -- what the game answered, for diagnosis
    if not (H and H.CreateCatalogSearcher and H.GetCatalogEntryInfo) then return nil end
    if not decorSearcher then
        local ok, srch = pcall(H.CreateCatalogSearcher)
        probe.createOk, probe.searcherType = ok, type(srch)
        if not ok or srch == nil then return nil end   -- the searcher may be a table or a game object (userdata)
        for _, m in ipairs({ { "SetOwnedOnly", false }, { "SetCollected", true }, { "SetUncollected", true },
            { "SetAllowedIndoors", true }, { "SetAllowedOutdoors", true } }) do
            if type(srch[m[1]]) == "function" then pcall(srch[m[1]], srch, m[2]) end
        end
        if type(srch.RunSearch) == "function" then pcall(srch.RunSearch, srch) end
        decorSearcher = srch
    end
    probe.searcher = true
    if type(decorSearcher.GetCatalogSearchResults) ~= "function" then return nil end
    local ok, ids = pcall(decorSearcher.GetCatalogSearchResults, decorSearcher)
    probe.results = (ok and type(ids) == "table") and #ids or -1
    if not ok or type(ids) ~= "table" or #ids == 0 then
        -- the catalog fills in a moment after the first search: ask again
        if type(decorSearcher.RunSearch) == "function" then pcall(decorSearcher.RunSearch, decorSearcher) end
        return nil
    end
    local out = {}
    for _, entryID in ipairs(ids) do
        slice()
        local okI, info = pcall(H.GetCatalogEntryInfo, entryID)
        if okI and type(info) == "table" and type(info.name) == "string" and not secret(info.name) then
            local qty = math.max((tonumber(info.quantity) or 0) + (tonumber(info.numPlaced) or 0), (tonumber(info.totalNumStored) or 0) + (tonumber(info.totalNumPlaced) or 0) + (tonumber(info.remainingRedeemable) or 0))
            local eid = type(entryID) == "table" and entryID.recordID or nil
            out[#out + 1] = { name = info.name, owned = qty > 0, source = plainText(info.sourceText), itemID = tonumber(info.itemID), decorID = tonumber(eid) }
        end
    end
    return out
end

-- owned count of one decor item from the game's housing catalog (nil = the game would not say)
local function decorOwned(itemID)
    local H = C_HousingCatalog
    if not (H and H.GetCatalogEntryInfoByItem) then return nil end
    local ok, info = pcall(H.GetCatalogEntryInfoByItem, itemID, true)
    if not ok or type(info) ~= "table" then return nil end
    return math.max((tonumber(info.quantity) or 0) + (tonumber(info.numPlaced) or 0), (tonumber(info.totalNumStored) or 0) + (tonumber(info.totalNumPlaced) or 0) + (tonumber(info.remainingRedeemable) or 0))
end

local function buildDecorEntries()
    local list, byName, byItem, fromGame = {}, {}, {}, false
    for _, d in ipairs(SFP.DecorData or {}) do
        slice()
        local name = d[3] ~= "" and d[3] or ("Decor item " .. d[1])
        local e = { name = name, itemID = d[1] > 0 and d[1] or nil, decorID = d[2] > 0 and d[2] or nil, source = d[4], unknownOwned = true }
        local own = decorOwned(d[1])
        if own ~= nil then e.owned, e.unknownOwned, fromGame = own > 0, false, true end
        e.placeholder = d[3] == ""
        -- a vendor you opened that sells this decor: it is the source when the data has none
        local vl = e.itemID and SFP.db.vendorLearned and SFP.db.vendorLearned[e.itemID]
        if vl and (not e.source or e.source == "") then e.source = "Vendor: " .. tostring(vl.v) end
        list[#list + 1] = e
        byName[name:lower()] = e
        if d[1] > 0 then byItem[d[1]] = e end
    end
    -- decor shipped from a played account: fills names and sources and corrects the data
    for _, d in ipairs(SFP.DecorLearned or {}) do
        slice()
        local name = d[3] ~= "" and d[3] or ("Decor item " .. d[1])
        local old = byItem[d[1]]
        if old then
            if d[3] ~= "" then old.name, old.placeholder = d[3], false; byName[d[3]:lower()] = old end
            if d[4] ~= "" then old.source = d[4] end
            if d[2] > 0 then old.decorID = d[2] end
        elseif not byName[name:lower()] then
            local e = { name = name, itemID = d[1] > 0 and d[1] or nil, decorID = d[2] > 0 and d[2] or nil, source = d[4], unknownOwned = true }
            list[#list + 1] = e
            byName[name:lower()] = e
        end
    end
    -- what the game's catalog lists on top (decor newer than the addon's data), and its owned state
    local cat = catalogEntries()
    if cat then
        fromGame = true
        for _, c in ipairs(cat) do
            slice()
            local e = (c.itemID and byItem[c.itemID]) or byName[c.name:lower()]
            local hadID = e and e.decorID
            local changed = false
            if e then
                e.owned, e.unknownOwned = c.owned, false
                -- the game is right: fill what is empty and fix what differs
                if c.name ~= e.name then e.name, changed = c.name, true end
                if (c.source or "") ~= "" and c.source ~= e.source then e.source, changed = c.source, true end
                if c.decorID and e.decorID ~= c.decorID then e.decorID, changed = c.decorID, true end
                e.placeholder = false
            else
                list[#list + 1] = c
            end
            -- learn what the addon's data lacks (new decor, missing decor IDs); saved with the account data
            if SFP.db and (not e or changed or (c.decorID and not hadID)) then
                SFP.db.learnedDecor = SFP.db.learnedDecor or {}
                local key = c.itemID and tostring(c.itemID) or c.name
                SFP.db.learnedDecor[key] = { item = c.itemID, decor = c.decorID or (e and e.decorID), name = c.name, source = c.source }
            end
        end
    end
    -- the craftable recipes: known or not
    local have = {}
    for _, d in ipairs(DECOR) do
        local ok, has = pcall(function() return IsPlayerSpell and IsPlayerSpell(d[1]) or (IsSpellKnown and IsSpellKnown(d[1])) end)
        if ok and has then have[d[2]:lower()] = true end
    end
    for _, e in ipairs(list) do e.recipeKnown = have[e.name:lower()] end
    for _, e in ipairs(list) do
        slice()
        local src = (e.source or ""):gsub("^Wowhead %- ", "")
        local kind = src:match("^(.-)[:%(]") or src
        kind = strtrim(kind)
        if kind == "" then kind = "Unknown" end
        e.kind = kind:sub(1, 1):upper() .. kind:sub(2)
        -- place: the zone or instance after the last " - ", or the profession of a crafted decor
        local place = src:match(".* %- (.-)$")
        if e.kind == "Crafted" then place = src:match("^Crafted %(([^,%)]+)") end
        -- Wowhead sources name the vendor, quest, achievement or boss itself: that name is the place
        if not place and (e.kind == "Vendor" or e.kind == "Quest" or e.kind == "Achievement" or e.kind == "Drop") then
            place = src:match("^[^:]+:%s*([^;]+)")
            place = place and strtrim(place)
        end
        -- Brewfest, shop and reputation decor go into their own sections even when the place is not known yet
        local low = src:lower()
        if #e.kind > 24 or e.kind:find("%s+by%s") then
            -- a full sentence ("Sold by X (Zone) or Y (Zone)"): file it by what it says
            if low:find("sold by", 1, true) or low:find("vendor", 1, true) then
                e.kind = "Vendor"
                place = src:match("%(([^%)]+)%)") or place
            elseif low:find("quest", 1, true) then e.kind = "Quest"
            elseif low:find("achievement", 1, true) then e.kind = "Achievement"
            elseif low:find("drop", 1, true) then e.kind = "Drop"
            elseif low:find("event", 1, true) or low:find("festival", 1, true) then e.kind = "Event"
            else e.kind = "Other" end
        end
        if low:find("brewfest", 1, true) then
            e.kind, place = "Event", "Brewfest"
        elseif e.kind == "Shop" or e.kind == "Promo" then
            place = src:match("^[^:]+:%s*([^;]+)") or "Blizzard Shop"
        elseif e.kind == "Rep" or e.kind == "Reputation" then
            place = src:match("^[^:]+:%s*([^;%[]+)") or "Reputation"
        end
        e.place = (place and strtrim(place) ~= "") and strtrim(place) or "Unknown"
    end
    table.sort(list, function(x, y) return x.name:lower() < y.name:lower() end)
    decorCache, decorAt = { list = list, fromGame = fromGame }, GetTime()
    return list, fromGame
end

local decorBuilding = false
local function startDecorBuild()
    if decorBuilding then return end
    decorBuilding = true
    local co = coroutine.create(buildDecorEntries)
    local function step()
        sliceStart = debugprofilestop and debugprofilestop() or 0
        local ok, err = coroutine.resume(co)
        if not ok then
            decorBuilding = false
            geterrorhandler()(err)
        elseif coroutine.status(co) == "dead" then
            decorBuilding = false
            if SFP.RefreshDecorWindow then SFP.RefreshDecorWindow() end
            if SFP.DecorPlanChanged then SFP.DecorPlanChanged() end
        else
            C_Timer.After(0, step)
        end
    end
    step()
end

-- the list is built in the background; until it is ready the last one (or an empty one) is returned
local function decorEntries()
    if decorCache and GetTime() - decorAt < 60 then return decorCache.list, decorCache.fromGame end
    startDecorBuild()
    if decorCache then return decorCache.list, decorCache.fromGame end
    return {}, false
end

-- the map of a place named in a decor source ("Dornogal", "Tiragarde Sound"): zones the addon knows, by name
local placeMaps
function SFP:MapForPlace(place)
    if not place or place == "" then return nil end
    if not placeMaps then
        placeMaps = {}
        for mapID in pairs(self.zoneByMap or {}) do
            local nm = self:ZoneName(mapID)
            if nm then placeMaps[nm:lower()] = mapID end
        end
    end
    local p = place:lower()
    if placeMaps[p] then return placeMaps[p] end
    for nm, mapID in pairs(placeMaps) do
        if #nm >= 5 and p:find(nm, 1, true) then return mapID end
    end
end

-- the best waypoint for a decor: the exact spot of a vendor or boss named in its source (Wowhead positions), else the middle of a known zone
function SFP:DecorWaypointFor(e)
    -- a vendor you opened that sells it: the place you stood at (learned from every vendor window)
    local vl = e and e.itemID and self.db.vendorLearned and self.db.vendorLearned[e.itemID]
    if vl and vl.m and vl.x then return vl.m, vl.x, vl.y, tostring(vl.v), true end
    local src = (e and e.source) or ""
    for kind, names in src:gmatch("(%a+): ([^;]+)") do
        if kind == "Vendor" or kind == "Drop" then
            local name = strtrim(names)
            local npc = self.DecorNPCs and self.DecorNPCs[name]
            if npc then return npc.map, npc.x, npc.y, name, true end
        end
    end
    if e and e.kind ~= "Crafted" then
        local map = self:MapForPlace(e.place)
        if map then return map, 0.5, 0.5, e.name, false end
    end
end

-- all decor entries (the addon's data plus what the game's catalog adds), for the housing planner
function SFP:DecorEntries()
    return (decorEntries())
end

-- learning needs no window: reads the housing catalog by itself
function SFP:LearnDecor()
    decorCache = nil
    startDecorBuild()
end

-- the game's housing dashboard (the decor catalog window) has the data loaded: learn from it whenever it opens
-- the housing dashboard and the decor catalog (storage) windows: the decor planner opens with them
local DASH_FRAMES = { "HousingDashboardFrame", "HousingFrame", "HousingCatalogFrame", "HouseEditorFrame", "HousingStorageFrame" }
local dashHooked = {}
local function hookDashboard()
    for _, name in ipairs(DASH_FRAMES) do
        local f = _G[name]
        if not dashHooked[name] and f and f.HookScript then
            dashHooked[name] = true
            f:HookScript("OnShow", function()
                C_Timer.After(1.5, function() SFP:Safe("decor learning", SFP.LearnDecor, SFP) end)
                C_Timer.After(6, function() SFP:Safe("decor learning", SFP.LearnDecor, SFP) end)
                if SFP.db and SFP.db.decorWithHousing ~= false then SFP:Safe("decor window", SFP.ShowDecor, SFP) end
            end)
            if f:IsShown() then SFP:Safe("decor learning", SFP.LearnDecor, SFP) end
        end
    end
end
local dashFrame = CreateFrame("Frame")
pcall(dashFrame.RegisterEvent, dashFrame, "ADDON_LOADED")
pcall(dashFrame.RegisterEvent, dashFrame, "PLAYER_ENTERING_WORLD")
dashFrame:SetScript("OnEvent", function() C_Timer.After(1, hookDashboard) end)
C_Timer.NewTicker(10, hookDashboard)

local decorKind, decorPlace
local decorFilterBox

local function decorList(counts, order, current, onPick, total)
    local items = { { text = "", buttons = { { (current == nil and "|cff40ff40" or "") .. "All (" .. total .. ")", 168, function() onPick(nil) end } } } }
    for _, k in ipairs(order) do
        items[#items + 1] = { text = "", buttons = { { (current == k and "|cff40ff40" or "") .. k .. " (" .. counts[k] .. ")", 168, function() onPick(k) end } } }
    end
    return items
end

local function decorRefresh()
    if not decorWin or not decorWin:IsShown() then return end
    local list, fromGame = decorEntries()
    local filter = (decorBox:GetText() or ""):lower()
    local own = 0
    local kc, korder, pc, porder = {}, {}, {}, {}
    for _, e in ipairs(list) do
        if e.owned then own = own + 1 end
        if not kc[e.kind] then kc[e.kind] = 0; korder[#korder + 1] = e.kind end
        kc[e.kind] = kc[e.kind] + 1
    end
    table.sort(korder, function(x, y) return kc[x] > kc[y] end)
    -- the places depend on the chosen type
    for _, e in ipairs(list) do
        if not decorKind or e.kind == decorKind then
            if not pc[e.place] then pc[e.place] = 0; porder[#porder + 1] = e.place end
            pc[e.place] = pc[e.place] + 1
        end
    end
    table.sort(porder, function(x, y) if pc[x] ~= pc[y] then return pc[x] > pc[y] end return x < y end)
    decorWin.kinds:Set(decorList(kc, korder, decorKind, function(k) decorKind = k; decorPlace = nil; decorRefresh() end, #list))
    local ptotal = 0
    for _, n in pairs(pc) do ptotal = ptotal + n end
    decorWin.places:Set(decorList(pc, porder, decorPlace, function(k) decorPlace = k; decorRefresh() end, ptotal))

    local plan = SFP.db.decorPlan or {}
    local function planIndex(e)
        for i, p in ipairs(plan) do
            if (e.itemID and p.id == e.itemID) or (not e.itemID and p.name == e.name) then return i end
        end
    end
    local items, shown = {}, 0
    for _, e in ipairs(list) do
        local pass = (decorMode == "all") or (decorMode == "missing" and not e.owned and not e.unknownOwned) or (decorMode == "owned" and e.owned)
        if pass and decorKind and e.kind ~= decorKind then pass = false end
        if pass and decorPlace and e.place ~= decorPlace then pass = false end
        if pass and filter ~= "" then
            pass = e.name:lower():find(filter, 1, true) or (e.source or ""):lower():find(filter, 1, true)
        end
        if pass then
            shown = shown + 1
            if shown <= 300 then
                local state = e.unknownOwned and "|cff808080owned?|r" or (e.owned and "|cff40ff40owned|r" or "|cffff6060missing|r")
                items[#items + 1] = {
                    -- tick = in your housing plan: tick the decor you want, untick to take it out
                    check = planIndex(e) ~= nil,
                    onToggle = function(on)
                        SFP.db.decorPlan = SFP.db.decorPlan or {}
                        local pl = SFP.db.decorPlan
                        local idx
                        for i, p in ipairs(pl) do
                            if (e.itemID and p.id == e.itemID) or (not e.itemID and p.name == e.name) then idx = i end
                        end
                        if on and not idx then table.insert(pl, { id = e.itemID, name = e.name })
                        elseif not on and idx then table.remove(pl, idx) end
                        if SFP.DecorPlanChanged then SFP.DecorPlanChanged() end   -- the planner page updates at once
                    end,
                    text = state .. " " .. e.name .. ((e.source and e.source ~= "") and ("  |cff808080" .. e.source:sub(1, 80) .. "|r") or ""),
                }
            end
        end
    end
    decorWin.head:SetText(("|cffffd100%d shown|r"):format(shown) .. (decorKind and ("  type: " .. decorKind) or "") .. (decorPlace and ("  place: " .. decorPlace) or "") ..
        "  |cff808080- tick a decor to add it to your housing plan (Housing Decor page)|r" .. (shown > 300 and "  |cff808080(first 300, narrow it down)|r" or "") ..
        "\n|cff808080" .. #list .. " decor items. " .. (fromGame and ("You own " .. own .. " (read from the game).") or "Owned is unknown: the game's housing catalog could not be read.") .. "|r")
    decorWin.results:Set(items)
    for _, bt in ipairs(decorBtns) do bt:SetText((bt.mode == decorMode and "|cff40ff40" or "") .. bt.label) end
end

-- the planner page asks the list window to redraw at once when the plan changes
SFP.RefreshDecorWindow = function() if decorWin and decorWin:IsShown() then decorRefresh() end end

function SFP:ShowDecor()
    if not decorWin then
        decorWin = window("SeviathsUsefulToolsDecor", "Housing decor - all of it, and where to get it", 820, 580)
        decorWin.scroll:Hide()
        decorWin.head = decorWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        decorWin.head:SetPoint("TOPLEFT", 216, -64)
        decorWin.head:SetWidth(590)
        decorWin.head:SetJustifyH("LEFT")
        decorWin.results = SFP.MakeRowList(decorWin, 212, -96, 600, 464, 20)
        local sl = decorWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sl:SetPoint("TOPLEFT", 216, -40)
        sl:SetText("Search:")
        decorBox = CreateFrame("EditBox", nil, decorWin, "InputBoxTemplate")
        decorBox:SetSize(230, 20)
        decorBox:SetPoint("TOPLEFT", 270, -37)
        decorBox:SetAutoFocus(false)
        decorBox:SetScript("OnTextChanged", function() decorRefresh() end)
        decorBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); decorRefresh() end)
        decorBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local x = 520
        for _, m in ipairs({ { "all", "All", 50 }, { "missing", "Missing", 70 }, { "owned", "Owned", 60 } }) do
            local bt = CreateFrame("Button", nil, decorWin, "UIPanelButtonTemplate")
            bt:SetSize(m[3], 22)
            bt:SetPoint("TOPLEFT", x, -36)
            bt.mode, bt.label = m[1], m[2]
            bt:SetText(m[2])
            bt:SetScript("OnClick", function() decorMode = m[1]; decorRefresh() end)
            decorBtns[#decorBtns + 1] = bt
            x = x + m[3] + 4
        end
        local l1 = decorWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        l1:SetPoint("TOPLEFT", 14, -36)
        l1:SetText("Type (quest, crafted, drop ...):")
        decorWin.kinds = SFP.MakeRowList(decorWin, 10, -52, 196, 190, 22)
        local l2 = decorWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        l2:SetPoint("TOPLEFT", 14, -252)
        l2:SetText("Place (zone, instance, profession):")
        decorWin.places = SFP.MakeRowList(decorWin, 10, -268, 196, 300, 22)
        local acc = 0
        decorWin:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc < 5 then return end
            acc = 0
            SFP:Safe("decor", decorRefresh)
        end)
    end
    -- opened from the menu: sits right next to the main menu
    local mf = self.MenuFrame and self:MenuFrame()
    local saved = SFP.db and SFP.db.windowPos and SFP.db.windowPos["SeviathsUsefulToolsDecor"]
    if mf and mf:IsShown() and not decorWin:IsShown() and not saved then
        decorWin:ClearAllPoints()
        decorWin:SetPoint("TOPLEFT", mf, "TOPRIGHT", 6, 0)
        decorWin:SetClampedToScreen(true)
    end
    decorWin:Show()
    decorRefresh()
end

---------------------------------------------------------------------------
-- 8. achievement planner
---------------------------------------------------------------------------
local achWin, achBox, achResults, achRows, achAddBtn, achResRows = nil, nil, {}, nil, nil, nil
local achCur
local npcIndex

local function npcWhere(npcID)
    if not npcIndex then
        npcIndex = {}
        for mapID, list in pairs(SFP.Rares or {}) do
            for _, sp in ipairs(type(list) == "table" and list or {}) do
                if sp.npc and sp.npc > 0 and sp.hx then npcIndex[sp.npc] = { map = mapID, x = sp.hx, y = sp.hy, name = sp.name } end
            end
        end
        for mapID, list in pairs(SFP.Spawns or {}) do
            for _, sp in ipairs(type(list) == "table" and list or {}) do
                if sp.npc and sp.npc > 0 and sp.hx and not npcIndex[sp.npc] then npcIndex[sp.npc] = { map = mapID, x = sp.hx, y = sp.hy, name = sp.name } end
            end
        end
    end
    return npcIndex[npcID]
end

-- an instance of the addon's data that the text talks about (raid / dungeon achievements)
local function achInstance(text)
    local best
    for _, exp in ipairs(SFP.Expansions or {}) do
        for _, inst in ipairs(exp.instances or {}) do
            if inst.name and text:find(inst.name, 1, true) and (not best or #inst.name > #best.name) then best = inst end
        end
    end
    return best
end

-- the zone that the text names (longest name wins), for an estimate waypoint
local function achZone(text)
    local bestMap, bestLen
    for mapID in pairs(SFP.zoneByMap or {}) do
        local zn = SFP:ZoneName(mapID)
        if type(zn) == "string" and #zn >= 5 and text:find(zn, 1, true) and (not bestLen or #zn > bestLen) then bestMap, bestLen = mapID, #zn end
    end
    return bestMap
end

local function achDetail(id)
    local ok, _, name, points, completed, _, _, _, desc = pcall(GetAchievementInfo, id)
    if not ok or not name then return "Could not read that achievement.", nil end
    local lines = { "|cffffd100" .. name .. "|r  |cff808080" .. (points or 0) .. " points|r" }
    if desc and desc ~= "" then lines[#lines + 1] = desc end
    if completed then lines[#lines + 1] = "|cff40ff40Completed on this account.|r"; return table.concat(lines, "\n"), nil end
    local n = GetAchievementNumCriteria and GetAchievementNumCriteria(id) or 0
    local left, done, firstWhere = {}, 0, nil
    local blob = { name, desc or "" }
    for i = 1, n do
        local ok2, cname, ctype, ccomplete, qty, req, _, _, assetID = pcall(GetAchievementCriteriaInfo, id, i)
        if ok2 then
            if ccomplete then done = done + 1
            else
                local where = (ctype == 0 and assetID and assetID > 0) and npcWhere(assetID) or nil
                local label = (cname and cname ~= "") and cname or ("step " .. i)
                if cname and cname ~= "" and not secret(cname) then blob[#blob + 1] = cname end
                local prog = (req and req > 1) and ("  " .. (qty or 0) .. "/" .. req) or ""
                local loc = where and ("  |cff80ff80" .. SFP:ZoneName(where.map) .. (where.x and (" %.1f, %.1f"):format(where.x * 100, where.y * 100) or "") .. "|r") or ""
                left[#left + 1] = "• " .. label .. prog .. loc
                if where and not firstWhere then firstWhere = where; firstWhere.label = label end
            end
        end
    end
    lines[#lines + 1] = ("%d of %d steps done, %d left:"):format(done, n, n - done)
    for i = 1, math.min(25, #left) do lines[#lines + 1] = left[i] end
    if #left > 25 then lines[#lines + 1] = "+" .. (#left - 25) .. " more" end
    local codexQuery
    if firstWhere then
        lines[#lines + 1] = "\n|cffffd100Do first:|r " .. firstWhere.label .. " - the nearest step with a known place (button: waypoint)."
    else
        local text = table.concat(blob, " ")
        local inst = achInstance(text)
        local low = text:lower()
        if inst or low:find("raid", 1, true) or low:find("dungeon", 1, true) then
            -- raid and dungeon achievements: the bosses, loot and entrance are in the Codex
            codexQuery = inst and inst.name or name
            if inst then
                local e = SFP.FindEntrance and SFP:FindEntrance(inst)
                if e then firstWhere = { map = e.map, x = e.x, y = e.y, label = inst.name .. " (entrance)" } end
            end
            lines[#lines + 1] = "\n|cffffd100Raid / dungeon achievement:|r the bosses, abilities, loot and the way in are in the Codex (button: Codex info)" ..
                (firstWhere and "; the waypoint goes to the entrance." or ".")
        else
            -- other achievements: an estimate, the middle of the zone the text names
            local map = achZone(text)
            if map then
                firstWhere = { map = map, x = 0.5, y = 0.5, label = SFP:ZoneName(map) .. " (estimate)", estimate = true }
                lines[#lines + 1] = "\n|cffffd100Estimate:|r this achievement names " .. SFP:ZoneName(map) .. "; the waypoint goes to the middle of that zone, not to an exact spot."
            end
        end
    end
    -- the first thing to read: where to go
    local go
    if firstWhere and firstWhere.estimate then
        go = "|cffffd100Where to go (estimate):|r the middle of " .. SFP:ZoneName(firstWhere.map)
    elseif firstWhere then
        go = ("|cffffd100Where to go:|r %s, %s%s"):format(firstWhere.label or "first step", SFP:ZoneName(firstWhere.map),
            firstWhere.x and (" %.1f, %.1f"):format(firstWhere.x * 100, firstWhere.y * 100) or "")
    elseif codexQuery then
        go = "|cffffd100Where to go:|r see the Codex (button: Codex info) for the dungeon or raid, its entrance and its bosses."
    else
        go = "|cffffd100Where to go:|r the addon does not know a place for this achievement yet."
    end
    table.insert(lines, 2, go)
    return table.concat(lines, "\n"), firstWhere, codexQuery
end

local achWay, achCodexQ, achWayBtn, achCodexBtn

-- the saved list lives with the addon's data: { { id =, name = }, ... }
local function achData()
    SFP.db.achList = SFP.db.achList or {}
    return SFP.db.achList
end

local function achIndex(id)
    for i, e in ipairs(achData()) do if e.id == id then return i end end
end

local function achProgress(id)
    local ok, _, name, _, completed = pcall(GetAchievementInfo, id)
    if not ok or not name then return nil end
    local n = GetAchievementNumCriteria and GetAchievementNumCriteria(id) or 0
    local done = 0
    for i = 1, n do
        local ok2, _, _, ccomplete = pcall(GetAchievementCriteriaInfo, id, i)
        if ok2 and ccomplete then done = done + 1 end
    end
    return name, completed, n, done
end

local function achOpen(id, name)
    achCur = { id = id, name = name }
    local text, where, cq = achDetail(id)
    achWay, achCodexQ = where, cq
    if achWayBtn then
        achWayBtn:SetText(where and where.estimate and "Waypoint (estimate)" or "Waypoint to first step")
        achWayBtn:SetEnabled(where ~= nil)
    end
    if achCodexBtn then achCodexBtn:SetEnabled(cq ~= nil) end
    achWin:SetContent(text)
    SFP:AchRefreshList()
end

function SFP:AchRefreshList()
    if not achWin then return end
    local items = {}
    for _, e in ipairs(achData()) do
        local name, completed, n, done = achProgress(e.id)
        local state = completed and "|cff40ff40completed|r" or (n and n > 0 and ("|cff808080" .. done .. "/" .. n .. " steps|r") or "")
        local id, saved = e.id, e.name
        items[#items + 1] = {
            text = (name or saved or ("#" .. id)) .. "  " .. state,
            check = true,
            onToggle = function(on)
                if not on then
                    local i = achIndex(id)
                    if i then table.remove(achData(), i) end
                end
                SFP:AchRefreshList()
            end,
            buttons = {
                { "Open info", 80, function() achOpen(id, name or saved) end },
            },
        }
    end
    achRows:Set(items)
    if SFP.AchShowResults then SFP:AchShowResults() end
    if achAddBtn then
        achAddBtn:SetEnabled(achCur ~= nil)
        achAddBtn:SetText((achCur and achIndex(achCur.id)) and "Remove from list" or "Add to list")
    end
end

local achFound, achQuery = {}, ""

-- the search results: tick one to put it in your list, untick to take it out
function SFP:AchShowResults()
    if not achResRows then return end
    local items = {}
    for _, e in ipairs(achFound) do
        local id = tonumber(e.id) or 0
        local name = e.name
        items[#items + 1] = {
            text = name .. "  |cff808080#" .. tostring(e.id) .. "|r",
            check = achIndex(id) ~= nil,
            onToggle = function(on)
                local i = achIndex(id)
                if on and not i then
                    achData()[#achData() + 1] = { id = id, name = name }
                elseif not on and i then
                    table.remove(achData(), i)
                end
                SFP:AchRefreshList()
            end,
            buttons = { { "Open info", 80, function() achOpen(id, name) end } },
        }
    end
    if #items == 0 and achQuery and #achQuery >= 3 then
        items[1] = { text = "|cff808080" .. (achAll and "No achievement matches that." or "Reading the achievement list...") .. "|r", buttons = {} }
    elseif #items > 0 then
        table.insert(items, 1, { text = "|cff808080" .. #items .. " found - tick the ones you want|r", buttons = {} })
    end
    achResRows:Set(items)
end

-- every achievement of the game (id and name), read once in small steps; the search does not depend on the Codex being indexed
local achAll, achReading
local function achReadAll()
    if achAll or achReading then return end
    achReading = true
    local idx, seen = {}, {}
    local cats = (GetCategoryList and GetCategoryList()) or {}
    local ci, ai = 1, 1
    local step
    local function stepInner()
        local t0 = debugprofilestop()
        while ci <= #cats do
            local n = (GetCategoryNumAchievements and GetCategoryNumAchievements(cats[ci], true)) or 0
            while ai <= n do
                local ok, id, name = pcall(GetAchievementInfo, cats[ci], ai)
                if ok and id and not seen[id] and type(name) == "string" and not secret(name) then
                    seen[id] = true
                    idx[#idx + 1] = { id = id, name = name, lname = name:lower() }
                end
                ai = ai + 1
                if debugprofilestop() - t0 > 12 then C_Timer.After(0, step); return end
            end
            ci, ai = ci + 1, 1
        end
        achAll, achReading = idx, false
        if achBox then
            local fn = achBox:GetScript("OnTextChanged")
            if fn then fn(achBox) end
        end
    end
    -- an error while reading ends the reading with what was read so far (and is reported), instead of leaving "Reading the achievement list..." for ever
    step = function()
        local ok, err = pcall(stepInner)
        if not ok then
            if SFP.CatchError then SFP:CatchError("achievement list", err) end
            achAll, achReading = idx, false
            if achBox then local fn = achBox:GetScript("OnTextChanged"); if fn then pcall(fn, achBox) end end
        end
    end
    step()
end

local function achSearch(text)
    achFound = {}
    achQuery = text or ""
    local q = (text or ""):lower()
    if #q >= 3 then
        if achAll then
            for _, e in ipairs(achAll) do
                if e.lname:find(q, 1, true) then
                    achFound[#achFound + 1] = e
                    if #achFound >= 200 then break end
                end
            end
        else
            achReadAll()
            -- until the list is read, the Codex answers if it already has the achievements
            local _, ns = SFP_Module("Codex")
            if ns and ns.Search then
                local ok, res = pcall(ns.Search, ns, text, "achievement", 8)
                if ok and type(res) == "table" then achFound = res end
            end
        end
    end
    SFP:AchShowResults()
end

function SFP:ShowAchPlanner()
    if not achWin then
        achWin = window("SeviathsUsefulToolsAch", "Achievement planner", 560, 720)
        achWin.scroll:SetPoint("TOPLEFT", 12, -500)
        achBox = CreateFrame("EditBox", nil, achWin, "InputBoxTemplate")
        achBox:SetSize(220, 22)
        achBox:SetPoint("TOPLEFT", 22, -34)
        achBox:SetAutoFocus(false)
        achBox:SetScript("OnTextChanged", function(self)
            local ok, err = pcall(achSearch, self:GetText())
            if not ok then SFP:Print("Achievement search error: " .. tostring(err)) end
        end)
        achBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        achAddBtn = CreateFrame("Button", nil, achWin, "UIPanelButtonTemplate")
        achAddBtn:SetSize(120, 22)
        achAddBtn:SetPoint("LEFT", achBox, "RIGHT", 10, 0)
        achAddBtn:Hide()   -- the tick boxes of the results add and remove now
        achAddBtn:SetText("Add to list")
        achAddBtn:SetScript("OnClick", function()
            if not achCur then return end
            local i = achIndex(achCur.id)
            if i then table.remove(achData(), i) else achData()[#achData() + 1] = { id = achCur.id, name = achCur.name } end
            SFP:AchRefreshList()
        end)
        local way = CreateFrame("Button", nil, achWin, "UIPanelButtonTemplate")
        achWayBtn = way
        way:SetSize(160, 22)
        way:SetPoint("LEFT", achBox, "RIGHT", 10, 0)
        way:SetText("Waypoint to first step")
        way:SetEnabled(false)
        achCodexBtn = CreateFrame("Button", nil, achWin, "UIPanelButtonTemplate")
        achCodexBtn:SetSize(100, 22)
        achCodexBtn:SetPoint("LEFT", way, "RIGHT", 6, 0)
        achCodexBtn:SetText("Codex info")
        achCodexBtn:SetEnabled(false)
        achCodexBtn:SetScript("OnClick", function()
            local okM, _, cns = pcall(SFP_Module, "Codex")
            if okM and cns and cns.Toggle and achCodexQ then
                if cns.StartIndexing then cns:StartIndexing() end
                cns:Toggle(achCodexQ)
            else
                SFP:Print("The Codex is not loaded.")
            end
        end)
        way:SetScript("OnClick", function()
            if achWay and SFP.SetWaypoint then SFP:SetWaypoint(achWay.map, achWay.x, achWay.y, achWay.label) end
        end)
        achResRows = SFP.MakeRowList(achWin, 18, -62, 530, 180, 20)
        achReadAll()
        local label = achWin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", 22, -252)
        label:SetText("Your list (saved - tick to keep, untick to remove):")
        local function bulk(text, x, add)
            local b = CreateFrame("Button", nil, achWin, "UIPanelButtonTemplate")
            b:SetSize(120, 20)
            b:SetPoint("TOPLEFT", x, -246)
            b:SetText(text)
            b:SetScript("OnClick", function()
                for _, e in ipairs(achFound) do
                    local id = tonumber(e.id) or 0
                    local i = achIndex(id)
                    if add and not i then
                        achData()[#achData() + 1] = { id = id, name = e.name }
                    elseif not add and i then
                        table.remove(achData(), i)
                    end
                end
                SFP:AchRefreshList()
            end)
        end
        bulk("Add all shown", 300, true)
        bulk("Remove all shown", 424, false)
        achRows = SFP.MakeRowList(achWin, 18, -274, 530, 210, 20)
        achWin:SetContent("Type part of an achievement name above, tick the ones you want in your list (untick to remove them); press Open info on any of them to see its details and press Open info to see what is left and where to go. You get what is left, where each step is when the addon knows the place, and what to do first. The list is saved and shows your progress each time you open this window.")
        achWin:HookScript("OnShow", function() SFP:Safe("ach list", SFP.AchRefreshList, SFP) end)
    end
    achWin:Show()
    self:AchRefreshList()
end

-- curios and decor are learned automatically (silent; the delve planner button reads the curios again with a report)
SFP:OnLogin(function()
    -- everything is learned by itself: a minute after login, then every 15 minutes while you play
    local function learnAll()
        SFP:Safe("curio scan", SFP.ScanOwnedCurios, SFP)
        SFP:Safe("decor learning", SFP.LearnDecor, SFP)
    end
    C_Timer.After(45, learnAll)
    C_Timer.NewTicker(900, learnAll)
    -- the curios are also read when the companion window is opened or closed (that is where they are changed)
    local curioHooked = false
    local function hookCompanionWindow()
        local fr = _G.DelvesCompanionConfigurationFrame
        if curioHooked or not (fr and fr.HookScript) then return end
        curioHooked = true
        local function scanSoon() C_Timer.After(1.5, function() SFP:Safe("curio scan", SFP.ScanOwnedCurios, SFP) end) end
        fr:HookScript("OnShow", scanSoon)
        fr:HookScript("OnHide", scanSoon)
    end
    hookCompanionWindow()
    local cf = CreateFrame("Frame")
    cf:RegisterEvent("ADDON_LOADED")
    cf:RegisterEvent("TRAIT_CONFIG_UPDATED")
    local lastTraitScan = 0
    cf:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == "Blizzard_DelvesCompanionConfiguration" then hookCompanionWindow() end
        elseif GetTime() - lastTraitScan > 3 then
            -- a curio changed in the companion's trait tree
            local fr = _G.DelvesCompanionConfigurationFrame
            if fr and fr.IsShown and fr:IsShown() then
                lastTraitScan = GetTime()
                C_Timer.After(1, function() SFP:Safe("curio scan", SFP.ScanOwnedCurios, SFP) end)
            end
        end
    end)
    -- the achievement planner's search list is read in the background, so it is ready when you open the window
    C_Timer.After(25, function() SFP:Safe("achievement list", achReadAll) end)
end)
