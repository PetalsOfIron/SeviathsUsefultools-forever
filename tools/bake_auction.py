"""Copies the auction house items the addon learned (item ID, section, name) into Data/AuctionItems.lua so a release already has them.

Usage:  python tools/bake_auction.py "<path to SavedVariables/SeviathsUsefulTools.lua>"
Needs: pip install lupa. Run it after a scan and a /reload (names fill in a few minutes after the scan). Prices are never included.
"""
import os, sys
from lupa.lua54 import LuaRuntime

L = LuaRuntime()
L.execute(open(sys.argv[1], encoding="utf-8", errors="replace").read())
db = L.eval("SeviathsUsefulToolsDB")
items = db["ahItems"]
names = db["ahNames"]
if not items:
    sys.exit("No auction items in that file yet.")
rows = []
for k in sorted(int(x) for x in items.keys()):
    cls = int(items[k])
    nm = names[k] if names else None
    nm = (nm or "").replace("\\", "\\\\").replace('"', '\\"')
    rows.append('[%d]={%d,"%s"},' % (k, cls, nm))
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Data", "AuctionItems.lua")
open(out, "w", encoding="utf-8", newline="\n").write(
    "-- SeviathsUsefulTools - auction house items learned from a played account: [itemID] = { section (item class), name }\n"
    "-- Made by tools/bake_auction.py. No prices: those belong to each player's own realm.\n"
    "local _, SFP = ...\nSFP.AuctionItems = {\n" + "\n".join(rows) + "\n}\n")
print(len(rows), "items,", sum(1 for r in rows if not r.endswith('""},')), "with a name ->", out)
