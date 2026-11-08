"""Bakes Data/WildPetZones.lua: the zone maps where each battle pet species is found, for pets that Wowhead gives a location.

Source: Wowhead's battle pet database page (https://www.wowhead.com/battle-pets), whose listview data was saved in
tools/wowhead_pet_species.json as [species, name, category, type, npcID, minlevel, maxlevel, [areaIDs], untameable].
The area IDs are turned into uiMapIDs with wago.tools' UiMapAssignment and UiMap tables (zone maps first).
Output: SFP.WildPetZones["Pet name"] = { uiMapID, ... }
Run: python tools/bake_wild_zones.py
"""
import csv
import io
import json
import os
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)


def table(name):
    req = urllib.request.Request("https://wago.tools/db2/%s/csv" % name, headers={"User-Agent": "Mozilla/5.0"})
    return list(csv.DictReader(io.StringIO(urllib.request.urlopen(req, timeout=120).read().decode("utf8"))))


uimap = {int(r["ID"]): r for r in table("UiMap")}
by_area = {}
for r in table("UiMapAssignment"):
    a = int(r["AreaID"])
    if a:
        by_area.setdefault(a, set()).add(int(r["UiMapID"]))
RANK = {3: 0, 5: 1, 4: 2, 2: 3, 1: 4}


def zone_map(area):
    maps = by_area.get(area)
    if not maps:
        return None
    best = None
    for m in maps:
        t = int(uimap.get(m, {}).get("Type", 9) or 9)
        key = (RANK.get(t, 9), m)
        if best is None or key < best[0]:
            best = (key, m)
    return best[1]


pets = json.load(open(os.path.join(HERE, "wowhead_pet_species.json"), encoding="utf8"))
out = {}
for species, name, cat, typ, npc, lo, hi, areas, untame in pets:
    maps = []
    for a in areas:
        if a > 0:
            m = zone_map(a)
            if m and m not in maps:
                maps.append(m)
    if maps:
        out.setdefault(name, [])
        for m in maps:
            if m not in out[name]:
                out[name].append(m)
lines = ["-- SeviathsUsefulTools - the zone maps where battle pets are found (made by tools/bake_wild_zones.py from Wowhead's battle pet",
         "-- database and wago.tools' map tables)", "", "local _, SFP = ...", "", "SFP.WildPetZones = {"]
for name in sorted(out):
    lines.append('    ["%s"] = { %s },' % (name.replace('"', '\\"'), ", ".join(str(m) for m in out[name][:8])))
lines.append("}")
open(os.path.join(ADDON, "Data", "WildPetZones.lua"), "w", encoding="utf8", newline="\n").write("\n".join(lines) + "\n")
print(len(out), "pets with a zone map")
