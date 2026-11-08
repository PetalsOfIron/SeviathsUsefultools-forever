-- Seviath's Codex — open quests and items in the Codex from anywhere
--
--  • Quest log / objective tracker: Alt+click a quest, or press the "Codex"
--    button on the quest details page.
--  • Items (bags, bank, chat links, loot, vendors, Auction House…): Alt+click.
--  • Chat quest/item links: Alt+click.
--  • /codex quest <id or name>   /codex item <link or id>

local ADDON, ns = SFP_Module("Codex")

------------------------------------------------------------------------
-- open helpers
------------------------------------------------------------------------
function ns:OpenQuest(questID)
    if not questID or questID == 0 then return end
    self:StartIndexing("quest")
    local key = "quest:" .. questID
    if not self:Get(key) then
        -- not scanned yet: build it now
        local rec = self.ReadQuestRaw and self.ReadQuestRaw(questID)
        if not rec then
            local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
            if title then rec = { t = title, o = "" } end
        end
        if rec then
            self.db.quests = self.db.quests or {}
            self.db.quests[questID] = self.db.quests[questID] or rec
            self.AddQuestEntry(questID, rec)
        end
    end
    if self:Get(key) then
        self:Open()
        self:ShowEntry(key)
    else
        if C_QuestLog.RequestLoadQuestByID then C_QuestLog.RequestLoadQuestByID(questID) end
        self:Print("loading that quest — try again in a second.")
    end
end

function ns:OpenItem(itemID, linkName)
    if not itemID then return end
    self:StartIndexing("item")
    local key = "item:" .. itemID
    if not self:Get(key) then
        if self.RecordItem then self.RecordItem(itemID) end
    end
    if not self:Get(key) then
        -- not cached yet: create it anyway, the name fills in when it loads
        local name = C_Item.GetItemNameByID(itemID) or linkName or ("item " .. itemID)
        local _, itemType = C_Item.GetItemInfoInstant(itemID)
        self:Add({
            cat = "item", id = itemID, name = name, itemID = itemID,
            group = self:ItemGroupFor(itemID, itemType), sub = itemType or "",
            icon = C_Item.GetItemIconByID(itemID), wh = "item=" .. itemID,
        })
        if not C_Item.GetItemNameByID(itemID) then
            C_Item.RequestLoadItemDataByID(itemID)
            C_Timer.After(0.6, function()
                local e = ns:Get(key)
                local n = C_Item.GetItemNameByID(itemID)
                if e and n then
                    e.name = n; e.lname = n:lower()
                    ns.db.items = ns.db.items or {}
                    ns.db.items[itemID] = ns.db.items[itemID] or { n = n, t = e.sub }
                    if ns.state and ns.state.selected == key then ns:ShowEntry(key, true) end
                end
            end)
        end
    end
    if self.MaybeMaterial then self:MaybeMaterial(itemID) end
    self:Open()
    self:ShowEntry(key)
end

local function ItemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)")), link:match("|h%[(.-)%]|h")
end

local function PetFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("battlepet:(%d+)"))
end

------------------------------------------------------------------------
-- Alt+click items anywhere (Blizzard routes modified item clicks here)
------------------------------------------------------------------------
if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if IsAltKeyDown() and not IsShiftKeyDown() and not IsControlKeyDown() then
            local id, name = ItemIDFromLink(link)
            if id then ns:OpenItem(id, name); return end
            local pet = PetFromLink(link)
            if pet and ns:Get("pet:" .. pet) then ns:Open(); ns:ShowEntry("pet:" .. pet) end
        end
    end)
end

-- Alt+click chat links (quests and items)
if SetItemRef then
    hooksecurefunc("SetItemRef", function(link)
        if not IsAltKeyDown() or type(link) ~= "string" then return end
        local qid = tonumber(link:match("^quest:(%d+)"))
        if qid then ns:OpenQuest(qid); return end
        local iid = tonumber(link:match("^item:(%d+)"))
        if iid then ns:OpenItem(iid); return end
        local pet = tonumber(link:match("^battlepet:(%d+)"))
        if pet and ns:Get("pet:" .. pet) then ns:Open(); ns:ShowEntry("pet:" .. pet) end
    end)
end

------------------------------------------------------------------------
-- Quest log + objective tracker
------------------------------------------------------------------------
-- Clicking a quest in the log or tracker opens its details through this.
for _, fname in ipairs({ "QuestMapFrame_OpenToQuestDetails", "QuestMapFrame_ShowQuestDetails" }) do
    if _G[fname] then
        hooksecurefunc(fname, function(questID)
            if IsAltKeyDown() then ns:OpenQuest(questID) end
        end)
    end
end

-- A "Codex" button on the quest details page
local function AddDetailsButton()
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    if not details or details.SeviathsCodexButton then return end
    local b = CreateFrame("Button", nil, details, "UIPanelButtonTemplate")
    b:SetSize(70, 22)
    b:SetText("Codex")
    b:SetPoint("TOPRIGHT", details, "TOPRIGHT", -8, -6)
    b:SetFrameLevel(details:GetFrameLevel() + 20)
    b:SetScript("OnClick", function()
        local qid = (C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()) or details.questID
        ns:OpenQuest(qid)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd100Seviath's|r Codex")
        GameTooltip:AddLine("Open this quest: what to do, how, and where.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    details.SeviathsCodexButton = b
end

local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
pcall(ev.RegisterEvent, ev, "ADDON_LOADED")
ev:SetScript("OnEvent", function()
    pcall(AddDetailsButton)
end)

------------------------------------------------------------------------
-- Hover a quest (quest log or objective tracker): what to do next and how
------------------------------------------------------------------------
local hoverOwner
-- our block is written once per tooltip: the flag is cleared when the tooltip is cleared for the next one
local questBlockShown = false
pcall(function() GameTooltip:HookScript("OnTooltipCleared", function() questBlockShown = false end) end)
local function QuestHoverTip(owner, questID, append)
    if not owner or type(questID) ~= "number" or questID <= 0 then return end
    -- append = the tooltip on screen belongs to a part of the quest line (a world quest's reward icon): our lines go below it
    if questBlockShown and GameTooltip:IsShown() and (append or GameTooltip:GetOwner() == owner) then return end
    if ns.db and ns.db.hideHint then return end
    pcall(function()
        local e = { id = questID, worldQuest = C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID) or nil }
        local complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)
        local nextObj = ns:QuestNextObjective(e)
        local lines = {}
        if complete then
            lines[#lines + 1] = "Done - go and turn it in."
        elseif nextObj then
            lines[#lines + 1] = "Next: " .. nextObj
            -- every other objective that is not done yet is listed under it (all of them are shown, also when they are in the same place)
            local okAll, allObjs = pcall(C_QuestLog.GetQuestObjectives, questID)
            if okAll and type(allObjs) == "table" then
                local seenText = { [nextObj] = true }
                for _, o in ipairs(allObjs) do
                    local t = o.text
                    if type(t) == "string" and t ~= "" and not o.finished and not seenText[t] then
                        seenText[t] = true
                        lines[#lines + 1] = "Also: " .. t
                    end
                end
            end
        end
        if not complete then
            for raw in (ns:QuestHowTo(e, nil, nextObj) or ""):gmatch("[^\n]+") do
                local tip = raw:gsub("^•%s*", "")
                if not tip:find("^Next step:") then lines[#lines + 1] = tip end
            end
        end
        -- where to go, by how far the quest is: the places of the objectives (items, kills) and then the NPC to speak with, each with its
        -- coordinates; a finished quest shows the NPC to hand it in to. Only a quest with none of that known shows the first place line.
        if ns.LearnQuestAreas then ns:LearnQuestAreas(questID) end
        local ql = ns.db and ns.db.qloc and ns.db.qloc[questID] or {}
        -- the name of the area at a spot (the sub-area the map shows, e.g. "Temple of Halazzi"), else the zone
        local function areaName(p)
            if not (p and p.m) then return nil end
            if C_Map and C_Map.GetMapInfoAtPosition and p.x and p.y then
                local okA, info = pcall(C_Map.GetMapInfoAtPosition, p.m, p.x, p.y)
                if okA and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
            end
            local okM, mi = pcall(C_Map.GetMapInfo, p.m)
            return okM and mi and mi.name or nil
        end
        local function placeText(p)
            local a = p.a or areaName(p)   -- the minimap's zone text saved with the spot, else the area the map shows there
            local xy = (p.x and p.y) and (" (" .. ("%.1f, %.1f"):format(p.x * 100, p.y * 100) .. ")") or ""
            return (a or "") .. xy
        end
        -- "<place> - <NPC name>", like the vendor lines of items
        local function spotText(p) return placeText(p) .. (p.n and (" - " .. p.n) or "") end
        -- what the next objective asks for decides the words: an item is picked up, a monster is killed
        local objLabel = "Objective at"
        local objItemName   -- the item the quest asks for ("Hunter's Tablet"), from the objective's own text
        local objIsItem = false   -- the objective is something to collect (an item), which monsters may drop
        local okO, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
        if okO and type(objs) == "table" then
            for _, o in ipairs(objs) do
                if not o.finished then
                    -- the words come from what the objective says, not only from its type (the game calls many tasks "monster")
                    objIsItem = (o.type == "item")
                    if o.type == "item" and type(o.text) == "string" then
                        local nmI = o.text:gsub("^%s*%d+%s*/%s*%d+%s*", "")
                        if nmI ~= "" then objItemName = nmI end
                    end
                    local txt = tostring(o.text or ""):lower()
                    local kill = txt:find("slain", 1, true) or txt:find("killed", 1, true) or txt:find("defeated", 1, true)
                        or txt:find("kill ", 1, true) or txt:find("destroyed", 1, true)
                    local pick = txt:find("collect", 1, true) or txt:find("gather", 1, true) or txt:find("pick", 1, true)
                        or txt:find("loot", 1, true) or txt:find("retriev", 1, true) or txt:find("recover", 1, true)
                    if kill then objLabel = "Monster at"
                    elseif o.type == "item" or pick then objLabel = "Collect at"   -- picked up, dropped by monsters, taken from objects: one name for all
                    elseif o.type == "object" then objLabel = "Collect at"
                    else objLabel = "Objective at" end
                    break
                end
            end
        end
        local added = false
        if not complete and ql.o then
            -- one line for a place: spots in the same area are said once
            local seenPlace = {}
            local shown = 0
            local lastLabel
            -- places where you really did something come first; the spot of a world quest's map icon is shown only when there is none
            local real = {}
            -- (a spot at the very edge of the map is the position of a map icon that was taken for a place: left out)
            for _, p in ipairs(ql.o) do
                local edge = p.x and p.y and (p.x < 0.03 or p.x > 0.97 or p.y < 0.03 or p.y > 0.97)
                if not p.icon and not edge then real[#real + 1] = p end
            end
            local spotsToShow = #real > 0 and real or ql.o
            for _, p in ipairs(spotsToShow) do
                local text = placeText(p)
                -- one line for a place: the same area name and the same part of the map; a pickup further off in the same area is a line of its own
                local area = (p.a or areaName(p) or text) .. "|" .. (p.x and (math.floor(p.x * 30) .. "," .. math.floor((p.y or 0) * 30)) or "")
                if not seenPlace[area] and shown < 1000 then
                    seenPlace[area] = true
                    shown = shown + 1
                    local clean = {}
                    -- monsters killed here, and the objects picked up or used here (a spot with only objects shows those)
                    local src = {}
                    for _, n in ipairs(type(p.names) == "table" and p.names or {}) do src[#src + 1] = n end
                    if not p.kill or not p.use then
                        for _, n in ipairs(type(p.unames) == "table" and p.unames or {}) do src[#src + 1] = n end
                    end
                    for _, n in ipairs(src) do
                        if not (n:find("|c", 1, true) or n:find("Seviath", 1, true)) then clean[#clean + 1] = n end
                    end
                    -- the items picked up here: the ones recorded with the spot, else the item the objective asks for
                    local itemNames = {}
                    for _, id in ipairs(type(p.loot) == "table" and p.loot or {}) do
                        local inm = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
                        if type(inm) == "string" and inm ~= "" then itemNames[#itemNames + 1] = inm
                        elseif C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
                    end
                    if #itemNames == 0 and objItemName and (p.use or p.kill or p.loot) then itemNames[1] = objItemName end
                    local nm
                    if #itemNames > 0 then
                        nm = " - |cffffd100" .. table.concat(itemNames, ", ") .. "|r" .. (#clean > 0 and ("  |cff808080from " .. table.concat(clean, ", ") .. "|r") or "")
                    else
                        nm = #clean > 0 and (" - " .. table.concat(clean, ", ")) or ""
                    end
                -- a spot where progress came from a kill says "Kill at", whatever the objective's own words are
                -- two kinds of monster objective: just kill them ("Monster at") and an item the monsters drop ("Monster item at", e.g. Lumpy Fish Guts)
                local spotLabel = (p.kill and (objIsItem and "Collect at" or "Monster at")) or (p.use and "Collect at") or objLabel
                if p.kill and p.use then
                    -- monsters killed and objects used at the same place: a line for each
                    local un = {}
                    for _, n in ipairs(type(p.unames) == "table" and p.unames or {}) do
                        if not (n:find("|c", 1, true) or n:find("Seviath", 1, true)) then un[#un + 1] = n end
                    end
                    lines[#lines + 1] = (spotLabel .. ": ") .. text .. nm
                    lines[#lines + 1] = "Collect at: " .. text .. (#un > 0 and (" - " .. table.concat(un, ", ")) or "")
                    spotLabel = "Collect at"
                else
                    lines[#lines + 1] = (spotLabel .. ": ") .. text .. nm
                end
                lastLabel = spotLabel
                    added = true
                end
            end
        end
        -- the people of the quest: who gave it and who takes it back (one line when it is the same person at the same place)
        -- every quest giver and every hand-in NPC is listed (a quest can be given at more than one place), each once
        local givers = ql.gs or (ql.g and { ql.g }) or {}
        local takers = ql.ts or (ql.t and { ql.t }) or {}
        local function samePerson(a, c)
            return a.n and c.n and a.n == c.n and a.m == c.m and a.x and c.x and math.abs(a.x - c.x) < 0.01 and math.abs(a.y - c.y) < 0.01
        end
        -- one line per place: everyone at the same place is listed by name on it
        local function peopleLines(label, list)
            local order, byPlace = {}, {}
            for _, p in ipairs(list) do
                local key = placeText(p)
                local g = byPlace[key]
                if not g then g = { text = key, names = {} }; byPlace[key] = g; order[#order + 1] = g end
                local have = false
                for _, n in ipairs(g.names) do if n == p.n then have = true break end end
                if p.n and not have then g.names[#g.names + 1] = p.n end
            end
            for _, g in ipairs(order) do
                lines[#lines + 1] = label .. ": " .. g.text .. (#g.names > 0 and (" - " .. table.concat(g.names, ", ")) or "")
                added = true
            end
        end
        local givers = ql.gs or (ql.g and { ql.g }) or {}
        local takers = ql.ts or (ql.t and { ql.t }) or {}
        local function samePerson(a, c)
            return a.n and c.n and a.n == c.n and a.m == c.m and a.x and c.x and math.abs(a.x - c.x) < 0.01 and math.abs(a.y - c.y) < 0.01
        end
        -- a person who gives and takes the quest is said once, as giver
        local onlyTakers = {}
        for _, t in ipairs(takers) do
            local both = false
            for _, g in ipairs(givers) do if samePerson(g, t) then both = true break end end
            if not both then onlyTakers[#onlyTakers + 1] = t end
        end
        peopleLines("Quest giver at", givers)
        peopleLines("Speak to at", ql.vs or {})
        peopleLines(complete and "Hand in at" or "Then hand in at", onlyTakers)
        if not added then
            local where = (ns:QuestWhere(e) or ""):match("[^\n]+")
            if where and not where:find("Not known yet") then lines[#lines + 1] = where end
        end
        if #lines == 0 then return end
        if GameTooltip:IsShown() and (append or GameTooltip:GetOwner() == owner) then
            GameTooltip:AddLine(" ")
        else
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        end
        GameTooltip:AddLine("|cffffd100Seviath's Codex|r - what to do")
        for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1, true) end
        GameTooltip:AddLine("|cffffd100Alt+click: open in Codex|r")
        GameTooltip:Show()
        questBlockShown = true
        hoverOwner = owner
    end)
end

-- the quest tooltip is rebuilt while it is shown when the quest's progress changes (an item picked up, a monster killed): the numbers in
-- "Next: 1/6 Stolen Equipment" follow the objective instead of staying as they were when the mouse arrived
local refreshFrame = CreateFrame("Frame")
for _, ev in ipairs({ "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "QUEST_WATCH_UPDATE", "BAG_UPDATE_DELAYED" }) do
    pcall(refreshFrame.RegisterEvent, refreshFrame, ev)
end
local lastRefresh = 0
refreshFrame:SetScript("OnEvent", function()
    if not hoverOwner or GetTime() - lastRefresh < 0.4 then return end
    local owner = hoverOwner
    if not (GameTooltip:IsShown() and GameTooltip:GetOwner() == owner and owner:IsShown() and owner:IsMouseOver()) then hoverOwner = nil return end
    lastRefresh = GetTime()
    C_Timer.After(0.3, function()
        if hoverOwner ~= owner or not owner:IsMouseOver() then return end
        local onEnter = owner.GetScript and owner:GetScript("OnEnter")
        if onEnter then
            GameTooltip:Hide()
            -- the owner builds its tooltip again: run through securecallfunction, so that our (tainted) code does not taint Blizzard's own
            -- handler and what it sets (a tainted tracker block makes a click on its header fail with ADDON_ACTION_BLOCKED)
            pcall(securecallfunction or function(fn, ...) return fn(...) end, onEnter, owner)
            -- (the hook on the owner's OnEnter adds our lines; they are not added a second time here)
        end
    end)
end)

-- quest log entries in the map window
if _G.QuestMapLogTitleButton_OnEnter then
    hooksecurefunc("QuestMapLogTitleButton_OnEnter", function(self)
        QuestHoverTip(self, self.questID)
    end)
end

-- the rewards tooltip of a world quest (tracker, map): the game writes it with these functions, which are given the quest; our lines are
-- added after it has been written, whatever frame it belongs to
for _, fname in ipairs({ "GameTooltip_AddQuestRewardsToTooltip", "QuestUtils_AddQuestRewardsToTooltip" }) do
    if _G[fname] and hooksecurefunc then
        pcall(hooksecurefunc, fname, function(tt, questID)
            if tt == GameTooltip and type(questID) == "number" and GameTooltip:GetOwner() then
                QuestHoverTip(GameTooltip:GetOwner(), questID, true)
            end
        end)
    end
end

local hookedBlocks = setmetatable({}, { __mode = "k" })
-- objective tracker blocks (the quest list on the right of the screen)
local function HookTrackerBlock(block)
    -- no field is written on Blizzard's block (a weak table remembers the hooked blocks instead)
    if type(block) ~= "table" or hookedBlocks[block] or not block.HookScript then return end
    hookedBlocks[block] = true
    block:HookScript("OnEnter", function(self)
        local qid = self.id or self.questID
        QuestHoverTip(self, qid)
        -- a world quest's tooltip (the rewards) is built a moment later, when the reward data has arrived, and that clears what was added:
        -- our lines are added again once it has settled (once per tooltip: the flag is cleared with the tooltip)
        if type(qid) == "number" and C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(qid) then
            for _, delay in ipairs({ 0.4, 1.2 }) do
                C_Timer.After(delay, function()
                    -- the rewards tooltip belongs to a child of the block (its icon), so the owner is not checked: the mouse is over the line
                    if self:IsMouseOver() and GameTooltip:IsShown() then QuestHoverTip(self, qid, true) end
                end)
            end
        end
    end)
    block:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function ScanTracker()
    for _, mname in ipairs({ "QuestObjectiveTracker", "CampaignQuestObjectiveTracker", "WorldQuestObjectiveTracker",
        "BonusObjectiveTracker" }) do
        local mod = _G[mname]
        if mod and type(mod.usedBlocks) == "table" then
            for _, byId in pairs(mod.usedBlocks) do
                if type(byId) == "table" then
                    for _, block in pairs(byId) do HookTrackerBlock(block) end
                end
            end
        end
    end
end
C_Timer.NewTicker(3, function() pcall(ScanTracker) end)

------------------------------------------------------------------------
-- Tooltip hint on items
------------------------------------------------------------------------
-- Registered a few seconds after login, so this hint is the LAST tooltip block to run: the game calls the item tooltip hooks in the order
-- they were registered, and the hint must come after the prices and the Seviaths lines. (Adding it a frame later made the tooltip
-- change size again and again, because the game refreshes a tooltip all the time.)
local function RegisterItemHint()
    if not (TooltipDataProcessor and Enum.TooltipDataType) then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        if tt ~= GameTooltip or not data or not data.id or InCombatLockdown() then return end
        if ns.db and ns.db.hideHint then return end
        tt:AddLine("|cffffd100Alt+click: open in Codex|r")
    end)
end
local hintFrame = CreateFrame("Frame")
hintFrame:RegisterEvent("PLAYER_LOGIN")
hintFrame:SetScript("OnEvent", function() C_Timer.After(8, RegisterItemHint) end)

------------------------------------------------------------------------
-- Slash: /codex quest …  /codex item …   (hooked into the main command)
------------------------------------------------------------------------
local base = SlashCmdList.SEVIATHSCODEX
SlashCmdList.SEVIATHSCODEX = function(msg)
    msg = msg or ""
    local kind, rest = msg:match("^%s*(%a+)%s+(.+)$")
    if kind == "quest" then
        local id = tonumber(rest)
        if id then ns:OpenQuest(id) return end
        ns:StartIndexing("all"); ns:Toggle(rest); return
    elseif kind == "item" then
        local id = ItemIDFromLink(rest) or tonumber(rest)
        if id then ns:OpenItem(id) return end
        ns:StartIndexing("all"); ns:Toggle(rest); return
    elseif msg:match("^%s*hint%s*$") then
        ns.db.hideHint = not ns.db.hideHint
        ns:Print("tooltip hints (items and quests) " .. (ns.db.hideHint and "off" or "on"))
        return
    end
    return base(msg)
end

-- keep the Best Grinding Spots ranking current: recalculated when the Codex opens (at most every 20 s)
do
    local open = ns.Open
    if open then
        ns.Open = function(self, ...)
            if self.RefreshGrind then pcall(self.RefreshGrind, self) end
            if self.RefreshHistory then pcall(self.RefreshHistory, self) end
            return open(self, ...)
        end
    end
end
