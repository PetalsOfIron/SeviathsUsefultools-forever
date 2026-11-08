"""Adds the items of your Forever auction house scans that the Classic lists do not have to tools/items_sources.txt, then bakes the item folders again.

Reads the saved data of the Forever client (ahItems: item id -> item class, ahNames: item id -> name). A row is made for every item that is not in
items_sources.txt yet: id|name|quality|source types|sourcemore|item class|subclass|slot|level|required level|list  (list "f" = found at the Forever auction house;
what is not known stays empty or 0). Safe to run again: items already in the list are skipped.
Run: python tools/add_forever_items.py
"""
import glob
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FOREVER = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, HERE)
sys.setrecursionlimit(20000)
from luadata import P, parse_file   # noqa: E402

src = os.path.join(HERE, "items_sources.txt")
have = set()
for line in open(src, encoding="utf8").read().splitlines():
    p = line.split("|")
    if p and p[0].isdigit():
        have.add(int(p[0]))

rows = {}
for f in glob.glob(os.path.join(FOREVER, "WTF", "Account", "*", "SavedVariables", "SeviathsUsefulTools.lua")):
    db = parse_file(f).get("SeviathsUsefulToolsDB", {})

    def table(key):
        v = db.get(key)
        return P(v).value(0)[0] if isinstance(v, str) else (v or {})

    ah, names = table("ahItems"), table("ahNames")
    for iid, cls in ah.items():
        if isinstance(iid, int) and iid not in have and iid not in rows:
            name = names.get(iid)
            if isinstance(name, str) and name:
                rows[iid] = "%d|%s|1|||%s|0|0|1|0|f" % (iid, name.replace("|", "/"), cls if isinstance(cls, int) else 0)

if rows:
    with open(src, "a", encoding="utf8", newline="\n") as fh:
        for iid in sorted(rows):
            fh.write(rows[iid] + "\n")
print("%d new items added to items_sources.txt (the Forever auction house items)" % len(rows))
r = subprocess.run([sys.executable, os.path.join(HERE, "bake_items.py")], capture_output=True, text=True)
print((r.stdout + r.stderr).strip()[-300:])
