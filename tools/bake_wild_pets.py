"""Bakes Data/WildPets.lua: the zones where each wild battle pet is found.

Sources (read by hand from Wowhead and kept next to this script):
  tools/wildpets_guide.txt - "Trapping Round the World - All the Tameable Wild Battle Pets" (zone, then the pets of that zone)
  tools/wildpets_news.txt  - "Pet Battles: Wild Battle Pets by Zone" (pet, then the zones it is in)
Output: SFP.WildPets["Pet name"] = "Zone; Zone; ..."  (no coordinates exist in these sources: the zone is the finest place).
Run: python tools/bake_wild_pets.py
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
FIX = {"Infnite Whelping": "Infinite Whelpling", "Rabid Nut Varmit 5000": "Rabid Nut Varmint 5000", "Lost of Lordaeron": "Lost of Lordaeron",
       "Long-tailed Mole": "Long-Tailed Mole", "clanking Scrapsorter": "Clanking Scrapsorter"}
pets = {}


def add(name, zone):
    name = FIX.get(name.strip().rstrip("*").strip(), name.strip().rstrip("*").strip())
    zone = re.sub(r"\s*\(Burning Crusade\)", "", zone).strip()
    if not name or not zone:
        return
    zs = pets.setdefault(name, [])
    if zone not in zs:
        zs.append(zone)


lines = [l.rstrip("\n") for l in open(os.path.join(HERE, "wildpets_guide.txt"), encoding="utf8") if l.strip()]
i = 0
while i + 1 < len(lines):
    m = re.match(r"^(.*?)\s*\((?:\d+(?:-\d+)?)\)\s*.*$", lines[i])
    if m:
        for p in lines[i + 1].split(","):
            add(p, m.group(1))
        i += 2
    else:
        i += 1
for l in open(os.path.join(HERE, "wildpets_news.txt"), encoding="utf8"):
    if "\t" in l:
        name, zones = l.rstrip("\n").split("\t", 1)
        for z in zones.split(","):
            add(name, z)

out = ["-- SeviathsUsefulTools - the zones where wild battle pets are found (made by tools/bake_wild_pets.py from two Wowhead pages;",
       "-- no coordinates exist in them, the zone is the finest place)", "", "local _, SFP = ...", "", "SFP.WildPets = {"]
for name in sorted(pets):
    out.append('    ["%s"] = "%s",' % (name.replace('"', '\\"'), "; ".join(pets[name]).replace('"', '\\"')))
out.append("}")
open(os.path.join(ADDON, "Data", "WildPets.lua"), "w", encoding="utf8", newline="\n").write("\n".join(out) + "\n")
print(len(pets), "pets")
