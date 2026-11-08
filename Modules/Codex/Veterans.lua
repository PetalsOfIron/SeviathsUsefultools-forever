-- Seviath's Codex — Veteran Tips: things long-time players often do not know
-- Written for this addon (CC BY-NC 3.0). Things experienced players know and most do not. Evergreen on purpose; numbers and menu names
-- move between patches, so the pages say to check the game.

local ADDON, ns = SFP_Module("Codex")
local C = "|cffffd100"
local R = "|r"

ns.VETERAN = {
------------------------------------------------------------------------
{ id = "vet-queue", group = "1. Combat mechanics", title = "The spell queue and the global cooldown", icon = "Ability_Warrior_Charge",
  tags = "spell queue gcd global cooldown latency spellqueuewindow clipping cast time instant channel cancel timing",
  body = [[
Most players press the next button after the last one finishes. Experienced players press it ]]..C.."a little early"..R..[[:

• The game ]]..C.."queues"..R..[[ the next ability if you press it shortly before the global cooldown or the current cast ends. It then fires at the first possible moment, with no gap. Mash lightly, do not wait.
• The length of that window is a setting called ]]..C.."SpellQueueWindow"..R..[[ (in milliseconds). The command /console SpellQueueWindow 100 makes it shorter; a bigger value is more forgiving on a slow connection. If you change it, change it by small steps and watch for abilities that fire when you did not want them.
• ]]..C.."Cast on key press"..R..[[ (see "Key and mouse tricks") removes the small delay of waiting for the key to come up.
• ]]..C.."Channeled spells"..R..[[ can often be cancelled or refreshed near the end without losing the last tick; the spell's tooltip and your spec guide tell you the best moment.
• Use ]]..C.."instant abilities while moving"..R..[[ and save cast-time abilities for when you stand still.
• Watch your ]]..C.."latency"..R..[[: a high World delay means a queue gap that no setting fully fixes.

|cff888888Check the current default of the queue window in your game; it has been changed before.|r]] },

{ id = "vet-dots", group = "1. Combat mechanics", title = "Damage over time: refresh windows (pandemic)", icon = "Spell_Shadow_ShadowWordPain",
  tags = "dot hot refresh pandemic window clipping uptime snapshot haste ticks bleed periodic",
  body = [[
A ]]..C.."DoT"..R..[[ (damage over time) or ]]..C.."HoT"..R..[[ (healing over time) refreshed too early wastes its remaining time. Many of them have a ]]..C.."pandemic window"..R..[[: if you refresh in the last part of the duration (about the last 30%), the leftover time is added to the new one and nothing is lost.

• Refresh inside the window, not before it, and not after it ends.
• ]]..C.."Uptime"..R..[[ matters most for strong DoTs: keeping one running all fight is worth more than a perfectly timed single cast.
• ]]..C.."Haste"..R..[[ makes ticks faster but makes the whole effect end sooner in many specs; your spec guide says how it works for you.
• Some effects ]]..C.."snapshot"..R..[[ your stats when you apply them. Applying them while your buffs are up can raise the damage of the whole DoT. This depends on the class, so read your spec guide.
• In a fight with many targets, a DoT on each target usually beats a big single-target ability. Check the "many targets" part of your spec guide.

|cff888888Exact windows and snapshot rules change by spec and patch. The tooltip and the current spec guide are the final word.|r]] },

{ id = "vet-interrupt", group = "1. Combat mechanics", title = "Interrupts, stops and crowd control in depth", icon = "Ability_Kick",
  tags = "interrupt kick lockout stop cc crowd control diminishing returns dr stun root silence uninterruptible incapacitate immune",
  body = [[
• ]]..C.."An interrupt locks the school"..R..[[ of the spell for a few seconds, so the enemy cannot cast that kind of spell. Plan the kicks: the same pack can cast several schools.
• ]]..C.."Some casts cannot be interrupted"..R..[[. The cast bar shows it (a different colour or a shield). A stop or a crowd control effect works instead.
• ]]..C.."A kick that is on cooldown"..R..[[ can be replaced by a stun, silence or knockback. Know which of your abilities stop a cast.
• ]]..C.."Diminishing returns (DR)"..R..[[ — the same kind of crowd control (stun, root, silence, incapacitate, fear and so on) gets shorter each time and then stops working. The count resets after a short while (around 18 seconds). Use different kinds in a row.
• ]]..C.."Bosses are often immune"..R..[[ to stun, fear and other control effects. The tooltip or the Journal tells you; a "does nothing" message is the sign.
• ]]..C.."Break lines of sight"..R..[[ — casters need a clear line to you. A corner or pillar makes them walk to you.
• ]]..C.."Coordinate"..R..[[: say "I kick first, you kick second" in chat. Without a plan three players waste the same kick.

|cff888888Check each spell's tooltip; interrupt types and DR groups differ by class.|r]] },

{ id = "vet-pathing", group = "2. Dungeons and Mythic+", title = "Pulling, pathing and line of sight", icon = "INV_Misc_Map02",
  tags = "pull pathing line of sight leash evade reset corner patrol skip stealth route mythic plus dungeon",
  body = [[
• ]]..C.."Pull to a corner."..R..[[ Casters and ranged enemies run to you around a wall, and fight in one place. This is the most common trick for big pulls.
• ]]..C.."Pull away from the other packs"..R..[[ so a second group does not join. Check for patrols before you pull.
• ]]..C.."Leashing"..R..[[ — enemies that are pulled too far from where they stand reset and heal. Use this to avoid chasing a mob, but not to reset a boss you are winning.
• ]]..C.."Stand in a spot that the whole group can reach"..R..[[ and keep healers out of the line of the tank's cleave.
• ]]..C.."Mark the pack"..R..[[ (kill order and crowd control) before you pull. A marked pack dies faster.
• ]]..C.."Skips"..R..[[ — some groups can be avoided with stealth, an invisibility effect or a shortcut. Learn which in the dungeon's guide; do not try them without telling the group.
• ]]..C.."Use pull timers"..R..[[: most boss mods have a command like /pull 10 that starts a countdown so all pull together.
• ]]..C.."The tank decides"..R..[[ the route. Follow the pace, and say when you need a drink.]] },

{ id = "vet-mplus", group = "2. Dungeons and Mythic+", title = "Mythic+: the timer, the count and the deaths", icon = "INV_Relics_Hourglass",
  tags = "mythic plus timer enemy forces count percent deaths penalty keystone upgrade route chest time",
  body = [[
• ]]..C.."Enemy forces"..R..[[ — you must kill enough enemies to fill a bar to 100%. Not every enemy is needed; you can skip many and fill the bar with big packs. A good route picks the packs that give the most percent for the least time.
• ]]..C.."Deaths cost time"..R..[[ — each death adds a time penalty to the run. A death in the first pull is worse than a slow pull. Defensive abilities and potions are cheaper than a death.
• ]]..C.."Upgrade size"..R..[[ — finishing well inside the timer upgrades the key by more than one level; finishing late can still complete it for loot but may lower or keep the key.
• ]]..C.."Bosses"..R..[[ — the boss fight is part of the timer; a boss that is killed quickly is worth more than ten extra trash enemies.
• ]]..C.."Combat resurrection"..R..[[ — in a dungeon the charges are shared, so use them on bosses and dangerous pulls.
• ]]..C.."Know the dungeon"..R..[[ — a route guide for each dungeon (Wowhead, Method, Icy Veins) is the fastest way to improve. Many groups paste a shared route.
• ]]..C.."Affixes change what matters"..R..[[ — read them before the key and adapt (more mobile pulls, more defensives).

|cff888888Penalty size, upgrade thresholds and affixes change each season. The Mythic+ window and the Adventure Guide show the current values.|r]] },

{ id = "vet-cooldowns", group = "2. Dungeons and Mythic+", title = "Planning cooldowns and bloodlust", icon = "Spell_Nature_Bloodlust",
  tags = "cooldown plan bloodlust heroism time warp external defensive burst phase raid cooldown rotation",
  body = [[
• ]]..C.."Bloodlust"..R..[[ — use it when the most players have their big cooldowns up, or at the start of a fight when it is short. Do not use it on trash that dies in seconds.
• ]]..C.."Burst windows"..R..[[ — enemies take extra damage in some phases. Hold your strongest abilities for them when the next window is soon, and use them right away if it is far away.
• ]]..C.."Raid cooldowns"..R..[[ — healers and some damage classes have group-wide defensives. Call them out ("cooldown on 3") so they cover the dangerous mechanics one after another instead of all at once.
• ]]..C.."External defensives"..R..[[ — some classes can protect another player. Tanks and players targeted by a big hit should be covered; say when you need it.
• ]]..C.."Pre-potion"..R..[[ — a potion used just before the pull starts its short boost for the first burst.
• ]]..C.."Know the fight timers"..R..[[ — the Journal and your boss mod show when the dangerous parts come.
• ]]..C.."Use abilities when they come back"..R..[[ unless a guide tells you to wait for a phase.]] },
{ id = "vet-macros", group = "3. Macros and controls", title = "Macros: the few lines that change everything", icon = "INV_Misc_Note_06",
  tags = "macro mouseover focus modifier showtooltip castsequence stopmacro cast use cursor conditional",
  body = [[
Open macros with /macro. A macro is a short list of commands. The few ideas below cover most of what players use.

• ]]..C.."#showtooltip"..R..[[ on the first line shows the icon and tooltip of the ability the macro uses.
• ]]..C.."Mouseover"..R..[[ — /cast [@mouseover,help,nodead] Heal casts a heal on the player under your mouse, without changing your target. The same works for interrupts and dispels on the enemy or ally you point at.
• ]]..C.."Focus"..R..[[ — /cast [@focus] Interrupt uses your interrupt on your focus target. Set the focus with /focus.
• ]]..C.."Modifiers"..R..[[ — /cast [mod:shift] Ability1; Ability2 uses Ability1 when Shift is held and Ability2 otherwise.
• ]]..C.."At the cursor"..R..[[ — /cast [@cursor] Ability places a ground spell where the mouse points.
• ]]..C.."Fallbacks"..R..[[ — conditions go in square brackets; the first one that is true is used. [@mouseover,help,nodead][] means "mouseover if friendly and alive, else my target".
• ]]..C.."Use items"..R..[[ — /use Item Name or /use 13 (a trinket slot) puts a potion or trinket on a button.
• ]]..C.."Stop a macro"..R..[[ — /stopmacro [conditions] ends the macro early, for example when you are not in combat.

Macros cannot play the game for you: they cannot press many abilities in a loop, and the game will not let them. See "What not to use".]] },

{ id = "vet-slash", group = "3. Macros and controls", title = "Useful slash commands", icon = "INV_Letter_15",
  tags = "slash command reload played readycheck rolecheck follow focus startattack stopcasting roll who invite camp logout dump fstack",
  body = [[
Type these in the chat box:

• ]]..C.."/reload"..R..[[ — reloads the interface. Fixes most addon glitches.
• ]]..C.."/played"..R..[[ — shows how long this character has played.
• ]]..C.."/readycheck"..R..[[ and ]]..C.."/rolecheck"..R..[[ — ask the group if they are ready, or to confirm their roles.
• ]]..C.."/roll"..R..[[ — rolls 1 to 100 (/roll 20 rolls 1 to 20).
• ]]..C.."/follow"..R..[[ — follows your target. ]]..C.."/focus"..R..[[ and ]]..C.."/clearfocus"..R..[[ set and clear your focus.
• ]]..C.."/startattack"..R..[[ and ]]..C.."/stopcasting"..R..[[ — useful inside macros.
• ]]..C.."/who name"..R..[[ — finds a player; ]]..C.."/invite name"..R..[[ invites them.
• ]]..C.."/logout"..R..[[ and ]]..C.."/camp"..R..[[ — leave the world (you log out after a short wait).
• ]]..C.."/fstack"..R..[[ — shows which interface frame is under your mouse. Useful when an addon looks wrong and you want to know whose it is.
• ]]..C.."/console scriptErrors 1"..R..[[ — shows error details (0 hides them).

Addons often add their own slash commands; this addon uses /sut and /sfp.]] },

{ id = "vet-controls", group = "3. Macros and controls", title = "Key and mouse tricks many players miss", icon = "INV_Misc_Gear_01",
  tags = "keybind cast on key press self cast focus cast modifier mouse shift click ctrl click dressing room link chat reply",
  body = [[
• ]]..C.."Cast on key press"..R..[[ — in the Options (search "press") you can make an ability fire when the key goes down, not when it comes up. Many players say it feels faster.
• ]]..C.."Self-cast and focus-cast keys"..R..[[ — in the Options (search "self cast" and "focus") you can hold a key to cast a friendly spell on yourself or on your focus.
• ]]..C.."Shift+click an item or link"..R..[[ puts it in the chat box. Do it on an item in your bags, the Auction House or the Adventure Guide.
• ]]..C.."Ctrl+click an item"..R..[[ shows it on your character in the dressing room.
• ]]..C.."R"..R..[[ answers the last whisper. ]]..C.."Enter"..R..[[ opens the chat box.
• ]]..C.."Mouse buttons"..R..[[ can be bound to abilities in Options » Keybindings, so a mouse with side buttons gives extra keys.
• ]]..C.."Bar paging"..R..[[ — extra action bars and modifier-swapped bars give you many more buttons without a bigger screen.
• ]]..C.."Interact key"..R..[[ — bind it and talk to NPCs and loot with one key.
• ]]..C.."Shift+click at a vendor"..R..[[ lets you choose how many of an item to buy, instead of one at a time.
• ]]..C.."Ignore a bag when you sort"..R..[[ — right-click a bag icon and choose the option to ignore it for clean-up, so your bag of keepsakes stays as it is.
• ]]..C.."Target markers"..R..[[ — /tm 8 puts a skull on your target, /tm 0 clears it. Put it on a macro button to mark quickly.
• ]]..C.."Camera distance"..R..[[ — the command /console cameraDistanceMaxZoomFactor 2.6 lets you zoom further out. Some interface updates reset console settings, so retype it if it stops working.
• ]]..C.."Nameplate range"..R..[[ — /console nameplateMaxDistance 60 shows enemy nameplates further away. This also can reset.

|cff888888Menu names move between patches. Use the search box at the top of the Options window.|r]] },

{ id = "vet-changed", group = "6. For returning players", title = "Systems that replaced the old ones", icon = "INV_Misc_Book_09",
  tags = "changed old new talents covenant titanforging upgrade tracks warband skyriding crafting orders renown veteran returning old system",
  body = [[
If you remember older versions of the game, these are the biggest differences:

• ]]..C.."Talents"..R..[[ — class, spec and hero talent trees with loadouts replaced the old fixed trees. You can import a build as text.
• ]]..C.."Gear"..R..[[ — upgrade tracks and crests replaced random item level jumps. The tooltip shows the track and the rank (for example 2/6).
• ]]..C.."Flying"..R..[[ — Skyriding is the dynamic flying style; classic flying is called Steady Flight.
• ]]..C.."Professions"..R..[[ — crafted items have quality levels, knowledge trees and crafting orders; many players buy items from crafters instead of making them.
• ]]..C.."Reputation"..R..[[ — renown tracks (account-wide for many factions) replaced the old grind of reputation.
• ]]..C.."Warband"..R..[[ — mounts, pets, toys, appearances, the Warband bank and gold are shared across your characters.
• ]]..C.."Delves and Prey"..R..[[ — solo-friendly content with companions and weekly rewards.
• ]]..C.."Housing"..R..[[ — decor collecting, neighborhoods and endeavors.
• ]]..C.."Addons"..R..[[ — rotation helpers and combat triggers were limited; see "Addons in Midnight" and "Rotation helpers".

Old guides that mention any of the old systems as current are out of date.]] },

{ id = "vet-ah", group = "4. Gold and loot", title = "Auction House details veterans miss", icon = "INV_Misc_Coin_02",
  tags = "auction house commodity unit price deposit cancel listing duration stack sell buy minimum",
  body = [[
• ]]..C.."Commodities and items"..R..[[ — stackable goods (herbs, ore, cloth, potions) are commodities: you buy by unit price and the cheapest units are bought first. Gear and other unique items are listed one by one.
• ]]..C.."The deposit"..R..[[ — you pay a deposit when you list. If the item sells, it is returned; if you cancel, you can lose it. A longer listing time costs a bigger deposit.
• ]]..C.."The cut"..R..[[ — the house takes 5% of the sale price.
• ]]..C.."Check the quantity, not the lowest price"..R..[[ — a very cheap listing may be one unit. Look at how many units are on offer at each price before you undercut.
• ]]..C.."Realms"..R..[[ — the Auction House is shared by connected realms only. Prices from another realm are not your prices; this addon says which realm a price came from.
• ]]..C.."Buy materials in the morning, sell before raid nights"..R..[[ — demand for flasks, potions and food follows raid and key schedules.

|cff888888Use your own Auction House as the final word, not a list from the web.|r]] },

{ id = "vet-gold-loot", group = "4. Gold and loot", title = "Loot and trade details", icon = "INV_Misc_Bag_09",
  tags = "loot trade two hours personal loot need greed bind boe warbound vendor value transmog loot",
  body = [[
• ]]..C.."Personal loot"..R..[[ — in most groups each player gets their own chance at loot, so you do not compete for drops.
• ]]..C.."Trade window for loot"..R..[[ — gear you won in a dungeon or raid can be traded to a group member who could use it for a short time (about 2 hours) if it is not an upgrade for you.
• ]]..C.."Bind-on-Equip pieces"..R..[[ — check the Auction House before you vendor them. Old raid pieces can be worth a lot.
• ]]..C.."Warbound"..R..[[ items can be sent to your own characters through the Warband bank, but not to other players.
• ]]..C.."Vendor value is not the real value"..R..[[ — many items sell for far more on the Auction House than a vendor pays.
• ]]..C.."Transmog from loot"..R..[[ — an item you cannot use can still unlock its appearance for the whole account; look at the tooltip line "not collected yet".
• ]]..C.."Mail"..R..[[ — mail between your own characters arrives at once; use it to move gold and items.]] },

{ id = "vet-gear-habits", group = "5. Habits of good players", title = "Habits experienced players share", icon = "Ability_Warrior_StrengthOfArms",
  tags = "habits veteran tips preparation consumables weakauras interrupt mark read ability journal stack ready check",
  body = [[
• ]]..C.."Read the boss before you pull."..R..[[ The Adventure Guide and the Codex show every boss ability with a role icon. Five minutes there saves a wipe.
• ]]..C.."Prepare before the ready check."..R..[[ Repair, food, flask, potion and the right talent loadout. Veterans never ask for the ready check to wait.
• ]]..C.."Keep one extra interrupt key."..R..[[ A focus macro lets you kick without clicking.
• ]]..C.."Say what you are doing."..R..[[ A short "Pulling in 5", "Need a drink" or "Battle res used" keeps the group calm.
• ]]..C.."Learn a second role."..R..[[ A player who can tank or heal never waits long for a group.
• ]]..C.."Clean your bags weekly."..R..[[ Move gold, mats and old gear to the Warband bank or the Auction House.
• ]]..C.."Use the Alt Overview"..R..[[ of this addon to see what your characters carry before you buy or craft more.
• ]]..C.."Keep an eye on the calendar."..R..[[ Events, Timewalking and bonus weeks are free power.
• ]]..C.."Be kind to new players."..R..[[ Everyone started with no idea what a "key" was.]] },
}

function ns:LoadVeterans()
    for i, a in ipairs(self.VETERAN) do
        self:Add({
            cat = "vet", id = a.id, name = a.title, group = a.group,
            icon = "Interface\\Icons\\" .. (a.icon or "INV_Misc_Book_09"),
            sub = a.tags, tags = a.tags, body = a.body, order = i,
        })
    end
end
