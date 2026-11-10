"""Reads what a quest needs from the Wowhead Classic page of every quest of tools/crawl/questgivers.txt and writes tools/crawl/quest_reqs.txt:
one line  quest|class mask|race mask|sod|prerequisite quests  (sod 1 = Season of Discovery; the prerequisites are quest numbers joined by commas, the quests
that must be turned in before this one is offered). Slow and polite; it continues where it stopped.
Run: python tools/crawl_quest_reqs.py   then   python tools/bake_quest_reqs.py"""
import os, re, threading, time, urllib.error, urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "crawl", "questgivers.txt")
OUT = os.path.join(HERE, "crawl", "quest_reqs.txt")
BS = chr(92)
WORKERS = 3


def fetch(qid):
    for a in range(10):
        try:
            time.sleep(1.5)
            req = urllib.request.Request("https://www.wowhead.com/classic/quest=%d" % qid, headers={"User-Agent": "Mozilla/5.0"})
            return urllib.request.urlopen(req, timeout=60).read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return ""
            if e.code not in (403, 429, 503) or a == 9:
                raise
            time.sleep(min(30 * 2 ** a, 900))


def prereqs(h, qid):
    """the quests that must be done before this one: the quest before it in the series box and the quests of a 'Prerequisite' list of the page"""
    out = []
    m = re.search(r'<table class="series">(.*?)</table>', h, re.S)
    if m:
        ids = []
        for row in re.findall(r"<tr>(.*?)</tr>", m.group(1), re.S):
            a = re.search(r"quest=(\d+)", row)
            ids.append(int(a.group(1)) if a else qid)
        if qid in ids and ids.index(qid) > 0:
            out.append(ids[ids.index(qid) - 1])
    for mm in re.finditer(r"(?:Prerequisite|Requires quest)[^<]{0,40}", h):
        seg = h[mm.start(): mm.start() + 600]
        for q in re.findall(r"quest=(\d+)", seg):
            if int(q) != qid and int(q) not in out:
                out.append(int(q))
    return out


quests = set()
for line in open(SRC, encoding="utf8").read().splitlines():
    p = line.split("|", 3)
    if len(p) == 4:
        for q in p[3].split(","):
            f = q.split(":")
            if f[0].isdigit():
                quests.add(int(f[0]))
done = set()
if os.path.exists(OUT):
    for l in open(OUT, encoding="utf8").read().splitlines():
        if l.split("|")[0].isdigit() and len(l.split("|")) >= 6:
            done.add(int(l.split("|")[0]))
lock = threading.Lock()
out = open(OUT, "a", encoding="utf8", newline="\n")


def work(qid):
    try:
        html = fetch(qid)
    except Exception as e:
        print(qid, "failed", e, flush=True)
        return
    h = html.replace(BS + "/", "/")
    m = re.search(r"g_quests\[%d\], (\{.*?\})\);" % qid, h)
    blob = m.group(1) if m else ""
    cm = re.search(r'"reqclass":(\d+)', blob)
    rm = re.search(r'"reqrace":(\d+)', blob)
    sod = 1 if re.search(r"Added in patch.{0,120}Season of Discovery", h) else 0
    pre = ",".join(str(x) for x in prereqs(h, qid))
    # repeatable, daily and weekly quests (the blue "!" of the game): the box of the page says "Repeatable" / "Daily" / "Weekly"
    mk = re.search(r'WH.markup.printHtml\("(.*?)"\)', h, re.S)
    rep = 1 if mk and re.search(r"\[li\](Repeatable|Daily|Weekly|Monthly)", mk.group(1)) else 0
    with lock:
        out.write("%d|%s|%s|%d|%s|%d\n" % (qid, cm.group(1) if cm else 0, rm.group(1) if rm else 0, sod, pre, rep))
        out.flush()


with ThreadPoolExecutor(max_workers=WORKERS) as ex:
    list(ex.map(work, sorted(quests - done)))
out.close()
