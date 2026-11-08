"""Turns the Wowhead crawl (tools/crawl/npcs_classic.txt + items_meta.txt + zone_npcs.json) into tools/crawl/crawl_seed.lua, a saved-variables style file that
bake_collected.py reads (python tools/bake_collected.py tools/classic_seed.lua tools/crawl/crawl_seed.lua): every monster with its places, level, kind,
family and drops (a drop chance = count of the item / kills seen, scaled to k kills), and the items it drops.
Run: python tools/make_crawl_seed.py"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
CR = os.path.join(HERE, "crawl")
# Wowhead zone number -> uiMapID of WoW Forever
MAPS = {12: 1429, 1: 1426, 14: 1411, 215: 1412, 141: 1438, 85: 1420, 40: 1436, 38: 1432, 148: 1439, 17: 1413, 130: 1421, 44: 1433, 10: 1431, 11: 1437,
        267: 1424, 331: 1440, 406: 1442, 400: 1441, 36: 1416, 45: 1417, 33: 1434, 405: 1443, 3: 1418, 8: 1435, 15: 1445, 357: 1444, 440: 1446, 47: 1425,
        51: 1427, 46: 1428, 4: 1419, 490: 1449, 16: 1447, 361: 1448, 493: 1450, 1377: 1451, 618: 1452, 139: 1423, 28: 1422, 41: 1430,
        1519: 1453, 1537: 1455, 1657: 1457, 1637: 1454, 1638: 1456, 1497: 1458}
TYPES = {1: "Beast", 2: "Dragonkin", 3: "Demon", 4: "Elemental", 5: "Giant", 6: "Undead", 7: "Humanoid", 8: "Critter", 9: "Mechanical", 10: "Not specified"}
FAMILY = {1: "Wolf", 2: "Cat", 3: "Spider", 4: "Bear", 5: "Boar", 6: "Crocolisk", 7: "Carrion Bird", 8: "Crab", 9: "Gorilla", 11: "Raptor", 12: "Tallstrider",
          15: "Felhunter", 16: "Voidwalker", 17: "Succubus", 19: "Doomguard", 20: "Scorpid", 21: "Turtle", 23: "Imp", 24: "Bat", 25: "Hyena", 26: "Bird of Prey",
          27: "Wind Serpent"}
CLASS = {1: "elite", 2: "rareelite", 3: "worldboss", 4: "rare"}   # Wowhead's classification number


def lua(v):
    if isinstance(v, dict):
        return "{" + ",".join("[%s]=%s" % (k if isinstance(k, int) else '"%s"' % k, lua(x)) for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "{" + ",".join(lua(x) for x in v) + "}"
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return str(v)


zones = json.load(open(os.path.join(CR, "zone_npcs.json"), encoding="utf8"))
cls = {}
for rows in zones.values():
    for nid, name, c, lo, hi, typ, react in rows:
        cls[nid] = c

items = {}
for line in open(os.path.join(CR, "items_meta.txt"), encoding="utf8").read().splitlines():
    p = line.split("|")
    if len(p) >= 7 and p[0].isdigit():
        items[int(p[0])] = {"n": p[1], "q": int(p[2] or 1), "c": int(p[3] or 0), "s": int(p[4] or 0), "r": int(p[6] or 0)}

npcs = {}
for line in open(os.path.join(CR, "npcs_classic.txt"), encoding="utf8").read().splitlines():
    p = line.split("|")
    if len(p) < 10 or not p[0].isdigit():
        continue
    nid = int(p[0])
    lo, hi = (p[3].split("-") + ["0"])[:2]
    rec = {"n": p[1], "lmin": int(lo or 0), "lmax": int(hi or 0)}
    if int(p[4] or 0) in TYPES:
        rec["t"] = TYPES[int(p[4])]
    if p[5].isdigit() and int(p[5]) in FAMILY:
        rec["f"] = FAMILY[int(p[5])]
    c = CLASS.get(cls.get(nid, int(p[2] or 0)))
    if c:
        rec["c"] = c
    places = {}
    for part in p[7].split("~"):
        if ":" not in part:
            continue
        area, pts = part.split(":", 1)
        m = MAPS.get(int(area))
        if not m:
            continue
        lst = places.setdefault(m, [])
        for xy in pts.split(";")[:5]:
            x, y = xy.split(",")
            lst.append([round(float(x) / 100, 4), round(float(y) / 100, 4)])
    if not places:
        continue
    rec["m"] = places
    for key, col in (("d", p[8]), ("s", p[9])):
        drops = {}
        outof = 0
        for d in col.split(","):
            f = d.split(":")
            if len(f) == 3 and f[0].isdigit() and int(f[2] or 0) > 0:
                outof = max(outof, int(f[2]))
        kills = min(outof, 1000)
        for d in col.split(","):
            f = d.split(":")
            if len(f) == 3 and f[0].isdigit() and int(f[2] or 0) > 0:
                n = round(int(f[1]) / int(f[2]) * kills)
                if n > 0:
                    drops[int(f[0])] = n
        if drops:
            rec[key] = drops
            if key == "d":
                rec["k"] = kills
    rec.setdefault("k", 0)
    npcs[nid] = rec

out = "SeviathsUsefulToolsDB = " + lua({"npcs": npcs, "knownItems": items}) + "\n"
open(os.path.join(CR, "crawl_seed.lua"), "w", encoding="utf8", newline="\n").write(out)
print(len(npcs), "monsters,", len(items), "items,", len(out) // 1024, "KB")
