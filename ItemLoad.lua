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

-- Only the tooltip of the addon itself is filled again when the item arrives. The tooltips of the game (GameTooltip, ItemRefTooltip) are never called from here: a call of
-- addon code on them taints them, and Blizzard's own code then fails with "execution tainted by SeviathsUsefulTools". For them the item is only requested (the game
-- refreshes its tooltip by itself when the item data arrives).
local function watch(tip, own)
    if not tip or tip.sutItemWatch or not tip.SetItemByID then return end
    tip.sutItemWatch = true
    hooksecurefunc(tip, "SetItemByID", function(self, id)
        if type(id) ~= "number" or cached(id) then return end
        if own then
            waiting[id] = waiting[id] or {}
            waiting[id][self] = true
        end
        pcall(C_Item.RequestLoadItemDataByID, id)
    end)
end

-- (a post-hook on the tooltips of the game is safe: it only asks the game to load the item)
local function hookGame(tip)
    if not tip or not tip.SetItemByID or tip.sutGameHook then return end
    tip.sutGameHook = true
    hooksecurefunc(tip, "SetItemByID", function(_, id)
        if type(id) == "number" and not cached(id) then pcall(C_Item.RequestLoadItemDataByID, id) end
    end)
end
hookGame(GameTooltip)
hookGame(ItemRefTooltip)
-- the tooltip of the addon (made on first use)
C_Timer.After(0, function() pcall(function() watch(SFP.Tip and SFP.Tip(), true) end) end)

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
