"""Bakes Data/Collected.lua: everything the addon collected (players, nameplates, inspects, Raider.IO answers, guilds, NPCs, quests,
loot, materials, towns, spots ...), so the addon uploaded to CurseForge carries it and every player who installs it starts with that data.

    python tools/bake_collected.py            (then upload the addon folder; no /reload needed)

Reads your saved data (WTF/.../SavedVariables/SeviathsUsefulTools.lua) and the file it wrote last time and keeps both: your newer data wins
on the same entry, nothing is lost between bakes. In the game the data is merged into what a player already has (CollectedImport.lua):
world data is overwritten by these values, player records keep the newer one.

What is left out on purpose: your settings, window places, characters/alts, history, and the auction prices (they are old the moment they
are saved).
"""
import glob
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.setrecursionlimit(20000)
from luadata import P, parse_file   # noqa: E402

OUT = os.path.join(HERE, "..", "collected")   # one file per saved table
RETAIL = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
# the monsters and the gray items are shipped in their own load-on-demand addon folder (next to this one in Interface/AddOns): the game reads
# it only when a monster tooltip or a gray item tooltip is shown, or the farm menu opens
LOD = os.path.join(RETAIL, "Interface", "AddOns", "SeviathsUsefulTools_Monsters")

# which saved tables are shipped: { saved global: [keys] }
SHIP = {
    "SeviathsUsefulToolsDB": ["seenInfo", "inspected", "rioCache", "guildDir", "nameplateText", "npcs", "learned", "learnedDecor",
                              "vendorLearned", "itemZones", "hiddenSpots", "bestSpots", "objects", "towns", "npcPos", "killPos",
                              "itemFrom", "playerIDs", "nameRealms", "nameRealm", "seenPlayers", "seenBuilds", "petPrices", "realmGroups", "knownItems", "itemExp", "itemIcon", "petSpots", "petInfo", "itemSpots", "mountStats", "instanceEntrances", "mountSpots", "rareSeen", "learnedCurios", "ahOutcome", "lib"],
    "SeviathsCodexDB": ["quests", "loot", "matUses", "items", "qloc", "lootZones", "npcs", "vendors", "beasts", "vendorItems", "rares"],
    "SeviathsDungeonsRaidsDB": ["dungeon", "raid", "delve", "mplus", "quest"],
}
SKIP_FIELDS = {"noGuildT"}
# the big tables are shipped as one short Lua string per record, decoded only when an entry is read (a table per record costs 5 to 10 times
# more memory in the game than its text)
PACK = {("SeviathsCodexDB", k) for k in ("quests", "loot", "matUses", "items")} | {("SeviathsUsefulToolsDB", k) for k in ("knownItems", "learnedDecor", "npcs")}
BATCH = 40000   # constants per generated function (Lua allows 262143 per function)


def merge(old, new):
    """new wins on the same entry/field; everything only in old stays."""
    if isinstance(old, dict) and isinstance(new, dict):
        out = dict(old)
        for k, v in new.items():
            out[k] = merge(old[k], v) if k in old else v
        return out
    return new


def esc(s):
    return '"%s"' % str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "")


def lua(v):
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            if k in SKIP_FIELDS or x is None:
                continue
            parts.append("[%s]=%s" % (esc(k) if isinstance(k, str) else k, lua(x)))
        return "{" + ",".join(parts) + "}"
    if isinstance(v, list):
        return "{" + ",".join(lua(x) for x in v if x is not None) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return ("%.4f" % v).rstrip("0").rstrip(".") or "0"
    if isinstance(v, int):
        return str(v)
    return esc(v)


def weight(s):
    return s.count(",") + 2


def read_old():
    """The tables of the files written last time: { db: { key: value } }."""
    out = {}
    import re
    for path in sorted(glob.glob(os.path.join(OUT, "*.lua"))) + sorted(glob.glob(os.path.join(LOD, "*.lua"))):
        text = open(path, encoding="utf-8").read()
        p = P(text)
        for m in re.finditer(r'^;?\(function\(\) (Dp|D)\("(\w+)","(\w+)",', text, re.M):
            v, _ = p.value(m.end())
            db, key = m.group(2), m.group(3)
            if m.group(1) == "Dp":
                v = {k: P(x).value(0)[0] for k, x in v.items()}
            cur = out.setdefault(db, {}).get(key)
            out[db][key] = merge(cur, v) if cur is not None else v
    return out


def main():
    data = read_old()
    files = glob.glob(os.path.join(RETAIL, "WTF", "Account", "*", "SavedVariables", "SeviathsUsefulTools.lua"))
    files += [a for a in sys.argv[1:] if a.endswith(".lua") and os.path.exists(a)]   # extra saved files (older backups) can be added
    if not files:
        sys.exit("no saved data found under " + RETAIL)
    # the saved files of the addons this one grew out of (Codex, Farm Pack, Dungeons & Raids): their data is read too
    old_dir = os.path.dirname(files[0])
    for old in ("SeviathsCodex.lua", "SeviathsCodex.lua.bak", "SeviathsFarmPack.lua", "SeviathsFarmPack.lua.bak",
                "SeviathsDungeonsRaids.lua", "SeviathsDungeonsRaids.lua.bak"):
        p = os.path.join(old_dir, old)
        if os.path.exists(p) and p not in files:
            files.append(p)
    for f in files:
        saved = parse_file(f)
        # the Farm Pack's data is what the Useful Tools database holds now
        if "SeviathsFarmPackDB" in saved:
            saved.setdefault("SeviathsUsefulToolsDB", {})
            for k, v in (saved["SeviathsFarmPackDB"] or {}).items():
                saved["SeviathsUsefulToolsDB"].setdefault(k, v)
        for db, keys in SHIP.items():
            for key in keys:
                v = (saved.get(db) or {}).get(key)
                if isinstance(v, (dict, list)) and v:
                    cur = data.setdefault(db, {}).get(key)
                    data[db][key] = merge(cur, v) if cur is not None else v
    # gray items (quality 0) are worth only their vendor price: a short record (name, quality, sell price, class, subclass) instead of the whole
    # item record. They and the monsters go to the load-on-demand folder; everything else stays in collected/
    lod = {}
    tools = data.get("SeviathsUsefulToolsDB") or {}
    # the monsters Wowhead lists drops for, with their places (tools/npc_extra.json, made by bake_npc_spots.py): added when the player's data lacks them
    xp = os.path.join(HERE, "npc_extra.json")
    if os.path.exists(xp):
        import json as _json
        extra = _json.load(open(xp, encoding="utf8"))
        have = tools.setdefault("npcs", {})
        added = 0
        for k, rec in extra.items():
            nid = int(k)
            if nid not in have and k not in have:
                have[nid] = {"n": rec["n"], "k": 0, "m": {int(m): pts for m, pts in rec["m"].items()}}
                added += 1
        print("monsters added from Wowhead:", added)
    if "npcs" in tools:
        npcs = tools.pop("npcs")
        lod.setdefault("SeviathsUsefulToolsDB", {})["npcs"] = npcs
        # which monsters are on which map: the game reads only the records of the map that is shown (and only when it is shown)
        by_map = {}
        for nid, rec in npcs.items():
            if isinstance(rec, dict) and isinstance(rec.get("m"), dict):
                for m in rec["m"]:
                    by_map.setdefault(m, []).append(nid)
        lod["SeviathsUsefulToolsDB"]["npcMaps"] = by_map
    ki = tools.get("knownItems")
    if isinstance(ki, dict):
        keep = ("n", "q", "p", "c", "s", "ic")
        normal = {k: v for k, v in ki.items() if not (isinstance(v, dict) and v.get("q") == 0)}
        gray = {k: {f: v[f] for f in keep if f in v} for k, v in ki.items() if isinstance(v, dict) and v.get("q") == 0}
        tools["knownItems"] = normal
        # the gray items of Wowhead's junk list (tools/junk_items.txt: id|name|icon|level): name and icon of every gray item, also those not picked up yet
        jp = os.path.join(HERE, "junk_items.txt")
        if os.path.exists(jp):
            for line in open(jp, encoding="utf8").read().splitlines():
                parts = line.split("|")
                if len(parts) >= 3 and parts[0].isdigit():
                    jid = int(parts[0])
                    cur = gray.setdefault(jid, {"n": parts[1], "q": 0, "c": 15, "s": 0})
                    if parts[2]:
                        cur.setdefault("ic", parts[2])
        if gray:
            lod.setdefault("SeviathsUsefulToolsDB", {})["knownItems"] = gray
        print("gray items:", len(gray), "of", len(ki))
    stamp = int(time.time())
    short = {"SeviathsUsefulToolsDB": "tools", "SeviathsCodexDB": "codex", "SeviathsDungeonsRaidsDB": "dungeonsraids"}

    def emit(data_set, out_dir, keep_gold):
        lines = []
        for db, keys in data_set.items():
            for key, v in keys.items():
                if not isinstance(v, dict):
                    lines.append((db, key, ';(function() D(%s,%s,%s) end)()' % (esc(db), esc(key), lua(v))))
                    continue
                batch, w = {}, 0
                packed = (db, key) in PACK
                fn = "Dp" if packed else "D"
                for k, x in v.items():
                    s = lua(x)
                    if packed:
                        s = esc(s)   # one string per record
                    batch[k] = s
                    w += (2 if packed else weight(s)) + 1
                    if w >= BATCH:
                        lines.append((db, key, ';(function() %s(%s,%s,{%s}) end)()' % (fn, esc(db), esc(key), ",".join(
                            "[%s]=%s" % (esc(a) if isinstance(a, str) else a, b2) for a, b2 in batch.items()))))
                        batch, w = {}, 0
                if batch:
                    lines.append((db, key, ';(function() %s(%s,%s,{%s}) end)()' % (fn, esc(db), esc(key), ",".join(
                        "[%s]=%s" % (esc(a) if isinstance(a, str) else a, b2) for a, b2 in batch.items()))))
        os.makedirs(out_dir, exist_ok=True)
        for old in glob.glob(os.path.join(out_dir, "*.lua")):
            if not (keep_gold and os.path.basename(old).startswith("gold.")):   # the prices are kept by bake_gold.py
                os.remove(old)
        total = 0
        by_file = {}
        for db, key, text in lines:
            by_file.setdefault((db, key), []).append(text)
        # a table is split into parts of about MAX_FILE bytes (name.key.1.lua, name.key.2.lua ...), so no single file gets huge as the data grows;
        # update_data.py lists whatever files exist in the .toc
        MAX_FILE = 500_000
        n_files = 0
        for (db, key), group in by_file.items():
            parts, cur, size = [], [], 0
            for text in group:
                if cur and size + len(text) > MAX_FILE:
                    parts.append(cur)
                    cur, size = [], 0
                cur.append(text)
                size += len(text)
            if cur:
                parts.append(cur)
            for i2, part in enumerate(parts, 1):
                name = "%s.%s%s.lua" % (short.get(db, db), key, ("." + str(i2)) if len(parts) > 1 else "")
                path = os.path.join(out_dir, name)
                with open(path, "w", encoding="utf-8", newline="\n") as fh:
                    fh.write("-- generated by tools/bake_collected.py: what was collected in the game (%s / %s, part %d of %d)\n" % (db, key, i2, len(parts)))
                    fh.write("local C = SeviathsUsefulToolsCollected or { data = {} }\nSeviathsUsefulToolsCollected = C\nC.date = %d\nC.packed = C.packed or {}\nC.data = C.data or {}\n" % stamp)
                    fh.write("local function Dp(db, key, t)\n  local d = C.packed[db]\n  if not d then d = {}; C.packed[db] = d end\n")
                    fh.write("  local cur = d[key]\n  if not cur then d[key] = t return end\n  for k, v in pairs(t) do cur[k] = v end\nend\n")
                    fh.write("local function D(db, key, t)\n  local d = C.data[db]\n  if not d then d = {}; C.data[db] = d end\n")
                    fh.write("  local cur = d[key]\n  if not cur then d[key] = t return end\n  for k, v in pairs(t) do cur[k] = v end\nend\n")
                    for text in part:
                        fh.write(text + "\n")
                total += os.path.getsize(path)
                n_files += 1
        return len(by_file), n_files, total

    t1 = emit(data, OUT, True)
    t2 = emit(lod, LOD, False)
    # the toc of the load-on-demand folder: loaded by the main addon with C_AddOns.LoadAddOn when a monster or a gray item is looked at
    main_toc = open(os.path.join(HERE, "..", "SeviathsUsefulTools.toc"), encoding="utf-8").read().splitlines()
    interface = next((l for l in main_toc if l.startswith("## Interface")), "## Interface: 120100")
    files = sorted(os.path.basename(p) for p in glob.glob(os.path.join(LOD, "*.lua")))
    with open(os.path.join(LOD, "SeviathsUsefulTools_Monsters.toc"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(interface + "\n## Title: SeviathsUsefulTools - monster and gray item data\n## Notes: Shipped monster drops and gray items, read only when needed.\n")
        fh.write("## Dependencies: SeviathsUsefulTools\n## LoadOnDemand: 1\n## Author: Seviath\n\n")
        fh.write("\n".join(files) + "\n")
    print("%s: %d tables in %d files, %.1f MB" % (os.path.abspath(OUT), t1[0], t1[1], t1[2] / 1e6))
    print("%s: %d tables in %d files, %.1f MB (loaded on demand)" % (os.path.abspath(LOD), t2[0], t2[1], t2[2] / 1e6))


if __name__ == "__main__":
    main()
