"""Reads the quest chains (the "Series" box of each quest page on Wowhead Classic) for every quest of tools/crawl/questgivers.txt, and writes
tools/crawl/quest_prereqs.txt: one line  quest|previous quest  for each quest that has one. A series page lists the whole chain in order, so one page
gives the answer for every quest of it. Slow and polite; it continues where it stopped. Run: python tools/crawl_quest_prereqs.py"""
import os, re, time, urllib.error, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "crawl", "questgivers.txt")
OUT = os.path.join(HERE, "crawl", "quest_prereqs.txt")
DONE = os.path.join(HERE, "crawl", "quest_prereqs_done.txt")

def fetch(qid):
    for a in range(8):
        try:
            time.sleep(1.1)
            return urllib.request.urlopen(urllib.request.Request("https://www.wowhead.com/classic/quest=%d" % qid, headers={"User-Agent": "Mozilla/5.0"}), timeout=60).read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code not in (403, 429, 503) or a == 7: raise
            time.sleep(min(30 * 2 ** a, 600))

quests = []
for line in open(SRC, encoding="utf8").read().splitlines():
    p = line.split("|", 3)
    if len(p) == 4:
        for q in p[3].split(","):
            f = q.split(":")
            if f[0].isdigit(): quests.append(int(f[0]))
done = set(int(x) for x in open(DONE).read().split()) if os.path.exists(DONE) else set()
with open(OUT, "a", encoding="utf8", newline="\n") as out, open(DONE, "a") as dn:
    for qid in sorted(set(quests)):
        if qid in done: continue
        try: html = fetch(qid)
        except Exception as e: print(qid, "failed", e, flush=True); continue
        m = re.search(r'<table class="series">(.*?)</table>', html, re.S)
        ids = []
        if m:
            for row in re.findall(r"<tr>(.*?)</tr>", m.group(1), re.S):
                a = re.search(r"quest=(\d+)", row)
                ids.append(int(a.group(1)) if a else qid)   # the bold entry is this quest
            for i in range(1, len(ids)):
                out.write("%d|%d\n" % (ids[i], ids[i - 1]))
            for q in ids: dn.write("%d\n" % q)
        dn.write("%d\n" % qid); out.flush(); dn.flush()
