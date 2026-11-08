"""Bakes the collected data, pushes it to the data repo, and makes the CurseForge zip.

    python tools/update_data.py            bake + push the data to GitHub (PetalsOfIron/Data-wow) + build the zip
    python tools/update_data.py --no-zip   bake + push only

1. tools/bake_collected.py writes the collected folder from your saved data (and keeps what earlier bakes had).
2. The collected folder is copied to the clone of the data repo (C:/Users/<you>/Projects/Data-wow), committed and pushed.
3. The addon folder is copied to C:/Users/<you>/Projects/sut-curse-release/SeviathsUsefulTools (without .git, .github, .gitignore, tools and
   backup files) and zipped next to it: that zip is the one file to upload to CurseForge.
Run it after a play session, after the game is closed or after /reload (the game writes the saved data then).
"""
import glob
import os
import shutil
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.abspath(os.path.join(HERE, ".."))
HOME = os.path.expanduser("~")
DATA_REPO = os.path.join(HOME, "Projects", "Data-wow")
CURSE = os.path.join(HOME, "Projects", "sut-curse-release")
# the monsters and gray items are a second addon folder (load on demand), next to this one in Interface/AddOns
LOD_DIR = os.path.join(os.path.dirname(ADDON), "SeviathsUsefulTools_Monsters")
ADDONS_DIR = os.path.dirname(ADDON)


def tmog_dirs():
    return sorted(d for d in os.listdir(ADDONS_DIR) if d.startswith(("SeviathsUsefulTools_Transmog", "SeviathsUsefulTools_Drops", "SeviathsUsefulTools_Items")) and os.path.isdir(os.path.join(ADDONS_DIR, d)))
SKIP_DIRS = {".git", ".github", "tools"}
SKIP_FILES = {".gitignore", ".gitattributes"}


def run(*args, cwd=None):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr).strip()


def version():
    for line in open(os.path.join(ADDON, "SeviathsUsefulTools.toc"), encoding="utf-8"):
        if line.startswith("## Version:"):
            return line.split(":", 1)[1].strip()
    return "x"


def sync_toc():
    """The .toc lists every file of the collected folder (the game loads only what is listed)."""
    toc = os.path.join(ADDON, "SeviathsUsefulTools.toc")
    raw = open(toc, "rb").read().decode("utf-8")
    nl = chr(13) + chr(10) if chr(13) + chr(10) in raw else chr(10)
    keep = [l for l in raw.split(nl) if not l.startswith("collected" + chr(92))]
    names = sorted(f for f in os.listdir(os.path.join(ADDON, "collected")) if f.endswith(".lua"))
    at = next(i for i, l in enumerate(keep) if l.strip() == "CollectedImport.lua")
    keep[at:at] = ["collected" + chr(92) + n for n in names]
    open(toc, "wb").write(nl.join(keep).encode("utf-8"))
    print("toc: %d collected files" % len(names))


def load_check():
    """Loads the shipped data and the player's saved data the way the game does (offline, with a Lua interpreter) before anything is pushed:
    a data file that would not load in the game stops the push. Needs node with the fengari package (see tools/load_test.js)."""
    saved = glob.glob(os.path.join(os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")), "WTF", "Account", "*", "SavedVariables", "SeviathsUsefulTools.lua"))
    modules = os.path.join(os.environ.get("TEMP", ""), "lchk", "node_modules")
    if not (saved and os.path.isdir(modules)):
        print("load check: skipped (no saved data or no fengari)")
        return True
    env = dict(os.environ, NODE_PATH=modules)
    r = subprocess.run(["node", "--max-old-space-size=8192", os.path.join(HERE, "load_test.js"), ADDON, saved[0]],
                       capture_output=True, text=True, env=env)
    ok = r.returncode == 0 and "done, total" in r.stdout
    print("load check:", "passed" if ok else "FAILED")
    if not ok:
        print((r.stdout + r.stderr)[-1500:])
    return ok


def push_data():
    if not os.path.isdir(os.path.join(DATA_REPO, ".git")):
        sys.exit("clone https://github.com/PetalsOfIron/Data-wow.git to " + DATA_REPO + " first")
    dst = os.path.join(DATA_REPO, "collected")
    shutil.rmtree(dst, ignore_errors=True)
    shutil.copytree(os.path.join(ADDON, "collected"), dst)
    if os.path.isdir(LOD_DIR):
        dst2 = os.path.join(DATA_REPO, "monsters")
        shutil.rmtree(dst2, ignore_errors=True)
        shutil.copytree(LOD_DIR, dst2)
    dst3 = os.path.join(DATA_REPO, "extra-addons")
    shutil.rmtree(dst3, ignore_errors=True)
    for d in tmog_dirs():
        shutil.copytree(os.path.join(ADDONS_DIR, d), os.path.join(dst3, d))
    readme = os.path.join(HERE, "README-FOR-CLAUDE.md")   # the recovery notes also live in the data repo (outside the addon zip)
    if os.path.exists(readme):
        shutil.copy2(readme, os.path.join(DATA_REPO, "README-FOR-CLAUDE.md"))
    run("git", "add", "-A", cwd=DATA_REPO)
    code, out = run("git", "diff", "--cached", "--quiet", cwd=DATA_REPO)
    if code == 0:
        print("data repo: nothing new")
        return
    msg = "Collected data update\n\nCo-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
    print(run("git", "commit", "-q", "-m", msg, cwd=DATA_REPO)[1])
    print(run("git", "push", "origin", "main", cwd=DATA_REPO)[1] or "data repo: pushed")


BACKUP_REPO = os.path.join(HOME, "Projects", "backupwowseviath")
MEMORY = os.path.join(HOME, ".claude", "projects", "C--Users-SaphiresSilver-Projects-seviathstudio", "memory")


def backup_repo():
    """Copies everything needed to rebuild the workflow to the backup repo (PetalsOfIron/backupwowseviath) and pushes it: the tools,
    the PC scripts, the recovery notes and Claude's memory notes. The player's saved game data is added only when that repo is private
    (it holds character names, gold and settings)."""
    if not os.path.isdir(os.path.join(BACKUP_REPO, ".git")):
        print("backup repo: not cloned, skipped")
        return
    def copy_tree(src, dst):
        shutil.rmtree(dst, ignore_errors=True)
        if os.path.isdir(src):
            shutil.copytree(src, dst, ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "*.bak"))
    copy_tree(HERE, os.path.join(BACKUP_REPO, "tools"))
    copy_tree(MEMORY, os.path.join(BACKUP_REPO, "claude-memory"))
    scripts = os.path.join(BACKUP_REPO, "pc-scripts")
    os.makedirs(scripts, exist_ok=True)
    for src in (os.path.join(HOME, "Desktop", "Install auto update (run once).bat"), os.path.join(HOME, "Desktop", "Start WoW with data update.bat"),
                os.path.join(os.environ.get("APPDATA", ""), "Microsoft", "Windows", "Start Menu", "Programs", "Startup", "SeviathsUsefulTools data update.vbs")):
        if os.path.exists(src):
            shutil.copy2(src, scripts)
    shutil.copy2(os.path.join(HERE, "README-FOR-CLAUDE.md"), os.path.join(BACKUP_REPO, "README-FOR-CLAUDE.md"))
    # the saved game data: only when the backup repo is private
    private = False
    try:
        import json
        import urllib.request
        with urllib.request.urlopen("https://api.github.com/repos/PetalsOfIron/backupwowseviath", timeout=20) as r:
            private = json.loads(r.read().decode("utf-8")).get("private") is True
    except Exception:
        private = False   # not readable without a login means private or unreachable: not copied to be safe
    saved_dir = os.path.join(BACKUP_REPO, "saved")
    if private:
        found = glob.glob(os.path.join(os.path.abspath(os.path.join(HERE, "..", "..", "..", "..")), "WTF", "Account", "*", "SavedVariables", "SeviathsUsefulTools.lua"))
        if found:
            os.makedirs(saved_dir, exist_ok=True)
            shutil.copy2(found[0], os.path.join(saved_dir, "SeviathsUsefulTools.lua"))
    else:
        shutil.rmtree(saved_dir, ignore_errors=True)
    run("git", "add", "-A", cwd=BACKUP_REPO)
    code, _ = run("git", "diff", "--cached", "--quiet", cwd=BACKUP_REPO)
    if code == 0:
        print("backup repo: nothing new")
        return
    msg = "Backup" + chr(10) + chr(10) + "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
    run("git", "-c", "user.name=santamadaraneilande-ctrl", "-c", "user.email=santamadaraneilande@gmail.com", "commit", "-q", "-m", msg, cwd=BACKUP_REPO)
    print(run("git", "push", "origin", "main", cwd=BACKUP_REPO)[1] or "backup repo: pushed")
    print("backup repo: saved game data " + ("included (repo is private)" if private else "NOT included (repo is public)"))


GITDIR = os.path.join(HOME, "Projects", "sut-retail-gitdir")   # the addon's git folder is kept outside the addon folder


def push_addon():
    """Commits and pushes the addon itself (with the fresh collected folder) to its GitHub repo."""
    if not os.path.isdir(GITDIR):
        print("addon repo: git folder not found, not pushed")
        return
    base = ["git", "--git-dir=" + GITDIR, "--work-tree=" + ADDON]
    run(*base, "add", "-A")
    code, _ = run(*base, "diff", "--cached", "--quiet")
    if code == 0:
        print("addon repo: nothing new")
        return
    msg = "Auto update: collected data and addon files" + chr(10) + chr(10) + "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
    print(run(*base, "-c", "user.name=santamadaraneilande-ctrl", "-c", "user.email=santamadaraneilande@gmail.com",
              "commit", "-q", "-m", msg)[1])
    print(run(*base, "push", "origin", "main")[1] or "addon repo: pushed")


def build_zip():
    target = os.path.join(CURSE, "SeviathsUsefulTools")
    shutil.rmtree(target, ignore_errors=True)
    os.makedirs(CURSE, exist_ok=True)

    def ignore(folder, names):
        out = []
        for n in names:
            p = os.path.join(folder, n)
            if os.path.isdir(p) and n in SKIP_DIRS and folder == ADDON:
                out.append(n)
            elif os.path.isfile(p) and (n in SKIP_FILES or n.endswith(".bak")):
                out.append(n)
        return out

    shutil.copytree(ADDON, target, ignore=ignore, dirs_exist_ok=True)   # a folder that could not be removed is overwritten
    # the load-on-demand folder goes into the same zip, as a second addon folder
    lod_target = os.path.join(CURSE, "SeviathsUsefulTools_Monsters")
    shutil.rmtree(lod_target, ignore_errors=True)
    if os.path.isdir(LOD_DIR):
        shutil.copytree(LOD_DIR, lod_target, ignore=ignore, dirs_exist_ok=True)
    tmog_targets = []
    for d in tmog_dirs():
        tt = os.path.join(CURSE, d)
        shutil.rmtree(tt, ignore_errors=True)
        shutil.copytree(os.path.join(ADDONS_DIR, d), tt, ignore=ignore, dirs_exist_ok=True)
        tmog_targets.append(tt)
    zpath = os.path.join(CURSE, "SeviathsUsefulTools-%s.zip" % version())
    if os.path.exists(zpath):
        os.remove(zpath)
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for folder in [target, lod_target] + tmog_targets:
            for root, _, files in os.walk(folder):
                for f in files:
                    full = os.path.join(root, f)
                    z.write(full, os.path.relpath(full, CURSE))
    print("zip: %s (%.1f MB)" % (zpath, os.path.getsize(zpath) / 1e6))
    # only the zip goes to the folder you upload from (older zips there are replaced)
    out = os.path.join(HOME, "Downloads", "curse")
    os.makedirs(out, exist_ok=True)
    for old in os.listdir(out):
        if old.lower().endswith(".zip") and old.startswith("SeviathsUsefulTools"):
            os.remove(os.path.join(out, old))
    shutil.copy2(zpath, out)
    print("copied to " + out)
    # the text for the CurseForge changelog box: the newest section of CHANGELOG.md only (what is new in this version), as plain lines
    try:
        text = open(os.path.join(ADDON, "CHANGELOG.md"), encoding="utf-8").read().replace(chr(13) + chr(10), chr(10))
        start = text.index("## ")
        end = text.find(chr(10) + "## ", start + 3)
        section = text[start:end if end > 0 else len(text)].strip().split(chr(10))[1:]
        lines = ["New in %s" % version(), ""]
        for line in section:
            if line.startswith("### "):
                lines += ["", line[4:]]
            else:
                lines.append(line)
        with open(os.path.join(out, "CHANGELOG-for-curse.txt"), "w", encoding="utf-8", newline=chr(10)) as fh:
            fh.write(chr(10).join(lines).strip() + chr(10))
        print("changelog text written for version " + version())
    except Exception as e:
        print("changelog text not written: %s" % e)


def take_lock():
    """Only one update runs at a time (the watcher and a manual run would rewrite the collected files under each other):
    the others wait here. A lock older than 30 minutes belongs to a run that died and is taken over."""
    import time
    path = os.path.join(os.environ.get("TEMP", HERE), "sut_update.lock")
    while True:
        try:
            fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            return path
        except FileExistsError:
            try:
                if time.time() - os.path.getmtime(path) > 1800:
                    os.remove(path)
                    continue
            except OSError:
                pass
            time.sleep(3)


if __name__ == "__main__":
    _lock = take_lock()
    import atexit
    atexit.register(lambda: os.path.exists(_lock) and os.remove(_lock))
    print(run(sys.executable, os.path.join(HERE, "bake_items.py"))[1].strip())   # the other items of the Wowhead lists
    print(run(sys.executable, os.path.join(HERE, "bake_drops.py"))[1].strip())   # the monster drops, from tools/items_sources.txt
    print(run(sys.executable, os.path.join(HERE, "bake_transmog.py"))[1].strip())   # the transmog folders, from tools/transmog_items.txt
    print(run(sys.executable, os.path.join(HERE, "bake_collected.py"))[1].splitlines()[-1])
    print(run(sys.executable, os.path.join(HERE, "bake_gold.py"))[1])
    sync_toc()
    if not load_check():
        sys.exit("the data did not load in the check: nothing was pushed")
    push_data()
    push_addon()
    try:
        backup_repo()
    except Exception as e:
        print("backup repo failed:", e)
    if "--no-zip" not in sys.argv:
        build_zip()
