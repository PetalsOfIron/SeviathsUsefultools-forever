"""Bakes Data/WildPetSpots.lua: exact places of wild battle pets, with the uiMapID of each.

Source: Wowhead's Mists of Pandaria Classic guide "Catching Every Wild Battle Pet: Locations & Waypoints", whose TomTom lines
("/way #<uiMapID> <x> <y> <Pet name>") are kept in tools/wildpets_mop.txt (the page text, read in a browser).
Output: SFP.WildPetSpots["Pet name"] = { { map, x, y }, ... } with x and y as fractions of the map.
Run: python tools/bake_wild_pet_spots.py
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
text = open(os.path.join(HERE, "wildpets_mop.txt"), encoding="utf8").read()
spots = {}
for m in re.finditer(r"/way #(\d+) ([\d.]+) ([\d.]+) ([^\n]+)", text):
    name = m.group(4).strip()
    lst = spots.setdefault(name, [])
    p = (int(m.group(1)), round(float(m.group(2)) / 100, 4), round(float(m.group(3)) / 100, 4))
    if p not in lst:
        lst.append(p)
# the newer guides (Wowhead: Midnight, Curse of Ula'tek, The War Within, Dragonflight wild pets, Zaralek, Forbidden Reach): "uiMapID|x|y|name" lines
guides = os.path.join(HERE, "wildpets_guides.txt")
if os.path.exists(guides):
    for line in open(guides, encoding="utf8"):
        parts = line.strip().split("|")
        if len(parts) == 4:
            name = parts[3].strip()
            p = (int(parts[0]), round(float(parts[1]) / 100, 4), round(float(parts[2]) / 100, 4))
            lst = spots.setdefault(name, [])
            if p not in lst:
                lst.append(p)
out = ["-- SeviathsUsefulTools - exact places of wild battle pets (made by tools/bake_wild_pet_spots.py from Wowhead's wild pet guide)",
       "-- SFP.WildPetSpots[name] = { { uiMapID, x, y }, ... }", "", "local _, SFP = ...", "", "SFP.WildPetSpots = {"]
for name in sorted(spots):
    pts = ", ".join("{ %d, %g, %g }" % p for p in spots[name])
    out.append('    ["%s"] = { %s },' % (name.replace('"', '\\"'), pts))
out.append("}")
open(os.path.join(ADDON, "Data", "WildPetSpots.lua"), "w", encoding="utf8", newline="\n").write("\n".join(out) + "\n")
print(len(spots), "pets,", sum(len(v) for v in spots.values()), "places")
