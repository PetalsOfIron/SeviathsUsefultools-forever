"""Bakes Data/SpawnsWowhead.lua: which monsters drop (or are skinned for) every crafting reagent, and where they are.

The reagent list is every trade good in Data/AuctionItems.lua (item class 7). For each one the Wowhead item page lists the monsters
that drop it ("Dropped by", "Skinned from") with the drop count; the best ones (by drop chance, from enough kills) are then read from
their Wowhead NPC page for their places on the map. Pages are cached in %TEMP%\\sut_wh_cache, so a second run only asks for what is new
or missing. Run: python tools/bake_wowhead_drops.py  (about 30 minutes the first time; it waits between requests).
"""
import json
import os
import re
import sys
import threading
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
CACHE = os.path.join(os.environ.get("TEMP", HERE), "sut_wh_cache")
os.makedirs(CACHE, exist_ok=True)

MIN_PCT = 3.0       # a monster is kept when it drops the item at least this often ...
MIN_OUTOF = 15      # ... judged over at least this many kills
MAX_PER_ITEM = 8    # the best monsters per item
MAX_POINTS = 24     # map points kept per monster and map

lock = threading.Lock()
last = [0.0]


def fetch(url, cache_name):
    path = os.path.join(CACHE, cache_name)
    if os.path.exists(path):
        return open(path, encoding="utf8").read()
    for attempt in range(4):
        with lock:   # one request every 0.25 s over all threads
            wait = 0.25 - (time.time() - last[0])
            if wait > 0:
                time.sleep(wait)
            last[0] = time.time()
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            text = urllib.request.urlopen(req, timeout=40).read().decode("utf8", "replace")
            if cache_name.startswith("item"):   # only the loot lists are kept
                text = "\n".join(listviews(text))
            elif cache_name.startswith("npc"):
                m = re.search(r"g_mapperData = (\{.*?\});\s*\n", text)
                text = m.group(1) if m else "{}"
            open(path, "w", encoding="utf8").write(text)
            return text
        except Exception as e:
            if "403" in str(e) or "429" in str(e):
                # Wowhead is refusing the requests: stop (the pages read so far stay cached) and try again much later
                os._exit(3)
            if "404" in str(e):
                open(path, "w", encoding="utf8").write("")
                return ""
            time.sleep(2 + attempt * 3)
    return None


def listviews(html):
    """The data arrays of the 'dropped-by' and 'skinned-from' lists of an item page, one JSON text per line."""
    out = []
    for key in ("dropped-by", "skinned-from"):
        i = html.find("id: '" + key + "'")
        if i < 0:
            continue
        j = html.find("data: [", i)
        if j < 0 or j - i > 900:
            continue
        try:
            arr, _ = json.JSONDecoder().raw_decode(html[j + 6:])
        except ValueError:
            continue
        out.append(json.dumps({"kind": key, "data": arr}))
    return out


def reagent_ids():
    t = open(os.path.join(ADDON, "Data", "AuctionItems.lua"), encoding="utf8").read()
    return sorted(int(m.group(1)) for m in re.finditer(r"\[(\d+)\]=\{7,", t))


def main():
    ids = reagent_ids()
    print("reagents:", len(ids), flush=True)
    done = [0]

    def item_job(i):
        text = fetch("https://www.wowhead.com/item=%d" % i, "item%d.json" % i)
        done[0] += 1
        if done[0] % 100 == 0:
            print("items", done[0], "/", len(ids), flush=True)
        return i, text

    drops = {}   # npc -> {name, items{item: pct}}
    with ThreadPoolExecutor(4) as pool:
        for i, text in pool.map(item_job, ids):
            if not text:
                continue
            best = []
            for line in text.splitlines():
                try:
                    block = json.loads(line)
                except ValueError:
                    continue
                for n in block["data"]:
                    outof = n.get("outof") or 0
                    cnt = n.get("count") or 0
                    if outof >= MIN_OUTOF and cnt > 0 and n.get("id") and n.get("name"):
                        pct = 100.0 * cnt / outof
                        if pct >= MIN_PCT:
                            best.append((pct, n["id"], n["name"]))
            best.sort(reverse=True)
            for pct, nid, name in best[:MAX_PER_ITEM]:
                d = drops.setdefault(nid, {"name": name, "items": {}})
                d["items"][i] = round(pct, 1)
    print("monsters:", len(drops), flush=True)

    got = [0]

    def npc_job(nid):
        text = fetch("https://www.wowhead.com/npc=%d" % nid, "npc%d.json" % nid)
        got[0] += 1
        if got[0] % 200 == 0:
            print("monsters", got[0], "/", len(drops), flush=True)
        return nid, text

    by_map = {}
    with ThreadPoolExecutor(4) as pool:
        for nid, text in pool.map(npc_job, sorted(drops)):
            try:
                data = json.loads(text) if text else {}
            except ValueError:
                continue
            for _zone, entries in data.items():
                for e in entries:
                    m = e.get("uiMapId")
                    coords = e.get("coords") or []
                    if not m or not coords:
                        continue
                    step = max(1, len(coords) // MAX_POINTS)
                    pts = ";".join("%g,%g" % (c[0], c[1]) for c in coords[::step][:MAX_POINTS])
                    by_map.setdefault(m, []).append((nid, pts))

    out = ["-- SeviathsUsefulTools - monsters that drop crafting reagents, from Wowhead (made by tools/bake_wowhead_drops.py)",
           "-- [uiMapID] = { { npc, name, pts = \"x,y;x,y\", drop = { [itemID] = percent } } }", "",
           "local _, SFP = ...", "", "SFP.SpawnsWowhead = {"]
    for m in sorted(by_map):
        out.append("    [%d] = {" % m)
        for nid, pts in by_map[m]:
            d = drops[nid]
            drop = ",".join("[%d]=%s" % (k, v) for k, v in sorted(d["items"].items()))
            name = d["name"].replace("\\", "\\\\").replace('"', '\\"')
            out.append('        { npc = %d, name = "%s", pts = "%s", drop = { %s } },' % (nid, name, pts, drop))
        out.append("    },")
    out.append("}")
    out.append("")
    path = os.path.join(ADDON, "Data", "SpawnsWowhead.lua")
    open(path, "w", encoding="utf8", newline="\n").write("\n".join(out))
    print("written", path, sum(len(v) for v in by_map.values()), "monster places in", len(by_map), "maps")


if __name__ == "__main__":
    main()
