"""Copies the housing decor the addon learned in game (saved variables) into Data/DecorLearned.lua.

Usage:  python tools/bake_decor.py "<path to SavedVariables/SeviathsUsefulTools.lua>"
Run it after opening the Housing Decor window in game with the housing catalog available, then commit and release.
Rows: { itemID, decorID (0 = unknown), name, source }.
"""
import re, sys, os

src = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(r'\["learnedDecor"\]\s*=\s*\{', src)
if not m:
    sys.exit("No learned decor in that file yet.")
i, depth = m.end(), 1
j = i
while depth and j < len(src):
    depth += {"{": 1, "}": -1}.get(src[j], 0)
    j += 1
block = src[i:j - 1]
rows = []
for e in re.finditer(r'\["((?:[^"\]|\.)*)"\]\s*=\s*\{(.*?)\}\s*,', block, re.S):
    key, body = e.group(1), e.group(2)
    g = lambda f, pat: (re.search(r'\["%s"\]\s*=\s*%s' % (f, pat), body) or [None, None])[1]
    rows.append('    { %s, %s, "%s", "%s" },' % (g("item", r"(\d+)") or "0", g("decor", r"(\d+)") or "0", g("name", r'"((?:[^"\]|\.)*)"') or key, g("source", r'"((?:[^"\]|\.)*)"') or ""))
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Data", "DecorLearned.lua")
open(out, "w", encoding="utf-8", newline="\n").write(
    "-- SeviathsUsefulTools - housing decor learned from the game, shipped with the addon (made by tools/bake_decor.py from a played account)\n"
    "local _, SFP = ...\nSFP.DecorLearned = {\n" + "\n".join(rows) + "\n}\n")
print(len(rows), "decor rows written to", out)
