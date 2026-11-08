-- Seviath's Dungeons & Raids - your own group's makeup and applicant tags (for leaders)
local _, ns = SFP_Module("DungeonsRaids")
local D = ns.Data

function ns:GroupComp()
  local c = {
    n = 0, roles = { TANK = 0, HEALER = 0, DAMAGER = 0, NONE = 0 },
    classes = {}, present = {}, tokens = {}, missing = {},
  }
  for _, unit in ipairs(ns.GroupUnits()) do
    if UnitExists(unit) then
      local _, class = UnitClass(unit)
      class = ns.Safe(class)
      local role = ns.Safe(UnitGroupRolesAssigned(unit)) or "NONE"
      c.n = c.n + 1
      c.roles[role] = (c.roles[role] or 0) + 1
      if class then
        c.classes[class] = (c.classes[class] or 0) + 1
        if D.LUST[class] then c.lust = true end
        if D.BREZ[class] then c.brez = true end
        for _, b in ipairs(D.BUFFS) do
          if D.Provides(b, class) then c.present[b.key] = true end
        end
        local tok = D.TOKEN[class]
        if tok then c.tokens[tok] = (c.tokens[tok] or 0) + 1 end
      end
    end
  end
  for _, b in ipairs(D.BUFFS) do
    if not c.present[b.key] then c.missing[#c.missing + 1] = b end
  end
  return c
end

function ns:GroupCompText()
  local c = ns:GroupComp()
  local function YN(v) return v and "|cff40ff60yes|r" or "|cffff5050no|r" end
  local lines = {}
  if not IsInGroup() then lines[#lines + 1] = "|cff999999You are not in a group: this is only you. It works for any group size, so join or invite people and press Refresh.|r"; lines[#lines + 1] = " " end
  lines[#lines + 1] = string.format("Members: |cffffffff%d|r    Tanks %d   Healers %d   DPS %d%s",
    c.n, c.roles.TANK, c.roles.HEALER, c.roles.DAMAGER,
    c.roles.NONE > 0 and ("   |cff999999no role " .. c.roles.NONE .. "|r") or "")
  lines[#lines + 1] = "Bloodlust: " .. YN(c.lust) .. "     Battle res: " .. YN(c.brez)
  lines[#lines + 1] = " "
  local have, need = {}, {}
  for _, b in ipairs(D.BUFFS) do
    if c.present[b.key] then
      have[#have + 1] = "|cff40ff60" .. b.name .. "|r"
    else
      need[#need + 1] = "|cffffb040" .. b.name .. "|r (" .. D.ProviderText(b) .. ")"
    end
  end
  lines[#lines + 1] = "|cff" .. ns.CYAN_HEX .. "Raid buffs covered|r"
  lines[#lines + 1] = #have > 0 and table.concat(have, ", ") or "none"
  lines[#lines + 1] = " "
  lines[#lines + 1] = "|cff" .. ns.CYAN_HEX .. "Missing (class that brings it)|r"
  lines[#lines + 1] = #need > 0 and table.concat(need, "\n") or "|cff40ff60All covered|r"
  lines[#lines + 1] = " "
  lines[#lines + 1] = "|cff" .. ns.CYAN_HEX .. "Tier tokens|r"
  local tok = {}
  for _, name in ipairs({ "Cloth", "Leather", "Mail", "Plate" }) do
    tok[#tok + 1] = name .. " " .. (c.tokens[name] or 0)
  end
  lines[#lines + 1] = table.concat(tok, "    ")
  lines[#lines + 1] = " "
  lines[#lines + 1] = "|cff" .. ns.CYAN_HEX .. "About tier tokens (Midnight Season 2, The Venomous Abyss)|r"
  lines[#lines + 1] = "A token turns into the tier piece for your class; tokens follow your armor type: Cloth (Mage, Priest, Warlock), Leather (Demon Hunter, Druid, Monk, Rogue), Mail (Evoker, Hunter, Shaman), Plate (Death Knight, Paladin, Warrior)."
  lines[#lines + 1] = "Slots: Entombed Sentinels - gloves, Vashnik the Malignant - chest, The Lost Explorers - shoulders, Sszorak - legs, The Twin Fangs - helm. The last boss, Ula'tek, drops a flexible curio that can be traded for any token."
  lines[#lines + 1] = "Four tier pieces turn on the full set bonus (a fifth slot only gives flexibility). The Matrix Catalyst can turn a piece into a missing tier slot; it uses a Venomblight Manaflux per conversion."
  lines[#lines + 1] = "|cff999999A group with many players of the same armor type competes for each token. Source: Maxroll and WoWCarry guides, Oct 2026; not checked in game.|r"
  return table.concat(lines, "\n")
end

-- Cache the comp briefly; applicant rows update many times in a row
local compCache, compTime = nil, 0
local function CachedComp()
  if not compCache or GetTime() - compTime > 2 then
    compCache, compTime = ns:GroupComp(), GetTime()
  end
  return compCache
end

ns:RequestHook("LFGListApplicationViewer_UpdateApplicantMember", function(member, appID, memberIdx)
  if not ns.db or not ns.db.annotate or not member or not appID then return end
  local ok, name, class = pcall(C_LFGList.GetApplicantMemberInfo, appID, memberIdx)
  if not ok then return end
  name, class = ns.Safe(name), ns.Safe(class)
  if not member.SDRText then
    local fs = member:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if member.Name then
      fs:SetPoint("LEFT", member.Name, "RIGHT", 4, 0)
    else
      fs:SetPoint("LEFT", member, "LEFT", 150, 0)
    end
    member.SDRText = fs
  end
  local parts = {}
  local full = name and ns.FullName(name)
  member.SDRName = full   -- for the hover below (the row is reused for other applicants)
  if not member.SDRHover and member.HookScript then
    member.SDRHover = true
    -- hovering an applicant: what is known about them (their addon's profile, Raider.IO, the baked armory data)
    member:HookScript("OnEnter", function(self)
      local S = _G.SeviathsUsefulTools and _G.SeviathsUsefulTools.Social
      if not (S and S.AddByName and self.SDRName) then return end
      if GameTooltip:IsShown() then
        GameTooltip:AddLine(" ")
        pcall(S.AddByName, GameTooltip, self.SDRName)
        GameTooltip:Show()
      end
    end)
  end
  if full then
    local t = ns:TagShortFor(full)
    if t ~= "" then parts[#parts + 1] = t end
  end
  if class then
    local comp = CachedComp()
    for _, b in ipairs(comp.missing) do
      if D.Provides(b, class) then parts[#parts + 1] = "|cff40ff60+" .. b.short .. "|r" end
    end
    if not comp.lust and D.LUST[class] then parts[#parts + 1] = "|cff40ff60+BL|r" end
    if not comp.brez and D.BREZ[class] then parts[#parts + 1] = "|cff40ff60+BR|r" end
  end
  member.SDRText:SetText(table.concat(parts, " "))
end)

-- the makeup does not open by itself (it covered the screen when a dungeon was entered): a small button at the top left of the screen opens it, always
local autoPending, groupButton
local function AutoComp()
  local S = _G.SeviathsUsefulTools
  local want = not (S and S.db and S.db.autoGroupComp == false)   -- always there, whatever the size of the group (the setting can switch it off)
  if not want then
    if groupButton then groupButton:Hide() end
    return
  end
  if not groupButton then
    groupButton = CreateFrame("Button", "SeviathsGroupMakeupButton", UIParent, "UIPanelButtonTemplate")
    groupButton:SetSize(120, 24)
    groupButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -12)
    groupButton:SetFrameStrata("MEDIUM")
    groupButton:SetText("My groups setup")
    groupButton:SetScript("OnClick", function()
      if ns.UI and ns.UI.Show then ns.UI:Show("group") end
    end)
    groupButton:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("My groups setup")
      GameTooltip:AddLine("Raid buffs, bloodlust, battle res and tier tokens of your group.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    groupButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  groupButton:Show()
end

local function ScheduleAuto()
  if autoPending then return end
  autoPending = true
  C_Timer.After(2.5, function()
    autoPending = false
    local ok, err = pcall(AutoComp)
    if not ok then geterrorhandler()(err) end
  end)
end

ns:On("GROUP_ROSTER_UPDATE", function()
  compCache = nil
  if ns.UI and ns.UI.RefreshGroup then ns.UI:RefreshGroup() end
  ScheduleAuto()
end)
ns:On("PLAYER_ENTERING_WORLD", ScheduleAuto)
ns:On("PLAYER_REGEN_ENABLED", ScheduleAuto)
