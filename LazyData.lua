-- Shipped monsters and gray items: read only when they are needed.
--
-- They are in their own load-on-demand addon folder (SeviathsUsefulTools_Monsters, made by tools/bake_collected.py), so the game does not
-- read them at login. The addon is loaded the first time a monster tooltip, a gray item tooltip or the farm menu needs it. A monster is
-- kept there as a short text, and only the records of the map that is shown (or of the monster that is hovered) are turned into tables.

local _, SFP = ...

local NAME = "SeviathsUsefulTools_Monsters"
local state          -- nil = not tried yet, true = loaded, false = not there
local cache = {}     -- [npcID] = decoded record (false = none), freed when the window closes

function SFP:LoadMonsterData()
    if state ~= nil then return state end
    local ok = false
    if C_AddOns and C_AddOns.LoadAddOn then
        if C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(NAME) then
            ok = true
        else
            local loaded = C_AddOns.LoadAddOn(NAME)
            ok = loaded and true or false
        end
    end
    state = ok
    return ok
end

-- the shipped tables the load-on-demand folder fills: the monsters (a text per record), the monsters of each map (ids only)
local function shipped()
    local C = _G.SeviathsUsefulToolsCollected
    local packed = C and C.packed and C.packed.SeviathsUsefulToolsDB
    local data = C and C.data and C.data.SeviathsUsefulToolsDB
    return packed and packed.npcs, data and data.npcMaps
end

-- the numbers of the monsters known on one map (shipped and your own)
function SFP:MonstersOnMap(mapID)
    local out = {}
    if self:LoadMonsterData() then
        local _, byMap = shipped()
        for _, id in ipairs((byMap and byMap[mapID]) or {}) do out[#out + 1] = id end
    end
    return out
end

-- a monster's shipped record, decoded now: a fresh table each time
function SFP:ShippedNpcRecord(id)
    if not self:LoadMonsterData() then return nil end
    local npcs = shipped()
    local text = npcs and npcs[id]
    if type(text) == "string" and SeviathsDecode then return SeviathsDecode(text) end
    return nil
end

-- a monster: the player's own record, else the shipped one (decoded when it is first asked for)
function SFP:Npc(id)
    local rec = self.db and self.db.npcs and self.db.npcs[id]
    if rec ~= nil then return rec end
    local c = cache[id]
    if c ~= nil then return c or nil end
    rec = self:ShippedNpcRecord(id)
    cache[id] = rec or false
    return rec
end

-- the ids of the shipped monsters of a map (no record is decoded)
function SFP:ShippedNpcIDs(map)
    if not self:LoadMonsterData() then return {} end
    local _, maps = shipped()
    return maps and maps[map] or {}
end

-- the maps that have shipped monsters
function SFP:ShippedNpcMaps()
    if not self:LoadMonsterData() then return {} end
    local _, maps = shipped()
    return maps or {}
end

function SFP:FreeMonsterCache()
    cache = {}
    if SFP.FreeDropCache then SFP:FreeDropCache() end
end

---------------------------------------------------------------------------
-- Transmog items (SeviathsUsefulTools_Transmog): where an item comes from, read from its block of 500 ids only when that item is looked at
---------------------------------------------------------------------------
local TNAME = "SeviathsUsefulTools_Transmog"
local tstate
local TSOURCE = {
    "Crafted", "Drop", "PvP", "Quest", "Vendor", "Trainer", "Discovery", "Redemption", "Talent", "Starter", "Event", "Achievement",
    "Black Market", "Disenchanting", "Fishing", "Gathering", "Milling", "Mining", "Prospecting", "Pickpocketing", "Salvaging", "In-game shop",
}

local TCLASS = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Death Knight", "Shaman", "Mage", "Warlock", "Monk", "Druid", "Demon Hunter", "Evoker" }
local TARMOR = { [0] = "Miscellaneous", "Cloth", "Leather", "Mail", "Plate", "Cosmetic", "Shield", "Libram", "Idol", "Totem", "Sigil", "Relic", [-6] = "Cloak" }
local TWEAPON = { [0] = "One-handed axe", "Two-handed axe", "Bow", "Gun", "One-handed mace", "Two-handed mace", "Polearm", "One-handed sword", "Two-handed sword",
    "Warglaive", "Staff", [13] = "Fist weapon", [14] = "Miscellaneous", [15] = "Dagger", [16] = "Thrown", [17] = "Spear", [18] = "Crossbow", [19] = "Wand", [20] = "Fishing pole" }
local TSLOT = { "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger", "Trinket", "One-hand", "Shield", "Ranged", "Back",
    "Two-hand", "Bag", "Tabard", "Robe", "Main hand", "Off hand", "Held in off-hand", "Ammo", "Thrown", "Ranged" }

-- one record line "id|name|quality|source|source name|item class|subclass|slot|required level|classes" as a table
local function parseTransmog(line)
    local id, name, q, src, sname, ic, isub, slot, req, cls = line:match("^(%d+)|(.-)|(%d+)|(%d+)|([^|]*)|?([^|]*)|?([^|]*)|?([^|]*)|?([^|]*)|?([^|]*)$")
    if not id then return nil end
    local classes
    if cls and cls ~= "" then
        classes = {}
        for c in cls:gmatch("%d+") do classes[#classes + 1] = TCLASS[tonumber(c)] end
    end
    ic, isub = tonumber(ic), tonumber(isub)
    local kind = (ic == 4 and TARMOR[isub]) or (ic == 2 and TWEAPON[isub]) or nil
    return {
        id = tonumber(id), name = name, quality = tonumber(q), source = TSOURCE[tonumber(src)], sourceName = sname ~= "" and sname or nil,
        type = kind, slot = TSLOT[tonumber(slot) or 0], reqLevel = tonumber(req), classes = classes,
    }
end
SFP.TransmogParseLine = parseTransmog

-- the transmog items are in several small load-on-demand folders (Data/TransmogIndex.lua says which holds which blocks of 500 ids): the folder
-- of the item looked at is loaded, not all of them
local loadedPart = {}
local function loadPart(folder)
    local s = loadedPart[folder]
    if s == nil then
        s = false
        if C_AddOns and C_AddOns.LoadAddOn then
            if C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(folder) then s = true
            else s = C_AddOns.LoadAddOn(folder) and true or false end
        end
        loadedPart[folder] = s
    end
    return s
end

local function blockText(block)
    for _, part in ipairs(SFP.TransmogParts or {}) do
        if block >= part[1] and block <= part[2] then
            if loadPart(part[3]) then
                local blocks = _G.SeviathsTransmogBlocks
                return blocks and blocks[block]
            end
            return nil
        end
    end
end

-- every folder, for the Codex section that lists all the transmog items
function SFP:TransmogBlocks()
    local any
    for _, part in ipairs(SFP.TransmogParts or {}) do
        if loadPart(part[3]) then any = true end
    end
    return any and _G.SeviathsTransmogBlocks or nil
end

-- { name, quality, source ("Drop", "Vendor" ...), source name, type, slot, required level, classes } or nil
function SFP:TransmogItem(id)
    if type(id) ~= "number" then return nil end
    local text = blockText(math.floor(id / 500))
    if not text then return nil end
    local key = id .. "|"
    local from = 1
    while true do
        local s = text:find(key, from, true)
        if not s then return nil end
        if s == 1 or text:sub(s - 1, s - 1) == "\n" then
            local e = text:find("\n", s, true) or (#text + 1)
            return parseTransmog(text:sub(s, e - 1))
        end
        from = s + 1
    end
end

---------------------------------------------------------------------------
-- Items Wowhead lists as dropped by a monster (SeviathsUsefulTools_Drops1, 2 ...): the folder of the monster looked at is loaded, the others not.
-- Data/DropIndex.lua says which folder holds which blocks of 500 monster ids. A block is "npcID|itemID,itemID,...", one line per monster.
---------------------------------------------------------------------------
local dropLoaded = {}
local dropCache = {}   -- [npcID] = list of item ids (false = none), freed with the monster cache

function SFP:WowheadDrops(npcID)
    if type(npcID) ~= "number" then return nil end
    local c = dropCache[npcID]
    if c ~= nil then return c or nil end
    local block = math.floor(npcID / 500)
    local text
    for _, part in ipairs(SFP.DropParts or {}) do
        if block >= part[1] and block <= part[2] then
            local s = dropLoaded[part[3]]
            if s == nil then
                s = false
                if C_AddOns and C_AddOns.LoadAddOn then
                    if C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(part[3]) then s = true
                    else s = C_AddOns.LoadAddOn(part[3]) and true or false end
                end
                dropLoaded[part[3]] = s
            end
            local blocks = s and _G.SeviathsDropBlocks
            text = blocks and blocks[block]
            break
        end
    end
    local list
    if text then
        local key = npcID .. "|"
        local from = 1
        while true do
            local s = text:find(key, from, true)
            if not s then break end
            if s == 1 or text:sub(s - 1, s - 1) == "\n" then
                local e = text:find("\n", s, true) or (#text + 1)
                list = {}
                local line = text:sub(s + #key, e - 1)
                local _, items = line:match("^(.-)|(.*)$")
                for id in (items or line):gmatch("%d+") do list[#list + 1] = tonumber(id) end
                break
            end
            from = s + 1
        end
    end
    dropCache[npcID] = list or false
    return list
end

function SFP:FreeDropCache() dropCache = {} end

-- the items Wowhead lists for a monster by its name (a boss page of the Codex has a name, not an id): every folder is read for it, so it is
-- for the pages that are opened one at a time
function SFP:WowheadDropsByName(name)
    if type(name) ~= "string" or name == "" then return nil end
    local want = name:lower()
    local out, seen = {}, {}
    for _, part in ipairs(SFP.DropParts or {}) do
        if not dropLoaded[part[3]] then
            dropLoaded[part[3]] = (C_AddOns and C_AddOns.LoadAddOn and C_AddOns.LoadAddOn(part[3])) and true or false
        end
    end
    for _, text in pairs(_G.SeviathsDropBlocks or {}) do
        for line in text:gmatch("[^\n]+") do
            local nm = line:match("^%d+|(.-)|")
            if nm and nm:lower() == want then
                local items = line:match("^%d+|.-|(.*)$")
                for id in (items or ""):gmatch("%d+") do
                    id = tonumber(id)
                    if not seen[id] then seen[id] = true; out[#out + 1] = id end
                end
            end
        end
    end
    return #out > 0 and out or nil
end

---------------------------------------------------------------------------
-- Items of Wowhead's lists that are not transmog (SeviathsUsefulTools_Items1, 2 ...): id, name, quality, item class and subclass, level, the list
-- (c = Classic, w = Warlords of Draenor, m = Midnight, t = other). Read only while the Codex lists items.
---------------------------------------------------------------------------
local itemLoaded = {}
-- the expansion of the list the item was found in, as the game numbers them (EXPANSION_NAME0 Classic ... 11 Midnight); xN is Wowhead's expansion N (the game's N - 1)
local ITAG = setmetatable({ c = 0, w = 5, m = 11 }, { __index = function(_, k)
    local n = type(k) == "string" and k:match("^x(%d+)$")
    return n and (tonumber(n) - 1) or nil
end })
local function loadItemPart(folder)
    local s = itemLoaded[folder]
    if s == nil then
        s = false
        if C_AddOns and C_AddOns.LoadAddOn then
            if C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(folder) then s = true
            else s = C_AddOns.LoadAddOn(folder) and true or false end
        end
        itemLoaded[folder] = s
    end
    return s
end

-- every folder; returns the table of blocks or nil
function SFP:ItemBlocks()
    local any
    for _, part in ipairs(SFP.ItemParts or {}) do
        if loadItemPart(part[3]) then any = true end
    end
    return any and _G.SeviathsItemBlocks or nil
end

-- one line "id|name|quality|class|subclass|level|required level|list" as a table
function SFP.ItemParseLine(line)
    local id, name, q, ic, isub, lvl, req, tag = line:match("^(%d+)|(.-)|(%d*)|(%-?%d*)|(%-?%d*)|(%d*)|(%d*)|(.*)$")
    if not id then return nil end
    local r = { id = tonumber(id), name = name, quality = tonumber(q), class = tonumber(ic), sub = tonumber(isub), level = tonumber(lvl),
        reqLevel = tonumber(req), exp = ITAG[tag], tag = tag }
    -- an item found at the Forever auction house: its type is asked from the game (the Codex sorts it into Type > Subtype by it)
    if tag == "f" and C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, _, _, cls, sub = pcall(C_Item.GetItemInfoInstant, r.id)
        if ok and type(cls) == "number" then r.class, r.sub = cls, sub end
    end
    return r
end

function SFP:ShippedItem(id)
    if type(id) ~= "number" then return nil end
    local blocks = self:ItemBlocks()
    local text = blocks and blocks[math.floor(id / 500)]
    if not text then return nil end
    local key = id .. "|"
    local from = 1
    while true do
        local s = text:find(key, from, true)
        if not s then return nil end
        if s == 1 or text:sub(s - 1, s - 1) == "\n" then
            local e = text:find("\n", s, true) or (#text + 1)
            return SFP.ItemParseLine(text:sub(s, e - 1))
        end
        from = s + 1
    end
end
