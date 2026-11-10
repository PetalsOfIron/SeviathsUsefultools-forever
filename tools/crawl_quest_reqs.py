"""Reads the class and race a quest needs (and whether it is a Season of Discovery quest) from the Wowhead Classic page of every quest of
tools/crawl/questgivers.txt, and writes tools/crawl/quest_reqs.txt: one line  quest|class mask|race mask|sod  (sod 1 = Season of Discovery).
Slow and polite (1.1 s per page); it continues where it stopped. Run: python tools/crawl_quest_reqs.py   then   python tools/bake_quest_reqs.py"""
import os, re, time, urllib.error, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "crawl", "questgivers.txt")
OUT = os.path.join(HERE, "crawl", "quest_reqs.txt")

def fetch(qid):
    for a in range(8):
        try:
            time.sleep(1.1)
            return urllib.request.urlopen(urllib.request.Request("https://www.wowhead.com/classic/quest=%d" % qid, headers={"User-Agent": "Mozilla/5.0"}), timeout=60).read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code == 404: return ""
            if e.code not in (403, 429, 503) or a == 7: raise
            time.sleep(min(30 * 2 ** a, 600))

quests = set()
for line in open(SRC, encoding="utf8").read().splitlines():
    p = line.split("|", 3)
    if len(p) == 4:
        for q in p[3].split(","):
            f = q.split(":")
            if f[0].isdigit(): quests.add(int(f[0]))
done = set()
if os.path.exists(OUT):
    for l in open(OUT, encoding="utf8").read().splitlines():
        if l.split("|")[0].isdigit(): done.add(int(l.split("|")[0]))
import threading
from concurrent.futures import ThreadPoolExecutor
lock = threading.Lock()
out = open(OUT, "a", encoding="utf8", newline="
")
def work(qid):
    try: html = fetch(qid)
    except Exception as e: print(qid, "failed", e, flush=True); return
    h = html.replace(chr(92) + "/", "/")
    m = re.search(r'g_quests\[%d\], (\{.*?\})\);' % qid, h)
    blob = m.group(1) if m else ""
    cm = re.search(r'"reqclass":(\d+)', blob); rm = re.search(r'"reqrace":(\d+)', blob)
    sod = 1 if re.search(r'Added in patch.{0,120}Season of Discovery', h) else 0
    with lock:
        out.write("%d|%s|%s|%d
" % (qid, cm.group(1) if cm else 0, rm.group(1) if rm else 0, sod)); out.flush()
with ThreadPoolExecutor(max_workers=6) as ex:
    list(ex.map(work, sorted(quests - done)))
out.close()
