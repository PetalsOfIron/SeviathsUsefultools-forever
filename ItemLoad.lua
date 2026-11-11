-- SeviathsUsefulTools - items that are not loaded yet
-- A tooltip of an item the game has not loaded says "Retrieving item information" and stays like that. Here the item is requested from the game and, as soon as it has
-- arrived, the tooltip that was waiting for it is filled again.

local _, SFP = ...

local waiting = {}   -- [itemID] = list of tooltips that wait for it

local function cached(id)
    if C_Item and C_Item.IsItemDataCachedByID then
        local ok, r = pcall(C_Item.IsItemDataCachedByID, id)
        if ok then return r end
    end
    return true
end

local function watch(tip)
    if not tip or tip.sutItemWatch or not tip.SetItemByID then return end
    tip.sutItemWatch = true
    hooksecurefunc(tip, "SetItemByID", function(self, id)
        if type(id) ~= "number" or cached(id) then return end
        waiting[id] = waiting[id] or {}
        waiting[id][self] = true
        pcall(C_Item.RequestLoadItemDataByID, id)
    end)
end

watch(GameTooltip)
watch(ItemRefTooltip)
-- the tooltip of the addon (made on first use)
C_Timer.After(0, function() pcall(function() watch(SFP.Tip and SFP.Tip()) end) end)

local f = CreateFrame("Frame")
f:RegisterEvent("ITEM_DATA_LOAD_RESULT")
f:SetScript("OnEvent", function(_, _, id, success)
    local list = waiting[id]
    if not list then return end
    waiting[id] = nil
    if not success then return end
    for tip in pairs(list) do
        if tip:IsShown() then
            local owner = tip:GetOwner()
            if owner then pcall(tip.SetItemByID, tip, id) end
        end
    end
end)
