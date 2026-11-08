-- Seviath's Codex — Raiding Guide (WoW Forever / Classic)
-- Written for this addon (CC BY-NC 3.0). Evergreen on purpose: season numbers, affixes and item levels are not given;
-- the pages say where to read the current values in the game.

local ADDON, ns = SFP_Module("Codex")
local C = "|cffffd100"
local R = "|r"
local NOTE = "|cff888888Numbers, rules and rewards change every season. Check the in-game windows and the Adventure Guide for the current values.|r"

-- what each class brings; shared by both guides
local CLASSES = [[
Utility is what a class gives the group besides damage, healing or tanking. Groups often ask for it, but a good player of any class is welcome.

]]..C.."Group buffs (one of each is enough)"..R..[[
• Mage — Arcane Intellect.   • Priest — Power Word: Fortitude.   • Warrior — Battle Shout.
• Druid — Mark of the Wild.   • Shaman — Skyfury.   • Evoker — Blessing of the Bronze.

]]..C.."Bloodlust (a short haste boost for the group)"..R..[[
• Shaman, Mage and Evoker have it. A Hunter's pet can give a similar boost.

]]..C.."Battle resurrection (bring a dead player back in combat)"..R..[[
• Druid, Death Knight, Paladin and Warlock.

]]..C.."By class: what it is known for"..R..[[
• ]]..C.."Death Knight"..R..[[ — Death Grip, Anti-Magic Zone for the group, resurrection in combat.
• ]]..C.."Demon Hunter"..R..[[ — mobility, a group defensive (Darkness), a damage debuff on enemies.
• ]]..C.."Druid"..R..[[ — Mark of the Wild, resurrection in combat, Innervate (mana for a healer), speed boost for the group.
• ]]..C.."Evoker"..R..[[ — Blessing of the Bronze, Bloodlust, rescue a player from danger.
• ]]..C.."Hunter"..R..[[ — Misdirection (moves threat to the tank), removing an enrage, a pet that can give a haste boost.
• ]]..C.."Mage"..R..[[ — Arcane Intellect, Time Warp, portals and food.
• ]]..C.."Monk"..R..[[ — a damage debuff on enemies, strong crowd control, mobility.
• ]]..C.."Paladin"..R..[[ — blessings that protect or free a player, lay on hands, resurrection in combat.
• ]]..C.."Priest"..R..[[ — Power Word: Fortitude, Power Infusion (a damage boost for one player), mass dispel.
• ]]..C.."Rogue"..R..[[ — Tricks of the Trade (damage boost for a player), strong interrupts, stealth to skip groups.
• ]]..C.."Shaman"..R..[[ — Bloodlust, Skyfury, totems for healing, speed and defence.
• ]]..C.."Warlock"..R..[[ — Healthstones, Soulstone, summoning players, resurrection in combat.
• ]]..C.."Warrior"..R..[[ — Battle Shout, a group defensive (Rallying Cry), jumping to a player or an enemy.

|cff888888Which class has which ability changes sometimes. The Groups page of this addon shows what your group has right now; spell tooltips are the final word.|r]]

ns.RAIDGUIDE = {
------------------------------------------------------------------------
{ id = "raid-what", group = "1. Before you go", title = "What a Classic raid is and what to expect", icon = "Achievement_Boss_Ragnaros",
  tags = "raid what is expect first time 40 20 man lockout molten core onyxia blackwing zul'gurub ahn'qiraj naxxramas",
  body = [[
A raid is a big dungeon for many players. In Classic there are no difficulty levels and no Raid Finder: you form the group yourself, usually through a guild or a pick-up group from chat.

]]..C.."The raids of Classic"..R..[[
• ]]..C.."Molten Core"..R..[[ — 40 players, level 60. The first raid; Ragnaros is the last boss.
• ]]..C.."Onyxia's Lair"..R..[[ — 40 players, one dragon. Needs the attunement quest chain.
• ]]..C.."Blackwing Lair"..R..[[ — 40 players, Nefarian is the last boss. Needs an attunement.
• ]]..C.."Zul'Gurub"..R..[[ — 20 players, the Gurubashi troll city. Hakkar is the last boss.
• ]]..C.."Ruins of Ahn'Qiraj"..R..[[ — 20 players. The first of the two Qiraji raids.
• ]]..C.."Temple of Ahn'Qiraj"..R..[[ — 40 players. C'Thun is the last boss.
• ]]..C.."Naxxramas"..R..[[ — 40 players. The last raid, in the Plaguelands.

]]..C.."What to expect"..R..[[
• A raid night is long: several hours, with repairs and consumables to prepare.
• Many bosses are about tanks, healers and damage doing their jobs together, not about complicated mechanics.
• Lockouts: Molten Core, Blackwing Lair and Naxxramas reset weekly; Zul'Gurub and the Ahn'Qiraj ruins reset every three days; Onyxia every five.]] },

{ id = "raid-attune", group = "1. Before you go", title = "Attunements and keys", icon = "INV_Misc_Key_14",
  tags = "attunement key molten core onyxia blackwing lair naxxramas argent dawn",
  body = [[
Some raids need a quest chain before you may enter.

]]..C.."Molten Core"..R..[[
• Reach the Molten Core entrance in Blackrock Depths (through the Lyceum). The attunement is a quest started in Blackrock Depths; the guild or a friend can guide you in.

]]..C.."Onyxia's Lair"..R..[[
• A quest chain started by Lord Ironaya (Alliance) or Warchief Rend Blackhand's agent (Horde), ending with the Drakefire Amulet. You need level 60.

]]..C.."Blackwing Lair"..R..[[
• Obtain Blackhand's Command at Upper Blackrock Spire by killing the Warchief. Many raiders also finish the Molten Core attunement first.

]]..C.."Naxxramas"..R..[[
• Earn Honored with the Argent Dawn (a reputation you gain from the Plaguelands) for the entrance, and later Revered for the best rewards.

|cff888888Quest names and places are as in the original game; check the in-game quest text for the final word.|r]] },

{ id = "raid-bring", group = "1. Before you go", title = "What to bring to a raid", icon = "INV_Misc_Bag_10",
  tags = "bring consumables flask potion food buff repair reagents",
  body = [[
]]..C.."Always"..R..[[
• Repair your gear and keep a few gold for repairs after wipes.
• Food and a drink; a well-fed buff helps.
• Health and mana potions, a bandage, and a few bags free for loot.

]]..C.."For serious raiders"..R..[[
• Flasks (Supreme Power, Distilled Wisdom, Titans) and elixirs for your role.
• Fire Protection or Nature Protection potions for the right boss.
• Reagents (Ankh, Symbols, Soul Shards) for your class.

]]..C.."World buffs"..R..[[
• Rallying Cry of the Dragonslayer (Onyxia), Spirit of Zandalar (Zul'Gurub), Songflower Serenade (Felwood) and Warchief's Blessing / Slip'kik's Savvy (Dire Maul) help the whole raid. Ask your leader which ones to bring.]] },

{ id = "raid-roles", group = "2. In the raid", title = "Your job in a raid: tank, healer, damage", icon = "Ability_Warrior_DefensiveStance",
  tags = "roles tank healer dps damage threat aggro",
  body = [[
]]..C.."Tanks"..R..[[
• Hold the boss's attention (threat) and turn it away from the raid. A warrior is the most common main tank; druids and paladins help.
• Off-tanks pick up adds and extra bosses.

]]..C.."Healers"..R..[[
• Keep tanks up first, then the raid. Priests, druids, paladins and shamans heal; each has a role (a single-target healer, a chain healer, a decurser).
• Watch your mana and do not overheal when someone else already covered the damage.

]]..C.."Damage dealers"..R..[[
• Do the most damage you can without pulling threat off the tank. Wait a few seconds at the start of the fight.
• Interrupt, decurse, or kill adds when the leader asks.]] },

{ id = "raid-calls", group = "2. In the raid", title = "Raid language: pull, aggro, decurse, MC and more", icon = "INV_Misc_Note_01",
  tags = "language calls pull aggro threat decurse mc dispel mark kill order",
  body = [[
• ]]..C.."Pull"..R..[[ — the tank starts the fight. Do not attack before the pull.
• ]]..C.."Aggro / threat"..R..[[ — who the boss is attacking. If a damage dealer gets it, the boss can kill them.
• ]]..C.."Decurse / dispel"..R..[[ — remove a harmful effect from a player (mages, druids, priests, shamans).
• ]]..C.."MC"..R..[[ — Mind Control: a boss takes over a player; the group may need to polymorph or kill them.
• ]]..C.."Kill order"..R..[[ — the order adds should die in (marks on their heads).
• ]]..C.."Wipe"..R..[[ — everyone died; release, run back and buff again.]] },

{ id = "raid-leader", group = "2. In the raid", title = "Raid leader, markers and loot rules", icon = "Spell_Holy_PrayerOfHealing",
  tags = "leader assistant marker loot dkp loot council soft reserve roll",
  body = [[
• The leader decides when to pull and who tanks what. Raid markers show kill order and positions.
• ]]..C.."Loot rules"..R..[[ are set by the guild: roll (Need / Greed), DKP points, a loot council, or a soft-reserve list. Read the rules before the raid and never take loot that is not yours.
• Ready checks and a pull timer start fights together. Say it in chat if you need a bathroom break.]] },

{ id = "raid-wipes", group = "3. After the boss", title = "Wipes, resurrection and recovering", icon = "Spell_Holy_Resurrection",
  tags = "wipe recover res corpse ankh soulstone rebirth",
  body = [[
• After a wipe, run back from the graveyard and wait for the buffs and resurrections.
• Druids can use Rebirth in combat; shamans use Reincarnation; warlocks can set a Soulstone before the pull.
• Do not rush in alone: a second wipe costs the raid a lot of time and repairs.]] },

{ id = "raid-loot", group = "3. After the boss", title = "Loot and tokens", icon = "INV_Misc_Treasurechest02b",
  tags = "loot token tier set head legs reward",
  body = [[
• Bosses drop gear, plus tokens that turn into tier-set pieces at a vendor in the city.
• Raids give Lava Core, Fiery Core, Elementium and Qiraji items used by crafters; the guild may keep them for a project.
• Sell the extra items on the auction house or disenchant them; gold repairs add up in raids.]] },

{ id = "raid-class", group = "4. Tips by class", title = "What each class brings to a Classic raid", icon = "ClassIcon_Warrior",
  tags = "class bring buffs warrior paladin hunter rogue priest shaman mage warlock druid",
  body = [[
• ]]..C.."Warrior"..R..[[ — the main tank; Battle Shout; strong melee damage.
• ]]..C.."Paladin"..R..[[ — Blessings and Auras, heals, or tank help.
• ]]..C.."Hunter"..R..[[ — ranged damage, traps, tranquilizing shot, Aspect of the Wild.
• ]]..C.."Rogue"..R..[[ — high melee damage, stealth, lockpicking, Kick.
• ]]..C.."Priest"..R..[[ — heals, Power Word: Fortitude, Dispel Magic, Shadow Protection.
• ]]..C.."Shaman"..R..[[ — totems for the group, heals, Reincarnation, Purge.
• ]]..C.."Mage"..R..[[ — high ranged damage, Arcane Intellect, Remove Curse, food and water.
• ]]..C.."Warlock"..R..[[ — ranged damage, Healthstones, Soulstones, summon.
• ]]..C.."Druid"..R..[[ — Mark of the Wild, Rebirth, Innervate, heals or tank.]] },

{ id = "raid-mistakes", group = "4. Tips by class", title = "Common raid mistakes", icon = "INV_Misc_Wrench_01",
  tags = "mistakes avoid fail pull aggro afk repair",
  body = [[
• Pulling before the tank or the leader says so.
• Taking aggro from the tank.
• Standing in fire, poison or fear.
• No consumables and no repairs before the raid.
• Not reading the boss notes beforehand.
• Going AFK without telling the leader.
• Blaming others after a wipe.

Fix one habit per week. Raiders get better a little at a time.]] },

}

function ns:LoadRaidMplus()
    for i, a in ipairs(self.RAIDGUIDE) do
        self:Add({
            cat = "raidg", id = a.id, name = a.title, group = a.group,
            icon = "Interface\\Icons\\" .. (a.icon or "INV_Misc_Book_09"),
            sub = a.tags, tags = a.tags, body = a.body, order = i,
        })
    end
end
