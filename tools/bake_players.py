"""Bakes Data/PlayerData.lua: public character data of the players the addon has seen near you.

The addon notes every player that comes near you (either faction) in its saved data (seenPlayers). This script reads that list,
asks Blizzard's free web API for each one's public character data (item level, achievement points, Mythic+ rating, mount and pet
counts) and writes it as plain data. The addon only reads the file, so it needs no question to the other player and works across
factions. The data is as fresh as the last run: run it again when you like (weekly is enough), then /reload the game.

You need a free Blizzard API client (https://develop.battle.net/access/clients): put its id and secret in the environment
variables BLIZZARD_CLIENT_ID and BLIZZARD_CLIENT_SECRET (never in the addon folder). Region: BLIZZARD_REGION (default us).

    python tools/bake_players.py

Characters whose profile is private or not found are skipped. About 5 requests per player, at a gentle pace.
"""
import base64
import glob
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Data", "PlayerData.lua")
# ...\_retail_\Interface\AddOns\SeviathsUsefulTools\tools -> ...\_retail_
RETAIL = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
REGION = os.environ.get("BLIZZARD_REGION", "us").lower()
MAX_AGE_DAYS = 7        # data younger than this is not fetched again
MAX_PER_RUN = 400       # players per run (the newest seen first)


def get_json(url, token=None, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read().decode("utf-8"))


def credentials():
    """The id and secret of your free Blizzard API client: the environment variables, or the file ~/.sut_blizzard.json
    ({"client_id": "...", "client_secret": "...", "region": "eu"}), which lives in your user folder and never in the addon folder."""
    global REGION
    cid, secret = os.environ.get("BLIZZARD_CLIENT_ID"), os.environ.get("BLIZZARD_CLIENT_SECRET")
    path = os.path.join(os.path.expanduser("~"), ".sut_blizzard.json")
    if os.path.exists(path):
        cfg = json.load(open(path, encoding="utf-8"))
        cid, secret = cid or cfg.get("client_id"), secret or cfg.get("client_secret")
        if cfg.get("region"):
            REGION = cfg["region"].lower()
    return cid, secret


def get_token():
    cid, secret = credentials()
    if not (cid and secret):
        sys.exit("No Blizzard API client found. Create a free one at https://develop.battle.net/access/clients, then put its id and secret "
                 "in the environment variables BLIZZARD_CLIENT_ID and BLIZZARD_CLIENT_SECRET, or in the file ~/.sut_blizzard.json "
                 "(in your user folder): {\"client_id\": \"...\", \"client_secret\": \"...\", \"region\": \"eu\"}")
    auth = base64.b64encode((cid + ":" + secret).encode()).decode()
    d = get_json("https://oauth.battle.net/token", data=b"grant_type=client_credentials",
                 headers={"Authorization": "Basic " + auth, "Content-Type": "application/x-www-form-urlencoded"})
    return d["access_token"]


def api(path, token, namespace):
    host = "https://%s.api.blizzard.com" % REGION
    sep = "&" if "?" in path else "?"
    return get_json(host + path + sep + "namespace=%s-%s&locale=en_US" % (namespace, REGION), token)


def seen_players():
    """{'Name-Realm': last seen time} from the addon's saved data (the file is large: only the seenPlayers block is read)."""
    files = glob.glob(os.path.join(RETAIL, "WTF", "Account", "*", "SavedVariables", "SeviathsUsefulTools.lua"))
    out = {}
    for f in files:
        text = open(f, encoding="utf-8", errors="replace").read()
        i = text.find('["seenPlayers"] = {')
        if i < 0:
            continue
        depth, j = 0, text.index("{", i)
        k = j
        while k < len(text):
            c = text[k]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    break
            k += 1
        for m in re.finditer(r'\["([^"]+)"\]\s*=\s*(\d+)', text[j:k]):
            out[m.group(1)] = max(out.get(m.group(1), 0), int(m.group(2)))
    return out


def home_realms():
    """The realms of the player's own connected group, as the addon saved them (homeRealms)."""
    out = []
    for f in glob.glob(os.path.join(RETAIL, "WTF", "Account", "*", "SavedVariables", "SeviathsUsefulTools.lua")):
        text = open(f, encoding="utf-8", errors="replace").read()
        i = text.find('["homeRealms"] = {')
        if i >= 0:
            j = text.index("}", i)
            out += re.findall(r'"([^"]+)"', text[i:j])
    return list(dict.fromkeys(out))


def realm_slugs(token):
    """normalized realm name (letters and digits only, lowercase) -> API slug"""
    d = api("/data/wow/realm/index", token, "dynamic")
    out = {}
    for r in d.get("realms", []):
        out[re.sub(r"[^a-z0-9]", "", r["name"].lower())] = r["slug"]
        out[re.sub(r"[^a-z0-9]", "", r["slug"].lower())] = r["slug"]
    return out


def read_old():
    old = {}
    if os.path.exists(OUT):
        for m in re.finditer(r'\["([^"]+)"\] = \{ (\d+), (\d+), (\d+), (\d+), (\d+), "([^"]*)" \}', open(OUT, encoding="utf-8").read()):
            old[m.group(1)] = dict(ilvl=int(m.group(2)), ach=int(m.group(3)), mplus=int(m.group(4)), mounts=int(m.group(5)),
                                   pets=int(m.group(6)), date=m.group(7))
    return old


def fetch(name, slug, token):
    base = "/profile/wow/character/%s/%s" % (slug, urllib.parse.quote(name.lower()))
    d = {"ilvl": 0, "ach": 0, "mplus": 0, "mounts": 0, "pets": 0}
    prof = api(base, token, "profile")
    d["ilvl"] = int(prof.get("equipped_item_level") or prof.get("average_item_level") or 0)
    d["ach"] = int(prof.get("achievement_points") or 0)
    for key, path, fn in (
        ("mplus", base + "/mythic-keystone-profile", lambda j: int((j.get("current_mythic_rating") or {}).get("rating") or 0)),
        ("mounts", base + "/collections/mounts", lambda j: len(j.get("mounts") or [])),
        ("pets", base + "/collections/pets", lambda j: len(j.get("pets") or [])),
    ):
        try:
            d[key] = fn(api(path, token, "profile"))
        except Exception:
            pass   # a part that is private or missing: left at 0 (the addon leaves zeros out)
        time.sleep(0.15)
    return d


def main():
    token = get_token()
    seen = seen_players()
    print(len(seen), "players seen", file=sys.stderr)
    slugs = realm_slugs(token)
    old = read_old()
    today = time.strftime("%Y-%m-%d")
    cutoff = time.time() - MAX_AGE_DAYS * 86400
    todo = []
    for key, t in sorted(seen.items(), key=lambda kv: -kv[1]):
        o = old.get(key)
        if o and time.mktime(time.strptime(o["date"], "%Y-%m-%d")) > cutoff:
            continue
        todo.append(key)
    home = home_realms()
    stop = False
    for n, key in enumerate(todo[:MAX_PER_RUN]):
        if stop:
            break
        name, _, realm = key.partition("-")
        # "Name-?": the game gave no realm, the player is on yours or on a connected one: every one of them is tried
        candidates = home if realm == "?" else [realm]
        for cand in candidates:
            slug = slugs.get(re.sub(r"[^a-z0-9]", "", cand.lower()))
            if not slug:
                continue
            try:
                d = fetch(name, slug, token)
            except urllib.error.HTTPError as e:
                if e.code == 429:
                    print("rate limit: stopping, run again later", file=sys.stderr)
                    stop = True
                    break
                continue   # 404 = not found here, or private
            except Exception as e:
                print("  failed", key, e, file=sys.stderr)
                continue
            d["date"] = today
            found = name + "-" + re.sub(r"[^A-Za-z0-9]", "", cand)
            old[found] = d
            print("  ", found, d, file=sys.stderr)
            time.sleep(0.2)
            break
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- SeviathsUsefulTools - public character data of players you met (generated by tools/bake_players.py)\n")
        f.write("-- Row: [\"Name-Realm\"] = { ilvl, ach (achievement points), mplus (Mythic+ rating), mounts, pets, date }.\n\n")
        f.write("local _, SFP = ...\n\nSFP.PlayerData = {\n")
        for key in sorted(old):
            d = old[key]
            f.write('    ["%s"] = { %d, %d, %d, %d, %d, "%s" },\n' % (key.replace('"', ""), d["ilvl"], d["ach"], d["mplus"], d["mounts"], d["pets"], d["date"]))
        f.write("}\n")
    print("wrote", len(old), "players to", OUT, file=sys.stderr)


if __name__ == "__main__":
    main()
