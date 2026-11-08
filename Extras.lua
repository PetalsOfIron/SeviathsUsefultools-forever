-- SeviathsUsefulTools - extras
--   1. rares you killed today are greyed out on the map until the daily reset      (SFP:NoteKill / RareKilledToday)
--   2. farm session tracker: /sfp session                                         (kills, gold, loot value, per hour)
--   3. "what should I farm next?": /sfp next                                      (missing mounts / pets / toys of rares)
--   4. export / import of what the addon learned: /sfp export, /sfp import        (a copy-paste string)
-- Everything here only reads and writes the addon's own saved data.

local _, SFP = ...

local function secret(v) return issecretvalue and issecretvalue(v) end
local function money(c)
    c = math.floor((c or 0) + 0.5)
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return math.floor(c / 10000) .. "g"
end

---------------------------------------------------------------------------
-- 1. rares killed today
---------------------------------------------------------------------------
local function charKey()
    return (UnitName("player") or "?") .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or "?"):gsub("[%s%-']", ""))
end

local function lastDailyReset()
    local secs = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if type(secs) ~= "number" then return time() - 7 * 86400 end
    return time() + secs - 7 * 86400
end

-- called by Collector when a kill is looted
function SFP:NoteKill(npcID)
    if not (self.db and npcID) then return end
    self.db.killed = self.db.killed or {}
    local k = self.db.killed[charKey()]
    if not k then k = {}; self.db.killed[charKey()] = k end
    k[npcID] = time()
    -- forget kills older than two weeks
    local old = time() - 14 * 86400
    for id, t in pairs(k) do if t < old then k[id] = nil end end
    if self.RefreshWorldMap then pcall(self.RefreshWorldMap) end
    if self.session then self.session.kills = self.session.kills + 1 end
end

-- every rare killed this week (since the weekly reset), per character: { char, name, zone, t }
function SFP:KilledTodayList()
    local out = {}
    local reset = lastDailyReset()
    local byNpc = {}
    for mapID, list in pairs(self.Rares or {}) do
        for _, sp in ipairs(type(list) == "table" and list or {}) do
            if sp.npc and sp.npc > 0 then byNpc[sp.npc] = { name = sp.name, map = mapID } end
        end
    end
    for char, kills in pairs(self.db and self.db.killed or {}) do
        for npcID, t in pairs(kills) do
            local known = byNpc[npcID]
            local rec = self.db.npcs and self.db.npcs[npcID]
            local isRare = known or (rec and (rec.c == "rare" or rec.c == "rareelite" or rec.c == "worldboss" or rec.boss))
            if t >= reset and isRare then
                local map = known and known.map or (rec and rec.m and next(rec.m))
                out[#out + 1] = {
                    char = char, npc = npcID, t = t,
                    name = (known and known.name) or (rec and rec.n) or ("NPC " .. npcID),
                    zone = map and self:ZoneName(map) or "",
                    rare = known ~= nil,
                }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.char ~= b.char then return a.char < b.char end
        return a.t > b.t
    end)
    return out
end

-- forget what this character killed today (the greyed rares come back)
function SFP:ClearKilled()
    if self.db and self.db.killed then self.db.killed[charKey()] = nil end
    if self.RefreshWorldMap then pcall(self.RefreshWorldMap) end
    self:Print("Today's kills forgotten - the rares are shown again.")
end

function SFP:RareKilledToday(npcID)
    local k = self.db and self.db.killed and self.db.killed[charKey()]
    local t = k and k[npcID]
    return t and t >= lastDailyReset() or false
end

---------------------------------------------------------------------------
-- 2. farm session
---------------------------------------------------------------------------
local frame, text
local lastLootT = 0

local function sessionTotals()
    local s = SFP.session
    if not s then return end
    local now = s.stop or time()
    local secs = math.max(1, now - s.t0)
    local total = s.gold + s.itemValue
    return secs, total, total * 3600 / secs
end

local function fmtTime(secs)
    return ("%d:%02d:%02d"):format(math.floor(secs / 3600), math.floor(secs / 60) % 60, secs % 60)
end

local function sessionText()
    local s = SFP.session
    if not s then return "No session yet. /sfp session starts one, /sfp session stop ends it." end
    local secs, total, perHour = sessionTotals()
    return ("Farm session %s%s\nKills: %d   Items: %d\nGold looted: %s\nLoot worth: %s\nTotal: %s   (%s / hour)"):format(
        fmtTime(secs), s.stop and "  (stopped)" or "", s.kills, s.items, money(s.gold), money(s.itemValue), money(total), money(perHour))
end

function SFP:SessionSummary() return sessionText() end

local function buildFrame()
    if frame then return end
    frame = CreateFrame("Frame", "SeviathsUsefulToolsSession", UIParent, "BackdropTemplate")
    frame:SetSize(230, 82)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -220)
    SFP.BlizzardFrame(frame, "small")
    frame:SetBackdropColor(0.08, 0.03, 0.03, 0.95)
    frame:SetBackdropBorderColor(0.9, 0.28, 0.24, 0.7)
    frame:SetMovable(true); frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    SFP.RegisterWindow(frame)   -- remembers where the session window was put
    text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 8, -6)
    text:SetJustifyH("LEFT")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScale(0.7)
    local acc = 0
    frame:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 1 then return end
        acc = 0
        text:SetText(sessionText())
    end)
    frame:Hide()
end

function SFP:SessionStart()
    self.session = { t0 = time(), kills = 0, items = 0, gold = 0, itemValue = 0 }
    if self.Social and self.Social.Count then pcall(self.Social.Count, "session") end   -- for the automatic play style
    buildFrame()
    frame:Show()
    text:SetText(sessionText())
    self:Print("Farm session started. Stop it with /sfp session stop (or the Stop button in the menu, page Farm Session).")
end

function SFP:SessionStop()
    local s = self.session
    if not s or s.stop then self:Print("No running session."); return end
    s.stop = time()
    self:Print((sessionText():gsub("\n", "  |  ")))
    if text then text:SetText(sessionText()) end
end

-- a small movable control: play, stop and show / hide the session window
local ctl
function SFP:ShowSessionControl()
    local justBuilt = false
    if not ctl then
        justBuilt = true
        ctl = CreateFrame("Frame", "SeviathsUsefulToolsSessionControl", UIParent, "BackdropTemplate")
        ctl:SetSize(236, 50)
        local pos = self.db and self.db.sessionCtlPos
        if pos then ctl:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else ctl:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -180) end
        ctl:SetFrameStrata("HIGH")
        SFP.BlizzardFrame(ctl, "small")
        ctl:SetBackdropColor(0.08, 0.03, 0.03, 0.9)
        ctl:SetBackdropBorderColor(0.9, 0.28, 0.24, 0.7)
        ctl:SetMovable(true); ctl:EnableMouse(true); ctl:SetClampedToScreen(true)
        ctl:RegisterForDrag("LeftButton")
        ctl:SetScript("OnDragStart", ctl.StartMoving)
        ctl:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()
            local point, _, rel, x, y = f:GetPoint()
            SFP.db.sessionCtlPos = { point, rel, x, y }
        end)
        local function btn(label, w, x, fn)
            local b = CreateFrame("Button", nil, ctl, "UIPanelButtonTemplate")
            b:SetSize(w, 20)
            b:SetPoint("TOPLEFT", x, -6)
            b:SetText(label)
            b:SetScript("OnClick", fn)
            return b
        end
        btn("Play", 48, 5, function() SFP:SessionStart() end)
        btn("Stop", 48, 56, function() SFP:SessionStop() end)
        btn("Show/Hide", 70, 107, function() SFP:SessionToggle("window") end)
        local close = CreateFrame("Button", nil, ctl, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
        close:SetScale(0.6)
        -- the gold gained in this session (looted gold + what the loot is worth), updated every second
        local gain = ctl:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        gain:SetPoint("BOTTOMLEFT", 8, 5)
        gain:SetJustifyH("LEFT")
        local acc = 0
        local function upd()
            local sess = SFP.session
            if not sess then gain:SetText("|cff808080No session - press Play|r"); return end
            local secs, total, perHour = sessionTotals()
            gain:SetText(("|cffffd100%s|r  Gained: |cffffd100%s|r  (%s/h)%s"):format(fmtTime(secs), money(total), money(perHour), sess.stop and "  |cff808080stopped|r" or ""))
        end
        ctl:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc < 1 then return end
            acc = 0
            upd()
        end)
        upd()
    end
    -- a new window is already visible, so the first click must not toggle it away again
    if not justBuilt then ctl:SetShown(not ctl:IsShown()) else ctl:Show() end
end

function SFP:SessionToggle(arg)
    if arg == "window" then
        buildFrame(); frame:SetShown(not frame:IsShown()); text:SetText(sessionText())
        return
    end
    if arg == "stop" then return self:SessionStop() end
    if arg == "hide" then if frame then frame:Hide() end return end
    if arg == "show" then buildFrame(); frame:Show(); text:SetText(sessionText()); return end
    if self.session and not self.session.stop then
        buildFrame(); frame:SetShown(not frame:IsShown()); text:SetText(sessionText())
    else
        self:SessionStart()
    end
end

-- called by Collector for every looted item slot
function SFP:SessionItem(itemID, qty)
    local s = self.session
    if not s or s.stop or not itemID then return end
    qty = (type(qty) == "number" and not secret(qty) and qty > 0) and qty or 1
    s.items = s.items + qty
    local p = self.GetPrice and self:GetPrice(itemID) or 0
    if not p or p <= 0 then p = select(11, C_Item.GetItemInfo(itemID)) or 0 end
    s.itemValue = s.itemValue + p * qty
end

function SFP:SessionLootOpened() lastLootT = GetTime() end

local gf = CreateFrame("Frame")
pcall(gf.RegisterEvent, gf, "PLAYER_MONEY")
local lastMoney
gf:SetScript("OnEvent", function()
    local now = GetMoney()
    local delta = now - (lastMoney or now)
    lastMoney = now
    local s = SFP.session
    -- money that arrives while a loot window is open is looted gold (not mail, vendor or auction money)
    if s and not s.stop and delta > 0 and GetTime() - lastLootT < 2 then s.gold = s.gold + delta end
end)
SFP:OnLogin(function() lastMoney = GetMoney() end)

---------------------------------------------------------------------------
-- 3. what should I farm next?
---------------------------------------------------------------------------
local function playerPos()
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return map end
    local x, y = pos:GetXY()
    if secret(x) or secret(y) then return map end
    return map, x, y
end

function SFP:FarmNext(limit, mode)
    limit = limit or 5
    mode = mode or self.db.nextSort or "best"
    local pm, px, py = playerPos()
    local list = {}
    for mapID, entries in pairs(self.Rares or {}) do
        if type(entries) == "table" then
            for _, sp in ipairs(entries) do
                if sp.name and sp.items and #sp.items > 0 and sp.points and #sp.points > 0 then
                    local missing = {}
                    for _, itemID in ipairs(sp.items) do
                        local own = self.OwnedStatus and self:OwnedStatus(itemID)
                        if own == false then missing[#missing + 1] = itemID end
                    end
                    if #missing > 0 then
                        local killed = sp.npc and sp.npc > 0 and self:RareKilledToday(sp.npc)
                        local dist
                        if mapID == pm and px then
                            local dx, dy = (sp.hx or sp.points[1][1]) - px, (sp.hy or sp.points[1][2]) - py
                            dist = math.sqrt(dx * dx + dy * dy)
                        end
                        local score = 0
                        for _, id in ipairs(missing) do
                            local k = self.Items and self.Items[id] and self.Items[id].kind
                            score = score + (k == "mount" and 3 or (k == "toy" and 2 or 1))
                        end
                        list[#list + 1] = { sp = sp, map = mapID, missing = missing, killed = killed, dist = dist, score = score }
                    end
                end
            end
        end
    end
    -- available ones first, then same zone nearest first, then more missing items
    table.sort(list, function(a, b)
        if (a.killed and 1 or 0) ~= (b.killed and 1 or 0) then return not a.killed end
        if mode == "best" and a.score ~= b.score then return a.score > b.score end
        if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
        if a.dist and b.dist and math.abs(a.dist - b.dist) > 0.001 then return a.dist < b.dist end
        if #a.missing ~= #b.missing then return #a.missing > #b.missing end
        return (a.sp.name or "") < (b.sp.name or "")
    end)
    local out = {}
    for i = 1, math.min(limit, #list) do out[i] = list[i] end
    return out, #list
end

function SFP:PrintFarmNext()
    local top, total = self:FarmNext(5)
    if #top == 0 then
        self:Print("Nothing to suggest: you have every mount, pet and toy the addon knows from rares (or the collection data is not read yet - /sfp history rescan).")
        return
    end
    self:Print(("Farm next (%d rares still have something you are missing):"):format(total))
    for i, c in ipairs(top) do
        local sp = c.sp
        local names = {}
        for _, id in ipairs(c.missing) do names[#names + 1] = self:ItemName(id) end
        self:Print(("%d. %s - %s%s%s  |  missing: %s"):format(i, sp.name, self:ZoneName(c.map),
            c.dist and ("  (" .. ("%.0f"):format(c.dist * 100) .. " away)") or "",
            c.killed and "  |cff808080killed today|r" or "", table.concat(names, ", ")))
    end
    local first = top[1]
    if first and self.SetWaypoint and first.sp.hx then
        self:SetWaypoint(first.map, first.sp.hx, first.sp.hy, first.sp.name)
        self:Print("Waypoint set to #1.")
    end
end

---------------------------------------------------------------------------
-- 4. export / import of learned data
---------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64enc(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2, c3, c4 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1) ..
            (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end
local B64IDX = {}
for i = 1, #B64 do B64IDX[B64:sub(i, i)] = i - 1 end
local function b64dec(s)
    s = s:gsub("[^%w%+/=]", "")
    local out = {}
    for i = 1, #s, 4 do
        local a, b, c, d = s:sub(i, i), s:sub(i + 1, i + 1), s:sub(i + 2, i + 2), s:sub(i + 3, i + 3)
        local n = (B64IDX[a] or 0) * 262144 + (B64IDX[b] or 0) * 4096 + (B64IDX[c] or 0) * 64 + (B64IDX[d] or 0)
        local bytes = string.char(math.floor(n / 65536) % 256)
        if c ~= "=" then bytes = bytes .. string.char(math.floor(n / 256) % 256) end
        if d ~= "=" then bytes = bytes .. string.char(n % 256) end
        out[#out + 1] = bytes
    end
    return table.concat(out)
end

-- plain data only: numbers, strings, booleans, tables. Format: n<num>; s<len>:<chars>; t/f; {k v k v ...}
local function ser(v, out)
    local t = type(v)
    if t == "number" then out[#out + 1] = "n" .. tostring(v) .. ";"
    elseif t == "string" then out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "boolean" then out[#out + 1] = v and "T" or "F"
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, x in pairs(v) do
            local tk = type(k)
            if (tk == "number" or tk == "string") and (type(x) ~= "function") then ser(k, out); ser(x, out) end
        end
        out[#out + 1] = "}"
    end
end

local function parse(str)
    local pos = 1
    local value
    local function val(depth)
        if depth > 12 then error("too deep") end
        local c = str:sub(pos, pos)
        if c == "n" then
            local num, e = str:match("^n([%-%d%.eE%+]+);()", pos)
            if not num then error("bad number") end
            pos = e
            return tonumber(num)
        elseif c == "s" then
            local len, e = str:match("^s(%d+):()", pos)
            len = tonumber(len)
            if not len or len > 20000 then error("bad string") end
            local s = str:sub(e, e + len - 1)
            pos = e + len
            return s
        elseif c == "T" then pos = pos + 1; return true
        elseif c == "F" then pos = pos + 1; return false
        elseif c == "{" then
            pos = pos + 1
            local t = {}
            while str:sub(pos, pos) ~= "}" do
                if pos > #str then error("unfinished") end
                local k = val(depth + 1)
                local x = val(depth + 1)
                if type(k) == "number" or type(k) == "string" then t[k] = x end
            end
            pos = pos + 1
            return t
        end
        error("bad data at " .. pos)
    end
    value = val(0)
    return value
end

local EXPORT_KEYS = { "npcs", "objects", "knownItems", "recipes", "learned", "itemZones", "learnedCurios", "learnedDecor", "ahItems", "ahNames" }

function SFP:BuildExport()
    local pack = { v = 1 }
    for _, k in ipairs(EXPORT_KEYS) do pack[k] = self.db[k] end
    local out = {}
    ser(pack, out)
    local raw = table.concat(out)
    -- the game's own compression when it has one (smaller to copy)
    local EU = C_EncodingUtil
    if EU and EU.CompressString and EU.EncodeBase64 and Enum and Enum.CompressionMethod then
        local ok, res = pcall(function() return EU.EncodeBase64(EU.CompressString(raw, Enum.CompressionMethod.Deflate)) end)
        if ok and type(res) == "string" then return "SUT2:" .. res end
    end
    return "SUT1:" .. b64enc(raw)
end

local function mergeCounts(dst, src)
    for id, n in pairs(src or {}) do
        if type(n) == "number" then dst[id] = math.max(dst[id] or 0, n) end
    end
end

local function mergePoints(dst, src)
    for map, pts in pairs(src or {}) do
        if type(pts) == "table" then
            dst[map] = dst[map] or {}
            for _, p in ipairs(pts) do
                local dup = false
                for _, q in ipairs(dst[map]) do
                    if math.abs((q[1] or 0) - (p[1] or 0)) < 0.012 and math.abs((q[2] or 0) - (p[2] or 0)) < 0.012 then dup = true; break end
                end
                if not dup and #dst[map] < 15 and type(p[1]) == "number" and type(p[2]) == "number" then dst[map][#dst[map] + 1] = { p[1], p[2] } end
            end
        end
    end
end

-- merge, never replace: counts take the larger value, so importing the same string twice changes nothing
local function mergeRecord(dst, src)
    for k, v in pairs(src) do
        if k == "d" or k == "s" or k == "items" then
            dst[k] = dst[k] or {}
            mergeCounts(dst[k], v)
        elseif k == "m" then
            dst.m = dst.m or {}
            mergePoints(dst.m, v)
        elseif type(v) == "number" then
            dst[k] = math.max(dst[k] or 0, v)
        elseif type(v) == "string" and dst[k] == nil then
            dst[k] = v
        end
    end
end

function SFP:ImportString(str)
    str = (str or ""):gsub("%s", "")
    local tag, body = str:match("^(SUT%d):(.+)$")
    if not tag then return false, "That is not a SeviathsUsefulTools export string." end
    local raw
    if tag == "SUT1" then raw = b64dec(body)
    elseif tag == "SUT2" then
        local EU = C_EncodingUtil
        if not (EU and EU.DecodeBase64 and EU.DecompressString and Enum and Enum.CompressionMethod) then return false, "This game version cannot read that string." end
        local ok, res = pcall(function() return EU.DecompressString(EU.DecodeBase64(body), Enum.CompressionMethod.Deflate) end)
        if not ok or type(res) ~= "string" then return false, "The string is damaged." end
        raw = res
    else return false, "Unknown export version." end
    local ok, pack = pcall(parse, raw)
    if not ok or type(pack) ~= "table" or pack.v ~= 1 then return false, "The string is damaged or from another version." end
    local counts = { npcs = 0, items = 0, nodes = 0, recipes = 0, spots = 0 }
    for id, rec in pairs(pack.npcs or {}) do
        if type(rec) == "table" then
            self.db.npcs[id] = self.db.npcs[id] or {}
            mergeRecord(self.db.npcs[id], rec)
            counts.npcs = counts.npcs + 1
        end
    end
    for id, rec in pairs(pack.objects or {}) do
        if type(rec) == "table" then
            self.db.objects[id] = self.db.objects[id] or {}
            mergeRecord(self.db.objects[id], rec)
            counts.nodes = counts.nodes + 1
        end
    end
    for id, rec in pairs(pack.knownItems or {}) do
        if type(rec) == "table" and self.db.knownItems[id] == nil then self.db.knownItems[id] = rec; counts.items = counts.items + 1 end
    end
    for key, rec in pairs(pack.recipes or {}) do
        if type(rec) == "table" and self.db.recipes[key] == nil then self.db.recipes[key] = rec; counts.recipes = counts.recipes + 1 end
    end
    for map, mobs in pairs(pack.learned or {}) do
        if type(mobs) == "table" then
            self.db.learned[map] = self.db.learned[map] or {}
            for npc, rec in pairs(mobs) do
                if type(rec) == "table" then
                    local dst = self.db.learned[map][npc] or { pts = {}, items = {}, kills = 0, name = rec.name }
                    self.db.learned[map][npc] = dst
                    dst.kills = math.max(dst.kills or 0, rec.kills or 0)
                    mergeCounts(dst.items, rec.items)
                    for _, p in ipairs(rec.pts or {}) do
                        local dup = false
                        for _, q in ipairs(dst.pts) do
                            if math.abs(q[1] - p[1]) < 0.012 and math.abs(q[2] - p[2]) < 0.012 then dup = true; break end
                        end
                        if not dup and #dst.pts < 40 and type(p[1]) == "number" then dst.pts[#dst.pts + 1] = { p[1], p[2] } end
                    end
                    counts.spots = counts.spots + 1
                end
            end
        end
    end
    for id, zones in pairs(pack.itemZones or {}) do
        if type(zones) == "table" then
            self.db.itemZones[id] = self.db.itemZones[id] or {}
            for map, rec in pairs(zones) do
                if type(rec) == "table" then
                    self.db.itemZones[id][map] = self.db.itemZones[id][map] or {}
                    for k, v in pairs(rec) do
                        if type(v) == "number" then self.db.itemZones[id][map][k] = math.max(self.db.itemZones[id][map][k] or 0, v) end
                    end
                end
            end
        end
    end
    for id in SeviathsAllPairs(self.db.knownItems) do pcall(self.ClassifyItem, self, id) end
    if self.ApplyLearned then pcall(self.ApplyLearned, self) end
    if self.RefreshAll then self:RefreshAll() end
    return true, ("Imported: %d monsters, %d nodes, %d items, %d recipes, %d learned spots."):format(
        counts.npcs, counts.nodes, counts.items, counts.recipes, counts.spots)
end

local ioFrame, ioBox, ioTitle, ioButton
local function buildIO()
    if ioFrame then return end
    ioFrame = CreateFrame("Frame", "SeviathsUsefulToolsTransfer", UIParent, "BackdropTemplate")
    ioFrame:SetSize(520, 300)
    ioFrame:SetPoint("CENTER")
    ioFrame:SetFrameStrata("DIALOG")
    SFP.RegisterWindow(ioFrame)
    SFP.BlizzardFrame(ioFrame, true)
    ioFrame:SetBackdropColor(0.08, 0.03, 0.03, 0.95)
    ioFrame:SetBackdropBorderColor(0.9, 0.28, 0.24, 0.8)
    ioFrame:SetMovable(true); ioFrame:EnableMouse(true)
    ioFrame:RegisterForDrag("LeftButton")
    ioFrame:SetScript("OnDragStart", ioFrame.StartMoving)
    ioFrame:SetScript("OnDragStop", ioFrame.StopMovingOrSizing)
    ioTitle = ioFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ioTitle:SetPoint("TOPLEFT", 12, -10)
    local close = CreateFrame("Button", nil, ioFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local scroll = CreateFrame("ScrollFrame", "SeviathsUsefulToolsTransferScroll", ioFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -36)
    scroll:SetPoint("BOTTOMRIGHT", -32, 44)
    ioBox = CreateFrame("EditBox", nil, scroll)
    ioBox:SetMultiLine(true)
    ioBox:SetFontObject("ChatFontNormal")
    ioBox:SetWidth(470)
    ioBox:SetAutoFocus(false)
    ioBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(ioBox)
    ioButton = CreateFrame("Button", nil, ioFrame, "UIPanelButtonTemplate")
    ioButton:SetSize(120, 24)
    ioButton:SetPoint("BOTTOMLEFT", 12, 10)
    ioFrame:Hide()
end

function SFP:ShowExport()
    buildIO()
    local ok, str = pcall(self.BuildExport, self)
    if not ok then self:Print("Export failed: " .. tostring(str)); return end
    ioTitle:SetText("Export - select all (Ctrl+A), copy (Ctrl+C) and send it to a friend")
    ioBox:SetText(str)
    ioBox:HighlightText()
    ioBox:SetFocus()
    ioButton:SetText("Close")
    ioButton:SetScript("OnClick", function() ioFrame:Hide() end)
    ioFrame:Show()
    self:Print(("Export string ready (%d characters)."):format(#str))
end

function SFP:ShowImport()
    buildIO()
    ioTitle:SetText("Import - paste an export string (Ctrl+V), then press Import")
    ioBox:SetText("")
    ioBox:SetFocus()
    ioButton:SetText("Import")
    ioButton:SetScript("OnClick", function()
        local good, msg = SFP:ImportString(ioBox:GetText())
        SFP:Print(msg)
        if good then ioFrame:Hide() end
    end)
    ioFrame:Show()
end

---------------------------------------------------------------------------
-- 5. rare alerts: a sound and a chat line when a rare you still miss something from shows up nearby
---------------------------------------------------------------------------
local alerted = {}
local rareByNpc, rareLoaded = {}, false

local function loadRareIndex()
    if rareLoaded or not SFP.Rares then return end
    rareLoaded = true
    for mapID, list in pairs(SFP.Rares) do
        if type(list) == "table" then
            for _, sp in ipairs(list) do
                if sp.npc and sp.npc > 0 then rareByNpc[sp.npc] = { sp = sp, map = mapID } end
            end
        end
    end
end

local function npcFromGUID(guid)
    if type(guid) ~= "string" or secret(guid) then return nil end
    local t, _, _, _, _, id = strsplit("-", guid)
    if t == "Creature" or t == "Vehicle" then return tonumber(id) end
end

local function checkVignette(vguid)
    if not (SFP.db and SFP.db.rareAlerts ~= false) or secret(vguid) or alerted[vguid] then return end
    if not (C_VignetteInfo and C_VignetteInfo.GetVignetteInfo) then return end
    local ok, info = pcall(C_VignetteInfo.GetVignetteInfo, vguid)
    if not ok or type(info) ~= "table" then return end
    local npc = npcFromGUID(info.objectGUID)
    if not npc then return end
    loadRareIndex()
    local rec = rareByNpc[npc]
    if not rec or SFP:RareKilledToday(npc) then return end
    -- only when you still miss a mount / pet / toy it drops
    local missing = {}
    for _, itemID in ipairs(rec.sp.items or {}) do
        if SFP.OwnedStatus and SFP:OwnedStatus(itemID) == false then missing[#missing + 1] = SFP:ItemName(itemID) end
    end
    if #missing == 0 then return end
    alerted[vguid] = true
    local map = C_Map.GetBestMapForUnit("player") or rec.map
    local x, y
    if C_VignetteInfo.GetVignettePosition then
        local okp, pos = pcall(C_VignetteInfo.GetVignettePosition, vguid, map)
        if okp and pos and pos.GetXY then x, y = pos:GetXY() end
    end
    x, y = x or rec.sp.hx, y or rec.sp.hy
    local link = (x and y) and (" |cffffd100|Haddon:SUT:way:" .. map .. ":" .. x .. ":" .. y .. "|h[set waypoint]|h|r") or ""
    SFP:Print("|cffff9933Rare nearby:|r " .. (rec.sp.name or "?") .. " - you still miss: " .. table.concat(missing, ", ") .. link)
    if SFP.db.rareAlertSound ~= false and PlaySound and SOUNDKIT and SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING then PlaySound(SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING) end
end

local vf = CreateFrame("Frame")
for _, e in ipairs({ "VIGNETTE_MINIMAP_UPDATED", "VIGNETTES_UPDATED" }) do pcall(vf.RegisterEvent, vf, e) end
vf:SetScript("OnEvent", function(_, event, vguid)
    SFP:Safe("rare alert", function()
        if event == "VIGNETTE_MINIMAP_UPDATED" then checkVignette(vguid)
        elseif C_VignetteInfo and C_VignetteInfo.GetVignettes then
            for _, g in ipairs(C_VignetteInfo.GetVignettes() or {}) do checkVignette(g) end
        end
    end)
end)

-- clicking "[set waypoint]" in chat
if SetItemRef then
    hooksecurefunc("SetItemRef", function(link)
        local m, x, y = tostring(link):match("^addon:SUT:way:(%d+):([%d%.]+):([%d%.]+)$")
        if m and SFP.SetWaypoint then SFP:SetWaypoint(tonumber(m), tonumber(x), tonumber(y), "Rare") end
    end)
end
