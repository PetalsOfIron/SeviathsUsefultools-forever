-- Seviath's Dungeons & Raids - class data
-- Check these after big patches: Blizzard sometimes moves raid buffs between classes.
local _, ns = SFP_Module("DungeonsRaids")
local D = {}
ns.Data = D

-- Raid buffs and raid-wide debuffs, one provider class each
D.BUFFS = {
  { key = "INT",    name = "Arcane Intellect",         short = "Int",    class = "MAGE" },
  { key = "STAM",   name = "Power Word: Fortitude",    short = "Stam",   class = "PRIEST" },
  { key = "MARK",   name = "Mark of the Wild",         short = "MotW",   class = "DRUID" },
  { key = "AP",     name = "Battle Shout",             short = "AP",     class = "WARRIOR" },
  { key = "BLESS",  name = "Blessings",                short = "Bless",  class = "PALADIN" },
  { key = "TRUE",   name = "Trueshot Aura",            short = "Aura",   class = "HUNTER" },
  { key = "TOTEM",  name = "Totems (Windfury, Strength of Earth)", short = "Totem", class = "SHAMAN" },
  { key = "CURSE",  name = "Curse of the Elements",    short = "Curse",  class = "WARLOCK" },
  { key = "EXPOSE", name = "Expose Armor",             short = "Armor",  class = "ROGUE" },
}

-- does this class bring the buff?
function D.Provides(buff, class)
  return (buff.classes and buff.classes[class]) or buff.class == class
end

-- "Mage, Warlock, Shaman" in the player's language
function D.ProviderText(buff)
  local names = {}
  for class in pairs(buff.classes or { [buff.class] = true }) do names[#names + 1] = D.ClassLabel(class) end
  table.sort(names)
  return table.concat(names, ", ")
end

D.LUST = {}   -- Forever has no Bloodlust in the lists of the group tools
D.BREZ = { DRUID = true, WARLOCK = true }   -- Rebirth, Soulstone

D.ARMOR = {
  WARRIOR = "Plate", PALADIN = "Plate",
  HUNTER = "Mail", SHAMAN = "Mail",
  ROGUE = "Leather", DRUID = "Leather",
  PRIEST = "Cloth", MAGE = "Cloth", WARLOCK = "Cloth",
}

-- Tier token groups. Midnight Season 2 (patch 12.1): the token families follow the armor type
-- (cloth, leather, mail, plate) instead of the old mixed-class groups (Dreadful / Mystic / Venerated / Zenith).
D.TOKEN = {}
for class, armor in pairs(D.ARMOR) do D.TOKEN[class] = armor end

D.DIFF_ID = { N = 14, H = 15, M = 16 }
-- Every difficulty that counts as Normal / Heroic / Mythic, including old 10/25/40-player raids
D.DIFF_IDS = { N = { 14, 3, 4, 9, 1 }, H = { 15, 5, 6, 2 }, M = { 16, 23, 8 } }

-- Small class icon for use inside text
function D.ClassIcon(class, size)
  size = size or 14
  local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  if c then
    return string.format("|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:%d:%d:0:0:256:256:%d:%d:%d:%d|t",
      size, size, c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
  end
  return "|A:classicon-" .. class:lower() .. ":" .. size .. ":" .. size .. "|a"
end
D.DIFF_LABEL = { N = "Normal", H = "Heroic", M = "Mythic" }
D.ROLE_LABEL = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

function D.ClassLabel(class)
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end
