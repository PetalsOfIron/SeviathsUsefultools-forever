-- SeviathsUsefulTools - notable rares (mounts) and hunter tames (spirit beasts, unique pets)
-- Spawn positions from Wowhead's NPC data. Drops are mostly bind-on-pickup collectibles;
-- drop chances are low and not published, so none are claimed here.

local _, SFP = ...

SFP.Rares = {
    [47] = { exp = "classic",
        { npc = 118244, name = "Lightning Paw", items = {  }, note = "Spirit beast (fox). It hides stealthed in bushes until you are very close - make a /tar Lightning Paw macro and press it at each spot.",
          hunter = "spirit", pts = "16,60.2;16.4,54;16.6,54.4;16.6,60.4;17,55.4;23.4,76.6;23.6,76.6;24.2,40.6;24.4,39.2;24.4,39.6;30,40.8;30.2,41.6" },
    },
    [50] = { exp = "classic",
        { npc = 51663, name = "Pogeyan", items = {  }, note = "The Fire Spirit - a cat with a unique burning look. Tameable rare, no special tactic.",
          hunter = "unique", pts = "36.2,29.2;36.4,27.4;36.4,28.2;36.4,29.6;36.6,29.2;37,28.4;37,29.8;37.6,30.2" },
    },
    [84] = { exp = "classic",
        { npc = 121567, name = "Lost Spectral Gryphon", items = {  }, note = "Spirit beast (gryphon). Click the Spectral Feather in the far back of the gryphon master's nest to make it appear; only Beast Mastery hunters can see it.",
          hunter = "spirit", pts = "62.8,72.4;67.8,72.6;71.4,72;71.4,72.6;71.6,72.2;71.8,73" },
    },
    [85] = { exp = "classic",
        { npc = 121571, name = "Gon", items = {  }, note = "Spirit beast. Click the Spectral Eggshell by the skull pile near the priest trainer's hut in the Valley of Spirits; only Beast Mastery hunters can see it.",
          hunter = "spirit", pts = "35.4,69.2;35.8,67.8;35.8,69" },
    },
}

-- mounts, pets and toys dropped by the rares above (names/icons come from the game)

-- the Classic rares of Wowhead (rare and rare elite monsters, read from Wowhead Classic with their places): see tools/rares_classic.txt
local function addRare(map, npc, name, note, pts)
    local block = SFP.Rares[map]
    if not block then block = { exp = "classic" }; SFP.Rares[map] = block end
    block[#block + 1] = { npc = npc, name = name, items = {}, note = note, pts = pts }
end
addRare(7, 3056, "Ghost Howl", "Rare, level 12", "29.4,25.4;30.4,22.6;31.2,22.4;31.8,22;32.2,23.6")
addRare(7, 3068, "Mazzranache", "Rare, level 9", "33.4,41.4;33.8,40.4;34.8,41.2;35.4,39.4;36,42.2")
addRare(7, 5785, "Sister Hatelash", "Rare elite, level 11", "29.2,20.6;30.4,21.4;31,19.8;35.8,12.6;36.6,13.2")
addRare(7, 5786, "Snagglespear", "Rare, level 9", "45.8,68.2;47.2,69;47.8,66.8;48.4,69.4;48.8,72.6")
addRare(10, 3253, "Silithid Harvester", "Rare, level 24", "42.4,69.4;42.8,71.8;44.4,74;45.2,71.2;47.2,69.4")
addRare(10, 3270, "Elder Mystic Razorsnout", "Rare elite, level 15", "58.2,26.2;58.2,26.6;58.6,26.4;58.6,26.8;59,24.6")
addRare(10, 3295, "Sludge Beast", "Rare, level 19", "55,9;56.2,9.6;56.4,8.6;56.6,8.2;58,8.8")
addRare(10, 3398, "Gesharahan", "Rare elite, level 20", "46.4,39.4;46.4,39.6;46.6,39.4;46.6,39.6")
addRare(10, 3470, "Rathorian", "Rare, level 15", "47.6,19.2")
addRare(14, 2598, "Darbel Montrose", "Rare elite, level 39", "25.8,59.2;27.4,62.8;28,62.8;29.2,60.2;29.8,64")
addRare(14, 2600, "Singer", "Rare, level 34", "30.2,26.2;31.8,31.8;32.6,31.2;33.6,26.4;34.6,32")
addRare(14, 2601, "Foulbelly", "Rare elite, level 42", "18.4,65.8;19.4,64.4;20,64.8;20.2,67.6;21.6,66.8")
addRare(14, 2602, "Ruul Onestone", "Rare elite, level 39", "17.4,68.4;18.2,68.4;18.2,68.6")
addRare(14, 2603, "Kovork", "Rare, level 36", "31.4,45.8;31.6,45.8;32.6,46")
addRare(14, 2604, "Molok the Crusher", "Rare, level 39", "53.4,79.4;53.6,79.8;54.2,77.6;54.6,78.2;54.8,80.2")
addRare(14, 2605, "Zalas Witherbark", "Rare, level 40", "66,82;67.6,80.2;69,79.4;69.6,79.6;70.2,77.8")
addRare(14, 2606, "Nimar the Slayer", "Rare, level 37", "59,74.6;61.2,72.8;62.2,56.8;62.8,58.6;63.2,66.2")
addRare(14, 2779, "Prince Nazjak", "Rare, level 41", "19.8,88.8;21,91.6;21.6,89.4;23,85;23.4,86.8")
addRare(15, 2744, "Shadowforge Commander", "Rare, level 40", "39.4,27.4;40,26.4;40.8,29;41.4,26.6;42.6,27.6")
addRare(15, 2749, "Siege Golem", "Rare elite, level 40", "5.6,59.8;7.2,59.8;9.6,73.8;11.4,67.4;12.6,63.8")
addRare(15, 2751, "War Golem", "Rare, level 36", "42.4,33;44.4,32.4;45.4,13;46.2,12.8;47,35")
addRare(15, 2752, "Rumbler", "Rare, level 45", "0.8,81;1.8,83.2;3.2,78.8;3.6,80.4;4.4,83.6")
addRare(15, 2754, "Anathemus", "Rare elite, level 45", "2.2,45.8;4.4,46.4;8.2,62.6;9.6,70.6;10.2,80.2")
addRare(15, 2850, "Broken Tooth", "Rare, level 37", "25.8,48.6;40.4,36.8;43.4,36.8;44.2,38.8;45,39.4")
addRare(15, 2931, "Zaricotl", "Rare elite, level 55", "3,48.6;4.4,47.8;5,44.4;17.6,53.8;22.8,54.6")
addRare(18, 1531, "Lost Soul", "Rare, level 6-7", "44.4,37.4;47,39.4;48.4,36;53.2,48.4;53.6,46.6")
addRare(18, 1533, "Tormented Spirit", "Rare, level 8-9", "43,34.8;44,32.6;44.4,31.2;45,37.6;46,35.4")
addRare(18, 1910, "Muad", "Rare, level 10", "33,43.4;34.2,41.6;34.8,44.8;35.8,46.6;36.4,41.2")
addRare(18, 1911, "Deeb", "Rare, level 12", "57.4,25;58,26.4;58.8,27.2;61.8,29.4;62.8,29.6")
addRare(18, 1936, "Farmer Solliden", "Rare, level 8", "34.2,52;34.6,51.4;36.4,49.4;37,49.4;38.2,50")
addRare(21, 1920, "Dalaran Spellscribe", "Rare, level 21", "60.4,64.2;62,64.8;63,63.6;63.4,65.2;63.8,63.2")
addRare(21, 1944, "Rot Hide Bruiser", "Rare, level 22", "63.4,22.2;64.6,24.2;65.6,23;66.4,25.4;67.6,24.4")
addRare(21, 1948, "Snarlmane", "Rare, level 23", "65,23.2;65.2,24;65.8,23.2;65.8,23.8;66.2,27")
addRare(21, 2283, "Ravenclaw Regent", "Rare, level 22", "57.2,70.8;57.4,69.8;57.6,69.8;57.6,71.4;57.8,71.6")
addRare(22, 1837, "Scarlet Judge", "Rare, level 60", "40.4,17.6;42.2,18.2;43.2,16;44.6,19.4;48.4,22")
addRare(22, 1838, "Scarlet Interrogator", "Rare elite, level 61", "43,14.2;44.2,14.4;46.2,11.6;46.6,14;47.2,12.2")
addRare(22, 1839, "Scarlet High Clerist", "Rare elite, level 63", "54.2,25.2;54.4,23.8;54.8,22.4;55,23.4;55,23.6")
addRare(22, 1841, "Scarlet Executioner", "Rare elite, level 60", "44.2,18.4;45.2,17.2;45.6,18.4;45.8,21;47.2,18")
addRare(22, 1843, "Foreman Jerris", "Rare elite, level 62", "41,15.2;45.2,10.2;45.8,11;46.2,15.6;46.8,16.6")
addRare(22, 1844, "Foreman Marcrid", "Rare, level 58", "43.6,34.8;44.4,38.8;45.2,37.4;47,34.2;47.8,33.6")
addRare(22, 1847, "Foulmane", "Rare, level 52", "41.8,53.2;44.2,52;45.4,53.6;46.2,48.6;47,52.6")
addRare(22, 1848, "Lord Maldazzar", "Rare, level 56", "44,81.4;48.4,77.4;49.2,76.4;49.8,80.8;50.6,74.2")
addRare(22, 1850, "Putridius", "Rare elite, level 58", "36,64.8;38.4,70.8;39.2,71.6;39.6,70.6;40.4,66.4")
addRare(22, 1851, "The Husk", "Rare, level 62", "61.2,35.4;62,37.6;63,36;64.2,33.4;65.4,39.8")
addRare(22, 1885, "Scarlet Smith", "Rare, level 58-59", "41.4,13.4;43.2,16;44.4,13.6;45.4,12.2;46.2,11.6")
addRare(25, 2447, "Narillasanz", "Rare elite, level 44", "50.2,59.2;60,20.4;63.8,8.8;66.2,7.4;68,35.6")
addRare(27, 1119, "Hammerspine", "Rare, level 12", "71.4,51.4;71.6,50.2;72.4,53;72.6,51.4;73,51.8")
addRare(27, 1130, "Bjarn", "Rare, level 12", "47.4,55.6;50.8,59.4;53.6,58.6;55.2,55.2;55.8,59.6")
addRare(27, 1132, "Timber", "Rare, level 10", "29.6,43.2;31.2,43.4;32.2,35.2;32.8,43;33.4,44")
addRare(27, 1137, "Edan the Howler", "Rare, level 9", "38.4,48.2;39.6,46;40.8,47;42.4,49.2;43.6,49.6")
addRare(27, 1260, "Great Father Arctikus", "Rare, level 11", "21,51;21.4,54.6;22.4,54.2;23.4,54.2;25.4,49.4")
addRare(37, 61, "Thuros Lightfingers", "Rare, level 11", "28,59;29.4,58.6;30.6,58;46.2,57.8;48,58.6")
addRare(37, 79, "Narg the Taskmaster", "Rare, level 10", "40.8,77.4;41,77.8;41.2,78.8;41.4,79.8")
addRare(37, 99, "Morgaine the Sly", "Rare, level 10", "30.8,64.8;31,65.6;31.4,64.4;31.6,64.4;31.6,64.8")
addRare(37, 100, "Gruff Swiftbite", "Rare, level 12", "23.4,91.6;24,92.6;25.4,92.8;26.2,87.6;26.4,95")
addRare(37, 471, "Mother Fang", "Rare, level 10", "60.4,47;60.8,47;61.4,48;61.4,48.8;61.8,47.8")
addRare(37, 472, "Fedfennel", "Rare, level 12", "64.2,44.2;65.2,44.2;65.8,38;66.6,41;67.2,41.6")
addRare(47, 503, "Lord Malathrom", "Rare, level 31", "21.4,27.6;25.6,30.2")
addRare(47, 507, "Fenros", "Rare, level 32", "57,49.4;58.2,44.2;59.4,31;59.8,32;60,34.8")
addRare(47, 521, "Lupos", "Rare, level 23", "19.8,29.6;21.2,26.6;22.2,25.8;23.4,26.6;23.8,31.2")
addRare(47, 534, "Nefaru", "Rare, level 34", "55.4,68.4;57,77.2;58.6,79.4;60.6,80.8;62.8,62.6")
addRare(47, 574, "Naraxis", "Rare, level 27", "86.2,47.4;86.4,48;86.4,49.2;86.6,49.2;86.6,49.6")
addRare(47, 771, "Commander Felstrom", "Rare, level 32", "11.4,29.8;14.4,33.8;15.2,38.4;15.6,37.4;17,30.6")
addRare(48, 1398, "Boss Galgosh", "Rare, level 22", "68.4,66;68.8,66;69.2,66.6;69.6,65.8;72.4,67.6")
addRare(48, 1399, "Magosh", "Rare, level 21", "70,65.4;70,66.2")
addRare(48, 1425, "Grizlak", "Rare, level 15", "34.4,27;35,27.4;35.4,27.8;35.6,27.8;36.4,26.2")
addRare(48, 2476, "Large Loch Crocolisk", "Rare, level 22", "53.2,30.8;57,20.6;58,33.6;58.4,29.4;58.8,28.2")
addRare(49, 584, "Kazon", "Rare, level 27", "33,6.6;34.6,7.6;35.6,6.4;36.4,11.2;36.8,8.2")
addRare(49, 616, "Chatter", "Rare, level 23", "43.4,31.4;50,41;50.6,42.4;51.2,45.6;51.8,34.8")
addRare(49, 947, "Rohh the Silent", "Rare, level 26", "65.6,40.4;74.2,41.2;75.4,39.4;75.8,30.8;76.2,39.4")
addRare(50, 723, "Mosh'Ogg Butcher", "Rare elite, level 44", "47.6,34.2;49.2,31.2;49.6,31.6;49.8,31;51,31.8")
addRare(50, 1552, "Scale Belly", "Rare, level 45", "42.4,46;43,48.2;43.4,45.8;43.6,46.2;44,47.6")
addRare(50, 2541, "Lord Sakrasis", "Rare, level 45", "28.4,62.4;28.6,62.2")
addRare(51, 763, "Lost One Chieftain", "Rare, level 39", "58.4,22.8;59.4,21.4;61,20.4;61.4,23.6;61.8,24.6")
addRare(51, 1106, "Lost One Cook", "Rare, level 37", "58,25.6;59.8,23.6;61.2,22.4;61.4,26.4;62.4,23.8")
addRare(52, 462, "Vultros", "Rare, level 26", "32.6,66.8;35.4,67.8;36.4,65;37.4,64;43.4,60.4")
addRare(52, 506, "Sergeant Brashclaw", "Rare, level 18", "31,30.8;33.6,33.8;35,28.4;35.6,33.8;36.4,27.2")
addRare(52, 519, "Slark", "Rare, level 15", "24.8,64.4;26.2,59;26.4,48;26.4,61;26.6,65.2")
addRare(52, 520, "Brack", "Rare, level 19", "25.2,62.8;25.8,61.4;26,64.8;26.4,48.8;26.4,69.4")
addRare(52, 572, "Leprithus", "Rare, level 19", "39.4,26.2;40.8,32.6;41.6,29.2;42.6,33.8;43.8,28.4")
addRare(52, 573, "Foe Reaper 4000", "Rare, level 20", "33.4,49.2;35.4,49.4;36.8,49.2;37.4,37.8;37.6,55.6")
addRare(52, 1424, "Master Digger", "Rare, level 15", "44.6,19.6;45,18.6;45.4,18.2;45.8,18.2;46.6,19.4")
addRare(56, 1037, "Dragonmaw Battlemaster", "Rare, level 30", "42.2,40.8;42.8,43.8;44.6,42.8;47,44.2;48.2,45.2")
addRare(56, 1112, "Leech Widow", "Rare, level 24", "45.6,61.2;46,62.2;46.6,64;46.8,65.8;47.6,64.4")
addRare(56, 1140, "Razormaw Matriarch", "Rare, level 31", "67.2,28.6;67.6,32;69.2,28.8;70.2,31.4;70.8,30.4")
addRare(56, 2090, "Ma'ruk Wyrmscale", "Rare, level 23", "47.2,74;47.8,74.6;48.2,75.6;48.8,78.8;50,81")
addRare(56, 2108, "Garneg Charskull", "Rare, level 29", "37,44;38.2,45.4;39.4,37.2;41.4,45.4;42.6,40.2")
addRare(57, 3535, "Blackmoss the Fetid", "Rare, level 13", "38.2,39.4;40.8,26.6;41.4,28.4;42,44.8;42.2,42.8")
addRare(62, 2172, "Strider Clutchmother", "Rare, level 20", "32.8,88.8;34.4,89;34.8,87.4;36.2,90.8;37.4,95")
addRare(62, 2175, "Shadowclaw", "Rare, level 13", "37.2,37.6;38.4,38;39.2,41.6;39.6,33;39.8,42.8")
addRare(62, 2184, "Lady Moongazer", "Rare, level 17", "40.4,60.4;41.6,59.6;42.2,62.6;43.4,62.4;44.4,60.4")
addRare(62, 2186, "Carnivous the Breaker", "Rare, level 16", "36.8,54.8;37.6,51.6;38.8,53.6;39.4,78.4;40,55")
addRare(62, 2191, "Licillin", "Rare, level 14", "44.4,36.6;45.2,36.4;45.8,39.2;46.8,36.6;47.6,36.6")
addRare(62, 2192, "Firecaller Radison", "Rare, level 19", "38.4,86.2;38.4,87.4;38.6,87.6;39,86.4;39,86.6")
addRare(63, 3735, "Apothecary Falthis", "Rare, level 22", "33,22;33.2,21")
addRare(63, 3773, "Akkrilus", "Rare, level 26", "25.2,60.4;27.4,63.2;27.6,63;28.2,65.2;28.6,62")
addRare(63, 3792, "Terrowulf Packlord", "Rare, level 31-32", "50,39.6;50.4,38.4;50.6,38.4;50.8,36.8;52,37.8")
addRare(64, 4132, "Silithid Ravager", "Rare, level 36", "63.4,85.4;64.8,84.4;67,84;67.8,89;68.4,81")
addRare(65, 4015, "Pridewing Patriarch", "Rare, level 25", "42.8,42;44.2,43.8;44.4,46.8;45.4,38.4;45.6,39.8")
addRare(65, 4030, "Vengeful Ancient", "Rare, level 29-30", "28,71.8;29.2,68.6;29.6,69.8;30.4,64.4;30.8,71")
addRare(65, 4066, "Nal'taszar", "Rare elite, level 30", "25.4,11.4;25.4,11.6;25.6,11.4;25.6,11.6;26.2,13.6")
addRare(69, 5343, "Lady Szallah", "Rare, level 46", "24.8,72.8;25.6,72.2;26.6,65.8;27.2,68.8;28.2,67.4")
addRare(69, 5345, "Diamond Head", "Rare, level 45", "21.2,50.2;21.6,55.2;22.4,59;35.4,58.2;36,54.4")
addRare(69, 5346, "Bloodroar the Stalker", "Rare, level 48", "51,59.8;51.8,60.6;52.4,60.2;52.6,59.4;53,56.6")
addRare(69, 5347, "Antilus the Soarer", "Rare, level 48", "53,68;54,70.2;54.6,71.2;55.6,74.6;58.8,73.4")
addRare(69, 5349, "Arash-ethis", "Rare, level 49", "37.2,22;38.2,22.2;39.6,24.2;41.4,25;42.6,24.8")
addRare(69, 5350, "Qirot", "Rare, level 47", "71.8,63.4;73.8,64.4;76.6,61.4;78,64.6;78.8,63.2")
addRare(69, 5352, "Old Grizzlegut", "Rare, level 43", "57.4,57;59.2,58.4;60.6,60.2;68.2,48.6;69.4,47")
addRare(69, 5354, "Gnarl Leafbrother", "Rare, level 44", "67.8,57.2;69.4,57.6;71.8,57.8;74.2,58.6;76,58.4")
addRare(69, 5356, "Snarler", "Rare, level 42", "74.8,35.4;75.6,37.2;76.6,38.4;78,38.6;80,38")
addRare(70, 4339, "Brimgore", "Rare elite, level 45", "33,45.4;40.8,75;42,76;42.8,80.6;43.6,77.4")
addRare(70, 4380, "Darkmist Widow", "Rare, level 40", "31,20.4;31,20.6")
addRare(84, 3581, "Sewer Beast", "Rare, level 50", "22.4,51;30.8,63.2;31.8,60;32.4,63.6;33.4,63.4")
addRare(88, 3056, "Ghost Howl", "Rare, level 12", "11.2,30;12.4,27;14.2,30.8;14.8,30.2;15.8,13.6")
