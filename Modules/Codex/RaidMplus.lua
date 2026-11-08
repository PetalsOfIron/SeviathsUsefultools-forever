-- Seviath's Codex — Raiding Guide and Mythic+ Guide
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
{ id = "raid-what", group = "1. Before you go", title = "What a raid is and what to expect", icon = "Achievement_Boss_Ragnaros",
  tags = "raid what is expect first time difficulty lfr normal heroic mythic wing boss lockout length hours",
  body = [[
A raid is a big instance for many players, made of several bosses (often grouped in wings). You go through it boss by boss.

]]..C.."What to expect on a first raid night"..R..[[
• A raid night usually lasts two to four hours. Raid Finder runs are shorter.
• Raid leaders explain each boss before the first pull. Listen; the plan matters more than your damage.
• ]]..C.."Wipes are normal."..R..[[ A new boss can take many tries. Each try teaches the group something.
• Bosses have phases: the fight changes at set health or after set times. The leader names them ("phase two", "intermission").
• Waiting is part of it: a pause to explain, drink, repair and re-pull.
• You do not need to be perfect, but you need to follow the plan and stay alive.

]]..C.."Difficulties"..R..[[
• Raid Finder (LFR) — queue alone, easiest, many players, no group plan needed. A good first look.
• Normal and Heroic — you join a guild or a Premade group. Sizes are flexible (about 10 to 30 players).
• Mythic — a fixed number of players (20) and the hardest mechanics. Usually for organised groups.

Each boss gives loot once a week per difficulty (the lockout). The weekly reset is Wednesday in Europe, Tuesday in the Americas.

]]..NOTE },

{ id = "raid-facts", group = "5. Facts", title = "Raiding facts and history", icon = "INV_Misc_Book_11",
  tags = "raid facts history molten core 40 player flex lfr dragon soul challenge mythic 20 great vault tier set bosses",
  body = [[
• ]]..C.."Raiding is as old as the game."..R..[[ The first raids, Molten Core and Onyxia's Lair, came with the 2004 launch; Molten Core was for up to 40 players.
• ]]..C.."Raid Finder"..R..[[ arrived in the Dragon Soul patch of Cataclysm so that players without a guild could see the bosses.
• ]]..C.."Flexible raid sizes"..R..[[ (a group of any size within a range) arrived at the end of Mists of Pandaria.
• ]]..C.."Mythic raids"..R..[[ with a fixed 20 players arrived in Warlords of Draenor and replaced the old 10 and 25 player split.
• ]]..C.."A raid has several bosses"..R..[[ in a set order or in wings that open one after another. The first boss is the easiest, the last the hardest.
• ]]..C.."One kill per boss per difficulty per week."..R..[[ That is the lockout. A new week resets it.
• ]]..C.."Tier sets"..R..[[ are sets of armor pieces that drop as tokens in the raid. Wearing two and four pieces gives set bonuses.
• ]]..C.."The Great Vault"..R..[[ has raid slots that unlock by how many bosses you killed in a week.
• ]]..C.."Raid bosses have an enrage"..R..[[ — a timer after which they become far too strong.
• ]]..C.."A battle resurrection"..R..[[ is shared by the raid and refills slowly.
• ]]..C.."Raids take time"..R..[[: guilds raid several nights a week for months to clear the hardest difficulty.

|cff888888These are long-standing facts of the game; exact numbers can change.|r]] },

{ id = "raid-bring", group = "1. Before you go", title = "What to bring to a raid", icon = "INV_Misc_Bag_10",
  tags = "raid bring consumables flask food potion rune oil healthstone repair bags gems enchants talents addon boss mod voice",
  body = [[
Prepare before the ready check, not during it.

]]..C.."In your bags"..R..[[
• ]]..C.."Flask"..R..[[ — a long buff from alchemy; read the tooltip for how long it lasts.
• ]]..C.."Food"..R..[[ — eat for the Well Fed buff; a feast placed by a cook feeds the whole group.
• ]]..C.."Potions"..R..[[ — a health potion for emergencies and a combat potion for burst. Keep both on your bars. Each type has its own cooldown, so plan one per fight.
• ]]..C.."Weapon oil or rune"..R..[[ — small extra buffs if your group uses them.
• ]]..C.."Healthstone"..R..[[ — from a warlock; heals right away.
• ]]..C.."Bag space"..R..[[ — empty a few slots so loot never has to be left behind.
• ]]..C.."Repair"..R..[[ — repair before you go in. Deaths damage gear.

]]..C.."On your character"..R..[[
• ]]..C.."Talents"..R..[[ — a raid build, not your solo build. Most spec guides list a "raid" and a "Mythic+" loadout.
• ]]..C.."Gems and enchants"..R..[[ — every socket filled and every enchantable slot enchanted.
• ]]..C.."Action bars"..R..[[ — interrupt, defensive and potion on easy keys.

]]..C.."On your screen"..R..[[
• A boss mod addon (BigWigs or DBM) for timers and alerts, and the built-in boss timeline.
• Voice chat if your group uses it (headset on, mute when not talking).
• The raid frames visible, and your debuffs and cooldowns easy to see.

]]..C.."In your head"..R..[[
• The boss plan: the first minute, the big moves and what kills players.
• Which cooldown covers which part of the fight.
• Where you stand and when you move.]] },

{ id = "raid-know", group = "1. Before you go", title = "What to know about the boss before you pull", icon = "INV_Misc_Book_09",
  tags = "raid boss learn journal guide abilities phases mechanics video log preparation role plan",
  body = [[
Five minutes of reading saves many wipes.

1. ]]..C.."Open the Adventure Guide (Shift+J)"..R..[[ and read the boss in the Journal. Abilities carry role icons: tank, healer, damage.
2. ]]..C.."Find this boss in the Codex"..R..[[ (Bosses). It shows the abilities and the way in.
3. ]]..C.."Read a written guide for your role"..R..[[ (Wowhead, Icy Veins, Method). It lists the plan and the mistakes.
4. ]]..C.."Watch one short video"..R..[[ if you learn better that way. A good video shows positions and timing.
5. ]]..C.."Ask your leader"..R..[[ what the group will do differently from the guide (some groups change the strategy).

What to know about each boss:
• ]]..C.."Phases"..R..[[ — when the fight changes and what you do in each.
• ]]..C.."Deadly abilities"..R..[[ — the ones that kill if you stand wrong or miss a soak.
• ]]..C.."Your job"..R..[[ — tanks decide positions and swaps; healers plan cooldowns; damage dealers kill the right target and interrupt.
• ]]..C.."The enrage"..R..[[ — a timer after which the boss becomes too strong. It sets how fast you must kill.
• ]]..C.."Adds"..R..[[ — extra enemies that must die first, be stopped, or be avoided.]] },

{ id = "raid-lfr", group = "1. Before you go", title = "Raid Finder, Normal, Heroic and Mythic: where to start", icon = "INV_Misc_GroupNeedMore",
  tags = "raid finder lfr normal heroic mythic difficulty start ladder gear item level progression guild premade",
  body = [[
A good order for a new raider:

1. ]]..C.."Raid Finder"..R..[[ — queue alone, learn the bosses and their looks, and collect gear. You do not need a plan.
2. ]]..C.."Normal"..R..[[ — join a group that explains each boss. Gear from Raid Finder helps.
3. ]]..C.."Heroic"..R..[[ — harder mechanics and better gear. Groups often have a plan and expect you to know it.
4. ]]..C.."Mythic"..R..[[ — 20 players, tight mechanics and no room for mistakes; usually a guild with a schedule.

Tips:
• Do not skip Raid Finder; it is a free tour of the bosses.
• Say you are new when you join a group; most will help.
• Item level is a guide, not a rule. Skill matters more.
• Raid in a group you enjoy. A friendly guild is worth more than a fast one.
• Check the Group Finder listing for what a group expects (item level, experience, a voice chat).

]]..NOTE },

{ id = "raid-roles", group = "2. In the raid", title = "Your job in a raid: tank, healer, damage", icon = "Ability_Warrior_DefensiveStance",
  tags = "raid role tank healer damage positioning cooldown assignment interrupt dispel soak adds",
  body = [[
]]..C.."Tanks"..R..[[ — hold the boss, face it away from the group, and swap when the boss puts a stacking debuff on the tank (the other tank takes over). Call your cooldowns and watch for stacks. Pick up adds.

]]..C.."Healers"..R..[[ — keep the raid up, with an assigned cooldown for dangerous moments (the leader or a plan tells you which). Dispel what must be dispelled. Spend mana so you do not run out before the boss dies.

]]..C.."Damage dealers"..R..[[ — kill the right target: the boss, a marked add, or a group of adds, as the plan says. Use interrupts and stops on dangerous casts. Move out of bad effects and keep dealing damage while you move. Save big cooldowns for the right phase or for bloodlust.

]]..C.."Everyone"..R..[[
• Stand where the plan says (melee behind the boss, ranged spread, healers within range).
• Follow call-outs: stack, spread, soak, move.
• Use your personal defensives before the raid needs to save you.
• Stay alive. A dead player does no damage and cannot soak.
• Do not stand in anything on the floor. It is nearly always bad.]] },

{ id = "raid-calls", group = "2. In the raid", title = "Raid language: stack, spread, soak, kite and more", icon = "INV_Misc_Note_01",
  tags = "raid call out stack spread soak kite swap adds phase intermission enrage bait dispel cleave tank buster glossary",
  body = [[
Words you will hear in raid chat and voice:

• ]]..C.."Stack"..R..[[ — stand close together to share damage or healing.
• ]]..C.."Spread"..R..[[ — stand apart so an area attack hits few players.
• ]]..C.."Soak"..R..[[ — stand in a circle or marker so its damage is shared instead of killing one player.
• ]]..C.."Swap"..R..[[ — the second tank takes over the boss.
• ]]..C.."Tank buster"..R..[[ — a big hit on the tank; the tank uses a defensive.
• ]]..C.."Cleave / cone"..R..[[ — an attack in front of the boss; do not stand there.
• ]]..C.."Adds"..R..[[ — extra enemies. "Kill adds" means target them first.
• ]]..C.."Kite"..R..[[ — keep moving so a slow enemy never reaches you.
• ]]..C.."Bait"..R..[[ — stand somewhere on purpose so a later effect lands where it can do no harm.
• ]]..C.."Dispel / cleanse"..R..[[ — remove a harmful effect from a player.
• ]]..C.."Interrupt / stop"..R..[[ — end a cast with a kick or a stun.
• ]]..C.."Phase / intermission"..R..[[ — a part of the fight and a short pause between parts.
• ]]..C.."Enrage"..R..[[ — the point after which the boss kills everyone.
• ]]..C.."Burst"..R..[[ — a window to use your strongest abilities.
• ]]..C.."CD"..R..[[ — cooldown. "Use your CD" means use a defensive or raid cooldown.
• ]]..C.."Pull"..R..[[ — start the fight. A pull timer counts down.
• ]]..C.."Wipe"..R..[[ — everyone died. The raid resets and tries again.]] },

{ id = "raid-leader", group = "2. In the raid", title = "Ready checks, markers, pull timers and assignments", icon = "Spell_Holy_PrayerOfHealing",
  tags = "raid ready check marker pull timer assignment leader voice chat announce readycheck raid frame setup",
  body = [[
• ]]..C.."Ready check"..R..[[ — the leader asks if everyone is ready. Click Ready only when you are repaired, buffed, potted and at your spot.
• ]]..C.."Pull timer"..R..[[ — a countdown (often from a boss mod, for example /pull 10). Do not start before zero.
• ]]..C.."Raid markers"..R..[[ — icons on targets and the floor. The leader gives them; everyone reads them the same way. /tm 8 sets a skull on your target.
• ]]..C.."Assignments"..R..[[ — who kicks, who soaks, who takes adds, which healer covers which cooldown. A note in chat or a screen usually lists them. Read it; if you do not understand, ask.
• ]]..C.."Voice chat"..R..[[ — keep quiet during the fight unless you have a call. Short, calm calls are best.
• ]]..C.."Raid frames"..R..[[ — keep them visible and sorted by role. Many players use Edit Mode to place them.
• ]]..C.."If you are the leader"..R..[[ — give one clear plan at a time, keep pulls fast after a wipe, and thank the group at the end.]] },

{ id = "raid-timing", group = "2. In the raid", title = "Cooldowns, bloodlust and potion timing in raids", icon = "Spell_Nature_Bloodlust",
  tags = "raid cooldown bloodlust heroism time warp burst potion pre pot external defensive timing plan phase",
  body = [[
• ]]..C.."Bloodlust"..R..[[ — use it at the start for short fights or when most players have their big cooldowns up in longer fights. The leader names the moment ("lust on pull" or "lust at 40%").
• ]]..C.."Pre-potion"..R..[[ — a combat potion used just before the pull starts its boost for the first burst. A second potion can be used later when the cooldown is back.
• ]]..C.."Personal burst"..R..[[ — use it every time it comes back unless the next phase starts soon.
• ]]..C.."Raid cooldowns"..R..[[ — healers and some classes have a group-wide defensive. A plan assigns each one to a dangerous moment so they do not overlap.
• ]]..C.."External defensives"..R..[[ — some classes protect another player; call for one if you are targeted by something big.
• ]]..C.."Use abilities on time"..R..[[ — a plan with timers (a screen or the boss mod) tells you when. Learn it by repeating the fight.
• ]]..C.."Do not hold cooldowns forever"..R..[[ — a cooldown unused at the end of a fight is wasted.]] },

{ id = "raid-wipes", group = "2. In the raid", title = "Wipes, battle resurrection and recovering", icon = "Spell_Holy_Resurrection",
  tags = "raid wipe battle res combat resurrection recover release ghost run back repair progress attempt",
  body = [[
A wipe is part of progress.

• ]]..C.."During a fight"..R..[[ — a death is not the end if the group has a battle resurrection. The charges are shared by the whole raid and refill slowly. Use them on important players (healers, tanks) at important moments, not on the first death.
• ]]..C.."After a wipe"..R..[[ — click Release Spirit and run back, or accept a resurrection from a player who survived. In many raids you can use the spirit healer or a graveyard near the entrance.
• ]]..C.."Repair when you can"..R..[[ — many wipes in a row break gear. Use a repair bot, vendor or your own repair item.
• ]]..C.."Listen to the post-mortem"..R..[[ — the leader says what went wrong; fix one thing at a time.
• ]]..C.."Do not blame players."..R..[[ If it is you, say "my mistake, fixed" and move on.
• ]]..C.."Count the attempts"..R..[[ — if the group is not improving, change the plan, swap players or take a break.
• ]]..C.."Check your logs"..R..[[ — Warcraft Logs and a damage meter show your deaths and missed mechanics.]] },

{ id = "raid-tank", group = "4. Tips by role", title = "Tank tips: needed, expected, avoid, annoying", icon = "Ability_Warrior_DefensiveStance",
  tags = "raid tank tips needed expected avoid annoy swap cooldown positioning pull timer boss facing add pickup",
  body = [[
]]..C.."What you need"..R..[[
• A tank spec with your defensives and a taunt on easy keys.
• The boss plan: where to hold the boss, which way to face it and when to swap.
• A clear view of your health, your debuff stacks and the other tank.

]]..C.."What is expected"..R..[[
• Hold the boss and the adds, and keep them away from the group.
• Swap on time and call your cooldowns.
• Lead the pace between bosses and say when you pull.
• Tell the raid when a plan changes.

]]..C.."What to avoid"..R..[[
• Facing the boss toward the group so cones hit everyone.
• Taking a stacking debuff too far without the swap.
• Wasting a defensive early, then having none for the big hit.
• Moving the boss while melee are mid-fight without a call.

]]..C.."What annoys other players"..R..[[
• Pulling before the raid is ready.
• Moving the boss around with no warning.
• Silence when something goes wrong.
• Blaming others for a death caused by a swap that came late.]] },

{ id = "raid-healer", group = "4. Tips by role", title = "Healer tips: needed, expected, avoid, annoying", icon = "Spell_Holy_PrayerOfHealing",
  tags = "raid healer tips needed expected avoid annoy cooldown mana dispel assignment overheal tank raid",
  body = [[
]]..C.."What you need"..R..[[
• Raid frames you can read and click fast.
• A healing plan: which cooldown for which moment.
• Dispels on a key and a mana plan for the whole fight.

]]..C.."What is expected"..R..[[
• Keep the tanks alive first, then the raid.
• Use your assigned cooldown at the right moment, and say when you do.
• Dispel what must be dispelled quickly.
• Stand in range and out of bad effects.

]]..C.."What to avoid"..R..[[
• Running out of mana before the boss is dead.
• Healing players who are not in danger while the tank falls.
• Using all cooldowns at once.
• Standing in bad effects because you are watching the bars.

]]..C.."What annoys other players"..R..[[
• Not dispelling when asked.
• Asking for more healing without saying what happened.
• Leaving the raid at the first wipe.
• Being out of range of the group.]] },

{ id = "raid-dps", group = "4. Tips by role", title = "Damage tips: needed, expected, avoid, annoying", icon = "Ability_Marksmanship",
  tags = "raid damage dps tips needed expected avoid annoy interrupt add target swap cooldown move aoe single",
  body = [[
]]..C.."What you need"..R..[[
• A raid build and your rotation on your bars.
• An interrupt and a defensive on easy keys.
• The target list: boss, adds and the order.

]]..C.."What is expected"..R..[[
• Do your job first, then your damage: soak, interrupt, kill the add, stand where the plan says.
• Use your cooldowns on time and with bloodlust.
• Keep damage up while you move.
• Know your role in the call-outs.

]]..C.."What to avoid"..R..[[
• Standing in bad effects.
• Pulling threat from the tank by starting early.
• Chasing numbers instead of mechanics.
• Wasting a cooldown just before a phase change.

]]..C.."What annoys other players"..R..[[
• Dying early and needing a battle resurrection.
• Missing interrupts and soaks.
• Taking an add assigned to someone else.
• Blaming the tank or healer after your own death.
• Leaving without a word.]] },

{ id = "raid-classes", group = "4. Tips by role", title = "What each class brings to a raid", icon = "ClassIcon_Warrior",
  tags = "raid class utility buff bloodlust battle res raid composition brings classes",
  body = CLASSES },

{ id = "raid-loot", group = "3. After the boss", title = "Loot, the Great Vault and weekly reset", icon = "INV_Misc_Treasurechest02b",
  tags = "raid loot personal loot great vault tier set token catalyst trade two hours lockout reset boe weekly",
  body = [[
• ]]..C.."Personal loot"..R..[[ — in most groups each boss gives each player their own chance. You are not competing with the group for drops.
• ]]..C.."Trading"..R..[[ — loot you won can be traded to a group member who can use it for a short time (about 2 hours) if it is not an upgrade for you.
• ]]..C.."Tier set pieces"..R..[[ — your set (usually head, shoulders, chest, hands, legs) drops as tokens for your armor type. Wearing two and four pieces gives set bonuses. The Groups page of this addon lists which token fits which armor type.
• ]]..C.."Great Vault"..R..[[ — the raid row fills as you kill bosses; you pick one item after reset.
• ]]..C.."Lockout"..R..[[ — one kill per boss per difficulty per week. A new week resets it.
• ]]..C.."Bind-on-Equip"..R..[[ — some drops can be sold on the Auction House. Check the price before you vendor.
• ]]..C.."Upgrading"..R..[[ — raid gear can be upgraded at the upgrade vendor with crests. Spend them on pieces you keep.
• ]]..C.."Catalyst"..R..[[ — a system that converts an item into a tier-style piece. It is limited each week.

]]..NOTE },

{ id = "raid-manners", group = "3. After the boss", title = "Being a good raider: habits and manners", icon = "Achievement_Character_Human_Male",
  tags = "raid manners etiquette attendance prepared communicate feedback loot council guild raid leader respect",
  body = [[
• ]]..C.."Be on time"..R..[[ and ready. Prepared players make fast raids.
• ]]..C.."Know the plan."..R..[[ If you do not, ask before the pull.
• ]]..C.."Communicate"..R..[[ — say when you must leave, need a break or are having a problem.
• ]]..C.."Accept feedback"..R..[[ and give it kindly. Ask "what could I do better?".
• ]]..C.."Do not stand in bad things,"..R..[[ do not pull early, do not take loot meant for someone else.
• ]]..C.."Respect the loot rules."..R..[[ Ask before you roll on something a guild member may need.
• ]]..C.."Share"..R..[[ — consumables, tips, and a kind word after a hard fight.
• ]]..C.."Take breaks"..R..[[ — a tired player makes mistakes.
• ]]..C.."Leave nicely"..R..[[ — tell the leader before you go.]] },

{ id = "raid-mistakes", group = "3. After the boss", title = "Common raid mistakes", icon = "INV_Misc_Wrench_01",
  tags = "raid mistakes common errors afk pull early missing consumables not reading standing in fire dying early",
  body = [[
• Arriving without consumables, repairs or the right talents.
• Not reading the boss before the first pull.
• Standing in the red area on the ground.
• Pulling before the timer ends.
• Using a big cooldown too early, then having nothing when it matters.
• Wasting a battle resurrection on a player who will die again at once.
• Not following the call-outs because you are watching your own bars only.
• Taking an add that someone else was assigned to.
• Chasing damage numbers instead of doing your job.
• Going AFK without telling the leader.
• Blaming others after a wipe.

Fix one habit per week. Raiders get better a little at a time.]] },

}

ns.MPGUIDE = {
------------------------------------------------------------------------
{ id = "mp-how", group = "1. Basics", title = "How a Mythic+ run works, step by step", icon = "INV_Relics_Hourglass",
  tags = "mythic plus m+ keystone how it works timer enemy forces boss chest upgrade depleted weekly",
  body = [[
1. ]]..C.."Get a keystone"..R..[[ — finishing a Mythic dungeon (and the weekly reset) gives you one. It names a dungeon and a level.
2. ]]..C.."Form a group"..R..[[ — 1 tank, 1 healer, 3 damage dealers. Use Premade Groups, friends or a guild.
3. ]]..C.."Start the key"..R..[[ — put the keystone in the font at the dungeon entrance. A countdown starts and the timer begins when you move in.
4. ]]..C.."Fill the enemy bar"..R..[[ — you must kill enough enemies to reach 100% enemy forces. Bosses must also die.
5. ]]..C.."Beat the timer"..R..[[ — each dungeon has a time limit. Deaths add time.
6. ]]..C.."Open the chest"..R..[[ — loot waits at the end. Higher keys give better loot.
7. ]]..C.."The key changes"..R..[[ — if you finish in time your key goes up (more if you finish early); if not it stays or goes down.
8. ]]..C.."Weekly rewards"..R..[[ — your best runs fill the dungeon row of the Great Vault.

]]..C.."Words"..R..[[: a ]]..C.."timed"..R..[[ key is finished inside the limit; ]]..C.."depleted"..R..[[ means over time (you still get loot); ]]..C.."rating"..R..[[ is your score from the best run in each dungeon.

]]..NOTE },

{ id = "mp-facts", group = "5. Facts", title = "Mythic+ facts and history", icon = "INV_Misc_Book_11",
  tags = "mythic plus facts history legion challenge mode keystone affix weekly vault death penalty rating timer",
  body = [[
• ]]..C.."Mythic+ came with Legion"..R..[[ (2016). It grew out of the Challenge Modes of Mists of Pandaria.
• ]]..C.."A group is always five players:"..R..[[ one tank, one healer, three damage dealers.
• ]]..C.."Keys start at +2"..R..[[ and go up without a fixed top; each level makes enemies stronger.
• ]]..C.."Every dungeon has its own timer."..R..[[ Deaths add time.
• ]]..C.."Enemy forces"..R..[[ is a bar to 100% that every key needs.
• ]]..C.."Affixes change"..R..[[ from week to week; some are seasonal and some rotate.
• ]]..C.."Each season"..R..[[ uses a set of dungeons that can be run as keys; older dungeons rotate in and out.
• ]]..C.."The Great Vault"..R..[[ has a dungeon row that unlocks by how many runs you finish in a week.
• ]]..C.."A rating"..R..[[ shows your best result in each dungeon and appears in the Group Finder.
• ]]..C.."Timed keys at high levels unlock teleports"..R..[[ to their dungeon for the season.
• ]]..C.."A battle resurrection"..R..[[ is shared by the group.
• ]]..C.."Season goals"..R..[[ give titles, mounts and cosmetics.

|cff888888Long-standing facts; exact numbers change with each season.|r]] },

{ id = "mp-bring", group = "2. Prepare", title = "What to bring to a Mythic+ key", icon = "INV_Misc_Bag_10",
  tags = "mythic plus bring consumables flask food potion healthstone defensive interrupt repair keystone addon",
  body = [[
]]..C.."Items"..R..[[
• ]]..C.."Flask and food"..R..[[ — a flask lasts a long time and costs less than a death. Food gives a stat buff.
• ]]..C.."Potions"..R..[[ — a health potion and a combat potion on your bars.
• ]]..C.."Healthstone"..R..[[ — from a warlock; heals at once.
• ]]..C.."Repair"..R..[[ — fix your gear before you start; deaths break it.
• ]]..C.."Your keystone"..R..[[ — keep it in your bags. Bring a spare if the group asks.

]]..C.."Character"..R..[[
• ]]..C.."A dungeon talent loadout"..R..[[ — many enemies at once, mobility and interrupts.
• ]]..C.."Defensives and an interrupt"..R..[[ on easy keys.
• ]]..C.."Gems and enchants"..R..[[ — full.

]]..C.."Screen"..R..[[
• ]]..C.."A boss mod"..R..[[ (BigWigs with LittleWigs, or DBM) for the dungeon bosses.
• ]]..C.."A key timer"..R..[[ (the game has one; some addons add a clearer one).
• ]]..C.."Nameplates"..R..[[ with cast bars so you can see what to kick.

]]..C.."Mind"..R..[[
• The dungeon's route and bosses (see "Learn a dungeon fast").
• The affixes of the week.
• Your part: kick, stop, soak, dispel, defensive timing.]] },

{ id = "mp-expect", group = "1. Basics", title = "What to expect in a key", icon = "INV_Misc_Note_01",
  tags = "mythic plus expect pace time length fast group strangers chat pulling death leave key level",
  body = [[
• ]]..C.."Pace"..R..[[ — a key is fast. Most groups pull big and keep moving. A run takes about half an hour or more, depending on the dungeon and the level.
• ]]..C.."Pulls"..R..[[ — several groups at once. The tank decides. Follow the tank.
• ]]..C.."Silence is normal"..R..[[ — many groups do not talk. Short messages in chat are welcome, such as "kick Boss", "defensive used" or "need a drink".
• ]]..C.."Deaths"..R..[[ — each death costs time. One or two do not ruin a run; many do.
• ]]..C.."Interrupts"..R..[[ — in higher keys a missed interrupt can wipe the group. Kick on time.
• ]]..C.."Strangers"..R..[[ — most players are decent. If someone is rude, finish or leave, then use "Report".
• ]]..C.."A bad key"..R..[[ — sometimes a run fails. Learn from it and queue again.
• ]]..C.."Key level"..R..[[ — start low so you can learn the dungeon, and go up when it feels easy.

]]..NOTE },

{ id = "mp-before", group = "2. Prepare", title = "What to know before your first key", icon = "INV_Misc_Book_09",
  tags = "mythic plus first key know learn dungeon route boss interrupt affix preparation checklist",
  body = [[
A checklist for the first key:

1. ]]..C.."Gear"..R..[[ — your item level should match the dungeon's suggested level or a little above for the key level.
2. ]]..C.."Know the dungeon"..R..[[ — read a route guide (Wowhead, Icy Veins, Method) and watch a run. The Codex shows the bosses.
3. ]]..C.."Know the affixes"..R..[[ — read this week's affixes in the Mythic+ window.
4. ]]..C.."Know your kicks"..R..[[ — the list of casts you must interrupt or stop.
5. ]]..C.."Know the bosses"..R..[[ — what each does and what kills the group.
6. ]]..C.."Pick the right group"..R..[[ — join "learning" or low keys first.
7. ]]..C.."Say it"..R..[[ — "first time in this dungeon" is welcome and saves wipes.
8. ]]..C.."Settle your keys"..R..[[ — talk with the group about who starts.]] },

{ id = "mp-learn", group = "2. Prepare", title = "Learn a dungeon fast", icon = "INV_Misc_Book_11",
  tags = "mythic plus learn dungeon route guide boss video journal practice normal heroic mythic zero",
  body = [[
1. ]]..C.."Run it on Normal or Heroic first"..R..[[ so you know the layout.
2. ]]..C.."Read a route guide"..R..[[ for the key level you want (Icy Veins, Method, Wowhead).
3. ]]..C.."Open the Codex"..R..[[ for the bosses and their abilities.
4. ]]..C.."Mark the dangerous casts"..R..[[ you must kick or avoid.
5. ]]..C.."Watch one run"..R..[[ at your key level on video.
6. ]]..C.."Run it a few times"..R..[[ at a low key. Repetition beats theory.
7. ]]..C.."Ask the group"..R..[[ about their route; many have a copy-pasted plan.]] },

{ id = "mp-affixes", group = "2. Prepare", title = "Affixes: how to read and use them", icon = "INV_Misc_Note_06",
  tags = "mythic plus affix fortified tyrannical week rotation season rule seasonal strategy",
  body = [[
]]..C.."Affixes"..R..[[ are extra rules added to a key. They change from week to week and from season to season.

• Read them at the keystone or in the Mythic+ window before you start.
• ]]..C.."Fortified"..R..[[ and ]]..C.."Tyrannical"..R..[[ alternate: one makes ordinary enemies stronger, the other makes bosses and their helpers stronger. Plan big pulls or boss time accordingly.
• Higher keys add more affixes. Your defensives and interrupts matter more.
• Each season adds its own affixes and rules. A guide for the season explains them.
• Use affix guides (Icy Veins, Wowhead, Method) for the current rotation.

]]..NOTE },

{ id = "mp-group", group = "1. Basics", title = "Finding a group and applying", icon = "INV_Misc_GroupNeedMore",
  tags = "mythic plus group finder premade apply note role rating key level invite leader create listing",
  body = [[
• ]]..C.."Open the Group Finder (I)"..R..[[ and the Premade Groups tab for Mythic+.
• ]]..C.."Choose your key"..R..[[ — a key level near your skill. Do not start high.
• ]]..C.."Apply with a note"..R..[[ — "learning" and "will listen" help. If you are new to the dungeon, say so.
• ]]..C.."Create your own group"..R..[[ — use your keystone, name the dungeon and level, and write what you need.
• ]]..C.."Roles"..R..[[ — tanks and healers are asked for most. If you can play one, queue for it.
• ]]..C.."Your rating"..R..[[ shows on your application. A low rating is fine at low keys.
• ]]..C.."Use friends and guilds"..R..[[ — they are the most reliable groups.
• ]]..C.."Leaving"..R..[[ — leaving a key early costs the group. Only leave if you must, and say so.]] },

{ id = "mp-roles", group = "3. During the run", title = "Roles in a key: tank, healer, damage", icon = "Ability_Warrior_DefensiveStance",
  tags = "mythic plus role tank healer damage pull size route mark interrupt dispel defensive cc kick bloodlust",
  body = [[
]]..C.."Tank"..R..[[ — plans the route and the pull size, marks the first target, and keeps enemies on you. Use defensives early. Pull only when the healer and damage dealers are ready. Do not pull a group the group cannot kill.

]]..C.."Healer"..R..[[ — keep the tank up, then everyone. Use dispels and defensives. Drink between pulls. Ask for a break if you run low.

]]..C.."Damage"..R..[[ — kill the marked target first; use your area damage on big pulls; keep damage-over-time effects on many targets; use your kick on dangerous casts; use your defensives before health is low.

]]..C.."Everyone"..R..[[
• Stand out of bad effects.
• Use bloodlust on a boss or a very big pull.
• Say what you used ("kick used", "stop on cooldown").
• Use the battle resurrection on a player who matters (a healer or a tank).]] },

{ id = "mp-route", group = "3. During the run", title = "Routes, enemy forces and pulling", icon = "INV_Misc_Map02",
  tags = "mythic plus route enemy forces percent count pull skip pack priority must kill boss line of sight pull corner",
  body = [[
• ]]..C.."Enemy forces"..R..[[ — a bar from 0 to 100%. Different enemies are worth different amounts. You do not need to kill all of them.
• ]]..C.."Route"..R..[[ — a plan of which groups to pull and in what order so you reach 100% with the least time. Routes are shared in guides.
• ]]..C.."Pull size"..R..[[ — bigger pulls are faster but need more healing and damage. Grow your pulls as the group gets better.
• ]]..C.."Pull to a corner"..R..[[ — casters come to you and fight in one place.
• ]]..C.."Avoid extra packs"..R..[[ — a patrol or an extra group can wipe you.
• ]]..C.."Skip when you can"..R..[[ — some groups can be skipped with stealth, invisibility or a shortcut. Learn which with a guide and tell the group.
• ]]..C.."Mark and plan the kills"..R..[[ — mark the kick target, the crowd-controlled one and the one to kill first.
• ]]..C.."Finish the bar before the last boss"..R..[[ — otherwise you must clear extra enemies at the end.
• ]]..C.."Watch the timer"..R..[[ — if you are behind, make bigger pulls and use bloodlust; if you are ahead, be careful.]] },

{ id = "mp-interrupts", group = "3. During the run", title = "Interrupts, stops and crowd control in keys", icon = "Ability_Kick",
  tags = "mythic plus interrupt kick stop crowd control priority list assignment stun cooldown lockout dispel",
  body = [[
In keys, kicks decide runs.

• ]]..C.."Make a priority list"..R..[[ — a route guide lists the casts that must be stopped. Learn them.
• ]]..C.."Share the work"..R..[[ — say who kicks which enemy ("I kick the left one"). Without a plan, kicks overlap.
• ]]..C.."Use stops"..R..[[ — stuns, knockbacks and silences also end a cast. Use them when the kick is on cooldown.
• ]]..C.."Remember the cooldowns"..R..[[ — a kick returns after a short wait. The next kick belongs to someone else.
• ]]..C.."Use crowd control"..R..[[ — mark which enemy is crowd-controlled and do not break it.
• ]]..C.."Dispels"..R..[[ — remove effects that hurt players or enemies' buffs (some classes can).
• ]]..C.."Look at the cast bar"..R..[[ — an uninterruptible cast shows differently; stop it with a stun or avoid it.

|cff888888Which casts must be stopped differs for each dungeon. Read the dungeon's guide before the key.|r]] },

{ id = "mp-tank", group = "4. Tips by role", title = "Tank tips: needed, expected, avoid, annoying", icon = "Ability_Warrior_DefensiveStance",
  tags = "mythic plus tank tips needed expected avoid annoy pull size route mark defensive lust",
  body = [[
]]..C.."What you need"..R..[[
• The route and the pull sizes for the dungeon and the key level.
• Your defensives and a plan for each big hit.
• A way to mark the kill target and the interrupt order.

]]..C.."What is expected"..R..[[
• Lead the pace and say what comes next.
• Pull sizes the group can kill.
• Pick up loose enemies and keep them off the healer.
• Tell the group when you use a defensive or need a break.

]]..C.."What to avoid"..R..[[
• Pulling before the healer has mana.
• Pulling more than the group can handle just to be fast.
• Skipping marks and then not saying anything.
• Running far ahead of the group.

]]..C.."What annoys other players"..R..[[
• No warning before a big or sudden pull.
• Pulling extra enemies by accident.
• Leaving the group behind with no word.
• Blaming the healer for a death caused by a pull that was too big.]] },

{ id = "mp-healer", group = "4. Tips by role", title = "Healer tips: needed, expected, avoid, annoying", icon = "Spell_Holy_PrayerOfHealing",
  tags = "mythic plus healer tips needed expected avoid annoy mana dispel cooldown tank defensive kick",
  body = [[
]]..C.."What you need"..R..[[
• A dungeon loadout with healing on movement and a dispel.
• Your cooldowns and a plan for the big hits.
• Mana for the whole run: drink between pulls.

]]..C.."What is expected"..R..[[
• Keep the tank up first and heal the group.
• Dispel the effects that must be removed.
• Use your group cooldown on dangerous pulls and bosses.
• Say when you need a drink or a break.

]]..C.."What to avoid"..R..[[
• Healing players who are not in danger while the tank drops.
• Running out of mana mid-pull.
• Using all cooldowns on the first pull.
• Standing in bad effects.

]]..C.."What annoys other players"..R..[[
• Silence when mana is low and the pull goes on.
• Not dispelling something that hurts the group.
• Leaving after the first death.
• Asking for slower pulls without saying why.]] },

{ id = "mp-dps", group = "4. Tips by role", title = "Damage tips: needed, expected, avoid, annoying", icon = "Ability_Marksmanship",
  tags = "mythic plus damage dps tips needed expected avoid annoy interrupt kick area single target defensive death",
  body = [[
]]..C.."What you need"..R..[[
• A dungeon loadout with area damage and mobility.
• An interrupt on an easy key and a defensive.
• The list of casts that must be stopped.

]]..C.."What is expected"..R..[[
• Do your job first: kick, stop, soak, dispel.
• Kill the marked target first.
• Use your area damage on big pulls and single-target on bosses.
• Use your defensives early.

]]..C.."What to avoid"..R..[[
• Missing an interrupt and wiping the group.
• Dying to avoidable damage.
• Pulling extra enemies by running ahead.
• Wasting cooldowns on a pull that is almost dead.

]]..C.."What annoys other players"..R..[[
• Going ahead of the tank.
• Not saying when the kick is on cooldown.
• Blaming the tank or healer for your own death.
• Leaving after a bad pull.]] },

{ id = "mp-classes", group = "4. Tips by role", title = "What each class brings to a key", icon = "ClassIcon_Warrior",
  tags = "mythic plus class utility buff bloodlust battle res composition brings classes",
  body = CLASSES },

{ id = "mp-rewards", group = "6. After the key", title = "Rewards: the chest, the Vault, rating and keys", icon = "INV_Misc_Treasurechest02b",
  tags = "mythic plus rewards chest great vault rating key level depleted upgrade timed teleport title mount season",
  body = [[
• ]]..C.."End chest"..R..[[ — gives gear; better with a higher key level. A depleted key still gives loot.
• ]]..C.."The key"..R..[[ — a timed key gives you a higher key; a depleted one gives you the same or a lower one. Finishing early can raise it by more than one level.
• ]]..C.."Great Vault"..R..[[ — the dungeon row fills as you complete more runs in a week; the item level depends on the key levels you finished.
• ]]..C.."Rating"..R..[[ — each dungeon keeps your best run. Total rating shows on your profile and in the Group Finder.
• ]]..C.."Teleports and rewards"..R..[[ — timing a high enough key unlocks a teleport spell to that dungeon, and season goals give mounts and titles.
• ]]..C.."Crests and upgrades"..R..[[ — a key gives crests that you spend to upgrade gear.

]]..NOTE },

{ id = "mp-manners", group = "6. After the key", title = "Etiquette and mistakes to avoid", icon = "Achievement_Character_Human_Female",
  tags = "mythic plus etiquette manners mistakes leave rude blame ready check drink thank report group",
  body = [[
]]..C.."Etiquette"..R..[[
• Be ready and repaired when you join.
• Greet the group; say "ready" at the ready check.
• Wait for the tank before you pull.
• Say what happens ("drink please", "kick used").
• Thank the group at the end.

]]..C.."Mistakes"..R..[[
• Pulling alone or too early.
• Missing interrupts.
• Standing in bad areas.
• Wasting the battle resurrection.
• Blaming players after a death.
• Leaving the group early.
• Taking a key much too high for your skill.
• Arriving without consumables or repairs.

Fix one habit per run. Keys get easier quickly when you do.]] },

}

function ns:LoadRaidMplus()
    for i, a in ipairs(self.RAIDGUIDE) do
        self:Add({
            cat = "raidg", id = a.id, name = a.title, group = a.group,
            icon = "Interface\\Icons\\" .. (a.icon or "INV_Misc_Book_09"),
            sub = a.tags, tags = a.tags, body = a.body, order = i,
        })
    end
    for i, a in ipairs(self.MPGUIDE) do
        self:Add({
            cat = "mpg", id = a.id, name = a.title, group = a.group,
            icon = "Interface\\Icons\\" .. (a.icon or "INV_Misc_Book_09"),
            sub = a.tags, tags = a.tags, body = a.body, order = i,
        })
    end
end
