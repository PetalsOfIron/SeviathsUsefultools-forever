-- SeviathsUsefulTools - tells you in chat (yellow) when something you put on the Auction House has sold
local _, SFP = ...

local YELLOW = "|cffffff00"
local seen = {}   -- invoices already announced this session

local function say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "[Auction House] " .. text .. "|r") end
end

local function money(c)
    if not c or c <= 0 then return "" end
    if GetCoinTextureString then return GetCoinTextureString(c) end
    return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100)
end

-- "A buyer has been found for your auction of %s." -> pattern
local soldPattern
do
    local g = _G.ERR_AUCTION_SOLD_S
    if g then soldPattern = "^" .. g:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"):gsub("%%s", "(.+)") .. "$" end
end

-- Whether an item sells: db.ahOutcome[itemID] = { s = times it sold, e = times an auction of it ran out and came back in the mailbox }.
-- A sale is read from the chat line, an expired auction from the mail "Auction expired: <item>" (kept once per mail).
local nameToID
local function itemIDOf(text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return nil end
    local id = tonumber(text:match("item:(%d+)"))
    if id then return id end
    local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%[", ""):gsub("%]$", "")
    if not nameToID then
        nameToID = {}
        for iid, n in pairs((SFP.db and SFP.db.ahNames) or {}) do nameToID[n] = iid end
    end
    return nameToID[plain]
end

local function noteOutcome(itemID, field)
    if type(itemID) ~= "number" or not SFP.db then return end
    SFP.db.ahOutcome = SFP.db.ahOutcome or {}
    local o = SFP.db.ahOutcome[itemID]
    if type(o) ~= "table" then o = {}; SFP.db.ahOutcome[itemID] = o end
    o[field] = (o[field] or 0) + 1
    o.t = time()
end

-- expired auctions waiting in the mailbox (each mail counted once, also across sessions: the day the mail ends is the key)
local function scanExpired()
    if not (GetInboxNumItems and GetInboxHeaderInfo and GetInboxItemLink) then return end
    local subj = _G.AUCTION_EXPIRED_MAIL_SUBJECT   -- "Auction expired: %s"
    if type(subj) ~= "string" then return end
    local prefix = subj:match("^(.-)%%s")
    if not prefix or prefix == "" then return end
    SFP.db.ahMailSeen = SFP.db.ahMailSeen or {}
    local seenMail, now = SFP.db.ahMailSeen, time()
    for k, t in pairs(seenMail) do if now - t > 40 * 86400 then seenMail[k] = nil end end
    for i = 1, (GetInboxNumItems()) do
        local _, _, _, subject, _, _, daysLeft = GetInboxHeaderInfo(i)
        if type(subject) == "string" and not (issecretvalue and issecretvalue(subject)) and subject:sub(1, #prefix) == prefix then
            local link = GetInboxItemLink(i, 1)
            local id = itemIDOf(link) or itemIDOf(subject:sub(#prefix + 1))
            if id then
                local key = id .. ":" .. math.floor((now + (daysLeft or 0) * 86400) / 86400)
                if not seenMail[key] then
                    seenMail[key] = now
                    noteOutcome(id, "e")
                end
            end
        end
    end
end

-- sale invoices waiting in the mailbox: who bought what for how much (after the Auction House cut)
local function scanInbox()
    if not (GetInboxNumItems and GetInboxInvoiceInfo) then return end
    for i = 1, (GetInboxNumItems()) do
        local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo(i)
        if invoiceType == "seller" and itemName then
            local key = itemName .. ":" .. (playerName or "") .. ":" .. (bid or 0)
            local _, _, sender, subject = GetInboxHeaderInfo(i)
            key = key .. ":" .. (subject or "") .. ":" .. i
            if not seen[key] then
                seen[key] = true
                local got = (bid or 0) - (consignment or 0)
                say(("Sold %s%s for %s (you receive %s)"):format(itemName,
                    playerName and playerName ~= "" and (" to " .. playerName) or "", money(bid), money(got)))
            end
        end
    end
end

SFP:OnLogin(function()
    if SFP.db.auctionSold == nil then SFP.db.auctionSold = true end
    local f = CreateFrame("Frame")
    pcall(f.RegisterEvent, f, "CHAT_MSG_SYSTEM")
    pcall(f.RegisterEvent, f, "MAIL_INBOX_UPDATE")
    f:SetScript("OnEvent", function(_, event, msg)
        if event == "CHAT_MSG_SYSTEM" then
            -- a chat line can be a secret string (in a dungeon or a fight): it is left alone then
            if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return end
            local item = soldPattern and msg:match(soldPattern)
            if item then
                noteOutcome(itemIDOf(item), "s")   -- always noted, whether the chat message is on or not
                if SFP.db.auctionSold then
                    say("Sold: " .. item)
                    pcall(PlaySound, 120)   -- coin sound
                end
            end
        else
            SFP:Safe("expired auctions", scanExpired)
            if SFP.db.auctionSold then SFP:Safe("auction invoices", scanInbox) end
        end
    end)
end)

function SFP:ToggleAuctionSold()
    SFP.db.auctionSold = not SFP.db.auctionSold
    SFP:Print("Auction sold messages " .. (SFP.db.auctionSold and "ON" or "OFF"))
end
