-- Seviath's Codex — window: categories | list | detail, search, minimap button

local ADDON, ns = SFP_Module("Codex")

local W, H        = 980, 620
local CAT_W       = 200
local LIST_W      = 320
local ROW_H       = 20
local CYAN        = ns.CYAN
local BACKDROP    = {
    bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local frame, searchBox, listRows, listSlider, detail, statusText

-- Only the group that is open holds its big data (see Lazy.lua): opening the Items or Quests section only counts the pages of each group,
-- the pages of a group are made when it is expanded (about 2 seconds) and removed when it is collapsed, another section is opened, or the
-- Codex is closed. A search builds everything.
function ns:ShowCategoryData(cat, searching)
    if searching then ns:IndexCategory("all") elseif cat then ns:IndexCategory(cat) end
    for _, lc in ipairs({ "item", "quest", "tmog" }) do
        local mine = (cat == lc) or (lc == "item" and cat == "material")
        if searching and lc == "tmog" then
            ns:UnloadAllLazy(lc)   -- 94,000 pages: never built by a search, open the section to browse them
        elseif searching then
            ns:LazyIndex(lc, function() ns:BuildAllLazy(lc) end)
        elseif mine then
            ns:LazyIndex(lc)
        else
            ns:UnloadAllLazy(lc)
        end
    end
end
function ns:IsOpen() return frame ~= nil and frame:IsShown() end
local catButtons = {}
local state = {
    cat = "guide",       -- selected category
    query = "",          -- active search
    flat = {},           -- rows currently in list
    offset = 0,
    collapsed = {},      -- [cat..group] = true/false
    selected = nil,      -- entry key
    history = {},
}
ns.state = state

------------------------------------------------------------------------
-- small widget helpers
------------------------------------------------------------------------
local function Panel(parent, alpha)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if _G.SeviathsUsefulTools and _G.SeviathsUsefulTools.BlizzardFrame then _G.SeviathsUsefulTools.BlizzardFrame(f, "inset") else f:SetBackdrop(BACKDROP) end
    return f
end

local function Button(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w or 120, 22)
    b:SetBackdrop(BACKDROP)
    b:SetBackdropColor(0.24, 0.07, 0.07, 0.95)
    b:SetBackdropBorderColor(0.9, 0.28, 0.24, 0.6)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetScript("OnEnter", function(s) s:SetBackdropColor(0.42, 0.10, 0.10, 1) end)
    b:SetScript("OnLeave", function(s) s:SetBackdropColor(0.24, 0.07, 0.07, 0.95) end)
    b:SetScript("OnDisable", function(s) s.text:SetTextColor(0.4, 0.4, 0.4) end)
    b:SetScript("OnEnable", function(s) s.text:SetTextColor(1, 1, 1) end)
    return b
end

local function catName(key)
    local c = ns.CATBYKEY[key]
    return c and c.name or key
end

------------------------------------------------------------------------
-- List building
------------------------------------------------------------------------
local function sortEntries(cat, list)
    if ns.TEXTCAT[cat] or cat == "mats" or cat == "grind" then
        table.sort(list, function(a, b) return (a.order or 0) < (b.order or 0) end)
    elseif cat == "boss" then
        table.sort(list, function(a, b)
            if a.sub ~= b.sub then return (a.sub or "") < (b.sub or "") end
            return (a.order or 0) < (b.order or 0)
        end)
    else
        table.sort(list, function(a, b) return a.name < b.name end)
    end
end

local function BuildFlat()
    local flat = {}
    if state.query ~= "" then
        local results = ns:Search(state.query, nil, 500)
        flat[#flat + 1] = { header = true, label = ("%d results for \"%s\""):format(#results, state.query), static = true }
        for _, e in ipairs(results) do flat[#flat + 1] = { entry = e, showCat = true } end
    else
        local cat = state.cat
        local byGroup = {}
        for _, e in ipairs(ns.byCat[cat]) do
            local g = byGroup[e.group]
            if not g then g = {}; byGroup[e.group] = g end
            g[#g + 1] = e
        end
        local groups = {}
        local seenG = {}
        for _, g in ipairs(ns.groups[cat]) do groups[#groups + 1] = g; seenG[g] = true end
        for g in pairs(byGroup) do
            if not seenG[g] then groups[#groups + 1] = g; seenG[g] = true end   -- entries whose group changed later
        end
        local lz = ns.lazy and ns.lazy[cat]
        if lz then
            for g in pairs(lz.groups) do
                if not seenG[g] then groups[#groups + 1] = g; seenG[g] = true end   -- groups whose pages are not built yet
            end
            table.sort(groups)
        end
        if ns.TEXTCAT[cat] or cat == "mats" or cat == "delve" then table.sort(groups) end
        -- a group name with " > " is a path (Classic > Crafting > Herbalism): the parts are sections inside sections, each opened on its own
        local nested = false
        for _, g in ipairs(groups) do if g:find(" > ", 1, true) then nested = true break end end
        if nested then table.sort(groups) end
        local small = #ns.byCat[cat] < 80 and not lz
        local prevParts = {}
        local pathCount = {}   -- entries under each path prefix
        local function split(name)
            local parts = {}
            for part in (name .. " > "):gmatch("(.-) > ") do parts[#parts + 1] = part end
            return parts
        end
        if nested then
            for _, gname in ipairs(groups) do
                local n = #(byGroup[gname] or {}) + (lz and ns:LazyPending(cat, gname) or 0)
                local prefix = ""
                for _, part in ipairs(split(gname)) do
                    prefix = prefix == "" and part or (prefix .. " > " .. part)
                    pathCount[prefix] = (pathCount[prefix] or 0) + n
                end
            end
        end
        for _, gname in ipairs(groups) do
            local list = byGroup[gname] or {}
            local pending = lz and ns:LazyPending(cat, gname) or 0
            if #list + pending > 0 then
                local parts = nested and split(gname) or { gname }
                local depth = #parts
                -- the headers of the path parts that changed since the last group; a closed part hides everything below it
                local open = true
                local prefix = ""
                for i = 1, depth - 1 do
                    prefix = prefix == "" and parts[i] or (prefix .. " > " .. parts[i])
                    if open then
                        local ck = cat .. "\001" .. prefix
                        local collapsed = state.collapsed[ck]
                        if collapsed == nil then collapsed = true end
                        local same = true
                        for j = 1, i do if prevParts[j] ~= parts[j] then same = false end end
                        if not same then
                            flat[#flat + 1] = { header = true, label = parts[i], count = pathCount[prefix], ckey = ck, collapsed = collapsed, indent = i - 1 }
                        end
                        if collapsed then open = false end
                    end
                end
                if open then
                    local ck = cat .. "\001" .. gname
                    local collapsed = state.collapsed[ck]
                    if collapsed == nil then collapsed = not small end
                    flat[#flat + 1] = { header = true, label = parts[depth], count = #list + pending, ckey = ck, collapsed = collapsed, lazyCat = lz and cat or nil, lazyGroup = gname, indent = depth - 1 }
                    if not collapsed and pending > 0 then ns:BuildLazyGroup(cat, gname) end
                    if not collapsed then
                        sortEntries(cat, list)
                        for _, e in ipairs(list) do flat[#flat + 1] = { entry = e, indent = depth - 1 } end
                    end
                end
                prevParts = parts
            end
        end
    end
    state.flat = flat
end

local function VisibleRows()
    return #listRows
end

local function UpdateList()
    local n = #state.flat
    local vis = VisibleRows()
    local maxOff = math.max(0, n - vis)
    if state.offset > maxOff then state.offset = maxOff end
    listSlider:SetMinMaxValues(0, maxOff)
    listSlider:SetValue(state.offset)
    if maxOff == 0 then listSlider:Hide() else listSlider:Show() end

    for i, row in ipairs(listRows) do
        local item = state.flat[i + state.offset]
        row.item = item
        if not item then
            row:Hide()
        else
            row:Show()
            if item.header then
                row.icon:Hide()
                row.check:Hide()
                row.text:SetPoint("LEFT", 6 + (item.indent or 0) * 14, 0)
                local arrow = item.static and "" or (item.collapsed and "+ " or "– ")
                row.text:SetText(CYAN .. arrow .. item.label .. "|r" .. (item.count and ("  |cff888888(" .. item.count .. ")|r") or ""))
                row.bg:SetColorTexture(0.36, 0.1, 0.1, 0.45)
            else
                local e = item.entry
                row.icon:Show()
                row.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.text:SetPoint("LEFT", 26 + (item.indent or 0) * 14, 0)
                row.icon:ClearAllPoints()
                row.icon:SetPoint("LEFT", 4 + (item.indent or 0) * 14, 0)
                local name = e.name
                if e.collected == false then name = "|cff9a9a9a" .. name .. "|r" end
                if item.showCat then name = name .. "  |cffff6a60" .. catName(e.cat) .. "|r" end
                row.text:SetText(name)
                row.check:SetShown(e.collected == true)
                if e.key == state.selected then
                    row.bg:SetColorTexture(0.9, 0.28, 0.24, 0.25)
                else
                    row.bg:SetColorTexture(0, 0, 0, (i % 2 == 0) and 0.15 or 0)
                end
            end
        end
    end
end

function ns:RefreshList(keepOffset)
    if not frame then return end
    BuildFlat()
    if not keepOffset then state.offset = 0 end
    UpdateList()
end

local function RefreshCategories()
    for _, b in ipairs(catButtons) do
        local n = ns:Count(b.cat)
        b.count:SetText(n > 0 and n or "")
        if b.cat == state.cat and state.query == "" then
            b.bg:SetColorTexture(0.9, 0.28, 0.24, 0.22)
        else
            b.bg:SetColorTexture(0, 0, 0, 0)
        end
    end
    if ns.status ~= "" then
        statusText:SetText(CYAN .. "Indexing:|r " .. ns.status .. (ns.progress and (" (" .. ns.progress .. ")") or "") .. "…")
    else
        local total = 0
        for k in pairs(ns.entries) do total = total + 1 end
        statusText:SetText(("|cff888888%d entries · /codex · Petalsofiron|r"):format(total))
    end
end

------------------------------------------------------------------------
-- Detail pane
------------------------------------------------------------------------
local relatedPool = {}

local function openJournal(e)
    if not C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal") then C_AddOns.LoadAddOn("Blizzard_EncounterJournal") end
    if EncounterJournal_OpenJournal then
        pcall(EncounterJournal_OpenJournal, nil, e.instanceID, e.encounterID)
    end
end

local OPENERS = {
    dungeon = { label = "Adventure Guide", fn = openJournal },
    raid    = { label = "Adventure Guide", fn = openJournal },
    boss    = { label = "Adventure Guide", fn = openJournal },
    mount   = { label = "Mount Journal", fn = function(e)
        if ToggleCollectionsJournal then ToggleCollectionsJournal(1) end
        if MountJournal_SelectByMountID then pcall(MountJournal_SelectByMountID, e.id) end
    end },
    pet     = { label = "Pet Journal", fn = function(e)
        if ToggleCollectionsJournal then ToggleCollectionsJournal(2) end
        if PetJournal_SelectSpecies and PetJournal then pcall(PetJournal_SelectSpecies, PetJournal, e.id) end
    end },
    achievement = { label = "Achievements", fn = function(e)
        if OpenAchievementFrameToAchievement then pcall(OpenAchievementFrameToAchievement, e.id) end
    end },
    tset    = { label = "Appearances", fn = function()
        if ToggleCollectionsJournal then ToggleCollectionsJournal(5) end
    end },
}

local function section(title, text)
    if not text or text == "" then return "" end
    return "\n\n" .. CYAN .. title .. "|r\n" .. text
end

local function DetailText(e)
    local t = ""
    local c = e.cat
    if e.bodyFn then return e.bodyFn(e) end
    -- towns, nodes and NPCs from the collected data: their text, and where they are
    if (c == "town" or c == "node" or (c == "npc" and not e.vendorKey)) and e.body then
        local where = e.map and (ns.CYAN .. "Where|r" .. "\n" .. ns:Coords(e.map) .. "\n\n") or ""
        return where .. e.body
    end
    if c == "delve" then
        if e.body then return e.body end
        if not e.map and ns.DelveGuideSpot then
            local spot = ns:DelveGuideSpot(e)
            if spot then e.map = spot end
        end
        local guide = ns.DelveGuideText and ns:DelveGuideText(e)
        local general = ns.DelveText and ns.DelveText(e) or ""
        if guide then
            return guide .. "\n\n" .. general
        end
        return general .. "\n\n|cff888888No specific guide for this delve yet (older expansion) — the general rules above apply.|r"
    end
    if (c == "creature" or c == "npc") and e.vendorKey and ns.VendorText then
        return ns:VendorText(e)
    end
    if c == "material" and ns.MaterialText then
        return ns:MaterialText(e)
    end
    if c == "mats" and e.farm and ns.FarmText then
        return ns:FarmText(e)
    end
    if c == "grind" then
        if e.grind and ns.GrindText then return ns:GrindText(e) end
        return e.body or ""
    end
    if c == "history" then
        return ns.HistoryEntryText and ns:HistoryEntryText(e) or ""
    end
    if ns.TEXTCAT[c] or c == "mats" then
        return e.body or ""
    end
    if c == "quest" then
        t = e.collected and "|cff40ff40Completed on this character|r"
            or (e.acctDone and "|cff40ff40Completed on another character of your account|r")
            or "|cffaaaaaaNot completed on this character|r"
    elseif e.collected ~= nil then
        t = t .. (e.collected and "|cff40ff40Collected / completed|r" or "|cffff7070Not collected yet|r")
    end
    if c == "mount" and ns.MountHowTo then
        local ok, txt = pcall(ns.MountHowTo, ns, e)
        if ok and txt and txt ~= "" then return txt end
    end
    if (c == "mount" or c == "pet") and ns.SourceHowTo then
        return (ns:SourceHowTo(e):gsub("^\n+", ""))
    end
    if c == "tset" and ns.SetHowTo then
        return (ns:SetHowTo(e):gsub("^\n+", ""))
    end
    if c == "achievement" and ns.AchievementHowTo then
        return (ns:AchievementHowTo(e):gsub("^\n+", ""))
    end
    if c == "mount" or c == "pet" then
        t = t .. section("How to get it", e.source)
        if c == "pet" then
            local extra = {}
            if e.wild then extra[#extra + 1] = "Wild — capture it in a pet battle." end
            if e.tradeable then extra[#extra + 1] = "Can be caged and sold." end
            if e.canBattle == false then extra[#extra + 1] = "Cannot battle." end
            t = t .. section("Notes", table.concat(extra, "\n"))
        end
    elseif (c == "dungeon" or c == "raid") and e.legacy and ns.LegacyInstanceText then
        t = t .. ns:LegacyInstanceText(e)
    elseif c == "dungeon" or c == "raid" then
        local info = {}
        if e.seasonal then info[#info + 1] = "In " .. e.seasonal .. " (Mythic+ / current rotation)" end
        if e.map then info[#info + 1] = "Entrance: " .. ns:Coords(e.map) end
        t = t .. section("Info", table.concat(info, "\n"))
        t = t .. section("Bosses & mechanics", ns:InstanceMechanics(e))
    elseif c == "rare" then
        t = t .. section("Location", ns:Coords(e.map))
        t = t .. section("Mechanics", "Blizzard doesn't give addons a rare's abilities, so they can't be listed here. Rares usually hit harder than normal enemies and many have a cast you should interrupt or a frontal to sidestep. Use the Wowhead link for player notes.")
    elseif c == "boss" then
        local inst = e.instKey and ns:Get(e.instKey)
        if inst and inst.map and not e.map then e.map = inst.map end
        if inst then t = t .. section("Instance", inst.name .. (e.order and ("  ·  boss " .. e.order) or "")) end
        t = t .. section("Mechanics", ns:BossAbilities(e))
    elseif c == "creature" then
        if e.body and e.body ~= "" and (e.id:find("^special:") or e.id:find("^tame:") or e.id:find("^beast:") or e.id:find("^npc:")) then
            t = t .. "\n\n" .. e.body
        else
            t = t .. section("Appears in", e.sub)
        end
        if not e.map then
            for _, k in ipairs(e.refs or {}) do
                local b = ns:Get(k)
                local inst = b and b.instKey and ns:Get(b.instKey)
                if inst and inst.map then
                    e.map = inst.map
                    t = t .. section("Where", "Inside " .. inst.name .. " — entrance " .. ns:Coords(inst.map))
                    break
                end
            end
        end
        if not e.map and e.zoneText and ns.ZoneByName then
            e.openMap = ns:ZoneByName((e.zoneText:gsub("%s*%(.-%)", "")))
        end
    elseif c == "item" then
        t = t .. ns:ItemExplain(e)
        if ns.BestPlace then t = t .. "\n\n" .. ns:BestPlace(e, e.itemID or e.id) end
    elseif c == "entrance" then
        t = t .. "\n\n" .. ns:EntranceRoute(e)
    elseif c == "quest" then
        local obj = ns:QuestObjectives(e)
        local nextObj = ns:QuestNextObjective(e)
        t = t .. section("What to do", obj or "No objective text — usually a 'talk to' or automatic quest.")
        local story = ns:QuestStory(e)
        if story then t = t .. section("What the quest says", story) end
        t = t .. section("How to do it", ns:QuestHowTo(e, obj, nextObj))
        t = t .. section("Where to go", ns:QuestWhere(e))
        if e.tag then t = t .. section("Type", e.tag .. (e.worldQuest and " (world quest)" or "")) end
    elseif c == "achievement" then
        t = t .. section("Goal", e.body)
        if e.reward and e.reward ~= "" then t = t .. section("Reward", e.reward) end
        if e.points then t = t .. "\n\n|cff888888" .. e.points .. " points|r" end
        t = t .. section("Criteria", ns:AchievementCriteria(e))
    elseif c == "tset" then
        t = t .. section("Info", e.sub)
        t = t .. section("Pieces", ns:SetItems(e))
    end
    -- items: where your own loot of it came from (collected by the addon when you loot), with the spot
    if c == "item" or c == "tmog" then
        local S = _G.SeviathsUsefulTools
        local rec = S and S.db and S.db.itemFrom and S.db.itemFrom[e.itemID or tonumber(e.id) or 0]
        if rec and rec.src then
            local lines = {}
            for key, src in pairs(rec.src) do
                local kind, id = key:match("^(%a+):(%d+)$")
                local nm
                if kind == "npc" then
                    id = tonumber(id)
                    nm = (S.db.killPos and S.db.killPos[id] and S.db.killPos[id].n) or (S.db.npcPos and S.db.npcPos[id] and S.db.npcPos[id].n)
                end
                lines[#lines + 1] = (nm or key) .. " x" .. (src.c or 1) .. ((src.m and src.x) and (", " .. ns:Coords({ m = src.m, x = src.x, y = src.y })) or "")
            end
            table.sort(lines)
            if #lines > 0 then t = t .. section("You looted it from", table.concat(lines, "\n")) end
        end
    end
    -- a monster: the items Wowhead lists for it (gear, bags, pets, materials ...), read only for this monster
    if c == "creature" or c == "boss" or c == "rare" then
        local S = _G.SeviathsUsefulTools
        local list = e.npcID and S and S.WowheadDrops and S:WowheadDrops(e.npcID)
        if not list and c == "boss" and S and S.WowheadDropsByName then list = S:WowheadDropsByName(e.name) end
        -- what you picked up from this boss yourself (filed by the boss killed, for dungeons and raids)
        if c == "boss" and S and S.db and S.db.bossLoot then
            local mine = {}
            for _, bosses in pairs(S.db.bossLoot) do
                local rec = type(bosses) == "table" and bosses[e.name]
                if type(rec) == "table" and rec.d then
                    for id, n in pairs(rec.d) do mine[id] = (mine[id] or 0) + n end
                end
            end
            local ids = {}
            for id in pairs(mine) do ids[#ids + 1] = id end
            table.sort(ids)
            if #ids > 0 then
                local lines = {}
                for _, id in ipairs(ids) do
                    local nm = C_Item.GetItemNameByID(id) or ("item " .. id)
                    lines[#lines + 1] = "• " .. nm .. "  x" .. mine[id]
                end
                t = t .. section("You picked up", table.concat(lines, "\n"))
            end
        end
        if list and #list > 0 then
            local lines = {}
            local own = S.Npc and e.npcID and S:Npc(e.npcID)
            for i = 1, math.min(#list, 40) do
                local id = list[i]
                local nm = C_Item.GetItemNameByID(id)
                if not nm then nm = "item " .. id; C_Item.RequestLoadItemDataByID(id) end
                -- the chance from your own kills, with how many kills it takes ("12.5% (1 in 8)")
                local chance = (type(own) == "table" and own.d and S.ChanceText) and S.ChanceText(own.d[id], own.k or 0) or ""
                lines[#lines + 1] = "• " .. nm .. (chance ~= "" and ("  " .. chance) or "")
            end
            if #list > 40 then lines[#lines + 1] = "|cff888888+ " .. (#list - 40) .. " more|r" end
            t = t .. section("Drops (Wowhead)", table.concat(lines, "\n"))
        end
    end
    -- an item that is a transmog item: where it comes from (Wowhead's list, read only for this item)
    if c == "item" or c == "tmog" then
        local S = _G.SeviathsUsefulTools
        local tm = S and S.TransmogItem and S:TransmogItem(e.itemID or tonumber(e.id) or 0)
        if tm and tm.source then
            local info = {}
            info[#info + 1] = tm.source .. (tm.sourceName and (": " .. tm.sourceName) or "")
            if tm.type or tm.slot then info[#info + 1] = (tm.type or "") .. ((tm.type and tm.slot) and " " or "") .. (tm.slot and tm.slot:lower() or "") end
            info[#info + 1] = "For: " .. (tm.classes and table.concat(tm.classes, ", ") or "all classes")
            if tm.reqLevel and tm.reqLevel > 1 then info[#info + 1] = "Requires level " .. tm.reqLevel end
            t = t .. section("Transmog", table.concat(info, "\n"))
        end
    end
    -- quests: where you accepted and where you turned the quest in (collected by the addon as you do them)
    if c == "quest" then
        local S = _G.SeviathsUsefulTools
        local lib = S and S.Social and S.Social.Config and S.Social.Config().lib
        local rec = lib and lib.quest and lib.quest[tonumber(e.id) or e.questID or 0]
        if rec then
            local parts = {}
            if rec.map and rec.x then parts[#parts + 1] = "Taken from: " .. (rec.giverName and (rec.giverName .. ", ") or "") .. ns:Coords({ m = rec.map, x = rec.x, y = rec.y }) end
            if rec.doneMap and rec.doneX then parts[#parts + 1] = "Turned in to: " .. (rec.turnName and (rec.turnName .. ", ") or "") .. ns:Coords({ m = rec.doneMap, x = rec.doneX, y = rec.doneY }) end
            if #parts > 0 then t = t .. section("Where you did it", table.concat(parts, "\n")) end
        end
    end
    -- the places you have been to: collected by the addon when you enter a dungeon or a raid (every expansion, old ones too)
    if c == "dungeon" or c == "raid" or c == "entrance" then
        local S = _G.SeviathsUsefulTools
        local lib = S and S.Social and S.Social.Config and S.Social.Config().lib
        local kind = (c == "raid" or (c == "entrance" and e.isRaid)) and "raid" or "dungeon"
        local seen = lib and lib[kind]
        if seen and e.name then
            local want, hit = e.name:lower(), nil
            -- by ID first (the Adventure Guide ID or the instance ID saved when you entered), then by name
            for _, rec in pairs(seen) do
                if (rec.jid and rec.jid == tonumber(e.id)) or (rec.id and e.instanceID and rec.id == e.instanceID) then hit = rec break end
            end
            if not hit then
                for en, rec in pairs(seen) do
                    local el = en:lower()
                    if el:find(want, 1, true) or want:find(el, 1, true) then hit = rec break end
                end
            end
            if hit then
                local diffs = {}
                for d in pairs(hit.diffs or {}) do diffs[#diffs + 1] = d end
                table.sort(diffs)
                t = t .. section("You have been here", ("Entered %d time%s%s%s"):format(hit.n or 1, (hit.n or 1) == 1 and "" or "s",
                    hit.t and (", last " .. date("%Y-%m-%d", hit.t)) or "", #diffs > 0 and ("\nDifficulties: " .. table.concat(diffs, ", ")) or ""))
            else
                t = t .. section("You have been here", "|cff888888Not entered yet. The addon notes it when you walk in.|r")
            end
        end
    end
    -- what your own collections already say (transmog, mounts, pets), also from before the addon was installed
    do
        local S = _G.SeviathsUsefulTools
        if S and S.HistoryFor and (c == "boss" or c == "creature" or c == "rare") then
            local past = S:HistoryFor(e.name)
            if past then t = t .. section("Your collection", S:HistoryText(past)) end
        elseif S and S.db and S.db.history and c == "item" then
            local iid = e.itemID or tonumber(e.id)
            if iid and S.db.history.items[iid] then t = t .. section("Your collection", "You already own this appearance (transmog collection).") end
        end
    end
    return (t:gsub("^\n+", ""))
end

local function LayoutDetail()
    local child = detail.child
    local w = detail.scroll:GetWidth() - 8
    child:SetWidth(w)
    detail.body:SetWidth(w - 12)
    local y = 122 + detail.body:GetStringHeight() + 14
    local shown = 0
    for _, b in ipairs(relatedPool) do
        if b:IsShown() then
            shown = shown + 1
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", child, "TOPLEFT", 6, -(y + (shown - 1) * 20 + 18))
            b:SetWidth(w - 16)
        end
    end
    detail.relHeader:ClearAllPoints()
    detail.relHeader:SetPoint("TOPLEFT", child, "TOPLEFT", 6, -y)
    detail.relHeader:SetShown(shown > 0)
    child:SetHeight(y + shown * 20 + 40)
end

function ns:ShowEntry(key, noHistory)
    local e = ns:Get(key)
    if not e or not frame then return end
    if state.selected and not noHistory and state.selected ~= key then
        state.history[#state.history + 1] = state.selected
    end
    state.selected = key
    detail.back:SetEnabled(#state.history > 0)

    detail.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    detail.title:SetText(e.name)
    detail.sub:SetText(CYAN .. catName(e.cat) .. "|r  ·  " .. (e.group or ""))
    local okText, text = pcall(DetailText, e)
    if not okText then
        text = "|cffff6060This page hit an error:|r " .. tostring(text) .. "\n\n|cff888888Please send this line to the Codex author.|r"
    end
    -- what was collected in the game about the same creature (kills, drops, where seen) goes on the page that already exists
    -- battle pets: the cheapest auction price of this species, from the scans (this realm's, else any scanned realm's)
    if e.cat == "pet" and type(e.id) == "number" then
        local S = _G.SeviathsUsefulTools
        local all = S and S.db and S.db.petPrices
        local price = all and S.RealmKey and all[S:RealmKey()] and all[S:RealmKey()][e.id]
        if not price and all then
            for _, byRealm in pairs(all) do
                if byRealm[e.id] and (not price or byRealm[e.id] < price) then price = byRealm[e.id] end
            end
        end
        if price then text = (text or "") .. "\n\n" .. ns.CYAN .. "Auction price|r\n" .. S:FormatPrice(price) end
    end
    if e.seenData and e.seenData ~= "" then text = (text or "") .. "\n\n" .. ns.CYAN .. "Details|r\n" .. e.seenData end
    detail.body:SetText(text or "")

    -- buttons
    detail.mapBtn:SetEnabled(e.map ~= nil or e.openMap ~= nil)
    detail.mapBtn.text:SetText((ns.pin and ns.pin.key == e.key) and "Remove pin" or (e.map and "Show on map" or "Open map"))
    local op = OPENERS[e.cat]
    if op then
        detail.openBtn.text:SetText(op.label)
        detail.openBtn:Show()
    else
        detail.openBtn:Hide()
    end
    detail.linkBtn:SetEnabled(e.link ~= nil)
    local url = ns:WowheadURL(e)
    detail.wh:SetText(url or "")
    detail.wh:SetCursorPosition(0)
    detail.wh:SetShown(url ~= nil)
    detail.whLabel:SetShown(url ~= nil)

    -- related entries
    for _, b in ipairs(relatedPool) do b:Hide() end
    local seen, n = {}, 0
    for _, rk in ipairs(e.refs or {}) do
        if not seen[rk] and n < 200 then
            seen[rk] = true
            local r = ns:Get(rk)
            if r then
                n = n + 1
                local b = relatedPool[n]
                if not b then
                    b = CreateFrame("Button", nil, detail.child)
                    b:SetHeight(18)
                    b.icon = b:CreateTexture(nil, "ARTWORK")
                    b.icon:SetSize(16, 16)
                    b.icon:SetPoint("LEFT")
                    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    b.text:SetPoint("LEFT", 22, 0)
                    b.text:SetPoint("RIGHT")
                    b.text:SetJustifyH("LEFT")
                    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
                    b:GetHighlightTexture():SetVertexColor(0.9, 0.28, 0.24, 0.15)
                    b:SetScript("OnClick", function(s) ns:ShowEntry(s.key) end)
                    relatedPool[n] = b
                end
                b.key = r.key
                b.icon:SetTexture(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                b.text:SetText(r.name .. "  |cffff6a60" .. catName(r.cat) .. "|r")
                b:Show()
            end
        end
    end
    detail.scroll:SetVerticalScroll(0)
    LayoutDetail()
    UpdateList()
end

------------------------------------------------------------------------
-- Window construction
------------------------------------------------------------------------
local function CreateWindow()
    frame = Panel(UIParent, 0.96)
    if _G.SeviathsUsefulTools and _G.SeviathsUsefulTools.BlizzardFrame then _G.SeviathsUsefulTools.BlizzardFrame(frame, true) end   -- the red dialog look
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    if _G.SeviathsUsefulTools and _G.SeviathsUsefulTools.RegisterWindow then _G.SeviathsUsefulTools.RegisterWindow(frame) end
    frame:SetMovable(true)
    frame:SetResizable(false)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    tinsert(UISpecialFrames, "SeviathsCodexFrame")
    _G.SeviathsCodexFrame = frame

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText(CYAN .. "Seviath's|r Codex")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local pinBtn = Button(frame, "No pin", 120)
    pinBtn:SetPoint("RIGHT", close, "LEFT", -6, 0)
    pinBtn:SetScript("OnClick", function()
        if ns.pin then
            if IsShiftKeyDown() then
                ns:ClearPin()
            elseif ns.pin.key and ns:Get(ns.pin.key) then
                ns:ShowEntry(ns.pin.key)
                if OpenWorldMap and not InCombatLockdown() then OpenWorldMap(ns.pin.m) end
            end
        end
    end)
    pinBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.42, 0.10, 0.10, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if ns.pin then
            GameTooltip:AddLine("Pin: " .. (ns.pin.title or "?"), 1, 1, 1)
            GameTooltip:AddLine("Click: show it on the map", 1, 0.6, 0.55)
            GameTooltip:AddLine("Shift+click or the X: remove it", 1, 0.6, 0.55)
        else
            GameTooltip:AddLine("No pin set. Use Show on map on any page.", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    pinBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.24, 0.07, 0.07, 0.95); GameTooltip:Hide() end)
    local pinX = Button(frame, "X", 22)
    pinX:SetPoint("RIGHT", pinBtn, "LEFT", -2, 0)
    pinX:SetScript("OnClick", function() ns:ClearPin() end)
    frame.pinBtn, frame.pinX = pinBtn, pinX
    function ns:OnPinChanged()
        if self.pin then
            local t = self.pin.title or "?"
            if #t > 14 then t = t:sub(1, 13) .. "…" end
            pinBtn.text:SetText("Pin: " .. t)
            pinX:Show()
        else
            pinBtn.text:SetText("No pin")
            pinX:Hide()
        end
        local e = state.selected and ns:Get(state.selected)
        if e and detail and detail.mapBtn then
            detail.mapBtn.text:SetText((self.pin and self.pin.key == e.key) and "Remove pin" or (e.map and "Show on map" or "Open map"))
        end
    end
    pinX:Hide()

    -- search box
    searchBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    searchBox:SetSize(360, 24)
    searchBox:SetPoint("TOP", 0, -10)
    searchBox:SetBackdrop(BACKDROP)
    searchBox:SetBackdropColor(0, 0, 0, 0.95)
    searchBox:SetBackdropBorderColor(0.9, 0.28, 0.24, 0.7)
    searchBox:SetFontObject("ChatFontNormal")
    searchBox:SetTextInsets(8, 8, 0, 0)
    searchBox:SetAutoFocus(false)
    local ph = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 10, 0)
    ph:SetText("Search everything: boss, item, mount, dungeon, quest…")
    local pending
    searchBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        ph:SetShown(txt == "")
        if pending then pending:Cancel() end
        pending = C_Timer.NewTimer(0.25, function()
            state.query = txt
            if txt ~= "" then ns:ShowCategoryData(state.cat, true) end   -- a search looks in everything: the big pages are made
            ns:RefreshList()
            RefreshCategories()
        end)
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local first = state.flat[2]
        if first and first.entry then ns:ShowEntry(first.entry.key) end
    end)

    -- categories
    local cats = Panel(frame, 0.6)
    cats:SetPoint("TOPLEFT", 10, -44)
    cats:SetPoint("BOTTOMLEFT", 10, 30)
    cats:SetWidth(CAT_W)
    -- squeeze the buttons so every category fits, however many there are
    local catStep = math.max(20, math.min(32, math.floor((H - 44 - 30 - 12) / #ns.CATEGORIES)))
    for i, c in ipairs(ns.CATEGORIES) do
        local b = CreateFrame("Button", nil, cats)
        b:SetSize(CAT_W - 8, catStep - 2)
        b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * catStep)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        b:GetHighlightTexture():SetVertexColor(0.9, 0.28, 0.24, 0.12)
        local ic = b:CreateTexture(nil, "ARTWORK")
        ic:SetSize(22, 22)
        ic:SetPoint("LEFT", 4, 0)
        ic:SetTexture(c.icon)
        ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("LEFT", 32, 0)
        t:SetText(c.name)
        b.count = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        b.count:SetPoint("RIGHT", -4, 0)
        b.cat = c.key
        b:SetScript("OnClick", function()
            state.cat = c.key
            ns:ShowCategoryData(c.key, false)
            if searchBox:GetText() ~= "" then searchBox:SetText("") end
            state.query = ""
            ns:RefreshList()
            RefreshCategories()
        end)
        catButtons[#catButtons + 1] = b
    end

    -- list
    local list = Panel(frame, 0.6)
    list:SetPoint("TOPLEFT", cats, "TOPRIGHT", 6, 0)
    list:SetPoint("BOTTOMLEFT", cats, "BOTTOMRIGHT", 6, 0)
    list:SetWidth(LIST_W)
    list:EnableMouseWheel(true)
    listRows = {}
    local listH = H - 44 - 30 - 8
    local nRows = math.floor(listH / ROW_H)
    for i = 1, nRows do
        local r = CreateFrame("Button", nil, list)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_H)
        r:SetPoint("RIGHT", -16, 0)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        r:GetHighlightTexture():SetVertexColor(0.9, 0.28, 0.24, 0.12)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("LEFT", 4, 0)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", 26, 0)
        r.text:SetPoint("RIGHT", -18, 0)
        r.text:SetJustifyH("LEFT")
        r.text:SetWordWrap(false)
        r.check = r:CreateTexture(nil, "OVERLAY")
        r.check:SetSize(14, 14)
        r.check:SetPoint("RIGHT", -2, 0)
        r.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        r:SetScript("OnClick", function(self)
            local it = self.item
            if not it then return end
            if it.header then
                if it.ckey then
                    state.collapsed[it.ckey] = not it.collapsed
                    -- a group of a lazy section that was just collapsed gives its pages back
                    if it.lazyCat and state.collapsed[it.ckey] then ns:UnloadLazyGroup(it.lazyCat, it.lazyGroup) end
                    ns:RefreshList(true)
                end
            else
                ns:ShowEntry(it.entry.key)
            end
        end)
        r:SetScript("OnEnter", function(self)
            local e = self.item and self.item.entry
            if not e then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local ok = false
            if e.cat == "item" and e.itemID then
                ok = pcall(GameTooltip.SetItemByID, GameTooltip, e.itemID)
            end
            if not ok then
                GameTooltip:AddLine(e.name, 1, 1, 1)
                if e.sub and e.sub ~= "" then GameTooltip:AddLine(e.sub, 0.6, 0.85, 0.9, true) end
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        listRows[i] = r
    end

    listSlider = CreateFrame("Slider", nil, list)
    listSlider:SetOrientation("VERTICAL")
    listSlider:SetPoint("TOPRIGHT", -3, -4)
    listSlider:SetPoint("BOTTOMRIGHT", -3, 4)
    listSlider:SetWidth(10)
    local track = listSlider:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.4)
    listSlider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    listSlider:GetThumbTexture():SetVertexColor(0.9, 0.28, 0.24, 0.7)
    listSlider:GetThumbTexture():SetSize(10, 30)
    listSlider:SetValueStep(1)
    listSlider:SetObeyStepOnDrag(true)
    listSlider:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v + 0.5)
        if v ~= state.offset then state.offset = v; UpdateList() end
    end)
    list:SetScript("OnMouseWheel", function(_, delta)
        state.offset = math.max(0, state.offset - delta * 3)
        UpdateList()
    end)

    -- detail
    local d = Panel(frame, 0.6)
    d:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
    d:SetPoint("BOTTOMRIGHT", -10, 30)
    detail = d
    d.scroll = CreateFrame("ScrollFrame", nil, d)
    d.scroll:SetPoint("TOPLEFT", 4, -4)
    d.scroll:SetPoint("BOTTOMRIGHT", -4, 4)
    d.scroll:EnableMouseWheel(true)
    d.child = CreateFrame("Frame", nil, d.scroll)
    d.child:SetSize(400, 400)
    d.scroll:SetScrollChild(d.child)
    d.scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxV = math.max(0, d.child:GetHeight() - self:GetHeight())
        local v = math.min(maxV, math.max(0, self:GetVerticalScroll() - delta * 40))
        self:SetVerticalScroll(v)
    end)
    local child = d.child

    d.icon = child:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(40, 40)
    d.icon:SetPoint("TOPLEFT", 6, -8)
    d.title = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    d.title:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, -2)
    d.title:SetPoint("RIGHT", child, "RIGHT", -70, 0)
    d.title:SetJustifyH("LEFT")
    d.title:SetTextColor(1, 1, 1)
    d.sub = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -4)
    d.sub:SetPoint("RIGHT", child, "RIGHT", -10, 0)
    d.sub:SetJustifyH("LEFT")

    d.back = Button(child, "< Back", 60)
    d.back:SetPoint("TOPRIGHT", child, "TOPRIGHT", -6, -8)
    d.back:SetScript("OnClick", function()
        local k = table.remove(state.history)
        if k then ns:ShowEntry(k, true) end
    end)

    d.mapBtn = Button(child, "Show on map", 100)
    d.mapBtn:SetPoint("TOPLEFT", 6, -62)
    d.mapBtn:SetScript("OnClick", function()
        local e = ns:Get(state.selected)
        if not e then return end
        if ns.pin and ns.pin.key == e.key then
            ns:ClearPin()
        elseif e.map then
            ns:Waypoint(e.map.m, e.map.x, e.map.y, e.name, e.key)
        elseif e.openMap and OpenWorldMap then
            OpenWorldMap(e.openMap)
        end
    end)

    d.openBtn = Button(child, "Open", 110)
    d.openBtn:SetPoint("LEFT", d.mapBtn, "RIGHT", 6, 0)
    d.openBtn:SetScript("OnClick", function()
        local e = ns:Get(state.selected)
        local op = e and OPENERS[e.cat]
        if op then op.fn(e) end
    end)
    d.linkBtn = Button(child, "Link in chat", 90)
    d.linkBtn:SetPoint("LEFT", d.openBtn, "RIGHT", 6, 0)
    d.linkBtn:SetScript("OnClick", function()
        local e = ns:Get(state.selected)
        if e and e.link then
            if not ChatEdit_InsertLink(e.link) then ChatFrame_OpenChat(e.link) end
        end
    end)
    d.whLabel = child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d.whLabel:SetPoint("TOPLEFT", d.mapBtn, "BOTTOMLEFT", 0, -8)
    d.whLabel:SetText("Wowhead:")
    d.wh = CreateFrame("EditBox", nil, child, "BackdropTemplate")
    d.wh:SetHeight(20)
    d.wh:SetPoint("LEFT", d.whLabel, "RIGHT", 4, 0)
    d.wh:SetPoint("RIGHT", child, "RIGHT", -6, 0)
    d.wh:SetBackdrop(BACKDROP)
    d.wh:SetBackdropColor(0, 0, 0, 0.95)
    d.wh:SetBackdropBorderColor(0.9, 0.28, 0.24, 0.3)
    d.wh:SetFontObject("GameFontHighlightSmall")
    d.wh:SetTextInsets(4, 4, 0, 0)
    d.wh:SetAutoFocus(false)
    d.wh:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    d.wh:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    d.wh:SetScript("OnTextChanged", function(self, user)
        if user then local e = ns:Get(state.selected); self:SetText(ns:WowheadURL(e) or ""); self:HighlightText() end
    end)

    d.body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.body:SetPoint("TOPLEFT", 8, -122)
    d.body:SetJustifyH("LEFT")
    d.body:SetJustifyV("TOP")
    d.body:SetSpacing(2)
    d.body:SetText("")

    d.relHeader = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    d.relHeader:SetText(CYAN .. "Related|r")

    -- status bar
    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", 14, 10)

    frame:SetScript("OnHide", function()
        -- closed: the section's big pages are taken out of memory at once (only one section holds data), made again when it opens
        C_Timer.After(0.2, function()
            if frame:IsShown() then return end
            ns:UnloadAllLazy("item")
            ns:UnloadAllLazy("quest")
            ns:UnloadAllLazy("tmog")
            ns:UnloadAll()
            state.selected = nil
            state.history = {}
            state.flat = {}   -- the rows still pointed at the removed pages
            for _, r in ipairs(listRows or {}) do r.item = nil; r.entry = nil end
            collectgarbage("collect")
        end)
    end)
    frame:SetScript("OnShow", function()
        if ns.ResumeJobs then ns:ResumeJobs() end
        ns:ShowCategoryData(state.cat, state.query ~= "")   -- the section that was open last (the guide page when it is a new session)
        RefreshCategories()
        ns:RefreshList()
        if not state.selected then ns:ShowEntry("guide:codex", true) end
    end)
end

-- live refresh while indexing (throttled)
local lastRefresh = 0
function ns:OnDataChanged()
    if not frame or not frame:IsShown() then return end
    if GetTime() - lastRefresh < 1.5 then return end
    lastRefresh = GetTime()
    RefreshCategories()
    if state.query ~= "" or #state.flat < 2 then ns:RefreshList(true) else BuildFlat(); UpdateList() end
end

function ns:OnJobsDone()
    if frame and frame:IsShown() then
        RefreshCategories()
        ns:RefreshList(true)
    end
end

function ns:Open()
    if not frame then CreateWindow() end
    frame:Show()
end

function ns:OpenCategory(key)
    if not frame then CreateWindow() end
    frame:Show()
    if ns.CATBYKEY[key] then
        state.cat = key
        ns:ShowCategoryData(key, false)
        if searchBox:GetText() ~= "" then searchBox:SetText("") end
        state.query = ""
        ns:RefreshList()
        if RefreshCategories then RefreshCategories() end
    end
end

function ns:Toggle(query)
    if not frame then CreateWindow() end
    if query then
        frame:Show()
        searchBox:SetText(query)
        return
    end
    frame:SetShown(not frame:IsShown())
end

------------------------------------------------------------------------
-- Minimap button
------------------------------------------------------------------------
local mm
local function PlaceMinimap()
    local a = math.rad(ns.db.minimap.angle or 200)
    local r = (Minimap:GetWidth() / 2) + 5
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function ns:CreateMinimapButton()
    if mm then return end
    mm = CreateFrame("Button", "SeviathsCodexMinimapButton", Minimap)
    mm:SetSize(31, 31)
    mm:SetFrameStrata("MEDIUM")
    mm:SetFrameLevel(8)
    mm:RegisterForClicks("AnyUp")
    mm:RegisterForDrag("LeftButton")
    mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = mm:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    icon:SetVertexColor(0.6, 1, 1)
    local border = mm:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mm:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then
            ns.db.minimap.hide = true
            ns:UpdateMinimapButton()
            ns:Print("minimap button hidden — /codex minimap to bring it back")
        else
            ns:StartIndexing()
            ns:Toggle()
        end
    end)
    mm:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            ns.db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
            PlaceMinimap()
        end)
    end)
    mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mm:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(CYAN .. "Seviath's|r Codex")
        GameTooltip:AddLine("Left-click: open", 1, 1, 1)
        GameTooltip:AddLine("Right-click: hide button", 1, 1, 1)
        GameTooltip:AddLine("Drag: move", 1, 1, 1)
        GameTooltip:Show()
    end)
    mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PlaceMinimap()
    ns:UpdateMinimapButton()
end

function ns:UpdateMinimapButton()
    if mm then mm:SetShown(not ns.db.minimap.hide) end
end

-- Addon compartment (the puzzle-piece menu by the minimap)
function SeviathsCodex_OnAddonCompartmentClick()
    ns:StartIndexing()
    ns:Toggle()
end
