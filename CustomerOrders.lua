-- SeviathsUsefulTools - prices for the Place Crafting Order window
-- Next to each reagent: what the amount costs at the auction house. Next to the window a small movable menu pops up with
-- everything for the item: the auction price, the materials with their prices, every commission crafting orders for it pay
-- (read from the orders the game lists, see OrderScan.lua), and the profit or loss of making it.
-- The game does not let addons ask for crafting orders, so the orders are read as you browse the Crafting Orders tab.

local _, SFP = ...

local function money(c)
    return GetMoneyString and GetMoneyString(c, true) or tostring(c)
end

local function priceOf(id)
    if not id then return nil end
    local ok, p = pcall(SFP.GetPrice, SFP, id)
    if ok and type(p) == "number" and p > 0 then return p end
    return nil
end

-- the reagent slots are found by what they carry, wherever the form keeps them
local function findSlots(frame, out, depth)
    if not (frame and frame.GetChildren) or depth > 5 then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if type(child) == "table" and child.reagentSlotSchematic then
            out[#out + 1] = child
        else
            findSlots(child, out, depth + 1)
        end
    end
end

-- the recipe the window is about: the form keeps it in different places depending on the game version
local function recipeOf(form)
    local ids = {}
    local function try(fn)
        local ok, v = pcall(fn)
        if ok and type(v) == "number" then ids[#ids + 1] = v end
    end
    try(function() return form.order.spellID end)
    try(function() return form.order.recipeID end)
    try(function() return form.recipeInfo.recipeID end)
    try(function() return form.transaction:GetRecipeID() end)
    try(function() return form.recipeID end)
    return ids[1]
end

-- everything about the item the window is about
local function gather(frame)
    local form = frame.Form or frame
    local d = { recipeID = recipeOf(form), reagents = {}, cost = 0, missing = 0 }
    local basic = (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1
    local slots = {}
    findSlots(frame, slots, 0)
    d.slots = slots
    for _, slot in ipairs(slots) do
        local s = slot.reagentSlotSchematic
        local r = s and s.reagentType == basic and s.reagents and s.reagents[1]
        local id = r and r.itemID
        if id and slot:IsShown() then
            if SFP.LearnMaterial then SFP.LearnMaterial(id) end   -- seen here: the addon learns the material
            local unit = priceOf(id)
            local qty = s.quantityRequired or 1
            d.reagents[#d.reagents + 1] = { id = id, qty = qty, unit = unit, slot = slot }
            if unit then d.cost = d.cost + unit * qty else d.missing = d.missing + 1 end
        end
    end
    if d.recipeID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData then
        local ok, out = pcall(C_TradeSkillUI.GetRecipeOutputItemData, d.recipeID)
        if ok and type(out) == "table" then d.outID = out.itemID end
    end
    if d.recipeID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, d.recipeID)
        if ok and type(info) == "table" then d.name = info.name; d.info = info end
    end
    d.name = d.name or (d.outID and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(d.outID)) or "this item"
    d.sell = priceOf(d.outID)
    if not d.sell then
        local okN, p = pcall(SFP.PriceByName, SFP, d.name)
        if okN and type(p) == "number" and p > 0 then d.sell = p end
    end
    if d.sell and #d.reagents > 0 and d.missing == 0 then d.profit = math.floor(d.sell * 0.95 - d.cost) end
    return d
end

-- the price under each reagent's name, in the window itself
local function decorate(d)
    for _, slot in ipairs(d.slots) do
        local text = slot.SFPPrice
        if not text then
            text = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetJustifyH("LEFT")
            text:SetWordWrap(false)
            text:SetWidth(120)
            slot.SFPPrice = text
        end
        text:ClearAllPoints()
        if slot.Text and slot.Text.GetObjectType and slot.Text:GetObjectType() == "FontString" then
            local h = slot.Text:GetStringHeight()
            if type(h) ~= "number" or h < 8 then h = 12 end
            text:SetPoint("TOPLEFT", slot.Text, "TOPLEFT", 0, -(h + 2))
        elseif slot.Button then
            text:SetPoint("TOPLEFT", slot.Button, "TOPRIGHT", 6, -30)
        else
            text:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 40, 0)
        end
        text:SetText("")
    end
    for _, r in ipairs(d.reagents) do
        local text = r.slot.SFPPrice
        if text then
            text:SetText(r.unit and ("|cffffd100x" .. r.qty .. " = " .. money(r.unit * r.qty) .. "|r") or "|cff808080no price|r")
        end
    end
end

---------------------------------------------------------------------------
-- the menu next to the window
---------------------------------------------------------------------------
local pop, popList, orderFrame
local dismissed   -- the recipe whose menu you closed: it stays closed until another item is chosen

local function rowsFor(d)
    local rows = {}
    local function add(text) rows[#rows + 1] = { text = text } end
    add("|cffffd100" .. d.name .. "|r")
    if d.sell then add("Auction price: " .. money(d.sell))
    else add("|cff808080Auction price: not seen yet (scan the auction house)|r") end
    add("")
    add("|cffffd100Materials|r")
    for _, r in ipairs(d.reagents) do
        -- name, how many, the price of one, of the amount needed, and of a whole stack
        local stack = SFP:StackCount(r.id)
        add(("%dx %s"):format(r.qty, SFP:ItemName(r.id)))
        if r.unit then
            add(("     %s each, |cffffd100%s|r for %d%s"):format(money(r.unit), money(r.unit * r.qty), r.qty,
                (stack and stack > 1) and ("   |cff808080stack of " .. stack .. ": " .. money(r.unit * stack) .. "|r") or ""))
        else
            add("     |cff808080no price seen yet|r")
        end
    end
    if #d.reagents == 0 then add("|cff808080Pick the item you want to order.|r") end
    add(("Materials together: %s%s"):format(money(d.cost), d.missing > 0 and ("  |cffff6060(" .. d.missing .. " without a price)|r") or ""))
    if d.profit then
        add(d.profit >= 0 and ("Making it yourself: |cff40ff40profit +" .. money(d.profit) .. "|r (after the 5% cut)")
            or ("Making it yourself: |cffff6060loss -" .. money(-d.profit) .. "|r (after the 5% cut)"))
    end
    -- the chance of each quality (percentages), as in the profession window
    local q = d.info and SFP.QualityChanceText and SFP.QualityChanceText(d.info, nil)
    if q then
        -- one row per quality: a row does not wrap, so a long line would be cut at the edge of the menu
        for seg in (q .. "   "):gmatch("(.-)   ") do
            if seg ~= "" then add(seg) end
        end
    end
    add("")
    local tips = d.outID and SFP.OrderList and SFP:OrderList(d.outID) or {}
    add(("|cffffd100Crafting orders listed for this item|r  (%d)"):format(#tips))
    if #tips == 0 then
        add("|cff808080None read yet. Open the Crafting Orders tab of the profession and look at this item: every order the game lists is saved here.|r")
    else
        local sum = 0
        for _, t in ipairs(tips) do sum = sum + t end
        add(("Commission: lowest %s, average %s, highest %s"):format(money(tips[1]), money(math.floor(sum / #tips)), money(tips[#tips])))
        for i = 1, math.min(#tips, 12) do add(("   order %d: %s"):format(i, money(tips[i]))) end
        if #tips > 12 then add("   +" .. (#tips - 12) .. " more") end
    end
    add("")
    local items, orders = SFP.OrderStats and SFP:OrderStats()
    add(("|cff808080%d orders of %d items read so far. The game does not let addons ask for orders, so they are read as you browse the Crafting Orders tab.|r"):format(orders or 0, items or 0))
    return rows
end

-- before an item is chosen: what crafting orders pay, the best paying items read so far
local function overviewRows()
    local rows = {}
    local function add(text) rows[#rows + 1] = { text = text } end
    add("|cffffd100Crafting order prices|r")
    add("|cff808080Pick an item in the list to see its materials, prices, profit and the orders listed for it.|r")
    add("")
    local list = {}
    SFP.db.orders = SFP.db.orders or {}
    for id in pairs(SFP.db.orders[SFP:RealmKey()] or {}) do
        local tip, n = SFP:OrderPrice(id)
        if tip then list[#list + 1] = { id = id, tip = tip, n = n } end
    end
    table.sort(list, function(a, b) if a.tip ~= b.tip then return a.tip > b.tip end return a.id < b.id end)
    add(("|cffffd100Best paying items read so far|r  (%d)"):format(#list))
    if #list == 0 then
        add("|cff808080No orders read yet. Open the Crafting Orders tab of a profession and look through the orders: every order the game lists is saved here.|r")
    end
    for i = 1, math.min(#list, 25) do
        local e = list[i]
        local ah = priceOf(e.id)
        add(("%s  commission %s (%d order%s)%s"):format(SFP:ItemName(e.id), money(e.tip), e.n, e.n == 1 and "" or "s",
            ah and ("   |cff808080sells for " .. money(ah) .. "|r") or ""))
    end
    add("")
    local items, orders = SFP.OrderStats and SFP:OrderStats()
    add(("|cff808080%d orders of %d items read so far. The game does not let addons ask for orders, so they are read as you browse the Crafting Orders tab.|r"):format(orders or 0, items or 0))
    return rows
end

local lastRows
local function fillPop(d)
    if not (pop and pop:IsShown()) then return end
    -- one block of text that wraps (a list row does not wrap and would cut long lines at the edge)
    local lines = {}
    for _, r in ipairs(d.recipeID and rowsFor(d) or overviewRows()) do lines[#lines + 1] = r.text end
    pop:SetContent(table.concat(lines, "\n"))
end

local function ensurePop(frame)
    if pop then return end
    pop = SFP.MakeToolWindow("SeviathsUsefulToolsOrderPrices", "Crafting order prices", 420, 470)
    pop.scroll:SetPoint("BOTTOMRIGHT", -30, 42)   -- room for the buttons under the text
    local refresh = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
    refresh:SetSize(110, 22)
    refresh:SetPoint("BOTTOMLEFT", 14, 10)
    refresh:SetText("Refresh prices")
    refresh:SetScript("OnClick", function()
        if orderFrame and orderFrame:IsShown() then fillPop(gather(orderFrame)) end
    end)
    local scan = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
    scan:SetSize(110, 22)
    scan:SetPoint("LEFT", refresh, "RIGHT", 8, 0)
    scan:SetText("Read orders")
    scan:SetScript("OnClick", function()
        SFP:ReadOrdersNow()
        if orderFrame and orderFrame:IsShown() then fillPop(gather(orderFrame)) end
    end)
    scan:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Read the crafting orders the game has loaded now.", 1, 1, 1, true)
        GameTooltip:AddLine("The game does not let addons ask for orders. Open the Crafting Orders tab of a profession and pick a category: the addon saves every order the game lists, by itself.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    scan:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local planner = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
    planner:SetSize(110, 22)
    planner:SetPoint("LEFT", scan, "RIGHT", 8, 0)
    planner:SetText("Recipe Planner")
    planner:SetScript("OnClick", function() if SFP.ShowShop then SFP:ShowShop() end end)
    pop:SetScript("OnShow", function(self)
        -- the first time (no saved place) it opens next to the order window
        if orderFrame and not (SFP.db.windowPos and SFP.db.windowPos["SeviathsUsefulToolsOrderPrices"]) then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", orderFrame, "TOPRIGHT", 6, 0)
        end
    end)
    pop:HookScript("OnHide", function()
        if orderFrame and orderFrame:IsShown() and lastRows then dismissed = lastRows end
    end)
end

local function update(frame)
    orderFrame = frame
    local d = gather(frame)
    decorate(d)
    -- the menu opens with the window (the overview), and shows the item once one is chosen
    local key = d.recipeID or "overview"
    lastRows = key
    if SFP.db.orderPopup ~= false and dismissed ~= key then
        ensurePop(frame)
        if not pop:IsShown() then pop:Show() end
    end
    fillPop(d)
end

local hooked
local function hookWindow()
    local frame = _G.ProfessionsCustomerOrdersFrame
    if not frame or hooked then return end
    hooked = true
    local acc = 0
    frame:HookScript("OnUpdate", function(self, dt)
        acc = acc + dt
        if acc < 0.5 then return end
        acc = 0
        SFP:Safe("crafting order prices", update, self)
    end)
    frame:HookScript("OnHide", function() if pop then pop:Hide() end; dismissed = nil end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name == "Blizzard_ProfessionsCustomerOrders" then C_Timer.After(0, function() SFP:Safe("crafting orders window", hookWindow) end) end
end)
-- in case the window was made before this addon looked (or under a moment of delay): look again every second until it is hooked
local look = 0
f:SetScript("OnUpdate", function(_, dt)
    if hooked then return end
    look = look + dt
    if look < 1 then return end
    look = 0
    SFP:Safe("crafting orders window", hookWindow)
end)
SFP:OnLogin(function() SFP:Safe("crafting orders window", hookWindow) end)
