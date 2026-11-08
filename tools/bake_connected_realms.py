"""Bakes Data/ConnectedRealms.lua: which realms share one auction house, for the US, EU, Korea and Taiwan.

Uses the official Blizzard API (free): create an API client at https://develop.battle.net/access/clients and put its id and secret in the
environment variables BLIZZARD_CLIENT_ID / BLIZZARD_CLIENT_SECRET, or in ~/.sut_blizzard.json: {"client_id": "...", "client_secret": "..."}.

    python tools/bake_connected_realms.py

Realms are written the way the game normalizes them (no spaces); the addon compares them without spaces, apostrophes and hyphens.
"""
import base64
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Data", "ConnectedRealms.lua")
REGIONS = ["us", "eu", "kr", "tw"]


def credentials():
    cid, secret = os.environ.get("BLIZZARD_CLIENT_ID"), os.environ.get("BLIZZARD_CLIENT_SECRET")
    path = os.path.join(os.path.expanduser("~"), ".sut_blizzard.json")
    if not (cid and secret) and os.path.exists(path):
        d = json.load(open(path, encoding="utf-8"))
        cid, secret = d.get("client_id"), d.get("client_secret")
    return cid, secret


def get_json(url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def token(cid, secret):
    auth = base64.b64encode((cid + ":" + secret).encode()).decode()
    d = get_json("https://oauth.battle.net/token", data=b"grant_type=client_credentials",
                 headers={"Authorization": "Basic " + auth, "Content-Type": "application/x-www-form-urlencoded"})
    return d["access_token"]


def main():
    cid, secret = credentials()
    if not (cid and secret):
        sys.exit("No Blizzard API client found. See the top of this file.")
    tok = token(cid, secret)
    groups = []
    for region in REGIONS:
        host = "https://%s.api.blizzard.com" % region
        hdr = {"Authorization": "Bearer " + tok}
        q = "?namespace=dynamic-%s&locale=en_US" % region
        index = get_json(host + "/data/wow/connected-realm/index" + q, headers=hdr)
        for entry in index.get("connected_realms", []):
            href = entry["href"].split("?")[0] + q
            d = get_json(href, headers=hdr)
            names = sorted(re.sub(r"[\s]", "", (r.get("name") or "")) for r in d.get("realms", []))
            names = [n for n in names if n]
            if names:
                groups.append((region, names))
            time.sleep(0.05)
        print(region, "done:", sum(1 for g in groups if g[0] == region), "groups")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- SeviathsUsefulTools - realms that share one auction house, per region (made by tools/bake_connected_realms.py from the Blizzard API)\n")
        f.write("local _, SFP = ...\nSFP.ConnectedRealms = {\n")
        for region, names in groups:
            f.write('    { "%s", %s },\n' % (region, ", ".join('"%s"' % n.replace('"', "") for n in names)))
        f.write("}\n")
    print("wrote", len(groups), "groups ->", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
