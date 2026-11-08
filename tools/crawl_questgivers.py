"""Reads the friendly NPCs of every Classic zone from Wowhead Classic and keeps the quests each one starts (the "!" quests you can pick up) with its places.
Output: tools/crawl/questgivers.txt, one line per NPC that starts quests:
  id|name|area:x,y;x,y~area:...|quest:level:reqlevel:side:name,...
Needs tools/crawl/zone_npcs.json (made by crawl_classic_npcs.py). Slow and polite; it continues where it stopped.
Run (stop crawl_classic_npcs.py first, one crawler at a time): python tools/crawl_questgivers.py"""
import json, os, re, time, urllib.error, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "crawl", "questgivers.txt")
DONE = os.path.join(HERE, "crawl", "questgivers_done.txt")

def fetch(path):
    for a in range(8):
        try:
            time.sleep(1.1)
            return urllib.request.urlopen(urllib.request.Request("https://www.wowhead.com" + path, headers={"User-Agent": "Mozilla/5.0"}), timeout=60).read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code not in (403, 429, 503) or a == 7: raise
            time.sleep(min(30 * 2 ** a, 600))

def listview(html, lv):
    i = html.find("id: '%s'" % lv)
    if i < 0: return []
    s = html.find("[", html.find("data:", i)); d = 0
    for q in range(s, len(html)):
        d += (html[q] == "[") - (html[q] == "]")
        if d == 0: break
    try: return json.loads(re.sub(r"([,{])([A-Za-z_][A-Za-z0-9_]*):", r'\1"\2":', html[s:q + 1]))
    except Exception: return []

zones = json.load(open(os.path.join(HERE, "crawl", "zone_npcs.json"), encoding="utf8"))
npcs = {}
for rows in zones.values():
    for nid, name, cl, lo, hi, typ, react in rows:
        if react == 1 or (lo == 0 and hi == 0): npcs[nid] = name
done = set(int(x) for x in open(DONE).read().split()) if os.path.exists(DONE) else set()
with open(OUT, "a", encoding="utf8", newline="\n") as out, open(DONE, "a") as dn:
    for nid in sorted(npcs):
        if nid in done: continue
        try: html = fetch("/classic/npc=%d" % nid)
        except Exception as e: print(nid, "failed", e, flush=True); continue
        starts = [q for q in listview(html, "starts") if "id" in q]
        if starts:
            pts = []
            i = html.find("g_mapperData = ")
            if i >= 0:
                try: data = json.loads(html[i + 15:html.find(";\n", i)])
                except Exception: data = {}
                for area, arr in (data.items() if isinstance(data, dict) else []):
                    co = [c for part in arr for c in part.get("coords", [])][:3]
                    if co: pts.append("%s:%s" % (area, ";".join("%s,%s" % (c[0], c[1]) for c in co)))
            out.write("%d|%s|%s|%s\n" % (nid, npcs[nid].replace("|", "/"), "~".join(pts),
                ",".join("%d:%d:%d:%d:%s" % (q["id"], q.get("level", 0), q.get("reqlevel", 0), q.get("side", 0), q.get("name", "").replace(",", " ").replace("|", "/")) for q in starts)))
            out.flush()
        dn.write("%d\n" % nid); dn.flush()
