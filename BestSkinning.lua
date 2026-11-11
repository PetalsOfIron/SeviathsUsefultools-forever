-- SeviathsUsefulTools - the 15 best skinning spots
-- From what was collected (your skinnings and the shipped data of everybody): for every monster that was skinned often enough, the value of one skinning is the
-- sum, over everything it gave, of (how often it gave it per skinning) x (auction house price). The 15 monsters with the highest value are listed with the zone, the
-- gold per skinning and the best things they drop with the drop rate. Click a row to open the map at the zone.

local _, SFP = ...

local MIN_SKINS = 5   -- fewer skinnings than this say too little about the drop rates
local frame, rows = nil, {}

local function money(c)
    c = math.floor((c or 0) + 0.5)
    if GetMoneyString then return GetMoneyString(c, true) end
    return string.format("%dg %ds", math.floor(c / 10000), math.floor(c / 100) % 100)
end

local function compute()
    local out = {}
    local npcs = SFP.db and SFP.db.npcs
    if not npcs then return out end
    for id, r in (SeviathsAllPairs or pairs)(npcs) do
        if type(r) == "table" and type(r.s) == "table" and (r.sk or 0) >= MIN_SKINS then
            local value, top = 0, {}
            for item, n in pairs(r.s) do
                local okP, price = pcall(SFP.GetPrice, SFP, item)
                if okP and type(price) == "number" and price > 0 then
                    local rate = n / r.sk
                    value = value + rate * price
                    top[#top + 1] = { item = item, rate = rate, gold = rate * price }
                end
            end
            if value > 0 then
                table.sort(top, function(a, b) return a.gold > b.gold end)
                local zone
                for map in pairs(r.m or {}) do zone = map break end
                out[#out + 1] = { id = id, name = r.n or ("NPC " .. tostring(id)), value = value, top = top, skins = r.sk, map = zone }
            end
        end
    end
    table.sort(out, function(a, b) return a.value > b.value end)
    while #out > 15 do out[#out] = nil end
    return out
end

local function build()
    if frame then return frame end
    frame = CreateFrame("Frame", "SeviathsBestSkinning", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(640, 470)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.TitleText:SetText("Best 15 skinning spots")
    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 14, -32)
    note:SetWidth(610)
    note:SetJustifyH("LEFT")
    note:SetText("By gold per skinning (drop rate x auction price). Monsters skinned at least " .. MIN_SKINS .. " times. Click a row to open its zone.")
    for i = 1, 15 do
        local r = CreateFrame("Button", nil, frame)
        r:SetSize(612, 26)
        r:SetPoint("TOPLEFT", 14, -56 - (i - 1) * 27)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.05 or 0.0)
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(1, 0.82, 0.2, 0.12)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.text:SetPoint("LEFT", 6, 0)
        r.text:SetWidth(600)
        r.text:SetJustifyH("LEFT")
        r:SetScript("OnClick", function(self)
            if self.map and SFP.OpenMapTo then SFP:OpenMapTo(self.map) end
        end)
        rows[i] = r
    end
    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.empty:SetPoint("CENTER", 0, -10)
    frame.empty:SetWidth(520)
    frame.empty:SetText("No skinning data with prices yet. Skin some monsters and scan the auction house (Farm & Map > Scan auction prices).")
    frame:Hide()
    return frame
end

function SFP:ShowBestSkinning()
    local f = build()
    local list = compute()
    f.empty:SetShown(#list == 0)
    for i, r in ipairs(rows) do
        local e = list[i]
        if e then
            local top = {}
            for k = 1, math.min(2, #e.top) do
                local t = e.top[k]
                top[#top + 1] = ("%s %d%%"):format(SFP:ItemName(t.item), math.min(100, math.floor(t.rate * 100 + 0.5)))
            end
            r.map = e.map
            r.text:SetText(("|cffffd100%d.|r %s  |cff909090%s|r   %s per skin   |cff909090%s|r"):format(
                i, e.name, e.map and SFP:ZoneName(e.map) or "", money(e.value), table.concat(top, ", ")))
            r:Show()
        else
            r:Hide()
        end
    end
    f:Show()
    f:Raise()
end
