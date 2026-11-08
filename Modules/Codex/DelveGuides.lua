-- Seviath's Codex — per-delve guides (Midnight)
-- Written in our own words from Method.gg delve guides (2026). Locations are
-- zone + coordinates; the live map data in Delves.lua overrides them when found.

local ADDON, ns = SFP_Module("Codex")

ns.DELVE_GUIDES = {
["collegiate calamity"] = {
    zone = "Silvermoon City", x = 0.4076, y = 0.5406, where = "Center of Silvermoon City, inside a building.",
    variants = {
        { "Invasive Glow", "Talk to Bloomkeeper Thornflare and take the Grimgrow Deweeder (extra button, instantly kills Weedlings at short range). Kill 70 Weedlings, then fill the bar by killing Lightbloom enemies and popping 5 Luminbulbs with the Deweeder (they leave damaging circles). Boss: Hydrangea." },
        { "Academy Under Siege", "Talk to Thalandri Fatesinger. Student Projects (books/scrolls) give one-use abilities like fireballs or shields. Activate the 4 Arcane Wards. Boss: Voidscorned Vagrant." },
        { "Faculty of Fear", "Talk to Celonus Blackflame for the Eye of Revelation (extra button that reveals disguised enemies). Reveal and kill disguised enemies to fill the bar — you must reveal some, there aren't enough normal mobs. Boss: Infiltrator Garand." },
    },
    trash = {
        "Radiant Chloromancer — interrupt Blooming Shield (big absorb) when nothing more dangerous is casting.",
        "Thornblade — stacking disease DoT; kill fast or dispel.",
        "Stumpspreader (elite) — Blooming Bile frontal cone: sidestep.",
        "Domnaar Enforcer — step out of its circle.",
        "Controlled Slaughterclaw (elite) — Seismic Stomp leaves circles: spread out; hits hard.",
        "Shadowguard Phaseblade — Corporal Cleave frontal: sidestep.",
        "Twilight Ogre Mage — interrupt Sullen Shadow Bolt (ignore normal Shadow Bolt).",
        "Umbral Skullcrasher — interrupt Sacrificial Aegis (absorb).",
        "Shadowburn Vortex — interrupt Malicious Ray.",
    },
    bosses = {
        { "Hydrangea (Invasive Glow)", "Summon Wildwood Weed roots you and spawns a Weed — interrupt the Weed's channel to break the root. Move out of Lightbloom Salvo. Stand on knocked-out NPCs to heal them; they do most of the work. Root + Salvo is what kills you." },
        { "Voidscorned Vagrant (Academy Under Siege)", "Move out of Void Eruption circles. Interrupt Terrifying Power (fear) — Valeera does it if she's on Damage. Revive knocked-out NPCs fast." },
        { "Infiltrator Garand (Faculty of Fear)", "Spread for Twilight Crash. Shadow Laceration is a magic DoT — dispel, or set Valeera to Healer. Stand in the purple circle on each captured NPC to free them (it hurts — use a defensive); once freed the boss melts." },
    },
},
["the darkway"] = {
    zone = "Silvermoon City", x = 0.3931, y = 0.3207, where = "Silvermoon City north docks, on a boat (the delve itself is set in the Arcway).",
    variants = {
        { "Focusers Under Pressure", "Inspect the Shattered Ley Line crystals, collect 6 new crystals around the delve, bring them back to the entrance and place them. Then the boss." },
        { "Leyline Technician", "Talk to Technician Mireile and click leylines around the delve to fill the bar; the route ends at the boss." },
        { "Ogre Powered", "Interact with Infiltrator Gulkar, then kill 7 Unstable Aberrations — interrupt their Arcane Deluge (Valeera on Damage does it). Then the boss." },
    },
    trash = {
        "Shadowtaint Anomaly (elite) — Arcane Slicer beam at one player: sidestep, even in melee.",
        "Spellshield Collaborator — Spell Reflection: don't throw big spells or DoTs into it.",
        "Shadowfuse Sentinel (elite) — interrupt Discharge (huge circle); move out of Mystic Blast puddles.",
    },
    bosses = {
        { "Twilight Gulkat", "Stay out of the Abyssal Burst frontal cone. Illusory Deceit summons 5-6 adds with purple circles that follow you and explode — don't attack them, just be outside their circles when they finish. Interrupt Shadow Bolt. Fight in a big open space." },
    },
},
["the shadow enclave"] = {
    zone = "Eversong Woods", x = 0.4555, y = 0.8631, where = "South Eversong Woods, in a hard-to-spot cave.",
    variants = {
        { "Mirror Shine", "Darkness fills the delve. Pick up mirrors and drop them (extra button) to point light at 6 Shadow Nexus and destroy them. Light in the open gives Dazzled (+25% damage taken). Fighting while carrying a mirror drops it." },
        { "Traitor's Due", "Kill enemies to destroy 2 void focuses, then 3 more — each spawns an elite. Lure the elite into the Eyes of Antenorian beams to kill it fast." },
        { "Shadowy Supplies", "Talk to Doleana and collect 30 supplies from the ground and from enemies." },
    },
    special = "Eyes of Antenorian: floating eyes that fire a heavy frontal beam with knockback. Avoid them — but the beam hits enemies too, so use it on elites.",
    trash = {
        "Twilight Ogre Mage — interrupt Sullen Shadow Bolt.",
        "Umbral Skullcrasher — interrupt Sacrificial Aegis (absorb).",
        "Shadowburn Vortex — interrupt Malicious Ray.",
    },
    bosses = {
        { "Lord Antenorian", "Hardest delve boss. Interrupt Shadow Bolt (defensive if you miss). He teleports and leaves a puddle on the path — step out. Annihilation is a one-shot: he shields himself and 2 of 3 orbs — kill the unshielded orb, which unshields the next, until all are dead; that breaks his shield, stops the cast and stuns him. Use cooldowns for the orbs, keep Valeera alive (she does big orb damage) and keep him in the middle of the room." },
    },
},
["the grudge pit"] = {
    zone = "Harandar", x = 0.7030, y = 0.6714, where = "South-east Harandar.",
    variants = {
        { "Lightbloom Invasion", "Free 6 entangled fighters and kill 8 Lightbloom attackers (one side at a time). Defend 2 barricades. Then 3 untargetable Thornmaws roam — kill enemies for barrels and click a barrel to remove each Thornmaw. Boss: Brightthorn." },
        { "Arena Champion", "Kill enemies to fill the bar (clicking big single mobs makes them flee, still counts). Kill Bogdamp (interrupt his casts) and Moldrus. Collect mold samples from defeated Moldering Fighters — standing in mold makes it explode. Boss: Gyrospore." },
        { "Dastardly Rootstalks", "Put on the mask, defeat 6 Fan Favourites (sidestep their cone) and punt 8 small Fungarians. Stand in a moving spotlight and taunt (extra button) to pull Angry Fans and kill them. Dig up 8 competitors from dirt piles (getting hit interrupts the dig — use crowd control). Click Boletus. Boss: Mycomight." },
    },
    trash = {
        "Radiant Chloromancer — interrupt Blooming Shield when free.",
        "Thornblade — stacking disease; kill fast or dispel.",
        "Stumpspreader (elite) — frontal cone: sidestep.",
        "Fungal Gutter — interrupt Battle Cry (25% haste to allies) in big packs.",
        "Gnarled Reviver / Fungal Rotcaster — interrupt Rotten Bolt.",
        "Fungal Rotspreader — avoid its mushrooms.",
        "Fungal Speartender (elite) — sidestep Spear Vine line; interrupt Battle Cry.",
    },
    bosses = {
        { "Brightthorn (Lightbloom Invasion)", "Solar Charge leaves puddles — fight at the edge and bait charges into walls. Look away from him during Binding Burst. Interrupt Thorn Burst." },
        { "Gyrospore (Arena Champion)", "Sidestep Fungal Charge. During Fungistorm he spins and chases someone — run; afterwards he's dizzy and takes 25% more damage: use cooldowns then." },
        { "Mycomight (Dastardly Rootstalks)", "Very punishing on high tiers. Rancid Rain: green circles on everyone drop puddles — move to the edge so the middle stays clean. The Fungal's Fist frontal + 5 projectiles stun for 3 sec — dodge wide, the hitboxes are bigger than they look. Fling Chair disorients. Keep him in the center." },
    },
},
["the gulf of memory"] = {
    zone = "Harandar", x = 0.4536, y = 0.5134, where = "West Harandar, in caves under the area near the portal.",
    variants = {
        { "Alnmoth Munchies", "Talk to Ashyao; the extra button collects pollen and damages enemies. Fill the bar. Boss: Lumenia." },
        { "Descent of the Haranir", "Kobolds: light 8 candles (outside candlelight you take +25% damage, enemies too). Nerubians: free 8 Haranir from webs, avoid the big patrolling elite. Abominations: kill enemies to fill the bar. Boss: Mul'tha'ul." },
        { "Sporesaurous Surprise", "Kill 3 Sporesaurous elites one at a time — stand in the ground circles to bounce spores back and break their shield (each circle stacks a debuff on you). Fill the bar. Boss: Lumenia." },
    },
    special = "Sapstick Lurkers: standing in their ground circles yanks you up and stuns you. You can kite enemies through them instead.",
    trash = {
        "Radiant Chloromancer — interrupt Blooming Shield when free.",
        "Thornblade — stacking disease; kill fast or dispel.",
    },
    bosses = {
        { "Lumenia", "Command Light summons a slow add that hits very hard — kite it, don't attack it (kite it through floor zones). Floor circles disorient unless you face away, then stay as stun zones — face away and don't step in. Clear space and keep her in the middle." },
        { "Mul'tha'ul", "Move out of tentacle slams. Interrupt Hopelessness (curse DoT + slow) as often as you can, decurse if it lands. Unanswered Call fixates you for 8 sec — kite with a movement skill. Keep him central." },
    },
},
["parhelion plaza"] = {
    zone = "Isle of Quel'Danas", x = 0.4774, y = 0.4158, where = "Isle of Quel'Danas, west of the Sunwell, downstairs inside a building.",
    variants = {
        { "March of the Arcane Brigade", "Fill the bar by killing Devouring Host enemies and destroy 3 Void Pylons — activate the Sentinels around the area and they destroy the pylons. Circle the outer edge." },
        { "Holding the Line", "Pick 2 weapons (best: Cosmic Infuser for everyone; then Warp Slicer for melee, Netherstrand Longbow for ranged). Repair 8 barriers and kill Devouring Host. Boss appears on the center platform." },
        { "Bombing Run", "Grab a bomb at the entrance, enter a portal, kill the mobs, use the bomb to destroy the portal (don't leave before, or it closes). Repeat for every portal." },
    },
    trash = {
        "Domnaar Enforcer — step out of its circle.",
        "Controlled Slaughterclaw (elite) — spread for Seismic Stomp; hits hard.",
        "Shadowguard Phasehunter — Corporal Cleave frontal: sidestep.",
    },
    bosses = {
        { "Gladius Slaurna", "Fairly hard even on low tiers. Kill the Sacrificial Void Callers fast (interruptible, immune to CC). Voidscar Raze is a beam toward the farthest target (often Valeera) — keep adds out of it, each add it eats gives him +10% damage. Devouring Nova knocks back (stay away from the edge) and also eats live adds for +10% each. When he's low and your cooldowns are up, ignore adds and burn him." },
    },
},
["twilight crypts"] = {
    zone = "Zul'Aman", where = "South-west Zul'Aman, hidden in troll ruins.",
    variants = {
        { "Loosed Loa", "Talk to Scout Lok'aemon and take the Evasive Elixir (turns you into a pot for 4 sec: immune to Mot'amra). The Loa rampages through the middle and stuns whatever it hits — let it hit enemies. Kill Vilebranch Skeleton Charmers and destroy 6 Hex Totems." },
        { "Party Crasher", "Talk to Dulgor Legstuck (stuck in a trap). Kill 4 Twilight Summoners (marked on the map) and click 7 suspicious levers." },
        { "Trapped", "Free the hostages held by the Twilight's Blade — the first key teleports you to the southern room; open every side room. Boss fights in a small room near the entrance." },
    },
    special = "Spear traps block routes (small damage + knockback). Levers switch them off.",
    trash = {
        "Hexbound Necrowraith — interrupt Necrotic Bolt; leave the Necromantic Upheaval circles before the cast ends.",
        "Fleshwarped Abomination (elite) — after Ghoulish Strength it hits twice as hard but is slowed: kite it (tanks can ignore). Stun/CC its Reconstitution heal (can't be interrupted).",
        "Leering Skulltaker — Hex Strike lowers all your stats by 5%; careful pulling several.",
    },
    bosses = {
        { "Blademaster Darza", "Stay close — she only Charges ranged players. Sidestep Shade Cleave (frontal locked to a spot). Bask in Twilight makes a circle around her: get out, it leaves puddles. On high tiers drag her to the room's edge and circle the walls during each Bask." },
    },
},
["atal'aman"] = {
    zone = "Zul'Aman", x = 0.6378, y = 0.8015, where = "West Zul'Aman, near the Eversong Woods border.",
    variants = {
        { "Toadly Unbecoming", "Troll Ritual items give buffs (e.g. 30% haste). Talk to Kasha for the Vilebranch Hexstick. Fill the bar by killing mobs, then use the hexstick on 20 Cursed Frogs. Avoid the Giant Cursed Bullfrog's Venom Bite." },
        { "Totem Annihilation", "A captured Loa drops lightning circles — stay out and don't kite mobs into them. Destroy 6 totems and fill the bar by killing Witherbark trolls." },
        { "Ritual Interrupted", "Click weapon racks for Haunted Weapons that fight for you. Talk to Furbolg Fleek, free the Spiritclaw Cubs, then clear the enemy waves at Nalorakk's shrine." },
    },
    trash = {
        "Hexbound Necrowraith — interrupt Necrotic Bolt; leave Necromantic Upheaval circles.",
        "Fleshwarped Abomination (elite) — kite after Ghoulish Strength; stun/CC its Reconstitution heal.",
        "Leering Skulltaker — Hex Strike lowers all stats by 5%.",
    },
    bosses = {
        { "Spiritflayer Jin'ma", "Flayed Knife puts a circle on everyone and spawns 3 souls — step out, wait for the circle to end, then run over the souls (+10% damage for you each). If a soul dies uncollected, he gets +10% instead. Collect Souls can't be interrupted — grab them first with movement skills. Fight in an open area." },
    },
},
["shadowguard point"] = {
    zone = "Voidstorm", x = 0.3738, y = 0.4774, where = "West Voidstorm.",
    variants = {
        { "Calamitous", "Kill Guard Captain Meti at the entrance. Fill the bar and destroy Void Stabilizers: run over the Arcane orbs, then step into a Stabilizer's circle. Destroyed Stabilizers leave stunning void zones — kite enemies into them, don't get caught." },
        { "Stolen Mana", "Talk to Lysikas for the Galvanic Rifle (extra button). Free 8 captives from Mana Siphoners and shoot mana barrels (small 1%, big 3% and a knockback circle you can kite mobs through)." },
        { "Captured Wildlife", "Free caged wildlife early (they fight for you). Fill the bar, then use the Worm Bait on the 4 shielded Void Researchers to kill them instantly." },
    },
    trash = {
        "Shadowguard Phasehunter — Corporal Cleave frontal; don't pull several at once.",
        "Shadowguard Soulbreaker — interrupt Soul Siphon (heals it).",
        "Shadowguard Steelsoul — big shield; after it breaks it pulses damage. Move out of Arcane Geyser circles and kill it fast.",
    },
    bosses = {
        { "Chief-Arcanist Patram", "Keep moving during Discordant Hymn (ground circles). Interrupt Submit to the Void as LATE as possible. Dark Communion summons a Dark Harbinger — kill it at once: killing it gives you 20% Versatility and faster cooldowns; if it survives its 15-sec Dark Prayer, Patram gets stronger." },
    },
},
["sunkiller sanctum"] = {
    zone = "Voidstorm", x = 0.5478, y = 0.4727, where = "Voidstorm, deep ravine just north of the Void Spire raid entrance.",
    variants = {
        { "Core of the Problem", "Talk to Null-Theorist Selune: collect 50 Cores from enemies while filling the bar. Singularity Portals teleport you around — fastest variant." },
        { "Not What I Expected", "Talk to Darkmender Deremius Duskwalk. Click 7 Lightbloom Crates, activate the Sanctum Security Panel, fill the bar. Displacement Portals give a helper clone for ~5 min. Instead of the boss you fight 3 Corrupted Umbraroots — pull one at a time." },
        { "The Gravitational Effect", "Talk to Riftblade Maella. Micro Singularities let you fly and stealth briefly. Collect 5 Singularity Coils, fill the bar, place coils in 5 stabilizers to start the boss." },
    },
    trash = {
        "Domnaar Enforcer — step out of its circle.",
        "Controlled Slaughterclaw (elite) — spread for Seismic Stomp.",
        "Shadowguard Phasehunter — frontal cleave: sidestep.",
        "Corrupted Umbraroot (variant 2) — dodge Blooming Bile cone and Rotting Charge; interrupt Lightbloom Beam.",
    },
    bosses = {
        { "Esuritus", "One of the easier bosses. Step out of Crushing Rift around him. Interrupt Singular Bolt (Valeera on Damage helps). Kill the summoned adds fast and dodge their debris — Gorge eats live adds for +5% damage each." },
    },
},
["torment's rise"] = {
    zone = "Voidstorm", where = "South-east Voidstorm, just north of Obscurion Citadel.",
    variants = {
        { "Nemesis delve (Season 1)", "Only boss is Nullaeus. Tier 8 (about ilvl 255) and Tier 11 (about 274). He can also appear randomly in any Tier 8+ delve, or be summoned with the Beacon of Hope." },
    },
    trash = {
        "Razorshell Ravagers (at 75%) — sidestep Spiny Leap; move during Jagged Rip to dodge the bleed. Kill fast.",
        "Spitting Ticks (at 50%) — 7 adds with stacking poison: crowd control + AoE, defensives if needed.",
        "Enslaved Voidcaster (at 25%) — immune to CC; interrupt only its first cast, then save interrupts for Nullaeus and ignore it.",
    },
    bosses = {
        { "Nullaeus", "Interrupt EVERY Emptiness of the Void (can one-shot you). Dispel Devouring Essence (magic DoT). Stay out of the Void Zone (a third of the room, moves each time). Black Hole bounces around and pulls you — save movement skills for it. Phases at 75/50/25% add the trash above; at the end use all cooldowns and burn him.\nValeera: melee/tanks set her to Healer (dispels + bleed); healers set her to Damage (she interrupts).\nRewards: My Shady Nemesis; Tier 11 = The Ominous title; solo Tier 11 = Let Me Solo Him: Nullaeus + Arcanovoid Construct mount." },
    },
},
}

local C = ns.CYAN
function ns:DelveGuideText(e)
    local g = self.DELVE_GUIDES[(e.name or ""):lower()]
    if not g then return nil end
    local out = {}
    if g.where then out[#out + 1] = C .. "Location|r\n" .. g.where end
    if g.special then out[#out + 1] = C .. "Delve mechanic|r\n" .. g.special end
    if g.variants then
        local l = {}
        for i, v in ipairs(g.variants) do l[#l + 1] = "|cffffd100" .. i .. ". " .. v[1] .. "|r\n" .. v[2] end
        out[#out + 1] = C .. "Story variants (the map tooltip shows today's)|r\n" .. table.concat(l, "\n\n")
    end
    if g.trash then out[#out + 1] = C .. "Dangerous enemies|r\n• " .. table.concat(g.trash, "\n• ") end
    if g.bosses then
        local l = {}
        for _, b in ipairs(g.bosses) do l[#l + 1] = "|cffff9900" .. b[1] .. "|r\n" .. b[2] end
        out[#out + 1] = C .. "Boss mechanics|r\n" .. table.concat(l, "\n\n")
    end
    return table.concat(out, "\n\n")
end

-- fallback spot from the guide when the live map didn't give one
function ns:DelveGuideSpot(e)
    local g = self.DELVE_GUIDES[(e.name or ""):lower()]
    if not (g and g.zone) then return end
    local m = self.ZoneByName and self:ZoneByName(g.zone)
    if not m then return end
    if g.x then return { m = m, x = g.x, y = g.y } end
    e.openMap = m
end
