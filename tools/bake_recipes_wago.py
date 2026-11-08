"""Adds the crafting recipes of the game tables of WoW Forever (wago.tools CSV of the Forever build, saved as %TEMP%/wf_*.csv: SkillLine, SkillLineAbility,
SpellReagents, SpellEffect, Spell, ItemSparse) to Data/RecipeData.lua: every recipe whose spell number is not in it yet. Run: python tools/bake_recipes_wago.py"""
import csv
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
T = os.environ["TEMP"]


def rd(n):
    return list(csv.DictReader(open(os.path.join(T, "wf_%s.csv" % n), encoding="utf8")))


PROF = {"Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring", "Cooking", "First Aid", "Jewelcrafting", "Mining", "Inscription"}
lines = {r["ID"]: r["DisplayName_lang"] for r in rd("SkillLine") if r["DisplayName_lang"] in PROF}
spells = {r["ID"]: r.get("Name_lang", "") for r in rd("SpellName")}
reag = {}
for r in rd("SpellReagents"):
    lst = []
    for i in range(8):
        a, c = int(r["Reagent_%d" % i] or 0), int(r["ReagentCount_%d" % i] or 0)
        if a > 0 and c > 0:
            lst.append((a, c))
    if lst:
        reag[r["SpellID"]] = lst
out_item = {}
for r in rd("SpellEffect"):
    if r["Effect"] == "24" and int(r["EffectItemType"] or 0) > 0:   # create item
        out_item.setdefault(r["SpellID"], int(r["EffectItemType"]))
path = os.path.join(HERE, "..", "Data", "RecipeData.lua")
text = open(path, encoding="utf8").read()
have = set(re.findall(r"^\{(\d+),", text, re.M))
rows = []
for r in rd("SkillLineAbility"):
    sk = lines.get(r["SkillLine"])
    sid = r["Spell"]
    if not sk or sid in have or sid not in reag:
        continue
    name = spells.get(sid, "")
    if not name:
        continue
    have.add(sid)
    rows.append('{%s,"%s","%s",%d,{%s}},' % (sid, sk, name.replace('"', "'"), out_item.get(sid, 0), ",".join("{%d,%d}" % x for x in reag[sid])))
i = text.rindex("}")
text = text[:i].rstrip("\n") + "\n" + "\n".join(rows) + "\n}\n"
open(path, "w", encoding="utf8", newline="\n").write(text)
print(len(rows), "recipes added")
