-- SeviathsUsefulTools - crafting order prices
-- Like the auction house scan, for crafting orders: while the Crafting Orders page of a profession window is open, the
-- orders the game lists are read and the commission each order pays is saved per item (this realm). The numbers show in the
-- profession window ("Orders pay"), next to the auction house price. Nothing is sent: it only reads what the game lists.

local _, SFP = ...

local KEEP = 3 * 86400   -- an order seen this long ago is forgotten

local function store()
    SFP.db.orders = SFP.db.orders or {}
    local realm = SFP:RealmKey()
    SFP.db.orders[realm] = SFP.db.orders[realm] or {}
    return SFP.db.orders[realm]
end

local function itemOf(order)
    local id = tonumber(order.itemID)
    if not id and order.outputItemHyperlink then id = tonumber(tostring(order.outputItemHyperlink):match("item:(%d+)")) end
    return id
end

-- the average commission (copper) crafting orders pay for an item, and how many orders that is based on
function SFP:OrderPrice(itemID)
    if not (self.db and self.db.orders) then return nil end
    local rec = store()[itemID]
    if not rec then return nil end
    local now, sum, n = time(), 0, 0
    for orderID, o in pairs(rec) do
        if now - (o.t or 0) > KEEP then rec[orderID] = nil else sum = sum + o.tip; n = n + 1 end
    end
    if n == 0 then return nil end
    return math.floor(sum / n), n
end

-- the lowest and highest commission listed for an item
function SFP:OrderRange(itemID)
    if not (self.db and self.db.orders) then return nil end
    local rec = store()[itemID]
    if not rec then return nil end
    local low, high
    for _, o in pairs(rec) do
        if type(o) == "table" and o.tip then
            if not low or o.tip < low then low = o.tip end
            if not high or o.tip > high then high = o.tip end
        end
    end
    return low, high
end

-- every commission read for an item, lowest first
function SFP:OrderList(itemID)
    if not (self.db and self.db.orders) then return {} end
    local rec = store()[itemID]
    local out = {}
    for _, o in pairs(rec or {}) do
        if type(o) == "table" and o.tip then out[#out + 1] = o.tip end
    end
    table.sort(out)
    return out
end

-- how many orders and items were read, and when the last order was read
function SFP:OrderStats()
    local items, orders, last = 0, 0, 0
    for _, rec in pairs(store()) do
        items = items + 1
        for _, o in pairs(rec) do
            orders = orders + 1
            if (o.t or 0) > last then last = o.t end
        end
    end
    return items, orders, last
end

local function record(orders)
    if type(orders) ~= "table" then return 0 end
    local t, added = store(), 0
    local now = time()
    for _, o in ipairs(orders) do
        if type(o) == "table" then
            local id, tip, orderID = itemOf(o), tonumber(o.tipAmount), o.orderID
            -- the materials of the order are learned too (the entry holds the reagent in different fields by game version)
            for _, rg in ipairs(o.reagents or {}) do
                local okR, rid = pcall(function()
                    local info = rg.reagentInfo or rg.reagent or rg
                    local reagent = info.reagent or info
                    return reagent.itemID
                end)
                if okR and type(rid) == "number" and SFP.LearnMaterial then SFP.LearnMaterial(rid) end
            end
            if id and tip and tip > 0 and orderID then
                local rec = t[id]
                if not rec then rec = {}; t[id] = rec end
                if not rec[orderID] then added = added + 1 end
                rec[orderID] = { tip = tip, t = now }
            end
        end
    end
    return added
end

local inRead = false
-- read the orders the game has loaded right now; returns how many orders there are and how many of them were new
local function read()
    if not (C_CraftingOrders and C_CraftingOrders.GetCrafterOrders) then return 0, 0 end
    inRead = true
    local ok, orders = pcall(C_CraftingOrders.GetCrafterOrders)
    inRead = false
    if not ok or type(orders) ~= "table" then return 0, 0 end
    local added = record(orders)
    if added > 0 then
        SFP.lastOrderRead = time()
        if SFP.RefreshAll then SFP:RefreshAll() end
    end
    return #orders, added
end

-- the button: read what the game has loaded now, and say what came of it
function SFP:ReadOrdersNow()
    local total, added = read()
    local items, orders = self:OrderStats()
    if total == 0 then
        self:Print("No crafting orders are loaded right now. The game does not let addons ask for them: open the Crafting Orders tab of a profession and pick a category (or press its Search button), then read again. Orders already saved: " .. orders .. " for " .. items .. " items.")
    else
        self:Print(("Read %d crafting orders (%d new). Saved: %d orders for %d items."):format(total, added, orders, items))
    end
    return total, added
end

-- the game's own window asks for the orders and reads them with GetCrafterOrders: every time it does, the orders are saved too
if C_CraftingOrders and C_CraftingOrders.GetCrafterOrders and hooksecurefunc then
    hooksecurefunc(C_CraftingOrders, "GetCrafterOrders", function()
        if inRead then return end
        C_Timer.After(0, function() SFP:Safe("crafting orders", read) end)
    end)
end

-- while the profession window is open (and it is on the Crafting Orders page), the list is read twice a second
local f = CreateFrame("Frame")
local acc = 0
f:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 1.5 then return end
    acc = 0
    local PF = _G.ProfessionsFrame
    if PF and PF:IsShown() and PF.OrdersPage and PF.OrdersPage:IsShown() then
        SFP:Safe("crafting orders", read)
    end
end)

-- the orders the game sends are read as they arrive too
for _, e in ipairs({ "CRAFTINGORDERS_UPDATE_ORDER_COUNT", "CRAFTINGORDERS_CLAIM_ORDER_RESPONSE", "CRAFTINGORDERS_FULFILL_ORDER_RESPONSE" }) do
    pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function() C_Timer.After(0.5, function() SFP:Safe("crafting orders", read) end) end)
