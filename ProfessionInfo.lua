-- SeviathsUsefulTools - profit and loss in the game's profession window
-- Under the reagents of the chosen recipe: what it costs to craft and what it earns at the auction house (after the 5% cut),
-- and whether the recipe is learned. A "Best profit" button opens the Recipe Planner on this profession,
-- the recipes you learned first (best profit first), the ones you have not learned yet after them.

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

-- cost of the recipe with the cheapest quality of each reagent, the product's price, and the profit
local function figures(recipeID, recipeName)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic) then return nil end
    local ok, schem = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not ok or type(schem) ~= "table" then return nil end
    local basic = (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1
    local cost, missing = 0, 0
    for _, slot in ipairs(schem.reagentSlotSchematics or {}) do
        if slot.reagentType == basic then
            local r = slot.reagents and slot.reagents[1]
            if r and r.itemID and SFP.LearnMaterial then SFP.LearnMaterial(r.itemID) end   -- seen here: the addon learns the material
            local p = r and priceOf(r.itemID)
            if p then cost = cost + p * (slot.quantityRequired or 1) else missing = missing + 1 end
        end
    end
    local outID
    if C_TradeSkillUI.GetRecipeOutputItemData then
        local ok2, out = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
        if ok2 and type(out) == "table" then outID = out.itemID end
    end
    local qty = tonumber(schem.quantityMin) or 1
    if qty < 1 then qty = 1 end
    local sell = priceOf(outID)
    if not sell and recipeName then
        -- the same item by name: crafted gear is listed under an ID per quality
        local okN, p = pcall(SFP.PriceByName, SFP, recipeName)
        if okN and type(p) == "number" and p > 0 then sell = p end
    end
    local profit = sell and missing == 0 and math.floor(sell * qty * 0.95 - cost) or nil
    return cost, missing, sell and sell * qty or nil, profit, outID
end

local fs
local orderTab, orderPanel                  -- the "Orders" tab button and its panel
local orderItem, orderName, orderCost       -- the item the window is about, its name, what its reagents cost

-- the panel: every crafting order read for the item, with its gold (commission)
function SFP.RefreshOrderTab()
    if not (orderPanel and orderPanel:IsShown()) then return end
    local list = (SFP.OrderList and orderItem) and SFP:OrderList(orderItem) or {}
    local lines = { ("|cffffd100%s|r"):format(orderName or "this item"), "" }
    -- the 4 highest commissions of an item, highest first
    local function top4(l)
        local out = {}
        for i = #l, math.max(1, #l - 3), -1 do out[#out + 1] = l[i] end
        return out
    end
    if #list == 0 then
        lines[#lines + 1] = "|cff808080No crafting orders read for this item yet.|r"
    else
        local sum = 0
        for _, t in ipairs(list) do sum = sum + t end
        local avg = math.floor(sum / #list)
        lines[#lines + 1] = ("|cffffd100The %d highest of %d order%s:|r"):format(math.min(4, #list), #list, #list == 1 and "" or "s")
        for i, t in ipairs(top4(list)) do lines[#lines + 1] = ("%d.  %s"):format(i, money(t)) end
        lines[#lines + 1] = ("Average of all: %s"):format(money(avg))
        -- against the auction house price of the item (a commission is usually below it)
        local ah = priceOf(orderItem)
        if not ah and orderName then
            local okN, p = pcall(SFP.PriceByName, SFP, orderName)
            if okN and type(p) == "number" and p > 0 then ah = p end
        end
        if ah then
            local best = list[#list]
            local pct = math.floor(best * 100 / ah + 0.5)
            lines[#lines + 1] = ("Auction price: %s.  The highest order is %d%% of it (%s %s)"):format(money(ah), pct,
                best >= ah and "over by" or "below by", money(math.abs(ah - best)))
        end
        if orderCost then
            local diff = avg - orderCost
            lines[#lines + 1] = diff >= 0 and ("Average over the reagents (%s): |cff40ff40+%s|r"):format(money(orderCost), money(diff))
                or ("Average under the reagents (%s): |cffff6060-%s|r"):format(money(orderCost), money(-diff))
        end
    end
    -- every other item that was checked at the crafting orders, with its 4 highest
    local others = {}
    SFP.db.orders = SFP.db.orders or {}
    for id in pairs(SFP.db.orders[SFP:RealmKey()] or {}) do
        if id ~= orderItem then
            local l = SFP:OrderList(id)
            if #l > 0 then others[#others + 1] = { id = id, l = l, top = l[#l] } end
        end
    end
    table.sort(others, function(a, b) if a.top ~= b.top then return a.top > b.top end return a.id < b.id end)
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("|cffffd100All items checked at the crafting orders|r  (%d)"):format(#others + ((#list > 0) and 1 or 0))
    if #others == 0 and #list == 0 then
        lines[#lines + 1] = "|cff808080None yet. The game does not let addons ask for orders: open the Crafting Orders tab of a profession, pick a category and look through the orders. The addon saves each one by itself and lists it here.|r"
    end
    for i = 1, math.min(#others, 40) do
        local o = others[i]
        local parts = {}
        for k, t in ipairs(top4(o.l)) do parts[k] = money(t) end
        lines[#lines + 1] = ("%s:  %s"):format(SFP:ItemName(o.id), table.concat(parts, "  "))
    end
    if #others > 40 then lines[#lines + 1] = "+" .. (#others - 40) .. " more" end
    orderPanel:SetContent(table.concat(lines, "\n"))
end

-- next to each reagent of the recipe: what the amount needed costs, and what a whole stack of it costs
-- the reagent slots are found by what they carry (reagentSlotSchematic), wherever the game keeps them in the form
local function findSlots(frame, out, depth)
    if not (frame and frame.GetChildren) or depth > 4 then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if type(child) == "table" and child.reagentSlotSchematic then
            out[#out + 1] = child
        else
            findSlots(child, out, depth + 1)
        end
    end
end

local function decorateSlots(form)
    local basic = (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1
    local slots = {}
    findSlots(form, slots, 0)
    for _, slot in ipairs(slots) do
        local text = slot.SFPPrice
        if not text then
            text = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            text:SetJustifyH("LEFT")
            text:SetWordWrap(false)
            text:SetWidth(120)   -- short text, never reaches the Crafting Details panel on the right
            slot.SFPPrice = text
        end
        -- one short line directly under the reagent's name, inside the reagent column
        text:ClearAllPoints()
        if slot.Text and slot.Text.GetObjectType and slot.Text:GetObjectType() == "FontString" then
            -- under the name as it is really written (two lines when the name wraps), not under the one-line box of it
            local h = slot.Text:GetStringHeight()
            if type(h) ~= "number" or h < 8 then h = 12 end
            text:SetPoint("TOPLEFT", slot.Text, "TOPLEFT", 0, -(h + 2))
        elseif slot.Button then
            text:SetPoint("TOPLEFT", slot.Button, "TOPRIGHT", 6, -30)
        else
            text:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 40, 0)
        end
        local s = slot.reagentSlotSchematic
        local r = s and s.reagentType == basic and s.reagents and s.reagents[1]
        local id = r and r.itemID
        if id and slot:IsShown() then
            local unit = priceOf(id)
            local qty = s.quantityRequired or 1
            if unit then
                -- only the price of the amount the recipe needs: "x10 = 700"
                text:SetText(("|cffffd100x%d = %s|r"):format(qty, money(unit * qty)))
            else
                text:SetText("|cff808080no price|r")
            end
        else
            text:SetText("")
        end
    end
end

-- can better gear raise the quality? From the game's own numbers for this recipe: skill now, skill where the next quality starts
local function qualityLine(form, recipeInfo)
    if not (C_TradeSkillUI and C_TradeSkillUI.GetCraftingOperationInfo) then return nil end
    local infos = {}
    local okT, tx = pcall(function() return form.GetTransaction and form:GetTransaction() end)
    if okT and tx and tx.CreateCraftingReagentInfoTbl then
        local okI, t = pcall(tx.CreateCraftingReagentInfoTbl, tx)
        if okI and type(t) == "table" then infos = t end
    end
    local ok, op = pcall(C_TradeSkillUI.GetCraftingOperationInfo, recipeInfo.recipeID, infos, nil, false)
    if not ok or type(op) ~= "table" then return nil end
    -- the chance of each quality, as percentages. With the skill you have, the quality of a craft is fixed by the game
    -- (the whole number of "quality"), so one quality is 100% and the others 0%; more skill from gear moves the 100% up.
    local q = tonumber(op.quality) or tonumber(op.craftingQuality)
    local maxQ = tonumber(recipeInfo.maxQuality)
    if not (q and maxQ and maxQ > 1) then return nil end
    local tier = math.max(1, math.min(maxQ, math.floor(q)))
    local parts = {}
    for i = 1, maxQ do
        local pct = (i == tier) and 100 or 0
        local col = (i == maxQ) and (pct > 0 and "|cff40ff40" or "|cffffd100") or (pct > 0 and "|cffffffff" or "|cff808080")
        parts[#parts + 1] = ("%sQuality %d: %d%%|r"):format(col, i, pct)
    end
    return table.concat(parts, "   ")
end

-- for other windows (the Place Crafting Order menu): the quality percentages of a recipe
function SFP.QualityChanceText(recipeInfo, form)
    if type(recipeInfo) ~= "table" or not recipeInfo.recipeID then return nil end
    local ok, text = pcall(qualityLine, form, recipeInfo)
    return ok and text or nil
end

local function update(recipeInfo, form)
    if not fs then return end
    if type(recipeInfo) ~= "table" or not recipeInfo.recipeID then fs:SetText(""); return end
    local cost, missing, sell, profit, outID = figures(recipeInfo.recipeID, recipeInfo.name)
    local lines = {}
    local ql = form and qualityLine(form, recipeInfo)
    if ql then lines[#lines + 1] = ql end
    if cost then
        lines[#lines + 1] = ("To craft: %s%s"):format(money(cost), missing > 0 and ("  |cffff6060(" .. missing .. " reagents without a price)|r") or "")
        if sell then
            lines[#lines + 1] = ("Sells for: %s"):format(money(sell))
        else
            -- say why: no scan yet, or the scan did not see it listed
            local snap = SFP.AllPrices and SFP:AllPrices()
            if snap and next(snap) then
                lines[#lines + 1] = "|cff808080Sells for: not listed at the last scan|r"
            else
                lines[#lines + 1] = "|cff808080Sells for: no scan of the whole auction house yet (open the auction house and wait for the fast scan)|r"
            end
        end
        if profit then
            lines[#lines + 1] = profit >= 0 and ("Profit: |cff40ff40+" .. money(profit) .. "|r") or ("Loss: |cffff6060-" .. money(-profit) .. "|r")
        end
    end
    -- every price listed for this item: the auction house listings (cheapest first), and what crafting orders pay
    local listed = SFP.Listings and outID and SFP:Listings(outID)
    if listed and #listed.p > 0 then
        -- only one price: the cheapest auction listing, and how many are listed
        lines[#lines + 1] = ("|cffffd100Auction price:|r %s  |cff808080(%d listed)|r"):format(money(listed.p[1]), listed.n)
    end
    -- crafting orders get their own tab (button) and panel, only for items that have orders
    orderItem = outID
    orderName = recipeInfo.name
    orderCost = (cost and missing == 0) and cost or nil
    local tip, orders = SFP.OrderPrice and outID and SFP:OrderPrice(outID)
    if orderTab then
        -- the tab is always there for a recipe with a product: crafting orders are listed apart from the auction prices
        orderTab:SetShown(outID ~= nil)
        orderTab:SetText(tip and ("Crafting orders (%d)"):format(orders) or "Crafting orders (none read)")
    end
    if orderPanel and orderPanel:IsShown() then SFP.RefreshOrderTab() end
    if recipeInfo.learned == false then lines[#lines + 1] = "|cffff9040Not learned yet|r" end
    fs:SetText(table.concat(lines, "\n"))
end

local function hookWindow()
    local PF = _G.ProfessionsFrame
    if not (PF and PF.CraftingPage and PF.CraftingPage.SchematicForm) or PF.SFPHooked then return end
    PF.SFPHooked = true
    local form = PF.CraftingPage.SchematicForm
    fs = form:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("BOTTOMLEFT", form, "BOTTOMLEFT", 22, 44)
    fs:SetJustifyH("LEFT")
    fs:SetWidth(320)
    -- the Orders tab: only shown for an item that crafting orders were read for
    orderTab = CreateFrame("Button", nil, form, "UIPanelButtonTemplate")
    orderTab:SetSize(170, 20)
    orderTab:SetPoint("BOTTOMLEFT", fs, "TOPLEFT", 0, 4)
    orderTab:SetText("Orders")
    orderTab:Hide()
    orderTab:SetScript("OnClick", function()
        if not orderPanel then
            orderPanel = SFP.MakeToolWindow("SeviathsUsefulToolsOrderTab", "Crafting orders", 320, 340)
            orderPanel:SetScript("OnShow", function(self)
                if not (SFP.db.windowPos and SFP.db.windowPos["SeviathsUsefulToolsOrderTab"]) then
                    self:ClearAllPoints()
                    self:SetPoint("TOPLEFT", PF, "TOPRIGHT", 6, 0)
                end
            end)
        end
        if orderPanel:IsShown() then orderPanel:Hide() else orderPanel:Show(); SFP.RefreshOrderTab() end
    end)

    local lastRecipe
    hooksecurefunc(form, "Init", function(self, recipeInfo)
        lastRecipe = recipeInfo
        SFP:Safe("profession profit", update, recipeInfo, self)
        SFP:Safe("profession stack prices", decorateSlots, self)
    end)
    -- the reagent slots may be built a moment after Init, and the prices and skill change as you pick reagents:
    -- look again twice a second while the form is shown
    local acc = 0
    form:HookScript("OnUpdate", function(self, dt)
        acc = acc + dt
        if acc < 0.5 then return end
        acc = 0
        SFP:Safe("profession stack prices", decorateSlots, self)
        if lastRecipe then SFP:Safe("profession profit", update, lastRecipe, self) end
    end)

    -- the button: best crafts of this profession, from the auction prices
    local btn = CreateFrame("Button", nil, PF, "UIPanelButtonTemplate")
    btn:SetSize(120, 22)
    btn:SetPoint("TOPRIGHT", PF, "TOPRIGHT", -72, -4)
    btn:SetText("Best profit")
    btn:SetScript("OnClick", function()
        local prof
        if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
            local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
            if ok and type(info) == "table" then prof = info.professionName end
        end
        if SFP.ShowShopFor then SFP:ShowShopFor(prof, true) end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("SeviathsUsefulTools")
        GameTooltip:AddLine("The best crafts of this profession by auction prices: the recipes you learned first, then the ones you have not learned yet.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- the Crafting Orders tab: a button that saves the orders the game has loaded (it also happens by itself while you browse)
    local ordersBtn = CreateFrame("Button", nil, PF, "UIPanelButtonTemplate")
    ordersBtn:SetSize(120, 22)
    ordersBtn:SetPoint("RIGHT", btn, "LEFT", -6, 0)
    ordersBtn:SetText("Read orders")
    ordersBtn:SetScript("OnClick", function() if SFP.ReadOrdersNow then SFP:ReadOrdersNow() end end)
    ordersBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("SeviathsUsefulTools")
        GameTooltip:AddLine("Save the crafting orders the game has loaded: the commission each pays, per item. It also happens by itself while you look through the orders. The game does not let addons ask for orders, so pick a category or press Search first.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    ordersBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ordersBtn:Hide()
    local function sync() ordersBtn:SetShown(PF.OrdersPage and PF.OrdersPage:IsShown() or false) end
    if PF.OrdersPage then
        PF.OrdersPage:HookScript("OnShow", sync)
        PF.OrdersPage:HookScript("OnHide", sync)
    end
    PF:HookScript("OnShow", sync)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_Professions" then return end
    C_Timer.After(0, function() SFP:Safe("profession window", hookWindow) end)
end)
SFP:OnLogin(function() SFP:Safe("profession window", hookWindow) end)
