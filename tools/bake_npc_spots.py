"""Turns the places of the monsters Wowhead lists drops for into monster records of the shipped data (tools/npc_extra.json).

Sources:
  tools/npc_spots.txt  - id|areaID:count:x,y;x,y;x,y|areaID2:...  (read in a browser from each monster's Wowhead page, g_mapperData: the places are
                         percent of the zone map)
  tools/items_sources.txt - the monster's name (sourcemore of the items it drops)
  wago.tools UiMap and UiMapAssignment - the area ID of Wowhead is a zone; its uiMapID is looked up there (zone maps first), kept in
                         tools/area_maps.json so the pipeline does not need the network
Output: tools/npc_extra.json = { npcID: { "n": name, "m": { uiMapID: [[x, y], ...] }, "k": 0 } }; bake_collected.py adds them to the shipped monsters
(only monsters the player's data does not have), so the map lists, hovers and waypoints work for them like for any other monster.
Run: python tools/bake_npc_spots.py
"""
import csv
import io
import json
import os
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "area_maps.json")


def table(name):
    req = urllib.request.Request("https://wago.tools/db2/%s/csv" % name, headers={"User-Agent": "Mozilla/5.0"})
    return list(csv.DictReader(io.StringIO(urllib.request.urlopen(req, timeout=120).read().decode("utf8"))))


def build_area_maps():
    uimap = {int(r["ID"]): r for r in table("UiMap")}
    by_area = {}
    for r in table("UiMapAssignment"):
        a = int(r["AreaID"])
        if a:
            by_area.setdefault(a, set()).add(int(r["UiMapID"]))
    rank = {3: 0, 5: 1, 4: 2, 2: 3, 1: 4}   # zone maps first
    out = {}
    for a, maps in by_area.items():
        best = None
        for m in maps:
            t = int(uimap.get(m, {}).get("Type", 9) or 9)
            key = (rank.get(t, 9), m)
            if best is None or key < best[0]:
                best = (key, m)
        out[a] = best[1]
    return out


if os.path.exists(CACHE):
    area_map = {int(k): v for k, v in json.load(open(CACHE)).items()}
else:
    area_map = build_area_maps()
    json.dump(area_map, open(CACHE, "w"))

names = {}
for line in open(os.path.join(HERE, "items_sources.txt"), encoding="utf8").read().splitlines():
    p = line.split("|")
    if len(p) < 5:
        continue
    for part in p[4].split(";"):
        f = part.split(":")
        if len(f) >= 4 and f[0] == "1" and f[1].isdigit() and f[3].strip():
            names.setdefault(int(f[1]), f[3].strip())

out = {}
for line in open(os.path.join(HERE, "npc_spots.txt"), encoding="utf8").read().splitlines():
    p = line.split("|")
    if not p[0].isdigit():
        continue
    npc = int(p[0])
    maps = {}
    for area_part in p[1:]:
        f = area_part.split(":")
        if len(f) < 3:
            continue
        m = area_map.get(int(f[0])) if f[0].isdigit() else None
        if not m:
            continue
        pts = []
        for xy in f[2].split(";"):
            x, _, y = xy.partition(",")
            try:
                pts.append([round(float(x) / 100, 4), round(float(y) / 100, 4)])
            except ValueError:
                pass
        if pts:
            maps[str(m)] = pts
    if maps and npc in names:
        out[str(npc)] = {"n": names[npc], "m": maps, "k": 0}
json.dump(out, open(os.path.join(HERE, "npc_extra.json"), "w"), ensure_ascii=False)
print("%d monsters with a name and a place" % len(out))
