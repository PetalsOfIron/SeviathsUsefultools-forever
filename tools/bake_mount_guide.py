"""Bakes Data/MountGuide.lua: where each Battle for Azeroth mount comes from, and what it costs (gold or a special token / currency).

Source: Wowhead's "Battle for Azeroth Mount Guide" (https://www.wowhead.com/guide/mount-collecting-battle-for-azeroth), whose tables ("Mount<TAB>Source")
were saved as text in tools/bfa_mounts.txt (read in a browser).
Output: SFP.MountGuide["Mount name"] = "source text"
Run: python tools/bake_mount_guide.py
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
guide = {}
lines = []
for fn in ("mounts_guides.txt", "mounts_old.txt"):
    if os.path.exists(os.path.join(HERE, fn)):
        lines += open(os.path.join(HERE, fn), encoding="utf8").read().splitlines()
for line in lines:
    if "\t" not in line:
        continue
    name, _, src = line.rstrip("\n").partition("\t")
    name = re.sub(r"\s+", " ", name).strip()
    src = re.sub(r"\s+", " ", src).strip()
    name = re.sub(r"\s*\((Horde|Alliance) Only\)", "", name)
    if not name or not src or name == "Mount" or src == "Source":
        continue
    guide.setdefault(name, src)
out = ["-- SeviathsUsefulTools - where Battle for Azeroth mounts come from and what they cost (made by tools/bake_mount_guide.py from Wowhead's guide)",
       "", "local _, SFP = ...", "", "SFP.MountGuide = {"]
for name in sorted(guide):
    out.append('    ["%s"] = "%s",' % (name.replace('"', '\\"'), guide[name].replace("\\", "\\\\").replace('"', '\\"')))
out.append("}")
# waypoints of the places the guides name (caches, skulls, cauldrons): "uiMapID|x|y|name"
spots = {}
wp = os.path.join(HERE, "mounts_guides_ways.txt")
if os.path.exists(wp):
    for line in open(wp, encoding="utf8"):
        parts = line.strip().split("|")
        if len(parts) == 4:
            lst = spots.setdefault(parts[3].strip(), [])
            lst.append("{ %d, %g, %g }" % (int(parts[0]), round(float(parts[1]) / 100, 4), round(float(parts[2]) / 100, 4)))
out.append("")
out.append("SFP.MountGuideSpots = {")
for name in sorted(spots):
    out.append('    ["%s"] = { %s },' % (name.replace('"', '\\"'), ", ".join(spots[name][:6])))
out.append("}")
open(os.path.join(ADDON, "Data", "MountGuide.lua"), "w", encoding="utf8", newline="\n").write("\n".join(out) + "\n")
print(len(guide), "mounts")
