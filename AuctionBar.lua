-- SeviathsUsefulTools - scan bar and scan button on the auction house window
-- Below the auction house window: a "Scan prices" button and a bar that shows how far the scan is.
-- Auction.lua reports the progress (SFP.scanState); this file only draws it.

local _, SFP = ...

local bar, status, label, button
local doneUntil = 0

-- exact age: days, hours and minutes (and the date of the scan)
local function ago(t, withDate)
    if not t or t <= 0 then return nil end
    local mins = math.max(0, math.floor((time() - t) / 60))
    local text
    if mins < 1 then
        text = "just now"
    else
        local d, h, m = math.floor(mins / 1440), math.floor(mins % 1440 / 60), mins % 60
        local parts = {}
        if d > 0 then parts[#parts + 1] = d .. (d == 1 and " day" or " days") end
        if h > 0 then parts[#parts + 1] = h .. " h" end
        if m > 0 and d == 0 then parts[#parts + 1] = m .. " min" end
        text = table.concat(parts, " ") .. " ago"
    end
    if withDate and date then text = text .. " (" .. date("%d %b %H:%M", t) .. ")" end
    return text
end

-- scans of other realms: { { realm, time }, ... } newest first (this realm's own scan is not in the list)
local function otherRealmScans()
    local out, mine = {}, SFP:RealmKey()
    for realm, t in pairs(SFP.db.realmScan or {}) do
        if realm ~= mine and t and t > 0 then out[#out + 1] = { realm, t } end
    end
    table.sort(out, function(a, b) return a[2] > b[2] end)
    return out
end

local function refresh()
    if not bar then return end
    local scanning = SFP:IsScanning()
    local st = SFP.scanState
    button:SetEnabled(not scanning)
    button:SetText(scanning and "Scanning..." or "Scan prices")

    local value, text, r, g, b = 0, nil, 0.1, 0.75, 0.9
    if scanning and st then
        if st.phase == "wait" then
            text = ("Waiting for the auction house...  %d s"):format(math.floor(GetTime() - (st.t0 or GetTime())))
        elseif st.phase == "read" then
            value = st.total > 0 and st.done / st.total or 0
            text = ("Reading auctions  %d%%"):format(math.floor(value * 100))
        elseif st.phase == "section" then
            value = st.total > 0 and st.done / st.total or 0
            text = ("Scanning section  %d / %d  (%d%%)"):format(st.done, st.total, math.floor(value * 100))
        elseif st.phase == "items" then
            value = st.total > 0 and st.done / st.total or 0
            text = ("Scanning items  %d / %d  (%d%%)"):format(st.done, st.total, math.floor(value * 100))
        end
    elseif st and st.phase == "done" and GetTime() < doneUntil then
        value, r, g, b = 1, 0.2, 0.85, 0.3
        text = "Scan done - prices updated"
    end
    local old = false
    if not text then
        local last = SFP.LastScan and SFP:LastScan()
        local when = ago(last)
        local limit = (SFP.db.rescanHours or 12) * 3600
        local others = otherRealmScans()
        local realm = (GetRealmName and GetRealmName()) or SFP:RealmKey()
        if (not last or last == 0) and #others > 0 then
            text, old = "Prices from another realm (" .. others[1][1] .. ") - scan " .. realm, true
        elseif (not last or last == 0) and SFP.ShippedPrice and SFP.ShippedRealmName and SFP:ShippedRealmName() then
            -- no scan of its own yet, but prices shipped with the addon (this realm's or a connected realm's) are in use
            text = "Prices for " .. realm .. ": shipped prices (" .. SFP:ShippedRealmName() .. ") - scan for current"
        elseif not when or not last or last == 0 then
            text, old = "Prices for " .. realm .. ": old data - scan for current", true
        elseif time() - last > limit then
            text, old = "Prices for " .. realm .. ": last scan " .. when .. " - scan", true
        else
            text = "Prices for " .. realm .. ": last scan " .. when
        end
    end
    status:SetValue(value)
    status:SetStatusBarColor(r, g, b)
    label:SetText(text)
    if old then label:SetTextColor(1, 0.8, 0.3) else label:SetTextColor(1, 1, 1) end
end

local function build()
    if bar or not AuctionHouseFrame then return end
    bar = CreateFrame("Frame", "SeviathsUsefulToolsScanBar", AuctionHouseFrame)
    bar:SetSize(580, 22)
    bar:SetPoint("TOPLEFT", AuctionHouseFrame, "BOTTOMLEFT", 6, -40)   -- below the tab row, where Auctionator, TSM and others put their tabs
    bar:SetFrameStrata("HIGH")

    button = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    button:SetSize(96, 22)
    button:SetPoint("LEFT", 0, 0)
    button:SetText("Scan prices")
    button:SetScript("OnClick", function() SFP:StartScan(true) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("SeviathsUsefulTools")
        GameTooltip:AddLine("Scan the whole auction house for farm prices. It also starts by itself when the prices are old.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    status = CreateFrame("StatusBar", nil, bar)
    status:SetPoint("LEFT", button, "RIGHT", 6, 0)
    status:SetSize(272, 18)
    status:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    status:EnableMouse(true)
    status:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Auction prices", 1, 1, 1)
        local others = otherRealmScans()
        GameTooltip:AddLine("This realm: " .. SFP:RealmKey() .. "  (" .. ((SFP.LastScan and SFP:LastScan() > 0) and ago(SFP:LastScan(), true) or "not scanned") .. ")", 0.4, 0.9, 1)
        for _, o in ipairs(others) do GameTooltip:AddLine("Other realm: " .. o[1] .. "  (" .. (ago(o[2], true) or "?") .. ")", 1, 0.8, 0.3) end
        if #others > 0 and (not SFP.LastScan or SFP:LastScan() == 0) then
            GameTooltip:AddLine("This realm has no scan, so prices shown come from another realm and may be wrong here.", 1, 0.8, 0.3, true)
        end
        GameTooltip:AddLine("Prices come from your last scan. If there is none or it is old, press Scan prices for current prices. Until then the addon uses Auctionator or TradeSkillMaster prices when you have them, also data they got from another PC or account.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    status:SetScript("OnLeave", function() GameTooltip:Hide() end)
    status:SetMinMaxValues(0, 1)
    status:SetValue(0)
    local bg = status:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    label = status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")

    -- a small timer under the bar: when the game allows the next fast scan (one request per 15 minutes for the whole account)
    local fastLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fastLabel:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 104, -2)
    local acc = 0
    local timerFrame = CreateFrame("Frame", nil, bar)   -- its own frame: the bar already has an OnUpdate of its own further down
    timerFrame:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 1 then return end
        acc = 0
        local last = SFP.db and SFP.db.lastReplicate
        local left = last and (15 * 60 + 15 - (time() - last)) or 0
        if left > 0 then
            fastLabel:SetText(("Fast scan again in %d:%02d"):format(math.floor(left / 60), left % 60))
            fastLabel:SetTextColor(1, 0.6, 0.3)
        else
            fastLabel:SetText("Fast scan ready")
            fastLabel:SetTextColor(0.4, 0.9, 0.4)
        end
    end)

    local deals = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    deals:SetSize(80, 22)
    deals:SetPoint("LEFT", status, "RIGHT", 6, 0)
    deals:SetText("BoE deals")
    deals:SetScript("OnClick", function() SFP:ShowDeals() end)

    -- long scan: keep everything the auction house shows (all items, full details, all prices)
    local long = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
    long:SetSize(22, 22)
    long:SetPoint("LEFT", deals, "RIGHT", 4, 0)
    long.label = long:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    long.label:SetPoint("LEFT", long, "RIGHT", 0, 0)
    long.label:SetText("Long scan")
    long:SetHitRectInsets(0, -60, 0, 0)
    long:SetChecked(SFP.db.longScan and true or false)
    long:SetScript("OnClick", function(self) SFP.db.longScan = self:GetChecked() and true or false end)
    long:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Long scan: after the section scan it also scans each tracked item one by one, like the old scan (slow, thousands of searches). It also saves the price and full details of every item in the auction house, which makes the saved data bigger. Use it to collect everything, then switch it off.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    long:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local acc = 0
    bar:SetScript("OnUpdate", function(_, dt)
        acc = acc + dt
        if acc < 0.2 then return end
        acc = 0
        refresh()
    end)
    refresh()
end

function SFP:UpdateScanBar()
    local st = SFP.scanState
    if st and st.phase == "done" then doneUntil = GetTime() + 12 end
    if bar then refresh() end
end

local f = CreateFrame("Frame")
pcall(f.RegisterEvent, f, "AUCTION_HOUSE_SHOW")
f:SetScript("OnEvent", function()
    -- the auction house window is created by the game when it first opens
    C_Timer.After(0.2, function() SFP:Safe("scan bar", build) end)
end)
