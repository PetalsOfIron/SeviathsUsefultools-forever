"""Reads the monsters of every Classic zone from Wowhead Classic: the zone pages list the monsters; each monster page gives its places, family, what it drops
(with how often) and what it gives when skinned. Slow and polite on purpose (about one page a second, waits and goes on after a 403); it can be stopped and run again:
it continues where it stopped.

Output: tools/crawl/npcs_classic.txt, one line per monster:
  id|name|classification|minlevel-maxlevel|type|family|tameable|area:x,y;x,y~area:...|item:count:outof,...|skinitem:count:outof,...
Run: python tools/crawl_classic_npcs.py
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "crawl")
os.makedirs(OUT_DIR, exist_ok=True)
OUT = os.path.join(OUT_DIR, "npcs_classic.txt")
ZONES_FILE = os.path.join(OUT_DIR, "zone_npcs.json")

# Wowhead zone numbers of the Classic zones
ZONES = [12, 1, 14, 215, 141, 85, 40, 38, 148, 17, 130, 44, 10, 11, 267, 331, 406, 400, 36, 45, 33, 405, 3, 8, 15, 357, 440, 47, 51, 46, 4, 490, 16, 361,
         493, 1377, 618, 139, 28, 41]
PAUSE = 1.1


def fetch(path):
    for attempt in range(8):
        req = urllib.request.Request("https://www.wowhead.com" + path, headers={"User-Agent": "Mozilla/5.0"})
        try:
            time.sleep(PAUSE)
            return urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code not in (403, 429, 503) or attempt == 7:
                raise
            wait = min(30 * 2 ** attempt, 600)
            print("  waiting %d s (%d)" % (wait, e.code), flush=True)
            time.sleep(wait)


def listview(html, lv_id):
    i = html.find("id: '%s'" % lv_id)
    if i < 0:
        return []
    j = html.find("data:", i)
    s = html.find("[", j)
    depth = 0
    end = s
    for q in range(s, len(html)):
        c = html[q]
        if c == "[":
            depth += 1
        elif c == "]":
            depth -= 1
            if depth == 0:
                end = q + 1
                break
    body = re.sub(r"([,{])([A-Za-z_][A-Za-z0-9_]*):", r'\1"\2":', html[s:end])
    try:
        return json.loads(body)
    except Exception:
        return []


# 1. the monsters of the zones
if os.path.exists(ZONES_FILE):
    zone_npcs = json.load(open(ZONES_FILE, encoding="utf8"))
else:
    zone_npcs = {}
for z in ZONES:
    if str(z) in zone_npcs:
        continue
    try:
        rows = listview(fetch("/classic/zone=%d" % z), "npcs")
    except Exception as e:
        print("zone", z, "failed", e, flush=True)
        continue
    zone_npcs[str(z)] = [[r["id"], r.get("name", ""), r.get("classification", 0), r.get("minlevel", 0), r.get("maxlevel", 0), r.get("type", 0),
                          (r.get("react") or [None])[0]] for r in rows]
    json.dump(zone_npcs, open(ZONES_FILE, "w", encoding="utf8"))
    print("zone", z, len(rows), "monsters", flush=True)

todo = {}
for z, rows in zone_npcs.items():
    for nid, name, cl, lo, hi, typ, react in rows:
        if typ == 8 or lo == 0 and hi == 0 and cl == 0:   # critters and what has no level
            continue
        if react == 1:   # friendly to both: not a monster
            continue
        todo[nid] = (name, cl, lo, hi, typ)
print(len(todo), "monsters to read", flush=True)

# 2. each monster
done = set()
if os.path.exists(OUT):
    for line in open(OUT, encoding="utf8"):
        p = line.split("|", 1)
        if p and p[0].isdigit():
            done.add(int(p[0]))
count = 0
META = os.path.join(OUT_DIR, "items_meta.txt")
seen_items = set()
if os.path.exists(META):
    for line in open(META, encoding="utf8"):
        p = line.split("|", 1)
        if p and p[0].isdigit():
            seen_items.add(int(p[0]))
meta = open(META, "a", encoding="utf8", newline="\n")
with open(OUT, "a", encoding="utf8", newline="\n") as out:
    for nid in sorted(todo):
        if nid in done:
            continue
        name, cl, lo, hi, typ = todo[nid]
        try:
            html = fetch("/classic/npc=%d" % nid)
        except Exception as e:
            print("npc", nid, "failed", e, flush=True)
            continue
        family = ""
        m = re.search(r'"family":(\d+)', html)
        if m:
            family = m.group(1)
        tame = 1 if "Tameable (" in html else 0
        pts = []
        i = html.find("g_mapperData = ")
        if i >= 0:
            j = html.find(";\n", i)
            try:
                data = json.loads(html[i + 15:j])
            except Exception:
                data = {}
            if isinstance(data, dict):
                for area, arr in data.items():
                    coords = []
                    for part in arr:
                        coords.extend(part.get("coords", []))
                    if coords:
                        step = max(1, len(coords) // 5)
                        pts.append("%s:%s" % (area, ";".join("%s,%s" % (c[0], c[1]) for c in coords[::step][:5])))
        drop_rows = [d for d in listview(html, "drops") if "id" in d]
        skin_rows = [d for d in listview(html, "skinning") if "id" in d]
        drops = ",".join("%d:%d:%d" % (d["id"], d.get("count", 0), d.get("outof", 0)) for d in drop_rows)
        skin = ",".join("%d:%d:%d" % (d["id"], d.get("count", 0), d.get("outof", 0)) for d in skin_rows)
        # what the items are (name, quality, class, subclass, level): kept once for each item
        for d in drop_rows + skin_rows:
            if d["id"] not in seen_items:
                seen_items.add(d["id"])
                meta.write("%d|%s|%s|%s|%s|%s|%s\n" % (d["id"], str(d.get("name", "")).replace("|", "/"), d.get("quality", 1), d.get("classs", 0),
                                                       d.get("subclass", 0), d.get("level", 0), d.get("reqlevel", 0)))
        meta.flush()
        out.write("|".join([str(nid), name.replace("|", "/"), str(cl), "%d-%d" % (lo, hi), str(typ), family, str(tame), "~".join(pts), drops, skin]) + "\n")
        out.flush()
        count += 1
        if count % 50 == 0:
            print(count, "monsters read", flush=True)
print("finished", count, "monsters", flush=True)
