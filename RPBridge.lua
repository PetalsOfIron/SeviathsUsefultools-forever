-- SeviathsUsefulTools - roleplay addon bridge: reads the character profiles of Total RP 3, XRP and MyRolePlay (when one of them is installed),
-- shows them on the tooltip of other players, and can copy your own profile of that addon into the Roleplay page.
-- Every call into another addon is guarded: a different version of it can only make a field empty, never an error.

local _, SFP = ...

local Bridge = {}
SFP.RPBridge = Bridge

local function safe(f, ...)
    local ok, a, b, c = pcall(f, ...)
    if ok then return a, b, c end
end

local function text(v)
    if type(v) ~= "string" then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    v = v:gsub("{[^}]*}", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return v ~= "" and v or nil
end

-- the fields of one profile: name, title, age, height, eyes, residence, birthplace, motto, looks, traits, story, currently, ooc
local function fromTRP3(profile)
    if type(profile) ~= "table" then return nil end
    local c, a = profile.characteristics or {}, profile.about or {}
    local t3 = a.T3 or {}
    local function block(k) local t = t3[k] return type(t) == "table" and text(t.TX) or nil end
    local name = text(((c.FN or "") .. " " .. (c.LN or "")))
    return { name = name, title = text(c.TI), age = text(c.AG), height = text(c.HE), eyes = text(c.EC), residence = text(c.RE),
        birthplace = text(c.BP), looks = block("PH"), traits = block("PS"), story = block("HI"),
        currently = profile.character and text(profile.character.CU) or nil, ooc = profile.character and text(profile.character.CO) or nil }
end

local function fromFields(f)
    if type(f) ~= "table" then return nil end
    return { name = text(f.NA), title = text(f.NT), age = text(f.AG), height = text(f.AH), eyes = text(f.AE), residence = text(f.HH),
        birthplace = text(f.HB), motto = text(f.MO), looks = text(f.DE), traits = text(f.PE), story = text(f.HI),
        currently = text(f.CU), ooc = text(f.CO) }
end

function Bridge.Which()
    if _G.TRP3_API then return "Total RP 3" end
    if _G.xrp then return "XRP" end
    if _G.msp and _G.mrp then return "MyRolePlay" end
    if _G.msp then return "an MSP addon" end
end

-- the profile of a unit ("target", "mouseover" ...) from the installed roleplay addon, or nil
function Bridge.ProfileOf(unit)
    if type(unit) ~= "string" then return nil end
    local trp = _G.TRP3_API
    if trp and trp.register and trp.utils and trp.utils.str then
        local id = safe(trp.utils.str.getUnitID, unit)
        if id and trp.register.isUnitIDKnown and safe(trp.register.isUnitIDKnown, id) then
            local p = safe(trp.register.getUnitIDCurrentProfile, id)
            local r = fromTRP3(p)
            if r then return r end
        end
    end
    local xrp = _G.xrp
    if xrp and xrp.characters and xrp.characters.byUnit then
        local ch = safe(xrp.characters.byUnit, unit)
        if type(ch) == "table" and ch.fields then return fromFields(ch.fields) end
    end
    local msp = _G.msp
    if msp and msp.char then
        local name, realm = UnitName(unit)
        if name then
            local key = (realm and realm ~= "") and (name .. "-" .. realm) or name
            local rec = msp.char[key] or msp.char[name]
            if type(rec) == "table" and rec.field then return fromFields(rec.field) end
            if msp.Request then safe(msp.Request, msp, key) end   -- asked once: the answer is there on a later hover
        end
    end
end

-- your own profile of the roleplay addon, to copy into the Roleplay page
function Bridge.MyProfile()
    local trp = _G.TRP3_API
    if trp and trp.profile and trp.profile.getData then
        local c, a = safe(trp.profile.getData, "player/characteristics"), safe(trp.profile.getData, "player/about")
        local r = fromTRP3({ characteristics = c, about = a })
        if r then return r end
    end
    local xrp = _G.xrp
    if xrp and xrp.profile and xrp.profile.fields then return fromFields(xrp.profile.fields) end
    local msp = _G.msp
    if msp and msp.my and msp.my.field then return fromFields(msp.my.field) end
end

-- the lines on the tooltip of another player
local function addLines(tt, unit)
    local r = Bridge.ProfileOf(unit)
    if not r then return end
    local CY = "|c" .. (SFP.CYAN_HEX or "ffffd100")
    local any = false
    local function line(label, v, max)
        if v then tt:AddLine(CY .. label .. ":|r " .. v:sub(1, max or 80), 0.8, 0.8, 0.8, true); any = true end
    end
    if r.name then tt:AddLine(CY .. r.name .. "|r"); any = true end
    if r.title then tt:AddLine(r.title, 1, 1, 1); any = true end
    line("Age", r.age, 40); line("Height", r.height, 60); line("Residence", r.residence, 80)
    line("Personality", r.traits, 120); line("Backstory", r.story, 240); line("Currently", r.currently, 120)
    if any then tt:Show() end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tt)
        if tt ~= GameTooltip then return end
        local okU, _, unit = pcall(tt.GetUnit, tt)
        if not okU or not unit or (issecretvalue and issecretvalue(unit)) then return end
        local okP, isPlayer = pcall(UnitIsPlayer, unit)
        if not okP or not isPlayer or (issecretvalue and issecretvalue(isPlayer)) then return end
        local okS, isMe = pcall(UnitIsUnit, unit, "player")
        if okS and isMe then return end   -- yourself: the Roleplay page of this addon
        if not Bridge.Which() then return end
        pcall(addLines, tt, unit)
    end)
end

---------------------------------------------------------------------------
-- A small public API, so other addons (tooltip addons, roleplay addons, WeakAuras) can read what this addon knows about a player:
--   SeviathsUsefulTools_API.GetPlayer("Name-Realm")  ->  { level, class, race, guild, zone, faction, seen } or nil   (from the Who and nameplate scans)
--   SeviathsUsefulTools_API.GetMyProfile()           ->  your profile of the Roleplay page: title, age, height, looks, personality, story ...
--   SeviathsUsefulTools_API.GetPrice(itemID)         ->  the auction price in copper of your server kind, or nil
-- Other addons cannot be made to show our data: each tooltip addon (Raider.IO and the like) reads only its own files. The API is the part we can offer.
---------------------------------------------------------------------------
local API = {}
_G.SeviathsUsefulTools_API = API

function API.GetPlayer(key)
    local info = SFP.db and SFP.db.seenInfo
    local r = type(key) == "string" and info and info[key]
    if type(r) ~= "table" then return nil end
    return { level = r.lvl, class = r.class, race = r.race, guild = r.guild, zone = r.zone, faction = r.faction, seen = r.t }
end

function API.GetMyProfile()
    local n = UnitName("player") or "?"
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    local chars = SFP.db and SFP.db.rp and SFP.db.rp.chars
    local r = chars and (chars[n .. "-" .. realm] or chars[n])
    if type(r) ~= "table" then return nil end
    local out = {}
    for k, v in pairs(r) do if k ~= "notes" then out[k] = v end end   -- the private notes are never given out
    return out
end

function API.GetPrice(itemID)
    return SFP.GetPrice and SFP:GetPrice(itemID) or nil
end

---------------------------------------------------------------------------
-- The MSP exchange (the language Total RP 3, MyRolePlay and XRP speak over addon messages): this addon answers "?FIELD" requests with the card written on
-- the Roleplay page, and asks the same of other players when you hover them, so players of those addons see your card and you see theirs even without one of
-- these addons yourself. Only when no addon of that family is installed (an installed one does the talking itself, and this would answer twice).
---------------------------------------------------------------------------
local MSP_FIELDS = { NA = "name", NT = "title", AG = "age", AH = "height", AE = "eyes", HH = "residence", HB = "birthplace", MO = "motto",
    DE = "looks", PE = "traits", HI = "story", CU = "currently", CO = "ooc" }
local theirs = {}   -- [sender] = { fields, t }

local function mspActive()
    return not (_G.msp or _G.TRP3_API or _G.xrp)
end

local function myCard()
    local p = API.GetMyProfile() or {}
    local n, s = UnitName("player")
    p.name = (type(s) == "string" and s ~= "" and not s:find("Realm") and not s:find("CAMWOW")) and (n .. " " .. s) or n
    return p
end

local function clean(v) return (tostring(v or ""):gsub("[\t\n]", " ")) end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.SendAddonMessage then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, "MSP")
    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
        if prefix ~= "MSP" or type(text) ~= "string" or (issecretvalue and (issecretvalue(text) or issecretvalue(sender))) then return end
        if not mspActive() then return end
        if text:find("^%?") or text:find("\t%?") then
            -- a request: ?NA\t?DE ...  -> our answer: NA=...\tDE=...
            local out = { "VP=1", "VA=SeviathsUsefulTools/" .. tostring(SFP.VERSION) }
            local card = myCard()
            for fld in text:gmatch("%?(%u%u)") do
                local key = MSP_FIELDS[fld]
                if key and card[key] and card[key] ~= "" then out[#out + 1] = fld .. "=" .. clean(card[key]) end
            end
            if #out > 2 then if SFP.NoteAskedName then SFP.NoteAskedName(sender) end pcall(C_ChatInfo.SendAddonMessage, "MSP", table.concat(out, "\t"), "WHISPER", sender) end
        else
            -- an answer from someone: FIELD=value pairs
            local rec = theirs[sender] or { fields = {} }
            for fld, val in text:gmatch("(%u%u)=([^\t]*)") do rec.fields[fld] = val end
            rec.t = GetTime()
            theirs[sender] = rec
        end
    end)
    -- ask a player we hover (once a minute) for the card
    local asked = {}
    local hov = CreateFrame("Frame")
    hov:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    hov:SetScript("OnEvent", function()
        if not mspActive() or not UnitExists("mouseover") then return end
        local okP, isP = pcall(UnitIsPlayer, "mouseover")
        if not okP or not isP or (issecretvalue and issecretvalue(isP)) or UnitIsUnit("mouseover", "player") then return end
        local name, realm = UnitName("mouseover")
        if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then return end
        local key = (type(realm) == "string" and realm ~= "") and (name .. "-" .. realm) or name
        if asked[key] and GetTime() - asked[key] < 60 then return end
        asked[key] = GetTime()
        if SFP.NoteAskedName then SFP.NoteAskedName(key) end
        pcall(C_ChatInfo.SendAddonMessage, "MSP", "?NA\t?NT\t?AG\t?AH\t?HH\t?DE\t?PE\t?HI\t?CU", "WHISPER", key)
    end)
    -- the answers are shown on the tooltip like those of an installed roleplay addon
    local prev = Bridge.ProfileOf
    function Bridge.ProfileOf(unit)
        local r = prev(unit)
        if r then return r end
        local name, realm = UnitName(unit)
        if type(name) ~= "string" then return nil end
        for sender, rec in pairs(theirs) do
            if sender == name or sender:match("^([^-]+)") == name then return fromFields(rec.fields) end
        end
    end
    local oldWhich = Bridge.Which
    function Bridge.Which() return oldWhich() or (next(theirs) and "MSP") or nil end
end

---------------------------------------------------------------------------
-- Other tooltip addons that keep data about players: what they know is read here and shown in our own player tooltip, so one tooltip tells it all.
-- Raider.IO (RaiderIO.GetProfile): the mythic+ score. Every call is guarded: a different version only leaves the line out.
---------------------------------------------------------------------------
local function raiderIOLines(tt, unit)
    local rio = _G.RaiderIO
    if type(rio) ~= "table" or type(rio.GetProfile) ~= "function" then return end
    local okp, prof = pcall(rio.GetProfile, unit)
    if not okp or type(prof) ~= "table" then return end
    local m = prof.mythicKeystoneProfile
    if type(m) ~= "table" then return end
    local score, main = tonumber(m.currentScore) or 0, tonumber(m.mainCurrentScore) or 0
    if score <= 0 and main <= 0 then return end
    local txt = "|c" .. (SFP.CYAN_HEX or "ffffd100") .. "Raider.IO:|r " .. math.floor(score)
    if main > score then txt = txt .. "  |cff808080(main " .. math.floor(main) .. ")|r" end
    tt:AddLine(txt, 1, 1, 1)
    tt:Show()
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tt)
        if tt ~= GameTooltip then return end
        local okU, _, unit = pcall(tt.GetUnit, tt)
        if not okU or not unit or (issecretvalue and issecretvalue(unit)) then return end
        local okP, isPlayer = pcall(UnitIsPlayer, unit)
        if not okP or not isPlayer or (issecretvalue and issecretvalue(isPlayer)) then return end
        pcall(raiderIOLines, tt, unit)
    end)
end
