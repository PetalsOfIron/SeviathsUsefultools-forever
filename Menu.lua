-- SeviathsUsefulTools - main menu
-- One window for everything. Left and right click on the minimap button open it, so does /sut.
-- Sections: Home, Farm & Map, Guides (Codex), Groups, Guild, Learned data, Settings.

local ADDON, SFP = ...
local CY = SFP.CYAN
local CYHEX = "|c" .. SFP.CYAN_HEX

local frame
local navButtons, panes, current = {}, {}, nil

local SECTIONS = {
    { key = "groups",   label = "Find Groups" },
    { key = "home",     label = "Home" },
    { key = "farm",     label = "Farm & Map" },
    { key = "alerts",   label = "Rare Alerts" },
    { key = "killed",   label = "Killed Today" },
    { key = "route",    label = "Farm Route" },
    { key = "session",  label = "Farm Session" },
    { key = "next",     label = "What To Farm Next" },
    { key = "weekly",   label = "Weekly Checklist" },
    { key = "deals",    label = "BoE Deals" },
    { key = "shop",     label = "Recipe Planner" },
    { key = "gems",     label = "Gem & Enchant Helper" },
    { key = "collect",  label = "My Collections" },
    { key = "share",    label = "Share Data" },
    { key = "delve",    label = "Delve Planner" },
    { key = "keys",     label = "Delve Keys" },
    { key = "ach",      label = "Achievement Planner" },
    { key = "zone",     label = "Zone Check" },
    { key = "decor",    label = "Housing Decor" },
    { key = "alts",     label = "Alt Overview" },
    { key = "guides",   label = "Guides (Codex)" },
    { key = "social",   label = "Players & Party" },
    { key = "guild",    label = "Guild" },
    { key = "know",     label = "Learned data" },
    { key = "guilds",   label = "Guild Directory" },
    { key = "settings", label = "Settings" },
}

-- "Guild Directory" and "Settings" stay the last two entries, whatever is added to the list above later
do
    local tail, head = {}, {}
    for _, e in ipairs(SECTIONS) do
        if e.key == "guilds" or e.key == "settings" then tail[#tail + 1] = e else head[#head + 1] = e end
    end
    table.sort(tail, function(a, b) return a.key == "guilds" and b.key == "settings" end)
    for i = #SECTIONS, 1, -1 do SECTIONS[i] = nil end
    for _, e in ipairs(head) do SECTIONS[#SECTIONS + 1] = e end
    for _, e in ipairs(tail) do SECTIONS[#SECTIONS + 1] = e end
end

local function backdrop(f, r, g, b, a, br, bg_, bb, ba)
    SFP.BlizzardFrame(f)
    f:SetBackdropColor(r, g, b, a)
    f:SetBackdropBorderColor(br, bg_, bb, ba)
end

local function mkButton(parent, text, w, fn, tip)
    -- the game's own red panel button (the look of the Hunter search / Waypoint buttons)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b.text = b:GetFontString()
    b:SetScript("OnClick", function(self) fn(self) end)
    b:SetScript("OnEnter", function(self)
        if tip then
            SFP.Tip():SetOwner(self, "ANCHOR_RIGHT")
            SFP.Tip():AddLine(tip, 1, 1, 1, true)
            SFP.Tip():Show()
        end
    end)
    b:SetScript("OnLeave", function() SFP.Tip():Hide() end)
    return b
end

local function mkText(parent, text, x, y, w, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    if w then fs:SetWidth(w) end
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function mkCheck(parent, label, getter, setter, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    local t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    t:SetText(label)
    cb:SetHitRectInsets(0, -(t:GetStringWidth() + 6), 0, 0)   -- the label can be clicked too
    cb:SetScript("OnClick", function(self) setter(self:GetChecked() and true or false) end)
    cb.refresh = function() cb:SetChecked(getter() and true or false) end
    cb.text, cb.labelText = t, label
    return cb
end

local function codex() return _G.SeviathsCodex end

---------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------
local function countKeys(t) local n = 0 for _ in SeviathsAllPairs(t or {}) do n = n + 1 end return n end

local function buildHome(pane)
    mkText(pane, CYHEX .. "SeviathsUsefulTools|r", 12, -10, 480, "GameFontNormalLarge")
    mkText(pane, "Everything in one place. Pick a section on the left:", 12, -36, 500)
    local list = {
        { "Farm & Map", "farm", "Glowing farm spots, rares and gathering routes on the world map, prices, layers." },
        { "Guides (Codex)", "guides", "How to do things: dungeons, raids, bosses, quests, mounts, pets, entrances, materials, gold." },
        { "Find Groups", "groups", "Raid buffs, tier tokens, player tags and notes for dungeons and raids." },
        { "Guild", "guild", "Find and invite players for your guild, charter signatures." },
        { "Learned data", "know", "Every monster, item, node and recipe the addon has learned from your play." },
        { "Settings", "settings", "Switches for the map, tooltips and learning." },
    }
    for i, e in ipairs(list) do
        local y = -64 - (i - 1) * 44
        mkButton(pane, e[1], 130, function() SFP:ShowMenuSection(e[2]) end):SetPoint("TOPLEFT", 12, y)
        mkText(pane, e[3], 152, y - 2, 360, "GameFontHighlightSmall"):SetTextColor(0.8, 0.8, 0.8)
    end
    pane.stats = mkText(pane, "", 12, -420, 500, "GameFontHighlightSmall")
    pane.refresh = function()
        local db = SFP.db
        pane.stats:SetText(("|cff808080Learned so far: %d monsters, %d items, %d gathering nodes, %d recipes. Saved for all your characters.|r")
            :format(countKeys(db.npcs), countKeys(db.knownItems), countKeys(db.objects), countKeys(db.recipes)))
    end
end

local function buildFarm(pane)
    mkText(pane, CYHEX .. "Farm & Map|r", 12, -10, 480, "GameFontNormalLarge")
    mkText(pane, "Farm spots, rares, hunter tames and best gathering zones on the world map.", 12, -34, 500, "GameFontHighlightSmall")
    mkButton(pane, "Farm browser", 130, function() SFP:ToggleBrowser() end, "Expansions, zones, items with auction prices, coordinates"):SetPoint("TOPLEFT", 12, -58)
    mkButton(pane, "Open world map", 130, function() SFP:OpenMapTo(C_Map.GetBestMapForUnit("player") or 1) end):SetPoint("TOPLEFT", 150, -58)
    mkButton(pane, "Scan auction prices", 150, function() SFP:StartScan(true) end, "The auction house must be open"):SetPoint("TOPLEFT", 288, -58)
    mkText(pane, "Layers on the world map:", 12, -92, 400)
    local checks = {
        { "mapOverlay", "Show farm layer" }, { "showSpawns", "Monster farm spots" }, { "showRares", "Rares (mounts, pets)" },
        { "showHunter", "Hunter tames" }, { "showMining", "Mining zones" }, { "showHerbs", "Herb zones" },
        { "showDungeons", "Dungeon entrances" }, { "showRaids", "Raid entrances" }, { "showSpecial", "Special materials" },
        { "showGatherList", "Gathering list" }, { "showSpotList", "Farm spot list (switch single spots off)" }, { "showLabels", "Names on the map" }, { "learn", "Learn farm spots from my loot" },
        { "exactSpots", "Exact spot markers (special / hunter)" }, { "continentSpots", "Also on continent maps (crowded)" }, { "minimapSpots", "Also show spots on the minimap" },
    }
    pane.checks = {}
    for i, c in ipairs(checks) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local cb = mkCheck(pane, c[2], function() return SFP.db[c[1]] end, function(v) SFP.db[c[1]] = v; SFP:RefreshAll() end,
            12 + col * 250, -116 - row * 26)
        pane.checks[#pane.checks + 1] = cb
    end
    pane.refresh = function() for _, cb in ipairs(pane.checks) do cb.refresh() end end
end

-- a simple page: title, a short explanation, then whatever the page adds
local function pageHead(pane, title, desc)
    mkText(pane, CYHEX .. title .. "|r", 12, -10, 480, "GameFontNormalLarge")
    local fs = mkText(pane, desc, 12, -38, 700, "GameFontHighlightSmall")
    fs:SetTextColor(0.85, 0.85, 0.85)
    fs:SetSpacing(2)
    return -38 - math.max(30, fs:GetStringHeight() or 30) - 14
end

local function simplePage(title, desc, fill)
    return function(pane)
        local y = pageHead(pane, title, desc)
        local refresh = fill(pane, y) or function() end
        pane.refresh = function() refresh() end
        -- live: the page redraws itself every couple of seconds while it is shown
        local acc = 0
        pane:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc < 2 then return end
            acc = 0
            SFP:Safe("page update", pane.refresh)
        end)
    end
end

local buildAlerts = simplePage("Rare Alerts",
    "When a rare you still miss a mount, pet or toy from shows up near you, the addon plays a sound and prints a chat line with a clickable [set waypoint]. " ..
    "It uses the game's map markers for rares. It only alerts for rares you do not own everything from and have not killed today. " ..
    "The switches for this are on the Settings page.",
    function(pane, y)
        mkButton(pane, "Open Settings", 150, function() SFP:ShowMenuSection("settings") end):SetPoint("TOPLEFT", 12, y)
    end)

local buildKilled = simplePage("Killed Today",
    "The rares and bosses you killed this week (since the weekly reset) that gave loot, per character. Normal monsters are not listed. Rares are greyed out on the map and marked [killed today] until the weekly reset. " ..
    "The switch for this is on the Settings page.",
    function(pane, y)
        mkButton(pane, "Open Settings", 150, function() SFP:ShowMenuSection("settings") end):SetPoint("TOPLEFT", 12, y)

        local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, y - 34)
        scroll:SetPoint("BOTTOMRIGHT", -30, 10)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(480, 10)
        scroll:SetScrollChild(child)
        local txt = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("TOPLEFT")
        txt:SetWidth(470)
        txt:SetJustifyH("LEFT")
        txt:SetSpacing(3)
        return function()
            local list = SFP:KilledTodayList()
            local lines, last = {}, nil
            for _, k in ipairs(list) do
                if k.char ~= last then
                    lines[#lines + 1] = (#lines > 0 and "\n" or "") .. "|cffffd100" .. k.char .. "|r"
                    last = k.char
                end
                lines[#lines + 1] = ("  %s%s  |cff808080%s  -  %s|r"):format(k.name, k.rare and "  |cffff9933[rare]|r" or "", k.zone, date("%H:%M", k.t))
            end
            if #lines == 0 then lines[1] = "No rare killed this week yet (only rares and bosses are listed)." end
            txt:SetText(table.concat(lines, "\n"))
            child:SetHeight(txt:GetStringHeight() + 10)
        end
    end)

local buildRoute = simplePage("Farm Route",
    "The addon detects the zone you are in and lists its farm spots. Tick the ones you want, then Build route: they are ordered into a short loop starting next to you, " ..
    "drawn as a yellow line on the map, and a waypoint is set to the first stop. To plan another zone, pick it in the list at the bottom. The switch to show or hide the line is on the Settings page.",
    function(pane, y)
        local state = { map = nil, sel = {}, spots = {} }
        local zoneText = mkText(pane, "", 12, y, 360, "GameFontNormal")
        local spotRows = {}
        local spotScroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
        spotScroll:SetPoint("TOPLEFT", 12, y - 26)
        spotScroll:SetSize(470, 150)
        local spotChild = CreateFrame("Frame", nil, spotScroll)
        spotChild:SetSize(460, 10)
        spotScroll:SetScrollChild(spotChild)

        local function fillSpots()
            local n = 0
            for _, sp in ipairs(state.spots) do
                n = n + 1
                local r = spotRows[n]
                if not r then
                    r = CreateFrame("CheckButton", nil, spotChild, "UICheckButtonTemplate")
                    r:SetSize(22, 22)
                    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    r.label:SetPoint("LEFT", r, "RIGHT", 2, 0)
                    r:SetScript("OnClick", function(self) state.sel[self.key] = self:GetChecked() and true or nil end)
                    spotRows[n] = r
                end
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", spotChild, "TOPLEFT", 0, -(n - 1) * 22)
                r.key = SFP.SpotKey(sp)
                r:SetChecked(state.sel[r.key] and true or false)
                local kind = sp.gather and (sp.gather == "ore" and "mining" or "herbs") or (sp.rare and "rare") or (sp.hunter and "hunter tame") or (sp.special and "special") or "monsters"
                r.label:SetText(("%s  |cff808080%s|r"):format(sp.name or "?", kind))
                r:Show()
            end
            for i = n + 1, #spotRows do spotRows[i]:Hide() end
            spotChild:SetHeight(n * 22 + 6)
        end

        local function setZone(mapID)
            local zone = mapID and SFP.zoneByMap and SFP.zoneByMap[mapID]
            state.map, state.spots, state.sel = mapID, {}, {}
            if zone then
                for _, sp in ipairs(zone.spawns or {}) do
                    if sp.hx and sp.hy then state.spots[#state.spots + 1] = sp; state.sel[SFP.SpotKey(sp)] = true end
                end
                table.sort(state.spots, function(a, b) return tostring(a.name) < tostring(b.name) end)
            end
            zoneText:SetText(zone and ("Zone: " .. SFP:ZoneName(mapID) .. "  |cff808080(" .. #state.spots .. " farm spots)|r") or "No farm spots found here - pick a zone below.")
            fillSpots()
        end

        mkButton(pane, "Use the zone I am in", 160, function() setZone(SFP:PlayerFarmZone()) end):SetPoint("TOPLEFT", 330, y + 4)
        mkButton(pane, "Open farm routes", 150, function() SFP:ShowRouteWindow() end, "A bigger window with every spot of a zone and every zone."):SetPoint("TOPLEFT", 330, y - 22)
        local by = y - 184
        mkButton(pane, "Select all", 90, function()
            for _, sp in ipairs(state.spots) do state.sel[SFP.SpotKey(sp)] = true end
            fillSpots()
        end):SetPoint("TOPLEFT", 12, by)
        mkButton(pane, "Select none", 90, function() wipe(state.sel); fillSpots() end):SetPoint("TOPLEFT", 108, by)
        mkButton(pane, "Build route", 120, function()
            if not state.map then return end
            if SFP.OpenMapTo then SFP:OpenMapTo(state.map) end
            SFP:BuildRoute(state.map, state.sel)
        end, "Orders the ticked spots into a loop, draws it on the map and sets a waypoint to the first stop."):SetPoint("TOPLEFT", 204, by)
        mkButton(pane, "Clear route", 100, function() SFP:ClearRoute() end):SetPoint("TOPLEFT", 330, by)

        mkText(pane, "Another zone:", 12, by - 34, 110, "GameFontHighlightSmall")
        local filter = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
        filter:SetSize(200, 22)
        filter:SetPoint("TOPLEFT", 100, by - 30)
        filter:SetAutoFocus(false)
        filter:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local zScroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
        zScroll:SetPoint("TOPLEFT", 12, by - 58)
        zScroll:SetPoint("BOTTOMRIGHT", -30, 8)
        local zChild = CreateFrame("Frame", nil, zScroll)
        zChild:SetSize(460, 10)
        zScroll:SetScrollChild(zChild)
        local zRows = {}
        local function fillZones()
            local text = (filter:GetText() or ""):lower()
            local n = 0
            for _, z in ipairs(SFP:RouteZones()) do
                if text == "" or z.name:lower():find(text, 1, true) or z.exp:lower():find(text, 1, true) then
                    n = n + 1
                    local b = zRows[n]
                    if not b then
                        b = mkButton(zChild, "", 450, function(self) if self.zone then setZone(self.zone.map) end end)
                        b.text:ClearAllPoints()
                        b.text:SetPoint("LEFT", 8, 0)
                        zRows[n] = b
                    end
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", zChild, "TOPLEFT", 0, -(n - 1) * 24)
                    b.zone = z
                    b.text:SetText(("%s  |cff808080%s  -  %d spots|r"):format(z.name, z.exp, z.count))
                    b:Show()
                end
            end
            for i = n + 1, #zRows do zRows[i]:Hide() end
            zChild:SetHeight(n * 24 + 6)
        end
        filter:SetScript("OnTextChanged", fillZones)
        fillZones()

        return function()
            -- each time the page opens: detect the zone you are in (unless you already picked one)
            if not state.map then setZone(SFP:PlayerFarmZone()) end
        end
    end)

local buildSession = simplePage("Farm Session",
    "Start a session before you farm: it counts your kills, the gold you loot and what the loot is worth at auction prices, and shows the total and the gold per hour in a small window you can move. Stop it when you are done: the result is printed in chat.",
    function(pane, y)
        local state = mkText(pane, "", 12, y - 4, 500, "GameFontNormal")
        mkButton(pane, "Start session", 130, function() SFP:SessionStart(); pane.refresh() end):SetPoint("TOPLEFT", 12, y - 26)
        mkButton(pane, "Stop session", 130, function() SFP:SessionStop(); pane.refresh() end):SetPoint("TOPLEFT", 150, y - 26)
        mkButton(pane, "Show / hide window", 160, function() SFP:SessionToggle("window") end):SetPoint("TOPLEFT", 288, y - 26)
        mkButton(pane, "Open farm session window", 210, function() SFP:ShowSessionControl() end,
            "A small window you can move anywhere with Play, Stop and Show/Hide buttons."):SetPoint("TOPLEFT", 12, y - 52)
        local txt = mkText(pane, "", 12, y - 86, 500, "GameFontHighlightSmall")
        local cmds = mkText(pane, "Commands:\n/sfp session  -  start a session (or show the window)\n/sfp session stop  -  stop it and print the result\n" ..
            "/sfp session hide  -  hide the window     /sfp session show  -  show it again", 12, y - 170, 500, "GameFontHighlightSmall")
        cmds:SetTextColor(0.7, 0.7, 0.7)
        return function()
            local s = SFP.session
            state:SetText(not s and "No session running" or (s.stop and "Session stopped" or "|cff40ff40Session running|r"))
            txt:SetText(SFP.SessionSummary and SFP:SessionSummary() or "")
        end
    end)

local buildNext = simplePage("What To Farm Next",
    "Rares that still drop a mount, pet or toy you do not own. Best first (most and most wanted missing items; mounts count most) or nearest first, killed today come last. Press Waypoint on the one you want, or open the full list to pick rares by zone and build a route. It needs your collections to be read (see My Collections).",
    function(pane, y)
        local rows = {}
        for i = 1, 9 do
            local btn = mkButton(pane, "Waypoint", 80, function() end)
            btn:SetPoint("TOPLEFT", 12, y - 28 - (i - 1) * 36)
            local fs = mkText(pane, "", 100, y - 30 - (i - 1) * 36, 410, "GameFontHighlightSmall")
            rows[i] = { btn = btn, fs = fs }
        end
        local head = mkText(pane, "", 12, y, 200, "GameFontNormal")
        mkButton(pane, "Full list by zone", 140, function() SFP:ShowNextWindow() end):SetPoint("TOPLEFT", 368, y + 4)
        local sortBtn = mkButton(pane, "", 146, function() SFP.db.nextSort = (SFP.db.nextSort or "best") == "best" and "near" or "best"; pane.refresh() end)
        sortBtn:SetPoint("TOPLEFT", 216, y + 4)
        local retry
        local function fill()
            local top, total = SFP:FarmNext(9)
            sortBtn.text:SetText((SFP.db.nextSort or "best") == "best" and "Sorted: best first" or "Sorted: nearest first")
            head:SetText(total > 0 and (total .. " rares have something you miss") or "Nothing to suggest (or your collections are not read yet)")
            for i, r in ipairs(rows) do
                local c = top[i]
                if c then
                    local names = {}
                    for _, id in ipairs(c.missing) do names[#names + 1] = SFP:ItemName(id) end
                    local where = c.sp.hx and ("%.1f, %.1f"):format(c.sp.hx * 100, c.sp.hy * 100) or ""
                    r.fs:SetText(("|cffffd100%s|r  %s %s%s\nmissing: %s"):format(c.sp.name, SFP:ZoneName(c.map), where,
                        c.killed and "  |cff808080killed today|r" or "", table.concat(names, ", ")))
                    r.btn:SetScript("OnClick", function()
                        if c.sp.hx then SFP:SetWaypoint(c.map, c.sp.hx, c.sp.hy, c.sp.name) end
                    end)
                    r.btn:Show(); r.fs:Show()
                else
                    r.btn:Hide(); r.fs:Hide()
                end
            end
        end
        return function() fill() end
    end)

local buildWeekly = simplePage("Weekly Checklist",
    "One window for all your characters: Great Vault progress, raid lockouts and the rares each one killed today. A character appears after you log in with it.",
    function(pane, y)
        mkButton(pane, "Open weekly checklist", 190, function() SFP:ShowWeekly() end):SetPoint("TOPLEFT", 12, y)
    end)

local buildDeals = simplePage("BoE Deals",
    "Bind-on-equip items that are cheaper than usual right now. The addon remembers every auction house scan, so the list gets better after a few scans on different days. " ..
    "The same list opens from the BoE deals button below the auction house window.",
    function(pane, y)
        mkButton(pane, "Open BoE deals", 170, function() SFP:ShowDeals() end):SetPoint("TOPLEFT", 12, y)
    end)

local buildShop = simplePage("Recipe Planner",
    "Pick the recipes you want to craft: you get the total reagents, their auction prices, the profit and, for each reagent, a place to farm it. " ..
    "To decide farm or buy, compare with your gold per hour from a Farm Session.",
    function(pane, y)
        mkButton(pane, "Open recipe planner", 170, function() SFP:ShowShop() end):SetPoint("TOPLEFT", 12, y)
    end)

local buildCollect = simplePage("My Collections",
    "The game remembers your transmog, mounts and battle pets, also from before this addon was installed. The addon reads them by itself in the background: on the first start after the install, and again when the number of mounts or pets changes, so you never have to press anything. Monster tooltips and the Codex " ..
    "(tab My Collection History) can say what you already own from a monster, and so What To Farm Next knows what you miss.",
    function(pane, y)
        local txt = mkText(pane, "", 12, y - 30, 500, "GameFontHighlightSmall")
        local function status()
            local h = SFP.db.history
            if not h or not h.t or h.t == 0 then return "Not read yet - it starts by itself about 20 seconds after you log in." end
            local items, mons, mnt, pets = 0, 0, 0, 0
            for _ in pairs(h.items or {}) do items = items + 1 end
            for _, r in pairs(h.by or {}) do
                mons = mons + 1
                mnt = mnt + (r.mounts and #r.mounts or 0)
                pets = pets + (r.pets and #r.pets or 0)
            end
            local mins = math.floor((time() - h.t) / 60)
            return ("Last read %s: %d transmog items, %d mounts and %d pets from %d monsters and bosses."):format(
                mins < 1 and "just now" or (mins < 120 and (mins .. " min ago") or (math.floor(mins / 60) .. " h ago")), items, mnt, pets, mons)
        end
        mkButton(pane, "Read my collections", 190, function()
            SFP.db.historyReport = true
            SFP:Print("Reading your transmog, mount and pet collections (in the background)...")
            SFP:ScanTransmogHistory(true)
            C_Timer.After(1, function() txt:SetText(status()) end)
        end):SetPoint("TOPLEFT", 12, y)
        -- the planner: pick the mounts, pets and toys you want to farm
        mkText(pane, CYHEX .. "Your collection plan|r", 12, y - 62, 400, "GameFontNormal")
        local plan = SFP.MakeRowList(pane, 8, y - 80, 500, 110, 22)
        local planInfo = mkText(pane, "", 12, y - 194, 480, "GameFontHighlightSmall")
        mkText(pane, "Pick from every mount, battle pet and toy in the game (search by name or source, or use the buttons); tick to plan, untick to remove:", 12, y - 212, 500, "GameFontHighlightSmall")
        local box = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
        box:SetSize(260, 20)
        box:SetPoint("TOPLEFT", 16, y - 230)
        box:SetAutoFocus(false)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local results = SFP.MakeRowList(pane, 8, y - 254, 500, 150, 22)
        -- the list holds every mount, battle pet and toy of the game, not only yours: narrow it down here
        local kindF, missOnly = "all", false
        local KINDS = { all = "All", mount = "Mounts", pet = "Pets", toy = "Toys" }
        local KIND_NEXT = { all = "mount", mount = "pet", pet = "toy", toy = "all" }
        local kindBtn, missBtn
        kindBtn = mkButton(pane, "Show: All", 100, function()
            kindF = KIND_NEXT[kindF]
            kindBtn:SetText("Show: " .. KINDS[kindF])
            SFP.CollPlanChanged()
        end)
        kindBtn:SetPoint("TOPLEFT", 286, y - 229)
        missBtn = mkButton(pane, "Missing only: off", 120, function()
            missOnly = not missOnly
            missBtn:SetText("Missing only: " .. (missOnly and "on" or "off"))
            SFP.CollPlanChanged()
        end)
        missBtn:SetPoint("TOPLEFT", 390, y - 229)
        local function planData()
            SFP.db.collPlan = SFP.db.collPlan or {}
            return SFP.db.collPlan
        end
        local function planIndex(e)
            for i, p in ipairs(planData()) do if p.key == e.key then return i end end
        end
        local function ownedText(e)
            local own = SFP:CollOwned(e)
            if own == nil then return "|cff808080owned?|r" end
            return own and "|cff40ff40owned|r" or "|cffff6060missing|r"
        end
        local function line(e, n)
            local src = e.source and e.source ~= "" and ("  |cff808080" .. e.source:sub(1, n) .. "|r") or ""
            return ("%s [%s] %s%s"):format(SFP:CollEntryName(e), e.kind, "", src)
        end
        local fillPlan, fillResults
        fillPlan = function()
            local entries = SFP:CollectEntries()
            local byKey = {}
            for _, e in ipairs(entries or {}) do byKey[e.key] = e end
            local items, have = {}, 0
            for i, p in ipairs(planData()) do
                local e = byKey[p.key]
                if e then
                    if SFP:CollOwned(e) then have = have + 1 end
                    items[#items + 1] = {
                        text = ownedText(e) .. " " .. line(e, 80),
                        check = true,
                        onToggle = function(on) if not on then table.remove(planData(), i); fillPlan(); fillResults() end end,
                        buttons = SFP:CollTarget(e) and { { "Waypoint", 70, function() SFP:CollWaypoint(e) end } } or {},
                    }
                else
                    items[#items + 1] = {
                        text = "|cff808080" .. (p.name or p.key) .. "|r",
                        check = true,
                        onToggle = function(on) if not on then table.remove(planData(), i); fillPlan(); fillResults() end end,
                    }
                end
            end
            plan:Set(items)
            planInfo:SetText(#items == 0 and "|cff808080Nothing planned yet. Search below and tick what you want.|r"
                or ("|cff808080" .. #items .. " planned, " .. have .. " owned. A Waypoint button shows when the rare's spawn spots are known.|r"))
        end
        fillResults = function()
            local q = (box:GetText() or ""):lower()
            local items = {}
            if #q >= 2 or kindF ~= "all" or missOnly then
                local entries = SFP:CollectEntries()
                if not entries then
                    items[1] = { text = "|cff808080Reading all mounts, pets and toys...|r", buttons = {} }
                else
                    for _, e in ipairs(entries) do
                        if (kindF == "all" or e.kind == kindF) and (not missOnly or SFP:CollOwned(e) == false)
                            and (#q < 2 or SFP:CollEntryName(e):lower():find(q, 1, true) or (e.source or ""):lower():find(q, 1, true)) then
                            items[#items + 1] = {
                                text = ownedText(e) .. " " .. line(e, 60),
                                check = planIndex(e) ~= nil,
                                onToggle = function(on)
                                    if on then
                                        if not planIndex(e) then table.insert(planData(), { key = e.key, name = SFP:CollEntryName(e) }) end
                                    else
                                        local k = planIndex(e)
                                        if k then table.remove(planData(), k) end
                                    end
                                    fillPlan(); fillResults()
                                end,
                                buttons = SFP:CollTarget(e) and { { "Waypoint", 70, function() SFP:CollWaypoint(e) end } } or {},
                            }
                            if #items >= 200 then break end
                        end
                    end
                    if #items == 0 then items[1] = { text = "|cff808080Nothing matches.|r", buttons = {} } end
                end
            end
            results:Set(items)
        end
        box:SetScript("OnTextChanged", function() fillResults() end)
        SFP.CollPlanChanged = function() fillPlan(); fillResults() end
        SFP:CollectEntries()
        return function() txt:SetText(status()); fillPlan() end
    end)

local buildShare = simplePage("Share Data",
    "Export what the addon learned (monsters, drops, items, nodes, recipes, learned spots) as a copy-paste text, to give to a friend or to move to another account. " ..
    "Import merges a string into your data and never lowers your counts, so importing it twice changes nothing.",
    function(pane, y)
        mkButton(pane, "Export learned data", 190, function() SFP:ShowExport() end):SetPoint("TOPLEFT", 12, y)
        mkButton(pane, "Import learned data", 190, function() SFP:ShowImport() end):SetPoint("TOPLEFT", 214, y)
    end)

local buildDelve = simplePage("Delve Planner",
    "Your class and specializations are detected (change class and it follows). Type the tier you can do safely, choose the companion role and Valeera's curios, and see every delve. " ..
    "Everything is saved. The game's own companion window sets the real role; here you keep your choice and see what is best.",
    function(pane, y)
        local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, y)
        scroll:SetPoint("BOTTOMRIGHT", -30, 8)
        local c = CreateFrame("Frame", nil, scroll)
        c:SetSize(480, 10)
        scroll:SetScrollChild(c)

        local classText = mkText(c, "", 0, 0, 480, "GameFontNormal")
        mkText(c, "Specialization (it follows the spec you play unless you pick one here):", 0, -22, 480, "GameFontHighlightSmall")
        local specBtns = {}
        for i = 1, 5 do
            local b = mkButton(c, "", 152, function(self)
                if self.follow then SFP.db.delveSpec = nil elseif self.specID then SFP.db.delveSpec = self.specID end
                pane.refresh()
            end)
            b:SetPoint("TOPLEFT", ((i - 1) % 3) * 156, -42 - math.floor((i - 1) / 3) * 26)
            specBtns[i] = b
        end

        mkText(c, "Tier you are comfortable with (1-11):", 0, -104, 280, "GameFontHighlightSmall")
        local tierBox = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
        tierBox:SetSize(46, 22)
        tierBox:SetPoint("TOPLEFT", 250, -100)
        tierBox:SetAutoFocus(false)
        tierBox:SetNumeric(true)
        tierBox:SetMaxLetters(2)
        local function saveTier(self)
            SFP:SetDelveTier(self:GetText())
            self:ClearFocus()
            pane.refresh()
        end
        tierBox:SetScript("OnEnterPressed", saveTier)
        tierBox:SetScript("OnEditFocusLost", function(self) SFP:SetDelveTier(self:GetText()) end)
        tierBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        mkButton(c, "Use suggested setup", 190, function() SFP:UseBestSetup(); pane.refresh() end,
            "Sets the companion role and the curios to what the guides suggest for the spec above."):SetPoint("TOPLEFT", 306, -100)

        mkText(c, "Companion role (Valeera):", 0, -134, 480, "GameFontHighlightSmall")
        local roleBtns = {}
        local ROLES = { { nil, "Best for my spec", 140 }, { "Healer", "Healer", 96 }, { "Tank", "Tank", 96 }, { "Damage", "Damage", 96 } }
        local rx = 0
        for i, r in ipairs(ROLES) do
            local b = mkButton(c, r[2], r[3], function() SFP:DelveSet("companion", r[1]); pane.refresh() end)
            b:SetPoint("TOPLEFT", rx, -154)
            b.role, b.label = r[1], r[2]
            roleBtns[i] = b
            rx = rx + r[3] + 4
        end
        local advice = mkText(c, "", 0, -186, 480, "GameFontHighlightSmall")
        advice:SetSpacing(2)

        local curioBtns, curioText = {}, {}
        local function curioBlock(slot, label, topY)
            mkText(c, label, 0, topY, 480, "GameFontNormal")
            local n = 0
            for _, cu in ipairs(SFP.CURIOS or {}) do
                if cu[2] == slot then
                    n = n + 1
                    local b = mkButton(c, cu[1], 156, function()
                        SFP:DelveSet("curio", (SFP:DelveGet("curio", slot) == cu[1]) and false or cu[1], slot)
                        pane.refresh()
                    end, cu[3] .. "\n\nRight-click: mark that you own this curio (the suggestion then picks the best of yours).")
                    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    b:SetScript("OnClick", function(self, btn)
                        if btn == "RightButton" then
                            SFP.db.curiosOwned = SFP.db.curiosOwned or {}
                            SFP.db.curiosOwned[cu[1]] = (not SFP.db.curiosOwned[cu[1]]) or nil
                        else
                            SFP:DelveSet("curio", (SFP:DelveGet("curio", slot) == cu[1]) and false or cu[1], slot)
                        end
                        pane.refresh()
                    end)
                    b:SetPoint("TOPLEFT", ((n - 1) % 3) * 160, topY - 22 - math.floor((n - 1) / 3) * 26)
                    b.curio = cu[1]
                    b.slot = slot
                    curioBtns[#curioBtns + 1] = b
                end
            end
            if n == 0 then
                -- nothing to pick: one grey line under the heading, no "nothing chosen" line on top of it
                mkText(c, "|cff808080No verified curios for this slot yet.|r", 0, topY - 24, 480, "GameFontHighlightSmall")
                return
            end
            local t = mkText(c, "", 0, topY - 22 - math.ceil(n / 3) * 26 - 4, 480, "GameFontHighlightSmall")
            t:SetSpacing(2)
            curioText[slot] = t
        end
        local nextY = -440
        for i, sl in ipairs(SFP:CurioSlots()) do
            local rows = 0
            for _, cu in ipairs(SFP.CURIOS or {}) do if cu[2] == sl.key then rows = rows + 1 end end
            if sl.key == "role" then
                mkText(c, ("Slot %d - Role: the companion role, set with the Healer / Tank / Damage buttons above."):format(i), 0, nextY, 480, "GameFontNormal")
                mkButton(c, "Scan my account's curios", 220, function()
                    -- silent: the owned curios are marked in the list below (nothing is written to the chat)
                    SFP:ScanOwnedCurios()
                    pane.refresh()
                end, "Reads the curios of your delve companion from the game and marks them as owned. Right-click a curio to mark it by hand."):SetPoint("TOPLEFT", 0, nextY - 24)
                nextY = nextY - 70
            else
                curioBlock(sl.key, ("Slot %d - %s (left-click pick, right-click = I have it)"):format(i, sl.label), nextY)
            nextY = nextY - (22 + math.max(1, math.ceil(rows / 3)) * 26 + 56)
            end
        end
        local best = mkText(c, SFP.CURIO_BEST or "", 0, nextY, 480, "GameFontHighlightSmall")
        best:SetTextColor(0.8, 0.8, 0.5)
        local listY = nextY - 60
        local listHead = mkText(c, "", 0, listY, 480, "GameFontNormal")
        local infoText = mkText(c, "", 0, listY - 22, 470, "GameFontHighlightSmall")
        infoText:SetSpacing(2)
        local delveRows = {}
        local function delveRow(i)
            local r = delveRows[i]
            if not r then
                r = CreateFrame("CheckButton", nil, c, "UICheckButtonTemplate")
                r:SetSize(24, 24)
                r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                r.label:SetPoint("LEFT", r, "RIGHT", 2, 0)
                r:SetScript("OnClick", function(self)
                    -- ticking a delve selects it (only one at a time); unticking goes back to the default settings
                    SFP.db.delveSel = self:GetChecked() and self.pick or nil
                    pane.refresh()
                end)
                delveRows[i] = r
            end
            return r
        end
        local listText = infoText

        return function()
            local info = SFP:DelveInfo()
            classText:SetText("Class: " .. (info.className or "?") .. (info.spec and ("   Spec: " .. info.spec.name) or "") .. "   |cffffd100Settings for: " .. (SFP.db.delveSel or "all delves (default)") .. "|r")
            for i, b in ipairs(specBtns) do
                local sp = info.specs[i]
                b.specID, b.follow = nil, nil
                if sp then
                    b.specID = sp.id
                    local sel = info.spec and info.spec.id == sp.id and not info.following
                    b.text:SetText((sel and "|cff40ff40" or "") .. sp.name .. (sp.id == info.currentID and " |cff808080(playing)|r" or ""))
                    b:Show()
                elseif i == #info.specs + 1 then
                    b.follow = true
                    b.text:SetText((info.following and "|cff40ff40" or "") .. "Follow my spec")
                    b:Show()
                else
                    b:Hide()
                end
            end
            if not tierBox:HasFocus() then local t = SFP:DelveGet("tier"); tierBox:SetText(t and tostring(t) or "") end
            for _, b in ipairs(roleBtns) do
                local sel = (b.role == SFP:DelveGet("companion"))
                local mark = (b.role and b.role == info.recommended) and " |cff808080(best)|r" or ""
                b.text:SetText((sel and "|cff40ff40" or "") .. b.label .. mark)
            end
            advice:SetText(SFP:DelveAdvice() .. "\n\n" .. table.concat(SFP:DelveBestSetup().lines, "\n"))
            local chosen = setmetatable({}, { __index = function(_, slot) return SFP:DelveGet("curio", slot) or nil end })
            for _, b in ipairs(curioBtns) do
                local best = SFP:BestCurio(b.slot) == b.curio
                local own = SFP.db.curiosOwned and SFP.db.curiosOwned[b.curio]
                b.text:SetText((chosen[b.slot] == b.curio and "|cff40ff40" or "") .. b.curio .. (own and " |cffffd100(have)|r" or "") .. (best and " |cff40ff40*best|r" or ""))
            end
            for slot, t in pairs(curioText) do
                local name = chosen[slot]
                local bonus
                for _, cu in ipairs(SFP.CURIOS or {}) do if cu[1] == name then bonus = cu[3] end end
                t:SetText(bonus and ("|cff40ff40" .. name .. ":|r " .. bonus) or "|cff808080Nothing chosen yet.|r")
            end
            local list = SFP:DelveList()
            listHead:SetText(("All delves (%d) - click one to set its own tier, companion and curios"):format(#list))
            local sel = SFP.db.delveSel
            local lines = {}
            if sel then
                lines[#lines + 1] = "|cffffd100" .. sel .. "|r  - your choices above are saved for this delve only (anything you leave empty uses the default)."
                local tips = SFP:DelveTips(sel)
                if tips then
                    if tips.where then lines[#lines + 1] = "Where: " .. tips.where end
                    if #tips.variants > 0 then lines[#lines + 1] = "Story variants: " .. table.concat(tips.variants, ", ") end
                    if #tips.tips > 0 then
                        lines[#lines + 1] = "|cffffd100About Valeera here (from the guide):|r"
                        for i = 1, math.min(8, #tips.tips) do lines[#lines + 1] = "  - " .. tips.tips[i] end
                    else
                        lines[#lines + 1] = "The guide has no special advice for Valeera in this delve."
                    end
                else
                    lines[#lines + 1] = "|cff808080No guide written for this delve yet.|r"
                end
                lines[#lines + 1] = "For your spec the best companion role is |cff40ff40" .. info.recommended .. "|r."
            else
                lines[#lines + 1] = "|cff808080Showing the default settings. Pick a delve below to give it its own; untick it to go back to the default.|r"
            end
            infoText:SetText(table.concat(lines, "\n"))
            local top = listY - 22 - infoText:GetStringHeight() - 10
            local n = 0
            local function row(text, pick, isHeader)
                n = n + 1
                local r = delveRow(n)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", c, "TOPLEFT", isHeader and 0 or 12, top - (n - 1) * 24)
                r.pick = pick
                r.label:SetText(text)
                if not r.hdr then r.hdr = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") end
                if isHeader then
                    r:Hide()
                    r.hdr:ClearAllPoints()
                    r.hdr:SetPoint("TOPLEFT", c, "TOPLEFT", 4, top - (n - 1) * 24 - 6)
                    r.hdr:SetText(text)
                    r.hdr:Show()
                else
                    r.hdr:Hide()
                    r:SetChecked(pick ~= nil and sel == pick)
                    r:Show()
                end
            end
            local zone
            for _, dv in ipairs(list) do
                if dv.zone ~= zone then zone = dv.zone; row("|cffffd100" .. zone .. "|r", nil, true) end
                row(dv.name .. (dv.bountiful and "  |cffffd100bountiful today|r" or ""), dv.name)
            end
            for i = n + 1, #delveRows do delveRows[i]:Hide(); if delveRows[i].hdr then delveRows[i].hdr:Hide() end end
            c:SetHeight(-top + n * 24 + 20)
        end
    end)

local buildKeys = simplePage("Delve Keys",
    "Your delve keys and key shards, how many you earned this week, and the delves that are bountiful today. A bountiful delve needs a key and gives an extra chest, so save keys for your best tier.",
    function(pane, y)
        mkButton(pane, "Open delve keys", 170, function() SFP:ShowKeys() end):SetPoint("TOPLEFT", 12, y)
    end)

local buildAch = simplePage("Achievement Planner",
    "Pick an achievement and see what is left, where each step is when the addon knows the place, and what to do first. A button sets a waypoint to the first step with a known place.",
    function(pane, y)
        mkButton(pane, "Open achievement planner", 210, function() SFP:ShowAchPlanner() end):SetPoint("TOPLEFT", 12, y)
    end)

local buildZone = simplePage("Zone Check",
    "What you still miss in the zone or instance you are in: mounts, pets and toys from its rares and bosses. This page updates by itself. The switch for the one chat line when you enter a zone is on the Settings page.",
    function(pane, y)
        mkButton(pane, "Open Settings", 150, function() SFP:ShowMenuSection("settings") end):SetPoint("TOPLEFT", 12, y)
        local head = mkText(pane, "", 12, y - 34, 480, "GameFontNormal")
        local list = SFP.MakeRowList(pane, 8, y - 54, 500, 380, 22)
        return function()
            local title, ents = SFP:ZoneCheckRows()
            if #ents == 0 then
                head:SetText(CYHEX .. title .. "|r  -  nothing missing here that the addon knows about")
                list:Set({})
                return
            end
            head:SetText(("%s%s|r  -  you still miss %d here"):format(CYHEX, title, #ents))
            local items = {}
            for i, e in ipairs(ents) do
                local spot = e.spot
                items[i] = {
                    text = e.text,
                    buttons = spot and { { "Waypoint", 70, function() SFP:ZoneCheckWaypoint(spot) end } } or {},
                }
            end
            list:Set(items)
        end
    end)

local buildDecor = simplePage("Housing Decor",
    "Housing planner: search any decor of any section, add it to your plan and keep it. The plan is saved for all your characters and shows if you already own each decor and where to get it. " ..
    "Below it you can open the full decor list.",
    function(pane, y)
        mkText(pane, CYHEX .. "Your housing plan|r", 12, y, 400, "GameFontNormal")
        local plan = SFP.MakeRowList(pane, 8, y - 20, 500, 150, 22)
        local planInfo = mkText(pane, "", 12, y - 174, 480, "GameFontHighlightSmall")
        mkText(pane, "Tick the decor you need (search by name or by where it comes from); untick to remove it:", 12, y - 194, 400, "GameFontHighlightSmall")
        local box = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
        box:SetSize(260, 20)
        box:SetPoint("TOPLEFT", 16, y - 212)
        box:SetAutoFocus(false)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local results = SFP.MakeRowList(pane, 8, y - 236, 500, 130, 22)
        local function planData()
            SFP.db.decorPlan = SFP.db.decorPlan or {}
            return SFP.db.decorPlan
        end
        local function inPlan(e)
            for i, p in ipairs(planData()) do
                if (e.itemID and p.id == e.itemID) or (not e.itemID and p.name == e.name) then return i end
            end
        end
        local fillPlan, fillResults
        fillPlan = function()
            local entries, byId, byName = SFP:DecorEntries(), {}, {}
            for _, e in ipairs(entries) do
                if e.itemID then byId[e.itemID] = e end
                byName[e.name] = e
            end
            local items, have = {}, 0
            for i, p in ipairs(planData()) do
                local e = (p.id and byId[p.id]) or byName[p.name]
                local state = (e and e.unknownOwned) and "|cff808080owned?|r" or ((e and e.owned) and "|cff40ff40owned|r" or "|cffff6060missing|r")
                if e and e.owned then have = have + 1 end
                local src = e and e.source and e.source ~= "" and ("  |cff808080" .. e.source:sub(1, 90) .. "|r") or ""
                items[#items + 1] = {
                    text = state .. " " .. (e and e.name or p.name) .. src,
                    check = true,
                    onToggle = function(on) if not on then table.remove(planData(), i); fillPlan(); fillResults(); if SFP.RefreshDecorWindow then SFP.RefreshDecorWindow() end end end,
                    buttons = (function()
                        -- a waypoint for every decor with a known place: the exact vendor or boss spot, else the middle of the zone
                        local map, x, y, label, exact = SFP:DecorWaypointFor(e)
                        if not map then return {} end
                        return { { "Waypoint", 70, function()
                            SFP:SetWaypoint(map, x, y, label or (e and e.name) or p.name)
                            if not exact then SFP:Print("Waypoint set to the middle of " .. SFP:ZoneName(map) .. " - the exact spot of this decor is not known.") end
                        end } }
                    end)(),
                }
            end
            plan:Set(items)
            planInfo:SetText(#items == 0 and "|cff808080Nothing planned yet. Search below and tick the decor you want.|r" or ("|cff808080" .. #items .. " planned, " .. have .. " owned.|r"))
        end
        fillResults = function()
            local q = (box:GetText() or ""):lower()
            local items = {}
            if #q >= 2 then
                for _, e in ipairs(SFP:DecorEntries()) do
                    if e.name:lower():find(q, 1, true) or (e.source or ""):lower():find(q, 1, true) then
                        local idx = inPlan(e)
                        items[#items + 1] = {
                            text = e.name .. ((e.source and e.source ~= "") and ("  |cff808080" .. e.source:sub(1, 70) .. "|r") or ""),
                            check = idx ~= nil,
                            onToggle = function(on)
                                if on then
                                    if not inPlan(e) then table.insert(planData(), { id = e.itemID, name = e.name }) end
                                else
                                    local k = inPlan(e)
                                    if k then table.remove(planData(), k) end
                                end
                                fillPlan(); fillResults(); if SFP.RefreshDecorWindow then SFP.RefreshDecorWindow() end
                            end,
                        }
                        if #items >= 60 then break end
                    end
                end
                if #items == 0 then items[1] = { text = "|cff808080Nothing matches.|r", buttons = {} } end
            end
            results:Set(items)
        end
        box:SetScript("OnTextChanged", function() fillResults() end)
        SFP.DecorPlanChanged = function() fillPlan(); fillResults() end
        mkButton(pane, "Open decor list", 170, function() SFP:ShowDecor() end):SetPoint("TOPLEFT", 12, y - 374)
        return function() fillPlan() end
    end)

local buildAlts = simplePage("Alt Overview",
    "Every character you logged in with, in a list you can pick from: overview, bags, bank, the warband bank and all the gold. Bags are saved while you play; a bank is saved when you open it. Profession cooldowns are not shown.",
    function(pane, y)
        mkButton(pane, "Open alt overview", 170, function() SFP:ShowAlts() end):SetPoint("TOPLEFT", 12, y)
    end)

local GUIDE_CATS = {
    { "guide", "New Player Guide", "Start here: classes, gear, professions, travel, gold" },
    { "dungeon", "Dungeons", "Every dungeon: how to enter, bosses, loot" },
    { "raid", "Raids", "Every raid: bosses, tactics, loot" },
    { "boss", "Bosses", "Boss abilities and how to beat them" },
    { "creature", "Monsters & Creatures", "Monsters, rares, tames, world bosses and their drops" },
    { "item", "Loot & Items", "Gear and items and how to get them" },
    { "delve", "Delves", "Every delve: how to run it, bosses, rewards" },
    { "entrance", "Entrances (How to Enter)", "Where and how to enter every dungeon and raid" },
    { "quest", "Quests (what to do)", "How to do the quests" },
    { "mount", "Mounts", "How to get every mount" },
    { "pet", "Battle Pets", "Where to find the pets" },
    { "achievement", "Achievements & Titles", "How to earn them" },
    { "material", "Materials (what for)", "What every material is used for" },
    { "mats", "Gold Farming", "How to make gold in the current game" },
}
local function buildGuides(pane)
    mkText(pane, CYHEX .. "Guides (Codex)|r", 12, -10, 480, "GameFontNormalLarge")
    mkText(pane, "A guide to doing things: dungeons, raids, bosses, loot, delves, quests, mounts, pets, achievements, materials, gold farming and the top 10 grinding spots. It all opens in the Codex; pick the part there.", 12, -34, 500, "GameFontHighlightSmall")
    local box = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
    box:SetSize(260, 20)
    box:SetPoint("TOPLEFT", 18, -84)
    box:SetAutoFocus(false)
    box:SetScript("OnEnterPressed", function(self)
        local cx = codex()
        if cx then cx:StartIndexing(); cx:Toggle(self:GetText()) end
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    mkText(pane, "|cff808080search everything, press Enter|r", 290, -88, 220, "GameFontHighlightSmall")
    mkButton(pane, "Open Codex", 245, function()
        local cx = codex()
        if cx then cx:StartIndexing(); cx:Toggle("") else SFP:Print("The Codex is not loaded.") end
    end, "Opens the Codex with all guides. The Best Grinding Spots tab has the top 10 farm spots."):SetPoint("TOPLEFT", 12, -116)
end

local function buildGroups(pane)
    mkText(pane, CYHEX .. "Groups|r", 12, -10, 480, "GameFontNormalLarge")
    mkText(pane, "Tools for dungeon and raid groups: your group's raid buffs and tier tokens, tags and notes on players you met, filters for Premade Groups when the game offers them. " ..
        "The group makeup opens by itself when you are in a group of 5 or more (dungeon, raid or open world); the switch is on the Settings page.", 12, -34, 500, "GameFontHighlightSmall")
    mkButton(pane, "Open Dungeons & Raids", 190, function()
        -- always opens it (the slash command toggles: a window that was already open would be closed by the button)
        local okM, _, dns = pcall(SFP_Module, "DungeonsRaids")
        if okM and dns and dns.UI and dns.UI.frame and dns.UI.frame:IsShown() then dns.UI.frame:Raise(); return end
        SFP:RunModule("SEVIATHSDUNGEONSRAIDS", "")
    end):SetPoint("TOPLEFT", 12, -90)
    mkButton(pane, "Open Looking For Group", 190, function() SFP.OpenGroupFinder() end, "Opens the game's own Looking For Group window."):SetPoint("TOPLEFT", 214, -90)
    mkButton(pane, "My group's makeup", 190, function()
        -- open the makeup window directly, in front of the menu, and say if something goes wrong
        local okM, _, dns = pcall(SFP_Module, "DungeonsRaids")
        if not (okM and dns and dns.UI and dns.UI.Show) then SFP:Print("The Dungeons & Raids part is not loaded."); return end
        local ok, err = pcall(dns.UI.Show, dns.UI, "group")
        if not ok then SFP:Print("Could not open the group makeup: " .. tostring(err)); return end
        local f = dns.UI.frame
        if f then
            f:SetFrameStrata("FULLSCREEN_DIALOG")
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            f:Show()
            f:Raise()
            if dns.UI.RefreshGroup then pcall(dns.UI.RefreshGroup, dns.UI) end
        else
            SFP:Print("The group makeup window could not be created.")
        end
    end, "Roles, Bloodlust, battle res, missing raid buffs, tier tokens"):SetPoint("TOPLEFT", 12, -120)
    mkButton(pane, "Rate my last group", 190, function() SFP:RunModule("SEVIATHSDUNGEONSRAIDS", "rate") end):SetPoint("TOPLEFT", 12, -150)
    mkText(pane, "Tag a player: /sdr tag Name-Realm good|bad|fav|block", 12, -210, 500, "GameFontHighlightSmall"):SetTextColor(0.7, 0.7, 0.7)
end

local function buildGuild(pane)
    mkText(pane, CYHEX .. "Guild|r", 12, -10, 480, "GameFontNormalLarge")
    mkText(pane, "Find players with /who by level and class, whisper them your pitch and invite them when they say yes. Not in a guild? It helps you collect charter signatures.", 12, -34, 500, "GameFontHighlightSmall")
    mkButton(pane, "Open Guild Helper", 190, function() SFP:RunModule("SEVIATHSGUILDHELPER", "") end):SetPoint("TOPLEFT", 12, -90)
    mkButton(pane, "Scan next level range", 190, function() SFP:RunModule("SEVIATHSGUILDHELPER", "scan") end):SetPoint("TOPLEFT", 12, -120)
    mkButton(pane, "Guild Directory", 190, function() SFP:ShowGuildDirectory() end,
        "All the guilds the addon has seen, by realm, with their faction, Guild Master and officers"):SetPoint("TOPLEFT", 12, -150)
end

local function buildSettings(pane)
    mkText(pane, CYHEX .. "Settings|r", 12, -10, 480, "GameFontNormalLarge")
    pane.checks = {
        -- left column
        mkCheck(pane, "Item and monster tooltip lines", function() return SFP.db.tooltip end, function(v) SFP.db.tooltip = v end, 12, -40),
        mkCheck(pane, "Learn farm spots from my loot", function() return SFP.db.learn end, function(v) SFP.db.learn = v end, 12, -66),
        mkCheck(pane, "Learn everything constantly", function() return SFP.db.learnAll ~= false end,
            function(v) SFP.db.learnAll = v end, 12, -92),
        mkCheck(pane, "Show the minimap button", function() return not SFP.db.minimap.hide end,
            function(v) SFP.db.minimap.hide = not v; SFP:RefreshAll() end, 12, -118),
        mkCheck(pane, "Minimap button glows in farm zones", function() return SFP.db.minimapGlow end, function(v) SFP.db.minimapGlow = v; SFP:RefreshAll() end, 12, -144),
        mkCheck(pane, "Compare monsters: my level and below only", function() return SFP.db.compareMineOnly end,
            function(v) SFP.db.compareMineOnly = v end, 12, -170),
        -- right column
        mkCheck(pane, "Chat message when an auction sells", function() return SFP.db.auctionSold ~= false end,
            function(v) SFP.db.auctionSold = v end, 260, -40),
        mkCheck(pane, "Chat message: mailbox / vendor gold", function() return SFP.db.incomeMessages ~= false end,
            function(v) SFP.db.incomeMessages = v end, 260, -66),
    }
    mkButton(pane, "Show internal errors", 160, function() SFP:Print("see /sfp errors"); SFP:RunModule("SEVIATHSUSEFULTOOLS", "errors") end):SetPoint("TOPLEFT", 12, -190)
    mkButton(pane, "Reload UI", 160, function() ReloadUI() end):SetPoint("TOPLEFT", 180, -190)
    mkButton(pane, "About / options page", 160, function() SFP:OpenAbout() end):SetPoint("TOPLEFT", 348, -190)
    -- rares, alerts and the farm route
    mkText(pane, CYHEX .. "Rares & alerts|r", 12, -220, 400, "GameFontNormal")
    local more = {
        mkCheck(pane, "Rare alerts (chat line)", function() return SFP.db.rareAlerts ~= false end, function(v) SFP.db.rareAlerts = v end, 12, -244),
        mkCheck(pane, "Rare alert sound", function() return SFP.db.rareAlertSound ~= false end, function(v) SFP.db.rareAlertSound = v end, 12, -270),
        mkCheck(pane, "Grey out rares killed today", function() return SFP.db.greyKilled ~= false end,
            function(v) SFP.db.greyKilled = v; SFP:RefreshAll() end, 260, -244),
        mkCheck(pane, "Show the farm route on the map", function() return SFP.db.showRoute ~= false end,
            function(v) SFP.db.showRoute = v; SFP:RefreshAll() end, 260, -270),
    }
    for _, cb in ipairs(more) do pane.checks[#pane.checks + 1] = cb end
    local zc = mkCheck(pane, "Zone check: say what I still miss when I enter a zone", function() return SFP.db.zoneCheck ~= false end,
        function(v) SFP.db.zoneCheck = v end, 12, -306)
    pane.checks[#pane.checks + 1] = zc
    pane.checks[#pane.checks + 1] = mkCheck(pane, "Also scan every auction house section after the fast scan (moves the Browse list)",
        function() return SFP.db.autoSections ~= false end, function(v) SFP.db.autoSections = v end, 12, -332)
    pane.checks[#pane.checks + 1] = mkCheck(pane, "Use Auctionator prices when I have not scanned", function() return SFP.db.useAuctionator ~= false end,
        function(v) SFP.db.useAuctionator = v; SFP:RefreshAll() end, 12, -358)
    pane.checks[#pane.checks + 1] = mkCheck(pane, "Use TradeSkillMaster prices when I have not scanned", function() return SFP.db.useTSM ~= false end,
        function(v) SFP.db.useTSM = v; SFP:RefreshAll() end, 12, -384)
    pane.checks[#pane.checks + 1] = mkCheck(pane, "Always show a button for my groups setup at the top left of the screen", function() return SFP.db.autoGroupComp ~= false end,
        function(v) SFP.db.autoGroupComp = v end, 12, -410)
    mkText(pane, "Each tool has its own page in the list on the left.", 12, -444, 480, "GameFontHighlightSmall"):SetTextColor(0.7, 0.7, 0.7)
    pane.refresh = function()
        local have = {
            ["Use Auctionator prices"] = (Auctionator and Auctionator.API and Auctionator.API.v1) and true or false,
            ["Use TradeSkillMaster prices"] = (TSM_API and TSM_API.GetCustomPriceValue) and true or false,
        }
        for _, cb in ipairs(pane.checks) do
            cb.refresh()
            -- the price source boxes are greyed out when that addon is not installed
            for key, installed in pairs(have) do
                if cb.labelText and cb.labelText:find(key, 1, true) then
                    cb:SetEnabled(installed)
                    cb.text:SetText(cb.labelText .. (installed and "" or "  (addon not installed)"))
                    if installed then cb.text:SetTextColor(1, 1, 1) else cb.text:SetTextColor(0.5, 0.5, 0.5) end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Learned data browser
---------------------------------------------------------------------------
local know = { mode = "npc", offset = 0, list = {}, sel = nil }
local ROWS = 16

local function zoneNames(rec)
    local out = {}
    for map in pairs(rec.m or {}) do out[#out + 1] = SFP:ZoneName(map) end
    table.sort(out)
    return table.concat(out, ", ")
end

local function dropLines(tbl, kills)
    local list = {}
    for id, n in pairs(tbl or {}) do list[#list + 1] = { id, n } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(14, #list) do
        local pct = kills and kills > 0 and (" " .. math.min(100, math.floor(list[i][2] * 100 / kills + 0.5)) .. "%") or (" x" .. list[i][2])
        out[#out + 1] = "  " .. SFP:ItemName(list[i][1]) .. "|cff909090" .. pct .. "|r"
    end
    if #list > 14 then out[#out + 1] = "  |cff808080+" .. (#list - 14) .. " more|r" end
    return table.concat(out, "\n")
end

local function detailText(mode, key)
    local db = SFP.db
    if mode == "npc" then
        local r = db.npcs[key]
        if not r then return "" end
        local lvl = r.lmin and (r.lmin == r.lmax and tostring(r.lmin) or (r.lmin .. "-" .. r.lmax)) or "?"
        local t = CYHEX .. r.n .. "|r  |cff808080NPC ID " .. key .. "|r\n"
        t = t .. "Level " .. lvl .. (r.t and ("  " .. r.t) or "") .. (r.f and ("  " .. r.f) or "") .. (r.c and ("  " .. r.c) or "") .. "\n"
        local z = zoneNames(r)
        if z ~= "" then t = t .. "Seen in: " .. z .. "\n" end
        if r.a then
            local al = {}
            for n in pairs(r.a) do al[#al + 1] = n end
            t = t .. "|cff808080Also seen as: " .. table.concat(al, ", ") .. "|r\n"
        end
        if r.d and next(r.d) then t = t .. "\n\nDrops:\n" .. dropLines(r.d, r.k) end
        if r.s and next(r.s) then t = t .. "\n\nSkinning:\n" .. dropLines(r.s, r.sk) end
        return t
    elseif mode == "obj" then
        local r = db.objects[key]
        if not r then return "" end
        local t = CYHEX .. r.n .. "|r  |cff808080object ID " .. key .. "|r\n"
        local z = zoneNames(r)
        if z ~= "" then t = t .. "Seen in: " .. z .. "\n" end
        t = t .. "\n" .. (r.k or 0) .. " times gathered"
        if r.d and next(r.d) then t = t .. "\n\nGave:\n" .. dropLines(r.d, r.k) end
        return t
    elseif mode == "item" then
        local r = db.knownItems[key]
        if not r then return "" end
        local t = SFP:ItemName(key) .. "  |cff808080item ID " .. key .. "|r\n"
        t = t .. (r.t or "") .. (r.st and (" - " .. r.st) or "") .. (r.i and r.i > 0 and ("  item level " .. r.i) or "") .. "\n"
        for _, l in ipairs(SFP:ItemTipLines(key)) do t = t .. "\n" .. l[1] end
        return t
    elseif mode == "ah" then
        local cls = (db.ahItems and db.ahItems[key]) or (SFP.AuctionItems and SFP.AuctionItems[key] and SFP.AuctionItems[key][1])
        local className = cls and GetItemClassInfo and GetItemClassInfo(cls) or "?"
        local t = SFP:ItemName(key) .. "  |cff808080item ID " .. key .. "|r\nSection: " .. tostring(className) .. "\n"
        local price = SFP:GetPrice(key)
        t = t .. "Auction price: " .. (price and SFP:FormatPrice(price) or "|cff808080none saved|r") .. "\n"
        for _, l in ipairs(SFP:ItemTipLines(key)) do t = t .. "\n" .. l[1] end
        return t
    elseif mode == "recipe" then
        local r = db.recipes[key]
        if not r then return "" end
        local t = CYHEX .. r.n .. "|r  |cff808080" .. (r.p or "") .. "|r\n"
        if r.o then t = t .. "Makes: " .. SFP:ItemName(r.o) .. "\n" end
        t = t .. "\nReagents:\n"
        for _, rg in ipairs(r.r or {}) do t = t .. "  " .. rg[2] .. "x " .. SFP:ItemName(rg[1]) .. "\n" end
        return t
    end
    return ""
end

local function knowRebuild(pane)
    local db = SFP.db
    local q = (pane.search:GetText() or ""):lower()
    local list = {}
    local src, nameOf
    if know.mode == "npc" then src = db.npcs
    elseif know.mode == "obj" then src = db.objects
    elseif know.mode == "item" then src = db.knownItems
    elseif know.mode == "ah" then src = {}
        -- every item ID the auction house scan saw, grouped by its auction section
        -- the items shipped with the addon plus the ones this account learned
        local all = {}
        for id, r in pairs(SFP.AuctionItems or {}) do all[id] = r[1] end
        for id, cls in pairs(db.ahItems or {}) do all[id] = cls end
        for id, cls in pairs(all) do
            local shipped = SFP.AuctionItems and SFP.AuctionItems[id]
            local nm = (db.ahNames and db.ahNames[id]) or (shipped and shipped[2] ~= "" and shipped[2]) or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
            if not nm and C_Item and C_Item.RequestLoadItemDataByID and #src < 200 then pcall(C_Item.RequestLoadItemDataByID, id) end
            local cn = GetItemClassInfo and GetItemClassInfo(cls) or tostring(cls)
            src[id] = { n = (cn or "?") .. ": " .. (nm or ("item " .. id)) }
        end
    else src = db.recipes end
    for key, r in SeviathsAllPairs(src) do
        local name = r.n or ""
        -- items are grouped by their category (type and subtype, as the game names them): "Armor - Leather: Tailthrasher Bindings"
        if know.mode == "item" then name = (r.t or "Other") .. ((r.st and r.st ~= "") and (" - " .. r.st) or "") .. ": " .. name end
        if q == "" or name:lower():find(q, 1, true) or tostring(key):find(q, 1, true) then
            list[#list + 1] = { key = key, name = name }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    know.list = list
    know.offset = 0
    pane.count:SetText(#list .. " found")
end

local function knowRefresh(pane)
    for i = 1, ROWS do
        local row = pane.rows[i]
        local e = know.list[know.offset + i]
        if e then
            row.key = e.key
            row.text:SetText(e.name)
            row.hl:SetShown(know.sel == e.key)
            row:Show()
        else
            row:Hide()
        end
    end
    pane.detail:SetText(know.sel and detailText(know.mode, know.sel) or "|cff808080Pick an entry on the left. Everything here was learned while you played, and is saved for all your characters.|r")
end

local function buildKnow(pane)
    mkText(pane, CYHEX .. "Learned data|r", 12, -10, 400, "GameFontNormalLarge")
    pane.rows = {}
    local modes = { { "npc", "Monsters" }, { "obj", "Nodes" }, { "item", "Items" }, { "ah", "Auction" }, { "recipe", "Recipes" } }
    pane.tabs = {}
    for i, m in ipairs(modes) do
        local b = mkButton(pane, m[2], 70, function()
            know.mode, know.sel = m[1], nil
            knowRebuild(pane); knowRefresh(pane)
            for _, t in ipairs(pane.tabs) do t:SetBackdropBorderColor(CY.r, CY.g, CY.b, t.mode == m[1] and 1 or 0.4) end
        end)
        b.mode = m[1]
        b:SetPoint("TOPLEFT", 12 + (i - 1) * 74, -36)
        pane.tabs[i] = b
    end
    pane.search = CreateFrame("EditBox", nil, pane, "InputBoxTemplate")
    pane.search:SetSize(190, 20)
    pane.search:SetPoint("TOPLEFT", 18, -68)
    pane.search:SetAutoFocus(false)
    pane.search:SetScript("OnTextChanged", function() knowRebuild(pane); knowRefresh(pane) end)
    pane.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    pane.count = mkText(pane, "", 220, -72, 100, "GameFontHighlightSmall")
    local listFrame = CreateFrame("Frame", nil, pane)
    listFrame:SetPoint("TOPLEFT", 12, -92)
    listFrame:SetSize(230, ROWS * 18)
    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(_, delta)
        local maxOff = math.max(0, #know.list - ROWS)
        know.offset = math.max(0, math.min(maxOff, know.offset - delta * 3))
        knowRefresh(pane)
    end)
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, listFrame)
        row:SetSize(230, 18)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 18)
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetAllPoints(); row.hl:SetColorTexture(CY.r, CY.g, CY.b, 0.25); row.hl:Hide()
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 4, 0); row.text:SetWidth(222); row.text:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self) know.sel = self.key; knowRefresh(pane) end)
        pane.rows[i] = row
    end
    pane.detail = mkText(pane, "", 252, -70, 262, "GameFontHighlightSmall")
    pane.detail:SetWidth(262)
    pane.detail:SetJustifyV("TOP")
    pane.refresh = function() knowRebuild(pane); knowRefresh(pane) end
end

---------------------------------------------------------------------------
-- Gem & Enchant Helper
---------------------------------------------------------------------------
local buildGems = simplePage("Gem & Enchant Helper",
    "Pick a class and specialization (your own is the start): the recommended gems and enchants from the guides, what you wear now, empty sockets, missing enchants, and what it costs at the auction house. Tick what you want to get to plan it.",
    function(pane, y)
        local GH = SFP.GemHelper
        local classBtn, specBtn
        local function relabel()
            local token, spec = GH.Selected()
            classBtn.text:SetText("Class: " .. GH.ClassLabel(token))
            specBtn.text:SetText("Spec: " .. tostring(spec))
        end
        -- the planner opens in its own window, like the other planners
        mkButton(pane, "Planner", 120, function() GH.ShowPlanner() end,
            "Every gem and enchant (from the auction house scans and Wowhead): search, click to add, tick to count, prices follow the scans"):SetPoint("TOPLEFT", 12, y)
        classBtn = mkButton(pane, "", 190, function() GH.NextClass(1); pane.refresh() end, "Click for the next class")
        classBtn:SetPoint("TOPLEFT", 12, y - 28)
        specBtn = mkButton(pane, "", 190, function() GH.NextSpec(1); pane.refresh() end, "Click for the next specialization")
        specBtn:SetPoint("TOPLEFT", 208, y - 28)
        mkButton(pane, "My spec", 90, function()
            SFP.db.gemClass, SFP.db.gemSpec = nil, nil
            pane.refresh()
        end, "Back to your own class and the specialization you play"):SetPoint("TOPLEFT", 404, y - 28)

        local stat = mkText(pane, "", 12, y - 56, 500, "GameFontHighlightSmall")
        stat:SetTextColor(0.85, 0.85, 0.85)
        local gear = mkText(pane, "", 12, y - 92, 500, "GameFontHighlightSmall")
        local list = SFP.MakeRowList(pane, 8, y - 138, 500, 230, 20)
        local total = mkText(pane, "", 12, y - 374, 500, "GameFontHighlightSmall")
        local rowsNow = {}

        return function()
            local token, spec = GH.Selected()
            relabel()
            local rows, data, own = GH.Rows(token, spec)
            rowsNow = rows
            if not data then
                stat:SetText("No data for this specialization.")
                list:Set({})
                return
            end
            stat:SetText("|cffffd100Stat priority:|r " .. data.stat .. "   |cff808080(Method guides, patch " .. (SFP.GemEnchantBisPatch or "?") .. ")|r")
            -- your own gear against the recommendation
            local lines = {}
            if own and own.any then
                if own.empty > 0 then lines[#lines + 1] = ("|cffff6060Empty sockets: %d (%s)|r"):format(own.empty, table.concat(own.emptyWhere, ", ")) end
                if #own.missing > 0 then lines[#lines + 1] = "|cffff6060Missing enchants: " .. table.concat(own.missing, ", ") .. "|r" end
                local cmp = GH.Compare(own, data)
                if #cmp.offGems > 0 then lines[#lines + 1] = "|cffffd100Gems not on the guide: " .. table.concat(cmp.offGems, ", ") .. "|r" end
                if own.empty == 0 and #own.missing == 0 and #cmp.offGems == 0 then lines[#lines + 1] = "|cff40ff40Your gear: every socket filled and every slot enchanted.|r" end
            end
            gear:SetText(table.concat(lines, "\n"))
            -- the list
            local items = {}
            for _, r in ipairs(rows) do
                if r.header then
                    items[#items + 1] = { text = CYHEX .. r.header .. "|r", buttons = {} }
                elseif r.note then
                    items[#items + 1] = { text = "   |cff808080" .. r.note .. "|r", buttons = {} }
                elseif r.planName then
                    -- click a gem or enchant to add it to the planner, click again to take it out
                    items[#items + 1] = {
                        text = r.text, check = GH.PlanHas(r.planName),
                        onToggle = function(on)
                            GH.PlanSet(r.planName, r.kind, on)
                            pane.refresh()
                            if GH.PlannerRefresh then GH.PlannerRefresh() end
                        end,
                        buttons = {},
                    }
                else
                    items[#items + 1] = { text = r.text, buttons = {} }
                end
            end
            list:Set(items)
            local n, sum, noPrice = GH.PlanTotal()
            if n == 0 then
                total:SetText("|cff808080Planner is empty. Click the gems and enchants you want to add to it (button Planner above).|r")
            else
                total:SetText(("In the planner: %d item%s, about %s%s"):format(n, n == 1 and "" or "s",
                    GetMoneyString and GetMoneyString(sum, true) or sum,
                    noPrice > 0 and ("  |cff808080(" .. noPrice .. " without a price: scan the auction house)|r") or ""))
            end
        end
    end)

---------------------------------------------------------------------------
-- Players & Party
---------------------------------------------------------------------------
local buildSocial = simplePage("Players & Party",
    "Hover a player to see their item level, empty sockets and missing enchants. Players who also have this addon share a small profile with you: collections, Mythic+ score, what they did this week (numbers only), their play style and what they dislike in a group. Nothing leaves the game.",
    function(pane, y)
        local S = SFP.Social
        local c = S.Config()
        local checks = {
            mkCheck(pane, "Share my profile with other addon users", function() return S.Config().share end, function(v) S.Config().share = v end, 12, y),
            mkCheck(pane, "Show item level and profiles on player tooltips", function() return S.Config().tip end, function(v) S.Config().tip = v end, 12, y - 26),
            mkCheck(pane, "One chat line about my group when it forms", function() return S.Config().groupLine end, function(v) S.Config().groupLine = v end, 12, y - 52),
        }
        local styleBtn, styleInfo
        styleBtn = mkButton(pane, "", 300, function()
            local cfg = S.Config()
            local idx = 1
            for i, s in ipairs(S.STYLES) do if s[1] == cfg.style then idx = i end end
            cfg.style = S.STYLES[(idx % #S.STYLES) + 1][1]
            pane.refresh()
        end, "Click to change how you describe your play style. Automatic decides from your numbers.")
        styleBtn:SetPoint("TOPLEFT", 12, y - 84)
        mkButton(pane, "Open my group", 130, function() S.ShowGroup() end, "Item level, profile, sockets and enchants of everyone in your group"):SetPoint("TOPLEFT", 322, y - 84)
        styleInfo = mkText(pane, "", 12, y - 112, 500, "GameFontHighlightSmall")

        mkText(pane, CYHEX .. "What I dislike in a group|r  (others who have the addon see it on my tooltip)", 12, y - 140, 500, "GameFontNormal")
        for i, d in ipairs(S.DISLIKES) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local id = d[1]
            checks[#checks + 1] = mkCheck(pane, d[2], function() return S.Config().dislikes[id] end,
                function(v) S.Config().dislikes[id] = v and true or nil end, 12 + col * 255, y - 164 - row * 24)
        end
        local preview = mkText(pane, "", 12, y - 316, 500, "GameFontHighlightSmall")
        preview:SetTextColor(0.8, 0.8, 0.8)
        return function()
            local cfg = S.Config()
            local label = "Automatic"
            for _, s in ipairs(S.STYLES) do if s[1] == cfg.style then label = s[2] end end
            styleBtn.text:SetText("Play style: " .. (cfg.style == "auto" and "Automatic" or label))
            local p = S.MyProfile()
            if cfg.style == "auto" then
                styleInfo:SetText("The addon says you are: |cffffd100" .. S.StyleLabels(p.style) .. "|r  (from what you did in the last 28 days: raids, Mythic+, delves, collecting, achievements, PvP, dailies, farming, gold. The two strongest.)")
            else
                styleInfo:SetText("You chose: |cffffd100" .. S.StyleLabels(p.style) .. "|r")
            end
            for _, cb in ipairs(checks) do cb.refresh() end
            -- only what you have: numbers at 0 are not shown to others, so they are not listed here either
            local seen = { "item level " .. p.ilvl }
            for _, e in ipairs({ { "Mythic+ score", p.mplus }, { "achievements", p.ach }, { "mounts", p.mounts }, { "battle pets", p.pets },
                { "housing decor", p.decor }, { "dungeons this week", p.dw }, { "raid bosses this week", p.rw }, { "delves this week", p.dl } }) do
                if (e[2] or 0) > 0 then seen[#seen + 1] = e[2] .. " " .. e[1]:gsub("^Mythic%+ score$", "Mythic+ score") end
            end
            preview:SetText("What others see: " .. table.concat(seen, ", ") .. ".")
        end
    end)

---------------------------------------------------------------------------
-- Guild Directory: the guilds the addon has seen, by realm, with the Guild Master and the officers to whisper
---------------------------------------------------------------------------
local FACTION_HEX = { Alliance = "ff4a8cff", Horde = "ffff4a4a" }

local buildGuilds = simplePage("Guild Directory",
    "A window of its own with a button for every realm (Argent Dawn, Kazzak, Silvermoon ...). Pick a realm to see all the guilds the addon knows on it, "
    .. "each with its faction, its Guild Master and its officers, and click Whisper to write to one. It knows what it has seen: guilds on the nameplates "
    .. "of players around you, your own guild's whole roster, and the guild masters and officers who have this addon.",
    function(pane, y)
        mkButton(pane, "Open the Guild Directory", 220, function() SFP:ShowGuildDirectory() end):SetPoint("TOPLEFT", 12, y)
        return function() end
    end)

local BUILDERS = {
    home = buildHome, farm = buildFarm, alerts = buildAlerts, killed = buildKilled, route = buildRoute, session = buildSession,
    next = buildNext, weekly = buildWeekly, deals = buildDeals, shop = buildShop, collect = buildCollect, share = buildShare,
    delve = buildDelve, keys = buildKeys, ach = buildAch, zone = buildZone, decor = buildDecor, alts = buildAlts,
    guides = buildGuides, groups = buildGroups, guild = buildGuild, know = buildKnow, settings = buildSettings,
    gems = buildGems, social = buildSocial, guilds = buildGuilds,
}

-- what the planner pages of Planners.lua (WoW Forever) need to put themselves in the menu
SFP.MenuKit = { builders = BUILDERS, sections = SECTIONS, simplePage = simplePage, mkButton = mkButton, mkText = mkText, mkCheck = mkCheck }

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
function SFP:ShowMenuSection(key)
    if not frame then return end
    frame:Raise()
    current = key
    for _, s in ipairs(SECTIONS) do
        local b = navButtons[s.key]
        if s.key == key then b:LockHighlight() else b:UnlockHighlight() end
        if panes[s.key] then panes[s.key]:Hide() end
    end
    local pane = panes[key]
    if not pane then
        pane = CreateFrame("Frame", nil, frame.content)
        pane:SetAllPoints()
        panes[key] = pane
        SFP:Safe("build " .. key, BUILDERS[key], pane)
    end
    pane:Show()
    if pane.refresh then SFP:Safe("refresh " .. key, pane.refresh) end
    -- the decor list opens next to the menu, on its right side
    if key == "guilds" and SFP.ShowGuildDirectory then SFP:Safe("guild directory", SFP.ShowGuildDirectory, SFP) end
end

function SFP:MenuFrame() return frame end

local function build()
    frame = CreateFrame("Frame", "SeviathsUsefulToolsMenu", UIParent, "BackdropTemplate")
    frame:SetSize(960, 700)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    SFP.RegisterWindow(frame)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    SFP.BlizzardFrame(frame, true)
    tinsert(UISpecialFrames, "SeviathsUsefulToolsMenu")

    local title = CreateFrame("Frame", nil, frame)
    title:SetPoint("TOPLEFT"); title:SetPoint("TOPRIGHT", -34, 0); title:SetHeight(28)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() frame:StartMoving() end)
    title:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local tt = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tt:SetPoint("LEFT", 12, 0)
    tt:SetText(CYHEX .. "Seviaths|r UsefulTools  |cff808080v" .. SFP.VERSION .. "|r")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetFrameLevel(frame:GetFrameLevel() + 30)
    close:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    close:SetScript("OnClick", function() frame:Hide() end)
    frame.close = close

    local navScroll = CreateFrame("ScrollFrame", nil, frame)
    navScroll:SetPoint("TOPLEFT", 4, -34)
    navScroll:SetPoint("BOTTOMLEFT", 4, 8)
    navScroll:SetWidth(194)
    local navChild = CreateFrame("Frame", nil, navScroll)
    navChild:SetSize(194, #SECTIONS * 28 + 8)
    navScroll:SetScrollChild(navChild)
    navScroll:EnableMouseWheel(true)
    navScroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, navChild:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 50)))
    end)
    for i, s in ipairs(SECTIONS) do
        local b = mkButton(navChild, s.label, 184, function() SFP:ShowMenuSection(s.key) end)
        b:SetHeight(24)
        b:SetPoint("TOPLEFT", 6, -2 - (i - 1) * 28)
        navButtons[s.key] = b
    end
    frame.content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.content:SetPoint("TOPLEFT", 202, -34)
    frame.content:SetPoint("BOTTOMRIGHT", -8, 8)
    SFP.BlizzardFrame(frame.content, "inset")
end

function SFP:ToggleMenu(section)
    local justBuilt = false
    if not frame then build(); justBuilt = true end
    -- a menu that was only just created must open on this click (a new frame counts as shown before it is drawn)
    if frame:IsShown() and not section and not justBuilt then frame:Hide(); return end
    frame:Show()
    frame:Raise()
    self:ShowMenuSection(section or current or "home")
end

-- the minimap button's old menu now opens the main menu
SFP.ShowHubMenu = function() SFP:ToggleMenu() end

-- one minimap button for everything: hide the merged addons' own buttons
SFP:OnLogin(function()
    if not SFP.db.mergedButtonsHidden then
        SFP.db.mergedButtonsHidden = true
        if SeviathsCodexDB and SeviathsCodexDB.minimap then SeviathsCodexDB.minimap.hide = true end
        if SeviathsDungeonsRaidsDB and SeviathsDungeonsRaidsDB.minimap then SeviathsDungeonsRaidsDB.minimap.show = false end
        if SeviathsGuildHelperDB and SeviathsGuildHelperDB.settings and SeviathsGuildHelperDB.settings.minimap then
            SeviathsGuildHelperDB.settings.minimap.hide = true
        end
    end
    for _, name in ipairs({ "SeviathsCodexMinimapButton", "SDRMinimapButton", "SeviathsGuildHelperMinimapButton" }) do
        local f = _G[name]
        if f and f.Hide then f:Hide() end
    end
end)
