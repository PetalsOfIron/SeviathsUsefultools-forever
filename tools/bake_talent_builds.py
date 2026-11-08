"""Bakes Data/TalentBuilds.lua: the recommended talent builds (import strings) of every specialization.

The builds are read from the public Method.gg talent page of each specialization (one request every few seconds) and written
as plain data: build name, what it is for (raid, Mythic+, delves, other) and the talent import string.
A WoW addon cannot open web pages, so the data is refreshed here, outside the game. Run it again after a patch or once a week:

    python tools/bake_talent_builds.py

then /reload the game. The date of the guide and the patch are saved with the data and shown in the addon.
"""
import html
import os
import re
import sys
import time
import urllib.request

# (class token, specialization name as the game shows it, Method.gg page slug)
SPECS = [
    ("DEATHKNIGHT", "Blood", "blood-death-knight"), ("DEATHKNIGHT", "Frost", "frost-death-knight"), ("DEATHKNIGHT", "Unholy", "unholy-death-knight"),
    ("DEMONHUNTER", "Havoc", "havoc-demon-hunter"), ("DEMONHUNTER", "Vengeance", "vengeance-demon-hunter"), ("DEMONHUNTER", "Devourer", "devourer-demon-hunter"),
    ("DRUID", "Balance", "balance-druid"), ("DRUID", "Feral", "feral-druid"), ("DRUID", "Guardian", "guardian-druid"), ("DRUID", "Restoration", "restoration-druid"),
    ("EVOKER", "Devastation", "devastation-evoker"), ("EVOKER", "Preservation", "preservation-evoker"), ("EVOKER", "Augmentation", "augmentation-evoker"),
    ("HUNTER", "Beast Mastery", "beast-mastery-hunter"), ("HUNTER", "Marksmanship", "marksmanship-hunter"), ("HUNTER", "Survival", "survival-hunter"),
    ("MAGE", "Arcane", "arcane-mage"), ("MAGE", "Fire", "fire-mage"), ("MAGE", "Frost", "frost-mage"),
    ("MONK", "Brewmaster", "brewmaster-monk"), ("MONK", "Mistweaver", "mistweaver-monk"), ("MONK", "Windwalker", "windwalker-monk"),
    ("PALADIN", "Holy", "holy-paladin"), ("PALADIN", "Protection", "protection-paladin"), ("PALADIN", "Retribution", "retribution-paladin"),
    ("PRIEST", "Discipline", "discipline-priest"), ("PRIEST", "Holy", "holy-priest"), ("PRIEST", "Shadow", "shadow-priest"),
    ("ROGUE", "Assassination", "assassination-rogue"), ("ROGUE", "Outlaw", "outlaw-rogue"), ("ROGUE", "Subtlety", "subtlety-rogue"),
    ("SHAMAN", "Elemental", "elemental-shaman"), ("SHAMAN", "Enhancement", "enhancement-shaman"), ("SHAMAN", "Restoration", "restoration-shaman"),
    ("WARLOCK", "Affliction", "affliction-warlock"), ("WARLOCK", "Demonology", "demonology-warlock"), ("WARLOCK", "Destruction", "destruction-warlock"),
    ("WARRIOR", "Arms", "arms-warrior"), ("WARRIOR", "Fury", "fury-warrior"), ("WARRIOR", "Protection", "protection-warrior"),
]

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Data", "TalentBuilds.lua")


def fetch(slug):
    req = urllib.request.Request(
        "https://www.method.gg/guides/" + slug + "/talents",
        headers={"User-Agent": "Mozilla/5.0"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", "replace")


def content_of(name):
    n = name.lower()
    kinds = []
    if "delve" in n:
        kinds.append("delves")
    if "mythic" in n or "m+" in n or "dungeon" in n:
        kinds.append("mythic")
    if "raid" in n or "single target" in n or "boss" in n:
        kinds.append("raid")
    if not kinds:
        kinds.append("other")
    return kinds


def parse(page):
    builds = []
    for block in page.split('<div class="df-talent-block">')[1:]:
        h = re.search(r"<h3>(.*?)</h3>", block, re.S)
        t = re.search(r'data-talent="([A-Za-z0-9+/]{40,})"', block)
        if not (h and t):
            continue
        name = html.unescape(re.sub(r"<[^>]+>", "", h.group(1))).strip().rstrip(":")
        builds.append((name, t.group(1)))
    patch = re.search(r"Patch[^0-9]{0,40}(\d+\.\d+\.\d+)", page)
    updated = re.search(r"Last Updated[^A-Za-z0-9]{0,40}([0-9]{1,2}(?:st|nd|rd|th)? [A-Za-z]{3,9},? ?[0-9]{4})", page)
    return builds, (patch.group(1) if patch else "?"), (updated.group(1) if updated else "?")


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


TANKS = {("DEATHKNIGHT", "Blood"), ("DEMONHUNTER", "Vengeance"), ("DRUID", "Guardian"), ("MONK", "Brewmaster"), ("PALADIN", "Protection"), ("WARRIOR", "Protection")}
HEALERS = {("DRUID", "Restoration"), ("EVOKER", "Preservation"), ("MONK", "Mistweaver"), ("PALADIN", "Holy"), ("PRIEST", "Discipline"), ("PRIEST", "Holy"), ("SHAMAN", "Restoration")}
CLASS_SLUG = {"DEATHKNIGHT": "death-knight", "DEMONHUNTER": "demon-hunter"}


def fetch_wowhead(cls, spec):
    role = "tank" if (cls, spec) in TANKS else "healer" if (cls, spec) in HEALERS else "dps"
    url = "https://www.wowhead.com/guide/classes/%s/%s/talent-builds-pve-%s" % (
        CLASS_SLUG.get(cls, cls.lower()), spec.lower().replace(" ", "-"), role)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", "replace")


def parse_wowhead(page):
    """Rows of the build tables: a hero tree icon, the build's label and its import code."""
    builds = []
    pat = re.compile(r'wow-hero-talent-([a-z-]+)\](.{0,260}?)\[copy=\\"([^"\\]*)\\"\]([A-Za-z0-9+/]{40,})\[\\/copy\]', re.S)
    for m in pat.finditer(page):
        hero = m.group(1).replace("-", " ").title()
        label = html.unescape(m.group(3)).strip()
        builds.append((hero + " " + label + " (Wowhead)", m.group(4)))
    return builds


def read_old():
    """The rows of the file written last time: builds that are no longer on the guide pages are kept (older seasons)."""
    old = {}
    if not os.path.exists(OUT):
        return old
    text = open(OUT, encoding="utf-8").read()
    for line in text.splitlines():
        m = re.match(r'B\["([^"]+)"\] = \{(.*)\}\s*$', line)
        if not m:
            continue
        for r in re.finditer(r'\{"((?:[^"\\]|\\.)*)","([^"]*)","([A-Za-z0-9+/]+)"(?:,"([^"]*)","([^"]*)")?\}', m.group(2)):
            name = r.group(1).replace('\\"', '"').replace("\\\\", "\\")
            old.setdefault(m.group(1), []).append((name, r.group(2), r.group(3), r.group(4) or "M", r.group(5) or ""))
    return old


def main():
    today = time.strftime("%Y-%m-%d")
    out = []
    total = 0
    kept_old = 0
    patch_seen = {}
    old = read_old()
    for cls, spec, slug in SPECS:
        key = cls + ":" + spec
        print("reading", spec, cls, file=sys.stderr)
        current = []   # (name, string, source)
        patch, updated = "?", "?"
        try:
            builds, patch, updated = parse(fetch(slug))
            current += [(n, s, "M") for n, s in builds]
        except Exception as e:  # keep going: one failed page must not lose the others
            print("  Method FAILED:", e, file=sys.stderr)
        time.sleep(3)
        try:
            current += [(n, s, "W") for n, s in parse_wowhead(fetch_wowhead(cls, spec))]
        except Exception as e:
            print("  Wowhead FAILED:", e, file=sys.stderr)
        time.sleep(3)
        print("  ", len(current), "builds, patch", patch, updated, file=sys.stderr)
        if not current and key not in old:
            continue
        patch_seen[patch] = patch_seen.get(patch, 0) + 1
        rows = []
        have = set()
        for name, string, src in current:
            if string in have:
                continue
            have.add(string)
            rows.append("{%s,%s,%s,%s,\"\"}," % (lua_str(name), lua_str(",".join(content_of(name))), lua_str(string), lua_str(src)))
            total += 1
        # builds of earlier bakes that the guides do not show any more: kept, dated by when they were last on a page
        for name, kinds, string, src, date in old.get(key, []):
            if string in have:
                continue
            have.add(string)
            rows.append("{%s,%s,%s,%s,%s}," % (lua_str(name), lua_str(kinds), lua_str(string), lua_str(src), lua_str(date or today)))
            kept_old += 1
        out.append('B[%s] = { updated = %s, patch = %s, %s }' % (lua_str(key), lua_str(updated), lua_str(patch), "".join(rows)))
    patch = max(patch_seen, key=patch_seen.get) if patch_seen else "?"
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- SeviathsUsefulTools - recommended talent builds of every specialization (generated by tools/bake_talent_builds.py)\n")
        f.write("-- Read from the public Method.gg and Wowhead talent pages. Row: { build name, content (raid, mythic, delves, other), import string,\n")
        f.write("-- source (M Method, W Wowhead), date it was last on a guide page (empty = on a page now; a date = an older season's build) }.\n")
        f.write("-- Run the script again after a patch (or once a week) to refresh; /reload the game afterwards. Builds of earlier bakes stay in the file.\n\n")
        f.write("local _, SFP = ...\n\nlocal B = {}\nSFP.TalentBuilds = B\nSFP.TalentBuildsPatch = %s\nSFP.TalentBuildsBaked = %s\n\n" % (lua_str(patch), lua_str(today)))
        for line in out:
            f.write(line + "\n")
    print("wrote", total, "current builds and kept", kept_old, "older ones of", len(out), "specializations to", OUT, file=sys.stderr)


if __name__ == "__main__":
    main()
