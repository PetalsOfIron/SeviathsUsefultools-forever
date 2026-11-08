"""Copies the curios the addon learned in game (saved variables) into Data/CuriosLearned.lua so a release already has them.

Usage:  python tools/bake_curios.py "<path to SavedVariables/SeviathsUsefulTools.lua>"
Run it after playing with the addon (press 'Scan my account's curios' on the Delve Planner), then commit and release.
"""
import re, sys, os

src = open(sys.argv[1], encoding="utf-8", errors="replace").read()
m = re.search(r'\["learnedCurios"\]\s*=\s*\{', src)
if not m:
    sys.exit("No learned curios in that file yet.")
i, depth = m.end(), 1
j = i
while depth and j < len(src):
    depth += {"{": 1, "}": -1}.get(src[j], 0)
    j += 1
block = src[i:j - 1]
rows = []
for e in re.finditer(r'\["((?:[^"\]|\.)*)"\]\s*=\s*\{(.*?)\}\s*,', block, re.S):
    name, body = e.group(1), e.group(2)
    slot = re.search(r'\["slot"\]\s*=\s*"([^"]*)"', body)
    spell = re.search(r'\["spell"\]\s*=\s*(\d+)', body)
    text = re.search(r'\["text"\]\s*=\s*"((?:[^"\]|\.)*)"', body)
    rows.append('    ["%s"] = { slot = "%s", spell = %s, text = "%s" },' % (
        name, slot.group(1) if slot else "combat", spell.group(1) if spell else "nil", text.group(1) if text else ""))
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Data", "CuriosLearned.lua")
open(out, "w", encoding="utf-8", newline="\n").write(
    "-- SeviathsUsefulTools - curios learned from the game, shipped with the addon (made by tools/bake_curios.py from a played account)\n"
    "local _, SFP = ...\nSFP.CuriosLearned = {\n" + "\n".join(rows) + "\n}\n")
print(len(rows), "curios written to", out)
