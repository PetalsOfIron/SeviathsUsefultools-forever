"""Builds the CurseForge upload: one zip with SeviathsUsefulTools and its load-on-demand data folders (SeviathsUsefulTools_*), without tools/, crawl data,
git files and notes. Output: <_forever_>/curseforge/SeviathsUsefulTools-<version>-forever.zip
Run: python tools/package_curseforge.py   (run it again after every change you upload)"""
import os
import re
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
ADDONS = os.path.dirname(ADDON)
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(ADDONS)), "curseforge")
os.makedirs(OUT_DIR, exist_ok=True)
toc = open(os.path.join(ADDON, "SeviathsUsefulTools.toc"), encoding="utf8").read()
m = re.search(r"## Version:\s*(\S+)", toc)
ver = m.group(1) if m else "dev"
SKIP_DIRS = {"tools", ".git", ".claude", "lod"}
SKIP_FILES = {".gitignore", "FOREVER-PORT.md"}
zpath = os.path.join(OUT_DIR, "SeviathsUsefulTools-%s-forever.zip" % ver)
n = 0
with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(ADDONS)):
        if name != "SeviathsUsefulTools" and not name.startswith("SeviathsUsefulTools_"):
            continue
        root = os.path.join(ADDONS, name)
        for d, dirs, files in os.walk(root):
            dirs[:] = [x for x in dirs if not (d == root and x in SKIP_DIRS) and x != ".git"]
            for f in files:
                if f in SKIP_FILES:
                    continue
                full = os.path.join(d, f)
                z.write(full, os.path.relpath(full, ADDONS))
                n += 1
print("wrote", zpath, n, "files")
