"""Bakes Data/GuildLeaders.lua: the Guild Master and the officers of the guilds the addon has seen.

The addon records the guilds of the players around you (the guild directory). This script reads that list from the addon's saved data
and asks Raider.IO's public web API (no key needed) for each guild's members and ranks: rank 0 is the Guild Master, rank 1 the officers.
The directory then shows the Guild Master and officers even when you have not seen them yourself, marked with the date of the data.

    python tools/bake_guilds.py            (then /reload the game)

Guilds Raider.IO does not know are skipped. One guild per request, at a gentle pace.
"""
import glob
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Data", "GuildLeaders.lua")
RETAIL = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
REALMS_FILE = os.path.join(HERE, "..", "..", "RaiderIO", "db", "db_realms.lua")
REGIONS = ["eu", "us", "kr", "tw"]   # tried in this order for a realm


def parse_lua_table(text, pos=0):
    """Reads one Lua table written as {["key"] = value, ...} (what the game saves) and returns (python dict/list, end position)."""
    def skip(p):
        while p < len(text) and text[p] in " \t\r\n,":
            p += 1
        return p
    pos = skip(pos)
    assert text[pos] == "{", text[pos:pos + 20]
    pos += 1
    out = {}
    while True:
        pos = skip(pos)
        if text[pos] == "}":
            return out, pos + 1
        if text[pos] == "[":
            end = text.index("]", pos)
            key = text[pos + 1:end].strip()
            key = key[1:-1] if key.startswith('"') else int(key)
            pos = skip(text.index("=", end) + 1)
        else:
            m = re.match(r'(\w+)\s*=\s*', text[pos:])
            key = m.group(1)
            pos = skip(pos + m.end())
        c = text[pos]
        if c == "{":
            val, pos = parse_lua_table(text, pos)
        elif c == '"':
            j = pos + 1
            buf = []
            while text[j] != '"':
                if text[j] == "\\":
                    j += 1
                buf.append(text[j])
                j += 1
            val, pos = "".join(buf), j + 1
        else:
            m = re.match(r"[-\w.]+", text[pos:])
            raw = m.group(0)
            val = {"true": True, "false": False}.get(raw)
            if val is None:
                try:
                    val = float(raw) if "." in raw else int(raw)
                except ValueError:
                    val = raw
            pos += m.end()
        out[key] = val


def shipped_guilds():
    """{(realm, guild): entry} from the Data/GuildLeaders.lua written last time: guilds already shipped stay in the next release."""
    out = {}
    if not os.path.exists(OUT):
        return out
    realm = None
    for line in open(OUT, encoding="utf-8").read().splitlines():
        m = re.match(r'^    \["(.+)"\] = \{$', line)
        if m:
            realm = m.group(1).replace('\\"', '"')
            continue
        m = re.match(r'^        \["(.+)"\] = \{ gm = (nil|"[^"]*"), officers = \{(.*)\}, n = (\d+), faction = (nil|"[^"]*"), date = "([^"]*)"(?:, raid = "([^"]*)")?(?:, src = "([^"]*)")? \},$', line)
        if m and realm:
            out[(realm, m.group(1).replace('\\"', '"'))] = dict(
                gm=None if m.group(2) == "nil" else m.group(2)[1:-1], officers=re.findall(r'"([^"]*)"', m.group(3)), n=int(m.group(4)),
                faction=None if m.group(5) == "nil" else m.group(5)[1:-1], date=m.group(6), raid=m.group(7), src=m.group(8) or "R")
    return out


def seen_leaders(g):
    """Guild Master and officers from the ranks the addon saw: rank 0, and rank 1 / officer-like rank names."""
    gm, officers = None, []
    for name, m in (g.get("members") or {}).items():
        if not isinstance(m, dict):
            continue
        rn = str(m.get("rank", "")).lower()
        if m.get("ri") == 0:
            gm = name
        elif m.get("ri") == 1 or "officer" in rn or "lieutenant" in rn or "deputy" in rn:
            officers.append(name)
    return gm, sorted(officers)


def seen_guilds():
    """{(realm, guild): faction} from the addon's saved data."""
    out = {}
    for f in glob.glob(os.path.join(RETAIL, "WTF", "Account", "*", "SavedVariables", "SeviathsUsefulTools.lua")):
        text = open(f, encoding="utf-8", errors="replace").read()
        i = text.find('["guildDir"] = {')
        if i < 0:
            continue
        table, _ = parse_lua_table(text, text.index("{", i))
        for realm, guilds in table.items():
            for guild, g in guilds.items():
                out[(realm, guild)] = g if isinstance(g, dict) else {}
    return out


def realm_slugs():
    slugs = {}
    if os.path.exists(REALMS_FILE):
        for name, slug in re.findall(r'\["([^"]+)"\]\s*=\s*"([^"]+)"', open(REALMS_FILE, encoding="utf-8", errors="replace").read()):
            slugs.setdefault(name, slug)
            slugs.setdefault(re.sub(r"[^a-z0-9]", "", name.lower()), slug)
    return slugs


def fetch(region, slug, guild):
    url = "https://raider.io/api/v1/guilds/profile?region=%s&realm=%s&name=%s&fields=members,raid_progression" % (
        region, urllib.parse.quote(slug), urllib.parse.quote(guild))
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read().decode("utf-8"))


def blizzard_roster(token, realm_slug, guild):
    """The complete roster of a guild from Blizzard's web API (rank 0 = Guild Master, rank 1 = officers), or None."""
    try:
        import bake_players as bp   # its credentials and API helper
        guild_slug = re.sub(r"[^a-z0-9-]", "", guild.lower().replace(" ", "-").replace("'", ""))
        data = bp.api("/data/wow/guild/%s/%s/roster" % (realm_slug, urllib.parse.quote(guild_slug)), token, "profile")
    except Exception:
        return None
    members = data.get("members") or []
    if not members:
        return None
    gm = [m["character"]["name"] for m in members if m.get("rank") == 0 and real_name(m["character"]["name"])]
    officers = [m["character"]["name"] for m in members if m.get("rank") == 1 and real_name(m["character"]["name"])]
    return gm[0] if gm else None, officers, len(members)


def real_name(n):
    """Raider.IO lists characters that were renamed, transferred or deleted as 'Name-12345678': those are not names to whisper."""
    return isinstance(n, str) and n != "" and not re.search(r"-\d{4,}$", n)


def guild_raid(prog):
    """The guild's progress in its main raid ("7/8 H"): the raid with the most bosses of Raider.IO's list (at least 5)."""
    best = None
    for key, v in (prog or {}).items():
        if isinstance(v, dict) and v.get("summary") and (v.get("total_bosses") or 0) >= 5:
            if best is None or v["total_bosses"] >= best["total_bosses"]:
                best = v
    return best["summary"] if best else None


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    seen = seen_guilds()
    old = shipped_guilds()
    if not seen and not old:
        sys.exit("No guild directory in the saved data yet: play a while near players, /reload, then run this again.")
    slugs = realm_slugs()
    today = time.strftime("%Y-%m-%d")
    result = {}
    # a Blizzard API client (the same one bake_players.py uses) gives the complete roster of every guild; without it Raider.IO is used
    token = None
    try:
        sys.path.insert(0, HERE)
        import bake_players as bp
        if all(bp.credentials()):
            token = bp.get_token()
            print("using Blizzard's guild rosters", file=sys.stderr)
    except SystemExit:
        pass
    except Exception as e:
        print("no Blizzard API client:", e, file=sys.stderr)
    for key in sorted(set(seen) | set(old)):
        realm, guild = key
        g = seen.get(key, {})
        faction = g.get("faction") if g else None
        slug = slugs.get(realm) or slugs.get(re.sub(r"[^a-z0-9]", "", realm.lower()))
        data = None
        if slug:
            for region in REGIONS:
                try:
                    data = fetch(region, slug, guild)
                    break
                except Exception:
                    time.sleep(0.3)
            time.sleep(0.4)
        entry = None
        if data:
            members = data.get("members", [])
            gm = [m["character"]["name"] for m in members if m.get("rank") == 0 and real_name(m["character"]["name"])]
            entry = dict(gm=gm[0] if gm else None,
                         officers=[m["character"]["name"] for m in members if m.get("rank") == 1 and real_name(m["character"]["name"])], n=len(members),
                         faction=(data.get("faction") or faction or "").capitalize() or None, date=today, src="R",
                         raid=guild_raid(data.get("raid_progression")))
        if token and slug:
            br = blizzard_roster(token, slug, guild)
            if br:
                entry = dict(gm=br[0], officers=br[1], n=br[2],
                             faction=(entry or {}).get("faction") or faction, date=today, src="B")
        sgm, soff = seen_leaders(g)
        if entry is None and key in old:
            entry = old[key]                      # not answered now: what was shipped before stays
        if entry is None:
            entry = dict(gm=None, officers=[], n=len(g.get("members") or {}), faction=faction, date=today, src="S")
        # what the addon saw itself fills what Raider.IO did not give
        if not entry["gm"] and sgm:
            entry["gm"] = sgm
        for o in soff:
            if o not in entry["officers"]:
                entry["officers"].append(o)
        entry["officers"] = entry["officers"][:12]
        result.setdefault(realm, {})[guild] = entry
        print(realm, guild, "GM:", entry["gm"] or "-", "officers:", len(entry["officers"]), "src", entry["src"], file=sys.stderr)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- SeviathsUsefulTools - Guild Master and officers of the guilds seen (generated by tools/bake_guilds.py from Raider.IO)\n")
        f.write("-- SFP.GuildLeaders[realm][guild] = { gm = name, officers = { names }, n = members, faction, date }. Rank 0 = Guild Master, rank 1 = officers.\n\n")
        f.write("local _, SFP = ...\n\nSFP.GuildLeaders = {\n")
        for realm in sorted(result):
            f.write("    [%s] = {\n" % lua_str(realm))
            for guild in sorted(result[realm]):
                g = result[realm][guild]
                off = ", ".join(lua_str(o) for o in g["officers"])
                f.write("        [%s] = { gm = %s, officers = { %s }, n = %d, faction = %s, date = %s, raid = %s, src = %s },\n" % (
                    lua_str(guild), lua_str(g["gm"]) if g["gm"] else "nil", off, g["n"],
                    lua_str(g["faction"]) if g["faction"] else "nil", lua_str(g["date"]), lua_str(g.get("raid")) if g.get("raid") else "nil", lua_str(g.get("src", "R"))))
            f.write("    },\n")
        f.write("}\n")
    print("wrote", sum(len(v) for v in result.values()), "guilds to", OUT, file=sys.stderr)


if __name__ == "__main__":
    main()
