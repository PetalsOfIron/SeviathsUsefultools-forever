"""Bakes Data/QuestDB.lua and Data/QuestStarts.lua from the Questie addon (and its QuestieDB data addon) installed next to this one.

Questie (GPL-3.0, https://github.com/Questie/Questie and https://github.com/Questie/QuestieDB) keeps the complete quest database of the game:
who starts each quest and where that NPC / object stands, the level, race and class a quest needs, the quests before it (a group that must all be
done, or a list of which one is enough), quests that exclude each other, breadcrumbs, repeatable / daily flags, reputation and profession needs.
This script reads that data (a read of the metadata lines of QuestieDB_Forever.toc) and the list of quests Questie hides (QuestieQuestBlacklist.lua),
and writes it in the form this addon uses:

  SFP.QDB[quest]        the rules of a quest (see RULE_KEYS)
  SFP.QStarts[uiMapId]  the quest starters of a zone: { name, x, y, { quest numbers }, faction }
  SFP.QEvents[quest]    the holiday a quest belongs to

Run:  python tools/bake_questie.py        (needs: pip install cbor2)
"""
import base64
import collections
import glob
import os
import re
import sys

import cbor2

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.abspath(os.path.join(HERE, ".."))
ADDONS = os.path.dirname(ADDON)
QDB_DIR = os.path.join(ADDONS, "QuestieDB")
if not os.path.isdir(QDB_DIR):   # not installed in the game: the Forever release of QuestieDB (https://github.com/Questie/QuestieDB/releases) unpacked anywhere
    QDB_DIR = os.environ.get("QUESTIEDB_DIR") or os.path.join(os.environ.get("TEMP", "."), "qdb_dl", "x", "QuestieDB")
DB_TOC = os.path.join(QDB_DIR, "QuestieDB_Forever.toc")
ZONES = os.path.join(QDB_DIR, "support", "Forever", "Zones")
QUESTIE = os.path.join(ADDONS, "Questie")
if not os.path.isdir(QUESTIE):   # Questie itself is not installed: a clone of https://github.com/Questie/Questie (git clone --depth 1) is read instead
    QUESTIE = os.environ.get("QUESTIE_SRC") or os.path.join(os.environ.get("TEMP", "."), "questie_src")

# quest fields (QuestieDB/src/meta/questMeta.lua)
Q = dict(name=1, startedBy=2, finishedBy=3, requiredLevel=4, questLevel=5, requiredRaces=6, requiredClasses=7, objectivesText=8, preQuestGroup=12,
         preQuestSingle=13, childQuests=14, exclusiveTo=16, zoneOrSort=17, requiredSkill=18, requiredMinRep=19, requiredMaxRep=20, nextQuestInChain=22,
         questFlags=23, specialFlags=24, parentQuest=25, breadcrumbForQuestId=27, breadcrumbs=28, requiredSpell=30, requiredSpecialization=31,
         requiredMaxLevel=32, availableUntilCompleted=33, availableStartingWith=34, requiredRanks=35, disabledByQuest=36)
TABLE_FIELDS = {2, 3, 8, 12, 13, 14, 15, 16, 18, 19, 20, 28, 35}
NPC = dict(name=1, spawns=7, friendlyToFaction=13)
OBJ = dict(name=1, spawns=4)


def read_store():
    kv = {}
    for line in open(DB_TOC, encoding="utf-8"):
        m = re.match(r"## (X-[A-Za-z]+-[^:]+): (.*)", line.rstrip("\n"))
        if m:
            kv[m.group(1)] = m.group(2)
    return kv


def stored(kv, key):
    v = kv.get(key)
    if v is None:
        return None
    m = re.fullmatch(r"~(\d+)~", v)
    if m:
        return "".join(kv["%s-%d" % (key, i)] for i in range(1, int(m.group(1)) + 1))
    return v


def row(kv, prefix, ident):
    s = kv.get("X-%s-%d-S" % (prefix, ident))
    if s is None:
        return None
    r = cbor2.loads(base64.b64decode(s))
    return r if isinstance(r, dict) else None   # a list is a placeholder row ("REUSE ME")


def table_field(kv, prefix, ident, field):
    s = stored(kv, "X-%s-%d-%d" % (prefix, ident, field))
    return cbor2.loads(base64.b64decode(s)) if s else None


def text(v):
    return v.decode("utf-8", "replace") if isinstance(v, bytes) else v


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


# ---- zones: area id -> UiMapId -------------------------------------------------------------------------------------------------------------
def area_to_map():
    s = open(os.path.join(ZONES, "areaIdToUiMapId.lua"), encoding="utf-8").read()
    mp = {}
    m = re.search(r"areaIdToUiMapIdOverride = \[\[return \{(.*?)\n\}\]\]", s, re.S)
    override_text = m.group(1) if m else ""
    rest = s.replace(override_text, "")
    for a, b in re.findall(r"^\s*\[(\d+)\]\s*=\s*(\d+)", rest, re.M):
        mp[int(a)] = int(b)
    for a, b in re.findall(r"^\s*\[(\d+)\]\s*=\s*(\d+)", override_text, re.M):
        mp[int(a)] = int(b)
    sub = {}
    t = open(os.path.join(ZONES, "subZoneToParentZone.lua"), encoding="utf-8").read()
    for a, b in re.findall(r"^\s*\[(\d+)\]\s*=\s*(\d+)", t, re.M):
        sub[int(a)] = int(b)
    return mp, sub


# ---- the quests Questie hides ----------------------------------------------------------------------------------------------------------------
def blacklist():
    """QuestieQuestBlacklist:Load() for Forever: the content of the Era (everything of Era is in, no season): the entries are true, false, HIDE_ON_MAP or a
    condition of Expansions / Questie flags / ContentPhases that is worked out here."""
    src = open(os.path.join(QUESTIE, "Database", "Corrections", "QuestieQuestBlacklist.lua"), encoding="utf-8").read()
    body = src[src.index("local questsToBlacklist = {"): src.index("    if Questie.IsSoD then")]
    ns = {"Expansions": collections.namedtuple("E", "Current Era Tbc Wotlk Cata MoP")(1, 1, 2, 3, 4, 5), "HIDE_ON_MAP": "HIDE_ON_MAP"}

    class Flags:
        def __getattr__(self, k):
            return False
    ns["Questie"] = Flags()
    ns["ContentPhases"] = type("CP", (), {"activePhases": type("AP", (), {"SoM": 5, "SoD": 7, "Anniversary": 6, "MoP": 5, "TBC": 4})()})()
    hidden, on_map_hidden, failed = set(), set(), []
    for m in re.finditer(r"^\s*\[(\d+)\]\s*=\s*([^\n]*?),?\s*(?:--.*)?$", body, re.M):
        qid, expr = int(m.group(1)), m.group(2).strip().rstrip(",").strip()
        if not expr:
            continue
        e = expr
        e = re.sub(r"~=", "!=", e)
        e = re.sub(r"\bnot\b", " not ", e)
        e = e.replace("true", "True").replace("false", "False")
        e = re.sub(r"\bnil\b", "None", e)
        try:
            v = eval(e, {"__builtins__": {}}, {"Expansions": ns["Expansions"], "Questie": ns["Questie"], "ContentPhases": ns["ContentPhases"],
                                                "HIDE_ON_MAP": "HIDE_ON_MAP", "True": True, "False": False})
        except Exception:
            failed.append((qid, expr))
            v = False
        if v == "HIDE_ON_MAP" or v is True:
            hidden.add(qid)
    return hidden, failed


def _eval_entries(text_block):
    """entries '[id] = true / false / expression,' of a Questie Lua table -> set of the ids that are true (conditions of Expansions / Questie flags /
    ContentPhases worked out for the Era: no season, everything of Era in)"""
    E = collections.namedtuple("E", "Current Era Tbc Wotlk Cata MoP")(1, 1, 2, 3, 4, 5)

    class Flags:
        def __getattr__(self, k):
            return False
    CP = type("CP", (), {"activePhases": type("AP", (), {"SoM": 5, "SoD": 7, "Anniversary": 6, "MoP": 5, "TBC": 4})()})()
    out = set()
    for m in re.finditer(r"^\s*\[(\d+)\]\s*=\s*([^\n]*?),?\s*(?:--.*)?$", text_block, re.M):
        qid, expr = int(m.group(1)), m.group(2).strip().rstrip(",").strip()
        if not expr:
            continue
        e = re.sub(r"~=", "!=", expr)
        e = re.sub(r"not", " not ", e).replace("true", "True").replace("false", "False")
        e = re.sub(r"nil", "None", e)
        try:
            v = eval(e, {"__builtins__": {}}, {"Expansions": E, "Questie": Flags(), "ContentPhases": CP, "HIDE_ON_MAP": "HIDE_ON_MAP", "True": True, "False": False})
        except Exception:
            v = False
        if v is True or v == "HIDE_ON_MAP":
            out.add(qid)
    return out


def npc_blacklist():
    src = open(os.path.join(QUESTIE, "Database", "Corrections", "QuestieNPCBlacklist.lua"), encoding="utf-8").read()
    return _eval_entries(src[src.index("return {"):])


def aq_war_effort():
    """the AQ war effort quests: Questie hides them by default (showAQWarEffortQuests = false)"""
    src = open(os.path.join(QUESTIE, "Database", "Corrections", "QuestieQuestBlacklist.lua"), encoding="utf-8").read()
    i = src.index("QuestieQuestBlacklist.AQWarEffortQuests = {")
    block = src[i: src.index("\n}", i)]
    return set(int(x) for x in re.findall(r"^\s*\[(\d+)\]\s*=\s*true", block, re.M))


# ---- holiday quests ---------------------------------------------------------------------------------------------------------------------------
CAL = {"Hallow": "Hallow", "Winter": "Winter Veil", "Lunar": "Lunar", "Love": "Love", "Midsummer": "Midsummer", "Harvest": "Harvest", "Children": "Children",
       "Darkmoon": "Darkmoon", "Brewfest": "Brewfest", "Noblegarden": "Noblegarden", "Day of the Dead": "Day of the Dead",
       "Pilgrim": "Pilgrim"}


def holiday_quests():
    """quest -> the word of the game's calendar event (tinsert(eventQuests, {"Hallow's End", 1657}) in Questie's Holidays folder)"""
    out = {}
    for f in glob.glob(os.path.join(QUESTIE, "Database", "Corrections", "Holidays", "quests", "*.lua")):
        s = open(f, encoding="utf-8").read()
        for name, q in re.findall(r'\{\s*"([^"]+)"\s*,\s*(\d+)\s*\}', s):
            for word, cal in CAL.items():
                if name.startswith(word):
                    out[int(q)] = cal
    return out


def main():
    kv = read_store()
    amap, sub = area_to_map()
    hidden, failed = blacklist()
    print("hidden by Questie:", len(hidden), "conditions not worked out:", len(failed), failed[:5])
    holidays = holiday_quests()
    bad_npcs, aq = npc_blacklist(), aq_war_effort()
    print("hidden NPCs:", len(bad_npcs), "AQ war effort quests:", len(aq))
    hidden = hidden | aq

    quest_ids = sorted(int(m.group(1)) for k in kv for m in [re.fullmatch(r"X-Quest-(\d+)-S", k)] if m)
    print("quests in the database:", len(quest_ids))

    npc_cache, obj_cache = {}, {}

    def npc(i):
        if i not in npc_cache:
            r = row(kv, "Npc", i)
            if r is None:
                npc_cache[i] = None
            else:
                sp = table_field(kv, "Npc", i, NPC["spawns"]) or {}
                npc_cache[i] = (text(r.get(1)), sp, text(r.get(13)))
        return npc_cache[i]

    def obj(i):
        if i not in obj_cache:
            r = row(kv, "Object", i)
            if r is None:
                obj_cache[i] = None
            else:
                sp = table_field(kv, "Object", i, OBJ["spawns"]) or {}
                obj_cache[i] = (text(r.get(1)), sp, None)
        return obj_cache[i]

    rules, starts = {}, collections.defaultdict(dict)   # starts[map][(name, x, y, faction)] = set(quests)
    for qid in quest_ids:
        if qid in hidden and qid not in holidays:   # (the holiday quests are hidden in the list and shown by Questie only while their event runs)
            continue
        r = row(kv, "Quest", qid)
        if r is None:
            continue
        flags = r.get(b"p", 0)
        def tf(name):
            f = Q[name]
            if (flags >> (f - 1)) & 1:
                return table_field(kv, "Quest", qid, f)
            return None
        started = tf("startedBy") or {}
        if isinstance(started, dict):      # a sparse list is stored as a map with the positions (1, 2, 3) as keys
            npc_ids, obj_ids = started.get(1) or [], started.get(2) or []
        else:
            npc_ids = started[0] if len(started) > 0 and started[0] else []
            obj_ids = started[1] if len(started) > 1 and started[1] else []
        for kind, ids, getter in (("npc", npc_ids, npc), ("obj", obj_ids, obj)):
            for i in ids:
                if kind == "npc" and i in bad_npcs:
                    continue
                d = getter(i)
                if not d:
                    continue
                name, spawns, faction = d
                if not isinstance(spawns, dict):
                    continue
                for area, pts in (spawns or {}).items():
                    ui = amap.get(area)
                    if ui is None:
                        ui = amap.get(sub.get(area, -1))
                    if not ui:
                        continue
                    for p in (pts or [])[:6]:
                        if p[0] is None or p[0] < 0:
                            continue
                        key = (name, round(p[0], 1), round(p[1], 1), faction or "")
                        starts[ui].setdefault(key, set()).add(qid)
        rule = {"n": text(r.get(1)), "l": r.get(5), "r": r.get(4), "m": r.get(32), "rc": r.get(6), "cl": r.get(7), "nx": r.get(22), "fl": r.get(23),
                "sf": r.get(24), "pa": r.get(25), "bf": r.get(27), "au": r.get(33), "as": r.get(34), "db": r.get(36), "sp": r.get(30), "ss": r.get(31)}
        for short, name in (("pg", "preQuestGroup"), ("ps", "preQuestSingle"), ("ex", "exclusiveTo"), ("br", "breadcrumbs"), ("sk", "requiredSkill"),
                            ("mr", "requiredMinRep"), ("xr", "requiredMaxRep"), ("rk", "requiredRanks")):
            v = tf(name)
            if v:
                rule[short] = v
        if qid in holidays:
            rule["ev"] = holidays[qid]
        rules[qid] = {k: v for k, v in rule.items() if v not in (None, 0, [], "")}

    # ---- write ----------------------------------------------------------------------------------------------------------------------------------
    def lv(v):
        if isinstance(v, bool):
            return "true" if v else "false"
        if isinstance(v, (int, float)):
            return str(int(v)) if float(v).is_integer() else repr(round(v, 2))
        if isinstance(v, str):
            return lua_str(v)
        if isinstance(v, (list, tuple)):
            return "{" + ",".join(lv(x) for x in v) + "}"
        return "nil"

    lines = ["-- SeviathsUsefulTools - the quest database of the game: rules of each quest (level, race, class, quests before it, exclusive quests, breadcrumbs,",
             "-- reputation / profession needs, repeatable flags) and the starters of quests by zone. Generated by tools/bake_questie.py from the data of Questie",
             "-- and QuestieDB (GPL-3.0, https://github.com/Questie/Questie): thank you to everyone who built that database.",
             "local _, SFP = ...", "SFP.QDB = {"]
    for qid in sorted(rules):
        parts = ",".join("%s=%s" % (k, lv(v)) for k, v in rules[qid].items())
        lines.append("[%d]={%s}," % (qid, parts))
    lines += ["}", ""]
    open(os.path.join(ADDON, "Data", "QuestDB.lua"), "w", encoding="utf-8", newline="\n").write("\n".join(lines))

    lines = ["-- SeviathsUsefulTools - the quest starters of each zone (UiMapId): { name, x, y, { quest numbers }, faction }. Generated by tools/bake_questie.py",
             "-- from the data of Questie / QuestieDB (GPL-3.0).", "local _, SFP = ...", "SFP.QStarts = {"]
    total = 0
    for ui in sorted(starts):
        lines.append("[%d]={" % ui)
        for (name, x, y, faction), qs in sorted(starts[ui].items(), key=lambda kv_: (kv_[0][0], kv_[0][1], kv_[0][2])):
            qs = sorted(q for q in qs if q in rules)
            if not qs:
                continue
            total += 1
            lines.append("{%s,%s,%s,{%s}%s}," % (lua_str(name), lv(x), lv(y), ",".join(str(q) for q in qs), (",%s" % lua_str(faction)) if faction else ""))
        lines.append("},")
    lines += ["}", ""]
    open(os.path.join(ADDON, "Data", "QuestStarts.lua"), "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("quests with rules:", len(rules), "- starter marks:", total, "- zones:", len(starts))


if __name__ == "__main__":
    sys.exit(main())
